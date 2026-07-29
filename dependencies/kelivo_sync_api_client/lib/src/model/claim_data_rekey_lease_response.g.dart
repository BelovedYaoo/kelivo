// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'claim_data_rekey_lease_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ClaimDataRekeyLeaseResponse extends ClaimDataRekeyLeaseResponse {
  @override
  final DataRekeyLeaseClaimData data;

  factory _$ClaimDataRekeyLeaseResponse([
    void Function(ClaimDataRekeyLeaseResponseBuilder)? updates,
  ]) => (ClaimDataRekeyLeaseResponseBuilder()..update(updates))._build();

  _$ClaimDataRekeyLeaseResponse._({required this.data}) : super._();
  @override
  ClaimDataRekeyLeaseResponse rebuild(
    void Function(ClaimDataRekeyLeaseResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ClaimDataRekeyLeaseResponseBuilder toBuilder() =>
      ClaimDataRekeyLeaseResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ClaimDataRekeyLeaseResponse && data == other.data;
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
      r'ClaimDataRekeyLeaseResponse',
    )..add('data', data)).toString();
  }
}

class ClaimDataRekeyLeaseResponseBuilder
    implements
        Builder<
          ClaimDataRekeyLeaseResponse,
          ClaimDataRekeyLeaseResponseBuilder
        > {
  _$ClaimDataRekeyLeaseResponse? _$v;

  DataRekeyLeaseClaimDataBuilder? _data;
  DataRekeyLeaseClaimDataBuilder get data =>
      _$this._data ??= DataRekeyLeaseClaimDataBuilder();
  set data(DataRekeyLeaseClaimDataBuilder? data) => _$this._data = data;

  ClaimDataRekeyLeaseResponseBuilder() {
    ClaimDataRekeyLeaseResponse._defaults(this);
  }

  ClaimDataRekeyLeaseResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ClaimDataRekeyLeaseResponse other) {
    _$v = other as _$ClaimDataRekeyLeaseResponse;
  }

  @override
  void update(void Function(ClaimDataRekeyLeaseResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ClaimDataRekeyLeaseResponse build() => _build();

  _$ClaimDataRekeyLeaseResponse _build() {
    _$ClaimDataRekeyLeaseResponse _$result;
    try {
      _$result = _$v ?? _$ClaimDataRekeyLeaseResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ClaimDataRekeyLeaseResponse',
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
