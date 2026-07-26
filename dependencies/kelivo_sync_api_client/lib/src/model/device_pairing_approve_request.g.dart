// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_pairing_approve_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DevicePairingApproveRequest extends DevicePairingApproveRequest {
  @override
  final int protocolVersion;
  @override
  final String pairingId;
  @override
  final int keyEpoch;
  @override
  final String accountKeyEnvelope;
  @override
  final String deviceProof;
  @override
  final String pairingAuthenticator;

  factory _$DevicePairingApproveRequest([
    void Function(DevicePairingApproveRequestBuilder)? updates,
  ]) => (DevicePairingApproveRequestBuilder()..update(updates))._build();

  _$DevicePairingApproveRequest._({
    required this.protocolVersion,
    required this.pairingId,
    required this.keyEpoch,
    required this.accountKeyEnvelope,
    required this.deviceProof,
    required this.pairingAuthenticator,
  }) : super._();
  @override
  DevicePairingApproveRequest rebuild(
    void Function(DevicePairingApproveRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DevicePairingApproveRequestBuilder toBuilder() =>
      DevicePairingApproveRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DevicePairingApproveRequest &&
        protocolVersion == other.protocolVersion &&
        pairingId == other.pairingId &&
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
    _$hash = $jc(_$hash, keyEpoch.hashCode);
    _$hash = $jc(_$hash, accountKeyEnvelope.hashCode);
    _$hash = $jc(_$hash, deviceProof.hashCode);
    _$hash = $jc(_$hash, pairingAuthenticator.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DevicePairingApproveRequest')
          ..add('protocolVersion', protocolVersion)
          ..add('pairingId', pairingId)
          ..add('keyEpoch', keyEpoch)
          ..add('accountKeyEnvelope', accountKeyEnvelope)
          ..add('deviceProof', deviceProof)
          ..add('pairingAuthenticator', pairingAuthenticator))
        .toString();
  }
}

class DevicePairingApproveRequestBuilder
    implements
        Builder<
          DevicePairingApproveRequest,
          DevicePairingApproveRequestBuilder
        > {
  _$DevicePairingApproveRequest? _$v;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  String? _pairingId;
  String? get pairingId => _$this._pairingId;
  set pairingId(String? pairingId) => _$this._pairingId = pairingId;

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

  DevicePairingApproveRequestBuilder() {
    DevicePairingApproveRequest._defaults(this);
  }

  DevicePairingApproveRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _protocolVersion = $v.protocolVersion;
      _pairingId = $v.pairingId;
      _keyEpoch = $v.keyEpoch;
      _accountKeyEnvelope = $v.accountKeyEnvelope;
      _deviceProof = $v.deviceProof;
      _pairingAuthenticator = $v.pairingAuthenticator;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DevicePairingApproveRequest other) {
    _$v = other as _$DevicePairingApproveRequest;
  }

  @override
  void update(void Function(DevicePairingApproveRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DevicePairingApproveRequest build() => _build();

  _$DevicePairingApproveRequest _build() {
    final _$result =
        _$v ??
        _$DevicePairingApproveRequest._(
          protocolVersion: BuiltValueNullFieldError.checkNotNull(
            protocolVersion,
            r'DevicePairingApproveRequest',
            'protocolVersion',
          ),
          pairingId: BuiltValueNullFieldError.checkNotNull(
            pairingId,
            r'DevicePairingApproveRequest',
            'pairingId',
          ),
          keyEpoch: BuiltValueNullFieldError.checkNotNull(
            keyEpoch,
            r'DevicePairingApproveRequest',
            'keyEpoch',
          ),
          accountKeyEnvelope: BuiltValueNullFieldError.checkNotNull(
            accountKeyEnvelope,
            r'DevicePairingApproveRequest',
            'accountKeyEnvelope',
          ),
          deviceProof: BuiltValueNullFieldError.checkNotNull(
            deviceProof,
            r'DevicePairingApproveRequest',
            'deviceProof',
          ),
          pairingAuthenticator: BuiltValueNullFieldError.checkNotNull(
            pairingAuthenticator,
            r'DevicePairingApproveRequest',
            'pairingAuthenticator',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
