// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_record_stage_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DataRekeyRecordStageRequest extends DataRekeyRecordStageRequest {
  @override
  final String operationId;
  @override
  final int sourceDataGeneration;
  @override
  final int sourceKeyEpoch;
  @override
  final int targetKeyEpoch;
  @override
  final String leaseToken;
  @override
  final int leaseVersion;
  @override
  final String mutationId;
  @override
  final String sourceRecordId;
  @override
  final String targetRecordId;
  @override
  final int sourceRevision;
  @override
  final int envelopeVersion;
  @override
  final String ciphertext;

  factory _$DataRekeyRecordStageRequest([
    void Function(DataRekeyRecordStageRequestBuilder)? updates,
  ]) => (DataRekeyRecordStageRequestBuilder()..update(updates))._build();

  _$DataRekeyRecordStageRequest._({
    required this.operationId,
    required this.sourceDataGeneration,
    required this.sourceKeyEpoch,
    required this.targetKeyEpoch,
    required this.leaseToken,
    required this.leaseVersion,
    required this.mutationId,
    required this.sourceRecordId,
    required this.targetRecordId,
    required this.sourceRevision,
    required this.envelopeVersion,
    required this.ciphertext,
  }) : super._();
  @override
  DataRekeyRecordStageRequest rebuild(
    void Function(DataRekeyRecordStageRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeyRecordStageRequestBuilder toBuilder() =>
      DataRekeyRecordStageRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeyRecordStageRequest &&
        operationId == other.operationId &&
        sourceDataGeneration == other.sourceDataGeneration &&
        sourceKeyEpoch == other.sourceKeyEpoch &&
        targetKeyEpoch == other.targetKeyEpoch &&
        leaseToken == other.leaseToken &&
        leaseVersion == other.leaseVersion &&
        mutationId == other.mutationId &&
        sourceRecordId == other.sourceRecordId &&
        targetRecordId == other.targetRecordId &&
        sourceRevision == other.sourceRevision &&
        envelopeVersion == other.envelopeVersion &&
        ciphertext == other.ciphertext;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, operationId.hashCode);
    _$hash = $jc(_$hash, sourceDataGeneration.hashCode);
    _$hash = $jc(_$hash, sourceKeyEpoch.hashCode);
    _$hash = $jc(_$hash, targetKeyEpoch.hashCode);
    _$hash = $jc(_$hash, leaseToken.hashCode);
    _$hash = $jc(_$hash, leaseVersion.hashCode);
    _$hash = $jc(_$hash, mutationId.hashCode);
    _$hash = $jc(_$hash, sourceRecordId.hashCode);
    _$hash = $jc(_$hash, targetRecordId.hashCode);
    _$hash = $jc(_$hash, sourceRevision.hashCode);
    _$hash = $jc(_$hash, envelopeVersion.hashCode);
    _$hash = $jc(_$hash, ciphertext.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DataRekeyRecordStageRequest')
          ..add('operationId', operationId)
          ..add('sourceDataGeneration', sourceDataGeneration)
          ..add('sourceKeyEpoch', sourceKeyEpoch)
          ..add('targetKeyEpoch', targetKeyEpoch)
          ..add('leaseToken', leaseToken)
          ..add('leaseVersion', leaseVersion)
          ..add('mutationId', mutationId)
          ..add('sourceRecordId', sourceRecordId)
          ..add('targetRecordId', targetRecordId)
          ..add('sourceRevision', sourceRevision)
          ..add('envelopeVersion', envelopeVersion)
          ..add('ciphertext', ciphertext))
        .toString();
  }
}

class DataRekeyRecordStageRequestBuilder
    implements
        Builder<
          DataRekeyRecordStageRequest,
          DataRekeyRecordStageRequestBuilder
        > {
  _$DataRekeyRecordStageRequest? _$v;

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

  String? _leaseToken;
  String? get leaseToken => _$this._leaseToken;
  set leaseToken(String? leaseToken) => _$this._leaseToken = leaseToken;

  int? _leaseVersion;
  int? get leaseVersion => _$this._leaseVersion;
  set leaseVersion(int? leaseVersion) => _$this._leaseVersion = leaseVersion;

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

  int? _sourceRevision;
  int? get sourceRevision => _$this._sourceRevision;
  set sourceRevision(int? sourceRevision) =>
      _$this._sourceRevision = sourceRevision;

  int? _envelopeVersion;
  int? get envelopeVersion => _$this._envelopeVersion;
  set envelopeVersion(int? envelopeVersion) =>
      _$this._envelopeVersion = envelopeVersion;

  String? _ciphertext;
  String? get ciphertext => _$this._ciphertext;
  set ciphertext(String? ciphertext) => _$this._ciphertext = ciphertext;

  DataRekeyRecordStageRequestBuilder() {
    DataRekeyRecordStageRequest._defaults(this);
  }

  DataRekeyRecordStageRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _operationId = $v.operationId;
      _sourceDataGeneration = $v.sourceDataGeneration;
      _sourceKeyEpoch = $v.sourceKeyEpoch;
      _targetKeyEpoch = $v.targetKeyEpoch;
      _leaseToken = $v.leaseToken;
      _leaseVersion = $v.leaseVersion;
      _mutationId = $v.mutationId;
      _sourceRecordId = $v.sourceRecordId;
      _targetRecordId = $v.targetRecordId;
      _sourceRevision = $v.sourceRevision;
      _envelopeVersion = $v.envelopeVersion;
      _ciphertext = $v.ciphertext;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeyRecordStageRequest other) {
    _$v = other as _$DataRekeyRecordStageRequest;
  }

  @override
  void update(void Function(DataRekeyRecordStageRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeyRecordStageRequest build() => _build();

  _$DataRekeyRecordStageRequest _build() {
    final _$result =
        _$v ??
        _$DataRekeyRecordStageRequest._(
          operationId: BuiltValueNullFieldError.checkNotNull(
            operationId,
            r'DataRekeyRecordStageRequest',
            'operationId',
          ),
          sourceDataGeneration: BuiltValueNullFieldError.checkNotNull(
            sourceDataGeneration,
            r'DataRekeyRecordStageRequest',
            'sourceDataGeneration',
          ),
          sourceKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            sourceKeyEpoch,
            r'DataRekeyRecordStageRequest',
            'sourceKeyEpoch',
          ),
          targetKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            targetKeyEpoch,
            r'DataRekeyRecordStageRequest',
            'targetKeyEpoch',
          ),
          leaseToken: BuiltValueNullFieldError.checkNotNull(
            leaseToken,
            r'DataRekeyRecordStageRequest',
            'leaseToken',
          ),
          leaseVersion: BuiltValueNullFieldError.checkNotNull(
            leaseVersion,
            r'DataRekeyRecordStageRequest',
            'leaseVersion',
          ),
          mutationId: BuiltValueNullFieldError.checkNotNull(
            mutationId,
            r'DataRekeyRecordStageRequest',
            'mutationId',
          ),
          sourceRecordId: BuiltValueNullFieldError.checkNotNull(
            sourceRecordId,
            r'DataRekeyRecordStageRequest',
            'sourceRecordId',
          ),
          targetRecordId: BuiltValueNullFieldError.checkNotNull(
            targetRecordId,
            r'DataRekeyRecordStageRequest',
            'targetRecordId',
          ),
          sourceRevision: BuiltValueNullFieldError.checkNotNull(
            sourceRevision,
            r'DataRekeyRecordStageRequest',
            'sourceRevision',
          ),
          envelopeVersion: BuiltValueNullFieldError.checkNotNull(
            envelopeVersion,
            r'DataRekeyRecordStageRequest',
            'envelopeVersion',
          ),
          ciphertext: BuiltValueNullFieldError.checkNotNull(
            ciphertext,
            r'DataRekeyRecordStageRequest',
            'ciphertext',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
