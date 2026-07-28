// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_encrypted_attachment_upload_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$CreateEncryptedAttachmentUploadResponse
    extends CreateEncryptedAttachmentUploadResponse {
  @override
  final AttachmentUploadData data;

  factory _$CreateEncryptedAttachmentUploadResponse([
    void Function(CreateEncryptedAttachmentUploadResponseBuilder)? updates,
  ]) => (CreateEncryptedAttachmentUploadResponseBuilder()..update(updates))
      ._build();

  _$CreateEncryptedAttachmentUploadResponse._({required this.data}) : super._();
  @override
  CreateEncryptedAttachmentUploadResponse rebuild(
    void Function(CreateEncryptedAttachmentUploadResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  CreateEncryptedAttachmentUploadResponseBuilder toBuilder() =>
      CreateEncryptedAttachmentUploadResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CreateEncryptedAttachmentUploadResponse &&
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
      r'CreateEncryptedAttachmentUploadResponse',
    )..add('data', data)).toString();
  }
}

class CreateEncryptedAttachmentUploadResponseBuilder
    implements
        Builder<
          CreateEncryptedAttachmentUploadResponse,
          CreateEncryptedAttachmentUploadResponseBuilder
        > {
  _$CreateEncryptedAttachmentUploadResponse? _$v;

  AttachmentUploadDataBuilder? _data;
  AttachmentUploadDataBuilder get data =>
      _$this._data ??= AttachmentUploadDataBuilder();
  set data(AttachmentUploadDataBuilder? data) => _$this._data = data;

  CreateEncryptedAttachmentUploadResponseBuilder() {
    CreateEncryptedAttachmentUploadResponse._defaults(this);
  }

  CreateEncryptedAttachmentUploadResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CreateEncryptedAttachmentUploadResponse other) {
    _$v = other as _$CreateEncryptedAttachmentUploadResponse;
  }

  @override
  void update(
    void Function(CreateEncryptedAttachmentUploadResponseBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  CreateEncryptedAttachmentUploadResponse build() => _build();

  _$CreateEncryptedAttachmentUploadResponse _build() {
    _$CreateEncryptedAttachmentUploadResponse _$result;
    try {
      _$result =
          _$v ??
          _$CreateEncryptedAttachmentUploadResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'CreateEncryptedAttachmentUploadResponse',
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
