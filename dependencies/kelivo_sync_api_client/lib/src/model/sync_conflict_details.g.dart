// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_conflict_details.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SyncConflictDetails extends SyncConflictDetails {
  @override
  final int baseRevision;
  @override
  final BuiltList<SyncConflictDetailsFieldsInner> fields;

  factory _$SyncConflictDetails([
    void Function(SyncConflictDetailsBuilder)? updates,
  ]) => (SyncConflictDetailsBuilder()..update(updates))._build();

  _$SyncConflictDetails._({required this.baseRevision, required this.fields})
    : super._();
  @override
  SyncConflictDetails rebuild(
    void Function(SyncConflictDetailsBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SyncConflictDetailsBuilder toBuilder() =>
      SyncConflictDetailsBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncConflictDetails &&
        baseRevision == other.baseRevision &&
        fields == other.fields;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, baseRevision.hashCode);
    _$hash = $jc(_$hash, fields.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncConflictDetails')
          ..add('baseRevision', baseRevision)
          ..add('fields', fields))
        .toString();
  }
}

class SyncConflictDetailsBuilder
    implements Builder<SyncConflictDetails, SyncConflictDetailsBuilder> {
  _$SyncConflictDetails? _$v;

  int? _baseRevision;
  int? get baseRevision => _$this._baseRevision;
  set baseRevision(int? baseRevision) => _$this._baseRevision = baseRevision;

  ListBuilder<SyncConflictDetailsFieldsInner>? _fields;
  ListBuilder<SyncConflictDetailsFieldsInner> get fields =>
      _$this._fields ??= ListBuilder<SyncConflictDetailsFieldsInner>();
  set fields(ListBuilder<SyncConflictDetailsFieldsInner>? fields) =>
      _$this._fields = fields;

  SyncConflictDetailsBuilder() {
    SyncConflictDetails._defaults(this);
  }

  SyncConflictDetailsBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _baseRevision = $v.baseRevision;
      _fields = $v.fields.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncConflictDetails other) {
    _$v = other as _$SyncConflictDetails;
  }

  @override
  void update(void Function(SyncConflictDetailsBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncConflictDetails build() => _build();

  _$SyncConflictDetails _build() {
    _$SyncConflictDetails _$result;
    try {
      _$result =
          _$v ??
          _$SyncConflictDetails._(
            baseRevision: BuiltValueNullFieldError.checkNotNull(
              baseRevision,
              r'SyncConflictDetails',
              'baseRevision',
            ),
            fields: fields.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'fields';
        fields.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'SyncConflictDetails',
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
