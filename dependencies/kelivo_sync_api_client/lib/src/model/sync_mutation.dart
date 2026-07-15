//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/sync_patch_operation.dart';
import 'package:kelivo_sync_api_client/src/model/sync_delete_mutation.dart';
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/sync_create_mutation.dart';
import 'package:kelivo_sync_api_client/src/model/sync_entity_type.dart';
import 'package:kelivo_sync_api_client/src/model/sync_restore_mutation.dart';
import 'package:built_value/json_object.dart';
import 'package:kelivo_sync_api_client/src/model/sync_update_mutation.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:one_of/one_of.dart';

part 'sync_mutation.g.dart';

/// SyncMutation
///
/// Properties:
/// * [mutationId]
/// * [entityType]
/// * [entityId]
/// * [operation]
/// * [parentId]
/// * [schemaVersion]
/// * [payload]
/// * [baseRevision]
/// * [patch_]
@BuiltValue()
abstract class SyncMutation
    implements Built<SyncMutation, SyncMutationBuilder> {
  /// One Of [SyncCreateMutation], [SyncDeleteMutation], [SyncRestoreMutation], [SyncUpdateMutation]
  OneOf get oneOf;

  static const String discriminatorFieldName = r'operation';

  static const Map<String, Type> discriminatorMapping = {
    r'create': SyncCreateMutation,
    r'delete': SyncDeleteMutation,
    r'restore': SyncRestoreMutation,
    r'update': SyncUpdateMutation,
  };

  SyncMutation._();

  factory SyncMutation([void updates(SyncMutationBuilder b)]) = _$SyncMutation;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncMutationBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncMutation> get serializer => _$SyncMutationSerializer();
}

extension SyncMutationDiscriminatorExt on SyncMutation {
  String? get discriminatorValue {
    if (this is SyncCreateMutation) {
      return r'create';
    }
    if (this is SyncDeleteMutation) {
      return r'delete';
    }
    if (this is SyncRestoreMutation) {
      return r'restore';
    }
    if (this is SyncUpdateMutation) {
      return r'update';
    }
    return null;
  }
}

extension SyncMutationBuilderDiscriminatorExt on SyncMutationBuilder {
  String? get discriminatorValue {
    if (this is SyncCreateMutationBuilder) {
      return r'create';
    }
    if (this is SyncDeleteMutationBuilder) {
      return r'delete';
    }
    if (this is SyncRestoreMutationBuilder) {
      return r'restore';
    }
    if (this is SyncUpdateMutationBuilder) {
      return r'update';
    }
    return null;
  }
}

class _$SyncMutationSerializer implements PrimitiveSerializer<SyncMutation> {
  @override
  final Iterable<Type> types = const [SyncMutation, _$SyncMutation];

  @override
  final String wireName = r'SyncMutation';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncMutation object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {}

  @override
  Object serialize(
    Serializers serializers,
    SyncMutation object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final oneOf = object.oneOf;
    return serializers.serialize(
      oneOf.value,
      specifiedType: FullType(oneOf.valueType),
    )!;
  }

  @override
  SyncMutation deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncMutationBuilder();
    Object? oneOfDataSrc;
    final serializedList = (serialized as Iterable<Object?>).toList();
    final discIndex =
        serializedList.indexOf(SyncMutation.discriminatorFieldName) + 1;
    final discValue =
        serializers.deserialize(
              serializedList[discIndex],
              specifiedType: FullType(String),
            )
            as String;
    oneOfDataSrc = serialized;
    final oneOfTypes = [
      SyncCreateMutation,
      SyncDeleteMutation,
      SyncRestoreMutation,
      SyncUpdateMutation,
    ];
    Object oneOfResult;
    Type oneOfType;
    switch (discValue) {
      case r'create':
        oneOfResult =
            serializers.deserialize(
                  oneOfDataSrc,
                  specifiedType: FullType(SyncCreateMutation),
                )
                as SyncCreateMutation;
        oneOfType = SyncCreateMutation;
        break;
      case r'delete':
        oneOfResult =
            serializers.deserialize(
                  oneOfDataSrc,
                  specifiedType: FullType(SyncDeleteMutation),
                )
                as SyncDeleteMutation;
        oneOfType = SyncDeleteMutation;
        break;
      case r'restore':
        oneOfResult =
            serializers.deserialize(
                  oneOfDataSrc,
                  specifiedType: FullType(SyncRestoreMutation),
                )
                as SyncRestoreMutation;
        oneOfType = SyncRestoreMutation;
        break;
      case r'update':
        oneOfResult =
            serializers.deserialize(
                  oneOfDataSrc,
                  specifiedType: FullType(SyncUpdateMutation),
                )
                as SyncUpdateMutation;
        oneOfType = SyncUpdateMutation;
        break;
      default:
        throw UnsupportedError(
          "Couldn't deserialize oneOf for the discriminator value: ${discValue}",
        );
    }
    result.oneOf = OneOfDynamic(
      typeIndex: oneOfTypes.indexOf(oneOfType),
      types: oneOfTypes,
      value: oneOfResult,
    );
    return result.build();
  }
}

class SyncMutationOperationEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'restore')
  static const SyncMutationOperationEnum restore =
      _$syncMutationOperationEnum_restore;

  static Serializer<SyncMutationOperationEnum> get serializer =>
      _$syncMutationOperationEnumSerializer;

  const SyncMutationOperationEnum._(String name) : super(name);

  static BuiltSet<SyncMutationOperationEnum> get values =>
      _$syncMutationOperationEnumValues;
  static SyncMutationOperationEnum valueOf(String name) =>
      _$syncMutationOperationEnumValueOf(name);
}
