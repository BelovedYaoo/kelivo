import 'cloud_sync_types.dart';

enum CloudSyncConflictEntityCategory {
  conversation,
  turn,
  message,
  messageSelection,
  toolEvent,
  thoughtSignature,
  provider,
  assistant,
  memory,
  worldBook,
  quickPhrase,
  searchService,
  networkTts,
  mcpServer,
  instructionInjection,
  userPreference,
}

enum CloudSyncConflictFieldCategory {
  title,
  content,
  summary,
  name,
  status,
  time,
  settings,
  security,
  reference,
  attachments,
  selection,
  other,
}

enum CloudSyncHiddenValueState { set, missing }

sealed class CloudSyncConflictValueDescriptor {
  const CloudSyncConflictValueDescriptor();
}

final class CloudSyncAbsentValueDescriptor
    extends CloudSyncConflictValueDescriptor {
  const CloudSyncAbsentValueDescriptor();
}

final class CloudSyncNullValueDescriptor
    extends CloudSyncConflictValueDescriptor {
  const CloudSyncNullValueDescriptor();
}

final class CloudSyncHiddenValueDescriptor
    extends CloudSyncConflictValueDescriptor {
  const CloudSyncHiddenValueDescriptor(this.state);

  final CloudSyncHiddenValueState state;
}

final class CloudSyncReferenceValueDescriptor
    extends CloudSyncConflictValueDescriptor {
  const CloudSyncReferenceValueDescriptor();
}

final class CloudSyncItemCountValueDescriptor
    extends CloudSyncConflictValueDescriptor {
  const CloudSyncItemCountValueDescriptor(this.itemCount);

  final int itemCount;
}

final class CloudSyncBooleanValueDescriptor
    extends CloudSyncConflictValueDescriptor {
  const CloudSyncBooleanValueDescriptor(this.value);

  final bool value;
}

final class CloudSyncNumberValueDescriptor
    extends CloudSyncConflictValueDescriptor {
  const CloudSyncNumberValueDescriptor(this.value);

  final num value;
}

final class CloudSyncTextValueDescriptor
    extends CloudSyncConflictValueDescriptor {
  const CloudSyncTextValueDescriptor(this.value);

  final String value;
}

final class CloudSyncConflictFieldDescriptor {
  const CloudSyncConflictFieldDescriptor({
    required this.category,
    required this.current,
    required this.desired,
  });

  final CloudSyncConflictFieldCategory category;
  final CloudSyncConflictValueDescriptor current;
  final CloudSyncConflictValueDescriptor desired;
}

final class CloudSyncConflictPresentationDescriptor {
  CloudSyncConflictPresentationDescriptor({
    required this.entityCategory,
    required List<CloudSyncConflictFieldDescriptor> fields,
  }) : fields = List<CloudSyncConflictFieldDescriptor>.unmodifiable(fields);

  final CloudSyncConflictEntityCategory entityCategory;
  final List<CloudSyncConflictFieldDescriptor> fields;
}

CloudSyncConflictPresentationDescriptor describeCloudSyncConflict(
  CloudSyncConflict conflict,
) {
  return CloudSyncConflictPresentationDescriptor(
    entityCategory: _entityCategory(conflict.entityType),
    fields: conflict.fields
        .map(describeCloudSyncConflictField)
        .toList(growable: false),
  );
}

CloudSyncConflictFieldDescriptor describeCloudSyncConflictField(
  CloudSyncConflictField field,
) {
  final token = _decodeSimpleTopLevelJsonPointer(field.path);
  final sensitive = _containsSensitiveKeyword(field.path);
  final reference = _containsReferenceMarker(field.path);
  // 无法确认字段语义时隐藏标量值，避免畸形路径绕过敏感字段保护。
  final hideValue = sensitive || token == null;
  return CloudSyncConflictFieldDescriptor(
    category: _fieldCategory(
      token: token,
      sensitive: sensitive,
      reference: reference,
    ),
    current: _valueDescriptor(
      field.current,
      hidden: hideValue,
      reference: reference,
    ),
    desired: _valueDescriptor(
      field.desired,
      hidden: hideValue,
      reference: reference,
    ),
  );
}

CloudSyncConflictEntityCategory _entityCategory(
  CloudSyncEntityType entityType,
) {
  // 穷尽映射让新增同步实体在编译期显式补齐展示语义。
  return switch (entityType) {
    CloudSyncEntityType.conversation =>
      CloudSyncConflictEntityCategory.conversation,
    CloudSyncEntityType.turn => CloudSyncConflictEntityCategory.turn,
    CloudSyncEntityType.message => CloudSyncConflictEntityCategory.message,
    CloudSyncEntityType.messageSelection =>
      CloudSyncConflictEntityCategory.messageSelection,
    CloudSyncEntityType.toolEvent => CloudSyncConflictEntityCategory.toolEvent,
    CloudSyncEntityType.thoughtSignature =>
      CloudSyncConflictEntityCategory.thoughtSignature,
    CloudSyncEntityType.provider => CloudSyncConflictEntityCategory.provider,
    CloudSyncEntityType.assistant => CloudSyncConflictEntityCategory.assistant,
    CloudSyncEntityType.memory => CloudSyncConflictEntityCategory.memory,
    CloudSyncEntityType.worldBook => CloudSyncConflictEntityCategory.worldBook,
    CloudSyncEntityType.quickPhrase =>
      CloudSyncConflictEntityCategory.quickPhrase,
    CloudSyncEntityType.searchService =>
      CloudSyncConflictEntityCategory.searchService,
    CloudSyncEntityType.networkTts =>
      CloudSyncConflictEntityCategory.networkTts,
    CloudSyncEntityType.mcpServer => CloudSyncConflictEntityCategory.mcpServer,
    CloudSyncEntityType.instructionInjection =>
      CloudSyncConflictEntityCategory.instructionInjection,
    CloudSyncEntityType.userPreference =>
      CloudSyncConflictEntityCategory.userPreference,
  };
}

CloudSyncConflictFieldCategory _fieldCategory({
  required String? token,
  required bool sensitive,
  required bool reference,
}) {
  if (token == null) return CloudSyncConflictFieldCategory.other;
  final words = _identifierWords(token);
  final compact = words.join();

  if (sensitive) return CloudSyncConflictFieldCategory.security;
  if (_containsAny(words, const <String>{
    'attachment',
    'attachments',
    'file',
  })) {
    return CloudSyncConflictFieldCategory.attachments;
  }
  if (_containsAny(words, const <String>{
    'selection',
    'selected',
    'choice',
    'choices',
  })) {
    return CloudSyncConflictFieldCategory.selection;
  }
  if (reference) return CloudSyncConflictFieldCategory.reference;
  if (_matchesAny(compact, const <String>{'title', 'subject'})) {
    return CloudSyncConflictFieldCategory.title;
  }
  if (_matchesAny(compact, const <String>{
    'content',
    'body',
    'text',
    'prompt',
    'message',
  })) {
    return CloudSyncConflictFieldCategory.content;
  }
  if (_matchesAny(compact, const <String>{
    'summary',
    'description',
    'preview',
  })) {
    return CloudSyncConflictFieldCategory.summary;
  }
  if (_containsAny(words, const <String>{'name', 'nickname', 'label'})) {
    return CloudSyncConflictFieldCategory.name;
  }
  if (_containsAny(words, const <String>{
    'status',
    'state',
    'enabled',
    'active',
    'archived',
    'pinned',
  })) {
    return CloudSyncConflictFieldCategory.status;
  }
  if (_isTimeField(words, compact)) {
    return CloudSyncConflictFieldCategory.time;
  }
  if (_containsAny(words, const <String>{
    'setting',
    'settings',
    'config',
    'configuration',
    'option',
    'options',
    'preference',
    'preferences',
    'model',
    'temperature',
  })) {
    return CloudSyncConflictFieldCategory.settings;
  }
  return CloudSyncConflictFieldCategory.other;
}

CloudSyncConflictValueDescriptor _valueDescriptor(
  CloudSyncConflictFieldState state, {
  required bool hidden,
  required bool reference,
}) {
  if (hidden) {
    return CloudSyncHiddenValueDescriptor(
      state.exists && state.value != null
          ? CloudSyncHiddenValueState.set
          : CloudSyncHiddenValueState.missing,
    );
  }
  if (!state.exists) return const CloudSyncAbsentValueDescriptor();
  final value = state.value;
  if (value == null) return const CloudSyncNullValueDescriptor();
  if (value is List<Object?>) {
    return CloudSyncItemCountValueDescriptor(value.length);
  }
  if (value is Map<Object?, Object?>) {
    return CloudSyncItemCountValueDescriptor(value.length);
  }
  if (reference) return const CloudSyncReferenceValueDescriptor();
  if (value is bool) return CloudSyncBooleanValueDescriptor(value);
  if (value is num) return CloudSyncNumberValueDescriptor(value);
  if (value is String) return CloudSyncTextValueDescriptor(value);
  throw StateError('冲突字段包含不支持的 JSON 值');
}

String? _decodeSimpleTopLevelJsonPointer(String path) {
  if (!path.startsWith('/') || path.length == 1 || path.indexOf('/', 1) >= 0) {
    return null;
  }
  final encoded = path.substring(1);
  final buffer = StringBuffer();
  for (var index = 0; index < encoded.length; index++) {
    final character = encoded[index];
    if (character != '~') {
      buffer.write(character);
      continue;
    }
    if (index + 1 >= encoded.length) return null;
    final escape = encoded[++index];
    if (escape == '0') {
      buffer.write('~');
    } else if (escape == '1') {
      buffer.write('/');
    } else {
      return null;
    }
  }
  final decoded = buffer.toString();
  if (decoded.isEmpty || decoded.contains('/')) return null;
  return decoded;
}

bool _containsSensitiveKeyword(String value) {
  final words = _identifierWords(value);
  const sensitiveWords = <String>{
    'key',
    'keys',
    'token',
    'tokens',
    'secret',
    'secrets',
    'password',
    'passwords',
    'authorization',
    'authorizations',
    'header',
    'headers',
    'credential',
    'credentials',
    'signature',
    'signatures',
  };
  if (_containsAny(words, sensitiveWords)) return true;
  final compact = words.join();
  // 全大写或历史扁平命名无法可靠分词，安全边界优先选择过度隐藏。
  return sensitiveWords.any(
    (keyword) => compact == keyword || compact.endsWith(keyword),
  );
}

bool _containsReferenceMarker(String value) {
  final words = _identifierWords(value);
  if (_containsAny(words, const <String>{'id', 'ids'})) return true;
  final token = value.split('/').last;
  return RegExp(r'(?:Id|ID|Ids|IDs)$').hasMatch(token);
}

List<String> _identifierWords(String value) {
  final separatedAcronyms = value.replaceAllMapped(
    RegExp(r'([A-Z]+)([A-Z][a-z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  final separatedCamelCase = separatedAcronyms.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  return separatedCamelCase
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word.toLowerCase())
      .toList(growable: false);
}

bool _containsAny(List<String> words, Set<String> candidates) {
  return words.any(candidates.contains);
}

bool _matchesAny(String value, Set<String> candidates) {
  return candidates.contains(value);
}

bool _isTimeField(List<String> words, String compact) {
  if (_containsAny(words, const <String>{
    'time',
    'timestamp',
    'date',
    'duration',
  })) {
    return true;
  }
  return const <String>{
    'createdat',
    'updatedat',
    'deletedat',
    'resolvedat',
    'sentat',
    'receivedat',
    'modifiedat',
  }.contains(compact);
}
