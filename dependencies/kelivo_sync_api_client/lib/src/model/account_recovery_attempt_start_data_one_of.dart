//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/account_recovery_data_state.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'account_recovery_attempt_start_data_one_of.g.dart';

/// AccountRecoveryAttemptStartDataOneOf
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
@BuiltValue()
abstract class AccountRecoveryAttemptStartDataOneOf
    implements
        Built<
          AccountRecoveryAttemptStartDataOneOf,
          AccountRecoveryAttemptStartDataOneOfBuilder
        > {
  @BuiltValueField(wireName: r'action')
  AccountRecoveryAttemptStartDataOneOfActionEnum get action;
  // enum actionEnum {  challenge,  };

  @BuiltValueField(wireName: r'result')
  AccountRecoveryAttemptStartDataOneOfResultEnum get result;
  // enum resultEnum {  created,  replayed,  };

  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'attemptId')
  String get attemptId;

  @BuiltValueField(wireName: r'requestDigest')
  String get requestDigest;

  @BuiltValueField(wireName: r'challengeFrame')
  String get challengeFrame;

  @BuiltValueField(wireName: r'sealedNonce')
  String get sealedNonce;

  @BuiltValueField(wireName: r'securityGeneration')
  int get securityGeneration;

  @BuiltValueField(wireName: r'keyEpoch')
  int get keyEpoch;

  @BuiltValueField(wireName: r'membershipManifestDigest')
  String get membershipManifestDigest;

  @BuiltValueField(wireName: r'recoveryPublicKeyVersion')
  int get recoveryPublicKeyVersion;

  @BuiltValueField(wireName: r'recoveryPublicKey')
  String get recoveryPublicKey;

  @BuiltValueField(wireName: r'recoveryCapsuleVersion')
  int get recoveryCapsuleVersion;

  @BuiltValueField(wireName: r'recoveryCapsule')
  String get recoveryCapsule;

  @BuiltValueField(wireName: r'recoveryCapsuleDigest')
  String get recoveryCapsuleDigest;

  @BuiltValueField(wireName: r'dataState')
  AccountRecoveryDataState get dataState;

  @BuiltValueField(wireName: r'expiresAt')
  DateTime get expiresAt;

  AccountRecoveryAttemptStartDataOneOf._();

  factory AccountRecoveryAttemptStartDataOneOf([
    void updates(AccountRecoveryAttemptStartDataOneOfBuilder b),
  ]) = _$AccountRecoveryAttemptStartDataOneOf;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AccountRecoveryAttemptStartDataOneOfBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AccountRecoveryAttemptStartDataOneOf> get serializer =>
      _$AccountRecoveryAttemptStartDataOneOfSerializer();
}

class _$AccountRecoveryAttemptStartDataOneOfSerializer
    implements PrimitiveSerializer<AccountRecoveryAttemptStartDataOneOf> {
  @override
  final Iterable<Type> types = const [
    AccountRecoveryAttemptStartDataOneOf,
    _$AccountRecoveryAttemptStartDataOneOf,
  ];

  @override
  final String wireName = r'AccountRecoveryAttemptStartDataOneOf';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AccountRecoveryAttemptStartDataOneOf object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'action';
    yield serializers.serialize(
      object.action,
      specifiedType: const FullType(
        AccountRecoveryAttemptStartDataOneOfActionEnum,
      ),
    );
    yield r'result';
    yield serializers.serialize(
      object.result,
      specifiedType: const FullType(
        AccountRecoveryAttemptStartDataOneOfResultEnum,
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
    yield r'requestDigest';
    yield serializers.serialize(
      object.requestDigest,
      specifiedType: const FullType(String),
    );
    yield r'challengeFrame';
    yield serializers.serialize(
      object.challengeFrame,
      specifiedType: const FullType(String),
    );
    yield r'sealedNonce';
    yield serializers.serialize(
      object.sealedNonce,
      specifiedType: const FullType(String),
    );
    yield r'securityGeneration';
    yield serializers.serialize(
      object.securityGeneration,
      specifiedType: const FullType(int),
    );
    yield r'keyEpoch';
    yield serializers.serialize(
      object.keyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'membershipManifestDigest';
    yield serializers.serialize(
      object.membershipManifestDigest,
      specifiedType: const FullType(String),
    );
    yield r'recoveryPublicKeyVersion';
    yield serializers.serialize(
      object.recoveryPublicKeyVersion,
      specifiedType: const FullType(int),
    );
    yield r'recoveryPublicKey';
    yield serializers.serialize(
      object.recoveryPublicKey,
      specifiedType: const FullType(String),
    );
    yield r'recoveryCapsuleVersion';
    yield serializers.serialize(
      object.recoveryCapsuleVersion,
      specifiedType: const FullType(int),
    );
    yield r'recoveryCapsule';
    yield serializers.serialize(
      object.recoveryCapsule,
      specifiedType: const FullType(String),
    );
    yield r'recoveryCapsuleDigest';
    yield serializers.serialize(
      object.recoveryCapsuleDigest,
      specifiedType: const FullType(String),
    );
    yield r'dataState';
    yield serializers.serialize(
      object.dataState,
      specifiedType: const FullType(AccountRecoveryDataState),
    );
    yield r'expiresAt';
    yield serializers.serialize(
      object.expiresAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryAttemptStartDataOneOf object, {
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
    required AccountRecoveryAttemptStartDataOneOfBuilder result,
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
                      AccountRecoveryAttemptStartDataOneOfActionEnum,
                    ),
                  )
                  as AccountRecoveryAttemptStartDataOneOfActionEnum;
          result.action = valueDes;
          break;
        case r'result':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AccountRecoveryAttemptStartDataOneOfResultEnum,
                    ),
                  )
                  as AccountRecoveryAttemptStartDataOneOfResultEnum;
          result.result = valueDes;
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
        case r'requestDigest':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.requestDigest = valueDes;
          break;
        case r'challengeFrame':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.challengeFrame = valueDes;
          break;
        case r'sealedNonce':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.sealedNonce = valueDes;
          break;
        case r'securityGeneration':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.securityGeneration = valueDes;
          break;
        case r'keyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.keyEpoch = valueDes;
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
        case r'recoveryPublicKeyVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.recoveryPublicKeyVersion = valueDes;
          break;
        case r'recoveryPublicKey':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.recoveryPublicKey = valueDes;
          break;
        case r'recoveryCapsuleVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.recoveryCapsuleVersion = valueDes;
          break;
        case r'recoveryCapsule':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.recoveryCapsule = valueDes;
          break;
        case r'recoveryCapsuleDigest':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.recoveryCapsuleDigest = valueDes;
          break;
        case r'dataState':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(AccountRecoveryDataState),
                  )
                  as AccountRecoveryDataState;
          result.dataState.replace(valueDes);
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AccountRecoveryAttemptStartDataOneOf deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AccountRecoveryAttemptStartDataOneOfBuilder();
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

class AccountRecoveryAttemptStartDataOneOfActionEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'challenge')
  static const AccountRecoveryAttemptStartDataOneOfActionEnum challenge =
      _$accountRecoveryAttemptStartDataOneOfActionEnum_challenge;

  static Serializer<AccountRecoveryAttemptStartDataOneOfActionEnum>
  get serializer => _$accountRecoveryAttemptStartDataOneOfActionEnumSerializer;

  const AccountRecoveryAttemptStartDataOneOfActionEnum._(String name)
    : super(name);

  static BuiltSet<AccountRecoveryAttemptStartDataOneOfActionEnum> get values =>
      _$accountRecoveryAttemptStartDataOneOfActionEnumValues;
  static AccountRecoveryAttemptStartDataOneOfActionEnum valueOf(String name) =>
      _$accountRecoveryAttemptStartDataOneOfActionEnumValueOf(name);
}

class AccountRecoveryAttemptStartDataOneOfResultEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'created')
  static const AccountRecoveryAttemptStartDataOneOfResultEnum created =
      _$accountRecoveryAttemptStartDataOneOfResultEnum_created;
  @BuiltValueEnumConst(wireName: r'replayed')
  static const AccountRecoveryAttemptStartDataOneOfResultEnum replayed =
      _$accountRecoveryAttemptStartDataOneOfResultEnum_replayed;

  static Serializer<AccountRecoveryAttemptStartDataOneOfResultEnum>
  get serializer => _$accountRecoveryAttemptStartDataOneOfResultEnumSerializer;

  const AccountRecoveryAttemptStartDataOneOfResultEnum._(String name)
    : super(name);

  static BuiltSet<AccountRecoveryAttemptStartDataOneOfResultEnum> get values =>
      _$accountRecoveryAttemptStartDataOneOfResultEnumValues;
  static AccountRecoveryAttemptStartDataOneOfResultEnum valueOf(String name) =>
      _$accountRecoveryAttemptStartDataOneOfResultEnumValueOf(name);
}
