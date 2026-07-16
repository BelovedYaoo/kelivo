// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_conflict.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncConflictStateEnum _$syncConflictStateEnum_open =
    const SyncConflictStateEnum._('open');
const SyncConflictStateEnum _$syncConflictStateEnum_resolved =
    const SyncConflictStateEnum._('resolved');

SyncConflictStateEnum _$syncConflictStateEnumValueOf(String name) {
  switch (name) {
    case 'open':
      return _$syncConflictStateEnum_open;
    case 'resolved':
      return _$syncConflictStateEnum_resolved;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncConflictStateEnum> _$syncConflictStateEnumValues =
    BuiltSet<SyncConflictStateEnum>(const <SyncConflictStateEnum>[
      _$syncConflictStateEnum_open,
      _$syncConflictStateEnum_resolved,
    ]);

Serializer<SyncConflictStateEnum> _$syncConflictStateEnumSerializer =
    _$SyncConflictStateEnumSerializer();

class _$SyncConflictStateEnumSerializer
    implements PrimitiveSerializer<SyncConflictStateEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'open': 'open',
    'resolved': 'resolved',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'open': 'open',
    'resolved': 'resolved',
  };

  @override
  final Iterable<Type> types = const <Type>[SyncConflictStateEnum];
  @override
  final String wireName = 'SyncConflictStateEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncConflictStateEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncConflictStateEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncConflictStateEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncConflict extends SyncConflict {
  @override
  final String conflictId;
  @override
  final String mutationId;
  @override
  final SyncEntityType entityType;
  @override
  final String entityId;
  @override
  final SyncConflictDetails details;
  @override
  final SyncConflictStateEnum state;
  @override
  final DateTime createdAt;
  @override
  final DateTime? resolvedAt;

  factory _$SyncConflict([void Function(SyncConflictBuilder)? updates]) =>
      (SyncConflictBuilder()..update(updates))._build();

  _$SyncConflict._({
    required this.conflictId,
    required this.mutationId,
    required this.entityType,
    required this.entityId,
    required this.details,
    required this.state,
    required this.createdAt,
    this.resolvedAt,
  }) : super._();
  @override
  SyncConflict rebuild(void Function(SyncConflictBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SyncConflictBuilder toBuilder() => SyncConflictBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncConflict &&
        conflictId == other.conflictId &&
        mutationId == other.mutationId &&
        entityType == other.entityType &&
        entityId == other.entityId &&
        details == other.details &&
        state == other.state &&
        createdAt == other.createdAt &&
        resolvedAt == other.resolvedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, conflictId.hashCode);
    _$hash = $jc(_$hash, mutationId.hashCode);
    _$hash = $jc(_$hash, entityType.hashCode);
    _$hash = $jc(_$hash, entityId.hashCode);
    _$hash = $jc(_$hash, details.hashCode);
    _$hash = $jc(_$hash, state.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jc(_$hash, resolvedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncConflict')
          ..add('conflictId', conflictId)
          ..add('mutationId', mutationId)
          ..add('entityType', entityType)
          ..add('entityId', entityId)
          ..add('details', details)
          ..add('state', state)
          ..add('createdAt', createdAt)
          ..add('resolvedAt', resolvedAt))
        .toString();
  }
}

class SyncConflictBuilder
    implements Builder<SyncConflict, SyncConflictBuilder> {
  _$SyncConflict? _$v;

  String? _conflictId;
  String? get conflictId => _$this._conflictId;
  set conflictId(String? conflictId) => _$this._conflictId = conflictId;

  String? _mutationId;
  String? get mutationId => _$this._mutationId;
  set mutationId(String? mutationId) => _$this._mutationId = mutationId;

  SyncEntityType? _entityType;
  SyncEntityType? get entityType => _$this._entityType;
  set entityType(SyncEntityType? entityType) => _$this._entityType = entityType;

  String? _entityId;
  String? get entityId => _$this._entityId;
  set entityId(String? entityId) => _$this._entityId = entityId;

  SyncConflictDetailsBuilder? _details;
  SyncConflictDetailsBuilder get details =>
      _$this._details ??= SyncConflictDetailsBuilder();
  set details(SyncConflictDetailsBuilder? details) => _$this._details = details;

  SyncConflictStateEnum? _state;
  SyncConflictStateEnum? get state => _$this._state;
  set state(SyncConflictStateEnum? state) => _$this._state = state;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  DateTime? _resolvedAt;
  DateTime? get resolvedAt => _$this._resolvedAt;
  set resolvedAt(DateTime? resolvedAt) => _$this._resolvedAt = resolvedAt;

  SyncConflictBuilder() {
    SyncConflict._defaults(this);
  }

  SyncConflictBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _conflictId = $v.conflictId;
      _mutationId = $v.mutationId;
      _entityType = $v.entityType;
      _entityId = $v.entityId;
      _details = $v.details.toBuilder();
      _state = $v.state;
      _createdAt = $v.createdAt;
      _resolvedAt = $v.resolvedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncConflict other) {
    _$v = other as _$SyncConflict;
  }

  @override
  void update(void Function(SyncConflictBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncConflict build() => _build();

  _$SyncConflict _build() {
    _$SyncConflict _$result;
    try {
      _$result =
          _$v ??
          _$SyncConflict._(
            conflictId: BuiltValueNullFieldError.checkNotNull(
              conflictId,
              r'SyncConflict',
              'conflictId',
            ),
            mutationId: BuiltValueNullFieldError.checkNotNull(
              mutationId,
              r'SyncConflict',
              'mutationId',
            ),
            entityType: BuiltValueNullFieldError.checkNotNull(
              entityType,
              r'SyncConflict',
              'entityType',
            ),
            entityId: BuiltValueNullFieldError.checkNotNull(
              entityId,
              r'SyncConflict',
              'entityId',
            ),
            details: details.build(),
            state: BuiltValueNullFieldError.checkNotNull(
              state,
              r'SyncConflict',
              'state',
            ),
            createdAt: BuiltValueNullFieldError.checkNotNull(
              createdAt,
              r'SyncConflict',
              'createdAt',
            ),
            resolvedAt: resolvedAt,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'details';
        details.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'SyncConflict',
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
