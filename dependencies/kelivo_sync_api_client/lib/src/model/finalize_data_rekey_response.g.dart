// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finalize_data_rekey_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$FinalizeDataRekeyResponse extends FinalizeDataRekeyResponse {
  @override
  final DataRekeyFinalizeData data;

  factory _$FinalizeDataRekeyResponse([
    void Function(FinalizeDataRekeyResponseBuilder)? updates,
  ]) => (FinalizeDataRekeyResponseBuilder()..update(updates))._build();

  _$FinalizeDataRekeyResponse._({required this.data}) : super._();
  @override
  FinalizeDataRekeyResponse rebuild(
    void Function(FinalizeDataRekeyResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  FinalizeDataRekeyResponseBuilder toBuilder() =>
      FinalizeDataRekeyResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is FinalizeDataRekeyResponse && data == other.data;
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
      r'FinalizeDataRekeyResponse',
    )..add('data', data)).toString();
  }
}

class FinalizeDataRekeyResponseBuilder
    implements
        Builder<FinalizeDataRekeyResponse, FinalizeDataRekeyResponseBuilder> {
  _$FinalizeDataRekeyResponse? _$v;

  DataRekeyFinalizeDataBuilder? _data;
  DataRekeyFinalizeDataBuilder get data =>
      _$this._data ??= DataRekeyFinalizeDataBuilder();
  set data(DataRekeyFinalizeDataBuilder? data) => _$this._data = data;

  FinalizeDataRekeyResponseBuilder() {
    FinalizeDataRekeyResponse._defaults(this);
  }

  FinalizeDataRekeyResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(FinalizeDataRekeyResponse other) {
    _$v = other as _$FinalizeDataRekeyResponse;
  }

  @override
  void update(void Function(FinalizeDataRekeyResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  FinalizeDataRekeyResponse build() => _build();

  _$FinalizeDataRekeyResponse _build() {
    _$FinalizeDataRekeyResponse _$result;
    try {
      _$result = _$v ?? _$FinalizeDataRekeyResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'FinalizeDataRekeyResponse',
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
