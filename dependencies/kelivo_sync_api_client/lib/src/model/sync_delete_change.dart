//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/sync_entity_type.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_delete_change.g.dart';

/// SyncDeleteChange
///
/// Properties:
/// * [changeSeq]
/// * [operation]
/// * [entityType]
/// * [entityId]
/// * [revision]
/// * [deletedAt]
@BuiltValue()
abstract class SyncDeleteChange
    implements Built<SyncDeleteChange, SyncDeleteChangeBuilder> {
  @BuiltValueField(wireName: r'changeSeq')
  int get changeSeq;

  @BuiltValueField(wireName: r'operation')
  SyncDeleteChangeOperationEnum get operation;
  // enum operationEnum {  delete,  };

  @BuiltValueField(wireName: r'entityType')
  SyncEntityType get entityType;
  // enum entityTypeEnum {  conversation,  turn,  message,  message-selection,  tool-event,  thought-signature,  provider,  assistant,  memory,  world-book,  quick-phrase,  search-service,  network-tts,  mcp-server,  instruction-injection,  user-preference,  };

  @BuiltValueField(wireName: r'entityId')
  String get entityId;

  @BuiltValueField(wireName: r'revision')
  int get revision;

  @BuiltValueField(wireName: r'deletedAt')
  DateTime get deletedAt;

  SyncDeleteChange._();

  factory SyncDeleteChange([void updates(SyncDeleteChangeBuilder b)]) =
      _$SyncDeleteChange;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncDeleteChangeBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncDeleteChange> get serializer =>
      _$SyncDeleteChangeSerializer();
}

class _$SyncDeleteChangeSerializer
    implements PrimitiveSerializer<SyncDeleteChange> {
  @override
  final Iterable<Type> types = const [SyncDeleteChange, _$SyncDeleteChange];

  @override
  final String wireName = r'SyncDeleteChange';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncDeleteChange object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'changeSeq';
    yield serializers.serialize(
      object.changeSeq,
      specifiedType: const FullType(int),
    );
    yield r'operation';
    yield serializers.serialize(
      object.operation,
      specifiedType: const FullType(SyncDeleteChangeOperationEnum),
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
    yield r'revision';
    yield serializers.serialize(
      object.revision,
      specifiedType: const FullType(int),
    );
    yield r'deletedAt';
    yield serializers.serialize(
      object.deletedAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncDeleteChange object, {
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
    required SyncDeleteChangeBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'changeSeq':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.changeSeq = valueDes;
          break;
        case r'operation':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      SyncDeleteChangeOperationEnum,
                    ),
                  )
                  as SyncDeleteChangeOperationEnum;
          result.operation = valueDes;
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
        case r'revision':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.revision = valueDes;
          break;
        case r'deletedAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.deletedAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncDeleteChange deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncDeleteChangeBuilder();
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

class SyncDeleteChangeOperationEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'delete')
  static const SyncDeleteChangeOperationEnum delete =
      _$syncDeleteChangeOperationEnum_delete;

  static Serializer<SyncDeleteChangeOperationEnum> get serializer =>
      _$syncDeleteChangeOperationEnumSerializer;

  const SyncDeleteChangeOperationEnum._(String name) : super(name);

  static BuiltSet<SyncDeleteChangeOperationEnum> get values =>
      _$syncDeleteChangeOperationEnumValues;
  static SyncDeleteChangeOperationEnum valueOf(String name) =>
      _$syncDeleteChangeOperationEnumValueOf(name);
}
