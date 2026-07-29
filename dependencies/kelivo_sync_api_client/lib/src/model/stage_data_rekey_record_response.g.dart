// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stage_data_rekey_record_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$StageDataRekeyRecordResponse extends StageDataRekeyRecordResponse {
  @override
  final DataRekeyRecordStageData data;

  factory _$StageDataRekeyRecordResponse([
    void Function(StageDataRekeyRecordResponseBuilder)? updates,
  ]) => (StageDataRekeyRecordResponseBuilder()..update(updates))._build();

  _$StageDataRekeyRecordResponse._({required this.data}) : super._();
  @override
  StageDataRekeyRecordResponse rebuild(
    void Function(StageDataRekeyRecordResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  StageDataRekeyRecordResponseBuilder toBuilder() =>
      StageDataRekeyRecordResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is StageDataRekeyRecordResponse && data == other.data;
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
      r'StageDataRekeyRecordResponse',
    )..add('data', data)).toString();
  }
}

class StageDataRekeyRecordResponseBuilder
    implements
        Builder<
          StageDataRekeyRecordResponse,
          StageDataRekeyRecordResponseBuilder
        > {
  _$StageDataRekeyRecordResponse? _$v;

  DataRekeyRecordStageDataBuilder? _data;
  DataRekeyRecordStageDataBuilder get data =>
      _$this._data ??= DataRekeyRecordStageDataBuilder();
  set data(DataRekeyRecordStageDataBuilder? data) => _$this._data = data;

  StageDataRekeyRecordResponseBuilder() {
    StageDataRekeyRecordResponse._defaults(this);
  }

  StageDataRekeyRecordResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(StageDataRekeyRecordResponse other) {
    _$v = other as _$StageDataRekeyRecordResponse;
  }

  @override
  void update(void Function(StageDataRekeyRecordResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  StageDataRekeyRecordResponse build() => _build();

  _$StageDataRekeyRecordResponse _build() {
    _$StageDataRekeyRecordResponse _$result;
    try {
      _$result = _$v ?? _$StageDataRekeyRecordResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'StageDataRekeyRecordResponse',
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
