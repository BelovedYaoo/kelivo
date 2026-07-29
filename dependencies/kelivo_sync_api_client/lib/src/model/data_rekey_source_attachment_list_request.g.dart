// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_source_attachment_list_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DataRekeySourceAttachmentListRequest
    extends DataRekeySourceAttachmentListRequest {
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
  final String? afterAttachmentId;
  @override
  final int? limit;

  factory _$DataRekeySourceAttachmentListRequest([
    void Function(DataRekeySourceAttachmentListRequestBuilder)? updates,
  ]) =>
      (DataRekeySourceAttachmentListRequestBuilder()..update(updates))._build();

  _$DataRekeySourceAttachmentListRequest._({
    required this.operationId,
    required this.sourceDataGeneration,
    required this.targetKeyEpoch,
    required this.leaseToken,
    required this.leaseVersion,
    this.afterAttachmentId,
    this.limit,
  }) : super._();
  @override
  DataRekeySourceAttachmentListRequest rebuild(
    void Function(DataRekeySourceAttachmentListRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeySourceAttachmentListRequestBuilder toBuilder() =>
      DataRekeySourceAttachmentListRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeySourceAttachmentListRequest &&
        operationId == other.operationId &&
        sourceDataGeneration == other.sourceDataGeneration &&
        targetKeyEpoch == other.targetKeyEpoch &&
        leaseToken == other.leaseToken &&
        leaseVersion == other.leaseVersion &&
        afterAttachmentId == other.afterAttachmentId &&
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
    _$hash = $jc(_$hash, afterAttachmentId.hashCode);
    _$hash = $jc(_$hash, limit.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DataRekeySourceAttachmentListRequest')
          ..add('operationId', operationId)
          ..add('sourceDataGeneration', sourceDataGeneration)
          ..add('targetKeyEpoch', targetKeyEpoch)
          ..add('leaseToken', leaseToken)
          ..add('leaseVersion', leaseVersion)
          ..add('afterAttachmentId', afterAttachmentId)
          ..add('limit', limit))
        .toString();
  }
}

class DataRekeySourceAttachmentListRequestBuilder
    implements
        Builder<
          DataRekeySourceAttachmentListRequest,
          DataRekeySourceAttachmentListRequestBuilder
        > {
  _$DataRekeySourceAttachmentListRequest? _$v;

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

  String? _afterAttachmentId;
  String? get afterAttachmentId => _$this._afterAttachmentId;
  set afterAttachmentId(String? afterAttachmentId) =>
      _$this._afterAttachmentId = afterAttachmentId;

  int? _limit;
  int? get limit => _$this._limit;
  set limit(int? limit) => _$this._limit = limit;

  DataRekeySourceAttachmentListRequestBuilder() {
    DataRekeySourceAttachmentListRequest._defaults(this);
  }

  DataRekeySourceAttachmentListRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _operationId = $v.operationId;
      _sourceDataGeneration = $v.sourceDataGeneration;
      _targetKeyEpoch = $v.targetKeyEpoch;
      _leaseToken = $v.leaseToken;
      _leaseVersion = $v.leaseVersion;
      _afterAttachmentId = $v.afterAttachmentId;
      _limit = $v.limit;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeySourceAttachmentListRequest other) {
    _$v = other as _$DataRekeySourceAttachmentListRequest;
  }

  @override
  void update(
    void Function(DataRekeySourceAttachmentListRequestBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeySourceAttachmentListRequest build() => _build();

  _$DataRekeySourceAttachmentListRequest _build() {
    final _$result =
        _$v ??
        _$DataRekeySourceAttachmentListRequest._(
          operationId: BuiltValueNullFieldError.checkNotNull(
            operationId,
            r'DataRekeySourceAttachmentListRequest',
            'operationId',
          ),
          sourceDataGeneration: BuiltValueNullFieldError.checkNotNull(
            sourceDataGeneration,
            r'DataRekeySourceAttachmentListRequest',
            'sourceDataGeneration',
          ),
          targetKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            targetKeyEpoch,
            r'DataRekeySourceAttachmentListRequest',
            'targetKeyEpoch',
          ),
          leaseToken: BuiltValueNullFieldError.checkNotNull(
            leaseToken,
            r'DataRekeySourceAttachmentListRequest',
            'leaseToken',
          ),
          leaseVersion: BuiltValueNullFieldError.checkNotNull(
            leaseVersion,
            r'DataRekeySourceAttachmentListRequest',
            'leaseVersion',
          ),
          afterAttachmentId: afterAttachmentId,
          limit: limit,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
