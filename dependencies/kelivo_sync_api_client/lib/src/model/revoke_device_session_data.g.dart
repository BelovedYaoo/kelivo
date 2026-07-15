// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revoke_device_session_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RevokeDeviceSessionData extends RevokeDeviceSessionData {
  @override
  final DeviceSessionSummary device;

  factory _$RevokeDeviceSessionData([
    void Function(RevokeDeviceSessionDataBuilder)? updates,
  ]) => (RevokeDeviceSessionDataBuilder()..update(updates))._build();

  _$RevokeDeviceSessionData._({required this.device}) : super._();
  @override
  RevokeDeviceSessionData rebuild(
    void Function(RevokeDeviceSessionDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  RevokeDeviceSessionDataBuilder toBuilder() =>
      RevokeDeviceSessionDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RevokeDeviceSessionData && device == other.device;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, device.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'RevokeDeviceSessionData',
    )..add('device', device)).toString();
  }
}

class RevokeDeviceSessionDataBuilder
    implements
        Builder<RevokeDeviceSessionData, RevokeDeviceSessionDataBuilder> {
  _$RevokeDeviceSessionData? _$v;

  DeviceSessionSummaryBuilder? _device;
  DeviceSessionSummaryBuilder get device =>
      _$this._device ??= DeviceSessionSummaryBuilder();
  set device(DeviceSessionSummaryBuilder? device) => _$this._device = device;

  RevokeDeviceSessionDataBuilder() {
    RevokeDeviceSessionData._defaults(this);
  }

  RevokeDeviceSessionDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _device = $v.device.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RevokeDeviceSessionData other) {
    _$v = other as _$RevokeDeviceSessionData;
  }

  @override
  void update(void Function(RevokeDeviceSessionDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RevokeDeviceSessionData build() => _build();

  _$RevokeDeviceSessionData _build() {
    _$RevokeDeviceSessionData _$result;
    try {
      _$result = _$v ?? _$RevokeDeviceSessionData._(device: device.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'device';
        device.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'RevokeDeviceSessionData',
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
