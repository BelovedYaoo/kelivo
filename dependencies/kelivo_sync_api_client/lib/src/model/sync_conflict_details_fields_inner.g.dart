// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_conflict_details_fields_inner.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SyncConflictDetailsFieldsInner extends SyncConflictDetailsFieldsInner {
  @override
  final String path;
  @override
  final SyncConflictDetailsFieldsInnerCurrent current;
  @override
  final SyncConflictDetailsFieldsInnerCurrent desired;

  factory _$SyncConflictDetailsFieldsInner([
    void Function(SyncConflictDetailsFieldsInnerBuilder)? updates,
  ]) => (SyncConflictDetailsFieldsInnerBuilder()..update(updates))._build();

  _$SyncConflictDetailsFieldsInner._({
    required this.path,
    required this.current,
    required this.desired,
  }) : super._();
  @override
  SyncConflictDetailsFieldsInner rebuild(
    void Function(SyncConflictDetailsFieldsInnerBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SyncConflictDetailsFieldsInnerBuilder toBuilder() =>
      SyncConflictDetailsFieldsInnerBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncConflictDetailsFieldsInner &&
        path == other.path &&
        current == other.current &&
        desired == other.desired;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, path.hashCode);
    _$hash = $jc(_$hash, current.hashCode);
    _$hash = $jc(_$hash, desired.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncConflictDetailsFieldsInner')
          ..add('path', path)
          ..add('current', current)
          ..add('desired', desired))
        .toString();
  }
}

class SyncConflictDetailsFieldsInnerBuilder
    implements
        Builder<
          SyncConflictDetailsFieldsInner,
          SyncConflictDetailsFieldsInnerBuilder
        > {
  _$SyncConflictDetailsFieldsInner? _$v;

  String? _path;
  String? get path => _$this._path;
  set path(String? path) => _$this._path = path;

  SyncConflictDetailsFieldsInnerCurrentBuilder? _current;
  SyncConflictDetailsFieldsInnerCurrentBuilder get current =>
      _$this._current ??= SyncConflictDetailsFieldsInnerCurrentBuilder();
  set current(SyncConflictDetailsFieldsInnerCurrentBuilder? current) =>
      _$this._current = current;

  SyncConflictDetailsFieldsInnerCurrentBuilder? _desired;
  SyncConflictDetailsFieldsInnerCurrentBuilder get desired =>
      _$this._desired ??= SyncConflictDetailsFieldsInnerCurrentBuilder();
  set desired(SyncConflictDetailsFieldsInnerCurrentBuilder? desired) =>
      _$this._desired = desired;

  SyncConflictDetailsFieldsInnerBuilder() {
    SyncConflictDetailsFieldsInner._defaults(this);
  }

  SyncConflictDetailsFieldsInnerBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _path = $v.path;
      _current = $v.current.toBuilder();
      _desired = $v.desired.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncConflictDetailsFieldsInner other) {
    _$v = other as _$SyncConflictDetailsFieldsInner;
  }

  @override
  void update(void Function(SyncConflictDetailsFieldsInnerBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncConflictDetailsFieldsInner build() => _build();

  _$SyncConflictDetailsFieldsInner _build() {
    _$SyncConflictDetailsFieldsInner _$result;
    try {
      _$result =
          _$v ??
          _$SyncConflictDetailsFieldsInner._(
            path: BuiltValueNullFieldError.checkNotNull(
              path,
              r'SyncConflictDetailsFieldsInner',
              'path',
            ),
            current: current.build(),
            desired: desired.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'current';
        current.build();
        _$failedField = 'desired';
        desired.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'SyncConflictDetailsFieldsInner',
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
