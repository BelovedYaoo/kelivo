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
        notifier?()
    }

    private func installCancellationNotifier(_ notifier: @escaping () -> Void) {
        let shouldNotify: Bool
        cancellationLock.lock()
        cancellationNotifier = notifier
        shouldNotify = cancellationRequested
        cancellationLock.unlock()
        if shouldNotify {
            notifier()
        }
    }

    private func clearCancellationNotifier() {
        cancellationLock.lock()
        cancellationNotifier = nil
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

        func cleanupFlutterResources() {
            self.clearCancellationNotifier()
            flutterEngine?.destroyContext()
            flutterApi = nil
            flutterEngine = nil
        }

        // Initialize the background channel and execute the task
        flutterApi?.backgroundChannelInitialized { result in
            switch result {
            case .success:
                // Get the task name from backgroundMode
                let taskName = self.backgroundMode.onResultSendArguments["\(WorkmanagerPlugin.identifier).DART_TASK"] ?? ""

                // Convert inputData to the format expected by Pigeon
                var pigeonInputData: [String?: Any?]?
                if let inputData = self.inputData {
                    pigeonInputData = Dictionary(uniqueKeysWithValues: inputData.map { ($0.key as String?, $0.value as Any?) })
                }

                self.installCancellationNotifier {
                    flutterApi?.taskCancelled(taskName: taskName) { result in
                        if case .failure(let error) = result {
                            logError("Notify Dart cancellation failed: \(error)")
                        }
                    }
                }

                // Execute the task
                flutterApi?.executeTask(taskName: taskName, inputData: pigeonInputData) { taskResult in
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
            case .failure(let error):
                logError("Background channel initialization failed: \(error)")
                cleanupFlutterResources()
                completionHandler(UIBackgroundFetchResult.failed)
            }
        }

        return true
    }
}
