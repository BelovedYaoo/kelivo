// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_change.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncChangeOperationEnum _$syncChangeOperationEnum_delete =
    const SyncChangeOperationEnum._('delete');

SyncChangeOperationEnum _$syncChangeOperationEnumValueOf(String name) {
  switch (name) {
    case 'delete':
      return _$syncChangeOperationEnum_delete;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncChangeOperationEnum> _$syncChangeOperationEnumValues =
    BuiltSet<SyncChangeOperationEnum>(const <SyncChangeOperationEnum>[
      _$syncChangeOperationEnum_delete,
    ]);

Serializer<SyncChangeOperationEnum> _$syncChangeOperationEnumSerializer =
    _$SyncChangeOperationEnumSerializer();

class _$SyncChangeOperationEnumSerializer
    implements PrimitiveSerializer<SyncChangeOperationEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'delete': 'delete',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'delete': 'delete',
  };

  @override
  final Iterable<Type> types = const <Type>[SyncChangeOperationEnum];
  @override
  final String wireName = 'SyncChangeOperationEnum';

  @override
  Object serialize(
    Serializers serializers,
    SyncChangeOperationEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  SyncChangeOperationEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => SyncChangeOperationEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$SyncChange extends SyncChange {
  @override
  final OneOf oneOf;

  factory _$SyncChange([void Function(SyncChangeBuilder)? updates]) =>
      (SyncChangeBuilder()..update(updates))._build();

  _$SyncChange._({required this.oneOf}) : super._();
  @override
  SyncChange rebuild(void Function(SyncChangeBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SyncChangeBuilder toBuilder() => SyncChangeBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncChange && oneOf == other.oneOf;
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
      r'SyncChange',
    )..add('oneOf', oneOf)).toString();
  }
}

class SyncChangeBuilder implements Builder<SyncChange, SyncChangeBuilder> {
  _$SyncChange? _$v;

  OneOf? _oneOf;
  OneOf? get oneOf => _$this._oneOf;
  set oneOf(OneOf? oneOf) => _$this._oneOf = oneOf;

  SyncChangeBuilder() {
    SyncChange._defaults(this);
  }

  SyncChangeBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _oneOf = $v.oneOf;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncChange other) {
    _$v = other as _$SyncChange;
  }

  @override
  void update(void Function(SyncChangeBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncChange build() => _build();

  _$SyncChange _build() {
    final _$result =
        _$v ??
        _$SyncChange._(
          oneOf: BuiltValueNullFieldError.checkNotNull(
            oneOf,
            r'SyncChange',
            'oneOf',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
