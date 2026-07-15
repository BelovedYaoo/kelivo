// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_attachment_info_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListAttachmentInfoRequest extends ListAttachmentInfoRequest {
  @override
  final String entityType;
  @override
  final String entityId;

  factory _$ListAttachmentInfoRequest([
    void Function(ListAttachmentInfoRequestBuilder)? updates,
  ]) => (ListAttachmentInfoRequestBuilder()..update(updates))._build();

  _$ListAttachmentInfoRequest._({
    required this.entityType,
    required this.entityId,
  }) : super._();
  @override
  ListAttachmentInfoRequest rebuild(
    void Function(ListAttachmentInfoRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListAttachmentInfoRequestBuilder toBuilder() =>
      ListAttachmentInfoRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListAttachmentInfoRequest &&
        entityType == other.entityType &&
        entityId == other.entityId;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, entityType.hashCode);
    _$hash = $jc(_$hash, entityId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ListAttachmentInfoRequest')
          ..add('entityType', entityType)
          ..add('entityId', entityId))
        .toString();
  }
}

class ListAttachmentInfoRequestBuilder
    implements
        Builder<ListAttachmentInfoRequest, ListAttachmentInfoRequestBuilder> {
  _$ListAttachmentInfoRequest? _$v;

  String? _entityType;
  String? get entityType => _$this._entityType;
  set entityType(String? entityType) => _$this._entityType = entityType;

  String? _entityId;
  String? get entityId => _$this._entityId;
  set entityId(String? entityId) => _$this._entityId = entityId;

  ListAttachmentInfoRequestBuilder() {
    ListAttachmentInfoRequest._defaults(this);
  }

  ListAttachmentInfoRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _entityType = $v.entityType;
      _entityId = $v.entityId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListAttachmentInfoRequest other) {
    _$v = other as _$ListAttachmentInfoRequest;
  }

  @override
  void update(void Function(ListAttachmentInfoRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ListAttachmentInfoRequest build() => _build();

  _$ListAttachmentInfoRequest _build() {
    final _$result =
        _$v ??
        _$ListAttachmentInfoRequest._(
          entityType: BuiltValueNullFieldError.checkNotNull(
            entityType,
            r'ListAttachmentInfoRequest',
            'entityType',
          ),
          entityId: BuiltValueNullFieldError.checkNotNull(
            entityId,
            r'ListAttachmentInfoRequest',
            'entityId',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
