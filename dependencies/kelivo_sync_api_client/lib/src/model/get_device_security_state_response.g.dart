// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_device_security_state_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$GetDeviceSecurityStateResponse extends GetDeviceSecurityStateResponse {
  @override
  final DeviceSecurityStateData data;

  factory _$GetDeviceSecurityStateResponse([
    void Function(GetDeviceSecurityStateResponseBuilder)? updates,
  ]) => (GetDeviceSecurityStateResponseBuilder()..update(updates))._build();

  _$GetDeviceSecurityStateResponse._({required this.data}) : super._();
  @override
  GetDeviceSecurityStateResponse rebuild(
    void Function(GetDeviceSecurityStateResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  GetDeviceSecurityStateResponseBuilder toBuilder() =>
      GetDeviceSecurityStateResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GetDeviceSecurityStateResponse && data == other.data;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, data.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'GetDeviceSecurityStateResponse',
    )..add('data', data)).toString();
  }
}

class GetDeviceSecurityStateResponseBuilder
    implements
        Builder<
          GetDeviceSecurityStateResponse,
          GetDeviceSecurityStateResponseBuilder
        > {
  _$GetDeviceSecurityStateResponse? _$v;

  DeviceSecurityStateDataBuilder? _data;
  DeviceSecurityStateDataBuilder get data =>
      _$this._data ??= DeviceSecurityStateDataBuilder();
  set data(DeviceSecurityStateDataBuilder? data) => _$this._data = data;

  GetDeviceSecurityStateResponseBuilder() {
    GetDeviceSecurityStateResponse._defaults(this);
  }

  GetDeviceSecurityStateResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GetDeviceSecurityStateResponse other) {
    _$v = other as _$GetDeviceSecurityStateResponse;
  }

  @override
  void update(void Function(GetDeviceSecurityStateResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  GetDeviceSecurityStateResponse build() => _build();

  _$GetDeviceSecurityStateResponse _build() {
    _$GetDeviceSecurityStateResponse _$result;
    try {
      _$result = _$v ?? _$GetDeviceSecurityStateResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'GetDeviceSecurityStateResponse',
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
