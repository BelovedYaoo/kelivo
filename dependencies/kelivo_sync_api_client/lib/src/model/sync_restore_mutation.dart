//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/sync_entity_type.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_restore_mutation.g.dart';

/// SyncRestoreMutation
///
/// Properties:
/// * [mutationId]
/// * [entityType]
/// * [entityId]
/// * [operation]
/// * [baseRevision]
@BuiltValue()
abstract class SyncRestoreMutation
    implements Built<SyncRestoreMutation, SyncRestoreMutationBuilder> {
  @BuiltValueField(wireName: r'mutationId')
  String get mutationId;

  @BuiltValueField(wireName: r'entityType')
  SyncEntityType get entityType;
  // enum entityTypeEnum {  conversation,  turn,  message,  message-selection,  tool-event,  thought-signature,  provider,  assistant,  memory,  world-book,  quick-phrase,  search-service,  network-tts,  mcp-server,  instruction-injection,  user-preference,  };

  @BuiltValueField(wireName: r'entityId')
  String get entityId;

  @BuiltValueField(wireName: r'operation')
  SyncRestoreMutationOperationEnum get operation;
  // enum operationEnum {  restore,  };

  @BuiltValueField(wireName: r'baseRevision')
  int get baseRevision;

  SyncRestoreMutation._();

  factory SyncRestoreMutation([void updates(SyncRestoreMutationBuilder b)]) =
      _$SyncRestoreMutation;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncRestoreMutationBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncRestoreMutation> get serializer =>
      _$SyncRestoreMutationSerializer();
}

class _$SyncRestoreMutationSerializer
    implements PrimitiveSerializer<SyncRestoreMutation> {
  @override
  final Iterable<Type> types = const [
    SyncRestoreMutation,
    _$SyncRestoreMutation,
  ];

  @override
  final String wireName = r'SyncRestoreMutation';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncRestoreMutation object, {
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
      specifiedType: const FullType(SyncRestoreMutationOperationEnum),
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
    SyncRestoreMutation object, {
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
    required SyncRestoreMutationBuilder result,
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
                      SyncRestoreMutationOperationEnum,
                    ),
                  )
                  as SyncRestoreMutationOperationEnum;
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
  SyncRestoreMutation deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncRestoreMutationBuilder();
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

class SyncRestoreMutationOperationEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'restore')
  static const SyncRestoreMutationOperationEnum restore =
      _$syncRestoreMutationOperationEnum_restore;

  static Serializer<SyncRestoreMutationOperationEnum> get serializer =>
      _$syncRestoreMutationOperationEnumSerializer;

  const SyncRestoreMutationOperationEnum._(String name) : super(name);

  static BuiltSet<SyncRestoreMutationOperationEnum> get values =>
      _$syncRestoreMutationOperationEnumValues;
  static SyncRestoreMutationOperationEnum valueOf(String name) =>
      _$syncRestoreMutationOperationEnumValueOf(name);
}
