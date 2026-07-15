// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revoke_admin_device_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RevokeAdminDeviceRequest extends RevokeAdminDeviceRequest {
  @override
  final String deviceId;

  factory _$RevokeAdminDeviceRequest([
    void Function(RevokeAdminDeviceRequestBuilder)? updates,
  ]) => (RevokeAdminDeviceRequestBuilder()..update(updates))._build();

  _$RevokeAdminDeviceRequest._({required this.deviceId}) : super._();
  @override
  RevokeAdminDeviceRequest rebuild(
    void Function(RevokeAdminDeviceRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  RevokeAdminDeviceRequestBuilder toBuilder() =>
      RevokeAdminDeviceRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RevokeAdminDeviceRequest && deviceId == other.deviceId;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, deviceId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'RevokeAdminDeviceRequest',
    )..add('deviceId', deviceId)).toString();
  }
}

class RevokeAdminDeviceRequestBuilder
    implements
        Builder<RevokeAdminDeviceRequest, RevokeAdminDeviceRequestBuilder> {
  _$RevokeAdminDeviceRequest? _$v;

  String? _deviceId;
  String? get deviceId => _$this._deviceId;
  set deviceId(String? deviceId) => _$this._deviceId = deviceId;

  RevokeAdminDeviceRequestBuilder() {
    RevokeAdminDeviceRequest._defaults(this);
  }

  RevokeAdminDeviceRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _deviceId = $v.deviceId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RevokeAdminDeviceRequest other) {
    _$v = other as _$RevokeAdminDeviceRequest;
  }

  @override
  void update(void Function(RevokeAdminDeviceRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RevokeAdminDeviceRequest build() => _build();

  _$RevokeAdminDeviceRequest _build() {
    final _$result =
        _$v ??
        _$RevokeAdminDeviceRequest._(
          deviceId: BuiltValueNullFieldError.checkNotNull(
            deviceId,
            r'RevokeAdminDeviceRequest',
            'deviceId',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
