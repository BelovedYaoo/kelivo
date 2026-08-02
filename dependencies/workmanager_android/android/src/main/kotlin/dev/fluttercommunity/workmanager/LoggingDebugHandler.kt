package dev.fluttercommunity.workmanager

import android.content.Context
import android.util.Log
import dev.fluttercommunity.workmanager.pigeon.TaskStatus

/**
 * A debug handler that outputs debug information to Android's Log system.
 */
class LoggingDebugHandler : WorkmanagerDebug() {
    companion object {
        private const val TAG = "WorkmanagerDebug"
    }

    override fun onTaskStatusUpdate(
        context: Context,
        taskInfo: TaskDebugInfo,
        status: TaskStatus,
        result: TaskResult?,
    ) {
        when (status) {
            TaskStatus.SCHEDULED -> Log.d(TAG, "Task scheduled")
            TaskStatus.STARTED -> Log.d(TAG, "Task started")
            TaskStatus.COMPLETED -> Log.d(TAG, "Task completed")
            TaskStatus.FAILED -> Log.e(TAG, "Task failed")
            TaskStatus.CANCELLED -> Log.w(TAG, "Task cancelled")
            TaskStatus.RETRYING -> Log.w(TAG, "Task retrying")
            TaskStatus.RESCHEDULED -> Log.w(TAG, "Task rescheduled")
        }
    }

    override fun onExceptionEncountered(
        context: Context,
        taskInfo: TaskDebugInfo?,
        exception: Throwable,
    ) {
        Log.e(TAG, "Task exception")
    }
}
