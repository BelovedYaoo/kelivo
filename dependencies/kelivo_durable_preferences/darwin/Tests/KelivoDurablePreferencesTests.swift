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
    let first = DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )

    try first.initialize()
    try first.set(valueType: "String", key: "flutter.secret", value: "value")

    let reopened = DurablePreferencesFileStore(
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
    let verified = DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )
    try verified.initialize()
    XCTAssertNil(verified.getAll(prefix: "", allowList: nil)["flutter.secret"])
    XCTAssertNoThrow(try verified.remove(key: "flutter.secret"))
  }

  func testDirectoryBarrierFailureRequiresIdempotentRetry() throws {
    let directory = root.appendingPathComponent("preferences", isDirectory: true)
    let legacy = StubLegacyPreferences()
    let initial = DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )
    try initial.initialize()
    try initial.set(valueType: "String", key: "flutter.secret", value: "value")
    let failing = DurablePreferencesFileStore(
      directory: directory,
      durability: FailingDirectoryDurability(failAtCall: 2),
      legacyPreferences: legacy
    )

    XCTAssertThrowsError(try failing.remove(key: "flutter.secret"))

    let retry = DurablePreferencesFileStore(
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
    let first = DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: contaminated
    )

    XCTAssertThrowsError(try first.initialize())
    XCTAssertEqual(contaminated.removedKeys, Set(["flutter.secret"]))

    let cleanLegacy = StubLegacyPreferences()
    let reopened = DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: cleanLegacy
    )
    XCTAssertThrowsError(try reopened.initialize())
  }

  func testCrashTemporaryFileIsRemovedBeforeOpeningSnapshot() throws {
    let directory = root.appendingPathComponent("preferences", isDirectory: true)
    let legacy = StubLegacyPreferences()
    let first = DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )
    try first.initialize()
    let stale = directory.appendingPathComponent(
      ".preferences-v1.tmp.crashed",
      isDirectory: false
    )
    try Data("secret".utf8).write(to: stale)

    let reopened = DurablePreferencesFileStore(
      directory: directory,
      durability: DarwinPreferencesDurability(),
      legacyPreferences: legacy
    )
    try reopened.initialize()

    XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
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
}
