// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_device_user_summary.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AdminDeviceUserSummaryRoleEnum _$adminDeviceUserSummaryRoleEnum_owner =
    const AdminDeviceUserSummaryRoleEnum._('owner');
const AdminDeviceUserSummaryRoleEnum _$adminDeviceUserSummaryRoleEnum_admin =
    const AdminDeviceUserSummaryRoleEnum._('admin');
const AdminDeviceUserSummaryRoleEnum _$adminDeviceUserSummaryRoleEnum_user =
    const AdminDeviceUserSummaryRoleEnum._('user');

AdminDeviceUserSummaryRoleEnum _$adminDeviceUserSummaryRoleEnumValueOf(
  String name,
) {
  switch (name) {
    case 'owner':
      return _$adminDeviceUserSummaryRoleEnum_owner;
    case 'admin':
      return _$adminDeviceUserSummaryRoleEnum_admin;
    case 'user':
      return _$adminDeviceUserSummaryRoleEnum_user;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AdminDeviceUserSummaryRoleEnum>
_$adminDeviceUserSummaryRoleEnumValues =
    BuiltSet<AdminDeviceUserSummaryRoleEnum>(
      const <AdminDeviceUserSummaryRoleEnum>[
        _$adminDeviceUserSummaryRoleEnum_owner,
        _$adminDeviceUserSummaryRoleEnum_admin,
        _$adminDeviceUserSummaryRoleEnum_user,
      ],
    );

Serializer<AdminDeviceUserSummaryRoleEnum>
_$adminDeviceUserSummaryRoleEnumSerializer =
    _$AdminDeviceUserSummaryRoleEnumSerializer();

class _$AdminDeviceUserSummaryRoleEnumSerializer
    implements PrimitiveSerializer<AdminDeviceUserSummaryRoleEnum> {
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
  final Iterable<Type> types = const <Type>[AdminDeviceUserSummaryRoleEnum];
  @override
  final String wireName = 'AdminDeviceUserSummaryRoleEnum';

  @override
  Object serialize(
    Serializers serializers,
    AdminDeviceUserSummaryRoleEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AdminDeviceUserSummaryRoleEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AdminDeviceUserSummaryRoleEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AdminDeviceUserSummary extends AdminDeviceUserSummary {
  @override
  final String id;
  @override
  final String loginName;
  @override
  final String displayName;
  @override
  final AdminDeviceUserSummaryRoleEnum role;

  factory _$AdminDeviceUserSummary([
    void Function(AdminDeviceUserSummaryBuilder)? updates,
  ]) => (AdminDeviceUserSummaryBuilder()..update(updates))._build();

  _$AdminDeviceUserSummary._({
    required this.id,
    required this.loginName,
    required this.displayName,
    required this.role,
  }) : super._();
  @override
  AdminDeviceUserSummary rebuild(
    void Function(AdminDeviceUserSummaryBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AdminDeviceUserSummaryBuilder toBuilder() =>
      AdminDeviceUserSummaryBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AdminDeviceUserSummary &&
        id == other.id &&
        loginName == other.loginName &&
        displayName == other.displayName &&
        role == other.role;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, loginName.hashCode);
    _$hash = $jc(_$hash, displayName.hashCode);
    _$hash = $jc(_$hash, role.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AdminDeviceUserSummary')
          ..add('id', id)
          ..add('loginName', loginName)
          ..add('displayName', displayName)
          ..add('role', role))
        .toString();
  }
}

class AdminDeviceUserSummaryBuilder
    implements Builder<AdminDeviceUserSummary, AdminDeviceUserSummaryBuilder> {
  _$AdminDeviceUserSummary? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _loginName;
  String? get loginName => _$this._loginName;
  set loginName(String? loginName) => _$this._loginName = loginName;

  String? _displayName;
  String? get displayName => _$this._displayName;
  set displayName(String? displayName) => _$this._displayName = displayName;

  AdminDeviceUserSummaryRoleEnum? _role;
  AdminDeviceUserSummaryRoleEnum? get role => _$this._role;
  set role(AdminDeviceUserSummaryRoleEnum? role) => _$this._role = role;

  AdminDeviceUserSummaryBuilder() {
    AdminDeviceUserSummary._defaults(this);
  }

  AdminDeviceUserSummaryBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _loginName = $v.loginName;
      _displayName = $v.displayName;
      _role = $v.role;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AdminDeviceUserSummary other) {
    _$v = other as _$AdminDeviceUserSummary;
  }

  @override
  void update(void Function(AdminDeviceUserSummaryBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AdminDeviceUserSummary build() => _build();

  _$AdminDeviceUserSummary _build() {
    final _$result =
        _$v ??
        _$AdminDeviceUserSummary._(
          id: BuiltValueNullFieldError.checkNotNull(
            id,
            r'AdminDeviceUserSummary',
            'id',
          ),
          loginName: BuiltValueNullFieldError.checkNotNull(
            loginName,
            r'AdminDeviceUserSummary',
            'loginName',
          ),
          displayName: BuiltValueNullFieldError.checkNotNull(
            displayName,
            r'AdminDeviceUserSummary',
            'displayName',
          ),
          role: BuiltValueNullFieldError.checkNotNull(
            role,
            r'AdminDeviceUserSummary',
            'role',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
