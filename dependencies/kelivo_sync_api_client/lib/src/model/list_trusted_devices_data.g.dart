// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_trusted_devices_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListTrustedDevicesData extends ListTrustedDevicesData {
  @override
  final BuiltList<TrustedDeviceSummary> items;
  @override
  final int total;
  @override
  final int pageIndex;
  @override
  final int pageSize;

  factory _$ListTrustedDevicesData([
    void Function(ListTrustedDevicesDataBuilder)? updates,
  ]) => (ListTrustedDevicesDataBuilder()..update(updates))._build();

  _$ListTrustedDevicesData._({
    required this.items,
    required this.total,
    required this.pageIndex,
    required this.pageSize,
  }) : super._();
  @override
  ListTrustedDevicesData rebuild(
    void Function(ListTrustedDevicesDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListTrustedDevicesDataBuilder toBuilder() =>
      ListTrustedDevicesDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListTrustedDevicesData &&
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
    return (newBuiltValueToStringHelper(r'ListTrustedDevicesData')
          ..add('items', items)
          ..add('total', total)
          ..add('pageIndex', pageIndex)
          ..add('pageSize', pageSize))
        .toString();
  }
}

class ListTrustedDevicesDataBuilder
    implements Builder<ListTrustedDevicesData, ListTrustedDevicesDataBuilder> {
  _$ListTrustedDevicesData? _$v;

  ListBuilder<TrustedDeviceSummary>? _items;
  ListBuilder<TrustedDeviceSummary> get items =>
      _$this._items ??= ListBuilder<TrustedDeviceSummary>();
  set items(ListBuilder<TrustedDeviceSummary>? items) => _$this._items = items;

  int? _total;
  int? get total => _$this._total;
  set total(int? total) => _$this._total = total;

  int? _pageIndex;
  int? get pageIndex => _$this._pageIndex;
  set pageIndex(int? pageIndex) => _$this._pageIndex = pageIndex;

  int? _pageSize;
  int? get pageSize => _$this._pageSize;
  set pageSize(int? pageSize) => _$this._pageSize = pageSize;

  ListTrustedDevicesDataBuilder() {
    ListTrustedDevicesData._defaults(this);
  }

  ListTrustedDevicesDataBuilder get _$this {
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
  void replace(ListTrustedDevicesData other) {
    _$v = other as _$ListTrustedDevicesData;
  }

  @override
  void update(void Function(ListTrustedDevicesDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ListTrustedDevicesData build() => _build();

  _$ListTrustedDevicesData _build() {
    _$ListTrustedDevicesData _$result;
    try {
      _$result =
          _$v ??
          _$ListTrustedDevicesData._(
            items: items.build(),
            total: BuiltValueNullFieldError.checkNotNull(
              total,
              r'ListTrustedDevicesData',
              'total',
            ),
            pageIndex: BuiltValueNullFieldError.checkNotNull(
              pageIndex,
              r'ListTrustedDevicesData',
              'pageIndex',
            ),
            pageSize: BuiltValueNullFieldError.checkNotNull(
              pageSize,
              r'ListTrustedDevicesData',
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
          r'ListTrustedDevicesData',
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
