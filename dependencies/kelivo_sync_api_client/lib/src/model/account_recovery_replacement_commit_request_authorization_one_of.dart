//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'account_recovery_replacement_commit_request_authorization_one_of.g.dart';

/// AccountRecoveryReplacementCommitRequestAuthorizationOneOf
///
/// Properties:
/// * [kind]
/// * [challengeRequestDigest]
@BuiltValue()
abstract class AccountRecoveryReplacementCommitRequestAuthorizationOneOf
    implements
        Built<
          AccountRecoveryReplacementCommitRequestAuthorizationOneOf,
          AccountRecoveryReplacementCommitRequestAuthorizationOneOfBuilder
        > {
  @BuiltValueField(wireName: r'kind')
  AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum get kind;
  // enum kindEnum {  initial,  };

  @BuiltValueField(wireName: r'challengeRequestDigest')
  String get challengeRequestDigest;

  AccountRecoveryReplacementCommitRequestAuthorizationOneOf._();

  factory AccountRecoveryReplacementCommitRequestAuthorizationOneOf([
    void updates(
      AccountRecoveryReplacementCommitRequestAuthorizationOneOfBuilder b,
    ),
  ]) = _$AccountRecoveryReplacementCommitRequestAuthorizationOneOf;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(
    AccountRecoveryReplacementCommitRequestAuthorizationOneOfBuilder b,
  ) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AccountRecoveryReplacementCommitRequestAuthorizationOneOf>
  get serializer =>
      _$AccountRecoveryReplacementCommitRequestAuthorizationOneOfSerializer();
}

class _$AccountRecoveryReplacementCommitRequestAuthorizationOneOfSerializer
    implements
        PrimitiveSerializer<
          AccountRecoveryReplacementCommitRequestAuthorizationOneOf
        > {
  @override
  final Iterable<Type> types = const [
    AccountRecoveryReplacementCommitRequestAuthorizationOneOf,
    _$AccountRecoveryReplacementCommitRequestAuthorizationOneOf,
  ];

  @override
  final String wireName =
      r'AccountRecoveryReplacementCommitRequestAuthorizationOneOf';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AccountRecoveryReplacementCommitRequestAuthorizationOneOf object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'kind';
    yield serializers.serialize(
      object.kind,
      specifiedType: const FullType(
        AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum,
      ),
    );
    yield r'challengeRequestDigest';
    yield serializers.serialize(
      object.challengeRequestDigest,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryReplacementCommitRequestAuthorizationOneOf object, {
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
    required AccountRecoveryReplacementCommitRequestAuthorizationOneOfBuilder
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
                      AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum,
                    ),
                  )
                  as AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum;
          result.kind = valueDes;
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AccountRecoveryReplacementCommitRequestAuthorizationOneOf deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result =
        AccountRecoveryReplacementCommitRequestAuthorizationOneOfBuilder();
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

class AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum
    extends EnumClass {
  @BuiltValueEnumConst(wireName: r'initial')
  static const AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum
  initial =
      _$accountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum_initial;

  static Serializer<
    AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum
  >
  get serializer =>
      _$accountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnumSerializer;

  const AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum._(
    String name,
  ) : super(name);

  static BuiltSet<
    AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum
  >
  get values =>
      _$accountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnumValues;
  static AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum
  valueOf(String name) =>
      _$accountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnumValueOf(
        name,
      );
}
