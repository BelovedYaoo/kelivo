// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_admin_user_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$CreateAdminUserData extends CreateAdminUserData {
  @override
  final AdminUserSummary user;

  factory _$CreateAdminUserData([
    void Function(CreateAdminUserDataBuilder)? updates,
  ]) => (CreateAdminUserDataBuilder()..update(updates))._build();

  _$CreateAdminUserData._({required this.user}) : super._();
  @override
  CreateAdminUserData rebuild(
    void Function(CreateAdminUserDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  CreateAdminUserDataBuilder toBuilder() =>
      CreateAdminUserDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CreateAdminUserData && user == other.user;
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
      r'CreateAdminUserData',
    )..add('user', user)).toString();
  }
}

class CreateAdminUserDataBuilder
    implements Builder<CreateAdminUserData, CreateAdminUserDataBuilder> {
  _$CreateAdminUserData? _$v;

  AdminUserSummaryBuilder? _user;
  AdminUserSummaryBuilder get user =>
      _$this._user ??= AdminUserSummaryBuilder();
  set user(AdminUserSummaryBuilder? user) => _$this._user = user;

  CreateAdminUserDataBuilder() {
    CreateAdminUserData._defaults(this);
  }

  CreateAdminUserDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _user = $v.user.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CreateAdminUserData other) {
    _$v = other as _$CreateAdminUserData;
  }

  @override
  void update(void Function(CreateAdminUserDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  CreateAdminUserData build() => _build();

  _$CreateAdminUserData _build() {
    _$CreateAdminUserData _$result;
    try {
      _$result = _$v ?? _$CreateAdminUserData._(user: user.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'user';
        user.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'CreateAdminUserData',
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
