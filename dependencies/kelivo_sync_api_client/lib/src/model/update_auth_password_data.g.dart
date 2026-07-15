// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_auth_password_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$UpdateAuthPasswordData extends UpdateAuthPasswordData {
  @override
  final bool updated;

  factory _$UpdateAuthPasswordData([
    void Function(UpdateAuthPasswordDataBuilder)? updates,
  ]) => (UpdateAuthPasswordDataBuilder()..update(updates))._build();

  _$UpdateAuthPasswordData._({required this.updated}) : super._();
  @override
  UpdateAuthPasswordData rebuild(
    void Function(UpdateAuthPasswordDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  UpdateAuthPasswordDataBuilder toBuilder() =>
      UpdateAuthPasswordDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is UpdateAuthPasswordData && updated == other.updated;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, updated.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'UpdateAuthPasswordData',
    )..add('updated', updated)).toString();
  }
}

class UpdateAuthPasswordDataBuilder
    implements Builder<UpdateAuthPasswordData, UpdateAuthPasswordDataBuilder> {
  _$UpdateAuthPasswordData? _$v;

  bool? _updated;
  bool? get updated => _$this._updated;
  set updated(bool? updated) => _$this._updated = updated;

  UpdateAuthPasswordDataBuilder() {
    UpdateAuthPasswordData._defaults(this);
  }

  UpdateAuthPasswordDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _updated = $v.updated;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(UpdateAuthPasswordData other) {
    _$v = other as _$UpdateAuthPasswordData;
  }

  @override
  void update(void Function(UpdateAuthPasswordDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  UpdateAuthPasswordData build() => _build();

  _$UpdateAuthPasswordData _build() {
    final _$result =
        _$v ??
        _$UpdateAuthPasswordData._(
          updated: BuiltValueNullFieldError.checkNotNull(
            updated,
            r'UpdateAuthPasswordData',
            'updated',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
