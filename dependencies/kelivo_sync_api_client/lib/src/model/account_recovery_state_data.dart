//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelivo_sync_api_client/src/model/account_security_state_data.dart';
import 'package:kelivo_sync_api_client/src/model/account_recovery_data_state.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'account_recovery_state_data.g.dart';

/// AccountRecoveryStateData
///
/// Properties:
/// * [protocolVersion]
/// * [attemptId]
/// * [status]
/// * [nextAction]
/// * [authorizedAt]
/// * [recoveryTokenExpiresAt]
/// * [securityState]
/// * [dataState]
@BuiltValue()
abstract class AccountRecoveryStateData
    implements
        Built<AccountRecoveryStateData, AccountRecoveryStateDataBuilder> {
  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'attemptId')
  String get attemptId;

  @BuiltValueField(wireName: r'status')
  AccountRecoveryStateDataStatusEnum get status;
  // enum statusEnum {  authorized,  resume-committed,  replacement-committed,  };

  @BuiltValueField(wireName: r'nextAction')
  AccountRecoveryStateDataNextActionEnum get nextAction;
  // enum nextActionEnum {  recover-resume,  finish-first-data-rekey,  create-replacement-challenge,  recover-replace,  finish-second-data-rekey,  };

  @BuiltValueField(wireName: r'authorizedAt')
  DateTime get authorizedAt;

  @BuiltValueField(wireName: r'recoveryTokenExpiresAt')
  DateTime get recoveryTokenExpiresAt;

  @BuiltValueField(wireName: r'securityState')
  AccountSecurityStateData get securityState;

  @BuiltValueField(wireName: r'dataState')
  AccountRecoveryDataState get dataState;

  AccountRecoveryStateData._();

  factory AccountRecoveryStateData([
    void updates(AccountRecoveryStateDataBuilder b),
  ]) = _$AccountRecoveryStateData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AccountRecoveryStateDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AccountRecoveryStateData> get serializer =>
      _$AccountRecoveryStateDataSerializer();
}

class _$AccountRecoveryStateDataSerializer
    implements PrimitiveSerializer<AccountRecoveryStateData> {
  @override
  final Iterable<Type> types = const [
    AccountRecoveryStateData,
    _$AccountRecoveryStateData,
  ];

  @override
  final String wireName = r'AccountRecoveryStateData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AccountRecoveryStateData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
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
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(AccountRecoveryStateDataStatusEnum),
    );
    yield r'nextAction';
    yield serializers.serialize(
      object.nextAction,
      specifiedType: const FullType(AccountRecoveryStateDataNextActionEnum),
    );
    yield r'authorizedAt';
    yield serializers.serialize(
      object.authorizedAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'recoveryTokenExpiresAt';
    yield serializers.serialize(
      object.recoveryTokenExpiresAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'securityState';
    yield serializers.serialize(
      object.securityState,
      specifiedType: const FullType(AccountSecurityStateData),
    );
    yield r'dataState';
    yield serializers.serialize(
      object.dataState,
      specifiedType: const FullType(AccountRecoveryDataState),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryStateData object, {
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
    required AccountRecoveryStateDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
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
        case r'status':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AccountRecoveryStateDataStatusEnum,
                    ),
                  )
                  as AccountRecoveryStateDataStatusEnum;
          result.status = valueDes;
          break;
        case r'nextAction':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AccountRecoveryStateDataNextActionEnum,
                    ),
                  )
                  as AccountRecoveryStateDataNextActionEnum;
          result.nextAction = valueDes;
          break;
        case r'authorizedAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.authorizedAt = valueDes;
          break;
        case r'recoveryTokenExpiresAt':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(DateTime),
                  )
                  as DateTime;
          result.recoveryTokenExpiresAt = valueDes;
          break;
        case r'securityState':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(AccountSecurityStateData),
                  )
                  as AccountSecurityStateData;
          result.securityState.replace(valueDes);
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AccountRecoveryStateData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AccountRecoveryStateDataBuilder();
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

class AccountRecoveryStateDataStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'authorized')
  static const AccountRecoveryStateDataStatusEnum authorized =
      _$accountRecoveryStateDataStatusEnum_authorized;
  @BuiltValueEnumConst(wireName: r'resume-committed')
  static const AccountRecoveryStateDataStatusEnum resumeCommitted =
      _$accountRecoveryStateDataStatusEnum_resumeCommitted;
  @BuiltValueEnumConst(wireName: r'replacement-committed')
  static const AccountRecoveryStateDataStatusEnum replacementCommitted =
      _$accountRecoveryStateDataStatusEnum_replacementCommitted;

  static Serializer<AccountRecoveryStateDataStatusEnum> get serializer =>
      _$accountRecoveryStateDataStatusEnumSerializer;

  const AccountRecoveryStateDataStatusEnum._(String name) : super(name);

  static BuiltSet<AccountRecoveryStateDataStatusEnum> get values =>
      _$accountRecoveryStateDataStatusEnumValues;
  static AccountRecoveryStateDataStatusEnum valueOf(String name) =>
      _$accountRecoveryStateDataStatusEnumValueOf(name);
}

class AccountRecoveryStateDataNextActionEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'recover-resume')
  static const AccountRecoveryStateDataNextActionEnum recoverResume =
      _$accountRecoveryStateDataNextActionEnum_recoverResume;
  @BuiltValueEnumConst(wireName: r'finish-first-data-rekey')
  static const AccountRecoveryStateDataNextActionEnum finishFirstDataRekey =
      _$accountRecoveryStateDataNextActionEnum_finishFirstDataRekey;
  @BuiltValueEnumConst(wireName: r'create-replacement-challenge')
  static const AccountRecoveryStateDataNextActionEnum
  createReplacementChallenge =
      _$accountRecoveryStateDataNextActionEnum_createReplacementChallenge;
  @BuiltValueEnumConst(wireName: r'recover-replace')
  static const AccountRecoveryStateDataNextActionEnum recoverReplace =
      _$accountRecoveryStateDataNextActionEnum_recoverReplace;
  @BuiltValueEnumConst(wireName: r'finish-second-data-rekey')
  static const AccountRecoveryStateDataNextActionEnum finishSecondDataRekey =
      _$accountRecoveryStateDataNextActionEnum_finishSecondDataRekey;

  static Serializer<AccountRecoveryStateDataNextActionEnum> get serializer =>
      _$accountRecoveryStateDataNextActionEnumSerializer;

  const AccountRecoveryStateDataNextActionEnum._(String name) : super(name);

  static BuiltSet<AccountRecoveryStateDataNextActionEnum> get values =>
      _$accountRecoveryStateDataNextActionEnumValues;
  static AccountRecoveryStateDataNextActionEnum valueOf(String name) =>
      _$accountRecoveryStateDataNextActionEnumValueOf(name);
}
