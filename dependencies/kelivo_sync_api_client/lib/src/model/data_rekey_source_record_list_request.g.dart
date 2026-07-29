// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_source_record_list_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DataRekeySourceRecordListRequest
    extends DataRekeySourceRecordListRequest {
  @override
  final String operationId;
  @override
  final int sourceDataGeneration;
  @override
  final int targetKeyEpoch;
  @override
  final String leaseToken;
  @override
  final int leaseVersion;
  @override
  final String? afterRecordId;
  @override
  final int? limit;

  factory _$DataRekeySourceRecordListRequest([
    void Function(DataRekeySourceRecordListRequestBuilder)? updates,
  ]) => (DataRekeySourceRecordListRequestBuilder()..update(updates))._build();

  _$DataRekeySourceRecordListRequest._({
    required this.operationId,
    required this.sourceDataGeneration,
    required this.targetKeyEpoch,
    required this.leaseToken,
    required this.leaseVersion,
    this.afterRecordId,
    this.limit,
  }) : super._();
  @override
  DataRekeySourceRecordListRequest rebuild(
    void Function(DataRekeySourceRecordListRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeySourceRecordListRequestBuilder toBuilder() =>
      DataRekeySourceRecordListRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeySourceRecordListRequest &&
        operationId == other.operationId &&
        sourceDataGeneration == other.sourceDataGeneration &&
        targetKeyEpoch == other.targetKeyEpoch &&
        leaseToken == other.leaseToken &&
        leaseVersion == other.leaseVersion &&
        afterRecordId == other.afterRecordId &&
        limit == other.limit;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, operationId.hashCode);
    _$hash = $jc(_$hash, sourceDataGeneration.hashCode);
    _$hash = $jc(_$hash, targetKeyEpoch.hashCode);
    _$hash = $jc(_$hash, leaseToken.hashCode);
    _$hash = $jc(_$hash, leaseVersion.hashCode);
    _$hash = $jc(_$hash, afterRecordId.hashCode);
    _$hash = $jc(_$hash, limit.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DataRekeySourceRecordListRequest')
          ..add('operationId', operationId)
          ..add('sourceDataGeneration', sourceDataGeneration)
          ..add('targetKeyEpoch', targetKeyEpoch)
          ..add('leaseToken', leaseToken)
          ..add('leaseVersion', leaseVersion)
          ..add('afterRecordId', afterRecordId)
          ..add('limit', limit))
        .toString();
  }
}

class DataRekeySourceRecordListRequestBuilder
    implements
        Builder<
          DataRekeySourceRecordListRequest,
          DataRekeySourceRecordListRequestBuilder
        > {
  _$DataRekeySourceRecordListRequest? _$v;

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

  int? _leaseVersion;
  int? get leaseVersion => _$this._leaseVersion;
  set leaseVersion(int? leaseVersion) => _$this._leaseVersion = leaseVersion;

  String? _afterRecordId;
  String? get afterRecordId => _$this._afterRecordId;
  set afterRecordId(String? afterRecordId) =>
      _$this._afterRecordId = afterRecordId;

  int? _limit;
  int? get limit => _$this._limit;
  set limit(int? limit) => _$this._limit = limit;

  DataRekeySourceRecordListRequestBuilder() {
    DataRekeySourceRecordListRequest._defaults(this);
  }

  DataRekeySourceRecordListRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _operationId = $v.operationId;
      _sourceDataGeneration = $v.sourceDataGeneration;
      _targetKeyEpoch = $v.targetKeyEpoch;
      _leaseToken = $v.leaseToken;
      _leaseVersion = $v.leaseVersion;
      _afterRecordId = $v.afterRecordId;
      _limit = $v.limit;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeySourceRecordListRequest other) {
    _$v = other as _$DataRekeySourceRecordListRequest;
  }

  @override
  void update(void Function(DataRekeySourceRecordListRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeySourceRecordListRequest build() => _build();

  _$DataRekeySourceRecordListRequest _build() {
    final _$result =
        _$v ??
        _$DataRekeySourceRecordListRequest._(
          operationId: BuiltValueNullFieldError.checkNotNull(
            operationId,
            r'DataRekeySourceRecordListRequest',
            'operationId',
          ),
          sourceDataGeneration: BuiltValueNullFieldError.checkNotNull(
            sourceDataGeneration,
            r'DataRekeySourceRecordListRequest',
            'sourceDataGeneration',
          ),
          targetKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            targetKeyEpoch,
            r'DataRekeySourceRecordListRequest',
            'targetKeyEpoch',
          ),
          leaseToken: BuiltValueNullFieldError.checkNotNull(
            leaseToken,
            r'DataRekeySourceRecordListRequest',
            'leaseToken',
          ),
          leaseVersion: BuiltValueNullFieldError.checkNotNull(
            leaseVersion,
            r'DataRekeySourceRecordListRequest',
            'leaseVersion',
          ),
          afterRecordId: afterRecordId,
          limit: limit,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
