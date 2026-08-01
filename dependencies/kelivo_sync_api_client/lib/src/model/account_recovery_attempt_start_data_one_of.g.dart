// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_recovery_attempt_start_data_one_of.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AccountRecoveryAttemptStartDataOneOfActionEnum
_$accountRecoveryAttemptStartDataOneOfActionEnum_challenge =
    const AccountRecoveryAttemptStartDataOneOfActionEnum._('challenge');

AccountRecoveryAttemptStartDataOneOfActionEnum
_$accountRecoveryAttemptStartDataOneOfActionEnumValueOf(String name) {
  switch (name) {
    case 'challenge':
      return _$accountRecoveryAttemptStartDataOneOfActionEnum_challenge;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountRecoveryAttemptStartDataOneOfActionEnum>
_$accountRecoveryAttemptStartDataOneOfActionEnumValues =
    BuiltSet<AccountRecoveryAttemptStartDataOneOfActionEnum>(
      const <AccountRecoveryAttemptStartDataOneOfActionEnum>[
        _$accountRecoveryAttemptStartDataOneOfActionEnum_challenge,
      ],
    );

const AccountRecoveryAttemptStartDataOneOfResultEnum
_$accountRecoveryAttemptStartDataOneOfResultEnum_created =
    const AccountRecoveryAttemptStartDataOneOfResultEnum._('created');
const AccountRecoveryAttemptStartDataOneOfResultEnum
_$accountRecoveryAttemptStartDataOneOfResultEnum_replayed =
    const AccountRecoveryAttemptStartDataOneOfResultEnum._('replayed');

AccountRecoveryAttemptStartDataOneOfResultEnum
_$accountRecoveryAttemptStartDataOneOfResultEnumValueOf(String name) {
  switch (name) {
    case 'created':
      return _$accountRecoveryAttemptStartDataOneOfResultEnum_created;
    case 'replayed':
      return _$accountRecoveryAttemptStartDataOneOfResultEnum_replayed;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountRecoveryAttemptStartDataOneOfResultEnum>
_$accountRecoveryAttemptStartDataOneOfResultEnumValues =
    BuiltSet<AccountRecoveryAttemptStartDataOneOfResultEnum>(
      const <AccountRecoveryAttemptStartDataOneOfResultEnum>[
        _$accountRecoveryAttemptStartDataOneOfResultEnum_created,
        _$accountRecoveryAttemptStartDataOneOfResultEnum_replayed,
      ],
    );

Serializer<AccountRecoveryAttemptStartDataOneOfActionEnum>
_$accountRecoveryAttemptStartDataOneOfActionEnumSerializer =
    _$AccountRecoveryAttemptStartDataOneOfActionEnumSerializer();
Serializer<AccountRecoveryAttemptStartDataOneOfResultEnum>
_$accountRecoveryAttemptStartDataOneOfResultEnumSerializer =
    _$AccountRecoveryAttemptStartDataOneOfResultEnumSerializer();

class _$AccountRecoveryAttemptStartDataOneOfActionEnumSerializer
    implements
        PrimitiveSerializer<AccountRecoveryAttemptStartDataOneOfActionEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'challenge': 'challenge',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'challenge': 'challenge',
  };

  @override
  final Iterable<Type> types = const <Type>[
    AccountRecoveryAttemptStartDataOneOfActionEnum,
  ];
  @override
  final String wireName = 'AccountRecoveryAttemptStartDataOneOfActionEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryAttemptStartDataOneOfActionEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountRecoveryAttemptStartDataOneOfActionEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AccountRecoveryAttemptStartDataOneOfActionEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AccountRecoveryAttemptStartDataOneOfResultEnumSerializer
    implements
        PrimitiveSerializer<AccountRecoveryAttemptStartDataOneOfResultEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'created': 'created',
    'replayed': 'replayed',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'created': 'created',
    'replayed': 'replayed',
  };

  @override
  final Iterable<Type> types = const <Type>[
    AccountRecoveryAttemptStartDataOneOfResultEnum,
  ];
  @override
  final String wireName = 'AccountRecoveryAttemptStartDataOneOfResultEnum';

  @override
  Object serialize(
    Serializers serializers,
    AccountRecoveryAttemptStartDataOneOfResultEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AccountRecoveryAttemptStartDataOneOfResultEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AccountRecoveryAttemptStartDataOneOfResultEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AccountRecoveryAttemptStartDataOneOf
    extends AccountRecoveryAttemptStartDataOneOf {
  @override
  final AccountRecoveryAttemptStartDataOneOfActionEnum action;
  @override
  final AccountRecoveryAttemptStartDataOneOfResultEnum result;
  @override
  final int protocolVersion;
  @override
  final String attemptId;
  @override
  final String requestDigest;
  @override
  final String challengeFrame;
  @override
  final String sealedNonce;
  @override
  final int securityGeneration;
  @override
  final int keyEpoch;
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
  final String recoveryCapsuleDigest;
  @override
  final AccountRecoveryDataState dataState;
  @override
  final DateTime expiresAt;

  factory _$AccountRecoveryAttemptStartDataOneOf([
    void Function(AccountRecoveryAttemptStartDataOneOfBuilder)? updates,
  ]) =>
      (AccountRecoveryAttemptStartDataOneOfBuilder()..update(updates))._build();

  _$AccountRecoveryAttemptStartDataOneOf._({
    required this.action,
    required this.result,
    required this.protocolVersion,
    required this.attemptId,
    required this.requestDigest,
    required this.challengeFrame,
    required this.sealedNonce,
    required this.securityGeneration,
    required this.keyEpoch,
    required this.membershipManifestDigest,
    required this.recoveryPublicKeyVersion,
    required this.recoveryPublicKey,
    required this.recoveryCapsuleVersion,
    required this.recoveryCapsule,
    required this.recoveryCapsuleDigest,
    required this.dataState,
    required this.expiresAt,
  }) : super._();
  @override
  AccountRecoveryAttemptStartDataOneOf rebuild(
    void Function(AccountRecoveryAttemptStartDataOneOfBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountRecoveryAttemptStartDataOneOfBuilder toBuilder() =>
      AccountRecoveryAttemptStartDataOneOfBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountRecoveryAttemptStartDataOneOf &&
        action == other.action &&
        result == other.result &&
        protocolVersion == other.protocolVersion &&
        attemptId == other.attemptId &&
        requestDigest == other.requestDigest &&
        challengeFrame == other.challengeFrame &&
        sealedNonce == other.sealedNonce &&
        securityGeneration == other.securityGeneration &&
        keyEpoch == other.keyEpoch &&
        membershipManifestDigest == other.membershipManifestDigest &&
        recoveryPublicKeyVersion == other.recoveryPublicKeyVersion &&
        recoveryPublicKey == other.recoveryPublicKey &&
        recoveryCapsuleVersion == other.recoveryCapsuleVersion &&
        recoveryCapsule == other.recoveryCapsule &&
        recoveryCapsuleDigest == other.recoveryCapsuleDigest &&
        dataState == other.dataState &&
        expiresAt == other.expiresAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, action.hashCode);
    _$hash = $jc(_$hash, result.hashCode);
    _$hash = $jc(_$hash, protocolVersion.hashCode);
    _$hash = $jc(_$hash, attemptId.hashCode);
    _$hash = $jc(_$hash, requestDigest.hashCode);
    _$hash = $jc(_$hash, challengeFrame.hashCode);
    _$hash = $jc(_$hash, sealedNonce.hashCode);
    _$hash = $jc(_$hash, securityGeneration.hashCode);
    _$hash = $jc(_$hash, keyEpoch.hashCode);
    _$hash = $jc(_$hash, membershipManifestDigest.hashCode);
    _$hash = $jc(_$hash, recoveryPublicKeyVersion.hashCode);
    _$hash = $jc(_$hash, recoveryPublicKey.hashCode);
    _$hash = $jc(_$hash, recoveryCapsuleVersion.hashCode);
    _$hash = $jc(_$hash, recoveryCapsule.hashCode);
    _$hash = $jc(_$hash, recoveryCapsuleDigest.hashCode);
    _$hash = $jc(_$hash, dataState.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AccountRecoveryAttemptStartDataOneOf')
          ..add('action', action)
          ..add('result', result)
          ..add('protocolVersion', protocolVersion)
          ..add('attemptId', attemptId)
          ..add('requestDigest', requestDigest)
          ..add('challengeFrame', challengeFrame)
          ..add('sealedNonce', sealedNonce)
          ..add('securityGeneration', securityGeneration)
          ..add('keyEpoch', keyEpoch)
          ..add('membershipManifestDigest', membershipManifestDigest)
          ..add('recoveryPublicKeyVersion', recoveryPublicKeyVersion)
          ..add('recoveryPublicKey', recoveryPublicKey)
          ..add('recoveryCapsuleVersion', recoveryCapsuleVersion)
          ..add('recoveryCapsule', recoveryCapsule)
          ..add('recoveryCapsuleDigest', recoveryCapsuleDigest)
          ..add('dataState', dataState)
          ..add('expiresAt', expiresAt))
        .toString();
  }
}

class AccountRecoveryAttemptStartDataOneOfBuilder
    implements
        Builder<
          AccountRecoveryAttemptStartDataOneOf,
          AccountRecoveryAttemptStartDataOneOfBuilder
        > {
  _$AccountRecoveryAttemptStartDataOneOf? _$v;

  AccountRecoveryAttemptStartDataOneOfActionEnum? _action;
  AccountRecoveryAttemptStartDataOneOfActionEnum? get action => _$this._action;
  set action(AccountRecoveryAttemptStartDataOneOfActionEnum? action) =>
      _$this._action = action;

  AccountRecoveryAttemptStartDataOneOfResultEnum? _result;
  AccountRecoveryAttemptStartDataOneOfResultEnum? get result => _$this._result;
  set result(AccountRecoveryAttemptStartDataOneOfResultEnum? result) =>
      _$this._result = result;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  String? _attemptId;
  String? get attemptId => _$this._attemptId;
  set attemptId(String? attemptId) => _$this._attemptId = attemptId;

  String? _requestDigest;
  String? get requestDigest => _$this._requestDigest;
  set requestDigest(String? requestDigest) =>
      _$this._requestDigest = requestDigest;

  String? _challengeFrame;
  String? get challengeFrame => _$this._challengeFrame;
  set challengeFrame(String? challengeFrame) =>
      _$this._challengeFrame = challengeFrame;

  String? _sealedNonce;
  String? get sealedNonce => _$this._sealedNonce;
  set sealedNonce(String? sealedNonce) => _$this._sealedNonce = sealedNonce;

  int? _securityGeneration;
  int? get securityGeneration => _$this._securityGeneration;
  set securityGeneration(int? securityGeneration) =>
      _$this._securityGeneration = securityGeneration;

  int? _keyEpoch;
  int? get keyEpoch => _$this._keyEpoch;
  set keyEpoch(int? keyEpoch) => _$this._keyEpoch = keyEpoch;

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

  String? _recoveryCapsuleDigest;
  String? get recoveryCapsuleDigest => _$this._recoveryCapsuleDigest;
  set recoveryCapsuleDigest(String? recoveryCapsuleDigest) =>
      _$this._recoveryCapsuleDigest = recoveryCapsuleDigest;

  AccountRecoveryDataStateBuilder? _dataState;
  AccountRecoveryDataStateBuilder get dataState =>
      _$this._dataState ??= AccountRecoveryDataStateBuilder();
  set dataState(AccountRecoveryDataStateBuilder? dataState) =>
      _$this._dataState = dataState;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  AccountRecoveryAttemptStartDataOneOfBuilder() {
    AccountRecoveryAttemptStartDataOneOf._defaults(this);
  }

  AccountRecoveryAttemptStartDataOneOfBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _action = $v.action;
      _result = $v.result;
      _protocolVersion = $v.protocolVersion;
      _attemptId = $v.attemptId;
      _requestDigest = $v.requestDigest;
      _challengeFrame = $v.challengeFrame;
      _sealedNonce = $v.sealedNonce;
      _securityGeneration = $v.securityGeneration;
      _keyEpoch = $v.keyEpoch;
      _membershipManifestDigest = $v.membershipManifestDigest;
      _recoveryPublicKeyVersion = $v.recoveryPublicKeyVersion;
      _recoveryPublicKey = $v.recoveryPublicKey;
      _recoveryCapsuleVersion = $v.recoveryCapsuleVersion;
      _recoveryCapsule = $v.recoveryCapsule;
      _recoveryCapsuleDigest = $v.recoveryCapsuleDigest;
      _dataState = $v.dataState.toBuilder();
      _expiresAt = $v.expiresAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AccountRecoveryAttemptStartDataOneOf other) {
    _$v = other as _$AccountRecoveryAttemptStartDataOneOf;
  }

  @override
  void update(
    void Function(AccountRecoveryAttemptStartDataOneOfBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  AccountRecoveryAttemptStartDataOneOf build() => _build();

  _$AccountRecoveryAttemptStartDataOneOf _build() {
    _$AccountRecoveryAttemptStartDataOneOf _$result;
    try {
      _$result =
          _$v ??
          _$AccountRecoveryAttemptStartDataOneOf._(
            action: BuiltValueNullFieldError.checkNotNull(
              action,
              r'AccountRecoveryAttemptStartDataOneOf',
              'action',
            ),
            result: BuiltValueNullFieldError.checkNotNull(
              result,
              r'AccountRecoveryAttemptStartDataOneOf',
              'result',
            ),
            protocolVersion: BuiltValueNullFieldError.checkNotNull(
              protocolVersion,
              r'AccountRecoveryAttemptStartDataOneOf',
              'protocolVersion',
            ),
            attemptId: BuiltValueNullFieldError.checkNotNull(
              attemptId,
              r'AccountRecoveryAttemptStartDataOneOf',
              'attemptId',
            ),
            requestDigest: BuiltValueNullFieldError.checkNotNull(
              requestDigest,
              r'AccountRecoveryAttemptStartDataOneOf',
              'requestDigest',
            ),
            challengeFrame: BuiltValueNullFieldError.checkNotNull(
              challengeFrame,
              r'AccountRecoveryAttemptStartDataOneOf',
              'challengeFrame',
            ),
            sealedNonce: BuiltValueNullFieldError.checkNotNull(
              sealedNonce,
              r'AccountRecoveryAttemptStartDataOneOf',
              'sealedNonce',
            ),
            securityGeneration: BuiltValueNullFieldError.checkNotNull(
              securityGeneration,
              r'AccountRecoveryAttemptStartDataOneOf',
              'securityGeneration',
            ),
            keyEpoch: BuiltValueNullFieldError.checkNotNull(
              keyEpoch,
              r'AccountRecoveryAttemptStartDataOneOf',
              'keyEpoch',
            ),
            membershipManifestDigest: BuiltValueNullFieldError.checkNotNull(
              membershipManifestDigest,
              r'AccountRecoveryAttemptStartDataOneOf',
              'membershipManifestDigest',
            ),
            recoveryPublicKeyVersion: BuiltValueNullFieldError.checkNotNull(
              recoveryPublicKeyVersion,
              r'AccountRecoveryAttemptStartDataOneOf',
              'recoveryPublicKeyVersion',
            ),
            recoveryPublicKey: BuiltValueNullFieldError.checkNotNull(
              recoveryPublicKey,
              r'AccountRecoveryAttemptStartDataOneOf',
              'recoveryPublicKey',
            ),
            recoveryCapsuleVersion: BuiltValueNullFieldError.checkNotNull(
              recoveryCapsuleVersion,
              r'AccountRecoveryAttemptStartDataOneOf',
              'recoveryCapsuleVersion',
            ),
            recoveryCapsule: BuiltValueNullFieldError.checkNotNull(
              recoveryCapsule,
              r'AccountRecoveryAttemptStartDataOneOf',
              'recoveryCapsule',
            ),
            recoveryCapsuleDigest: BuiltValueNullFieldError.checkNotNull(
              recoveryCapsuleDigest,
              r'AccountRecoveryAttemptStartDataOneOf',
              'recoveryCapsuleDigest',
            ),
            dataState: dataState.build(),
            expiresAt: BuiltValueNullFieldError.checkNotNull(
              expiresAt,
              r'AccountRecoveryAttemptStartDataOneOf',
              'expiresAt',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'dataState';
        dataState.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'AccountRecoveryAttemptStartDataOneOf',
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
