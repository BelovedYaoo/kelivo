import Foundation
import os

/**
 * A debug handler that outputs debug information to iOS's unified logging system.
 * Note: This class requires iOS 14.0 or later due to the use of os.Logger.
 */
@available(iOS 14.0, *)
public class LoggingDebugHandler: WorkmanagerDebug {
    private let logger = os.Logger(subsystem: "dev.fluttercommunity.workmanager", category: "debug")

    public override init() {}

    override func onTaskStatusUpdate(taskInfo: TaskDebugInfo, status: TaskStatus, result: TaskResult?) {
        switch status {
        case .scheduled:
            logger.debug("Task scheduled")
        case .started:
            logger.debug("Task started")
        case .completed:
            logger.debug("Task completed")
        case .failed:
            logger.error("Task failed")
        case .cancelled:
            logger.info("Task cancelled")
        case .retrying:
            logger.info("Task retrying")
        case .rescheduled:
            logger.info("Task rescheduled")
        }
    }

    override func onExceptionEncountered(taskInfo: TaskDebugInfo?, exception: Error) {
        logger.error("Task exception")
    }
}
