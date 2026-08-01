//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'account_recovery_data_state.g.dart';

/// AccountRecoveryDataState
///
/// Properties:
/// * [phase]
/// * [dataGeneration]
/// * [dataKeyEpoch]
/// * [operationId]
/// * [targetKeyEpoch]
@BuiltValue()
abstract class AccountRecoveryDataState
    implements
        Built<AccountRecoveryDataState, AccountRecoveryDataStateBuilder> {
  @BuiltValueField(wireName: r'phase')
  AccountRecoveryDataStatePhaseEnum get phase;
  // enum phaseEnum {  ready,  rekey-pending,  };

  @BuiltValueField(wireName: r'dataGeneration')
  int get dataGeneration;

  @BuiltValueField(wireName: r'dataKeyEpoch')
  int get dataKeyEpoch;

  @BuiltValueField(wireName: r'operationId')
  String? get operationId;

  @BuiltValueField(wireName: r'targetKeyEpoch')
  int? get targetKeyEpoch;

  AccountRecoveryDataState._();

  factory AccountRecoveryDataState([
    void updates(AccountRecoveryDataStateBuilder b),
  ]) = _$AccountRecoveryDataState;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AccountRecoveryDataStateBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AccountRecoveryDataState> get serializer =>
      _$AccountRecoveryDataStateSerializer();
}

class _$AccountRecoveryDataStateSerializer
    implements PrimitiveSerializer<AccountRecoveryDataState> {
  @override
  final Iterable<Type> types = const [
    AccountRecoveryDataState,
    _$AccountRecoveryDataState,
  ];

  @override
  final String wireName = r'AccountRecoveryDataState';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AccountRecoveryDataState object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'phase';
    yield serializers.serialize(
      object.phase,
      specifiedType: const FullType(AccountRecoveryDataStatePhaseEnum),
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
    yield r'operationId';
    yield object.operationId == null
        ? null
        : serializers.serialize(
            object.operationId,
            specifiedType: const FullType.nullable(String),
          );
    yield r'targetKeyEpoch';
    yield object.targetKeyEpoch == null
        ? null
        : serializers.serialize(
            object.targetKeyEpoch,
            specifiedType: const FullType.nullable(int),
          );
  }

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryDataState object, {
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
    required AccountRecoveryDataStateBuilder result,
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
                      AccountRecoveryDataStatePhaseEnum,
                    ),
                  )
                  as AccountRecoveryDataStatePhaseEnum;
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
        case r'operationId':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(String),
                  )
                  as String?;
          if (valueDes == null) continue;
          result.operationId = valueDes;
          break;
        case r'targetKeyEpoch':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType.nullable(int),
                  )
                  as int?;
          if (valueDes == null) continue;
          result.targetKeyEpoch = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AccountRecoveryDataState deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AccountRecoveryDataStateBuilder();
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

class AccountRecoveryDataStatePhaseEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'ready')
  static const AccountRecoveryDataStatePhaseEnum ready =
      _$accountRecoveryDataStatePhaseEnum_ready;
  @BuiltValueEnumConst(wireName: r'rekey-pending')
  static const AccountRecoveryDataStatePhaseEnum rekeyPending =
      _$accountRecoveryDataStatePhaseEnum_rekeyPending;

  static Serializer<AccountRecoveryDataStatePhaseEnum> get serializer =>
      _$accountRecoveryDataStatePhaseEnumSerializer;

  const AccountRecoveryDataStatePhaseEnum._(String name) : super(name);

  static BuiltSet<AccountRecoveryDataStatePhaseEnum> get values =>
      _$accountRecoveryDataStatePhaseEnumValues;
  static AccountRecoveryDataStatePhaseEnum valueOf(String name) =>
      _$accountRecoveryDataStatePhaseEnumValueOf(name);
}
