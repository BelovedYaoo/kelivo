// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'opaque_registration_finish_data_user.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const OpaqueRegistrationFinishDataUserRoleEnum
_$opaqueRegistrationFinishDataUserRoleEnum_owner =
    const OpaqueRegistrationFinishDataUserRoleEnum._('owner');
const OpaqueRegistrationFinishDataUserRoleEnum
_$opaqueRegistrationFinishDataUserRoleEnum_admin =
    const OpaqueRegistrationFinishDataUserRoleEnum._('admin');
const OpaqueRegistrationFinishDataUserRoleEnum
_$opaqueRegistrationFinishDataUserRoleEnum_user =
    const OpaqueRegistrationFinishDataUserRoleEnum._('user');

OpaqueRegistrationFinishDataUserRoleEnum
_$opaqueRegistrationFinishDataUserRoleEnumValueOf(String name) {
  switch (name) {
    case 'owner':
      return _$opaqueRegistrationFinishDataUserRoleEnum_owner;
    case 'admin':
      return _$opaqueRegistrationFinishDataUserRoleEnum_admin;
    case 'user':
      return _$opaqueRegistrationFinishDataUserRoleEnum_user;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<OpaqueRegistrationFinishDataUserRoleEnum>
_$opaqueRegistrationFinishDataUserRoleEnumValues =
    BuiltSet<OpaqueRegistrationFinishDataUserRoleEnum>(
      const <OpaqueRegistrationFinishDataUserRoleEnum>[
        _$opaqueRegistrationFinishDataUserRoleEnum_owner,
        _$opaqueRegistrationFinishDataUserRoleEnum_admin,
        _$opaqueRegistrationFinishDataUserRoleEnum_user,
      ],
    );

Serializer<OpaqueRegistrationFinishDataUserRoleEnum>
_$opaqueRegistrationFinishDataUserRoleEnumSerializer =
    _$OpaqueRegistrationFinishDataUserRoleEnumSerializer();

class _$OpaqueRegistrationFinishDataUserRoleEnumSerializer
    implements PrimitiveSerializer<OpaqueRegistrationFinishDataUserRoleEnum> {
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
  final Iterable<Type> types = const <Type>[
    OpaqueRegistrationFinishDataUserRoleEnum,
  ];
  @override
  final String wireName = 'OpaqueRegistrationFinishDataUserRoleEnum';

  @override
  Object serialize(
    Serializers serializers,
    OpaqueRegistrationFinishDataUserRoleEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  OpaqueRegistrationFinishDataUserRoleEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => OpaqueRegistrationFinishDataUserRoleEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$OpaqueRegistrationFinishDataUser
    extends OpaqueRegistrationFinishDataUser {
  @override
  final String id;
  @override
  final String loginName;
  @override
  final String displayName;
  @override
  final OpaqueRegistrationFinishDataUserRoleEnum role;
  @override
  final int attachmentQuotaBytes;

  factory _$OpaqueRegistrationFinishDataUser([
    void Function(OpaqueRegistrationFinishDataUserBuilder)? updates,
  ]) => (OpaqueRegistrationFinishDataUserBuilder()..update(updates))._build();

  _$OpaqueRegistrationFinishDataUser._({
    required this.id,
    required this.loginName,
    required this.displayName,
    required this.role,
    required this.attachmentQuotaBytes,
  }) : super._();
  @override
  OpaqueRegistrationFinishDataUser rebuild(
    void Function(OpaqueRegistrationFinishDataUserBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  OpaqueRegistrationFinishDataUserBuilder toBuilder() =>
      OpaqueRegistrationFinishDataUserBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OpaqueRegistrationFinishDataUser &&
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
    return (newBuiltValueToStringHelper(r'OpaqueRegistrationFinishDataUser')
          ..add('id', id)
          ..add('loginName', loginName)
          ..add('displayName', displayName)
          ..add('role', role)
          ..add('attachmentQuotaBytes', attachmentQuotaBytes))
        .toString();
  }
}

class OpaqueRegistrationFinishDataUserBuilder
    implements
        Builder<
          OpaqueRegistrationFinishDataUser,
          OpaqueRegistrationFinishDataUserBuilder
        > {
  _$OpaqueRegistrationFinishDataUser? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _loginName;
  String? get loginName => _$this._loginName;
  set loginName(String? loginName) => _$this._loginName = loginName;

  String? _displayName;
  String? get displayName => _$this._displayName;
  set displayName(String? displayName) => _$this._displayName = displayName;

  OpaqueRegistrationFinishDataUserRoleEnum? _role;
  OpaqueRegistrationFinishDataUserRoleEnum? get role => _$this._role;
  set role(OpaqueRegistrationFinishDataUserRoleEnum? role) =>
      _$this._role = role;

  int? _attachmentQuotaBytes;
  int? get attachmentQuotaBytes => _$this._attachmentQuotaBytes;
  set attachmentQuotaBytes(int? attachmentQuotaBytes) =>
      _$this._attachmentQuotaBytes = attachmentQuotaBytes;

  OpaqueRegistrationFinishDataUserBuilder() {
    OpaqueRegistrationFinishDataUser._defaults(this);
  }

  OpaqueRegistrationFinishDataUserBuilder get _$this {
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
  void replace(OpaqueRegistrationFinishDataUser other) {
    _$v = other as _$OpaqueRegistrationFinishDataUser;
  }

  @override
  void update(void Function(OpaqueRegistrationFinishDataUserBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  OpaqueRegistrationFinishDataUser build() => _build();

  _$OpaqueRegistrationFinishDataUser _build() {
    final _$result =
        _$v ??
        _$OpaqueRegistrationFinishDataUser._(
          id: BuiltValueNullFieldError.checkNotNull(
            id,
            r'OpaqueRegistrationFinishDataUser',
            'id',
          ),
          loginName: BuiltValueNullFieldError.checkNotNull(
            loginName,
            r'OpaqueRegistrationFinishDataUser',
            'loginName',
          ),
          displayName: BuiltValueNullFieldError.checkNotNull(
            displayName,
            r'OpaqueRegistrationFinishDataUser',
            'displayName',
          ),
          role: BuiltValueNullFieldError.checkNotNull(
            role,
            r'OpaqueRegistrationFinishDataUser',
            'role',
          ),
          attachmentQuotaBytes: BuiltValueNullFieldError.checkNotNull(
            attachmentQuotaBytes,
            r'OpaqueRegistrationFinishDataUser',
            'attachmentQuotaBytes',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
