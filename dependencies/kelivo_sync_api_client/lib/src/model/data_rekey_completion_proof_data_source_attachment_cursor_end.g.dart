// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_completion_proof_data_source_attachment_cursor_end.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DataRekeyCompletionProofDataSourceAttachmentCursorEnd
    extends DataRekeyCompletionProofDataSourceAttachmentCursorEnd {
  @override
  final String attachmentId;
  @override
  final String uploadId;

  factory _$DataRekeyCompletionProofDataSourceAttachmentCursorEnd([
    void Function(DataRekeyCompletionProofDataSourceAttachmentCursorEndBuilder)?
    updates,
  ]) =>
      (DataRekeyCompletionProofDataSourceAttachmentCursorEndBuilder()
            ..update(updates))
          ._build();

  _$DataRekeyCompletionProofDataSourceAttachmentCursorEnd._({
    required this.attachmentId,
    required this.uploadId,
  }) : super._();
  @override
  DataRekeyCompletionProofDataSourceAttachmentCursorEnd rebuild(
    void Function(DataRekeyCompletionProofDataSourceAttachmentCursorEndBuilder)
    updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeyCompletionProofDataSourceAttachmentCursorEndBuilder toBuilder() =>
      DataRekeyCompletionProofDataSourceAttachmentCursorEndBuilder()
        ..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeyCompletionProofDataSourceAttachmentCursorEnd &&
        attachmentId == other.attachmentId &&
        uploadId == other.uploadId;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, attachmentId.hashCode);
    _$hash = $jc(_$hash, uploadId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
            r'DataRekeyCompletionProofDataSourceAttachmentCursorEnd',
          )
          ..add('attachmentId', attachmentId)
          ..add('uploadId', uploadId))
        .toString();
  }
}

class DataRekeyCompletionProofDataSourceAttachmentCursorEndBuilder
    implements
        Builder<
          DataRekeyCompletionProofDataSourceAttachmentCursorEnd,
          DataRekeyCompletionProofDataSourceAttachmentCursorEndBuilder
        > {
  _$DataRekeyCompletionProofDataSourceAttachmentCursorEnd? _$v;

  String? _attachmentId;
  String? get attachmentId => _$this._attachmentId;
  set attachmentId(String? attachmentId) => _$this._attachmentId = attachmentId;

  String? _uploadId;
  String? get uploadId => _$this._uploadId;
  set uploadId(String? uploadId) => _$this._uploadId = uploadId;

  DataRekeyCompletionProofDataSourceAttachmentCursorEndBuilder() {
    DataRekeyCompletionProofDataSourceAttachmentCursorEnd._defaults(this);
  }

  DataRekeyCompletionProofDataSourceAttachmentCursorEndBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _attachmentId = $v.attachmentId;
      _uploadId = $v.uploadId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeyCompletionProofDataSourceAttachmentCursorEnd other) {
    _$v = other as _$DataRekeyCompletionProofDataSourceAttachmentCursorEnd;
  }

  @override
  void update(
    void Function(DataRekeyCompletionProofDataSourceAttachmentCursorEndBuilder)?
    updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeyCompletionProofDataSourceAttachmentCursorEnd build() => _build();

  _$DataRekeyCompletionProofDataSourceAttachmentCursorEnd _build() {
    final _$result =
        _$v ??
        _$DataRekeyCompletionProofDataSourceAttachmentCursorEnd._(
          attachmentId: BuiltValueNullFieldError.checkNotNull(
            attachmentId,
            r'DataRekeyCompletionProofDataSourceAttachmentCursorEnd',
            'attachmentId',
          ),
          uploadId: BuiltValueNullFieldError.checkNotNull(
            uploadId,
            r'DataRekeyCompletionProofDataSourceAttachmentCursorEnd',
            'uploadId',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
