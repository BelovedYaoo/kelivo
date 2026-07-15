// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_devices_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListAdminDevicesResponse extends ListAdminDevicesResponse {
  @override
  final ListAdminDevicesData data;

  factory _$ListAdminDevicesResponse([
    void Function(ListAdminDevicesResponseBuilder)? updates,
  ]) => (ListAdminDevicesResponseBuilder()..update(updates))._build();

  _$ListAdminDevicesResponse._({required this.data}) : super._();
  @override
  ListAdminDevicesResponse rebuild(
    void Function(ListAdminDevicesResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListAdminDevicesResponseBuilder toBuilder() =>
      ListAdminDevicesResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListAdminDevicesResponse && data == other.data;
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
      r'ListAdminDevicesResponse',
    )..add('data', data)).toString();
  }
}

class ListAdminDevicesResponseBuilder
    implements
        Builder<ListAdminDevicesResponse, ListAdminDevicesResponseBuilder> {
  _$ListAdminDevicesResponse? _$v;

  ListAdminDevicesDataBuilder? _data;
  ListAdminDevicesDataBuilder get data =>
      _$this._data ??= ListAdminDevicesDataBuilder();
  set data(ListAdminDevicesDataBuilder? data) => _$this._data = data;

  ListAdminDevicesResponseBuilder() {
    ListAdminDevicesResponse._defaults(this);
  }

  ListAdminDevicesResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListAdminDevicesResponse other) {
    _$v = other as _$ListAdminDevicesResponse;
  }

  @override
  void update(void Function(ListAdminDevicesResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ListAdminDevicesResponse build() => _build();

  _$ListAdminDevicesResponse _build() {
    _$ListAdminDevicesResponse _$result;
    try {
      _$result = _$v ?? _$ListAdminDevicesResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ListAdminDevicesResponse',
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
