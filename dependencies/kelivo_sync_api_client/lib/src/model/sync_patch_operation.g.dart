// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_patch_operation.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncPatchOperationOpEnum _$syncPatchOperationOpEnum_remove =
    const SyncPatchOperationOpEnum._('remove');

SyncPatchOperationOpEnum _$syncPatchOperationOpEnumValueOf(String name) {
  switch (name) {
    case 'remove':
      return _$syncPatchOperationOpEnum_remove;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncPatchOperationOpEnum> _$syncPatchOperationOpEnumValues =
    BuiltSet<SyncPatchOperationOpEnum>(const <SyncPatchOperationOpEnum>[
      _$syncPatchOperationOpEnum_remove,
    ]);

Serializer<SyncPatchOperationOpEnum> _$syncPatchOperationOpEnumSerializer =
    _$SyncPatchOperationOpEnumSerializer();

class _$SyncPatchOperationOpEnumSerializer
    implements PrimitiveSerializer<SyncPatchOperationOpEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'remove': 'remove',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'remove': 'remove',
  };

  @override
  final Iterable<Type> types = const <Type>[SyncPatchOperationOpEnum];
  @override
  final String wireName = 'SyncPatchOperationOpEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncPatchOperationOpEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncPatchOperationOpEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncPatchOperationOpEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncPatchOperation extends SyncPatchOperation {
  @override
  final OneOf oneOf;

  factory _$SyncPatchOperation([
    void Function(SyncPatchOperationBuilder)? updates,
  ]) => (SyncPatchOperationBuilder()..update(updates))._build();

  _$SyncPatchOperation._({required this.oneOf}) : super._();
  @override
  SyncPatchOperation rebuild(
    void Function(SyncPatchOperationBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SyncPatchOperationBuilder toBuilder() =>
      SyncPatchOperationBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncPatchOperation && oneOf == other.oneOf;
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
      r'SyncPatchOperation',
    )..add('oneOf', oneOf)).toString();
  }
}

class SyncPatchOperationBuilder
    implements Builder<SyncPatchOperation, SyncPatchOperationBuilder> {
  _$SyncPatchOperation? _$v;

  OneOf? _oneOf;
  OneOf? get oneOf => _$this._oneOf;
  set oneOf(OneOf? oneOf) => _$this._oneOf = oneOf;

  SyncPatchOperationBuilder() {
    SyncPatchOperation._defaults(this);
  }

  SyncPatchOperationBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _oneOf = $v.oneOf;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncPatchOperation other) {
    _$v = other as _$SyncPatchOperation;
  }

  @override
  void update(void Function(SyncPatchOperationBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncPatchOperation build() => _build();

  _$SyncPatchOperation _build() {
    final _$result =
        _$v ??
        _$SyncPatchOperation._(
          oneOf: BuiltValueNullFieldError.checkNotNull(
            oneOf,
            r'SyncPatchOperation',
            'oneOf',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
