// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_snapshot_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SyncSnapshotRequest extends SyncSnapshotRequest {
  @override
  final String? snapshotCursor;
  @override
  final int? limit;

  factory _$SyncSnapshotRequest([
    void Function(SyncSnapshotRequestBuilder)? updates,
  ]) => (SyncSnapshotRequestBuilder()..update(updates))._build();

  _$SyncSnapshotRequest._({this.snapshotCursor, this.limit}) : super._();
  @override
  SyncSnapshotRequest rebuild(
    void Function(SyncSnapshotRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SyncSnapshotRequestBuilder toBuilder() =>
      SyncSnapshotRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncSnapshotRequest &&
        snapshotCursor == other.snapshotCursor &&
        limit == other.limit;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, snapshotCursor.hashCode);
    _$hash = $jc(_$hash, limit.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncSnapshotRequest')
          ..add('snapshotCursor', snapshotCursor)
          ..add('limit', limit))
        .toString();
  }
}

class SyncSnapshotRequestBuilder
    implements Builder<SyncSnapshotRequest, SyncSnapshotRequestBuilder> {
  _$SyncSnapshotRequest? _$v;

  String? _snapshotCursor;
  String? get snapshotCursor => _$this._snapshotCursor;
  set snapshotCursor(String? snapshotCursor) =>
      _$this._snapshotCursor = snapshotCursor;

  int? _limit;
  int? get limit => _$this._limit;
  set limit(int? limit) => _$this._limit = limit;

  SyncSnapshotRequestBuilder() {
    SyncSnapshotRequest._defaults(this);
  }

  SyncSnapshotRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _snapshotCursor = $v.snapshotCursor;
      _limit = $v.limit;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncSnapshotRequest other) {
    _$v = other as _$SyncSnapshotRequest;
  }

  @override
  void update(void Function(SyncSnapshotRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncSnapshotRequest build() => _build();

  _$SyncSnapshotRequest _build() {
    final _$result =
        _$v ??
        _$SyncSnapshotRequest._(snapshotCursor: snapshotCursor, limit: limit);
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
