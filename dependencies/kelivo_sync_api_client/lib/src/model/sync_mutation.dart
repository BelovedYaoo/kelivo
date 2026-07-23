//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/sync_put_mutation.dart';
import 'package:kelivo_sync_api_client/src/model/sync_delete_mutation.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:one_of/one_of.dart';

part 'sync_mutation.g.dart';

/// SyncMutation
///
/// Properties:
/// * [mutationId]
/// * [recordId]
/// * [expectedRevision]
/// * [operation]
/// * [envelopeVersion]
/// * [keyEpoch]
/// * [ciphertext] - 客户端生成的完整加密信封，使用无填充 Base64URL 编码，解码后最大 1 MiB
@BuiltValue()
abstract class SyncMutation
    implements Built<SyncMutation, SyncMutationBuilder> {
  /// One Of [SyncDeleteMutation], [SyncPutMutation]
  OneOf get oneOf;

  static const String discriminatorFieldName = r'operation';

  static const Map<String, Type> discriminatorMapping = {
    r'delete': SyncDeleteMutation,
    r'put': SyncPutMutation,
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
    if (this is SyncDeleteMutation) {
      return r'delete';
    }
    if (this is SyncPutMutation) {
      return r'put';
    }
    return null;
  }
}

extension SyncMutationBuilderDiscriminatorExt on SyncMutationBuilder {
  String? get discriminatorValue {
    if (this is SyncDeleteMutationBuilder) {
      return r'delete';
    }
    if (this is SyncPutMutationBuilder) {
      return r'put';
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
    final oneOfTypes = [SyncDeleteMutation, SyncPutMutation];
    Object oneOfResult;
    Type oneOfType;
    switch (discValue) {
      case r'delete':
        oneOfResult =
            serializers.deserialize(
                  oneOfDataSrc,
                  specifiedType: FullType(SyncDeleteMutation),
                )
                as SyncDeleteMutation;
        oneOfType = SyncDeleteMutation;
        break;
      case r'put':
        oneOfResult =
            serializers.deserialize(
                  oneOfDataSrc,
                  specifiedType: FullType(SyncPutMutation),
                )
                as SyncPutMutation;
        oneOfType = SyncPutMutation;
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
  @BuiltValueEnumConst(wireName: r'delete')
  static const SyncMutationOperationEnum delete =
      _$syncMutationOperationEnum_delete;

  static Serializer<SyncMutationOperationEnum> get serializer =>
      _$syncMutationOperationEnumSerializer;

  const SyncMutationOperationEnum._(String name) : super(name);

  static BuiltSet<SyncMutationOperationEnum> get values =>
      _$syncMutationOperationEnumValues;
  static SyncMutationOperationEnum valueOf(String name) =>
      _$syncMutationOperationEnumValueOf(name);
}
