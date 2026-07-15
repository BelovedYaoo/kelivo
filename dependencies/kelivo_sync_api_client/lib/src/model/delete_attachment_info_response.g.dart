// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_attachment_info_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DeleteAttachmentInfoResponse extends DeleteAttachmentInfoResponse {
  @override
  final DeleteAttachmentInfoData data;

  factory _$DeleteAttachmentInfoResponse([
    void Function(DeleteAttachmentInfoResponseBuilder)? updates,
  ]) => (DeleteAttachmentInfoResponseBuilder()..update(updates))._build();

  _$DeleteAttachmentInfoResponse._({required this.data}) : super._();
  @override
  DeleteAttachmentInfoResponse rebuild(
    void Function(DeleteAttachmentInfoResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DeleteAttachmentInfoResponseBuilder toBuilder() =>
      DeleteAttachmentInfoResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DeleteAttachmentInfoResponse && data == other.data;
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
      r'DeleteAttachmentInfoResponse',
    )..add('data', data)).toString();
  }
}

class DeleteAttachmentInfoResponseBuilder
    implements
        Builder<
          DeleteAttachmentInfoResponse,
          DeleteAttachmentInfoResponseBuilder
        > {
  _$DeleteAttachmentInfoResponse? _$v;

  DeleteAttachmentInfoDataBuilder? _data;
  DeleteAttachmentInfoDataBuilder get data =>
      _$this._data ??= DeleteAttachmentInfoDataBuilder();
  set data(DeleteAttachmentInfoDataBuilder? data) => _$this._data = data;

  DeleteAttachmentInfoResponseBuilder() {
    DeleteAttachmentInfoResponse._defaults(this);
  }

  DeleteAttachmentInfoResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DeleteAttachmentInfoResponse other) {
    _$v = other as _$DeleteAttachmentInfoResponse;
  }

  @override
  void update(void Function(DeleteAttachmentInfoResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DeleteAttachmentInfoResponse build() => _build();

  _$DeleteAttachmentInfoResponse _build() {
    _$DeleteAttachmentInfoResponse _$result;
    try {
      _$result = _$v ?? _$DeleteAttachmentInfoResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'DeleteAttachmentInfoResponse',
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
