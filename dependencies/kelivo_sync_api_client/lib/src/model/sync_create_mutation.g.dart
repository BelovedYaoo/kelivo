// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_create_mutation.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncCreateMutationOperationEnum _$syncCreateMutationOperationEnum_create =
    const SyncCreateMutationOperationEnum._('create');

SyncCreateMutationOperationEnum _$syncCreateMutationOperationEnumValueOf(
  String name,
) {
  switch (name) {
    case 'create':
      return _$syncCreateMutationOperationEnum_create;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncCreateMutationOperationEnum>
_$syncCreateMutationOperationEnumValues =
    BuiltSet<SyncCreateMutationOperationEnum>(
      const <SyncCreateMutationOperationEnum>[
        _$syncCreateMutationOperationEnum_create,
      ],
    );

Serializer<SyncCreateMutationOperationEnum>
_$syncCreateMutationOperationEnumSerializer =
    _$SyncCreateMutationOperationEnumSerializer();

class _$SyncCreateMutationOperationEnumSerializer
    implements PrimitiveSerializer<SyncCreateMutationOperationEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'create': 'create',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'create': 'create',
  };

  @override
  final Iterable<Type> types = const <Type>[SyncCreateMutationOperationEnum];
  @override
  final String wireName = 'SyncCreateMutationOperationEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncCreateMutationOperationEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncCreateMutationOperationEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncCreateMutationOperationEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncCreateMutation extends SyncCreateMutation {
  @override
  final String mutationId;
  @override
  final SyncEntityType entityType;
  @override
  final String entityId;
  @override
  final SyncCreateMutationOperationEnum operation;
  @override
  final String? parentId;
  @override
  final int schemaVersion;
  @override
  final BuiltMap<String, JsonObject?> payload;

  factory _$SyncCreateMutation([
    void Function(SyncCreateMutationBuilder)? updates,
  ]) => (SyncCreateMutationBuilder()..update(updates))._build();

  _$SyncCreateMutation._({
    required this.mutationId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    this.parentId,
    required this.schemaVersion,
    required this.payload,
  }) : super._();
  @override
  SyncCreateMutation rebuild(
    void Function(SyncCreateMutationBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SyncCreateMutationBuilder toBuilder() =>
      SyncCreateMutationBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncCreateMutation &&
        mutationId == other.mutationId &&
        entityType == other.entityType &&
        entityId == other.entityId &&
        operation == other.operation &&
        parentId == other.parentId &&
        schemaVersion == other.schemaVersion &&
        payload == other.payload;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, mutationId.hashCode);
    _$hash = $jc(_$hash, entityType.hashCode);
    _$hash = $jc(_$hash, entityId.hashCode);
    _$hash = $jc(_$hash, operation.hashCode);
    _$hash = $jc(_$hash, parentId.hashCode);
    _$hash = $jc(_$hash, schemaVersion.hashCode);
    _$hash = $jc(_$hash, payload.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncCreateMutation')
          ..add('mutationId', mutationId)
          ..add('entityType', entityType)
          ..add('entityId', entityId)
          ..add('operation', operation)
          ..add('parentId', parentId)
          ..add('schemaVersion', schemaVersion)
          ..add('payload', payload))
        .toString();
  }
}

class SyncCreateMutationBuilder
    implements Builder<SyncCreateMutation, SyncCreateMutationBuilder> {
  _$SyncCreateMutation? _$v;

  String? _mutationId;
  String? get mutationId => _$this._mutationId;
  set mutationId(String? mutationId) => _$this._mutationId = mutationId;

  SyncEntityType? _entityType;
  SyncEntityType? get entityType => _$this._entityType;
  set entityType(SyncEntityType? entityType) => _$this._entityType = entityType;

  String? _entityId;
  String? get entityId => _$this._entityId;
  set entityId(String? entityId) => _$this._entityId = entityId;

  SyncCreateMutationOperationEnum? _operation;
  SyncCreateMutationOperationEnum? get operation => _$this._operation;
  set operation(SyncCreateMutationOperationEnum? operation) =>
      _$this._operation = operation;

  String? _parentId;
  String? get parentId => _$this._parentId;
  set parentId(String? parentId) => _$this._parentId = parentId;

  int? _schemaVersion;
  int? get schemaVersion => _$this._schemaVersion;
  set schemaVersion(int? schemaVersion) =>
      _$this._schemaVersion = schemaVersion;

  MapBuilder<String, JsonObject?>? _payload;
  MapBuilder<String, JsonObject?> get payload =>
      _$this._payload ??= MapBuilder<String, JsonObject?>();
  set payload(MapBuilder<String, JsonObject?>? payload) =>
      _$this._payload = payload;

  SyncCreateMutationBuilder() {
    SyncCreateMutation._defaults(this);
  }

  SyncCreateMutationBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _mutationId = $v.mutationId;
      _entityType = $v.entityType;
      _entityId = $v.entityId;
      _operation = $v.operation;
      _parentId = $v.parentId;
      _schemaVersion = $v.schemaVersion;
      _payload = $v.payload.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncCreateMutation other) {
    _$v = other as _$SyncCreateMutation;
  }

  @override
  void update(void Function(SyncCreateMutationBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncCreateMutation build() => _build();

  _$SyncCreateMutation _build() {
    _$SyncCreateMutation _$result;
    try {
      _$result =
          _$v ??
          _$SyncCreateMutation._(
            mutationId: BuiltValueNullFieldError.checkNotNull(
              mutationId,
              r'SyncCreateMutation',
              'mutationId',
            ),
            entityType: BuiltValueNullFieldError.checkNotNull(
              entityType,
              r'SyncCreateMutation',
              'entityType',
            ),
            entityId: BuiltValueNullFieldError.checkNotNull(
              entityId,
              r'SyncCreateMutation',
              'entityId',
            ),
            operation: BuiltValueNullFieldError.checkNotNull(
              operation,
              r'SyncCreateMutation',
              'operation',
            ),
            parentId: parentId,
            schemaVersion: BuiltValueNullFieldError.checkNotNull(
              schemaVersion,
              r'SyncCreateMutation',
              'schemaVersion',
            ),
            payload: payload.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'payload';
        payload.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'SyncCreateMutation',
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
