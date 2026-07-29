// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_attachment_stage_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DataRekeyAttachmentStageRequest
    extends DataRekeyAttachmentStageRequest {
  @override
  final String operationId;
  @override
  final int sourceDataGeneration;
  @override
  final int sourceKeyEpoch;
  @override
  final int targetKeyEpoch;
  @override
  final String leaseToken;
  @override
  final int leaseVersion;
  @override
  final String mutationId;
  @override
  final String attachmentId;
  @override
  final String uploadId;
  @override
  final int sourceManifestRevision;
  @override
  final int manifestKeyEpoch;
  @override
  final int manifestRevision;
  @override
  final String manifestCiphertext;

  factory _$DataRekeyAttachmentStageRequest([
    void Function(DataRekeyAttachmentStageRequestBuilder)? updates,
  ]) => (DataRekeyAttachmentStageRequestBuilder()..update(updates))._build();

  _$DataRekeyAttachmentStageRequest._({
    required this.operationId,
    required this.sourceDataGeneration,
    required this.sourceKeyEpoch,
    required this.targetKeyEpoch,
    required this.leaseToken,
    required this.leaseVersion,
    required this.mutationId,
    required this.attachmentId,
    required this.uploadId,
    required this.sourceManifestRevision,
    required this.manifestKeyEpoch,
    required this.manifestRevision,
    required this.manifestCiphertext,
  }) : super._();
  @override
  DataRekeyAttachmentStageRequest rebuild(
    void Function(DataRekeyAttachmentStageRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeyAttachmentStageRequestBuilder toBuilder() =>
      DataRekeyAttachmentStageRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeyAttachmentStageRequest &&
        operationId == other.operationId &&
        sourceDataGeneration == other.sourceDataGeneration &&
        sourceKeyEpoch == other.sourceKeyEpoch &&
        targetKeyEpoch == other.targetKeyEpoch &&
        leaseToken == other.leaseToken &&
        leaseVersion == other.leaseVersion &&
        mutationId == other.mutationId &&
        attachmentId == other.attachmentId &&
        uploadId == other.uploadId &&
        sourceManifestRevision == other.sourceManifestRevision &&
        manifestKeyEpoch == other.manifestKeyEpoch &&
        manifestRevision == other.manifestRevision &&
        manifestCiphertext == other.manifestCiphertext;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, operationId.hashCode);
    _$hash = $jc(_$hash, sourceDataGeneration.hashCode);
    _$hash = $jc(_$hash, sourceKeyEpoch.hashCode);
    _$hash = $jc(_$hash, targetKeyEpoch.hashCode);
    _$hash = $jc(_$hash, leaseToken.hashCode);
    _$hash = $jc(_$hash, leaseVersion.hashCode);
    _$hash = $jc(_$hash, mutationId.hashCode);
    _$hash = $jc(_$hash, attachmentId.hashCode);
    _$hash = $jc(_$hash, uploadId.hashCode);
    _$hash = $jc(_$hash, sourceManifestRevision.hashCode);
    _$hash = $jc(_$hash, manifestKeyEpoch.hashCode);
    _$hash = $jc(_$hash, manifestRevision.hashCode);
    _$hash = $jc(_$hash, manifestCiphertext.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DataRekeyAttachmentStageRequest')
          ..add('operationId', operationId)
          ..add('sourceDataGeneration', sourceDataGeneration)
          ..add('sourceKeyEpoch', sourceKeyEpoch)
          ..add('targetKeyEpoch', targetKeyEpoch)
          ..add('leaseToken', leaseToken)
          ..add('leaseVersion', leaseVersion)
          ..add('mutationId', mutationId)
          ..add('attachmentId', attachmentId)
          ..add('uploadId', uploadId)
          ..add('sourceManifestRevision', sourceManifestRevision)
          ..add('manifestKeyEpoch', manifestKeyEpoch)
          ..add('manifestRevision', manifestRevision)
          ..add('manifestCiphertext', manifestCiphertext))
        .toString();
  }
}

class DataRekeyAttachmentStageRequestBuilder
    implements
        Builder<
          DataRekeyAttachmentStageRequest,
          DataRekeyAttachmentStageRequestBuilder
        > {
  _$DataRekeyAttachmentStageRequest? _$v;

  String? _operationId;
  String? get operationId => _$this._operationId;
  set operationId(String? operationId) => _$this._operationId = operationId;

  int? _sourceDataGeneration;
  int? get sourceDataGeneration => _$this._sourceDataGeneration;
  set sourceDataGeneration(int? sourceDataGeneration) =>
      _$this._sourceDataGeneration = sourceDataGeneration;

  int? _sourceKeyEpoch;
  int? get sourceKeyEpoch => _$this._sourceKeyEpoch;
  set sourceKeyEpoch(int? sourceKeyEpoch) =>
      _$this._sourceKeyEpoch = sourceKeyEpoch;

  int? _targetKeyEpoch;
  int? get targetKeyEpoch => _$this._targetKeyEpoch;
  set targetKeyEpoch(int? targetKeyEpoch) =>
      _$this._targetKeyEpoch = targetKeyEpoch;

  String? _leaseToken;
  String? get leaseToken => _$this._leaseToken;
  set leaseToken(String? leaseToken) => _$this._leaseToken = leaseToken;

  int? _leaseVersion;
  int? get leaseVersion => _$this._leaseVersion;
  set leaseVersion(int? leaseVersion) => _$this._leaseVersion = leaseVersion;

  String? _mutationId;
  String? get mutationId => _$this._mutationId;
  set mutationId(String? mutationId) => _$this._mutationId = mutationId;

  String? _attachmentId;
  String? get attachmentId => _$this._attachmentId;
  set attachmentId(String? attachmentId) => _$this._attachmentId = attachmentId;

  String? _uploadId;
  String? get uploadId => _$this._uploadId;
  set uploadId(String? uploadId) => _$this._uploadId = uploadId;

  int? _sourceManifestRevision;
  int? get sourceManifestRevision => _$this._sourceManifestRevision;
  set sourceManifestRevision(int? sourceManifestRevision) =>
      _$this._sourceManifestRevision = sourceManifestRevision;

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

  DataRekeyAttachmentStageRequestBuilder() {
    DataRekeyAttachmentStageRequest._defaults(this);
  }

  DataRekeyAttachmentStageRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _operationId = $v.operationId;
      _sourceDataGeneration = $v.sourceDataGeneration;
      _sourceKeyEpoch = $v.sourceKeyEpoch;
      _targetKeyEpoch = $v.targetKeyEpoch;
      _leaseToken = $v.leaseToken;
      _leaseVersion = $v.leaseVersion;
      _mutationId = $v.mutationId;
      _attachmentId = $v.attachmentId;
      _uploadId = $v.uploadId;
      _sourceManifestRevision = $v.sourceManifestRevision;
      _manifestKeyEpoch = $v.manifestKeyEpoch;
      _manifestRevision = $v.manifestRevision;
      _manifestCiphertext = $v.manifestCiphertext;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeyAttachmentStageRequest other) {
    _$v = other as _$DataRekeyAttachmentStageRequest;
  }

  @override
  void update(void Function(DataRekeyAttachmentStageRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeyAttachmentStageRequest build() => _build();

  _$DataRekeyAttachmentStageRequest _build() {
    final _$result =
        _$v ??
        _$DataRekeyAttachmentStageRequest._(
          operationId: BuiltValueNullFieldError.checkNotNull(
            operationId,
            r'DataRekeyAttachmentStageRequest',
            'operationId',
          ),
          sourceDataGeneration: BuiltValueNullFieldError.checkNotNull(
            sourceDataGeneration,
            r'DataRekeyAttachmentStageRequest',
            'sourceDataGeneration',
          ),
          sourceKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            sourceKeyEpoch,
            r'DataRekeyAttachmentStageRequest',
            'sourceKeyEpoch',
          ),
          targetKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            targetKeyEpoch,
            r'DataRekeyAttachmentStageRequest',
            'targetKeyEpoch',
          ),
          leaseToken: BuiltValueNullFieldError.checkNotNull(
            leaseToken,
            r'DataRekeyAttachmentStageRequest',
            'leaseToken',
          ),
          leaseVersion: BuiltValueNullFieldError.checkNotNull(
            leaseVersion,
            r'DataRekeyAttachmentStageRequest',
            'leaseVersion',
          ),
          mutationId: BuiltValueNullFieldError.checkNotNull(
            mutationId,
            r'DataRekeyAttachmentStageRequest',
            'mutationId',
          ),
          attachmentId: BuiltValueNullFieldError.checkNotNull(
            attachmentId,
            r'DataRekeyAttachmentStageRequest',
            'attachmentId',
          ),
          uploadId: BuiltValueNullFieldError.checkNotNull(
            uploadId,
            r'DataRekeyAttachmentStageRequest',
            'uploadId',
          ),
          sourceManifestRevision: BuiltValueNullFieldError.checkNotNull(
            sourceManifestRevision,
            r'DataRekeyAttachmentStageRequest',
            'sourceManifestRevision',
          ),
          manifestKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            manifestKeyEpoch,
            r'DataRekeyAttachmentStageRequest',
            'manifestKeyEpoch',
          ),
          manifestRevision: BuiltValueNullFieldError.checkNotNull(
            manifestRevision,
            r'DataRekeyAttachmentStageRequest',
            'manifestRevision',
          ),
          manifestCiphertext: BuiltValueNullFieldError.checkNotNull(
            manifestCiphertext,
            r'DataRekeyAttachmentStageRequest',
            'manifestCiphertext',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
