//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/account_recovery_replacement_challenge_data_device_state.dart';
import 'package:kelivo_sync_api_client/src/model/account_recovery_replacement_challenge_data_data_state.dart';
import 'package:kelivo_sync_api_client/src/model/account_recovery_replacement_challenge_data_security_state.dart';
import 'package:built_collection/built_collection.dart';
import 'package:kelivo_sync_api_client/src/model/data_rekey_completion_proof_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'account_recovery_replacement_challenge_data.g.dart';

/// AccountRecoveryReplacementChallengeData
///
/// Properties:
/// * [result]
/// * [protocolVersion]
/// * [challengeId]
/// * [attemptId]
/// * [requestDigest]
/// * [challengeFrame]
/// * [sealedNonce]
/// * [deviceState]
/// * [securityState]
/// * [dataState]
/// * [sourceCompletion]
/// * [expiresAt]
@BuiltValue()
abstract class AccountRecoveryReplacementChallengeData
    implements
        Built<
          AccountRecoveryReplacementChallengeData,
          AccountRecoveryReplacementChallengeDataBuilder
        > {
  @BuiltValueField(wireName: r'result')
  AccountRecoveryReplacementChallengeDataResultEnum get result;
  // enum resultEnum {  created,  replayed,  };

  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'challengeId')
  String get challengeId;

  @BuiltValueField(wireName: r'attemptId')
  String get attemptId;

  @BuiltValueField(wireName: r'requestDigest')
  String get requestDigest;

  @BuiltValueField(wireName: r'challengeFrame')
  String get challengeFrame;

  @BuiltValueField(wireName: r'sealedNonce')
  String get sealedNonce;

  @BuiltValueField(wireName: r'deviceState')
  AccountRecoveryReplacementChallengeDataDeviceState get deviceState;

  @BuiltValueField(wireName: r'securityState')
  AccountRecoveryReplacementChallengeDataSecurityState get securityState;

  @BuiltValueField(wireName: r'dataState')
  AccountRecoveryReplacementChallengeDataDataState get dataState;

  @BuiltValueField(wireName: r'sourceCompletion')
  DataRekeyCompletionProofData get sourceCompletion;

  @BuiltValueField(wireName: r'expiresAt')
  DateTime get expiresAt;

  AccountRecoveryReplacementChallengeData._();

  factory AccountRecoveryReplacementChallengeData([
    void updates(AccountRecoveryReplacementChallengeDataBuilder b),
  ]) = _$AccountRecoveryReplacementChallengeData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AccountRecoveryReplacementChallengeDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AccountRecoveryReplacementChallengeData> get serializer =>
      _$AccountRecoveryReplacementChallengeDataSerializer();
}

class _$AccountRecoveryReplacementChallengeDataSerializer
    implements PrimitiveSerializer<AccountRecoveryReplacementChallengeData> {
  @override
  final Iterable<Type> types = const [
    AccountRecoveryReplacementChallengeData,
    _$AccountRecoveryReplacementChallengeData,
  ];

  @override
  final String wireName = r'AccountRecoveryReplacementChallengeData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AccountRecoveryReplacementChallengeData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'result';
    yield serializers.serialize(
      object.result,
      specifiedType: const FullType(
        AccountRecoveryReplacementChallengeDataResultEnum,
      ),
    );
    yield r'protocolVersion';
    yield serializers.serialize(
      object.protocolVersion,
      specifiedType: const FullType(int),
    );
    yield r'challengeId';
    yield serializers.serialize(
      object.challengeId,
      specifiedType: const FullType(String),
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
    yield r'deviceState';
    yield serializers.serialize(
      object.deviceState,
      specifiedType: const FullType(
        AccountRecoveryReplacementChallengeDataDeviceState,
      ),
    );
    yield r'securityState';
    yield serializers.serialize(
      object.securityState,
      specifiedType: const FullType(
        AccountRecoveryReplacementChallengeDataSecurityState,
      ),
    );
    yield r'dataState';
    yield serializers.serialize(
      object.dataState,
      specifiedType: const FullType(
        AccountRecoveryReplacementChallengeDataDataState,
      ),
    );
    yield r'sourceCompletion';
    yield serializers.serialize(
      object.sourceCompletion,
      specifiedType: const FullType(DataRekeyCompletionProofData),
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
    AccountRecoveryReplacementChallengeData object, {
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
    required AccountRecoveryReplacementChallengeDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'result':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AccountRecoveryReplacementChallengeDataResultEnum,
                    ),
                  )
                  as AccountRecoveryReplacementChallengeDataResultEnum;
          result.result = valueDes;
          break;
        case r'protocolVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.protocolVersion = valueDes;
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
        case r'deviceState':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AccountRecoveryReplacementChallengeDataDeviceState,
                    ),
                  )
                  as AccountRecoveryReplacementChallengeDataDeviceState;
          result.deviceState.replace(valueDes);
          break;
        case r'securityState':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AccountRecoveryReplacementChallengeDataSecurityState,
                    ),
                  )
                  as AccountRecoveryReplacementChallengeDataSecurityState;
          result.securityState.replace(valueDes);
          break;
        case r'dataState':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AccountRecoveryReplacementChallengeDataDataState,
                    ),
                  )
                  as AccountRecoveryReplacementChallengeDataDataState;
          result.dataState.replace(valueDes);
          break;
        case r'sourceCompletion':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DataRekeyCompletionProofData),
                  )
                  as DataRekeyCompletionProofData;
          result.sourceCompletion.replace(valueDes);
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
  AccountRecoveryReplacementChallengeData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AccountRecoveryReplacementChallengeDataBuilder();
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

class AccountRecoveryReplacementChallengeDataResultEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'created')
  static const AccountRecoveryReplacementChallengeDataResultEnum created =
      _$accountRecoveryReplacementChallengeDataResultEnum_created;
  @BuiltValueEnumConst(wireName: r'replayed')
  static const AccountRecoveryReplacementChallengeDataResultEnum replayed =
      _$accountRecoveryReplacementChallengeDataResultEnum_replayed;

  static Serializer<AccountRecoveryReplacementChallengeDataResultEnum>
  get serializer =>
      _$accountRecoveryReplacementChallengeDataResultEnumSerializer;

  const AccountRecoveryReplacementChallengeDataResultEnum._(String name)
    : super(name);

  static BuiltSet<AccountRecoveryReplacementChallengeDataResultEnum>
  get values => _$accountRecoveryReplacementChallengeDataResultEnumValues;
  static AccountRecoveryReplacementChallengeDataResultEnum valueOf(
    String name,
  ) => _$accountRecoveryReplacementChallengeDataResultEnumValueOf(name);
}
