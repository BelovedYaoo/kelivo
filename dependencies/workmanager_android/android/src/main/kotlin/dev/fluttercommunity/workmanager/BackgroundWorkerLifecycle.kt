package dev.fluttercommunity.workmanager

internal data class BackgroundWorkerTerminalCompletion<TerminalOutcome, ForcedStop>(
    val outcome: TerminalOutcome,
    val forcedStop: ForcedStop?,
)

internal class BackgroundWorkerLifecycleCoordinator<TerminalOutcome, ForcedStop> {
    private enum class LifecycleState {
        INITIALIZING,
        WAITING_FOR_BACKGROUND_CHANNEL,
        TASK_EXECUTING,
        TERMINAL,
    }

    private enum class CancellationState {
        NONE,
        REQUESTED,
        WAKEUP_POSTED,
        DISPATCH_CLAIMED,
    }

    private data class TerminalRequest<TerminalOutcome>(
        val outcome: TerminalOutcome,
    )

    private val lock = Any()
    private var lifecycleState = LifecycleState.INITIALIZING
    private var cancellationState = CancellationState.NONE
    private var terminalRequest: TerminalRequest<TerminalOutcome>? = null
    private var inFlightEffects = 0
    private var forcedStop: ForcedStop? = null

    internal inner class Effect internal constructor() {
        private var finished = false

        fun finish(): BackgroundWorkerTerminalCompletion<TerminalOutcome, ForcedStop>? =
            synchronized(lock) {
                check(!finished) { "Lifecycle effect was already finished" }
                finished = true
                check(inFlightEffects > 0) { "Lifecycle effect counter underflow" }
                inFlightEffects -= 1
                takeTerminalCompletionLocked()
            }
    }

    fun beginDartExecution(): Effect? =
        beginPhaseEffect(
            expectedState = LifecycleState.INITIALIZING,
            nextState = LifecycleState.WAITING_FOR_BACKGROUND_CHANNEL,
        )

    fun beginTaskExecution(): Effect? =
        beginPhaseEffect(
            expectedState = LifecycleState.WAITING_FOR_BACKGROUND_CHANNEL,
            nextState = LifecycleState.TASK_EXECUTING,
        )

    fun beginDebugEffect(): Effect? =
        synchronized(lock) {
            if (terminalRequest != null || lifecycleState == LifecycleState.TERMINAL) {
                return@synchronized null
            }
            beginEffectLocked()
        }

    fun requestCancellationWakeup(): Boolean =
        synchronized(lock) {
            if (terminalRequest != null || lifecycleState == LifecycleState.TERMINAL) {
                return@synchronized false
            }
            when (cancellationState) {
                CancellationState.NONE,
                CancellationState.REQUESTED,
                -> {
                    cancellationState = CancellationState.WAKEUP_POSTED
                    true
                }
                CancellationState.WAKEUP_POSTED,
                CancellationState.DISPATCH_CLAIMED,
                -> false
            }
        }

    fun markCancellationRequested() {
        synchronized(lock) {
            if (terminalRequest != null || lifecycleState == LifecycleState.TERMINAL) {
                return
            }
            if (cancellationState == CancellationState.NONE) {
                cancellationState = CancellationState.REQUESTED
            }
        }
    }

    fun beginCancellationDispatch(): Effect? =
        synchronized(lock) {
            if (
                terminalRequest != null ||
                    lifecycleState != LifecycleState.TASK_EXECUTING ||
                    cancellationState == CancellationState.NONE ||
                    cancellationState == CancellationState.DISPATCH_CLAIMED
            ) {
                return@synchronized null
            }

            cancellationState = CancellationState.DISPATCH_CLAIMED
            beginEffectLocked()
        }

    fun scheduleForcedStop(createForcedStop: () -> ForcedStop): Boolean =
        synchronized(lock) {
            if (
                terminalRequest != null ||
                    lifecycleState == LifecycleState.TERMINAL ||
                    forcedStop != null
            ) {
                return@synchronized false
            }
            forcedStop = createForcedStop()
            true
        }

    fun requestTerminal(
        outcome: TerminalOutcome,
    ): BackgroundWorkerTerminalCompletion<TerminalOutcome, ForcedStop>? =
        synchronized(lock) {
            if (terminalRequest != null || lifecycleState == LifecycleState.TERMINAL) {
                return@synchronized null
            }
            terminalRequest = TerminalRequest(outcome)
            takeTerminalCompletionLocked()
        }

    private fun beginPhaseEffect(
        expectedState: LifecycleState,
        nextState: LifecycleState,
    ): Effect? =
        synchronized(lock) {
            if (terminalRequest != null || lifecycleState != expectedState) {
                return@synchronized null
            }
            lifecycleState = nextState
            beginEffectLocked()
        }

    private fun beginEffectLocked(): Effect {
        inFlightEffects += 1
        return Effect()
    }

    private fun takeTerminalCompletionLocked(): BackgroundWorkerTerminalCompletion<TerminalOutcome, ForcedStop>? {
        val request = terminalRequest ?: return null
        if (inFlightEffects != 0 || lifecycleState == LifecycleState.TERMINAL) {
            return null
        }

        lifecycleState = LifecycleState.TERMINAL
        terminalRequest = null
        val pendingForcedStop = forcedStop
        forcedStop = null
        return BackgroundWorkerTerminalCompletion(
            outcome = request.outcome,
            forcedStop = pendingForcedStop,
        )
    }
}

internal fun <TerminalOutcome, ForcedStop> reportBackgroundWorkerDebugIfActive(
    lifecycle: BackgroundWorkerLifecycleCoordinator<TerminalOutcome, ForcedStop>,
    failureOutcome: (Throwable) -> TerminalOutcome,
    report: () -> Unit,
    completeTerminal: (BackgroundWorkerTerminalCompletion<TerminalOutcome, ForcedStop>) -> Unit,
) {
    val effect = lifecycle.beginDebugEffect() ?: return
    var reporterFailure: Throwable? = null

    try {
        report()
    } catch (failure: Throwable) {
        reporterFailure = failure
        lifecycle.requestTerminal(failureOutcome(failure))
    } finally {
        try {
            effect.finish()?.let(completeTerminal)
        } catch (completionFailure: Throwable) {
            val originalFailure = reporterFailure
            if (originalFailure == null) {
                throw completionFailure
            }
            if (completionFailure !== originalFailure) {
                originalFailure.addSuppressed(completionFailure)
            }
        }
    }

    reporterFailure?.let { throw it }
}

// 把平台完成留作最后一个同步步骤，同时保证任一前置步骤抛错也不会遗留未完成 Future。
internal class BackgroundWorkerTerminalFinalizer<Engine>(
    private val cancelForcedStop: () -> Unit,
    private val reportFinalStatus: () -> Unit,
    private val shutdownScheduler: () -> Unit,
    private val detachEngine: () -> Engine?,
    private val scheduleDetachedEngineDestruction: (Engine) -> Unit,
    private val completePlatform: () -> Unit,
) {
    fun finish() {
        var detachedEngine: Engine? = null
        try {
            cancelForcedStop()
        } finally {
            try {
                reportFinalStatus()
            } finally {
                try {
                    shutdownScheduler()
                } finally {
                    try {
                        detachedEngine = detachEngine()
                    } finally {
                        try {
                            detachedEngine?.let(scheduleDetachedEngineDestruction)
                        } finally {
                            completePlatform()
                        }
                    }
                }
            }
        }
    }
}
