import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'cloud_sync_types.dart';

const e2eeAccountRecoveryProtocolVersion = 1;
const e2eeAccountRecoveryChallengeFrameBytes = 316;
const e2eeAccountRecoverySealedNonceBytes = 100;
const e2eeAccountRecoveryNonceProofBytes = 32;
const e2eeAccountRecoveryTrustSignatureBytes = 64;
const e2eeAccountRecoveryMaximumHistoryEntries = 4096;
const e2eeAccountRecoveryHistoryPageSize = 100;

final _canonicalUuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final _recoveryTokenPattern = RegExp(r'^kelivo_recovery_[A-Za-z0-9_-]{43}$');

enum E2eeAccountRecoveryDataPhase { ready, rekeyPending }

enum E2eeAccountRecoveryAuthorizationResult { authorized, replayed }

enum E2eeAccountRecoveryNextAction { recoverResume, recoverReplace }

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

final class E2eeAccountRecoveryAuthorizationReceipt {
  E2eeAccountRecoveryAuthorizationReceipt({
    required String attemptId,
    required this.result,
    required this.nextAction,
    required DateTime recoveryTokenExpiresAt,
  }) : attemptId = _canonicalUuid(attemptId, 'attemptId'),
       recoveryTokenExpiresAt = recoveryTokenExpiresAt.toUtc();

  final String attemptId;
  final E2eeAccountRecoveryAuthorizationResult result;
  final E2eeAccountRecoveryNextAction nextAction;
  final DateTime recoveryTokenExpiresAt;
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

enum E2eeAccountRecoveryStage { challenged, proofReady, authorized }

final class E2eeAccountRecoveryCheckpoint {
  factory E2eeAccountRecoveryCheckpoint.challenged({
    required String expectedDeviceId,
    required CloudSyncAccountRecoveryToken recoveryToken,
    required E2eeAccountRecoveryChallenge challenge,
  }) {
    return E2eeAccountRecoveryCheckpoint._(
      E2eeAccountRecoveryStage.challenged,
      _canonicalUuid(expectedDeviceId, 'expectedDeviceId'),
      recoveryToken,
      challenge,
      null,
      null,
      null,
      null,
    );
  }

  E2eeAccountRecoveryCheckpoint._(
    this.stage,
    this.expectedDeviceId,
    this.recoveryToken,
    this.challenge,
    this._nonceProof,
    this._trustSignature,
    this.recoveryTokenExpiresAt,
    this.nextAction,
  );

  final E2eeAccountRecoveryStage stage;
  final String expectedDeviceId;
  final CloudSyncAccountRecoveryToken recoveryToken;
  final E2eeAccountRecoveryChallenge challenge;
  final Uint8List? _nonceProof;
  final Uint8List? _trustSignature;
  final DateTime? recoveryTokenExpiresAt;
  final E2eeAccountRecoveryNextAction? nextAction;

  String get attemptId => challenge.attemptId;

  E2eeAccountRecoveryCheckpoint withProof({
    required Uint8List nonceProof,
    required Uint8List trustSignature,
  }) {
    if (stage != E2eeAccountRecoveryStage.challenged) {
      nonceProof.fillRange(0, nonceProof.length, 0);
      trustSignature.fillRange(0, trustSignature.length, 0);
      throw StateError('账户恢复 checkpoint 不处于 challenge 阶段');
    }
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
      return E2eeAccountRecoveryCheckpoint._(
        E2eeAccountRecoveryStage.proofReady,
        expectedDeviceId,
        recoveryToken,
        challenge,
        ownedNonceProof.asUnmodifiableView(),
        ownedTrustSignature.asUnmodifiableView(),
        null,
        null,
      );
    } catch (_) {
      _clear(ownedNonceProof);
      _clear(ownedTrustSignature);
      rethrow;
    }
  }

  E2eeAccountRecoveryCheckpoint authorized({
    required DateTime recoveryTokenExpiresAt,
    required E2eeAccountRecoveryNextAction nextAction,
  }) {
    if (stage != E2eeAccountRecoveryStage.proofReady) {
      throw StateError('账户恢复 checkpoint 尚未生成 proof');
    }
    final expiresAt = recoveryTokenExpiresAt.toUtc();
    if (expiresAt.millisecondsSinceEpoch <= 0) {
      throw const FormatException('账户恢复 token 过期时间无效');
    }
    return E2eeAccountRecoveryCheckpoint._(
      E2eeAccountRecoveryStage.authorized,
      expectedDeviceId,
      recoveryToken,
      challenge,
      _nonceProof,
      _trustSignature,
      expiresAt,
      nextAction,
    );
  }

  Uint8List copyNonceProof() {
    final value = _nonceProof;
    if (stage == E2eeAccountRecoveryStage.challenged || value == null) {
      throw StateError('账户恢复 checkpoint 不含 nonce proof');
    }
    return Uint8List.fromList(value);
  }

  Uint8List copyTrustSignature() {
    final value = _trustSignature;
    if (stage == E2eeAccountRecoveryStage.challenged || value == null) {
      throw StateError('账户恢复 checkpoint 不含信任签名');
    }
    return Uint8List.fromList(value);
  }
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
}

abstract interface class E2eeAccountRecoveryCheckpointPersistence {
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
    var retainLease = false;
    try {
      var checkpointSnapshot = await _checkpointPersistence.read();
      var checkpoint = checkpointSnapshot?.checkpoint;
      if (checkpoint != null && checkpoint.expectedDeviceId != deviceId) {
        throw const FormatException('账户恢复 checkpoint 目标设备不一致');
      }

      final now = _now().toUtc();
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
      } else if (checkpoint.stage == E2eeAccountRecoveryStage.authorized) {
        final expiresAt = checkpoint.recoveryTokenExpiresAt;
        if (expiresAt == null || !now.isBefore(expiresAt)) {
          throw const E2eeAccountRecoveryExpired();
        }
      } else if (!now.isBefore(checkpoint.challenge.expiresAt)) {
        throw const E2eeAccountRecoveryExpired();
      }

      final challenge = checkpoint.challenge;
      final attemptId = checkpoint.attemptId;
      final authorization =
          checkpoint.stage == E2eeAccountRecoveryStage.authorized
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
      if (checkpoint.stage == E2eeAccountRecoveryStage.challenged) {
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

      if (checkpoint.stage == E2eeAccountRecoveryStage.authorized) {
        retainLease = true;
        return E2eeAuthorizedAccountRecovery._(
          attemptId: attemptId,
          recoveryToken: recoveryToken,
          recoveryTokenExpiresAt: checkpoint.recoveryTokenExpiresAt!,
          nextAction: checkpoint.nextAction!,
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

  static Uint8List? _sourceCapsule(
    E2eeAccountRecoveryChallenge challenge,
    List<CloudSyncAccountSecurityHistoryItem> history,
  ) {
    if (challenge.dataState.phase == E2eeAccountRecoveryDataPhase.ready) {
      return null;
    }
    for (var index = history.length - 1; index >= 0; index--) {
      final item = history[index];
      if (item.keyEpoch == challenge.dataState.dataKeyEpoch) {
        return Uint8List.fromList(item.recoveryCapsule);
      }
    }
    throw const FormatException('账户恢复历史缺少数据源代 capsule');
  }
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

Uint8List _fixedBytes(Uint8List value, int length, String field) {
  if (value.length != length) {
    throw FormatException('$field 长度必须为 $length 字节');
  }
  return Uint8List.fromList(value).asUnmodifiableView();
}

Uint8List _fixedMutableBytes(Uint8List value, int length, String field) {
  if (value.length != length) {
    value.fillRange(0, value.length, 0);
    throw FormatException('$field 长度必须为 $length 字节');
  }
  final copy = Uint8List.fromList(value);
  value.fillRange(0, value.length, 0);
  return copy;
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
  value?.fillRange(0, value.length, 0);
}
