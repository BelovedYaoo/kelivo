import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/assistant_memory.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/instruction_injection.dart';
import 'package:Kelivo/core/models/quick_phrase.dart';
import 'package:Kelivo/core/models/world_book.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/cloud_sync_provider.dart';
import 'package:Kelivo/core/providers/instruction_injection_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/memory_provider.dart';
import 'package:Kelivo/core/providers/quick_phrase_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/providers/world_book_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/chat/upload_directory_critical_section.dart';
import 'package:Kelivo/core/services/sync/chat_sync_adapter.dart';
import 'package:Kelivo/core/services/sync/chat_sync_codec.dart';
import 'package:Kelivo/core/services/sync/cloud_attachment_sync_service.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_client.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_store.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/sync/config_sync_adapter.dart';
import 'package:Kelivo/core/services/sync/sync_codec.dart';
import 'package:Kelivo/core/services/sync/sync_write_executor.dart';
import 'package:Kelivo/core/services/sync/sync_write_journal.dart';
import 'package:Kelivo/core/services/search/search_service.dart';
import 'package:Kelivo/core/services/tts/network_tts.dart';
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

class _RealHttpOverrides extends HttpOverrides {
  // 测试需要绕过 TestWidgetsFlutterBinding 注入的 HTTP 客户端。
  @override
  // ignore: unnecessary_overrides
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context);
  }
}

Future<T> _withRealHttpClient<T>(Future<T> Function() action) {
  final overrides = _RealHttpOverrides();
  return HttpOverrides.runZoned(
    action,
    createHttpClient: overrides.createHttpClient,
  );
}

final class _CloudSyncProviderFixture {
  _CloudSyncProviderFixture({
    required this.provider,
    required this.chatService,
    required this.store,
  });

  final CloudSyncProvider provider;
  final ChatService chatService;
  final CloudSyncStore store;
  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    provider.dispose();
  }

  Future<void> close() async {
    dispose();
    await waitUntilClosed();
  }

  Future<void> waitUntilClosed() async {
    for (var attempt = 0; attempt < 100; attempt++) {
      if (!Hive.isBoxOpen('cloud-sync-provider-login-test')) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError('CloudSyncProvider 未及时关闭同步存储');
  }
}

Future<_CloudSyncProviderFixture> _createCloudSyncProviderFixture(
  String hivePath,
) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  Hive.init(hivePath);
  PackageInfo.setMockInitialValues(
    appName: 'Kelivo',
    packageName: 'com.kelivo.test',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );
  final store = await CloudSyncStore.open(
    boxName: 'cloud-sync-provider-login-test',
  );
  final journal = SyncWriteJournal(
    store: store,
    journalScopeId: 'provider-login-test',
  );
  final chatService = ChatService(journal);
  final provider = CloudSyncProvider(
    chatService,
    store,
    journal,
    settingsProvider: SettingsProvider(syncWriteExecutor: journal),
    assistantProvider: AssistantProvider(syncWriteExecutor: journal),
    memoryProvider: MemoryProvider(syncWriteExecutor: journal),
    mcpProvider: McpProvider(syncWriteExecutor: journal),
    quickPhraseProvider: QuickPhraseProvider(syncWriteExecutor: journal),
    instructionInjectionProvider: InstructionInjectionProvider(
      syncWriteExecutor: journal,
    ),
    worldBookProvider: WorldBookProvider(syncWriteExecutor: journal),
    userProvider: UserProvider(syncWriteExecutor: journal),
    capturedConfigRescanGeneration: null,
  );
  return _CloudSyncProviderFixture(
    provider: provider,
    chatService: chatService,
    store: store,
  );
}

Future<HttpServer> _startCloudSyncLoginServer({
  List<String>? requestPaths,
  Completer<void>? loginRequestReceived,
  Future<void>? releaseLoginResponse,
  bool serveSuccessfulSync = false,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    requestPaths?.add(request.uri.path);
    await request.drain<void>();
    request.response.headers.contentType = ContentType.json;
    if (request.uri.path == '/api/auth/session/create') {
      if (loginRequestReceived != null && !loginRequestReceived.isCompleted) {
        loginRequestReceived.complete();
      }
      if (releaseLoginResponse != null) {
        await releaseLoginResponse;
      }
      request.response.write(
        jsonEncode(<String, Object?>{
          'data': <String, Object?>{
            'token': 'token-sync-user',
            'user': <String, Object?>{
              'id': 'sync-user',
              'loginName': 'sync-user',
              'displayName': 'sync-user',
              'role': 'user',
              'attachmentQuotaBytes': maximumCloudSyncAttachmentSizeBytes,
            },
            'device': <String, Object?>{
              'id': 'device-sync-user',
              'name': 'device',
              'platform': 'windows',
              'clientVersion': '1.0.0',
              'createdAt': '2026-07-15T00:00:00.000Z',
            },
          },
        }),
      );
    } else if (serveSuccessfulSync &&
        request.uri.path == '/api/sync/change/pull') {
      request.response.write(
        jsonEncode(<String, Object?>{
          'data': <String, Object?>{
            'changes': const <Object?>[],
            'nextCursor': 'cursor-0',
            'hasMore': false,
            'resetRequired': false,
          },
        }),
      );
    } else if (serveSuccessfulSync &&
        request.uri.path == '/api/sync/conflict/list') {
      request.response.write(
        jsonEncode(<String, Object?>{
          'data': <String, Object?>{'conflicts': const <Object?>[]},
        }),
      );
    } else {
      request.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..write(
          jsonEncode(<String, Object?>{
            'error': <String, Object?>{
              'code': 'SYNC_TEMPORARILY_UNAVAILABLE',
              'message': '暂时不可用',
            },
          }),
        );
    }
    await request.response.close();
  });
  return server;
}

final class _RecordingSyncWriteExecutor implements SyncWriteExecutor {
  final List<Set<SyncEntityKey>> batches = <Set<SyncEntityKey>>[];
  Future<void> Function()? onBatchWritten;
  int _batchDepth = 0;

  @override
  Future<T> runLocal<T>({
    required SyncEntityKey key,
    required Future<T> Function() write,
  }) {
    return runLocalBatch(keys: <SyncEntityKey>[key], write: write);
  }

  @override
  Future<T> runLocalBatch<T>({
    required Iterable<SyncEntityKey> keys,
    required Future<T> Function() write,
  }) async {
    if (_batchDepth > 0) return write();
    batches.add(Set<SyncEntityKey>.from(keys));
    _batchDepth++;
    try {
      final result = await write();
      await onBatchWritten?.call();
      return result;
    } finally {
      _batchDepth--;
    }
  }
}

CloudSyncAccountSession _cloudSession(
  String baseUrl, {
  String userId = 'sync-user',
}) {
  return CloudSyncAccountSession(
    baseUrl: baseUrl,
    token: 'token-$userId',
    userId: userId,
    loginName: userId,
    displayName: userId,
    role: CloudSyncUserRole.user,
    attachmentQuotaBytes: maximumCloudSyncAttachmentSizeBytes,
    deviceId: 'device-$userId',
    deviceName: 'device',
    platform: CloudSyncPlatform.windows,
    clientVersion: '1.0.0',
    deviceCreatedAt: DateTime.utc(2026, 7, 15),
  );
}

Future<ConfigSyncAdapter> _createPopulatedConfigSyncAdapter() async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  const syncWriteExecutor = UntrackedSyncWriteExecutor.forTests();
  final settings = SettingsProvider(syncWriteExecutor: syncWriteExecutor);
  final assistants = AssistantProvider(syncWriteExecutor: syncWriteExecutor);
  final memories = MemoryProvider(syncWriteExecutor: syncWriteExecutor);
  final mcp = McpProvider(syncWriteExecutor: syncWriteExecutor);
  final quickPhrases = QuickPhraseProvider(
    syncWriteExecutor: syncWriteExecutor,
  );
  final injections = InstructionInjectionProvider(
    syncWriteExecutor: syncWriteExecutor,
  );
  final worldBooks = WorldBookProvider(syncWriteExecutor: syncWriteExecutor);
  final user = UserProvider(syncWriteExecutor: syncWriteExecutor);
  await Future.wait<void>(<Future<void>>[
    settings.ready,
    assistants.ready,
    mcp.ready,
    user.ready,
    memories.initialize(),
    quickPhrases.initialize(),
    injections.initialize(),
    worldBooks.initialize(),
  ]);
  await assistants.syncUpsertAssistant(
    const Assistant(id: 'assistant-wire', name: 'Assistant'),
    position: 0,
  );
  await memories.syncUpsert(
    AssistantMemory(
      id: 1,
      syncId: 'memory-wire',
      assistantId: 'assistant-wire',
      content: 'Memory',
    ),
  );
  await worldBooks.syncUpsert(
    const WorldBook(id: 'world-book-wire', name: 'World Book'),
    position: 0,
  );
  await quickPhrases.syncUpsert(
    const QuickPhrase(
      id: 'quick-phrase-wire',
      title: 'Phrase',
      content: 'Content',
      isGlobal: false,
      assistantId: 'assistant-wire',
    ),
    position: 0,
  );
  await settings.syncUpsertSearchService(
    JinaOptions(id: 'search-wire', apiKey: 'search-key'),
    position: 0,
  );
  await settings.syncUpsertTtsService(
    OpenAiTtsOptions(
      id: 'tts-wire',
      enabled: false,
      name: 'TTS',
      apiKey: 'tts-key',
      baseUrl: 'https://example.com/v1',
      model: 'tts-model',
      voice: 'voice',
    ),
    position: 0,
  );
  await mcp.syncUpsertServer(
    McpServerConfig(
      id: 'mcp-wire',
      enabled: false,
      name: 'MCP',
      transport: McpTransportType.http,
      url: 'https://example.com/mcp',
    ),
    position: 0,
  );
  await injections.syncUpsert(
    const InstructionInjection(
      id: 'instruction-wire',
      title: 'Instruction',
      prompt: 'Prompt',
    ),
    position: 0,
  );
  final adapter = ConfigSyncAdapter(
    settingsProvider: settings,
    assistantProvider: assistants,
    memoryProvider: memories,
    mcpProvider: mcp,
    quickPhraseProvider: quickPhrases,
    instructionInjectionProvider: injections,
    worldBookProvider: worldBooks,
    userProvider: user,
  );
  await adapter.ready;
  return adapter;
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

  group('CloudSyncProvider 登录', () {
    test('空冲突且只有未来重试项时真实同步状态为待同步', () async {
      final server = await _startCloudSyncLoginServer(
        serveSuccessfulSync: true,
      );
      final fixture = await _createCloudSyncProviderFixture(tempDir.path);
      addTearDown(() async {
        await server.close(force: true);
        await fixture.close();
      });
      final baseUrl = 'http://${server.address.address}:${server.port}';
      final session = _cloudSession(baseUrl);
      await fixture.store.savePullCursor(session, 'cursor-0');
      await fixture.store.enqueueOutbox(
        session,
        CloudSyncOutboxMutation.create(
          mutationId: 'future-retry',
          entityType: CloudSyncEntityType.conversation,
          entityId: 'conversation-1',
          schemaVersion: 2,
          payload: const <String, Object?>{'title': '待同步会话'},
        ),
      );
      await fixture.store.markOutboxRetry(
        session,
        mutationId: 'future-retry',
        nextAttemptAt: DateTime.utc(2099),
      );

      final success = await _withRealHttpClient(
        () => fixture.provider.login(
          baseUrl: baseUrl,
          loginName: 'sync-user',
          password: 'password',
          deviceName: 'device',
        ),
      );

      expect(success, isFalse);
      expect(fixture.provider.lastError, isNull);
      expect(fixture.provider.conflicts, isEmpty);
      expect(fixture.provider.status, CloudSyncProviderStatus.pendingSync);
    });

    test('空冲突且存在永久阻塞项时真实同步状态为同步失败', () async {
      final server = await _startCloudSyncLoginServer(
        serveSuccessfulSync: true,
      );
      final fixture = await _createCloudSyncProviderFixture(tempDir.path);
      addTearDown(() async {
        await server.close(force: true);
        await fixture.close();
      });
      final baseUrl = 'http://${server.address.address}:${server.port}';
      final session = _cloudSession(baseUrl);
      await fixture.store.savePullCursor(session, 'cursor-0');
      await fixture.store.enqueueOutbox(
        session,
        CloudSyncOutboxMutation.create(
          mutationId: 'blocked-mutation',
          entityType: CloudSyncEntityType.conversation,
          entityId: 'conversation-1',
          schemaVersion: 2,
          payload: const <String, Object?>{'title': '失败会话'},
        ),
      );
      await fixture.store.markOutboxBlocked(
        session,
        mutationId: 'blocked-mutation',
        errorCode: 'SYNC_PAYLOAD_INVALID',
      );

      final success = await _withRealHttpClient(
        () => fixture.provider.login(
          baseUrl: baseUrl,
          loginName: 'sync-user',
          password: 'password',
          deviceName: 'device',
        ),
      );

      expect(success, isFalse);
      expect(fixture.provider.lastError, isNull);
      expect(fixture.provider.conflicts, isEmpty);
      expect(fixture.provider.status, CloudSyncProviderStatus.syncBlocked);
    });

    test('登录时替换旧版助手媒体缺键载荷但保留其他阻塞项', () async {
      final server = await _startCloudSyncLoginServer();
      final fixture = await _createCloudSyncProviderFixture(tempDir.path);
      addTearDown(() async {
        await server.close(force: true);
        await fixture.close();
      });
      final baseUrl = 'http://${server.address.address}:${server.port}';
      final session = _cloudSession(baseUrl);
      await fixture.store.enqueueOutbox(
        session,
        CloudSyncOutboxMutation.create(
          mutationId: 'assistant-invalid-payload',
          entityType: CloudSyncEntityType.assistant,
          entityId: 'assistant-1',
          schemaVersion: 2,
          payload: const <String, Object?>{'name': '助手'},
        ),
      );
      await fixture.store.markOutboxBlocked(
        session,
        mutationId: 'assistant-invalid-payload',
        errorCode: 'SYNC_PAYLOAD_INVALID',
      );
      await fixture.store.enqueueOutbox(
        session,
        CloudSyncOutboxMutation.create(
          mutationId: 'assistant-other-invalid-payload',
          entityType: CloudSyncEntityType.assistant,
          entityId: 'assistant-2',
          schemaVersion: 2,
          payload: const <String, Object?>{
            'name': '其他无效助手',
            'avatar': null,
            'background': null,
          },
        ),
      );
      await fixture.store.markOutboxBlocked(
        session,
        mutationId: 'assistant-other-invalid-payload',
        errorCode: 'SYNC_PAYLOAD_INVALID',
      );
      await fixture.store.enqueueOutbox(
        session,
        CloudSyncOutboxMutation.update(
          mutationId: 'assistant-invalid-patch',
          entityType: CloudSyncEntityType.assistant,
          entityId: 'assistant-3',
          baseRevision: 1,
          schemaVersion: 2,
          patch: <CloudSyncPatch>[
            CloudSyncPatch.remove('/avatar'),
            CloudSyncPatch.remove('/background'),
          ],
        ),
      );
      await fixture.store.markOutboxBlocked(
        session,
        mutationId: 'assistant-invalid-patch',
        errorCode: 'SYNC_PAYLOAD_INVALID',
      );
      await fixture.store.enqueueOutbox(
        session,
        CloudSyncOutboxMutation.create(
          mutationId: 'message-invalid-payload',
          entityType: CloudSyncEntityType.message,
          entityId: 'message-1',
          parentId: 'turn-1',
          schemaVersion: 2,
          payload: const <String, Object?>{},
        ),
      );
      await fixture.store.markOutboxBlocked(
        session,
        mutationId: 'message-invalid-payload',
        errorCode: 'SYNC_PAYLOAD_INVALID',
      );

      await _withRealHttpClient(
        () => fixture.provider.login(
          baseUrl: baseUrl,
          loginName: 'sync-user',
          password: 'password',
          deviceName: 'device',
        ),
      );

      expect(
        fixture.store
            .blockedOutbox(session)
            .map((mutation) => mutation.mutationId),
        unorderedEquals(<String>[
          'assistant-other-invalid-payload',
          'message-invalid-payload',
        ]),
      );
      final replacement = fixture.store
          .outboxForEntity(
            session,
            entityType: CloudSyncEntityType.assistant,
            entityId: 'assistant-1',
          )
          .single;
      expect(replacement.mutationId, isNot('assistant-invalid-payload'));
      expect(replacement.blockedAt, isNull);
      expect(replacement.payload, containsPair('avatar', null));
      expect(replacement.payload, containsPair('background', null));
      final updateReplacement = fixture.store
          .outboxForEntity(
            session,
            entityType: CloudSyncEntityType.assistant,
            entityId: 'assistant-3',
          )
          .single;
      expect(updateReplacement.mutationId, isNot('assistant-invalid-patch'));
      expect(updateReplacement.blockedAt, isNull);
      expect(
        updateReplacement.patch.map((patch) => patch.toJson()),
        <Map<String, Object?>>[
          <String, Object?>{'op': 'replace', 'path': '/avatar', 'value': null},
          <String, Object?>{
            'op': 'replace',
            'path': '/background',
            'value': null,
          },
        ],
      );
      expect(fixture.store.configRescanGeneration, isNull);
    });

    test('首次同步失败时保留认证会话并返回失败状态', () async {
      final server = await _startCloudSyncLoginServer();
      final fixture = await _createCloudSyncProviderFixture(tempDir.path);
      addTearDown(() async {
        await server.close(force: true);
        await fixture.close();
      });
      final baseUrl = 'http://${server.address.address}:${server.port}';

      final success = await _withRealHttpClient(
        () => fixture.provider.login(
          baseUrl: baseUrl,
          loginName: 'sync-user',
          password: 'password',
          deviceName: 'device',
        ),
      );

      expect(success, isFalse);
      expect(fixture.provider.signedIn, isTrue);
      expect(fixture.provider.status, CloudSyncProviderStatus.error);
      expect(fixture.provider.lastError, isNotNull);
    });

    test('写前日志恢复失败时保留认证会话并返回失败状态', () async {
      final server = await _startCloudSyncLoginServer();
      final fixture = await _createCloudSyncProviderFixture(tempDir.path);
      addTearDown(() async {
        await server.close(force: true);
        await fixture.close();
      });
      final baseUrl = 'http://${server.address.address}:${server.port}';
      await fixture.provider.initialize();
      final conversation = await fixture.chatService.createConversation(
        title: 'Chat',
      );
      final message = await fixture.chatService.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'hello',
      );
      await fixture.store.saveShadow(
        _cloudSession(baseUrl),
        CloudSyncShadow(
          entityType: CloudSyncEntityType.message,
          entityId: message.id,
          parentId: 'wrong-turn',
          revision: 1,
          schemaVersion: 2,
          lastChangeSeq: 1,
          deleted: false,
          payload: ChatSyncCodec.encodeMessage(
            message,
            syncedContent: message.content,
          ),
          updatedAt: DateTime.utc(2026, 7, 15),
        ),
      );

      final success = await _withRealHttpClient(
        () => fixture.provider.login(
          baseUrl: baseUrl,
          loginName: 'sync-user',
          password: 'password',
          deviceName: 'device',
        ),
      );

      expect(success, isFalse);
      expect(fixture.provider.signedIn, isTrue);
      expect(fixture.provider.status, CloudSyncProviderStatus.error);
      expect(fixture.provider.lastError, isNotNull);
    });
  });

  group('CloudSyncProvider 生命周期', () {
    test('首次同步失败后退出仍清除认证会话和本地同步状态', () async {
      final server = await _startCloudSyncLoginServer();
      final fixture = await _createCloudSyncProviderFixture(tempDir.path);
      addTearDown(() async {
        await server.close(force: true);
        await fixture.close();
      });
      final baseUrl = 'http://${server.address.address}:${server.port}';

      final loginSuccess = await _withRealHttpClient(
        () => fixture.provider.login(
          baseUrl: baseUrl,
          loginName: 'sync-user',
          password: 'password',
          deviceName: 'device',
        ),
      );
      final logoutSuccess = await fixture.provider.logout(clearSyncState: true);

      expect(loginSuccess, isFalse);
      expect(logoutSuccess, isTrue);
      expect(fixture.provider.signedIn, isFalse);
      expect(fixture.provider.paused, isFalse);
      expect(fixture.provider.status, CloudSyncProviderStatus.signedOut);
      expect(fixture.store.activeSession, isNull);
    });

    test('暂停时拒绝手动同步且恢复后重新发起同步', () async {
      final requestPaths = <String>[];
      final server = await _startCloudSyncLoginServer(
        requestPaths: requestPaths,
      );
      final fixture = await _createCloudSyncProviderFixture(tempDir.path);
      addTearDown(() async {
        await server.close(force: true);
        await fixture.close();
      });
      final baseUrl = 'http://${server.address.address}:${server.port}';

      await _withRealHttpClient(() async {
        await fixture.provider.login(
          baseUrl: baseUrl,
          loginName: 'sync-user',
          password: 'password',
          deviceName: 'device',
        );
        expect(await fixture.provider.setPaused(true), isTrue);
        final requestCountWhilePaused = requestPaths.length;

        expect(await fixture.provider.syncNow(), isFalse);
        expect(requestPaths, hasLength(requestCountWhilePaused));
        expect(fixture.provider.paused, isTrue);
        expect(fixture.provider.status, CloudSyncProviderStatus.paused);

        expect(await fixture.provider.setPaused(false), isTrue);
        expect(await fixture.provider.syncNow(), isFalse);
        expect(requestPaths.length, greaterThan(requestCountWhilePaused));
        expect(fixture.provider.paused, isFalse);
        expect(fixture.provider.status, CloudSyncProviderStatus.error);
      });
    });

    test('登录请求进行中销毁会等待会话变更完成后关闭存储', () async {
      final loginRequestReceived = Completer<void>();
      final releaseLoginResponse = Completer<void>();
      final server = await _startCloudSyncLoginServer(
        loginRequestReceived: loginRequestReceived,
        releaseLoginResponse: releaseLoginResponse.future,
      );
      final fixture = await _createCloudSyncProviderFixture(tempDir.path);
      addTearDown(() async {
        if (!releaseLoginResponse.isCompleted) {
          releaseLoginResponse.complete();
        }
        await server.close(force: true);
        await fixture.close();
      });
      final baseUrl = 'http://${server.address.address}:${server.port}';

      final login = _withRealHttpClient(
        () => fixture.provider.login(
          baseUrl: baseUrl,
          loginName: 'sync-user',
          password: 'password',
          deviceName: 'device',
        ),
      );
      await loginRequestReceived.future.timeout(const Duration(seconds: 2));

      fixture.dispose();
      releaseLoginResponse.complete();

      expect(await login, isFalse);
      await fixture.waitUntilClosed();
      expect(Hive.isBoxOpen('cloud-sync-provider-login-test'), isFalse);
    });
  });

  group('ChatService turn identities', () {
    test('流式更新不记日志且终态只提交一个完整批次', () async {
      final writes = _RecordingSyncWriteExecutor();
      final service = ChatService(writes);
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
      writes.batches.clear();

      await service.updateMessageSilent(assistant.id, content: 'partial');
      await service.setToolEvents(assistant.id, <Map<String, dynamic>>[
        <String, dynamic>{'id': 'tool-1', 'name': 'search'},
      ]);
      await service.setGeminiThoughtSignature(assistant.id, 'signature');

      expect(writes.batches, isEmpty);

      await service.updateMessageSilent(
        assistant.id,
        content: 'answer',
        reasoningText: 'final reasoning',
        isStreaming: false,
        generationStatus: ChatMessage.generationStatusCompleted,
      );

      expect(writes.batches, hasLength(1));
      expect(writes.batches.single, <SyncEntityKey>{
        SyncEntityKey(entityType: 'conversation', entityId: conversation.id),
        SyncEntityKey(entityType: 'turn', entityId: user.turnId),
        SyncEntityKey(entityType: 'message', entityId: assistant.id),
        SyncEntityKey(entityType: 'tool-event', entityId: assistant.id),
        SyncEntityKey(entityType: 'thought-signature', entityId: assistant.id),
      });
      final stored = service.getMessageById(assistant.id);
      expect(stored?.content, 'answer');
      expect(stored?.reasoningText, 'final reasoning');
    });

    test('失败终态也只提交一个完整批次', () async {
      final writes = _RecordingSyncWriteExecutor();
      final service = ChatService(writes);
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
      writes.batches.clear();

      await service.updateMessage(
        assistant.id,
        content: 'partial error',
        isStreaming: false,
        generationStatus: ChatMessage.generationStatusFailed,
      );

      expect(writes.batches, hasLength(1));
      expect(
        service.getMessageById(assistant.id)?.generationStatus,
        ChatMessage.generationStatusFailed,
      );
    });

    test('删除消息在一个批次中声明全部派生实体', () async {
      final writes = _RecordingSyncWriteExecutor();
      final service = ChatService(writes);
      await service.init();
      final conversation = await service.createConversation(title: 'Chat');
      final message = await service.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        content: 'answer',
        turnId: 'turn-delete',
        groupId: 'group-delete',
        generationStatus: ChatMessage.generationStatusCompleted,
      );
      await service.setSelectedVersion(conversation.id, 'group-delete', 0);
      await service.setToolEvents(message.id, const <Map<String, dynamic>>[]);
      await service.setGeminiThoughtSignature(message.id, 'signature');
      writes.batches.clear();

      await service.deleteMessage(message.id);

      expect(writes.batches, hasLength(1));
      expect(writes.batches.single, <SyncEntityKey>{
        SyncEntityKey(entityType: 'message', entityId: message.id),
        const SyncEntityKey(entityType: 'turn', entityId: 'turn-delete'),
        const SyncEntityKey(
          entityType: 'message-selection',
          entityId: 'group-delete',
        ),
        SyncEntityKey(entityType: 'tool-event', entityId: message.id),
        SyncEntityKey(entityType: 'thought-signature', entityId: message.id),
      });
      expect(service.getMessageById(message.id), isNull);
    });

    test('版本选择与会话更新时间在同一批次提交', () async {
      final writes = _RecordingSyncWriteExecutor();
      final service = ChatService(writes);
      await service.init();
      final conversation = await service.createConversation(title: 'Chat');
      final beforeSet = conversation.updatedAt;
      writes.batches.clear();
      await Future<void>.delayed(const Duration(milliseconds: 2));

      await service.setSelectedVersion(conversation.id, 'group-select', 1);

      final afterSet = service.getConversation(conversation.id)!.updatedAt;
      expect(afterSet.isAfter(beforeSet), isTrue);
      expect(writes.batches, hasLength(1));
      expect(writes.batches.single, <SyncEntityKey>{
        SyncEntityKey(entityType: 'conversation', entityId: conversation.id),
        const SyncEntityKey(
          entityType: 'message-selection',
          entityId: 'group-select',
        ),
      });

      writes.batches.clear();
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await service.clearSelectedVersion(conversation.id, 'group-select');

      expect(
        service.getConversation(conversation.id)!.updatedAt.isAfter(afterSet),
        isTrue,
      );
      expect(writes.batches, hasLength(1));
      expect(writes.batches.single, <SyncEntityKey>{
        SyncEntityKey(entityType: 'conversation', entityId: conversation.id),
        const SyncEntityKey(
          entityType: 'message-selection',
          entityId: 'group-select',
        ),
      });
    });

    test('多消息删除去重实体键并只提交一次', () async {
      final writes = _RecordingSyncWriteExecutor();
      final service = ChatService(writes);
      await service.init();
      final conversation = await service.createConversation(title: 'Chat');
      final first = await service.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        content: 'first',
        turnId: 'shared-turn',
        groupId: 'shared-group',
        version: 0,
      );
      final second = await service.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        content: 'second',
        turnId: 'shared-turn',
        groupId: 'shared-group',
        version: 1,
      );
      await service.setSelectedVersion(conversation.id, 'shared-group', 1);
      writes.batches.clear();

      await service.deleteMessagesWithSelections(
        conversationId: conversation.id,
        messageIds: <String>[second.id, first.id, second.id],
        versionSelections: const <String, int?>{'shared-group': null},
      );

      expect(writes.batches, hasLength(1));
      expect(writes.batches.single, hasLength(8));
      expect(service.getMessages(conversation.id), isEmpty);
      expect(service.getVersionSelections(conversation.id), isEmpty);
    });

    test('临时会话批量删除保持内存态且不写日志', () async {
      final writes = _RecordingSyncWriteExecutor();
      final service = ChatService(writes);
      await service.init();
      final conversation = await service.createDraftConversation(
        title: 'Temporary',
        temporary: true,
      );
      final message = await service.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        content: 'answer',
        groupId: 'temporary-group',
      );
      writes.batches.clear();

      await service.deleteMessagesWithSelections(
        conversationId: conversation.id,
        messageIds: <String>[message.id],
        versionSelections: const <String, int?>{'temporary-group': null},
      );

      expect(writes.batches, isEmpty);
      expect(service.getMessageById(message.id), isNull);
      expect(service.getMessages(conversation.id), isEmpty);
    });

    test('覆盖导入清空与恢复只提交最终状态批次', () async {
      final writes = _RecordingSyncWriteExecutor();
      final service = ChatService(writes);
      await service.init();
      final oldConversation = await service.createConversation(title: 'Old');
      await service.addMessage(
        conversationId: oldConversation.id,
        role: 'user',
        content: 'old',
      );
      final incomingConversation = Conversation(
        id: 'imported-conversation',
        title: 'Imported',
      );
      final incomingMessage = ChatMessage(
        id: 'imported-message',
        role: 'user',
        content: 'new',
        conversationId: incomingConversation.id,
      );
      writes.batches.clear();
      var notificationCount = 0;
      service.addListener(() => notificationCount++);

      await service.runImportBatch<void>(
        overwrite: true,
        conversations: <Conversation>[incomingConversation],
        messages: <ChatMessage>[incomingMessage],
        write: () async {
          await service.clearAllData();
          await service.restoreConversation(incomingConversation, <ChatMessage>[
            incomingMessage,
          ]);
        },
      );

      expect(writes.batches, hasLength(1));
      expect(writes.batches.single.length, 6);
      expect(notificationCount, 1);
      expect(service.getConversation(oldConversation.id), isNull);
      expect(service.getMessageById(incomingMessage.id), isNotNull);
    });

    test('message writes preserve turn and explicit terminal status', () async {
      final service = ChatService(const UntrackedSyncWriteExecutor.forTests());
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

        final writes = _RecordingSyncWriteExecutor();
        late ChatService service;
        writes.onBatchWritten = () async {
          expect(service.initialized, isTrue);
        };
        service = ChatService(writes);
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
        expect(writes.batches, hasLength(1));
        expect(
          writes.batches.single,
          contains(
            SyncEntityKey(entityType: 'message', entityId: laterVersion.id),
          ),
        );
      },
    );
  });

  group('Chat sync boundary', () {
    test('local sync entities use protocol schema version 2 by default', () {
      final entity = LocalSyncEntity(
        entityType: 'conversation',
        entityId: 'conversation-1',
        payload: const <String, Object?>{'title': 'Chat'},
      );

      expect(entity.schemaVersion, 2);
    });

    test('message sync entities belong to their turn', () async {
      final chatService = ChatService(
        const UntrackedSyncWriteExecutor.forTests(),
      );
      await chatService.init();
      final store = await CloudSyncStore.open(
        boxName: 'cloud_sync_message_parent_test',
      );
      final client = CloudSyncClient(baseUrl: 'http://127.0.0.1:1');
      addTearDown(() async {
        client.close(force: true);
        await store.close();
      });
      final adapter = ChatSyncAdapter(
        chatService,
        CloudAttachmentSyncService(
          _cloudSession(client.baseUrl),
          client,
          store,
        ),
      );
      final conversation = await chatService.createConversation(title: 'Chat');
      final message = await chatService.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'question',
      );

      final entity = (await adapter.exportLocalEntities()).singleWhere(
        (candidate) =>
            candidate.entityType == ChatSyncAdapter.messageType &&
            candidate.entityId == message.id,
      );

      expect(entity.parentId, message.turnId);
    });

    test(
      'instruction injections export as standalone ordered entities',
      () async {
        final adapter = await _createPopulatedConfigSyncAdapter();

        final entity = (await adapter.exportLocalEntities()).singleWhere(
          (candidate) => candidate.payload['prompt'] == 'Prompt',
        );

        expect(entity.entityType, 'instruction-injection');
        expect(entity.entityId, 'instruction-wire');
        expect(entity.payload, isNot(contains('id')));
        expect(entity.payload['_position'], 0);
      },
    );

    test('configuration adapter exports one requested key', () async {
      final adapter = await _createPopulatedConfigSyncAdapter();
      const key = SyncEntityKey(
        entityType: 'assistant',
        entityId: 'assistant-wire',
      );

      final entity = await adapter.exportLocalEntity(key);

      expect(entity?.key, key);
      expect(entity?.payload['name'], 'Assistant');
      expect(
        await adapter.exportLocalEntity(
          const SyncEntityKey(
            entityType: 'assistant',
            entityId: 'assistant-missing',
          ),
        ),
        isNull,
      );
      final batch = await adapter.exportLocalEntitiesForKeys(<SyncEntityKey>{
        key,
        SyncEntityKey(entityType: 'assistant', entityId: 'assistant-missing'),
      });
      expect(batch.keys, <SyncEntityKey>{key});
      expect(batch[key]?.payload['name'], 'Assistant');
    });

    test(
      'configuration wire payloads use envelope identity and explicit order',
      () async {
        final adapter = await _createPopulatedConfigSyncAdapter();
        final entities = await adapter.exportLocalEntities();
        final ordered = <LocalSyncEntity>[
          entities.firstWhere((entity) => entity.entityType == 'provider'),
          entities.singleWhere(
            (entity) =>
                entity.entityType == 'assistant' &&
                entity.entityId == 'assistant-wire',
          ),
          entities.singleWhere(
            (entity) =>
                entity.entityType == 'world-book' &&
                entity.entityId == 'world-book-wire',
          ),
          entities.singleWhere(
            (entity) =>
                entity.entityType == 'quick-phrase' &&
                entity.entityId == 'quick-phrase-wire',
          ),
          entities.singleWhere(
            (entity) =>
                entity.entityType == 'search-service' &&
                entity.entityId == 'search-wire',
          ),
          entities.singleWhere(
            (entity) =>
                entity.entityType == 'network-tts' &&
                entity.entityId == 'tts-wire',
          ),
          entities.singleWhere(
            (entity) =>
                entity.entityType == 'mcp-server' &&
                entity.entityId == 'mcp-wire',
          ),
          entities.singleWhere(
            (entity) =>
                entity.entityType == 'instruction-injection' &&
                entity.entityId == 'instruction-wire',
          ),
        ];
        for (final entity in ordered) {
          expect(entity.schemaVersion, 2, reason: entity.entityType);
          expect(
            entity.payload,
            isNot(contains('id')),
            reason: entity.entityType,
          );
          expect(
            entity.payload['_position'],
            isA<int>().having(
              (value) => value,
              'value',
              greaterThanOrEqualTo(0),
            ),
            reason: entity.entityType,
          );
        }

        final memory = entities.singleWhere(
          (entity) =>
              entity.entityType == 'memory' && entity.entityId == 'memory-wire',
        );
        expect(memory.parentId, 'assistant-wire');
        expect(memory.payload, isNot(contains('id')));
        expect(memory.payload, isNot(contains('syncId')));

        final quickPhrase = entities.singleWhere(
          (entity) =>
              entity.entityType == 'quick-phrase' &&
              entity.entityId == 'quick-phrase-wire',
        );
        expect(quickPhrase.parentId, 'assistant-wire');

        final profile = entities.singleWhere(
          (entity) =>
              entity.entityType == 'user-preference' &&
              entity.entityId == 'profile:default',
        );
        expect(profile.payload['name'], 'User');
        expect(profile.payload, isNot(contains('key')));
        expect(profile.payload, isNot(contains('value')));
      },
    );

    test(
      'configuration adapters restore local identity from the envelope',
      () async {
        final adapter = await _createPopulatedConfigSyncAdapter();
        final exported = await adapter.exportLocalEntities();
        const replayTypes = <String>{
          'provider',
          'assistant',
          'memory',
          'world-book',
          'quick-phrase',
          'search-service',
          'network-tts',
          'mcp-server',
          'instruction-injection',
        };
        final replayed = exported
            .where((entity) => replayTypes.contains(entity.entityType))
            .toList(growable: false);

        for (final entity in replayed) {
          await adapter.applyRemoteUpsert(
            RemoteSyncEntity(
              entityType: entity.entityType,
              entityId: entity.entityId,
              parentId: entity.parentId,
              revision: 1,
              schemaVersion: entity.schemaVersion,
              payload: entity.payload,
              updatedAt: DateTime.utc(2026, 7, 16),
            ),
          );
        }

        final after = <SyncEntityKey, LocalSyncEntity>{
          for (final entity in await adapter.exportLocalEntities())
            entity.key: entity,
        };
        for (final entity in replayed) {
          expect(after, contains(entity.key), reason: entity.entityType);
          expect(
            canonicalSyncJson(after[entity.key]!.payload),
            canonicalSyncJson(entity.payload),
            reason: entity.entityType,
          );
        }
      },
    );

    test('ordered configuration payloads reject a missing position', () async {
      final adapter = await _createPopulatedConfigSyncAdapter();
      const orderedTypes = <String>{
        'provider',
        'assistant',
        'world-book',
        'quick-phrase',
        'search-service',
        'network-tts',
        'mcp-server',
        'instruction-injection',
      };
      final entities = (await adapter.exportLocalEntities())
          .where((entity) => orderedTypes.contains(entity.entityType))
          .toList(growable: false);

      for (final entity in entities) {
        final payload = Map<String, Object?>.from(entity.payload)
          ..remove('_position');
        await expectLater(
          adapter.applyRemoteUpsert(
            RemoteSyncEntity(
              entityType: entity.entityType,
              entityId: entity.entityId,
              parentId: entity.parentId,
              revision: 1,
              schemaVersion: entity.schemaVersion,
              payload: payload,
              updatedAt: DateTime.utc(2026, 7, 16),
            ),
          ),
          throwsFormatException,
          reason: entity.entityType,
        );
      }
    });

    test('attachment markers strip local paths and restore stable order', () {
      final document = ChatAttachmentMarkerCodec.parse(
        'question\n'
        r'[image:C:\uploads\photo.JPG]'
        '\n'
        r'[file:C:\uploads\report.pdf|报告.pdf|application/pdf]',
      );

      expect(document.contentWithoutMarkers, 'question');
      expect(document.markers, hasLength(2));
      expect(document.markers.first.order, 0);
      expect(document.markers.first.fileName, 'photo.JPG');
      expect(document.markers.first.mimeType, 'image/jpeg');
      expect(document.markers.last.order, 1);
      expect(document.markers.last.fileName, '报告.pdf');
      expect(document.markers.last.mimeType, 'application/pdf');
      expect(document.contentWithoutMarkers, isNot(contains('C:\\uploads')));

      final restored = ChatAttachmentMarkerCodec.restore(
        document.contentWithoutMarkers,
        document.markers,
      );
      expect(
        restored,
        'question\n'
        r'[image:C:\uploads\photo.JPG]'
        '\n'
        r'[file:C:\uploads\report.pdf|报告.pdf|application/pdf]',
      );
      expect(
        ChatAttachmentMarkerCodec.parse(restored).contentWithoutMarkers,
        document.contentWithoutMarkers,
      );
    });

    test('attachment marker codec preserves ordinary marker-like text', () {
      const malformed = r'[file:C:\uploads\report.pdf||application/pdf]';
      final malformedDocument = ChatAttachmentMarkerCodec.parse(malformed);
      expect(malformedDocument.markers, isEmpty);
      expect(malformedDocument.contentWithoutMarkers, malformed);

      const inline =
          'ordinary [file:C:\\uploads\\report.pdf|report.pdf|application/pdf]';
      final inlineDocument = ChatAttachmentMarkerCodec.parse(inline);
      expect(inlineDocument.markers, isEmpty);
      expect(inlineDocument.contentWithoutMarkers, inline);

      final marker = ChatAttachmentMarkerCodec.parse(
        r'[image:C:\uploads\photo.png]',
      ).markers.single;
      expect(
        () => ChatAttachmentMarkerCodec.restore('', <ChatAttachmentMarker>[
          marker,
          marker,
        ]),
        throwsFormatException,
      );

      const remoteMarkers =
          '[image:https://cdn.example.com/photo.png]\n'
          '[file:https://cdn.example.com/report.pdf|report.pdf|application/pdf]';
      final remoteDocument = ChatAttachmentMarkerCodec.parse(remoteMarkers);
      expect(remoteDocument.markers, isEmpty);
      expect(remoteDocument.contentWithoutMarkers, remoteMarkers);
      expect(
        () => CloudSyncAttachmentDownload(
          attachmentId: '../outside',
          downloadUrl: 'https://storage.example.com/object',
          expiresAt: DateTime.utc(2026, 7, 15),
        ),
        throwsFormatException,
      );
    });

    test('cloud sync transport only permits secure or loopback URLs', () {
      expect(
        normalizeCloudSyncBaseUrl('https://sync.example.com/'),
        'https://sync.example.com',
      );
      expect(
        normalizeCloudSyncBaseUrl('http://localhost:8787'),
        'http://localhost:8787',
      );
      expect(
        normalizeCloudSyncBaseUrl('http://127.0.0.1:8787'),
        'http://127.0.0.1:8787',
      );
      expect(
        normalizeCloudSyncBaseUrl('http://[::1]:8787'),
        'http://[::1]:8787',
      );
      expect(
        () => normalizeCloudSyncBaseUrl('http://sync.example.com'),
        throwsFormatException,
      );
      expect(
        () => CloudSyncAttachmentDownload(
          attachmentId: '11111111-1111-5111-8111-111111111111',
          downloadUrl: 'http://storage.example.com/object',
          expiresAt: DateTime.utc(2026, 7, 15),
        ),
        throwsFormatException,
      );
    });

    test('attachment bindings persist within their account scope', () async {
      final chatService = ChatService(
        const UntrackedSyncWriteExecutor.forTests(),
      );
      await chatService.init();
      final store = await CloudSyncStore.open(
        boxName: 'cloud_sync_attachment_test',
      );
      CloudSyncAccountSession session(String userId) {
        return CloudSyncAccountSession(
          baseUrl: 'https://sync.example.com',
          token: 'token-$userId',
          userId: userId,
          loginName: userId,
          displayName: userId,
          role: CloudSyncUserRole.user,
          attachmentQuotaBytes: 1024,
          deviceId: 'device-$userId',
          deviceName: 'device',
          platform: CloudSyncPlatform.windows,
          clientVersion: '1.0.0',
          deviceCreatedAt: DateTime.utc(2026, 7, 15),
        );
      }

      final firstAccount = session('first-user');
      final secondAccount = session('second-user');
      final binding = CloudSyncAttachmentBinding(
        messageId: 'message-1',
        attachmentId: '11111111-1111-5111-8111-111111111111',
        kind: CloudSyncAttachmentKind.file,
        order: 0,
        localPath: r'C:\uploads\report.pdf',
        modifiedAt: DateTime.utc(2026, 7, 15, 12),
        sizeBytes: 1,
        sha256: List<String>.filled(64, 'a').join(),
        md5Base64: '1B2M2Y8AsgTpgAmY7PhCfg==',
        fileName: 'report.pdf',
        mimeType: 'application/pdf',
        completed: true,
      );
      await store.saveAttachmentBinding(firstAccount, binding);

      expect(
        store
            .attachmentBinding(
              firstAccount,
              messageId: binding.messageId,
              kind: binding.kind,
              order: binding.order,
            )
            ?.completed,
        isTrue,
      );
      expect(
        store.attachmentBinding(
          secondAccount,
          messageId: binding.messageId,
          kind: binding.kind,
          order: binding.order,
        ),
        isNull,
      );
      await store.close();
    });

    test('chat adapter only extracts trailing user attachment markers', () async {
      final chatService = ChatService(
        const UntrackedSyncWriteExecutor.forTests(),
      );
      await chatService.init();
      final store = await CloudSyncStore.open(
        boxName: 'cloud_sync_marker_authenticity_test',
      );
      final client = CloudSyncClient(baseUrl: 'http://127.0.0.1:1');
      addTearDown(() async {
        client.close(force: true);
        await store.close();
      });
      final attachmentService = CloudAttachmentSyncService(
        _cloudSession(client.baseUrl),
        client,
        store,
      );
      final adapter = ChatSyncAdapter(chatService, attachmentService);
      final conversation = await chatService.createConversation(title: 'Chat');
      final user = await chatService.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: r'ordinary [file:C:\outside\report.txt|report.txt|text/plain]',
      );
      final assistant = await chatService.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        content: r'[file:C:\outside\assistant.txt|assistant.txt|text/plain]',
        turnId: user.turnId,
      );

      final entities = await adapter.exportLocalEntities();
      final userPayload = entities
          .singleWhere(
            (entity) =>
                entity.entityType == ChatSyncAdapter.messageType &&
                entity.entityId == user.id,
          )
          .payload;
      final assistantPayload = entities
          .singleWhere(
            (entity) =>
                entity.entityType == ChatSyncAdapter.messageType &&
                entity.entityId == assistant.id,
          )
          .payload;

      expect(userPayload['content'], user.content);
      expect(assistantPayload['content'], assistant.content);

      final uploadDirectory = await AppDirectories.getUploadDirectory();
      await uploadDirectory.create(recursive: true);
      final managedFile = File(
        '${uploadDirectory.path}${Platform.pathSeparator}remote-report.txt',
      );
      await managedFile.writeAsString('must-not-upload');
      final remoteUser = ChatMessage(
        id: 'remote-ordinary-marker',
        role: 'user',
        content:
            'ordinary\n[file:${managedFile.path}|remote-report.txt|text/plain]',
        timestamp: DateTime.utc(2026, 7, 15, 10),
        conversationId: conversation.id,
        turnId: 'remote-turn',
        generationStatus: ChatMessage.generationStatusCompleted,
      );
      await adapter.applyRemoteUpsert(
        RemoteSyncEntity(
          entityType: ChatSyncAdapter.messageType,
          entityId: remoteUser.id,
          parentId: remoteUser.turnId,
          revision: 1,
          schemaVersion: 1,
          payload: ChatSyncCodec.encodeMessage(remoteUser)!,
          updatedAt: remoteUser.timestamp,
        ),
      );

      final replayedEntities = await adapter.exportLocalEntities();
      final replayedPayload = replayedEntities
          .singleWhere(
            (entity) =>
                entity.entityType == ChatSyncAdapter.messageType &&
                entity.entityId == remoteUser.id,
          )
          .payload;
      expect(replayedPayload['content'], remoteUser.content);
      expect(replayedPayload['attachments'], isEmpty);
    });

    test(
      'local attachment markers cannot read outside managed uploads',
      () async {
        final store = await CloudSyncStore.open(
          boxName: 'cloud_sync_untrusted_attachment_test',
        );
        final client = CloudSyncClient(baseUrl: 'http://127.0.0.1:1');
        addTearDown(() async {
          client.close(force: true);
          await store.close();
        });
        final outsideFile = File(
          '${tempDir.path}${Platform.pathSeparator}outside.txt',
        );
        await outsideFile.writeAsString('secret');
        final service = CloudAttachmentSyncService(
          _cloudSession(client.baseUrl),
          client,
          store,
        );

        await expectLater(
          service.prepareMessage(
            messageId: 'message-outside',
            content:
                'question\n[file:${outsideFile.path}|outside.txt|text/plain]',
          ),
          throwsA(isA<FileSystemException>()),
        );
      },
    );

    test('missing managed attachment heals from completed binding', () async {
      final bytes = utf8.encode('hello');
      const attachmentId = '11111111-1111-5111-8111-111111111111';
      const blobId = '22222222-2222-5222-8222-222222222222';
      const digest =
          '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824';
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final baseUrl = 'http://127.0.0.1:${server.port}';
      server.listen((request) async {
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
                      'blobId': blobId,
                      'entityType': 'message',
                      'entityId': 'message-recover',
                      'fileName': 'report.txt',
                      'mimeType': 'text/plain',
                      'sizeBytes': bytes.length,
                      'sha256': digest,
                      'createdAt': '2026-07-15T00:00:00.000Z',
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
                  'downloadUrl': '$baseUrl/blob',
                  'expiresAt': '2026-07-15T00:05:00.000Z',
                },
              }),
            );
            break;
          case '/blob':
            request.response.contentLength = bytes.length;
            request.response.add(bytes);
            break;
          default:
            request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });

      final store = await CloudSyncStore.open(
        boxName: 'cloud_sync_missing_attachment_test',
      );
      final client = CloudSyncClient(baseUrl: baseUrl, token: 'token');
      addTearDown(() async {
        client.close(force: true);
        await store.close();
        await server.close(force: true);
      });
      final uploadDirectory = await AppDirectories.getUploadDirectory();
      final missingFile = File(
        '${uploadDirectory.path}${Platform.pathSeparator}'
        'recovered${Platform.pathSeparator}report.txt',
      );
      final session = _cloudSession(baseUrl);
      await store.saveAttachmentBinding(
        session,
        CloudSyncAttachmentBinding(
          messageId: 'message-recover',
          attachmentId: attachmentId,
          kind: CloudSyncAttachmentKind.file,
          order: 0,
          localPath: missingFile.path,
          modifiedAt: DateTime.utc(2026, 7, 15),
          sizeBytes: bytes.length,
          sha256: digest,
          md5Base64: 'XUFAKrxLKna5cZ2REBfFkg==',
          fileName: 'report.txt',
          mimeType: 'text/plain',
          completed: true,
        ),
      );
      final service = CloudAttachmentSyncService(session, client, store);

      final prepared = await _withRealHttpClient(
        () => service.prepareMessage(
          messageId: 'message-recover',
          content: 'question\n[file:${missingFile.path}|report.txt|text/plain]',
        ),
      );

      expect(prepared.syncedContent, 'question');
      expect(prepared.references.single.attachmentId, attachmentId);
      expect(await missingFile.readAsString(), 'hello');
      expect(
        store
            .attachmentBinding(
              session,
              messageId: 'message-recover',
              kind: CloudSyncAttachmentKind.file,
              order: 0,
            )
            ?.completed,
        isTrue,
      );
    });

    test('signed download rejects redirects and bytes beyond limit', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var redirectTargetRequests = 0;
      server.listen((request) async {
        await request.drain<void>();
        if (request.uri.path == '/redirect') {
          request.response.statusCode = HttpStatus.found;
          request.response.headers.set(
            HttpHeaders.locationHeader,
            'http://127.0.0.1:${server.port}/redirect-target',
          );
        } else if (request.uri.path == '/redirect-target') {
          redirectTargetRequests++;
          request.response.contentLength = 0;
        } else {
          request.response.headers.chunkedTransferEncoding = true;
          request.response.add(const <int>[1, 2, 3, 4, 5]);
        }
        await request.response.close();
      });
      final client = CloudSyncClient(
        baseUrl: 'http://127.0.0.1:${server.port}',
      );
      addTearDown(() async {
        client.close(force: true);
        await server.close(force: true);
      });
      final destination = File(
        '${tempDir.path}${Platform.pathSeparator}oversized-download.bin',
      );

      await _withRealHttpClient(
        () => expectLater(
          client.downloadSignedAttachment(
            downloadUrl: 'http://127.0.0.1:${server.port}/blob',
            destinationPath: destination.path,
            expectedSizeBytes: 4,
          ),
          throwsA(
            isA<CloudSyncException>().having(
              (error) => error.kind,
              'kind',
              CloudSyncFailureKind.invalidResponse,
            ),
          ),
        ),
      );
      expect(await destination.exists(), isFalse);

      final redirectedDestination = File(
        '${tempDir.path}${Platform.pathSeparator}redirected-download.bin',
      );
      await _withRealHttpClient(
        () => expectLater(
          client.downloadSignedAttachment(
            downloadUrl: 'http://127.0.0.1:${server.port}/redirect',
            destinationPath: redirectedDestination.path,
            expectedSizeBytes: 0,
          ),
          throwsA(isA<CloudSyncException>()),
        ),
      );
      expect(redirectTargetRequests, 0);
      expect(await redirectedDestination.exists(), isFalse);
    });

    test('upload directory critical section is FIFO and reentrant', () async {
      final events = <String>[];
      final firstEntered = Completer<void>();
      final releaseFirst = Completer<void>();
      final first = UploadDirectoryCriticalSection.run(() async {
        events.add('first-start');
        await UploadDirectoryCriticalSection.run(() async {
          events.add('nested');
        });
        firstEntered.complete();
        await releaseFirst.future;
        events.add('first-end');
      });
      await firstEntered.future;
      final second = UploadDirectoryCriticalSection.run(() async {
        events.add('second');
      });

      await Future<void>.delayed(Duration.zero);
      expect(events, <String>['first-start', 'nested']);
      releaseFirst.complete();
      await Future.wait(<Future<void>>[first, second]);
      expect(events, <String>['first-start', 'nested', 'first-end', 'second']);
    });

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
        ChatSyncCodec.encodeMessage(terminal)?['content'],
        terminal.content,
      );

      final remoteImage = terminal.copyWith(
        content: '[image:https://cdn.example.com/photo.png]answer',
      );
      expect(
        ChatSyncCodec.encodeMessage(remoteImage)?['content'],
        remoteImage.content,
      );

      final payload = ChatSyncCodec.encodeMessage(
        terminal,
        syncedContent: 'answer',
        attachments: const <ChatSyncAttachmentReference>[
          ChatSyncAttachmentReference(
            attachmentId: '11111111-1111-5111-8111-111111111111',
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
      expect(
        decoded.attachments.single.attachmentId,
        '11111111-1111-5111-8111-111111111111',
      );
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
        final service = ChatService(
          const UntrackedSyncWriteExecutor.forTests(),
        );
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
      final service = ChatService(const UntrackedSyncWriteExecutor.forTests());
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
        final service = ChatService(
          const UntrackedSyncWriteExecutor.forTests(),
        );
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
        final service = ChatService(
          const UntrackedSyncWriteExecutor.forTests(),
        );
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
        final service = ChatService(
          const UntrackedSyncWriteExecutor.forTests(),
        );
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
      final service = ChatService(const UntrackedSyncWriteExecutor.forTests());
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
        final service = ChatService(
          const UntrackedSyncWriteExecutor.forTests(),
        );
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
