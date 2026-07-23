// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_encrypted_sync_records_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PushEncryptedSyncRecordsResponse
    extends PushEncryptedSyncRecordsResponse {
  @override
  final SyncPushResponseData data;

  factory _$PushEncryptedSyncRecordsResponse([
    void Function(PushEncryptedSyncRecordsResponseBuilder)? updates,
  ]) => (PushEncryptedSyncRecordsResponseBuilder()..update(updates))._build();

  _$PushEncryptedSyncRecordsResponse._({required this.data}) : super._();
  @override
  PushEncryptedSyncRecordsResponse rebuild(
    void Function(PushEncryptedSyncRecordsResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  PushEncryptedSyncRecordsResponseBuilder toBuilder() =>
      PushEncryptedSyncRecordsResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PushEncryptedSyncRecordsResponse && data == other.data;
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
      r'PushEncryptedSyncRecordsResponse',
    )..add('data', data)).toString();
  }
}

class PushEncryptedSyncRecordsResponseBuilder
    implements
        Builder<
          PushEncryptedSyncRecordsResponse,
          PushEncryptedSyncRecordsResponseBuilder
        > {
  _$PushEncryptedSyncRecordsResponse? _$v;

  SyncPushResponseDataBuilder? _data;
  SyncPushResponseDataBuilder get data =>
      _$this._data ??= SyncPushResponseDataBuilder();
  set data(SyncPushResponseDataBuilder? data) => _$this._data = data;

  PushEncryptedSyncRecordsResponseBuilder() {
    PushEncryptedSyncRecordsResponse._defaults(this);
  }

  PushEncryptedSyncRecordsResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PushEncryptedSyncRecordsResponse other) {
    _$v = other as _$PushEncryptedSyncRecordsResponse;
  }

  @override
  void update(void Function(PushEncryptedSyncRecordsResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PushEncryptedSyncRecordsResponse build() => _build();

  _$PushEncryptedSyncRecordsResponse _build() {
    _$PushEncryptedSyncRecordsResponse _$result;
    try {
      _$result =
          _$v ?? _$PushEncryptedSyncRecordsResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'PushEncryptedSyncRecordsResponse',
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
