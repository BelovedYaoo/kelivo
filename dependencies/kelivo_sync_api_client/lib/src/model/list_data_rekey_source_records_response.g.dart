// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_data_rekey_source_records_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListDataRekeySourceRecordsResponse
    extends ListDataRekeySourceRecordsResponse {
  @override
  final DataRekeySourceRecordListData data;

  factory _$ListDataRekeySourceRecordsResponse([
    void Function(ListDataRekeySourceRecordsResponseBuilder)? updates,
  ]) => (ListDataRekeySourceRecordsResponseBuilder()..update(updates))._build();

  _$ListDataRekeySourceRecordsResponse._({required this.data}) : super._();
  @override
  ListDataRekeySourceRecordsResponse rebuild(
    void Function(ListDataRekeySourceRecordsResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListDataRekeySourceRecordsResponseBuilder toBuilder() =>
      ListDataRekeySourceRecordsResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListDataRekeySourceRecordsResponse && data == other.data;
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
      r'ListDataRekeySourceRecordsResponse',
    )..add('data', data)).toString();
  }
}

class ListDataRekeySourceRecordsResponseBuilder
    implements
        Builder<
          ListDataRekeySourceRecordsResponse,
          ListDataRekeySourceRecordsResponseBuilder
        > {
  _$ListDataRekeySourceRecordsResponse? _$v;

  DataRekeySourceRecordListDataBuilder? _data;
  DataRekeySourceRecordListDataBuilder get data =>
      _$this._data ??= DataRekeySourceRecordListDataBuilder();
  set data(DataRekeySourceRecordListDataBuilder? data) => _$this._data = data;

  ListDataRekeySourceRecordsResponseBuilder() {
    ListDataRekeySourceRecordsResponse._defaults(this);
  }

  ListDataRekeySourceRecordsResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListDataRekeySourceRecordsResponse other) {
    _$v = other as _$ListDataRekeySourceRecordsResponse;
  }

  @override
  void update(
    void Function(ListDataRekeySourceRecordsResponseBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  ListDataRekeySourceRecordsResponse build() => _build();

  _$ListDataRekeySourceRecordsResponse _build() {
    _$ListDataRekeySourceRecordsResponse _$result;
    try {
      _$result =
          _$v ?? _$ListDataRekeySourceRecordsResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ListDataRekeySourceRecordsResponse',
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
