// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'opaque_registration_start_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$OpaqueRegistrationStartData extends OpaqueRegistrationStartData {
  @override
  final int protocolVersion;
  @override
  final String attemptId;
  @override
  final String userId;
  @override
  final String accountBinding;
  @override
  final String deviceChallenge;
  @override
  final String registrationResponse;
  @override
  final DateTime expiresAt;

  factory _$OpaqueRegistrationStartData([
    void Function(OpaqueRegistrationStartDataBuilder)? updates,
  ]) => (OpaqueRegistrationStartDataBuilder()..update(updates))._build();

  _$OpaqueRegistrationStartData._({
    required this.protocolVersion,
    required this.attemptId,
    required this.userId,
    required this.accountBinding,
    required this.deviceChallenge,
    required this.registrationResponse,
    required this.expiresAt,
  }) : super._();
  @override
  OpaqueRegistrationStartData rebuild(
    void Function(OpaqueRegistrationStartDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  OpaqueRegistrationStartDataBuilder toBuilder() =>
      OpaqueRegistrationStartDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpaqueRegistrationStartData &&
        protocolVersion == other.protocolVersion &&
        attemptId == other.attemptId &&
        userId == other.userId &&
        accountBinding == other.accountBinding &&
        deviceChallenge == other.deviceChallenge &&
        registrationResponse == other.registrationResponse &&
        expiresAt == other.expiresAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, protocolVersion.hashCode);
    _$hash = $jc(_$hash, attemptId.hashCode);
    _$hash = $jc(_$hash, userId.hashCode);
    _$hash = $jc(_$hash, accountBinding.hashCode);
    _$hash = $jc(_$hash, deviceChallenge.hashCode);
    _$hash = $jc(_$hash, registrationResponse.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'OpaqueRegistrationStartData')
          ..add('protocolVersion', protocolVersion)
          ..add('attemptId', attemptId)
          ..add('userId', userId)
          ..add('accountBinding', accountBinding)
          ..add('deviceChallenge', deviceChallenge)
          ..add('registrationResponse', registrationResponse)
          ..add('expiresAt', expiresAt))
        .toString();
  }
}

class OpaqueRegistrationStartDataBuilder
    implements
        Builder<
          OpaqueRegistrationStartData,
          OpaqueRegistrationStartDataBuilder
        > {
  _$OpaqueRegistrationStartData? _$v;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  String? _attemptId;
  String? get attemptId => _$this._attemptId;
  set attemptId(String? attemptId) => _$this._attemptId = attemptId;

  String? _userId;
  String? get userId => _$this._userId;
  set userId(String? userId) => _$this._userId = userId;

  String? _accountBinding;
  String? get accountBinding => _$this._accountBinding;
  set accountBinding(String? accountBinding) =>
      _$this._accountBinding = accountBinding;

  String? _deviceChallenge;
  String? get deviceChallenge => _$this._deviceChallenge;
  set deviceChallenge(String? deviceChallenge) =>
      _$this._deviceChallenge = deviceChallenge;

  String? _registrationResponse;
  String? get registrationResponse => _$this._registrationResponse;
  set registrationResponse(String? registrationResponse) =>
      _$this._registrationResponse = registrationResponse;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  OpaqueRegistrationStartDataBuilder() {
    OpaqueRegistrationStartData._defaults(this);
  }

  OpaqueRegistrationStartDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _protocolVersion = $v.protocolVersion;
      _attemptId = $v.attemptId;
      _userId = $v.userId;
      _accountBinding = $v.accountBinding;
      _deviceChallenge = $v.deviceChallenge;
      _registrationResponse = $v.registrationResponse;
      _expiresAt = $v.expiresAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(OpaqueRegistrationStartData other) {
    _$v = other as _$OpaqueRegistrationStartData;
  }

  @override
  void update(void Function(OpaqueRegistrationStartDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  OpaqueRegistrationStartData build() => _build();

  _$OpaqueRegistrationStartData _build() {
    final _$result =
        _$v ??
        _$OpaqueRegistrationStartData._(
          protocolVersion: BuiltValueNullFieldError.checkNotNull(
            protocolVersion,
            r'OpaqueRegistrationStartData',
            'protocolVersion',
          ),
          attemptId: BuiltValueNullFieldError.checkNotNull(
            attemptId,
            r'OpaqueRegistrationStartData',
            'attemptId',
          ),
          userId: BuiltValueNullFieldError.checkNotNull(
            userId,
            r'OpaqueRegistrationStartData',
            'userId',
          ),
          accountBinding: BuiltValueNullFieldError.checkNotNull(
            accountBinding,
            r'OpaqueRegistrationStartData',
            'accountBinding',
          ),
          deviceChallenge: BuiltValueNullFieldError.checkNotNull(
            deviceChallenge,
            r'OpaqueRegistrationStartData',
            'deviceChallenge',
          ),
          registrationResponse: BuiltValueNullFieldError.checkNotNull(
            registrationResponse,
            r'OpaqueRegistrationStartData',
            'registrationResponse',
          ),
          expiresAt: BuiltValueNullFieldError.checkNotNull(
            expiresAt,
            r'OpaqueRegistrationStartData',
            'expiresAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
