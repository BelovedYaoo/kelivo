// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prepare_attachment_upload_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PrepareAttachmentUploadResponse
    extends PrepareAttachmentUploadResponse {
  @override
  final PrepareAttachmentUploadData data;

  factory _$PrepareAttachmentUploadResponse([
    void Function(PrepareAttachmentUploadResponseBuilder)? updates,
  ]) => (PrepareAttachmentUploadResponseBuilder()..update(updates))._build();

  _$PrepareAttachmentUploadResponse._({required this.data}) : super._();
  @override
  PrepareAttachmentUploadResponse rebuild(
    void Function(PrepareAttachmentUploadResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  PrepareAttachmentUploadResponseBuilder toBuilder() =>
      PrepareAttachmentUploadResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PrepareAttachmentUploadResponse && data == other.data;
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
      r'PrepareAttachmentUploadResponse',
    )..add('data', data)).toString();
  }
}

class PrepareAttachmentUploadResponseBuilder
    implements
        Builder<
          PrepareAttachmentUploadResponse,
          PrepareAttachmentUploadResponseBuilder
        > {
  _$PrepareAttachmentUploadResponse? _$v;

  PrepareAttachmentUploadDataBuilder? _data;
  PrepareAttachmentUploadDataBuilder get data =>
      _$this._data ??= PrepareAttachmentUploadDataBuilder();
  set data(PrepareAttachmentUploadDataBuilder? data) => _$this._data = data;

  PrepareAttachmentUploadResponseBuilder() {
    PrepareAttachmentUploadResponse._defaults(this);
  }

  PrepareAttachmentUploadResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PrepareAttachmentUploadResponse other) {
    _$v = other as _$PrepareAttachmentUploadResponse;
  }

  @override
  void update(void Function(PrepareAttachmentUploadResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PrepareAttachmentUploadResponse build() => _build();

  _$PrepareAttachmentUploadResponse _build() {
    _$PrepareAttachmentUploadResponse _$result;
    try {
      _$result = _$v ?? _$PrepareAttachmentUploadResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'PrepareAttachmentUploadResponse',
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
