// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_update_mutation.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncUpdateMutationOperationEnum _$syncUpdateMutationOperationEnum_update =
    const SyncUpdateMutationOperationEnum._('update');

SyncUpdateMutationOperationEnum _$syncUpdateMutationOperationEnumValueOf(
  String name,
) {
  switch (name) {
    case 'update':
      return _$syncUpdateMutationOperationEnum_update;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncUpdateMutationOperationEnum>
_$syncUpdateMutationOperationEnumValues =
    BuiltSet<SyncUpdateMutationOperationEnum>(
      const <SyncUpdateMutationOperationEnum>[
        _$syncUpdateMutationOperationEnum_update,
      ],
    );

Serializer<SyncUpdateMutationOperationEnum>
_$syncUpdateMutationOperationEnumSerializer =
    _$SyncUpdateMutationOperationEnumSerializer();

class _$SyncUpdateMutationOperationEnumSerializer
    implements PrimitiveSerializer<SyncUpdateMutationOperationEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'update': 'update',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'update': 'update',
  };

  @override
  final Iterable<Type> types = const <Type>[SyncUpdateMutationOperationEnum];
  @override
  final String wireName = 'SyncUpdateMutationOperationEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncUpdateMutationOperationEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncUpdateMutationOperationEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncUpdateMutationOperationEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncUpdateMutation extends SyncUpdateMutation {
  @override
  final String mutationId;
  @override
  final SyncEntityType entityType;
  @override
  final String entityId;
  @override
  final SyncUpdateMutationOperationEnum operation;
  @override
  final int baseRevision;
  @override
  final int? schemaVersion;
  @override
  final BuiltList<SyncPatchOperation> patch_;

  factory _$SyncUpdateMutation([
    void Function(SyncUpdateMutationBuilder)? updates,
  ]) => (SyncUpdateMutationBuilder()..update(updates))._build();

  _$SyncUpdateMutation._({
    required this.mutationId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.baseRevision,
    this.schemaVersion,
    required this.patch_,
  }) : super._();
  @override
  SyncUpdateMutation rebuild(
    void Function(SyncUpdateMutationBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SyncUpdateMutationBuilder toBuilder() =>
      SyncUpdateMutationBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncUpdateMutation &&
        mutationId == other.mutationId &&
        entityType == other.entityType &&
        entityId == other.entityId &&
        operation == other.operation &&
        baseRevision == other.baseRevision &&
        schemaVersion == other.schemaVersion &&
        patch_ == other.patch_;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, mutationId.hashCode);
    _$hash = $jc(_$hash, entityType.hashCode);
    _$hash = $jc(_$hash, entityId.hashCode);
    _$hash = $jc(_$hash, operation.hashCode);
    _$hash = $jc(_$hash, baseRevision.hashCode);
    _$hash = $jc(_$hash, schemaVersion.hashCode);
    _$hash = $jc(_$hash, patch_.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncUpdateMutation')
          ..add('mutationId', mutationId)
          ..add('entityType', entityType)
          ..add('entityId', entityId)
          ..add('operation', operation)
          ..add('baseRevision', baseRevision)
          ..add('schemaVersion', schemaVersion)
          ..add('patch_', patch_))
        .toString();
  }
}

class SyncUpdateMutationBuilder
    implements Builder<SyncUpdateMutation, SyncUpdateMutationBuilder> {
  _$SyncUpdateMutation? _$v;

  String? _mutationId;
  String? get mutationId => _$this._mutationId;
  set mutationId(String? mutationId) => _$this._mutationId = mutationId;

  SyncEntityType? _entityType;
  SyncEntityType? get entityType => _$this._entityType;
  set entityType(SyncEntityType? entityType) => _$this._entityType = entityType;

  String? _entityId;
  String? get entityId => _$this._entityId;
  set entityId(String? entityId) => _$this._entityId = entityId;

  SyncUpdateMutationOperationEnum? _operation;
  SyncUpdateMutationOperationEnum? get operation => _$this._operation;
  set operation(SyncUpdateMutationOperationEnum? operation) =>
      _$this._operation = operation;

  int? _baseRevision;
  int? get baseRevision => _$this._baseRevision;
  set baseRevision(int? baseRevision) => _$this._baseRevision = baseRevision;

  int? _schemaVersion;
  int? get schemaVersion => _$this._schemaVersion;
  set schemaVersion(int? schemaVersion) =>
      _$this._schemaVersion = schemaVersion;

  ListBuilder<SyncPatchOperation>? _patch_;
  ListBuilder<SyncPatchOperation> get patch_ =>
      _$this._patch_ ??= ListBuilder<SyncPatchOperation>();
  set patch_(ListBuilder<SyncPatchOperation>? patch_) =>
      _$this._patch_ = patch_;

  SyncUpdateMutationBuilder() {
    SyncUpdateMutation._defaults(this);
  }

  SyncUpdateMutationBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _mutationId = $v.mutationId;
      _entityType = $v.entityType;
      _entityId = $v.entityId;
      _operation = $v.operation;
      _baseRevision = $v.baseRevision;
      _schemaVersion = $v.schemaVersion;
      _patch_ = $v.patch_.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncUpdateMutation other) {
    _$v = other as _$SyncUpdateMutation;
  }

  @override
  void update(void Function(SyncUpdateMutationBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncUpdateMutation build() => _build();

  _$SyncUpdateMutation _build() {
    _$SyncUpdateMutation _$result;
    try {
      _$result =
          _$v ??
          _$SyncUpdateMutation._(
            mutationId: BuiltValueNullFieldError.checkNotNull(
              mutationId,
              r'SyncUpdateMutation',
              'mutationId',
            ),
            entityType: BuiltValueNullFieldError.checkNotNull(
              entityType,
              r'SyncUpdateMutation',
              'entityType',
            ),
            entityId: BuiltValueNullFieldError.checkNotNull(
              entityId,
              r'SyncUpdateMutation',
              'entityId',
            ),
            operation: BuiltValueNullFieldError.checkNotNull(
              operation,
              r'SyncUpdateMutation',
              'operation',
            ),
            baseRevision: BuiltValueNullFieldError.checkNotNull(
              baseRevision,
              r'SyncUpdateMutation',
              'baseRevision',
            ),
            schemaVersion: schemaVersion,
            patch_: patch_.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'patch_';
        patch_.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'SyncUpdateMutation',
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
