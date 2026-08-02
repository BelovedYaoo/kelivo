// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_self_revocation_status_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$GetSelfRevocationStatusResponse
    extends GetSelfRevocationStatusResponse {
  @override
  final SelfRevocationStatusData data;

  factory _$GetSelfRevocationStatusResponse([
    void Function(GetSelfRevocationStatusResponseBuilder)? updates,
  ]) => (GetSelfRevocationStatusResponseBuilder()..update(updates))._build();

  _$GetSelfRevocationStatusResponse._({required this.data}) : super._();
  @override
  GetSelfRevocationStatusResponse rebuild(
    void Function(GetSelfRevocationStatusResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  GetSelfRevocationStatusResponseBuilder toBuilder() =>
      GetSelfRevocationStatusResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GetSelfRevocationStatusResponse && data == other.data;
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
      r'GetSelfRevocationStatusResponse',
    )..add('data', data)).toString();
  }
}

class GetSelfRevocationStatusResponseBuilder
    implements
        Builder<
          GetSelfRevocationStatusResponse,
          GetSelfRevocationStatusResponseBuilder
        > {
  _$GetSelfRevocationStatusResponse? _$v;

  SelfRevocationStatusDataBuilder? _data;
  SelfRevocationStatusDataBuilder get data =>
      _$this._data ??= SelfRevocationStatusDataBuilder();
  set data(SelfRevocationStatusDataBuilder? data) => _$this._data = data;

  GetSelfRevocationStatusResponseBuilder() {
    GetSelfRevocationStatusResponse._defaults(this);
  }

  GetSelfRevocationStatusResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GetSelfRevocationStatusResponse other) {
    _$v = other as _$GetSelfRevocationStatusResponse;
  }

  @override
  void update(void Function(GetSelfRevocationStatusResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  GetSelfRevocationStatusResponse build() => _build();

  _$GetSelfRevocationStatusResponse _build() {
    _$GetSelfRevocationStatusResponse _$result;
    try {
      _$result = _$v ?? _$GetSelfRevocationStatusResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'GetSelfRevocationStatusResponse',
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
