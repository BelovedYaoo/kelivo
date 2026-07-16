// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resolve_sync_conflict_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ResolveSyncConflictResponse extends ResolveSyncConflictResponse {
  @override
  final ResolveSyncConflictResponseData data;

  factory _$ResolveSyncConflictResponse([
    void Function(ResolveSyncConflictResponseBuilder)? updates,
  ]) => (ResolveSyncConflictResponseBuilder()..update(updates))._build();

  _$ResolveSyncConflictResponse._({required this.data}) : super._();
  @override
  ResolveSyncConflictResponse rebuild(
    void Function(ResolveSyncConflictResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ResolveSyncConflictResponseBuilder toBuilder() =>
      ResolveSyncConflictResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ResolveSyncConflictResponse && data == other.data;
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
      r'ResolveSyncConflictResponse',
    )..add('data', data)).toString();
  }
}

class ResolveSyncConflictResponseBuilder
    implements
        Builder<
          ResolveSyncConflictResponse,
          ResolveSyncConflictResponseBuilder
        > {
  _$ResolveSyncConflictResponse? _$v;

  ResolveSyncConflictResponseDataBuilder? _data;
  ResolveSyncConflictResponseDataBuilder get data =>
      _$this._data ??= ResolveSyncConflictResponseDataBuilder();
  set data(ResolveSyncConflictResponseDataBuilder? data) => _$this._data = data;

  ResolveSyncConflictResponseBuilder() {
    ResolveSyncConflictResponse._defaults(this);
  }

  ResolveSyncConflictResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ResolveSyncConflictResponse other) {
    _$v = other as _$ResolveSyncConflictResponse;
  }

  @override
  void update(void Function(ResolveSyncConflictResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ResolveSyncConflictResponse build() => _build();

  _$ResolveSyncConflictResponse _build() {
    _$ResolveSyncConflictResponse _$result;
    try {
      _$result = _$v ?? _$ResolveSyncConflictResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ResolveSyncConflictResponse',
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
