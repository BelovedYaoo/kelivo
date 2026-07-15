// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bootstrap_owner_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$BootstrapOwnerData extends BootstrapOwnerData {
  @override
  final UserSummary user;

  factory _$BootstrapOwnerData([
    void Function(BootstrapOwnerDataBuilder)? updates,
  ]) => (BootstrapOwnerDataBuilder()..update(updates))._build();

  _$BootstrapOwnerData._({required this.user}) : super._();
  @override
  BootstrapOwnerData rebuild(
    void Function(BootstrapOwnerDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  BootstrapOwnerDataBuilder toBuilder() =>
      BootstrapOwnerDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is BootstrapOwnerData && user == other.user;
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
      r'BootstrapOwnerData',
    )..add('user', user)).toString();
  }
}

class BootstrapOwnerDataBuilder
    implements Builder<BootstrapOwnerData, BootstrapOwnerDataBuilder> {
  _$BootstrapOwnerData? _$v;

  UserSummaryBuilder? _user;
  UserSummaryBuilder get user => _$this._user ??= UserSummaryBuilder();
  set user(UserSummaryBuilder? user) => _$this._user = user;

  BootstrapOwnerDataBuilder() {
    BootstrapOwnerData._defaults(this);
  }

  BootstrapOwnerDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _user = $v.user.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(BootstrapOwnerData other) {
    _$v = other as _$BootstrapOwnerData;
  }

  @override
  void update(void Function(BootstrapOwnerDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  BootstrapOwnerData build() => _build();

  _$BootstrapOwnerData _build() {
    _$BootstrapOwnerData _$result;
    try {
      _$result = _$v ?? _$BootstrapOwnerData._(user: user.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'user';
        user.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'BootstrapOwnerData',
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
