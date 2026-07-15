// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_pull_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SyncPullRequest extends SyncPullRequest {
  @override
  final String? cursor;
  @override
  final int? limit;

  factory _$SyncPullRequest([void Function(SyncPullRequestBuilder)? updates]) =>
      (SyncPullRequestBuilder()..update(updates))._build();

  _$SyncPullRequest._({this.cursor, this.limit}) : super._();
  @override
  SyncPullRequest rebuild(void Function(SyncPullRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SyncPullRequestBuilder toBuilder() => SyncPullRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncPullRequest &&
        cursor == other.cursor &&
        limit == other.limit;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, cursor.hashCode);
    _$hash = $jc(_$hash, limit.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncPullRequest')
          ..add('cursor', cursor)
          ..add('limit', limit))
        .toString();
  }
}

class SyncPullRequestBuilder
    implements Builder<SyncPullRequest, SyncPullRequestBuilder> {
  _$SyncPullRequest? _$v;

  String? _cursor;
  String? get cursor => _$this._cursor;
  set cursor(String? cursor) => _$this._cursor = cursor;

  int? _limit;
  int? get limit => _$this._limit;
  set limit(int? limit) => _$this._limit = limit;

  SyncPullRequestBuilder() {
    SyncPullRequest._defaults(this);
  }

  SyncPullRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _cursor = $v.cursor;
      _limit = $v.limit;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncPullRequest other) {
    _$v = other as _$SyncPullRequest;
  }

  @override
  void update(void Function(SyncPullRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncPullRequest build() => _build();

  _$SyncPullRequest _build() {
    final _$result = _$v ?? _$SyncPullRequest._(cursor: cursor, limit: limit);
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
