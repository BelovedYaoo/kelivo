//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'account_recovery_attempt_start_data_one_of1.g.dart';

/// AccountRecoveryAttemptStartDataOneOf1
///
/// Properties:
/// * [action]
/// * [result]
/// * [protocolVersion]
/// * [attemptId]
/// * [status]
/// * [nextAction]
/// * [recoveryTokenExpiresAt]
@BuiltValue()
abstract class AccountRecoveryAttemptStartDataOneOf1
    implements
        Built<
          AccountRecoveryAttemptStartDataOneOf1,
          AccountRecoveryAttemptStartDataOneOf1Builder
        > {
  @BuiltValueField(wireName: r'action')
  AccountRecoveryAttemptStartDataOneOf1ActionEnum get action;
  // enum actionEnum {  authorized,  };

  @BuiltValueField(wireName: r'result')
  AccountRecoveryAttemptStartDataOneOf1ResultEnum get result;
  // enum resultEnum {  authorized,  replayed,  };

  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'attemptId')
  String get attemptId;

  @BuiltValueField(wireName: r'status')
  AccountRecoveryAttemptStartDataOneOf1StatusEnum get status;
  // enum statusEnum {  authorized,  };

  @BuiltValueField(wireName: r'nextAction')
  AccountRecoveryAttemptStartDataOneOf1NextActionEnum get nextAction;
  // enum nextActionEnum {  recover-resume,  recover-replace,  };

  @BuiltValueField(wireName: r'recoveryTokenExpiresAt')
  DateTime get recoveryTokenExpiresAt;

  AccountRecoveryAttemptStartDataOneOf1._();

  factory AccountRecoveryAttemptStartDataOneOf1([
    void updates(AccountRecoveryAttemptStartDataOneOf1Builder b),
  ]) = _$AccountRecoveryAttemptStartDataOneOf1;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AccountRecoveryAttemptStartDataOneOf1Builder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AccountRecoveryAttemptStartDataOneOf1> get serializer =>
      _$AccountRecoveryAttemptStartDataOneOf1Serializer();
}

class _$AccountRecoveryAttemptStartDataOneOf1Serializer
    implements PrimitiveSerializer<AccountRecoveryAttemptStartDataOneOf1> {
  @override
  final Iterable<Type> types = const [
    AccountRecoveryAttemptStartDataOneOf1,
    _$AccountRecoveryAttemptStartDataOneOf1,
  ];

  @override
  final String wireName = r'AccountRecoveryAttemptStartDataOneOf1';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AccountRecoveryAttemptStartDataOneOf1 object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'action';
    yield serializers.serialize(
      object.action,
      specifiedType: const FullType(
        AccountRecoveryAttemptStartDataOneOf1ActionEnum,
      ),
    );
    yield r'result';
    yield serializers.serialize(
      object.result,
      specifiedType: const FullType(
        AccountRecoveryAttemptStartDataOneOf1ResultEnum,
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
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(
        AccountRecoveryAttemptStartDataOneOf1StatusEnum,
      ),
    );
    yield r'nextAction';
    yield serializers.serialize(
      object.nextAction,
      specifiedType: const FullType(
        AccountRecoveryAttemptStartDataOneOf1NextActionEnum,
      ),
    );
    yield r'recoveryTokenExpiresAt';
    yield serializers.serialize(
      object.recoveryTokenExpiresAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryAttemptStartDataOneOf1 object, {
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
    required AccountRecoveryAttemptStartDataOneOf1Builder result,
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
                      AccountRecoveryAttemptStartDataOneOf1ActionEnum,
                    ),
                  )
                  as AccountRecoveryAttemptStartDataOneOf1ActionEnum;
          result.action = valueDes;
          break;
        case r'result':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AccountRecoveryAttemptStartDataOneOf1ResultEnum,
                    ),
                  )
                  as AccountRecoveryAttemptStartDataOneOf1ResultEnum;
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
        case r'status':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AccountRecoveryAttemptStartDataOneOf1StatusEnum,
                    ),
                  )
                  as AccountRecoveryAttemptStartDataOneOf1StatusEnum;
          result.status = valueDes;
          break;
        case r'nextAction':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AccountRecoveryAttemptStartDataOneOf1NextActionEnum,
                    ),
                  )
                  as AccountRecoveryAttemptStartDataOneOf1NextActionEnum;
          result.nextAction = valueDes;
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AccountRecoveryAttemptStartDataOneOf1 deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AccountRecoveryAttemptStartDataOneOf1Builder();
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

class AccountRecoveryAttemptStartDataOneOf1ActionEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'authorized')
  static const AccountRecoveryAttemptStartDataOneOf1ActionEnum authorized =
      _$accountRecoveryAttemptStartDataOneOf1ActionEnum_authorized;

  static Serializer<AccountRecoveryAttemptStartDataOneOf1ActionEnum>
  get serializer => _$accountRecoveryAttemptStartDataOneOf1ActionEnumSerializer;

  const AccountRecoveryAttemptStartDataOneOf1ActionEnum._(String name)
    : super(name);

  static BuiltSet<AccountRecoveryAttemptStartDataOneOf1ActionEnum> get values =>
      _$accountRecoveryAttemptStartDataOneOf1ActionEnumValues;
  static AccountRecoveryAttemptStartDataOneOf1ActionEnum valueOf(String name) =>
      _$accountRecoveryAttemptStartDataOneOf1ActionEnumValueOf(name);
}

class AccountRecoveryAttemptStartDataOneOf1ResultEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'authorized')
  static const AccountRecoveryAttemptStartDataOneOf1ResultEnum authorized =
      _$accountRecoveryAttemptStartDataOneOf1ResultEnum_authorized;
  @BuiltValueEnumConst(wireName: r'replayed')
  static const AccountRecoveryAttemptStartDataOneOf1ResultEnum replayed =
      _$accountRecoveryAttemptStartDataOneOf1ResultEnum_replayed;

  static Serializer<AccountRecoveryAttemptStartDataOneOf1ResultEnum>
  get serializer => _$accountRecoveryAttemptStartDataOneOf1ResultEnumSerializer;

  const AccountRecoveryAttemptStartDataOneOf1ResultEnum._(String name)
    : super(name);

  static BuiltSet<AccountRecoveryAttemptStartDataOneOf1ResultEnum> get values =>
      _$accountRecoveryAttemptStartDataOneOf1ResultEnumValues;
  static AccountRecoveryAttemptStartDataOneOf1ResultEnum valueOf(String name) =>
      _$accountRecoveryAttemptStartDataOneOf1ResultEnumValueOf(name);
}

class AccountRecoveryAttemptStartDataOneOf1StatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'authorized')
  static const AccountRecoveryAttemptStartDataOneOf1StatusEnum authorized =
      _$accountRecoveryAttemptStartDataOneOf1StatusEnum_authorized;

  static Serializer<AccountRecoveryAttemptStartDataOneOf1StatusEnum>
  get serializer => _$accountRecoveryAttemptStartDataOneOf1StatusEnumSerializer;

  const AccountRecoveryAttemptStartDataOneOf1StatusEnum._(String name)
    : super(name);

  static BuiltSet<AccountRecoveryAttemptStartDataOneOf1StatusEnum> get values =>
      _$accountRecoveryAttemptStartDataOneOf1StatusEnumValues;
  static AccountRecoveryAttemptStartDataOneOf1StatusEnum valueOf(String name) =>
      _$accountRecoveryAttemptStartDataOneOf1StatusEnumValueOf(name);
}

class AccountRecoveryAttemptStartDataOneOf1NextActionEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'recover-resume')
  static const AccountRecoveryAttemptStartDataOneOf1NextActionEnum
  recoverResume =
      _$accountRecoveryAttemptStartDataOneOf1NextActionEnum_recoverResume;
  @BuiltValueEnumConst(wireName: r'recover-replace')
  static const AccountRecoveryAttemptStartDataOneOf1NextActionEnum
  recoverReplace =
      _$accountRecoveryAttemptStartDataOneOf1NextActionEnum_recoverReplace;

  static Serializer<AccountRecoveryAttemptStartDataOneOf1NextActionEnum>
  get serializer =>
      _$accountRecoveryAttemptStartDataOneOf1NextActionEnumSerializer;

  const AccountRecoveryAttemptStartDataOneOf1NextActionEnum._(String name)
    : super(name);

  static BuiltSet<AccountRecoveryAttemptStartDataOneOf1NextActionEnum>
  get values => _$accountRecoveryAttemptStartDataOneOf1NextActionEnumValues;
  static AccountRecoveryAttemptStartDataOneOf1NextActionEnum valueOf(
    String name,
  ) => _$accountRecoveryAttemptStartDataOneOf1NextActionEnumValueOf(name);
}
