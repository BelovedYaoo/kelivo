// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_recovery_attempt_start_request_one_of.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AccountRecoveryAttemptStartRequestOneOfActionEnum
_$accountRecoveryAttemptStartRequestOneOfActionEnum_challenge =
    const AccountRecoveryAttemptStartRequestOneOfActionEnum._('challenge');

AccountRecoveryAttemptStartRequestOneOfActionEnum
_$accountRecoveryAttemptStartRequestOneOfActionEnumValueOf(String name) {
  switch (name) {
    case 'challenge':
      return _$accountRecoveryAttemptStartRequestOneOfActionEnum_challenge;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountRecoveryAttemptStartRequestOneOfActionEnum>
_$accountRecoveryAttemptStartRequestOneOfActionEnumValues =
    BuiltSet<AccountRecoveryAttemptStartRequestOneOfActionEnum>(
      const <AccountRecoveryAttemptStartRequestOneOfActionEnum>[
        _$accountRecoveryAttemptStartRequestOneOfActionEnum_challenge,
      ],
    );

Serializer<AccountRecoveryAttemptStartRequestOneOfActionEnum>
_$accountRecoveryAttemptStartRequestOneOfActionEnumSerializer =
    _$AccountRecoveryAttemptStartRequestOneOfActionEnumSerializer();

class _$AccountRecoveryAttemptStartRequestOneOfActionEnumSerializer
    implements
        PrimitiveSerializer<AccountRecoveryAttemptStartRequestOneOfActionEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'challenge': 'challenge',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'challenge': 'challenge',
  };

  @override
  final Iterable<Type> types = const <Type>[
    AccountRecoveryAttemptStartRequestOneOfActionEnum,
  ];
  @override
  final String wireName = 'AccountRecoveryAttemptStartRequestOneOfActionEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryAttemptStartRequestOneOfActionEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountRecoveryAttemptStartRequestOneOfActionEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AccountRecoveryAttemptStartRequestOneOfActionEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AccountRecoveryAttemptStartRequestOneOf
    extends AccountRecoveryAttemptStartRequestOneOf {
  @override
  final AccountRecoveryAttemptStartRequestOneOfActionEnum action;
  @override
  final int protocolVersion;
  @override
  final String attemptId;

  factory _$AccountRecoveryAttemptStartRequestOneOf([
    void Function(AccountRecoveryAttemptStartRequestOneOfBuilder)? updates,
  ]) => (AccountRecoveryAttemptStartRequestOneOfBuilder()..update(updates))
      ._build();

  _$AccountRecoveryAttemptStartRequestOneOf._({
    required this.action,
    required this.protocolVersion,
    required this.attemptId,
  }) : super._();
  @override
  AccountRecoveryAttemptStartRequestOneOf rebuild(
    void Function(AccountRecoveryAttemptStartRequestOneOfBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountRecoveryAttemptStartRequestOneOfBuilder toBuilder() =>
      AccountRecoveryAttemptStartRequestOneOfBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountRecoveryAttemptStartRequestOneOf &&
        action == other.action &&
        protocolVersion == other.protocolVersion &&
        attemptId == other.attemptId;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, action.hashCode);
    _$hash = $jc(_$hash, protocolVersion.hashCode);
    _$hash = $jc(_$hash, attemptId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
            r'AccountRecoveryAttemptStartRequestOneOf',
          )
          ..add('action', action)
          ..add('protocolVersion', protocolVersion)
          ..add('attemptId', attemptId))
        .toString();
  }
}

class AccountRecoveryAttemptStartRequestOneOfBuilder
    implements
        Builder<
          AccountRecoveryAttemptStartRequestOneOf,
          AccountRecoveryAttemptStartRequestOneOfBuilder
        > {
  _$AccountRecoveryAttemptStartRequestOneOf? _$v;

  AccountRecoveryAttemptStartRequestOneOfActionEnum? _action;
  AccountRecoveryAttemptStartRequestOneOfActionEnum? get action =>
      _$this._action;
  set action(AccountRecoveryAttemptStartRequestOneOfActionEnum? action) =>
      _$this._action = action;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  String? _attemptId;
  String? get attemptId => _$this._attemptId;
  set attemptId(String? attemptId) => _$this._attemptId = attemptId;

  AccountRecoveryAttemptStartRequestOneOfBuilder() {
    AccountRecoveryAttemptStartRequestOneOf._defaults(this);
  }

  AccountRecoveryAttemptStartRequestOneOfBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _action = $v.action;
      _protocolVersion = $v.protocolVersion;
      _attemptId = $v.attemptId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AccountRecoveryAttemptStartRequestOneOf other) {
    _$v = other as _$AccountRecoveryAttemptStartRequestOneOf;
  }

  @override
  void update(
    void Function(AccountRecoveryAttemptStartRequestOneOfBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  AccountRecoveryAttemptStartRequestOneOf build() => _build();

  _$AccountRecoveryAttemptStartRequestOneOf _build() {
    final _$result =
        _$v ??
        _$AccountRecoveryAttemptStartRequestOneOf._(
          action: BuiltValueNullFieldError.checkNotNull(
            action,
            r'AccountRecoveryAttemptStartRequestOneOf',
            'action',
          ),
          protocolVersion: BuiltValueNullFieldError.checkNotNull(
            protocolVersion,
            r'AccountRecoveryAttemptStartRequestOneOf',
            'protocolVersion',
          ),
          attemptId: BuiltValueNullFieldError.checkNotNull(
            attemptId,
            r'AccountRecoveryAttemptStartRequestOneOf',
            'attemptId',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
