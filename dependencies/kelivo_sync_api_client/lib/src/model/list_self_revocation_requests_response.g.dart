// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_self_revocation_requests_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListSelfRevocationRequestsResponse
    extends ListSelfRevocationRequestsResponse {
  @override
  final SelfRevocationRequestListData data;

  factory _$ListSelfRevocationRequestsResponse([
    void Function(ListSelfRevocationRequestsResponseBuilder)? updates,
  ]) => (ListSelfRevocationRequestsResponseBuilder()..update(updates))._build();

  _$ListSelfRevocationRequestsResponse._({required this.data}) : super._();
  @override
  ListSelfRevocationRequestsResponse rebuild(
    void Function(ListSelfRevocationRequestsResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListSelfRevocationRequestsResponseBuilder toBuilder() =>
      ListSelfRevocationRequestsResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListSelfRevocationRequestsResponse && data == other.data;
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
      r'ListSelfRevocationRequestsResponse',
    )..add('data', data)).toString();
  }
}

class ListSelfRevocationRequestsResponseBuilder
    implements
        Builder<
          ListSelfRevocationRequestsResponse,
          ListSelfRevocationRequestsResponseBuilder
        > {
  _$ListSelfRevocationRequestsResponse? _$v;

  SelfRevocationRequestListDataBuilder? _data;
  SelfRevocationRequestListDataBuilder get data =>
      _$this._data ??= SelfRevocationRequestListDataBuilder();
  set data(SelfRevocationRequestListDataBuilder? data) => _$this._data = data;

  ListSelfRevocationRequestsResponseBuilder() {
    ListSelfRevocationRequestsResponse._defaults(this);
  }

  ListSelfRevocationRequestsResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListSelfRevocationRequestsResponse other) {
    _$v = other as _$ListSelfRevocationRequestsResponse;
  }

  @override
  void update(
    void Function(ListSelfRevocationRequestsResponseBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  ListSelfRevocationRequestsResponse build() => _build();

  _$ListSelfRevocationRequestsResponse _build() {
    _$ListSelfRevocationRequestsResponse _$result;
    try {
      _$result =
          _$v ?? _$ListSelfRevocationRequestsResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ListSelfRevocationRequestsResponse',
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
