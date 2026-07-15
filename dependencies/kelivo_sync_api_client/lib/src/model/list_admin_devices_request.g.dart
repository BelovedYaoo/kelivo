// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_devices_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const ListAdminDevicesRequestStatusEnum
_$listAdminDevicesRequestStatusEnum_active =
    const ListAdminDevicesRequestStatusEnum._('active');
const ListAdminDevicesRequestStatusEnum
_$listAdminDevicesRequestStatusEnum_revoked =
    const ListAdminDevicesRequestStatusEnum._('revoked');

ListAdminDevicesRequestStatusEnum _$listAdminDevicesRequestStatusEnumValueOf(
  String name,
) {
  switch (name) {
    case 'active':
      return _$listAdminDevicesRequestStatusEnum_active;
    case 'revoked':
      return _$listAdminDevicesRequestStatusEnum_revoked;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<ListAdminDevicesRequestStatusEnum>
_$listAdminDevicesRequestStatusEnumValues =
    BuiltSet<ListAdminDevicesRequestStatusEnum>(
      const <ListAdminDevicesRequestStatusEnum>[
        _$listAdminDevicesRequestStatusEnum_active,
        _$listAdminDevicesRequestStatusEnum_revoked,
      ],
    );

Serializer<ListAdminDevicesRequestStatusEnum>
_$listAdminDevicesRequestStatusEnumSerializer =
    _$ListAdminDevicesRequestStatusEnumSerializer();

class _$ListAdminDevicesRequestStatusEnumSerializer
    implements PrimitiveSerializer<ListAdminDevicesRequestStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'active': 'active',
    'revoked': 'revoked',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'active': 'active',
    'revoked': 'revoked',
  };

  @override
  final Iterable<Type> types = const <Type>[ListAdminDevicesRequestStatusEnum];
  @override
  final String wireName = 'ListAdminDevicesRequestStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    ListAdminDevicesRequestStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  ListAdminDevicesRequestStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => ListAdminDevicesRequestStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$ListAdminDevicesRequest extends ListAdminDevicesRequest {
  @override
  final String? userId;
  @override
  final ListAdminDevicesRequestStatusEnum? status;
  @override
  final int? pageIndex;
  @override
  final int? pageSize;

  factory _$ListAdminDevicesRequest([
    void Function(ListAdminDevicesRequestBuilder)? updates,
  ]) => (ListAdminDevicesRequestBuilder()..update(updates))._build();

  _$ListAdminDevicesRequest._({
    this.userId,
    this.status,
    this.pageIndex,
    this.pageSize,
  }) : super._();
  @override
  ListAdminDevicesRequest rebuild(
    void Function(ListAdminDevicesRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListAdminDevicesRequestBuilder toBuilder() =>
      ListAdminDevicesRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListAdminDevicesRequest &&
        userId == other.userId &&
        status == other.status &&
        pageIndex == other.pageIndex &&
        pageSize == other.pageSize;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, userId.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, pageIndex.hashCode);
    _$hash = $jc(_$hash, pageSize.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ListAdminDevicesRequest')
          ..add('userId', userId)
          ..add('status', status)
          ..add('pageIndex', pageIndex)
          ..add('pageSize', pageSize))
        .toString();
  }
}

class ListAdminDevicesRequestBuilder
    implements
        Builder<ListAdminDevicesRequest, ListAdminDevicesRequestBuilder> {
  _$ListAdminDevicesRequest? _$v;

  String? _userId;
  String? get userId => _$this._userId;
  set userId(String? userId) => _$this._userId = userId;

  ListAdminDevicesRequestStatusEnum? _status;
  ListAdminDevicesRequestStatusEnum? get status => _$this._status;
  set status(ListAdminDevicesRequestStatusEnum? status) =>
      _$this._status = status;

  int? _pageIndex;
  int? get pageIndex => _$this._pageIndex;
  set pageIndex(int? pageIndex) => _$this._pageIndex = pageIndex;

  int? _pageSize;
  int? get pageSize => _$this._pageSize;
  set pageSize(int? pageSize) => _$this._pageSize = pageSize;

  ListAdminDevicesRequestBuilder() {
    ListAdminDevicesRequest._defaults(this);
  }

  ListAdminDevicesRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _userId = $v.userId;
      _status = $v.status;
      _pageIndex = $v.pageIndex;
      _pageSize = $v.pageSize;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListAdminDevicesRequest other) {
    _$v = other as _$ListAdminDevicesRequest;
  }

  @override
  void update(void Function(ListAdminDevicesRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ListAdminDevicesRequest build() => _build();

  _$ListAdminDevicesRequest _build() {
    final _$result =
        _$v ??
        _$ListAdminDevicesRequest._(
          userId: userId,
          status: status,
          pageIndex: pageIndex,
          pageSize: pageSize,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
