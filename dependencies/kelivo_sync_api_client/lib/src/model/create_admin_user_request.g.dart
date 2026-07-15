// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_admin_user_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const CreateAdminUserRequestRoleEnum _$createAdminUserRequestRoleEnum_admin =
    const CreateAdminUserRequestRoleEnum._('admin');
const CreateAdminUserRequestRoleEnum _$createAdminUserRequestRoleEnum_user =
    const CreateAdminUserRequestRoleEnum._('user');

CreateAdminUserRequestRoleEnum _$createAdminUserRequestRoleEnumValueOf(
  String name,
) {
  switch (name) {
    case 'admin':
      return _$createAdminUserRequestRoleEnum_admin;
    case 'user':
      return _$createAdminUserRequestRoleEnum_user;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<CreateAdminUserRequestRoleEnum>
_$createAdminUserRequestRoleEnumValues =
    BuiltSet<CreateAdminUserRequestRoleEnum>(
      const <CreateAdminUserRequestRoleEnum>[
        _$createAdminUserRequestRoleEnum_admin,
        _$createAdminUserRequestRoleEnum_user,
      ],
    );

Serializer<CreateAdminUserRequestRoleEnum>
_$createAdminUserRequestRoleEnumSerializer =
    _$CreateAdminUserRequestRoleEnumSerializer();

class _$CreateAdminUserRequestRoleEnumSerializer
    implements PrimitiveSerializer<CreateAdminUserRequestRoleEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'admin': 'admin',
    'user': 'user',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'admin': 'admin',
    'user': 'user',
  };

  @override
  final Iterable<Type> types = const <Type>[CreateAdminUserRequestRoleEnum];
  @override
  final String wireName = 'CreateAdminUserRequestRoleEnum';

  @override
  Object serialize(
    Serializers serializers,
    CreateAdminUserRequestRoleEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  CreateAdminUserRequestRoleEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => CreateAdminUserRequestRoleEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$CreateAdminUserRequest extends CreateAdminUserRequest {
  @override
  final String loginName;
  @override
  final String displayName;
  @override
  final String password;
  @override
  final CreateAdminUserRequestRoleEnum? role;
  @override
  final int? attachmentQuotaBytes;

  factory _$CreateAdminUserRequest([
    void Function(CreateAdminUserRequestBuilder)? updates,
  ]) => (CreateAdminUserRequestBuilder()..update(updates))._build();

  _$CreateAdminUserRequest._({
    required this.loginName,
    required this.displayName,
    required this.password,
    this.role,
    this.attachmentQuotaBytes,
  }) : super._();
  @override
  CreateAdminUserRequest rebuild(
    void Function(CreateAdminUserRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  CreateAdminUserRequestBuilder toBuilder() =>
      CreateAdminUserRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CreateAdminUserRequest &&
        loginName == other.loginName &&
        displayName == other.displayName &&
        password == other.password &&
        role == other.role &&
        attachmentQuotaBytes == other.attachmentQuotaBytes;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, loginName.hashCode);
    _$hash = $jc(_$hash, displayName.hashCode);
    _$hash = $jc(_$hash, password.hashCode);
    _$hash = $jc(_$hash, role.hashCode);
    _$hash = $jc(_$hash, attachmentQuotaBytes.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'CreateAdminUserRequest')
          ..add('loginName', loginName)
          ..add('displayName', displayName)
          ..add('password', password)
          ..add('role', role)
          ..add('attachmentQuotaBytes', attachmentQuotaBytes))
        .toString();
  }
}

class CreateAdminUserRequestBuilder
    implements Builder<CreateAdminUserRequest, CreateAdminUserRequestBuilder> {
  _$CreateAdminUserRequest? _$v;

  String? _loginName;
  String? get loginName => _$this._loginName;
  set loginName(String? loginName) => _$this._loginName = loginName;

  String? _displayName;
  String? get displayName => _$this._displayName;
  set displayName(String? displayName) => _$this._displayName = displayName;

  String? _password;
  String? get password => _$this._password;
  set password(String? password) => _$this._password = password;

  CreateAdminUserRequestRoleEnum? _role;
  CreateAdminUserRequestRoleEnum? get role => _$this._role;
  set role(CreateAdminUserRequestRoleEnum? role) => _$this._role = role;

  int? _attachmentQuotaBytes;
  int? get attachmentQuotaBytes => _$this._attachmentQuotaBytes;
  set attachmentQuotaBytes(int? attachmentQuotaBytes) =>
      _$this._attachmentQuotaBytes = attachmentQuotaBytes;

  CreateAdminUserRequestBuilder() {
    CreateAdminUserRequest._defaults(this);
  }

  CreateAdminUserRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _loginName = $v.loginName;
      _displayName = $v.displayName;
      _password = $v.password;
      _role = $v.role;
      _attachmentQuotaBytes = $v.attachmentQuotaBytes;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CreateAdminUserRequest other) {
    _$v = other as _$CreateAdminUserRequest;
  }

  @override
  void update(void Function(CreateAdminUserRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  CreateAdminUserRequest build() => _build();

  _$CreateAdminUserRequest _build() {
    final _$result =
        _$v ??
        _$CreateAdminUserRequest._(
          loginName: BuiltValueNullFieldError.checkNotNull(
            loginName,
            r'CreateAdminUserRequest',
            'loginName',
          ),
          displayName: BuiltValueNullFieldError.checkNotNull(
            displayName,
            r'CreateAdminUserRequest',
            'displayName',
          ),
          password: BuiltValueNullFieldError.checkNotNull(
            password,
            r'CreateAdminUserRequest',
            'password',
          ),
          role: role,
          attachmentQuotaBytes: attachmentQuotaBytes,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
