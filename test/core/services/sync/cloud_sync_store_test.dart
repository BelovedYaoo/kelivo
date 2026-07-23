import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_mutation_planner.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_state_retirement.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_store.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/sync/sync_codec.dart';
import 'package:Kelivo/core/services/sync/sync_write_executor.dart';
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

  test('硬切删除明文同步状态完整文件族并保留账号工作区密文', () async {
    final appDataDirectory = Directory(
      p.join(tempDirectory.path, 'sync-state-retirement'),
    );
    await appDataDirectory.create();
    final plaintextArtifacts = <File>[
      for (final suffix in const <String>['.hive', '.hivec', '.lock'])
        File(
          p.join(
            appDataDirectory.path,
            '${CloudSyncStore.defaultBoxName}$suffix',
          ),
        ),
    ];
    for (final artifact in plaintextArtifacts) {
      await artifact.writeAsString('shadow-and-outbox-plaintext');
    }
    final encryptedAccountArtifacts = <File>[
      File(p.join(appDataDirectory.path, 'session-v2')),
      File(p.join(appDataDirectory.path, 'token-v1-device.bin')),
    ];
    for (final artifact in encryptedAccountArtifacts) {
      await artifact.writeAsString('encrypted-account-record');
    }

    await CloudSyncStateRetirement.discardPlaintextState(
      appDataDirectory: appDataDirectory,
    );

    for (final artifact in plaintextArtifacts) {
      expect(await artifact.exists(), isFalse);
    }
    for (final artifact in encryptedAccountArtifacts) {
      expect(await artifact.readAsString(), 'encrypted-account-record');
    }
  });

  test('硬切发现同前缀未知文件时拒绝清理且不触碰任何状态', () async {
    final appDataDirectory = Directory(
      p.join(tempDirectory.path, 'sync-state-retirement-unknown'),
    );
    await appDataDirectory.create();
    final plaintextArtifact = File(
      p.join(appDataDirectory.path, '${CloudSyncStore.defaultBoxName}.hive'),
    );
    final unknownArtifact = File(
      p.join(
        appDataDirectory.path,
        '${CloudSyncStore.defaultBoxName}.hive-journal',
      ),
    );
    await plaintextArtifact.writeAsString('shadow-plaintext');
    await unknownArtifact.writeAsString('unknown-topology');

    await expectLater(
      CloudSyncStateRetirement.discardPlaintextState(
        appDataDirectory: appDataDirectory,
      ),
      throwsA(isA<StateError>()),
    );

    expect(await plaintextArtifact.readAsString(), 'shadow-plaintext');
    expect(await unknownArtifact.readAsString(), 'unknown-topology');
    expect(
      await File(
        p.join(appDataDirectory.path, '.cloud-sync-state-retirement-v1'),
      ).exists(),
      isFalse,
    );
  });

  test('硬切按大小写不敏感前缀识别未知拓扑并拒绝启动', () async {
    final appDataDirectory = Directory(
      p.join(tempDirectory.path, 'sync-state-retirement-unknown-casing'),
    );
    await appDataDirectory.create();
    final unknownArtifact = File(
      p.join(appDataDirectory.path, 'CLOUD_SYNC_STATE_V1.unknown'),
    );
    await unknownArtifact.writeAsString('unknown-topology');

    await expectLater(
      CloudSyncStateRetirement.discardPlaintextState(
        appDataDirectory: appDataDirectory,
      ),
      throwsA(isA<StateError>()),
    );

    expect(await unknownArtifact.readAsString(), 'unknown-topology');
  });

  test('硬切在没有旧同步状态时保持幂等且不创建清理标记', () async {
    final appDataDirectory = Directory(
      p.join(tempDirectory.path, 'sync-state-retirement-empty'),
    );
    await appDataDirectory.create();

    await CloudSyncStateRetirement.discardPlaintextState(
      appDataDirectory: appDataDirectory,
    );
    await CloudSyncStateRetirement.discardPlaintextState(
      appDataDirectory: appDataDirectory,
    );

    expect(await appDataDirectory.list().toList(), isEmpty);
  });

  test('硬切发现旧同步状态同名目录时拒绝清理', () async {
    final appDataDirectory = Directory(
      p.join(tempDirectory.path, 'sync-state-retirement-directory'),
    );
    await appDataDirectory.create();
    final unexpectedDirectory = Directory(
      p.join(appDataDirectory.path, '${CloudSyncStore.defaultBoxName}.hive'),
    );
    await unexpectedDirectory.create();

    await expectLater(
      CloudSyncStateRetirement.discardPlaintextState(
        appDataDirectory: appDataDirectory,
      ),
      throwsA(isA<StateError>()),
    );

    expect(await unexpectedDirectory.exists(), isTrue);
  });

  test('硬切发现旧同步状态符号链接时拒绝跟随和清理', () async {
    final appDataDirectory = Directory(
      p.join(tempDirectory.path, 'sync-state-retirement-link'),
    );
    await appDataDirectory.create();
    final encryptedAccountArtifact = File(
      p.join(appDataDirectory.path, 'session-v2'),
    );
    await encryptedAccountArtifact.writeAsString('encrypted-account-record');
    final unexpectedLink = Link(
      p.join(appDataDirectory.path, '${CloudSyncStore.defaultBoxName}.hive'),
    );
    await unexpectedLink.create(encryptedAccountArtifact.path);

    await expectLater(
      CloudSyncStateRetirement.discardPlaintextState(
        appDataDirectory: appDataDirectory,
      ),
      throwsA(isA<StateError>()),
    );

    expect(await unexpectedLink.exists(), isTrue);
    expect(
      await encryptedAccountArtifact.readAsString(),
      'encrypted-account-record',
    );
  });

  test('硬切在清理标记耐久后中断并于下次启动无条件续删', () async {
    final appDataDirectory = Directory(
      p.join(tempDirectory.path, 'sync-state-retirement-interrupted'),
    );
    await appDataDirectory.create();
    final plaintextArtifact = File(
      p.join(appDataDirectory.path, '${CloudSyncStore.defaultBoxName}.hive'),
    );
    await plaintextArtifact.writeAsString('shadow-plaintext');
    final marker = File(
      p.join(appDataDirectory.path, '.cloud-sync-state-retirement-v1'),
    );
    final interruptingDurability = _InterruptAfterMarkerDurability(
      delegate: RestorePlatformDurability(),
      markerPath: marker.path,
      plaintextArtifactPath: plaintextArtifact.path,
    );

    await expectLater(
      CloudSyncStateRetirement.discardPlaintextState(
        appDataDirectory: appDataDirectory,
        durability: interruptingDurability,
      ),
      throwsA(isA<StateError>()),
    );

    expect(interruptingDurability.markerWasDurableBeforeInterruption, isTrue);
    expect(await marker.exists(), isTrue);
    expect(await plaintextArtifact.exists(), isTrue);

    await CloudSyncStateRetirement.discardPlaintextState(
      appDataDirectory: appDataDirectory,
    );

    expect(await marker.exists(), isFalse);
    expect(await plaintextArtifact.exists(), isFalse);
  });

  test('仅本地写执行器只执行一次写入并返回本地结果', () async {
    const executor = LocalOnlySyncWriteExecutor();
    var writeCount = 0;

    final result = await executor.runLocal(
      key: const SyncEntityKey(entityType: 'chat', entityId: 'chat-1'),
      write: () async {
        writeCount += 1;
        return 'local-result';
      },
    );

    expect(result, 'local-result');
    expect(writeCount, 1);
  });

  test('仅本地批量写不遍历实体键且只执行本地写入', () async {
    const executor = LocalOnlySyncWriteExecutor();
    var writeCount = 0;

    final result = await executor.runLocalBatch(
      keys: _unreadableSyncEntityKeys(),
      write: () async {
        writeCount += 1;
        return 7;
      },
    );

    expect(result, 7);
    expect(writeCount, 1);
  });

  test('仅本地写执行器原样透传写入异常', () async {
    const executor = LocalOnlySyncWriteExecutor();

    await expectLater(
      executor.runLocal<void>(
        key: const SyncEntityKey(entityType: 'chat', entityId: 'chat-error'),
        write: () => throw StateError('local-write-failed'),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'local-write-failed',
        ),
      ),
    );
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

  test('重扫请求跨重启持久化、合并实体类型且只能比较删除当前代次', () async {
    final first = await store.markRescanRequired(
      entityTypes: const <String>{'assistant'},
      createGeneration: () => 'generation-1',
    );

    await store.close();
    store = await CloudSyncStore.open(boxName: 'cloud-sync-store-test');
    final second = await store.markRescanRequired(
      entityTypes: const <String>{'message'},
      createGeneration: () => 'generation-2',
    );

    expect(first.generation, 'generation-1');
    expect(first.entityTypes, const <String>{'assistant'});
    expect(second.generation, 'generation-2');
    expect(second.entityTypes, const <String>{'assistant', 'message'});
    expect(store.rescanRequest, second);
    expect(await store.consumeRescanRequest('generation-1'), isFalse);
    expect(store.rescanRequest, second);
    expect(await store.consumeRescanRequest('generation-2'), isTrue);
    expect(store.rescanRequest, isNull);
  });

  test('默认 Store 首次普通标记先完成协议初始化并保留请求', () async {
    expect(Hive.isBoxOpen(CloudSyncStore.defaultBoxName), isFalse);

    await CloudSyncStore.markDefaultRescanRequired(const <String>{'assistant'});

    expect(Hive.isBoxOpen(CloudSyncStore.defaultBoxName), isFalse);
    final reopened = await CloudSyncStore.open();
    try {
      expect(reopened.rescanRequest?.entityTypes, const <String>{'assistant'});
      expect(reopened.rescanRequest?.localAuthoritativeEntityTypes, isEmpty);
      expect(reopened.rescanRequest?.activeWriteIds, isEmpty);
    } finally {
      await reopened.close();
    }
  });

  test('默认 Store 首次权威写入经重启恢复后保留权威请求', () async {
    expect(Hive.isBoxOpen(CloudSyncStore.defaultBoxName), isFalse);
    var writeCount = 0;

    final result = await CloudSyncStore.runWithDefaultRescanWrite<String>(
      entityTypes: const <String>{'conversation', 'message'},
      localAuthoritativeEntityTypes: const <String>{'message'},
      keepActiveOnSuccess: true,
      write: () async {
        writeCount++;
        return 'written';
      },
    );

    expect(result, 'written');
    expect(writeCount, 1);
    expect(Hive.isBoxOpen(CloudSyncStore.defaultBoxName), isFalse);
    final reopened = await CloudSyncStore.open();
    try {
      expect(reopened.rescanRequest?.entityTypes, const <String>{
        'conversation',
        'message',
      });
      expect(
        reopened.rescanRequest?.localAuthoritativeEntityTypes,
        const <String>{'message'},
      );
      expect(reopened.rescanRequest?.activeWriteIds, isEmpty);
    } finally {
      await reopened.close();
    }
  });

  test('活动重扫写入期间不能消费请求且保留原请求', () async {
    await store.beginRescanWrite(
      entityTypes: const <String>{'message'},
      createId: () => 'write-active',
    );
    final active = store.rescanRequest!;

    expect(await store.consumeRescanRequest(active.generation), isFalse);
    expect(store.rescanRequest, active);
    expect(active.activeWriteIds, const <String>{'write-active'});
  });

  test('完成重扫写入后旋转代次并保留待扫描请求', () async {
    final lease = await store.beginRescanWrite(
      entityTypes: const <String>{'assistant', 'message'},
      createId: () => 'write-finished',
    );
    final active = store.rescanRequest!;

    expect(await store.completeRescanWrite(lease), isTrue);
    final pending = store.rescanRequest!;
    expect(pending.generation, isNot(active.generation));
    expect(pending.entityTypes, active.entityTypes);
    expect(pending.activeWriteIds, isEmpty);
    expect(await store.consumeRescanRequest(active.generation), isFalse);
    expect(store.rescanRequest, pending);
  });

  test('重启时将中断的重扫写入恢复为待扫描请求', () async {
    await store.beginRescanWrite(
      entityTypes: const <String>{'conversation', 'message'},
      createId: () => 'write-interrupted',
    );
    final interrupted = store.rescanRequest!;

    await store.close();
    store = await CloudSyncStore.open(boxName: 'cloud-sync-store-test');

    final recovered = store.rescanRequest!;
    expect(recovered.generation, isNot(interrupted.generation));
    expect(recovered.entityTypes, interrupted.entityTypes);
    expect(recovered.activeWriteIds, isEmpty);
  });

  test('重扫请求参数无效时保留已有请求', () async {
    final stable = await store.markRescanRequired(
      entityTypes: const <String>{'assistant'},
      createGeneration: () => 'generation-stable',
    );

    await expectLater(
      store.markRescanRequired(
        entityTypes: const <String>{'message'},
        createGeneration: () => '  ',
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      store.markRescanRequired(
        entityTypes: const <String>{'unsupported'},
        createGeneration: () => 'generation-invalid-type',
      ),
      throwsA(isA<FormatException>()),
    );

    expect(store.rescanRequest, stable);
  });

  test('本地权威范围必须属于本次写入而不能借用历史重扫范围', () async {
    final stable = await store.markRescanRequired(
      entityTypes: const <String>{'assistant'},
      createGeneration: () => 'generation-stable-authority',
    );

    await expectLater(
      store.markRescanRequired(
        entityTypes: const <String>{'message'},
        localAuthoritativeEntityTypes: const <String>{'assistant'},
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      store.beginRescanWrite(
        entityTypes: const <String>{'message'},
        localAuthoritativeEntityTypes: const <String>{'assistant'},
      ),
      throwsA(isA<FormatException>()),
    );

    expect(store.rescanRequest, stable);
  });

  test('不同账号 Store 的重扫请求相互隔离且只能消费各自代次', () async {
    final accountBStore = await CloudSyncStore.open(
      boxName: 'cloud-sync-store-account-b-test',
    );
    try {
      final accountARequest = await store.markRescanRequired(
        entityTypes: const <String>{'assistant'},
        localAuthoritativeEntityTypes: const <String>{'assistant'},
        createGeneration: () => 'account-a-generation',
      );
      final accountBRequest = await accountBStore.markRescanRequired(
        entityTypes: const <String>{'message'},
        createGeneration: () => 'account-b-generation',
      );

      expect(store.rescanRequest, accountARequest);
      expect(accountBStore.rescanRequest, accountBRequest);
      expect(accountARequest.localAuthoritativeEntityTypes, const <String>{
        'assistant',
      });
      expect(accountBRequest.localAuthoritativeEntityTypes, isEmpty);
      expect(
        await store.consumeRescanRequest(accountBRequest.generation),
        isFalse,
      );
      expect(
        await accountBStore.consumeRescanRequest(accountARequest.generation),
        isFalse,
      );
      expect(
        await store.consumeRescanRequest(accountARequest.generation),
        isTrue,
      );
      expect(store.rescanRequest, isNull);
      expect(accountBStore.rescanRequest, accountBRequest);
      expect(
        await accountBStore.consumeRescanRequest(accountBRequest.generation),
        isTrue,
      );
    } finally {
      await accountBStore.close();
    }
  });

  test('普通重扫不提升本地权威集合而成功权威写入才提升', () async {
    final ordinary = await store.markRescanRequired(
      entityTypes: const <String>{'assistant'},
      createGeneration: () => 'ordinary-generation',
    );

    expect(ordinary.localAuthoritativeEntityTypes, isEmpty);

    final lease = await store.beginRescanWrite(
      entityTypes: const <String>{'message'},
      localAuthoritativeEntityTypes: const <String>{'message'},
      createId: () => 'authoritative-write',
    );
    expect(store.rescanRequest!.localAuthoritativeEntityTypes, isEmpty);

    expect(await store.completeRescanWrite(lease), isTrue);
    expect(store.rescanRequest!.localAuthoritativeEntityTypes, const <String>{
      'message',
    });
  });

  test('取消或中断权威写入只恢复普通重扫而不提升权威集合', () async {
    await store.markRescanRequired(
      entityTypes: const <String>{'assistant'},
      createGeneration: () => 'ordinary-before-abort',
    );
    final abortedLease = await store.beginRescanWrite(
      entityTypes: const <String>{'message'},
      localAuthoritativeEntityTypes: const <String>{'message'},
      createId: () => 'authoritative-aborted',
    );

    expect(await store.abortRescanWrite(abortedLease), isTrue);
    final afterAbort = store.rescanRequest!;
    expect(afterAbort.activeWriteIds, isEmpty);
    expect(afterAbort.localAuthoritativeEntityTypes, isEmpty);

    await store.beginRescanWrite(
      entityTypes: const <String>{'conversation'},
      localAuthoritativeEntityTypes: const <String>{'conversation'},
      createId: () => 'authoritative-interrupted',
    );
    await store.close();
    store = await CloudSyncStore.open(boxName: 'cloud-sync-store-test');

    final recovered = store.rescanRequest!;
    expect(recovered.entityTypes, const <String>{
      'assistant',
      'conversation',
      'message',
    });
    expect(recovered.activeWriteIds, isEmpty);
    expect(recovered.localAuthoritativeEntityTypes, isEmpty);
  });

  test('keepActiveOnSuccess 在重启恢复后保留已成功的本地权威集合', () async {
    final lease = await store.beginRescanWrite(
      entityTypes: const <String>{'conversation', 'message'},
      localAuthoritativeEntityTypes: const <String>{'conversation', 'message'},
      createId: () => 'authoritative-kept-active',
    );

    expect(await store.completeRescanWrite(lease, keepActive: true), isTrue);
    final keptActive = store.rescanRequest!;
    expect(keptActive.activeWriteIds, <String>{lease.writeId});
    expect(keptActive.localAuthoritativeEntityTypes, const <String>{
      'conversation',
      'message',
    });

    await store.close();
    store = await CloudSyncStore.open(boxName: 'cloud-sync-store-test');

    final recovered = store.rescanRequest!;
    expect(recovered.activeWriteIds, isEmpty);
    expect(recovered.localAuthoritativeEntityTypes, const <String>{
      'conversation',
      'message',
    });
  });

  test('同目录重复初始化 Hive 时已打开的同步 Store 保持可用', () async {
    final journalScopeId = await store.loadOrCreateJournalScopeId(
      createId: () => 'duplicate-init-installation',
    );

    await Hive.initFlutter(tempDirectory.path);

    await store.close();
    store = await CloudSyncStore.open(boxName: 'cloud-sync-store-test');
    expect(await store.loadOrCreateJournalScopeId(), journalScopeId);
  });

  test('本地协议首次或旧版启动清理同步状态并保留安装身份', () async {
    final journalScopeId = await store.loadOrCreateJournalScopeId(
      createId: () => 'installation-stable',
    );
    await store.close();

    final raw = await Hive.openBox<String>('cloud-sync-store-test');
    await raw.put('active-session', 'legacy-session');
    await raw.put('last-base-url', 'https://legacy.invalid');
    await raw.delete('local-sync-protocol-version');
    await raw.put('account:legacy:cursor:state', 'legacy-account-state');
    await raw.put('journal:legacy:write-intent:item', 'legacy-journal-state');
    await raw.close();

    store = await CloudSyncStore.open(boxName: 'cloud-sync-store-test');
    final migrated = Hive.box<String>('cloud-sync-store-test');
    expect(migrated.containsKey('active-session'), isFalse);
    expect(migrated.containsKey('last-base-url'), isFalse);
    expect(await store.loadOrCreateJournalScopeId(), journalScopeId);
    expect(migrated.get('local-sync-protocol-version'), '3');
    expect(
      migrated.keys.whereType<String>().where(
        (key) => key.startsWith('account:') || key.startsWith('journal:'),
      ),
      isEmpty,
    );
  });

  test('当前协议启动仍清除废弃的服务地址状态', () async {
    await store.close();
    final raw = await Hive.openBox<String>('cloud-sync-store-test');
    await raw.put('local-sync-protocol-version', '3');
    await raw.put('last-base-url', 'https://legacy.invalid');
    await raw.close();

    store = await CloudSyncStore.open(boxName: 'cloud-sync-store-test');
    expect(
      Hive.box<String>('cloud-sync-store-test').containsKey('last-base-url'),
      isFalse,
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
    expect(migrated.get('local-sync-protocol-version'), '3');
    expect(migrated.get('account:legacy:shadow:item'), isNull);
    expect(migrated.get('journal:legacy:write-intent:item'), isNull);
  });

  test('高于当前的本地协议版本拒绝打开且不清理未知状态', () async {
    await store.close();
    final raw = await Hive.openBox<String>('cloud-sync-store-test');
    await raw.put('local-sync-protocol-version', '4');
    await raw.put('account:future:state', 'future-state');
    await raw.put('journal:future:state', 'future-journal-state');
    await raw.close();

    await expectLater(
      CloudSyncStore.open(boxName: 'cloud-sync-store-test'),
      throwsA(isA<StateError>()),
    );

    final reopened = await Hive.openBox<String>('cloud-sync-store-test');
    expect(reopened.get('local-sync-protocol-version'), '4');
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

  test('outbox 总数包含永久阻塞、未来重试与当前待发送项', () async {
    final session = _session();
    for (final index in <int>[1, 2, 3]) {
      await store.enqueueOutbox(
        session,
        CloudSyncOutboxMutation.create(
          mutationId: 'mutation-$index',
          entityType: CloudSyncEntityType.conversation,
          entityId: 'conversation-$index',
          schemaVersion: 2,
          payload: <String, Object?>{'title': '会话 $index'},
        ),
      );
    }
    await store.markOutboxBlocked(
      session,
      mutationId: 'mutation-1',
      errorCode: 'SYNC_PAYLOAD_INVALID',
    );
    await store.markOutboxRetry(
      session,
      mutationId: 'mutation-2',
      nextAttemptAt: DateTime.now().toUtc().add(const Duration(days: 1)),
    );

    expect(store.pendingOutbox(session), hasLength(1));
    expect(store.outboxCount(session), 3);
    expect(store.outboxCounts(session), (total: 3, blocked: 1));
    expect(
      store.blockedOutbox(session).map((mutation) => mutation.mutationId),
      <String>['mutation-1'],
    );

    await store.removeOutbox(session, 'mutation-3');
    expect(store.outboxCount(session), 2);
  });

  test('outbox 快照按实体保留阻塞、已尝试与未来重试状态', () async {
    final session = _session();
    final createdAt = DateTime.utc(2026, 7, 16, 8);
    for (final index in <int>[1, 2, 3]) {
      await store.enqueueOutbox(
        session,
        _createMutation(
          mutationId: 'mutation-$index',
          entityType: CloudSyncEntityType.assistant,
          entityId: 'assistant-$index',
          createdAt: createdAt.add(Duration(seconds: index)),
        ),
        merge: false,
      );
    }
    final retryAt = DateTime.utc(2099);
    await store.runWithOutboxSnapshot(session, () async {
      await store.markOutboxBlocked(
        session,
        mutationId: 'mutation-1',
        errorCode: 'SYNC_PAYLOAD_INVALID',
      );
      await store.markOutboxAttempted(session, mutationId: 'mutation-2');
      await store.markOutboxRetry(
        session,
        mutationId: 'mutation-2',
        nextAttemptAt: retryAt,
      );

      final blocked = store
          .outboxForEntity(
            session,
            entityType: CloudSyncEntityType.assistant,
            entityId: 'assistant-1',
          )
          .single;
      final attempted = store
          .outboxForEntity(
            session,
            entityType: CloudSyncEntityType.assistant,
            entityId: 'assistant-2',
          )
          .single;
      final pending = store
          .outboxForEntity(
            session,
            entityType: CloudSyncEntityType.assistant,
            entityId: 'assistant-3',
          )
          .single;
      expect(store.outboxCount(session), 3);
      expect(store.pendingOutbox(session).single.mutationId, 'mutation-3');
      expect(blocked.blockedAt, isNotNull);
      expect(attempted.attemptCount, 1);
      expect(attempted.nextAttemptAt, retryAt);
      expect(pending.blockedAt, isNull);
      expect(pending.attemptCount, 0);
    });
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

CloudSyncAccountSession _session({
  String baseUrl = 'https://sync.example.com',
}) {
  return CloudSyncAccountSession(
    baseUrl: baseUrl,
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

Iterable<SyncEntityKey> _unreadableSyncEntityKeys() sync* {
  throw StateError('仅本地执行器不应读取同步实体键');
}

final class _InterruptAfterMarkerDurability implements RestoreDurability {
  _InterruptAfterMarkerDurability({
    required this.delegate,
    required this.markerPath,
    required this.plaintextArtifactPath,
  });

  final RestoreDurability delegate;
  final String markerPath;
  final String plaintextArtifactPath;
  bool _markerRestricted = false;
  bool _markerSynced = false;
  bool _interrupted = false;
  bool markerWasDurableBeforeInterruption = false;

  @override
  Future<void> restrictDirectory(Directory directory) {
    return delegate.restrictDirectory(directory);
  }

  @override
  Future<void> restrictFile(File file) async {
    await delegate.restrictFile(file);
    if (p.equals(file.path, markerPath)) {
      _markerRestricted = true;
    }
  }

  @override
  Future<void> syncDirectory(
    Directory directory, {
    bool fullBarrier = false,
  }) async {
    await delegate.syncDirectory(directory, fullBarrier: fullBarrier);
    if (!_interrupted &&
        await File(markerPath).exists() &&
        await File(plaintextArtifactPath).exists()) {
      _interrupted = true;
      markerWasDurableBeforeInterruption =
          _markerRestricted && _markerSynced && fullBarrier;
      throw StateError('模拟清理标记持久化后的进程中断');
    }
  }

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) async {
    await delegate.syncFile(file, fullBarrier: fullBarrier);
    if (p.equals(file.path, markerPath) && fullBarrier) {
      _markerSynced = true;
    }
  }

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) {
    return delegate.renameAndSync(source: source, targetPath: targetPath);
  }
}
