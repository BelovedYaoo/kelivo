//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'account_recovery_replacement_commit_request_authorization_one_of1.g.dart';

/// AccountRecoveryReplacementCommitRequestAuthorizationOneOf1
///
/// Properties:
/// * [kind]
/// * [challengeId]
/// * [challengeRequestDigest]
/// * [nonceProof]
/// * [trustSignature]
@BuiltValue()
abstract class AccountRecoveryReplacementCommitRequestAuthorizationOneOf1
    implements
        Built<
          AccountRecoveryReplacementCommitRequestAuthorizationOneOf1,
          AccountRecoveryReplacementCommitRequestAuthorizationOneOf1Builder
        > {
  @BuiltValueField(wireName: r'kind')
  AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum get kind;
  // enum kindEnum {  replacement-challenge,  };

  @BuiltValueField(wireName: r'challengeId')
  String get challengeId;

  @BuiltValueField(wireName: r'challengeRequestDigest')
  String get challengeRequestDigest;

  @BuiltValueField(wireName: r'nonceProof')
  String get nonceProof;

  @BuiltValueField(wireName: r'trustSignature')
  String get trustSignature;

  AccountRecoveryReplacementCommitRequestAuthorizationOneOf1._();

  factory AccountRecoveryReplacementCommitRequestAuthorizationOneOf1([
    void updates(
      AccountRecoveryReplacementCommitRequestAuthorizationOneOf1Builder b,
    ),
  ]) = _$AccountRecoveryReplacementCommitRequestAuthorizationOneOf1;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(
    AccountRecoveryReplacementCommitRequestAuthorizationOneOf1Builder b,
  ) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AccountRecoveryReplacementCommitRequestAuthorizationOneOf1>
  get serializer =>
      _$AccountRecoveryReplacementCommitRequestAuthorizationOneOf1Serializer();
}

class _$AccountRecoveryReplacementCommitRequestAuthorizationOneOf1Serializer
    implements
        PrimitiveSerializer<
          AccountRecoveryReplacementCommitRequestAuthorizationOneOf1
        > {
  @override
  final Iterable<Type> types = const [
    AccountRecoveryReplacementCommitRequestAuthorizationOneOf1,
    _$AccountRecoveryReplacementCommitRequestAuthorizationOneOf1,
  ];

  @override
  final String wireName =
      r'AccountRecoveryReplacementCommitRequestAuthorizationOneOf1';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AccountRecoveryReplacementCommitRequestAuthorizationOneOf1 object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'kind';
    yield serializers.serialize(
      object.kind,
      specifiedType: const FullType(
        AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum,
      ),
    );
    yield r'challengeId';
    yield serializers.serialize(
      object.challengeId,
      specifiedType: const FullType(String),
    );
    yield r'challengeRequestDigest';
    yield serializers.serialize(
      object.challengeRequestDigest,
      specifiedType: const FullType(String),
    );
    yield r'nonceProof';
    yield serializers.serialize(
      object.nonceProof,
      specifiedType: const FullType(String),
    );
    yield r'trustSignature';
    yield serializers.serialize(
      object.trustSignature,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryReplacementCommitRequestAuthorizationOneOf1 object, {
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
    required AccountRecoveryReplacementCommitRequestAuthorizationOneOf1Builder
    result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'kind':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum,
                    ),
                  )
                  as AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum;
          result.kind = valueDes;
          break;
        case r'challengeId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.challengeId = valueDes;
          break;
        case r'challengeRequestDigest':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.challengeRequestDigest = valueDes;
          break;
        case r'nonceProof':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.nonceProof = valueDes;
          break;
        case r'trustSignature':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.trustSignature = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AccountRecoveryReplacementCommitRequestAuthorizationOneOf1 deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result =
        AccountRecoveryReplacementCommitRequestAuthorizationOneOf1Builder();
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

class AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum
    extends EnumClass {
  @BuiltValueEnumConst(wireName: r'replacement-challenge')
  static const AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum
  replacementChallenge =
      _$accountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum_replacementChallenge;

  static Serializer<
    AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum
  >
  get serializer =>
      _$accountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnumSerializer;

  const AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum._(
    String name,
  ) : super(name);

  static BuiltSet<
    AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum
  >
  get values =>
      _$accountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnumValues;
  static AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum
  valueOf(String name) =>
      _$accountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnumValueOf(
        name,
      );
}
