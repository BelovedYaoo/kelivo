// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_source_attachment_list_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DataRekeySourceAttachmentListData
    extends DataRekeySourceAttachmentListData {
  @override
  final BuiltList<DataRekeySourceAttachmentData> attachments;
  @override
  final String? nextAfterAttachmentId;
  @override
  final bool hasMore;

  factory _$DataRekeySourceAttachmentListData([
    void Function(DataRekeySourceAttachmentListDataBuilder)? updates,
  ]) => (DataRekeySourceAttachmentListDataBuilder()..update(updates))._build();

  _$DataRekeySourceAttachmentListData._({
    required this.attachments,
    this.nextAfterAttachmentId,
    required this.hasMore,
  }) : super._();
  @override
  DataRekeySourceAttachmentListData rebuild(
    void Function(DataRekeySourceAttachmentListDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeySourceAttachmentListDataBuilder toBuilder() =>
      DataRekeySourceAttachmentListDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeySourceAttachmentListData &&
        attachments == other.attachments &&
        nextAfterAttachmentId == other.nextAfterAttachmentId &&
        hasMore == other.hasMore;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, attachments.hashCode);
    _$hash = $jc(_$hash, nextAfterAttachmentId.hashCode);
    _$hash = $jc(_$hash, hasMore.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DataRekeySourceAttachmentListData')
          ..add('attachments', attachments)
          ..add('nextAfterAttachmentId', nextAfterAttachmentId)
          ..add('hasMore', hasMore))
        .toString();
  }
}

class DataRekeySourceAttachmentListDataBuilder
    implements
        Builder<
          DataRekeySourceAttachmentListData,
          DataRekeySourceAttachmentListDataBuilder
        > {
  _$DataRekeySourceAttachmentListData? _$v;

  ListBuilder<DataRekeySourceAttachmentData>? _attachments;
  ListBuilder<DataRekeySourceAttachmentData> get attachments =>
      _$this._attachments ??= ListBuilder<DataRekeySourceAttachmentData>();
  set attachments(ListBuilder<DataRekeySourceAttachmentData>? attachments) =>
      _$this._attachments = attachments;

  String? _nextAfterAttachmentId;
  String? get nextAfterAttachmentId => _$this._nextAfterAttachmentId;
  set nextAfterAttachmentId(String? nextAfterAttachmentId) =>
      _$this._nextAfterAttachmentId = nextAfterAttachmentId;

  bool? _hasMore;
  bool? get hasMore => _$this._hasMore;
  set hasMore(bool? hasMore) => _$this._hasMore = hasMore;

  DataRekeySourceAttachmentListDataBuilder() {
    DataRekeySourceAttachmentListData._defaults(this);
  }

  DataRekeySourceAttachmentListDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _attachments = $v.attachments.toBuilder();
      _nextAfterAttachmentId = $v.nextAfterAttachmentId;
      _hasMore = $v.hasMore;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeySourceAttachmentListData other) {
    _$v = other as _$DataRekeySourceAttachmentListData;
  }

  @override
  void update(
    void Function(DataRekeySourceAttachmentListDataBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeySourceAttachmentListData build() => _build();

  _$DataRekeySourceAttachmentListData _build() {
    _$DataRekeySourceAttachmentListData _$result;
    try {
      _$result =
          _$v ??
          _$DataRekeySourceAttachmentListData._(
            attachments: attachments.build(),
            nextAfterAttachmentId: nextAfterAttachmentId,
            hasMore: BuiltValueNullFieldError.checkNotNull(
              hasMore,
              r'DataRekeySourceAttachmentListData',
              'hasMore',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'attachments';
        attachments.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'DataRekeySourceAttachmentListData',
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
