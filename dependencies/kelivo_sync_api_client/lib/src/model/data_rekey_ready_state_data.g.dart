// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_ready_state_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DataRekeyReadyStateDataPhaseEnum
_$dataRekeyReadyStateDataPhaseEnum_ready =
    const DataRekeyReadyStateDataPhaseEnum._('ready');

DataRekeyReadyStateDataPhaseEnum _$dataRekeyReadyStateDataPhaseEnumValueOf(
  String name,
) {
  switch (name) {
    case 'ready':
      return _$dataRekeyReadyStateDataPhaseEnum_ready;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DataRekeyReadyStateDataPhaseEnum>
_$dataRekeyReadyStateDataPhaseEnumValues =
    BuiltSet<DataRekeyReadyStateDataPhaseEnum>(
      const <DataRekeyReadyStateDataPhaseEnum>[
        _$dataRekeyReadyStateDataPhaseEnum_ready,
      ],
    );

Serializer<DataRekeyReadyStateDataPhaseEnum>
_$dataRekeyReadyStateDataPhaseEnumSerializer =
    _$DataRekeyReadyStateDataPhaseEnumSerializer();

class _$DataRekeyReadyStateDataPhaseEnumSerializer
    implements PrimitiveSerializer<DataRekeyReadyStateDataPhaseEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'ready': 'ready',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'ready': 'ready',
  };

  @override
  final Iterable<Type> types = const <Type>[DataRekeyReadyStateDataPhaseEnum];
  @override
  final String wireName = 'DataRekeyReadyStateDataPhaseEnum';

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyReadyStateDataPhaseEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  DataRekeyReadyStateDataPhaseEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => DataRekeyReadyStateDataPhaseEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$DataRekeyReadyStateData extends DataRekeyReadyStateData {
  @override
  final DataRekeyReadyStateDataPhaseEnum phase;
  @override
  final int dataGeneration;
  @override
  final int dataKeyEpoch;
  @override
  final int changeWatermark;
  @override
  final DataRekeyCompletionProofData? lastCompletion;
  @override
  final DateTime updatedAt;

  factory _$DataRekeyReadyStateData([
    void Function(DataRekeyReadyStateDataBuilder)? updates,
  ]) => (DataRekeyReadyStateDataBuilder()..update(updates))._build();

  _$DataRekeyReadyStateData._({
    required this.phase,
    required this.dataGeneration,
    required this.dataKeyEpoch,
    required this.changeWatermark,
    this.lastCompletion,
    required this.updatedAt,
  }) : super._();
  @override
  DataRekeyReadyStateData rebuild(
    void Function(DataRekeyReadyStateDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeyReadyStateDataBuilder toBuilder() =>
      DataRekeyReadyStateDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeyReadyStateData &&
        phase == other.phase &&
        dataGeneration == other.dataGeneration &&
        dataKeyEpoch == other.dataKeyEpoch &&
        changeWatermark == other.changeWatermark &&
        lastCompletion == other.lastCompletion &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, phase.hashCode);
    _$hash = $jc(_$hash, dataGeneration.hashCode);
    _$hash = $jc(_$hash, dataKeyEpoch.hashCode);
    _$hash = $jc(_$hash, changeWatermark.hashCode);
    _$hash = $jc(_$hash, lastCompletion.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DataRekeyReadyStateData')
          ..add('phase', phase)
          ..add('dataGeneration', dataGeneration)
          ..add('dataKeyEpoch', dataKeyEpoch)
          ..add('changeWatermark', changeWatermark)
          ..add('lastCompletion', lastCompletion)
          ..add('updatedAt', updatedAt))
        .toString();
  }
}

class DataRekeyReadyStateDataBuilder
    implements
        Builder<DataRekeyReadyStateData, DataRekeyReadyStateDataBuilder> {
  _$DataRekeyReadyStateData? _$v;

  DataRekeyReadyStateDataPhaseEnum? _phase;
  DataRekeyReadyStateDataPhaseEnum? get phase => _$this._phase;
  set phase(DataRekeyReadyStateDataPhaseEnum? phase) => _$this._phase = phase;

  int? _dataGeneration;
  int? get dataGeneration => _$this._dataGeneration;
  set dataGeneration(int? dataGeneration) =>
      _$this._dataGeneration = dataGeneration;

  int? _dataKeyEpoch;
  int? get dataKeyEpoch => _$this._dataKeyEpoch;
  set dataKeyEpoch(int? dataKeyEpoch) => _$this._dataKeyEpoch = dataKeyEpoch;

  int? _changeWatermark;
  int? get changeWatermark => _$this._changeWatermark;
  set changeWatermark(int? changeWatermark) =>
      _$this._changeWatermark = changeWatermark;

  DataRekeyCompletionProofDataBuilder? _lastCompletion;
  DataRekeyCompletionProofDataBuilder get lastCompletion =>
      _$this._lastCompletion ??= DataRekeyCompletionProofDataBuilder();
  set lastCompletion(DataRekeyCompletionProofDataBuilder? lastCompletion) =>
      _$this._lastCompletion = lastCompletion;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _$this._updatedAt;
  set updatedAt(DateTime? updatedAt) => _$this._updatedAt = updatedAt;

  DataRekeyReadyStateDataBuilder() {
    DataRekeyReadyStateData._defaults(this);
  }

  DataRekeyReadyStateDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _phase = $v.phase;
      _dataGeneration = $v.dataGeneration;
      _dataKeyEpoch = $v.dataKeyEpoch;
      _changeWatermark = $v.changeWatermark;
      _lastCompletion = $v.lastCompletion?.toBuilder();
      _updatedAt = $v.updatedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeyReadyStateData other) {
    _$v = other as _$DataRekeyReadyStateData;
  }

  @override
  void update(void Function(DataRekeyReadyStateDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeyReadyStateData build() => _build();

  _$DataRekeyReadyStateData _build() {
    _$DataRekeyReadyStateData _$result;
    try {
      _$result =
          _$v ??
          _$DataRekeyReadyStateData._(
            phase: BuiltValueNullFieldError.checkNotNull(
              phase,
              r'DataRekeyReadyStateData',
              'phase',
            ),
            dataGeneration: BuiltValueNullFieldError.checkNotNull(
              dataGeneration,
              r'DataRekeyReadyStateData',
              'dataGeneration',
            ),
            dataKeyEpoch: BuiltValueNullFieldError.checkNotNull(
              dataKeyEpoch,
              r'DataRekeyReadyStateData',
              'dataKeyEpoch',
            ),
            changeWatermark: BuiltValueNullFieldError.checkNotNull(
              changeWatermark,
              r'DataRekeyReadyStateData',
              'changeWatermark',
            ),
            lastCompletion: _lastCompletion?.build(),
            updatedAt: BuiltValueNullFieldError.checkNotNull(
              updatedAt,
              r'DataRekeyReadyStateData',
              'updatedAt',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'lastCompletion';
        _lastCompletion?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'DataRekeyReadyStateData',
          _$failedField,
          e.toString(),
        );
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
