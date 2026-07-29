package dev.fluttercommunity.workmanager

import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class BackgroundWorkerLifecycleCoordinatorTest {
    @Test
    fun `终态先发布时迟到 loader 不能领取副作用`() {
        val lifecycle = BackgroundWorkerLifecycleCoordinator<String, String>()
        val terminalPublished = CountDownLatch(1)
        val executor = Executors.newFixedThreadPool(2)

        try {
            val terminal =
                executor.submit<BackgroundWorkerTerminalCompletion<String, String>?> {
                    lifecycle.requestTerminal("timeout").also {
                        terminalPublished.countDown()
                    }
                }
            val lateLoader =
                executor.submit<Any?> {
                    assertTrue(terminalPublished.await(1, TimeUnit.SECONDS))
                    lifecycle.beginDartExecution()
                }

            assertEquals("timeout", assertNotNull(terminal.get()).outcome)
            assertNull(lateLoader.get())
        } finally {
            executor.shutdownNow()
        }
    }

    @Test
    fun `副作用先领取时终态等待最后一个 effect 归还`() {
        val lifecycle = BackgroundWorkerLifecycleCoordinator<String, String>()
        val dartEffect = assertNotNull(lifecycle.beginDartExecution())
        val executor = Executors.newSingleThreadExecutor()

        try {
            val terminal = executor.submit { lifecycle.requestTerminal("timeout") }

            assertNull(terminal.get())
            assertEquals("timeout", assertNotNull(dartEffect.finish()).outcome)
            assertNull(lifecycle.beginTaskExecution())
        } finally {
            executor.shutdownNow()
        }
    }

    @Test
    fun `取消回复迟于终态时静默跳过 debug`() {
        val lifecycle = runningTaskLifecycle()
        val terminal = assertNotNull(lifecycle.requestTerminal("finished"))
        val debugCalls = AtomicInteger()
        val executor = Executors.newSingleThreadExecutor()

        try {
            val lateReply =
                executor.submit {
                    lifecycle.beginDebugEffect()?.let { effect ->
                        try {
                            debugCalls.incrementAndGet()
                        } finally {
                            effect.finish()
                        }
                    }
                }

            lateReply.get()
            assertEquals("finished", terminal.outcome)
            assertEquals(0, debugCalls.get())
        } finally {
            executor.shutdownNow()
        }
    }

    @Test
    fun `debug 抛错仍请求终态并归还 effect`() {
        val lifecycle = BackgroundWorkerLifecycleCoordinator<String, String>()
        val debugEffect = assertNotNull(lifecycle.beginDebugEffect())
        var terminal: BackgroundWorkerTerminalCompletion<String, String>? = null

        assertFailsWith<IllegalStateException> {
            try {
                throw IllegalStateException("debug-failed")
            } finally {
                assertNull(lifecycle.requestTerminal("failed"))
                terminal = debugEffect.finish()
            }
        }

        assertEquals("failed", assertNotNull(terminal).outcome)
    }

    @Test
    fun `取消 dispatch 仅能领取一次`() {
        val lifecycle = runningTaskLifecycle()

        assertTrue(lifecycle.requestCancellationWakeup())
        assertFalse(lifecycle.requestCancellationWakeup())
        val cancellationEffect = assertNotNull(lifecycle.beginCancellationDispatch())
        assertNull(lifecycle.beginCancellationDispatch())
        assertNull(cancellationEffect.finish())
    }

    @Test
    fun `completer 前完成状态上报关闭与引擎脱离`() {
        val events = mutableListOf<String>()
        var workerEngine: String? = "engine-a"
        var detachedCleanup: (() -> Unit)? = null
        val finalizer =
            BackgroundWorkerTerminalFinalizer(
                cancelForcedStop = { events += "cancel-timeout" },
                reportFinalStatus = { events += "final-status" },
                shutdownScheduler = { events += "shutdown" },
                detachEngine = {
                    events += "detach"
                    workerEngine.also { workerEngine = null }
                },
                scheduleDetachedEngineDestruction = { detachedEngine ->
                    events += "schedule-destroy:$detachedEngine"
                    detachedCleanup = { events += "destroy:$detachedEngine" }
                },
                completePlatform = { events += "complete" },
            )

        finalizer.finish()

        assertEquals(
            listOf(
                "cancel-timeout",
                "final-status",
                "shutdown",
                "detach",
                "schedule-destroy:engine-a",
                "complete",
            ),
            events,
        )
        workerEngine = "engine-b"
        assertNotNull(detachedCleanup).invoke()
        assertEquals("destroy:engine-a", events.last())
        assertEquals("engine-b", workerEngine)
    }

    @Test
    fun `终态前置步骤抛错仍以 completer 作为最后同步操作`() {
        val failingSteps =
            listOf("cancel-timeout", "final-status", "shutdown", "detach", "schedule-destroy")

        for (failingStep in failingSteps) {
            val events = mutableListOf<String>()
            fun record(step: String) {
                events += step
                if (step == failingStep) {
                    throw IllegalStateException(step)
                }
            }

            val finalizer =
                BackgroundWorkerTerminalFinalizer(
                    cancelForcedStop = { record("cancel-timeout") },
                    reportFinalStatus = { record("final-status") },
                    shutdownScheduler = { record("shutdown") },
                    detachEngine = {
                        record("detach")
                        "engine"
                    },
                    scheduleDetachedEngineDestruction = { record("schedule-destroy") },
                    completePlatform = { events += "complete" },
                )

            assertFailsWith<IllegalStateException> { finalizer.finish() }
            assertEquals("complete", events.last(), failingStep)
            assertEquals(1, events.count { it == "complete" }, failingStep)
        }
    }

    private fun runningTaskLifecycle(): BackgroundWorkerLifecycleCoordinator<String, String> {
        val lifecycle = BackgroundWorkerLifecycleCoordinator<String, String>()
        assertNull(assertNotNull(lifecycle.beginDartExecution()).finish())
        assertNull(assertNotNull(lifecycle.beginTaskExecution()).finish())
        return lifecycle
    }
}
