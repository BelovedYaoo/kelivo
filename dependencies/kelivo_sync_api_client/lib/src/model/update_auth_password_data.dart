//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'update_auth_password_data.g.dart';

/// UpdateAuthPasswordData
///
/// Properties:
/// * [updated]
@BuiltValue()
abstract class UpdateAuthPasswordData
    implements Built<UpdateAuthPasswordData, UpdateAuthPasswordDataBuilder> {
  @BuiltValueField(wireName: r'updated')
  bool get updated;

  UpdateAuthPasswordData._();

  factory UpdateAuthPasswordData([
    void updates(UpdateAuthPasswordDataBuilder b),
  ]) = _$UpdateAuthPasswordData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(UpdateAuthPasswordDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<UpdateAuthPasswordData> get serializer =>
      _$UpdateAuthPasswordDataSerializer();
}

class _$UpdateAuthPasswordDataSerializer
    implements PrimitiveSerializer<UpdateAuthPasswordData> {
  @override
  final Iterable<Type> types = const [
    UpdateAuthPasswordData,
    _$UpdateAuthPasswordData,
  ];

  @override
  final String wireName = r'UpdateAuthPasswordData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    UpdateAuthPasswordData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'updated';
    yield serializers.serialize(
      object.updated,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    UpdateAuthPasswordData object, {
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
    required UpdateAuthPasswordDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'updated':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )
                  as bool;
          result.updated = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  UpdateAuthPasswordData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = UpdateAuthPasswordDataBuilder();
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
