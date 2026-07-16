import '../chat/chat_service.dart';
import '../chat/upload_directory_critical_section.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import 'chat_sync_codec.dart';
import 'cloud_attachment_sync_service.dart';
import 'sync_codec.dart';

final class ChatSyncAdapter implements SyncEntityAdapter {
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
  Future<T> runRemoteBatch<T>(Future<T> Function() apply) => apply();

  @override
  Future<LocalSyncEntity?> exportLocalEntity(SyncEntityKey key) async {
    if (!_chatService.initialized) {
      await _chatService.init();
    }
    if (!entityTypes.contains(key.entityType)) {
      throw FormatException('不支持的聊天同步实体：${key.entityType}');
    }

    return switch (key.entityType) {
      conversationType => _exportConversation(key.entityId),
      turnType => _exportTurn(key.entityId),
      messageType => await _exportMessage(key.entityId),
      messageSelectionType => _exportMessageSelection(key.entityId),
      toolEventType => _exportToolEvent(key.entityId),
      thoughtSignatureType => _exportThoughtSignature(key.entityId),
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
    final requested = Set<SyncEntityKey>.unmodifiable(keys);
    final result = <SyncEntityKey, LocalSyncEntity>{};
    for (final entity in await exportLocalEntities()) {
      if (requested.contains(entity.key)) {
        result[entity.key] = entity;
      }
    }
    return Map<SyncEntityKey, LocalSyncEntity>.unmodifiable(result);
  }

  @override
  Future<List<LocalSyncEntity>> exportLocalEntities() async {
    if (!_chatService.initialized) {
      await _chatService.init();
    }

    final entities = <LocalSyncEntity>[];
    for (final conversation in _chatService.getAllConversations()) {
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

      final messages = _chatService.getMessages(conversation.id);
      for (final turn in ChatSyncCodec.deriveTurns(messages)) {
        entities.add(
          LocalSyncEntity(
            entityType: turnType,
            entityId: turn.id,
            parentId: turn.conversationId,
            payload: ChatSyncCodec.encodeTurn(turn),
          ),
        );
      }

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
        final toolEvents = _chatService.getToolEvents(message.id);
        if (_chatService.hasToolEvents(message.id)) {
          entities.add(
            LocalSyncEntity(
              entityType: toolEventType,
              entityId: message.id,
              parentId: message.id,
              payload: ChatSyncCodec.encodeToolEvent(message.id, toolEvents),
            ),
          );
        }
        final thoughtSignature = _chatService.getGeminiThoughtSignature(
          message.id,
        );
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

  LocalSyncEntity? _exportConversation(String conversationId) {
    final conversation = _findConversation(conversationId);
    if (conversation == null) return null;
    return LocalSyncEntity(
      entityType: conversationType,
      entityId: conversation.id,
      payload: ChatSyncCodec.encodeConversation(conversation),
    );
  }

  LocalSyncEntity? _exportTurn(String turnId) {
    for (final conversation in _chatService.getAllConversations()) {
      final matching = _chatService
          .getMessages(conversation.id)
          .where((message) => message.turnId == turnId)
          .toList(growable: false);
      if (matching.isEmpty) continue;
      final turn = ChatSyncCodec.deriveTurns(matching).single;
      return LocalSyncEntity(
        entityType: turnType,
        entityId: turn.id,
        parentId: turn.conversationId,
        payload: ChatSyncCodec.encodeTurn(turn),
      );
    }
    return null;
  }

  Future<LocalSyncEntity?> _exportMessage(String messageId) async {
    final message = _findMessage(messageId);
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

  LocalSyncEntity? _exportMessageSelection(String groupId) {
    for (final conversation in _chatService.getAllConversations()) {
      final selectedVersion = conversation.versionSelections[groupId];
      if (selectedVersion == null) continue;
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
    return null;
  }

  LocalSyncEntity? _exportToolEvent(String messageId) {
    final message = _findMessage(messageId);
    if (message == null ||
        ChatSyncCodec.encodeMessage(message, syncedContent: '') == null ||
        !_chatService.hasToolEvents(messageId)) {
      return null;
    }
    return LocalSyncEntity(
      entityType: toolEventType,
      entityId: messageId,
      parentId: messageId,
      payload: ChatSyncCodec.encodeToolEvent(
        messageId,
        _chatService.getToolEvents(messageId),
      ),
    );
  }

  LocalSyncEntity? _exportThoughtSignature(String messageId) {
    final message = _findMessage(messageId);
    if (message == null ||
        ChatSyncCodec.encodeMessage(message, syncedContent: '') == null) {
      return null;
    }
    final signature = _chatService.getGeminiThoughtSignature(messageId);
    if (signature == null) return null;
    return LocalSyncEntity(
      entityType: thoughtSignatureType,
      entityId: messageId,
      parentId: messageId,
      payload: ChatSyncCodec.encodeThoughtSignature(messageId, signature),
    );
  }

  Conversation? _findConversation(String conversationId) {
    for (final conversation in _chatService.getAllConversations()) {
      if (conversation.id == conversationId) return conversation;
    }
    return null;
  }

  ChatMessage? _findMessage(String messageId) {
    for (final conversation in _chatService.getAllConversations()) {
      final index = conversation.messageIds.indexOf(messageId);
      if (index < 0) continue;
      final messages = _chatService.getMessagesRange(
        conversation.id,
        start: index,
        limit: 1,
      );
      if (messages.isNotEmpty && messages.single.id == messageId) {
        return messages.single;
      }
    }
    return null;
  }

  @override
  Future<void> applyRemoteUpsert(RemoteSyncEntity entity) async {
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
          await UploadDirectoryCriticalSection.run(() async {
            final content = await _attachmentSyncService.restoreMessage(
              messageId: entity.entityId,
              syncedContent: record.message.content,
              references: record.attachments,
            );
            await _chatService.upsertMessageFromSync(
              record.message.copyWith(content: content),
            );
            await _attachmentSyncService.forgetRemoteOrdinaryUserMessage(
              entity.entityId,
            );
          });
        }
        return;
      case turnType:
        final turn = ChatSyncCodec.decodeTurn(entity.entityId, entity.payload);
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
        for (final conversation in _chatService.getAllConversations()) {
          final hasTurn = _chatService
              .getMessages(conversation.id)
              .any((message) => message.turnId == key.entityId);
          if (!hasTurn) continue;
          await _chatService.deleteTurnFromSync(
            conversationId: conversation.id,
            turnId: key.entityId,
          );
          return;
        }
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
