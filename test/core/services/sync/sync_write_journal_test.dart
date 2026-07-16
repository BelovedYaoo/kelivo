import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:Kelivo/core/services/sync/cloud_sync_store.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/sync/sync_codec.dart';
import 'package:Kelivo/core/services/sync/sync_write_journal.dart';

const _journalScopeId = 'installation-1';

void main() {
  late Directory tempDirectory;
  late CloudSyncStore store;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'kelivo_sync_write_journal_test_',
    );
    Hive.init(tempDirectory.path);
    store = await CloudSyncStore.open(boxName: 'sync-write-journal-test');
  });

  tearDown(() async {
    await store.close();
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('本地写入先持久化 intent，导出入队成功后才清理', () async {
    final session = _session(userId: 'user-1');
    final events = <String>[];
    final journal = SyncWriteJournal(
      store: store,
      journalScopeId: _journalScopeId,
      initialSession: session,
      createIntentId: () => 'intent-1',
      now: () => DateTime.utc(2026, 7, 16, 9),
      exportAndEnqueue: (intent) async {
        events.add('export');
        final persisted = store.writeIntents(
          journalScopeId: _journalScopeId,
          accountScope: session.accountScope,
        );
        expect(persisted.single.intentId, intent.intentId);
        return SyncWriteDisposition.completed;
      },
    );

    final result = await journal.runLocal<String>(
      key: const SyncEntityKey(entityType: 'message', entityId: 'message-1'),
      write: () async {
        events.add('write');
        expect(
          store.writeIntents(
            journalScopeId: _journalScopeId,
            accountScope: session.accountScope,
          ),
          hasLength(1),
        );
        return 'done';
      },
    );

    expect(result, 'done');
    expect(events, <String>['write', 'export']);
    expect(
      store.writeIntents(
        journalScopeId: _journalScopeId,
        accountScope: session.accountScope,
      ),
      isEmpty,
    );
  });

  test('回调失败保留 intent，重启后可定向恢复并清理', () async {
    final session = _session(userId: 'user-1');
    final failingJournal = SyncWriteJournal(
      store: store,
      journalScopeId: _journalScopeId,
      initialSession: session,
      createIntentId: () => 'intent-recover',
      exportAndEnqueue: (_) async => throw StateError('enqueue failed'),
    );

    await expectLater(
      failingJournal.runLocal<void>(
        key: const SyncEntityKey(
          entityType: 'assistant',
          entityId: 'assistant-1',
        ),
        write: () async {},
      ),
      throwsStateError,
    );
    await store.close();
    store = await CloudSyncStore.open(boxName: 'sync-write-journal-test');

    final recovered = <SyncWriteIntent>[];
    final recoveringJournal = SyncWriteJournal(
      store: store,
      journalScopeId: _journalScopeId,
      initialSession: session,
      exportAndEnqueue: (intent) async {
        recovered.add(intent);
        return SyncWriteDisposition.completed;
      },
    );
    await recoveringJournal.recover();

    expect(recovered, hasLength(1));
    expect(recovered.single.intentId, 'intent-recover');
    expect(recovered.single.entityType, CloudSyncEntityType.assistant);
    expect(recovered.single.entityId, 'assistant-1');
    expect(recovered.single.accountScope, session.accountScope);
    expect(
      store.writeIntents(
        journalScopeId: _journalScopeId,
        accountScope: session.accountScope,
      ),
      isEmpty,
    );
  });

  test('同一实体写入串行，不同实体可以并发', () async {
    final session = _session(userId: 'user-1');
    var nextIntent = 0;
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final secondStarted = Completer<void>();
    final otherStarted = Completer<void>();
    final journal = SyncWriteJournal(
      store: store,
      journalScopeId: _journalScopeId,
      initialSession: session,
      createIntentId: () => 'intent-${nextIntent++}',
      exportAndEnqueue: (_) async => SyncWriteDisposition.completed,
    );
    const firstKey = SyncEntityKey(
      entityType: 'message',
      entityId: 'message-1',
    );

    final first = journal.runLocal<int>(
      key: firstKey,
      write: () async {
        firstStarted.complete();
        await releaseFirst.future;
        return 1;
      },
    );
    await firstStarted.future;
    final second = journal.runLocal<int>(
      key: firstKey,
      write: () async {
        secondStarted.complete();
        return 2;
      },
    );
    final other = journal.runLocal<int>(
      key: const SyncEntityKey(entityType: 'message', entityId: 'message-2'),
      write: () async {
        otherStarted.complete();
        return 3;
      },
    );
    await otherStarted.future;
    final wasSerialized = !secondStarted.isCompleted;
    releaseFirst.complete();

    expect(await Future.wait<int>(<Future<int>>[first, second, other]), <int>[
      1,
      2,
      3,
    ]);
    expect(wasSerialized, isTrue);
    expect(secondStarted.isCompleted, isTrue);
  });

  test('远端应用与同实体本地写串行且不生成 intent 或 outbox', () async {
    final session = _session(userId: 'user-1');
    final localStarted = Completer<void>();
    final releaseLocal = Completer<void>();
    final remoteStarted = Completer<void>();
    var exportCount = 0;
    final journal = SyncWriteJournal(
      store: store,
      journalScopeId: _journalScopeId,
      initialSession: session,
      exportAndEnqueue: (_) async {
        exportCount++;
        return SyncWriteDisposition.completed;
      },
    );
    const key = SyncEntityKey(
      entityType: 'conversation',
      entityId: 'conversation-1',
    );

    final local = journal.runLocal<void>(
      key: key,
      write: () async {
        localStarted.complete();
        await releaseLocal.future;
      },
    );
    await localStarted.future;
    final remote = journal.runRemote<void>(
      key: key,
      write: () async => remoteStarted.complete(),
    );
    final remoteWaited = !remoteStarted.isCompleted;
    releaseLocal.complete();
    await Future.wait<void>(<Future<void>>[local, remote]);

    expect(remoteWaited, isTrue);
    expect(exportCount, 1);
    expect(
      store.writeIntents(
        journalScopeId: _journalScopeId,
        accountScope: session.accountScope,
      ),
      isEmpty,
    );
  });

  test('无会话写入正常返回并延迟到登录后恢复', () async {
    final session = _session(userId: 'user-1');
    final recovered = <SyncWriteIntent>[];
    final journal = SyncWriteJournal(
      store: store,
      journalScopeId: _journalScopeId,
      createIntentId: () => 'intent-device-global',
      exportAndEnqueue: (intent) async {
        if (intent.accountScope == null) {
          return SyncWriteDisposition.deferred;
        }
        recovered.add(intent);
        return SyncWriteDisposition.completed;
      },
    );

    final result = await journal.runLocal<String>(
      key: const SyncEntityKey(
        entityType: 'user-preference',
        entityId: 'profile:default',
      ),
      write: () async => 'saved',
    );
    expect(result, 'saved');
    expect(
      store.writeIntents(journalScopeId: _journalScopeId, accountScope: null),
      hasLength(1),
    );

    await journal.transitionSession(session);
    expect(
      store.writeIntents(journalScopeId: _journalScopeId, accountScope: null),
      isEmpty,
    );
    expect(
      store.writeIntents(
        journalScopeId: _journalScopeId,
        accountScope: session.accountScope,
      ),
      hasLength(1),
    );
    await journal.recover();

    expect(recovered.single.intentId, 'intent-device-global');
    expect(recovered.single.accountScope, session.accountScope);
    expect(
      store.writeIntents(
        journalScopeId: _journalScopeId,
        accountScope: session.accountScope,
      ),
      isEmpty,
    );
  });

  test('会话切换独占等待在途写且写入固定使用开始时账号', () async {
    final firstSession = _session(
      userId: 'user-1',
      deviceId: 'server-device-1',
    );
    final secondSession = _session(
      userId: 'user-2',
      deviceId: 'server-device-2',
    );
    final writeStarted = Completer<void>();
    final releaseWrite = Completer<void>();
    final exportedScopes = <String?>[];
    var transitioned = false;
    var nextIntent = 0;
    final journal = SyncWriteJournal(
      store: store,
      journalScopeId: _journalScopeId,
      initialSession: firstSession,
      createIntentId: () => 'intent-transition-${nextIntent++}',
      exportAndEnqueue: (intent) async {
        exportedScopes.add(intent.accountScope);
        return SyncWriteDisposition.completed;
      },
    );

    final local = journal.runLocal<void>(
      key: const SyncEntityKey(
        entityType: 'conversation',
        entityId: 'conversation-before-transition',
      ),
      write: () async {
        writeStarted.complete();
        await releaseWrite.future;
      },
    );
    await writeStarted.future;
    final transition = journal.transitionSession(secondSession).then((_) {
      transitioned = true;
    });
    await Future<void>.delayed(Duration.zero);
    final transitionWaited = !transitioned;
    expect(
      store.writeIntents(
        journalScopeId: _journalScopeId,
        accountScope: firstSession.accountScope,
      ),
      hasLength(1),
    );
    releaseWrite.complete();
    await Future.wait<void>(<Future<void>>[local, transition]);

    await journal.runLocal<void>(
      key: const SyncEntityKey(
        entityType: 'conversation',
        entityId: 'conversation-after-transition',
      ),
      write: () async {},
    );
    expect(transitionWaited, isTrue);
    expect(exportedScopes, <String?>[
      firstSession.accountScope,
      secondSession.accountScope,
    ]);
  });

  test('业务写回调失败时保留 intent 且不提前导出', () async {
    final session = _session(userId: 'user-1');
    var exportCount = 0;
    final journal = SyncWriteJournal(
      store: store,
      journalScopeId: _journalScopeId,
      initialSession: session,
      createIntentId: () => 'intent-write-failed',
      exportAndEnqueue: (_) async {
        exportCount++;
        return SyncWriteDisposition.completed;
      },
    );

    await expectLater(
      journal.runLocal<void>(
        key: const SyncEntityKey(
          entityType: 'assistant',
          entityId: 'assistant-write-failed',
        ),
        write: () async => throw StateError('write failed'),
      ),
      throwsStateError,
    );

    expect(exportCount, 0);
    expect(
      store
          .writeIntents(
            journalScopeId: _journalScopeId,
            accountScope: session.accountScope,
          )
          .single
          .intentId,
      'intent-write-failed',
    );
  });

  test('暂停自动同步不影响本地写前记录和入队', () async {
    final session = _session(userId: 'user-1');
    await store.savePaused(session, paused: true);
    var exported = false;
    final journal = SyncWriteJournal(
      store: store,
      journalScopeId: _journalScopeId,
      initialSession: session,
      exportAndEnqueue: (_) async {
        exported = true;
        return SyncWriteDisposition.completed;
      },
    );

    await journal.runLocal<void>(
      key: const SyncEntityKey(
        entityType: 'user-preference',
        entityId: 'profile:default',
      ),
      write: () async {},
    );

    expect(store.isPaused(session), isTrue);
    expect(exported, isTrue);
    expect(
      store.writeIntents(
        journalScopeId: _journalScopeId,
        accountScope: session.accountScope,
      ),
      isEmpty,
    );
  });

  test('同一账号下不同本地 journal 作用域不会复用 intent', () async {
    final session = _session(userId: 'user-1');
    const key = SyncEntityKey(
      entityType: 'assistant',
      entityId: 'assistant-shared',
    );
    final first = SyncWriteJournal(
      store: store,
      journalScopeId: 'installation-a',
      initialSession: session,
      createIntentId: () => 'intent-installation-a',
      exportAndEnqueue: (_) async => throw StateError('offline'),
    );
    final second = SyncWriteJournal(
      store: store,
      journalScopeId: 'installation-b',
      initialSession: session,
      createIntentId: () => 'intent-installation-b',
      exportAndEnqueue: (_) async => throw StateError('offline'),
    );

    await expectLater(
      first.runLocal<void>(key: key, write: () async {}),
      throwsStateError,
    );
    await expectLater(
      second.runLocal<void>(key: key, write: () async {}),
      throwsStateError,
    );

    expect(
      store
          .writeIntents(
            journalScopeId: 'installation-a',
            accountScope: session.accountScope,
          )
          .single
          .intentId,
      'intent-installation-a',
    );
    expect(
      store
          .writeIntents(
            journalScopeId: 'installation-b',
            accountScope: session.accountScope,
          )
          .single
          .intentId,
      'intent-installation-b',
    );
  });
}

CloudSyncAccountSession _session({
  required String userId,
  String deviceId = 'device-1',
}) {
  return CloudSyncAccountSession(
    baseUrl: 'https://sync.example.com',
    token: 'token-$userId',
    userId: userId,
    loginName: userId,
    displayName: userId,
    role: CloudSyncUserRole.user,
    attachmentQuotaBytes: maximumCloudSyncAttachmentSizeBytes,
    deviceId: deviceId,
    deviceName: 'Device',
    platform: CloudSyncPlatform.android,
    clientVersion: '2.0.0',
    deviceCreatedAt: DateTime.utc(2026, 7, 16),
  );
}
