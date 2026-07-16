//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/sync_entity_type.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_create_mutation.g.dart';

/// SyncCreateMutation
///
/// Properties:
/// * [mutationId]
/// * [entityType]
/// * [entityId]
/// * [operation]
/// * [parentId]
/// * [schemaVersion]
/// * [payload]
@BuiltValue()
abstract class SyncCreateMutation
    implements Built<SyncCreateMutation, SyncCreateMutationBuilder> {
  @BuiltValueField(wireName: r'mutationId')
  String get mutationId;

  @BuiltValueField(wireName: r'entityType')
  SyncEntityType get entityType;
  // enum entityTypeEnum {  conversation,  turn,  message,  message-selection,  tool-event,  thought-signature,  provider,  assistant,  memory,  world-book,  quick-phrase,  search-service,  network-tts,  mcp-server,  instruction-injection,  user-preference,  };

  @BuiltValueField(wireName: r'entityId')
  String get entityId;

  @BuiltValueField(wireName: r'operation')
  SyncCreateMutationOperationEnum get operation;
  // enum operationEnum {  create,  };

  @BuiltValueField(wireName: r'parentId')
  String? get parentId;

  @BuiltValueField(wireName: r'schemaVersion')
  int get schemaVersion;

  @BuiltValueField(wireName: r'payload')
  BuiltMap<String, JsonObject?> get payload;

  SyncCreateMutation._();

  factory SyncCreateMutation([void updates(SyncCreateMutationBuilder b)]) =
      _$SyncCreateMutation;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncCreateMutationBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncCreateMutation> get serializer =>
      _$SyncCreateMutationSerializer();
}

class _$SyncCreateMutationSerializer
    implements PrimitiveSerializer<SyncCreateMutation> {
  @override
  final Iterable<Type> types = const [SyncCreateMutation, _$SyncCreateMutation];

  @override
  final String wireName = r'SyncCreateMutation';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncCreateMutation object, {
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
      specifiedType: const FullType(SyncCreateMutationOperationEnum),
    );
    if (object.parentId != null) {
      yield r'parentId';
      yield serializers.serialize(
        object.parentId,
        specifiedType: const FullType.nullable(String),
      );
    }
    yield r'schemaVersion';
    yield serializers.serialize(
      object.schemaVersion,
      specifiedType: const FullType(int),
    );
    yield r'payload';
    yield serializers.serialize(
      object.payload,
      specifiedType: const FullType(BuiltMap, [
        FullType(String),
        FullType.nullable(JsonObject),
      ]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncCreateMutation object, {
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
    required SyncCreateMutationBuilder result,
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
                      SyncCreateMutationOperationEnum,
                    ),
                  )
                  as SyncCreateMutationOperationEnum;
          result.operation = valueDes;
          break;
        case r'parentId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(String),
                  )
                  as String?;
          if (valueDes == null) continue;
          result.parentId = valueDes;
          break;
        case r'schemaVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.schemaVersion = valueDes;
          break;
        case r'payload':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(BuiltMap, [
                      FullType(String),
                      FullType.nullable(JsonObject),
                    ]),
                  )
                  as BuiltMap<String, JsonObject?>;
          result.payload.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncCreateMutation deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncCreateMutationBuilder();
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

class SyncCreateMutationOperationEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'create')
  static const SyncCreateMutationOperationEnum create =
      _$syncCreateMutationOperationEnum_create;

  static Serializer<SyncCreateMutationOperationEnum> get serializer =>
      _$syncCreateMutationOperationEnumSerializer;

  const SyncCreateMutationOperationEnum._(String name) : super(name);

  static BuiltSet<SyncCreateMutationOperationEnum> get values =>
      _$syncCreateMutationOperationEnumValues;
  static SyncCreateMutationOperationEnum valueOf(String name) =>
      _$syncCreateMutationOperationEnumValueOf(name);
}
