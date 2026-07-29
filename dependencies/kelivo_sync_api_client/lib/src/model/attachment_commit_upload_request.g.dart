// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_commit_upload_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AttachmentCommitUploadRequest extends AttachmentCommitUploadRequest {
  @override
  final String mutationId;
  @override
  final String attachmentId;
  @override
  final String uploadId;
  @override
  final int manifestKeyEpoch;
  @override
  final int manifestRevision;
  @override
  final String manifestCiphertext;
  @override
  final BuiltList<AttachmentManifestChunk> chunks;

  factory _$AttachmentCommitUploadRequest([
    void Function(AttachmentCommitUploadRequestBuilder)? updates,
  ]) => (AttachmentCommitUploadRequestBuilder()..update(updates))._build();

  _$AttachmentCommitUploadRequest._({
    required this.mutationId,
    required this.attachmentId,
    required this.uploadId,
    required this.manifestKeyEpoch,
    required this.manifestRevision,
    required this.manifestCiphertext,
    required this.chunks,
  }) : super._();
  @override
  AttachmentCommitUploadRequest rebuild(
    void Function(AttachmentCommitUploadRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AttachmentCommitUploadRequestBuilder toBuilder() =>
      AttachmentCommitUploadRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AttachmentCommitUploadRequest &&
        mutationId == other.mutationId &&
        attachmentId == other.attachmentId &&
        uploadId == other.uploadId &&
        manifestKeyEpoch == other.manifestKeyEpoch &&
        manifestRevision == other.manifestRevision &&
        manifestCiphertext == other.manifestCiphertext &&
        chunks == other.chunks;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, mutationId.hashCode);
    _$hash = $jc(_$hash, attachmentId.hashCode);
    _$hash = $jc(_$hash, uploadId.hashCode);
    _$hash = $jc(_$hash, manifestKeyEpoch.hashCode);
    _$hash = $jc(_$hash, manifestRevision.hashCode);
    _$hash = $jc(_$hash, manifestCiphertext.hashCode);
    _$hash = $jc(_$hash, chunks.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AttachmentCommitUploadRequest')
          ..add('mutationId', mutationId)
          ..add('attachmentId', attachmentId)
          ..add('uploadId', uploadId)
          ..add('manifestKeyEpoch', manifestKeyEpoch)
          ..add('manifestRevision', manifestRevision)
          ..add('manifestCiphertext', manifestCiphertext)
          ..add('chunks', chunks))
        .toString();
  }
}

class AttachmentCommitUploadRequestBuilder
    implements
        Builder<
          AttachmentCommitUploadRequest,
          AttachmentCommitUploadRequestBuilder
        > {
  _$AttachmentCommitUploadRequest? _$v;

  String? _mutationId;
  String? get mutationId => _$this._mutationId;
  set mutationId(String? mutationId) => _$this._mutationId = mutationId;

  String? _attachmentId;
  String? get attachmentId => _$this._attachmentId;
  set attachmentId(String? attachmentId) => _$this._attachmentId = attachmentId;

  String? _uploadId;
  String? get uploadId => _$this._uploadId;
  set uploadId(String? uploadId) => _$this._uploadId = uploadId;

  int? _manifestKeyEpoch;
  int? get manifestKeyEpoch => _$this._manifestKeyEpoch;
  set manifestKeyEpoch(int? manifestKeyEpoch) =>
      _$this._manifestKeyEpoch = manifestKeyEpoch;

  int? _manifestRevision;
  int? get manifestRevision => _$this._manifestRevision;
  set manifestRevision(int? manifestRevision) =>
      _$this._manifestRevision = manifestRevision;

  String? _manifestCiphertext;
  String? get manifestCiphertext => _$this._manifestCiphertext;
  set manifestCiphertext(String? manifestCiphertext) =>
      _$this._manifestCiphertext = manifestCiphertext;

  ListBuilder<AttachmentManifestChunk>? _chunks;
  ListBuilder<AttachmentManifestChunk> get chunks =>
      _$this._chunks ??= ListBuilder<AttachmentManifestChunk>();
  set chunks(ListBuilder<AttachmentManifestChunk>? chunks) =>
      _$this._chunks = chunks;

  AttachmentCommitUploadRequestBuilder() {
    AttachmentCommitUploadRequest._defaults(this);
  }

  AttachmentCommitUploadRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _mutationId = $v.mutationId;
      _attachmentId = $v.attachmentId;
      _uploadId = $v.uploadId;
      _manifestKeyEpoch = $v.manifestKeyEpoch;
      _manifestRevision = $v.manifestRevision;
      _manifestCiphertext = $v.manifestCiphertext;
      _chunks = $v.chunks.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AttachmentCommitUploadRequest other) {
    _$v = other as _$AttachmentCommitUploadRequest;
  }

  @override
  void update(void Function(AttachmentCommitUploadRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AttachmentCommitUploadRequest build() => _build();

  _$AttachmentCommitUploadRequest _build() {
    _$AttachmentCommitUploadRequest _$result;
    try {
      _$result =
          _$v ??
          _$AttachmentCommitUploadRequest._(
            mutationId: BuiltValueNullFieldError.checkNotNull(
              mutationId,
              r'AttachmentCommitUploadRequest',
              'mutationId',
            ),
            attachmentId: BuiltValueNullFieldError.checkNotNull(
              attachmentId,
              r'AttachmentCommitUploadRequest',
              'attachmentId',
            ),
            uploadId: BuiltValueNullFieldError.checkNotNull(
              uploadId,
              r'AttachmentCommitUploadRequest',
              'uploadId',
            ),
            manifestKeyEpoch: BuiltValueNullFieldError.checkNotNull(
              manifestKeyEpoch,
              r'AttachmentCommitUploadRequest',
              'manifestKeyEpoch',
            ),
            manifestRevision: BuiltValueNullFieldError.checkNotNull(
              manifestRevision,
              r'AttachmentCommitUploadRequest',
              'manifestRevision',
            ),
            manifestCiphertext: BuiltValueNullFieldError.checkNotNull(
              manifestCiphertext,
              r'AttachmentCommitUploadRequest',
              'manifestCiphertext',
            ),
            chunks: chunks.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'chunks';
        chunks.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'AttachmentCommitUploadRequest',
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
