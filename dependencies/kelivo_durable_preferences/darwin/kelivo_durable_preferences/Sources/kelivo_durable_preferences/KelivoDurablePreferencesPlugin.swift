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
    let instance = KelivoDurablePreferencesPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private static let queue = DispatchQueue(
    label: "kelivo.durable_preferences.io",
    qos: .userInitiated
  )

  private var store: Result<DurablePreferencesFileStore, Error>?

  override init() {
    super.init()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    Self.queue.async { [self] in
      do {
        let value = try Self.handle(call, store: self.resolveStore())
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

  private func resolveStore() throws -> DurablePreferencesFileStore {
    if let store {
      return try store.get()
    }
    let created = Result { try Self.makeStore() }
    store = created
    return try created.get()
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
    let libraryDirectory: URL
    let applicationSupportDirectory: URL
    do {
      libraryDirectory = try FileManager.default.url(
        for: .libraryDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: false
      )
      applicationSupportDirectory = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: false
      )
    } catch {
      throw DurablePreferencesError.applicationSupportUnavailable
    }
    let standardizedLibrary = libraryDirectory.standardizedFileURL
    let standardizedApplicationSupport = applicationSupportDirectory.standardizedFileURL
    guard standardizedApplicationSupport.deletingLastPathComponent() == standardizedLibrary else {
      throw DurablePreferencesError.applicationSupportUnavailable
    }
    return try DurablePreferencesFileStore(
      rootDirectory: standardizedLibrary,
      relativeDirectoryComponents: [
        standardizedApplicationSupport.lastPathComponent,
        "\(bundleIdentifier).kelivo-durable-preferences-v1",
      ],
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
