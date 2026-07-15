// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_attachment_info_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DeleteAttachmentInfoRequest extends DeleteAttachmentInfoRequest {
  @override
  final String attachmentId;

  factory _$DeleteAttachmentInfoRequest([
    void Function(DeleteAttachmentInfoRequestBuilder)? updates,
  ]) => (DeleteAttachmentInfoRequestBuilder()..update(updates))._build();

  _$DeleteAttachmentInfoRequest._({required this.attachmentId}) : super._();
  @override
  DeleteAttachmentInfoRequest rebuild(
    void Function(DeleteAttachmentInfoRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DeleteAttachmentInfoRequestBuilder toBuilder() =>
      DeleteAttachmentInfoRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DeleteAttachmentInfoRequest &&
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
      r'DeleteAttachmentInfoRequest',
    )..add('attachmentId', attachmentId)).toString();
  }
}

class DeleteAttachmentInfoRequestBuilder
    implements
        Builder<
          DeleteAttachmentInfoRequest,
          DeleteAttachmentInfoRequestBuilder
        > {
  _$DeleteAttachmentInfoRequest? _$v;

  String? _attachmentId;
  String? get attachmentId => _$this._attachmentId;
  set attachmentId(String? attachmentId) => _$this._attachmentId = attachmentId;

  DeleteAttachmentInfoRequestBuilder() {
    DeleteAttachmentInfoRequest._defaults(this);
  }

  DeleteAttachmentInfoRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _attachmentId = $v.attachmentId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DeleteAttachmentInfoRequest other) {
    _$v = other as _$DeleteAttachmentInfoRequest;
  }

  @override
  void update(void Function(DeleteAttachmentInfoRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DeleteAttachmentInfoRequest build() => _build();

  _$DeleteAttachmentInfoRequest _build() {
    final _$result =
        _$v ??
        _$DeleteAttachmentInfoRequest._(
          attachmentId: BuiltValueNullFieldError.checkNotNull(
            attachmentId,
            r'DeleteAttachmentInfoRequest',
            'attachmentId',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
