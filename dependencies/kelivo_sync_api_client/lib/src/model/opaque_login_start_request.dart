//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'opaque_login_start_request.g.dart';

/// OpaqueLoginStartRequest
///
/// Properties:
/// * [protocolVersion]
/// * [loginName]
/// * [deviceId]
/// * [deviceName]
/// * [platform]
/// * [clientVersion]
/// * [deviceKeyVersion]
/// * [signingPublicKey]
/// * [keyAgreementPublicKey]
/// * [credentialRequest]
@BuiltValue()
abstract class OpaqueLoginStartRequest
    implements Built<OpaqueLoginStartRequest, OpaqueLoginStartRequestBuilder> {
  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'loginName')
  String get loginName;

  @BuiltValueField(wireName: r'deviceId')
  String get deviceId;

  @BuiltValueField(wireName: r'deviceName')
  String get deviceName;

  @BuiltValueField(wireName: r'platform')
  OpaqueLoginStartRequestPlatformEnum get platform;
  // enum platformEnum {  android,  ios,  macos,  windows,  linux,  };

  @BuiltValueField(wireName: r'clientVersion')
  String get clientVersion;

  @BuiltValueField(wireName: r'deviceKeyVersion')
  int get deviceKeyVersion;

  @BuiltValueField(wireName: r'signingPublicKey')
  String get signingPublicKey;

  @BuiltValueField(wireName: r'keyAgreementPublicKey')
  String get keyAgreementPublicKey;

  @BuiltValueField(wireName: r'credentialRequest')
  String get credentialRequest;

  OpaqueLoginStartRequest._();

  factory OpaqueLoginStartRequest([
    void updates(OpaqueLoginStartRequestBuilder b),
  ]) = _$OpaqueLoginStartRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(OpaqueLoginStartRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<OpaqueLoginStartRequest> get serializer =>
      _$OpaqueLoginStartRequestSerializer();
}

class _$OpaqueLoginStartRequestSerializer
    implements PrimitiveSerializer<OpaqueLoginStartRequest> {
  @override
  final Iterable<Type> types = const [
    OpaqueLoginStartRequest,
    _$OpaqueLoginStartRequest,
  ];

  @override
  final String wireName = r'OpaqueLoginStartRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    OpaqueLoginStartRequest object, {
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
      specifiedType: const FullType(OpaqueLoginStartRequestPlatformEnum),
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
    yield r'credentialRequest';
    yield serializers.serialize(
      object.credentialRequest,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    OpaqueLoginStartRequest object, {
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
    required OpaqueLoginStartRequestBuilder result,
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
                      OpaqueLoginStartRequestPlatformEnum,
                    ),
                  )
                  as OpaqueLoginStartRequestPlatformEnum;
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
        case r'credentialRequest':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.credentialRequest = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  OpaqueLoginStartRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = OpaqueLoginStartRequestBuilder();
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

class OpaqueLoginStartRequestPlatformEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'android')
  static const OpaqueLoginStartRequestPlatformEnum android =
      _$opaqueLoginStartRequestPlatformEnum_android;
  @BuiltValueEnumConst(wireName: r'ios')
  static const OpaqueLoginStartRequestPlatformEnum ios =
      _$opaqueLoginStartRequestPlatformEnum_ios;
  @BuiltValueEnumConst(wireName: r'macos')
  static const OpaqueLoginStartRequestPlatformEnum macos =
      _$opaqueLoginStartRequestPlatformEnum_macos;
  @BuiltValueEnumConst(wireName: r'windows')
  static const OpaqueLoginStartRequestPlatformEnum windows =
      _$opaqueLoginStartRequestPlatformEnum_windows;
  @BuiltValueEnumConst(wireName: r'linux')
  static const OpaqueLoginStartRequestPlatformEnum linux =
      _$opaqueLoginStartRequestPlatformEnum_linux;

  static Serializer<OpaqueLoginStartRequestPlatformEnum> get serializer =>
      _$opaqueLoginStartRequestPlatformEnumSerializer;

  const OpaqueLoginStartRequestPlatformEnum._(String name) : super(name);

  static BuiltSet<OpaqueLoginStartRequestPlatformEnum> get values =>
      _$opaqueLoginStartRequestPlatformEnumValues;
  static OpaqueLoginStartRequestPlatformEnum valueOf(String name) =>
      _$opaqueLoginStartRequestPlatformEnumValueOf(name);
}
