import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../database/app_database.dart';
import '../../database/chat_database_gateway.dart';
import '../../database/chat_database_repository.dart';
import '../../database/generation_run.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../utils/app_directories.dart';
import '../backup/portable_ndjson_v2.dart';
import '../sync/cloud_sync_store.dart';
import '../sync/sync_codec.dart';
import '../sync/sync_write_executor.dart';
import '../../utils/batched_change_notifier.dart';

final class LoadedTimelineSlot {
  const LoadedTimelineSlot({required this.identity, required this.message});

  final ActiveTimelineSlot identity;
  final ChatMessage message;
}

final class LoadedTimelinePage {
  LoadedTimelinePage({
    required this.conversationId,
    required this.stateRevision,
    required this.contextStartRevisionId,
    required List<LoadedTimelineSlot> slots,
    required this.hasMoreBefore,
    required this.hasMoreAfter,
    required this.totalSlotCount,
  }) : slots = List.unmodifiable(slots);

  final String conversationId;
  final int stateRevision;
  final String? contextStartRevisionId;
  final List<LoadedTimelineSlot> slots;
  final bool hasMoreBefore;
  final bool hasMoreAfter;
  final int totalSlotCount;

  String? get beforeRevisionId => hasMoreBefore && slots.isNotEmpty
      ? slots.first.identity.revisionId
      : null;
  String? get afterRevisionId =>
      hasMoreAfter && slots.isNotEmpty ? slots.last.identity.revisionId : null;
}

typedef AssetContentHash = Future<String> Function(File file);

typedef _AssetGcQuarantine = ({
  AssetGcQuarantineRecord record,
  File original,
  File quarantine,
  Directory root,
});

class ChatService extends ChangeNotifier with BatchedChangeNotifier {
  ChatService(
    this._syncWriteExecutor, {
    ChatDatabaseGateway? databaseGateway,
    AssetContentHash? assetContentHash,
  }) : _databaseGateway = databaseGateway ?? ChatDatabaseGateway.instance,
       _assetContentHash = assetContentHash ?? _hashAssetFile;

  static const String _conversationEntityType = 'conversation';
  static const String _turnEntityType = 'turn';
  static const String _messageEntityType = 'message';
  static const String _messageSelectionEntityType = 'message-selection';
  static const String _toolEventEntityType = 'tool-event';
  static const String _thoughtSignatureEntityType = 'thought-signature';

  static const int defaultInitialMessageMin = 2;
  static const int defaultInitialMessageMax = 240;
  static const int defaultTimelineInitialSlots = 40;
  static const int defaultInitialTextBudget = 20000;
  static const int defaultHistoryPageSize = 20;
  static const int defaultLoadedWindowMax = 360;
  static const int _messageCacheMaxEntries = 720;
  static const int _messageCacheMaxBytes = 8 * 1024 * 1024;
  static const int _assetReferenceBackfillVersion = 2;
  static const Duration _assetGcDelay = Duration(days: 7);
  static const Duration _assetGcLeaseDuration = Duration(minutes: 2);
  static const Duration _assetGcLeaseRetryInterval = Duration(
    milliseconds: 100,
  );
  static const String _assetGcQuarantineDirectoryName = '.kelivo-gc';
  static const String _assetGcLockFileName = '.kelivo-asset-gc.lock';
  static final Map<String, Future<void>> _assetGcProcessLockTails =
      <String, Future<void>>{};

  late ChatDatabaseRepository _repo;
  late File _databaseFile;
  final ChatDatabaseGateway _databaseGateway;
  final AssetContentHash _assetContentHash;
  final SyncWriteExecutor _syncWriteExecutor;
  final String _assetGcLeaseOwnerToken = const Uuid().v4();
  ChatDatabaseLease? _databaseLease;
  Future<void>? _assetReferenceMaintenanceFuture;
  Future<void>? _assetMaintenanceFuture;
  Future<void>? _assetGcRecoveryFuture;
  Future<void>? _postStartupAssetMaintenanceFuture;
  bool _assetGcRecoveryComplete = false;
  int _remoteBatchDepth = 0;
  final Object _importBatchZoneKey = Object();
  final Set<String> _remoteRebuildConversationIds = <String>{};
  bool _remoteNeedsAssetMaintenance = false;

  String? _currentConversationId;
  final Map<String, List<ChatMessage>> _messagesCache = {};
  final Map<String, Conversation> _conversationsCache = {};
  final Map<String, Conversation> _draftConversations = {};
  final Set<String> _temporaryConversationIds = <String>{};
  final Map<String, List<Map<String, dynamic>>> _temporaryToolEvents =
      <String, List<Map<String, dynamic>>>{};
  final Map<String, String> _temporaryGeminiThoughtSigs = <String, String>{};
  final Map<String, List<Map<String, dynamic>>> _toolEventsCache = {};
  final Map<String, String> _geminiThoughtSigsCache = {};
  final Map<String, Map<String, int>> _firstGroupIndicesCache = {};
  final Map<String, int> _messageCounts = {};
  final Map<String, List<String>> _messageOrderIds = {};

  // Localized default title for new conversations; set by UI on startup.
  String _defaultConversationTitle = 'New Chat';
  void setDefaultConversationTitle(String title) {
    if (title.trim().isEmpty) return;
    _defaultConversationTitle = title.trim();
  }

  bool _initialized = false;
  Future<void>? _initFuture;
  bool get initialized => _initialized;
  int _statisticsRevision = 0;
  int get statisticsRevision => _statisticsRevision;

  String? get currentConversationId => _currentConversationId;

  bool isTemporaryConversation(String? id) {
    return id != null && _temporaryConversationIds.contains(id);
  }

  Future<void> init() {
    if (_initialized) return Future<void>.value();
    final inFlight = _initFuture;
    if (inFlight != null) return inFlight;
    final initialization = _initialize();
    _initFuture = initialization;
    return initialization.whenComplete(() {
      if (identical(_initFuture, initialization)) _initFuture = null;
    });
  }

  Future<void> _initialize() async {
    final appDataDir = await AppDirectories.getAppDataDirectory();
    if (!await appDataDir.exists()) {
      await appDataDir.create(recursive: true);
    }
    _databaseFile = File(p.join(appDataDir.path, AppDatabase.databaseFileName));
    final lease = await _databaseGateway.acquire(_databaseFile);
    _databaseLease = lease;
    _repo = lease.repository;
    try {
      // 迁移具有版本号且以事务执行；常规启动无需扫描数据行即可返回。
      await _migrateSandboxPaths();
      await _loadConversationsCache();

      // 清理上一次崩溃或强制退出遗留的 isStreaming 标记；重新启动后，
      // 不可能仍有消息处于活动流式生成中。
      await _resetStaleStreamingFlags();

      _initialized = true;
      notifyListeners();
      late final Future<void> postStartupMaintenance;
      postStartupMaintenance = _ensureAssetGcRecovery()
          .then((_) => _runAssetReferenceMaintenance(appDataDir))
          .then((_) => runAssetMaintenance())
          .whenComplete(() {
            if (identical(
              _postStartupAssetMaintenanceFuture,
              postStartupMaintenance,
            )) {
              _postStartupAssetMaintenanceFuture = null;
            }
          });
      _postStartupAssetMaintenanceFuture = postStartupMaintenance;
      unawaited(
        postStartupMaintenance.catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'chat_service',
              context: ErrorDescription('执行启动后的聊天资源维护失败'),
            ),
          );
        }),
      );
    } catch (_) {
      _databaseLease = null;
      await lease.release();
      rethrow;
    }
  }

  Future<void> close() async {
    final initialization = _initFuture;
    if (initialization != null) {
      try {
        await initialization;
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'chat_service',
            context: ErrorDescription('关闭聊天服务时等待初始化失败'),
          ),
        );
        return;
      }
    }
    if (!_initialized) return;
    final postStartupMaintenance = _postStartupAssetMaintenanceFuture;
    if (postStartupMaintenance != null) {
      try {
        await postStartupMaintenance;
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'chat_service',
            context: ErrorDescription('关闭聊天服务时等待启动维护失败'),
          ),
        );
      }
    }
    final assetReferenceMaintenance = _assetReferenceMaintenanceFuture;
    if (assetReferenceMaintenance != null) {
      try {
        await assetReferenceMaintenance;
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'chat_service',
            context: ErrorDescription('关闭聊天服务时等待资源维护失败'),
          ),
        );
      }
    }
    final assetMaintenance = _assetMaintenanceFuture;
    if (assetMaintenance != null) {
      try {
        await assetMaintenance;
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'chat_service',
            context: ErrorDescription('关闭聊天服务时等待资产清理失败'),
          ),
        );
      }
    }
    _initialized = false;
    _assetGcRecoveryComplete = false;
    final lease = _databaseLease;
    _databaseLease = null;
    await lease?.release();
  }

  @override
  void dispose() {
    if (_initialized || _initFuture != null) {
      unawaited(close());
    }
    super.dispose();
  }

  Future<void> _loadConversationsCache() async {
    final conversations = await _repo.getAllConversationSummaries();
    final messageCounts = await _repo.getMessageCountsByConversation();
    _toolEventsCache.clear();
    _geminiThoughtSigsCache.clear();
    _messageOrderIds.clear();
    _messageCounts
      ..clear()
      ..addAll(messageCounts);
    _conversationsCache
      ..clear()
      ..addEntries(
        conversations.map(
          (conversation) => MapEntry(conversation.id, conversation),
        ),
      );
  }

  SyncEntityKey _conversationKey(String id) =>
      SyncEntityKey(entityType: _conversationEntityType, entityId: id);

  SyncEntityKey _turnKey(String id) =>
      SyncEntityKey(entityType: _turnEntityType, entityId: id);

  SyncEntityKey _messageKey(String id) =>
      SyncEntityKey(entityType: _messageEntityType, entityId: id);

  SyncEntityKey _messageSelectionKey(String id) =>
      SyncEntityKey(entityType: _messageSelectionEntityType, entityId: id);

  SyncEntityKey _toolEventKey(String id) =>
      SyncEntityKey(entityType: _toolEventEntityType, entityId: id);

  SyncEntityKey _thoughtSignatureKey(String id) =>
      SyncEntityKey(entityType: _thoughtSignatureEntityType, entityId: id);

  Set<SyncEntityKey> _messageGraphKeys(
    ChatMessage message, {
    bool includeConversation = true,
    bool includeSelectionWhenPresent = true,
  }) {
    final keys = <SyncEntityKey>{
      if (includeConversation) _conversationKey(message.conversationId),
      _turnKey(message.turnId),
      _messageKey(message.id),
      _toolEventKey(message.id),
      _thoughtSignatureKey(message.id),
    };
    final groupId = message.groupId ?? message.id;
    if (includeSelectionWhenPresent &&
        _conversationsCache[message.conversationId]?.versionSelections
                .containsKey(groupId) ==
            true) {
      keys.add(_messageSelectionKey(groupId));
    }
    return keys;
  }

  bool _isTerminalMessage(ChatMessage message) {
    return !message.isStreaming &&
        message.generationStatus != ChatMessage.generationStatusDraft;
  }

  Future<List<Conversation>> loadConversationsForSync() async {
    if (!_initialized) await init();
    return _repo.getAllConversationSummaries();
  }

  Future<Conversation?> loadConversationForSync(String conversationId) async {
    if (!_initialized) await init();
    return _repo.getConversation(conversationId);
  }

  Future<ChatMessage?> loadMessageForSync(String messageId) async {
    if (!_initialized) await init();
    return _repo.getMessage(messageId);
  }

  Future<List<ChatMessage>> loadMessagesForSync(String conversationId) async {
    if (!_initialized) await init();
    final count = await _repo.getMessageCount(conversationId);
    if (count == 0) return const <ChatMessage>[];
    return _repo.getMessagesRange(conversationId, start: 0, limit: count);
  }

  Future<List<ChatMessage>> loadMessagesForTurn(String turnId) async {
    if (!_initialized) await init();
    return _repo.getMessagesForTurn(turnId);
  }

  Future<String?> loadConversationIdForTurn(String turnId) async {
    if (!_initialized) await init();
    return _repo.getConversationIdForTurn(turnId);
  }

  Future<String?> loadConversationIdForSelection(String groupId) async {
    if (!_initialized) await init();
    return _repo.getConversationIdForSelection(groupId);
  }

  Future<Map<String, DateTime>> loadTurnCreatedAtsForSync(
    String conversationId,
  ) async {
    if (!_initialized) await init();
    return _repo.getTurnCreatedAts(conversationId);
  }

  Future<List<Map<String, dynamic>>> loadToolEventsForSync(
    String messageId,
  ) async {
    if (!_initialized) await init();
    return _repo.getToolEvents(messageId);
  }

  Future<bool> hasToolEventsForSync(String messageId) async {
    if (!_initialized) await init();
    return _repo.hasToolEvents(messageId);
  }

  Future<Map<String, List<Map<String, dynamic>>>>
  loadToolEventsForMessagesForSync(Iterable<String> messageIds) async {
    if (!_initialized) await init();
    return _repo.getToolEventsForMessages(messageIds);
  }

  Future<String?> loadThoughtSignatureForSync(String messageId) async {
    if (!_initialized) await init();
    return _repo.getGeminiThoughtSignature(messageId);
  }

  Future<Map<String, String>> loadThoughtSignaturesForMessagesForSync(
    Iterable<String> messageIds,
  ) async {
    if (!_initialized) await init();
    return _repo.getGeminiThoughtSignaturesForMessages(messageIds);
  }

  Future<void> _refreshPersistedCachesAfterRemoteBatch() async {
    _messagesCache.removeWhere(
      (conversationId, _) =>
          !_temporaryConversationIds.contains(conversationId),
    );
    _firstGroupIndicesCache.clear();
    await _loadConversationsCache();
  }

  Future<T> runRemoteBatch<T>(Future<T> Function() apply) async {
    if (!_initialized) await init();
    if (_remoteBatchDepth > 0) return apply();
    return runNotificationBatch<T>(() async {
      var committed = false;
      _remoteBatchDepth = 1;
      try {
        final result = await _repo.runInTransaction(() async {
          final value = await apply();
          final conversations = _remoteRebuildConversationIds.toList()..sort();
          for (final conversationId in conversations) {
            await _repo.rebuildSyncedMessageOrder(conversationId);
          }
          return value;
        });
        committed = true;
        return result;
      } finally {
        final runAssetMaintenance = committed && _remoteNeedsAssetMaintenance;
        _remoteBatchDepth = 0;
        _remoteRebuildConversationIds.clear();
        _remoteNeedsAssetMaintenance = false;
        await _refreshPersistedCachesAfterRemoteBatch();
        if (runAssetMaintenance) await _cleanupOrphanUploads();
        notifyListeners();
      }
    });
  }

  List<ChatMessage> _normalizeTurnIdentities(List<ChatMessage> messages) {
    final groups = <String, List<ChatMessage>>{};
    for (final message in messages) {
      groups
          .putIfAbsent(message.groupId ?? message.id, () => <ChatMessage>[])
          .add(message);
    }

    final normalizedById = <String, ChatMessage>{};
    String? currentTurnId;
    for (final group in groups.values) {
      final first = group.first;
      if (first.role == 'user') {
        currentTurnId = first.turnId;
      } else {
        currentTurnId ??= first.turnId;
      }
      for (final message in group) {
        normalizedById[message.id] = message.turnId == currentTurnId
            ? message
            : message.copyWith(turnId: currentTurnId);
      }
    }
    return messages
        .map((message) => normalizedById[message.id] ?? message)
        .toList(growable: false);
  }

  Future<T> runImportBatch<T>({
    required bool overwrite,
    required Iterable<Conversation> conversations,
    required Iterable<ChatMessage> messages,
    Iterable<String> toolEventMessageIds = const <String>[],
    Iterable<String> thoughtSignatureMessageIds = const <String>[],
    required Future<T> Function() write,
  }) async {
    if (!_initialized) await init();
    // 导入事务会再次触发附件引用维护；先排空启动维护，避免事务内等待事务外查询形成环。
    final startupMaintenance = _postStartupAssetMaintenanceFuture;
    if (startupMaintenance != null) {
      await startupMaintenance;
    }
    Future<T> apply() => runNotificationBatch<T>(() async {
      var committed = false;
      try {
        final result = await _repo.runInTransaction(write);
        committed = true;
        return result;
      } finally {
        if (!committed) await _refreshPersistedCachesAfterRemoteBatch();
        notifyListeners();
      }
    });
    if (identical(Zone.current[_importBatchZoneKey], this)) return write();
    return CloudSyncStore.runWithDefaultRescanWrite<T>(
      entityTypes: CloudSyncStore.chatRescanEntityTypes,
      localAuthoritativeEntityTypes: overwrite
          ? CloudSyncStore.chatRescanEntityTypes
          : const <String>{},
      write: () => runZoned<Future<T>>(
        apply,
        zoneValues: <Object?, Object?>{_importBatchZoneKey: this},
      ),
    );
  }

  Future<Conversation> upsertConversationFromSync(Conversation incoming) {
    if (_remoteBatchDepth == 0) {
      return runRemoteBatch(() => upsertConversationFromSync(incoming));
    }
    _requireSyncIdentifier(incoming.id, 'conversationId');
    _discardTemporaryConversation(incoming.id);
    _draftConversations.remove(incoming.id);
    _remoteRebuildConversationIds.add(incoming.id);
    return _repo.upsertConversationFromSync(incoming);
  }

  Future<ChatMessage> upsertMessageFromSync(ChatMessage incoming) {
    if (_remoteBatchDepth == 0) {
      return runRemoteBatch(() => upsertMessageFromSync(incoming));
    }
    _validateSyncedMessage(incoming);
    return _upsertMessageFromSync(incoming);
  }

  Future<ChatMessage> _upsertMessageFromSync(ChatMessage incoming) async {
    await _repo.ensureConversationFromSync(
      conversationId: incoming.conversationId,
      createdAt: incoming.timestamp,
      defaultTitle: _defaultConversationTitle,
    );
    final persisted = await _repo.upsertMessageFromSync(incoming);
    if (_messageCanOwnAssets(persisted)) {
      await _synchronizeMessageAssetsBestEffort(persisted);
    }
    _remoteRebuildConversationIds.add(incoming.conversationId);
    return persisted;
  }

  Future<void> applyTurnFromSync({
    required String conversationId,
    required String turnId,
    required DateTime createdAt,
  }) {
    if (_remoteBatchDepth == 0) {
      return runRemoteBatch(
        () => applyTurnFromSync(
          conversationId: conversationId,
          turnId: turnId,
          createdAt: createdAt,
        ),
      );
    }
    return _applyTurnFromSync(
      conversationId: conversationId,
      turnId: turnId,
      createdAt: createdAt,
    );
  }

  Future<void> _applyTurnFromSync({
    required String conversationId,
    required String turnId,
    required DateTime createdAt,
  }) async {
    _requireSyncIdentifier(conversationId, 'conversationId');
    _requireSyncIdentifier(turnId, 'turnId');
    await _repo.ensureConversationFromSync(
      conversationId: conversationId,
      createdAt: createdAt,
      defaultTitle: _defaultConversationTitle,
    );
    await _repo.upsertTurnFromSync(
      conversationId: conversationId,
      turnId: turnId,
      createdAt: createdAt,
    );
    _remoteRebuildConversationIds.add(conversationId);
  }

  Future<void> upsertMessageSelectionFromSync({
    required String conversationId,
    required String groupId,
    required int selectedVersion,
  }) {
    if (_remoteBatchDepth == 0) {
      return runRemoteBatch(
        () => upsertMessageSelectionFromSync(
          conversationId: conversationId,
          groupId: groupId,
          selectedVersion: selectedVersion,
        ),
      );
    }
    return _upsertMessageSelectionFromSync(
      conversationId: conversationId,
      groupId: groupId,
      selectedVersion: selectedVersion,
    );
  }

  Future<void> _upsertMessageSelectionFromSync({
    required String conversationId,
    required String groupId,
    required int selectedVersion,
  }) async {
    _requireSyncIdentifier(conversationId, 'conversationId');
    _requireSyncIdentifier(groupId, 'groupId');
    if (selectedVersion < 0) {
      throw const FormatException('selectedVersion 不能为负数');
    }
    final conversation = await _repo.getConversation(conversationId);
    if (conversation == null) {
      throw FormatException('版本选择所属会话不存在：$conversationId');
    }
    await _repo.setSelectedVersion(
      conversationId: conversationId,
      groupId: groupId,
      version: selectedVersion,
    );
    _remoteRebuildConversationIds.add(conversationId);
  }

  Future<void> upsertToolEventsFromSync({
    required String messageId,
    required List<Map<String, Object?>> events,
  }) {
    if (_remoteBatchDepth == 0) {
      return runRemoteBatch(
        () => upsertToolEventsFromSync(messageId: messageId, events: events),
      );
    }
    return _upsertToolEventsFromSync(messageId: messageId, events: events);
  }

  Future<void> _upsertToolEventsFromSync({
    required String messageId,
    required List<Map<String, Object?>> events,
  }) async {
    _requireSyncIdentifier(messageId, 'messageId');
    if (await _repo.getMessage(messageId) == null) {
      throw FormatException('工具事件所属消息不存在：$messageId');
    }
    await _repo.setToolEvents(messageId, [
      for (final event in events) Map<String, dynamic>.from(event),
    ]);
  }

  Future<void> upsertThoughtSignatureFromSync({
    required String messageId,
    required String signature,
  }) {
    if (_remoteBatchDepth == 0) {
      return runRemoteBatch(
        () => upsertThoughtSignatureFromSync(
          messageId: messageId,
          signature: signature,
        ),
      );
    }
    return _upsertThoughtSignatureFromSync(
      messageId: messageId,
      signature: signature,
    );
  }

  Future<void> _upsertThoughtSignatureFromSync({
    required String messageId,
    required String signature,
  }) async {
    _requireSyncIdentifier(messageId, 'messageId');
    if (signature.trim().isEmpty) {
      throw const FormatException('signature 不能为空');
    }
    if (await _repo.getMessage(messageId) == null) {
      throw FormatException('思维签名所属消息不存在：$messageId');
    }
    await _repo.setGeminiThoughtSignature(messageId, signature);
  }

  Future<void> deleteMessageSelectionFromSync(String groupId) {
    if (_remoteBatchDepth == 0) {
      return runRemoteBatch(() => deleteMessageSelectionFromSync(groupId));
    }
    return _deleteMessageSelectionFromSync(groupId);
  }

  Future<void> _deleteMessageSelectionFromSync(String groupId) async {
    _requireSyncIdentifier(groupId, 'groupId');
    final conversationId = await _repo.getConversationIdForSelection(groupId);
    if (conversationId == null) return;
    await _repo.setSelectedVersion(
      conversationId: conversationId,
      groupId: groupId,
      version: null,
    );
    _remoteRebuildConversationIds.add(conversationId);
  }

  Future<void> deleteToolEventsFromSync(String messageId) {
    if (_remoteBatchDepth == 0) {
      return runRemoteBatch(() => deleteToolEventsFromSync(messageId));
    }
    _requireSyncIdentifier(messageId, 'messageId');
    return _repo.deleteToolEvents(messageId);
  }

  Future<void> deleteThoughtSignatureFromSync(String messageId) {
    if (_remoteBatchDepth == 0) {
      return runRemoteBatch(() => deleteThoughtSignatureFromSync(messageId));
    }
    _requireSyncIdentifier(messageId, 'messageId');
    return _repo.deleteGeminiThoughtSignature(messageId);
  }

  Future<void> deleteTurnFromSync({
    required String conversationId,
    required String turnId,
  }) {
    if (_remoteBatchDepth == 0) {
      return runRemoteBatch(
        () =>
            deleteTurnFromSync(conversationId: conversationId, turnId: turnId),
      );
    }
    return _deleteTurnFromSync(conversationId: conversationId, turnId: turnId);
  }

  Future<void> _deleteTurnFromSync({
    required String conversationId,
    required String turnId,
  }) async {
    _requireSyncIdentifier(conversationId, 'conversationId');
    _requireSyncIdentifier(turnId, 'turnId');
    final result = await _repo.deleteTurnFromSync(
      conversationId: conversationId,
      turnId: turnId,
    );
    if (result != null) _remoteNeedsAssetMaintenance = true;
    _remoteRebuildConversationIds.add(conversationId);
  }

  Future<void> deleteMessageFromSync(String messageId) {
    if (_remoteBatchDepth == 0) {
      return runRemoteBatch(() => deleteMessageFromSync(messageId));
    }
    return _deleteMessageFromSync(messageId);
  }

  Future<void> _deleteMessageFromSync(String messageId) async {
    _requireSyncIdentifier(messageId, 'messageId');
    final message = await _repo.getMessage(messageId);
    if (message == null) return;
    await _repo.deleteMessage(messageId);
    _remoteRebuildConversationIds.add(message.conversationId);
    _remoteNeedsAssetMaintenance = true;
  }

  Future<void> deleteConversationFromSync(String conversationId) {
    if (_remoteBatchDepth == 0) {
      return runRemoteBatch(() => deleteConversationFromSync(conversationId));
    }
    _requireSyncIdentifier(conversationId, 'conversationId');
    _remoteNeedsAssetMaintenance = true;
    _remoteRebuildConversationIds.remove(conversationId);
    return _repo.deleteConversation(conversationId);
  }

  void _validateSyncedMessage(ChatMessage message) {
    _requireSyncIdentifier(message.id, 'messageId');
    _requireSyncIdentifier(message.conversationId, 'conversationId');
    _requireSyncIdentifier(message.turnId, 'turnId');
    if (message.role != 'user' && message.role != 'assistant') {
      throw ArgumentError.value(message.role, 'role', '不支持的消息角色');
    }
    if (message.isStreaming ||
        message.generationStatus == ChatMessage.generationStatusDraft ||
        !ChatMessage.generationStatuses.contains(message.generationStatus)) {
      throw ArgumentError.value(
        message.generationStatus,
        'generationStatus',
        '远端消息必须处于可同步终态',
      );
    }
  }

  void _requireSyncIdentifier(String value, String name) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, name, '同步标识不能为空');
    }
  }

  Future<List<String>> _loadMessageOrder(String conversationId) async {
    final cached = _messageOrderIds[conversationId];
    if (cached != null) return cached;
    final ids = (await _repo.getMessageIds(
      conversationId,
    )).toList(growable: true);
    _messageOrderIds[conversationId] = ids;
    _messageCounts[conversationId] = ids.length;
    return ids;
  }

  Future<List<ChatMessage>> loadActiveTimelineMessages(
    String conversationId,
  ) async {
    if (!_initialized) return const <ChatMessage>[];
    if (_temporaryConversationIds.contains(conversationId)) {
      return List<ChatMessage>.of(
        _messagesCache[conversationId] ?? const <ChatMessage>[],
      );
    }
    final probe = await _repo.loadLinearMessageWindow(
      conversationId: conversationId,
      fromStart: true,
      limit: 1,
    );
    if (probe.totalSlotCount == 0) return const <ChatMessage>[];
    final timeline = await _repo.loadLinearMessageWindow(
      conversationId: conversationId,
      fromStart: true,
      limit: probe.totalSlotCount,
    );
    final revisionIds = timeline.slots
        .map((slot) => slot.revisionId)
        .toList(growable: false);
    final messages = await _repo.getMessagesByIds(revisionIds);
    final byId = {for (final message in messages) message.id: message};
    return List<ChatMessage>.unmodifiable([
      for (final revisionId in revisionIds)
        if (byId[revisionId] != null) byId[revisionId]!,
    ]);
  }

  Future<LoadedTimelinePage?> loadTimelinePage(
    String conversationId, {
    String? beforeRevisionId,
    String? afterRevisionId,
    String? aroundRevisionId,
    bool fromStart = false,
    int limit = 40,
  }) async {
    if (!_initialized || limit <= 0) return null;
    if (_temporaryConversationIds.contains(conversationId)) {
      return _loadTemporaryTimelinePage(
        conversationId,
        beforeRevisionId: beforeRevisionId,
        afterRevisionId: afterRevisionId,
        aroundRevisionId: aroundRevisionId,
        fromStart: fromStart,
        limit: limit,
      );
    }
    final page = await _repo.loadLinearMessageWindow(
      conversationId: conversationId,
      beforeRevisionId: beforeRevisionId,
      afterRevisionId: afterRevisionId,
      aroundRevisionId: aroundRevisionId,
      fromStart: fromStart,
      limit: limit,
    );
    final revisionIds = page.slots
        .map((slot) => slot.revisionId)
        .toList(growable: false);
    final messages = await _repo.getMessagesByIds(revisionIds);
    final byId = {for (final message in messages) message.id: message};
    String? parentRevisionId;
    final loadedSlots = <LoadedTimelineSlot>[];
    for (final slot in page.slots) {
      final message = byId[slot.revisionId];
      if (message == null) continue;
      loadedSlots.add(
        LoadedTimelineSlot(
          identity: ActiveTimelineSlot(
            slotId: slot.groupId,
            revisionId: slot.revisionId,
            parentRevisionId: parentRevisionId,
            role: message.role,
            createdAt: message.timestamp,
            updatedAt: message.timestamp,
            finalizedAt: message.isStreaming ? null : message.timestamp,
            versionCount: slot.versionCount,
            logicalIndex: slot.logicalIndex,
          ),
          message: message,
        ),
      );
      parentRevisionId = message.id;
    }
    if (loadedSlots.length != page.slots.length) {
      throw StateError('timeline_selected_revision_shadow_missing');
    }
    _cacheLoadedMessages(conversationId, messages);
    await _cacheMessageArtifacts(messages);
    return LoadedTimelinePage(
      conversationId: conversationId,
      stateRevision:
          _conversationsCache[conversationId]
              ?.updatedAt
              .microsecondsSinceEpoch ??
          0,
      contextStartRevisionId: null,
      slots: loadedSlots,
      hasMoreBefore: page.hasMoreBefore,
      hasMoreAfter: page.hasMoreAfter,
      totalSlotCount: page.totalSlotCount,
    );
  }

  LoadedTimelinePage? _loadTemporaryTimelinePage(
    String conversationId, {
    String? beforeRevisionId,
    String? afterRevisionId,
    String? aroundRevisionId,
    required bool fromStart,
    required int limit,
  }) {
    final cursorCount = <String?>[
      beforeRevisionId,
      afterRevisionId,
      aroundRevisionId,
    ].where((cursor) => cursor != null).length;
    if (cursorCount > 1 || (fromStart && cursorCount != 0)) {
      throw ArgumentError('Only one timeline cursor may be supplied.');
    }
    final conversation = _draftConversations[conversationId];
    if (conversation == null) return null;
    final allMessages = _messagesCache[conversationId] ?? const <ChatMessage>[];
    final groups = <String, List<ChatMessage>>{};
    for (final message in allMessages) {
      groups.putIfAbsent(message.groupId ?? message.id, () => []).add(message);
    }
    final activeMessages = <ChatMessage>[];
    final versionCounts = <String, int>{};
    for (final entry in groups.entries) {
      final revisions = entry.value;
      versionCounts[entry.key] = revisions.length;
      final selection = conversation.versionSelections[entry.key];
      ChatMessage? selected;
      if (selection != null) {
        for (final revision in revisions) {
          if (revision.version == selection) {
            selected = revision;
            break;
          }
        }
      }
      activeMessages.add(selected ?? revisions.last);
    }

    var start = 0;
    var end = activeMessages.length;
    if (fromStart) {
      end = limit.clamp(0, activeMessages.length).toInt();
    } else if (aroundRevisionId != null) {
      final targetIndex = activeMessages.indexWhere(
        (message) => message.id == aroundRevisionId,
      );
      if (targetIndex < 0) return null;
      start = (targetIndex - (limit ~/ 2))
          .clamp(0, activeMessages.length)
          .toInt();
      end = (start + limit).clamp(start, activeMessages.length).toInt();
      start = (end - limit).clamp(0, end).toInt();
    } else if (beforeRevisionId != null) {
      end = activeMessages.indexWhere(
        (message) => message.id == beforeRevisionId,
      );
      if (end < 0) return null;
      start = (end - limit).clamp(0, end).toInt();
    } else if (afterRevisionId != null) {
      final cursorIndex = activeMessages.indexWhere(
        (message) => message.id == afterRevisionId,
      );
      if (cursorIndex < 0) return null;
      start = cursorIndex + 1;
      end = (start + limit).clamp(start, activeMessages.length).toInt();
    } else {
      start = (activeMessages.length - limit)
          .clamp(0, activeMessages.length)
          .toInt();
    }

    String? parentRevisionId = start == 0 ? null : activeMessages[start - 1].id;
    final slots = <LoadedTimelineSlot>[];
    for (var index = start; index < end; index++) {
      final message = activeMessages[index];
      final groupId = message.groupId ?? message.id;
      slots.add(
        LoadedTimelineSlot(
          identity: ActiveTimelineSlot(
            slotId: groupId,
            revisionId: message.id,
            parentRevisionId: parentRevisionId,
            role: message.role,
            createdAt: message.timestamp,
            updatedAt: message.timestamp,
            finalizedAt: message.isStreaming ? null : message.timestamp,
            versionCount: versionCounts[groupId] ?? 1,
            logicalIndex: index,
          ),
          message: message,
        ),
      );
      parentRevisionId = message.id;
    }
    return LoadedTimelinePage(
      conversationId: conversationId,
      stateRevision: conversation.updatedAt.microsecondsSinceEpoch,
      contextStartRevisionId: null,
      slots: slots,
      hasMoreBefore: start > 0,
      hasMoreAfter: end < activeMessages.length,
      totalSlotCount: activeMessages.length,
    );
  }

  void retainTimelineWindow(
    String conversationId,
    Iterable<String> revisionIds,
  ) {
    // 临时聊天没有可供逐出后重新加载的数据库副本。服务层持有的数据保持完整，
    // 协调器仍只暴露有界的可见窗口。
    if (_temporaryConversationIds.contains(conversationId)) return;
    final retained = revisionIds.toSet();
    final messages = _messagesCache[conversationId];
    if (messages != null) {
      final removedIds = messages
          .where((message) => !retained.contains(message.id))
          .map((message) => message.id)
          .toList(growable: false);
      _messagesCache[conversationId] = messages
          .where((message) => retained.contains(message.id))
          .toList(growable: true);
      for (final id in removedIds) {
        _toolEventsCache.remove(id);
        _geminiThoughtSigsCache.remove(id);
      }
    }
  }

  int getContextStartIndex(String conversationId) =>
      _conversationsCache[conversationId]?.truncateIndex ?? -1;

  Future<void> _cacheMessageArtifacts(Iterable<ChatMessage> messages) async {
    final ids = messages.map((message) => message.id).toSet();
    if (ids.isEmpty) return;
    final results = await Future.wait([
      _repo.getToolEventsForMessages(ids),
      _repo.getGeminiThoughtSignaturesForMessages(ids),
    ]);
    for (final id in ids) {
      _toolEventsCache.remove(id);
      _geminiThoughtSigsCache.remove(id);
    }
    _toolEventsCache.addAll(
      results[0] as Map<String, List<Map<String, dynamic>>>,
    );
    _geminiThoughtSigsCache.addAll(results[1] as Map<String, String>);
  }

  void _cacheLoadedMessages(
    String conversationId,
    Iterable<ChatMessage> messages,
  ) {
    if (_conversationForMessages(conversationId) == null) return;
    final byId = <String, ChatMessage>{
      for (final message in _messagesCache[conversationId] ?? const [])
        message.id: message,
      for (final message in messages) message.id: message,
    };
    _messagesCache[conversationId] = [
      for (final id in _messageOrderIds[conversationId] ?? const <String>[])
        if (byId[id] != null) byId[id]!,
    ];
    _touchMessageCache(conversationId);
    _enforceMessageCacheLimits();
  }

  void _touchMessageCache(String conversationId) {
    final messages = _messagesCache.remove(conversationId);
    if (messages != null) _messagesCache[conversationId] = messages;
  }

  void _enforceMessageCacheLimits() {
    var entries = 0;
    var bytes = 0;
    for (final entry in _messagesCache.entries) {
      if (entry.key == _currentConversationId ||
          _temporaryConversationIds.contains(entry.key)) {
        continue;
      }
      entries += entry.value.length;
      bytes += entry.value.fold<int>(0, (sum, message) {
        return sum +
            message.content.length * 2 +
            (message.reasoningText?.length ?? 0) * 2 +
            (message.translation?.length ?? 0) * 2;
      });
    }
    while ((entries > _messageCacheMaxEntries ||
            bytes > _messageCacheMaxBytes) &&
        _messagesCache.isNotEmpty) {
      final candidate = _messagesCache.entries.firstWhere(
        (entry) =>
            entry.key != _currentConversationId &&
            !_temporaryConversationIds.contains(entry.key),
        orElse: () => const MapEntry('', <ChatMessage>[]),
      );
      if (candidate.key.isEmpty) break;
      _messagesCache.remove(candidate.key);
      entries -= candidate.value.length;
      bytes -= candidate.value.fold<int>(0, (sum, message) {
        return sum +
            message.content.length * 2 +
            (message.reasoningText?.length ?? 0) * 2 +
            (message.translation?.length ?? 0) * 2;
      });
      for (final message in candidate.value) {
        _toolEventsCache.remove(message.id);
        _geminiThoughtSigsCache.remove(message.id);
      }
    }
  }

  List<Conversation> getAllConversations() {
    if (!_initialized) return [];
    final conversations = _conversationsCache.values.toList();
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return conversations;
  }

  List<Conversation> getAllCompleteConversations() {
    return getAllConversations();
  }

  List<Conversation> getPinnedConversations() {
    return getAllConversations().where((c) => c.isPinned).toList();
  }

  Conversation? getConversation(String id) {
    if (!_initialized) return null;
    return _conversationsCache[id] ?? _draftConversations[id];
  }

  Conversation? getCompleteConversation(String id) {
    if (!_initialized) return null;
    final draft = _draftConversations[id];
    if (draft != null) return draft;
    return _conversationsCache[id];
  }

  Conversation? _conversationForMessages(String conversationId) {
    if (!_initialized) return _draftConversations[conversationId];
    return _conversationsCache[conversationId] ??
        _draftConversations[conversationId];
  }

  int getMessageCount(String conversationId) {
    if (_temporaryConversationIds.contains(conversationId)) {
      return _messagesCache[conversationId]?.length ?? 0;
    }
    if (!_initialized) return 0;
    return _messageCounts[conversationId] ?? 0;
  }

  int getMessageIndex(String conversationId, String messageId) {
    if (_temporaryConversationIds.contains(conversationId)) {
      final messages = _messagesCache[conversationId];
      if (messages == null) return -1;
      return messages.indexWhere((message) => message.id == messageId);
    }
    return _messageOrderIds[conversationId]?.indexOf(messageId) ?? -1;
  }

  Map<String, int> getFirstMessageIndicesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) {
    if (!_initialized) return const <String, int>{};
    final ids = groupIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return const <String, int>{};
    final cached = _firstGroupIndicesCache[conversationId] ?? const {};
    return {
      for (final id in ids)
        if (cached[id] != null) id: cached[id]!,
    };
  }

  Future<Map<String, int>> loadFirstMessageIndicesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) async {
    final ids = groupIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return const {};
    if (_temporaryConversationIds.contains(conversationId) ||
        _draftConversations.containsKey(conversationId)) {
      final result = <String, int>{};
      final messages = _messagesCache[conversationId] ?? const <ChatMessage>[];
      for (var i = 0; i < messages.length; i++) {
        final groupId = messages[i].groupId ?? messages[i].id;
        if (ids.contains(groupId)) result.putIfAbsent(groupId, () => i);
      }
      return result;
    }
    final loaded = await _repo.getFirstMessageIndicesForGroups(
      conversationId,
      ids,
    );
    _firstGroupIndicesCache
        .putIfAbsent(conversationId, () => {})
        .addAll(loaded);
    return loaded;
  }

  List<ChatMessage> getMessagesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) {
    if (!_initialized) return const <ChatMessage>[];
    final ids = groupIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return const <ChatMessage>[];
    final messages = _messagesCache[conversationId] ?? const <ChatMessage>[];
    return messages
        .where((message) => ids.contains(message.groupId ?? message.id))
        .toList(growable: false);
  }

  Future<List<ChatMessage>> loadMessagesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) async {
    if (_temporaryConversationIds.contains(conversationId) ||
        _draftConversations.containsKey(conversationId)) {
      return getMessagesForGroups(conversationId, groupIds);
    }
    await _loadMessageOrder(conversationId);
    final messages = await _repo.getMessagesForGroups(conversationId, groupIds);
    _cacheLoadedMessages(conversationId, messages);
    await _cacheMessageArtifacts(messages);
    return messages;
  }

  Future<List<ConversationSearchMatch>> searchConversationMatches({
    required List<String> tokens,
    int limit = 200,
    bool includeAllRevisions = false,
  }) async {
    if (!_initialized) return const <ConversationSearchMatch>[];
    return _repo.searchConversationMatches(
      tokens: tokens,
      limit: limit,
      includeAllRevisions: includeAllRevisions,
    );
  }

  Future<ChatStatsAggregate> loadStatsAggregate({
    required DateTime? rangeStart,
    required DateTime? rangeEndExclusive,
    required DateTime heatmapStart,
    required DateTime trendStart,
    required DateTime trendEndExclusive,
  }) async {
    if (!_initialized) await init();
    return _repo.queryStatsAggregate(
      rangeStart: rangeStart,
      rangeEndExclusive: rangeEndExclusive,
      heatmapStart: heatmapStart,
      trendStart: trendStart,
      trendEndExclusive: trendEndExclusive,
    );
  }

  List<ChatMessage> getMessages(String conversationId) {
    if (!_initialized) return const [];
    return _messagesCache[conversationId] ?? const [];
  }

  Future<List<ChatMessage>> loadMessages(String conversationId) async {
    if (!_initialized) return const [];
    final cached = _messagesCache[conversationId];
    if (cached != null && cached.length == getMessageCount(conversationId)) {
      return cached;
    }
    final conversation =
        _conversationsCache[conversationId] ??
        _draftConversations[conversationId];
    if (conversation == null) return [];

    final messages = _temporaryConversationIds.contains(conversationId)
        ? (_messagesCache[conversationId] ?? const <ChatMessage>[])
        : await _repo.getMessagesRange(
            conversationId,
            start: 0,
            limit: getMessageCount(conversationId),
          );

    if (!_temporaryConversationIds.contains(conversationId)) {
      await _cacheMessageArtifacts(messages);
    }

    // 缓存结果
    _messagesCache[conversationId] = List.of(messages);
    _touchMessageCache(conversationId);
    _enforceMessageCacheLimits();
    return messages;
  }

  Future<List<ChatMessage>> loadSelectedContextMessages(
    String conversationId, {
    required int truncateIndex,
    required int limit,
    String? throughRevisionId,
    bool includeFollowingAssistant = false,
  }) async {
    if (!_initialized || limit <= 0) return const <ChatMessage>[];
    if (_temporaryConversationIds.contains(conversationId) ||
        _draftConversations.containsKey(conversationId)) {
      final messages = _messagesCache[conversationId] ?? const <ChatMessage>[];
      final groups = <String, List<ChatMessage>>{};
      final order = <String>[];
      for (final message in messages) {
        final groupId = message.groupId ?? message.id;
        if (!groups.containsKey(groupId)) order.add(groupId);
        groups.putIfAbsent(groupId, () => <ChatMessage>[]).add(message);
      }
      final selections = getVersionSelections(conversationId);
      final selected = <ChatMessage>[];
      for (final groupId in order) {
        final versions = groups[groupId]!
          ..sort((a, b) => a.version.compareTo(b.version));
        final version = selections[groupId];
        selected.add(
          versions.cast<ChatMessage?>().firstWhere(
                (message) => message!.version == version,
                orElse: () => null,
              ) ??
              versions.last,
        );
      }
      var end = selected.length;
      if (throughRevisionId != null) {
        final target = selected.indexWhere(
          (message) => message.id == throughRevisionId,
        );
        if (target < 0) return const <ChatMessage>[];
        end = target + 1;
        if (includeFollowingAssistant && selected[target].role == 'user') {
          final assistant = selected.indexWhere(
            (message) => message.role == 'assistant',
            target + 1,
          );
          if (assistant >= 0) end = assistant + 1;
        }
      }
      final start = truncateIndex >= 0 && truncateIndex <= end
          ? truncateIndex
          : 0;
      final available = end - start;
      final boundedStart = start + (available - limit).clamp(0, available);
      return selected.sublist(boundedStart, end);
    }
    final messages = await _repo.getSelectedContextMessages(
      conversationId,
      truncateIndex: truncateIndex,
      limit: limit,
      throughRevisionId: throughRevisionId,
      includeFollowingAssistant: includeFollowingAssistant,
    );
    await _cacheMessageArtifacts(messages);
    return messages;
  }

  Future<int> getMaxMessageVersionForGroup(
    String conversationId,
    String groupId,
  ) {
    if (_temporaryConversationIds.contains(conversationId) ||
        _draftConversations.containsKey(conversationId)) {
      final versions = (_messagesCache[conversationId] ?? const <ChatMessage>[])
          .where((message) => (message.groupId ?? message.id) == groupId)
          .map((message) => message.version);
      return Future<int>.value(
        versions.isEmpty ? -1 : versions.reduce((a, b) => a > b ? a : b),
      );
    }
    return _repo.getMaxMessageVersionForGroup(conversationId, groupId);
  }

  Future<List<ChatMessage>> loadSelectedMessageProjections(
    String conversationId,
  ) async {
    if (_temporaryConversationIds.contains(conversationId) ||
        _draftConversations.containsKey(conversationId)) {
      return loadSelectedContextMessages(
        conversationId,
        truncateIndex: -1,
        limit: _messagesCache[conversationId]?.length ?? 0,
      );
    }
    return _repo.getSelectedMessageProjections(conversationId);
  }

  Future<List<ChatMessage>> loadMessagesByIds(List<String> ids) async {
    if (ids.isEmpty) return const <ChatMessage>[];
    final temporaryById = <String, ChatMessage>{
      for (final conversationId in _temporaryConversationIds)
        for (final message
            in _messagesCache[conversationId] ?? const <ChatMessage>[])
          message.id: message,
    };
    if (ids.every(temporaryById.containsKey)) {
      return [for (final id in ids) temporaryById[id]!];
    }
    final messages = await _repo.getMessagesByIds(ids);
    await _cacheMessageArtifacts(messages);
    return messages;
  }

  Future<Set<String>> loadMessageIdsForGroups(
    String conversationId,
    Set<String> groupIds,
  ) {
    if (_temporaryConversationIds.contains(conversationId) ||
        _draftConversations.containsKey(conversationId)) {
      return Future<Set<String>>.value({
        for (final message
            in _messagesCache[conversationId] ?? const <ChatMessage>[])
          if (groupIds.contains(message.groupId ?? message.id)) message.id,
      });
    }
    return _repo.getMessageIdsForGroups(conversationId, groupIds);
  }

  List<ChatMessage> getMessagesRange(
    String conversationId, {
    required int start,
    required int limit,
  }) {
    if (!_initialized || limit <= 0) return const [];
    if (_temporaryConversationIds.contains(conversationId)) {
      final messages = _messagesCache[conversationId] ?? const <ChatMessage>[];
      final safeStart = start.clamp(0, messages.length).toInt();
      final end = (safeStart + limit).clamp(safeStart, messages.length).toInt();
      return messages.sublist(safeStart, end);
    }
    if (_conversationForMessages(conversationId) == null) return const [];
    final ids = _messageOrderIds[conversationId] ?? const <String>[];
    final safeStart = start.clamp(0, ids.length).toInt();
    final end = (safeStart + limit).clamp(safeStart, ids.length).toInt();
    final byId = {
      for (final message in _messagesCache[conversationId] ?? const [])
        message.id: message,
    };
    return [
      for (final id in ids.sublist(safeStart, end))
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<List<ChatMessage>> loadMessagesRange(
    String conversationId, {
    required int start,
    required int limit,
  }) async {
    if (!_initialized || limit <= 0) return const <ChatMessage>[];

    if (_temporaryConversationIds.contains(conversationId)) {
      final messages = _messagesCache[conversationId] ?? const <ChatMessage>[];
      final safeStart = start.clamp(0, messages.length).toInt();
      final end = (safeStart + limit).clamp(safeStart, messages.length).toInt();
      return safeStart >= end
          ? const <ChatMessage>[]
          : messages.sublist(safeStart, end);
    }

    final conversation = _conversationForMessages(conversationId);
    if (conversation == null) {
      return const <ChatMessage>[];
    }

    await _loadMessageOrder(conversationId);

    final messages = await _repo.getMessagesRange(
      conversationId,
      start: start,
      limit: limit,
    );
    _cacheLoadedMessages(conversationId, messages);
    await _cacheMessageArtifacts(messages);
    return messages;
  }

  List<ChatMessage> getRecentMessages(
    String conversationId, {
    int minMessages = defaultInitialMessageMin,
    int textBudget = defaultInitialTextBudget,
    int maxMessages = defaultInitialMessageMax,
  }) {
    final cached = _messagesCache[conversationId] ?? const <ChatMessage>[];
    if (cached.length <= maxMessages) return List.of(cached);
    return cached.sublist(cached.length - maxMessages);
  }

  Future<List<ChatMessage>> loadRecentMessages(
    String conversationId, {
    int minMessages = defaultInitialMessageMin,
    int textBudget = defaultInitialTextBudget,
    int maxMessages = defaultInitialMessageMax,
  }) async {
    if (!_initialized) return const <ChatMessage>[];

    final conversation = _conversationForMessages(conversationId);
    if (conversation == null) {
      return const <ChatMessage>[];
    }

    final total = getMessageCount(conversationId);
    if (total == 0) return const <ChatMessage>[];
    final minCount = minMessages.clamp(1, total).toInt();
    final maxCount = maxMessages < minCount ? minCount : maxMessages;
    final budget = textBudget <= 0 ? defaultInitialTextBudget : textBudget;

    var start = total;
    var loaded = 0;
    var weight = 0;
    final selected = <ChatMessage>[];
    while (start > 0 && loaded < maxCount) {
      final batchStart = (start - defaultHistoryPageSize)
          .clamp(0, start)
          .toInt();
      final batch = await loadMessagesRange(
        conversationId,
        start: batchStart,
        limit: start - batchStart,
      );
      for (var i = batch.length - 1; i >= 0 && loaded < maxCount; i--) {
        final message = batch[i];
        selected.insert(0, message);
        loaded++;
        weight += _estimateInitialLoadWeight(message);
        if (loaded >= minCount && weight >= budget) break;
      }
      start = batchStart;
      if (loaded >= minCount && weight >= budget) break;
    }

    if (selected.isNotEmpty && selected.length.isOdd && start > 0) {
      final previous = await loadMessagesRange(
        conversationId,
        start: start - 1,
        limit: 1,
      );
      if (previous.isNotEmpty) {
        selected.insert(0, previous.first);
        start--;
      }
    }

    return selected;
  }

  int _estimateInitialLoadWeight(ChatMessage message) {
    final len = message.content.length;
    if (message.role == 'user') return len < 200 ? 200 : len;
    if (message.role == 'assistant') return (len * 0.8).round();
    return len;
  }

  Future<Conversation> createConversation({
    String? title,
    String? assistantId,
  }) async {
    if (!_initialized) await init();
    _discardTemporaryConversation(_currentConversationId);

    final conversation = Conversation(
      title: title ?? _defaultConversationTitle,
      assistantId: assistantId,
    );

    await _saveConversation(conversation);
    _currentConversationId = conversation.id;
    _enforceMessageCacheLimits();
    notifyListeners();
    return conversation;
  }

  Future<void> _saveConversation(Conversation conversation) async {
    if (_temporaryConversationIds.contains(conversation.id)) {
      _draftConversations[conversation.id] = conversation;
      return;
    }
    await _syncWriteExecutor.runLocal<void>(
      key: _conversationKey(conversation.id),
      write: () async {
        await _repo.putConversation(conversation);
        _conversationsCache[conversation.id] = conversation;
      },
    );
  }

  Future<Conversation?> _updatePersistedConversation(
    String conversationId,
    Future<bool> Function(Conversation conversation) update,
  ) {
    return _syncWriteExecutor.runLocal<Conversation?>(
      key: _conversationKey(conversationId),
      write: () async {
        final conversation = await _repo.getConversation(
          conversationId,
          includeMessageIds: false,
        );
        if (conversation == null) {
          _conversationsCache.remove(conversationId);
          return null;
        }
        if (!await update(conversation)) {
          _conversationsCache[conversationId] = conversation;
          return conversation;
        }
        await _repo.putConversation(conversation);
        _conversationsCache[conversationId] = conversation;
        return conversation;
      },
    );
  }

  Future<void> _refreshConversation(String conversationId) async {
    if (_temporaryConversationIds.contains(conversationId)) return;
    final conversation = await _repo.getConversation(conversationId);
    if (conversation == null) {
      _conversationsCache.remove(conversationId);
    } else {
      _conversationsCache[conversationId] = conversation;
    }
  }

  // Create a draft conversation that is not persisted until first message arrives.
  Future<Conversation> createDraftConversation({
    String? title,
    String? assistantId,
    bool temporary = false,
  }) async {
    if (!_initialized) await init();
    _discardTemporaryConversation(_currentConversationId);
    final conversation = Conversation(
      title: title ?? _defaultConversationTitle,
      assistantId: assistantId,
    );
    _draftConversations[conversation.id] = conversation;
    if (temporary) {
      _temporaryConversationIds.add(conversation.id);
      _messagesCache[conversation.id] = <ChatMessage>[];
    }
    _currentConversationId = conversation.id;
    _enforceMessageCacheLimits();
    notifyListeners();
    return conversation;
  }

  void _discardTemporaryConversation(String? id) {
    if (id == null || !_temporaryConversationIds.remove(id)) return;
    final messages = _messagesCache[id] ?? const <ChatMessage>[];
    for (final message in messages) {
      _temporaryToolEvents.remove(message.id);
      _temporaryGeminiThoughtSigs.remove(message.id);
    }
    _draftConversations.remove(id);
    _messagesCache.remove(id);
    if (_currentConversationId == id) {
      _currentConversationId = null;
    }
  }

  Future<void> deleteConversation(String id) async {
    if (!_initialized) return;

    final deleted =
        await _deleteDraftConversation(id) ||
        await _deletePersistedConversation(id);
    if (!deleted) return;

    // 只删除已无任何会话引用的孤立文件，避免破坏仍在使用的附件。
    await _cleanupOrphanUploads();

    notifyListeners();
  }

  Future<bool> _deleteDraftConversation(String id) async {
    if (!_draftConversations.containsKey(id)) return false;

    _draftConversations.remove(id);
    _temporaryConversationIds.remove(id);
    final messages = _messagesCache[id] ?? const <ChatMessage>[];
    for (final message in messages) {
      _temporaryToolEvents.remove(message.id);
      _temporaryGeminiThoughtSigs.remove(message.id);
    }
    _messagesCache.remove(id);
    if (_currentConversationId == id) {
      _currentConversationId = null;
    }
    return true;
  }

  Future<bool> _deletePersistedConversation(String id) async {
    final conversation = _conversationsCache[id];
    if (conversation == null) return false;
    return CloudSyncStore.runWithDefaultRescanWrite<bool>(
      entityTypes: CloudSyncStore.chatRescanEntityTypes,
      write: () => _syncWriteExecutor.runLocal<bool>(
        key: _conversationKey(id),
        write: () async {
          if (await _repo.getConversation(id, includeMessageIds: false) ==
              null) {
            _conversationsCache.remove(id);
            return false;
          }
          await _repo.deleteConversation(id);
          _conversationsCache.remove(id);
          _messagesCache.remove(id);

          if (_currentConversationId == id) {
            _currentConversationId = null;
          }
          return true;
        },
      ),
    );
  }

  Future<void> deleteConversationsForAssistant(String assistantId) async {
    if (!_initialized) await init();

    final targetId = assistantId.trim();
    if (targetId.isEmpty) return;

    final persistedConversationIds = _conversationsCache.values
        .where((conversation) => conversation.assistantId == targetId)
        .map((conversation) => conversation.id)
        .toList(growable: false);
    final draftConversationIds = _draftConversations.values
        .where((conversation) => conversation.assistantId == targetId)
        .map((conversation) => conversation.id)
        .toList(growable: false);

    var deleted = false;
    for (final conversationId in draftConversationIds) {
      deleted = await _deleteDraftConversation(conversationId) || deleted;
    }
    for (final conversationId in persistedConversationIds) {
      deleted = await _deletePersistedConversation(conversationId) || deleted;
    }

    if (!deleted) return;
    await _cleanupOrphanUploads();
    notifyListeners();
  }

  List<({String path, String kind})> _extractLocalAttachments(String content) {
    final out = <String, ({String path, String kind})>{};
    final imgRe = RegExp(r"\[image:(.+?)\]");
    for (final m in imgRe.allMatches(content)) {
      final pth = m.group(1)?.trim();
      if (pth != null &&
          pth.isNotEmpty &&
          !pth.startsWith('http') &&
          !pth.startsWith('data:')) {
        final fixed = SandboxPathResolver.fix(pth);
        out['image:$fixed'] = (path: fixed, kind: 'image');
      }
    }
    final fileRe = RegExp(r"\[file:(.+?)\|(.+?)\|(.+?)\]");
    for (final m in fileRe.allMatches(content)) {
      final pth = m.group(1)?.trim();
      if (pth != null &&
          pth.isNotEmpty &&
          !pth.startsWith('http') &&
          !pth.startsWith('data:')) {
        final fixed = SandboxPathResolver.fix(pth);
        out['file:$fixed'] = (path: fixed, kind: 'file');
      }
    }
    return List.unmodifiable(out.values);
  }

  bool _messageCanOwnAssets(ChatMessage message) =>
      message.content.contains('[image:') || message.content.contains('[file:');

  Future<void> _backfillAssetReferences(Directory appDataDir) async {
    final targetRoot = p.normalize(appDataDir.absolute.path);
    final includeLegacyCandidates = await _repo.needsAssetReferenceBackfill(
      version: _assetReferenceBackfillVersion,
      targetRoot: targetRoot,
    );
    if (!includeLegacyCandidates &&
        !await _repo.hasPendingAssetReferenceSync()) {
      return;
    }
    var cursor = '';
    while (true) {
      final messages = await _repo.getMessagesForAssetReferenceBackfill(
        afterMessageId: cursor,
        includeLegacyCandidates: includeLegacyCandidates,
      );
      if (messages.isEmpty) break;
      for (final message in messages) {
        await _synchronizeMessageAssets(message);
        cursor = message.id;
        await Future<void>.delayed(Duration.zero);
      }
    }
    if (includeLegacyCandidates) {
      await _repo.markAssetReferenceBackfillComplete(
        version: _assetReferenceBackfillVersion,
        targetRoot: targetRoot,
      );
    }
  }

  Future<void> runAssetReferenceMaintenance() async {
    if (!_initialized) await init();
    return _runAssetReferenceMaintenance(
      await AppDirectories.getAppDataDirectory(),
    );
  }

  Future<void> _runAssetReferenceMaintenance(Directory appDataDir) {
    final inFlight = _assetReferenceMaintenanceFuture;
    if (inFlight != null) return inFlight;
    late final Future<void> tracked;
    tracked = _backfillAssetReferences(appDataDir).whenComplete(() {
      if (identical(_assetReferenceMaintenanceFuture, tracked)) {
        _assetReferenceMaintenanceFuture = null;
      }
    });
    _assetReferenceMaintenanceFuture = tracked;
    return tracked;
  }

  Future<void> _backfillAssetReferencesForCurrentRoot() async {
    await runAssetReferenceMaintenance();
  }

  Future<void> _synchronizeMessageAssets(ChatMessage message) async {
    if (isTemporaryConversation(message.conversationId)) return;
    try {
      var current = message;
      while (true) {
        // 回填读取的是快照；先持久化 dirty，再读取文件，GC 才不会在摘要窗口内释放资源。
        await _repo.markMessageAssetReferencesDirty(current.id);
        final managedRoots = <Directory>[
          await AppDirectories.getUploadDirectory(),
          await AppDirectories.getImagesDirectory(),
        ];
        final registrations = <MessageAssetRegistration>[];
        for (final attachment in _extractLocalAttachments(current.content)) {
          final normalizedPath = p.normalize(
            File(attachment.path).absolute.path,
          );
          Directory? owner;
          for (final root in managedRoots) {
            if (SandboxPathResolver.isOwnedManagedPath(
              path: normalizedPath,
              managedDirectory: root,
            )) {
              owner = root;
              break;
            }
          }
          if (owner == null) continue;
          final file = File(normalizedPath);
          if (await FileSystemEntity.type(file.path, followLinks: false) !=
              FileSystemEntityType.file) {
            throw StateError('asset_file_unavailable');
          }
          final contentHash = await _assetContentHash(file);
          if (!SandboxPathResolver.isOwnedManagedPath(
            path: normalizedPath,
            managedDirectory: owner,
          )) {
            throw StateError('asset_file_escaped_managed_root');
          }
          registrations.add(
            MessageAssetRegistration(
              assetId: 'asset_$contentHash',
              contentHash: contentHash,
              path: normalizedPath,
              byteSize: await file.length(),
              kind: attachment.kind,
            ),
          );
        }
        final replaced = await _repo.replaceMessageAssetReferences(
          conversationId: current.conversationId,
          revisionId: current.id,
          expectedContent: current.content,
          assets: registrations,
        );
        if (replaced) return;
        final latest = await _repo.getMessage(current.id);
        if (latest == null) return;
        current = latest;
        await Future<void>.delayed(Duration.zero);
      }
    } catch (error, stackTrace) {
      // dirty 行是失败与 GC 之间的持久化闸门；只记录日志无法跨重启保护文件。
      await _repo.markMessageAssetReferencesDirty(message.id);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static Future<String> _hashAssetFile(File file) {
    final path = file.path;
    return Isolate.run(
      () async => (await sha256.bind(File(path).openRead()).first).toString(),
    );
  }

  Future<void> _synchronizeMessageAssetsBestEffort(ChatMessage message) async {
    try {
      await _synchronizeMessageAssets(message);
    } catch (error) {
      // 消息持久化是权威数据。消息事务会先将相关修订加入队列，
      // 因此资产索引更新失败时由有界启动回填重试，而不是让发送失败。
      debugPrint('Message asset synchronization failed: $error');
    }
  }

  Future<void> _migrateSandboxPaths() async {
    if (SandboxPathResolver.docsDir == null) {
      await SandboxPathResolver.init();
    }
    final targetRoot = SandboxPathResolver.docsDir;
    if (targetRoot == null || targetRoot.isEmpty) {
      throw StateError('sandbox_path_resolver_not_ready');
    }
    final imgRe = RegExp(r"\[image:(.+?)\]");
    final fileRe = RegExp(r"\[file:(.+?)\|(.+?)\|(.+?)\]");
    await _repo.migrateSandboxPaths(
      targetVersion: 1,
      targetRoot: targetRoot,
      rewriteContent: (content) {
        var updated = content.replaceAllMapped(imgRe, (match) {
          final raw = (match.group(1) ?? '').trim();
          return '[image:${SandboxPathResolver.fix(raw)}]';
        });
        updated = updated.replaceAllMapped(fileRe, (match) {
          final raw = (match.group(1) ?? '').trim();
          final name = (match.group(2) ?? '').trim();
          final mime = (match.group(3) ?? '').trim();
          return '[file:${SandboxPathResolver.fix(raw)}|$name|$mime]';
        });
        return updated;
      },
    );
  }

  /// 重置上一次崩溃或强制退出遗留的 isStreaming 标记。重新启动后，
  /// 不可能仍有消息处于活动流式生成中，因此所有持久化的
  /// `isStreaming: true` 都已过期，必须清除以免加载指示器卡住。
  ///
  Future<void> _resetStaleStreamingFlags() async {
    final messages = await _repo.getStreamingMessages();
    if (messages.isEmpty) {
      await _repo.resetStaleStreamingState();
      return;
    }
    final keys = <SyncEntityKey>{};
    for (final message in messages) {
      keys.addAll(_messageGraphKeys(message));
    }
    await _syncWriteExecutor.runLocalBatch<int>(
      keys: keys,
      write: _repo.resetStaleStreamingState,
    );
  }

  String _assetGcPathKey(String path) {
    final normalized = p.normalize(File(path).absolute.path);
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  Future<void> _acquireAssetGcLease() async {
    while (true) {
      final now = DateTime.now().toUtc();
      final attempt = await _repo.tryAcquireAssetGcLease(
        ownerToken: _assetGcLeaseOwnerToken,
        now: now,
        leaseDuration: _assetGcLeaseDuration,
      );
      if (attempt.acquired) return;
      final remaining = attempt.expiresAt.difference(now);
      final retryDelay =
          remaining <= Duration.zero || remaining > _assetGcLeaseRetryInterval
          ? _assetGcLeaseRetryInterval
          : remaining;
      await Future<void>.delayed(retryDelay);
    }
  }

  Future<void> _renewAssetGcLease() async {
    final attempt = await _repo.tryAcquireAssetGcLease(
      ownerToken: _assetGcLeaseOwnerToken,
      now: DateTime.now().toUtc(),
      leaseDuration: _assetGcLeaseDuration,
    );
    if (!attempt.acquired) {
      throw StateError('asset_gc_lease_lost');
    }
  }

  Future<T> _withAssetGcProcessLock<T>(
    String key,
    Future<T> Function() action,
  ) async {
    final gate = Completer<void>();
    final ownTail = gate.future;
    final previous = _assetGcProcessLockTails[key] ?? Future<void>.value();
    _assetGcProcessLockTails[key] = ownTail;
    await previous;
    try {
      return await action();
    } finally {
      if (identical(_assetGcProcessLockTails[key], ownTail)) {
        _assetGcProcessLockTails.remove(key);
      }
      gate.complete();
    }
  }

  Future<T> _withAssetGcFileLock<T>(Future<T> Function() action) async {
    final appDataDirectory = await AppDirectories.getAppDataDirectory();
    final lockFile = File(p.join(appDataDirectory.path, _assetGcLockFileName));
    final lockKey = _assetGcPathKey(lockFile.path);
    return _withAssetGcProcessLock<T>(lockKey, () async {
      final existingType = await FileSystemEntity.type(
        lockFile.path,
        followLinks: false,
      );
      if (existingType != FileSystemEntityType.notFound &&
          existingType != FileSystemEntityType.file) {
        throw StateError('asset_gc_lock_file_invalid');
      }
      final handle = await lockFile.open(mode: FileMode.append);
      var locked = false;
      try {
        // 文件锁由操作系统在进程退出时释放，避免过期租约允许旧进程恢复后继续移动文件。
        await handle.lock(FileLock.exclusive);
        locked = true;
        return await action();
      } finally {
        try {
          if (locked) await handle.unlock();
        } finally {
          await handle.close();
        }
      }
    });
  }

  Future<T> _withAssetGcLease<T>(Future<T> Function() action) async {
    return _withAssetGcFileLock<T>(() async {
      await _acquireAssetGcLease();
      try {
        return await action();
      } finally {
        await _repo.releaseAssetGcLease(ownerToken: _assetGcLeaseOwnerToken);
      }
    });
  }

  Directory _assetGcQuarantineDirectory(Directory root) {
    return Directory(
      p.join(p.normalize(root.absolute.path), _assetGcQuarantineDirectoryName),
    );
  }

  _AssetGcQuarantine _validateAssetGcQuarantineRecord(
    AssetGcQuarantineRecord record,
    Iterable<Directory> managedRoots,
  ) {
    final originalPath = p.normalize(File(record.originalPath).absolute.path);
    final quarantinePath = p.normalize(
      File(record.quarantinePath).absolute.path,
    );
    Directory? owner;
    for (final root in managedRoots) {
      final rootPath = p.normalize(root.absolute.path);
      final quarantineDirectory = _assetGcQuarantineDirectory(root);
      if (!p.isWithin(rootPath, originalPath) ||
          p.equals(originalPath, quarantineDirectory.path) ||
          p.isWithin(quarantineDirectory.path, originalPath)) {
        continue;
      }
      owner = root;
      break;
    }
    if (owner == null) {
      throw StateError('asset_gc_quarantine_original_outside_managed_root');
    }
    final quarantineDirectory = _assetGcQuarantineDirectory(owner);
    if (!p.equals(p.dirname(quarantinePath), quarantineDirectory.path) ||
        !SandboxPathResolver.isOwnedManagedPath(
          path: originalPath,
          managedDirectory: owner,
        ) ||
        !SandboxPathResolver.isOwnedManagedPath(
          path: quarantinePath,
          managedDirectory: owner,
        )) {
      throw StateError('asset_gc_quarantine_record_invalid');
    }
    return (
      record: record,
      original: File(originalPath),
      quarantine: File(quarantinePath),
      root: owner,
    );
  }

  Future<void> _recoverAssetGcQuarantine(_AssetGcQuarantine quarantine) async {
    await _renewAssetGcLease();
    final record = await _repo.getAssetGcQuarantine(
      quarantine.record.quarantinePath,
    );
    if (record == null ||
        record.assetId != quarantine.record.assetId ||
        record.generation != quarantine.record.generation ||
        !p.equals(record.originalPath, quarantine.record.originalPath)) {
      throw StateError('asset_gc_quarantine_record_changed');
    }
    if (!SandboxPathResolver.isOwnedManagedPath(
          path: quarantine.quarantine.path,
          managedDirectory: quarantine.root,
        ) ||
        !SandboxPathResolver.isOwnedManagedPath(
          path: quarantine.original.path,
          managedDirectory: quarantine.root,
        )) {
      throw StateError('asset_gc_quarantine_path_escaped_managed_root');
    }
    final originalType = await FileSystemEntity.type(
      quarantine.original.path,
      followLinks: false,
    );
    final quarantineType = await FileSystemEntity.type(
      quarantine.quarantine.path,
      followLinks: false,
    );
    switch (record.state) {
      case AssetGcQuarantineState.pending:
        if (originalType == FileSystemEntityType.file &&
            quarantineType == FileSystemEntityType.notFound) {
          await _renewAssetGcLease();
          await _repo.deleteAssetGcQuarantine(record.quarantinePath);
          return;
        }
        if (originalType == FileSystemEntityType.notFound &&
            quarantineType == FileSystemEntityType.file) {
          await _renewAssetGcLease();
          await quarantine.quarantine.rename(quarantine.original.path);
          await _repo.deleteAssetGcQuarantine(record.quarantinePath);
          return;
        }
        throw StateError('asset_gc_pending_quarantine_ambiguous');
      case AssetGcQuarantineState.completed:
        await _renewAssetGcLease();
        await _repo.settleCompletedAssetGcQuarantine(
          expectedRecord: record,
          settleFile: (disposition) async {
            if (!SandboxPathResolver.isOwnedManagedPath(
                  path: quarantine.quarantine.path,
                  managedDirectory: quarantine.root,
                ) ||
                !SandboxPathResolver.isOwnedManagedPath(
                  path: quarantine.original.path,
                  managedDirectory: quarantine.root,
                )) {
              throw StateError('asset_gc_quarantine_path_escaped_managed_root');
            }
            final currentOriginalType = await FileSystemEntity.type(
              quarantine.original.path,
              followLinks: false,
            );
            final currentQuarantineType = await FileSystemEntity.type(
              quarantine.quarantine.path,
              followLinks: false,
            );
            switch (disposition) {
              case AssetGcCompletedDisposition.restore:
                if (currentOriginalType == FileSystemEntityType.notFound &&
                    currentQuarantineType == FileSystemEntityType.file) {
                  await quarantine.quarantine.rename(quarantine.original.path);
                  return;
                }
                if (currentOriginalType == FileSystemEntityType.file &&
                    currentQuarantineType == FileSystemEntityType.notFound) {
                  return;
                }
                throw StateError('asset_gc_completed_restore_ambiguous');
              case AssetGcCompletedDisposition.delete:
                if (currentQuarantineType == FileSystemEntityType.file) {
                  await quarantine.quarantine.delete();
                  return;
                }
                if (currentQuarantineType == FileSystemEntityType.notFound &&
                    currentOriginalType == FileSystemEntityType.notFound) {
                  return;
                }
                if (currentQuarantineType == FileSystemEntityType.notFound &&
                    currentOriginalType == FileSystemEntityType.file) {
                  throw StateError(
                    'asset_gc_completed_delete_original_ambiguous',
                  );
                }
                throw StateError(
                  'asset_gc_completed_quarantine_not_regular_file',
                );
            }
          },
        );
    }
  }

  Future<void> _recoverAssetGcQuarantines(List<Directory> managedRoots) async {
    final records = await _repo.listAssetGcQuarantines();
    final quarantines = <_AssetGcQuarantine>[];
    final quarantinesByPath = <String, _AssetGcQuarantine>{};
    for (final record in records) {
      final quarantine = _validateAssetGcQuarantineRecord(record, managedRoots);
      final key = _assetGcPathKey(quarantine.quarantine.path);
      if (quarantinesByPath.containsKey(key)) {
        throw StateError('asset_gc_quarantine_path_collision');
      }
      quarantines.add(quarantine);
      quarantinesByPath[key] = quarantine;
    }

    for (final root in managedRoots) {
      final directory = _assetGcQuarantineDirectory(root);
      final directoryType = await FileSystemEntity.type(
        directory.path,
        followLinks: false,
      );
      if (directoryType == FileSystemEntityType.notFound) continue;
      if (directoryType != FileSystemEntityType.directory ||
          !SandboxPathResolver.isOwnedManagedPath(
            path: p.join(directory.path, '.ownership-probe'),
            managedDirectory: root,
          )) {
        throw StateError('asset_gc_quarantine_directory_invalid');
      }
      await for (final entity in directory.list(
        recursive: false,
        followLinks: false,
      )) {
        final quarantine = quarantinesByPath[_assetGcPathKey(entity.path)];
        if (quarantine == null ||
            !p.equals(entity.path, quarantine.quarantine.path)) {
          throw StateError('asset_gc_unknown_quarantine_entry');
        }
      }
    }

    for (final quarantine in quarantines) {
      await _recoverAssetGcQuarantine(quarantine);
    }
  }

  Future<Directory> _ensureAssetGcQuarantineDirectory(Directory root) async {
    final directory = _assetGcQuarantineDirectory(root);
    var type = await FileSystemEntity.type(directory.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      await directory.create();
      type = await FileSystemEntity.type(directory.path, followLinks: false);
    }
    if (type != FileSystemEntityType.directory ||
        !SandboxPathResolver.isOwnedManagedPath(
          path: p.join(directory.path, '.ownership-probe'),
          managedDirectory: root,
        )) {
      throw StateError('asset_gc_quarantine_directory_invalid');
    }
    return directory;
  }

  Future<void> _ensureAssetGcRecovery() {
    if (_assetGcRecoveryComplete) return Future<void>.value();
    final inFlight = _assetGcRecoveryFuture;
    if (inFlight != null) return inFlight;
    late final Future<void> tracked;
    tracked =
        _withAssetGcLease<void>(() async {
          final managedRoots = <Directory>[
            await AppDirectories.getUploadDirectory(),
            await AppDirectories.getImagesDirectory(),
          ];
          await _recoverAssetGcQuarantines(managedRoots);
          _assetGcRecoveryComplete = true;
        }).whenComplete(() {
          if (identical(_assetGcRecoveryFuture, tracked)) {
            _assetGcRecoveryFuture = null;
          }
        });
    _assetGcRecoveryFuture = tracked;
    return tracked;
  }

  Future<void> _settleAssetGcQuarantines(
    List<_AssetGcQuarantine> quarantines,
  ) async {
    while (quarantines.isNotEmpty) {
      final quarantine = quarantines.last;
      await _recoverAssetGcQuarantine(quarantine);
      quarantines.removeLast();
    }
  }

  Future<void> runAssetMaintenance({DateTime? now}) async {
    if (!_initialized) await init();
    final inFlight = _assetMaintenanceFuture;
    if (inFlight != null) return inFlight;
    late final Future<void> tracked;
    tracked = _runAssetMaintenance(now: now).whenComplete(() {
      if (identical(_assetMaintenanceFuture, tracked)) {
        _assetMaintenanceFuture = null;
      }
    });
    _assetMaintenanceFuture = tracked;
    return tracked;
  }

  Future<void> _runAssetMaintenance({DateTime? now}) async {
    final effectiveNow = (now ?? DateTime.now()).toUtc();
    await _ensureAssetGcRecovery();
    await _runAssetReferenceMaintenance(
      await AppDirectories.getAppDataDirectory(),
    );
    await _withAssetGcLease<void>(() async {
      final managedRoots = <Directory>[
        await AppDirectories.getUploadDirectory(),
        await AppDirectories.getImagesDirectory(),
      ];
      await _renewAssetGcLease();
      await _repo.scheduleUnreferencedAssetGc(
        notBefore: effectiveNow.add(_assetGcDelay),
      );
      final candidates = await _repo.claimAssetGc(now: effectiveNow);
      for (final candidate in candidates) {
        await _renewAssetGcLease();
        final paths = [
          candidate.path,
          candidate.thumbnailPath,
        ].whereType<String>();
        final regularFiles = <({File file, Directory root})>[];
        final seenPaths = <String>{};
        var safe = true;
        for (final candidatePath in paths) {
          final normalized = p.normalize(File(candidatePath).absolute.path);
          if (!seenPaths.add(_assetGcPathKey(normalized))) continue;
          Directory? owner;
          for (final root in managedRoots) {
            if (SandboxPathResolver.isOwnedManagedPath(
              path: normalized,
              managedDirectory: root,
            )) {
              owner = root;
              break;
            }
          }
          if (owner == null ||
              p.equals(normalized, _assetGcQuarantineDirectory(owner).path) ||
              p.isWithin(_assetGcQuarantineDirectory(owner).path, normalized)) {
            safe = false;
            break;
          }
          final type = await FileSystemEntity.type(
            normalized,
            followLinks: false,
          );
          if (type == FileSystemEntityType.file) {
            regularFiles.add((file: File(normalized), root: owner));
          } else if (type != FileSystemEntityType.notFound) {
            safe = false;
            break;
          }
        }
        if (!safe) continue;
        if (!await _repo.isAssetGcClaimStillValid(
          candidate,
          now: effectiveNow,
        )) {
          continue;
        }
        final quarantined = <_AssetGcQuarantine>[];
        try {
          for (final entry in regularFiles) {
            final file = entry.file;
            if (!SandboxPathResolver.isOwnedManagedPath(
                  path: file.path,
                  managedDirectory: entry.root,
                ) ||
                await FileSystemEntity.type(file.path, followLinks: false) !=
                    FileSystemEntityType.file) {
              safe = false;
              break;
            }
            final quarantineDirectory = await _ensureAssetGcQuarantineDirectory(
              entry.root,
            );
            final quarantine = File(
              p.join(quarantineDirectory.path, const Uuid().v4()),
            );
            if (await FileSystemEntity.type(
                  quarantine.path,
                  followLinks: false,
                ) !=
                FileSystemEntityType.notFound) {
              safe = false;
              break;
            }
            final record = AssetGcQuarantineRecord(
              assetId: candidate.assetId,
              generation: candidate.generation,
              originalPath: file.path,
              quarantinePath: quarantine.path,
              state: AssetGcQuarantineState.pending,
            );
            await _renewAssetGcLease();
            await _repo.recordAssetGcQuarantine(
              assetId: record.assetId,
              generation: record.generation,
              originalPath: record.originalPath,
              quarantinePath: record.quarantinePath,
            );
            quarantined.add((
              record: record,
              original: file,
              quarantine: quarantine,
              root: entry.root,
            ));
            await _renewAssetGcLease();
            await file.rename(quarantine.path);
            if (!SandboxPathResolver.isOwnedManagedPath(
                  path: quarantine.path,
                  managedDirectory: entry.root,
                ) ||
                await FileSystemEntity.type(
                      quarantine.path,
                      followLinks: false,
                    ) !=
                    FileSystemEntityType.file) {
              throw StateError('asset_gc_quarantine_move_invalid');
            }
          }
          if (!safe) {
            await _settleAssetGcQuarantines(quarantined);
            continue;
          }
          await _renewAssetGcLease();
          final completed = await _repo.completeAssetGc(
            assetId: candidate.assetId,
            expectedGeneration: candidate.generation,
            expectedQuarantinePaths: {
              for (final quarantine in quarantined)
                quarantine.record.quarantinePath,
            },
            now: effectiveNow,
          );
          if (!completed) {
            await _settleAssetGcQuarantines(quarantined);
            continue;
          }
          await _settleAssetGcQuarantines(quarantined);
        } catch (error, stackTrace) {
          // DB 结果决定隔离文件的唯一合法去向，不能凭异常发生位置猜测。
          try {
            await _settleAssetGcQuarantines(quarantined);
          } catch (recoveryError, recoveryStackTrace) {
            _assetGcRecoveryComplete = false;
            Error.throwWithStackTrace(recoveryError, recoveryStackTrace);
          }
          Error.throwWithStackTrace(error, stackTrace);
        }
      }
    });
  }

  Future<void> _cleanupOrphanUploads() => runAssetMaintenance();

  Future<void> restoreConversation(
    Conversation conversation,
    List<ChatMessage> messages,
  ) async {
    if (!_initialized) await init();
    final normalizedMessages = _normalizeTurnIdentities(messages);
    // 确保 messageIds 保持相同顺序
    final ids = normalizedMessages.map((message) => message.id).toList();
    final restored = Conversation(
      id: conversation.id,
      title: conversation.title,
      createdAt: conversation.createdAt,
      updatedAt: conversation.updatedAt,
      messageIds: ids,
      isPinned: conversation.isPinned,
      mcpServerIds: List.of(conversation.mcpServerIds),
      truncateIndex: conversation.truncateIndex,
      assistantId: conversation.assistantId,
      versionSelections: Map<String, int>.from(conversation.versionSelections),
      summary: conversation.summary,
      lastSummarizedMessageCount: conversation.lastSummarizedMessageCount,
      chatSuggestions: List<String>.of(conversation.chatSuggestions),
    );
    await runImportBatch<void>(
      overwrite: false,
      conversations: <Conversation>[restored],
      messages: normalizedMessages,
      write: () async {
        await _repo.putMigrationBatch(
          conversations: [restored],
          messages: [
            for (final (index, message) in normalizedMessages.indexed)
              (message: message, messageOrder: index),
          ],
          toolEventsByMessageId: const {},
          geminiSignaturesByMessageId: const {},
        );
        await _backfillAssetReferencesForCurrentRoot();
        await _refreshConversation(restored.id);

        _messagesCache[restored.id] = List.of(normalizedMessages);
        _messageOrderIds[restored.id] = normalizedMessages
            .map((message) => message.id)
            .toList(growable: true);
        _messageCounts[restored.id] = normalizedMessages.length;
        notifyListeners();
      },
    );
  }

  Future<void> replaceAllDataFromBackup({
    required List<Conversation> conversations,
    required List<ChatMessage> messages,
    required Map<String, List<Map<String, dynamic>>> toolEventsByMessageId,
    required Map<String, String> geminiSignaturesByMessageId,
  }) async {
    if (!_initialized) await init();

    final nextOrderByConversation = <String, int>{};
    final orderedMessages = <({ChatMessage message, int messageOrder})>[];
    for (final message in messages) {
      final messageOrder = nextOrderByConversation.update(
        message.conversationId,
        (value) => value + 1,
        ifAbsent: () => 0,
      );
      orderedMessages.add((message: message, messageOrder: messageOrder));
    }

    await runImportBatch<void>(
      overwrite: true,
      conversations: conversations,
      messages: messages,
      toolEventMessageIds: toolEventsByMessageId.keys,
      thoughtSignatureMessageIds: geminiSignaturesByMessageId.keys,
      write: () async {
        await _repo.replaceBackupData(
          conversations: conversations,
          messages: orderedMessages,
          toolEventsByMessageId: toolEventsByMessageId,
          geminiSignaturesByMessageId: geminiSignaturesByMessageId,
        );

        await _resetAfterOverwriteRestore();
      },
    );
  }

  Future<ChatDatabaseSnapshotInfo> createBackupDatabaseSnapshot(
    File destinationFile,
  ) async {
    if (!_initialized) await init();
    final sourcePath = _databaseFile.path;
    final destinationPath = destinationFile.path;
    return Isolate.run(
      () => ChatDatabaseRepository.createConsistentSnapshot(
        sourceFile: File(sourcePath),
        destinationFile: File(destinationPath),
      ),
    );
  }

  Future<void> restoreDatabaseSnapshot(File snapshotFile) async {
    if (!_initialized) await init();
    await CloudSyncStore.runWithDefaultRescanWrite<void>(
      entityTypes: CloudSyncStore.chatRescanEntityTypes,
      localAuthoritativeEntityTypes: CloudSyncStore.chatRescanEntityTypes,
      write: () async {
        await _repo.replaceBackupSnapshot(snapshotFile);
        await _resetAfterOverwriteRestore();
      },
    );
  }

  Future<BackupMergeReport> mergeDatabaseSnapshot(File snapshotFile) async {
    if (!_initialized) await init();
    return CloudSyncStore.runWithDefaultRescanWrite<BackupMergeReport>(
      entityTypes: CloudSyncStore.chatRescanEntityTypes,
      write: () async {
        final report = await _repo.mergeBackupSnapshot(snapshotFile);
        _messagesCache.clear();
        await _backfillAssetReferencesForCurrentRoot();
        await _loadConversationsCache();
        notifyListeners();
        return report;
      },
    );
  }

  Future<PortableChatExportResult> exportPortableChats(
    File destination, {
    PortableChatScope scope = PortableChatScope.selectedVersionsCompleted,
  }) async {
    if (!_initialized) await init();
    return PortableNdjsonV2.exportToFile(
      repository: _repo,
      destination: destination,
      scope: scope,
    );
  }

  Future<BackupMergeReport> importPortableChats(File source) async {
    if (!_initialized) await init();
    return CloudSyncStore.runWithDefaultRescanWrite<BackupMergeReport>(
      entityTypes: CloudSyncStore.chatRescanEntityTypes,
      write: () async {
        final report = await PortableNdjsonV2.importFromFile(
          target: _repo,
          source: source,
        );
        _messagesCache.clear();
        await _backfillAssetReferencesForCurrentRoot();
        await _loadConversationsCache();
        notifyListeners();
        return report;
      },
    );
  }

  Future<void> _resetAfterOverwriteRestore() async {
    _messagesCache.clear();
    _draftConversations.clear();
    _temporaryConversationIds.clear();
    _temporaryToolEvents.clear();
    _temporaryGeminiThoughtSigs.clear();
    _toolEventsCache.clear();
    _geminiThoughtSigsCache.clear();
    _messageCounts.clear();
    _messageOrderIds.clear();
    _currentConversationId = null;
    await _backfillAssetReferencesForCurrentRoot();
    await _loadConversationsCache();
    notifyListeners();
  }

  // 合并模式直接向已有会话追加消息，不另建会话。
  Future<void> addMessageDirectly(
    String conversationId,
    ChatMessage message,
  ) async {
    if (!_initialized) await init();

    final conversation = _conversationsCache[conversationId];
    if (conversation == null) return;
    final order = await _loadMessageOrder(conversationId);
    if (order.contains(message.id)) return;
    await runImportBatch<void>(
      overwrite: false,
      conversations: <Conversation>[conversation],
      messages: <ChatMessage>[message],
      write: () async {
        final persisted = await _repo.appendLinearMessageToConversation(
          conversation: conversation,
          message: message,
          touchUpdatedAt: false,
        );
        if (_messageCanOwnAssets(message)) {
          await _synchronizeMessageAssetsBestEffort(message);
        }
        _conversationsCache[conversationId] = persisted;
        order.add(message.id);
        _messageCounts[conversationId] = order.length;

        if (_messagesCache.containsKey(conversationId)) {
          if (!_messagesCache[conversationId]!.any((m) => m.id == message.id)) {
            _messagesCache[conversationId]!.add(message);
          }
        }

        notifyListeners();
      },
    );
  }

  // Conversation-scoped MCP servers selection
  List<String> getConversationMcpServers(String conversationId) {
    if (!_initialized) return const <String>[];
    final c =
        _conversationsCache[conversationId] ??
        _draftConversations[conversationId];
    return c?.mcpServerIds ?? const <String>[];
  }

  Future<void> setConversationMcpServers(
    String conversationId,
    List<String> serverIds,
  ) async {
    if (!_initialized) await init();
    if (_draftConversations.containsKey(conversationId)) {
      final draft = _draftConversations[conversationId]!;
      draft.mcpServerIds = List.of(serverIds);
      draft.updatedAt = DateTime.now();
      notifyListeners();
      return;
    }
    if (!_conversationsCache.containsKey(conversationId)) return;
    final updated = await _updatePersistedConversation(conversationId, (
      conversation,
    ) async {
      conversation.mcpServerIds = List.of(serverIds);
      conversation.updatedAt = DateTime.now();
      return true;
    });
    if (updated == null) return;
    notifyListeners();
  }

  Future<void> toggleConversationMcpServer(
    String conversationId,
    String serverId,
    bool enabled,
  ) async {
    if (!_initialized) await init();
    final draft = _draftConversations[conversationId];
    if (draft != null) {
      final servers = draft.mcpServerIds.toSet();
      enabled ? servers.add(serverId) : servers.remove(serverId);
      draft.mcpServerIds = servers.toList(growable: false);
      draft.updatedAt = DateTime.now();
      notifyListeners();
      return;
    }
    if (!_conversationsCache.containsKey(conversationId)) return;
    final updated = await _updatePersistedConversation(conversationId, (
      conversation,
    ) async {
      final servers = conversation.mcpServerIds.toSet();
      enabled ? servers.add(serverId) : servers.remove(serverId);
      conversation.mcpServerIds = servers.toList(growable: false);
      conversation.updatedAt = DateTime.now();
      return true;
    });
    if (updated != null) notifyListeners();
  }

  Future<void> renameConversation(String id, String newTitle) async {
    if (!_initialized) return;

    if (_draftConversations.containsKey(id)) {
      final draft = _draftConversations[id]!;
      draft.title = newTitle;
      draft.updatedAt = DateTime.now();
      notifyListeners();
      return;
    }
    if (!_conversationsCache.containsKey(id)) return;
    final updated = await _updatePersistedConversation(id, (
      conversation,
    ) async {
      conversation.title = newTitle;
      conversation.updatedAt = DateTime.now();
      return true;
    });
    if (updated == null) return;
    notifyListeners();
  }

  /// Updates the conversation summary generated by LLM.
  Future<void> updateConversationSummary(
    String id,
    String summary,
    int messageCount,
  ) async {
    if (!_initialized) return;

    if (_draftConversations.containsKey(id)) {
      final draft = _draftConversations[id]!;
      draft.summary = summary;
      draft.lastSummarizedMessageCount = messageCount;
      notifyListeners();
      return;
    }

    if (!_conversationsCache.containsKey(id)) return;

    final updated = await _updatePersistedConversation(id, (
      conversation,
    ) async {
      conversation.summary = summary;
      conversation.lastSummarizedMessageCount = messageCount;
      return true;
    });
    if (updated == null) return;
    notifyListeners();
  }

  /// Gets all conversations with non-empty summaries for a specific assistant.
  List<Conversation> getConversationsWithSummaryForAssistant(
    String assistantId,
  ) {
    if (!_initialized) return [];
    return getAllConversations()
        .where(
          (c) =>
              c.assistantId == assistantId &&
              c.summary != null &&
              c.summary!.trim().isNotEmpty,
        )
        .toList();
  }

  /// Clears the summary of a specific conversation.
  Future<void> clearConversationSummary(String conversationId) async {
    if (!_initialized) return;

    if (_draftConversations.containsKey(conversationId)) {
      final draft = _draftConversations[conversationId]!;
      draft.summary = null;
      draft.lastSummarizedMessageCount = 0;
      notifyListeners();
      return;
    }

    if (!_conversationsCache.containsKey(conversationId)) return;

    final updated = await _updatePersistedConversation(conversationId, (
      conversation,
    ) async {
      conversation.summary = null;
      conversation.lastSummarizedMessageCount = 0;
      return true;
    });
    if (updated == null) return;
    notifyListeners();
  }

  Future<void> updateConversationSuggestions(
    String conversationId,
    List<String> suggestions,
  ) async {
    if (!_initialized) return;

    final clean = suggestions
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(3)
        .toList();

    if (_draftConversations.containsKey(conversationId)) {
      final draft = _draftConversations[conversationId]!;
      draft.chatSuggestions = clean;
      notifyListeners();
      return;
    }

    if (!_conversationsCache.containsKey(conversationId)) return;

    final updated = await _updatePersistedConversation(conversationId, (
      conversation,
    ) async {
      conversation.chatSuggestions = clean;
      return true;
    });
    if (updated == null) return;
    notifyListeners();
  }

  Future<void> clearConversationSuggestions(String conversationId) async {
    if (!_initialized) return;

    if (_draftConversations.containsKey(conversationId)) {
      final draft = _draftConversations[conversationId]!;
      if (draft.chatSuggestions.isEmpty) return;
      draft.chatSuggestions = <String>[];
      notifyListeners();
      return;
    }

    if (!_conversationsCache.containsKey(conversationId)) return;

    final updated = await _updatePersistedConversation(conversationId, (
      conversation,
    ) async {
      if (conversation.chatSuggestions.isEmpty) return false;
      conversation.chatSuggestions = <String>[];
      return true;
    });
    if (updated == null) return;
    notifyListeners();
  }

  Future<void> togglePinConversation(String id) async {
    if (!_initialized) return;

    if (_draftConversations.containsKey(id)) {
      final draft = _draftConversations[id]!;
      draft.isPinned = !draft.isPinned;
      notifyListeners();
      return;
    }
    if (!_conversationsCache.containsKey(id)) return;
    final updated = await _updatePersistedConversation(id, (
      conversation,
    ) async {
      conversation.isPinned = !conversation.isPinned;
      return true;
    });
    if (updated == null) return;
    notifyListeners();
  }

  Future<ChatMessage> addMessage({
    required String conversationId,
    required String role,
    required String content,
    String? modelId,
    String? providerId,
    int? totalTokens,
    bool isStreaming = false,
    String? reasoningText,
    DateTime? reasoningStartAt,
    DateTime? reasoningFinishedAt,
    String? groupId,
    int? version,
    String? turnId,
    String? generationStatus,
    bool selectVersion = false,
  }) async {
    if (!_initialized) await init();

    var conversation = _conversationsCache[conversationId];
    final temporary = _temporaryConversationIds.contains(conversationId);
    if (conversation == null) {
      final draft = temporary
          ? _draftConversations[conversationId]
          : _draftConversations[conversationId];
      if (draft != null) {
        conversation = draft;
      } else {
        conversation = Conversation(
          id: conversationId,
          title: _defaultConversationTitle,
        );
        if (temporary) {
          _draftConversations[conversationId] = conversation;
        }
      }
    }

    final message = ChatMessage(
      role: role,
      content: content,
      conversationId: conversationId,
      modelId: modelId,
      providerId: providerId,
      totalTokens: totalTokens,
      isStreaming: isStreaming,
      reasoningText: reasoningText,
      reasoningStartAt: reasoningStartAt,
      reasoningFinishedAt: reasoningFinishedAt,
      groupId: groupId,
      version: version,
      turnId: turnId,
      generationStatus: generationStatus,
    );
    final targetConversation = conversation;

    Future<ChatMessage> write() async {
      if (temporary) {
        targetConversation.messageIds.add(message.id);
        targetConversation.updatedAt = DateTime.now();
        if (selectVersion) {
          targetConversation.versionSelections[message.groupId ?? message.id] =
              message.version;
        }
        _messagesCache.putIfAbsent(conversationId, () => <ChatMessage>[]);
      } else {
        if (_conversationsCache.containsKey(conversationId)) {
          await _loadMessageOrder(conversationId);
        }
        final persisted = await _repo.appendLinearMessageToConversation(
          conversation: targetConversation,
          message: message,
          selectVersion: selectVersion,
        );
        if (_messageCanOwnAssets(message)) {
          await _synchronizeMessageAssetsBestEffort(message);
        }
        _draftConversations.remove(conversationId);
        _conversationsCache[conversationId] = persisted;
        conversation = persisted;
        final order = _messageOrderIds.putIfAbsent(
          conversationId,
          () => <String>[],
        );
        if (!order.contains(message.id)) order.add(message.id);
        _messageCounts[conversationId] = order.length;
      }

      if (_messagesCache.containsKey(conversationId)) {
        _messagesCache[conversationId]!.add(message);
      }
      notifyListeners();
      return message;
    }

    if (temporary || !_isTerminalMessage(message)) return write();
    final keys = message.role == 'assistant'
        ? _messageGraphKeys(message)
        : <SyncEntityKey>{
            _conversationKey(conversationId),
            _turnKey(message.turnId),
            _messageKey(message.id),
          };
    return _syncWriteExecutor.runLocalBatch<ChatMessage>(
      keys: keys,
      write: write,
    );
  }

  Future<GenerationBeginResult> beginSendGeneration({
    required String conversationId,
    required String userContent,
    required String modelId,
    required String providerId,
  }) async {
    if (!_initialized) await init();
    if (isTemporaryConversation(conversationId)) {
      throw StateError('temporary_generation_is_not_persisted');
    }
    final conversation =
        _conversationsCache[conversationId] ??
        _draftConversations[conversationId] ??
        Conversation(id: conversationId, title: _defaultConversationTitle);
    if (_conversationsCache.containsKey(conversationId)) {
      await _loadMessageOrder(conversationId);
    }
    final turnId = const Uuid().v4();
    final userMessage = ChatMessage(
      role: 'user',
      content: userContent,
      conversationId: conversationId,
      turnId: turnId,
    );
    final assistantMessage = ChatMessage(
      role: 'assistant',
      content: '',
      conversationId: conversationId,
      modelId: modelId,
      providerId: providerId,
      isStreaming: true,
      turnId: turnId,
    );
    return _syncWriteExecutor.runLocalBatch<GenerationBeginResult>(
      keys: <SyncEntityKey>{
        _conversationKey(conversationId),
        _turnKey(turnId),
        _messageKey(userMessage.id),
      },
      write: () async {
        final result = await _repo.beginSendGeneration(
          conversation: conversation,
          userMessage: userMessage,
          assistantMessage: assistantMessage,
          runId: const Uuid().v4(),
        );
        await _publishGenerationBegin(result);
        return result;
      },
    );
  }

  Future<GenerationBeginResult> beginRegeneration({
    required String conversationId,
    required String modelId,
    required String providerId,
    required String turnId,
    required String groupId,
    required int version,
    required bool truncateFuture,
  }) async {
    if (!_initialized) await init();
    if (isTemporaryConversation(conversationId)) {
      throw StateError('temporary_generation_is_not_persisted');
    }
    final conversation = _conversationsCache[conversationId];
    if (conversation == null) throw StateError('conversation_missing');
    await _loadMessageOrder(conversationId);
    final assistantMessage = ChatMessage(
      role: 'assistant',
      content: '',
      conversationId: conversationId,
      modelId: modelId,
      providerId: providerId,
      isStreaming: true,
      turnId: turnId,
      groupId: groupId,
      version: version,
    );

    Future<GenerationBeginResult> write() async {
      final latestConversation = await _repo.getConversation(conversationId);
      if (latestConversation == null) {
        throw StateError('conversation_missing');
      }
      final result = await _repo.beginRegeneration(
        conversation: latestConversation,
        assistantMessage: assistantMessage,
        runId: const Uuid().v4(),
        truncateFuture: truncateFuture,
      );
      if (truncateFuture) {
        _messagesCache.remove(conversationId);
        _messageOrderIds.remove(conversationId);
        await _loadMessageOrder(conversationId);
      }
      await _publishGenerationBegin(result);
      return result;
    }

    if (!truncateFuture) return write();
    final messages = await loadMessagesForSync(conversationId);
    final anchorIndex = messages.indexWhere(
      (message) => (message.groupId ?? message.id) == groupId,
    );
    if (anchorIndex < 0) return write();
    final trailing = messages
        .skip(anchorIndex + 1)
        .where((message) => (message.groupId ?? message.id) != groupId)
        .toList(growable: false);
    if (trailing.isEmpty) return write();
    final keys = <SyncEntityKey>{_conversationKey(conversationId)};
    for (final message in trailing) {
      keys
        ..addAll(_messageGraphKeys(message, includeSelectionWhenPresent: false))
        ..add(_messageSelectionKey(message.groupId ?? message.id));
    }
    return _syncWriteExecutor.runLocalBatch<GenerationBeginResult>(
      keys: keys,
      write: write,
    );
  }

  Future<void> _publishGenerationBegin(GenerationBeginResult result) async {
    final conversationId = result.conversation.id;
    _draftConversations.remove(conversationId);
    _conversationsCache[conversationId] = result.conversation;
    final messages = [
      if (result.userMessage case final userMessage?) userMessage,
      result.assistantMessage,
    ];
    if (result.userMessage case final userMessage?
        when _messageCanOwnAssets(userMessage)) {
      await _synchronizeMessageAssetsBestEffort(userMessage);
    }
    final order = _messageOrderIds.putIfAbsent(
      conversationId,
      () => <String>[],
    );
    for (final message in messages) {
      if (!order.contains(message.id)) order.add(message.id);
    }
    _messageCounts[conversationId] = order.length;
    if (_messagesCache.containsKey(conversationId)) {
      _messagesCache[conversationId]!.addAll(messages);
    }
    notifyListeners();
  }

  ChatMessage? _cachedTemporaryMessage(String messageId) {
    for (final entry in _messagesCache.entries) {
      if (!_temporaryConversationIds.contains(entry.key)) continue;
      for (final message in entry.value) {
        if (message.id == messageId) return message;
      }
    }
    return null;
  }

  bool _isTemporaryMessageId(String messageId) {
    return _cachedTemporaryMessage(messageId) != null;
  }

  void _replaceCachedMessage(ChatMessage updatedMessage) {
    final messages = _messagesCache[updatedMessage.conversationId];
    if (messages == null) return;
    final index = messages.indexWhere((m) => m.id == updatedMessage.id);
    if (index >= 0) {
      messages[index] = updatedMessage;
    }
  }

  Future<void> updateMessage(
    String messageId, {
    String? content,
    int? totalTokens,
    bool? isStreaming,
    String? reasoningText,
    DateTime? reasoningStartAt,
    DateTime? reasoningFinishedAt,
    String? translation,
    String? reasoningSegmentsJson,
    int? promptTokens,
    int? completionTokens,
    int? cachedTokens,
    int? durationMs,
    String? generationStatus,
  }) async {
    if (!_initialized) return;

    final message =
        await _repo.getMessage(messageId) ?? _cachedTemporaryMessage(messageId);
    if (message == null) return;

    ChatMessage applyUpdate(ChatMessage source) => source.copyWith(
      content: content,
      totalTokens: totalTokens,
      isStreaming: isStreaming,
      reasoningText: reasoningText,
      reasoningStartAt: reasoningStartAt,
      reasoningFinishedAt: reasoningFinishedAt,
      translation: translation,
      reasoningSegmentsJson: reasoningSegmentsJson,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      cachedTokens: cachedTokens,
      durationMs: durationMs,
      generationStatus: generationStatus,
    );
    final initialUpdatedMessage = applyUpdate(message);

    if (isTemporaryConversation(message.conversationId)) {
      _replaceCachedMessage(initialUpdatedMessage);
      notifyListeners();
      return;
    }

    Future<void> write() async {
      final latest = await _repo.getMessage(messageId);
      if (latest == null) return;
      final updatedMessage = applyUpdate(latest);
      if (content != null) {
        await _repo.markMessageAssetReferencesDirty(updatedMessage.id);
      }
      await _repo.updateMessageAndStreamingState(
        updatedMessage,
        untrackStreaming: isStreaming == false,
      );
      if (content != null) {
        await _synchronizeMessageAssetsBestEffort(updatedMessage);
      }
      _replaceCachedMessage(updatedMessage);
      notifyListeners();
    }

    if (!_isTerminalMessage(initialUpdatedMessage)) return write();
    if (message.role == 'assistant' && !_isTerminalMessage(message)) {
      return _syncWriteExecutor.runLocalBatch<void>(
        keys: _messageGraphKeys(initialUpdatedMessage),
        write: write,
      );
    }
    return _syncWriteExecutor.runLocal<void>(
      key: _messageKey(messageId),
      write: write,
    );
  }

  /// 流式生成期间只更新消息内容，不触发 notifyListeners，
  /// 避免监听 ChatService 的界面组件发生无意义重建。
  Future<void> updateMessageSilent(
    String messageId, {
    String? content,
    int? totalTokens,
    bool? isStreaming,
    String? reasoningText,
    DateTime? reasoningStartAt,
    DateTime? reasoningFinishedAt,
    String? translation,
    String? reasoningSegmentsJson,
    int? promptTokens,
    int? completionTokens,
    int? cachedTokens,
    int? durationMs,
    String? generationStatus,
  }) async {
    if (!_initialized) return;

    final message =
        await _repo.getMessage(messageId) ?? _cachedTemporaryMessage(messageId);
    if (message == null) return;

    ChatMessage applyUpdate(ChatMessage source) => source.copyWith(
      content: content,
      totalTokens: totalTokens,
      isStreaming: isStreaming,
      reasoningText: reasoningText,
      reasoningStartAt: reasoningStartAt,
      reasoningFinishedAt: reasoningFinishedAt,
      translation: translation,
      reasoningSegmentsJson: reasoningSegmentsJson,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      cachedTokens: cachedTokens,
      durationMs: durationMs,
      generationStatus: generationStatus,
    );
    final initialUpdatedMessage = applyUpdate(message);

    if (isTemporaryConversation(message.conversationId)) {
      _replaceCachedMessage(initialUpdatedMessage);
      return;
    }

    Future<void> write() async {
      final latest = await _repo.getMessage(messageId);
      if (latest == null) return;
      final updatedMessage = applyUpdate(latest);
      await _repo.updateMessageAndStreamingState(
        updatedMessage,
        untrackStreaming: isStreaming == false,
      );
      _replaceCachedMessage(updatedMessage);
    }

    if (!_isTerminalMessage(initialUpdatedMessage)) return write();
    if (message.role == 'assistant' && !_isTerminalMessage(message)) {
      return _syncWriteExecutor.runLocalBatch<void>(
        keys: _messageGraphKeys(initialUpdatedMessage),
        write: write,
      );
    }
    return _syncWriteExecutor.runLocal<void>(
      key: _messageKey(messageId),
      write: write,
    );
  }

  /// 无需先读后写，直接持久化一份完整的流式快照。
  Future<void> updateStreamingCheckpointSilent(
    ChatMessage message,
    List<Map<String, dynamic>> toolEvents, {
    String? generationRunId,
    int? checkpointSeq,
  }) async {
    if (!_initialized) return;

    if (isTemporaryConversation(message.conversationId)) {
      _replaceCachedMessage(message);
      _temporaryToolEvents[message.id] = List<Map<String, dynamic>>.of(
        toolEvents,
      );
      return;
    }

    await _repo.updateStreamingCheckpoint(
      message,
      toolEvents,
      generationRunId: generationRunId,
      checkpointSeq: checkpointSeq,
    );
    _replaceCachedMessage(message);
    _toolEventsCache[message.id] = List<Map<String, dynamic>>.of(toolEvents);
  }

  Future<GenerationRun> transitionGenerationRun({
    required String id,
    required GenerationRunState expectedState,
    required int expectedStateRevision,
    required GenerationRunState nextState,
    String? errorCode,
  }) => _repo.transitionGenerationRun(
    id: id,
    expectedState: expectedState,
    expectedStateRevision: expectedStateRevision,
    nextState: nextState,
    updatedAt: DateTime.now().toUtc(),
    errorCode: errorCode,
  );

  Future<GenerationRun?> finalizeGenerationRunSilent({
    required ChatMessage message,
    required List<Map<String, dynamic>> toolEvents,
    required String? generationRunId,
    required GenerationRunState? expectedState,
    required int? expectedStateRevision,
    required GenerationRunState terminalState,
    int? checkpointSeq,
    String? errorCode,
  }) async {
    if (!_initialized) return null;
    if (isTemporaryConversation(message.conversationId)) {
      await updateStreamingCheckpointSilent(message, toolEvents);
      return null;
    }
    Future<GenerationRun?> write() async {
      if (generationRunId == null) {
        await updateStreamingCheckpointSilent(message, toolEvents);
        _statisticsRevision++;
        notifyListeners();
        return null;
      }
      if (expectedState == null || expectedStateRevision == null) {
        throw StateError('generation_run_cursor_missing');
      }
      final run = await _repo.finalizeGenerationRun(
        message: message,
        toolEvents: toolEvents,
        generationRunId: generationRunId,
        expectedState: expectedState,
        expectedStateRevision: expectedStateRevision,
        terminalState: terminalState,
        checkpointSeq: checkpointSeq,
        errorCode: errorCode,
        geminiThoughtSignature: _geminiThoughtSigsCache[message.id],
      );
      if (_messageCanOwnAssets(message)) {
        await _synchronizeMessageAssetsBestEffort(message);
      }
      _replaceCachedMessage(message);
      _toolEventsCache[message.id] = List<Map<String, dynamic>>.of(toolEvents);
      _statisticsRevision++;
      notifyListeners();
      return run;
    }

    if (!_isTerminalMessage(message)) return write();
    return _syncWriteExecutor.runLocalBatch<GenerationRun?>(
      keys: _messageGraphKeys(message),
      write: write,
    );
  }

  // Tool events persistence (per assistant message)
  List<Map<String, dynamic>> getToolEvents(String assistantMessageId) {
    if (!_initialized) return const <Map<String, dynamic>>[];
    final temporary = _temporaryToolEvents[assistantMessageId];
    if (temporary != null) return List<Map<String, dynamic>>.of(temporary);
    return List<Map<String, dynamic>>.of(
      _toolEventsCache[assistantMessageId] ?? const [],
    );
  }

  bool hasToolEvents(String assistantMessageId) {
    if (!_initialized) return false;
    return _temporaryToolEvents.containsKey(assistantMessageId) ||
        _toolEventsCache.containsKey(assistantMessageId);
  }

  Future<void> setToolEvents(
    String assistantMessageId,
    List<Map<String, dynamic>> events,
  ) async {
    if (!_initialized) await init();
    if (_isTemporaryMessageId(assistantMessageId)) {
      _temporaryToolEvents[assistantMessageId] = List<Map<String, dynamic>>.of(
        events,
      );
      notifyListeners();
      return;
    }
    final message = await _repo.getMessage(assistantMessageId);
    if (message == null) return;
    Future<void> write() async {
      await _repo.setToolEvents(assistantMessageId, events);
      _toolEventsCache[assistantMessageId] = List<Map<String, dynamic>>.of(
        events,
      );
      notifyListeners();
    }

    if (!_isTerminalMessage(message)) return write();
    return _syncWriteExecutor.runLocal<void>(
      key: _toolEventKey(assistantMessageId),
      write: write,
    );
  }

  Future<void> upsertToolEvent(
    String assistantMessageId, {
    required String id,
    required String name,
    required Map<String, dynamic> arguments,
    String? content,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_initialized) await init();
    final cleanId = (id).toString();

    List<Map<String, dynamic>> mergeEvent(List<Map<String, dynamic>> current) {
      final list = List<Map<String, dynamic>>.of(current);
      var index = cleanId.isEmpty
          ? -1
          : list.indexWhere(
              (event) => (event['id']?.toString() ?? '') == cleanId,
            );
      if (index < 0) {
        index = list.indexWhere(
          (event) =>
              (event['name']?.toString() ?? '') == name &&
              (event['content'] == null ||
                  (event['content']?.toString().isEmpty ?? true)),
        );
      }
      final record = <String, dynamic>{
        'id': cleanId,
        'name': name,
        'arguments': arguments,
        'content': content,
      };
      final existingMetadata = index >= 0 ? list[index]['metadata'] : null;
      if (metadata != null && metadata.isNotEmpty) {
        record['metadata'] = metadata;
      } else if (existingMetadata is Map && existingMetadata.isNotEmpty) {
        record['metadata'] = existingMetadata.cast<String, dynamic>();
      }
      if (index >= 0) {
        list[index] = record;
      } else {
        list.add(record);
      }
      return list;
    }

    if (_isTemporaryMessageId(assistantMessageId)) {
      _temporaryToolEvents[assistantMessageId] = mergeEvent(
        getToolEvents(assistantMessageId),
      );
      notifyListeners();
      return;
    }
    final message = await _repo.getMessage(assistantMessageId);
    if (message == null) return;
    Future<void> write() async {
      final events = mergeEvent(await _repo.getToolEvents(assistantMessageId));
      await _repo.setToolEvents(assistantMessageId, events);
      _toolEventsCache[assistantMessageId] = events;
      notifyListeners();
    }

    if (!_isTerminalMessage(message)) return write();
    await _syncWriteExecutor.runLocal<void>(
      key: _toolEventKey(assistantMessageId),
      write: write,
    );
  }

  // Gemini thought signature persistence (per assistant message)
  String? getGeminiThoughtSignature(String assistantMessageId) {
    if (!_initialized) return null;
    final temporary = _temporaryGeminiThoughtSigs[assistantMessageId];
    if (temporary != null && temporary.trim().isNotEmpty) return temporary;
    return _geminiThoughtSigsCache[assistantMessageId];
  }

  Future<void> setGeminiThoughtSignature(
    String assistantMessageId,
    String signature,
  ) async {
    if (!_initialized) await init();
    if (_isTemporaryMessageId(assistantMessageId)) {
      _temporaryGeminiThoughtSigs[assistantMessageId] = signature;
      notifyListeners();
      return;
    }
    final message = await _repo.getMessage(assistantMessageId);
    if (message == null) return;
    Future<void> write() async {
      await _repo.setGeminiThoughtSignature(assistantMessageId, signature);
      _geminiThoughtSigsCache[assistantMessageId] = signature;
      notifyListeners();
    }

    if (!_isTerminalMessage(message)) return write();
    return _syncWriteExecutor.runLocal<void>(
      key: _thoughtSignatureKey(assistantMessageId),
      write: write,
    );
  }

  Future<void> removeGeminiThoughtSignature(String assistantMessageId) async {
    if (!_initialized) await init();
    if (_isTemporaryMessageId(assistantMessageId)) {
      _temporaryGeminiThoughtSigs.remove(assistantMessageId);
      return;
    }
    final message = await _repo.getMessage(assistantMessageId);
    if (message == null) return;
    Future<void> write() async {
      await _repo.deleteGeminiThoughtSignature(assistantMessageId);
      _geminiThoughtSigsCache.remove(assistantMessageId);
    }

    if (!_isTerminalMessage(message)) return write();
    return _syncWriteExecutor.runLocal<void>(
      key: _thoughtSignatureKey(assistantMessageId),
      write: write,
    );
  }

  Future<Conversation> forkConversationAtRevision({
    required String sourceConversationId,
    required String sourceRevisionId,
    required String title,
  }) async {
    if (!_initialized) await init();
    final source = _conversationsCache[sourceConversationId];
    if (source == null) throw StateError('conversation_missing');
    final targetMessage = await _repo.getMessage(sourceRevisionId);
    if (targetMessage == null ||
        targetMessage.conversationId != sourceConversationId) {
      throw StateError('linear_fork_target_missing');
    }
    final targetGroupId = targetMessage.groupId ?? targetMessage.id;
    final probe = await _repo.loadLinearMessageWindow(
      conversationId: sourceConversationId,
      fromStart: true,
      limit: 1,
    );
    final window = await _repo.loadLinearMessageWindow(
      conversationId: sourceConversationId,
      fromStart: true,
      limit: probe.totalSlotCount,
    );
    final targetIndex = window.slots.indexWhere(
      (slot) => slot.groupId == targetGroupId,
    );
    if (targetIndex < 0) throw StateError('linear_fork_target_not_visible');
    final sourceMessages = await _repo.getMessagesByIds([
      for (final slot in window.slots.take(targetIndex + 1)) slot.revisionId,
    ]);
    final persisted = await createConversation(
      title: source.title,
      assistantId: source.assistantId,
    );
    _messagesCache[persisted.id] = <ChatMessage>[];
    _messageOrderIds[persisted.id] = <String>[];
    _messageCounts[persisted.id] = 0;
    for (final message in sourceMessages) {
      await addMessageDirectly(
        persisted.id,
        ChatMessage(
          role: message.role,
          content: message.content,
          timestamp: message.timestamp,
          modelId: message.modelId,
          providerId: message.providerId,
          totalTokens: message.totalTokens,
          conversationId: persisted.id,
          isStreaming: false,
          reasoningText: message.reasoningText,
          reasoningStartAt: message.reasoningStartAt,
          reasoningFinishedAt: message.reasoningFinishedAt,
          translation: message.translation,
          reasoningSegmentsJson: message.reasoningSegmentsJson,
          promptTokens: message.promptTokens,
          completionTokens: message.completionTokens,
          cachedTokens: message.cachedTokens,
          durationMs: message.durationMs,
        ),
      );
    }
    _currentConversationId = persisted.id;
    notifyListeners();
    return persisted;
  }

  Future<ChatMessage?> appendMessageVersion({
    required String messageId,
    required String content,
  }) async {
    if (!_initialized) await init();
    final original = await _repo.getMessage(messageId);
    if (original == null) return null;
    await _loadMessageOrder(original.conversationId);
    final newMessageId = const Uuid().v4();
    final keys = <SyncEntityKey>{
      _conversationKey(original.conversationId),
      _turnKey(original.turnId),
      _messageKey(original.id),
      _messageKey(newMessageId),
      _messageSelectionKey(original.groupId ?? original.id),
      if (original.role == 'assistant') _toolEventKey(newMessageId),
      if (original.role == 'assistant') _thoughtSignatureKey(newMessageId),
    };
    return _syncWriteExecutor.runLocalBatch<ChatMessage?>(
      keys: keys,
      write: () async {
        final result = await _repo.appendMessageVersion(
          messageId: messageId,
          content: content,
          newMessageId: newMessageId,
        );
        if (result == null) return null;
        final newMsg = result.message;
        if (_messageCanOwnAssets(newMsg)) {
          await _synchronizeMessageAssetsBestEffort(newMsg);
        }
        final cid = newMsg.conversationId;
        _conversationsCache[cid] = result.conversation;
        final order = _messageOrderIds.putIfAbsent(cid, () => <String>[]);
        if (!order.contains(newMsg.id)) order.add(newMsg.id);
        _messageCounts[cid] = order.length;
        final arr = _messagesCache[cid];
        if (arr != null) arr.add(newMsg);
        notifyListeners();
        return newMsg;
      },
    );
  }

  Map<String, int> getVersionSelections(String conversationId) {
    return Map<String, int>.from(
      (_draftConversations[conversationId] ??
                  _conversationsCache[conversationId])
              ?.versionSelections ??
          const <String, int>{},
    );
  }

  Future<void> setSelectedVersion(
    String conversationId,
    String groupId,
    int version,
  ) async {
    if (_draftConversations.containsKey(conversationId)) {
      final draft = _draftConversations[conversationId]!;
      draft.versionSelections[groupId] = version;
      draft.updatedAt = DateTime.now();
      notifyListeners();
      return;
    }
    if (!_conversationsCache.containsKey(conversationId)) {
      throw StateError('message_version_missing');
    }
    await _syncWriteExecutor.runLocalBatch<void>(
      keys: <SyncEntityKey>{
        _conversationKey(conversationId),
        _messageSelectionKey(groupId),
      },
      write: () async {
        final candidates = await _repo.getMessagesForGroups(conversationId, [
          groupId,
        ]);
        if (!candidates.any((candidate) => candidate.version == version)) {
          throw StateError('message_version_missing');
        }
        final conversation = await _repo.setSelectedVersion(
          conversationId: conversationId,
          groupId: groupId,
          version: version,
        );
        if (conversation == null) return;
        _conversationsCache[conversationId] = conversation;
        notifyListeners();
      },
    );
  }

  Future<void> clearSelectedVersion(
    String conversationId,
    String groupId,
  ) async {
    if (_draftConversations.containsKey(conversationId)) {
      final draft = _draftConversations[conversationId]!;
      draft.versionSelections.remove(groupId);
      draft.updatedAt = DateTime.now();
      notifyListeners();
      return;
    }
    if (!_conversationsCache.containsKey(conversationId)) return;
    await _syncWriteExecutor.runLocalBatch<void>(
      keys: <SyncEntityKey>{
        _conversationKey(conversationId),
        _messageSelectionKey(groupId),
      },
      write: () async {
        final conversation = await _repo.setSelectedVersion(
          conversationId: conversationId,
          groupId: groupId,
          version: null,
        );
        if (conversation == null) return;
        _conversationsCache[conversationId] = conversation;
        notifyListeners();
      },
    );
  }

  Future<Conversation?> toggleTruncateAtTail(
    String conversationId, {
    String? defaultTitle,
  }) async {
    if (!_initialized) await init();
    // Draft case
    if (_draftConversations.containsKey(conversationId)) {
      final draft = _draftConversations[conversationId]!;
      final lastIndexPlusOne = draft.messageIds.length; // last index + 1
      final newValue = (draft.truncateIndex == lastIndexPlusOne)
          ? -1
          : lastIndexPlusOne;
      draft.truncateIndex = newValue;
      if ((defaultTitle ?? '').isNotEmpty) draft.title = defaultTitle!;
      draft.updatedAt = DateTime.now();
      notifyListeners();
      return draft;
    }
    if (!_conversationsCache.containsKey(conversationId)) return null;
    // Persisted case
    var changed = false;
    final updated = await _updatePersistedConversation(conversationId, (
      conversation,
    ) async {
      final probe = await _repo.loadLinearMessageWindow(
        conversationId: conversationId,
        fromStart: true,
        limit: 1,
      );
      if (probe.totalSlotCount == 0) return false;
      conversation.truncateIndex =
          conversation.truncateIndex == probe.totalSlotCount
          ? -1
          : probe.totalSlotCount;
      if ((defaultTitle ?? '').isNotEmpty) {
        conversation.title = defaultTitle!;
      }
      conversation.updatedAt = DateTime.now();
      changed = true;
      return true;
    });
    if (updated == null) return null;
    if (changed) notifyListeners();
    return updated;
  }

  Future<void> deleteMessage(String messageId) async {
    if (!_initialized) return;

    final message =
        await _repo.getMessage(messageId) ?? _cachedTemporaryMessage(messageId);
    if (message == null) return;

    if (isTemporaryConversation(message.conversationId)) {
      final conversation = _draftConversations[message.conversationId];
      conversation?.messageIds.remove(messageId);
      final messages = _messagesCache[message.conversationId];
      messages?.removeWhere((m) => m.id == messageId);
      _temporaryToolEvents.remove(messageId);
      _temporaryGeminiThoughtSigs.remove(messageId);
      notifyListeners();
      return;
    }
    final conversation = _conversationsCache[message.conversationId];
    if (conversation == null) return;
    await deleteMessages(
      conversationId: conversation.id,
      messageIds: {messageId},
      versionSelectionChanges: const {},
    );
  }

  Future<Set<String>> deleteMessages({
    required String conversationId,
    required Set<String> messageIds,
    required Map<String, int?> versionSelectionChanges,
  }) async {
    if (!_initialized || messageIds.isEmpty) return const <String>{};
    if (_temporaryConversationIds.contains(conversationId)) {
      final conversation = _draftConversations[conversationId];
      final messages = _messagesCache[conversationId];
      if (conversation == null || messages == null) return const <String>{};
      final deletedIds = messages
          .where((message) => messageIds.contains(message.id))
          .map((message) => message.id)
          .toSet();
      if (deletedIds.isEmpty) return const <String>{};
      messages.removeWhere((message) => deletedIds.contains(message.id));
      conversation.messageIds.removeWhere(deletedIds.contains);
      for (final entry in versionSelectionChanges.entries) {
        final version = entry.value;
        if (version == null) {
          conversation.versionSelections.remove(entry.key);
        } else {
          conversation.versionSelections[entry.key] = version;
        }
      }
      conversation.updatedAt = DateTime.now();
      for (final id in deletedIds) {
        _temporaryToolEvents.remove(id);
        _temporaryGeminiThoughtSigs.remove(id);
      }
      notifyListeners();
      return Set<String>.unmodifiable(deletedIds);
    }
    Future<Set<String>> write() async {
      final result = await _repo.deleteMessages(
        conversationId: conversationId,
        messageIds: messageIds,
        versionSelectionChanges: versionSelectionChanges,
      );
      if (result == null) return const <String>{};

      _conversationsCache[conversationId] = result.conversation;
      final deletedIds = <String>{};
      for (final message in result.messages) {
        deletedIds.add(message.id);
        _toolEventsCache.remove(message.id);
        _geminiThoughtSigsCache.remove(message.id);
      }
      _messagesCache.remove(conversationId);
      _messageOrderIds.remove(conversationId);
      _messageCounts[conversationId] = await _repo.getMessageCount(
        conversationId,
      );
      await _cleanupOrphanUploads();
      notifyListeners();
      return Set<String>.unmodifiable(deletedIds);
    }

    final persistedMessages =
        (await _repo.getMessagesByIds(messageIds.toList(growable: false)))
            .where((message) => message.conversationId == conversationId)
            .toList(growable: false);
    if (persistedMessages.isEmpty && versionSelectionChanges.isEmpty) {
      return write();
    }
    if (persistedMessages.length != messageIds.length) {
      throw StateError('delete_messages_not_found');
    }

    final keys = <SyncEntityKey>{_conversationKey(conversationId)};
    for (final message in persistedMessages) {
      keys.addAll(_messageGraphKeys(message));
    }
    keys.addAll(
      (_conversationsCache[conversationId]?.versionSelections.keys ??
              const <String>[])
          .map(_messageSelectionKey),
    );
    keys.addAll(versionSelectionChanges.keys.map(_messageSelectionKey));
    return _syncWriteExecutor.runLocalBatch<Set<String>>(
      keys: keys,
      write: write,
    );
  }

  void setCurrentConversation(String? id) {
    if (id != _currentConversationId) {
      _discardTemporaryConversation(_currentConversationId);
    }
    _currentConversationId = id;
    _enforceMessageCacheLimits();
    notifyListeners();
  }

  Future<void> clearAllData({bool deleteUploads = true}) async {
    if (!_initialized) await init();

    Future<void> write() async {
      await _repo.clearAllData();
      _messagesCache.clear();
      _conversationsCache.clear();
      _draftConversations.clear();
      _temporaryConversationIds.clear();
      _temporaryToolEvents.clear();
      _temporaryGeminiThoughtSigs.clear();
      _toolEventsCache.clear();
      _geminiThoughtSigsCache.clear();
      _messageCounts.clear();
      _messageOrderIds.clear();
      _currentConversationId = null;
      if (deleteUploads) {
        final uploadDir = await AppDirectories.getUploadDirectory();
        if (await uploadDir.exists()) {
          await uploadDir.delete(recursive: true);
        }
      }
      notifyListeners();
    }

    if (identical(Zone.current[_importBatchZoneKey], this)) {
      await write();
      return;
    }
    await CloudSyncStore.runWithDefaultRescanWrite<void>(
      entityTypes: CloudSyncStore.chatRescanEntityTypes,
      localAuthoritativeEntityTypes: CloudSyncStore.chatRescanEntityTypes,
      write: write,
    );
  }

  // Uploads stats: count and total size of files under app documents/upload
  Future<UploadStats> getUploadStats() async {
    try {
      final uploadDir = await AppDirectories.getUploadDirectory();
      if (!await uploadDir.exists()) {
        return const UploadStats(fileCount: 0, totalBytes: 0);
      }
      int count = 0;
      int bytes = 0;
      final entries = uploadDir.listSync(recursive: true, followLinks: false);
      for (final ent in entries) {
        if (ent is File) {
          count += 1;
          try {
            bytes += await ent.length();
          } catch (_) {}
        }
      }
      return UploadStats(fileCount: count, totalBytes: bytes);
    } catch (_) {
      return const UploadStats(fileCount: 0, totalBytes: 0);
    }
  }

  // Move an existing conversation to a different assistant.
  // If the conversation is still a draft, update it in memory;
  // otherwise persist the assistantId change and updatedAt.
  Future<void> moveConversationToAssistant({
    required String conversationId,
    required String assistantId,
  }) async {
    if (!_initialized) await init();

    // Draft conversation case
    if (_draftConversations.containsKey(conversationId)) {
      final draft = _draftConversations[conversationId]!;
      draft.assistantId = assistantId;
      draft.updatedAt = DateTime.now();
      notifyListeners();
      return;
    }

    if (!_conversationsCache.containsKey(conversationId)) return;

    final updated = await _updatePersistedConversation(conversationId, (
      conversation,
    ) async {
      conversation.assistantId = assistantId;
      conversation.updatedAt = DateTime.now();
      return true;
    });
    if (updated == null) return;
    notifyListeners();
  }
}

class UploadStats {
  final int fileCount;
  final int totalBytes;
  const UploadStats({required this.fileCount, required this.totalBytes});
}

final class ActiveTimelineSlot {
  const ActiveTimelineSlot({
    required this.slotId,
    required this.revisionId,
    required this.parentRevisionId,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    required this.finalizedAt,
    required this.versionCount,
    required this.logicalIndex,
  });

  final String slotId;
  final String revisionId;
  final String? parentRevisionId;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? finalizedAt;
  final int versionCount;
  final int logicalIndex;
}
