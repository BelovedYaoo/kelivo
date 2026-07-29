// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_create_upload_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AttachmentCreateUploadRequest extends AttachmentCreateUploadRequest {
  @override
  final String mutationId;
  @override
  final String attachmentId;
  @override
  final int chunkKeyEpoch;
  @override
  final int manifestKeyEpoch;
  @override
  final int manifestRevision;
  @override
  final int chunkCount;
  @override
  final int totalCiphertextBytes;

  factory _$AttachmentCreateUploadRequest([
    void Function(AttachmentCreateUploadRequestBuilder)? updates,
  ]) => (AttachmentCreateUploadRequestBuilder()..update(updates))._build();

  _$AttachmentCreateUploadRequest._({
    required this.mutationId,
    required this.attachmentId,
    required this.chunkKeyEpoch,
    required this.manifestKeyEpoch,
    required this.manifestRevision,
    required this.chunkCount,
    required this.totalCiphertextBytes,
  }) : super._();
  @override
  AttachmentCreateUploadRequest rebuild(
    void Function(AttachmentCreateUploadRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AttachmentCreateUploadRequestBuilder toBuilder() =>
      AttachmentCreateUploadRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AttachmentCreateUploadRequest &&
        mutationId == other.mutationId &&
        attachmentId == other.attachmentId &&
        chunkKeyEpoch == other.chunkKeyEpoch &&
        manifestKeyEpoch == other.manifestKeyEpoch &&
        manifestRevision == other.manifestRevision &&
        chunkCount == other.chunkCount &&
        totalCiphertextBytes == other.totalCiphertextBytes;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, mutationId.hashCode);
    _$hash = $jc(_$hash, attachmentId.hashCode);
    _$hash = $jc(_$hash, chunkKeyEpoch.hashCode);
    _$hash = $jc(_$hash, manifestKeyEpoch.hashCode);
    _$hash = $jc(_$hash, manifestRevision.hashCode);
    _$hash = $jc(_$hash, chunkCount.hashCode);
    _$hash = $jc(_$hash, totalCiphertextBytes.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AttachmentCreateUploadRequest')
          ..add('mutationId', mutationId)
          ..add('attachmentId', attachmentId)
          ..add('chunkKeyEpoch', chunkKeyEpoch)
          ..add('manifestKeyEpoch', manifestKeyEpoch)
          ..add('manifestRevision', manifestRevision)
          ..add('chunkCount', chunkCount)
          ..add('totalCiphertextBytes', totalCiphertextBytes))
        .toString();
  }
}

class AttachmentCreateUploadRequestBuilder
    implements
        Builder<
          AttachmentCreateUploadRequest,
          AttachmentCreateUploadRequestBuilder
        > {
  _$AttachmentCreateUploadRequest? _$v;

  String? _mutationId;
  String? get mutationId => _$this._mutationId;
  set mutationId(String? mutationId) => _$this._mutationId = mutationId;

  String? _attachmentId;
  String? get attachmentId => _$this._attachmentId;
  set attachmentId(String? attachmentId) => _$this._attachmentId = attachmentId;

  int? _chunkKeyEpoch;
  int? get chunkKeyEpoch => _$this._chunkKeyEpoch;
  set chunkKeyEpoch(int? chunkKeyEpoch) =>
      _$this._chunkKeyEpoch = chunkKeyEpoch;

  int? _manifestKeyEpoch;
  int? get manifestKeyEpoch => _$this._manifestKeyEpoch;
  set manifestKeyEpoch(int? manifestKeyEpoch) =>
      _$this._manifestKeyEpoch = manifestKeyEpoch;

  int? _manifestRevision;
  int? get manifestRevision => _$this._manifestRevision;
  set manifestRevision(int? manifestRevision) =>
      _$this._manifestRevision = manifestRevision;

  int? _chunkCount;
  int? get chunkCount => _$this._chunkCount;
  set chunkCount(int? chunkCount) => _$this._chunkCount = chunkCount;

  int? _totalCiphertextBytes;
  int? get totalCiphertextBytes => _$this._totalCiphertextBytes;
  set totalCiphertextBytes(int? totalCiphertextBytes) =>
      _$this._totalCiphertextBytes = totalCiphertextBytes;

  AttachmentCreateUploadRequestBuilder() {
    AttachmentCreateUploadRequest._defaults(this);
  }

  AttachmentCreateUploadRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _mutationId = $v.mutationId;
      _attachmentId = $v.attachmentId;
      _chunkKeyEpoch = $v.chunkKeyEpoch;
      _manifestKeyEpoch = $v.manifestKeyEpoch;
      _manifestRevision = $v.manifestRevision;
      _chunkCount = $v.chunkCount;
      _totalCiphertextBytes = $v.totalCiphertextBytes;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AttachmentCreateUploadRequest other) {
    _$v = other as _$AttachmentCreateUploadRequest;
  }

  @override
  void update(void Function(AttachmentCreateUploadRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AttachmentCreateUploadRequest build() => _build();

  _$AttachmentCreateUploadRequest _build() {
    final _$result =
        _$v ??
        _$AttachmentCreateUploadRequest._(
          mutationId: BuiltValueNullFieldError.checkNotNull(
            mutationId,
            r'AttachmentCreateUploadRequest',
            'mutationId',
          ),
          attachmentId: BuiltValueNullFieldError.checkNotNull(
            attachmentId,
            r'AttachmentCreateUploadRequest',
            'attachmentId',
          ),
          chunkKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            chunkKeyEpoch,
            r'AttachmentCreateUploadRequest',
            'chunkKeyEpoch',
          ),
          manifestKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            manifestKeyEpoch,
            r'AttachmentCreateUploadRequest',
            'manifestKeyEpoch',
          ),
          manifestRevision: BuiltValueNullFieldError.checkNotNull(
            manifestRevision,
            r'AttachmentCreateUploadRequest',
            'manifestRevision',
          ),
          chunkCount: BuiltValueNullFieldError.checkNotNull(
            chunkCount,
            r'AttachmentCreateUploadRequest',
            'chunkCount',
          ),
          totalCiphertextBytes: BuiltValueNullFieldError.checkNotNull(
            totalCiphertextBytes,
            r'AttachmentCreateUploadRequest',
            'totalCiphertextBytes',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
