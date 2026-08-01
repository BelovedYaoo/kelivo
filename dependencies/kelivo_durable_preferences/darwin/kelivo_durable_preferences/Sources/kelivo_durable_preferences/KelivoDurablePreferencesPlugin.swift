import Foundation

#if os(iOS)
  import Flutter
#elseif os(macOS)
  import FlutterMacOS
#endif

public final class KelivoDurablePreferencesPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(
      name: "kelivo.durable_preferences",
      binaryMessenger: messenger
    )
    let instance = KelivoDurablePreferencesPlugin(
      store: Result { try makeStore() }
    )
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private static let queue = DispatchQueue(
    label: "kelivo.durable_preferences.io",
    qos: .userInitiated
  )

  private let store: Result<DurablePreferencesFileStore, Error>

  init(store: Result<DurablePreferencesFileStore, Error>) {
    self.store = store
    super.init()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    Self.queue.async { [store] in
      do {
        let value = try Self.handle(call, store: store.get())
        DispatchQueue.main.async {
          result(value)
        }
      } catch {
        let code = (error as? DurablePreferencesError)?.errorDescription
          ?? "kelivo_durable_preferences_native_failure"
        DispatchQueue.main.async {
          result(FlutterError(code: code, message: code, details: nil))
        }
      }
    }
  }

  private static func handle(
    _ call: FlutterMethodCall,
    store: DurablePreferencesFileStore
  ) throws -> Any? {
    switch call.method {
    case "initialize":
      try store.initialize()
      return nil
    case "get-all":
      let filter = try filterArguments(call.arguments)
      return try store.getAll(prefix: filter.prefix, allowList: filter.allowList)
    case "set-value":
      let arguments = try dictionaryArguments(call.arguments)
      guard let key = arguments["key"] as? String,
        let valueType = arguments["valueType"] as? String,
        let value = arguments["value"]
      else {
        throw DurablePreferencesError.unsupportedValue
      }
      try store.set(valueType: valueType, key: key, value: value)
      return nil
    case "remove":
      let arguments = try dictionaryArguments(call.arguments)
      guard let key = arguments["key"] as? String else {
        throw DurablePreferencesError.unsupportedValue
      }
      try store.remove(key: key)
      return nil
    case "clear":
      let filter = try filterArguments(call.arguments)
      try store.clear(prefix: filter.prefix, allowList: filter.allowList)
      return nil
    default:
      return FlutterMethodNotImplemented
    }
  }

  private static func filterArguments(_ value: Any?) throws -> FilterArguments {
    let arguments = try dictionaryArguments(value)
    guard let prefix = arguments["prefix"] as? String else {
      throw DurablePreferencesError.unsupportedValue
    }
    let allowList: Set<String>?
    if let rawAllowList = arguments["allowList"] {
      guard let values = rawAllowList as? [Any], values.allSatisfy({ $0 is String }) else {
        throw DurablePreferencesError.unsupportedValue
      }
      allowList = Set(values.compactMap { $0 as? String })
    } else {
      allowList = nil
    }
    return FilterArguments(prefix: prefix, allowList: allowList)
  }

  private static func dictionaryArguments(_ value: Any?) throws -> [String: Any] {
    guard let arguments = value as? [String: Any] else {
      throw DurablePreferencesError.unsupportedValue
    }
    return arguments
  }

  private static func makeStore() throws -> DurablePreferencesFileStore {
    guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
      throw DurablePreferencesError.bundleIdentifierUnavailable
    }
    guard let applicationSupport = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first else {
      throw DurablePreferencesError.applicationSupportUnavailable
    }
    let directory = applicationSupport.appendingPathComponent(
      "\(bundleIdentifier).kelivo-durable-preferences-v1",
      isDirectory: true
    )
    return DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: SystemLegacyPreferencesAccess(
        bundleIdentifier: bundleIdentifier
      )
    )
  }
}

private struct FilterArguments {
  let prefix: String
  let allowList: Set<String>?
}
