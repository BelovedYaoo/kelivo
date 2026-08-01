part of '../kelivo_secure_core.dart';

const _accountRecoveryChallengeLength =
    native.KELIVO_ACCOUNT_RECOVERY_CHALLENGE_SIZE;
const _accountRecoverySealedNonceLength =
    native.KELIVO_ACCOUNT_RECOVERY_SEALED_NONCE_SIZE;
const _accountRecoveryTokenDigestLength =
    native.KELIVO_ACCOUNT_RECOVERY_TOKEN_DIGEST_SIZE;
const _accountRecoveryNonceProofLength =
    native.KELIVO_ACCOUNT_RECOVERY_NONCE_PROOF_SIZE;
const _accountRecoveryPreparedManifestMaximumLength =
    native.KELIVO_ACCOUNT_RECOVERY_PREPARED_MANIFEST_MAX_SIZE;
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
    required this.dataPhase,
    required Uint8List userId,
    required Uint8List deviceId,
    required this.securityGeneration,
    required this.keyEpoch,
    required this.deviceKeyVersion,
    required this.targetAuthGeneration,
    required this.recoveryCapsuleVersion,
  }) : _state = _AccountRecoveryExecutionState(handle),
       userId = _immutableDeviceBytes(userId),
       deviceId = _immutableDeviceBytes(deviceId);

  final _AccountRecoveryExecutionState _state;
  final KelivoAccountRecoveryDataPhase dataPhase;
  final Uint8List userId;
  final Uint8List deviceId;
  final int securityGeneration;
  final int keyEpoch;
  final int deviceKeyVersion;
  final int targetAuthGeneration;
  final int recoveryCapsuleVersion;

  @override
  String toString() => 'KelivoAccountRecoveryExecution(opaque)';
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
  final Uint8List nonceProof;
  final Uint8List trustSignature;
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
            native.KELIVO_ACCOUNT_RECOVERY_INVALID_EXECUTION_HANDLE ||
        binding.ark_handle == native.KELIVO_DEVICE_INVALID_HANDLE) {
      throw StateError('账户恢复证明成功但未发布有效秘密句柄');
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
    KelivoAccountRecoveryDataPhase.fromCode(binding.data_phase);
    final result = _AccountRecoveryProofNativeResult(
      executionHandle: binding.execution_handle,
      dataPhase: binding.data_phase,
      userId: userId,
      deviceId: deviceId,
      securityGeneration: binding.security_generation,
      keyEpoch: binding.key_epoch,
      deviceKeyVersion: binding.device_key_version,
      recoveryCapsuleVersion: binding.recovery_capsule_version,
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
