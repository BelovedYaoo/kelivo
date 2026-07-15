// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_summary.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const UserSummaryRoleEnum _$userSummaryRoleEnum_owner =
    const UserSummaryRoleEnum._('owner');
const UserSummaryRoleEnum _$userSummaryRoleEnum_admin =
    const UserSummaryRoleEnum._('admin');
const UserSummaryRoleEnum _$userSummaryRoleEnum_user =
    const UserSummaryRoleEnum._('user');

UserSummaryRoleEnum _$userSummaryRoleEnumValueOf(String name) {
  switch (name) {
    case 'owner':
      return _$userSummaryRoleEnum_owner;
    case 'admin':
      return _$userSummaryRoleEnum_admin;
    case 'user':
      return _$userSummaryRoleEnum_user;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<UserSummaryRoleEnum> _$userSummaryRoleEnumValues =
    BuiltSet<UserSummaryRoleEnum>(const <UserSummaryRoleEnum>[
      _$userSummaryRoleEnum_owner,
      _$userSummaryRoleEnum_admin,
      _$userSummaryRoleEnum_user,
    ]);

Serializer<UserSummaryRoleEnum> _$userSummaryRoleEnumSerializer =
    _$UserSummaryRoleEnumSerializer();

class _$UserSummaryRoleEnumSerializer
    implements PrimitiveSerializer<UserSummaryRoleEnum> {
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
  final Iterable<Type> types = const <Type>[UserSummaryRoleEnum];
  @override
  final String wireName = 'UserSummaryRoleEnum';

  @override
  Object serialize(
    Serializers serializers,
    UserSummaryRoleEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  UserSummaryRoleEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => UserSummaryRoleEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$UserSummary extends UserSummary {
  @override
  final String id;
  @override
  final String loginName;
  @override
  final String displayName;
  @override
  final UserSummaryRoleEnum role;
  @override
  final int attachmentQuotaBytes;

  factory _$UserSummary([void Function(UserSummaryBuilder)? updates]) =>
      (UserSummaryBuilder()..update(updates))._build();

  _$UserSummary._({
    required this.id,
    required this.loginName,
    required this.displayName,
    required this.role,
    required this.attachmentQuotaBytes,
  }) : super._();
  @override
  UserSummary rebuild(void Function(UserSummaryBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  UserSummaryBuilder toBuilder() => UserSummaryBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is UserSummary &&
        id == other.id &&
        loginName == other.loginName &&
        displayName == other.displayName &&
        role == other.role &&
        attachmentQuotaBytes == other.attachmentQuotaBytes;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, loginName.hashCode);
    _$hash = $jc(_$hash, displayName.hashCode);
    _$hash = $jc(_$hash, role.hashCode);
    _$hash = $jc(_$hash, attachmentQuotaBytes.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'UserSummary')
          ..add('id', id)
          ..add('loginName', loginName)
          ..add('displayName', displayName)
          ..add('role', role)
          ..add('attachmentQuotaBytes', attachmentQuotaBytes))
        .toString();
  }
}

class UserSummaryBuilder implements Builder<UserSummary, UserSummaryBuilder> {
  _$UserSummary? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _loginName;
  String? get loginName => _$this._loginName;
  set loginName(String? loginName) => _$this._loginName = loginName;

  String? _displayName;
  String? get displayName => _$this._displayName;
  set displayName(String? displayName) => _$this._displayName = displayName;

  UserSummaryRoleEnum? _role;
  UserSummaryRoleEnum? get role => _$this._role;
  set role(UserSummaryRoleEnum? role) => _$this._role = role;

  int? _attachmentQuotaBytes;
  int? get attachmentQuotaBytes => _$this._attachmentQuotaBytes;
  set attachmentQuotaBytes(int? attachmentQuotaBytes) =>
      _$this._attachmentQuotaBytes = attachmentQuotaBytes;

  UserSummaryBuilder() {
    UserSummary._defaults(this);
  }

  UserSummaryBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _loginName = $v.loginName;
      _displayName = $v.displayName;
      _role = $v.role;
      _attachmentQuotaBytes = $v.attachmentQuotaBytes;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(UserSummary other) {
    _$v = other as _$UserSummary;
  }

  @override
  void update(void Function(UserSummaryBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  UserSummary build() => _build();

  _$UserSummary _build() {
    final _$result =
        _$v ??
        _$UserSummary._(
          id: BuiltValueNullFieldError.checkNotNull(id, r'UserSummary', 'id'),
          loginName: BuiltValueNullFieldError.checkNotNull(
            loginName,
            r'UserSummary',
            'loginName',
          ),
          displayName: BuiltValueNullFieldError.checkNotNull(
            displayName,
            r'UserSummary',
            'displayName',
          ),
          role: BuiltValueNullFieldError.checkNotNull(
            role,
            r'UserSummary',
            'role',
          ),
          attachmentQuotaBytes: BuiltValueNullFieldError.checkNotNull(
            attachmentQuotaBytes,
            r'UserSummary',
            'attachmentQuotaBytes',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
