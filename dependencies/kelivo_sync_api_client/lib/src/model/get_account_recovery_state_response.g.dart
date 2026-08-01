// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_account_recovery_state_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$GetAccountRecoveryStateResponse
    extends GetAccountRecoveryStateResponse {
  @override
  final AccountRecoveryStateData data;

  factory _$GetAccountRecoveryStateResponse([
    void Function(GetAccountRecoveryStateResponseBuilder)? updates,
  ]) => (GetAccountRecoveryStateResponseBuilder()..update(updates))._build();

  _$GetAccountRecoveryStateResponse._({required this.data}) : super._();
  @override
  GetAccountRecoveryStateResponse rebuild(
    void Function(GetAccountRecoveryStateResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  GetAccountRecoveryStateResponseBuilder toBuilder() =>
      GetAccountRecoveryStateResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GetAccountRecoveryStateResponse && data == other.data;
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
      r'GetAccountRecoveryStateResponse',
    )..add('data', data)).toString();
  }
}

class GetAccountRecoveryStateResponseBuilder
    implements
        Builder<
          GetAccountRecoveryStateResponse,
          GetAccountRecoveryStateResponseBuilder
        > {
  _$GetAccountRecoveryStateResponse? _$v;

  AccountRecoveryStateDataBuilder? _data;
  AccountRecoveryStateDataBuilder get data =>
      _$this._data ??= AccountRecoveryStateDataBuilder();
  set data(AccountRecoveryStateDataBuilder? data) => _$this._data = data;

  GetAccountRecoveryStateResponseBuilder() {
    GetAccountRecoveryStateResponse._defaults(this);
  }

  GetAccountRecoveryStateResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GetAccountRecoveryStateResponse other) {
    _$v = other as _$GetAccountRecoveryStateResponse;
  }

  @override
  void update(void Function(GetAccountRecoveryStateResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  GetAccountRecoveryStateResponse build() => _build();

  _$GetAccountRecoveryStateResponse _build() {
    _$GetAccountRecoveryStateResponse _$result;
    try {
      _$result = _$v ?? _$GetAccountRecoveryStateResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'GetAccountRecoveryStateResponse',
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
