// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_record_stage_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DataRekeyRecordStageDataResultEnum
_$dataRekeyRecordStageDataResultEnum_staged =
    const DataRekeyRecordStageDataResultEnum._('staged');

DataRekeyRecordStageDataResultEnum _$dataRekeyRecordStageDataResultEnumValueOf(
  String name,
) {
  switch (name) {
    case 'staged':
      return _$dataRekeyRecordStageDataResultEnum_staged;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DataRekeyRecordStageDataResultEnum>
_$dataRekeyRecordStageDataResultEnumValues =
    BuiltSet<DataRekeyRecordStageDataResultEnum>(
      const <DataRekeyRecordStageDataResultEnum>[
        _$dataRekeyRecordStageDataResultEnum_staged,
      ],
    );

Serializer<DataRekeyRecordStageDataResultEnum>
_$dataRekeyRecordStageDataResultEnumSerializer =
    _$DataRekeyRecordStageDataResultEnumSerializer();

class _$DataRekeyRecordStageDataResultEnumSerializer
    implements PrimitiveSerializer<DataRekeyRecordStageDataResultEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'staged': 'staged',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'staged': 'staged',
  };

  @override
  final Iterable<Type> types = const <Type>[DataRekeyRecordStageDataResultEnum];
  @override
  final String wireName = 'DataRekeyRecordStageDataResultEnum';

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyRecordStageDataResultEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  DataRekeyRecordStageDataResultEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => DataRekeyRecordStageDataResultEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$DataRekeyRecordStageData extends DataRekeyRecordStageData {
  @override
  final DataRekeyRecordStageDataResultEnum result;
  @override
  final String operationId;
  @override
  final String mutationId;
  @override
  final String sourceRecordId;
  @override
  final String targetRecordId;
  @override
  final int leaseVersion;

  factory _$DataRekeyRecordStageData([
    void Function(DataRekeyRecordStageDataBuilder)? updates,
  ]) => (DataRekeyRecordStageDataBuilder()..update(updates))._build();

  _$DataRekeyRecordStageData._({
    required this.result,
    required this.operationId,
    required this.mutationId,
    required this.sourceRecordId,
    required this.targetRecordId,
    required this.leaseVersion,
  }) : super._();
  @override
  DataRekeyRecordStageData rebuild(
    void Function(DataRekeyRecordStageDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeyRecordStageDataBuilder toBuilder() =>
      DataRekeyRecordStageDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeyRecordStageData &&
        result == other.result &&
        operationId == other.operationId &&
        mutationId == other.mutationId &&
        sourceRecordId == other.sourceRecordId &&
        targetRecordId == other.targetRecordId &&
        leaseVersion == other.leaseVersion;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, result.hashCode);
    _$hash = $jc(_$hash, operationId.hashCode);
    _$hash = $jc(_$hash, mutationId.hashCode);
    _$hash = $jc(_$hash, sourceRecordId.hashCode);
    _$hash = $jc(_$hash, targetRecordId.hashCode);
    _$hash = $jc(_$hash, leaseVersion.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DataRekeyRecordStageData')
          ..add('result', result)
          ..add('operationId', operationId)
          ..add('mutationId', mutationId)
          ..add('sourceRecordId', sourceRecordId)
          ..add('targetRecordId', targetRecordId)
          ..add('leaseVersion', leaseVersion))
        .toString();
  }
}

class DataRekeyRecordStageDataBuilder
    implements
        Builder<DataRekeyRecordStageData, DataRekeyRecordStageDataBuilder> {
  _$DataRekeyRecordStageData? _$v;

  DataRekeyRecordStageDataResultEnum? _result;
  DataRekeyRecordStageDataResultEnum? get result => _$this._result;
  set result(DataRekeyRecordStageDataResultEnum? result) =>
      _$this._result = result;

  String? _operationId;
  String? get operationId => _$this._operationId;
  set operationId(String? operationId) => _$this._operationId = operationId;

  String? _mutationId;
  String? get mutationId => _$this._mutationId;
  set mutationId(String? mutationId) => _$this._mutationId = mutationId;

  String? _sourceRecordId;
  String? get sourceRecordId => _$this._sourceRecordId;
  set sourceRecordId(String? sourceRecordId) =>
      _$this._sourceRecordId = sourceRecordId;

  String? _targetRecordId;
  String? get targetRecordId => _$this._targetRecordId;
  set targetRecordId(String? targetRecordId) =>
      _$this._targetRecordId = targetRecordId;

  int? _leaseVersion;
  int? get leaseVersion => _$this._leaseVersion;
  set leaseVersion(int? leaseVersion) => _$this._leaseVersion = leaseVersion;

  DataRekeyRecordStageDataBuilder() {
    DataRekeyRecordStageData._defaults(this);
  }

  DataRekeyRecordStageDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _result = $v.result;
      _operationId = $v.operationId;
      _mutationId = $v.mutationId;
      _sourceRecordId = $v.sourceRecordId;
      _targetRecordId = $v.targetRecordId;
      _leaseVersion = $v.leaseVersion;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeyRecordStageData other) {
    _$v = other as _$DataRekeyRecordStageData;
  }

  @override
  void update(void Function(DataRekeyRecordStageDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeyRecordStageData build() => _build();

  _$DataRekeyRecordStageData _build() {
    final _$result =
        _$v ??
        _$DataRekeyRecordStageData._(
          result: BuiltValueNullFieldError.checkNotNull(
            result,
            r'DataRekeyRecordStageData',
            'result',
          ),
          operationId: BuiltValueNullFieldError.checkNotNull(
            operationId,
            r'DataRekeyRecordStageData',
            'operationId',
          ),
          mutationId: BuiltValueNullFieldError.checkNotNull(
            mutationId,
            r'DataRekeyRecordStageData',
            'mutationId',
          ),
          sourceRecordId: BuiltValueNullFieldError.checkNotNull(
            sourceRecordId,
            r'DataRekeyRecordStageData',
            'sourceRecordId',
          ),
          targetRecordId: BuiltValueNullFieldError.checkNotNull(
            targetRecordId,
            r'DataRekeyRecordStageData',
            'targetRecordId',
          ),
          leaseVersion: BuiltValueNullFieldError.checkNotNull(
            leaseVersion,
            r'DataRekeyRecordStageData',
            'leaseVersion',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
