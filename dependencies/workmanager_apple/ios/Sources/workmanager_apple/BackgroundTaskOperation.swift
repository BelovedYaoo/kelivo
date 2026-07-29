//
//  BackgroundTaskOperation.swift
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

class BackgroundTaskOperation: Operation, @unchecked Sendable {

    private static let cancellationGrace: TimeInterval = 4

    private let identifier: String
    private let flutterPluginRegistrantCallback: FlutterPluginRegistrantCallback?
    private let inputData: [String: Any]?
    private let backgroundMode: BackgroundMode
    private let worker: BackgroundWorker
    private let completionSemaphore = DispatchSemaphore(value: 0)
    private let lifecycleLock = NSLock()
    private var completed = false
    private var forcedCancellation: DispatchWorkItem?
    private var backgroundResult = UIBackgroundFetchResult.failed

    var wasSuccessful: Bool {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        return completed && !isCancelled && backgroundResult != .failed
    }

    init(_ identifier: String,
         inputData: [String: Any]?,
         flutterPluginRegistrantCallback: FlutterPluginRegistrantCallback?,
         backgroundMode: BackgroundMode) {
        self.identifier = identifier
        self.inputData = inputData
        self.flutterPluginRegistrantCallback = flutterPluginRegistrantCallback
        self.backgroundMode = backgroundMode
        self.worker = BackgroundWorker(
            mode: backgroundMode,
            inputData: inputData,
            flutterPluginRegistrantCallback: flutterPluginRegistrantCallback
        )
        super.init()
    }

    override func main() {
        DispatchQueue.main.async {
            self.worker.performBackgroundRequest { result in
                self.finish(result: result)
            }
        }

        completionSemaphore.wait()
    }

    override func cancel() {
        super.cancel()
        DispatchQueue.main.async {
            self.worker.requestCancellation()
        }
        let forcedCancellation = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.worker.requestForcedCancellationCleanup {
                self.finish()
            }
        }
        lifecycleLock.lock()
        if completed || self.forcedCancellation != nil {
            lifecycleLock.unlock()
            return
        }
        self.forcedCancellation = forcedCancellation
        lifecycleLock.unlock()
        // 平台任务必须独立于主线程和引擎销毁完成，避免系统取消永久占用执行槽。
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + Self.cancellationGrace,
            execute: forcedCancellation
        )
    }

    func requestBestEffortCleanup() {
        worker.requestBestEffortCleanup()
    }

    private func finish() {
        finish(result: .failed)
    }

    private func finish(result: UIBackgroundFetchResult) {
        let pendingCancellation: DispatchWorkItem?
        lifecycleLock.lock()
        if completed {
            lifecycleLock.unlock()
            return
        }
        completed = true
        backgroundResult = result
        pendingCancellation = forcedCancellation
        forcedCancellation = nil
        lifecycleLock.unlock()
        pendingCancellation?.cancel()
        completionSemaphore.signal()
    }
}
