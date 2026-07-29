// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_state_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DataRekeyStateDataPhaseEnum _$dataRekeyStateDataPhaseEnum_rekeyPending =
    const DataRekeyStateDataPhaseEnum._('rekeyPending');

DataRekeyStateDataPhaseEnum _$dataRekeyStateDataPhaseEnumValueOf(String name) {
  switch (name) {
    case 'rekeyPending':
      return _$dataRekeyStateDataPhaseEnum_rekeyPending;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DataRekeyStateDataPhaseEnum>
_$dataRekeyStateDataPhaseEnumValues = BuiltSet<DataRekeyStateDataPhaseEnum>(
  const <DataRekeyStateDataPhaseEnum>[
    _$dataRekeyStateDataPhaseEnum_rekeyPending,
  ],
);

Serializer<DataRekeyStateDataPhaseEnum>
_$dataRekeyStateDataPhaseEnumSerializer =
    _$DataRekeyStateDataPhaseEnumSerializer();

class _$DataRekeyStateDataPhaseEnumSerializer
    implements PrimitiveSerializer<DataRekeyStateDataPhaseEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'rekeyPending': 'rekey-pending',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'rekey-pending': 'rekeyPending',
  };

  @override
  final Iterable<Type> types = const <Type>[DataRekeyStateDataPhaseEnum];
  @override
  final String wireName = 'DataRekeyStateDataPhaseEnum';

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyStateDataPhaseEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  DataRekeyStateDataPhaseEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => DataRekeyStateDataPhaseEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$DataRekeyStateData extends DataRekeyStateData {
  @override
  final OneOf oneOf;

  factory _$DataRekeyStateData([
    void Function(DataRekeyStateDataBuilder)? updates,
  ]) => (DataRekeyStateDataBuilder()..update(updates))._build();

  _$DataRekeyStateData._({required this.oneOf}) : super._();
  @override
  DataRekeyStateData rebuild(
    void Function(DataRekeyStateDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeyStateDataBuilder toBuilder() =>
      DataRekeyStateDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeyStateData && oneOf == other.oneOf;
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
      r'DataRekeyStateData',
    )..add('oneOf', oneOf)).toString();
  }
}

class DataRekeyStateDataBuilder
    implements Builder<DataRekeyStateData, DataRekeyStateDataBuilder> {
  _$DataRekeyStateData? _$v;

  OneOf? _oneOf;
  OneOf? get oneOf => _$this._oneOf;
  set oneOf(OneOf? oneOf) => _$this._oneOf = oneOf;

  DataRekeyStateDataBuilder() {
    DataRekeyStateData._defaults(this);
  }

  DataRekeyStateDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _oneOf = $v.oneOf;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeyStateData other) {
    _$v = other as _$DataRekeyStateData;
  }

  @override
  void update(void Function(DataRekeyStateDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeyStateData build() => _build();

  _$DataRekeyStateData _build() {
    final _$result =
        _$v ??
        _$DataRekeyStateData._(
          oneOf: BuiltValueNullFieldError.checkNotNull(
            oneOf,
            r'DataRekeyStateData',
            'oneOf',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
