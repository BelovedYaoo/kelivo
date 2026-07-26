//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/opaque_login_finish_data_one_of.dart';
import 'package:kelivo_sync_api_client/src/model/opaque_login_finish_data_one_of1_device.dart';
import 'package:kelivo_sync_api_client/src/model/opaque_registration_finish_data_user.dart';
import 'package:kelivo_sync_api_client/src/model/opaque_login_finish_data_one_of1.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:one_of/one_of.dart';

part 'opaque_login_finish_data.g.dart';

/// OpaqueLoginFinishData
///
/// Properties:
/// * [protocolVersion]
/// * [result]
/// * [keyEpoch]
/// * [token]
/// * [tokenExpiresAt]
/// * [user]
/// * [device]
/// * [onboardingToken]
/// * [onboardingTokenExpiresAt]
@BuiltValue()
abstract class OpaqueLoginFinishData
    implements Built<OpaqueLoginFinishData, OpaqueLoginFinishDataBuilder> {
  /// One Of [OpaqueLoginFinishDataOneOf], [OpaqueLoginFinishDataOneOf1]
  OneOf get oneOf;

  OpaqueLoginFinishData._();

  factory OpaqueLoginFinishData([
    void updates(OpaqueLoginFinishDataBuilder b),
  ]) = _$OpaqueLoginFinishData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(OpaqueLoginFinishDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<OpaqueLoginFinishData> get serializer =>
      _$OpaqueLoginFinishDataSerializer();
}

class _$OpaqueLoginFinishDataSerializer
    implements PrimitiveSerializer<OpaqueLoginFinishData> {
  @override
  final Iterable<Type> types = const [
    OpaqueLoginFinishData,
    _$OpaqueLoginFinishData,
  ];

  @override
  final String wireName = r'OpaqueLoginFinishData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    OpaqueLoginFinishData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {}

  @override
  Object serialize(
    Serializers serializers,
    OpaqueLoginFinishData object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final oneOf = object.oneOf;
    return serializers.serialize(
      oneOf.value,
      specifiedType: FullType(oneOf.valueType),
    )!;
  }

  @override
  OpaqueLoginFinishData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = OpaqueLoginFinishDataBuilder();
    Object? oneOfDataSrc;
    final targetType = const FullType(OneOf, [
      FullType(OpaqueLoginFinishDataOneOf),
      FullType(OpaqueLoginFinishDataOneOf1),
    ]);
    oneOfDataSrc = serialized;
    result.oneOf =
        serializers.deserialize(oneOfDataSrc, specifiedType: targetType)
            as OneOf;
    return result.build();
  }
}

class OpaqueLoginFinishDataResultEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'device-approval-required')
  static const OpaqueLoginFinishDataResultEnum deviceApprovalRequired =
      _$opaqueLoginFinishDataResultEnum_deviceApprovalRequired;

  static Serializer<OpaqueLoginFinishDataResultEnum> get serializer =>
      _$opaqueLoginFinishDataResultEnumSerializer;

  const OpaqueLoginFinishDataResultEnum._(String name) : super(name);

  static BuiltSet<OpaqueLoginFinishDataResultEnum> get values =>
      _$opaqueLoginFinishDataResultEnumValues;
  static OpaqueLoginFinishDataResultEnum valueOf(String name) =>
      _$opaqueLoginFinishDataResultEnumValueOf(name);
}
