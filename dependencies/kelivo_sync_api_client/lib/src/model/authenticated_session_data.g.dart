// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'authenticated_session_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AuthenticatedSessionDataResultEnum
_$authenticatedSessionDataResultEnum_authenticated =
    const AuthenticatedSessionDataResultEnum._('authenticated');

AuthenticatedSessionDataResultEnum _$authenticatedSessionDataResultEnumValueOf(
  String name,
) {
  switch (name) {
    case 'authenticated':
      return _$authenticatedSessionDataResultEnum_authenticated;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AuthenticatedSessionDataResultEnum>
_$authenticatedSessionDataResultEnumValues =
    BuiltSet<AuthenticatedSessionDataResultEnum>(
      const <AuthenticatedSessionDataResultEnum>[
        _$authenticatedSessionDataResultEnum_authenticated,
      ],
    );

Serializer<AuthenticatedSessionDataResultEnum>
_$authenticatedSessionDataResultEnumSerializer =
    _$AuthenticatedSessionDataResultEnumSerializer();

class _$AuthenticatedSessionDataResultEnumSerializer
    implements PrimitiveSerializer<AuthenticatedSessionDataResultEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'authenticated': 'authenticated',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'authenticated': 'authenticated',
  };

  @override
  final Iterable<Type> types = const <Type>[AuthenticatedSessionDataResultEnum];
  @override
  final String wireName = 'AuthenticatedSessionDataResultEnum';

  @override
  Object serialize(
    Serializers serializers,
    AuthenticatedSessionDataResultEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  AuthenticatedSessionDataResultEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => AuthenticatedSessionDataResultEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$AuthenticatedSessionData extends AuthenticatedSessionData {
  @override
  final int protocolVersion;
  @override
  final AuthenticatedSessionDataResultEnum result;
  @override
  final String token;
  @override
  final DateTime tokenExpiresAt;
  @override
  final OpaqueRegistrationFinishDataUser user;
  @override
  final OpaqueRegistrationFinishDataDevice device;
  @override
  final AccountSecurityStateData securityState;

  factory _$AuthenticatedSessionData([
    void Function(AuthenticatedSessionDataBuilder)? updates,
  ]) => (AuthenticatedSessionDataBuilder()..update(updates))._build();

  _$AuthenticatedSessionData._({
    required this.protocolVersion,
    required this.result,
    required this.token,
    required this.tokenExpiresAt,
    required this.user,
    required this.device,
    required this.securityState,
  }) : super._();
  @override
  AuthenticatedSessionData rebuild(
    void Function(AuthenticatedSessionDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AuthenticatedSessionDataBuilder toBuilder() =>
      AuthenticatedSessionDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AuthenticatedSessionData &&
        protocolVersion == other.protocolVersion &&
        result == other.result &&
        token == other.token &&
        tokenExpiresAt == other.tokenExpiresAt &&
        user == other.user &&
        device == other.device &&
        securityState == other.securityState;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, protocolVersion.hashCode);
    _$hash = $jc(_$hash, result.hashCode);
    _$hash = $jc(_$hash, token.hashCode);
    _$hash = $jc(_$hash, tokenExpiresAt.hashCode);
    _$hash = $jc(_$hash, user.hashCode);
    _$hash = $jc(_$hash, device.hashCode);
    _$hash = $jc(_$hash, securityState.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AuthenticatedSessionData')
          ..add('protocolVersion', protocolVersion)
          ..add('result', result)
          ..add('token', token)
          ..add('tokenExpiresAt', tokenExpiresAt)
          ..add('user', user)
          ..add('device', device)
          ..add('securityState', securityState))
        .toString();
  }
}

class AuthenticatedSessionDataBuilder
    implements
        Builder<AuthenticatedSessionData, AuthenticatedSessionDataBuilder> {
  _$AuthenticatedSessionData? _$v;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  AuthenticatedSessionDataResultEnum? _result;
  AuthenticatedSessionDataResultEnum? get result => _$this._result;
  set result(AuthenticatedSessionDataResultEnum? result) =>
      _$this._result = result;

  String? _token;
  String? get token => _$this._token;
  set token(String? token) => _$this._token = token;

  DateTime? _tokenExpiresAt;
  DateTime? get tokenExpiresAt => _$this._tokenExpiresAt;
  set tokenExpiresAt(DateTime? tokenExpiresAt) =>
      _$this._tokenExpiresAt = tokenExpiresAt;

  OpaqueRegistrationFinishDataUserBuilder? _user;
  OpaqueRegistrationFinishDataUserBuilder get user =>
      _$this._user ??= OpaqueRegistrationFinishDataUserBuilder();
  set user(OpaqueRegistrationFinishDataUserBuilder? user) =>
      _$this._user = user;

  OpaqueRegistrationFinishDataDeviceBuilder? _device;
  OpaqueRegistrationFinishDataDeviceBuilder get device =>
      _$this._device ??= OpaqueRegistrationFinishDataDeviceBuilder();
  set device(OpaqueRegistrationFinishDataDeviceBuilder? device) =>
      _$this._device = device;

  AccountSecurityStateDataBuilder? _securityState;
  AccountSecurityStateDataBuilder get securityState =>
      _$this._securityState ??= AccountSecurityStateDataBuilder();
  set securityState(AccountSecurityStateDataBuilder? securityState) =>
      _$this._securityState = securityState;

  AuthenticatedSessionDataBuilder() {
    AuthenticatedSessionData._defaults(this);
  }

  AuthenticatedSessionDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _protocolVersion = $v.protocolVersion;
      _result = $v.result;
      _token = $v.token;
      _tokenExpiresAt = $v.tokenExpiresAt;
      _user = $v.user.toBuilder();
      _device = $v.device.toBuilder();
      _securityState = $v.securityState.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AuthenticatedSessionData other) {
    _$v = other as _$AuthenticatedSessionData;
  }

  @override
  void update(void Function(AuthenticatedSessionDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AuthenticatedSessionData build() => _build();

  _$AuthenticatedSessionData _build() {
    _$AuthenticatedSessionData _$result;
    try {
      _$result =
          _$v ??
          _$AuthenticatedSessionData._(
            protocolVersion: BuiltValueNullFieldError.checkNotNull(
              protocolVersion,
              r'AuthenticatedSessionData',
              'protocolVersion',
            ),
            result: BuiltValueNullFieldError.checkNotNull(
              result,
              r'AuthenticatedSessionData',
              'result',
            ),
            token: BuiltValueNullFieldError.checkNotNull(
              token,
              r'AuthenticatedSessionData',
              'token',
            ),
            tokenExpiresAt: BuiltValueNullFieldError.checkNotNull(
              tokenExpiresAt,
              r'AuthenticatedSessionData',
              'tokenExpiresAt',
            ),
            user: user.build(),
            device: device.build(),
            securityState: securityState.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'user';
        user.build();
        _$failedField = 'device';
        device.build();
        _$failedField = 'securityState';
        securityState.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'AuthenticatedSessionData',
          _$failedField,
          e.toString(),
        );
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
