// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_recovery_history_list_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AccountRecoveryHistoryListData extends AccountRecoveryHistoryListData {
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

  factory _$AccountRecoveryHistoryListData([
    void Function(AccountRecoveryHistoryListDataBuilder)? updates,
  ]) => (AccountRecoveryHistoryListDataBuilder()..update(updates))._build();

  _$AccountRecoveryHistoryListData._({
    required this.items,
    required this.afterGeneration,
    required this.nextAfterGeneration,
    required this.pageSize,
    required this.hasMore,
    required this.currentState,
  }) : super._();
  @override
  AccountRecoveryHistoryListData rebuild(
    void Function(AccountRecoveryHistoryListDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountRecoveryHistoryListDataBuilder toBuilder() =>
      AccountRecoveryHistoryListDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountRecoveryHistoryListData &&
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
    return (newBuiltValueToStringHelper(r'AccountRecoveryHistoryListData')
          ..add('items', items)
          ..add('afterGeneration', afterGeneration)
          ..add('nextAfterGeneration', nextAfterGeneration)
          ..add('pageSize', pageSize)
          ..add('hasMore', hasMore)
          ..add('currentState', currentState))
        .toString();
  }
}

class AccountRecoveryHistoryListDataBuilder
    implements
        Builder<
          AccountRecoveryHistoryListData,
          AccountRecoveryHistoryListDataBuilder
        > {
  _$AccountRecoveryHistoryListData? _$v;

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

  AccountRecoveryHistoryListDataBuilder() {
    AccountRecoveryHistoryListData._defaults(this);
  }

  AccountRecoveryHistoryListDataBuilder get _$this {
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
  void replace(AccountRecoveryHistoryListData other) {
    _$v = other as _$AccountRecoveryHistoryListData;
  }

  @override
  void update(void Function(AccountRecoveryHistoryListDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AccountRecoveryHistoryListData build() => _build();

  _$AccountRecoveryHistoryListData _build() {
    _$AccountRecoveryHistoryListData _$result;
    try {
      _$result =
          _$v ??
          _$AccountRecoveryHistoryListData._(
            items: items.build(),
            afterGeneration: BuiltValueNullFieldError.checkNotNull(
              afterGeneration,
              r'AccountRecoveryHistoryListData',
              'afterGeneration',
            ),
            nextAfterGeneration: BuiltValueNullFieldError.checkNotNull(
              nextAfterGeneration,
              r'AccountRecoveryHistoryListData',
              'nextAfterGeneration',
            ),
            pageSize: BuiltValueNullFieldError.checkNotNull(
              pageSize,
              r'AccountRecoveryHistoryListData',
              'pageSize',
            ),
            hasMore: BuiltValueNullFieldError.checkNotNull(
              hasMore,
              r'AccountRecoveryHistoryListData',
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
          r'AccountRecoveryHistoryListData',
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
