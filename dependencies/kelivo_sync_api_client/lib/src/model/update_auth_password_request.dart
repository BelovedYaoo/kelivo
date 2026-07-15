//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'update_auth_password_request.g.dart';

/// UpdateAuthPasswordRequest
///
/// Properties:
/// * [currentPassword]
/// * [newPassword]
@BuiltValue()
abstract class UpdateAuthPasswordRequest
    implements
        Built<UpdateAuthPasswordRequest, UpdateAuthPasswordRequestBuilder> {
  @BuiltValueField(wireName: r'currentPassword')
  String get currentPassword;

  @BuiltValueField(wireName: r'newPassword')
  String get newPassword;

  UpdateAuthPasswordRequest._();

  factory UpdateAuthPasswordRequest([
    void updates(UpdateAuthPasswordRequestBuilder b),
  ]) = _$UpdateAuthPasswordRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(UpdateAuthPasswordRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<UpdateAuthPasswordRequest> get serializer =>
      _$UpdateAuthPasswordRequestSerializer();
}

class _$UpdateAuthPasswordRequestSerializer
    implements PrimitiveSerializer<UpdateAuthPasswordRequest> {
  @override
  final Iterable<Type> types = const [
    UpdateAuthPasswordRequest,
    _$UpdateAuthPasswordRequest,
  ];

  @override
  final String wireName = r'UpdateAuthPasswordRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    UpdateAuthPasswordRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'currentPassword';
    yield serializers.serialize(
      object.currentPassword,
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
    UpdateAuthPasswordRequest object, {
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
    required UpdateAuthPasswordRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'currentPassword':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.currentPassword = valueDes;
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
  UpdateAuthPasswordRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = UpdateAuthPasswordRequestBuilder();
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
