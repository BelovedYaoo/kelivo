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
    'installation gate rejects every unpublished SQLite schema without mutation',
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

        await expectLater(
          DatabaseInstallationGate.ensureReady(
            appDataDirectory: directory,
            cipher: testDatabaseCipher,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'database_schema_version',
            ),
          ),
        );

        final after = sqlite.sqlite3.open(
          file.path,
          mode: sqlite.OpenMode.readOnly,
        );
        try {
          testDatabaseCipher.apply(after, createSlotIfMissing: false);
          expect(after.userVersion, schemaVersion);
          expect(
            after.select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name=?;",
              ['intermediate_only'],
            ),
            hasLength(1),
          );
        } finally {
          after.close();
        }
      }
    },
  );
}
