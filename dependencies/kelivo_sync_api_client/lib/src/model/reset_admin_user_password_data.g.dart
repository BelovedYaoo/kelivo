// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reset_admin_user_password_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ResetAdminUserPasswordData extends ResetAdminUserPasswordData {
  @override
  final bool updated;
  @override
  final bool sessionsRevoked;

  factory _$ResetAdminUserPasswordData([
    void Function(ResetAdminUserPasswordDataBuilder)? updates,
  ]) => (ResetAdminUserPasswordDataBuilder()..update(updates))._build();

  _$ResetAdminUserPasswordData._({
    required this.updated,
    required this.sessionsRevoked,
  }) : super._();
  @override
  ResetAdminUserPasswordData rebuild(
    void Function(ResetAdminUserPasswordDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ResetAdminUserPasswordDataBuilder toBuilder() =>
      ResetAdminUserPasswordDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ResetAdminUserPasswordData &&
        updated == other.updated &&
        sessionsRevoked == other.sessionsRevoked;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, updated.hashCode);
    _$hash = $jc(_$hash, sessionsRevoked.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ResetAdminUserPasswordData')
          ..add('updated', updated)
          ..add('sessionsRevoked', sessionsRevoked))
        .toString();
  }
}

class ResetAdminUserPasswordDataBuilder
    implements
        Builder<ResetAdminUserPasswordData, ResetAdminUserPasswordDataBuilder> {
  _$ResetAdminUserPasswordData? _$v;

  bool? _updated;
  bool? get updated => _$this._updated;
  set updated(bool? updated) => _$this._updated = updated;

  bool? _sessionsRevoked;
  bool? get sessionsRevoked => _$this._sessionsRevoked;
  set sessionsRevoked(bool? sessionsRevoked) =>
      _$this._sessionsRevoked = sessionsRevoked;

  ResetAdminUserPasswordDataBuilder() {
    ResetAdminUserPasswordData._defaults(this);
  }

  ResetAdminUserPasswordDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _updated = $v.updated;
      _sessionsRevoked = $v.sessionsRevoked;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ResetAdminUserPasswordData other) {
    _$v = other as _$ResetAdminUserPasswordData;
  }

  @override
  void update(void Function(ResetAdminUserPasswordDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ResetAdminUserPasswordData build() => _build();

  _$ResetAdminUserPasswordData _build() {
    final _$result =
        _$v ??
        _$ResetAdminUserPasswordData._(
          updated: BuiltValueNullFieldError.checkNotNull(
            updated,
            r'ResetAdminUserPasswordData',
            'updated',
          ),
          sessionsRevoked: BuiltValueNullFieldError.checkNotNull(
            sessionsRevoked,
            r'ResetAdminUserPasswordData',
            'sessionsRevoked',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
