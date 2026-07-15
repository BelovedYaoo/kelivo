// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_devices_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListAdminDevicesData extends ListAdminDevicesData {
  @override
  final BuiltList<AdminDeviceSummary> items;
  @override
  final int total;
  @override
  final int pageIndex;
  @override
  final int pageSize;

  factory _$ListAdminDevicesData([
    void Function(ListAdminDevicesDataBuilder)? updates,
  ]) => (ListAdminDevicesDataBuilder()..update(updates))._build();

  _$ListAdminDevicesData._({
    required this.items,
    required this.total,
    required this.pageIndex,
    required this.pageSize,
  }) : super._();
  @override
  ListAdminDevicesData rebuild(
    void Function(ListAdminDevicesDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListAdminDevicesDataBuilder toBuilder() =>
      ListAdminDevicesDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListAdminDevicesData &&
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
    return (newBuiltValueToStringHelper(r'ListAdminDevicesData')
          ..add('items', items)
          ..add('total', total)
          ..add('pageIndex', pageIndex)
          ..add('pageSize', pageSize))
        .toString();
  }
}

class ListAdminDevicesDataBuilder
    implements Builder<ListAdminDevicesData, ListAdminDevicesDataBuilder> {
  _$ListAdminDevicesData? _$v;

  ListBuilder<AdminDeviceSummary>? _items;
  ListBuilder<AdminDeviceSummary> get items =>
      _$this._items ??= ListBuilder<AdminDeviceSummary>();
  set items(ListBuilder<AdminDeviceSummary>? items) => _$this._items = items;

  int? _total;
  int? get total => _$this._total;
  set total(int? total) => _$this._total = total;

  int? _pageIndex;
  int? get pageIndex => _$this._pageIndex;
  set pageIndex(int? pageIndex) => _$this._pageIndex = pageIndex;

  int? _pageSize;
  int? get pageSize => _$this._pageSize;
  set pageSize(int? pageSize) => _$this._pageSize = pageSize;

  ListAdminDevicesDataBuilder() {
    ListAdminDevicesData._defaults(this);
  }

  ListAdminDevicesDataBuilder get _$this {
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
  void replace(ListAdminDevicesData other) {
    _$v = other as _$ListAdminDevicesData;
  }

  @override
  void update(void Function(ListAdminDevicesDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ListAdminDevicesData build() => _build();

  _$ListAdminDevicesData _build() {
    _$ListAdminDevicesData _$result;
    try {
      _$result =
          _$v ??
          _$ListAdminDevicesData._(
            items: items.build(),
            total: BuiltValueNullFieldError.checkNotNull(
              total,
              r'ListAdminDevicesData',
              'total',
            ),
            pageIndex: BuiltValueNullFieldError.checkNotNull(
              pageIndex,
              r'ListAdminDevicesData',
              'pageIndex',
            ),
            pageSize: BuiltValueNullFieldError.checkNotNull(
              pageSize,
              r'ListAdminDevicesData',
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
          r'ListAdminDevicesData',
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
