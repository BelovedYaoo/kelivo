// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revoke_admin_device_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RevokeAdminDeviceData extends RevokeAdminDeviceData {
  @override
  final AdminDeviceSummary device;

  factory _$RevokeAdminDeviceData([
    void Function(RevokeAdminDeviceDataBuilder)? updates,
  ]) => (RevokeAdminDeviceDataBuilder()..update(updates))._build();

  _$RevokeAdminDeviceData._({required this.device}) : super._();
  @override
  RevokeAdminDeviceData rebuild(
    void Function(RevokeAdminDeviceDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  RevokeAdminDeviceDataBuilder toBuilder() =>
      RevokeAdminDeviceDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RevokeAdminDeviceData && device == other.device;
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
      r'RevokeAdminDeviceData',
    )..add('device', device)).toString();
  }
}

class RevokeAdminDeviceDataBuilder
    implements Builder<RevokeAdminDeviceData, RevokeAdminDeviceDataBuilder> {
  _$RevokeAdminDeviceData? _$v;

  AdminDeviceSummaryBuilder? _device;
  AdminDeviceSummaryBuilder get device =>
      _$this._device ??= AdminDeviceSummaryBuilder();
  set device(AdminDeviceSummaryBuilder? device) => _$this._device = device;

  RevokeAdminDeviceDataBuilder() {
    RevokeAdminDeviceData._defaults(this);
  }

  RevokeAdminDeviceDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _device = $v.device.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RevokeAdminDeviceData other) {
    _$v = other as _$RevokeAdminDeviceData;
  }

  @override
  void update(void Function(RevokeAdminDeviceDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RevokeAdminDeviceData build() => _build();

  _$RevokeAdminDeviceData _build() {
    _$RevokeAdminDeviceData _$result;
    try {
      _$result = _$v ?? _$RevokeAdminDeviceData._(device: device.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'device';
        device.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'RevokeAdminDeviceData',
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
