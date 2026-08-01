import Foundation
import Darwin
import XCTest

@testable import kelivo_durable_preferences

final class KelivoDurablePreferencesTests: XCTestCase {
  private var root: URL!

  override func setUpWithError() throws {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: root,
      withIntermediateDirectories: false
    )
  }

  override func tearDownWithError() throws {
    try FileManager.default.removeItem(at: root)
  }

  func testWriteAndDeleteSurviveIndependentReopen() throws {
    let directory = root.appendingPathComponent("preferences", isDirectory: true)
    let legacy = StubLegacyPreferences()
    let first = try DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )

    try first.initialize()
    try first.set(valueType: "String", key: "flutter.secret", value: "value")

    let reopened = try DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )
    try reopened.initialize()
    XCTAssertEqual(
      reopened.getAll(prefix: "flutter.", allowList: nil)["flutter.secret"] as? String,
      "value"
    )

    try reopened.remove(key: "flutter.secret")
    let verified = try DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )
    try verified.initialize()
    XCTAssertNil(verified.getAll(prefix: "", allowList: nil)["flutter.secret"])
    XCTAssertNoThrow(try verified.remove(key: "flutter.secret"))
  }

  func testTypedValuesSurviveIndependentReopenWithoutNumericCoercion() throws {
    let directory = root.appendingPathComponent("preferences", isDirectory: true)
    let legacy = StubLegacyPreferences()
    let first = try DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )

    try first.initialize()
    try first.set(valueType: "Bool", key: "flutter.bool", value: NSNumber(value: true))
    try first.set(valueType: "Double", key: "flutter.double", value: NSNumber(value: 1.0))
    try first.set(valueType: "Int", key: "flutter.int-min", value: NSNumber(value: Int64.min))
    try first.set(valueType: "Int", key: "flutter.int-max", value: NSNumber(value: Int64.max))
    try first.set(valueType: "String", key: "flutter.string", value: "value")
    try first.set(
      valueType: "StringList",
      key: "flutter.list",
      value: ["first", "second"]
    )

    let reopened = try DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )
    try reopened.initialize()
    let values = try reopened.getAll(prefix: "flutter.", allowList: nil)

    XCTAssertTrue(values["flutter.bool"] is Bool)
    XCTAssertTrue(values["flutter.double"] is Double)
    XCTAssertEqual(values["flutter.double"] as? Double, 1.0)
    XCTAssertTrue(values["flutter.int-min"] is Int64)
    XCTAssertEqual(values["flutter.int-min"] as? Int64, Int64.min)
    XCTAssertTrue(values["flutter.int-max"] is Int64)
    XCTAssertEqual(values["flutter.int-max"] as? Int64, Int64.max)
    XCTAssertEqual(values["flutter.string"] as? String, "value")
    XCTAssertEqual(values["flutter.list"] as? [String], ["first", "second"])
  }

  func testLegacyUntypedSnapshotIsRejectedWithoutMigration() throws {
    let directory = root.appendingPathComponent("preferences", isDirectory: true)
    let legacy = StubLegacyPreferences()
    let first = try DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )
    try first.initialize()
    let legacySnapshot = """
    {"formatVersion":1,"legacyContaminated":false,"values":{"flutter.value":1}}
    """
    try Data(legacySnapshot.utf8).write(
      to: directory.appendingPathComponent(DurablePreferencesFileStore.snapshotFileName)
    )

    let reopened = try DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )
    XCTAssertThrowsError(try reopened.initialize())
  }

  func testMalformedTypedSnapshotsAreRejected() throws {
    let malformedValues = [
      #"{"type":"Double","value":1}"#,
      #"{"type":"Int","value":"9223372036854775808"}"#,
      #"{"type":"Bool","value":"true"}"#,
      #"{"type":"String","value":1}"#,
      #"{"type":"StringList","value":["valid",1]}"#,
      #"{"type":"Unknown","value":"value"}"#,
    ]

    for (index, malformedValue) in malformedValues.enumerated() {
      let directory = root.appendingPathComponent("preferences-\(index)", isDirectory: true)
      let legacy = StubLegacyPreferences()
      let first = try DurablePreferencesFileStore(
        directory: directory,
        durability: DarwinPreferencesDurability(),
        legacyPreferences: legacy
      )
      try first.initialize()
      let malformedSnapshot = """
      {"formatVersion":2,"legacyContaminated":false,"values":{"flutter.value":\(malformedValue)}}
      """
      try Data(malformedSnapshot.utf8).write(
        to: directory.appendingPathComponent(DurablePreferencesFileStore.snapshotFileName)
      )

      let reopened = try DurablePreferencesFileStore(
        directory: directory,
        durability: DarwinPreferencesDurability(),
        legacyPreferences: legacy
      )
      XCTAssertThrowsError(try reopened.initialize())
    }
  }

  func testOversizedMutationLeavesPreviousSnapshotUsable() throws {
    let directory = root.appendingPathComponent("preferences", isDirectory: true)
    let legacy = StubLegacyPreferences()
    let first = try DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )
    try first.initialize()
    try first.set(valueType: "String", key: "flutter.value", value: "before")

    XCTAssertThrowsError(
      try first.set(
        valueType: "String",
        key: "flutter.oversized",
        value: String(repeating: "x", count: 16 * 1024 * 1024)
      )
    )

    let reopened = try DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )
    try reopened.initialize()
    XCTAssertEqual(
      try reopened.getAll(prefix: "flutter.", allowList: nil)["flutter.value"] as? String,
      "before"
    )
  }

  func testReplacedDirectoryIdentityCannotSplitTheCrossProcessLock() throws {
    let directory = root.appendingPathComponent("preferences", isDirectory: true)
    let detached = root.appendingPathComponent("detached", isDirectory: true)
    let legacy = StubLegacyPreferences()
    let first = try DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )
    try first.initialize()
    try first.set(valueType: "String", key: "flutter.owner", value: "first")
    try FileManager.default.moveItem(at: directory, to: detached)

    let replacement = try DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )
    try replacement.initialize()
    try replacement.set(valueType: "String", key: "flutter.owner", value: "replacement")

    XCTAssertThrowsError(
      try first.set(valueType: "String", key: "flutter.owner", value: "escaped")
    )
    XCTAssertEqual(
      try replacement.getAll(prefix: "flutter.", allowList: nil)["flutter.owner"] as? String,
      "replacement"
    )
  }

  func testReplacedIntermediateDirectoryInvalidatesTheAnchoredChain() throws {
    let detached = root.appendingPathComponent("detached", isDirectory: true)
    let legacy = StubLegacyPreferences()
    let first = try DurablePreferencesFileStore(
      rootDirectory: root,
      relativeDirectoryComponents: ["application-support", "preferences"],
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )
    try first.initialize()
    try first.set(valueType: "String", key: "flutter.owner", value: "first")
    try FileManager.default.moveItem(
      at: root.appendingPathComponent("application-support", isDirectory: true),
      to: detached
    )

    let replacement = try DurablePreferencesFileStore(
      rootDirectory: root,
      relativeDirectoryComponents: ["application-support", "preferences"],
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )
    try replacement.initialize()

    XCTAssertThrowsError(
      try first.set(valueType: "String", key: "flutter.owner", value: "escaped")
    )
  }

  func testReplacingLibraryRootRejectsEveryOperationAndPreservesCanonicalSnapshot() throws {
    let container = root.appendingPathComponent("container", isDirectory: true)
    let library = container.appendingPathComponent("Library", isDirectory: true)
    let detachedLibrary = container.appendingPathComponent(
      "DetachedLibrary",
      isDirectory: true
    )
    try FileManager.default.createDirectory(at: container, withIntermediateDirectories: false)
    try FileManager.default.createDirectory(at: library, withIntermediateDirectories: false)
    let legacy = StubLegacyPreferences()
    let primary = try makeNestedStore(rootDirectory: library, legacy: legacy)
    try primary.initialize()
    try primary.set(valueType: "String", key: "flutter.secret", value: "original")
    let operationStores = try (0..<5).map { _ in
      try makeNestedStore(rootDirectory: library, legacy: legacy)
    }

    try FileManager.default.moveItem(at: library, to: detachedLibrary)
    try FileManager.default.createDirectory(at: library, withIntermediateDirectories: false)
    let replacement = try makeNestedStore(rootDirectory: library, legacy: legacy)
    try replacement.initialize()
    try replacement.set(valueType: "String", key: "flutter.owner", value: "replacement")
    try replacement.set(
      valueType: "String",
      key: "flutter.secret",
      value: "replacement-secret"
    )

    assertDirectoryUnsafe { try operationStores[0].initialize() }
    assertDirectoryUnsafe {
      _ = try operationStores[1].getAll(prefix: "flutter.", allowList: nil)
    }
    assertDirectoryUnsafe {
      try operationStores[2].set(
        valueType: "String",
        key: "flutter.secret",
        value: "escaped"
      )
    }
    assertDirectoryUnsafe { try operationStores[3].remove(key: "flutter.secret") }
    assertDirectoryUnsafe {
      try operationStores[4].clear(prefix: "flutter.", allowList: nil)
    }

    let replacementValues = try replacement.getAll(prefix: "flutter.", allowList: nil)
    XCTAssertEqual(replacementValues["flutter.owner"] as? String, "replacement")
    XCTAssertEqual(
      replacementValues["flutter.secret"] as? String,
      "replacement-secret"
    )
  }

  func testReplacementDuringMutationPoisonsStoreAfterOriginalRootReturns() throws {
    let container = root.appendingPathComponent("container", isDirectory: true)
    let library = container.appendingPathComponent("Library", isDirectory: true)
    let detachedLibrary = container.appendingPathComponent(
      "DetachedLibrary",
      isDirectory: true
    )
    let replacementLibrary = container.appendingPathComponent(
      "ReplacementLibrary",
      isDirectory: true
    )
    try FileManager.default.createDirectory(at: container, withIntermediateDirectories: false)
    try FileManager.default.createDirectory(at: library, withIntermediateDirectories: false)
    try FileManager.default.createDirectory(
      at: replacementLibrary,
      withIntermediateDirectories: false
    )
    let legacy = StubLegacyPreferences()
    let initial = try makeNestedStore(rootDirectory: library, legacy: legacy)
    try initial.initialize()
    try initial.set(valueType: "String", key: "flutter.secret", value: "original")
    let preparedReplacement = try makeNestedStore(
      rootDirectory: replacementLibrary,
      legacy: legacy
    )
    try preparedReplacement.initialize()
    try preparedReplacement.set(
      valueType: "String",
      key: "flutter.secret",
      value: "replacement-secret"
    )

    let durability = FileSyncHookDurability {
      try FileManager.default.moveItem(at: library, to: detachedLibrary)
      try FileManager.default.moveItem(at: replacementLibrary, to: library)
    }
    let oldStore = try makeNestedStore(
      rootDirectory: library,
      durability: durability,
      legacy: legacy
    )

    assertDirectoryUnsafe { try oldStore.remove(key: "flutter.secret") }
    XCTAssertTrue(durability.didRun)
    let canonical = try makeNestedStore(rootDirectory: library, legacy: legacy)
    try canonical.initialize()
    XCTAssertEqual(
      try canonical.getAll(prefix: "flutter.", allowList: nil)["flutter.secret"] as? String,
      "replacement-secret"
    )

    try FileManager.default.moveItem(at: library, to: replacementLibrary)
    try FileManager.default.moveItem(at: detachedLibrary, to: library)
    assertDirectoryUnsafe {
      _ = try oldStore.getAll(prefix: "flutter.", allowList: nil)
    }
  }

  func testReplacementFollowedByDurabilityFailureStillPoisonsStore() throws {
    let container = root.appendingPathComponent("container", isDirectory: true)
    let library = container.appendingPathComponent("Library", isDirectory: true)
    let detachedLibrary = container.appendingPathComponent(
      "DetachedLibrary",
      isDirectory: true
    )
    let replacementLibrary = container.appendingPathComponent(
      "ReplacementLibrary",
      isDirectory: true
    )
    try FileManager.default.createDirectory(at: container, withIntermediateDirectories: false)
    try FileManager.default.createDirectory(at: library, withIntermediateDirectories: false)
    try FileManager.default.createDirectory(
      at: replacementLibrary,
      withIntermediateDirectories: false
    )
    let legacy = StubLegacyPreferences()
    let initial = try makeNestedStore(rootDirectory: library, legacy: legacy)
    try initial.initialize()
    try initial.set(valueType: "String", key: "flutter.secret", value: "original")
    let preparedReplacement = try makeNestedStore(
      rootDirectory: replacementLibrary,
      legacy: legacy
    )
    try preparedReplacement.initialize()
    try preparedReplacement.set(
      valueType: "String",
      key: "flutter.secret",
      value: "replacement-secret"
    )

    let durability = FileSyncHookDurability(failAfterHook: true) {
      try FileManager.default.moveItem(at: library, to: detachedLibrary)
      try FileManager.default.moveItem(at: replacementLibrary, to: library)
    }
    let oldStore = try makeNestedStore(
      rootDirectory: library,
      durability: durability,
      legacy: legacy
    )

    assertDirectoryUnsafe { try oldStore.remove(key: "flutter.secret") }
    XCTAssertTrue(durability.didRun)
    let canonical = try makeNestedStore(rootDirectory: library, legacy: legacy)
    try canonical.initialize()
    XCTAssertEqual(
      try canonical.getAll(prefix: "flutter.", allowList: nil)["flutter.secret"] as? String,
      "replacement-secret"
    )

    try FileManager.default.moveItem(at: library, to: replacementLibrary)
    try FileManager.default.moveItem(at: detachedLibrary, to: library)
    assertDirectoryUnsafe {
      _ = try oldStore.getAll(prefix: "flutter.", allowList: nil)
    }
  }

  func testSymbolicLinkDirectoryIsRejectedBeforeCreatingLockState() throws {
    let directory = root.appendingPathComponent("preferences", isDirectory: true)
    let target = root.appendingPathComponent("target", isDirectory: true)
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
    try FileManager.default.createSymbolicLink(
      atPath: directory.path,
      withDestinationPath: target.path
    )

    XCTAssertThrowsError(
      try DurablePreferencesFileStore(
        directory: directory,
        durability: DarwinPreferencesDurability(),
        legacyPreferences: StubLegacyPreferences()
      )
    )
    XCTAssertFalse(
      FileManager.default.fileExists(
        atPath: target.appendingPathComponent(".preferences-v1.lock").path
      )
    )
  }

  func testNestedDirectoryCreationOrdersDirectorySyncBeforeBarrier() throws {
    let durability = RecordingDurability()

    _ = try DurablePreferencesFileStore(
      rootDirectory: root,
      relativeDirectoryComponents: ["application-support", "preferences"],
      durability: durability,
      legacyPreferences: StubLegacyPreferences()
    )

    XCTAssertEqual(
      durability.events,
      [
        .directory, .barrier,
        .directory, .barrier,
        .directory, .barrier,
        .directory, .barrier,
      ]
    )
  }

  func testDirectorySyncFailureStopsBeforeBarrier() throws {
    let durability = RecordingDurability(failDirectoryAtCall: 1)

    XCTAssertThrowsError(
      try DurablePreferencesFileStore(
        rootDirectory: root,
        relativeDirectoryComponents: ["preferences"],
        durability: durability,
        legacyPreferences: StubLegacyPreferences()
      )
    )
    XCTAssertEqual(durability.events, [.directory])
  }

  func testBarrierSyncFailureFailsInitialization() throws {
    let durability = RecordingDurability(failBarrierAtCall: 1)

    XCTAssertThrowsError(
      try DurablePreferencesFileStore(
        rootDirectory: root,
        relativeDirectoryComponents: ["preferences"],
        durability: durability,
        legacyPreferences: StubLegacyPreferences()
      )
    )
    XCTAssertEqual(durability.events, [.directory, .barrier])
  }

  func testDirectorySyncFailureRequiresIdempotentRetry() throws {
    let directory = root.appendingPathComponent("preferences", isDirectory: true)
    let legacy = StubLegacyPreferences()
    let initial = try DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )
    try initial.initialize()
    try initial.set(valueType: "String", key: "flutter.secret", value: "value")
    let failing = try DurablePreferencesFileStore(
      directory: directory,
      durability: FailingDirectoryDurability(failAtCall: 4),
      legacyPreferences: legacy
    )

    XCTAssertThrowsError(try failing.remove(key: "flutter.secret"))

    let retry = try DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )
    XCTAssertNoThrow(try retry.initialize())
    XCTAssertNoThrow(try retry.remove(key: "flutter.secret"))
    XCTAssertNil(retry.getAll(prefix: "", allowList: nil)["flutter.secret"])
  }

  func testBarrierSyncFailureRequiresIdempotentRetry() throws {
    let directory = root.appendingPathComponent("preferences", isDirectory: true)
    let legacy = StubLegacyPreferences()
    let initial = try DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )
    try initial.initialize()
    try initial.set(valueType: "String", key: "flutter.secret", value: "value")
    let durability = RecordingDurability(failBarrierAtCall: 4)
    let failing = try DurablePreferencesFileStore(
      directory: directory,
      durability: durability,
      legacyPreferences: legacy
    )

    XCTAssertThrowsError(try failing.remove(key: "flutter.secret"))

    let retry = try DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )
    XCTAssertNoThrow(try retry.initialize())
    XCTAssertNoThrow(try retry.remove(key: "flutter.secret"))
    XCTAssertNil(retry.getAll(prefix: "", allowList: nil)["flutter.secret"])
  }

  func testLegacyContaminationRemainsBlockedAfterBestEffortCleanup() throws {
    let directory = root.appendingPathComponent("preferences", isDirectory: true)
    let contaminated = StubLegacyPreferences(keys: ["flutter.secret"])
    let first = try DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: contaminated
    )

    XCTAssertThrowsError(try first.initialize())
    XCTAssertEqual(contaminated.removedKeys, Set(["flutter.secret"]))

    let cleanLegacy = StubLegacyPreferences()
    let reopened = try DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: cleanLegacy
    )
    XCTAssertThrowsError(try reopened.initialize())
  }

  func testCrashTemporaryFileIsRemovedBeforeOpeningSnapshot() throws {
    let directory = root.appendingPathComponent("preferences", isDirectory: true)
    let legacy = StubLegacyPreferences()
    let first = try DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )
    try first.initialize()
    let stale = directory.appendingPathComponent(
      DurablePreferencesFileStore.temporaryFileName,
      isDirectory: false
    )
    try Data("secret".utf8).write(to: stale)

    let reopened = try DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )
    try reopened.initialize()

    XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
  }

  func testFailedTemporaryWriteDurablyRemovesTemporaryFile() throws {
    let directory = root.appendingPathComponent("preferences", isDirectory: true)
    let legacy = StubLegacyPreferences()
    let initial = try DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )
    try initial.initialize()
    try initial.set(valueType: "String", key: "flutter.value", value: "before")

    let durability = RecordingDurability(failFileAtCall: 1)
    let failing = try DurablePreferencesFileStore(
      directory: directory,
      durability: durability,
      legacyPreferences: legacy
    )
    XCTAssertThrowsError(
      try failing.set(valueType: "String", key: "flutter.value", value: "after")
    ) { error in
      guard let durableError = error as? DurablePreferencesError,
        case .fileSyncFailed = durableError
      else {
        XCTFail("锚点一致时未保留原始文件同步错误：\(error)")
        return
      }
    }

    XCTAssertFalse(
      FileManager.default.fileExists(
        atPath: directory.appendingPathComponent(
          DurablePreferencesFileStore.temporaryFileName
        ).path
      )
    )
    XCTAssertEqual(
      Array(durability.events.suffix(3)),
      [.file, .directory, .barrier]
    )
    let reopened = try DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )
    try reopened.initialize()
    XCTAssertEqual(
      try reopened.getAll(prefix: "flutter.", allowList: nil)["flutter.value"] as? String,
      "before"
    )
  }

  private func makeNestedStore(
    rootDirectory: URL,
    durability: PreferencesDurability = DarwinPreferencesDurability(),
    legacy: LegacyPreferencesAccess
  ) throws -> DurablePreferencesFileStore {
    try DurablePreferencesFileStore(
      rootDirectory: rootDirectory,
      relativeDirectoryComponents: ["Application Support", "preferences"],
      durability: durability,
      legacyPreferences: legacy
    )
  }

  private func assertDirectoryUnsafe(
    _ operation: () throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    do {
      try operation()
      XCTFail("操作未在目录身份失配时失败关闭", file: file, line: line)
    } catch let error as DurablePreferencesError {
      guard case .directoryUnsafe = error else {
        XCTFail("收到非目录身份错误：\(error)", file: file, line: line)
        return
      }
    } catch {
      XCTFail("收到非耐久偏好错误：\(error)", file: file, line: line)
    }
  }
}

private final class StubLegacyPreferences: LegacyPreferencesAccess {
  init(keys: Set<String> = []) {
    self.keys = keys
  }

  private(set) var keys: Set<String>
  private(set) var removedKeys: Set<String> = []

  func contaminatedKeys() -> Set<String> {
    keys
  }

  func bestEffortRemove(keys: Set<String>) {
    removedKeys.formUnion(keys)
    self.keys.subtract(keys)
  }
}

private final class FailingDirectoryDurability: PreferencesDurability {
  init(failAtCall: Int) {
    self.failAtCall = failAtCall
  }

  private let failAtCall: Int
  private var directoryCalls = 0

  func syncFileDescriptor(_ descriptor: Int32) throws {}

  func syncDirectoryDescriptor(_ descriptor: Int32) throws {
    directoryCalls += 1
    if directoryCalls == failAtCall {
      throw DurablePreferencesError.directorySyncFailed(errno: EIO)
    }
  }

  func syncBarrierFileDescriptor(_ descriptor: Int32) throws {}
}

private enum DurabilityEvent: Equatable {
  case file
  case directory
  case barrier
}

private final class RecordingDurability: PreferencesDurability {
  init(
    failFileAtCall: Int? = nil,
    failDirectoryAtCall: Int? = nil,
    failBarrierAtCall: Int? = nil
  ) {
    self.failFileAtCall = failFileAtCall
    self.failDirectoryAtCall = failDirectoryAtCall
    self.failBarrierAtCall = failBarrierAtCall
  }

  private let failFileAtCall: Int?
  private let failDirectoryAtCall: Int?
  private let failBarrierAtCall: Int?
  private var fileCalls = 0
  private var directoryCalls = 0
  private var barrierCalls = 0
  private(set) var events: [DurabilityEvent] = []

  func syncFileDescriptor(_ descriptor: Int32) throws {
    fileCalls += 1
    events.append(.file)
    if let failFileAtCall, fileCalls == failFileAtCall {
      throw DurablePreferencesError.fileSyncFailed(errno: EIO)
    }
  }

  func syncDirectoryDescriptor(_ descriptor: Int32) throws {
    directoryCalls += 1
    events.append(.directory)
    if let failDirectoryAtCall, directoryCalls == failDirectoryAtCall {
      throw DurablePreferencesError.directorySyncFailed(errno: EIO)
    }
  }

  func syncBarrierFileDescriptor(_ descriptor: Int32) throws {
    barrierCalls += 1
    events.append(.barrier)
    if let failBarrierAtCall, barrierCalls == failBarrierAtCall {
      throw DurablePreferencesError.barrierSyncFailed(errno: EIO)
    }
  }
}

private final class FileSyncHookDurability: PreferencesDurability {
  init(
    failAfterHook: Bool = false,
    onFirstFileSync: @escaping () throws -> Void
  ) {
    self.failAfterHook = failAfterHook
    self.onFirstFileSync = onFirstFileSync
  }

  private let base = DarwinPreferencesDurability()
  private let failAfterHook: Bool
  private let onFirstFileSync: () throws -> Void
  private(set) var didRun = false

  func syncFileDescriptor(_ descriptor: Int32) throws {
    try base.syncFileDescriptor(descriptor)
    if !didRun {
      didRun = true
      try onFirstFileSync()
      if failAfterHook {
        throw DurablePreferencesError.fileSyncFailed(errno: EIO)
      }
    }
  }

  func syncDirectoryDescriptor(_ descriptor: Int32) throws {
    try base.syncDirectoryDescriptor(descriptor)
  }

  func syncBarrierFileDescriptor(_ descriptor: Int32) throws {
    try base.syncBarrierFileDescriptor(descriptor)
  }
}
