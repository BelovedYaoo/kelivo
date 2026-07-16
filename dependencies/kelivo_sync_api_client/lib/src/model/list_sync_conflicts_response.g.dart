// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_sync_conflicts_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListSyncConflictsResponse extends ListSyncConflictsResponse {
  @override
  final ListSyncConflictsResponseData data;

  factory _$ListSyncConflictsResponse([
    void Function(ListSyncConflictsResponseBuilder)? updates,
  ]) => (ListSyncConflictsResponseBuilder()..update(updates))._build();

  _$ListSyncConflictsResponse._({required this.data}) : super._();
  @override
  ListSyncConflictsResponse rebuild(
    void Function(ListSyncConflictsResponseBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListSyncConflictsResponseBuilder toBuilder() =>
      ListSyncConflictsResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListSyncConflictsResponse && data == other.data;
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
      r'ListSyncConflictsResponse',
    )..add('data', data)).toString();
  }
}

class ListSyncConflictsResponseBuilder
    implements
        Builder<ListSyncConflictsResponse, ListSyncConflictsResponseBuilder> {
  _$ListSyncConflictsResponse? _$v;

  ListSyncConflictsResponseDataBuilder? _data;
  ListSyncConflictsResponseDataBuilder get data =>
      _$this._data ??= ListSyncConflictsResponseDataBuilder();
  set data(ListSyncConflictsResponseDataBuilder? data) => _$this._data = data;

  ListSyncConflictsResponseBuilder() {
    ListSyncConflictsResponse._defaults(this);
  }

  ListSyncConflictsResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListSyncConflictsResponse other) {
    _$v = other as _$ListSyncConflictsResponse;
  }

  @override
  void update(void Function(ListSyncConflictsResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ListSyncConflictsResponse build() => _build();

  _$ListSyncConflictsResponse _build() {
    _$ListSyncConflictsResponse _$result;
    try {
      _$result = _$v ?? _$ListSyncConflictsResponse._(data: data.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ListSyncConflictsResponse',
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
