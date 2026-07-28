// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_encrypted_attachment_manifest_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$GetEncryptedAttachmentManifestResponse
    extends GetEncryptedAttachmentManifestResponse {
  @override
  final AttachmentManifestData data;

  factory _$GetEncryptedAttachmentManifestResponse([
    void Function(GetEncryptedAttachmentManifestResponseBuilder)? updates,
  ]) => (GetEncryptedAttachmentManifestResponseBuilder()..update(updates))
      ._build();

  _$GetEncryptedAttachmentManifestResponse._({required this.data}) : super._();
  @override
  GetEncryptedAttachmentManifestResponse rebuild(
    void Function(GetEncryptedAttachmentManifestResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  GetEncryptedAttachmentManifestResponseBuilder toBuilder() =>
      GetEncryptedAttachmentManifestResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GetEncryptedAttachmentManifestResponse &&
        data == other.data;
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
      r'GetEncryptedAttachmentManifestResponse',
    )..add('data', data)).toString();
  }
}

class GetEncryptedAttachmentManifestResponseBuilder
    implements
        Builder<
          GetEncryptedAttachmentManifestResponse,
          GetEncryptedAttachmentManifestResponseBuilder
        > {
  _$GetEncryptedAttachmentManifestResponse? _$v;

  AttachmentManifestDataBuilder? _data;
  AttachmentManifestDataBuilder get data =>
      _$this._data ??= AttachmentManifestDataBuilder();
  set data(AttachmentManifestDataBuilder? data) => _$this._data = data;

  GetEncryptedAttachmentManifestResponseBuilder() {
    GetEncryptedAttachmentManifestResponse._defaults(this);
  }

  GetEncryptedAttachmentManifestResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GetEncryptedAttachmentManifestResponse other) {
    _$v = other as _$GetEncryptedAttachmentManifestResponse;
  }

  @override
  void update(
    void Function(GetEncryptedAttachmentManifestResponseBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  GetEncryptedAttachmentManifestResponse build() => _build();

  _$GetEncryptedAttachmentManifestResponse _build() {
    _$GetEncryptedAttachmentManifestResponse _$result;
    try {
      _$result =
          _$v ?? _$GetEncryptedAttachmentManifestResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'GetEncryptedAttachmentManifestResponse',
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
