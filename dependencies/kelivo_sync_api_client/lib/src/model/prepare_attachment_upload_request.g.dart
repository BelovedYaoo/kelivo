// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prepare_attachment_upload_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PrepareAttachmentUploadRequest extends PrepareAttachmentUploadRequest {
  @override
  final String sha256;
  @override
  final String md5;
  @override
  final int sizeBytes;

  factory _$PrepareAttachmentUploadRequest([
    void Function(PrepareAttachmentUploadRequestBuilder)? updates,
  ]) => (PrepareAttachmentUploadRequestBuilder()..update(updates))._build();

  _$PrepareAttachmentUploadRequest._({
    required this.sha256,
    required this.md5,
    required this.sizeBytes,
  }) : super._();
  @override
  PrepareAttachmentUploadRequest rebuild(
    void Function(PrepareAttachmentUploadRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  PrepareAttachmentUploadRequestBuilder toBuilder() =>
      PrepareAttachmentUploadRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PrepareAttachmentUploadRequest &&
        sha256 == other.sha256 &&
        md5 == other.md5 &&
        sizeBytes == other.sizeBytes;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, sha256.hashCode);
    _$hash = $jc(_$hash, md5.hashCode);
    _$hash = $jc(_$hash, sizeBytes.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PrepareAttachmentUploadRequest')
          ..add('sha256', sha256)
          ..add('md5', md5)
          ..add('sizeBytes', sizeBytes))
        .toString();
  }
}

class PrepareAttachmentUploadRequestBuilder
    implements
        Builder<
          PrepareAttachmentUploadRequest,
          PrepareAttachmentUploadRequestBuilder
        > {
  _$PrepareAttachmentUploadRequest? _$v;

  String? _sha256;
  String? get sha256 => _$this._sha256;
  set sha256(String? sha256) => _$this._sha256 = sha256;

  String? _md5;
  String? get md5 => _$this._md5;
  set md5(String? md5) => _$this._md5 = md5;

  int? _sizeBytes;
  int? get sizeBytes => _$this._sizeBytes;
  set sizeBytes(int? sizeBytes) => _$this._sizeBytes = sizeBytes;

  PrepareAttachmentUploadRequestBuilder() {
    PrepareAttachmentUploadRequest._defaults(this);
  }

  PrepareAttachmentUploadRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _sha256 = $v.sha256;
      _md5 = $v.md5;
      _sizeBytes = $v.sizeBytes;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PrepareAttachmentUploadRequest other) {
    _$v = other as _$PrepareAttachmentUploadRequest;
  }

  @override
  void update(void Function(PrepareAttachmentUploadRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PrepareAttachmentUploadRequest build() => _build();

  _$PrepareAttachmentUploadRequest _build() {
    final _$result =
        _$v ??
        _$PrepareAttachmentUploadRequest._(
          sha256: BuiltValueNullFieldError.checkNotNull(
            sha256,
            r'PrepareAttachmentUploadRequest',
            'sha256',
          ),
          md5: BuiltValueNullFieldError.checkNotNull(
            md5,
            r'PrepareAttachmentUploadRequest',
            'md5',
          ),
          sizeBytes: BuiltValueNullFieldError.checkNotNull(
            sizeBytes,
            r'PrepareAttachmentUploadRequest',
            'sizeBytes',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
