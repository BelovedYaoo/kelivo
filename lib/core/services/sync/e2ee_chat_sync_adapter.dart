import 'dart:async';

import '../../database/chat_database_repository.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import 'e2ee_account_record_state.dart';
import 'e2ee_sync_outbox.dart';
import 'e2ee_sync_payload_codec.dart';
import 'e2ee_sync_pull_types.dart';
import 'sync_codec.dart';

typedef E2eeChatSyncPullBatchRunner =
    Future<T> Function<T>({
      required Future<T> Function() pull,
      required bool Function() shouldRefresh,
      required bool Function() mayHaveOrphanedAssets,
    });

/// 六类聊天实体与 E2EE 完整状态 payload 之间的唯一映射边界。
final class E2eeChatSyncAdapter {
  factory E2eeChatSyncAdapter({
    required ChatDatabaseRepository repository,
    required E2eeChatSyncPullBatchRunner runPullBatch,
  }) => E2eeChatSyncAdapter._(repository, runPullBatch);

  E2eeChatSyncAdapter._(this._repository, this._runPullBatch);

  final ChatDatabaseRepository _repository;
  final E2eeChatSyncPullBatchRunner _runPullBatch;
  Future<void> _pullTail = Future<void>.value();
  _PullApplyContext? _activePull;
  bool _publishPending = false;
  bool _pendingMayHaveOrphanedAssets = false;

  Future<E2eeSyncEntitySnapshot> readSnapshot(SyncEntityKey entityKey) async {
    E2eeSyncPayloadCodec.validateEntityKey(entityKey);
    return switch (entityKey.entityType) {
      E2eeSyncChatRecordTypes.conversation => _readConversation(entityKey),
      E2eeSyncChatRecordTypes.turn => _readTurn(entityKey),
      E2eeSyncChatRecordTypes.message => _readMessage(entityKey),
      E2eeSyncChatRecordTypes.messageSelection => _readMessageSelection(
        entityKey,
      ),
      E2eeSyncChatRecordTypes.toolEvent => _readToolEvent(entityKey),
      E2eeSyncChatRecordTypes.thoughtSignature => _readThoughtSignature(
        entityKey,
      ),
      _ => throw StateError('sync_chat_entity_type_unreachable'),
    };
  }

  /// 只能作为 pull coordinator 的最外层入口使用；回调返回即代表 checkpoint 已提交。
  Future<T> runPullAndPublish<T>(Future<T> Function() pull) {
    final previous = _pullTail;
    final completion = Completer<void>();
    _pullTail = completion.future;
    return () async {
      await previous;
      final context = _PullApplyContext();
      if (_activePull != null) throw StateError('sync_pull_batch_reentered');
      _activePull = context;
      try {
        final result = await _runPullBatch<T>(
          pull: () async {
            final committed = await pull();
            if (context.appliedChanges) {
              _publishPending = true;
              _pendingMayHaveOrphanedAssets |= context.mayHaveOrphanedAssets;
            }
            return committed;
          },
          shouldRefresh: () => _publishPending,
          mayHaveOrphanedAssets: () => _pendingMayHaveOrphanedAssets,
        );
        _publishPending = false;
        _pendingMayHaveOrphanedAssets = false;
        return result;
      } finally {
        _activePull = null;
        completion.complete();
      }
    }();
  }

  /// 此回调由 E2eeSyncPullCommands 放入 ledger、业务表和 checkpoint 的同一事务。
  Future<void> applyTransactional(
    List<E2eeSyncPulledChange> applicableChanges,
  ) async {
    final context = _activePull;
    if (context == null) {
      throw StateError('sync_apply_requires_pull_batch');
    }
    if (applicableChanges.isEmpty) return;

    final ordered = <_IndexedPulledChange>[
      for (var index = 0; index < applicableChanges.length; index++)
        _IndexedPulledChange(index: index, change: applicableChanges[index]),
    ];
    for (final entry in ordered) {
      _validateChange(entry.change);
    }
    ordered.sort(_compareChanges);

    final rebuildConversationIds = <String>{};
    var mayHaveOrphanedAssets = false;
    for (final entry in ordered) {
      final change = entry.change;
      switch (change) {
        case E2eeSyncPulledValueChange():
          await _applyValue(change, rebuildConversationIds);
        case E2eeSyncPulledTombstoneChange():
          mayHaveOrphanedAssets |= await _applyTombstone(
            change,
            rebuildConversationIds,
          );
      }
    }
    final sortedConversationIds = rebuildConversationIds.toList()..sort();
    for (final conversationId in sortedConversationIds) {
      await _repository.rebuildSyncedMessageOrder(conversationId);
    }
    context
      ..appliedChanges = true
      ..mayHaveOrphanedAssets |= mayHaveOrphanedAssets;
  }

  Future<E2eeSyncEntitySnapshot> _readConversation(
    SyncEntityKey entityKey,
  ) async {
    final conversation = await _repository.getConversation(
      entityKey.entityId,
      includeMessageIds: false,
    );
    if (conversation == null) return const E2eeSyncTombstoneSnapshot();
    return _encodeValue(entityKey, <String, Object?>{
      'title': conversation.title,
      'createdAt': _canonicalUtc(conversation.createdAt),
      'updatedAt': _canonicalUtc(conversation.updatedAt),
      'isPinned': conversation.isPinned,
      'assistantId': conversation.assistantId,
      'mcpServerIds': <Object?>[...conversation.mcpServerIds],
      'truncateIndex': conversation.truncateIndex,
      'summary': conversation.summary,
      'lastSummarizedMessageCount': conversation.lastSummarizedMessageCount,
      'chatSuggestions': <Object?>[...conversation.chatSuggestions],
    });
  }

  Future<E2eeSyncEntitySnapshot> _readTurn(SyncEntityKey entityKey) async {
    final turn = await _repository.getTurnForSync(entityKey.entityId);
    if (turn == null) return const E2eeSyncTombstoneSnapshot();
    return _encodeValue(entityKey, <String, Object?>{
      'conversationId': turn.conversationId,
      'createdAt': _canonicalUtc(turn.createdAt),
    });
  }

  Future<E2eeSyncEntitySnapshot> _readMessage(SyncEntityKey entityKey) async {
    final message = await _repository.getMessage(entityKey.entityId);
    if (message == null) return const E2eeSyncTombstoneSnapshot();
    _requireTerminalMessage(message);
    if (_containsLocalAttachmentMarker(message.content) ||
        await _repository.hasMessageAssetReferences(message.id)) {
      throw StateError('sync_message_attachments_not_supported');
    }
    return _encodeValue(entityKey, <String, Object?>{
      'conversationId': message.conversationId,
      'turnId': message.turnId,
      'role': message.role,
      'content': message.content,
      'attachments': const <Object?>[],
      'timestamp': _canonicalUtc(message.timestamp),
      'groupId': message.groupId ?? message.id,
      'version': message.version,
      'status': message.generationStatus,
      'modelId': message.modelId,
      'providerId': message.providerId,
      'totalTokens': message.totalTokens,
      'reasoningText': message.reasoningText,
      'reasoningSegmentsJson': message.reasoningSegmentsJson,
      'translation': message.translation,
      'reasoningStartAt': _nullableCanonicalUtc(message.reasoningStartAt),
      'reasoningFinishedAt': _nullableCanonicalUtc(message.reasoningFinishedAt),
      'promptTokens': message.promptTokens,
      'completionTokens': message.completionTokens,
      'cachedTokens': message.cachedTokens,
      'durationMs': message.durationMs,
    });
  }

  Future<E2eeSyncEntitySnapshot> _readMessageSelection(
    SyncEntityKey entityKey,
  ) async {
    final conversationId = await _repository.getConversationIdForSelection(
      entityKey.entityId,
    );
    if (conversationId == null) return const E2eeSyncTombstoneSnapshot();
    final conversation = await _repository.getConversation(
      conversationId,
      includeMessageIds: false,
    );
    final selectedVersion = conversation?.versionSelections[entityKey.entityId];
    if (selectedVersion == null) return const E2eeSyncTombstoneSnapshot();
    return _encodeValue(entityKey, <String, Object?>{
      'conversationId': conversationId,
      'groupId': entityKey.entityId,
      'selectedVersion': selectedVersion,
    });
  }

  Future<E2eeSyncEntitySnapshot> _readToolEvent(SyncEntityKey entityKey) async {
    if (!await _repository.hasToolEvents(entityKey.entityId)) {
      return const E2eeSyncTombstoneSnapshot();
    }
    final events = await _repository.getToolEvents(entityKey.entityId);
    return _encodeValue(entityKey, <String, Object?>{
      'messageId': entityKey.entityId,
      'events': <Object?>[
        for (final event in events) Map<String, Object?>.from(event),
      ],
    });
  }

  Future<E2eeSyncEntitySnapshot> _readThoughtSignature(
    SyncEntityKey entityKey,
  ) async {
    final signature = await _repository.getGeminiThoughtSignature(
      entityKey.entityId,
    );
    if (signature == null) return const E2eeSyncTombstoneSnapshot();
    return _encodeValue(entityKey, <String, Object?>{
      'messageId': entityKey.entityId,
      'signature': signature,
    });
  }

  E2eeSyncValueSnapshot _encodeValue(
    SyncEntityKey entityKey,
    Map<String, Object?> payload,
  ) {
    final encoded = E2eeSyncPayloadCodec.encode(
      entityKey: entityKey,
      payload: payload,
    );
    try {
      return E2eeSyncValueSnapshot.copyFrom(encoded);
    } finally {
      encoded.fillRange(0, encoded.length, 0);
    }
  }

  Future<void> _applyValue(
    E2eeSyncPulledValueChange change,
    Set<String> rebuildConversationIds,
  ) async {
    final key = change.state.entityKey;
    _validatePayload(key, change.payload);
    switch (key.entityType) {
      case E2eeSyncChatRecordTypes.conversation:
        await _applyConversationValue(key, change.payload);
      case E2eeSyncChatRecordTypes.turn:
        rebuildConversationIds.add(await _applyTurnValue(key, change.payload));
      case E2eeSyncChatRecordTypes.message:
        rebuildConversationIds.add(
          await _applyMessageValue(key, change.payload),
        );
      case E2eeSyncChatRecordTypes.messageSelection:
        await _applyMessageSelectionValue(key, change.payload);
      case E2eeSyncChatRecordTypes.toolEvent:
        await _applyToolEventValue(key, change.payload);
      case E2eeSyncChatRecordTypes.thoughtSignature:
        await _applyThoughtSignatureValue(key, change.payload);
      default:
        throw StateError('sync_chat_entity_type_unreachable');
    }
  }

  Future<void> _applyConversationValue(
    SyncEntityKey key,
    Map<String, Object?> payload,
  ) {
    return _repository.upsertConversationFromSync(
      Conversation(
        id: key.entityId,
        title: payload['title'] as String,
        createdAt: DateTime.parse(payload['createdAt'] as String),
        updatedAt: DateTime.parse(payload['updatedAt'] as String),
        isPinned: payload['isPinned'] as bool,
        assistantId: payload['assistantId'] as String?,
        mcpServerIds: (payload['mcpServerIds'] as List<Object?>).cast<String>(),
        truncateIndex: payload['truncateIndex'] as int,
        summary: payload['summary'] as String?,
        lastSummarizedMessageCount:
            payload['lastSummarizedMessageCount'] as int,
        chatSuggestions: (payload['chatSuggestions'] as List<Object?>)
            .cast<String>(),
      ),
    );
  }

  Future<String> _applyTurnValue(
    SyncEntityKey key,
    Map<String, Object?> payload,
  ) async {
    final conversationId = payload['conversationId'] as String;
    if (await _repository.getConversation(
          conversationId,
          includeMessageIds: false,
        ) ==
        null) {
      throw StateError('sync_turn_conversation_missing');
    }
    await _repository.upsertTurnFromSync(
      conversationId: conversationId,
      turnId: key.entityId,
      createdAt: DateTime.parse(payload['createdAt'] as String),
    );
    return conversationId;
  }

  Future<String> _applyMessageValue(
    SyncEntityKey key,
    Map<String, Object?> payload,
  ) async {
    final attachments = payload['attachments'] as List<Object?>;
    final content = payload['content'] as String;
    if (attachments.isNotEmpty || _containsLocalAttachmentMarker(content)) {
      throw StateError('sync_message_attachments_not_supported');
    }
    final conversationId = payload['conversationId'] as String;
    final turnId = payload['turnId'] as String;
    if (await _repository.getConversation(
          conversationId,
          includeMessageIds: false,
        ) ==
        null) {
      throw StateError('sync_message_conversation_missing');
    }
    final turn = await _repository.getTurnForSync(turnId);
    if (turn == null) throw StateError('sync_message_turn_missing');
    if (turn.conversationId != conversationId) {
      throw StateError('sync_message_turn_parent_mismatch');
    }
    final message = ChatMessage(
      id: key.entityId,
      role: payload['role'] as String,
      content: content,
      timestamp: DateTime.parse(payload['timestamp'] as String),
      modelId: payload['modelId'] as String?,
      providerId: payload['providerId'] as String?,
      totalTokens: payload['totalTokens'] as int?,
      conversationId: conversationId,
      isStreaming: false,
      reasoningText: payload['reasoningText'] as String?,
      reasoningStartAt: _parseNullableDateTime(payload['reasoningStartAt']),
      reasoningFinishedAt: _parseNullableDateTime(
        payload['reasoningFinishedAt'],
      ),
      translation: payload['translation'] as String?,
      reasoningSegmentsJson: payload['reasoningSegmentsJson'] as String?,
      groupId: payload['groupId'] as String,
      version: payload['version'] as int,
      promptTokens: payload['promptTokens'] as int?,
      completionTokens: payload['completionTokens'] as int?,
      cachedTokens: payload['cachedTokens'] as int?,
      durationMs: payload['durationMs'] as int?,
      turnId: turnId,
      generationStatus: payload['status'] as String,
    );
    _requireTerminalMessage(message);
    await _repository.upsertMessageFromSync(message);
    return conversationId;
  }

  Future<void> _applyMessageSelectionValue(
    SyncEntityKey key,
    Map<String, Object?> payload,
  ) async {
    final conversationId = payload['conversationId'] as String;
    final selectedVersion = payload['selectedVersion'] as int;
    final versions = await _repository.getMessagesForGroups(
      conversationId,
      <String>[key.entityId],
    );
    if (!versions.any((message) => message.version == selectedVersion)) {
      throw StateError('sync_message_selection_revision_missing');
    }
    await _repository.setSelectedVersionFromSync(
      conversationId: conversationId,
      groupId: key.entityId,
      version: selectedVersion,
    );
  }

  Future<void> _applyToolEventValue(
    SyncEntityKey key,
    Map<String, Object?> payload,
  ) async {
    if (await _repository.getMessage(key.entityId) == null) {
      throw StateError('sync_tool_event_message_missing');
    }
    final events = payload['events'] as List<Object?>;
    await _repository.setToolEvents(key.entityId, <Map<String, dynamic>>[
      for (final event in events)
        Map<String, dynamic>.from(event as Map<String, Object?>),
    ]);
  }

  Future<void> _applyThoughtSignatureValue(
    SyncEntityKey key,
    Map<String, Object?> payload,
  ) async {
    if (await _repository.getMessage(key.entityId) == null) {
      throw StateError('sync_thought_signature_message_missing');
    }
    await _repository.setGeminiThoughtSignature(
      key.entityId,
      payload['signature'] as String,
    );
  }

  Future<bool> _applyTombstone(
    E2eeSyncPulledTombstoneChange change,
    Set<String> rebuildConversationIds,
  ) async {
    final key = change.state.entityKey;
    switch (key.entityType) {
      case E2eeSyncChatRecordTypes.conversation:
        final existed =
            await _repository.getConversation(
              key.entityId,
              includeMessageIds: false,
            ) !=
            null;
        await _repository.deleteConversation(key.entityId);
        return existed;
      case E2eeSyncChatRecordTypes.turn:
        final conversationId = await _repository.getConversationIdForTurn(
          key.entityId,
        );
        await _repository.deleteTurnFromSync(turnId: key.entityId);
        if (conversationId != null) rebuildConversationIds.add(conversationId);
        return conversationId != null;
      case E2eeSyncChatRecordTypes.message:
        final message = await _repository.getMessage(key.entityId);
        if (message == null) return false;
        await _repository.deleteMessageFromSync(key.entityId);
        rebuildConversationIds.add(message.conversationId);
        return true;
      case E2eeSyncChatRecordTypes.messageSelection:
        final conversationId = await _repository.getConversationIdForSelection(
          key.entityId,
        );
        if (conversationId == null) return false;
        await _repository.setSelectedVersionFromSync(
          conversationId: conversationId,
          groupId: key.entityId,
          version: null,
        );
        return false;
      case E2eeSyncChatRecordTypes.toolEvent:
        await _repository.deleteToolEvents(key.entityId);
        return false;
      case E2eeSyncChatRecordTypes.thoughtSignature:
        await _repository.deleteGeminiThoughtSignature(key.entityId);
        return false;
      default:
        throw StateError('sync_chat_entity_type_unreachable');
    }
  }

  void _validateChange(E2eeSyncPulledChange change) {
    E2eeSyncPayloadCodec.validateEntityKey(change.state.entityKey);
    final kindMatches = switch (change) {
      E2eeSyncPulledValueChange() =>
        change.state.kind == E2eeAccountRecordStateKind.value,
      E2eeSyncPulledTombstoneChange() =>
        change.state.kind == E2eeAccountRecordStateKind.tombstone,
    };
    if (!kindMatches) throw const FormatException('同步变更类型与认证状态不一致');
  }

  void _validatePayload(SyncEntityKey entityKey, Map<String, Object?> payload) {
    final encoded = E2eeSyncPayloadCodec.encode(
      entityKey: entityKey,
      payload: payload,
    );
    encoded.fillRange(0, encoded.length, 0);
  }

  void _requireTerminalMessage(ChatMessage message) {
    if (message.isStreaming ||
        message.generationStatus == ChatMessage.generationStatusDraft ||
        !ChatMessage.generationStatuses.contains(message.generationStatus)) {
      throw StateError('sync_message_not_terminal');
    }
  }
}

final class _PullApplyContext {
  bool appliedChanges = false;
  bool mayHaveOrphanedAssets = false;
}

final class _IndexedPulledChange {
  const _IndexedPulledChange({required this.index, required this.change});

  final int index;
  final E2eeSyncPulledChange change;
}

int _compareChanges(_IndexedPulledChange left, _IndexedPulledChange right) {
  var compared = _changePriority(
    left.change,
  ).compareTo(_changePriority(right.change));
  if (compared != 0) return compared;
  compared = left.change.untrustedServerMetadata.changeSeq.compareTo(
    right.change.untrustedServerMetadata.changeSeq,
  );
  return compared != 0 ? compared : left.index.compareTo(right.index);
}

int _changePriority(E2eeSyncPulledChange change) {
  final dependencyRank = switch (change.state.entityKey.entityType) {
    E2eeSyncChatRecordTypes.conversation => 0,
    E2eeSyncChatRecordTypes.turn => 1,
    E2eeSyncChatRecordTypes.message => 2,
    E2eeSyncChatRecordTypes.messageSelection ||
    E2eeSyncChatRecordTypes.toolEvent ||
    E2eeSyncChatRecordTypes.thoughtSignature => 3,
    _ => throw StateError('sync_chat_entity_type_unreachable'),
  };
  return switch (change) {
    E2eeSyncPulledValueChange() => dependencyRank,
    E2eeSyncPulledTombstoneChange() => 7 - dependencyRank,
  };
}

String _canonicalUtc(DateTime value) => value.toUtc().toIso8601String();

String? _nullableCanonicalUtc(DateTime? value) =>
    value == null ? null : _canonicalUtc(value);

DateTime? _parseNullableDateTime(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

bool _containsLocalAttachmentMarker(String content) =>
    content.contains('[image:') || content.contains('[file:');
