// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_recovery_replacement_commit_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AccountRecoveryReplacementCommitRequest
    extends AccountRecoveryReplacementCommitRequest {
  @override
  final int protocolVersion;
  @override
  final int expectedGeneration;
  @override
  final int expectedKeyEpoch;
  @override
  final String expectedMembershipManifestDigest;
  @override
  final String operationId;
  @override
  final String nextMembershipManifest;
  @override
  final String nextMembershipManifestDigest;
  @override
  final AccountRecoveryResumeCommitRequestEnvelope envelope;
  @override
  final int nextRecoveryCapsuleVersion;
  @override
  final String nextRecoveryCapsule;
  @override
  final String completionSessionId;
  @override
  final String completionSessionToken;

  factory _$AccountRecoveryReplacementCommitRequest([
    void Function(AccountRecoveryReplacementCommitRequestBuilder)? updates,
  ]) => (AccountRecoveryReplacementCommitRequestBuilder()..update(updates))
      ._build();

  _$AccountRecoveryReplacementCommitRequest._({
    required this.protocolVersion,
    required this.expectedGeneration,
    required this.expectedKeyEpoch,
    required this.expectedMembershipManifestDigest,
    required this.operationId,
    required this.nextMembershipManifest,
    required this.nextMembershipManifestDigest,
    required this.envelope,
    required this.nextRecoveryCapsuleVersion,
    required this.nextRecoveryCapsule,
    required this.completionSessionId,
    required this.completionSessionToken,
  }) : super._();
  @override
  AccountRecoveryReplacementCommitRequest rebuild(
    void Function(AccountRecoveryReplacementCommitRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountRecoveryReplacementCommitRequestBuilder toBuilder() =>
      AccountRecoveryReplacementCommitRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountRecoveryReplacementCommitRequest &&
        protocolVersion == other.protocolVersion &&
        expectedGeneration == other.expectedGeneration &&
        expectedKeyEpoch == other.expectedKeyEpoch &&
        expectedMembershipManifestDigest ==
            other.expectedMembershipManifestDigest &&
        operationId == other.operationId &&
        nextMembershipManifest == other.nextMembershipManifest &&
        nextMembershipManifestDigest == other.nextMembershipManifestDigest &&
        envelope == other.envelope &&
        nextRecoveryCapsuleVersion == other.nextRecoveryCapsuleVersion &&
        nextRecoveryCapsule == other.nextRecoveryCapsule &&
        completionSessionId == other.completionSessionId &&
        completionSessionToken == other.completionSessionToken;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, protocolVersion.hashCode);
    _$hash = $jc(_$hash, expectedGeneration.hashCode);
    _$hash = $jc(_$hash, expectedKeyEpoch.hashCode);
    _$hash = $jc(_$hash, expectedMembershipManifestDigest.hashCode);
    _$hash = $jc(_$hash, operationId.hashCode);
    _$hash = $jc(_$hash, nextMembershipManifest.hashCode);
    _$hash = $jc(_$hash, nextMembershipManifestDigest.hashCode);
    _$hash = $jc(_$hash, envelope.hashCode);
    _$hash = $jc(_$hash, nextRecoveryCapsuleVersion.hashCode);
    _$hash = $jc(_$hash, nextRecoveryCapsule.hashCode);
    _$hash = $jc(_$hash, completionSessionId.hashCode);
    _$hash = $jc(_$hash, completionSessionToken.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
            r'AccountRecoveryReplacementCommitRequest',
          )
          ..add('protocolVersion', protocolVersion)
          ..add('expectedGeneration', expectedGeneration)
          ..add('expectedKeyEpoch', expectedKeyEpoch)
          ..add(
            'expectedMembershipManifestDigest',
            expectedMembershipManifestDigest,
          )
          ..add('operationId', operationId)
          ..add('nextMembershipManifest', nextMembershipManifest)
          ..add('nextMembershipManifestDigest', nextMembershipManifestDigest)
          ..add('envelope', envelope)
          ..add('nextRecoveryCapsuleVersion', nextRecoveryCapsuleVersion)
          ..add('nextRecoveryCapsule', nextRecoveryCapsule)
          ..add('completionSessionId', completionSessionId)
          ..add('completionSessionToken', completionSessionToken))
        .toString();
  }
}

class AccountRecoveryReplacementCommitRequestBuilder
    implements
        Builder<
          AccountRecoveryReplacementCommitRequest,
          AccountRecoveryReplacementCommitRequestBuilder
        > {
  _$AccountRecoveryReplacementCommitRequest? _$v;

  int? _protocolVersion;
  int? get protocolVersion => _$this._protocolVersion;
  set protocolVersion(int? protocolVersion) =>
      _$this._protocolVersion = protocolVersion;

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

  String? _operationId;
  String? get operationId => _$this._operationId;
  set operationId(String? operationId) => _$this._operationId = operationId;

  String? _nextMembershipManifest;
  String? get nextMembershipManifest => _$this._nextMembershipManifest;
  set nextMembershipManifest(String? nextMembershipManifest) =>
      _$this._nextMembershipManifest = nextMembershipManifest;

  String? _nextMembershipManifestDigest;
  String? get nextMembershipManifestDigest =>
      _$this._nextMembershipManifestDigest;
  set nextMembershipManifestDigest(String? nextMembershipManifestDigest) =>
      _$this._nextMembershipManifestDigest = nextMembershipManifestDigest;

  AccountRecoveryResumeCommitRequestEnvelopeBuilder? _envelope;
  AccountRecoveryResumeCommitRequestEnvelopeBuilder get envelope =>
      _$this._envelope ??= AccountRecoveryResumeCommitRequestEnvelopeBuilder();
  set envelope(AccountRecoveryResumeCommitRequestEnvelopeBuilder? envelope) =>
      _$this._envelope = envelope;

  int? _nextRecoveryCapsuleVersion;
  int? get nextRecoveryCapsuleVersion => _$this._nextRecoveryCapsuleVersion;
  set nextRecoveryCapsuleVersion(int? nextRecoveryCapsuleVersion) =>
      _$this._nextRecoveryCapsuleVersion = nextRecoveryCapsuleVersion;

  String? _nextRecoveryCapsule;
  String? get nextRecoveryCapsule => _$this._nextRecoveryCapsule;
  set nextRecoveryCapsule(String? nextRecoveryCapsule) =>
      _$this._nextRecoveryCapsule = nextRecoveryCapsule;

  String? _completionSessionId;
  String? get completionSessionId => _$this._completionSessionId;
  set completionSessionId(String? completionSessionId) =>
      _$this._completionSessionId = completionSessionId;

  String? _completionSessionToken;
  String? get completionSessionToken => _$this._completionSessionToken;
  set completionSessionToken(String? completionSessionToken) =>
      _$this._completionSessionToken = completionSessionToken;

  AccountRecoveryReplacementCommitRequestBuilder() {
    AccountRecoveryReplacementCommitRequest._defaults(this);
  }

  AccountRecoveryReplacementCommitRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _protocolVersion = $v.protocolVersion;
      _expectedGeneration = $v.expectedGeneration;
      _expectedKeyEpoch = $v.expectedKeyEpoch;
      _expectedMembershipManifestDigest = $v.expectedMembershipManifestDigest;
      _operationId = $v.operationId;
      _nextMembershipManifest = $v.nextMembershipManifest;
      _nextMembershipManifestDigest = $v.nextMembershipManifestDigest;
      _envelope = $v.envelope.toBuilder();
      _nextRecoveryCapsuleVersion = $v.nextRecoveryCapsuleVersion;
      _nextRecoveryCapsule = $v.nextRecoveryCapsule;
      _completionSessionId = $v.completionSessionId;
      _completionSessionToken = $v.completionSessionToken;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AccountRecoveryReplacementCommitRequest other) {
    _$v = other as _$AccountRecoveryReplacementCommitRequest;
  }

  @override
  void update(
    void Function(AccountRecoveryReplacementCommitRequestBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  AccountRecoveryReplacementCommitRequest build() => _build();

  _$AccountRecoveryReplacementCommitRequest _build() {
    _$AccountRecoveryReplacementCommitRequest _$result;
    try {
      _$result =
          _$v ??
          _$AccountRecoveryReplacementCommitRequest._(
            protocolVersion: BuiltValueNullFieldError.checkNotNull(
              protocolVersion,
              r'AccountRecoveryReplacementCommitRequest',
              'protocolVersion',
            ),
            expectedGeneration: BuiltValueNullFieldError.checkNotNull(
              expectedGeneration,
              r'AccountRecoveryReplacementCommitRequest',
              'expectedGeneration',
            ),
            expectedKeyEpoch: BuiltValueNullFieldError.checkNotNull(
              expectedKeyEpoch,
              r'AccountRecoveryReplacementCommitRequest',
              'expectedKeyEpoch',
            ),
            expectedMembershipManifestDigest:
                BuiltValueNullFieldError.checkNotNull(
                  expectedMembershipManifestDigest,
                  r'AccountRecoveryReplacementCommitRequest',
                  'expectedMembershipManifestDigest',
                ),
            operationId: BuiltValueNullFieldError.checkNotNull(
              operationId,
              r'AccountRecoveryReplacementCommitRequest',
              'operationId',
            ),
            nextMembershipManifest: BuiltValueNullFieldError.checkNotNull(
              nextMembershipManifest,
              r'AccountRecoveryReplacementCommitRequest',
              'nextMembershipManifest',
            ),
            nextMembershipManifestDigest: BuiltValueNullFieldError.checkNotNull(
              nextMembershipManifestDigest,
              r'AccountRecoveryReplacementCommitRequest',
              'nextMembershipManifestDigest',
            ),
            envelope: envelope.build(),
            nextRecoveryCapsuleVersion: BuiltValueNullFieldError.checkNotNull(
              nextRecoveryCapsuleVersion,
              r'AccountRecoveryReplacementCommitRequest',
              'nextRecoveryCapsuleVersion',
            ),
            nextRecoveryCapsule: BuiltValueNullFieldError.checkNotNull(
              nextRecoveryCapsule,
              r'AccountRecoveryReplacementCommitRequest',
              'nextRecoveryCapsule',
            ),
            completionSessionId: BuiltValueNullFieldError.checkNotNull(
              completionSessionId,
              r'AccountRecoveryReplacementCommitRequest',
              'completionSessionId',
            ),
            completionSessionToken: BuiltValueNullFieldError.checkNotNull(
              completionSessionToken,
              r'AccountRecoveryReplacementCommitRequest',
              'completionSessionToken',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'envelope';
        envelope.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'AccountRecoveryReplacementCommitRequest',
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
