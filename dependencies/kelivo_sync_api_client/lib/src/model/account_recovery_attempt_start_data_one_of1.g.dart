// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_recovery_attempt_start_data_one_of1.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AccountRecoveryAttemptStartDataOneOf1ActionEnum
_$accountRecoveryAttemptStartDataOneOf1ActionEnum_authorized =
    const AccountRecoveryAttemptStartDataOneOf1ActionEnum._('authorized');

AccountRecoveryAttemptStartDataOneOf1ActionEnum
_$accountRecoveryAttemptStartDataOneOf1ActionEnumValueOf(String name) {
  switch (name) {
    case 'authorized':
      return _$accountRecoveryAttemptStartDataOneOf1ActionEnum_authorized;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountRecoveryAttemptStartDataOneOf1ActionEnum>
_$accountRecoveryAttemptStartDataOneOf1ActionEnumValues =
    BuiltSet<AccountRecoveryAttemptStartDataOneOf1ActionEnum>(
      const <AccountRecoveryAttemptStartDataOneOf1ActionEnum>[
        _$accountRecoveryAttemptStartDataOneOf1ActionEnum_authorized,
      ],
    );

const AccountRecoveryAttemptStartDataOneOf1ResultEnum
_$accountRecoveryAttemptStartDataOneOf1ResultEnum_authorized =
    const AccountRecoveryAttemptStartDataOneOf1ResultEnum._('authorized');
const AccountRecoveryAttemptStartDataOneOf1ResultEnum
_$accountRecoveryAttemptStartDataOneOf1ResultEnum_replayed =
    const AccountRecoveryAttemptStartDataOneOf1ResultEnum._('replayed');

AccountRecoveryAttemptStartDataOneOf1ResultEnum
_$accountRecoveryAttemptStartDataOneOf1ResultEnumValueOf(String name) {
  switch (name) {
    case 'authorized':
      return _$accountRecoveryAttemptStartDataOneOf1ResultEnum_authorized;
    case 'replayed':
      return _$accountRecoveryAttemptStartDataOneOf1ResultEnum_replayed;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountRecoveryAttemptStartDataOneOf1ResultEnum>
_$accountRecoveryAttemptStartDataOneOf1ResultEnumValues =
    BuiltSet<AccountRecoveryAttemptStartDataOneOf1ResultEnum>(
      const <AccountRecoveryAttemptStartDataOneOf1ResultEnum>[
        _$accountRecoveryAttemptStartDataOneOf1ResultEnum_authorized,
        _$accountRecoveryAttemptStartDataOneOf1ResultEnum_replayed,
      ],
    );

const AccountRecoveryAttemptStartDataOneOf1StatusEnum
_$accountRecoveryAttemptStartDataOneOf1StatusEnum_authorized =
    const AccountRecoveryAttemptStartDataOneOf1StatusEnum._('authorized');

AccountRecoveryAttemptStartDataOneOf1StatusEnum
_$accountRecoveryAttemptStartDataOneOf1StatusEnumValueOf(String name) {
  switch (name) {
    case 'authorized':
      return _$accountRecoveryAttemptStartDataOneOf1StatusEnum_authorized;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountRecoveryAttemptStartDataOneOf1StatusEnum>
_$accountRecoveryAttemptStartDataOneOf1StatusEnumValues =
    BuiltSet<AccountRecoveryAttemptStartDataOneOf1StatusEnum>(
      const <AccountRecoveryAttemptStartDataOneOf1StatusEnum>[
        _$accountRecoveryAttemptStartDataOneOf1StatusEnum_authorized,
      ],
    );

const AccountRecoveryAttemptStartDataOneOf1NextActionEnum
_$accountRecoveryAttemptStartDataOneOf1NextActionEnum_recoverResume =
    const AccountRecoveryAttemptStartDataOneOf1NextActionEnum._(
      'recoverResume',
    );
const AccountRecoveryAttemptStartDataOneOf1NextActionEnum
_$accountRecoveryAttemptStartDataOneOf1NextActionEnum_recoverReplace =
    const AccountRecoveryAttemptStartDataOneOf1NextActionEnum._(
      'recoverReplace',
    );

AccountRecoveryAttemptStartDataOneOf1NextActionEnum
_$accountRecoveryAttemptStartDataOneOf1NextActionEnumValueOf(String name) {
  switch (name) {
    case 'recoverResume':
      return _$accountRecoveryAttemptStartDataOneOf1NextActionEnum_recoverResume;
    case 'recoverReplace':
      return _$accountRecoveryAttemptStartDataOneOf1NextActionEnum_recoverReplace;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountRecoveryAttemptStartDataOneOf1NextActionEnum>
_$accountRecoveryAttemptStartDataOneOf1NextActionEnumValues =
    BuiltSet<AccountRecoveryAttemptStartDataOneOf1NextActionEnum>(
      const <AccountRecoveryAttemptStartDataOneOf1NextActionEnum>[
        _$accountRecoveryAttemptStartDataOneOf1NextActionEnum_recoverResume,
        _$accountRecoveryAttemptStartDataOneOf1NextActionEnum_recoverReplace,
      ],
    );

Serializer<AccountRecoveryAttemptStartDataOneOf1ActionEnum>
_$accountRecoveryAttemptStartDataOneOf1ActionEnumSerializer =
    _$AccountRecoveryAttemptStartDataOneOf1ActionEnumSerializer();
Serializer<AccountRecoveryAttemptStartDataOneOf1ResultEnum>
_$accountRecoveryAttemptStartDataOneOf1ResultEnumSerializer =
    _$AccountRecoveryAttemptStartDataOneOf1ResultEnumSerializer();
Serializer<AccountRecoveryAttemptStartDataOneOf1StatusEnum>
_$accountRecoveryAttemptStartDataOneOf1StatusEnumSerializer =
    _$AccountRecoveryAttemptStartDataOneOf1StatusEnumSerializer();
Serializer<AccountRecoveryAttemptStartDataOneOf1NextActionEnum>
_$accountRecoveryAttemptStartDataOneOf1NextActionEnumSerializer =
    _$AccountRecoveryAttemptStartDataOneOf1NextActionEnumSerializer();

class _$AccountRecoveryAttemptStartDataOneOf1ActionEnumSerializer
    implements
        PrimitiveSerializer<AccountRecoveryAttemptStartDataOneOf1ActionEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'authorized': 'authorized',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'authorized': 'authorized',
  };

  @override
  final Iterable<Type> types = const <Type>[
    AccountRecoveryAttemptStartDataOneOf1ActionEnum,
  ];
  @override
  final String wireName = 'AccountRecoveryAttemptStartDataOneOf1ActionEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryAttemptStartDataOneOf1ActionEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountRecoveryAttemptStartDataOneOf1ActionEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AccountRecoveryAttemptStartDataOneOf1ActionEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AccountRecoveryAttemptStartDataOneOf1ResultEnumSerializer
    implements
        PrimitiveSerializer<AccountRecoveryAttemptStartDataOneOf1ResultEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'authorized': 'authorized',
    'replayed': 'replayed',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'authorized': 'authorized',
    'replayed': 'replayed',
  };

  @override
  final Iterable<Type> types = const <Type>[
    AccountRecoveryAttemptStartDataOneOf1ResultEnum,
  ];
  @override
  final String wireName = 'AccountRecoveryAttemptStartDataOneOf1ResultEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryAttemptStartDataOneOf1ResultEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountRecoveryAttemptStartDataOneOf1ResultEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AccountRecoveryAttemptStartDataOneOf1ResultEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AccountRecoveryAttemptStartDataOneOf1StatusEnumSerializer
    implements
        PrimitiveSerializer<AccountRecoveryAttemptStartDataOneOf1StatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'authorized': 'authorized',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'authorized': 'authorized',
  };

  @override
  final Iterable<Type> types = const <Type>[
    AccountRecoveryAttemptStartDataOneOf1StatusEnum,
  ];
  @override
  final String wireName = 'AccountRecoveryAttemptStartDataOneOf1StatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryAttemptStartDataOneOf1StatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountRecoveryAttemptStartDataOneOf1StatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AccountRecoveryAttemptStartDataOneOf1StatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AccountRecoveryAttemptStartDataOneOf1NextActionEnumSerializer
    implements
        PrimitiveSerializer<
          AccountRecoveryAttemptStartDataOneOf1NextActionEnum
        > {
  static const Map<String, Object> _toWire = const <String, Object>{
    'recoverResume': 'recover-resume',
    'recoverReplace': 'recover-replace',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'recover-resume': 'recoverResume',
    'recover-replace': 'recoverReplace',
  };

  @override
  final Iterable<Type> types = const <Type>[
    AccountRecoveryAttemptStartDataOneOf1NextActionEnum,
  ];
  @override
  final String wireName = 'AccountRecoveryAttemptStartDataOneOf1NextActionEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryAttemptStartDataOneOf1NextActionEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountRecoveryAttemptStartDataOneOf1NextActionEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AccountRecoveryAttemptStartDataOneOf1NextActionEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AccountRecoveryAttemptStartDataOneOf1
    extends AccountRecoveryAttemptStartDataOneOf1 {
  @override
  final AccountRecoveryAttemptStartDataOneOf1ActionEnum action;
  @override
  final AccountRecoveryAttemptStartDataOneOf1ResultEnum result;
  @override
  final int protocolVersion;
  @override
  final String attemptId;
  @override
  final AccountRecoveryAttemptStartDataOneOf1StatusEnum status;
  @override
  final AccountRecoveryAttemptStartDataOneOf1NextActionEnum nextAction;
  @override
  final DateTime recoveryTokenExpiresAt;

  factory _$AccountRecoveryAttemptStartDataOneOf1([
    void Function(AccountRecoveryAttemptStartDataOneOf1Builder)? updates,
  ]) => (AccountRecoveryAttemptStartDataOneOf1Builder()..update(updates))
      ._build();

  _$AccountRecoveryAttemptStartDataOneOf1._({
    required this.action,
    required this.result,
    required this.protocolVersion,
    required this.attemptId,
    required this.status,
    required this.nextAction,
    required this.recoveryTokenExpiresAt,
  }) : super._();
  @override
  AccountRecoveryAttemptStartDataOneOf1 rebuild(
    void Function(AccountRecoveryAttemptStartDataOneOf1Builder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountRecoveryAttemptStartDataOneOf1Builder toBuilder() =>
      AccountRecoveryAttemptStartDataOneOf1Builder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountRecoveryAttemptStartDataOneOf1 &&
        action == other.action &&
        result == other.result &&
        protocolVersion == other.protocolVersion &&
        attemptId == other.attemptId &&
        status == other.status &&
        nextAction == other.nextAction &&
        recoveryTokenExpiresAt == other.recoveryTokenExpiresAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, action.hashCode);
    _$hash = $jc(_$hash, result.hashCode);
    _$hash = $jc(_$hash, protocolVersion.hashCode);
    _$hash = $jc(_$hash, attemptId.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, nextAction.hashCode);
    _$hash = $jc(_$hash, recoveryTokenExpiresAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
            r'AccountRecoveryAttemptStartDataOneOf1',
          )
          ..add('action', action)
          ..add('result', result)
          ..add('protocolVersion', protocolVersion)
          ..add('attemptId', attemptId)
          ..add('status', status)
          ..add('nextAction', nextAction)
          ..add('recoveryTokenExpiresAt', recoveryTokenExpiresAt))
        .toString();
  }
}

class AccountRecoveryAttemptStartDataOneOf1Builder
    implements
        Builder<
          AccountRecoveryAttemptStartDataOneOf1,
          AccountRecoveryAttemptStartDataOneOf1Builder
        > {
  _$AccountRecoveryAttemptStartDataOneOf1? _$v;

  AccountRecoveryAttemptStartDataOneOf1ActionEnum? _action;
  AccountRecoveryAttemptStartDataOneOf1ActionEnum? get action => _$this._action;
  set action(AccountRecoveryAttemptStartDataOneOf1ActionEnum? action) =>
      _$this._action = action;

  AccountRecoveryAttemptStartDataOneOf1ResultEnum? _result;
  AccountRecoveryAttemptStartDataOneOf1ResultEnum? get result => _$this._result;
  set result(AccountRecoveryAttemptStartDataOneOf1ResultEnum? result) =>
      _$this._result = result;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  String? _attemptId;
  String? get attemptId => _$this._attemptId;
  set attemptId(String? attemptId) => _$this._attemptId = attemptId;

  AccountRecoveryAttemptStartDataOneOf1StatusEnum? _status;
  AccountRecoveryAttemptStartDataOneOf1StatusEnum? get status => _$this._status;
  set status(AccountRecoveryAttemptStartDataOneOf1StatusEnum? status) =>
      _$this._status = status;

  AccountRecoveryAttemptStartDataOneOf1NextActionEnum? _nextAction;
  AccountRecoveryAttemptStartDataOneOf1NextActionEnum? get nextAction =>
      _$this._nextAction;
  set nextAction(
    AccountRecoveryAttemptStartDataOneOf1NextActionEnum? nextAction,
  ) => _$this._nextAction = nextAction;

  DateTime? _recoveryTokenExpiresAt;
  DateTime? get recoveryTokenExpiresAt => _$this._recoveryTokenExpiresAt;
  set recoveryTokenExpiresAt(DateTime? recoveryTokenExpiresAt) =>
      _$this._recoveryTokenExpiresAt = recoveryTokenExpiresAt;

  AccountRecoveryAttemptStartDataOneOf1Builder() {
    AccountRecoveryAttemptStartDataOneOf1._defaults(this);
  }

  AccountRecoveryAttemptStartDataOneOf1Builder get _$this {
    final $v = _$v;
    if ($v != null) {
      _action = $v.action;
      _result = $v.result;
      _protocolVersion = $v.protocolVersion;
      _attemptId = $v.attemptId;
      _status = $v.status;
      _nextAction = $v.nextAction;
      _recoveryTokenExpiresAt = $v.recoveryTokenExpiresAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AccountRecoveryAttemptStartDataOneOf1 other) {
    _$v = other as _$AccountRecoveryAttemptStartDataOneOf1;
  }

  @override
  void update(
    void Function(AccountRecoveryAttemptStartDataOneOf1Builder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  AccountRecoveryAttemptStartDataOneOf1 build() => _build();

  _$AccountRecoveryAttemptStartDataOneOf1 _build() {
    final _$result =
        _$v ??
        _$AccountRecoveryAttemptStartDataOneOf1._(
          action: BuiltValueNullFieldError.checkNotNull(
            action,
            r'AccountRecoveryAttemptStartDataOneOf1',
            'action',
          ),
          result: BuiltValueNullFieldError.checkNotNull(
            result,
            r'AccountRecoveryAttemptStartDataOneOf1',
            'result',
          ),
          protocolVersion: BuiltValueNullFieldError.checkNotNull(
            protocolVersion,
            r'AccountRecoveryAttemptStartDataOneOf1',
            'protocolVersion',
          ),
          attemptId: BuiltValueNullFieldError.checkNotNull(
            attemptId,
            r'AccountRecoveryAttemptStartDataOneOf1',
            'attemptId',
          ),
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'AccountRecoveryAttemptStartDataOneOf1',
            'status',
          ),
          nextAction: BuiltValueNullFieldError.checkNotNull(
            nextAction,
            r'AccountRecoveryAttemptStartDataOneOf1',
            'nextAction',
          ),
          recoveryTokenExpiresAt: BuiltValueNullFieldError.checkNotNull(
            recoveryTokenExpiresAt,
            r'AccountRecoveryAttemptStartDataOneOf1',
            'recoveryTokenExpiresAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
