import '../chat/chat_service.dart';
import 'chat_sync_codec.dart';
import 'cloud_attachment_sync_service.dart';
import 'sync_codec.dart';

final class ChatSyncAdapter
    implements SyncEntityAdapter, RemoteSyncUpsertPreparer {
  ChatSyncAdapter(this._chatService, this._attachmentSyncService);

  static const String conversationType = 'conversation';
  static const String turnType = 'turn';
  static const String messageType = 'message';
  static const String messageSelectionType = 'message-selection';
  static const String toolEventType = 'tool-event';
  static const String thoughtSignatureType = 'thought-signature';

  final ChatService _chatService;
  final CloudAttachmentSyncService _attachmentSyncService;

  @override
  Set<String> get entityTypes => const <String>{
    conversationType,
    turnType,
    messageType,
    messageSelectionType,
    toolEventType,
    thoughtSignatureType,
  };

  @override
  int get applyPriority => 100;

  @override
  Future<T> runRemoteBatch<T>(Future<T> Function() apply) {
    return _chatService.runRemoteBatch(apply);
  }

  @override
  Future<LocalSyncEntity?> exportLocalEntity(SyncEntityKey key) async {
    if (!_chatService.initialized) {
      await _chatService.init();
    }
    if (!entityTypes.contains(key.entityType)) {
      throw FormatException('不支持的聊天同步实体：${key.entityType}');
    }

    return switch (key.entityType) {
      conversationType => await _exportConversation(key.entityId),
      turnType => await _exportTurn(key.entityId),
      messageType => await _exportMessage(key.entityId),
      messageSelectionType => await _exportMessageSelection(key.entityId),
      toolEventType => await _exportToolEvent(key.entityId),
      thoughtSignatureType => await _exportThoughtSignature(key.entityId),
      _ => null,
    };
  }

  @override
  Future<Map<SyncEntityKey, LocalSyncEntity>> exportLocalEntitiesForKeys(
    Set<SyncEntityKey> keys,
  ) async {
    for (final key in keys) {
      if (!entityTypes.contains(key.entityType)) {
        throw FormatException('不支持的聊天同步实体：${key.entityType}');
      }
    }
    final result = <SyncEntityKey, LocalSyncEntity>{};
    for (final key in keys) {
      final entity = await exportLocalEntity(key);
      if (entity != null) result[key] = entity;
    }
    return Map<SyncEntityKey, LocalSyncEntity>.unmodifiable(result);
  }

  @override
  Future<List<LocalSyncEntity>> exportLocalEntities() async {
    if (!_chatService.initialized) {
      await _chatService.init();
    }

    final entities = <LocalSyncEntity>[];
    final conversations = await _chatService.loadConversationsForSync();
    for (final conversation in conversations) {
      entities.add(
        LocalSyncEntity(
          entityType: conversationType,
          entityId: conversation.id,
          payload: ChatSyncCodec.encodeConversation(conversation),
        ),
      );

      final selections = conversation.versionSelections.entries.toList()
        ..sort((left, right) => left.key.compareTo(right.key));
      for (final selection in selections) {
        entities.add(
          LocalSyncEntity(
            entityType: messageSelectionType,
            entityId: selection.key,
            parentId: conversation.id,
            payload: ChatSyncCodec.encodeMessageSelection(
              ChatSyncMessageSelectionRecord(
                conversationId: conversation.id,
                groupId: selection.key,
                selectedVersion: selection.value,
              ),
            ),
          ),
        );
      }

      final messages = await _chatService.loadMessagesForSync(conversation.id);
      final turnCreatedAts = await _chatService.loadTurnCreatedAtsForSync(
        conversation.id,
      );
      for (final derived in ChatSyncCodec.deriveTurns(messages)) {
        final turn = ChatSyncTurnRecord(
          id: derived.id,
          conversationId: derived.conversationId,
          createdAt: turnCreatedAts[derived.id] ?? derived.createdAt,
        );
        entities.add(
          LocalSyncEntity(
            entityType: turnType,
            entityId: turn.id,
            parentId: turn.conversationId,
            payload: ChatSyncCodec.encodeTurn(turn),
          ),
        );
      }

      final messageIds = messages.map((message) => message.id).toList();
      final toolEventsByMessageId = await _chatService
          .loadToolEventsForMessagesForSync(messageIds);
      final thoughtSignaturesByMessageId = await _chatService
          .loadThoughtSignaturesForMessagesForSync(messageIds);

      for (final message in messages) {
        final syncable = ChatSyncCodec.encodeMessage(
          message,
          syncedContent: '',
        );
        if (syncable == null) continue;
        final prepared = message.role == 'user'
            ? await _attachmentSyncService.prepareMessage(
                messageId: message.id,
                content: message.content,
              )
            : PreparedChatSyncAttachments(
                syncedContent: message.content,
                references: const <ChatSyncAttachmentReference>[],
              );
        final payload = ChatSyncCodec.encodeMessage(
          message,
          syncedContent: prepared.syncedContent,
          attachments: prepared.references,
        )!;
        entities.add(
          LocalSyncEntity(
            entityType: messageType,
            entityId: message.id,
            parentId: message.turnId,
            payload: payload,
          ),
        );
        final toolEvents = toolEventsByMessageId[message.id];
        if (toolEvents != null) {
          entities.add(
            LocalSyncEntity(
              entityType: toolEventType,
              entityId: message.id,
              parentId: message.id,
              payload: ChatSyncCodec.encodeToolEvent(message.id, toolEvents),
            ),
          );
        }
        final thoughtSignature = thoughtSignaturesByMessageId[message.id];
        if (thoughtSignature != null) {
          entities.add(
            LocalSyncEntity(
              entityType: thoughtSignatureType,
              entityId: message.id,
              parentId: message.id,
              payload: ChatSyncCodec.encodeThoughtSignature(
                message.id,
                thoughtSignature,
              ),
            ),
          );
        }
      }
    }
    return entities;
  }

  Future<LocalSyncEntity?> _exportConversation(String conversationId) async {
    final conversation = await _chatService.loadConversationForSync(
      conversationId,
    );
    if (conversation == null) return null;
    return LocalSyncEntity(
      entityType: conversationType,
      entityId: conversation.id,
      payload: ChatSyncCodec.encodeConversation(conversation),
    );
  }

  Future<LocalSyncEntity?> _exportTurn(String turnId) async {
    final matching = await _chatService.loadMessagesForTurn(turnId);
    if (matching.isEmpty) return null;
    final derived = ChatSyncCodec.deriveTurns(matching).single;
    final createdAts = await _chatService.loadTurnCreatedAtsForSync(
      derived.conversationId,
    );
    final turn = ChatSyncTurnRecord(
      id: derived.id,
      conversationId: derived.conversationId,
      createdAt: createdAts[derived.id] ?? derived.createdAt,
    );
    return LocalSyncEntity(
      entityType: turnType,
      entityId: turn.id,
      parentId: turn.conversationId,
      payload: ChatSyncCodec.encodeTurn(turn),
    );
  }

  Future<LocalSyncEntity?> _exportMessage(String messageId) async {
    final message = await _chatService.loadMessageForSync(messageId);
    if (message == null ||
        ChatSyncCodec.encodeMessage(message, syncedContent: '') == null) {
      return null;
    }
    final prepared = message.role == 'user'
        ? await _attachmentSyncService.prepareMessage(
            messageId: message.id,
            content: message.content,
          )
        : PreparedChatSyncAttachments(
            syncedContent: message.content,
            references: const <ChatSyncAttachmentReference>[],
          );
    return LocalSyncEntity(
      entityType: messageType,
      entityId: message.id,
      parentId: message.turnId,
      payload: ChatSyncCodec.encodeMessage(
        message,
        syncedContent: prepared.syncedContent,
        attachments: prepared.references,
      )!,
    );
  }

  Future<LocalSyncEntity?> _exportMessageSelection(String groupId) async {
    final conversationId = await _chatService.loadConversationIdForSelection(
      groupId,
    );
    if (conversationId == null) return null;
    final conversation = await _chatService.loadConversationForSync(
      conversationId,
    );
    final selectedVersion = conversation?.versionSelections[groupId];
    if (conversation == null || selectedVersion == null) return null;
    return LocalSyncEntity(
      entityType: messageSelectionType,
      entityId: groupId,
      parentId: conversation.id,
      payload: ChatSyncCodec.encodeMessageSelection(
        ChatSyncMessageSelectionRecord(
          conversationId: conversation.id,
          groupId: groupId,
          selectedVersion: selectedVersion,
        ),
      ),
    );
  }

  Future<LocalSyncEntity?> _exportToolEvent(String messageId) async {
    final message = await _chatService.loadMessageForSync(messageId);
    if (message == null ||
        ChatSyncCodec.encodeMessage(message, syncedContent: '') == null ||
        !await _chatService.hasToolEventsForSync(messageId)) {
      return null;
    }
    final toolEvents = await _chatService.loadToolEventsForSync(messageId);
    return LocalSyncEntity(
      entityType: toolEventType,
      entityId: messageId,
      parentId: messageId,
      payload: ChatSyncCodec.encodeToolEvent(messageId, toolEvents),
    );
  }

  Future<LocalSyncEntity?> _exportThoughtSignature(String messageId) async {
    final message = await _chatService.loadMessageForSync(messageId);
    if (message == null ||
        ChatSyncCodec.encodeMessage(message, syncedContent: '') == null) {
      return null;
    }
    final signature = await _chatService.loadThoughtSignatureForSync(messageId);
    if (signature == null) return null;
    return LocalSyncEntity(
      entityType: thoughtSignatureType,
      entityId: messageId,
      parentId: messageId,
      payload: ChatSyncCodec.encodeThoughtSignature(messageId, signature),
    );
  }

  @override
  Future<void> applyRemoteUpsert(RemoteSyncEntity entity) async {
    final prepared = await prepareRemoteUpsert(entity);
    if (prepared != null) {
      try {
        await prepared.apply();
        await prepared.commit();
      } catch (_) {
        await prepared.discard();
        rethrow;
      }
      return;
    }
    switch (entity.entityType) {
      case conversationType:
        final conversation = ChatSyncCodec.decodeConversation(
          entity.entityId,
          entity.payload,
        );
        await _chatService.upsertConversationFromSync(conversation);
        return;
      case messageType:
        final record = ChatSyncCodec.decodeMessage(
          entity.entityId,
          entity.payload,
        );
        _requireParent(entity, record.message.turnId);
        if (record.attachments.isEmpty) {
          if (record.message.role == 'user') {
            await _attachmentSyncService.rememberRemoteOrdinaryUserMessage(
              messageId: entity.entityId,
              content: record.message.content,
            );
          } else {
            await _attachmentSyncService.forgetRemoteOrdinaryUserMessage(
              entity.entityId,
            );
          }
          await _chatService.upsertMessageFromSync(record.message);
        } else {
          throw StateError('带附件的远端消息必须先完成资源准备');
        }
        return;
      case turnType:
        final turn = ChatSyncCodec.decodeTurn(entity.entityId, entity.payload);
        _requireParent(entity, turn.conversationId);
        await _chatService.applyTurnFromSync(
          conversationId: turn.conversationId,
          turnId: turn.id,
          createdAt: turn.createdAt,
        );
        return;
      case messageSelectionType:
        final selection = ChatSyncCodec.decodeMessageSelection(
          entity.entityId,
          entity.payload,
        );
        _requireParent(entity, selection.conversationId);
        await _chatService.upsertMessageSelectionFromSync(
          conversationId: selection.conversationId,
          groupId: selection.groupId,
          selectedVersion: selection.selectedVersion,
        );
        return;
      case toolEventType:
        final toolEvent = ChatSyncCodec.decodeToolEvent(
          entity.entityId,
          entity.payload,
        );
        _requireParent(entity, toolEvent.messageId);
        await _chatService.upsertToolEventsFromSync(
          messageId: toolEvent.messageId,
          events: toolEvent.events,
        );
        return;
      case thoughtSignatureType:
        final thoughtSignature = ChatSyncCodec.decodeThoughtSignature(
          entity.entityId,
          entity.payload,
        );
        _requireParent(entity, thoughtSignature.messageId);
        await _chatService.upsertThoughtSignatureFromSync(
          messageId: thoughtSignature.messageId,
          signature: thoughtSignature.signature,
        );
        return;
      default:
        throw FormatException('聊天同步不支持实体类型：${entity.entityType}');
    }
  }

  @override
  Future<PreparedRemoteSyncUpsert?> prepareRemoteUpsert(
    RemoteSyncEntity entity,
  ) async {
    if (entity.entityType != messageType) return null;
    final record = ChatSyncCodec.decodeMessage(entity.entityId, entity.payload);
    _requireParent(entity, record.message.turnId);
    if (record.attachments.isEmpty) return null;
    final preparedRestore = await _attachmentSyncService.prepareRestoreMessage(
      messageId: entity.entityId,
      syncedContent: record.message.content,
      references: record.attachments,
    );
    return _PreparedChatRemoteUpsert(
      key: entity.key,
      applyAction: () => _chatService.upsertMessageFromSync(
        record.message.copyWith(content: preparedRestore.content),
      ),
      commitAction: () async {
        await preparedRestore.commit();
        await _attachmentSyncService.forgetRemoteOrdinaryUserMessage(
          entity.entityId,
        );
      },
      discardAction: preparedRestore.discard,
    );
  }

  @override
  Future<void> applyRemoteDelete(SyncEntityKey key) async {
    switch (key.entityType) {
      case conversationType:
        await _chatService.deleteConversationFromSync(key.entityId);
        return;
      case messageType:
        await _attachmentSyncService.forgetRemoteOrdinaryUserMessage(
          key.entityId,
        );
        await _chatService.deleteMessageFromSync(key.entityId);
        return;
      case turnType:
        final conversationId = await _chatService.loadConversationIdForTurn(
          key.entityId,
        );
        if (conversationId == null) return;
        await _chatService.deleteTurnFromSync(
          conversationId: conversationId,
          turnId: key.entityId,
        );
        return;
      case messageSelectionType:
        await _chatService.deleteMessageSelectionFromSync(key.entityId);
        return;
      case toolEventType:
        await _chatService.deleteToolEventsFromSync(key.entityId);
        return;
      case thoughtSignatureType:
        await _chatService.deleteThoughtSignatureFromSync(key.entityId);
        return;
      default:
        throw FormatException('聊天同步不支持实体类型：${key.entityType}');
    }
  }

  void _requireParent(RemoteSyncEntity entity, String expectedParentId) {
    if (entity.parentId != expectedParentId) {
      throw FormatException('${entity.entityType}.parentId 与 Payload 父级不一致');
    }
  }
}

final class _PreparedChatRemoteUpsert implements PreparedRemoteSyncUpsert {
  _PreparedChatRemoteUpsert({
    required this.key,
    required this.applyAction,
    required this.commitAction,
    required this.discardAction,
  });

  @override
  final SyncEntityKey key;
  final Future<void> Function() applyAction;
  final Future<void> Function() commitAction;
  final Future<void> Function() discardAction;

  @override
  Future<void> apply() => applyAction();

  @override
  Future<void> commit() => commitAction();

  @override
  Future<void> discard() => discardAction();
}
