import CoreFoundation
import Darwin
import Foundation

enum DurablePreferencesError: Error, LocalizedError {
  case directoryUnsafe
  case fileUnsafe
  case openFailed(operation: String, errno: Int32)
  case lockFailed(errno: Int32)
  case readFailed(errno: Int32)
  case writeFailed(errno: Int32)
  case fileSyncFailed(errno: Int32)
  case directorySyncFailed(errno: Int32)
  case renameFailed(errno: Int32)
  case snapshotInvalid
  case snapshotTooLarge
  case verificationFailed
  case legacyPreferencesContaminated
  case unsupportedValue
  case bundleIdentifierUnavailable
  case applicationSupportUnavailable

  var errorDescription: String? {
    switch self {
    case .directoryUnsafe:
      return "kelivo_durable_preferences_directory_unsafe"
    case .fileUnsafe:
      return "kelivo_durable_preferences_file_unsafe"
    case .openFailed(let operation, let code):
      return "kelivo_durable_preferences_\(operation)_open_failed_\(code)"
    case .lockFailed(let code):
      return "kelivo_durable_preferences_lock_failed_\(code)"
    case .readFailed(let code):
      return "kelivo_durable_preferences_read_failed_\(code)"
    case .writeFailed(let code):
      return "kelivo_durable_preferences_write_failed_\(code)"
    case .fileSyncFailed(let code):
      return "kelivo_durable_preferences_file_sync_failed_\(code)"
    case .directorySyncFailed(let code):
      return "kelivo_durable_preferences_directory_sync_failed_\(code)"
    case .renameFailed(let code):
      return "kelivo_durable_preferences_rename_failed_\(code)"
    case .snapshotInvalid:
      return "kelivo_durable_preferences_snapshot_invalid"
    case .snapshotTooLarge:
      return "kelivo_durable_preferences_snapshot_too_large"
    case .verificationFailed:
      return "kelivo_durable_preferences_verification_failed"
    case .legacyPreferencesContaminated:
      return "kelivo_durable_preferences_legacy_container_reset_required"
    case .unsupportedValue:
      return "kelivo_durable_preferences_unsupported_value"
    case .bundleIdentifierUnavailable:
      return "kelivo_durable_preferences_bundle_identifier_unavailable"
    case .applicationSupportUnavailable:
      return "kelivo_durable_preferences_application_support_unavailable"
    }
  }
}

protocol PreferencesDurability {
  func syncFileDescriptor(_ descriptor: Int32) throws
  func syncDirectoryDescriptor(_ descriptor: Int32) throws
}

struct DarwinPreferencesDurability: PreferencesDurability {
  func syncFileDescriptor(_ descriptor: Int32) throws {
    guard Darwin.fcntl(descriptor, F_FULLFSYNC) == 0 else {
      throw DurablePreferencesError.fileSyncFailed(errno: errno)
    }
  }

  func syncDirectoryDescriptor(_ descriptor: Int32) throws {
    guard Darwin.fsync(descriptor) == 0 else {
      throw DurablePreferencesError.directorySyncFailed(errno: errno)
    }
  }
}

protocol LegacyPreferencesAccess: AnyObject {
  func contaminatedKeys() -> Set<String>
  func bestEffortRemove(keys: Set<String>)
}

final class SystemLegacyPreferencesAccess: LegacyPreferencesAccess {
  init(bundleIdentifier: String) {
    self.bundleIdentifier = bundleIdentifier
  }

  private let bundleIdentifier: String

  func contaminatedKeys() -> Set<String> {
    let domain = UserDefaults.standard.persistentDomain(forName: bundleIdentifier) ?? [:]
    return Set(domain.keys.filter(Self.isLegacyManagedKey))
  }

  func bestEffortRemove(keys: Set<String>) {
    let defaults = UserDefaults.standard
    for key in keys {
      defaults.removeObject(forKey: key)
    }
    // 这里只减少旧容器残留，不把 CFPreferences 的返回值当作耐久证明；
    // 污染标记已经先写入自有 store，并会永久阻断到容器被清空。
    _ = CFPreferencesAppSynchronize(bundleIdentifier as CFString)
  }

  private static func isLegacyManagedKey(_ key: String) -> Bool {
    key.hasPrefix("flutter.") || key.hasPrefix("kelivo.account.")
  }
}

final class DurablePreferencesFileStore {
  init(
    directory: URL,
    durability: PreferencesDurability,
    legacyPreferences: LegacyPreferencesAccess
  ) {
    self.directory = directory
    self.durability = durability
    self.legacyPreferences = legacyPreferences
  }

  static let snapshotFileName = "preferences-v1.json"
  static let temporaryFilePrefix = ".preferences-v1.tmp."

  private static let lockFileName = ".preferences-v1.lock"
  private static let formatVersion = 1
  // 偏好不是大对象存储；限制损坏文件的内存放大，同时覆盖正常配置规模。
  private static let maximumSnapshotBytes = 16 * 1024 * 1024

  private let directory: URL
  private let durability: PreferencesDurability
  private let legacyPreferences: LegacyPreferencesAccess
  private let fileManager = FileManager.default

  private var snapshotURL: URL {
    directory.appendingPathComponent(Self.snapshotFileName, isDirectory: false)
  }

  func initialize() throws {
    try withExclusiveLock {
      var snapshot = try readSnapshot() ?? Snapshot.empty
      let legacyKeys = legacyPreferences.contaminatedKeys()
      if snapshot.legacyContaminated || !legacyKeys.isEmpty {
        if !snapshot.legacyContaminated {
          snapshot.legacyContaminated = true
          try persist(snapshot)
        }
        legacyPreferences.bestEffortRemove(keys: legacyKeys)
        throw DurablePreferencesError.legacyPreferencesContaminated
      }
      if !fileManager.fileExists(atPath: snapshotURL.path) {
        try persist(snapshot)
      }
    }
  }

  func getAll(prefix: String, allowList: Set<String>?) throws -> [String: Any] {
    try withExclusiveLock {
      let snapshot = try requireUsableSnapshot()
      var values: [String: Any] = [:]
      for (key, value) in snapshot.values
      where key.hasPrefix(prefix) && (allowList == nil || allowList!.contains(key)) {
        values[key] = value
      }
      return values
    }
  }

  func set(valueType: String, key: String, value: Any) throws {
    try withExclusiveLock {
      var snapshot = try requireUsableSnapshot()
      snapshot.values[key] = try normalized(value: value, valueType: valueType)
      try persist(snapshot)
    }
  }

  func remove(key: String) throws {
    try withExclusiveLock {
      var snapshot = try requireUsableSnapshot()
      snapshot.values.removeValue(forKey: key)
      try persist(snapshot)
      let reopened = try requireUsableSnapshot()
      guard reopened.values[key] == nil else {
        throw DurablePreferencesError.verificationFailed
      }
    }
  }

  func clear(prefix: String, allowList: Set<String>?) throws {
    try withExclusiveLock {
      var snapshot = try requireUsableSnapshot()
      snapshot.values = snapshot.values.filter { key, _ in
        !key.hasPrefix(prefix) || (allowList != nil && !allowList!.contains(key))
      }
      try persist(snapshot)
      let reopened = try requireUsableSnapshot()
      let hasResidual = reopened.values.keys.contains { key in
        key.hasPrefix(prefix) && (allowList == nil || allowList!.contains(key))
      }
      guard !hasResidual else {
        throw DurablePreferencesError.verificationFailed
      }
    }
  }

  private func withExclusiveLock<Result>(_ operation: () throws -> Result) throws -> Result {
    try ensureDirectory()
    let lockURL = directory.appendingPathComponent(Self.lockFileName, isDirectory: false)
    let descriptor = try openFile(
      at: lockURL,
      flags: O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW,
      mode: mode_t(S_IRUSR | S_IWUSR),
      operation: "lock"
    )
    defer { Darwin.close(descriptor) }
    // 上一次可能已完成目录变更但在 barrier 返回前失败；每次重试都先确认目录，
    // 不能依据当前目录项是否存在来推断之前已经耐久。
    try syncDirectory()
    guard Darwin.flock(descriptor, LOCK_EX) == 0 else {
      throw DurablePreferencesError.lockFailed(errno: errno)
    }
    defer { Darwin.flock(descriptor, LOCK_UN) }

    try removeStaleTemporaryFiles()
    return try operation()
  }

  private func ensureDirectory() throws {
    let existingMode = try entityMode(at: directory)
    if existingMode == nil {
      try fileManager.createDirectory(
        at: directory,
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700]
      )
      guard try entityMode(at: directory).map(isDirectoryMode) == true else {
        throw DurablePreferencesError.directoryUnsafe
      }
      try syncDirectory(at: directory.deletingLastPathComponent())
      try syncDirectory()
      return
    }
    guard existingMode.map(isDirectoryMode) == true else {
      throw DurablePreferencesError.directoryUnsafe
    }
  }

  private func removeStaleTemporaryFiles() throws {
    let children = try fileManager.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil,
      options: []
    )
    var removed = false
    for child in children where child.lastPathComponent.hasPrefix(Self.temporaryFilePrefix) {
      guard try entityMode(at: child).map(isRegularFileMode) == true else {
        throw DurablePreferencesError.fileUnsafe
      }
      guard Darwin.unlink(child.path) == 0 else {
        throw DurablePreferencesError.writeFailed(errno: errno)
      }
      removed = true
    }
    if removed {
      try syncDirectory()
    }
  }

  private func requireUsableSnapshot() throws -> Snapshot {
    guard let snapshot = try readSnapshot() else {
      throw DurablePreferencesError.snapshotInvalid
    }
    guard !snapshot.legacyContaminated else {
      throw DurablePreferencesError.legacyPreferencesContaminated
    }
    return snapshot
  }

  private func readSnapshot() throws -> Snapshot? {
    guard let mode = try entityMode(at: snapshotURL) else {
      return nil
    }
    guard isRegularFileMode(mode) else {
      throw DurablePreferencesError.fileUnsafe
    }
    return try decodeSnapshot(readFile(at: snapshotURL))
  }

  private func persist(_ snapshot: Snapshot) throws {
    let encoded = try encodeSnapshot(snapshot)
    let temporaryURL = directory.appendingPathComponent(
      "\(Self.temporaryFilePrefix)\(UUID().uuidString)",
      isDirectory: false
    )
    let descriptor = try openFile(
      at: temporaryURL,
      flags: O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
      mode: mode_t(S_IRUSR | S_IWUSR),
      operation: "temporary"
    )
    var descriptorOpen = true
    var temporaryExists = true
    defer {
      if descriptorOpen {
        Darwin.close(descriptor)
      }
      if temporaryExists {
        Darwin.unlink(temporaryURL.path)
      }
    }

    try writeAll(encoded, to: descriptor)
    try durability.syncFileDescriptor(descriptor)
    guard Darwin.close(descriptor) == 0 else {
      descriptorOpen = false
      throw DurablePreferencesError.writeFailed(errno: errno)
    }
    descriptorOpen = false

    if let destinationMode = try entityMode(at: snapshotURL),
      !isRegularFileMode(destinationMode)
    {
      throw DurablePreferencesError.fileUnsafe
    }
    let renameResult = temporaryURL.path.withCString { source in
      snapshotURL.path.withCString { destination in
        Darwin.rename(source, destination)
      }
    }
    guard renameResult == 0 else {
      throw DurablePreferencesError.renameFailed(errno: errno)
    }
    temporaryExists = false
    try syncDirectory()

    let reopened = try readFile(at: snapshotURL)
    guard reopened == encoded else {
      throw DurablePreferencesError.verificationFailed
    }
    _ = try decodeSnapshot(reopened)
  }

  private func encodeSnapshot(_ snapshot: Snapshot) throws -> Data {
    let object: [String: Any] = [
      "formatVersion": Self.formatVersion,
      "legacyContaminated": snapshot.legacyContaminated,
      "values": snapshot.values,
    ]
    guard JSONSerialization.isValidJSONObject(object) else {
      throw DurablePreferencesError.unsupportedValue
    }
    return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
  }

  private func decodeSnapshot(_ data: Data) throws -> Snapshot {
    guard data.count <= Self.maximumSnapshotBytes else {
      throw DurablePreferencesError.snapshotTooLarge
    }
    let decoded: Any
    do {
      decoded = try JSONSerialization.jsonObject(with: data)
    } catch {
      throw DurablePreferencesError.snapshotInvalid
    }
    guard let object = decoded as? [String: Any],
      Set(object.keys) == Set(["formatVersion", "legacyContaminated", "values"]),
      let version = object["formatVersion"] as? NSNumber,
      CFGetTypeID(version) != CFBooleanGetTypeID(),
      version.intValue == Self.formatVersion,
      version.doubleValue == Double(Self.formatVersion),
      let contaminatedNumber = object["legacyContaminated"] as? NSNumber,
      CFGetTypeID(contaminatedNumber) == CFBooleanGetTypeID(),
      let values = object["values"] as? [String: Any]
    else {
      throw DurablePreferencesError.snapshotInvalid
    }
    for value in values.values where !isSupportedSnapshotValue(value) {
      throw DurablePreferencesError.snapshotInvalid
    }
    return Snapshot(
      legacyContaminated: contaminatedNumber.boolValue,
      values: values
    )
  }

  private func normalized(value: Any, valueType: String) throws -> Any {
    switch valueType {
    case "Bool":
      guard let number = value as? NSNumber,
        CFGetTypeID(number) == CFBooleanGetTypeID()
      else {
        throw DurablePreferencesError.unsupportedValue
      }
      return number.boolValue
    case "Double":
      guard let number = value as? NSNumber,
        CFGetTypeID(number) != CFBooleanGetTypeID(),
        isFloatingPointNumber(number),
        number.doubleValue.isFinite
      else {
        throw DurablePreferencesError.unsupportedValue
      }
      return number.doubleValue
    case "Int":
      guard let number = value as? NSNumber,
        CFGetTypeID(number) != CFBooleanGetTypeID(),
        !isFloatingPointNumber(number)
      else {
        throw DurablePreferencesError.unsupportedValue
      }
      return number.int64Value
    case "String":
      guard let string = value as? String else {
        throw DurablePreferencesError.unsupportedValue
      }
      return string
    case "StringList":
      guard let list = value as? [Any], list.allSatisfy({ $0 is String }) else {
        throw DurablePreferencesError.unsupportedValue
      }
      return list.compactMap { $0 as? String }
    default:
      throw DurablePreferencesError.unsupportedValue
    }
  }

  private func isSupportedSnapshotValue(_ value: Any) -> Bool {
    if value is String {
      return true
    }
    if let number = value as? NSNumber {
      return CFGetTypeID(number) == CFBooleanGetTypeID() || number.doubleValue.isFinite
    }
    if let list = value as? [Any] {
      return list.allSatisfy { $0 is String }
    }
    return false
  }

  private func isFloatingPointNumber(_ value: NSNumber) -> Bool {
    let encoding = String(cString: value.objCType)
    return encoding == "f" || encoding == "d"
  }

  private func readFile(at url: URL) throws -> Data {
    let descriptor = try openFile(
      at: url,
      flags: O_RDONLY | O_CLOEXEC | O_NOFOLLOW,
      mode: 0,
      operation: "snapshot"
    )
    defer { Darwin.close(descriptor) }
    var info = stat()
    guard Darwin.fstat(descriptor, &info) == 0, isRegularFileMode(info.st_mode) else {
      throw DurablePreferencesError.fileUnsafe
    }
    guard info.st_size >= 0,
      info.st_size <= off_t(Self.maximumSnapshotBytes)
    else {
      throw DurablePreferencesError.snapshotTooLarge
    }

    var data = Data()
    data.reserveCapacity(Int(info.st_size))
    var buffer = [UInt8](repeating: 0, count: 8192)
    while true {
      let count = buffer.withUnsafeMutableBytes { rawBuffer in
        Darwin.read(descriptor, rawBuffer.baseAddress, rawBuffer.count)
      }
      if count == 0 {
        break
      }
      if count < 0 {
        if errno == EINTR {
          continue
        }
        throw DurablePreferencesError.readFailed(errno: errno)
      }
      guard data.count + count <= Self.maximumSnapshotBytes else {
        throw DurablePreferencesError.snapshotTooLarge
      }
      data.append(contentsOf: buffer[0..<count])
    }
    return data
  }

  private func writeAll(_ data: Data, to descriptor: Int32) throws {
    try data.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) in
      guard let baseAddress = rawBuffer.baseAddress else {
        return
      }
      var offset = 0
      while offset < rawBuffer.count {
        let count = Darwin.write(
          descriptor,
          baseAddress.advanced(by: offset),
          rawBuffer.count - offset
        )
        if count < 0 {
          if errno == EINTR {
            continue
          }
          throw DurablePreferencesError.writeFailed(errno: errno)
        }
        guard count > 0 else {
          throw DurablePreferencesError.writeFailed(errno: EIO)
        }
        offset += count
      }
    }
  }

  private func syncDirectory() throws {
    try syncDirectory(at: directory)
  }

  private func syncDirectory(at url: URL) throws {
    let descriptor = try openFile(
      at: url,
      flags: O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW,
      mode: 0,
      operation: "directory"
    )
    defer { Darwin.close(descriptor) }
    try durability.syncDirectoryDescriptor(descriptor)
  }

  private func openFile(
    at url: URL,
    flags: Int32,
    mode: mode_t,
    operation: String
  ) throws -> Int32 {
    let descriptor = url.path.withCString { path in
      Darwin.open(path, flags, mode)
    }
    guard descriptor >= 0 else {
      throw DurablePreferencesError.openFailed(operation: operation, errno: errno)
    }
    return descriptor
  }

  private func entityMode(at url: URL) throws -> mode_t? {
    var info = stat()
    let result = url.path.withCString { path in
      Darwin.lstat(path, &info)
    }
    if result == 0 {
      return info.st_mode
    }
    if errno == ENOENT {
      return nil
    }
    throw DurablePreferencesError.openFailed(operation: "metadata", errno: errno)
  }

  private func isDirectoryMode(_ mode: mode_t) -> Bool {
    (mode & mode_t(S_IFMT)) == mode_t(S_IFDIR)
  }

  private func isRegularFileMode(_ mode: mode_t) -> Bool {
    (mode & mode_t(S_IFMT)) == mode_t(S_IFREG)
  }
}

private struct Snapshot {
  static let empty = Snapshot(legacyContaminated: false, values: [:])

  var legacyContaminated: Bool
  var values: [String: Any]
}
