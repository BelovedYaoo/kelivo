// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pull_sync_snapshot_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PullSyncSnapshotResponse extends PullSyncSnapshotResponse {
  @override
  final SyncSnapshotResponseData data;

  factory _$PullSyncSnapshotResponse([
    void Function(PullSyncSnapshotResponseBuilder)? updates,
  ]) => (PullSyncSnapshotResponseBuilder()..update(updates))._build();

  _$PullSyncSnapshotResponse._({required this.data}) : super._();
  @override
  PullSyncSnapshotResponse rebuild(
    void Function(PullSyncSnapshotResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  PullSyncSnapshotResponseBuilder toBuilder() =>
      PullSyncSnapshotResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PullSyncSnapshotResponse && data == other.data;
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
      r'PullSyncSnapshotResponse',
    )..add('data', data)).toString();
  }
}

class PullSyncSnapshotResponseBuilder
    implements
        Builder<PullSyncSnapshotResponse, PullSyncSnapshotResponseBuilder> {
  _$PullSyncSnapshotResponse? _$v;

  SyncSnapshotResponseDataBuilder? _data;
  SyncSnapshotResponseDataBuilder get data =>
      _$this._data ??= SyncSnapshotResponseDataBuilder();
  set data(SyncSnapshotResponseDataBuilder? data) => _$this._data = data;

  PullSyncSnapshotResponseBuilder() {
    PullSyncSnapshotResponse._defaults(this);
  }

  PullSyncSnapshotResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PullSyncSnapshotResponse other) {
    _$v = other as _$PullSyncSnapshotResponse;
  }

  @override
  void update(void Function(PullSyncSnapshotResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PullSyncSnapshotResponse build() => _build();

  _$PullSyncSnapshotResponse _build() {
    _$PullSyncSnapshotResponse _$result;
    try {
      _$result = _$v ?? _$PullSyncSnapshotResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'PullSyncSnapshotResponse',
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
