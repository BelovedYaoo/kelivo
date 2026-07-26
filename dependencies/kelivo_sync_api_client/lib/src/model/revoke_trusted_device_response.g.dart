// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revoke_trusted_device_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RevokeTrustedDeviceResponse extends RevokeTrustedDeviceResponse {
  @override
  final RevokeTrustedDeviceData data;

  factory _$RevokeTrustedDeviceResponse([
    void Function(RevokeTrustedDeviceResponseBuilder)? updates,
  ]) => (RevokeTrustedDeviceResponseBuilder()..update(updates))._build();

  _$RevokeTrustedDeviceResponse._({required this.data}) : super._();
  @override
  RevokeTrustedDeviceResponse rebuild(
    void Function(RevokeTrustedDeviceResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  RevokeTrustedDeviceResponseBuilder toBuilder() =>
      RevokeTrustedDeviceResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RevokeTrustedDeviceResponse && data == other.data;
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
      r'RevokeTrustedDeviceResponse',
    )..add('data', data)).toString();
  }
}

class RevokeTrustedDeviceResponseBuilder
    implements
        Builder<
          RevokeTrustedDeviceResponse,
          RevokeTrustedDeviceResponseBuilder
        > {
  _$RevokeTrustedDeviceResponse? _$v;

  RevokeTrustedDeviceDataBuilder? _data;
  RevokeTrustedDeviceDataBuilder get data =>
      _$this._data ??= RevokeTrustedDeviceDataBuilder();
  set data(RevokeTrustedDeviceDataBuilder? data) => _$this._data = data;

  RevokeTrustedDeviceResponseBuilder() {
    RevokeTrustedDeviceResponse._defaults(this);
  }

  RevokeTrustedDeviceResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RevokeTrustedDeviceResponse other) {
    _$v = other as _$RevokeTrustedDeviceResponse;
  }

  @override
  void update(void Function(RevokeTrustedDeviceResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RevokeTrustedDeviceResponse build() => _build();

  _$RevokeTrustedDeviceResponse _build() {
    _$RevokeTrustedDeviceResponse _$result;
    try {
      _$result = _$v ?? _$RevokeTrustedDeviceResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'RevokeTrustedDeviceResponse',
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
