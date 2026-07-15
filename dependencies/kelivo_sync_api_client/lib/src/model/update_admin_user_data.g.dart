// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_admin_user_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$UpdateAdminUserData extends UpdateAdminUserData {
  @override
  final AdminUserSummary user;

  factory _$UpdateAdminUserData([
    void Function(UpdateAdminUserDataBuilder)? updates,
  ]) => (UpdateAdminUserDataBuilder()..update(updates))._build();

  _$UpdateAdminUserData._({required this.user}) : super._();
  @override
  UpdateAdminUserData rebuild(
    void Function(UpdateAdminUserDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  UpdateAdminUserDataBuilder toBuilder() =>
      UpdateAdminUserDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is UpdateAdminUserData && user == other.user;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, user.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'UpdateAdminUserData',
    )..add('user', user)).toString();
  }
}

class UpdateAdminUserDataBuilder
    implements Builder<UpdateAdminUserData, UpdateAdminUserDataBuilder> {
  _$UpdateAdminUserData? _$v;

  AdminUserSummaryBuilder? _user;
  AdminUserSummaryBuilder get user =>
      _$this._user ??= AdminUserSummaryBuilder();
  set user(AdminUserSummaryBuilder? user) => _$this._user = user;

  UpdateAdminUserDataBuilder() {
    UpdateAdminUserData._defaults(this);
  }

  UpdateAdminUserDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _user = $v.user.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(UpdateAdminUserData other) {
    _$v = other as _$UpdateAdminUserData;
  }

  @override
  void update(void Function(UpdateAdminUserDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  UpdateAdminUserData build() => _build();

  _$UpdateAdminUserData _build() {
    _$UpdateAdminUserData _$result;
    try {
      _$result = _$v ?? _$UpdateAdminUserData._(user: user.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'user';
        user.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'UpdateAdminUserData',
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
