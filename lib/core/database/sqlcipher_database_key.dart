import 'dart:convert';
import 'dart:ffi' as ffi;
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

  static Uint8List _deriveIdentifier(String domain, String workspaceKey) {
    final digest = sha256.convert(utf8.encode('$domain\u0000$workspaceKey'));
    return Uint8List.fromList(digest.bytes.take(16).toList(growable: false));
  }
}
