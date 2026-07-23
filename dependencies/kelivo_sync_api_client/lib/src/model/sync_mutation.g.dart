// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_mutation.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncMutationOperationEnum _$syncMutationOperationEnum_delete =
    const SyncMutationOperationEnum._('delete');

SyncMutationOperationEnum _$syncMutationOperationEnumValueOf(String name) {
  switch (name) {
    case 'delete':
      return _$syncMutationOperationEnum_delete;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncMutationOperationEnum> _$syncMutationOperationEnumValues =
    BuiltSet<SyncMutationOperationEnum>(const <SyncMutationOperationEnum>[
      _$syncMutationOperationEnum_delete,
    ]);

Serializer<SyncMutationOperationEnum> _$syncMutationOperationEnumSerializer =
    _$SyncMutationOperationEnumSerializer();

class _$SyncMutationOperationEnumSerializer
    implements PrimitiveSerializer<SyncMutationOperationEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'delete': 'delete',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'delete': 'delete',
  };

  @override
  final Iterable<Type> types = const <Type>[SyncMutationOperationEnum];
  @override
  final String wireName = 'SyncMutationOperationEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncMutationOperationEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncMutationOperationEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncMutationOperationEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncMutation extends SyncMutation {
  @override
  final OneOf oneOf;

  factory _$SyncMutation([void Function(SyncMutationBuilder)? updates]) =>
      (SyncMutationBuilder()..update(updates))._build();

  _$SyncMutation._({required this.oneOf}) : super._();
  @override
  SyncMutation rebuild(void Function(SyncMutationBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SyncMutationBuilder toBuilder() => SyncMutationBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncMutation && oneOf == other.oneOf;
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
      r'SyncMutation',
    )..add('oneOf', oneOf)).toString();
  }
}

class SyncMutationBuilder
    implements Builder<SyncMutation, SyncMutationBuilder> {
  _$SyncMutation? _$v;

  OneOf? _oneOf;
  OneOf? get oneOf => _$this._oneOf;
  set oneOf(OneOf? oneOf) => _$this._oneOf = oneOf;

  SyncMutationBuilder() {
    SyncMutation._defaults(this);
  }

  SyncMutationBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _oneOf = $v.oneOf;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncMutation other) {
    _$v = other as _$SyncMutation;
  }

  @override
  void update(void Function(SyncMutationBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncMutation build() => _build();

  _$SyncMutation _build() {
    final _$result =
        _$v ??
        _$SyncMutation._(
          oneOf: BuiltValueNullFieldError.checkNotNull(
            oneOf,
            r'SyncMutation',
            'oneOf',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
