import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_recovery.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_recovery_checkpoint.dart';
import 'package:Kelivo/core/services/workspace/device_state_blob_store.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';

import '../../../support/secure_core_test_store.dart';

void main() {
  test('direct replacement 只通过单一耐久阶段推进并持有 Native continuation', () {
    final challenge = _challenge(rekeyPending: false);
    final checkpoint = E2eeAccountRecoveryCheckpoint.challenged(
      expectedDeviceId: _uuid(5),
      recoveryToken: _recoveryToken(0x71),
      challenge: challenge,
    );
    expect(checkpoint.phase, E2eeAccountRecoveryCheckpointPhase.challenged);

    final authorized = checkpoint
        .withProof(
          nonceProof: _bytes(e2eeAccountRecoveryNonceProofBytes, 0x81),
          trustSignature: _bytes(e2eeAccountRecoveryTrustSignatureBytes, 0x82),
        )
        .authorized(
          recoveryTokenExpiresAt: DateTime.utc(2026, 8, 1, 2),
          nextAction: E2eeAccountRecoveryNextAction.recoverReplace,
        );
    final continuation = _bytes(
      e2eeAccountRecoveryNativeContinuationBytes,
      0x91,
    );
    final replacementCommit = _replacementCommit(challenge);
    final prepared = authorized.prepareTransition(
      commit: replacementCommit,
      localTransitionPlan: _localTransitionPlan(
        0x93,
        continuation: continuation,
        replacement: true,
      ),
    );

    expect(
      prepared.phase,
      E2eeAccountRecoveryCheckpointPhase.replacementPrepared,
    );
    expect(
      prepared.progress,
      isA<E2eeAccountRecoveryReplacementPreparedProgress>(),
    );
    continuation.fillRange(0, continuation.length, 0);
    final progress =
        prepared.progress as E2eeAccountRecoveryReplacementPreparedProgress;
    expect(
      progress.transition.localTransitionPlan.copyContinuation(),
      everyElement(0x91),
    );

    final committed = prepared.withCommitReceipt(
      _receipt(
        replacementCommit,
        result: E2eeAccountRecoveryCommitResult.committed,
      ),
    );
    expect(
      progress.transition.localTransitionPlan.copyContinuation(),
      everyElement(0),
    );
    final committedProgress =
        committed.progress as E2eeAccountRecoveryReplacementCommittedProgress;
    expect(
      committedProgress.transition.localTransitionPlan.copyContinuation(),
      everyElement(0x91),
    );

    final finalized = committed.withRekeyCompletion(
      _completionFor(
        commit: replacementCommit,
        issuerDeviceId: committed.expectedDeviceId,
        seed: 0xa1,
      ),
    );
    expect(
      committedProgress.transition.localTransitionPlan.copyContinuation(),
      everyElement(0),
    );
    final finalizedProgress =
        finalized.progress as E2eeAccountRecoverySecondRekeyFinalizedProgress;
    expect(
      finalizedProgress.transition.localTransitionPlan.copyContinuation(),
      everyElement(0x91),
    );

    final activated = finalized.markLocalTransitionActivated();
    expect(
      finalizedProgress.transition.localTransitionPlan.copyContinuation(),
      everyElement(0),
    );
    expect(
      activated.markSessionVerified().phase,
      E2eeAccountRecoveryCheckpointPhase.sessionVerified,
    );
    final invalidCapsulePlan = _localTransitionPlan(0xb1, replacement: true);
    expect(
      () => authorized.prepareTransition(
        commit: _replacementCommit(
          challenge,
          nextRecoveryCapsuleVersion: challenge.recoveryCapsuleVersion,
        ),
        localTransitionPlan: invalidCapsulePlan,
      ),
      throwsFormatException,
    );
    expect(invalidCapsulePlan.copyContinuation(), everyElement(0));

    final rejectedPlan = _localTransitionPlan(0xb5);
    expect(
      () => E2eeAccountRecoveryPreparedTransition(
        commit: replacementCommit,
        localTransitionPlan: rejectedPlan,
      ),
      throwsFormatException,
    );
    expect(rejectedPlan.copyContinuation(), everyElement(0));
    expect(
      () => E2eeAccountRecoveryLocalTransitionPlan(
        sourceStateBlob: _bytes(DeviceStateBlobStore.blobLength, 1),
        unprunedStateBlob: _bytes(DeviceStateBlobStore.blobLength, 2),
        prunedStateBlob: _bytes(DeviceStateBlobStore.blobLength, 3),
        deviceKeyVersion: 1,
        userId: _uuid(9),
        sourceDataGeneration: 1,
        operationAuthorizationDigest: Uint8List(32),
        continuation: Uint8List(e2eeAccountRecoveryNativeContinuationBytes - 1),
      ),
      throwsFormatException,
    );
  });

  test('resume 完成首轮后裁剪大字段并通过第二 challenge 完成 replacement', () {
    final challenge = _challenge();
    final authorized = _authorizedCheckpoint(challenge);
    final resumeCommit = _resumeCommit(challenge);
    final resumePrepared = authorized.prepareTransition(
      commit: resumeCommit,
      localTransitionPlan: _localTransitionPlan(0x91),
    );
    expect(
      resumePrepared.phase,
      E2eeAccountRecoveryCheckpointPhase.resumePrepared,
    );
    final resumeReceipt = _receipt(
      resumeCommit,
      result: E2eeAccountRecoveryCommitResult.committed,
    );
    final resumeCommitted = resumePrepared.withCommitReceipt(resumeReceipt);
    expect(
      resumeCommitted.phase,
      E2eeAccountRecoveryCheckpointPhase.resumeCommitted,
    );
    final firstCompletion = _completionFor(
      commit: resumeCommit,
      issuerDeviceId: authorized.expectedDeviceId,
      seed: 0xb1,
    );
    final firstFinalized = resumeCommitted.withRekeyCompletion(firstCompletion);
    expect(
      firstFinalized.phase,
      E2eeAccountRecoveryCheckpointPhase.firstRekeyFinalized,
    );
    final firstActivated = firstFinalized.markLocalTransitionActivated();
    expect(
      firstActivated.phase,
      E2eeAccountRecoveryCheckpointPhase.firstLocalActivated,
    );
    final firstProgress =
        firstActivated.progress
            as E2eeAccountRecoveryFirstLocalActivatedProgress;
    expect(firstProgress.resumeReceipt, same(resumeReceipt));
    expect(firstProgress.completion.proofDigest, firstCompletion.proofDigest);

    final replacementRequest = _replacementChallengeRequest(firstProgress);
    final requested = firstActivated.requestReplacementChallenge(
      replacementRequest,
    );
    expect(
      requested.phase,
      E2eeAccountRecoveryCheckpointPhase.replacementChallengeRequested,
    );
    final replacementChallenge = _replacementChallenge(
      request: replacementRequest,
      resumeCommit: resumeCommit,
      completion: firstCompletion,
    );
    final challengeReceived = requested.withReplacementChallenge(
      replacementChallenge,
    );
    expect(
      challengeReceived.phase,
      E2eeAccountRecoveryCheckpointPhase.replacementChallengeReceived,
    );
    final replacementProofReady = challengeReceived.withReplacementProof(
      nonceProof: _bytes(e2eeAccountRecoveryNonceProofBytes, 0xc1),
      trustSignature: _bytes(e2eeAccountRecoveryTrustSignatureBytes, 0xc2),
    );
    expect(
      replacementProofReady.phase,
      E2eeAccountRecoveryCheckpointPhase.replacementProofReady,
    );
    final replacementCommit = _replacementCommitForChallenge(
      replacementChallenge,
    );
    final replacementPrepared = replacementProofReady.prepareTransition(
      commit: replacementCommit,
      localTransitionPlan: _localTransitionPlan(
        0xc3,
        replacement: true,
        sourceDataGeneration: replacementChallenge.dataGeneration,
      ),
    );
    expect(
      replacementPrepared.phase,
      E2eeAccountRecoveryCheckpointPhase.replacementPrepared,
    );
    final replacementProgress =
        replacementPrepared.progress
            as E2eeAccountRecoveryReplacementPreparedProgress;
    expect(replacementProgress.transition.commit, same(replacementCommit));

    final replacementCommitted = replacementPrepared.withCommitReceipt(
      _receipt(
        replacementCommit,
        result: E2eeAccountRecoveryCommitResult.replayed,
      ),
    );
    expect(
      replacementCommitted.phase,
      E2eeAccountRecoveryCheckpointPhase.replacementCommitted,
    );
    final secondCompletion = _completionFor(
      commit: replacementCommit,
      issuerDeviceId: authorized.expectedDeviceId,
      seed: 0xd1,
    );
    final secondFinalized = replacementCommitted.withRekeyCompletion(
      secondCompletion,
    );
    expect(
      secondFinalized.phase,
      E2eeAccountRecoveryCheckpointPhase.secondRekeyFinalized,
    );
    final secondActivated = secondFinalized.markLocalTransitionActivated();
    expect(
      secondActivated.phase,
      E2eeAccountRecoveryCheckpointPhase.secondLocalActivated,
    );
    final verified = secondActivated.markSessionVerified();
    expect(verified.phase, E2eeAccountRecoveryCheckpointPhase.sessionVerified);
  });

  test('v6 每个耐久阶段可重开、篡改失败且最大帧不超过 64 KiB', () async {
    final testStoreScope = SecureCoreTestStoreScope.open();
    addTearDown(testStoreScope.close);
    const core = KelivoSecureCore();
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_account_recovery_checkpoint_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('checkpoint-v6-');
    final slotId = Uint8List.fromList(
      _digest(
        Uint8List.fromList(utf8.encode('checkpoint-v6-slot')),
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
    final store = E2eeAccountRecoveryCheckpointStore(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      deviceStateStore: deviceStateStore,
      secureCore: core,
      key: key,
    );

    Future<E2eeAccountRecoveryCheckpointSnapshot> reopenAt(
      E2eeAccountRecoveryCheckpointPhase phase,
    ) async {
      final reopened = await store.read();
      expect(reopened, isNotNull);
      expect(reopened!.checkpoint.phase, phase);
      final envelope = await deviceStateStore
          .readPendingAccountRecoveryEnvelope(
            normalizedBaseUrl: baseUrl,
            normalizedLoginName: loginName,
          );
      expect(envelope, isNotNull);
      expect(
        envelope!.length,
        lessThan(DeviceStateBlobStore.pendingAccountRecoveryEnvelopeMaxLength),
      );
      return reopened;
    }

    Future<E2eeAccountRecoveryCheckpointSnapshot> advanceAndReopen(
      E2eeAccountRecoveryCheckpointSnapshot current,
      E2eeAccountRecoveryCheckpoint next,
    ) async {
      await store.advance(
        expectedEnvelopeDigest: current.envelopeDigest,
        checkpoint: next,
      );
      return reopenAt(next.phase);
    }

    final challenge = _challenge();
    var snapshot = await store.create(
      E2eeAccountRecoveryCheckpoint.challenged(
        expectedDeviceId: _uuid(5),
        recoveryToken: _recoveryToken(0x71),
        challenge: challenge,
      ),
    );
    snapshot = await reopenAt(E2eeAccountRecoveryCheckpointPhase.challenged);
    snapshot = await advanceAndReopen(
      snapshot,
      snapshot.checkpoint.withProof(
        nonceProof: _bytes(e2eeAccountRecoveryNonceProofBytes, 0x81),
        trustSignature: _bytes(e2eeAccountRecoveryTrustSignatureBytes, 0x82),
      ),
    );
    snapshot = await advanceAndReopen(
      snapshot,
      snapshot.checkpoint.authorized(
        recoveryTokenExpiresAt: DateTime.utc(2026, 8, 1, 2),
        nextAction: E2eeAccountRecoveryNextAction.recoverResume,
      ),
    );

    final resumeCommit = _resumeCommit(challenge);
    snapshot = await advanceAndReopen(
      snapshot,
      snapshot.checkpoint.prepareTransition(
        commit: resumeCommit,
        localTransitionPlan: _localTransitionPlan(0x91),
      ),
    );
    final resumePreparedEnvelope = await deviceStateStore
        .readPendingAccountRecoveryEnvelope(
          normalizedBaseUrl: baseUrl,
          normalizedLoginName: loginName,
        );
    snapshot = await advanceAndReopen(
      snapshot,
      snapshot.checkpoint.withCommitReceipt(
        _receipt(
          resumeCommit,
          result: E2eeAccountRecoveryCommitResult.committed,
        ),
      ),
    );
    final firstCompletion = _completionFor(
      commit: resumeCommit,
      issuerDeviceId: snapshot.checkpoint.expectedDeviceId,
      seed: 0xb1,
    );
    snapshot = await advanceAndReopen(
      snapshot,
      snapshot.checkpoint.withRekeyCompletion(firstCompletion),
    );
    snapshot = await advanceAndReopen(
      snapshot,
      snapshot.checkpoint.markLocalTransitionActivated(),
    );
    final firstActivatedEnvelope = await deviceStateStore
        .readPendingAccountRecoveryEnvelope(
          normalizedBaseUrl: baseUrl,
          normalizedLoginName: loginName,
        );
    expect(
      firstActivatedEnvelope!.length,
      lessThan(resumePreparedEnvelope!.length),
    );

    final firstProgress =
        snapshot.checkpoint.progress
            as E2eeAccountRecoveryFirstLocalActivatedProgress;
    final replacementRequest = _replacementChallengeRequest(firstProgress);
    snapshot = await advanceAndReopen(
      snapshot,
      snapshot.checkpoint.requestReplacementChallenge(replacementRequest),
    );
    final replacementChallenge = _replacementChallenge(
      request: replacementRequest,
      resumeCommit: resumeCommit,
      completion: firstCompletion,
    );
    snapshot = await advanceAndReopen(
      snapshot,
      snapshot.checkpoint.withReplacementChallenge(replacementChallenge),
    );

    final originalEnvelope = await deviceStateStore
        .readPendingAccountRecoveryEnvelope(
          normalizedBaseUrl: baseUrl,
          normalizedLoginName: loginName,
        );
    final tamperedEnvelope = Uint8List.fromList(originalEnvelope!);
    tamperedEnvelope[tamperedEnvelope.length - 1] ^= 0x01;
    await deviceStateStore.replacePendingAccountRecoveryEnvelope(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      expectedDigest: _digest(originalEnvelope),
      envelope: tamperedEnvelope,
    );
    await expectLater(store.read(), throwsA(isA<KelivoSecureCoreException>()));
    await deviceStateStore.replacePendingAccountRecoveryEnvelope(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      expectedDigest: _digest(tamperedEnvelope),
      envelope: originalEnvelope,
    );
    snapshot = await reopenAt(
      E2eeAccountRecoveryCheckpointPhase.replacementChallengeReceived,
    );

    snapshot = await advanceAndReopen(
      snapshot,
      snapshot.checkpoint.withReplacementProof(
        nonceProof: _bytes(e2eeAccountRecoveryNonceProofBytes, 0xc1),
        trustSignature: _bytes(e2eeAccountRecoveryTrustSignatureBytes, 0xc2),
      ),
    );
    final replacementCommit = _replacementCommitForChallenge(
      replacementChallenge,
    );
    snapshot = await advanceAndReopen(
      snapshot,
      snapshot.checkpoint.prepareTransition(
        commit: replacementCommit,
        localTransitionPlan: _localTransitionPlan(
          0xc3,
          replacement: true,
          sourceDataGeneration: replacementChallenge.dataGeneration,
        ),
      ),
    );
    snapshot = await advanceAndReopen(
      snapshot,
      snapshot.checkpoint.withCommitReceipt(
        _receipt(
          replacementCommit,
          result: E2eeAccountRecoveryCommitResult.replayed,
        ),
      ),
    );
    final secondCompletion = _completionFor(
      commit: replacementCommit,
      issuerDeviceId: snapshot.checkpoint.expectedDeviceId,
      seed: 0xd1,
    );
    snapshot = await advanceAndReopen(
      snapshot,
      snapshot.checkpoint.withRekeyCompletion(secondCompletion),
    );
    snapshot = await advanceAndReopen(
      snapshot,
      snapshot.checkpoint.markLocalTransitionActivated(),
    );
    snapshot = await advanceAndReopen(
      snapshot,
      snapshot.checkpoint.markSessionVerified(),
    );
    expect(await store.delete(snapshot), isTrue);

    final directChallenge = _challenge(rekeyPending: false);
    final directPrepared = _authorizedCheckpoint(directChallenge)
        .prepareTransition(
          commit: _replacementCommit(directChallenge),
          localTransitionPlan: _localTransitionPlan(0xe1, replacement: true),
        );
    snapshot = await store.create(directPrepared);
    snapshot = await reopenAt(
      E2eeAccountRecoveryCheckpointPhase.replacementPrepared,
    );
    final directEnvelope = await deviceStateStore
        .readPendingAccountRecoveryEnvelope(
          normalizedBaseUrl: baseUrl,
          normalizedLoginName: loginName,
        );
    expect(
      utf8.decode(directEnvelope!, allowMalformed: true),
      isNot(contains(directPrepared.recoveryToken.value)),
    );
    expect(await store.delete(snapshot), isTrue);

    final scope = '$baseUrl\u0000$loginName';
    final recordId = Uint8List.fromList(
      sha256
          .convert(
            utf8.encode(
              'kelivo.account-recovery.checkpoint.record.v6\u0000$scope',
            ),
          )
          .bytes
          .sublist(0, 16),
    );
    final associatedData = Uint8List.fromList(
      utf8.encode('kelivo.account-recovery.checkpoint.aad.v6\u0000$scope'),
    );
    final legacyFrame = Uint8List(12);
    legacyFrame.setRange(0, 8, ascii.encode('KELVARC5'));
    ByteData.sublistView(legacyFrame).setUint32(8, 5, Endian.big);
    final legacyEnvelope = await core.sealRecord(
      key,
      recordId: recordId,
      epoch: 1,
      associatedData: associatedData,
      plaintext: legacyFrame,
    );
    await deviceStateStore.writePendingAccountRecoveryEnvelope(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      envelope: legacyEnvelope,
    );
    await expectLater(store.read(), throwsFormatException);
  });
}

E2eeAccountRecoveryCheckpoint _authorizedCheckpoint(
  E2eeAccountRecoveryChallenge challenge,
) {
  return E2eeAccountRecoveryCheckpoint.challenged(
        expectedDeviceId: _uuid(5),
        recoveryToken: _recoveryToken(0x71),
        challenge: challenge,
      )
      .withProof(
        nonceProof: _bytes(e2eeAccountRecoveryNonceProofBytes, 0x81),
        trustSignature: _bytes(e2eeAccountRecoveryTrustSignatureBytes, 0x82),
      )
      .authorized(
        recoveryTokenExpiresAt: DateTime.utc(2026, 8, 1, 2),
        nextAction:
            challenge.dataState.phase == E2eeAccountRecoveryDataPhase.ready
            ? E2eeAccountRecoveryNextAction.recoverReplace
            : E2eeAccountRecoveryNextAction.recoverResume,
      );
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
    Uint8List(length)..fillRange(0, length, value & 0xff);

CloudSyncAccountRecoveryToken _recoveryToken(int seed) {
  return CloudSyncAccountRecoveryToken.parse(
    'kelivo_recovery_${base64Url.encode(_bytes(32, seed)).replaceAll('=', '')}',
  );
}

CloudSyncFullSessionToken _fullSessionToken(int seed) {
  return CloudSyncFullSessionToken.parse(
    'kelivo_${base64Url.encode(_bytes(32, seed)).replaceAll('=', '')}',
  );
}

E2eeAccountRecoveryReplacementCommit _replacementCommit(
  E2eeAccountRecoveryChallenge challenge, {
  int? nextRecoveryCapsuleVersion,
}) {
  final manifest = _bytes(cloudSyncMembershipManifestMaximumBytes, 0xa3);
  return E2eeAccountRecoveryReplacementCommit(
    attemptId: challenge.attemptId,
    membership: E2eeAccountRecoveryMembershipCommit(
      expectedGeneration: challenge.securityGeneration,
      expectedKeyEpoch: challenge.keyEpoch,
      expectedMembershipManifestDigest:
          CloudSyncMembershipManifestDigest.fromBytes(
            challenge.membershipManifestDigest,
          ),
      operationId: _uuid(6),
      nextMembershipManifest: manifest,
      nextMembershipManifestDigest: CloudSyncMembershipManifestDigest.fromBytes(
        _digest(manifest),
      ),
      envelope: E2eeAccountRecoveryEnvelope(
        envelopeVersion: 1,
        keyEpoch: challenge.keyEpoch + 1,
        accountKeyEnvelope: _bytes(cloudSyncAccountKeyEnvelopeBytes, 0xa4),
      ),
    ),
    authorization: E2eeAccountRecoveryReplacementAuthorization.initial(
      challengeRequestDigest: challenge.requestDigest,
    ),
    nextRecoveryCapsuleVersion:
        nextRecoveryCapsuleVersion ?? challenge.recoveryCapsuleVersion + 1,
    nextRecoveryCapsule: _bytes(cloudSyncRecoveryCapsuleMaximumBytes, 0xa5),
    completionSessionId: _uuid(7),
    completionSessionToken: _fullSessionToken(0xa6),
  );
}

E2eeAccountRecoveryResumeCommit _resumeCommit(
  E2eeAccountRecoveryChallenge challenge,
) {
  final manifest = _bytes(cloudSyncMembershipManifestMaximumBytes, 0x91);
  return E2eeAccountRecoveryResumeCommit(
    attemptId: challenge.attemptId,
    membership: E2eeAccountRecoveryMembershipCommit(
      expectedGeneration: challenge.securityGeneration,
      expectedKeyEpoch: challenge.keyEpoch,
      expectedMembershipManifestDigest:
          CloudSyncMembershipManifestDigest.fromBytes(
            challenge.membershipManifestDigest,
          ),
      operationId: _uuid(2),
      nextMembershipManifest: manifest,
      nextMembershipManifestDigest: CloudSyncMembershipManifestDigest.fromBytes(
        _digest(manifest),
      ),
      envelope: E2eeAccountRecoveryEnvelope(
        envelopeVersion: 1,
        keyEpoch: challenge.keyEpoch,
        accountKeyEnvelope: _bytes(cloudSyncAccountKeyEnvelopeBytes, 0x92),
      ),
    ),
    rekeyOperationId: challenge.dataState.operationId!,
  );
}

E2eeAccountRecoveryCommitReceipt _receipt(
  E2eeAccountRecoveryPreparedCommit commit, {
  required E2eeAccountRecoveryCommitResult result,
}) {
  final membership = commit.membership;
  return E2eeAccountRecoveryCommitReceipt(
    result: result,
    kind: commit.kind,
    attemptId: commit.attemptId,
    membershipOperationId: membership.operationId,
    rekeyOperationId: switch (commit) {
      E2eeAccountRecoveryResumeCommit(:final rekeyOperationId) =>
        rekeyOperationId,
      E2eeAccountRecoveryReplacementCommit() => membership.operationId,
    },
    generation: membership.expectedGeneration + 1,
    keyEpoch: switch (commit) {
      E2eeAccountRecoveryResumeCommit() => membership.expectedKeyEpoch,
      E2eeAccountRecoveryReplacementCommit() => membership.expectedKeyEpoch + 1,
    },
    nextAction: switch (commit) {
      E2eeAccountRecoveryResumeCommit() =>
        E2eeAccountRecoveryNextAction.finishFirstDataRekey,
      E2eeAccountRecoveryReplacementCommit() =>
        E2eeAccountRecoveryNextAction.finishSecondDataRekey,
    },
  );
}

CloudSyncDataRekeyCompletion _completionFor({
  required E2eeAccountRecoveryPreparedCommit commit,
  required String issuerDeviceId,
  required int seed,
}) {
  final membership = commit.membership;
  final sourceKeyEpoch = switch (commit) {
    E2eeAccountRecoveryResumeCommit() => membership.expectedKeyEpoch - 1,
    E2eeAccountRecoveryReplacementCommit() => membership.expectedKeyEpoch,
  };
  final operationId = switch (commit) {
    E2eeAccountRecoveryResumeCommit(:final rekeyOperationId) =>
      rekeyOperationId,
    E2eeAccountRecoveryReplacementCommit() => membership.operationId,
  };
  return CloudSyncDataRekeyCompletion.fromJson(<String, Object?>{
    'proofVersion': 2,
    'operationId': operationId,
    'issuerDeviceId': issuerDeviceId,
    'sourceDataGeneration': membership.expectedGeneration,
    'targetDataGeneration': membership.expectedGeneration + 1,
    'sourceKeyEpoch': sourceKeyEpoch,
    'targetKeyEpoch': sourceKeyEpoch + 1,
    'sourceSnapshotRoot': _encodedBytes(32, seed),
    'sourceRecordCount': 0,
    'sourceAttachmentCount': 0,
    'sourceMaximumChangeSeq': 0,
    'sourceRecordCursorEnd': null,
    'sourceAttachmentCursorEnd': null,
    'membershipGeneration': membership.expectedGeneration + 1,
    'membershipManifestDigest': _encodedData(
      membership.nextMembershipManifestDigest.bytes,
    ),
    'stagedRecordCount': 0,
    'stagedAttachmentCount': 0,
    'stagedCiphertextSetDigest': _encodedBytes(32, seed + 1),
    'proofFrame': _encodedBytes(cloudSyncDataRekeyProofFrameBytes, seed + 2),
    'proofDigest': _encodedBytes(32, seed + 3),
    'signature': _encodedBytes(cloudSyncDeviceProofBytes, seed + 4),
    'finalizedAt': '2026-08-01T01:30:00.000Z',
  });
}

E2eeAccountRecoveryReplacementChallengeRequest _replacementChallengeRequest(
  E2eeAccountRecoveryFirstLocalActivatedProgress progress,
) {
  return E2eeAccountRecoveryReplacementChallengeRequest(
    challengeId: _uuid(8),
    expectedGeneration: progress.resumeReceipt.generation,
    expectedKeyEpoch: progress.resumeReceipt.keyEpoch,
    expectedMembershipManifestDigest:
        progress.completion.membershipManifestDigest,
    expectedMembershipOperationId: progress.resumeReceipt.membershipOperationId,
    dataGeneration: progress.completion.targetDataGeneration,
    dataKeyEpoch: progress.completion.targetKeyEpoch,
    sourceRekeyOperationId: progress.completion.operationId,
    sourceCompletionProofDigest: progress.completion.proofDigest,
  );
}

E2eeAccountRecoveryReplacementChallenge _replacementChallenge({
  required E2eeAccountRecoveryReplacementChallengeRequest request,
  required E2eeAccountRecoveryResumeCommit resumeCommit,
  required CloudSyncDataRekeyCompletion completion,
}) {
  final capsule = _bytes(cloudSyncRecoveryCapsuleMaximumBytes, 0xb7);
  return E2eeAccountRecoveryReplacementChallenge(
    result: E2eeAccountRecoveryReplacementChallengeResult.created,
    challengeId: request.challengeId,
    attemptId: resumeCommit.attemptId,
    requestDigest: _bytes(32, 0xb8),
    challengeFrame: _bytes(
      e2eeAccountRecoveryReplacementChallengeFrameBytes,
      0xb9,
    ),
    sealedNonce: _bytes(e2eeAccountRecoverySealedNonceBytes, 0xba),
    deviceKeyVersion: 1,
    deviceSigningPublicKey: _bytes(cloudSyncDevicePublicKeyBytes, 0xbb),
    deviceKeyAgreementPublicKey: _bytes(cloudSyncDevicePublicKeyBytes, 0xbc),
    securityGeneration: request.expectedGeneration,
    keyEpoch: request.expectedKeyEpoch,
    membershipManifest: resumeCommit.membership.nextMembershipManifest,
    membershipManifestDigest: request.expectedMembershipManifestDigest,
    membershipOperationId: request.expectedMembershipOperationId,
    recoveryPublicKeyVersion: 1,
    recoveryPublicKey: _bytes(cloudSyncRecoveryPublicKeyBytes, 0xbd),
    recoveryCapsuleVersion: 2,
    recoveryCapsule: capsule,
    recoveryCapsuleDigest: _digest(capsule),
    dataGeneration: request.dataGeneration,
    dataKeyEpoch: request.dataKeyEpoch,
    sourceRekeyOperationId: request.sourceRekeyOperationId,
    sourceCompletion: completion,
    expiresAt: DateTime.utc(2026, 8, 1, 2),
  );
}

E2eeAccountRecoveryReplacementCommit _replacementCommitForChallenge(
  E2eeAccountRecoveryReplacementChallenge challenge,
) {
  final manifest = _bytes(cloudSyncMembershipManifestMaximumBytes, 0xc4);
  return E2eeAccountRecoveryReplacementCommit(
    attemptId: challenge.attemptId,
    membership: E2eeAccountRecoveryMembershipCommit(
      expectedGeneration: challenge.securityGeneration,
      expectedKeyEpoch: challenge.keyEpoch,
      expectedMembershipManifestDigest:
          CloudSyncMembershipManifestDigest.fromBytes(
            challenge.membershipManifestDigest,
          ),
      operationId: _uuid(6),
      nextMembershipManifest: manifest,
      nextMembershipManifestDigest: CloudSyncMembershipManifestDigest.fromBytes(
        _digest(manifest),
      ),
      envelope: E2eeAccountRecoveryEnvelope(
        envelopeVersion: 1,
        keyEpoch: challenge.keyEpoch + 1,
        accountKeyEnvelope: _bytes(cloudSyncAccountKeyEnvelopeBytes, 0xc5),
      ),
    ),
    authorization:
        E2eeAccountRecoveryReplacementAuthorization.replacementChallenge(
          challengeId: challenge.challengeId,
          challengeRequestDigest: challenge.requestDigest,
          nonceProof: _bytes(e2eeAccountRecoveryNonceProofBytes, 0xc1),
          trustSignature: _bytes(e2eeAccountRecoveryTrustSignatureBytes, 0xc2),
        ),
    nextRecoveryCapsuleVersion: challenge.recoveryCapsuleVersion + 1,
    nextRecoveryCapsule: _bytes(cloudSyncRecoveryCapsuleMaximumBytes, 0xc6),
    completionSessionId: _uuid(7),
    completionSessionToken: _fullSessionToken(0xc7),
  );
}

String _encodedBytes(int length, int seed) =>
    _encodedData(_bytes(length, seed));

String _encodedData(Uint8List value) =>
    base64Url.encode(value).replaceAll('=', '');

E2eeAccountRecoveryLocalTransitionPlan _localTransitionPlan(
  int seed, {
  Uint8List? continuation,
  bool replacement = false,
  int sourceDataGeneration = 1,
}) {
  return E2eeAccountRecoveryLocalTransitionPlan(
    sourceStateBlob: _bytes(DeviceStateBlobStore.blobLength, seed),
    unprunedStateBlob: _bytes(DeviceStateBlobStore.blobLength, seed + 1),
    prunedStateBlob: _bytes(DeviceStateBlobStore.blobLength, seed + 2),
    deviceKeyVersion: 1,
    userId: _uuid(9),
    sourceDataGeneration: sourceDataGeneration,
    operationAuthorizationDigest: replacement
        ? Uint8List(cloudSyncMembershipManifestDigestBytes)
        : _bytes(cloudSyncMembershipManifestDigestBytes, seed + 3),
    continuation:
        continuation ??
        _bytes(e2eeAccountRecoveryNativeContinuationBytes, seed + 4),
  );
}

String _uuid(int value) {
  final digit = value.toRadixString(16);
  String repeated(int count) => List<String>.filled(count, digit).join();
  return '${repeated(8)}-${repeated(4)}-4${repeated(3)}-8${repeated(3)}-${repeated(12)}';
}
