import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';

import 'package:Kelivo/core/services/sync/e2ee_account_authenticator.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_client.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_pairing_qr_codec.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_record_types.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_record_cipher.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_record_state.dart';
import 'package:Kelivo/core/services/sync/sync_codec.dart';
import 'package:Kelivo/core/services/workspace/device_state_blob_store.dart';

const _mutationId1 = '00000000-0000-4000-8000-000000000001';
const _mutationId2 = '00000000-0000-4000-8000-000000000002';
const _mutationId3 = '00000000-0000-4000-8000-000000000003';
const _recordId1 = '10000000-0000-4000-8000-000000000001';
const _recordId2 = '10000000-0000-4000-8000-000000000002';
const _deviceId1 = '20000000-0000-4000-8000-000000000001';
const _deviceId2 = '20000000-0000-4000-8000-000000000002';
const _attemptId1 = '30000000-0000-4000-8000-000000000001';
const _attemptId2 = '30000000-0000-4000-8000-000000000002';
const _userId = '40000000-0000-4000-8000-000000000001';
const _accountContextId = '50000000-0000-4000-8000-000000000001';
const _pairingId = '60000000-0000-4000-8000-000000000001';
const _issuerDeviceId = '70000000-0000-4000-8000-000000000001';
const _fullTokenValue = 'kelivo_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _otherFullTokenValue =
    'kelivo_BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';
const _onboardingTokenValue =
    'kelivo_onboarding_BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';

final _fullToken = CloudSyncFullSessionToken.parse(_fullTokenValue);
final _otherFullToken = CloudSyncFullSessionToken.parse(_otherFullTokenValue);
final _onboardingToken = CloudSyncOnboardingToken.parse(_onboardingTokenValue);

Uint8List _filledBytes(int length, [int value = 0]) {
  return Uint8List.fromList(List<int>.filled(length, value));
}

String _encodedBytes(int length, [int value = 0]) {
  return base64Url.encode(_filledBytes(length, value)).replaceAll('=', '');
}

String _encodedRecordCiphertext(E2eeSealedAccountRecordEnvelope record) {
  return base64Url.encode(record.ciphertext).replaceAll('=', '');
}

E2eeUntrustedAccountRecordEnvelope _untrustedRecord(
  E2eeSealedAccountRecordEnvelope record, {
  E2eeUntrustedAccountRecordId? recordId,
  int? keyEpoch,
  Uint8List? ciphertext,
}) {
  return E2eeUntrustedAccountRecordEnvelope.fromTransport(
    recordId:
        recordId ??
        E2eeUntrustedAccountRecordId.fromTransport(record.recordId.wireValue),
    envelopeVersion: e2eeAccountRecordEnvelopeVersion,
    keyEpoch: keyEpoch ?? record.keyEpoch,
    ciphertext: ciphertext ?? record.ciphertext,
  );
}

Future<E2eeUntrustedAccountRecordEnvelope> _sealRawAccountRecord({
  required KelivoSecureCore core,
  required KelivoAccountRootKeyHandle ark,
  required SyncEntityKey recordIdKey,
  required SyncEntityKey frameKey,
  required String userId,
  int keyEpoch = 7,
}) async {
  final canonicalKey = _recordCanonicalKey(recordIdKey);
  final frame = _recordPlaintextFrame(frameKey, Uint8List(0));
  final associatedData = _recordAssociatedData(userId);
  Uint8List? ciphertext;
  try {
    final recordId = await core.deriveAccountRecordId(
      ark,
      canonicalEntityKey: canonicalKey,
    );
    ciphertext = await core.sealAccountRecord(
      ark,
      recordId: recordId,
      keyEpoch: keyEpoch,
      associatedData: associatedData,
      plaintext: frame,
    );
    return E2eeUntrustedAccountRecordEnvelope.fromTransport(
      recordId: E2eeUntrustedAccountRecordId.fromTransport(
        _uuidStringForTest(recordId),
      ),
      envelopeVersion: e2eeAccountRecordEnvelopeVersion,
      keyEpoch: keyEpoch,
      ciphertext: ciphertext,
    );
  } finally {
    canonicalKey.fillRange(0, canonicalKey.length, 0);
    frame.fillRange(0, frame.length, 0);
    associatedData.fillRange(0, associatedData.length, 0);
    ciphertext?.fillRange(0, ciphertext.length, 0);
  }
}

Uint8List _recordCanonicalKey(SyncEntityKey key) {
  final typeBytes = utf8.encode(key.entityType);
  final idBytes = utf8.encode(key.entityId);
  final result = Uint8List(20 + typeBytes.length + idBytes.length);
  result.setRange(0, 8, ascii.encode('KELVRK01'));
  final fields = ByteData.sublistView(result);
  fields.setUint16(8, 1, Endian.big);
  fields.setUint32(12, typeBytes.length, Endian.big);
  fields.setUint32(16, idBytes.length, Endian.big);
  result.setRange(20, 20 + typeBytes.length, typeBytes);
  result.setRange(20 + typeBytes.length, result.length, idBytes);
  return result;
}

Uint8List _recordPlaintextFrame(SyncEntityKey key, Uint8List payload) {
  final typeBytes = utf8.encode(key.entityType);
  final idBytes = utf8.encode(key.entityId);
  final result = Uint8List(
    24 + typeBytes.length + idBytes.length + payload.length,
  );
  result.setRange(0, 8, ascii.encode('KELVRF01'));
  final fields = ByteData.sublistView(result);
  fields.setUint16(8, 1, Endian.big);
  fields.setUint32(12, typeBytes.length, Endian.big);
  fields.setUint32(16, idBytes.length, Endian.big);
  fields.setUint32(20, payload.length, Endian.big);
  result.setRange(24, 24 + typeBytes.length, typeBytes);
  result.setRange(
    24 + typeBytes.length,
    24 + typeBytes.length + idBytes.length,
    idBytes,
  );
  result.setRange(
    24 + typeBytes.length + idBytes.length,
    result.length,
    payload,
  );
  return result;
}

Uint8List _recordAssociatedData(String userId) {
  final result = Uint8List(28);
  result.setRange(0, 8, ascii.encode('KELVRA01'));
  final fields = ByteData.sublistView(result);
  fields.setUint16(8, 1, Endian.big);
  fields.setUint16(10, e2eeAccountRecordSyncProtocolVersion, Endian.big);
  result.setRange(12, 28, _rawUuid(userId));
  return result;
}

CloudSyncOpaqueDeviceIdentity _deviceIdentity() {
  return CloudSyncOpaqueDeviceIdentity(
    deviceId: _deviceId1,
    deviceName: 'Windows 主机',
    platform: CloudSyncPlatform.windows,
    clientVersion: '1.2.3',
    deviceKeyVersion: 1,
    signingPublicKey: _filledBytes(cloudSyncDevicePublicKeyBytes, 1),
    keyAgreementPublicKey: _filledBytes(cloudSyncDevicePublicKeyBytes, 2),
  );
}

Map<String, Object?> _authenticatedData({
  String token = _fullTokenValue,
  int keyEpoch = 7,
  String deviceId = _deviceId1,
  String loginName = 'alice',
}) {
  return <String, Object?>{
    'protocolVersion': cloudSyncOpaqueProtocolVersion,
    'result': 'authenticated',
    'keyEpoch': keyEpoch,
    'token': token,
    'tokenExpiresAt': '2026-07-27T05:00:00.000Z',
    'user': <String, Object?>{
      'id': _userId,
      'loginName': loginName,
      'displayName': 'Alice',
      'role': 'owner',
      'attachmentQuotaBytes': 1048576,
    },
    'device': <String, Object?>{
      'id': deviceId,
      'name': 'Windows 主机',
      'platform': 'windows',
      'clientVersion': '1.2.3',
      'status': 'active',
      'createdAt': '2026-07-26T05:00:00.000Z',
    },
  };
}

Map<String, Object?> _pairingTargetJson() {
  return <String, Object?>{
    'id': _deviceId2,
    'name': 'Android 手机',
    'platform': 'android',
    'clientVersion': '1.2.3',
    'keyVersion': 1,
    'authGeneration': 0,
    'signingPublicKey': _encodedBytes(cloudSyncDevicePublicKeyBytes, 4),
    'keyAgreementPublicKey': _encodedBytes(cloudSyncDevicePublicKeyBytes, 5),
  };
}

CloudSyncDevicePairingCreated _pairingQrCreated({DateTime? expiresAt}) {
  return CloudSyncDevicePairingCreated(
    pairingId: _pairingId,
    accountContextId: _userId,
    challenge: _filledBytes(cloudSyncDeviceChallengeBytes, 18),
    expiresAt: expiresAt ?? DateTime.utc(2026, 7, 26, 5, 5),
    targetDevice: CloudSyncDevicePairingTarget(
      id: _deviceId2,
      name: 'Android 手机',
      platform: CloudSyncPlatform.android,
      clientVersion: '1.2.3',
      keyVersion: 1,
      authGeneration: 0,
      signingPublicKey: _filledBytes(cloudSyncDevicePublicKeyBytes, 4),
      keyAgreementPublicKey: _filledBytes(cloudSyncDevicePublicKeyBytes, 5),
    ),
  );
}

CloudSyncDevicePairingQrPayload _pairingQrPayload({
  required Uint8List pairingSecret,
  DateTime? now,
  DateTime? expiresAt,
  int protocolVersion = cloudSyncOpaqueProtocolVersion,
  CloudSyncPlatform platform = CloudSyncPlatform.android,
  String deviceName = 'Android 手机',
  String clientVersion = '1.2.3',
  int keyVersion = 1,
  String pairingId = _pairingId,
  String accountContextId = _userId,
  String targetDeviceId = _deviceId2,
  Uint8List? challenge,
  Uint8List? signingPublicKey,
  Uint8List? keyAgreementPublicKey,
}) {
  return CloudSyncDevicePairingQrPayload.takeOwnership(
    protocolVersion: protocolVersion,
    platform: platform,
    untrustedDeviceName: deviceName,
    untrustedClientVersion: clientVersion,
    keyVersion: keyVersion,
    expiresAt: expiresAt ?? DateTime.utc(2026, 7, 26, 5, 5),
    pairingId: pairingId,
    accountContextId: accountContextId,
    targetDeviceId: targetDeviceId,
    challenge: challenge ?? _filledBytes(cloudSyncDeviceChallengeBytes, 18),
    signingPublicKey:
        signingPublicKey ?? _filledBytes(cloudSyncDevicePublicKeyBytes, 4),
    keyAgreementPublicKey:
        keyAgreementPublicKey ?? _filledBytes(cloudSyncDevicePublicKeyBytes, 5),
    pairingSecret: pairingSecret,
    now: now ?? DateTime.utc(2026, 7, 26, 5),
  );
}

Uint8List _validPairingQrFrame() {
  final payload = _pairingQrPayload(
    pairingSecret: _filledBytes(cloudSyncPairingSecretBytes, 24),
  );
  try {
    return CloudSyncDevicePairingQrCodec.encode(
      payload,
      now: DateTime.utc(2026, 7, 26, 5),
    );
  } finally {
    payload.dispose();
  }
}

void _refreshPairingQrCrc(Uint8List frame) {
  final crcOffset = frame.length - 4;
  ByteData.sublistView(frame).setUint32(
    crcOffset,
    getCrc32(Uint8List.sublistView(frame, 0, crcOffset)),
    Endian.big,
  );
}

Map<String, Object?> _trustedDeviceJson({String status = 'active'}) {
  return <String, Object?>{
    'id': _deviceId2,
    'name': 'Android 手机',
    'platform': 'android',
    'clientVersion': '1.2.3',
    'status': status,
    'createdAt': '2026-07-26T05:00:00.000Z',
    'lastSeenAt': '2026-07-26T06:00:00.000Z',
    'revokedAt': status == 'revoked' ? '2026-07-26T07:00:00.000Z' : null,
    'isCurrent': false,
  };
}

void main() {
  test('桌面端不能注册首个可信设备且不会创建本地设备状态', () async {
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_authenticator_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
    final client = CloudSyncClient.forTesting(baseUrl: 'http://127.0.0.1:1');
    final store = DeviceStateBlobStore(installationRoot: root);
    final authenticator = E2eeAccountAuthenticator(
      baseUrl: 'http://127.0.0.1:1',
      accountClient: client,
      deviceStateStore: store,
      secureCore: const KelivoSecureCore(),
    );
    addTearDown(() async {
      client.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });

    final password = Uint8List.fromList(utf8.encode('password'));
    await expectLater(
      authenticator.registerFirstDevice(
        loginName: 'desktop-user',
        displayName: 'Desktop User',
        password: password,
        deviceName: 'Windows 主机',
        platform: CloudSyncPlatform.windows,
        clientVersion: '1.2.3',
      ),
      throwsA(isA<UnsupportedError>()),
    );
    expect(password, everyElement(0));
    expect(
      await store.read(
        normalizedBaseUrl: 'http://127.0.0.1:1',
        normalizedLoginName: 'desktop-user',
      ),
      isNull,
    );
  });

  test('业务校验与密码清理同时失败时保留主异常', () async {
    final client = CloudSyncClient.forTesting(baseUrl: 'http://127.0.0.1:1');
    client.setToken(_fullToken);
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_authenticator_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
    final authenticator = E2eeAccountAuthenticator(
      baseUrl: 'http://127.0.0.1:1',
      accountClient: client,
      deviceStateStore: DeviceStateBlobStore(installationRoot: root),
      secureCore: const KelivoSecureCore(),
    );
    addTearDown(() async {
      client.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });

    final readOnlyPassword = Uint8List.fromList(
      utf8.encode('password'),
    ).asUnmodifiableView();
    await expectLater(
      authenticator.loginDevice(
        loginName: 'invalid login name',
        password: readOnlyPassword,
        deviceName: 'Windows 主机',
        platform: CloudSyncPlatform.windows,
        clientVersion: '1.2.3',
      ),
      throwsA(
        isA<CloudSyncException>().having(
          (error) => error.kind,
          'kind',
          CloudSyncFailureKind.validation,
        ),
      ),
    );
    await expectLater(
      client.listDevices(),
      throwsA(
        isA<CloudSyncException>().having(
          (error) => error.kind,
          'kind',
          CloudSyncFailureKind.unauthenticated,
        ),
      ),
    );
  });

  test('登录网络失败后保留可认证重开的设备状态且不会伪成功', () async {
    const core = KelivoSecureCore();
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_authenticator_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
    const baseUrl = 'http://127.0.0.1:1';
    const normalizedLoginName = 'network-user';
    final client = CloudSyncClient.forTesting(baseUrl: baseUrl);
    final store = DeviceStateBlobStore(installationRoot: root);
    final authenticator = E2eeAccountAuthenticator(
      baseUrl: '$baseUrl/',
      accountClient: client,
      deviceStateStore: store,
      secureCore: core,
    );
    addTearDown(() async {
      client.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });

    Future<void> login() async {
      await authenticator.loginDevice(
        loginName: ' Network-User ',
        password: Uint8List.fromList(utf8.encode('password')),
        deviceName: 'Windows 主机',
        platform: CloudSyncPlatform.windows,
        clientVersion: '1.2.3',
      );
    }

    await expectLater(login(), throwsA(isA<CloudSyncException>()));
    final firstBlob = await store.read(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    expect(firstBlob, hasLength(DeviceStateBlobStore.blobLength));

    await expectLater(login(), throwsA(isA<CloudSyncException>()));
    final secondBlob = await store.read(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    expect(secondBlob, orderedEquals(firstBlob!));
  });

  test('同一认证器并发登录时第二个操作失败关闭', () async {
    const core = KelivoSecureCore();
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final baseUrl = 'http://${server.address.address}:${server.port}';
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_authenticator_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
    final store = DeviceStateBlobStore(installationRoot: root);
    final client = CloudSyncClient.forTesting(baseUrl: baseUrl);
    final authenticator = E2eeAccountAuthenticator(
      baseUrl: baseUrl,
      accountClient: client,
      deviceStateStore: store,
      secureCore: core,
    );
    final firstRequestArrived = Completer<void>();
    final releaseFirstRequest = Completer<void>();
    var requestCount = 0;
    final subscription = server.listen((request) async {
      requestCount++;
      if (requestCount == 1) {
        firstRequestArrived.complete();
        await releaseFirstRequest.future;
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{
          'data': <String, Object?>{
            'protocolVersion': cloudSyncOpaqueProtocolVersion,
            'attemptId': _attemptId1,
            'accountBinding': _accountContextId,
            'deviceChallenge': _encodedBytes(cloudSyncDeviceChallengeBytes, 1),
            'credentialResponse': _encodedBytes(
              cloudSyncOpaqueCredentialResponseBytes,
              2,
            ),
            'expiresAt': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 5))
                .toIso8601String(),
          },
        }),
      );
      await request.response.close();
    });
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });

    Future<Object?> capture(Future<Object?> operation) async {
      try {
        await operation;
        return null;
      } catch (error) {
        return error;
      }
    }

    final firstPassword = Uint8List.fromList(utf8.encode('first-password'));
    final firstOutcome = capture(
      authenticator.loginDevice(
        loginName: 'first-user',
        password: firstPassword,
        deviceName: 'Windows 主机',
        platform: CloudSyncPlatform.windows,
        clientVersion: '1.2.3',
      ),
    );
    await firstRequestArrived.future;

    final secondPassword = Uint8List.fromList(utf8.encode('second-password'));
    final secondOutcome = await capture(
      authenticator.loginDevice(
        loginName: 'second-user',
        password: secondPassword,
        deviceName: 'Windows 主机',
        platform: CloudSyncPlatform.windows,
        clientVersion: '1.2.3',
      ),
    );
    releaseFirstRequest.complete();
    final completedFirstOutcome = await firstOutcome;

    expect(
      secondOutcome,
      isA<CloudSyncException>()
          .having((error) => error.kind, 'kind', CloudSyncFailureKind.conflict)
          .having(
            (error) => error.serverCode,
            'serverCode',
            'SYNC_AUTHENTICATION_IN_PROGRESS',
          ),
    );
    expect(
      completedFirstOutcome,
      isA<KelivoSecureCoreException>().having(
        (error) => error.status,
        'status',
        KelivoSecureCoreStatus.opaqueMessageInvalid,
      ),
    );
    expect(requestCount, 1);
    expect(firstPassword, everyElement(0));
    expect(secondPassword, everyElement(0));
    expect(
      await store.read(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: 'second-user',
      ),
      isNull,
    );
  });

  test('设备状态存在但持久密钥槽缺失时失败关闭', () async {
    const core = KelivoSecureCore();
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_authenticator_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
    const baseUrl = 'https://missing-slot.example';
    final loginName = 'missing${DateTime.now().microsecondsSinceEpoch}';
    final client = CloudSyncClient.forTesting(baseUrl: baseUrl);
    final store = DeviceStateBlobStore(installationRoot: root);
    final authenticator = E2eeAccountAuthenticator(
      baseUrl: baseUrl,
      accountClient: client,
      deviceStateStore: store,
      secureCore: core,
    );
    addTearDown(() async {
      client.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });
    await store.write(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      blob: Uint8List(DeviceStateBlobStore.blobLength),
    );

    await expectLater(
      authenticator.loginDevice(
        loginName: loginName,
        password: Uint8List.fromList(utf8.encode('password')),
        deviceName: 'Windows 主机',
        platform: CloudSyncPlatform.windows,
        clientVersion: '1.2.3',
      ),
      throwsA(
        isA<KelivoSecureCoreException>().having(
          (error) => error.status,
          'status',
          KelivoSecureCoreStatus.slotNotFound,
        ),
      ),
    );
  });

  test('设备状态密文损坏时不会重建身份掩盖认证失败', () async {
    const core = KelivoSecureCore();
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_authenticator_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
    const baseUrl = 'http://127.0.0.1:1';
    const loginName = 'damaged-user';
    final client = CloudSyncClient.forTesting(baseUrl: baseUrl);
    final store = DeviceStateBlobStore(installationRoot: root);
    final authenticator = E2eeAccountAuthenticator(
      baseUrl: baseUrl,
      accountClient: client,
      deviceStateStore: store,
      secureCore: core,
    );
    addTearDown(() async {
      client.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });
    Future<void> login() async {
      await authenticator.loginDevice(
        loginName: loginName,
        password: Uint8List.fromList(utf8.encode('password')),
        deviceName: 'Windows 主机',
        platform: CloudSyncPlatform.windows,
        clientVersion: '1.2.3',
      );
    }

    await expectLater(login(), throwsA(isA<CloudSyncException>()));
    final blob = await store.read(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
    );
    final damagedBlob = Uint8List.fromList(blob!)..last ^= 1;
    await store.write(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      blob: damagedBlob,
    );

    await expectLater(
      login(),
      throwsA(
        isA<KelivoSecureCoreException>().having(
          (error) => error.status,
          'status',
          KelivoSecureCoreStatus.deviceStateAuthenticationFailed,
        ),
      ),
    );
  });

  test('OPAQUE 账户伪名不同于本地用户标识时仍继续密码学登录', () async {
    const core = KelivoSecureCore();
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final baseUrl = 'http://${server.address.address}:${server.port}';
    const loginName = 'bound-user';
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_authenticator_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
    final store = DeviceStateBlobStore(installationRoot: root);
    final slotId = _authenticatorSlotId(baseUrl, loginName);
    final key = await core.createSlot(slotId);
    final identity = await core.generateDeviceIdentity();
    final ark = await core.generateAccountRootKey();
    final stateBlob = await core.sealDeviceState(
      key,
      identity,
      deviceId: _rawUuid(_deviceId1),
      keyVersion: 1,
      ark: ark,
      account: KelivoDeviceStateAccountBinding(
        userId: _rawUuid(_userId),
        keyEpoch: 7,
      ),
    );
    await store.write(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      blob: stateBlob,
    );
    await core.closeAccountRootKey(ark);
    await core.closeDeviceIdentity(identity);
    await core.close(key);
    expect(_accountContextId, isNot(_userId));

    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(baseUrl: baseUrl);
    final authenticator = E2eeAccountAuthenticator(
      baseUrl: baseUrl,
      accountClient: client,
      deviceStateStore: store,
      secureCore: core,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });

    final loginFuture = authenticator.loginDevice(
      loginName: loginName,
      password: Uint8List.fromList(utf8.encode('password')),
      deviceName: 'Windows 主机',
      platform: CloudSyncPlatform.windows,
      clientVersion: '1.2.3',
    );
    final request = await requestFuture;
    final body = copyCloudSyncJsonMap(
      jsonDecode(await utf8.decoder.bind(request).join()),
    );
    expect(body['deviceId'], _deviceId1);
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'attemptId': _attemptId1,
          'accountBinding': _accountContextId,
          'deviceChallenge': _encodedBytes(cloudSyncDeviceChallengeBytes, 1),
          'credentialResponse': _encodedBytes(
            cloudSyncOpaqueCredentialResponseBytes,
            2,
          ),
          'expiresAt': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 5))
              .toIso8601String(),
        },
      }),
    );
    await request.response.close();
    await expectLater(
      loginFuture,
      throwsA(
        isA<KelivoSecureCoreException>().having(
          (error) => error.status,
          'status',
          KelivoSecureCoreStatus.opaqueMessageInvalid,
        ),
      ),
    );

    final reopenedKey = await core.openSlot(slotId);
    final reopened = await core.openDeviceState(
      reopenedKey,
      stateBlob: (await store.read(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ))!,
    );
    expect(reopened.binding.account?.keyEpoch, 7);
    expect(reopened.binding.account?.userId, orderedEquals(_rawUuid(_userId)));
    await core.closeAccountRootKey(reopened.ark!);
    await core.closeDeviceIdentity(reopened.identity);
    await core.close(reopenedKey);
  });

  test('移动注册的畸形 OPAQUE 响应保留可重开的未绑定设备状态', () async {
    const core = KelivoSecureCore();
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final baseUrl = 'http://${server.address.address}:${server.port}';
    const loginName = 'mobile-user';
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_authenticator_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
    final store = DeviceStateBlobStore(installationRoot: root);
    final client = CloudSyncClient.forTesting(baseUrl: baseUrl);
    final authenticator = E2eeAccountAuthenticator(
      baseUrl: baseUrl,
      accountClient: client,
      deviceStateStore: store,
      secureCore: core,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });

    final requestFuture = server.first;
    final registrationFuture = authenticator.registerFirstDevice(
      loginName: loginName,
      displayName: 'Mobile User',
      password: Uint8List.fromList(utf8.encode('password')),
      deviceName: 'Android 手机',
      platform: CloudSyncPlatform.android,
      clientVersion: '1.2.3',
    );
    final request = await requestFuture;
    final body = copyCloudSyncJsonMap(
      jsonDecode(await utf8.decoder.bind(request).join()),
    );
    expect(body['platform'], 'android');
    expect(body['deviceKeyVersion'], 1);
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'attemptId': _attemptId1,
          'userId': _userId,
          'accountBinding': _accountContextId,
          'deviceChallenge': _encodedBytes(cloudSyncDeviceChallengeBytes, 1),
          'registrationResponse': _encodedBytes(
            cloudSyncOpaqueRegistrationResponseBytes,
          ),
          'expiresAt': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 5))
              .toIso8601String(),
        },
      }),
    );
    await request.response.close();
    await expectLater(
      registrationFuture,
      throwsA(
        isA<KelivoSecureCoreException>().having(
          (error) => error.status,
          'status',
          KelivoSecureCoreStatus.opaqueMessageInvalid,
        ),
      ),
    );

    final key = await core.openSlot(_authenticatorSlotId(baseUrl, loginName));
    final opened = await core.openDeviceState(
      key,
      stateBlob: (await store.read(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ))!,
    );
    expect(opened.binding.account, isNull);
    expect(opened.binding.keyVersion, 1);
    expect(body['deviceId'], _uuidStringForTest(opened.binding.deviceId));
    expect(
      await store.readPendingRegistrationEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      isNull,
    );
    await core.closeDeviceIdentity(opened.identity);
    await core.close(key);
  });

  test('首设备注册响应丢失后新认证器原样重放且提交确认前保留事务', () async {
    const core = KelivoSecureCore();
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = StreamIterator<HttpRequest>(server);
    final baseUrl = 'http://${server.address.address}:${server.port}';
    const loginName = 'recover-registration';
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_authenticator_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
    final store = DeviceStateBlobStore(installationRoot: root);
    final expectedRequest = await _seedPendingRegistration(
      core: core,
      store: store,
      baseUrl: baseUrl,
      loginName: loginName,
      attemptExpiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );
    final firstClient = CloudSyncClient.forTesting(baseUrl: baseUrl);
    final firstAuthenticator = E2eeAccountAuthenticator(
      baseUrl: baseUrl,
      accountClient: firstClient,
      deviceStateStore: store,
      secureCore: core,
    );
    addTearDown(() async {
      firstClient.close(force: true);
      await requests.cancel();
      await server.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });

    final firstPassword = Uint8List.fromList(utf8.encode('password'));
    final firstResult = firstAuthenticator.registerFirstDevice(
      loginName: loginName,
      displayName: 'Recovery User',
      password: firstPassword,
      deviceName: 'Android 手机',
      platform: CloudSyncPlatform.android,
      clientVersion: '1.2.3',
    );
    expect(await requests.moveNext(), isTrue);
    final firstRequest = requests.current;
    final firstBody = copyCloudSyncJsonMap(
      jsonDecode(await utf8.decoder.bind(firstRequest).join()),
    );
    expect(firstRequest.uri.path, '/api/auth/opaque-registration/finish');
    expect(firstBody, expectedRequest);
    final firstSocket = await firstRequest.response.detachSocket();
    firstSocket.destroy();
    await expectLater(firstResult, throwsA(isA<CloudSyncException>()));
    expect(firstPassword, everyElement(0));
    expect(
      await store.readPendingRegistrationEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      isNotNull,
    );

    final persistedKey = await core.openSlot(
      _authenticatorSlotId(baseUrl, loginName),
    );
    final persistedState = await core.openDeviceState(
      persistedKey,
      stateBlob: (await store.read(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ))!,
    );
    expect(persistedState.binding.account?.keyEpoch, 1);
    expect(
      persistedState.binding.account?.userId,
      orderedEquals(_rawUuid(_userId)),
    );
    await core.closeAccountRootKey(persistedState.ark!);
    await core.closeDeviceIdentity(persistedState.identity);
    await core.close(persistedKey);

    firstClient.close(force: true);
    final secondClient = CloudSyncClient.forTesting(baseUrl: baseUrl);
    final secondAuthenticator = E2eeAccountAuthenticator(
      baseUrl: baseUrl,
      accountClient: secondClient,
      deviceStateStore: store,
      secureCore: core,
    );
    addTearDown(() => secondClient.close(force: true));
    final secondPassword = Uint8List.fromList(utf8.encode('password'));
    final secondResultFuture = secondAuthenticator.registerFirstDevice(
      loginName: loginName,
      displayName: 'Ignored On Recovery',
      password: secondPassword,
      deviceName: 'Android 手机',
      platform: CloudSyncPlatform.android,
      clientVersion: '1.2.3',
    );
    expect(await requests.moveNext(), isTrue);
    final secondRequest = requests.current;
    final secondBody = copyCloudSyncJsonMap(
      jsonDecode(await utf8.decoder.bind(secondRequest).join()),
    );
    expect(secondRequest.uri.path, '/api/auth/opaque-registration/finish');
    expect(secondBody, expectedRequest);
    secondRequest.response.headers.contentType = ContentType.json;
    secondRequest.response.write(
      jsonEncode(<String, Object?>{
        'data': _authenticatedData(
          keyEpoch: 1,
          deviceId: _deviceId1,
          loginName: loginName,
        ),
      }),
    );
    await secondRequest.response.close();

    final secondResult = await secondResultFuture;
    expect(secondResult.user.id, _userId);
    expect(secondResult.device.id, _deviceId1);
    expect(secondPassword, everyElement(0));
    expect(
      await store.readPendingRegistrationEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      isNotNull,
    );
    await secondAuthenticator.confirmFirstDeviceRegistration(
      loginName: loginName,
      session: secondResult,
    );
    expect(
      await store.readPendingRegistrationEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      isNull,
    );
  });

  for (final scenario
      in <
        ({String name, Duration attemptExpiryOffset, String expectedServerCode})
      >[
        (
          name: '未过期注册事务被拒绝时保留服务端错误且不回滚 ARK',
          attemptExpiryOffset: const Duration(minutes: 5),
          expectedServerCode: 'AUTH_REGISTRATION_FAILED',
        ),
        (
          name: '已过期注册恢复要求正常登录且不回滚 ARK',
          attemptExpiryOffset: const Duration(minutes: -1),
          expectedServerCode: 'SYNC_REGISTRATION_RECOVERY_LOGIN_REQUIRED',
        ),
      ]) {
    test(scenario.name, () async {
      const core = KelivoSecureCore();
      if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requestFuture = server.first;
      final baseUrl = 'http://${server.address.address}:${server.port}';
      final loginName = scenario.attemptExpiryOffset.isNegative
          ? 'expired-registration'
          : 'rejected-registration';
      final testRoot = Directory(
        '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
        '${Platform.pathSeparator}e2ee_authenticator_tests',
      );
      await testRoot.create(recursive: true);
      final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
      final store = DeviceStateBlobStore(installationRoot: root);
      await _seedPendingRegistration(
        core: core,
        store: store,
        baseUrl: baseUrl,
        loginName: loginName,
        attemptExpiresAt: DateTime.now().toUtc().add(
          scenario.attemptExpiryOffset,
        ),
      );
      final client = CloudSyncClient.forTesting(baseUrl: baseUrl);
      final authenticator = E2eeAccountAuthenticator(
        baseUrl: baseUrl,
        accountClient: client,
        deviceStateStore: store,
        secureCore: core,
      );
      addTearDown(() async {
        client.close(force: true);
        await server.close(force: true);
        if (await root.exists()) await root.delete(recursive: true);
      });

      final password = Uint8List.fromList(utf8.encode('password'));
      final result = authenticator.registerFirstDevice(
        loginName: loginName,
        displayName: 'Recovery User',
        password: password,
        deviceName: 'Android 手机',
        platform: CloudSyncPlatform.android,
        clientVersion: '1.2.3',
      );
      final request = await requestFuture;
      await utf8.decoder.bind(request).join();
      expect(request.uri.path, '/api/auth/opaque-registration/finish');
      request.response
        ..statusCode = 400
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode(<String, Object?>{
            'error': <String, Object?>{
              'code': 'AUTH_REGISTRATION_FAILED',
              'message': 'registration failed',
              'retryable': false,
            },
            'requestId': 'registration-recovery-failure',
          }),
        );
      await request.response.close();

      await expectLater(
        result,
        throwsA(
          isA<CloudSyncException>().having(
            (error) => error.serverCode,
            'serverCode',
            scenario.expectedServerCode,
          ),
        ),
      );
      expect(password, everyElement(0));
      expect(
        await store.readPendingRegistrationEnvelope(
          normalizedBaseUrl: baseUrl,
          normalizedLoginName: loginName,
        ),
        isNotNull,
      );
      final key = await core.openSlot(_authenticatorSlotId(baseUrl, loginName));
      final opened = await core.openDeviceState(
        key,
        stateBlob: (await store.read(
          normalizedBaseUrl: baseUrl,
          normalizedLoginName: loginName,
        ))!,
      );
      expect(opened.binding.account?.keyEpoch, 1);
      expect(opened.ark, isNotNull);
      await core.closeAccountRootKey(opened.ark!);
      await core.closeDeviceIdentity(opened.identity);
      await core.close(key);
    });
  }

  test('生产客户端固定使用官方服务地址', () {
    final client = CloudSyncClient();
    addTearDown(() => client.close(force: true));

    expect(client.baseUrl, 'https://kelivo.bemylover.top');
    expect(client.baseUrl, defaultCloudSyncBaseUrl);
  });

  test('完整会话令牌与设备引导令牌不可混淆且不会被日志输出', () {
    expect(_fullToken.value, _fullTokenValue);
    expect(_onboardingToken.value, _onboardingTokenValue);
    expect(_fullToken.toString(), isNot(contains(_fullTokenValue)));
    expect(_onboardingToken.toString(), isNot(contains(_onboardingTokenValue)));
    expect(
      () => CloudSyncFullSessionToken.parse(_onboardingTokenValue),
      throwsFormatException,
    );
    expect(
      () => CloudSyncOnboardingToken.parse(_fullTokenValue),
      throwsFormatException,
    );
    expect(
      () => CloudSyncFullSessionToken.parse('kelivo_short'),
      throwsFormatException,
    );
  });

  test('OPAQUE 注册开始规范化账户字段并保持固定长度二进制', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final startFuture = client.startOpaqueRegistration(
      loginName: ' Alice ',
      displayName: ' Alice ',
      device: _deviceIdentity(),
      registrationRequest: _filledBytes(
        cloudSyncOpaqueRegistrationRequestBytes,
        3,
      ),
    );

    final request = await requestFuture;
    expect(request.uri.path, '/api/auth/opaque-registration/start');
    expect(request.headers.value(HttpHeaders.authorizationHeader), isNull);
    expect(jsonDecode(await utf8.decoder.bind(request).join()), <
      String,
      Object?
    >{
      'protocolVersion': cloudSyncOpaqueProtocolVersion,
      'loginName': 'alice',
      'displayName': 'Alice',
      'deviceId': _deviceId1,
      'deviceName': 'Windows 主机',
      'platform': 'windows',
      'clientVersion': '1.2.3',
      'deviceKeyVersion': 1,
      'signingPublicKey': _encodedBytes(cloudSyncDevicePublicKeyBytes, 1),
      'keyAgreementPublicKey': _encodedBytes(cloudSyncDevicePublicKeyBytes, 2),
      'registrationRequest': _encodedBytes(
        cloudSyncOpaqueRegistrationRequestBytes,
        3,
      ),
    });
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'attemptId': _attemptId1,
          'userId': _userId,
          'accountBinding': _accountContextId,
          'deviceChallenge': _encodedBytes(cloudSyncDeviceChallengeBytes, 6),
          'registrationResponse': _encodedBytes(
            cloudSyncOpaqueRegistrationResponseBytes,
            7,
          ),
          'expiresAt': '2026-07-26T05:05:00.000Z',
        },
      }),
    );
    await request.response.close();

    final result = await startFuture;
    expect(result.attemptId, _attemptId1);
    expect(result.userId, _userId);
    expect(result.accountBinding, _accountContextId);
    expect(result.deviceChallenge, everyElement(6));
    expect(result.registrationResponse, everyElement(7));
  });

  test('OPAQUE 注册完成返回绑定当前 keyEpoch 的完整会话', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final finishFuture = client.finishOpaqueRegistration(
      attemptId: _attemptId1,
      registrationUpload: _filledBytes(
        cloudSyncOpaqueRegistrationUploadBytes,
        8,
      ),
      accountKeyEnvelope: _filledBytes(cloudSyncAccountKeyEnvelopeBytes, 9),
      deviceProof: _filledBytes(cloudSyncDeviceProofBytes, 10),
    );

    final request = await requestFuture;
    expect(request.uri.path, '/api/auth/opaque-registration/finish');
    expect(request.headers.value(HttpHeaders.authorizationHeader), isNull);
    expect(jsonDecode(await utf8.decoder.bind(request).join()), <
      String,
      Object?
    >{
      'protocolVersion': cloudSyncOpaqueProtocolVersion,
      'attemptId': _attemptId1,
      'registrationUpload': _encodedBytes(
        cloudSyncOpaqueRegistrationUploadBytes,
        8,
      ),
      'accountKeyEnvelope': _encodedBytes(cloudSyncAccountKeyEnvelopeBytes, 9),
      'deviceProof': _encodedBytes(cloudSyncDeviceProofBytes, 10),
    });
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{'data': _authenticatedData(keyEpoch: 11)}),
    );
    await request.response.close();

    final session = await finishFuture;
    expect(session.token.value, _fullTokenValue);
    expect(session.keyEpoch, 11);
    expect(session.user.id, _userId);
    expect(session.device.id, _deviceId1);
    expect(session.device.status, CloudSyncAuthenticatedDeviceStatus.active);
  });

  test('OPAQUE 登录保持匿名并区分已认证与待设备批准结果', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <(String, String?, CloudSyncJsonMap)>[];
    final subscription = server.listen((request) async {
      final body = copyCloudSyncJsonMap(
        jsonDecode(await utf8.decoder.bind(request).join()),
      );
      requests.add((
        request.uri.path,
        request.headers.value(HttpHeaders.authorizationHeader),
        body,
      ));
      final Object data;
      if (request.uri.path == '/api/auth/opaque-login/start') {
        data = <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'attemptId': _attemptId1,
          'accountBinding': _accountContextId,
          'deviceChallenge': _encodedBytes(cloudSyncDeviceChallengeBytes, 11),
          'credentialResponse': _encodedBytes(
            cloudSyncOpaqueCredentialResponseBytes,
            12,
          ),
          'expiresAt': '2026-07-26T05:05:00.000Z',
        };
      } else if (body['attemptId'] == _attemptId1) {
        data = _authenticatedData(keyEpoch: 12);
      } else {
        data = <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'result': 'device-approval-required',
          'onboardingToken': _onboardingTokenValue,
          'onboardingTokenExpiresAt': '2026-07-26T05:05:00.000Z',
          'device': <String, Object?>{
            'id': _deviceId2,
            'name': 'Windows 主机',
            'platform': 'windows',
            'clientVersion': '1.2.3',
            'status': 'pending',
            'createdAt': '2026-07-26T05:00:00.000Z',
          },
        };
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, Object?>{'data': data}));
      await request.response.close();
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    });

    final start = await client.startOpaqueLogin(
      loginName: ' Alice ',
      device: _deviceIdentity(),
      credentialRequest: _filledBytes(
        cloudSyncOpaqueCredentialRequestBytes,
        13,
      ),
    );
    final authenticated = await client.finishOpaqueLogin(
      attemptId: _attemptId1,
      credentialFinalization: _filledBytes(
        cloudSyncOpaqueCredentialFinalizationBytes,
        14,
      ),
      deviceProof: _filledBytes(cloudSyncDeviceProofBytes, 15),
    );
    final approvalRequired = await client.finishOpaqueLogin(
      attemptId: _attemptId2,
      credentialFinalization: _filledBytes(
        cloudSyncOpaqueCredentialFinalizationBytes,
        16,
      ),
      deviceProof: _filledBytes(cloudSyncDeviceProofBytes, 17),
    );

    expect(start.credentialResponse, everyElement(12));
    expect(
      authenticated,
      isA<CloudSyncOpaqueLoginAuthenticated>().having(
        (result) => result.session.keyEpoch,
        'keyEpoch',
        12,
      ),
    );
    expect(
      approvalRequired,
      isA<CloudSyncOpaqueLoginApprovalRequired>()
          .having(
            (result) => result.onboardingToken.value,
            'onboardingToken',
            _onboardingTokenValue,
          )
          .having(
            (result) => result.device.status,
            'device.status',
            CloudSyncAuthenticatedDeviceStatus.pending,
          ),
    );
    expect(requests, hasLength(3));
    expect(requests.map((request) => request.$2), everyElement(isNull));
    expect(requests.first.$3['loginName'], 'alice');
    expect(
      requests.first.$3['credentialRequest'],
      _encodedBytes(cloudSyncOpaqueCredentialRequestBytes, 13),
    );
  });

  test('桌面待批准登录创建绑定当前设备身份的二维码并可取消', () async {
    const core = KelivoSecureCore();
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = StreamIterator<HttpRequest>(server);
    final baseUrl = 'http://${server.address.address}:${server.port}';
    const loginName = 'pairing-target';
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_authenticator_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
    final store = DeviceStateBlobStore(installationRoot: root);
    final key = await core.createSlot(_authenticatorSlotId(baseUrl, loginName));
    final identity = await core.generateDeviceIdentity();
    final publicKeys = await core.readDevicePublicKeys(identity);
    final identityState = await core.sealDeviceState(
      key,
      identity,
      deviceId: _rawUuid(_deviceId2),
      keyVersion: 1,
    );
    await store.write(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      blob: identityState,
    );
    await core.closeDeviceIdentity(identity);
    await core.close(key);

    final client = CloudSyncClient.forTesting(baseUrl: baseUrl);
    final authenticator = E2eeAccountAuthenticator(
      baseUrl: baseUrl,
      accountClient: client,
      deviceStateStore: store,
      secureCore: core,
    );
    addTearDown(() async {
      client.close(force: true);
      await requests.cancel();
      await server.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });

    final onboardingExpiresAt = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 5))
          .millisecondsSinceEpoch,
      isUtc: true,
    );
    final approvalRequired = E2eeAccountLoginApprovalRequired(
      onboardingToken: _onboardingToken,
      onboardingTokenExpiresAt: onboardingExpiresAt,
      loginName: loginName,
      device: CloudSyncAuthenticatedDevice(
        id: _deviceId2,
        name: 'Windows 主机',
        platform: CloudSyncPlatform.windows,
        clientVersion: '1.2.3',
        status: CloudSyncAuthenticatedDeviceStatus.pending,
        createdAt: DateTime.utc(2026, 7, 26, 5),
      ),
    );
    Future<String> respondToCreate(DateTime expiresAt) async {
      expect(await requests.moveNext(), isTrue);
      final createRequest = requests.current;
      final createBody = copyCloudSyncJsonMap(
        jsonDecode(await utf8.decoder.bind(createRequest).join()),
      );
      expect(createRequest.uri.path, '/api/auth/device-pairing/create');
      final pairingId = createBody['pairingId']! as String;
      createRequest.response.headers.contentType = ContentType.json;
      createRequest.response.write(
        jsonEncode(<String, Object?>{
          'data': <String, Object?>{
            'protocolVersion': cloudSyncOpaqueProtocolVersion,
            'pairingId': pairingId,
            'accountContextId': _userId,
            'challenge': _encodedBytes(cloudSyncDeviceChallengeBytes, 18),
            'expiresAt': expiresAt.toIso8601String(),
            'targetDevice': <String, Object?>{
              'id': _deviceId2,
              'name': 'Windows 主机',
              'platform': 'windows',
              'clientVersion': '1.2.3',
              'keyVersion': 1,
              'authGeneration': 0,
              'signingPublicKey': base64Url
                  .encode(publicKeys.signingPublicKey)
                  .replaceAll('=', ''),
              'keyAgreementPublicKey': base64Url
                  .encode(publicKeys.keyAgreementPublicKey)
                  .replaceAll('=', ''),
            },
          },
        }),
      );
      await createRequest.response.close();
      return pairingId;
    }

    final pairingExpiresAt = onboardingExpiresAt.subtract(
      const Duration(seconds: 1),
    );
    final startFuture = authenticator.startDevicePairing(approvalRequired);
    final pairingId = await respondToCreate(pairingExpiresAt);

    final pending = await startFuture;
    final frame = pending.takeQrFrame(now: DateTime.now().toUtc());
    final decoded = CloudSyncDevicePairingQrCodec.decodeTakingOwnership(
      frame,
      now: DateTime.now().toUtc(),
    );
    expect(decoded.pairingId, pairingId);
    expect(decoded.accountContextId, _userId);
    expect(decoded.targetDeviceId, _deviceId2);
    decoded.dispose();

    final foreignClient = CloudSyncClient.forTesting(baseUrl: baseUrl);
    final foreignAuthenticator = E2eeAccountAuthenticator(
      baseUrl: baseUrl,
      accountClient: foreignClient,
      deviceStateStore: store,
      secureCore: core,
    );
    addTearDown(() => foreignClient.close(force: true));
    await expectLater(
      foreignAuthenticator.waitForDevicePairing(pending),
      throwsStateError,
    );
    await expectLater(
      foreignAuthenticator.cancelDevicePairing(pending),
      throwsStateError,
    );

    final waitingFuture = authenticator.waitForDevicePairing(pending);
    expect(await requests.moveNext(), isTrue);
    final queryRequest = requests.current;
    expect(queryRequest.uri.path, '/api/auth/device-pairing/query');
    await utf8.decoder.bind(queryRequest).join();
    final waitingExpectation = expectLater(
      waitingFuture,
      throwsA(
        isA<CloudSyncException>().having(
          (error) => error.kind,
          'kind',
          CloudSyncFailureKind.cancelled,
        ),
      ),
    );

    final cancelFuture = authenticator.cancelDevicePairing(pending);
    expect(await requests.moveNext(), isTrue);
    final cancelRequest = requests.current;
    expect(cancelRequest.uri.path, '/api/auth/device-pairing/cancel');
    cancelRequest.response.headers.contentType = ContentType.json;
    cancelRequest.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'pairingId': pairingId,
          'result': 'cancelled',
          'cancelledAt': DateTime.now().toUtc().toIso8601String(),
        },
      }),
    );
    await cancelRequest.response.close();
    await cancelFuture;
    queryRequest.response.headers.contentType = ContentType.json;
    queryRequest.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'pairingId': pairingId,
          'accountContextId': _userId,
          'challenge': _encodedBytes(cloudSyncDeviceChallengeBytes, 18),
          'expiresAt': pairingExpiresAt.toIso8601String(),
          'targetDevice': <String, Object?>{
            'id': _deviceId2,
            'name': 'Windows 主机',
            'platform': 'windows',
            'clientVersion': '1.2.3',
            'keyVersion': 1,
            'authGeneration': 0,
            'signingPublicKey': base64Url
                .encode(publicKeys.signingPublicKey)
                .replaceAll('=', ''),
            'keyAgreementPublicKey': base64Url
                .encode(publicKeys.keyAgreementPublicKey)
                .replaceAll('=', ''),
          },
          'status': 'pending',
        },
      }),
    );
    await queryRequest.response.close();
    await waitingExpectation;

    final rejectedStart = authenticator.startDevicePairing(approvalRequired);
    await respondToCreate(onboardingExpiresAt.add(const Duration(seconds: 1)));
    await expectLater(rejectedStart, throwsStateError);
  });

  test('移动可信设备批准响应丢失后原样重试并清零扫码帧', () async {
    const core = KelivoSecureCore();
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = StreamIterator<HttpRequest>(server);
    final baseUrl = 'http://${server.address.address}:${server.port}';
    const loginName = 'pairing-issuer';
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_authenticator_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
    final store = DeviceStateBlobStore(installationRoot: root);
    final key = await core.createSlot(_authenticatorSlotId(baseUrl, loginName));
    final identity = await core.generateDeviceIdentity();
    final ark = await core.generateAccountRootKey();
    final targetIdentity = await core.generateDeviceIdentity();
    final targetPublicKeys = await core.readDevicePublicKeys(targetIdentity);
    final fullState = await core.sealDeviceState(
      key,
      identity,
      deviceId: _rawUuid(_issuerDeviceId),
      keyVersion: 1,
      ark: ark,
      account: KelivoDeviceStateAccountBinding(
        userId: _rawUuid(_userId),
        keyEpoch: 7,
      ),
    );
    await store.write(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      blob: fullState,
    );
    await core.closeAccountRootKey(ark);
    await core.closeDeviceIdentity(targetIdentity);
    await core.closeDeviceIdentity(identity);
    await core.close(key);

    final client = CloudSyncClient.forTesting(baseUrl: baseUrl);
    final authenticator = E2eeAccountAuthenticator(
      baseUrl: baseUrl,
      accountClient: client,
      deviceStateStore: store,
      secureCore: core,
    );
    addTearDown(() async {
      client.close(force: true);
      await requests.cancel();
      await server.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });

    final now = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().toUtc().millisecondsSinceEpoch,
      isUtc: true,
    );
    final qrPayload = _pairingQrPayload(
      pairingSecret: _filledBytes(cloudSyncPairingSecretBytes, 24),
      now: now,
      expiresAt: now.add(const Duration(minutes: 4)),
      signingPublicKey: targetPublicKeys.signingPublicKey,
      keyAgreementPublicKey: targetPublicKeys.keyAgreementPublicKey,
    );
    final qrFrame = CloudSyncDevicePairingQrCodec.encode(qrPayload, now: now);
    qrPayload.dispose();
    final session = CloudSyncAuthenticatedSession(
      token: _fullToken,
      tokenExpiresAt: now.add(const Duration(minutes: 10)),
      keyEpoch: 7,
      user: CloudSyncAuthenticatedUser(
        id: _userId,
        loginName: loginName,
        displayName: 'Pairing Issuer',
        role: CloudSyncUserRole.owner,
        attachmentQuotaBytes: 1048576,
      ),
      device: CloudSyncAuthenticatedDevice(
        id: _issuerDeviceId,
        name: 'Android 手机',
        platform: CloudSyncPlatform.android,
        clientVersion: '1.2.3',
        status: CloudSyncAuthenticatedDeviceStatus.active,
        createdAt: now,
      ),
    );

    final approvalFuture = authenticator.approveScannedDevicePairing(
      loginName: loginName,
      session: session,
      qrFrame: qrFrame,
    );
    expect(await requests.moveNext(), isTrue);
    final firstRequest = requests.current;
    expect(firstRequest.uri.path, '/api/auth/device-pairing/approve');
    final firstBody = copyCloudSyncJsonMap(
      jsonDecode(await utf8.decoder.bind(firstRequest).join()),
    );
    final firstSocket = await firstRequest.response.detachSocket();
    firstSocket.destroy();

    expect(await requests.moveNext(), isTrue);
    final secondRequest = requests.current;
    expect(secondRequest.uri.path, '/api/auth/device-pairing/approve');
    expect(
      secondRequest.headers.value(HttpHeaders.authorizationHeader),
      'Bearer $_fullTokenValue',
    );
    final secondBody = copyCloudSyncJsonMap(
      jsonDecode(await utf8.decoder.bind(secondRequest).join()),
    );
    expect(secondBody, firstBody);
    secondRequest.response.headers.contentType = ContentType.json;
    secondRequest.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'pairingId': _pairingId,
          'result': 'approved',
          'approvedAt': now.toIso8601String(),
        },
      }),
    );
    await secondRequest.response.close();

    final approval = await approvalFuture;
    expect(approval.pairingId, _pairingId);
    expect(qrFrame, everyElement(0));

    Uint8List createQrFrame({
      required int secretByte,
      String accountContextId = _userId,
    }) {
      final payload = _pairingQrPayload(
        pairingSecret: _filledBytes(cloudSyncPairingSecretBytes, secretByte),
        now: now,
        expiresAt: now.add(const Duration(minutes: 4)),
        accountContextId: accountContextId,
        signingPublicKey: targetPublicKeys.signingPublicKey,
        keyAgreementPublicKey: targetPublicKeys.keyAgreementPublicKey,
      );
      try {
        return CloudSyncDevicePairingQrCodec.encode(payload, now: now);
      } finally {
        payload.dispose();
      }
    }

    final crossAccountFrame = createQrFrame(
      secretByte: 25,
      accountContextId: _accountContextId,
    );
    await expectLater(
      authenticator.approveScannedDevicePairing(
        loginName: loginName,
        session: session,
        qrFrame: crossAccountFrame,
      ),
      throwsFormatException,
    );
    expect(crossAccountFrame, everyElement(0));

    final desktopFrame = createQrFrame(secretByte: 26);
    final desktopSession = CloudSyncAuthenticatedSession(
      token: _fullToken,
      tokenExpiresAt: session.tokenExpiresAt,
      keyEpoch: session.keyEpoch,
      user: session.user,
      device: CloudSyncAuthenticatedDevice(
        id: session.device.id,
        name: 'Windows 主机',
        platform: CloudSyncPlatform.windows,
        clientVersion: session.device.clientVersion,
        status: CloudSyncAuthenticatedDeviceStatus.active,
        createdAt: session.device.createdAt,
      ),
    );
    await expectLater(
      authenticator.approveScannedDevicePairing(
        loginName: loginName,
        session: desktopSession,
        qrFrame: desktopFrame,
      ),
      throwsUnsupportedError,
    );
    expect(desktopFrame, everyElement(0));
  });

  test('桌面接收批准后先持久化完整状态与恢复事务再消费', () async {
    const core = KelivoSecureCore();
    if (!(await core.getCapabilities()).supportsDeviceE2eeCore) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = StreamIterator<HttpRequest>(server);
    final baseUrl = 'http://${server.address.address}:${server.port}';
    const loginName = 'pairing-consumer';
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}e2ee_authenticator_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('kelivo-e2ee-authenticator-');
    final store = DeviceStateBlobStore(installationRoot: root);
    final key = await core.createSlot(_authenticatorSlotId(baseUrl, loginName));
    final targetIdentity = await core.generateDeviceIdentity();
    final targetPublicKeys = await core.readDevicePublicKeys(targetIdentity);
    final identityState = await core.sealDeviceState(
      key,
      targetIdentity,
      deviceId: _rawUuid(_deviceId2),
      keyVersion: 1,
    );
    await store.write(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      blob: identityState,
    );
    await core.closeDeviceIdentity(targetIdentity);
    await core.close(key);

    final client = CloudSyncClient.forTesting(baseUrl: baseUrl);
    final authenticator = E2eeAccountAuthenticator(
      baseUrl: baseUrl,
      accountClient: client,
      deviceStateStore: store,
      secureCore: core,
    );
    addTearDown(() async {
      client.close(force: true);
      await requests.cancel();
      await server.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });

    final now = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().toUtc().millisecondsSinceEpoch,
      isUtc: true,
    );
    final pairingExpiresAt = now.add(const Duration(minutes: 4));
    final approvalRequired = E2eeAccountLoginApprovalRequired(
      onboardingToken: _onboardingToken,
      onboardingTokenExpiresAt: now.add(const Duration(minutes: 5)),
      loginName: loginName,
      device: CloudSyncAuthenticatedDevice(
        id: _deviceId2,
        name: 'Windows 主机',
        platform: CloudSyncPlatform.windows,
        clientVersion: '1.2.3',
        status: CloudSyncAuthenticatedDeviceStatus.pending,
        createdAt: now,
      ),
    );
    final startFuture = authenticator.startDevicePairing(approvalRequired);
    expect(await requests.moveNext(), isTrue);
    final createRequest = requests.current;
    final createBody = copyCloudSyncJsonMap(
      jsonDecode(await utf8.decoder.bind(createRequest).join()),
    );
    final pairingId = createBody['pairingId']! as String;
    createRequest.response.headers.contentType = ContentType.json;
    createRequest.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'pairingId': pairingId,
          'accountContextId': _userId,
          'challenge': _encodedBytes(cloudSyncDeviceChallengeBytes, 18),
          'expiresAt': pairingExpiresAt.toIso8601String(),
          'targetDevice': <String, Object?>{
            'id': _deviceId2,
            'name': 'Windows 主机',
            'platform': 'windows',
            'clientVersion': '1.2.3',
            'keyVersion': 1,
            'authGeneration': 0,
            'signingPublicKey': base64Url
                .encode(targetPublicKeys.signingPublicKey)
                .replaceAll('=', ''),
            'keyAgreementPublicKey': base64Url
                .encode(targetPublicKeys.keyAgreementPublicKey)
                .replaceAll('=', ''),
          },
        },
      }),
    );
    await createRequest.response.close();
    final pending = await startFuture;

    final frame = pending.takeQrFrame(now: now);
    final decoded = CloudSyncDevicePairingQrCodec.decodeTakingOwnership(
      frame,
      now: now,
    );
    final pairingSecret = decoded.takePairingSecret();
    decoded.dispose();
    final issuerIdentity = await core.generateDeviceIdentity();
    final issuerArk = await core.generateAccountRootKey();
    final issuerPublicKeys = await core.readDevicePublicKeys(issuerIdentity);
    late final KelivoPairingApprovalBundle approvalBundle;
    try {
      approvalBundle = await core.createPairingApproval(
        issuerIdentity,
        issuerArk,
        pairingId: _rawUuid(pairingId),
        userId: _rawUuid(_userId),
        issuerDeviceId: _rawUuid(_issuerDeviceId),
        targetDeviceId: _rawUuid(_deviceId2),
        expiresAtMs: pairingExpiresAt.millisecondsSinceEpoch,
        challenge: _filledBytes(cloudSyncDeviceChallengeBytes, 18),
        keyEpoch: 7,
        targetPublicKeys: targetPublicKeys,
        pairingSecret: pairingSecret,
      );
    } finally {
      pairingSecret.fillRange(0, pairingSecret.length, 0);
      await core.closeAccountRootKey(issuerArk);
      await core.closeDeviceIdentity(issuerIdentity);
    }

    final completionFuture = authenticator.waitForDevicePairing(pending);
    expect(await requests.moveNext(), isTrue);
    final queryRequest = requests.current;
    expect(queryRequest.uri.path, '/api/auth/device-pairing/query');
    await utf8.decoder.bind(queryRequest).join();
    queryRequest.response.headers.contentType = ContentType.json;
    queryRequest.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'pairingId': pairingId,
          'accountContextId': _userId,
          'challenge': _encodedBytes(cloudSyncDeviceChallengeBytes, 18),
          'expiresAt': pairingExpiresAt.toIso8601String(),
          'targetDevice': <String, Object?>{
            'id': _deviceId2,
            'name': 'Windows 主机',
            'platform': 'windows',
            'clientVersion': '1.2.3',
            'keyVersion': 1,
            'authGeneration': 0,
            'signingPublicKey': base64Url
                .encode(targetPublicKeys.signingPublicKey)
                .replaceAll('=', ''),
            'keyAgreementPublicKey': base64Url
                .encode(targetPublicKeys.keyAgreementPublicKey)
                .replaceAll('=', ''),
          },
          'status': 'approved',
          'issuerDeviceId': _issuerDeviceId,
          'issuerSigningPublicKey': base64Url
              .encode(issuerPublicKeys.signingPublicKey)
              .replaceAll('=', ''),
          'issuerKeyAgreementPublicKey': base64Url
              .encode(issuerPublicKeys.keyAgreementPublicKey)
              .replaceAll('=', ''),
          'keyEpoch': 7,
          'accountKeyEnvelope': base64Url
              .encode(approvalBundle.envelope)
              .replaceAll('=', ''),
          'deviceProof': base64Url
              .encode(approvalBundle.signature)
              .replaceAll('=', ''),
          'pairingAuthenticator': base64Url
              .encode(approvalBundle.authenticator)
              .replaceAll('=', ''),
        },
      }),
    );
    await queryRequest.response.close();

    expect(await requests.moveNext(), isTrue);
    final consumeRequest = requests.current;
    expect(consumeRequest.uri.path, '/api/auth/device-pairing/consume');
    final firstConsumeBody = copyCloudSyncJsonMap(
      jsonDecode(await utf8.decoder.bind(consumeRequest).join()),
    );
    expect(
      await store.readPendingPairingEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      isNotNull,
    );
    final persistedKey = await core.openSlot(
      _authenticatorSlotId(baseUrl, loginName),
    );
    final persistedState = await core.openDeviceState(
      persistedKey,
      stateBlob: (await store.read(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ))!,
    );
    expect(persistedState.binding.account?.keyEpoch, 7);
    expect(
      persistedState.binding.account?.userId,
      orderedEquals(_rawUuid(_userId)),
    );
    await core.closeAccountRootKey(persistedState.ark!);
    await core.closeDeviceIdentity(persistedState.identity);
    await core.close(persistedKey);

    final consumeSocket = await consumeRequest.response.detachSocket();
    consumeSocket.destroy();
    await expectLater(completionFuture, throwsA(isA<CloudSyncException>()));
    client.close(force: true);

    final recoveryClient = CloudSyncClient.forTesting(baseUrl: baseUrl);
    final recoveryAuthenticator = E2eeAccountAuthenticator(
      baseUrl: baseUrl,
      accountClient: recoveryClient,
      deviceStateStore: store,
      secureCore: core,
    );
    addTearDown(() => recoveryClient.close(force: true));
    final password = Uint8List.fromList(utf8.encode('password'));
    final recoveryFuture = recoveryAuthenticator.loginDevice(
      loginName: loginName,
      password: password,
      deviceName: 'Windows 主机',
      platform: CloudSyncPlatform.windows,
      clientVersion: '1.2.3',
    );
    expect(await requests.moveNext(), isTrue);
    final retriedConsumeRequest = requests.current;
    expect(retriedConsumeRequest.uri.path, '/api/auth/device-pairing/consume');
    expect(
      copyCloudSyncJsonMap(
        jsonDecode(await utf8.decoder.bind(retriedConsumeRequest).join()),
      ),
      firstConsumeBody,
    );
    retriedConsumeRequest.response.headers.contentType = ContentType.json;
    retriedConsumeRequest.response.write(
      jsonEncode(<String, Object?>{
        'data': _authenticatedData(
          keyEpoch: 7,
          deviceId: _deviceId2,
          loginName: loginName,
        ),
      }),
    );
    await retriedConsumeRequest.response.close();
    final recoveryResult = await recoveryFuture;
    expect(recoveryResult, isA<E2eeAccountLoginAuthenticated>());
    final session = (recoveryResult as E2eeAccountLoginAuthenticated).session;
    expect(session.user.id, _userId);
    expect(session.device.id, _deviceId2);
    expect(password, everyElement(0));
    expect(
      await store.readPendingPairingEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      isNotNull,
    );
    await recoveryAuthenticator.confirmDevicePairing(
      loginName: loginName,
      session: session,
    );
    expect(
      await store.readPendingPairingEnvelope(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      ),
      isNull,
    );
  });

  test('设备配对全生命周期按令牌能力隔离并显式接管完整会话', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <(String, String?, CloudSyncJsonMap)>[];
    var queryCount = 0;
    final subscription = server.listen((request) async {
      final body = copyCloudSyncJsonMap(
        jsonDecode(await utf8.decoder.bind(request).join()),
      );
      requests.add((
        request.uri.path,
        request.headers.value(HttpHeaders.authorizationHeader),
        body,
      ));
      final Object data = switch (request.uri.path) {
        '/api/auth/device-pairing/create' => <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'pairingId': _pairingId,
          'accountContextId': _accountContextId,
          'challenge': _encodedBytes(cloudSyncDeviceChallengeBytes, 18),
          'expiresAt': '2026-07-26T05:05:00.000Z',
          'targetDevice': _pairingTargetJson(),
        },
        '/api/auth/device-pairing/query' => <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'pairingId': _pairingId,
          'accountContextId': _accountContextId,
          'challenge': _encodedBytes(cloudSyncDeviceChallengeBytes, 18),
          'expiresAt': '2026-07-26T05:05:00.000Z',
          'targetDevice': _pairingTargetJson(),
          'status': ++queryCount == 1 ? 'pending' : 'approved',
          if (queryCount > 1) ...<String, Object?>{
            'issuerDeviceId': _issuerDeviceId,
            'issuerSigningPublicKey': _encodedBytes(
              cloudSyncDevicePublicKeyBytes,
              19,
            ),
            'issuerKeyAgreementPublicKey': _encodedBytes(
              cloudSyncDevicePublicKeyBytes,
              20,
            ),
            'keyEpoch': 23,
            'accountKeyEnvelope': _encodedBytes(
              cloudSyncAccountKeyEnvelopeBytes,
              21,
            ),
            'deviceProof': _encodedBytes(cloudSyncDeviceProofBytes, 22),
            'pairingAuthenticator': _encodedBytes(
              cloudSyncPairingAuthenticatorBytes,
              23,
            ),
          },
        },
        '/api/auth/device-pairing/approve' => <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'pairingId': _pairingId,
          'result': 'approved',
          'approvedAt': '2026-07-26T05:01:00.000Z',
        },
        '/api/auth/device-pairing/consume' => _authenticatedData(
          keyEpoch: 23,
          deviceId: _deviceId2,
        ),
        '/api/auth/device-pairing/cancel' => <String, Object?>{
          'protocolVersion': cloudSyncOpaqueProtocolVersion,
          'pairingId': _pairingId,
          'result': 'cancelled',
          'cancelledAt': '2026-07-26T05:02:00.000Z',
        },
        '/api/device/trusted/list' => <String, Object?>{
          'items': <Object?>[_trustedDeviceJson()],
          'total': 1,
          'pageIndex': 1,
          'pageSize': 10,
        },
        '/api/device/trusted/revoke' => <String, Object?>{
          'device': _trustedDeviceJson(status: 'revoked'),
        },
        _ => throw StateError('未预期的请求路径：${request.uri.path}'),
      };
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, Object?>{'data': data}));
      await request.response.close();
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    });

    final created = await client.createDevicePairing(
      token: _onboardingToken,
      pairingId: _pairingId,
      pairingSecretHash: _filledBytes(cloudSyncPairingSecretHashBytes, 24),
    );
    final pending = await client.queryDevicePairing(
      token: _onboardingToken,
      pairingId: _pairingId,
    );
    final approval = await client.approveDevicePairing(
      token: _fullToken,
      pairingId: _pairingId,
      keyEpoch: 23,
      accountKeyEnvelope: _filledBytes(cloudSyncAccountKeyEnvelopeBytes, 21),
      deviceProof: _filledBytes(cloudSyncDeviceProofBytes, 22),
      pairingAuthenticator: _filledBytes(
        cloudSyncPairingAuthenticatorBytes,
        23,
      ),
    );
    final approved = await client.queryDevicePairing(
      token: _onboardingToken,
      pairingId: _pairingId,
    );
    final session = await client.consumeDevicePairing(
      token: _onboardingToken,
      pairingId: _pairingId,
    );
    await expectLater(
      client.listDevices(),
      throwsA(
        isA<CloudSyncException>().having(
          (error) => error.kind,
          'kind',
          CloudSyncFailureKind.unauthenticated,
        ),
      ),
    );
    client.setToken(session.token);
    final devices = await client.listDevices(
      status: CloudSyncDeviceStatus.active,
      pageSize: 10,
    );
    final revoked = await client.revokeDevice(_deviceId2);
    final cancellation = await client.cancelDevicePairing(
      token: _onboardingToken,
      pairingId: _pairingId,
    );

    expect(created.targetDevice.id, _deviceId2);
    expect(created.challenge, everyElement(18));
    expect(pending, isA<CloudSyncDevicePairingPending>());
    expect(approval.pairingId, _pairingId);
    expect(
      approved,
      isA<CloudSyncDevicePairingApproved>()
          .having((result) => result.keyEpoch, 'keyEpoch', 23)
          .having(
            (result) => result.issuerDeviceId,
            'issuerDeviceId',
            _issuerDeviceId,
          )
          .having(
            (result) => result.accountKeyEnvelope,
            'accountKeyEnvelope',
            everyElement(21),
          ),
    );
    expect(session.keyEpoch, 23);
    expect(session.device.id, _deviceId2);
    expect(devices.items.single.id, _deviceId2);
    expect(revoked.status, CloudSyncDeviceStatus.revoked);
    expect(cancellation.pairingId, _pairingId);

    final onboardingHeader = 'Bearer $_onboardingTokenValue';
    final fullHeader = 'Bearer $_fullTokenValue';
    for (final request in requests) {
      final expectedHeader = switch (request.$1) {
        '/api/auth/device-pairing/approve' ||
        '/api/device/trusted/list' ||
        '/api/device/trusted/revoke' => fullHeader,
        _ => onboardingHeader,
      };
      expect(request.$2, expectedHeader, reason: request.$1);
    }
    expect(requests.first.$3, <String, Object?>{
      'protocolVersion': cloudSyncOpaqueProtocolVersion,
      'pairingId': _pairingId,
      'pairingSecretHash': _encodedBytes(cloudSyncPairingSecretHashBytes, 24),
    });
    expect(requests[2].$3['keyEpoch'], 23);
    expect(
      requests[2].$3['accountKeyEnvelope'],
      _encodedBytes(cloudSyncAccountKeyEnvelopeBytes, 21),
    );
    expect(requests[5].$3, <String, Object?>{
      'status': 'active',
      'pageIndex': 1,
      'pageSize': 10,
    });
  });

  test('设备配对 QR 完整 transcript 规范编码并转移敏感缓冲区所有权', () {
    final now = DateTime.utc(2026, 7, 26, 5);
    final sourceSecret = _filledBytes(cloudSyncPairingSecretBytes, 24);
    final payload = CloudSyncDevicePairingQrPayload.fromCreatedPairing(
      created: _pairingQrCreated(),
      pairingSecret: sourceSecret,
      now: now,
    );
    final frame = CloudSyncDevicePairingQrCodec.encode(payload, now: now);
    final deviceNameBytes = utf8.encode('Android 手机');
    final clientVersionBytes = ascii.encode('1.2.3');
    final expectedLength =
        cloudSyncPairingQrMinimumFrameBytes +
        deviceNameBytes.length +
        clientVersionBytes.length;
    final frameData = ByteData.sublistView(frame);

    expect(frame, hasLength(expectedLength));
    expect(frame.sublist(0, 16), <int>[
      0x4b,
      0x4c,
      0x50,
      0x51,
      cloudSyncPairingQrFrameVersion,
      0,
      expectedLength >> 8,
      expectedLength & 0xff,
      0,
      0,
      0,
      cloudSyncOpaqueProtocolVersion,
      1,
      deviceNameBytes.length,
      clientVersionBytes.length,
      0,
    ]);
    expect(frameData.getUint32(16, Endian.big), 1);
    expect(
      frameData.getUint64(20, Endian.big),
      DateTime.utc(2026, 7, 26, 5, 5).millisecondsSinceEpoch,
    );
    expect(frame.sublist(76, 108), everyElement(18));
    expect(frame.sublist(108, 140), everyElement(4));
    expect(frame.sublist(140, 172), everyElement(5));
    expect(frame.sublist(172, 204), everyElement(24));
    expect(frame.sublist(204, 204 + deviceNameBytes.length), deviceNameBytes);
    expect(
      frame.sublist(204 + deviceNameBytes.length, frame.length - 4),
      clientVersionBytes,
    );
    expect(
      frameData.getUint32(frame.length - 4, Endian.big),
      getCrc32(Uint8List.sublistView(frame, 0, frame.length - 4)),
    );

    payload.dispose();
    expect(sourceSecret, everyElement(0));
    final decoded = CloudSyncDevicePairingQrCodec.decodeTakingOwnership(
      frame,
      now: now,
    );
    expect(frame, everyElement(0));
    expect(decoded.protocolVersion, cloudSyncOpaqueProtocolVersion);
    expect(decoded.platform, CloudSyncPlatform.android);
    expect(decoded.untrustedDeviceName, 'Android 手机');
    expect(decoded.untrustedClientVersion, '1.2.3');
    expect(decoded.keyVersion, 1);
    expect(decoded.expiresAt, DateTime.utc(2026, 7, 26, 5, 5));
    expect(decoded.pairingId, _pairingId);
    expect(decoded.accountContextId, _userId);
    expect(decoded.targetDeviceId, _deviceId2);
    expect(decoded.challenge, everyElement(18));
    expect(decoded.signingPublicKey, everyElement(4));
    expect(decoded.keyAgreementPublicKey, everyElement(5));
    expect(
      () => decoded.requireAccountContextMatchesLocalUserId(_userId),
      returnsNormally,
    );
    expect(
      () => decoded.requireAccountContextMatchesLocalUserId(_accountContextId),
      throwsA(isA<FormatException>()),
    );
    final decodedSecret = decoded.takePairingSecret();
    expect(decodedSecret, everyElement(24));
    expect(decoded.isDisposed, isTrue);
    decodedSecret.fillRange(0, decodedSecret.length, 0);
    expect(decodedSecret, everyElement(0));

    final disposableFrame = _validPairingQrFrame();
    final disposableDecoded =
        CloudSyncDevicePairingQrCodec.decodeTakingOwnership(
          disposableFrame,
          now: now,
        );
    disposableDecoded.dispose();
    expect(disposableDecoded.isDisposed, isTrue);
    expect(disposableDecoded.takePairingSecret, throwsStateError);
  });

  final invalidPairingQrPayloads =
      <
        ({
          String name,
          CloudSyncDevicePairingQrPayload Function(Uint8List secret) create,
        })
      >[
        (
          name: '协议版本',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            protocolVersion: cloudSyncOpaqueProtocolVersion + 1,
          ),
        ),
        (
          name: '设备名空白',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            deviceName: ' Android 手机',
          ),
        ),
        (
          name: '设备名长度',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            deviceName: List<String>.filled(81, 'x').join(),
          ),
        ),
        (
          name: '客户端版本',
          create: (secret) =>
              _pairingQrPayload(pairingSecret: secret, clientVersion: '1/2'),
        ),
        (
          name: 'keyVersion 下界',
          create: (secret) =>
              _pairingQrPayload(pairingSecret: secret, keyVersion: 0),
        ),
        (
          name: 'keyVersion 上界',
          create: (secret) =>
              _pairingQrPayload(pairingSecret: secret, keyVersion: 0x80000000),
        ),
        (
          name: 'pairingId 规范形式',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            pairingId: 'ABCDEFAB-CDEF-4ABC-8DEF-ABCDEFABCDEF',
          ),
        ),
        (
          name: 'accountContextId UUID 版本',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            accountContextId: 'abcdefab-cdef-3abc-8def-abcdefabcdef',
          ),
        ),
        (
          name: 'targetDeviceId UUID variant',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            targetDeviceId: 'abcdefab-cdef-4abc-7def-abcdefabcdef',
          ),
        ),
        (
          name: 'challenge 长度',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            challenge: _filledBytes(cloudSyncDeviceChallengeBytes - 1),
          ),
        ),
        (
          name: '签名公钥长度',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            signingPublicKey: _filledBytes(cloudSyncDevicePublicKeyBytes + 1),
          ),
        ),
        (
          name: '密钥协商公钥长度',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            keyAgreementPublicKey: _filledBytes(
              cloudSyncDevicePublicKeyBytes - 1,
            ),
          ),
        ),
        (
          name: '到期边界',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            expiresAt: DateTime.utc(2026, 7, 26, 5),
          ),
        ),
        (
          name: '五分钟上界',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            expiresAt: DateTime.utc(2026, 7, 26, 5, 5, 0, 1),
          ),
        ),
        (
          name: '毫秒精度',
          create: (secret) => _pairingQrPayload(
            pairingSecret: secret,
            expiresAt: DateTime.utc(
              2026,
              7,
              26,
              5,
              4,
            ).add(const Duration(microseconds: 1)),
          ),
        ),
      ];
  for (final invalid in invalidPairingQrPayloads) {
    test('设备配对 QR payload 拒绝非法${invalid.name}并清零 secret', () {
      final secret = _filledBytes(cloudSyncPairingSecretBytes, 24);

      expect(() => invalid.create(secret), throwsA(isA<FormatException>()));
      expect(secret, everyElement(0));
    });
  }

  test('设备配对 QR payload 拒绝错误 secret 长度并清零', () {
    final secret = _filledBytes(cloudSyncPairingSecretBytes - 1, 24);

    expect(
      () => _pairingQrPayload(pairingSecret: secret),
      throwsA(isA<FormatException>()),
    );
    expect(secret, everyElement(0));
  });

  final invalidPairingQrFrames =
      <({String name, void Function(Uint8List frame) mutate})>[
        (name: 'magic', mutate: (frame) => frame[0] ^= 0xff),
        (name: '帧版本', mutate: (frame) => frame[4] = 2),
        (name: 'flags', mutate: (frame) => frame[5] = 1),
        (
          name: 'totalLength',
          mutate: (frame) => ByteData.sublistView(
            frame,
          ).setUint16(6, frame.length - 1, Endian.big),
        ),
        (name: '设备名长度', mutate: (frame) => frame[13] += 1),
        (name: 'reserved', mutate: (frame) => frame[15] = 1),
        (name: 'CRC', mutate: (frame) => frame[172] ^= 0xff),
      ];
  for (final invalid in invalidPairingQrFrames) {
    test('设备配对 QR 解码拒绝非法${invalid.name}并清零帧', () {
      final frame = _validPairingQrFrame();
      invalid.mutate(frame);

      expect(
        () => CloudSyncDevicePairingQrCodec.decodeTakingOwnership(
          frame,
          now: DateTime.utc(2026, 7, 26, 5),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(frame, everyElement(0));
    });
  }

  final invalidPairingQrTranscripts =
      <({String name, void Function(Uint8List frame) mutate})>[
        (
          name: 'protocolVersion',
          mutate: (frame) {
            ByteData.sublistView(frame).setUint32(8, 2, Endian.big);
            _refreshPairingQrCrc(frame);
          },
        ),
        (
          name: 'platform',
          mutate: (frame) {
            frame[12] = 0;
            _refreshPairingQrCrc(frame);
          },
        ),
        (
          name: 'keyVersion',
          mutate: (frame) {
            ByteData.sublistView(frame).setUint32(16, 0, Endian.big);
            _refreshPairingQrCrc(frame);
          },
        ),
        (
          name: 'expiresAt',
          mutate: (frame) {
            ByteData.sublistView(
              frame,
            ).setUint64(20, 0xffffffffffffffff, Endian.big);
            _refreshPairingQrCrc(frame);
          },
        ),
        (
          name: 'pairingId UUID',
          mutate: (frame) {
            frame[28 + 6] = (frame[28 + 6] & 0x0f) | 0x30;
            _refreshPairingQrCrc(frame);
          },
        ),
        (
          name: 'accountContextId UUID',
          mutate: (frame) {
            frame[44 + 8] = (frame[44 + 8] & 0x3f) | 0x40;
            _refreshPairingQrCrc(frame);
          },
        ),
        (
          name: 'targetDeviceId UUID',
          mutate: (frame) {
            frame[60 + 6] = (frame[60 + 6] & 0x0f) | 0x50;
            _refreshPairingQrCrc(frame);
          },
        ),
        (
          name: '设备名 UTF-8',
          mutate: (frame) {
            frame[204] = 0xff;
            _refreshPairingQrCrc(frame);
          },
        ),
        (
          name: 'clientVersion',
          mutate: (frame) {
            final clientVersionOffset = 204 + frame[13];
            frame[clientVersionOffset] = 0x2f;
            _refreshPairingQrCrc(frame);
          },
        ),
      ];
  for (final invalid in invalidPairingQrTranscripts) {
    test('设备配对 QR 解码拒绝非法${invalid.name}并清零帧', () {
      final frame = _validPairingQrFrame();
      invalid.mutate(frame);

      expect(
        () => CloudSyncDevicePairingQrCodec.decodeTakingOwnership(
          frame,
          now: DateTime.utc(2026, 7, 26, 5),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(frame, everyElement(0));
    });
  }

  for (final lengthDelta in <int>[-1, 1]) {
    test('设备配对 QR 解码拒绝非规范总长度 $lengthDelta', () {
      final validFrame = _validPairingQrFrame();
      final frame = Uint8List(validFrame.length + lengthDelta);
      frame.setRange(
        0,
        lengthDelta < 0 ? frame.length : validFrame.length,
        validFrame,
      );
      validFrame.fillRange(0, validFrame.length, 0);

      expect(
        () => CloudSyncDevicePairingQrCodec.decodeTakingOwnership(
          frame,
          now: DateTime.utc(2026, 7, 26, 5),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(frame, everyElement(0));
    });
  }

  for (final decodeNow in <DateTime>[
    DateTime.utc(2026, 7, 26, 4, 59, 59, 999),
    DateTime.utc(2026, 7, 26, 5, 5),
  ]) {
    test('设备配对 QR 解码拒绝越界时间 $decodeNow 并清零帧', () {
      final frame = _validPairingQrFrame();

      expect(
        () => CloudSyncDevicePairingQrCodec.decodeTakingOwnership(
          frame,
          now: decodeNow,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(frame, everyElement(0));
    });
  }

  test('认证与配对请求在发网前拒绝错误长度和越界 keyEpoch', () {
    final client = CloudSyncClient.forTesting(baseUrl: 'http://127.0.0.1:1');
    addTearDown(() => client.close(force: true));
    final identity = _deviceIdentity();
    final invalidCalls = <(String, Object? Function())>[
      (
        '注册请求长度',
        () => client.startOpaqueRegistration(
          loginName: 'alice',
          displayName: 'Alice',
          device: identity,
          registrationRequest: _filledBytes(
            cloudSyncOpaqueRegistrationRequestBytes - 1,
          ),
        ),
      ),
      (
        '注册上传长度',
        () => client.finishOpaqueRegistration(
          attemptId: _attemptId1,
          registrationUpload: _filledBytes(
            cloudSyncOpaqueRegistrationUploadBytes + 1,
          ),
          accountKeyEnvelope: _filledBytes(cloudSyncAccountKeyEnvelopeBytes),
          deviceProof: _filledBytes(cloudSyncDeviceProofBytes),
        ),
      ),
      (
        '登录请求长度',
        () => client.startOpaqueLogin(
          loginName: 'alice',
          device: identity,
          credentialRequest: _filledBytes(
            cloudSyncOpaqueCredentialRequestBytes - 1,
          ),
        ),
      ),
      (
        '登录完成长度',
        () => client.finishOpaqueLogin(
          attemptId: _attemptId1,
          credentialFinalization: _filledBytes(
            cloudSyncOpaqueCredentialFinalizationBytes - 1,
          ),
          deviceProof: _filledBytes(cloudSyncDeviceProofBytes),
        ),
      ),
      (
        '配对密钥摘要长度',
        () => client.createDevicePairing(
          token: _onboardingToken,
          pairingId: _pairingId,
          pairingSecretHash: _filledBytes(cloudSyncPairingSecretHashBytes + 1),
        ),
      ),
      (
        'key epoch 下界',
        () => client.approveDevicePairing(
          token: _fullToken,
          pairingId: _pairingId,
          keyEpoch: 0,
          accountKeyEnvelope: _filledBytes(cloudSyncAccountKeyEnvelopeBytes),
          deviceProof: _filledBytes(cloudSyncDeviceProofBytes),
          pairingAuthenticator: _filledBytes(
            cloudSyncPairingAuthenticatorBytes,
          ),
        ),
      ),
      (
        'key epoch 上界',
        () => client.approveDevicePairing(
          token: _fullToken,
          pairingId: _pairingId,
          keyEpoch: 0x100000000,
          accountKeyEnvelope: _filledBytes(cloudSyncAccountKeyEnvelopeBytes),
          deviceProof: _filledBytes(cloudSyncDeviceProofBytes),
          pairingAuthenticator: _filledBytes(
            cloudSyncPairingAuthenticatorBytes,
          ),
        ),
      ),
    ];

    for (final invalidCall in invalidCalls) {
      expect(
        invalidCall.$2,
        throwsA(
          isA<CloudSyncException>()
              .having(
                (error) => error.kind,
                'kind',
                CloudSyncFailureKind.validation,
              )
              .having((error) => error.retryable, 'retryable', isFalse),
        ),
        reason: invalidCall.$1,
      );
    }
  });

  test('认证响应拒绝非规范 Base64URL 和 generated 模型缺字段', () async {
    final canonicalChallenge = _encodedBytes(cloudSyncDeviceChallengeBytes);
    final invalidChallenges = <String>[
      '$canonicalChallenge=',
      '${canonicalChallenge.substring(0, canonicalChallenge.length - 1)}B',
      canonicalChallenge.substring(0, canonicalChallenge.length - 1),
    ];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requestIndex = 0;
    final subscription = server.listen((request) async {
      await utf8.decoder.bind(request).join();
      final currentIndex = requestIndex++;
      final omitRegistrationResponse = currentIndex == invalidChallenges.length;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{
          'data': <String, Object?>{
            'protocolVersion': cloudSyncOpaqueProtocolVersion,
            'attemptId': _attemptId1,
            'userId': _userId,
            'accountBinding': _accountContextId,
            'deviceChallenge': omitRegistrationResponse
                ? canonicalChallenge
                : invalidChallenges[currentIndex],
            if (!omitRegistrationResponse)
              'registrationResponse': _encodedBytes(
                cloudSyncOpaqueRegistrationResponseBytes,
              ),
            'expiresAt': '2026-07-26T05:05:00.000Z',
          },
        }),
      );
      await request.response.close();
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    });

    final invalidResponse = throwsA(
      isA<CloudSyncException>()
          .having(
            (error) => error.kind,
            'kind',
            CloudSyncFailureKind.invalidResponse,
          )
          .having((error) => error.retryable, 'retryable', isFalse),
    );
    for (var index = 0; index <= invalidChallenges.length; index++) {
      await expectLater(
        client.startOpaqueRegistration(
          loginName: 'alice',
          displayName: 'Alice',
          device: _deviceIdentity(),
          registrationRequest: _filledBytes(
            cloudSyncOpaqueRegistrationRequestBytes,
          ),
        ),
        invalidResponse,
      );
    }
  });

  test('同步服务响应重定向时拒绝访问目标地址', () async {
    final target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var targetRequestCount = 0;
    final targetSubscription = target.listen((request) async {
      targetRequestCount++;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{
          'data': <String, Object?>{
            'service': 'kelivo-api',
            'status': 'ok',
            'timestamp': '2026-07-19T05:00:00.000Z',
          },
        }),
      );
      await request.response.close();
    });

    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final originSubscription = origin.listen((request) async {
      request.response
        ..statusCode = HttpStatus.found
        ..headers.set(
          HttpHeaders.locationHeader,
          'http://${target.address.address}:${target.port}'
          '/api/system/health/get',
        );
      await request.response.close();
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${origin.address.address}:${origin.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await originSubscription.cancel();
      await targetSubscription.cancel();
      await origin.close(force: true);
      await target.close(force: true);
    });

    await expectLater(
      client.health(),
      throwsA(
        isA<CloudSyncException>()
            .having(
              (error) => error.kind,
              'kind',
              CloudSyncFailureKind.invalidResponse,
            )
            .having(
              (error) => error.statusCode,
              'statusCode',
              HttpStatus.found,
            ),
      ),
    );
    expect(targetRequestCount, 0);
  });

  test('账户记录加密器派生稳定不透明标识并限制明文生命周期', () async {
    const core = KelivoSecureCore();
    final ark = await core.generateAccountRootKey();
    final cipher = E2eeAccountRecordCipher.takeOwnership(
      secureCore: core,
      accountRootKey: ark,
      userId: _userId,
      currentKeyEpoch: 7,
    );
    addTearDown(cipher.close);

    const entityKey = SyncEntityKey(
      entityType: 'conversation',
      entityId: 'conversation-1',
    );
    const otherEntityKey = SyncEntityKey(
      entityType: 'message',
      entityId: 'conversation-1',
    );
    final payload = Uint8List.fromList(<int>[1, 2, 3]);
    final firstId = await cipher.deriveRecordId(entityKey);
    final repeatedId = await cipher.deriveRecordId(entityKey);
    final otherId = await cipher.deriveRecordId(otherEntityKey);
    final first = await cipher.seal(entityKey: entityKey, payload: payload);
    final second = await cipher.seal(entityKey: entityKey, payload: payload);

    expect(firstId, repeatedId);
    expect(first.recordId, firstId);
    expect(otherId, isNot(firstId));
    expect(first.ciphertext, isNot(orderedEquals(second.ciphertext)));
    final recordIdBytes = _rawUuid(firstId.wireValue);
    expect(recordIdBytes[6] & 0xf0, 0x40);
    expect(recordIdBytes[8] & 0xc0, 0x80);
    expect(payload, orderedEquals(<int>[1, 2, 3]));

    Uint8List? borrowedPayload;
    final opened = await cipher.open(
      _untrustedRecord(first),
      decode: (openedKey, borrowed) {
        expect(openedKey, entityKey);
        borrowedPayload = borrowed;
        return Uint8List.fromList(borrowed);
      },
    );
    expect(opened, orderedEquals(payload));
    expect(borrowedPayload, everyElement(0));
    expect(payload, orderedEquals(<int>[1, 2, 3]));
  });

  test('账户记录加密器拒绝篡改、错误标识、未来世代与越界内容', () async {
    const core = KelivoSecureCore();
    final ark = await core.generateAccountRootKey();
    final cipher = E2eeAccountRecordCipher.takeOwnership(
      secureCore: core,
      accountRootKey: ark,
      userId: _userId,
      currentKeyEpoch: 7,
    );
    addTearDown(cipher.close);

    const entityKey = SyncEntityKey(
      entityType: 'conversation',
      entityId: 'conversation-1',
    );
    const otherEntityKey = SyncEntityKey(
      entityType: 'conversation',
      entityId: 'conversation-2',
    );
    final sealed = await cipher.seal(
      entityKey: entityKey,
      payload: Uint8List(0),
    );
    final otherId = await cipher.deriveRecordId(otherEntityKey);
    final tampered = Uint8List.fromList(sealed.ciphertext);
    tampered[tampered.length - 1] ^= 1;

    await expectLater(
      cipher.open<Object?>(
        _untrustedRecord(sealed, ciphertext: tampered),
        decode: (_, _) => null,
      ),
      throwsA(isA<KelivoSecureCoreException>()),
    );
    await expectLater(
      cipher.open<Object?>(
        _untrustedRecord(
          sealed,
          recordId: E2eeUntrustedAccountRecordId.fromTransport(
            otherId.wireValue,
          ),
        ),
        decode: (_, _) => null,
      ),
      throwsA(isA<KelivoSecureCoreException>()),
    );
    await expectLater(
      cipher.open<Object?>(
        _untrustedRecord(sealed, keyEpoch: 8),
        decode: (_, _) => null,
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      cipher.deriveRecordId(
        const SyncEntityKey(entityType: 'Conversation', entityId: '1'),
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      cipher.deriveRecordId(
        SyncEntityKey(
          entityType: 'message',
          entityId: List<String>.filled(1025, 'a').join(),
        ),
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      cipher.deriveRecordId(
        SyncEntityKey(
          entityType: 'message',
          entityId: String.fromCharCode(0xd800),
        ),
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      cipher.seal(
        entityKey: entityKey,
        payload: Uint8List(e2eeAccountRecordMaxCiphertextBytes),
      ),
      throwsA(isA<ArgumentError>()),
    );

    await cipher.close();
    await expectLater(
      cipher.deriveRecordId(entityKey),
      throwsA(isA<StateError>()),
    );
  });

  test('账户记录加密器隔离用户 AAD 并拒绝帧内实体键替换', () async {
    const core = KelivoSecureCore();
    const firstKey = SyncEntityKey(
      entityType: 'conversation',
      entityId: 'conversation-1',
    );
    const secondKey = SyncEntityKey(
      entityType: 'conversation',
      entityId: 'conversation-2',
    );

    final aadArk = await core.generateAccountRootKey();
    final wrongUserRecord = await _sealRawAccountRecord(
      core: core,
      ark: aadArk,
      recordIdKey: firstKey,
      frameKey: firstKey,
      userId: _userId,
    );
    final wrongUserCipher = E2eeAccountRecordCipher.takeOwnership(
      secureCore: core,
      accountRootKey: aadArk,
      userId: _accountContextId,
      currentKeyEpoch: 7,
    );
    addTearDown(wrongUserCipher.close);
    await expectLater(
      wrongUserCipher.open<Object?>(wrongUserRecord, decode: (_, _) => null),
      throwsA(isA<KelivoSecureCoreException>()),
    );

    final identityArk = await core.generateAccountRootKey();
    final mismatchedRecord = await _sealRawAccountRecord(
      core: core,
      ark: identityArk,
      recordIdKey: firstKey,
      frameKey: secondKey,
      userId: _userId,
    );
    final identityCipher = E2eeAccountRecordCipher.takeOwnership(
      secureCore: core,
      accountRootKey: identityArk,
      userId: _userId,
      currentKeyEpoch: 7,
    );
    addTearDown(identityCipher.close);
    await expectLater(
      identityCipher.open<Object?>(mismatchedRecord, decode: (_, _) => null),
      throwsA(isA<FormatException>()),
    );
  });

  test('不可信账户记录信封严格校验传输边界', () {
    expect(
      () => E2eeUntrustedAccountRecordId.fromTransport(
        'A0000000-0000-4000-8000-000000000001',
      ),
      throwsA(isA<FormatException>()),
    );
    final recordId = E2eeUntrustedAccountRecordId.fromTransport(_recordId1);
    final validEpochs = <int>[1, 0x7fffffff];
    for (final keyEpoch in validEpochs) {
      expect(
        E2eeUntrustedAccountRecordEnvelope.fromTransport(
          recordId: recordId,
          envelopeVersion: e2eeAccountRecordEnvelopeVersion,
          keyEpoch: keyEpoch,
          ciphertext: Uint8List.fromList(<int>[1]),
        ).keyEpoch,
        keyEpoch,
      );
    }
    for (final invalid in <({int version, int epoch, Uint8List ciphertext})>[
      (version: 2, epoch: 1, ciphertext: Uint8List.fromList(<int>[1])),
      (version: 1, epoch: 0, ciphertext: Uint8List.fromList(<int>[1])),
      (version: 1, epoch: 0x80000000, ciphertext: Uint8List.fromList(<int>[1])),
      (version: 1, epoch: 1, ciphertext: Uint8List(0)),
      (
        version: 1,
        epoch: 1,
        ciphertext: Uint8List(e2eeAccountRecordMaxCiphertextBytes + 1),
      ),
    ]) {
      expect(
        () => E2eeUntrustedAccountRecordEnvelope.fromTransport(
          recordId: recordId,
          envelopeVersion: invalid.version,
          keyEpoch: invalid.epoch,
          ciphertext: invalid.ciphertext,
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('v3 推送绑定显式令牌且只接受加密 put 并解析三类结果', () async {
    const core = KelivoSecureCore();
    final ark = await core.generateAccountRootKey();
    final cipher = E2eeAccountRecordCipher.takeOwnership(
      secureCore: core,
      accountRootKey: ark,
      userId: _userId,
      currentKeyEpoch: 7,
    );
    final stateCodec = E2eeAccountRecordStateCodec.takeOwnership(cipher);
    addTearDown(stateCodec.close);
    final firstState = await stateCodec.sealValue(
      entityKey: const SyncEntityKey(
        entityType: 'conversation',
        entityId: 'conversation-1',
      ),
      logicalVersion: 1,
      parentDigests: const [],
      operationId: _mutationId1,
      claimedWriterDeviceId: _deviceId1,
      claimedWriterKeyVersion: 1,
      payload: Uint8List.fromList(<int>[1, 2, 3]),
    );
    final secondState = await stateCodec.sealValue(
      entityKey: const SyncEntityKey(
        entityType: 'conversation',
        entityId: 'conversation-2',
      ),
      logicalVersion: 1,
      parentDigests: const [],
      operationId: _mutationId2,
      claimedWriterDeviceId: _deviceId1,
      claimedWriterKeyVersion: 1,
      payload: Uint8List.fromList(<int>[7, 8, 9]),
    );
    final thirdState = await stateCodec.sealValue(
      entityKey: const SyncEntityKey(
        entityType: 'message',
        entityId: 'message-1',
      ),
      logicalVersion: 1,
      parentDigests: const [],
      operationId: _mutationId3,
      claimedWriterDeviceId: _deviceId1,
      claimedWriterKeyVersion: 1,
      payload: Uint8List.fromList(<int>[4, 5, 6]),
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final pushFuture = client.pushRecordsWithToken(<CloudSyncRecordMutation>[
      CloudSyncPutRecordMutation(
        mutationId: _mutationId1,
        expectedRevision: 0,
        state: firstState,
      ),
      CloudSyncPutRecordMutation(
        mutationId: _mutationId2,
        expectedRevision: 3,
        state: secondState,
      ),
      CloudSyncPutRecordMutation(
        mutationId: _mutationId3,
        expectedRevision: 2,
        state: thirdState,
      ),
    ], token: _fullToken);
    client.setToken(_otherFullToken);

    final request = await requestFuture;
    expect(request.uri.path, '/api/sync/record/push');
    expect(
      request.headers.value(HttpHeaders.authorizationHeader),
      'Bearer $_fullTokenValue',
    );
    expect(request.headers.value('x-kelivo-sync-protocol-version'), '3');
    expect(
      jsonDecode(await utf8.decoder.bind(request).join()),
      <String, Object?>{
        'mutations': <Object?>[
          <String, Object?>{
            'mutationId': _mutationId1,
            'recordId': firstState.record.recordId.wireValue,
            'expectedRevision': 0,
            'operation': 'put',
            'envelopeVersion': 1,
            'keyEpoch': 7,
            'ciphertext': _encodedRecordCiphertext(firstState.record),
          },
          <String, Object?>{
            'mutationId': _mutationId2,
            'recordId': secondState.record.recordId.wireValue,
            'expectedRevision': 3,
            'operation': 'put',
            'envelopeVersion': 1,
            'keyEpoch': 7,
            'ciphertext': _encodedRecordCiphertext(secondState.record),
          },
          <String, Object?>{
            'mutationId': _mutationId3,
            'recordId': thirdState.record.recordId.wireValue,
            'expectedRevision': 2,
            'operation': 'put',
            'envelopeVersion': 1,
            'keyEpoch': 7,
            'ciphertext': _encodedRecordCiphertext(thirdState.record),
          },
        ],
      },
    );
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'results': <Object?>[
            <String, Object?>{
              'mutationId': _mutationId1,
              'status': 'applied',
              'revision': 1,
              'changeSeq': 11,
            },
            <String, Object?>{
              'mutationId': _mutationId2,
              'status': 'conflict',
              'currentRevision': 4,
            },
            <String, Object?>{
              'mutationId': _mutationId3,
              'status': 'rejected',
              'errorCode': 'SYNC_RECORD_REJECTED',
            },
          ],
        },
      }),
    );
    await request.response.close();

    final results = await pushFuture;
    expect(
      results[0],
      isA<CloudSyncAppliedMutationResult>()
          .having((result) => result.revision, 'revision', 1)
          .having((result) => result.changeSeq, 'changeSeq', 11),
    );
    expect(
      results[1],
      isA<CloudSyncConflictMutationResult>().having(
        (result) => result.currentRevision,
        'currentRevision',
        4,
      ),
    );
    expect(
      results[2],
      isA<CloudSyncRejectedMutationResult>().having(
        (result) => result.errorCode,
        'errorCode',
        'SYNC_RECORD_REJECTED',
      ),
    );
  });

  test('v3 推送在发网前拒绝 mutationId 与认证 operationId 不一致', () async {
    const core = KelivoSecureCore();
    final ark = await core.generateAccountRootKey();
    final cipher = E2eeAccountRecordCipher.takeOwnership(
      secureCore: core,
      accountRootKey: ark,
      userId: _userId,
      currentKeyEpoch: 7,
    );
    final stateCodec = E2eeAccountRecordStateCodec.takeOwnership(cipher);
    addTearDown(stateCodec.close);
    final state = await stateCodec.sealValue(
      entityKey: const SyncEntityKey(
        entityType: 'conversation',
        entityId: 'conversation-1',
      ),
      logicalVersion: 1,
      parentDigests: const [],
      operationId: _mutationId1,
      claimedWriterDeviceId: _deviceId1,
      claimedWriterKeyVersion: 1,
      payload: Uint8List.fromList(<int>[1, 2, 3]),
    );

    expect(
      () => CloudSyncPutRecordMutation(
        mutationId: _mutationId2,
        expectedRevision: 0,
        state: state,
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.name,
          'name',
          'mutationId',
        ),
      ),
    );
  });

  test('v3 增量拉取保持 put 密文不透明', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final pullFuture = client.pullChanges(cursor: 'cursor-1', limit: 1);

    final request = await requestFuture;
    expect(request.uri.path, '/api/sync/change/pull');
    expect(request.headers.value('x-kelivo-sync-protocol-version'), '3');
    expect(
      jsonDecode(await utf8.decoder.bind(request).join()),
      <String, Object?>{'cursor': 'cursor-1', 'limit': 1},
    );
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'changes': <Object?>[
            <String, Object?>{
              'changeSeq': 12,
              'operation': 'put',
              'recordId': _recordId1,
              'revision': 2,
              'envelopeVersion': 1,
              'keyEpoch': 7,
              'ciphertext': 'AQID',
              'ciphertextBytes': 3,
              'deletedAt': null,
              'updatedAt': '2026-07-19T05:00:00.000Z',
              'updatedByDeviceId': _deviceId1,
            },
          ],
          'nextCursor': 'cursor-2',
          'hasMore': true,
          'resetRequired': false,
        },
      }),
    );
    await request.response.close();

    final page = await pullFuture;
    expect(page.nextCursor, 'cursor-2');
    expect(page.hasMore, isTrue);
    expect(page.resetRequired, isFalse);
    expect(
      page.changes[0],
      isA<CloudSyncPutRecordChange>()
          .having((change) => change.changeSeq, 'changeSeq', 12)
          .having((change) => change.recordId.wireValue, 'recordId', _recordId1)
          .having((change) => change.revision, 'revision', 2)
          .having((change) => change.record.keyEpoch, 'keyEpoch', 7)
          .having(
            (change) => change.record.ciphertext,
            'ciphertext',
            orderedEquals(<int>[1, 2, 3]),
          )
          .having(
            (change) => change.updatedByDeviceId,
            'updatedByDeviceId',
            _deviceId1,
          ),
    );
  });

  test('v3 增量拉取拒绝包含 raw delete 的整页响应', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final pullFuture = client.pullChanges(cursor: 'cursor-1', limit: 2);
    final request = await requestFuture;
    await utf8.decoder.bind(request).join();
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'changes': <Object?>[
            <String, Object?>{
              'changeSeq': 12,
              'operation': 'put',
              'recordId': _recordId1,
              'revision': 2,
              'envelopeVersion': 1,
              'keyEpoch': 7,
              'ciphertext': 'AQID',
              'ciphertextBytes': 3,
              'deletedAt': null,
              'updatedAt': '2026-07-19T05:00:00.000Z',
              'updatedByDeviceId': _deviceId1,
            },
            <String, Object?>{
              'changeSeq': 13,
              'operation': 'delete',
              'recordId': _recordId2,
              'revision': 4,
              'envelopeVersion': null,
              'keyEpoch': null,
              'ciphertext': null,
              'ciphertextBytes': 0,
              'deletedAt': '2026-07-19T05:01:00.000Z',
              'updatedAt': '2026-07-19T05:01:00.000Z',
              'updatedByDeviceId': null,
            },
          ],
          'nextCursor': 'cursor-2',
          'hasMore': true,
          'resetRequired': false,
        },
      }),
    );
    await request.response.close();

    await expectLater(
      pullFuture,
      throwsA(
        isA<CloudSyncException>()
            .having(
              (error) => error.kind,
              'kind',
              CloudSyncFailureKind.invalidResponse,
            )
            .having((error) => error.retryable, 'retryable', isFalse),
      ),
    );
  });

  test('v3 增量拉取显式返回服务端要求重置游标', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final pullFuture = client.pullChanges();
    final request = await requestFuture;
    expect(
      jsonDecode(await utf8.decoder.bind(request).join()),
      <String, Object?>{'limit': 10},
    );
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'changes': <Object?>[],
          'nextCursor': 'reset-cursor',
          'hasMore': false,
          'resetRequired': true,
        },
      }),
    );
    await request.response.close();

    final page = await pullFuture;
    expect(page.changes, isEmpty);
    expect(page.nextCursor, 'reset-cursor');
    expect(page.hasMore, isFalse);
    expect(page.resetRequired, isTrue);
  });

  test('v3 快照拉取解析 active 并返回固定水位游标', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final pullFuture = client.pullSnapshot(
      snapshotCursor: 'snapshot-1',
      limit: 1,
    );

    final request = await requestFuture;
    expect(request.uri.path, '/api/sync/snapshot/pull');
    expect(request.headers.value('x-kelivo-sync-protocol-version'), '3');
    expect(
      jsonDecode(await utf8.decoder.bind(request).join()),
      <String, Object?>{'snapshotCursor': 'snapshot-1', 'limit': 1},
    );
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'records': <Object?>[
            <String, Object?>{
              'recordId': _recordId1,
              'revision': 2,
              'envelopeVersion': 1,
              'keyEpoch': 7,
              'ciphertext': 'BAUG',
              'ciphertextBytes': 3,
              'deletedAt': null,
              'updatedAt': '2026-07-19T05:00:00.000Z',
              'updatedByDeviceId': _deviceId1,
              'lastChangeSeq': 12,
            },
          ],
          'nextSnapshotCursor': null,
          'syncCursor': 'sync-13',
          'hasMore': false,
        },
      }),
    );
    await request.response.close();

    final page = await pullFuture;
    expect(page.nextSnapshotCursor, isNull);
    expect(page.syncCursor, 'sync-13');
    expect(page.hasMore, isFalse);
    expect(
      page.records[0],
      isA<CloudSyncActiveRecord>()
          .having((record) => record.recordId.wireValue, 'recordId', _recordId1)
          .having((record) => record.revision, 'revision', 2)
          .having((record) => record.lastChangeSeq, 'lastChangeSeq', 12)
          .having((record) => record.record.keyEpoch, 'keyEpoch', 7)
          .having(
            (record) => record.record.ciphertext,
            'ciphertext',
            orderedEquals(<int>[4, 5, 6]),
          ),
    );
  });

  test('v3 快照拉取拒绝包含 raw deleted 的整页响应', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final pullFuture = client.pullSnapshot(
      snapshotCursor: 'snapshot-1',
      limit: 2,
    );
    final request = await requestFuture;
    await utf8.decoder.bind(request).join();
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'records': <Object?>[
            <String, Object?>{
              'recordId': _recordId1,
              'revision': 2,
              'envelopeVersion': 1,
              'keyEpoch': 7,
              'ciphertext': 'BAUG',
              'ciphertextBytes': 3,
              'deletedAt': null,
              'updatedAt': '2026-07-19T05:00:00.000Z',
              'updatedByDeviceId': _deviceId1,
              'lastChangeSeq': 12,
            },
            <String, Object?>{
              'recordId': _recordId2,
              'revision': 4,
              'envelopeVersion': null,
              'keyEpoch': null,
              'ciphertext': null,
              'ciphertextBytes': 0,
              'deletedAt': '2026-07-19T05:01:00.000Z',
              'updatedAt': '2026-07-19T05:01:00.000Z',
              'updatedByDeviceId': null,
              'lastChangeSeq': 13,
            },
          ],
          'nextSnapshotCursor': null,
          'syncCursor': 'sync-13',
          'hasMore': false,
        },
      }),
    );
    await request.response.close();

    await expectLater(
      pullFuture,
      throwsA(
        isA<CloudSyncException>()
            .having(
              (error) => error.kind,
              'kind',
              CloudSyncFailureKind.invalidResponse,
            )
            .having((error) => error.retryable, 'retryable', isFalse),
      ),
    );
  });

  test('v3 推送在发网前拒绝非法标识与批量边界', () async {
    const core = KelivoSecureCore();
    final ark = await core.generateAccountRootKey();
    final cipher = E2eeAccountRecordCipher.takeOwnership(
      secureCore: core,
      accountRootKey: ark,
      userId: _userId,
      currentKeyEpoch: 7,
    );
    final stateCodec = E2eeAccountRecordStateCodec.takeOwnership(cipher);
    final client = CloudSyncClient.forTesting(baseUrl: 'http://127.0.0.1:1');
    addTearDown(() async {
      client.close(force: true);
      await stateCodec.close();
    });
    final smallState = await stateCodec.sealValue(
      entityKey: const SyncEntityKey(entityType: 'conversation', entityId: '1'),
      logicalVersion: 1,
      parentDigests: const [],
      operationId: _mutationId1,
      claimedWriterDeviceId: _deviceId1,
      claimedWriterKeyVersion: 1,
      payload: Uint8List(0),
    );
    final firstHalfState = await stateCodec.sealValue(
      entityKey: const SyncEntityKey(entityType: 'message', entityId: '1'),
      logicalVersion: 1,
      parentDigests: const [],
      operationId: _mutationId1,
      claimedWriterDeviceId: _deviceId1,
      claimedWriterKeyVersion: 1,
      payload: Uint8List(524200),
    );
    final secondHalfState = await stateCodec.sealValue(
      entityKey: const SyncEntityKey(entityType: 'message', entityId: '2'),
      logicalVersion: 1,
      parentDigests: const [],
      operationId: _mutationId2,
      claimedWriterDeviceId: _deviceId1,
      claimedWriterKeyVersion: 1,
      payload: Uint8List(524200),
    );
    final oversizedBatch = List<CloudSyncRecordMutation>.generate(
      11,
      (_) => CloudSyncPutRecordMutation(
        mutationId: _mutationId1,
        expectedRevision: 1,
        state: smallState,
      ),
    );
    final invalidCalls = <(String, Object? Function())>[
      ('空批次', () => client.pushRecords(const <CloudSyncRecordMutation>[])),
      ('超过十条', () => client.pushRecords(oversizedBatch)),
      (
        '批次密文总量超过一 MiB',
        () => client.pushRecords(<CloudSyncRecordMutation>[
          CloudSyncPutRecordMutation(
            mutationId: _mutationId1,
            expectedRevision: 0,
            state: firstHalfState,
          ),
          CloudSyncPutRecordMutation(
            mutationId: _mutationId2,
            expectedRevision: 0,
            state: secondHalfState,
          ),
        ]),
      ),
    ];

    for (final invalidCall in invalidCalls) {
      expect(
        invalidCall.$2,
        throwsA(
          isA<CloudSyncException>()
              .having(
                (error) => error.kind,
                'kind',
                CloudSyncFailureKind.validation,
              )
              .having((error) => error.retryable, 'retryable', isFalse),
        ),
        reason: invalidCall.$1,
      );
    }
  });

  test('v3 拉取在发网前拒绝非法分页与游标边界', () {
    final client = CloudSyncClient.forTesting(baseUrl: 'http://127.0.0.1:1');
    addTearDown(() => client.close(force: true));
    final oversizedCursor = List<String>.filled(4097, 'a').join();
    final invalidCalls = <(String, Object? Function())>[
      ('增量 limit 下界', () => client.pullChanges(limit: 0)),
      ('增量 limit 上界', () => client.pullChanges(limit: 11)),
      ('增量空游标', () => client.pullChanges(cursor: '')),
      ('增量超长游标', () => client.pullChanges(cursor: oversizedCursor)),
      ('快照 limit 下界', () => client.pullSnapshot(limit: 0)),
      ('快照 limit 上界', () => client.pullSnapshot(limit: 11)),
      ('快照空游标', () => client.pullSnapshot(snapshotCursor: '')),
      ('快照超长游标', () => client.pullSnapshot(snapshotCursor: oversizedCursor)),
    ];

    for (final invalidCall in invalidCalls) {
      expect(
        invalidCall.$2,
        throwsA(
          isA<CloudSyncException>().having(
            (error) => error.kind,
            'kind',
            CloudSyncFailureKind.validation,
          ),
        ),
        reason: invalidCall.$1,
      );
    }
  });

  test('v3 拒绝密文长度、分页数量或最终水位无效的响应', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var changeRequestCount = 0;
    final subscription = server.listen((request) async {
      await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/api/sync/change/pull') {
        changeRequestCount++;
        request.response.write(
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{
              'changes': <Object?>[
                <String, Object?>{
                  'changeSeq': 12,
                  'operation': 'put',
                  'recordId': _recordId1,
                  'revision': 2,
                  'envelopeVersion': 1,
                  'keyEpoch': 7,
                  'ciphertext': changeRequestCount == 2 ? 'AQID=' : 'AQID',
                  'ciphertextBytes': changeRequestCount == 1 ? 4 : 3,
                  'deletedAt': null,
                  'updatedAt': '2026-07-19T05:00:00.000Z',
                  'updatedByDeviceId': _deviceId1,
                },
                if (changeRequestCount > 2)
                  <String, Object?>{
                    'changeSeq': 13,
                    'operation': 'delete',
                    'recordId': _recordId2,
                    'revision': 4,
                    'envelopeVersion': null,
                    'keyEpoch': null,
                    'ciphertext': null,
                    'ciphertextBytes': 0,
                    'deletedAt': '2026-07-19T05:01:00.000Z',
                    'updatedAt': '2026-07-19T05:01:00.000Z',
                    'updatedByDeviceId': null,
                  },
              ],
              'nextCursor': 'cursor-2',
              'hasMore': false,
              'resetRequired': false,
            },
          }),
        );
      } else {
        request.response.write(
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{
              'records': <Object?>[],
              'nextSnapshotCursor': null,
              'syncCursor': null,
              'hasMore': false,
            },
          }),
        );
      }
      await request.response.close();
    });
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    });

    final invalidResponse = throwsA(
      isA<CloudSyncException>()
          .having(
            (error) => error.kind,
            'kind',
            CloudSyncFailureKind.invalidResponse,
          )
          .having((error) => error.retryable, 'retryable', isFalse),
    );
    for (final request in <Future<Object?> Function()>[
      () => client.pullChanges(),
      () => client.pullChanges(),
      () => client.pullChanges(limit: 1),
      () => client.pullSnapshot(),
    ]) {
      await expectLater(request(), invalidResponse);
    }
  });

  test('v3 协议版本错误保留服务端错误码与请求标识', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _fullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final pullFuture = client.pullChanges();
    final request = await requestFuture;
    await utf8.decoder.bind(request).join();
    request.response
      ..statusCode = 426
      ..headers.contentType = ContentType.json
      ..write(
        jsonEncode(<String, Object?>{
          'error': <String, Object?>{
            'code': 'SYNC_PROTOCOL_VERSION_UNSUPPORTED',
            'message': 'unsupported protocol',
            'retryable': false,
          },
          'requestId': 'request-1',
        }),
      );
    await request.response.close();

    await expectLater(
      pullFuture,
      throwsA(
        isA<CloudSyncException>()
            .having(
              (error) => error.kind,
              'kind',
              CloudSyncFailureKind.invalidResponse,
            )
            .having((error) => error.statusCode, 'statusCode', 426)
            .having(
              (error) => error.serverCode,
              'serverCode',
              'SYNC_PROTOCOL_VERSION_UNSUPPORTED',
            )
            .having((error) => error.requestId, 'requestId', 'request-1')
            .having((error) => error.retryable, 'retryable', isFalse),
      ),
    );
  });
}

Uint8List _authenticatorSlotId(String baseUrl, String loginName) {
  final digest = sha256.convert(
    utf8.encode(
      'kelivo.e2ee.device-state.slot.v1\u0000$baseUrl\u0000$loginName',
    ),
  );
  return Uint8List.fromList(digest.bytes.sublist(0, 16));
}

Uint8List _rawUuid(String value) {
  final hex = value.replaceAll('-', '');
  return Uint8List.fromList(<int>[
    for (var offset = 0; offset < hex.length; offset += 2)
      int.parse(hex.substring(offset, offset + 2), radix: 16),
  ]);
}

String _uuidStringForTest(Uint8List value) {
  final hex = value
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

Future<Map<String, Object?>> _seedPendingRegistration({
  required KelivoSecureCore core,
  required DeviceStateBlobStore store,
  required String baseUrl,
  required String loginName,
  required DateTime attemptExpiresAt,
}) async {
  final registrationUpload = _filledBytes(
    cloudSyncOpaqueRegistrationUploadBytes,
    0x51,
  );
  final accountKeyEnvelope = _filledBytes(
    cloudSyncAccountKeyEnvelopeBytes,
    0x52,
  );
  final deviceProof = _filledBytes(cloudSyncDeviceProofBytes, 0x53);
  final expectedRequest = <String, Object?>{
    'protocolVersion': cloudSyncOpaqueProtocolVersion,
    'attemptId': _attemptId1,
    'registrationUpload': base64Url
        .encode(registrationUpload)
        .replaceAll('=', ''),
    'accountKeyEnvelope': base64Url
        .encode(accountKeyEnvelope)
        .replaceAll('=', ''),
    'deviceProof': base64Url.encode(deviceProof).replaceAll('=', ''),
  };
  final key = await core.createSlot(_authenticatorSlotId(baseUrl, loginName));
  final identity = await core.generateDeviceIdentity();
  final ark = await core.generateAccountRootKey();
  final deviceId = _rawUuid(_deviceId1);
  final userId = _rawUuid(_userId);
  final identityOnlyState = Uint8List.fromList(
    await core.sealDeviceState(
      key,
      identity,
      deviceId: deviceId,
      keyVersion: 1,
    ),
  );
  final fullState = Uint8List.fromList(
    await core.sealDeviceState(
      key,
      identity,
      deviceId: deviceId,
      keyVersion: 1,
      ark: ark,
      account: KelivoDeviceStateAccountBinding(userId: userId, keyEpoch: 1),
    ),
  );
  final frame = Uint8List(892);
  final magic = ascii.encode('KELVRT01');
  frame.setRange(0, magic.length, magic);
  final fields = ByteData.sublistView(frame);
  fields.setUint16(8, 1, Endian.big);
  fields.setUint16(10, 0, Endian.big);
  fields.setUint32(12, 1, Endian.big);
  fields.setUint32(16, 1, Endian.big);
  fields.setUint32(20, 0, Endian.big);
  fields.setUint64(
    24,
    attemptExpiresAt.toUtc().millisecondsSinceEpoch,
    Endian.big,
  );
  frame.setRange(32, 48, _rawUuid(_attemptId1));
  frame.setRange(48, 64, userId);
  frame.setRange(64, 80, _rawUuid(_accountContextId));
  frame.setRange(80, 96, deviceId);
  frame.setRange(96, 304, registrationUpload);
  frame.setRange(304, 640, accountKeyEnvelope);
  frame.setRange(640, 704, deviceProof);
  frame.setRange(704, 892, fullState);
  final recordId = Uint8List.fromList(
    sha256
        .convert(
          utf8.encode(
            'kelivo.e2ee.registration-transaction.record.v1\u0000'
            '$baseUrl\u0000$loginName',
          ),
        )
        .bytes
        .sublist(0, 16),
  );
  final associatedData = Uint8List.fromList(
    utf8.encode(
      'kelivo.e2ee.registration-transaction.aad.v1\u0000'
      '$baseUrl\u0000$loginName',
    ),
  );
  try {
    await store.write(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      blob: identityOnlyState,
    );
    final envelope = await core.sealRecord(
      key,
      recordId: recordId,
      epoch: 1,
      associatedData: associatedData,
      plaintext: frame,
    );
    await store.writePendingRegistrationEnvelope(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      envelope: envelope,
    );
  } finally {
    frame.fillRange(0, frame.length, 0);
    identityOnlyState.fillRange(0, identityOnlyState.length, 0);
    fullState.fillRange(0, fullState.length, 0);
    registrationUpload.fillRange(0, registrationUpload.length, 0);
    accountKeyEnvelope.fillRange(0, accountKeyEnvelope.length, 0);
    deviceProof.fillRange(0, deviceProof.length, 0);
    recordId.fillRange(0, recordId.length, 0);
    associatedData.fillRange(0, associatedData.length, 0);
    await core.closeAccountRootKey(ark);
    await core.closeDeviceIdentity(identity);
    await core.close(key);
  }
  return expectedRequest;
}
