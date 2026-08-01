// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_recovery_resume_commit_request_envelope.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AccountRecoveryResumeCommitRequestEnvelope
    extends AccountRecoveryResumeCommitRequestEnvelope {
  @override
  final int envelopeVersion;
  @override
  final int keyEpoch;
  @override
  final String accountKeyEnvelope;

  factory _$AccountRecoveryResumeCommitRequestEnvelope([
    void Function(AccountRecoveryResumeCommitRequestEnvelopeBuilder)? updates,
  ]) => (AccountRecoveryResumeCommitRequestEnvelopeBuilder()..update(updates))
      ._build();

  _$AccountRecoveryResumeCommitRequestEnvelope._({
    required this.envelopeVersion,
    required this.keyEpoch,
    required this.accountKeyEnvelope,
  }) : super._();
  @override
  AccountRecoveryResumeCommitRequestEnvelope rebuild(
    void Function(AccountRecoveryResumeCommitRequestEnvelopeBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountRecoveryResumeCommitRequestEnvelopeBuilder toBuilder() =>
      AccountRecoveryResumeCommitRequestEnvelopeBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountRecoveryResumeCommitRequestEnvelope &&
        envelopeVersion == other.envelopeVersion &&
        keyEpoch == other.keyEpoch &&
        accountKeyEnvelope == other.accountKeyEnvelope;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, envelopeVersion.hashCode);
    _$hash = $jc(_$hash, keyEpoch.hashCode);
    _$hash = $jc(_$hash, accountKeyEnvelope.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
            r'AccountRecoveryResumeCommitRequestEnvelope',
          )
          ..add('envelopeVersion', envelopeVersion)
          ..add('keyEpoch', keyEpoch)
          ..add('accountKeyEnvelope', accountKeyEnvelope))
        .toString();
  }
}

class AccountRecoveryResumeCommitRequestEnvelopeBuilder
    implements
        Builder<
          AccountRecoveryResumeCommitRequestEnvelope,
          AccountRecoveryResumeCommitRequestEnvelopeBuilder
        > {
  _$AccountRecoveryResumeCommitRequestEnvelope? _$v;

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

  AccountRecoveryResumeCommitRequestEnvelopeBuilder() {
    AccountRecoveryResumeCommitRequestEnvelope._defaults(this);
  }

  AccountRecoveryResumeCommitRequestEnvelopeBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _envelopeVersion = $v.envelopeVersion;
      _keyEpoch = $v.keyEpoch;
      _accountKeyEnvelope = $v.accountKeyEnvelope;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AccountRecoveryResumeCommitRequestEnvelope other) {
    _$v = other as _$AccountRecoveryResumeCommitRequestEnvelope;
  }

  @override
  void update(
    void Function(AccountRecoveryResumeCommitRequestEnvelopeBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  AccountRecoveryResumeCommitRequestEnvelope build() => _build();

  _$AccountRecoveryResumeCommitRequestEnvelope _build() {
    final _$result =
        _$v ??
        _$AccountRecoveryResumeCommitRequestEnvelope._(
          envelopeVersion: BuiltValueNullFieldError.checkNotNull(
            envelopeVersion,
            r'AccountRecoveryResumeCommitRequestEnvelope',
            'envelopeVersion',
          ),
          keyEpoch: BuiltValueNullFieldError.checkNotNull(
            keyEpoch,
            r'AccountRecoveryResumeCommitRequestEnvelope',
            'keyEpoch',
          ),
          accountKeyEnvelope: BuiltValueNullFieldError.checkNotNull(
            accountKeyEnvelope,
            r'AccountRecoveryResumeCommitRequestEnvelope',
            'accountKeyEnvelope',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
