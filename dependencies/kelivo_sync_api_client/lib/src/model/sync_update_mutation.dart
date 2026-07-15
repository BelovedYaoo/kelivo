//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/sync_patch_operation.dart';
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/sync_entity_type.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_update_mutation.g.dart';

/// SyncUpdateMutation
///
/// Properties:
/// * [mutationId]
/// * [entityType]
/// * [entityId]
/// * [operation]
/// * [baseRevision]
/// * [schemaVersion]
/// * [patch_]
@BuiltValue()
abstract class SyncUpdateMutation
    implements Built<SyncUpdateMutation, SyncUpdateMutationBuilder> {
  @BuiltValueField(wireName: r'mutationId')
  String get mutationId;

  @BuiltValueField(wireName: r'entityType')
  SyncEntityType get entityType;
  // enum entityTypeEnum {  conversation,  turn,  message,  message-selection,  tool-event,  thought-signature,  provider,  assistant,  memory,  world-book,  quick-phrase,  search-service,  network-tts,  mcp-server,  user-preference,  };

  @BuiltValueField(wireName: r'entityId')
  String get entityId;

  @BuiltValueField(wireName: r'operation')
  SyncUpdateMutationOperationEnum get operation;
  // enum operationEnum {  update,  };

  @BuiltValueField(wireName: r'baseRevision')
  int get baseRevision;

  @BuiltValueField(wireName: r'schemaVersion')
  int? get schemaVersion;

  @BuiltValueField(wireName: r'patch')
  BuiltList<SyncPatchOperation> get patch_;

  SyncUpdateMutation._();

  factory SyncUpdateMutation([void updates(SyncUpdateMutationBuilder b)]) =
      _$SyncUpdateMutation;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncUpdateMutationBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncUpdateMutation> get serializer =>
      _$SyncUpdateMutationSerializer();
}

class _$SyncUpdateMutationSerializer
    implements PrimitiveSerializer<SyncUpdateMutation> {
  @override
  final Iterable<Type> types = const [SyncUpdateMutation, _$SyncUpdateMutation];

  @override
  final String wireName = r'SyncUpdateMutation';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncUpdateMutation object, {
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
      specifiedType: const FullType(SyncUpdateMutationOperationEnum),
    );
    yield r'baseRevision';
    yield serializers.serialize(
      object.baseRevision,
      specifiedType: const FullType(int),
    );
    if (object.schemaVersion != null) {
      yield r'schemaVersion';
      yield serializers.serialize(
        object.schemaVersion,
        specifiedType: const FullType(int),
      );
    }
    yield r'patch';
    yield serializers.serialize(
      object.patch_,
      specifiedType: const FullType(BuiltList, [FullType(SyncPatchOperation)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncUpdateMutation object, {
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
    required SyncUpdateMutationBuilder result,
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
                      SyncUpdateMutationOperationEnum,
                    ),
                  )
                  as SyncUpdateMutationOperationEnum;
          result.operation = valueDes;
          break;
        case r'baseRevision':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.baseRevision = valueDes;
          break;
        case r'schemaVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.schemaVersion = valueDes;
          break;
        case r'patch':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(BuiltList, [
                      FullType(SyncPatchOperation),
                    ]),
                  )
                  as BuiltList<SyncPatchOperation>;
          result.patch_.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncUpdateMutation deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncUpdateMutationBuilder();
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

class SyncUpdateMutationOperationEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'update')
  static const SyncUpdateMutationOperationEnum update =
      _$syncUpdateMutationOperationEnum_update;

  static Serializer<SyncUpdateMutationOperationEnum> get serializer =>
      _$syncUpdateMutationOperationEnumSerializer;

  const SyncUpdateMutationOperationEnum._(String name) : super(name);

  static BuiltSet<SyncUpdateMutationOperationEnum> get values =>
      _$syncUpdateMutationOperationEnumValues;
  static SyncUpdateMutationOperationEnum valueOf(String name) =>
      _$syncUpdateMutationOperationEnumValueOf(name);
}
