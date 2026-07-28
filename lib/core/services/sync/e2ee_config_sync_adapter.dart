import 'dart:typed_data';

import '../../database/chat_database_repository.dart';
import 'config_sync_keys.dart';
import 'e2ee_account_record_state.dart';
import 'e2ee_sync_outbox.dart';
import 'e2ee_sync_payload_codec.dart';
import 'e2ee_sync_pull_types.dart';
import 'sync_codec.dart';

typedef E2eeConfigSyncClock = DateTime Function();

/// 配置只在 SQLCipher Vault 与认证密文 payload 之间转换，避免提前形成第二份配置真相。
final class E2eeConfigSyncAdapter {
  factory E2eeConfigSyncAdapter({
    required E2eeConfigVaultCommands commands,
    E2eeConfigSyncClock now = _utcNow,
  }) => E2eeConfigSyncAdapter._(commands, now);

  E2eeConfigSyncAdapter._(this._commands, this._now);

  final E2eeConfigVaultCommands _commands;
  final E2eeConfigSyncClock _now;

  Future<E2eeSyncEntitySnapshot> readSnapshot(SyncEntityKey entityKey) async {
    ConfigSyncKeys.validate(entityKey);
    final entry = await _commands.read(entityKey);
    if (entry == null) return const E2eeSyncTombstoneSnapshot();
    E2eeSyncPayloadCodec.decode(entityKey: entityKey, bytes: entry.payload);
    return E2eeSyncValueSnapshot.copyFrom(entry.payload);
  }

  /// 该回调必须由 E2eeSyncPullCommands 放入 ledger、Vault 与 checkpoint 的同一事务。
  Future<void> applyTransactional(
    List<E2eeSyncPulledChange> applicableChanges,
  ) async {
    if (applicableChanges.isEmpty) return;
    final ordered = <_IndexedConfigChange>[
      for (var index = 0; index < applicableChanges.length; index++)
        _IndexedConfigChange(index: index, change: applicableChanges[index]),
    ];
    for (final entry in ordered) {
      _validateChange(entry.change);
    }
    ordered.sort(_compareConfigChanges);

    final encodedByIndex = <int, Uint8List>{};
    try {
      for (final entry in ordered) {
        final change = entry.change;
        if (change is E2eeSyncPulledValueChange) {
          encodedByIndex[entry.index] = E2eeSyncPayloadCodec.encode(
            entityKey: change.state.entityKey,
            payload: change.payload,
          );
        }
      }
      for (final entry in ordered) {
        final change = entry.change;
        switch (change) {
          case E2eeSyncPulledValueChange():
            final encoded = encodedByIndex[entry.index];
            if (encoded == null) {
              throw StateError('sync_config_encoded_payload_missing');
            }
            await _commands.put(
              key: change.state.entityKey,
              payload: encoded,
              updatedAt: _storageTime(_now()),
            );
          case E2eeSyncPulledTombstoneChange():
            await _commands.delete(change.state.entityKey);
        }
      }
    } finally {
      for (final encoded in encodedByIndex.values) {
        encoded.fillRange(0, encoded.length, 0);
      }
    }
  }

  void _validateChange(E2eeSyncPulledChange change) {
    ConfigSyncKeys.validate(change.state.entityKey);
    final kindMatches = switch (change) {
      E2eeSyncPulledValueChange() =>
        change.state.kind == E2eeAccountRecordStateKind.value,
      E2eeSyncPulledTombstoneChange() =>
        change.state.kind == E2eeAccountRecordStateKind.tombstone,
    };
    if (!kindMatches) throw const FormatException('同步变更类型与认证状态不一致');
  }
}

final class _IndexedConfigChange {
  const _IndexedConfigChange({required this.index, required this.change});

  final int index;
  final E2eeSyncPulledChange change;
}

int _compareConfigChanges(
  _IndexedConfigChange left,
  _IndexedConfigChange right,
) {
  var compared = _configChangePriority(
    left.change,
  ).compareTo(_configChangePriority(right.change));
  if (compared != 0) return compared;
  compared = left.change.untrustedServerMetadata.changeSeq.compareTo(
    right.change.untrustedServerMetadata.changeSeq,
  );
  return compared != 0 ? compared : left.index.compareTo(right.index);
}

int _configChangePriority(E2eeSyncPulledChange change) {
  final dependencyRank = switch (change.state.entityKey.entityType) {
    ConfigSyncKeys.providerType ||
    ConfigSyncKeys.searchServiceType ||
    ConfigSyncKeys.networkTtsType ||
    ConfigSyncKeys.mcpServerType => 0,
    ConfigSyncKeys.assistantType ||
    ConfigSyncKeys.worldBookType ||
    ConfigSyncKeys.instructionInjectionType => 1,
    ConfigSyncKeys.memoryType || ConfigSyncKeys.quickPhraseType => 2,
    ConfigSyncKeys.preferenceType => 3,
    _ => throw StateError('sync_config_entity_type_unreachable'),
  };
  return switch (change) {
    E2eeSyncPulledValueChange() => dependencyRank,
    E2eeSyncPulledTombstoneChange() => 7 - dependencyRank,
  };
}

DateTime _storageTime(DateTime value) {
  final utc = value.toUtc();
  if (utc.microsecondsSinceEpoch < 0) {
    throw const FormatException('配置 Vault 更新时间必须为非负 UTC 时间');
  }
  return utc;
}

DateTime _utcNow() => DateTime.now().toUtc();
