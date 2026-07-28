// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_pull_reset_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

SyncPullResetDataNextCursorEnum _$syncPullResetDataNextCursorEnumValueOf(
  String name,
) {
  switch (name) {
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncPullResetDataNextCursorEnum>
_$syncPullResetDataNextCursorEnumValues =
    BuiltSet<SyncPullResetDataNextCursorEnum>(
      const <SyncPullResetDataNextCursorEnum>[],
    );

Serializer<SyncPullResetDataNextCursorEnum>
_$syncPullResetDataNextCursorEnumSerializer =
    _$SyncPullResetDataNextCursorEnumSerializer();

class _$SyncPullResetDataNextCursorEnumSerializer
    implements PrimitiveSerializer<SyncPullResetDataNextCursorEnum> {
  @override
  final Iterable<Type> types = const <Type>[SyncPullResetDataNextCursorEnum];
  @override
  final String wireName = 'SyncPullResetDataNextCursorEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncPullResetDataNextCursorEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => object.name;

  @override
  SyncPullResetDataNextCursorEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncPullResetDataNextCursorEnum.valueOf(serialized as String);
}

class _$SyncPullResetData extends SyncPullResetData {
  @override
  final BuiltList<SyncChange> changes;
  @override
  final SyncPullResetDataNextCursorEnum? nextCursor;
  @override
  final bool hasMore;
  @override
  final bool resetRequired;

  factory _$SyncPullResetData([
    void Function(SyncPullResetDataBuilder)? updates,
  ]) => (SyncPullResetDataBuilder()..update(updates))._build();

  _$SyncPullResetData._({
    required this.changes,
    this.nextCursor,
    required this.hasMore,
    required this.resetRequired,
  }) : super._();
  @override
  SyncPullResetData rebuild(void Function(SyncPullResetDataBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SyncPullResetDataBuilder toBuilder() =>
      SyncPullResetDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncPullResetData &&
        changes == other.changes &&
        nextCursor == other.nextCursor &&
        hasMore == other.hasMore &&
        resetRequired == other.resetRequired;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, changes.hashCode);
    _$hash = $jc(_$hash, nextCursor.hashCode);
    _$hash = $jc(_$hash, hasMore.hashCode);
    _$hash = $jc(_$hash, resetRequired.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncPullResetData')
          ..add('changes', changes)
          ..add('nextCursor', nextCursor)
          ..add('hasMore', hasMore)
          ..add('resetRequired', resetRequired))
        .toString();
  }
}

class SyncPullResetDataBuilder
    implements Builder<SyncPullResetData, SyncPullResetDataBuilder> {
  _$SyncPullResetData? _$v;

  ListBuilder<SyncChange>? _changes;
  ListBuilder<SyncChange> get changes =>
      _$this._changes ??= ListBuilder<SyncChange>();
  set changes(ListBuilder<SyncChange>? changes) => _$this._changes = changes;

  SyncPullResetDataNextCursorEnum? _nextCursor;
  SyncPullResetDataNextCursorEnum? get nextCursor => _$this._nextCursor;
  set nextCursor(SyncPullResetDataNextCursorEnum? nextCursor) =>
      _$this._nextCursor = nextCursor;

  bool? _hasMore;
  bool? get hasMore => _$this._hasMore;
  set hasMore(bool? hasMore) => _$this._hasMore = hasMore;

  bool? _resetRequired;
  bool? get resetRequired => _$this._resetRequired;
  set resetRequired(bool? resetRequired) =>
      _$this._resetRequired = resetRequired;

  SyncPullResetDataBuilder() {
    SyncPullResetData._defaults(this);
  }

  SyncPullResetDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _changes = $v.changes.toBuilder();
      _nextCursor = $v.nextCursor;
      _hasMore = $v.hasMore;
      _resetRequired = $v.resetRequired;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncPullResetData other) {
    _$v = other as _$SyncPullResetData;
  }

  @override
  void update(void Function(SyncPullResetDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncPullResetData build() => _build();

  _$SyncPullResetData _build() {
    _$SyncPullResetData _$result;
    try {
      _$result =
          _$v ??
          _$SyncPullResetData._(
            changes: changes.build(),
            nextCursor: nextCursor,
            hasMore: BuiltValueNullFieldError.checkNotNull(
              hasMore,
              r'SyncPullResetData',
              'hasMore',
            ),
            resetRequired: BuiltValueNullFieldError.checkNotNull(
              resetRequired,
              r'SyncPullResetData',
              'resetRequired',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'changes';
        changes.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'SyncPullResetData',
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
