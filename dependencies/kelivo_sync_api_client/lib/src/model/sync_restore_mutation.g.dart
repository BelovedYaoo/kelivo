// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_restore_mutation.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncRestoreMutationOperationEnum
_$syncRestoreMutationOperationEnum_restore =
    const SyncRestoreMutationOperationEnum._('restore');

SyncRestoreMutationOperationEnum _$syncRestoreMutationOperationEnumValueOf(
  String name,
) {
  switch (name) {
    case 'restore':
      return _$syncRestoreMutationOperationEnum_restore;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncRestoreMutationOperationEnum>
_$syncRestoreMutationOperationEnumValues =
    BuiltSet<SyncRestoreMutationOperationEnum>(
      const <SyncRestoreMutationOperationEnum>[
        _$syncRestoreMutationOperationEnum_restore,
      ],
    );

Serializer<SyncRestoreMutationOperationEnum>
_$syncRestoreMutationOperationEnumSerializer =
    _$SyncRestoreMutationOperationEnumSerializer();

class _$SyncRestoreMutationOperationEnumSerializer
    implements PrimitiveSerializer<SyncRestoreMutationOperationEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'restore': 'restore',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'restore': 'restore',
  };

  @override
  final Iterable<Type> types = const <Type>[SyncRestoreMutationOperationEnum];
  @override
  final String wireName = 'SyncRestoreMutationOperationEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncRestoreMutationOperationEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncRestoreMutationOperationEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncRestoreMutationOperationEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncRestoreMutation extends SyncRestoreMutation {
  @override
  final String mutationId;
  @override
  final SyncEntityType entityType;
  @override
  final String entityId;
  @override
  final SyncRestoreMutationOperationEnum operation;
  @override
  final int baseRevision;

  factory _$SyncRestoreMutation([
    void Function(SyncRestoreMutationBuilder)? updates,
  ]) => (SyncRestoreMutationBuilder()..update(updates))._build();

  _$SyncRestoreMutation._({
    required this.mutationId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.baseRevision,
  }) : super._();
  @override
  SyncRestoreMutation rebuild(
    void Function(SyncRestoreMutationBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SyncRestoreMutationBuilder toBuilder() =>
      SyncRestoreMutationBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncRestoreMutation &&
        mutationId == other.mutationId &&
        entityType == other.entityType &&
        entityId == other.entityId &&
        operation == other.operation &&
        baseRevision == other.baseRevision;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, mutationId.hashCode);
    _$hash = $jc(_$hash, entityType.hashCode);
    _$hash = $jc(_$hash, entityId.hashCode);
    _$hash = $jc(_$hash, operation.hashCode);
    _$hash = $jc(_$hash, baseRevision.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncRestoreMutation')
          ..add('mutationId', mutationId)
          ..add('entityType', entityType)
          ..add('entityId', entityId)
          ..add('operation', operation)
          ..add('baseRevision', baseRevision))
        .toString();
  }
}

class SyncRestoreMutationBuilder
    implements Builder<SyncRestoreMutation, SyncRestoreMutationBuilder> {
  _$SyncRestoreMutation? _$v;

  String? _mutationId;
  String? get mutationId => _$this._mutationId;
  set mutationId(String? mutationId) => _$this._mutationId = mutationId;

  SyncEntityType? _entityType;
  SyncEntityType? get entityType => _$this._entityType;
  set entityType(SyncEntityType? entityType) => _$this._entityType = entityType;

  String? _entityId;
  String? get entityId => _$this._entityId;
  set entityId(String? entityId) => _$this._entityId = entityId;

  SyncRestoreMutationOperationEnum? _operation;
  SyncRestoreMutationOperationEnum? get operation => _$this._operation;
  set operation(SyncRestoreMutationOperationEnum? operation) =>
      _$this._operation = operation;

  int? _baseRevision;
  int? get baseRevision => _$this._baseRevision;
  set baseRevision(int? baseRevision) => _$this._baseRevision = baseRevision;

  SyncRestoreMutationBuilder() {
    SyncRestoreMutation._defaults(this);
  }

  SyncRestoreMutationBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _mutationId = $v.mutationId;
      _entityType = $v.entityType;
      _entityId = $v.entityId;
      _operation = $v.operation;
      _baseRevision = $v.baseRevision;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncRestoreMutation other) {
    _$v = other as _$SyncRestoreMutation;
  }

  @override
  void update(void Function(SyncRestoreMutationBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncRestoreMutation build() => _build();

  _$SyncRestoreMutation _build() {
    final _$result =
        _$v ??
        _$SyncRestoreMutation._(
          mutationId: BuiltValueNullFieldError.checkNotNull(
            mutationId,
            r'SyncRestoreMutation',
            'mutationId',
          ),
          entityType: BuiltValueNullFieldError.checkNotNull(
            entityType,
            r'SyncRestoreMutation',
            'entityType',
          ),
          entityId: BuiltValueNullFieldError.checkNotNull(
            entityId,
            r'SyncRestoreMutation',
            'entityId',
          ),
          operation: BuiltValueNullFieldError.checkNotNull(
            operation,
            r'SyncRestoreMutation',
            'operation',
          ),
          baseRevision: BuiltValueNullFieldError.checkNotNull(
            baseRevision,
            r'SyncRestoreMutation',
            'baseRevision',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
