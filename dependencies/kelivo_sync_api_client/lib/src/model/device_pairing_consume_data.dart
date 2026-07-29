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

part 'device_pairing_consume_data.g.dart';

/// DevicePairingConsumeData
///
/// Properties:
/// * [protocolVersion]
/// * [result]
/// * [pairingId]
/// * [issuerDeviceId]
/// * [keyEpoch]
/// * [securityGeneration]
/// * [membershipManifestDigest]
/// * [securityState]
/// * [token]
/// * [tokenExpiresAt]
/// * [user]
/// * [device]
@BuiltValue()
abstract class DevicePairingConsumeData
    implements
        Built<DevicePairingConsumeData, DevicePairingConsumeDataBuilder> {
  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'result')
  DevicePairingConsumeDataResultEnum get result;
  // enum resultEnum {  authenticated,  };

  @BuiltValueField(wireName: r'pairingId')
  String get pairingId;

  @BuiltValueField(wireName: r'issuerDeviceId')
  String get issuerDeviceId;

  @BuiltValueField(wireName: r'keyEpoch')
  int get keyEpoch;

  @BuiltValueField(wireName: r'securityGeneration')
  int get securityGeneration;

  @BuiltValueField(wireName: r'membershipManifestDigest')
  String get membershipManifestDigest;

  @BuiltValueField(wireName: r'securityState')
  AccountSecurityStateData get securityState;

  @BuiltValueField(wireName: r'token')
  String get token;

  @BuiltValueField(wireName: r'tokenExpiresAt')
  DateTime get tokenExpiresAt;

  @BuiltValueField(wireName: r'user')
  OpaqueRegistrationFinishDataUser get user;

  @BuiltValueField(wireName: r'device')
  OpaqueRegistrationFinishDataDevice get device;

  DevicePairingConsumeData._();

  factory DevicePairingConsumeData([
    void updates(DevicePairingConsumeDataBuilder b),
  ]) = _$DevicePairingConsumeData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DevicePairingConsumeDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DevicePairingConsumeData> get serializer =>
      _$DevicePairingConsumeDataSerializer();
}

class _$DevicePairingConsumeDataSerializer
    implements PrimitiveSerializer<DevicePairingConsumeData> {
  @override
  final Iterable<Type> types = const [
    DevicePairingConsumeData,
    _$DevicePairingConsumeData,
  ];

  @override
  final String wireName = r'DevicePairingConsumeData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DevicePairingConsumeData object, {
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
      specifiedType: const FullType(DevicePairingConsumeDataResultEnum),
    );
    yield r'pairingId';
    yield serializers.serialize(
      object.pairingId,
      specifiedType: const FullType(String),
    );
    yield r'issuerDeviceId';
    yield serializers.serialize(
      object.issuerDeviceId,
      specifiedType: const FullType(String),
    );
    yield r'keyEpoch';
    yield serializers.serialize(
      object.keyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'securityGeneration';
    yield serializers.serialize(
      object.securityGeneration,
      specifiedType: const FullType(int),
    );
    yield r'membershipManifestDigest';
    yield serializers.serialize(
      object.membershipManifestDigest,
      specifiedType: const FullType(String),
    );
    yield r'securityState';
    yield serializers.serialize(
      object.securityState,
      specifiedType: const FullType(AccountSecurityStateData),
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
  }

  @override
  Object serialize(
    Serializers serializers,
    DevicePairingConsumeData object, {
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
    required DevicePairingConsumeDataBuilder result,
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
                      DevicePairingConsumeDataResultEnum,
                    ),
                  )
                  as DevicePairingConsumeDataResultEnum;
          result.result = valueDes;
          break;
        case r'pairingId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.pairingId = valueDes;
          break;
        case r'issuerDeviceId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.issuerDeviceId = valueDes;
          break;
        case r'keyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.keyEpoch = valueDes;
          break;
        case r'securityGeneration':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.securityGeneration = valueDes;
          break;
        case r'membershipManifestDigest':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.membershipManifestDigest = valueDes;
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DevicePairingConsumeData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DevicePairingConsumeDataBuilder();
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

class DevicePairingConsumeDataResultEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'authenticated')
  static const DevicePairingConsumeDataResultEnum authenticated =
      _$devicePairingConsumeDataResultEnum_authenticated;

  static Serializer<DevicePairingConsumeDataResultEnum> get serializer =>
      _$devicePairingConsumeDataResultEnumSerializer;

  const DevicePairingConsumeDataResultEnum._(String name) : super(name);

  static BuiltSet<DevicePairingConsumeDataResultEnum> get values =>
      _$devicePairingConsumeDataResultEnumValues;
  static DevicePairingConsumeDataResultEnum valueOf(String name) =>
      _$devicePairingConsumeDataResultEnumValueOf(name);
}
