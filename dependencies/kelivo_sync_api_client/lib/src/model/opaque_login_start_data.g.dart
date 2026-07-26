// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'opaque_login_start_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$OpaqueLoginStartData extends OpaqueLoginStartData {
  @override
  final int protocolVersion;
  @override
  final String attemptId;
  @override
  final String accountBinding;
  @override
  final String deviceChallenge;
  @override
  final String credentialResponse;
  @override
  final DateTime expiresAt;

  factory _$OpaqueLoginStartData([
    void Function(OpaqueLoginStartDataBuilder)? updates,
  ]) => (OpaqueLoginStartDataBuilder()..update(updates))._build();

  _$OpaqueLoginStartData._({
    required this.protocolVersion,
    required this.attemptId,
    required this.accountBinding,
    required this.deviceChallenge,
    required this.credentialResponse,
    required this.expiresAt,
  }) : super._();
  @override
  OpaqueLoginStartData rebuild(
    void Function(OpaqueLoginStartDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  OpaqueLoginStartDataBuilder toBuilder() =>
      OpaqueLoginStartDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpaqueLoginStartData &&
        protocolVersion == other.protocolVersion &&
        attemptId == other.attemptId &&
        accountBinding == other.accountBinding &&
        deviceChallenge == other.deviceChallenge &&
        credentialResponse == other.credentialResponse &&
        expiresAt == other.expiresAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, protocolVersion.hashCode);
    _$hash = $jc(_$hash, attemptId.hashCode);
    _$hash = $jc(_$hash, accountBinding.hashCode);
    _$hash = $jc(_$hash, deviceChallenge.hashCode);
    _$hash = $jc(_$hash, credentialResponse.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'OpaqueLoginStartData')
          ..add('protocolVersion', protocolVersion)
          ..add('attemptId', attemptId)
          ..add('accountBinding', accountBinding)
          ..add('deviceChallenge', deviceChallenge)
          ..add('credentialResponse', credentialResponse)
          ..add('expiresAt', expiresAt))
        .toString();
  }
}

class OpaqueLoginStartDataBuilder
    implements Builder<OpaqueLoginStartData, OpaqueLoginStartDataBuilder> {
  _$OpaqueLoginStartData? _$v;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  String? _attemptId;
  String? get attemptId => _$this._attemptId;
  set attemptId(String? attemptId) => _$this._attemptId = attemptId;

  String? _accountBinding;
  String? get accountBinding => _$this._accountBinding;
  set accountBinding(String? accountBinding) =>
      _$this._accountBinding = accountBinding;

  String? _deviceChallenge;
  String? get deviceChallenge => _$this._deviceChallenge;
  set deviceChallenge(String? deviceChallenge) =>
      _$this._deviceChallenge = deviceChallenge;

  String? _credentialResponse;
  String? get credentialResponse => _$this._credentialResponse;
  set credentialResponse(String? credentialResponse) =>
      _$this._credentialResponse = credentialResponse;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  OpaqueLoginStartDataBuilder() {
    OpaqueLoginStartData._defaults(this);
  }

  OpaqueLoginStartDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _protocolVersion = $v.protocolVersion;
      _attemptId = $v.attemptId;
      _accountBinding = $v.accountBinding;
      _deviceChallenge = $v.deviceChallenge;
      _credentialResponse = $v.credentialResponse;
      _expiresAt = $v.expiresAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(OpaqueLoginStartData other) {
    _$v = other as _$OpaqueLoginStartData;
  }

  @override
  void update(void Function(OpaqueLoginStartDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  OpaqueLoginStartData build() => _build();

  _$OpaqueLoginStartData _build() {
    final _$result =
        _$v ??
        _$OpaqueLoginStartData._(
          protocolVersion: BuiltValueNullFieldError.checkNotNull(
            protocolVersion,
            r'OpaqueLoginStartData',
            'protocolVersion',
          ),
          attemptId: BuiltValueNullFieldError.checkNotNull(
            attemptId,
            r'OpaqueLoginStartData',
            'attemptId',
          ),
          accountBinding: BuiltValueNullFieldError.checkNotNull(
            accountBinding,
            r'OpaqueLoginStartData',
            'accountBinding',
          ),
          deviceChallenge: BuiltValueNullFieldError.checkNotNull(
            deviceChallenge,
            r'OpaqueLoginStartData',
            'deviceChallenge',
          ),
          credentialResponse: BuiltValueNullFieldError.checkNotNull(
            credentialResponse,
            r'OpaqueLoginStartData',
            'credentialResponse',
          ),
          expiresAt: BuiltValueNullFieldError.checkNotNull(
            expiresAt,
            r'OpaqueLoginStartData',
            'expiresAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
