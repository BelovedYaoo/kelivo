// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_attachment_info_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DeleteAttachmentInfoData extends DeleteAttachmentInfoData {
  @override
  final String attachmentId;
  @override
  final bool deleted;

  factory _$DeleteAttachmentInfoData([
    void Function(DeleteAttachmentInfoDataBuilder)? updates,
  ]) => (DeleteAttachmentInfoDataBuilder()..update(updates))._build();

  _$DeleteAttachmentInfoData._({
    required this.attachmentId,
    required this.deleted,
  }) : super._();
  @override
  DeleteAttachmentInfoData rebuild(
    void Function(DeleteAttachmentInfoDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DeleteAttachmentInfoDataBuilder toBuilder() =>
      DeleteAttachmentInfoDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DeleteAttachmentInfoData &&
        attachmentId == other.attachmentId &&
        deleted == other.deleted;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, attachmentId.hashCode);
    _$hash = $jc(_$hash, deleted.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DeleteAttachmentInfoData')
          ..add('attachmentId', attachmentId)
          ..add('deleted', deleted))
        .toString();
  }
}

class DeleteAttachmentInfoDataBuilder
    implements
        Builder<DeleteAttachmentInfoData, DeleteAttachmentInfoDataBuilder> {
  _$DeleteAttachmentInfoData? _$v;

  String? _attachmentId;
  String? get attachmentId => _$this._attachmentId;
  set attachmentId(String? attachmentId) => _$this._attachmentId = attachmentId;

  bool? _deleted;
  bool? get deleted => _$this._deleted;
  set deleted(bool? deleted) => _$this._deleted = deleted;

  DeleteAttachmentInfoDataBuilder() {
    DeleteAttachmentInfoData._defaults(this);
  }

  DeleteAttachmentInfoDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _attachmentId = $v.attachmentId;
      _deleted = $v.deleted;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DeleteAttachmentInfoData other) {
    _$v = other as _$DeleteAttachmentInfoData;
  }

  @override
  void update(void Function(DeleteAttachmentInfoDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DeleteAttachmentInfoData build() => _build();

  _$DeleteAttachmentInfoData _build() {
    final _$result =
        _$v ??
        _$DeleteAttachmentInfoData._(
          attachmentId: BuiltValueNullFieldError.checkNotNull(
            attachmentId,
            r'DeleteAttachmentInfoData',
            'attachmentId',
          ),
          deleted: BuiltValueNullFieldError.checkNotNull(
            deleted,
            r'DeleteAttachmentInfoData',
            'deleted',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
