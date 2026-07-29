// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_security_state_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AccountSecurityStateDataDataRekeyPhaseEnum
_$accountSecurityStateDataDataRekeyPhaseEnum_ready =
    const AccountSecurityStateDataDataRekeyPhaseEnum._('ready');
const AccountSecurityStateDataDataRekeyPhaseEnum
_$accountSecurityStateDataDataRekeyPhaseEnum_rekeyPending =
    const AccountSecurityStateDataDataRekeyPhaseEnum._('rekeyPending');

AccountSecurityStateDataDataRekeyPhaseEnum
_$accountSecurityStateDataDataRekeyPhaseEnumValueOf(String name) {
  switch (name) {
    case 'ready':
      return _$accountSecurityStateDataDataRekeyPhaseEnum_ready;
    case 'rekeyPending':
      return _$accountSecurityStateDataDataRekeyPhaseEnum_rekeyPending;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountSecurityStateDataDataRekeyPhaseEnum>
_$accountSecurityStateDataDataRekeyPhaseEnumValues =
    BuiltSet<AccountSecurityStateDataDataRekeyPhaseEnum>(
      const <AccountSecurityStateDataDataRekeyPhaseEnum>[
        _$accountSecurityStateDataDataRekeyPhaseEnum_ready,
        _$accountSecurityStateDataDataRekeyPhaseEnum_rekeyPending,
      ],
    );

Serializer<AccountSecurityStateDataDataRekeyPhaseEnum>
_$accountSecurityStateDataDataRekeyPhaseEnumSerializer =
    _$AccountSecurityStateDataDataRekeyPhaseEnumSerializer();

class _$AccountSecurityStateDataDataRekeyPhaseEnumSerializer
    implements PrimitiveSerializer<AccountSecurityStateDataDataRekeyPhaseEnum> {
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
    AccountSecurityStateDataDataRekeyPhaseEnum,
  ];
  @override
  final String wireName = 'AccountSecurityStateDataDataRekeyPhaseEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountSecurityStateDataDataRekeyPhaseEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountSecurityStateDataDataRekeyPhaseEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AccountSecurityStateDataDataRekeyPhaseEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AccountSecurityStateData extends AccountSecurityStateData {
  @override
  final int generation;
  @override
  final int keyEpoch;
  @override
  final AccountSecurityStateDataDataRekeyPhaseEnum dataRekeyPhase;
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
  final String lastOperationId;
  @override
  final DateTime updatedAt;
  @override
  final BuiltList<AccountSecurityStateEnvelope> envelopes;

  factory _$AccountSecurityStateData([
    void Function(AccountSecurityStateDataBuilder)? updates,
  ]) => (AccountSecurityStateDataBuilder()..update(updates))._build();

  _$AccountSecurityStateData._({
    required this.generation,
    required this.keyEpoch,
    required this.dataRekeyPhase,
    required this.membershipManifest,
    required this.membershipManifestDigest,
    required this.recoveryPublicKeyVersion,
    required this.recoveryPublicKey,
    required this.recoveryCapsuleVersion,
    required this.recoveryCapsule,
    required this.lastOperationId,
    required this.updatedAt,
    required this.envelopes,
  }) : super._();
  @override
  AccountSecurityStateData rebuild(
    void Function(AccountSecurityStateDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountSecurityStateDataBuilder toBuilder() =>
      AccountSecurityStateDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountSecurityStateData &&
        generation == other.generation &&
        keyEpoch == other.keyEpoch &&
        dataRekeyPhase == other.dataRekeyPhase &&
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
    _$hash = $jc(_$hash, dataRekeyPhase.hashCode);
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
    return (newBuiltValueToStringHelper(r'AccountSecurityStateData')
          ..add('generation', generation)
          ..add('keyEpoch', keyEpoch)
          ..add('dataRekeyPhase', dataRekeyPhase)
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

class AccountSecurityStateDataBuilder
    implements
        Builder<AccountSecurityStateData, AccountSecurityStateDataBuilder> {
  _$AccountSecurityStateData? _$v;

  int? _generation;
  int? get generation => _$this._generation;
  set generation(int? generation) => _$this._generation = generation;

  int? _keyEpoch;
  int? get keyEpoch => _$this._keyEpoch;
  set keyEpoch(int? keyEpoch) => _$this._keyEpoch = keyEpoch;

  AccountSecurityStateDataDataRekeyPhaseEnum? _dataRekeyPhase;
  AccountSecurityStateDataDataRekeyPhaseEnum? get dataRekeyPhase =>
      _$this._dataRekeyPhase;
  set dataRekeyPhase(
    AccountSecurityStateDataDataRekeyPhaseEnum? dataRekeyPhase,
  ) => _$this._dataRekeyPhase = dataRekeyPhase;

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

  ListBuilder<AccountSecurityStateEnvelope>? _envelopes;
  ListBuilder<AccountSecurityStateEnvelope> get envelopes =>
      _$this._envelopes ??= ListBuilder<AccountSecurityStateEnvelope>();
  set envelopes(ListBuilder<AccountSecurityStateEnvelope>? envelopes) =>
      _$this._envelopes = envelopes;

  AccountSecurityStateDataBuilder() {
    AccountSecurityStateData._defaults(this);
  }

  AccountSecurityStateDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _generation = $v.generation;
      _keyEpoch = $v.keyEpoch;
      _dataRekeyPhase = $v.dataRekeyPhase;
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
  void replace(AccountSecurityStateData other) {
    _$v = other as _$AccountSecurityStateData;
  }

  @override
  void update(void Function(AccountSecurityStateDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AccountSecurityStateData build() => _build();

  _$AccountSecurityStateData _build() {
    _$AccountSecurityStateData _$result;
    try {
      _$result =
          _$v ??
          _$AccountSecurityStateData._(
            generation: BuiltValueNullFieldError.checkNotNull(
              generation,
              r'AccountSecurityStateData',
              'generation',
            ),
            keyEpoch: BuiltValueNullFieldError.checkNotNull(
              keyEpoch,
              r'AccountSecurityStateData',
              'keyEpoch',
            ),
            dataRekeyPhase: BuiltValueNullFieldError.checkNotNull(
              dataRekeyPhase,
              r'AccountSecurityStateData',
              'dataRekeyPhase',
            ),
            membershipManifest: BuiltValueNullFieldError.checkNotNull(
              membershipManifest,
              r'AccountSecurityStateData',
              'membershipManifest',
            ),
            membershipManifestDigest: BuiltValueNullFieldError.checkNotNull(
              membershipManifestDigest,
              r'AccountSecurityStateData',
              'membershipManifestDigest',
            ),
            recoveryPublicKeyVersion: BuiltValueNullFieldError.checkNotNull(
              recoveryPublicKeyVersion,
              r'AccountSecurityStateData',
              'recoveryPublicKeyVersion',
            ),
            recoveryPublicKey: BuiltValueNullFieldError.checkNotNull(
              recoveryPublicKey,
              r'AccountSecurityStateData',
              'recoveryPublicKey',
            ),
            recoveryCapsuleVersion: BuiltValueNullFieldError.checkNotNull(
              recoveryCapsuleVersion,
              r'AccountSecurityStateData',
              'recoveryCapsuleVersion',
            ),
            recoveryCapsule: BuiltValueNullFieldError.checkNotNull(
              recoveryCapsule,
              r'AccountSecurityStateData',
              'recoveryCapsule',
            ),
            lastOperationId: BuiltValueNullFieldError.checkNotNull(
              lastOperationId,
              r'AccountSecurityStateData',
              'lastOperationId',
            ),
            updatedAt: BuiltValueNullFieldError.checkNotNull(
              updatedAt,
              r'AccountSecurityStateData',
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
          r'AccountSecurityStateData',
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
