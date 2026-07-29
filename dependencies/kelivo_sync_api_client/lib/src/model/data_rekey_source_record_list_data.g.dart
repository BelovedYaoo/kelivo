// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_source_record_list_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DataRekeySourceRecordListData extends DataRekeySourceRecordListData {
  @override
  final BuiltList<SyncRecord> records;
  @override
  final String? nextAfterRecordId;
  @override
  final bool hasMore;

  factory _$DataRekeySourceRecordListData([
    void Function(DataRekeySourceRecordListDataBuilder)? updates,
  ]) => (DataRekeySourceRecordListDataBuilder()..update(updates))._build();

  _$DataRekeySourceRecordListData._({
    required this.records,
    this.nextAfterRecordId,
    required this.hasMore,
  }) : super._();
  @override
  DataRekeySourceRecordListData rebuild(
    void Function(DataRekeySourceRecordListDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeySourceRecordListDataBuilder toBuilder() =>
      DataRekeySourceRecordListDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeySourceRecordListData &&
        records == other.records &&
        nextAfterRecordId == other.nextAfterRecordId &&
        hasMore == other.hasMore;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, records.hashCode);
    _$hash = $jc(_$hash, nextAfterRecordId.hashCode);
    _$hash = $jc(_$hash, hasMore.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DataRekeySourceRecordListData')
          ..add('records', records)
          ..add('nextAfterRecordId', nextAfterRecordId)
          ..add('hasMore', hasMore))
        .toString();
  }
}

class DataRekeySourceRecordListDataBuilder
    implements
        Builder<
          DataRekeySourceRecordListData,
          DataRekeySourceRecordListDataBuilder
        > {
  _$DataRekeySourceRecordListData? _$v;

  ListBuilder<SyncRecord>? _records;
  ListBuilder<SyncRecord> get records =>
      _$this._records ??= ListBuilder<SyncRecord>();
  set records(ListBuilder<SyncRecord>? records) => _$this._records = records;

  String? _nextAfterRecordId;
  String? get nextAfterRecordId => _$this._nextAfterRecordId;
  set nextAfterRecordId(String? nextAfterRecordId) =>
      _$this._nextAfterRecordId = nextAfterRecordId;

  bool? _hasMore;
  bool? get hasMore => _$this._hasMore;
  set hasMore(bool? hasMore) => _$this._hasMore = hasMore;

  DataRekeySourceRecordListDataBuilder() {
    DataRekeySourceRecordListData._defaults(this);
  }

  DataRekeySourceRecordListDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _records = $v.records.toBuilder();
      _nextAfterRecordId = $v.nextAfterRecordId;
      _hasMore = $v.hasMore;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeySourceRecordListData other) {
    _$v = other as _$DataRekeySourceRecordListData;
  }

  @override
  void update(void Function(DataRekeySourceRecordListDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeySourceRecordListData build() => _build();

  _$DataRekeySourceRecordListData _build() {
    _$DataRekeySourceRecordListData _$result;
    try {
      _$result =
          _$v ??
          _$DataRekeySourceRecordListData._(
            records: records.build(),
            nextAfterRecordId: nextAfterRecordId,
            hasMore: BuiltValueNullFieldError.checkNotNull(
              hasMore,
              r'DataRekeySourceRecordListData',
              'hasMore',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'records';
        records.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'DataRekeySourceRecordListData',
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
