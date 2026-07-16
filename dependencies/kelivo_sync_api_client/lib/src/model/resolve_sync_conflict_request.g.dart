// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resolve_sync_conflict_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ResolveSyncConflictRequest extends ResolveSyncConflictRequest {
  @override
  final String conflictId;

  factory _$ResolveSyncConflictRequest([
    void Function(ResolveSyncConflictRequestBuilder)? updates,
  ]) => (ResolveSyncConflictRequestBuilder()..update(updates))._build();

  _$ResolveSyncConflictRequest._({required this.conflictId}) : super._();
  @override
  ResolveSyncConflictRequest rebuild(
    void Function(ResolveSyncConflictRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ResolveSyncConflictRequestBuilder toBuilder() =>
      ResolveSyncConflictRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ResolveSyncConflictRequest &&
        conflictId == other.conflictId;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, conflictId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'ResolveSyncConflictRequest',
    )..add('conflictId', conflictId)).toString();
  }
}

class ResolveSyncConflictRequestBuilder
    implements
        Builder<ResolveSyncConflictRequest, ResolveSyncConflictRequestBuilder> {
  _$ResolveSyncConflictRequest? _$v;

  String? _conflictId;
  String? get conflictId => _$this._conflictId;
  set conflictId(String? conflictId) => _$this._conflictId = conflictId;

  ResolveSyncConflictRequestBuilder() {
    ResolveSyncConflictRequest._defaults(this);
  }

  ResolveSyncConflictRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _conflictId = $v.conflictId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ResolveSyncConflictRequest other) {
    _$v = other as _$ResolveSyncConflictRequest;
  }

  @override
  void update(void Function(ResolveSyncConflictRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ResolveSyncConflictRequest build() => _build();

  _$ResolveSyncConflictRequest _build() {
    final _$result =
        _$v ??
        _$ResolveSyncConflictRequest._(
          conflictId: BuiltValueNullFieldError.checkNotNull(
            conflictId,
            r'ResolveSyncConflictRequest',
            'conflictId',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
