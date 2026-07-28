// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_pull_page_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SyncPullPageData extends SyncPullPageData {
  @override
  final BuiltList<SyncChange> changes;
  @override
  final String nextCursor;
  @override
  final bool hasMore;
  @override
  final bool resetRequired;

  factory _$SyncPullPageData([
    void Function(SyncPullPageDataBuilder)? updates,
  ]) => (SyncPullPageDataBuilder()..update(updates))._build();

  _$SyncPullPageData._({
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
    required this.resetRequired,
  }) : super._();
  @override
  SyncPullPageData rebuild(void Function(SyncPullPageDataBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SyncPullPageDataBuilder toBuilder() =>
      SyncPullPageDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncPullPageData &&
        changes == other.changes &&
        nextCursor == other.nextCursor &&
        hasMore == other.hasMore &&
        resetRequired == other.resetRequired;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, changes.hashCode);
    _$hash = $jc(_$hash, nextCursor.hashCode);
    _$hash = $jc(_$hash, hasMore.hashCode);
    _$hash = $jc(_$hash, resetRequired.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncPullPageData')
          ..add('changes', changes)
          ..add('nextCursor', nextCursor)
          ..add('hasMore', hasMore)
          ..add('resetRequired', resetRequired))
        .toString();
  }
}

class SyncPullPageDataBuilder
    implements Builder<SyncPullPageData, SyncPullPageDataBuilder> {
  _$SyncPullPageData? _$v;

  ListBuilder<SyncChange>? _changes;
  ListBuilder<SyncChange> get changes =>
      _$this._changes ??= ListBuilder<SyncChange>();
  set changes(ListBuilder<SyncChange>? changes) => _$this._changes = changes;

  String? _nextCursor;
  String? get nextCursor => _$this._nextCursor;
  set nextCursor(String? nextCursor) => _$this._nextCursor = nextCursor;

  bool? _hasMore;
  bool? get hasMore => _$this._hasMore;
  set hasMore(bool? hasMore) => _$this._hasMore = hasMore;

  bool? _resetRequired;
  bool? get resetRequired => _$this._resetRequired;
  set resetRequired(bool? resetRequired) =>
      _$this._resetRequired = resetRequired;

  SyncPullPageDataBuilder() {
    SyncPullPageData._defaults(this);
  }

  SyncPullPageDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _changes = $v.changes.toBuilder();
      _nextCursor = $v.nextCursor;
      _hasMore = $v.hasMore;
      _resetRequired = $v.resetRequired;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncPullPageData other) {
    _$v = other as _$SyncPullPageData;
  }

  @override
  void update(void Function(SyncPullPageDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncPullPageData build() => _build();

  _$SyncPullPageData _build() {
    _$SyncPullPageData _$result;
    try {
      _$result =
          _$v ??
          _$SyncPullPageData._(
            changes: changes.build(),
            nextCursor: BuiltValueNullFieldError.checkNotNull(
              nextCursor,
              r'SyncPullPageData',
              'nextCursor',
            ),
            hasMore: BuiltValueNullFieldError.checkNotNull(
              hasMore,
              r'SyncPullPageData',
              'hasMore',
            ),
            resetRequired: BuiltValueNullFieldError.checkNotNull(
              resetRequired,
              r'SyncPullPageData',
              'resetRequired',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'changes';
        changes.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'SyncPullPageData',
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
