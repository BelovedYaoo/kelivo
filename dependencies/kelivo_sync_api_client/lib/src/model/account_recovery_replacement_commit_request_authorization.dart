//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/account_recovery_replacement_commit_request_authorization_one_of1.dart';
import 'package:kelivo_sync_api_client/src/model/account_recovery_replacement_commit_request_authorization_one_of.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:one_of/one_of.dart';

part 'account_recovery_replacement_commit_request_authorization.g.dart';

/// AccountRecoveryReplacementCommitRequestAuthorization
///
/// Properties:
/// * [kind]
/// * [challengeRequestDigest]
/// * [challengeId]
/// * [nonceProof]
/// * [trustSignature]
@BuiltValue()
abstract class AccountRecoveryReplacementCommitRequestAuthorization
    implements
        Built<
          AccountRecoveryReplacementCommitRequestAuthorization,
          AccountRecoveryReplacementCommitRequestAuthorizationBuilder
        > {
  /// One Of [AccountRecoveryReplacementCommitRequestAuthorizationOneOf], [AccountRecoveryReplacementCommitRequestAuthorizationOneOf1]
  OneOf get oneOf;

  AccountRecoveryReplacementCommitRequestAuthorization._();

  factory AccountRecoveryReplacementCommitRequestAuthorization([
    void updates(AccountRecoveryReplacementCommitRequestAuthorizationBuilder b),
  ]) = _$AccountRecoveryReplacementCommitRequestAuthorization;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(
    AccountRecoveryReplacementCommitRequestAuthorizationBuilder b,
  ) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AccountRecoveryReplacementCommitRequestAuthorization>
  get serializer =>
      _$AccountRecoveryReplacementCommitRequestAuthorizationSerializer();
}

class _$AccountRecoveryReplacementCommitRequestAuthorizationSerializer
    implements
        PrimitiveSerializer<
          AccountRecoveryReplacementCommitRequestAuthorization
        > {
  @override
  final Iterable<Type> types = const [
    AccountRecoveryReplacementCommitRequestAuthorization,
    _$AccountRecoveryReplacementCommitRequestAuthorization,
  ];

  @override
  final String wireName =
      r'AccountRecoveryReplacementCommitRequestAuthorization';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AccountRecoveryReplacementCommitRequestAuthorization object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {}

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryReplacementCommitRequestAuthorization object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final oneOf = object.oneOf;
    return serializers.serialize(
      oneOf.value,
      specifiedType: FullType(oneOf.valueType),
    )!;
  }

  @override
  AccountRecoveryReplacementCommitRequestAuthorization deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result =
        AccountRecoveryReplacementCommitRequestAuthorizationBuilder();
    Object? oneOfDataSrc;
    final targetType = const FullType(OneOf, [
      FullType(AccountRecoveryReplacementCommitRequestAuthorizationOneOf),
      FullType(AccountRecoveryReplacementCommitRequestAuthorizationOneOf1),
    ]);
    oneOfDataSrc = serialized;
    result.oneOf =
        serializers.deserialize(oneOfDataSrc, specifiedType: targetType)
            as OneOf;
    return result.build();
  }
}

class AccountRecoveryReplacementCommitRequestAuthorizationKindEnum
    extends EnumClass {
  @BuiltValueEnumConst(wireName: r'replacement-challenge')
  static const AccountRecoveryReplacementCommitRequestAuthorizationKindEnum
  replacementChallenge =
      _$accountRecoveryReplacementCommitRequestAuthorizationKindEnum_replacementChallenge;

  static Serializer<
    AccountRecoveryReplacementCommitRequestAuthorizationKindEnum
  >
  get serializer =>
      _$accountRecoveryReplacementCommitRequestAuthorizationKindEnumSerializer;

  const AccountRecoveryReplacementCommitRequestAuthorizationKindEnum._(
    String name,
  ) : super(name);

  static BuiltSet<AccountRecoveryReplacementCommitRequestAuthorizationKindEnum>
  get values =>
      _$accountRecoveryReplacementCommitRequestAuthorizationKindEnumValues;
  static AccountRecoveryReplacementCommitRequestAuthorizationKindEnum valueOf(
    String name,
  ) => _$accountRecoveryReplacementCommitRequestAuthorizationKindEnumValueOf(
    name,
  );
}
