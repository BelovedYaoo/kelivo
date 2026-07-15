// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'complete_attachment_upload_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$CompleteAttachmentUploadData extends CompleteAttachmentUploadData {
  @override
  final AttachmentInfo attachment;

  factory _$CompleteAttachmentUploadData([
    void Function(CompleteAttachmentUploadDataBuilder)? updates,
  ]) => (CompleteAttachmentUploadDataBuilder()..update(updates))._build();

  _$CompleteAttachmentUploadData._({required this.attachment}) : super._();
  @override
  CompleteAttachmentUploadData rebuild(
    void Function(CompleteAttachmentUploadDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  CompleteAttachmentUploadDataBuilder toBuilder() =>
      CompleteAttachmentUploadDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CompleteAttachmentUploadData &&
        attachment == other.attachment;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, attachment.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'CompleteAttachmentUploadData',
    )..add('attachment', attachment)).toString();
  }
}

class CompleteAttachmentUploadDataBuilder
    implements
        Builder<
          CompleteAttachmentUploadData,
          CompleteAttachmentUploadDataBuilder
        > {
  _$CompleteAttachmentUploadData? _$v;

  AttachmentInfoBuilder? _attachment;
  AttachmentInfoBuilder get attachment =>
      _$this._attachment ??= AttachmentInfoBuilder();
  set attachment(AttachmentInfoBuilder? attachment) =>
      _$this._attachment = attachment;

  CompleteAttachmentUploadDataBuilder() {
    CompleteAttachmentUploadData._defaults(this);
  }

  CompleteAttachmentUploadDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _attachment = $v.attachment.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CompleteAttachmentUploadData other) {
    _$v = other as _$CompleteAttachmentUploadData;
  }

  @override
  void update(void Function(CompleteAttachmentUploadDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  CompleteAttachmentUploadData build() => _build();

  _$CompleteAttachmentUploadData _build() {
    _$CompleteAttachmentUploadData _$result;
    try {
      _$result =
          _$v ??
          _$CompleteAttachmentUploadData._(attachment: attachment.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'attachment';
        attachment.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'CompleteAttachmentUploadData',
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
