// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_record.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SyncRecord extends SyncRecord {
  @override
  final AnyOf anyOf;

  factory _$SyncRecord([void Function(SyncRecordBuilder)? updates]) =>
      (SyncRecordBuilder()..update(updates))._build();

  _$SyncRecord._({required this.anyOf}) : super._();
  @override
  SyncRecord rebuild(void Function(SyncRecordBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SyncRecordBuilder toBuilder() => SyncRecordBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncRecord && anyOf == other.anyOf;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, anyOf.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'SyncRecord',
    )..add('anyOf', anyOf)).toString();
  }
}

class SyncRecordBuilder implements Builder<SyncRecord, SyncRecordBuilder> {
  _$SyncRecord? _$v;

  AnyOf? _anyOf;
  AnyOf? get anyOf => _$this._anyOf;
  set anyOf(AnyOf? anyOf) => _$this._anyOf = anyOf;

  SyncRecordBuilder() {
    SyncRecord._defaults(this);
  }

  SyncRecordBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _anyOf = $v.anyOf;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncRecord other) {
    _$v = other as _$SyncRecord;
  }

  @override
  void update(void Function(SyncRecordBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncRecord build() => _build();

  _$SyncRecord _build() {
    final _$result =
        _$v ??
        _$SyncRecord._(
          anyOf: BuiltValueNullFieldError.checkNotNull(
            anyOf,
            r'SyncRecord',
            'anyOf',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
