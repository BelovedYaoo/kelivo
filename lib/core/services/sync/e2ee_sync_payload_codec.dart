import 'dart:convert';
import 'dart:typed_data';

import 'config_sync_keys.dart';
import 'e2ee_config_sync_payload_schema.dart';
import 'sync_codec.dart';

const e2eeSyncPayloadFormatVersion = 3;
const e2eeSyncMaximumMessageAttachmentCount = 32;
const _maximumPositiveInt63 = 0x7fffffffffffffff;
const _minimumSignedInt64 = -0x8000000000000000;
// 解密内容不可信，限制嵌套层数可避免恶意载荷耗尽客户端调用栈。
const _maximumJsonNestingDepth = 64;

abstract final class E2eeSyncChatRecordTypes {
  static const conversation = 'conversation';
  static const turn = 'turn';
  static const message = 'message';
  static const messageSelection = 'message-selection';
  static const toolEvent = 'tool-event';
  static const thoughtSignature = 'thought-signature';

  static const values = <String>{
    conversation,
    turn,
    message,
    messageSelection,
    toolEvent,
    thoughtSignature,
  };
}

/// 记录必须先通过实体专属 schema，再进入可逐字节比较的明文信封。
abstract final class E2eeSyncPayloadCodec {
  static void validateEntityKey(SyncEntityKey entityKey) {
    if (E2eeSyncChatRecordTypes.values.contains(entityKey.entityType)) {
      _validateChatEntityKey(entityKey);
      return;
    }
    ConfigSyncKeys.validate(entityKey);
  }

  static Uint8List encode({
    required SyncEntityKey entityKey,
    required Map<String, Object?> payload,
  }) {
    validateEntityKey(entityKey);
    _rejectOversizedMessageAttachmentsBeforeFreeze(entityKey, payload);
    final frozenPayload = _freezeJsonValue(payload);
    if (frozenPayload is! Map<String, Object?>) {
      throw const FormatException('E2EE 同步 payload 必须为对象');
    }
    _validatePayload(entityKey, frozenPayload);
    final output = StringBuffer();
    _writeCanonicalJson(output, <String, Object?>{
      'payload': frozenPayload,
      'recordType': entityKey.entityType,
      'version': e2eeSyncPayloadFormatVersion,
    });
    return Uint8List.fromList(utf8.encode(output.toString()));
  }

  static Map<String, Object?> decode({
    required SyncEntityKey entityKey,
    required Uint8List bytes,
  }) {
    validateEntityKey(entityKey);
    final String source;
    try {
      source = utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      throw const FormatException('E2EE 同步 payload 包含无效 UTF-8');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FormatException('E2EE 同步 payload 不是合法 JSON');
    }
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException('E2EE 同步 payload 信封必须为对象');
    }
    if (decoded.length != 3 ||
        !decoded.containsKey('payload') ||
        !decoded.containsKey('recordType') ||
        !decoded.containsKey('version')) {
      throw const FormatException('E2EE 同步 payload 信封字段无效');
    }
    for (final key in decoded.keys) {
      if (key != 'payload' && key != 'recordType' && key != 'version') {
        throw const FormatException('E2EE 同步 payload 信封包含未知字段');
      }
    }
    final version = decoded['version'];
    if (version is! int || version != e2eeSyncPayloadFormatVersion) {
      throw const FormatException('E2EE 同步 payload 信封版本无效');
    }
    if (decoded['recordType'] != entityKey.entityType) {
      throw const FormatException('E2EE 同步 payload recordType 与记录身份不一致');
    }

    final rawPayload = decoded['payload'];
    _rejectOversizedMessageAttachmentsBeforeFreeze(entityKey, rawPayload);
    final payload = _freezeJsonValue(rawPayload);
    if (payload is! Map<String, Object?>) {
      throw const FormatException('E2EE 同步 payload 必须为对象');
    }
    _validatePayload(entityKey, payload);
    final canonical = encode(entityKey: entityKey, payload: payload);
    if (!_sameBytes(bytes, canonical)) {
      throw const FormatException('E2EE 同步 payload 不是规范 JSON');
    }
    return payload;
  }
}

void _validatePayload(SyncEntityKey entityKey, Map<String, Object?> payload) {
  if (E2eeSyncChatRecordTypes.values.contains(entityKey.entityType)) {
    _validateChatPayload(entityKey, payload);
    return;
  }
  E2eeConfigSyncPayloadSchema.validate(entityKey, payload);
}

const _conversationKeys = <String>{
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
const _turnKeys = <String>{'conversationId', 'createdAt'};
const _messageKeys = <String>{
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
const _attachmentKeys = <String>{
  'attachmentId',
  'uploadId',
  'chunkKeyEpoch',
  'manifestKeyEpoch',
  'manifestRevision',
  'kind',
  'order',
};
const _messageSelectionKeys = <String>{
  'conversationId',
  'groupId',
  'selectedVersion',
};
const _toolEventKeys = <String>{'messageId', 'events'};
const _thoughtSignatureKeys = <String>{'messageId', 'signature'};
final _canonicalUuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void _validateChatEntityKey(SyncEntityKey entityKey) {
  validateSyncEntityKey(entityKey);
  _requireIdentifier(entityKey.entityId, 'entityId');
  if (!E2eeSyncChatRecordTypes.values.contains(entityKey.entityType)) {
    throw FormatException('E2EE 同步不支持记录类型：${entityKey.entityType}');
  }
}

void _validateChatPayload(
  SyncEntityKey entityKey,
  Map<String, Object?> payload,
) {
  switch (entityKey.entityType) {
    case E2eeSyncChatRecordTypes.conversation:
      _validateConversation(payload);
    case E2eeSyncChatRecordTypes.turn:
      _validateTurn(payload);
    case E2eeSyncChatRecordTypes.message:
      _validateMessage(payload);
    case E2eeSyncChatRecordTypes.messageSelection:
      _validateMessageSelection(entityKey.entityId, payload);
    case E2eeSyncChatRecordTypes.toolEvent:
      _validateToolEvent(entityKey.entityId, payload);
    case E2eeSyncChatRecordTypes.thoughtSignature:
      _validateThoughtSignature(entityKey.entityId, payload);
    default:
      throw FormatException('E2EE 同步不支持记录类型：${entityKey.entityType}');
  }
}

void _validateConversation(Map<String, Object?> payload) {
  _expectExactKeys(payload, _conversationKeys, 'conversation');
  _requiredString(payload, 'title', allowEmpty: true);
  _requiredCanonicalUtcDateTime(payload, 'createdAt');
  _requiredCanonicalUtcDateTime(payload, 'updatedAt');
  _requiredBoolean(payload, 'isPinned');
  final assistantId = _nullableString(payload, 'assistantId');
  if (assistantId != null) _requireIdentifier(assistantId, 'assistantId');
  _requiredIdentifierList(payload, 'mcpServerIds');
  final truncateIndex = _requiredInteger(payload, 'truncateIndex');
  if (truncateIndex < -1 || truncateIndex > _maximumPositiveInt63) {
    throw const FormatException('conversation.truncateIndex 超出范围');
  }
  _nullableString(payload, 'summary');
  _requiredNonNegativeInteger(payload, 'lastSummarizedMessageCount');
  _requiredStringList(payload, 'chatSuggestions');
}

void _validateTurn(Map<String, Object?> payload) {
  _expectExactKeys(payload, _turnKeys, 'turn');
  _requiredIdentifier(payload, 'conversationId');
  _requiredCanonicalUtcDateTime(payload, 'createdAt');
}

void _validateMessage(Map<String, Object?> payload) {
  _expectExactKeys(payload, _messageKeys, 'message');
  _requiredIdentifier(payload, 'conversationId');
  _requiredIdentifier(payload, 'turnId');
  final role = _requiredString(payload, 'role');
  if (role != 'user' && role != 'assistant') {
    throw const FormatException('message.role 无效');
  }
  _requiredString(payload, 'content', allowEmpty: true);
  _validateAttachments(_requiredList(payload, 'attachments'));
  _requiredCanonicalUtcDateTime(payload, 'timestamp');
  _requiredIdentifier(payload, 'groupId');
  _requiredNonNegativeInteger(payload, 'version');
  final status = _requiredString(payload, 'status');
  if (status != 'completed' && status != 'interrupted' && status != 'failed') {
    throw const FormatException('message.status 不是可同步终态');
  }
  for (final key in const <String>[
    'modelId',
    'providerId',
    'reasoningText',
    'reasoningSegmentsJson',
    'translation',
  ]) {
    _nullableString(payload, key);
  }
  _nullableCanonicalUtcDateTime(payload, 'reasoningStartAt');
  _nullableCanonicalUtcDateTime(payload, 'reasoningFinishedAt');
  for (final key in const <String>[
    'totalTokens',
    'promptTokens',
    'completionTokens',
    'cachedTokens',
    'durationMs',
  ]) {
    _nullableNonNegativeInteger(payload, key);
  }
}

void _validateAttachments(List<Object?> attachments) {
  _requireMessageAttachmentCountWithinLimit(attachments);
  final attachmentIds = <String>{};
  final uploadIds = <String>{};
  for (var index = 0; index < attachments.length; index++) {
    final attachment = attachments[index];
    if (attachment is! Map<String, Object?>) {
      throw FormatException('message.attachments[$index] 必须为对象');
    }
    _expectExactKeys(
      attachment,
      _attachmentKeys,
      'message.attachments[$index]',
    );
    final attachmentId = _requiredString(attachment, 'attachmentId');
    if (!_canonicalUuidV4Pattern.hasMatch(attachmentId) ||
        !attachmentIds.add(attachmentId)) {
      throw FormatException('message.attachments[$index].attachmentId 无效或重复');
    }
    final uploadId = _requiredString(attachment, 'uploadId');
    if (!_canonicalUuidV4Pattern.hasMatch(uploadId) ||
        !uploadIds.add(uploadId)) {
      throw FormatException('message.attachments[$index].uploadId 无效或重复');
    }
    final chunkKeyEpoch = _requiredInteger(attachment, 'chunkKeyEpoch');
    final manifestKeyEpoch = _requiredInteger(attachment, 'manifestKeyEpoch');
    final manifestRevision = _requiredInteger(attachment, 'manifestRevision');
    if (chunkKeyEpoch < 1 || chunkKeyEpoch > 0xffffffff) {
      throw FormatException(
        'message.attachments[$index].chunkKeyEpoch 超出正 uint32 范围',
      );
    }
    if (manifestKeyEpoch < 1 || manifestKeyEpoch > 0xffffffff) {
      throw FormatException(
        'message.attachments[$index].manifestKeyEpoch 超出正 uint32 范围',
      );
    }
    if (manifestRevision < 1 || manifestRevision > 0xffffffff) {
      throw FormatException(
        'message.attachments[$index].manifestRevision 超出正 uint32 范围',
      );
    }
    if (manifestKeyEpoch - chunkKeyEpoch != manifestRevision - 1) {
      throw FormatException('message.attachments[$index] 代次与修订关系无效');
    }
    final kind = _requiredString(attachment, 'kind');
    if (kind != 'image' && kind != 'file') {
      throw FormatException('message.attachments[$index].kind 无效');
    }
    final order = _requiredNonNegativeInteger(attachment, 'order');
    if (order != index) {
      throw FormatException('message.attachments[$index].order 必须与数组顺序一致');
    }
  }
}

void _rejectOversizedMessageAttachmentsBeforeFreeze(
  SyncEntityKey entityKey,
  Object? payload,
) {
  if (entityKey.entityType != E2eeSyncChatRecordTypes.message ||
      payload is! Map<Object?, Object?>) {
    return;
  }
  final attachments = payload['attachments'];
  if (attachments is! List<Object?>) return;

  // 冻结会复制整棵对象图，先做长度门禁可避免为必然拒绝的附件再分配一份内存。
  _requireMessageAttachmentCountWithinLimit(attachments);
}

void _requireMessageAttachmentCountWithinLimit(List<Object?> attachments) {
  if (attachments.length > e2eeSyncMaximumMessageAttachmentCount) {
    throw FormatException(
      'message.attachments 数量不得超过 '
      '$e2eeSyncMaximumMessageAttachmentCount',
    );
  }
}

void _validateMessageSelection(String entityId, Map<String, Object?> payload) {
  _expectExactKeys(payload, _messageSelectionKeys, 'message-selection');
  _requiredIdentifier(payload, 'conversationId');
  final groupId = _requiredIdentifier(payload, 'groupId');
  if (groupId != entityId) {
    throw const FormatException('message-selection.groupId 与记录身份不一致');
  }
  _requiredNonNegativeInteger(payload, 'selectedVersion');
}

void _validateToolEvent(String entityId, Map<String, Object?> payload) {
  _expectExactKeys(payload, _toolEventKeys, 'tool-event');
  final messageId = _requiredIdentifier(payload, 'messageId');
  if (messageId != entityId) {
    throw const FormatException('tool-event.messageId 与记录身份不一致');
  }
  final events = _requiredList(payload, 'events');
  for (var index = 0; index < events.length; index++) {
    if (events[index] is! Map<String, Object?>) {
      throw FormatException('tool-event.events[$index] 必须为对象');
    }
  }
}

void _validateThoughtSignature(String entityId, Map<String, Object?> payload) {
  _expectExactKeys(payload, _thoughtSignatureKeys, 'thought-signature');
  final messageId = _requiredIdentifier(payload, 'messageId');
  if (messageId != entityId) {
    throw const FormatException('thought-signature.messageId 与记录身份不一致');
  }
  _requiredString(payload, 'signature');
}

void _expectExactKeys(
  Map<String, Object?> payload,
  Set<String> expected,
  String context,
) {
  if (payload.length == expected.length &&
      expected.every(payload.containsKey)) {
    return;
  }
  throw FormatException('$context 字段不匹配');
}

Object? _requiredValue(Map<String, Object?> payload, String key) {
  if (!payload.containsKey(key)) throw FormatException('缺少字段：$key');
  return payload[key];
}

String _requiredString(
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

String? _nullableString(Map<String, Object?> payload, String key) {
  final value = _requiredValue(payload, key);
  if (value == null) return null;
  if (value is! String) throw FormatException('$key 必须是字符串或 null');
  return value;
}

String _requiredIdentifier(Map<String, Object?> payload, String key) {
  final value = _requiredString(payload, key);
  _requireIdentifier(value, key);
  return value;
}

void _requireIdentifier(String value, String context) {
  if (value.trim().isEmpty) throw FormatException('$context 不能为空');
  try {
    validateSyncEntityKey(
      SyncEntityKey(entityType: 'record-id', entityId: value),
    );
  } on FormatException {
    throw FormatException('$context 不是合法同步实体 ID');
  }
}

int _requiredInteger(Map<String, Object?> payload, String key) {
  final value = _requiredValue(payload, key);
  if (value is! int) throw FormatException('$key 必须是整数');
  return value;
}

int _requiredNonNegativeInteger(Map<String, Object?> payload, String key) {
  final value = _requiredInteger(payload, key);
  if (value < 0 || value > _maximumPositiveInt63) {
    throw FormatException('$key 超出非负 int63 范围');
  }
  return value;
}

void _nullableNonNegativeInteger(Map<String, Object?> payload, String key) {
  final value = _requiredValue(payload, key);
  if (value == null) return;
  if (value is! int || value < 0 || value > _maximumPositiveInt63) {
    throw FormatException('$key 必须是非负 int63 或 null');
  }
}

bool _requiredBoolean(Map<String, Object?> payload, String key) {
  final value = _requiredValue(payload, key);
  if (value is! bool) throw FormatException('$key 必须是布尔值');
  return value;
}

List<Object?> _requiredList(Map<String, Object?> payload, String key) {
  final value = _requiredValue(payload, key);
  if (value is! List<Object?>) throw FormatException('$key 必须是数组');
  return value;
}

void _requiredStringList(Map<String, Object?> payload, String key) {
  final values = _requiredList(payload, key);
  for (var index = 0; index < values.length; index++) {
    if (values[index] is! String) {
      throw FormatException('$key[$index] 必须是字符串');
    }
  }
}

void _requiredIdentifierList(Map<String, Object?> payload, String key) {
  final values = _requiredList(payload, key);
  final unique = <String>{};
  for (var index = 0; index < values.length; index++) {
    final value = values[index];
    if (value is! String) throw FormatException('$key[$index] 必须是字符串');
    _requireIdentifier(value, '$key[$index]');
    if (!unique.add(value)) throw FormatException('$key[$index] 重复');
  }
}

void _requiredCanonicalUtcDateTime(Map<String, Object?> payload, String key) {
  _requireCanonicalUtcDateTime(_requiredString(payload, key), key);
}

void _nullableCanonicalUtcDateTime(Map<String, Object?> payload, String key) {
  final value = _nullableString(payload, key);
  if (value != null) _requireCanonicalUtcDateTime(value, key);
}

void _requireCanonicalUtcDateTime(String value, String context) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc || parsed.toIso8601String() != value) {
    throw FormatException('$context 必须是规范 UTC ISO 8601 时间');
  }
}

Object? _freezeJsonValue(Object? value, [int depth = 0]) {
  if (depth > _maximumJsonNestingDepth) {
    throw const FormatException('E2EE 同步 payload 嵌套层数超出限制');
  }
  if (value == null || value is bool) return value;
  if (value is int) {
    if (value < _minimumSignedInt64 || value > _maximumPositiveInt63) {
      throw const FormatException('E2EE 同步 payload 整数超出 int64 范围');
    }
    return value;
  }
  if (value is String) {
    _requireWellFormedUtf16(value);
    return value;
  }
  if (value is double) {
    if (!value.isFinite) {
      throw const FormatException('E2EE 同步 payload 数值必须为有限值');
    }
    return value;
  }
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(
      value.map((entry) => _freezeJsonValue(entry, depth + 1)),
    );
  }
  if (value is Map<Object?, Object?>) {
    final keys = <String>[];
    for (final key in value.keys) {
      if (key is! String) {
        throw const FormatException('E2EE 同步 payload 对象键必须为字符串');
      }
      _requireWellFormedUtf16(key);
      keys.add(key);
    }
    keys.sort();
    final result = <String, Object?>{};
    for (final key in keys) {
      result[key] = _freezeJsonValue(value[key], depth + 1);
    }
    return Map<String, Object?>.unmodifiable(result);
  }
  throw const FormatException('E2EE 同步 payload 包含非法类型');
}

void _writeCanonicalJson(StringBuffer output, Object? value) {
  if (value == null) {
    output.write('null');
    return;
  }
  if (value is bool || value is int || value is double || value is String) {
    output.write(jsonEncode(value));
    return;
  }
  if (value is List<Object?>) {
    output.write('[');
    for (var index = 0; index < value.length; index++) {
      if (index > 0) output.write(',');
      _writeCanonicalJson(output, value[index]);
    }
    output.write(']');
    return;
  }
  if (value is Map<String, Object?>) {
    output.write('{');
    var first = true;
    for (final entry in value.entries) {
      if (!first) output.write(',');
      first = false;
      output.write(jsonEncode(entry.key));
      output.write(':');
      _writeCanonicalJson(output, entry.value);
    }
    output.write('}');
    return;
  }
  throw StateError('规范 JSON 写入器收到了未经校验的值');
}

void _requireWellFormedUtf16(String value) {
  for (var index = 0; index < value.length; index++) {
    final codeUnit = value.codeUnitAt(index);
    if (codeUnit >= 0xd800 && codeUnit <= 0xdbff) {
      if (++index >= value.length) {
        throw const FormatException('E2EE 同步 payload 包含无效 Unicode');
      }
      final trailing = value.codeUnitAt(index);
      if (trailing < 0xdc00 || trailing > 0xdfff) {
        throw const FormatException('E2EE 同步 payload 包含无效 Unicode');
      }
    } else if (codeUnit >= 0xdc00 && codeUnit <= 0xdfff) {
      throw const FormatException('E2EE 同步 payload 包含无效 Unicode');
    }
  }
}

bool _sameBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
