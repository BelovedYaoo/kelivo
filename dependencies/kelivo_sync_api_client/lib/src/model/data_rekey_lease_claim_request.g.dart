// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_lease_claim_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DataRekeyLeaseClaimRequest extends DataRekeyLeaseClaimRequest {
  @override
  final String operationId;
  @override
  final int sourceDataGeneration;
  @override
  final int targetKeyEpoch;
  @override
  final String leaseToken;
  @override
  final String mutationId;

  factory _$DataRekeyLeaseClaimRequest([
    void Function(DataRekeyLeaseClaimRequestBuilder)? updates,
  ]) => (DataRekeyLeaseClaimRequestBuilder()..update(updates))._build();

  _$DataRekeyLeaseClaimRequest._({
    required this.operationId,
    required this.sourceDataGeneration,
    required this.targetKeyEpoch,
    required this.leaseToken,
    required this.mutationId,
  }) : super._();
  @override
  DataRekeyLeaseClaimRequest rebuild(
    void Function(DataRekeyLeaseClaimRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeyLeaseClaimRequestBuilder toBuilder() =>
      DataRekeyLeaseClaimRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeyLeaseClaimRequest &&
        operationId == other.operationId &&
        sourceDataGeneration == other.sourceDataGeneration &&
        targetKeyEpoch == other.targetKeyEpoch &&
        leaseToken == other.leaseToken &&
        mutationId == other.mutationId;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, operationId.hashCode);
    _$hash = $jc(_$hash, sourceDataGeneration.hashCode);
    _$hash = $jc(_$hash, targetKeyEpoch.hashCode);
    _$hash = $jc(_$hash, leaseToken.hashCode);
    _$hash = $jc(_$hash, mutationId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DataRekeyLeaseClaimRequest')
          ..add('operationId', operationId)
          ..add('sourceDataGeneration', sourceDataGeneration)
          ..add('targetKeyEpoch', targetKeyEpoch)
          ..add('leaseToken', leaseToken)
          ..add('mutationId', mutationId))
        .toString();
  }
}

class DataRekeyLeaseClaimRequestBuilder
    implements
        Builder<DataRekeyLeaseClaimRequest, DataRekeyLeaseClaimRequestBuilder> {
  _$DataRekeyLeaseClaimRequest? _$v;

  String? _operationId;
  String? get operationId => _$this._operationId;
  set operationId(String? operationId) => _$this._operationId = operationId;

  int? _sourceDataGeneration;
  int? get sourceDataGeneration => _$this._sourceDataGeneration;
  set sourceDataGeneration(int? sourceDataGeneration) =>
      _$this._sourceDataGeneration = sourceDataGeneration;

  int? _targetKeyEpoch;
  int? get targetKeyEpoch => _$this._targetKeyEpoch;
  set targetKeyEpoch(int? targetKeyEpoch) =>
      _$this._targetKeyEpoch = targetKeyEpoch;

  String? _leaseToken;
  String? get leaseToken => _$this._leaseToken;
  set leaseToken(String? leaseToken) => _$this._leaseToken = leaseToken;

  String? _mutationId;
  String? get mutationId => _$this._mutationId;
  set mutationId(String? mutationId) => _$this._mutationId = mutationId;

  DataRekeyLeaseClaimRequestBuilder() {
    DataRekeyLeaseClaimRequest._defaults(this);
  }

  DataRekeyLeaseClaimRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _operationId = $v.operationId;
      _sourceDataGeneration = $v.sourceDataGeneration;
      _targetKeyEpoch = $v.targetKeyEpoch;
      _leaseToken = $v.leaseToken;
      _mutationId = $v.mutationId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeyLeaseClaimRequest other) {
    _$v = other as _$DataRekeyLeaseClaimRequest;
  }

  @override
  void update(void Function(DataRekeyLeaseClaimRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeyLeaseClaimRequest build() => _build();

  _$DataRekeyLeaseClaimRequest _build() {
    final _$result =
        _$v ??
        _$DataRekeyLeaseClaimRequest._(
          operationId: BuiltValueNullFieldError.checkNotNull(
            operationId,
            r'DataRekeyLeaseClaimRequest',
            'operationId',
          ),
          sourceDataGeneration: BuiltValueNullFieldError.checkNotNull(
            sourceDataGeneration,
            r'DataRekeyLeaseClaimRequest',
            'sourceDataGeneration',
          ),
          targetKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            targetKeyEpoch,
            r'DataRekeyLeaseClaimRequest',
            'targetKeyEpoch',
          ),
          leaseToken: BuiltValueNullFieldError.checkNotNull(
            leaseToken,
            r'DataRekeyLeaseClaimRequest',
            'leaseToken',
          ),
          mutationId: BuiltValueNullFieldError.checkNotNull(
            mutationId,
            r'DataRekeyLeaseClaimRequest',
            'mutationId',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
