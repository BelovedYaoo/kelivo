import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/database/chat_database_gateway.dart';
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
import 'package:Kelivo/utils/app_directories.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

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

final class _RealHttpOverrides extends HttpOverrides {}

final class _NoFullScanChatService extends ChatService {
  _NoFullScanChatService([SyncWriteExecutor? syncWriteExecutor])
    : super(
        syncWriteExecutor ?? const UntrackedSyncWriteExecutor.forTests(),
        databaseGateway: ChatDatabaseGateway(),
      );

  int fullScanCount = 0;

  @override
  List<Conversation> getAllConversations() {
    fullScanCount++;
    return super.getAllConversations();
  }
}

final class _RecordingSyncWriteExecutor implements SyncWriteExecutor {
  final List<Set<SyncEntityKey>> batches = <Set<SyncEntityKey>>[];
  Completer<void>? _writeEntered;
  Completer<void>? _writeGate;

  void blockNextWrite() {
    _writeEntered = Completer<void>();
    _writeGate = Completer<void>();
  }

  Future<void> get writeEntered =>
      _writeEntered?.future ?? Future<void>.value();

  void releaseWrite() {
    final gate = _writeGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<T> runLocal<T>({
    required SyncEntityKey key,
    required Future<T> Function() write,
  }) {
    return runLocalBatch(keys: <SyncEntityKey>{key}, write: write);
  }

  @override
  Future<T> runLocalBatch<T>({
    required Iterable<SyncEntityKey> keys,
    required Future<T> Function() write,
  }) async {
    batches.add(Set<SyncEntityKey>.of(keys));
    final entered = _writeEntered;
    final gate = _writeGate;
    if (entered != null && gate != null) {
      if (!entered.isCompleted) entered.complete();
      await gate.future;
      _writeEntered = null;
      _writeGate = null;
    }
    return write();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late ChatService chatService;
  late CloudSyncStore store;
  late CloudSyncClient client;
  late ChatSyncAdapter adapter;
  late _RecordingSyncWriteExecutor writeExecutor;

  setUp(() async {
    final tempRoot = Directory.fromUri(
      Directory.current.uri.resolve('.dart_tool/'),
    );
    await tempRoot.create(recursive: true);
    tempDirectory = await tempRoot.createTemp(
      'kelivo_chat_sync_v2_entities_test_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      tempDirectory.path,
    );
    AppDirectories.bindWorkspaceRoot(
      tempDirectory,
      installationRoot: tempDirectory,
      accountWorkspace: false,
    );
    await SandboxPathResolver.init();
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    Hive.init(tempDirectory.path);
    writeExecutor = _RecordingSyncWriteExecutor();
    chatService = _NoFullScanChatService(writeExecutor);
    await chatService.init();
    store = await CloudSyncStore.open();
    client = CloudSyncClient.forTesting(baseUrl: 'http://127.0.0.1:1');
    adapter = ChatSyncAdapter(
      chatService,
      CloudAttachmentSyncService(_session(client.baseUrl), client, store),
    );
  });

  tearDown(() async {
    client.close(force: true);
    await chatService.close();
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

  test('同长度篡改暂存附件后提交失败并保留原绑定', () async {
    final realHttpOverrides = _RealHttpOverrides();
    await HttpOverrides.runZoned(
      () async {
        final attachmentBytes = utf8.encode('remote attachment');
        final attachmentSha256 = sha256.convert(attachmentBytes).toString();
        const messageId = 'message-attachment-staging';
        const attachmentId = '11111111-1111-4111-8111-111111111111';
        const previousAttachmentId = '22222222-2222-4222-8222-222222222222';
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final baseUrl = 'http://${server.address.address}:${server.port}';
        final subscription = server.listen((request) async {
          await request.drain<void>();
          switch (request.uri.path) {
            case '/api/attachment/info/list':
              request.response.headers.contentType = ContentType.json;
              request.response.write(
                jsonEncode(<String, Object?>{
                  'data': <String, Object?>{
                    'items': <Object?>[
                      <String, Object?>{
                        'id': attachmentId,
                        'blobId': '33333333-3333-4333-8333-333333333333',
                        'entityType': 'message',
                        'entityId': messageId,
                        'fileName': 'remote.txt',
                        'mimeType': 'text/plain',
                        'sizeBytes': attachmentBytes.length,
                        'sha256': attachmentSha256,
                        'createdAt': '2026-07-18T08:00:00.000Z',
                      },
                    ],
                  },
                }),
              );
              break;
            case '/api/attachment/download-url/get':
              request.response.headers.contentType = ContentType.json;
              request.response.write(
                jsonEncode(<String, Object?>{
                  'data': <String, Object?>{
                    'attachmentId': attachmentId,
                    'downloadUrl': '$baseUrl/signed-download',
                    'expiresAt': '2026-07-18T09:00:00.000Z',
                  },
                }),
              );
              break;
            case '/signed-download':
              request.response.headers.contentLength = attachmentBytes.length;
              request.response.add(attachmentBytes);
              break;
            default:
              request.response.statusCode = HttpStatus.notFound;
          }
          await request.response.close();
        });
        final attachmentClient = CloudSyncClient.forTesting(
          baseUrl: baseUrl,
          token: 'token',
        );
        final session = _session(baseUrl);
        final service = CloudAttachmentSyncService(
          session,
          attachmentClient,
          store,
        );
        final previousBinding = CloudSyncAttachmentBinding(
          messageId: messageId,
          attachmentId: previousAttachmentId,
          kind: CloudSyncAttachmentKind.file,
          order: 0,
          localPath:
              '${tempDirectory.path}${Platform.pathSeparator}previous.txt',
          modifiedAt: DateTime.utc(2026, 7, 18, 7),
          sizeBytes: 1,
          sha256: List<String>.filled(64, '0').join(),
          md5Base64: base64Encode(List<int>.filled(16, 0)),
          fileName: 'previous.txt',
          mimeType: 'text/plain',
          completed: true,
        );
        await store.saveAttachmentBinding(session, previousBinding);

        try {
          final prepared = await service.prepareRestoreMessage(
            messageId: messageId,
            syncedContent: 'hello',
            references: const <ChatSyncAttachmentReference>[
              ChatSyncAttachmentReference(
                attachmentId: attachmentId,
                kind: ChatSyncAttachmentReference.fileKind,
                order: 0,
              ),
            ],
          );
          final marker = ChatAttachmentMarkerCodec.parse(
            prepared.content,
          ).markers.single;
          final stagingFiles = await tempDirectory
              .list(recursive: true)
              .where((entry) => entry is File && entry.path.endsWith('.part'))
              .cast<File>()
              .toList();

          expect(await File(marker.localPath).exists(), isFalse);
          expect(stagingFiles, hasLength(1));
          expect(
            store
                .attachmentBinding(
                  session,
                  messageId: messageId,
                  kind: CloudSyncAttachmentKind.file,
                  order: 0,
                )
                ?.attachmentId,
            previousAttachmentId,
          );

          final tamperedBytes = utf8.encode('tamper attachment');
          expect(tamperedBytes, hasLength(attachmentBytes.length));
          await stagingFiles.single.writeAsBytes(tamperedBytes, flush: true);

          await expectLater(prepared.commit(), throwsFormatException);

          expect(await stagingFiles.single.exists(), isFalse);
          expect(await File(marker.localPath).exists(), isFalse);
          expect(
            store
                .attachmentBinding(
                  session,
                  messageId: messageId,
                  kind: CloudSyncAttachmentKind.file,
                  order: 0,
                )
                ?.attachmentId,
            previousAttachmentId,
          );
        } finally {
          attachmentClient.close(force: true);
          await subscription.cancel();
          await server.close(force: true);
        }
      },
      createHttpClient: realHttpOverrides.createHttpClient,
      findProxyFromEnvironment: (_, _) => 'DIRECT',
    );
  });

  test('缓存附件在提交前被删除时提交失败且不改写绑定', () async {
    final realHttpOverrides = _RealHttpOverrides();
    await HttpOverrides.runZoned(
      () async {
        final attachmentBytes = utf8.encode('cached attachment');
        final attachmentSha256 = sha256.convert(attachmentBytes).toString();
        const messageId = 'message-cached-attachment';
        const attachmentId = '44444444-4444-4444-8444-444444444444';
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final baseUrl = 'http://${server.address.address}:${server.port}';
        final subscription = server.listen((request) async {
          await request.drain<void>();
          if (request.uri.path == '/api/attachment/info/list') {
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode(<String, Object?>{
                'data': <String, Object?>{
                  'items': <Object?>[
                    <String, Object?>{
                      'id': attachmentId,
                      'blobId': '55555555-5555-4555-8555-555555555555',
                      'entityType': 'message',
                      'entityId': messageId,
                      'fileName': 'cached.txt',
                      'mimeType': 'text/plain',
                      'sizeBytes': attachmentBytes.length,
                      'sha256': attachmentSha256,
                      'createdAt': '2026-07-18T08:00:00.000Z',
                    },
                  ],
                },
              }),
            );
          } else {
            request.response.statusCode = HttpStatus.notFound;
          }
          await request.response.close();
        });
        final attachmentClient = CloudSyncClient.forTesting(
          baseUrl: baseUrl,
          token: 'token',
        );
        final session = _session(baseUrl);
        final service = CloudAttachmentSyncService(
          session,
          attachmentClient,
          store,
        );
        final uploadDirectory = await AppDirectories.getUploadDirectory();
        await uploadDirectory.create(recursive: true);
        final cachedFile = File(
          '${uploadDirectory.path}${Platform.pathSeparator}cached.txt',
        );
        await cachedFile.writeAsBytes(attachmentBytes, flush: true);
        final cachedStat = await cachedFile.stat();
        final cachedBinding = CloudSyncAttachmentBinding(
          messageId: messageId,
          attachmentId: attachmentId,
          kind: CloudSyncAttachmentKind.file,
          order: 0,
          localPath: cachedFile.path,
          modifiedAt: cachedStat.modified,
          sizeBytes: cachedStat.size,
          sha256: attachmentSha256,
          md5Base64: base64Encode(md5.convert(attachmentBytes).bytes),
          fileName: 'cached.txt',
          mimeType: 'text/plain',
          completed: true,
        );
        await store.saveAttachmentBinding(session, cachedBinding);

        try {
          final prepared = await service.prepareRestoreMessage(
            messageId: messageId,
            syncedContent: 'hello',
            references: const <ChatSyncAttachmentReference>[
              ChatSyncAttachmentReference(
                attachmentId: attachmentId,
                kind: ChatSyncAttachmentReference.fileKind,
                order: 0,
              ),
            ],
          );
          await cachedFile.delete();

          await expectLater(prepared.commit(), throwsFormatException);

          expect(await cachedFile.exists(), isFalse);
          expect(
            store
                .attachmentBinding(
                  session,
                  messageId: messageId,
                  kind: CloudSyncAttachmentKind.file,
                  order: 0,
                )
                ?.attachmentId,
            attachmentId,
          );
        } finally {
          attachmentClient.close(force: true);
          await subscription.cancel();
          await server.close(force: true);
        }
      },
      createHttpClient: realHttpOverrides.createHttpClient,
      findProxyFromEnvironment: (_, _) => 'DIRECT',
    );
  });

  test('新建持久化会话进入同步写 journal', () async {
    final conversation = await chatService.createConversation(title: 'Chat');

    expect(writeExecutor.batches, <Set<SyncEntityKey>>[
      <SyncEntityKey>{
        SyncEntityKey(entityType: 'conversation', entityId: conversation.id),
      },
    ]);
  });

  test('会话更新在 journal 锁内重读并保留并发远端字段', () async {
    final conversation = await chatService.createConversation(title: 'Chat');
    final remoteConversation = conversation.copyWith(
      title: 'Remote title',
      assistantId: 'remote-assistant',
      mcpServerIds: const <String>['remote-mcp'],
      updatedAt: DateTime.utc(2026, 7, 18, 10),
    );
    writeExecutor.blockNextWrite();

    final rename = chatService.renameConversation(
      conversation.id,
      'Local title',
    );
    await writeExecutor.writeEntered;
    await chatService.upsertConversationFromSync(remoteConversation);
    writeExecutor.releaseWrite();
    await rename;

    final persisted = await chatService.loadConversationForSync(
      conversation.id,
    );
    expect(persisted?.title, 'Local title');
    expect(persisted?.assistantId, 'remote-assistant');
    expect(persisted?.mcpServerIds, const <String>['remote-mcp']);
  });

  test('设置和清除消息版本选择同时记录会话与选择实体', () async {
    final conversation = await chatService.createConversation(title: 'Chat');
    await chatService.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      content: 'answer',
      turnId: 'turn-selection',
      groupId: 'group-selection',
      version: 1,
      generationStatus: ChatMessage.generationStatusCompleted,
    );
    writeExecutor.batches.clear();

    await chatService.setSelectedVersion(conversation.id, 'group-selection', 1);
    await chatService.clearSelectedVersion(conversation.id, 'group-selection');

    final expectedKeys = <SyncEntityKey>{
      SyncEntityKey(entityType: 'conversation', entityId: conversation.id),
      const SyncEntityKey(
        entityType: 'message-selection',
        entityId: 'group-selection',
      ),
    };
    expect(writeExecutor.batches, <Set<SyncEntityKey>>[
      expectedKeys,
      expectedKeys,
    ]);
  });

  test('删除消息会把受影响的完整聊天图写入 journal', () async {
    final conversation = await chatService.createConversation(title: 'Chat');
    final message = await chatService.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      content: 'answer',
      turnId: 'turn-delete',
      groupId: 'group-delete',
      version: 1,
      generationStatus: ChatMessage.generationStatusCompleted,
    );
    await chatService.setSelectedVersion(conversation.id, 'group-delete', 1);
    writeExecutor.batches.clear();

    await chatService.deleteMessages(
      conversationId: conversation.id,
      messageIds: <String>{message.id},
      versionSelectionChanges: const <String, int?>{'group-delete': null},
    );

    expect(writeExecutor.batches, <Set<SyncEntityKey>>[
      <SyncEntityKey>{
        SyncEntityKey(entityType: 'conversation', entityId: conversation.id),
        const SyncEntityKey(entityType: 'turn', entityId: 'turn-delete'),
        SyncEntityKey(entityType: 'message', entityId: message.id),
        const SyncEntityKey(
          entityType: 'message-selection',
          entityId: 'group-delete',
        ),
        SyncEntityKey(entityType: 'tool-event', entityId: message.id),
        SyncEntityKey(entityType: 'thought-signature', entityId: message.id),
      },
    ]);
  });

  test('删除目标不存在时不创建错误的 journal 意图', () async {
    final conversation = await chatService.createConversation(title: 'Chat');
    final message = await chatService.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      content: 'answer',
      turnId: 'turn-delete-validation',
      generationStatus: ChatMessage.generationStatusCompleted,
    );
    writeExecutor.batches.clear();

    expect(
      await chatService.deleteMessages(
        conversationId: conversation.id,
        messageIds: const <String>{'missing-message'},
        versionSelectionChanges: const <String, int?>{},
      ),
      isEmpty,
    );
    await expectLater(
      chatService.deleteMessages(
        conversationId: conversation.id,
        messageIds: <String>{message.id, 'missing-message'},
        versionSelectionChanges: const <String, int?>{},
      ),
      throwsA(isA<StateError>()),
    );

    expect(writeExecutor.batches, isEmpty);
    expect(await chatService.loadMessageForSync(message.id), isNotNull);
  });

  test('截断式重新生成会把尾部删除图写入 journal', () async {
    final conversation = await chatService.createConversation(title: 'Chat');
    await chatService.addMessage(
      conversationId: conversation.id,
      role: 'user',
      content: 'question',
      turnId: 'regeneration-turn',
      groupId: 'regeneration-user-group',
      generationStatus: ChatMessage.generationStatusCompleted,
    );
    await chatService.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      content: 'answer',
      turnId: 'regeneration-turn',
      groupId: 'regeneration-group',
      version: 0,
      generationStatus: ChatMessage.generationStatusCompleted,
    );
    final trailing = await chatService.addMessage(
      conversationId: conversation.id,
      role: 'user',
      content: 'future question',
      turnId: 'future-turn',
      groupId: 'future-group',
      generationStatus: ChatMessage.generationStatusCompleted,
    );
    writeExecutor.batches.clear();

    await chatService.beginRegeneration(
      conversationId: conversation.id,
      modelId: 'model',
      providerId: 'provider',
      turnId: 'regeneration-turn',
      groupId: 'regeneration-group',
      version: 1,
      truncateFuture: true,
    );

    expect(writeExecutor.batches, hasLength(1));
    expect(
      writeExecutor.batches.single,
      containsAll(<SyncEntityKey>{
        SyncEntityKey(entityType: 'conversation', entityId: conversation.id),
        SyncEntityKey(entityType: 'message', entityId: trailing.id),
        const SyncEntityKey(entityType: 'turn', entityId: 'future-turn'),
        const SyncEntityKey(
          entityType: 'message-selection',
          entityId: 'future-group',
        ),
      }),
    );
    expect(
      writeExecutor.batches.single,
      isNot(
        contains(
          const SyncEntityKey(
            entityType: 'message-selection',
            entityId: 'regeneration-group',
          ),
        ),
      ),
    );
  });

  test('追加消息版本会原子记录新版本与选择实体', () async {
    final conversation = await chatService.createConversation(title: 'Chat');
    final original = await chatService.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      content: 'answer',
      turnId: 'append-version-turn',
      groupId: 'append-version-group',
      version: 0,
      generationStatus: ChatMessage.generationStatusCompleted,
    );
    writeExecutor.batches.clear();

    final appended = await chatService.appendMessageVersion(
      messageId: original.id,
      content: 'new answer',
    );

    expect(appended, isNotNull);
    expect(writeExecutor.batches, hasLength(1));
    expect(
      writeExecutor.batches.single,
      containsAll(<SyncEntityKey>{
        SyncEntityKey(entityType: 'conversation', entityId: conversation.id),
        const SyncEntityKey(
          entityType: 'turn',
          entityId: 'append-version-turn',
        ),
        SyncEntityKey(entityType: 'message', entityId: appended!.id),
        const SyncEntityKey(
          entityType: 'message-selection',
          entityId: 'append-version-group',
        ),
        SyncEntityKey(entityType: 'tool-event', entityId: appended.id),
        SyncEntityKey(entityType: 'thought-signature', entityId: appended.id),
      }),
    );
  });

  test('删除会话只锁定会话并请求完整聊天重扫', () async {
    final conversation = await chatService.createConversation(title: 'Chat');
    final message = await chatService.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      content: 'answer',
      turnId: 'turn-delete-conversation',
      groupId: 'group-delete-conversation',
      version: 1,
      generationStatus: ChatMessage.generationStatusCompleted,
    );
    await chatService.setSelectedVersion(
      conversation.id,
      'group-delete-conversation',
      1,
    );
    writeExecutor.batches.clear();

    await chatService.deleteConversation(conversation.id);

    expect(writeExecutor.batches, <Set<SyncEntityKey>>[
      <SyncEntityKey>{
        SyncEntityKey(entityType: 'conversation', entityId: conversation.id),
      },
    ]);
    expect(await chatService.loadConversationForSync(conversation.id), isNull);
    expect(await chatService.loadMessageForSync(message.id), isNull);
    expect(
      (await _readDefaultRescanRequest())?.entityTypes,
      CloudSyncStore.chatRescanEntityTypes,
    );
  });

  test('恢复旧版会话不逐项写 journal 并请求完整聊天重扫', () async {
    final conversation = Conversation(
      id: 'legacy-conversation',
      title: 'Legacy',
      messageIds: const <String>['legacy-message'],
    );
    final message = ChatMessage(
      id: 'legacy-message',
      role: 'assistant',
      content: 'legacy answer',
      conversationId: conversation.id,
      turnId: 'legacy-turn',
      generationStatus: ChatMessage.generationStatusCompleted,
    );

    await chatService.restoreConversation(conversation, <ChatMessage>[message]);

    expect(writeExecutor.batches, isEmpty);
    final persistedConversation = await chatService.loadConversationForSync(
      conversation.id,
    );
    final persistedMessage = await chatService.loadMessageForSync(message.id);
    expect(persistedConversation?.messageIds, contains(message.id));
    expect(persistedMessage?.content, message.content);
    expect(
      (await _readDefaultRescanRequest())?.entityTypes,
      CloudSyncStore.chatRescanEntityTypes,
    );
  });

  test('向旧版会话补入消息不逐项写 journal 并请求完整聊天重扫', () async {
    final conversation = await chatService.createConversation(title: 'Chat');
    writeExecutor.batches.clear();
    final message = ChatMessage(
      id: 'legacy-added-message',
      role: 'assistant',
      content: 'legacy answer',
      conversationId: conversation.id,
      turnId: 'legacy-added-turn',
      generationStatus: ChatMessage.generationStatusCompleted,
    );

    await chatService.addMessageDirectly(conversation.id, message);

    expect(writeExecutor.batches, isEmpty);
    final persistedConversation = await chatService.loadConversationForSync(
      conversation.id,
    );
    final persistedMessage = await chatService.loadMessageForSync(message.id);
    expect(persistedConversation?.messageIds, contains(message.id));
    expect(persistedMessage?.content, message.content);
    expect(
      (await _readDefaultRescanRequest())?.entityTypes,
      CloudSyncStore.chatRescanEntityTypes,
    );
  });

  test('覆盖恢复不逐项写 journal 并请求完整聊天重扫', () async {
    final oldConversation = await chatService.createConversation(title: 'Old');
    final oldMessage = await chatService.addMessage(
      conversationId: oldConversation.id,
      role: 'assistant',
      content: 'old answer',
      turnId: 'old-turn',
      generationStatus: ChatMessage.generationStatusCompleted,
    );
    writeExecutor.batches.clear();
    final newConversation = Conversation(
      id: 'replacement-conversation',
      title: 'Replacement',
      messageIds: const <String>['replacement-message'],
    );
    final newMessage = ChatMessage(
      id: 'replacement-message',
      role: 'assistant',
      content: 'replacement answer',
      conversationId: newConversation.id,
      turnId: 'replacement-turn',
      generationStatus: ChatMessage.generationStatusCompleted,
    );

    await chatService.replaceAllDataFromBackup(
      conversations: <Conversation>[newConversation],
      messages: <ChatMessage>[newMessage],
      toolEventsByMessageId: const <String, List<Map<String, dynamic>>>{},
      geminiSignaturesByMessageId: const <String, String>{},
    );

    expect(writeExecutor.batches, isEmpty);
    expect(
      await chatService.loadConversationForSync(oldConversation.id),
      isNull,
    );
    expect(await chatService.loadMessageForSync(oldMessage.id), isNull);
    final persistedConversation = await chatService.loadConversationForSync(
      newConversation.id,
    );
    final persistedMessage = await chatService.loadMessageForSync(
      newMessage.id,
    );
    expect(persistedConversation?.messageIds, contains(newMessage.id));
    expect(persistedMessage?.content, newMessage.content);
    expect(
      (await _readDefaultRescanRequest())?.entityTypes,
      CloudSyncStore.chatRescanEntityTypes,
    );
  });

  test('清空聊天数据不逐项写 journal 并请求完整聊天重扫', () async {
    final conversation = await chatService.createConversation(title: 'Chat');
    final message = await chatService.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      content: 'answer',
      turnId: 'clear-turn',
      generationStatus: ChatMessage.generationStatusCompleted,
    );
    writeExecutor.batches.clear();

    await chatService.clearAllData(deleteUploads: false);

    expect(writeExecutor.batches, isEmpty);
    expect(await chatService.loadConversationForSync(conversation.id), isNull);
    expect(await chatService.loadMessageForSync(message.id), isNull);
    expect(
      (await _readDefaultRescanRequest())?.entityTypes,
      CloudSyncStore.chatRescanEntityTypes,
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
    await chatService.loadMessages(conversation.id);
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
    final persistedMessages = await chatService.loadMessages(conversation.id);
    expect(persistedMessages.map((message) => message.id), <String>[
      user.id,
      assistant.id,
    ]);
  });

  test('远端批次失败仍释放通知边界', () async {
    final localConversation = await chatService.createConversation(
      title: 'Local',
    );
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
    await chatService.renameConversation(localConversation.id, 'Recovered');
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
    await chatService.setSelectedVersion(
      conversation.id,
      'group-delete',
      message.version,
    );
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

Future<CloudSyncRescanRequest?> _readDefaultRescanRequest() async {
  final wasOpen = Hive.isBoxOpen(CloudSyncStore.defaultBoxName);
  final defaultStore = await CloudSyncStore.open();
  try {
    return defaultStore.rescanRequest;
  } finally {
    if (!wasOpen) await defaultStore.close();
  }
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
