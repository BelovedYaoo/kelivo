// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_get_manifest_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AttachmentGetManifestRequest extends AttachmentGetManifestRequest {
  @override
  final String attachmentId;
  @override
  final String uploadId;
  @override
  final int manifestKeyEpoch;
  @override
  final int manifestRevision;

  factory _$AttachmentGetManifestRequest([
    void Function(AttachmentGetManifestRequestBuilder)? updates,
  ]) => (AttachmentGetManifestRequestBuilder()..update(updates))._build();

  _$AttachmentGetManifestRequest._({
    required this.attachmentId,
    required this.uploadId,
    required this.manifestKeyEpoch,
    required this.manifestRevision,
  }) : super._();
  @override
  AttachmentGetManifestRequest rebuild(
    void Function(AttachmentGetManifestRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AttachmentGetManifestRequestBuilder toBuilder() =>
      AttachmentGetManifestRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AttachmentGetManifestRequest &&
        attachmentId == other.attachmentId &&
        uploadId == other.uploadId &&
        manifestKeyEpoch == other.manifestKeyEpoch &&
        manifestRevision == other.manifestRevision;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, attachmentId.hashCode);
    _$hash = $jc(_$hash, uploadId.hashCode);
    _$hash = $jc(_$hash, manifestKeyEpoch.hashCode);
    _$hash = $jc(_$hash, manifestRevision.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AttachmentGetManifestRequest')
          ..add('attachmentId', attachmentId)
          ..add('uploadId', uploadId)
          ..add('manifestKeyEpoch', manifestKeyEpoch)
          ..add('manifestRevision', manifestRevision))
        .toString();
  }
}

class AttachmentGetManifestRequestBuilder
    implements
        Builder<
          AttachmentGetManifestRequest,
          AttachmentGetManifestRequestBuilder
        > {
  _$AttachmentGetManifestRequest? _$v;

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

  AttachmentGetManifestRequestBuilder() {
    AttachmentGetManifestRequest._defaults(this);
  }

  AttachmentGetManifestRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _attachmentId = $v.attachmentId;
      _uploadId = $v.uploadId;
      _manifestKeyEpoch = $v.manifestKeyEpoch;
      _manifestRevision = $v.manifestRevision;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AttachmentGetManifestRequest other) {
    _$v = other as _$AttachmentGetManifestRequest;
  }

  @override
  void update(void Function(AttachmentGetManifestRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AttachmentGetManifestRequest build() => _build();

  _$AttachmentGetManifestRequest _build() {
    final _$result =
        _$v ??
        _$AttachmentGetManifestRequest._(
          attachmentId: BuiltValueNullFieldError.checkNotNull(
            attachmentId,
            r'AttachmentGetManifestRequest',
            'attachmentId',
          ),
          uploadId: BuiltValueNullFieldError.checkNotNull(
            uploadId,
            r'AttachmentGetManifestRequest',
            'uploadId',
          ),
          manifestKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            manifestKeyEpoch,
            r'AttachmentGetManifestRequest',
            'manifestKeyEpoch',
          ),
          manifestRevision: BuiltValueNullFieldError.checkNotNull(
            manifestRevision,
            r'AttachmentGetManifestRequest',
            'manifestRevision',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
