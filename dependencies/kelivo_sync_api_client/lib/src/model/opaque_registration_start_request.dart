//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'opaque_registration_start_request.g.dart';

/// OpaqueRegistrationStartRequest
///
/// Properties:
/// * [protocolVersion]
/// * [loginName]
/// * [displayName]
/// * [deviceId]
/// * [deviceName]
/// * [platform]
/// * [clientVersion]
/// * [deviceKeyVersion]
/// * [signingPublicKey]
/// * [keyAgreementPublicKey]
/// * [registrationRequest]
@BuiltValue()
abstract class OpaqueRegistrationStartRequest
    implements
        Built<
          OpaqueRegistrationStartRequest,
          OpaqueRegistrationStartRequestBuilder
        > {
  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'loginName')
  String get loginName;

  @BuiltValueField(wireName: r'displayName')
  String get displayName;

  @BuiltValueField(wireName: r'deviceId')
  String get deviceId;

  @BuiltValueField(wireName: r'deviceName')
  String get deviceName;

  @BuiltValueField(wireName: r'platform')
  OpaqueRegistrationStartRequestPlatformEnum get platform;
  // enum platformEnum {  android,  ios,  macos,  windows,  linux,  };

  @BuiltValueField(wireName: r'clientVersion')
  String get clientVersion;

  @BuiltValueField(wireName: r'deviceKeyVersion')
  int get deviceKeyVersion;

  @BuiltValueField(wireName: r'signingPublicKey')
  String get signingPublicKey;

  @BuiltValueField(wireName: r'keyAgreementPublicKey')
  String get keyAgreementPublicKey;

  @BuiltValueField(wireName: r'registrationRequest')
  String get registrationRequest;

  OpaqueRegistrationStartRequest._();

  factory OpaqueRegistrationStartRequest([
    void updates(OpaqueRegistrationStartRequestBuilder b),
  ]) = _$OpaqueRegistrationStartRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(OpaqueRegistrationStartRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<OpaqueRegistrationStartRequest> get serializer =>
      _$OpaqueRegistrationStartRequestSerializer();
}

class _$OpaqueRegistrationStartRequestSerializer
    implements PrimitiveSerializer<OpaqueRegistrationStartRequest> {
  @override
  final Iterable<Type> types = const [
    OpaqueRegistrationStartRequest,
    _$OpaqueRegistrationStartRequest,
  ];

  @override
  final String wireName = r'OpaqueRegistrationStartRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    OpaqueRegistrationStartRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'protocolVersion';
    yield serializers.serialize(
      object.protocolVersion,
      specifiedType: const FullType(int),
    );
    yield r'loginName';
    yield serializers.serialize(
      object.loginName,
      specifiedType: const FullType(String),
    );
    yield r'displayName';
    yield serializers.serialize(
      object.displayName,
      specifiedType: const FullType(String),
    );
    yield r'deviceId';
    yield serializers.serialize(
      object.deviceId,
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
      specifiedType: const FullType(OpaqueRegistrationStartRequestPlatformEnum),
    );
    yield r'clientVersion';
    yield serializers.serialize(
      object.clientVersion,
      specifiedType: const FullType(String),
    );
    yield r'deviceKeyVersion';
    yield serializers.serialize(
      object.deviceKeyVersion,
      specifiedType: const FullType(int),
    );
    yield r'signingPublicKey';
    yield serializers.serialize(
      object.signingPublicKey,
      specifiedType: const FullType(String),
    );
    yield r'keyAgreementPublicKey';
    yield serializers.serialize(
      object.keyAgreementPublicKey,
      specifiedType: const FullType(String),
    );
    yield r'registrationRequest';
    yield serializers.serialize(
      object.registrationRequest,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    OpaqueRegistrationStartRequest object, {
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
    required OpaqueRegistrationStartRequestBuilder result,
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
        case r'loginName':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.loginName = valueDes;
          break;
        case r'displayName':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.displayName = valueDes;
          break;
        case r'deviceId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.deviceId = valueDes;
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
                      OpaqueRegistrationStartRequestPlatformEnum,
                    ),
                  )
                  as OpaqueRegistrationStartRequestPlatformEnum;
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
        case r'deviceKeyVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.deviceKeyVersion = valueDes;
          break;
        case r'signingPublicKey':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.signingPublicKey = valueDes;
          break;
        case r'keyAgreementPublicKey':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.keyAgreementPublicKey = valueDes;
          break;
        case r'registrationRequest':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.registrationRequest = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  OpaqueRegistrationStartRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = OpaqueRegistrationStartRequestBuilder();
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

class OpaqueRegistrationStartRequestPlatformEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'android')
  static const OpaqueRegistrationStartRequestPlatformEnum android =
      _$opaqueRegistrationStartRequestPlatformEnum_android;
  @BuiltValueEnumConst(wireName: r'ios')
  static const OpaqueRegistrationStartRequestPlatformEnum ios =
      _$opaqueRegistrationStartRequestPlatformEnum_ios;
  @BuiltValueEnumConst(wireName: r'macos')
  static const OpaqueRegistrationStartRequestPlatformEnum macos =
      _$opaqueRegistrationStartRequestPlatformEnum_macos;
  @BuiltValueEnumConst(wireName: r'windows')
  static const OpaqueRegistrationStartRequestPlatformEnum windows =
      _$opaqueRegistrationStartRequestPlatformEnum_windows;
  @BuiltValueEnumConst(wireName: r'linux')
  static const OpaqueRegistrationStartRequestPlatformEnum linux =
      _$opaqueRegistrationStartRequestPlatformEnum_linux;

  static Serializer<OpaqueRegistrationStartRequestPlatformEnum>
  get serializer => _$opaqueRegistrationStartRequestPlatformEnumSerializer;

  const OpaqueRegistrationStartRequestPlatformEnum._(String name) : super(name);

  static BuiltSet<OpaqueRegistrationStartRequestPlatformEnum> get values =>
      _$opaqueRegistrationStartRequestPlatformEnumValues;
  static OpaqueRegistrationStartRequestPlatformEnum valueOf(String name) =>
      _$opaqueRegistrationStartRequestPlatformEnumValueOf(name);
}
