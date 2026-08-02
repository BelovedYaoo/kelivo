//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/self_revocation_status_data_one_of4.dart';
import 'package:kelivo_sync_api_client/src/model/self_revocation_status_data_one_of1.dart';
import 'package:kelivo_sync_api_client/src/model/self_revocation_status_data_one_of1_receipt.dart';
import 'package:kelivo_sync_api_client/src/model/self_revocation_status_data_one_of.dart';
import 'package:kelivo_sync_api_client/src/model/self_revocation_status_data_one_of3.dart';
import 'package:kelivo_sync_api_client/src/model/self_revocation_status_data_one_of2.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:one_of/one_of.dart';

part 'self_revocation_status_data.g.dart';

/// SelfRevocationStatusData
///
/// Properties:
/// * [status]
/// * [deviceId]
/// * [mutationId]
/// * [operationId]
/// * [expectedGeneration]
/// * [expectedKeyEpoch]
/// * [expectedMembershipManifestDigest]
/// * [intentDigest]
/// * [intentSignature]
/// * [requestedAt]
/// * [expiresAt]
/// * [receiptExpiresAt]
/// * [receipt]
/// * [cancelledAt]
@BuiltValue()
abstract class SelfRevocationStatusData
    implements
        Built<SelfRevocationStatusData, SelfRevocationStatusDataBuilder> {
  /// One Of [SelfRevocationStatusDataOneOf], [SelfRevocationStatusDataOneOf1], [SelfRevocationStatusDataOneOf2], [SelfRevocationStatusDataOneOf3], [SelfRevocationStatusDataOneOf4]
  OneOf get oneOf;

  SelfRevocationStatusData._();

  factory SelfRevocationStatusData([
    void updates(SelfRevocationStatusDataBuilder b),
  ]) = _$SelfRevocationStatusData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SelfRevocationStatusDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SelfRevocationStatusData> get serializer =>
      _$SelfRevocationStatusDataSerializer();
}

class _$SelfRevocationStatusDataSerializer
    implements PrimitiveSerializer<SelfRevocationStatusData> {
  @override
  final Iterable<Type> types = const [
    SelfRevocationStatusData,
    _$SelfRevocationStatusData,
  ];

  @override
  final String wireName = r'SelfRevocationStatusData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SelfRevocationStatusData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {}

  @override
  Object serialize(
    Serializers serializers,
    SelfRevocationStatusData object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final oneOf = object.oneOf;
    return serializers.serialize(
      oneOf.value,
      specifiedType: FullType(oneOf.valueType),
    )!;
  }

  @override
  SelfRevocationStatusData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SelfRevocationStatusDataBuilder();
    Object? oneOfDataSrc;
    final targetType = const FullType(OneOf, [
      FullType(SelfRevocationStatusDataOneOf),
      FullType(SelfRevocationStatusDataOneOf1),
      FullType(SelfRevocationStatusDataOneOf2),
      FullType(SelfRevocationStatusDataOneOf3),
      FullType(SelfRevocationStatusDataOneOf4),
    ]);
    oneOfDataSrc = serialized;
    result.oneOf =
        serializers.deserialize(oneOfDataSrc, specifiedType: targetType)
            as OneOf;
    return result.build();
  }
}

class SelfRevocationStatusDataStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'superseded')
  static const SelfRevocationStatusDataStatusEnum superseded =
      _$selfRevocationStatusDataStatusEnum_superseded;

  static Serializer<SelfRevocationStatusDataStatusEnum> get serializer =>
      _$selfRevocationStatusDataStatusEnumSerializer;

  const SelfRevocationStatusDataStatusEnum._(String name) : super(name);

  static BuiltSet<SelfRevocationStatusDataStatusEnum> get values =>
      _$selfRevocationStatusDataStatusEnumValues;
  static SelfRevocationStatusDataStatusEnum valueOf(String name) =>
      _$selfRevocationStatusDataStatusEnumValueOf(name);
}
