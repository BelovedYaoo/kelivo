import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:Kelivo/core/services/sync/cloud_sync_client.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_conflict_resolver.dart';
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

  test('稳态同步不再全量导出本地实体', () async {
    final session = _session();
    await store.savePullCursor(session, 'cursor-0');
    final adapter = _CountingAdapter(
      entityType: 'message',
      entityId: 'message-1',
    );
    final transport = _ApplyingTransport();
    final coordinator = CloudSyncCoordinator(
      session,
      transport,
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
    );

    await coordinator.synchronize();

    expect(adapter.fullExportCount, 0);
    expect(transport.pushedEntityTypes, isEmpty);
  });

  test('首次同步批量查询实体时保留全部非就绪 outbox', () async {
    final session = _session();
    final entities = <SyncEntityKey, LocalSyncEntity>{};
    for (var index = 0; index < 40; index++) {
      final key = SyncEntityKey(
        entityType: 'message',
        entityId: 'message-$index',
      );
      final entity = LocalSyncEntity(
        entityType: key.entityType,
        entityId: key.entityId,
        parentId: 'turn-$index',
        payload: <String, Object?>{
          'conversationId': 'conversation-$index',
          'turnId': 'turn-$index',
        },
      );
      entities[key] = entity;
      await store.enqueueOutbox(
        session,
        CloudSyncOutboxMutation.create(
          mutationId: 'mutation-$index',
          entityType: CloudSyncEntityType.message,
          entityId: entity.entityId,
          parentId: entity.parentId,
          schemaVersion: 2,
          payload: entity.payload,
        ),
        merge: false,
      );
      if (index.isEven) {
        await store.markOutboxBlocked(
          session,
          mutationId: 'mutation-$index',
          errorCode: 'SYNC_PAYLOAD_INVALID',
        );
      } else {
        await store.markOutboxAttempted(session, mutationId: 'mutation-$index');
        await store.markOutboxRetry(
          session,
          mutationId: 'mutation-$index',
          nextAttemptAt: DateTime.utc(2099),
        );
      }
    }
    final coordinator = CloudSyncCoordinator(
      session,
      _EmptyInitialTransport(),
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[_StatefulMessageAdapter(entities)],
    );

    await coordinator.synchronize();

    expect(store.outboxCount(session), 40);
  });

  test('导入重扫只导出指定配置域并在拉取后推送', () async {
    final session = _session();
    await store.savePullCursor(session, 'cursor-0');
    final configAdapter = _CountingAdapter(
      entityType: 'assistant',
      entityId: 'assistant-1',
    );
    final chatAdapter = _CountingAdapter(
      entityType: 'message',
      entityId: 'message-1',
    );
    final transport = _ApplyingTransport();
    final coordinator = CloudSyncCoordinator(
      session,
      transport,
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[configAdapter, chatAdapter],
    );

    await coordinator.synchronize(
      rescanEntityTypes: const <String>{'assistant'},
    );

    expect(configAdapter.fullExportCount, 1);
    expect(chatAdapter.fullExportCount, 0);
    expect(transport.pushedEntityTypes, <String>['assistant']);
    expect(
      transport.events.indexOf('pull'),
      lessThan(transport.events.indexOf('push')),
    );
  });

  test('导入重扫拒绝未注册的实体类型且不发起网络请求', () async {
    final session = _session();
    await store.savePullCursor(session, 'cursor-0');
    final transport = _ApplyingTransport();
    final coordinator = CloudSyncCoordinator(
      session,
      transport,
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[
        _CountingAdapter(entityType: 'assistant', entityId: 'assistant-1'),
      ],
    );

    expect(
      () => coordinator.synchronize(
        rescanEntityTypes: const <String>{'unknown-entity'},
      ),
      throwsA(isA<StateError>()),
    );

    expect(transport.events, isEmpty);
  });

  test('首次同步的本地权威空集合会删除远端孤儿项', () async {
    final session = _session();
    const key = SyncEntityKey(entityType: 'message', entityId: 'message-1');
    final adapter = _StatefulMessageAdapter(
      const <SyncEntityKey, LocalSyncEntity>{},
    );
    final transport = _AuthoritativeSnapshotTransport(
      _messageRecord(revision: 7, changeSeq: 11, value: 'remote-only'),
    );
    final coordinator = CloudSyncCoordinator(
      session,
      transport,
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
      createMutationId: () => 'authoritative-delete',
    );

    final summary = await coordinator.synchronize(
      rescanEntityTypes: const <String>{'message'},
      localAuthoritativeEntityTypes: const <String>{'message'},
    );

    expect(adapter.remoteUpserts, isEmpty);
    expect(adapter.entities, isEmpty);
    final mutation = transport.pushedMutations.single;
    expect(mutation.operation, CloudSyncMutationOperation.delete);
    expect(mutation.entityType, CloudSyncEntityType.message);
    expect(mutation.entityId, key.entityId);
    expect(mutation.baseRevision, 7);
    expect(transport.hasLiveRecord, isFalse);
    expect(summary.uploadedCount, 1);
    expect(
      store
          .shadow(
            session,
            entityType: CloudSyncEntityType.message,
            entityId: key.entityId,
          )
          ?.deleted,
      isTrue,
    );
  });

  test('本地权威空集合会删除快照游标后新增的远端实体', () async {
    final session = _session();
    const key = SyncEntityKey(entityType: 'message', entityId: 'message-1');
    final adapter = _StatefulMessageAdapter(
      const <SyncEntityKey, LocalSyncEntity>{},
    );
    final transport = _AuthoritativeDeltaTransport(
      snapshotRecords: const <CloudSyncRecord>[],
      deltaRecord: _messageRecord(
        revision: 1,
        changeSeq: 1,
        value: 'remote-after-snapshot',
      ),
    );
    final coordinator = CloudSyncCoordinator(
      session,
      transport,
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
      createMutationId: () => 'authoritative-delta-delete',
    );

    await coordinator.synchronize(
      rescanEntityTypes: const <String>{'message'},
      localAuthoritativeEntityTypes: const <String>{'message'},
    );

    expect(adapter.remoteUpserts, isEmpty);
    expect(adapter.entities, isEmpty);
    final mutation = transport.pushedMutations.single;
    expect(mutation.operation, CloudSyncMutationOperation.delete);
    expect(mutation.entityId, key.entityId);
    expect(mutation.baseRevision, 1);
    expect(transport.hasLiveRecord, isFalse);
    expect(store.cursorState(session).pullCursor, 'authoritative-delta-cursor');
  });

  test('本地权威实体会覆盖快照游标后的远端更新', () async {
    final session = _session();
    const key = SyncEntityKey(entityType: 'message', entityId: 'message-1');
    final local = _localMessage(value: 'local-before-snapshot');
    final adapter = _StatefulMessageAdapter(<SyncEntityKey, LocalSyncEntity>{
      key: local,
    });
    final transport = _AuthoritativeDeltaTransport(
      snapshotRecords: <CloudSyncRecord>[
        _messageRecord(
          revision: 1,
          changeSeq: 1,
          value: 'local-before-snapshot',
        ),
      ],
      deltaRecord: _messageRecord(
        revision: 2,
        changeSeq: 2,
        value: 'remote-after-snapshot',
      ),
    );
    final coordinator = CloudSyncCoordinator(
      session,
      transport,
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
      createMutationId: () => 'authoritative-delta-update',
    );

    await coordinator.synchronize(
      rescanEntityTypes: const <String>{'message'},
      localAuthoritativeEntityTypes: const <String>{'message'},
    );

    expect(adapter.remoteUpserts, isEmpty);
    expect(adapter.entities[key]?.payload['value'], 'local-before-snapshot');
    final mutation = transport.pushedMutations.single;
    expect(mutation.operation, CloudSyncMutationOperation.update);
    expect(mutation.baseRevision, 2);
    expect(mutation.patch, hasLength(1));
    expect(mutation.patch.single.path, '/value');
    expect(mutation.patch.single.value, 'local-before-snapshot');
    expect(store.cursorState(session).pullCursor, 'authoritative-delta-cursor');
  });

  test('新权威请求会放弃旧的半截快照并从第一页重新比较', () async {
    final session = _session();
    final record = _messageRecord(
      revision: 7,
      changeSeq: 11,
      value: 'remote-only',
    );
    await store.saveShadow(session, _messageShadow(value: 'remote-old'));
    await store.beginSnapshot(session);
    await store.markSnapshotRecordsSeen(session, <CloudSyncRecord>[record]);
    await store.saveSnapshotProgress(
      session,
      snapshotCursor: 'stale-next-page',
      syncCursor: 'stale-sync-cursor',
    );
    final transport = _RestartingAuthoritativeSnapshotTransport(record);
    final coordinator = CloudSyncCoordinator(
      session,
      transport,
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[
        _StatefulMessageAdapter(const <SyncEntityKey, LocalSyncEntity>{}),
      ],
      createMutationId: () => 'restarted-authoritative-delete',
    );

    await coordinator.synchronize(
      rescanEntityTypes: const <String>{'message'},
      localAuthoritativeEntityTypes: const <String>{'message'},
    );

    expect(transport.snapshotCursors, <String?>[null]);
    final mutation = transport.pushedMutations.single;
    expect(mutation.operation, CloudSyncMutationOperation.delete);
    expect(mutation.entityId, record.entityId);
    expect(mutation.baseRevision, record.revision);
  });

  test('普通重扫保持增量语义并接纳仅存在于远端的实体', () async {
    final session = _session();
    const key = SyncEntityKey(entityType: 'message', entityId: 'message-1');
    await store.savePullCursor(session, 'cursor-0');
    await store.saveShadow(session, _messageShadow(value: 'remote-old'));
    final adapter = _StatefulMessageAdapter(
      const <SyncEntityKey, LocalSyncEntity>{},
    );
    final transport = _IncrementalRemoteTransport(
      _messageRecord(revision: 2, changeSeq: 2, value: 'remote-current'),
    );
    final coordinator = CloudSyncCoordinator(
      session,
      transport,
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
      createMutationId: () => 'ordinary-rescan-delete',
    );

    await coordinator.synchronize(rescanEntityTypes: const <String>{'message'});

    expect(transport.pushedMutations, isEmpty);
    expect(adapter.remoteUpserts, hasLength(1));
    expect(adapter.entities[key]?.payload['value'], 'remote-current');
  });

  test('普通重扫遇游标重置时不会把本地缺失解释为远端删除', () async {
    final session = _session();
    const key = SyncEntityKey(entityType: 'message', entityId: 'message-1');
    await store.savePullCursor(session, 'cursor-0');
    await store.saveShadow(session, _messageShadow(value: 'remote-old'));
    final adapter = _StatefulMessageAdapter(
      const <SyncEntityKey, LocalSyncEntity>{},
    );
    final transport = _ResetRequiredSnapshotTransport(
      _messageRecord(revision: 2, changeSeq: 2, value: 'remote-current'),
    );
    final coordinator = CloudSyncCoordinator(
      session,
      transport,
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
      createMutationId: () => 'ordinary-reset-delete',
    );

    await coordinator.synchronize(rescanEntityTypes: const <String>{'message'});

    expect(transport.pushedMutations, isEmpty);
    expect(adapter.remoteUpserts, hasLength(1));
    expect(adapter.entities[key]?.payload['value'], 'remote-current');
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

  test('本地权威实体面对远端墓碑时会连续完成恢复与内容更新', () async {
    final session = _session();
    const key = SyncEntityKey(entityType: 'message', entityId: 'message-1');
    final adapter = _StatefulMessageAdapter(<SyncEntityKey, LocalSyncEntity>{
      key: _localMessage(value: 'local-authoritative'),
    });
    final transport = _AuthoritativeSnapshotTransport(
      _messageRecord(
        revision: 4,
        changeSeq: 8,
        value: 'remote-tombstone',
        deletedAt: DateTime.utc(2026, 7, 16, 9),
      ),
    );
    var mutationIndex = 0;
    final coordinator = CloudSyncCoordinator(
      session,
      transport,
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
      createMutationId: () => 'authoritative-tombstone-${mutationIndex++}',
    );

    final summary = await coordinator.synchronize(
      rescanEntityTypes: const <String>{'message'},
      localAuthoritativeEntityTypes: const <String>{'message'},
    );

    expect(
      transport.pushedMutations.map((mutation) => mutation.operation),
      <CloudSyncMutationOperation>[
        CloudSyncMutationOperation.restore,
        CloudSyncMutationOperation.update,
      ],
    );
    expect(transport.pushedMutations.first.baseRevision, 4);
    expect(transport.pushedMutations.last.baseRevision, 5);
    expect(summary.uploadedCount, 2);
    final shadow = store.shadow(
      session,
      entityType: CloudSyncEntityType.message,
      entityId: key.entityId,
    );
    expect(shadow?.deleted, isFalse);
    expect(shadow?.payload?['value'], 'local-authoritative');
    expect(
      store.outboxForEntity(
        session,
        entityType: CloudSyncEntityType.message,
        entityId: key.entityId,
      ),
      isEmpty,
    );
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

    expect(adapter.remoteBatchCount, 1);
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
    expect(adapter.remoteBatchCount, 1);
    expect(adapter.remoteUpserts, hasLength(1));
    expect(adapter.entities[key]?.payload['value'], 'server-current');
  });

  test('远端批次回滚时不提前推进 shadow 与拉取游标', () async {
    final session = _session();
    const firstKey = SyncEntityKey(
      entityType: 'message',
      entityId: 'message-1',
    );
    const secondKey = SyncEntityKey(
      entityType: 'message',
      entityId: 'message-2',
    );
    final adapter = _RollbackMessageAdapter(failOnEntityId: secondKey.entityId);
    await store.savePullCursor(session, 'cursor-0');
    final transport = _RemoteChangePageTransport(<CloudSyncRecord>[
      _messageRecord(revision: 2, changeSeq: 2, value: 'first'),
      _messageRecord(
        entityId: secondKey.entityId,
        turnId: 'turn-2',
        revision: 2,
        changeSeq: 3,
        value: 'second',
      ),
    ]);
    final coordinator = CloudSyncCoordinator(
      session,
      transport,
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
    );

    await expectLater(coordinator.synchronize(), throwsStateError);

    expect(adapter.entities, isEmpty);
    expect(
      store.shadow(
        session,
        entityType: CloudSyncEntityType.message,
        entityId: firstKey.entityId,
      ),
      isNull,
    );
    expect(
      store.shadow(
        session,
        entityType: CloudSyncEntityType.message,
        entityId: secondKey.entityId,
      ),
      isNull,
    );
    expect(store.cursorState(session).pullCursor, 'cursor-0');

    adapter.failOnEntityId = null;
    final summary = await coordinator.synchronize();

    expect(summary.downloadedCount, 2);
    expect(
      adapter.entities.keys,
      containsAll(<SyncEntityKey>[firstKey, secondKey]),
    );
    expect(
      store
          .shadow(
            session,
            entityType: CloudSyncEntityType.message,
            entityId: firstKey.entityId,
          )
          ?.lastChangeSeq,
      2,
    );
    expect(
      store
          .shadow(
            session,
            entityType: CloudSyncEntityType.message,
            entityId: secondKey.entityId,
          )
          ?.lastChangeSeq,
      3,
    );
    expect(store.cursorState(session).pullCursor, 'cursor-after-page');
  });

  test('远端事务跨越全部拉取分页并在最后一页后提交', () async {
    final session = _session();
    await store.savePullCursor(session, 'cursor-0');
    final adapter = _TransactionalMessageAdapter();
    final coordinator = CloudSyncCoordinator(
      session,
      _TwoPageRemoteChangeTransport(
        first: _messageRecord(revision: 2, changeSeq: 2, value: 'first'),
        second: _messageRecord(
          entityId: 'message-2',
          turnId: 'turn-2',
          revision: 2,
          changeSeq: 3,
          value: 'second',
        ),
      ),
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
    );

    final summary = await coordinator.synchronize();

    expect(summary.downloadedCount, 2);
    expect(adapter.events, <String>[
      'transaction-start',
      'apply:message-1',
      'apply:message-2',
      'transaction-commit',
      'transaction-start',
    ]);
    expect(adapter.transactionCommitCount, 1);
    expect(adapter.transactionDiscardCount, 0);
    expect(store.cursorState(session).pullCursor, 'cursor-final');
  });

  test('后续拉取分页失败会丢弃完整事务且不推进前页 shadow 与游标', () async {
    final session = _session();
    await store.savePullCursor(session, 'cursor-0');
    final adapter = _TransactionalMessageAdapter(failOnEntityId: 'message-2');
    final coordinator = CloudSyncCoordinator(
      session,
      _TwoPageRemoteChangeTransport(
        first: _messageRecord(revision: 2, changeSeq: 2, value: 'first'),
        second: _messageRecord(
          entityId: 'message-2',
          turnId: 'turn-2',
          revision: 2,
          changeSeq: 3,
          value: 'second',
        ),
      ),
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
    );

    await expectLater(coordinator.synchronize(), throwsStateError);

    expect(adapter.transactionCommitCount, 0);
    expect(adapter.transactionDiscardCount, 1);
    expect(
      store.shadow(
        session,
        entityType: CloudSyncEntityType.message,
        entityId: 'message-1',
      ),
      isNull,
    );
    expect(store.cursorState(session).pullCursor, 'cursor-0');
  });

  test('远端事务只延迟声明键且非事务页可从旧游标幂等重放', () async {
    final session = _session();
    await store.savePullCursor(session, 'cursor-0');
    final adapter = _TransactionalMessageAdapter(
      failOnEntityId: 'message-2',
      remoteTransactionKeys: <SyncEntityKey>{
        const SyncEntityKey(entityType: 'message', entityId: 'message-2'),
      },
    );
    final coordinator = CloudSyncCoordinator(
      session,
      _TwoPageRemoteChangeTransport(
        first: _messageRecord(revision: 2, changeSeq: 2, value: 'first'),
        second: _messageRecord(
          entityId: 'message-2',
          turnId: 'turn-2',
          revision: 2,
          changeSeq: 3,
          value: 'second',
        ),
      ),
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
    );

    await expectLater(coordinator.synchronize(), throwsStateError);

    expect(
      store
          .shadow(
            session,
            entityType: CloudSyncEntityType.message,
            entityId: 'message-1',
          )
          ?.lastChangeSeq,
      2,
    );
    expect(store.cursorState(session).pullCursor, 'cursor-0');

    adapter.failOnEntityId = null;
    final summary = await coordinator.synchronize();

    expect(summary.downloadedCount, 1);
    expect(adapter.transactionDiscardCount, 1);
    expect(adapter.transactionCommitCount, 1);
    expect(
      store
          .shadow(
            session,
            entityType: CloudSyncEntityType.message,
            entityId: 'message-2',
          )
          ?.lastChangeSeq,
      3,
    );
    expect(store.cursorState(session).pullCursor, 'cursor-final');
  });

  test('远端事务跨越全部快照分页并在完成游标前提交', () async {
    final session = _session();
    final adapter = _TransactionalMessageAdapter();
    final transport = _TwoPageSnapshotTransport(
      first: _messageRecord(revision: 2, changeSeq: 2, value: 'first'),
      second: _messageRecord(
        entityId: 'message-2',
        turnId: 'turn-2',
        revision: 2,
        changeSeq: 3,
        value: 'second',
      ),
    );
    final coordinator = CloudSyncCoordinator(
      session,
      transport,
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
    );

    await expectLater(
      coordinator.synchronize(),
      throwsA(isA<_StopAfterSnapshot>()),
    );

    expect(transport.snapshotCursors, <String?>[null, 'snapshot-page-2']);
    expect(adapter.events.take(4), <String>[
      'transaction-start',
      'apply:message-1',
      'apply:message-2',
      'transaction-commit',
    ]);
    expect(adapter.transactionCommitCount, 1);
    expect(store.cursorState(session).pullCursor, 'snapshot-final');
  });

  test('远端资源准备与提交分别发生在数据库批次前后', () async {
    final session = _session();
    await store.savePullCursor(session, 'cursor-0');
    final adapter = _PreparingMessageAdapter();
    final coordinator = CloudSyncCoordinator(
      session,
      _RemoteChangePageTransport(<CloudSyncRecord>[
        _messageRecord(revision: 2, changeSeq: 2, value: 'remote'),
      ]),
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
    );

    await coordinator.synchronize();

    expect(adapter.events, <String>[
      'prepare',
      'batch-start',
      'apply',
      'batch-end',
      'commit',
    ]);
  });

  test('数据库批次失败会丢弃已准备的远端资源', () async {
    final session = _session();
    await store.savePullCursor(session, 'cursor-0');
    final stagingFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}remote-message.part',
    );
    final adapter = _PreparingMessageAdapter(
      stagingFile: stagingFile,
      failApply: true,
    );
    final coordinator = CloudSyncCoordinator(
      session,
      _RemoteChangePageTransport(<CloudSyncRecord>[
        _messageRecord(revision: 2, changeSeq: 2, value: 'remote'),
      ]),
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
    );

    await expectLater(coordinator.synchronize(), throwsStateError);

    expect(await stagingFile.exists(), isFalse);
    expect(adapter.events, <String>[
      'prepare',
      'batch-start',
      'apply',
      'batch-end',
      'discard',
    ]);
  });

  test('远端资源提交失败时不推进 shadow 与拉取游标', () async {
    final session = _session();
    await store.savePullCursor(session, 'cursor-0');
    final adapter = _PreparingMessageAdapter(failCommit: true);
    final coordinator = CloudSyncCoordinator(
      session,
      _RemoteChangePageTransport(<CloudSyncRecord>[
        _messageRecord(revision: 2, changeSeq: 2, value: 'remote'),
      ]),
      store,
      writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
    );

    await expectLater(coordinator.synchronize(), throwsStateError);

    expect(
      store.shadow(
        session,
        entityType: CloudSyncEntityType.message,
        entityId: 'message-1',
      ),
      isNull,
    );
    expect(store.cursorState(session).pullCursor, 'cursor-0');
    expect(adapter.events, <String>[
      'prepare',
      'batch-start',
      'apply',
      'batch-end',
      'commit',
      'discard',
    ]);
  });

  test('字段冲突后同一轮强制采用远端 current 且不重建 outbox', () async {
    final session = _session();
    const key = SyncEntityKey(entityType: 'message', entityId: 'message-1');
    final adapter = _StatefulMessageAdapter(<SyncEntityKey, LocalSyncEntity>{
      key: _localMessage(value: 'local-desired'),
    });
    await store.savePullCursor(session, 'cursor-0');
    await store.saveShadow(session, _messageShadow(value: 'server-old'));
    await store.enqueueOutbox(
      session,
      CloudSyncOutboxMutation.update(
        mutationId: 'field-conflict-source',
        entityType: CloudSyncEntityType.message,
        entityId: key.entityId,
        baseRevision: 1,
        patch: <CloudSyncPatch>[
          CloudSyncPatch.replace('/value', 'local-desired'),
        ],
      ),
    );
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

  test('本地权威字段冲突保留本地修改且不准备远端资源', () async {
    final session = _session();
    const key = SyncEntityKey(entityType: 'message', entityId: 'message-1');
    final local = _localMessage(value: 'local-authoritative');
    final adapter = _PreparingMessageAdapter(localEntity: local);
    await store.savePullCursor(session, 'cursor-0');
    await store.saveShadow(session, _messageShadow(value: 'server-old'));
    await store.enqueueOutbox(
      session,
      CloudSyncOutboxMutation.update(
        mutationId: 'authoritative-field-conflict-source',
        entityType: CloudSyncEntityType.message,
        entityId: key.entityId,
        baseRevision: 1,
        patch: <CloudSyncPatch>[
          CloudSyncPatch.replace('/value', 'local-authoritative'),
        ],
      ),
    );
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
      createMutationId: () => 'authoritative-field-${mutationIndex++}',
    );

    final summary = await coordinator.synchronize(
      rescanEntityTypes: const <String>{'message'},
      localAuthoritativeEntityTypes: const <String>{'message'},
    );

    expect(summary.conflictCount, 1);
    expect(adapter.events, isNot(contains('prepare')));
    expect(adapter.events, isNot(contains('apply')));
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

  test('结构冲突后保留本地 desired 并按远端 current 重规划', () async {
    final session = _session();
    const key = SyncEntityKey(entityType: 'message', entityId: 'message-1');
    final adapter = _StatefulMessageAdapter(<SyncEntityKey, LocalSyncEntity>{
      key: _localMessage(value: 'local-desired'),
    });
    await store.savePullCursor(session, 'cursor-0');
    await store.saveShadow(session, _messageShadow(value: 'server-old'));
    await store.enqueueOutbox(
      session,
      CloudSyncOutboxMutation.update(
        mutationId: 'structural-conflict-source',
        entityType: CloudSyncEntityType.message,
        entityId: key.entityId,
        baseRevision: 1,
        patch: <CloudSyncPatch>[
          CloudSyncPatch.replace('/value', 'local-desired'),
        ],
      ),
    );
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

  test('字段冲突混合选择只写回所选本地值并最后解决', () async {
    final session = _session();
    const key = SyncEntityKey(entityType: 'message', entityId: 'message-1');
    final initialPayload = <String, Object?>{
      'title': '云端标题',
      'summary': '云端摘要',
      'nullable': '云端值',
      'removeMe': '云端值',
    };
    await store.saveShadow(session, _conflictShadow(initialPayload));
    final events = <String>[];
    final adapter = _StatefulMessageAdapter(<SyncEntityKey, LocalSyncEntity>{
      key: LocalSyncEntity(
        entityType: key.entityType,
        entityId: key.entityId,
        payload: initialPayload,
      ),
    }, events: events);
    final conflict = _fieldConflict();
    final transport = _ConflictTransport(
      events: events,
      listResponses: <List<CloudSyncConflict>>[
        <CloudSyncConflict>[conflict],
        <CloudSyncConflict>[conflict],
      ],
      resolveResult: _resolvedConflict(conflict),
    );
    _bindCompletedExporter(writeJournal);
    var syncCount = 0;
    final resolver = CloudSyncConflictResolver(
      session: session,
      client: transport,
      store: store,
      writeJournal: writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
      synchronize: () async {
        events.add('sync');
        syncCount++;
        if (syncCount == 2) {
          await store.saveShadow(
            session,
            _conflictShadow(adapter.entities[key]!.payload, revision: 2),
          );
        }
      },
    );

    final resolved = await resolver.resolve(conflict, const <String>{
      '/title',
      '/nullable',
      '/removeMe',
    });

    expect(resolved.state, CloudSyncConflictState.resolved);
    expect(adapter.entities[key]!.payload, <String, Object?>{
      'title': '本地标题',
      'summary': '云端摘要',
      'nullable': null,
    });
    expect(events, <String>[
      'sync',
      'list',
      'apply',
      'sync',
      'list',
      'resolve',
    ]);
  });

  test('字段冲突全选云端不改本地并直接解决', () async {
    final conflict = _fieldConflict();
    final events = <String>[];
    final transport = _ConflictTransport(
      events: events,
      listResponses: const <List<CloudSyncConflict>>[],
      resolveResult: _resolvedConflict(conflict),
    );
    final resolver = CloudSyncConflictResolver(
      session: _session(),
      client: transport,
      store: store,
      writeJournal: writeJournal,
      adapters: const <SyncEntityAdapter>[],
      synchronize: () async => events.add('sync'),
    );

    final resolved = await resolver.resolve(conflict, const <String>{});

    expect(resolved.state, CloudSyncConflictState.resolved);
    expect(events, <String>['resolve']);
  });

  test('字段冲突服务端未返回已解决状态时拒绝伪成功', () async {
    final conflict = _fieldConflict();
    final events = <String>[];
    final resolver = CloudSyncConflictResolver(
      session: _session(),
      client: _ConflictTransport(
        events: events,
        listResponses: const <List<CloudSyncConflict>>[],
        resolveResult: conflict,
      ),
      store: store,
      writeJournal: writeJournal,
      adapters: const <SyncEntityAdapter>[],
      synchronize: () async => events.add('sync'),
    );

    await expectLater(
      resolver.resolve(conflict, const <String>{}),
      throwsA(
        isA<CloudSyncConflictResolutionException>().having(
          (error) => error.reason,
          'reason',
          CloudSyncConflictResolutionFailureReason.invalidResolveResult,
        ),
      ),
    );

    expect(events, <String>['resolve']);
  });

  test('字段冲突缺少有效 shadow 时保留开放状态', () async {
    final conflict = _fieldConflict();
    final events = <String>[];
    final transport = _ConflictTransport(
      events: events,
      listResponses: <List<CloudSyncConflict>>[
        <CloudSyncConflict>[conflict],
      ],
      resolveResult: _resolvedConflict(conflict),
    );
    final resolver = CloudSyncConflictResolver(
      session: _session(),
      client: transport,
      store: store,
      writeJournal: writeJournal,
      adapters: <SyncEntityAdapter>[
        _StatefulMessageAdapter(const <SyncEntityKey, LocalSyncEntity>{}),
      ],
      synchronize: () async => events.add('sync'),
    );

    await expectLater(
      resolver.resolve(conflict, const <String>{'/title'}),
      throwsA(
        isA<CloudSyncConflictResolutionException>().having(
          (error) => error.reason,
          'reason',
          CloudSyncConflictResolutionFailureReason.invalidShadow,
        ),
      ),
    );

    expect(events, <String>['sync', 'list']);
  });

  test('字段冲突二次同步产生同实体新冲突时不提前解决', () async {
    final session = _session();
    const key = SyncEntityKey(entityType: 'message', entityId: 'message-1');
    final initialPayload = <String, Object?>{'title': '云端标题'};
    await store.saveShadow(session, _conflictShadow(initialPayload));
    final events = <String>[];
    final adapter = _StatefulMessageAdapter(<SyncEntityKey, LocalSyncEntity>{
      key: LocalSyncEntity(
        entityType: key.entityType,
        entityId: key.entityId,
        payload: initialPayload,
      ),
    }, events: events);
    final conflict = _fieldConflict();
    final nextConflict = _fieldConflict(
      conflictId: 'conflict-2',
      mutationId: 'mutation-2',
    );
    final transport = _ConflictTransport(
      events: events,
      listResponses: <List<CloudSyncConflict>>[
        <CloudSyncConflict>[conflict],
        <CloudSyncConflict>[conflict, nextConflict],
      ],
      resolveResult: _resolvedConflict(conflict),
    );
    _bindCompletedExporter(writeJournal);
    final resolver = CloudSyncConflictResolver(
      session: session,
      client: transport,
      store: store,
      writeJournal: writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
      synchronize: () async => events.add('sync'),
    );

    await expectLater(
      resolver.resolve(conflict, const <String>{'/title'}),
      throwsA(
        isA<CloudSyncConflictResolutionException>().having(
          (error) => error.reason,
          'reason',
          CloudSyncConflictResolutionFailureReason.entityHasAnotherConflict,
        ),
      ),
    );

    expect(events, <String>['sync', 'list', 'apply', 'sync', 'list']);
  });

  test('字段冲突写回后校验不一致时不提前解决', () async {
    final session = _session();
    const key = SyncEntityKey(entityType: 'message', entityId: 'message-1');
    final initialPayload = <String, Object?>{'title': '云端标题'};
    await store.saveShadow(session, _conflictShadow(initialPayload));
    final events = <String>[];
    final adapter = _StatefulMessageAdapter(<SyncEntityKey, LocalSyncEntity>{
      key: LocalSyncEntity(
        entityType: key.entityType,
        entityId: key.entityId,
        payload: initialPayload,
      ),
    }, events: events);
    final conflict = _fieldConflict();
    final transport = _ConflictTransport(
      events: events,
      listResponses: <List<CloudSyncConflict>>[
        <CloudSyncConflict>[conflict],
        <CloudSyncConflict>[conflict],
      ],
      resolveResult: _resolvedConflict(conflict),
    );
    _bindCompletedExporter(writeJournal);
    final resolver = CloudSyncConflictResolver(
      session: session,
      client: transport,
      store: store,
      writeJournal: writeJournal,
      adapters: <SyncEntityAdapter>[adapter],
      synchronize: () async => events.add('sync'),
    );

    await expectLater(
      resolver.resolve(conflict, const <String>{'/title'}),
      throwsA(
        isA<CloudSyncConflictResolutionException>().having(
          (error) => error.reason,
          'reason',
          CloudSyncConflictResolutionFailureReason.verificationMismatch,
        ),
      ),
    );

    expect(events, <String>['sync', 'list', 'apply', 'sync', 'list']);
  });

  test('字段冲突拒绝嵌套路径且不发起网络请求', () async {
    final events = <String>[];
    final conflict = _fieldConflict(
      fields: <CloudSyncConflictField>[
        _conflictField('/settings/theme', desired: 'dark'),
      ],
    );
    final resolver = CloudSyncConflictResolver(
      session: _session(),
      client: _ConflictTransport(
        events: events,
        listResponses: const <List<CloudSyncConflict>>[],
        resolveResult: _resolvedConflict(conflict),
      ),
      store: store,
      writeJournal: writeJournal,
      adapters: <SyncEntityAdapter>[
        _StatefulMessageAdapter(const <SyncEntityKey, LocalSyncEntity>{}),
      ],
      synchronize: () async => events.add('sync'),
    );

    await expectLater(
      resolver.resolve(conflict, const <String>{'/settings/theme'}),
      throwsA(
        isA<CloudSyncConflictResolutionException>().having(
          (error) => error.reason,
          'reason',
          CloudSyncConflictResolutionFailureReason.unsupportedNestedPath,
        ),
      ),
    );

    expect(events, isEmpty);
  });
}

final class _StopAfterSnapshot implements Exception {}

final class _AuthoritativeSnapshotTransport implements CloudSyncTransport {
  _AuthoritativeSnapshotTransport(this.record);

  final CloudSyncRecord record;
  final List<CloudSyncOutboxMutation> pushedMutations =
      <CloudSyncOutboxMutation>[];
  bool hasLiveRecord = true;

  @override
  Future<CloudSyncPullResult> pull({String? cursor, int limit = 100}) async {
    return const CloudSyncPullResult(
      changes: <CloudSyncChange>[],
      nextCursor: 'authoritative-cursor',
      hasMore: false,
      resetRequired: false,
    );
  }

  @override
  Future<List<CloudSyncMutationResult>> push(
    List<CloudSyncOutboxMutation> mutations,
  ) async {
    pushedMutations.addAll(mutations);
    for (final mutation in mutations) {
      if (mutation.entityType == record.entityType &&
          mutation.entityId == record.entityId &&
          mutation.operation == CloudSyncMutationOperation.delete) {
        hasLiveRecord = false;
      }
    }
    return <CloudSyncMutationResult>[
      for (final mutation in mutations)
        CloudSyncMutationResult(
          mutationId: mutation.mutationId,
          status: CloudSyncMutationStatus.applied,
          retryable: false,
          revision: record.revision + 1,
          changeSeq: record.lastChangeSeq + 1,
        ),
    ];
  }

  @override
  Future<CloudSyncSnapshotResult> snapshot({
    String? snapshotCursor,
    int limit = 100,
  }) async {
    final records = hasLiveRecord
        ? <CloudSyncRecord>[record]
        : const <CloudSyncRecord>[];
    return CloudSyncSnapshotResult(
      records: records,
      nextSnapshotCursor: null,
      syncCursor: 'authoritative-cursor',
      hasMore: false,
    );
  }
}

final class _AuthoritativeDeltaTransport implements CloudSyncTransport {
  _AuthoritativeDeltaTransport({
    required this.snapshotRecords,
    required this.deltaRecord,
  });

  final List<CloudSyncRecord> snapshotRecords;
  final CloudSyncRecord deltaRecord;
  final List<CloudSyncOutboxMutation> pushedMutations =
      <CloudSyncOutboxMutation>[];
  var _pullCount = 0;
  bool hasLiveRecord = true;

  @override
  Future<CloudSyncPullResult> pull({String? cursor, int limit = 100}) async {
    if (_pullCount++ == 0 && hasLiveRecord) {
      return CloudSyncPullResult(
        changes: <CloudSyncChange>[
          CloudSyncChange.upsert(
            changeSeq: deltaRecord.lastChangeSeq,
            record: deltaRecord,
          ),
        ],
        nextCursor: 'authoritative-delta-cursor',
        hasMore: false,
        resetRequired: false,
      );
    }
    return const CloudSyncPullResult(
      changes: <CloudSyncChange>[],
      nextCursor: 'authoritative-delta-cursor',
      hasMore: false,
      resetRequired: false,
    );
  }

  @override
  Future<List<CloudSyncMutationResult>> push(
    List<CloudSyncOutboxMutation> mutations,
  ) async {
    pushedMutations.addAll(mutations);
    for (final mutation in mutations) {
      if (mutation.entityType == deltaRecord.entityType &&
          mutation.entityId == deltaRecord.entityId &&
          mutation.operation == CloudSyncMutationOperation.delete) {
        hasLiveRecord = false;
      }
    }
    return <CloudSyncMutationResult>[
      for (final mutation in mutations)
        CloudSyncMutationResult(
          mutationId: mutation.mutationId,
          status: CloudSyncMutationStatus.applied,
          retryable: false,
          revision: deltaRecord.revision + 1,
          changeSeq: deltaRecord.lastChangeSeq + 1,
        ),
    ];
  }

  @override
  Future<CloudSyncSnapshotResult> snapshot({
    String? snapshotCursor,
    int limit = 100,
  }) async {
    return CloudSyncSnapshotResult(
      records: snapshotRecords,
      nextSnapshotCursor: null,
      syncCursor: 'authoritative-snapshot-cursor',
      hasMore: false,
    );
  }
}

final class _RestartingAuthoritativeSnapshotTransport
    implements CloudSyncTransport {
  _RestartingAuthoritativeSnapshotTransport(this.record);

  final CloudSyncRecord record;
  final List<String?> snapshotCursors = <String?>[];
  final List<CloudSyncOutboxMutation> pushedMutations =
      <CloudSyncOutboxMutation>[];

  @override
  Future<CloudSyncPullResult> pull({String? cursor, int limit = 100}) async {
    return const CloudSyncPullResult(
      changes: <CloudSyncChange>[],
      nextCursor: 'authoritative-cursor',
      hasMore: false,
      resetRequired: false,
    );
  }

  @override
  Future<List<CloudSyncMutationResult>> push(
    List<CloudSyncOutboxMutation> mutations,
  ) async {
    pushedMutations.addAll(mutations);
    return <CloudSyncMutationResult>[
      for (final mutation in mutations)
        CloudSyncMutationResult(
          mutationId: mutation.mutationId,
          status: CloudSyncMutationStatus.applied,
          retryable: false,
          revision: record.revision + 1,
          changeSeq: record.lastChangeSeq + 1,
        ),
    ];
  }

  @override
  Future<CloudSyncSnapshotResult> snapshot({
    String? snapshotCursor,
    int limit = 100,
  }) async {
    snapshotCursors.add(snapshotCursor);
    return CloudSyncSnapshotResult(
      records: snapshotCursor == null
          ? <CloudSyncRecord>[record]
          : const <CloudSyncRecord>[],
      nextSnapshotCursor: null,
      syncCursor: 'authoritative-cursor',
      hasMore: false,
    );
  }
}

final class _IncrementalRemoteTransport implements CloudSyncTransport {
  _IncrementalRemoteTransport(this.record);

  final CloudSyncRecord record;
  final List<CloudSyncOutboxMutation> pushedMutations =
      <CloudSyncOutboxMutation>[];
  var _returnedChange = false;

  @override
  Future<CloudSyncPullResult> pull({String? cursor, int limit = 100}) async {
    if (!_returnedChange) {
      _returnedChange = true;
      return CloudSyncPullResult(
        changes: <CloudSyncChange>[
          CloudSyncChange.upsert(
            changeSeq: record.lastChangeSeq,
            record: record,
          ),
        ],
        nextCursor: 'incremental-cursor',
        hasMore: false,
        resetRequired: false,
      );
    }
    return const CloudSyncPullResult(
      changes: <CloudSyncChange>[],
      nextCursor: 'incremental-cursor',
      hasMore: false,
      resetRequired: false,
    );
  }

  @override
  Future<List<CloudSyncMutationResult>> push(
    List<CloudSyncOutboxMutation> mutations,
  ) async {
    pushedMutations.addAll(mutations);
    return <CloudSyncMutationResult>[
      for (final mutation in mutations)
        CloudSyncMutationResult(
          mutationId: mutation.mutationId,
          status: CloudSyncMutationStatus.applied,
          retryable: false,
          revision: record.revision + 1,
          changeSeq: record.lastChangeSeq + 1,
        ),
    ];
  }

  @override
  Future<CloudSyncSnapshotResult> snapshot({
    String? snapshotCursor,
    int limit = 100,
  }) {
    throw StateError('已有游标时不应请求全量快照');
  }
}

final class _ResetRequiredSnapshotTransport implements CloudSyncTransport {
  _ResetRequiredSnapshotTransport(this.record);

  final CloudSyncRecord record;
  final List<CloudSyncOutboxMutation> pushedMutations =
      <CloudSyncOutboxMutation>[];
  var _resetReturned = false;

  @override
  Future<CloudSyncPullResult> pull({String? cursor, int limit = 100}) async {
    if (!_resetReturned) {
      _resetReturned = true;
      return const CloudSyncPullResult(
        changes: <CloudSyncChange>[],
        nextCursor: 'reset-required',
        hasMore: false,
        resetRequired: true,
      );
    }
    return const CloudSyncPullResult(
      changes: <CloudSyncChange>[],
      nextCursor: 'cursor-after-reset',
      hasMore: false,
      resetRequired: false,
    );
  }

  @override
  Future<List<CloudSyncMutationResult>> push(
    List<CloudSyncOutboxMutation> mutations,
  ) async {
    pushedMutations.addAll(mutations);
    return <CloudSyncMutationResult>[
      for (final mutation in mutations)
        CloudSyncMutationResult(
          mutationId: mutation.mutationId,
          status: CloudSyncMutationStatus.applied,
          retryable: false,
          revision: record.revision + 1,
          changeSeq: record.lastChangeSeq + 1,
        ),
    ];
  }

  @override
  Future<CloudSyncSnapshotResult> snapshot({
    String? snapshotCursor,
    int limit = 100,
  }) async {
    return CloudSyncSnapshotResult(
      records: <CloudSyncRecord>[record],
      nextSnapshotCursor: null,
      syncCursor: 'snapshot-after-reset',
      hasMore: false,
    );
  }
}

final class _ConflictTransport implements CloudSyncConflictTransport {
  _ConflictTransport({
    required this.events,
    required List<List<CloudSyncConflict>> listResponses,
    required this.resolveResult,
  }) : _listResponses = List<List<CloudSyncConflict>>.from(listResponses);

  final List<String> events;
  final List<List<CloudSyncConflict>> _listResponses;
  final CloudSyncConflict resolveResult;

  @override
  Future<List<CloudSyncConflict>> listConflicts({
    CloudSyncConflictState state = CloudSyncConflictState.open,
    int limit = 100,
  }) async {
    events.add('list');
    if (_listResponses.isEmpty) {
      throw StateError('冲突列表响应不足');
    }
    return List<CloudSyncConflict>.unmodifiable(_listResponses.removeAt(0));
  }

  @override
  Future<CloudSyncConflict> resolveConflict(String conflictId) async {
    events.add('resolve');
    return resolveResult;
  }
}

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

final class _RemoteChangePageTransport implements CloudSyncTransport {
  _RemoteChangePageTransport(this.records);

  final List<CloudSyncRecord> records;

  @override
  Future<CloudSyncPullResult> pull({String? cursor, int limit = 100}) async {
    if (cursor == 'cursor-0') {
      return CloudSyncPullResult(
        changes: <CloudSyncChange>[
          for (final record in records)
            CloudSyncChange.upsert(
              changeSeq: record.lastChangeSeq,
              record: record,
            ),
        ],
        nextCursor: 'cursor-after-page',
        hasMore: false,
        resetRequired: false,
      );
    }
    return const CloudSyncPullResult(
      changes: <CloudSyncChange>[],
      nextCursor: 'cursor-after-page',
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

final class _TwoPageRemoteChangeTransport implements CloudSyncTransport {
  _TwoPageRemoteChangeTransport({required this.first, required this.second});

  final CloudSyncRecord first;
  final CloudSyncRecord second;

  @override
  Future<CloudSyncPullResult> pull({String? cursor, int limit = 100}) async {
    if (cursor == 'cursor-0') {
      return CloudSyncPullResult(
        changes: <CloudSyncChange>[
          CloudSyncChange.upsert(changeSeq: first.lastChangeSeq, record: first),
        ],
        nextCursor: 'cursor-page-2',
        hasMore: true,
        resetRequired: false,
      );
    }
    if (cursor == 'cursor-page-2') {
      return CloudSyncPullResult(
        changes: <CloudSyncChange>[
          CloudSyncChange.upsert(
            changeSeq: second.lastChangeSeq,
            record: second,
          ),
        ],
        nextCursor: 'cursor-final',
        hasMore: false,
        resetRequired: false,
      );
    }
    return const CloudSyncPullResult(
      changes: <CloudSyncChange>[],
      nextCursor: 'cursor-final',
      hasMore: false,
      resetRequired: false,
    );
  }

  @override
  Future<List<CloudSyncMutationResult>> push(
    List<CloudSyncOutboxMutation> mutations,
  ) {
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

final class _TwoPageSnapshotTransport implements CloudSyncTransport {
  _TwoPageSnapshotTransport({required this.first, required this.second});

  final CloudSyncRecord first;
  final CloudSyncRecord second;
  final List<String?> snapshotCursors = <String?>[];

  @override
  Future<CloudSyncPullResult> pull({String? cursor, int limit = 100}) {
    throw _StopAfterSnapshot();
  }

  @override
  Future<List<CloudSyncMutationResult>> push(
    List<CloudSyncOutboxMutation> mutations,
  ) {
    throw StateError('快照后不应推送');
  }

  @override
  Future<CloudSyncSnapshotResult> snapshot({
    String? snapshotCursor,
    int limit = 100,
  }) async {
    snapshotCursors.add(snapshotCursor);
    if (snapshotCursor == null) {
      return CloudSyncSnapshotResult(
        records: <CloudSyncRecord>[first],
        nextSnapshotCursor: 'snapshot-page-2',
        syncCursor: 'snapshot-final',
        hasMore: true,
      );
    }
    return CloudSyncSnapshotResult(
      records: <CloudSyncRecord>[second],
      nextSnapshotCursor: null,
      syncCursor: 'snapshot-final',
      hasMore: false,
    );
  }
}

final class _TransactionalMessageAdapter
    implements SyncEntityAdapter, RemoteSyncTransactionAdapter {
  _TransactionalMessageAdapter({
    this.failOnEntityId,
    Set<SyncEntityKey>? remoteTransactionKeys,
  }) : _remoteTransactionKeys = remoteTransactionKeys == null
           ? _defaultRemoteTransactionKeys
           : Set<SyncEntityKey>.unmodifiable(remoteTransactionKeys);

  static final Set<SyncEntityKey> _defaultRemoteTransactionKeys =
      Set<SyncEntityKey>.unmodifiable(<SyncEntityKey>[
        const SyncEntityKey(entityType: 'message', entityId: 'message-1'),
        const SyncEntityKey(entityType: 'message', entityId: 'message-2'),
      ]);

  String? failOnEntityId;
  final Set<SyncEntityKey> _remoteTransactionKeys;
  final Map<SyncEntityKey, LocalSyncEntity> entities =
      <SyncEntityKey, LocalSyncEntity>{};
  final List<String> events = <String>[];
  int transactionCommitCount = 0;
  int transactionDiscardCount = 0;
  bool _transactionSawApply = false;

  @override
  int get applyPriority => 0;

  @override
  Set<String> get entityTypes => const <String>{'message'};

  @override
  Set<SyncEntityKey> get remoteTransactionKeys => _remoteTransactionKeys;

  @override
  Future<T> runRemoteBatch<T>(Future<T> Function() apply) => apply();

  @override
  Future<T> runRemoteTransaction<T>(
    Future<T> Function() apply, {
    required RemoteSyncTransactionCommit commit,
  }) async {
    events.add('transaction-start');
    _transactionSawApply = false;
    try {
      final result = await apply();
      if (_transactionSawApply) {
        await commit(remoteTransactionKeys, () async {
          transactionCommitCount++;
          events.add('transaction-commit');
        });
      }
      return result;
    } catch (_) {
      transactionDiscardCount++;
      rethrow;
    }
  }

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
    entities.remove(key);
  }

  @override
  Future<void> applyRemoteUpsert(RemoteSyncEntity entity) async {
    events.add('apply:${entity.entityId}');
    _transactionSawApply = true;
    if (entity.entityId == failOnEntityId) {
      throw StateError('模拟后续分页应用失败');
    }
    entities[entity.key] = LocalSyncEntity(
      entityType: entity.entityType,
      entityId: entity.entityId,
      parentId: entity.parentId,
      schemaVersion: entity.schemaVersion,
      payload: entity.payload,
    );
  }
}

final class _StatefulMessageAdapter implements SyncEntityAdapter {
  _StatefulMessageAdapter(
    Map<SyncEntityKey, LocalSyncEntity> entities, {
    this.events,
  }) : entities = Map<SyncEntityKey, LocalSyncEntity>.from(entities);

  final Map<SyncEntityKey, LocalSyncEntity> entities;
  final List<String>? events;
  final List<RemoteSyncEntity> remoteUpserts = <RemoteSyncEntity>[];
  final List<SyncEntityKey> remoteDeletes = <SyncEntityKey>[];
  int remoteBatchCount = 0;

  @override
  int get applyPriority => 0;

  @override
  Set<String> get entityTypes => const <String>{'message'};

  @override
  Future<T> runRemoteBatch<T>(Future<T> Function() apply) {
    remoteBatchCount++;
    return apply();
  }

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
    events?.add('apply');
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

final class _RollbackMessageAdapter implements SyncEntityAdapter {
  _RollbackMessageAdapter({required this.failOnEntityId});

  final Map<SyncEntityKey, LocalSyncEntity> entities =
      <SyncEntityKey, LocalSyncEntity>{};
  String? failOnEntityId;

  @override
  int get applyPriority => 0;

  @override
  Set<String> get entityTypes => const <String>{'message'};

  @override
  Future<T> runRemoteBatch<T>(Future<T> Function() apply) async {
    final before = Map<SyncEntityKey, LocalSyncEntity>.from(entities);
    try {
      return await apply();
    } catch (_) {
      entities
        ..clear()
        ..addAll(before);
      rethrow;
    }
  }

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
    entities.remove(key);
  }

  @override
  Future<void> applyRemoteUpsert(RemoteSyncEntity entity) async {
    if (entity.entityId == failOnEntityId) {
      throw StateError('模拟远端批次中途失败');
    }
    entities[entity.key] = LocalSyncEntity(
      entityType: entity.entityType,
      entityId: entity.entityId,
      parentId: entity.parentId,
      schemaVersion: entity.schemaVersion,
      payload: entity.payload,
    );
  }
}

final class _PreparingMessageAdapter
    implements SyncEntityAdapter, RemoteSyncUpsertPreparer {
  _PreparingMessageAdapter({
    this.localEntity,
    this.stagingFile,
    this.failApply = false,
    this.failCommit = false,
  });

  final LocalSyncEntity? localEntity;
  final File? stagingFile;
  final bool failApply;
  final bool failCommit;
  final List<String> events = <String>[];
  var _insideBatch = false;

  @override
  int get applyPriority => 0;

  @override
  Set<String> get entityTypes => const <String>{'message'};

  @override
  Future<T> runRemoteBatch<T>(Future<T> Function() apply) async {
    events.add('batch-start');
    _insideBatch = true;
    try {
      return await apply();
    } finally {
      _insideBatch = false;
      events.add('batch-end');
    }
  }

  @override
  Future<PreparedRemoteSyncUpsert?> prepareRemoteUpsert(
    RemoteSyncEntity entity,
  ) async {
    if (_insideBatch) {
      throw StateError('远端资源准备不能发生在数据库批次内');
    }
    events.add('prepare');
    final file = stagingFile;
    if (file != null) await file.writeAsString('staged');
    return _RecordingPreparedRemoteUpsert(
      key: entity.key,
      events: events,
      isInsideBatch: () => _insideBatch,
      stagingFile: file,
      failApply: failApply,
      failCommit: failCommit,
    );
  }

  @override
  Future<LocalSyncEntity?> exportLocalEntity(SyncEntityKey key) async {
    final entity = localEntity;
    return entity?.key == key ? entity : null;
  }

  @override
  Future<Map<SyncEntityKey, LocalSyncEntity>> exportLocalEntitiesForKeys(
    Set<SyncEntityKey> keys,
  ) async {
    final entity = localEntity;
    if (entity == null || !keys.contains(entity.key)) {
      return <SyncEntityKey, LocalSyncEntity>{};
    }
    return <SyncEntityKey, LocalSyncEntity>{entity.key: entity};
  }

  @override
  Future<List<LocalSyncEntity>> exportLocalEntities() async {
    final entity = localEntity;
    return entity == null ? <LocalSyncEntity>[] : <LocalSyncEntity>[entity];
  }

  @override
  Future<void> applyRemoteDelete(SyncEntityKey key) async {}

  @override
  Future<void> applyRemoteUpsert(RemoteSyncEntity entity) async {
    throw StateError('已准备的远端实体必须通过 preparation 应用');
  }
}

final class _RecordingPreparedRemoteUpsert implements PreparedRemoteSyncUpsert {
  _RecordingPreparedRemoteUpsert({
    required this.key,
    required this.events,
    required this.isInsideBatch,
    required this.stagingFile,
    required this.failApply,
    required this.failCommit,
  });

  @override
  final SyncEntityKey key;
  final List<String> events;
  final bool Function() isInsideBatch;
  final File? stagingFile;
  final bool failApply;
  final bool failCommit;

  @override
  Future<void> apply() async {
    if (!isInsideBatch()) {
      throw StateError('远端实体必须在数据库批次内应用');
    }
    events.add('apply');
    if (failApply) throw StateError('模拟数据库批次失败');
  }

  @override
  Future<void> commit() async {
    if (isInsideBatch()) {
      throw StateError('远端资源不能在数据库批次内提交');
    }
    events.add('commit');
    if (failCommit) throw StateError('模拟远端资源提交失败');
  }

  @override
  Future<void> discard() async {
    if (isInsideBatch()) {
      throw StateError('远端资源不能在数据库批次内丢弃');
    }
    events.add('discard');
    final file = stagingFile;
    if (file != null && await file.exists()) await file.delete();
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

final class _ApplyingTransport implements CloudSyncTransport {
  final List<String> events = <String>[];
  final List<String> pushedEntityTypes = <String>[];
  int _changeSeq = 0;

  @override
  Future<CloudSyncPullResult> pull({String? cursor, int limit = 100}) async {
    events.add('pull');
    return CloudSyncPullResult(
      changes: const <CloudSyncChange>[],
      nextCursor: 'cursor-${events.length}',
      hasMore: false,
      resetRequired: false,
    );
  }

  @override
  Future<List<CloudSyncMutationResult>> push(
    List<CloudSyncOutboxMutation> mutations,
  ) async {
    events.add('push');
    pushedEntityTypes.addAll(
      mutations.map((mutation) => mutation.entityType.wireName),
    );
    return <CloudSyncMutationResult>[
      for (final mutation in mutations)
        CloudSyncMutationResult(
          mutationId: mutation.mutationId,
          status: CloudSyncMutationStatus.applied,
          retryable: false,
          revision: 1,
          changeSeq: ++_changeSeq,
        ),
    ];
  }

  @override
  Future<CloudSyncSnapshotResult> snapshot({
    String? snapshotCursor,
    int limit = 100,
  }) {
    throw StateError('已有游标时不应请求全量快照');
  }
}

final class _EmptyInitialTransport implements CloudSyncTransport {
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
  Future<List<CloudSyncMutationResult>> push(
    List<CloudSyncOutboxMutation> mutations,
  ) {
    throw StateError('阻塞与未来重试项不应进入推送');
  }

  @override
  Future<CloudSyncSnapshotResult> snapshot({
    String? snapshotCursor,
    int limit = 100,
  }) async {
    return const CloudSyncSnapshotResult(
      records: <CloudSyncRecord>[],
      nextSnapshotCursor: null,
      syncCursor: 'snapshot-cursor',
      hasMore: false,
    );
  }
}

final class _CountingAdapter implements SyncEntityAdapter {
  _CountingAdapter({required this.entityType, required this.entityId});

  final String entityType;
  final String entityId;
  int fullExportCount = 0;

  LocalSyncEntity get _entity => LocalSyncEntity(
    entityType: entityType,
    entityId: entityId,
    payload: <String, Object?>{'name': entityId},
  );

  @override
  int get applyPriority => 0;

  @override
  Set<String> get entityTypes => <String>{entityType};

  @override
  Future<T> runRemoteBatch<T>(Future<T> Function() apply) => apply();

  @override
  Future<LocalSyncEntity?> exportLocalEntity(SyncEntityKey key) async {
    return key == _entity.key ? _entity : null;
  }

  @override
  Future<Map<SyncEntityKey, LocalSyncEntity>> exportLocalEntitiesForKeys(
    Set<SyncEntityKey> keys,
  ) async {
    final entity = _entity;
    return keys.contains(entity.key)
        ? <SyncEntityKey, LocalSyncEntity>{entity.key: entity}
        : <SyncEntityKey, LocalSyncEntity>{};
  }

  @override
  Future<List<LocalSyncEntity>> exportLocalEntities() async {
    fullExportCount++;
    return <LocalSyncEntity>[_entity];
  }

  @override
  Future<void> applyRemoteDelete(SyncEntityKey key) async {}

  @override
  Future<void> applyRemoteUpsert(RemoteSyncEntity entity) async {}
}

final class _MessageAdapter implements SyncEntityAdapter {
  @override
  int get applyPriority => 0;

  @override
  Set<String> get entityTypes => const <String>{'message'};

  @override
  Future<T> runRemoteBatch<T>(Future<T> Function() apply) => apply();

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
  String entityId = 'message-1',
  String turnId = 'turn-1',
  required int revision,
  required int changeSeq,
  required String value,
  DateTime? deletedAt,
}) {
  return CloudSyncRecord(
    entityType: CloudSyncEntityType.message,
    entityId: entityId,
    parentId: turnId,
    revision: revision,
    schemaVersion: 2,
    sortSeq: null,
    payload: <String, Object?>{
      'conversationId': 'conversation-1',
      'turnId': turnId,
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

void _bindCompletedExporter(SyncWriteJournal journal) {
  journal.bindExporter((intents) async {
    return <SyncEntityKey, SyncWriteDisposition>{
      for (final intent in intents)
        SyncEntityKey(
          entityType: intent.entityType.wireName,
          entityId: intent.entityId,
        ): SyncWriteDisposition.completed,
    };
  });
}

CloudSyncShadow _conflictShadow(
  Map<String, Object?> payload, {
  int revision = 1,
}) {
  return CloudSyncShadow(
    entityType: CloudSyncEntityType.message,
    entityId: 'message-1',
    parentId: null,
    revision: revision,
    schemaVersion: 2,
    lastChangeSeq: revision,
    deleted: false,
    payload: payload,
    updatedAt: DateTime.utc(2026, 7, 16, 8, revision),
  );
}

CloudSyncConflict _fieldConflict({
  String conflictId = 'conflict-1',
  String mutationId = 'mutation-1',
  List<CloudSyncConflictField>? fields,
}) {
  return CloudSyncConflict(
    conflictId: conflictId,
    mutationId: mutationId,
    entityType: CloudSyncEntityType.message,
    entityId: 'message-1',
    baseRevision: 1,
    fields:
        fields ??
        <CloudSyncConflictField>[
          _conflictField('/title', desired: '本地标题'),
          _conflictField('/summary', desired: '本地摘要'),
          _conflictField('/nullable', desired: null),
          _conflictField('/removeMe', desiredExists: false),
        ],
    state: CloudSyncConflictState.open,
    createdAt: DateTime.utc(2026, 7, 16, 8),
    resolvedAt: null,
  );
}

CloudSyncConflictField _conflictField(
  String path, {
  Object? desired,
  bool desiredExists = true,
}) {
  return CloudSyncConflictField(
    path: path,
    current: CloudSyncConflictFieldState(exists: true, value: '云端值'),
    desired: CloudSyncConflictFieldState(
      exists: desiredExists,
      value: desiredExists ? desired : null,
    ),
  );
}

CloudSyncConflict _resolvedConflict(CloudSyncConflict conflict) {
  return CloudSyncConflict(
    conflictId: conflict.conflictId,
    mutationId: conflict.mutationId,
    entityType: conflict.entityType,
    entityId: conflict.entityId,
    baseRevision: conflict.baseRevision,
    fields: conflict.fields,
    state: CloudSyncConflictState.resolved,
    createdAt: conflict.createdAt,
    resolvedAt: DateTime.utc(2026, 7, 16, 9),
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
