// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_user_summary.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AdminUserSummaryRoleEnum _$adminUserSummaryRoleEnum_owner =
    const AdminUserSummaryRoleEnum._('owner');
const AdminUserSummaryRoleEnum _$adminUserSummaryRoleEnum_admin =
    const AdminUserSummaryRoleEnum._('admin');
const AdminUserSummaryRoleEnum _$adminUserSummaryRoleEnum_user =
    const AdminUserSummaryRoleEnum._('user');

AdminUserSummaryRoleEnum _$adminUserSummaryRoleEnumValueOf(String name) {
  switch (name) {
    case 'owner':
      return _$adminUserSummaryRoleEnum_owner;
    case 'admin':
      return _$adminUserSummaryRoleEnum_admin;
    case 'user':
      return _$adminUserSummaryRoleEnum_user;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AdminUserSummaryRoleEnum> _$adminUserSummaryRoleEnumValues =
    BuiltSet<AdminUserSummaryRoleEnum>(const <AdminUserSummaryRoleEnum>[
      _$adminUserSummaryRoleEnum_owner,
      _$adminUserSummaryRoleEnum_admin,
      _$adminUserSummaryRoleEnum_user,
    ]);

const AdminUserSummaryStatusEnum _$adminUserSummaryStatusEnum_active =
    const AdminUserSummaryStatusEnum._('active');
const AdminUserSummaryStatusEnum _$adminUserSummaryStatusEnum_disabled =
    const AdminUserSummaryStatusEnum._('disabled');

AdminUserSummaryStatusEnum _$adminUserSummaryStatusEnumValueOf(String name) {
  switch (name) {
    case 'active':
      return _$adminUserSummaryStatusEnum_active;
    case 'disabled':
      return _$adminUserSummaryStatusEnum_disabled;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AdminUserSummaryStatusEnum> _$adminUserSummaryStatusEnumValues =
    BuiltSet<AdminUserSummaryStatusEnum>(const <AdminUserSummaryStatusEnum>[
      _$adminUserSummaryStatusEnum_active,
      _$adminUserSummaryStatusEnum_disabled,
    ]);

Serializer<AdminUserSummaryRoleEnum> _$adminUserSummaryRoleEnumSerializer =
    _$AdminUserSummaryRoleEnumSerializer();
Serializer<AdminUserSummaryStatusEnum> _$adminUserSummaryStatusEnumSerializer =
    _$AdminUserSummaryStatusEnumSerializer();

class _$AdminUserSummaryRoleEnumSerializer
    implements PrimitiveSerializer<AdminUserSummaryRoleEnum> {
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
  final Iterable<Type> types = const <Type>[AdminUserSummaryRoleEnum];
  @override
  final String wireName = 'AdminUserSummaryRoleEnum';

  @override
  Object serialize(
    Serializers serializers,
    AdminUserSummaryRoleEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AdminUserSummaryRoleEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AdminUserSummaryRoleEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AdminUserSummaryStatusEnumSerializer
    implements PrimitiveSerializer<AdminUserSummaryStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'active': 'active',
    'disabled': 'disabled',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'active': 'active',
    'disabled': 'disabled',
  };

  @override
  final Iterable<Type> types = const <Type>[AdminUserSummaryStatusEnum];
  @override
  final String wireName = 'AdminUserSummaryStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    AdminUserSummaryStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AdminUserSummaryStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AdminUserSummaryStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AdminUserSummary extends AdminUserSummary {
  @override
  final String id;
  @override
  final String loginName;
  @override
  final String displayName;
  @override
  final AdminUserSummaryRoleEnum role;
  @override
  final AdminUserSummaryStatusEnum status;
  @override
  final int attachmentQuotaBytes;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? disabledAt;

  factory _$AdminUserSummary([
    void Function(AdminUserSummaryBuilder)? updates,
  ]) => (AdminUserSummaryBuilder()..update(updates))._build();

  _$AdminUserSummary._({
    required this.id,
    required this.loginName,
    required this.displayName,
    required this.role,
    required this.status,
    required this.attachmentQuotaBytes,
    required this.createdAt,
    required this.updatedAt,
    this.disabledAt,
  }) : super._();
  @override
  AdminUserSummary rebuild(void Function(AdminUserSummaryBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AdminUserSummaryBuilder toBuilder() =>
      AdminUserSummaryBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AdminUserSummary &&
        id == other.id &&
        loginName == other.loginName &&
        displayName == other.displayName &&
        role == other.role &&
        status == other.status &&
        attachmentQuotaBytes == other.attachmentQuotaBytes &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt &&
        disabledAt == other.disabledAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, loginName.hashCode);
    _$hash = $jc(_$hash, displayName.hashCode);
    _$hash = $jc(_$hash, role.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, attachmentQuotaBytes.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jc(_$hash, disabledAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AdminUserSummary')
          ..add('id', id)
          ..add('loginName', loginName)
          ..add('displayName', displayName)
          ..add('role', role)
          ..add('status', status)
          ..add('attachmentQuotaBytes', attachmentQuotaBytes)
          ..add('createdAt', createdAt)
          ..add('updatedAt', updatedAt)
          ..add('disabledAt', disabledAt))
        .toString();
  }
}

class AdminUserSummaryBuilder
    implements Builder<AdminUserSummary, AdminUserSummaryBuilder> {
  _$AdminUserSummary? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _loginName;
  String? get loginName => _$this._loginName;
  set loginName(String? loginName) => _$this._loginName = loginName;

  String? _displayName;
  String? get displayName => _$this._displayName;
  set displayName(String? displayName) => _$this._displayName = displayName;

  AdminUserSummaryRoleEnum? _role;
  AdminUserSummaryRoleEnum? get role => _$this._role;
  set role(AdminUserSummaryRoleEnum? role) => _$this._role = role;

  AdminUserSummaryStatusEnum? _status;
  AdminUserSummaryStatusEnum? get status => _$this._status;
  set status(AdminUserSummaryStatusEnum? status) => _$this._status = status;

  int? _attachmentQuotaBytes;
  int? get attachmentQuotaBytes => _$this._attachmentQuotaBytes;
  set attachmentQuotaBytes(int? attachmentQuotaBytes) =>
      _$this._attachmentQuotaBytes = attachmentQuotaBytes;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _$this._updatedAt;
  set updatedAt(DateTime? updatedAt) => _$this._updatedAt = updatedAt;

  DateTime? _disabledAt;
  DateTime? get disabledAt => _$this._disabledAt;
  set disabledAt(DateTime? disabledAt) => _$this._disabledAt = disabledAt;

  AdminUserSummaryBuilder() {
    AdminUserSummary._defaults(this);
  }

  AdminUserSummaryBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _loginName = $v.loginName;
      _displayName = $v.displayName;
      _role = $v.role;
      _status = $v.status;
      _attachmentQuotaBytes = $v.attachmentQuotaBytes;
      _createdAt = $v.createdAt;
      _updatedAt = $v.updatedAt;
      _disabledAt = $v.disabledAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AdminUserSummary other) {
    _$v = other as _$AdminUserSummary;
  }

  @override
  void update(void Function(AdminUserSummaryBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AdminUserSummary build() => _build();

  _$AdminUserSummary _build() {
    final _$result =
        _$v ??
        _$AdminUserSummary._(
          id: BuiltValueNullFieldError.checkNotNull(
            id,
            r'AdminUserSummary',
            'id',
          ),
          loginName: BuiltValueNullFieldError.checkNotNull(
            loginName,
            r'AdminUserSummary',
            'loginName',
          ),
          displayName: BuiltValueNullFieldError.checkNotNull(
            displayName,
            r'AdminUserSummary',
            'displayName',
          ),
          role: BuiltValueNullFieldError.checkNotNull(
            role,
            r'AdminUserSummary',
            'role',
          ),
          status: BuiltValueNullFieldError.checkNotNull(
            status,
            r'AdminUserSummary',
            'status',
          ),
          attachmentQuotaBytes: BuiltValueNullFieldError.checkNotNull(
            attachmentQuotaBytes,
            r'AdminUserSummary',
            'attachmentQuotaBytes',
          ),
          createdAt: BuiltValueNullFieldError.checkNotNull(
            createdAt,
            r'AdminUserSummary',
            'createdAt',
          ),
          updatedAt: BuiltValueNullFieldError.checkNotNull(
            updatedAt,
            r'AdminUserSummary',
            'updatedAt',
          ),
          disabledAt: disabledAt,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
