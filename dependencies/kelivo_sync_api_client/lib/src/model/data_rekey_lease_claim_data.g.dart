// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_lease_claim_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DataRekeyLeaseClaimDataPhaseEnum
_$dataRekeyLeaseClaimDataPhaseEnum_rekeyPending =
    const DataRekeyLeaseClaimDataPhaseEnum._('rekeyPending');

DataRekeyLeaseClaimDataPhaseEnum _$dataRekeyLeaseClaimDataPhaseEnumValueOf(
  String name,
) {
  switch (name) {
    case 'rekeyPending':
      return _$dataRekeyLeaseClaimDataPhaseEnum_rekeyPending;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DataRekeyLeaseClaimDataPhaseEnum>
_$dataRekeyLeaseClaimDataPhaseEnumValues =
    BuiltSet<DataRekeyLeaseClaimDataPhaseEnum>(
      const <DataRekeyLeaseClaimDataPhaseEnum>[
        _$dataRekeyLeaseClaimDataPhaseEnum_rekeyPending,
      ],
    );

Serializer<DataRekeyLeaseClaimDataPhaseEnum>
_$dataRekeyLeaseClaimDataPhaseEnumSerializer =
    _$DataRekeyLeaseClaimDataPhaseEnumSerializer();

class _$DataRekeyLeaseClaimDataPhaseEnumSerializer
    implements PrimitiveSerializer<DataRekeyLeaseClaimDataPhaseEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'rekeyPending': 'rekey-pending',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'rekey-pending': 'rekeyPending',
  };

  @override
  final Iterable<Type> types = const <Type>[DataRekeyLeaseClaimDataPhaseEnum];
  @override
  final String wireName = 'DataRekeyLeaseClaimDataPhaseEnum';

  @override
  Object serialize(
    Serializers serializers,
    DataRekeyLeaseClaimDataPhaseEnum object, {
    FullType specifiedType = FullType.unspecified,
  }) => _toWire[object.name] ?? object.name;

  @override
  DataRekeyLeaseClaimDataPhaseEnum deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => DataRekeyLeaseClaimDataPhaseEnum.valueOf(
    _fromWire[serialized] ?? (serialized is String ? serialized : ''),
  );
}

class _$DataRekeyLeaseClaimData extends DataRekeyLeaseClaimData {
  @override
  final DataRekeyLeaseClaimDataPhaseEnum phase;
  @override
  final String operationId;
  @override
  final int sourceDataGeneration;
  @override
  final int sourceKeyEpoch;
  @override
  final int targetKeyEpoch;
  @override
  final int leaseVersion;
  @override
  final DateTime leaseExpiresAt;
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

  factory _$DataRekeyLeaseClaimData([
    void Function(DataRekeyLeaseClaimDataBuilder)? updates,
  ]) => (DataRekeyLeaseClaimDataBuilder()..update(updates))._build();

  _$DataRekeyLeaseClaimData._({
    required this.phase,
    required this.operationId,
    required this.sourceDataGeneration,
    required this.sourceKeyEpoch,
    required this.targetKeyEpoch,
    required this.leaseVersion,
    required this.leaseExpiresAt,
    required this.sourceRecordCount,
    required this.sourceAttachmentCount,
    required this.sourceMaximumChangeSeq,
    this.sourceRecordCursorEnd,
    this.sourceAttachmentCursorEnd,
  }) : super._();
  @override
  DataRekeyLeaseClaimData rebuild(
    void Function(DataRekeyLeaseClaimDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeyLeaseClaimDataBuilder toBuilder() =>
      DataRekeyLeaseClaimDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeyLeaseClaimData &&
        phase == other.phase &&
        operationId == other.operationId &&
        sourceDataGeneration == other.sourceDataGeneration &&
        sourceKeyEpoch == other.sourceKeyEpoch &&
        targetKeyEpoch == other.targetKeyEpoch &&
        leaseVersion == other.leaseVersion &&
        leaseExpiresAt == other.leaseExpiresAt &&
        sourceRecordCount == other.sourceRecordCount &&
        sourceAttachmentCount == other.sourceAttachmentCount &&
        sourceMaximumChangeSeq == other.sourceMaximumChangeSeq &&
        sourceRecordCursorEnd == other.sourceRecordCursorEnd &&
        sourceAttachmentCursorEnd == other.sourceAttachmentCursorEnd;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, phase.hashCode);
    _$hash = $jc(_$hash, operationId.hashCode);
    _$hash = $jc(_$hash, sourceDataGeneration.hashCode);
    _$hash = $jc(_$hash, sourceKeyEpoch.hashCode);
    _$hash = $jc(_$hash, targetKeyEpoch.hashCode);
    _$hash = $jc(_$hash, leaseVersion.hashCode);
    _$hash = $jc(_$hash, leaseExpiresAt.hashCode);
    _$hash = $jc(_$hash, sourceRecordCount.hashCode);
    _$hash = $jc(_$hash, sourceAttachmentCount.hashCode);
    _$hash = $jc(_$hash, sourceMaximumChangeSeq.hashCode);
    _$hash = $jc(_$hash, sourceRecordCursorEnd.hashCode);
    _$hash = $jc(_$hash, sourceAttachmentCursorEnd.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DataRekeyLeaseClaimData')
          ..add('phase', phase)
          ..add('operationId', operationId)
          ..add('sourceDataGeneration', sourceDataGeneration)
          ..add('sourceKeyEpoch', sourceKeyEpoch)
          ..add('targetKeyEpoch', targetKeyEpoch)
          ..add('leaseVersion', leaseVersion)
          ..add('leaseExpiresAt', leaseExpiresAt)
          ..add('sourceRecordCount', sourceRecordCount)
          ..add('sourceAttachmentCount', sourceAttachmentCount)
          ..add('sourceMaximumChangeSeq', sourceMaximumChangeSeq)
          ..add('sourceRecordCursorEnd', sourceRecordCursorEnd)
          ..add('sourceAttachmentCursorEnd', sourceAttachmentCursorEnd))
        .toString();
  }
}

class DataRekeyLeaseClaimDataBuilder
    implements
        Builder<DataRekeyLeaseClaimData, DataRekeyLeaseClaimDataBuilder> {
  _$DataRekeyLeaseClaimData? _$v;

  DataRekeyLeaseClaimDataPhaseEnum? _phase;
  DataRekeyLeaseClaimDataPhaseEnum? get phase => _$this._phase;
  set phase(DataRekeyLeaseClaimDataPhaseEnum? phase) => _$this._phase = phase;

  String? _operationId;
  String? get operationId => _$this._operationId;
  set operationId(String? operationId) => _$this._operationId = operationId;

  int? _sourceDataGeneration;
  int? get sourceDataGeneration => _$this._sourceDataGeneration;
  set sourceDataGeneration(int? sourceDataGeneration) =>
      _$this._sourceDataGeneration = sourceDataGeneration;

  int? _sourceKeyEpoch;
  int? get sourceKeyEpoch => _$this._sourceKeyEpoch;
  set sourceKeyEpoch(int? sourceKeyEpoch) =>
      _$this._sourceKeyEpoch = sourceKeyEpoch;

  int? _targetKeyEpoch;
  int? get targetKeyEpoch => _$this._targetKeyEpoch;
  set targetKeyEpoch(int? targetKeyEpoch) =>
      _$this._targetKeyEpoch = targetKeyEpoch;

  int? _leaseVersion;
  int? get leaseVersion => _$this._leaseVersion;
  set leaseVersion(int? leaseVersion) => _$this._leaseVersion = leaseVersion;

  DateTime? _leaseExpiresAt;
  DateTime? get leaseExpiresAt => _$this._leaseExpiresAt;
  set leaseExpiresAt(DateTime? leaseExpiresAt) =>
      _$this._leaseExpiresAt = leaseExpiresAt;

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

  DataRekeyLeaseClaimDataBuilder() {
    DataRekeyLeaseClaimData._defaults(this);
  }

  DataRekeyLeaseClaimDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _phase = $v.phase;
      _operationId = $v.operationId;
      _sourceDataGeneration = $v.sourceDataGeneration;
      _sourceKeyEpoch = $v.sourceKeyEpoch;
      _targetKeyEpoch = $v.targetKeyEpoch;
      _leaseVersion = $v.leaseVersion;
      _leaseExpiresAt = $v.leaseExpiresAt;
      _sourceRecordCount = $v.sourceRecordCount;
      _sourceAttachmentCount = $v.sourceAttachmentCount;
      _sourceMaximumChangeSeq = $v.sourceMaximumChangeSeq;
      _sourceRecordCursorEnd = $v.sourceRecordCursorEnd;
      _sourceAttachmentCursorEnd = $v.sourceAttachmentCursorEnd?.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeyLeaseClaimData other) {
    _$v = other as _$DataRekeyLeaseClaimData;
  }

  @override
  void update(void Function(DataRekeyLeaseClaimDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeyLeaseClaimData build() => _build();

  _$DataRekeyLeaseClaimData _build() {
    _$DataRekeyLeaseClaimData _$result;
    try {
      _$result =
          _$v ??
          _$DataRekeyLeaseClaimData._(
            phase: BuiltValueNullFieldError.checkNotNull(
              phase,
              r'DataRekeyLeaseClaimData',
              'phase',
            ),
            operationId: BuiltValueNullFieldError.checkNotNull(
              operationId,
              r'DataRekeyLeaseClaimData',
              'operationId',
            ),
            sourceDataGeneration: BuiltValueNullFieldError.checkNotNull(
              sourceDataGeneration,
              r'DataRekeyLeaseClaimData',
              'sourceDataGeneration',
            ),
            sourceKeyEpoch: BuiltValueNullFieldError.checkNotNull(
              sourceKeyEpoch,
              r'DataRekeyLeaseClaimData',
              'sourceKeyEpoch',
            ),
            targetKeyEpoch: BuiltValueNullFieldError.checkNotNull(
              targetKeyEpoch,
              r'DataRekeyLeaseClaimData',
              'targetKeyEpoch',
            ),
            leaseVersion: BuiltValueNullFieldError.checkNotNull(
              leaseVersion,
              r'DataRekeyLeaseClaimData',
              'leaseVersion',
            ),
            leaseExpiresAt: BuiltValueNullFieldError.checkNotNull(
              leaseExpiresAt,
              r'DataRekeyLeaseClaimData',
              'leaseExpiresAt',
            ),
            sourceRecordCount: BuiltValueNullFieldError.checkNotNull(
              sourceRecordCount,
              r'DataRekeyLeaseClaimData',
              'sourceRecordCount',
            ),
            sourceAttachmentCount: BuiltValueNullFieldError.checkNotNull(
              sourceAttachmentCount,
              r'DataRekeyLeaseClaimData',
              'sourceAttachmentCount',
            ),
            sourceMaximumChangeSeq: BuiltValueNullFieldError.checkNotNull(
              sourceMaximumChangeSeq,
              r'DataRekeyLeaseClaimData',
              'sourceMaximumChangeSeq',
            ),
            sourceRecordCursorEnd: sourceRecordCursorEnd,
            sourceAttachmentCursorEnd: _sourceAttachmentCursorEnd?.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'sourceAttachmentCursorEnd';
        _sourceAttachmentCursorEnd?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'DataRekeyLeaseClaimData',
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
