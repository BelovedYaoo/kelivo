// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_snapshot_response_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SyncSnapshotResponseData extends SyncSnapshotResponseData {
  @override
  final BuiltList<SyncRecord> records;
  @override
  final String? nextSnapshotCursor;
  @override
  final String? syncCursor;
  @override
  final bool hasMore;

  factory _$SyncSnapshotResponseData([
    void Function(SyncSnapshotResponseDataBuilder)? updates,
  ]) => (SyncSnapshotResponseDataBuilder()..update(updates))._build();

  _$SyncSnapshotResponseData._({
    required this.records,
    this.nextSnapshotCursor,
    this.syncCursor,
    required this.hasMore,
  }) : super._();
  @override
  SyncSnapshotResponseData rebuild(
    void Function(SyncSnapshotResponseDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SyncSnapshotResponseDataBuilder toBuilder() =>
      SyncSnapshotResponseDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncSnapshotResponseData &&
        records == other.records &&
        nextSnapshotCursor == other.nextSnapshotCursor &&
        syncCursor == other.syncCursor &&
        hasMore == other.hasMore;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, records.hashCode);
    _$hash = $jc(_$hash, nextSnapshotCursor.hashCode);
    _$hash = $jc(_$hash, syncCursor.hashCode);
    _$hash = $jc(_$hash, hasMore.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncSnapshotResponseData')
          ..add('records', records)
          ..add('nextSnapshotCursor', nextSnapshotCursor)
          ..add('syncCursor', syncCursor)
          ..add('hasMore', hasMore))
        .toString();
  }
}

class SyncSnapshotResponseDataBuilder
    implements
        Builder<SyncSnapshotResponseData, SyncSnapshotResponseDataBuilder> {
  _$SyncSnapshotResponseData? _$v;

  ListBuilder<SyncRecord>? _records;
  ListBuilder<SyncRecord> get records =>
      _$this._records ??= ListBuilder<SyncRecord>();
  set records(ListBuilder<SyncRecord>? records) => _$this._records = records;

  String? _nextSnapshotCursor;
  String? get nextSnapshotCursor => _$this._nextSnapshotCursor;
  set nextSnapshotCursor(String? nextSnapshotCursor) =>
      _$this._nextSnapshotCursor = nextSnapshotCursor;

  String? _syncCursor;
  String? get syncCursor => _$this._syncCursor;
  set syncCursor(String? syncCursor) => _$this._syncCursor = syncCursor;

  bool? _hasMore;
  bool? get hasMore => _$this._hasMore;
  set hasMore(bool? hasMore) => _$this._hasMore = hasMore;

  SyncSnapshotResponseDataBuilder() {
    SyncSnapshotResponseData._defaults(this);
  }

  SyncSnapshotResponseDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _records = $v.records.toBuilder();
      _nextSnapshotCursor = $v.nextSnapshotCursor;
      _syncCursor = $v.syncCursor;
      _hasMore = $v.hasMore;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncSnapshotResponseData other) {
    _$v = other as _$SyncSnapshotResponseData;
  }

  @override
  void update(void Function(SyncSnapshotResponseDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncSnapshotResponseData build() => _build();

  _$SyncSnapshotResponseData _build() {
    _$SyncSnapshotResponseData _$result;
    try {
      _$result =
          _$v ??
          _$SyncSnapshotResponseData._(
            records: records.build(),
            nextSnapshotCursor: nextSnapshotCursor,
            syncCursor: syncCursor,
            hasMore: BuiltValueNullFieldError.checkNotNull(
              hasMore,
              r'SyncSnapshotResponseData',
              'hasMore',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'records';
        records.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'SyncSnapshotResponseData',
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
