// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_put_chunk_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AttachmentPutChunkRequest extends AttachmentPutChunkRequest {
  @override
  final String mutationId;
  @override
  final String attachmentId;
  @override
  final String uploadId;
  @override
  final int chunkKeyEpoch;
  @override
  final int chunkIndex;
  @override
  final String ciphertext;

  factory _$AttachmentPutChunkRequest([
    void Function(AttachmentPutChunkRequestBuilder)? updates,
  ]) => (AttachmentPutChunkRequestBuilder()..update(updates))._build();

  _$AttachmentPutChunkRequest._({
    required this.mutationId,
    required this.attachmentId,
    required this.uploadId,
    required this.chunkKeyEpoch,
    required this.chunkIndex,
    required this.ciphertext,
  }) : super._();
  @override
  AttachmentPutChunkRequest rebuild(
    void Function(AttachmentPutChunkRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AttachmentPutChunkRequestBuilder toBuilder() =>
      AttachmentPutChunkRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AttachmentPutChunkRequest &&
        mutationId == other.mutationId &&
        attachmentId == other.attachmentId &&
        uploadId == other.uploadId &&
        chunkKeyEpoch == other.chunkKeyEpoch &&
        chunkIndex == other.chunkIndex &&
        ciphertext == other.ciphertext;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, mutationId.hashCode);
    _$hash = $jc(_$hash, attachmentId.hashCode);
    _$hash = $jc(_$hash, uploadId.hashCode);
    _$hash = $jc(_$hash, chunkKeyEpoch.hashCode);
    _$hash = $jc(_$hash, chunkIndex.hashCode);
    _$hash = $jc(_$hash, ciphertext.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AttachmentPutChunkRequest')
          ..add('mutationId', mutationId)
          ..add('attachmentId', attachmentId)
          ..add('uploadId', uploadId)
          ..add('chunkKeyEpoch', chunkKeyEpoch)
          ..add('chunkIndex', chunkIndex)
          ..add('ciphertext', ciphertext))
        .toString();
  }
}

class AttachmentPutChunkRequestBuilder
    implements
        Builder<AttachmentPutChunkRequest, AttachmentPutChunkRequestBuilder> {
  _$AttachmentPutChunkRequest? _$v;

  String? _mutationId;
  String? get mutationId => _$this._mutationId;
  set mutationId(String? mutationId) => _$this._mutationId = mutationId;

  String? _attachmentId;
  String? get attachmentId => _$this._attachmentId;
  set attachmentId(String? attachmentId) => _$this._attachmentId = attachmentId;

  String? _uploadId;
  String? get uploadId => _$this._uploadId;
  set uploadId(String? uploadId) => _$this._uploadId = uploadId;

  int? _chunkKeyEpoch;
  int? get chunkKeyEpoch => _$this._chunkKeyEpoch;
  set chunkKeyEpoch(int? chunkKeyEpoch) =>
      _$this._chunkKeyEpoch = chunkKeyEpoch;

  int? _chunkIndex;
  int? get chunkIndex => _$this._chunkIndex;
  set chunkIndex(int? chunkIndex) => _$this._chunkIndex = chunkIndex;

  String? _ciphertext;
  String? get ciphertext => _$this._ciphertext;
  set ciphertext(String? ciphertext) => _$this._ciphertext = ciphertext;

  AttachmentPutChunkRequestBuilder() {
    AttachmentPutChunkRequest._defaults(this);
  }

  AttachmentPutChunkRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _mutationId = $v.mutationId;
      _attachmentId = $v.attachmentId;
      _uploadId = $v.uploadId;
      _chunkKeyEpoch = $v.chunkKeyEpoch;
      _chunkIndex = $v.chunkIndex;
      _ciphertext = $v.ciphertext;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AttachmentPutChunkRequest other) {
    _$v = other as _$AttachmentPutChunkRequest;
  }

  @override
  void update(void Function(AttachmentPutChunkRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AttachmentPutChunkRequest build() => _build();

  _$AttachmentPutChunkRequest _build() {
    final _$result =
        _$v ??
        _$AttachmentPutChunkRequest._(
          mutationId: BuiltValueNullFieldError.checkNotNull(
            mutationId,
            r'AttachmentPutChunkRequest',
            'mutationId',
          ),
          attachmentId: BuiltValueNullFieldError.checkNotNull(
            attachmentId,
            r'AttachmentPutChunkRequest',
            'attachmentId',
          ),
          uploadId: BuiltValueNullFieldError.checkNotNull(
            uploadId,
            r'AttachmentPutChunkRequest',
            'uploadId',
          ),
          chunkKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            chunkKeyEpoch,
            r'AttachmentPutChunkRequest',
            'chunkKeyEpoch',
          ),
          chunkIndex: BuiltValueNullFieldError.checkNotNull(
            chunkIndex,
            r'AttachmentPutChunkRequest',
            'chunkIndex',
          ),
          ciphertext: BuiltValueNullFieldError.checkNotNull(
            ciphertext,
            r'AttachmentPutChunkRequest',
            'ciphertext',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
