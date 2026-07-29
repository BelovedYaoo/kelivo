// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_completion_proof_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DataRekeyCompletionProofData extends DataRekeyCompletionProofData {
  @override
  final String operationId;
  @override
  final String issuerDeviceId;
  @override
  final int sourceDataGeneration;
  @override
  final int targetDataGeneration;
  @override
  final int targetKeyEpoch;
  @override
  final String membershipManifestDigest;
  @override
  final int stagedRecordCount;
  @override
  final int stagedAttachmentCount;
  @override
  final String stagedCiphertextSetDigest;
  @override
  final String signature;
  @override
  final DateTime finalizedAt;

  factory _$DataRekeyCompletionProofData([
    void Function(DataRekeyCompletionProofDataBuilder)? updates,
  ]) => (DataRekeyCompletionProofDataBuilder()..update(updates))._build();

  _$DataRekeyCompletionProofData._({
    required this.operationId,
    required this.issuerDeviceId,
    required this.sourceDataGeneration,
    required this.targetDataGeneration,
    required this.targetKeyEpoch,
    required this.membershipManifestDigest,
    required this.stagedRecordCount,
    required this.stagedAttachmentCount,
    required this.stagedCiphertextSetDigest,
    required this.signature,
    required this.finalizedAt,
  }) : super._();
  @override
  DataRekeyCompletionProofData rebuild(
    void Function(DataRekeyCompletionProofDataBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeyCompletionProofDataBuilder toBuilder() =>
      DataRekeyCompletionProofDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeyCompletionProofData &&
        operationId == other.operationId &&
        issuerDeviceId == other.issuerDeviceId &&
        sourceDataGeneration == other.sourceDataGeneration &&
        targetDataGeneration == other.targetDataGeneration &&
        targetKeyEpoch == other.targetKeyEpoch &&
        membershipManifestDigest == other.membershipManifestDigest &&
        stagedRecordCount == other.stagedRecordCount &&
        stagedAttachmentCount == other.stagedAttachmentCount &&
        stagedCiphertextSetDigest == other.stagedCiphertextSetDigest &&
        signature == other.signature &&
        finalizedAt == other.finalizedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, operationId.hashCode);
    _$hash = $jc(_$hash, issuerDeviceId.hashCode);
    _$hash = $jc(_$hash, sourceDataGeneration.hashCode);
    _$hash = $jc(_$hash, targetDataGeneration.hashCode);
    _$hash = $jc(_$hash, targetKeyEpoch.hashCode);
    _$hash = $jc(_$hash, membershipManifestDigest.hashCode);
    _$hash = $jc(_$hash, stagedRecordCount.hashCode);
    _$hash = $jc(_$hash, stagedAttachmentCount.hashCode);
    _$hash = $jc(_$hash, stagedCiphertextSetDigest.hashCode);
    _$hash = $jc(_$hash, signature.hashCode);
    _$hash = $jc(_$hash, finalizedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DataRekeyCompletionProofData')
          ..add('operationId', operationId)
          ..add('issuerDeviceId', issuerDeviceId)
          ..add('sourceDataGeneration', sourceDataGeneration)
          ..add('targetDataGeneration', targetDataGeneration)
          ..add('targetKeyEpoch', targetKeyEpoch)
          ..add('membershipManifestDigest', membershipManifestDigest)
          ..add('stagedRecordCount', stagedRecordCount)
          ..add('stagedAttachmentCount', stagedAttachmentCount)
          ..add('stagedCiphertextSetDigest', stagedCiphertextSetDigest)
          ..add('signature', signature)
          ..add('finalizedAt', finalizedAt))
        .toString();
  }
}

class DataRekeyCompletionProofDataBuilder
    implements
        Builder<
          DataRekeyCompletionProofData,
          DataRekeyCompletionProofDataBuilder
        > {
  _$DataRekeyCompletionProofData? _$v;

  String? _operationId;
  String? get operationId => _$this._operationId;
  set operationId(String? operationId) => _$this._operationId = operationId;

  String? _issuerDeviceId;
  String? get issuerDeviceId => _$this._issuerDeviceId;
  set issuerDeviceId(String? issuerDeviceId) =>
      _$this._issuerDeviceId = issuerDeviceId;

  int? _sourceDataGeneration;
  int? get sourceDataGeneration => _$this._sourceDataGeneration;
  set sourceDataGeneration(int? sourceDataGeneration) =>
      _$this._sourceDataGeneration = sourceDataGeneration;

  int? _targetDataGeneration;
  int? get targetDataGeneration => _$this._targetDataGeneration;
  set targetDataGeneration(int? targetDataGeneration) =>
      _$this._targetDataGeneration = targetDataGeneration;

  int? _targetKeyEpoch;
  int? get targetKeyEpoch => _$this._targetKeyEpoch;
  set targetKeyEpoch(int? targetKeyEpoch) =>
      _$this._targetKeyEpoch = targetKeyEpoch;

  String? _membershipManifestDigest;
  String? get membershipManifestDigest => _$this._membershipManifestDigest;
  set membershipManifestDigest(String? membershipManifestDigest) =>
      _$this._membershipManifestDigest = membershipManifestDigest;

  int? _stagedRecordCount;
  int? get stagedRecordCount => _$this._stagedRecordCount;
  set stagedRecordCount(int? stagedRecordCount) =>
      _$this._stagedRecordCount = stagedRecordCount;

  int? _stagedAttachmentCount;
  int? get stagedAttachmentCount => _$this._stagedAttachmentCount;
  set stagedAttachmentCount(int? stagedAttachmentCount) =>
      _$this._stagedAttachmentCount = stagedAttachmentCount;

  String? _stagedCiphertextSetDigest;
  String? get stagedCiphertextSetDigest => _$this._stagedCiphertextSetDigest;
  set stagedCiphertextSetDigest(String? stagedCiphertextSetDigest) =>
      _$this._stagedCiphertextSetDigest = stagedCiphertextSetDigest;

  String? _signature;
  String? get signature => _$this._signature;
  set signature(String? signature) => _$this._signature = signature;

  DateTime? _finalizedAt;
  DateTime? get finalizedAt => _$this._finalizedAt;
  set finalizedAt(DateTime? finalizedAt) => _$this._finalizedAt = finalizedAt;

  DataRekeyCompletionProofDataBuilder() {
    DataRekeyCompletionProofData._defaults(this);
  }

  DataRekeyCompletionProofDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _operationId = $v.operationId;
      _issuerDeviceId = $v.issuerDeviceId;
      _sourceDataGeneration = $v.sourceDataGeneration;
      _targetDataGeneration = $v.targetDataGeneration;
      _targetKeyEpoch = $v.targetKeyEpoch;
      _membershipManifestDigest = $v.membershipManifestDigest;
      _stagedRecordCount = $v.stagedRecordCount;
      _stagedAttachmentCount = $v.stagedAttachmentCount;
      _stagedCiphertextSetDigest = $v.stagedCiphertextSetDigest;
      _signature = $v.signature;
      _finalizedAt = $v.finalizedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeyCompletionProofData other) {
    _$v = other as _$DataRekeyCompletionProofData;
  }

  @override
  void update(void Function(DataRekeyCompletionProofDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeyCompletionProofData build() => _build();

  _$DataRekeyCompletionProofData _build() {
    final _$result =
        _$v ??
        _$DataRekeyCompletionProofData._(
          operationId: BuiltValueNullFieldError.checkNotNull(
            operationId,
            r'DataRekeyCompletionProofData',
            'operationId',
          ),
          issuerDeviceId: BuiltValueNullFieldError.checkNotNull(
            issuerDeviceId,
            r'DataRekeyCompletionProofData',
            'issuerDeviceId',
          ),
          sourceDataGeneration: BuiltValueNullFieldError.checkNotNull(
            sourceDataGeneration,
            r'DataRekeyCompletionProofData',
            'sourceDataGeneration',
          ),
          targetDataGeneration: BuiltValueNullFieldError.checkNotNull(
            targetDataGeneration,
            r'DataRekeyCompletionProofData',
            'targetDataGeneration',
          ),
          targetKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            targetKeyEpoch,
            r'DataRekeyCompletionProofData',
            'targetKeyEpoch',
          ),
          membershipManifestDigest: BuiltValueNullFieldError.checkNotNull(
            membershipManifestDigest,
            r'DataRekeyCompletionProofData',
            'membershipManifestDigest',
          ),
          stagedRecordCount: BuiltValueNullFieldError.checkNotNull(
            stagedRecordCount,
            r'DataRekeyCompletionProofData',
            'stagedRecordCount',
          ),
          stagedAttachmentCount: BuiltValueNullFieldError.checkNotNull(
            stagedAttachmentCount,
            r'DataRekeyCompletionProofData',
            'stagedAttachmentCount',
          ),
          stagedCiphertextSetDigest: BuiltValueNullFieldError.checkNotNull(
            stagedCiphertextSetDigest,
            r'DataRekeyCompletionProofData',
            'stagedCiphertextSetDigest',
          ),
          signature: BuiltValueNullFieldError.checkNotNull(
            signature,
            r'DataRekeyCompletionProofData',
            'signature',
          ),
          finalizedAt: BuiltValueNullFieldError.checkNotNull(
            finalizedAt,
            r'DataRekeyCompletionProofData',
            'finalizedAt',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
