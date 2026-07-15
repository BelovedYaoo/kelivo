//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_patch_remove_operation.g.dart';

/// SyncPatchRemoveOperation
///
/// Properties:
/// * [op]
/// * [path]
@BuiltValue()
abstract class SyncPatchRemoveOperation
    implements
        Built<SyncPatchRemoveOperation, SyncPatchRemoveOperationBuilder> {
  @BuiltValueField(wireName: r'op')
  SyncPatchRemoveOperationOpEnum get op;
  // enum opEnum {  remove,  };

  @BuiltValueField(wireName: r'path')
  String get path;

  SyncPatchRemoveOperation._();

  factory SyncPatchRemoveOperation([
    void updates(SyncPatchRemoveOperationBuilder b),
  ]) = _$SyncPatchRemoveOperation;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncPatchRemoveOperationBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncPatchRemoveOperation> get serializer =>
      _$SyncPatchRemoveOperationSerializer();
}

class _$SyncPatchRemoveOperationSerializer
    implements PrimitiveSerializer<SyncPatchRemoveOperation> {
  @override
  final Iterable<Type> types = const [
    SyncPatchRemoveOperation,
    _$SyncPatchRemoveOperation,
  ];

  @override
  final String wireName = r'SyncPatchRemoveOperation';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncPatchRemoveOperation object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'op';
    yield serializers.serialize(
      object.op,
      specifiedType: const FullType(SyncPatchRemoveOperationOpEnum),
    );
    yield r'path';
    yield serializers.serialize(
      object.path,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncPatchRemoveOperation object, {
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
    required SyncPatchRemoveOperationBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'op':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      SyncPatchRemoveOperationOpEnum,
                    ),
                  )
                  as SyncPatchRemoveOperationOpEnum;
          result.op = valueDes;
          break;
        case r'path':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.path = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncPatchRemoveOperation deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncPatchRemoveOperationBuilder();
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

class SyncPatchRemoveOperationOpEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'remove')
  static const SyncPatchRemoveOperationOpEnum remove =
      _$syncPatchRemoveOperationOpEnum_remove;

  static Serializer<SyncPatchRemoveOperationOpEnum> get serializer =>
      _$syncPatchRemoveOperationOpEnumSerializer;

  const SyncPatchRemoveOperationOpEnum._(String name) : super(name);

  static BuiltSet<SyncPatchRemoveOperationOpEnum> get values =>
      _$syncPatchRemoveOperationOpEnumValues;
  static SyncPatchRemoveOperationOpEnum valueOf(String name) =>
      _$syncPatchRemoveOperationOpEnumValueOf(name);
}
