import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:Kelivo/core/services/sync/cloud_sync_client.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_coordinator.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_store.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/sync/sync_codec.dart';

void main() {
  late Directory tempDirectory;
  late CloudSyncStore store;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'kelivo_cloud_sync_coordinator_test_',
    );
    Hive.init(tempDirectory.path);
    store = await CloudSyncStore.open(boxName: 'cloud-sync-coordinator-test');
  });

  tearDown(() async {
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
