//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'reset_admin_user_password_data.g.dart';

/// ResetAdminUserPasswordData
///
/// Properties:
/// * [updated]
/// * [sessionsRevoked]
@BuiltValue()
abstract class ResetAdminUserPasswordData
    implements
        Built<ResetAdminUserPasswordData, ResetAdminUserPasswordDataBuilder> {
  @BuiltValueField(wireName: r'updated')
  bool get updated;

  @BuiltValueField(wireName: r'sessionsRevoked')
  bool get sessionsRevoked;

  ResetAdminUserPasswordData._();

  factory ResetAdminUserPasswordData([
    void updates(ResetAdminUserPasswordDataBuilder b),
  ]) = _$ResetAdminUserPasswordData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ResetAdminUserPasswordDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ResetAdminUserPasswordData> get serializer =>
      _$ResetAdminUserPasswordDataSerializer();
}

class _$ResetAdminUserPasswordDataSerializer
    implements PrimitiveSerializer<ResetAdminUserPasswordData> {
  @override
  final Iterable<Type> types = const [
    ResetAdminUserPasswordData,
    _$ResetAdminUserPasswordData,
  ];

  @override
  final String wireName = r'ResetAdminUserPasswordData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ResetAdminUserPasswordData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'updated';
    yield serializers.serialize(
      object.updated,
      specifiedType: const FullType(bool),
    );
    yield r'sessionsRevoked';
    yield serializers.serialize(
      object.sessionsRevoked,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ResetAdminUserPasswordData object, {
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
    required ResetAdminUserPasswordDataBuilder result,
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
        case r'sessionsRevoked':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )
                  as bool;
          result.sessionsRevoked = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ResetAdminUserPasswordData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ResetAdminUserPasswordDataBuilder();
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
