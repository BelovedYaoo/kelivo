// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_finalized_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DataRekeyFinalizedDataResultEnum
_$dataRekeyFinalizedDataResultEnum_finalized =
    const DataRekeyFinalizedDataResultEnum._('finalized');

DataRekeyFinalizedDataResultEnum _$dataRekeyFinalizedDataResultEnumValueOf(
  String name,
) {
  switch (name) {
    case 'finalized':
      return _$dataRekeyFinalizedDataResultEnum_finalized;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DataRekeyFinalizedDataResultEnum>
_$dataRekeyFinalizedDataResultEnumValues =
    BuiltSet<DataRekeyFinalizedDataResultEnum>(
      const <DataRekeyFinalizedDataResultEnum>[
        _$dataRekeyFinalizedDataResultEnum_finalized,
      ],
    );

Serializer<DataRekeyFinalizedDataResultEnum>
_$dataRekeyFinalizedDataResultEnumSerializer =
    _$DataRekeyFinalizedDataResultEnumSerializer();

class _$DataRekeyFinalizedDataResultEnumSerializer
    implements PrimitiveSerializer<DataRekeyFinalizedDataResultEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'finalized': 'finalized',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'finalized': 'finalized',
  };

  @override
  final Iterable<Type> types = const <Type>[DataRekeyFinalizedDataResultEnum];
  @override
  final String wireName = 'DataRekeyFinalizedDataResultEnum';

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyFinalizedDataResultEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  DataRekeyFinalizedDataResultEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => DataRekeyFinalizedDataResultEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$DataRekeyFinalizedData extends DataRekeyFinalizedData {
  @override
  final DataRekeyFinalizedDataResultEnum result;
  @override
  final int dataGeneration;
  @override
  final int dataKeyEpoch;
  @override
  final int changeWatermark;
  @override
  final DataRekeyCompletionProofData completion;

  factory _$DataRekeyFinalizedData([
    void Function(DataRekeyFinalizedDataBuilder)? updates,
  ]) => (DataRekeyFinalizedDataBuilder()..update(updates))._build();

  _$DataRekeyFinalizedData._({
    required this.result,
    required this.dataGeneration,
    required this.dataKeyEpoch,
    required this.changeWatermark,
    required this.completion,
  }) : super._();
  @override
  DataRekeyFinalizedData rebuild(
    void Function(DataRekeyFinalizedDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeyFinalizedDataBuilder toBuilder() =>
      DataRekeyFinalizedDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeyFinalizedData &&
        result == other.result &&
        dataGeneration == other.dataGeneration &&
        dataKeyEpoch == other.dataKeyEpoch &&
        changeWatermark == other.changeWatermark &&
        completion == other.completion;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, result.hashCode);
    _$hash = $jc(_$hash, dataGeneration.hashCode);
    _$hash = $jc(_$hash, dataKeyEpoch.hashCode);
    _$hash = $jc(_$hash, changeWatermark.hashCode);
    _$hash = $jc(_$hash, completion.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DataRekeyFinalizedData')
          ..add('result', result)
          ..add('dataGeneration', dataGeneration)
          ..add('dataKeyEpoch', dataKeyEpoch)
          ..add('changeWatermark', changeWatermark)
          ..add('completion', completion))
        .toString();
  }
}

class DataRekeyFinalizedDataBuilder
    implements Builder<DataRekeyFinalizedData, DataRekeyFinalizedDataBuilder> {
  _$DataRekeyFinalizedData? _$v;

  DataRekeyFinalizedDataResultEnum? _result;
  DataRekeyFinalizedDataResultEnum? get result => _$this._result;
  set result(DataRekeyFinalizedDataResultEnum? result) =>
      _$this._result = result;

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

  DataRekeyCompletionProofDataBuilder? _completion;
  DataRekeyCompletionProofDataBuilder get completion =>
      _$this._completion ??= DataRekeyCompletionProofDataBuilder();
  set completion(DataRekeyCompletionProofDataBuilder? completion) =>
      _$this._completion = completion;

  DataRekeyFinalizedDataBuilder() {
    DataRekeyFinalizedData._defaults(this);
  }

  DataRekeyFinalizedDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _result = $v.result;
      _dataGeneration = $v.dataGeneration;
      _dataKeyEpoch = $v.dataKeyEpoch;
      _changeWatermark = $v.changeWatermark;
      _completion = $v.completion.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeyFinalizedData other) {
    _$v = other as _$DataRekeyFinalizedData;
  }

  @override
  void update(void Function(DataRekeyFinalizedDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeyFinalizedData build() => _build();

  _$DataRekeyFinalizedData _build() {
    _$DataRekeyFinalizedData _$result;
    try {
      _$result =
          _$v ??
          _$DataRekeyFinalizedData._(
            result: BuiltValueNullFieldError.checkNotNull(
              result,
              r'DataRekeyFinalizedData',
              'result',
            ),
            dataGeneration: BuiltValueNullFieldError.checkNotNull(
              dataGeneration,
              r'DataRekeyFinalizedData',
              'dataGeneration',
            ),
            dataKeyEpoch: BuiltValueNullFieldError.checkNotNull(
              dataKeyEpoch,
              r'DataRekeyFinalizedData',
              'dataKeyEpoch',
            ),
            changeWatermark: BuiltValueNullFieldError.checkNotNull(
              changeWatermark,
              r'DataRekeyFinalizedData',
              'changeWatermark',
            ),
            completion: completion.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'completion';
        completion.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'DataRekeyFinalizedData',
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
