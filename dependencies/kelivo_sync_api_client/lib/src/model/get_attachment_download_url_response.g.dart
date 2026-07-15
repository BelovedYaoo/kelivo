// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_attachment_download_url_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$GetAttachmentDownloadUrlResponse
    extends GetAttachmentDownloadUrlResponse {
  @override
  final GetAttachmentDownloadUrlData data;

  factory _$GetAttachmentDownloadUrlResponse([
    void Function(GetAttachmentDownloadUrlResponseBuilder)? updates,
  ]) => (GetAttachmentDownloadUrlResponseBuilder()..update(updates))._build();

  _$GetAttachmentDownloadUrlResponse._({required this.data}) : super._();
  @override
  GetAttachmentDownloadUrlResponse rebuild(
    void Function(GetAttachmentDownloadUrlResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  GetAttachmentDownloadUrlResponseBuilder toBuilder() =>
      GetAttachmentDownloadUrlResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GetAttachmentDownloadUrlResponse && data == other.data;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, data.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'GetAttachmentDownloadUrlResponse',
    )..add('data', data)).toString();
  }
}

class GetAttachmentDownloadUrlResponseBuilder
    implements
        Builder<
          GetAttachmentDownloadUrlResponse,
          GetAttachmentDownloadUrlResponseBuilder
        > {
  _$GetAttachmentDownloadUrlResponse? _$v;

  GetAttachmentDownloadUrlDataBuilder? _data;
  GetAttachmentDownloadUrlDataBuilder get data =>
      _$this._data ??= GetAttachmentDownloadUrlDataBuilder();
  set data(GetAttachmentDownloadUrlDataBuilder? data) => _$this._data = data;

  GetAttachmentDownloadUrlResponseBuilder() {
    GetAttachmentDownloadUrlResponse._defaults(this);
  }

  GetAttachmentDownloadUrlResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GetAttachmentDownloadUrlResponse other) {
    _$v = other as _$GetAttachmentDownloadUrlResponse;
  }

  @override
  void update(void Function(GetAttachmentDownloadUrlResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  GetAttachmentDownloadUrlResponse build() => _build();

  _$GetAttachmentDownloadUrlResponse _build() {
    _$GetAttachmentDownloadUrlResponse _$result;
    try {
      _$result =
          _$v ?? _$GetAttachmentDownloadUrlResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'GetAttachmentDownloadUrlResponse',
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
