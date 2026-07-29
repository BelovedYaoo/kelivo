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

    private let identifier: String
    private let flutterPluginRegistrantCallback: FlutterPluginRegistrantCallback?
    private let inputData: [String: Any]?
    private let backgroundMode: BackgroundMode
    private let worker: BackgroundWorker

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
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            self.worker.performBackgroundRequest { _ in
                semaphore.signal()
            }
        }

        semaphore.wait()
    }

    override func cancel() {
        worker.requestCancellation()
        super.cancel()
    }
}
