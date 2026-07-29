// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rekey_finalize_request_proof.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DataRekeyFinalizeRequestProof extends DataRekeyFinalizeRequestProof {
  @override
  final int proofVersion;
  @override
  final String issuerDeviceId;
  @override
  final int targetDataGeneration;
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
  final String signature;

  factory _$DataRekeyFinalizeRequestProof([
    void Function(DataRekeyFinalizeRequestProofBuilder)? updates,
  ]) => (DataRekeyFinalizeRequestProofBuilder()..update(updates))._build();

  _$DataRekeyFinalizeRequestProof._({
    required this.proofVersion,
    required this.issuerDeviceId,
    required this.targetDataGeneration,
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
    required this.signature,
  }) : super._();
  @override
  DataRekeyFinalizeRequestProof rebuild(
    void Function(DataRekeyFinalizeRequestProofBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  DataRekeyFinalizeRequestProofBuilder toBuilder() =>
      DataRekeyFinalizeRequestProofBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DataRekeyFinalizeRequestProof &&
        proofVersion == other.proofVersion &&
        issuerDeviceId == other.issuerDeviceId &&
        targetDataGeneration == other.targetDataGeneration &&
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
        signature == other.signature;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, proofVersion.hashCode);
    _$hash = $jc(_$hash, issuerDeviceId.hashCode);
    _$hash = $jc(_$hash, targetDataGeneration.hashCode);
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
    _$hash = $jc(_$hash, signature.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DataRekeyFinalizeRequestProof')
          ..add('proofVersion', proofVersion)
          ..add('issuerDeviceId', issuerDeviceId)
          ..add('targetDataGeneration', targetDataGeneration)
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
          ..add('signature', signature))
        .toString();
  }
}

class DataRekeyFinalizeRequestProofBuilder
    implements
        Builder<
          DataRekeyFinalizeRequestProof,
          DataRekeyFinalizeRequestProofBuilder
        > {
  _$DataRekeyFinalizeRequestProof? _$v;

  int? _proofVersion;
  int? get proofVersion => _$this._proofVersion;
  set proofVersion(int? proofVersion) => _$this._proofVersion = proofVersion;

  String? _issuerDeviceId;
  String? get issuerDeviceId => _$this._issuerDeviceId;
  set issuerDeviceId(String? issuerDeviceId) =>
      _$this._issuerDeviceId = issuerDeviceId;

  int? _targetDataGeneration;
  int? get targetDataGeneration => _$this._targetDataGeneration;
  set targetDataGeneration(int? targetDataGeneration) =>
      _$this._targetDataGeneration = targetDataGeneration;

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

  String? _signature;
  String? get signature => _$this._signature;
  set signature(String? signature) => _$this._signature = signature;

  DataRekeyFinalizeRequestProofBuilder() {
    DataRekeyFinalizeRequestProof._defaults(this);
  }

  DataRekeyFinalizeRequestProofBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _proofVersion = $v.proofVersion;
      _issuerDeviceId = $v.issuerDeviceId;
      _targetDataGeneration = $v.targetDataGeneration;
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
      _signature = $v.signature;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DataRekeyFinalizeRequestProof other) {
    _$v = other as _$DataRekeyFinalizeRequestProof;
  }

  @override
  void update(void Function(DataRekeyFinalizeRequestProofBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DataRekeyFinalizeRequestProof build() => _build();

  _$DataRekeyFinalizeRequestProof _build() {
    _$DataRekeyFinalizeRequestProof _$result;
    try {
      _$result =
          _$v ??
          _$DataRekeyFinalizeRequestProof._(
            proofVersion: BuiltValueNullFieldError.checkNotNull(
              proofVersion,
              r'DataRekeyFinalizeRequestProof',
              'proofVersion',
            ),
            issuerDeviceId: BuiltValueNullFieldError.checkNotNull(
              issuerDeviceId,
              r'DataRekeyFinalizeRequestProof',
              'issuerDeviceId',
            ),
            targetDataGeneration: BuiltValueNullFieldError.checkNotNull(
              targetDataGeneration,
              r'DataRekeyFinalizeRequestProof',
              'targetDataGeneration',
            ),
            sourceSnapshotRoot: BuiltValueNullFieldError.checkNotNull(
              sourceSnapshotRoot,
              r'DataRekeyFinalizeRequestProof',
              'sourceSnapshotRoot',
            ),
            sourceRecordCount: BuiltValueNullFieldError.checkNotNull(
              sourceRecordCount,
              r'DataRekeyFinalizeRequestProof',
              'sourceRecordCount',
            ),
            sourceAttachmentCount: BuiltValueNullFieldError.checkNotNull(
              sourceAttachmentCount,
              r'DataRekeyFinalizeRequestProof',
              'sourceAttachmentCount',
            ),
            sourceMaximumChangeSeq: BuiltValueNullFieldError.checkNotNull(
              sourceMaximumChangeSeq,
              r'DataRekeyFinalizeRequestProof',
              'sourceMaximumChangeSeq',
            ),
            sourceRecordCursorEnd: sourceRecordCursorEnd,
            sourceAttachmentCursorEnd: _sourceAttachmentCursorEnd?.build(),
            membershipGeneration: BuiltValueNullFieldError.checkNotNull(
              membershipGeneration,
              r'DataRekeyFinalizeRequestProof',
              'membershipGeneration',
            ),
            membershipManifestDigest: BuiltValueNullFieldError.checkNotNull(
              membershipManifestDigest,
              r'DataRekeyFinalizeRequestProof',
              'membershipManifestDigest',
            ),
            stagedRecordCount: BuiltValueNullFieldError.checkNotNull(
              stagedRecordCount,
              r'DataRekeyFinalizeRequestProof',
              'stagedRecordCount',
            ),
            stagedAttachmentCount: BuiltValueNullFieldError.checkNotNull(
              stagedAttachmentCount,
              r'DataRekeyFinalizeRequestProof',
              'stagedAttachmentCount',
            ),
            stagedCiphertextSetDigest: BuiltValueNullFieldError.checkNotNull(
              stagedCiphertextSetDigest,
              r'DataRekeyFinalizeRequestProof',
              'stagedCiphertextSetDigest',
            ),
            signature: BuiltValueNullFieldError.checkNotNull(
              signature,
              r'DataRekeyFinalizeRequestProof',
              'signature',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'sourceAttachmentCursorEnd';
        _sourceAttachmentCursorEnd?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'DataRekeyFinalizeRequestProof',
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
