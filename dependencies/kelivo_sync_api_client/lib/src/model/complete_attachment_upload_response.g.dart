// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'complete_attachment_upload_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$CompleteAttachmentUploadResponse
    extends CompleteAttachmentUploadResponse {
  @override
  final CompleteAttachmentUploadData data;

  factory _$CompleteAttachmentUploadResponse([
    void Function(CompleteAttachmentUploadResponseBuilder)? updates,
  ]) => (CompleteAttachmentUploadResponseBuilder()..update(updates))._build();

  _$CompleteAttachmentUploadResponse._({required this.data}) : super._();
  @override
  CompleteAttachmentUploadResponse rebuild(
    void Function(CompleteAttachmentUploadResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  CompleteAttachmentUploadResponseBuilder toBuilder() =>
      CompleteAttachmentUploadResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CompleteAttachmentUploadResponse && data == other.data;
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
      r'CompleteAttachmentUploadResponse',
    )..add('data', data)).toString();
  }
}

class CompleteAttachmentUploadResponseBuilder
    implements
        Builder<
          CompleteAttachmentUploadResponse,
          CompleteAttachmentUploadResponseBuilder
        > {
  _$CompleteAttachmentUploadResponse? _$v;

  CompleteAttachmentUploadDataBuilder? _data;
  CompleteAttachmentUploadDataBuilder get data =>
      _$this._data ??= CompleteAttachmentUploadDataBuilder();
  set data(CompleteAttachmentUploadDataBuilder? data) => _$this._data = data;

  CompleteAttachmentUploadResponseBuilder() {
    CompleteAttachmentUploadResponse._defaults(this);
  }

  CompleteAttachmentUploadResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CompleteAttachmentUploadResponse other) {
    _$v = other as _$CompleteAttachmentUploadResponse;
  }

  @override
  void update(void Function(CompleteAttachmentUploadResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  CompleteAttachmentUploadResponse build() => _build();

  _$CompleteAttachmentUploadResponse _build() {
    _$CompleteAttachmentUploadResponse _$result;
    try {
      _$result =
          _$v ?? _$CompleteAttachmentUploadResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'CompleteAttachmentUploadResponse',
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
