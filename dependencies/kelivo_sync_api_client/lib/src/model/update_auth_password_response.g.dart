// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_auth_password_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$UpdateAuthPasswordResponse extends UpdateAuthPasswordResponse {
  @override
  final UpdateAuthPasswordData data;

  factory _$UpdateAuthPasswordResponse([
    void Function(UpdateAuthPasswordResponseBuilder)? updates,
  ]) => (UpdateAuthPasswordResponseBuilder()..update(updates))._build();

  _$UpdateAuthPasswordResponse._({required this.data}) : super._();
  @override
  UpdateAuthPasswordResponse rebuild(
    void Function(UpdateAuthPasswordResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  UpdateAuthPasswordResponseBuilder toBuilder() =>
      UpdateAuthPasswordResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is UpdateAuthPasswordResponse && data == other.data;
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
      r'UpdateAuthPasswordResponse',
    )..add('data', data)).toString();
  }
}

class UpdateAuthPasswordResponseBuilder
    implements
        Builder<UpdateAuthPasswordResponse, UpdateAuthPasswordResponseBuilder> {
  _$UpdateAuthPasswordResponse? _$v;

  UpdateAuthPasswordDataBuilder? _data;
  UpdateAuthPasswordDataBuilder get data =>
      _$this._data ??= UpdateAuthPasswordDataBuilder();
  set data(UpdateAuthPasswordDataBuilder? data) => _$this._data = data;

  UpdateAuthPasswordResponseBuilder() {
    UpdateAuthPasswordResponse._defaults(this);
  }

  UpdateAuthPasswordResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(UpdateAuthPasswordResponse other) {
    _$v = other as _$UpdateAuthPasswordResponse;
  }

  @override
  void update(void Function(UpdateAuthPasswordResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  UpdateAuthPasswordResponse build() => _build();

  _$UpdateAuthPasswordResponse _build() {
    _$UpdateAuthPasswordResponse _$result;
    try {
      _$result = _$v ?? _$UpdateAuthPasswordResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'UpdateAuthPasswordResponse',
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
