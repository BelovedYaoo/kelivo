//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'account_recovery_replacement_challenge_data_data_state.g.dart';

/// AccountRecoveryReplacementChallengeDataDataState
///
/// Properties:
/// * [phase]
/// * [dataGeneration]
/// * [dataKeyEpoch]
/// * [sourceRekeyOperationId]
@BuiltValue()
abstract class AccountRecoveryReplacementChallengeDataDataState
    implements
        Built<
          AccountRecoveryReplacementChallengeDataDataState,
          AccountRecoveryReplacementChallengeDataDataStateBuilder
        > {
  @BuiltValueField(wireName: r'phase')
  AccountRecoveryReplacementChallengeDataDataStatePhaseEnum get phase;
  // enum phaseEnum {  ready,  };

  @BuiltValueField(wireName: r'dataGeneration')
  int get dataGeneration;

  @BuiltValueField(wireName: r'dataKeyEpoch')
  int get dataKeyEpoch;

  @BuiltValueField(wireName: r'sourceRekeyOperationId')
  String get sourceRekeyOperationId;

  AccountRecoveryReplacementChallengeDataDataState._();

  factory AccountRecoveryReplacementChallengeDataDataState([
    void updates(AccountRecoveryReplacementChallengeDataDataStateBuilder b),
  ]) = _$AccountRecoveryReplacementChallengeDataDataState;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(
    AccountRecoveryReplacementChallengeDataDataStateBuilder b,
  ) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AccountRecoveryReplacementChallengeDataDataState>
  get serializer =>
      _$AccountRecoveryReplacementChallengeDataDataStateSerializer();
}

class _$AccountRecoveryReplacementChallengeDataDataStateSerializer
    implements
        PrimitiveSerializer<AccountRecoveryReplacementChallengeDataDataState> {
  @override
  final Iterable<Type> types = const [
    AccountRecoveryReplacementChallengeDataDataState,
    _$AccountRecoveryReplacementChallengeDataDataState,
  ];

  @override
  final String wireName = r'AccountRecoveryReplacementChallengeDataDataState';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AccountRecoveryReplacementChallengeDataDataState object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'phase';
    yield serializers.serialize(
      object.phase,
      specifiedType: const FullType(
        AccountRecoveryReplacementChallengeDataDataStatePhaseEnum,
      ),
    );
    yield r'dataGeneration';
    yield serializers.serialize(
      object.dataGeneration,
      specifiedType: const FullType(int),
    );
    yield r'dataKeyEpoch';
    yield serializers.serialize(
      object.dataKeyEpoch,
      specifiedType: const FullType(int),
    );
    yield r'sourceRekeyOperationId';
    yield serializers.serialize(
      object.sourceRekeyOperationId,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryReplacementChallengeDataDataState object, {
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
    required AccountRecoveryReplacementChallengeDataDataStateBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'phase':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(
                      AccountRecoveryReplacementChallengeDataDataStatePhaseEnum,
                    ),
                  )
                  as AccountRecoveryReplacementChallengeDataDataStatePhaseEnum;
          result.phase = valueDes;
          break;
        case r'dataGeneration':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.dataGeneration = valueDes;
          break;
        case r'dataKeyEpoch':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.dataKeyEpoch = valueDes;
          break;
        case r'sourceRekeyOperationId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.sourceRekeyOperationId = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AccountRecoveryReplacementChallengeDataDataState deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AccountRecoveryReplacementChallengeDataDataStateBuilder();
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

class AccountRecoveryReplacementChallengeDataDataStatePhaseEnum
    extends EnumClass {
  @BuiltValueEnumConst(wireName: r'ready')
  static const AccountRecoveryReplacementChallengeDataDataStatePhaseEnum ready =
      _$accountRecoveryReplacementChallengeDataDataStatePhaseEnum_ready;

  static Serializer<AccountRecoveryReplacementChallengeDataDataStatePhaseEnum>
  get serializer =>
      _$accountRecoveryReplacementChallengeDataDataStatePhaseEnumSerializer;

  const AccountRecoveryReplacementChallengeDataDataStatePhaseEnum._(String name)
    : super(name);

  static BuiltSet<AccountRecoveryReplacementChallengeDataDataStatePhaseEnum>
  get values =>
      _$accountRecoveryReplacementChallengeDataDataStatePhaseEnumValues;
  static AccountRecoveryReplacementChallengeDataDataStatePhaseEnum valueOf(
    String name,
  ) => _$accountRecoveryReplacementChallengeDataDataStatePhaseEnumValueOf(name);
}
