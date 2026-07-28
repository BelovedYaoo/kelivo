part of 'chat_database_repository.dart';

// 为最长合法实体键、状态头、双 parent digest 和记录信封预留认证开销。
const e2eeConfigVaultMaxPayloadBytes = 1000000;

final class E2eeConfigVaultEntry {
  E2eeConfigVaultEntry._({
    required this.key,
    required Uint8List payload,
    required DateTime updatedAt,
  }) : payload = Uint8List.fromList(payload).asUnmodifiableView(),
       updatedAt = updatedAt.toUtc();

  final SyncEntityKey key;
  final Uint8List payload;
  final DateTime updatedAt;
}

final class E2eeConfigVaultCommands {
  E2eeConfigVaultCommands._(this._database);

  final AppDatabase _database;

  Future<E2eeConfigVaultEntry?> read(SyncEntityKey key) async {
    ConfigSyncKeys.validate(key);
    final row =
        await (_database.select(_database.e2eeConfigEntryRows)..where(
              (table) =>
                  table.entityType.equals(key.entityType) &
                  table.entityId.equals(key.entityId),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    return _entryFromRow(row);
  }

  Future<List<E2eeConfigVaultEntry>> readByType(String entityType) async {
    if (!ConfigSyncKeys.entityTypes.contains(entityType)) {
      throw const FormatException('配置同步实体类型无效');
    }
    final rows =
        await (_database.select(_database.e2eeConfigEntryRows)
              ..where((table) => table.entityType.equals(entityType))
              ..orderBy(<OrderClauseGenerator<$E2eeConfigEntryRowsTable>>[
                (table) => OrderingTerm.asc(table.entityId),
              ]))
            .get();
    return List<E2eeConfigVaultEntry>.unmodifiable(rows.map(_entryFromRow));
  }

  Future<void> put({
    required SyncEntityKey key,
    required Uint8List payload,
    required DateTime updatedAt,
  }) async {
    ConfigSyncKeys.validate(key);
    if (payload.isEmpty || payload.length > e2eeConfigVaultMaxPayloadBytes) {
      throw const FormatException('配置 Vault payload 长度无效');
    }
    if (!updatedAt.isUtc || updatedAt.microsecondsSinceEpoch < 0) {
      throw const FormatException('配置 Vault 更新时间必须为非负 UTC 时间');
    }

    final ownedPayload = Uint8List.fromList(payload);
    try {
      await _database
          .into(_database.e2eeConfigEntryRows)
          .insertOnConflictUpdate(
            E2eeConfigEntryRowsCompanion.insert(
              entityType: key.entityType,
              entityId: key.entityId,
              payload: ownedPayload,
              updatedAt: updatedAt,
            ),
          );
    } finally {
      ownedPayload.fillRange(0, ownedPayload.length, 0);
    }
  }

  Future<bool> delete(SyncEntityKey key) async {
    ConfigSyncKeys.validate(key);
    final deleted =
        await (_database.delete(_database.e2eeConfigEntryRows)..where(
              (table) =>
                  table.entityType.equals(key.entityType) &
                  table.entityId.equals(key.entityId),
            ))
            .go();
    return deleted == 1;
  }

  E2eeConfigVaultEntry _entryFromRow(E2eeConfigEntryRow row) {
    try {
      return E2eeConfigVaultEntry._(
        key: SyncEntityKey(entityType: row.entityType, entityId: row.entityId),
        payload: row.payload,
        updatedAt: row.updatedAt,
      );
    } finally {
      row.payload.fillRange(0, row.payload.length, 0);
    }
  }
}
