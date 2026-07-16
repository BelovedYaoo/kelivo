import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../../utils/batched_change_notifier.dart';
import '../sync/sync_codec.dart';
import '../sync/sync_write_executor.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../utils/app_directories.dart';
import 'upload_directory_critical_section.dart';

class ChatService extends ChangeNotifier with BatchedChangeNotifier {
  ChatService(this._syncWriteExecutor);

  static const String _conversationsBoxName = 'conversations';
  static const String _messagesBoxName = 'messages';
  static const String _toolEventsBoxName = 'tool_events_v1';
  static const String _activeStreamingKey = '_active_streaming_ids';
  static const String _turnIdentityMigrationKey = '_turn_identity_v1';
  static const String _syncTurnMetadataPrefix = '_sync_turn_v1';
  static const String _conversationEntityType = 'conversation';
  static const String _turnEntityType = 'turn';
  static const String _messageEntityType = 'message';
  static const String _messageSelectionEntityType = 'message-selection';
  static const String _toolEventEntityType = 'tool-event';
  static const String _thoughtSignatureEntityType = 'thought-signature';
  static const int defaultInitialMessageMin = 2;
  static const int defaultInitialMessageMax = 240;
  static const int defaultInitialTextBudget = 20000;
  static const int defaultHistoryPageSize = 20;
  static const int defaultLoadedWindowMax = 360;

  late Box<Conversation> _conversationsBox;
  late Box<ChatMessage> _messagesBox;
  late Box
  _toolEventsBox; // key: assistantMessageId, value: List<Map<String,dynamic>>
  final SyncWriteExecutor _syncWriteExecutor;
  final Map<String, String> _messageConversationIds = <String, String>{};
  final Map<String, String> _turnConversationIds = <String, String>{};
  final Map<String, String> _selectionConversationIds = <String, String>{};
  int _remoteBatchDepth = 0;
  final Set<String> _remoteRebuildConversationIds = <String>{};
  bool _remoteNeedsOrphanCleanup = false;
  String _sigKey(String id) => 'sig_$id';

  String? _currentConversationId;
  final Map<String, List<ChatMessage>> _messagesCache = {};
  final Map<String, Conversation> _draftConversations = {};
  final Set<String> _temporaryConversationIds = <String>{};
  final Map<String, List<Map<String, dynamic>>> _temporaryToolEvents =
      <String, List<Map<String, dynamic>>>{};
  final Map<String, String> _temporaryGeminiThoughtSigs = <String, String>{};

  // Localized default title for new conversations; set by UI on startup.
  String _defaultConversationTitle = 'New Chat';
  void setDefaultConversationTitle(String title) {
    if (title.trim().isEmpty) return;
    _defaultConversationTitle = title.trim();
  }

  bool _initialized = false;
  Future<void>? _initialization;
  bool get initialized => _initialized;

  String? get currentConversationId => _currentConversationId;

  bool isTemporaryConversation(String? id) {
    return id != null && _temporaryConversationIds.contains(id);
  }

  Future<void> init() {
    if (_initialized) return Future<void>.value();
    return _initialization ??= _initialize().whenComplete(() {
      if (!_initialized) {
        _initialization = null;
      }
    });
  }

  Future<void> _initialize() async {
    // Initialize Hive with platform-specific directory
    final appDataDir = await AppDirectories.getAppDataDirectory();
    await Hive.initFlutter(appDataDir.path);

    // Register adapters if not already registered
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChatMessageAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ConversationAdapter());
    }

    _conversationsBox = await Hive.openBox<Conversation>(_conversationsBoxName);
    _messagesBox = await Hive.openBox<ChatMessage>(_messagesBoxName);
    _toolEventsBox = await Hive.openBox(_toolEventsBoxName);

    // Migrate any persisted message content that references old iOS sandbox paths
    await _migrateSandboxPaths();

    // 旧消息没有轮次字段，必须在云同步读取前按逻辑消息组补齐一致身份。
    await _migrateTurnIdentities();

    _rebuildSyncIndexes();

    // 崩溃恢复会立即导出写前批次；此时存储与索引已就绪，避免导出器递归等待本次初始化。
    _initialized = true;
    try {
      await _resetStaleStreamingFlags();
    } catch (_) {
      _initialized = false;
      rethrow;
    }
    notifyListeners();
  }

  List<Conversation> getAllConversations() {
    if (!_initialized) return [];
    final conversations = _conversationsBox.values.toList();
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return conversations;
  }

  List<Conversation> getPinnedConversations() {
    return getAllConversations().where((c) => c.isPinned).toList();
  }

  Conversation? getConversation(String id) {
    if (!_initialized) return null;
    return _conversationsBox.get(id) ?? _draftConversations[id];
  }

  Conversation? getConversationForSync(String id) {
    if (!_initialized) return null;
    return _conversationsBox.get(id);
  }

  ChatMessage? getMessageById(String messageId) {
    if (!_initialized) return null;
    if (_messageConversationIds.containsKey(messageId)) {
      return _messagesBox.get(messageId);
    }
    return _cachedTemporaryMessage(messageId);
  }

  String? getConversationIdForMessage(String messageId) {
    if (!_initialized) return null;
    return _messageConversationIds[messageId];
  }

  String? getConversationIdForTurn(String turnId) {
    if (!_initialized) return null;
    return _turnConversationIds[turnId];
  }

  String? getConversationIdForSelection(String groupId) {
    if (!_initialized) return null;
    return _selectionConversationIds[groupId];
  }

  List<ChatMessage> getMessagesForTurn(String turnId) {
    final conversationId = getConversationIdForTurn(turnId);
    if (conversationId == null) return const <ChatMessage>[];
    final conversation = _conversationsBox.get(conversationId);
    if (conversation == null) return const <ChatMessage>[];
    return conversation.messageIds
        .map(_messagesBox.get)
        .whereType<ChatMessage>()
        .where(
          (message) =>
              message.conversationId == conversationId &&
              message.turnId == turnId,
        )
        .toList(growable: false);
  }

  void _rebuildSyncIndexes() {
    _messageConversationIds.clear();
    _turnConversationIds.clear();
    _selectionConversationIds.clear();
    for (final conversation in _conversationsBox.values) {
      _indexConversation(conversation);
    }
  }

  void _indexConversation(Conversation conversation) {
    for (final groupId in conversation.versionSelections.keys) {
      _selectionConversationIds[groupId] = conversation.id;
    }
    for (final messageId in conversation.messageIds) {
      final message = _messagesBox.get(messageId);
      if (message == null || message.conversationId != conversation.id) {
        continue;
      }
      _messageConversationIds[message.id] = conversation.id;
      _turnConversationIds[message.turnId] = conversation.id;
    }
  }

  SyncEntityKey _conversationKey(String conversationId) => SyncEntityKey(
    entityType: _conversationEntityType,
    entityId: conversationId,
  );

  SyncEntityKey _turnKey(String turnId) =>
      SyncEntityKey(entityType: _turnEntityType, entityId: turnId);

  SyncEntityKey _messageKey(String messageId) =>
      SyncEntityKey(entityType: _messageEntityType, entityId: messageId);

  SyncEntityKey _messageSelectionKey(String groupId) =>
      SyncEntityKey(entityType: _messageSelectionEntityType, entityId: groupId);

  SyncEntityKey _toolEventKey(String messageId) =>
      SyncEntityKey(entityType: _toolEventEntityType, entityId: messageId);

  SyncEntityKey _thoughtSignatureKey(String messageId) => SyncEntityKey(
    entityType: _thoughtSignatureEntityType,
    entityId: messageId,
  );

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
    final conversation = _conversationsBox.get(message.conversationId);
    if (includeSelectionWhenPresent &&
        conversation?.versionSelections.containsKey(groupId) == true) {
      keys.add(_messageSelectionKey(groupId));
    }
    return keys;
  }

  bool _isTerminalMessage(ChatMessage message) {
    return !message.isStreaming &&
        message.generationStatus != ChatMessage.generationStatusDraft;
  }

  void _removeConversationFromSyncIndexes(String conversationId) {
    _messageConversationIds.removeWhere(
      (messageId, indexedConversationId) =>
          indexedConversationId == conversationId,
    );
    _turnConversationIds.removeWhere(
      (turnId, indexedConversationId) =>
          indexedConversationId == conversationId,
    );
    _selectionConversationIds.removeWhere(
      (groupId, indexedConversationId) =>
          indexedConversationId == conversationId,
    );
  }

  void _refreshConversationSyncIndexes(String conversationId) {
    _removeConversationFromSyncIndexes(conversationId);
    final conversation = _conversationsBox.get(conversationId);
    if (conversation != null) _indexConversation(conversation);
  }

  Set<SyncEntityKey> _allActiveSyncKeys() {
    final keys = <SyncEntityKey>{};
    for (final conversation in _conversationsBox.values) {
      keys.add(_conversationKey(conversation.id));
      keys.addAll(
        conversation.versionSelections.keys.map(_messageSelectionKey),
      );
      for (final messageId in conversation.messageIds) {
        final message = _messagesBox.get(messageId);
        if (message == null || message.conversationId != conversation.id) {
          continue;
        }
        keys
          ..add(_turnKey(message.turnId))
          ..add(_messageKey(message.id));
        if (message.role == 'assistant') {
          keys
            ..add(_toolEventKey(message.id))
            ..add(_thoughtSignatureKey(message.id));
        }
      }
    }
    return keys;
  }

  Future<T> runRemoteBatch<T>(Future<T> Function() apply) {
    return runNotificationBatch<T>(() async {
      _remoteBatchDepth++;
      try {
        return await apply();
      } finally {
        _remoteBatchDepth--;
        if (_remoteBatchDepth == 0) {
          final conversationIds = _remoteRebuildConversationIds.toList()
            ..sort();
          _remoteRebuildConversationIds.clear();
          for (final conversationId in conversationIds) {
            await _rebuildSyncedMessageOrder(conversationId);
          }
          if (_remoteNeedsOrphanCleanup) {
            _remoteNeedsOrphanCleanup = false;
            await _cleanupOrphanUploads();
          }
        }
      }
    });
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
    final keys = overwrite ? _allActiveSyncKeys() : <SyncEntityKey>{};
    final incomingConversations = conversations.toList(growable: false);
    final incomingMessages = messages.toList(growable: false);
    for (final conversation in incomingConversations) {
      keys.add(_conversationKey(conversation.id));
      keys.addAll(
        conversation.versionSelections.keys.map(_messageSelectionKey),
      );
    }
    final messagesByConversation = <String, List<ChatMessage>>{};
    for (final message in incomingMessages) {
      (messagesByConversation[message.conversationId] ??= <ChatMessage>[]).add(
        message,
      );
      keys
        ..add(_conversationKey(message.conversationId))
        ..add(_turnKey(message.turnId))
        ..add(_messageKey(message.id));
      if (message.role == 'assistant') {
        keys
          ..add(_toolEventKey(message.id))
          ..add(_thoughtSignatureKey(message.id));
      }
    }
    for (final conversationMessages in messagesByConversation.values) {
      for (final normalized in _normalizeTurnIdentities(conversationMessages)) {
        keys.add(_turnKey(normalized.turnId));
      }
    }
    keys.addAll(toolEventMessageIds.map(_toolEventKey));
    keys.addAll(thoughtSignatureMessageIds.map(_thoughtSignatureKey));

    Future<T> apply() => runNotificationBatch(write);
    if (keys.isEmpty) return apply();
    return _syncWriteExecutor.runLocalBatch<T>(keys: keys, write: apply);
  }

  Future<void> _rebuildSyncedMessageOrderOrDefer(String conversationId) async {
    if (_remoteBatchDepth > 0) {
      _remoteRebuildConversationIds.add(conversationId);
      return;
    }
    await _rebuildSyncedMessageOrder(conversationId);
  }

  Future<void> _cleanupOrphanUploadsOrDefer() async {
    if (_remoteBatchDepth > 0) {
      _remoteNeedsOrphanCleanup = true;
      return;
    }
    await _cleanupOrphanUploads();
  }

  Conversation? _conversationForMessages(String conversationId) {
    if (!_initialized) return _draftConversations[conversationId];
    return _conversationsBox.get(conversationId) ??
        _draftConversations[conversationId];
  }

  int getMessageCount(String conversationId) {
    final conversation = _conversationForMessages(conversationId);
    return conversation?.messageIds.length ?? 0;
  }

  int getMessageIndex(String conversationId, String messageId) {
    final conversation = _conversationForMessages(conversationId);
    if (conversation == null) return -1;
    return conversation.messageIds.indexOf(messageId);
  }

  Map<String, int> getFirstMessageIndicesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) {
    final remaining = groupIds.where((id) => id.isNotEmpty).toSet();
    if (remaining.isEmpty) return const <String, int>{};

    final result = <String, int>{};
    final count = getMessageCount(conversationId);
    for (
      var start = 0;
      start < count && remaining.isNotEmpty;
      start += defaultLoadedWindowMax
    ) {
      final range = getMessagesRange(
        conversationId,
        start: start,
        limit: defaultLoadedWindowMax,
      );
      for (var offset = 0; offset < range.length; offset++) {
        final message = range[offset];
        final groupId = message.groupId ?? message.id;
        if (remaining.remove(groupId)) {
          result[groupId] = start + offset;
          if (remaining.isEmpty) break;
        }
      }
    }

    return result;
  }

  List<ChatMessage> getMessagesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) {
    final remaining = groupIds.where((id) => id.isNotEmpty).toSet();
    if (remaining.isEmpty) return const <ChatMessage>[];

    final result = <ChatMessage>[];
    final count = getMessageCount(conversationId);
    for (var start = 0; start < count; start += defaultLoadedWindowMax) {
      final range = getMessagesRange(
        conversationId,
        start: start,
        limit: defaultLoadedWindowMax,
      );
      for (final message in range) {
        final groupId = message.groupId ?? message.id;
        if (remaining.contains(groupId)) {
          result.add(message);
        }
      }
    }

    return result;
  }

  ChatMessage? _messageForConversation(
    String conversationId,
    String messageId,
  ) {
    if (_temporaryConversationIds.contains(conversationId)) {
      final messages = _messagesCache[conversationId];
      if (messages == null) return null;
      for (final message in messages) {
        if (message.id == messageId) return message;
      }
      return null;
    }
    return _messagesBox.get(messageId);
  }

  List<ChatMessage> getMessages(String conversationId) {
    if (!_initialized) return [];

    // Check cache first
    if (_messagesCache.containsKey(conversationId)) {
      return _messagesCache[conversationId]!;
    }

    // Load from storage
    final conversation =
        _conversationsBox.get(conversationId) ??
        _draftConversations[conversationId];
    if (conversation == null) return [];

    final messages = <ChatMessage>[];
    for (final messageId in conversation.messageIds) {
      final message = _messageForConversation(conversationId, messageId);
      if (message != null) {
        messages.add(message);
      }
    }

    // Cache the result
    _messagesCache[conversationId] = messages;
    return messages;
  }

  List<ChatMessage> getMessagesRange(
    String conversationId, {
    required int start,
    required int limit,
  }) {
    if (!_initialized || limit <= 0) return const <ChatMessage>[];

    final conversation = _conversationForMessages(conversationId);
    if (conversation == null || conversation.messageIds.isEmpty) {
      return const <ChatMessage>[];
    }

    final ids = conversation.messageIds;
    final safeStart = start.clamp(0, ids.length).toInt();
    final end = (safeStart + limit).clamp(safeStart, ids.length).toInt();
    if (safeStart >= end) return const <ChatMessage>[];

    final messages = <ChatMessage>[];
    for (var i = safeStart; i < end; i++) {
      final message = _messageForConversation(conversationId, ids[i]);
      if (message != null) messages.add(message);
    }
    return messages;
  }

  List<ChatMessage> getRecentMessages(
    String conversationId, {
    int minMessages = defaultInitialMessageMin,
    int textBudget = defaultInitialTextBudget,
    int maxMessages = defaultInitialMessageMax,
  }) {
    if (!_initialized) return const <ChatMessage>[];

    final conversation = _conversationForMessages(conversationId);
    if (conversation == null || conversation.messageIds.isEmpty) {
      return const <ChatMessage>[];
    }

    final ids = conversation.messageIds;
    final minCount = minMessages.clamp(1, ids.length).toInt();
    final maxCount = maxMessages < minCount ? minCount : maxMessages;
    final budget = textBudget <= 0 ? defaultInitialTextBudget : textBudget;

    var start = ids.length;
    var loaded = 0;
    var weight = 0;
    while (start > 0 && loaded < maxCount) {
      start--;
      final message = _messageForConversation(conversationId, ids[start]);
      if (message == null) continue;
      loaded++;
      weight += _estimateInitialLoadWeight(message);
      if (loaded >= minCount && weight >= budget) break;
    }

    if (loaded.isOdd && start > 0 && loaded < maxCount) {
      start--;
    }

    return getMessagesRange(
      conversationId,
      start: start,
      limit: ids.length - start,
    );
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

    return _syncWriteExecutor.runLocal<Conversation>(
      key: _conversationKey(conversation.id),
      write: () async {
        await _conversationsBox.put(conversation.id, conversation);
        _indexConversation(conversation);
        _currentConversationId = conversation.id;
        notifyListeners();
        return conversation;
      },
    );
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

    if (_draftConversations.containsKey(id)) {
      await _deleteConversationRaw(id);
      return;
    }
    if (!_conversationsBox.containsKey(id)) return;
    await _syncWriteExecutor.runLocal<void>(
      key: _conversationKey(id),
      write: () => _deleteConversationRaw(id),
    );
  }

  Future<void> _deleteConversationRaw(
    String id, {
    bool deferRemoteCleanup = false,
  }) async {
    final deleted =
        await _deleteDraftConversation(id) ||
        await _deletePersistedConversation(id);
    if (!deleted) return;

    // Delete orphaned files (not referenced by any remaining conversation)
    if (deferRemoteCleanup) {
      await _cleanupOrphanUploadsOrDefer();
    } else {
      await _cleanupOrphanUploads();
    }

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
    final conversation = _conversationsBox.get(id);
    if (conversation == null) return false;

    final turnIds = <String>{};
    for (final messageId in conversation.messageIds) {
      final msg = _messagesBox.get(messageId);
      if (msg != null) {
        turnIds.add(msg.turnId);
      }
      if (msg != null && msg.role == 'assistant') {
        await _toolEventsBox.delete(msg.id);
        await _toolEventsBox.delete(_sigKey(msg.id));
      }
      await _messagesBox.delete(messageId);
    }
    for (final turnId in turnIds) {
      await _toolEventsBox.delete(_syncTurnMetadataKey(id, turnId));
    }

    await _conversationsBox.delete(id);
    _messagesCache.remove(id);
    _removeConversationFromSyncIndexes(id);

    if (_currentConversationId == id) {
      _currentConversationId = null;
    }
    return true;
  }

  Future<void> deleteConversationsForAssistant(String assistantId) async {
    if (!_initialized) await init();

    final targetId = assistantId.trim();
    if (targetId.isEmpty) return;

    final persistedConversationIds = _conversationsBox.values
        .where((conversation) => conversation.assistantId == targetId)
        .map((conversation) => conversation.id)
        .toList(growable: false);
    final draftConversationIds = _draftConversations.values
        .where((conversation) => conversation.assistantId == targetId)
        .map((conversation) => conversation.id)
        .toList(growable: false);

    Future<void> write() async {
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

    if (persistedConversationIds.isEmpty) {
      await write();
      return;
    }
    await _syncWriteExecutor.runLocalBatch<void>(
      keys: persistedConversationIds.map(_conversationKey),
      write: write,
    );
  }

  Set<String> _extractAttachmentPaths(String content) {
    final out = <String>{};
    final imgRe = RegExp(r"\[image:(.+?)\]");
    for (final m in imgRe.allMatches(content)) {
      final pth = m.group(1)?.trim();
      if (pth != null &&
          pth.isNotEmpty &&
          !pth.startsWith('http') &&
          !pth.startsWith('data:')) {
        out.add(SandboxPathResolver.fix(pth));
      }
    }
    final fileRe = RegExp(r"\[file:(.+?)\|(.+?)\|(.+?)\]");
    for (final m in fileRe.allMatches(content)) {
      final pth = m.group(1)?.trim();
      if (pth != null &&
          pth.isNotEmpty &&
          !pth.startsWith('http') &&
          !pth.startsWith('data:')) {
        out.add(SandboxPathResolver.fix(pth));
      }
    }
    return out;
  }

  Future<void> _migrateSandboxPaths() async {
    try {
      // No-op if empty
      if (_messagesBox.isEmpty) return;
      final imgRe = RegExp(r"\[image:(.+?)\]");
      final fileRe = RegExp(r"\[file:(.+?)\|(.+?)\|(.+?)\]");

      for (final key in _messagesBox.keys) {
        final msg = _messagesBox.get(key);
        if (msg == null) continue;
        final content = msg.content;
        String updated = content;
        bool changed = false;

        // Rewrite image paths
        updated = updated.replaceAllMapped(imgRe, (m) {
          final raw = (m.group(1) ?? '').trim();
          final fixed = SandboxPathResolver.fix(raw);
          if (fixed != raw) changed = true;
          return '[image:$fixed]';
        });

        // Rewrite file attachment paths
        updated = updated.replaceAllMapped(fileRe, (m) {
          final raw = (m.group(1) ?? '').trim();
          final name = (m.group(2) ?? '').trim();
          final mime = (m.group(3) ?? '').trim();
          final fixed = SandboxPathResolver.fix(raw);
          if (fixed != raw) changed = true;
          return '[file:$fixed|$name|$mime]';
        });

        if (changed && updated != content) {
          final newMsg = msg.copyWith(content: updated);
          await _messagesBox.put(msg.id, newMsg);
        }
      }
    } catch (_) {
      // best-effort migration; ignore errors
    }
  }

  List<ChatMessage> _normalizeTurnIdentities(List<ChatMessage> messages) {
    final groups = <String, List<ChatMessage>>{};
    for (final message in messages) {
      final groupId = message.groupId ?? message.id;
      groups.putIfAbsent(groupId, () => <ChatMessage>[]).add(message);
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

  Future<void> _migrateTurnIdentities() async {
    if (_toolEventsBox.get(_turnIdentityMigrationKey) == true) return;

    for (final conversation in _conversationsBox.values) {
      final updates = <String, ChatMessage>{};
      final messages = conversation.messageIds
          .map(_messagesBox.get)
          .whereType<ChatMessage>()
          .toList(growable: false);
      final normalized = _normalizeTurnIdentities(messages);
      for (final message in normalized) {
        final stored = _messagesBox.get(message.id);
        if (stored != null && stored.turnId != message.turnId) {
          updates[message.id] = message;
        }
      }
      if (updates.isNotEmpty) {
        await _messagesBox.putAll(updates);
      }
    }
    await _toolEventsBox.put(_turnIdentityMigrationKey, true);
  }

  /// Reset stale isStreaming flags left over from a previous app crash or
  /// force-quit.  After a fresh launch no message can be actively streaming,
  /// so any persisted `isStreaming: true` is stale and must be cleared to
  /// avoid stuck loading indicators.
  ///
  /// Uses a tracked set of streaming message IDs for O(1) lookup instead of
  /// scanning every message in the box.
  Future<void> _resetStaleStreamingFlags() async {
    final raw = _toolEventsBox.get(_activeStreamingKey);
    if (raw == null) return;
    final ids = (raw as List).cast<String>();
    if (ids.isEmpty) return;
    final updates = <String, ChatMessage>{};
    final keys = <SyncEntityKey>{};
    for (final id in ids) {
      final message = _messagesBox.get(id);
      if (message == null || !message.isStreaming) continue;
      final interrupted = message.copyWith(
        isStreaming: false,
        generationStatus: ChatMessage.generationStatusInterrupted,
      );
      updates[id] = interrupted;
      keys.addAll(_messageGraphKeys(interrupted));
    }
    Future<void> write() async {
      if (updates.isNotEmpty) {
        await _messagesBox.putAll(updates);
        for (final message in updates.values) {
          _replaceCachedMessage(message);
        }
      }
      await _toolEventsBox.delete(_activeStreamingKey);
    }

    if (keys.isEmpty) {
      await write();
      return;
    }
    await _syncWriteExecutor.runLocalBatch<void>(keys: keys, write: write);
  }

  /// Record a message ID as actively streaming.
  Future<void> _trackStreamingId(String messageId) async {
    final raw = _toolEventsBox.get(_activeStreamingKey);
    final ids = raw != null
        ? (raw as List).cast<String>().toList()
        : <String>[];
    if (!ids.contains(messageId)) {
      ids.add(messageId);
      await _toolEventsBox.put(_activeStreamingKey, ids);
    }
  }

  /// Remove a message ID from the active streaming set.
  Future<void> _untrackStreamingId(String messageId) async {
    final raw = _toolEventsBox.get(_activeStreamingKey);
    if (raw == null) return;
    final ids = (raw as List).cast<String>().toList();
    if (ids.remove(messageId)) {
      if (ids.isEmpty) {
        await _toolEventsBox.delete(_activeStreamingKey);
      } else {
        await _toolEventsBox.put(_activeStreamingKey, ids);
      }
    }
  }

  Future<void> _cleanupOrphanUploads() {
    return UploadDirectoryCriticalSection.run(() async {
      try {
        final uploadDir = await AppDirectories.getUploadDirectory();
        if (!await uploadDir.exists()) return;

        // Build the set of all referenced paths across all messages
        String canon(String pth) {
          // Normalize separators and resolve redundant segments to enable
          // reliable equality checks across platforms (esp. Windows).
          final normalized = p.normalize(pth);
          // On Windows, paths are case-insensitive; compare in lowercase.
          return Platform.isWindows ? normalized.toLowerCase() : normalized;
        }

        final referenced = <String>{};
        for (final m in _messagesBox.values) {
          for (final pth in _extractAttachmentPaths(m.content)) {
            referenced.add(canon(pth));
          }
        }

        // Walk upload directory recursively to consider all files
        final entries = uploadDir.listSync(recursive: true, followLinks: false);
        for (final ent in entries) {
          if (ent is File) {
            final filePath = canon(ent.path);
            if (!referenced.contains(filePath)) {
              try {
                await ent.delete();
              } catch (_) {}
            }
          }
        }
      } catch (_) {}
    });
  }

  Future<void> restoreConversation(
    Conversation conversation,
    List<ChatMessage> messages,
  ) async {
    if (!_initialized) await init();
    final normalizedMessages = _normalizeTurnIdentities(messages);
    final keys = <SyncEntityKey>{_conversationKey(conversation.id)};
    for (final message in normalizedMessages) {
      keys
        ..add(_turnKey(message.turnId))
        ..add(_messageKey(message.id));
      if (message.role == 'assistant') {
        keys
          ..add(_toolEventKey(message.id))
          ..add(_thoughtSignatureKey(message.id));
      }
    }
    keys.addAll(conversation.versionSelections.keys.map(_messageSelectionKey));

    await _syncWriteExecutor.runLocalBatch<void>(
      keys: keys,
      write: () async {
        for (final message in normalizedMessages) {
          await _messagesBox.put(message.id, message);
        }
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
          versionSelections: Map<String, int>.from(
            conversation.versionSelections,
          ),
          summary: conversation.summary,
          lastSummarizedMessageCount: conversation.lastSummarizedMessageCount,
          chatSuggestions: List<String>.of(conversation.chatSuggestions),
        );
        await _conversationsBox.put(restored.id, restored);
        _messagesCache[restored.id] = List.of(normalizedMessages);
        _refreshConversationSyncIndexes(restored.id);
        notifyListeners();
      },
    );
  }

  Future<Conversation> upsertConversationFromSync(Conversation incoming) async {
    if (!_initialized) await init();
    _requireSyncIdentifier(incoming.id, 'conversationId');

    final wasCurrent = _currentConversationId == incoming.id;
    Conversation? draft;
    if (_temporaryConversationIds.contains(incoming.id)) {
      _discardTemporaryConversation(incoming.id);
    } else {
      draft = _draftConversations.remove(incoming.id);
    }
    if (wasCurrent) {
      _currentConversationId = incoming.id;
    }

    final existing = _conversationsBox.get(incoming.id);
    final localProjection = existing ?? draft;
    final synchronized = Conversation(
      id: incoming.id,
      title: incoming.title,
      createdAt: incoming.createdAt,
      updatedAt: incoming.updatedAt,
      // 云端会话没有消息顺序真相，本地索引只能保留并由消息、轮次重新计算。
      messageIds: List<String>.of(
        localProjection?.messageIds ?? const <String>[],
      ),
      isPinned: incoming.isPinned,
      mcpServerIds: List<String>.of(incoming.mcpServerIds),
      assistantId: incoming.assistantId,
      truncateIndex: incoming.truncateIndex,
      versionSelections: Map<String, int>.from(
        localProjection?.versionSelections ?? const <String, int>{},
      ),
      summary: incoming.summary,
      lastSummarizedMessageCount: incoming.lastSummarizedMessageCount,
      chatSuggestions: List<String>.of(incoming.chatSuggestions),
    );
    await _conversationsBox.put(synchronized.id, synchronized);
    await _rebuildSyncedMessageOrderOrDefer(synchronized.id);
    notifyListeners();
    return _conversationsBox.get(synchronized.id)!;
  }

  Future<ChatMessage> upsertMessageFromSync(ChatMessage incoming) async {
    if (!_initialized) await init();
    _validateSyncedMessage(incoming);

    final existing = _messagesBox.get(incoming.id);
    final previousConversationId = existing?.conversationId;
    if (existing != null &&
        existing.role == 'assistant' &&
        incoming.role != 'assistant') {
      await _toolEventsBox.delete(existing.id);
      await _toolEventsBox.delete(_sigKey(existing.id));
    }
    await _messagesBox.put(incoming.id, incoming);
    _messageConversationIds[incoming.id] = incoming.conversationId;
    _turnConversationIds[incoming.turnId] = incoming.conversationId;
    await _untrackStreamingId(incoming.id);

    if (previousConversationId != null &&
        previousConversationId != incoming.conversationId) {
      final previousConversation = _conversationsBox.get(
        previousConversationId,
      );
      if (previousConversation != null &&
          previousConversation.messageIds.remove(incoming.id)) {
        await previousConversation.save();
        await _rebuildSyncedMessageOrderOrDefer(previousConversationId);
      }
    }

    final conversation = await _ensureSyncedConversation(
      incoming.conversationId,
      incoming.timestamp,
    );
    if (!conversation.messageIds.contains(incoming.id)) {
      conversation.messageIds.add(incoming.id);
      await conversation.save();
    }
    await _rebuildSyncedMessageOrderOrDefer(incoming.conversationId);
    notifyListeners();
    return _messagesBox.get(incoming.id)!;
  }

  Future<void> applyTurnFromSync({
    required String conversationId,
    required String turnId,
    required DateTime createdAt,
  }) async {
    if (!_initialized) await init();
    _requireSyncIdentifier(conversationId, 'conversationId');
    _requireSyncIdentifier(turnId, 'turnId');

    await _ensureSyncedConversation(conversationId, createdAt);
    await _toolEventsBox.put(
      _syncTurnMetadataKey(conversationId, turnId),
      createdAt.toUtc().toIso8601String(),
    );
    await _rebuildSyncedMessageOrderOrDefer(conversationId);
    notifyListeners();
  }

  Future<void> upsertMessageSelectionFromSync({
    required String conversationId,
    required String groupId,
    required int selectedVersion,
  }) async {
    if (!_initialized) await init();
    _requireSyncIdentifier(conversationId, 'conversationId');
    _requireSyncIdentifier(groupId, 'groupId');
    if (selectedVersion < 0) {
      throw const FormatException('selectedVersion 不能为负数');
    }
    final conversation = _conversationsBox.get(conversationId);
    if (conversation == null) {
      throw FormatException('版本选择所属会话不存在：$conversationId');
    }
    if (conversation.versionSelections[groupId] == selectedVersion) return;
    conversation.versionSelections[groupId] = selectedVersion;
    await conversation.save();
    _selectionConversationIds[groupId] = conversationId;
    notifyListeners();
  }

  Future<void> upsertToolEventsFromSync({
    required String messageId,
    required List<Map<String, Object?>> events,
  }) async {
    if (!_initialized) await init();
    _requireSyncIdentifier(messageId, 'messageId');
    if (!_messagesBox.containsKey(messageId)) {
      throw FormatException('工具事件所属消息不存在：$messageId');
    }
    _temporaryToolEvents.remove(messageId);
    await _toolEventsBox.put(messageId, <Map<String, Object?>>[
      for (final event in events) Map<String, Object?>.from(event),
    ]);
    notifyListeners();
  }

  Future<void> upsertThoughtSignatureFromSync({
    required String messageId,
    required String signature,
  }) async {
    if (!_initialized) await init();
    _requireSyncIdentifier(messageId, 'messageId');
    if (signature.trim().isEmpty) {
      throw const FormatException('signature 不能为空');
    }
    if (!_messagesBox.containsKey(messageId)) {
      throw FormatException('思维签名所属消息不存在：$messageId');
    }
    _temporaryGeminiThoughtSigs.remove(messageId);
    await _toolEventsBox.put(_sigKey(messageId), signature);
    notifyListeners();
  }

  Future<void> deleteMessageSelectionFromSync(String groupId) async {
    if (!_initialized) await init();
    _requireSyncIdentifier(groupId, 'groupId');
    final conversationId = _selectionConversationIds[groupId];
    if (conversationId == null) return;
    final conversation = _conversationsBox.get(conversationId);
    if (conversation == null ||
        conversation.versionSelections.remove(groupId) == null) {
      _selectionConversationIds.remove(groupId);
      return;
    }
    await conversation.save();
    _selectionConversationIds.remove(groupId);
    notifyListeners();
  }

  Future<void> deleteToolEventsFromSync(String messageId) async {
    if (!_initialized) await init();
    _requireSyncIdentifier(messageId, 'messageId');
    final temporaryRemoved = _temporaryToolEvents.remove(messageId) != null;
    final persisted = _toolEventsBox.containsKey(messageId);
    if (persisted) {
      await _toolEventsBox.delete(messageId);
    }
    if (temporaryRemoved || persisted) notifyListeners();
  }

  Future<void> deleteThoughtSignatureFromSync(String messageId) async {
    if (!_initialized) await init();
    _requireSyncIdentifier(messageId, 'messageId');
    final temporaryRemoved =
        _temporaryGeminiThoughtSigs.remove(messageId) != null;
    final key = _sigKey(messageId);
    final persisted = _toolEventsBox.containsKey(key);
    if (persisted) {
      await _toolEventsBox.delete(key);
    }
    if (temporaryRemoved || persisted) notifyListeners();
  }

  Future<void> deleteTurnFromSync({
    required String conversationId,
    required String turnId,
  }) async {
    if (!_initialized) await init();
    _requireSyncIdentifier(conversationId, 'conversationId');
    _requireSyncIdentifier(turnId, 'turnId');

    final conversation = _conversationsBox.get(conversationId);
    if (conversation == null) {
      await _toolEventsBox.delete(_syncTurnMetadataKey(conversationId, turnId));
      return;
    }

    final deletedMessages = <ChatMessage>[];
    for (final messageId in conversation.messageIds) {
      final message = _messagesBox.get(messageId);
      if (message?.turnId == turnId) {
        deletedMessages.add(message!);
      }
    }
    final deletedIds = deletedMessages.map((message) => message.id).toSet();
    final deletedGroups = deletedMessages
        .map((message) => message.groupId ?? message.id)
        .toSet();

    if (deletedIds.isNotEmpty) {
      for (final message in deletedMessages) {
        await _untrackStreamingId(message.id);
        if (message.role == 'assistant') {
          await _toolEventsBox.delete(message.id);
          await _toolEventsBox.delete(_sigKey(message.id));
        }
      }
      await _messagesBox.deleteAll(deletedIds);
      conversation.messageIds.removeWhere(deletedIds.contains);

      final remainingGroups = conversation.messageIds
          .map(_messagesBox.get)
          .whereType<ChatMessage>()
          .map((message) => message.groupId ?? message.id)
          .toSet();
      for (final groupId in deletedGroups.difference(remainingGroups)) {
        conversation.versionSelections.remove(groupId);
      }
      await conversation.save();
    }

    await _toolEventsBox.delete(_syncTurnMetadataKey(conversationId, turnId));
    await _rebuildSyncedMessageOrderOrDefer(conversationId);
    if (deletedIds.isNotEmpty) {
      await _cleanupOrphanUploadsOrDefer();
    }
    notifyListeners();
  }

  Future<void> deleteMessageFromSync(String messageId) async {
    if (!_initialized) await init();
    final message = getMessageById(messageId);
    if (message == null) return;
    await _deleteMessageRaw(message, deferRemoteCleanup: true);
  }

  Future<void> deleteConversationFromSync(String conversationId) async {
    if (!_initialized) await init();
    await _deleteConversationRaw(conversationId, deferRemoteCleanup: true);
  }

  Future<Conversation> _ensureSyncedConversation(
    String conversationId,
    DateTime createdAt,
  ) async {
    final persisted = _conversationsBox.get(conversationId);
    if (persisted != null) return persisted;

    final wasCurrent = _currentConversationId == conversationId;
    if (_temporaryConversationIds.contains(conversationId)) {
      _discardTemporaryConversation(conversationId);
    }
    final draft = _draftConversations.remove(conversationId);
    if (wasCurrent) {
      _currentConversationId = conversationId;
    }
    if (draft != null) {
      await _conversationsBox.put(draft.id, draft);
      return draft;
    }

    final placeholder = Conversation(
      id: conversationId,
      title: _defaultConversationTitle,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    await _conversationsBox.put(placeholder.id, placeholder);
    return placeholder;
  }

  Future<void> _rebuildSyncedMessageOrder(String conversationId) async {
    final conversation = _conversationsBox.get(conversationId);
    if (conversation == null) return;

    final seen = <String>{};
    final messages = <ChatMessage>[];
    for (final messageId in conversation.messageIds) {
      final message = _messagesBox.get(messageId);
      if (message != null &&
          message.conversationId == conversationId &&
          seen.add(message.id)) {
        messages.add(message);
      }
    }

    final fallbackTurnTimes = <String, DateTime>{};
    final groupTimes = <(String, String), DateTime>{};
    for (final message in messages) {
      fallbackTurnTimes.update(
        message.turnId,
        (value) =>
            message.timestamp.isBefore(value) ? message.timestamp : value,
        ifAbsent: () => message.timestamp,
      );
      final groupKey = (message.turnId, message.groupId ?? message.id);
      groupTimes.update(
        groupKey,
        (value) =>
            message.timestamp.isBefore(value) ? message.timestamp : value,
        ifAbsent: () => message.timestamp,
      );
    }
    final turnTimes = <String, DateTime>{};
    for (final entry in fallbackTurnTimes.entries) {
      turnTimes[entry.key] =
          _syncedTurnCreatedAt(conversationId, entry.key) ?? entry.value;
    }

    messages.sort((left, right) {
      var compared = turnTimes[left.turnId]!.compareTo(
        turnTimes[right.turnId]!,
      );
      if (compared != 0) return compared;
      compared = left.turnId.compareTo(right.turnId);
      if (compared != 0) return compared;

      final leftGroup = left.groupId ?? left.id;
      final rightGroup = right.groupId ?? right.id;
      compared = groupTimes[(left.turnId, leftGroup)]!.compareTo(
        groupTimes[(right.turnId, rightGroup)]!,
      );
      if (compared != 0) return compared;
      compared = _syncedRoleRank(
        left.role,
      ).compareTo(_syncedRoleRank(right.role));
      if (compared != 0) return compared;
      compared = leftGroup.compareTo(rightGroup);
      if (compared != 0) return compared;
      compared = left.version.compareTo(right.version);
      if (compared != 0) return compared;
      compared = left.timestamp.compareTo(right.timestamp);
      return compared != 0 ? compared : left.id.compareTo(right.id);
    });

    final orderedIds = messages.map((message) => message.id).toList();
    if (!listEquals(conversation.messageIds, orderedIds)) {
      conversation.messageIds
        ..clear()
        ..addAll(orderedIds);
      await conversation.save();
    }
    _messagesCache[conversationId] = messages;
    _refreshConversationSyncIndexes(conversationId);
  }

  String _syncTurnMetadataKey(String conversationId, String turnId) {
    return '$_syncTurnMetadataPrefix:${Uri.encodeComponent(conversationId)}:'
        '${Uri.encodeComponent(turnId)}';
  }

  DateTime? _syncedTurnCreatedAt(String conversationId, String turnId) {
    final raw = _toolEventsBox.get(
      _syncTurnMetadataKey(conversationId, turnId),
    );
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  int _syncedRoleRank(String role) => role == 'user' ? 0 : 1;

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

  // Add a message directly to an existing conversation (for merge mode)
  Future<void> addMessageDirectly(
    String conversationId,
    ChatMessage message,
  ) async {
    if (!_initialized) await init();
    if (message.conversationId != conversationId) {
      throw ArgumentError.value(
        message.conversationId,
        'message.conversationId',
        '消息与目标会话不一致',
      );
    }
    final keys = <SyncEntityKey>{
      _conversationKey(conversationId),
      _turnKey(message.turnId),
      _messageKey(message.id),
      if (message.role == 'assistant') _toolEventKey(message.id),
      if (message.role == 'assistant') _thoughtSignatureKey(message.id),
    };
    await _syncWriteExecutor.runLocalBatch<void>(
      keys: keys,
      write: () => _addMessageDirectlyRaw(conversationId, message),
    );
  }

  Future<void> _addMessageDirectlyRaw(
    String conversationId,
    ChatMessage message,
  ) async {
    final conversation = _conversationsBox.get(conversationId);
    if (conversation == null) {
      throw ArgumentError.value(conversationId, 'conversationId', '目标会话不存在');
    }
    // Add message to box
    await _messagesBox.put(message.id, message);

    // Update conversation
    if (!conversation.messageIds.contains(message.id)) {
      conversation.messageIds.add(message.id);
      // 恢复时保留原始更新时间。
      await conversation.save();
    }

    // Update cache
    if (_messagesCache.containsKey(conversationId)) {
      if (!_messagesCache[conversationId]!.any((m) => m.id == message.id)) {
        _messagesCache[conversationId]!.add(message);
      }
    }

    _refreshConversationSyncIndexes(conversationId);
    notifyListeners();
  }

  // Conversation-scoped MCP servers selection
  List<String> getConversationMcpServers(String conversationId) {
    if (!_initialized) return const <String>[];
    final c =
        _conversationsBox.get(conversationId) ??
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
    final c = _conversationsBox.get(conversationId);
    if (c == null) return;
    await _syncWriteExecutor.runLocal<void>(
      key: _conversationKey(conversationId),
      write: () async {
        c.mcpServerIds = List.of(serverIds);
        c.updatedAt = DateTime.now();
        await c.save();
        notifyListeners();
      },
    );
  }

  Future<void> toggleConversationMcpServer(
    String conversationId,
    String serverId,
    bool enabled,
  ) async {
    final current = getConversationMcpServers(conversationId);
    final set = current.toSet();
    if (enabled) {
      set.add(serverId);
    } else {
      set.remove(serverId);
    }
    await setConversationMcpServers(conversationId, set.toList());
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
    final conversation = _conversationsBox.get(id);
    if (conversation == null) return;

    await _syncWriteExecutor.runLocal<void>(
      key: _conversationKey(id),
      write: () async {
        conversation.title = newTitle;
        conversation.updatedAt = DateTime.now();
        await conversation.save();
        notifyListeners();
      },
    );
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

    final conversation = _conversationsBox.get(id);
    if (conversation == null) return;

    await _syncWriteExecutor.runLocal<void>(
      key: _conversationKey(id),
      write: () async {
        conversation.summary = summary;
        conversation.lastSummarizedMessageCount = messageCount;
        await conversation.save();
        notifyListeners();
      },
    );
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

    final conversation = _conversationsBox.get(conversationId);
    if (conversation == null) return;

    await _syncWriteExecutor.runLocal<void>(
      key: _conversationKey(conversationId),
      write: () async {
        conversation.summary = null;
        conversation.lastSummarizedMessageCount = 0;
        await conversation.save();
        notifyListeners();
      },
    );
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

    final conversation = _conversationsBox.get(conversationId);
    if (conversation == null) return;

    await _syncWriteExecutor.runLocal<void>(
      key: _conversationKey(conversationId),
      write: () async {
        conversation.chatSuggestions = clean;
        await conversation.save();
        notifyListeners();
      },
    );
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

    final conversation = _conversationsBox.get(conversationId);
    if (conversation == null || conversation.chatSuggestions.isEmpty) return;

    await _syncWriteExecutor.runLocal<void>(
      key: _conversationKey(conversationId),
      write: () async {
        conversation.chatSuggestions = <String>[];
        await conversation.save();
        notifyListeners();
      },
    );
  }

  Future<void> togglePinConversation(String id) async {
    if (!_initialized) return;

    if (_draftConversations.containsKey(id)) {
      final draft = _draftConversations[id]!;
      draft.isPinned = !draft.isPinned;
      notifyListeners();
      return;
    }
    final conversation = _conversationsBox.get(id);
    if (conversation == null) return;

    await _syncWriteExecutor.runLocal<void>(
      key: _conversationKey(id),
      write: () async {
        conversation.isPinned = !conversation.isPinned;
        await conversation.save();
        notifyListeners();
      },
    );
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
  }) async {
    if (!_initialized) await init();

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
    final temporary = _temporaryConversationIds.contains(conversationId);
    if (temporary || !_isTerminalMessage(message)) {
      return _addMessageRaw(message, temporary: temporary);
    }
    final keys = message.role == 'assistant'
        ? _messageGraphKeys(message)
        : <SyncEntityKey>{
            _conversationKey(conversationId),
            _turnKey(message.turnId),
            _messageKey(message.id),
          };
    return _syncWriteExecutor.runLocalBatch<ChatMessage>(
      keys: keys,
      write: () => _addMessageRaw(message, temporary: false),
    );
  }

  Future<ChatMessage> _addMessageRaw(
    ChatMessage message, {
    required bool temporary,
  }) async {
    final conversationId = message.conversationId;
    var conversation = _conversationsBox.get(conversationId);
    // If conversation doesn't exist yet, persist draft (if any)
    if (conversation == null) {
      final draft = temporary
          ? _draftConversations[conversationId]
          : _draftConversations.remove(conversationId);
      if (draft != null) {
        if (!temporary) {
          await _conversationsBox.put(draft.id, draft);
        }
        conversation = draft;
      } else {
        // Create a new one on the fly as a fallback
        conversation = Conversation(
          id: conversationId,
          title: _defaultConversationTitle,
        );
        if (!temporary) {
          await _conversationsBox.put(conversationId, conversation);
        } else {
          _draftConversations[conversationId] = conversation;
        }
      }
    }

    if (!temporary) {
      await _messagesBox.put(message.id, message);
    }

    // Track streaming state for crash-recovery cleanup
    if (message.isStreaming && !temporary) {
      await _trackStreamingId(message.id);
    }

    conversation.messageIds.add(message.id);
    conversation.updatedAt = DateTime.now();
    if (temporary) {
      _messagesCache.putIfAbsent(conversationId, () => <ChatMessage>[]);
    } else {
      await conversation.save();
    }

    // Update cache
    if (_messagesCache.containsKey(conversationId)) {
      _messagesCache[conversationId]!.add(message);
    }

    if (!temporary) {
      _messageConversationIds[message.id] = conversationId;
      _turnConversationIds[message.turnId] = conversationId;
    }

    notifyListeners();
    return message;
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
  }) {
    return _updateMessage(
      messageId,
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
      notify: true,
    );
  }

  /// Update message content during streaming without triggering notifyListeners.
  /// This is used for streaming updates to avoid unnecessary rebuilds of
  /// widgets watching ChatService (e.g., side_drawer).
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
  }) {
    return _updateMessage(
      messageId,
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
      notify: false,
    );
  }

  Future<void> _updateMessage(
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
    required bool notify,
  }) async {
    if (!_initialized) return;

    final message =
        _messagesBox.get(messageId) ?? _cachedTemporaryMessage(messageId);
    if (message == null) return;

    final updatedMessage = message.copyWith(
      content: content ?? message.content,
      totalTokens: totalTokens ?? message.totalTokens,
      isStreaming: isStreaming ?? message.isStreaming,
      reasoningText: reasoningText ?? message.reasoningText,
      reasoningStartAt: reasoningStartAt ?? message.reasoningStartAt,
      reasoningFinishedAt: reasoningFinishedAt ?? message.reasoningFinishedAt,
      translation: translation,
      reasoningSegmentsJson:
          reasoningSegmentsJson ?? message.reasoningSegmentsJson,
      promptTokens: promptTokens ?? message.promptTokens,
      completionTokens: completionTokens ?? message.completionTokens,
      cachedTokens: cachedTokens ?? message.cachedTokens,
      durationMs: durationMs ?? message.durationMs,
      generationStatus: generationStatus,
    );

    if (isTemporaryConversation(message.conversationId)) {
      _replaceCachedMessage(updatedMessage);
      if (notify) notifyListeners();
      return;
    }

    Future<void> write() async {
      await _messagesBox.put(messageId, updatedMessage);

      if (isStreaming == false) {
        await _untrackStreamingId(messageId);
      }

      final messages = _messagesCache[message.conversationId];
      if (messages != null) {
        final index = messages.indexWhere(
          (candidate) => candidate.id == messageId,
        );
        if (index != -1) messages[index] = updatedMessage;
      }
      if (notify) notifyListeners();
    }

    final wasTerminal = _isTerminalMessage(message);
    final isTerminal = _isTerminalMessage(updatedMessage);
    if (!isTerminal) {
      await write();
      return;
    }
    if (message.role == 'assistant' && !wasTerminal) {
      await _syncWriteExecutor.runLocalBatch<void>(
        keys: _messageGraphKeys(updatedMessage),
        write: write,
      );
      return;
    }
    await _syncWriteExecutor.runLocal<void>(
      key: _messageKey(messageId),
      write: write,
    );
  }

  // Tool events persistence (per assistant message)
  List<Map<String, dynamic>> getToolEvents(String assistantMessageId) {
    if (!_initialized) return const <Map<String, dynamic>>[];
    final temporary = _temporaryToolEvents[assistantMessageId];
    if (temporary != null) return List<Map<String, dynamic>>.of(temporary);
    final v = _toolEventsBox.get(assistantMessageId);
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  bool hasToolEvents(String assistantMessageId) {
    if (!_initialized) return false;
    return _temporaryToolEvents.containsKey(assistantMessageId) ||
        _toolEventsBox.containsKey(assistantMessageId);
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
    final message = getMessageById(assistantMessageId);
    if (message == null) {
      throw ArgumentError.value(
        assistantMessageId,
        'assistantMessageId',
        '工具事件所属消息不存在',
      );
    }
    Future<void> write() async {
      await _toolEventsBox.put(assistantMessageId, events);
      notifyListeners();
    }

    if (!_isTerminalMessage(message)) {
      await write();
      return;
    }
    await _syncWriteExecutor.runLocal<void>(
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
    final list = List<Map<String, dynamic>>.of(
      getToolEvents(assistantMessageId),
    );
    final cleanId = (id).toString();

    int idx = -1;
    // Prefer matching by a non-empty id
    if (cleanId.isNotEmpty) {
      idx = list.indexWhere((e) => (e['id']?.toString() ?? '') == cleanId);
    }
    // If no id or not found, match the first placeholder (no content) with same name
    if (idx < 0) {
      idx = list.indexWhere(
        (e) =>
            (e['name']?.toString() ?? '') == name &&
            (e['content'] == null ||
                (e['content']?.toString().isEmpty ?? true)),
      );
    }

    final record = <String, dynamic>{
      'id': cleanId,
      'name': name,
      'arguments': arguments,
      'content': content,
    };
    final existingMetadata = idx >= 0 ? list[idx]['metadata'] : null;
    if (metadata != null && metadata.isNotEmpty) {
      record['metadata'] = metadata;
    } else if (existingMetadata is Map && existingMetadata.isNotEmpty) {
      record['metadata'] = existingMetadata.cast<String, dynamic>();
    }
    if (idx >= 0) {
      list[idx] = record;
    } else {
      list.add(record);
    }
    if (_isTemporaryMessageId(assistantMessageId)) {
      _temporaryToolEvents[assistantMessageId] = list;
      notifyListeners();
      return;
    }
    final message = getMessageById(assistantMessageId);
    if (message == null) {
      throw ArgumentError.value(
        assistantMessageId,
        'assistantMessageId',
        '工具事件所属消息不存在',
      );
    }
    Future<void> write() async {
      await _toolEventsBox.put(assistantMessageId, list);
      notifyListeners();
    }

    if (!_isTerminalMessage(message)) {
      await write();
      return;
    }
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
    final v = _toolEventsBox.get(_sigKey(assistantMessageId));
    if (v is String && v.trim().isNotEmpty) return v;
    return null;
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
    final message = getMessageById(assistantMessageId);
    if (message == null) {
      throw ArgumentError.value(
        assistantMessageId,
        'assistantMessageId',
        '思维签名所属消息不存在',
      );
    }
    Future<void> write() async {
      await _toolEventsBox.put(_sigKey(assistantMessageId), signature);
      notifyListeners();
    }

    if (!_isTerminalMessage(message)) {
      await write();
      return;
    }
    await _syncWriteExecutor.runLocal<void>(
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
    final message = getMessageById(assistantMessageId);
    if (message == null) return;
    Future<void> write() => _toolEventsBox.delete(_sigKey(assistantMessageId));
    if (!_isTerminalMessage(message)) {
      await write();
      return;
    }
    await _syncWriteExecutor.runLocal<void>(
      key: _thoughtSignatureKey(assistantMessageId),
      write: write,
    );
  }

  Future<Conversation> forkConversation({
    required String title,
    required String? assistantId,
    required List<ChatMessage> sourceMessages,
  }) async {
    if (!_initialized) await init();
    final convo = Conversation(title: title, assistantId: assistantId);
    final clones = <ChatMessage>[];
    for (final src in sourceMessages) {
      final clone = ChatMessage(
        role: src.role,
        content: src.content,
        timestamp: src.timestamp,
        modelId: src.modelId,
        providerId: src.providerId,
        totalTokens: src.totalTokens,
        conversationId: convo.id,
        isStreaming: false,
        reasoningText: src.reasoningText,
        reasoningStartAt: src.reasoningStartAt,
        reasoningFinishedAt: src.reasoningFinishedAt,
        translation: src.translation,
        reasoningSegmentsJson: src.reasoningSegmentsJson,
        generationStatus: src.isStreaming
            ? ChatMessage.generationStatusInterrupted
            : src.generationStatus,
      );
      clones.add(clone);
    }
    final normalizedClones = _normalizeTurnIdentities(clones);
    final keys = <SyncEntityKey>{_conversationKey(convo.id)};
    for (final clone in normalizedClones) {
      keys
        ..add(_turnKey(clone.turnId))
        ..add(_messageKey(clone.id));
      if (clone.role == 'assistant') {
        keys
          ..add(_toolEventKey(clone.id))
          ..add(_thoughtSignatureKey(clone.id));
      }
    }
    return _syncWriteExecutor.runLocalBatch<Conversation>(
      keys: keys,
      write: () async {
        _discardTemporaryConversation(_currentConversationId);
        await _conversationsBox.put(convo.id, convo);
        _currentConversationId = convo.id;
        final ids = <String>[];
        for (final clone in normalizedClones) {
          await _messagesBox.put(clone.id, clone);
          ids.add(clone.id);
        }
        convo.messageIds
          ..clear()
          ..addAll(ids);
        convo.versionSelections = <String, int>{};
        convo.updatedAt = DateTime.now();
        await convo.save();
        _messagesCache[convo.id] = List<ChatMessage>.of(normalizedClones);
        _refreshConversationSyncIndexes(convo.id);
        notifyListeners();
        return _conversationsBox.get(convo.id)!;
      },
    );
  }

  Future<ChatMessage?> appendMessageVersion({
    required String messageId,
    required String content,
  }) async {
    if (!_initialized) await init();
    final original = _messagesBox.get(messageId);
    if (original == null) return null;

    final cid = original.conversationId;
    final convo = _conversationsBox.get(cid) ?? _draftConversations[cid];
    if (convo == null) return null;

    final gid = (original.groupId ?? original.id);
    // Find current max version within this group in this conversation
    int maxVersion = -1;
    for (final mid in convo.messageIds) {
      final m = _messagesBox.get(mid);
      if (m == null) continue;
      final mg = (m.groupId ?? m.id);
      if (mg == gid) {
        if (m.version > maxVersion) maxVersion = m.version;
      }
    }
    final nextVersion = maxVersion + 1;

    final newMsg = ChatMessage(
      role: original.role,
      content: content,
      conversationId: cid,
      modelId: original.modelId,
      providerId: original.providerId,
      totalTokens: null,
      isStreaming: false,
      groupId: gid,
      version: nextVersion,
      turnId: original.turnId,
      generationStatus: ChatMessage.generationStatusCompleted,
    );
    final keys = <SyncEntityKey>{
      _conversationKey(cid),
      _turnKey(newMsg.turnId),
      _messageKey(newMsg.id),
      _messageSelectionKey(gid),
      if (newMsg.role == 'assistant') _toolEventKey(newMsg.id),
      if (newMsg.role == 'assistant') _thoughtSignatureKey(newMsg.id),
    };
    return _syncWriteExecutor.runLocalBatch<ChatMessage>(
      keys: keys,
      write: () async {
        await _messagesBox.put(newMsg.id, newMsg);
        if (_draftConversations.containsKey(cid)) {
          final draft = _draftConversations[cid]!;
          draft.messageIds.add(newMsg.id);
          draft.updatedAt = DateTime.now();
          draft.versionSelections[gid] = nextVersion;
        } else {
          final c = _conversationsBox.get(cid);
          if (c != null) {
            c.messageIds.add(newMsg.id);
            c.updatedAt = DateTime.now();
            c.versionSelections[gid] = nextVersion;
            await c.save();
          }
        }
        final arr = _messagesCache[cid];
        if (arr != null) arr.add(newMsg);
        _refreshConversationSyncIndexes(cid);
        notifyListeners();
        return newMsg;
      },
    );
  }

  Map<String, int> getVersionSelections(String conversationId) {
    final c =
        _conversationsBox.get(conversationId) ??
        _draftConversations[conversationId];
    return Map<String, int>.from(c?.versionSelections ?? const <String, int>{});
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
    final c = _conversationsBox.get(conversationId);
    if (c == null) return;
    await _syncWriteExecutor.runLocalBatch<void>(
      keys: <SyncEntityKey>{
        _conversationKey(conversationId),
        _messageSelectionKey(groupId),
      },
      write: () async {
        c.versionSelections[groupId] = version;
        c.updatedAt = DateTime.now();
        await c.save();
        _selectionConversationIds[groupId] = conversationId;
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
    final c = _conversationsBox.get(conversationId);
    if (c == null) return;
    await _syncWriteExecutor.runLocalBatch<void>(
      keys: <SyncEntityKey>{
        _conversationKey(conversationId),
        _messageSelectionKey(groupId),
      },
      write: () async {
        c.versionSelections.remove(groupId);
        c.updatedAt = DateTime.now();
        await c.save();
        _selectionConversationIds.remove(groupId);
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
    // Persisted case
    final c = _conversationsBox.get(conversationId);
    if (c == null) return null;
    return _syncWriteExecutor.runLocal<Conversation>(
      key: _conversationKey(conversationId),
      write: () async {
        final lastIndexPlusOne = c.messageIds.length;
        final newValue = (c.truncateIndex == lastIndexPlusOne)
            ? -1
            : lastIndexPlusOne;
        c.truncateIndex = newValue;
        if ((defaultTitle ?? '').isNotEmpty) c.title = defaultTitle!;
        c.updatedAt = DateTime.now();
        await c.save();
        notifyListeners();
        return c;
      },
    );
  }

  Future<void> deleteMessage(String messageId) async {
    if (!_initialized) return;

    final message =
        _messagesBox.get(messageId) ?? _cachedTemporaryMessage(messageId);
    if (message == null) return;
    if (isTemporaryConversation(message.conversationId)) {
      await _deleteMessageRaw(message);
      return;
    }
    final groupId = message.groupId ?? message.id;
    await _syncWriteExecutor.runLocalBatch<void>(
      keys: <SyncEntityKey>{
        _messageKey(message.id),
        _turnKey(message.turnId),
        _messageSelectionKey(groupId),
        _toolEventKey(message.id),
        _thoughtSignatureKey(message.id),
      },
      write: () => _deleteMessageRaw(message),
    );
  }

  Future<void> _deleteMessageRaw(
    ChatMessage message, {
    bool deferRemoteCleanup = false,
    bool skipCleanup = false,
  }) async {
    if (isTemporaryConversation(message.conversationId)) {
      final conversation = _draftConversations[message.conversationId];
      conversation?.messageIds.remove(message.id);
      final messages = _messagesCache[message.conversationId];
      messages?.removeWhere((m) => m.id == message.id);
      final groupId = message.groupId ?? message.id;
      if (messages == null ||
          !messages.any((m) => (m.groupId ?? m.id) == groupId)) {
        conversation?.versionSelections.remove(groupId);
      }
      _temporaryToolEvents.remove(message.id);
      _temporaryGeminiThoughtSigs.remove(message.id);
      notifyListeners();
      return;
    }

    final conversation = _conversationsBox.get(message.conversationId);
    if (conversation != null) {
      final gid = message.groupId ?? message.id;
      final ids = conversation.messageIds;

      // Find the earliest position of this message group before removal so we
      // can keep the group anchored when deleting one of its versions.
      int anchorIndex = -1;
      for (int i = 0; i < ids.length; i++) {
        final mid = ids[i];
        final m = _messagesBox.get(mid);
        if (m == null) continue;
        final mgid = m.groupId ?? m.id;
        if (mgid == gid) {
          anchorIndex = i;
          break;
        }
      }

      ids.remove(message.id);

      // If we removed the earliest version but other versions remain, move the
      // earliest remaining one back to the original anchor index to preserve
      // the group's relative order in the conversation.
      if (anchorIndex >= 0) {
        int? earliestRemaining;
        for (int i = 0; i < ids.length; i++) {
          final mid = ids[i];
          final m = _messagesBox.get(mid);
          if (m == null) continue;
          final mgid = m.groupId ?? m.id;
          if (mgid == gid) {
            earliestRemaining = i;
            break;
          }
        }

        if (earliestRemaining != null && earliestRemaining > anchorIndex) {
          final replacementId = ids.removeAt(earliestRemaining);
          final insertAt = anchorIndex <= ids.length ? anchorIndex : ids.length;
          ids.insert(insertAt, replacementId);
        }
      }

      final groupStillExists = ids.map(_messagesBox.get).any((candidate) {
        return candidate != null && (candidate.groupId ?? candidate.id) == gid;
      });
      if (!groupStillExists) {
        conversation.versionSelections.remove(gid);
      }

      await conversation.save();
    }

    await _messagesBox.delete(message.id);
    // Remove any tool events linked to this assistant message
    if (message.role == 'assistant') {
      await _toolEventsBox.delete(message.id);
      await _toolEventsBox.delete(_sigKey(message.id));
    }

    // Update cache: clear this conversation so that next getMessages()
    // reloads messages in the updated order from conversation.messageIds.
    _messagesCache.remove(message.conversationId);
    if (deferRemoteCleanup && _remoteBatchDepth > 0) {
      // 远端批次统一重建索引，避免每条删除都遍历同一会话。
      _remoteRebuildConversationIds.add(message.conversationId);
    } else {
      _refreshConversationSyncIndexes(message.conversationId);
    }

    // Clean up orphaned upload files that are no longer referenced by any message
    if (!skipCleanup) {
      if (deferRemoteCleanup) {
        await _cleanupOrphanUploadsOrDefer();
      } else {
        await _cleanupOrphanUploads();
      }
    }

    notifyListeners();
  }

  Future<void> deleteMessagesWithSelections({
    required String conversationId,
    required Iterable<String> messageIds,
    required Map<String, int?> versionSelections,
  }) async {
    if (!_initialized) return;
    final temporary = isTemporaryConversation(conversationId);
    final messages = messageIds
        .toSet()
        .map(getMessageById)
        .whereType<ChatMessage>()
        .where((message) => message.conversationId == conversationId)
        .toList(growable: false);
    if (messages.isEmpty && versionSelections.isEmpty) return;

    final keys = <SyncEntityKey>{
      for (final groupId in versionSelections.keys)
        _messageSelectionKey(groupId),
    };
    for (final message in messages) {
      keys
        ..add(_messageKey(message.id))
        ..add(_turnKey(message.turnId))
        ..add(_messageSelectionKey(message.groupId ?? message.id))
        ..add(_toolEventKey(message.id))
        ..add(_thoughtSignatureKey(message.id));
    }

    Future<void> write() => runNotificationBatch<void>(() async {
      final conversation = temporary
          ? _draftConversations[conversationId]
          : _conversationsBox.get(conversationId);
      if (conversation != null && versionSelections.isNotEmpty) {
        for (final entry in versionSelections.entries) {
          final version = entry.value;
          if (version == null) {
            conversation.versionSelections.remove(entry.key);
          } else {
            conversation.versionSelections[entry.key] = version;
          }
        }
        if (!temporary) {
          await conversation.save();
          _refreshConversationSyncIndexes(conversationId);
        }
        notifyListeners();
      }
      for (final message in messages) {
        await _deleteMessageRaw(message, skipCleanup: true);
      }
      if (!temporary && messages.isNotEmpty) await _cleanupOrphanUploads();
    });

    if (temporary || keys.isEmpty) {
      await write();
      return;
    }
    await _syncWriteExecutor.runLocalBatch<void>(keys: keys, write: write);
  }

  void setCurrentConversation(String? id) {
    if (id != _currentConversationId) {
      _discardTemporaryConversation(_currentConversationId);
    }
    _currentConversationId = id;
    notifyListeners();
  }

  Future<void> clearAllData({bool preserveUploads = false}) {
    if (!_initialized) return Future<void>.value();
    final keys = _allActiveSyncKeys();
    Future<void> write() => UploadDirectoryCriticalSection.run(() async {
      await _messagesBox.clear();
      await _conversationsBox.clear();
      await _toolEventsBox.clear();
      _messagesCache.clear();
      _draftConversations.clear();
      _temporaryConversationIds.clear();
      _temporaryToolEvents.clear();
      _temporaryGeminiThoughtSigs.clear();
      _messageConversationIds.clear();
      _turnConversationIds.clear();
      _selectionConversationIds.clear();
      _currentConversationId = null;
      if (!preserveUploads) {
        final uploadDir = await AppDirectories.getUploadDirectory();
        if (await uploadDir.exists()) {
          await uploadDir.delete(recursive: true);
        }
      }
      notifyListeners();
    });
    if (keys.isEmpty) return write();
    return _syncWriteExecutor.runLocalBatch<void>(keys: keys, write: write);
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

    final c = _conversationsBox.get(conversationId);
    if (c == null) return;
    await _syncWriteExecutor.runLocal<void>(
      key: _conversationKey(conversationId),
      write: () async {
        c.assistantId = assistantId;
        c.updatedAt = DateTime.now();
        await c.save();
        notifyListeners();
      },
    );
  }
}

class UploadStats {
  final int fileCount;
  final int totalBytes;
  const UploadStats({required this.fileCount, required this.totalBytes});
}
