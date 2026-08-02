//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'account_recovery_replacement_challenge_data_device_state.g.dart';

/// AccountRecoveryReplacementChallengeDataDeviceState
///
/// Properties:
/// * [keyVersion]
/// * [signingPublicKey]
/// * [keyAgreementPublicKey]
@BuiltValue()
abstract class AccountRecoveryReplacementChallengeDataDeviceState
    implements
        Built<
          AccountRecoveryReplacementChallengeDataDeviceState,
          AccountRecoveryReplacementChallengeDataDeviceStateBuilder
        > {
  @BuiltValueField(wireName: r'keyVersion')
  int get keyVersion;

  @BuiltValueField(wireName: r'signingPublicKey')
  String get signingPublicKey;

  @BuiltValueField(wireName: r'keyAgreementPublicKey')
  String get keyAgreementPublicKey;

  AccountRecoveryReplacementChallengeDataDeviceState._();

  factory AccountRecoveryReplacementChallengeDataDeviceState([
    void updates(AccountRecoveryReplacementChallengeDataDeviceStateBuilder b),
  ]) = _$AccountRecoveryReplacementChallengeDataDeviceState;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(
    AccountRecoveryReplacementChallengeDataDeviceStateBuilder b,
  ) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AccountRecoveryReplacementChallengeDataDeviceState>
  get serializer =>
      _$AccountRecoveryReplacementChallengeDataDeviceStateSerializer();
}

class _$AccountRecoveryReplacementChallengeDataDeviceStateSerializer
    implements
        PrimitiveSerializer<
          AccountRecoveryReplacementChallengeDataDeviceState
        > {
  @override
  final Iterable<Type> types = const [
    AccountRecoveryReplacementChallengeDataDeviceState,
    _$AccountRecoveryReplacementChallengeDataDeviceState,
  ];

  @override
  final String wireName = r'AccountRecoveryReplacementChallengeDataDeviceState';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AccountRecoveryReplacementChallengeDataDeviceState object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'keyVersion';
    yield serializers.serialize(
      object.keyVersion,
      specifiedType: const FullType(int),
    );
    yield r'signingPublicKey';
    yield serializers.serialize(
      object.signingPublicKey,
      specifiedType: const FullType(String),
    );
    yield r'keyAgreementPublicKey';
    yield serializers.serialize(
      object.keyAgreementPublicKey,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryReplacementChallengeDataDeviceState object, {
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
    required AccountRecoveryReplacementChallengeDataDeviceStateBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'keyVersion':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.keyVersion = valueDes;
          break;
        case r'signingPublicKey':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.signingPublicKey = valueDes;
          break;
        case r'keyAgreementPublicKey':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.keyAgreementPublicKey = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AccountRecoveryReplacementChallengeDataDeviceState deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AccountRecoveryReplacementChallengeDataDeviceStateBuilder();
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
