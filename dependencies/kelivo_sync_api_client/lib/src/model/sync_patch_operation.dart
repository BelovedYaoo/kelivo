//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/sync_patch_remove_operation.dart';
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/sync_patch_value_operation.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:one_of/one_of.dart';

part 'sync_patch_operation.g.dart';

/// SyncPatchOperation
///
/// Properties:
/// * [op]
/// * [path]
/// * [value] - 合法 JSON 值
@BuiltValue()
abstract class SyncPatchOperation
    implements Built<SyncPatchOperation, SyncPatchOperationBuilder> {
  /// One Of [SyncPatchRemoveOperation], [SyncPatchValueOperation]
  OneOf get oneOf;

  static const String discriminatorFieldName = r'op';

  static const Map<String, Type> discriminatorMapping = {
    r'add': SyncPatchValueOperation,
    r'remove': SyncPatchRemoveOperation,
    r'replace': SyncPatchValueOperation,
  };

  SyncPatchOperation._();

  factory SyncPatchOperation([void updates(SyncPatchOperationBuilder b)]) =
      _$SyncPatchOperation;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncPatchOperationBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncPatchOperation> get serializer =>
      _$SyncPatchOperationSerializer();
}

extension SyncPatchOperationDiscriminatorExt on SyncPatchOperation {
  String? get discriminatorValue {
    if (this is SyncPatchValueOperation) {
      return r'add';
    }
    if (this is SyncPatchRemoveOperation) {
      return r'remove';
    }
    if (this is SyncPatchValueOperation) {
      return r'replace';
    }
    return null;
  }
}

extension SyncPatchOperationBuilderDiscriminatorExt
    on SyncPatchOperationBuilder {
  String? get discriminatorValue {
    if (this is SyncPatchValueOperationBuilder) {
      return r'add';
    }
    if (this is SyncPatchRemoveOperationBuilder) {
      return r'remove';
    }
    if (this is SyncPatchValueOperationBuilder) {
      return r'replace';
    }
    return null;
  }
}

class _$SyncPatchOperationSerializer
    implements PrimitiveSerializer<SyncPatchOperation> {
  @override
  final Iterable<Type> types = const [SyncPatchOperation, _$SyncPatchOperation];

  @override
  final String wireName = r'SyncPatchOperation';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncPatchOperation object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {}

  @override
  Object serialize(
    Serializers serializers,
    SyncPatchOperation object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final oneOf = object.oneOf;
    return serializers.serialize(
      oneOf.value,
      specifiedType: FullType(oneOf.valueType),
    )!;
  }

  @override
  SyncPatchOperation deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncPatchOperationBuilder();
    Object? oneOfDataSrc;
    final serializedList = (serialized as Iterable<Object?>).toList();
    final discIndex =
        serializedList.indexOf(SyncPatchOperation.discriminatorFieldName) + 1;
    final discValue =
        serializers.deserialize(
              serializedList[discIndex],
              specifiedType: FullType(String),
            )
            as String;
    oneOfDataSrc = serialized;
    final oneOfTypes = [
      SyncPatchValueOperation,
      SyncPatchRemoveOperation,
      SyncPatchValueOperation,
    ];
    Object oneOfResult;
    Type oneOfType;
    switch (discValue) {
      case r'add':
        oneOfResult =
            serializers.deserialize(
                  oneOfDataSrc,
                  specifiedType: FullType(SyncPatchValueOperation),
                )
                as SyncPatchValueOperation;
        oneOfType = SyncPatchValueOperation;
        break;
      case r'remove':
        oneOfResult =
            serializers.deserialize(
                  oneOfDataSrc,
                  specifiedType: FullType(SyncPatchRemoveOperation),
                )
                as SyncPatchRemoveOperation;
        oneOfType = SyncPatchRemoveOperation;
        break;
      case r'replace':
        oneOfResult =
            serializers.deserialize(
                  oneOfDataSrc,
                  specifiedType: FullType(SyncPatchValueOperation),
                )
                as SyncPatchValueOperation;
        oneOfType = SyncPatchValueOperation;
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

class SyncPatchOperationOpEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'remove')
  static const SyncPatchOperationOpEnum remove =
      _$syncPatchOperationOpEnum_remove;

  static Serializer<SyncPatchOperationOpEnum> get serializer =>
      _$syncPatchOperationOpEnumSerializer;

  const SyncPatchOperationOpEnum._(String name) : super(name);

  static BuiltSet<SyncPatchOperationOpEnum> get values =>
      _$syncPatchOperationOpEnumValues;
  static SyncPatchOperationOpEnum valueOf(String name) =>
      _$syncPatchOperationOpEnumValueOf(name);
}
