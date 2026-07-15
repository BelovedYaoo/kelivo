// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_patch_value_operation.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncPatchValueOperationOpEnum _$syncPatchValueOperationOpEnum_add =
    const SyncPatchValueOperationOpEnum._('add');
const SyncPatchValueOperationOpEnum _$syncPatchValueOperationOpEnum_replace =
    const SyncPatchValueOperationOpEnum._('replace');

SyncPatchValueOperationOpEnum _$syncPatchValueOperationOpEnumValueOf(
  String name,
) {
  switch (name) {
    case 'add':
      return _$syncPatchValueOperationOpEnum_add;
    case 'replace':
      return _$syncPatchValueOperationOpEnum_replace;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncPatchValueOperationOpEnum>
_$syncPatchValueOperationOpEnumValues = BuiltSet<SyncPatchValueOperationOpEnum>(
  const <SyncPatchValueOperationOpEnum>[
    _$syncPatchValueOperationOpEnum_add,
    _$syncPatchValueOperationOpEnum_replace,
  ],
);

Serializer<SyncPatchValueOperationOpEnum>
_$syncPatchValueOperationOpEnumSerializer =
    _$SyncPatchValueOperationOpEnumSerializer();

class _$SyncPatchValueOperationOpEnumSerializer
    implements PrimitiveSerializer<SyncPatchValueOperationOpEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'add': 'add',
    'replace': 'replace',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'add': 'add',
    'replace': 'replace',
  };

  @override
  final Iterable<Type> types = const <Type>[SyncPatchValueOperationOpEnum];
  @override
  final String wireName = 'SyncPatchValueOperationOpEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncPatchValueOperationOpEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncPatchValueOperationOpEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncPatchValueOperationOpEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncPatchValueOperation extends SyncPatchValueOperation {
  @override
  final SyncPatchValueOperationOpEnum op;
  @override
  final String path;
  @override
  final JsonObject? value;

  factory _$SyncPatchValueOperation([
    void Function(SyncPatchValueOperationBuilder)? updates,
  ]) => (SyncPatchValueOperationBuilder()..update(updates))._build();

  _$SyncPatchValueOperation._({
    required this.op,
    required this.path,
    this.value,
  }) : super._();
  @override
  SyncPatchValueOperation rebuild(
    void Function(SyncPatchValueOperationBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SyncPatchValueOperationBuilder toBuilder() =>
      SyncPatchValueOperationBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncPatchValueOperation &&
        op == other.op &&
        path == other.path &&
        value == other.value;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, op.hashCode);
    _$hash = $jc(_$hash, path.hashCode);
    _$hash = $jc(_$hash, value.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncPatchValueOperation')
          ..add('op', op)
          ..add('path', path)
          ..add('value', value))
        .toString();
  }
}

class SyncPatchValueOperationBuilder
    implements
        Builder<SyncPatchValueOperation, SyncPatchValueOperationBuilder> {
  _$SyncPatchValueOperation? _$v;

  SyncPatchValueOperationOpEnum? _op;
  SyncPatchValueOperationOpEnum? get op => _$this._op;
  set op(SyncPatchValueOperationOpEnum? op) => _$this._op = op;

  String? _path;
  String? get path => _$this._path;
  set path(String? path) => _$this._path = path;

  JsonObject? _value;
  JsonObject? get value => _$this._value;
  set value(JsonObject? value) => _$this._value = value;

  SyncPatchValueOperationBuilder() {
    SyncPatchValueOperation._defaults(this);
  }

  SyncPatchValueOperationBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _op = $v.op;
      _path = $v.path;
      _value = $v.value;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncPatchValueOperation other) {
    _$v = other as _$SyncPatchValueOperation;
  }

  @override
  void update(void Function(SyncPatchValueOperationBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncPatchValueOperation build() => _build();

  _$SyncPatchValueOperation _build() {
    final _$result =
        _$v ??
        _$SyncPatchValueOperation._(
          op: BuiltValueNullFieldError.checkNotNull(
            op,
            r'SyncPatchValueOperation',
            'op',
          ),
          path: BuiltValueNullFieldError.checkNotNull(
            path,
            r'SyncPatchValueOperation',
            'path',
          ),
          value: value,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
