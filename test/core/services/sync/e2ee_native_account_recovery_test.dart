import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_recovery.dart';
import 'package:Kelivo/core/services/sync/e2ee_first_device_registration_commit_coordinator.dart';
import 'package:Kelivo/core/services/sync/e2ee_native_account_recovery.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';

void main() {
  const secureCore = KelivoSecureCore();

  test('Native 账户恢复适配器拒绝非规范 UUID 并清零恢复口令', () async {
    final identity = await secureCore.generateDeviceIdentity();
    final adapter = E2eeNativeAccountRecoveryProofCore(
      secureCore: secureCore,
      deviceIdentity: identity,
      deviceKeyVersion: 1,
      targetAuthGeneration: 1,
    );
    final passphrase = Uint8List.fromList(
      utf8.encode('account-recovery-passphrase'),
    );
    try {
      await expectLater(
        adapter.verifyHistoryAndCreateProof(
          recoveryMedia: Uint8List(e2eeEncryptedRecoveryMediaBytes),
          recoveryPassphrase: passphrase,
          serviceOriginSha256: Uint8List(32),
          membershipHistory: <Uint8List>[
            Uint8List(cloudSyncMembershipManifestMinimumBytes),
          ],
          currentCapsule: Uint8List(156),
          sourceCapsule: null,
          challengeFrame: Uint8List(316),
          sealedNonce: Uint8List(100),
          recoveryTokenDigest: Uint8List(32),
          expectedAttemptId: 'not-a-uuid',
          expectedDeviceId: '22222222-2222-4222-8222-222222222222',
          expectedRequestDigest: Uint8List(32),
          expectedExpiresAt: DateTime.utc(2026, 8, 1, 2),
        ),
        throwsFormatException,
      );
      expect(passphrase, everyElement(0));
    } finally {
      await secureCore.closeDeviceIdentity(identity);
    }
  });

  test('Windows Native 账户恢复适配器透传失败关闭状态且不保留口令', () async {
    if (!Platform.isWindows) return;
    final identity = await secureCore.generateDeviceIdentity();
    final adapter = E2eeNativeAccountRecoveryProofCore(
      secureCore: secureCore,
      deviceIdentity: identity,
      deviceKeyVersion: 1,
      targetAuthGeneration: 1,
    );
    final passphrase = Uint8List.fromList(
      utf8.encode('account-recovery-passphrase'),
    );
    try {
      await expectLater(
        adapter.verifyHistoryAndCreateProof(
          recoveryMedia: Uint8List(e2eeEncryptedRecoveryMediaBytes),
          recoveryPassphrase: passphrase,
          serviceOriginSha256: Uint8List(32),
          membershipHistory: <Uint8List>[
            Uint8List(cloudSyncMembershipManifestMinimumBytes),
          ],
          currentCapsule: Uint8List(156),
          sourceCapsule: null,
          challengeFrame: Uint8List(316),
          sealedNonce: Uint8List(100),
          recoveryTokenDigest: Uint8List(32),
          expectedAttemptId: '11111111-1111-4111-8111-111111111111',
          expectedDeviceId: '22222222-2222-4222-8222-222222222222',
          expectedRequestDigest: Uint8List(32),
          expectedExpiresAt: DateTime.utc(2026, 8, 1, 2),
        ),
        throwsA(
          isA<KelivoSecureCoreException>().having(
            (error) => error.status,
            'status',
            KelivoSecureCoreStatus.unsupportedPlatform,
          ),
        ),
      );
      expect(passphrase, everyElement(0));
    } finally {
      await secureCore.closeDeviceIdentity(identity);
    }
  });

  test('Native 账户恢复替换适配器在调用核心前拒绝设备密钥漂移并清零口令', () async {
    final identity = await secureCore.generateDeviceIdentity();
    final adapter = E2eeNativeAccountRecoveryProofCore(
      secureCore: secureCore,
      deviceIdentity: identity,
      deviceKeyVersion: 1,
      targetAuthGeneration: 1,
    );
    final passphrase = Uint8List.fromList(
      utf8.encode('account-recovery-passphrase'),
    );
    try {
      await expectLater(
        adapter.verifyReplacementChallengeAndCreateProof(
          recoveryMedia: Uint8List(e2eeEncryptedRecoveryMediaBytes),
          recoveryPassphrase: passphrase,
          serviceOriginSha256: Uint8List(32),
          membershipHistory: <Uint8List>[
            Uint8List(cloudSyncMembershipManifestMinimumBytes),
          ],
          sourceCapsule: Uint8List(cloudSyncRecoveryCapsuleBytes),
          challenge: _replacementChallenge(deviceKeyVersion: 2),
          recoveryTokenDigest: Uint8List(32),
          expectedDeviceId: '22222222-2222-4222-8222-222222222222',
        ),
        throwsFormatException,
      );
      expect(passphrase, everyElement(0));
    } finally {
      await secureCore.closeDeviceIdentity(identity);
    }
  });
}

E2eeAccountRecoveryReplacementChallenge _replacementChallenge({
  required int deviceKeyVersion,
}) {
  final manifest = Uint8List(cloudSyncMembershipManifestMinimumBytes);
  final manifestDigest = Uint8List.fromList(sha256.convert(manifest).bytes);
  final capsule = Uint8List(cloudSyncRecoveryCapsuleBytes);
  final capsuleDigest = Uint8List.fromList(sha256.convert(capsule).bytes);
  final completionProofDigest = Uint8List(32);
  return E2eeAccountRecoveryReplacementChallenge(
    result: E2eeAccountRecoveryReplacementChallengeResult.created,
    challengeId: '11111111-1111-4111-8111-111111111111',
    attemptId: '33333333-3333-4333-8333-333333333333',
    requestDigest: Uint8List(32),
    challengeFrame: Uint8List(
      e2eeAccountRecoveryReplacementChallengeFrameBytes,
    ),
    sealedNonce: Uint8List(e2eeAccountRecoverySealedNonceBytes),
    deviceKeyVersion: deviceKeyVersion,
    deviceSigningPublicKey: Uint8List(cloudSyncDevicePublicKeyBytes),
    deviceKeyAgreementPublicKey: Uint8List(cloudSyncDevicePublicKeyBytes),
    securityGeneration: 2,
    keyEpoch: 2,
    membershipManifest: manifest,
    membershipManifestDigest: manifestDigest,
    membershipOperationId: '44444444-4444-4444-8444-444444444444',
    recoveryPublicKeyVersion: 1,
    recoveryPublicKey: Uint8List(cloudSyncRecoveryPublicKeyBytes),
    recoveryCapsuleVersion: 2,
    recoveryCapsule: capsule,
    recoveryCapsuleDigest: capsuleDigest,
    dataGeneration: 2,
    dataKeyEpoch: 2,
    sourceRekeyOperationId: '55555555-5555-4555-8555-555555555555',
    sourceCompletion: CloudSyncDataRekeyCompletion.fromJson(<String, Object?>{
      'proofVersion': 2,
      'operationId': '55555555-5555-4555-8555-555555555555',
      'issuerDeviceId': '22222222-2222-4222-8222-222222222222',
      'sourceDataGeneration': 1,
      'targetDataGeneration': 2,
      'sourceKeyEpoch': 1,
      'targetKeyEpoch': 2,
      'sourceSnapshotRoot': _encodedBytes(32),
      'sourceRecordCount': 0,
      'sourceAttachmentCount': 0,
      'sourceMaximumChangeSeq': 0,
      'sourceRecordCursorEnd': null,
      'sourceAttachmentCursorEnd': null,
      'membershipGeneration': 2,
      'membershipManifestDigest': _encodedData(manifestDigest),
      'stagedRecordCount': 0,
      'stagedAttachmentCount': 0,
      'stagedCiphertextSetDigest': _encodedBytes(32),
      'proofFrame': _encodedBytes(270),
      'proofDigest': _encodedData(completionProofDigest),
      'signature': _encodedBytes(64),
      'finalizedAt': '2026-08-01T01:30:00.000Z',
    }),
    expiresAt: DateTime.utc(2026, 8, 1, 2),
  );
}

String _encodedBytes(int length) => _encodedData(Uint8List(length));

String _encodedData(Uint8List value) =>
    base64Url.encode(value).replaceAll('=', '');
