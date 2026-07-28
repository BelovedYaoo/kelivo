// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_delete_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AttachmentDeleteRequest extends AttachmentDeleteRequest {
  @override
  final String mutationId;
  @override
  final String attachmentId;
  @override
  final String uploadId;
  @override
  final int keyEpoch;

  factory _$AttachmentDeleteRequest([
    void Function(AttachmentDeleteRequestBuilder)? updates,
  ]) => (AttachmentDeleteRequestBuilder()..update(updates))._build();

  _$AttachmentDeleteRequest._({
    required this.mutationId,
    required this.attachmentId,
    required this.uploadId,
    required this.keyEpoch,
  }) : super._();
  @override
  AttachmentDeleteRequest rebuild(
    void Function(AttachmentDeleteRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AttachmentDeleteRequestBuilder toBuilder() =>
      AttachmentDeleteRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AttachmentDeleteRequest &&
        mutationId == other.mutationId &&
        attachmentId == other.attachmentId &&
        uploadId == other.uploadId &&
        keyEpoch == other.keyEpoch;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, mutationId.hashCode);
    _$hash = $jc(_$hash, attachmentId.hashCode);
    _$hash = $jc(_$hash, uploadId.hashCode);
    _$hash = $jc(_$hash, keyEpoch.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AttachmentDeleteRequest')
          ..add('mutationId', mutationId)
          ..add('attachmentId', attachmentId)
          ..add('uploadId', uploadId)
          ..add('keyEpoch', keyEpoch))
        .toString();
  }
}

class AttachmentDeleteRequestBuilder
    implements
        Builder<AttachmentDeleteRequest, AttachmentDeleteRequestBuilder> {
  _$AttachmentDeleteRequest? _$v;

  String? _mutationId;
  String? get mutationId => _$this._mutationId;
  set mutationId(String? mutationId) => _$this._mutationId = mutationId;

  String? _attachmentId;
  String? get attachmentId => _$this._attachmentId;
  set attachmentId(String? attachmentId) => _$this._attachmentId = attachmentId;

  String? _uploadId;
  String? get uploadId => _$this._uploadId;
  set uploadId(String? uploadId) => _$this._uploadId = uploadId;

  int? _keyEpoch;
  int? get keyEpoch => _$this._keyEpoch;
  set keyEpoch(int? keyEpoch) => _$this._keyEpoch = keyEpoch;

  AttachmentDeleteRequestBuilder() {
    AttachmentDeleteRequest._defaults(this);
  }

  AttachmentDeleteRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _mutationId = $v.mutationId;
      _attachmentId = $v.attachmentId;
      _uploadId = $v.uploadId;
      _keyEpoch = $v.keyEpoch;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AttachmentDeleteRequest other) {
    _$v = other as _$AttachmentDeleteRequest;
  }

  @override
  void update(void Function(AttachmentDeleteRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AttachmentDeleteRequest build() => _build();

  _$AttachmentDeleteRequest _build() {
    final _$result =
        _$v ??
        _$AttachmentDeleteRequest._(
          mutationId: BuiltValueNullFieldError.checkNotNull(
            mutationId,
            r'AttachmentDeleteRequest',
            'mutationId',
          ),
          attachmentId: BuiltValueNullFieldError.checkNotNull(
            attachmentId,
            r'AttachmentDeleteRequest',
            'attachmentId',
          ),
          uploadId: BuiltValueNullFieldError.checkNotNull(
            uploadId,
            r'AttachmentDeleteRequest',
            'uploadId',
          ),
          keyEpoch: BuiltValueNullFieldError.checkNotNull(
            keyEpoch,
            r'AttachmentDeleteRequest',
            'keyEpoch',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
