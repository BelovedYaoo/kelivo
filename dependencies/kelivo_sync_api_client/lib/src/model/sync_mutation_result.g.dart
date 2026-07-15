// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_mutation_result.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncMutationResultStatusEnum _$syncMutationResultStatusEnum_retry =
    const SyncMutationResultStatusEnum._('retry');

SyncMutationResultStatusEnum _$syncMutationResultStatusEnumValueOf(
  String name,
) {
  switch (name) {
    case 'retry':
      return _$syncMutationResultStatusEnum_retry;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncMutationResultStatusEnum>
_$syncMutationResultStatusEnumValues = BuiltSet<SyncMutationResultStatusEnum>(
  const <SyncMutationResultStatusEnum>[_$syncMutationResultStatusEnum_retry],
);

const SyncMutationResultReasonEnum _$syncMutationResultReasonEnum_entityExists =
    const SyncMutationResultReasonEnum._('entityExists');
const SyncMutationResultReasonEnum
_$syncMutationResultReasonEnum_entityMissing =
    const SyncMutationResultReasonEnum._('entityMissing');
const SyncMutationResultReasonEnum
_$syncMutationResultReasonEnum_entityDeleted =
    const SyncMutationResultReasonEnum._('entityDeleted');
const SyncMutationResultReasonEnum _$syncMutationResultReasonEnum_entityActive =
    const SyncMutationResultReasonEnum._('entityActive');
const SyncMutationResultReasonEnum
_$syncMutationResultReasonEnum_revisionAhead =
    const SyncMutationResultReasonEnum._('revisionAhead');
const SyncMutationResultReasonEnum
_$syncMutationResultReasonEnum_revisionStale =
    const SyncMutationResultReasonEnum._('revisionStale');

SyncMutationResultReasonEnum _$syncMutationResultReasonEnumValueOf(
  String name,
) {
  switch (name) {
    case 'entityExists':
      return _$syncMutationResultReasonEnum_entityExists;
    case 'entityMissing':
      return _$syncMutationResultReasonEnum_entityMissing;
    case 'entityDeleted':
      return _$syncMutationResultReasonEnum_entityDeleted;
    case 'entityActive':
      return _$syncMutationResultReasonEnum_entityActive;
    case 'revisionAhead':
      return _$syncMutationResultReasonEnum_revisionAhead;
    case 'revisionStale':
      return _$syncMutationResultReasonEnum_revisionStale;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncMutationResultReasonEnum>
_$syncMutationResultReasonEnumValues =
    BuiltSet<SyncMutationResultReasonEnum>(const <SyncMutationResultReasonEnum>[
      _$syncMutationResultReasonEnum_entityExists,
      _$syncMutationResultReasonEnum_entityMissing,
      _$syncMutationResultReasonEnum_entityDeleted,
      _$syncMutationResultReasonEnum_entityActive,
      _$syncMutationResultReasonEnum_revisionAhead,
      _$syncMutationResultReasonEnum_revisionStale,
    ]);

Serializer<SyncMutationResultStatusEnum>
_$syncMutationResultStatusEnumSerializer =
    _$SyncMutationResultStatusEnumSerializer();
Serializer<SyncMutationResultReasonEnum>
_$syncMutationResultReasonEnumSerializer =
    _$SyncMutationResultReasonEnumSerializer();

class _$SyncMutationResultStatusEnumSerializer
    implements PrimitiveSerializer<SyncMutationResultStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'retry': 'retry',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'retry': 'retry',
  };

  @override
  final Iterable<Type> types = const <Type>[SyncMutationResultStatusEnum];
  @override
  final String wireName = 'SyncMutationResultStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncMutationResultStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncMutationResultStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncMutationResultStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncMutationResultReasonEnumSerializer
    implements PrimitiveSerializer<SyncMutationResultReasonEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'entityExists': 'entity-exists',
    'entityMissing': 'entity-missing',
    'entityDeleted': 'entity-deleted',
    'entityActive': 'entity-active',
    'revisionAhead': 'revision-ahead',
    'revisionStale': 'revision-stale',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'entity-exists': 'entityExists',
    'entity-missing': 'entityMissing',
    'entity-deleted': 'entityDeleted',
    'entity-active': 'entityActive',
    'revision-ahead': 'revisionAhead',
    'revision-stale': 'revisionStale',
  };

  @override
  final Iterable<Type> types = const <Type>[SyncMutationResultReasonEnum];
  @override
  final String wireName = 'SyncMutationResultReasonEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncMutationResultReasonEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncMutationResultReasonEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncMutationResultReasonEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncMutationResult extends SyncMutationResult {
  @override
  final OneOf oneOf;

  factory _$SyncMutationResult([
    void Function(SyncMutationResultBuilder)? updates,
  ]) => (SyncMutationResultBuilder()..update(updates))._build();

  _$SyncMutationResult._({required this.oneOf}) : super._();
  @override
  SyncMutationResult rebuild(
    void Function(SyncMutationResultBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SyncMutationResultBuilder toBuilder() =>
      SyncMutationResultBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncMutationResult && oneOf == other.oneOf;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, oneOf.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
      r'SyncMutationResult',
    )..add('oneOf', oneOf)).toString();
  }
}

class SyncMutationResultBuilder
    implements Builder<SyncMutationResult, SyncMutationResultBuilder> {
  _$SyncMutationResult? _$v;

  OneOf? _oneOf;
  OneOf? get oneOf => _$this._oneOf;
  set oneOf(OneOf? oneOf) => _$this._oneOf = oneOf;

  SyncMutationResultBuilder() {
    SyncMutationResult._defaults(this);
  }

  SyncMutationResultBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _oneOf = $v.oneOf;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncMutationResult other) {
    _$v = other as _$SyncMutationResult;
  }

  @override
  void update(void Function(SyncMutationResultBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncMutationResult build() => _build();

  _$SyncMutationResult _build() {
    final _$result =
        _$v ??
        _$SyncMutationResult._(
          oneOf: BuiltValueNullFieldError.checkNotNull(
            oneOf,
            r'SyncMutationResult',
            'oneOf',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
