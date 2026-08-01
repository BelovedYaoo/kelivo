import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Kelivo/core/services/sync/e2ee_native_account_recovery.dart';
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
          recoveryMedia: Uint8List(644),
          recoveryPassphrase: passphrase,
          serviceOriginSha256: Uint8List(32),
          membershipHistory: <Uint8List>[Uint8List(444)],
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
          recoveryMedia: Uint8List(644),
          recoveryPassphrase: passphrase,
          serviceOriginSha256: Uint8List(32),
          membershipHistory: <Uint8List>[Uint8List(444)],
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
}
