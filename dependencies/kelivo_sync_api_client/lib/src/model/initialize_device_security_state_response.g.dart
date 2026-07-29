// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'initialize_device_security_state_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$InitializeDeviceSecurityStateResponse
    extends InitializeDeviceSecurityStateResponse {
  @override
  final DeviceSecurityStateData data;

  factory _$InitializeDeviceSecurityStateResponse([
    void Function(InitializeDeviceSecurityStateResponseBuilder)? updates,
  ]) => (InitializeDeviceSecurityStateResponseBuilder()..update(updates))
      ._build();

  _$InitializeDeviceSecurityStateResponse._({required this.data}) : super._();
  @override
  InitializeDeviceSecurityStateResponse rebuild(
    void Function(InitializeDeviceSecurityStateResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  InitializeDeviceSecurityStateResponseBuilder toBuilder() =>
      InitializeDeviceSecurityStateResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is InitializeDeviceSecurityStateResponse && data == other.data;
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
      r'InitializeDeviceSecurityStateResponse',
    )..add('data', data)).toString();
  }
}

class InitializeDeviceSecurityStateResponseBuilder
    implements
        Builder<
          InitializeDeviceSecurityStateResponse,
          InitializeDeviceSecurityStateResponseBuilder
        > {
  _$InitializeDeviceSecurityStateResponse? _$v;

  DeviceSecurityStateDataBuilder? _data;
  DeviceSecurityStateDataBuilder get data =>
      _$this._data ??= DeviceSecurityStateDataBuilder();
  set data(DeviceSecurityStateDataBuilder? data) => _$this._data = data;

  InitializeDeviceSecurityStateResponseBuilder() {
    InitializeDeviceSecurityStateResponse._defaults(this);
  }

  InitializeDeviceSecurityStateResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(InitializeDeviceSecurityStateResponse other) {
    _$v = other as _$InitializeDeviceSecurityStateResponse;
  }

  @override
  void update(
    void Function(InitializeDeviceSecurityStateResponseBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  InitializeDeviceSecurityStateResponse build() => _build();

  _$InitializeDeviceSecurityStateResponse _build() {
    _$InitializeDeviceSecurityStateResponse _$result;
    try {
      _$result =
          _$v ?? _$InitializeDeviceSecurityStateResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'InitializeDeviceSecurityStateResponse',
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
