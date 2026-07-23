// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_mutation_result.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncMutationResultStatusEnum _$syncMutationResultStatusEnum_rejected =
    const SyncMutationResultStatusEnum._('rejected');

SyncMutationResultStatusEnum _$syncMutationResultStatusEnumValueOf(
  String name,
) {
  switch (name) {
    case 'rejected':
      return _$syncMutationResultStatusEnum_rejected;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncMutationResultStatusEnum>
_$syncMutationResultStatusEnumValues = BuiltSet<SyncMutationResultStatusEnum>(
  const <SyncMutationResultStatusEnum>[_$syncMutationResultStatusEnum_rejected],
);

Serializer<SyncMutationResultStatusEnum>
_$syncMutationResultStatusEnumSerializer =
    _$SyncMutationResultStatusEnumSerializer();

class _$SyncMutationResultStatusEnumSerializer
    implements PrimitiveSerializer<SyncMutationResultStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'rejected': 'rejected',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'rejected': 'rejected',
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
