// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_data_rekey_state_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$GetDataRekeyStateResponse extends GetDataRekeyStateResponse {
  @override
  final DataRekeyStateData data;

  factory _$GetDataRekeyStateResponse([
    void Function(GetDataRekeyStateResponseBuilder)? updates,
  ]) => (GetDataRekeyStateResponseBuilder()..update(updates))._build();

  _$GetDataRekeyStateResponse._({required this.data}) : super._();
  @override
  GetDataRekeyStateResponse rebuild(
    void Function(GetDataRekeyStateResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  GetDataRekeyStateResponseBuilder toBuilder() =>
      GetDataRekeyStateResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GetDataRekeyStateResponse && data == other.data;
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
      r'GetDataRekeyStateResponse',
    )..add('data', data)).toString();
  }
}

class GetDataRekeyStateResponseBuilder
    implements
        Builder<GetDataRekeyStateResponse, GetDataRekeyStateResponseBuilder> {
  _$GetDataRekeyStateResponse? _$v;

  DataRekeyStateDataBuilder? _data;
  DataRekeyStateDataBuilder get data =>
      _$this._data ??= DataRekeyStateDataBuilder();
  set data(DataRekeyStateDataBuilder? data) => _$this._data = data;

  GetDataRekeyStateResponseBuilder() {
    GetDataRekeyStateResponse._defaults(this);
  }

  GetDataRekeyStateResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GetDataRekeyStateResponse other) {
    _$v = other as _$GetDataRekeyStateResponse;
  }

  @override
  void update(void Function(GetDataRekeyStateResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  GetDataRekeyStateResponse build() => _build();

  _$GetDataRekeyStateResponse _build() {
    _$GetDataRekeyStateResponse _$result;
    try {
      _$result = _$v ?? _$GetDataRekeyStateResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'GetDataRekeyStateResponse',
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
