//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'account_recovery_attempt_start_request_one_of1.g.dart';

/// AccountRecoveryAttemptStartRequestOneOf1
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
abstract class AccountRecoveryAttemptStartRequestOneOf1
    implements
        Built<
          AccountRecoveryAttemptStartRequestOneOf1,
          AccountRecoveryAttemptStartRequestOneOf1Builder
        > {
  @BuiltValueField(wireName: r'action')
  AccountRecoveryAttemptStartRequestOneOf1ActionEnum get action;
  // enum actionEnum {  authorize,  };

  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'attemptId')
  String get attemptId;

  @BuiltValueField(wireName: r'challengeRequestDigest')
  String get challengeRequestDigest;

  @BuiltValueField(wireName: r'recoveryToken')
  String get recoveryToken;

  @BuiltValueField(wireName: r'nonceProof')
  String get nonceProof;

  @BuiltValueField(wireName: r'trustSignature')
  String get trustSignature;

  AccountRecoveryAttemptStartRequestOneOf1._();

  factory AccountRecoveryAttemptStartRequestOneOf1([
    void updates(AccountRecoveryAttemptStartRequestOneOf1Builder b),
  ]) = _$AccountRecoveryAttemptStartRequestOneOf1;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AccountRecoveryAttemptStartRequestOneOf1Builder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AccountRecoveryAttemptStartRequestOneOf1> get serializer =>
      _$AccountRecoveryAttemptStartRequestOneOf1Serializer();
}

class _$AccountRecoveryAttemptStartRequestOneOf1Serializer
    implements PrimitiveSerializer<AccountRecoveryAttemptStartRequestOneOf1> {
  @override
  final Iterable<Type> types = const [
    AccountRecoveryAttemptStartRequestOneOf1,
    _$AccountRecoveryAttemptStartRequestOneOf1,
  ];

  @override
  final String wireName = r'AccountRecoveryAttemptStartRequestOneOf1';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AccountRecoveryAttemptStartRequestOneOf1 object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'action';
    yield serializers.serialize(
      object.action,
      specifiedType: const FullType(
        AccountRecoveryAttemptStartRequestOneOf1ActionEnum,
      ),
    );
    yield r'protocolVersion';
    yield serializers.serialize(
      object.protocolVersion,
      specifiedType: const FullType(int),
    );
    yield r'attemptId';
    yield serializers.serialize(
      object.attemptId,
      specifiedType: const FullType(String),
    );
    yield r'challengeRequestDigest';
    yield serializers.serialize(
      object.challengeRequestDigest,
      specifiedType: const FullType(String),
    );
    yield r'recoveryToken';
    yield serializers.serialize(
      object.recoveryToken,
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
    AccountRecoveryAttemptStartRequestOneOf1 object, {
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
    required AccountRecoveryAttemptStartRequestOneOf1Builder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'action':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AccountRecoveryAttemptStartRequestOneOf1ActionEnum,
                    ),
                  )
                  as AccountRecoveryAttemptStartRequestOneOf1ActionEnum;
          result.action = valueDes;
          break;
        case r'protocolVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.protocolVersion = valueDes;
          break;
        case r'attemptId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.attemptId = valueDes;
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
        case r'recoveryToken':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.recoveryToken = valueDes;
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
  AccountRecoveryAttemptStartRequestOneOf1 deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AccountRecoveryAttemptStartRequestOneOf1Builder();
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

class AccountRecoveryAttemptStartRequestOneOf1ActionEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'authorize')
  static const AccountRecoveryAttemptStartRequestOneOf1ActionEnum authorize =
      _$accountRecoveryAttemptStartRequestOneOf1ActionEnum_authorize;

  static Serializer<AccountRecoveryAttemptStartRequestOneOf1ActionEnum>
  get serializer =>
      _$accountRecoveryAttemptStartRequestOneOf1ActionEnumSerializer;

  const AccountRecoveryAttemptStartRequestOneOf1ActionEnum._(String name)
    : super(name);

  static BuiltSet<AccountRecoveryAttemptStartRequestOneOf1ActionEnum>
  get values => _$accountRecoveryAttemptStartRequestOneOf1ActionEnumValues;
  static AccountRecoveryAttemptStartRequestOneOf1ActionEnum valueOf(
    String name,
  ) => _$accountRecoveryAttemptStartRequestOneOf1ActionEnumValueOf(name);
}
