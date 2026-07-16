import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:Kelivo/core/services/sync/cloud_sync_store.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';

void main() {
  late Directory tempDirectory;
  late CloudSyncStore store;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'kelivo_cloud_sync_store_test_',
    );
    Hive.init(tempDirectory.path);
    store = await CloudSyncStore.open(boxName: 'cloud-sync-store-test');
  });

  tearDown(() async {
    await store.close();
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
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
