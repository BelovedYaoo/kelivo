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
  List<_RemoteApplyResult>? _deferredRemoteStoreResults;
  Set<SyncEntityKey>? _deferredRemoteStoreKeys;

  Future<CloudSyncRunSummary> synchronize({
    Set<String> rescanEntityTypes = const <String>{},
    Set<String> localAuthoritativeEntityTypes = const <String>{},
  }) {
    final active = _activeRun;
    if (active != null) {
      if (rescanEntityTypes.isNotEmpty ||
          localAuthoritativeEntityTypes.isNotEmpty) {
        throw StateError('同步运行期间不能追加重扫');
      }
      return active;
    }

    final requestedRescanTypes = Set<String>.unmodifiable(rescanEntityTypes);
    final requestedLocalAuthoritativeTypes = Set<String>.unmodifiable(
      localAuthoritativeEntityTypes,
    );
    if (!requestedRescanTypes.containsAll(requestedLocalAuthoritativeTypes)) {
      throw StateError('本地权威实体类型必须属于重扫范围');
    }
    for (final entityType in requestedRescanTypes) {
      if (!_adapterByType.containsKey(entityType)) {
        throw StateError('配置重扫包含未注册的实体类型：$entityType');
      }
    }

    final run = _synchronize(
      requestedRescanTypes,
      requestedLocalAuthoritativeTypes,
    );
    _activeRun = run;
    return run.whenComplete(() {
      if (identical(_activeRun, run)) {
        _activeRun = null;
      }
    });
  }

  Future<CloudSyncRunSummary> _synchronize(
    Set<String> rescanEntityTypes,
    Set<String> localAuthoritativeEntityTypes,
  ) {
    // 快照只在单轮同步内存活，Hive 始终是 outbox 的唯一持久化真相。
    return _store.runWithOutboxSnapshot(
      _session,
      () => _synchronizeWithOutboxSnapshot(
        rescanEntityTypes,
        localAuthoritativeEntityTypes,
      ),
    );
  }

  Future<CloudSyncRunSummary> _synchronizeWithOutboxSnapshot(
    Set<String> rescanEntityTypes,
    Set<String> localAuthoritativeEntityTypes,
  ) async {
    var uploadedCount = 0;
    var downloadedCount = 0;
    var conflictCount = 0;

    var cursorState = _store.cursorState(_session);
    final isInitialSync = cursorState.pullCursor == null;
    if (localAuthoritativeEntityTypes.isNotEmpty) {
      // 权威代次不能继承普通快照的 seen 集合，否则覆盖前已读取的页面会逃逸删除。
      await _store.clearSyncProgress(_session);
      downloadedCount += await _pullSnapshot(
        localAuthoritativeEntityTypes: localAuthoritativeEntityTypes,
      );
    } else if (isInitialSync) {
      downloadedCount += await _pullSnapshot();
    } else if (rescanEntityTypes.isNotEmpty) {
      await _scanLocalChanges(entityTypes: rescanEntityTypes);
    }

    cursorState = _store.cursorState(_session);
    downloadedCount += await _pullChanges(
      cursorState.pullCursor,
      localAuthoritativeEntityTypes: localAuthoritativeEntityTypes,
    );

    if (isInitialSync) {
      await _scanLocalChanges();
    } else if (localAuthoritativeEntityTypes.isNotEmpty) {
      await _scanLocalChanges(entityTypes: rescanEntityTypes);
    }
    final pushResult = await _pushPendingChanges(
      localAuthoritativeEntityTypes: localAuthoritativeEntityTypes,
    );
    uploadedCount += pushResult.uploadedCount;
    conflictCount += pushResult.conflictCount;

    if (pushResult.requiresSnapshot) {
      await _store.clearSyncProgress(_session);
      downloadedCount += await _pullSnapshot(
        forceRemoteKeys: pushResult.fieldConflictKeys,
        localAuthoritativeEntityTypes: localAuthoritativeEntityTypes,
      );
    }

    final failure = pushResult.failure;
    if (failure != null) throw failure;

    cursorState = _store.cursorState(_session);
    downloadedCount += await _pullChanges(
      cursorState.pullCursor,
      localAuthoritativeEntityTypes: localAuthoritativeEntityTypes,
    );

    return CloudSyncRunSummary(
      uploadedCount: uploadedCount,
      downloadedCount: downloadedCount,
      conflictCount: conflictCount,
      completedAt: DateTime.now().toUtc(),
    );
  }

  Future<Map<SyncEntityKey, LocalSyncEntity>> _exportLocalEntities({
    Set<String>? entityTypes,
  }) async {
    final result = <SyncEntityKey, LocalSyncEntity>{};
    for (final adapter in _adapters) {
      if (entityTypes != null &&
          !adapter.entityTypes.any(entityTypes.contains)) {
        continue;
      }
      final entities = await adapter.exportLocalEntities();
      for (final entity in entities) {
        if (!adapter.entityTypes.contains(entity.entityType)) {
          throw StateError('适配器导出了未声明的实体类型：${entity.entityType}');
        }
        if (entityTypes != null && !entityTypes.contains(entity.entityType)) {
          continue;
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

  Future<void> _scanLocalChanges({Set<String>? entityTypes}) async {
    final localByKey = await _exportLocalEntities(entityTypes: entityTypes);
    // 普通重扫只恢复当前仍存在的本地实体；删除必须来自写入日志或显式的本地权威重扫。
    final keys = localByKey.keys.toList()
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

  Future<_PushOutcome> _pushPendingChanges({
    required Set<String> localAuthoritativeEntityTypes,
  }) async {
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
            if (mutation.operation == CloudSyncMutationOperation.restore) {
              await _planRestoredEntityFollowUp(mutation);
            }
            uploadedCount++;
            continue;
          case CloudSyncMutationStatus.conflict:
            await _store.removeOutbox(_session, mutation.mutationId);
            if (result.reason == 'field-conflict' &&
                !localAuthoritativeEntityTypes.contains(
                  mutation.entityType.wireName,
                )) {
              // 普通字段冲突保持远端优先；显式覆盖仍需用最新 revision 重建本地 mutation。
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

  Future<void> _planRestoredEntityFollowUp(CloudSyncOutboxMutation mutation) {
    final key = SyncEntityKey(
      entityType: mutation.entityType.wireName,
      entityId: mutation.entityId,
    );
    final adapter = _requiredAdapter(key.entityType);
    return _writeJournal.runRemote<void>(
      key: key,
      write: () async {
        final local = await adapter.exportLocalEntity(key);
        await _mutationPlanner.planLocalEntity(
          _session,
          key,
          local,
          mutationId: _createMutationId(),
        );
      },
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
    Set<String> localAuthoritativeEntityTypes = const <String>{},
  }) async {
    final transactional = _hasRemoteTransactionAdapters;
    final state = _store.cursorState(_session);
    var snapshotCursor = transactional ? null : state.snapshotCursor;
    var syncCursor = transactional ? null : state.snapshotSyncCursor;

    if (snapshotCursor == null) {
      await _store.beginSnapshot(_session);
    }

    final outcome = await _runRemoteSyncTransaction(() async {
      var appliedCount = 0;
      while (true) {
        final page = await _client.snapshot(
          snapshotCursor: snapshotCursor,
          limit: _pageSize,
        );
        appliedCount += await _applyRecords(
          page.records,
          forceRemoteKeys: forceRemoteKeys,
          localAuthoritativeEntityTypes: localAuthoritativeEntityTypes,
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
          return _SnapshotPullOutcome(
            appliedCount: appliedCount,
            syncCursor: completedCursor,
          );
        }
        final nextCursor = page.nextSnapshotCursor;
        if (nextCursor == null) {
          throw const CloudSyncException(
            kind: CloudSyncFailureKind.invalidResponse,
            retryable: true,
            serverCode: 'SYNC_SNAPSHOT_PAGE_CURSOR_MISSING',
          );
        }
        if (!transactional) {
          await _store.saveSnapshotProgress(
            _session,
            snapshotCursor: nextCursor,
            syncCursor: syncCursor,
          );
        }
        snapshotCursor = nextCursor;
      }
    });
    await _store.completeSnapshot(_session, syncCursor: outcome.syncCursor);
    await _store.finishSnapshot(_session);
    return outcome.appliedCount;
  }

  Future<int> _pullChanges(
    String? initialCursor, {
    required Set<String> localAuthoritativeEntityTypes,
  }) async {
    var cursor = initialCursor;
    var appliedCount = 0;
    while (true) {
      final transactional = _hasRemoteTransactionAdapters;
      final outcome = await _runRemoteSyncTransaction(() async {
        var pageAppliedCount = 0;
        var pageCursor = cursor;
        while (true) {
          final page = await _client.pull(cursor: pageCursor, limit: _pageSize);
          if (page.resetRequired) {
            return _PullChangesOutcome(
              appliedCount: pageAppliedCount,
              nextCursor: pageCursor,
              resetRequired: true,
            );
          }
          pageAppliedCount += await _applyChanges(
            page.changes,
            localAuthoritativeEntityTypes: localAuthoritativeEntityTypes,
          );
          pageCursor = page.nextCursor;
          if (!transactional) {
            await _store.savePullCursor(_session, pageCursor);
          }
          if (!page.hasMore) {
            return _PullChangesOutcome(
              appliedCount: pageAppliedCount,
              nextCursor: pageCursor,
              resetRequired: false,
            );
          }
        }
      });
      appliedCount += outcome.appliedCount;
      if (outcome.resetRequired) {
        await _store.clearSyncProgress(_session);
        appliedCount += await _pullSnapshot(
          localAuthoritativeEntityTypes: localAuthoritativeEntityTypes,
        );
        cursor = _store.cursorState(_session).pullCursor;
        continue;
      }
      await _store.savePullCursor(_session, outcome.nextCursor);
      return appliedCount;
    }
  }

  Future<int> _reconcileSnapshotAbsences(
    Set<SyncEntityKey> forceRemoteKeys,
  ) async {
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
    if (missing.isEmpty) return 0;
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
      write: () async {
        final result = await _runAdapterRemoteBatches<_RemoteApplyResult>(
          adapters,
          0,
          () => _reconcileSnapshotAbsencesLocked(missing, forceRemoteKeys),
        );
        await _commitOrDeferRemoteStoreState(result, keys: keys);
        return result.appliedCount;
      },
    );
  }

  Future<_RemoteApplyResult> _reconcileSnapshotAbsencesLocked(
    List<CloudSyncShadow> missing,
    Set<SyncEntityKey> forceRemoteKeys,
  ) async {
    var deletedCount = 0;
    final storeActions = <Future<void> Function()>[];
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
        await _applyRemoteDelete(adapter, key);
        storeActions.add(() async {
          for (final mutation in pending) {
            await _store.removeOutbox(_session, mutation.mutationId);
          }
          await _store.deleteShadow(
            _session,
            entityType: shadow.entityType,
            entityId: shadow.entityId,
          );
        });
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

      if (local == null) {
        await _applyRemoteDelete(adapter, key);
        storeActions.add(() async {
          for (final mutation in pending) {
            await _store.removeOutbox(_session, mutation.mutationId);
          }
          await _store.deleteShadow(
            _session,
            entityType: shadow.entityType,
            entityId: shadow.entityId,
          );
        });
      } else {
        final replacement = CloudSyncOutboxMutation.create(
          mutationId: _createMutationId(),
          entityType: shadow.entityType,
          entityId: local.entityId,
          parentId: local.parentId,
          schemaVersion: local.schemaVersion,
          payload: local.payload,
        );
        storeActions.add(() async {
          // 先建立新基线，确保中途失败时本地实体仍有可重放的创建请求。
          await _store.enqueueOutbox(_session, replacement, merge: false);
          for (final mutation in pending) {
            await _store.removeOutbox(_session, mutation.mutationId);
          }
          await _store.deleteShadow(
            _session,
            entityType: shadow.entityType,
            entityId: shadow.entityId,
          );
        });
      }
      deletedCount++;
    }
    return _RemoteApplyResult(
      appliedCount: deletedCount,
      storeActions: storeActions,
    );
  }

  Future<int> _applyRecords(
    List<CloudSyncRecord> records, {
    required Set<SyncEntityKey> forceRemoteKeys,
    required Set<String> localAuthoritativeEntityTypes,
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
      localAuthoritativeEntityTypes: localAuthoritativeEntityTypes,
    );
  }

  Future<int> _applyChanges(
    List<CloudSyncChange> changes, {
    List<CloudSyncRecord> snapshotRecords = const <CloudSyncRecord>[],
    bool authoritative = false,
    Set<SyncEntityKey> forceRemoteKeys = const <SyncEntityKey>{},
    Set<String> localAuthoritativeEntityTypes = const <String>{},
  }) async {
    final keys = <SyncEntityKey>{
      for (final change in changes)
        SyncEntityKey(
          entityType: change.entityType.wireName,
          entityId: change.entityId,
        ),
    };
    if (keys.isEmpty) return 0;
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
      write: () async {
        // 实体锁稳定住 outbox 决策，同时让慢速资源准备早于数据库事务发生。
        final preparations = await _prepareRemoteUpserts(
          changes,
          authoritative: authoritative,
          forceRemoteKeys: forceRemoteKeys,
          localAuthoritativeEntityTypes: localAuthoritativeEntityTypes,
        );
        try {
          final result = await _runAdapterRemoteBatches<_RemoteApplyResult>(
            adapters,
            0,
            () => _applyChangesLocked(
              changes,
              preparations: preparations,
              snapshotRecords: snapshotRecords,
              authoritative: authoritative,
              forceRemoteKeys: forceRemoteKeys,
              localAuthoritativeEntityTypes: localAuthoritativeEntityTypes,
            ),
          );
          await preparations.commitApplied();
          await _commitOrDeferRemoteStoreState(result, keys: keys);
          return result.appliedCount;
        } catch (_) {
          await preparations.discard();
          rethrow;
        }
      },
    );
  }

  Future<_RemoteUpsertPreparationBatch> _prepareRemoteUpserts(
    List<CloudSyncChange> changes, {
    required bool authoritative,
    required Set<SyncEntityKey> forceRemoteKeys,
    required Set<String> localAuthoritativeEntityTypes,
  }) async {
    final latestByKey = <SyncEntityKey, CloudSyncChange>{};
    for (final change in changes) {
      latestByKey[SyncEntityKey(
            entityType: change.entityType.wireName,
            entityId: change.entityId,
          )] =
          change;
    }
    final preparations = _RemoteUpsertPreparationBatch();
    try {
      for (final entry in latestByKey.entries) {
        final key = entry.key;
        final change = entry.value;
        final record = change.record;
        if (change.operation != CloudSyncChangeOperation.upsert ||
            record == null ||
            record.deletedAt != null) {
          continue;
        }
        final adapter = _requiredAdapter(key.entityType);
        final RemoteSyncUpsertPreparer? preparer = switch (adapter) {
          RemoteSyncUpsertPreparer value => value,
          _ => null,
        };
        if (preparer == null) continue;
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
        if (!forceRemote &&
            localAuthoritativeEntityTypes.contains(key.entityType)) {
          continue;
        }
        final pending = _store.outboxForEntity(
          _session,
          entityType: change.entityType,
          entityId: change.entityId,
        );
        if (!forceRemote && pending.isNotEmpty) continue;
        final entity = _remoteEntity(record);
        final prepared = await preparer.prepareRemoteUpsert(entity);
        if (prepared != null) {
          await preparations.add(prepared, expectedKey: key);
        }
      }
      return preparations;
    } catch (_) {
      await preparations.discard();
      rethrow;
    }
  }

  bool get _hasRemoteTransactionAdapters =>
      _adapters.any((adapter) => adapter is RemoteSyncTransactionAdapter);

  Future<T> _runRemoteSyncTransaction<T>(Future<T> Function() apply) async {
    final participants = _adapters
        .whereType<RemoteSyncTransactionAdapter>()
        .toList(growable: false);
    if (participants.isEmpty) return apply();
    if (_deferredRemoteStoreResults != null) {
      throw StateError('远端同步事务不能嵌套');
    }

    final deferredResults = <_RemoteApplyResult>[];
    final deferredKeys = <SyncEntityKey>{
      for (final participant in participants)
        ...participant.remoteTransactionKeys,
    };
    _deferredRemoteStoreResults = deferredResults;
    _deferredRemoteStoreKeys = deferredKeys;
    try {
      final result = await _runAdapterRemoteTransactions<T>(
        participants,
        0,
        apply,
      );
      for (final deferred in deferredResults) {
        await deferred.commitStoreState();
      }
      return result;
    } finally {
      _deferredRemoteStoreResults = null;
      _deferredRemoteStoreKeys = null;
    }
  }

  Future<T> _runAdapterRemoteTransactions<T>(
    List<RemoteSyncTransactionAdapter> adapters,
    int index,
    Future<T> Function() apply,
  ) {
    if (index >= adapters.length) return apply();
    return adapters[index].runRemoteTransaction<T>(
      () => _runAdapterRemoteTransactions<T>(adapters, index + 1, apply),
      commit: (keys, write) =>
          _writeJournal.runRemoteBatch<void>(keys: keys, write: write),
    );
  }

  Future<void> _commitOrDeferRemoteStoreState(
    _RemoteApplyResult result, {
    required Set<SyncEntityKey> keys,
  }) {
    final deferred = _deferredRemoteStoreResults;
    if (deferred == null) return result.commitStoreState();
    final deferredKeys = _deferredRemoteStoreKeys;
    if (deferredKeys == null ||
        !keys.any((key) => deferredKeys.contains(key))) {
      return result.commitStoreState();
    }
    deferred.add(result);
    return Future<void>.value();
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

  Future<_RemoteApplyResult> _applyChangesLocked(
    List<CloudSyncChange> changes, {
    required _RemoteUpsertPreparationBatch preparations,
    List<CloudSyncRecord> snapshotRecords = const <CloudSyncRecord>[],
    bool authoritative = false,
    Set<SyncEntityKey> forceRemoteKeys = const <SyncEntityKey>{},
    Set<String> localAuthoritativeEntityTypes = const <String>{},
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
    final storeActions = <Future<void> Function()>[];

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
      final snapshot = snapshotByKey[key];
      final localAuthoritative =
          !forceRemote &&
          localAuthoritativeEntityTypes.contains(key.entityType);
      final explicitBaseline = localAuthoritative
          ? _changeBaseline(change, snapshot: snapshot, previous: previous)
          : null;
      final snapshotLocal =
          (authoritative || localAuthoritative) && !forceRemote
          ? await _captureLocalBeforeSnapshot(
              key,
              adapter,
              explicitBaseline: explicitBaseline,
            )
          : null;
      final pending = _store.outboxForEntity(
        _session,
        entityType: change.entityType,
        entityId: change.entityId,
      );
      if (forceRemote) {
        storeActions.add(() async {
          for (final mutation in pending) {
            await _store.removeOutbox(_session, mutation.mutationId);
          }
        });
      }
      final preserveLocal =
          localAuthoritative || (!forceRemote && pending.isNotEmpty);
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
            _remoteEntity(record),
            preparations,
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
          storeActions.add(() => _store.saveShadow(_session, nextShadow));
        }
        if (authoritative &&
            !forceRemote &&
            pending.isNotEmpty &&
            !immutableSnapshotMutation) {
          storeActions.add(
            () => _replanUnattemptedAfterSnapshot(key, snapshotLocal, pending),
          );
        }
        appliedCount++;
        continue;
      }

      if (!preserveLocal) {
        await _applyRemoteDelete(adapter, key);
      }
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
        storeActions.add(() => _store.saveShadow(_session, nextShadow));
      }
      if (authoritative &&
          !forceRemote &&
          pending.isNotEmpty &&
          !immutableSnapshotMutation) {
        storeActions.add(
          () => _replanUnattemptedAfterSnapshot(key, snapshotLocal, pending),
        );
      }
      appliedCount++;
    }
    return _RemoteApplyResult(
      appliedCount: appliedCount,
      storeActions: storeActions,
    );
  }

  Future<LocalSyncEntity?> _captureLocalBeforeSnapshot(
    SyncEntityKey key,
    SyncEntityAdapter adapter, {
    CloudSyncShadow? explicitBaseline,
  }) async {
    final local = await adapter.exportLocalEntity(key);
    if (local == null && explicitBaseline == null) {
      // 普通快照只能确认远端真相；没有写前 mutation 时，本地缺失本身不是删除意图。
      return null;
    }
    if (explicitBaseline == null) {
      await _mutationPlanner.planLocalEntity(
        _session,
        key,
        local,
        mutationId: _createMutationId(),
      );
    } else {
      await _mutationPlanner.planLocalEntityAgainstBaseline(
        _session,
        key,
        local,
        baseline: explicitBaseline,
        mutationId: _createMutationId(),
      );
    }
    return local;
  }

  CloudSyncShadow _snapshotBaseline(CloudSyncRecord record) {
    return CloudSyncShadow(
      entityType: record.entityType,
      entityId: record.entityId,
      parentId: record.parentId,
      revision: record.revision,
      schemaVersion: record.schemaVersion,
      lastChangeSeq: record.lastChangeSeq,
      deleted: record.deletedAt != null,
      payload: record.payload,
      updatedAt: record.deletedAt ?? record.updatedAt,
    );
  }

  CloudSyncShadow _changeBaseline(
    CloudSyncChange change, {
    CloudSyncRecord? snapshot,
    CloudSyncShadow? previous,
  }) {
    final record = snapshot ?? change.record;
    if (record != null) return _snapshotBaseline(record);
    return CloudSyncShadow(
      entityType: change.entityType,
      entityId: change.entityId,
      parentId: previous?.parentId,
      revision: change.revision,
      schemaVersion: previous?.schemaVersion ?? 1,
      lastChangeSeq: change.changeSeq,
      deleted: true,
      payload: previous?.payload,
      updatedAt: change.deletedAt ?? DateTime.now().toUtc(),
    );
  }

  Future<void> _applyRemoteUpsert(
    SyncEntityAdapter adapter,
    RemoteSyncEntity entity,
    _RemoteUpsertPreparationBatch preparations,
  ) {
    return _writeJournal.runRemote<void>(
      key: entity.key,
      write: () async {
        final prepared = preparations[entity.key];
        if (prepared == null) {
          await adapter.applyRemoteUpsert(entity);
          return;
        }
        await prepared.apply();
        preparations.markApplied(entity.key);
      },
    );
  }

  RemoteSyncEntity _remoteEntity(CloudSyncRecord record) {
    return RemoteSyncEntity(
      entityType: record.entityType.wireName,
      entityId: record.entityId,
      parentId: record.parentId,
      revision: record.revision,
      schemaVersion: record.schemaVersion,
      payload: record.payload,
      updatedAt: record.updatedAt,
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

final class _SnapshotPullOutcome {
  const _SnapshotPullOutcome({
    required this.appliedCount,
    required this.syncCursor,
  });

  final int appliedCount;
  final String syncCursor;
}

final class _PullChangesOutcome {
  const _PullChangesOutcome({
    required this.appliedCount,
    required this.nextCursor,
    required this.resetRequired,
  });

  final int appliedCount;
  final String? nextCursor;
  final bool resetRequired;
}

final class _RemoteApplyResult {
  _RemoteApplyResult({
    required this.appliedCount,
    required List<Future<void> Function()> storeActions,
  }) : _storeActions = List<Future<void> Function()>.unmodifiable(storeActions);

  final int appliedCount;
  final List<Future<void> Function()> _storeActions;

  Future<void> commitStoreState() async {
    for (final action in _storeActions) {
      await action();
    }
  }
}

final class _RemoteUpsertPreparationBatch {
  final Map<SyncEntityKey, PreparedRemoteSyncUpsert> _byKey =
      <SyncEntityKey, PreparedRemoteSyncUpsert>{};
  final Set<SyncEntityKey> _appliedKeys = <SyncEntityKey>{};
  final Set<SyncEntityKey> _settledKeys = <SyncEntityKey>{};

  PreparedRemoteSyncUpsert? operator [](SyncEntityKey key) => _byKey[key];

  Future<void> add(
    PreparedRemoteSyncUpsert prepared, {
    required SyncEntityKey expectedKey,
  }) async {
    if (prepared.key != expectedKey) {
      await prepared.discard();
      throw StateError('远端资源准备结果与实体身份不一致');
    }
    if (_byKey.containsKey(prepared.key)) {
      await prepared.discard();
      throw StateError('同一远端实体存在重复资源准备结果');
    }
    _byKey[prepared.key] = prepared;
  }

  void markApplied(SyncEntityKey key) {
    if (!_byKey.containsKey(key)) {
      throw StateError('远端资源准备结果不存在');
    }
    _appliedKeys.add(key);
  }

  Future<void> commitApplied() async {
    for (final entry in _byKey.entries) {
      if (_settledKeys.contains(entry.key)) continue;
      if (_appliedKeys.contains(entry.key)) {
        await entry.value.commit();
      } else {
        await entry.value.discard();
      }
      _settledKeys.add(entry.key);
    }
  }

  Future<void> discard() async {
    for (final entry in _byKey.entries.toList(growable: false).reversed) {
      if (_settledKeys.contains(entry.key)) continue;
      await entry.value.discard();
      _settledKeys.add(entry.key);
    }
  }
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
