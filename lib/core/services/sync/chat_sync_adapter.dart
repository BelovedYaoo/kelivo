import '../chat/chat_service.dart';
import '../chat/upload_directory_critical_section.dart';
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
