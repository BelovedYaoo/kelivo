import 'dart:io';

import 'package:Kelivo/core/database/database_cipher.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

final class TestDatabaseCipher implements DatabaseCipher {
  const TestDatabaseCipher({
    this.rawKeyHex =
        '8f6a44c387d133ea73e888235aaa508190318c771dce8f53d38716dd970e293a',
  });

  final String rawKeyHex;

  @override
  void apply(sqlite.Database database, {required bool createSlotIfMissing}) {
    _requireKey();
    // 固定测试密钥只验证数据库边界；产品密钥禁止经过 Dart 字符串或缓冲区。
    database.execute('PRAGMA key = "x\'$rawKeyHex\'";');
    final versionRows = database.select('PRAGMA cipher_version;');
    if (versionRows.length != 1 ||
        versionRows.single.values.single.toString().trim().isEmpty) {
      throw StateError('sqlcipher_unavailable');
    }
    database.select('SELECT count(*) FROM sqlite_master;');
  }

  @override
  void attachExisting(
    sqlite.Database database, {
    required File databaseFile,
    required String databaseName,
  }) {
    _requireKey();
    if (!databaseFile.existsSync()) {
      throw StateError('database_cipher_attach_source_missing');
    }
    if (!RegExp(r'^[a-z][a-z0-9_]{0,31}$').hasMatch(databaseName) ||
        databaseName == 'main' ||
        databaseName == 'temp') {
      throw StateError('database_cipher_attach_name');
    }
    database.execute(
      'ATTACH DATABASE ? AS "$databaseName" KEY "x\'$rawKeyHex\'";',
      [databaseFile.absolute.path],
    );
    database.select('SELECT count(*) FROM "$databaseName".sqlite_master;');
  }

  void _requireKey() {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(rawKeyHex)) {
      throw StateError('test_database_cipher_key');
    }
  }
}

const testDatabaseCipher = TestDatabaseCipher();
