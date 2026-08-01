// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_recovery_attempt_start_request_one_of1.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AccountRecoveryAttemptStartRequestOneOf1ActionEnum
_$accountRecoveryAttemptStartRequestOneOf1ActionEnum_authorize =
    const AccountRecoveryAttemptStartRequestOneOf1ActionEnum._('authorize');

AccountRecoveryAttemptStartRequestOneOf1ActionEnum
_$accountRecoveryAttemptStartRequestOneOf1ActionEnumValueOf(String name) {
  switch (name) {
    case 'authorize':
      return _$accountRecoveryAttemptStartRequestOneOf1ActionEnum_authorize;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountRecoveryAttemptStartRequestOneOf1ActionEnum>
_$accountRecoveryAttemptStartRequestOneOf1ActionEnumValues =
    BuiltSet<AccountRecoveryAttemptStartRequestOneOf1ActionEnum>(
      const <AccountRecoveryAttemptStartRequestOneOf1ActionEnum>[
        _$accountRecoveryAttemptStartRequestOneOf1ActionEnum_authorize,
      ],
    );

Serializer<AccountRecoveryAttemptStartRequestOneOf1ActionEnum>
_$accountRecoveryAttemptStartRequestOneOf1ActionEnumSerializer =
    _$AccountRecoveryAttemptStartRequestOneOf1ActionEnumSerializer();

class _$AccountRecoveryAttemptStartRequestOneOf1ActionEnumSerializer
    implements
        PrimitiveSerializer<
          AccountRecoveryAttemptStartRequestOneOf1ActionEnum
        > {
  static const Map<String, Object> _toWire = const <String, Object>{
    'authorize': 'authorize',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'authorize': 'authorize',
  };

  @override
  final Iterable<Type> types = const <Type>[
    AccountRecoveryAttemptStartRequestOneOf1ActionEnum,
  ];
  @override
  final String wireName = 'AccountRecoveryAttemptStartRequestOneOf1ActionEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryAttemptStartRequestOneOf1ActionEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountRecoveryAttemptStartRequestOneOf1ActionEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AccountRecoveryAttemptStartRequestOneOf1ActionEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AccountRecoveryAttemptStartRequestOneOf1
    extends AccountRecoveryAttemptStartRequestOneOf1 {
  @override
  final AccountRecoveryAttemptStartRequestOneOf1ActionEnum action;
  @override
  final int protocolVersion;
  @override
  final String attemptId;
  @override
  final String challengeRequestDigest;
  @override
  final String recoveryToken;
  @override
  final String nonceProof;
  @override
  final String trustSignature;

  factory _$AccountRecoveryAttemptStartRequestOneOf1([
    void Function(AccountRecoveryAttemptStartRequestOneOf1Builder)? updates,
  ]) => (AccountRecoveryAttemptStartRequestOneOf1Builder()..update(updates))
      ._build();

  _$AccountRecoveryAttemptStartRequestOneOf1._({
    required this.action,
    required this.protocolVersion,
    required this.attemptId,
    required this.challengeRequestDigest,
    required this.recoveryToken,
    required this.nonceProof,
    required this.trustSignature,
  }) : super._();
  @override
  AccountRecoveryAttemptStartRequestOneOf1 rebuild(
    void Function(AccountRecoveryAttemptStartRequestOneOf1Builder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountRecoveryAttemptStartRequestOneOf1Builder toBuilder() =>
      AccountRecoveryAttemptStartRequestOneOf1Builder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountRecoveryAttemptStartRequestOneOf1 &&
        action == other.action &&
        protocolVersion == other.protocolVersion &&
        attemptId == other.attemptId &&
        challengeRequestDigest == other.challengeRequestDigest &&
        recoveryToken == other.recoveryToken &&
        nonceProof == other.nonceProof &&
        trustSignature == other.trustSignature;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, action.hashCode);
    _$hash = $jc(_$hash, protocolVersion.hashCode);
    _$hash = $jc(_$hash, attemptId.hashCode);
    _$hash = $jc(_$hash, challengeRequestDigest.hashCode);
    _$hash = $jc(_$hash, recoveryToken.hashCode);
    _$hash = $jc(_$hash, nonceProof.hashCode);
    _$hash = $jc(_$hash, trustSignature.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
            r'AccountRecoveryAttemptStartRequestOneOf1',
          )
          ..add('action', action)
          ..add('protocolVersion', protocolVersion)
          ..add('attemptId', attemptId)
          ..add('challengeRequestDigest', challengeRequestDigest)
          ..add('recoveryToken', recoveryToken)
          ..add('nonceProof', nonceProof)
          ..add('trustSignature', trustSignature))
        .toString();
  }
}

class AccountRecoveryAttemptStartRequestOneOf1Builder
    implements
        Builder<
          AccountRecoveryAttemptStartRequestOneOf1,
          AccountRecoveryAttemptStartRequestOneOf1Builder
        > {
  _$AccountRecoveryAttemptStartRequestOneOf1? _$v;

  AccountRecoveryAttemptStartRequestOneOf1ActionEnum? _action;
  AccountRecoveryAttemptStartRequestOneOf1ActionEnum? get action =>
      _$this._action;
  set action(AccountRecoveryAttemptStartRequestOneOf1ActionEnum? action) =>
      _$this._action = action;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  String? _attemptId;
  String? get attemptId => _$this._attemptId;
  set attemptId(String? attemptId) => _$this._attemptId = attemptId;

  String? _challengeRequestDigest;
  String? get challengeRequestDigest => _$this._challengeRequestDigest;
  set challengeRequestDigest(String? challengeRequestDigest) =>
      _$this._challengeRequestDigest = challengeRequestDigest;

  String? _recoveryToken;
  String? get recoveryToken => _$this._recoveryToken;
  set recoveryToken(String? recoveryToken) =>
      _$this._recoveryToken = recoveryToken;

  String? _nonceProof;
  String? get nonceProof => _$this._nonceProof;
  set nonceProof(String? nonceProof) => _$this._nonceProof = nonceProof;

  String? _trustSignature;
  String? get trustSignature => _$this._trustSignature;
  set trustSignature(String? trustSignature) =>
      _$this._trustSignature = trustSignature;

  AccountRecoveryAttemptStartRequestOneOf1Builder() {
    AccountRecoveryAttemptStartRequestOneOf1._defaults(this);
  }

  AccountRecoveryAttemptStartRequestOneOf1Builder get _$this {
    final $v = _$v;
    if ($v != null) {
      _action = $v.action;
      _protocolVersion = $v.protocolVersion;
      _attemptId = $v.attemptId;
      _challengeRequestDigest = $v.challengeRequestDigest;
      _recoveryToken = $v.recoveryToken;
      _nonceProof = $v.nonceProof;
      _trustSignature = $v.trustSignature;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AccountRecoveryAttemptStartRequestOneOf1 other) {
    _$v = other as _$AccountRecoveryAttemptStartRequestOneOf1;
  }

  @override
  void update(
    void Function(AccountRecoveryAttemptStartRequestOneOf1Builder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  AccountRecoveryAttemptStartRequestOneOf1 build() => _build();

  _$AccountRecoveryAttemptStartRequestOneOf1 _build() {
    final _$result =
        _$v ??
        _$AccountRecoveryAttemptStartRequestOneOf1._(
          action: BuiltValueNullFieldError.checkNotNull(
            action,
            r'AccountRecoveryAttemptStartRequestOneOf1',
            'action',
          ),
          protocolVersion: BuiltValueNullFieldError.checkNotNull(
            protocolVersion,
            r'AccountRecoveryAttemptStartRequestOneOf1',
            'protocolVersion',
          ),
          attemptId: BuiltValueNullFieldError.checkNotNull(
            attemptId,
            r'AccountRecoveryAttemptStartRequestOneOf1',
            'attemptId',
          ),
          challengeRequestDigest: BuiltValueNullFieldError.checkNotNull(
            challengeRequestDigest,
            r'AccountRecoveryAttemptStartRequestOneOf1',
            'challengeRequestDigest',
          ),
          recoveryToken: BuiltValueNullFieldError.checkNotNull(
            recoveryToken,
            r'AccountRecoveryAttemptStartRequestOneOf1',
            'recoveryToken',
          ),
          nonceProof: BuiltValueNullFieldError.checkNotNull(
            nonceProof,
            r'AccountRecoveryAttemptStartRequestOneOf1',
            'nonceProof',
          ),
          trustSignature: BuiltValueNullFieldError.checkNotNull(
            trustSignature,
            r'AccountRecoveryAttemptStartRequestOneOf1',
            'trustSignature',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
