//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'account_recovery_resume_commit_request_envelope.g.dart';

/// AccountRecoveryResumeCommitRequestEnvelope
///
/// Properties:
/// * [envelopeVersion]
/// * [keyEpoch]
/// * [accountKeyEnvelope]
@BuiltValue()
abstract class AccountRecoveryResumeCommitRequestEnvelope
    implements
        Built<
          AccountRecoveryResumeCommitRequestEnvelope,
          AccountRecoveryResumeCommitRequestEnvelopeBuilder
        > {
  @BuiltValueField(wireName: r'envelopeVersion')
  int get envelopeVersion;

  @BuiltValueField(wireName: r'keyEpoch')
  int get keyEpoch;

  @BuiltValueField(wireName: r'accountKeyEnvelope')
  String get accountKeyEnvelope;

  AccountRecoveryResumeCommitRequestEnvelope._();

  factory AccountRecoveryResumeCommitRequestEnvelope([
    void updates(AccountRecoveryResumeCommitRequestEnvelopeBuilder b),
  ]) = _$AccountRecoveryResumeCommitRequestEnvelope;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AccountRecoveryResumeCommitRequestEnvelopeBuilder b) =>
      b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AccountRecoveryResumeCommitRequestEnvelope>
  get serializer => _$AccountRecoveryResumeCommitRequestEnvelopeSerializer();
}

class _$AccountRecoveryResumeCommitRequestEnvelopeSerializer
    implements PrimitiveSerializer<AccountRecoveryResumeCommitRequestEnvelope> {
  @override
  final Iterable<Type> types = const [
    AccountRecoveryResumeCommitRequestEnvelope,
    _$AccountRecoveryResumeCommitRequestEnvelope,
  ];

  @override
  final String wireName = r'AccountRecoveryResumeCommitRequestEnvelope';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AccountRecoveryResumeCommitRequestEnvelope object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'envelopeVersion';
    yield serializers.serialize(
      object.envelopeVersion,
      specifiedType: const FullType(int),
    );
    yield r'keyEpoch';
    yield serializers.serialize(
      object.keyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'accountKeyEnvelope';
    yield serializers.serialize(
      object.accountKeyEnvelope,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryResumeCommitRequestEnvelope object, {
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
    required AccountRecoveryResumeCommitRequestEnvelopeBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'envelopeVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.envelopeVersion = valueDes;
          break;
        case r'keyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.keyEpoch = valueDes;
          break;
        case r'accountKeyEnvelope':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.accountKeyEnvelope = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AccountRecoveryResumeCommitRequestEnvelope deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AccountRecoveryResumeCommitRequestEnvelopeBuilder();
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
