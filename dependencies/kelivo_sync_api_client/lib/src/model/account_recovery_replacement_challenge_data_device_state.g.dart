// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_recovery_replacement_challenge_data_device_state.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AccountRecoveryReplacementChallengeDataDeviceState
    extends AccountRecoveryReplacementChallengeDataDeviceState {
  @override
  final int keyVersion;
  @override
  final String signingPublicKey;
  @override
  final String keyAgreementPublicKey;

  factory _$AccountRecoveryReplacementChallengeDataDeviceState([
    void Function(AccountRecoveryReplacementChallengeDataDeviceStateBuilder)?
    updates,
  ]) =>
      (AccountRecoveryReplacementChallengeDataDeviceStateBuilder()
            ..update(updates))
          ._build();

  _$AccountRecoveryReplacementChallengeDataDeviceState._({
    required this.keyVersion,
    required this.signingPublicKey,
    required this.keyAgreementPublicKey,
  }) : super._();
  @override
  AccountRecoveryReplacementChallengeDataDeviceState rebuild(
    void Function(AccountRecoveryReplacementChallengeDataDeviceStateBuilder)
    updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountRecoveryReplacementChallengeDataDeviceStateBuilder toBuilder() =>
      AccountRecoveryReplacementChallengeDataDeviceStateBuilder()
        ..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountRecoveryReplacementChallengeDataDeviceState &&
        keyVersion == other.keyVersion &&
        signingPublicKey == other.signingPublicKey &&
        keyAgreementPublicKey == other.keyAgreementPublicKey;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, keyVersion.hashCode);
    _$hash = $jc(_$hash, signingPublicKey.hashCode);
    _$hash = $jc(_$hash, keyAgreementPublicKey.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
            r'AccountRecoveryReplacementChallengeDataDeviceState',
          )
          ..add('keyVersion', keyVersion)
          ..add('signingPublicKey', signingPublicKey)
          ..add('keyAgreementPublicKey', keyAgreementPublicKey))
        .toString();
  }
}

class AccountRecoveryReplacementChallengeDataDeviceStateBuilder
    implements
        Builder<
          AccountRecoveryReplacementChallengeDataDeviceState,
          AccountRecoveryReplacementChallengeDataDeviceStateBuilder
        > {
  _$AccountRecoveryReplacementChallengeDataDeviceState? _$v;

  int? _keyVersion;
  int? get keyVersion => _$this._keyVersion;
  set keyVersion(int? keyVersion) => _$this._keyVersion = keyVersion;

  String? _signingPublicKey;
  String? get signingPublicKey => _$this._signingPublicKey;
  set signingPublicKey(String? signingPublicKey) =>
      _$this._signingPublicKey = signingPublicKey;

  String? _keyAgreementPublicKey;
  String? get keyAgreementPublicKey => _$this._keyAgreementPublicKey;
  set keyAgreementPublicKey(String? keyAgreementPublicKey) =>
      _$this._keyAgreementPublicKey = keyAgreementPublicKey;

  AccountRecoveryReplacementChallengeDataDeviceStateBuilder() {
    AccountRecoveryReplacementChallengeDataDeviceState._defaults(this);
  }

  AccountRecoveryReplacementChallengeDataDeviceStateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _keyVersion = $v.keyVersion;
      _signingPublicKey = $v.signingPublicKey;
      _keyAgreementPublicKey = $v.keyAgreementPublicKey;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AccountRecoveryReplacementChallengeDataDeviceState other) {
    _$v = other as _$AccountRecoveryReplacementChallengeDataDeviceState;
  }

  @override
  void update(
    void Function(AccountRecoveryReplacementChallengeDataDeviceStateBuilder)?
    updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  AccountRecoveryReplacementChallengeDataDeviceState build() => _build();

  _$AccountRecoveryReplacementChallengeDataDeviceState _build() {
    final _$result =
        _$v ??
        _$AccountRecoveryReplacementChallengeDataDeviceState._(
          keyVersion: BuiltValueNullFieldError.checkNotNull(
            keyVersion,
            r'AccountRecoveryReplacementChallengeDataDeviceState',
            'keyVersion',
          ),
          signingPublicKey: BuiltValueNullFieldError.checkNotNull(
            signingPublicKey,
            r'AccountRecoveryReplacementChallengeDataDeviceState',
            'signingPublicKey',
          ),
          keyAgreementPublicKey: BuiltValueNullFieldError.checkNotNull(
            keyAgreementPublicKey,
            r'AccountRecoveryReplacementChallengeDataDeviceState',
            'keyAgreementPublicKey',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
