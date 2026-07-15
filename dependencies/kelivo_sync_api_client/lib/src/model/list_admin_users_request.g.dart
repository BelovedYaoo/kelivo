// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_users_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const ListAdminUsersRequestRoleEnum _$listAdminUsersRequestRoleEnum_owner =
    const ListAdminUsersRequestRoleEnum._('owner');
const ListAdminUsersRequestRoleEnum _$listAdminUsersRequestRoleEnum_admin =
    const ListAdminUsersRequestRoleEnum._('admin');
const ListAdminUsersRequestRoleEnum _$listAdminUsersRequestRoleEnum_user =
    const ListAdminUsersRequestRoleEnum._('user');

ListAdminUsersRequestRoleEnum _$listAdminUsersRequestRoleEnumValueOf(
  String name,
) {
  switch (name) {
    case 'owner':
      return _$listAdminUsersRequestRoleEnum_owner;
    case 'admin':
      return _$listAdminUsersRequestRoleEnum_admin;
    case 'user':
      return _$listAdminUsersRequestRoleEnum_user;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<ListAdminUsersRequestRoleEnum>
_$listAdminUsersRequestRoleEnumValues = BuiltSet<ListAdminUsersRequestRoleEnum>(
  const <ListAdminUsersRequestRoleEnum>[
    _$listAdminUsersRequestRoleEnum_owner,
    _$listAdminUsersRequestRoleEnum_admin,
    _$listAdminUsersRequestRoleEnum_user,
  ],
);

const ListAdminUsersRequestStatusEnum _$listAdminUsersRequestStatusEnum_active =
    const ListAdminUsersRequestStatusEnum._('active');
const ListAdminUsersRequestStatusEnum
_$listAdminUsersRequestStatusEnum_disabled =
    const ListAdminUsersRequestStatusEnum._('disabled');

ListAdminUsersRequestStatusEnum _$listAdminUsersRequestStatusEnumValueOf(
  String name,
) {
  switch (name) {
    case 'active':
      return _$listAdminUsersRequestStatusEnum_active;
    case 'disabled':
      return _$listAdminUsersRequestStatusEnum_disabled;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<ListAdminUsersRequestStatusEnum>
_$listAdminUsersRequestStatusEnumValues =
    BuiltSet<ListAdminUsersRequestStatusEnum>(
      const <ListAdminUsersRequestStatusEnum>[
        _$listAdminUsersRequestStatusEnum_active,
        _$listAdminUsersRequestStatusEnum_disabled,
      ],
    );

Serializer<ListAdminUsersRequestRoleEnum>
_$listAdminUsersRequestRoleEnumSerializer =
    _$ListAdminUsersRequestRoleEnumSerializer();
Serializer<ListAdminUsersRequestStatusEnum>
_$listAdminUsersRequestStatusEnumSerializer =
    _$ListAdminUsersRequestStatusEnumSerializer();

class _$ListAdminUsersRequestRoleEnumSerializer
    implements PrimitiveSerializer<ListAdminUsersRequestRoleEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'owner': 'owner',
    'admin': 'admin',
    'user': 'user',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'owner': 'owner',
    'admin': 'admin',
    'user': 'user',
  };

  @override
  final Iterable<Type> types = const <Type>[ListAdminUsersRequestRoleEnum];
  @override
  final String wireName = 'ListAdminUsersRequestRoleEnum';

  @override
  Object serialize(
    Serializers serializers,
    ListAdminUsersRequestRoleEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  ListAdminUsersRequestRoleEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => ListAdminUsersRequestRoleEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$ListAdminUsersRequestStatusEnumSerializer
    implements PrimitiveSerializer<ListAdminUsersRequestStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'active': 'active',
    'disabled': 'disabled',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'active': 'active',
    'disabled': 'disabled',
  };

  @override
  final Iterable<Type> types = const <Type>[ListAdminUsersRequestStatusEnum];
  @override
  final String wireName = 'ListAdminUsersRequestStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    ListAdminUsersRequestStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  ListAdminUsersRequestStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => ListAdminUsersRequestStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$ListAdminUsersRequest extends ListAdminUsersRequest {
  @override
  final String? keyword;
  @override
  final ListAdminUsersRequestRoleEnum? role;
  @override
  final ListAdminUsersRequestStatusEnum? status;
  @override
  final int? pageIndex;
  @override
  final int? pageSize;

  factory _$ListAdminUsersRequest([
    void Function(ListAdminUsersRequestBuilder)? updates,
  ]) => (ListAdminUsersRequestBuilder()..update(updates))._build();

  _$ListAdminUsersRequest._({
    this.keyword,
    this.role,
    this.status,
    this.pageIndex,
    this.pageSize,
  }) : super._();
  @override
  ListAdminUsersRequest rebuild(
    void Function(ListAdminUsersRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListAdminUsersRequestBuilder toBuilder() =>
      ListAdminUsersRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListAdminUsersRequest &&
        keyword == other.keyword &&
        role == other.role &&
        status == other.status &&
        pageIndex == other.pageIndex &&
        pageSize == other.pageSize;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, keyword.hashCode);
    _$hash = $jc(_$hash, role.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, pageIndex.hashCode);
    _$hash = $jc(_$hash, pageSize.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ListAdminUsersRequest')
          ..add('keyword', keyword)
          ..add('role', role)
          ..add('status', status)
          ..add('pageIndex', pageIndex)
          ..add('pageSize', pageSize))
        .toString();
  }
}

class ListAdminUsersRequestBuilder
    implements Builder<ListAdminUsersRequest, ListAdminUsersRequestBuilder> {
  _$ListAdminUsersRequest? _$v;

  String? _keyword;
  String? get keyword => _$this._keyword;
  set keyword(String? keyword) => _$this._keyword = keyword;

  ListAdminUsersRequestRoleEnum? _role;
  ListAdminUsersRequestRoleEnum? get role => _$this._role;
  set role(ListAdminUsersRequestRoleEnum? role) => _$this._role = role;

  ListAdminUsersRequestStatusEnum? _status;
  ListAdminUsersRequestStatusEnum? get status => _$this._status;
  set status(ListAdminUsersRequestStatusEnum? status) =>
      _$this._status = status;

  int? _pageIndex;
  int? get pageIndex => _$this._pageIndex;
  set pageIndex(int? pageIndex) => _$this._pageIndex = pageIndex;

  int? _pageSize;
  int? get pageSize => _$this._pageSize;
  set pageSize(int? pageSize) => _$this._pageSize = pageSize;

  ListAdminUsersRequestBuilder() {
    ListAdminUsersRequest._defaults(this);
  }

  ListAdminUsersRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _keyword = $v.keyword;
      _role = $v.role;
      _status = $v.status;
      _pageIndex = $v.pageIndex;
      _pageSize = $v.pageSize;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListAdminUsersRequest other) {
    _$v = other as _$ListAdminUsersRequest;
  }

  @override
  void update(void Function(ListAdminUsersRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ListAdminUsersRequest build() => _build();

  _$ListAdminUsersRequest _build() {
    final _$result =
        _$v ??
        _$ListAdminUsersRequest._(
          keyword: keyword,
          role: role,
          status: status,
          pageIndex: pageIndex,
          pageSize: pageSize,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
