//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/account_security_state_data.dart';
import 'package:kelivo_sync_api_client/src/model/opaque_registration_finish_data_device.dart';
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/opaque_registration_finish_data_user.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'authenticated_session_data.g.dart';

/// AuthenticatedSessionData
///
/// Properties:
/// * [protocolVersion]
/// * [result]
/// * [token]
/// * [tokenExpiresAt]
/// * [user]
/// * [device]
/// * [securityState]
@BuiltValue()
abstract class AuthenticatedSessionData
    implements
        Built<AuthenticatedSessionData, AuthenticatedSessionDataBuilder> {
  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'result')
  AuthenticatedSessionDataResultEnum get result;
  // enum resultEnum {  authenticated,  };

  @BuiltValueField(wireName: r'token')
  String get token;

  @BuiltValueField(wireName: r'tokenExpiresAt')
  DateTime get tokenExpiresAt;

  @BuiltValueField(wireName: r'user')
  OpaqueRegistrationFinishDataUser get user;

  @BuiltValueField(wireName: r'device')
  OpaqueRegistrationFinishDataDevice get device;

  @BuiltValueField(wireName: r'securityState')
  AccountSecurityStateData get securityState;

  AuthenticatedSessionData._();

  factory AuthenticatedSessionData([
    void updates(AuthenticatedSessionDataBuilder b),
  ]) = _$AuthenticatedSessionData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AuthenticatedSessionDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AuthenticatedSessionData> get serializer =>
      _$AuthenticatedSessionDataSerializer();
}

class _$AuthenticatedSessionDataSerializer
    implements PrimitiveSerializer<AuthenticatedSessionData> {
  @override
  final Iterable<Type> types = const [
    AuthenticatedSessionData,
    _$AuthenticatedSessionData,
  ];

  @override
  final String wireName = r'AuthenticatedSessionData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AuthenticatedSessionData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'protocolVersion';
    yield serializers.serialize(
      object.protocolVersion,
      specifiedType: const FullType(int),
    );
    yield r'result';
    yield serializers.serialize(
      object.result,
      specifiedType: const FullType(AuthenticatedSessionDataResultEnum),
    );
    yield r'token';
    yield serializers.serialize(
      object.token,
      specifiedType: const FullType(String),
    );
    yield r'tokenExpiresAt';
    yield serializers.serialize(
      object.tokenExpiresAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'user';
    yield serializers.serialize(
      object.user,
      specifiedType: const FullType(OpaqueRegistrationFinishDataUser),
    );
    yield r'device';
    yield serializers.serialize(
      object.device,
      specifiedType: const FullType(OpaqueRegistrationFinishDataDevice),
    );
    yield r'securityState';
    yield serializers.serialize(
      object.securityState,
      specifiedType: const FullType(AccountSecurityStateData),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AuthenticatedSessionData object, {
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
    required AuthenticatedSessionDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'protocolVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.protocolVersion = valueDes;
          break;
        case r'result':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AuthenticatedSessionDataResultEnum,
                    ),
                  )
                  as AuthenticatedSessionDataResultEnum;
          result.result = valueDes;
          break;
        case r'token':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.token = valueDes;
          break;
        case r'tokenExpiresAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.tokenExpiresAt = valueDes;
          break;
        case r'user':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      OpaqueRegistrationFinishDataUser,
                    ),
                  )
                  as OpaqueRegistrationFinishDataUser;
          result.user.replace(valueDes);
          break;
        case r'device':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      OpaqueRegistrationFinishDataDevice,
                    ),
                  )
                  as OpaqueRegistrationFinishDataDevice;
          result.device.replace(valueDes);
          break;
        case r'securityState':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(AccountSecurityStateData),
                  )
                  as AccountSecurityStateData;
          result.securityState.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AuthenticatedSessionData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AuthenticatedSessionDataBuilder();
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

class AuthenticatedSessionDataResultEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'authenticated')
  static const AuthenticatedSessionDataResultEnum authenticated =
      _$authenticatedSessionDataResultEnum_authenticated;

  static Serializer<AuthenticatedSessionDataResultEnum> get serializer =>
      _$authenticatedSessionDataResultEnumSerializer;

  const AuthenticatedSessionDataResultEnum._(String name) : super(name);

  static BuiltSet<AuthenticatedSessionDataResultEnum> get values =>
      _$authenticatedSessionDataResultEnumValues;
  static AuthenticatedSessionDataResultEnum valueOf(String name) =>
      _$authenticatedSessionDataResultEnumValueOf(name);
}
