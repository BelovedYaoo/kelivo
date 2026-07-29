//
//  BackgroundWorker.swift
//  workmanager
//
//  Created by Sebastian Roth on 10/06/2021.
//

import Foundation

#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#else
#error("Unsupported platform.")
#endif

enum BackgroundMode {
    case backgroundFetch
    case backgroundProcessingTask(identifier: String)
    case backgroundPeriodicTask(identifier: String)
    case backgroundOneOffTask(identifier: String)

    var flutterThreadlabelPrefix: String {
        switch self {
        case .backgroundFetch:
            return "\(WorkmanagerPlugin.identifier).BackgroundFetch"
        case .backgroundProcessingTask:
            return "\(WorkmanagerPlugin.identifier).BackgroundProcessingTask"
        case .backgroundPeriodicTask:
            return "\(WorkmanagerPlugin.identifier).BackgroundPeriodicTask"
        case .backgroundOneOffTask:
            return "\(WorkmanagerPlugin.identifier).OneOffTask"
        }
    }

    var onResultSendArguments: [String: String] {
        switch self {
        case .backgroundFetch:
            return ["\(WorkmanagerPlugin.identifier).DART_TASK": "iOSPerformFetch"]
        case let .backgroundProcessingTask(identifier):
            return ["\(WorkmanagerPlugin.identifier).DART_TASK": identifier]
        case let .backgroundPeriodicTask(identifier):
            return ["\(WorkmanagerPlugin.identifier).DART_TASK": identifier]
        case let .backgroundOneOffTask(identifier):
            return ["\(WorkmanagerPlugin.identifier).DART_TASK": identifier]
        }
    }
}

class BackgroundWorker {

    private static let legacyFetchHardBound: TimeInterval = 4

    private enum LifecycleState {
        case pending
        case executing
        case terminal
    }

    let backgroundMode: BackgroundMode
    let flutterPluginRegistrantCallback: FlutterPluginRegistrantCallback?
    let inputData: [String: Any]?
    private let lifecycleLock = NSRecursiveLock()
    private var lifecycleState = LifecycleState.pending
    private var cancellationRequested = false
    private var cancellationNotifier: (() -> Void)?
    private var forceCancellationCompleter: (() -> Void)?
    private var bestEffortCleanup: (() -> Void)?
    private var cleanupRequested = false
    private var cleanupReady = false
    private var cleanupScheduled = false

    init(
        mode: BackgroundMode, inputData: [String: Any]?,
        flutterPluginRegistrantCallback: FlutterPluginRegistrantCallback?
    ) {
        backgroundMode = mode
        self.inputData = inputData
        self.flutterPluginRegistrantCallback = flutterPluginRegistrantCallback
    }

    func requestCancellation() {
        let notifier: (() -> Void)?
        lifecycleLock.lock()
        cancellationRequested = true
        notifier = cancellationNotifier
        lifecycleLock.unlock()
        if let notifier {
            DispatchQueue.main.async(execute: notifier)
        }
    }

    func requestForcedCancellationCleanup(platformCompletion: () -> Void) {
        let completer: (() -> Void)?
        lifecycleLock.lock()
        switch lifecycleState {
        case .terminal:
            completer = nil
        case .pending, .executing:
            lifecycleState = .terminal
            completer = forceCancellationCompleter
            forceCancellationCompleter = nil
            cancellationNotifier = nil
        }
        lifecycleLock.unlock()
        // 先封闭 Worker 终态，避免平台完成后迟到的 Dart 结果反向改写状态。
        completer?()
        platformCompletion()
    }

    private func claimExecution() -> Bool {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        switch lifecycleState {
        case .pending:
            lifecycleState = .executing
            return true
        case .executing, .terminal:
            return false
        }
    }

    private func isExecuting() -> Bool {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        if case .executing = lifecycleState { return true }
        return false
    }

    private func isTerminal() -> Bool {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        if case .terminal = lifecycleState { return true }
        return false
    }

    private func runWhileExecuting(_ operation: () -> Void) -> Bool {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        guard case .executing = lifecycleState else { return false }
        operation()
        return true
    }

    private func installCancellationNotifier(_ notifier: @escaping () -> Void) -> Bool {
        let shouldNotify: Bool
        lifecycleLock.lock()
        guard case .executing = lifecycleState else {
            lifecycleLock.unlock()
            return false
        }
        cancellationNotifier = notifier
        shouldNotify = cancellationRequested
        lifecycleLock.unlock()
        if shouldNotify {
            DispatchQueue.main.async(execute: notifier)
        }
        return true
    }

    private func installForceCancellationCompleter(_ completer: @escaping () -> Void) -> Bool {
        lifecycleLock.lock()
        guard case .pending = lifecycleState else {
            lifecycleLock.unlock()
            return false
        }
        forceCancellationCompleter = completer
        lifecycleLock.unlock()
        return true
    }

    private func installBestEffortCleanup(_ cleanup: @escaping () -> Void) -> Bool {
        let cleanupToSchedule: (() -> Void)?
        lifecycleLock.lock()
        if case .terminal = lifecycleState {
            lifecycleLock.unlock()
            return false
        }
        bestEffortCleanup = cleanup
        if cleanupRequested && cleanupReady && !cleanupScheduled {
            cleanupScheduled = true
            cleanupToSchedule = cleanup
        } else {
            cleanupToSchedule = nil
        }
        lifecycleLock.unlock()
        if let cleanupToSchedule {
            DispatchQueue.main.async(execute: cleanupToSchedule)
        }
        return true
    }

    func requestBestEffortCleanup() {
        let cleanupToSchedule: (() -> Void)?
        lifecycleLock.lock()
        cleanupRequested = true
        if cleanupReady, let bestEffortCleanup, !cleanupScheduled {
            cleanupScheduled = true
            cleanupToSchedule = bestEffortCleanup
        } else {
            cleanupToSchedule = nil
        }
        lifecycleLock.unlock()
        if let cleanupToSchedule {
            DispatchQueue.main.async(execute: cleanupToSchedule)
        }
    }

    private func markBestEffortCleanupReady() {
        let cleanupToSchedule: (() -> Void)?
        lifecycleLock.lock()
        cleanupReady = true
        if cleanupRequested, let bestEffortCleanup, !cleanupScheduled {
            cleanupScheduled = true
            cleanupToSchedule = bestEffortCleanup
        } else {
            cleanupToSchedule = nil
        }
        lifecycleLock.unlock()
        if let cleanupToSchedule {
            DispatchQueue.main.async(execute: cleanupToSchedule)
        }
    }

    private func clearCancellationHandlers() {
        lifecycleLock.lock()
        cancellationNotifier = nil
        forceCancellationCompleter = nil
        bestEffortCleanup = nil
        lifecycleLock.unlock()
    }

    private struct BackgroundChannel {
        static let name = "\(WorkmanagerPlugin.identifier)/background_channel_work_manager"
        static let initialized = "backgroundChannelInitialized"
        static let onResultSendCommand = "onResultSend"
    }

    /// The result is discardable due to how [BackgroundTaskOperation] works.
    @discardableResult
    func performBackgroundRequest(_ completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
        -> Bool {
        var flutterEngine: FlutterEngine?
        var flutterApi: WorkmanagerFlutterApi?
        var legacyFetchDeadline: DispatchWorkItem?

        func finishCompletionDelivery() {
            markBestEffortCleanupReady()
            if case .backgroundFetch = backgroundMode {
                requestBestEffortCleanup()
            }
        }

        func cleanupFlutterResources() {
            self.clearCancellationHandlers()
            flutterEngine?.destroyContext()
            flutterApi = nil
            flutterEngine = nil
        }

        guard installBestEffortCleanup(cleanupFlutterResources) else { return false }

        func deliverForcedCompletion() {
            let pendingDeadline: DispatchWorkItem?
            lifecycleLock.lock()
            pendingDeadline = legacyFetchDeadline
            legacyFetchDeadline = nil
            lifecycleLock.unlock()
            pendingDeadline?.cancel()
            completionHandler(.failed)
            finishCompletionDelivery()
        }

        @discardableResult
        func complete(_ result: UIBackgroundFetchResult) -> Bool {
            let pendingDeadline: DispatchWorkItem?
            lifecycleLock.lock()
            if case .terminal = lifecycleState {
                lifecycleLock.unlock()
                return false
            }
            lifecycleState = .terminal
            forceCancellationCompleter = nil
            cancellationNotifier = nil
            pendingDeadline = legacyFetchDeadline
            legacyFetchDeadline = nil
            pendingDeadline?.cancel()
            // legacy fetch 的回调就是平台终态；Operation 则由 completionBlock 在平台终态后触发清理。
            completionHandler(result)
            lifecycleLock.unlock()
            finishCompletionDelivery()
            return true
        }

        guard self.installForceCancellationCompleter({
            deliverForcedCompletion()
        }) else {
            clearCancellationHandlers()
            return false
        }

        if case .backgroundFetch = backgroundMode {
            let deadline = DispatchWorkItem {
                complete(.failed)
            }
            lifecycleLock.lock()
            if case .pending = lifecycleState {
                legacyFetchDeadline = deadline
            }
            let shouldScheduleDeadline: Bool
            if case .pending = lifecycleState {
                shouldScheduleDeadline = true
            } else {
                shouldScheduleDeadline = false
            }
            lifecycleLock.unlock()
            if shouldScheduleDeadline {
                DispatchQueue.global(qos: .utility).asyncAfter(
                    deadline: .now() + Self.legacyFetchHardBound,
                    execute: deadline
                )
            }
        }

        guard !isTerminal() else { return false }

        guard let callbackHandle = UserDefaultsHelper.getStoredCallbackHandle(),
            let flutterCallbackInformation = FlutterCallbackCache.lookupCallbackInformation(
                callbackHandle)
        else {
            logError("[\(String(describing: self))] \(WMPError.workmanagerNotInitialized.message)")
            complete(.failed)
            return false
        }

        let taskSessionStart = Date()
        let taskSessionIdentifier = UUID()

        let taskInfo = TaskDebugInfo(
            taskName: "background_fetch",
            startTime: taskSessionStart.timeIntervalSince1970,
            callbackHandle: callbackHandle,
            callbackInfo: flutterCallbackInformation.callbackName
        )

        // 领取成功即视为任务已开始；先到的终态会在同一状态锁内拒绝领取。
        guard claimExecution() else { return false }
        flutterEngine = FlutterEngine(
            name: backgroundMode.flutterThreadlabelPrefix,
            project: nil,
            allowHeadlessExecution: true
        )

        guard isExecuting(), let flutterEngine else { return true }
        WorkmanagerDebug.onTaskStatusUpdate(taskInfo: taskInfo, status: .started)
        flutterEngine.run(
            withEntrypoint: flutterCallbackInformation.callbackName,
            libraryURI: flutterCallbackInformation.callbackLibraryPath
        )
        guard isExecuting() else { return true }
        flutterPluginRegistrantCallback?(flutterEngine)
        guard isExecuting() else { return true }
        flutterApi = WorkmanagerFlutterApi(binaryMessenger: flutterEngine.binaryMessenger)

        // Initialize the background channel and execute the task
        guard runWhileExecuting({
            flutterApi?.backgroundChannelInitialized { result in
                guard isExecuting() else { return }
                switch result {
                case .success:
                    // Get the task name from backgroundMode
                    let taskName = self.backgroundMode.onResultSendArguments["\(WorkmanagerPlugin.identifier).DART_TASK"] ?? ""

                    // Convert inputData to the format expected by Pigeon
                    var pigeonInputData: [String?: Any?]?
                    if let inputData = self.inputData {
                        pigeonInputData = Dictionary(uniqueKeysWithValues: inputData.map { ($0.key as String?, $0.value as Any?) })
                    }

                    guard self.installCancellationNotifier({
                        flutterApi?.taskCancelled(taskName: taskName) { result in
                            if case .failure(let error) = result {
                                logError("Notify Dart cancellation failed: \(error)")
                            }
                        }
                    }) else { return }
                    guard isExecuting() else { return }

                    // 先领取发送权；终态若随后到达，会由一次性 completion 丢弃迟到结果。
                    guard runWhileExecuting({
                        flutterApi?.executeTask(taskName: taskName, inputData: pigeonInputData) { taskResult in
                            let taskSessionCompleter = Date()

                            let fetchResult: UIBackgroundFetchResult
                            let status: TaskStatus
                            let errorMessage: String?

                            switch taskResult {
                            case .success(let wasSuccessful):
                                if wasSuccessful {
                                    fetchResult = .newData
                                    status = .completed
                                    errorMessage = nil
                                } else {
                                    fetchResult = .failed
                                    status = .retrying
                                    errorMessage = nil
                                }
                            case .failure(let error):
                                fetchResult = .failed
                                status = .failed
                                errorMessage = error.localizedDescription
                            }

                            guard complete(fetchResult) else { return }
                            let taskDuration = taskSessionCompleter.timeIntervalSince(taskSessionStart)
                            logInfo(
                                "[\(String(describing: self))] \(#function) -> performBackgroundRequest.\(fetchResult) (finished in \(taskDuration.formatToSeconds()))"
                            )

                            let taskResult = TaskResult(
                                success: status == .completed,
                                duration: Int64(taskDuration * 1000), // Convert to milliseconds
                                error: errorMessage
                            )
                            WorkmanagerDebug.onTaskStatusUpdate(taskInfo: taskInfo, status: status, result: taskResult)
                        }
                    }) else { return }
                case .failure(let error):
                    guard complete(.failed) else { return }
                    logError("Background channel initialization failed: \(error)")
                }
            }
        }) else { return true }

        return true
    }
}
