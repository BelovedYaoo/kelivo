// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_data_rekey_source_attachments_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListDataRekeySourceAttachmentsResponse
    extends ListDataRekeySourceAttachmentsResponse {
  @override
  final DataRekeySourceAttachmentListData data;

  factory _$ListDataRekeySourceAttachmentsResponse([
    void Function(ListDataRekeySourceAttachmentsResponseBuilder)? updates,
  ]) => (ListDataRekeySourceAttachmentsResponseBuilder()..update(updates))
      ._build();

  _$ListDataRekeySourceAttachmentsResponse._({required this.data}) : super._();
  @override
  ListDataRekeySourceAttachmentsResponse rebuild(
    void Function(ListDataRekeySourceAttachmentsResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListDataRekeySourceAttachmentsResponseBuilder toBuilder() =>
      ListDataRekeySourceAttachmentsResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListDataRekeySourceAttachmentsResponse &&
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
      r'ListDataRekeySourceAttachmentsResponse',
    )..add('data', data)).toString();
  }
}

class ListDataRekeySourceAttachmentsResponseBuilder
    implements
        Builder<
          ListDataRekeySourceAttachmentsResponse,
          ListDataRekeySourceAttachmentsResponseBuilder
        > {
  _$ListDataRekeySourceAttachmentsResponse? _$v;

  DataRekeySourceAttachmentListDataBuilder? _data;
  DataRekeySourceAttachmentListDataBuilder get data =>
      _$this._data ??= DataRekeySourceAttachmentListDataBuilder();
  set data(DataRekeySourceAttachmentListDataBuilder? data) =>
      _$this._data = data;

  ListDataRekeySourceAttachmentsResponseBuilder() {
    ListDataRekeySourceAttachmentsResponse._defaults(this);
  }

  ListDataRekeySourceAttachmentsResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListDataRekeySourceAttachmentsResponse other) {
    _$v = other as _$ListDataRekeySourceAttachmentsResponse;
  }

  @override
  void update(
    void Function(ListDataRekeySourceAttachmentsResponseBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  ListDataRekeySourceAttachmentsResponse build() => _build();

  _$ListDataRekeySourceAttachmentsResponse _build() {
    _$ListDataRekeySourceAttachmentsResponse _$result;
    try {
      _$result =
          _$v ?? _$ListDataRekeySourceAttachmentsResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ListDataRekeySourceAttachmentsResponse',
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
