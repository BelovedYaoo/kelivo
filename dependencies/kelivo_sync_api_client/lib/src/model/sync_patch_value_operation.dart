//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_patch_value_operation.g.dart';

/// SyncPatchValueOperation
///
/// Properties:
/// * [op]
/// * [path]
/// * [value] - 合法 JSON 值
@BuiltValue()
abstract class SyncPatchValueOperation
    implements Built<SyncPatchValueOperation, SyncPatchValueOperationBuilder> {
  @BuiltValueField(wireName: r'op')
  SyncPatchValueOperationOpEnum get op;
  // enum opEnum {  add,  replace,  };

  @BuiltValueField(wireName: r'path')
  String get path;

  /// 合法 JSON 值
  @BuiltValueField(wireName: r'value')
  JsonObject? get value;

  SyncPatchValueOperation._();

  factory SyncPatchValueOperation([
    void updates(SyncPatchValueOperationBuilder b),
  ]) = _$SyncPatchValueOperation;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncPatchValueOperationBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncPatchValueOperation> get serializer =>
      _$SyncPatchValueOperationSerializer();
}

class _$SyncPatchValueOperationSerializer
    implements PrimitiveSerializer<SyncPatchValueOperation> {
  @override
  final Iterable<Type> types = const [
    SyncPatchValueOperation,
    _$SyncPatchValueOperation,
  ];

  @override
  final String wireName = r'SyncPatchValueOperation';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncPatchValueOperation object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'op';
    yield serializers.serialize(
      object.op,
      specifiedType: const FullType(SyncPatchValueOperationOpEnum),
    );
    yield r'path';
    yield serializers.serialize(
      object.path,
      specifiedType: const FullType(String),
    );
    yield r'value';
    yield object.value == null
        ? null
        : serializers.serialize(
            object.value,
            specifiedType: const FullType.nullable(JsonObject),
          );
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncPatchValueOperation object, {
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
    required SyncPatchValueOperationBuilder result,
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
                      SyncPatchValueOperationOpEnum,
                    ),
                  )
                  as SyncPatchValueOperationOpEnum;
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
        case r'value':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(JsonObject),
                  )
                  as JsonObject?;
          if (valueDes == null) continue;
          result.value = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncPatchValueOperation deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncPatchValueOperationBuilder();
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

class SyncPatchValueOperationOpEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'add')
  static const SyncPatchValueOperationOpEnum add =
      _$syncPatchValueOperationOpEnum_add;
  @BuiltValueEnumConst(wireName: r'replace')
  static const SyncPatchValueOperationOpEnum replace =
      _$syncPatchValueOperationOpEnum_replace;

  static Serializer<SyncPatchValueOperationOpEnum> get serializer =>
      _$syncPatchValueOperationOpEnumSerializer;

  const SyncPatchValueOperationOpEnum._(String name) : super(name);

  static BuiltSet<SyncPatchValueOperationOpEnum> get values =>
      _$syncPatchValueOperationOpEnumValues;
  static SyncPatchValueOperationOpEnum valueOf(String name) =>
      _$syncPatchValueOperationOpEnumValueOf(name);
}
