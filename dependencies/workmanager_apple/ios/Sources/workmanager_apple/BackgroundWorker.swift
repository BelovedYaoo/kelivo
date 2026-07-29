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

    let backgroundMode: BackgroundMode
    let flutterPluginRegistrantCallback: FlutterPluginRegistrantCallback?
    let inputData: [String: Any]?
    private let cancellationLock = NSLock()
    private var cancellationRequested = false
    private var cancellationNotifier: (() -> Void)?
    private var forceCancellationRequested = false
    private var forceCancellationCompleter: (() -> Void)?
    private var executionClaimed = false
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
        cancellationLock.lock()
        cancellationRequested = true
        notifier = cancellationNotifier
        cancellationLock.unlock()
        if let notifier {
            DispatchQueue.main.async(execute: notifier)
        }
    }

    func requestForcedCancellationCleanup(platformCompletion: () -> Void) {
        let completer: (() -> Void)?
        cancellationLock.lock()
        forceCancellationRequested = true
        completer = forceCancellationCompleter
        cancellationLock.unlock()
        // 先封闭 Worker 终态，避免平台完成后迟到的 Dart 结果反向改写状态。
        completer?()
        platformCompletion()
    }

    private func claimExecution() -> Bool {
        cancellationLock.lock()
        defer { cancellationLock.unlock() }
        guard !forceCancellationRequested, !executionClaimed else { return false }
        executionClaimed = true
        return true
    }

    private func installCancellationNotifier(_ notifier: @escaping () -> Void) -> Bool {
        let shouldNotify: Bool
        cancellationLock.lock()
        if forceCancellationRequested {
            cancellationLock.unlock()
            return false
        }
        cancellationNotifier = notifier
        shouldNotify = cancellationRequested
        cancellationLock.unlock()
        if shouldNotify {
            DispatchQueue.main.async(execute: notifier)
        }
        return true
    }

    private func installForceCancellationCompleter(_ completer: @escaping () -> Void) {
        let shouldComplete: Bool
        cancellationLock.lock()
        forceCancellationCompleter = completer
        shouldComplete = forceCancellationRequested
        cancellationLock.unlock()
        if shouldComplete {
            completer()
        }
    }

    private func installBestEffortCleanup(_ cleanup: @escaping () -> Void) {
        let cleanupToSchedule: (() -> Void)?
        cancellationLock.lock()
        bestEffortCleanup = cleanup
        if cleanupRequested && cleanupReady && !cleanupScheduled {
            cleanupScheduled = true
            cleanupToSchedule = cleanup
        } else {
            cleanupToSchedule = nil
        }
        cancellationLock.unlock()
        if let cleanupToSchedule {
            DispatchQueue.main.async(execute: cleanupToSchedule)
        }
    }

    func requestBestEffortCleanup() {
        let cleanupToSchedule: (() -> Void)?
        cancellationLock.lock()
        cleanupRequested = true
        if cleanupReady, let bestEffortCleanup, !cleanupScheduled {
            cleanupScheduled = true
            cleanupToSchedule = bestEffortCleanup
        } else {
            cleanupToSchedule = nil
        }
        cancellationLock.unlock()
        if let cleanupToSchedule {
            DispatchQueue.main.async(execute: cleanupToSchedule)
        }
    }

    private func markBestEffortCleanupReady() {
        let cleanupToSchedule: (() -> Void)?
        cancellationLock.lock()
        cleanupReady = true
        if cleanupRequested, let bestEffortCleanup, !cleanupScheduled {
            cleanupScheduled = true
            cleanupToSchedule = bestEffortCleanup
        } else {
            cleanupToSchedule = nil
        }
        cancellationLock.unlock()
        if let cleanupToSchedule {
            DispatchQueue.main.async(execute: cleanupToSchedule)
        }
    }

    private func clearCancellationHandlers() {
        cancellationLock.lock()
        cancellationNotifier = nil
        forceCancellationCompleter = nil
        bestEffortCleanup = nil
        cancellationLock.unlock()
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
        let completionLock = NSRecursiveLock()
        var completionDelivered = false
        var legacyFetchDeadline: DispatchWorkItem?

        func isCompletionDelivered() -> Bool {
            completionLock.lock()
            defer { completionLock.unlock() }
            return completionDelivered
        }

        func runWhileActive(_ operation: () -> Void) -> Bool {
            completionLock.lock()
            defer { completionLock.unlock() }
            if completionDelivered { return false }
            // Pigeon 注册必须与终态领取互斥，但锁不跨越异步任务本身。
            operation()
            return true
        }

        func cleanupFlutterResources() {
            self.clearCancellationHandlers()
            flutterEngine?.destroyContext()
            flutterApi = nil
            flutterEngine = nil
        }

        installBestEffortCleanup(cleanupFlutterResources)

        @discardableResult
        func complete(_ result: UIBackgroundFetchResult) -> Bool {
            let pendingDeadline: DispatchWorkItem?
            completionLock.lock()
            if completionDelivered {
                completionLock.unlock()
                return false
            }
            completionDelivered = true
            pendingDeadline = legacyFetchDeadline
            legacyFetchDeadline = nil
            completionLock.unlock()

            pendingDeadline?.cancel()
            // legacy fetch 的回调就是平台终态；Operation 则由 completionBlock 在平台终态后触发清理。
            completionHandler(result)
            markBestEffortCleanupReady()
            if case .backgroundFetch = backgroundMode {
                requestBestEffortCleanup()
            }
            return true
        }

        self.installForceCancellationCompleter {
            complete(.failed)
        }

        if case .backgroundFetch = backgroundMode {
            let deadline = DispatchWorkItem {
                complete(.failed)
            }
            completionLock.lock()
            if !completionDelivered {
                legacyFetchDeadline = deadline
            }
            let shouldScheduleDeadline = !completionDelivered
            completionLock.unlock()
            if shouldScheduleDeadline {
                DispatchQueue.global(qos: .utility).asyncAfter(
                    deadline: .now() + Self.legacyFetchHardBound,
                    execute: deadline
                )
            }
        }

        guard !isCompletionDelivered() else { return false }

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

        WorkmanagerDebug.onTaskStatusUpdate(taskInfo: taskInfo, status: .started)

        guard !isCompletionDelivered() else { return true }
        // 强制终态与主线程启动竞争时，只允许最后领取执行权的一方创建引擎。
        guard claimExecution() else { return false }
        flutterEngine = FlutterEngine(
            name: backgroundMode.flutterThreadlabelPrefix,
            project: nil,
            allowHeadlessExecution: true
        )

        guard !isCompletionDelivered(), let flutterEngine else { return true }
        flutterEngine.run(
            withEntrypoint: flutterCallbackInformation.callbackName,
            libraryURI: flutterCallbackInformation.callbackLibraryPath
        )
        guard !isCompletionDelivered() else { return true }
        flutterPluginRegistrantCallback?(flutterEngine)
        guard !isCompletionDelivered() else { return true }
        flutterApi = WorkmanagerFlutterApi(binaryMessenger: flutterEngine.binaryMessenger)

        // Initialize the background channel and execute the task
        guard runWhileActive({
            flutterApi?.backgroundChannelInitialized { result in
                guard !isCompletionDelivered() else { return }
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
                    guard !isCompletionDelivered() else { return }

                    // 先领取发送权；终态若随后到达，会由一次性 completion 丢弃迟到结果。
                    guard runWhileActive({
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
