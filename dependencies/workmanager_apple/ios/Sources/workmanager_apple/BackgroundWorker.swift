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

    let backgroundMode: BackgroundMode
    let flutterPluginRegistrantCallback: FlutterPluginRegistrantCallback?
    let inputData: [String: Any]?
    private let cancellationLock = NSLock()
    private var cancellationRequested = false
    private var cancellationNotifier: (() -> Void)?
    private var forceCancellationRequested = false
    private var forceCancellationCompleter: (() -> Void)?

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

    func requestForcedCancellationCleanup() {
        let completer: (() -> Void)?
        cancellationLock.lock()
        forceCancellationRequested = true
        completer = forceCancellationCompleter
        cancellationLock.unlock()
        completer?()
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

    private func clearCancellationHandlers() {
        cancellationLock.lock()
        cancellationNotifier = nil
        forceCancellationCompleter = nil
        cancellationRequested = false
        forceCancellationRequested = false
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
        guard let callbackHandle = UserDefaultsHelper.getStoredCallbackHandle(),
            let flutterCallbackInformation = FlutterCallbackCache.lookupCallbackInformation(
                callbackHandle)
        else {
            logError("[\(String(describing: self))] \(WMPError.workmanagerNotInitialized.message)")
            completionHandler(.failed)
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

        var flutterEngine: FlutterEngine? = FlutterEngine(
            name: backgroundMode.flutterThreadlabelPrefix,
            project: nil,
            allowHeadlessExecution: true
        )

        flutterEngine!.run(
            withEntrypoint: flutterCallbackInformation.callbackName,
            libraryURI: flutterCallbackInformation.callbackLibraryPath
        )
        flutterPluginRegistrantCallback?(flutterEngine!)

        var flutterApi: WorkmanagerFlutterApi? = WorkmanagerFlutterApi(binaryMessenger: flutterEngine!.binaryMessenger)
        let completionLock = NSRecursiveLock()
        var completionDelivered = false

        func claimCompletion() -> Bool {
            completionLock.lock()
            defer { completionLock.unlock() }
            if completionDelivered { return false }
            completionDelivered = true
            return true
        }

        func isCompletionDelivered() -> Bool {
            completionLock.lock()
            defer { completionLock.unlock() }
            return completionDelivered
        }

        func runWhileActive(_ operation: () -> Void) -> Bool {
            completionLock.lock()
            defer { completionLock.unlock() }
            if completionDelivered { return false }
            operation()
            return true
        }

        func cleanupFlutterResources() {
            self.clearCancellationHandlers()
            flutterEngine?.destroyContext()
            flutterApi = nil
            flutterEngine = nil
        }

        self.installForceCancellationCompleter {
            guard claimCompletion() else { return }
            DispatchQueue.main.async {
                cleanupFlutterResources()
                completionHandler(.failed)
            }
        }

        guard !isCompletionDelivered() else { return true }

        // Initialize the background channel and execute the task
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

                // 检查与通道发送必须同锁，避免强制终态穿过二者之间的窗口。
                guard runWhileActive({
                    flutterApi?.executeTask(taskName: taskName, inputData: pigeonInputData) { taskResult in
                        guard claimCompletion() else { return }
                        cleanupFlutterResources()
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
                        completionHandler(fetchResult)
                    }
                }) else { return }
            case .failure(let error):
                guard claimCompletion() else { return }
                logError("Background channel initialization failed: \(error)")
                cleanupFlutterResources()
                completionHandler(UIBackgroundFetchResult.failed)
            }
        }

        return true
    }
}
