// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'put_encrypted_attachment_chunk_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PutEncryptedAttachmentChunkResponse
    extends PutEncryptedAttachmentChunkResponse {
  @override
  final AttachmentStoredChunkData data;

  factory _$PutEncryptedAttachmentChunkResponse([
    void Function(PutEncryptedAttachmentChunkResponseBuilder)? updates,
  ]) =>
      (PutEncryptedAttachmentChunkResponseBuilder()..update(updates))._build();

  _$PutEncryptedAttachmentChunkResponse._({required this.data}) : super._();
  @override
  PutEncryptedAttachmentChunkResponse rebuild(
    void Function(PutEncryptedAttachmentChunkResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  PutEncryptedAttachmentChunkResponseBuilder toBuilder() =>
      PutEncryptedAttachmentChunkResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PutEncryptedAttachmentChunkResponse && data == other.data;
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
      r'PutEncryptedAttachmentChunkResponse',
    )..add('data', data)).toString();
  }
}

class PutEncryptedAttachmentChunkResponseBuilder
    implements
        Builder<
          PutEncryptedAttachmentChunkResponse,
          PutEncryptedAttachmentChunkResponseBuilder
        > {
  _$PutEncryptedAttachmentChunkResponse? _$v;

  AttachmentStoredChunkDataBuilder? _data;
  AttachmentStoredChunkDataBuilder get data =>
      _$this._data ??= AttachmentStoredChunkDataBuilder();
  set data(AttachmentStoredChunkDataBuilder? data) => _$this._data = data;

  PutEncryptedAttachmentChunkResponseBuilder() {
    PutEncryptedAttachmentChunkResponse._defaults(this);
  }

  PutEncryptedAttachmentChunkResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PutEncryptedAttachmentChunkResponse other) {
    _$v = other as _$PutEncryptedAttachmentChunkResponse;
  }

  @override
  void update(
    void Function(PutEncryptedAttachmentChunkResponseBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  PutEncryptedAttachmentChunkResponse build() => _build();

  _$PutEncryptedAttachmentChunkResponse _build() {
    _$PutEncryptedAttachmentChunkResponse _$result;
    try {
      _$result =
          _$v ?? _$PutEncryptedAttachmentChunkResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'PutEncryptedAttachmentChunkResponse',
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
