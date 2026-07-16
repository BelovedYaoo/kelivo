import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:Kelivo/core/services/sync/cloud_sync_mutation_planner.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_store.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/sync/sync_codec.dart';
import 'package:Kelivo/core/services/sync/sync_write_journal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDirectory;
  late CloudSyncStore store;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'kelivo_cloud_sync_store_test_',
    );
    Hive.init(tempDirectory.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return tempDirectory.parent.path;
          }
          return null;
        });
    store = await CloudSyncStore.open(boxName: 'cloud-sync-store-test');
  });

  tearDown(() async {
    await store.close();
    await Hive.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('journal 本地作用域首次生成后跨重启保持稳定', () async {
    final first = await store.loadOrCreateJournalScopeId(
      createId: () => 'installation-stable',
    );

    await store.close();
    store = await CloudSyncStore.open(boxName: 'cloud-sync-store-test');
    final reopened = await store.loadOrCreateJournalScopeId(
      createId: () => throw StateError('已有作用域时不应重新生成'),
    );

    expect(first, 'installation-stable');
    expect(reopened, first);
  });

  test('配置重扫代次随机生成且只能比较删除当前值', () async {
    final first = await store.createConfigRescanGeneration(
      createGeneration: () => 'generation-1',
    );
    final second = await store.createConfigRescanGeneration(
      createGeneration: () => 'generation-2',
    );

    expect(first, 'generation-1');
    expect(second, 'generation-2');
    expect(store.configRescanGeneration, 'generation-2');
    expect(await store.consumeConfigRescanGeneration('generation-1'), isFalse);
    expect(store.configRescanGeneration, 'generation-2');
    expect(await store.consumeConfigRescanGeneration('generation-2'), isTrue);
    expect(store.configRescanGeneration, isNull);
  });

  test('配置重扫代次生成失败时保留已有值', () async {
    await store.createConfigRescanGeneration(
      createGeneration: () => 'generation-stable',
    );

    await expectLater(
      store.createConfigRescanGeneration(createGeneration: () => '  '),
      throwsA(isA<FormatException>()),
    );

    expect(store.configRescanGeneration, 'generation-stable');
  });

  test('同目录重复初始化 Hive 时已打开的同步 Store 保持可用', () async {
    await store.saveLastBaseUrl('https://sync.example.com');

    await Hive.initFlutter(tempDirectory.path);

    await store.close();
    store = await CloudSyncStore.open(boxName: 'cloud-sync-store-test');
    expect(store.lastBaseUrl, 'https://sync.example.com');
    await store.saveLastBaseUrl('https://sync-2.example.com');
    expect(store.lastBaseUrl, 'https://sync-2.example.com');
  });

  test('本地协议首次或旧版启动清理同步状态并保留登录与安装身份', () async {
    final session = _session();
    await store.saveSession(session);
    await store.saveLastBaseUrl('https://sync.example.com');
    final journalScopeId = await store.loadOrCreateJournalScopeId(
      createId: () => 'installation-stable',
    );
    await store.close();

    final raw = await Hive.openBox<String>('cloud-sync-store-test');
    await raw.delete('local-sync-protocol-version');
    await raw.put('account:legacy:cursor:state', 'legacy-account-state');
    await raw.put('journal:legacy:write-intent:item', 'legacy-journal-state');
    await raw.close();

    store = await CloudSyncStore.open(boxName: 'cloud-sync-store-test');
    final migrated = Hive.box<String>('cloud-sync-store-test');
    expect(store.activeSession?.userId, session.userId);
    expect(store.lastBaseUrl, 'https://sync.example.com');
    expect(await store.loadOrCreateJournalScopeId(), journalScopeId);
    expect(migrated.get('local-sync-protocol-version'), '2');
    expect(
      migrated.keys.whereType<String>().where(
        (key) => key.startsWith('account:') || key.startsWith('journal:'),
      ),
      isEmpty,
    );
  });

  test('本地协议旧版本启动后重新清理账号与 journal 状态', () async {
    await store.close();
    final raw = await Hive.openBox<String>('cloud-sync-store-test');
    await raw.put('local-sync-protocol-version', '1');
    await raw.put('account:legacy:shadow:item', 'legacy-account-state');
    await raw.put('journal:legacy:write-intent:item', 'legacy-journal-state');
    await raw.close();

    store = await CloudSyncStore.open(boxName: 'cloud-sync-store-test');
    final migrated = Hive.box<String>('cloud-sync-store-test');
    expect(migrated.get('local-sync-protocol-version'), '2');
    expect(migrated.get('account:legacy:shadow:item'), isNull);
    expect(migrated.get('journal:legacy:write-intent:item'), isNull);
  });

  test('高于当前的本地协议版本拒绝打开且不清理未知状态', () async {
    await store.close();
    final raw = await Hive.openBox<String>('cloud-sync-store-test');
    await raw.put('local-sync-protocol-version', '3');
    await raw.put('account:future:state', 'future-state');
    await raw.put('journal:future:state', 'future-journal-state');
    await raw.close();

    await expectLater(
      CloudSyncStore.open(boxName: 'cloud-sync-store-test'),
      throwsA(isA<StateError>()),
    );

    final reopened = await Hive.openBox<String>('cloud-sync-store-test');
    expect(reopened.get('local-sync-protocol-version'), '3');
    expect(reopened.get('account:future:state'), 'future-state');
    expect(reopened.get('journal:future:state'), 'future-journal-state');
    await reopened.close();
  });

  test('被永久拒绝的 outbox 项保留但不再进入自动发送队列', () async {
    final session = _session();
    final createdAt = DateTime.utc(2026, 7, 16, 8);
    final blockedAt = createdAt.add(const Duration(seconds: 3));
    await store.enqueueOutbox(
      session,
      CloudSyncOutboxMutation.create(
        mutationId: 'mutation-1',
        entityType: CloudSyncEntityType.message,
        entityId: 'message-1',
        parentId: 'turn-1',
        schemaVersion: 2,
        payload: <String, Object?>{
          'conversationId': 'conversation-1',
          'turnId': 'turn-1',
        },
        createdAt: createdAt,
      ),
    );

    await store.markOutboxBlocked(
      session,
      mutationId: 'mutation-1',
      errorCode: 'SYNC_PAYLOAD_INVALID',
      blockedAt: blockedAt,
    );

    expect(store.pendingOutbox(session), isEmpty);
    final persisted = store
        .outboxForEntity(
          session,
          entityType: CloudSyncEntityType.message,
          entityId: 'message-1',
        )
        .single;
    expect(persisted.blockedAt, blockedAt);
    expect(persisted.lastErrorCode, 'SYNC_PAYLOAD_INVALID');
    expect(persisted.mutationId, 'mutation-1');
    expect(persisted.payload?['turnId'], 'turn-1');
  });

  test('待发送实体按父级先于子级排序且不依赖创建时间', () async {
    final session = _session();
    final createdAt = DateTime.utc(2026, 7, 16, 8);
    final mutations = <CloudSyncOutboxMutation>[
      _createMutation(
        mutationId: 'tool-event',
        entityType: CloudSyncEntityType.toolEvent,
        entityId: 'tool-event-1',
        parentId: 'message-1',
        createdAt: createdAt,
      ),
      _createMutation(
        mutationId: 'message',
        entityType: CloudSyncEntityType.message,
        entityId: 'message-1',
        parentId: 'turn-1',
        createdAt: createdAt.add(const Duration(seconds: 1)),
      ),
      _createMutation(
        mutationId: 'thought-signature',
        entityType: CloudSyncEntityType.thoughtSignature,
        entityId: 'thought-signature-1',
        parentId: 'message-1',
        createdAt: createdAt,
      ),
      _createMutation(
        mutationId: 'turn',
        entityType: CloudSyncEntityType.turn,
        entityId: 'turn-1',
        parentId: 'conversation-1',
        createdAt: createdAt.add(const Duration(seconds: 2)),
      ),
      _createMutation(
        mutationId: 'message-selection',
        entityType: CloudSyncEntityType.messageSelection,
        entityId: 'selection-1',
        parentId: 'conversation-1',
        createdAt: createdAt,
      ),
      _createMutation(
        mutationId: 'conversation',
        entityType: CloudSyncEntityType.conversation,
        entityId: 'conversation-1',
        createdAt: createdAt.add(const Duration(seconds: 3)),
      ),
      _createMutation(
        mutationId: 'memory',
        entityType: CloudSyncEntityType.memory,
        entityId: 'memory-1',
        parentId: 'assistant-1',
        createdAt: createdAt,
      ),
      _createMutation(
        mutationId: 'quick-phrase',
        entityType: CloudSyncEntityType.quickPhrase,
        entityId: 'quick-phrase-1',
        parentId: 'assistant-1',
        createdAt: createdAt,
      ),
      _createMutation(
        mutationId: 'assistant',
        entityType: CloudSyncEntityType.assistant,
        entityId: 'assistant-1',
        createdAt: createdAt.add(const Duration(seconds: 1)),
      ),
    ];
    for (final mutation in mutations) {
      await store.enqueueOutbox(session, mutation);
    }

    final pending = store.pendingOutbox(
      session,
      readyAt: createdAt.add(const Duration(minutes: 1)),
    );
    final indexes = <String, int>{
      for (var index = 0; index < pending.length; index++)
        pending[index].mutationId: index,
    };

    expect(indexes['conversation']!, lessThan(indexes['turn']!));
    expect(indexes['conversation']!, lessThan(indexes['message-selection']!));
    expect(indexes['turn']!, lessThan(indexes['message']!));
    expect(indexes['message']!, lessThan(indexes['tool-event']!));
    expect(indexes['message']!, lessThan(indexes['thought-signature']!));
    expect(indexes['assistant']!, lessThan(indexes['memory']!));
    expect(indexes['assistant']!, lessThan(indexes['quick-phrase']!));
  });

  test('定向捕获只导出目标实体，同一 intent 重放不重复入队', () async {
    final session = _session();
    const key = SyncEntityKey(entityType: 'assistant', entityId: 'assistant-1');
    final adapter = _TargetAdapter(
      entities: <SyncEntityKey, LocalSyncEntity?>{
        key: LocalSyncEntity(
          entityType: key.entityType,
          entityId: key.entityId,
          payload: const <String, Object?>{'name': '助手'},
        ),
      },
    );
    final planner = CloudSyncMutationPlanner(
      store,
      adapters: <SyncEntityAdapter>[adapter],
    );
    final intent = _intent(session, key, 'intent-create');

    expect(
      await planner.captureLocalIntent(session, intent),
      SyncWriteDisposition.completed,
    );
    expect(
      await planner.captureLocalIntent(session, intent),
      SyncWriteDisposition.deferred,
    );

    expect(adapter.fullExportCount, 0);
    expect(adapter.targetedKeys, <SyncEntityKey>[key]);
    final mutation = store
        .outboxForEntity(
          session,
          entityType: CloudSyncEntityType.assistant,
          entityId: key.entityId,
        )
        .single;
    expect(mutation.mutationId, 'intent-create');
    expect(mutation.operation, CloudSyncMutationOperation.create);
    expect(mutation.payload, <String, Object?>{'name': '助手'});
  });

  test('批量捕获按适配器一次导出多个目标实体', () async {
    final session = _session();
    const firstKey = SyncEntityKey(
      entityType: 'assistant',
      entityId: 'assistant-1',
    );
    const secondKey = SyncEntityKey(
      entityType: 'assistant',
      entityId: 'assistant-2',
    );
    final adapter = _TargetAdapter(
      entities: <SyncEntityKey, LocalSyncEntity?>{
        firstKey: LocalSyncEntity(
          entityType: firstKey.entityType,
          entityId: firstKey.entityId,
          payload: const <String, Object?>{'name': '助手一'},
        ),
        secondKey: LocalSyncEntity(
          entityType: secondKey.entityType,
          entityId: secondKey.entityId,
          payload: const <String, Object?>{'name': '助手二'},
        ),
      },
    );
    final planner = CloudSyncMutationPlanner(
      store,
      adapters: <SyncEntityAdapter>[adapter],
    );

    final dispositions = await planner
        .captureLocalIntents(session, <SyncWriteIntent>[
          _intent(session, firstKey, 'intent-first'),
          _intent(session, secondKey, 'intent-second'),
        ]);

    expect(dispositions.values, everyElement(SyncWriteDisposition.completed));
    expect(adapter.batchExportCount, 1);
    expect(adapter.fullExportCount, 0);
    expect(adapter.targetedKeys.toSet(), <SyncEntityKey>{firstKey, secondKey});
    expect(
      store.outboxForEntity(
        session,
        entityType: CloudSyncEntityType.assistant,
        entityId: firstKey.entityId,
      ),
      hasLength(1),
    );
    expect(
      store.outboxForEntity(
        session,
        entityType: CloudSyncEntityType.assistant,
        entityId: secondKey.entityId,
      ),
      hasLength(1),
    );
  });

  test('有效 shadow 生成顶层 update，无变化时不入队', () async {
    final session = _session();
    const changedKey = SyncEntityKey(
      entityType: 'assistant',
      entityId: 'assistant-changed',
    );
    const unchangedKey = SyncEntityKey(
      entityType: 'assistant',
      entityId: 'assistant-unchanged',
    );
    await store.saveShadow(
      session,
      _shadow(
        changedKey,
        payload: const <String, Object?>{'name': '旧名称', 'obsolete': true},
      ),
    );
    await store.saveShadow(
      session,
      _shadow(unchangedKey, payload: const <String, Object?>{'name': '不变'}),
    );
    final adapter = _TargetAdapter(
      entities: <SyncEntityKey, LocalSyncEntity?>{
        changedKey: LocalSyncEntity(
          entityType: changedKey.entityType,
          entityId: changedKey.entityId,
          payload: const <String, Object?>{'name': '新名称', 'added': 1},
        ),
        unchangedKey: LocalSyncEntity(
          entityType: unchangedKey.entityType,
          entityId: unchangedKey.entityId,
          payload: const <String, Object?>{'name': '不变'},
        ),
      },
    );
    final planner = CloudSyncMutationPlanner(
      store,
      adapters: <SyncEntityAdapter>[adapter],
    );

    await planner.captureLocalIntent(
      session,
      _intent(session, changedKey, 'intent-update'),
    );
    await planner.captureLocalIntent(
      session,
      _intent(session, unchangedKey, 'intent-unchanged'),
    );

    final mutation = store
        .outboxForEntity(
          session,
          entityType: CloudSyncEntityType.assistant,
          entityId: changedKey.entityId,
        )
        .single;
    expect(mutation.operation, CloudSyncMutationOperation.update);
    expect(mutation.baseRevision, 3);
    expect(
      mutation.patch.map((item) => '${item.operation.name}:${item.path}'),
      <String>['add:/added', 'replace:/name', 'remove:/obsolete'],
    );
    expect(
      store.outboxForEntity(
        session,
        entityType: CloudSyncEntityType.assistant,
        entityId: unchangedKey.entityId,
      ),
      isEmpty,
    );
  });

  test('实体缺失生成 delete，墓碑后重现生成 restore', () async {
    final session = _session();
    const deletedKey = SyncEntityKey(
      entityType: 'assistant',
      entityId: 'assistant-deleted',
    );
    const restoredKey = SyncEntityKey(
      entityType: 'assistant',
      entityId: 'assistant-restored',
    );
    await store.saveShadow(
      session,
      _shadow(deletedKey, payload: const <String, Object?>{'name': '待删除'}),
    );
    await store.saveShadow(
      session,
      _shadow(
        restoredKey,
        payload: const <String, Object?>{'name': '待恢复'},
        deleted: true,
      ),
    );
    final adapter = _TargetAdapter(
      entities: <SyncEntityKey, LocalSyncEntity?>{
        deletedKey: null,
        restoredKey: LocalSyncEntity(
          entityType: restoredKey.entityType,
          entityId: restoredKey.entityId,
          payload: const <String, Object?>{'name': '待恢复'},
        ),
      },
    );
    final planner = CloudSyncMutationPlanner(
      store,
      adapters: <SyncEntityAdapter>[adapter],
    );

    await planner.captureLocalIntent(
      session,
      _intent(session, deletedKey, 'intent-delete'),
    );
    await planner.captureLocalIntent(
      session,
      _intent(session, restoredKey, 'intent-restore'),
    );

    expect(
      store
          .outboxForEntity(
            session,
            entityType: CloudSyncEntityType.assistant,
            entityId: deletedKey.entityId,
          )
          .single
          .operation,
      CloudSyncMutationOperation.delete,
    );
    expect(
      store
          .outboxForEntity(
            session,
            entityType: CloudSyncEntityType.assistant,
            entityId: restoredKey.entityId,
          )
          .single
          .operation,
      CloudSyncMutationOperation.restore,
    );
  });

  test('create 待确认时延迟 update，确认后按新 shadow 规划', () async {
    final session = _session();
    const key = SyncEntityKey(entityType: 'assistant', entityId: 'assistant-1');
    final entities = <SyncEntityKey, LocalSyncEntity?>{
      key: LocalSyncEntity(
        entityType: key.entityType,
        entityId: key.entityId,
        payload: const <String, Object?>{'name': '第一版'},
      ),
    };
    final planner = CloudSyncMutationPlanner(
      store,
      adapters: <SyncEntityAdapter>[_TargetAdapter(entities: entities)],
    );

    await planner.captureLocalIntent(
      session,
      _intent(session, key, 'intent-create'),
    );
    entities[key] = LocalSyncEntity(
      entityType: key.entityType,
      entityId: key.entityId,
      payload: const <String, Object?>{'name': '第二版'},
    );
    final deferred = await planner.captureLocalIntent(
      session,
      _intent(session, key, 'intent-update'),
    );

    final retainedCreate = store
        .outboxForEntity(
          session,
          entityType: CloudSyncEntityType.assistant,
          entityId: key.entityId,
        )
        .single;
    expect(deferred, SyncWriteDisposition.deferred);
    expect(retainedCreate.mutationId, 'intent-create');
    expect(retainedCreate.payload?['name'], '第一版');

    await store.acknowledgeOutbox(
      session,
      mutationId: 'intent-create',
      revision: 1,
      lastChangeSeq: 1,
      schemaVersion: 2,
      payload: const <String, Object?>{'name': '第一版'},
    );
    expect(
      await planner.captureLocalIntent(
        session,
        _intent(session, key, 'intent-update'),
      ),
      SyncWriteDisposition.completed,
    );

    final update = store
        .outboxForEntity(
          session,
          entityType: CloudSyncEntityType.assistant,
          entityId: key.entityId,
        )
        .single;
    expect(update.mutationId, 'intent-update');
    expect(update.operation, CloudSyncMutationOperation.update);
    expect(update.patch.single.value, '第二版');
  });

  test('create 待确认时延迟 delete，确认后生成 delete', () async {
    final session = _session();
    const key = SyncEntityKey(entityType: 'assistant', entityId: 'assistant-1');
    final entities = <SyncEntityKey, LocalSyncEntity?>{
      key: LocalSyncEntity(
        entityType: key.entityType,
        entityId: key.entityId,
        payload: const <String, Object?>{'name': '待删除'},
      ),
    };
    final planner = CloudSyncMutationPlanner(
      store,
      adapters: <SyncEntityAdapter>[_TargetAdapter(entities: entities)],
    );
    await planner.captureLocalIntent(
      session,
      _intent(session, key, 'intent-create'),
    );

    entities[key] = null;
    expect(
      await planner.captureLocalIntent(
        session,
        _intent(session, key, 'intent-delete'),
      ),
      SyncWriteDisposition.deferred,
    );
    await store.acknowledgeOutbox(
      session,
      mutationId: 'intent-create',
      revision: 1,
      lastChangeSeq: 1,
      schemaVersion: 2,
      payload: const <String, Object?>{'name': '待删除'},
    );
    expect(
      await planner.captureLocalIntent(
        session,
        _intent(session, key, 'intent-delete'),
      ),
      SyncWriteDisposition.completed,
    );
    expect(
      store
          .outboxForEntity(
            session,
            entityType: CloudSyncEntityType.assistant,
            entityId: key.entityId,
          )
          .single
          .operation,
      CloudSyncMutationOperation.delete,
    );
  });

  test('update 待确认时延迟后续 update 和 delete', () async {
    final session = _session();
    const key = SyncEntityKey(entityType: 'assistant', entityId: 'assistant-1');
    await store.saveShadow(
      session,
      _shadow(key, payload: const <String, Object?>{'name': '服务端'}),
    );
    final entities = <SyncEntityKey, LocalSyncEntity?>{
      key: LocalSyncEntity(
        entityType: key.entityType,
        entityId: key.entityId,
        payload: const <String, Object?>{'name': '本地一'},
      ),
    };
    final planner = CloudSyncMutationPlanner(
      store,
      adapters: <SyncEntityAdapter>[_TargetAdapter(entities: entities)],
    );

    await planner.captureLocalIntent(
      session,
      _intent(session, key, 'intent-update-1'),
    );
    entities[key] = LocalSyncEntity(
      entityType: key.entityType,
      entityId: key.entityId,
      payload: const <String, Object?>{'name': '本地二'},
    );
    expect(
      await planner.captureLocalIntent(
        session,
        _intent(session, key, 'intent-update-2'),
      ),
      SyncWriteDisposition.deferred,
    );

    final retained = store
        .outboxForEntity(
          session,
          entityType: CloudSyncEntityType.assistant,
          entityId: key.entityId,
        )
        .single;
    expect(retained.mutationId, 'intent-update-1');
    expect(retained.patch.single.value, '本地一');

    await store.acknowledgeOutbox(
      session,
      mutationId: 'intent-update-1',
      revision: 4,
      lastChangeSeq: 4,
      schemaVersion: 2,
      payload: const <String, Object?>{'name': '本地一'},
    );
    await planner.captureLocalIntent(
      session,
      _intent(session, key, 'intent-update-2'),
    );
    final secondUpdate = store
        .outboxForEntity(
          session,
          entityType: CloudSyncEntityType.assistant,
          entityId: key.entityId,
        )
        .single;
    expect(secondUpdate.mutationId, 'intent-update-2');
    expect(secondUpdate.patch.single.value, '本地二');

    entities[key] = null;
    expect(
      await planner.captureLocalIntent(
        session,
        _intent(session, key, 'intent-delete'),
      ),
      SyncWriteDisposition.deferred,
    );
    await store.acknowledgeOutbox(
      session,
      mutationId: 'intent-update-2',
      revision: 5,
      lastChangeSeq: 5,
      schemaVersion: 2,
      payload: const <String, Object?>{'name': '本地二'},
    );
    await planner.captureLocalIntent(
      session,
      _intent(session, key, 'intent-delete'),
    );
    final delete = store
        .outboxForEntity(
          session,
          entityType: CloudSyncEntityType.assistant,
          entityId: key.entityId,
        )
        .single;
    expect(delete.mutationId, 'intent-delete');
    expect(delete.operation, CloudSyncMutationOperation.delete);
  });

  test('已尝试的同实体 mutation 不改写，新 intent 保持 deferred', () async {
    final session = _session();
    const key = SyncEntityKey(entityType: 'assistant', entityId: 'assistant-1');
    final entities = <SyncEntityKey, LocalSyncEntity?>{
      key: LocalSyncEntity(
        entityType: key.entityType,
        entityId: key.entityId,
        payload: const <String, Object?>{'name': '第一版'},
      ),
    };
    final planner = CloudSyncMutationPlanner(
      store,
      adapters: <SyncEntityAdapter>[_TargetAdapter(entities: entities)],
    );
    await planner.captureLocalIntent(
      session,
      _intent(session, key, 'intent-first'),
    );
    await store.markOutboxAttempted(session, mutationId: 'intent-first');
    entities[key] = LocalSyncEntity(
      entityType: key.entityType,
      entityId: key.entityId,
      payload: const <String, Object?>{'name': '第二版'},
    );

    final disposition = await planner.captureLocalIntent(
      session,
      _intent(session, key, 'intent-second'),
    );

    expect(disposition, SyncWriteDisposition.deferred);
    final retained = store
        .outboxForEntity(
          session,
          entityType: CloudSyncEntityType.assistant,
          entityId: key.entityId,
        )
        .single;
    expect(retained.mutationId, 'intent-first');
    expect(retained.attemptCount, 1);
    expect(retained.payload?['name'], '第一版');
  });

  test('墓碑内容变化时先 restore 并保留 intent 等待后续 update', () async {
    final session = _session();
    const key = SyncEntityKey(entityType: 'assistant', entityId: 'assistant-1');
    await store.saveShadow(
      session,
      _shadow(
        key,
        payload: const <String, Object?>{'name': '墓碑版本'},
        deleted: true,
      ),
    );
    final entities = <SyncEntityKey, LocalSyncEntity?>{
      key: LocalSyncEntity(
        entityType: key.entityType,
        entityId: key.entityId,
        payload: const <String, Object?>{'name': '恢复后修改'},
      ),
    };
    final planner = CloudSyncMutationPlanner(
      store,
      adapters: <SyncEntityAdapter>[_TargetAdapter(entities: entities)],
    );

    final disposition = await planner.captureLocalIntent(
      session,
      _intent(session, key, 'intent-restore-update'),
    );

    expect(disposition, SyncWriteDisposition.deferred);
    final restore = store
        .outboxForEntity(
          session,
          entityType: CloudSyncEntityType.assistant,
          entityId: key.entityId,
        )
        .single;
    expect(restore.mutationId, 'intent-restore-update:restore');
    expect(restore.operation, CloudSyncMutationOperation.restore);

    await store.acknowledgeOutbox(
      session,
      mutationId: restore.mutationId,
      revision: 4,
      lastChangeSeq: 4,
      schemaVersion: 2,
      payload: const <String, Object?>{'name': '墓碑版本'},
    );
    expect(
      await planner.captureLocalIntent(
        session,
        _intent(session, key, 'intent-restore-update'),
      ),
      SyncWriteDisposition.completed,
    );
    final update = store
        .outboxForEntity(
          session,
          entityType: CloudSyncEntityType.assistant,
          entityId: key.entityId,
        )
        .single;
    expect(update.mutationId, 'intent-restore-update');
    expect(update.operation, CloudSyncMutationOperation.update);
    expect(update.patch.single.value, '恢复后修改');
  });
}

final class _TargetAdapter implements SyncEntityAdapter {
  _TargetAdapter({required this.entities});

  final Map<SyncEntityKey, LocalSyncEntity?> entities;
  final List<SyncEntityKey> targetedKeys = <SyncEntityKey>[];
  int fullExportCount = 0;
  int batchExportCount = 0;

  @override
  int get applyPriority => 0;

  @override
  Set<String> get entityTypes => const <String>{'assistant'};

  @override
  Future<T> runRemoteBatch<T>(Future<T> Function() apply) => apply();

  @override
  Future<LocalSyncEntity?> exportLocalEntity(SyncEntityKey key) async {
    targetedKeys.add(key);
    return entities[key];
  }

  @override
  Future<Map<SyncEntityKey, LocalSyncEntity>> exportLocalEntitiesForKeys(
    Set<SyncEntityKey> keys,
  ) async {
    batchExportCount++;
    targetedKeys.addAll(keys);
    return <SyncEntityKey, LocalSyncEntity>{
      for (final key in keys)
        if (entities[key] case final LocalSyncEntity entity) key: entity,
    };
  }

  @override
  Future<List<LocalSyncEntity>> exportLocalEntities() async {
    fullExportCount++;
    return entities.values.whereType<LocalSyncEntity>().toList();
  }

  @override
  Future<void> applyRemoteDelete(SyncEntityKey key) async {}

  @override
  Future<void> applyRemoteUpsert(RemoteSyncEntity entity) async {}
}

SyncWriteIntent _intent(
  CloudSyncAccountSession session,
  SyncEntityKey key,
  String intentId,
) {
  return SyncWriteIntent(
    intentId: intentId,
    entityType: CloudSyncEntityType.parse(key.entityType),
    entityId: key.entityId,
    journalScopeId: 'installation-1',
    accountScope: session.accountScope,
    createdAt: DateTime.utc(2026, 7, 16, 10),
  );
}

CloudSyncShadow _shadow(
  SyncEntityKey key, {
  required Map<String, Object?> payload,
  bool deleted = false,
}) {
  return CloudSyncShadow(
    entityType: CloudSyncEntityType.parse(key.entityType),
    entityId: key.entityId,
    parentId: null,
    revision: 3,
    schemaVersion: 2,
    lastChangeSeq: 3,
    deleted: deleted,
    payload: payload,
    updatedAt: DateTime.utc(2026, 7, 16, 9),
  );
}

CloudSyncOutboxMutation _createMutation({
  required String mutationId,
  required CloudSyncEntityType entityType,
  required String entityId,
  required DateTime createdAt,
  String? parentId,
}) {
  return CloudSyncOutboxMutation.create(
    mutationId: mutationId,
    entityType: entityType,
    entityId: entityId,
    parentId: parentId,
    schemaVersion: 1,
    payload: const <String, Object?>{},
    createdAt: createdAt,
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
