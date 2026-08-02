import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';

import '../workspace/device_state_blob_store.dart';
import 'cloud_sync_types.dart';
import 'e2ee_account_recovery.dart';

const _checkpointVersion = 7;
const _checkpointRecordEpoch = 1;
const _checkpointTokenLength = 59;
const _checkpointFullSessionTokenLength = 50;
const _checkpointCapsuleMaximumLength = 4096;
const _checkpointRecordDomain = 'kelivo.account-recovery.checkpoint.record.v7';
const _checkpointAssociatedDataDomain =
    'kelivo.account-recovery.checkpoint.aad.v7';
final _checkpointMagic = Uint8List.fromList(ascii.encode('KELVARC7'));

final class E2eeAccountRecoveryCheckpointStore
    implements E2eeAccountRecoveryCheckpointPersistence {
  factory E2eeAccountRecoveryCheckpointStore({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
    required DeviceStateBlobStore deviceStateStore,
    required KelivoSecureCore secureCore,
    required KelivoKeyHandle key,
  }) {
    if (normalizedBaseUrl.isEmpty || normalizedBaseUrl.contains('\u0000')) {
      throw const FormatException('账户恢复 checkpoint 服务地址无效');
    }
    if (normalizedLoginName.isEmpty || normalizedLoginName.contains('\u0000')) {
      throw const FormatException('账户恢复 checkpoint 登录名无效');
    }
    final scope = '$normalizedBaseUrl\u0000$normalizedLoginName';
    final recordDigest = sha256.convert(
      utf8.encode('$_checkpointRecordDomain\u0000$scope'),
    );
    final recordId = Uint8List.fromList(
      recordDigest.bytes.sublist(0, 16),
    ).asUnmodifiableView();
    final associatedData = Uint8List.fromList(
      utf8.encode('$_checkpointAssociatedDataDomain\u0000$scope'),
    ).asUnmodifiableView();
    return E2eeAccountRecoveryCheckpointStore._(
      normalizedBaseUrl,
      normalizedLoginName,
      deviceStateStore,
      secureCore,
      key,
      recordId,
      associatedData,
    );
  }

  const E2eeAccountRecoveryCheckpointStore._(
    this._normalizedBaseUrl,
    this._normalizedLoginName,
    this._deviceStateStore,
    this._secureCore,
    this._key,
    this._recordId,
    this._associatedData,
  );

  final String _normalizedBaseUrl;
  final String _normalizedLoginName;
  final DeviceStateBlobStore _deviceStateStore;
  final KelivoSecureCore _secureCore;
  final KelivoKeyHandle _key;
  final Uint8List _recordId;
  final Uint8List _associatedData;

  @override
  Future<E2eeAccountRecoveryCheckpointSnapshot?> read() async {
    Uint8List? envelope;
    Uint8List? plaintext;
    try {
      envelope = await _deviceStateStore.readPendingAccountRecoveryEnvelope(
        normalizedBaseUrl: _normalizedBaseUrl,
        normalizedLoginName: _normalizedLoginName,
      );
      if (envelope == null) return null;
      plaintext = await _secureCore.openRecord(
        _key,
        recordId: _recordId,
        epoch: _checkpointRecordEpoch,
        associatedData: _associatedData,
        envelope: envelope,
      );
      return E2eeAccountRecoveryCheckpointSnapshot(
        checkpoint: _decodeCheckpoint(plaintext),
        envelopeDigest: _digest(envelope),
      );
    } finally {
      _clear(envelope);
      _clear(plaintext);
    }
  }

  @override
  Future<E2eeAccountRecoveryCheckpointSnapshot> create(
    E2eeAccountRecoveryCheckpoint checkpoint,
  ) async {
    final current = await read();
    if (current != null) {
      var retainCurrent = false;
      try {
        if (_sameCheckpoint(current.checkpoint, checkpoint)) {
          retainCurrent = true;
          return current;
        }
        throw StateError('账户恢复 checkpoint 已存在');
      } finally {
        if (!retainCurrent) current.clearSensitiveState();
      }
    }
    final envelope = await _seal(checkpoint);
    try {
      try {
        await _deviceStateStore.writePendingAccountRecoveryEnvelope(
          normalizedBaseUrl: _normalizedBaseUrl,
          normalizedLoginName: _normalizedLoginName,
          envelope: envelope,
        );
      } on StateError {
        final raced = await read();
        if (raced != null) {
          var retainRaced = false;
          try {
            if (_sameCheckpoint(raced.checkpoint, checkpoint)) {
              retainRaced = true;
              return raced;
            }
          } finally {
            if (!retainRaced) raced.clearSensitiveState();
          }
        }
        rethrow;
      }
      return E2eeAccountRecoveryCheckpointSnapshot(
        checkpoint: checkpoint.detachedCopy(),
        envelopeDigest: _digest(envelope),
      );
    } finally {
      _clear(envelope);
    }
  }

  @override
  Future<E2eeAccountRecoveryCheckpointSnapshot> advance({
    required Uint8List expectedEnvelopeDigest,
    required E2eeAccountRecoveryCheckpoint checkpoint,
  }) async {
    if (expectedEnvelopeDigest.length != 32) {
      throw const FormatException('账户恢复 checkpoint 信封摘要长度无效');
    }
    final current = await read();
    if (current == null) {
      throw StateError('账户恢复 checkpoint 不存在');
    }
    var retainCurrent = false;
    try {
      if (_sameCheckpoint(current.checkpoint, checkpoint)) {
        retainCurrent = true;
        return current;
      }
      if (!_sameBytes(current.envelopeDigest, expectedEnvelopeDigest)) {
        throw StateError('账户恢复 checkpoint 已被并发推进');
      }
    } finally {
      if (!retainCurrent) current.clearSensitiveState();
    }
    final envelope = await _seal(checkpoint);
    try {
      try {
        await _deviceStateStore.replacePendingAccountRecoveryEnvelope(
          normalizedBaseUrl: _normalizedBaseUrl,
          normalizedLoginName: _normalizedLoginName,
          expectedDigest: expectedEnvelopeDigest,
          envelope: envelope,
        );
      } on StateError {
        final raced = await read();
        if (raced != null) {
          var retainRaced = false;
          try {
            if (_sameCheckpoint(raced.checkpoint, checkpoint)) {
              retainRaced = true;
              return raced;
            }
          } finally {
            if (!retainRaced) raced.clearSensitiveState();
          }
        }
        rethrow;
      }
      return E2eeAccountRecoveryCheckpointSnapshot(
        checkpoint: checkpoint.detachedCopy(),
        envelopeDigest: _digest(envelope),
      );
    } finally {
      _clear(envelope);
    }
  }

  @override
  Future<bool> delete(E2eeAccountRecoveryCheckpointSnapshot snapshot) {
    return _deviceStateStore.deletePendingAccountRecoveryEnvelope(
      normalizedBaseUrl: _normalizedBaseUrl,
      normalizedLoginName: _normalizedLoginName,
      expectedDigest: snapshot.envelopeDigest,
    );
  }

  Future<Uint8List> _seal(E2eeAccountRecoveryCheckpoint checkpoint) async {
    final plaintext = _encodeCheckpoint(checkpoint);
    try {
      final envelope = await _secureCore.sealRecord(
        _key,
        recordId: _recordId,
        epoch: _checkpointRecordEpoch,
        associatedData: _associatedData,
        plaintext: plaintext,
      );
      if (envelope.length >
          DeviceStateBlobStore.pendingAccountRecoveryEnvelopeMaxLength) {
        envelope.fillRange(0, envelope.length, 0);
        throw const FormatException('账户恢复 checkpoint 密文超过存储上限');
      }
      return envelope;
    } finally {
      _clear(plaintext);
    }
  }
}

bool _sameCheckpoint(
  E2eeAccountRecoveryCheckpoint left,
  E2eeAccountRecoveryCheckpoint right,
) {
  final leftFrame = _encodeCheckpoint(left);
  final rightFrame = _encodeCheckpoint(right);
  try {
    return _sameBytes(leftFrame, rightFrame);
  } finally {
    _clear(leftFrame);
    _clear(rightFrame);
  }
}

Uint8List _encodeCheckpoint(E2eeAccountRecoveryCheckpoint checkpoint) {
  final writer = _CheckpointWriter();
  writer.bytes(_checkpointMagic);
  writer.uint32(_checkpointVersion);
  writer.uint32(_phaseCode(checkpoint.phase));
  writer.uuid(checkpoint.expectedDeviceId);
  writer.fixedAscii(checkpoint.recoveryToken.value, _checkpointTokenLength);
  _writeChallenge(writer, checkpoint.challenge);
  _writeProgress(writer, checkpoint.progress);
  return writer.takeBytes();
}

E2eeAccountRecoveryCheckpoint _decodeCheckpoint(Uint8List frame) {
  final reader = _CheckpointReader(frame);
  if (!_sameBytes(reader.bytes(_checkpointMagic.length), _checkpointMagic)) {
    throw const FormatException('账户恢复 checkpoint magic 无效');
  }
  if (reader.uint32() != _checkpointVersion) {
    throw const FormatException('账户恢复 checkpoint 版本无效');
  }
  final phase = _parsePhase(reader.uint32());
  final expectedDeviceId = reader.uuid();
  final recoveryToken = CloudSyncAccountRecoveryToken.parse(
    reader.fixedAscii(_checkpointTokenLength),
  );
  final challenge = _readChallenge(reader);
  E2eeAccountRecoveryCheckpointProgress? progress;
  try {
    progress = _readProgress(reader, phase, attemptId: challenge.attemptId);
    reader.requireEnd();
    return E2eeAccountRecoveryCheckpoint.restore(
      expectedDeviceId: expectedDeviceId,
      recoveryToken: recoveryToken,
      challenge: challenge,
      progress: progress,
    );
  } catch (_) {
    _clearProgressContinuation(progress);
    rethrow;
  }
}

void _writeChallenge(
  _CheckpointWriter writer,
  E2eeAccountRecoveryChallenge challenge,
) {
  writer.uuid(challenge.attemptId);
  writer.bytes(challenge.requestDigest);
  writer.bytes(challenge.challengeFrame);
  writer.bytes(challenge.sealedNonce);
  writer.uint32(challenge.securityGeneration);
  writer.uint32(challenge.keyEpoch);
  writer.bytes(challenge.membershipManifestDigest);
  writer.uint32(challenge.recoveryPublicKeyVersion);
  writer.bytes(challenge.recoveryPublicKey);
  writer.uint32(challenge.recoveryCapsuleVersion);
  writer.variableBytes(
    challenge.recoveryCapsule,
    maximum: _checkpointCapsuleMaximumLength,
  );
  writer.bytes(challenge.recoveryCapsuleDigest);
  switch (challenge.dataState.phase) {
    case E2eeAccountRecoveryDataPhase.ready:
      writer.uint32(1);
      writer.uint32(challenge.dataState.dataGeneration);
      writer.uint32(challenge.dataState.dataKeyEpoch);
    case E2eeAccountRecoveryDataPhase.rekeyPending:
      writer.uint32(2);
      writer.uint32(challenge.dataState.dataGeneration);
      writer.uint32(challenge.dataState.dataKeyEpoch);
      writer.uuid(challenge.dataState.operationId!);
      writer.uint32(challenge.dataState.targetKeyEpoch!);
  }
  writer.timestamp(challenge.expiresAt);
}

E2eeAccountRecoveryChallenge _readChallenge(_CheckpointReader reader) {
  final attemptId = reader.uuid();
  final requestDigest = reader.bytes(32);
  final challengeFrame = reader.bytes(e2eeAccountRecoveryChallengeFrameBytes);
  final sealedNonce = reader.bytes(e2eeAccountRecoverySealedNonceBytes);
  final securityGeneration = reader.uint32();
  final keyEpoch = reader.uint32();
  final membershipManifestDigest = reader.bytes(32);
  final recoveryPublicKeyVersion = reader.uint32();
  final recoveryPublicKey = reader.bytes(cloudSyncRecoveryPublicKeyBytes);
  final recoveryCapsuleVersion = reader.uint32();
  final recoveryCapsule = reader.variableBytes(
    minimum: 1,
    maximum: _checkpointCapsuleMaximumLength,
  );
  final recoveryCapsuleDigest = reader.bytes(32);
  final dataPhase = reader.uint32();
  final dataGeneration = reader.uint32();
  final dataKeyEpoch = reader.uint32();
  final dataState = switch (dataPhase) {
    1 => E2eeAccountRecoveryDataState.ready(
      dataGeneration: dataGeneration,
      dataKeyEpoch: dataKeyEpoch,
    ),
    2 => E2eeAccountRecoveryDataState.rekeyPending(
      dataGeneration: dataGeneration,
      dataKeyEpoch: dataKeyEpoch,
      operationId: reader.uuid(),
      targetKeyEpoch: reader.uint32(),
    ),
    _ => throw const FormatException('账户恢复 checkpoint 数据阶段无效'),
  };
  final expiresAt = reader.timestamp();
  try {
    return E2eeAccountRecoveryChallenge(
      attemptId: attemptId,
      requestDigest: requestDigest,
      challengeFrame: challengeFrame,
      sealedNonce: sealedNonce,
      securityGeneration: securityGeneration,
      keyEpoch: keyEpoch,
      membershipManifestDigest: membershipManifestDigest,
      recoveryPublicKeyVersion: recoveryPublicKeyVersion,
      recoveryPublicKey: recoveryPublicKey,
      recoveryCapsuleVersion: recoveryCapsuleVersion,
      recoveryCapsule: recoveryCapsule,
      recoveryCapsuleDigest: recoveryCapsuleDigest,
      dataState: dataState,
      expiresAt: expiresAt,
    );
  } finally {
    _clear(requestDigest);
    _clear(challengeFrame);
    _clear(sealedNonce);
    _clear(membershipManifestDigest);
    _clear(recoveryPublicKey);
    _clear(recoveryCapsule);
    _clear(recoveryCapsuleDigest);
  }
}

void _writeProgress(
  _CheckpointWriter writer,
  E2eeAccountRecoveryCheckpointProgress progress,
) {
  switch (progress) {
    case E2eeAccountRecoveryChallengedProgress():
      return;
    case E2eeAccountRecoveryProofReadyProgress(:final proof):
      _writeProof(writer, proof);
    case E2eeAccountRecoveryAuthorizedProgress(:final authorization):
      _writeAuthorization(writer, authorization);
    case E2eeAccountRecoveryResumePreparedProgress(
      :final authorization,
      :final transition,
    ):
      _writeAuthorization(writer, authorization);
      _writeTransition(writer, transition);
    case E2eeAccountRecoveryResumeCommittedProgress(
      :final authorization,
      :final transition,
      :final receipt,
    ):
      _writeAuthorization(writer, authorization);
      _writeTransition(writer, transition);
      _writeReceipt(writer, receipt);
    case E2eeAccountRecoveryFirstRekeyFinalizedProgress(
      :final authorization,
      :final transition,
      :final receipt,
      :final completion,
    ):
      _writeAuthorization(writer, authorization);
      _writeTransition(writer, transition);
      _writeReceipt(writer, receipt);
      _writeCompletion(writer, completion);
    case E2eeAccountRecoveryFirstLocalActivatedProgress(
      :final authorization,
      :final resumeReceipt,
      :final completion,
      :final reopenBinding,
    ):
      _writeAuthorization(writer, authorization);
      _writeReceipt(writer, resumeReceipt);
      _writeCompletion(writer, completion);
      _writeReopenBinding(writer, reopenBinding);
    case E2eeAccountRecoveryReplacementChallengeRequestedProgress(
      :final authorization,
      :final resumeReceipt,
      :final completion,
      :final request,
      :final reopenBinding,
    ):
      _writeAuthorization(writer, authorization);
      _writeReceipt(writer, resumeReceipt);
      _writeCompletion(writer, completion);
      _writeReplacementChallengeRequest(writer, request);
      _writeReopenBinding(writer, reopenBinding);
    case E2eeAccountRecoveryReplacementChallengeReceivedProgress(
      :final authorization,
      :final challenge,
      :final reopenBinding,
    ):
      _writeAuthorization(writer, authorization);
      _writeReplacementChallenge(writer, challenge);
      _writeReopenBinding(writer, reopenBinding);
    case E2eeAccountRecoveryReplacementProofReadyProgress(
      :final authorization,
      :final challenge,
      :final proof,
      :final reopenBinding,
    ):
      _writeAuthorization(writer, authorization);
      _writeReplacementChallenge(writer, challenge);
      _writeProof(writer, proof);
      _writeReopenBinding(writer, reopenBinding);
    case E2eeAccountRecoveryReplacementPreparedProgress(
      :final authorization,
      :final transition,
      :final reopenBinding,
    ):
      _writeAuthorization(writer, authorization);
      _writeTransition(writer, transition);
      _writeOptionalReopenBinding(writer, reopenBinding);
    case E2eeAccountRecoveryReplacementCommittedProgress(
      :final authorization,
      :final transition,
      :final receipt,
      :final reopenBinding,
    ):
      _writeAuthorization(writer, authorization);
      _writeTransition(writer, transition);
      _writeReceipt(writer, receipt);
      _writeOptionalReopenBinding(writer, reopenBinding);
    case E2eeAccountRecoverySecondRekeyFinalizedProgress(
      :final authorization,
      :final transition,
      :final receipt,
      :final completion,
      :final reopenBinding,
    ):
      _writeAuthorization(writer, authorization);
      _writeTransition(writer, transition);
      _writeReceipt(writer, receipt);
      _writeCompletion(writer, completion);
      _writeOptionalReopenBinding(writer, reopenBinding);
    case E2eeAccountRecoverySecondLocalActivatedProgress(
      :final authorization,
      :final completionSession,
      :final replacementReceipt,
      :final completion,
      :final reopenBinding,
    ):
      _writeAuthorization(writer, authorization);
      _writeCompletionSession(writer, completionSession);
      _writeReceipt(writer, replacementReceipt);
      _writeCompletion(writer, completion);
      _writeReopenBinding(writer, reopenBinding);
    case E2eeAccountRecoverySessionVerifiedProgress(
      :final authorization,
      :final completionSession,
      :final replacementReceipt,
      :final completion,
      :final reopenBinding,
      :final sessionGeneration,
      :final tokenExpiresAt,
    ):
      _writeAuthorization(writer, authorization);
      _writeCompletionSession(writer, completionSession);
      _writeReceipt(writer, replacementReceipt);
      _writeCompletion(writer, completion);
      _writeReopenBinding(writer, reopenBinding);
      writer.uint32(sessionGeneration);
      writer.unixSeconds(tokenExpiresAt);
  }
}

E2eeAccountRecoveryCheckpointProgress _readProgress(
  _CheckpointReader reader,
  E2eeAccountRecoveryCheckpointPhase phase, {
  required String attemptId,
}) {
  switch (phase) {
    case E2eeAccountRecoveryCheckpointPhase.challenged:
      return const E2eeAccountRecoveryChallengedProgress();
    case E2eeAccountRecoveryCheckpointPhase.proofReady:
      return E2eeAccountRecoveryProofReadyProgress(_readProof(reader));
    case E2eeAccountRecoveryCheckpointPhase.authorized:
      return E2eeAccountRecoveryAuthorizedProgress(_readAuthorization(reader));
    case E2eeAccountRecoveryCheckpointPhase.resumePrepared:
      final authorization = _readAuthorization(reader);
      final transition = _readTransition(reader, attemptId: attemptId);
      return _finishReadingTransition(
        transition,
        () => E2eeAccountRecoveryResumePreparedProgress(
          authorization: authorization,
          transition: transition,
        ),
      );
    case E2eeAccountRecoveryCheckpointPhase.resumeCommitted:
      final authorization = _readAuthorization(reader);
      final transition = _readTransition(reader, attemptId: attemptId);
      return _finishReadingTransition(
        transition,
        () => E2eeAccountRecoveryResumeCommittedProgress(
          authorization: authorization,
          transition: transition,
          receipt: _readReceipt(reader),
        ),
      );
    case E2eeAccountRecoveryCheckpointPhase.firstRekeyFinalized:
      final authorization = _readAuthorization(reader);
      final transition = _readTransition(reader, attemptId: attemptId);
      return _finishReadingTransition(
        transition,
        () => E2eeAccountRecoveryFirstRekeyFinalizedProgress(
          authorization: authorization,
          transition: transition,
          receipt: _readReceipt(reader),
          completion: _readCompletion(reader),
        ),
      );
    case E2eeAccountRecoveryCheckpointPhase.firstLocalActivated:
      return E2eeAccountRecoveryFirstLocalActivatedProgress(
        authorization: _readAuthorization(reader),
        resumeReceipt: _readReceipt(reader),
        completion: _readCompletion(reader),
        reopenBinding: _readReopenBinding(reader),
      );
    case E2eeAccountRecoveryCheckpointPhase.replacementChallengeRequested:
      return E2eeAccountRecoveryReplacementChallengeRequestedProgress(
        authorization: _readAuthorization(reader),
        resumeReceipt: _readReceipt(reader),
        completion: _readCompletion(reader),
        request: _readReplacementChallengeRequest(reader),
        reopenBinding: _readReopenBinding(reader),
      );
    case E2eeAccountRecoveryCheckpointPhase.replacementChallengeReceived:
      return E2eeAccountRecoveryReplacementChallengeReceivedProgress(
        authorization: _readAuthorization(reader),
        challenge: _readReplacementChallenge(reader),
        reopenBinding: _readReopenBinding(reader),
      );
    case E2eeAccountRecoveryCheckpointPhase.replacementProofReady:
      return E2eeAccountRecoveryReplacementProofReadyProgress(
        authorization: _readAuthorization(reader),
        challenge: _readReplacementChallenge(reader),
        proof: _readProof(reader),
        reopenBinding: _readReopenBinding(reader),
      );
    case E2eeAccountRecoveryCheckpointPhase.replacementPrepared:
      final authorization = _readAuthorization(reader);
      final transition = _readTransition(reader, attemptId: attemptId);
      return _finishReadingTransition(
        transition,
        () => E2eeAccountRecoveryReplacementPreparedProgress(
          authorization: authorization,
          transition: transition,
          reopenBinding: _readOptionalReopenBinding(reader),
        ),
      );
    case E2eeAccountRecoveryCheckpointPhase.replacementCommitted:
      final authorization = _readAuthorization(reader);
      final transition = _readTransition(reader, attemptId: attemptId);
      return _finishReadingTransition(
        transition,
        () => E2eeAccountRecoveryReplacementCommittedProgress(
          authorization: authorization,
          transition: transition,
          receipt: _readReceipt(reader),
          reopenBinding: _readOptionalReopenBinding(reader),
        ),
      );
    case E2eeAccountRecoveryCheckpointPhase.secondRekeyFinalized:
      final authorization = _readAuthorization(reader);
      final transition = _readTransition(reader, attemptId: attemptId);
      return _finishReadingTransition(
        transition,
        () => E2eeAccountRecoverySecondRekeyFinalizedProgress(
          authorization: authorization,
          transition: transition,
          receipt: _readReceipt(reader),
          completion: _readCompletion(reader),
          reopenBinding: _readOptionalReopenBinding(reader),
        ),
      );
    case E2eeAccountRecoveryCheckpointPhase.secondLocalActivated:
      return E2eeAccountRecoverySecondLocalActivatedProgress(
        authorization: _readAuthorization(reader),
        completionSession: _readCompletionSession(reader),
        replacementReceipt: _readReceipt(reader),
        completion: _readCompletion(reader),
        reopenBinding: _readReopenBinding(reader),
      );
    case E2eeAccountRecoveryCheckpointPhase.sessionVerified:
      return E2eeAccountRecoverySessionVerifiedProgress(
        authorization: _readAuthorization(reader),
        completionSession: _readCompletionSession(reader),
        replacementReceipt: _readReceipt(reader),
        completion: _readCompletion(reader),
        reopenBinding: _readReopenBinding(reader),
        sessionGeneration: reader.uint32(),
        tokenExpiresAt: reader.unixSeconds(),
      );
  }
}

void _writeProof(
  _CheckpointWriter writer,
  E2eeAccountRecoveryCheckpointProof proof,
) {
  final nonceProof = proof.copyNonceProof();
  final trustSignature = proof.copyTrustSignature();
  try {
    writer.bytes(nonceProof);
    writer.bytes(trustSignature);
  } finally {
    _clear(nonceProof);
    _clear(trustSignature);
  }
}

E2eeAccountRecoveryCheckpointProof _readProof(_CheckpointReader reader) {
  return E2eeAccountRecoveryCheckpointProof.take(
    nonceProof: reader.bytes(e2eeAccountRecoveryNonceProofBytes),
    trustSignature: reader.bytes(e2eeAccountRecoveryTrustSignatureBytes),
  );
}

void _writeAuthorization(
  _CheckpointWriter writer,
  E2eeAccountRecoveryCheckpointAuthorization authorization,
) {
  _writeProof(writer, authorization.proof);
  writer.timestamp(authorization.recoveryTokenExpiresAt);
  writer.uint32(_nextActionCode(authorization.nextAction));
}

E2eeAccountRecoveryCheckpointAuthorization _readAuthorization(
  _CheckpointReader reader,
) {
  return E2eeAccountRecoveryCheckpointAuthorization(
    proof: _readProof(reader),
    recoveryTokenExpiresAt: reader.timestamp(),
    nextAction: _parseNextAction(reader.uint32()),
  );
}

void _writeOptionalReopenBinding(
  _CheckpointWriter writer,
  E2eeAccountRecoveryReopenBinding? binding,
) {
  writer.uint32(binding == null ? 0 : 1);
  if (binding != null) _writeReopenBinding(writer, binding);
}

E2eeAccountRecoveryReopenBinding? _readOptionalReopenBinding(
  _CheckpointReader reader,
) {
  return switch (reader.uint32()) {
    0 => null,
    1 => _readReopenBinding(reader),
    _ => throw const FormatException('账户恢复 checkpoint 重开绑定标记无效'),
  };
}

void _writeReopenBinding(
  _CheckpointWriter writer,
  E2eeAccountRecoveryReopenBinding binding,
) {
  final membershipDigest = binding.membershipManifestDigest;
  final stateDigest = binding.prunedStateDigest;
  try {
    writer.uuid(binding.userId);
    writer.uuid(binding.deviceId);
    writer.uint32(binding.deviceKeyVersion);
    writer.uint32(binding.deviceAuthGeneration);
    writer.uint32(binding.keyEpoch);
    writer.uint32(binding.dataGeneration);
    writer.uint32(binding.membershipGeneration);
    writer.bytes(membershipDigest);
    writer.uuid(binding.membershipOperationId);
    writer.bytes(stateDigest);
  } finally {
    _clear(membershipDigest);
    _clear(stateDigest);
  }
}

E2eeAccountRecoveryReopenBinding _readReopenBinding(_CheckpointReader reader) {
  final userId = reader.uuid();
  final deviceId = reader.uuid();
  final deviceKeyVersion = reader.uint32();
  final deviceAuthGeneration = reader.uint32();
  final keyEpoch = reader.uint32();
  final dataGeneration = reader.uint32();
  final membershipGeneration = reader.uint32();
  final membershipDigest = reader.bytes(cloudSyncMembershipManifestDigestBytes);
  final membershipOperationId = reader.uuid();
  final stateDigest = reader.bytes(32);
  try {
    return E2eeAccountRecoveryReopenBinding(
      userId: userId,
      deviceId: deviceId,
      deviceKeyVersion: deviceKeyVersion,
      deviceAuthGeneration: deviceAuthGeneration,
      keyEpoch: keyEpoch,
      dataGeneration: dataGeneration,
      membershipGeneration: membershipGeneration,
      membershipManifestDigest: membershipDigest,
      membershipOperationId: membershipOperationId,
      prunedStateDigest: stateDigest,
    );
  } finally {
    _clear(membershipDigest);
    _clear(stateDigest);
  }
}

void _writeTransition(
  _CheckpointWriter writer,
  E2eeAccountRecoveryPreparedTransition transition,
) {
  _writePreparedCommit(writer, transition.commit);
  _writeLocalTransitionPlan(writer, transition.localTransitionPlan);
}

E2eeAccountRecoveryPreparedTransition _readTransition(
  _CheckpointReader reader, {
  required String attemptId,
}) {
  final commit = _readPreparedCommit(reader, attemptId: attemptId);
  E2eeAccountRecoveryLocalTransitionPlan? plan;
  try {
    plan = _readLocalTransitionPlan(reader);
    return E2eeAccountRecoveryPreparedTransition(
      commit: commit,
      localTransitionPlan: plan,
    );
  } catch (_) {
    plan?.clearContinuation();
    rethrow;
  }
}

T _finishReadingTransition<T>(
  E2eeAccountRecoveryPreparedTransition transition,
  T Function() readTail,
) {
  try {
    return readTail();
  } catch (_) {
    transition.clearContinuation();
    rethrow;
  }
}

void _clearProgressContinuation(
  E2eeAccountRecoveryCheckpointProgress? progress,
) {
  switch (progress) {
    case E2eeAccountRecoveryResumePreparedProgress(:final transition):
    case E2eeAccountRecoveryResumeCommittedProgress(:final transition):
    case E2eeAccountRecoveryFirstRekeyFinalizedProgress(:final transition):
    case E2eeAccountRecoveryReplacementPreparedProgress(:final transition):
    case E2eeAccountRecoveryReplacementCommittedProgress(:final transition):
    case E2eeAccountRecoverySecondRekeyFinalizedProgress(:final transition):
      transition.clearContinuation();
    default:
      return;
  }
}

void _writePreparedCommit(
  _CheckpointWriter writer,
  E2eeAccountRecoveryPreparedCommit commit,
) {
  writer.uint32(commit.kind == E2eeAccountRecoveryCommitKind.resume ? 1 : 2);
  final membership = commit.membership;
  writer.uint32(membership.expectedGeneration);
  writer.uint32(membership.expectedKeyEpoch);
  writer.bytes(membership.expectedMembershipManifestDigest.bytes);
  writer.uuid(membership.operationId);
  writer.variableBytes(
    membership.nextMembershipManifest,
    minimum: cloudSyncMembershipManifestMinimumBytes,
    maximum: cloudSyncMembershipManifestMaximumBytes,
  );
  writer.bytes(membership.nextMembershipManifestDigest.bytes);
  writer.uint32(membership.envelope.envelopeVersion);
  writer.uint32(membership.envelope.keyEpoch);
  writer.bytes(membership.envelope.accountKeyEnvelope);
  switch (commit) {
    case E2eeAccountRecoveryResumeCommit(:final rekeyOperationId):
      writer.uuid(rekeyOperationId);
    case E2eeAccountRecoveryReplacementCommit(
      :final authorization,
      :final nextRecoveryCapsuleVersion,
      :final nextRecoveryCapsule,
      :final completionSessionId,
      :final completionSessionToken,
    ):
      _writeReplacementAuthorization(writer, authorization);
      writer.uint32(nextRecoveryCapsuleVersion);
      writer.variableBytes(
        nextRecoveryCapsule,
        minimum: 1,
        maximum: cloudSyncRecoveryCapsuleMaximumBytes,
      );
      writer.uuid(completionSessionId);
      writer.fixedAscii(
        completionSessionToken.value,
        _checkpointFullSessionTokenLength,
      );
  }
}

E2eeAccountRecoveryPreparedCommit _readPreparedCommit(
  _CheckpointReader reader, {
  required String attemptId,
}) {
  final kind = reader.uint32();
  if (kind != 1 && kind != 2) {
    throw const FormatException('账户恢复 checkpoint 提交类型无效');
  }
  final expectedGeneration = reader.uint32();
  final expectedKeyEpoch = reader.uint32();
  final expectedManifestDigest = reader.bytes(32);
  final operationId = reader.uuid();
  final nextManifest = reader.variableBytes(
    minimum: cloudSyncMembershipManifestMinimumBytes,
    maximum: cloudSyncMembershipManifestMaximumBytes,
  );
  final nextManifestDigest = reader.bytes(32);
  final envelopeVersion = reader.uint32();
  final envelopeKeyEpoch = reader.uint32();
  final accountKeyEnvelope = reader.bytes(cloudSyncAccountKeyEnvelopeBytes);
  final membership = E2eeAccountRecoveryMembershipCommit(
    expectedGeneration: expectedGeneration,
    expectedKeyEpoch: expectedKeyEpoch,
    expectedMembershipManifestDigest:
        CloudSyncMembershipManifestDigest.fromBytes(expectedManifestDigest),
    operationId: operationId,
    nextMembershipManifest: nextManifest,
    nextMembershipManifestDigest: CloudSyncMembershipManifestDigest.fromBytes(
      nextManifestDigest,
    ),
    envelope: E2eeAccountRecoveryEnvelope(
      envelopeVersion: envelopeVersion,
      keyEpoch: envelopeKeyEpoch,
      accountKeyEnvelope: accountKeyEnvelope,
    ),
  );
  try {
    if (kind == 1) {
      return E2eeAccountRecoveryResumeCommit(
        attemptId: attemptId,
        membership: membership,
        rekeyOperationId: reader.uuid(),
      );
    }
    return E2eeAccountRecoveryReplacementCommit(
      attemptId: attemptId,
      membership: membership,
      authorization: _readReplacementAuthorization(reader),
      nextRecoveryCapsuleVersion: reader.uint32(),
      nextRecoveryCapsule: reader.variableBytes(
        minimum: 1,
        maximum: cloudSyncRecoveryCapsuleMaximumBytes,
      ),
      completionSessionId: reader.uuid(),
      completionSessionToken: CloudSyncFullSessionToken.parse(
        reader.fixedAscii(_checkpointFullSessionTokenLength),
      ),
    );
  } finally {
    _clear(expectedManifestDigest);
    _clear(nextManifest);
    _clear(nextManifestDigest);
    _clear(accountKeyEnvelope);
  }
}

void _writeReplacementAuthorization(
  _CheckpointWriter writer,
  E2eeAccountRecoveryReplacementAuthorization authorization,
) {
  switch (authorization) {
    case E2eeAccountRecoveryReplacementInitialAuthorization(
      :final challengeRequestDigest,
    ):
      writer.uint32(1);
      writer.bytes(challengeRequestDigest);
    case E2eeAccountRecoveryReplacementChallengeAuthorization(
      :final challengeId,
      :final challengeRequestDigest,
      :final nonceProof,
      :final trustSignature,
    ):
      writer.uint32(2);
      writer.uuid(challengeId);
      writer.bytes(challengeRequestDigest);
      writer.bytes(nonceProof);
      writer.bytes(trustSignature);
  }
}

E2eeAccountRecoveryReplacementAuthorization _readReplacementAuthorization(
  _CheckpointReader reader,
) {
  return switch (reader.uint32()) {
    1 => E2eeAccountRecoveryReplacementAuthorization.initial(
      challengeRequestDigest: reader.bytes(32),
    ),
    2 => E2eeAccountRecoveryReplacementAuthorization.replacementChallenge(
      challengeId: reader.uuid(),
      challengeRequestDigest: reader.bytes(32),
      nonceProof: reader.bytes(e2eeAccountRecoveryNonceProofBytes),
      trustSignature: reader.bytes(e2eeAccountRecoveryTrustSignatureBytes),
    ),
    _ => throw const FormatException('账户恢复 checkpoint replacement 授权无效'),
  };
}

void _writeLocalTransitionPlan(
  _CheckpointWriter writer,
  E2eeAccountRecoveryLocalTransitionPlan plan,
) {
  final source = plan.sourceStateBlob;
  final unpruned = plan.unprunedStateBlob;
  final pruned = plan.prunedStateBlob;
  final authorizationDigest = plan.operationAuthorizationDigest;
  final continuation = plan.copyContinuation();
  try {
    writer.bytes(source);
    writer.bytes(unpruned);
    writer.bytes(pruned);
    writer.uint32(plan.deviceKeyVersion);
    writer.uuid(plan.userId);
    writer.uint32(plan.sourceDataGeneration);
    writer.bytes(authorizationDigest);
    writer.bytes(continuation);
  } finally {
    _clear(source);
    _clear(unpruned);
    _clear(pruned);
    _clear(authorizationDigest);
    _clear(continuation);
  }
}

E2eeAccountRecoveryLocalTransitionPlan _readLocalTransitionPlan(
  _CheckpointReader reader,
) {
  final source = reader.bytes(DeviceStateBlobStore.blobLength);
  final unpruned = reader.bytes(DeviceStateBlobStore.blobLength);
  final pruned = reader.bytes(DeviceStateBlobStore.blobLength);
  final deviceKeyVersion = reader.uint32();
  final userId = reader.uuid();
  final sourceDataGeneration = reader.uint32();
  final authorizationDigest = reader.bytes(
    cloudSyncMembershipManifestDigestBytes,
  );
  final continuation = reader.bytes(e2eeAccountRecoveryNativeContinuationBytes);
  try {
    return E2eeAccountRecoveryLocalTransitionPlan(
      sourceStateBlob: source,
      unprunedStateBlob: unpruned,
      prunedStateBlob: pruned,
      deviceKeyVersion: deviceKeyVersion,
      userId: userId,
      sourceDataGeneration: sourceDataGeneration,
      operationAuthorizationDigest: authorizationDigest,
      continuation: continuation,
    );
  } finally {
    _clear(source);
    _clear(unpruned);
    _clear(pruned);
    _clear(authorizationDigest);
    _clear(continuation);
  }
}

void _writeReceipt(
  _CheckpointWriter writer,
  E2eeAccountRecoveryCommitReceipt receipt,
) {
  writer.uint32(
    receipt.result == E2eeAccountRecoveryCommitResult.committed ? 1 : 2,
  );
  writer.uint32(receipt.kind == E2eeAccountRecoveryCommitKind.resume ? 1 : 2);
  writer.uuid(receipt.attemptId);
  writer.uuid(receipt.membershipOperationId);
  writer.uuid(receipt.rekeyOperationId);
  writer.uint32(receipt.generation);
  writer.uint32(receipt.keyEpoch);
  writer.uint32(_nextActionCode(receipt.nextAction));
}

E2eeAccountRecoveryCommitReceipt _readReceipt(_CheckpointReader reader) {
  final result = switch (reader.uint32()) {
    1 => E2eeAccountRecoveryCommitResult.committed,
    2 => E2eeAccountRecoveryCommitResult.replayed,
    _ => throw const FormatException('账户恢复 checkpoint 回执结果无效'),
  };
  final kind = switch (reader.uint32()) {
    1 => E2eeAccountRecoveryCommitKind.resume,
    2 => E2eeAccountRecoveryCommitKind.replacement,
    _ => throw const FormatException('账户恢复 checkpoint 回执类型无效'),
  };
  return E2eeAccountRecoveryCommitReceipt(
    result: result,
    kind: kind,
    attemptId: reader.uuid(),
    membershipOperationId: reader.uuid(),
    rekeyOperationId: reader.uuid(),
    generation: reader.uint32(),
    keyEpoch: reader.uint32(),
    nextAction: _parseNextAction(reader.uint32()),
  );
}

void _writeCompletion(
  _CheckpointWriter writer,
  CloudSyncDataRekeyCompletion completion,
) {
  writer.uint32(completion.proofVersion);
  writer.uuid(completion.operationId);
  writer.uuid(completion.issuerDeviceId);
  writer.uint32(completion.sourceDataGeneration);
  writer.uint32(completion.targetDataGeneration);
  writer.uint32(completion.sourceKeyEpoch);
  writer.uint32(completion.targetKeyEpoch);
  writer.bytes(completion.sourceSnapshotRoot);
  writer.uint32(completion.sourceRecordCount);
  writer.uint32(completion.sourceAttachmentCount);
  writer.uint64(completion.sourceMaximumChangeSeq);
  writer.optionalUuid(completion.sourceRecordCursorEnd);
  final attachmentCursor = completion.sourceAttachmentCursorEnd;
  writer.uint32(attachmentCursor == null ? 0 : 1);
  if (attachmentCursor != null) {
    writer.uuid(attachmentCursor.attachmentId);
    writer.uuid(attachmentCursor.uploadId);
  }
  writer.uint32(completion.membershipGeneration);
  writer.bytes(completion.membershipManifestDigest);
  writer.uint32(completion.stagedRecordCount);
  writer.uint32(completion.stagedAttachmentCount);
  writer.bytes(completion.stagedCiphertextSetDigest);
  writer.bytes(completion.proofFrame);
  writer.bytes(completion.proofDigest);
  writer.bytes(completion.signature);
  writer.timestamp(completion.finalizedAt);
}

CloudSyncDataRekeyCompletion _readCompletion(_CheckpointReader reader) {
  final proofVersion = reader.uint32();
  final operationId = reader.uuid();
  final issuerDeviceId = reader.uuid();
  final sourceDataGeneration = reader.uint32();
  final targetDataGeneration = reader.uint32();
  final sourceKeyEpoch = reader.uint32();
  final targetKeyEpoch = reader.uint32();
  final sourceSnapshotRoot = reader.bytes(cloudSyncDataRekeyDigestBytes);
  final sourceRecordCount = reader.uint32();
  final sourceAttachmentCount = reader.uint32();
  final sourceMaximumChangeSeq = reader.uint64();
  final sourceRecordCursorEnd = reader.optionalUuid();
  final attachmentMarker = reader.uint32();
  final CloudSyncJsonMap? sourceAttachmentCursorEnd;
  if (attachmentMarker == 0) {
    sourceAttachmentCursorEnd = null;
  } else if (attachmentMarker == 1) {
    sourceAttachmentCursorEnd = <String, Object?>{
      'attachmentId': reader.uuid(),
      'uploadId': reader.uuid(),
    };
  } else {
    throw const FormatException('账户恢复 checkpoint 附件游标标记无效');
  }
  final membershipGeneration = reader.uint32();
  final membershipManifestDigest = reader.bytes(cloudSyncDataRekeyDigestBytes);
  final stagedRecordCount = reader.uint32();
  final stagedAttachmentCount = reader.uint32();
  final stagedCiphertextSetDigest = reader.bytes(cloudSyncDataRekeyDigestBytes);
  final proofFrame = reader.bytes(cloudSyncDataRekeyProofFrameBytes);
  final proofDigest = reader.bytes(cloudSyncDataRekeyDigestBytes);
  final signature = reader.bytes(cloudSyncDeviceProofBytes);
  final finalizedAt = reader.timestamp();
  try {
    return CloudSyncDataRekeyCompletion.fromJson(<String, Object?>{
      'proofVersion': proofVersion,
      'operationId': operationId,
      'issuerDeviceId': issuerDeviceId,
      'sourceDataGeneration': sourceDataGeneration,
      'targetDataGeneration': targetDataGeneration,
      'sourceKeyEpoch': sourceKeyEpoch,
      'targetKeyEpoch': targetKeyEpoch,
      'sourceSnapshotRoot': _encodedData(sourceSnapshotRoot),
      'sourceRecordCount': sourceRecordCount,
      'sourceAttachmentCount': sourceAttachmentCount,
      'sourceMaximumChangeSeq': sourceMaximumChangeSeq,
      'sourceRecordCursorEnd': sourceRecordCursorEnd,
      'sourceAttachmentCursorEnd': sourceAttachmentCursorEnd,
      'membershipGeneration': membershipGeneration,
      'membershipManifestDigest': _encodedData(membershipManifestDigest),
      'stagedRecordCount': stagedRecordCount,
      'stagedAttachmentCount': stagedAttachmentCount,
      'stagedCiphertextSetDigest': _encodedData(stagedCiphertextSetDigest),
      'proofFrame': _encodedData(proofFrame),
      'proofDigest': _encodedData(proofDigest),
      'signature': _encodedData(signature),
      'finalizedAt': finalizedAt.toIso8601String(),
    });
  } finally {
    _clear(sourceSnapshotRoot);
    _clear(membershipManifestDigest);
    _clear(stagedCiphertextSetDigest);
    _clear(proofFrame);
    _clear(proofDigest);
    _clear(signature);
  }
}

void _writeReplacementChallengeRequest(
  _CheckpointWriter writer,
  E2eeAccountRecoveryReplacementChallengeRequest request,
) {
  writer.uuid(request.challengeId);
  writer.uint32(request.expectedGeneration);
  writer.uint32(request.expectedKeyEpoch);
  writer.bytes(request.expectedMembershipManifestDigest);
  writer.uuid(request.expectedMembershipOperationId);
  writer.uint32(request.dataGeneration);
  writer.uint32(request.dataKeyEpoch);
  writer.uuid(request.sourceRekeyOperationId);
  writer.bytes(request.sourceCompletionProofDigest);
}

E2eeAccountRecoveryReplacementChallengeRequest _readReplacementChallengeRequest(
  _CheckpointReader reader,
) {
  return E2eeAccountRecoveryReplacementChallengeRequest(
    challengeId: reader.uuid(),
    expectedGeneration: reader.uint32(),
    expectedKeyEpoch: reader.uint32(),
    expectedMembershipManifestDigest: reader.bytes(32),
    expectedMembershipOperationId: reader.uuid(),
    dataGeneration: reader.uint32(),
    dataKeyEpoch: reader.uint32(),
    sourceRekeyOperationId: reader.uuid(),
    sourceCompletionProofDigest: reader.bytes(32),
  );
}

void _writeReplacementChallenge(
  _CheckpointWriter writer,
  E2eeAccountRecoveryReplacementChallenge challenge,
) {
  writer.uint32(
    challenge.result == E2eeAccountRecoveryReplacementChallengeResult.created
        ? 1
        : 2,
  );
  writer.uuid(challenge.challengeId);
  writer.uuid(challenge.attemptId);
  writer.bytes(challenge.requestDigest);
  writer.bytes(challenge.challengeFrame);
  writer.bytes(challenge.sealedNonce);
  writer.uint32(challenge.deviceKeyVersion);
  writer.bytes(challenge.deviceSigningPublicKey);
  writer.bytes(challenge.deviceKeyAgreementPublicKey);
  writer.uint32(challenge.securityGeneration);
  writer.uint32(challenge.keyEpoch);
  writer.variableBytes(
    challenge.membershipManifest,
    minimum: cloudSyncMembershipManifestMinimumBytes,
    maximum: cloudSyncMembershipManifestMaximumBytes,
  );
  writer.bytes(challenge.membershipManifestDigest);
  writer.uuid(challenge.membershipOperationId);
  writer.uint32(challenge.recoveryPublicKeyVersion);
  writer.bytes(challenge.recoveryPublicKey);
  writer.uint32(challenge.recoveryCapsuleVersion);
  writer.variableBytes(
    challenge.recoveryCapsule,
    minimum: 1,
    maximum: cloudSyncRecoveryCapsuleMaximumBytes,
  );
  writer.bytes(challenge.recoveryCapsuleDigest);
  writer.uint32(challenge.dataGeneration);
  writer.uint32(challenge.dataKeyEpoch);
  writer.uuid(challenge.sourceRekeyOperationId);
  _writeCompletion(writer, challenge.sourceCompletion);
  writer.timestamp(challenge.expiresAt);
}

E2eeAccountRecoveryReplacementChallenge _readReplacementChallenge(
  _CheckpointReader reader,
) {
  final result = switch (reader.uint32()) {
    1 => E2eeAccountRecoveryReplacementChallengeResult.created,
    2 => E2eeAccountRecoveryReplacementChallengeResult.replayed,
    _ => throw const FormatException('账户恢复 checkpoint 第二 challenge 结果无效'),
  };
  return E2eeAccountRecoveryReplacementChallenge(
    result: result,
    challengeId: reader.uuid(),
    attemptId: reader.uuid(),
    requestDigest: reader.bytes(32),
    challengeFrame: reader.bytes(
      e2eeAccountRecoveryReplacementChallengeFrameBytes,
    ),
    sealedNonce: reader.bytes(e2eeAccountRecoverySealedNonceBytes),
    deviceKeyVersion: reader.uint32(),
    deviceSigningPublicKey: reader.bytes(cloudSyncDevicePublicKeyBytes),
    deviceKeyAgreementPublicKey: reader.bytes(cloudSyncDevicePublicKeyBytes),
    securityGeneration: reader.uint32(),
    keyEpoch: reader.uint32(),
    membershipManifest: reader.variableBytes(
      minimum: cloudSyncMembershipManifestMinimumBytes,
      maximum: cloudSyncMembershipManifestMaximumBytes,
    ),
    membershipManifestDigest: reader.bytes(32),
    membershipOperationId: reader.uuid(),
    recoveryPublicKeyVersion: reader.uint32(),
    recoveryPublicKey: reader.bytes(cloudSyncRecoveryPublicKeyBytes),
    recoveryCapsuleVersion: reader.uint32(),
    recoveryCapsule: reader.variableBytes(
      minimum: 1,
      maximum: cloudSyncRecoveryCapsuleMaximumBytes,
    ),
    recoveryCapsuleDigest: reader.bytes(32),
    dataGeneration: reader.uint32(),
    dataKeyEpoch: reader.uint32(),
    sourceRekeyOperationId: reader.uuid(),
    sourceCompletion: _readCompletion(reader),
    expiresAt: reader.timestamp(),
  );
}

void _writeCompletionSession(
  _CheckpointWriter writer,
  E2eeAccountRecoveryCompletionSession session,
) {
  writer.uuid(session.sessionId);
  writer.fixedAscii(session.token.value, _checkpointFullSessionTokenLength);
}

E2eeAccountRecoveryCompletionSession _readCompletionSession(
  _CheckpointReader reader,
) {
  return E2eeAccountRecoveryCompletionSession(
    sessionId: reader.uuid(),
    token: CloudSyncFullSessionToken.parse(
      reader.fixedAscii(_checkpointFullSessionTokenLength),
    ),
  );
}

int _phaseCode(E2eeAccountRecoveryCheckpointPhase phase) => switch (phase) {
  E2eeAccountRecoveryCheckpointPhase.challenged => 1,
  E2eeAccountRecoveryCheckpointPhase.proofReady => 2,
  E2eeAccountRecoveryCheckpointPhase.authorized => 3,
  E2eeAccountRecoveryCheckpointPhase.resumePrepared => 4,
  E2eeAccountRecoveryCheckpointPhase.resumeCommitted => 5,
  E2eeAccountRecoveryCheckpointPhase.firstRekeyFinalized => 6,
  E2eeAccountRecoveryCheckpointPhase.firstLocalActivated => 7,
  E2eeAccountRecoveryCheckpointPhase.replacementChallengeRequested => 8,
  E2eeAccountRecoveryCheckpointPhase.replacementChallengeReceived => 9,
  E2eeAccountRecoveryCheckpointPhase.replacementProofReady => 10,
  E2eeAccountRecoveryCheckpointPhase.replacementPrepared => 11,
  E2eeAccountRecoveryCheckpointPhase.replacementCommitted => 12,
  E2eeAccountRecoveryCheckpointPhase.secondRekeyFinalized => 13,
  E2eeAccountRecoveryCheckpointPhase.secondLocalActivated => 14,
  E2eeAccountRecoveryCheckpointPhase.sessionVerified => 15,
};

E2eeAccountRecoveryCheckpointPhase _parsePhase(int value) => switch (value) {
  1 => E2eeAccountRecoveryCheckpointPhase.challenged,
  2 => E2eeAccountRecoveryCheckpointPhase.proofReady,
  3 => E2eeAccountRecoveryCheckpointPhase.authorized,
  4 => E2eeAccountRecoveryCheckpointPhase.resumePrepared,
  5 => E2eeAccountRecoveryCheckpointPhase.resumeCommitted,
  6 => E2eeAccountRecoveryCheckpointPhase.firstRekeyFinalized,
  7 => E2eeAccountRecoveryCheckpointPhase.firstLocalActivated,
  8 => E2eeAccountRecoveryCheckpointPhase.replacementChallengeRequested,
  9 => E2eeAccountRecoveryCheckpointPhase.replacementChallengeReceived,
  10 => E2eeAccountRecoveryCheckpointPhase.replacementProofReady,
  11 => E2eeAccountRecoveryCheckpointPhase.replacementPrepared,
  12 => E2eeAccountRecoveryCheckpointPhase.replacementCommitted,
  13 => E2eeAccountRecoveryCheckpointPhase.secondRekeyFinalized,
  14 => E2eeAccountRecoveryCheckpointPhase.secondLocalActivated,
  15 => E2eeAccountRecoveryCheckpointPhase.sessionVerified,
  _ => throw const FormatException('账户恢复 checkpoint 阶段无效'),
};

int _nextActionCode(E2eeAccountRecoveryNextAction action) => switch (action) {
  E2eeAccountRecoveryNextAction.recoverResume => 1,
  E2eeAccountRecoveryNextAction.recoverReplace => 2,
  E2eeAccountRecoveryNextAction.finishFirstDataRekey => 3,
  E2eeAccountRecoveryNextAction.finishSecondDataRekey => 4,
  E2eeAccountRecoveryNextAction.createReplacementChallenge => 5,
};

E2eeAccountRecoveryNextAction _parseNextAction(int value) => switch (value) {
  1 => E2eeAccountRecoveryNextAction.recoverResume,
  2 => E2eeAccountRecoveryNextAction.recoverReplace,
  3 => E2eeAccountRecoveryNextAction.finishFirstDataRekey,
  4 => E2eeAccountRecoveryNextAction.finishSecondDataRekey,
  5 => E2eeAccountRecoveryNextAction.createReplacementChallenge,
  _ => throw const FormatException('账户恢复 checkpoint 下一步无效'),
};

final class _CheckpointWriter {
  final BytesBuilder _builder = BytesBuilder(copy: true);

  void bytes(Uint8List value) {
    _builder.add(value);
  }

  void uint32(int value) {
    if (value < 0 || value > 0xffffffff) {
      throw const FormatException('账户恢复 checkpoint uint32 越界');
    }
    final bytes = Uint8List(4);
    ByteData.sublistView(bytes).setUint32(0, value, Endian.big);
    _builder.add(bytes);
  }

  void uint64(int value) {
    if (value < 0) {
      throw const FormatException('账户恢复 checkpoint uint64 越界');
    }
    final bytes = Uint8List(8);
    ByteData.sublistView(bytes).setUint64(0, value, Endian.big);
    _builder.add(bytes);
  }

  void timestamp(DateTime value) {
    uint64(value.toUtc().millisecondsSinceEpoch);
  }

  void unixSeconds(DateTime value) {
    uint64(
      value.toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond,
    );
  }

  void uuid(String value) {
    final compact = value.replaceAll('-', '');
    if (compact.length != 32) {
      throw const FormatException('账户恢复 checkpoint UUID 长度无效');
    }
    final result = Uint8List(16);
    for (var index = 0; index < result.length; index++) {
      final byte = int.tryParse(
        compact.substring(index * 2, index * 2 + 2),
        radix: 16,
      );
      if (byte == null) {
        throw const FormatException('账户恢复 checkpoint UUID 字节无效');
      }
      result[index] = byte;
    }
    _builder.add(result);
  }

  void optionalUuid(String? value) {
    uint32(value == null ? 0 : 1);
    if (value != null) uuid(value);
  }

  void fixedAscii(String value, int length) {
    final encoded = Uint8List.fromList(ascii.encode(value));
    try {
      if (encoded.length != length) {
        throw const FormatException('账户恢复 checkpoint ASCII 字段长度无效');
      }
      _builder.add(encoded);
    } finally {
      _clear(encoded);
    }
  }

  void variableBytes(Uint8List value, {int minimum = 0, required int maximum}) {
    if (value.length < minimum || value.length > maximum) {
      throw const FormatException('账户恢复 checkpoint 变长字段长度无效');
    }
    uint32(value.length);
    _builder.add(value);
  }

  Uint8List takeBytes() => _builder.takeBytes();
}

final class _CheckpointReader {
  _CheckpointReader(this._frame) : _view = ByteData.sublistView(_frame);

  final Uint8List _frame;
  final ByteData _view;
  int _offset = 0;

  Uint8List bytes(int length) {
    _require(length);
    final result = Uint8List.fromList(
      _frame.sublist(_offset, _offset + length),
    );
    _offset += length;
    return result;
  }

  int uint32() {
    _require(4);
    final value = _view.getUint32(_offset, Endian.big);
    _offset += 4;
    return value;
  }

  int uint64() {
    _require(8);
    final value = _view.getUint64(_offset, Endian.big);
    _offset += 8;
    return value;
  }

  DateTime timestamp() {
    final milliseconds = uint64();
    if (milliseconds <= 0) {
      throw const FormatException('账户恢复 checkpoint 时间戳无效');
    }
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }

  DateTime unixSeconds() {
    final seconds = uint64();
    if (seconds <= 0) {
      throw const FormatException('账户恢复 checkpoint 时间戳无效');
    }
    return DateTime.fromMillisecondsSinceEpoch(
      seconds * Duration.millisecondsPerSecond,
      isUtc: true,
    );
  }

  String uuid() {
    final value = bytes(16);
    final hex = value
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  String? optionalUuid() {
    return switch (uint32()) {
      0 => null,
      1 => uuid(),
      _ => throw const FormatException('账户恢复 checkpoint UUID 标记无效'),
    };
  }

  String fixedAscii(int length) {
    final value = bytes(length);
    try {
      return ascii.decode(value);
    } on FormatException {
      throw const FormatException('账户恢复 checkpoint ASCII 字段无效');
    } finally {
      _clear(value);
    }
  }

  Uint8List variableBytes({int minimum = 0, required int maximum}) {
    final length = uint32();
    if (length < minimum || length > maximum) {
      throw const FormatException('账户恢复 checkpoint 变长字段长度无效');
    }
    return bytes(length);
  }

  void requireEnd() {
    if (_offset != _frame.length) {
      throw const FormatException('账户恢复 checkpoint 存在尾随数据');
    }
  }

  void _require(int length) {
    if (length < 0 || _offset + length > _frame.length) {
      throw const FormatException('账户恢复 checkpoint 字段截断');
    }
  }
}

String _encodedData(Uint8List value) =>
    base64Url.encode(value).replaceAll('=', '');

Uint8List _digest(Uint8List value) =>
    Uint8List.fromList(sha256.convert(value).bytes);

bool _sameBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

void _clear(Uint8List? value) {
  value?.fillRange(0, value.length, 0);
}
