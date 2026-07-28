// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_encrypted_attachment_chunk_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$GetEncryptedAttachmentChunkResponse
    extends GetEncryptedAttachmentChunkResponse {
  @override
  final AttachmentChunkData data;

  factory _$GetEncryptedAttachmentChunkResponse([
    void Function(GetEncryptedAttachmentChunkResponseBuilder)? updates,
  ]) =>
      (GetEncryptedAttachmentChunkResponseBuilder()..update(updates))._build();

  _$GetEncryptedAttachmentChunkResponse._({required this.data}) : super._();
  @override
  GetEncryptedAttachmentChunkResponse rebuild(
    void Function(GetEncryptedAttachmentChunkResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  GetEncryptedAttachmentChunkResponseBuilder toBuilder() =>
      GetEncryptedAttachmentChunkResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GetEncryptedAttachmentChunkResponse && data == other.data;
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
      r'GetEncryptedAttachmentChunkResponse',
    )..add('data', data)).toString();
  }
}

class GetEncryptedAttachmentChunkResponseBuilder
    implements
        Builder<
          GetEncryptedAttachmentChunkResponse,
          GetEncryptedAttachmentChunkResponseBuilder
        > {
  _$GetEncryptedAttachmentChunkResponse? _$v;

  AttachmentChunkDataBuilder? _data;
  AttachmentChunkDataBuilder get data =>
      _$this._data ??= AttachmentChunkDataBuilder();
  set data(AttachmentChunkDataBuilder? data) => _$this._data = data;

  GetEncryptedAttachmentChunkResponseBuilder() {
    GetEncryptedAttachmentChunkResponse._defaults(this);
  }

  GetEncryptedAttachmentChunkResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GetEncryptedAttachmentChunkResponse other) {
    _$v = other as _$GetEncryptedAttachmentChunkResponse;
  }

  @override
  void update(
    void Function(GetEncryptedAttachmentChunkResponseBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  GetEncryptedAttachmentChunkResponse build() => _build();

  _$GetEncryptedAttachmentChunkResponse _build() {
    _$GetEncryptedAttachmentChunkResponse _$result;
    try {
      _$result =
          _$v ?? _$GetEncryptedAttachmentChunkResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'GetEncryptedAttachmentChunkResponse',
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
