// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'initialize_device_security_state_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$InitializeDeviceSecurityStateRequest
    extends InitializeDeviceSecurityStateRequest {
  @override
  final int generation;
  @override
  final int keyEpoch;
  @override
  final int membershipManifestVersion;
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
  @override
  final InitializeDeviceSecurityStateEnvelope currentDeviceEnvelope;

  factory _$InitializeDeviceSecurityStateRequest([
    void Function(InitializeDeviceSecurityStateRequestBuilder)? updates,
  ]) =>
      (InitializeDeviceSecurityStateRequestBuilder()..update(updates))._build();

  _$InitializeDeviceSecurityStateRequest._({
    required this.generation,
    required this.keyEpoch,
    required this.membershipManifestVersion,
    required this.membershipManifest,
    required this.membershipManifestDigest,
    required this.recoveryPublicKeyVersion,
    required this.recoveryPublicKey,
    required this.recoveryCapsuleVersion,
    required this.recoveryCapsule,
    required this.currentDeviceEnvelope,
  }) : super._();
  @override
  InitializeDeviceSecurityStateRequest rebuild(
    void Function(InitializeDeviceSecurityStateRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  InitializeDeviceSecurityStateRequestBuilder toBuilder() =>
      InitializeDeviceSecurityStateRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is InitializeDeviceSecurityStateRequest &&
        generation == other.generation &&
        keyEpoch == other.keyEpoch &&
        membershipManifestVersion == other.membershipManifestVersion &&
        membershipManifest == other.membershipManifest &&
        membershipManifestDigest == other.membershipManifestDigest &&
        recoveryPublicKeyVersion == other.recoveryPublicKeyVersion &&
        recoveryPublicKey == other.recoveryPublicKey &&
        recoveryCapsuleVersion == other.recoveryCapsuleVersion &&
        recoveryCapsule == other.recoveryCapsule &&
        currentDeviceEnvelope == other.currentDeviceEnvelope;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, generation.hashCode);
    _$hash = $jc(_$hash, keyEpoch.hashCode);
    _$hash = $jc(_$hash, membershipManifestVersion.hashCode);
    _$hash = $jc(_$hash, membershipManifest.hashCode);
    _$hash = $jc(_$hash, membershipManifestDigest.hashCode);
    _$hash = $jc(_$hash, recoveryPublicKeyVersion.hashCode);
    _$hash = $jc(_$hash, recoveryPublicKey.hashCode);
    _$hash = $jc(_$hash, recoveryCapsuleVersion.hashCode);
    _$hash = $jc(_$hash, recoveryCapsule.hashCode);
    _$hash = $jc(_$hash, currentDeviceEnvelope.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'InitializeDeviceSecurityStateRequest')
          ..add('generation', generation)
          ..add('keyEpoch', keyEpoch)
          ..add('membershipManifestVersion', membershipManifestVersion)
          ..add('membershipManifest', membershipManifest)
          ..add('membershipManifestDigest', membershipManifestDigest)
          ..add('recoveryPublicKeyVersion', recoveryPublicKeyVersion)
          ..add('recoveryPublicKey', recoveryPublicKey)
          ..add('recoveryCapsuleVersion', recoveryCapsuleVersion)
          ..add('recoveryCapsule', recoveryCapsule)
          ..add('currentDeviceEnvelope', currentDeviceEnvelope))
        .toString();
  }
}

class InitializeDeviceSecurityStateRequestBuilder
    implements
        Builder<
          InitializeDeviceSecurityStateRequest,
          InitializeDeviceSecurityStateRequestBuilder
        > {
  _$InitializeDeviceSecurityStateRequest? _$v;

  int? _generation;
  int? get generation => _$this._generation;
  set generation(int? generation) => _$this._generation = generation;

  int? _keyEpoch;
  int? get keyEpoch => _$this._keyEpoch;
  set keyEpoch(int? keyEpoch) => _$this._keyEpoch = keyEpoch;

  int? _membershipManifestVersion;
  int? get membershipManifestVersion => _$this._membershipManifestVersion;
  set membershipManifestVersion(int? membershipManifestVersion) =>
      _$this._membershipManifestVersion = membershipManifestVersion;

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

  InitializeDeviceSecurityStateEnvelopeBuilder? _currentDeviceEnvelope;
  InitializeDeviceSecurityStateEnvelopeBuilder get currentDeviceEnvelope =>
      _$this._currentDeviceEnvelope ??=
          InitializeDeviceSecurityStateEnvelopeBuilder();
  set currentDeviceEnvelope(
    InitializeDeviceSecurityStateEnvelopeBuilder? currentDeviceEnvelope,
  ) => _$this._currentDeviceEnvelope = currentDeviceEnvelope;

  InitializeDeviceSecurityStateRequestBuilder() {
    InitializeDeviceSecurityStateRequest._defaults(this);
  }

  InitializeDeviceSecurityStateRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _generation = $v.generation;
      _keyEpoch = $v.keyEpoch;
      _membershipManifestVersion = $v.membershipManifestVersion;
      _membershipManifest = $v.membershipManifest;
      _membershipManifestDigest = $v.membershipManifestDigest;
      _recoveryPublicKeyVersion = $v.recoveryPublicKeyVersion;
      _recoveryPublicKey = $v.recoveryPublicKey;
      _recoveryCapsuleVersion = $v.recoveryCapsuleVersion;
      _recoveryCapsule = $v.recoveryCapsule;
      _currentDeviceEnvelope = $v.currentDeviceEnvelope.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(InitializeDeviceSecurityStateRequest other) {
    _$v = other as _$InitializeDeviceSecurityStateRequest;
  }

  @override
  void update(
    void Function(InitializeDeviceSecurityStateRequestBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  InitializeDeviceSecurityStateRequest build() => _build();

  _$InitializeDeviceSecurityStateRequest _build() {
    _$InitializeDeviceSecurityStateRequest _$result;
    try {
      _$result =
          _$v ??
          _$InitializeDeviceSecurityStateRequest._(
            generation: BuiltValueNullFieldError.checkNotNull(
              generation,
              r'InitializeDeviceSecurityStateRequest',
              'generation',
            ),
            keyEpoch: BuiltValueNullFieldError.checkNotNull(
              keyEpoch,
              r'InitializeDeviceSecurityStateRequest',
              'keyEpoch',
            ),
            membershipManifestVersion: BuiltValueNullFieldError.checkNotNull(
              membershipManifestVersion,
              r'InitializeDeviceSecurityStateRequest',
              'membershipManifestVersion',
            ),
            membershipManifest: BuiltValueNullFieldError.checkNotNull(
              membershipManifest,
              r'InitializeDeviceSecurityStateRequest',
              'membershipManifest',
            ),
            membershipManifestDigest: BuiltValueNullFieldError.checkNotNull(
              membershipManifestDigest,
              r'InitializeDeviceSecurityStateRequest',
              'membershipManifestDigest',
            ),
            recoveryPublicKeyVersion: BuiltValueNullFieldError.checkNotNull(
              recoveryPublicKeyVersion,
              r'InitializeDeviceSecurityStateRequest',
              'recoveryPublicKeyVersion',
            ),
            recoveryPublicKey: BuiltValueNullFieldError.checkNotNull(
              recoveryPublicKey,
              r'InitializeDeviceSecurityStateRequest',
              'recoveryPublicKey',
            ),
            recoveryCapsuleVersion: BuiltValueNullFieldError.checkNotNull(
              recoveryCapsuleVersion,
              r'InitializeDeviceSecurityStateRequest',
              'recoveryCapsuleVersion',
            ),
            recoveryCapsule: BuiltValueNullFieldError.checkNotNull(
              recoveryCapsule,
              r'InitializeDeviceSecurityStateRequest',
              'recoveryCapsule',
            ),
            currentDeviceEnvelope: currentDeviceEnvelope.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'currentDeviceEnvelope';
        currentDeviceEnvelope.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'InitializeDeviceSecurityStateRequest',
          _$failedField,
          e.toString(),
        );
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
