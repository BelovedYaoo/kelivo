import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/database/chat_database_gateway.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/sync/sync_write_executor.dart';
import 'package:Kelivo/features/search/services/global_session_search_service.dart';

import '../database/test_database_cipher.dart';

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

final class _FailOncePreferencesStore extends SharedPreferencesStorePlatform {
  _FailOncePreferencesStore(Map<String, Object> values)
    : _values = Map<String, Object>.from(values);

  final Map<String, Object> _values;
  bool failNextAssistantWrite = false;

  @override
  Future<bool> clear() async {
    _values.clear();
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() async =>
      Map<String, Object>.from(_values);

  @override
  Future<bool> remove(String key) async {
    _values.remove(key);
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.assistants_v1' && failNextAssistantWrite) {
      failNextAssistantWrite = false;
      return false;
    }
    _values[key] = value;
    return true;
  }
}

Future<AssistantProvider> _createLoadedAssistantProvider({
  required ChatService chatService,
  List<Map<String, Object?>> assistants = const [
    {'id': 'assistant-delete', 'name': 'Delete Me'},
    {'id': 'assistant-keep', 'name': 'Keep Me'},
  ],
  String currentAssistantId = 'assistant-delete',
  _FailOncePreferencesStore? preferencesStore,
  SyncWriteExecutor syncWriteExecutor =
      const UntrackedSyncWriteExecutor.forTests(),
}) async {
  if (preferencesStore == null) {
    SharedPreferences.setMockInitialValues({
      'assistants_v1': jsonEncode(assistants),
      'current_assistant_id_v1': currentAssistantId,
    });
  } else {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = preferencesStore;
  }

  final provider = AssistantProvider(
    chatService: chatService,
    syncWriteExecutor: syncWriteExecutor,
  );
  for (var i = 0; i < 25; i++) {
    if (provider.assistants.length == assistants.length) return provider;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late SharedPreferencesStorePlatform previousPreferencesStore;
  final services = <ChatService>[];

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'kelivo_assistant_cascade_test_',
    );
    previousPreferencesStore = SharedPreferencesStorePlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    for (final service in services) {
      await service.close();
    }
    services.clear();
    await Hive.close();
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = previousPreferencesStore;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  ChatService createService([
    SyncWriteExecutor syncWriteExecutor =
        const UntrackedSyncWriteExecutor.forTests(),
  ]) {
    final service = ChatService(
      syncWriteExecutor,
      databaseGateway: ChatDatabaseGateway(cipher: testDatabaseCipher),
    );
    services.add(service);
    return service;
  }

  group('AssistantProvider cascade delete', () {
    test(
      'deletes conversations and messages owned by the deleted assistant',
      () async {
        final chatService = createService();
        await chatService.init();
        final provider = await _createLoadedAssistantProvider(
          chatService: chatService,
        );

        final deletedConversation = await chatService.createConversation(
          title: 'Deleted assistant chat',
          assistantId: 'assistant-delete',
        );
        await chatService.addMessage(
          conversationId: deletedConversation.id,
          role: 'user',
          content: 'unique-test-keyword-123',
        );

        final keptConversation = await chatService.createConversation(
          title: 'Kept assistant chat',
          assistantId: 'assistant-keep',
        );
        await chatService.addMessage(
          conversationId: keptConversation.id,
          role: 'user',
          content: 'keep-assistant-keyword-456',
        );

        expect(
          await GlobalSessionSearchService.search(
            chatService: chatService,
            query: 'unique-test-keyword-123',
          ),
          hasLength(1),
        );

        expect(await provider.deleteAssistant('assistant-delete'), isTrue);

        expect(chatService.getConversation(deletedConversation.id), isNull);
        expect(chatService.getMessages(deletedConversation.id), isEmpty);
        expect(
          await GlobalSessionSearchService.search(
            chatService: chatService,
            query: 'unique-test-keyword-123',
          ),
          isEmpty,
        );
        expect(
          await GlobalSessionSearchService.search(
            chatService: chatService,
            query: 'keep-assistant-keyword-456',
          ),
          hasLength(1),
        );
      },
    );

    test('共享仅本地写执行器时仍可级联删除持久化会话', () async {
      const executor = LocalOnlySyncWriteExecutor();
      final chatService = createService(executor);
      await chatService.init();
      final provider = await _createLoadedAssistantProvider(
        chatService: chatService,
        syncWriteExecutor: executor,
      );
      final conversation = await chatService.createConversation(
        title: 'Shared journal conversation',
        assistantId: 'assistant-delete',
      );

      expect(await provider.deleteAssistant('assistant-delete'), isTrue);

      expect(chatService.getConversation(conversation.id), isNull);
      expect(provider.getById('assistant-delete'), isNull);
    });

    test(
      'deletes draft conversations owned by the deleted assistant',
      () async {
        final chatService = createService();
        await chatService.init();
        final provider = await _createLoadedAssistantProvider(
          chatService: chatService,
        );

        final draft = await chatService.createDraftConversation(
          title: 'Draft assistant chat',
          assistantId: 'assistant-delete',
        );
        final keptDraft = await chatService.createDraftConversation(
          title: 'Kept draft chat',
          assistantId: 'assistant-keep',
        );

        expect(chatService.getConversation(draft.id), isNotNull);

        expect(await provider.deleteAssistant('assistant-delete'), isTrue);

        expect(chatService.getConversation(draft.id), isNull);
        expect(chatService.getConversation(keptDraft.id), isNotNull);
      },
    );

    test(
      'notifies once when deleting multiple assistant conversations',
      () async {
        final chatService = createService();
        await chatService.init();

        final first = await chatService.createConversation(
          title: 'First deleted chat',
          assistantId: 'assistant-delete',
        );
        await chatService.addMessage(
          conversationId: first.id,
          role: 'user',
          content: 'first-delete-keyword',
        );
        final second = await chatService.createConversation(
          title: 'Second deleted chat',
          assistantId: 'assistant-delete',
        );
        await chatService.addMessage(
          conversationId: second.id,
          role: 'user',
          content: 'second-delete-keyword',
        );
        final kept = await chatService.createConversation(
          title: 'Kept chat',
          assistantId: 'assistant-keep',
        );

        var notifications = 0;
        chatService.addListener(() {
          notifications++;
        });

        await chatService.deleteConversationsForAssistant('assistant-delete');

        expect(notifications, 1);
        expect(chatService.getConversation(first.id), isNull);
        expect(chatService.getConversation(second.id), isNull);
        expect(chatService.getConversation(kept.id), isNotNull);
      },
    );

    test(
      'keeps conversations when deleting the last assistant is rejected',
      () async {
        final chatService = createService();
        await chatService.init();
        final provider = await _createLoadedAssistantProvider(
          chatService: chatService,
          assistants: const [
            {'id': 'only-assistant', 'name': 'Only Assistant'},
          ],
          currentAssistantId: 'only-assistant',
        );

        final conversation = await chatService.createConversation(
          title: 'Only assistant chat',
          assistantId: 'only-assistant',
        );
        await chatService.addMessage(
          conversationId: conversation.id,
          role: 'user',
          content: 'last-assistant-keyword-789',
        );

        expect(await provider.deleteAssistant('only-assistant'), isFalse);

        expect(chatService.getConversation(conversation.id), isNotNull);
        expect(
          await GlobalSessionSearchService.search(
            chatService: chatService,
            query: 'last-assistant-keyword-789',
          ),
          hasLength(1),
        );
      },
    );

    test('持久化失败时会话删除可重试且助手不会永久短路', () async {
      const executor = LocalOnlySyncWriteExecutor();
      final chatService = createService(executor);
      await chatService.init();
      final assistants = <Map<String, Object?>>[
        {'id': 'assistant-delete', 'name': 'Delete Me'},
        {'id': 'assistant-keep', 'name': 'Keep Me'},
      ];
      final store = _FailOncePreferencesStore({
        'flutter.assistants_v1': jsonEncode(assistants),
        'flutter.current_assistant_id_v1': 'assistant-delete',
      });
      final provider = await _createLoadedAssistantProvider(
        chatService: chatService,
        assistants: assistants,
        preferencesStore: store,
        syncWriteExecutor: executor,
      );
      final conversation = await chatService.createConversation(
        title: 'Retry delete',
        assistantId: 'assistant-delete',
      );
      store.failNextAssistantWrite = true;

      await expectLater(
        provider.deleteAssistant('assistant-delete'),
        throwsA(isA<StateError>()),
      );

      expect(chatService.getConversation(conversation.id), isNull);
      expect(provider.assistants.map((assistant) => assistant.id), const [
        'assistant-delete',
        'assistant-keep',
      ]);

      expect(await provider.deleteAssistant('assistant-delete'), isTrue);
      expect(provider.assistants.map((assistant) => assistant.id), const [
        'assistant-keep',
      ]);
    });
  });
}
