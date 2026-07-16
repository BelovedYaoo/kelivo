import 'dart:async';

import 'package:uuid/uuid.dart';

import 'cloud_sync_client.dart';
import 'cloud_sync_mutation_planner.dart';
import 'cloud_sync_store.dart';
import 'cloud_sync_types.dart';
import 'sync_codec.dart';
import 'sync_write_journal.dart';

final class CloudSyncRunSummary {
  const CloudSyncRunSummary({
    required this.uploadedCount,
    required this.downloadedCount,
    required this.conflictCount,
    required this.completedAt,
    this.deferredWriteCount = 0,
  });

  final int uploadedCount;
  final int downloadedCount;
  final int conflictCount;
  final DateTime completedAt;
  final int deferredWriteCount;

  CloudSyncRunSummary copyWith({int? deferredWriteCount}) {
    return CloudSyncRunSummary(
      uploadedCount: uploadedCount,
      downloadedCount: downloadedCount,
      conflictCount: conflictCount,
      completedAt: completedAt,
      deferredWriteCount: deferredWriteCount ?? this.deferredWriteCount,
    );
  }
}

final class CloudSyncCoordinator {
  CloudSyncCoordinator(
    this._session,
    this._client,
    this._store,
    this._writeJournal, {
    required List<SyncEntityAdapter> adapters,
    String Function()? createMutationId,
    CloudSyncMutationPlanner? mutationPlanner,
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
    _mutationPlanner =
        mutationPlanner ??
        CloudSyncMutationPlanner(_store, adapters: _adapters);
  }

  static const int _maxPushBatchesPerRun = 10;
  static const int _pageSize = 100;

  final CloudSyncAccountSession _session;
  final CloudSyncTransport _client;
  final CloudSyncStore _store;
  final List<SyncEntityAdapter> _adapters;
  final SyncWriteJournal _writeJournal;
  final String Function() _createMutationId;
  final Map<String, SyncEntityAdapter> _adapterByType =
      <String, SyncEntityAdapter>{};
  late final CloudSyncMutationPlanner _mutationPlanner;
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
      downloadedCount += await _pullSnapshot(
        forceRemoteKeys: pushResult.fieldConflictKeys,
      );
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
      await _mutationPlanner.planLocalEntity(
        _session,
        key,
        local,
        mutationId: _createMutationId(),
      );
    }
  }

  Future<_PushOutcome> _pushPendingChanges() async {
    var uploadedCount = 0;
    var conflictCount = 0;
    var requiresSnapshot = false;
    final fieldConflictKeys = <SyncEntityKey>{};
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
            if (result.reason == 'field-conflict') {
              fieldConflictKeys.add(
                SyncEntityKey(
                  entityType: mutation.entityType.wireName,
                  entityId: mutation.entityId,
                ),
              );
            }
            conflictCount++;
            requiresSnapshot = true;
            continue;
          case CloudSyncMutationStatus.rejected:
            await _store.markOutboxBlocked(
              _session,
              mutationId: mutation.mutationId,
              errorCode: result.errorCode ?? 'SYNC_MUTATION_REJECTED',
            );
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
      fieldConflictKeys: Set<SyncEntityKey>.unmodifiable(fieldConflictKeys),
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

  Future<int> _pullSnapshot({
    Set<SyncEntityKey> forceRemoteKeys = const <SyncEntityKey>{},
  }) async {
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
      appliedCount += await _applyRecords(
        page.records,
        forceRemoteKeys: forceRemoteKeys,
      );
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
        appliedCount += await _reconcileSnapshotAbsences(forceRemoteKeys);
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

  Future<int> _reconcileSnapshotAbsences(Set<SyncEntityKey> forceRemoteKeys) {
    final missing = _store
        .shadows(_session)
        .where(
          (shadow) => !_store.wasSeenInSnapshot(
            _session,
            entityType: shadow.entityType,
            entityId: shadow.entityId,
          ),
        )
        .toList(growable: false);
    if (missing.isEmpty) return Future<int>.value(0);
    final keys = <SyncEntityKey>{
      for (final shadow in missing)
        SyncEntityKey(
          entityType: shadow.entityType.wireName,
          entityId: shadow.entityId,
        ),
    };
    final adapters =
        keys
            .map((key) => _requiredAdapter(key.entityType))
            .toSet()
            .toList(growable: false)
          ..sort(
            (left, right) => left.applyPriority.compareTo(right.applyPriority),
          );
    return _writeJournal.runRemoteBatch<int>(
      keys: keys,
      write: () => _runAdapterRemoteBatches<int>(
        adapters,
        0,
        () => _reconcileSnapshotAbsencesLocked(missing, forceRemoteKeys),
      ),
    );
  }

  Future<int> _reconcileSnapshotAbsencesLocked(
    List<CloudSyncShadow> missing,
    Set<SyncEntityKey> forceRemoteKeys,
  ) async {
    var deletedCount = 0;
    for (final shadow in missing) {
      final key = SyncEntityKey(
        entityType: shadow.entityType.wireName,
        entityId: shadow.entityId,
      );
      final adapter = _requiredAdapter(key.entityType);
      if (forceRemoteKeys.contains(key)) {
        final pending = _store.outboxForEntity(
          _session,
          entityType: shadow.entityType,
          entityId: shadow.entityId,
        );
        for (final mutation in pending) {
          await _store.removeOutbox(_session, mutation.mutationId);
        }
        await _applyRemoteDelete(adapter, key);
        await _store.deleteShadow(
          _session,
          entityType: shadow.entityType,
          entityId: shadow.entityId,
        );
        deletedCount++;
        continue;
      }
      final local = await _captureLocalBeforeSnapshot(key, adapter);
      final pending = _store.outboxForEntity(
        _session,
        entityType: shadow.entityType,
        entityId: shadow.entityId,
      );
      if (_containsImmutableSnapshotMutation(pending)) continue;

      for (final mutation in pending) {
        await _store.removeOutbox(_session, mutation.mutationId);
      }
      await _store.deleteShadow(
        _session,
        entityType: shadow.entityType,
        entityId: shadow.entityId,
      );
      if (local == null) {
        await _applyRemoteDelete(adapter, key);
      } else {
        // 快照缺席代表服务端同步域被重建，本地实体必须作为新基线重新创建。
        await _mutationPlanner.planLocalEntity(
          _session,
          key,
          local,
          mutationId: _createMutationId(),
        );
      }
      deletedCount++;
    }
    return deletedCount;
  }

  Future<int> _applyRecords(
    List<CloudSyncRecord> records, {
    required Set<SyncEntityKey> forceRemoteKeys,
  }) {
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
      forceRemoteKeys: forceRemoteKeys,
    );
  }

  Future<int> _applyChanges(
    List<CloudSyncChange> changes, {
    List<CloudSyncRecord> snapshotRecords = const <CloudSyncRecord>[],
    bool authoritative = false,
    Set<SyncEntityKey> forceRemoteKeys = const <SyncEntityKey>{},
  }) {
    final keys = <SyncEntityKey>{
      for (final change in changes)
        SyncEntityKey(
          entityType: change.entityType.wireName,
          entityId: change.entityId,
        ),
    };
    if (keys.isEmpty) return Future<int>.value(0);
    final adapters =
        keys
            .map((key) => _requiredAdapter(key.entityType))
            .toSet()
            .toList(growable: false)
          ..sort(
            (left, right) => left.applyPriority.compareTo(right.applyPriority),
          );
    return _writeJournal.runRemoteBatch<int>(
      keys: keys,
      write: () => _runAdapterRemoteBatches<int>(
        adapters,
        0,
        () => _applyChangesLocked(
          changes,
          snapshotRecords: snapshotRecords,
          authoritative: authoritative,
          forceRemoteKeys: forceRemoteKeys,
        ),
      ),
    );
  }

  Future<T> _runAdapterRemoteBatches<T>(
    List<SyncEntityAdapter> adapters,
    int index,
    Future<T> Function() apply,
  ) {
    if (index >= adapters.length) return apply();
    return adapters[index].runRemoteBatch<T>(
      () => _runAdapterRemoteBatches<T>(adapters, index + 1, apply),
    );
  }

  Future<int> _applyChangesLocked(
    List<CloudSyncChange> changes, {
    List<CloudSyncRecord> snapshotRecords = const <CloudSyncRecord>[],
    bool authoritative = false,
    Set<SyncEntityKey> forceRemoteKeys = const <SyncEntityKey>{},
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
      final forceRemote = authoritative && forceRemoteKeys.contains(key);
      final snapshotLocal = authoritative && !forceRemote
          ? await _captureLocalBeforeSnapshot(key, adapter)
          : null;
      final pending = _store.outboxForEntity(
        _session,
        entityType: change.entityType,
        entityId: change.entityId,
      );
      if (forceRemote) {
        for (final mutation in pending) {
          await _store.removeOutbox(_session, mutation.mutationId);
        }
      }
      final preserveLocal = !forceRemote && pending.isNotEmpty;
      final immutableSnapshotMutation =
          authoritative &&
          !forceRemote &&
          _containsImmutableSnapshotMutation(pending);
      final record = change.record;
      if (change.operation == CloudSyncChangeOperation.upsert &&
          record != null &&
          record.deletedAt == null) {
        if (!preserveLocal) {
          await _applyRemoteUpsert(
            adapter,
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
        final nextShadow = CloudSyncShadow(
          entityType: record.entityType,
          entityId: record.entityId,
          parentId: record.parentId,
          revision: record.revision,
          schemaVersion: record.schemaVersion,
          lastChangeSeq: record.lastChangeSeq,
          deleted: false,
          payload: record.payload,
          updatedAt: record.updatedAt,
        );
        if (!immutableSnapshotMutation) {
          await _store.saveShadow(_session, nextShadow);
        }
        if (authoritative &&
            !forceRemote &&
            pending.isNotEmpty &&
            !immutableSnapshotMutation) {
          await _replanUnattemptedAfterSnapshot(key, snapshotLocal, pending);
        }
        appliedCount++;
        continue;
      }

      if (!preserveLocal) {
        await _applyRemoteDelete(adapter, key);
      }
      final snapshot = snapshotByKey[key];
      final nextShadow = CloudSyncShadow(
        entityType: change.entityType,
        entityId: change.entityId,
        parentId: snapshot?.parentId ?? previous?.parentId,
        revision: change.revision,
        schemaVersion: snapshot?.schemaVersion ?? previous?.schemaVersion ?? 1,
        lastChangeSeq: change.changeSeq,
        deleted: true,
        payload: snapshot?.payload ?? previous?.payload,
        updatedAt: change.deletedAt ?? DateTime.now(),
      );
      if (!immutableSnapshotMutation) {
        await _store.saveShadow(_session, nextShadow);
      }
      if (authoritative &&
          !forceRemote &&
          pending.isNotEmpty &&
          !immutableSnapshotMutation) {
        await _replanUnattemptedAfterSnapshot(key, snapshotLocal, pending);
      }
      appliedCount++;
    }
    return appliedCount;
  }

  Future<LocalSyncEntity?> _captureLocalBeforeSnapshot(
    SyncEntityKey key,
    SyncEntityAdapter adapter,
  ) async {
    final local = await adapter.exportLocalEntity(key);
    await _mutationPlanner.planLocalEntity(
      _session,
      key,
      local,
      mutationId: _createMutationId(),
    );
    return local;
  }

  Future<void> _applyRemoteUpsert(
    SyncEntityAdapter adapter,
    RemoteSyncEntity entity,
  ) {
    return _writeJournal.runRemote<void>(
      key: entity.key,
      write: () => adapter.applyRemoteUpsert(entity),
    );
  }

  Future<void> _applyRemoteDelete(
    SyncEntityAdapter adapter,
    SyncEntityKey key,
  ) {
    return _writeJournal.runRemote<void>(
      key: key,
      write: () => adapter.applyRemoteDelete(key),
    );
  }

  bool _containsImmutableSnapshotMutation(
    List<CloudSyncOutboxMutation> pending,
  ) {
    return pending.any(
      (mutation) => mutation.attemptCount > 0 || mutation.blockedAt != null,
    );
  }

  Future<void> _replanUnattemptedAfterSnapshot(
    SyncEntityKey key,
    LocalSyncEntity? local,
    List<CloudSyncOutboxMutation> pending,
  ) async {
    for (final mutation in pending) {
      await _store.removeOutbox(_session, mutation.mutationId);
    }
    await _mutationPlanner.planLocalEntity(
      _session,
      key,
      local,
      mutationId: _createMutationId(),
    );
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
    required this.fieldConflictKeys,
    required this.failure,
  });

  final int uploadedCount;
  final int conflictCount;
  final bool requiresSnapshot;
  final Set<SyncEntityKey> fieldConflictKeys;
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

String _decodeSingleJsonPointerToken(String path) {
  if (!path.startsWith('/') || path.indexOf('/', 1) != -1) {
    throw FormatException('协调器只接受顶层 JSON Patch：$path');
  }
  return path.substring(1).replaceAll('~1', '/').replaceAll('~0', '~');
}
