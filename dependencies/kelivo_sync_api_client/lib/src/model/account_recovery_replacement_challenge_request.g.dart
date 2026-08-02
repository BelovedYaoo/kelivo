// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_recovery_replacement_challenge_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AccountRecoveryReplacementChallengeRequest
    extends AccountRecoveryReplacementChallengeRequest {
  @override
  final int protocolVersion;
  @override
  final String challengeId;
  @override
  final int expectedGeneration;
  @override
  final int expectedKeyEpoch;
  @override
  final String expectedMembershipManifestDigest;
  @override
  final String expectedMembershipOperationId;
  @override
  final int dataGeneration;
  @override
  final int dataKeyEpoch;
  @override
  final String sourceRekeyOperationId;
  @override
  final String sourceCompletionProofDigest;

  factory _$AccountRecoveryReplacementChallengeRequest([
    void Function(AccountRecoveryReplacementChallengeRequestBuilder)? updates,
  ]) => (AccountRecoveryReplacementChallengeRequestBuilder()..update(updates))
      ._build();

  _$AccountRecoveryReplacementChallengeRequest._({
    required this.protocolVersion,
    required this.challengeId,
    required this.expectedGeneration,
    required this.expectedKeyEpoch,
    required this.expectedMembershipManifestDigest,
    required this.expectedMembershipOperationId,
    required this.dataGeneration,
    required this.dataKeyEpoch,
    required this.sourceRekeyOperationId,
    required this.sourceCompletionProofDigest,
  }) : super._();
  @override
  AccountRecoveryReplacementChallengeRequest rebuild(
    void Function(AccountRecoveryReplacementChallengeRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountRecoveryReplacementChallengeRequestBuilder toBuilder() =>
      AccountRecoveryReplacementChallengeRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountRecoveryReplacementChallengeRequest &&
        protocolVersion == other.protocolVersion &&
        challengeId == other.challengeId &&
        expectedGeneration == other.expectedGeneration &&
        expectedKeyEpoch == other.expectedKeyEpoch &&
        expectedMembershipManifestDigest ==
            other.expectedMembershipManifestDigest &&
        expectedMembershipOperationId == other.expectedMembershipOperationId &&
        dataGeneration == other.dataGeneration &&
        dataKeyEpoch == other.dataKeyEpoch &&
        sourceRekeyOperationId == other.sourceRekeyOperationId &&
        sourceCompletionProofDigest == other.sourceCompletionProofDigest;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, protocolVersion.hashCode);
    _$hash = $jc(_$hash, challengeId.hashCode);
    _$hash = $jc(_$hash, expectedGeneration.hashCode);
    _$hash = $jc(_$hash, expectedKeyEpoch.hashCode);
    _$hash = $jc(_$hash, expectedMembershipManifestDigest.hashCode);
    _$hash = $jc(_$hash, expectedMembershipOperationId.hashCode);
    _$hash = $jc(_$hash, dataGeneration.hashCode);
    _$hash = $jc(_$hash, dataKeyEpoch.hashCode);
    _$hash = $jc(_$hash, sourceRekeyOperationId.hashCode);
    _$hash = $jc(_$hash, sourceCompletionProofDigest.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
            r'AccountRecoveryReplacementChallengeRequest',
          )
          ..add('protocolVersion', protocolVersion)
          ..add('challengeId', challengeId)
          ..add('expectedGeneration', expectedGeneration)
          ..add('expectedKeyEpoch', expectedKeyEpoch)
          ..add(
            'expectedMembershipManifestDigest',
            expectedMembershipManifestDigest,
          )
          ..add('expectedMembershipOperationId', expectedMembershipOperationId)
          ..add('dataGeneration', dataGeneration)
          ..add('dataKeyEpoch', dataKeyEpoch)
          ..add('sourceRekeyOperationId', sourceRekeyOperationId)
          ..add('sourceCompletionProofDigest', sourceCompletionProofDigest))
        .toString();
  }
}

class AccountRecoveryReplacementChallengeRequestBuilder
    implements
        Builder<
          AccountRecoveryReplacementChallengeRequest,
          AccountRecoveryReplacementChallengeRequestBuilder
        > {
  _$AccountRecoveryReplacementChallengeRequest? _$v;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

  String? _challengeId;
  String? get challengeId => _$this._challengeId;
  set challengeId(String? challengeId) => _$this._challengeId = challengeId;

  int? _expectedGeneration;
  int? get expectedGeneration => _$this._expectedGeneration;
  set expectedGeneration(int? expectedGeneration) =>
      _$this._expectedGeneration = expectedGeneration;

  int? _expectedKeyEpoch;
  int? get expectedKeyEpoch => _$this._expectedKeyEpoch;
  set expectedKeyEpoch(int? expectedKeyEpoch) =>
      _$this._expectedKeyEpoch = expectedKeyEpoch;

  String? _expectedMembershipManifestDigest;
  String? get expectedMembershipManifestDigest =>
      _$this._expectedMembershipManifestDigest;
  set expectedMembershipManifestDigest(
    String? expectedMembershipManifestDigest,
  ) => _$this._expectedMembershipManifestDigest =
      expectedMembershipManifestDigest;

  String? _expectedMembershipOperationId;
  String? get expectedMembershipOperationId =>
      _$this._expectedMembershipOperationId;
  set expectedMembershipOperationId(String? expectedMembershipOperationId) =>
      _$this._expectedMembershipOperationId = expectedMembershipOperationId;

  int? _dataGeneration;
  int? get dataGeneration => _$this._dataGeneration;
  set dataGeneration(int? dataGeneration) =>
      _$this._dataGeneration = dataGeneration;

  int? _dataKeyEpoch;
  int? get dataKeyEpoch => _$this._dataKeyEpoch;
  set dataKeyEpoch(int? dataKeyEpoch) => _$this._dataKeyEpoch = dataKeyEpoch;

  String? _sourceRekeyOperationId;
  String? get sourceRekeyOperationId => _$this._sourceRekeyOperationId;
  set sourceRekeyOperationId(String? sourceRekeyOperationId) =>
      _$this._sourceRekeyOperationId = sourceRekeyOperationId;

  String? _sourceCompletionProofDigest;
  String? get sourceCompletionProofDigest =>
      _$this._sourceCompletionProofDigest;
  set sourceCompletionProofDigest(String? sourceCompletionProofDigest) =>
      _$this._sourceCompletionProofDigest = sourceCompletionProofDigest;

  AccountRecoveryReplacementChallengeRequestBuilder() {
    AccountRecoveryReplacementChallengeRequest._defaults(this);
  }

  AccountRecoveryReplacementChallengeRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _protocolVersion = $v.protocolVersion;
      _challengeId = $v.challengeId;
      _expectedGeneration = $v.expectedGeneration;
      _expectedKeyEpoch = $v.expectedKeyEpoch;
      _expectedMembershipManifestDigest = $v.expectedMembershipManifestDigest;
      _expectedMembershipOperationId = $v.expectedMembershipOperationId;
      _dataGeneration = $v.dataGeneration;
      _dataKeyEpoch = $v.dataKeyEpoch;
      _sourceRekeyOperationId = $v.sourceRekeyOperationId;
      _sourceCompletionProofDigest = $v.sourceCompletionProofDigest;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AccountRecoveryReplacementChallengeRequest other) {
    _$v = other as _$AccountRecoveryReplacementChallengeRequest;
  }

  @override
  void update(
    void Function(AccountRecoveryReplacementChallengeRequestBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  AccountRecoveryReplacementChallengeRequest build() => _build();

  _$AccountRecoveryReplacementChallengeRequest _build() {
    final _$result =
        _$v ??
        _$AccountRecoveryReplacementChallengeRequest._(
          protocolVersion: BuiltValueNullFieldError.checkNotNull(
            protocolVersion,
            r'AccountRecoveryReplacementChallengeRequest',
            'protocolVersion',
          ),
          challengeId: BuiltValueNullFieldError.checkNotNull(
            challengeId,
            r'AccountRecoveryReplacementChallengeRequest',
            'challengeId',
          ),
          expectedGeneration: BuiltValueNullFieldError.checkNotNull(
            expectedGeneration,
            r'AccountRecoveryReplacementChallengeRequest',
            'expectedGeneration',
          ),
          expectedKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            expectedKeyEpoch,
            r'AccountRecoveryReplacementChallengeRequest',
            'expectedKeyEpoch',
          ),
          expectedMembershipManifestDigest:
              BuiltValueNullFieldError.checkNotNull(
                expectedMembershipManifestDigest,
                r'AccountRecoveryReplacementChallengeRequest',
                'expectedMembershipManifestDigest',
              ),
          expectedMembershipOperationId: BuiltValueNullFieldError.checkNotNull(
            expectedMembershipOperationId,
            r'AccountRecoveryReplacementChallengeRequest',
            'expectedMembershipOperationId',
          ),
          dataGeneration: BuiltValueNullFieldError.checkNotNull(
            dataGeneration,
            r'AccountRecoveryReplacementChallengeRequest',
            'dataGeneration',
          ),
          dataKeyEpoch: BuiltValueNullFieldError.checkNotNull(
            dataKeyEpoch,
            r'AccountRecoveryReplacementChallengeRequest',
            'dataKeyEpoch',
          ),
          sourceRekeyOperationId: BuiltValueNullFieldError.checkNotNull(
            sourceRekeyOperationId,
            r'AccountRecoveryReplacementChallengeRequest',
            'sourceRekeyOperationId',
          ),
          sourceCompletionProofDigest: BuiltValueNullFieldError.checkNotNull(
            sourceCompletionProofDigest,
            r'AccountRecoveryReplacementChallengeRequest',
            'sourceCompletionProofDigest',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
