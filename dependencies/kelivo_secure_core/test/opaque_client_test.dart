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

  test('能力门禁声明 ABI v12 OPAQUE、设备 E2EE、附件加密与账户信任签名支持', () async {
    final capabilities = await core.getCapabilities();

    expect(capabilities.abiVersion, 12);
    expect(capabilities.supportsOpaqueClient, isTrue);
    expect(
      capabilities.supportsDeviceE2eeCore,
      Platform.isWindows || Platform.isAndroid,
    );
    expect(
      capabilities.supportsAttachmentCrypto,
      Platform.isWindows || Platform.isAndroid,
    );
    expect(
      capabilities.supportsAccountTrustSigning,
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
    final userId = accountId(0x41);
    final ark = await core.generateAccountRootKey(userId: userId, keyEpoch: 1);
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

  test('账户根密钥按精确代次稳定派生记录标识并拒绝非法输入', () async {
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final userId = accountId(0x40);
    final ark = await core.generateAccountRootKey(userId: userId, keyEpoch: 1);
    final canonicalKey = Uint8List.fromList(
      'chat-message/018f2f89-8d5a-7bd2-a459-5d540a8f90ab'.codeUnits,
    );

    final first = await core.deriveAccountRecordId(
      ark,
      keyEpoch: 1,
      canonicalEntityKey: canonicalKey,
    );
    final repeated = await core.deriveAccountRecordId(
      ark,
      keyEpoch: 1,
      canonicalEntityKey: canonicalKey,
    );
    final other = await core.deriveAccountRecordId(
      ark,
      keyEpoch: 1,
      canonicalEntityKey: Uint8List.fromList(
        'chat-message/018f2f89-8d5a-7bd2-a459-5d540a8f90ac'.codeUnits,
      ),
    );

    expect(first, hasLength(16));
    expect(first[6] & 0xf0, 0x40);
    expect(first[8] & 0xc0, 0x80);
    expect(repeated, orderedEquals(first));
    expect(other, isNot(orderedEquals(first)));
    expect(
      await core.deriveAccountRecordId(
        ark,
        keyEpoch: 1,
        canonicalEntityKey: Uint8List(2048)..fillRange(0, 2048, 0x5a),
      ),
      hasLength(16),
    );

    await expectLater(
      core.deriveAccountRecordId(
        ark,
        keyEpoch: 1,
        canonicalEntityKey: Uint8List(0),
      ),
      throwsArgumentError,
    );
    await expectLater(
      core.deriveAccountRecordId(
        ark,
        keyEpoch: 1,
        canonicalEntityKey: Uint8List(2049),
      ),
      throwsArgumentError,
    );
    await expectLater(
      core.deriveAccountRecordId(
        ark,
        keyEpoch: 0,
        canonicalEntityKey: canonicalKey,
      ),
      throwsArgumentError,
    );
    await expectLater(
      core.deriveAccountRecordId(
        ark,
        keyEpoch: 0x100000000,
        canonicalEntityKey: canonicalKey,
      ),
      throwsArgumentError,
    );

    await core.closeAccountRootKey(ark);
    await expectLater(
      core.deriveAccountRecordId(
        ark,
        keyEpoch: 1,
        canonicalEntityKey: canonicalKey,
      ),
      throwsStateError,
    );
  });

  test('ARK 轮换信封严格绑定双方设备并保持句柄生命周期关闭', () async {
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final issuerIdentity = await core.generateDeviceIdentity();
    final targetIdentity = await core.generateDeviceIdentity();
    final otherIdentity = await core.generateDeviceIdentity();
    final issuerPublicKeys = await core.readDevicePublicKeys(issuerIdentity);
    final targetPublicKeys = await core.readDevicePublicKeys(targetIdentity);
    final otherPublicKeys = await core.readDevicePublicKeys(otherIdentity);
    final userId = accountId(0x61);
    final ark = await core.generateAccountRootKey(
      userId: userId,
      keyEpoch: 0xffffffff,
    );
    final issuerDeviceId = accountId(0x62);
    final targetDeviceId = accountId(0x63);
    const keyEpoch = 0xffffffff;

    final sealing = core.sealAccountRootKeyEnvelope(
      issuerIdentity,
      ark,
      userId: userId,
      issuerDeviceId: issuerDeviceId,
      targetDeviceId: targetDeviceId,
      keyEpoch: keyEpoch,
      targetPublicKeys: targetPublicKeys,
    );
    await expectLater(core.closeAccountRootKey(ark), throwsStateError);
    final envelope = await sealing;
    expect(envelope.bytes, hasLength(336));
    expect(
      () => KelivoAccountRootKeyEnvelope(Uint8List(335)),
      throwsArgumentError,
    );

    final openingUserId = Uint8List.fromList(userId);
    final opening = core.openAccountRootKeyEnvelope(
      targetIdentity,
      envelope: envelope,
      userId: openingUserId,
      issuerDeviceId: issuerDeviceId,
      targetDeviceId: targetDeviceId,
      keyEpoch: keyEpoch,
      issuerPublicKeys: issuerPublicKeys,
      targetPublicKeys: targetPublicKeys,
    );
    openingUserId[0] ^= 1;
    await expectLater(
      core.closeDeviceIdentity(targetIdentity),
      throwsStateError,
    );
    final openedArk = await opening;
    expect(openedArk.userId, orderedEquals(userId));
    final canonicalKey = Uint8List.fromList(
      'chat-message/ark-rotation-proof'.codeUnits,
    );
    expect(
      await core.deriveAccountRecordId(
        openedArk,
        keyEpoch: keyEpoch,
        canonicalEntityKey: canonicalKey,
      ),
      orderedEquals(
        await core.deriveAccountRecordId(
          ark,
          keyEpoch: keyEpoch,
          canonicalEntityKey: canonicalKey,
        ),
      ),
    );

    final authenticationFailure = throwsA(
      isA<KelivoSecureCoreException>().having(
        (error) => error.status,
        'status',
        KelivoSecureCoreStatus.deviceAuthenticationFailed,
      ),
    );
    await expectLater(
      core.openAccountRootKeyEnvelope(
        targetIdentity,
        envelope: envelope,
        userId: accountId(0x64),
        issuerDeviceId: issuerDeviceId,
        targetDeviceId: targetDeviceId,
        keyEpoch: keyEpoch,
        issuerPublicKeys: issuerPublicKeys,
        targetPublicKeys: targetPublicKeys,
      ),
      authenticationFailure,
    );
    await expectLater(
      core.openAccountRootKeyEnvelope(
        targetIdentity,
        envelope: envelope,
        userId: userId,
        issuerDeviceId: issuerDeviceId,
        targetDeviceId: targetDeviceId,
        keyEpoch: keyEpoch,
        issuerPublicKeys: otherPublicKeys,
        targetPublicKeys: targetPublicKeys,
      ),
      authenticationFailure,
    );
    await expectLater(
      core.openAccountRootKeyEnvelope(
        targetIdentity,
        envelope: envelope,
        userId: userId,
        issuerDeviceId: issuerDeviceId,
        targetDeviceId: targetDeviceId,
        keyEpoch: keyEpoch,
        issuerPublicKeys: issuerPublicKeys,
        targetPublicKeys: otherPublicKeys,
      ),
      authenticationFailure,
    );
    await expectLater(
      core.openAccountRootKeyEnvelope(
        otherIdentity,
        envelope: envelope,
        userId: userId,
        issuerDeviceId: issuerDeviceId,
        targetDeviceId: targetDeviceId,
        keyEpoch: keyEpoch,
        issuerPublicKeys: issuerPublicKeys,
        targetPublicKeys: targetPublicKeys,
      ),
      authenticationFailure,
    );
    final tamperedBytes = Uint8List.fromList(envelope.bytes);
    tamperedBytes[tamperedBytes.length - 1] ^= 1;
    await expectLater(
      core.openAccountRootKeyEnvelope(
        targetIdentity,
        envelope: KelivoAccountRootKeyEnvelope(tamperedBytes),
        userId: userId,
        issuerDeviceId: issuerDeviceId,
        targetDeviceId: targetDeviceId,
        keyEpoch: keyEpoch,
        issuerPublicKeys: issuerPublicKeys,
        targetPublicKeys: targetPublicKeys,
      ),
      authenticationFailure,
    );

    await expectLater(
      core.sealAccountRootKeyEnvelope(
        issuerIdentity,
        ark,
        userId: Uint8List(16),
        issuerDeviceId: issuerDeviceId,
        targetDeviceId: targetDeviceId,
        keyEpoch: keyEpoch,
        targetPublicKeys: targetPublicKeys,
      ),
      throwsArgumentError,
    );
    for (final invalidEpoch in [0, 0x100000000]) {
      await expectLater(
        core.sealAccountRootKeyEnvelope(
          issuerIdentity,
          ark,
          userId: userId,
          issuerDeviceId: issuerDeviceId,
          targetDeviceId: targetDeviceId,
          keyEpoch: invalidEpoch,
          targetPublicKeys: targetPublicKeys,
        ),
        throwsArgumentError,
      );
    }

    await core.closeAccountRootKey(openedArk);
    await core.closeDeviceIdentity(targetIdentity);
    await expectLater(
      core.openAccountRootKeyEnvelope(
        targetIdentity,
        envelope: envelope,
        userId: userId,
        issuerDeviceId: issuerDeviceId,
        targetDeviceId: targetDeviceId,
        keyEpoch: keyEpoch,
        issuerPublicKeys: issuerPublicKeys,
        targetPublicKeys: targetPublicKeys,
      ),
      throwsStateError,
    );
    await core.closeAccountRootKey(ark);
    await expectLater(
      core.sealAccountRootKeyEnvelope(
        issuerIdentity,
        ark,
        userId: userId,
        issuerDeviceId: issuerDeviceId,
        targetDeviceId: targetDeviceId,
        keyEpoch: keyEpoch,
        targetPublicKeys: targetPublicKeys,
      ),
      throwsStateError,
    );
    await core.closeDeviceIdentity(otherIdentity);
    await core.closeDeviceIdentity(issuerIdentity);
  });

  test('账户根密钥记录可跨句柄互解并严格绑定上下文', () async {
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final key = await openOrCreateTestSlot();
    final identity = await core.generateDeviceIdentity();
    final userId = accountId(0x48);
    final ark = await core.generateAccountRootKey(userId: userId, keyEpoch: 7);
    final deviceId = accountId(0x49);
    final recordId = accountId(0x4a);
    final associatedData = Uint8List.fromList('sync/chat/message'.codeUnits);
    final plaintext = Uint8List.fromList('encrypted payload'.codeUnits);
    const keyEpoch = 7;

    final stateBlob = await core.sealDeviceState(
      key,
      identity,
      deviceId: deviceId,
      keyVersion: 1,
      ark: ark,
      account: KelivoDeviceStateAccountBinding(
        userId: userId,
        keyEpoch: keyEpoch,
      ),
    );
    final reopened = await core.openDeviceState(key, stateBlob: stateBlob);
    final reopenedArk = reopened.ark!;
    final envelope = await core.sealAccountRecord(
      ark,
      recordId: recordId,
      keyEpoch: keyEpoch,
      associatedData: associatedData,
      plaintext: plaintext,
    );
    expect(
      await core.openAccountRecord(
        reopenedArk,
        recordId: recordId,
        keyEpoch: keyEpoch,
        associatedData: associatedData,
        envelope: envelope,
      ),
      orderedEquals(plaintext),
    );

    final authenticationFailure = throwsA(
      isA<KelivoSecureCoreException>().having(
        (error) => error.status,
        'status',
        KelivoSecureCoreStatus.recordAuthenticationFailed,
      ),
    );
    final otherArk = await core.generateAccountRootKey(
      userId: userId,
      keyEpoch: keyEpoch,
    );
    await expectLater(
      core.openAccountRecord(
        otherArk,
        recordId: recordId,
        keyEpoch: keyEpoch,
        associatedData: associatedData,
        envelope: envelope,
      ),
      authenticationFailure,
    );
    await expectLater(
      core.openAccountRecord(
        reopenedArk,
        recordId: recordId,
        keyEpoch: keyEpoch + 1,
        associatedData: associatedData,
        envelope: envelope,
      ),
      authenticationFailure,
    );
    await expectLater(
      core.openAccountRecord(
        reopenedArk,
        recordId: accountId(0x4b),
        keyEpoch: keyEpoch,
        associatedData: associatedData,
        envelope: envelope,
      ),
      authenticationFailure,
    );
    await expectLater(
      core.openAccountRecord(
        reopenedArk,
        recordId: recordId,
        keyEpoch: keyEpoch,
        associatedData: Uint8List.fromList('sync/chat/other'.codeUnits),
        envelope: envelope,
      ),
      authenticationFailure,
    );
    final tamperedEnvelope = Uint8List.fromList(envelope);
    tamperedEnvelope[tamperedEnvelope.length - 1] ^= 1;
    await expectLater(
      core.openAccountRecord(
        reopenedArk,
        recordId: recordId,
        keyEpoch: keyEpoch,
        associatedData: associatedData,
        envelope: tamperedEnvelope,
      ),
      authenticationFailure,
    );

    final closedArk = await core.generateAccountRootKey(
      userId: userId,
      keyEpoch: keyEpoch,
    );
    await core.closeAccountRootKey(closedArk);
    await expectLater(
      core.openAccountRecord(
        closedArk,
        recordId: recordId,
        keyEpoch: keyEpoch,
        associatedData: associatedData,
        envelope: envelope,
      ),
      throwsStateError,
    );

    await core.closeAccountRootKey(otherArk);
    await core.closeAccountRootKey(reopenedArk);
    await core.closeDeviceIdentity(reopened.identity);
    await core.closeAccountRootKey(ark);
    await core.closeDeviceIdentity(identity);
    await core.close(key);
  });

  test('ARK密钥环跨设备状态保留历史代次并按精确代次裁剪', () async {
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final key = await openOrCreateTestSlot();
    final identity = await core.generateDeviceIdentity();
    final recordId = accountId(0x4c);
    final userId = accountId(0x4d);
    final keyring = await core.generateAccountRootKey(
      userId: userId,
      keyEpoch: 1,
    );
    final epochTwo = await core.generateAccountRootKey(
      userId: userId,
      keyEpoch: 2,
    );
    final duplicate = await core.generateAccountRootKey(
      userId: userId,
      keyEpoch: 2,
    );
    final deviceId = accountId(0x4e);
    final associatedData = Uint8List.fromList('sync/keyring'.codeUnits);
    final canonicalEntityKey = Uint8List.fromList(
      'conversation/record-epoch-history'.codeUnits,
    );
    final epochOneRecordId = await core.deriveAccountRecordId(
      keyring,
      keyEpoch: 1,
      canonicalEntityKey: canonicalEntityKey,
    );
    final epochOneEnvelope = await core.sealAccountRecord(
      keyring,
      recordId: recordId,
      keyEpoch: 1,
      associatedData: associatedData,
      plaintext: Uint8List.fromList(<int>[1]),
    );

    await core.addAccountRootKeyEpoch(keyring, source: epochTwo);
    expect(
      await core.deriveAccountRecordId(
        keyring,
        keyEpoch: 1,
        canonicalEntityKey: canonicalEntityKey,
      ),
      orderedEquals(epochOneRecordId),
    );
    final epochTwoRecordId = await core.deriveAccountRecordId(
      keyring,
      keyEpoch: 2,
      canonicalEntityKey: canonicalEntityKey,
    );
    expect(epochTwoRecordId, isNot(orderedEquals(epochOneRecordId)));
    await expectLater(
      core.deriveAccountRecordId(
        keyring,
        keyEpoch: 3,
        canonicalEntityKey: canonicalEntityKey,
      ),
      throwsA(
        isA<KelivoSecureCoreException>().having(
          (error) => error.status,
          'status',
          KelivoSecureCoreStatus.invalidArgument,
        ),
      ),
    );
    await expectLater(
      core.addAccountRootKeyEpoch(keyring, source: duplicate),
      throwsA(
        isA<KelivoSecureCoreException>().having(
          (error) => error.status,
          'status',
          KelivoSecureCoreStatus.invalidArgument,
        ),
      ),
    );
    final epochTwoEnvelope = await core.sealAccountRecord(
      keyring,
      recordId: recordId,
      keyEpoch: 2,
      associatedData: associatedData,
      plaintext: Uint8List.fromList(<int>[2]),
    );
    final stateBlob = await core.sealDeviceState(
      key,
      identity,
      deviceId: deviceId,
      keyVersion: 1,
      ark: keyring,
      account: KelivoDeviceStateAccountBinding(userId: userId, keyEpoch: 2),
    );
    expect(stateBlob, hasLength(448));
    final reopened = await core.openDeviceState(key, stateBlob: stateBlob);
    final reopenedKeyring = reopened.ark!;
    expect(reopenedKeyring.userId, orderedEquals(userId));
    expect(
      await core.deriveAccountRecordId(
        reopenedKeyring,
        keyEpoch: 1,
        canonicalEntityKey: canonicalEntityKey,
      ),
      orderedEquals(epochOneRecordId),
    );
    expect(
      await core.deriveAccountRecordId(
        reopenedKeyring,
        keyEpoch: 2,
        canonicalEntityKey: canonicalEntityKey,
      ),
      orderedEquals(epochTwoRecordId),
    );
    expect(
      await core.openAccountRecord(
        reopenedKeyring,
        recordId: recordId,
        keyEpoch: 1,
        associatedData: associatedData,
        envelope: epochOneEnvelope,
      ),
      orderedEquals(<int>[1]),
    );
    expect(
      await core.openAccountRecord(
        reopenedKeyring,
        recordId: recordId,
        keyEpoch: 2,
        associatedData: associatedData,
        envelope: epochTwoEnvelope,
      ),
      orderedEquals(<int>[2]),
    );

    await core.pruneAccountRootKeyEpoch(reopenedKeyring, keyEpoch: 1);
    await expectLater(
      core.deriveAccountRecordId(
        reopenedKeyring,
        keyEpoch: 1,
        canonicalEntityKey: canonicalEntityKey,
      ),
      throwsA(
        isA<KelivoSecureCoreException>().having(
          (error) => error.status,
          'status',
          KelivoSecureCoreStatus.invalidArgument,
        ),
      ),
    );
    await expectLater(
      core.openAccountRecord(
        reopenedKeyring,
        recordId: recordId,
        keyEpoch: 1,
        associatedData: associatedData,
        envelope: epochOneEnvelope,
      ),
      throwsA(
        isA<KelivoSecureCoreException>().having(
          (error) => error.status,
          'status',
          KelivoSecureCoreStatus.recordAuthenticationFailed,
        ),
      ),
    );
    await expectLater(
      core.pruneAccountRootKeyEpoch(reopenedKeyring, keyEpoch: 2),
      throwsA(
        isA<KelivoSecureCoreException>().having(
          (error) => error.status,
          'status',
          KelivoSecureCoreStatus.invalidArgument,
        ),
      ),
    );

    await core.closeAccountRootKey(duplicate);
    await core.closeAccountRootKey(epochTwo);
    await core.closeAccountRootKey(reopenedKeyring);
    await core.closeDeviceIdentity(reopened.identity);
    await core.closeAccountRootKey(keyring);
    await core.closeDeviceIdentity(identity);
    await core.close(key);
  });

  test('账户信任根签名跨恢复保持确定性并严格绑定账户代次与载荷', () async {
    if (!(await core.getCapabilities()).supportsAccountTrustSigning) return;
    final key = await openOrCreateTestSlot();
    final identity = await core.generateDeviceIdentity();
    final userId = accountId(0x71);
    final otherUserId = accountId(0x72);
    final generationUserId = Uint8List.fromList(userId);
    final keyringFuture = core.generateAccountRootKey(
      userId: generationUserId,
      keyEpoch: 7,
    );
    generationUserId[0] ^= 1;
    final keyring = await keyringFuture;
    final epochEight = await core.generateAccountRootKey(
      userId: userId,
      keyEpoch: 8,
    );
    await core.addAccountRootKeyEpoch(keyring, source: epochEight);
    expect(keyring.userId, orderedEquals(userId));
    expect(() => keyring.userId[0] ^= 1, throwsUnsupportedError);
    final crossAccountEpoch = await core.generateAccountRootKey(
      userId: otherUserId,
      keyEpoch: 9,
    );
    await expectLater(
      core.addAccountRootKeyEpoch(keyring, source: crossAccountEpoch),
      throwsArgumentError,
    );
    await expectLater(
      core.deriveAccountTrustPublicKey(
        keyring,
        userId: otherUserId,
        keyEpoch: 7,
      ),
      throwsArgumentError,
    );
    await expectLater(
      core.signAccountTrustPayload(
        keyring,
        userId: otherUserId,
        keyEpoch: 7,
        canonicalPayload: Uint8List.fromList('member-set-v1'.codeUnits),
      ),
      throwsArgumentError,
    );
    await core.closeAccountRootKey(crossAccountEpoch);
    final deviceId = accountId(0x73);
    final payload = Uint8List.fromList('member-set-v1'.codeUnits);
    final changedPayload = Uint8List.fromList('member-set-v2'.codeUnits);

    final publicKey = await core.deriveAccountTrustPublicKey(
      keyring,
      userId: userId,
      keyEpoch: 7,
    );
    final repeatedPublicKey = await core.deriveAccountTrustPublicKey(
      keyring,
      userId: userId,
      keyEpoch: 7,
    );
    final nextEpochPublicKey = await core.deriveAccountTrustPublicKey(
      keyring,
      userId: userId,
      keyEpoch: 8,
    );
    expect(publicKey.bytes, hasLength(32));
    expect(publicKey.bytes, orderedEquals(repeatedPublicKey.bytes));
    expect(publicKey.bytes, isNot(orderedEquals(nextEpochPublicKey.bytes)));
    expect(() => publicKey.bytes[0] ^= 1, throwsUnsupportedError);

    final signature = await core.signAccountTrustPayload(
      keyring,
      userId: userId,
      keyEpoch: 7,
      canonicalPayload: payload,
    );
    final repeatedSignature = await core.signAccountTrustPayload(
      keyring,
      userId: userId,
      keyEpoch: 7,
      canonicalPayload: payload,
    );
    expect(signature.bytes, hasLength(64));
    expect(signature.bytes, orderedEquals(repeatedSignature.bytes));
    expect(() => signature.bytes[0] ^= 1, throwsUnsupportedError);
    await core.verifyAccountTrustPayload(
      publicKey,
      userId: userId,
      keyEpoch: 7,
      canonicalPayload: payload,
      signature: signature,
    );

    for (final invalidVerification in <Future<void> Function()>[
      () => core.verifyAccountTrustPayload(
        publicKey,
        userId: otherUserId,
        keyEpoch: 7,
        canonicalPayload: payload,
        signature: signature,
      ),
      () => core.verifyAccountTrustPayload(
        publicKey,
        userId: userId,
        keyEpoch: 8,
        canonicalPayload: payload,
        signature: signature,
      ),
      () => core.verifyAccountTrustPayload(
        publicKey,
        userId: userId,
        keyEpoch: 7,
        canonicalPayload: changedPayload,
        signature: signature,
      ),
      () => core.verifyAccountTrustPayload(
        publicKey,
        userId: userId,
        keyEpoch: 7,
        canonicalPayload: payload,
        signature: KelivoAccountTrustSignature(
          Uint8List.fromList(signature.bytes)..[0] ^= 1,
        ),
      ),
    ]) {
      await expectLater(
        invalidVerification(),
        throwsA(
          isA<KelivoSecureCoreException>().having(
            (error) => error.status,
            'status',
            KelivoSecureCoreStatus.deviceAuthenticationFailed,
          ),
        ),
      );
    }

    final stateBlob = await core.sealDeviceState(
      key,
      identity,
      deviceId: deviceId,
      keyVersion: 1,
      ark: keyring,
      account: KelivoDeviceStateAccountBinding(userId: userId, keyEpoch: 8),
    );
    final reopened = await core.openDeviceState(key, stateBlob: stateBlob);
    final reopenedKeyring = reopened.ark!;
    expect(reopenedKeyring.userId, orderedEquals(userId));
    final recoveredPublicKey = await core.deriveAccountTrustPublicKey(
      reopenedKeyring,
      userId: userId,
      keyEpoch: 7,
    );
    final recoveredSignature = await core.signAccountTrustPayload(
      reopenedKeyring,
      userId: userId,
      keyEpoch: 7,
      canonicalPayload: payload,
    );
    expect(recoveredPublicKey.bytes, orderedEquals(publicKey.bytes));
    expect(recoveredSignature.bytes, orderedEquals(signature.bytes));
    await core.verifyAccountTrustPayload(
      recoveredPublicKey,
      userId: userId,
      keyEpoch: 7,
      canonicalPayload: payload,
      signature: recoveredSignature,
    );

    await expectLater(
      core.signAccountTrustPayload(
        reopenedKeyring,
        userId: userId,
        keyEpoch: 7,
        canonicalPayload: Uint8List(0),
      ),
      throwsArgumentError,
    );
    await expectLater(
      core.signAccountTrustPayload(
        reopenedKeyring,
        userId: userId,
        keyEpoch: 7,
        canonicalPayload: Uint8List(65537),
      ),
      throwsArgumentError,
    );
    await expectLater(
      core.deriveAccountTrustPublicKey(
        reopenedKeyring,
        userId: userId,
        keyEpoch: 9,
      ),
      throwsA(
        isA<KelivoSecureCoreException>().having(
          (error) => error.status,
          'status',
          KelivoSecureCoreStatus.invalidArgument,
        ),
      ),
    );

    final maximumPayload = Uint8List(65536)..fillRange(0, 65536, 0xa5);
    final pendingSignature = core.signAccountTrustPayload(
      reopenedKeyring,
      userId: userId,
      keyEpoch: 8,
      canonicalPayload: maximumPayload,
    );
    await expectLater(
      core.closeAccountRootKey(reopenedKeyring),
      throwsStateError,
    );
    final maximumSignature = await pendingSignature;
    await core.verifyAccountTrustPayload(
      nextEpochPublicKey,
      userId: userId,
      keyEpoch: 8,
      canonicalPayload: maximumPayload,
      signature: maximumSignature,
    );

    await core.pruneAccountRootKeyEpoch(reopenedKeyring, keyEpoch: 7);
    await expectLater(
      core.deriveAccountTrustPublicKey(
        reopenedKeyring,
        userId: userId,
        keyEpoch: 7,
      ),
      throwsA(
        isA<KelivoSecureCoreException>().having(
          (error) => error.status,
          'status',
          KelivoSecureCoreStatus.invalidArgument,
        ),
      ),
    );
    await core.closeAccountRootKey(reopenedKeyring);
    await expectLater(
      core.deriveAccountTrustPublicKey(
        reopenedKeyring,
        userId: userId,
        keyEpoch: 8,
      ),
      throwsStateError,
    );

    await core.closeDeviceIdentity(reopened.identity);
    await core.closeAccountRootKey(epochEight);
    await core.closeAccountRootKey(keyring);
    await core.closeDeviceIdentity(identity);
    await core.close(key);
  });

  test('一次性 pending 配对失败可重试且成功后原子消费', () async {
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final key = await openOrCreateTestSlot();
    final issuerIdentity = await core.generateDeviceIdentity();
    final targetIdentity = await core.generateDeviceIdentity();
    final issuerDeviceId = accountId(0x51);
    final targetDeviceId = accountId(0x52);
    final userId = accountId(0x53);
    final issuerArk = await core.generateAccountRootKey(
      userId: userId,
      keyEpoch: 7,
    );
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
    expect(pendingState, hasLength(448));
    await core.closeDeviceIdentity(targetIdentity);

    final reopenedPending = await core.openDeviceState(
      key,
      stateBlob: pendingState,
    );
    expect(reopenedPending.ark, isNull);
    expect(reopenedPending.binding.deviceId, orderedEquals(targetDeviceId));
    expect(reopenedPending.binding.keyVersion, keyVersion);
    expect(reopenedPending.binding.account, isNull);
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
    final bindingUserId = Uint8List.fromList(userId);
    final binding = core.bindPendingPairing(
      pending.state,
      pairingId: pending.pairingId,
      userId: bindingUserId,
      targetDeviceId: targetDeviceId,
      targetKeyVersion: keyVersion,
      targetPublicKeys: targetPublicKeys,
      expiresAtMs: expiresAtMs,
      challenge: challenge,
      nowMs: nowMs,
    );
    bindingUserId[0] ^= 1;
    await binding;
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
      nowMs: expiresAtMs - 1,
      issuerDeviceId: issuerDeviceId,
      keyEpoch: keyEpoch,
      issuerPublicKeys: issuerPublicKeys,
      approval: approval,
    );
    expect(accepted.ark.userId, orderedEquals(userId));
    expect(accepted.stateBlob, hasLength(448));
    await expectLater(
      core.acceptPairingApproval(
        key,
        reopenedPending.identity,
        pending.state,
        nowMs: expiresAtMs - 1,
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
    );
    expect(reopenedFull.ark, isNotNull);
    expect(reopenedFull.binding.deviceId, orderedEquals(targetDeviceId));
    expect(reopenedFull.binding.keyVersion, keyVersion);
    expect(reopenedFull.binding.account?.userId, orderedEquals(userId));
    expect(reopenedFull.binding.account?.keyEpoch, keyEpoch);
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

  test('附件数据密钥全程保持不透明并可经 ARK 包装后跨句柄解密', () async {
    if (!(await core.getCapabilities()).supportsAttachmentCrypto) return;
    final userId = accountId(0x81);
    final ark = await core.generateAccountRootKey(userId: userId, keyEpoch: 7);
    final created = await core.generateAttachmentDataKey();
    final context = KelivoAttachmentContext(
      userId: userId,
      attachmentId: created.attachmentId,
      keyEpoch: 7,
    );
    final uploadContext = KelivoAttachmentUploadContext(
      attachment: context,
      uploadId: accountId(0x91),
    );
    final plaintext = Uint8List.fromList('encrypted attachment'.codeUnits);
    final layout = KelivoAttachmentLayout(
      totalPlaintextBytes: plaintext.length,
    );

    expect(created.attachmentId[6] & 0xf0, 0x40);
    expect(created.attachmentId[8] & 0xc0, 0x80);
    expect(created.key.toString(), 'KelivoAttachmentDataKeyHandle(opaque)');

    final wrapped = await core.wrapAttachmentDataKey(
      ark,
      created.key,
      context: context,
    );
    expect(wrapped, hasLength(KelivoAttachmentLimits.wrappedDataKeyBytes));
    final reopened = await core.unwrapAttachmentDataKey(
      ark,
      context: context,
      wrappedKey: wrapped,
    );
    final chunk = await core.sealAttachmentChunk(
      created.key,
      uploadContext: uploadContext,
      layout: layout,
      chunkIndex: 0,
      plaintext: plaintext,
    );
    final storedChunk = Uint8List.fromList(chunk);

    expect(
      await core.openAttachmentChunk(
        reopened,
        uploadContext: uploadContext,
        layout: layout,
        chunkIndex: 0,
        envelope: chunk,
      ),
      orderedEquals(plaintext),
    );
    expect(chunk, orderedEquals(storedChunk));

    await core.closeAttachmentDataKey(created.key);
    await core.closeAttachmentDataKey(created.key);
    await expectLater(
      core.sealAttachmentChunk(
        created.key,
        uploadContext: uploadContext,
        layout: layout,
        chunkIndex: 0,
        plaintext: plaintext,
      ),
      throwsStateError,
    );
    await core.closeAttachmentDataKey(reopened);
    await core.closeAccountRootKey(ark);
  });

  test('附件块拒绝篡改、截断、替换及所有认证上下文错配', () async {
    if (!(await core.getCapabilities()).supportsAttachmentCrypto) return;
    final userId = accountId(0x82);
    final ark = await core.generateAccountRootKey(userId: userId, keyEpoch: 11);
    final otherArk = await core.generateAccountRootKey(
      userId: userId,
      keyEpoch: 11,
    );
    final created = await core.generateAttachmentDataKey();
    final replacement = await core.generateAttachmentDataKey();
    final context = KelivoAttachmentContext(
      userId: userId,
      attachmentId: created.attachmentId,
      keyEpoch: 11,
    );
    final uploadId = accountId(0x92);
    final uploadContext = KelivoAttachmentUploadContext(
      attachment: context,
      uploadId: uploadId,
    );
    final wrongAccountContext = KelivoAttachmentContext(
      userId: accountId(0x83),
      attachmentId: created.attachmentId,
      keyEpoch: 11,
    );
    final wrongContexts = <KelivoAttachmentContext>[
      KelivoAttachmentContext(
        userId: accountId(0x82),
        attachmentId: replacement.attachmentId,
        keyEpoch: 11,
      ),
      KelivoAttachmentContext(
        userId: accountId(0x82),
        attachmentId: created.attachmentId,
        keyEpoch: 12,
      ),
    ];
    final plaintext = Uint8List.fromList('authenticated chunk'.codeUnits);
    final layout = KelivoAttachmentLayout(
      totalPlaintextBytes: plaintext.length,
    );
    final wrapped = await core.wrapAttachmentDataKey(
      ark,
      created.key,
      context: context,
    );
    final chunk = await core.sealAttachmentChunk(
      created.key,
      uploadContext: uploadContext,
      layout: layout,
      chunkIndex: 0,
      plaintext: plaintext,
    );
    final authenticationFailure = throwsA(
      isA<KelivoSecureCoreException>().having(
        (error) => error.status,
        'status',
        KelivoSecureCoreStatus.attachmentAuthenticationFailed,
      ),
    );

    await expectLater(
      core.unwrapAttachmentDataKey(
        otherArk,
        context: context,
        wrappedKey: wrapped,
      ),
      authenticationFailure,
    );
    await expectLater(
      core.unwrapAttachmentDataKey(
        ark,
        context: wrongAccountContext,
        wrappedKey: wrapped,
      ),
      throwsArgumentError,
    );
    await expectLater(
      core.openAttachmentChunk(
        created.key,
        uploadContext: KelivoAttachmentUploadContext(
          attachment: wrongAccountContext,
          uploadId: uploadId,
        ),
        layout: layout,
        chunkIndex: 0,
        envelope: chunk,
      ),
      authenticationFailure,
    );
    for (final wrongContext in wrongContexts) {
      await expectLater(
        core.unwrapAttachmentDataKey(
          ark,
          context: wrongContext,
          wrappedKey: wrapped,
        ),
        authenticationFailure,
      );
      await expectLater(
        core.openAttachmentChunk(
          created.key,
          uploadContext: KelivoAttachmentUploadContext(
            attachment: wrongContext,
            uploadId: uploadId,
          ),
          layout: layout,
          chunkIndex: 0,
          envelope: chunk,
        ),
        authenticationFailure,
      );
    }
    await expectLater(
      core.openAttachmentChunk(
        created.key,
        uploadContext: KelivoAttachmentUploadContext(
          attachment: context,
          uploadId: accountId(0x93),
        ),
        layout: layout,
        chunkIndex: 0,
        envelope: chunk,
      ),
      authenticationFailure,
    );

    final tamperedWrapped = Uint8List.fromList(wrapped)
      ..[wrapped.length - 1] ^= 1;
    await expectLater(
      core.unwrapAttachmentDataKey(
        ark,
        context: context,
        wrappedKey: tamperedWrapped,
      ),
      authenticationFailure,
    );
    await expectLater(
      core.unwrapAttachmentDataKey(
        ark,
        context: context,
        wrappedKey: Uint8List.sublistView(wrapped, 0, wrapped.length - 1),
      ),
      throwsA(
        isA<KelivoSecureCoreException>().having(
          (error) => error.status,
          'status',
          KelivoSecureCoreStatus.attachmentEnvelopeInvalid,
        ),
      ),
    );

    final tampered = Uint8List.fromList(chunk)..[chunk.length - 1] ^= 1;
    await expectLater(
      core.openAttachmentChunk(
        created.key,
        uploadContext: uploadContext,
        layout: layout,
        chunkIndex: 0,
        envelope: tampered,
      ),
      authenticationFailure,
    );
    await expectLater(
      core.openAttachmentChunk(
        created.key,
        uploadContext: uploadContext,
        layout: layout,
        chunkIndex: 0,
        envelope: Uint8List.sublistView(chunk, 0, chunk.length - 1),
      ),
      throwsA(
        isA<KelivoSecureCoreException>().having(
          (error) => error.status,
          'status',
          KelivoSecureCoreStatus.attachmentEnvelopeInvalid,
        ),
      ),
    );
    await expectLater(
      core.openAttachmentChunk(
        replacement.key,
        uploadContext: uploadContext,
        layout: layout,
        chunkIndex: 0,
        envelope: chunk,
      ),
      authenticationFailure,
    );

    await core.closeAttachmentDataKey(replacement.key);
    await core.closeAttachmentDataKey(created.key);
    await core.closeAccountRootKey(otherArk);
    await core.closeAccountRootKey(ark);
  });

  test('附件固定分块覆盖空块、最大块、重排与非法边界', () async {
    if (!(await core.getCapabilities()).supportsAttachmentCrypto) return;
    final created = await core.generateAttachmentDataKey();
    final context = KelivoAttachmentContext(
      userId: accountId(0x84),
      attachmentId: created.attachmentId,
      keyEpoch: 0xffffffff,
    );
    final uploadContext = KelivoAttachmentUploadContext(
      attachment: context,
      uploadId: accountId(0x94),
    );
    final emptyLayout = KelivoAttachmentLayout(totalPlaintextBytes: 0);
    expect(emptyLayout.chunkCount, 1);
    expect(
      emptyLayout.totalCiphertextBytes,
      KelivoAttachmentLimits.chunkEnvelopeOverheadBytes,
    );

    final emptyEnvelope = await core.sealAttachmentChunk(
      created.key,
      uploadContext: uploadContext,
      layout: emptyLayout,
      chunkIndex: 0,
      plaintext: Uint8List(0),
    );
    expect(
      await core.openAttachmentChunk(
        created.key,
        uploadContext: uploadContext,
        layout: emptyLayout,
        chunkIndex: 0,
        envelope: emptyEnvelope,
      ),
      isEmpty,
    );

    final maximumChunk = Uint8List(KelivoAttachmentLimits.chunkPlaintextBytes)
      ..fillRange(0, KelivoAttachmentLimits.chunkPlaintextBytes, 0xa5);
    final twoChunkLayout = KelivoAttachmentLayout(
      totalPlaintextBytes: KelivoAttachmentLimits.chunkPlaintextBytes + 1,
    );
    expect(twoChunkLayout.chunkCount, 2);
    expect(
      twoChunkLayout.totalCiphertextBytes,
      twoChunkLayout.totalPlaintextBytes +
          2 * KelivoAttachmentLimits.chunkEnvelopeOverheadBytes,
    );
    final firstEnvelope = await core.sealAttachmentChunk(
      created.key,
      uploadContext: uploadContext,
      layout: twoChunkLayout,
      chunkIndex: 0,
      plaintext: maximumChunk,
    );
    expect(
      firstEnvelope,
      hasLength(KelivoAttachmentLimits.maxChunkEnvelopeBytes),
    );
    expect(
      await core.openAttachmentChunk(
        created.key,
        uploadContext: uploadContext,
        layout: twoChunkLayout,
        chunkIndex: 0,
        envelope: firstEnvelope,
      ),
      orderedEquals(maximumChunk),
    );
    final lastPlaintext = Uint8List.fromList([0x5a]);
    final lastEnvelope = await core.sealAttachmentChunk(
      created.key,
      uploadContext: uploadContext,
      layout: twoChunkLayout,
      chunkIndex: 1,
      plaintext: lastPlaintext,
    );
    expect(
      await core.openAttachmentChunk(
        created.key,
        uploadContext: uploadContext,
        layout: twoChunkLayout,
        chunkIndex: 1,
        envelope: lastEnvelope,
      ),
      orderedEquals(lastPlaintext),
    );
    expect(
      firstEnvelope.length + lastEnvelope.length,
      twoChunkLayout.totalCiphertextBytes,
    );
    await expectLater(
      core.openAttachmentChunk(
        created.key,
        uploadContext: uploadContext,
        layout: twoChunkLayout,
        chunkIndex: 1,
        envelope: firstEnvelope,
      ),
      throwsA(
        isA<KelivoSecureCoreException>().having(
          (error) => error.status,
          'status',
          KelivoSecureCoreStatus.attachmentAuthenticationFailed,
        ),
      ),
    );

    expect(
      () => KelivoAttachmentLayout(
        totalPlaintextBytes: KelivoAttachmentLimits.maxTotalPlaintextBytes + 1,
      ),
      throwsArgumentError,
    );
    await expectLater(
      core.sealAttachmentChunk(
        created.key,
        uploadContext: uploadContext,
        layout: KelivoAttachmentLayout(totalPlaintextBytes: 1),
        chunkIndex: 0,
        plaintext: Uint8List(0),
      ),
      throwsArgumentError,
    );
    expect(
      () => KelivoAttachmentContext(
        userId: Uint8List(16),
        attachmentId: created.attachmentId,
        keyEpoch: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => KelivoAttachmentUploadContext(
        attachment: context,
        uploadId: Uint8List(16),
      ),
      throwsArgumentError,
    );
    expect(
      () => KelivoAttachmentContext(
        userId: accountId(0x85),
        attachmentId: created.attachmentId,
        keyEpoch: 0,
      ),
      throwsArgumentError,
    );

    await core.closeAttachmentDataKey(created.key);
  });
}
