// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resolve_sync_conflict_response_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ResolveSyncConflictResponseData
    extends ResolveSyncConflictResponseData {
  @override
  final SyncConflict conflict;

  factory _$ResolveSyncConflictResponseData([
    void Function(ResolveSyncConflictResponseDataBuilder)? updates,
  ]) => (ResolveSyncConflictResponseDataBuilder()..update(updates))._build();

  _$ResolveSyncConflictResponseData._({required this.conflict}) : super._();
  @override
  ResolveSyncConflictResponseData rebuild(
    void Function(ResolveSyncConflictResponseDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ResolveSyncConflictResponseDataBuilder toBuilder() =>
      ResolveSyncConflictResponseDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ResolveSyncConflictResponseData &&
        conflict == other.conflict;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, conflict.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'ResolveSyncConflictResponseData',
    )..add('conflict', conflict)).toString();
  }
}

class ResolveSyncConflictResponseDataBuilder
    implements
        Builder<
          ResolveSyncConflictResponseData,
          ResolveSyncConflictResponseDataBuilder
        > {
  _$ResolveSyncConflictResponseData? _$v;

  SyncConflictBuilder? _conflict;
  SyncConflictBuilder get conflict =>
      _$this._conflict ??= SyncConflictBuilder();
  set conflict(SyncConflictBuilder? conflict) => _$this._conflict = conflict;

  ResolveSyncConflictResponseDataBuilder() {
    ResolveSyncConflictResponseData._defaults(this);
  }

  ResolveSyncConflictResponseDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _conflict = $v.conflict.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ResolveSyncConflictResponseData other) {
    _$v = other as _$ResolveSyncConflictResponseData;
  }

  @override
  void update(void Function(ResolveSyncConflictResponseDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ResolveSyncConflictResponseData build() => _build();

  _$ResolveSyncConflictResponseData _build() {
    _$ResolveSyncConflictResponseData _$result;
    try {
      _$result =
          _$v ??
          _$ResolveSyncConflictResponseData._(conflict: conflict.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'conflict';
        conflict.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ResolveSyncConflictResponseData',
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
