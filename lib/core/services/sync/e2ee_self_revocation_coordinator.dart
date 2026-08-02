import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:uuid/uuid.dart';

import 'cloud_sync_types.dart';
import 'e2ee_account_trust_manifest.dart';
import 'e2ee_data_rekey_wire.dart';
import 'e2ee_self_revocation_rotation_binding.dart';

const _selfRevocationIntentDigestBytes = 32;

enum E2eeSelfRevocationVerificationFailure {
  currentSecurityHeadMismatch,
  requestingDeviceNotTrusted,
  intentExpired,
  intentInvalid,
  receiptLineageInvalid,
  completionInvalid,
}

final class E2eeSelfRevocationVerificationException implements Exception {
  const E2eeSelfRevocationVerificationException(
    this.failure,
    this.message, {
    this.cause,
  });

  final E2eeSelfRevocationVerificationFailure failure;
  final String message;
  final Object? cause;

  @override
  String toString() => 'E2eeSelfRevocationVerificationException: $message';
}

abstract interface class E2eeSelfRevocationIntentVerifier {
  // 不接收服务端给出的 intentDigest，避免把待验证摘要误当成验签输入。
  Future<Uint8List> verifyAndDigest({
    required String userId,
    required String deviceId,
    required String mutationId,
    required String operationId,
    required int expectedGeneration,
    required int expectedKeyEpoch,
    required Uint8List expectedMembershipManifestDigest,
    required DateTime expiresAt,
    required Uint8List signature,
    required Uint8List signingPublicKey,
  });
}

final class E2eeNativeSelfRevocationIntentVerifier
    implements E2eeSelfRevocationIntentVerifier {
  const E2eeNativeSelfRevocationIntentVerifier()
    : _secureCore = const KelivoSecureCore();

  const E2eeNativeSelfRevocationIntentVerifier.withSecureCore(this._secureCore);

  final KelivoSecureCore _secureCore;

  @override
  Future<Uint8List> verifyAndDigest({
    required String userId,
    required String deviceId,
    required String mutationId,
    required String operationId,
    required int expectedGeneration,
    required int expectedKeyEpoch,
    required Uint8List expectedMembershipManifestDigest,
    required DateTime expiresAt,
    required Uint8List signature,
    required Uint8List signingPublicKey,
  }) {
    if (!expiresAt.isUtc ||
        expiresAt.microsecond != 0 ||
        expiresAt.millisecondsSinceEpoch < 0) {
      throw ArgumentError.value(expiresAt, 'expiresAt', '必须为非负整毫秒 UTC 时间');
    }
    return _secureCore.verifySelfRevocationIntent(
      signingPublicKey: signingPublicKey,
      userId: _canonicalSelfRevocationUuidBytes(userId, 'userId'),
      deviceId: _canonicalSelfRevocationUuidBytes(deviceId, 'deviceId'),
      mutationId: _canonicalSelfRevocationUuidBytes(mutationId, 'mutationId'),
      operationId: _canonicalSelfRevocationUuidBytes(
        operationId,
        'operationId',
      ),
      expectedGeneration: expectedGeneration,
      expectedKeyEpoch: expectedKeyEpoch,
      expectedMembershipManifestDigest: expectedMembershipManifestDigest,
      expiresAtMs: expiresAt.millisecondsSinceEpoch,
      signature: signature,
    );
  }
}

final class E2eeVerifiedSelfRevocationIntent {
  E2eeVerifiedSelfRevocationIntent._({
    required this.userId,
    required this.deviceId,
    required this.mutationId,
    required this.operationId,
    required this.expectedGeneration,
    required this.expectedKeyEpoch,
    required Uint8List expectedMembershipManifestDigest,
    required Uint8List intentDigest,
    required this.expiresAt,
  }) : expectedMembershipManifestDigest = Uint8List.fromList(
         expectedMembershipManifestDigest,
       ).asUnmodifiableView(),
       intentDigest = Uint8List.fromList(intentDigest).asUnmodifiableView();

  final String userId;
  final String deviceId;
  final String mutationId;
  final String operationId;
  final int expectedGeneration;
  final int expectedKeyEpoch;
  final Uint8List expectedMembershipManifestDigest;
  final Uint8List intentDigest;
  final DateTime expiresAt;

  E2eeSelfRevocationRotationBinding toRotationBinding() {
    return E2eeSelfRevocationRotationBinding(
      deviceId: deviceId,
      mutationId: mutationId,
      operationId: operationId,
      expectedGeneration: expectedGeneration,
      expectedKeyEpoch: expectedKeyEpoch,
      expectedMembershipManifestDigest: expectedMembershipManifestDigest,
      intentDigest: intentDigest,
    );
  }
}

final class E2eeVerifiedSelfRevocationReceipt {
  E2eeVerifiedSelfRevocationReceipt._({
    required this.intent,
    required List<E2eeVerifiedMembership> securityStates,
    required this.completion,
  }) : securityStates = List<E2eeVerifiedMembership>.unmodifiable(
         securityStates,
       );

  final E2eeVerifiedSelfRevocationIntent intent;
  final List<E2eeVerifiedMembership> securityStates;
  final E2eeVerifiedSelfRevocationCompletion completion;

  E2eeVerifiedMembership get finalSecurityHead => securityStates.last;
}

final class E2eeVerifiedSelfRevocationCompletion {
  E2eeVerifiedSelfRevocationCompletion._(
    CloudSyncDataRekeyCompletion completion,
  ) : operationId = completion.operationId,
      issuerDeviceId = completion.issuerDeviceId,
      sourceDataGeneration = completion.sourceDataGeneration,
      targetDataGeneration = completion.targetDataGeneration,
      sourceKeyEpoch = completion.sourceKeyEpoch,
      targetKeyEpoch = completion.targetKeyEpoch,
      membershipGeneration = completion.membershipGeneration,
      membershipManifestDigest = Uint8List.fromList(
        completion.membershipManifestDigest,
      ).asUnmodifiableView(),
      proofDigest = Uint8List.fromList(
        completion.proofDigest,
      ).asUnmodifiableView();

  final String operationId;
  final String issuerDeviceId;
  final int sourceDataGeneration;
  final int targetDataGeneration;
  final int sourceKeyEpoch;
  final int targetKeyEpoch;
  final int membershipGeneration;
  final Uint8List membershipManifestDigest;
  final Uint8List proofDigest;
}

final class E2eeTrustedSelfRevocationCoordinator {
  factory E2eeTrustedSelfRevocationCoordinator({
    required E2eeSelfRevocationIntentVerifier intentVerifier,
    E2eeAccountTrustManifestModule manifestModule =
        const E2eeAccountTrustManifestModule(),
    KelivoSecureCore secureCore = const KelivoSecureCore(),
  }) {
    return E2eeTrustedSelfRevocationCoordinator._(
      intentVerifier,
      manifestModule,
      secureCore,
    );
  }

  const E2eeTrustedSelfRevocationCoordinator._(
    this._intentVerifier,
    this._manifestModule,
    this._secureCore,
  );

  final E2eeSelfRevocationIntentVerifier _intentVerifier;
  final E2eeAccountTrustManifestModule _manifestModule;
  final KelivoSecureCore _secureCore;

  Future<List<E2eeVerifiedSelfRevocationIntent>> verifyPendingRequestList({
    required E2eeVerifiedMembership trustedCurrentHead,
    required CloudSyncUntrustedSelfRevocationRequestList untrustedList,
    required DateTime now,
  }) async {
    final verified = <E2eeVerifiedSelfRevocationIntent>[];
    final currentTime = now.toUtc();
    for (final request in untrustedList.requests) {
      verified.add(
        await _verifyIntent(
          trustedCurrentHead: trustedCurrentHead,
          deviceId: request.deviceId,
          mutationId: request.mutationId,
          operationId: request.operationId,
          expectedGeneration: request.expectedGeneration,
          expectedKeyEpoch: request.expectedKeyEpoch,
          expectedMembershipManifestDigest:
              request.expectedMembershipManifestDigest.bytes,
          intentDigest: request.intentDigest,
          intentSignature: request.intentSignature,
          expiresAt: request.expiresAt,
          rejectAtOrBefore: currentTime,
        ),
      );
    }
    return List<E2eeVerifiedSelfRevocationIntent>.unmodifiable(verified);
  }

  Future<E2eeVerifiedSelfRevocationReceipt> verifyConfirmedReceipt({
    required E2eeVerifiedMembership trustedCurrentHead,
    required CloudSyncUntrustedSelfRevocationConfirmed untrustedConfirmed,
  }) async {
    final request = untrustedConfirmed.request;
    final verifiedIntent = await _verifyIntent(
      trustedCurrentHead: trustedCurrentHead,
      deviceId: request.deviceId,
      mutationId: request.mutationId,
      operationId: request.operationId,
      expectedGeneration: request.expectedGeneration,
      expectedKeyEpoch: request.expectedKeyEpoch,
      expectedMembershipManifestDigest:
          request.expectedMembershipManifestDigest.bytes,
      intentDigest: request.intentDigest,
      intentSignature: request.intentSignature,
      expiresAt: request.expiresAt,
    );
    final untrustedReceipt = untrustedConfirmed.untrustedReceipt;
    final verifiedStates = <E2eeVerifiedMembership>[];
    var previous = trustedCurrentHead;
    try {
      for (
        var index = 0;
        index < untrustedReceipt.securityStates.length;
        index++
      ) {
        final state = untrustedReceipt.securityStates[index];
        final verified = await _manifestModule.verifyHistoryBatch(
          previous: previous,
          entries: <E2eeMembershipHistoryEntry>[
            E2eeMembershipHistoryEntry(
              manifest: state.membershipManifest,
              manifestDigest: state.membershipManifestDigest.bytes,
            ),
          ],
        );
        _requireSecurityStateProjection(state, verified);
        if (index == 0) {
          _requireRotationBinding(
            previous: previous,
            verified: verified,
            intent: verifiedIntent,
          );
        } else {
          _requireRecoveryResumeBinding(previous: previous, verified: verified);
        }
        verifiedStates.add(verified);
        previous = verified;
      }
      if (verifiedStates.length > 1) {
        verifiedStates.last.requireDataRekeyLineage(
          rekeyOperationId: verifiedIntent.operationId,
        );
      }
    } on E2eeSelfRevocationVerificationException {
      rethrow;
    } catch (error) {
      throw E2eeSelfRevocationVerificationException(
        E2eeSelfRevocationVerificationFailure.receiptLineageInvalid,
        '自撤销安全状态签名链验证失败',
        cause: error,
      );
    }

    final finalHead = verifiedStates.last;
    final completion = untrustedReceipt.completion;
    final finalIssuer = _findMember(finalHead, completion.issuerDeviceId);
    if (completion.operationId != verifiedIntent.operationId ||
        completion.issuerDeviceId == verifiedIntent.deviceId ||
        completion.issuerDeviceId != finalHead.issuerDeviceId ||
        finalIssuer == null ||
        completion.sourceKeyEpoch != verifiedIntent.expectedKeyEpoch ||
        completion.targetKeyEpoch != finalHead.keyEpoch ||
        completion.membershipGeneration != finalHead.securityGeneration ||
        !_sameBytes(completion.membershipManifestDigest, finalHead.digest)) {
      throw const E2eeSelfRevocationVerificationException(
        E2eeSelfRevocationVerificationFailure.completionInvalid,
        '自撤销完成证明未绑定最终可信安全头',
      );
    }
    try {
      await _verifyCompletionProof(
        userId: verifiedIntent.userId,
        signingPublicKey: finalIssuer.signingPublicKey,
        completion: completion,
      );
    } catch (error) {
      throw E2eeSelfRevocationVerificationException(
        E2eeSelfRevocationVerificationFailure.completionInvalid,
        '自撤销完成证明摘要或签名无效',
        cause: error,
      );
    }
    return E2eeVerifiedSelfRevocationReceipt._(
      intent: verifiedIntent,
      securityStates: verifiedStates,
      completion: E2eeVerifiedSelfRevocationCompletion._(completion),
    );
  }

  Future<E2eeVerifiedSelfRevocationIntent> _verifyIntent({
    required E2eeVerifiedMembership trustedCurrentHead,
    required String deviceId,
    required String mutationId,
    required String operationId,
    required int expectedGeneration,
    required int expectedKeyEpoch,
    required Uint8List expectedMembershipManifestDigest,
    required Uint8List intentDigest,
    required Uint8List intentSignature,
    required DateTime expiresAt,
    DateTime? rejectAtOrBefore,
  }) async {
    if (expectedGeneration != trustedCurrentHead.securityGeneration ||
        expectedKeyEpoch != trustedCurrentHead.keyEpoch ||
        !_sameBytes(
          expectedMembershipManifestDigest,
          trustedCurrentHead.digest,
        )) {
      throw const E2eeSelfRevocationVerificationException(
        E2eeSelfRevocationVerificationFailure.currentSecurityHeadMismatch,
        '自撤销意图未绑定本地可信安全头',
      );
    }
    final requestingDevice = _findMember(trustedCurrentHead, deviceId);
    if (requestingDevice == null) {
      throw const E2eeSelfRevocationVerificationException(
        E2eeSelfRevocationVerificationFailure.requestingDeviceNotTrusted,
        '自撤销请求设备不在本地可信成员清单中',
      );
    }
    if (rejectAtOrBefore != null &&
        !rejectAtOrBefore.toUtc().isBefore(expiresAt)) {
      throw const E2eeSelfRevocationVerificationException(
        E2eeSelfRevocationVerificationFailure.intentExpired,
        '自撤销意图已按本地时间过期',
      );
    }
    late final Uint8List computedDigest;
    try {
      computedDigest = await _intentVerifier.verifyAndDigest(
        userId: trustedCurrentHead.userId,
        deviceId: deviceId,
        mutationId: mutationId,
        operationId: operationId,
        expectedGeneration: expectedGeneration,
        expectedKeyEpoch: expectedKeyEpoch,
        expectedMembershipManifestDigest: Uint8List.fromList(
          expectedMembershipManifestDigest,
        ),
        expiresAt: expiresAt,
        signature: Uint8List.fromList(intentSignature),
        signingPublicKey: Uint8List.fromList(requestingDevice.signingPublicKey),
      );
    } catch (error) {
      throw E2eeSelfRevocationVerificationException(
        E2eeSelfRevocationVerificationFailure.intentInvalid,
        '自撤销意图签名验证失败',
        cause: error,
      );
    }
    if (computedDigest.length != _selfRevocationIntentDigestBytes ||
        !_sameBytes(computedDigest, intentDigest)) {
      throw const E2eeSelfRevocationVerificationException(
        E2eeSelfRevocationVerificationFailure.intentInvalid,
        '自撤销意图摘要与签名字段不一致',
      );
    }
    return E2eeVerifiedSelfRevocationIntent._(
      userId: trustedCurrentHead.userId,
      deviceId: deviceId,
      mutationId: mutationId,
      operationId: operationId,
      expectedGeneration: expectedGeneration,
      expectedKeyEpoch: expectedKeyEpoch,
      expectedMembershipManifestDigest: expectedMembershipManifestDigest,
      intentDigest: computedDigest,
      expiresAt: expiresAt,
    );
  }

  Future<void> _verifyCompletionProof({
    required String userId,
    required Uint8List signingPublicKey,
    required CloudSyncDataRekeyCompletion completion,
  }) async {
    final sourceAttachmentCursor = completion.sourceAttachmentCursorEnd;
    final expectedFrame = buildE2eeDataRekeyCompletionFrame(
      E2eeDataRekeyCompletionFields(
        operationId: completion.operationId,
        userId: userId,
        issuerDeviceId: completion.issuerDeviceId,
        sourceDataGeneration: completion.sourceDataGeneration,
        targetDataGeneration: completion.targetDataGeneration,
        sourceKeyEpoch: completion.sourceKeyEpoch,
        targetKeyEpoch: completion.targetKeyEpoch,
        sourceSnapshotRoot: completion.sourceSnapshotRoot,
        sourceRecordCount: completion.sourceRecordCount,
        sourceAttachmentCount: completion.sourceAttachmentCount,
        sourceMaximumChangeSeq: completion.sourceMaximumChangeSeq,
        sourceRecordCursorEnd: completion.sourceRecordCursorEnd,
        sourceAttachmentCursorEnd: sourceAttachmentCursor == null
            ? null
            : E2eeDataRekeyAttachmentCursor(
                attachmentId: sourceAttachmentCursor.attachmentId,
                uploadId: sourceAttachmentCursor.uploadId,
              ),
        membershipGeneration: completion.membershipGeneration,
        membershipManifestDigest: completion.membershipManifestDigest,
        stagedRecordCount: completion.stagedRecordCount,
        stagedAttachmentCount: completion.stagedAttachmentCount,
        stagedCiphertextSetDigest: completion.stagedCiphertextSetDigest,
      ),
    );
    if (!_sameBytes(expectedFrame, completion.proofFrame)) {
      throw const FormatException('data-rekey completion proofFrame 无效');
    }
    final expectedDigest = digestE2eeDataRekeyCompletionProof(
      proofFrame: expectedFrame,
      signature: completion.signature,
    );
    if (!_sameBytes(expectedDigest, completion.proofDigest)) {
      throw const FormatException('data-rekey completion proofDigest 无效');
    }
    await _secureCore.verifyDataRekeyCompletionProof(
      signingPublicKey: signingPublicKey,
      proofFrame: expectedFrame,
      signature: KelivoDataRekeyCompletionProofSignature(completion.signature),
    );
  }
}

void _requireSecurityStateProjection(
  CloudSyncAccountSecurityHistoryItem state,
  E2eeVerifiedMembership verified,
) {
  final capsuleDigest = Uint8List.fromList(
    sha256.convert(state.recoveryCapsule).bytes,
  );
  if (state.generation != verified.securityGeneration ||
      state.keyEpoch != verified.keyEpoch ||
      state.operationId != verified.operationId ||
      !_sameBytes(state.membershipManifest, verified.manifest) ||
      !_sameBytes(state.membershipManifestDigest.bytes, verified.digest) ||
      state.recoveryPublicKeyVersion != verified.recoveryPublicKeyVersion ||
      !_sameBytes(state.recoveryPublicKey, verified.recoveryPublicKey) ||
      state.recoveryCapsuleVersion != verified.recoveryCapsuleVersion ||
      !_sameBytes(capsuleDigest, verified.recoveryCapsuleDigest)) {
    throw const E2eeSelfRevocationVerificationException(
      E2eeSelfRevocationVerificationFailure.receiptLineageInvalid,
      '自撤销安全状态外层投影与已验签成员清单不一致',
    );
  }
}

void _requireRotationBinding({
  required E2eeVerifiedMembership previous,
  required E2eeVerifiedMembership verified,
  required E2eeVerifiedSelfRevocationIntent intent,
}) {
  if (verified.securityGeneration != previous.securityGeneration + 1 ||
      verified.keyEpoch != previous.keyEpoch + 1 ||
      verified.operationKind != E2eeMembershipOperationKind.revokeRotate ||
      verified.operationId != intent.operationId ||
      verified.subjectDeviceId != intent.deviceId ||
      verified.issuerDeviceId == intent.deviceId ||
      !_sameBytes(verified.previousDigest, previous.digest) ||
      !_sameBytes(verified.operationAuthorizationDigest, intent.intentDigest) ||
      _findMember(verified, intent.deviceId) != null ||
      _findMember(verified, verified.issuerDeviceId) == null) {
    throw const E2eeSelfRevocationVerificationException(
      E2eeSelfRevocationVerificationFailure.receiptLineageInvalid,
      '自撤销首个安全状态未绑定撤销轮换意图',
    );
  }
}

void _requireRecoveryResumeBinding({
  required E2eeVerifiedMembership previous,
  required E2eeVerifiedMembership verified,
}) {
  if (verified.securityGeneration != previous.securityGeneration + 1 ||
      verified.keyEpoch != previous.keyEpoch ||
      verified.operationKind != E2eeMembershipOperationKind.recoverResume ||
      verified.issuerDeviceId != verified.subjectDeviceId ||
      !_sameBytes(verified.previousDigest, previous.digest) ||
      !_allZero(verified.operationAuthorizationDigest) ||
      _findMember(previous, verified.subjectDeviceId) != null ||
      _findMember(verified, verified.subjectDeviceId) == null) {
    throw const E2eeSelfRevocationVerificationException(
      E2eeSelfRevocationVerificationFailure.receiptLineageInvalid,
      '自撤销恢复接续安全状态不连续',
    );
  }
}

E2eeVerifiedMembershipDevice? _findMember(
  E2eeVerifiedMembership membership,
  String deviceId,
) {
  for (final member in membership.members) {
    if (member.deviceId == deviceId) return member;
  }
  return null;
}

bool _allZero(Uint8List value) {
  var aggregate = 0;
  for (final byte in value) {
    aggregate |= byte;
  }
  return aggregate == 0;
}

bool _sameBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

Uint8List _canonicalSelfRevocationUuidBytes(String value, String field) {
  late final Uint8List bytes;
  try {
    bytes = Uint8List.fromList(Uuid.parseAsByteList(value));
  } on FormatException {
    throw ArgumentError.value(value, field, '必须为规范小写 UUIDv4');
  }
  if (bytes.length != 16 ||
      bytes[6] & 0xf0 != 0x40 ||
      bytes[8] & 0xc0 != 0x80 ||
      Uuid.unparse(bytes) != value) {
    throw ArgumentError.value(value, field, '必须为规范小写 UUIDv4');
  }
  return bytes;
}
