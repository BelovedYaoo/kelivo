//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/account_recovery_attempt_start_data_one_of1.dart';
import 'package:kelivo_sync_api_client/src/model/account_recovery_data_state.dart';
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/account_recovery_attempt_start_data_one_of.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:one_of/one_of.dart';

part 'account_recovery_attempt_start_data.g.dart';

/// AccountRecoveryAttemptStartData
///
/// Properties:
/// * [action]
/// * [result]
/// * [protocolVersion]
/// * [attemptId]
/// * [requestDigest]
/// * [challengeFrame]
/// * [sealedNonce]
/// * [securityGeneration]
/// * [keyEpoch]
/// * [membershipManifestDigest]
/// * [recoveryPublicKeyVersion]
/// * [recoveryPublicKey]
/// * [recoveryCapsuleVersion]
/// * [recoveryCapsule]
/// * [recoveryCapsuleDigest]
/// * [dataState]
/// * [expiresAt]
/// * [status]
/// * [nextAction]
/// * [recoveryTokenExpiresAt]
@BuiltValue()
abstract class AccountRecoveryAttemptStartData
    implements
        Built<
          AccountRecoveryAttemptStartData,
          AccountRecoveryAttemptStartDataBuilder
        > {
  /// One Of [AccountRecoveryAttemptStartDataOneOf], [AccountRecoveryAttemptStartDataOneOf1]
  OneOf get oneOf;

  AccountRecoveryAttemptStartData._();

  factory AccountRecoveryAttemptStartData([
    void updates(AccountRecoveryAttemptStartDataBuilder b),
  ]) = _$AccountRecoveryAttemptStartData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AccountRecoveryAttemptStartDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AccountRecoveryAttemptStartData> get serializer =>
      _$AccountRecoveryAttemptStartDataSerializer();
}

class _$AccountRecoveryAttemptStartDataSerializer
    implements PrimitiveSerializer<AccountRecoveryAttemptStartData> {
  @override
  final Iterable<Type> types = const [
    AccountRecoveryAttemptStartData,
    _$AccountRecoveryAttemptStartData,
  ];

  @override
  final String wireName = r'AccountRecoveryAttemptStartData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AccountRecoveryAttemptStartData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {}

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryAttemptStartData object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final oneOf = object.oneOf;
    return serializers.serialize(
      oneOf.value,
      specifiedType: FullType(oneOf.valueType),
    )!;
  }

  @override
  AccountRecoveryAttemptStartData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AccountRecoveryAttemptStartDataBuilder();
    Object? oneOfDataSrc;
    final targetType = const FullType(OneOf, [
      FullType(AccountRecoveryAttemptStartDataOneOf),
      FullType(AccountRecoveryAttemptStartDataOneOf1),
    ]);
    oneOfDataSrc = serialized;
    result.oneOf =
        serializers.deserialize(oneOfDataSrc, specifiedType: targetType)
            as OneOf;
    return result.build();
  }
}

class AccountRecoveryAttemptStartDataActionEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'authorized')
  static const AccountRecoveryAttemptStartDataActionEnum authorized =
      _$accountRecoveryAttemptStartDataActionEnum_authorized;

  static Serializer<AccountRecoveryAttemptStartDataActionEnum> get serializer =>
      _$accountRecoveryAttemptStartDataActionEnumSerializer;

  const AccountRecoveryAttemptStartDataActionEnum._(String name) : super(name);

  static BuiltSet<AccountRecoveryAttemptStartDataActionEnum> get values =>
      _$accountRecoveryAttemptStartDataActionEnumValues;
  static AccountRecoveryAttemptStartDataActionEnum valueOf(String name) =>
      _$accountRecoveryAttemptStartDataActionEnumValueOf(name);
}

class AccountRecoveryAttemptStartDataResultEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'authorized')
  static const AccountRecoveryAttemptStartDataResultEnum authorized =
      _$accountRecoveryAttemptStartDataResultEnum_authorized;
  @BuiltValueEnumConst(wireName: r'replayed')
  static const AccountRecoveryAttemptStartDataResultEnum replayed =
      _$accountRecoveryAttemptStartDataResultEnum_replayed;

  static Serializer<AccountRecoveryAttemptStartDataResultEnum> get serializer =>
      _$accountRecoveryAttemptStartDataResultEnumSerializer;

  const AccountRecoveryAttemptStartDataResultEnum._(String name) : super(name);

  static BuiltSet<AccountRecoveryAttemptStartDataResultEnum> get values =>
      _$accountRecoveryAttemptStartDataResultEnumValues;
  static AccountRecoveryAttemptStartDataResultEnum valueOf(String name) =>
      _$accountRecoveryAttemptStartDataResultEnumValueOf(name);
}

class AccountRecoveryAttemptStartDataStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'authorized')
  static const AccountRecoveryAttemptStartDataStatusEnum authorized =
      _$accountRecoveryAttemptStartDataStatusEnum_authorized;

  static Serializer<AccountRecoveryAttemptStartDataStatusEnum> get serializer =>
      _$accountRecoveryAttemptStartDataStatusEnumSerializer;

  const AccountRecoveryAttemptStartDataStatusEnum._(String name) : super(name);

  static BuiltSet<AccountRecoveryAttemptStartDataStatusEnum> get values =>
      _$accountRecoveryAttemptStartDataStatusEnumValues;
  static AccountRecoveryAttemptStartDataStatusEnum valueOf(String name) =>
      _$accountRecoveryAttemptStartDataStatusEnumValueOf(name);
}

class AccountRecoveryAttemptStartDataNextActionEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'recover-resume')
  static const AccountRecoveryAttemptStartDataNextActionEnum recoverResume =
      _$accountRecoveryAttemptStartDataNextActionEnum_recoverResume;
  @BuiltValueEnumConst(wireName: r'recover-replace')
  static const AccountRecoveryAttemptStartDataNextActionEnum recoverReplace =
      _$accountRecoveryAttemptStartDataNextActionEnum_recoverReplace;

  static Serializer<AccountRecoveryAttemptStartDataNextActionEnum>
  get serializer => _$accountRecoveryAttemptStartDataNextActionEnumSerializer;

  const AccountRecoveryAttemptStartDataNextActionEnum._(String name)
    : super(name);

  static BuiltSet<AccountRecoveryAttemptStartDataNextActionEnum> get values =>
      _$accountRecoveryAttemptStartDataNextActionEnumValues;
  static AccountRecoveryAttemptStartDataNextActionEnum valueOf(String name) =>
      _$accountRecoveryAttemptStartDataNextActionEnumValueOf(name);
}
