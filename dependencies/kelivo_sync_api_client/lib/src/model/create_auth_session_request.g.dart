// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_auth_session_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const CreateAuthSessionRequestPlatformEnum
_$createAuthSessionRequestPlatformEnum_android =
    const CreateAuthSessionRequestPlatformEnum._('android');
const CreateAuthSessionRequestPlatformEnum
_$createAuthSessionRequestPlatformEnum_ios =
    const CreateAuthSessionRequestPlatformEnum._('ios');
const CreateAuthSessionRequestPlatformEnum
_$createAuthSessionRequestPlatformEnum_macos =
    const CreateAuthSessionRequestPlatformEnum._('macos');
const CreateAuthSessionRequestPlatformEnum
_$createAuthSessionRequestPlatformEnum_windows =
    const CreateAuthSessionRequestPlatformEnum._('windows');
const CreateAuthSessionRequestPlatformEnum
_$createAuthSessionRequestPlatformEnum_linux =
    const CreateAuthSessionRequestPlatformEnum._('linux');

CreateAuthSessionRequestPlatformEnum
_$createAuthSessionRequestPlatformEnumValueOf(String name) {
  switch (name) {
    case 'android':
      return _$createAuthSessionRequestPlatformEnum_android;
    case 'ios':
      return _$createAuthSessionRequestPlatformEnum_ios;
    case 'macos':
      return _$createAuthSessionRequestPlatformEnum_macos;
    case 'windows':
      return _$createAuthSessionRequestPlatformEnum_windows;
    case 'linux':
      return _$createAuthSessionRequestPlatformEnum_linux;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<CreateAuthSessionRequestPlatformEnum>
_$createAuthSessionRequestPlatformEnumValues =
    BuiltSet<CreateAuthSessionRequestPlatformEnum>(
      const <CreateAuthSessionRequestPlatformEnum>[
        _$createAuthSessionRequestPlatformEnum_android,
        _$createAuthSessionRequestPlatformEnum_ios,
        _$createAuthSessionRequestPlatformEnum_macos,
        _$createAuthSessionRequestPlatformEnum_windows,
        _$createAuthSessionRequestPlatformEnum_linux,
      ],
    );

Serializer<CreateAuthSessionRequestPlatformEnum>
_$createAuthSessionRequestPlatformEnumSerializer =
    _$CreateAuthSessionRequestPlatformEnumSerializer();

class _$CreateAuthSessionRequestPlatformEnumSerializer
    implements PrimitiveSerializer<CreateAuthSessionRequestPlatformEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'android': 'android',
    'ios': 'ios',
    'macos': 'macos',
    'windows': 'windows',
    'linux': 'linux',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'android': 'android',
    'ios': 'ios',
    'macos': 'macos',
    'windows': 'windows',
    'linux': 'linux',
  };

  @override
  final Iterable<Type> types = const <Type>[
    CreateAuthSessionRequestPlatformEnum,
  ];
  @override
  final String wireName = 'CreateAuthSessionRequestPlatformEnum';

  @override
  Object serialize(
    Serializers serializers,
    CreateAuthSessionRequestPlatformEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  CreateAuthSessionRequestPlatformEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => CreateAuthSessionRequestPlatformEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$CreateAuthSessionRequest extends CreateAuthSessionRequest {
  @override
  final String loginName;
  @override
  final String password;
  @override
  final String deviceName;
  @override
  final CreateAuthSessionRequestPlatformEnum platform;
  @override
  final String clientVersion;

  factory _$CreateAuthSessionRequest([
    void Function(CreateAuthSessionRequestBuilder)? updates,
  ]) => (CreateAuthSessionRequestBuilder()..update(updates))._build();

  _$CreateAuthSessionRequest._({
    required this.loginName,
    required this.password,
    required this.deviceName,
    required this.platform,
    required this.clientVersion,
  }) : super._();
  @override
  CreateAuthSessionRequest rebuild(
    void Function(CreateAuthSessionRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  CreateAuthSessionRequestBuilder toBuilder() =>
      CreateAuthSessionRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CreateAuthSessionRequest &&
        loginName == other.loginName &&
        password == other.password &&
        deviceName == other.deviceName &&
        platform == other.platform &&
        clientVersion == other.clientVersion;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, loginName.hashCode);
    _$hash = $jc(_$hash, password.hashCode);
    _$hash = $jc(_$hash, deviceName.hashCode);
    _$hash = $jc(_$hash, platform.hashCode);
    _$hash = $jc(_$hash, clientVersion.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'CreateAuthSessionRequest')
          ..add('loginName', loginName)
          ..add('password', password)
          ..add('deviceName', deviceName)
          ..add('platform', platform)
          ..add('clientVersion', clientVersion))
        .toString();
  }
}

class CreateAuthSessionRequestBuilder
    implements
        Builder<CreateAuthSessionRequest, CreateAuthSessionRequestBuilder> {
  _$CreateAuthSessionRequest? _$v;

  String? _loginName;
  String? get loginName => _$this._loginName;
  set loginName(String? loginName) => _$this._loginName = loginName;

  String? _password;
  String? get password => _$this._password;
  set password(String? password) => _$this._password = password;

  String? _deviceName;
  String? get deviceName => _$this._deviceName;
  set deviceName(String? deviceName) => _$this._deviceName = deviceName;

  CreateAuthSessionRequestPlatformEnum? _platform;
  CreateAuthSessionRequestPlatformEnum? get platform => _$this._platform;
  set platform(CreateAuthSessionRequestPlatformEnum? platform) =>
      _$this._platform = platform;

  String? _clientVersion;
  String? get clientVersion => _$this._clientVersion;
  set clientVersion(String? clientVersion) =>
      _$this._clientVersion = clientVersion;

  CreateAuthSessionRequestBuilder() {
    CreateAuthSessionRequest._defaults(this);
  }

  CreateAuthSessionRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _loginName = $v.loginName;
      _password = $v.password;
      _deviceName = $v.deviceName;
      _platform = $v.platform;
      _clientVersion = $v.clientVersion;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CreateAuthSessionRequest other) {
    _$v = other as _$CreateAuthSessionRequest;
  }

  @override
  void update(void Function(CreateAuthSessionRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  CreateAuthSessionRequest build() => _build();

  _$CreateAuthSessionRequest _build() {
    final _$result =
        _$v ??
        _$CreateAuthSessionRequest._(
          loginName: BuiltValueNullFieldError.checkNotNull(
            loginName,
            r'CreateAuthSessionRequest',
            'loginName',
          ),
          password: BuiltValueNullFieldError.checkNotNull(
            password,
            r'CreateAuthSessionRequest',
            'password',
          ),
          deviceName: BuiltValueNullFieldError.checkNotNull(
            deviceName,
            r'CreateAuthSessionRequest',
            'deviceName',
          ),
          platform: BuiltValueNullFieldError.checkNotNull(
            platform,
            r'CreateAuthSessionRequest',
            'platform',
          ),
          clientVersion: BuiltValueNullFieldError.checkNotNull(
            clientVersion,
            r'CreateAuthSessionRequest',
            'clientVersion',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
