// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_completion_proof_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DataRekeyCompletionProofData extends DataRekeyCompletionProofData {
  @override
  final int proofVersion;
  @override
  final String operationId;
  @override
  final String issuerDeviceId;
  @override
  final int sourceDataGeneration;
  @override
  final int targetDataGeneration;
  @override
  final int sourceKeyEpoch;
  @override
  final int targetKeyEpoch;
  @override
  final String sourceSnapshotRoot;
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
  final int membershipGeneration;
  @override
  final String membershipManifestDigest;
  @override
  final int stagedRecordCount;
  @override
  final int stagedAttachmentCount;
  @override
  final String stagedCiphertextSetDigest;
  @override
  final String proofFrame;
  @override
  final String proofDigest;
  @override
  final String signature;
  @override
  final DateTime finalizedAt;

  factory _$DataRekeyCompletionProofData([
    void Function(DataRekeyCompletionProofDataBuilder)? updates,
  ]) => (DataRekeyCompletionProofDataBuilder()..update(updates))._build();

  _$DataRekeyCompletionProofData._({
    required this.proofVersion,
    required this.operationId,
    required this.issuerDeviceId,
    required this.sourceDataGeneration,
    required this.targetDataGeneration,
    required this.sourceKeyEpoch,
    required this.targetKeyEpoch,
    required this.sourceSnapshotRoot,
    required this.sourceRecordCount,
    required this.sourceAttachmentCount,
    required this.sourceMaximumChangeSeq,
    this.sourceRecordCursorEnd,
    this.sourceAttachmentCursorEnd,
    required this.membershipGeneration,
    required this.membershipManifestDigest,
    required this.stagedRecordCount,
    required this.stagedAttachmentCount,
    required this.stagedCiphertextSetDigest,
    required this.proofFrame,
    required this.proofDigest,
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
        proofVersion == other.proofVersion &&
        operationId == other.operationId &&
        issuerDeviceId == other.issuerDeviceId &&
        sourceDataGeneration == other.sourceDataGeneration &&
        targetDataGeneration == other.targetDataGeneration &&
        sourceKeyEpoch == other.sourceKeyEpoch &&
        targetKeyEpoch == other.targetKeyEpoch &&
        sourceSnapshotRoot == other.sourceSnapshotRoot &&
        sourceRecordCount == other.sourceRecordCount &&
        sourceAttachmentCount == other.sourceAttachmentCount &&
        sourceMaximumChangeSeq == other.sourceMaximumChangeSeq &&
        sourceRecordCursorEnd == other.sourceRecordCursorEnd &&
        sourceAttachmentCursorEnd == other.sourceAttachmentCursorEnd &&
        membershipGeneration == other.membershipGeneration &&
        membershipManifestDigest == other.membershipManifestDigest &&
        stagedRecordCount == other.stagedRecordCount &&
        stagedAttachmentCount == other.stagedAttachmentCount &&
        stagedCiphertextSetDigest == other.stagedCiphertextSetDigest &&
        proofFrame == other.proofFrame &&
        proofDigest == other.proofDigest &&
        signature == other.signature &&
        finalizedAt == other.finalizedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, proofVersion.hashCode);
    _$hash = $jc(_$hash, operationId.hashCode);
    _$hash = $jc(_$hash, issuerDeviceId.hashCode);
    _$hash = $jc(_$hash, sourceDataGeneration.hashCode);
    _$hash = $jc(_$hash, targetDataGeneration.hashCode);
    _$hash = $jc(_$hash, sourceKeyEpoch.hashCode);
    _$hash = $jc(_$hash, targetKeyEpoch.hashCode);
    _$hash = $jc(_$hash, sourceSnapshotRoot.hashCode);
    _$hash = $jc(_$hash, sourceRecordCount.hashCode);
    _$hash = $jc(_$hash, sourceAttachmentCount.hashCode);
    _$hash = $jc(_$hash, sourceMaximumChangeSeq.hashCode);
    _$hash = $jc(_$hash, sourceRecordCursorEnd.hashCode);
    _$hash = $jc(_$hash, sourceAttachmentCursorEnd.hashCode);
    _$hash = $jc(_$hash, membershipGeneration.hashCode);
    _$hash = $jc(_$hash, membershipManifestDigest.hashCode);
    _$hash = $jc(_$hash, stagedRecordCount.hashCode);
    _$hash = $jc(_$hash, stagedAttachmentCount.hashCode);
    _$hash = $jc(_$hash, stagedCiphertextSetDigest.hashCode);
    _$hash = $jc(_$hash, proofFrame.hashCode);
    _$hash = $jc(_$hash, proofDigest.hashCode);
    _$hash = $jc(_$hash, signature.hashCode);
    _$hash = $jc(_$hash, finalizedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DataRekeyCompletionProofData')
          ..add('proofVersion', proofVersion)
          ..add('operationId', operationId)
          ..add('issuerDeviceId', issuerDeviceId)
          ..add('sourceDataGeneration', sourceDataGeneration)
          ..add('targetDataGeneration', targetDataGeneration)
          ..add('sourceKeyEpoch', sourceKeyEpoch)
          ..add('targetKeyEpoch', targetKeyEpoch)
          ..add('sourceSnapshotRoot', sourceSnapshotRoot)
          ..add('sourceRecordCount', sourceRecordCount)
          ..add('sourceAttachmentCount', sourceAttachmentCount)
          ..add('sourceMaximumChangeSeq', sourceMaximumChangeSeq)
          ..add('sourceRecordCursorEnd', sourceRecordCursorEnd)
          ..add('sourceAttachmentCursorEnd', sourceAttachmentCursorEnd)
          ..add('membershipGeneration', membershipGeneration)
          ..add('membershipManifestDigest', membershipManifestDigest)
          ..add('stagedRecordCount', stagedRecordCount)
          ..add('stagedAttachmentCount', stagedAttachmentCount)
          ..add('stagedCiphertextSetDigest', stagedCiphertextSetDigest)
          ..add('proofFrame', proofFrame)
          ..add('proofDigest', proofDigest)
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

  int? _proofVersion;
  int? get proofVersion => _$this._proofVersion;
  set proofVersion(int? proofVersion) => _$this._proofVersion = proofVersion;

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

  int? _sourceKeyEpoch;
  int? get sourceKeyEpoch => _$this._sourceKeyEpoch;
  set sourceKeyEpoch(int? sourceKeyEpoch) =>
      _$this._sourceKeyEpoch = sourceKeyEpoch;

  int? _targetKeyEpoch;
  int? get targetKeyEpoch => _$this._targetKeyEpoch;
  set targetKeyEpoch(int? targetKeyEpoch) =>
      _$this._targetKeyEpoch = targetKeyEpoch;

  String? _sourceSnapshotRoot;
  String? get sourceSnapshotRoot => _$this._sourceSnapshotRoot;
  set sourceSnapshotRoot(String? sourceSnapshotRoot) =>
      _$this._sourceSnapshotRoot = sourceSnapshotRoot;

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

  int? _membershipGeneration;
  int? get membershipGeneration => _$this._membershipGeneration;
  set membershipGeneration(int? membershipGeneration) =>
      _$this._membershipGeneration = membershipGeneration;

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

  String? _proofFrame;
  String? get proofFrame => _$this._proofFrame;
  set proofFrame(String? proofFrame) => _$this._proofFrame = proofFrame;

  String? _proofDigest;
  String? get proofDigest => _$this._proofDigest;
  set proofDigest(String? proofDigest) => _$this._proofDigest = proofDigest;

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
      _proofVersion = $v.proofVersion;
      _operationId = $v.operationId;
      _issuerDeviceId = $v.issuerDeviceId;
      _sourceDataGeneration = $v.sourceDataGeneration;
      _targetDataGeneration = $v.targetDataGeneration;
      _sourceKeyEpoch = $v.sourceKeyEpoch;
      _targetKeyEpoch = $v.targetKeyEpoch;
      _sourceSnapshotRoot = $v.sourceSnapshotRoot;
      _sourceRecordCount = $v.sourceRecordCount;
      _sourceAttachmentCount = $v.sourceAttachmentCount;
      _sourceMaximumChangeSeq = $v.sourceMaximumChangeSeq;
      _sourceRecordCursorEnd = $v.sourceRecordCursorEnd;
      _sourceAttachmentCursorEnd = $v.sourceAttachmentCursorEnd?.toBuilder();
      _membershipGeneration = $v.membershipGeneration;
      _membershipManifestDigest = $v.membershipManifestDigest;
      _stagedRecordCount = $v.stagedRecordCount;
      _stagedAttachmentCount = $v.stagedAttachmentCount;
      _stagedCiphertextSetDigest = $v.stagedCiphertextSetDigest;
      _proofFrame = $v.proofFrame;
      _proofDigest = $v.proofDigest;
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
    _$DataRekeyCompletionProofData _$result;
    try {
      _$result =
          _$v ??
          _$DataRekeyCompletionProofData._(
            proofVersion: BuiltValueNullFieldError.checkNotNull(
              proofVersion,
              r'DataRekeyCompletionProofData',
              'proofVersion',
            ),
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
            sourceKeyEpoch: BuiltValueNullFieldError.checkNotNull(
              sourceKeyEpoch,
              r'DataRekeyCompletionProofData',
              'sourceKeyEpoch',
            ),
            targetKeyEpoch: BuiltValueNullFieldError.checkNotNull(
              targetKeyEpoch,
              r'DataRekeyCompletionProofData',
              'targetKeyEpoch',
            ),
            sourceSnapshotRoot: BuiltValueNullFieldError.checkNotNull(
              sourceSnapshotRoot,
              r'DataRekeyCompletionProofData',
              'sourceSnapshotRoot',
            ),
            sourceRecordCount: BuiltValueNullFieldError.checkNotNull(
              sourceRecordCount,
              r'DataRekeyCompletionProofData',
              'sourceRecordCount',
            ),
            sourceAttachmentCount: BuiltValueNullFieldError.checkNotNull(
              sourceAttachmentCount,
              r'DataRekeyCompletionProofData',
              'sourceAttachmentCount',
            ),
            sourceMaximumChangeSeq: BuiltValueNullFieldError.checkNotNull(
              sourceMaximumChangeSeq,
              r'DataRekeyCompletionProofData',
              'sourceMaximumChangeSeq',
            ),
            sourceRecordCursorEnd: sourceRecordCursorEnd,
            sourceAttachmentCursorEnd: _sourceAttachmentCursorEnd?.build(),
            membershipGeneration: BuiltValueNullFieldError.checkNotNull(
              membershipGeneration,
              r'DataRekeyCompletionProofData',
              'membershipGeneration',
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
            proofFrame: BuiltValueNullFieldError.checkNotNull(
              proofFrame,
              r'DataRekeyCompletionProofData',
              'proofFrame',
            ),
            proofDigest: BuiltValueNullFieldError.checkNotNull(
              proofDigest,
              r'DataRekeyCompletionProofData',
              'proofDigest',
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
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'sourceAttachmentCursorEnd';
        _sourceAttachmentCursorEnd?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'DataRekeyCompletionProofData',
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
