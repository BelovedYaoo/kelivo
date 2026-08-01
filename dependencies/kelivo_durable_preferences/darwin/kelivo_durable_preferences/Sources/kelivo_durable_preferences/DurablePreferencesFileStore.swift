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
  case barrierSyncFailed(errno: Int32)
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
    case .barrierSyncFailed(let code):
      return "kelivo_durable_preferences_barrier_sync_failed_\(code)"
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
  func syncBarrierFileDescriptor(_ descriptor: Int32) throws
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

  func syncBarrierFileDescriptor(_ descriptor: Int32) throws {
    guard Darwin.fcntl(descriptor, F_FULLFSYNC) == 0 else {
      throw DurablePreferencesError.barrierSyncFailed(errno: errno)
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
  convenience init(
    directory: URL,
    durability: PreferencesDurability,
    legacyPreferences: LegacyPreferencesAccess
  ) throws {
    let standardizedDirectory = directory.standardizedFileURL
    let parentURL = standardizedDirectory.deletingLastPathComponent()
    let directoryName = standardizedDirectory.lastPathComponent
    guard !directoryName.isEmpty,
      directoryName != ".",
      directoryName != "..",
      !directoryName.contains("/"),
      parentURL.appendingPathComponent(directoryName, isDirectory: true).standardizedFileURL
        == standardizedDirectory
    else {
      throw DurablePreferencesError.directoryUnsafe
    }

    try self.init(
      rootDirectory: parentURL,
      relativeDirectoryComponents: [directoryName],
      durability: durability,
      legacyPreferences: legacyPreferences
    )
  }

  init(
    rootDirectory: URL,
    relativeDirectoryComponents: [String],
    durability: PreferencesDurability,
    legacyPreferences: LegacyPreferencesAccess
  ) throws {
    guard rootDirectory.isFileURL,
      !relativeDirectoryComponents.isEmpty,
      relativeDirectoryComponents.allSatisfy(Self.isSafeEntryName)
    else {
      throw DurablePreferencesError.directoryUnsafe
    }

    let rootDescriptor = try Self.openAbsoluteDirectory(
      at: rootDirectory.standardizedFileURL
    )
    var directoryDescriptors = [rootDescriptor]
    var barrierDescriptor: Int32 = -1
    var descriptorsTransferred = false
    defer {
      if !descriptorsTransferred {
        if barrierDescriptor >= 0 {
          Darwin.close(barrierDescriptor)
        }
        for descriptor in directoryDescriptors.reversed() {
          Darwin.close(descriptor)
        }
      }
    }

    var rootInfo = stat()
    guard Darwin.fstat(rootDescriptor, &rootInfo) == 0,
      Self.isDirectoryMode(rootInfo.st_mode)
    else {
      throw DurablePreferencesError.directoryUnsafe
    }

    for (index, directoryName) in relativeDirectoryComponents.enumerated() {
      guard let parentDescriptor = directoryDescriptors.last else {
        throw DurablePreferencesError.directoryUnsafe
      }
      let createResult = directoryName.withCString { name in
        Darwin.mkdirat(
          parentDescriptor,
          name,
          mode_t(S_IRUSR | S_IWUSR | S_IXUSR)
        )
      }
      if createResult != 0 && errno != EEXIST {
        throw DurablePreferencesError.openFailed(
          operation: "directory-create",
          errno: errno
        )
      }

      let directoryDescriptor = try Self.openRelativeDirectory(
        parentDescriptor: parentDescriptor,
        name: directoryName
      )
      directoryDescriptors.append(directoryDescriptor)
      try Self.requireSameDirectory(
        parentDescriptor: parentDescriptor,
        directoryName: directoryName,
        directoryDescriptor: directoryDescriptor
      )
      var directoryInfo = stat()
      guard Darwin.fstat(directoryDescriptor, &directoryInfo) == 0,
        Self.isDirectoryMode(directoryInfo.st_mode),
        rootInfo.st_dev == directoryInfo.st_dev
      else {
        throw DurablePreferencesError.directoryUnsafe
      }

      let currentBarrierDescriptor = try Self.openRelativeFile(
        directoryDescriptor: directoryDescriptor,
        named: Self.barrierFileName,
        flags: O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW,
        mode: mode_t(S_IRUSR | S_IWUSR),
        operation: "barrier"
      )
      var barrierTransferred = false
      defer {
        if !barrierTransferred {
          Darwin.close(currentBarrierDescriptor)
        }
      }
      var barrierInfo = stat()
      guard Darwin.fstat(currentBarrierDescriptor, &barrierInfo) == 0,
        Self.isRegularFileMode(barrierInfo.st_mode),
        barrierInfo.st_dev == rootInfo.st_dev
      else {
        throw DurablePreferencesError.fileUnsafe
      }

      // 即使目录已存在也重放完整屏障；上一次可能完成了目录项变更，却在屏障返回前中断。
      try Self.syncDirectory(
        directoryDescriptor,
        barrierDescriptor: currentBarrierDescriptor,
        durability: durability
      )
      try Self.syncDirectory(
        parentDescriptor,
        barrierDescriptor: currentBarrierDescriptor,
        durability: durability
      )

      if index == relativeDirectoryComponents.index(before: relativeDirectoryComponents.endIndex) {
        barrierDescriptor = currentBarrierDescriptor
        barrierTransferred = true
      }
    }

    self.directoryDescriptors = directoryDescriptors
    self.barrierDescriptor = barrierDescriptor
    self.directoryNames = relativeDirectoryComponents
    self.durability = durability
    self.legacyPreferences = legacyPreferences
    descriptorsTransferred = true
  }

  deinit {
    Darwin.close(barrierDescriptor)
    for descriptor in directoryDescriptors.reversed() {
      Darwin.close(descriptor)
    }
  }

  static let snapshotFileName = "preferences-v1.json"
  static let temporaryFileName = ".preferences-v1.tmp"

  private static let barrierFileName = ".kelivo-durable-preferences.barrier"
  private static let lockFileName = ".preferences-v1.lock"
  private static let formatVersion = 2
  // 偏好不是大对象存储；限制损坏文件的内存放大，同时覆盖正常配置规模。
  private static let maximumSnapshotBytes = 16 * 1024 * 1024

  private let directoryDescriptors: [Int32]
  private let barrierDescriptor: Int32
  private let directoryNames: [String]
  private let durability: PreferencesDurability
  private let legacyPreferences: LegacyPreferencesAccess

  private var directoryDescriptor: Int32 {
    directoryDescriptors[directoryDescriptors.index(before: directoryDescriptors.endIndex)]
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
      if try entityInfo(named: Self.snapshotFileName) == nil {
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
        values[key] = value.platformValue
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
    try requireAnchoredDirectoryIdentity()
    let descriptor = try openRelativeFile(
      named: Self.lockFileName,
      flags: O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW,
      mode: mode_t(S_IRUSR | S_IWUSR),
      operation: "lock"
    )
    defer { Darwin.close(descriptor) }
    var lockInfo = stat()
    guard Darwin.fstat(descriptor, &lockInfo) == 0,
      Self.isRegularFileMode(lockInfo.st_mode)
    else {
      throw DurablePreferencesError.fileUnsafe
    }
    // 上一次可能已完成目录变更但在 barrier 返回前失败；每次重试都先确认目录，
    // 不能依据当前目录项是否存在来推断之前已经耐久。
    try syncDirectory()
    guard Darwin.flock(descriptor, LOCK_EX) == 0 else {
      throw DurablePreferencesError.lockFailed(errno: errno)
    }
    defer { Darwin.flock(descriptor, LOCK_UN) }

    try requireLockIdentity(descriptor)
    try requireAnchoredDirectoryIdentity()
    try removeStaleTemporaryFile()
    let result = try operation()
    try requireLockIdentity(descriptor)
    try requireAnchoredDirectoryIdentity()
    return result
  }

  private func removeStaleTemporaryFile() throws {
    if let info = try entityInfo(named: Self.temporaryFileName) {
      guard Self.isRegularFileMode(info.st_mode) else {
        throw DurablePreferencesError.fileUnsafe
      }
      let result = Self.temporaryFileName.withCString { name in
        Darwin.unlinkat(directoryDescriptor, name, 0)
      }
      guard result == 0 else {
        throw DurablePreferencesError.writeFailed(errno: errno)
      }
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
    guard let info = try entityInfo(named: Self.snapshotFileName) else {
      return nil
    }
    guard Self.isRegularFileMode(info.st_mode) else {
      throw DurablePreferencesError.fileUnsafe
    }
    return try decodeSnapshot(readFile(named: Self.snapshotFileName))
  }

  private func persist(_ snapshot: Snapshot) throws {
    let encoded = try encodeSnapshot(snapshot)
    guard encoded.count <= Self.maximumSnapshotBytes else {
      throw DurablePreferencesError.snapshotTooLarge
    }
    let descriptor = try openRelativeFile(
      named: Self.temporaryFileName,
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
        Self.temporaryFileName.withCString { name in
          _ = Darwin.unlinkat(directoryDescriptor, name, 0)
        }
      }
    }

    do {
      try writeAll(encoded, to: descriptor)
      try durability.syncFileDescriptor(descriptor)
      guard Darwin.close(descriptor) == 0 else {
        descriptorOpen = false
        throw DurablePreferencesError.writeFailed(errno: errno)
      }
      descriptorOpen = false

      if let destinationInfo = try entityInfo(named: Self.snapshotFileName),
        !Self.isRegularFileMode(destinationInfo.st_mode)
      {
        throw DurablePreferencesError.fileUnsafe
      }
      let renameResult = Self.temporaryFileName.withCString { source in
        Self.snapshotFileName.withCString { destination in
          Darwin.renameat(
            directoryDescriptor,
            source,
            directoryDescriptor,
            destination
          )
        }
      }
      guard renameResult == 0 else {
        throw DurablePreferencesError.renameFailed(errno: errno)
      }
      temporaryExists = false
      try syncDirectory()

      let reopened = try readFile(named: Self.snapshotFileName)
      guard reopened == encoded else {
        throw DurablePreferencesError.verificationFailed
      }
      _ = try decodeSnapshot(reopened)
    } catch {
      let primaryError = error
      if descriptorOpen {
        _ = Darwin.close(descriptor)
        descriptorOpen = false
      }
      if temporaryExists {
        try removeStaleTemporaryFile()
        temporaryExists = false
      }
      throw primaryError
    }
  }

  private func encodeSnapshot(_ snapshot: Snapshot) throws -> Data {
    let encodedValues = snapshot.values.mapValues(\.encodedObject)
    let object: [String: Any] = [
      "formatVersion": Self.formatVersion,
      "legacyContaminated": snapshot.legacyContaminated,
      "values": encodedValues,
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
    var typedValues: [String: StoredPreference] = [:]
    typedValues.reserveCapacity(values.count)
    for (key, value) in values {
      typedValues[key] = try StoredPreference.decode(value)
    }
    return Snapshot(
      legacyContaminated: contaminatedNumber.boolValue,
      values: typedValues
    )
  }

  private func normalized(value: Any, valueType: String) throws -> StoredPreference {
    switch valueType {
    case "Bool":
      guard let number = value as? NSNumber,
        CFGetTypeID(number) == CFBooleanGetTypeID()
      else {
        throw DurablePreferencesError.unsupportedValue
      }
      return .boolean(number.boolValue)
    case "Double":
      guard let number = value as? NSNumber,
        CFGetTypeID(number) != CFBooleanGetTypeID(),
        isFloatingPointNumber(number)
      else {
        throw DurablePreferencesError.unsupportedValue
      }
      return .double(number.doubleValue)
    case "Int":
      guard let number = value as? NSNumber,
        CFGetTypeID(number) != CFBooleanGetTypeID(),
        !isFloatingPointNumber(number)
      else {
        throw DurablePreferencesError.unsupportedValue
      }
      return .integer(number.int64Value)
    case "String":
      guard let string = value as? String else {
        throw DurablePreferencesError.unsupportedValue
      }
      return .string(string)
    case "StringList":
      guard let list = value as? [Any], list.allSatisfy({ $0 is String }) else {
        throw DurablePreferencesError.unsupportedValue
      }
      return .stringList(list.compactMap { $0 as? String })
    default:
      throw DurablePreferencesError.unsupportedValue
    }
  }

  private func isFloatingPointNumber(_ value: NSNumber) -> Bool {
    let encoding = String(cString: value.objCType)
    return encoding == "f" || encoding == "d"
  }

  private func readFile(named name: String) throws -> Data {
    guard let expectedInfo = try entityInfo(named: name) else {
      throw DurablePreferencesError.snapshotInvalid
    }
    let descriptor = try openRelativeFile(
      named: name,
      flags: O_RDONLY | O_CLOEXEC | O_NOFOLLOW,
      mode: 0,
      operation: "snapshot"
    )
    defer { Darwin.close(descriptor) }
    var info = stat()
    guard Darwin.fstat(descriptor, &info) == 0,
      Self.isRegularFileMode(info.st_mode),
      Self.isSameEntity(expectedInfo, info)
    else {
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
    try Self.syncDirectory(
      directoryDescriptor,
      barrierDescriptor: barrierDescriptor,
      durability: durability
    )
  }

  private static func syncDirectory(
    _ directoryDescriptor: Int32,
    barrierDescriptor: Int32,
    durability: PreferencesDurability
  ) throws {
    // Apple 仅公开承诺普通文件的 F_FULLFSYNC 屏障语义；目录元数据先通过
    // fsync 提交，再由同卷稳定文件发出设备屏障。
    try durability.syncDirectoryDescriptor(directoryDescriptor)
    try durability.syncBarrierFileDescriptor(barrierDescriptor)
  }

  private func requireAnchoredDirectoryIdentity() throws {
    for index in directoryNames.indices {
      try Self.requireSameDirectory(
        parentDescriptor: directoryDescriptors[index],
        directoryName: directoryNames[index],
        directoryDescriptor: directoryDescriptors[index + 1]
      )
    }
  }

  private func requireLockIdentity(_ descriptor: Int32) throws {
    var descriptorInfo = stat()
    guard Darwin.fstat(descriptor, &descriptorInfo) == 0,
      Self.isRegularFileMode(descriptorInfo.st_mode),
      let pathInfo = try entityInfo(named: Self.lockFileName),
      Self.isSameEntity(descriptorInfo, pathInfo)
    else {
      throw DurablePreferencesError.fileUnsafe
    }
  }

  private func openRelativeFile(
    named name: String,
    flags: Int32,
    mode: mode_t,
    operation: String
  ) throws -> Int32 {
    try Self.openRelativeFile(
      directoryDescriptor: directoryDescriptor,
      named: name,
      flags: flags,
      mode: mode,
      operation: operation
    )
  }

  private static func openRelativeFile(
    directoryDescriptor: Int32,
    named name: String,
    flags: Int32,
    mode: mode_t,
    operation: String
  ) throws -> Int32 {
    guard Self.isSafeEntryName(name) else {
      throw DurablePreferencesError.fileUnsafe
    }
    let descriptor = name.withCString { path in
      Darwin.openat(directoryDescriptor, path, flags, mode)
    }
    guard descriptor >= 0 else {
      throw DurablePreferencesError.openFailed(operation: operation, errno: errno)
    }
    return descriptor
  }

  private func entityInfo(named name: String) throws -> stat? {
    guard Self.isSafeEntryName(name) else {
      throw DurablePreferencesError.fileUnsafe
    }
    var info = stat()
    let result = name.withCString { path in
      Darwin.fstatat(directoryDescriptor, path, &info, AT_SYMLINK_NOFOLLOW)
    }
    if result == 0 {
      return info
    }
    let code = errno
    if code == ENOENT {
      return nil
    }
    throw DurablePreferencesError.openFailed(operation: "metadata", errno: code)
  }

  private static func openAbsoluteDirectory(at url: URL) throws -> Int32 {
    let descriptor = url.path.withCString { path in
      Darwin.open(path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW, 0)
    }
    guard descriptor >= 0 else {
      throw DurablePreferencesError.openFailed(operation: "parent-directory", errno: errno)
    }
    return descriptor
  }

  private static func openRelativeDirectory(
    parentDescriptor: Int32,
    name: String
  ) throws -> Int32 {
    let descriptor = name.withCString { path in
      Darwin.openat(
        parentDescriptor,
        path,
        O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW,
        0
      )
    }
    guard descriptor >= 0 else {
      throw DurablePreferencesError.openFailed(operation: "directory", errno: errno)
    }
    return descriptor
  }

  private static func requireSameDirectory(
    parentDescriptor: Int32,
    directoryName: String,
    directoryDescriptor: Int32
  ) throws {
    var descriptorInfo = stat()
    var pathInfo = stat()
    let pathResult = directoryName.withCString { name in
      Darwin.fstatat(
        parentDescriptor,
        name,
        &pathInfo,
        AT_SYMLINK_NOFOLLOW
      )
    }
    guard pathResult == 0,
      Darwin.fstat(directoryDescriptor, &descriptorInfo) == 0,
      isDirectoryMode(pathInfo.st_mode),
      isDirectoryMode(descriptorInfo.st_mode),
      isSameEntity(pathInfo, descriptorInfo)
    else {
      throw DurablePreferencesError.directoryUnsafe
    }
  }

  private static func isSafeEntryName(_ name: String) -> Bool {
    !name.isEmpty && name != "." && name != ".." && !name.contains("/")
  }

  private static func isSameEntity(_ first: stat, _ second: stat) -> Bool {
    first.st_dev == second.st_dev && first.st_ino == second.st_ino
  }

  private static func isDirectoryMode(_ mode: mode_t) -> Bool {
    (mode & mode_t(S_IFMT)) == mode_t(S_IFDIR)
  }

  private static func isRegularFileMode(_ mode: mode_t) -> Bool {
    (mode & mode_t(S_IFMT)) == mode_t(S_IFREG)
  }
}

private struct Snapshot {
  static let empty = Snapshot(legacyContaminated: false, values: [:])

  var legacyContaminated: Bool
  var values: [String: StoredPreference]
}

private enum StoredPreference {
  case boolean(Bool)
  case double(Double)
  case integer(Int64)
  case string(String)
  case stringList([String])

  var platformValue: Any {
    switch self {
    case .boolean(let value):
      return value
    case .double(let value):
      return value
    case .integer(let value):
      return value
    case .string(let value):
      return value
    case .stringList(let value):
      return value
    }
  }

  var encodedObject: [String: Any] {
    switch self {
    case .boolean(let value):
      return ["type": "Bool", "value": value]
    case .double(let value):
      // JSON 数字不能可靠区分 1 与 1.0；保存 IEEE-754 位模式同时覆盖
      // 积分 double、负零与非有限值。
      return ["type": "Double", "value": String(value.bitPattern)]
    case .integer(let value):
      return ["type": "Int", "value": String(value)]
    case .string(let value):
      return ["type": "String", "value": value]
    case .stringList(let value):
      return ["type": "StringList", "value": value]
    }
  }

  static func decode(_ raw: Any) throws -> StoredPreference {
    guard let object = raw as? [String: Any],
      Set(object.keys) == Set(["type", "value"]),
      let type = object["type"] as? String,
      let value = object["value"]
    else {
      throw DurablePreferencesError.snapshotInvalid
    }

    switch type {
    case "Bool":
      guard let number = value as? NSNumber,
        CFGetTypeID(number) == CFBooleanGetTypeID()
      else {
        throw DurablePreferencesError.snapshotInvalid
      }
      return .boolean(number.boolValue)
    case "Double":
      guard let encoded = value as? String,
        let bitPattern = UInt64(encoded),
        String(bitPattern) == encoded
      else {
        throw DurablePreferencesError.snapshotInvalid
      }
      return .double(Double(bitPattern: bitPattern))
    case "Int":
      guard let encoded = value as? String,
        let integer = Int64(encoded),
        String(integer) == encoded
      else {
        throw DurablePreferencesError.snapshotInvalid
      }
      return .integer(integer)
    case "String":
      guard let string = value as? String else {
        throw DurablePreferencesError.snapshotInvalid
      }
      return .string(string)
    case "StringList":
      guard let list = value as? [Any], list.allSatisfy({ $0 is String }) else {
        throw DurablePreferencesError.snapshotInvalid
      }
      return .stringList(list.compactMap { $0 as? String })
    default:
      throw DurablePreferencesError.snapshotInvalid
    }
  }
}
