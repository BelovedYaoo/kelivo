// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'commit_encrypted_attachment_upload_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$CommitEncryptedAttachmentUploadResponse
    extends CommitEncryptedAttachmentUploadResponse {
  @override
  final AttachmentCommittedData data;

  factory _$CommitEncryptedAttachmentUploadResponse([
    void Function(CommitEncryptedAttachmentUploadResponseBuilder)? updates,
  ]) => (CommitEncryptedAttachmentUploadResponseBuilder()..update(updates))
      ._build();

  _$CommitEncryptedAttachmentUploadResponse._({required this.data}) : super._();
  @override
  CommitEncryptedAttachmentUploadResponse rebuild(
    void Function(CommitEncryptedAttachmentUploadResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  CommitEncryptedAttachmentUploadResponseBuilder toBuilder() =>
      CommitEncryptedAttachmentUploadResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CommitEncryptedAttachmentUploadResponse &&
        data == other.data;
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
      r'CommitEncryptedAttachmentUploadResponse',
    )..add('data', data)).toString();
  }
}

class CommitEncryptedAttachmentUploadResponseBuilder
    implements
        Builder<
          CommitEncryptedAttachmentUploadResponse,
          CommitEncryptedAttachmentUploadResponseBuilder
        > {
  _$CommitEncryptedAttachmentUploadResponse? _$v;

  AttachmentCommittedDataBuilder? _data;
  AttachmentCommittedDataBuilder get data =>
      _$this._data ??= AttachmentCommittedDataBuilder();
  set data(AttachmentCommittedDataBuilder? data) => _$this._data = data;

  CommitEncryptedAttachmentUploadResponseBuilder() {
    CommitEncryptedAttachmentUploadResponse._defaults(this);
  }

  CommitEncryptedAttachmentUploadResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CommitEncryptedAttachmentUploadResponse other) {
    _$v = other as _$CommitEncryptedAttachmentUploadResponse;
  }

  @override
  void update(
    void Function(CommitEncryptedAttachmentUploadResponseBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  CommitEncryptedAttachmentUploadResponse build() => _build();

  _$CommitEncryptedAttachmentUploadResponse _build() {
    _$CommitEncryptedAttachmentUploadResponse _$result;
    try {
      _$result =
          _$v ??
          _$CommitEncryptedAttachmentUploadResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'CommitEncryptedAttachmentUploadResponse',
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
