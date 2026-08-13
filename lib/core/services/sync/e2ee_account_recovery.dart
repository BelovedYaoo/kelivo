import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../workspace/device_state_blob_store.dart';
import 'cloud_sync_types.dart';

const e2eeAccountRecoveryProtocolVersion = 1;
const e2eeAccountRecoveryChallengeFrameBytes = 316;
const e2eeAccountRecoveryReplacementChallengeFrameBytes = 376;
const e2eeAccountRecoverySealedNonceBytes = 100;
const e2eeAccountRecoveryNonceProofBytes = 32;
const e2eeAccountRecoveryTrustSignatureBytes = 64;
const e2eeAccountRecoveryNativeContinuationBytes = 260;
const e2eeAccountRecoveryMaximumHistoryEntries = 4096;
const e2eeAccountRecoveryHistoryPageSize = 100;

final _canonicalUuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final _recoveryTokenPattern = RegExp(r'^kelivo_recovery_[A-Za-z0-9_-]{43}$');

enum E2eeAccountRecoveryDataPhase { ready, rekeyPending }

enum E2eeAccountRecoveryAuthorizationResult { authorized, replayed }

enum E2eeAccountRecoveryReplacementChallengeResult { created, replayed }

enum E2eeAccountRecoveryRemoteStatus {
  authorized,
  resumeCommitted,
  replacementCommitted,
}

enum E2eeAccountRecoveryNextAction {
  recoverResume,
  finishFirstDataRekey,
  createReplacementChallenge,
  recoverReplace,
  finishSecondDataRekey,
}

enum E2eeAccountRecoveryCommitResult { committed, replayed }

enum E2eeAccountRecoveryCommitKind { resume, replacement }

final class E2eeAccountRecoveryLocalTransitionPlan {
  factory E2eeAccountRecoveryLocalTransitionPlan({
    required Uint8List sourceStateBlob,
    required Uint8List unprunedStateBlob,
    required Uint8List prunedStateBlob,
    required int deviceKeyVersion,
    required String userId,
    required int sourceDataGeneration,
    required Uint8List operationAuthorizationDigest,
    required Uint8List continuation,
  }) {
    final source = _fixedBytes(
      sourceStateBlob,
      DeviceStateBlobStore.blobLength,
      'sourceStateBlob',
    );
    final unpruned = _fixedBytes(
      unprunedStateBlob,
      DeviceStateBlobStore.blobLength,
      'unprunedStateBlob',
    );
    final pruned = _fixedBytes(
      prunedStateBlob,
      DeviceStateBlobStore.blobLength,
      'prunedStateBlob',
    );
    final authorizationDigest = _fixedBytes(
      operationAuthorizationDigest,
      cloudSyncMembershipManifestDigestBytes,
      'operationAuthorizationDigest',
    );
    if (_sameBytes(source, unpruned) ||
        _sameBytes(source, pruned) ||
        _sameBytes(unpruned, pruned)) {
      throw const FormatException('账户恢复本地提交必须持有三个不同设备状态');
    }
    final checkedDeviceKeyVersion = _positiveUint32(
      deviceKeyVersion,
      'deviceKeyVersion',
    );
    final checkedUserId = _canonicalUuid(userId, 'userId');
    final checkedSourceDataGeneration = _positiveInt32(
      sourceDataGeneration,
      'sourceDataGeneration',
    );
    final ownedContinuation = _fixedMutableCopy(
      continuation,
      e2eeAccountRecoveryNativeContinuationBytes,
      'continuation',
    );
    return E2eeAccountRecoveryLocalTransitionPlan._(
      source,
      unpruned,
      pruned,
      checkedDeviceKeyVersion,
      checkedUserId,
      checkedSourceDataGeneration,
      authorizationDigest,
      ownedContinuation,
    );
  }

  E2eeAccountRecoveryLocalTransitionPlan._(
    this._sourceStateBlob,
    this._unprunedStateBlob,
    this._prunedStateBlob,
    this.deviceKeyVersion,
    this.userId,
    this.sourceDataGeneration,
    this._operationAuthorizationDigest,
    this._continuation,
  );

  final Uint8List _sourceStateBlob;
  final Uint8List _unprunedStateBlob;
  final Uint8List _prunedStateBlob;
  final int deviceKeyVersion;
  final String userId;
  final int sourceDataGeneration;
  final Uint8List _operationAuthorizationDigest;
  Uint8List? _continuation;

  Uint8List get sourceStateBlob => Uint8List.fromList(_sourceStateBlob);

  Uint8List get unprunedStateBlob => Uint8List.fromList(_unprunedStateBlob);

  Uint8List get prunedStateBlob => Uint8List.fromList(_prunedStateBlob);

  Uint8List get operationAuthorizationDigest =>
      Uint8List.fromList(_operationAuthorizationDigest);

  Uint8List copyContinuation() {
    final continuation = _continuation;
    if (continuation == null) {
      throw StateError('账户恢复本地转换计划已清理');
    }
    return Uint8List.fromList(continuation);
  }

  void clearContinuation() {
    final continuation = _continuation;
    continuation?.fillRange(0, continuation.length, 0);
    _continuation = null;
  }

  E2eeAccountRecoveryLocalTransitionPlan _copy() {
    return E2eeAccountRecoveryLocalTransitionPlan._(
      _sourceStateBlob,
      _unprunedStateBlob,
      _prunedStateBlob,
      deviceKeyVersion,
      userId,
      sourceDataGeneration,
      _operationAuthorizationDigest,
      copyContinuation(),
    );
  }
}

final class E2eeAccountRecoveryReopenBinding {
  factory E2eeAccountRecoveryReopenBinding({
    required String userId,
    required String deviceId,
    required int deviceKeyVersion,
    required int deviceAuthGeneration,
    required int keyEpoch,
    required int dataGeneration,
    required int membershipGeneration,
    required Uint8List membershipManifestDigest,
    required String membershipOperationId,
    required Uint8List prunedStateDigest,
  }) {
    return E2eeAccountRecoveryReopenBinding._(
      _canonicalUuid(userId, 'userId'),
      _canonicalUuid(deviceId, 'deviceId'),
      _positiveUint32(deviceKeyVersion, 'deviceKeyVersion'),
      _positiveInt32(deviceAuthGeneration, 'deviceAuthGeneration'),
      _positiveUint32(keyEpoch, 'keyEpoch'),
      _positiveInt32(dataGeneration, 'dataGeneration'),
      _positiveInt32(membershipGeneration, 'membershipGeneration'),
      _fixedBytes(
        membershipManifestDigest,
        cloudSyncMembershipManifestDigestBytes,
        'membershipManifestDigest',
      ),
      _canonicalUuid(membershipOperationId, 'membershipOperationId'),
      _fixedBytes(prunedStateDigest, 32, 'prunedStateDigest'),
    );
  }

  const E2eeAccountRecoveryReopenBinding._(
    this.userId,
    this.deviceId,
    this.deviceKeyVersion,
    this.deviceAuthGeneration,
    this.keyEpoch,
    this.dataGeneration,
    this.membershipGeneration,
    this._membershipManifestDigest,
    this.membershipOperationId,
    this._prunedStateDigest,
  );

  final String userId;
  final String deviceId;
  final int deviceKeyVersion;
  final int deviceAuthGeneration;
  final int keyEpoch;
  final int dataGeneration;
  final int membershipGeneration;
  final Uint8List _membershipManifestDigest;
  final String membershipOperationId;
  final Uint8List _prunedStateDigest;

  Uint8List get membershipManifestDigest =>
      Uint8List.fromList(_membershipManifestDigest);

  Uint8List get prunedStateDigest => Uint8List.fromList(_prunedStateDigest);
}

final class CloudSyncAccountRecoveryToken {
  CloudSyncAccountRecoveryToken._(this.value);

  factory CloudSyncAccountRecoveryToken.generate() {
    final random = Random.secure();
    final bytes = Uint8List(32);
    try {
      for (var index = 0; index < bytes.length; index++) {
        bytes[index] = random.nextInt(256);
      }
      final encoded = base64Url.encode(bytes).replaceAll('=', '');
      return CloudSyncAccountRecoveryToken.parse('kelivo_recovery_$encoded');
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  factory CloudSyncAccountRecoveryToken.parse(String value) {
    if (!_recoveryTokenPattern.hasMatch(value)) {
      throw const FormatException('账户恢复令牌格式无效');
    }
    return CloudSyncAccountRecoveryToken._(value);
  }

  final String value;

  @override
  String toString() => 'CloudSyncAccountRecoveryToken(<已隐藏>)';
}

final class E2eeAccountRecoveryDataState {
  E2eeAccountRecoveryDataState._({
    required this.phase,
    required this.dataGeneration,
    required this.dataKeyEpoch,
    required this.operationId,
    required this.targetKeyEpoch,
  });

  factory E2eeAccountRecoveryDataState.ready({
    required int dataGeneration,
    required int dataKeyEpoch,
  }) {
    return E2eeAccountRecoveryDataState._(
      phase: E2eeAccountRecoveryDataPhase.ready,
      dataGeneration: _positiveInt32(dataGeneration, 'dataGeneration'),
      dataKeyEpoch: _positiveUint32(dataKeyEpoch, 'dataKeyEpoch'),
      operationId: null,
      targetKeyEpoch: null,
    );
  }

  factory E2eeAccountRecoveryDataState.rekeyPending({
    required int dataGeneration,
    required int dataKeyEpoch,
    required String operationId,
    required int targetKeyEpoch,
  }) {
    final sourceEpoch = _positiveUint32(dataKeyEpoch, 'dataKeyEpoch');
    final targetEpoch = _positiveUint32(targetKeyEpoch, 'targetKeyEpoch');
    if (sourceEpoch == 0xffffffff || targetEpoch != sourceEpoch + 1) {
      throw const FormatException('账户恢复数据换钥代次不相邻');
    }
    return E2eeAccountRecoveryDataState._(
      phase: E2eeAccountRecoveryDataPhase.rekeyPending,
      dataGeneration: _positiveInt32(dataGeneration, 'dataGeneration'),
      dataKeyEpoch: sourceEpoch,
      operationId: _canonicalUuid(operationId, 'operationId'),
      targetKeyEpoch: targetEpoch,
    );
  }

  final E2eeAccountRecoveryDataPhase phase;
  final int dataGeneration;
  final int dataKeyEpoch;
  final String? operationId;
  final int? targetKeyEpoch;
}

final class E2eeAccountRecoveryChallenge {
  factory E2eeAccountRecoveryChallenge({
    required String attemptId,
    required Uint8List requestDigest,
    required Uint8List challengeFrame,
    required Uint8List sealedNonce,
    required int securityGeneration,
    required int keyEpoch,
    required Uint8List membershipManifestDigest,
    required int recoveryPublicKeyVersion,
    required Uint8List recoveryPublicKey,
    required int recoveryCapsuleVersion,
    required Uint8List recoveryCapsule,
    required Uint8List recoveryCapsuleDigest,
    required E2eeAccountRecoveryDataState dataState,
    required DateTime expiresAt,
  }) {
    final capsule = _rangedBytes(
      recoveryCapsule,
      minimum: 1,
      maximum: cloudSyncRecoveryCapsuleMaximumBytes,
      field: 'recoveryCapsule',
    );
    final capsuleDigest = _fixedBytes(
      recoveryCapsuleDigest,
      32,
      'recoveryCapsuleDigest',
    );
    final actualCapsuleDigest = Uint8List.fromList(
      sha256.convert(capsule).bytes,
    );
    if (!_sameBytes(actualCapsuleDigest, capsuleDigest)) {
      throw const FormatException('账户恢复 capsule 摘要不一致');
    }
    final checkedKeyEpoch = _positiveUint32(keyEpoch, 'keyEpoch');
    if (dataState.phase == E2eeAccountRecoveryDataPhase.ready) {
      if (dataState.dataKeyEpoch != checkedKeyEpoch) {
        throw const FormatException('账户恢复就绪数据代次与安全代次不一致');
      }
    } else if (dataState.targetKeyEpoch != checkedKeyEpoch) {
      throw const FormatException('账户恢复换钥目标代次与安全代次不一致');
    }
    return E2eeAccountRecoveryChallenge._(
      attemptId: _canonicalUuid(attemptId, 'attemptId'),
      requestDigest: _fixedBytes(requestDigest, 32, 'requestDigest'),
      challengeFrame: _fixedBytes(
        challengeFrame,
        e2eeAccountRecoveryChallengeFrameBytes,
        'challengeFrame',
      ),
      sealedNonce: _fixedBytes(
        sealedNonce,
        e2eeAccountRecoverySealedNonceBytes,
        'sealedNonce',
      ),
      securityGeneration: _positiveInt32(
        securityGeneration,
        'securityGeneration',
      ),
      keyEpoch: checkedKeyEpoch,
      membershipManifestDigest: _fixedBytes(
        membershipManifestDigest,
        32,
        'membershipManifestDigest',
      ),
      recoveryPublicKeyVersion: _positiveInt32(
        recoveryPublicKeyVersion,
        'recoveryPublicKeyVersion',
      ),
      recoveryPublicKey: _fixedBytes(
        recoveryPublicKey,
        cloudSyncRecoveryPublicKeyBytes,
        'recoveryPublicKey',
      ),
      recoveryCapsuleVersion: _positiveInt32(
        recoveryCapsuleVersion,
        'recoveryCapsuleVersion',
      ),
      recoveryCapsule: capsule,
      recoveryCapsuleDigest: capsuleDigest,
      dataState: dataState,
      expiresAt: expiresAt.toUtc(),
    );
  }

  const E2eeAccountRecoveryChallenge._({
    required this.attemptId,
    required this.requestDigest,
    required this.challengeFrame,
    required this.sealedNonce,
    required this.securityGeneration,
    required this.keyEpoch,
    required this.membershipManifestDigest,
    required this.recoveryPublicKeyVersion,
    required this.recoveryPublicKey,
    required this.recoveryCapsuleVersion,
    required this.recoveryCapsule,
    required this.recoveryCapsuleDigest,
    required this.dataState,
    required this.expiresAt,
  });

  final String attemptId;
  final Uint8List requestDigest;
  final Uint8List challengeFrame;
  final Uint8List sealedNonce;
  final int securityGeneration;
  final int keyEpoch;
  final Uint8List membershipManifestDigest;
  final int recoveryPublicKeyVersion;
  final Uint8List recoveryPublicKey;
  final int recoveryCapsuleVersion;
  final Uint8List recoveryCapsule;
  final Uint8List recoveryCapsuleDigest;
  final E2eeAccountRecoveryDataState dataState;
  final DateTime expiresAt;
}

final class E2eeAccountRecoveryReplacementChallengeRequest {
  factory E2eeAccountRecoveryReplacementChallengeRequest({
    required String challengeId,
    required int expectedGeneration,
    required int expectedKeyEpoch,
    required Uint8List expectedMembershipManifestDigest,
    required String expectedMembershipOperationId,
    required int dataGeneration,
    required int dataKeyEpoch,
    required String sourceRekeyOperationId,
    required Uint8List sourceCompletionProofDigest,
  }) {
    final checkedKeyEpoch = _positiveUint32(
      expectedKeyEpoch,
      'expectedKeyEpoch',
    );
    final checkedDataKeyEpoch = _positiveUint32(dataKeyEpoch, 'dataKeyEpoch');
    if (checkedDataKeyEpoch != checkedKeyEpoch) {
      throw const FormatException('账户恢复替换 challenge 数据代次与安全代次不一致');
    }
    return E2eeAccountRecoveryReplacementChallengeRequest._(
      challengeId: _canonicalUuid(challengeId, 'challengeId'),
      expectedGeneration: _positiveInt32(
        expectedGeneration,
        'expectedGeneration',
      ),
      expectedKeyEpoch: checkedKeyEpoch,
      expectedMembershipManifestDigest: _fixedBytes(
        expectedMembershipManifestDigest,
        cloudSyncMembershipManifestDigestBytes,
        'expectedMembershipManifestDigest',
      ),
      expectedMembershipOperationId: _canonicalUuid(
        expectedMembershipOperationId,
        'expectedMembershipOperationId',
      ),
      dataGeneration: _positiveInt32(dataGeneration, 'dataGeneration'),
      dataKeyEpoch: checkedDataKeyEpoch,
      sourceRekeyOperationId: _canonicalUuid(
        sourceRekeyOperationId,
        'sourceRekeyOperationId',
      ),
      sourceCompletionProofDigest: _fixedBytes(
        sourceCompletionProofDigest,
        cloudSyncMembershipManifestDigestBytes,
        'sourceCompletionProofDigest',
      ),
    );
  }

  const E2eeAccountRecoveryReplacementChallengeRequest._({
    required this.challengeId,
    required this.expectedGeneration,
    required this.expectedKeyEpoch,
    required this.expectedMembershipManifestDigest,
    required this.expectedMembershipOperationId,
    required this.dataGeneration,
    required this.dataKeyEpoch,
    required this.sourceRekeyOperationId,
    required this.sourceCompletionProofDigest,
  });

  final String challengeId;
  final int expectedGeneration;
  final int expectedKeyEpoch;
  final Uint8List expectedMembershipManifestDigest;
  final String expectedMembershipOperationId;
  final int dataGeneration;
  final int dataKeyEpoch;
  final String sourceRekeyOperationId;
  final Uint8List sourceCompletionProofDigest;
}

final class E2eeAccountRecoveryReplacementChallenge {
  factory E2eeAccountRecoveryReplacementChallenge({
    required E2eeAccountRecoveryReplacementChallengeResult result,
    required String challengeId,
    required String attemptId,
    required Uint8List requestDigest,
    required Uint8List challengeFrame,
    required Uint8List sealedNonce,
    required int deviceKeyVersion,
    required Uint8List deviceSigningPublicKey,
    required Uint8List deviceKeyAgreementPublicKey,
    required int securityGeneration,
    required int keyEpoch,
    required Uint8List membershipManifest,
    required Uint8List membershipManifestDigest,
    required String membershipOperationId,
    required int recoveryPublicKeyVersion,
    required Uint8List recoveryPublicKey,
    required int recoveryCapsuleVersion,
    required Uint8List recoveryCapsule,
    required Uint8List recoveryCapsuleDigest,
    required int dataGeneration,
    required int dataKeyEpoch,
    required String sourceRekeyOperationId,
    required CloudSyncDataRekeyCompletion sourceCompletion,
    required DateTime expiresAt,
  }) {
    final manifest = _rangedBytes(
      membershipManifest,
      minimum: cloudSyncMembershipManifestMinimumBytes,
      maximum: cloudSyncMembershipManifestMaximumBytes,
      field: 'membershipManifest',
    );
    final manifestDigest = _fixedBytes(
      membershipManifestDigest,
      cloudSyncMembershipManifestDigestBytes,
      'membershipManifestDigest',
    );
    if (!_sameBytes(
      Uint8List.fromList(sha256.convert(manifest).bytes),
      manifestDigest,
    )) {
      throw const FormatException('账户恢复替换 challenge 成员清单摘要不一致');
    }
    final capsule = _rangedBytes(
      recoveryCapsule,
      minimum: 1,
      maximum: cloudSyncRecoveryCapsuleMaximumBytes,
      field: 'recoveryCapsule',
    );
    final capsuleDigest = _fixedBytes(
      recoveryCapsuleDigest,
      cloudSyncMembershipManifestDigestBytes,
      'recoveryCapsuleDigest',
    );
    if (!_sameBytes(
      Uint8List.fromList(sha256.convert(capsule).bytes),
      capsuleDigest,
    )) {
      throw const FormatException('账户恢复替换 challenge capsule 摘要不一致');
    }
    final checkedSecurityGeneration = _positiveInt32(
      securityGeneration,
      'securityGeneration',
    );
    final checkedKeyEpoch = _positiveUint32(keyEpoch, 'keyEpoch');
    final checkedDataGeneration = _positiveInt32(
      dataGeneration,
      'dataGeneration',
    );
    final checkedDataKeyEpoch = _positiveUint32(dataKeyEpoch, 'dataKeyEpoch');
    final checkedSourceRekeyOperationId = _canonicalUuid(
      sourceRekeyOperationId,
      'sourceRekeyOperationId',
    );
    if (checkedDataKeyEpoch != checkedKeyEpoch ||
        sourceCompletion.operationId != checkedSourceRekeyOperationId ||
        sourceCompletion.targetDataGeneration != checkedDataGeneration ||
        sourceCompletion.targetKeyEpoch != checkedDataKeyEpoch ||
        sourceCompletion.membershipGeneration != checkedSecurityGeneration ||
        !_sameBytes(
          sourceCompletion.membershipManifestDigest,
          manifestDigest,
        )) {
      throw const FormatException('账户恢复替换 challenge 完成证明与安全状态不一致');
    }
    final checkedExpiresAt = expiresAt.toUtc();
    if (checkedExpiresAt.millisecondsSinceEpoch <= 0) {
      throw const FormatException('账户恢复替换 challenge 过期时间无效');
    }
    return E2eeAccountRecoveryReplacementChallenge._(
      result: result,
      challengeId: _canonicalUuid(challengeId, 'challengeId'),
      attemptId: _canonicalUuid(attemptId, 'attemptId'),
      requestDigest: _fixedBytes(
        requestDigest,
        cloudSyncMembershipManifestDigestBytes,
        'requestDigest',
      ),
      challengeFrame: _fixedBytes(
        challengeFrame,
        e2eeAccountRecoveryReplacementChallengeFrameBytes,
        'challengeFrame',
      ),
      sealedNonce: _fixedBytes(
        sealedNonce,
        e2eeAccountRecoverySealedNonceBytes,
        'sealedNonce',
      ),
      deviceKeyVersion: _positiveInt32(deviceKeyVersion, 'deviceKeyVersion'),
      deviceSigningPublicKey: _fixedBytes(
        deviceSigningPublicKey,
        cloudSyncDevicePublicKeyBytes,
        'deviceSigningPublicKey',
      ),
      deviceKeyAgreementPublicKey: _fixedBytes(
        deviceKeyAgreementPublicKey,
        cloudSyncDevicePublicKeyBytes,
        'deviceKeyAgreementPublicKey',
      ),
      securityGeneration: checkedSecurityGeneration,
      keyEpoch: checkedKeyEpoch,
      membershipManifest: manifest,
      membershipManifestDigest: manifestDigest,
      membershipOperationId: _canonicalUuid(
        membershipOperationId,
        'membershipOperationId',
      ),
      recoveryPublicKeyVersion: _positiveInt32(
        recoveryPublicKeyVersion,
        'recoveryPublicKeyVersion',
      ),
      recoveryPublicKey: _fixedBytes(
        recoveryPublicKey,
        cloudSyncRecoveryPublicKeyBytes,
        'recoveryPublicKey',
      ),
      recoveryCapsuleVersion: _positiveInt32(
        recoveryCapsuleVersion,
        'recoveryCapsuleVersion',
      ),
      recoveryCapsule: capsule,
      recoveryCapsuleDigest: capsuleDigest,
      dataGeneration: checkedDataGeneration,
      dataKeyEpoch: checkedDataKeyEpoch,
      sourceRekeyOperationId: checkedSourceRekeyOperationId,
      sourceCompletion: sourceCompletion,
      expiresAt: checkedExpiresAt,
    );
  }

  const E2eeAccountRecoveryReplacementChallenge._({
    required this.result,
    required this.challengeId,
    required this.attemptId,
    required this.requestDigest,
    required this.challengeFrame,
    required this.sealedNonce,
    required this.deviceKeyVersion,
    required this.deviceSigningPublicKey,
    required this.deviceKeyAgreementPublicKey,
    required this.securityGeneration,
    required this.keyEpoch,
    required this.membershipManifest,
    required this.membershipManifestDigest,
    required this.membershipOperationId,
    required this.recoveryPublicKeyVersion,
    required this.recoveryPublicKey,
    required this.recoveryCapsuleVersion,
    required this.recoveryCapsule,
    required this.recoveryCapsuleDigest,
    required this.dataGeneration,
    required this.dataKeyEpoch,
    required this.sourceRekeyOperationId,
    required this.sourceCompletion,
    required this.expiresAt,
  });

  final E2eeAccountRecoveryReplacementChallengeResult result;
  final String challengeId;
  final String attemptId;
  final Uint8List requestDigest;
  final Uint8List challengeFrame;
  final Uint8List sealedNonce;
  final int deviceKeyVersion;
  final Uint8List deviceSigningPublicKey;
  final Uint8List deviceKeyAgreementPublicKey;
  final int securityGeneration;
  final int keyEpoch;
  final Uint8List membershipManifest;
  final Uint8List membershipManifestDigest;
  final String membershipOperationId;
  final int recoveryPublicKeyVersion;
  final Uint8List recoveryPublicKey;
  final int recoveryCapsuleVersion;
  final Uint8List recoveryCapsule;
  final Uint8List recoveryCapsuleDigest;
  final int dataGeneration;
  final int dataKeyEpoch;
  final String sourceRekeyOperationId;
  final CloudSyncDataRekeyCompletion sourceCompletion;
  final DateTime expiresAt;
}

final class E2eeAccountRecoveryAuthorizationReceipt {
  E2eeAccountRecoveryAuthorizationReceipt({
    required String attemptId,
    required this.result,
    required this.nextAction,
    required DateTime recoveryTokenExpiresAt,
  }) : attemptId = _canonicalUuid(attemptId, 'attemptId'),
       recoveryTokenExpiresAt = recoveryTokenExpiresAt.toUtc() {
    if (nextAction != E2eeAccountRecoveryNextAction.recoverResume &&
        nextAction != E2eeAccountRecoveryNextAction.recoverReplace) {
      throw const FormatException('账户恢复授权回执下一步无效');
    }
  }

  final String attemptId;
  final E2eeAccountRecoveryAuthorizationResult result;
  final E2eeAccountRecoveryNextAction nextAction;
  final DateTime recoveryTokenExpiresAt;
}

final class E2eeAccountRecoveryAuthorizedState {
  E2eeAccountRecoveryAuthorizedState({
    required String attemptId,
    required DateTime authorizedAt,
    required DateTime recoveryTokenExpiresAt,
    required this.status,
    required this.nextAction,
    required this.securityState,
    required this.dataState,
  }) : attemptId = _canonicalUuid(attemptId, 'attemptId'),
       authorizedAt = authorizedAt.toUtc(),
       recoveryTokenExpiresAt = recoveryTokenExpiresAt.toUtc() {
    if (this.authorizedAt.millisecondsSinceEpoch <= 0 ||
        !this.authorizedAt.isBefore(this.recoveryTokenExpiresAt)) {
      throw const FormatException('账户恢复远程授权时间无效');
    }
    final expectedDataRekeyPhase =
        dataState.phase == E2eeAccountRecoveryDataPhase.ready
        ? CloudSyncDataRekeyPhase.ready
        : CloudSyncDataRekeyPhase.rekeyPending;
    final stateEpoch = dataState.phase == E2eeAccountRecoveryDataPhase.ready
        ? dataState.dataKeyEpoch
        : dataState.targetKeyEpoch;
    if (securityState.dataRekeyPhase != expectedDataRekeyPhase ||
        securityState.keyEpoch != stateEpoch ||
        !_remoteStatusAllowsAction(status, dataState.phase, nextAction)) {
      throw const FormatException('账户恢复远程状态与数据换钥阶段不一致');
    }
  }

  final String attemptId;
  final DateTime authorizedAt;
  final DateTime recoveryTokenExpiresAt;
  final E2eeAccountRecoveryRemoteStatus status;
  final E2eeAccountRecoveryNextAction nextAction;
  final CloudSyncAccountSecurityState securityState;
  final E2eeAccountRecoveryDataState dataState;
}

final class E2eeAccountRecoveryTokenUnavailable implements Exception {
  const E2eeAccountRecoveryTokenUnavailable();

  @override
  String toString() => 'E2eeAccountRecoveryTokenUnavailable';
}

final class E2eeAccountRecoveryEnvelope {
  factory E2eeAccountRecoveryEnvelope({
    required int envelopeVersion,
    required int keyEpoch,
    required Uint8List accountKeyEnvelope,
  }) {
    if (envelopeVersion != 1) {
      throw const FormatException('账户恢复信封版本无效');
    }
    return E2eeAccountRecoveryEnvelope._(
      envelopeVersion,
      _positiveUint32(keyEpoch, 'keyEpoch'),
      _fixedBytes(
        accountKeyEnvelope,
        cloudSyncAccountKeyEnvelopeBytes,
        'accountKeyEnvelope',
      ),
    );
  }

  const E2eeAccountRecoveryEnvelope._(
    this.envelopeVersion,
    this.keyEpoch,
    this.accountKeyEnvelope,
  );

  final int envelopeVersion;
  final int keyEpoch;
  final Uint8List accountKeyEnvelope;
}

final class E2eeAccountRecoveryMembershipCommit {
  factory E2eeAccountRecoveryMembershipCommit({
    required int expectedGeneration,
    required int expectedKeyEpoch,
    required CloudSyncMembershipManifestDigest expectedMembershipManifestDigest,
    required String operationId,
    required Uint8List nextMembershipManifest,
    required CloudSyncMembershipManifestDigest nextMembershipManifestDigest,
    required E2eeAccountRecoveryEnvelope envelope,
  }) {
    final generation = _positiveInt32(expectedGeneration, 'expectedGeneration');
    final keyEpoch = _positiveUint32(expectedKeyEpoch, 'expectedKeyEpoch');
    if (generation == 0x7fffffff || keyEpoch == 0xffffffff) {
      throw const FormatException('账户恢复成员提交代次无法继续推进');
    }
    final manifest = _rangedBytes(
      nextMembershipManifest,
      minimum: cloudSyncMembershipManifestMinimumBytes,
      maximum: cloudSyncMembershipManifestMaximumBytes,
      field: 'nextMembershipManifest',
    );
    final actualDigest = Uint8List.fromList(sha256.convert(manifest).bytes);
    if (!_sameBytes(actualDigest, nextMembershipManifestDigest.bytes)) {
      throw const FormatException('账户恢复下一成员清单摘要不匹配');
    }
    return E2eeAccountRecoveryMembershipCommit._(
      generation,
      keyEpoch,
      expectedMembershipManifestDigest,
      _canonicalUuid(operationId, 'operationId'),
      manifest,
      nextMembershipManifestDigest,
      envelope,
    );
  }

  const E2eeAccountRecoveryMembershipCommit._(
    this.expectedGeneration,
    this.expectedKeyEpoch,
    this.expectedMembershipManifestDigest,
    this.operationId,
    this.nextMembershipManifest,
    this.nextMembershipManifestDigest,
    this.envelope,
  );

  final int expectedGeneration;
  final int expectedKeyEpoch;
  final CloudSyncMembershipManifestDigest expectedMembershipManifestDigest;
  final String operationId;
  final Uint8List nextMembershipManifest;
  final CloudSyncMembershipManifestDigest nextMembershipManifestDigest;
  final E2eeAccountRecoveryEnvelope envelope;
}

sealed class E2eeAccountRecoveryPreparedCommit {
  const E2eeAccountRecoveryPreparedCommit();

  E2eeAccountRecoveryCommitKind get kind;

  String get attemptId;

  E2eeAccountRecoveryMembershipCommit get membership;
}

final class E2eeAccountRecoveryResumeCommit
    extends E2eeAccountRecoveryPreparedCommit {
  factory E2eeAccountRecoveryResumeCommit({
    required String attemptId,
    required E2eeAccountRecoveryMembershipCommit membership,
    required String rekeyOperationId,
  }) {
    if (membership.envelope.keyEpoch != membership.expectedKeyEpoch) {
      throw const FormatException('账户恢复接续信封密钥代次无效');
    }
    return E2eeAccountRecoveryResumeCommit._(
      _canonicalUuid(attemptId, 'attemptId'),
      membership,
      _canonicalUuid(rekeyOperationId, 'rekeyOperationId'),
    );
  }

  const E2eeAccountRecoveryResumeCommit._(
    this.attemptId,
    this.membership,
    this.rekeyOperationId,
  );

  @override
  E2eeAccountRecoveryCommitKind get kind =>
      E2eeAccountRecoveryCommitKind.resume;

  @override
  final String attemptId;
  @override
  final E2eeAccountRecoveryMembershipCommit membership;
  final String rekeyOperationId;
}

sealed class E2eeAccountRecoveryReplacementAuthorization {
  factory E2eeAccountRecoveryReplacementAuthorization.initial({
    required Uint8List challengeRequestDigest,
  }) = E2eeAccountRecoveryReplacementInitialAuthorization;

  factory E2eeAccountRecoveryReplacementAuthorization.replacementChallenge({
    required String challengeId,
    required Uint8List challengeRequestDigest,
    required Uint8List nonceProof,
    required Uint8List trustSignature,
  }) = E2eeAccountRecoveryReplacementChallengeAuthorization;

  const E2eeAccountRecoveryReplacementAuthorization._();

  Uint8List get challengeRequestDigest;
}

final class E2eeAccountRecoveryReplacementInitialAuthorization
    extends E2eeAccountRecoveryReplacementAuthorization {
  factory E2eeAccountRecoveryReplacementInitialAuthorization({
    required Uint8List challengeRequestDigest,
  }) {
    return E2eeAccountRecoveryReplacementInitialAuthorization._(
      _fixedBytes(challengeRequestDigest, 32, 'challengeRequestDigest'),
    );
  }

  const E2eeAccountRecoveryReplacementInitialAuthorization._(
    this.challengeRequestDigest,
  ) : super._();

  @override
  final Uint8List challengeRequestDigest;
}

final class E2eeAccountRecoveryReplacementChallengeAuthorization
    extends E2eeAccountRecoveryReplacementAuthorization {
  factory E2eeAccountRecoveryReplacementChallengeAuthorization({
    required String challengeId,
    required Uint8List challengeRequestDigest,
    required Uint8List nonceProof,
    required Uint8List trustSignature,
  }) {
    return E2eeAccountRecoveryReplacementChallengeAuthorization._(
      _canonicalUuid(challengeId, 'challengeId'),
      _fixedBytes(challengeRequestDigest, 32, 'challengeRequestDigest'),
      _fixedBytes(nonceProof, e2eeAccountRecoveryNonceProofBytes, 'nonceProof'),
      _fixedBytes(
        trustSignature,
        e2eeAccountRecoveryTrustSignatureBytes,
        'trustSignature',
      ),
    );
  }

  const E2eeAccountRecoveryReplacementChallengeAuthorization._(
    this.challengeId,
    this.challengeRequestDigest,
    this.nonceProof,
    this.trustSignature,
  ) : super._();

  final String challengeId;
  @override
  final Uint8List challengeRequestDigest;
  final Uint8List nonceProof;
  final Uint8List trustSignature;
}

final class E2eeAccountRecoveryReplacementCommit
    extends E2eeAccountRecoveryPreparedCommit {
  factory E2eeAccountRecoveryReplacementCommit({
    required String attemptId,
    required E2eeAccountRecoveryMembershipCommit membership,
    required E2eeAccountRecoveryReplacementAuthorization authorization,
    required int nextRecoveryCapsuleVersion,
    required Uint8List nextRecoveryCapsule,
    required String completionSessionId,
    required CloudSyncFullSessionToken completionSessionToken,
  }) {
    if (membership.envelope.keyEpoch != membership.expectedKeyEpoch + 1) {
      throw const FormatException('账户恢复替换信封密钥代次无效');
    }
    return E2eeAccountRecoveryReplacementCommit._(
      _canonicalUuid(attemptId, 'attemptId'),
      membership,
      authorization,
      _positiveInt32(nextRecoveryCapsuleVersion, 'nextRecoveryCapsuleVersion'),
      _rangedBytes(
        nextRecoveryCapsule,
        minimum: 1,
        maximum: cloudSyncRecoveryCapsuleMaximumBytes,
        field: 'nextRecoveryCapsule',
      ),
      _canonicalUuid(completionSessionId, 'completionSessionId'),
      completionSessionToken,
    );
  }

  const E2eeAccountRecoveryReplacementCommit._(
    this.attemptId,
    this.membership,
    this.authorization,
    this.nextRecoveryCapsuleVersion,
    this.nextRecoveryCapsule,
    this.completionSessionId,
    this.completionSessionToken,
  );

  @override
  E2eeAccountRecoveryCommitKind get kind =>
      E2eeAccountRecoveryCommitKind.replacement;

  @override
  final String attemptId;
  @override
  final E2eeAccountRecoveryMembershipCommit membership;
  final E2eeAccountRecoveryReplacementAuthorization authorization;
  final int nextRecoveryCapsuleVersion;
  final Uint8List nextRecoveryCapsule;
  final String completionSessionId;
  final CloudSyncFullSessionToken completionSessionToken;
}

final class E2eeAccountRecoveryCommitReceipt {
  E2eeAccountRecoveryCommitReceipt({
    required this.result,
    required this.kind,
    required String attemptId,
    required String membershipOperationId,
    required String rekeyOperationId,
    required int generation,
    required int keyEpoch,
    required this.nextAction,
  }) : attemptId = _canonicalUuid(attemptId, 'attemptId'),
       membershipOperationId = _canonicalUuid(
         membershipOperationId,
         'membershipOperationId',
       ),
       rekeyOperationId = _canonicalUuid(rekeyOperationId, 'rekeyOperationId'),
       generation = _positiveInt32(generation, 'generation'),
       keyEpoch = _positiveUint32(keyEpoch, 'keyEpoch');

  final E2eeAccountRecoveryCommitResult result;
  final E2eeAccountRecoveryCommitKind kind;
  final String attemptId;
  final String membershipOperationId;
  final String rekeyOperationId;
  final int generation;
  final int keyEpoch;
  final E2eeAccountRecoveryNextAction nextAction;
}

sealed class E2eeAccountRecoveryBearer {
  const E2eeAccountRecoveryBearer();

  factory E2eeAccountRecoveryBearer.onboarding(CloudSyncOnboardingToken token) =
      _E2eeAccountRecoveryOnboardingBearer;

  factory E2eeAccountRecoveryBearer.recovery(
    CloudSyncAccountRecoveryToken token,
  ) = _E2eeAccountRecoveryTokenBearer;

  String get value;

  @override
  String toString() => 'E2eeAccountRecoveryBearer(<已隐藏>)';
}

final class _E2eeAccountRecoveryOnboardingBearer
    extends E2eeAccountRecoveryBearer {
  const _E2eeAccountRecoveryOnboardingBearer(this._token);

  final CloudSyncOnboardingToken _token;

  @override
  String get value => _token.value;
}

final class _E2eeAccountRecoveryTokenBearer extends E2eeAccountRecoveryBearer {
  const _E2eeAccountRecoveryTokenBearer(this._token);

  final CloudSyncAccountRecoveryToken _token;

  @override
  String get value => _token.value;
}

abstract interface class E2eeAccountRecoveryTransport {
  Future<E2eeAccountRecoveryAuthorizedState> getAuthorizedState({
    required CloudSyncAccountRecoveryToken recoveryToken,
  });

  Future<E2eeAccountRecoveryChallenge> createChallenge({
    required CloudSyncOnboardingToken onboardingToken,
    required String attemptId,
  });

  Future<CloudSyncAccountSecurityHistoryPage> listFrozenHistory({
    required E2eeAccountRecoveryBearer authorization,
    required String attemptId,
    required Uint8List challengeRequestDigest,
    required int afterGeneration,
    required int pageSize,
  });

  Future<E2eeAccountRecoveryAuthorizationReceipt> authorize({
    required E2eeAccountRecoveryBearer authorization,
    required String attemptId,
    required Uint8List challengeRequestDigest,
    required CloudSyncAccountRecoveryToken recoveryToken,
    required Uint8List nonceProof,
    required Uint8List trustSignature,
  });

  Future<E2eeAccountRecoveryReplacementChallenge> createReplacementChallenge({
    required CloudSyncAccountRecoveryToken recoveryToken,
    required String expectedAttemptId,
    required String expectedDeviceId,
    required E2eeAccountRecoveryReplacementChallengeRequest request,
  });

  Future<E2eeAccountRecoveryCommitReceipt> commitRecoveryResume({
    required CloudSyncAccountRecoveryToken recoveryToken,
    required E2eeAccountRecoveryResumeCommit request,
  });

  Future<E2eeAccountRecoveryCommitReceipt> commitRecoveryReplacement({
    required CloudSyncAccountRecoveryToken recoveryToken,
    required E2eeAccountRecoveryReplacementCommit request,
  });
}

abstract interface class E2eeAccountRecoveryKeyLease {
  int get keyEpoch;

  Future<void> close();
}

final class E2eeAccountRecoveryProof {
  factory E2eeAccountRecoveryProof({
    required E2eeAccountRecoveryKeyLease keyLease,
    required Uint8List nonceProof,
    required Uint8List trustSignature,
  }) {
    return E2eeAccountRecoveryProof._(
      keyLease,
      _fixedMutableBytes(
        nonceProof,
        e2eeAccountRecoveryNonceProofBytes,
        'nonceProof',
      ),
      _fixedMutableBytes(
        trustSignature,
        e2eeAccountRecoveryTrustSignatureBytes,
        'trustSignature',
      ),
    );
  }

  E2eeAccountRecoveryProof._(
    this.keyLease,
    this._nonceProof,
    this._trustSignature,
  );

  final E2eeAccountRecoveryKeyLease keyLease;
  Uint8List? _nonceProof;
  Uint8List? _trustSignature;

  Uint8List takeNonceProof() {
    final value = _nonceProof;
    if (value == null) throw StateError('账户恢复 nonce proof 已被消费');
    _nonceProof = null;
    return value;
  }

  Uint8List takeTrustSignature() {
    final value = _trustSignature;
    if (value == null) throw StateError('账户恢复信任签名已被消费');
    _trustSignature = null;
    return value;
  }

  void dispose() {
    _clear(_nonceProof);
    _clear(_trustSignature);
    _nonceProof = null;
    _trustSignature = null;
  }
}

abstract interface class E2eeAccountRecoveryProofCore {
  /// 实现必须在单次 Native 事务中解密介质、验证完整历史、打开 capsule、
  /// 校验目标设备绑定并生成 proof；不得向 Dart 暴露恢复私钥、ARK 或明文 nonce。
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
  });

  /// 第二挑战必须连同第一轮 data-rekey 完成证明交给 Native 验证；
  /// Dart 只能获得提交所需 proof，不能自行重建或替换挑战绑定。
  Future<E2eeAccountRecoveryProof> verifyReplacementChallengeAndCreateProof({
    required Uint8List recoveryMedia,
    required Uint8List recoveryPassphrase,
    required Uint8List serviceOriginSha256,
    required List<Uint8List> membershipHistory,
    required Uint8List sourceCapsule,
    required E2eeAccountRecoveryReplacementChallenge challenge,
    required Uint8List recoveryTokenDigest,
    required String expectedDeviceId,
  });
}

final class E2eeAuthorizedAccountRecovery {
  const E2eeAuthorizedAccountRecovery._({
    required this.attemptId,
    required this.recoveryToken,
    required this.recoveryTokenExpiresAt,
    required this.nextAction,
    required this.challenge,
    required this.keyLease,
  });

  final String attemptId;
  final CloudSyncAccountRecoveryToken recoveryToken;
  final DateTime recoveryTokenExpiresAt;
  final E2eeAccountRecoveryNextAction nextAction;
  final E2eeAccountRecoveryChallenge challenge;
  final E2eeAccountRecoveryKeyLease keyLease;
}

enum E2eeAccountRecoveryCheckpointPhase {
  challenged,
  proofReady,
  authorized,
  resumePrepared,
  resumeCommitted,
  firstRekeyFinalized,
  firstLocalActivated,
  replacementChallengeRequested,
  replacementChallengeReceived,
  replacementProofReady,
  replacementPrepared,
  replacementCommitted,
  secondRekeyFinalized,
  secondLocalActivated,
  sessionVerified,
}

sealed class E2eeAccountRecoveryCheckpointProgress {
  const E2eeAccountRecoveryCheckpointProgress();

  E2eeAccountRecoveryCheckpointPhase get phase;
}

final class E2eeAccountRecoveryChallengedProgress
    extends E2eeAccountRecoveryCheckpointProgress {
  const E2eeAccountRecoveryChallengedProgress();

  @override
  E2eeAccountRecoveryCheckpointPhase get phase =>
      E2eeAccountRecoveryCheckpointPhase.challenged;
}

final class E2eeAccountRecoveryCheckpointProof {
  factory E2eeAccountRecoveryCheckpointProof.take({
    required Uint8List nonceProof,
    required Uint8List trustSignature,
  }) {
    Uint8List? ownedNonceProof;
    Uint8List? ownedTrustSignature;
    try {
      ownedNonceProof = _fixedMutableBytes(
        nonceProof,
        e2eeAccountRecoveryNonceProofBytes,
        'nonceProof',
      );
      ownedTrustSignature = _fixedMutableBytes(
        trustSignature,
        e2eeAccountRecoveryTrustSignatureBytes,
        'trustSignature',
      );
      return E2eeAccountRecoveryCheckpointProof._(
        ownedNonceProof.asUnmodifiableView(),
        ownedTrustSignature.asUnmodifiableView(),
      );
    } catch (_) {
      _clear(ownedNonceProof);
      _clear(ownedTrustSignature);
      rethrow;
    }
  }

  const E2eeAccountRecoveryCheckpointProof._(
    this._nonceProof,
    this._trustSignature,
  );

  final Uint8List _nonceProof;
  final Uint8List _trustSignature;

  Uint8List copyNonceProof() => Uint8List.fromList(_nonceProof);

  Uint8List copyTrustSignature() => Uint8List.fromList(_trustSignature);
}

final class E2eeAccountRecoveryProofReadyProgress
    extends E2eeAccountRecoveryCheckpointProgress {
  const E2eeAccountRecoveryProofReadyProgress(this.proof);

  final E2eeAccountRecoveryCheckpointProof proof;

  @override
  E2eeAccountRecoveryCheckpointPhase get phase =>
      E2eeAccountRecoveryCheckpointPhase.proofReady;
}

final class E2eeAccountRecoveryCheckpointAuthorization {
  E2eeAccountRecoveryCheckpointAuthorization({
    required this.proof,
    required DateTime recoveryTokenExpiresAt,
    required this.nextAction,
  }) : recoveryTokenExpiresAt = recoveryTokenExpiresAt.toUtc() {
    if (this.recoveryTokenExpiresAt.millisecondsSinceEpoch <= 0) {
      throw const FormatException('账户恢复 token 过期时间无效');
    }
    if (nextAction != E2eeAccountRecoveryNextAction.recoverResume &&
        nextAction != E2eeAccountRecoveryNextAction.recoverReplace) {
      throw const FormatException('账户恢复 checkpoint 授权下一步无效');
    }
  }

  final E2eeAccountRecoveryCheckpointProof proof;
  final DateTime recoveryTokenExpiresAt;
  final E2eeAccountRecoveryNextAction nextAction;
}

final class E2eeAccountRecoveryAuthorizedProgress
    extends E2eeAccountRecoveryCheckpointProgress {
  const E2eeAccountRecoveryAuthorizedProgress(this.authorization);

  final E2eeAccountRecoveryCheckpointAuthorization authorization;

  @override
  E2eeAccountRecoveryCheckpointPhase get phase =>
      E2eeAccountRecoveryCheckpointPhase.authorized;
}

final class E2eeAccountRecoveryPreparedTransition {
  E2eeAccountRecoveryPreparedTransition({
    required this.commit,
    required this.localTransitionPlan,
  }) {
    try {
      final authorizationDigest =
          localTransitionPlan.operationAuthorizationDigest;
      try {
        if (commit.kind == E2eeAccountRecoveryCommitKind.replacement &&
            !_allZeroBytes(authorizationDigest)) {
          throw const FormatException('账户恢复 replacement 本地绑定必须使用零授权摘要');
        }
      } finally {
        _clear(authorizationDigest);
      }
    } catch (_) {
      localTransitionPlan.clearContinuation();
      rethrow;
    }
  }

  final E2eeAccountRecoveryPreparedCommit commit;
  final E2eeAccountRecoveryLocalTransitionPlan localTransitionPlan;

  E2eeAccountRecoveryPreparedTransition _copy() {
    return E2eeAccountRecoveryPreparedTransition(
      commit: commit,
      localTransitionPlan: localTransitionPlan._copy(),
    );
  }

  void clearContinuation() {
    localTransitionPlan.clearContinuation();
  }
}

final class E2eeAccountRecoveryResumePreparedProgress
    extends E2eeAccountRecoveryCheckpointProgress {
  const E2eeAccountRecoveryResumePreparedProgress({
    required this.authorization,
    required this.transition,
  });

  final E2eeAccountRecoveryCheckpointAuthorization authorization;
  final E2eeAccountRecoveryPreparedTransition transition;

  @override
  E2eeAccountRecoveryCheckpointPhase get phase =>
      E2eeAccountRecoveryCheckpointPhase.resumePrepared;
}

final class E2eeAccountRecoveryResumeCommittedProgress
    extends E2eeAccountRecoveryCheckpointProgress {
  const E2eeAccountRecoveryResumeCommittedProgress({
    required this.authorization,
    required this.transition,
    required this.receipt,
  });

  final E2eeAccountRecoveryCheckpointAuthorization authorization;
  final E2eeAccountRecoveryPreparedTransition transition;
  final E2eeAccountRecoveryCommitReceipt receipt;

  @override
  E2eeAccountRecoveryCheckpointPhase get phase =>
      E2eeAccountRecoveryCheckpointPhase.resumeCommitted;
}

final class E2eeAccountRecoveryFirstRekeyFinalizedProgress
    extends E2eeAccountRecoveryCheckpointProgress {
  const E2eeAccountRecoveryFirstRekeyFinalizedProgress({
    required this.authorization,
    required this.transition,
    required this.receipt,
    required this.completion,
  });

  final E2eeAccountRecoveryCheckpointAuthorization authorization;
  final E2eeAccountRecoveryPreparedTransition transition;
  final E2eeAccountRecoveryCommitReceipt receipt;
  final CloudSyncDataRekeyCompletion completion;

  @override
  E2eeAccountRecoveryCheckpointPhase get phase =>
      E2eeAccountRecoveryCheckpointPhase.firstRekeyFinalized;
}

final class E2eeAccountRecoveryFirstLocalActivatedProgress
    extends E2eeAccountRecoveryCheckpointProgress {
  const E2eeAccountRecoveryFirstLocalActivatedProgress({
    required this.authorization,
    required this.resumeReceipt,
    required this.completion,
    required this.reopenBinding,
  });

  final E2eeAccountRecoveryCheckpointAuthorization authorization;
  final E2eeAccountRecoveryCommitReceipt resumeReceipt;
  final CloudSyncDataRekeyCompletion completion;
  final E2eeAccountRecoveryReopenBinding reopenBinding;

  @override
  E2eeAccountRecoveryCheckpointPhase get phase =>
      E2eeAccountRecoveryCheckpointPhase.firstLocalActivated;
}

final class E2eeAccountRecoveryReplacementChallengeRequestedProgress
    extends E2eeAccountRecoveryCheckpointProgress {
  const E2eeAccountRecoveryReplacementChallengeRequestedProgress({
    required this.authorization,
    required this.resumeReceipt,
    required this.completion,
    required this.request,
    required this.reopenBinding,
  });

  final E2eeAccountRecoveryCheckpointAuthorization authorization;
  final E2eeAccountRecoveryCommitReceipt resumeReceipt;
  final CloudSyncDataRekeyCompletion completion;
  final E2eeAccountRecoveryReplacementChallengeRequest request;
  final E2eeAccountRecoveryReopenBinding reopenBinding;

  @override
  E2eeAccountRecoveryCheckpointPhase get phase =>
      E2eeAccountRecoveryCheckpointPhase.replacementChallengeRequested;
}

final class E2eeAccountRecoveryReplacementChallengeReceivedProgress
    extends E2eeAccountRecoveryCheckpointProgress {
  const E2eeAccountRecoveryReplacementChallengeReceivedProgress({
    required this.authorization,
    required this.challenge,
    required this.reopenBinding,
  });

  final E2eeAccountRecoveryCheckpointAuthorization authorization;
  final E2eeAccountRecoveryReplacementChallenge challenge;
  final E2eeAccountRecoveryReopenBinding reopenBinding;

  @override
  E2eeAccountRecoveryCheckpointPhase get phase =>
      E2eeAccountRecoveryCheckpointPhase.replacementChallengeReceived;
}

final class E2eeAccountRecoveryReplacementProofReadyProgress
    extends E2eeAccountRecoveryCheckpointProgress {
  const E2eeAccountRecoveryReplacementProofReadyProgress({
    required this.authorization,
    required this.challenge,
    required this.proof,
    required this.reopenBinding,
  });

  final E2eeAccountRecoveryCheckpointAuthorization authorization;
  final E2eeAccountRecoveryReplacementChallenge challenge;
  final E2eeAccountRecoveryCheckpointProof proof;
  final E2eeAccountRecoveryReopenBinding reopenBinding;

  @override
  E2eeAccountRecoveryCheckpointPhase get phase =>
      E2eeAccountRecoveryCheckpointPhase.replacementProofReady;
}

final class E2eeAccountRecoveryReplacementPreparedProgress
    extends E2eeAccountRecoveryCheckpointProgress {
  const E2eeAccountRecoveryReplacementPreparedProgress({
    required this.authorization,
    required this.transition,
    required this.reopenBinding,
  });

  final E2eeAccountRecoveryCheckpointAuthorization authorization;
  final E2eeAccountRecoveryPreparedTransition transition;
  final E2eeAccountRecoveryReopenBinding? reopenBinding;

  @override
  E2eeAccountRecoveryCheckpointPhase get phase =>
      E2eeAccountRecoveryCheckpointPhase.replacementPrepared;
}

final class E2eeAccountRecoveryReplacementCommittedProgress
    extends E2eeAccountRecoveryCheckpointProgress {
  const E2eeAccountRecoveryReplacementCommittedProgress({
    required this.authorization,
    required this.transition,
    required this.receipt,
    required this.reopenBinding,
  });

  final E2eeAccountRecoveryCheckpointAuthorization authorization;
  final E2eeAccountRecoveryPreparedTransition transition;
  final E2eeAccountRecoveryCommitReceipt receipt;
  final E2eeAccountRecoveryReopenBinding? reopenBinding;

  @override
  E2eeAccountRecoveryCheckpointPhase get phase =>
      E2eeAccountRecoveryCheckpointPhase.replacementCommitted;
}

final class E2eeAccountRecoverySecondRekeyFinalizedProgress
    extends E2eeAccountRecoveryCheckpointProgress {
  const E2eeAccountRecoverySecondRekeyFinalizedProgress({
    required this.authorization,
    required this.transition,
    required this.receipt,
    required this.completion,
    required this.reopenBinding,
  });

  final E2eeAccountRecoveryCheckpointAuthorization authorization;
  final E2eeAccountRecoveryPreparedTransition transition;
  final E2eeAccountRecoveryCommitReceipt receipt;
  final CloudSyncDataRekeyCompletion completion;
  final E2eeAccountRecoveryReopenBinding? reopenBinding;

  @override
  E2eeAccountRecoveryCheckpointPhase get phase =>
      E2eeAccountRecoveryCheckpointPhase.secondRekeyFinalized;
}

final class E2eeAccountRecoveryCompletionSession {
  E2eeAccountRecoveryCompletionSession({
    required String sessionId,
    required this.token,
  }) : sessionId = _canonicalUuid(sessionId, 'sessionId');

  final String sessionId;
  final CloudSyncFullSessionToken token;
}

final class E2eeAccountRecoverySecondLocalActivatedProgress
    extends E2eeAccountRecoveryCheckpointProgress {
  const E2eeAccountRecoverySecondLocalActivatedProgress({
    required this.authorization,
    required this.completionSession,
    required this.replacementReceipt,
    required this.completion,
    required this.reopenBinding,
  });

  final E2eeAccountRecoveryCheckpointAuthorization authorization;
  final E2eeAccountRecoveryCompletionSession completionSession;
  final E2eeAccountRecoveryCommitReceipt replacementReceipt;
  final CloudSyncDataRekeyCompletion completion;
  final E2eeAccountRecoveryReopenBinding reopenBinding;

  @override
  E2eeAccountRecoveryCheckpointPhase get phase =>
      E2eeAccountRecoveryCheckpointPhase.secondLocalActivated;
}

final class E2eeAccountRecoverySessionVerifiedProgress
    extends E2eeAccountRecoveryCheckpointProgress {
  factory E2eeAccountRecoverySessionVerifiedProgress({
    required E2eeAccountRecoveryCheckpointAuthorization authorization,
    required E2eeAccountRecoveryCompletionSession completionSession,
    required E2eeAccountRecoveryCommitReceipt replacementReceipt,
    required CloudSyncDataRekeyCompletion completion,
    required E2eeAccountRecoveryReopenBinding reopenBinding,
    required int sessionGeneration,
    required DateTime tokenExpiresAt,
  }) {
    return E2eeAccountRecoverySessionVerifiedProgress._(
      authorization: authorization,
      completionSession: completionSession,
      replacementReceipt: replacementReceipt,
      completion: completion,
      reopenBinding: reopenBinding,
      sessionGeneration: _positiveInt32(sessionGeneration, 'sessionGeneration'),
      tokenExpiresAt: _canonicalUtcSecondTimestamp(
        tokenExpiresAt,
        'tokenExpiresAt',
      ),
    );
  }

  const E2eeAccountRecoverySessionVerifiedProgress._({
    required this.authorization,
    required this.completionSession,
    required this.replacementReceipt,
    required this.completion,
    required this.reopenBinding,
    required this.sessionGeneration,
    required this.tokenExpiresAt,
  });

  final E2eeAccountRecoveryCheckpointAuthorization authorization;
  final E2eeAccountRecoveryCompletionSession completionSession;
  final E2eeAccountRecoveryCommitReceipt replacementReceipt;
  final CloudSyncDataRekeyCompletion completion;
  final E2eeAccountRecoveryReopenBinding reopenBinding;
  final int sessionGeneration;
  final DateTime tokenExpiresAt;

  @override
  E2eeAccountRecoveryCheckpointPhase get phase =>
      E2eeAccountRecoveryCheckpointPhase.sessionVerified;
}

final class E2eeAccountRecoveryCheckpoint {
  factory E2eeAccountRecoveryCheckpoint.challenged({
    required String expectedDeviceId,
    required CloudSyncAccountRecoveryToken recoveryToken,
    required E2eeAccountRecoveryChallenge challenge,
  }) {
    return E2eeAccountRecoveryCheckpoint._(
      _canonicalUuid(expectedDeviceId, 'expectedDeviceId'),
      recoveryToken,
      challenge,
      const E2eeAccountRecoveryChallengedProgress(),
    );
  }

  factory E2eeAccountRecoveryCheckpoint.restore({
    required String expectedDeviceId,
    required CloudSyncAccountRecoveryToken recoveryToken,
    required E2eeAccountRecoveryChallenge challenge,
    required E2eeAccountRecoveryCheckpointProgress progress,
  }) {
    final deviceId = _canonicalUuid(expectedDeviceId, 'expectedDeviceId');
    _validateCheckpointProgress(
      expectedDeviceId: deviceId,
      challenge: challenge,
      progress: progress,
    );
    return E2eeAccountRecoveryCheckpoint._(
      deviceId,
      recoveryToken,
      challenge,
      progress,
    );
  }

  const E2eeAccountRecoveryCheckpoint._(
    this.expectedDeviceId,
    this.recoveryToken,
    this.challenge,
    this.progress,
  );

  final String expectedDeviceId;
  final CloudSyncAccountRecoveryToken recoveryToken;
  final E2eeAccountRecoveryChallenge challenge;
  final E2eeAccountRecoveryCheckpointProgress progress;

  String get attemptId => challenge.attemptId;

  E2eeAccountRecoveryCheckpointPhase get phase => progress.phase;

  E2eeAccountRecoveryCheckpoint detachedCopy() {
    return _copyWithProgress(switch (progress) {
      E2eeAccountRecoveryResumePreparedProgress(
        :final authorization,
        :final transition,
      ) =>
        E2eeAccountRecoveryResumePreparedProgress(
          authorization: authorization,
          transition: transition._copy(),
        ),
      E2eeAccountRecoveryResumeCommittedProgress(
        :final authorization,
        :final transition,
        :final receipt,
      ) =>
        E2eeAccountRecoveryResumeCommittedProgress(
          authorization: authorization,
          transition: transition._copy(),
          receipt: receipt,
        ),
      E2eeAccountRecoveryFirstRekeyFinalizedProgress(
        :final authorization,
        :final transition,
        :final receipt,
        :final completion,
      ) =>
        E2eeAccountRecoveryFirstRekeyFinalizedProgress(
          authorization: authorization,
          transition: transition._copy(),
          receipt: receipt,
          completion: completion,
        ),
      E2eeAccountRecoveryReplacementPreparedProgress(
        :final authorization,
        :final transition,
        :final reopenBinding,
      ) =>
        E2eeAccountRecoveryReplacementPreparedProgress(
          authorization: authorization,
          transition: transition._copy(),
          reopenBinding: reopenBinding,
        ),
      E2eeAccountRecoveryReplacementCommittedProgress(
        :final authorization,
        :final transition,
        :final receipt,
        :final reopenBinding,
      ) =>
        E2eeAccountRecoveryReplacementCommittedProgress(
          authorization: authorization,
          transition: transition._copy(),
          receipt: receipt,
          reopenBinding: reopenBinding,
        ),
      E2eeAccountRecoverySecondRekeyFinalizedProgress(
        :final authorization,
        :final transition,
        :final receipt,
        :final completion,
        :final reopenBinding,
      ) =>
        E2eeAccountRecoverySecondRekeyFinalizedProgress(
          authorization: authorization,
          transition: transition._copy(),
          receipt: receipt,
          completion: completion,
          reopenBinding: reopenBinding,
        ),
      E2eeAccountRecoveryChallengedProgress() => progress,
      E2eeAccountRecoveryProofReadyProgress() => progress,
      E2eeAccountRecoveryAuthorizedProgress() => progress,
      E2eeAccountRecoveryFirstLocalActivatedProgress() => progress,
      E2eeAccountRecoveryReplacementChallengeRequestedProgress() => progress,
      E2eeAccountRecoveryReplacementChallengeReceivedProgress() => progress,
      E2eeAccountRecoveryReplacementProofReadyProgress() => progress,
      E2eeAccountRecoverySecondLocalActivatedProgress() => progress,
      E2eeAccountRecoverySessionVerifiedProgress() => progress,
    });
  }

  void clearSensitiveState() {
    switch (progress) {
      case E2eeAccountRecoveryResumePreparedProgress(:final transition) ||
          E2eeAccountRecoveryResumeCommittedProgress(:final transition) ||
          E2eeAccountRecoveryFirstRekeyFinalizedProgress(:final transition) ||
          E2eeAccountRecoveryReplacementPreparedProgress(:final transition) ||
          E2eeAccountRecoveryReplacementCommittedProgress(:final transition) ||
          E2eeAccountRecoverySecondRekeyFinalizedProgress(:final transition):
        transition.clearContinuation();
      case E2eeAccountRecoveryChallengedProgress() ||
          E2eeAccountRecoveryProofReadyProgress() ||
          E2eeAccountRecoveryAuthorizedProgress() ||
          E2eeAccountRecoveryFirstLocalActivatedProgress() ||
          E2eeAccountRecoveryReplacementChallengeRequestedProgress() ||
          E2eeAccountRecoveryReplacementChallengeReceivedProgress() ||
          E2eeAccountRecoveryReplacementProofReadyProgress() ||
          E2eeAccountRecoverySecondLocalActivatedProgress() ||
          E2eeAccountRecoverySessionVerifiedProgress():
        return;
    }
  }

  E2eeAccountRecoveryReopenBinding? get reopenBinding => switch (progress) {
    E2eeAccountRecoveryFirstLocalActivatedProgress(:final reopenBinding) =>
      reopenBinding,
    E2eeAccountRecoveryReplacementChallengeRequestedProgress(
      :final reopenBinding,
    ) =>
      reopenBinding,
    E2eeAccountRecoveryReplacementChallengeReceivedProgress(
      :final reopenBinding,
    ) =>
      reopenBinding,
    E2eeAccountRecoveryReplacementProofReadyProgress(:final reopenBinding) =>
      reopenBinding,
    E2eeAccountRecoveryReplacementPreparedProgress(:final reopenBinding) =>
      reopenBinding,
    E2eeAccountRecoveryReplacementCommittedProgress(:final reopenBinding) =>
      reopenBinding,
    E2eeAccountRecoverySecondRekeyFinalizedProgress(:final reopenBinding) =>
      reopenBinding,
    E2eeAccountRecoverySecondLocalActivatedProgress(:final reopenBinding) =>
      reopenBinding,
    E2eeAccountRecoverySessionVerifiedProgress(:final reopenBinding) =>
      reopenBinding,
    _ => null,
  };

  E2eeAccountRecoveryCheckpoint withProof({
    required Uint8List nonceProof,
    required Uint8List trustSignature,
  }) {
    if (progress is! E2eeAccountRecoveryChallengedProgress) {
      nonceProof.fillRange(0, nonceProof.length, 0);
      trustSignature.fillRange(0, trustSignature.length, 0);
      throw StateError('账户恢复 checkpoint 不处于 challenge 阶段');
    }
    return _copyWithProgress(
      E2eeAccountRecoveryProofReadyProgress(
        E2eeAccountRecoveryCheckpointProof.take(
          nonceProof: nonceProof,
          trustSignature: trustSignature,
        ),
      ),
    );
  }

  E2eeAccountRecoveryCheckpoint authorized({
    required DateTime recoveryTokenExpiresAt,
    required E2eeAccountRecoveryNextAction nextAction,
  }) {
    final current = progress;
    if (current is! E2eeAccountRecoveryProofReadyProgress) {
      throw StateError('账户恢复 checkpoint 尚未生成 proof');
    }
    if (nextAction != E2eeAccountRecoveryNextAction.recoverResume &&
        nextAction != E2eeAccountRecoveryNextAction.recoverReplace) {
      throw const FormatException('账户恢复 checkpoint 授权下一步无效');
    }
    final expectedNextAction =
        challenge.dataState.phase == E2eeAccountRecoveryDataPhase.ready
        ? E2eeAccountRecoveryNextAction.recoverReplace
        : E2eeAccountRecoveryNextAction.recoverResume;
    if (nextAction != expectedNextAction) {
      throw const FormatException('账户恢复 checkpoint 授权动作与 challenge 不一致');
    }
    return _copyWithProgress(
      E2eeAccountRecoveryAuthorizedProgress(
        E2eeAccountRecoveryCheckpointAuthorization(
          proof: current.proof,
          recoveryTokenExpiresAt: recoveryTokenExpiresAt,
          nextAction: nextAction,
        ),
      ),
    );
  }

  E2eeAccountRecoveryCheckpoint prepareTransition({
    required E2eeAccountRecoveryPreparedCommit commit,
    required E2eeAccountRecoveryLocalTransitionPlan localTransitionPlan,
  }) {
    final current = progress;
    final transition = E2eeAccountRecoveryPreparedTransition(
      commit: commit,
      localTransitionPlan: localTransitionPlan,
    );
    try {
      switch (current) {
        case E2eeAccountRecoveryAuthorizedProgress(:final authorization):
          final expectedKind = switch (authorization.nextAction) {
            E2eeAccountRecoveryNextAction.recoverResume =>
              E2eeAccountRecoveryCommitKind.resume,
            E2eeAccountRecoveryNextAction.recoverReplace =>
              E2eeAccountRecoveryCommitKind.replacement,
            _ => throw StateError('账户恢复 checkpoint 当前不应准备成员提交'),
          };
          if (commit.kind != expectedKind) {
            throw const FormatException('账户恢复待提交类型与授权动作不一致');
          }
          _validateInitialPreparedTransition(
            challenge: challenge,
            transition: transition,
          );
          return _copyWithProgress(switch (commit) {
            E2eeAccountRecoveryResumeCommit() =>
              E2eeAccountRecoveryResumePreparedProgress(
                authorization: authorization,
                transition: transition,
              ),
            E2eeAccountRecoveryReplacementCommit() =>
              E2eeAccountRecoveryReplacementPreparedProgress(
                authorization: authorization,
                transition: transition,
                reopenBinding: null,
              ),
          });
        case E2eeAccountRecoveryReplacementProofReadyProgress(
          :final authorization,
          :final challenge,
          :final proof,
          :final reopenBinding,
        ):
          _validateReplacementPreparedTransition(
            challenge: challenge,
            proof: proof,
            transition: transition,
          );
          _validateTransitionSourceReopenBinding(transition, reopenBinding);
          return _copyWithProgress(
            E2eeAccountRecoveryReplacementPreparedProgress(
              authorization: authorization,
              transition: transition,
              reopenBinding: reopenBinding,
            ),
          );
        default:
          throw StateError('账户恢复 checkpoint 当前不可准备成员提交');
      }
    } catch (_) {
      transition.clearContinuation();
      rethrow;
    }
  }

  E2eeAccountRecoveryCheckpoint withCommitReceipt(
    E2eeAccountRecoveryCommitReceipt receipt,
  ) {
    return switch (progress) {
      E2eeAccountRecoveryResumePreparedProgress(
        :final authorization,
        :final transition,
      ) =>
        _commitResume(authorization, transition, receipt),
      E2eeAccountRecoveryReplacementPreparedProgress(
        :final authorization,
        :final transition,
        :final reopenBinding,
      ) =>
        _commitReplacement(
          authorization,
          transition,
          receipt,
          reopenBinding: reopenBinding,
        ),
      _ => throw StateError('账户恢复 checkpoint 不可写入成员提交回执'),
    };
  }

  E2eeAccountRecoveryCheckpoint withRekeyCompletion(
    CloudSyncDataRekeyCompletion completion,
  ) {
    switch (progress) {
      case E2eeAccountRecoveryResumeCommittedProgress(
        :final authorization,
        :final transition,
        :final receipt,
      ):
        _validateRekeyCompletion(
          expectedDeviceId: expectedDeviceId,
          transition: transition,
          receipt: receipt,
          completion: completion,
        );
        return _copyWithProgress(
          E2eeAccountRecoveryFirstRekeyFinalizedProgress(
            authorization: authorization,
            transition: transition._copy(),
            receipt: receipt,
            completion: completion,
          ),
        );
      case E2eeAccountRecoveryReplacementCommittedProgress(
        :final authorization,
        :final transition,
        :final receipt,
        :final reopenBinding,
      ):
        _validateRekeyCompletion(
          expectedDeviceId: expectedDeviceId,
          transition: transition,
          receipt: receipt,
          completion: completion,
        );
        return _copyWithProgress(
          E2eeAccountRecoverySecondRekeyFinalizedProgress(
            authorization: authorization,
            transition: transition._copy(),
            receipt: receipt,
            completion: completion,
            reopenBinding: reopenBinding,
          ),
        );
      default:
        throw StateError('账户恢复 checkpoint 不可写入 data-rekey 完成证明');
    }
  }

  E2eeAccountRecoveryCheckpoint markLocalTransitionActivated({
    required int deviceAuthGeneration,
  }) {
    switch (progress) {
      case E2eeAccountRecoveryFirstRekeyFinalizedProgress(
        :final authorization,
        :final transition,
        :final receipt,
        :final completion,
      ):
        final reopenBinding = _createRecoveryReopenBinding(
          expectedDeviceId: expectedDeviceId,
          transition: transition,
          receipt: receipt,
          completion: completion,
          deviceAuthGeneration: deviceAuthGeneration,
        );
        return _copyWithProgress(
          E2eeAccountRecoveryFirstLocalActivatedProgress(
            authorization: authorization,
            resumeReceipt: receipt,
            completion: completion,
            reopenBinding: reopenBinding,
          ),
        );
      case E2eeAccountRecoverySecondRekeyFinalizedProgress(
        :final authorization,
        :final transition,
        :final receipt,
        :final completion,
      ):
        final commit = transition.commit;
        if (commit is! E2eeAccountRecoveryReplacementCommit) {
          throw StateError('账户恢复第二轮提交类型无效');
        }
        final completionSession = E2eeAccountRecoveryCompletionSession(
          sessionId: commit.completionSessionId,
          token: commit.completionSessionToken,
        );
        final reopenBinding = _createRecoveryReopenBinding(
          expectedDeviceId: expectedDeviceId,
          transition: transition,
          receipt: receipt,
          completion: completion,
          deviceAuthGeneration: deviceAuthGeneration,
        );
        return _copyWithProgress(
          E2eeAccountRecoverySecondLocalActivatedProgress(
            authorization: authorization,
            completionSession: completionSession,
            replacementReceipt: receipt,
            completion: completion,
            reopenBinding: reopenBinding,
          ),
        );
      default:
        throw StateError('账户恢复 checkpoint 不可激活本地候选');
    }
  }

  E2eeAccountRecoveryCheckpoint requestReplacementChallenge(
    E2eeAccountRecoveryReplacementChallengeRequest request,
  ) {
    final current = progress;
    if (current is! E2eeAccountRecoveryFirstLocalActivatedProgress) {
      throw StateError('账户恢复 checkpoint 不可请求 replacement challenge');
    }
    _validateReplacementChallengeRequest(
      receipt: current.resumeReceipt,
      completion: current.completion,
      request: request,
    );
    return _copyWithProgress(
      E2eeAccountRecoveryReplacementChallengeRequestedProgress(
        authorization: current.authorization,
        resumeReceipt: current.resumeReceipt,
        completion: current.completion,
        request: request,
        reopenBinding: current.reopenBinding,
      ),
    );
  }

  E2eeAccountRecoveryCheckpoint withReplacementChallenge(
    E2eeAccountRecoveryReplacementChallenge replacementChallenge,
  ) {
    final current = progress;
    if (current is! E2eeAccountRecoveryReplacementChallengeRequestedProgress) {
      throw StateError('账户恢复 checkpoint 不可写入 replacement challenge');
    }
    _validateReplacementChallengeResponse(
      attemptId: attemptId,
      request: current.request,
      completion: current.completion,
      challenge: replacementChallenge,
    );
    return _copyWithProgress(
      E2eeAccountRecoveryReplacementChallengeReceivedProgress(
        authorization: current.authorization,
        challenge: replacementChallenge,
        reopenBinding: current.reopenBinding,
      ),
    );
  }

  E2eeAccountRecoveryCheckpoint withReplacementProof({
    required Uint8List nonceProof,
    required Uint8List trustSignature,
  }) {
    final current = progress;
    if (current is! E2eeAccountRecoveryReplacementChallengeReceivedProgress) {
      nonceProof.fillRange(0, nonceProof.length, 0);
      trustSignature.fillRange(0, trustSignature.length, 0);
      throw StateError('账户恢复 checkpoint 不可写入 replacement proof');
    }
    return _copyWithProgress(
      E2eeAccountRecoveryReplacementProofReadyProgress(
        authorization: current.authorization,
        challenge: current.challenge,
        proof: E2eeAccountRecoveryCheckpointProof.take(
          nonceProof: nonceProof,
          trustSignature: trustSignature,
        ),
        reopenBinding: current.reopenBinding,
      ),
    );
  }

  E2eeAccountRecoveryCheckpoint markSessionVerified({
    required int sessionGeneration,
    required DateTime tokenExpiresAt,
  }) {
    final current = progress;
    if (current is! E2eeAccountRecoverySecondLocalActivatedProgress) {
      throw StateError('账户恢复 checkpoint 尚不可确认完整会话');
    }
    final normalizedTokenExpiresAt = _canonicalUtcSecondTimestamp(
      tokenExpiresAt,
      'tokenExpiresAt',
    );
    if (!normalizedTokenExpiresAt.isAfter(_utcNow())) {
      throw const FormatException('账户恢复完整会话已过期');
    }
    return _copyWithProgress(
      E2eeAccountRecoverySessionVerifiedProgress(
        authorization: current.authorization,
        completionSession: current.completionSession,
        replacementReceipt: current.replacementReceipt,
        completion: current.completion,
        reopenBinding: current.reopenBinding,
        sessionGeneration: sessionGeneration,
        tokenExpiresAt: normalizedTokenExpiresAt,
      ),
    );
  }

  Uint8List copyNonceProof() {
    return _checkpointProof(progress).copyNonceProof();
  }

  Uint8List copyTrustSignature() {
    return _checkpointProof(progress).copyTrustSignature();
  }

  E2eeAccountRecoveryCheckpoint _copyWithProgress(
    E2eeAccountRecoveryCheckpointProgress nextProgress,
  ) {
    return E2eeAccountRecoveryCheckpoint._(
      expectedDeviceId,
      recoveryToken,
      challenge,
      nextProgress,
    );
  }

  E2eeAccountRecoveryCheckpoint _commitResume(
    E2eeAccountRecoveryCheckpointAuthorization authorization,
    E2eeAccountRecoveryPreparedTransition transition,
    E2eeAccountRecoveryCommitReceipt receipt,
  ) {
    _validateCommitReceipt(transition.commit, receipt);
    return _copyWithProgress(
      E2eeAccountRecoveryResumeCommittedProgress(
        authorization: authorization,
        transition: transition._copy(),
        receipt: receipt,
      ),
    );
  }

  E2eeAccountRecoveryCheckpoint _commitReplacement(
    E2eeAccountRecoveryCheckpointAuthorization authorization,
    E2eeAccountRecoveryPreparedTransition transition,
    E2eeAccountRecoveryCommitReceipt receipt, {
    required E2eeAccountRecoveryReopenBinding? reopenBinding,
  }) {
    _validateCommitReceipt(transition.commit, receipt);
    return _copyWithProgress(
      E2eeAccountRecoveryReplacementCommittedProgress(
        authorization: authorization,
        transition: transition._copy(),
        receipt: receipt,
        reopenBinding: reopenBinding,
      ),
    );
  }
}

E2eeAccountRecoveryReopenBinding _createRecoveryReopenBinding({
  required String expectedDeviceId,
  required E2eeAccountRecoveryPreparedTransition transition,
  required E2eeAccountRecoveryCommitReceipt receipt,
  required CloudSyncDataRekeyCompletion completion,
  required int deviceAuthGeneration,
}) {
  final plan = transition.localTransitionPlan;
  final prunedState = plan.prunedStateBlob;
  final manifestDigest =
      transition.commit.membership.nextMembershipManifestDigest.bytes;
  try {
    if (receipt.membershipOperationId !=
            transition.commit.membership.operationId ||
        completion.membershipGeneration != receipt.generation ||
        !_sameBytes(completion.membershipManifestDigest, manifestDigest)) {
      throw const FormatException('账户恢复重开绑定与完成状态不一致');
    }
    return E2eeAccountRecoveryReopenBinding(
      userId: plan.userId,
      deviceId: expectedDeviceId,
      deviceKeyVersion: plan.deviceKeyVersion,
      deviceAuthGeneration: deviceAuthGeneration,
      keyEpoch: receipt.keyEpoch,
      dataGeneration: completion.targetDataGeneration,
      membershipGeneration: receipt.generation,
      membershipManifestDigest: manifestDigest,
      membershipOperationId: receipt.membershipOperationId,
      prunedStateDigest: Uint8List.fromList(sha256.convert(prunedState).bytes),
    );
  } finally {
    _clear(prunedState);
  }
}

E2eeAccountRecoveryCheckpointProof _checkpointProof(
  E2eeAccountRecoveryCheckpointProgress progress,
) => switch (progress) {
  E2eeAccountRecoveryProofReadyProgress(:final proof) => proof,
  E2eeAccountRecoveryAuthorizedProgress(:final authorization) =>
    authorization.proof,
  E2eeAccountRecoveryResumePreparedProgress(:final authorization) =>
    authorization.proof,
  E2eeAccountRecoveryResumeCommittedProgress(:final authorization) =>
    authorization.proof,
  E2eeAccountRecoveryFirstRekeyFinalizedProgress(:final authorization) =>
    authorization.proof,
  E2eeAccountRecoveryFirstLocalActivatedProgress(:final authorization) =>
    authorization.proof,
  E2eeAccountRecoveryReplacementChallengeRequestedProgress(
    :final authorization,
  ) =>
    authorization.proof,
  E2eeAccountRecoveryReplacementChallengeReceivedProgress(
    :final authorization,
  ) =>
    authorization.proof,
  E2eeAccountRecoveryReplacementProofReadyProgress(:final authorization) =>
    authorization.proof,
  E2eeAccountRecoveryReplacementPreparedProgress(:final authorization) =>
    authorization.proof,
  E2eeAccountRecoveryReplacementCommittedProgress(:final authorization) =>
    authorization.proof,
  E2eeAccountRecoverySecondRekeyFinalizedProgress(:final authorization) =>
    authorization.proof,
  E2eeAccountRecoverySecondLocalActivatedProgress(:final authorization) =>
    authorization.proof,
  E2eeAccountRecoverySessionVerifiedProgress(:final authorization) =>
    authorization.proof,
  E2eeAccountRecoveryChallengedProgress() => throw StateError(
    '账户恢复 checkpoint 不含 proof',
  ),
};

E2eeAccountRecoveryCheckpointAuthorization? _checkpointAuthorization(
  E2eeAccountRecoveryCheckpointProgress progress,
) => switch (progress) {
  E2eeAccountRecoveryAuthorizedProgress(:final authorization) => authorization,
  E2eeAccountRecoveryResumePreparedProgress(:final authorization) =>
    authorization,
  E2eeAccountRecoveryResumeCommittedProgress(:final authorization) =>
    authorization,
  E2eeAccountRecoveryFirstRekeyFinalizedProgress(:final authorization) =>
    authorization,
  E2eeAccountRecoveryFirstLocalActivatedProgress(:final authorization) =>
    authorization,
  E2eeAccountRecoveryReplacementChallengeRequestedProgress(
    :final authorization,
  ) =>
    authorization,
  E2eeAccountRecoveryReplacementChallengeReceivedProgress(
    :final authorization,
  ) =>
    authorization,
  E2eeAccountRecoveryReplacementProofReadyProgress(:final authorization) =>
    authorization,
  E2eeAccountRecoveryReplacementPreparedProgress(:final authorization) =>
    authorization,
  E2eeAccountRecoveryReplacementCommittedProgress(:final authorization) =>
    authorization,
  E2eeAccountRecoverySecondRekeyFinalizedProgress(:final authorization) =>
    authorization,
  E2eeAccountRecoverySecondLocalActivatedProgress(:final authorization) =>
    authorization,
  E2eeAccountRecoverySessionVerifiedProgress(:final authorization) =>
    authorization,
  E2eeAccountRecoveryChallengedProgress() ||
  E2eeAccountRecoveryProofReadyProgress() => null,
};

bool _preTransitionCheckpointExpired(
  E2eeAccountRecoveryCheckpoint checkpoint,
  DateTime now,
) => switch (checkpoint.progress) {
  E2eeAccountRecoveryChallengedProgress() ||
  E2eeAccountRecoveryProofReadyProgress() => !now.isBefore(
    checkpoint.challenge.expiresAt,
  ),
  E2eeAccountRecoveryAuthorizedProgress(:final authorization) => !now.isBefore(
    authorization.recoveryTokenExpiresAt,
  ),
  _ => false,
};

E2eeAccountRecoveryCommitReceipt? _checkpointCommitReceipt(
  E2eeAccountRecoveryCheckpointProgress progress,
) => switch (progress) {
  E2eeAccountRecoveryResumeCommittedProgress(:final receipt) => receipt,
  E2eeAccountRecoveryFirstRekeyFinalizedProgress(:final receipt) => receipt,
  E2eeAccountRecoveryFirstLocalActivatedProgress(:final resumeReceipt) =>
    resumeReceipt,
  E2eeAccountRecoveryReplacementChallengeRequestedProgress(
    :final resumeReceipt,
  ) =>
    resumeReceipt,
  E2eeAccountRecoveryReplacementCommittedProgress(:final receipt) => receipt,
  E2eeAccountRecoverySecondRekeyFinalizedProgress(:final receipt) => receipt,
  E2eeAccountRecoverySecondLocalActivatedProgress(:final replacementReceipt) =>
    replacementReceipt,
  E2eeAccountRecoverySessionVerifiedProgress(:final replacementReceipt) =>
    replacementReceipt,
  _ => null,
};

void _validateCheckpointProgress({
  required String expectedDeviceId,
  required E2eeAccountRecoveryChallenge challenge,
  required E2eeAccountRecoveryCheckpointProgress progress,
}) {
  switch (progress) {
    case E2eeAccountRecoveryChallengedProgress() ||
        E2eeAccountRecoveryProofReadyProgress():
      return;
    case E2eeAccountRecoveryAuthorizedProgress(:final authorization):
      _validateInitialAuthorization(challenge, authorization);
    case E2eeAccountRecoveryResumePreparedProgress(
      :final authorization,
      :final transition,
    ):
      _validateInitialAuthorization(challenge, authorization);
      _validateInitialPreparedTransition(
        challenge: challenge,
        transition: transition,
      );
    case E2eeAccountRecoveryResumeCommittedProgress(
      :final authorization,
      :final transition,
      :final receipt,
    ):
      _validateInitialAuthorization(challenge, authorization);
      _validateInitialPreparedTransition(
        challenge: challenge,
        transition: transition,
      );
      _validateCommitReceipt(transition.commit, receipt);
    case E2eeAccountRecoveryFirstRekeyFinalizedProgress(
      :final authorization,
      :final transition,
      :final receipt,
      :final completion,
    ):
      _validateInitialAuthorization(challenge, authorization);
      _validateInitialPreparedTransition(
        challenge: challenge,
        transition: transition,
      );
      _validateCommitReceipt(transition.commit, receipt);
      _validateRekeyCompletion(
        expectedDeviceId: expectedDeviceId,
        transition: transition,
        receipt: receipt,
        completion: completion,
      );
    case E2eeAccountRecoveryFirstLocalActivatedProgress(
      :final authorization,
      :final resumeReceipt,
      :final completion,
      :final reopenBinding,
    ):
      _validateInitialAuthorization(challenge, authorization);
      _validateFirstCompletionSummary(
        expectedDeviceId: expectedDeviceId,
        challenge: challenge,
        receipt: resumeReceipt,
        completion: completion,
      );
      _validateActivatedReopenBinding(
        expectedDeviceId: expectedDeviceId,
        receipt: resumeReceipt,
        completion: completion,
        binding: reopenBinding,
      );
    case E2eeAccountRecoveryReplacementChallengeRequestedProgress(
      :final authorization,
      :final resumeReceipt,
      :final completion,
      :final request,
      :final reopenBinding,
    ):
      _validateInitialAuthorization(challenge, authorization);
      _validateFirstCompletionSummary(
        expectedDeviceId: expectedDeviceId,
        challenge: challenge,
        receipt: resumeReceipt,
        completion: completion,
      );
      _validateReplacementChallengeRequest(
        receipt: resumeReceipt,
        completion: completion,
        request: request,
      );
      _validateActivatedReopenBinding(
        expectedDeviceId: expectedDeviceId,
        receipt: resumeReceipt,
        completion: completion,
        binding: reopenBinding,
      );
    case E2eeAccountRecoveryReplacementChallengeReceivedProgress(
      :final authorization,
      challenge: final replacementChallenge,
      :final reopenBinding,
    ):
      _validateInitialAuthorization(
        challenge,
        authorization,
        expectedAction: E2eeAccountRecoveryNextAction.recoverResume,
      );
      _validateReplacementChallengeSummary(
        expectedDeviceId: expectedDeviceId,
        initialChallenge: challenge,
        replacementChallenge: replacementChallenge,
      );
      _validateReplacementChallengeReopenBinding(
        replacementChallenge,
        reopenBinding,
      );
    case E2eeAccountRecoveryReplacementProofReadyProgress(
      :final authorization,
      challenge: final replacementChallenge,
      :final reopenBinding,
    ):
      _validateInitialAuthorization(
        challenge,
        authorization,
        expectedAction: E2eeAccountRecoveryNextAction.recoverResume,
      );
      _validateReplacementChallengeSummary(
        expectedDeviceId: expectedDeviceId,
        initialChallenge: challenge,
        replacementChallenge: replacementChallenge,
      );
      _validateReplacementChallengeReopenBinding(
        replacementChallenge,
        reopenBinding,
      );
    case E2eeAccountRecoveryReplacementPreparedProgress(
      :final authorization,
      :final transition,
      :final reopenBinding,
    ):
      _validateInitialAuthorization(challenge, authorization);
      _validateRestoredReplacementTransition(
        challenge,
        transition,
        reopenBinding: reopenBinding,
      );
    case E2eeAccountRecoveryReplacementCommittedProgress(
      :final authorization,
      :final transition,
      :final receipt,
      :final reopenBinding,
    ):
      _validateInitialAuthorization(challenge, authorization);
      _validateRestoredReplacementTransition(
        challenge,
        transition,
        reopenBinding: reopenBinding,
      );
      _validateCommitReceipt(transition.commit, receipt);
    case E2eeAccountRecoverySecondRekeyFinalizedProgress(
      :final authorization,
      :final transition,
      :final receipt,
      :final completion,
      :final reopenBinding,
    ):
      _validateInitialAuthorization(challenge, authorization);
      _validateRestoredReplacementTransition(
        challenge,
        transition,
        reopenBinding: reopenBinding,
      );
      _validateCommitReceipt(transition.commit, receipt);
      _validateRekeyCompletion(
        expectedDeviceId: expectedDeviceId,
        transition: transition,
        receipt: receipt,
        completion: completion,
      );
    case E2eeAccountRecoverySecondLocalActivatedProgress(
      :final authorization,
      :final completionSession,
      :final replacementReceipt,
      :final completion,
      :final reopenBinding,
    ):
      _validateInitialAuthorization(challenge, authorization);
      _validateTerminalReplacementSummary(
        initialChallenge: challenge,
        completionSession: completionSession,
        receipt: replacementReceipt,
        completion: completion,
        expectedDeviceId: expectedDeviceId,
      );
      _validateActivatedReopenBinding(
        expectedDeviceId: expectedDeviceId,
        receipt: replacementReceipt,
        completion: completion,
        binding: reopenBinding,
      );
    case E2eeAccountRecoverySessionVerifiedProgress(
      :final authorization,
      :final completionSession,
      :final replacementReceipt,
      :final completion,
      :final reopenBinding,
    ):
      _validateInitialAuthorization(challenge, authorization);
      _validateTerminalReplacementSummary(
        initialChallenge: challenge,
        completionSession: completionSession,
        receipt: replacementReceipt,
        completion: completion,
        expectedDeviceId: expectedDeviceId,
      );
      _validateActivatedReopenBinding(
        expectedDeviceId: expectedDeviceId,
        receipt: replacementReceipt,
        completion: completion,
        binding: reopenBinding,
      );
  }
}

void _validateInitialAuthorization(
  E2eeAccountRecoveryChallenge challenge,
  E2eeAccountRecoveryCheckpointAuthorization authorization, {
  E2eeAccountRecoveryNextAction? expectedAction,
}) {
  final expected =
      expectedAction ??
      (challenge.dataState.phase == E2eeAccountRecoveryDataPhase.ready
          ? E2eeAccountRecoveryNextAction.recoverReplace
          : E2eeAccountRecoveryNextAction.recoverResume);
  if (authorization.nextAction != expected) {
    throw const FormatException('账户恢复授权动作与初始 challenge 不一致');
  }
}

void _validateInitialPreparedTransition({
  required E2eeAccountRecoveryChallenge challenge,
  required E2eeAccountRecoveryPreparedTransition transition,
}) {
  final commit = transition.commit;
  final membership = commit.membership;
  final plan = transition.localTransitionPlan;
  if (commit.attemptId != challenge.attemptId ||
      membership.expectedGeneration != challenge.securityGeneration ||
      membership.expectedKeyEpoch != challenge.keyEpoch ||
      !_sameBytes(
        membership.expectedMembershipManifestDigest.bytes,
        challenge.membershipManifestDigest,
      ) ||
      plan.sourceDataGeneration != challenge.dataState.dataGeneration) {
    throw const FormatException('账户恢复待提交请求未绑定初始 challenge');
  }
  switch (commit) {
    case E2eeAccountRecoveryResumeCommit(:final rekeyOperationId):
      if (challenge.dataState.phase !=
              E2eeAccountRecoveryDataPhase.rekeyPending ||
          rekeyOperationId != challenge.dataState.operationId ||
          membership.envelope.keyEpoch != challenge.keyEpoch) {
        throw const FormatException('账户恢复 resume 提交绑定无效');
      }
    case E2eeAccountRecoveryReplacementCommit(:final authorization):
      if (challenge.dataState.phase != E2eeAccountRecoveryDataPhase.ready ||
          membership.envelope.keyEpoch != challenge.keyEpoch + 1 ||
          commit.nextRecoveryCapsuleVersion !=
              challenge.recoveryCapsuleVersion + 1 ||
          authorization
              is! E2eeAccountRecoveryReplacementInitialAuthorization ||
          !_sameBytes(
            authorization.challengeRequestDigest,
            challenge.requestDigest,
          )) {
        throw const FormatException('账户恢复 direct replacement 提交绑定无效');
      }
  }
}

void _validateReplacementPreparedTransition({
  required E2eeAccountRecoveryReplacementChallenge challenge,
  required E2eeAccountRecoveryCheckpointProof proof,
  required E2eeAccountRecoveryPreparedTransition transition,
}) {
  final commit = transition.commit;
  if (commit is! E2eeAccountRecoveryReplacementCommit) {
    throw const FormatException('账户恢复第二挑战只能准备 replacement 提交');
  }
  final authorization = commit.authorization;
  final membership = commit.membership;
  final plan = transition.localTransitionPlan;
  final nonceProof = proof.copyNonceProof();
  final trustSignature = proof.copyTrustSignature();
  try {
    if (authorization
            is! E2eeAccountRecoveryReplacementChallengeAuthorization ||
        commit.attemptId != challenge.attemptId ||
        authorization.challengeId != challenge.challengeId ||
        !_sameBytes(
          authorization.challengeRequestDigest,
          challenge.requestDigest,
        ) ||
        !_sameBytes(authorization.nonceProof, nonceProof) ||
        !_sameBytes(authorization.trustSignature, trustSignature) ||
        membership.expectedGeneration != challenge.securityGeneration ||
        membership.expectedKeyEpoch != challenge.keyEpoch ||
        !_sameBytes(
          membership.expectedMembershipManifestDigest.bytes,
          challenge.membershipManifestDigest,
        ) ||
        membership.envelope.keyEpoch != challenge.keyEpoch + 1 ||
        commit.nextRecoveryCapsuleVersion !=
            challenge.recoveryCapsuleVersion + 1 ||
        plan.deviceKeyVersion != challenge.deviceKeyVersion ||
        plan.sourceDataGeneration != challenge.dataGeneration) {
      throw const FormatException('账户恢复 replacement 提交未绑定第二 challenge');
    }
  } finally {
    _clear(nonceProof);
    _clear(trustSignature);
  }
}

void _validateRestoredReplacementTransition(
  E2eeAccountRecoveryChallenge initialChallenge,
  E2eeAccountRecoveryPreparedTransition transition, {
  required E2eeAccountRecoveryReopenBinding? reopenBinding,
}) {
  final commit = transition.commit;
  if (commit is! E2eeAccountRecoveryReplacementCommit ||
      commit.attemptId != initialChallenge.attemptId) {
    throw const FormatException('账户恢复 replacement checkpoint 提交无效');
  }
  final authorization = commit.authorization;
  if (authorization is E2eeAccountRecoveryReplacementInitialAuthorization) {
    if (reopenBinding != null) {
      throw const FormatException('direct replacement 不应持有首轮重开绑定');
    }
    _validateInitialPreparedTransition(
      challenge: initialChallenge,
      transition: transition,
    );
  } else if (authorization
      is E2eeAccountRecoveryReplacementChallengeAuthorization) {
    if (reopenBinding == null) {
      throw const FormatException('第二挑战 replacement 缺少首轮重开绑定');
    }
    final membership = commit.membership;
    final plan = transition.localTransitionPlan;
    if (initialChallenge.dataState.phase !=
            E2eeAccountRecoveryDataPhase.rekeyPending ||
        membership.expectedGeneration !=
            initialChallenge.securityGeneration + 1 ||
        membership.expectedKeyEpoch != initialChallenge.keyEpoch ||
        membership.envelope.keyEpoch != initialChallenge.keyEpoch + 1 ||
        plan.sourceDataGeneration !=
            initialChallenge.dataState.dataGeneration + 1) {
      throw const FormatException('账户恢复第二挑战 replacement checkpoint 绑定无效');
    }
    _validateTransitionSourceReopenBinding(transition, reopenBinding);
  } else {
    throw const FormatException('账户恢复 replacement checkpoint 授权无效');
  }
}

void _validateActivatedReopenBinding({
  required String expectedDeviceId,
  required E2eeAccountRecoveryCommitReceipt receipt,
  required CloudSyncDataRekeyCompletion completion,
  required E2eeAccountRecoveryReopenBinding binding,
}) {
  final membershipDigest = binding.membershipManifestDigest;
  try {
    if (binding.deviceId != expectedDeviceId ||
        binding.keyEpoch != receipt.keyEpoch ||
        binding.dataGeneration != completion.targetDataGeneration ||
        binding.membershipGeneration != receipt.generation ||
        binding.membershipOperationId != receipt.membershipOperationId ||
        !_sameBytes(membershipDigest, completion.membershipManifestDigest)) {
      throw const FormatException('账户恢复 checkpoint 重开绑定与激活摘要不一致');
    }
  } finally {
    _clear(membershipDigest);
  }
}

void _validateReplacementChallengeReopenBinding(
  E2eeAccountRecoveryReplacementChallenge challenge,
  E2eeAccountRecoveryReopenBinding binding,
) {
  final membershipDigest = binding.membershipManifestDigest;
  try {
    if (binding.deviceId != challenge.sourceCompletion.issuerDeviceId ||
        binding.deviceKeyVersion != challenge.deviceKeyVersion ||
        binding.keyEpoch != challenge.keyEpoch ||
        binding.dataGeneration != challenge.dataGeneration ||
        binding.membershipGeneration != challenge.securityGeneration ||
        binding.membershipOperationId != challenge.membershipOperationId ||
        !_sameBytes(membershipDigest, challenge.membershipManifestDigest)) {
      throw const FormatException('账户恢复第二 challenge 与本地重开绑定不一致');
    }
  } finally {
    _clear(membershipDigest);
  }
}

void _validateTransitionSourceReopenBinding(
  E2eeAccountRecoveryPreparedTransition transition,
  E2eeAccountRecoveryReopenBinding binding,
) {
  final plan = transition.localTransitionPlan;
  final membership = transition.commit.membership;
  final sourceState = plan.sourceStateBlob;
  final expectedStateDigest = binding.prunedStateDigest;
  final membershipDigest = binding.membershipManifestDigest;
  try {
    if (plan.userId != binding.userId ||
        plan.deviceKeyVersion != binding.deviceKeyVersion ||
        plan.sourceDataGeneration != binding.dataGeneration ||
        membership.expectedGeneration != binding.membershipGeneration ||
        membership.expectedKeyEpoch != binding.keyEpoch ||
        !_sameBytes(
          membership.expectedMembershipManifestDigest.bytes,
          membershipDigest,
        ) ||
        !_sameBytes(
          Uint8List.fromList(sha256.convert(sourceState).bytes),
          expectedStateDigest,
        )) {
      throw const FormatException('账户恢复 replacement 源状态与重开绑定不一致');
    }
  } finally {
    _clear(sourceState);
    _clear(expectedStateDigest);
    _clear(membershipDigest);
  }
}

void _validateReplacementChallengeSummary({
  required String expectedDeviceId,
  required E2eeAccountRecoveryChallenge initialChallenge,
  required E2eeAccountRecoveryReplacementChallenge replacementChallenge,
}) {
  final initialDataState = initialChallenge.dataState;
  final sourceCompletion = replacementChallenge.sourceCompletion;
  if (initialDataState.phase != E2eeAccountRecoveryDataPhase.rekeyPending ||
      replacementChallenge.attemptId != initialChallenge.attemptId ||
      replacementChallenge.securityGeneration !=
          initialChallenge.securityGeneration + 1 ||
      replacementChallenge.keyEpoch != initialChallenge.keyEpoch ||
      replacementChallenge.dataGeneration !=
          initialDataState.dataGeneration + 1 ||
      replacementChallenge.dataKeyEpoch != initialChallenge.keyEpoch ||
      replacementChallenge.sourceRekeyOperationId !=
          initialDataState.operationId ||
      sourceCompletion.operationId != initialDataState.operationId ||
      sourceCompletion.issuerDeviceId != expectedDeviceId ||
      sourceCompletion.sourceDataGeneration !=
          initialDataState.dataGeneration ||
      sourceCompletion.targetDataGeneration !=
          initialDataState.dataGeneration + 1 ||
      sourceCompletion.sourceKeyEpoch != initialDataState.dataKeyEpoch ||
      sourceCompletion.targetKeyEpoch != initialChallenge.keyEpoch ||
      sourceCompletion.membershipGeneration !=
          initialChallenge.securityGeneration + 1) {
    throw const FormatException('账户恢复 replacement challenge 摘要无效');
  }
}

void _validateCommitReceipt(
  E2eeAccountRecoveryPreparedCommit prepared,
  E2eeAccountRecoveryCommitReceipt receipt,
) {
  final membership = prepared.membership;
  final expectedRekeyOperationId = switch (prepared) {
    E2eeAccountRecoveryResumeCommit(:final rekeyOperationId) =>
      rekeyOperationId,
    E2eeAccountRecoveryReplacementCommit() => membership.operationId,
  };
  final expectedKeyEpoch = switch (prepared) {
    E2eeAccountRecoveryResumeCommit() => membership.expectedKeyEpoch,
    E2eeAccountRecoveryReplacementCommit() => membership.expectedKeyEpoch + 1,
  };
  final expectedNextAction = switch (prepared) {
    E2eeAccountRecoveryResumeCommit() =>
      E2eeAccountRecoveryNextAction.finishFirstDataRekey,
    E2eeAccountRecoveryReplacementCommit() =>
      E2eeAccountRecoveryNextAction.finishSecondDataRekey,
  };
  if (receipt.kind != prepared.kind ||
      receipt.attemptId != prepared.attemptId ||
      receipt.membershipOperationId != membership.operationId ||
      receipt.rekeyOperationId != expectedRekeyOperationId ||
      receipt.generation != membership.expectedGeneration + 1 ||
      receipt.keyEpoch != expectedKeyEpoch ||
      receipt.nextAction != expectedNextAction) {
    throw const FormatException('账户恢复成员提交回执未绑定待提交请求');
  }
}

void _validateRekeyCompletion({
  required String expectedDeviceId,
  required E2eeAccountRecoveryPreparedTransition transition,
  required E2eeAccountRecoveryCommitReceipt receipt,
  required CloudSyncDataRekeyCompletion completion,
}) {
  final commit = transition.commit;
  final membership = commit.membership;
  final plan = transition.localTransitionPlan;
  final expectedSourceKeyEpoch = switch (commit) {
    E2eeAccountRecoveryResumeCommit() => membership.expectedKeyEpoch - 1,
    E2eeAccountRecoveryReplacementCommit() => membership.expectedKeyEpoch,
  };
  if (completion.operationId != receipt.rekeyOperationId ||
      completion.issuerDeviceId != expectedDeviceId ||
      completion.sourceDataGeneration != plan.sourceDataGeneration ||
      completion.targetDataGeneration != plan.sourceDataGeneration + 1 ||
      completion.sourceKeyEpoch != expectedSourceKeyEpoch ||
      completion.targetKeyEpoch != receipt.keyEpoch ||
      completion.membershipGeneration != receipt.generation ||
      !_sameBytes(
        completion.membershipManifestDigest,
        membership.nextMembershipManifestDigest.bytes,
      )) {
    throw const FormatException('账户恢复 data-rekey 完成证明未绑定当前提交');
  }
}

void _validateFirstCompletionSummary({
  required String expectedDeviceId,
  required E2eeAccountRecoveryChallenge challenge,
  required E2eeAccountRecoveryCommitReceipt receipt,
  required CloudSyncDataRekeyCompletion completion,
}) {
  if (receipt.kind != E2eeAccountRecoveryCommitKind.resume ||
      receipt.attemptId != challenge.attemptId ||
      receipt.nextAction !=
          E2eeAccountRecoveryNextAction.finishFirstDataRekey ||
      completion.operationId != receipt.rekeyOperationId ||
      completion.issuerDeviceId != expectedDeviceId ||
      completion.sourceDataGeneration != challenge.dataState.dataGeneration ||
      completion.targetDataGeneration !=
          challenge.dataState.dataGeneration + 1 ||
      completion.sourceKeyEpoch != challenge.dataState.dataKeyEpoch ||
      completion.targetKeyEpoch != receipt.keyEpoch ||
      completion.membershipGeneration != receipt.generation) {
    throw const FormatException('账户恢复首轮完成摘要无效');
  }
}

void _validateReplacementChallengeRequest({
  required E2eeAccountRecoveryCommitReceipt receipt,
  required CloudSyncDataRekeyCompletion completion,
  required E2eeAccountRecoveryReplacementChallengeRequest request,
}) {
  if (request.expectedGeneration != receipt.generation ||
      request.expectedKeyEpoch != receipt.keyEpoch ||
      !_sameBytes(
        request.expectedMembershipManifestDigest,
        completion.membershipManifestDigest,
      ) ||
      request.expectedMembershipOperationId != receipt.membershipOperationId ||
      request.dataGeneration != completion.targetDataGeneration ||
      request.dataKeyEpoch != completion.targetKeyEpoch ||
      request.sourceRekeyOperationId != completion.operationId ||
      !_sameBytes(
        request.sourceCompletionProofDigest,
        completion.proofDigest,
      )) {
    throw const FormatException('账户恢复 replacement challenge 请求未绑定首轮完成');
  }
}

void _validateReplacementChallengeResponse({
  required String attemptId,
  required E2eeAccountRecoveryReplacementChallengeRequest request,
  required CloudSyncDataRekeyCompletion completion,
  required E2eeAccountRecoveryReplacementChallenge challenge,
}) {
  if (challenge.challengeId != request.challengeId ||
      challenge.attemptId != attemptId ||
      challenge.securityGeneration != request.expectedGeneration ||
      challenge.keyEpoch != request.expectedKeyEpoch ||
      !_sameBytes(
        challenge.membershipManifestDigest,
        request.expectedMembershipManifestDigest,
      ) ||
      challenge.membershipOperationId !=
          request.expectedMembershipOperationId ||
      challenge.dataGeneration != request.dataGeneration ||
      challenge.dataKeyEpoch != request.dataKeyEpoch ||
      challenge.sourceRekeyOperationId != request.sourceRekeyOperationId ||
      !_sameBytes(
        challenge.sourceCompletion.proofDigest,
        request.sourceCompletionProofDigest,
      ) ||
      !_sameDataRekeyCompletion(challenge.sourceCompletion, completion)) {
    throw const FormatException('账户恢复 replacement challenge 响应未绑定请求');
  }
}

void _validateTerminalReplacementSummary({
  required E2eeAccountRecoveryChallenge initialChallenge,
  required E2eeAccountRecoveryCompletionSession completionSession,
  required E2eeAccountRecoveryCommitReceipt receipt,
  required CloudSyncDataRekeyCompletion completion,
  required String expectedDeviceId,
}) {
  final resumed =
      initialChallenge.dataState.phase ==
      E2eeAccountRecoveryDataPhase.rekeyPending;
  final expectedGeneration =
      initialChallenge.securityGeneration + (resumed ? 2 : 1);
  final expectedSourceDataGeneration =
      initialChallenge.dataState.dataGeneration + (resumed ? 1 : 0);
  if (completionSession.sessionId.isEmpty ||
      receipt.kind != E2eeAccountRecoveryCommitKind.replacement ||
      receipt.attemptId != initialChallenge.attemptId ||
      receipt.generation != expectedGeneration ||
      receipt.keyEpoch != initialChallenge.keyEpoch + 1 ||
      receipt.nextAction !=
          E2eeAccountRecoveryNextAction.finishSecondDataRekey ||
      completion.operationId != receipt.rekeyOperationId ||
      completion.issuerDeviceId != expectedDeviceId ||
      completion.sourceDataGeneration != expectedSourceDataGeneration ||
      completion.targetDataGeneration != expectedSourceDataGeneration + 1 ||
      completion.sourceKeyEpoch != initialChallenge.keyEpoch ||
      completion.membershipGeneration != receipt.generation ||
      completion.targetKeyEpoch != receipt.keyEpoch) {
    throw const FormatException('账户恢复第二轮完成摘要无效');
  }
}

bool _sameDataRekeyCompletion(
  CloudSyncDataRekeyCompletion left,
  CloudSyncDataRekeyCompletion right,
) {
  final leftAttachmentCursor = left.sourceAttachmentCursorEnd;
  final rightAttachmentCursor = right.sourceAttachmentCursorEnd;
  return left.proofVersion == right.proofVersion &&
      left.operationId == right.operationId &&
      left.issuerDeviceId == right.issuerDeviceId &&
      left.sourceDataGeneration == right.sourceDataGeneration &&
      left.targetDataGeneration == right.targetDataGeneration &&
      left.sourceKeyEpoch == right.sourceKeyEpoch &&
      left.targetKeyEpoch == right.targetKeyEpoch &&
      _sameBytes(left.sourceSnapshotRoot, right.sourceSnapshotRoot) &&
      left.sourceRecordCount == right.sourceRecordCount &&
      left.sourceAttachmentCount == right.sourceAttachmentCount &&
      left.sourceMaximumChangeSeq == right.sourceMaximumChangeSeq &&
      left.sourceRecordCursorEnd == right.sourceRecordCursorEnd &&
      leftAttachmentCursor?.attachmentId ==
          rightAttachmentCursor?.attachmentId &&
      leftAttachmentCursor?.uploadId == rightAttachmentCursor?.uploadId &&
      left.membershipGeneration == right.membershipGeneration &&
      _sameBytes(
        left.membershipManifestDigest,
        right.membershipManifestDigest,
      ) &&
      left.stagedRecordCount == right.stagedRecordCount &&
      left.stagedAttachmentCount == right.stagedAttachmentCount &&
      _sameBytes(
        left.stagedCiphertextSetDigest,
        right.stagedCiphertextSetDigest,
      ) &&
      _sameBytes(left.proofFrame, right.proofFrame) &&
      _sameBytes(left.proofDigest, right.proofDigest) &&
      _sameBytes(left.signature, right.signature) &&
      left.finalizedAt == right.finalizedAt;
}

bool _allZeroBytes(Uint8List value) {
  var difference = 0;
  for (final byte in value) {
    difference |= byte;
  }
  return difference == 0;
}

final class E2eeAccountRecoveryCheckpointSnapshot {
  factory E2eeAccountRecoveryCheckpointSnapshot({
    required E2eeAccountRecoveryCheckpoint checkpoint,
    required Uint8List envelopeDigest,
  }) {
    return E2eeAccountRecoveryCheckpointSnapshot._(
      checkpoint,
      _fixedBytes(envelopeDigest, 32, 'envelopeDigest'),
    );
  }

  const E2eeAccountRecoveryCheckpointSnapshot._(
    this.checkpoint,
    this.envelopeDigest,
  );

  final E2eeAccountRecoveryCheckpoint checkpoint;
  final Uint8List envelopeDigest;

  E2eeAccountRecoveryCheckpointSnapshot detachedCopy() {
    return E2eeAccountRecoveryCheckpointSnapshot(
      checkpoint: checkpoint.detachedCopy(),
      envelopeDigest: envelopeDigest,
    );
  }

  void clearSensitiveState() => checkpoint.clearSensitiveState();
}

abstract interface class E2eeAccountRecoveryCheckpointPersistence {
  /// 返回的快照由调用方独占，丢弃前必须清理其敏感状态。
  Future<E2eeAccountRecoveryCheckpointSnapshot?> read();

  Future<E2eeAccountRecoveryCheckpointSnapshot> create(
    E2eeAccountRecoveryCheckpoint checkpoint,
  );

  Future<E2eeAccountRecoveryCheckpointSnapshot> advance({
    required Uint8List expectedEnvelopeDigest,
    required E2eeAccountRecoveryCheckpoint checkpoint,
  });

  Future<bool> delete(E2eeAccountRecoveryCheckpointSnapshot snapshot);
}

typedef E2eeAccountRecoveryAttemptIdFactory = String Function();
typedef E2eeAccountRecoveryTokenFactory =
    CloudSyncAccountRecoveryToken Function();
typedef E2eeAccountRecoveryClock = DateTime Function();

final class E2eeAccountRecoveryCommitCoordinator {
  factory E2eeAccountRecoveryCommitCoordinator({
    required E2eeAccountRecoveryTransport transport,
    required E2eeAccountRecoveryCheckpointPersistence checkpointPersistence,
    E2eeAccountRecoveryClock? now,
  }) {
    return E2eeAccountRecoveryCommitCoordinator._(
      transport,
      checkpointPersistence,
      now ?? _utcNow,
    );
  }

  const E2eeAccountRecoveryCommitCoordinator._(
    this._transport,
    this._checkpointPersistence,
    this._now,
  );

  final E2eeAccountRecoveryTransport _transport;
  final E2eeAccountRecoveryCheckpointPersistence _checkpointPersistence;
  final E2eeAccountRecoveryClock _now;

  Future<E2eeAccountRecoveryCommitReceipt> commitPrepared() async {
    final snapshot = await _checkpointPersistence.read();
    if (snapshot == null) {
      throw StateError('账户恢复 checkpoint 不存在');
    }
    try {
      final checkpoint = snapshot.checkpoint;
      final persistedReceipt = _checkpointCommitReceipt(checkpoint.progress);
      if (persistedReceipt != null) return persistedReceipt;
      final prepared = switch (checkpoint.progress) {
        E2eeAccountRecoveryResumePreparedProgress(:final transition) =>
          transition.commit,
        E2eeAccountRecoveryReplacementPreparedProgress(:final transition) =>
          transition.commit,
        _ => throw StateError('账户恢复 checkpoint 尚未准备成员提交'),
      };
      final authorization = _checkpointAuthorization(checkpoint.progress);
      if (authorization == null ||
          !_now().toUtc().isBefore(authorization.recoveryTokenExpiresAt)) {
        throw const E2eeAccountRecoveryExpired();
      }

      final E2eeAccountRecoveryCommitReceipt receipt;
      switch (prepared) {
        case E2eeAccountRecoveryResumeCommit():
          receipt = await _transport.commitRecoveryResume(
            recoveryToken: checkpoint.recoveryToken,
            request: prepared,
          );
        case E2eeAccountRecoveryReplacementCommit():
          receipt = await _transport.commitRecoveryReplacement(
            recoveryToken: checkpoint.recoveryToken,
            request: prepared,
          );
      }
      final committed = checkpoint.withCommitReceipt(receipt);
      E2eeAccountRecoveryCheckpointSnapshot? advanced;
      try {
        try {
          advanced = await _checkpointPersistence.advance(
            expectedEnvelopeDigest: snapshot.envelopeDigest,
            checkpoint: committed,
          );
          final advancedReceipt = _checkpointCommitReceipt(
            advanced.checkpoint.progress,
          );
          if (advancedReceipt == null) {
            throw StateError('账户恢复成员提交回执未持久化');
          }
          return advancedReceipt;
        } on StateError {
          final raced = await _checkpointPersistence.read();
          try {
            final racedReceipt = raced == null
                ? null
                : _checkpointCommitReceipt(raced.checkpoint.progress);
            if (racedReceipt != null &&
                _sameAccountRecoveryCommitEffect(racedReceipt, receipt)) {
              return racedReceipt;
            }
            rethrow;
          } finally {
            raced?.clearSensitiveState();
          }
        }
      } finally {
        advanced?.clearSensitiveState();
        if (!identical(committed, advanced?.checkpoint)) {
          committed.clearSensitiveState();
        }
      }
    } finally {
      snapshot.clearSensitiveState();
    }
  }
}

final class E2eeAccountRecoveryAuthorizer {
  factory E2eeAccountRecoveryAuthorizer({
    required E2eeAccountRecoveryTransport transport,
    required E2eeAccountRecoveryProofCore proofCore,
    required E2eeAccountRecoveryCheckpointPersistence checkpointPersistence,
    required Uint8List serviceOriginSha256,
    required E2eeAccountRecoveryAttemptIdFactory attemptIdFactory,
    required E2eeAccountRecoveryTokenFactory recoveryTokenFactory,
    E2eeAccountRecoveryClock? now,
  }) {
    return E2eeAccountRecoveryAuthorizer._(
      transport,
      proofCore,
      checkpointPersistence,
      _fixedBytes(serviceOriginSha256, 32, 'serviceOriginSha256'),
      attemptIdFactory,
      recoveryTokenFactory,
      now ?? _utcNow,
    );
  }

  const E2eeAccountRecoveryAuthorizer._(
    this._transport,
    this._proofCore,
    this._checkpointPersistence,
    this._serviceOriginSha256,
    this._attemptIdFactory,
    this._recoveryTokenFactory,
    this._now,
  );

  final E2eeAccountRecoveryTransport _transport;
  final E2eeAccountRecoveryProofCore _proofCore;
  final E2eeAccountRecoveryCheckpointPersistence _checkpointPersistence;
  final Uint8List _serviceOriginSha256;
  final E2eeAccountRecoveryAttemptIdFactory _attemptIdFactory;
  final E2eeAccountRecoveryTokenFactory _recoveryTokenFactory;
  final E2eeAccountRecoveryClock _now;

  Future<E2eeAuthorizedAccountRecovery> authorize({
    required CloudSyncOnboardingToken onboardingToken,
    required String expectedDeviceId,
    required Uint8List recoveryMedia,
    required Uint8List recoveryPassphrase,
  }) async {
    final deviceId = _canonicalUuid(expectedDeviceId, 'expectedDeviceId');
    E2eeAccountRecoveryProof? proof;
    Uint8List? tokenBytes;
    Uint8List? tokenDigest;
    Uint8List? nonceProof;
    Uint8List? trustSignature;
    E2eeAccountRecoveryCheckpointSnapshot? checkpointSnapshot;
    var retainLease = false;
    try {
      checkpointSnapshot = await _checkpointPersistence.read();
      var checkpoint = checkpointSnapshot?.checkpoint;
      final now = _now().toUtc();
      final checkpointDeviceMatches =
          checkpoint == null || checkpoint.expectedDeviceId == deviceId;
      final checkpointExpired =
          checkpoint != null &&
          _preTransitionCheckpointExpired(checkpoint, now);
      if (!checkpointDeviceMatches && !checkpointExpired) {
        throw const FormatException('账户恢复 checkpoint 目标设备不一致');
      }

      var recoveredAuthorizationExpired = false;
      final proofReadyCheckpoint = checkpoint;
      if (proofReadyCheckpoint != null &&
          proofReadyCheckpoint.progress
              is E2eeAccountRecoveryProofReadyProgress) {
        E2eeAccountRecoveryAuthorizedState? authorizedState;
        try {
          authorizedState = await _transport.getAuthorizedState(
            recoveryToken: proofReadyCheckpoint.recoveryToken,
          );
        } on E2eeAccountRecoveryTokenUnavailable {
          authorizedState = null;
        }
        if (authorizedState != null) {
          _validateAuthorizedState(
            proofReadyCheckpoint.challenge,
            authorizedState,
          );
          if (now.isBefore(authorizedState.recoveryTokenExpiresAt)) {
            final proofReadySnapshot = checkpointSnapshot;
            if (proofReadySnapshot == null) {
              throw StateError('账户恢复 checkpoint 快照缺失');
            }
            checkpointSnapshot = await _checkpointPersistence.advance(
              expectedEnvelopeDigest: proofReadySnapshot.envelopeDigest,
              checkpoint: proofReadyCheckpoint.authorized(
                recoveryTokenExpiresAt: authorizedState.recoveryTokenExpiresAt,
                nextAction: authorizedState.nextAction,
              ),
            );
            checkpoint = checkpointSnapshot.checkpoint;
          } else {
            recoveredAuthorizationExpired = true;
          }
        }
      }
      if (checkpoint != null &&
          (recoveredAuthorizationExpired ||
              _preTransitionCheckpointExpired(checkpoint, now))) {
        final expiredSnapshot = checkpointSnapshot;
        if (expiredSnapshot == null) {
          throw StateError('账户恢复 checkpoint 快照缺失');
        }
        if (!await _checkpointPersistence.delete(expiredSnapshot)) {
          throw StateError('账户恢复过期 checkpoint 已被并发推进');
        }
        expiredSnapshot.clearSensitiveState();
        checkpointSnapshot = null;
        checkpoint = null;
      }
      if (checkpoint != null && !checkpointDeviceMatches) {
        throw const FormatException('账户恢复 checkpoint 目标设备不一致');
      }
      if (checkpoint == null) {
        final attemptId = _canonicalUuid(_attemptIdFactory(), 'attemptId');
        final challenge = await _transport.createChallenge(
          onboardingToken: onboardingToken,
          attemptId: attemptId,
        );
        if (challenge.attemptId != attemptId) {
          throw const FormatException('账户恢复 challenge attempt 不一致');
        }
        if (!now.isBefore(challenge.expiresAt)) {
          throw const E2eeAccountRecoveryExpired();
        }
        checkpoint = E2eeAccountRecoveryCheckpoint.challenged(
          expectedDeviceId: deviceId,
          recoveryToken: _recoveryTokenFactory(),
          challenge: challenge,
        );
        checkpointSnapshot = await _checkpointPersistence.create(checkpoint);
        checkpoint = checkpointSnapshot.checkpoint;
      }
      final durableAuthorization = _checkpointAuthorization(
        checkpoint.progress,
      );
      if (durableAuthorization != null) {
        if (!now.isBefore(durableAuthorization.recoveryTokenExpiresAt)) {
          throw const E2eeAccountRecoveryExpired();
        }
      } else if (!now.isBefore(checkpoint.challenge.expiresAt)) {
        throw const E2eeAccountRecoveryExpired();
      }

      final challenge = checkpoint.challenge;
      final attemptId = checkpoint.attemptId;
      final authorization = durableAuthorization != null
          ? E2eeAccountRecoveryBearer.recovery(checkpoint.recoveryToken)
          : E2eeAccountRecoveryBearer.onboarding(onboardingToken);
      final history = await _readFrozenHistory(
        authorization: authorization,
        challenge: challenge,
      );
      final sourceCapsule = _sourceCapsule(challenge, history);
      final recoveryToken = checkpoint.recoveryToken;
      tokenBytes = Uint8List.fromList(utf8.encode(recoveryToken.value));
      tokenDigest = Uint8List.fromList(sha256.convert(tokenBytes).bytes);
      proof = await _proofCore.verifyHistoryAndCreateProof(
        recoveryMedia: Uint8List.fromList(recoveryMedia),
        recoveryPassphrase: recoveryPassphrase,
        serviceOriginSha256: Uint8List.fromList(_serviceOriginSha256),
        membershipHistory: history
            .map((item) => Uint8List.fromList(item.membershipManifest))
            .toList(growable: false),
        currentCapsule: Uint8List.fromList(challenge.recoveryCapsule),
        sourceCapsule: sourceCapsule,
        challengeFrame: Uint8List.fromList(challenge.challengeFrame),
        sealedNonce: Uint8List.fromList(challenge.sealedNonce),
        recoveryTokenDigest: tokenDigest,
        expectedAttemptId: attemptId,
        expectedDeviceId: deviceId,
        expectedRequestDigest: Uint8List.fromList(challenge.requestDigest),
        expectedExpiresAt: challenge.expiresAt,
      );
      if (proof.keyLease.keyEpoch != challenge.keyEpoch) {
        throw const FormatException('账户恢复 Native ARK 代次不一致');
      }
      nonceProof = proof.takeNonceProof();
      trustSignature = proof.takeTrustSignature();
      if (checkpoint.progress is E2eeAccountRecoveryChallengedProgress) {
        final proofReady = checkpoint.withProof(
          nonceProof: nonceProof,
          trustSignature: trustSignature,
        );
        nonceProof = null;
        trustSignature = null;
        final challengedSnapshot = checkpointSnapshot;
        if (challengedSnapshot == null) {
          throw StateError('账户恢复 checkpoint 快照缺失');
        }
        checkpointSnapshot = await _checkpointPersistence.advance(
          expectedEnvelopeDigest: challengedSnapshot.envelopeDigest,
          checkpoint: proofReady,
        );
        checkpoint = checkpointSnapshot.checkpoint;
      } else {
        final expectedNonceProof = checkpoint.copyNonceProof();
        final expectedTrustSignature = checkpoint.copyTrustSignature();
        try {
          if (!_sameBytes(nonceProof, expectedNonceProof) ||
              !_sameBytes(trustSignature, expectedTrustSignature)) {
            throw const FormatException('账户恢复 Native proof 与 checkpoint 不一致');
          }
        } finally {
          _clear(expectedNonceProof);
          _clear(expectedTrustSignature);
          _clear(nonceProof);
          _clear(trustSignature);
          nonceProof = null;
          trustSignature = null;
        }
      }

      final persistedAuthorization = _checkpointAuthorization(
        checkpoint.progress,
      );
      if (persistedAuthorization != null) {
        retainLease = true;
        return E2eeAuthorizedAccountRecovery._(
          attemptId: attemptId,
          recoveryToken: recoveryToken,
          recoveryTokenExpiresAt: persistedAuthorization.recoveryTokenExpiresAt,
          nextAction: persistedAuthorization.nextAction,
          challenge: challenge,
          keyLease: proof.keyLease,
        );
      }

      nonceProof = checkpoint.copyNonceProof();
      trustSignature = checkpoint.copyTrustSignature();
      final receipt = await _transport.authorize(
        authorization: authorization,
        attemptId: attemptId,
        challengeRequestDigest: challenge.requestDigest,
        recoveryToken: recoveryToken,
        nonceProof: nonceProof,
        trustSignature: trustSignature,
      );
      if (receipt.attemptId != attemptId ||
          !_now().toUtc().isBefore(receipt.recoveryTokenExpiresAt)) {
        throw const FormatException('账户恢复授权回执不一致或已过期');
      }
      final authorizedCheckpoint = checkpoint.authorized(
        recoveryTokenExpiresAt: receipt.recoveryTokenExpiresAt,
        nextAction: receipt.nextAction,
      );
      final proofReadySnapshot = checkpointSnapshot;
      if (proofReadySnapshot == null) {
        throw StateError('账户恢复 checkpoint 快照缺失');
      }
      checkpointSnapshot = await _checkpointPersistence.advance(
        expectedEnvelopeDigest: proofReadySnapshot.envelopeDigest,
        checkpoint: authorizedCheckpoint,
      );
      retainLease = true;
      return E2eeAuthorizedAccountRecovery._(
        attemptId: attemptId,
        recoveryToken: recoveryToken,
        recoveryTokenExpiresAt: receipt.recoveryTokenExpiresAt,
        nextAction: receipt.nextAction,
        challenge: challenge,
        keyLease: proof.keyLease,
      );
    } finally {
      recoveryPassphrase.fillRange(0, recoveryPassphrase.length, 0);
      _clear(tokenBytes);
      _clear(tokenDigest);
      _clear(nonceProof);
      _clear(trustSignature);
      checkpointSnapshot?.clearSensitiveState();
      proof?.dispose();
      if (proof != null && !retainLease) {
        await proof.keyLease.close();
      }
    }
  }

  Future<List<CloudSyncAccountSecurityHistoryItem>> _readFrozenHistory({
    required E2eeAccountRecoveryBearer authorization,
    required E2eeAccountRecoveryChallenge challenge,
  }) async {
    final history = <CloudSyncAccountSecurityHistoryItem>[];
    var cursor = 0;
    while (true) {
      final page = await _transport.listFrozenHistory(
        authorization: authorization,
        attemptId: challenge.attemptId,
        challengeRequestDigest: challenge.requestDigest,
        afterGeneration: cursor,
        pageSize: e2eeAccountRecoveryHistoryPageSize,
      );
      _validateFrozenProjection(challenge, page.currentState);
      if (page.afterGeneration != cursor) {
        throw const FormatException('账户恢复历史请求与响应游标不一致');
      }
      history.addAll(page.items);
      if (history.length > e2eeAccountRecoveryMaximumHistoryEntries) {
        throw const FormatException('账户恢复历史超过客户端安全上限');
      }
      cursor = page.nextAfterGeneration;
      if (!page.hasMore) break;
    }
    if (history.length != challenge.securityGeneration ||
        history.isEmpty ||
        history.first.generation != 1 ||
        history.last.generation != challenge.securityGeneration) {
      throw const FormatException('账户恢复冻结历史不完整');
    }
    final head = history.last;
    if (head.keyEpoch != challenge.keyEpoch ||
        !_sameBytes(
          head.membershipManifestDigest.bytes,
          challenge.membershipManifestDigest,
        ) ||
        head.recoveryPublicKeyVersion != challenge.recoveryPublicKeyVersion ||
        !_sameBytes(head.recoveryPublicKey, challenge.recoveryPublicKey) ||
        head.recoveryCapsuleVersion != challenge.recoveryCapsuleVersion ||
        !_sameBytes(head.recoveryCapsule, challenge.recoveryCapsule)) {
      throw const FormatException('账户恢复历史链头与冻结 challenge 不一致');
    }
    return List<CloudSyncAccountSecurityHistoryItem>.unmodifiable(history);
  }

  static void _validateFrozenProjection(
    E2eeAccountRecoveryChallenge challenge,
    CloudSyncAccountSecurityCurrentProjection projection,
  ) {
    final expectedPhase =
        challenge.dataState.phase == E2eeAccountRecoveryDataPhase.ready
        ? CloudSyncDataRekeyPhase.ready
        : CloudSyncDataRekeyPhase.rekeyPending;
    if (projection.generation != challenge.securityGeneration ||
        projection.keyEpoch != challenge.keyEpoch ||
        projection.dataRekeyPhase != expectedPhase ||
        !_sameBytes(
          projection.membershipManifestDigest.bytes,
          challenge.membershipManifestDigest,
        ) ||
        projection.recoveryPublicKeyVersion !=
            challenge.recoveryPublicKeyVersion ||
        !_sameBytes(
          projection.recoveryPublicKey,
          challenge.recoveryPublicKey,
        ) ||
        projection.recoveryCapsuleVersion != challenge.recoveryCapsuleVersion) {
      throw const FormatException('账户恢复历史投影未绑定冻结 challenge');
    }
  }

  static void _validateAuthorizedState(
    E2eeAccountRecoveryChallenge challenge,
    E2eeAccountRecoveryAuthorizedState authorized,
  ) {
    final security = authorized.securityState;
    final expectedPhase =
        challenge.dataState.phase == E2eeAccountRecoveryDataPhase.ready
        ? CloudSyncDataRekeyPhase.ready
        : CloudSyncDataRekeyPhase.rekeyPending;
    final expectedNextAction =
        challenge.dataState.phase == E2eeAccountRecoveryDataPhase.ready
        ? E2eeAccountRecoveryNextAction.recoverReplace
        : E2eeAccountRecoveryNextAction.recoverResume;
    if (authorized.status != E2eeAccountRecoveryRemoteStatus.authorized ||
        authorized.attemptId != challenge.attemptId ||
        authorized.nextAction != expectedNextAction ||
        security.generation != challenge.securityGeneration ||
        security.keyEpoch != challenge.keyEpoch ||
        security.dataRekeyPhase != expectedPhase ||
        !_sameBytes(
          security.membershipManifestDigest.bytes,
          challenge.membershipManifestDigest,
        ) ||
        security.recoveryPublicKeyVersion !=
            challenge.recoveryPublicKeyVersion ||
        !_sameBytes(security.recoveryPublicKey, challenge.recoveryPublicKey) ||
        security.recoveryCapsuleVersion != challenge.recoveryCapsuleVersion ||
        !_sameBytes(security.recoveryCapsule, challenge.recoveryCapsule) ||
        !_sameDataState(authorized.dataState, challenge.dataState)) {
      throw const FormatException('账户恢复远程授权状态与冻结 challenge 不一致');
    }
  }

  static bool _sameDataState(
    E2eeAccountRecoveryDataState left,
    E2eeAccountRecoveryDataState right,
  ) {
    return left.phase == right.phase &&
        left.dataGeneration == right.dataGeneration &&
        left.dataKeyEpoch == right.dataKeyEpoch &&
        left.operationId == right.operationId &&
        left.targetKeyEpoch == right.targetKeyEpoch;
  }

  static Uint8List? _sourceCapsule(
    E2eeAccountRecoveryChallenge challenge,
    List<CloudSyncAccountSecurityHistoryItem> history,
  ) {
    if (challenge.keyEpoch == 1) {
      return null;
    }

    final sourceKeyEpoch = challenge.keyEpoch - 1;
    CloudSyncAccountSecurityHistoryItem? source;
    for (var index = 0; index < history.length - 1; index++) {
      final candidate = history[index];
      final successor = history[index + 1];
      if (candidate.keyEpoch == sourceKeyEpoch &&
          successor.keyEpoch == challenge.keyEpoch) {
        if (source != null) {
          throw const FormatException('账户恢复历史存在多个轮换前驱');
        }
        source = candidate;
      }
    }
    if (source == null) {
      throw const FormatException('账户恢复历史缺少轮换前驱 capsule');
    }
    if (source.recoveryPublicKeyVersion != challenge.recoveryPublicKeyVersion ||
        !_sameBytes(source.recoveryPublicKey, challenge.recoveryPublicKey) ||
        source.recoveryCapsuleVersion == 0x7fffffff ||
        source.recoveryCapsuleVersion + 1 != challenge.recoveryCapsuleVersion) {
      throw const FormatException('账户恢复轮换前驱 capsule 绑定无效');
    }

    // 外层字段只能用于无歧义选路，capsule 摘要必须由 Native 对签名历史验证。
    return Uint8List.fromList(source.recoveryCapsule);
  }
}

bool _sameAccountRecoveryCommitEffect(
  E2eeAccountRecoveryCommitReceipt left,
  E2eeAccountRecoveryCommitReceipt right,
) {
  return left.kind == right.kind &&
      left.attemptId == right.attemptId &&
      left.membershipOperationId == right.membershipOperationId &&
      left.rekeyOperationId == right.rekeyOperationId &&
      left.generation == right.generation &&
      left.keyEpoch == right.keyEpoch &&
      left.nextAction == right.nextAction;
}

bool _remoteStatusAllowsAction(
  E2eeAccountRecoveryRemoteStatus status,
  E2eeAccountRecoveryDataPhase phase,
  E2eeAccountRecoveryNextAction action,
) {
  return switch ((status, phase)) {
    (
      E2eeAccountRecoveryRemoteStatus.authorized,
      E2eeAccountRecoveryDataPhase.ready,
    ) =>
      action == E2eeAccountRecoveryNextAction.recoverReplace,
    (
      E2eeAccountRecoveryRemoteStatus.authorized,
      E2eeAccountRecoveryDataPhase.rekeyPending,
    ) =>
      action == E2eeAccountRecoveryNextAction.recoverResume,
    (
      E2eeAccountRecoveryRemoteStatus.resumeCommitted,
      E2eeAccountRecoveryDataPhase.ready,
    ) =>
      action == E2eeAccountRecoveryNextAction.createReplacementChallenge,
    (
      E2eeAccountRecoveryRemoteStatus.resumeCommitted,
      E2eeAccountRecoveryDataPhase.rekeyPending,
    ) =>
      action == E2eeAccountRecoveryNextAction.finishFirstDataRekey,
    (
      E2eeAccountRecoveryRemoteStatus.replacementCommitted,
      E2eeAccountRecoveryDataPhase.ready,
    ) =>
      false,
    (
      E2eeAccountRecoveryRemoteStatus.replacementCommitted,
      E2eeAccountRecoveryDataPhase.rekeyPending,
    ) =>
      action == E2eeAccountRecoveryNextAction.finishSecondDataRekey,
  };
}

final class E2eeAccountRecoveryExpired implements Exception {
  const E2eeAccountRecoveryExpired();

  @override
  String toString() => 'E2eeAccountRecoveryExpired';
}

DateTime _utcNow() => DateTime.now().toUtc();

String _canonicalUuid(String value, String field) {
  if (!_canonicalUuidV4Pattern.hasMatch(value)) {
    throw FormatException('$field 不是规范 UUID v4');
  }
  return value;
}

int _positiveInt32(int value, String field) {
  if (value <= 0 || value > 0x7fffffff) {
    throw FormatException('$field 不在正 int32 范围内');
  }
  return value;
}

int _positiveUint32(int value, String field) {
  if (value <= 0 || value > 0xffffffff) {
    throw FormatException('$field 不在正 uint32 范围内');
  }
  return value;
}

DateTime _canonicalUtcSecondTimestamp(DateTime value, String field) {
  final utc = value.toUtc();
  final seconds = utc.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
  if (seconds <= 0) {
    throw FormatException('$field 时间戳无效');
  }
  return DateTime.fromMillisecondsSinceEpoch(
    seconds * Duration.millisecondsPerSecond,
    isUtc: true,
  );
}

Uint8List _fixedBytes(Uint8List value, int length, String field) {
  if (value.length != length) {
    throw FormatException('$field 长度必须为 $length 字节');
  }
  return Uint8List.fromList(value).asUnmodifiableView();
}

Uint8List _fixedMutableBytes(Uint8List value, int length, String field) {
  if (value.length != length) {
    throw FormatException('$field 长度必须为 $length 字节');
  }
  final copy = Uint8List.fromList(value);
  // Native 绑定层可能返回不可变视图（asUnmodifiableView）；清零只对
  // 可写缓冲区执行，不可变视图的生命周期由创建方（绑定层）负责。
  try {
    value.fillRange(0, value.length, 0);
  } on UnsupportedError {
    // 不可变视图：跳过原地清零，拷贝已隔离敏感内容。
  }
  return copy;
}

Uint8List _fixedMutableCopy(Uint8List value, int length, String field) {
  if (value.length != length) {
    throw FormatException('$field 长度必须为 $length 字节');
  }
  return Uint8List.fromList(value);
}

Uint8List _rangedBytes(
  Uint8List value, {
  required int minimum,
  required int maximum,
  required String field,
}) {
  if (value.length < minimum || value.length > maximum) {
    throw FormatException('$field 长度不在协议范围内');
  }
  return Uint8List.fromList(value).asUnmodifiableView();
}

bool _sameBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

void _clear(Uint8List? value) {
  if (value == null) return;
  try {
    value.fillRange(0, value.length, 0);
  } on UnsupportedError {
    // 不可变视图（native 绑定输出）：由创建方管理生命周期。
  }
}
