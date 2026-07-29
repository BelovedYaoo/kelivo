package dev.fluttercommunity.workmanager

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.concurrent.futures.CallbackToFutureAdapter
import androidx.work.ListenableWorker
import androidx.work.WorkerParameters
import com.google.common.util.concurrent.ListenableFuture
import dev.fluttercommunity.workmanager.pigeon.TaskStatus
import dev.fluttercommunity.workmanager.pigeon.WorkmanagerFlutterApi
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.view.FlutterCallbackInformation
import java.util.Random
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.ScheduledThreadPoolExecutor
import java.util.concurrent.TimeUnit

/**
 * A simple worker that posts your input back to your Flutter application.
 *
 * It will block the background thread until a value of either true or false is received back from Flutter code.
 */
class BackgroundWorker(
    applicationContext: Context,
    private val workerParams: WorkerParameters,
) : ListenableWorker(applicationContext, workerParams) {
    private lateinit var flutterApi: WorkmanagerFlutterApi

    private enum class LifecycleState {
        INITIALIZING,
        EXECUTING,
        TASK_EXECUTING,
        TERMINAL,
    }

    companion object {
        const val PAYLOAD_KEY = "dev.fluttercommunity.workmanager.INPUT_DATA"
        const val DART_TASK_KEY = "dev.fluttercommunity.workmanager.DART_TASK"
        private const val CANCELLATION_GRACE_MILLIS = 4_000L

        private val flutterLoader = FlutterLoader()
    }

    private val payload
        get() =
            workerParams.inputData.keyValueMap
                .filter { it.key.startsWith("payload_") }
                .mapKeys { it.key.replace("payload_", "") }
                .mapValues {
                    when (it.value) {
                        is Array<*> -> (it.value as Array<*>).asList()
                        else -> it.value
                    }
                }

    private val dartTask
        get() = workerParams.inputData.getString(DART_TASK_KEY)

    private val runAttemptCount = workerParams.runAttemptCount
    private val randomThreadIdentifier = Random().nextInt()
    private var engine: FlutterEngine? = null
    @Volatile
    private var backgroundChannelReady = false
    private val mainHandler = Handler(Looper.getMainLooper())
    private val lifecycleLock = Any()
    private var lifecycleState = LifecycleState.INITIALIZING
    private var forcedStop: ScheduledFuture<*>? = null
    private val cancellationScheduler: ScheduledExecutorService =
        ScheduledThreadPoolExecutor(1) { runnable ->
            Thread(runnable, "workmanager-cancellation-timeout").apply {
                isDaemon = true
            }
        }.apply {
            setRemoveOnCancelPolicy(true)
            setExecuteExistingDelayedTasksAfterShutdownPolicy(false)
        }

    private var startTime: Long = 0

    private var completer: CallbackToFutureAdapter.Completer<Result>? = null

    private var resolvableFuture =
        CallbackToFutureAdapter.getFuture { completer ->
            this.completer = completer
            null
        }

    override fun startWork(): ListenableFuture<Result> {
        startTime = System.currentTimeMillis()

        engine = FlutterEngine(applicationContext)

        if (!flutterLoader.initialized()) {
            flutterLoader.startInitialization(applicationContext)
        }

        flutterLoader.ensureInitializationCompleteAsync(
            applicationContext,
            null,
            mainHandler,
        ) {
            if (!claimDartExecution()) {
                return@ensureInitializationCompleteAsync
            }

            val callbackHandle = SharedPreferenceHelper.getCallbackHandle(applicationContext)
            val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)

            if (callbackInfo == null) {
                val exception = IllegalStateException("Failed to resolve Dart callback for handle $callbackHandle")
                WorkmanagerDebug.onExceptionEncountered(applicationContext, null, exception)
                stopEngine(Result.failure(), exception.message)
                return@ensureInitializationCompleteAsync
            }

            val localDartTask = dartTask

            if (localDartTask == null) {
                val exception = IllegalStateException("Dart task is null")
                WorkmanagerDebug.onExceptionEncountered(applicationContext, null, exception)
                stopEngine(Result.failure(), exception.message)
                return@ensureInitializationCompleteAsync
            }

            val dartBundlePath = flutterLoader.findAppBundlePath()

            val taskInfo =
                TaskDebugInfo(
                    taskName = localDartTask,
                    inputData = payload,
                    startTime = startTime,
                    callbackHandle = callbackHandle,
                    callbackInfo = callbackInfo?.callbackName,
                )

            val startStatus = if (runAttemptCount > 0) TaskStatus.RETRYING else TaskStatus.STARTED
            WorkmanagerDebug.onTaskStatusUpdate(applicationContext, taskInfo, startStatus)

            engine?.let { engine ->
                flutterApi = WorkmanagerFlutterApi(engine.dartExecutor.binaryMessenger)

                engine.dartExecutor.executeDartCallback(
                    DartExecutor.DartCallback(
                        applicationContext.assets,
                        dartBundlePath,
                        callbackInfo,
                    ),
                )

                // Initialize the background channel
                flutterApi.backgroundChannelInitialized {
                    if (!claimBackgroundTaskExecution()) {
                        return@backgroundChannelInitialized
                    }
                    backgroundChannelReady = true
                    // Channel is initialized, now execute the task
                    executeBackgroundTask()
                    if (isStopped) {
                        notifyDartCancellation()
                    }
                }
            }
        }

        return resolvableFuture
    }

    override fun onStopped() {
        notifyDartCancellation()
        scheduleForcedStop()
    }

    // 阶段领取与终态共用同一锁，防止迟到回调跨过已经完成的平台任务。
    private fun claimDartExecution(): Boolean =
        synchronized(lifecycleLock) {
            when (lifecycleState) {
                LifecycleState.INITIALIZING -> {
                    lifecycleState = LifecycleState.EXECUTING
                    true
                }
                LifecycleState.EXECUTING,
                LifecycleState.TASK_EXECUTING,
                LifecycleState.TERMINAL,
                -> false
            }
        }

    private fun claimBackgroundTaskExecution(): Boolean =
        synchronized(lifecycleLock) {
            when (lifecycleState) {
                LifecycleState.EXECUTING -> {
                    lifecycleState = LifecycleState.TASK_EXECUTING
                    true
                }
                LifecycleState.INITIALIZING,
                LifecycleState.TASK_EXECUTING,
                LifecycleState.TERMINAL,
                -> false
            }
        }

    private fun notifyDartCancellation() {
        mainHandler.post {
            val localDartTask = dartTask ?: return@post
            if (!backgroundChannelReady || engine == null || !this::flutterApi.isInitialized) {
                return@post
            }
            flutterApi.taskCancelled(localDartTask) { result ->
                result.exceptionOrNull()?.let { exception ->
                    WorkmanagerDebug.onExceptionEncountered(
                        applicationContext,
                        null,
                        exception,
                    )
                }
            }
        }
    }

    private fun scheduleForcedStop() {
        synchronized(lifecycleLock) {
            if (lifecycleState == LifecycleState.TERMINAL || forcedStop != null) {
                return
            }

            // 独立计时线程避免主线程阻塞使硬截止失效；主线程只负责最终的引擎销毁。
            forcedStop =
                cancellationScheduler.schedule(
                    {
                        stopEngine(
                            Result.failure(),
                            "Task cancellation timed out",
                        )
                    },
                    CANCELLATION_GRACE_MILLIS,
                    TimeUnit.MILLISECONDS,
                )
        }
    }

    private fun stopEngine(
        result: Result,
        errorMessage: String? = null,
    ) {
        val pendingForcedStop: ScheduledFuture<*>?
        synchronized(lifecycleLock) {
            if (lifecycleState == LifecycleState.TERMINAL) return
            lifecycleState = LifecycleState.TERMINAL
            pendingForcedStop = forcedStop
            forcedStop = null
        }
        pendingForcedStop?.cancel(false)

        val localDartTask = dartTask
        completer?.set(result)
        scheduleEngineDestruction()
        cancellationScheduler.shutdown()

        val fetchDuration = System.currentTimeMillis() - startTime

        if (localDartTask == null) {
            val exception = IllegalStateException("Dart task is null")
            WorkmanagerDebug.onExceptionEncountered(applicationContext, null, exception)
            return
        }

        val taskInfo =
            TaskDebugInfo(
                taskName = localDartTask,
                inputData = payload,
                startTime = startTime,
            )

        val taskResult =
            TaskResult(
                success = result is Result.Success,
                duration = fetchDuration,
                error =
                    when (result) {
                        is Result.Failure -> errorMessage ?: "Task failed"
                        else -> null
                    },
            )

        val status =
            when (result) {
                is Result.Success -> TaskStatus.COMPLETED
                is Result.Retry -> TaskStatus.RESCHEDULED
                else -> TaskStatus.FAILED
            }
        WorkmanagerDebug.onTaskStatusUpdate(applicationContext, taskInfo, status, taskResult)
    }

    private fun scheduleEngineDestruction() {
        // FlutterEngine 必须在主线程销毁；硬截止只保证结果结算，此处属于尽力清理。
        mainHandler.post {
            backgroundChannelReady = false
            engine?.destroy()
            engine = null
        }
    }

    private fun executeBackgroundTask() {
        // Convert payload to the format expected by Pigeon (Map<String?, Object?>)
        val pigeonPayload = payload.mapKeys { it.key as String? }.mapValues { it.value as Object? }

        val localDartTask = dartTask

        if (localDartTask == null) {
            val exception = IllegalStateException("Dart task is null")
            WorkmanagerDebug.onExceptionEncountered(applicationContext, null, exception)

            stopEngine(Result.failure(), exception.message)
            return
        }

        flutterApi.executeTask(localDartTask, pigeonPayload) { result ->
            if (isStopped) {
                stopEngine(Result.failure(), "Task was cancelled")
                return@executeTask
            }
            when {
                result.isSuccess -> {
                    val wasSuccessful = result.getOrNull() ?: false
                    stopEngine(if (wasSuccessful) Result.success() else Result.retry())
                }
                result.isFailure -> {
                    val exception = result.exceptionOrNull()
                    // Don't call onExceptionEncountered for Dart task failures
                    // These are handled as normal failures via onTaskStatusUpdate
                    stopEngine(Result.failure(), exception?.message)
                }
            }
        }
    }
}
