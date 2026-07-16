// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_conflict_details_fields_inner_current.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SyncConflictDetailsFieldsInnerCurrent
    extends SyncConflictDetailsFieldsInnerCurrent {
  @override
  final bool exists;
  @override
  final JsonObject? value;

  factory _$SyncConflictDetailsFieldsInnerCurrent([
    void Function(SyncConflictDetailsFieldsInnerCurrentBuilder)? updates,
  ]) => (SyncConflictDetailsFieldsInnerCurrentBuilder()..update(updates))
      ._build();

  _$SyncConflictDetailsFieldsInnerCurrent._({required this.exists, this.value})
    : super._();
  @override
  SyncConflictDetailsFieldsInnerCurrent rebuild(
    void Function(SyncConflictDetailsFieldsInnerCurrentBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SyncConflictDetailsFieldsInnerCurrentBuilder toBuilder() =>
      SyncConflictDetailsFieldsInnerCurrentBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncConflictDetailsFieldsInnerCurrent &&
        exists == other.exists &&
        value == other.value;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, exists.hashCode);
    _$hash = $jc(_$hash, value.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
            r'SyncConflictDetailsFieldsInnerCurrent',
          )
          ..add('exists', exists)
          ..add('value', value))
        .toString();
  }
}

class SyncConflictDetailsFieldsInnerCurrentBuilder
    implements
        Builder<
          SyncConflictDetailsFieldsInnerCurrent,
          SyncConflictDetailsFieldsInnerCurrentBuilder
        > {
  _$SyncConflictDetailsFieldsInnerCurrent? _$v;

  bool? _exists;
  bool? get exists => _$this._exists;
  set exists(bool? exists) => _$this._exists = exists;

  JsonObject? _value;
  JsonObject? get value => _$this._value;
  set value(JsonObject? value) => _$this._value = value;

  SyncConflictDetailsFieldsInnerCurrentBuilder() {
    SyncConflictDetailsFieldsInnerCurrent._defaults(this);
  }

  SyncConflictDetailsFieldsInnerCurrentBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _exists = $v.exists;
      _value = $v.value;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncConflictDetailsFieldsInnerCurrent other) {
    _$v = other as _$SyncConflictDetailsFieldsInnerCurrent;
  }

  @override
  void update(
    void Function(SyncConflictDetailsFieldsInnerCurrentBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  SyncConflictDetailsFieldsInnerCurrent build() => _build();

  _$SyncConflictDetailsFieldsInnerCurrent _build() {
    final _$result =
        _$v ??
        _$SyncConflictDetailsFieldsInnerCurrent._(
          exists: BuiltValueNullFieldError.checkNotNull(
            exists,
            r'SyncConflictDetailsFieldsInnerCurrent',
            'exists',
          ),
          value: value,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
