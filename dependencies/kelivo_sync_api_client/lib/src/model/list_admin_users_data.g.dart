// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_users_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListAdminUsersData extends ListAdminUsersData {
  @override
  final BuiltList<AdminUserSummary> items;
  @override
  final int total;
  @override
  final int pageIndex;
  @override
  final int pageSize;

  factory _$ListAdminUsersData([
    void Function(ListAdminUsersDataBuilder)? updates,
  ]) => (ListAdminUsersDataBuilder()..update(updates))._build();

  _$ListAdminUsersData._({
    required this.items,
    required this.total,
    required this.pageIndex,
    required this.pageSize,
  }) : super._();
  @override
  ListAdminUsersData rebuild(
    void Function(ListAdminUsersDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListAdminUsersDataBuilder toBuilder() =>
      ListAdminUsersDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListAdminUsersData &&
        items == other.items &&
        total == other.total &&
        pageIndex == other.pageIndex &&
        pageSize == other.pageSize;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, items.hashCode);
    _$hash = $jc(_$hash, total.hashCode);
    _$hash = $jc(_$hash, pageIndex.hashCode);
    _$hash = $jc(_$hash, pageSize.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ListAdminUsersData')
          ..add('items', items)
          ..add('total', total)
          ..add('pageIndex', pageIndex)
          ..add('pageSize', pageSize))
        .toString();
  }
}

class ListAdminUsersDataBuilder
    implements Builder<ListAdminUsersData, ListAdminUsersDataBuilder> {
  _$ListAdminUsersData? _$v;

  ListBuilder<AdminUserSummary>? _items;
  ListBuilder<AdminUserSummary> get items =>
      _$this._items ??= ListBuilder<AdminUserSummary>();
  set items(ListBuilder<AdminUserSummary>? items) => _$this._items = items;

  int? _total;
  int? get total => _$this._total;
  set total(int? total) => _$this._total = total;

  int? _pageIndex;
  int? get pageIndex => _$this._pageIndex;
  set pageIndex(int? pageIndex) => _$this._pageIndex = pageIndex;

  int? _pageSize;
  int? get pageSize => _$this._pageSize;
  set pageSize(int? pageSize) => _$this._pageSize = pageSize;

  ListAdminUsersDataBuilder() {
    ListAdminUsersData._defaults(this);
  }

  ListAdminUsersDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _items = $v.items.toBuilder();
      _total = $v.total;
      _pageIndex = $v.pageIndex;
      _pageSize = $v.pageSize;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListAdminUsersData other) {
    _$v = other as _$ListAdminUsersData;
  }

  @override
  void update(void Function(ListAdminUsersDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ListAdminUsersData build() => _build();

  _$ListAdminUsersData _build() {
    _$ListAdminUsersData _$result;
    try {
      _$result =
          _$v ??
          _$ListAdminUsersData._(
            items: items.build(),
            total: BuiltValueNullFieldError.checkNotNull(
              total,
              r'ListAdminUsersData',
              'total',
            ),
            pageIndex: BuiltValueNullFieldError.checkNotNull(
              pageIndex,
              r'ListAdminUsersData',
              'pageIndex',
            ),
            pageSize: BuiltValueNullFieldError.checkNotNull(
              pageSize,
              r'ListAdminUsersData',
              'pageSize',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'items';
        items.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ListAdminUsersData',
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
