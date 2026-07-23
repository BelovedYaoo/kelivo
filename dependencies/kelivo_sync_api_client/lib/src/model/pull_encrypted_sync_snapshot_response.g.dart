// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pull_encrypted_sync_snapshot_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PullEncryptedSyncSnapshotResponse
    extends PullEncryptedSyncSnapshotResponse {
  @override
  final SyncSnapshotResponseData data;

  factory _$PullEncryptedSyncSnapshotResponse([
    void Function(PullEncryptedSyncSnapshotResponseBuilder)? updates,
  ]) => (PullEncryptedSyncSnapshotResponseBuilder()..update(updates))._build();

  _$PullEncryptedSyncSnapshotResponse._({required this.data}) : super._();
  @override
  PullEncryptedSyncSnapshotResponse rebuild(
    void Function(PullEncryptedSyncSnapshotResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  PullEncryptedSyncSnapshotResponseBuilder toBuilder() =>
      PullEncryptedSyncSnapshotResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PullEncryptedSyncSnapshotResponse && data == other.data;
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
      r'PullEncryptedSyncSnapshotResponse',
    )..add('data', data)).toString();
  }
}

class PullEncryptedSyncSnapshotResponseBuilder
    implements
        Builder<
          PullEncryptedSyncSnapshotResponse,
          PullEncryptedSyncSnapshotResponseBuilder
        > {
  _$PullEncryptedSyncSnapshotResponse? _$v;

  SyncSnapshotResponseDataBuilder? _data;
  SyncSnapshotResponseDataBuilder get data =>
      _$this._data ??= SyncSnapshotResponseDataBuilder();
  set data(SyncSnapshotResponseDataBuilder? data) => _$this._data = data;

  PullEncryptedSyncSnapshotResponseBuilder() {
    PullEncryptedSyncSnapshotResponse._defaults(this);
  }

  PullEncryptedSyncSnapshotResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PullEncryptedSyncSnapshotResponse other) {
    _$v = other as _$PullEncryptedSyncSnapshotResponse;
  }

  @override
  void update(
    void Function(PullEncryptedSyncSnapshotResponseBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  PullEncryptedSyncSnapshotResponse build() => _build();

  _$PullEncryptedSyncSnapshotResponse _build() {
    _$PullEncryptedSyncSnapshotResponse _$result;
    try {
      _$result =
          _$v ?? _$PullEncryptedSyncSnapshotResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'PullEncryptedSyncSnapshotResponse',
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
