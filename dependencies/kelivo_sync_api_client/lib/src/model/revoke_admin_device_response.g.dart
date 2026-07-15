// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revoke_admin_device_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RevokeAdminDeviceResponse extends RevokeAdminDeviceResponse {
  @override
  final RevokeAdminDeviceData data;

  factory _$RevokeAdminDeviceResponse([
    void Function(RevokeAdminDeviceResponseBuilder)? updates,
  ]) => (RevokeAdminDeviceResponseBuilder()..update(updates))._build();

  _$RevokeAdminDeviceResponse._({required this.data}) : super._();
  @override
  RevokeAdminDeviceResponse rebuild(
    void Function(RevokeAdminDeviceResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  RevokeAdminDeviceResponseBuilder toBuilder() =>
      RevokeAdminDeviceResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RevokeAdminDeviceResponse && data == other.data;
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
      r'RevokeAdminDeviceResponse',
    )..add('data', data)).toString();
  }
}

class RevokeAdminDeviceResponseBuilder
    implements
        Builder<RevokeAdminDeviceResponse, RevokeAdminDeviceResponseBuilder> {
  _$RevokeAdminDeviceResponse? _$v;

  RevokeAdminDeviceDataBuilder? _data;
  RevokeAdminDeviceDataBuilder get data =>
      _$this._data ??= RevokeAdminDeviceDataBuilder();
  set data(RevokeAdminDeviceDataBuilder? data) => _$this._data = data;

  RevokeAdminDeviceResponseBuilder() {
    RevokeAdminDeviceResponse._defaults(this);
  }

  RevokeAdminDeviceResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RevokeAdminDeviceResponse other) {
    _$v = other as _$RevokeAdminDeviceResponse;
  }

  @override
  void update(void Function(RevokeAdminDeviceResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RevokeAdminDeviceResponse build() => _build();

  _$RevokeAdminDeviceResponse _build() {
    _$RevokeAdminDeviceResponse _$result;
    try {
      _$result = _$v ?? _$RevokeAdminDeviceResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'RevokeAdminDeviceResponse',
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
