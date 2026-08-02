// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_verification_pending_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DataRekeyVerificationPendingDataResultEnum
_$dataRekeyVerificationPendingDataResultEnum_verificationPending =
    const DataRekeyVerificationPendingDataResultEnum._('verificationPending');

DataRekeyVerificationPendingDataResultEnum
_$dataRekeyVerificationPendingDataResultEnumValueOf(String name) {
  switch (name) {
    case 'verificationPending':
      return _$dataRekeyVerificationPendingDataResultEnum_verificationPending;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DataRekeyVerificationPendingDataResultEnum>
_$dataRekeyVerificationPendingDataResultEnumValues =
    BuiltSet<DataRekeyVerificationPendingDataResultEnum>(
      const <DataRekeyVerificationPendingDataResultEnum>[
        _$dataRekeyVerificationPendingDataResultEnum_verificationPending,
      ],
    );

const DataRekeyVerificationPendingDataPhaseEnum
_$dataRekeyVerificationPendingDataPhaseEnum_sourceRecords =
    const DataRekeyVerificationPendingDataPhaseEnum._('sourceRecords');
const DataRekeyVerificationPendingDataPhaseEnum
_$dataRekeyVerificationPendingDataPhaseEnum_sourceAttachments =
    const DataRekeyVerificationPendingDataPhaseEnum._('sourceAttachments');
const DataRekeyVerificationPendingDataPhaseEnum
_$dataRekeyVerificationPendingDataPhaseEnum_stagedRecords =
    const DataRekeyVerificationPendingDataPhaseEnum._('stagedRecords');
const DataRekeyVerificationPendingDataPhaseEnum
_$dataRekeyVerificationPendingDataPhaseEnum_stagedAttachments =
    const DataRekeyVerificationPendingDataPhaseEnum._('stagedAttachments');
const DataRekeyVerificationPendingDataPhaseEnum
_$dataRekeyVerificationPendingDataPhaseEnum_verified =
    const DataRekeyVerificationPendingDataPhaseEnum._('verified');

DataRekeyVerificationPendingDataPhaseEnum
_$dataRekeyVerificationPendingDataPhaseEnumValueOf(String name) {
  switch (name) {
    case 'sourceRecords':
      return _$dataRekeyVerificationPendingDataPhaseEnum_sourceRecords;
    case 'sourceAttachments':
      return _$dataRekeyVerificationPendingDataPhaseEnum_sourceAttachments;
    case 'stagedRecords':
      return _$dataRekeyVerificationPendingDataPhaseEnum_stagedRecords;
    case 'stagedAttachments':
      return _$dataRekeyVerificationPendingDataPhaseEnum_stagedAttachments;
    case 'verified':
      return _$dataRekeyVerificationPendingDataPhaseEnum_verified;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DataRekeyVerificationPendingDataPhaseEnum>
_$dataRekeyVerificationPendingDataPhaseEnumValues =
    BuiltSet<DataRekeyVerificationPendingDataPhaseEnum>(
      const <DataRekeyVerificationPendingDataPhaseEnum>[
        _$dataRekeyVerificationPendingDataPhaseEnum_sourceRecords,
        _$dataRekeyVerificationPendingDataPhaseEnum_sourceAttachments,
        _$dataRekeyVerificationPendingDataPhaseEnum_stagedRecords,
        _$dataRekeyVerificationPendingDataPhaseEnum_stagedAttachments,
        _$dataRekeyVerificationPendingDataPhaseEnum_verified,
      ],
    );

Serializer<DataRekeyVerificationPendingDataResultEnum>
_$dataRekeyVerificationPendingDataResultEnumSerializer =
    _$DataRekeyVerificationPendingDataResultEnumSerializer();
Serializer<DataRekeyVerificationPendingDataPhaseEnum>
_$dataRekeyVerificationPendingDataPhaseEnumSerializer =
    _$DataRekeyVerificationPendingDataPhaseEnumSerializer();

class _$DataRekeyVerificationPendingDataResultEnumSerializer
    implements PrimitiveSerializer<DataRekeyVerificationPendingDataResultEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'verificationPending': 'verification-pending',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'verification-pending': 'verificationPending',
  };

  @override
  final Iterable<Type> types = const <Type>[
    DataRekeyVerificationPendingDataResultEnum,
  ];
  @override
  final String wireName = 'DataRekeyVerificationPendingDataResultEnum';

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyVerificationPendingDataResultEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  DataRekeyVerificationPendingDataResultEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => DataRekeyVerificationPendingDataResultEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$DataRekeyVerificationPendingDataPhaseEnumSerializer
    implements PrimitiveSerializer<DataRekeyVerificationPendingDataPhaseEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'sourceRecords': 'source-records',
    'sourceAttachments': 'source-attachments',
    'stagedRecords': 'staged-records',
    'stagedAttachments': 'staged-attachments',
    'verified': 'verified',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'source-records': 'sourceRecords',
    'source-attachments': 'sourceAttachments',
    'staged-records': 'stagedRecords',
    'staged-attachments': 'stagedAttachments',
    'verified': 'verified',
  };

  @override
  final Iterable<Type> types = const <Type>[
    DataRekeyVerificationPendingDataPhaseEnum,
  ];
  @override
  final String wireName = 'DataRekeyVerificationPendingDataPhaseEnum';

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyVerificationPendingDataPhaseEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  DataRekeyVerificationPendingDataPhaseEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => DataRekeyVerificationPendingDataPhaseEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$DataRekeyVerificationPendingData
    extends DataRekeyVerificationPendingData {
  @override
  final DataRekeyVerificationPendingDataResultEnum result;
  @override
  final String operationId;
  @override
  final DataRekeyVerificationPendingDataPhaseEnum phase;
  @override
  final int sourceRecordCount;
  @override
  final int sourceAttachmentCount;
  @override
  final int stagedRecordCount;
  @override
  final int stagedAttachmentCount;

  factory _$DataRekeyVerificationPendingData([
    void Function(DataRekeyVerificationPendingDataBuilder)? updates,
  ]) => (DataRekeyVerificationPendingDataBuilder()..update(updates))._build();

  _$DataRekeyVerificationPendingData._({
    required this.result,
    required this.operationId,
    required this.phase,
    required this.sourceRecordCount,
    required this.sourceAttachmentCount,
    required this.stagedRecordCount,
    required this.stagedAttachmentCount,
  }) : super._();
  @override
  DataRekeyVerificationPendingData rebuild(
    void Function(DataRekeyVerificationPendingDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeyVerificationPendingDataBuilder toBuilder() =>
      DataRekeyVerificationPendingDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeyVerificationPendingData &&
        result == other.result &&
        operationId == other.operationId &&
        phase == other.phase &&
        sourceRecordCount == other.sourceRecordCount &&
        sourceAttachmentCount == other.sourceAttachmentCount &&
        stagedRecordCount == other.stagedRecordCount &&
        stagedAttachmentCount == other.stagedAttachmentCount;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, result.hashCode);
    _$hash = $jc(_$hash, operationId.hashCode);
    _$hash = $jc(_$hash, phase.hashCode);
    _$hash = $jc(_$hash, sourceRecordCount.hashCode);
    _$hash = $jc(_$hash, sourceAttachmentCount.hashCode);
    _$hash = $jc(_$hash, stagedRecordCount.hashCode);
    _$hash = $jc(_$hash, stagedAttachmentCount.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DataRekeyVerificationPendingData')
          ..add('result', result)
          ..add('operationId', operationId)
          ..add('phase', phase)
          ..add('sourceRecordCount', sourceRecordCount)
          ..add('sourceAttachmentCount', sourceAttachmentCount)
          ..add('stagedRecordCount', stagedRecordCount)
          ..add('stagedAttachmentCount', stagedAttachmentCount))
        .toString();
  }
}

class DataRekeyVerificationPendingDataBuilder
    implements
        Builder<
          DataRekeyVerificationPendingData,
          DataRekeyVerificationPendingDataBuilder
        > {
  _$DataRekeyVerificationPendingData? _$v;

  DataRekeyVerificationPendingDataResultEnum? _result;
  DataRekeyVerificationPendingDataResultEnum? get result => _$this._result;
  set result(DataRekeyVerificationPendingDataResultEnum? result) =>
      _$this._result = result;

  String? _operationId;
  String? get operationId => _$this._operationId;
  set operationId(String? operationId) => _$this._operationId = operationId;

  DataRekeyVerificationPendingDataPhaseEnum? _phase;
  DataRekeyVerificationPendingDataPhaseEnum? get phase => _$this._phase;
  set phase(DataRekeyVerificationPendingDataPhaseEnum? phase) =>
      _$this._phase = phase;

  int? _sourceRecordCount;
  int? get sourceRecordCount => _$this._sourceRecordCount;
  set sourceRecordCount(int? sourceRecordCount) =>
      _$this._sourceRecordCount = sourceRecordCount;

  int? _sourceAttachmentCount;
  int? get sourceAttachmentCount => _$this._sourceAttachmentCount;
  set sourceAttachmentCount(int? sourceAttachmentCount) =>
      _$this._sourceAttachmentCount = sourceAttachmentCount;

  int? _stagedRecordCount;
  int? get stagedRecordCount => _$this._stagedRecordCount;
  set stagedRecordCount(int? stagedRecordCount) =>
      _$this._stagedRecordCount = stagedRecordCount;

  int? _stagedAttachmentCount;
  int? get stagedAttachmentCount => _$this._stagedAttachmentCount;
  set stagedAttachmentCount(int? stagedAttachmentCount) =>
      _$this._stagedAttachmentCount = stagedAttachmentCount;

  DataRekeyVerificationPendingDataBuilder() {
    DataRekeyVerificationPendingData._defaults(this);
  }

  DataRekeyVerificationPendingDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _result = $v.result;
      _operationId = $v.operationId;
      _phase = $v.phase;
      _sourceRecordCount = $v.sourceRecordCount;
      _sourceAttachmentCount = $v.sourceAttachmentCount;
      _stagedRecordCount = $v.stagedRecordCount;
      _stagedAttachmentCount = $v.stagedAttachmentCount;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeyVerificationPendingData other) {
    _$v = other as _$DataRekeyVerificationPendingData;
  }

  @override
  void update(void Function(DataRekeyVerificationPendingDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeyVerificationPendingData build() => _build();

  _$DataRekeyVerificationPendingData _build() {
    final _$result =
        _$v ??
        _$DataRekeyVerificationPendingData._(
          result: BuiltValueNullFieldError.checkNotNull(
            result,
            r'DataRekeyVerificationPendingData',
            'result',
          ),
          operationId: BuiltValueNullFieldError.checkNotNull(
            operationId,
            r'DataRekeyVerificationPendingData',
            'operationId',
          ),
          phase: BuiltValueNullFieldError.checkNotNull(
            phase,
            r'DataRekeyVerificationPendingData',
            'phase',
          ),
          sourceRecordCount: BuiltValueNullFieldError.checkNotNull(
            sourceRecordCount,
            r'DataRekeyVerificationPendingData',
            'sourceRecordCount',
          ),
          sourceAttachmentCount: BuiltValueNullFieldError.checkNotNull(
            sourceAttachmentCount,
            r'DataRekeyVerificationPendingData',
            'sourceAttachmentCount',
          ),
          stagedRecordCount: BuiltValueNullFieldError.checkNotNull(
            stagedRecordCount,
            r'DataRekeyVerificationPendingData',
            'stagedRecordCount',
          ),
          stagedAttachmentCount: BuiltValueNullFieldError.checkNotNull(
            stagedAttachmentCount,
            r'DataRekeyVerificationPendingData',
            'stagedAttachmentCount',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
