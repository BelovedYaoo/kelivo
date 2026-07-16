//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/json_object.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_conflict_details_fields_inner_current.g.dart';

/// SyncConflictDetailsFieldsInnerCurrent
///
/// Properties:
/// * [exists]
/// * [value] - 合法 JSON 值
@BuiltValue()
abstract class SyncConflictDetailsFieldsInnerCurrent
    implements
        Built<
          SyncConflictDetailsFieldsInnerCurrent,
          SyncConflictDetailsFieldsInnerCurrentBuilder
        > {
  @BuiltValueField(wireName: r'exists')
  bool get exists;

  /// 合法 JSON 值
  @BuiltValueField(wireName: r'value')
  JsonObject? get value;

  SyncConflictDetailsFieldsInnerCurrent._();

  factory SyncConflictDetailsFieldsInnerCurrent([
    void updates(SyncConflictDetailsFieldsInnerCurrentBuilder b),
  ]) = _$SyncConflictDetailsFieldsInnerCurrent;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncConflictDetailsFieldsInnerCurrentBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncConflictDetailsFieldsInnerCurrent> get serializer =>
      _$SyncConflictDetailsFieldsInnerCurrentSerializer();
}

class _$SyncConflictDetailsFieldsInnerCurrentSerializer
    implements PrimitiveSerializer<SyncConflictDetailsFieldsInnerCurrent> {
  @override
  final Iterable<Type> types = const [
    SyncConflictDetailsFieldsInnerCurrent,
    _$SyncConflictDetailsFieldsInnerCurrent,
  ];

  @override
  final String wireName = r'SyncConflictDetailsFieldsInnerCurrent';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncConflictDetailsFieldsInnerCurrent object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'exists';
    yield serializers.serialize(
      object.exists,
      specifiedType: const FullType(bool),
    );
    if (object.value != null) {
      yield r'value';
      yield serializers.serialize(
        object.value,
        specifiedType: const FullType.nullable(JsonObject),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncConflictDetailsFieldsInnerCurrent object, {
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
    required SyncConflictDetailsFieldsInnerCurrentBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'exists':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )
                  as bool;
          result.exists = valueDes;
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
  SyncConflictDetailsFieldsInnerCurrent deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncConflictDetailsFieldsInnerCurrentBuilder();
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
