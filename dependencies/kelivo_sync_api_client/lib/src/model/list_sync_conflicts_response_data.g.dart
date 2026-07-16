// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_sync_conflicts_response_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ListSyncConflictsResponseData extends ListSyncConflictsResponseData {
  @override
  final BuiltList<SyncConflict> conflicts;

  factory _$ListSyncConflictsResponseData([
    void Function(ListSyncConflictsResponseDataBuilder)? updates,
  ]) => (ListSyncConflictsResponseDataBuilder()..update(updates))._build();

  _$ListSyncConflictsResponseData._({required this.conflicts}) : super._();
  @override
  ListSyncConflictsResponseData rebuild(
    void Function(ListSyncConflictsResponseDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ListSyncConflictsResponseDataBuilder toBuilder() =>
      ListSyncConflictsResponseDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ListSyncConflictsResponseData &&
        conflicts == other.conflicts;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, conflicts.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'ListSyncConflictsResponseData',
    )..add('conflicts', conflicts)).toString();
  }
}

class ListSyncConflictsResponseDataBuilder
    implements
        Builder<
          ListSyncConflictsResponseData,
          ListSyncConflictsResponseDataBuilder
        > {
  _$ListSyncConflictsResponseData? _$v;

  ListBuilder<SyncConflict>? _conflicts;
  ListBuilder<SyncConflict> get conflicts =>
      _$this._conflicts ??= ListBuilder<SyncConflict>();
  set conflicts(ListBuilder<SyncConflict>? conflicts) =>
      _$this._conflicts = conflicts;

  ListSyncConflictsResponseDataBuilder() {
    ListSyncConflictsResponseData._defaults(this);
  }

  ListSyncConflictsResponseDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _conflicts = $v.conflicts.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ListSyncConflictsResponseData other) {
    _$v = other as _$ListSyncConflictsResponseData;
  }

  @override
  void update(void Function(ListSyncConflictsResponseDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ListSyncConflictsResponseData build() => _build();

  _$ListSyncConflictsResponseData _build() {
    _$ListSyncConflictsResponseData _$result;
    try {
      _$result =
          _$v ??
          _$ListSyncConflictsResponseData._(conflicts: conflicts.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'conflicts';
        conflicts.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ListSyncConflictsResponseData',
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
