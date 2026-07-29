// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'genesis_security_state.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$GenesisSecurityState extends GenesisSecurityState {
  @override
  final int generation;
  @override
  final String operationId;
  @override
  final int keyEpoch;
  @override
  final String membershipManifest;
  @override
  final String membershipManifestDigest;
  @override
  final int recoveryPublicKeyVersion;
  @override
  final String recoveryPublicKey;
  @override
  final int recoveryCapsuleVersion;
  @override
  final String recoveryCapsule;

  factory _$GenesisSecurityState([
    void Function(GenesisSecurityStateBuilder)? updates,
  ]) => (GenesisSecurityStateBuilder()..update(updates))._build();

  _$GenesisSecurityState._({
    required this.generation,
    required this.operationId,
    required this.keyEpoch,
    required this.membershipManifest,
    required this.membershipManifestDigest,
    required this.recoveryPublicKeyVersion,
    required this.recoveryPublicKey,
    required this.recoveryCapsuleVersion,
    required this.recoveryCapsule,
  }) : super._();
  @override
  GenesisSecurityState rebuild(
    void Function(GenesisSecurityStateBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  GenesisSecurityStateBuilder toBuilder() =>
      GenesisSecurityStateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GenesisSecurityState &&
        generation == other.generation &&
        operationId == other.operationId &&
        keyEpoch == other.keyEpoch &&
        membershipManifest == other.membershipManifest &&
        membershipManifestDigest == other.membershipManifestDigest &&
        recoveryPublicKeyVersion == other.recoveryPublicKeyVersion &&
        recoveryPublicKey == other.recoveryPublicKey &&
        recoveryCapsuleVersion == other.recoveryCapsuleVersion &&
        recoveryCapsule == other.recoveryCapsule;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, generation.hashCode);
    _$hash = $jc(_$hash, operationId.hashCode);
    _$hash = $jc(_$hash, keyEpoch.hashCode);
    _$hash = $jc(_$hash, membershipManifest.hashCode);
    _$hash = $jc(_$hash, membershipManifestDigest.hashCode);
    _$hash = $jc(_$hash, recoveryPublicKeyVersion.hashCode);
    _$hash = $jc(_$hash, recoveryPublicKey.hashCode);
    _$hash = $jc(_$hash, recoveryCapsuleVersion.hashCode);
    _$hash = $jc(_$hash, recoveryCapsule.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'GenesisSecurityState')
          ..add('generation', generation)
          ..add('operationId', operationId)
          ..add('keyEpoch', keyEpoch)
          ..add('membershipManifest', membershipManifest)
          ..add('membershipManifestDigest', membershipManifestDigest)
          ..add('recoveryPublicKeyVersion', recoveryPublicKeyVersion)
          ..add('recoveryPublicKey', recoveryPublicKey)
          ..add('recoveryCapsuleVersion', recoveryCapsuleVersion)
          ..add('recoveryCapsule', recoveryCapsule))
        .toString();
  }
}

class GenesisSecurityStateBuilder
    implements Builder<GenesisSecurityState, GenesisSecurityStateBuilder> {
  _$GenesisSecurityState? _$v;

  int? _generation;
  int? get generation => _$this._generation;
  set generation(int? generation) => _$this._generation = generation;

  String? _operationId;
  String? get operationId => _$this._operationId;
  set operationId(String? operationId) => _$this._operationId = operationId;

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

  GenesisSecurityStateBuilder() {
    GenesisSecurityState._defaults(this);
  }

  GenesisSecurityStateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _generation = $v.generation;
      _operationId = $v.operationId;
      _keyEpoch = $v.keyEpoch;
      _membershipManifest = $v.membershipManifest;
      _membershipManifestDigest = $v.membershipManifestDigest;
      _recoveryPublicKeyVersion = $v.recoveryPublicKeyVersion;
      _recoveryPublicKey = $v.recoveryPublicKey;
      _recoveryCapsuleVersion = $v.recoveryCapsuleVersion;
      _recoveryCapsule = $v.recoveryCapsule;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GenesisSecurityState other) {
    _$v = other as _$GenesisSecurityState;
  }

  @override
  void update(void Function(GenesisSecurityStateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  GenesisSecurityState build() => _build();

  _$GenesisSecurityState _build() {
    final _$result =
        _$v ??
        _$GenesisSecurityState._(
          generation: BuiltValueNullFieldError.checkNotNull(
            generation,
            r'GenesisSecurityState',
            'generation',
          ),
          operationId: BuiltValueNullFieldError.checkNotNull(
            operationId,
            r'GenesisSecurityState',
            'operationId',
          ),
          keyEpoch: BuiltValueNullFieldError.checkNotNull(
            keyEpoch,
            r'GenesisSecurityState',
            'keyEpoch',
          ),
          membershipManifest: BuiltValueNullFieldError.checkNotNull(
            membershipManifest,
            r'GenesisSecurityState',
            'membershipManifest',
          ),
          membershipManifestDigest: BuiltValueNullFieldError.checkNotNull(
            membershipManifestDigest,
            r'GenesisSecurityState',
            'membershipManifestDigest',
          ),
          recoveryPublicKeyVersion: BuiltValueNullFieldError.checkNotNull(
            recoveryPublicKeyVersion,
            r'GenesisSecurityState',
            'recoveryPublicKeyVersion',
          ),
          recoveryPublicKey: BuiltValueNullFieldError.checkNotNull(
            recoveryPublicKey,
            r'GenesisSecurityState',
            'recoveryPublicKey',
          ),
          recoveryCapsuleVersion: BuiltValueNullFieldError.checkNotNull(
            recoveryCapsuleVersion,
            r'GenesisSecurityState',
            'recoveryCapsuleVersion',
          ),
          recoveryCapsule: BuiltValueNullFieldError.checkNotNull(
            recoveryCapsule,
            r'GenesisSecurityState',
            'recoveryCapsule',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
