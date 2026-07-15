// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_attachment_info_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListAttachmentInfoData extends ListAttachmentInfoData {
  @override
  final BuiltList<AttachmentInfo> items;

  factory _$ListAttachmentInfoData([
    void Function(ListAttachmentInfoDataBuilder)? updates,
  ]) => (ListAttachmentInfoDataBuilder()..update(updates))._build();

  _$ListAttachmentInfoData._({required this.items}) : super._();
  @override
  ListAttachmentInfoData rebuild(
    void Function(ListAttachmentInfoDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListAttachmentInfoDataBuilder toBuilder() =>
      ListAttachmentInfoDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListAttachmentInfoData && items == other.items;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, items.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'ListAttachmentInfoData',
    )..add('items', items)).toString();
  }
}

class ListAttachmentInfoDataBuilder
    implements Builder<ListAttachmentInfoData, ListAttachmentInfoDataBuilder> {
  _$ListAttachmentInfoData? _$v;

  ListBuilder<AttachmentInfo>? _items;
  ListBuilder<AttachmentInfo> get items =>
      _$this._items ??= ListBuilder<AttachmentInfo>();
  set items(ListBuilder<AttachmentInfo>? items) => _$this._items = items;

  ListAttachmentInfoDataBuilder() {
    ListAttachmentInfoData._defaults(this);
  }

  ListAttachmentInfoDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _items = $v.items.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListAttachmentInfoData other) {
    _$v = other as _$ListAttachmentInfoData;
  }

  @override
  void update(void Function(ListAttachmentInfoDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ListAttachmentInfoData build() => _build();

  _$ListAttachmentInfoData _build() {
    _$ListAttachmentInfoData _$result;
    try {
      _$result = _$v ?? _$ListAttachmentInfoData._(items: items.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'items';
        items.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ListAttachmentInfoData',
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
