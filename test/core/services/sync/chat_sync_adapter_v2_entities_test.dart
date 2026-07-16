import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/sync/chat_sync_adapter.dart';
import 'package:Kelivo/core/services/sync/chat_sync_codec.dart';
import 'package:Kelivo/core/services/sync/cloud_attachment_sync_service.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_client.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_store.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/sync/sync_codec.dart';
import 'package:Kelivo/core/services/sync/sync_write_executor.dart';

final class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getApplicationCachePath() async => '$path/cache';

  @override
  Future<String?> getTemporaryPath() async => '$path/tmp';
}

final class _NoFullScanChatService extends ChatService {
  _NoFullScanChatService() : super(const UntrackedSyncWriteExecutor.forTests());

  int fullScanCount = 0;

  @override
  List<Conversation> getAllConversations() {
    fullScanCount++;
    return super.getAllConversations();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late ChatService chatService;
  late CloudSyncStore store;
  late CloudSyncClient client;
  late ChatSyncAdapter adapter;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'kelivo_chat_sync_v2_entities_test_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      tempDirectory.path,
    );
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    chatService = _NoFullScanChatService();
    await chatService.init();
    store = await CloudSyncStore.open(boxName: 'chat-sync-v2-entities-test');
    client = CloudSyncClient(baseUrl: 'http://127.0.0.1:1');
    adapter = ChatSyncAdapter(
      chatService,
      CloudAttachmentSyncService(_session(client.baseUrl), client, store),
    );
  });

  tearDown(() async {
    client.close(force: true);
    await store.close();
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('Chat Adapter 声明完整的 v2 聊天实体类型', () {
    expect(
      adapter.entityTypes,
      containsAll(<String>{
        'conversation',
        'turn',
        'message',
        'message-selection',
        'tool-event',
        'thought-signature',
      }),
    );
  });

  test('导出版本选择、工具事件和思维签名实体', () async {
    final conversation = await chatService.createConversation(title: 'Chat');
    final message = await chatService.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      content: 'answer',
      turnId: 'turn-1',
      groupId: 'group-1',
      version: 1,
      generationStatus: 'completed',
    );
    await chatService.setSelectedVersion(conversation.id, 'group-1', 1);
    await chatService.setToolEvents(message.id, <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'tool-call-1',
        'name': 'weather',
        'arguments': <String, dynamic>{'city': '上海'},
        'content': '晴',
      },
    ]);
    await chatService.setGeminiThoughtSignature(message.id, 'signature-1');

    final entities = await adapter.exportLocalEntities();
    final selection = entities.singleWhere(
      (entity) => entity.entityType == 'message-selection',
    );
    final toolEvent = entities.singleWhere(
      (entity) => entity.entityType == 'tool-event',
    );
    final thoughtSignature = entities.singleWhere(
      (entity) => entity.entityType == 'thought-signature',
    );

    expect(selection.entityId, 'group-1');
    expect(selection.parentId, conversation.id);
    expect(selection.payload, <String, Object?>{
      'conversationId': conversation.id,
      'groupId': 'group-1',
      'selectedVersion': 1,
    });
    expect(toolEvent.entityId, message.id);
    expect(toolEvent.parentId, message.id);
    expect(toolEvent.payload, <String, Object?>{
      'messageId': message.id,
      'events': <Object?>[
        <String, Object?>{
          'id': 'tool-call-1',
          'name': 'weather',
          'arguments': <String, Object?>{'city': '上海'},
          'content': '晴',
        },
      ],
    });
    expect(thoughtSignature.entityId, message.id);
    expect(thoughtSignature.parentId, message.id);
    expect(thoughtSignature.payload, <String, Object?>{
      'messageId': message.id,
      'signature': 'signature-1',
    });
  });

  test('按 key 定向导出六类聊天实体', () async {
    final conversation = await chatService.createConversation(title: 'Chat');
    final message = await chatService.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      content: 'answer',
      turnId: 'turn-target',
      groupId: 'group-target',
      version: 1,
      generationStatus: 'completed',
    );
    await chatService.setSelectedVersion(conversation.id, 'group-target', 1);
    await chatService.setToolEvents(message.id, const <Map<String, dynamic>>[]);
    await chatService.setGeminiThoughtSignature(message.id, 'signature-target');

    final keys = <SyncEntityKey>[
      SyncEntityKey(
        entityType: ChatSyncAdapter.conversationType,
        entityId: conversation.id,
      ),
      const SyncEntityKey(
        entityType: ChatSyncAdapter.turnType,
        entityId: 'turn-target',
      ),
      SyncEntityKey(
        entityType: ChatSyncAdapter.messageType,
        entityId: message.id,
      ),
      const SyncEntityKey(
        entityType: ChatSyncAdapter.messageSelectionType,
        entityId: 'group-target',
      ),
      SyncEntityKey(
        entityType: ChatSyncAdapter.toolEventType,
        entityId: message.id,
      ),
      SyncEntityKey(
        entityType: ChatSyncAdapter.thoughtSignatureType,
        entityId: message.id,
      ),
    ];

    for (final key in keys) {
      final entity = await adapter.exportLocalEntity(key);
      expect(entity?.key, key, reason: key.entityType);
    }
    final batch = await adapter.exportLocalEntitiesForKeys(<SyncEntityKey>{
      ...keys,
      const SyncEntityKey(
        entityType: ChatSyncAdapter.messageType,
        entityId: 'missing-message',
      ),
    });
    expect(batch.keys.toSet(), keys.toSet());
    expect(
      await adapter.exportLocalEntity(
        const SyncEntityKey(
          entityType: ChatSyncAdapter.messageType,
          entityId: 'missing-message',
        ),
      ),
      isNull,
    );
  });

  test('按 key 导出不扫描会话全量列表', () async {
    final conversation = await chatService.createConversation(title: 'Chat');
    final message = await chatService.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      content: 'answer',
      turnId: 'turn-targeted',
      groupId: 'group-targeted',
      generationStatus: ChatMessage.generationStatusCompleted,
    );
    await chatService.setSelectedVersion(conversation.id, 'group-targeted', 0);
    final indexedService = chatService as _NoFullScanChatService;
    indexedService.fullScanCount = 0;

    final entities = await adapter.exportLocalEntitiesForKeys(<SyncEntityKey>{
      SyncEntityKey(
        entityType: ChatSyncAdapter.conversationType,
        entityId: conversation.id,
      ),
      const SyncEntityKey(
        entityType: ChatSyncAdapter.turnType,
        entityId: 'turn-targeted',
      ),
      SyncEntityKey(
        entityType: ChatSyncAdapter.messageType,
        entityId: message.id,
      ),
      const SyncEntityKey(
        entityType: ChatSyncAdapter.messageSelectionType,
        entityId: 'group-targeted',
      ),
    });

    expect(entities, hasLength(4));
    expect(indexedService.fullScanCount, 0);
  });

  test('远端三类实体通过专用同步入口恢复', () async {
    final conversation = await chatService.createConversation(title: 'Chat');
    final message = await chatService.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      content: 'answer',
      turnId: 'turn-remote',
      groupId: 'group-remote',
      generationStatus: 'completed',
    );
    final updatedAt = DateTime.utc(2026, 7, 16);

    await adapter.applyRemoteUpsert(
      RemoteSyncEntity(
        entityType: 'message-selection',
        entityId: 'group-remote',
        parentId: conversation.id,
        revision: 1,
        schemaVersion: 2,
        payload: <String, Object?>{
          'conversationId': conversation.id,
          'groupId': 'group-remote',
          'selectedVersion': 2,
        },
        updatedAt: updatedAt,
      ),
    );
    await adapter.applyRemoteUpsert(
      RemoteSyncEntity(
        entityType: 'tool-event',
        entityId: message.id,
        parentId: message.id,
        revision: 1,
        schemaVersion: 2,
        payload: <String, Object?>{
          'messageId': message.id,
          'events': <Object?>[
            <String, Object?>{
              'id': 'tool-call-remote',
              'name': 'search',
              'arguments': <String, Object?>{'query': 'Kelivo'},
              'content': 'result',
            },
          ],
        },
        updatedAt: updatedAt,
      ),
    );
    await adapter.applyRemoteUpsert(
      RemoteSyncEntity(
        entityType: 'thought-signature',
        entityId: message.id,
        parentId: message.id,
        revision: 1,
        schemaVersion: 2,
        payload: <String, Object?>{
          'messageId': message.id,
          'signature': 'remote-signature',
        },
        updatedAt: updatedAt,
      ),
    );

    expect(chatService.getVersionSelections(conversation.id), <String, int>{
      'group-remote': 2,
    });
    expect(chatService.getToolEvents(message.id), <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'tool-call-remote',
        'name': 'search',
        'arguments': <String, dynamic>{'query': 'Kelivo'},
        'content': 'result',
      },
    ]);
    expect(
      chatService.getGeminiThoughtSignature(message.id),
      'remote-signature',
    );
  });

  test('远端反序批次只通知一次并按轮次重建顺序', () async {
    final conversation = Conversation(
      id: 'remote-batch-conversation',
      title: 'Remote',
      createdAt: DateTime.utc(2026, 7, 16, 8),
      updatedAt: DateTime.utc(2026, 7, 16, 8),
    );
    final user = ChatMessage(
      id: 'remote-batch-user',
      role: 'user',
      content: 'question',
      conversationId: conversation.id,
      turnId: 'remote-batch-turn',
      timestamp: DateTime.utc(2026, 7, 16, 8, 1),
    );
    final assistant = ChatMessage(
      id: 'remote-batch-assistant',
      role: 'assistant',
      content: 'answer',
      conversationId: conversation.id,
      turnId: user.turnId,
      timestamp: DateTime.utc(2026, 7, 16, 8, 2),
    );
    final updatedAt = DateTime.utc(2026, 7, 16, 9);
    var notificationCount = 0;
    chatService.addListener(() => notificationCount++);

    await adapter.runRemoteBatch<void>(() async {
      await adapter.applyRemoteUpsert(
        RemoteSyncEntity(
          entityType: ChatSyncAdapter.conversationType,
          entityId: conversation.id,
          revision: 1,
          schemaVersion: 2,
          payload: ChatSyncCodec.encodeConversation(conversation),
          updatedAt: updatedAt,
        ),
      );
      for (final message in <ChatMessage>[assistant, user]) {
        await adapter.applyRemoteUpsert(
          RemoteSyncEntity(
            entityType: ChatSyncAdapter.messageType,
            entityId: message.id,
            parentId: message.turnId,
            revision: 1,
            schemaVersion: 2,
            payload: ChatSyncCodec.encodeMessage(
              message,
              syncedContent: message.content,
            )!,
            updatedAt: updatedAt,
          ),
        );
      }
      await adapter.applyRemoteUpsert(
        RemoteSyncEntity(
          entityType: ChatSyncAdapter.turnType,
          entityId: user.turnId,
          parentId: conversation.id,
          revision: 1,
          schemaVersion: 2,
          payload: ChatSyncCodec.encodeTurn(
            ChatSyncTurnRecord(
              id: user.turnId,
              conversationId: conversation.id,
              createdAt: DateTime.utc(2026, 7, 16, 8),
            ),
          ),
          updatedAt: updatedAt,
        ),
      );
    });

    expect(notificationCount, 1);
    expect(
      chatService.getMessages(conversation.id).map((message) => message.id),
      <String>[user.id, assistant.id],
    );
  });

  test('远端批次失败仍释放通知边界', () async {
    final conversation = Conversation(
      id: 'remote-failed-conversation',
      title: 'Remote',
      createdAt: DateTime.utc(2026, 7, 16, 8),
      updatedAt: DateTime.utc(2026, 7, 16, 8),
    );
    var notificationCount = 0;
    chatService.addListener(() => notificationCount++);

    await expectLater(
      adapter.runRemoteBatch<void>(() async {
        await adapter.applyRemoteUpsert(
          RemoteSyncEntity(
            entityType: ChatSyncAdapter.conversationType,
            entityId: conversation.id,
            revision: 1,
            schemaVersion: 2,
            payload: ChatSyncCodec.encodeConversation(conversation),
            updatedAt: DateTime.utc(2026, 7, 16, 9),
          ),
        );
        throw StateError('模拟远端批次失败');
      }),
      throwsStateError,
    );

    expect(notificationCount, 1);
    await chatService.renameConversation(conversation.id, 'Recovered');
    expect(notificationCount, 2);
  });

  test('远端墓碑按稳定实体身份清理三类状态', () async {
    final conversation = await chatService.createConversation(title: 'Chat');
    final message = await chatService.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      content: 'answer',
      turnId: 'turn-delete',
      groupId: 'group-delete',
      generationStatus: 'completed',
    );
    await chatService.setSelectedVersion(conversation.id, 'group-delete', 1);
    await chatService.setToolEvents(message.id, <Map<String, dynamic>>[
      <String, dynamic>{'id': 'tool-delete'},
    ]);
    await chatService.setGeminiThoughtSignature(message.id, 'signature');

    await adapter.applyRemoteDelete(
      const SyncEntityKey(
        entityType: 'message-selection',
        entityId: 'group-delete',
      ),
    );
    await adapter.applyRemoteDelete(
      SyncEntityKey(entityType: 'tool-event', entityId: message.id),
    );
    await adapter.applyRemoteDelete(
      SyncEntityKey(entityType: 'thought-signature', entityId: message.id),
    );

    expect(chatService.getVersionSelections(conversation.id), isEmpty);
    expect(chatService.getToolEvents(message.id), isEmpty);
    expect(chatService.getGeminiThoughtSignature(message.id), isNull);
  });

  test('空工具事件仍保留为可导出的同步实体', () async {
    final conversation = await chatService.createConversation(title: 'Chat');
    final message = await chatService.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      content: 'answer',
      turnId: 'turn-empty-tool',
      generationStatus: 'completed',
    );
    await chatService.setToolEvents(message.id, const <Map<String, dynamic>>[]);

    final entity = (await adapter.exportLocalEntities()).singleWhere(
      (candidate) =>
          candidate.entityType == 'tool-event' &&
          candidate.entityId == message.id,
    );

    expect(entity.parentId, message.id);
    expect(entity.payload, <String, Object?>{
      'messageId': message.id,
      'events': <Object?>[],
    });
  });

  test('远端扩展实体严格校验 Payload、身份和父级', () async {
    final conversation = await chatService.createConversation(title: 'Chat');
    final message = await chatService.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      content: 'answer',
      turnId: 'turn-validation',
      generationStatus: 'completed',
    );
    final updatedAt = DateTime.utc(2026, 7, 16);
    final invalidEntities = <RemoteSyncEntity>[
      RemoteSyncEntity(
        entityType: ChatSyncAdapter.turnType,
        entityId: 'turn-parent-mismatch',
        parentId: 'wrong-conversation',
        revision: 1,
        schemaVersion: 2,
        payload: ChatSyncCodec.encodeTurn(
          ChatSyncTurnRecord(
            id: 'turn-parent-mismatch',
            conversationId: conversation.id,
            createdAt: updatedAt,
          ),
        ),
        updatedAt: updatedAt,
      ),
      RemoteSyncEntity(
        entityType: ChatSyncAdapter.messageType,
        entityId: message.id,
        parentId: 'wrong-turn',
        revision: 1,
        schemaVersion: 2,
        payload: ChatSyncCodec.encodeMessage(
          message,
          syncedContent: message.content,
        )!,
        updatedAt: updatedAt,
      ),
      RemoteSyncEntity(
        entityType: 'message-selection',
        entityId: 'group-1',
        parentId: conversation.id,
        revision: 1,
        schemaVersion: 2,
        payload: <String, Object?>{
          'conversationId': conversation.id,
          'groupId': 'group-1',
          'selectedVersion': 1,
          'unexpected': true,
        },
        updatedAt: updatedAt,
      ),
      RemoteSyncEntity(
        entityType: 'message-selection',
        entityId: 'group-envelope',
        parentId: conversation.id,
        revision: 1,
        schemaVersion: 2,
        payload: <String, Object?>{
          'conversationId': conversation.id,
          'groupId': 'group-payload',
          'selectedVersion': 1,
        },
        updatedAt: updatedAt,
      ),
      RemoteSyncEntity(
        entityType: 'message-selection',
        entityId: 'group-parent',
        parentId: 'wrong-conversation',
        revision: 1,
        schemaVersion: 2,
        payload: <String, Object?>{
          'conversationId': conversation.id,
          'groupId': 'group-parent',
          'selectedVersion': 1,
        },
        updatedAt: updatedAt,
      ),
      RemoteSyncEntity(
        entityType: 'message-selection',
        entityId: 'group-negative',
        parentId: conversation.id,
        revision: 1,
        schemaVersion: 2,
        payload: <String, Object?>{
          'conversationId': conversation.id,
          'groupId': 'group-negative',
          'selectedVersion': -1,
        },
        updatedAt: updatedAt,
      ),
      RemoteSyncEntity(
        entityType: 'tool-event',
        entityId: message.id,
        parentId: message.id,
        revision: 1,
        schemaVersion: 2,
        payload: <String, Object?>{
          'messageId': 'wrong-message',
          'events': <Object?>[],
        },
        updatedAt: updatedAt,
      ),
      RemoteSyncEntity(
        entityType: 'tool-event',
        entityId: message.id,
        parentId: message.id,
        revision: 1,
        schemaVersion: 2,
        payload: <String, Object?>{
          'messageId': message.id,
          'events': <Object?>['not-an-object'],
        },
        updatedAt: updatedAt,
      ),
      RemoteSyncEntity(
        entityType: 'thought-signature',
        entityId: message.id,
        parentId: message.id,
        revision: 1,
        schemaVersion: 2,
        payload: <String, Object?>{'messageId': message.id, 'signature': '   '},
        updatedAt: updatedAt,
      ),
      RemoteSyncEntity(
        entityType: 'thought-signature',
        entityId: message.id,
        parentId: 'wrong-message',
        revision: 1,
        schemaVersion: 2,
        payload: <String, Object?>{
          'messageId': message.id,
          'signature': 'signature',
        },
        updatedAt: updatedAt,
      ),
    ];

    for (final entity in invalidEntities) {
      await expectLater(
        adapter.applyRemoteUpsert(entity),
        throwsFormatException,
        reason: entity.entityType,
      );
    }

    expect(chatService.getVersionSelections(conversation.id), isEmpty);
    expect(chatService.hasToolEvents(message.id), isFalse);
    expect(chatService.getGeminiThoughtSignature(message.id), isNull);
  });
}

CloudSyncAccountSession _session(String baseUrl) {
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
