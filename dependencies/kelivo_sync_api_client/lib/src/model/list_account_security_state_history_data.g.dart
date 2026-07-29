// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_account_security_state_history_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListAccountSecurityStateHistoryData
    extends ListAccountSecurityStateHistoryData {
  @override
  final BuiltList<AccountSecurityStateHistoryItem> items;
  @override
  final int afterGeneration;
  @override
  final int nextAfterGeneration;
  @override
  final int pageSize;
  @override
  final bool hasMore;
  @override
  final AccountSecurityStateCurrentProjection currentState;

  factory _$ListAccountSecurityStateHistoryData([
    void Function(ListAccountSecurityStateHistoryDataBuilder)? updates,
  ]) =>
      (ListAccountSecurityStateHistoryDataBuilder()..update(updates))._build();

  _$ListAccountSecurityStateHistoryData._({
    required this.items,
    required this.afterGeneration,
    required this.nextAfterGeneration,
    required this.pageSize,
    required this.hasMore,
    required this.currentState,
  }) : super._();
  @override
  ListAccountSecurityStateHistoryData rebuild(
    void Function(ListAccountSecurityStateHistoryDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListAccountSecurityStateHistoryDataBuilder toBuilder() =>
      ListAccountSecurityStateHistoryDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListAccountSecurityStateHistoryData &&
        items == other.items &&
        afterGeneration == other.afterGeneration &&
        nextAfterGeneration == other.nextAfterGeneration &&
        pageSize == other.pageSize &&
        hasMore == other.hasMore &&
        currentState == other.currentState;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, items.hashCode);
    _$hash = $jc(_$hash, afterGeneration.hashCode);
    _$hash = $jc(_$hash, nextAfterGeneration.hashCode);
    _$hash = $jc(_$hash, pageSize.hashCode);
    _$hash = $jc(_$hash, hasMore.hashCode);
    _$hash = $jc(_$hash, currentState.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ListAccountSecurityStateHistoryData')
          ..add('items', items)
          ..add('afterGeneration', afterGeneration)
          ..add('nextAfterGeneration', nextAfterGeneration)
          ..add('pageSize', pageSize)
          ..add('hasMore', hasMore)
          ..add('currentState', currentState))
        .toString();
  }
}

class ListAccountSecurityStateHistoryDataBuilder
    implements
        Builder<
          ListAccountSecurityStateHistoryData,
          ListAccountSecurityStateHistoryDataBuilder
        > {
  _$ListAccountSecurityStateHistoryData? _$v;

  ListBuilder<AccountSecurityStateHistoryItem>? _items;
  ListBuilder<AccountSecurityStateHistoryItem> get items =>
      _$this._items ??= ListBuilder<AccountSecurityStateHistoryItem>();
  set items(ListBuilder<AccountSecurityStateHistoryItem>? items) =>
      _$this._items = items;

  int? _afterGeneration;
  int? get afterGeneration => _$this._afterGeneration;
  set afterGeneration(int? afterGeneration) =>
      _$this._afterGeneration = afterGeneration;

  int? _nextAfterGeneration;
  int? get nextAfterGeneration => _$this._nextAfterGeneration;
  set nextAfterGeneration(int? nextAfterGeneration) =>
      _$this._nextAfterGeneration = nextAfterGeneration;

  int? _pageSize;
  int? get pageSize => _$this._pageSize;
  set pageSize(int? pageSize) => _$this._pageSize = pageSize;

  bool? _hasMore;
  bool? get hasMore => _$this._hasMore;
  set hasMore(bool? hasMore) => _$this._hasMore = hasMore;

  AccountSecurityStateCurrentProjectionBuilder? _currentState;
  AccountSecurityStateCurrentProjectionBuilder get currentState =>
      _$this._currentState ??= AccountSecurityStateCurrentProjectionBuilder();
  set currentState(
    AccountSecurityStateCurrentProjectionBuilder? currentState,
  ) => _$this._currentState = currentState;

  ListAccountSecurityStateHistoryDataBuilder() {
    ListAccountSecurityStateHistoryData._defaults(this);
  }

  ListAccountSecurityStateHistoryDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _items = $v.items.toBuilder();
      _afterGeneration = $v.afterGeneration;
      _nextAfterGeneration = $v.nextAfterGeneration;
      _pageSize = $v.pageSize;
      _hasMore = $v.hasMore;
      _currentState = $v.currentState.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListAccountSecurityStateHistoryData other) {
    _$v = other as _$ListAccountSecurityStateHistoryData;
  }

  @override
  void update(
    void Function(ListAccountSecurityStateHistoryDataBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  ListAccountSecurityStateHistoryData build() => _build();

  _$ListAccountSecurityStateHistoryData _build() {
    _$ListAccountSecurityStateHistoryData _$result;
    try {
      _$result =
          _$v ??
          _$ListAccountSecurityStateHistoryData._(
            items: items.build(),
            afterGeneration: BuiltValueNullFieldError.checkNotNull(
              afterGeneration,
              r'ListAccountSecurityStateHistoryData',
              'afterGeneration',
            ),
            nextAfterGeneration: BuiltValueNullFieldError.checkNotNull(
              nextAfterGeneration,
              r'ListAccountSecurityStateHistoryData',
              'nextAfterGeneration',
            ),
            pageSize: BuiltValueNullFieldError.checkNotNull(
              pageSize,
              r'ListAccountSecurityStateHistoryData',
              'pageSize',
            ),
            hasMore: BuiltValueNullFieldError.checkNotNull(
              hasMore,
              r'ListAccountSecurityStateHistoryData',
              'hasMore',
            ),
            currentState: currentState.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'items';
        items.build();

        _$failedField = 'currentState';
        currentState.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ListAccountSecurityStateHistoryData',
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
