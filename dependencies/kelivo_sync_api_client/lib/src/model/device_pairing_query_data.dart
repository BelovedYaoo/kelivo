//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/device_pairing_query_data_one_of.dart';
import 'package:kelivo_sync_api_client/src/model/device_pairing_create_data_target_device.dart';
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/device_pairing_query_data_one_of1.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:one_of/one_of.dart';

part 'device_pairing_query_data.g.dart';

/// DevicePairingQueryData
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
/// * [issuerSigningPublicKey]
/// * [issuerKeyAgreementPublicKey]
/// * [keyEpoch]
/// * [accountKeyEnvelope]
/// * [deviceProof]
/// * [pairingAuthenticator]
@BuiltValue()
abstract class DevicePairingQueryData
    implements Built<DevicePairingQueryData, DevicePairingQueryDataBuilder> {
  /// One Of [DevicePairingQueryDataOneOf], [DevicePairingQueryDataOneOf1]
  OneOf get oneOf;

  DevicePairingQueryData._();

  factory DevicePairingQueryData([
    void updates(DevicePairingQueryDataBuilder b),
  ]) = _$DevicePairingQueryData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DevicePairingQueryDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DevicePairingQueryData> get serializer =>
      _$DevicePairingQueryDataSerializer();
}

class _$DevicePairingQueryDataSerializer
    implements PrimitiveSerializer<DevicePairingQueryData> {
  @override
  final Iterable<Type> types = const [
    DevicePairingQueryData,
    _$DevicePairingQueryData,
  ];

  @override
  final String wireName = r'DevicePairingQueryData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DevicePairingQueryData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {}

  @override
  Object serialize(
    Serializers serializers,
    DevicePairingQueryData object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final oneOf = object.oneOf;
    return serializers.serialize(
      oneOf.value,
      specifiedType: FullType(oneOf.valueType),
    )!;
  }

  @override
  DevicePairingQueryData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DevicePairingQueryDataBuilder();
    Object? oneOfDataSrc;
    final targetType = const FullType(OneOf, [
      FullType(DevicePairingQueryDataOneOf),
      FullType(DevicePairingQueryDataOneOf1),
    ]);
    oneOfDataSrc = serialized;
    result.oneOf =
        serializers.deserialize(oneOfDataSrc, specifiedType: targetType)
            as OneOf;
    return result.build();
  }
}

class DevicePairingQueryDataStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'approved')
  static const DevicePairingQueryDataStatusEnum approved =
      _$devicePairingQueryDataStatusEnum_approved;

  static Serializer<DevicePairingQueryDataStatusEnum> get serializer =>
      _$devicePairingQueryDataStatusEnumSerializer;

  const DevicePairingQueryDataStatusEnum._(String name) : super(name);

  static BuiltSet<DevicePairingQueryDataStatusEnum> get values =>
      _$devicePairingQueryDataStatusEnumValues;
  static DevicePairingQueryDataStatusEnum valueOf(String name) =>
      _$devicePairingQueryDataStatusEnumValueOf(name);
}
