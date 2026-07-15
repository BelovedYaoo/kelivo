import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
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
