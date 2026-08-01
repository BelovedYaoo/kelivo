//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'account_recovery_membership_commit_data.g.dart';

/// AccountRecoveryMembershipCommitData
///
/// Properties:
/// * [result]
/// * [attemptId]
/// * [status]
/// * [membershipOperationId]
/// * [rekeyOperationId]
/// * [generation]
/// * [keyEpoch]
/// * [nextAction]
@BuiltValue()
abstract class AccountRecoveryMembershipCommitData
    implements
        Built<
          AccountRecoveryMembershipCommitData,
          AccountRecoveryMembershipCommitDataBuilder
        > {
  @BuiltValueField(wireName: r'result')
  AccountRecoveryMembershipCommitDataResultEnum get result;
  // enum resultEnum {  committed,  replayed,  };

  @BuiltValueField(wireName: r'attemptId')
  String get attemptId;

  @BuiltValueField(wireName: r'status')
  AccountRecoveryMembershipCommitDataStatusEnum get status;
  // enum statusEnum {  resume-committed,  replacement-committed,  };

  @BuiltValueField(wireName: r'membershipOperationId')
  String get membershipOperationId;

  @BuiltValueField(wireName: r'rekeyOperationId')
  String get rekeyOperationId;

  @BuiltValueField(wireName: r'generation')
  int get generation;

  @BuiltValueField(wireName: r'keyEpoch')
  int get keyEpoch;

  @BuiltValueField(wireName: r'nextAction')
  AccountRecoveryMembershipCommitDataNextActionEnum get nextAction;
  // enum nextActionEnum {  finish-first-data-rekey,  finish-second-data-rekey,  };

  AccountRecoveryMembershipCommitData._();

  factory AccountRecoveryMembershipCommitData([
    void updates(AccountRecoveryMembershipCommitDataBuilder b),
  ]) = _$AccountRecoveryMembershipCommitData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AccountRecoveryMembershipCommitDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AccountRecoveryMembershipCommitData> get serializer =>
      _$AccountRecoveryMembershipCommitDataSerializer();
}

class _$AccountRecoveryMembershipCommitDataSerializer
    implements PrimitiveSerializer<AccountRecoveryMembershipCommitData> {
  @override
  final Iterable<Type> types = const [
    AccountRecoveryMembershipCommitData,
    _$AccountRecoveryMembershipCommitData,
  ];

  @override
  final String wireName = r'AccountRecoveryMembershipCommitData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AccountRecoveryMembershipCommitData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'result';
    yield serializers.serialize(
      object.result,
      specifiedType: const FullType(
        AccountRecoveryMembershipCommitDataResultEnum,
      ),
    );
    yield r'attemptId';
    yield serializers.serialize(
      object.attemptId,
      specifiedType: const FullType(String),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(
        AccountRecoveryMembershipCommitDataStatusEnum,
      ),
    );
    yield r'membershipOperationId';
    yield serializers.serialize(
      object.membershipOperationId,
      specifiedType: const FullType(String),
    );
    yield r'rekeyOperationId';
    yield serializers.serialize(
      object.rekeyOperationId,
      specifiedType: const FullType(String),
    );
    yield r'generation';
    yield serializers.serialize(
      object.generation,
      specifiedType: const FullType(int),
    );
    yield r'keyEpoch';
    yield serializers.serialize(
      object.keyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'nextAction';
    yield serializers.serialize(
      object.nextAction,
      specifiedType: const FullType(
        AccountRecoveryMembershipCommitDataNextActionEnum,
      ),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryMembershipCommitData object, {
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
    required AccountRecoveryMembershipCommitDataBuilder result,
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
                      AccountRecoveryMembershipCommitDataResultEnum,
                    ),
                  )
                  as AccountRecoveryMembershipCommitDataResultEnum;
          result.result = valueDes;
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
                      AccountRecoveryMembershipCommitDataStatusEnum,
                    ),
                  )
                  as AccountRecoveryMembershipCommitDataStatusEnum;
          result.status = valueDes;
          break;
        case r'membershipOperationId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.membershipOperationId = valueDes;
          break;
        case r'rekeyOperationId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.rekeyOperationId = valueDes;
          break;
        case r'generation':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.generation = valueDes;
          break;
        case r'keyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.keyEpoch = valueDes;
          break;
        case r'nextAction':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AccountRecoveryMembershipCommitDataNextActionEnum,
                    ),
                  )
                  as AccountRecoveryMembershipCommitDataNextActionEnum;
          result.nextAction = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AccountRecoveryMembershipCommitData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AccountRecoveryMembershipCommitDataBuilder();
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

class AccountRecoveryMembershipCommitDataResultEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'committed')
  static const AccountRecoveryMembershipCommitDataResultEnum committed =
      _$accountRecoveryMembershipCommitDataResultEnum_committed;
  @BuiltValueEnumConst(wireName: r'replayed')
  static const AccountRecoveryMembershipCommitDataResultEnum replayed =
      _$accountRecoveryMembershipCommitDataResultEnum_replayed;

  static Serializer<AccountRecoveryMembershipCommitDataResultEnum>
  get serializer => _$accountRecoveryMembershipCommitDataResultEnumSerializer;

  const AccountRecoveryMembershipCommitDataResultEnum._(String name)
    : super(name);

  static BuiltSet<AccountRecoveryMembershipCommitDataResultEnum> get values =>
      _$accountRecoveryMembershipCommitDataResultEnumValues;
  static AccountRecoveryMembershipCommitDataResultEnum valueOf(String name) =>
      _$accountRecoveryMembershipCommitDataResultEnumValueOf(name);
}

class AccountRecoveryMembershipCommitDataStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'resume-committed')
  static const AccountRecoveryMembershipCommitDataStatusEnum resumeCommitted =
      _$accountRecoveryMembershipCommitDataStatusEnum_resumeCommitted;
  @BuiltValueEnumConst(wireName: r'replacement-committed')
  static const AccountRecoveryMembershipCommitDataStatusEnum
  replacementCommitted =
      _$accountRecoveryMembershipCommitDataStatusEnum_replacementCommitted;

  static Serializer<AccountRecoveryMembershipCommitDataStatusEnum>
  get serializer => _$accountRecoveryMembershipCommitDataStatusEnumSerializer;

  const AccountRecoveryMembershipCommitDataStatusEnum._(String name)
    : super(name);

  static BuiltSet<AccountRecoveryMembershipCommitDataStatusEnum> get values =>
      _$accountRecoveryMembershipCommitDataStatusEnumValues;
  static AccountRecoveryMembershipCommitDataStatusEnum valueOf(String name) =>
      _$accountRecoveryMembershipCommitDataStatusEnumValueOf(name);
}

class AccountRecoveryMembershipCommitDataNextActionEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'finish-first-data-rekey')
  static const AccountRecoveryMembershipCommitDataNextActionEnum
  finishFirstDataRekey =
      _$accountRecoveryMembershipCommitDataNextActionEnum_finishFirstDataRekey;
  @BuiltValueEnumConst(wireName: r'finish-second-data-rekey')
  static const AccountRecoveryMembershipCommitDataNextActionEnum
  finishSecondDataRekey =
      _$accountRecoveryMembershipCommitDataNextActionEnum_finishSecondDataRekey;

  static Serializer<AccountRecoveryMembershipCommitDataNextActionEnum>
  get serializer =>
      _$accountRecoveryMembershipCommitDataNextActionEnumSerializer;

  const AccountRecoveryMembershipCommitDataNextActionEnum._(String name)
    : super(name);

  static BuiltSet<AccountRecoveryMembershipCommitDataNextActionEnum>
  get values => _$accountRecoveryMembershipCommitDataNextActionEnumValues;
  static AccountRecoveryMembershipCommitDataNextActionEnum valueOf(
    String name,
  ) => _$accountRecoveryMembershipCommitDataNextActionEnumValueOf(name);
}
