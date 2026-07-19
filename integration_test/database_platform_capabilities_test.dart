import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
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
