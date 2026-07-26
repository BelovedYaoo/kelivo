// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'opaque_login_finish_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$OpaqueLoginFinishRequest extends OpaqueLoginFinishRequest {
  @override
  final int protocolVersion;
  @override
  final String attemptId;
  @override
  final String credentialFinalization;
  @override
  final String deviceProof;

  factory _$OpaqueLoginFinishRequest([
    void Function(OpaqueLoginFinishRequestBuilder)? updates,
  ]) => (OpaqueLoginFinishRequestBuilder()..update(updates))._build();

  _$OpaqueLoginFinishRequest._({
    required this.protocolVersion,
    required this.attemptId,
    required this.credentialFinalization,
    required this.deviceProof,
  }) : super._();
  @override
  OpaqueLoginFinishRequest rebuild(
    void Function(OpaqueLoginFinishRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  OpaqueLoginFinishRequestBuilder toBuilder() =>
      OpaqueLoginFinishRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpaqueLoginFinishRequest &&
        protocolVersion == other.protocolVersion &&
        attemptId == other.attemptId &&
        credentialFinalization == other.credentialFinalization &&
        deviceProof == other.deviceProof;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, protocolVersion.hashCode);
    _$hash = $jc(_$hash, attemptId.hashCode);
    _$hash = $jc(_$hash, credentialFinalization.hashCode);
    _$hash = $jc(_$hash, deviceProof.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'OpaqueLoginFinishRequest')
          ..add('protocolVersion', protocolVersion)
          ..add('attemptId', attemptId)
          ..add('credentialFinalization', credentialFinalization)
          ..add('deviceProof', deviceProof))
        .toString();
  }
}

class OpaqueLoginFinishRequestBuilder
    implements
        Builder<OpaqueLoginFinishRequest, OpaqueLoginFinishRequestBuilder> {
  _$OpaqueLoginFinishRequest? _$v;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  String? _attemptId;
  String? get attemptId => _$this._attemptId;
  set attemptId(String? attemptId) => _$this._attemptId = attemptId;

  String? _credentialFinalization;
  String? get credentialFinalization => _$this._credentialFinalization;
  set credentialFinalization(String? credentialFinalization) =>
      _$this._credentialFinalization = credentialFinalization;

  String? _deviceProof;
  String? get deviceProof => _$this._deviceProof;
  set deviceProof(String? deviceProof) => _$this._deviceProof = deviceProof;

  OpaqueLoginFinishRequestBuilder() {
    OpaqueLoginFinishRequest._defaults(this);
  }

  OpaqueLoginFinishRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _protocolVersion = $v.protocolVersion;
      _attemptId = $v.attemptId;
      _credentialFinalization = $v.credentialFinalization;
      _deviceProof = $v.deviceProof;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(OpaqueLoginFinishRequest other) {
    _$v = other as _$OpaqueLoginFinishRequest;
  }

  @override
  void update(void Function(OpaqueLoginFinishRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  OpaqueLoginFinishRequest build() => _build();

  _$OpaqueLoginFinishRequest _build() {
    final _$result =
        _$v ??
        _$OpaqueLoginFinishRequest._(
          protocolVersion: BuiltValueNullFieldError.checkNotNull(
            protocolVersion,
            r'OpaqueLoginFinishRequest',
            'protocolVersion',
          ),
          attemptId: BuiltValueNullFieldError.checkNotNull(
            attemptId,
            r'OpaqueLoginFinishRequest',
            'attemptId',
          ),
          credentialFinalization: BuiltValueNullFieldError.checkNotNull(
            credentialFinalization,
            r'OpaqueLoginFinishRequest',
            'credentialFinalization',
          ),
          deviceProof: BuiltValueNullFieldError.checkNotNull(
            deviceProof,
            r'OpaqueLoginFinishRequest',
            'deviceProof',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
