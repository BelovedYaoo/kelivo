import 'dart:convert';
import 'dart:typed_data';

import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_recovery.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('完整拉取冻结历史后才由 Native 生成恢复授权证明', () async {
    final currentCapsule = _bytes(156, 0x51);
    final sourceCapsule = _bytes(156, 0x41);
    final firstManifest = _bytes(444, 0x11);
    final currentManifest = _bytes(444, 0x21);
    final challenge = E2eeAccountRecoveryChallenge(
      attemptId: _uuid(1),
      requestDigest: _bytes(32, 0x31),
      challengeFrame: _bytes(316, 0x32),
      sealedNonce: _bytes(100, 0x33),
      securityGeneration: 2,
      keyEpoch: 2,
      membershipManifestDigest: _digest(currentManifest),
      recoveryPublicKeyVersion: 1,
      recoveryPublicKey: _bytes(32, 0x34),
      recoveryCapsuleVersion: 2,
      recoveryCapsule: currentCapsule,
      recoveryCapsuleDigest: _digest(currentCapsule),
      dataState: E2eeAccountRecoveryDataState.rekeyPending(
        dataGeneration: 7,
        dataKeyEpoch: 1,
        operationId: _uuid(2),
        targetKeyEpoch: 2,
      ),
      expiresAt: DateTime.utc(2026, 8, 1, 1),
    );
    final currentProjection = CloudSyncAccountSecurityCurrentProjection(
      generation: 2,
      keyEpoch: 2,
      dataRekeyPhase: CloudSyncDataRekeyPhase.rekeyPending,
      membershipManifestDigest: CloudSyncMembershipManifestDigest.fromBytes(
        _digest(currentManifest),
      ),
      recoveryPublicKeyVersion: 1,
      recoveryPublicKey: challenge.recoveryPublicKey,
      recoveryCapsuleVersion: 2,
      updatedAt: DateTime.utc(2026, 8, 1),
    );
    final pages = <CloudSyncAccountSecurityHistoryPage>[
      _historyPage(
        afterGeneration: 0,
        item: _historyItem(
          generation: 1,
          keyEpoch: 1,
          manifest: firstManifest,
          capsule: sourceCapsule,
          operationId: _uuid(3),
        ),
        currentProjection: currentProjection,
      ),
      _historyPage(
        afterGeneration: 1,
        item: _historyItem(
          generation: 2,
          keyEpoch: 2,
          manifest: currentManifest,
          capsule: currentCapsule,
          operationId: _uuid(4),
        ),
        currentProjection: currentProjection,
      ),
    ];
    final callOrder = <String>[];
    final transport = _FakeRecoveryTransport(
      challenge: challenge,
      historyPages: pages,
      callOrder: callOrder,
    );
    final proofCore = _FakeRecoveryProofCore(callOrder);
    final checkpointPersistence = _MemoryCheckpointPersistence(callOrder);
    final authorizer = E2eeAccountRecoveryAuthorizer(
      transport: transport,
      proofCore: proofCore,
      checkpointPersistence: checkpointPersistence,
      serviceOriginSha256: _bytes(32, 0x61),
      attemptIdFactory: () => _uuid(1),
      recoveryTokenFactory: () => CloudSyncAccountRecoveryToken.parse(
        'kelivo_recovery_${base64Url.encode(_bytes(32, 0x71)).replaceAll('=', '')}',
      ),
      now: () => DateTime.utc(2026, 8, 1),
    );
    final passphrase = Uint8List.fromList(utf8.encode('correct horse battery'));

    final authorized = await authorizer.authorize(
      onboardingToken: CloudSyncOnboardingToken.parse(
        'kelivo_onboarding_${base64Url.encode(_bytes(32, 0x72)).replaceAll('=', '')}',
      ),
      expectedDeviceId: _uuid(5),
      recoveryMedia: _bytes(644, 0x73),
      recoveryPassphrase: passphrase,
    );

    expect(callOrder, <String>[
      'checkpoint:read',
      'challenge',
      'checkpoint:create',
      'history:0',
      'history:1',
      'native',
      'checkpoint:proofReady',
      'authorize',
      'checkpoint:authorized',
    ]);
    expect(proofCore.receivedHistory, <Uint8List>[
      firstManifest,
      currentManifest,
    ]);
    expect(proofCore.receivedCurrentCapsule, currentCapsule);
    expect(proofCore.receivedSourceCapsule, sourceCapsule);
    expect(proofCore.receivedExpectedDeviceId, _uuid(5));
    expect(transport.receivedNonceProof, _bytes(32, 0x81));
    expect(transport.receivedTrustSignature, _bytes(64, 0x82));
    expect(authorized.nextAction, E2eeAccountRecoveryNextAction.recoverResume);
    expect(authorized.keyLease.keyEpoch, 2);
    expect(passphrase, everyElement(0));
  });

  test('冻结历史投影与 challenge 不一致时不进入 Native', () async {
    final challengeManifest = _bytes(444, 0x11);
    final serverManifest = _bytes(444, 0x12);
    final capsule = _bytes(156, 0x41);
    final challenge = E2eeAccountRecoveryChallenge(
      attemptId: _uuid(1),
      requestDigest: _bytes(32, 0x31),
      challengeFrame: _bytes(316, 0x32),
      sealedNonce: _bytes(100, 0x33),
      securityGeneration: 1,
      keyEpoch: 1,
      membershipManifestDigest: _digest(challengeManifest),
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
    final serverProjection = CloudSyncAccountSecurityCurrentProjection(
      generation: 1,
      keyEpoch: 1,
      dataRekeyPhase: CloudSyncDataRekeyPhase.ready,
      membershipManifestDigest: CloudSyncMembershipManifestDigest.fromBytes(
        _digest(serverManifest),
      ),
      recoveryPublicKeyVersion: 1,
      recoveryPublicKey: challenge.recoveryPublicKey,
      recoveryCapsuleVersion: 1,
      updatedAt: DateTime.utc(2026, 8, 1),
    );
    final callOrder = <String>[];
    final transport = _FakeRecoveryTransport(
      challenge: challenge,
      historyPages: <CloudSyncAccountSecurityHistoryPage>[
        _historyPage(
          afterGeneration: 0,
          item: _historyItem(
            generation: 1,
            keyEpoch: 1,
            manifest: serverManifest,
            capsule: capsule,
            operationId: _uuid(2),
          ),
          currentProjection: serverProjection,
        ),
      ],
      callOrder: callOrder,
    );
    final proofCore = _FakeRecoveryProofCore(callOrder);
    final checkpointPersistence = _MemoryCheckpointPersistence(callOrder);
    final passphrase = Uint8List.fromList(utf8.encode('correct horse battery'));
    final authorizer = E2eeAccountRecoveryAuthorizer(
      transport: transport,
      proofCore: proofCore,
      checkpointPersistence: checkpointPersistence,
      serviceOriginSha256: _bytes(32, 0x61),
      attemptIdFactory: () => _uuid(1),
      recoveryTokenFactory: () => CloudSyncAccountRecoveryToken.generate(),
      now: () => DateTime.utc(2026, 8, 1),
    );

    await expectLater(
      authorizer.authorize(
        onboardingToken: CloudSyncOnboardingToken.parse(
          'kelivo_onboarding_${base64Url.encode(_bytes(32, 0x72)).replaceAll('=', '')}',
        ),
        expectedDeviceId: _uuid(5),
        recoveryMedia: _bytes(644, 0x73),
        recoveryPassphrase: passphrase,
      ),
      throwsA(isA<FormatException>()),
    );

    expect(callOrder, <String>[
      'checkpoint:read',
      'challenge',
      'checkpoint:create',
      'history:0',
    ]);
    expect(proofCore.receivedHistory, isNull);
    expect(passphrase, everyElement(0));
  });

  test('proofReady 重启时复用恢复令牌与 proof 重放授权', () async {
    final fixture = _readyRecoveryFixture();
    final callOrder = <String>[];
    final recoveryToken = CloudSyncAccountRecoveryToken.parse(
      'kelivo_recovery_${base64Url.encode(_bytes(32, 0x71)).replaceAll('=', '')}',
    );
    final proofReady = E2eeAccountRecoveryCheckpoint.challenged(
      expectedDeviceId: _uuid(5),
      recoveryToken: recoveryToken,
      challenge: fixture.challenge,
    ).withProof(nonceProof: _bytes(32, 0x81), trustSignature: _bytes(64, 0x82));
    final checkpointPersistence = _MemoryCheckpointPersistence(
      callOrder,
      initialCheckpoint: proofReady,
    );
    final transport = _FakeRecoveryTransport(
      challenge: fixture.challenge,
      historyPages: <CloudSyncAccountSecurityHistoryPage>[fixture.historyPage],
      callOrder: callOrder,
    );
    final proofCore = _FakeRecoveryProofCore(callOrder);
    final authorizer = E2eeAccountRecoveryAuthorizer(
      transport: transport,
      proofCore: proofCore,
      checkpointPersistence: checkpointPersistence,
      serviceOriginSha256: _bytes(32, 0x61),
      attemptIdFactory: () => throw StateError('不应创建新 attempt'),
      recoveryTokenFactory: () => throw StateError('不应创建新恢复令牌'),
      now: () => DateTime.utc(2026, 8, 1),
    );
    final passphrase = Uint8List.fromList(utf8.encode('correct horse battery'));

    final authorized = await authorizer.authorize(
      onboardingToken: CloudSyncOnboardingToken.parse(
        'kelivo_onboarding_${base64Url.encode(_bytes(32, 0x72)).replaceAll('=', '')}',
      ),
      expectedDeviceId: _uuid(5),
      recoveryMedia: _bytes(644, 0x73),
      recoveryPassphrase: passphrase,
    );

    expect(callOrder, <String>[
      'checkpoint:read',
      'state',
      'history:0',
      'native',
      'authorize',
      'checkpoint:authorized',
    ]);
    expect(transport.receivedRecoveryToken?.value, recoveryToken.value);
    expect(authorized.recoveryToken.value, recoveryToken.value);
    expect(
      checkpointPersistence.current?.stage,
      E2eeAccountRecoveryStage.authorized,
    );
    expect(passphrase, everyElement(0));
  });

  test('proofReady 与 Native 重算结果不一致时失败关闭 key lease', () async {
    final fixture = _readyRecoveryFixture();
    final callOrder = <String>[];
    final proofReady = E2eeAccountRecoveryCheckpoint.challenged(
      expectedDeviceId: _uuid(5),
      recoveryToken: CloudSyncAccountRecoveryToken.generate(),
      challenge: fixture.challenge,
    ).withProof(nonceProof: _bytes(32, 0x83), trustSignature: _bytes(64, 0x82));
    final checkpointPersistence = _MemoryCheckpointPersistence(
      callOrder,
      initialCheckpoint: proofReady,
    );
    final transport = _FakeRecoveryTransport(
      challenge: fixture.challenge,
      historyPages: <CloudSyncAccountSecurityHistoryPage>[fixture.historyPage],
      callOrder: callOrder,
    );
    final proofCore = _FakeRecoveryProofCore(callOrder);
    final passphrase = Uint8List.fromList(utf8.encode('correct horse battery'));
    final authorizer = E2eeAccountRecoveryAuthorizer(
      transport: transport,
      proofCore: proofCore,
      checkpointPersistence: checkpointPersistence,
      serviceOriginSha256: _bytes(32, 0x61),
      attemptIdFactory: () => throw StateError('不应创建新 attempt'),
      recoveryTokenFactory: () => throw StateError('不应创建新恢复令牌'),
      now: () => DateTime.utc(2026, 8, 1),
    );

    await expectLater(
      authorizer.authorize(
        onboardingToken: CloudSyncOnboardingToken.parse(
          'kelivo_onboarding_${base64Url.encode(_bytes(32, 0x72)).replaceAll('=', '')}',
        ),
        expectedDeviceId: _uuid(5),
        recoveryMedia: _bytes(644, 0x73),
        recoveryPassphrase: passphrase,
      ),
      throwsA(isA<FormatException>()),
    );

    expect(callOrder, <String>[
      'checkpoint:read',
      'state',
      'history:0',
      'native',
    ]);
    expect(proofCore.lastLease?.closed, isTrue);
    expect(
      checkpointPersistence.current?.stage,
      E2eeAccountRecoveryStage.proofReady,
    );
    expect(passphrase, everyElement(0));
  });

  test('proofReady 重启发现服务端已授权时改用恢复 bearer', () async {
    final fixture = _readyRecoveryFixture();
    final callOrder = <String>[];
    final recoveryToken = CloudSyncAccountRecoveryToken.generate();
    final proofReady = E2eeAccountRecoveryCheckpoint.challenged(
      expectedDeviceId: _uuid(5),
      recoveryToken: recoveryToken,
      challenge: fixture.challenge,
    ).withProof(nonceProof: _bytes(32, 0x81), trustSignature: _bytes(64, 0x82));
    final checkpointPersistence = _MemoryCheckpointPersistence(
      callOrder,
      initialCheckpoint: proofReady,
    );
    final transport = _FakeRecoveryTransport(
      challenge: fixture.challenge,
      historyPages: <CloudSyncAccountSecurityHistoryPage>[fixture.historyPage],
      callOrder: callOrder,
      authorizedState: E2eeAccountRecoveryAuthorizedState(
        attemptId: fixture.challenge.attemptId,
        authorizedAt: DateTime.utc(2026, 8, 1),
        recoveryTokenExpiresAt: DateTime.utc(2026, 8, 1, 2),
        nextAction: E2eeAccountRecoveryNextAction.recoverReplace,
        securityState: _securityStateForFixture(fixture),
        dataState: fixture.challenge.dataState,
      ),
    );
    final proofCore = _FakeRecoveryProofCore(callOrder);
    final authorizer = E2eeAccountRecoveryAuthorizer(
      transport: transport,
      proofCore: proofCore,
      checkpointPersistence: checkpointPersistence,
      serviceOriginSha256: _bytes(32, 0x61),
      attemptIdFactory: () => throw StateError('不应创建新 attempt'),
      recoveryTokenFactory: () => throw StateError('不应创建新恢复令牌'),
      now: () => DateTime.utc(2026, 8, 1),
    );

    final authorized = await authorizer.authorize(
      onboardingToken: CloudSyncOnboardingToken.parse(
        'kelivo_onboarding_${base64Url.encode(_bytes(32, 0x72)).replaceAll('=', '')}',
      ),
      expectedDeviceId: _uuid(5),
      recoveryMedia: _bytes(644, 0x73),
      recoveryPassphrase: Uint8List.fromList(
        utf8.encode('correct horse battery'),
      ),
    );

    expect(callOrder, <String>[
      'checkpoint:read',
      'state',
      'checkpoint:authorized',
      'history:0',
      'native',
    ]);
    expect(transport.receivedHistoryBearer, recoveryToken.value);
    expect(transport.receivedRecoveryToken, isNull);
    expect(authorized.recoveryToken.value, recoveryToken.value);
    expect(
      checkpointPersistence.current?.stage,
      E2eeAccountRecoveryStage.authorized,
    );
  });
}

({
  E2eeAccountRecoveryChallenge challenge,
  CloudSyncAccountSecurityHistoryPage historyPage,
})
_readyRecoveryFixture() {
  final manifest = _bytes(444, 0x21);
  final capsule = _bytes(156, 0x51);
  final challenge = E2eeAccountRecoveryChallenge(
    attemptId: _uuid(1),
    requestDigest: _bytes(32, 0x31),
    challengeFrame: _bytes(316, 0x32),
    sealedNonce: _bytes(100, 0x33),
    securityGeneration: 1,
    keyEpoch: 2,
    membershipManifestDigest: _digest(manifest),
    recoveryPublicKeyVersion: 1,
    recoveryPublicKey: _bytes(32, 0x34),
    recoveryCapsuleVersion: 1,
    recoveryCapsule: capsule,
    recoveryCapsuleDigest: _digest(capsule),
    dataState: E2eeAccountRecoveryDataState.ready(
      dataGeneration: 7,
      dataKeyEpoch: 2,
    ),
    expiresAt: DateTime.utc(2026, 8, 1, 1),
  );
  final projection = CloudSyncAccountSecurityCurrentProjection(
    generation: 1,
    keyEpoch: 2,
    dataRekeyPhase: CloudSyncDataRekeyPhase.ready,
    membershipManifestDigest: CloudSyncMembershipManifestDigest.fromBytes(
      _digest(manifest),
    ),
    recoveryPublicKeyVersion: 1,
    recoveryPublicKey: challenge.recoveryPublicKey,
    recoveryCapsuleVersion: 1,
    updatedAt: DateTime.utc(2026, 8, 1),
  );
  return (
    challenge: challenge,
    historyPage: _historyPage(
      afterGeneration: 0,
      item: _historyItem(
        generation: 1,
        keyEpoch: 2,
        manifest: manifest,
        capsule: capsule,
        operationId: _uuid(2),
      ),
      currentProjection: projection,
    ),
  );
}

CloudSyncAccountSecurityState _securityStateForFixture(
  ({
    E2eeAccountRecoveryChallenge challenge,
    CloudSyncAccountSecurityHistoryPage historyPage,
  })
  fixture,
) {
  final head = fixture.historyPage.items.single;
  return CloudSyncAccountSecurityState(
    generation: head.generation,
    keyEpoch: head.keyEpoch,
    dataRekeyPhase: CloudSyncDataRekeyPhase.ready,
    membershipManifest: head.membershipManifest,
    membershipManifestDigest: head.membershipManifestDigest,
    recoveryPublicKeyVersion: head.recoveryPublicKeyVersion,
    recoveryPublicKey: head.recoveryPublicKey,
    recoveryCapsuleVersion: head.recoveryCapsuleVersion,
    recoveryCapsule: head.recoveryCapsule,
    lastOperationId: head.operationId,
    updatedAt: head.committedAt,
    envelopes: <CloudSyncAccountSecurityEnvelope>[
      CloudSyncAccountSecurityEnvelope(
        targetDeviceId: _uuid(5),
        issuerDeviceId: _uuid(6),
        envelopeVersion: 1,
        keyEpoch: head.keyEpoch,
        accountKeyEnvelope: _bytes(cloudSyncAccountKeyEnvelopeBytes, 0x84),
      ),
    ],
  );
}

CloudSyncAccountSecurityHistoryPage _historyPage({
  required int afterGeneration,
  required CloudSyncAccountSecurityHistoryItem item,
  required CloudSyncAccountSecurityCurrentProjection currentProjection,
}) {
  return CloudSyncAccountSecurityHistoryPage(
    items: <CloudSyncAccountSecurityHistoryItem>[item],
    afterGeneration: afterGeneration,
    nextAfterGeneration: item.generation,
    pageSize: 1,
    hasMore: item.generation < currentProjection.generation,
    currentState: currentProjection,
  );
}

CloudSyncAccountSecurityHistoryItem _historyItem({
  required int generation,
  required int keyEpoch,
  required Uint8List manifest,
  required Uint8List capsule,
  required String operationId,
}) {
  return CloudSyncAccountSecurityHistoryItem(
    generation: generation,
    keyEpoch: keyEpoch,
    membershipManifest: manifest,
    membershipManifestDigest: CloudSyncMembershipManifestDigest.fromBytes(
      _digest(manifest),
    ),
    recoveryPublicKeyVersion: 1,
    recoveryPublicKey: _bytes(32, 0x34),
    recoveryCapsuleVersion: generation,
    recoveryCapsule: capsule,
    operationId: operationId,
    committedAt: DateTime.utc(2026, 8, 1),
  );
}

final class _FakeRecoveryTransport implements E2eeAccountRecoveryTransport {
  _FakeRecoveryTransport({
    required this.challenge,
    required this.historyPages,
    required this.callOrder,
    this.authorizedState,
  });

  final E2eeAccountRecoveryChallenge challenge;
  final List<CloudSyncAccountSecurityHistoryPage> historyPages;
  final List<String> callOrder;
  final E2eeAccountRecoveryAuthorizedState? authorizedState;
  Uint8List? receivedNonceProof;
  Uint8List? receivedTrustSignature;
  CloudSyncAccountRecoveryToken? receivedRecoveryToken;
  String? receivedHistoryBearer;

  @override
  Future<E2eeAccountRecoveryAuthorizedState> getAuthorizedState({
    required CloudSyncAccountRecoveryToken recoveryToken,
  }) async {
    callOrder.add('state');
    final state = authorizedState;
    if (state == null) {
      throw const E2eeAccountRecoveryTokenUnavailable();
    }
    return state;
  }

  @override
  Future<E2eeAccountRecoveryChallenge> createChallenge({
    required CloudSyncOnboardingToken onboardingToken,
    required String attemptId,
  }) async {
    callOrder.add('challenge');
    return challenge;
  }

  @override
  Future<CloudSyncAccountSecurityHistoryPage> listFrozenHistory({
    required E2eeAccountRecoveryBearer authorization,
    required String attemptId,
    required Uint8List challengeRequestDigest,
    required int afterGeneration,
    required int pageSize,
  }) async {
    callOrder.add('history:$afterGeneration');
    receivedHistoryBearer = authorization.value;
    return historyPages.removeAt(0);
  }

  @override
  Future<E2eeAccountRecoveryAuthorizationReceipt> authorize({
    required E2eeAccountRecoveryBearer authorization,
    required String attemptId,
    required Uint8List challengeRequestDigest,
    required CloudSyncAccountRecoveryToken recoveryToken,
    required Uint8List nonceProof,
    required Uint8List trustSignature,
  }) async {
    callOrder.add('authorize');
    receivedRecoveryToken = recoveryToken;
    receivedNonceProof = Uint8List.fromList(nonceProof);
    receivedTrustSignature = Uint8List.fromList(trustSignature);
    return E2eeAccountRecoveryAuthorizationReceipt(
      attemptId: attemptId,
      result: E2eeAccountRecoveryAuthorizationResult.authorized,
      nextAction: E2eeAccountRecoveryNextAction.recoverResume,
      recoveryTokenExpiresAt: DateTime.utc(2026, 8, 1, 2),
    );
  }
}

final class _FakeRecoveryProofCore implements E2eeAccountRecoveryProofCore {
  _FakeRecoveryProofCore(this.callOrder);

  final List<String> callOrder;
  List<Uint8List>? receivedHistory;
  Uint8List? receivedCurrentCapsule;
  Uint8List? receivedSourceCapsule;
  String? receivedExpectedDeviceId;
  _FakeRecoveryKeyLease? lastLease;

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
    callOrder.add('native');
    receivedHistory = membershipHistory.map(Uint8List.fromList).toList();
    receivedCurrentCapsule = Uint8List.fromList(currentCapsule);
    receivedSourceCapsule = sourceCapsule == null
        ? null
        : Uint8List.fromList(sourceCapsule);
    receivedExpectedDeviceId = expectedDeviceId;
    recoveryPassphrase.fillRange(0, recoveryPassphrase.length, 0);
    final lease = _FakeRecoveryKeyLease(2);
    lastLease = lease;
    return E2eeAccountRecoveryProof(
      keyLease: lease,
      nonceProof: _bytes(32, 0x81),
      trustSignature: _bytes(64, 0x82),
    );
  }
}

final class _FakeRecoveryKeyLease implements E2eeAccountRecoveryKeyLease {
  _FakeRecoveryKeyLease(this.keyEpoch);

  @override
  final int keyEpoch;

  bool closed = false;

  @override
  Future<void> close() async {
    closed = true;
  }
}

final class _MemoryCheckpointPersistence
    implements E2eeAccountRecoveryCheckpointPersistence {
  _MemoryCheckpointPersistence(
    this.callOrder, {
    E2eeAccountRecoveryCheckpoint? initialCheckpoint,
  }) : _snapshot = initialCheckpoint == null
           ? null
           : E2eeAccountRecoveryCheckpointSnapshot(
               checkpoint: initialCheckpoint,
               envelopeDigest: _bytes(32, 0x90),
             );

  final List<String> callOrder;
  E2eeAccountRecoveryCheckpointSnapshot? _snapshot;

  E2eeAccountRecoveryCheckpoint? get current => _snapshot?.checkpoint;

  @override
  Future<E2eeAccountRecoveryCheckpointSnapshot?> read() async {
    callOrder.add('checkpoint:read');
    return _snapshot;
  }

  @override
  Future<E2eeAccountRecoveryCheckpointSnapshot> create(
    E2eeAccountRecoveryCheckpoint checkpoint,
  ) async {
    callOrder.add('checkpoint:create');
    final snapshot = E2eeAccountRecoveryCheckpointSnapshot(
      checkpoint: checkpoint,
      envelopeDigest: _bytes(32, 0x91),
    );
    _snapshot = snapshot;
    return snapshot;
  }

  @override
  Future<E2eeAccountRecoveryCheckpointSnapshot> advance({
    required Uint8List expectedEnvelopeDigest,
    required E2eeAccountRecoveryCheckpoint checkpoint,
  }) async {
    callOrder.add('checkpoint:${checkpoint.stage.name}');
    final snapshot = E2eeAccountRecoveryCheckpointSnapshot(
      checkpoint: checkpoint,
      envelopeDigest: _bytes(
        32,
        checkpoint.stage == E2eeAccountRecoveryStage.proofReady ? 0x92 : 0x93,
      ),
    );
    _snapshot = snapshot;
    return snapshot;
  }

  @override
  Future<bool> delete(E2eeAccountRecoveryCheckpointSnapshot snapshot) async {
    _snapshot = null;
    return true;
  }
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
