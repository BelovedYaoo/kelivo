// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_recovery_data_state.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AccountRecoveryDataStatePhaseEnum
_$accountRecoveryDataStatePhaseEnum_ready =
    const AccountRecoveryDataStatePhaseEnum._('ready');
const AccountRecoveryDataStatePhaseEnum
_$accountRecoveryDataStatePhaseEnum_rekeyPending =
    const AccountRecoveryDataStatePhaseEnum._('rekeyPending');

AccountRecoveryDataStatePhaseEnum _$accountRecoveryDataStatePhaseEnumValueOf(
  String name,
) {
  switch (name) {
    case 'ready':
      return _$accountRecoveryDataStatePhaseEnum_ready;
    case 'rekeyPending':
      return _$accountRecoveryDataStatePhaseEnum_rekeyPending;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountRecoveryDataStatePhaseEnum>
_$accountRecoveryDataStatePhaseEnumValues =
    BuiltSet<AccountRecoveryDataStatePhaseEnum>(
      const <AccountRecoveryDataStatePhaseEnum>[
        _$accountRecoveryDataStatePhaseEnum_ready,
        _$accountRecoveryDataStatePhaseEnum_rekeyPending,
      ],
    );

Serializer<AccountRecoveryDataStatePhaseEnum>
_$accountRecoveryDataStatePhaseEnumSerializer =
    _$AccountRecoveryDataStatePhaseEnumSerializer();

class _$AccountRecoveryDataStatePhaseEnumSerializer
    implements PrimitiveSerializer<AccountRecoveryDataStatePhaseEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'ready': 'ready',
    'rekeyPending': 'rekey-pending',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'ready': 'ready',
    'rekey-pending': 'rekeyPending',
  };

  @override
  final Iterable<Type> types = const <Type>[AccountRecoveryDataStatePhaseEnum];
  @override
  final String wireName = 'AccountRecoveryDataStatePhaseEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryDataStatePhaseEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountRecoveryDataStatePhaseEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AccountRecoveryDataStatePhaseEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AccountRecoveryDataState extends AccountRecoveryDataState {
  @override
  final AccountRecoveryDataStatePhaseEnum phase;
  @override
  final int dataGeneration;
  @override
  final int dataKeyEpoch;
  @override
  final String? operationId;
  @override
  final int? targetKeyEpoch;

  factory _$AccountRecoveryDataState([
    void Function(AccountRecoveryDataStateBuilder)? updates,
  ]) => (AccountRecoveryDataStateBuilder()..update(updates))._build();

  _$AccountRecoveryDataState._({
    required this.phase,
    required this.dataGeneration,
    required this.dataKeyEpoch,
    this.operationId,
    this.targetKeyEpoch,
  }) : super._();
  @override
  AccountRecoveryDataState rebuild(
    void Function(AccountRecoveryDataStateBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountRecoveryDataStateBuilder toBuilder() =>
      AccountRecoveryDataStateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountRecoveryDataState &&
        phase == other.phase &&
        dataGeneration == other.dataGeneration &&
        dataKeyEpoch == other.dataKeyEpoch &&
        operationId == other.operationId &&
        targetKeyEpoch == other.targetKeyEpoch;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, phase.hashCode);
    _$hash = $jc(_$hash, dataGeneration.hashCode);
    _$hash = $jc(_$hash, dataKeyEpoch.hashCode);
    _$hash = $jc(_$hash, operationId.hashCode);
    _$hash = $jc(_$hash, targetKeyEpoch.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AccountRecoveryDataState')
          ..add('phase', phase)
          ..add('dataGeneration', dataGeneration)
          ..add('dataKeyEpoch', dataKeyEpoch)
          ..add('operationId', operationId)
          ..add('targetKeyEpoch', targetKeyEpoch))
        .toString();
  }
}

class AccountRecoveryDataStateBuilder
    implements
        Builder<AccountRecoveryDataState, AccountRecoveryDataStateBuilder> {
  _$AccountRecoveryDataState? _$v;

  AccountRecoveryDataStatePhaseEnum? _phase;
  AccountRecoveryDataStatePhaseEnum? get phase => _$this._phase;
  set phase(AccountRecoveryDataStatePhaseEnum? phase) => _$this._phase = phase;

  int? _dataGeneration;
  int? get dataGeneration => _$this._dataGeneration;
  set dataGeneration(int? dataGeneration) =>
      _$this._dataGeneration = dataGeneration;

  int? _dataKeyEpoch;
  int? get dataKeyEpoch => _$this._dataKeyEpoch;
  set dataKeyEpoch(int? dataKeyEpoch) => _$this._dataKeyEpoch = dataKeyEpoch;

  String? _operationId;
  String? get operationId => _$this._operationId;
  set operationId(String? operationId) => _$this._operationId = operationId;

  int? _targetKeyEpoch;
  int? get targetKeyEpoch => _$this._targetKeyEpoch;
  set targetKeyEpoch(int? targetKeyEpoch) =>
      _$this._targetKeyEpoch = targetKeyEpoch;

  AccountRecoveryDataStateBuilder() {
    AccountRecoveryDataState._defaults(this);
  }

  AccountRecoveryDataStateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _phase = $v.phase;
      _dataGeneration = $v.dataGeneration;
      _dataKeyEpoch = $v.dataKeyEpoch;
      _operationId = $v.operationId;
      _targetKeyEpoch = $v.targetKeyEpoch;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AccountRecoveryDataState other) {
    _$v = other as _$AccountRecoveryDataState;
  }

  @override
  void update(void Function(AccountRecoveryDataStateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AccountRecoveryDataState build() => _build();

  _$AccountRecoveryDataState _build() {
    final _$result =
        _$v ??
        _$AccountRecoveryDataState._(
          phase: BuiltValueNullFieldError.checkNotNull(
            phase,
            r'AccountRecoveryDataState',
            'phase',
          ),
          dataGeneration: BuiltValueNullFieldError.checkNotNull(
            dataGeneration,
            r'AccountRecoveryDataState',
            'dataGeneration',
          ),
          dataKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            dataKeyEpoch,
            r'AccountRecoveryDataState',
            'dataKeyEpoch',
          ),
          operationId: operationId,
          targetKeyEpoch: targetKeyEpoch,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
