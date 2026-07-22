import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/database_encryption_cutover.dart';
import 'package:Kelivo/core/database/database_installation_gate.dart'
    hide DatabaseInstallationGate;
import 'package:Kelivo/core/database/database_installation_gate.dart'
    as production;
import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'test_database_cipher.dart';

final class DatabaseInstallationGate {
  static Future<DatabaseInstallationReceipt> ensureReady({
    required Directory appDataDirectory,
    bool allowDatabaseIdentityChange = false,
    RestoreDurability? durability,
  }) => production.DatabaseInstallationGate.ensureReady(
    appDataDirectory: appDataDirectory,
    cipher: testDatabaseCipher,
    allowDatabaseIdentityChange: allowDatabaseIdentityChange,
    durability: durability,
  );

  static Future<DatabaseInstallationReceipt?> read({
    required Directory appDataDirectory,
  }) => production.DatabaseInstallationGate.read(
    appDataDirectory: appDataDirectory,
    cipher: testDatabaseCipher,
  );
}

void main() {
  group('DatabaseInstallationGate', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'kelivo_database_installation_',
      );
    });

    tearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    File databaseFile(Directory root) =>
        File(p.join(root.path, AppDatabase.databaseFileName));

    test('首次安装创建带 identity 的数据库与 receipt', () async {
      final receipt = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: directory,
      );

      expect(await databaseFile(directory).exists(), isTrue);
      final info = ChatDatabaseRepository.inspectInstalledDatabase(
        databaseFile(directory),
        cipher: testDatabaseCipher,
      );
      expect(info.databaseId, receipt.databaseId);
      expect(
        (await DatabaseInstallationGate.read(
          appDataDirectory: directory,
        ))?.installationId,
        receipt.installationId,
      );
    });

    test('identity 一致的重复启动不改 receipt', () async {
      final first = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: directory,
      );
      final second = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: directory,
      );

      expect(second.installationId, first.installationId);
      expect(second.databaseId, first.databaseId);
    });

    test('升级时 adoption 已有有效数据库且不清空数据', () async {
      final repository = ChatDatabaseRepository.open(
        file: databaseFile(directory),
        cipher: testDatabaseCipher,
      );
      try {
        await repository.ensureReady();
      } finally {
        await repository.close();
      }
      final before = sqlite.sqlite3.open(databaseFile(directory).path);
      testDatabaseCipher.apply(before, createSlotIfMissing: false);
      before.execute(
        'INSERT INTO chat_storage_meta_rows (key, value) VALUES (?, ?);',
        ['upgrade_sentinel', 'keep'],
      );
      before.close();

      final receipt = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: directory,
      );

      expect(receipt.databaseId, isNotEmpty);
      expect(
        ChatDatabaseRepository.inspectInstalledDatabase(
          databaseFile(directory),
          cipher: testDatabaseCipher,
        ).databaseId,
        receipt.databaseId,
      );
      final after = sqlite.sqlite3.open(
        databaseFile(directory).path,
        mode: sqlite.OpenMode.readOnly,
      );
      testDatabaseCipher.apply(after, createSlotIfMissing: false);
      try {
        expect(
          after.select(
            'SELECT value FROM chat_storage_meta_rows WHERE key = ?;',
            ['upgrade_sentinel'],
          ).single['value'],
          'keep',
        );
      } finally {
        after.close();
      }
    });

    test('已有 receipt 但数据库缺失时拒绝且不创建空库', () async {
      await DatabaseInstallationGate.ensureReady(appDataDirectory: directory);
      await databaseFile(directory).delete();

      await expectLater(
        DatabaseInstallationGate.ensureReady(appDataDirectory: directory),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'database_missing',
          ),
        ),
      );
      expect(await databaseFile(directory).exists(), isFalse);
    });

    test('损坏数据库在无 receipt 升级场景也拒绝且不覆盖', () async {
      final file = databaseFile(directory);
      await file.writeAsString('not a sqlite database');

      await expectLater(
        DatabaseInstallationGate.ensureReady(appDataDirectory: directory),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'database_corrupt',
          ),
        ),
      );
      expect(await file.readAsString(), 'not a sqlite database');
    });

    test('高于当前 schema 的数据库拒绝 down migration', () async {
      final file = databaseFile(directory);
      final raw = sqlite.sqlite3.open(file.path);
      testDatabaseCipher.apply(raw, createSlotIfMissing: true);
      raw.userVersion = AppDatabase.currentSchemaVersion + 1;
      raw.close();

      await expectLater(
        DatabaseInstallationGate.ensureReady(appDataDirectory: directory),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'database_schema_version',
          ),
        ),
      );
    });

    test('损坏 installation receipt 时拒绝打开数据库', () async {
      await DatabaseInstallationGate.ensureReady(appDataDirectory: directory);
      final receipt = directory.listSync().whereType<File>().singleWhere(
        (file) =>
            p.basename(file.path).startsWith('database_installation_receipt_'),
      );
      await receipt.writeAsString('{broken');

      await expectLater(
        DatabaseInstallationGate.ensureReady(appDataDirectory: directory),
        throwsA(isA<FormatException>()),
      );
    });

    test('未授权的数据库 identity 替换被拒绝', () async {
      await DatabaseInstallationGate.ensureReady(appDataDirectory: directory);
      final originalReceipt = await DatabaseInstallationGate.read(
        appDataDirectory: directory,
      );
      final replacementRoot = await Directory.systemTemp.createTemp(
        'kelivo_database_replacement_',
      );
      addTearDown(() async {
        if (await replacementRoot.exists()) {
          await replacementRoot.delete(recursive: true);
        }
      });
      await DatabaseInstallationGate.ensureReady(
        appDataDirectory: replacementRoot,
      );
      await databaseFile(directory).delete();
      await databaseFile(replacementRoot).copy(databaseFile(directory).path);

      await expectLater(
        DatabaseInstallationGate.ensureReady(appDataDirectory: directory),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'database_identity_mismatch',
          ),
        ),
      );
      expect(
        File(
          p.join(
            directory.path,
            'database_installation_receipt_${originalReceipt!.databaseId}.json',
          ),
        ).existsSync(),
        isTrue,
      );
    });

    test('identity 替换不以全库 FK 扫描阻塞启动门', () async {
      await DatabaseInstallationGate.ensureReady(appDataDirectory: directory);
      final replacementRoot = await Directory.systemTemp.createTemp(
        'kelivo_database_replacement_corrupt_',
      );
      addTearDown(() async {
        if (await replacementRoot.exists()) {
          await replacementRoot.delete(recursive: true);
        }
      });
      await DatabaseInstallationGate.ensureReady(
        appDataDirectory: replacementRoot,
      );
      final replacement = databaseFile(replacementRoot);
      final raw = sqlite.sqlite3.open(replacement.path);
      testDatabaseCipher.apply(raw, createSlotIfMissing: false);
      raw.execute(
        'INSERT INTO tool_event_rows (message_id, events_json) VALUES (?, ?);',
        ['missing-message', '[]'],
      );
      raw.close();
      await databaseFile(directory).delete();
      await replacement.copy(databaseFile(directory).path);

      await expectLater(
        DatabaseInstallationGate.ensureReady(appDataDirectory: directory),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'database_identity_mismatch',
          ),
        ),
      );
    });

    test('已验证 restore 可轮换 database identity 并保留 installation', () async {
      final original = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: directory,
      );
      final replacementRoot = await Directory.systemTemp.createTemp(
        'kelivo_database_restore_',
      );
      addTearDown(() async {
        if (await replacementRoot.exists()) {
          await replacementRoot.delete(recursive: true);
        }
      });
      final replacement = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: replacementRoot,
      );
      await databaseFile(directory).delete();
      await databaseFile(replacementRoot).copy(databaseFile(directory).path);

      final updated = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: directory,
        allowDatabaseIdentityChange: true,
      );

      expect(updated.installationId, original.installationId);
      expect(updated.databaseId, replacement.databaseId);
    });

    test('废弃的 session receipt 不参与启动判定', () async {
      await DatabaseInstallationGate.ensureReady(appDataDirectory: directory);
      final sessionFile = File(
        p.join(directory.path, '.database_session_receipt.json'),
      );
      await sessionFile.writeAsString('{broken', flush: true);

      final receipt = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: directory,
      );

      expect(receipt.databaseId, isNotEmpty);
      expect(await databaseFile(directory).exists(), isTrue);
      expect(await sessionFile.readAsString(), '{broken');
    });

    test('硬切删除主库与恢复工作区中的明文数据库后创建密文库', () async {
      final mainFile = databaseFile(directory);
      final plaintext = sqlite.sqlite3.open(mainFile.path);
      plaintext.execute('CREATE TABLE legacy_rows (value TEXT);');
      plaintext.close();
      for (final suffix in const ['-wal', '-shm', '-journal']) {
        await File('${mainFile.path}$suffix').writeAsBytes([1], flush: true);
      }
      final legacyReceipt = File(
        p.join(directory.path, 'database_installation_receipt_legacy.json'),
      );
      await legacyReceipt.writeAsString('{legacy', flush: true);
      final legacyHiveFiles = [
        for (final name in const [
          'conversations.hive',
          'messages.hive',
          'tool_events_v1.hive',
        ])
          await File(
            p.join(directory.path, name),
          ).writeAsBytes([1, 2, 3], flush: true),
      ];
      final pendingDatabase = File(
        p.join(
          directory.path,
          '.kelivo_restore',
          'run_0123456789abcdef0123456789abcdef',
          'candidate',
          'database',
          AppDatabase.databaseFileName,
        ),
      );
      await pendingDatabase.parent.create(recursive: true);
      final pending = sqlite.sqlite3.open(pendingDatabase.path);
      pending.execute('CREATE TABLE pending_rows (value TEXT);');
      pending.close();

      await DatabaseEncryptionCutover.discardPlaintextState(
        appDataDirectory: directory,
      );

      for (final suffix in const ['', '-wal', '-shm', '-journal']) {
        expect(await File('${mainFile.path}$suffix').exists(), isFalse);
      }
      expect(await legacyReceipt.exists(), isFalse);
      for (final file in legacyHiveFiles) {
        expect(await file.exists(), isFalse);
      }
      expect(await pendingDatabase.exists(), isFalse);

      await DatabaseInstallationGate.ensureReady(appDataDirectory: directory);
      expect(await _hasPlaintextSqliteHeader(mainFile), isFalse);
      final wrongKeyDatabase = sqlite.sqlite3.open(
        mainFile.path,
        mode: sqlite.OpenMode.readOnly,
      );
      try {
        expect(
          () => const TestDatabaseCipher(
            rawKeyHex:
                '0000000000000000000000000000000000000000000000000000000000000000',
          ).apply(wrongKeyDatabase, createSlotIfMissing: false),
          throwsA(isA<sqlite.SqliteException>()),
        );
      } finally {
        wrongKeyDatabase.close();
      }
    });

    test('硬切保留现有密文主库与密文恢复候选', () async {
      final receipt = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: directory,
      );
      final mainFile = databaseFile(directory);
      final candidate = File(
        p.join(
          directory.path,
          '.kelivo_restore',
          'run_0123456789abcdef0123456789abcdef',
          'candidate',
          'database',
          AppDatabase.databaseFileName,
        ),
      );
      await candidate.parent.create(recursive: true);
      await mainFile.copy(candidate.path);

      await DatabaseEncryptionCutover.discardPlaintextState(
        appDataDirectory: directory,
      );

      expect(await mainFile.exists(), isTrue);
      expect(await candidate.exists(), isTrue);
      expect(
        (await DatabaseInstallationGate.read(
          appDataDirectory: directory,
        ))?.databaseId,
        receipt.databaseId,
      );
    });

    test('硬切会继续清理已经标记但尚未删除完的恢复工作区', () async {
      final workspace = Directory(p.join(directory.path, '.kelivo_restore'));
      final remainingFile = File(
        p.join(
          workspace.path,
          'run_0123456789abcdef0123456789abcdef',
          'candidate',
          'remaining.bin',
        ),
      );
      await remainingFile.parent.create(recursive: true);
      await remainingFile.writeAsBytes([1, 2, 3], flush: true);
      final marker = File(
        p.join(workspace.path, '.database-encryption-cutover-v1'),
      );
      await marker.writeAsString('1\n', flush: true);

      await DatabaseEncryptionCutover.discardPlaintextState(
        appDataDirectory: directory,
      );

      expect(await remainingFile.exists(), isFalse);
      expect(await marker.exists(), isFalse);
    });

    test('硬切会从主库清理标记恢复并删除孤立侧车与回执', () async {
      final mainFile = databaseFile(directory);
      final sidecar = File('${mainFile.path}-wal');
      await sidecar.writeAsBytes([1, 2, 3], flush: true);
      final receipt = File(
        p.join(directory.path, 'database_installation_receipt_orphan.json'),
      );
      await receipt.writeAsString('{orphan', flush: true);
      final marker = File(
        p.join(directory.path, '.database-encryption-cutover-v1'),
      );
      await marker.writeAsString('1\n', flush: true);

      await DatabaseEncryptionCutover.discardPlaintextState(
        appDataDirectory: directory,
      );

      expect(await sidecar.exists(), isFalse);
      expect(await receipt.exists(), isFalse);
      expect(await marker.exists(), isFalse);
      await DatabaseInstallationGate.ensureReady(appDataDirectory: directory);
      expect(await _hasPlaintextSqliteHeader(mainFile), isFalse);
    });

    test('硬切不会把未知或损坏文件误判成可删除的明文库', () async {
      final mainFile = databaseFile(directory);
      await mainFile.writeAsBytes([1, 2, 3, 4], flush: true);
      final sidecar = File('${mainFile.path}-wal');
      await sidecar.writeAsBytes([5, 6], flush: true);
      final receipt = File(
        p.join(directory.path, 'database_installation_receipt_unknown.json'),
      );
      await receipt.writeAsString('{unknown', flush: true);

      await DatabaseEncryptionCutover.discardPlaintextState(
        appDataDirectory: directory,
      );

      expect(await mainFile.readAsBytes(), [1, 2, 3, 4]);
      expect(await sidecar.readAsBytes(), [5, 6]);
      expect(await receipt.readAsString(), '{unknown');
    });
  });
}

Future<bool> _hasPlaintextSqliteHeader(File file) async {
  const expected = <int>[
    0x53,
    0x51,
    0x4c,
    0x69,
    0x74,
    0x65,
    0x20,
    0x66,
    0x6f,
    0x72,
    0x6d,
    0x61,
    0x74,
    0x20,
    0x33,
    0x00,
  ];
  if (await file.length() < expected.length) return false;
  final input = await file.open();
  try {
    final actual = await input.read(expected.length);
    return actual.length == expected.length &&
        actual.indexed.every((entry) => entry.$2 == expected[entry.$1]);
  } finally {
    await input.close();
  }
}
