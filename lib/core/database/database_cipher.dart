import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sqlite;

abstract interface class DatabaseCipher {
  void apply(sqlite.Database database, {required bool createSlotIfMissing});

  void attachExisting(
    sqlite.Database database, {
    required File databaseFile,
    required String databaseName,
  });
}
