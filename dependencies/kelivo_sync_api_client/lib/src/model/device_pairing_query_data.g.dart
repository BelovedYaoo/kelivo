// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_pairing_query_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DevicePairingQueryDataStatusEnum
_$devicePairingQueryDataStatusEnum_approved =
    const DevicePairingQueryDataStatusEnum._('approved');

DevicePairingQueryDataStatusEnum _$devicePairingQueryDataStatusEnumValueOf(
  String name,
) {
  switch (name) {
    case 'approved':
      return _$devicePairingQueryDataStatusEnum_approved;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DevicePairingQueryDataStatusEnum>
_$devicePairingQueryDataStatusEnumValues =
    BuiltSet<DevicePairingQueryDataStatusEnum>(
      const <DevicePairingQueryDataStatusEnum>[
        _$devicePairingQueryDataStatusEnum_approved,
      ],
    );

Serializer<DevicePairingQueryDataStatusEnum>
_$devicePairingQueryDataStatusEnumSerializer =
    _$DevicePairingQueryDataStatusEnumSerializer();

class _$DevicePairingQueryDataStatusEnumSerializer
    implements PrimitiveSerializer<DevicePairingQueryDataStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'approved': 'approved',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'approved': 'approved',
  };

  @override
  final Iterable<Type> types = const <Type>[DevicePairingQueryDataStatusEnum];
  @override
  final String wireName = 'DevicePairingQueryDataStatusEnum';

  @override
  Object serialize(
    Serializers serializers,
    DevicePairingQueryDataStatusEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  DevicePairingQueryDataStatusEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => DevicePairingQueryDataStatusEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$DevicePairingQueryData extends DevicePairingQueryData {
  @override
  final OneOf oneOf;

  factory _$DevicePairingQueryData([
    void Function(DevicePairingQueryDataBuilder)? updates,
  ]) => (DevicePairingQueryDataBuilder()..update(updates))._build();

  _$DevicePairingQueryData._({required this.oneOf}) : super._();
  @override
  DevicePairingQueryData rebuild(
    void Function(DevicePairingQueryDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DevicePairingQueryDataBuilder toBuilder() =>
      DevicePairingQueryDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DevicePairingQueryData && oneOf == other.oneOf;
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
      r'DevicePairingQueryData',
    )..add('oneOf', oneOf)).toString();
  }
}

class DevicePairingQueryDataBuilder
    implements Builder<DevicePairingQueryData, DevicePairingQueryDataBuilder> {
  _$DevicePairingQueryData? _$v;

  OneOf? _oneOf;
  OneOf? get oneOf => _$this._oneOf;
  set oneOf(OneOf? oneOf) => _$this._oneOf = oneOf;

  DevicePairingQueryDataBuilder() {
    DevicePairingQueryData._defaults(this);
  }

  DevicePairingQueryDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _oneOf = $v.oneOf;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DevicePairingQueryData other) {
    _$v = other as _$DevicePairingQueryData;
  }

  @override
  void update(void Function(DevicePairingQueryDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DevicePairingQueryData build() => _build();

  _$DevicePairingQueryData _build() {
    final _$result =
        _$v ??
        _$DevicePairingQueryData._(
          oneOf: BuiltValueNullFieldError.checkNotNull(
            oneOf,
            r'DevicePairingQueryData',
            'oneOf',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
