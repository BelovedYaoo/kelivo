// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'complete_attachment_upload_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$CompleteAttachmentUploadRequest
    extends CompleteAttachmentUploadRequest {
  @override
  final String attachmentId;
  @override
  final String blobId;
  @override
  final String entityType;
  @override
  final String entityId;
  @override
  final String fileName;
  @override
  final String mimeType;
  @override
  final String etag;

  factory _$CompleteAttachmentUploadRequest([
    void Function(CompleteAttachmentUploadRequestBuilder)? updates,
  ]) => (CompleteAttachmentUploadRequestBuilder()..update(updates))._build();

  _$CompleteAttachmentUploadRequest._({
    required this.attachmentId,
    required this.blobId,
    required this.entityType,
    required this.entityId,
    required this.fileName,
    required this.mimeType,
    required this.etag,
  }) : super._();
  @override
  CompleteAttachmentUploadRequest rebuild(
    void Function(CompleteAttachmentUploadRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  CompleteAttachmentUploadRequestBuilder toBuilder() =>
      CompleteAttachmentUploadRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CompleteAttachmentUploadRequest &&
        attachmentId == other.attachmentId &&
        blobId == other.blobId &&
        entityType == other.entityType &&
        entityId == other.entityId &&
        fileName == other.fileName &&
        mimeType == other.mimeType &&
        etag == other.etag;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, attachmentId.hashCode);
    _$hash = $jc(_$hash, blobId.hashCode);
    _$hash = $jc(_$hash, entityType.hashCode);
    _$hash = $jc(_$hash, entityId.hashCode);
    _$hash = $jc(_$hash, fileName.hashCode);
    _$hash = $jc(_$hash, mimeType.hashCode);
    _$hash = $jc(_$hash, etag.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'CompleteAttachmentUploadRequest')
          ..add('attachmentId', attachmentId)
          ..add('blobId', blobId)
          ..add('entityType', entityType)
          ..add('entityId', entityId)
          ..add('fileName', fileName)
          ..add('mimeType', mimeType)
          ..add('etag', etag))
        .toString();
  }
}

class CompleteAttachmentUploadRequestBuilder
    implements
        Builder<
          CompleteAttachmentUploadRequest,
          CompleteAttachmentUploadRequestBuilder
        > {
  _$CompleteAttachmentUploadRequest? _$v;

  String? _attachmentId;
  String? get attachmentId => _$this._attachmentId;
  set attachmentId(String? attachmentId) => _$this._attachmentId = attachmentId;

  String? _blobId;
  String? get blobId => _$this._blobId;
  set blobId(String? blobId) => _$this._blobId = blobId;

  String? _entityType;
  String? get entityType => _$this._entityType;
  set entityType(String? entityType) => _$this._entityType = entityType;

  String? _entityId;
  String? get entityId => _$this._entityId;
  set entityId(String? entityId) => _$this._entityId = entityId;

  String? _fileName;
  String? get fileName => _$this._fileName;
  set fileName(String? fileName) => _$this._fileName = fileName;

  String? _mimeType;
  String? get mimeType => _$this._mimeType;
  set mimeType(String? mimeType) => _$this._mimeType = mimeType;

  String? _etag;
  String? get etag => _$this._etag;
  set etag(String? etag) => _$this._etag = etag;

  CompleteAttachmentUploadRequestBuilder() {
    CompleteAttachmentUploadRequest._defaults(this);
  }

  CompleteAttachmentUploadRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _attachmentId = $v.attachmentId;
      _blobId = $v.blobId;
      _entityType = $v.entityType;
      _entityId = $v.entityId;
      _fileName = $v.fileName;
      _mimeType = $v.mimeType;
      _etag = $v.etag;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CompleteAttachmentUploadRequest other) {
    _$v = other as _$CompleteAttachmentUploadRequest;
  }

  @override
  void update(void Function(CompleteAttachmentUploadRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  CompleteAttachmentUploadRequest build() => _build();

  _$CompleteAttachmentUploadRequest _build() {
    final _$result =
        _$v ??
        _$CompleteAttachmentUploadRequest._(
          attachmentId: BuiltValueNullFieldError.checkNotNull(
            attachmentId,
            r'CompleteAttachmentUploadRequest',
            'attachmentId',
          ),
          blobId: BuiltValueNullFieldError.checkNotNull(
            blobId,
            r'CompleteAttachmentUploadRequest',
            'blobId',
          ),
          entityType: BuiltValueNullFieldError.checkNotNull(
            entityType,
            r'CompleteAttachmentUploadRequest',
            'entityType',
          ),
          entityId: BuiltValueNullFieldError.checkNotNull(
            entityId,
            r'CompleteAttachmentUploadRequest',
            'entityId',
          ),
          fileName: BuiltValueNullFieldError.checkNotNull(
            fileName,
            r'CompleteAttachmentUploadRequest',
            'fileName',
          ),
          mimeType: BuiltValueNullFieldError.checkNotNull(
            mimeType,
            r'CompleteAttachmentUploadRequest',
            'mimeType',
          ),
          etag: BuiltValueNullFieldError.checkNotNull(
            etag,
            r'CompleteAttachmentUploadRequest',
            'etag',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
