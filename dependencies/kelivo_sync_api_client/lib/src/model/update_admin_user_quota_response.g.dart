// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_admin_user_quota_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$UpdateAdminUserQuotaResponse extends UpdateAdminUserQuotaResponse {
  @override
  final UpdateAdminUserData data;

  factory _$UpdateAdminUserQuotaResponse([
    void Function(UpdateAdminUserQuotaResponseBuilder)? updates,
  ]) => (UpdateAdminUserQuotaResponseBuilder()..update(updates))._build();

  _$UpdateAdminUserQuotaResponse._({required this.data}) : super._();
  @override
  UpdateAdminUserQuotaResponse rebuild(
    void Function(UpdateAdminUserQuotaResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  UpdateAdminUserQuotaResponseBuilder toBuilder() =>
      UpdateAdminUserQuotaResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is UpdateAdminUserQuotaResponse && data == other.data;
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
      r'UpdateAdminUserQuotaResponse',
    )..add('data', data)).toString();
  }
}

class UpdateAdminUserQuotaResponseBuilder
    implements
        Builder<
          UpdateAdminUserQuotaResponse,
          UpdateAdminUserQuotaResponseBuilder
        > {
  _$UpdateAdminUserQuotaResponse? _$v;

  UpdateAdminUserDataBuilder? _data;
  UpdateAdminUserDataBuilder get data =>
      _$this._data ??= UpdateAdminUserDataBuilder();
  set data(UpdateAdminUserDataBuilder? data) => _$this._data = data;

  UpdateAdminUserQuotaResponseBuilder() {
    UpdateAdminUserQuotaResponse._defaults(this);
  }

  UpdateAdminUserQuotaResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(UpdateAdminUserQuotaResponse other) {
    _$v = other as _$UpdateAdminUserQuotaResponse;
  }

  @override
  void update(void Function(UpdateAdminUserQuotaResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  UpdateAdminUserQuotaResponse build() => _build();

  _$UpdateAdminUserQuotaResponse _build() {
    _$UpdateAdminUserQuotaResponse _$result;
    try {
      _$result = _$v ?? _$UpdateAdminUserQuotaResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'UpdateAdminUserQuotaResponse',
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
