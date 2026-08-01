//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/account_recovery_attempt_start_request_one_of1.dart';
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/account_recovery_attempt_start_request_one_of.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:one_of/one_of.dart';

part 'account_recovery_attempt_start_request.g.dart';

/// AccountRecoveryAttemptStartRequest
///
/// Properties:
/// * [action]
/// * [protocolVersion]
/// * [attemptId]
/// * [challengeRequestDigest]
/// * [recoveryToken]
/// * [nonceProof]
/// * [trustSignature]
@BuiltValue()
abstract class AccountRecoveryAttemptStartRequest
    implements
        Built<
          AccountRecoveryAttemptStartRequest,
          AccountRecoveryAttemptStartRequestBuilder
        > {
  /// One Of [AccountRecoveryAttemptStartRequestOneOf], [AccountRecoveryAttemptStartRequestOneOf1]
  OneOf get oneOf;

  AccountRecoveryAttemptStartRequest._();

  factory AccountRecoveryAttemptStartRequest([
    void updates(AccountRecoveryAttemptStartRequestBuilder b),
  ]) = _$AccountRecoveryAttemptStartRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AccountRecoveryAttemptStartRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AccountRecoveryAttemptStartRequest> get serializer =>
      _$AccountRecoveryAttemptStartRequestSerializer();
}

class _$AccountRecoveryAttemptStartRequestSerializer
    implements PrimitiveSerializer<AccountRecoveryAttemptStartRequest> {
  @override
  final Iterable<Type> types = const [
    AccountRecoveryAttemptStartRequest,
    _$AccountRecoveryAttemptStartRequest,
  ];

  @override
  final String wireName = r'AccountRecoveryAttemptStartRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AccountRecoveryAttemptStartRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {}

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryAttemptStartRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final oneOf = object.oneOf;
    return serializers.serialize(
      oneOf.value,
      specifiedType: FullType(oneOf.valueType),
    )!;
  }

  @override
  AccountRecoveryAttemptStartRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AccountRecoveryAttemptStartRequestBuilder();
    Object? oneOfDataSrc;
    final targetType = const FullType(OneOf, [
      FullType(AccountRecoveryAttemptStartRequestOneOf),
      FullType(AccountRecoveryAttemptStartRequestOneOf1),
    ]);
    oneOfDataSrc = serialized;
    result.oneOf =
        serializers.deserialize(oneOfDataSrc, specifiedType: targetType)
            as OneOf;
    return result.build();
  }
}

class AccountRecoveryAttemptStartRequestActionEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'authorize')
  static const AccountRecoveryAttemptStartRequestActionEnum authorize =
      _$accountRecoveryAttemptStartRequestActionEnum_authorize;

  static Serializer<AccountRecoveryAttemptStartRequestActionEnum>
  get serializer => _$accountRecoveryAttemptStartRequestActionEnumSerializer;

  const AccountRecoveryAttemptStartRequestActionEnum._(String name)
    : super(name);

  static BuiltSet<AccountRecoveryAttemptStartRequestActionEnum> get values =>
      _$accountRecoveryAttemptStartRequestActionEnumValues;
  static AccountRecoveryAttemptStartRequestActionEnum valueOf(String name) =>
      _$accountRecoveryAttemptStartRequestActionEnumValueOf(name);
}
