//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'create_auth_session_request.g.dart';

/// CreateAuthSessionRequest
///
/// Properties:
/// * [loginName]
/// * [password]
/// * [deviceName]
/// * [platform]
/// * [clientVersion]
@BuiltValue()
abstract class CreateAuthSessionRequest
    implements
        Built<CreateAuthSessionRequest, CreateAuthSessionRequestBuilder> {
  @BuiltValueField(wireName: r'loginName')
  String get loginName;

  @BuiltValueField(wireName: r'password')
  String get password;

  @BuiltValueField(wireName: r'deviceName')
  String get deviceName;

  @BuiltValueField(wireName: r'platform')
  CreateAuthSessionRequestPlatformEnum get platform;
  // enum platformEnum {  android,  ios,  macos,  windows,  linux,  };

  @BuiltValueField(wireName: r'clientVersion')
  String get clientVersion;

  CreateAuthSessionRequest._();

  factory CreateAuthSessionRequest([
    void updates(CreateAuthSessionRequestBuilder b),
  ]) = _$CreateAuthSessionRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CreateAuthSessionRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CreateAuthSessionRequest> get serializer =>
      _$CreateAuthSessionRequestSerializer();
}

class _$CreateAuthSessionRequestSerializer
    implements PrimitiveSerializer<CreateAuthSessionRequest> {
  @override
  final Iterable<Type> types = const [
    CreateAuthSessionRequest,
    _$CreateAuthSessionRequest,
  ];

  @override
  final String wireName = r'CreateAuthSessionRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CreateAuthSessionRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'loginName';
    yield serializers.serialize(
      object.loginName,
      specifiedType: const FullType(String),
    );
    yield r'password';
    yield serializers.serialize(
      object.password,
      specifiedType: const FullType(String),
    );
    yield r'deviceName';
    yield serializers.serialize(
      object.deviceName,
      specifiedType: const FullType(String),
    );
    yield r'platform';
    yield serializers.serialize(
      object.platform,
      specifiedType: const FullType(CreateAuthSessionRequestPlatformEnum),
    );
    yield r'clientVersion';
    yield serializers.serialize(
      object.clientVersion,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    CreateAuthSessionRequest object, {
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
    required CreateAuthSessionRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'loginName':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.loginName = valueDes;
          break;
        case r'password':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.password = valueDes;
          break;
        case r'deviceName':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.deviceName = valueDes;
          break;
        case r'platform':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      CreateAuthSessionRequestPlatformEnum,
                    ),
                  )
                  as CreateAuthSessionRequestPlatformEnum;
          result.platform = valueDes;
          break;
        case r'clientVersion':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.clientVersion = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CreateAuthSessionRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CreateAuthSessionRequestBuilder();
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

class CreateAuthSessionRequestPlatformEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'android')
  static const CreateAuthSessionRequestPlatformEnum android =
      _$createAuthSessionRequestPlatformEnum_android;
  @BuiltValueEnumConst(wireName: r'ios')
  static const CreateAuthSessionRequestPlatformEnum ios =
      _$createAuthSessionRequestPlatformEnum_ios;
  @BuiltValueEnumConst(wireName: r'macos')
  static const CreateAuthSessionRequestPlatformEnum macos =
      _$createAuthSessionRequestPlatformEnum_macos;
  @BuiltValueEnumConst(wireName: r'windows')
  static const CreateAuthSessionRequestPlatformEnum windows =
      _$createAuthSessionRequestPlatformEnum_windows;
  @BuiltValueEnumConst(wireName: r'linux')
  static const CreateAuthSessionRequestPlatformEnum linux =
      _$createAuthSessionRequestPlatformEnum_linux;

  static Serializer<CreateAuthSessionRequestPlatformEnum> get serializer =>
      _$createAuthSessionRequestPlatformEnumSerializer;

  const CreateAuthSessionRequestPlatformEnum._(String name) : super(name);

  static BuiltSet<CreateAuthSessionRequestPlatformEnum> get values =>
      _$createAuthSessionRequestPlatformEnumValues;
  static CreateAuthSessionRequestPlatformEnum valueOf(String name) =>
      _$createAuthSessionRequestPlatformEnumValueOf(name);
}
