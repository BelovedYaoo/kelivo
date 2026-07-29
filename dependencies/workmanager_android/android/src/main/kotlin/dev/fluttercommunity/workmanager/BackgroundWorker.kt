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
import java.util.concurrent.atomic.AtomicReference

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

    private data class TerminalRequest(
        val result: ListenableWorker.Result,
        val errorMessage: String?,
    )

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
    private val engine = AtomicReference<FlutterEngine?>()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val lifecycle =
        BackgroundWorkerLifecycleCoordinator<TerminalRequest, ScheduledFuture<*>>()
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

    private lateinit var completer: CallbackToFutureAdapter.Completer<Result>

    private val resolvableFuture =
        CallbackToFutureAdapter.getFuture { completer ->
            this.completer = completer
            null
        }

    override fun startWork(): ListenableFuture<Result> {
        startTime = System.currentTimeMillis()

        engine.set(FlutterEngine(applicationContext))

        if (!flutterLoader.initialized()) {
            flutterLoader.startInitialization(applicationContext)
        }

        flutterLoader.ensureInitializationCompleteAsync(
            applicationContext,
            null,
            mainHandler,
        ) {
            val callbackHandle = SharedPreferenceHelper.getCallbackHandle(applicationContext)
            val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)

            if (callbackInfo == null) {
                val exception = IllegalStateException("Failed to resolve Dart callback for handle $callbackHandle")
                reportFailureAndStop(exception)
                return@ensureInitializationCompleteAsync
            }

            val localDartTask = dartTask

            if (localDartTask == null) {
                val exception = IllegalStateException("Dart task is null")
                reportFailureAndStop(exception)
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
            startDartExecutionIfActive(
                callbackInfo = callbackInfo,
                dartBundlePath = dartBundlePath,
                localDartTask = localDartTask,
                taskInfo = taskInfo,
                startStatus = startStatus,
            )
        }

        return resolvableFuture
    }

    override fun onStopped() {
        requestDartCancellation()
        scheduleForcedStop()
    }

    // 在途门闩让终态先封门、再等已领取的原生调用返回，避免平台完成后出现迟到副作用。
    private fun startDartExecutionIfActive(
        callbackInfo: FlutterCallbackInformation,
        dartBundlePath: String,
        localDartTask: String,
        taskInfo: TaskDebugInfo,
        startStatus: TaskStatus,
    ): Boolean {
        val effect = lifecycle.beginDartExecution() ?: return false

        return try {
            val localEngine =
                engine.get() ?: throw IllegalStateException("Flutter engine is unavailable")
            WorkmanagerDebug.onTaskStatusUpdate(applicationContext, taskInfo, startStatus)
            flutterApi = WorkmanagerFlutterApi(localEngine.dartExecutor.binaryMessenger)
            localEngine.dartExecutor.executeDartCallback(
                DartExecutor.DartCallback(
                    applicationContext.assets,
                    dartBundlePath,
                    callbackInfo,
                ),
            )
            flutterApi.backgroundChannelInitialized { result ->
                result.exceptionOrNull()?.let { exception ->
                    reportFailureAndStop(exception)
                    return@backgroundChannelInitialized
                }
                startBackgroundTaskIfActive(localDartTask)
            }
            true
        } catch (exception: Exception) {
            reportFailureAndStop(exception)
            false
        } finally {
            finishLifecycleEffect(effect)
        }
    }

    private fun startBackgroundTaskIfActive(localDartTask: String): Boolean {
        val effect = lifecycle.beginTaskExecution() ?: return false

        return try {
            val pigeonPayload = payload.mapKeys { it.key as String? }.mapValues { it.value as Object? }
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

            markDartCancellationRequestedIfStopped()
            sendDartCancellationIfReady()
            true
        } catch (exception: Exception) {
            reportFailureAndStop(exception)
            false
        } finally {
            finishLifecycleEffect(effect)
        }
    }

    private fun requestDartCancellation() {
        if (lifecycle.requestCancellationWakeup()) {
            mainHandler.post { sendDartCancellationIfReady() }
        }
    }

    private fun markDartCancellationRequestedIfStopped() {
        if (!isStopped) return
        lifecycle.markCancellationRequested()
    }

    private fun sendDartCancellationIfReady() {
        val localDartTask = dartTask ?: return
        val effect = lifecycle.beginCancellationDispatch() ?: return
        val localFlutterApi = flutterApi

        try {
            localFlutterApi.taskCancelled(localDartTask) { result ->
                result.exceptionOrNull()?.let { exception ->
                    reportDebugIfActive(exception)
                }
            }
        } catch (exception: Exception) {
            reportFailureAndStop(exception)
        } finally {
            finishLifecycleEffect(effect)
        }
    }

    private fun finishLifecycleEffect(
        effect: BackgroundWorkerLifecycleCoordinator<TerminalRequest, ScheduledFuture<*>>.Effect,
    ) {
        val completion = effect.finish()
        completion?.let(::completeTerminal)
    }

    private fun scheduleForcedStop() {
        try {
            // 独立计时线程确保 4 秒时封闭新 effect；终态只等待此前已领取的原生 dispatch 返回。
            lifecycle.scheduleForcedStop {
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
        } catch (exception: Exception) {
            reportFailureAndStop(exception)
        }
    }

    private fun stopEngine(
        result: Result,
        errorMessage: String? = null,
    ) {
        val completion = lifecycle.requestTerminal(TerminalRequest(result, errorMessage))
        completion?.let(::completeTerminal)
    }

    private fun reportFailureAndStop(exception: Throwable) {
        val debugEffect = lifecycle.beginDebugEffect() ?: return
        try {
            WorkmanagerDebug.onExceptionEncountered(applicationContext, null, exception)
        } finally {
            try {
                stopEngine(Result.failure(), exception.message)
            } finally {
                finishLifecycleEffect(debugEffect)
            }
        }
    }

    private fun reportDebugIfActive(exception: Throwable) {
        reportBackgroundWorkerDebugIfActive(
            lifecycle = lifecycle,
            failureOutcome = { reporterFailure ->
                TerminalRequest(Result.failure(), reporterFailure.message)
            },
            report = {
                WorkmanagerDebug.onExceptionEncountered(applicationContext, null, exception)
            },
            completeTerminal = ::completeTerminal,
        )
    }

    private fun completeTerminal(
        completion: BackgroundWorkerTerminalCompletion<TerminalRequest, ScheduledFuture<*>>,
    ) {
        val result = completion.outcome.result
        val errorMessage = completion.outcome.errorMessage
        BackgroundWorkerTerminalFinalizer(
            cancelForcedStop = { completion.forcedStop?.cancel(false) },
            reportFinalStatus = { reportTerminalStatus(result, errorMessage) },
            shutdownScheduler = cancellationScheduler::shutdown,
            detachEngine = { engine.getAndSet(null) },
            scheduleDetachedEngineDestruction = ::scheduleDetachedEngineDestruction,
            completePlatform = { completer.set(result) },
        ).finish()
    }

    private fun reportTerminalStatus(
        result: Result,
        errorMessage: String?,
    ) {
        val localDartTask = dartTask
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

    private fun scheduleDetachedEngineDestruction(detachedEngine: FlutterEngine) {
        // 平台完成后唯一允许迟到的是已脱离 Worker 的引擎主线程销毁。
        mainHandler.post {
            detachedEngine.destroy()
        }
    }
}
