// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revoke_trusted_device_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RevokeTrustedDeviceData extends RevokeTrustedDeviceData {
  @override
  final TrustedDeviceSummary device;

  factory _$RevokeTrustedDeviceData([
    void Function(RevokeTrustedDeviceDataBuilder)? updates,
  ]) => (RevokeTrustedDeviceDataBuilder()..update(updates))._build();

  _$RevokeTrustedDeviceData._({required this.device}) : super._();
  @override
  RevokeTrustedDeviceData rebuild(
    void Function(RevokeTrustedDeviceDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  RevokeTrustedDeviceDataBuilder toBuilder() =>
      RevokeTrustedDeviceDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RevokeTrustedDeviceData && device == other.device;
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
      r'RevokeTrustedDeviceData',
    )..add('device', device)).toString();
  }
}

class RevokeTrustedDeviceDataBuilder
    implements
        Builder<RevokeTrustedDeviceData, RevokeTrustedDeviceDataBuilder> {
  _$RevokeTrustedDeviceData? _$v;

  TrustedDeviceSummaryBuilder? _device;
  TrustedDeviceSummaryBuilder get device =>
      _$this._device ??= TrustedDeviceSummaryBuilder();
  set device(TrustedDeviceSummaryBuilder? device) => _$this._device = device;

  RevokeTrustedDeviceDataBuilder() {
    RevokeTrustedDeviceData._defaults(this);
  }

  RevokeTrustedDeviceDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _device = $v.device.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RevokeTrustedDeviceData other) {
    _$v = other as _$RevokeTrustedDeviceData;
  }

  @override
  void update(void Function(RevokeTrustedDeviceDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RevokeTrustedDeviceData build() => _build();

  _$RevokeTrustedDeviceData _build() {
    _$RevokeTrustedDeviceData _$result;
    try {
      _$result = _$v ?? _$RevokeTrustedDeviceData._(device: device.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'device';
        device.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'RevokeTrustedDeviceData',
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
