import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/sync/chat_sync_codec.dart';
import 'package:Kelivo/utils/app_directories.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'kelivo_chat_service_test_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ChatService turn identities', () {
    test('message writes preserve turn and explicit terminal status', () async {
      final service = ChatService();
      await service.init();

      final conversation = await service.createConversation(title: 'Chat');
      final user = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'question',
      );
      final assistant = await service.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        content: '',
        isStreaming: true,
        turnId: user.turnId,
      );

      await service.updateMessage(
        assistant.id,
        isStreaming: false,
        generationStatus: ChatMessage.generationStatusFailed,
      );
      final stored = service
          .getMessages(conversation.id)
          .firstWhere((message) => message.id == assistant.id);
      final edited = await service.appendMessageVersion(
        messageId: stored.id,
        content: 'edited',
      );

      expect(stored.turnId, user.turnId);
      expect(stored.generationStatus, ChatMessage.generationStatusFailed);
      expect(edited?.turnId, user.turnId);
      expect(edited?.generationStatus, ChatMessage.generationStatusCompleted);
    });

    test(
      'legacy groups migrate by logical order and stale drafts interrupt',
      () async {
        final appDataDir = await AppDirectories.getAppDataDirectory();
        await Hive.initFlutter(appDataDir.path);
        if (!Hive.isAdapterRegistered(0)) {
          Hive.registerAdapter(ChatMessageAdapter());
        }
        if (!Hive.isAdapterRegistered(1)) {
          Hive.registerAdapter(ConversationAdapter());
        }

        final conversations = await Hive.openBox<Conversation>('conversations');
        final messages = await Hive.openBox<ChatMessage>('messages');
        final toolEvents = await Hive.openBox('tool_events_v1');
        final user = ChatMessage(
          id: 'user-1',
          role: 'user',
          content: 'question',
          conversationId: 'conversation-1',
        );
        final firstAnswer = ChatMessage(
          id: 'answer-1',
          role: 'assistant',
          content: 'first',
          conversationId: 'conversation-1',
          groupId: 'answer-group',
        );
        final nextUser = ChatMessage(
          id: 'user-2',
          role: 'user',
          content: 'next question',
          conversationId: 'conversation-1',
        );
        final laterVersion = ChatMessage(
          id: 'answer-2',
          role: 'assistant',
          content: 'later version',
          conversationId: 'conversation-1',
          isStreaming: true,
          groupId: 'answer-group',
          version: 1,
        );
        final conversation = Conversation(
          id: 'conversation-1',
          title: 'Legacy',
          messageIds: [user.id, firstAnswer.id, nextUser.id, laterVersion.id],
        );
        await conversations.put(conversation.id, conversation);
        await messages.putAll({
          user.id: user,
          firstAnswer.id: firstAnswer,
          nextUser.id: nextUser,
          laterVersion.id: laterVersion,
        });
        await toolEvents.put('_active_streaming_ids', [laterVersion.id]);
        await Hive.close();

        final service = ChatService();
        await service.init();
        final migrated = {
          for (final message in service.getMessages(conversation.id))
            message.id: message,
        };

        expect(migrated[firstAnswer.id]?.turnId, user.turnId);
        expect(migrated[laterVersion.id]?.turnId, user.turnId);
        expect(migrated[nextUser.id]?.turnId, nextUser.turnId);
        expect(
          migrated[laterVersion.id]?.generationStatus,
          ChatMessage.generationStatusInterrupted,
        );
      },
    );
  });

  group('Chat sync boundary', () {
    test('conversation payload excludes local message projection', () {
      final conversation = Conversation(
        id: 'conversation-1',
        title: 'Cloud Chat',
        createdAt: DateTime.utc(2026, 7, 15, 8),
        updatedAt: DateTime.utc(2026, 7, 15, 9),
        messageIds: const <String>['local-only-message'],
        isPinned: true,
        mcpServerIds: const <String>['mcp-1'],
        assistantId: 'assistant-1',
        truncateIndex: 2,
        versionSelections: const <String, int>{'group-1': 1},
        summary: 'summary',
        lastSummarizedMessageCount: 2,
        chatSuggestions: const <String>['next'],
      );

      final payload = ChatSyncCodec.encodeConversation(conversation);
      final decoded = ChatSyncCodec.decodeConversation(
        conversation.id,
        payload,
      );

      expect(payload, isNot(contains('messageIds')));
      expect(payload, isNot(contains('versionSelections')));
      expect(decoded.messageIds, isEmpty);
      expect(decoded.title, conversation.title);
      expect(decoded.assistantId, conversation.assistantId);
      expect(
        () => ChatSyncCodec.decodeConversation(
          conversation.id,
          <String, Object?>{...payload, 'unexpected': true},
        ),
        throwsFormatException,
      );
    });

    test('draft assistant is skipped and terminal message round-trips', () {
      final draft = ChatMessage(
        id: 'draft-1',
        role: 'assistant',
        content: 'partial',
        conversationId: 'conversation-1',
        isStreaming: true,
        turnId: 'turn-1',
      );
      final terminal = ChatMessage(
        id: 'answer-1',
        role: 'assistant',
        content: '[image:C:\\local\\image.png]answer',
        timestamp: DateTime.utc(2026, 7, 15, 8, 1),
        modelId: 'model-1',
        providerId: 'provider-1',
        totalTokens: 12,
        conversationId: 'conversation-1',
        reasoningText: 'reasoning',
        groupId: 'answer-group',
        version: 1,
        promptTokens: 5,
        completionTokens: 7,
        cachedTokens: 2,
        durationMs: 300,
        turnId: 'turn-1',
        generationStatus: ChatMessage.generationStatusInterrupted,
      );

      expect(ChatSyncCodec.encodeMessage(draft), isNull);
      expect(
        () => ChatSyncCodec.encodeMessage(terminal),
        throwsFormatException,
      );

      final payload = ChatSyncCodec.encodeMessage(
        terminal,
        syncedContent: 'answer',
        attachments: const <ChatSyncAttachmentReference>[
          ChatSyncAttachmentReference(
            attachmentId: 'attachment-1',
            kind: ChatSyncAttachmentReference.imageKind,
            order: 0,
          ),
        ],
      )!;
      final decoded = ChatSyncCodec.decodeMessage(terminal.id, payload);

      expect(decoded.message.id, terminal.id);
      expect(decoded.message.turnId, terminal.turnId);
      expect(decoded.message.groupId, terminal.groupId);
      expect(decoded.message.generationStatus, terminal.generationStatus);
      expect(decoded.message.isStreaming, isFalse);
      expect(decoded.attachments.single.attachmentId, 'attachment-1');
      expect(decoded.attachments.single.order, 0);

      final malformed = Map<String, Object?>.of(payload)..remove('status');
      expect(
        () => ChatSyncCodec.decodeMessage(terminal.id, malformed),
        throwsFormatException,
      );
    });

    test(
      'remote turns deterministically rebuild and delete local order',
      () async {
        final service = ChatService();
        await service.init();

        final incomingConversation = Conversation(
          id: 'conversation-sync',
          title: 'Cloud Chat',
          createdAt: DateTime.utc(2026, 7, 15, 8),
          updatedAt: DateTime.utc(2026, 7, 15, 9),
          messageIds: const <String>['server-must-not-control-this'],
        );
        await service.upsertConversationFromSync(incomingConversation);
        expect(
          service.getConversation(incomingConversation.id)?.messageIds,
          isEmpty,
        );

        ChatMessage message({
          required String id,
          required String role,
          required String turnId,
          required DateTime timestamp,
        }) {
          return ChatMessage(
            id: id,
            role: role,
            content: id,
            timestamp: timestamp,
            conversationId: incomingConversation.id,
            turnId: turnId,
            generationStatus: ChatMessage.generationStatusCompleted,
          );
        }

        final earlyUser = message(
          id: 'early-user',
          role: 'user',
          turnId: 'turn-early',
          timestamp: DateTime.utc(2026, 7, 15, 10),
        );
        final earlyAssistant = message(
          id: 'early-assistant',
          role: 'assistant',
          turnId: 'turn-early',
          timestamp: DateTime.utc(2026, 7, 15, 10, 1),
        );
        final lateUser = message(
          id: 'late-user',
          role: 'user',
          turnId: 'turn-late',
          timestamp: DateTime.utc(2026, 7, 15, 9),
        );
        final lateAssistant = message(
          id: 'late-assistant',
          role: 'assistant',
          turnId: 'turn-late',
          timestamp: DateTime.utc(2026, 7, 15, 9, 1),
        );

        for (final remoteMessage in <ChatMessage>[
          earlyAssistant,
          lateAssistant,
          earlyUser,
          lateUser,
        ]) {
          await service.upsertMessageFromSync(remoteMessage);
        }
        await service.applyTurnFromSync(
          conversationId: incomingConversation.id,
          turnId: 'turn-late',
          createdAt: DateTime.utc(2026, 7, 15, 9),
        );
        await service.applyTurnFromSync(
          conversationId: incomingConversation.id,
          turnId: 'turn-early',
          createdAt: DateTime.utc(2026, 7, 15, 8, 30),
        );

        expect(
          service
              .getMessages(incomingConversation.id)
              .map((message) => message.id),
          <String>[
            earlyUser.id,
            earlyAssistant.id,
            lateUser.id,
            lateAssistant.id,
          ],
        );

        await service.upsertConversationFromSync(
          incomingConversation.copyWith(
            title: 'Updated Cloud Chat',
            messageIds: const <String>['still-not-authoritative'],
          ),
        );
        expect(
          service.getConversation(incomingConversation.id)?.messageIds,
          <String>[
            earlyUser.id,
            earlyAssistant.id,
            lateUser.id,
            lateAssistant.id,
          ],
        );

        await service.setSelectedVersion(
          incomingConversation.id,
          earlyAssistant.groupId!,
          earlyAssistant.version,
        );
        await service.deleteTurnFromSync(
          conversationId: incomingConversation.id,
          turnId: 'turn-early',
        );

        expect(
          service
              .getMessages(incomingConversation.id)
              .map((message) => message.id),
          <String>[lateUser.id, lateAssistant.id],
        );
        expect(
          service.getVersionSelections(incomingConversation.id),
          isNot(contains(earlyAssistant.groupId)),
        );
      },
    );
  });

  group('ChatService temporary conversations', () {
    test('ordinary draft persists when its first message is added', () async {
      final service = ChatService();
      await service.init();

      final conversation = await service.createDraftConversation(title: 'Chat');
      await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'hello',
      );

      expect(service.getAllConversations().map((c) => c.id), [conversation.id]);
      expect(service.getMessages(conversation.id), hasLength(1));
    });

    test(
      'temporary draft keeps messages in memory without entering history',
      () async {
        final service = ChatService();
        await service.init();

        final conversation = await service.createDraftConversation(
          title: 'Temporary Chat',
          temporary: true,
        );
        await service.addMessage(
          conversationId: conversation.id,
          role: 'user',
          content: 'secret',
        );

        expect(service.getAllConversations(), isEmpty);
        expect(service.getConversation(conversation.id), isNotNull);
        expect(service.getMessages(conversation.id), hasLength(1));
        expect(service.isTemporaryConversation(conversation.id), isTrue);
      },
    );

    test(
      'temporary conversation supports range and recent message reads',
      () async {
        final service = ChatService();
        await service.init();

        final conversation = await service.createDraftConversation(
          title: 'Temporary Chat',
          temporary: true,
        );
        for (var i = 0; i < 5; i++) {
          await service.addMessage(
            conversationId: conversation.id,
            role: i.isEven ? 'user' : 'assistant',
            content: 'temporary message $i',
          );
        }

        final range = service.getMessagesRange(
          conversation.id,
          start: 1,
          limit: 3,
        );
        final recent = service.getRecentMessages(
          conversation.id,
          minMessages: 2,
          maxMessages: 2,
        );

        expect(range.map((message) => message.content), [
          'temporary message 1',
          'temporary message 2',
          'temporary message 3',
        ]);
        expect(recent.map((message) => message.content), [
          'temporary message 3',
          'temporary message 4',
        ]);
      },
    );

    test(
      'temporary conversation is discarded when current conversation changes',
      () async {
        final service = ChatService();
        await service.init();

        final temporary = await service.createDraftConversation(
          title: 'Temporary Chat',
          temporary: true,
        );
        await service.addMessage(
          conversationId: temporary.id,
          role: 'user',
          content: 'secret',
        );

        final ordinary = await service.createDraftConversation(title: 'Chat');

        expect(service.getConversation(temporary.id), isNull);
        expect(service.getMessages(temporary.id), isEmpty);
        expect(service.currentConversationId, ordinary.id);
        expect(service.getAllConversations(), isEmpty);
      },
    );

    test('temporary message deletion only affects memory', () async {
      final service = ChatService();
      await service.init();

      final conversation = await service.createDraftConversation(
        title: 'Temporary Chat',
        temporary: true,
      );
      final message = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'secret',
      );

      await service.deleteMessage(message.id);

      expect(service.getAllConversations(), isEmpty);
      expect(service.getMessages(conversation.id), isEmpty);
      expect(service.getConversation(conversation.id)?.messageIds, isEmpty);
    });
  });

  group('ChatService fork conversations', () {
    test(
      'fork copies selected path as plain single-version messages',
      () async {
        final service = ChatService();
        await service.init();

        final source = await service.createConversation(title: 'Source');
        final user = await service.addMessage(
          conversationId: source.id,
          role: 'user',
          content: 'question',
        );
        final original = await service.addMessage(
          conversationId: source.id,
          role: 'assistant',
          content: 'original answer',
          turnId: user.turnId,
        );
        final edited = await service.appendMessageVersion(
          messageId: original.id,
          content: 'edited answer',
        );
        expect(edited, isNotNull);

        final fork = await service.forkConversation(
          title: 'Fork',
          assistantId: null,
          sourceMessages: [user, edited!],
        );

        final forkMessages = service.getMessages(fork.id);
        expect(forkMessages, hasLength(2));
        expect(forkMessages.first.conversationId, fork.id);
        expect(forkMessages.last.content, 'edited answer');
        expect(forkMessages.last.turnId, forkMessages.first.turnId);
        expect(
          forkMessages.last.groupId ?? forkMessages.last.id,
          forkMessages.last.id,
        );
        expect(forkMessages.last.version, 0);
        expect(service.getVersionSelections(fork.id), isEmpty);
      },
    );
  });
}
