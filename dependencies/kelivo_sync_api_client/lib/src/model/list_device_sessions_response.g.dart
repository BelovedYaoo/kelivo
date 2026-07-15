// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_device_sessions_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListDeviceSessionsResponse extends ListDeviceSessionsResponse {
  @override
  final ListDeviceSessionsData data;

  factory _$ListDeviceSessionsResponse([
    void Function(ListDeviceSessionsResponseBuilder)? updates,
  ]) => (ListDeviceSessionsResponseBuilder()..update(updates))._build();

  _$ListDeviceSessionsResponse._({required this.data}) : super._();
  @override
  ListDeviceSessionsResponse rebuild(
    void Function(ListDeviceSessionsResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListDeviceSessionsResponseBuilder toBuilder() =>
      ListDeviceSessionsResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListDeviceSessionsResponse && data == other.data;
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
      r'ListDeviceSessionsResponse',
    )..add('data', data)).toString();
  }
}

class ListDeviceSessionsResponseBuilder
    implements
        Builder<ListDeviceSessionsResponse, ListDeviceSessionsResponseBuilder> {
  _$ListDeviceSessionsResponse? _$v;

  ListDeviceSessionsDataBuilder? _data;
  ListDeviceSessionsDataBuilder get data =>
      _$this._data ??= ListDeviceSessionsDataBuilder();
  set data(ListDeviceSessionsDataBuilder? data) => _$this._data = data;

  ListDeviceSessionsResponseBuilder() {
    ListDeviceSessionsResponse._defaults(this);
  }

  ListDeviceSessionsResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListDeviceSessionsResponse other) {
    _$v = other as _$ListDeviceSessionsResponse;
  }

  @override
  void update(void Function(ListDeviceSessionsResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ListDeviceSessionsResponse build() => _build();

  _$ListDeviceSessionsResponse _build() {
    _$ListDeviceSessionsResponse _$result;
    try {
      _$result = _$v ?? _$ListDeviceSessionsResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ListDeviceSessionsResponse',
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
