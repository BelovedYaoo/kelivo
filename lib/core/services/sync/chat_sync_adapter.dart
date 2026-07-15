import '../chat/chat_service.dart';
import 'chat_sync_codec.dart';
import 'sync_codec.dart';

final class ChatSyncAdapter implements SyncEntityAdapter {
  ChatSyncAdapter(this._chatService);

  static const String conversationType = 'conversation';
  static const String turnType = 'turn';
  static const String messageType = 'message';

  final ChatService _chatService;

  @override
  Set<String> get entityTypes => const <String>{
    conversationType,
    turnType,
    messageType,
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
        final payload = ChatSyncCodec.encodeMessage(message);
        if (payload == null) continue;
        entities.add(
          LocalSyncEntity(
            entityType: messageType,
            entityId: message.id,
            parentId: message.conversationId,
            payload: payload,
          ),
        );
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
        if (record.attachments.isNotEmpty) {
          throw const FormatException('远端消息附件尚未完成本地文件解析');
        }
        await _chatService.upsertMessageFromSync(record.message);
        return;
      case turnType:
        final turn = ChatSyncCodec.decodeTurn(entity.entityId, entity.payload);
        await _chatService.applyTurnFromSync(
          conversationId: turn.conversationId,
          turnId: turn.id,
          createdAt: turn.createdAt,
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
      default:
        throw FormatException('聊天同步不支持实体类型：${key.entityType}');
    }
  }
}
