// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_admin_user_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$CreateAdminUserResponse extends CreateAdminUserResponse {
  @override
  final CreateAdminUserData data;

  factory _$CreateAdminUserResponse([
    void Function(CreateAdminUserResponseBuilder)? updates,
  ]) => (CreateAdminUserResponseBuilder()..update(updates))._build();

  _$CreateAdminUserResponse._({required this.data}) : super._();
  @override
  CreateAdminUserResponse rebuild(
    void Function(CreateAdminUserResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  CreateAdminUserResponseBuilder toBuilder() =>
      CreateAdminUserResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CreateAdminUserResponse && data == other.data;
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
      r'CreateAdminUserResponse',
    )..add('data', data)).toString();
  }
}

class CreateAdminUserResponseBuilder
    implements
        Builder<CreateAdminUserResponse, CreateAdminUserResponseBuilder> {
  _$CreateAdminUserResponse? _$v;

  CreateAdminUserDataBuilder? _data;
  CreateAdminUserDataBuilder get data =>
      _$this._data ??= CreateAdminUserDataBuilder();
  set data(CreateAdminUserDataBuilder? data) => _$this._data = data;

  CreateAdminUserResponseBuilder() {
    CreateAdminUserResponse._defaults(this);
  }

  CreateAdminUserResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CreateAdminUserResponse other) {
    _$v = other as _$CreateAdminUserResponse;
  }

  @override
  void update(void Function(CreateAdminUserResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  CreateAdminUserResponse build() => _build();

  _$CreateAdminUserResponse _build() {
    _$CreateAdminUserResponse _$result;
    try {
      _$result = _$v ?? _$CreateAdminUserResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'CreateAdminUserResponse',
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
