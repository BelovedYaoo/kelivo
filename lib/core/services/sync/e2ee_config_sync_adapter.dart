import 'dart:typed_data';

import '../../database/chat_database_repository.dart';
import 'config_sync_keys.dart';
import 'e2ee_account_record_state.dart';
import 'e2ee_attachment_manifest.dart';
import 'e2ee_config_asset_types.dart';
import 'e2ee_sync_outbox.dart';
import 'e2ee_sync_payload_codec.dart';
import 'e2ee_sync_pull_types.dart';
import 'sync_codec.dart';

typedef E2eeConfigSyncClock = DateTime Function();

/// 配置只在 SQLCipher Vault 与认证密文 payload 之间转换，避免提前形成第二份配置真相。
final class E2eeConfigSyncAdapter {
  factory E2eeConfigSyncAdapter({
    required E2eeConfigVaultCommands commands,
    required E2eeConfigAssetCommands assetCommands,
    E2eeConfigSyncClock now = _utcNow,
  }) => E2eeConfigSyncAdapter._(commands, assetCommands, now);

  E2eeConfigSyncAdapter._(this._commands, this._assetCommands, this._now);

  final E2eeConfigVaultCommands _commands;
  final E2eeConfigAssetCommands _assetCommands;
  final E2eeConfigSyncClock _now;

  Future<E2eeSyncEntitySnapshot> readSnapshot(SyncEntityKey entityKey) async {
    ConfigSyncKeys.validate(entityKey);
    final entry = await _commands.read(entityKey);
    if (entry == null) return const E2eeSyncTombstoneSnapshot();
    final payload = Map<String, Object?>.from(
      E2eeSyncPayloadCodec.decode(entityKey: entityKey, bytes: entry.payload),
    );
    if (entityKey.entityType == ConfigSyncKeys.assistantType) {
      await _overlayAssistantAssets(entityKey, payload);
      final encoded = E2eeSyncPayloadCodec.encode(
        entityKey: entityKey,
        payload: payload,
      );
      try {
        return E2eeSyncValueSnapshot.copyFrom(encoded);
      } finally {
        encoded.fillRange(0, encoded.length, 0);
      }
    }
    return E2eeSyncValueSnapshot.copyFrom(entry.payload);
  }

  Future<void> _overlayAssistantAssets(
    SyncEntityKey entityKey,
    Map<String, Object?> payload,
  ) async {
    for (final entry in const <(String, String, E2eeConfigAssetSlot)>[
      ('avatar', 'avatarAsset', E2eeConfigAssetSlot.avatar),
      ('background', 'backgroundAsset', E2eeConfigAssetSlot.background),
    ]) {
      final record = await _assetCommands.read(
        E2eeConfigAssetKey(entityKey: entityKey, slot: entry.$3),
      );
      final payloadIdentity = payload[entry.$2];
      if (record == null) {
        if (payloadIdentity != null) {
          throw StateError('E2EE 配置资产 payload 缺少本地受管引用');
        }
        continue;
      }
      if (payload[entry.$1] != null) {
        throw StateError('E2EE 配置资产不得与可移植值同时存在');
      }
      final identity = record.remoteIdentity;
      if (identity == null) {
        throw const E2eeSyncOutboxBlocked(
          E2eeSyncOutboxBlockReason.attachmentPending,
        );
      }
      if (payloadIdentity != null) {
        final expected = E2eeConfigAssetRemoteIdentity.fromPayload(
          payloadIdentity,
          expectedKind: E2eeAttachmentKind.image,
        );
        if (!_sameConfigAssetIdentity(identity, expected)) {
          throw StateError('E2EE 配置资产 payload 与本地受管引用不一致');
        }
      }
      payload[entry.$2] = identity.toPayload();
    }
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

bool _sameConfigAssetIdentity(
  E2eeConfigAssetRemoteIdentity left,
  E2eeConfigAssetRemoteIdentity right,
) =>
    left.attachmentId == right.attachmentId &&
    left.uploadId == right.uploadId &&
    left.chunkKeyEpoch == right.chunkKeyEpoch &&
    left.manifestKeyEpoch == right.manifestKeyEpoch &&
    left.manifestRevision == right.manifestRevision &&
    left.kind == right.kind;

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
