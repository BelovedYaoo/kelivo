import 'cloud_sync_store.dart';
import 'cloud_sync_types.dart';
import 'sync_codec.dart';
import 'sync_write_journal.dart';

final class CloudSyncMutationPlanner {
  CloudSyncMutationPlanner(
    this._store, {
    required List<SyncEntityAdapter> adapters,
  }) {
    for (final adapter in adapters) {
      for (final entityType in adapter.entityTypes) {
        CloudSyncEntityType.parse(entityType);
        if (_adapterByType.containsKey(entityType)) {
          throw ArgumentError('同步实体类型存在重复适配器：$entityType');
        }
        _adapterByType[entityType] = adapter;
      }
    }
  }

  final CloudSyncStore _store;
  final Map<String, SyncEntityAdapter> _adapterByType =
      <String, SyncEntityAdapter>{};

  Future<SyncWriteDisposition> captureLocalIntent(
    CloudSyncAccountSession session,
    SyncWriteIntent intent,
  ) async {
    final key = SyncEntityKey(
      entityType: intent.entityType.wireName,
      entityId: intent.entityId,
    );
    final dispositions = await captureLocalIntents(session, <SyncWriteIntent>[
      intent,
    ]);
    return dispositions[key]!;
  }

  Future<Map<SyncEntityKey, SyncWriteDisposition>> captureLocalIntents(
    CloudSyncAccountSession session,
    Iterable<SyncWriteIntent> intents,
  ) async {
    final dispositions = <SyncEntityKey, SyncWriteDisposition>{};
    final intentsByAdapter =
        <SyncEntityAdapter, Map<SyncEntityKey, SyncWriteIntent>>{};
    final seenKeys = <SyncEntityKey>{};
    for (final intent in intents) {
      final key = SyncEntityKey(
        entityType: intent.entityType.wireName,
        entityId: intent.entityId,
      );
      if (!seenKeys.add(key)) {
        throw StateError('批量写前 intent 的实体身份重复：${key.storageKey}');
      }
      if (intent.accountScope != session.accountScope ||
          _hasPendingOutbox(session, key)) {
        dispositions[key] = SyncWriteDisposition.deferred;
        continue;
      }
      final adapter = _requiredAdapter(key.entityType);
      (intentsByAdapter[adapter] ??= <SyncEntityKey, SyncWriteIntent>{})[key] =
          intent;
    }

    for (final adapterEntry in intentsByAdapter.entries) {
      final requested = adapterEntry.value.keys.toSet();
      final locals = await adapterEntry.key.exportLocalEntitiesForKeys(
        requested,
      );
      for (final localEntry in locals.entries) {
        if (!requested.contains(localEntry.key) ||
            localEntry.value.key != localEntry.key) {
          throw StateError('适配器批量导出了未请求的实体：${localEntry.key.storageKey}');
        }
      }
      for (final intentEntry in adapterEntry.value.entries) {
        dispositions[intentEntry.key] = await planLocalEntity(
          session,
          intentEntry.key,
          locals[intentEntry.key],
          mutationId: intentEntry.value.intentId,
        );
      }
    }
    return Map<SyncEntityKey, SyncWriteDisposition>.unmodifiable(dispositions);
  }

  Future<SyncWriteDisposition> planLocalEntity(
    CloudSyncAccountSession session,
    SyncEntityKey key,
    LocalSyncEntity? local, {
    required String mutationId,
  }) async {
    final entityType = CloudSyncEntityType.parse(key.entityType);
    if (local != null && local.key != key) {
      throw StateError('定向导出的实体身份与请求不一致：${key.storageKey}');
    }
    if (_hasPendingOutbox(session, key)) {
      return SyncWriteDisposition.deferred;
    }

    final shadow = _store.shadow(
      session,
      entityType: entityType,
      entityId: key.entityId,
    );
    return _planLocalEntityAgainstShadow(
      session,
      key,
      local,
      entityType: entityType,
      shadow: shadow,
      mutationId: mutationId,
    );
  }

  Future<SyncWriteDisposition> planLocalEntityAgainstBaseline(
    CloudSyncAccountSession session,
    SyncEntityKey key,
    LocalSyncEntity? local, {
    required CloudSyncShadow baseline,
    required String mutationId,
  }) async {
    final entityType = CloudSyncEntityType.parse(key.entityType);
    if (baseline.entityType != entityType ||
        baseline.entityId != key.entityId) {
      throw StateError('显式同步基线与请求实体不一致：${key.storageKey}');
    }
    if (local != null && local.key != key) {
      throw StateError('定向导出的实体身份与请求不一致：${key.storageKey}');
    }
    return _planLocalEntityAgainstShadow(
      session,
      key,
      local,
      entityType: entityType,
      shadow: baseline,
      mutationId: mutationId,
    );
  }

  Future<SyncWriteDisposition> _planLocalEntityAgainstShadow(
    CloudSyncAccountSession session,
    SyncEntityKey key,
    LocalSyncEntity? local, {
    required CloudSyncEntityType entityType,
    required CloudSyncShadow? shadow,
    required String mutationId,
  }) async {
    if (_hasPendingOutbox(session, key)) {
      return SyncWriteDisposition.deferred;
    }
    final mutation = _buildMutation(
      key: key,
      entityType: entityType,
      local: local,
      shadow: shadow,
      mutationId: shadow?.deleted == true ? '$mutationId:restore' : mutationId,
    );
    if (mutation != null) {
      await _store.enqueueOutbox(session, mutation, merge: false);
    }
    return _requiresFollowUp(local, shadow)
        ? SyncWriteDisposition.deferred
        : SyncWriteDisposition.completed;
  }

  bool _hasPendingOutbox(CloudSyncAccountSession session, SyncEntityKey key) {
    return _store
        .outboxForEntity(
          session,
          entityType: CloudSyncEntityType.parse(key.entityType),
          entityId: key.entityId,
        )
        .isNotEmpty;
  }

  CloudSyncOutboxMutation? _buildMutation({
    required SyncEntityKey key,
    required CloudSyncEntityType entityType,
    required LocalSyncEntity? local,
    required CloudSyncShadow? shadow,
    required String mutationId,
  }) {
    if (local != null && shadow == null) {
      return CloudSyncOutboxMutation.create(
        mutationId: mutationId,
        entityType: entityType,
        entityId: local.entityId,
        parentId: local.parentId,
        schemaVersion: local.schemaVersion,
        payload: local.payload,
      );
    }
    if (local == null && shadow != null && !shadow.deleted) {
      return CloudSyncOutboxMutation.delete(
        mutationId: mutationId,
        entityType: entityType,
        entityId: key.entityId,
        baseRevision: shadow.revision,
      );
    }
    if (local == null || shadow == null) return null;
    if (local.parentId != shadow.parentId) {
      throw StateError('同步实体父级不可变：${key.storageKey}');
    }
    final previousPayload = shadow.payload;
    if (previousPayload == null) {
      throw StateError('有效 shadow 缺少 payload：${key.storageKey}');
    }
    if (local.schemaVersion < shadow.schemaVersion) {
      throw StateError('本地 schemaVersion 不能低于已确认版本：${key.storageKey}');
    }
    if (shadow.deleted) {
      return CloudSyncOutboxMutation.restore(
        mutationId: mutationId,
        entityType: entityType,
        entityId: key.entityId,
        baseRevision: shadow.revision,
      );
    }
    final patch = _buildTopLevelPatch(previousPayload, local.payload);
    if (patch.isEmpty && local.schemaVersion == shadow.schemaVersion) {
      return null;
    }
    return CloudSyncOutboxMutation.update(
      mutationId: mutationId,
      entityType: entityType,
      entityId: key.entityId,
      baseRevision: shadow.revision,
      schemaVersion: local.schemaVersion,
      patch: patch,
    );
  }

  bool _requiresFollowUp(LocalSyncEntity? local, CloudSyncShadow? shadow) {
    if (local == null || shadow == null || !shadow.deleted) return false;
    final payload = shadow.payload;
    return payload == null ||
        local.schemaVersion != shadow.schemaVersion ||
        canonicalSyncJson(local.payload) != canonicalSyncJson(payload);
  }

  SyncEntityAdapter _requiredAdapter(String entityType) {
    final adapter = _adapterByType[entityType];
    if (adapter == null) {
      throw StateError('找不到同步实体适配器：$entityType');
    }
    return adapter;
  }
}

List<CloudSyncPatch> _buildTopLevelPatch(
  CloudSyncJsonMap previous,
  CloudSyncJsonMap current,
) {
  final keys = <String>{...previous.keys, ...current.keys}.toList()..sort();
  final result = <CloudSyncPatch>[];
  for (final key in keys) {
    final path = '/${_escapeJsonPointerToken(key)}';
    if (!current.containsKey(key)) {
      result.add(CloudSyncPatch.remove(path));
      continue;
    }
    if (!previous.containsKey(key)) {
      result.add(CloudSyncPatch.add(path, current[key]));
      continue;
    }
    if (!_sameJsonValue(previous[key], current[key])) {
      result.add(CloudSyncPatch.replace(path, current[key]));
    }
  }
  if (result.length > 100) {
    throw const FormatException('单个同步实体一次变更超过 100 个字段');
  }
  return List<CloudSyncPatch>.unmodifiable(result);
}

bool _sameJsonValue(Object? left, Object? right) {
  return canonicalSyncJson(<String, Object?>{'value': left}) ==
      canonicalSyncJson(<String, Object?>{'value': right});
}

String _escapeJsonPointerToken(String value) {
  return value.replaceAll('~', '~0').replaceAll('/', '~1');
}
