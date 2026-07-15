import '../../models/chat_message.dart';
import '../../models/conversation.dart';

final class ChatSyncAttachmentReference {
  const ChatSyncAttachmentReference({
    required this.attachmentId,
    required this.kind,
    required this.order,
  });

  static const String imageKind = 'image';
  static const String fileKind = 'file';
  static const Set<String> kinds = <String>{imageKind, fileKind};

  final String attachmentId;
  final String kind;
  final int order;

  Map<String, Object?> toPayload() => <String, Object?>{
    'attachmentId': attachmentId,
    'kind': kind,
    'order': order,
  };
}

final class ChatSyncTurnRecord {
  const ChatSyncTurnRecord({
    required this.id,
    required this.conversationId,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final DateTime createdAt;
}

final class ChatSyncMessageRecord {
  ChatSyncMessageRecord({
    required this.message,
    required List<ChatSyncAttachmentReference> attachments,
  }) : attachments = List<ChatSyncAttachmentReference>.unmodifiable(
         attachments,
       );

  final ChatMessage message;
  final List<ChatSyncAttachmentReference> attachments;
}

abstract final class ChatSyncCodec {
  static final RegExp _localAttachmentMarker = RegExp(r'\[(?:image|file):');

  static const Set<String> _conversationKeys = <String>{
    'title',
    'createdAt',
    'updatedAt',
    'isPinned',
    'assistantId',
    'mcpServerIds',
    'truncateIndex',
    'summary',
    'lastSummarizedMessageCount',
    'chatSuggestions',
  };
  static const Set<String> _turnKeys = <String>{'conversationId', 'createdAt'};
  static const Set<String> _messageKeys = <String>{
    'conversationId',
    'turnId',
    'role',
    'content',
    'attachments',
    'timestamp',
    'groupId',
    'version',
    'status',
    'modelId',
    'providerId',
    'totalTokens',
    'reasoningText',
    'reasoningSegmentsJson',
    'translation',
    'reasoningStartAt',
    'reasoningFinishedAt',
    'promptTokens',
    'completionTokens',
    'cachedTokens',
    'durationMs',
  };
  static const Set<String> _attachmentKeys = <String>{
    'attachmentId',
    'kind',
    'order',
  };

  static Map<String, Object?> encodeConversation(Conversation conversation) {
    _requireIdentifier(conversation.id, 'conversation.id');
    return <String, Object?>{
      'title': conversation.title,
      'createdAt': _encodeDateTime(conversation.createdAt),
      'updatedAt': _encodeDateTime(conversation.updatedAt),
      'isPinned': conversation.isPinned,
      'assistantId': conversation.assistantId,
      'mcpServerIds': List<String>.of(conversation.mcpServerIds),
      'truncateIndex': conversation.truncateIndex,
      'summary': conversation.summary,
      'lastSummarizedMessageCount': conversation.lastSummarizedMessageCount,
      'chatSuggestions': List<String>.of(conversation.chatSuggestions),
    };
  }

  static Conversation decodeConversation(
    String conversationId,
    Map<String, Object?> payload,
  ) {
    _requireIdentifier(conversationId, 'conversationId');
    _expectExactKeys(payload, _conversationKeys, 'conversation');
    final lastSummarizedMessageCount = _requiredInteger(
      payload,
      'lastSummarizedMessageCount',
    );
    if (lastSummarizedMessageCount < 0) {
      throw const FormatException(
        'conversation.lastSummarizedMessageCount 不能为负数',
      );
    }

    return Conversation(
      id: conversationId,
      title: _requiredString(payload, 'title', allowEmpty: true),
      createdAt: _requiredDateTime(payload, 'createdAt'),
      updatedAt: _requiredDateTime(payload, 'updatedAt'),
      // messageIds 是 ChatService 根据消息与轮次重建的本地索引，不能由会话记录覆盖。
      messageIds: const <String>[],
      isPinned: _requiredBoolean(payload, 'isPinned'),
      assistantId: _nullableString(payload, 'assistantId'),
      mcpServerIds: _requiredStringList(payload, 'mcpServerIds'),
      truncateIndex: _requiredInteger(payload, 'truncateIndex'),
      summary: _nullableString(payload, 'summary'),
      lastSummarizedMessageCount: lastSummarizedMessageCount,
      chatSuggestions: _requiredStringList(payload, 'chatSuggestions'),
    );
  }

  static Map<String, Object?> encodeTurn(ChatSyncTurnRecord turn) {
    _requireIdentifier(turn.id, 'turn.id');
    _requireIdentifier(turn.conversationId, 'turn.conversationId');
    return <String, Object?>{
      'conversationId': turn.conversationId,
      'createdAt': _encodeDateTime(turn.createdAt),
    };
  }

  static ChatSyncTurnRecord decodeTurn(
    String turnId,
    Map<String, Object?> payload,
  ) {
    _requireIdentifier(turnId, 'turnId');
    _expectExactKeys(payload, _turnKeys, 'turn');
    return ChatSyncTurnRecord(
      id: turnId,
      conversationId: _requiredIdentifier(payload, 'conversationId'),
      createdAt: _requiredDateTime(payload, 'createdAt'),
    );
  }

  static List<ChatSyncTurnRecord> deriveTurns(Iterable<ChatMessage> messages) {
    final turns = <String, ChatSyncTurnRecord>{};
    for (final message in messages) {
      if (_isUnsyncableAssistantDraft(message)) continue;
      _requireIdentifier(message.turnId, 'message.turnId');
      _requireIdentifier(message.conversationId, 'message.conversationId');
      final existing = turns[message.turnId];
      if (existing != null &&
          existing.conversationId != message.conversationId) {
        throw FormatException('轮次 ${message.turnId} 不能跨会话');
      }
      if (existing == null || message.timestamp.isBefore(existing.createdAt)) {
        turns[message.turnId] = ChatSyncTurnRecord(
          id: message.turnId,
          conversationId: message.conversationId,
          createdAt: message.timestamp,
        );
      }
    }

    final result = turns.values.toList(growable: false);
    result.sort((left, right) {
      final createdAt = left.createdAt.compareTo(right.createdAt);
      return createdAt != 0 ? createdAt : left.id.compareTo(right.id);
    });
    return result;
  }

  static Map<String, Object?>? encodeMessage(
    ChatMessage message, {
    String? syncedContent,
    List<ChatSyncAttachmentReference> attachments =
        const <ChatSyncAttachmentReference>[],
  }) {
    if (_isUnsyncableAssistantDraft(message)) return null;

    _requireIdentifier(message.id, 'message.id');
    _requireIdentifier(message.conversationId, 'message.conversationId');
    _requireIdentifier(message.turnId, 'message.turnId');
    final groupId = message.groupId ?? message.id;
    _requireIdentifier(groupId, 'message.groupId');
    if (message.role != 'user' && message.role != 'assistant') {
      throw FormatException('不支持的消息角色：${message.role}');
    }
    if (message.version < 0) {
      throw const FormatException('message.version 不能为负数');
    }
    if (message.isStreaming ||
        message.generationStatus == ChatMessage.generationStatusDraft ||
        !ChatMessage.generationStatuses.contains(message.generationStatus)) {
      throw FormatException('消息 ${message.id} 尚未进入可同步终态');
    }

    final content = syncedContent ?? message.content;
    if (_localAttachmentMarker.hasMatch(content)) {
      throw const FormatException('同步消息正文不能包含本地附件路径，请先转换为附件引用');
    }
    _validateAttachments(attachments);

    return <String, Object?>{
      'conversationId': message.conversationId,
      'turnId': message.turnId,
      'role': message.role,
      'content': content,
      'attachments': <Map<String, Object?>>[
        for (final attachment in attachments) attachment.toPayload(),
      ],
      'timestamp': _encodeDateTime(message.timestamp),
      'groupId': groupId,
      'version': message.version,
      'status': message.generationStatus,
      'modelId': message.modelId,
      'providerId': message.providerId,
      'totalTokens': message.totalTokens,
      'reasoningText': message.reasoningText,
      'reasoningSegmentsJson': message.reasoningSegmentsJson,
      'translation': message.translation,
      'reasoningStartAt': _encodeNullableDateTime(message.reasoningStartAt),
      'reasoningFinishedAt': _encodeNullableDateTime(
        message.reasoningFinishedAt,
      ),
      'promptTokens': message.promptTokens,
      'completionTokens': message.completionTokens,
      'cachedTokens': message.cachedTokens,
      'durationMs': message.durationMs,
    };
  }

  static ChatSyncMessageRecord decodeMessage(
    String messageId,
    Map<String, Object?> payload,
  ) {
    _requireIdentifier(messageId, 'messageId');
    _expectExactKeys(payload, _messageKeys, 'message');
    final role = _requiredString(payload, 'role');
    if (role != 'user' && role != 'assistant') {
      throw FormatException('不支持的消息角色：$role');
    }
    final status = _requiredString(payload, 'status');
    if (status == ChatMessage.generationStatusDraft ||
        !ChatMessage.generationStatuses.contains(status)) {
      throw FormatException('不支持的消息生成状态：$status');
    }
    final version = _requiredInteger(payload, 'version');
    if (version < 0) {
      throw const FormatException('message.version 不能为负数');
    }
    final content = _requiredString(payload, 'content', allowEmpty: true);
    if (_localAttachmentMarker.hasMatch(content)) {
      throw const FormatException('远端消息正文包含非法的本地附件路径');
    }

    final attachments = _decodeAttachments(payload);
    return ChatSyncMessageRecord(
      message: ChatMessage(
        id: messageId,
        role: role,
        content: content,
        timestamp: _requiredDateTime(payload, 'timestamp'),
        modelId: _nullableString(payload, 'modelId'),
        providerId: _nullableString(payload, 'providerId'),
        totalTokens: _nullableInteger(payload, 'totalTokens'),
        conversationId: _requiredIdentifier(payload, 'conversationId'),
        isStreaming: false,
        reasoningText: _nullableString(payload, 'reasoningText'),
        reasoningStartAt: _nullableDateTime(payload, 'reasoningStartAt'),
        reasoningFinishedAt: _nullableDateTime(payload, 'reasoningFinishedAt'),
        translation: _nullableString(payload, 'translation'),
        reasoningSegmentsJson: _nullableString(
          payload,
          'reasoningSegmentsJson',
        ),
        groupId: _requiredIdentifier(payload, 'groupId'),
        version: version,
        promptTokens: _nullableInteger(payload, 'promptTokens'),
        completionTokens: _nullableInteger(payload, 'completionTokens'),
        cachedTokens: _nullableInteger(payload, 'cachedTokens'),
        durationMs: _nullableInteger(payload, 'durationMs'),
        turnId: _requiredIdentifier(payload, 'turnId'),
        generationStatus: status,
      ),
      attachments: attachments,
    );
  }

  static bool _isUnsyncableAssistantDraft(ChatMessage message) {
    return message.role == 'assistant' &&
        (message.isStreaming ||
            message.generationStatus == ChatMessage.generationStatusDraft);
  }

  static List<ChatSyncAttachmentReference> _decodeAttachments(
    Map<String, Object?> payload,
  ) {
    final rawAttachments = _requiredList(payload, 'attachments');
    final attachments = <ChatSyncAttachmentReference>[];
    for (var index = 0; index < rawAttachments.length; index++) {
      final raw = rawAttachments[index];
      if (raw is! Map<Object?, Object?>) {
        throw FormatException('message.attachments[$index] 必须是对象');
      }
      final attachment = <String, Object?>{};
      for (final entry in raw.entries) {
        final key = entry.key;
        if (key is! String) {
          throw FormatException('message.attachments[$index] 包含非字符串字段名');
        }
        attachment[key] = entry.value;
      }
      _expectExactKeys(
        attachment,
        _attachmentKeys,
        'message.attachments[$index]',
      );
      final kind = _requiredString(attachment, 'kind');
      if (!ChatSyncAttachmentReference.kinds.contains(kind)) {
        throw FormatException('不支持的附件类型：$kind');
      }
      final order = _requiredInteger(attachment, 'order');
      if (order < 0) {
        throw FormatException('message.attachments[$index].order 不能为负数');
      }
      attachments.add(
        ChatSyncAttachmentReference(
          attachmentId: _requiredIdentifier(attachment, 'attachmentId'),
          kind: kind,
          order: order,
        ),
      );
    }
    _validateAttachments(attachments);
    return attachments;
  }

  static void _validateAttachments(
    List<ChatSyncAttachmentReference> attachments,
  ) {
    final attachmentIds = <String>{};
    final orders = <int>{};
    for (final attachment in attachments) {
      _requireIdentifier(attachment.attachmentId, 'attachment.attachmentId');
      if (!ChatSyncAttachmentReference.kinds.contains(attachment.kind)) {
        throw FormatException('不支持的附件类型：${attachment.kind}');
      }
      if (attachment.order < 0) {
        throw const FormatException('attachment.order 不能为负数');
      }
      if (!attachmentIds.add(attachment.attachmentId)) {
        throw FormatException('附件 ${attachment.attachmentId} 重复');
      }
      if (!orders.add(attachment.order)) {
        throw FormatException('附件顺序 ${attachment.order} 重复');
      }
    }
  }

  static void _expectExactKeys(
    Map<String, Object?> payload,
    Set<String> expected,
    String context,
  ) {
    final missing = expected.difference(payload.keys.toSet());
    final unexpected = payload.keys.toSet().difference(expected);
    if (missing.isEmpty && unexpected.isEmpty) return;
    throw FormatException(
      '$context 字段不匹配，缺少：${missing.join(',')}，多出：${unexpected.join(',')}',
    );
  }

  static Object? _requiredValue(Map<String, Object?> payload, String key) {
    if (!payload.containsKey(key)) {
      throw FormatException('缺少字段：$key');
    }
    return payload[key];
  }

  static String _requiredIdentifier(Map<String, Object?> payload, String key) {
    final value = _requiredString(payload, key);
    _requireIdentifier(value, key);
    return value;
  }

  static void _requireIdentifier(String value, String key) {
    if (value.trim().isEmpty) {
      throw FormatException('$key 不能为空');
    }
  }

  static String _requiredString(
    Map<String, Object?> payload,
    String key, {
    bool allowEmpty = false,
  }) {
    final value = _requiredValue(payload, key);
    if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
      throw FormatException('$key 必须是${allowEmpty ? '' : '非空'}字符串');
    }
    return value;
  }

  static String? _nullableString(Map<String, Object?> payload, String key) {
    final value = _requiredValue(payload, key);
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('$key 必须是字符串或 null');
    }
    return value;
  }

  static int _requiredInteger(Map<String, Object?> payload, String key) {
    final value = _requiredValue(payload, key);
    if (value is! int) {
      throw FormatException('$key 必须是整数');
    }
    return value;
  }

  static int? _nullableInteger(Map<String, Object?> payload, String key) {
    final value = _requiredValue(payload, key);
    if (value == null) return null;
    if (value is! int) {
      throw FormatException('$key 必须是整数或 null');
    }
    return value;
  }

  static bool _requiredBoolean(Map<String, Object?> payload, String key) {
    final value = _requiredValue(payload, key);
    if (value is! bool) {
      throw FormatException('$key 必须是布尔值');
    }
    return value;
  }

  static List<Object?> _requiredList(Map<String, Object?> payload, String key) {
    final value = _requiredValue(payload, key);
    if (value is! List<Object?>) {
      throw FormatException('$key 必须是数组');
    }
    return value;
  }

  static List<String> _requiredStringList(
    Map<String, Object?> payload,
    String key,
  ) {
    final values = _requiredList(payload, key);
    final result = <String>[];
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value is! String) {
        throw FormatException('$key[$index] 必须是字符串');
      }
      result.add(value);
    }
    return result;
  }

  static DateTime _requiredDateTime(Map<String, Object?> payload, String key) {
    final raw = _requiredString(payload, key);
    final value = DateTime.tryParse(raw);
    if (value == null) {
      throw FormatException('$key 必须是 ISO 8601 时间');
    }
    return value;
  }

  static DateTime? _nullableDateTime(Map<String, Object?> payload, String key) {
    final raw = _nullableString(payload, key);
    if (raw == null) return null;
    final value = DateTime.tryParse(raw);
    if (value == null) {
      throw FormatException('$key 必须是 ISO 8601 时间或 null');
    }
    return value;
  }

  static String _encodeDateTime(DateTime value) {
    return value.toUtc().toIso8601String();
  }

  static String? _encodeNullableDateTime(DateTime? value) {
    return value == null ? null : _encodeDateTime(value);
  }
}
