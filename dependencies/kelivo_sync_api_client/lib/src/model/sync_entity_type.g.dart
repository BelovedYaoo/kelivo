// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_entity_type.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncEntityType _$conversation = const SyncEntityType._('conversation');
const SyncEntityType _$turn = const SyncEntityType._('turn');
const SyncEntityType _$message = const SyncEntityType._('message');
const SyncEntityType _$messageSelection = const SyncEntityType._(
  'messageSelection',
);
const SyncEntityType _$toolEvent = const SyncEntityType._('toolEvent');
const SyncEntityType _$thoughtSignature = const SyncEntityType._(
  'thoughtSignature',
);
const SyncEntityType _$provider = const SyncEntityType._('provider');
const SyncEntityType _$assistant = const SyncEntityType._('assistant');
const SyncEntityType _$memory = const SyncEntityType._('memory');
const SyncEntityType _$worldBook = const SyncEntityType._('worldBook');
const SyncEntityType _$quickPhrase = const SyncEntityType._('quickPhrase');
const SyncEntityType _$searchService = const SyncEntityType._('searchService');
const SyncEntityType _$networkTts = const SyncEntityType._('networkTts');
const SyncEntityType _$mcpServer = const SyncEntityType._('mcpServer');
const SyncEntityType _$instructionInjection = const SyncEntityType._(
  'instructionInjection',
);
const SyncEntityType _$userPreference = const SyncEntityType._(
  'userPreference',
);

SyncEntityType _$valueOf(String name) {
  switch (name) {
    case 'conversation':
      return _$conversation;
    case 'turn':
      return _$turn;
    case 'message':
      return _$message;
    case 'messageSelection':
      return _$messageSelection;
    case 'toolEvent':
      return _$toolEvent;
    case 'thoughtSignature':
      return _$thoughtSignature;
    case 'provider':
      return _$provider;
    case 'assistant':
      return _$assistant;
    case 'memory':
      return _$memory;
    case 'worldBook':
      return _$worldBook;
    case 'quickPhrase':
      return _$quickPhrase;
    case 'searchService':
      return _$searchService;
    case 'networkTts':
      return _$networkTts;
    case 'mcpServer':
      return _$mcpServer;
    case 'instructionInjection':
      return _$instructionInjection;
    case 'userPreference':
      return _$userPreference;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncEntityType> _$values =
    BuiltSet<SyncEntityType>(const <SyncEntityType>[
      _$conversation,
      _$turn,
      _$message,
      _$messageSelection,
      _$toolEvent,
      _$thoughtSignature,
      _$provider,
      _$assistant,
      _$memory,
      _$worldBook,
      _$quickPhrase,
      _$searchService,
      _$networkTts,
      _$mcpServer,
      _$instructionInjection,
      _$userPreference,
    ]);

class _$SyncEntityTypeMeta {
  const _$SyncEntityTypeMeta();
  SyncEntityType get conversation => _$conversation;
  SyncEntityType get turn => _$turn;
  SyncEntityType get message => _$message;
  SyncEntityType get messageSelection => _$messageSelection;
  SyncEntityType get toolEvent => _$toolEvent;
  SyncEntityType get thoughtSignature => _$thoughtSignature;
  SyncEntityType get provider => _$provider;
  SyncEntityType get assistant => _$assistant;
  SyncEntityType get memory => _$memory;
  SyncEntityType get worldBook => _$worldBook;
  SyncEntityType get quickPhrase => _$quickPhrase;
  SyncEntityType get searchService => _$searchService;
  SyncEntityType get networkTts => _$networkTts;
  SyncEntityType get mcpServer => _$mcpServer;
  SyncEntityType get instructionInjection => _$instructionInjection;
  SyncEntityType get userPreference => _$userPreference;
  SyncEntityType valueOf(String name) => _$valueOf(name);
  BuiltSet<SyncEntityType> get values => _$values;
}

mixin _$SyncEntityTypeMixin {
  // ignore: non_constant_identifier_names
  _$SyncEntityTypeMeta get SyncEntityType => const _$SyncEntityTypeMeta();
}

Serializer<SyncEntityType> _$syncEntityTypeSerializer =
    _$SyncEntityTypeSerializer();

class _$SyncEntityTypeSerializer
    implements PrimitiveSerializer<SyncEntityType> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'conversation': 'conversation',
    'turn': 'turn',
    'message': 'message',
    'messageSelection': 'message-selection',
    'toolEvent': 'tool-event',
    'thoughtSignature': 'thought-signature',
    'provider': 'provider',
    'assistant': 'assistant',
    'memory': 'memory',
    'worldBook': 'world-book',
    'quickPhrase': 'quick-phrase',
    'searchService': 'search-service',
    'networkTts': 'network-tts',
    'mcpServer': 'mcp-server',
    'instructionInjection': 'instruction-injection',
    'userPreference': 'user-preference',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'conversation': 'conversation',
    'turn': 'turn',
    'message': 'message',
    'message-selection': 'messageSelection',
    'tool-event': 'toolEvent',
    'thought-signature': 'thoughtSignature',
    'provider': 'provider',
    'assistant': 'assistant',
    'memory': 'memory',
    'world-book': 'worldBook',
    'quick-phrase': 'quickPhrase',
    'search-service': 'searchService',
    'network-tts': 'networkTts',
    'mcp-server': 'mcpServer',
    'instruction-injection': 'instructionInjection',
    'user-preference': 'userPreference',
  };

  @override
  final Iterable<Type> types = const <Type>[SyncEntityType];
  @override
  final String wireName = 'SyncEntityType';

  @override
  Object serialize(
    Serializers serializers,
    SyncEntityType object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncEntityType deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncEntityType.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
