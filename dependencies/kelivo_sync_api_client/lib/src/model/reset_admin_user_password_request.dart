//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'reset_admin_user_password_request.g.dart';

/// ResetAdminUserPasswordRequest
///
/// Properties:
/// * [userId]
/// * [newPassword]
@BuiltValue()
abstract class ResetAdminUserPasswordRequest
    implements
        Built<
          ResetAdminUserPasswordRequest,
          ResetAdminUserPasswordRequestBuilder
        > {
  @BuiltValueField(wireName: r'userId')
  String get userId;

  @BuiltValueField(wireName: r'newPassword')
  String get newPassword;

  ResetAdminUserPasswordRequest._();

  factory ResetAdminUserPasswordRequest([
    void updates(ResetAdminUserPasswordRequestBuilder b),
  ]) = _$ResetAdminUserPasswordRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ResetAdminUserPasswordRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ResetAdminUserPasswordRequest> get serializer =>
      _$ResetAdminUserPasswordRequestSerializer();
}

class _$ResetAdminUserPasswordRequestSerializer
    implements PrimitiveSerializer<ResetAdminUserPasswordRequest> {
  @override
  final Iterable<Type> types = const [
    ResetAdminUserPasswordRequest,
    _$ResetAdminUserPasswordRequest,
  ];

  @override
  final String wireName = r'ResetAdminUserPasswordRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ResetAdminUserPasswordRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'userId';
    yield serializers.serialize(
      object.userId,
      specifiedType: const FullType(String),
    );
    yield r'newPassword';
    yield serializers.serialize(
      object.newPassword,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ResetAdminUserPasswordRequest object, {
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
    required ResetAdminUserPasswordRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'userId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.userId = valueDes;
          break;
        case r'newPassword':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.newPassword = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ResetAdminUserPasswordRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ResetAdminUserPasswordRequestBuilder();
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
