// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_security_state_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DeviceSecurityStateData extends DeviceSecurityStateData {
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
  final String? lastOperationId;
  @override
  final DateTime updatedAt;
  @override
  final BuiltList<DeviceSecurityStateEnvelope> envelopes;

  factory _$DeviceSecurityStateData([
    void Function(DeviceSecurityStateDataBuilder)? updates,
  ]) => (DeviceSecurityStateDataBuilder()..update(updates))._build();

  _$DeviceSecurityStateData._({
    required this.generation,
    required this.keyEpoch,
    required this.membershipManifestVersion,
    required this.membershipManifest,
    required this.membershipManifestDigest,
    required this.recoveryPublicKeyVersion,
    required this.recoveryPublicKey,
    required this.recoveryCapsuleVersion,
    required this.recoveryCapsule,
    this.lastOperationId,
    required this.updatedAt,
    required this.envelopes,
  }) : super._();
  @override
  DeviceSecurityStateData rebuild(
    void Function(DeviceSecurityStateDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DeviceSecurityStateDataBuilder toBuilder() =>
      DeviceSecurityStateDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DeviceSecurityStateData &&
        generation == other.generation &&
        keyEpoch == other.keyEpoch &&
        membershipManifestVersion == other.membershipManifestVersion &&
        membershipManifest == other.membershipManifest &&
        membershipManifestDigest == other.membershipManifestDigest &&
        recoveryPublicKeyVersion == other.recoveryPublicKeyVersion &&
        recoveryPublicKey == other.recoveryPublicKey &&
        recoveryCapsuleVersion == other.recoveryCapsuleVersion &&
        recoveryCapsule == other.recoveryCapsule &&
        lastOperationId == other.lastOperationId &&
        updatedAt == other.updatedAt &&
        envelopes == other.envelopes;
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
    _$hash = $jc(_$hash, lastOperationId.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jc(_$hash, envelopes.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DeviceSecurityStateData')
          ..add('generation', generation)
          ..add('keyEpoch', keyEpoch)
          ..add('membershipManifestVersion', membershipManifestVersion)
          ..add('membershipManifest', membershipManifest)
          ..add('membershipManifestDigest', membershipManifestDigest)
          ..add('recoveryPublicKeyVersion', recoveryPublicKeyVersion)
          ..add('recoveryPublicKey', recoveryPublicKey)
          ..add('recoveryCapsuleVersion', recoveryCapsuleVersion)
          ..add('recoveryCapsule', recoveryCapsule)
          ..add('lastOperationId', lastOperationId)
          ..add('updatedAt', updatedAt)
          ..add('envelopes', envelopes))
        .toString();
  }
}

class DeviceSecurityStateDataBuilder
    implements
        Builder<DeviceSecurityStateData, DeviceSecurityStateDataBuilder> {
  _$DeviceSecurityStateData? _$v;

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

  String? _lastOperationId;
  String? get lastOperationId => _$this._lastOperationId;
  set lastOperationId(String? lastOperationId) =>
      _$this._lastOperationId = lastOperationId;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _$this._updatedAt;
  set updatedAt(DateTime? updatedAt) => _$this._updatedAt = updatedAt;

  ListBuilder<DeviceSecurityStateEnvelope>? _envelopes;
  ListBuilder<DeviceSecurityStateEnvelope> get envelopes =>
      _$this._envelopes ??= ListBuilder<DeviceSecurityStateEnvelope>();
  set envelopes(ListBuilder<DeviceSecurityStateEnvelope>? envelopes) =>
      _$this._envelopes = envelopes;

  DeviceSecurityStateDataBuilder() {
    DeviceSecurityStateData._defaults(this);
  }

  DeviceSecurityStateDataBuilder get _$this {
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
      _lastOperationId = $v.lastOperationId;
      _updatedAt = $v.updatedAt;
      _envelopes = $v.envelopes.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DeviceSecurityStateData other) {
    _$v = other as _$DeviceSecurityStateData;
  }

  @override
  void update(void Function(DeviceSecurityStateDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DeviceSecurityStateData build() => _build();

  _$DeviceSecurityStateData _build() {
    _$DeviceSecurityStateData _$result;
    try {
      _$result =
          _$v ??
          _$DeviceSecurityStateData._(
            generation: BuiltValueNullFieldError.checkNotNull(
              generation,
              r'DeviceSecurityStateData',
              'generation',
            ),
            keyEpoch: BuiltValueNullFieldError.checkNotNull(
              keyEpoch,
              r'DeviceSecurityStateData',
              'keyEpoch',
            ),
            membershipManifestVersion: BuiltValueNullFieldError.checkNotNull(
              membershipManifestVersion,
              r'DeviceSecurityStateData',
              'membershipManifestVersion',
            ),
            membershipManifest: BuiltValueNullFieldError.checkNotNull(
              membershipManifest,
              r'DeviceSecurityStateData',
              'membershipManifest',
            ),
            membershipManifestDigest: BuiltValueNullFieldError.checkNotNull(
              membershipManifestDigest,
              r'DeviceSecurityStateData',
              'membershipManifestDigest',
            ),
            recoveryPublicKeyVersion: BuiltValueNullFieldError.checkNotNull(
              recoveryPublicKeyVersion,
              r'DeviceSecurityStateData',
              'recoveryPublicKeyVersion',
            ),
            recoveryPublicKey: BuiltValueNullFieldError.checkNotNull(
              recoveryPublicKey,
              r'DeviceSecurityStateData',
              'recoveryPublicKey',
            ),
            recoveryCapsuleVersion: BuiltValueNullFieldError.checkNotNull(
              recoveryCapsuleVersion,
              r'DeviceSecurityStateData',
              'recoveryCapsuleVersion',
            ),
            recoveryCapsule: BuiltValueNullFieldError.checkNotNull(
              recoveryCapsule,
              r'DeviceSecurityStateData',
              'recoveryCapsule',
            ),
            lastOperationId: lastOperationId,
            updatedAt: BuiltValueNullFieldError.checkNotNull(
              updatedAt,
              r'DeviceSecurityStateData',
              'updatedAt',
            ),
            envelopes: envelopes.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'envelopes';
        envelopes.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'DeviceSecurityStateData',
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
