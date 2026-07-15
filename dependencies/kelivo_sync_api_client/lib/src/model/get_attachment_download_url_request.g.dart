// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_attachment_download_url_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$GetAttachmentDownloadUrlRequest
    extends GetAttachmentDownloadUrlRequest {
  @override
  final String attachmentId;

  factory _$GetAttachmentDownloadUrlRequest([
    void Function(GetAttachmentDownloadUrlRequestBuilder)? updates,
  ]) => (GetAttachmentDownloadUrlRequestBuilder()..update(updates))._build();

  _$GetAttachmentDownloadUrlRequest._({required this.attachmentId}) : super._();
  @override
  GetAttachmentDownloadUrlRequest rebuild(
    void Function(GetAttachmentDownloadUrlRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  GetAttachmentDownloadUrlRequestBuilder toBuilder() =>
      GetAttachmentDownloadUrlRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GetAttachmentDownloadUrlRequest &&
        attachmentId == other.attachmentId;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, attachmentId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'GetAttachmentDownloadUrlRequest',
    )..add('attachmentId', attachmentId)).toString();
  }
}

class GetAttachmentDownloadUrlRequestBuilder
    implements
        Builder<
          GetAttachmentDownloadUrlRequest,
          GetAttachmentDownloadUrlRequestBuilder
        > {
  _$GetAttachmentDownloadUrlRequest? _$v;

  String? _attachmentId;
  String? get attachmentId => _$this._attachmentId;
  set attachmentId(String? attachmentId) => _$this._attachmentId = attachmentId;

  GetAttachmentDownloadUrlRequestBuilder() {
    GetAttachmentDownloadUrlRequest._defaults(this);
  }

  GetAttachmentDownloadUrlRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _attachmentId = $v.attachmentId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GetAttachmentDownloadUrlRequest other) {
    _$v = other as _$GetAttachmentDownloadUrlRequest;
  }

  @override
  void update(void Function(GetAttachmentDownloadUrlRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  GetAttachmentDownloadUrlRequest build() => _build();

  _$GetAttachmentDownloadUrlRequest _build() {
    final _$result =
        _$v ??
        _$GetAttachmentDownloadUrlRequest._(
          attachmentId: BuiltValueNullFieldError.checkNotNull(
            attachmentId,
            r'GetAttachmentDownloadUrlRequest',
            'attachmentId',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
