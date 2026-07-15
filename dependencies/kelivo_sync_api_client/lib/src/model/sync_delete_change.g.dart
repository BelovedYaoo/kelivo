// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_delete_change.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncDeleteChangeOperationEnum _$syncDeleteChangeOperationEnum_delete =
    const SyncDeleteChangeOperationEnum._('delete');

SyncDeleteChangeOperationEnum _$syncDeleteChangeOperationEnumValueOf(
  String name,
) {
  switch (name) {
    case 'delete':
      return _$syncDeleteChangeOperationEnum_delete;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncDeleteChangeOperationEnum>
_$syncDeleteChangeOperationEnumValues = BuiltSet<SyncDeleteChangeOperationEnum>(
  const <SyncDeleteChangeOperationEnum>[_$syncDeleteChangeOperationEnum_delete],
);

Serializer<SyncDeleteChangeOperationEnum>
_$syncDeleteChangeOperationEnumSerializer =
    _$SyncDeleteChangeOperationEnumSerializer();

class _$SyncDeleteChangeOperationEnumSerializer
    implements PrimitiveSerializer<SyncDeleteChangeOperationEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'delete': 'delete',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'delete': 'delete',
  };

  @override
  final Iterable<Type> types = const <Type>[SyncDeleteChangeOperationEnum];
  @override
  final String wireName = 'SyncDeleteChangeOperationEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncDeleteChangeOperationEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncDeleteChangeOperationEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncDeleteChangeOperationEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncDeleteChange extends SyncDeleteChange {
  @override
  final int changeSeq;
  @override
  final SyncDeleteChangeOperationEnum operation;
  @override
  final SyncEntityType entityType;
  @override
  final String entityId;
  @override
  final int revision;
  @override
  final DateTime deletedAt;

  factory _$SyncDeleteChange([
    void Function(SyncDeleteChangeBuilder)? updates,
  ]) => (SyncDeleteChangeBuilder()..update(updates))._build();

  _$SyncDeleteChange._({
    required this.changeSeq,
    required this.operation,
    required this.entityType,
    required this.entityId,
    required this.revision,
    required this.deletedAt,
  }) : super._();
  @override
  SyncDeleteChange rebuild(void Function(SyncDeleteChangeBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SyncDeleteChangeBuilder toBuilder() =>
      SyncDeleteChangeBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncDeleteChange &&
        changeSeq == other.changeSeq &&
        operation == other.operation &&
        entityType == other.entityType &&
        entityId == other.entityId &&
        revision == other.revision &&
        deletedAt == other.deletedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, changeSeq.hashCode);
    _$hash = $jc(_$hash, operation.hashCode);
    _$hash = $jc(_$hash, entityType.hashCode);
    _$hash = $jc(_$hash, entityId.hashCode);
    _$hash = $jc(_$hash, revision.hashCode);
    _$hash = $jc(_$hash, deletedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncDeleteChange')
          ..add('changeSeq', changeSeq)
          ..add('operation', operation)
          ..add('entityType', entityType)
          ..add('entityId', entityId)
          ..add('revision', revision)
          ..add('deletedAt', deletedAt))
        .toString();
  }
}

class SyncDeleteChangeBuilder
    implements Builder<SyncDeleteChange, SyncDeleteChangeBuilder> {
  _$SyncDeleteChange? _$v;

  int? _changeSeq;
  int? get changeSeq => _$this._changeSeq;
  set changeSeq(int? changeSeq) => _$this._changeSeq = changeSeq;

  SyncDeleteChangeOperationEnum? _operation;
  SyncDeleteChangeOperationEnum? get operation => _$this._operation;
  set operation(SyncDeleteChangeOperationEnum? operation) =>
      _$this._operation = operation;

  SyncEntityType? _entityType;
  SyncEntityType? get entityType => _$this._entityType;
  set entityType(SyncEntityType? entityType) => _$this._entityType = entityType;

  String? _entityId;
  String? get entityId => _$this._entityId;
  set entityId(String? entityId) => _$this._entityId = entityId;

  int? _revision;
  int? get revision => _$this._revision;
  set revision(int? revision) => _$this._revision = revision;

  DateTime? _deletedAt;
  DateTime? get deletedAt => _$this._deletedAt;
  set deletedAt(DateTime? deletedAt) => _$this._deletedAt = deletedAt;

  SyncDeleteChangeBuilder() {
    SyncDeleteChange._defaults(this);
  }

  SyncDeleteChangeBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _changeSeq = $v.changeSeq;
      _operation = $v.operation;
      _entityType = $v.entityType;
      _entityId = $v.entityId;
      _revision = $v.revision;
      _deletedAt = $v.deletedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncDeleteChange other) {
    _$v = other as _$SyncDeleteChange;
  }

  @override
  void update(void Function(SyncDeleteChangeBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncDeleteChange build() => _build();

  _$SyncDeleteChange _build() {
    final _$result =
        _$v ??
        _$SyncDeleteChange._(
          changeSeq: BuiltValueNullFieldError.checkNotNull(
            changeSeq,
            r'SyncDeleteChange',
            'changeSeq',
          ),
          operation: BuiltValueNullFieldError.checkNotNull(
            operation,
            r'SyncDeleteChange',
            'operation',
          ),
          entityType: BuiltValueNullFieldError.checkNotNull(
            entityType,
            r'SyncDeleteChange',
            'entityType',
          ),
          entityId: BuiltValueNullFieldError.checkNotNull(
            entityId,
            r'SyncDeleteChange',
            'entityId',
          ),
          revision: BuiltValueNullFieldError.checkNotNull(
            revision,
            r'SyncDeleteChange',
            'revision',
          ),
          deletedAt: BuiltValueNullFieldError.checkNotNull(
            deletedAt,
            r'SyncDeleteChange',
            'deletedAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
