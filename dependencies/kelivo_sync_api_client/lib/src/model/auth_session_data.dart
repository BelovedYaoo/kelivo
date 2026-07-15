//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/user_summary.dart';
import 'package:kelivo_sync_api_client/src/model/auth_device_summary.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'auth_session_data.g.dart';

/// AuthSessionData
///
/// Properties:
/// * [token]
/// * [user]
/// * [device]
@BuiltValue()
abstract class AuthSessionData
    implements Built<AuthSessionData, AuthSessionDataBuilder> {
  @BuiltValueField(wireName: r'token')
  String get token;

  @BuiltValueField(wireName: r'user')
  UserSummary get user;

  @BuiltValueField(wireName: r'device')
  AuthDeviceSummary get device;

  AuthSessionData._();

  factory AuthSessionData([void updates(AuthSessionDataBuilder b)]) =
      _$AuthSessionData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AuthSessionDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AuthSessionData> get serializer =>
      _$AuthSessionDataSerializer();
}

class _$AuthSessionDataSerializer
    implements PrimitiveSerializer<AuthSessionData> {
  @override
  final Iterable<Type> types = const [AuthSessionData, _$AuthSessionData];

  @override
  final String wireName = r'AuthSessionData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AuthSessionData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'token';
    yield serializers.serialize(
      object.token,
      specifiedType: const FullType(String),
    );
    yield r'user';
    yield serializers.serialize(
      object.user,
      specifiedType: const FullType(UserSummary),
    );
    yield r'device';
    yield serializers.serialize(
      object.device,
      specifiedType: const FullType(AuthDeviceSummary),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AuthSessionData object, {
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
    required AuthSessionDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'token':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.token = valueDes;
          break;
        case r'user':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(UserSummary),
                  )
                  as UserSummary;
          result.user.replace(valueDes);
          break;
        case r'device':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(AuthDeviceSummary),
                  )
                  as AuthDeviceSummary;
          result.device.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AuthSessionData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AuthSessionDataBuilder();
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
