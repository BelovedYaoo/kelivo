import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Kelivo/core/services/sync/e2ee_account_recovery.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_recovery_checkpoint.dart';
import 'package:Kelivo/core/services/workspace/device_state_blob_store.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';

import '../../../support/secure_core_test_store.dart';

void main() {
  SecureCoreTestStoreScope? testStoreScope;

  setUpAll(() {
    testStoreScope = SecureCoreTestStoreScope.open();
  });
  tearDownAll(() {
    testStoreScope?.close();
  });

  test('恢复 checkpoint 只落认证密文且可跨实例原子推进', () async {
    const core = KelivoSecureCore();
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_account_recovery_checkpoint_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('checkpoint-');
    final slotId = Uint8List.fromList(
      _digest(
        Uint8List.fromList(utf8.encode('account-recovery-checkpoint-slot')),
      ).sublist(0, 16),
    );
    final key = await core.createSlot(slotId);
    addTearDown(() async {
      await core.close(key);
      await core.deleteSlot(slotId);
      if (await root.exists()) await root.delete(recursive: true);
    });
    const baseUrl = 'https://kelivo.bemylover.top';
    const loginName = 'ovo';
    final deviceStateStore = DeviceStateBlobStore(installationRoot: root);
    await deviceStateStore.compareAndSwap(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      expectedVersion: null,
      blob: Uint8List(DeviceStateBlobStore.blobLength),
    );
    final recoveryToken = CloudSyncAccountRecoveryToken.parse(
      'kelivo_recovery_${base64Url.encode(_bytes(32, 0x71)).replaceAll('=', '')}',
    );
    final checkpoint = E2eeAccountRecoveryCheckpoint.challenged(
      expectedDeviceId: _uuid(5),
      recoveryToken: recoveryToken,
      challenge: _challenge(),
    );
    final store = E2eeAccountRecoveryCheckpointStore(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      deviceStateStore: deviceStateStore,
      secureCore: core,
      key: key,
    );

    final initial = await store.create(checkpoint);
    final replayedInitial = await store.create(checkpoint);
    expect(replayedInitial.envelopeDigest, initial.envelopeDigest);
    final diskEnvelope = await deviceStateStore
        .readPendingAccountRecoveryEnvelope(
          normalizedBaseUrl: baseUrl,
          normalizedLoginName: loginName,
        );
    expect(diskEnvelope, isNotNull);
    final malformedDiskText = utf8.decode(diskEnvelope!, allowMalformed: true);
    expect(malformedDiskText, isNot(contains(recoveryToken.value)));
    expect(malformedDiskText, isNot(contains(checkpoint.attemptId)));
    final wrongSlotId = Uint8List.fromList(
      _digest(
        Uint8List.fromList(utf8.encode('account-recovery-wrong-slot')),
      ).sublist(0, 16),
    );
    final wrongKey = await core.createSlot(wrongSlotId);
    try {
      final wrongKeyStore = E2eeAccountRecoveryCheckpointStore(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        deviceStateStore: deviceStateStore,
        secureCore: core,
        key: wrongKey,
      );
      await expectLater(
        wrongKeyStore.read(),
        throwsA(isA<KelivoSecureCoreException>()),
      );
    } finally {
      await core.close(wrongKey);
      await core.deleteSlot(wrongSlotId);
    }

    final reopened = E2eeAccountRecoveryCheckpointStore(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      deviceStateStore: deviceStateStore,
      secureCore: core,
      key: key,
    );
    final restored = await reopened.read();
    expect(restored, isNotNull);
    expect(restored!.checkpoint.stage, E2eeAccountRecoveryStage.challenged);
    expect(restored.checkpoint.attemptId, checkpoint.attemptId);
    expect(restored.checkpoint.recoveryToken.value, recoveryToken.value);

    final proofReady = checkpoint.withProof(
      nonceProof: _bytes(32, 0x81),
      trustSignature: _bytes(64, 0x82),
    );
    final advanced = await reopened.advance(
      expectedEnvelopeDigest: initial.envelopeDigest,
      checkpoint: proofReady,
    );
    final replayed = await reopened.advance(
      expectedEnvelopeDigest: initial.envelopeDigest,
      checkpoint: proofReady,
    );
    expect(replayed.envelopeDigest, advanced.envelopeDigest);
    final finalSnapshot = await reopened.read();
    expect(
      finalSnapshot!.checkpoint.stage,
      E2eeAccountRecoveryStage.proofReady,
    );
    expect(finalSnapshot.checkpoint.copyNonceProof(), _bytes(32, 0x81));
    expect(finalSnapshot.checkpoint.copyTrustSignature(), _bytes(64, 0x82));

    final authorized = proofReady.authorized(
      recoveryTokenExpiresAt: DateTime.utc(2026, 8, 1, 2),
      nextAction: E2eeAccountRecoveryNextAction.recoverResume,
    );
    await reopened.advance(
      expectedEnvelopeDigest: finalSnapshot.envelopeDigest,
      checkpoint: authorized,
    );
    final authorizedSnapshot = await reopened.read();
    expect(
      authorizedSnapshot!.checkpoint.stage,
      E2eeAccountRecoveryStage.authorized,
    );
    expect(
      authorizedSnapshot.checkpoint.recoveryTokenExpiresAt,
      DateTime.utc(2026, 8, 1, 2),
    );
    expect(
      authorizedSnapshot.checkpoint.nextAction,
      E2eeAccountRecoveryNextAction.recoverResume,
    );
  });
}

E2eeAccountRecoveryChallenge _challenge() {
  final manifest = _bytes(444, 0x11);
  final capsule = _bytes(156, 0x41);
  return E2eeAccountRecoveryChallenge(
    attemptId: _uuid(1),
    requestDigest: _bytes(32, 0x31),
    challengeFrame: _bytes(316, 0x32),
    sealedNonce: _bytes(100, 0x33),
    securityGeneration: 1,
    keyEpoch: 1,
    membershipManifestDigest: _digest(manifest),
    recoveryPublicKeyVersion: 1,
    recoveryPublicKey: _bytes(32, 0x34),
    recoveryCapsuleVersion: 1,
    recoveryCapsule: capsule,
    recoveryCapsuleDigest: _digest(capsule),
    dataState: E2eeAccountRecoveryDataState.ready(
      dataGeneration: 1,
      dataKeyEpoch: 1,
    ),
    expiresAt: DateTime.utc(2026, 8, 1, 1),
  );
}

Uint8List _digest(Uint8List value) =>
    Uint8List.fromList(sha256.convert(value).bytes);

Uint8List _bytes(int length, int value) =>
    Uint8List(length)..fillRange(0, length, value);

String _uuid(int value) {
  final digit = value.toRadixString(16);
  String repeated(int count) => List<String>.filled(count, digit).join();
  return '${repeated(8)}-${repeated(4)}-4${repeated(3)}-8${repeated(3)}-${repeated(12)}';
}
