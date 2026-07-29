// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_security_state_envelope.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AccountSecurityStateEnvelope extends AccountSecurityStateEnvelope {
  @override
  final String targetDeviceId;
  @override
  final String issuerDeviceId;
  @override
  final int envelopeVersion;
  @override
  final int keyEpoch;
  @override
  final String accountKeyEnvelope;

  factory _$AccountSecurityStateEnvelope([
    void Function(AccountSecurityStateEnvelopeBuilder)? updates,
  ]) => (AccountSecurityStateEnvelopeBuilder()..update(updates))._build();

  _$AccountSecurityStateEnvelope._({
    required this.targetDeviceId,
    required this.issuerDeviceId,
    required this.envelopeVersion,
    required this.keyEpoch,
    required this.accountKeyEnvelope,
  }) : super._();
  @override
  AccountSecurityStateEnvelope rebuild(
    void Function(AccountSecurityStateEnvelopeBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountSecurityStateEnvelopeBuilder toBuilder() =>
      AccountSecurityStateEnvelopeBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountSecurityStateEnvelope &&
        targetDeviceId == other.targetDeviceId &&
        issuerDeviceId == other.issuerDeviceId &&
        envelopeVersion == other.envelopeVersion &&
        keyEpoch == other.keyEpoch &&
        accountKeyEnvelope == other.accountKeyEnvelope;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, targetDeviceId.hashCode);
    _$hash = $jc(_$hash, issuerDeviceId.hashCode);
    _$hash = $jc(_$hash, envelopeVersion.hashCode);
    _$hash = $jc(_$hash, keyEpoch.hashCode);
    _$hash = $jc(_$hash, accountKeyEnvelope.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AccountSecurityStateEnvelope')
          ..add('targetDeviceId', targetDeviceId)
          ..add('issuerDeviceId', issuerDeviceId)
          ..add('envelopeVersion', envelopeVersion)
          ..add('keyEpoch', keyEpoch)
          ..add('accountKeyEnvelope', accountKeyEnvelope))
        .toString();
  }
}

class AccountSecurityStateEnvelopeBuilder
    implements
        Builder<
          AccountSecurityStateEnvelope,
          AccountSecurityStateEnvelopeBuilder
        > {
  _$AccountSecurityStateEnvelope? _$v;

  String? _targetDeviceId;
  String? get targetDeviceId => _$this._targetDeviceId;
  set targetDeviceId(String? targetDeviceId) =>
      _$this._targetDeviceId = targetDeviceId;

  String? _issuerDeviceId;
  String? get issuerDeviceId => _$this._issuerDeviceId;
  set issuerDeviceId(String? issuerDeviceId) =>
      _$this._issuerDeviceId = issuerDeviceId;

  int? _envelopeVersion;
  int? get envelopeVersion => _$this._envelopeVersion;
  set envelopeVersion(int? envelopeVersion) =>
      _$this._envelopeVersion = envelopeVersion;

  int? _keyEpoch;
  int? get keyEpoch => _$this._keyEpoch;
  set keyEpoch(int? keyEpoch) => _$this._keyEpoch = keyEpoch;

  String? _accountKeyEnvelope;
  String? get accountKeyEnvelope => _$this._accountKeyEnvelope;
  set accountKeyEnvelope(String? accountKeyEnvelope) =>
      _$this._accountKeyEnvelope = accountKeyEnvelope;

  AccountSecurityStateEnvelopeBuilder() {
    AccountSecurityStateEnvelope._defaults(this);
  }

  AccountSecurityStateEnvelopeBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _targetDeviceId = $v.targetDeviceId;
      _issuerDeviceId = $v.issuerDeviceId;
      _envelopeVersion = $v.envelopeVersion;
      _keyEpoch = $v.keyEpoch;
      _accountKeyEnvelope = $v.accountKeyEnvelope;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AccountSecurityStateEnvelope other) {
    _$v = other as _$AccountSecurityStateEnvelope;
  }

  @override
  void update(void Function(AccountSecurityStateEnvelopeBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AccountSecurityStateEnvelope build() => _build();

  _$AccountSecurityStateEnvelope _build() {
    final _$result =
        _$v ??
        _$AccountSecurityStateEnvelope._(
          targetDeviceId: BuiltValueNullFieldError.checkNotNull(
            targetDeviceId,
            r'AccountSecurityStateEnvelope',
            'targetDeviceId',
          ),
          issuerDeviceId: BuiltValueNullFieldError.checkNotNull(
            issuerDeviceId,
            r'AccountSecurityStateEnvelope',
            'issuerDeviceId',
          ),
          envelopeVersion: BuiltValueNullFieldError.checkNotNull(
            envelopeVersion,
            r'AccountSecurityStateEnvelope',
            'envelopeVersion',
          ),
          keyEpoch: BuiltValueNullFieldError.checkNotNull(
            keyEpoch,
            r'AccountSecurityStateEnvelope',
            'keyEpoch',
          ),
          accountKeyEnvelope: BuiltValueNullFieldError.checkNotNull(
            accountKeyEnvelope,
            r'AccountSecurityStateEnvelope',
            'accountKeyEnvelope',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
