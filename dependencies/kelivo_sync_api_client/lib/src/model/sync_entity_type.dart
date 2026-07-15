//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_entity_type.g.dart';

class SyncEntityType extends EnumClass {
  @BuiltValueEnumConst(wireName: r'conversation')
  static const SyncEntityType conversation = _$conversation;
  @BuiltValueEnumConst(wireName: r'turn')
  static const SyncEntityType turn = _$turn;
  @BuiltValueEnumConst(wireName: r'message')
  static const SyncEntityType message = _$message;
  @BuiltValueEnumConst(wireName: r'message-selection')
  static const SyncEntityType messageSelection = _$messageSelection;
  @BuiltValueEnumConst(wireName: r'tool-event')
  static const SyncEntityType toolEvent = _$toolEvent;
  @BuiltValueEnumConst(wireName: r'thought-signature')
  static const SyncEntityType thoughtSignature = _$thoughtSignature;
  @BuiltValueEnumConst(wireName: r'provider')
  static const SyncEntityType provider = _$provider;
  @BuiltValueEnumConst(wireName: r'assistant')
  static const SyncEntityType assistant = _$assistant;
  @BuiltValueEnumConst(wireName: r'memory')
  static const SyncEntityType memory = _$memory;
  @BuiltValueEnumConst(wireName: r'world-book')
  static const SyncEntityType worldBook = _$worldBook;
  @BuiltValueEnumConst(wireName: r'quick-phrase')
  static const SyncEntityType quickPhrase = _$quickPhrase;
  @BuiltValueEnumConst(wireName: r'search-service')
  static const SyncEntityType searchService = _$searchService;
  @BuiltValueEnumConst(wireName: r'network-tts')
  static const SyncEntityType networkTts = _$networkTts;
  @BuiltValueEnumConst(wireName: r'mcp-server')
  static const SyncEntityType mcpServer = _$mcpServer;
  @BuiltValueEnumConst(wireName: r'user-preference')
  static const SyncEntityType userPreference = _$userPreference;

  static Serializer<SyncEntityType> get serializer =>
      _$syncEntityTypeSerializer;

  const SyncEntityType._(String name) : super(name);

  static BuiltSet<SyncEntityType> get values => _$values;
  static SyncEntityType valueOf(String name) => _$valueOf(name);
}

/// Optionally, enum_class can generate a mixin to go with your enum for use
/// with Angular. It exposes your enum constants as getters. So, if you mix it
/// in to your Dart component class, the values become available to the
/// corresponding Angular template.
///
/// Trigger mixin generation by writing a line like this one next to your enum.
abstract class SyncEntityTypeMixin = Object with _$SyncEntityTypeMixin;
