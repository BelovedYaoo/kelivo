// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_attachment_download_url_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$GetAttachmentDownloadUrlData extends GetAttachmentDownloadUrlData {
  @override
  final String attachmentId;
  @override
  final String downloadUrl;
  @override
  final DateTime expiresAt;

  factory _$GetAttachmentDownloadUrlData([
    void Function(GetAttachmentDownloadUrlDataBuilder)? updates,
  ]) => (GetAttachmentDownloadUrlDataBuilder()..update(updates))._build();

  _$GetAttachmentDownloadUrlData._({
    required this.attachmentId,
    required this.downloadUrl,
    required this.expiresAt,
  }) : super._();
  @override
  GetAttachmentDownloadUrlData rebuild(
    void Function(GetAttachmentDownloadUrlDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  GetAttachmentDownloadUrlDataBuilder toBuilder() =>
      GetAttachmentDownloadUrlDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GetAttachmentDownloadUrlData &&
        attachmentId == other.attachmentId &&
        downloadUrl == other.downloadUrl &&
        expiresAt == other.expiresAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, attachmentId.hashCode);
    _$hash = $jc(_$hash, downloadUrl.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'GetAttachmentDownloadUrlData')
          ..add('attachmentId', attachmentId)
          ..add('downloadUrl', downloadUrl)
          ..add('expiresAt', expiresAt))
        .toString();
  }
}

class GetAttachmentDownloadUrlDataBuilder
    implements
        Builder<
          GetAttachmentDownloadUrlData,
          GetAttachmentDownloadUrlDataBuilder
        > {
  _$GetAttachmentDownloadUrlData? _$v;

  String? _attachmentId;
  String? get attachmentId => _$this._attachmentId;
  set attachmentId(String? attachmentId) => _$this._attachmentId = attachmentId;

  String? _downloadUrl;
  String? get downloadUrl => _$this._downloadUrl;
  set downloadUrl(String? downloadUrl) => _$this._downloadUrl = downloadUrl;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  GetAttachmentDownloadUrlDataBuilder() {
    GetAttachmentDownloadUrlData._defaults(this);
  }

  GetAttachmentDownloadUrlDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _attachmentId = $v.attachmentId;
      _downloadUrl = $v.downloadUrl;
      _expiresAt = $v.expiresAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GetAttachmentDownloadUrlData other) {
    _$v = other as _$GetAttachmentDownloadUrlData;
  }

  @override
  void update(void Function(GetAttachmentDownloadUrlDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  GetAttachmentDownloadUrlData build() => _build();

  _$GetAttachmentDownloadUrlData _build() {
    final _$result =
        _$v ??
        _$GetAttachmentDownloadUrlData._(
          attachmentId: BuiltValueNullFieldError.checkNotNull(
            attachmentId,
            r'GetAttachmentDownloadUrlData',
            'attachmentId',
          ),
          downloadUrl: BuiltValueNullFieldError.checkNotNull(
            downloadUrl,
            r'GetAttachmentDownloadUrlData',
            'downloadUrl',
          ),
          expiresAt: BuiltValueNullFieldError.checkNotNull(
            expiresAt,
            r'GetAttachmentDownloadUrlData',
            'expiresAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
