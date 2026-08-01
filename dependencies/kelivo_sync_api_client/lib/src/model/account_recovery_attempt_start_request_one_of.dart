//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'account_recovery_attempt_start_request_one_of.g.dart';

/// AccountRecoveryAttemptStartRequestOneOf
///
/// Properties:
/// * [action]
/// * [protocolVersion]
/// * [attemptId]
@BuiltValue()
abstract class AccountRecoveryAttemptStartRequestOneOf
    implements
        Built<
          AccountRecoveryAttemptStartRequestOneOf,
          AccountRecoveryAttemptStartRequestOneOfBuilder
        > {
  @BuiltValueField(wireName: r'action')
  AccountRecoveryAttemptStartRequestOneOfActionEnum get action;
  // enum actionEnum {  challenge,  };

  @BuiltValueField(wireName: r'protocolVersion')
  int get protocolVersion;

  @BuiltValueField(wireName: r'attemptId')
  String get attemptId;

  AccountRecoveryAttemptStartRequestOneOf._();

  factory AccountRecoveryAttemptStartRequestOneOf([
    void updates(AccountRecoveryAttemptStartRequestOneOfBuilder b),
  ]) = _$AccountRecoveryAttemptStartRequestOneOf;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AccountRecoveryAttemptStartRequestOneOfBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AccountRecoveryAttemptStartRequestOneOf> get serializer =>
      _$AccountRecoveryAttemptStartRequestOneOfSerializer();
}

class _$AccountRecoveryAttemptStartRequestOneOfSerializer
    implements PrimitiveSerializer<AccountRecoveryAttemptStartRequestOneOf> {
  @override
  final Iterable<Type> types = const [
    AccountRecoveryAttemptStartRequestOneOf,
    _$AccountRecoveryAttemptStartRequestOneOf,
  ];

  @override
  final String wireName = r'AccountRecoveryAttemptStartRequestOneOf';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AccountRecoveryAttemptStartRequestOneOf object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'action';
    yield serializers.serialize(
      object.action,
      specifiedType: const FullType(
        AccountRecoveryAttemptStartRequestOneOfActionEnum,
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
  }

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryAttemptStartRequestOneOf object, {
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
    required AccountRecoveryAttemptStartRequestOneOfBuilder result,
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
                      AccountRecoveryAttemptStartRequestOneOfActionEnum,
                    ),
                  )
                  as AccountRecoveryAttemptStartRequestOneOfActionEnum;
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AccountRecoveryAttemptStartRequestOneOf deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AccountRecoveryAttemptStartRequestOneOfBuilder();
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

class AccountRecoveryAttemptStartRequestOneOfActionEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'challenge')
  static const AccountRecoveryAttemptStartRequestOneOfActionEnum challenge =
      _$accountRecoveryAttemptStartRequestOneOfActionEnum_challenge;

  static Serializer<AccountRecoveryAttemptStartRequestOneOfActionEnum>
  get serializer =>
      _$accountRecoveryAttemptStartRequestOneOfActionEnumSerializer;

  const AccountRecoveryAttemptStartRequestOneOfActionEnum._(String name)
    : super(name);

  static BuiltSet<AccountRecoveryAttemptStartRequestOneOfActionEnum>
  get values => _$accountRecoveryAttemptStartRequestOneOfActionEnumValues;
  static AccountRecoveryAttemptStartRequestOneOfActionEnum valueOf(
    String name,
  ) => _$accountRecoveryAttemptStartRequestOneOfActionEnumValueOf(name);
}
