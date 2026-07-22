import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/sqlcipher_database_key.dart';
import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/workspace/account_session_token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

const _sqlCipherTestKey =
    '7f4f771e734b28981b5b786ac0f281f684253a0e72128d6466ed1d49b0f38a27';
const _sqlCipherWrongTestKey =
    '83361ed49fd0df3da820687f3630c3907c6b8b987d7c7ce2e3a3364933aa22ac';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DB2-07 native platform capability matrix', (tester) async {
    final root = await Directory.systemTemp.createTemp(
      'kelivo_db2_platform_capability_',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    final schemaVersion = await _verifySchemaContract(root);
    final secureCoreCapabilities = await _verifySecureCoreCapabilities();
    final secureSessionTokenCapabilities = await _verifySecureSessionTokenStore(
      root,
    );
    final secureSqlCipherKeyCapabilities =
        await _verifySecureSqlCipherKeyBridge(root);
    final sqlCipherCapabilities = await _verifySqlCipherRoundTrip(root);
    final sqliteCapabilities = await _verifySqliteCapabilities(root);
    await _verifyDurableFileOperations(root);

    final version = sqlite.sqlite3.version;
    final report = <String, Object>{
      'format': 'kelivo-db2-platform-capabilities-v1',
      'platform': Platform.operatingSystem,
      'operatingSystemVersion': Platform.operatingSystemVersion,
      'abi': Abi.current().toString(),
      'sqliteVersion': version.libVersion,
      'sqliteVersionNumber': version.versionNumber,
      'sqliteSourceId': version.sourceId,
      'schemaVersion': schemaVersion,
      ...secureCoreCapabilities,
      ...secureSessionTokenCapabilities,
      ...secureSqlCipherKeyCapabilities,
      ...sqlCipherCapabilities,
      ...sqliteCapabilities,
      'fileLock': true,
      'fullBarrierRename': true,
    };
    // 提供不含数据库路径或应用数据的机器可读证据。
    // ignore: avoid_print
    print('DB2_CAPABILITY_RESULT:${jsonEncode(report)}');
  });
}

Future<Map<String, Object>> _verifySecureSqlCipherKeyBridge(
  Directory root,
) async {
  if (!Platform.isWindows && !Platform.isAndroid) {
    return const <String, Object>{'secureSqlCipherKeyBridge': false};
  }

  const sentinel = 'secure-core-sqlcipher-key-sentinel';
  const workspaceKey =
      '13579bdf2468ace013579bdf2468ace013579bdf2468ace013579bdf2468ace0';
  const wrongWorkspaceKey =
      '02468ace13579bdf02468ace13579bdf02468ace13579bdf02468ace13579bdf';
  final databaseFile = File(
    p.join(root.path, 'secure-core-sqlcipher-key.sqlite'),
  );
  final key = SqlCipherDatabaseKey.forWorkspace(workspaceKey);
  final database = sqlite.sqlite3.open(databaseFile.path);
  try {
    key.apply(database, createSlotIfMissing: true);
    database.execute('CREATE TABLE protected_rows(value TEXT NOT NULL);');
    database.execute('INSERT INTO protected_rows(value) VALUES (?);', [
      sentinel,
    ]);
  } finally {
    database.close();
  }

  expect(
    await databaseFile.openRead(0, 16).first,
    isNot(equals(utf8.encode('SQLite format 3\u0000'))),
  );
  expect(
    _containsBytes(await databaseFile.readAsBytes(), utf8.encode(sentinel)),
    isFalse,
  );

  final reopened = sqlite.sqlite3.open(
    databaseFile.path,
    mode: sqlite.OpenMode.readOnly,
  );
  try {
    key.apply(reopened, createSlotIfMissing: false);
    expect(
      reopened.select('SELECT value FROM protected_rows;').single['value'],
      sentinel,
    );
  } finally {
    reopened.close();
  }

  final wrongKeyDatabase = sqlite.sqlite3.open(
    databaseFile.path,
    mode: sqlite.OpenMode.readOnly,
  );
  try {
    expect(
      () => SqlCipherDatabaseKey.forWorkspace(
        wrongWorkspaceKey,
      ).apply(wrongKeyDatabase, createSlotIfMissing: true),
      throwsA(isA<sqlite.SqliteException>()),
    );
  } finally {
    wrongKeyDatabase.close();
  }

  final unkeyed = sqlite.sqlite3.open(
    databaseFile.path,
    mode: sqlite.OpenMode.readOnly,
  );
  try {
    expect(
      () => unkeyed.select('SELECT count(*) FROM sqlite_master;'),
      throwsA(isA<sqlite.SqliteException>()),
    );
  } finally {
    unkeyed.close();
  }

  return const <String, Object>{'secureSqlCipherKeyBridge': true};
}

Future<Map<String, Object>> _verifySecureSessionTokenStore(
  Directory root,
) async {
  if (!Platform.isWindows && !Platform.isAndroid) {
    return const <String, Object>{
      'secureSessionTokenAtRest': false,
      'secureSessionTokenDeletion': false,
    };
  }

  const store = SecureAccountSessionTokenStore();
  const workspaceKey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const firstToken = 'platform-session-token-first-sentinel';
  const secondToken = 'platform-session-token-second-sentinel';
  final accountDirectory = Directory(p.join(root.path, 'session-token-store'));
  await accountDirectory.create(recursive: true);
  final durability = RestorePlatformDurability();

  final absentReference = AccountSessionTokenReference(
    generation: 1,
    slot: 'a',
  );
  await expectLater(
    store.readToken(
      accountDirectory: accountDirectory,
      workspaceKey: workspaceKey,
      reference: absentReference,
    ),
    throwsA(isA<StateError>()),
  );

  final firstReference = await store.writeToken(
    accountDirectory: accountDirectory,
    workspaceKey: workspaceKey,
    token: firstToken,
    currentReference: null,
    durability: durability,
  );
  expect(firstReference.toJson(), <String, Object>{
    'version': 1,
    'generation': 1,
    'slot': 'a',
  });
  final firstFile = File(
    p.join(accountDirectory.path, 'token-v1-${firstReference.slot}.bin'),
  );
  expect(
    _containsBytes(await firstFile.readAsBytes(), utf8.encode(firstToken)),
    isFalse,
  );
  expect(
    await store.readToken(
      accountDirectory: accountDirectory,
      workspaceKey: workspaceKey,
      reference: firstReference,
    ),
    firstToken,
  );

  final secondReference = await store.writeToken(
    accountDirectory: accountDirectory,
    workspaceKey: workspaceKey,
    token: secondToken,
    currentReference: firstReference,
    durability: durability,
  );
  expect(secondReference.generation, 2);
  expect(secondReference.slot, 'b');
  await store.deleteTokens(
    accountDirectory: accountDirectory,
    keep: secondReference,
    durability: durability,
  );
  expect(await firstFile.exists(), isFalse);
  expect(
    await store.readToken(
      accountDirectory: accountDirectory,
      workspaceKey: workspaceKey,
      reference: secondReference,
    ),
    secondToken,
  );

  final secondFile = File(
    p.join(accountDirectory.path, 'token-v1-${secondReference.slot}.bin'),
  );
  final corruptedFrame = await secondFile.readAsBytes();
  corruptedFrame[corruptedFrame.length - 1] ^= 1;
  await secondFile.writeAsBytes(corruptedFrame, flush: true);
  await expectLater(
    store.readToken(
      accountDirectory: accountDirectory,
      workspaceKey: workspaceKey,
      reference: secondReference,
    ),
    _throwsSecureCoreStatus(KelivoSecureCoreStatus.recordAuthenticationFailed),
  );

  await store.deleteTokens(
    accountDirectory: accountDirectory,
    keep: null,
    durability: durability,
  );
  expect(await secondFile.exists(), isFalse);
  await expectLater(
    store.readToken(
      accountDirectory: accountDirectory,
      workspaceKey: workspaceKey,
      reference: secondReference,
    ),
    throwsA(isA<StateError>()),
  );

  return const <String, Object>{
    'secureSessionTokenAtRest': true,
    'secureSessionTokenDeletion': true,
  };
}

Future<Map<String, Object>> _verifySecureCoreCapabilities() async {
  const secureCore = KelivoSecureCore();
  final capabilities = await secureCore.getCapabilities();
  expect(capabilities.abiVersion, 1);
  await expectLater(secureCore.createSlot(Uint8List(15)), throwsArgumentError);

  if (Platform.isWindows) {
    expect(capabilities.backend, KelivoSecureStorageBackend.windowsDpapi);
    expect(capabilities.supportsKeySlots, isTrue);
    expect(capabilities.supportsBackgroundAccess, isTrue);
    expect(capabilities.supportsRecordEnvelopes, isTrue);
    expect(capabilities.supportsSqlCipherKeyApplication, isTrue);
    await _verifyPersistentSecureCoreSlot(
      secureCore,
      slotId: Uint8List.fromList('kelivo-dpapi-v01'.codeUnits),
    );
  } else if (Platform.isAndroid) {
    expect(capabilities.backend, KelivoSecureStorageBackend.androidKeystore);
    expect(capabilities.supportsKeySlots, isTrue);
    expect(capabilities.supportsBackgroundAccess, isTrue);
    expect(capabilities.supportsRecordEnvelopes, isTrue);
    expect(capabilities.supportsSqlCipherKeyApplication, isTrue);
    await _verifyPersistentSecureCoreSlot(
      secureCore,
      slotId: Uint8List.fromList('kelivo-keystore1'.codeUnits),
    );
  } else {
    expect(capabilities.backend, KelivoSecureStorageBackend.none);
    expect(capabilities.supportsKeySlots, isFalse);
    expect(capabilities.supportsBackgroundAccess, isFalse);
    expect(capabilities.supportsRecordEnvelopes, isFalse);
    expect(capabilities.supportsSqlCipherKeyApplication, isFalse);
    await _verifyUnsupportedSecureCoreSlots(secureCore);
  }

  return {
    'secureCoreAbiVersion': capabilities.abiVersion,
    'secureStorageBackend': capabilities.backend.name,
    'secureCoreKeySlots': capabilities.supportsKeySlots,
    'secureCoreBackgroundAccess': capabilities.supportsBackgroundAccess,
    'secureCoreRecordEnvelopes': capabilities.supportsRecordEnvelopes,
    'secureCoreSqlCipherKeyApplication':
        capabilities.supportsSqlCipherKeyApplication,
    'secureCoreFailClosed': true,
  };
}

Future<void> _verifyUnsupportedSecureCoreSlots(
  KelivoSecureCore secureCore,
) async {
  await expectLater(
    secureCore.createSlot(Uint8List(16)),
    throwsA(
      isA<KelivoSecureCoreException>().having(
        (error) => error.status,
        'status',
        KelivoSecureCoreStatus.unsupportedPlatform,
      ),
    ),
  );
  await expectLater(
    secureCore.openSlot(Uint8List(16)),
    throwsA(
      isA<KelivoSecureCoreException>().having(
        (error) => error.status,
        'status',
        KelivoSecureCoreStatus.unsupportedPlatform,
      ),
    ),
  );
}

Future<void> _verifyPersistentSecureCoreSlot(
  KelivoSecureCore secureCore, {
  required Uint8List slotId,
}) async {
  await expectLater(
    secureCore.openSlot(Uint8List.fromList('kelivo-absent-v1'.codeUnits)),
    throwsA(
      isA<KelivoSecureCoreException>().having(
        (error) => error.status,
        'status',
        KelivoSecureCoreStatus.slotNotFound,
      ),
    ),
  );

  KelivoKeyHandle handle;
  try {
    handle = await secureCore.createSlot(slotId);
  } on KelivoSecureCoreException catch (error) {
    expect(error.status, KelivoSecureCoreStatus.slotAlreadyExists);
    handle = await secureCore.openSlot(slotId);
  }
  await expectLater(
    secureCore.createSlot(slotId),
    throwsA(
      isA<KelivoSecureCoreException>().having(
        (error) => error.status,
        'status',
        KelivoSecureCoreStatus.slotAlreadyExists,
      ),
    ),
  );
  await secureCore.close(handle);
  await expectLater(secureCore.close(handle), throwsStateError);
  expect(
    () => secureCore.sealRecord(
      handle,
      recordId: Uint8List.fromList('record-envelope1'.codeUnits),
      epoch: 1,
      associatedData: Uint8List(0),
      plaintext: Uint8List(0),
    ),
    throwsStateError,
  );

  final reopened = await secureCore.openSlot(slotId);
  await _verifyRecordEnvelope(secureCore, reopened);
  await secureCore.close(reopened);
}

Future<void> _verifyRecordEnvelope(
  KelivoSecureCore secureCore,
  KelivoKeyHandle handle,
) async {
  final recordId = Uint8List.fromList('record-envelope1'.codeUnits);
  final associatedData = Uint8List.fromList('account/vault/record'.codeUnits);
  final plaintext = Uint8List.fromList('encrypted record payload'.codeUnits);

  final envelope = await secureCore.sealRecord(
    handle,
    recordId: recordId,
    epoch: 1,
    associatedData: associatedData,
    plaintext: plaintext,
  );
  final opened = await secureCore.openRecord(
    handle,
    recordId: recordId,
    epoch: 1,
    associatedData: associatedData,
    envelope: envelope,
  );

  expect(opened, orderedEquals(plaintext));

  final emptyEnvelope = await secureCore.sealRecord(
    handle,
    recordId: recordId,
    epoch: 1,
    associatedData: associatedData,
    plaintext: Uint8List(0),
  );
  final emptyPlaintext = await secureCore.openRecord(
    handle,
    recordId: recordId,
    epoch: 1,
    associatedData: associatedData,
    envelope: emptyEnvelope,
  );
  expect(emptyPlaintext, isEmpty);

  final tamperedEnvelope = Uint8List.fromList(envelope);
  tamperedEnvelope[tamperedEnvelope.length - 1] ^= 1;
  await expectLater(
    secureCore.openRecord(
      handle,
      recordId: recordId,
      epoch: 1,
      associatedData: associatedData,
      envelope: tamperedEnvelope,
    ),
    _throwsSecureCoreStatus(KelivoSecureCoreStatus.recordAuthenticationFailed),
  );

  final wrongAssociatedData = Uint8List.fromList(associatedData);
  wrongAssociatedData[0] ^= 1;
  await expectLater(
    secureCore.openRecord(
      handle,
      recordId: recordId,
      epoch: 1,
      associatedData: wrongAssociatedData,
      envelope: envelope,
    ),
    _throwsSecureCoreStatus(KelivoSecureCoreStatus.recordAuthenticationFailed),
  );

  final wrongRecordId = Uint8List.fromList(recordId);
  wrongRecordId[0] ^= 1;
  await expectLater(
    secureCore.openRecord(
      handle,
      recordId: wrongRecordId,
      epoch: 1,
      associatedData: associatedData,
      envelope: envelope,
    ),
    _throwsSecureCoreStatus(KelivoSecureCoreStatus.recordAuthenticationFailed),
  );

  final unsupportedVersionEnvelope = Uint8List.fromList(envelope);
  unsupportedVersionEnvelope[1] = 2;
  await expectLater(
    secureCore.openRecord(
      handle,
      recordId: recordId,
      epoch: 1,
      associatedData: associatedData,
      envelope: unsupportedVersionEnvelope,
    ),
    _throwsSecureCoreStatus(KelivoSecureCoreStatus.recordEnvelopeInvalid),
  );

  expect(
    () => secureCore.sealRecord(
      handle,
      recordId: Uint8List(15),
      epoch: 1,
      associatedData: associatedData,
      plaintext: plaintext,
    ),
    throwsArgumentError,
  );
  expect(
    () => secureCore.sealRecord(
      handle,
      recordId: recordId,
      epoch: 0,
      associatedData: associatedData,
      plaintext: plaintext,
    ),
    throwsArgumentError,
  );
  expect(
    () => secureCore.sealRecord(
      handle,
      recordId: recordId,
      epoch: 1,
      associatedData: Uint8List(64 * 1024 + 1),
      plaintext: plaintext,
    ),
    throwsArgumentError,
  );
}

Matcher _throwsSecureCoreStatus(KelivoSecureCoreStatus status) {
  return throwsA(
    isA<KelivoSecureCoreException>().having(
      (error) => error.status,
      'status',
      status,
    ),
  );
}

Future<int> _verifySchemaContract(Directory root) async {
  final currentFile = File(p.join(root.path, 'current.sqlite'));
  var repository = ChatDatabaseRepository.open(file: currentFile);
  try {
    await repository.ensureReady();
    await repository.validateConnectionContract();
    await repository.validateIntegrity();
  } finally {
    await repository.close();
  }

  final currentInfo = ChatDatabaseRepository.inspectInstalledDatabase(
    currentFile,
    validateContents: true,
  );
  expect(currentInfo.schemaVersion, AppDatabase.currentSchemaVersion);

  final incompatibleFile = File(p.join(root.path, 'incompatible.sqlite'));
  final incompatible = sqlite.sqlite3.open(incompatibleFile.path);
  incompatible.userVersion = AppDatabase.currentSchemaVersion - 1;
  incompatible.close();

  repository = ChatDatabaseRepository.open(file: incompatibleFile);
  try {
    await expectLater(
      repository.ensureReady(),
      throwsA(
        predicate<Object>(
          (error) => error.toString().contains('database_schema_version'),
        ),
      ),
    );
  } finally {
    await repository.close();
  }

  final rejected = sqlite.sqlite3.open(incompatibleFile.path);
  try {
    expect(rejected.userVersion, AppDatabase.currentSchemaVersion - 1);
  } finally {
    rejected.close();
  }
  return currentInfo.schemaVersion;
}

Future<Map<String, Object>> _verifySqlCipherRoundTrip(Directory root) async {
  const sentinel = 'kelivo-sqlcipher-round-trip-sentinel';
  final databaseFile = File(p.join(root.path, 'sqlcipher-round-trip.sqlite'));

  expect(
    () => _openSqlCipher(databaseFile, _sqlCipherTestKey.substring(1)),
    throwsArgumentError,
  );

  final database = _openSqlCipher(databaseFile, _sqlCipherTestKey);
  late final String cipherVersion;
  try {
    cipherVersion = _readCipherVersion(database);
    database.execute('PRAGMA journal_mode = WAL;');
    database.execute('PRAGMA wal_autocheckpoint = 0;');
    database.execute('CREATE TABLE encrypted_rows(value TEXT NOT NULL);');
    database.execute('INSERT INTO encrypted_rows(value) VALUES (?);', [
      sentinel,
    ]);

    final wal = File('${databaseFile.path}-wal');
    expect(await wal.exists(), isTrue);
    expect(
      _containsBytes(await wal.readAsBytes(), utf8.encode(sentinel)),
      isFalse,
    );
  } finally {
    database.close();
  }

  final encryptedHeader = await databaseFile.openRead(0, 16).first;
  expect(encryptedHeader, isNot(equals(utf8.encode('SQLite format 3\u0000'))));
  expect(
    _containsBytes(await databaseFile.readAsBytes(), utf8.encode(sentinel)),
    isFalse,
  );

  final reopened = _openSqlCipher(
    databaseFile,
    _sqlCipherTestKey,
    mode: sqlite.OpenMode.readOnly,
  );
  try {
    expect(
      reopened.select('SELECT value FROM encrypted_rows;').single['value'],
      sentinel,
    );
  } finally {
    reopened.close();
  }

  final beforeWrongKey = await _readDatabaseFamily(databaseFile);
  expect(
    () => _openSqlCipher(
      databaseFile,
      _sqlCipherWrongTestKey,
      mode: sqlite.OpenMode.readWrite,
    ),
    throwsA(
      isA<sqlite.SqliteException>().having(
        (error) => error.resultCode,
        'resultCode',
        26,
      ),
    ),
  );
  expect(await _readDatabaseFamily(databaseFile), beforeWrongKey);

  final unkeyed = sqlite.sqlite3.open(
    databaseFile.path,
    mode: sqlite.OpenMode.readOnly,
  );
  try {
    expect(
      () => unkeyed.select('SELECT count(*) FROM sqlite_master;'),
      throwsA(isA<sqlite.SqliteException>()),
    );
  } finally {
    unkeyed.close();
  }

  return {
    'sqlCipherVersion': cipherVersion,
    'encryptedDatabaseHeader': true,
    'encryptedWal': true,
    'sameKeyReopen': true,
    'wrongKeyRejected': true,
    'wrongKeyPreservesFile': true,
    'unkeyedOpenRejected': true,
    'invalidKeyLengthRejected': true,
  };
}

Future<Map<String, Object>> _verifySqliteCapabilities(Directory root) async {
  const backupSentinel = 'kelivo-sqlcipher-backup-sentinel';
  final sourceFile = File(p.join(root.path, 'source.sqlite'));
  final backupFile = File(p.join(root.path, 'backup.sqlite'));
  final source = _openSqlCipher(sourceFile, _sqlCipherTestKey);
  sqlite.Database? backup;
  sqlite.Database? contender;
  try {
    final journalMode = source
        .select('PRAGMA journal_mode = WAL;')
        .single
        .values
        .single
        .toString()
        .toLowerCase();
    source.execute('PRAGMA synchronous = FULL;');
    final synchronous =
        source.select('PRAGMA synchronous;').single.values.single as int;
    expect(journalMode, 'wal');
    expect(synchronous, 2);

    expect(sqlite.sqlite3.usedCompileOption('ENABLE_FTS5'), isTrue);
    source.execute(
      "CREATE VIRTUAL TABLE capability_fts USING fts5(content, tokenize='unicode61');",
    );
    source.execute('INSERT INTO capability_fts(content) VALUES (?);', [
      'database capability 中文测试',
    ]);
    expect(
      source.select(
        'SELECT COUNT(*) AS count FROM capability_fts '
        'WHERE capability_fts MATCH ?;',
        ['database'],
      ).single['count'],
      1,
    );
    final shortChineseMatchCount =
        source.select(
              'SELECT COUNT(*) AS count FROM capability_fts '
              'WHERE capability_fts MATCH ?;',
              ['中文'],
            ).single['count']
            as int;
    expect(
      source.select(
        'SELECT COUNT(*) AS count FROM capability_fts '
        'WHERE capability_fts MATCH ?;',
        ['中文测试'],
      ).single['count'],
      1,
    );

    source.execute('CREATE TABLE capability_rows(value TEXT NOT NULL);');
    source.execute('INSERT INTO capability_rows(value) VALUES (?);', [
      backupSentinel,
    ]);
    backup = _openSqlCipher(backupFile, _sqlCipherTestKey);
    await source.backup(backup, nPage: 1).drain<void>();
    expect(
      backup.select('SELECT value FROM capability_rows;').single['value'],
      backupSentinel,
    );
    expect(backup.select('PRAGMA integrity_check;').single.values.single, 'ok');
    backup.close();
    backup = null;

    final encryptedBackupHeader = await backupFile.openRead(0, 16).first;
    expect(
      encryptedBackupHeader,
      isNot(equals(utf8.encode('SQLite format 3\u0000'))),
    );
    expect(
      _containsBytes(
        await backupFile.readAsBytes(),
        utf8.encode(backupSentinel),
      ),
      isFalse,
    );

    final reopenedBackup = _openSqlCipher(
      backupFile,
      _sqlCipherTestKey,
      mode: sqlite.OpenMode.readOnly,
    );
    try {
      expect(
        reopenedBackup
            .select('SELECT value FROM capability_rows;')
            .single['value'],
        backupSentinel,
      );
      expect(
        reopenedBackup.select('PRAGMA integrity_check;').single.values.single,
        'ok',
      );
    } finally {
      reopenedBackup.close();
    }

    final beforeWrongBackupKey = await _readDatabaseFamily(backupFile);
    expect(
      () => _openSqlCipher(
        backupFile,
        _sqlCipherWrongTestKey,
        mode: sqlite.OpenMode.readWrite,
      ),
      throwsA(
        isA<sqlite.SqliteException>().having(
          (error) => error.resultCode,
          'resultCode',
          26,
        ),
      ),
    );
    expect(await _readDatabaseFamily(backupFile), beforeWrongBackupKey);

    final unkeyedBackup = sqlite.sqlite3.open(
      backupFile.path,
      mode: sqlite.OpenMode.readOnly,
    );
    try {
      expect(
        () => unkeyedBackup.select('SELECT count(*) FROM sqlite_master;'),
        throwsA(isA<sqlite.SqliteException>()),
      );
    } finally {
      unkeyedBackup.close();
    }

    source.execute('BEGIN IMMEDIATE;');
    contender = _openSqlCipher(sourceFile, _sqlCipherTestKey);
    contender.execute('PRAGMA busy_timeout = 1;');
    expect(
      () => contender!.execute('BEGIN IMMEDIATE;'),
      throwsA(isA<sqlite.SqliteException>()),
    );
    source.execute('ROLLBACK;');

    return {
      'fts5': true,
      'unicode61': true,
      'shortChineseMatchCount': shortChineseMatchCount,
      'onlineBackup': true,
      'sqliteLockContention': true,
      'journalMode': journalMode,
      'synchronous': synchronous,
    };
  } finally {
    contender?.close();
    backup?.close();
    source.close();
  }
}

sqlite.Database _openSqlCipher(
  File file,
  String rawKeyHex, {
  sqlite.OpenMode mode = sqlite.OpenMode.readWriteCreate,
}) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(rawKeyHex)) {
    throw ArgumentError.value(rawKeyHex.length, 'rawKeyHex');
  }
  final database = sqlite.sqlite3.open(file.path, mode: mode);
  try {
    // 测试密钥只用于验证原生 SQLCipher 资产，产品密钥不得经此 Dart 接口传递。
    database.execute('PRAGMA key = "x\'$rawKeyHex\'";');
    _readCipherVersion(database);
    database.select('SELECT count(*) FROM sqlite_master;');
    return database;
  } catch (_) {
    database.close();
    rethrow;
  }
}

String _readCipherVersion(sqlite.Database database) {
  final rows = database.select('PRAGMA cipher_version;');
  if (rows.length != 1) throw StateError('sqlcipher_unavailable');
  final version = rows.single.values.single.toString().trim();
  if (version.isEmpty) throw StateError('sqlcipher_unavailable');
  return version;
}

bool _containsBytes(List<int> source, List<int> pattern) {
  if (pattern.isEmpty) return true;
  for (var offset = 0; offset <= source.length - pattern.length; offset++) {
    var matches = true;
    for (var index = 0; index < pattern.length; index++) {
      if (source[offset + index] != pattern[index]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}

Future<Map<String, List<int>?>> _readDatabaseFamily(File databaseFile) async {
  final contents = <String, List<int>?>{};
  for (final suffix in const ['', '-wal', '-shm']) {
    final file = File('${databaseFile.path}$suffix');
    contents[suffix] = await file.exists() ? await file.readAsBytes() : null;
  }
  return contents;
}

Future<void> _verifyDurableFileOperations(Directory root) async {
  final durability = RestorePlatformDurability();
  final source = File(p.join(root.path, 'barrier-source'));
  final target = File(p.join(root.path, 'barrier-target'));
  await source.writeAsBytes(const [1, 2, 3, 4], flush: true);
  await durability.restrictFile(source);

  final lockHandle = await source.open(mode: FileMode.append);
  try {
    await lockHandle.lock(FileLock.exclusive);
    await lockHandle.unlock();
  } finally {
    await lockHandle.close();
  }

  await durability.syncFile(source, fullBarrier: true);
  await durability.renameAndSync(source: source, targetPath: target.path);
  expect(await target.readAsBytes(), const [1, 2, 3, 4]);
  await durability.syncDirectory(root, fullBarrier: true);
}
