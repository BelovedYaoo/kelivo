//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/device_pairing_create_data_target_device.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_pairing_query_data_one_of1.g.dart';

/// DevicePairingQueryDataOneOf1
///
/// Properties:
/// * [protocolVersion]
/// * [pairingId]
/// * [accountContextId]
/// * [challenge]
/// * [expiresAt]
/// * [targetDevice]
/// * [status]
/// * [issuerDeviceId]
/// * [issuerKeyVersion]
/// * [issuerAuthGeneration]
/// * [issuerSigningPublicKey]
/// * [issuerKeyAgreementPublicKey]
/// * [keyEpoch]
/// * [accountKeyEnvelope]
/// * [deviceProof]
/// * [pairingAuthenticator]
@BuiltValue()
abstract class DevicePairingQueryDataOneOf1
    implements
        Built<
          DevicePairingQueryDataOneOf1,
          DevicePairingQueryDataOneOf1Builder
        > {
  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'pairingId')
  String get pairingId;

  @BuiltValueField(wireName: r'accountContextId')
  String get accountContextId;

  @BuiltValueField(wireName: r'challenge')
  String get challenge;

  @BuiltValueField(wireName: r'expiresAt')
  DateTime get expiresAt;

  @BuiltValueField(wireName: r'targetDevice')
  DevicePairingCreateDataTargetDevice get targetDevice;

  @BuiltValueField(wireName: r'status')
  DevicePairingQueryDataOneOf1StatusEnum get status;
  // enum statusEnum {  approved,  };

  @BuiltValueField(wireName: r'issuerDeviceId')
  String get issuerDeviceId;

  @BuiltValueField(wireName: r'issuerKeyVersion')
  int get issuerKeyVersion;

  @BuiltValueField(wireName: r'issuerAuthGeneration')
  int get issuerAuthGeneration;

  @BuiltValueField(wireName: r'issuerSigningPublicKey')
  String get issuerSigningPublicKey;

  @BuiltValueField(wireName: r'issuerKeyAgreementPublicKey')
  String get issuerKeyAgreementPublicKey;

  @BuiltValueField(wireName: r'keyEpoch')
  int get keyEpoch;

  @BuiltValueField(wireName: r'accountKeyEnvelope')
  String get accountKeyEnvelope;

  @BuiltValueField(wireName: r'deviceProof')
  String get deviceProof;

  @BuiltValueField(wireName: r'pairingAuthenticator')
  String get pairingAuthenticator;

  DevicePairingQueryDataOneOf1._();

  factory DevicePairingQueryDataOneOf1([
    void updates(DevicePairingQueryDataOneOf1Builder b),
  ]) = _$DevicePairingQueryDataOneOf1;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DevicePairingQueryDataOneOf1Builder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DevicePairingQueryDataOneOf1> get serializer =>
      _$DevicePairingQueryDataOneOf1Serializer();
}

class _$DevicePairingQueryDataOneOf1Serializer
    implements PrimitiveSerializer<DevicePairingQueryDataOneOf1> {
  @override
  final Iterable<Type> types = const [
    DevicePairingQueryDataOneOf1,
    _$DevicePairingQueryDataOneOf1,
  ];

  @override
  final String wireName = r'DevicePairingQueryDataOneOf1';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DevicePairingQueryDataOneOf1 object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'protocolVersion';
    yield serializers.serialize(
      object.protocolVersion,
      specifiedType: const FullType(int),
    );
    yield r'pairingId';
    yield serializers.serialize(
      object.pairingId,
      specifiedType: const FullType(String),
    );
    yield r'accountContextId';
    yield serializers.serialize(
      object.accountContextId,
      specifiedType: const FullType(String),
    );
    yield r'challenge';
    yield serializers.serialize(
      object.challenge,
      specifiedType: const FullType(String),
    );
    yield r'expiresAt';
    yield serializers.serialize(
      object.expiresAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'targetDevice';
    yield serializers.serialize(
      object.targetDevice,
      specifiedType: const FullType(DevicePairingCreateDataTargetDevice),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(DevicePairingQueryDataOneOf1StatusEnum),
    );
    yield r'issuerDeviceId';
    yield serializers.serialize(
      object.issuerDeviceId,
      specifiedType: const FullType(String),
    );
    yield r'issuerKeyVersion';
    yield serializers.serialize(
      object.issuerKeyVersion,
      specifiedType: const FullType(int),
    );
    yield r'issuerAuthGeneration';
    yield serializers.serialize(
      object.issuerAuthGeneration,
      specifiedType: const FullType(int),
    );
    yield r'issuerSigningPublicKey';
    yield serializers.serialize(
      object.issuerSigningPublicKey,
      specifiedType: const FullType(String),
    );
    yield r'issuerKeyAgreementPublicKey';
    yield serializers.serialize(
      object.issuerKeyAgreementPublicKey,
      specifiedType: const FullType(String),
    );
    yield r'keyEpoch';
    yield serializers.serialize(
      object.keyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'accountKeyEnvelope';
    yield serializers.serialize(
      object.accountKeyEnvelope,
      specifiedType: const FullType(String),
    );
    yield r'deviceProof';
    yield serializers.serialize(
      object.deviceProof,
      specifiedType: const FullType(String),
    );
    yield r'pairingAuthenticator';
    yield serializers.serialize(
      object.pairingAuthenticator,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DevicePairingQueryDataOneOf1 object, {
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
    required DevicePairingQueryDataOneOf1Builder result,
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
        case r'pairingId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.pairingId = valueDes;
          break;
        case r'accountContextId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.accountContextId = valueDes;
          break;
        case r'challenge':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.challenge = valueDes;
          break;
        case r'expiresAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.expiresAt = valueDes;
          break;
        case r'targetDevice':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      DevicePairingCreateDataTargetDevice,
                    ),
                  )
                  as DevicePairingCreateDataTargetDevice;
          result.targetDevice.replace(valueDes);
          break;
        case r'status':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      DevicePairingQueryDataOneOf1StatusEnum,
                    ),
                  )
                  as DevicePairingQueryDataOneOf1StatusEnum;
          result.status = valueDes;
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
        case r'issuerKeyVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.issuerKeyVersion = valueDes;
          break;
        case r'issuerAuthGeneration':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.issuerAuthGeneration = valueDes;
          break;
        case r'issuerSigningPublicKey':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.issuerSigningPublicKey = valueDes;
          break;
        case r'issuerKeyAgreementPublicKey':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.issuerKeyAgreementPublicKey = valueDes;
          break;
        case r'keyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.keyEpoch = valueDes;
          break;
        case r'accountKeyEnvelope':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.accountKeyEnvelope = valueDes;
          break;
        case r'deviceProof':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.deviceProof = valueDes;
          break;
        case r'pairingAuthenticator':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.pairingAuthenticator = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DevicePairingQueryDataOneOf1 deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DevicePairingQueryDataOneOf1Builder();
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

class DevicePairingQueryDataOneOf1StatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'approved')
  static const DevicePairingQueryDataOneOf1StatusEnum approved =
      _$devicePairingQueryDataOneOf1StatusEnum_approved;

  static Serializer<DevicePairingQueryDataOneOf1StatusEnum> get serializer =>
      _$devicePairingQueryDataOneOf1StatusEnumSerializer;

  const DevicePairingQueryDataOneOf1StatusEnum._(String name) : super(name);

  static BuiltSet<DevicePairingQueryDataOneOf1StatusEnum> get values =>
      _$devicePairingQueryDataOneOf1StatusEnumValues;
  static DevicePairingQueryDataOneOf1StatusEnum valueOf(String name) =>
      _$devicePairingQueryDataOneOf1StatusEnumValueOf(name);
}
