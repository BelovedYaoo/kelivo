// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_finalize_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DataRekeyFinalizeDataResultEnum
_$dataRekeyFinalizeDataResultEnum_finalized =
    const DataRekeyFinalizeDataResultEnum._('finalized');

DataRekeyFinalizeDataResultEnum _$dataRekeyFinalizeDataResultEnumValueOf(
  String name,
) {
  switch (name) {
    case 'finalized':
      return _$dataRekeyFinalizeDataResultEnum_finalized;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DataRekeyFinalizeDataResultEnum>
_$dataRekeyFinalizeDataResultEnumValues =
    BuiltSet<DataRekeyFinalizeDataResultEnum>(
      const <DataRekeyFinalizeDataResultEnum>[
        _$dataRekeyFinalizeDataResultEnum_finalized,
      ],
    );

Serializer<DataRekeyFinalizeDataResultEnum>
_$dataRekeyFinalizeDataResultEnumSerializer =
    _$DataRekeyFinalizeDataResultEnumSerializer();

class _$DataRekeyFinalizeDataResultEnumSerializer
    implements PrimitiveSerializer<DataRekeyFinalizeDataResultEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'finalized': 'finalized',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'finalized': 'finalized',
  };

  @override
  final Iterable<Type> types = const <Type>[DataRekeyFinalizeDataResultEnum];
  @override
  final String wireName = 'DataRekeyFinalizeDataResultEnum';

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyFinalizeDataResultEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  DataRekeyFinalizeDataResultEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => DataRekeyFinalizeDataResultEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$DataRekeyFinalizeData extends DataRekeyFinalizeData {
  @override
  final DataRekeyFinalizeDataResultEnum result;
  @override
  final int dataGeneration;
  @override
  final int dataKeyEpoch;
  @override
  final int changeWatermark;
  @override
  final DataRekeyCompletionProofData? completion;

  factory _$DataRekeyFinalizeData([
    void Function(DataRekeyFinalizeDataBuilder)? updates,
  ]) => (DataRekeyFinalizeDataBuilder()..update(updates))._build();

  _$DataRekeyFinalizeData._({
    required this.result,
    required this.dataGeneration,
    required this.dataKeyEpoch,
    required this.changeWatermark,
    this.completion,
  }) : super._();
  @override
  DataRekeyFinalizeData rebuild(
    void Function(DataRekeyFinalizeDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeyFinalizeDataBuilder toBuilder() =>
      DataRekeyFinalizeDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeyFinalizeData &&
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
    return (newBuiltValueToStringHelper(r'DataRekeyFinalizeData')
          ..add('result', result)
          ..add('dataGeneration', dataGeneration)
          ..add('dataKeyEpoch', dataKeyEpoch)
          ..add('changeWatermark', changeWatermark)
          ..add('completion', completion))
        .toString();
  }
}

class DataRekeyFinalizeDataBuilder
    implements Builder<DataRekeyFinalizeData, DataRekeyFinalizeDataBuilder> {
  _$DataRekeyFinalizeData? _$v;

  DataRekeyFinalizeDataResultEnum? _result;
  DataRekeyFinalizeDataResultEnum? get result => _$this._result;
  set result(DataRekeyFinalizeDataResultEnum? result) =>
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

  DataRekeyFinalizeDataBuilder() {
    DataRekeyFinalizeData._defaults(this);
  }

  DataRekeyFinalizeDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _result = $v.result;
      _dataGeneration = $v.dataGeneration;
      _dataKeyEpoch = $v.dataKeyEpoch;
      _changeWatermark = $v.changeWatermark;
      _completion = $v.completion?.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeyFinalizeData other) {
    _$v = other as _$DataRekeyFinalizeData;
  }

  @override
  void update(void Function(DataRekeyFinalizeDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeyFinalizeData build() => _build();

  _$DataRekeyFinalizeData _build() {
    _$DataRekeyFinalizeData _$result;
    try {
      _$result =
          _$v ??
          _$DataRekeyFinalizeData._(
            result: BuiltValueNullFieldError.checkNotNull(
              result,
              r'DataRekeyFinalizeData',
              'result',
            ),
            dataGeneration: BuiltValueNullFieldError.checkNotNull(
              dataGeneration,
              r'DataRekeyFinalizeData',
              'dataGeneration',
            ),
            dataKeyEpoch: BuiltValueNullFieldError.checkNotNull(
              dataKeyEpoch,
              r'DataRekeyFinalizeData',
              'dataKeyEpoch',
            ),
            changeWatermark: BuiltValueNullFieldError.checkNotNull(
              changeWatermark,
              r'DataRekeyFinalizeData',
              'changeWatermark',
            ),
            completion: _completion?.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'completion';
        _completion?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'DataRekeyFinalizeData',
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
