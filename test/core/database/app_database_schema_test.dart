import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/app_database.dart';

import 'generated_schema/schema.dart';
import 'test_database_cipher.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('frozen schema includes and matches current schema 12', () async {
    expect(GeneratedHelper.versions, [AppDatabase.currentSchemaVersion]);
    final directory = await Directory.systemTemp.createTemp(
      'kelivo_schema_current_',
    );
    final database = AppDatabase.open(
      file: File('${directory.path}/schema.sqlite'),
      cipher: testDatabaseCipher,
    );
    try {
      await database.customSelect('SELECT 1;').getSingle();
      await verifier.migrateAndValidate(
        database,
        AppDatabase.currentSchemaVersion,
        options: const ValidationOptions(validateDropped: true),
      );
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });

  test('unpublished schema is rejected instead of migrated', () async {
    final directory = await Directory.systemTemp.createTemp(
      'kelivo_schema_unpublished_',
    );
    final file = File('${directory.path}/schema.sqlite');
    final rawDatabase = sqlite.sqlite3.open(file.path);
    testDatabaseCipher.apply(rawDatabase, createSlotIfMissing: true);
    rawDatabase.userVersion = AppDatabase.currentSchemaVersion - 1;
    rawDatabase.close();
    final database = AppDatabase.open(file: file, cipher: testDatabaseCipher);
    try {
      await expectLater(
        database.customSelect('SELECT 1;').getSingle(),
        throwsA(
          isA<DriftRemoteException>().having(
            (error) => error.remoteCause,
            'remoteCause',
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'database_schema_version',
            ),
          ),
        ),
      );
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });
}
