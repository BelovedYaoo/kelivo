// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pull_sync_changes_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PullSyncChangesResponse extends PullSyncChangesResponse {
  @override
  final SyncPullResponseData data;

  factory _$PullSyncChangesResponse([
    void Function(PullSyncChangesResponseBuilder)? updates,
  ]) => (PullSyncChangesResponseBuilder()..update(updates))._build();

  _$PullSyncChangesResponse._({required this.data}) : super._();
  @override
  PullSyncChangesResponse rebuild(
    void Function(PullSyncChangesResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  PullSyncChangesResponseBuilder toBuilder() =>
      PullSyncChangesResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PullSyncChangesResponse && data == other.data;
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
      r'PullSyncChangesResponse',
    )..add('data', data)).toString();
  }
}

class PullSyncChangesResponseBuilder
    implements
        Builder<PullSyncChangesResponse, PullSyncChangesResponseBuilder> {
  _$PullSyncChangesResponse? _$v;

  SyncPullResponseDataBuilder? _data;
  SyncPullResponseDataBuilder get data =>
      _$this._data ??= SyncPullResponseDataBuilder();
  set data(SyncPullResponseDataBuilder? data) => _$this._data = data;

  PullSyncChangesResponseBuilder() {
    PullSyncChangesResponse._defaults(this);
  }

  PullSyncChangesResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PullSyncChangesResponse other) {
    _$v = other as _$PullSyncChangesResponse;
  }

  @override
  void update(void Function(PullSyncChangesResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PullSyncChangesResponse build() => _build();

  _$PullSyncChangesResponse _build() {
    _$PullSyncChangesResponse _$result;
    try {
      _$result = _$v ?? _$PullSyncChangesResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'PullSyncChangesResponse',
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
