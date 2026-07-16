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

const SyncMutationResultReasonEnum
_$syncMutationResultReasonEnum_fieldConflict =
    const SyncMutationResultReasonEnum._('fieldConflict');

SyncMutationResultReasonEnum _$syncMutationResultReasonEnumValueOf(
  String name,
) {
  switch (name) {
    case 'fieldConflict':
      return _$syncMutationResultReasonEnum_fieldConflict;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncMutationResultReasonEnum>
_$syncMutationResultReasonEnumValues = BuiltSet<SyncMutationResultReasonEnum>(
  const <SyncMutationResultReasonEnum>[
    _$syncMutationResultReasonEnum_fieldConflict,
  ],
);

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
    'fieldConflict': 'field-conflict',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'field-conflict': 'fieldConflict',
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
  final AnyOf anyOf;

  factory _$SyncMutationResult([
    void Function(SyncMutationResultBuilder)? updates,
  ]) => (SyncMutationResultBuilder()..update(updates))._build();

  _$SyncMutationResult._({required this.anyOf}) : super._();
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
    return other is SyncMutationResult && anyOf == other.anyOf;
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
      r'SyncMutationResult',
    )..add('anyOf', anyOf)).toString();
  }
}

class SyncMutationResultBuilder
    implements Builder<SyncMutationResult, SyncMutationResultBuilder> {
  _$SyncMutationResult? _$v;

  AnyOf? _anyOf;
  AnyOf? get anyOf => _$this._anyOf;
  set anyOf(AnyOf? anyOf) => _$this._anyOf = anyOf;

  SyncMutationResultBuilder() {
    SyncMutationResult._defaults(this);
  }

  SyncMutationResultBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _anyOf = $v.anyOf;
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
          anyOf: BuiltValueNullFieldError.checkNotNull(
            anyOf,
            r'SyncMutationResult',
            'anyOf',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
