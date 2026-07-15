// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_session_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AuthSessionData extends AuthSessionData {
  @override
  final String token;
  @override
  final UserSummary user;
  @override
  final AuthDeviceSummary device;

  factory _$AuthSessionData([void Function(AuthSessionDataBuilder)? updates]) =>
      (AuthSessionDataBuilder()..update(updates))._build();

  _$AuthSessionData._({
    required this.token,
    required this.user,
    required this.device,
  }) : super._();
  @override
  AuthSessionData rebuild(void Function(AuthSessionDataBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AuthSessionDataBuilder toBuilder() => AuthSessionDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AuthSessionData &&
        token == other.token &&
        user == other.user &&
        device == other.device;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, token.hashCode);
    _$hash = $jc(_$hash, user.hashCode);
    _$hash = $jc(_$hash, device.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AuthSessionData')
          ..add('token', token)
          ..add('user', user)
          ..add('device', device))
        .toString();
  }
}

class AuthSessionDataBuilder
    implements Builder<AuthSessionData, AuthSessionDataBuilder> {
  _$AuthSessionData? _$v;

  String? _token;
  String? get token => _$this._token;
  set token(String? token) => _$this._token = token;

  UserSummaryBuilder? _user;
  UserSummaryBuilder get user => _$this._user ??= UserSummaryBuilder();
  set user(UserSummaryBuilder? user) => _$this._user = user;

  AuthDeviceSummaryBuilder? _device;
  AuthDeviceSummaryBuilder get device =>
      _$this._device ??= AuthDeviceSummaryBuilder();
  set device(AuthDeviceSummaryBuilder? device) => _$this._device = device;

  AuthSessionDataBuilder() {
    AuthSessionData._defaults(this);
  }

  AuthSessionDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _token = $v.token;
      _user = $v.user.toBuilder();
      _device = $v.device.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AuthSessionData other) {
    _$v = other as _$AuthSessionData;
  }

  @override
  void update(void Function(AuthSessionDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AuthSessionData build() => _build();

  _$AuthSessionData _build() {
    _$AuthSessionData _$result;
    try {
      _$result =
          _$v ??
          _$AuthSessionData._(
            token: BuiltValueNullFieldError.checkNotNull(
              token,
              r'AuthSessionData',
              'token',
            ),
            user: user.build(),
            device: device.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'user';
        user.build();
        _$failedField = 'device';
        device.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'AuthSessionData',
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
