import 'dart:typed_data';

import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:uuid/uuid.dart';

import 'e2ee_account_recovery.dart';

final class E2eeNativeAccountRecoveryProofCore
    implements E2eeAccountRecoveryProofCore {
  const E2eeNativeAccountRecoveryProofCore({
    required KelivoSecureCore secureCore,
    required KelivoDeviceIdentityHandle deviceIdentity,
    required int deviceKeyVersion,
    required int targetAuthGeneration,
  }) : this._(
         secureCore,
         deviceIdentity,
         deviceKeyVersion,
         targetAuthGeneration,
       );

  const E2eeNativeAccountRecoveryProofCore._(
    this._secureCore,
    this._deviceIdentity,
    this._deviceKeyVersion,
    this._targetAuthGeneration,
  );

  final KelivoSecureCore _secureCore;
  final KelivoDeviceIdentityHandle _deviceIdentity;
  final int _deviceKeyVersion;
  final int _targetAuthGeneration;

  @override
  Future<E2eeAccountRecoveryProof> verifyHistoryAndCreateProof({
    required Uint8List recoveryMedia,
    required Uint8List recoveryPassphrase,
    required Uint8List serviceOriginSha256,
    required List<Uint8List> membershipHistory,
    required Uint8List currentCapsule,
    required Uint8List? sourceCapsule,
    required Uint8List challengeFrame,
    required Uint8List sealedNonce,
    required Uint8List recoveryTokenDigest,
    required String expectedAttemptId,
    required String expectedDeviceId,
    required Uint8List expectedRequestDigest,
    required DateTime expectedExpiresAt,
  }) async {
    try {
      final nativeProof = await _secureCore.verifyAccountRecoveryAndCreateProof(
        _deviceIdentity,
        expectedDeviceKeyVersion: _deviceKeyVersion,
        expectedDeviceAuthGeneration: _targetAuthGeneration,
        media: recoveryMedia,
        passphrase: recoveryPassphrase,
        serviceOriginSha256: serviceOriginSha256,
        membershipHistory: membershipHistory,
        currentCapsule: currentCapsule,
        sourceCapsule: sourceCapsule,
        challengeFrame: challengeFrame,
        sealedNonce: sealedNonce,
        recoveryTokenDigest: recoveryTokenDigest,
        expectedAttemptId: _canonicalRecoveryUuidBytes(
          expectedAttemptId,
          'expectedAttemptId',
        ),
        expectedDeviceId: _canonicalRecoveryUuidBytes(
          expectedDeviceId,
          'expectedDeviceId',
        ),
        expectedRequestDigest: expectedRequestDigest,
        expectedExpiresAt: expectedExpiresAt,
      );
      return E2eeAccountRecoveryProof(
        keyLease: E2eeNativeAccountRecoveryKeyLease._(
          secureCore: _secureCore,
          execution: nativeProof.execution,
        ),
        nonceProof: nativeProof.nonceProof,
        trustSignature: nativeProof.trustSignature,
      );
    } finally {
      recoveryPassphrase.fillRange(0, recoveryPassphrase.length, 0);
    }
  }

  @override
  Future<E2eeAccountRecoveryProof> verifyReplacementChallengeAndCreateProof({
    required Uint8List recoveryMedia,
    required Uint8List recoveryPassphrase,
    required Uint8List serviceOriginSha256,
    required List<Uint8List> membershipHistory,
    required Uint8List sourceCapsule,
    required E2eeAccountRecoveryReplacementChallenge challenge,
    required Uint8List recoveryTokenDigest,
    required String expectedDeviceId,
  }) async {
    KelivoAccountRecoveryReplacementProof? nativeProof;
    var retainExecution = false;
    try {
      if (challenge.deviceKeyVersion != _deviceKeyVersion) {
        throw const FormatException('账户恢复替换 challenge 设备密钥版本不一致');
      }
      final expectedChallengeId = _canonicalRecoveryUuidBytes(
        challenge.challengeId,
        'challengeId',
      );
      final expectedAttemptId = _canonicalRecoveryUuidBytes(
        challenge.attemptId,
        'attemptId',
      );
      final expectedDeviceIdBytes = _canonicalRecoveryUuidBytes(
        expectedDeviceId,
        'expectedDeviceId',
      );
      final expectedMembershipOperationId = _canonicalRecoveryUuidBytes(
        challenge.membershipOperationId,
        'membershipOperationId',
      );
      final expectedSourceRekeyOperationId = _canonicalRecoveryUuidBytes(
        challenge.sourceRekeyOperationId,
        'sourceRekeyOperationId',
      );
      nativeProof = await _secureCore
          .verifyAccountRecoveryReplacementChallengeAndCreateProof(
            _deviceIdentity,
            expectedDeviceKeyVersion: _deviceKeyVersion,
            expectedDeviceAuthGeneration: _targetAuthGeneration,
            media: recoveryMedia,
            passphrase: recoveryPassphrase,
            serviceOriginSha256: serviceOriginSha256,
            membershipHistory: membershipHistory,
            currentCapsule: challenge.recoveryCapsule,
            sourceCapsule: sourceCapsule,
            challengeFrame: challenge.challengeFrame,
            sealedNonce: challenge.sealedNonce,
            completionProofFrame: challenge.sourceCompletion.proofFrame,
            completionProofSignature: KelivoDataRekeyCompletionProofSignature(
              challenge.sourceCompletion.signature,
            ),
            recoveryTokenDigest: recoveryTokenDigest,
            expectedChallengeId: expectedChallengeId,
            expectedAttemptId: expectedAttemptId,
            expectedDeviceId: expectedDeviceIdBytes,
            expectedExpiresAt: challenge.expiresAt,
          );
      final execution = nativeProof.execution;
      if (!_sameRecoveryBytes(nativeProof.challengeId, expectedChallengeId) ||
          !_sameRecoveryBytes(nativeProof.attemptId, expectedAttemptId) ||
          !_sameRecoveryBytes(execution.deviceId, expectedDeviceIdBytes) ||
          !_sameRecoveryBytes(
            nativeProof.membershipOperationId,
            expectedMembershipOperationId,
          ) ||
          !_sameRecoveryBytes(
            nativeProof.membershipManifestDigest,
            challenge.membershipManifestDigest,
          ) ||
          !_sameRecoveryBytes(
            nativeProof.sourceDataRekeyOperationId,
            expectedSourceRekeyOperationId,
          ) ||
          !_sameRecoveryBytes(
            nativeProof.completionProofDigest,
            challenge.sourceCompletion.proofDigest,
          ) ||
          !_sameRecoveryBytes(
            nativeProof.requestDigest,
            challenge.requestDigest,
          ) ||
          execution.dataPhase != KelivoAccountRecoveryDataPhase.ready ||
          execution.securityGeneration != challenge.securityGeneration ||
          execution.keyEpoch != challenge.keyEpoch ||
          execution.deviceKeyVersion != challenge.deviceKeyVersion ||
          execution.sourceDataGeneration != challenge.dataGeneration ||
          execution.sourceDataKeyEpoch != challenge.dataKeyEpoch) {
        throw const FormatException('账户恢复 Native 替换证明未绑定服务端 challenge');
      }
      retainExecution = true;
      return E2eeAccountRecoveryProof(
        keyLease: E2eeNativeAccountRecoveryKeyLease._(
          secureCore: _secureCore,
          execution: execution,
        ),
        nonceProof: nativeProof.nonceProof,
        trustSignature: nativeProof.trustSignature,
      );
    } finally {
      recoveryPassphrase.fillRange(0, recoveryPassphrase.length, 0);
      if (nativeProof != null && !retainExecution) {
        await _secureCore.closeAccountRecoveryExecution(nativeProof.execution);
      }
    }
  }
}

final class E2eeNativeAccountRecoveryKeyLease
    implements E2eeAccountRecoveryKeyLease {
  const E2eeNativeAccountRecoveryKeyLease._({
    required KelivoSecureCore secureCore,
    required KelivoAccountRecoveryExecution execution,
  }) : this._fromFields(secureCore, execution);

  const E2eeNativeAccountRecoveryKeyLease._fromFields(
    this._secureCore,
    this._execution,
  );

  final KelivoSecureCore _secureCore;
  final KelivoAccountRecoveryExecution _execution;

  @override
  int get keyEpoch => _execution.keyEpoch;

  Future<KelivoPreparedAccountRecoveryCommit> prepareResume({
    required String operationId,
    required String rekeyOperationId,
  }) {
    return _secureCore.prepareAccountRecoveryResume(
      _execution,
      operationId: _canonicalRecoveryUuidBytes(operationId, 'operationId'),
      rekeyOperationId: _canonicalRecoveryUuidBytes(
        rekeyOperationId,
        'rekeyOperationId',
      ),
    );
  }

  Future<KelivoPreparedAccountRecoveryCommit> prepareReplacement({
    required String operationId,
    required String completionSessionId,
    required Uint8List completionSessionTokenDigest,
  }) {
    return _secureCore.prepareAccountRecoveryReplacement(
      _execution,
      operationId: _canonicalRecoveryUuidBytes(operationId, 'operationId'),
      completionSessionId: _canonicalRecoveryUuidBytes(
        completionSessionId,
        'completionSessionId',
      ),
      completionSessionTokenDigest: completionSessionTokenDigest,
    );
  }

  @override
  Future<void> close() => _secureCore.closeAccountRecoveryExecution(_execution);
}

Uint8List _canonicalRecoveryUuidBytes(String value, String field) {
  late final Uint8List bytes;
  try {
    bytes = Uint8List.fromList(Uuid.parseAsByteList(value));
  } on FormatException {
    throw FormatException('$field 必须为规范 UUIDv4');
  }
  if (bytes.length != 16 ||
      bytes[6] & 0xf0 != 0x40 ||
      bytes[8] & 0xc0 != 0x80 ||
      Uuid.unparse(bytes) != value) {
    throw FormatException('$field 必须为规范 UUIDv4');
  }
  return bytes;
}

bool _sameRecoveryBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}
