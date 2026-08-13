import 'dart:convert';
import 'dart:typed_data';

import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_recovery.dart';
import 'package:Kelivo/core/services/workspace/device_state_blob_store.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('完整拉取冻结历史后才由 Native 生成恢复授权证明', () async {
    final currentCapsule = _bytes(156, 0x51);
    final sourceCapsule = _bytes(156, 0x41);
    final firstManifest = _bytes(476, 0x11);
    final currentManifest = _bytes(476, 0x21);
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
      recoveryMedia: _bytes(676, 0x73),
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

  test('已轮换且数据就绪时仍向 Native 提供最近轮换前驱 capsule', () async {
    final sourceCapsule = _bytes(156, 0x41);
    final currentCapsule = _bytes(156, 0x51);
    final sourceManifest = _bytes(476, 0x11);
    final currentManifest = _bytes(476, 0x21);
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
      dataState: E2eeAccountRecoveryDataState.ready(
        dataGeneration: 8,
        dataKeyEpoch: 2,
      ),
      expiresAt: DateTime.utc(2026, 8, 1, 1),
    );
    final projection = CloudSyncAccountSecurityCurrentProjection(
      generation: 2,
      keyEpoch: 2,
      dataRekeyPhase: CloudSyncDataRekeyPhase.ready,
      membershipManifestDigest: CloudSyncMembershipManifestDigest.fromBytes(
        _digest(currentManifest),
      ),
      recoveryPublicKeyVersion: 1,
      recoveryPublicKey: challenge.recoveryPublicKey,
      recoveryCapsuleVersion: 2,
      updatedAt: DateTime.utc(2026, 8, 1),
    );
    final callOrder = <String>[];
    final proofCore = _FakeRecoveryProofCore(callOrder);
    final authorizer = E2eeAccountRecoveryAuthorizer(
      transport: _FakeRecoveryTransport(
        challenge: challenge,
        historyPages: <CloudSyncAccountSecurityHistoryPage>[
          _historyPage(
            afterGeneration: 0,
            item: _historyItem(
              generation: 1,
              keyEpoch: 1,
              manifest: sourceManifest,
              capsule: sourceCapsule,
              operationId: _uuid(2),
            ),
            currentProjection: projection,
          ),
          _historyPage(
            afterGeneration: 1,
            item: _historyItem(
              generation: 2,
              keyEpoch: 2,
              manifest: currentManifest,
              capsule: currentCapsule,
              operationId: _uuid(3),
            ),
            currentProjection: projection,
          ),
        ],
        callOrder: callOrder,
      ),
      proofCore: proofCore,
      checkpointPersistence: _MemoryCheckpointPersistence(callOrder),
      serviceOriginSha256: _bytes(32, 0x61),
      attemptIdFactory: () => _uuid(1),
      recoveryTokenFactory: CloudSyncAccountRecoveryToken.generate,
      now: () => DateTime.utc(2026, 8, 1),
    );

    final authorized = await authorizer.authorize(
      onboardingToken: CloudSyncOnboardingToken.parse(
        'kelivo_onboarding_${base64Url.encode(_bytes(32, 0x72)).replaceAll('=', '')}',
      ),
      expectedDeviceId: _uuid(5),
      recoveryMedia: _bytes(676, 0x73),
      recoveryPassphrase: Uint8List.fromList(
        utf8.encode('correct horse battery'),
      ),
    );

    expect(proofCore.receivedCurrentCapsule, currentCapsule);
    expect(proofCore.receivedSourceCapsule, sourceCapsule);
    expect(authorized.nextAction, E2eeAccountRecoveryNextAction.recoverReplace);
    await authorized.keyLease.close();
  });

  test('已轮换历史缺少相邻前驱时不进入 Native', () async {
    final fixture = _rotatedReadyFixture(<CloudSyncAccountSecurityHistoryItem>[
      _historyItem(
        generation: 1,
        keyEpoch: 2,
        manifest: _bytes(476, 0x21),
        capsule: _bytes(156, 0x51),
        capsuleVersion: 2,
        operationId: _uuid(2),
      ),
    ]);

    await expectLater(
      fixture.authorize(),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          '账户恢复历史缺少轮换前驱 capsule',
        ),
      ),
    );

    expect(fixture.callOrder, isNot(contains('native')));
  });

  test('已轮换历史存在多个相邻前驱时不进入 Native', () async {
    final fixture = _rotatedReadyFixture(<CloudSyncAccountSecurityHistoryItem>[
      _historyItem(
        generation: 1,
        keyEpoch: 1,
        manifest: _bytes(476, 0x11),
        capsule: _bytes(156, 0x41),
        capsuleVersion: 1,
        operationId: _uuid(2),
      ),
      _historyItem(
        generation: 2,
        keyEpoch: 2,
        manifest: _bytes(476, 0x21),
        capsule: _bytes(156, 0x51),
        capsuleVersion: 2,
        operationId: _uuid(3),
      ),
      _historyItem(
        generation: 3,
        keyEpoch: 1,
        manifest: _bytes(476, 0x31),
        capsule: _bytes(156, 0x41),
        capsuleVersion: 1,
        operationId: _uuid(4),
      ),
      _historyItem(
        generation: 4,
        keyEpoch: 2,
        manifest: _bytes(476, 0x41),
        capsule: _bytes(156, 0x51),
        capsuleVersion: 2,
        operationId: _uuid(5),
      ),
    ]);

    await expectLater(
      fixture.authorize(),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          '账户恢复历史存在多个轮换前驱',
        ),
      ),
    );

    expect(fixture.callOrder, isNot(contains('native')));
  });

  test('已轮换历史的前驱 capsule 绑定错误时不进入 Native', () async {
    final fixture = _rotatedReadyFixture(<CloudSyncAccountSecurityHistoryItem>[
      _historyItem(
        generation: 1,
        keyEpoch: 1,
        manifest: _bytes(476, 0x11),
        capsule: _bytes(156, 0x41),
        capsuleVersion: 7,
        operationId: _uuid(2),
      ),
      _historyItem(
        generation: 2,
        keyEpoch: 2,
        manifest: _bytes(476, 0x21),
        capsule: _bytes(156, 0x51),
        capsuleVersion: 2,
        operationId: _uuid(3),
      ),
    ]);

    await expectLater(
      fixture.authorize(),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          '账户恢复轮换前驱 capsule 绑定无效',
        ),
      ),
    );

    expect(fixture.callOrder, isNot(contains('native')));
  });

  test('冻结历史投影与 challenge 不一致时不进入 Native', () async {
    final challengeManifest = _bytes(476, 0x11);
    final serverManifest = _bytes(476, 0x12);
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
        recoveryMedia: _bytes(676, 0x73),
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
      recoveryMedia: _bytes(676, 0x73),
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
      checkpointPersistence.current?.phase,
      E2eeAccountRecoveryCheckpointPhase.authorized,
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
        recoveryMedia: _bytes(676, 0x73),
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
      checkpointPersistence.current?.phase,
      E2eeAccountRecoveryCheckpointPhase.proofReady,
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
        status: E2eeAccountRecoveryRemoteStatus.authorized,
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
      recoveryMedia: _bytes(676, 0x73),
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
      checkpointPersistence.current?.phase,
      E2eeAccountRecoveryCheckpointPhase.authorized,
    );
  });

  test('proofReady 服务端授权已过期时删除旧事务并重新授权', () async {
    final fixture = _readyRecoveryFixture();
    final callOrder = <String>[];
    final oldRecoveryToken = CloudSyncAccountRecoveryToken.generate();
    final newRecoveryToken = CloudSyncAccountRecoveryToken.parse(
      'kelivo_recovery_${base64Url.encode(_bytes(32, 0x75)).replaceAll('=', '')}',
    );
    final checkpointPersistence = _MemoryCheckpointPersistence(
      callOrder,
      initialCheckpoint:
          E2eeAccountRecoveryCheckpoint.challenged(
            expectedDeviceId: _uuid(5),
            recoveryToken: oldRecoveryToken,
            challenge: fixture.challenge,
          ).withProof(
            nonceProof: _bytes(32, 0x81),
            trustSignature: _bytes(64, 0x82),
          ),
    );
    final transport = _FakeRecoveryTransport(
      challenge: fixture.challenge,
      historyPages: <CloudSyncAccountSecurityHistoryPage>[fixture.historyPage],
      callOrder: callOrder,
      authorizedState: E2eeAccountRecoveryAuthorizedState(
        attemptId: fixture.challenge.attemptId,
        authorizedAt: DateTime.utc(2026, 8, 1),
        recoveryTokenExpiresAt: DateTime.utc(2026, 8, 1, 0, 20),
        status: E2eeAccountRecoveryRemoteStatus.authorized,
        nextAction: E2eeAccountRecoveryNextAction.recoverReplace,
        securityState: _securityStateForFixture(fixture),
        dataState: fixture.challenge.dataState,
      ),
    );
    final passphrase = Uint8List.fromList(utf8.encode('correct horse battery'));
    final authorizer = E2eeAccountRecoveryAuthorizer(
      transport: transport,
      proofCore: _FakeRecoveryProofCore(callOrder),
      checkpointPersistence: checkpointPersistence,
      serviceOriginSha256: _bytes(32, 0x61),
      attemptIdFactory: () => fixture.challenge.attemptId,
      recoveryTokenFactory: () => newRecoveryToken,
      now: () => DateTime.utc(2026, 8, 1, 0, 30),
    );

    final authorized = await authorizer.authorize(
      onboardingToken: CloudSyncOnboardingToken.parse(
        'kelivo_onboarding_${base64Url.encode(_bytes(32, 0x72)).replaceAll('=', '')}',
      ),
      expectedDeviceId: _uuid(5),
      recoveryMedia: _bytes(676, 0x73),
      recoveryPassphrase: passphrase,
    );

    expect(callOrder, <String>[
      'checkpoint:read',
      'state',
      'checkpoint:delete',
      'challenge',
      'checkpoint:create',
      'history:0',
      'native',
      'checkpoint:proofReady',
      'authorize',
      'checkpoint:authorized',
    ]);
    expect(transport.receivedRecoveryToken?.value, newRecoveryToken.value);
    expect(authorized.recoveryToken.value, newRecoveryToken.value);
    expect(
      checkpointPersistence.current?.recoveryToken.value,
      newRecoveryToken.value,
    );
    expect(passphrase, everyElement(0));
  });

  test('过期 proofReady 发现服务端有效授权时保留事务再拒绝设备不一致', () async {
    final fixture = _readyRecoveryFixture();
    final callOrder = <String>[];
    final proofReady = _expiredPreTransitionCheckpoint(
      fixture.challenge,
      E2eeAccountRecoveryCheckpointPhase.proofReady,
      expectedDeviceId: _uuid(6),
    );
    final checkpointPersistence = _MemoryCheckpointPersistence(
      callOrder,
      initialCheckpoint: proofReady,
    );
    final authorizedFixture = (
      challenge: proofReady.challenge,
      historyPage: fixture.historyPage,
    );
    final passphrase = Uint8List.fromList(utf8.encode('correct horse battery'));
    final authorizer = E2eeAccountRecoveryAuthorizer(
      transport: _FakeRecoveryTransport(
        challenge: fixture.challenge,
        historyPages: <CloudSyncAccountSecurityHistoryPage>[
          fixture.historyPage,
        ],
        callOrder: callOrder,
        authorizedState: E2eeAccountRecoveryAuthorizedState(
          attemptId: proofReady.attemptId,
          authorizedAt: DateTime.utc(2026, 8, 1),
          recoveryTokenExpiresAt: DateTime.utc(2026, 8, 1, 2),
          status: E2eeAccountRecoveryRemoteStatus.authorized,
          nextAction: E2eeAccountRecoveryNextAction.recoverReplace,
          securityState: _securityStateForFixture(authorizedFixture),
          dataState: proofReady.challenge.dataState,
        ),
      ),
      proofCore: _FakeRecoveryProofCore(callOrder),
      checkpointPersistence: checkpointPersistence,
      serviceOriginSha256: _bytes(32, 0x61),
      attemptIdFactory: () => throw StateError('已授权事务不得创建新 attempt'),
      recoveryTokenFactory: () => throw StateError('已授权事务不得创建新恢复令牌'),
      now: () => DateTime.utc(2026, 8, 1, 0, 30),
    );

    await expectLater(
      authorizer.authorize(
        onboardingToken: CloudSyncOnboardingToken.parse(
          'kelivo_onboarding_${base64Url.encode(_bytes(32, 0x72)).replaceAll('=', '')}',
        ),
        expectedDeviceId: _uuid(5),
        recoveryMedia: _bytes(676, 0x73),
        recoveryPassphrase: passphrase,
      ),
      throwsFormatException,
    );

    expect(callOrder, <String>[
      'checkpoint:read',
      'state',
      'checkpoint:authorized',
    ]);
    expect(
      checkpointPersistence.current?.phase,
      E2eeAccountRecoveryCheckpointPhase.authorized,
    );
    expect(checkpointPersistence.current?.expectedDeviceId, _uuid(6));
    expect(passphrase, everyElement(0));
  });

  for (final phase in <E2eeAccountRecoveryCheckpointPhase>[
    E2eeAccountRecoveryCheckpointPhase.challenged,
    E2eeAccountRecoveryCheckpointPhase.proofReady,
    E2eeAccountRecoveryCheckpointPhase.authorized,
  ]) {
    test('授权前 ${phase.name} checkpoint 过期时删除旧事务并重新授权', () async {
      final fixture = _readyRecoveryFixture();
      final callOrder = <String>[];
      final checkpointPersistence = _MemoryCheckpointPersistence(
        callOrder,
        initialCheckpoint: _expiredPreTransitionCheckpoint(
          fixture.challenge,
          phase,
          expectedDeviceId: _uuid(6),
        ),
      );
      final transport = _FakeRecoveryTransport(
        challenge: fixture.challenge,
        historyPages: <CloudSyncAccountSecurityHistoryPage>[
          fixture.historyPage,
        ],
        callOrder: callOrder,
      );
      final authorizer = E2eeAccountRecoveryAuthorizer(
        transport: transport,
        proofCore: _FakeRecoveryProofCore(callOrder),
        checkpointPersistence: checkpointPersistence,
        serviceOriginSha256: _bytes(32, 0x61),
        attemptIdFactory: () => fixture.challenge.attemptId,
        recoveryTokenFactory: () => CloudSyncAccountRecoveryToken.parse(
          'kelivo_recovery_${base64Url.encode(_bytes(32, 0x75)).replaceAll('=', '')}',
        ),
        now: () => DateTime.utc(2026, 8, 1, 0, 30),
      );

      final authorized = await authorizer.authorize(
        onboardingToken: CloudSyncOnboardingToken.parse(
          'kelivo_onboarding_${base64Url.encode(_bytes(32, 0x72)).replaceAll('=', '')}',
        ),
        expectedDeviceId: _uuid(5),
        recoveryMedia: _bytes(676, 0x73),
        recoveryPassphrase: Uint8List.fromList(
          utf8.encode('correct horse battery'),
        ),
      );

      expect(callOrder, <String>[
        'checkpoint:read',
        if (phase == E2eeAccountRecoveryCheckpointPhase.proofReady) 'state',
        'checkpoint:delete',
        'challenge',
        'checkpoint:create',
        'history:0',
        'native',
        'checkpoint:proofReady',
        'authorize',
        'checkpoint:authorized',
      ]);
      expect(authorized.attemptId, fixture.challenge.attemptId);
      expect(
        checkpointPersistence.current?.attemptId,
        fixture.challenge.attemptId,
      );
      expect(
        checkpointPersistence.current?.phase,
        E2eeAccountRecoveryCheckpointPhase.authorized,
      );
    });
  }

  test('未过期 checkpoint 目标设备不一致时不触网也不删除', () async {
    final fixture = _readyRecoveryFixture();
    final callOrder = <String>[];
    final checkpointPersistence = _MemoryCheckpointPersistence(
      callOrder,
      initialCheckpoint:
          E2eeAccountRecoveryCheckpoint.challenged(
            expectedDeviceId: _uuid(6),
            recoveryToken: CloudSyncAccountRecoveryToken.generate(),
            challenge: fixture.challenge,
          ).withProof(
            nonceProof: _bytes(32, 0x81),
            trustSignature: _bytes(64, 0x82),
          ),
    );
    final passphrase = Uint8List.fromList(utf8.encode('correct horse battery'));
    final authorizer = E2eeAccountRecoveryAuthorizer(
      transport: _FakeRecoveryTransport(
        challenge: fixture.challenge,
        historyPages: <CloudSyncAccountSecurityHistoryPage>[
          fixture.historyPage,
        ],
        callOrder: callOrder,
      ),
      proofCore: _FakeRecoveryProofCore(callOrder),
      checkpointPersistence: checkpointPersistence,
      serviceOriginSha256: _bytes(32, 0x61),
      attemptIdFactory: () => throw StateError('设备不一致时不应创建新 attempt'),
      recoveryTokenFactory: () => throw StateError('设备不一致时不应创建新恢复令牌'),
      now: () => DateTime.utc(2026, 8, 1, 0, 30),
    );

    await expectLater(
      authorizer.authorize(
        onboardingToken: CloudSyncOnboardingToken.parse(
          'kelivo_onboarding_${base64Url.encode(_bytes(32, 0x72)).replaceAll('=', '')}',
        ),
        expectedDeviceId: _uuid(5),
        recoveryMedia: _bytes(676, 0x73),
        recoveryPassphrase: passphrase,
      ),
      throwsFormatException,
    );

    expect(callOrder, <String>['checkpoint:read']);
    expect(
      checkpointPersistence.current?.attemptId,
      fixture.challenge.attemptId,
    );
    expect(passphrase, everyElement(0));
  });

  test('过期 checkpoint 删除发生 CAS 竞争时不创建新恢复事务', () async {
    final fixture = _readyRecoveryFixture();
    final callOrder = <String>[];
    final expired = _expiredPreTransitionCheckpoint(
      fixture.challenge,
      E2eeAccountRecoveryCheckpointPhase.authorized,
    );
    final checkpointPersistence = _MemoryCheckpointPersistence(
      callOrder,
      initialCheckpoint: expired,
      deleteSucceeds: false,
    );
    final passphrase = Uint8List.fromList(utf8.encode('correct horse battery'));
    final authorizer = E2eeAccountRecoveryAuthorizer(
      transport: _FakeRecoveryTransport(
        challenge: fixture.challenge,
        historyPages: <CloudSyncAccountSecurityHistoryPage>[
          fixture.historyPage,
        ],
        callOrder: callOrder,
      ),
      proofCore: _FakeRecoveryProofCore(callOrder),
      checkpointPersistence: checkpointPersistence,
      serviceOriginSha256: _bytes(32, 0x61),
      attemptIdFactory: () => throw StateError('CAS 竞争后不应创建新 attempt'),
      recoveryTokenFactory: () => throw StateError('CAS 竞争后不应创建新恢复令牌'),
      now: () => DateTime.utc(2026, 8, 1, 0, 30),
    );

    await expectLater(
      authorizer.authorize(
        onboardingToken: CloudSyncOnboardingToken.parse(
          'kelivo_onboarding_${base64Url.encode(_bytes(32, 0x72)).replaceAll('=', '')}',
        ),
        expectedDeviceId: _uuid(5),
        recoveryMedia: _bytes(676, 0x73),
        recoveryPassphrase: passphrase,
      ),
      throwsStateError,
    );

    expect(callOrder, <String>['checkpoint:read', 'checkpoint:delete']);
    expect(checkpointPersistence.current?.attemptId, expired.attemptId);
    expect(passphrase, everyElement(0));
  });

  test('成员提交协调器只发送已持久化 replacement 并先落回执', () async {
    final callOrder = <String>[];
    final prepared = _preparedReplacementCheckpoint();
    final request =
        _preparedCommit(prepared) as E2eeAccountRecoveryReplacementCommit;
    final receipt = _replacementReceipt(
      request,
      E2eeAccountRecoveryCommitResult.committed,
    );
    final persistence = _MemoryCheckpointPersistence(
      callOrder,
      initialCheckpoint: prepared,
    );
    final transport = _FakeRecoveryTransport(
      challenge: prepared.challenge,
      historyPages: <CloudSyncAccountSecurityHistoryPage>[],
      callOrder: callOrder,
      replacementReceipt: receipt,
    );
    final coordinator = E2eeAccountRecoveryCommitCoordinator(
      transport: transport,
      checkpointPersistence: persistence,
      now: () => DateTime.utc(2026, 8, 1),
    );

    final committed = await coordinator.commitPrepared();

    expect(callOrder, <String>[
      'checkpoint:read',
      'commit:replacement',
      'checkpoint:replacementCommitted',
    ]);
    expect(transport.receivedReplacementRequest, same(request));
    expect(committed.membershipOperationId, request.membership.operationId);
    final committedProgress =
        persistence.current!.progress
            as E2eeAccountRecoveryReplacementCommittedProgress;
    expect(
      committedProgress.receipt.nextAction,
      E2eeAccountRecoveryNextAction.finishSecondDataRekey,
    );
    expect(committedProgress.receipt.result, committed.result);
  });

  test('成员提交协调器使用持久化 rekeyOperationId 提交 resume', () async {
    final callOrder = <String>[];
    final prepared = _preparedResumeCheckpoint();
    final request =
        _preparedCommit(prepared) as E2eeAccountRecoveryResumeCommit;
    final receipt = _resumeReceipt(request);
    final persistence = _MemoryCheckpointPersistence(
      callOrder,
      initialCheckpoint: prepared,
    );
    final transport = _FakeRecoveryTransport(
      challenge: prepared.challenge,
      historyPages: <CloudSyncAccountSecurityHistoryPage>[],
      callOrder: callOrder,
      resumeReceipt: receipt,
    );
    final coordinator = E2eeAccountRecoveryCommitCoordinator(
      transport: transport,
      checkpointPersistence: persistence,
      now: () => DateTime.utc(2026, 8, 1),
    );

    final committed = await coordinator.commitPrepared();

    expect(callOrder, <String>[
      'checkpoint:read',
      'commit:resume',
      'checkpoint:resumeCommitted',
    ]);
    expect(transport.receivedResumeRequest, same(request));
    expect(committed.rekeyOperationId, request.rekeyOperationId);
    expect(
      (persistence.current!.progress
              as E2eeAccountRecoveryResumeCommittedProgress)
          .receipt
          .nextAction,
      E2eeAccountRecoveryNextAction.finishFirstDataRekey,
    );
  });

  test('成员提交协调器发现已持久化回执时不重复触网', () async {
    final callOrder = <String>[];
    final prepared = _preparedReplacementCheckpoint();
    final request =
        _preparedCommit(prepared) as E2eeAccountRecoveryReplacementCommit;
    final receipt = _replacementReceipt(
      request,
      E2eeAccountRecoveryCommitResult.replayed,
    );
    final persistence = _MemoryCheckpointPersistence(
      callOrder,
      initialCheckpoint: prepared.withCommitReceipt(receipt),
    );
    final transport = _FakeRecoveryTransport(
      challenge: prepared.challenge,
      historyPages: <CloudSyncAccountSecurityHistoryPage>[],
      callOrder: callOrder,
    );
    final coordinator = E2eeAccountRecoveryCommitCoordinator(
      transport: transport,
      checkpointPersistence: persistence,
      now: () => DateTime.utc(2026, 8, 1),
    );

    final committed = await coordinator.commitPrepared();

    expect(callOrder, <String>['checkpoint:read']);
    expect(committed.result, E2eeAccountRecoveryCommitResult.replayed);
    expect(transport.receivedReplacementRequest, isNull);
  });

  test('成员提交协调器在恢复 token 到期时保留 prepared 且不触网', () async {
    final callOrder = <String>[];
    final prepared = _preparedReplacementCheckpoint();
    final persistence = _MemoryCheckpointPersistence(
      callOrder,
      initialCheckpoint: prepared,
    );
    final transport = _FakeRecoveryTransport(
      challenge: prepared.challenge,
      historyPages: <CloudSyncAccountSecurityHistoryPage>[],
      callOrder: callOrder,
    );
    final coordinator = E2eeAccountRecoveryCommitCoordinator(
      transport: transport,
      checkpointPersistence: persistence,
      now: () => DateTime.utc(2026, 8, 1, 2),
    );

    await expectLater(
      coordinator.commitPrepared(),
      throwsA(isA<E2eeAccountRecoveryExpired>()),
    );

    expect(callOrder, <String>['checkpoint:read']);
    expect(
      _preparedCommit(persistence.current!),
      same(_preparedCommit(prepared)),
    );
    expect(
      persistence.current!.phase,
      E2eeAccountRecoveryCheckpointPhase.replacementPrepared,
    );
    expect(transport.receivedReplacementRequest, isNull);
  });

  test('成员提交响应失败时保留 prepared 供原样重放', () async {
    final callOrder = <String>[];
    final prepared = _preparedReplacementCheckpoint();
    final failure = StateError('模拟成员提交响应丢失');
    final persistence = _MemoryCheckpointPersistence(
      callOrder,
      initialCheckpoint: prepared,
    );
    final transport = _FakeRecoveryTransport(
      challenge: prepared.challenge,
      historyPages: <CloudSyncAccountSecurityHistoryPage>[],
      callOrder: callOrder,
      replacementError: failure,
    );
    final coordinator = E2eeAccountRecoveryCommitCoordinator(
      transport: transport,
      checkpointPersistence: persistence,
      now: () => DateTime.utc(2026, 8, 1),
    );

    await expectLater(coordinator.commitPrepared(), throwsA(same(failure)));

    expect(callOrder, <String>['checkpoint:read', 'commit:replacement']);
    expect(
      _preparedCommit(persistence.current!),
      same(_preparedCommit(prepared)),
    );
    expect(
      persistence.current!.phase,
      E2eeAccountRecoveryCheckpointPhase.replacementPrepared,
    );
  });

  test('成员提交 CAS 竞争时接受同效 replayed 回执', () async {
    final callOrder = <String>[];
    final prepared = _preparedReplacementCheckpoint();
    final request =
        _preparedCommit(prepared) as E2eeAccountRecoveryReplacementCommit;
    final committedReceipt = _replacementReceipt(
      request,
      E2eeAccountRecoveryCommitResult.committed,
    );
    final replayedReceipt = _replacementReceipt(
      request,
      E2eeAccountRecoveryCommitResult.replayed,
    );
    final persistence = _MemoryCheckpointPersistence(
      callOrder,
      initialCheckpoint: prepared,
      concurrentAdvanceCheckpoint: prepared.withCommitReceipt(replayedReceipt),
    );
    final transport = _FakeRecoveryTransport(
      challenge: prepared.challenge,
      historyPages: <CloudSyncAccountSecurityHistoryPage>[],
      callOrder: callOrder,
      replacementReceipt: committedReceipt,
    );
    final coordinator = E2eeAccountRecoveryCommitCoordinator(
      transport: transport,
      checkpointPersistence: persistence,
      now: () => DateTime.utc(2026, 8, 1),
    );

    final committed = await coordinator.commitPrepared();

    expect(callOrder, <String>[
      'checkpoint:read',
      'commit:replacement',
      'checkpoint:replacementCommitted',
      'checkpoint:read',
    ]);
    expect(committed.result, E2eeAccountRecoveryCommitResult.replayed);
    expect(
      (persistence.current!.progress
              as E2eeAccountRecoveryReplacementCommittedProgress)
          .receipt
          .result,
      committed.result,
    );
  });
}

E2eeAccountRecoveryCheckpoint _preparedResumeCheckpoint() {
  final ready = _readyRecoveryFixture().challenge;
  final challenge = E2eeAccountRecoveryChallenge(
    attemptId: ready.attemptId,
    requestDigest: ready.requestDigest,
    challengeFrame: ready.challengeFrame,
    sealedNonce: ready.sealedNonce,
    securityGeneration: ready.securityGeneration,
    keyEpoch: ready.keyEpoch + 1,
    membershipManifestDigest: ready.membershipManifestDigest,
    recoveryPublicKeyVersion: ready.recoveryPublicKeyVersion,
    recoveryPublicKey: ready.recoveryPublicKey,
    recoveryCapsuleVersion: ready.recoveryCapsuleVersion,
    recoveryCapsule: ready.recoveryCapsule,
    recoveryCapsuleDigest: ready.recoveryCapsuleDigest,
    dataState: E2eeAccountRecoveryDataState.rekeyPending(
      dataGeneration: ready.dataState.dataGeneration,
      dataKeyEpoch: ready.dataState.dataKeyEpoch,
      operationId: _uuid(8),
      targetKeyEpoch: ready.dataState.dataKeyEpoch + 1,
    ),
    expiresAt: ready.expiresAt,
  );
  final authorized =
      E2eeAccountRecoveryCheckpoint.challenged(
            expectedDeviceId: _uuid(5),
            recoveryToken: CloudSyncAccountRecoveryToken.generate(),
            challenge: challenge,
          )
          .withProof(
            nonceProof: _bytes(32, 0x71),
            trustSignature: _bytes(64, 0x72),
          )
          .authorized(
            recoveryTokenExpiresAt: DateTime.utc(2026, 8, 1, 2),
            nextAction: E2eeAccountRecoveryNextAction.recoverResume,
          );
  final nextManifest = _bytes(476, 0x73);
  return authorized.prepareTransition(
    commit: E2eeAccountRecoveryResumeCommit(
      attemptId: challenge.attemptId,
      membership: E2eeAccountRecoveryMembershipCommit(
        expectedGeneration: challenge.securityGeneration,
        expectedKeyEpoch: challenge.keyEpoch,
        expectedMembershipManifestDigest:
            CloudSyncMembershipManifestDigest.fromBytes(
              challenge.membershipManifestDigest,
            ),
        operationId: _uuid(9),
        nextMembershipManifest: nextManifest,
        nextMembershipManifestDigest:
            CloudSyncMembershipManifestDigest.fromBytes(_digest(nextManifest)),
        envelope: E2eeAccountRecoveryEnvelope(
          envelopeVersion: 1,
          keyEpoch: challenge.keyEpoch,
          accountKeyEnvelope: _bytes(cloudSyncAccountKeyEnvelopeBytes, 0x74),
        ),
      ),
      rekeyOperationId: challenge.dataState.operationId!,
    ),
    localTransitionPlan: _localTransitionPlan(
      0x75,
      sourceDataGeneration: challenge.dataState.dataGeneration,
    ),
  );
}

E2eeAccountRecoveryCheckpoint _preparedReplacementCheckpoint() {
  final fixture = _readyRecoveryFixture();
  final authorized =
      E2eeAccountRecoveryCheckpoint.challenged(
            expectedDeviceId: _uuid(5),
            recoveryToken: CloudSyncAccountRecoveryToken.generate(),
            challenge: fixture.challenge,
          )
          .withProof(
            nonceProof: _bytes(32, 0x81),
            trustSignature: _bytes(64, 0x82),
          )
          .authorized(
            recoveryTokenExpiresAt: DateTime.utc(2026, 8, 1, 2),
            nextAction: E2eeAccountRecoveryNextAction.recoverReplace,
          );
  final nextManifest = _bytes(476, 0x91);
  return authorized.prepareTransition(
    commit: E2eeAccountRecoveryReplacementCommit(
      attemptId: fixture.challenge.attemptId,
      membership: E2eeAccountRecoveryMembershipCommit(
        expectedGeneration: fixture.challenge.securityGeneration,
        expectedKeyEpoch: fixture.challenge.keyEpoch,
        expectedMembershipManifestDigest:
            CloudSyncMembershipManifestDigest.fromBytes(
              fixture.challenge.membershipManifestDigest,
            ),
        operationId: _uuid(6),
        nextMembershipManifest: nextManifest,
        nextMembershipManifestDigest:
            CloudSyncMembershipManifestDigest.fromBytes(_digest(nextManifest)),
        envelope: E2eeAccountRecoveryEnvelope(
          envelopeVersion: 1,
          keyEpoch: fixture.challenge.keyEpoch + 1,
          accountKeyEnvelope: _bytes(cloudSyncAccountKeyEnvelopeBytes, 0x92),
        ),
      ),
      authorization: E2eeAccountRecoveryReplacementAuthorization.initial(
        challengeRequestDigest: fixture.challenge.requestDigest,
      ),
      nextRecoveryCapsuleVersion: fixture.challenge.recoveryCapsuleVersion + 1,
      nextRecoveryCapsule: _bytes(156, 0x93),
      completionSessionId: _uuid(7),
      completionSessionToken: CloudSyncFullSessionToken.generate(),
    ),
    localTransitionPlan: _localTransitionPlan(
      0x95,
      replacement: true,
      sourceDataGeneration: fixture.challenge.dataState.dataGeneration,
    ),
  );
}

E2eeAccountRecoveryCommitReceipt _replacementReceipt(
  E2eeAccountRecoveryReplacementCommit request,
  E2eeAccountRecoveryCommitResult result,
) {
  return E2eeAccountRecoveryCommitReceipt(
    result: result,
    kind: E2eeAccountRecoveryCommitKind.replacement,
    attemptId: request.attemptId,
    membershipOperationId: request.membership.operationId,
    rekeyOperationId: request.membership.operationId,
    generation: request.membership.expectedGeneration + 1,
    keyEpoch: request.membership.expectedKeyEpoch + 1,
    nextAction: E2eeAccountRecoveryNextAction.finishSecondDataRekey,
  );
}

E2eeAccountRecoveryCommitReceipt _resumeReceipt(
  E2eeAccountRecoveryResumeCommit request,
) {
  return E2eeAccountRecoveryCommitReceipt(
    result: E2eeAccountRecoveryCommitResult.committed,
    kind: E2eeAccountRecoveryCommitKind.resume,
    attemptId: request.attemptId,
    membershipOperationId: request.membership.operationId,
    rekeyOperationId: request.rekeyOperationId,
    generation: request.membership.expectedGeneration + 1,
    keyEpoch: request.membership.expectedKeyEpoch,
    nextAction: E2eeAccountRecoveryNextAction.finishFirstDataRekey,
  );
}

({
  E2eeAccountRecoveryChallenge challenge,
  CloudSyncAccountSecurityHistoryPage historyPage,
})
_readyRecoveryFixture() {
  final sourceManifest = _bytes(476, 0x11);
  final sourceCapsule = _bytes(156, 0x41);
  final currentManifest = _bytes(476, 0x21);
  final currentCapsule = _bytes(156, 0x51);
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
    dataState: E2eeAccountRecoveryDataState.ready(
      dataGeneration: 7,
      dataKeyEpoch: 2,
    ),
    expiresAt: DateTime.utc(2026, 8, 1, 1),
  );
  final projection = CloudSyncAccountSecurityCurrentProjection(
    generation: 2,
    keyEpoch: 2,
    dataRekeyPhase: CloudSyncDataRekeyPhase.ready,
    membershipManifestDigest: CloudSyncMembershipManifestDigest.fromBytes(
      _digest(currentManifest),
    ),
    recoveryPublicKeyVersion: 1,
    recoveryPublicKey: challenge.recoveryPublicKey,
    recoveryCapsuleVersion: 2,
    updatedAt: DateTime.utc(2026, 8, 1),
  );
  return (
    challenge: challenge,
    historyPage: CloudSyncAccountSecurityHistoryPage(
      items: <CloudSyncAccountSecurityHistoryItem>[
        _historyItem(
          generation: 1,
          keyEpoch: 1,
          manifest: sourceManifest,
          capsule: sourceCapsule,
          operationId: _uuid(2),
        ),
        _historyItem(
          generation: 2,
          keyEpoch: 2,
          manifest: currentManifest,
          capsule: currentCapsule,
          operationId: _uuid(3),
        ),
      ],
      afterGeneration: 0,
      nextAfterGeneration: 2,
      pageSize: 2,
      hasMore: false,
      currentState: projection,
    ),
  );
}

E2eeAccountRecoveryCheckpoint _expiredPreTransitionCheckpoint(
  E2eeAccountRecoveryChallenge current,
  E2eeAccountRecoveryCheckpointPhase phase, {
  String? expectedDeviceId,
}) {
  final expiredChallenge = E2eeAccountRecoveryChallenge(
    attemptId: _uuid(9),
    requestDigest: current.requestDigest,
    challengeFrame: current.challengeFrame,
    sealedNonce: current.sealedNonce,
    securityGeneration: current.securityGeneration,
    keyEpoch: current.keyEpoch,
    membershipManifestDigest: current.membershipManifestDigest,
    recoveryPublicKeyVersion: current.recoveryPublicKeyVersion,
    recoveryPublicKey: current.recoveryPublicKey,
    recoveryCapsuleVersion: current.recoveryCapsuleVersion,
    recoveryCapsule: current.recoveryCapsule,
    recoveryCapsuleDigest: current.recoveryCapsuleDigest,
    dataState: current.dataState,
    expiresAt: DateTime.utc(2026, 8, 1, 0, 10),
  );
  final challenged = E2eeAccountRecoveryCheckpoint.challenged(
    expectedDeviceId: expectedDeviceId ?? _uuid(5),
    recoveryToken: CloudSyncAccountRecoveryToken.generate(),
    challenge: expiredChallenge,
  );
  if (phase == E2eeAccountRecoveryCheckpointPhase.challenged) {
    return challenged;
  }
  final proofReady = challenged.withProof(
    nonceProof: _bytes(32, 0x81),
    trustSignature: _bytes(64, 0x82),
  );
  if (phase == E2eeAccountRecoveryCheckpointPhase.proofReady) {
    return proofReady;
  }
  if (phase != E2eeAccountRecoveryCheckpointPhase.authorized) {
    throw StateError('测试仅支持恢复迁移前阶段');
  }
  return proofReady.authorized(
    recoveryTokenExpiresAt: DateTime.utc(2026, 8, 1, 0, 20),
    nextAction: E2eeAccountRecoveryNextAction.recoverReplace,
  );
}

CloudSyncAccountSecurityState _securityStateForFixture(
  ({
    E2eeAccountRecoveryChallenge challenge,
    CloudSyncAccountSecurityHistoryPage historyPage,
  })
  fixture,
) {
  final head = fixture.historyPage.items.last;
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
  int? capsuleVersion,
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
    recoveryCapsuleVersion: capsuleVersion ?? generation,
    recoveryCapsule: capsule,
    operationId: operationId,
    committedAt: DateTime.utc(2026, 8, 1),
  );
}

_RotatedReadyFixture _rotatedReadyFixture(
  List<CloudSyncAccountSecurityHistoryItem> history,
) {
  final head = history.last;
  final projection = CloudSyncAccountSecurityCurrentProjection(
    generation: head.generation,
    keyEpoch: head.keyEpoch,
    dataRekeyPhase: CloudSyncDataRekeyPhase.ready,
    membershipManifestDigest: head.membershipManifestDigest,
    recoveryPublicKeyVersion: head.recoveryPublicKeyVersion,
    recoveryPublicKey: head.recoveryPublicKey,
    recoveryCapsuleVersion: head.recoveryCapsuleVersion,
    updatedAt: DateTime.utc(2026, 8, 1),
  );
  final challenge = E2eeAccountRecoveryChallenge(
    attemptId: _uuid(1),
    requestDigest: _bytes(32, 0x31),
    challengeFrame: _bytes(316, 0x32),
    sealedNonce: _bytes(100, 0x33),
    securityGeneration: head.generation,
    keyEpoch: head.keyEpoch,
    membershipManifestDigest: head.membershipManifestDigest.bytes,
    recoveryPublicKeyVersion: head.recoveryPublicKeyVersion,
    recoveryPublicKey: head.recoveryPublicKey,
    recoveryCapsuleVersion: head.recoveryCapsuleVersion,
    recoveryCapsule: head.recoveryCapsule,
    recoveryCapsuleDigest: _digest(head.recoveryCapsule),
    dataState: E2eeAccountRecoveryDataState.ready(
      dataGeneration: 8,
      dataKeyEpoch: head.keyEpoch,
    ),
    expiresAt: DateTime.utc(2026, 8, 1, 1),
  );
  final callOrder = <String>[];
  final transport = _FakeRecoveryTransport(
    challenge: challenge,
    historyPages: <CloudSyncAccountSecurityHistoryPage>[
      for (final item in history)
        _historyPage(
          afterGeneration: item.generation - 1,
          item: item,
          currentProjection: projection,
        ),
    ],
    callOrder: callOrder,
  );
  final proofCore = _FakeRecoveryProofCore(callOrder);
  return _RotatedReadyFixture(
    authorizer: E2eeAccountRecoveryAuthorizer(
      transport: transport,
      proofCore: proofCore,
      checkpointPersistence: _MemoryCheckpointPersistence(callOrder),
      serviceOriginSha256: _bytes(32, 0x61),
      attemptIdFactory: () => _uuid(1),
      recoveryTokenFactory: CloudSyncAccountRecoveryToken.generate,
      now: () => DateTime.utc(2026, 8, 1),
    ),
    callOrder: callOrder,
  );
}

final class _RotatedReadyFixture {
  const _RotatedReadyFixture({
    required this.authorizer,
    required this.callOrder,
  });

  final E2eeAccountRecoveryAuthorizer authorizer;
  final List<String> callOrder;

  Future<E2eeAuthorizedAccountRecovery> authorize() {
    return authorizer.authorize(
      onboardingToken: CloudSyncOnboardingToken.parse(
        'kelivo_onboarding_${base64Url.encode(_bytes(32, 0x72)).replaceAll('=', '')}',
      ),
      expectedDeviceId: _uuid(5),
      recoveryMedia: _bytes(676, 0x73),
      recoveryPassphrase: Uint8List.fromList(
        utf8.encode('correct horse battery'),
      ),
    );
  }
}

final class _FakeRecoveryTransport implements E2eeAccountRecoveryTransport {
  _FakeRecoveryTransport({
    required this.challenge,
    required this.historyPages,
    required this.callOrder,
    this.authorizedState,
    this.resumeReceipt,
    this.replacementReceipt,
    this.replacementError,
  });

  final E2eeAccountRecoveryChallenge challenge;
  final List<CloudSyncAccountSecurityHistoryPage> historyPages;
  final List<String> callOrder;
  final E2eeAccountRecoveryAuthorizedState? authorizedState;
  final E2eeAccountRecoveryCommitReceipt? resumeReceipt;
  final E2eeAccountRecoveryCommitReceipt? replacementReceipt;
  final Object? replacementError;
  Uint8List? receivedNonceProof;
  Uint8List? receivedTrustSignature;
  CloudSyncAccountRecoveryToken? receivedRecoveryToken;
  String? receivedHistoryBearer;
  E2eeAccountRecoveryResumeCommit? receivedResumeRequest;
  E2eeAccountRecoveryReplacementCommit? receivedReplacementRequest;

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
      nextAction:
          challenge.dataState.phase == E2eeAccountRecoveryDataPhase.ready
          ? E2eeAccountRecoveryNextAction.recoverReplace
          : E2eeAccountRecoveryNextAction.recoverResume,
      recoveryTokenExpiresAt: DateTime.utc(2026, 8, 1, 2),
    );
  }

  @override
  Future<E2eeAccountRecoveryReplacementChallenge> createReplacementChallenge({
    required CloudSyncAccountRecoveryToken recoveryToken,
    required String expectedAttemptId,
    required String expectedDeviceId,
    required E2eeAccountRecoveryReplacementChallengeRequest request,
  }) {
    throw StateError('授权测试不应创建恢复替换 challenge');
  }

  @override
  Future<E2eeAccountRecoveryCommitReceipt> commitRecoveryResume({
    required CloudSyncAccountRecoveryToken recoveryToken,
    required E2eeAccountRecoveryResumeCommit request,
  }) async {
    callOrder.add('commit:resume');
    receivedResumeRequest = request;
    final receipt = resumeReceipt;
    if (receipt == null) throw StateError('授权测试不应提交恢复接续');
    return receipt;
  }

  @override
  Future<E2eeAccountRecoveryCommitReceipt> commitRecoveryReplacement({
    required CloudSyncAccountRecoveryToken recoveryToken,
    required E2eeAccountRecoveryReplacementCommit request,
  }) async {
    callOrder.add('commit:replacement');
    receivedReplacementRequest = request;
    final error = replacementError;
    if (error != null) throw error;
    final receipt = replacementReceipt;
    if (receipt == null) throw StateError('授权测试不应提交恢复替换');
    return receipt;
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
  }) {
    throw StateError('授权测试不应验证恢复替换 challenge');
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
    this.concurrentAdvanceCheckpoint,
    this.deleteSucceeds = true,
  }) : _snapshot = initialCheckpoint == null
           ? null
           : E2eeAccountRecoveryCheckpointSnapshot(
               checkpoint: initialCheckpoint.detachedCopy(),
               envelopeDigest: _bytes(32, 0x90),
             );

  final List<String> callOrder;
  final E2eeAccountRecoveryCheckpoint? concurrentAdvanceCheckpoint;
  final bool deleteSucceeds;
  E2eeAccountRecoveryCheckpointSnapshot? _snapshot;

  E2eeAccountRecoveryCheckpoint? get current => _snapshot?.checkpoint;

  @override
  Future<E2eeAccountRecoveryCheckpointSnapshot?> read() async {
    callOrder.add('checkpoint:read');
    return _snapshot?.detachedCopy();
  }

  @override
  Future<E2eeAccountRecoveryCheckpointSnapshot> create(
    E2eeAccountRecoveryCheckpoint checkpoint,
  ) async {
    callOrder.add('checkpoint:create');
    final persisted = E2eeAccountRecoveryCheckpointSnapshot(
      checkpoint: checkpoint.detachedCopy(),
      envelopeDigest: _bytes(32, 0x91),
    );
    _snapshot?.clearSensitiveState();
    _snapshot = persisted;
    return persisted.detachedCopy();
  }

  @override
  Future<E2eeAccountRecoveryCheckpointSnapshot> advance({
    required Uint8List expectedEnvelopeDigest,
    required E2eeAccountRecoveryCheckpoint checkpoint,
  }) async {
    callOrder.add('checkpoint:${checkpoint.phase.name}');
    final concurrent = concurrentAdvanceCheckpoint;
    if (concurrent != null) {
      _snapshot?.clearSensitiveState();
      _snapshot = E2eeAccountRecoveryCheckpointSnapshot(
        checkpoint: concurrent.detachedCopy(),
        envelopeDigest: _bytes(32, 0x94),
      );
      throw StateError('模拟 checkpoint CAS 竞争');
    }
    final persisted = E2eeAccountRecoveryCheckpointSnapshot(
      checkpoint: checkpoint.detachedCopy(),
      envelopeDigest: _bytes(
        32,
        checkpoint.phase == E2eeAccountRecoveryCheckpointPhase.proofReady
            ? 0x92
            : 0x93,
      ),
    );
    _snapshot?.clearSensitiveState();
    _snapshot = persisted;
    return persisted.detachedCopy();
  }

  @override
  Future<bool> delete(E2eeAccountRecoveryCheckpointSnapshot snapshot) async {
    callOrder.add('checkpoint:delete');
    if (!deleteSucceeds) return false;
    _snapshot?.clearSensitiveState();
    _snapshot = null;
    return true;
  }
}

E2eeAccountRecoveryPreparedCommit _preparedCommit(
  E2eeAccountRecoveryCheckpoint checkpoint,
) {
  return switch (checkpoint.progress) {
    E2eeAccountRecoveryResumePreparedProgress(:final transition) =>
      transition.commit,
    E2eeAccountRecoveryReplacementPreparedProgress(:final transition) =>
      transition.commit,
    _ => throw StateError('测试 checkpoint 不处于 prepared 阶段'),
  };
}

E2eeAccountRecoveryLocalTransitionPlan _localTransitionPlan(
  int seed, {
  bool replacement = false,
  int sourceDataGeneration = 1,
}) {
  return E2eeAccountRecoveryLocalTransitionPlan(
    sourceStateBlob: _bytes(DeviceStateBlobStore.blobLength, seed),
    unprunedStateBlob: _bytes(DeviceStateBlobStore.blobLength, seed + 1),
    prunedStateBlob: _bytes(DeviceStateBlobStore.blobLength, seed + 2),
    deviceKeyVersion: 1,
    userId: _uuid(4),
    sourceDataGeneration: sourceDataGeneration,
    operationAuthorizationDigest: replacement
        ? Uint8List(cloudSyncMembershipManifestDigestBytes)
        : _bytes(cloudSyncMembershipManifestDigestBytes, seed + 3),
    continuation: _bytes(e2eeAccountRecoveryNativeContinuationBytes, seed + 4),
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
