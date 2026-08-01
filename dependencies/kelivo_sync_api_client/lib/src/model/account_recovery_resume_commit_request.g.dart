// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_recovery_resume_commit_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AccountRecoveryResumeCommitRequest
    extends AccountRecoveryResumeCommitRequest {
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
  final String rekeyOperationId;

  factory _$AccountRecoveryResumeCommitRequest([
    void Function(AccountRecoveryResumeCommitRequestBuilder)? updates,
  ]) => (AccountRecoveryResumeCommitRequestBuilder()..update(updates))._build();

  _$AccountRecoveryResumeCommitRequest._({
    required this.protocolVersion,
    required this.expectedGeneration,
    required this.expectedKeyEpoch,
    required this.expectedMembershipManifestDigest,
    required this.operationId,
    required this.nextMembershipManifest,
    required this.nextMembershipManifestDigest,
    required this.envelope,
    required this.rekeyOperationId,
  }) : super._();
  @override
  AccountRecoveryResumeCommitRequest rebuild(
    void Function(AccountRecoveryResumeCommitRequestBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  AccountRecoveryResumeCommitRequestBuilder toBuilder() =>
      AccountRecoveryResumeCommitRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountRecoveryResumeCommitRequest &&
        protocolVersion == other.protocolVersion &&
        expectedGeneration == other.expectedGeneration &&
        expectedKeyEpoch == other.expectedKeyEpoch &&
        expectedMembershipManifestDigest ==
            other.expectedMembershipManifestDigest &&
        operationId == other.operationId &&
        nextMembershipManifest == other.nextMembershipManifest &&
        nextMembershipManifestDigest == other.nextMembershipManifestDigest &&
        envelope == other.envelope &&
        rekeyOperationId == other.rekeyOperationId;
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
    _$hash = $jc(_$hash, rekeyOperationId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AccountRecoveryResumeCommitRequest')
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
          ..add('rekeyOperationId', rekeyOperationId))
        .toString();
  }
}

class AccountRecoveryResumeCommitRequestBuilder
    implements
        Builder<
          AccountRecoveryResumeCommitRequest,
          AccountRecoveryResumeCommitRequestBuilder
        > {
  _$AccountRecoveryResumeCommitRequest? _$v;

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

  String? _rekeyOperationId;
  String? get rekeyOperationId => _$this._rekeyOperationId;
  set rekeyOperationId(String? rekeyOperationId) =>
      _$this._rekeyOperationId = rekeyOperationId;

  AccountRecoveryResumeCommitRequestBuilder() {
    AccountRecoveryResumeCommitRequest._defaults(this);
  }

  AccountRecoveryResumeCommitRequestBuilder get _$this {
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
      _rekeyOperationId = $v.rekeyOperationId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AccountRecoveryResumeCommitRequest other) {
    _$v = other as _$AccountRecoveryResumeCommitRequest;
  }

  @override
  void update(
    void Function(AccountRecoveryResumeCommitRequestBuilder)? updates,
  ) {
    if (updates != null) updates(this);
  }

  @override
  AccountRecoveryResumeCommitRequest build() => _build();

  _$AccountRecoveryResumeCommitRequest _build() {
    _$AccountRecoveryResumeCommitRequest _$result;
    try {
      _$result =
          _$v ??
          _$AccountRecoveryResumeCommitRequest._(
            protocolVersion: BuiltValueNullFieldError.checkNotNull(
              protocolVersion,
              r'AccountRecoveryResumeCommitRequest',
              'protocolVersion',
            ),
            expectedGeneration: BuiltValueNullFieldError.checkNotNull(
              expectedGeneration,
              r'AccountRecoveryResumeCommitRequest',
              'expectedGeneration',
            ),
            expectedKeyEpoch: BuiltValueNullFieldError.checkNotNull(
              expectedKeyEpoch,
              r'AccountRecoveryResumeCommitRequest',
              'expectedKeyEpoch',
            ),
            expectedMembershipManifestDigest:
                BuiltValueNullFieldError.checkNotNull(
                  expectedMembershipManifestDigest,
                  r'AccountRecoveryResumeCommitRequest',
                  'expectedMembershipManifestDigest',
                ),
            operationId: BuiltValueNullFieldError.checkNotNull(
              operationId,
              r'AccountRecoveryResumeCommitRequest',
              'operationId',
            ),
            nextMembershipManifest: BuiltValueNullFieldError.checkNotNull(
              nextMembershipManifest,
              r'AccountRecoveryResumeCommitRequest',
              'nextMembershipManifest',
            ),
            nextMembershipManifestDigest: BuiltValueNullFieldError.checkNotNull(
              nextMembershipManifestDigest,
              r'AccountRecoveryResumeCommitRequest',
              'nextMembershipManifestDigest',
            ),
            envelope: envelope.build(),
            rekeyOperationId: BuiltValueNullFieldError.checkNotNull(
              rekeyOperationId,
              r'AccountRecoveryResumeCommitRequest',
              'rekeyOperationId',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'envelope';
        envelope.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'AccountRecoveryResumeCommitRequest',
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
