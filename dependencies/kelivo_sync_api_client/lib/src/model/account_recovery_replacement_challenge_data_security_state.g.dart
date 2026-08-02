// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_recovery_replacement_challenge_data_security_state.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AccountRecoveryReplacementChallengeDataSecurityState
    extends AccountRecoveryReplacementChallengeDataSecurityState {
  @override
  final int generation;
  @override
  final int keyEpoch;
  @override
  final String membershipManifest;
  @override
  final String membershipManifestDigest;
  @override
  final String membershipOperationId;
  @override
  final int recoveryPublicKeyVersion;
  @override
  final String recoveryPublicKey;
  @override
  final int recoveryCapsuleVersion;
  @override
  final String recoveryCapsule;
  @override
  final String recoveryCapsuleDigest;

  factory _$AccountRecoveryReplacementChallengeDataSecurityState([
    void Function(AccountRecoveryReplacementChallengeDataSecurityStateBuilder)?
    updates,
  ]) =>
      (AccountRecoveryReplacementChallengeDataSecurityStateBuilder()
            ..update(updates))
          ._build();

  _$AccountRecoveryReplacementChallengeDataSecurityState._({
    required this.generation,
    required this.keyEpoch,
    required this.membershipManifest,
    required this.membershipManifestDigest,
    required this.membershipOperationId,
    required this.recoveryPublicKeyVersion,
    required this.recoveryPublicKey,
    required this.recoveryCapsuleVersion,
    required this.recoveryCapsule,
    required this.recoveryCapsuleDigest,
  }) : super._();
  @override
  AccountRecoveryReplacementChallengeDataSecurityState rebuild(
    void Function(AccountRecoveryReplacementChallengeDataSecurityStateBuilder)
    updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountRecoveryReplacementChallengeDataSecurityStateBuilder toBuilder() =>
      AccountRecoveryReplacementChallengeDataSecurityStateBuilder()
        ..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountRecoveryReplacementChallengeDataSecurityState &&
        generation == other.generation &&
        keyEpoch == other.keyEpoch &&
        membershipManifest == other.membershipManifest &&
        membershipManifestDigest == other.membershipManifestDigest &&
        membershipOperationId == other.membershipOperationId &&
        recoveryPublicKeyVersion == other.recoveryPublicKeyVersion &&
        recoveryPublicKey == other.recoveryPublicKey &&
        recoveryCapsuleVersion == other.recoveryCapsuleVersion &&
        recoveryCapsule == other.recoveryCapsule &&
        recoveryCapsuleDigest == other.recoveryCapsuleDigest;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, generation.hashCode);
    _$hash = $jc(_$hash, keyEpoch.hashCode);
    _$hash = $jc(_$hash, membershipManifest.hashCode);
    _$hash = $jc(_$hash, membershipManifestDigest.hashCode);
    _$hash = $jc(_$hash, membershipOperationId.hashCode);
    _$hash = $jc(_$hash, recoveryPublicKeyVersion.hashCode);
    _$hash = $jc(_$hash, recoveryPublicKey.hashCode);
    _$hash = $jc(_$hash, recoveryCapsuleVersion.hashCode);
    _$hash = $jc(_$hash, recoveryCapsule.hashCode);
    _$hash = $jc(_$hash, recoveryCapsuleDigest.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
            r'AccountRecoveryReplacementChallengeDataSecurityState',
          )
          ..add('generation', generation)
          ..add('keyEpoch', keyEpoch)
          ..add('membershipManifest', membershipManifest)
          ..add('membershipManifestDigest', membershipManifestDigest)
          ..add('membershipOperationId', membershipOperationId)
          ..add('recoveryPublicKeyVersion', recoveryPublicKeyVersion)
          ..add('recoveryPublicKey', recoveryPublicKey)
          ..add('recoveryCapsuleVersion', recoveryCapsuleVersion)
          ..add('recoveryCapsule', recoveryCapsule)
          ..add('recoveryCapsuleDigest', recoveryCapsuleDigest))
        .toString();
  }
}

class AccountRecoveryReplacementChallengeDataSecurityStateBuilder
    implements
        Builder<
          AccountRecoveryReplacementChallengeDataSecurityState,
          AccountRecoveryReplacementChallengeDataSecurityStateBuilder
        > {
  _$AccountRecoveryReplacementChallengeDataSecurityState? _$v;

  int? _generation;
  int? get generation => _$this._generation;
  set generation(int? generation) => _$this._generation = generation;

  int? _keyEpoch;
  int? get keyEpoch => _$this._keyEpoch;
  set keyEpoch(int? keyEpoch) => _$this._keyEpoch = keyEpoch;

  String? _membershipManifest;
  String? get membershipManifest => _$this._membershipManifest;
  set membershipManifest(String? membershipManifest) =>
      _$this._membershipManifest = membershipManifest;

  String? _membershipManifestDigest;
  String? get membershipManifestDigest => _$this._membershipManifestDigest;
  set membershipManifestDigest(String? membershipManifestDigest) =>
      _$this._membershipManifestDigest = membershipManifestDigest;

  String? _membershipOperationId;
  String? get membershipOperationId => _$this._membershipOperationId;
  set membershipOperationId(String? membershipOperationId) =>
      _$this._membershipOperationId = membershipOperationId;

  int? _recoveryPublicKeyVersion;
  int? get recoveryPublicKeyVersion => _$this._recoveryPublicKeyVersion;
  set recoveryPublicKeyVersion(int? recoveryPublicKeyVersion) =>
      _$this._recoveryPublicKeyVersion = recoveryPublicKeyVersion;

  String? _recoveryPublicKey;
  String? get recoveryPublicKey => _$this._recoveryPublicKey;
  set recoveryPublicKey(String? recoveryPublicKey) =>
      _$this._recoveryPublicKey = recoveryPublicKey;

  int? _recoveryCapsuleVersion;
  int? get recoveryCapsuleVersion => _$this._recoveryCapsuleVersion;
  set recoveryCapsuleVersion(int? recoveryCapsuleVersion) =>
      _$this._recoveryCapsuleVersion = recoveryCapsuleVersion;

  String? _recoveryCapsule;
  String? get recoveryCapsule => _$this._recoveryCapsule;
  set recoveryCapsule(String? recoveryCapsule) =>
      _$this._recoveryCapsule = recoveryCapsule;

  String? _recoveryCapsuleDigest;
  String? get recoveryCapsuleDigest => _$this._recoveryCapsuleDigest;
  set recoveryCapsuleDigest(String? recoveryCapsuleDigest) =>
      _$this._recoveryCapsuleDigest = recoveryCapsuleDigest;

  AccountRecoveryReplacementChallengeDataSecurityStateBuilder() {
    AccountRecoveryReplacementChallengeDataSecurityState._defaults(this);
  }

  AccountRecoveryReplacementChallengeDataSecurityStateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _generation = $v.generation;
      _keyEpoch = $v.keyEpoch;
      _membershipManifest = $v.membershipManifest;
      _membershipManifestDigest = $v.membershipManifestDigest;
      _membershipOperationId = $v.membershipOperationId;
      _recoveryPublicKeyVersion = $v.recoveryPublicKeyVersion;
      _recoveryPublicKey = $v.recoveryPublicKey;
      _recoveryCapsuleVersion = $v.recoveryCapsuleVersion;
      _recoveryCapsule = $v.recoveryCapsule;
      _recoveryCapsuleDigest = $v.recoveryCapsuleDigest;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AccountRecoveryReplacementChallengeDataSecurityState other) {
    _$v = other as _$AccountRecoveryReplacementChallengeDataSecurityState;
  }

  @override
  void update(
    void Function(AccountRecoveryReplacementChallengeDataSecurityStateBuilder)?
    updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  AccountRecoveryReplacementChallengeDataSecurityState build() => _build();

  _$AccountRecoveryReplacementChallengeDataSecurityState _build() {
    final _$result =
        _$v ??
        _$AccountRecoveryReplacementChallengeDataSecurityState._(
          generation: BuiltValueNullFieldError.checkNotNull(
            generation,
            r'AccountRecoveryReplacementChallengeDataSecurityState',
            'generation',
          ),
          keyEpoch: BuiltValueNullFieldError.checkNotNull(
            keyEpoch,
            r'AccountRecoveryReplacementChallengeDataSecurityState',
            'keyEpoch',
          ),
          membershipManifest: BuiltValueNullFieldError.checkNotNull(
            membershipManifest,
            r'AccountRecoveryReplacementChallengeDataSecurityState',
            'membershipManifest',
          ),
          membershipManifestDigest: BuiltValueNullFieldError.checkNotNull(
            membershipManifestDigest,
            r'AccountRecoveryReplacementChallengeDataSecurityState',
            'membershipManifestDigest',
          ),
          membershipOperationId: BuiltValueNullFieldError.checkNotNull(
            membershipOperationId,
            r'AccountRecoveryReplacementChallengeDataSecurityState',
            'membershipOperationId',
          ),
          recoveryPublicKeyVersion: BuiltValueNullFieldError.checkNotNull(
            recoveryPublicKeyVersion,
            r'AccountRecoveryReplacementChallengeDataSecurityState',
            'recoveryPublicKeyVersion',
          ),
          recoveryPublicKey: BuiltValueNullFieldError.checkNotNull(
            recoveryPublicKey,
            r'AccountRecoveryReplacementChallengeDataSecurityState',
            'recoveryPublicKey',
          ),
          recoveryCapsuleVersion: BuiltValueNullFieldError.checkNotNull(
            recoveryCapsuleVersion,
            r'AccountRecoveryReplacementChallengeDataSecurityState',
            'recoveryCapsuleVersion',
          ),
          recoveryCapsule: BuiltValueNullFieldError.checkNotNull(
            recoveryCapsule,
            r'AccountRecoveryReplacementChallengeDataSecurityState',
            'recoveryCapsule',
          ),
          recoveryCapsuleDigest: BuiltValueNullFieldError.checkNotNull(
            recoveryCapsuleDigest,
            r'AccountRecoveryReplacementChallengeDataSecurityState',
            'recoveryCapsuleDigest',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
