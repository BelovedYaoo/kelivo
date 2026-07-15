// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_admin_user_status_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$UpdateAdminUserStatusResponse extends UpdateAdminUserStatusResponse {
  @override
  final UpdateAdminUserData data;

  factory _$UpdateAdminUserStatusResponse([
    void Function(UpdateAdminUserStatusResponseBuilder)? updates,
  ]) => (UpdateAdminUserStatusResponseBuilder()..update(updates))._build();

  _$UpdateAdminUserStatusResponse._({required this.data}) : super._();
  @override
  UpdateAdminUserStatusResponse rebuild(
    void Function(UpdateAdminUserStatusResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  UpdateAdminUserStatusResponseBuilder toBuilder() =>
      UpdateAdminUserStatusResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is UpdateAdminUserStatusResponse && data == other.data;
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
      r'UpdateAdminUserStatusResponse',
    )..add('data', data)).toString();
  }
}

class UpdateAdminUserStatusResponseBuilder
    implements
        Builder<
          UpdateAdminUserStatusResponse,
          UpdateAdminUserStatusResponseBuilder
        > {
  _$UpdateAdminUserStatusResponse? _$v;

  UpdateAdminUserDataBuilder? _data;
  UpdateAdminUserDataBuilder get data =>
      _$this._data ??= UpdateAdminUserDataBuilder();
  set data(UpdateAdminUserDataBuilder? data) => _$this._data = data;

  UpdateAdminUserStatusResponseBuilder() {
    UpdateAdminUserStatusResponse._defaults(this);
  }

  UpdateAdminUserStatusResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(UpdateAdminUserStatusResponse other) {
    _$v = other as _$UpdateAdminUserStatusResponse;
  }

  @override
  void update(void Function(UpdateAdminUserStatusResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  UpdateAdminUserStatusResponse build() => _build();

  _$UpdateAdminUserStatusResponse _build() {
    _$UpdateAdminUserStatusResponse _$result;
    try {
      _$result = _$v ?? _$UpdateAdminUserStatusResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'UpdateAdminUserStatusResponse',
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
