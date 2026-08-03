part of '../kelivo_secure_core.dart';

const _accountRecoveryChallengeLength =
    native.KELIVO_ACCOUNT_RECOVERY_CHALLENGE_SIZE;
const _accountRecoveryReplacementChallengeLength =
    native.KELIVO_ACCOUNT_RECOVERY_REPLACEMENT_CHALLENGE_SIZE;
const _accountRecoverySealedNonceLength =
    native.KELIVO_ACCOUNT_RECOVERY_SEALED_NONCE_SIZE;
const _accountRecoveryTokenDigestLength =
    native.KELIVO_ACCOUNT_RECOVERY_TOKEN_DIGEST_SIZE;
const _accountRecoveryNonceProofLength =
    native.KELIVO_ACCOUNT_RECOVERY_NONCE_PROOF_SIZE;
const _accountRecoveryPreparedManifestMaximumLength =
    native.KELIVO_ACCOUNT_RECOVERY_PREPARED_MANIFEST_MAX_SIZE;
const kelivoAccountRecoveryContinuationLength =
    native.KELIVO_ACCOUNT_RECOVERY_CONTINUATION_SIZE;
const _maximumPositiveInt31 = 0x7fffffff;

enum KelivoAccountRecoveryDataPhase {
  ready(1),
  rekeyPending(2);

  const KelivoAccountRecoveryDataPhase(this.code);

  final int code;

  static KelivoAccountRecoveryDataPhase fromCode(int code) {
    for (final phase in values) {
      if (phase.code == code) return phase;
    }
    throw StateError('账户恢复执行返回了未知数据阶段：$code');
  }
}

enum KelivoAccountRecoveryCommitKind {
  resume(native.KELIVO_ACCOUNT_RECOVERY_PREPARE_KIND_RESUME),
  replacement(native.KELIVO_ACCOUNT_RECOVERY_PREPARE_KIND_REPLACEMENT);

  const KelivoAccountRecoveryCommitKind(this.code);

  final int code;
}

enum _AccountRecoveryExecutionPhase { open, busy, closing, closed }

final class _AccountRecoveryExecutionState {
  _AccountRecoveryExecutionState(this.value);

  final int value;
  _AccountRecoveryExecutionPhase phase = _AccountRecoveryExecutionPhase.open;

  int beginUse() {
    if (phase != _AccountRecoveryExecutionPhase.open) {
      throw StateError('账户恢复执行已占用、正在关闭或已经关闭');
    }
    phase = _AccountRecoveryExecutionPhase.busy;
    return value;
  }

  void completeUse() {
    if (phase != _AccountRecoveryExecutionPhase.busy) {
      throw StateError('账户恢复执行生命周期已失配');
    }
    phase = _AccountRecoveryExecutionPhase.open;
  }

  void invalidateUse() {
    if (phase != _AccountRecoveryExecutionPhase.busy) {
      throw StateError('账户恢复执行失效生命周期已失配');
    }
    phase = _AccountRecoveryExecutionPhase.closed;
  }

  int? beginClose() {
    if (phase == _AccountRecoveryExecutionPhase.closed) return null;
    if (phase != _AccountRecoveryExecutionPhase.open) {
      throw StateError('账户恢复执行已占用或正在关闭');
    }
    phase = _AccountRecoveryExecutionPhase.closing;
    return value;
  }

  void completeClose() {
    if (phase != _AccountRecoveryExecutionPhase.closing) {
      throw StateError('账户恢复执行关闭生命周期已失配');
    }
    phase = _AccountRecoveryExecutionPhase.closed;
  }

  void cancelClose() {
    if (phase == _AccountRecoveryExecutionPhase.closing) {
      phase = _AccountRecoveryExecutionPhase.open;
    }
  }
}

final class KelivoAccountRecoveryExecution {
  KelivoAccountRecoveryExecution._({
    required int handle,
    required this._replacementOnly,
    required this.dataPhase,
    required Uint8List userId,
    required Uint8List deviceId,
    required this.securityGeneration,
    required this.keyEpoch,
    required this.deviceKeyVersion,
    required this.targetAuthGeneration,
    required this.recoveryCapsuleVersion,
    required this.sourceDataGeneration,
    required this.sourceDataKeyEpoch,
    required Uint8List sourceDataRekeyOperationId,
    required Uint8List operationAuthorizationDigest,
  }) : _state = _AccountRecoveryExecutionState(handle),
       userId = _immutableDeviceBytes(userId),
       deviceId = _immutableDeviceBytes(deviceId),
       _sourceDataRekeyOperationId = _immutableDeviceBytes(
         sourceDataRekeyOperationId,
       ),
       _operationAuthorizationDigest = _immutableDeviceBytes(
         operationAuthorizationDigest,
       );

  final _AccountRecoveryExecutionState _state;
  final bool _replacementOnly;
  final KelivoAccountRecoveryDataPhase dataPhase;
  final Uint8List userId;
  final Uint8List deviceId;
  final int securityGeneration;
  final int keyEpoch;
  final int deviceKeyVersion;
  final int targetAuthGeneration;
  final int recoveryCapsuleVersion;
  final int sourceDataGeneration;
  final int sourceDataKeyEpoch;
  final Uint8List _sourceDataRekeyOperationId;
  final Uint8List _operationAuthorizationDigest;

  @override
  String toString() => 'KelivoAccountRecoveryExecution(opaque)';
}

final class KelivoPreparedAccountRecoveryStateBinding {
  factory KelivoPreparedAccountRecoveryStateBinding({
    required KelivoAccountRecoveryCommitKind kind,
    required KelivoAccountRecoveryDataPhase dataPhase,
    required int deviceKeyVersion,
    required Uint8List userId,
    required Uint8List deviceId,
    required int sourceKeyEpoch,
    required int targetKeyEpoch,
    required int sourceDataGeneration,
    required int targetDataGeneration,
    required int membershipGeneration,
    required Uint8List membershipManifestDigest,
    required Uint8List rekeyOperationId,
    required Uint8List operationAuthorizationDigest,
  }) {
    _validatePositiveUint32(deviceKeyVersion, 'deviceKeyVersion');
    _validateUuidV4(userId, 'userId');
    _validateUuidV4(deviceId, 'deviceId');
    _validatePositiveUint32(sourceKeyEpoch, 'sourceKeyEpoch');
    _validatePositiveUint32(targetKeyEpoch, 'targetKeyEpoch');
    if (sourceKeyEpoch == _maxUint32 || targetKeyEpoch != sourceKeyEpoch + 1) {
      throw ArgumentError.value(
        targetKeyEpoch,
        'targetKeyEpoch',
        '必须紧邻 sourceKeyEpoch',
      );
    }
    _validatePositiveInt31(sourceDataGeneration, 'sourceDataGeneration');
    _validatePositiveInt31(targetDataGeneration, 'targetDataGeneration');
    if (sourceDataGeneration == _maximumPositiveInt31 ||
        targetDataGeneration != sourceDataGeneration + 1) {
      throw ArgumentError.value(
        targetDataGeneration,
        'targetDataGeneration',
        '必须紧邻 sourceDataGeneration',
      );
    }
    _validatePositiveInt31(membershipGeneration, 'membershipGeneration');
    _requireLength(
      membershipManifestDigest,
      _accountRecoveryTokenDigestLength,
      'membershipManifestDigest',
    );
    _validateUuidV4(rekeyOperationId, 'rekeyOperationId');
    _requireLength(
      operationAuthorizationDigest,
      _accountRecoveryTokenDigestLength,
      'operationAuthorizationDigest',
    );
    if ((kind == KelivoAccountRecoveryCommitKind.resume) !=
        (dataPhase == KelivoAccountRecoveryDataPhase.rekeyPending)) {
      throw ArgumentError('恢复提交类型与数据阶段不一致');
    }
    if (kind == KelivoAccountRecoveryCommitKind.replacement &&
        operationAuthorizationDigest.any((byte) => byte != 0)) {
      throw ArgumentError.value(
        operationAuthorizationDigest,
        'operationAuthorizationDigest',
        'replacement 必须使用零摘要',
      );
    }
    return KelivoPreparedAccountRecoveryStateBinding._(
      kind: kind,
      dataPhase: dataPhase,
      deviceKeyVersion: deviceKeyVersion,
      userId: _immutableDeviceBytes(userId),
      deviceId: _immutableDeviceBytes(deviceId),
      sourceKeyEpoch: sourceKeyEpoch,
      targetKeyEpoch: targetKeyEpoch,
      sourceDataGeneration: sourceDataGeneration,
      targetDataGeneration: targetDataGeneration,
      membershipGeneration: membershipGeneration,
      membershipManifestDigest: _immutableDeviceBytes(membershipManifestDigest),
      rekeyOperationId: _immutableDeviceBytes(rekeyOperationId),
      operationAuthorizationDigest: _immutableDeviceBytes(
        operationAuthorizationDigest,
      ),
    );
  }

  const KelivoPreparedAccountRecoveryStateBinding._({
    required this.kind,
    required this.dataPhase,
    required this.deviceKeyVersion,
    required this.userId,
    required this.deviceId,
    required this.sourceKeyEpoch,
    required this.targetKeyEpoch,
    required this.sourceDataGeneration,
    required this.targetDataGeneration,
    required this.membershipGeneration,
    required this.membershipManifestDigest,
    required this.rekeyOperationId,
    required this.operationAuthorizationDigest,
  });

  final KelivoAccountRecoveryCommitKind kind;
  final KelivoAccountRecoveryDataPhase dataPhase;
  final int deviceKeyVersion;
  final Uint8List userId;
  final Uint8List deviceId;
  final int sourceKeyEpoch;
  final int targetKeyEpoch;
  final int sourceDataGeneration;
  final int targetDataGeneration;
  final int membershipGeneration;
  final Uint8List membershipManifestDigest;
  final Uint8List rekeyOperationId;
  final Uint8List operationAuthorizationDigest;
}

final class KelivoPreparedAccountRecoveryDeviceStates {
  KelivoPreparedAccountRecoveryDeviceStates._({
    required Uint8List unprunedStateBlob,
    required Uint8List prunedCandidate,
    required Uint8List ownedContinuation,
  }) : unprunedStateBlob = _immutableDeviceBytes(unprunedStateBlob),
       prunedCandidate = _immutableDeviceBytes(prunedCandidate),
       _continuation = ownedContinuation;

  final Uint8List unprunedStateBlob;
  final Uint8List prunedCandidate;
  Uint8List? _continuation;

  Uint8List takeContinuation() {
    final continuation = _continuation;
    if (continuation == null) {
      throw StateError('账户恢复 continuation 已被消费');
    }
    _continuation = null;
    return continuation;
  }

  void dispose() {
    final continuation = _continuation;
    continuation?.fillRange(0, continuation.length, 0);
    _continuation = null;
  }
}

final class KelivoAccountRecoveryProof {
  KelivoAccountRecoveryProof._({
    required this.execution,
    required Uint8List nonceProof,
    required Uint8List trustSignature,
  }) : nonceProof = _immutableDeviceBytes(nonceProof),
       trustSignature = _immutableDeviceBytes(trustSignature);

  final KelivoAccountRecoveryExecution execution;
  final Uint8List nonceProof;
  final Uint8List trustSignature;
}

final class KelivoAccountRecoveryReplacementProof {
  KelivoAccountRecoveryReplacementProof._({
    required this.execution,
    required Uint8List challengeId,
    required Uint8List attemptId,
    required Uint8List membershipOperationId,
    required Uint8List membershipManifestDigest,
    required Uint8List sourceDataRekeyOperationId,
    required Uint8List completionProofDigest,
    required Uint8List requestDigest,
    required Uint8List nonceProof,
    required Uint8List trustSignature,
  }) : challengeId = _immutableDeviceBytes(challengeId),
       attemptId = _immutableDeviceBytes(attemptId),
       membershipOperationId = _immutableDeviceBytes(membershipOperationId),
       membershipManifestDigest = _immutableDeviceBytes(
         membershipManifestDigest,
       ),
       sourceDataRekeyOperationId = _immutableDeviceBytes(
         sourceDataRekeyOperationId,
       ),
       completionProofDigest = _immutableDeviceBytes(completionProofDigest),
       requestDigest = _immutableDeviceBytes(requestDigest),
       nonceProof = _immutableDeviceBytes(nonceProof),
       trustSignature = _immutableDeviceBytes(trustSignature);

  final KelivoAccountRecoveryExecution execution;
  final Uint8List challengeId;
  final Uint8List attemptId;
  final Uint8List membershipOperationId;
  final Uint8List membershipManifestDigest;
  final Uint8List sourceDataRekeyOperationId;
  final Uint8List completionProofDigest;
  final Uint8List requestDigest;
  final Uint8List nonceProof;
  final Uint8List trustSignature;
}

final class KelivoPreparedAccountRecoveryCommit {
  KelivoPreparedAccountRecoveryCommit._({
    required this.kind,
    required this.expectedGeneration,
    required this.expectedKeyEpoch,
    required this.nextGeneration,
    required this.nextKeyEpoch,
    required this.nextRecoveryCapsuleVersion,
    required Uint8List manifestDigest,
    required Uint8List requestDigest,
    required Uint8List membershipManifest,
    required Uint8List accountKeyEnvelope,
    required Uint8List? recoveryCapsule,
    required this.stateBinding,
  }) : manifestDigest = _immutableDeviceBytes(manifestDigest),
       requestDigest = _immutableDeviceBytes(requestDigest),
       membershipManifest = _immutableDeviceBytes(membershipManifest),
       accountKeyEnvelope = _immutableDeviceBytes(accountKeyEnvelope),
       recoveryCapsule = recoveryCapsule == null
           ? null
           : _immutableDeviceBytes(recoveryCapsule);

  final KelivoAccountRecoveryCommitKind kind;
  final int expectedGeneration;
  final int expectedKeyEpoch;
  final int nextGeneration;
  final int nextKeyEpoch;
  final int nextRecoveryCapsuleVersion;
  final Uint8List manifestDigest;
  final Uint8List requestDigest;
  final Uint8List membershipManifest;
  final Uint8List accountKeyEnvelope;
  final Uint8List? recoveryCapsule;
  final KelivoPreparedAccountRecoveryStateBinding stateBinding;
}

extension KelivoAccountRecoveryCore on KelivoSecureCore {
  Future<KelivoAccountRecoveryProof> verifyAccountRecoveryAndCreateProof(
    KelivoDeviceIdentityHandle deviceIdentity, {
    required int expectedDeviceKeyVersion,
    required int expectedDeviceAuthGeneration,
    required Uint8List media,
    required Uint8List passphrase,
    required Uint8List serviceOriginSha256,
    required List<Uint8List> membershipHistory,
    required Uint8List currentCapsule,
    Uint8List? sourceCapsule,
    required Uint8List challengeFrame,
    required Uint8List sealedNonce,
    required Uint8List recoveryTokenDigest,
    required Uint8List expectedAttemptId,
    required Uint8List expectedDeviceId,
    required Uint8List expectedRequestDigest,
    required DateTime expectedExpiresAt,
  }) async {
    try {
      _validatePositiveUint32(
        expectedDeviceKeyVersion,
        'expectedDeviceKeyVersion',
      );
      _validatePositiveInt31(
        expectedDeviceAuthGeneration,
        'expectedDeviceAuthGeneration',
      );
      _requireLength(media, _recoveryMediaLength, 'media');
      _validateRecoveryPassphrase(passphrase);
      _requireLength(
        serviceOriginSha256,
        _recoveryOriginDigestLength,
        'serviceOriginSha256',
      );
      _requireLength(currentCapsule, _recoveryCapsuleLength, 'currentCapsule');
      if (sourceCapsule != null) {
        _requireLength(sourceCapsule, _recoveryCapsuleLength, 'sourceCapsule');
      }
      _requireLength(
        challengeFrame,
        _accountRecoveryChallengeLength,
        'challengeFrame',
      );
      _requireLength(
        sealedNonce,
        _accountRecoverySealedNonceLength,
        'sealedNonce',
      );
      _requireLength(
        recoveryTokenDigest,
        _accountRecoveryTokenDigestLength,
        'recoveryTokenDigest',
      );
      _validateUuidV4(expectedAttemptId, 'expectedAttemptId');
      _validateUuidV4(expectedDeviceId, 'expectedDeviceId');
      _requireLength(
        expectedRequestDigest,
        _accountRecoveryTokenDigestLength,
        'expectedRequestDigest',
      );
      final expectedExpiresAtMs = expectedExpiresAt
          .toUtc()
          .millisecondsSinceEpoch;
      _validateTimestamp(expectedExpiresAtMs, 'expectedExpiresAt');
      final history = _transferRecoveryHistory(membershipHistory);
      final identityHandle = deviceIdentity._state.beginUse();
      try {
        final result = await _runWithTransferredPassword(passphrase, (
          workerPassphrase,
        ) {
          final workerHistory = history.materialize().asUint8List();
          return _verifyAccountRecoveryAndCreateProof(
            identityHandle,
            expectedDeviceKeyVersion,
            expectedDeviceAuthGeneration,
            Uint8List.fromList(media),
            workerPassphrase,
            Uint8List.fromList(serviceOriginSha256),
            workerHistory,
            sourceCapsule == null ? null : Uint8List.fromList(sourceCapsule),
            Uint8List.fromList(currentCapsule),
            Uint8List.fromList(challengeFrame),
            Uint8List.fromList(sealedNonce),
            Uint8List.fromList(recoveryTokenDigest),
            Uint8List.fromList(expectedAttemptId),
            Uint8List.fromList(expectedDeviceId),
            Uint8List.fromList(expectedRequestDigest),
            expectedExpiresAtMs,
          );
        });
        return KelivoAccountRecoveryProof._(
          execution: KelivoAccountRecoveryExecution._(
            handle: result.executionHandle,
            replacementOnly: false,
            dataPhase: KelivoAccountRecoveryDataPhase.fromCode(
              result.dataPhase,
            ),
            userId: result.userId,
            deviceId: result.deviceId,
            securityGeneration: result.securityGeneration,
            keyEpoch: result.keyEpoch,
            deviceKeyVersion: result.deviceKeyVersion,
            targetAuthGeneration: expectedDeviceAuthGeneration,
            recoveryCapsuleVersion: result.recoveryCapsuleVersion,
            sourceDataGeneration: result.sourceDataGeneration,
            sourceDataKeyEpoch: result.sourceDataKeyEpoch,
            sourceDataRekeyOperationId: result.sourceDataRekeyOperationId,
            operationAuthorizationDigest: result.operationAuthorizationDigest,
          ),
          nonceProof: result.nonceProof,
          trustSignature: result.trustSignature,
        );
      } finally {
        deviceIdentity._state.completeUse();
      }
    } finally {
      passphrase.fillRange(0, passphrase.length, 0);
    }
  }

  Future<KelivoAccountRecoveryReplacementProof>
  verifyAccountRecoveryReplacementChallengeAndCreateProof(
    KelivoDeviceIdentityHandle deviceIdentity, {
    required int expectedDeviceKeyVersion,
    required int expectedDeviceAuthGeneration,
    required Uint8List media,
    required Uint8List passphrase,
    required Uint8List serviceOriginSha256,
    required List<Uint8List> membershipHistory,
    required Uint8List currentCapsule,
    required Uint8List sourceCapsule,
    required Uint8List challengeFrame,
    required Uint8List sealedNonce,
    required Uint8List completionProofFrame,
    required KelivoDataRekeyCompletionProofSignature completionProofSignature,
    required Uint8List recoveryTokenDigest,
    required Uint8List expectedChallengeId,
    required Uint8List expectedAttemptId,
    required Uint8List expectedDeviceId,
    required DateTime expectedExpiresAt,
  }) async {
    try {
      _validatePositiveUint32(
        expectedDeviceKeyVersion,
        'expectedDeviceKeyVersion',
      );
      _validatePositiveInt31(
        expectedDeviceAuthGeneration,
        'expectedDeviceAuthGeneration',
      );
      _requireLength(media, _recoveryMediaLength, 'media');
      _validateRecoveryPassphrase(passphrase);
      _requireLength(
        serviceOriginSha256,
        _recoveryOriginDigestLength,
        'serviceOriginSha256',
      );
      _requireLength(currentCapsule, _recoveryCapsuleLength, 'currentCapsule');
      _requireLength(sourceCapsule, _recoveryCapsuleLength, 'sourceCapsule');
      _requireLength(
        challengeFrame,
        _accountRecoveryReplacementChallengeLength,
        'challengeFrame',
      );
      _requireLength(
        sealedNonce,
        _accountRecoverySealedNonceLength,
        'sealedNonce',
      );
      _requireLength(
        completionProofFrame,
        _dataRekeyCompletionProofFrameLength,
        'completionProofFrame',
      );
      _requireLength(
        recoveryTokenDigest,
        _accountRecoveryTokenDigestLength,
        'recoveryTokenDigest',
      );
      _validateUuidV4(expectedChallengeId, 'expectedChallengeId');
      _validateUuidV4(expectedAttemptId, 'expectedAttemptId');
      _validateUuidV4(expectedDeviceId, 'expectedDeviceId');
      final expectedExpiresAtMs = expectedExpiresAt
          .toUtc()
          .millisecondsSinceEpoch;
      _validateTimestamp(expectedExpiresAtMs, 'expectedExpiresAt');
      final history = _transferRecoveryHistory(membershipHistory);
      final identityHandle = deviceIdentity._state.beginUse();
      try {
        final result = await _runWithTransferredPassword(passphrase, (
          workerPassphrase,
        ) {
          return _verifyAccountRecoveryReplacementChallengeAndCreateProof(
            identityHandle,
            expectedDeviceKeyVersion,
            expectedDeviceAuthGeneration,
            Uint8List.fromList(media),
            workerPassphrase,
            Uint8List.fromList(serviceOriginSha256),
            history.materialize().asUint8List(),
            Uint8List.fromList(sourceCapsule),
            Uint8List.fromList(currentCapsule),
            Uint8List.fromList(challengeFrame),
            Uint8List.fromList(sealedNonce),
            Uint8List.fromList(completionProofFrame),
            Uint8List.fromList(completionProofSignature.bytes),
            Uint8List.fromList(recoveryTokenDigest),
            Uint8List.fromList(expectedChallengeId),
            Uint8List.fromList(expectedAttemptId),
            Uint8List.fromList(expectedDeviceId),
            expectedExpiresAtMs,
          );
        });
        return KelivoAccountRecoveryReplacementProof._(
          execution: KelivoAccountRecoveryExecution._(
            handle: result.executionHandle,
            replacementOnly: true,
            dataPhase: KelivoAccountRecoveryDataPhase.ready,
            userId: result.userId,
            deviceId: result.deviceId,
            securityGeneration: result.securityGeneration,
            keyEpoch: result.keyEpoch,
            deviceKeyVersion: result.deviceKeyVersion,
            targetAuthGeneration: expectedDeviceAuthGeneration,
            recoveryCapsuleVersion: result.recoveryCapsuleVersion,
            sourceDataGeneration: result.readyDataGeneration,
            sourceDataKeyEpoch: result.readyDataKeyEpoch,
            sourceDataRekeyOperationId: result.sourceDataRekeyOperationId,
            operationAuthorizationDigest: Uint8List(
              _accountRecoveryTokenDigestLength,
            ),
          ),
          challengeId: result.challengeId,
          attemptId: result.attemptId,
          membershipOperationId: result.membershipOperationId,
          membershipManifestDigest: result.membershipManifestDigest,
          sourceDataRekeyOperationId: result.sourceDataRekeyOperationId,
          completionProofDigest: result.completionProofDigest,
          requestDigest: result.requestDigest,
          nonceProof: result.nonceProof,
          trustSignature: result.trustSignature,
        );
      } finally {
        deviceIdentity._state.completeUse();
      }
    } finally {
      passphrase.fillRange(0, passphrase.length, 0);
    }
  }

  Future<KelivoPreparedAccountRecoveryCommit> prepareAccountRecoveryResume(
    KelivoAccountRecoveryExecution execution, {
    required Uint8List operationId,
    required Uint8List rekeyOperationId,
  }) {
    _validateUuidV4(operationId, 'operationId');
    _validateUuidV4(rekeyOperationId, 'rekeyOperationId');
    return _prepareAccountRecovery(
      execution,
      kind: KelivoAccountRecoveryCommitKind.resume,
      operationId: Uint8List.fromList(operationId),
      rekeyOperationId: Uint8List.fromList(rekeyOperationId),
      completionSessionId: Uint8List(_deviceUuidLength),
      completionSessionTokenDigest: Uint8List(
        _accountRecoveryTokenDigestLength,
      ),
    );
  }

  Future<KelivoPreparedAccountRecoveryCommit> prepareAccountRecoveryReplacement(
    KelivoAccountRecoveryExecution execution, {
    required Uint8List operationId,
    required Uint8List completionSessionId,
    required Uint8List completionSessionTokenDigest,
  }) {
    _validateUuidV4(operationId, 'operationId');
    _validateUuidV4(completionSessionId, 'completionSessionId');
    _requireLength(
      completionSessionTokenDigest,
      _accountRecoveryTokenDigestLength,
      'completionSessionTokenDigest',
    );
    return _prepareAccountRecovery(
      execution,
      kind: KelivoAccountRecoveryCommitKind.replacement,
      operationId: Uint8List.fromList(operationId),
      rekeyOperationId: Uint8List(_deviceUuidLength),
      completionSessionId: Uint8List.fromList(completionSessionId),
      completionSessionTokenDigest: Uint8List.fromList(
        completionSessionTokenDigest,
      ),
    );
  }

  Future<KelivoPreparedAccountRecoveryCommit> _prepareAccountRecovery(
    KelivoAccountRecoveryExecution execution, {
    required KelivoAccountRecoveryCommitKind kind,
    required Uint8List operationId,
    required Uint8List rekeyOperationId,
    required Uint8List completionSessionId,
    required Uint8List completionSessionTokenDigest,
  }) async {
    final handle = execution._state.beginUse();
    try {
      final result = await Isolate.run(
        () => _prepareAccountRecoveryCommit(
          handle,
          kind,
          execution.targetAuthGeneration,
          operationId,
          rekeyOperationId,
          completionSessionId,
          completionSessionTokenDigest,
          execution.securityGeneration,
          execution.keyEpoch,
          execution.recoveryCapsuleVersion,
          execution.dataPhase,
          execution.deviceKeyVersion,
          Uint8List.fromList(execution.userId),
          Uint8List.fromList(execution.deviceId),
          execution.sourceDataGeneration,
          execution.sourceDataKeyEpoch,
          Uint8List.fromList(execution._operationAuthorizationDigest),
        ),
      );
      execution._state.completeUse();
      return result;
    } on KelivoSecureCoreException catch (error) {
      if (error.status == KelivoSecureCoreStatus.recoveryPrepareInvalid ||
          error.status ==
              KelivoSecureCoreStatus.invalidRecoveryExecutionHandle) {
        execution._state.invalidateUse();
      } else {
        execution._state.completeUse();
      }
      rethrow;
    } catch (_) {
      execution._state.completeUse();
      rethrow;
    }
  }

  Future<KelivoPreparedAccountRecoveryDeviceStates>
  prepareAccountRecoveryDeviceStates(
    KelivoAccountRecoveryExecution execution,
    KelivoKeyHandle key,
    KelivoPreparedAccountRecoveryCommit prepared,
  ) async {
    final binding = prepared.stateBinding;
    _requireExecutionStateBinding(execution, binding);
    final executionHandle = execution._state.beginUse();
    int keyHandle;
    try {
      keyHandle = key._beginUse();
    } catch (_) {
      execution._state.completeUse();
      rethrow;
    }
    try {
      final result = await Isolate.run(
        () => _prepareAccountRecoveryDeviceStates(
          executionHandle,
          keyHandle,
          binding,
        ),
      );
      execution._state.completeUse();
      return result;
    } on KelivoSecureCoreException catch (error) {
      if (error.status ==
          KelivoSecureCoreStatus.invalidRecoveryExecutionHandle) {
        execution._state.invalidateUse();
      } else {
        execution._state.completeUse();
      }
      rethrow;
    } catch (_) {
      execution._state.completeUse();
      rethrow;
    } finally {
      key._completeUse();
    }
  }

  Future<Uint8List> activatePreparedAccountRecoveryDeviceState(
    KelivoKeyHandle key, {
    required Uint8List continuation,
    required KelivoPreparedAccountRecoveryStateBinding stateBinding,
    required Uint8List prunedCandidate,
    required Uint8List completionProofFrame,
    required KelivoDataRekeyCompletionProofSignature completionProofSignature,
    required Uint8List completionProofDigest,
  }) async {
    _requireLength(
      continuation,
      kelivoAccountRecoveryContinuationLength,
      'continuation',
    );
    _requireLength(prunedCandidate, _deviceStateBlobLength, 'prunedCandidate');
    _requireLength(
      completionProofFrame,
      _dataRekeyCompletionProofFrameLength,
      'completionProofFrame',
    );
    _requireLength(
      completionProofDigest,
      _accountRecoveryTokenDigestLength,
      'completionProofDigest',
    );
    final continuationBytes = Uint8List.fromList(continuation);
    final candidate = Uint8List.fromList(prunedCandidate);
    final frame = Uint8List.fromList(completionProofFrame);
    final signature = Uint8List.fromList(completionProofSignature.bytes);
    final proofDigest = Uint8List.fromList(completionProofDigest);
    var keyBorrowed = false;
    try {
      final keyHandle = key._beginUse();
      keyBorrowed = true;
      final activated = await Isolate.run(
        () => _activatePreparedAccountRecoveryDeviceState(
          keyHandle,
          continuationBytes,
          stateBinding,
          candidate,
          frame,
          signature,
          proofDigest,
        ),
      );
      if (!_sameAccountRecoveryBytes(activated, prunedCandidate)) {
        throw StateError('账户恢复激活未返回 checkpoint 中的精确候选状态');
      }
      return _immutableDeviceBytes(activated);
    } finally {
      if (keyBorrowed) key._completeUse();
      continuationBytes.fillRange(0, continuationBytes.length, 0);
      candidate.fillRange(0, candidate.length, 0);
      frame.fillRange(0, frame.length, 0);
      signature.fillRange(0, signature.length, 0);
      proofDigest.fillRange(0, proofDigest.length, 0);
    }
  }

  Future<void> closeAccountRecoveryExecution(
    KelivoAccountRecoveryExecution execution,
  ) async {
    final handle = execution._state.beginClose();
    if (handle == null) return;
    try {
      await Isolate.run(() {
        _throwOnError(
          operation: 'account_recovery_execution_close',
          statusCode: native.kelivo_account_recovery_execution_close(handle),
        );
      });
      execution._state.completeClose();
    } on KelivoSecureCoreException catch (error) {
      if (error.status ==
          KelivoSecureCoreStatus.invalidRecoveryExecutionHandle) {
        execution._state.completeClose();
        return;
      }
      execution._state.cancelClose();
      rethrow;
    } catch (_) {
      execution._state.cancelClose();
      rethrow;
    }
  }
}

final class _AccountRecoveryProofNativeResult {
  const _AccountRecoveryProofNativeResult({
    required this.executionHandle,
    required this.dataPhase,
    required this.userId,
    required this.deviceId,
    required this.securityGeneration,
    required this.keyEpoch,
    required this.deviceKeyVersion,
    required this.recoveryCapsuleVersion,
    required this.sourceDataGeneration,
    required this.sourceDataKeyEpoch,
    required this.sourceDataRekeyOperationId,
    required this.operationAuthorizationDigest,
    required this.nonceProof,
    required this.trustSignature,
  });

  final int executionHandle;
  final int dataPhase;
  final Uint8List userId;
  final Uint8List deviceId;
  final int securityGeneration;
  final int keyEpoch;
  final int deviceKeyVersion;
  final int recoveryCapsuleVersion;
  final int sourceDataGeneration;
  final int sourceDataKeyEpoch;
  final Uint8List sourceDataRekeyOperationId;
  final Uint8List operationAuthorizationDigest;
  final Uint8List nonceProof;
  final Uint8List trustSignature;
}

final class _AccountRecoveryReplacementProofNativeResult {
  const _AccountRecoveryReplacementProofNativeResult({
    required this.executionHandle,
    required this.challengeId,
    required this.attemptId,
    required this.userId,
    required this.deviceId,
    required this.securityGeneration,
    required this.keyEpoch,
    required this.membershipOperationId,
    required this.membershipManifestDigest,
    required this.deviceKeyVersion,
    required this.recoveryCapsuleVersion,
    required this.sourceDataRekeyOperationId,
    required this.readyDataGeneration,
    required this.readyDataKeyEpoch,
    required this.completionProofDigest,
    required this.requestDigest,
    required this.nonceProof,
    required this.trustSignature,
  });

  final int executionHandle;
  final Uint8List challengeId;
  final Uint8List attemptId;
  final Uint8List userId;
  final Uint8List deviceId;
  final int securityGeneration;
  final int keyEpoch;
  final Uint8List membershipOperationId;
  final Uint8List membershipManifestDigest;
  final int deviceKeyVersion;
  final int recoveryCapsuleVersion;
  final Uint8List sourceDataRekeyOperationId;
  final int readyDataGeneration;
  final int readyDataKeyEpoch;
  final Uint8List completionProofDigest;
  final Uint8List requestDigest;
  final Uint8List nonceProof;
  final Uint8List trustSignature;
}

@pragma('vm:never-inline')
_AccountRecoveryReplacementProofNativeResult
_verifyAccountRecoveryReplacementChallengeAndCreateProof(
  int identityHandle,
  int expectedDeviceKeyVersion,
  int expectedDeviceAuthGeneration,
  Uint8List media,
  Uint8List passphrase,
  Uint8List origin,
  Uint8List history,
  Uint8List sourceCapsule,
  Uint8List currentCapsule,
  Uint8List challenge,
  Uint8List sealedNonce,
  Uint8List completionProofFrame,
  Uint8List completionProofSignature,
  Uint8List recoveryTokenDigest,
  Uint8List expectedChallengeId,
  Uint8List expectedAttemptId,
  Uint8List expectedDeviceId,
  int expectedExpiresAtMs,
) {
  final mediaPointer = _copyToNative(media);
  final originPointer = _copyToNative(origin);
  final historyPointer = _copyToNative(history);
  final sourceCapsulePointer = _copyToNative(sourceCapsule);
  final currentCapsulePointer = _copyToNative(currentCapsule);
  final challengePointer = _copyToNative(challenge);
  final sealedNoncePointer = _copyToNative(sealedNonce);
  final completionProofFramePointer = _copyToNative(completionProofFrame);
  final completionProofSignaturePointer = _copyToNative(
    completionProofSignature,
  );
  final recoveryTokenDigestPointer = _copyToNative(recoveryTokenDigest);
  final expectedChallengeIdPointer = _copyToNative(expectedChallengeId);
  final expectedAttemptIdPointer = _copyToNative(expectedAttemptId);
  final expectedDeviceIdPointer = _copyToNative(expectedDeviceId);
  final outputBinding =
      calloc<native.KelivoAccountRecoveryReplacementProofBinding>();
  final outputNonceProof = calloc<ffi.Uint8>(_accountRecoveryNonceProofLength);
  final outputNonceProofLength = calloc<ffi.Size>();
  final outputTrustSignature = calloc<ffi.Uint8>(_accountTrustSignatureLength);
  final outputTrustSignatureLength = calloc<ffi.Size>();
  var passphrasePointer = ffi.nullptr.cast<ffi.Uint8>();
  var published = false;
  try {
    passphrasePointer = _copyToNative(passphrase);
    _throwOnError(
      operation: 'account_recovery_replacement_challenge_verify_and_prove',
      statusCode: native
          .kelivo_account_recovery_replacement_challenge_verify_and_prove(
            identityHandle,
            expectedDeviceKeyVersion,
            expectedDeviceAuthGeneration,
            mediaPointer,
            media.length,
            passphrasePointer,
            passphrase.length,
            originPointer,
            origin.length,
            historyPointer,
            history.length,
            sourceCapsulePointer,
            sourceCapsule.length,
            currentCapsulePointer,
            currentCapsule.length,
            challengePointer,
            challenge.length,
            sealedNoncePointer,
            sealedNonce.length,
            completionProofFramePointer,
            completionProofFrame.length,
            completionProofSignaturePointer,
            completionProofSignature.length,
            recoveryTokenDigestPointer,
            recoveryTokenDigest.length,
            expectedChallengeIdPointer,
            expectedChallengeId.length,
            expectedAttemptIdPointer,
            expectedAttemptId.length,
            expectedDeviceIdPointer,
            expectedDeviceId.length,
            expectedExpiresAtMs,
            outputBinding,
            outputNonceProof,
            _accountRecoveryNonceProofLength,
            outputNonceProofLength,
            outputTrustSignature,
            _accountTrustSignatureLength,
            outputTrustSignatureLength,
          ),
    );
    _requireExactOutputLength(
      operation:
          'account_recovery_replacement_challenge_verify_and_prove_nonce_proof',
      expected: _accountRecoveryNonceProofLength,
      actual: outputNonceProofLength.value,
    );
    _requireExactOutputLength(
      operation:
          'account_recovery_replacement_challenge_verify_and_prove_trust_signature',
      expected: _accountTrustSignatureLength,
      actual: outputTrustSignatureLength.value,
    );
    final binding = outputBinding.ref;
    if (binding.struct_size !=
            native
                .KELIVO_ACCOUNT_RECOVERY_REPLACEMENT_PROOF_BINDING_STRUCT_SIZE ||
        binding.reserved != 0) {
      throw StateError('账户恢复替换证明返回了未知绑定结构');
    }
    if (binding.execution_handle ==
        native.KELIVO_ACCOUNT_RECOVERY_INVALID_EXECUTION_HANDLE) {
      throw StateError('账户恢复替换证明成功但未发布有效执行句柄');
    }
    final challengeId = _copyNativeByteArray(
      binding.challenge_id,
      _deviceUuidLength,
    );
    final attemptId = _copyNativeByteArray(
      binding.attempt_id,
      _deviceUuidLength,
    );
    final userId = _copyNativeByteArray(binding.user_id, _deviceUuidLength);
    final deviceId = _copyNativeByteArray(binding.device_id, _deviceUuidLength);
    final membershipOperationId = _copyNativeByteArray(
      binding.membership_operation_id,
      _deviceUuidLength,
    );
    final sourceDataRekeyOperationId = _copyNativeByteArray(
      binding.source_data_rekey_operation_id,
      _deviceUuidLength,
    );
    for (final entry in <(Uint8List, String)>[
      (challengeId, 'challengeId'),
      (attemptId, 'attemptId'),
      (userId, 'userId'),
      (deviceId, 'deviceId'),
      (membershipOperationId, 'membershipOperationId'),
      (sourceDataRekeyOperationId, 'sourceDataRekeyOperationId'),
    ]) {
      _validateUuidV4(entry.$1, entry.$2);
    }
    if (!_sameAccountRecoveryBytes(challengeId, expectedChallengeId) ||
        !_sameAccountRecoveryBytes(attemptId, expectedAttemptId) ||
        !_sameAccountRecoveryBytes(deviceId, expectedDeviceId)) {
      throw StateError('账户恢复替换证明返回的挑战或设备绑定不一致');
    }
    _validatePositiveInt31(binding.security_generation, 'securityGeneration');
    _validatePositiveUint32(binding.key_epoch, 'keyEpoch');
    _validatePositiveUint32(binding.device_key_version, 'deviceKeyVersion');
    _validatePositiveInt31(
      binding.recovery_capsule_version,
      'recoveryCapsuleVersion',
    );
    _validatePositiveInt31(
      binding.ready_data_generation,
      'readyDataGeneration',
    );
    _validatePositiveUint32(binding.ready_data_key_epoch, 'readyDataKeyEpoch');
    if (binding.device_key_version != expectedDeviceKeyVersion ||
        binding.ready_data_key_epoch != binding.key_epoch) {
      throw StateError('账户恢复替换证明返回的版本或数据代次不一致');
    }
    final result = _AccountRecoveryReplacementProofNativeResult(
      executionHandle: binding.execution_handle,
      challengeId: challengeId,
      attemptId: attemptId,
      userId: userId,
      deviceId: deviceId,
      securityGeneration: binding.security_generation,
      keyEpoch: binding.key_epoch,
      membershipOperationId: membershipOperationId,
      membershipManifestDigest: _copyNativeByteArray(
        binding.membership_manifest_digest,
        _accountRecoveryTokenDigestLength,
      ),
      deviceKeyVersion: binding.device_key_version,
      recoveryCapsuleVersion: binding.recovery_capsule_version,
      sourceDataRekeyOperationId: sourceDataRekeyOperationId,
      readyDataGeneration: binding.ready_data_generation,
      readyDataKeyEpoch: binding.ready_data_key_epoch,
      completionProofDigest: _copyNativeByteArray(
        binding.completion_proof_digest,
        _accountRecoveryTokenDigestLength,
      ),
      requestDigest: _copyNativeByteArray(
        binding.request_digest,
        _accountRecoveryTokenDigestLength,
      ),
      nonceProof: Uint8List.fromList(
        outputNonceProof.asTypedList(_accountRecoveryNonceProofLength),
      ),
      trustSignature: Uint8List.fromList(
        outputTrustSignature.asTypedList(_accountTrustSignatureLength),
      ),
    );
    published = true;
    return result;
  } finally {
    if (!published &&
        outputBinding.ref.execution_handle !=
            native.KELIVO_ACCOUNT_RECOVERY_INVALID_EXECUTION_HANDLE) {
      native.kelivo_account_recovery_execution_close(
        outputBinding.ref.execution_handle,
      );
    }
    for (final entry in <(ffi.Pointer<ffi.Uint8>, int)>[
      (mediaPointer, media.length),
      (originPointer, origin.length),
      (historyPointer, history.length),
      (sourceCapsulePointer, sourceCapsule.length),
      (currentCapsulePointer, currentCapsule.length),
      (challengePointer, challenge.length),
      (sealedNoncePointer, sealedNonce.length),
      (completionProofFramePointer, completionProofFrame.length),
      (completionProofSignaturePointer, completionProofSignature.length),
      (recoveryTokenDigestPointer, recoveryTokenDigest.length),
      (expectedChallengeIdPointer, expectedChallengeId.length),
      (expectedAttemptIdPointer, expectedAttemptId.length),
      (expectedDeviceIdPointer, expectedDeviceId.length),
    ]) {
      _clearAndFree(entry.$1, entry.$2);
    }
    if (passphrasePointer.address != 0) {
      _clearAndFree(passphrasePointer, passphrase.length);
    }
    _clearAndFree(
      outputBinding.cast<ffi.Uint8>(),
      ffi.sizeOf<native.KelivoAccountRecoveryReplacementProofBinding>(),
    );
    _clearAndFree(outputNonceProof, _accountRecoveryNonceProofLength);
    calloc.free(outputNonceProofLength);
    _clearAndFree(outputTrustSignature, _accountTrustSignatureLength);
    calloc.free(outputTrustSignatureLength);
    for (final value in <Uint8List>[
      media,
      passphrase,
      origin,
      history,
      sourceCapsule,
      currentCapsule,
      challenge,
      sealedNonce,
      completionProofFrame,
      completionProofSignature,
      recoveryTokenDigest,
      expectedChallengeId,
      expectedAttemptId,
      expectedDeviceId,
    ]) {
      value.fillRange(0, value.length, 0);
    }
  }
}

@pragma('vm:never-inline')
_AccountRecoveryProofNativeResult _verifyAccountRecoveryAndCreateProof(
  int identityHandle,
  int expectedDeviceKeyVersion,
  int expectedDeviceAuthGeneration,
  Uint8List media,
  Uint8List passphrase,
  Uint8List origin,
  Uint8List history,
  Uint8List? sourceCapsule,
  Uint8List currentCapsule,
  Uint8List challenge,
  Uint8List sealedNonce,
  Uint8List recoveryTokenDigest,
  Uint8List expectedAttemptId,
  Uint8List expectedDeviceId,
  Uint8List expectedRequestDigest,
  int expectedExpiresAtMs,
) {
  final mediaPointer = _copyToNative(media);
  final originPointer = _copyToNative(origin);
  final historyPointer = _copyToNative(history);
  final sourceCapsulePointer = sourceCapsule == null
      ? ffi.nullptr.cast<ffi.Uint8>()
      : _copyToNative(sourceCapsule);
  final currentCapsulePointer = _copyToNative(currentCapsule);
  final challengePointer = _copyToNative(challenge);
  final sealedNoncePointer = _copyToNative(sealedNonce);
  final recoveryTokenDigestPointer = _copyToNative(recoveryTokenDigest);
  final expectedAttemptIdPointer = _copyToNative(expectedAttemptId);
  final expectedDeviceIdPointer = _copyToNative(expectedDeviceId);
  final expectedRequestDigestPointer = _copyToNative(expectedRequestDigest);
  final outputBinding = calloc<native.KelivoAccountRecoveryProofBinding>();
  final outputNonceProof = calloc<ffi.Uint8>(_accountRecoveryNonceProofLength);
  final outputNonceProofLength = calloc<ffi.Size>();
  final outputTrustSignature = calloc<ffi.Uint8>(_accountTrustSignatureLength);
  final outputTrustSignatureLength = calloc<ffi.Size>();
  var passphrasePointer = ffi.nullptr.cast<ffi.Uint8>();
  var published = false;
  try {
    passphrasePointer = _copyToNative(passphrase);
    _throwOnError(
      operation: 'account_recovery_verify_and_prove',
      statusCode: native.kelivo_account_recovery_verify_and_prove(
        identityHandle,
        expectedDeviceKeyVersion,
        expectedDeviceAuthGeneration,
        mediaPointer,
        media.length,
        passphrasePointer,
        passphrase.length,
        originPointer,
        origin.length,
        historyPointer,
        history.length,
        sourceCapsulePointer,
        sourceCapsule?.length ?? 0,
        currentCapsulePointer,
        currentCapsule.length,
        challengePointer,
        challenge.length,
        sealedNoncePointer,
        sealedNonce.length,
        recoveryTokenDigestPointer,
        recoveryTokenDigest.length,
        expectedAttemptIdPointer,
        expectedAttemptId.length,
        expectedDeviceIdPointer,
        expectedDeviceId.length,
        expectedRequestDigestPointer,
        expectedRequestDigest.length,
        expectedExpiresAtMs,
        outputBinding,
        outputNonceProof,
        _accountRecoveryNonceProofLength,
        outputNonceProofLength,
        outputTrustSignature,
        _accountTrustSignatureLength,
        outputTrustSignatureLength,
      ),
    );
    _requireExactOutputLength(
      operation: 'account_recovery_verify_and_prove_nonce_proof',
      expected: _accountRecoveryNonceProofLength,
      actual: outputNonceProofLength.value,
    );
    _requireExactOutputLength(
      operation: 'account_recovery_verify_and_prove_trust_signature',
      expected: _accountTrustSignatureLength,
      actual: outputTrustSignatureLength.value,
    );
    final binding = outputBinding.ref;
    if (binding.struct_size !=
        native.KELIVO_ACCOUNT_RECOVERY_PROOF_BINDING_STRUCT_SIZE) {
      throw StateError('账户恢复证明返回了未知绑定结构');
    }
    if (binding.execution_handle ==
        native.KELIVO_ACCOUNT_RECOVERY_INVALID_EXECUTION_HANDLE) {
      throw StateError('账户恢复证明成功但未发布有效执行句柄');
    }
    final userId = _copyNativeByteArray(binding.user_id, _deviceUuidLength);
    final deviceId = _copyNativeByteArray(binding.device_id, _deviceUuidLength);
    _validateUuidV4(userId, 'userId');
    _validateUuidV4(deviceId, 'deviceId');
    if (!_sameAccountRecoveryBytes(deviceId, expectedDeviceId)) {
      throw StateError('账户恢复证明返回的设备绑定不一致');
    }
    _validatePositiveInt31(binding.security_generation, 'securityGeneration');
    _validatePositiveUint32(binding.key_epoch, 'keyEpoch');
    _validatePositiveUint32(binding.device_key_version, 'deviceKeyVersion');
    _validatePositiveInt31(
      binding.recovery_capsule_version,
      'recoveryCapsuleVersion',
    );
    if (binding.device_key_version != expectedDeviceKeyVersion) {
      throw StateError('账户恢复证明返回的设备密钥版本不一致');
    }
    final dataPhase = KelivoAccountRecoveryDataPhase.fromCode(
      binding.data_phase,
    );
    _validatePositiveInt31(
      binding.source_data_generation,
      'sourceDataGeneration',
    );
    _validatePositiveUint32(
      binding.source_data_key_epoch,
      'sourceDataKeyEpoch',
    );
    final sourceDataRekeyOperationId = _copyNativeByteArray(
      binding.source_data_rekey_operation_id,
      _deviceUuidLength,
    );
    final operationAuthorizationDigest = _copyNativeByteArray(
      binding.operation_authorization_digest,
      _accountRecoveryTokenDigestLength,
    );
    switch (dataPhase) {
      case KelivoAccountRecoveryDataPhase.ready:
        if (binding.source_data_key_epoch != binding.key_epoch ||
            sourceDataRekeyOperationId.any((byte) => byte != 0) ||
            operationAuthorizationDigest.any((byte) => byte != 0)) {
          throw StateError('账户恢复证明返回的 ready 数据绑定不一致');
        }
      case KelivoAccountRecoveryDataPhase.rekeyPending:
        if (binding.source_data_key_epoch == _maxUint32 ||
            binding.source_data_key_epoch + 1 != binding.key_epoch) {
          throw StateError('账户恢复证明返回的 rekey 数据代次不一致');
        }
        _validateUuidV4(
          sourceDataRekeyOperationId,
          'sourceDataRekeyOperationId',
        );
    }
    final result = _AccountRecoveryProofNativeResult(
      executionHandle: binding.execution_handle,
      dataPhase: binding.data_phase,
      userId: userId,
      deviceId: deviceId,
      securityGeneration: binding.security_generation,
      keyEpoch: binding.key_epoch,
      deviceKeyVersion: binding.device_key_version,
      recoveryCapsuleVersion: binding.recovery_capsule_version,
      sourceDataGeneration: binding.source_data_generation,
      sourceDataKeyEpoch: binding.source_data_key_epoch,
      sourceDataRekeyOperationId: sourceDataRekeyOperationId,
      operationAuthorizationDigest: operationAuthorizationDigest,
      nonceProof: Uint8List.fromList(
        outputNonceProof.asTypedList(_accountRecoveryNonceProofLength),
      ),
      trustSignature: Uint8List.fromList(
        outputTrustSignature.asTypedList(_accountTrustSignatureLength),
      ),
    );
    published = true;
    return result;
  } finally {
    if (!published &&
        outputBinding.ref.execution_handle !=
            native.KELIVO_ACCOUNT_RECOVERY_INVALID_EXECUTION_HANDLE) {
      native.kelivo_account_recovery_execution_close(
        outputBinding.ref.execution_handle,
      );
    }
    _clearAndFree(mediaPointer, media.length);
    if (passphrasePointer.address != 0) {
      _clearAndFree(passphrasePointer, passphrase.length);
    }
    _clearAndFree(originPointer, origin.length);
    _clearAndFree(historyPointer, history.length);
    if (sourceCapsule != null) {
      _clearAndFree(sourceCapsulePointer, sourceCapsule.length);
      sourceCapsule.fillRange(0, sourceCapsule.length, 0);
    }
    _clearAndFree(currentCapsulePointer, currentCapsule.length);
    _clearAndFree(challengePointer, challenge.length);
    _clearAndFree(sealedNoncePointer, sealedNonce.length);
    _clearAndFree(recoveryTokenDigestPointer, recoveryTokenDigest.length);
    _clearAndFree(expectedAttemptIdPointer, expectedAttemptId.length);
    _clearAndFree(expectedDeviceIdPointer, expectedDeviceId.length);
    _clearAndFree(expectedRequestDigestPointer, expectedRequestDigest.length);
    _clearAndFree(
      outputBinding.cast<ffi.Uint8>(),
      ffi.sizeOf<native.KelivoAccountRecoveryProofBinding>(),
    );
    _clearAndFree(outputNonceProof, _accountRecoveryNonceProofLength);
    calloc.free(outputNonceProofLength);
    _clearAndFree(outputTrustSignature, _accountTrustSignatureLength);
    calloc.free(outputTrustSignatureLength);
    media.fillRange(0, media.length, 0);
    passphrase.fillRange(0, passphrase.length, 0);
    origin.fillRange(0, origin.length, 0);
    history.fillRange(0, history.length, 0);
    currentCapsule.fillRange(0, currentCapsule.length, 0);
    challenge.fillRange(0, challenge.length, 0);
    sealedNonce.fillRange(0, sealedNonce.length, 0);
    recoveryTokenDigest.fillRange(0, recoveryTokenDigest.length, 0);
    expectedAttemptId.fillRange(0, expectedAttemptId.length, 0);
    expectedDeviceId.fillRange(0, expectedDeviceId.length, 0);
    expectedRequestDigest.fillRange(0, expectedRequestDigest.length, 0);
  }
}

KelivoPreparedAccountRecoveryCommit _prepareAccountRecoveryCommit(
  int executionHandle,
  KelivoAccountRecoveryCommitKind kind,
  int targetAuthGeneration,
  Uint8List operationId,
  Uint8List rekeyOperationId,
  Uint8List completionSessionId,
  Uint8List completionSessionTokenDigest,
  int expectedGeneration,
  int expectedKeyEpoch,
  int currentRecoveryCapsuleVersion,
  KelivoAccountRecoveryDataPhase dataPhase,
  int deviceKeyVersion,
  Uint8List userId,
  Uint8List deviceId,
  int sourceDataGeneration,
  int sourceDataKeyEpoch,
  Uint8List operationAuthorizationDigest,
) {
  final input = calloc<native.KelivoAccountRecoveryPrepareInput>();
  final outputBinding = calloc<native.KelivoAccountRecoveryPrepareBinding>();
  final outputManifest = calloc<ffi.Uint8>(
    _accountRecoveryPreparedManifestMaximumLength,
  );
  final outputManifestLength = calloc<ffi.Size>();
  final outputEnvelope = calloc<ffi.Uint8>(_accountKeyEnvelopeLength);
  final outputEnvelopeLength = calloc<ffi.Size>();
  final outputCapsule = calloc<ffi.Uint8>(_recoveryCapsuleLength);
  final outputCapsuleLength = calloc<ffi.Size>();
  try {
    input.ref.struct_size =
        native.KELIVO_ACCOUNT_RECOVERY_PREPARE_INPUT_STRUCT_SIZE;
    input.ref.kind = kind.code;
    _writeAccountRecoveryArray(input.ref.operation_id, operationId);
    input.ref.target_auth_generation = targetAuthGeneration;
    _writeAccountRecoveryArray(input.ref.rekey_operation_id, rekeyOperationId);
    _writeAccountRecoveryArray(
      input.ref.completion_session_id,
      completionSessionId,
    );
    _writeAccountRecoveryArray(
      input.ref.completion_session_token_digest,
      completionSessionTokenDigest,
    );
    _throwOnError(
      operation: 'account_recovery_prepare_commit',
      statusCode: native.kelivo_account_recovery_prepare_commit(
        executionHandle,
        input,
        outputBinding,
        outputManifest,
        _accountRecoveryPreparedManifestMaximumLength,
        outputManifestLength,
        outputEnvelope,
        _accountKeyEnvelopeLength,
        outputEnvelopeLength,
        outputCapsule,
        _recoveryCapsuleLength,
        outputCapsuleLength,
      ),
    );
    final binding = outputBinding.ref;
    if (binding.struct_size !=
            native.KELIVO_ACCOUNT_RECOVERY_PREPARE_BINDING_STRUCT_SIZE ||
        binding.kind != kind.code ||
        binding.reserved != 0) {
      throw StateError('账户恢复提交返回了未知绑定结构');
    }
    if (binding.expected_generation != expectedGeneration ||
        binding.expected_key_epoch != expectedKeyEpoch ||
        binding.next_generation != expectedGeneration + 1) {
      throw StateError('账户恢复提交返回的成员代次绑定不一致');
    }
    if (outputManifestLength.value < _recoveryManifestMinimumLength ||
        outputManifestLength.value >
            _accountRecoveryPreparedManifestMaximumLength) {
      throw StateError('账户恢复提交返回的成员清单长度无效');
    }
    _requireExactOutputLength(
      operation: 'account_recovery_prepare_commit_envelope',
      expected: _accountKeyEnvelopeLength,
      actual: outputEnvelopeLength.value,
    );
    final Uint8List? capsule;
    switch (kind) {
      case KelivoAccountRecoveryCommitKind.resume:
        if (binding.next_key_epoch != expectedKeyEpoch ||
            binding.next_recovery_capsule_version != 0 ||
            outputCapsuleLength.value != 0) {
          throw StateError('账户恢复接续提交返回了替换材料');
        }
        capsule = null;
      case KelivoAccountRecoveryCommitKind.replacement:
        if (binding.next_key_epoch != expectedKeyEpoch + 1 ||
            binding.next_recovery_capsule_version !=
                currentRecoveryCapsuleVersion + 1) {
          throw StateError('账户恢复替换提交返回的轮换代次不一致');
        }
        _requireExactOutputLength(
          operation: 'account_recovery_prepare_commit_capsule',
          expected: _recoveryCapsuleLength,
          actual: outputCapsuleLength.value,
        );
        capsule = Uint8List.fromList(
          outputCapsule.asTypedList(_recoveryCapsuleLength),
        );
    }
    final stateBinding = KelivoPreparedAccountRecoveryStateBinding(
      kind: kind,
      dataPhase: dataPhase,
      deviceKeyVersion: deviceKeyVersion,
      userId: userId,
      deviceId: deviceId,
      sourceKeyEpoch: sourceDataKeyEpoch,
      targetKeyEpoch: binding.next_key_epoch,
      sourceDataGeneration: sourceDataGeneration,
      targetDataGeneration: sourceDataGeneration + 1,
      membershipGeneration: binding.next_generation,
      membershipManifestDigest: _copyNativeByteArray(
        binding.manifest_digest,
        _accountRecoveryTokenDigestLength,
      ),
      rekeyOperationId: kind == KelivoAccountRecoveryCommitKind.resume
          ? rekeyOperationId
          : operationId,
      operationAuthorizationDigest: operationAuthorizationDigest,
    );
    return KelivoPreparedAccountRecoveryCommit._(
      kind: kind,
      expectedGeneration: binding.expected_generation,
      expectedKeyEpoch: binding.expected_key_epoch,
      nextGeneration: binding.next_generation,
      nextKeyEpoch: binding.next_key_epoch,
      nextRecoveryCapsuleVersion: binding.next_recovery_capsule_version,
      manifestDigest: _copyNativeByteArray(
        binding.manifest_digest,
        _accountRecoveryTokenDigestLength,
      ),
      requestDigest: _copyNativeByteArray(
        binding.request_digest,
        _accountRecoveryTokenDigestLength,
      ),
      membershipManifest: Uint8List.fromList(
        outputManifest.asTypedList(outputManifestLength.value),
      ),
      accountKeyEnvelope: Uint8List.fromList(
        outputEnvelope.asTypedList(_accountKeyEnvelopeLength),
      ),
      recoveryCapsule: capsule,
      stateBinding: stateBinding,
    );
  } finally {
    _clearAndFree(
      input.cast<ffi.Uint8>(),
      ffi.sizeOf<native.KelivoAccountRecoveryPrepareInput>(),
    );
    _clearAndFree(
      outputBinding.cast<ffi.Uint8>(),
      ffi.sizeOf<native.KelivoAccountRecoveryPrepareBinding>(),
    );
    _clearAndFree(
      outputManifest,
      _accountRecoveryPreparedManifestMaximumLength,
    );
    calloc.free(outputManifestLength);
    _clearAndFree(outputEnvelope, _accountKeyEnvelopeLength);
    calloc.free(outputEnvelopeLength);
    _clearAndFree(outputCapsule, _recoveryCapsuleLength);
    calloc.free(outputCapsuleLength);
    operationId.fillRange(0, operationId.length, 0);
    rekeyOperationId.fillRange(0, rekeyOperationId.length, 0);
    completionSessionId.fillRange(0, completionSessionId.length, 0);
    completionSessionTokenDigest.fillRange(
      0,
      completionSessionTokenDigest.length,
      0,
    );
    userId.fillRange(0, userId.length, 0);
    deviceId.fillRange(0, deviceId.length, 0);
    operationAuthorizationDigest.fillRange(
      0,
      operationAuthorizationDigest.length,
      0,
    );
  }
}

KelivoPreparedAccountRecoveryDeviceStates _prepareAccountRecoveryDeviceStates(
  int executionHandle,
  int keyHandle,
  KelivoPreparedAccountRecoveryStateBinding stateBinding,
) {
  final expected = calloc<native.KelivoAccountRecoveryStateBinding>();
  final unpruned = calloc<ffi.Uint8>(_deviceStateBlobLength);
  final unprunedLength = calloc<ffi.Size>();
  final pruned = calloc<ffi.Uint8>(_deviceStateBlobLength);
  final prunedLength = calloc<ffi.Size>();
  final continuation = calloc<ffi.Uint8>(
    kelivoAccountRecoveryContinuationLength,
  );
  final continuationLength = calloc<ffi.Size>();
  Uint8List? continuationBytes;
  var continuationTransferred = false;
  try {
    _writeAccountRecoveryStateBinding(expected.ref, stateBinding);
    _throwOnError(
      operation: 'account_recovery_device_states_prepare',
      statusCode: native.kelivo_account_recovery_device_states_prepare(
        executionHandle,
        keyHandle,
        expected,
        unpruned,
        _deviceStateBlobLength,
        unprunedLength,
        pruned,
        _deviceStateBlobLength,
        prunedLength,
        continuation,
        kelivoAccountRecoveryContinuationLength,
        continuationLength,
      ),
    );
    _requireExactOutputLength(
      operation: 'account_recovery_device_states_prepare_unpruned',
      expected: _deviceStateBlobLength,
      actual: unprunedLength.value,
    );
    _requireExactOutputLength(
      operation: 'account_recovery_device_states_prepare_pruned',
      expected: _deviceStateBlobLength,
      actual: prunedLength.value,
    );
    _requireExactOutputLength(
      operation: 'account_recovery_device_states_prepare_continuation',
      expected: kelivoAccountRecoveryContinuationLength,
      actual: continuationLength.value,
    );
    final unprunedBytes = Uint8List.fromList(
      unpruned.asTypedList(_deviceStateBlobLength),
    );
    final prunedBytes = Uint8List.fromList(
      pruned.asTypedList(_deviceStateBlobLength),
    );
    continuationBytes = Uint8List.fromList(
      continuation.asTypedList(kelivoAccountRecoveryContinuationLength),
    );
    if (_sameAccountRecoveryBytes(unprunedBytes, prunedBytes)) {
      throw StateError('账户恢复设备状态候选必须彼此不同');
    }
    final result = KelivoPreparedAccountRecoveryDeviceStates._(
      unprunedStateBlob: unprunedBytes,
      prunedCandidate: prunedBytes,
      ownedContinuation: continuationBytes,
    );
    continuationTransferred = true;
    return result;
  } finally {
    if (!continuationTransferred) {
      continuationBytes?.fillRange(0, continuationBytes.length, 0);
    }
    _clearAndFree(
      expected.cast<ffi.Uint8>(),
      ffi.sizeOf<native.KelivoAccountRecoveryStateBinding>(),
    );
    _clearAndFree(unpruned, _deviceStateBlobLength);
    calloc.free(unprunedLength);
    _clearAndFree(pruned, _deviceStateBlobLength);
    calloc.free(prunedLength);
    _clearAndFree(continuation, kelivoAccountRecoveryContinuationLength);
    calloc.free(continuationLength);
  }
}

Uint8List _activatePreparedAccountRecoveryDeviceState(
  int keyHandle,
  Uint8List continuation,
  KelivoPreparedAccountRecoveryStateBinding stateBinding,
  Uint8List prunedCandidate,
  Uint8List completionProofFrame,
  Uint8List completionProofSignature,
  Uint8List completionProofDigest,
) {
  final expected = calloc<native.KelivoAccountRecoveryStateBinding>();
  final nativeContinuation = _copyToNative(continuation);
  final candidate = _copyToNative(prunedCandidate);
  final frame = _copyToNative(completionProofFrame);
  final signature = _copyToNative(completionProofSignature);
  final digest = _copyToNative(completionProofDigest);
  final output = calloc<ffi.Uint8>(_deviceStateBlobLength);
  final outputLength = calloc<ffi.Size>();
  try {
    _writeAccountRecoveryStateBinding(expected.ref, stateBinding);
    _throwOnError(
      operation: 'account_recovery_device_state_prune_and_activate',
      statusCode: native
          .kelivo_account_recovery_device_state_prune_and_activate(
            keyHandle,
            nativeContinuation,
            continuation.length,
            expected,
            candidate,
            prunedCandidate.length,
            frame,
            completionProofFrame.length,
            signature,
            completionProofSignature.length,
            digest,
            completionProofDigest.length,
            output,
            _deviceStateBlobLength,
            outputLength,
          ),
    );
    _requireExactOutputLength(
      operation: 'account_recovery_device_state_prune_and_activate',
      expected: _deviceStateBlobLength,
      actual: outputLength.value,
    );
    final activated = Uint8List.fromList(
      output.asTypedList(_deviceStateBlobLength),
    );
    if (!_sameAccountRecoveryBytes(activated, prunedCandidate)) {
      throw StateError('原生账户恢复激活返回了不同候选状态');
    }
    return activated;
  } finally {
    _clearAndFree(
      expected.cast<ffi.Uint8>(),
      ffi.sizeOf<native.KelivoAccountRecoveryStateBinding>(),
    );
    _clearAndFree(nativeContinuation, continuation.length);
    _clearAndFree(candidate, prunedCandidate.length);
    _clearAndFree(frame, completionProofFrame.length);
    _clearAndFree(signature, completionProofSignature.length);
    _clearAndFree(digest, completionProofDigest.length);
    _clearAndFree(output, _deviceStateBlobLength);
    calloc.free(outputLength);
    continuation.fillRange(0, continuation.length, 0);
    prunedCandidate.fillRange(0, prunedCandidate.length, 0);
    completionProofFrame.fillRange(0, completionProofFrame.length, 0);
    completionProofSignature.fillRange(0, completionProofSignature.length, 0);
    completionProofDigest.fillRange(0, completionProofDigest.length, 0);
  }
}

void _writeAccountRecoveryStateBinding(
  native.KelivoAccountRecoveryStateBinding output,
  KelivoPreparedAccountRecoveryStateBinding input,
) {
  output.struct_size = native.KELIVO_ACCOUNT_RECOVERY_STATE_BINDING_STRUCT_SIZE;
  output.kind = input.kind.code;
  output.data_phase = input.dataPhase.code;
  output.device_key_version = input.deviceKeyVersion;
  _writeAccountRecoveryArray(output.user_id, input.userId);
  _writeAccountRecoveryArray(output.device_id, input.deviceId);
  output.source_key_epoch = input.sourceKeyEpoch;
  output.target_key_epoch = input.targetKeyEpoch;
  output.source_data_generation = input.sourceDataGeneration;
  output.target_data_generation = input.targetDataGeneration;
  output.membership_generation = input.membershipGeneration;
  output.reserved = 0;
  _writeAccountRecoveryArray(
    output.membership_manifest_digest,
    input.membershipManifestDigest,
  );
  _writeAccountRecoveryArray(output.rekey_operation_id, input.rekeyOperationId);
  _writeAccountRecoveryArray(
    output.operation_authorization_digest,
    input.operationAuthorizationDigest,
  );
}

void _requireExecutionStateBinding(
  KelivoAccountRecoveryExecution execution,
  KelivoPreparedAccountRecoveryStateBinding binding,
) {
  if (execution._replacementOnly &&
      binding.kind != KelivoAccountRecoveryCommitKind.replacement) {
    throw ArgumentError.value(binding, 'stateBinding', '第二阶段恢复执行仅接受替换状态');
  }
  final sameIdentity =
      binding.deviceKeyVersion == execution.deviceKeyVersion &&
      _sameAccountRecoveryBytes(binding.userId, execution.userId) &&
      _sameAccountRecoveryBytes(binding.deviceId, execution.deviceId);
  final beforeCommitKindMatches = switch (binding.kind) {
    KelivoAccountRecoveryCommitKind.resume =>
      execution.dataPhase == KelivoAccountRecoveryDataPhase.rekeyPending &&
          _sameAccountRecoveryBytes(
            binding.rekeyOperationId,
            execution._sourceDataRekeyOperationId,
          ) &&
          _sameAccountRecoveryBytes(
            binding.operationAuthorizationDigest,
            execution._operationAuthorizationDigest,
          ),
    KelivoAccountRecoveryCommitKind.replacement =>
      execution.dataPhase == KelivoAccountRecoveryDataPhase.ready,
  };
  final beforeCommit =
      beforeCommitKindMatches &&
      binding.sourceKeyEpoch == execution.sourceDataKeyEpoch &&
      binding.sourceDataGeneration == execution.sourceDataGeneration &&
      binding.membershipGeneration == execution.securityGeneration + 1;
  final afterCommitPending =
      execution.dataPhase == KelivoAccountRecoveryDataPhase.rekeyPending &&
      binding.targetKeyEpoch == execution.keyEpoch &&
      binding.sourceKeyEpoch == execution.sourceDataKeyEpoch &&
      binding.sourceDataGeneration == execution.sourceDataGeneration &&
      binding.membershipGeneration == execution.securityGeneration &&
      _sameAccountRecoveryBytes(
        binding.rekeyOperationId,
        execution._sourceDataRekeyOperationId,
      ) &&
      _sameAccountRecoveryBytes(
        binding.operationAuthorizationDigest,
        execution._operationAuthorizationDigest,
      );
  final afterCommitReady =
      execution.dataPhase == KelivoAccountRecoveryDataPhase.ready &&
      binding.targetKeyEpoch == execution.sourceDataKeyEpoch &&
      binding.targetDataGeneration == execution.sourceDataGeneration &&
      binding.membershipGeneration == execution.securityGeneration;
  if (!sameIdentity ||
      (!beforeCommit && !afterCommitPending && !afterCommitReady)) {
    throw ArgumentError.value(binding, 'stateBinding', '与账户恢复执行不一致');
  }
}

void _writeAccountRecoveryArray(ffi.Array<ffi.Uint8> output, Uint8List input) {
  for (var index = 0; index < input.length; index++) {
    output[index] = input[index];
  }
}

void _validatePositiveInt31(int value, String name) {
  if (value <= 0 || value > _maximumPositiveInt31) {
    throw ArgumentError.value(value, name, '必须位于正 31 位整数范围');
  }
}

bool _sameAccountRecoveryBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}
