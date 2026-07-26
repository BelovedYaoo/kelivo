// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_trusted_devices_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListTrustedDevicesResponse extends ListTrustedDevicesResponse {
  @override
  final ListTrustedDevicesData data;

  factory _$ListTrustedDevicesResponse([
    void Function(ListTrustedDevicesResponseBuilder)? updates,
  ]) => (ListTrustedDevicesResponseBuilder()..update(updates))._build();

  _$ListTrustedDevicesResponse._({required this.data}) : super._();
  @override
  ListTrustedDevicesResponse rebuild(
    void Function(ListTrustedDevicesResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListTrustedDevicesResponseBuilder toBuilder() =>
      ListTrustedDevicesResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListTrustedDevicesResponse && data == other.data;
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
      r'ListTrustedDevicesResponse',
    )..add('data', data)).toString();
  }
}

class ListTrustedDevicesResponseBuilder
    implements
        Builder<ListTrustedDevicesResponse, ListTrustedDevicesResponseBuilder> {
  _$ListTrustedDevicesResponse? _$v;

  ListTrustedDevicesDataBuilder? _data;
  ListTrustedDevicesDataBuilder get data =>
      _$this._data ??= ListTrustedDevicesDataBuilder();
  set data(ListTrustedDevicesDataBuilder? data) => _$this._data = data;

  ListTrustedDevicesResponseBuilder() {
    ListTrustedDevicesResponse._defaults(this);
  }

  ListTrustedDevicesResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListTrustedDevicesResponse other) {
    _$v = other as _$ListTrustedDevicesResponse;
  }

  @override
  void update(void Function(ListTrustedDevicesResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ListTrustedDevicesResponse build() => _build();

  _$ListTrustedDevicesResponse _build() {
    _$ListTrustedDevicesResponse _$result;
    try {
      _$result = _$v ?? _$ListTrustedDevicesResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ListTrustedDevicesResponse',
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
