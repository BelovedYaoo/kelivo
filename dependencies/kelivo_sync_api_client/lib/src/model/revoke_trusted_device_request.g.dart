// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revoke_trusted_device_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RevokeTrustedDeviceRequest extends RevokeTrustedDeviceRequest {
  @override
  final String deviceId;

  factory _$RevokeTrustedDeviceRequest([
    void Function(RevokeTrustedDeviceRequestBuilder)? updates,
  ]) => (RevokeTrustedDeviceRequestBuilder()..update(updates))._build();

  _$RevokeTrustedDeviceRequest._({required this.deviceId}) : super._();
  @override
  RevokeTrustedDeviceRequest rebuild(
    void Function(RevokeTrustedDeviceRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  RevokeTrustedDeviceRequestBuilder toBuilder() =>
      RevokeTrustedDeviceRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RevokeTrustedDeviceRequest && deviceId == other.deviceId;
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
      r'RevokeTrustedDeviceRequest',
    )..add('deviceId', deviceId)).toString();
  }
}

class RevokeTrustedDeviceRequestBuilder
    implements
        Builder<RevokeTrustedDeviceRequest, RevokeTrustedDeviceRequestBuilder> {
  _$RevokeTrustedDeviceRequest? _$v;

  String? _deviceId;
  String? get deviceId => _$this._deviceId;
  set deviceId(String? deviceId) => _$this._deviceId = deviceId;

  RevokeTrustedDeviceRequestBuilder() {
    RevokeTrustedDeviceRequest._defaults(this);
  }

  RevokeTrustedDeviceRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _deviceId = $v.deviceId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RevokeTrustedDeviceRequest other) {
    _$v = other as _$RevokeTrustedDeviceRequest;
  }

  @override
  void update(void Function(RevokeTrustedDeviceRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RevokeTrustedDeviceRequest build() => _build();

  _$RevokeTrustedDeviceRequest _build() {
    final _$result =
        _$v ??
        _$RevokeTrustedDeviceRequest._(
          deviceId: BuiltValueNullFieldError.checkNotNull(
            deviceId,
            r'RevokeTrustedDeviceRequest',
            'deviceId',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
