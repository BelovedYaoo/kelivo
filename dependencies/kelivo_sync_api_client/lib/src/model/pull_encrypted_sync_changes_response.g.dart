// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pull_encrypted_sync_changes_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PullEncryptedSyncChangesResponse
    extends PullEncryptedSyncChangesResponse {
  @override
  final SyncPullResponseData data;

  factory _$PullEncryptedSyncChangesResponse([
    void Function(PullEncryptedSyncChangesResponseBuilder)? updates,
  ]) => (PullEncryptedSyncChangesResponseBuilder()..update(updates))._build();

  _$PullEncryptedSyncChangesResponse._({required this.data}) : super._();
  @override
  PullEncryptedSyncChangesResponse rebuild(
    void Function(PullEncryptedSyncChangesResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  PullEncryptedSyncChangesResponseBuilder toBuilder() =>
      PullEncryptedSyncChangesResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PullEncryptedSyncChangesResponse && data == other.data;
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
      r'PullEncryptedSyncChangesResponse',
    )..add('data', data)).toString();
  }
}

class PullEncryptedSyncChangesResponseBuilder
    implements
        Builder<
          PullEncryptedSyncChangesResponse,
          PullEncryptedSyncChangesResponseBuilder
        > {
  _$PullEncryptedSyncChangesResponse? _$v;

  SyncPullResponseDataBuilder? _data;
  SyncPullResponseDataBuilder get data =>
      _$this._data ??= SyncPullResponseDataBuilder();
  set data(SyncPullResponseDataBuilder? data) => _$this._data = data;

  PullEncryptedSyncChangesResponseBuilder() {
    PullEncryptedSyncChangesResponse._defaults(this);
  }

  PullEncryptedSyncChangesResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PullEncryptedSyncChangesResponse other) {
    _$v = other as _$PullEncryptedSyncChangesResponse;
  }

  @override
  void update(void Function(PullEncryptedSyncChangesResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PullEncryptedSyncChangesResponse build() => _build();

  _$PullEncryptedSyncChangesResponse _build() {
    _$PullEncryptedSyncChangesResponse _$result;
    try {
      _$result =
          _$v ?? _$PullEncryptedSyncChangesResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'PullEncryptedSyncChangesResponse',
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
