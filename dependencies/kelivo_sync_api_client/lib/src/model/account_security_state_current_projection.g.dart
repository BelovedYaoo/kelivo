// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_security_state_current_projection.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum
_$accountSecurityStateCurrentProjectionDataRekeyPhaseEnum_ready =
    const AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum._('ready');
const AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum
_$accountSecurityStateCurrentProjectionDataRekeyPhaseEnum_rekeyPending =
    const AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum._(
      'rekeyPending',
    );

AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum
_$accountSecurityStateCurrentProjectionDataRekeyPhaseEnumValueOf(String name) {
  switch (name) {
    case 'ready':
      return _$accountSecurityStateCurrentProjectionDataRekeyPhaseEnum_ready;
    case 'rekeyPending':
      return _$accountSecurityStateCurrentProjectionDataRekeyPhaseEnum_rekeyPending;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum>
_$accountSecurityStateCurrentProjectionDataRekeyPhaseEnumValues =
    BuiltSet<AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum>(
      const <AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum>[
        _$accountSecurityStateCurrentProjectionDataRekeyPhaseEnum_ready,
        _$accountSecurityStateCurrentProjectionDataRekeyPhaseEnum_rekeyPending,
      ],
    );

Serializer<AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum>
_$accountSecurityStateCurrentProjectionDataRekeyPhaseEnumSerializer =
    _$AccountSecurityStateCurrentProjectionDataRekeyPhaseEnumSerializer();

class _$AccountSecurityStateCurrentProjectionDataRekeyPhaseEnumSerializer
    implements
        PrimitiveSerializer<
          AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum
        > {
  static const Map<String, Object> _toWire = const <String, Object>{
    'ready': 'ready',
    'rekeyPending': 'rekey-pending',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'ready': 'ready',
    'rekey-pending': 'rekeyPending',
  };

  @override
  final Iterable<Type> types = const <Type>[
    AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum,
  ];
  @override
  final String wireName =
      'AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AccountSecurityStateCurrentProjection
    extends AccountSecurityStateCurrentProjection {
  @override
  final int generation;
  @override
  final int keyEpoch;
  @override
  final AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum dataRekeyPhase;
  @override
  final String membershipManifestDigest;
  @override
  final int recoveryPublicKeyVersion;
  @override
  final String recoveryPublicKey;
  @override
  final int recoveryCapsuleVersion;
  @override
  final DateTime updatedAt;

  factory _$AccountSecurityStateCurrentProjection([
    void Function(AccountSecurityStateCurrentProjectionBuilder)? updates,
  ]) => (AccountSecurityStateCurrentProjectionBuilder()..update(updates))
      ._build();

  _$AccountSecurityStateCurrentProjection._({
    required this.generation,
    required this.keyEpoch,
    required this.dataRekeyPhase,
    required this.membershipManifestDigest,
    required this.recoveryPublicKeyVersion,
    required this.recoveryPublicKey,
    required this.recoveryCapsuleVersion,
    required this.updatedAt,
  }) : super._();
  @override
  AccountSecurityStateCurrentProjection rebuild(
    void Function(AccountSecurityStateCurrentProjectionBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountSecurityStateCurrentProjectionBuilder toBuilder() =>
      AccountSecurityStateCurrentProjectionBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountSecurityStateCurrentProjection &&
        generation == other.generation &&
        keyEpoch == other.keyEpoch &&
        dataRekeyPhase == other.dataRekeyPhase &&
        membershipManifestDigest == other.membershipManifestDigest &&
        recoveryPublicKeyVersion == other.recoveryPublicKeyVersion &&
        recoveryPublicKey == other.recoveryPublicKey &&
        recoveryCapsuleVersion == other.recoveryCapsuleVersion &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, generation.hashCode);
    _$hash = $jc(_$hash, keyEpoch.hashCode);
    _$hash = $jc(_$hash, dataRekeyPhase.hashCode);
    _$hash = $jc(_$hash, membershipManifestDigest.hashCode);
    _$hash = $jc(_$hash, recoveryPublicKeyVersion.hashCode);
    _$hash = $jc(_$hash, recoveryPublicKey.hashCode);
    _$hash = $jc(_$hash, recoveryCapsuleVersion.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
            r'AccountSecurityStateCurrentProjection',
          )
          ..add('generation', generation)
          ..add('keyEpoch', keyEpoch)
          ..add('dataRekeyPhase', dataRekeyPhase)
          ..add('membershipManifestDigest', membershipManifestDigest)
          ..add('recoveryPublicKeyVersion', recoveryPublicKeyVersion)
          ..add('recoveryPublicKey', recoveryPublicKey)
          ..add('recoveryCapsuleVersion', recoveryCapsuleVersion)
          ..add('updatedAt', updatedAt))
        .toString();
  }
}

class AccountSecurityStateCurrentProjectionBuilder
    implements
        Builder<
          AccountSecurityStateCurrentProjection,
          AccountSecurityStateCurrentProjectionBuilder
        > {
  _$AccountSecurityStateCurrentProjection? _$v;

  int? _generation;
  int? get generation => _$this._generation;
  set generation(int? generation) => _$this._generation = generation;

  int? _keyEpoch;
  int? get keyEpoch => _$this._keyEpoch;
  set keyEpoch(int? keyEpoch) => _$this._keyEpoch = keyEpoch;

  AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum? _dataRekeyPhase;
  AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum? get dataRekeyPhase =>
      _$this._dataRekeyPhase;
  set dataRekeyPhase(
    AccountSecurityStateCurrentProjectionDataRekeyPhaseEnum? dataRekeyPhase,
  ) => _$this._dataRekeyPhase = dataRekeyPhase;

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

  DateTime? _updatedAt;
  DateTime? get updatedAt => _$this._updatedAt;
  set updatedAt(DateTime? updatedAt) => _$this._updatedAt = updatedAt;

  AccountSecurityStateCurrentProjectionBuilder() {
    AccountSecurityStateCurrentProjection._defaults(this);
  }

  AccountSecurityStateCurrentProjectionBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _generation = $v.generation;
      _keyEpoch = $v.keyEpoch;
      _dataRekeyPhase = $v.dataRekeyPhase;
      _membershipManifestDigest = $v.membershipManifestDigest;
      _recoveryPublicKeyVersion = $v.recoveryPublicKeyVersion;
      _recoveryPublicKey = $v.recoveryPublicKey;
      _recoveryCapsuleVersion = $v.recoveryCapsuleVersion;
      _updatedAt = $v.updatedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AccountSecurityStateCurrentProjection other) {
    _$v = other as _$AccountSecurityStateCurrentProjection;
  }

  @override
  void update(
    void Function(AccountSecurityStateCurrentProjectionBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  AccountSecurityStateCurrentProjection build() => _build();

  _$AccountSecurityStateCurrentProjection _build() {
    final _$result =
        _$v ??
        _$AccountSecurityStateCurrentProjection._(
          generation: BuiltValueNullFieldError.checkNotNull(
            generation,
            r'AccountSecurityStateCurrentProjection',
            'generation',
          ),
          keyEpoch: BuiltValueNullFieldError.checkNotNull(
            keyEpoch,
            r'AccountSecurityStateCurrentProjection',
            'keyEpoch',
          ),
          dataRekeyPhase: BuiltValueNullFieldError.checkNotNull(
            dataRekeyPhase,
            r'AccountSecurityStateCurrentProjection',
            'dataRekeyPhase',
          ),
          membershipManifestDigest: BuiltValueNullFieldError.checkNotNull(
            membershipManifestDigest,
            r'AccountSecurityStateCurrentProjection',
            'membershipManifestDigest',
          ),
          recoveryPublicKeyVersion: BuiltValueNullFieldError.checkNotNull(
            recoveryPublicKeyVersion,
            r'AccountSecurityStateCurrentProjection',
            'recoveryPublicKeyVersion',
          ),
          recoveryPublicKey: BuiltValueNullFieldError.checkNotNull(
            recoveryPublicKey,
            r'AccountSecurityStateCurrentProjection',
            'recoveryPublicKey',
          ),
          recoveryCapsuleVersion: BuiltValueNullFieldError.checkNotNull(
            recoveryCapsuleVersion,
            r'AccountSecurityStateCurrentProjection',
            'recoveryCapsuleVersion',
          ),
          updatedAt: BuiltValueNullFieldError.checkNotNull(
            updatedAt,
            r'AccountSecurityStateCurrentProjection',
            'updatedAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
