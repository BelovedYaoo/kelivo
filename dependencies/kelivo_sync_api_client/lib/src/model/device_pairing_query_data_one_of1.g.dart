// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_pairing_query_data_one_of1.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DevicePairingQueryDataOneOf1StatusEnum
_$devicePairingQueryDataOneOf1StatusEnum_approved =
    const DevicePairingQueryDataOneOf1StatusEnum._('approved');

DevicePairingQueryDataOneOf1StatusEnum
_$devicePairingQueryDataOneOf1StatusEnumValueOf(String name) {
  switch (name) {
    case 'approved':
      return _$devicePairingQueryDataOneOf1StatusEnum_approved;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DevicePairingQueryDataOneOf1StatusEnum>
_$devicePairingQueryDataOneOf1StatusEnumValues =
    BuiltSet<DevicePairingQueryDataOneOf1StatusEnum>(
      const <DevicePairingQueryDataOneOf1StatusEnum>[
        _$devicePairingQueryDataOneOf1StatusEnum_approved,
      ],
    );

Serializer<DevicePairingQueryDataOneOf1StatusEnum>
_$devicePairingQueryDataOneOf1StatusEnumSerializer =
    _$DevicePairingQueryDataOneOf1StatusEnumSerializer();

class _$DevicePairingQueryDataOneOf1StatusEnumSerializer
    implements PrimitiveSerializer<DevicePairingQueryDataOneOf1StatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'approved': 'approved',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'approved': 'approved',
  };

  @override
  final Iterable<Type> types = const <Type>[
    DevicePairingQueryDataOneOf1StatusEnum,
  ];
  @override
  final String wireName = 'DevicePairingQueryDataOneOf1StatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    DevicePairingQueryDataOneOf1StatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  DevicePairingQueryDataOneOf1StatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => DevicePairingQueryDataOneOf1StatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$DevicePairingQueryDataOneOf1 extends DevicePairingQueryDataOneOf1 {
  @override
  final int protocolVersion;
  @override
  final String pairingId;
  @override
  final String accountContextId;
  @override
  final String challenge;
  @override
  final DateTime expiresAt;
  @override
  final DevicePairingCreateDataTargetDevice targetDevice;
  @override
  final DevicePairingQueryDataOneOf1StatusEnum status;
  @override
  final String issuerDeviceId;
  @override
  final String issuerSigningPublicKey;
  @override
  final String issuerKeyAgreementPublicKey;
  @override
  final int keyEpoch;
  @override
  final String accountKeyEnvelope;
  @override
  final String deviceProof;
  @override
  final String pairingAuthenticator;

  factory _$DevicePairingQueryDataOneOf1([
    void Function(DevicePairingQueryDataOneOf1Builder)? updates,
  ]) => (DevicePairingQueryDataOneOf1Builder()..update(updates))._build();

  _$DevicePairingQueryDataOneOf1._({
    required this.protocolVersion,
    required this.pairingId,
    required this.accountContextId,
    required this.challenge,
    required this.expiresAt,
    required this.targetDevice,
    required this.status,
    required this.issuerDeviceId,
    required this.issuerSigningPublicKey,
    required this.issuerKeyAgreementPublicKey,
    required this.keyEpoch,
    required this.accountKeyEnvelope,
    required this.deviceProof,
    required this.pairingAuthenticator,
  }) : super._();
  @override
  DevicePairingQueryDataOneOf1 rebuild(
    void Function(DevicePairingQueryDataOneOf1Builder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DevicePairingQueryDataOneOf1Builder toBuilder() =>
      DevicePairingQueryDataOneOf1Builder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DevicePairingQueryDataOneOf1 &&
        protocolVersion == other.protocolVersion &&
        pairingId == other.pairingId &&
        accountContextId == other.accountContextId &&
        challenge == other.challenge &&
        expiresAt == other.expiresAt &&
        targetDevice == other.targetDevice &&
        status == other.status &&
        issuerDeviceId == other.issuerDeviceId &&
        issuerSigningPublicKey == other.issuerSigningPublicKey &&
        issuerKeyAgreementPublicKey == other.issuerKeyAgreementPublicKey &&
        keyEpoch == other.keyEpoch &&
        accountKeyEnvelope == other.accountKeyEnvelope &&
        deviceProof == other.deviceProof &&
        pairingAuthenticator == other.pairingAuthenticator;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, protocolVersion.hashCode);
    _$hash = $jc(_$hash, pairingId.hashCode);
    _$hash = $jc(_$hash, accountContextId.hashCode);
    _$hash = $jc(_$hash, challenge.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jc(_$hash, targetDevice.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, issuerDeviceId.hashCode);
    _$hash = $jc(_$hash, issuerSigningPublicKey.hashCode);
    _$hash = $jc(_$hash, issuerKeyAgreementPublicKey.hashCode);
    _$hash = $jc(_$hash, keyEpoch.hashCode);
    _$hash = $jc(_$hash, accountKeyEnvelope.hashCode);
    _$hash = $jc(_$hash, deviceProof.hashCode);
    _$hash = $jc(_$hash, pairingAuthenticator.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DevicePairingQueryDataOneOf1')
          ..add('protocolVersion', protocolVersion)
          ..add('pairingId', pairingId)
          ..add('accountContextId', accountContextId)
          ..add('challenge', challenge)
          ..add('expiresAt', expiresAt)
          ..add('targetDevice', targetDevice)
          ..add('status', status)
          ..add('issuerDeviceId', issuerDeviceId)
          ..add('issuerSigningPublicKey', issuerSigningPublicKey)
          ..add('issuerKeyAgreementPublicKey', issuerKeyAgreementPublicKey)
          ..add('keyEpoch', keyEpoch)
          ..add('accountKeyEnvelope', accountKeyEnvelope)
          ..add('deviceProof', deviceProof)
          ..add('pairingAuthenticator', pairingAuthenticator))
        .toString();
  }
}

class DevicePairingQueryDataOneOf1Builder
    implements
        Builder<
          DevicePairingQueryDataOneOf1,
          DevicePairingQueryDataOneOf1Builder
        > {
  _$DevicePairingQueryDataOneOf1? _$v;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  String? _pairingId;
  String? get pairingId => _$this._pairingId;
  set pairingId(String? pairingId) => _$this._pairingId = pairingId;

  String? _accountContextId;
  String? get accountContextId => _$this._accountContextId;
  set accountContextId(String? accountContextId) =>
      _$this._accountContextId = accountContextId;

  String? _challenge;
  String? get challenge => _$this._challenge;
  set challenge(String? challenge) => _$this._challenge = challenge;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  DevicePairingCreateDataTargetDeviceBuilder? _targetDevice;
  DevicePairingCreateDataTargetDeviceBuilder get targetDevice =>
      _$this._targetDevice ??= DevicePairingCreateDataTargetDeviceBuilder();
  set targetDevice(DevicePairingCreateDataTargetDeviceBuilder? targetDevice) =>
      _$this._targetDevice = targetDevice;

  DevicePairingQueryDataOneOf1StatusEnum? _status;
  DevicePairingQueryDataOneOf1StatusEnum? get status => _$this._status;
  set status(DevicePairingQueryDataOneOf1StatusEnum? status) =>
      _$this._status = status;

  String? _issuerDeviceId;
  String? get issuerDeviceId => _$this._issuerDeviceId;
  set issuerDeviceId(String? issuerDeviceId) =>
      _$this._issuerDeviceId = issuerDeviceId;

  String? _issuerSigningPublicKey;
  String? get issuerSigningPublicKey => _$this._issuerSigningPublicKey;
  set issuerSigningPublicKey(String? issuerSigningPublicKey) =>
      _$this._issuerSigningPublicKey = issuerSigningPublicKey;

  String? _issuerKeyAgreementPublicKey;
  String? get issuerKeyAgreementPublicKey =>
      _$this._issuerKeyAgreementPublicKey;
  set issuerKeyAgreementPublicKey(String? issuerKeyAgreementPublicKey) =>
      _$this._issuerKeyAgreementPublicKey = issuerKeyAgreementPublicKey;

  int? _keyEpoch;
  int? get keyEpoch => _$this._keyEpoch;
  set keyEpoch(int? keyEpoch) => _$this._keyEpoch = keyEpoch;

  String? _accountKeyEnvelope;
  String? get accountKeyEnvelope => _$this._accountKeyEnvelope;
  set accountKeyEnvelope(String? accountKeyEnvelope) =>
      _$this._accountKeyEnvelope = accountKeyEnvelope;

  String? _deviceProof;
  String? get deviceProof => _$this._deviceProof;
  set deviceProof(String? deviceProof) => _$this._deviceProof = deviceProof;

  String? _pairingAuthenticator;
  String? get pairingAuthenticator => _$this._pairingAuthenticator;
  set pairingAuthenticator(String? pairingAuthenticator) =>
      _$this._pairingAuthenticator = pairingAuthenticator;

  DevicePairingQueryDataOneOf1Builder() {
    DevicePairingQueryDataOneOf1._defaults(this);
  }

  DevicePairingQueryDataOneOf1Builder get _$this {
    final $v = _$v;
    if ($v != null) {
      _protocolVersion = $v.protocolVersion;
      _pairingId = $v.pairingId;
      _accountContextId = $v.accountContextId;
      _challenge = $v.challenge;
      _expiresAt = $v.expiresAt;
      _targetDevice = $v.targetDevice.toBuilder();
      _status = $v.status;
      _issuerDeviceId = $v.issuerDeviceId;
      _issuerSigningPublicKey = $v.issuerSigningPublicKey;
      _issuerKeyAgreementPublicKey = $v.issuerKeyAgreementPublicKey;
      _keyEpoch = $v.keyEpoch;
      _accountKeyEnvelope = $v.accountKeyEnvelope;
      _deviceProof = $v.deviceProof;
      _pairingAuthenticator = $v.pairingAuthenticator;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DevicePairingQueryDataOneOf1 other) {
    _$v = other as _$DevicePairingQueryDataOneOf1;
  }

  @override
  void update(void Function(DevicePairingQueryDataOneOf1Builder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DevicePairingQueryDataOneOf1 build() => _build();

  _$DevicePairingQueryDataOneOf1 _build() {
    _$DevicePairingQueryDataOneOf1 _$result;
    try {
      _$result =
          _$v ??
          _$DevicePairingQueryDataOneOf1._(
            protocolVersion: BuiltValueNullFieldError.checkNotNull(
              protocolVersion,
              r'DevicePairingQueryDataOneOf1',
              'protocolVersion',
            ),
            pairingId: BuiltValueNullFieldError.checkNotNull(
              pairingId,
              r'DevicePairingQueryDataOneOf1',
              'pairingId',
            ),
            accountContextId: BuiltValueNullFieldError.checkNotNull(
              accountContextId,
              r'DevicePairingQueryDataOneOf1',
              'accountContextId',
            ),
            challenge: BuiltValueNullFieldError.checkNotNull(
              challenge,
              r'DevicePairingQueryDataOneOf1',
              'challenge',
            ),
            expiresAt: BuiltValueNullFieldError.checkNotNull(
              expiresAt,
              r'DevicePairingQueryDataOneOf1',
              'expiresAt',
            ),
            targetDevice: targetDevice.build(),
            status: BuiltValueNullFieldError.checkNotNull(
              status,
              r'DevicePairingQueryDataOneOf1',
              'status',
            ),
            issuerDeviceId: BuiltValueNullFieldError.checkNotNull(
              issuerDeviceId,
              r'DevicePairingQueryDataOneOf1',
              'issuerDeviceId',
            ),
            issuerSigningPublicKey: BuiltValueNullFieldError.checkNotNull(
              issuerSigningPublicKey,
              r'DevicePairingQueryDataOneOf1',
              'issuerSigningPublicKey',
            ),
            issuerKeyAgreementPublicKey: BuiltValueNullFieldError.checkNotNull(
              issuerKeyAgreementPublicKey,
              r'DevicePairingQueryDataOneOf1',
              'issuerKeyAgreementPublicKey',
            ),
            keyEpoch: BuiltValueNullFieldError.checkNotNull(
              keyEpoch,
              r'DevicePairingQueryDataOneOf1',
              'keyEpoch',
            ),
            accountKeyEnvelope: BuiltValueNullFieldError.checkNotNull(
              accountKeyEnvelope,
              r'DevicePairingQueryDataOneOf1',
              'accountKeyEnvelope',
            ),
            deviceProof: BuiltValueNullFieldError.checkNotNull(
              deviceProof,
              r'DevicePairingQueryDataOneOf1',
              'deviceProof',
            ),
            pairingAuthenticator: BuiltValueNullFieldError.checkNotNull(
              pairingAuthenticator,
              r'DevicePairingQueryDataOneOf1',
              'pairingAuthenticator',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'targetDevice';
        targetDevice.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'DevicePairingQueryDataOneOf1',
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
