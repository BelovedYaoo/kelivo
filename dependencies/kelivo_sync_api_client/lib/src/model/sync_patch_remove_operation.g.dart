// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_patch_remove_operation.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncPatchRemoveOperationOpEnum _$syncPatchRemoveOperationOpEnum_remove =
    const SyncPatchRemoveOperationOpEnum._('remove');

SyncPatchRemoveOperationOpEnum _$syncPatchRemoveOperationOpEnumValueOf(
  String name,
) {
  switch (name) {
    case 'remove':
      return _$syncPatchRemoveOperationOpEnum_remove;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncPatchRemoveOperationOpEnum>
_$syncPatchRemoveOperationOpEnumValues =
    BuiltSet<SyncPatchRemoveOperationOpEnum>(
      const <SyncPatchRemoveOperationOpEnum>[
        _$syncPatchRemoveOperationOpEnum_remove,
      ],
    );

Serializer<SyncPatchRemoveOperationOpEnum>
_$syncPatchRemoveOperationOpEnumSerializer =
    _$SyncPatchRemoveOperationOpEnumSerializer();

class _$SyncPatchRemoveOperationOpEnumSerializer
    implements PrimitiveSerializer<SyncPatchRemoveOperationOpEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'remove': 'remove',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'remove': 'remove',
  };

  @override
  final Iterable<Type> types = const <Type>[SyncPatchRemoveOperationOpEnum];
  @override
  final String wireName = 'SyncPatchRemoveOperationOpEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncPatchRemoveOperationOpEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncPatchRemoveOperationOpEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncPatchRemoveOperationOpEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncPatchRemoveOperation extends SyncPatchRemoveOperation {
  @override
  final SyncPatchRemoveOperationOpEnum op;
  @override
  final String path;

  factory _$SyncPatchRemoveOperation([
    void Function(SyncPatchRemoveOperationBuilder)? updates,
  ]) => (SyncPatchRemoveOperationBuilder()..update(updates))._build();

  _$SyncPatchRemoveOperation._({required this.op, required this.path})
    : super._();
  @override
  SyncPatchRemoveOperation rebuild(
    void Function(SyncPatchRemoveOperationBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  SyncPatchRemoveOperationBuilder toBuilder() =>
      SyncPatchRemoveOperationBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncPatchRemoveOperation &&
        op == other.op &&
        path == other.path;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, op.hashCode);
    _$hash = $jc(_$hash, path.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncPatchRemoveOperation')
          ..add('op', op)
          ..add('path', path))
        .toString();
  }
}

class SyncPatchRemoveOperationBuilder
    implements
        Builder<SyncPatchRemoveOperation, SyncPatchRemoveOperationBuilder> {
  _$SyncPatchRemoveOperation? _$v;

  SyncPatchRemoveOperationOpEnum? _op;
  SyncPatchRemoveOperationOpEnum? get op => _$this._op;
  set op(SyncPatchRemoveOperationOpEnum? op) => _$this._op = op;

  String? _path;
  String? get path => _$this._path;
  set path(String? path) => _$this._path = path;

  SyncPatchRemoveOperationBuilder() {
    SyncPatchRemoveOperation._defaults(this);
  }

  SyncPatchRemoveOperationBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _op = $v.op;
      _path = $v.path;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncPatchRemoveOperation other) {
    _$v = other as _$SyncPatchRemoveOperation;
  }

  @override
  void update(void Function(SyncPatchRemoveOperationBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncPatchRemoveOperation build() => _build();

  _$SyncPatchRemoveOperation _build() {
    final _$result =
        _$v ??
        _$SyncPatchRemoveOperation._(
          op: BuiltValueNullFieldError.checkNotNull(
            op,
            r'SyncPatchRemoveOperation',
            'op',
          ),
          path: BuiltValueNullFieldError.checkNotNull(
            path,
            r'SyncPatchRemoveOperation',
            'path',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
