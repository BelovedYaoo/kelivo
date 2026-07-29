// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_security_state_history_item.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AccountSecurityStateHistoryItem
    extends AccountSecurityStateHistoryItem {
  @override
  final int generation;
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
  @override
  final String operationId;
  @override
  final DateTime committedAt;

  factory _$AccountSecurityStateHistoryItem([
    void Function(AccountSecurityStateHistoryItemBuilder)? updates,
  ]) => (AccountSecurityStateHistoryItemBuilder()..update(updates))._build();

  _$AccountSecurityStateHistoryItem._({
    required this.generation,
    required this.keyEpoch,
    required this.membershipManifest,
    required this.membershipManifestDigest,
    required this.recoveryPublicKeyVersion,
    required this.recoveryPublicKey,
    required this.recoveryCapsuleVersion,
    required this.recoveryCapsule,
    required this.operationId,
    required this.committedAt,
  }) : super._();
  @override
  AccountSecurityStateHistoryItem rebuild(
    void Function(AccountSecurityStateHistoryItemBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountSecurityStateHistoryItemBuilder toBuilder() =>
      AccountSecurityStateHistoryItemBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountSecurityStateHistoryItem &&
        generation == other.generation &&
        keyEpoch == other.keyEpoch &&
        membershipManifest == other.membershipManifest &&
        membershipManifestDigest == other.membershipManifestDigest &&
        recoveryPublicKeyVersion == other.recoveryPublicKeyVersion &&
        recoveryPublicKey == other.recoveryPublicKey &&
        recoveryCapsuleVersion == other.recoveryCapsuleVersion &&
        recoveryCapsule == other.recoveryCapsule &&
        operationId == other.operationId &&
        committedAt == other.committedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, generation.hashCode);
    _$hash = $jc(_$hash, keyEpoch.hashCode);
    _$hash = $jc(_$hash, membershipManifest.hashCode);
    _$hash = $jc(_$hash, membershipManifestDigest.hashCode);
    _$hash = $jc(_$hash, recoveryPublicKeyVersion.hashCode);
    _$hash = $jc(_$hash, recoveryPublicKey.hashCode);
    _$hash = $jc(_$hash, recoveryCapsuleVersion.hashCode);
    _$hash = $jc(_$hash, recoveryCapsule.hashCode);
    _$hash = $jc(_$hash, operationId.hashCode);
    _$hash = $jc(_$hash, committedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AccountSecurityStateHistoryItem')
          ..add('generation', generation)
          ..add('keyEpoch', keyEpoch)
          ..add('membershipManifest', membershipManifest)
          ..add('membershipManifestDigest', membershipManifestDigest)
          ..add('recoveryPublicKeyVersion', recoveryPublicKeyVersion)
          ..add('recoveryPublicKey', recoveryPublicKey)
          ..add('recoveryCapsuleVersion', recoveryCapsuleVersion)
          ..add('recoveryCapsule', recoveryCapsule)
          ..add('operationId', operationId)
          ..add('committedAt', committedAt))
        .toString();
  }
}

class AccountSecurityStateHistoryItemBuilder
    implements
        Builder<
          AccountSecurityStateHistoryItem,
          AccountSecurityStateHistoryItemBuilder
        > {
  _$AccountSecurityStateHistoryItem? _$v;

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

  String? _operationId;
  String? get operationId => _$this._operationId;
  set operationId(String? operationId) => _$this._operationId = operationId;

  DateTime? _committedAt;
  DateTime? get committedAt => _$this._committedAt;
  set committedAt(DateTime? committedAt) => _$this._committedAt = committedAt;

  AccountSecurityStateHistoryItemBuilder() {
    AccountSecurityStateHistoryItem._defaults(this);
  }

  AccountSecurityStateHistoryItemBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _generation = $v.generation;
      _keyEpoch = $v.keyEpoch;
      _membershipManifest = $v.membershipManifest;
      _membershipManifestDigest = $v.membershipManifestDigest;
      _recoveryPublicKeyVersion = $v.recoveryPublicKeyVersion;
      _recoveryPublicKey = $v.recoveryPublicKey;
      _recoveryCapsuleVersion = $v.recoveryCapsuleVersion;
      _recoveryCapsule = $v.recoveryCapsule;
      _operationId = $v.operationId;
      _committedAt = $v.committedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AccountSecurityStateHistoryItem other) {
    _$v = other as _$AccountSecurityStateHistoryItem;
  }

  @override
  void update(void Function(AccountSecurityStateHistoryItemBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AccountSecurityStateHistoryItem build() => _build();

  _$AccountSecurityStateHistoryItem _build() {
    final _$result =
        _$v ??
        _$AccountSecurityStateHistoryItem._(
          generation: BuiltValueNullFieldError.checkNotNull(
            generation,
            r'AccountSecurityStateHistoryItem',
            'generation',
          ),
          keyEpoch: BuiltValueNullFieldError.checkNotNull(
            keyEpoch,
            r'AccountSecurityStateHistoryItem',
            'keyEpoch',
          ),
          membershipManifest: BuiltValueNullFieldError.checkNotNull(
            membershipManifest,
            r'AccountSecurityStateHistoryItem',
            'membershipManifest',
          ),
          membershipManifestDigest: BuiltValueNullFieldError.checkNotNull(
            membershipManifestDigest,
            r'AccountSecurityStateHistoryItem',
            'membershipManifestDigest',
          ),
          recoveryPublicKeyVersion: BuiltValueNullFieldError.checkNotNull(
            recoveryPublicKeyVersion,
            r'AccountSecurityStateHistoryItem',
            'recoveryPublicKeyVersion',
          ),
          recoveryPublicKey: BuiltValueNullFieldError.checkNotNull(
            recoveryPublicKey,
            r'AccountSecurityStateHistoryItem',
            'recoveryPublicKey',
          ),
          recoveryCapsuleVersion: BuiltValueNullFieldError.checkNotNull(
            recoveryCapsuleVersion,
            r'AccountSecurityStateHistoryItem',
            'recoveryCapsuleVersion',
          ),
          recoveryCapsule: BuiltValueNullFieldError.checkNotNull(
            recoveryCapsule,
            r'AccountSecurityStateHistoryItem',
            'recoveryCapsule',
          ),
          operationId: BuiltValueNullFieldError.checkNotNull(
            operationId,
            r'AccountSecurityStateHistoryItem',
            'operationId',
          ),
          committedAt: BuiltValueNullFieldError.checkNotNull(
            committedAt,
            r'AccountSecurityStateHistoryItem',
            'committedAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
