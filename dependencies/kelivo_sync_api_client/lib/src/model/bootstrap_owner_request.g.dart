// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bootstrap_owner_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$BootstrapOwnerRequest extends BootstrapOwnerRequest {
  @override
  final String bootstrapSecret;
  @override
  final String loginName;
  @override
  final String displayName;
  @override
  final String password;

  factory _$BootstrapOwnerRequest([
    void Function(BootstrapOwnerRequestBuilder)? updates,
  ]) => (BootstrapOwnerRequestBuilder()..update(updates))._build();

  _$BootstrapOwnerRequest._({
    required this.bootstrapSecret,
    required this.loginName,
    required this.displayName,
    required this.password,
  }) : super._();
  @override
  BootstrapOwnerRequest rebuild(
    void Function(BootstrapOwnerRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  BootstrapOwnerRequestBuilder toBuilder() =>
      BootstrapOwnerRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is BootstrapOwnerRequest &&
        bootstrapSecret == other.bootstrapSecret &&
        loginName == other.loginName &&
        displayName == other.displayName &&
        password == other.password;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, bootstrapSecret.hashCode);
    _$hash = $jc(_$hash, loginName.hashCode);
    _$hash = $jc(_$hash, displayName.hashCode);
    _$hash = $jc(_$hash, password.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'BootstrapOwnerRequest')
          ..add('bootstrapSecret', bootstrapSecret)
          ..add('loginName', loginName)
          ..add('displayName', displayName)
          ..add('password', password))
        .toString();
  }
}

class BootstrapOwnerRequestBuilder
    implements Builder<BootstrapOwnerRequest, BootstrapOwnerRequestBuilder> {
  _$BootstrapOwnerRequest? _$v;

  String? _bootstrapSecret;
  String? get bootstrapSecret => _$this._bootstrapSecret;
  set bootstrapSecret(String? bootstrapSecret) =>
      _$this._bootstrapSecret = bootstrapSecret;

  String? _loginName;
  String? get loginName => _$this._loginName;
  set loginName(String? loginName) => _$this._loginName = loginName;

  String? _displayName;
  String? get displayName => _$this._displayName;
  set displayName(String? displayName) => _$this._displayName = displayName;

  String? _password;
  String? get password => _$this._password;
  set password(String? password) => _$this._password = password;

  BootstrapOwnerRequestBuilder() {
    BootstrapOwnerRequest._defaults(this);
  }

  BootstrapOwnerRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _bootstrapSecret = $v.bootstrapSecret;
      _loginName = $v.loginName;
      _displayName = $v.displayName;
      _password = $v.password;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(BootstrapOwnerRequest other) {
    _$v = other as _$BootstrapOwnerRequest;
  }

  @override
  void update(void Function(BootstrapOwnerRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  BootstrapOwnerRequest build() => _build();

  _$BootstrapOwnerRequest _build() {
    final _$result =
        _$v ??
        _$BootstrapOwnerRequest._(
          bootstrapSecret: BuiltValueNullFieldError.checkNotNull(
            bootstrapSecret,
            r'BootstrapOwnerRequest',
            'bootstrapSecret',
          ),
          loginName: BuiltValueNullFieldError.checkNotNull(
            loginName,
            r'BootstrapOwnerRequest',
            'loginName',
          ),
          displayName: BuiltValueNullFieldError.checkNotNull(
            displayName,
            r'BootstrapOwnerRequest',
            'displayName',
          ),
          password: BuiltValueNullFieldError.checkNotNull(
            password,
            r'BootstrapOwnerRequest',
            'password',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
