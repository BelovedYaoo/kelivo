// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_pairing_create_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DevicePairingCreateData extends DevicePairingCreateData {
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

  factory _$DevicePairingCreateData([
    void Function(DevicePairingCreateDataBuilder)? updates,
  ]) => (DevicePairingCreateDataBuilder()..update(updates))._build();

  _$DevicePairingCreateData._({
    required this.protocolVersion,
    required this.pairingId,
    required this.accountContextId,
    required this.challenge,
    required this.expiresAt,
    required this.targetDevice,
  }) : super._();
  @override
  DevicePairingCreateData rebuild(
    void Function(DevicePairingCreateDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DevicePairingCreateDataBuilder toBuilder() =>
      DevicePairingCreateDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DevicePairingCreateData &&
        protocolVersion == other.protocolVersion &&
        pairingId == other.pairingId &&
        accountContextId == other.accountContextId &&
        challenge == other.challenge &&
        expiresAt == other.expiresAt &&
        targetDevice == other.targetDevice;
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
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DevicePairingCreateData')
          ..add('protocolVersion', protocolVersion)
          ..add('pairingId', pairingId)
          ..add('accountContextId', accountContextId)
          ..add('challenge', challenge)
          ..add('expiresAt', expiresAt)
          ..add('targetDevice', targetDevice))
        .toString();
  }
}

class DevicePairingCreateDataBuilder
    implements
        Builder<DevicePairingCreateData, DevicePairingCreateDataBuilder> {
  _$DevicePairingCreateData? _$v;

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

  DevicePairingCreateDataBuilder() {
    DevicePairingCreateData._defaults(this);
  }

  DevicePairingCreateDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _protocolVersion = $v.protocolVersion;
      _pairingId = $v.pairingId;
      _accountContextId = $v.accountContextId;
      _challenge = $v.challenge;
      _expiresAt = $v.expiresAt;
      _targetDevice = $v.targetDevice.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DevicePairingCreateData other) {
    _$v = other as _$DevicePairingCreateData;
  }

  @override
  void update(void Function(DevicePairingCreateDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DevicePairingCreateData build() => _build();

  _$DevicePairingCreateData _build() {
    _$DevicePairingCreateData _$result;
    try {
      _$result =
          _$v ??
          _$DevicePairingCreateData._(
            protocolVersion: BuiltValueNullFieldError.checkNotNull(
              protocolVersion,
              r'DevicePairingCreateData',
              'protocolVersion',
            ),
            pairingId: BuiltValueNullFieldError.checkNotNull(
              pairingId,
              r'DevicePairingCreateData',
              'pairingId',
            ),
            accountContextId: BuiltValueNullFieldError.checkNotNull(
              accountContextId,
              r'DevicePairingCreateData',
              'accountContextId',
            ),
            challenge: BuiltValueNullFieldError.checkNotNull(
              challenge,
              r'DevicePairingCreateData',
              'challenge',
            ),
            expiresAt: BuiltValueNullFieldError.checkNotNull(
              expiresAt,
              r'DevicePairingCreateData',
              'expiresAt',
            ),
            targetDevice: targetDevice.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'targetDevice';
        targetDevice.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'DevicePairingCreateData',
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
