// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_finalize_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DataRekeyFinalizeRequest extends DataRekeyFinalizeRequest {
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
  final DataRekeyFinalizeRequestProof proof;

  factory _$DataRekeyFinalizeRequest([
    void Function(DataRekeyFinalizeRequestBuilder)? updates,
  ]) => (DataRekeyFinalizeRequestBuilder()..update(updates))._build();

  _$DataRekeyFinalizeRequest._({
    required this.operationId,
    required this.sourceDataGeneration,
    required this.sourceKeyEpoch,
    required this.targetKeyEpoch,
    required this.leaseToken,
    required this.leaseVersion,
    required this.mutationId,
    required this.proof,
  }) : super._();
  @override
  DataRekeyFinalizeRequest rebuild(
    void Function(DataRekeyFinalizeRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeyFinalizeRequestBuilder toBuilder() =>
      DataRekeyFinalizeRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeyFinalizeRequest &&
        operationId == other.operationId &&
        sourceDataGeneration == other.sourceDataGeneration &&
        sourceKeyEpoch == other.sourceKeyEpoch &&
        targetKeyEpoch == other.targetKeyEpoch &&
        leaseToken == other.leaseToken &&
        leaseVersion == other.leaseVersion &&
        mutationId == other.mutationId &&
        proof == other.proof;
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
    _$hash = $jc(_$hash, proof.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DataRekeyFinalizeRequest')
          ..add('operationId', operationId)
          ..add('sourceDataGeneration', sourceDataGeneration)
          ..add('sourceKeyEpoch', sourceKeyEpoch)
          ..add('targetKeyEpoch', targetKeyEpoch)
          ..add('leaseToken', leaseToken)
          ..add('leaseVersion', leaseVersion)
          ..add('mutationId', mutationId)
          ..add('proof', proof))
        .toString();
  }
}

class DataRekeyFinalizeRequestBuilder
    implements
        Builder<DataRekeyFinalizeRequest, DataRekeyFinalizeRequestBuilder> {
  _$DataRekeyFinalizeRequest? _$v;

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

  DataRekeyFinalizeRequestProofBuilder? _proof;
  DataRekeyFinalizeRequestProofBuilder get proof =>
      _$this._proof ??= DataRekeyFinalizeRequestProofBuilder();
  set proof(DataRekeyFinalizeRequestProofBuilder? proof) =>
      _$this._proof = proof;

  DataRekeyFinalizeRequestBuilder() {
    DataRekeyFinalizeRequest._defaults(this);
  }

  DataRekeyFinalizeRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _operationId = $v.operationId;
      _sourceDataGeneration = $v.sourceDataGeneration;
      _sourceKeyEpoch = $v.sourceKeyEpoch;
      _targetKeyEpoch = $v.targetKeyEpoch;
      _leaseToken = $v.leaseToken;
      _leaseVersion = $v.leaseVersion;
      _mutationId = $v.mutationId;
      _proof = $v.proof.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeyFinalizeRequest other) {
    _$v = other as _$DataRekeyFinalizeRequest;
  }

  @override
  void update(void Function(DataRekeyFinalizeRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeyFinalizeRequest build() => _build();

  _$DataRekeyFinalizeRequest _build() {
    _$DataRekeyFinalizeRequest _$result;
    try {
      _$result =
          _$v ??
          _$DataRekeyFinalizeRequest._(
            operationId: BuiltValueNullFieldError.checkNotNull(
              operationId,
              r'DataRekeyFinalizeRequest',
              'operationId',
            ),
            sourceDataGeneration: BuiltValueNullFieldError.checkNotNull(
              sourceDataGeneration,
              r'DataRekeyFinalizeRequest',
              'sourceDataGeneration',
            ),
            sourceKeyEpoch: BuiltValueNullFieldError.checkNotNull(
              sourceKeyEpoch,
              r'DataRekeyFinalizeRequest',
              'sourceKeyEpoch',
            ),
            targetKeyEpoch: BuiltValueNullFieldError.checkNotNull(
              targetKeyEpoch,
              r'DataRekeyFinalizeRequest',
              'targetKeyEpoch',
            ),
            leaseToken: BuiltValueNullFieldError.checkNotNull(
              leaseToken,
              r'DataRekeyFinalizeRequest',
              'leaseToken',
            ),
            leaseVersion: BuiltValueNullFieldError.checkNotNull(
              leaseVersion,
              r'DataRekeyFinalizeRequest',
              'leaseVersion',
            ),
            mutationId: BuiltValueNullFieldError.checkNotNull(
              mutationId,
              r'DataRekeyFinalizeRequest',
              'mutationId',
            ),
            proof: proof.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'proof';
        proof.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'DataRekeyFinalizeRequest',
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
