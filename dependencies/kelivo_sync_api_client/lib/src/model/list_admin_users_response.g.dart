// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_users_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListAdminUsersResponse extends ListAdminUsersResponse {
  @override
  final ListAdminUsersData data;

  factory _$ListAdminUsersResponse([
    void Function(ListAdminUsersResponseBuilder)? updates,
  ]) => (ListAdminUsersResponseBuilder()..update(updates))._build();

  _$ListAdminUsersResponse._({required this.data}) : super._();
  @override
  ListAdminUsersResponse rebuild(
    void Function(ListAdminUsersResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListAdminUsersResponseBuilder toBuilder() =>
      ListAdminUsersResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListAdminUsersResponse && data == other.data;
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
      r'ListAdminUsersResponse',
    )..add('data', data)).toString();
  }
}

class ListAdminUsersResponseBuilder
    implements Builder<ListAdminUsersResponse, ListAdminUsersResponseBuilder> {
  _$ListAdminUsersResponse? _$v;

  ListAdminUsersDataBuilder? _data;
  ListAdminUsersDataBuilder get data =>
      _$this._data ??= ListAdminUsersDataBuilder();
  set data(ListAdminUsersDataBuilder? data) => _$this._data = data;

  ListAdminUsersResponseBuilder() {
    ListAdminUsersResponse._defaults(this);
  }

  ListAdminUsersResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListAdminUsersResponse other) {
    _$v = other as _$ListAdminUsersResponse;
  }

  @override
  void update(void Function(ListAdminUsersResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ListAdminUsersResponse build() => _build();

  _$ListAdminUsersResponse _build() {
    _$ListAdminUsersResponse _$result;
    try {
      _$result = _$v ?? _$ListAdminUsersResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ListAdminUsersResponse',
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
