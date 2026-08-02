// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_recovery_replacement_challenge_data_data_state.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AccountRecoveryReplacementChallengeDataDataStatePhaseEnum
_$accountRecoveryReplacementChallengeDataDataStatePhaseEnum_ready =
    const AccountRecoveryReplacementChallengeDataDataStatePhaseEnum._('ready');

AccountRecoveryReplacementChallengeDataDataStatePhaseEnum
_$accountRecoveryReplacementChallengeDataDataStatePhaseEnumValueOf(
  String name,
) {
  switch (name) {
    case 'ready':
      return _$accountRecoveryReplacementChallengeDataDataStatePhaseEnum_ready;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountRecoveryReplacementChallengeDataDataStatePhaseEnum>
_$accountRecoveryReplacementChallengeDataDataStatePhaseEnumValues =
    BuiltSet<AccountRecoveryReplacementChallengeDataDataStatePhaseEnum>(
      const <AccountRecoveryReplacementChallengeDataDataStatePhaseEnum>[
        _$accountRecoveryReplacementChallengeDataDataStatePhaseEnum_ready,
      ],
    );

Serializer<AccountRecoveryReplacementChallengeDataDataStatePhaseEnum>
_$accountRecoveryReplacementChallengeDataDataStatePhaseEnumSerializer =
    _$AccountRecoveryReplacementChallengeDataDataStatePhaseEnumSerializer();

class _$AccountRecoveryReplacementChallengeDataDataStatePhaseEnumSerializer
    implements
        PrimitiveSerializer<
          AccountRecoveryReplacementChallengeDataDataStatePhaseEnum
        > {
  static const Map<String, Object> _toWire = const <String, Object>{
    'ready': 'ready',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'ready': 'ready',
  };

  @override
  final Iterable<Type> types = const <Type>[
    AccountRecoveryReplacementChallengeDataDataStatePhaseEnum,
  ];
  @override
  final String wireName =
      'AccountRecoveryReplacementChallengeDataDataStatePhaseEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryReplacementChallengeDataDataStatePhaseEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountRecoveryReplacementChallengeDataDataStatePhaseEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AccountRecoveryReplacementChallengeDataDataStatePhaseEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AccountRecoveryReplacementChallengeDataDataState
    extends AccountRecoveryReplacementChallengeDataDataState {
  @override
  final AccountRecoveryReplacementChallengeDataDataStatePhaseEnum phase;
  @override
  final int dataGeneration;
  @override
  final int dataKeyEpoch;
  @override
  final String sourceRekeyOperationId;

  factory _$AccountRecoveryReplacementChallengeDataDataState([
    void Function(AccountRecoveryReplacementChallengeDataDataStateBuilder)?
    updates,
  ]) =>
      (AccountRecoveryReplacementChallengeDataDataStateBuilder()
            ..update(updates))
          ._build();

  _$AccountRecoveryReplacementChallengeDataDataState._({
    required this.phase,
    required this.dataGeneration,
    required this.dataKeyEpoch,
    required this.sourceRekeyOperationId,
  }) : super._();
  @override
  AccountRecoveryReplacementChallengeDataDataState rebuild(
    void Function(AccountRecoveryReplacementChallengeDataDataStateBuilder)
    updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountRecoveryReplacementChallengeDataDataStateBuilder toBuilder() =>
      AccountRecoveryReplacementChallengeDataDataStateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountRecoveryReplacementChallengeDataDataState &&
        phase == other.phase &&
        dataGeneration == other.dataGeneration &&
        dataKeyEpoch == other.dataKeyEpoch &&
        sourceRekeyOperationId == other.sourceRekeyOperationId;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, phase.hashCode);
    _$hash = $jc(_$hash, dataGeneration.hashCode);
    _$hash = $jc(_$hash, dataKeyEpoch.hashCode);
    _$hash = $jc(_$hash, sourceRekeyOperationId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
            r'AccountRecoveryReplacementChallengeDataDataState',
          )
          ..add('phase', phase)
          ..add('dataGeneration', dataGeneration)
          ..add('dataKeyEpoch', dataKeyEpoch)
          ..add('sourceRekeyOperationId', sourceRekeyOperationId))
        .toString();
  }
}

class AccountRecoveryReplacementChallengeDataDataStateBuilder
    implements
        Builder<
          AccountRecoveryReplacementChallengeDataDataState,
          AccountRecoveryReplacementChallengeDataDataStateBuilder
        > {
  _$AccountRecoveryReplacementChallengeDataDataState? _$v;

  AccountRecoveryReplacementChallengeDataDataStatePhaseEnum? _phase;
  AccountRecoveryReplacementChallengeDataDataStatePhaseEnum? get phase =>
      _$this._phase;
  set phase(AccountRecoveryReplacementChallengeDataDataStatePhaseEnum? phase) =>
      _$this._phase = phase;

  int? _dataGeneration;
  int? get dataGeneration => _$this._dataGeneration;
  set dataGeneration(int? dataGeneration) =>
      _$this._dataGeneration = dataGeneration;

  int? _dataKeyEpoch;
  int? get dataKeyEpoch => _$this._dataKeyEpoch;
  set dataKeyEpoch(int? dataKeyEpoch) => _$this._dataKeyEpoch = dataKeyEpoch;

  String? _sourceRekeyOperationId;
  String? get sourceRekeyOperationId => _$this._sourceRekeyOperationId;
  set sourceRekeyOperationId(String? sourceRekeyOperationId) =>
      _$this._sourceRekeyOperationId = sourceRekeyOperationId;

  AccountRecoveryReplacementChallengeDataDataStateBuilder() {
    AccountRecoveryReplacementChallengeDataDataState._defaults(this);
  }

  AccountRecoveryReplacementChallengeDataDataStateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _phase = $v.phase;
      _dataGeneration = $v.dataGeneration;
      _dataKeyEpoch = $v.dataKeyEpoch;
      _sourceRekeyOperationId = $v.sourceRekeyOperationId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AccountRecoveryReplacementChallengeDataDataState other) {
    _$v = other as _$AccountRecoveryReplacementChallengeDataDataState;
  }

  @override
  void update(
    void Function(AccountRecoveryReplacementChallengeDataDataStateBuilder)?
    updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  AccountRecoveryReplacementChallengeDataDataState build() => _build();

  _$AccountRecoveryReplacementChallengeDataDataState _build() {
    final _$result =
        _$v ??
        _$AccountRecoveryReplacementChallengeDataDataState._(
          phase: BuiltValueNullFieldError.checkNotNull(
            phase,
            r'AccountRecoveryReplacementChallengeDataDataState',
            'phase',
          ),
          dataGeneration: BuiltValueNullFieldError.checkNotNull(
            dataGeneration,
            r'AccountRecoveryReplacementChallengeDataDataState',
            'dataGeneration',
          ),
          dataKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            dataKeyEpoch,
            r'AccountRecoveryReplacementChallengeDataDataState',
            'dataKeyEpoch',
          ),
          sourceRekeyOperationId: BuiltValueNullFieldError.checkNotNull(
            sourceRekeyOperationId,
            r'AccountRecoveryReplacementChallengeDataDataState',
            'sourceRekeyOperationId',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
