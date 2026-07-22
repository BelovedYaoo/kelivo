import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

const _sqliteAssetId = 'package:sqlite3/src/ffi/libsqlite3.g.dart';

@ffi.Native<KelivoSqlCipherKeyNative>(
  symbol: 'sqlite3_key',
  assetId: _sqliteAssetId,
)
external int _sqlite3Key(
  ffi.Pointer<ffi.Void> database,
  ffi.Pointer<ffi.Void> key,
  int keyLength,
);

@ffi.Native<KelivoSqlitePrepareNative>(
  symbol: 'sqlite3_prepare_v2',
  assetId: _sqliteAssetId,
)
external int _sqlite3PrepareV2(
  ffi.Pointer<ffi.Void> database,
  ffi.Pointer<ffi.Char> sql,
  int sqlLength,
  ffi.Pointer<ffi.Pointer<ffi.Void>> outStatement,
  ffi.Pointer<ffi.Pointer<ffi.Char>> sqlTail,
);

@ffi.Native<KelivoSqliteBindTextNative>(
  symbol: 'sqlite3_bind_text',
  assetId: _sqliteAssetId,
)
external int _sqlite3BindText(
  ffi.Pointer<ffi.Void> statement,
  int index,
  ffi.Pointer<ffi.Char> value,
  int valueLength,
  ffi.Pointer<ffi.NativeFunction<KelivoSqliteDestructorNative>> destructor,
);

@ffi.Native<KelivoSqliteBindBlobNative>(
  symbol: 'sqlite3_bind_blob',
  assetId: _sqliteAssetId,
)
external int _sqlite3BindBlob(
  ffi.Pointer<ffi.Void> statement,
  int index,
  ffi.Pointer<ffi.Void> value,
  int valueLength,
  ffi.Pointer<ffi.NativeFunction<KelivoSqliteDestructorNative>> destructor,
);

@ffi.Native<KelivoSqliteStepNative>(
  symbol: 'sqlite3_step',
  assetId: _sqliteAssetId,
)
external int _sqlite3Step(ffi.Pointer<ffi.Void> statement);

@ffi.Native<KelivoSqliteFinalizeNative>(
  symbol: 'sqlite3_finalize',
  assetId: _sqliteAssetId,
)
external int _sqlite3Finalize(ffi.Pointer<ffi.Void> statement);

final class SqlCipherDatabaseKey {
  factory SqlCipherDatabaseKey.forWorkspace(String workspaceKey) {
    if (workspaceKey != 'local' &&
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(workspaceKey)) {
      throw const FormatException('database_cipher_workspace');
    }
    return SqlCipherDatabaseKey._(
      slotId: _deriveIdentifier(_slotDomain, workspaceKey),
      databaseId: _deriveIdentifier(_databaseDomain, workspaceKey),
    );
  }

  SqlCipherDatabaseKey._({required this._slotId, required this._databaseId});

  static const _slotDomain = 'kelivo.database.slot.v1';
  static const _databaseDomain = 'kelivo.database.id.v1';
  static const _epoch = 1;
  static final ffi.Pointer<ffi.NativeFunction<KelivoSqlCipherKeyNative>>
  _keyCallback = ffi.Native.addressOf(_sqlite3Key);
  static final ffi.Pointer<ffi.NativeFunction<KelivoSqlitePrepareNative>>
  _prepareCallback = ffi.Native.addressOf(_sqlite3PrepareV2);
  static final ffi.Pointer<ffi.NativeFunction<KelivoSqliteBindTextNative>>
  _bindTextCallback = ffi.Native.addressOf(_sqlite3BindText);
  static final ffi.Pointer<ffi.NativeFunction<KelivoSqliteBindBlobNative>>
  _bindBlobCallback = ffi.Native.addressOf(_sqlite3BindBlob);
  static final ffi.Pointer<ffi.NativeFunction<KelivoSqliteStepNative>>
  _stepCallback = ffi.Native.addressOf(_sqlite3Step);
  static final ffi.Pointer<ffi.NativeFunction<KelivoSqliteFinalizeNative>>
  _finalizeCallback = ffi.Native.addressOf(_sqlite3Finalize);

  final Uint8List _slotId;
  final Uint8List _databaseId;
  final KelivoSecureCore _secureCore = const KelivoSecureCore();

  void apply(sqlite.Database database, {required bool createSlotIfMissing}) {
    _secureCore.applySqlCipherKeySync(
      slotId: _slotId,
      databaseId: _databaseId,
      epoch: _epoch,
      createSlotIfMissing: createSlotIfMissing,
      database: database.handle.cast<ffi.Void>(),
      keyCallback: _keyCallback,
    );
    final versionRows = database.select('PRAGMA cipher_version;');
    if (versionRows.length != 1 ||
        versionRows.single.values.single.toString().trim().isEmpty) {
      throw StateError('sqlcipher_unavailable');
    }
    database.select('SELECT count(*) FROM sqlite_master;');
  }

  void attachExisting(
    sqlite.Database database, {
    required File databaseFile,
    required String databaseName,
  }) {
    // SQLite 会为缺失路径创建空库，恢复源不存在时必须保持磁盘不变。
    final absoluteFile = databaseFile.absolute;
    if (!absoluteFile.existsSync()) {
      throw StateError('database_cipher_attach_source_missing');
    }
    _secureCore.attachSqlCipherDatabaseSync(
      slotId: _slotId,
      databaseId: _databaseId,
      epoch: _epoch,
      databasePath: absoluteFile.path,
      databaseName: databaseName,
      database: database.handle.cast<ffi.Void>(),
      prepareCallback: _prepareCallback,
      bindTextCallback: _bindTextCallback,
      bindBlobCallback: _bindBlobCallback,
      stepCallback: _stepCallback,
      finalizeCallback: _finalizeCallback,
    );
    database.select('SELECT count(*) FROM "$databaseName".sqlite_master;');
  }

  static Uint8List _deriveIdentifier(String domain, String workspaceKey) {
    final digest = sha256.convert(utf8.encode('$domain\u0000$workspaceKey'));
    return Uint8List.fromList(digest.bytes.take(16).toList(growable: false));
  }
}
