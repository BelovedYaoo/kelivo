import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Kelivo/core/services/sync/e2ee_account_recovery.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_recovery_checkpoint.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
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
    expect(authorizedSnapshot.checkpoint.copyNonceProof(), _bytes(32, 0x81));
    expect(
      authorizedSnapshot.checkpoint.copyTrustSignature(),
      _bytes(64, 0x82),
    );

    final resumeManifest = _bytes(
      cloudSyncMembershipManifestMaximumBytes,
      0x91,
    );
    final resumeRequest = E2eeAccountRecoveryResumeCommit(
      attemptId: checkpoint.attemptId,
      membership: E2eeAccountRecoveryMembershipCommit(
        expectedGeneration: checkpoint.challenge.securityGeneration,
        expectedKeyEpoch: checkpoint.challenge.keyEpoch,
        expectedMembershipManifestDigest:
            CloudSyncMembershipManifestDigest.fromBytes(
              checkpoint.challenge.membershipManifestDigest,
            ),
        operationId: _uuid(2),
        nextMembershipManifest: resumeManifest,
        nextMembershipManifestDigest:
            CloudSyncMembershipManifestDigest.fromBytes(
              _digest(resumeManifest),
            ),
        envelope: E2eeAccountRecoveryEnvelope(
          envelopeVersion: 1,
          keyEpoch: checkpoint.challenge.keyEpoch,
          accountKeyEnvelope: _bytes(cloudSyncAccountKeyEnvelopeBytes, 0x92),
        ),
      ),
      rekeyOperationId: checkpoint.challenge.dataState.operationId!,
    );
    final resumePlan = _localTransitionPlan(0x93);
    final preparedResume = authorized.withPreparedCommit(resumeRequest);
    expect(
      () => preparedResume.withPreparedCommit(resumeRequest),
      throwsA(isA<StateError>()),
    );
    final plannedResume = preparedResume.withLocalTransitionPlan(resumePlan);
    expect(
      plannedResume.localTransitionPlan!.phase,
      E2eeAccountRecoveryLocalTransitionPhase.candidatePrepared,
    );
    expect(
      () => plannedResume.withLocalTransitionPlan(resumePlan),
      throwsA(isA<StateError>()),
    );
    expect(
      plannedResume.markLocalTransitionProofVerified,
      throwsA(isA<StateError>()),
    );
    await reopened.advance(
      expectedEnvelopeDigest: authorizedSnapshot.envelopeDigest,
      checkpoint: plannedResume,
    );
    final restoredResumeSnapshot = await reopened.read();
    final restoredResume =
        restoredResumeSnapshot!.checkpoint.preparedCommit
            as E2eeAccountRecoveryResumeCommit;
    expect(restoredResume.rekeyOperationId, resumeRequest.rekeyOperationId);
    expect(
      restoredResume.membership.nextMembershipManifest,
      resumeRequest.membership.nextMembershipManifest,
    );
    final restoredResumePlan =
        restoredResumeSnapshot.checkpoint.localTransitionPlan!;
    expect(restoredResumePlan.sourceStateBlob, resumePlan.sourceStateBlob);
    expect(restoredResumePlan.unprunedStateBlob, resumePlan.unprunedStateBlob);
    expect(restoredResumePlan.prunedStateBlob, resumePlan.prunedStateBlob);
    restoredResumePlan.sourceStateBlob[0] ^= 0xff;
    expect(restoredResumePlan.sourceStateBlob, resumePlan.sourceStateBlob);
    final resumeReceipt = E2eeAccountRecoveryCommitReceipt(
      result: E2eeAccountRecoveryCommitResult.committed,
      kind: E2eeAccountRecoveryCommitKind.resume,
      attemptId: resumeRequest.attemptId,
      membershipOperationId: resumeRequest.membership.operationId,
      rekeyOperationId: resumeRequest.rekeyOperationId,
      generation: resumeRequest.membership.expectedGeneration + 1,
      keyEpoch: resumeRequest.membership.expectedKeyEpoch,
      nextAction: E2eeAccountRecoveryNextAction.finishFirstDataRekey,
    );
    expect(
      () => preparedResume.withCommitReceipt(resumeReceipt),
      throwsA(isA<StateError>()),
    );
    final committedResume = restoredResumeSnapshot.checkpoint.withCommitReceipt(
      resumeReceipt,
    );
    expect(
      () => committedResume.withCommitReceipt(resumeReceipt),
      throwsA(isA<StateError>()),
    );
    final committedResumeSnapshot = await reopened.advance(
      expectedEnvelopeDigest: restoredResumeSnapshot.envelopeDigest,
      checkpoint: committedResume,
    );
    final restoredCommittedResume = await reopened.read();
    expect(
      restoredCommittedResume!.checkpoint.nextAction,
      E2eeAccountRecoveryNextAction.finishFirstDataRekey,
    );
    expect(
      restoredCommittedResume.checkpoint.commitReceipt?.membershipOperationId,
      resumeRequest.membership.operationId,
    );
    expect(
      restoredCommittedResume.checkpoint.markLocalTransitionActivated,
      throwsA(isA<StateError>()),
    );
    final proofVerifiedResume = restoredCommittedResume.checkpoint
        .markLocalTransitionProofVerified();
    final proofVerifiedResumeSnapshot = await reopened.advance(
      expectedEnvelopeDigest: committedResumeSnapshot.envelopeDigest,
      checkpoint: proofVerifiedResume,
    );
    expect(
      (await reopened.read())!.checkpoint.localTransitionPlan!.phase,
      E2eeAccountRecoveryLocalTransitionPhase.proofVerified,
    );
    final activatedResume = proofVerifiedResume.markLocalTransitionActivated();
    final activatedResumeSnapshot = await reopened.advance(
      expectedEnvelopeDigest: proofVerifiedResumeSnapshot.envelopeDigest,
      checkpoint: activatedResume,
    );
    expect(
      (await reopened.read())!.checkpoint.localTransitionPlan!.phase,
      E2eeAccountRecoveryLocalTransitionPhase.activated,
    );
    expect(await reopened.delete(activatedResumeSnapshot), isTrue);

    final replacementChallenge = _challenge(rekeyPending: false);
    final replacementBase =
        E2eeAccountRecoveryCheckpoint.challenged(
              expectedDeviceId: _uuid(5),
              recoveryToken: recoveryToken,
              challenge: replacementChallenge,
            )
            .withProof(
              nonceProof: _bytes(32, 0xa1),
              trustSignature: _bytes(64, 0xa2),
            )
            .authorized(
              recoveryTokenExpiresAt: DateTime.utc(2026, 8, 1, 2),
              nextAction: E2eeAccountRecoveryNextAction.recoverReplace,
            );
    final replacementManifest = _bytes(
      cloudSyncMembershipManifestMaximumBytes,
      0xa3,
    );
    final completionSessionToken = CloudSyncFullSessionToken.generate();
    final replacementRequest = E2eeAccountRecoveryReplacementCommit(
      attemptId: replacementChallenge.attemptId,
      membership: E2eeAccountRecoveryMembershipCommit(
        expectedGeneration: replacementChallenge.securityGeneration,
        expectedKeyEpoch: replacementChallenge.keyEpoch,
        expectedMembershipManifestDigest:
            CloudSyncMembershipManifestDigest.fromBytes(
              replacementChallenge.membershipManifestDigest,
            ),
        operationId: _uuid(6),
        nextMembershipManifest: replacementManifest,
        nextMembershipManifestDigest:
            CloudSyncMembershipManifestDigest.fromBytes(
              _digest(replacementManifest),
            ),
        envelope: E2eeAccountRecoveryEnvelope(
          envelopeVersion: 1,
          keyEpoch: replacementChallenge.keyEpoch + 1,
          accountKeyEnvelope: _bytes(cloudSyncAccountKeyEnvelopeBytes, 0xa4),
        ),
      ),
      nextRecoveryCapsuleVersion:
          replacementChallenge.recoveryCapsuleVersion + 1,
      nextRecoveryCapsule: _bytes(cloudSyncRecoveryCapsuleMaximumBytes, 0xa5),
      completionSessionId: _uuid(7),
      completionSessionToken: completionSessionToken,
    );
    final replacementPlan = _localTransitionPlan(0xa6);
    final preparedReplacement = replacementBase
        .withPreparedCommit(replacementRequest)
        .withLocalTransitionPlan(replacementPlan);
    await reopened.create(preparedReplacement);
    final restoredReplacementSnapshot = await reopened.read();
    final restoredReplacement =
        restoredReplacementSnapshot!.checkpoint.preparedCommit
            as E2eeAccountRecoveryReplacementCommit;
    expect(
      restoredReplacement.nextRecoveryCapsule,
      replacementRequest.nextRecoveryCapsule,
    );
    expect(
      restoredReplacement.completionSessionToken.value,
      completionSessionToken.value,
    );
    expect(
      restoredReplacementSnapshot
          .checkpoint
          .localTransitionPlan!
          .prunedStateBlob,
      replacementPlan.prunedStateBlob,
    );
    final replacementReceipt = E2eeAccountRecoveryCommitReceipt(
      result: E2eeAccountRecoveryCommitResult.replayed,
      kind: E2eeAccountRecoveryCommitKind.replacement,
      attemptId: replacementRequest.attemptId,
      membershipOperationId: replacementRequest.membership.operationId,
      rekeyOperationId: replacementRequest.membership.operationId,
      generation: replacementRequest.membership.expectedGeneration + 1,
      keyEpoch: replacementRequest.membership.expectedKeyEpoch + 1,
      nextAction: E2eeAccountRecoveryNextAction.finishSecondDataRekey,
    );
    await reopened.advance(
      expectedEnvelopeDigest: restoredReplacementSnapshot.envelopeDigest,
      checkpoint: restoredReplacementSnapshot.checkpoint.withCommitReceipt(
        replacementReceipt,
      ),
    );
    final restoredCommittedReplacement = await reopened.read();
    expect(
      restoredCommittedReplacement!.checkpoint.nextAction,
      E2eeAccountRecoveryNextAction.finishSecondDataRekey,
    );
    expect(
      restoredCommittedReplacement.checkpoint.commitReceipt?.result,
      E2eeAccountRecoveryCommitResult.replayed,
    );
    final preparedDiskEnvelope = await deviceStateStore
        .readPendingAccountRecoveryEnvelope(
          normalizedBaseUrl: baseUrl,
          normalizedLoginName: loginName,
        );
    expect(preparedDiskEnvelope!.length, greaterThan(8192));
    expect(
      preparedDiskEnvelope.length,
      lessThanOrEqualTo(
        DeviceStateBlobStore.pendingAccountRecoveryEnvelopeMaxLength,
      ),
    );
    final preparedDiskText = utf8.decode(
      preparedDiskEnvelope,
      allowMalformed: true,
    );
    expect(preparedDiskText, isNot(contains(completionSessionToken.value)));
    expect(
      preparedDiskText,
      isNot(contains(replacementRequest.membership.operationId)),
    );
  });
}

E2eeAccountRecoveryChallenge _challenge({bool rekeyPending = true}) {
  final manifest = _bytes(476, 0x11);
  final capsule = _bytes(156, 0x41);
  return E2eeAccountRecoveryChallenge(
    attemptId: _uuid(1),
    requestDigest: _bytes(32, 0x31),
    challengeFrame: _bytes(316, 0x32),
    sealedNonce: _bytes(100, 0x33),
    securityGeneration: 1,
    keyEpoch: rekeyPending ? 2 : 1,
    membershipManifestDigest: _digest(manifest),
    recoveryPublicKeyVersion: 1,
    recoveryPublicKey: _bytes(32, 0x34),
    recoveryCapsuleVersion: 1,
    recoveryCapsule: capsule,
    recoveryCapsuleDigest: _digest(capsule),
    dataState: rekeyPending
        ? E2eeAccountRecoveryDataState.rekeyPending(
            dataGeneration: 1,
            dataKeyEpoch: 1,
            operationId: _uuid(4),
            targetKeyEpoch: 2,
          )
        : E2eeAccountRecoveryDataState.ready(
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

E2eeAccountRecoveryLocalTransitionPlan _localTransitionPlan(int seed) {
  return E2eeAccountRecoveryLocalTransitionPlan(
    sourceStateBlob: _bytes(DeviceStateBlobStore.blobLength, seed),
    unprunedStateBlob: _bytes(DeviceStateBlobStore.blobLength, seed + 1),
    prunedStateBlob: _bytes(DeviceStateBlobStore.blobLength, seed + 2),
  );
}

String _uuid(int value) {
  final digit = value.toRadixString(16);
  String repeated(int count) => List<String>.filled(count, digit).join();
  return '${repeated(8)}-${repeated(4)}-4${repeated(3)}-8${repeated(3)}-${repeated(12)}';
}
