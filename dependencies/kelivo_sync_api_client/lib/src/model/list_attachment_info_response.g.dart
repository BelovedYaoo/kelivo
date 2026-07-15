// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_attachment_info_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListAttachmentInfoResponse extends ListAttachmentInfoResponse {
  @override
  final ListAttachmentInfoData data;

  factory _$ListAttachmentInfoResponse([
    void Function(ListAttachmentInfoResponseBuilder)? updates,
  ]) => (ListAttachmentInfoResponseBuilder()..update(updates))._build();

  _$ListAttachmentInfoResponse._({required this.data}) : super._();
  @override
  ListAttachmentInfoResponse rebuild(
    void Function(ListAttachmentInfoResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListAttachmentInfoResponseBuilder toBuilder() =>
      ListAttachmentInfoResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListAttachmentInfoResponse && data == other.data;
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
      r'ListAttachmentInfoResponse',
    )..add('data', data)).toString();
  }
}

class ListAttachmentInfoResponseBuilder
    implements
        Builder<ListAttachmentInfoResponse, ListAttachmentInfoResponseBuilder> {
  _$ListAttachmentInfoResponse? _$v;

  ListAttachmentInfoDataBuilder? _data;
  ListAttachmentInfoDataBuilder get data =>
      _$this._data ??= ListAttachmentInfoDataBuilder();
  set data(ListAttachmentInfoDataBuilder? data) => _$this._data = data;

  ListAttachmentInfoResponseBuilder() {
    ListAttachmentInfoResponse._defaults(this);
  }

  ListAttachmentInfoResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListAttachmentInfoResponse other) {
    _$v = other as _$ListAttachmentInfoResponse;
  }

  @override
  void update(void Function(ListAttachmentInfoResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ListAttachmentInfoResponse build() => _build();

  _$ListAttachmentInfoResponse _build() {
    _$ListAttachmentInfoResponse _$result;
    try {
      _$result = _$v ?? _$ListAttachmentInfoResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ListAttachmentInfoResponse',
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
