// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'opaque_registration_finish_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$OpaqueRegistrationFinishRequest
    extends OpaqueRegistrationFinishRequest {
  @override
  final int protocolVersion;
  @override
  final String attemptId;
  @override
  final String registrationUpload;
  @override
  final String accountKeyEnvelope;
  @override
  final GenesisSecurityState securityState;
  @override
  final String deviceProof;

  factory _$OpaqueRegistrationFinishRequest([
    void Function(OpaqueRegistrationFinishRequestBuilder)? updates,
  ]) => (OpaqueRegistrationFinishRequestBuilder()..update(updates))._build();

  _$OpaqueRegistrationFinishRequest._({
    required this.protocolVersion,
    required this.attemptId,
    required this.registrationUpload,
    required this.accountKeyEnvelope,
    required this.securityState,
    required this.deviceProof,
  }) : super._();
  @override
  OpaqueRegistrationFinishRequest rebuild(
    void Function(OpaqueRegistrationFinishRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  OpaqueRegistrationFinishRequestBuilder toBuilder() =>
      OpaqueRegistrationFinishRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpaqueRegistrationFinishRequest &&
        protocolVersion == other.protocolVersion &&
        attemptId == other.attemptId &&
        registrationUpload == other.registrationUpload &&
        accountKeyEnvelope == other.accountKeyEnvelope &&
        securityState == other.securityState &&
        deviceProof == other.deviceProof;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, protocolVersion.hashCode);
    _$hash = $jc(_$hash, attemptId.hashCode);
    _$hash = $jc(_$hash, registrationUpload.hashCode);
    _$hash = $jc(_$hash, accountKeyEnvelope.hashCode);
    _$hash = $jc(_$hash, securityState.hashCode);
    _$hash = $jc(_$hash, deviceProof.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'OpaqueRegistrationFinishRequest')
          ..add('protocolVersion', protocolVersion)
          ..add('attemptId', attemptId)
          ..add('registrationUpload', registrationUpload)
          ..add('accountKeyEnvelope', accountKeyEnvelope)
          ..add('securityState', securityState)
          ..add('deviceProof', deviceProof))
        .toString();
  }
}

class OpaqueRegistrationFinishRequestBuilder
    implements
        Builder<
          OpaqueRegistrationFinishRequest,
          OpaqueRegistrationFinishRequestBuilder
        > {
  _$OpaqueRegistrationFinishRequest? _$v;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  String? _attemptId;
  String? get attemptId => _$this._attemptId;
  set attemptId(String? attemptId) => _$this._attemptId = attemptId;

  String? _registrationUpload;
  String? get registrationUpload => _$this._registrationUpload;
  set registrationUpload(String? registrationUpload) =>
      _$this._registrationUpload = registrationUpload;

  String? _accountKeyEnvelope;
  String? get accountKeyEnvelope => _$this._accountKeyEnvelope;
  set accountKeyEnvelope(String? accountKeyEnvelope) =>
      _$this._accountKeyEnvelope = accountKeyEnvelope;

  GenesisSecurityStateBuilder? _securityState;
  GenesisSecurityStateBuilder get securityState =>
      _$this._securityState ??= GenesisSecurityStateBuilder();
  set securityState(GenesisSecurityStateBuilder? securityState) =>
      _$this._securityState = securityState;

  String? _deviceProof;
  String? get deviceProof => _$this._deviceProof;
  set deviceProof(String? deviceProof) => _$this._deviceProof = deviceProof;

  OpaqueRegistrationFinishRequestBuilder() {
    OpaqueRegistrationFinishRequest._defaults(this);
  }

  OpaqueRegistrationFinishRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _protocolVersion = $v.protocolVersion;
      _attemptId = $v.attemptId;
      _registrationUpload = $v.registrationUpload;
      _accountKeyEnvelope = $v.accountKeyEnvelope;
      _securityState = $v.securityState.toBuilder();
      _deviceProof = $v.deviceProof;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(OpaqueRegistrationFinishRequest other) {
    _$v = other as _$OpaqueRegistrationFinishRequest;
  }

  @override
  void update(void Function(OpaqueRegistrationFinishRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  OpaqueRegistrationFinishRequest build() => _build();

  _$OpaqueRegistrationFinishRequest _build() {
    _$OpaqueRegistrationFinishRequest _$result;
    try {
      _$result =
          _$v ??
          _$OpaqueRegistrationFinishRequest._(
            protocolVersion: BuiltValueNullFieldError.checkNotNull(
              protocolVersion,
              r'OpaqueRegistrationFinishRequest',
              'protocolVersion',
            ),
            attemptId: BuiltValueNullFieldError.checkNotNull(
              attemptId,
              r'OpaqueRegistrationFinishRequest',
              'attemptId',
            ),
            registrationUpload: BuiltValueNullFieldError.checkNotNull(
              registrationUpload,
              r'OpaqueRegistrationFinishRequest',
              'registrationUpload',
            ),
            accountKeyEnvelope: BuiltValueNullFieldError.checkNotNull(
              accountKeyEnvelope,
              r'OpaqueRegistrationFinishRequest',
              'accountKeyEnvelope',
            ),
            securityState: securityState.build(),
            deviceProof: BuiltValueNullFieldError.checkNotNull(
              deviceProof,
              r'OpaqueRegistrationFinishRequest',
              'deviceProof',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'securityState';
        securityState.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'OpaqueRegistrationFinishRequest',
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
