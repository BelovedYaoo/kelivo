// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reset_admin_user_password_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ResetAdminUserPasswordResponse extends ResetAdminUserPasswordResponse {
  @override
  final ResetAdminUserPasswordData data;

  factory _$ResetAdminUserPasswordResponse([
    void Function(ResetAdminUserPasswordResponseBuilder)? updates,
  ]) => (ResetAdminUserPasswordResponseBuilder()..update(updates))._build();

  _$ResetAdminUserPasswordResponse._({required this.data}) : super._();
  @override
  ResetAdminUserPasswordResponse rebuild(
    void Function(ResetAdminUserPasswordResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ResetAdminUserPasswordResponseBuilder toBuilder() =>
      ResetAdminUserPasswordResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ResetAdminUserPasswordResponse && data == other.data;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, data.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'ResetAdminUserPasswordResponse',
    )..add('data', data)).toString();
  }
}

class ResetAdminUserPasswordResponseBuilder
    implements
        Builder<
          ResetAdminUserPasswordResponse,
          ResetAdminUserPasswordResponseBuilder
        > {
  _$ResetAdminUserPasswordResponse? _$v;

  ResetAdminUserPasswordDataBuilder? _data;
  ResetAdminUserPasswordDataBuilder get data =>
      _$this._data ??= ResetAdminUserPasswordDataBuilder();
  set data(ResetAdminUserPasswordDataBuilder? data) => _$this._data = data;

  ResetAdminUserPasswordResponseBuilder() {
    ResetAdminUserPasswordResponse._defaults(this);
  }

  ResetAdminUserPasswordResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ResetAdminUserPasswordResponse other) {
    _$v = other as _$ResetAdminUserPasswordResponse;
  }

  @override
  void update(void Function(ResetAdminUserPasswordResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ResetAdminUserPasswordResponse build() => _build();

  _$ResetAdminUserPasswordResponse _build() {
    _$ResetAdminUserPasswordResponse _$result;
    try {
      _$result = _$v ?? _$ResetAdminUserPasswordResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ResetAdminUserPasswordResponse',
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
