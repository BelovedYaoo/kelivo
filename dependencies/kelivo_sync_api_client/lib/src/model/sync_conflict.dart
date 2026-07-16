//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/sync_conflict_details.dart';
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/sync_entity_type.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_conflict.g.dart';

/// SyncConflict
///
/// Properties:
/// * [conflictId]
/// * [mutationId]
/// * [entityType]
/// * [entityId]
/// * [details]
/// * [state]
/// * [createdAt]
/// * [resolvedAt]
@BuiltValue()
abstract class SyncConflict
    implements Built<SyncConflict, SyncConflictBuilder> {
  @BuiltValueField(wireName: r'conflictId')
  String get conflictId;

  @BuiltValueField(wireName: r'mutationId')
  String get mutationId;

  @BuiltValueField(wireName: r'entityType')
  SyncEntityType get entityType;
  // enum entityTypeEnum {  conversation,  turn,  message,  message-selection,  tool-event,  thought-signature,  provider,  assistant,  memory,  world-book,  quick-phrase,  search-service,  network-tts,  mcp-server,  instruction-injection,  user-preference,  };

  @BuiltValueField(wireName: r'entityId')
  String get entityId;

  @BuiltValueField(wireName: r'details')
  SyncConflictDetails get details;

  @BuiltValueField(wireName: r'state')
  SyncConflictStateEnum get state;
  // enum stateEnum {  open,  resolved,  };

  @BuiltValueField(wireName: r'createdAt')
  DateTime get createdAt;

  @BuiltValueField(wireName: r'resolvedAt')
  DateTime? get resolvedAt;

  SyncConflict._();

  factory SyncConflict([void updates(SyncConflictBuilder b)]) = _$SyncConflict;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncConflictBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncConflict> get serializer => _$SyncConflictSerializer();
}

class _$SyncConflictSerializer implements PrimitiveSerializer<SyncConflict> {
  @override
  final Iterable<Type> types = const [SyncConflict, _$SyncConflict];

  @override
  final String wireName = r'SyncConflict';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncConflict object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'conflictId';
    yield serializers.serialize(
      object.conflictId,
      specifiedType: const FullType(String),
    );
    yield r'mutationId';
    yield serializers.serialize(
      object.mutationId,
      specifiedType: const FullType(String),
    );
    yield r'entityType';
    yield serializers.serialize(
      object.entityType,
      specifiedType: const FullType(SyncEntityType),
    );
    yield r'entityId';
    yield serializers.serialize(
      object.entityId,
      specifiedType: const FullType(String),
    );
    yield r'details';
    yield serializers.serialize(
      object.details,
      specifiedType: const FullType(SyncConflictDetails),
    );
    yield r'state';
    yield serializers.serialize(
      object.state,
      specifiedType: const FullType(SyncConflictStateEnum),
    );
    yield r'createdAt';
    yield serializers.serialize(
      object.createdAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'resolvedAt';
    yield object.resolvedAt == null
        ? null
        : serializers.serialize(
            object.resolvedAt,
            specifiedType: const FullType.nullable(DateTime),
          );
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncConflict object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(
      serializers,
      object,
      specifiedType: specifiedType,
    ).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required SyncConflictBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'conflictId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.conflictId = valueDes;
          break;
        case r'mutationId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.mutationId = valueDes;
          break;
        case r'entityType':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(SyncEntityType),
                  )
                  as SyncEntityType;
          result.entityType = valueDes;
          break;
        case r'entityId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.entityId = valueDes;
          break;
        case r'details':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(SyncConflictDetails),
                  )
                  as SyncConflictDetails;
          result.details.replace(valueDes);
          break;
        case r'state':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(SyncConflictStateEnum),
                  )
                  as SyncConflictStateEnum;
          result.state = valueDes;
          break;
        case r'createdAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.createdAt = valueDes;
          break;
        case r'resolvedAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(DateTime),
                  )
                  as DateTime?;
          if (valueDes == null) continue;
          result.resolvedAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncConflict deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncConflictBuilder();
    final serializedList = (serialized as Iterable<Object?>).toList();
    final unhandled = <Object?>[];
    _deserializeProperties(
      serializers,
      serialized,
      specifiedType: specifiedType,
      serializedList: serializedList,
      unhandled: unhandled,
      result: result,
    );
    return result.build();
  }
}

class SyncConflictStateEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'open')
  static const SyncConflictStateEnum open = _$syncConflictStateEnum_open;
  @BuiltValueEnumConst(wireName: r'resolved')
  static const SyncConflictStateEnum resolved =
      _$syncConflictStateEnum_resolved;

  static Serializer<SyncConflictStateEnum> get serializer =>
      _$syncConflictStateEnumSerializer;

  const SyncConflictStateEnum._(String name) : super(name);

  static BuiltSet<SyncConflictStateEnum> get values =>
      _$syncConflictStateEnumValues;
  static SyncConflictStateEnum valueOf(String name) =>
      _$syncConflictStateEnumValueOf(name);
}
