// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_encrypted_attachment_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DeleteEncryptedAttachmentResponse
    extends DeleteEncryptedAttachmentResponse {
  @override
  final AttachmentDeletedData data;

  factory _$DeleteEncryptedAttachmentResponse([
    void Function(DeleteEncryptedAttachmentResponseBuilder)? updates,
  ]) => (DeleteEncryptedAttachmentResponseBuilder()..update(updates))._build();

  _$DeleteEncryptedAttachmentResponse._({required this.data}) : super._();
  @override
  DeleteEncryptedAttachmentResponse rebuild(
    void Function(DeleteEncryptedAttachmentResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DeleteEncryptedAttachmentResponseBuilder toBuilder() =>
      DeleteEncryptedAttachmentResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DeleteEncryptedAttachmentResponse && data == other.data;
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
      r'DeleteEncryptedAttachmentResponse',
    )..add('data', data)).toString();
  }
}

class DeleteEncryptedAttachmentResponseBuilder
    implements
        Builder<
          DeleteEncryptedAttachmentResponse,
          DeleteEncryptedAttachmentResponseBuilder
        > {
  _$DeleteEncryptedAttachmentResponse? _$v;

  AttachmentDeletedDataBuilder? _data;
  AttachmentDeletedDataBuilder get data =>
      _$this._data ??= AttachmentDeletedDataBuilder();
  set data(AttachmentDeletedDataBuilder? data) => _$this._data = data;

  DeleteEncryptedAttachmentResponseBuilder() {
    DeleteEncryptedAttachmentResponse._defaults(this);
  }

  DeleteEncryptedAttachmentResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DeleteEncryptedAttachmentResponse other) {
    _$v = other as _$DeleteEncryptedAttachmentResponse;
  }

  @override
  void update(
    void Function(DeleteEncryptedAttachmentResponseBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  DeleteEncryptedAttachmentResponse build() => _build();

  _$DeleteEncryptedAttachmentResponse _build() {
    _$DeleteEncryptedAttachmentResponse _$result;
    try {
      _$result =
          _$v ?? _$DeleteEncryptedAttachmentResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'DeleteEncryptedAttachmentResponse',
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
