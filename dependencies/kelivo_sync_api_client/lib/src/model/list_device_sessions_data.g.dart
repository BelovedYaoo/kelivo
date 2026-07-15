// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_device_sessions_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListDeviceSessionsData extends ListDeviceSessionsData {
  @override
  final BuiltList<DeviceSessionSummary> items;
  @override
  final int total;
  @override
  final int pageIndex;
  @override
  final int pageSize;

  factory _$ListDeviceSessionsData([
    void Function(ListDeviceSessionsDataBuilder)? updates,
  ]) => (ListDeviceSessionsDataBuilder()..update(updates))._build();

  _$ListDeviceSessionsData._({
    required this.items,
    required this.total,
    required this.pageIndex,
    required this.pageSize,
  }) : super._();
  @override
  ListDeviceSessionsData rebuild(
    void Function(ListDeviceSessionsDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListDeviceSessionsDataBuilder toBuilder() =>
      ListDeviceSessionsDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListDeviceSessionsData &&
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
    return (newBuiltValueToStringHelper(r'ListDeviceSessionsData')
          ..add('items', items)
          ..add('total', total)
          ..add('pageIndex', pageIndex)
          ..add('pageSize', pageSize))
        .toString();
  }
}

class ListDeviceSessionsDataBuilder
    implements Builder<ListDeviceSessionsData, ListDeviceSessionsDataBuilder> {
  _$ListDeviceSessionsData? _$v;

  ListBuilder<DeviceSessionSummary>? _items;
  ListBuilder<DeviceSessionSummary> get items =>
      _$this._items ??= ListBuilder<DeviceSessionSummary>();
  set items(ListBuilder<DeviceSessionSummary>? items) => _$this._items = items;

  int? _total;
  int? get total => _$this._total;
  set total(int? total) => _$this._total = total;

  int? _pageIndex;
  int? get pageIndex => _$this._pageIndex;
  set pageIndex(int? pageIndex) => _$this._pageIndex = pageIndex;

  int? _pageSize;
  int? get pageSize => _$this._pageSize;
  set pageSize(int? pageSize) => _$this._pageSize = pageSize;

  ListDeviceSessionsDataBuilder() {
    ListDeviceSessionsData._defaults(this);
  }

  ListDeviceSessionsDataBuilder get _$this {
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
  void replace(ListDeviceSessionsData other) {
    _$v = other as _$ListDeviceSessionsData;
  }

  @override
  void update(void Function(ListDeviceSessionsDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ListDeviceSessionsData build() => _build();

  _$ListDeviceSessionsData _build() {
    _$ListDeviceSessionsData _$result;
    try {
      _$result =
          _$v ??
          _$ListDeviceSessionsData._(
            items: items.build(),
            total: BuiltValueNullFieldError.checkNotNull(
              total,
              r'ListDeviceSessionsData',
              'total',
            ),
            pageIndex: BuiltValueNullFieldError.checkNotNull(
              pageIndex,
              r'ListDeviceSessionsData',
              'pageIndex',
            ),
            pageSize: BuiltValueNullFieldError.checkNotNull(
              pageSize,
              r'ListDeviceSessionsData',
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
          r'ListDeviceSessionsData',
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
