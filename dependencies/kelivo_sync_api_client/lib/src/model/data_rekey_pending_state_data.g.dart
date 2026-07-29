// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_pending_state_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DataRekeyPendingStateDataPhaseEnum
_$dataRekeyPendingStateDataPhaseEnum_rekeyPending =
    const DataRekeyPendingStateDataPhaseEnum._('rekeyPending');

DataRekeyPendingStateDataPhaseEnum _$dataRekeyPendingStateDataPhaseEnumValueOf(
  String name,
) {
  switch (name) {
    case 'rekeyPending':
      return _$dataRekeyPendingStateDataPhaseEnum_rekeyPending;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DataRekeyPendingStateDataPhaseEnum>
_$dataRekeyPendingStateDataPhaseEnumValues =
    BuiltSet<DataRekeyPendingStateDataPhaseEnum>(
      const <DataRekeyPendingStateDataPhaseEnum>[
        _$dataRekeyPendingStateDataPhaseEnum_rekeyPending,
      ],
    );

Serializer<DataRekeyPendingStateDataPhaseEnum>
_$dataRekeyPendingStateDataPhaseEnumSerializer =
    _$DataRekeyPendingStateDataPhaseEnumSerializer();

class _$DataRekeyPendingStateDataPhaseEnumSerializer
    implements PrimitiveSerializer<DataRekeyPendingStateDataPhaseEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'rekeyPending': 'rekey-pending',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'rekey-pending': 'rekeyPending',
  };

  @override
  final Iterable<Type> types = const <Type>[DataRekeyPendingStateDataPhaseEnum];
  @override
  final String wireName = 'DataRekeyPendingStateDataPhaseEnum';

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyPendingStateDataPhaseEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  DataRekeyPendingStateDataPhaseEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => DataRekeyPendingStateDataPhaseEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$DataRekeyPendingStateData extends DataRekeyPendingStateData {
  @override
  final DataRekeyPendingStateDataPhaseEnum phase;
  @override
  final int dataGeneration;
  @override
  final int dataKeyEpoch;
  @override
  final int changeWatermark;
  @override
  final String operationId;
  @override
  final int targetKeyEpoch;
  @override
  final int sourceRecordCount;
  @override
  final int sourceAttachmentCount;
  @override
  final int sourceMaximumChangeSeq;
  @override
  final String? sourceRecordCursorEnd;
  @override
  final DataRekeyCompletionProofDataSourceAttachmentCursorEnd?
  sourceAttachmentCursorEnd;
  @override
  final DataRekeyPendingLeaseData? lease;
  @override
  final DataRekeyCompletionProofData? lastCompletion;
  @override
  final DateTime updatedAt;

  factory _$DataRekeyPendingStateData([
    void Function(DataRekeyPendingStateDataBuilder)? updates,
  ]) => (DataRekeyPendingStateDataBuilder()..update(updates))._build();

  _$DataRekeyPendingStateData._({
    required this.phase,
    required this.dataGeneration,
    required this.dataKeyEpoch,
    required this.changeWatermark,
    required this.operationId,
    required this.targetKeyEpoch,
    required this.sourceRecordCount,
    required this.sourceAttachmentCount,
    required this.sourceMaximumChangeSeq,
    this.sourceRecordCursorEnd,
    this.sourceAttachmentCursorEnd,
    this.lease,
    this.lastCompletion,
    required this.updatedAt,
  }) : super._();
  @override
  DataRekeyPendingStateData rebuild(
    void Function(DataRekeyPendingStateDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeyPendingStateDataBuilder toBuilder() =>
      DataRekeyPendingStateDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeyPendingStateData &&
        phase == other.phase &&
        dataGeneration == other.dataGeneration &&
        dataKeyEpoch == other.dataKeyEpoch &&
        changeWatermark == other.changeWatermark &&
        operationId == other.operationId &&
        targetKeyEpoch == other.targetKeyEpoch &&
        sourceRecordCount == other.sourceRecordCount &&
        sourceAttachmentCount == other.sourceAttachmentCount &&
        sourceMaximumChangeSeq == other.sourceMaximumChangeSeq &&
        sourceRecordCursorEnd == other.sourceRecordCursorEnd &&
        sourceAttachmentCursorEnd == other.sourceAttachmentCursorEnd &&
        lease == other.lease &&
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
    _$hash = $jc(_$hash, operationId.hashCode);
    _$hash = $jc(_$hash, targetKeyEpoch.hashCode);
    _$hash = $jc(_$hash, sourceRecordCount.hashCode);
    _$hash = $jc(_$hash, sourceAttachmentCount.hashCode);
    _$hash = $jc(_$hash, sourceMaximumChangeSeq.hashCode);
    _$hash = $jc(_$hash, sourceRecordCursorEnd.hashCode);
    _$hash = $jc(_$hash, sourceAttachmentCursorEnd.hashCode);
    _$hash = $jc(_$hash, lease.hashCode);
    _$hash = $jc(_$hash, lastCompletion.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DataRekeyPendingStateData')
          ..add('phase', phase)
          ..add('dataGeneration', dataGeneration)
          ..add('dataKeyEpoch', dataKeyEpoch)
          ..add('changeWatermark', changeWatermark)
          ..add('operationId', operationId)
          ..add('targetKeyEpoch', targetKeyEpoch)
          ..add('sourceRecordCount', sourceRecordCount)
          ..add('sourceAttachmentCount', sourceAttachmentCount)
          ..add('sourceMaximumChangeSeq', sourceMaximumChangeSeq)
          ..add('sourceRecordCursorEnd', sourceRecordCursorEnd)
          ..add('sourceAttachmentCursorEnd', sourceAttachmentCursorEnd)
          ..add('lease', lease)
          ..add('lastCompletion', lastCompletion)
          ..add('updatedAt', updatedAt))
        .toString();
  }
}

class DataRekeyPendingStateDataBuilder
    implements
        Builder<DataRekeyPendingStateData, DataRekeyPendingStateDataBuilder> {
  _$DataRekeyPendingStateData? _$v;

  DataRekeyPendingStateDataPhaseEnum? _phase;
  DataRekeyPendingStateDataPhaseEnum? get phase => _$this._phase;
  set phase(DataRekeyPendingStateDataPhaseEnum? phase) => _$this._phase = phase;

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

  String? _operationId;
  String? get operationId => _$this._operationId;
  set operationId(String? operationId) => _$this._operationId = operationId;

  int? _targetKeyEpoch;
  int? get targetKeyEpoch => _$this._targetKeyEpoch;
  set targetKeyEpoch(int? targetKeyEpoch) =>
      _$this._targetKeyEpoch = targetKeyEpoch;

  int? _sourceRecordCount;
  int? get sourceRecordCount => _$this._sourceRecordCount;
  set sourceRecordCount(int? sourceRecordCount) =>
      _$this._sourceRecordCount = sourceRecordCount;

  int? _sourceAttachmentCount;
  int? get sourceAttachmentCount => _$this._sourceAttachmentCount;
  set sourceAttachmentCount(int? sourceAttachmentCount) =>
      _$this._sourceAttachmentCount = sourceAttachmentCount;

  int? _sourceMaximumChangeSeq;
  int? get sourceMaximumChangeSeq => _$this._sourceMaximumChangeSeq;
  set sourceMaximumChangeSeq(int? sourceMaximumChangeSeq) =>
      _$this._sourceMaximumChangeSeq = sourceMaximumChangeSeq;

  String? _sourceRecordCursorEnd;
  String? get sourceRecordCursorEnd => _$this._sourceRecordCursorEnd;
  set sourceRecordCursorEnd(String? sourceRecordCursorEnd) =>
      _$this._sourceRecordCursorEnd = sourceRecordCursorEnd;

  DataRekeyCompletionProofDataSourceAttachmentCursorEndBuilder?
  _sourceAttachmentCursorEnd;
  DataRekeyCompletionProofDataSourceAttachmentCursorEndBuilder
  get sourceAttachmentCursorEnd => _$this._sourceAttachmentCursorEnd ??=
      DataRekeyCompletionProofDataSourceAttachmentCursorEndBuilder();
  set sourceAttachmentCursorEnd(
    DataRekeyCompletionProofDataSourceAttachmentCursorEndBuilder?
    sourceAttachmentCursorEnd,
  ) => _$this._sourceAttachmentCursorEnd = sourceAttachmentCursorEnd;

  DataRekeyPendingLeaseDataBuilder? _lease;
  DataRekeyPendingLeaseDataBuilder get lease =>
      _$this._lease ??= DataRekeyPendingLeaseDataBuilder();
  set lease(DataRekeyPendingLeaseDataBuilder? lease) => _$this._lease = lease;

  DataRekeyCompletionProofDataBuilder? _lastCompletion;
  DataRekeyCompletionProofDataBuilder get lastCompletion =>
      _$this._lastCompletion ??= DataRekeyCompletionProofDataBuilder();
  set lastCompletion(DataRekeyCompletionProofDataBuilder? lastCompletion) =>
      _$this._lastCompletion = lastCompletion;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _$this._updatedAt;
  set updatedAt(DateTime? updatedAt) => _$this._updatedAt = updatedAt;

  DataRekeyPendingStateDataBuilder() {
    DataRekeyPendingStateData._defaults(this);
  }

  DataRekeyPendingStateDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _phase = $v.phase;
      _dataGeneration = $v.dataGeneration;
      _dataKeyEpoch = $v.dataKeyEpoch;
      _changeWatermark = $v.changeWatermark;
      _operationId = $v.operationId;
      _targetKeyEpoch = $v.targetKeyEpoch;
      _sourceRecordCount = $v.sourceRecordCount;
      _sourceAttachmentCount = $v.sourceAttachmentCount;
      _sourceMaximumChangeSeq = $v.sourceMaximumChangeSeq;
      _sourceRecordCursorEnd = $v.sourceRecordCursorEnd;
      _sourceAttachmentCursorEnd = $v.sourceAttachmentCursorEnd?.toBuilder();
      _lease = $v.lease?.toBuilder();
      _lastCompletion = $v.lastCompletion?.toBuilder();
      _updatedAt = $v.updatedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeyPendingStateData other) {
    _$v = other as _$DataRekeyPendingStateData;
  }

  @override
  void update(void Function(DataRekeyPendingStateDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeyPendingStateData build() => _build();

  _$DataRekeyPendingStateData _build() {
    _$DataRekeyPendingStateData _$result;
    try {
      _$result =
          _$v ??
          _$DataRekeyPendingStateData._(
            phase: BuiltValueNullFieldError.checkNotNull(
              phase,
              r'DataRekeyPendingStateData',
              'phase',
            ),
            dataGeneration: BuiltValueNullFieldError.checkNotNull(
              dataGeneration,
              r'DataRekeyPendingStateData',
              'dataGeneration',
            ),
            dataKeyEpoch: BuiltValueNullFieldError.checkNotNull(
              dataKeyEpoch,
              r'DataRekeyPendingStateData',
              'dataKeyEpoch',
            ),
            changeWatermark: BuiltValueNullFieldError.checkNotNull(
              changeWatermark,
              r'DataRekeyPendingStateData',
              'changeWatermark',
            ),
            operationId: BuiltValueNullFieldError.checkNotNull(
              operationId,
              r'DataRekeyPendingStateData',
              'operationId',
            ),
            targetKeyEpoch: BuiltValueNullFieldError.checkNotNull(
              targetKeyEpoch,
              r'DataRekeyPendingStateData',
              'targetKeyEpoch',
            ),
            sourceRecordCount: BuiltValueNullFieldError.checkNotNull(
              sourceRecordCount,
              r'DataRekeyPendingStateData',
              'sourceRecordCount',
            ),
            sourceAttachmentCount: BuiltValueNullFieldError.checkNotNull(
              sourceAttachmentCount,
              r'DataRekeyPendingStateData',
              'sourceAttachmentCount',
            ),
            sourceMaximumChangeSeq: BuiltValueNullFieldError.checkNotNull(
              sourceMaximumChangeSeq,
              r'DataRekeyPendingStateData',
              'sourceMaximumChangeSeq',
            ),
            sourceRecordCursorEnd: sourceRecordCursorEnd,
            sourceAttachmentCursorEnd: _sourceAttachmentCursorEnd?.build(),
            lease: _lease?.build(),
            lastCompletion: _lastCompletion?.build(),
            updatedAt: BuiltValueNullFieldError.checkNotNull(
              updatedAt,
              r'DataRekeyPendingStateData',
              'updatedAt',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'sourceAttachmentCursorEnd';
        _sourceAttachmentCursorEnd?.build();
        _$failedField = 'lease';
        _lease?.build();
        _$failedField = 'lastCompletion';
        _lastCompletion?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'DataRekeyPendingStateData',
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
