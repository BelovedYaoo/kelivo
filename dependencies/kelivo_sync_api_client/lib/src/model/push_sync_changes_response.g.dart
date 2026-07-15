// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_sync_changes_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PushSyncChangesResponse extends PushSyncChangesResponse {
  @override
  final SyncPushResponseData data;

  factory _$PushSyncChangesResponse([
    void Function(PushSyncChangesResponseBuilder)? updates,
  ]) => (PushSyncChangesResponseBuilder()..update(updates))._build();

  _$PushSyncChangesResponse._({required this.data}) : super._();
  @override
  PushSyncChangesResponse rebuild(
    void Function(PushSyncChangesResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  PushSyncChangesResponseBuilder toBuilder() =>
      PushSyncChangesResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PushSyncChangesResponse && data == other.data;
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
      r'PushSyncChangesResponse',
    )..add('data', data)).toString();
  }
}

class PushSyncChangesResponseBuilder
    implements
        Builder<PushSyncChangesResponse, PushSyncChangesResponseBuilder> {
  _$PushSyncChangesResponse? _$v;

  SyncPushResponseDataBuilder? _data;
  SyncPushResponseDataBuilder get data =>
      _$this._data ??= SyncPushResponseDataBuilder();
  set data(SyncPushResponseDataBuilder? data) => _$this._data = data;

  PushSyncChangesResponseBuilder() {
    PushSyncChangesResponse._defaults(this);
  }

  PushSyncChangesResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PushSyncChangesResponse other) {
    _$v = other as _$PushSyncChangesResponse;
  }

  @override
  void update(void Function(PushSyncChangesResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PushSyncChangesResponse build() => _build();

  _$PushSyncChangesResponse _build() {
    _$PushSyncChangesResponse _$result;
    try {
      _$result = _$v ?? _$PushSyncChangesResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'PushSyncChangesResponse',
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
