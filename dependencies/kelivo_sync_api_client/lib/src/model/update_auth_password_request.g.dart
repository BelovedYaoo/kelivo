// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_auth_password_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$UpdateAuthPasswordRequest extends UpdateAuthPasswordRequest {
  @override
  final String currentPassword;
  @override
  final String newPassword;

  factory _$UpdateAuthPasswordRequest([
    void Function(UpdateAuthPasswordRequestBuilder)? updates,
  ]) => (UpdateAuthPasswordRequestBuilder()..update(updates))._build();

  _$UpdateAuthPasswordRequest._({
    required this.currentPassword,
    required this.newPassword,
  }) : super._();
  @override
  UpdateAuthPasswordRequest rebuild(
    void Function(UpdateAuthPasswordRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  UpdateAuthPasswordRequestBuilder toBuilder() =>
      UpdateAuthPasswordRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is UpdateAuthPasswordRequest &&
        currentPassword == other.currentPassword &&
        newPassword == other.newPassword;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, currentPassword.hashCode);
    _$hash = $jc(_$hash, newPassword.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'UpdateAuthPasswordRequest')
          ..add('currentPassword', currentPassword)
          ..add('newPassword', newPassword))
        .toString();
  }
}

class UpdateAuthPasswordRequestBuilder
    implements
        Builder<UpdateAuthPasswordRequest, UpdateAuthPasswordRequestBuilder> {
  _$UpdateAuthPasswordRequest? _$v;

  String? _currentPassword;
  String? get currentPassword => _$this._currentPassword;
  set currentPassword(String? currentPassword) =>
      _$this._currentPassword = currentPassword;

  String? _newPassword;
  String? get newPassword => _$this._newPassword;
  set newPassword(String? newPassword) => _$this._newPassword = newPassword;

  UpdateAuthPasswordRequestBuilder() {
    UpdateAuthPasswordRequest._defaults(this);
  }

  UpdateAuthPasswordRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _currentPassword = $v.currentPassword;
      _newPassword = $v.newPassword;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(UpdateAuthPasswordRequest other) {
    _$v = other as _$UpdateAuthPasswordRequest;
  }

  @override
  void update(void Function(UpdateAuthPasswordRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  UpdateAuthPasswordRequest build() => _build();

  _$UpdateAuthPasswordRequest _build() {
    final _$result =
        _$v ??
        _$UpdateAuthPasswordRequest._(
          currentPassword: BuiltValueNullFieldError.checkNotNull(
            currentPassword,
            r'UpdateAuthPasswordRequest',
            'currentPassword',
          ),
          newPassword: BuiltValueNullFieldError.checkNotNull(
            newPassword,
            r'UpdateAuthPasswordRequest',
            'newPassword',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
