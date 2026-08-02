import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/database_installation_gate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'test_database_cipher.dart';

void main() {
  test(
    'installation gate creates and validates only the current schema',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kelivo_current_schema_',
      );
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });

      await DatabaseInstallationGate.ensureReady(
        appDataDirectory: directory,
        cipher: testDatabaseCipher,
        retireAttachmentStaging: () async {},
      );

      final file = File(p.join(directory.path, AppDatabase.databaseFileName));
      final installed = ChatDatabaseRepository.inspectInstalledDatabase(
        file,
        cipher: testDatabaseCipher,
      );
      expect(installed.schemaVersion, AppDatabase.currentSchemaVersion);
      expect(installed.databaseId, isNotEmpty);
    },
  );

  test(
    'installation gate hard-cuts every obsolete SQLite schema',
    () async {
      for (
        var schemaVersion = 1;
        schemaVersion < AppDatabase.currentSchemaVersion;
        schemaVersion++
      ) {
        final directory = await Directory.systemTemp.createTemp(
          'kelivo_reject_schema_${schemaVersion}_',
        );
        addTearDown(() async {
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        });
        final file = File(p.join(directory.path, AppDatabase.databaseFileName));
        final database = sqlite.sqlite3.open(file.path);
        testDatabaseCipher.apply(database, createSlotIfMissing: true);
        database.execute('CREATE TABLE intermediate_only (value TEXT);');
        database.userVersion = schemaVersion;
        database.close();

        final receipt = await DatabaseInstallationGate.ensureReady(
          appDataDirectory: directory,
          cipher: testDatabaseCipher,
          retireAttachmentStaging: () async {},
        );

        final after = sqlite.sqlite3.open(
          file.path,
          mode: sqlite.OpenMode.readOnly,
        );
        try {
          testDatabaseCipher.apply(after, createSlotIfMissing: false);
          expect(after.userVersion, AppDatabase.currentSchemaVersion);
          expect(
            after.select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name=?;",
              ['intermediate_only'],
            ),
            isEmpty,
          );
        } finally {
          after.close();
        }
        expect(
          ChatDatabaseRepository.inspectInstalledDatabase(
            file,
            cipher: testDatabaseCipher,
          ).databaseId,
          receipt.databaseId,
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'obsolete schema hard-cut discards unreadable receipts before rebuild',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kelivo_obsolete_schema_bad_receipts_',
      );
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final file = File(p.join(directory.path, AppDatabase.databaseFileName));
      final database = sqlite.sqlite3.open(file.path);
      testDatabaseCipher.apply(database, createSlotIfMissing: true);
      database.execute('CREATE TABLE obsolete_only (value TEXT);');
      database.userVersion = AppDatabase.currentSchemaVersion - 1;
      database.close();
      final brokenReceipt = File(
        p.join(directory.path, 'database_installation_receipt_broken.json'),
      );
      final oversizedReceipt = File(
        p.join(directory.path, 'database_installation_receipt_oversized.json'),
      );
      await brokenReceipt.writeAsString('{broken', flush: true);
      await oversizedReceipt.writeAsString(
        List<String>.filled(4097, 'x').join(),
        flush: true,
      );

      final receipt = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: directory,
        cipher: testDatabaseCipher,
        retireAttachmentStaging: () async {},
      );

      expect(await brokenReceipt.exists(), isFalse);
      expect(await oversizedReceipt.exists(), isFalse);
      final installed = ChatDatabaseRepository.inspectInstalledDatabase(
        file,
        cipher: testDatabaseCipher,
      );
      expect(installed.schemaVersion, AppDatabase.currentSchemaVersion);
      expect(installed.databaseId, receipt.databaseId);
    },
  );
}
