// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_device_security_state_history_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListDeviceSecurityStateHistoryResponse
    extends ListDeviceSecurityStateHistoryResponse {
  @override
  final ListAccountSecurityStateHistoryData data;

  factory _$ListDeviceSecurityStateHistoryResponse([
    void Function(ListDeviceSecurityStateHistoryResponseBuilder)? updates,
  ]) => (ListDeviceSecurityStateHistoryResponseBuilder()..update(updates))
      ._build();

  _$ListDeviceSecurityStateHistoryResponse._({required this.data}) : super._();
  @override
  ListDeviceSecurityStateHistoryResponse rebuild(
    void Function(ListDeviceSecurityStateHistoryResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListDeviceSecurityStateHistoryResponseBuilder toBuilder() =>
      ListDeviceSecurityStateHistoryResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListDeviceSecurityStateHistoryResponse &&
        data == other.data;
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
      r'ListDeviceSecurityStateHistoryResponse',
    )..add('data', data)).toString();
  }
}

class ListDeviceSecurityStateHistoryResponseBuilder
    implements
        Builder<
          ListDeviceSecurityStateHistoryResponse,
          ListDeviceSecurityStateHistoryResponseBuilder
        > {
  _$ListDeviceSecurityStateHistoryResponse? _$v;

  ListAccountSecurityStateHistoryDataBuilder? _data;
  ListAccountSecurityStateHistoryDataBuilder get data =>
      _$this._data ??= ListAccountSecurityStateHistoryDataBuilder();
  set data(ListAccountSecurityStateHistoryDataBuilder? data) =>
      _$this._data = data;

  ListDeviceSecurityStateHistoryResponseBuilder() {
    ListDeviceSecurityStateHistoryResponse._defaults(this);
  }

  ListDeviceSecurityStateHistoryResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListDeviceSecurityStateHistoryResponse other) {
    _$v = other as _$ListDeviceSecurityStateHistoryResponse;
  }

  @override
  void update(
    void Function(ListDeviceSecurityStateHistoryResponseBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  ListDeviceSecurityStateHistoryResponse build() => _build();

  _$ListDeviceSecurityStateHistoryResponse _build() {
    _$ListDeviceSecurityStateHistoryResponse _$result;
    try {
      _$result =
          _$v ?? _$ListDeviceSecurityStateHistoryResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ListDeviceSecurityStateHistoryResponse',
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
