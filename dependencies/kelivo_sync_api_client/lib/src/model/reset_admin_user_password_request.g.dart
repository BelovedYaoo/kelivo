// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reset_admin_user_password_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ResetAdminUserPasswordRequest extends ResetAdminUserPasswordRequest {
  @override
  final String userId;
  @override
  final String newPassword;

  factory _$ResetAdminUserPasswordRequest([
    void Function(ResetAdminUserPasswordRequestBuilder)? updates,
  ]) => (ResetAdminUserPasswordRequestBuilder()..update(updates))._build();

  _$ResetAdminUserPasswordRequest._({
    required this.userId,
    required this.newPassword,
  }) : super._();
  @override
  ResetAdminUserPasswordRequest rebuild(
    void Function(ResetAdminUserPasswordRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ResetAdminUserPasswordRequestBuilder toBuilder() =>
      ResetAdminUserPasswordRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ResetAdminUserPasswordRequest &&
        userId == other.userId &&
        newPassword == other.newPassword;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, userId.hashCode);
    _$hash = $jc(_$hash, newPassword.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ResetAdminUserPasswordRequest')
          ..add('userId', userId)
          ..add('newPassword', newPassword))
        .toString();
  }
}

class ResetAdminUserPasswordRequestBuilder
    implements
        Builder<
          ResetAdminUserPasswordRequest,
          ResetAdminUserPasswordRequestBuilder
        > {
  _$ResetAdminUserPasswordRequest? _$v;

  String? _userId;
  String? get userId => _$this._userId;
  set userId(String? userId) => _$this._userId = userId;

  String? _newPassword;
  String? get newPassword => _$this._newPassword;
  set newPassword(String? newPassword) => _$this._newPassword = newPassword;

  ResetAdminUserPasswordRequestBuilder() {
    ResetAdminUserPasswordRequest._defaults(this);
  }

  ResetAdminUserPasswordRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _userId = $v.userId;
      _newPassword = $v.newPassword;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ResetAdminUserPasswordRequest other) {
    _$v = other as _$ResetAdminUserPasswordRequest;
  }

  @override
  void update(void Function(ResetAdminUserPasswordRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ResetAdminUserPasswordRequest build() => _build();

  _$ResetAdminUserPasswordRequest _build() {
    final _$result =
        _$v ??
        _$ResetAdminUserPasswordRequest._(
          userId: BuiltValueNullFieldError.checkNotNull(
            userId,
            r'ResetAdminUserPasswordRequest',
            'userId',
          ),
          newPassword: BuiltValueNullFieldError.checkNotNull(
            newPassword,
            r'ResetAdminUserPasswordRequest',
            'newPassword',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
