// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_get_chunk_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AttachmentGetChunkRequest extends AttachmentGetChunkRequest {
  @override
  final String attachmentId;
  @override
  final String uploadId;
  @override
  final int chunkKeyEpoch;
  @override
  final int chunkIndex;

  factory _$AttachmentGetChunkRequest([
    void Function(AttachmentGetChunkRequestBuilder)? updates,
  ]) => (AttachmentGetChunkRequestBuilder()..update(updates))._build();

  _$AttachmentGetChunkRequest._({
    required this.attachmentId,
    required this.uploadId,
    required this.chunkKeyEpoch,
    required this.chunkIndex,
  }) : super._();
  @override
  AttachmentGetChunkRequest rebuild(
    void Function(AttachmentGetChunkRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AttachmentGetChunkRequestBuilder toBuilder() =>
      AttachmentGetChunkRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AttachmentGetChunkRequest &&
        attachmentId == other.attachmentId &&
        uploadId == other.uploadId &&
        chunkKeyEpoch == other.chunkKeyEpoch &&
        chunkIndex == other.chunkIndex;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, attachmentId.hashCode);
    _$hash = $jc(_$hash, uploadId.hashCode);
    _$hash = $jc(_$hash, chunkKeyEpoch.hashCode);
    _$hash = $jc(_$hash, chunkIndex.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AttachmentGetChunkRequest')
          ..add('attachmentId', attachmentId)
          ..add('uploadId', uploadId)
          ..add('chunkKeyEpoch', chunkKeyEpoch)
          ..add('chunkIndex', chunkIndex))
        .toString();
  }
}

class AttachmentGetChunkRequestBuilder
    implements
        Builder<AttachmentGetChunkRequest, AttachmentGetChunkRequestBuilder> {
  _$AttachmentGetChunkRequest? _$v;

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

  AttachmentGetChunkRequestBuilder() {
    AttachmentGetChunkRequest._defaults(this);
  }

  AttachmentGetChunkRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _attachmentId = $v.attachmentId;
      _uploadId = $v.uploadId;
      _chunkKeyEpoch = $v.chunkKeyEpoch;
      _chunkIndex = $v.chunkIndex;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AttachmentGetChunkRequest other) {
    _$v = other as _$AttachmentGetChunkRequest;
  }

  @override
  void update(void Function(AttachmentGetChunkRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AttachmentGetChunkRequest build() => _build();

  _$AttachmentGetChunkRequest _build() {
    final _$result =
        _$v ??
        _$AttachmentGetChunkRequest._(
          attachmentId: BuiltValueNullFieldError.checkNotNull(
            attachmentId,
            r'AttachmentGetChunkRequest',
            'attachmentId',
          ),
          uploadId: BuiltValueNullFieldError.checkNotNull(
            uploadId,
            r'AttachmentGetChunkRequest',
            'uploadId',
          ),
          chunkKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            chunkKeyEpoch,
            r'AttachmentGetChunkRequest',
            'chunkKeyEpoch',
          ),
          chunkIndex: BuiltValueNullFieldError.checkNotNull(
            chunkIndex,
            r'AttachmentGetChunkRequest',
            'chunkIndex',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
