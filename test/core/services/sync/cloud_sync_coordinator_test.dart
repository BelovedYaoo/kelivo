import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:Kelivo/core/services/sync/cloud_sync_client.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_coordinator.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_store.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/sync/sync_codec.dart';
import 'package:Kelivo/core/services/sync/sync_write_journal.dart';

void main() {
  late Directory tempDirectory;
  late CloudSyncStore store;
  late SyncWriteJournal writeJournal;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'kelivo_cloud_sync_coordinator_test_',
    );
    Hive.init(tempDirectory.path);
    store = await CloudSyncStore.open(boxName: 'cloud-sync-coordinator-test');
    writeJournal = SyncWriteJournal(
      store: store,
      journalScopeId: 'coordinator-test',
      initialSession: _session(),
    );
  });

  tearDown(() async {
    await writeJournal.close();
    await store.close();
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('服务端永久拒绝后保留 mutation 且后续同步不再重投', () async {
    final session = _session();
    final transport = _RejectingTransport();
    await store.savePullCursor(session, 'cursor-0');
    await store.enqueueOutbox(
      session,
      CloudSyncOutboxMutation.create(
        mutationId: 'mutation-1',
        entityType: CloudSyncEntityType.message,
        entityId: 'message-1',
        parentId: 'turn-1',
        schemaVersion: 2,
        payload: const <String, Object?>{
          'conversationId': 'conversation-1',
          'turnId': 'turn-1',
        },
      ),
    );
    final coordinator = CloudSyncCoordinator(
      session,
      transport,
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[_MessageAdapter()],
    );

    await expectLater(
      coordinator.synchronize(),
      throwsA(
        isA<CloudSyncException>()
            .having(
              (error) => error.kind,
              'kind',
              CloudSyncFailureKind.validation,
            )
            .having(
              (error) => error.serverCode,
              'serverCode',
              'SYNC_PAYLOAD_INVALID',
            ),
      ),
    );
    await coordinator.synchronize();

    expect(transport.pushedMutationIds, <String>['mutation-1']);
    final retained = store
        .outboxForEntity(
          session,
          entityType: CloudSyncEntityType.message,
          entityId: 'message-1',
        )
        .single;
    expect(retained.mutationId, 'mutation-1');
    expect(retained.lastErrorCode, 'SYNC_PAYLOAD_INVALID');
    expect(retained.blockedAt, isNotNull);
  });

  test('首次快照记录不会覆盖本地修改并按远端版本重建更新', () async {
    final session = _session();
    final key = const SyncEntityKey(
      entityType: 'message',
      entityId: 'message-1',
    );
    final adapter = _StatefulMessageAdapter(<SyncEntityKey, LocalSyncEntity>{
      key: _localMessage(value: 'local'),
    });
    final transport = _SnapshotThenStopTransport(<CloudSyncRecord>[
      _messageRecord(revision: 4, changeSeq: 8, value: 'remote'),
    ]);
    var mutationIndex = 0;
    final coordinator = CloudSyncCoordinator(
      session,
      transport,
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
      createMutationId: () => 'snapshot-mutation-${mutationIndex++}',
    );

    await expectLater(
      coordinator.synchronize(),
      throwsA(isA<_StopAfterSnapshot>()),
    );

    expect(adapter.entities[key]?.payload['value'], 'local');
    expect(adapter.remoteUpserts, isEmpty);
    expect(
      store
          .shadow(
            session,
            entityType: CloudSyncEntityType.message,
            entityId: key.entityId,
          )
          ?.payload?['value'],
      'remote',
    );
    final pending = store
        .outboxForEntity(
          session,
          entityType: CloudSyncEntityType.message,
          entityId: key.entityId,
        )
        .single;
    expect(pending.operation, CloudSyncMutationOperation.update);
    expect(pending.baseRevision, 4);
  });

  test('快照墓碑不会覆盖未尝试的本地修改并重建恢复操作', () async {
    final session = _session();
    final key = const SyncEntityKey(
      entityType: 'message',
      entityId: 'message-1',
    );
    final adapter = _StatefulMessageAdapter(<SyncEntityKey, LocalSyncEntity>{
      key: _localMessage(value: 'local'),
    });
    final transport = _SnapshotThenStopTransport(<CloudSyncRecord>[
      _messageRecord(
        revision: 4,
        changeSeq: 8,
        value: 'remote',
        deletedAt: DateTime.utc(2026, 7, 16, 9),
      ),
    ]);
    var mutationIndex = 0;
    final coordinator = CloudSyncCoordinator(
      session,
      transport,
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
      createMutationId: () => 'snapshot-delete-${mutationIndex++}',
    );

    await expectLater(
      coordinator.synchronize(),
      throwsA(isA<_StopAfterSnapshot>()),
    );

    expect(adapter.entities[key]?.payload['value'], 'local');
    expect(adapter.remoteDeletes, isEmpty);
    final shadow = store.shadow(
      session,
      entityType: CloudSyncEntityType.message,
      entityId: key.entityId,
    );
    expect(shadow?.deleted, isTrue);
    final pending = store
        .outboxForEntity(
          session,
          entityType: CloudSyncEntityType.message,
          entityId: key.entityId,
        )
        .single;
    expect(pending.operation, CloudSyncMutationOperation.restore);
    expect(pending.baseRevision, 4);
  });

  test('快照期间已尝试的 mutation 与旧 shadow 保持不可变', () async {
    final session = _session();
    final key = const SyncEntityKey(
      entityType: 'message',
      entityId: 'message-1',
    );
    final adapter = _StatefulMessageAdapter(<SyncEntityKey, LocalSyncEntity>{
      key: _localMessage(value: 'local'),
    });
    final oldShadow = _messageShadow(value: 'old');
    await store.saveShadow(session, oldShadow);
    await store.enqueueOutbox(
      session,
      CloudSyncOutboxMutation.update(
        mutationId: 'attempted-update',
        entityType: CloudSyncEntityType.message,
        entityId: key.entityId,
        baseRevision: 1,
        patch: <CloudSyncPatch>[CloudSyncPatch.replace('/value', 'local')],
      ),
    );
    final attempted = await store.markOutboxAttempted(
      session,
      mutationId: 'attempted-update',
    );
    final coordinator = CloudSyncCoordinator(
      session,
      _SnapshotThenStopTransport(<CloudSyncRecord>[
        _messageRecord(revision: 2, changeSeq: 2, value: 'remote'),
      ]),
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
      createMutationId: () => 'unused-mutation',
    );

    await expectLater(
      coordinator.synchronize(),
      throwsA(isA<_StopAfterSnapshot>()),
    );

    final retained = store
        .outboxForEntity(
          session,
          entityType: CloudSyncEntityType.message,
          entityId: key.entityId,
        )
        .single;
    expect(retained.toJson(), attempted.toJson());
    expect(adapter.entities[key]?.payload['value'], 'local');
    expect(
      store
          .shadow(
            session,
            entityType: CloudSyncEntityType.message,
            entityId: key.entityId,
          )
          ?.toJson(),
      oldShadow.toJson(),
    );
  });

  test('快照期间永久阻塞的 mutation 与旧 shadow 保持不可变', () async {
    final session = _session();
    const key = SyncEntityKey(entityType: 'message', entityId: 'message-1');
    final adapter = _StatefulMessageAdapter(<SyncEntityKey, LocalSyncEntity>{
      key: _localMessage(value: 'local'),
    });
    final oldShadow = _messageShadow(value: 'old');
    await store.saveShadow(session, oldShadow);
    await store.enqueueOutbox(
      session,
      CloudSyncOutboxMutation.update(
        mutationId: 'blocked-update',
        entityType: CloudSyncEntityType.message,
        entityId: key.entityId,
        baseRevision: 1,
        patch: <CloudSyncPatch>[CloudSyncPatch.replace('/value', 'local')],
      ),
    );
    final blocked = await store.markOutboxBlocked(
      session,
      mutationId: 'blocked-update',
      errorCode: 'SYNC_PAYLOAD_INVALID',
      blockedAt: DateTime.utc(2026, 7, 16, 9),
    );
    final coordinator = CloudSyncCoordinator(
      session,
      _SnapshotThenStopTransport(<CloudSyncRecord>[
        _messageRecord(revision: 2, changeSeq: 2, value: 'remote'),
      ]),
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
      createMutationId: () => 'unused-mutation',
    );

    await expectLater(
      coordinator.synchronize(),
      throwsA(isA<_StopAfterSnapshot>()),
    );

    final retained = store
        .outboxForEntity(
          session,
          entityType: CloudSyncEntityType.message,
          entityId: key.entityId,
        )
        .single;
    expect(retained.toJson(), blocked.toJson());
    expect(adapter.entities[key]?.payload['value'], 'local');
    expect(
      store
          .shadow(
            session,
            entityType: CloudSyncEntityType.message,
            entityId: key.entityId,
          )
          ?.toJson(),
      oldShadow.toJson(),
    );
  });

  test('快照缺席时保留本地修改并重建唯一 create', () async {
    final session = _session();
    final key = const SyncEntityKey(
      entityType: 'message',
      entityId: 'message-1',
    );
    final adapter = _StatefulMessageAdapter(<SyncEntityKey, LocalSyncEntity>{
      key: _localMessage(value: 'local'),
    });
    await store.saveShadow(session, _messageShadow(value: 'old'));
    var mutationIndex = 0;
    final coordinator = CloudSyncCoordinator(
      session,
      _SnapshotThenStopTransport(const <CloudSyncRecord>[]),
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
      createMutationId: () => 'snapshot-absence-${mutationIndex++}',
    );

    await expectLater(
      coordinator.synchronize(),
      throwsA(isA<_StopAfterSnapshot>()),
    );

    expect(adapter.entities[key]?.payload['value'], 'local');
    expect(adapter.remoteDeletes, isEmpty);
    expect(
      store.shadow(
        session,
        entityType: CloudSyncEntityType.message,
        entityId: key.entityId,
      ),
      isNull,
    );
    final pending = store
        .outboxForEntity(
          session,
          entityType: CloudSyncEntityType.message,
          entityId: key.entityId,
        )
        .single;
    expect(pending.operation, CloudSyncMutationOperation.create);
  });

  test('快照缺席时未修改的本地实体也按新同步域重建 create', () async {
    final session = _session();
    final key = const SyncEntityKey(
      entityType: 'message',
      entityId: 'message-1',
    );
    final adapter = _StatefulMessageAdapter(<SyncEntityKey, LocalSyncEntity>{
      key: _localMessage(value: 'same'),
    });
    await store.saveShadow(session, _messageShadow(value: 'same'));
    final coordinator = CloudSyncCoordinator(
      session,
      _SnapshotThenStopTransport(const <CloudSyncRecord>[]),
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
      createMutationId: () => 'unused-mutation',
    );

    await expectLater(
      coordinator.synchronize(),
      throwsA(isA<_StopAfterSnapshot>()),
    );

    expect(adapter.entities[key]?.payload['value'], 'same');
    expect(adapter.remoteDeletes, isEmpty);
    expect(
      store.shadow(
        session,
        entityType: CloudSyncEntityType.message,
        entityId: key.entityId,
      ),
      isNull,
    );
    final pending = store
        .outboxForEntity(
          session,
          entityType: CloudSyncEntityType.message,
          entityId: key.entityId,
        )
        .single;
    expect(pending.operation, CloudSyncMutationOperation.create);
  });

  test('快照缺席且本地也不存在时只清理旧 shadow', () async {
    final session = _session();
    const key = SyncEntityKey(entityType: 'message', entityId: 'message-1');
    final adapter = _StatefulMessageAdapter(
      const <SyncEntityKey, LocalSyncEntity>{},
    );
    await store.saveShadow(session, _messageShadow(value: 'old'));
    final coordinator = CloudSyncCoordinator(
      session,
      _SnapshotThenStopTransport(const <CloudSyncRecord>[]),
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
      createMutationId: () => 'snapshot-missing-local',
    );

    await expectLater(
      coordinator.synchronize(),
      throwsA(isA<_StopAfterSnapshot>()),
    );

    expect(adapter.remoteDeletes, <SyncEntityKey>[key]);
    expect(
      store.shadow(
        session,
        entityType: CloudSyncEntityType.message,
        entityId: key.entityId,
      ),
      isNull,
    );
    expect(
      store.outboxForEntity(
        session,
        entityType: CloudSyncEntityType.message,
        entityId: key.entityId,
      ),
      isEmpty,
    );
  });

  test('协调器远端应用等待同实体本地写锁释放', () async {
    final session = _session();
    const key = SyncEntityKey(entityType: 'message', entityId: 'message-1');
    final adapter = _StatefulMessageAdapter(<SyncEntityKey, LocalSyncEntity>{
      key: _localMessage(value: 'server-old'),
    });
    await store.savePullCursor(session, 'cursor-0');
    await store.saveShadow(session, _messageShadow(value: 'server-old'));
    final transport = _RemoteChangeTransport(
      _messageRecord(revision: 2, changeSeq: 2, value: 'server-current'),
    );
    final coordinator = CloudSyncCoordinator(
      session,
      transport,
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
      createMutationId: () => 'unused-mutation',
    );
    final localStarted = Completer<void>();
    final releaseLocal = Completer<void>();
    final local = writeJournal.runLocal<void>(
      key: key,
      write: () async {
        localStarted.complete();
        await releaseLocal.future;
      },
    );
    await localStarted.future;

    final synchronizing = coordinator.synchronize();
    await transport.firstChangeReturned.future;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(adapter.remoteUpserts, isEmpty);

    releaseLocal.complete();
    await local;
    final summary = await synchronizing;
    expect(summary.downloadedCount, 1);
    expect(adapter.remoteUpserts, hasLength(1));
    expect(adapter.entities[key]?.payload['value'], 'server-current');
  });

  test('字段冲突后同一轮强制采用远端 current 且不重建 outbox', () async {
    final session = _session();
    const key = SyncEntityKey(entityType: 'message', entityId: 'message-1');
    final adapter = _StatefulMessageAdapter(<SyncEntityKey, LocalSyncEntity>{
      key: _localMessage(value: 'local-desired'),
    });
    await store.savePullCursor(session, 'cursor-0');
    await store.saveShadow(session, _messageShadow(value: 'server-old'));
    var mutationIndex = 0;
    final coordinator = CloudSyncCoordinator(
      session,
      _ConflictThenSnapshotTransport(
        reason: 'field-conflict',
        snapshotRecord: _messageRecord(
          revision: 2,
          changeSeq: 2,
          value: 'server-current',
        ),
      ),
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
      createMutationId: () => 'field-conflict-${mutationIndex++}',
    );

    final summary = await coordinator.synchronize();

    expect(summary.conflictCount, 1);
    expect(adapter.entities[key]?.payload['value'], 'server-current');
    expect(
      store
          .shadow(
            session,
            entityType: CloudSyncEntityType.message,
            entityId: key.entityId,
          )
          ?.payload?['value'],
      'server-current',
    );
    expect(
      store.outboxForEntity(
        session,
        entityType: CloudSyncEntityType.message,
        entityId: key.entityId,
      ),
      isEmpty,
    );
  });

  test('结构冲突后保留本地 desired 并按远端 current 重规划', () async {
    final session = _session();
    const key = SyncEntityKey(entityType: 'message', entityId: 'message-1');
    final adapter = _StatefulMessageAdapter(<SyncEntityKey, LocalSyncEntity>{
      key: _localMessage(value: 'local-desired'),
    });
    await store.savePullCursor(session, 'cursor-0');
    await store.saveShadow(session, _messageShadow(value: 'server-old'));
    var mutationIndex = 0;
    final coordinator = CloudSyncCoordinator(
      session,
      _ConflictThenSnapshotTransport(
        reason: 'revision-mismatch',
        snapshotRecord: _messageRecord(
          revision: 2,
          changeSeq: 2,
          value: 'server-current',
        ),
      ),
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
      createMutationId: () => 'structural-conflict-${mutationIndex++}',
    );

    final summary = await coordinator.synchronize();

    expect(summary.conflictCount, 1);
    expect(adapter.entities[key]?.payload['value'], 'local-desired');
    final pending = store
        .outboxForEntity(
          session,
          entityType: CloudSyncEntityType.message,
          entityId: key.entityId,
        )
        .single;
    expect(pending.operation, CloudSyncMutationOperation.update);
    expect(pending.baseRevision, 2);
  });
}

final class _StopAfterSnapshot implements Exception {}

final class _SnapshotThenStopTransport implements CloudSyncTransport {
  _SnapshotThenStopTransport(this.records);

  final List<CloudSyncRecord> records;

  @override
  Future<CloudSyncPullResult> pull({String? cursor, int limit = 100}) {
    throw _StopAfterSnapshot();
  }

  @override
  Future<List<CloudSyncMutationResult>> push(
    List<CloudSyncOutboxMutation> mutations,
  ) {
    throw StateError('测试应在 push 前停止');
  }

  @override
  Future<CloudSyncSnapshotResult> snapshot({
    String? snapshotCursor,
    int limit = 100,
  }) async {
    return CloudSyncSnapshotResult(
      records: records,
      nextSnapshotCursor: null,
      syncCursor: 'snapshot-cursor',
      hasMore: false,
    );
  }
}

final class _ConflictThenSnapshotTransport implements CloudSyncTransport {
  _ConflictThenSnapshotTransport({
    required this.reason,
    required this.snapshotRecord,
  });

  final String reason;
  final CloudSyncRecord snapshotRecord;

  @override
  Future<CloudSyncPullResult> pull({String? cursor, int limit = 100}) async {
    return const CloudSyncPullResult(
      changes: <CloudSyncChange>[],
      nextCursor: 'cursor-after-conflict',
      hasMore: false,
      resetRequired: false,
    );
  }

  @override
  Future<List<CloudSyncMutationResult>> push(
    List<CloudSyncOutboxMutation> mutations,
  ) async {
    return mutations
        .map(
          (mutation) => CloudSyncMutationResult(
            mutationId: mutation.mutationId,
            status: CloudSyncMutationStatus.conflict,
            retryable: false,
            currentRevision: snapshotRecord.revision,
            reason: reason,
            conflictId: reason == 'field-conflict' ? 'conflict-1' : null,
            conflictingPaths: reason == 'field-conflict'
                ? const <String>['/value']
                : const <String>[],
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<CloudSyncSnapshotResult> snapshot({
    String? snapshotCursor,
    int limit = 100,
  }) async {
    return CloudSyncSnapshotResult(
      records: <CloudSyncRecord>[snapshotRecord],
      nextSnapshotCursor: null,
      syncCursor: 'snapshot-after-conflict',
      hasMore: false,
    );
  }
}

final class _RemoteChangeTransport implements CloudSyncTransport {
  _RemoteChangeTransport(this.record);

  final CloudSyncRecord record;
  final Completer<void> firstChangeReturned = Completer<void>();
  var _pullCount = 0;

  @override
  Future<CloudSyncPullResult> pull({String? cursor, int limit = 100}) async {
    if (_pullCount++ == 0) {
      firstChangeReturned.complete();
      return CloudSyncPullResult(
        changes: <CloudSyncChange>[
          CloudSyncChange.upsert(
            changeSeq: record.lastChangeSeq,
            record: record,
          ),
        ],
        nextCursor: 'cursor-after-change',
        hasMore: false,
        resetRequired: false,
      );
    }
    return const CloudSyncPullResult(
      changes: <CloudSyncChange>[],
      nextCursor: 'cursor-after-change',
      hasMore: false,
      resetRequired: false,
    );
  }

  @override
  Future<List<CloudSyncMutationResult>> push(
    List<CloudSyncOutboxMutation> mutations,
  ) async {
    throw StateError('无本地变化时不应 push');
  }

  @override
  Future<CloudSyncSnapshotResult> snapshot({
    String? snapshotCursor,
    int limit = 100,
  }) {
    throw StateError('已有游标时不应 snapshot');
  }
}

final class _StatefulMessageAdapter implements SyncEntityAdapter {
  _StatefulMessageAdapter(Map<SyncEntityKey, LocalSyncEntity> entities)
    : entities = Map<SyncEntityKey, LocalSyncEntity>.from(entities);

  final Map<SyncEntityKey, LocalSyncEntity> entities;
  final List<RemoteSyncEntity> remoteUpserts = <RemoteSyncEntity>[];
  final List<SyncEntityKey> remoteDeletes = <SyncEntityKey>[];

  @override
  int get applyPriority => 0;

  @override
  Set<String> get entityTypes => const <String>{'message'};

  @override
  Future<LocalSyncEntity?> exportLocalEntity(SyncEntityKey key) async {
    return entities[key];
  }

  @override
  Future<Map<SyncEntityKey, LocalSyncEntity>> exportLocalEntitiesForKeys(
    Set<SyncEntityKey> keys,
  ) async {
    return <SyncEntityKey, LocalSyncEntity>{
      for (final key in keys)
        if (entities[key] case final LocalSyncEntity entity) key: entity,
    };
  }

  @override
  Future<List<LocalSyncEntity>> exportLocalEntities() async {
    return List<LocalSyncEntity>.unmodifiable(entities.values);
  }

  @override
  Future<void> applyRemoteDelete(SyncEntityKey key) async {
    remoteDeletes.add(key);
    entities.remove(key);
  }

  @override
  Future<void> applyRemoteUpsert(RemoteSyncEntity entity) async {
    remoteUpserts.add(entity);
    entities[entity.key] = LocalSyncEntity(
      entityType: entity.entityType,
      entityId: entity.entityId,
      parentId: entity.parentId,
      schemaVersion: entity.schemaVersion,
      payload: entity.payload,
    );
  }
}

final class _RejectingTransport implements CloudSyncTransport {
  final List<String> pushedMutationIds = <String>[];

  @override
  Future<List<CloudSyncMutationResult>> push(
    List<CloudSyncOutboxMutation> mutations,
  ) async {
    pushedMutationIds.addAll(mutations.map((mutation) => mutation.mutationId));
    return mutations
        .map(
          (mutation) => CloudSyncMutationResult(
            mutationId: mutation.mutationId,
            status: CloudSyncMutationStatus.rejected,
            retryable: false,
            errorCode: 'SYNC_PAYLOAD_INVALID',
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<CloudSyncPullResult> pull({String? cursor, int limit = 100}) async {
    return const CloudSyncPullResult(
      changes: <CloudSyncChange>[],
      nextCursor: 'cursor-1',
      hasMore: false,
      resetRequired: false,
    );
  }

  @override
  Future<CloudSyncSnapshotResult> snapshot({
    String? snapshotCursor,
    int limit = 100,
  }) {
    throw StateError('已有游标时不应请求全量快照');
  }
}

final class _MessageAdapter implements SyncEntityAdapter {
  @override
  int get applyPriority => 0;

  @override
  Set<String> get entityTypes => const <String>{'message'};

  @override
  Future<LocalSyncEntity?> exportLocalEntity(SyncEntityKey key) async {
    return (await exportLocalEntities()).singleWhere(
      (entity) => entity.key == key,
    );
  }

  @override
  Future<Map<SyncEntityKey, LocalSyncEntity>> exportLocalEntitiesForKeys(
    Set<SyncEntityKey> keys,
  ) async {
    final entities = await exportLocalEntities();
    return <SyncEntityKey, LocalSyncEntity>{
      for (final entity in entities)
        if (keys.contains(entity.key)) entity.key: entity,
    };
  }

  @override
  Future<List<LocalSyncEntity>> exportLocalEntities() async {
    return <LocalSyncEntity>[
      LocalSyncEntity(
        entityType: 'message',
        entityId: 'message-1',
        parentId: 'turn-1',
        payload: const <String, Object?>{
          'conversationId': 'conversation-1',
          'turnId': 'turn-1',
        },
      ),
    ];
  }

  @override
  Future<void> applyRemoteDelete(SyncEntityKey key) async {}

  @override
  Future<void> applyRemoteUpsert(RemoteSyncEntity entity) async {}
}

LocalSyncEntity _localMessage({required String value}) {
  return LocalSyncEntity(
    entityType: 'message',
    entityId: 'message-1',
    parentId: 'turn-1',
    payload: <String, Object?>{
      'conversationId': 'conversation-1',
      'turnId': 'turn-1',
      'value': value,
    },
  );
}

CloudSyncRecord _messageRecord({
  required int revision,
  required int changeSeq,
  required String value,
  DateTime? deletedAt,
}) {
  return CloudSyncRecord(
    entityType: CloudSyncEntityType.message,
    entityId: 'message-1',
    parentId: 'turn-1',
    revision: revision,
    schemaVersion: 2,
    sortSeq: null,
    payload: <String, Object?>{
      'conversationId': 'conversation-1',
      'turnId': 'turn-1',
      'value': value,
    },
    deletedAt: deletedAt,
    updatedAt: DateTime.utc(2026, 7, 16, 8),
    updatedByDeviceId: 'remote-device',
    lastChangeSeq: changeSeq,
  );
}

CloudSyncShadow _messageShadow({required String value}) {
  return CloudSyncShadow(
    entityType: CloudSyncEntityType.message,
    entityId: 'message-1',
    parentId: 'turn-1',
    revision: 1,
    schemaVersion: 2,
    lastChangeSeq: 1,
    deleted: false,
    payload: <String, Object?>{
      'conversationId': 'conversation-1',
      'turnId': 'turn-1',
      'value': value,
    },
    updatedAt: DateTime.utc(2026, 7, 16, 7),
  );
}

CloudSyncAccountSession _session() {
  return CloudSyncAccountSession(
    baseUrl: 'https://sync.example.com',
    token: 'token',
    userId: 'user-1',
    loginName: 'user',
    displayName: 'User',
    role: CloudSyncUserRole.user,
    attachmentQuotaBytes: maximumCloudSyncAttachmentSizeBytes,
    deviceId: 'device-1',
    deviceName: 'Device',
    platform: CloudSyncPlatform.android,
    clientVersion: '2.0.0',
    deviceCreatedAt: DateTime.utc(2026, 7, 16),
  );
}
