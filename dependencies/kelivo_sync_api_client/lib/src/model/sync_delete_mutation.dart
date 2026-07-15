//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/sync_entity_type.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_delete_mutation.g.dart';

/// SyncDeleteMutation
///
/// Properties:
/// * [mutationId]
/// * [entityType]
/// * [entityId]
/// * [operation]
/// * [baseRevision]
@BuiltValue()
abstract class SyncDeleteMutation
    implements Built<SyncDeleteMutation, SyncDeleteMutationBuilder> {
  @BuiltValueField(wireName: r'mutationId')
  String get mutationId;

  @BuiltValueField(wireName: r'entityType')
  SyncEntityType get entityType;
  // enum entityTypeEnum {  conversation,  turn,  message,  message-selection,  tool-event,  thought-signature,  provider,  assistant,  memory,  world-book,  quick-phrase,  search-service,  network-tts,  mcp-server,  user-preference,  };

  @BuiltValueField(wireName: r'entityId')
  String get entityId;

  @BuiltValueField(wireName: r'operation')
  SyncDeleteMutationOperationEnum get operation;
  // enum operationEnum {  delete,  };

  @BuiltValueField(wireName: r'baseRevision')
  int get baseRevision;

  SyncDeleteMutation._();

  factory SyncDeleteMutation([void updates(SyncDeleteMutationBuilder b)]) =
      _$SyncDeleteMutation;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncDeleteMutationBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncDeleteMutation> get serializer =>
      _$SyncDeleteMutationSerializer();
}

class _$SyncDeleteMutationSerializer
    implements PrimitiveSerializer<SyncDeleteMutation> {
  @override
  final Iterable<Type> types = const [SyncDeleteMutation, _$SyncDeleteMutation];

  @override
  final String wireName = r'SyncDeleteMutation';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncDeleteMutation object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
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
    yield r'operation';
    yield serializers.serialize(
      object.operation,
      specifiedType: const FullType(SyncDeleteMutationOperationEnum),
    );
    yield r'baseRevision';
    yield serializers.serialize(
      object.baseRevision,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncDeleteMutation object, {
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
    required SyncDeleteMutationBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
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
        case r'operation':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      SyncDeleteMutationOperationEnum,
                    ),
                  )
                  as SyncDeleteMutationOperationEnum;
          result.operation = valueDes;
          break;
        case r'baseRevision':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.baseRevision = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncDeleteMutation deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncDeleteMutationBuilder();
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

class SyncDeleteMutationOperationEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'delete')
  static const SyncDeleteMutationOperationEnum delete =
      _$syncDeleteMutationOperationEnum_delete;

  static Serializer<SyncDeleteMutationOperationEnum> get serializer =>
      _$syncDeleteMutationOperationEnumSerializer;

  const SyncDeleteMutationOperationEnum._(String name) : super(name);

  static BuiltSet<SyncDeleteMutationOperationEnum> get values =>
      _$syncDeleteMutationOperationEnumValues;
  static SyncDeleteMutationOperationEnum valueOf(String name) =>
      _$syncDeleteMutationOperationEnumValueOf(name);
}
