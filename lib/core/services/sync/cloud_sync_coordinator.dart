import 'dart:async';

import 'package:uuid/uuid.dart';

import 'cloud_sync_client.dart';
import 'cloud_sync_store.dart';
import 'cloud_sync_types.dart';
import 'sync_codec.dart';

final class CloudSyncRunSummary {
  const CloudSyncRunSummary({
    required this.uploadedCount,
    required this.downloadedCount,
    required this.conflictCount,
    required this.completedAt,
  });

  final int uploadedCount;
  final int downloadedCount;
  final int conflictCount;
  final DateTime completedAt;
}

final class CloudSyncCoordinator {
  CloudSyncCoordinator(
    this._session,
    this._client,
    this._store, {
    required List<SyncEntityAdapter> adapters,
    String Function()? createMutationId,
  }) : _adapters = List<SyncEntityAdapter>.unmodifiable(adapters),
       _createMutationId = createMutationId ?? const Uuid().v4 {
    for (final adapter in _adapters) {
      for (final entityType in adapter.entityTypes) {
        final previous = _adapterByType[entityType];
        if (previous != null) {
          throw ArgumentError('同步实体类型存在重复适配器：$entityType');
        }
        CloudSyncEntityType.parse(entityType);
        _adapterByType[entityType] = adapter;
      }
    }
  }

  static const int _maxPushBatchesPerRun = 10;
  static const int _pageSize = 100;

  final CloudSyncAccountSession _session;
  final CloudSyncClient _client;
  final CloudSyncStore _store;
  final List<SyncEntityAdapter> _adapters;
  final String Function() _createMutationId;
  final Map<String, SyncEntityAdapter> _adapterByType =
      <String, SyncEntityAdapter>{};
  Future<CloudSyncRunSummary>? _activeRun;

  Future<CloudSyncRunSummary> synchronize() {
    final active = _activeRun;
    if (active != null) return active;

    final run = _synchronize();
    _activeRun = run;
    return run.whenComplete(() {
      if (identical(_activeRun, run)) {
        _activeRun = null;
      }
    });
  }

  Future<CloudSyncRunSummary> _synchronize() async {
    var uploadedCount = 0;
    var downloadedCount = 0;
    var conflictCount = 0;

    var cursorState = _store.cursorState(_session);
    if (cursorState.pullCursor == null) {
      downloadedCount += await _pullSnapshot();
    } else {
      await _scanLocalChanges();
    }

    cursorState = _store.cursorState(_session);
    downloadedCount += await _pullChanges(cursorState.pullCursor);

    await _scanLocalChanges();
    final pushResult = await _pushPendingChanges();
    uploadedCount += pushResult.uploadedCount;
    conflictCount += pushResult.conflictCount;

    if (pushResult.requiresSnapshot) {
      await _store.clearSyncProgress(_session);
      downloadedCount += await _pullSnapshot();
    }

    final failure = pushResult.failure;
    if (failure != null) throw failure;

    await _scanLocalChanges();
    cursorState = _store.cursorState(_session);
    downloadedCount += await _pullChanges(cursorState.pullCursor);

    return CloudSyncRunSummary(
      uploadedCount: uploadedCount,
      downloadedCount: downloadedCount,
      conflictCount: conflictCount,
      completedAt: DateTime.now().toUtc(),
    );
  }

  Future<Map<SyncEntityKey, LocalSyncEntity>> _exportLocalEntities() async {
    final result = <SyncEntityKey, LocalSyncEntity>{};
    for (final adapter in _adapters) {
      final entities = await adapter.exportLocalEntities();
      for (final entity in entities) {
        if (!adapter.entityTypes.contains(entity.entityType)) {
          throw StateError('适配器导出了未声明的实体类型：${entity.entityType}');
        }
        final previous = result[entity.key];
        if (previous != null) {
          throw StateError('本地同步实体身份重复：${entity.key.storageKey}');
        }
        result[entity.key] = entity;
      }
    }
    return result;
  }

  Future<void> _scanLocalChanges() async {
    final localByKey = await _exportLocalEntities();
    final shadows = <SyncEntityKey, CloudSyncShadow>{
      for (final shadow in _store.shadows(_session))
        SyncEntityKey(
          entityType: shadow.entityType.wireName,
          entityId: shadow.entityId,
        ): shadow,
    };

    final keys = <SyncEntityKey>{...localByKey.keys, ...shadows.keys}.toList()
      ..sort((left, right) => left.storageKey.compareTo(right.storageKey));

    for (final key in keys) {
      final entityType = CloudSyncEntityType.parse(key.entityType);
      if (_store
          .outboxForEntity(
            _session,
            entityType: entityType,
            entityId: key.entityId,
          )
          .isNotEmpty) {
        continue;
      }

      final local = localByKey[key];
      final shadow = shadows[key];
      if (local != null && shadow == null) {
        await _store.enqueueOutbox(
          _session,
          CloudSyncOutboxMutation.create(
            mutationId: _createMutationId(),
            entityType: entityType,
            entityId: local.entityId,
            parentId: local.parentId,
            schemaVersion: local.schemaVersion,
            payload: local.payload,
          ),
        );
        continue;
      }
      if (local == null && shadow != null && !shadow.deleted) {
        await _store.enqueueOutbox(
          _session,
          CloudSyncOutboxMutation.delete(
            mutationId: _createMutationId(),
            entityType: entityType,
            entityId: key.entityId,
            baseRevision: shadow.revision,
          ),
        );
        continue;
      }
      if (local == null || shadow == null) continue;
      if (shadow.deleted) {
        await _store.enqueueOutbox(
          _session,
          CloudSyncOutboxMutation.restore(
            mutationId: _createMutationId(),
            entityType: entityType,
            entityId: key.entityId,
            baseRevision: shadow.revision,
          ),
        );
        continue;
      }
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
      final patch = _buildTopLevelPatch(previousPayload, local.payload);
      if (patch.isEmpty && local.schemaVersion == shadow.schemaVersion) {
        continue;
      }
      await _store.enqueueOutbox(
        _session,
        CloudSyncOutboxMutation.update(
          mutationId: _createMutationId(),
          entityType: entityType,
          entityId: key.entityId,
          baseRevision: shadow.revision,
          schemaVersion: local.schemaVersion,
          patch: patch,
        ),
      );
    }
  }

  Future<_PushOutcome> _pushPendingChanges() async {
    var uploadedCount = 0;
    var conflictCount = 0;
    var requiresSnapshot = false;
    CloudSyncException? failure;

    for (var batchIndex = 0; batchIndex < _maxPushBatchesPerRun; batchIndex++) {
      final pending = _store.pendingOutbox(_session, limit: 10);
      if (pending.isEmpty) break;
      final attempted = <CloudSyncOutboxMutation>[];
      for (final mutation in pending) {
        attempted.add(
          await _store.markOutboxAttempted(
            _session,
            mutationId: mutation.mutationId,
          ),
        );
      }

      List<CloudSyncMutationResult> results;
      try {
        results = await _client.push(attempted);
      } on CloudSyncException catch (error) {
        for (final mutation in attempted) {
          await _scheduleRetry(mutation, error.serverCode);
        }
        rethrow;
      }

      final resultById = <String, CloudSyncMutationResult>{
        for (final result in results) result.mutationId: result,
      };
      for (final mutation in attempted) {
        final result = resultById[mutation.mutationId];
        if (result == null) {
          await _scheduleRetry(mutation, 'SYNC_RESULT_MISSING');
          failure ??= const CloudSyncException(
            kind: CloudSyncFailureKind.invalidResponse,
            retryable: true,
            serverCode: 'SYNC_RESULT_MISSING',
          );
          continue;
        }
        switch (result.status) {
          case CloudSyncMutationStatus.applied:
            final revision = result.revision;
            final changeSeq = result.changeSeq;
            if (revision == null || changeSeq == null) {
              await _scheduleRetry(mutation, 'SYNC_RESULT_INVALID');
              failure ??= const CloudSyncException(
                kind: CloudSyncFailureKind.invalidResponse,
                retryable: true,
                serverCode: 'SYNC_RESULT_INVALID',
              );
              continue;
            }
            final confirmed = _confirmedState(mutation);
            await _store.acknowledgeOutbox(
              _session,
              mutationId: mutation.mutationId,
              revision: revision,
              lastChangeSeq: changeSeq,
              deleted: mutation.operation == CloudSyncMutationOperation.delete,
              parentId: confirmed.parentId,
              schemaVersion: confirmed.schemaVersion,
              payload: confirmed.payload,
            );
            uploadedCount++;
            continue;
          case CloudSyncMutationStatus.conflict:
            await _store.removeOutbox(_session, mutation.mutationId);
            conflictCount++;
            requiresSnapshot = true;
            continue;
          case CloudSyncMutationStatus.rejected:
            await _store.removeOutbox(_session, mutation.mutationId);
            failure ??= CloudSyncException(
              kind: CloudSyncFailureKind.validation,
              retryable: false,
              serverCode: result.errorCode ?? 'SYNC_MUTATION_REJECTED',
            );
            continue;
          case CloudSyncMutationStatus.retry:
            await _scheduleRetry(mutation, 'SYNC_MUTATION_RETRY');
            failure ??= const CloudSyncException(
              kind: CloudSyncFailureKind.server,
              retryable: true,
              serverCode: 'SYNC_MUTATION_RETRY',
            );
            continue;
        }
      }
      if (requiresSnapshot) break;
    }

    return _PushOutcome(
      uploadedCount: uploadedCount,
      conflictCount: conflictCount,
      requiresSnapshot: requiresSnapshot,
      failure: failure,
    );
  }

  Future<void> _scheduleRetry(
    CloudSyncOutboxMutation mutation,
    String? errorCode, {
    Duration minimumDelay = Duration.zero,
  }) {
    final exponent = mutation.attemptCount.clamp(1, 8).toInt();
    final automaticDelay = Duration(seconds: 1 << exponent);
    final delay = automaticDelay.compareTo(minimumDelay) > 0
        ? automaticDelay
        : minimumDelay;
    return _store.markOutboxRetry(
      _session,
      mutationId: mutation.mutationId,
      nextAttemptAt: DateTime.now().toUtc().add(delay),
      errorCode: errorCode,
    );
  }

  _ConfirmedState _confirmedState(CloudSyncOutboxMutation mutation) {
    final shadow = _store.shadow(
      _session,
      entityType: mutation.entityType,
      entityId: mutation.entityId,
    );
    return switch (mutation.operation) {
      CloudSyncMutationOperation.create => _ConfirmedState(
        parentId: mutation.parentId,
        schemaVersion: mutation.schemaVersion!,
        payload: mutation.payload!,
      ),
      CloudSyncMutationOperation.update => _ConfirmedState(
        parentId: shadow?.parentId,
        schemaVersion:
            mutation.schemaVersion ??
            shadow?.schemaVersion ??
            (throw StateError('更新确认缺少 schemaVersion')),
        payload: _applyTopLevelPatch(
          shadow?.payload ?? (throw StateError('更新确认缺少 shadow payload')),
          mutation.patch,
        ),
      ),
      CloudSyncMutationOperation.delete => _ConfirmedState(
        parentId: shadow?.parentId,
        schemaVersion:
            shadow?.schemaVersion ?? (throw StateError('删除确认缺少 schemaVersion')),
        payload: shadow?.payload,
      ),
      CloudSyncMutationOperation.restore => _ConfirmedState(
        parentId: shadow?.parentId,
        schemaVersion:
            shadow?.schemaVersion ?? (throw StateError('恢复确认缺少 schemaVersion')),
        payload: shadow?.payload,
      ),
    };
  }

  Future<int> _pullSnapshot() async {
    var appliedCount = 0;
    var state = _store.cursorState(_session);
    var snapshotCursor = state.snapshotCursor;
    var syncCursor = state.snapshotSyncCursor;

    if (snapshotCursor == null) {
      await _store.beginSnapshot(_session);
    }

    while (true) {
      final page = await _client.snapshot(
        snapshotCursor: snapshotCursor,
        limit: _pageSize,
      );
      appliedCount += await _applyRecords(page.records);
      await _store.markSnapshotRecordsSeen(_session, page.records);
      syncCursor = page.syncCursor ?? syncCursor;
      if (!page.hasMore) {
        final completedCursor = page.syncCursor ?? syncCursor;
        if (completedCursor == null) {
          throw const CloudSyncException(
            kind: CloudSyncFailureKind.invalidResponse,
            retryable: true,
            serverCode: 'SYNC_SNAPSHOT_CURSOR_MISSING',
          );
        }
        appliedCount += await _reconcileSnapshotAbsences();
        await _store.completeSnapshot(_session, syncCursor: completedCursor);
        await _store.finishSnapshot(_session);
        return appliedCount;
      }
      final nextCursor = page.nextSnapshotCursor;
      if (nextCursor == null) {
        throw const CloudSyncException(
          kind: CloudSyncFailureKind.invalidResponse,
          retryable: true,
          serverCode: 'SYNC_SNAPSHOT_PAGE_CURSOR_MISSING',
        );
      }
      await _store.saveSnapshotProgress(
        _session,
        snapshotCursor: nextCursor,
        syncCursor: syncCursor,
      );
      snapshotCursor = nextCursor;
      state = _store.cursorState(_session);
      syncCursor = state.snapshotSyncCursor ?? syncCursor;
    }
  }

  Future<int> _pullChanges(String? initialCursor) async {
    var cursor = initialCursor;
    var appliedCount = 0;
    while (true) {
      final page = await _client.pull(cursor: cursor, limit: _pageSize);
      // 网络等待期间产生的本地编辑必须先进入 outbox，避免被返回的远端页面覆盖。
      await _scanLocalChanges();
      if (page.resetRequired) {
        await _store.clearSyncProgress(_session);
        appliedCount += await _pullSnapshot();
        cursor = _store.cursorState(_session).pullCursor;
        continue;
      }
      appliedCount += await _applyChanges(page.changes);
      await _store.savePullCursor(_session, page.nextCursor);
      cursor = page.nextCursor;
      if (!page.hasMore) return appliedCount;
    }
  }

  Future<int> _reconcileSnapshotAbsences() async {
    var deletedCount = 0;
    for (final shadow in _store.shadows(_session)) {
      if (_store.wasSeenInSnapshot(
        _session,
        entityType: shadow.entityType,
        entityId: shadow.entityId,
      )) {
        continue;
      }

      final key = SyncEntityKey(
        entityType: shadow.entityType.wireName,
        entityId: shadow.entityId,
      );
      await _requiredAdapter(key.entityType).applyRemoteDelete(key);
      final outbox = _store.outboxForEntity(
        _session,
        entityType: shadow.entityType,
        entityId: shadow.entityId,
      );
      for (final mutation in outbox) {
        await _store.removeOutbox(_session, mutation.mutationId);
      }
      await _store.deleteShadow(
        _session,
        entityType: shadow.entityType,
        entityId: shadow.entityId,
      );
      deletedCount++;
    }
    return deletedCount;
  }

  Future<int> _applyRecords(List<CloudSyncRecord> records) {
    final changes = records
        .map(
          (record) => record.deletedAt == null
              ? CloudSyncChange.upsert(
                  changeSeq: record.lastChangeSeq,
                  record: record,
                )
              : CloudSyncChange.delete(
                  changeSeq: record.lastChangeSeq,
                  entityType: record.entityType,
                  entityId: record.entityId,
                  revision: record.revision,
                  deletedAt: record.deletedAt!,
                ),
        )
        .toList(growable: false);
    return _applyChanges(
      changes,
      snapshotRecords: records,
      authoritative: true,
    );
  }

  Future<int> _applyChanges(
    List<CloudSyncChange> changes, {
    List<CloudSyncRecord> snapshotRecords = const <CloudSyncRecord>[],
    bool authoritative = false,
  }) async {
    final latestByKey = <SyncEntityKey, CloudSyncChange>{};
    for (final change in changes) {
      latestByKey[SyncEntityKey(
            entityType: change.entityType.wireName,
            entityId: change.entityId,
          )] =
          change;
    }
    final snapshotByKey = <SyncEntityKey, CloudSyncRecord>{
      for (final record in snapshotRecords)
        SyncEntityKey(
          entityType: record.entityType.wireName,
          entityId: record.entityId,
        ): record,
    };
    final ordered = latestByKey.entries.toList()
      ..sort((left, right) {
        final leftAdapter = _requiredAdapter(left.key.entityType);
        final rightAdapter = _requiredAdapter(right.key.entityType);
        final byPriority = leftAdapter.applyPriority.compareTo(
          rightAdapter.applyPriority,
        );
        if (byPriority != 0) return byPriority;
        return left.value.changeSeq.compareTo(right.value.changeSeq);
      });
    var appliedCount = 0;

    for (final entry in ordered) {
      final key = entry.key;
      final change = entry.value;
      final adapter = _requiredAdapter(key.entityType);
      final previous = _store.shadow(
        _session,
        entityType: change.entityType,
        entityId: change.entityId,
      );
      if (!authoritative &&
          previous != null &&
          change.changeSeq <= previous.lastChangeSeq) {
        continue;
      }
      final pending = _store.outboxForEntity(
        _session,
        entityType: change.entityType,
        entityId: change.entityId,
      );
      final preserveLocal = !authoritative && pending.isNotEmpty;
      final record = change.record;
      if (change.operation == CloudSyncChangeOperation.upsert &&
          record != null &&
          record.deletedAt == null) {
        if (!preserveLocal) {
          await adapter.applyRemoteUpsert(
            RemoteSyncEntity(
              entityType: record.entityType.wireName,
              entityId: record.entityId,
              parentId: record.parentId,
              revision: record.revision,
              schemaVersion: record.schemaVersion,
              payload: record.payload,
              updatedAt: record.updatedAt,
            ),
          );
        }
        await _store.saveShadow(
          _session,
          CloudSyncShadow(
            entityType: record.entityType,
            entityId: record.entityId,
            parentId: record.parentId,
            revision: record.revision,
            schemaVersion: record.schemaVersion,
            lastChangeSeq: record.lastChangeSeq,
            deleted: false,
            payload: record.payload,
            updatedAt: record.updatedAt,
          ),
        );
        if (authoritative) {
          for (final mutation in pending) {
            await _store.removeOutbox(_session, mutation.mutationId);
          }
        }
        appliedCount++;
        continue;
      }

      if (!preserveLocal) {
        await adapter.applyRemoteDelete(key);
      }
      final snapshot = snapshotByKey[key];
      await _store.saveShadow(
        _session,
        CloudSyncShadow(
          entityType: change.entityType,
          entityId: change.entityId,
          parentId: snapshot?.parentId ?? previous?.parentId,
          revision: change.revision,
          schemaVersion:
              snapshot?.schemaVersion ?? previous?.schemaVersion ?? 1,
          lastChangeSeq: change.changeSeq,
          deleted: true,
          payload: snapshot?.payload ?? previous?.payload,
          updatedAt: change.deletedAt ?? DateTime.now(),
        ),
      );
      if (authoritative) {
        for (final mutation in pending) {
          await _store.removeOutbox(_session, mutation.mutationId);
        }
      }
      appliedCount++;
    }
    return appliedCount;
  }

  SyncEntityAdapter _requiredAdapter(String entityType) {
    final adapter = _adapterByType[entityType];
    if (adapter == null) {
      throw StateError('缺少同步实体适配器：$entityType');
    }
    return adapter;
  }
}

final class _PushOutcome {
  const _PushOutcome({
    required this.uploadedCount,
    required this.conflictCount,
    required this.requiresSnapshot,
    required this.failure,
  });

  final int uploadedCount;
  final int conflictCount;
  final bool requiresSnapshot;
  final CloudSyncException? failure;
}

final class _ConfirmedState {
  const _ConfirmedState({
    required this.parentId,
    required this.schemaVersion,
    required this.payload,
  });

  final String? parentId;
  final int schemaVersion;
  final CloudSyncJsonMap? payload;
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

CloudSyncJsonMap _applyTopLevelPatch(
  CloudSyncJsonMap previous,
  List<CloudSyncPatch> patch,
) {
  final result = CloudSyncJsonMap.from(previous);
  for (final operation in patch) {
    final token = _decodeSingleJsonPointerToken(operation.path);
    switch (operation.operation) {
      case CloudSyncPatchOperation.add:
      case CloudSyncPatchOperation.replace:
        result[token] = copyCloudSyncJsonValue(operation.value);
        break;
      case CloudSyncPatchOperation.remove:
        result.remove(token);
        break;
    }
  }
  return copyCloudSyncJsonMap(result);
}

bool _sameJsonValue(Object? left, Object? right) {
  return canonicalSyncJson(<String, Object?>{'value': left}) ==
      canonicalSyncJson(<String, Object?>{'value': right});
}

String _escapeJsonPointerToken(String value) {
  return value.replaceAll('~', '~0').replaceAll('/', '~1');
}

String _decodeSingleJsonPointerToken(String path) {
  if (!path.startsWith('/') || path.indexOf('/', 1) != -1) {
    throw FormatException('协调器只接受顶层 JSON Patch：$path');
  }
  return path.substring(1).replaceAll('~1', '/').replaceAll('~0', '~');
}
