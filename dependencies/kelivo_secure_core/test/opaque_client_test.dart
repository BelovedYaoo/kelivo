import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';

void main() {
  const core = KelivoSecureCore();

  Uint8List accountId(int seed) {
    final value = Uint8List(16)..fillRange(0, 16, seed);
    value[6] = (value[6] & 0x0f) | 0x40;
    value[8] = (value[8] & 0x3f) | 0x80;
    return value;
  }

  Future<KelivoKeyHandle> openOrCreateTestSlot() async {
    final slotId = Uint8List(16)..fillRange(0, 16, 0xe2);
    try {
      return await core.createSlot(slotId);
    } on KelivoSecureCoreException catch (error) {
      if (error.status != KelivoSecureCoreStatus.slotAlreadyExists) rethrow;
      return core.openSlot(slotId);
    }
  }

  test('能力门禁声明 ABI v4 OPAQUE 与设备 E2EE 支持', () async {
    final capabilities = await core.getCapabilities();

    expect(capabilities.abiVersion, 4);
    expect(capabilities.supportsOpaqueClient, isTrue);
    expect(
      capabilities.supportsDeviceE2eeCore,
      Platform.isWindows || Platform.isAndroid,
    );
  });

  test('注册状态可显式取消且不能重复消费', () async {
    final password = Uint8List.fromList('registration-password'.codeUnits);
    final start = await core.startOpaqueRegistration(password);

    expect(start.request, hasLength(48));
    expect(password, 'registration-password'.codeUnits);
    await core.cancelOpaqueRegistration(start.state);
    await expectLater(
      core.cancelOpaqueRegistration(start.state),
      throwsStateError,
    );
  });

  test('登录状态可显式取消且不能重复消费', () async {
    final password = Uint8List.fromList('login-password'.codeUnits);
    final start = await core.startOpaqueLogin(password);

    expect(start.request, hasLength(112));
    expect(password, 'login-password'.codeUnits);
    await core.cancelOpaqueLogin(start.state);
    await expectLater(core.cancelOpaqueLogin(start.state), throwsStateError);
  });

  test('畸形注册响应失败后状态仍被永久消费', () async {
    final password = Uint8List.fromList('registration-password'.codeUnits);
    final start = await core.startOpaqueRegistration(password);

    await expectLater(
      core.finishOpaqueRegistration(
        start.state,
        password: password,
        response: Uint8List(80),
        accountId: accountId(0x31),
      ),
      throwsA(
        isA<KelivoSecureCoreException>().having(
          (error) => error.status,
          'status',
          KelivoSecureCoreStatus.opaqueMessageInvalid,
        ),
      ),
    );
    await expectLater(
      core.cancelOpaqueRegistration(start.state),
      throwsStateError,
    );
  });

  test('客户端接口拒绝非 UUIDv4 原始账户标识并消费状态', () async {
    final password = Uint8List.fromList('login-password'.codeUnits);
    final start = await core.startOpaqueLogin(password);

    await expectLater(
      core.finishOpaqueLogin(
        start.state,
        password: password,
        response: Uint8List(336),
        accountId: Uint8List(16),
      ),
      throwsArgumentError,
    );
    await expectLater(core.cancelOpaqueLogin(start.state), throwsStateError);
  });

  test('空密码不创建可发送请求或秘密状态', () async {
    await expectLater(
      core.startOpaqueRegistration(Uint8List(0)),
      throwsArgumentError,
    );
  });

  test('超长密码在复制或进入原生层前被拒绝', () async {
    await expectLater(
      core.startOpaqueLogin(Uint8List(65536)),
      throwsArgumentError,
    );
  });

  test('固定长度响应在复制前校验且失败仍消费状态', () async {
    final password = Uint8List.fromList('registration-password'.codeUnits);
    final start = await core.startOpaqueRegistration(password);

    await expectLater(
      core.finishOpaqueRegistration(
        start.state,
        password: password,
        response: Uint8List(79),
        accountId: accountId(0x32),
      ),
      throwsArgumentError,
    );
    await expectLater(
      core.cancelOpaqueRegistration(start.state),
      throwsStateError,
    );
  });

  test('已消费状态会在创建密码转移缓冲区前同步拒绝', () async {
    final password = Uint8List.fromList('login-password'.codeUnits);
    final start = await core.startOpaqueLogin(password);
    await core.cancelOpaqueLogin(start.state);

    expect(
      () => core.finishOpaqueLogin(
        start.state,
        password: Uint8List(65536),
        response: Uint8List(336),
        accountId: accountId(0x33),
      ),
      throwsStateError,
    );
  });

  test('设备证明与注册 bundle 仅返回固定公开材料', () async {
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final identity = await core.generateDeviceIdentity();
    final ark = await core.generateAccountRootKey();
    final userId = accountId(0x41);
    final deviceId = accountId(0x42);
    final attemptId = accountId(0x43);
    final accountContextId = accountId(0x44);
    final challenge = Uint8List(32)..fillRange(0, 32, 0x45);

    final registration = await core.createDeviceRegistrationFinish(
      identity,
      ark,
      userId: userId,
      deviceId: deviceId,
      keyEpoch: 1,
      attemptId: attemptId,
      accountContextId: accountContextId,
      expiresAtMs: 1800000000000,
      challenge: challenge,
      registrationUpload: Uint8List(208)..fillRange(0, 208, 0x46),
    );
    expect(registration.envelope, hasLength(336));
    expect(registration.signature, hasLength(64));

    final loginProof = await core.signDeviceLoginProof(
      identity,
      attemptId: attemptId,
      accountContextId: accountContextId,
      deviceId: deviceId,
      expiresAtMs: 1800000000000,
      challenge: challenge,
      credentialFinalization: Uint8List(80)..fillRange(0, 80, 0x47),
    );
    expect(loginProof, hasLength(64));

    final cancelledPairing = await core.startPendingPairing(
      identity,
      targetDeviceId: deviceId,
      targetKeyVersion: 1,
    );
    cancelledPairing.discardPairingSecret();
    await core.cancelPendingPairing(cancelledPairing.state);
    await expectLater(
      core.cancelPendingPairing(cancelledPairing.state),
      throwsStateError,
    );

    await core.closeAccountRootKey(ark);
    await core.closeDeviceIdentity(identity);
    await expectLater(core.closeDeviceIdentity(identity), throwsStateError);
  });

  test('一次性 pending 配对失败可重试且成功后原子消费', () async {
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final key = await openOrCreateTestSlot();
    final issuerIdentity = await core.generateDeviceIdentity();
    final issuerArk = await core.generateAccountRootKey();
    final targetIdentity = await core.generateDeviceIdentity();
    final issuerDeviceId = accountId(0x51);
    final targetDeviceId = accountId(0x52);
    final userId = accountId(0x53);
    final challenge = Uint8List(32)..fillRange(0, 32, 0x54);
    const keyVersion = 1;
    const keyEpoch = 7;
    const nowMs = 1800000000000;
    const expiresAtMs = nowMs + 300000;

    final pendingState = await core.sealDeviceState(
      key,
      targetIdentity,
      deviceId: targetDeviceId,
      keyVersion: keyVersion,
    );
    expect(pendingState, hasLength(188));
    await core.closeDeviceIdentity(targetIdentity);

    final reopenedPending = await core.openDeviceState(
      key,
      stateBlob: pendingState,
      expectedDeviceId: targetDeviceId,
      expectedKeyVersion: keyVersion,
    );
    expect(reopenedPending.ark, isNull);
    final targetPublicKeys = await core.readDevicePublicKeys(
      reopenedPending.identity,
    );
    final issuerPublicKeys = await core.readDevicePublicKeys(issuerIdentity);
    final pending = await core.startPendingPairing(
      reopenedPending.identity,
      targetDeviceId: targetDeviceId,
      targetKeyVersion: keyVersion,
    );
    expect(pending.pairingId, hasLength(16));
    expect(pending.pairingSecretHash, hasLength(32));
    final pairingSecret = pending.takePairingSecret();
    expect(pairingSecret, hasLength(32));
    expect(pending.takePairingSecret, throwsStateError);

    await expectLater(
      core.bindPendingPairing(
        pending.state,
        pairingId: pending.pairingId,
        userId: userId,
        targetDeviceId: targetDeviceId,
        targetKeyVersion: keyVersion,
        targetPublicKeys: issuerPublicKeys,
        expiresAtMs: expiresAtMs,
        challenge: challenge,
        nowMs: nowMs,
      ),
      throwsA(
        isA<KelivoSecureCoreException>().having(
          (error) => error.status,
          'status',
          KelivoSecureCoreStatus.deviceAuthenticationFailed,
        ),
      ),
    );
    await core.bindPendingPairing(
      pending.state,
      pairingId: pending.pairingId,
      userId: userId,
      targetDeviceId: targetDeviceId,
      targetKeyVersion: keyVersion,
      targetPublicKeys: targetPublicKeys,
      expiresAtMs: expiresAtMs,
      challenge: challenge,
      nowMs: nowMs,
    );
    await expectLater(
      core.bindPendingPairing(
        pending.state,
        pairingId: pending.pairingId,
        userId: userId,
        targetDeviceId: targetDeviceId,
        targetKeyVersion: keyVersion,
        targetPublicKeys: targetPublicKeys,
        expiresAtMs: expiresAtMs,
        challenge: challenge,
        nowMs: nowMs,
      ),
      throwsStateError,
    );

    late final KelivoPairingApprovalBundle approval;
    try {
      approval = await core.createPairingApproval(
        issuerIdentity,
        issuerArk,
        pairingId: pending.pairingId,
        userId: userId,
        issuerDeviceId: issuerDeviceId,
        targetDeviceId: targetDeviceId,
        expiresAtMs: expiresAtMs,
        challenge: challenge,
        keyEpoch: keyEpoch,
        targetPublicKeys: targetPublicKeys,
        pairingSecret: pairingSecret,
      );
    } finally {
      pairingSecret.fillRange(0, pairingSecret.length, 0);
    }
    final tamperedAuthenticator = Uint8List.fromList(approval.authenticator);
    tamperedAuthenticator[0] ^= 1;
    final tamperedApproval = KelivoPairingApprovalBundle(
      envelope: approval.envelope,
      signature: approval.signature,
      authenticator: tamperedAuthenticator,
    );
    await expectLater(
      core.acceptPairingApproval(
        key,
        reopenedPending.identity,
        pending.state,
        nowMs: nowMs,
        issuerDeviceId: issuerDeviceId,
        keyEpoch: keyEpoch,
        issuerPublicKeys: issuerPublicKeys,
        approval: tamperedApproval,
      ),
      throwsA(
        isA<KelivoSecureCoreException>().having(
          (error) => error.status,
          'status',
          KelivoSecureCoreStatus.deviceAuthenticationFailed,
        ),
      ),
    );

    final accepted = await core.acceptPairingApproval(
      key,
      reopenedPending.identity,
      pending.state,
      nowMs: expiresAtMs,
      issuerDeviceId: issuerDeviceId,
      keyEpoch: keyEpoch,
      issuerPublicKeys: issuerPublicKeys,
      approval: approval,
    );
    expect(accepted.stateBlob, hasLength(188));
    await expectLater(
      core.acceptPairingApproval(
        key,
        reopenedPending.identity,
        pending.state,
        nowMs: expiresAtMs,
        issuerDeviceId: issuerDeviceId,
        keyEpoch: keyEpoch,
        issuerPublicKeys: issuerPublicKeys,
        approval: approval,
      ),
      throwsStateError,
    );

    final reopenedFull = await core.openDeviceState(
      key,
      stateBlob: accepted.stateBlob,
      expectedDeviceId: targetDeviceId,
      expectedKeyVersion: keyVersion,
      expectedAccount: KelivoDeviceStateAccountBinding(
        userId: userId,
        keyEpoch: keyEpoch,
      ),
    );
    expect(reopenedFull.ark, isNotNull);
    final reopenedPublicKeys = await core.readDevicePublicKeys(
      reopenedFull.identity,
    );
    expect(
      reopenedPublicKeys.signingPublicKey,
      orderedEquals(targetPublicKeys.signingPublicKey),
    );
    expect(
      reopenedPublicKeys.keyAgreementPublicKey,
      orderedEquals(targetPublicKeys.keyAgreementPublicKey),
    );

    await core.closeAccountRootKey(reopenedFull.ark!);
    await core.closeDeviceIdentity(reopenedFull.identity);
    await core.closeAccountRootKey(accepted.ark);
    await core.closeDeviceIdentity(reopenedPending.identity);
    await core.closeAccountRootKey(issuerArk);
    await core.closeDeviceIdentity(issuerIdentity);
    await core.close(key);
  });
}
