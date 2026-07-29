import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_authenticator.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_attachment_types.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_client.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_pairing_qr_codec.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_record_types.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_key_lease.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_record_cipher.dart';
import 'package:Kelivo/core/services/sync/e2ee_attachment_crypto_session.dart';
import 'package:Kelivo/core/services/sync/e2ee_attachment_file_store.dart';
import 'package:Kelivo/core/services/sync/e2ee_attachment_manifest.dart';
import 'package:Kelivo/core/services/sync/e2ee_attachment_upload_coordinator.dart';
import 'package:Kelivo/core/services/sync/e2ee_device_state_access.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_record_state.dart';
import 'package:Kelivo/core/services/sync/e2ee_sync_payload_codec.dart';
import 'package:Kelivo/core/services/sync/sync_codec.dart';
import 'package:Kelivo/core/services/workspace/device_state_blob_store.dart';
import 'package:Kelivo/utils/app_directories.dart';

import '../../database/test_database_cipher.dart';

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
const _attachmentId = '80000000-0000-4000-8000-000000000001';
const _uploadId = '90000000-0000-4000-8000-000000000001';
const _fullTokenValue = 'kelivo_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _otherFullTokenValue =
    'kelivo_BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';
const _onboardingTokenValue =
    'kelivo_onboarding_BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';

final _fullToken = CloudSyncFullSessionToken.parse(_fullTokenValue);
final _otherFullToken = CloudSyncFullSessionToken.parse(_otherFullTokenValue);
final _onboardingToken = CloudSyncOnboardingToken.parse(_onboardingTokenValue);

Map<String, Object?> _validConversationPayload() => <String, Object?>{
  'title': '会话',
  'createdAt': '2026-07-28T00:00:00.000Z',
  'updatedAt': '2026-07-28T00:00:01.000Z',
  'isPinned': false,
  'assistantId': null,
  'mcpServerIds': const <Object?>['mcp-1'],
  'truncateIndex': -1,
  'summary': null,
  'lastSummarizedMessageCount': 0,
  'chatSuggestions': const <Object?>['继续'],
};

Map<String, Object?> _validTurnPayload() => <String, Object?>{
  'conversationId': 'conversation-1',
  'createdAt': '2026-07-28T00:00:00.000Z',
};

Map<String, Object?> _validMessagePayload() => <String, Object?>{
  'conversationId': 'conversation-1',
  'turnId': 'turn-1',
  'role': 'assistant',
  'content': '完成',
  'attachments': const <Object?>[],
  'timestamp': '2026-07-28T00:00:01.000Z',
  'groupId': 'group-1',
  'version': 0,
  'status': 'completed',
  'modelId': null,
  'providerId': null,
  'totalTokens': 1,
  'reasoningText': null,
  'reasoningSegmentsJson': null,
  'translation': null,
  'reasoningStartAt': null,
  'reasoningFinishedAt': null,
  'promptTokens': 1,
  'completionTokens': 0,
  'cachedTokens': 0,
  'durationMs': 1,
};

Map<String, Object?> _validMessageAttachment(int index) {
  final suffix = (index + 1).toRadixString(16).padLeft(12, '0');
  return <String, Object?>{
    'attachmentId': '80000000-0000-4000-8000-$suffix',
    'uploadId': '90000000-0000-4000-8000-$suffix',
    'keyEpoch': 7,
    'kind': index.isEven ? 'image' : 'file',
    'order': index,
  };
}

final class _LengthOnlyAttachments extends ListBase<Object?> {
  @override
  int get length => e2eeSyncMaximumMessageAttachmentCount + 1;

  @override
  set length(int value) => throw UnsupportedError('只用于验证附件数量前置门禁');

  @override
  Object? operator [](int index) => throw StateError('超限附件不应被读取');

  @override
  void operator []=(int index, Object? value) {
    throw UnsupportedError('只用于验证附件数量前置门禁');
  }
}

Map<String, Object?> _validMessageSelectionPayload() => <String, Object?>{
  'conversationId': 'conversation-1',
  'groupId': 'group-1',
  'selectedVersion': 0,
};

Map<String, Object?> _validToolEventPayload({Object? value = true}) =>
    <String, Object?>{
      'messageId': 'message-1',
      'events': <Object?>[
        <String, Object?>{'value': value},
      ],
    };

Map<String, Object?> _validThoughtSignaturePayload() => <String, Object?>{
  'messageId': 'message-1',
  'signature': 'signature',
};

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
    expect(secondResult.deviceKeyVersion, 1);
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

  test('持久账户会话恢复认证会话时保留设备密钥版本', () {
    final persisted = _accountKeyLeaseSession(
      baseUrl: defaultCloudSyncBaseUrl,
      loginName: 'roundtrip-user',
      deviceKeyVersion: 9,
    );

    final authenticated = persisted.toAuthenticatedSession();

    expect(authenticated.token, same(persisted.token));
    expect(authenticated.keyEpoch, persisted.keyEpoch);
    expect(authenticated.user.id, persisted.userId);
    expect(authenticated.device.id, persisted.deviceId);
    expect(authenticated.deviceKeyVersion, 9);
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
    expect(session.deviceKeyVersion, isNull);
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
    expect(session.deviceKeyVersion, 1);
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

  test('账户记录加密器接受完整正 uint32 密钥世代', () async {
    const core = KelivoSecureCore();
    final ark = await core.generateAccountRootKey();
    final cipher = E2eeAccountRecordCipher.takeOwnership(
      secureCore: core,
      accountRootKey: ark,
      userId: _userId,
      currentKeyEpoch: 0xffffffff,
    );
    addTearDown(cipher.close);

    const entityKey = SyncEntityKey(
      entityType: 'conversation',
      entityId: 'conversation-max-epoch',
    );
    final sealed = await cipher.seal(
      entityKey: entityKey,
      payload: Uint8List.fromList(<int>[4, 2]),
    );
    final opened = await cipher.open(
      _untrustedRecord(sealed),
      decode: (_, payload) => Uint8List.fromList(payload),
    );

    expect(sealed.keyEpoch, 0xffffffff);
    expect(opened, orderedEquals(<int>[4, 2]));

    final overflowArk = await core.generateAccountRootKey();
    expect(
      () => E2eeAccountRecordCipher.takeOwnership(
        secureCore: core,
        accountRootKey: overflowArk,
        userId: _userId,
        currentKeyEpoch: 0x100000000,
      ),
      throwsA(isA<FormatException>()),
    );
    await core.closeAccountRootKey(overflowArk);
  });

  test('账户ARK租约只向严格匹配会话转移一次所有权', () async {
    const core = KelivoSecureCore();
    final root = await Directory.current.createTemp('.kelivo-key-lease-');
    addTearDown(() => root.delete(recursive: true));
    final store = DeviceStateBlobStore(installationRoot: root);
    final nonce = sha256
        .convert(utf8.encode(root.path))
        .toString()
        .substring(0, 16);
    final baseUrl = 'https://lease-$nonce.example.com';
    final loginName = 'lease-$nonce';
    final session = await _seedAccountKeyLeaseState(
      core: core,
      store: store,
      baseUrl: baseUrl,
      loginName: loginName,
    );

    final lease = await E2eeAccountKeyLease.open(
      session: session,
      deviceStateStore: store,
      secureCore: core,
    );
    expect(lease.deviceKeyVersion, 3);
    final ark = lease.takeAccountRootKeyOwnership();
    addTearDown(() async {
      try {
        await core.closeAccountRootKey(ark);
      } on StateError {
        // 测试正文可能已经关闭句柄；清理阶段只忽略该确定状态。
      }
    });

    expect(lease.takeAccountRootKeyOwnership, throwsStateError);
    await lease.close();
    await lease.close();
    final recordId = await core.deriveAccountRecordId(
      ark,
      canonicalEntityKey: Uint8List.fromList(utf8.encode('conversation:id')),
    );
    expect(recordId, hasLength(16));
    await core.closeAccountRootKey(ark);
  });

  test('账户ARK租约拒绝会话与设备状态任一绑定不一致', () async {
    const core = KelivoSecureCore();
    final root = await Directory.current.createTemp(
      'kelivo-key-lease-mismatch-',
    );
    addTearDown(() => root.delete(recursive: true));
    final store = DeviceStateBlobStore(installationRoot: root);
    final nonce = sha256
        .convert(utf8.encode(root.path))
        .toString()
        .substring(0, 16);
    final baseUrl = 'https://lease-$nonce.example.com';
    final loginName = 'lease-$nonce';
    final valid = await _seedAccountKeyLeaseState(
      core: core,
      store: store,
      baseUrl: baseUrl,
      loginName: loginName,
    );

    final mismatches = <CloudSyncAccountSession>[
      _accountKeyLeaseSession(baseUrl: baseUrl, loginName: '$loginName-other'),
      _accountKeyLeaseSession(
        baseUrl: 'https://other-$nonce.example.com',
        loginName: loginName,
      ),
      _accountKeyLeaseSession(
        baseUrl: baseUrl,
        loginName: loginName,
        userId: _accountContextId,
      ),
      _accountKeyLeaseSession(
        baseUrl: baseUrl,
        loginName: loginName,
        deviceId: _deviceId2,
      ),
      _accountKeyLeaseSession(
        baseUrl: baseUrl,
        loginName: loginName,
        keyEpoch: valid.keyEpoch + 1,
      ),
      _accountKeyLeaseSession(
        baseUrl: baseUrl,
        loginName: loginName,
        deviceKeyVersion: valid.deviceKeyVersion + 1,
      ),
    ];
    for (final mismatch in mismatches) {
      await expectLater(
        E2eeAccountKeyLease.open(
          session: mismatch,
          deviceStateStore: store,
          secureCore: core,
        ),
        throwsStateError,
      );
    }

    final unboundLoginName = 'unbound-$nonce';
    final unbound = await _seedAccountKeyLeaseState(
      core: core,
      store: store,
      baseUrl: baseUrl,
      loginName: unboundLoginName,
      bound: false,
    );
    await expectLater(
      E2eeAccountKeyLease.open(
        session: unbound,
        deviceStateStore: store,
        secureCore: core,
      ),
      throwsStateError,
    );

    final reopened = await E2eeAccountKeyLease.open(
      session: valid,
      deviceStateStore: store,
      secureCore: core,
    );
    await reopened.close();
  });

  test('账户ARK租约关闭幂等且关闭后保持失败关闭', () async {
    const core = KelivoSecureCore();
    final root = await Directory.current.createTemp('kelivo-key-lease-close-');
    addTearDown(() => root.delete(recursive: true));
    final store = DeviceStateBlobStore(installationRoot: root);
    final nonce = sha256
        .convert(utf8.encode(root.path))
        .toString()
        .substring(0, 16);
    final baseUrl = 'https://lease-$nonce.example.com';
    final loginName = 'lease-$nonce';
    final session = await _seedAccountKeyLeaseState(
      core: core,
      store: store,
      baseUrl: baseUrl,
      loginName: loginName,
    );
    final lease = await E2eeAccountKeyLease.open(
      session: session,
      deviceStateStore: store,
      secureCore: core,
    );

    await lease.close();
    await lease.close();
    expect(lease.takeAccountRootKeyOwnership, throwsStateError);
  });

  test('E2EE 同步 payload 递归排序对象键并保留数组顺序', () {
    const entityKey = SyncEntityKey(
      entityType: E2eeSyncChatRecordTypes.toolEvent,
      entityId: 'message-1',
    );
    final first = <String, Object?>{
      'messageId': 'message-1',
      'events': <Object?>[
        <String, Object?>{
          'z': <Object?>[
            3,
            null,
            true,
            1.5,
            <String, Object?>{'b': '二', 'a': '一'},
          ],
          'a': 'value',
        },
      ],
    };
    final second = <String, Object?>{
      'events': <Object?>[
        <String, Object?>{
          'a': 'value',
          'z': <Object?>[
            3,
            null,
            true,
            1.5,
            <String, Object?>{'a': '一', 'b': '二'},
          ],
        },
      ],
      'messageId': 'message-1',
    };

    final firstBytes = E2eeSyncPayloadCodec.encode(
      entityKey: entityKey,
      payload: first,
    );
    final secondBytes = E2eeSyncPayloadCodec.encode(
      entityKey: entityKey,
      payload: second,
    );

    expect(firstBytes, orderedEquals(secondBytes));
    expect(
      utf8.decode(firstBytes),
      '{"payload":{"events":[{"a":"value","z":[3,null,true,1.5,{"a":"一","b":"二"}]}],"messageId":"message-1"},"recordType":"tool-event","version":2}',
    );
    final decoded = E2eeSyncPayloadCodec.decode(
      entityKey: entityKey,
      bytes: firstBytes,
    );
    expect(decoded, equals(second));
    expect(
      E2eeSyncPayloadCodec.encode(entityKey: entityKey, payload: decoded),
      orderedEquals(firstBytes),
    );
  });

  test('E2EE 同步 payload 解码结果递归不可变且不借用输入', () {
    const entityKey = SyncEntityKey(
      entityType: E2eeSyncChatRecordTypes.toolEvent,
      entityId: 'message-1',
    );
    final bytes = E2eeSyncPayloadCodec.encode(
      entityKey: entityKey,
      payload: _validToolEventPayload(value: <String, Object?>{'nested': 1}),
    );
    final decoded = E2eeSyncPayloadCodec.decode(
      entityKey: entityKey,
      bytes: bytes,
    );
    bytes.fillRange(0, bytes.length, 0);

    final events = decoded['events'] as List<Object?>;
    final event = events.single as Map<String, Object?>;
    final value = event['value'] as Map<String, Object?>;
    expect(value['nested'], 1);
    expect(() => decoded['other'] = 2, throwsUnsupportedError);
    expect(() => events.add(2), throwsUnsupportedError);
    expect(() => value['nested'] = 2, throwsUnsupportedError);
  });

  test('E2EE 同步 payload 严格覆盖六类聊天记录 schema', () {
    final cases = <(SyncEntityKey, Map<String, Object?>)>[
      (
        const SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.conversation,
          entityId: 'conversation-1',
        ),
        _validConversationPayload(),
      ),
      (
        const SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.turn,
          entityId: 'turn-1',
        ),
        _validTurnPayload(),
      ),
      (
        const SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.message,
          entityId: 'message-1',
        ),
        _validMessagePayload(),
      ),
      (
        const SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.messageSelection,
          entityId: 'group-1',
        ),
        _validMessageSelectionPayload(),
      ),
      (
        const SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.toolEvent,
          entityId: 'message-1',
        ),
        _validToolEventPayload(),
      ),
      (
        const SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.thoughtSignature,
          entityId: 'message-1',
        ),
        _validThoughtSignaturePayload(),
      ),
    ];

    for (final (entityKey, payload) in cases) {
      final encoded = E2eeSyncPayloadCodec.encode(
        entityKey: entityKey,
        payload: payload,
      );
      expect(
        E2eeSyncPayloadCodec.decode(entityKey: entityKey, bytes: encoded),
        payload,
      );
    }
  });

  test('E2EE 消息 payload 接受上限内完整附件引用', () {
    const entityKey = SyncEntityKey(
      entityType: E2eeSyncChatRecordTypes.message,
      entityId: 'message-1',
    );
    expect(e2eeSyncMaximumMessageAttachmentCount, 32);
    final attachments = List<Object?>.generate(
      e2eeSyncMaximumMessageAttachmentCount,
      _validMessageAttachment,
      growable: false,
    );
    final payload = <String, Object?>{
      ..._validMessagePayload(),
      'attachments': attachments,
    };

    final encoded = E2eeSyncPayloadCodec.encode(
      entityKey: entityKey,
      payload: payload,
    );
    final decoded = E2eeSyncPayloadCodec.decode(
      entityKey: entityKey,
      bytes: encoded,
    );

    expect(decoded['attachments'], attachments);
  });

  test('E2EE 消息 payload 在递归冻结前拒绝超限附件', () {
    const entityKey = SyncEntityKey(
      entityType: E2eeSyncChatRecordTypes.message,
      entityId: 'message-1',
    );
    final attachmentLimitFailure = isA<FormatException>().having(
      (error) => error.message,
      'message',
      contains('$e2eeSyncMaximumMessageAttachmentCount'),
    );
    final oversizedAttachments = List<Object?>.generate(
      e2eeSyncMaximumMessageAttachmentCount + 1,
      _validMessageAttachment,
      growable: false,
    );

    expect(
      () => E2eeSyncPayloadCodec.encode(
        entityKey: entityKey,
        payload: <String, Object?>{
          ..._validMessagePayload(),
          'attachments': oversizedAttachments,
        },
      ),
      throwsA(attachmentLimitFailure),
    );
    expect(
      () => E2eeSyncPayloadCodec.encode(
        entityKey: entityKey,
        payload: <String, Object?>{
          ..._validMessagePayload(),
          'attachments': _LengthOnlyAttachments(),
        },
      ),
      throwsA(attachmentLimitFailure),
    );

    Object? deeplyNestedValue = true;
    for (var depth = 0; depth < 100; depth++) {
      deeplyNestedValue = <Object?>[deeplyNestedValue];
    }
    oversizedAttachments[0] = <String, Object?>{
      'unexpected': deeplyNestedValue,
    };
    final source = utf8.encode(
      jsonEncode(<String, Object?>{
        'payload': <String, Object?>{
          ..._validMessagePayload(),
          'attachments': oversizedAttachments,
        },
        'recordType': E2eeSyncChatRecordTypes.message,
        'version': e2eeSyncPayloadFormatVersion,
      }),
    );
    expect(
      () => E2eeSyncPayloadCodec.decode(
        entityKey: entityKey,
        bytes: Uint8List.fromList(source),
      ),
      throwsA(attachmentLimitFailure),
    );
  });

  test('E2EE 同步 payload 拒绝非规范编码与非法信封', () {
    const entityKey = SyncEntityKey(
      entityType: E2eeSyncChatRecordTypes.thoughtSignature,
      entityId: 'message-1',
    );
    final invalidSources = <List<int>>[
      <int>[0xc3, 0x28],
      utf8.encode(
        '{"payload":{"messageId":"message-1","signature":"signature"}, "recordType":"thought-signature","version":1}',
      ),
      utf8.encode(
        '{"recordType":"thought-signature","payload":{"messageId":"message-1","signature":"signature"},"version":1}',
      ),
      utf8.encode(
        '{"payload":null,"recordType":"thought-signature","version":1}',
      ),
      utf8.encode(
        '{"extra":null,"payload":{},"recordType":"thought-signature","version":1}',
      ),
      utf8.encode(
        '{"payload":{},"recordType":"thought-signature","version":2}',
      ),
      utf8.encode(
        '{"payload":{},"recordType":"thought-signature","version":1.0}',
      ),
      utf8.encode(
        '{"payload":{"messageId":"message-1","signature":"signature"},"recordType":"tool-event","version":1}',
      ),
      utf8.encode('[]'),
    ];

    for (final source in invalidSources) {
      expect(
        () => E2eeSyncPayloadCodec.decode(
          entityKey: entityKey,
          bytes: Uint8List.fromList(source),
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('E2EE 同步 payload 拒绝非法值类型、键与非有限数值', () {
    const entityKey = SyncEntityKey(
      entityType: E2eeSyncChatRecordTypes.toolEvent,
      entityId: 'message-1',
    );
    Object? deeplyNested = true;
    for (var depth = 0; depth < 100; depth++) {
      deeplyNested = <Object?>[deeplyNested];
    }
    final invalidValues = <Object?>[
      DateTime.utc(2026),
      <Object?, Object?>{1: 'value'},
      double.nan,
      double.infinity,
      double.negativeInfinity,
      String.fromCharCode(0xd800),
      <String, Object?>{String.fromCharCode(0xdc00): true},
      deeplyNested,
    ];

    for (final value in invalidValues) {
      expect(
        () => E2eeSyncPayloadCodec.encode(
          entityKey: entityKey,
          payload: _validToolEventPayload(value: value),
        ),
        throwsA(isA<FormatException>()),
      );
    }

    final nestedPrefix = List<String>.filled(100, '[').join();
    final nestedSuffix = List<String>.filled(100, ']').join();
    expect(
      () => E2eeSyncPayloadCodec.decode(
        entityKey: entityKey,
        bytes: Uint8List.fromList(
          utf8.encode(
            '{"payload":{"events":[{"value":$nestedPrefix'
            'true$nestedSuffix}],"messageId":"message-1"},'
            '"recordType":"tool-event","version":1}',
          ),
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('E2EE 同步 payload 拒绝未知类型、额外字段与身份错配', () {
    expect(
      () => E2eeSyncPayloadCodec.encode(
        entityKey: const SyncEntityKey(
          entityType: 'unknown-record',
          entityId: 'record-1',
        ),
        payload: const <String, Object?>{},
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => E2eeSyncPayloadCodec.encode(
        entityKey: const SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.conversation,
          entityId: 'conversation-1',
        ),
        payload: <String, Object?>{
          ..._validConversationPayload(),
          'extra': true,
        },
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => E2eeSyncPayloadCodec.encode(
        entityKey: const SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.messageSelection,
          entityId: 'other-group',
        ),
        payload: _validMessageSelectionPayload(),
      ),
      throwsA(isA<FormatException>()),
    );
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
    final validEpochs = <int>[1, 0xffffffff];
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
      (
        version: 1,
        epoch: 0x100000000,
        ciphertext: Uint8List.fromList(<int>[1]),
      ),
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

  test('v3 推送接受完整 uint32 keyEpoch 并解析三类结果', () async {
    const core = KelivoSecureCore();
    final ark = await core.generateAccountRootKey();
    final cipher = E2eeAccountRecordCipher.takeOwnership(
      secureCore: core,
      accountRootKey: ark,
      userId: _userId,
      currentKeyEpoch: 0xffffffff,
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
            'keyEpoch': 0xffffffff,
            'ciphertext': _encodedRecordCiphertext(firstState.record),
          },
          <String, Object?>{
            'mutationId': _mutationId2,
            'recordId': secondState.record.recordId.wireValue,
            'expectedRevision': 3,
            'operation': 'put',
            'envelopeVersion': 1,
            'keyEpoch': 0xffffffff,
            'ciphertext': _encodedRecordCiphertext(secondState.record),
          },
          <String, Object?>{
            'mutationId': _mutationId3,
            'recordId': thirdState.record.recordId.wireValue,
            'expectedRevision': 2,
            'operation': 'put',
            'envelopeVersion': 1,
            'keyEpoch': 0xffffffff,
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

  test('v3 增量拉取接受完整 uint32 keyEpoch 并保持 put 密文不透明', () async {
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

    final pullFuture = client.pullChangesWithToken(
      token: _fullToken,
      cursor: 'cursor-1',
      limit: 1,
    );
    client.setToken(_otherFullToken);

    final request = await requestFuture;
    expect(request.uri.path, '/api/sync/change/pull');
    expect(
      request.headers.value(HttpHeaders.authorizationHeader),
      'Bearer $_fullTokenValue',
    );
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
              'keyEpoch': 0xffffffff,
              'ciphertext': 'AQID',
              'ciphertextBytes': 3,
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

    final result = await pullFuture;
    expect(result, isA<CloudSyncChangePage>());
    final page = result as CloudSyncChangePage;
    expect(page.nextCursor, 'cursor-2');
    expect(page.hasMore, isTrue);
    expect(
      page.changes[0],
      isA<CloudSyncPutRecordChange>()
          .having((change) => change.changeSeq, 'changeSeq', 12)
          .having((change) => change.recordId.wireValue, 'recordId', _recordId1)
          .having((change) => change.revision, 'revision', 2)
          .having((change) => change.record.keyEpoch, 'keyEpoch', 0xffffffff)
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
          'nextCursor': null,
          'hasMore': false,
          'resetRequired': true,
        },
      }),
    );
    await request.response.close();

    expect(await pullFuture, isA<CloudSyncResetRequired>());
  });

  test('v3 增量拉取拒绝携带伪游标的 reset 响应', () async {
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
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'changes': <Object?>[],
          'nextCursor': 'forged-reset-cursor',
          'hasMore': false,
          'resetRequired': true,
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

  test('v3 快照首次拉取允许同一记录的非空完整有序历史', () async {
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

    final pullFuture = client.pullSnapshotWithToken(
      token: _fullToken,
      limit: 2,
    );
    client.setToken(_otherFullToken);

    final request = await requestFuture;
    expect(request.uri.path, '/api/sync/snapshot/pull');
    expect(
      request.headers.value(HttpHeaders.authorizationHeader),
      'Bearer $_fullTokenValue',
    );
    expect(request.headers.value('x-kelivo-sync-protocol-version'), '3');
    expect(
      jsonDecode(await utf8.decoder.bind(request).join()),
      <String, Object?>{'limit': 2},
    );
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'records': <Object?>[
            <String, Object?>{
              'recordId': _recordId1,
              'revision': 1,
              'envelopeVersion': 1,
              'keyEpoch': 7,
              'ciphertext': 'AQID',
              'ciphertextBytes': 3,
              'updatedAt': '2026-07-19T04:59:00.000Z',
              'updatedByDeviceId': _deviceId1,
              'lastChangeSeq': 11,
            },
            <String, Object?>{
              'recordId': _recordId1,
              'revision': 2,
              'envelopeVersion': 1,
              'keyEpoch': 7,
              'ciphertext': 'BAUG',
              'ciphertextBytes': 3,
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
      page.records[1],
      isA<CloudSyncEncryptedRecord>()
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

  test('v3 快照拉取拒绝乱序历史', () async {
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

    final pullFuture = client.pullSnapshot(limit: 2);
    final request = await requestFuture;
    await utf8.decoder.bind(request).join();
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'records': <Object?>[
            for (final sequence in <int>[12, 11])
              <String, Object?>{
                'recordId': _recordId1,
                'revision': sequence - 10,
                'envelopeVersion': 1,
                'keyEpoch': 7,
                'ciphertext': 'AQID',
                'ciphertextBytes': 3,
                'updatedAt': '2026-07-19T05:00:00.000Z',
                'updatedByDeviceId': _deviceId1,
                'lastChangeSeq': sequence,
              },
          ],
          'nextSnapshotCursor': null,
          'syncCursor': 'sync-12',
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

  test('v3 HTTP 边界拒绝非空增量页与快照页原地游标', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/api/sync/change/pull') {
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
                  'updatedAt': '2026-07-19T05:00:00.000Z',
                  'updatedByDeviceId': _deviceId1,
                },
              ],
              'nextCursor': 'cursor-stuck',
              'hasMore': true,
              'resetRequired': false,
            },
          }),
        );
      } else {
        request.response.write(
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{
              'records': <Object?>[
                <String, Object?>{
                  'recordId': _recordId1,
                  'revision': 2,
                  'envelopeVersion': 1,
                  'keyEpoch': 7,
                  'ciphertext': 'AQID',
                  'ciphertextBytes': 3,
                  'updatedAt': '2026-07-19T05:00:00.000Z',
                  'updatedByDeviceId': _deviceId1,
                  'lastChangeSeq': 12,
                },
              ],
              'nextSnapshotCursor': 'snapshot-stuck',
              'syncCursor': null,
              'hasMore': true,
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

    await expectLater(
      client.pullChanges(cursor: 'cursor-stuck', limit: 1),
      invalidResponse,
    );
    await expectLater(
      client.pullSnapshot(snapshotCursor: 'snapshot-stuck', limit: 1),
      invalidResponse,
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

  test('v3 附件创建显式冻结完整会话令牌且只发送密文元数据', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: _otherFullToken,
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    final createFuture = client.createAttachmentUpload(
      token: _fullToken,
      request: CloudSyncAttachmentCreateUploadRequest(
        mutationId: _mutationId1,
        attachmentId: _attachmentId,
        keyEpoch: 0xffffffff,
        chunkCount: 2,
        totalCiphertextBytes: 5,
      ),
    );
    client.setToken(_otherFullToken);

    final request = await requestFuture;
    expect(request.uri.path, '/api/sync/attachment/upload/create');
    expect(
      request.headers.value(HttpHeaders.authorizationHeader),
      'Bearer $_fullTokenValue',
    );
    expect(request.headers.value('x-kelivo-sync-protocol-version'), '3');
    expect(
      jsonDecode(await utf8.decoder.bind(request).join()),
      <String, Object?>{
        'mutationId': _mutationId1,
        'attachmentId': _attachmentId,
        'keyEpoch': 0xffffffff,
        'chunkCount': 2,
        'totalCiphertextBytes': 5,
      },
    );
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object?>{
        'data': <String, Object?>{
          'attachmentId': _attachmentId,
          'uploadId': _uploadId,
          'keyEpoch': 0xffffffff,
          'chunkCount': 2,
          'totalCiphertextBytes': 5,
          'status': 'open',
          'createdAt': '2026-07-29T00:00:00.000Z',
        },
      }),
    );
    await request.response.close();

    final upload = await createFuture;
    expect(upload.identity.attachmentId, _attachmentId);
    expect(upload.identity.uploadId, _uploadId);
    expect(upload.identity.keyEpoch, 0xffffffff);
    expect(upload.chunkCount, 2);
    expect(upload.totalCiphertextBytes, 5);
    expect(upload.createdAt, DateTime.utc(2026, 7, 29));
  });

  test('v3 附件分块、提交、清单、下载和删除保持不透明密文合同', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = StreamIterator<HttpRequest>(server);
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await requests.cancel();
      await server.close(force: true);
    });
    final identity = CloudSyncAttachmentIdentity(
      attachmentId: _attachmentId,
      uploadId: _uploadId,
      keyEpoch: 7,
    );
    final chunk = CloudSyncAttachmentChunkIdentity(
      identity: identity,
      chunkIndex: 0,
    );

    final putFuture = client.putAttachmentChunk(
      token: _fullToken,
      request: CloudSyncAttachmentPutChunkRequest(
        mutationId: _mutationId1,
        chunk: chunk,
        ciphertext: Uint8List.fromList(<int>[1, 2, 3]),
      ),
    );
    final putRequest = await _nextAttachmentRequest(requests);
    await _expectAttachmentRequest(
      putRequest,
      path: '/api/sync/attachment/chunk/put',
      body: <String, Object?>{
        'mutationId': _mutationId1,
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'keyEpoch': 7,
        'chunkIndex': 0,
        'ciphertext': 'AQID',
      },
    );
    await _writeJsonResponse(putRequest, <String, Object?>{
      'data': <String, Object?>{
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'chunkIndex': 0,
        'ciphertextBytes': 3,
        'status': 'stored',
      },
    });
    final stored = await putFuture;
    expect(stored.chunk, same(chunk));
    expect(stored.ciphertextBytes, 3);

    final commitFuture = client.commitAttachmentUpload(
      token: _fullToken,
      request: CloudSyncAttachmentCommitUploadRequest(
        mutationId: _mutationId2,
        identity: identity,
        manifestCiphertext: Uint8List.fromList(<int>[4, 5]),
        chunks: <CloudSyncAttachmentManifestChunk>[
          CloudSyncAttachmentManifestChunk(chunkIndex: 0, ciphertextBytes: 3),
        ],
      ),
    );
    final commitRequest = await _nextAttachmentRequest(requests);
    await _expectAttachmentRequest(
      commitRequest,
      path: '/api/sync/attachment/upload/commit',
      body: <String, Object?>{
        'mutationId': _mutationId2,
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'keyEpoch': 7,
        'manifestCiphertext': 'BAU',
        'chunks': <Object?>[
          <String, Object?>{'chunkIndex': 0, 'ciphertextBytes': 3},
        ],
      },
    );
    await _writeJsonResponse(commitRequest, <String, Object?>{
      'data': <String, Object?>{
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'keyEpoch': 7,
        'status': 'committed',
        'committedAt': '2026-07-29T00:01:00.000Z',
      },
    });
    final committed = await commitFuture;
    expect(committed.identity.attachmentId, _attachmentId);
    expect(committed.committedAt, DateTime.utc(2026, 7, 29, 0, 1));

    final manifestFuture = client.getAttachmentManifest(
      token: _fullToken,
      identity: identity,
    );
    final manifestRequest = await _nextAttachmentRequest(requests);
    await _expectAttachmentRequest(
      manifestRequest,
      path: '/api/sync/attachment/manifest/get',
      body: <String, Object?>{
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'keyEpoch': 7,
      },
    );
    await _writeJsonResponse(manifestRequest, <String, Object?>{
      'data': <String, Object?>{
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'keyEpoch': 7,
        'chunkCount': 1,
        'totalCiphertextBytes': 3,
        'manifestCiphertext': 'BAU',
        'manifestCiphertextBytes': 2,
        'chunks': <Object?>[
          <String, Object?>{'chunkIndex': 0, 'ciphertextBytes': 3},
        ],
        'committedAt': '2026-07-29T00:01:00.000Z',
      },
    });
    final manifest = await manifestFuture;
    expect(manifest.identity.uploadId, _uploadId);
    expect(manifest.manifestCiphertext, orderedEquals(<int>[4, 5]));
    expect(manifest.chunks.single.ciphertextBytes, 3);

    final getChunkFuture = client.getAttachmentChunk(
      token: _fullToken,
      chunk: chunk,
    );
    final getChunkRequest = await _nextAttachmentRequest(requests);
    await _expectAttachmentRequest(
      getChunkRequest,
      path: '/api/sync/attachment/chunk/get',
      body: <String, Object?>{
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'keyEpoch': 7,
        'chunkIndex': 0,
      },
    );
    await _writeJsonResponse(getChunkRequest, <String, Object?>{
      'data': <String, Object?>{
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'keyEpoch': 7,
        'chunkIndex': 0,
        'ciphertext': 'AQID',
        'ciphertextBytes': 3,
      },
    });
    final downloaded = await getChunkFuture;
    expect(downloaded.chunk, same(chunk));
    expect(downloaded.ciphertext, orderedEquals(<int>[1, 2, 3]));

    final deleteFuture = client.deleteAttachment(
      token: _fullToken,
      request: CloudSyncAttachmentDeleteRequest(
        mutationId: _mutationId3,
        identity: identity,
      ),
    );
    final deleteRequest = await _nextAttachmentRequest(requests);
    await _expectAttachmentRequest(
      deleteRequest,
      path: '/api/sync/attachment/record/delete',
      body: <String, Object?>{
        'mutationId': _mutationId3,
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'keyEpoch': 7,
      },
    );
    await _writeJsonResponse(deleteRequest, <String, Object?>{
      'data': <String, Object?>{
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'keyEpoch': 7,
        'status': 'deleted',
        'deletedAt': '2026-07-29T00:02:00.000Z',
      },
    });
    final deleted = await deleteFuture;
    expect(deleted.identity.keyEpoch, 7);
    expect(deleted.deletedAt, DateTime.utc(2026, 7, 29, 0, 2));
  });

  test('v3 附件强类型精确执行服务端大小与 uint32 边界', () {
    final identity = CloudSyncAttachmentIdentity(
      attachmentId: _attachmentId,
      uploadId: _uploadId,
      keyEpoch: 0xffffffff,
    );
    final maximumCreate = CloudSyncAttachmentCreateUploadRequest(
      mutationId: _mutationId1,
      attachmentId: _attachmentId,
      keyEpoch: 0xffffffff,
      chunkCount: cloudSyncMaximumAttachmentChunkCount,
      totalCiphertextBytes: cloudSyncMaximumAttachmentTotalCiphertextBytes,
    );
    expect(maximumCreate.keyEpoch, 0xffffffff);
    expect(maximumCreate.totalCiphertextBytes, 1000 * 4 * 1024 * 1024);

    final chunkSource = Uint8List(
      cloudSyncMaximumAttachmentChunkCiphertextBytes,
    )..first = 1;
    final maximumChunk = CloudSyncAttachmentPutChunkRequest(
      mutationId: _mutationId2,
      chunk: CloudSyncAttachmentChunkIdentity(
        identity: identity,
        chunkIndex: cloudSyncMaximumAttachmentChunkCount - 1,
      ),
      ciphertext: chunkSource,
    );
    chunkSource.first = 9;
    expect(maximumChunk.ciphertext.first, 1);
    expect(() => maximumChunk.ciphertext.first = 2, throwsUnsupportedError);

    final manifestSource = Uint8List(
      cloudSyncMaximumAttachmentManifestCiphertextBytes,
    )..first = 3;
    final chunkDescriptors = List<CloudSyncAttachmentManifestChunk>.generate(
      cloudSyncMaximumAttachmentChunkCount,
      (index) => CloudSyncAttachmentManifestChunk(
        chunkIndex: index,
        ciphertextBytes: cloudSyncMaximumAttachmentChunkCiphertextBytes,
      ),
    );
    final maximumCommit = CloudSyncAttachmentCommitUploadRequest(
      mutationId: _mutationId3,
      identity: identity,
      manifestCiphertext: manifestSource,
      chunks: chunkDescriptors,
    );
    manifestSource.first = 8;
    chunkDescriptors.clear();
    expect(maximumCommit.manifestCiphertext.first, 3);
    expect(
      maximumCommit.chunks,
      hasLength(cloudSyncMaximumAttachmentChunkCount),
    );

    final invalidValues = <Object? Function()>[
      () => CloudSyncAttachmentIdentity(
        attachmentId: _attachmentId,
        uploadId: _uploadId,
        keyEpoch: 0,
      ),
      () => CloudSyncAttachmentIdentity(
        attachmentId: _attachmentId,
        uploadId: _uploadId,
        keyEpoch: 0x100000000,
      ),
      () => CloudSyncAttachmentCreateUploadRequest(
        mutationId: _mutationId1,
        attachmentId: _attachmentId,
        keyEpoch: 1,
        chunkCount: 0,
        totalCiphertextBytes: 1,
      ),
      () => CloudSyncAttachmentCreateUploadRequest(
        mutationId: _mutationId1,
        attachmentId: _attachmentId,
        keyEpoch: 1,
        chunkCount: cloudSyncMaximumAttachmentChunkCount + 1,
        totalCiphertextBytes: cloudSyncMaximumAttachmentChunkCount + 1,
      ),
      () => CloudSyncAttachmentCreateUploadRequest(
        mutationId: _mutationId1,
        attachmentId: _attachmentId,
        keyEpoch: 1,
        chunkCount: 2,
        totalCiphertextBytes: 1,
      ),
      () => CloudSyncAttachmentCreateUploadRequest(
        mutationId: _mutationId1,
        attachmentId: _attachmentId,
        keyEpoch: 1,
        chunkCount: 1,
        totalCiphertextBytes:
            cloudSyncMaximumAttachmentChunkCiphertextBytes + 1,
      ),
      () =>
          CloudSyncAttachmentChunkIdentity(identity: identity, chunkIndex: -1),
      () => CloudSyncAttachmentChunkIdentity(
        identity: identity,
        chunkIndex: cloudSyncMaximumAttachmentChunkCount,
      ),
      () => CloudSyncAttachmentPutChunkRequest(
        mutationId: _mutationId1,
        chunk: CloudSyncAttachmentChunkIdentity(
          identity: identity,
          chunkIndex: 0,
        ),
        ciphertext: Uint8List(0),
      ),
      () => CloudSyncAttachmentPutChunkRequest(
        mutationId: _mutationId1,
        chunk: CloudSyncAttachmentChunkIdentity(
          identity: identity,
          chunkIndex: 0,
        ),
        ciphertext: Uint8List(
          cloudSyncMaximumAttachmentChunkCiphertextBytes + 1,
        ),
      ),
      () => CloudSyncAttachmentCommitUploadRequest(
        mutationId: _mutationId1,
        identity: identity,
        manifestCiphertext: Uint8List(0),
        chunks: <CloudSyncAttachmentManifestChunk>[
          CloudSyncAttachmentManifestChunk(chunkIndex: 0, ciphertextBytes: 1),
        ],
      ),
      () => CloudSyncAttachmentCommitUploadRequest(
        mutationId: _mutationId1,
        identity: identity,
        manifestCiphertext: Uint8List(
          cloudSyncMaximumAttachmentManifestCiphertextBytes + 1,
        ),
        chunks: <CloudSyncAttachmentManifestChunk>[
          CloudSyncAttachmentManifestChunk(chunkIndex: 0, ciphertextBytes: 1),
        ],
      ),
      () => CloudSyncAttachmentCommitUploadRequest(
        mutationId: _mutationId1,
        identity: identity,
        manifestCiphertext: Uint8List.fromList(<int>[1]),
        chunks: const <CloudSyncAttachmentManifestChunk>[],
      ),
      () => CloudSyncAttachmentCommitUploadRequest(
        mutationId: _mutationId1,
        identity: identity,
        manifestCiphertext: Uint8List.fromList(<int>[1]),
        chunks: <CloudSyncAttachmentManifestChunk>[
          CloudSyncAttachmentManifestChunk(chunkIndex: 1, ciphertextBytes: 1),
        ],
      ),
    ];
    for (final invalidValue in invalidValues) {
      expect(invalidValue, throwsFormatException);
    }
  });

  test('v3 附件响应拒绝未知字段、身份串线和非规范 Base64URL', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = StreamIterator<HttpRequest>(server);
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await requests.cancel();
      await server.close(force: true);
    });
    final createRequest = CloudSyncAttachmentCreateUploadRequest(
      mutationId: _mutationId1,
      attachmentId: _attachmentId,
      keyEpoch: 7,
      chunkCount: 1,
      totalCiphertextBytes: 3,
    );
    final identity = CloudSyncAttachmentIdentity(
      attachmentId: _attachmentId,
      uploadId: _uploadId,
      keyEpoch: 7,
    );
    final invalidResponse = throwsA(
      isA<CloudSyncException>()
          .having(
            (error) => error.kind,
            'kind',
            CloudSyncFailureKind.invalidResponse,
          )
          .having((error) => error.retryable, 'retryable', isFalse),
    );
    Map<String, Object?> validUploadData() => <String, Object?>{
      'attachmentId': _attachmentId,
      'uploadId': _uploadId,
      'keyEpoch': 7,
      'chunkCount': 1,
      'totalCiphertextBytes': 3,
      'status': 'open',
      'createdAt': '2026-07-29T00:00:00.000Z',
    };
    Future<void> expectInvalidCreate(Map<String, Object?> response) async {
      final future = client.createAttachmentUpload(
        token: _fullToken,
        request: createRequest,
      );
      final request = await _nextAttachmentRequest(requests);
      await utf8.decoder.bind(request).join();
      await _writeJsonResponse(request, response);
      await expectLater(future, invalidResponse);
    }

    await expectInvalidCreate(<String, Object?>{
      'data': validUploadData(),
      'trace': 'unknown',
    });
    await expectInvalidCreate(<String, Object?>{
      'data': <String, Object?>{...validUploadData(), 'filename': '不得进入服务端'},
    });
    await expectInvalidCreate(<String, Object?>{
      'data': <String, Object?>{
        ...validUploadData(),
        'attachmentId': _recordId1,
      },
    });

    final manifestFuture = client.getAttachmentManifest(
      token: _fullToken,
      identity: identity,
    );
    final manifestRequest = await _nextAttachmentRequest(requests);
    await utf8.decoder.bind(manifestRequest).join();
    await _writeJsonResponse(manifestRequest, <String, Object?>{
      'data': <String, Object?>{
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'keyEpoch': 7,
        'chunkCount': 1,
        'totalCiphertextBytes': 3,
        'manifestCiphertext': 'AQ',
        'manifestCiphertextBytes': 1,
        'chunks': <Object?>[
          <String, Object?>{
            'chunkIndex': 0,
            'ciphertextBytes': 3,
            'hash': '不得进入服务端',
          },
        ],
        'committedAt': '2026-07-29T00:01:00.000Z',
      },
    });
    await expectLater(manifestFuture, invalidResponse);

    final chunkFuture = client.getAttachmentChunk(
      token: _fullToken,
      chunk: CloudSyncAttachmentChunkIdentity(
        identity: identity,
        chunkIndex: 0,
      ),
    );
    final chunkRequest = await _nextAttachmentRequest(requests);
    await utf8.decoder.bind(chunkRequest).join();
    await _writeJsonResponse(chunkRequest, <String, Object?>{
      'data': <String, Object?>{
        'attachmentId': _attachmentId,
        'uploadId': _uploadId,
        'keyEpoch': 7,
        'chunkIndex': 0,
        'ciphertext': 'AQI=',
        'ciphertextBytes': 2,
      },
    });
    await expectLater(chunkFuture, invalidResponse);
  });

  test('v3 附件错误响应保留冲突代码与请求标识', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final client = CloudSyncClient.forTesting(
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });
    final deleteFuture = client.deleteAttachment(
      token: _fullToken,
      request: CloudSyncAttachmentDeleteRequest(
        mutationId: _mutationId1,
        identity: CloudSyncAttachmentIdentity(
          attachmentId: _attachmentId,
          uploadId: _uploadId,
          keyEpoch: 7,
        ),
      ),
    );
    final request = await requestFuture;
    await utf8.decoder.bind(request).join();
    await _writeJsonResponse(request, <String, Object?>{
      'error': <String, Object?>{
        'code': 'ATTACHMENT_MUTATION_CONFLICT',
        'message': 'conflict',
        'retryable': false,
      },
      'requestId': 'attachment-request-1',
    }, statusCode: HttpStatus.conflict);

    await expectLater(
      deleteFuture,
      throwsA(
        isA<CloudSyncException>()
            .having(
              (error) => error.kind,
              'kind',
              CloudSyncFailureKind.conflict,
            )
            .having((error) => error.statusCode, 'statusCode', 409)
            .having(
              (error) => error.serverCode,
              'serverCode',
              'ATTACHMENT_MUTATION_CONFLICT',
            )
            .having(
              (error) => error.requestId,
              'requestId',
              'attachment-request-1',
            )
            .having((error) => error.retryable, 'retryable', isFalse),
      ),
    );
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

  test('E2EE 附件密码会话隔离清单与分块密钥并在关闭后失败关闭', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[1, 2, 3]),
      openCoordinator: false,
    );
    addTearDown(fixture.close);
    final session = await fixture.openCryptoSession();
    final sealedManifest = await session.sealManifest(
      descriptor: fixture.descriptor,
      uploadId: _uploadId,
    );
    final openedManifest = await session.openManifest(
      attachmentId: fixture.descriptor.attachmentId,
      uploadId: _uploadId,
      keyEpoch: fixture.descriptor.keyEpoch,
      ciphertext: sealedManifest.ciphertext,
    );
    final ciphertext = await session.sealChunk(
      descriptor: fixture.descriptor,
      uploadId: _uploadId,
      chunkIndex: 0,
      plaintext: fixture.plaintext,
    );
    final opened = await session.openChunk(
      descriptor: fixture.descriptor,
      uploadId: _uploadId,
      chunkIndex: 0,
      ciphertext: ciphertext,
    );

    expect(openedManifest.attachmentId, fixture.descriptor.attachmentId);
    expect(openedManifest.contentSha256, fixture.descriptor.contentSha256);
    expect(opened, fixture.plaintext);
    await expectLater(
      session.openManifest(
        attachmentId: fixture.descriptor.attachmentId,
        uploadId: _uploadId,
        keyEpoch: fixture.descriptor.keyEpoch + 1,
        ciphertext: sealedManifest.ciphertext,
      ),
      throwsFormatException,
    );
    final inFlight = session.sealChunk(
      descriptor: fixture.descriptor,
      uploadId: _uploadId,
      chunkIndex: 0,
      plaintext: fixture.plaintext,
    );
    final closing = session.close();
    expect(await inFlight, isNotEmpty);
    await closing;
    await session.close();
    await expectLater(
      session.sealManifest(descriptor: fixture.descriptor, uploadId: _uploadId),
      throwsStateError,
    );
  });

  test('E2EE 附件上传协调器完成单块并提交认证清单', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[5, 6, 7]),
    );
    addTearDown(fixture.close);

    expect(await fixture.coordinator.advance(10), 3);
    final state = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(state!.phase, E2eeAttachmentUploadPhase.committed);
    expect(fixture.transport.createRequests, hasLength(1));
    expect(fixture.transport.putAttempts, hasLength(1));
    expect(fixture.transport.commitRequests, hasLength(1));
    expect(fixture.transport.createRequests.single.mutationId, _mutationId1);
    expect(fixture.transport.commitRequests.single.mutationId, _mutationId2);

    final verifier = await fixture.openCryptoSession();
    addTearDown(verifier.close);
    final commit = fixture.transport.commitRequests.single;
    final manifest = await verifier.openManifest(
      attachmentId: fixture.descriptor.attachmentId,
      uploadId: _uploadId,
      keyEpoch: fixture.descriptor.keyEpoch,
      ciphertext: commit.manifestCiphertext,
    );
    final plaintext = await verifier.openChunk(
      descriptor: fixture.descriptor,
      uploadId: _uploadId,
      chunkIndex: 0,
      ciphertext: fixture.transport.putAttempts.single.ciphertext,
    );
    expect(manifest.contentSha256, fixture.descriptor.contentSha256);
    expect(plaintext, fixture.plaintext);
  });

  test('E2EE 附件上传协调器按布局完成多块且不拼接明文缓冲', () async {
    final plaintext = Uint8List.fromList(<int>[
      ...List<int>.filled(KelivoAttachmentLimits.chunkPlaintextBytes, 0x31),
      0x32,
      0x33,
      0x34,
    ]);
    final fixture = await _AttachmentUploadFixture.create(plaintext: plaintext);
    addTearDown(fixture.close);

    expect(await fixture.coordinator.advance(10), 4);
    expect(fixture.transport.putAttempts, hasLength(2));
    expect(fixture.fileStore.verifiedContentOpens, 1);
    expect(fixture.fileStore.verifiedChunkReads, 2);
    expect(fixture.fileStore.unverifiedRangeReads, 0);
    final verifier = await fixture.openCryptoSession();
    addTearDown(verifier.close);
    final rebuilt = BytesBuilder(copy: true);
    for (final attempt in fixture.transport.putAttempts) {
      rebuilt.add(
        await verifier.openChunk(
          descriptor: fixture.descriptor,
          uploadId: _uploadId,
          chunkIndex: attempt.chunkIndex,
          ciphertext: attempt.ciphertext,
        ),
      );
    }
    expect(rebuilt.takeBytes(), plaintext);
  });

  test('E2EE 附件上传协调器将零字节内容编码为一个认证空块', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List(0),
    );
    addTearDown(fixture.close);

    expect(await fixture.coordinator.advance(10), 3);
    expect(fixture.transport.putAttempts, hasLength(1));
    expect(
      fixture.transport.putAttempts.single.ciphertext,
      hasLength(KelivoAttachmentLimits.chunkEnvelopeOverheadBytes),
    );
    final verifier = await fixture.openCryptoSession();
    addTearDown(verifier.close);
    expect(
      await verifier.openChunk(
        descriptor: fixture.descriptor,
        uploadId: _uploadId,
        chunkIndex: 0,
        ciphertext: fixture.transport.putAttempts.single.ciphertext,
      ),
      isEmpty,
    );
  });

  test('E2EE 附件上传协调器严格服从远端步数预算', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[
        ...List<int>.filled(KelivoAttachmentLimits.chunkPlaintextBytes, 0x41),
        0x42,
      ]),
    );
    addTearDown(fixture.close);

    expect(await fixture.coordinator.advance(0), 0);
    expect(fixture.transport.remoteCalls, 0);
    await expectLater(fixture.coordinator.advance(-1), throwsFormatException);
    for (var expectedCalls = 1; expectedCalls <= 4; expectedCalls++) {
      expect(await fixture.coordinator.advance(1), 1);
      expect(fixture.transport.remoteCalls, expectedCalls);
    }
    expect(
      (await fixture.commands.readByAttachmentId(
        fixture.descriptor.attachmentId,
      ))!.phase,
      E2eeAttachmentUploadPhase.committed,
    );
    expect(await fixture.coordinator.advance(1), 0);
  });

  test('E2EE 附件上传协调器在源认证耗尽租约后重新 claim 才发起远端请求', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[5, 6]),
    );
    addTearDown(fixture.close);

    fixture.fileStore.beforeOpenVerifiedContent = () {
      fixture.clock.value = fixture.clock.value.add(const Duration(minutes: 6));
    };
    expect(await fixture.coordinator.advance(1), 1);
    final released = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(released!.attemptCount, 2);
    expect(fixture.transport.createRequests, hasLength(1));
  });

  test('E2EE 附件上传协调器清理租约过期前未被数据库接管的 staging', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[6, 7]),
    );
    addTearDown(fixture.close);

    expect(await fixture.coordinator.advance(1), 1);
    E2eeAttachmentStoredFile? abandoned;
    fixture.fileStore.afterPublish = (stored) {
      if (abandoned != null) return;
      abandoned = stored;
      fixture.clock.value = fixture.clock.value.add(const Duration(minutes: 6));
    };
    expect(await fixture.coordinator.advance(1), 1);
    expect(abandoned, isNotNull);
    await expectLater(
      fixture.fileStore.readVerified(abandoned!),
      throwsA(isA<FileSystemException>()),
    );
    expect(fixture.transport.putAttempts, hasLength(1));
  });

  test('E2EE 附件上传协调器网络重试跨重启逐字节重放 pending 密文', () async {
    final transport = _AttachmentUploadTransport(
      retryablePutFailuresRemaining: 1,
    );
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[7, 8, 9]),
      transport: transport,
    );
    addTearDown(fixture.close);

    expect(await fixture.coordinator.advance(2), 2);
    final deferred = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(deferred!.phase, E2eeAttachmentUploadPhase.uploading);
    expect(deferred.pendingChunk, isNotNull);
    expect(deferred.consecutiveFailureCount, 1);
    expect(
      deferred.nextAttemptAt,
      fixture.clock.value.add(const Duration(seconds: 1)),
    );
    final first = transport.putAttempts.single;

    await fixture.restartCoordinator();
    fixture.clock.value = deferred.nextAttemptAt.subtract(
      const Duration(microseconds: 1),
    );
    expect(await fixture.coordinator.advance(2), 0);
    expect(transport.putAttempts, hasLength(1));
    fixture.clock.value = deferred.nextAttemptAt;
    expect(await fixture.coordinator.advance(2), 2);
    expect(transport.putAttempts, hasLength(2));
    final replay = transport.putAttempts.last;
    expect(replay.mutationId, first.mutationId);
    expect(replay.ciphertext, first.ciphertext);
    expect(
      (await fixture.commands.readByAttachmentId(
        fixture.descriptor.attachmentId,
      ))!.phase,
      E2eeAttachmentUploadPhase.committed,
    );
  });

  test('E2EE 附件上传协调器将不可重试响应固化为终止状态', () async {
    final transport = _AttachmentUploadTransport(
      permanentPutFailure: const CloudSyncException(
        kind: CloudSyncFailureKind.validation,
        retryable: false,
      ),
    );
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[10, 11]),
      transport: transport,
    );
    addTearDown(fixture.close);

    expect(await fixture.coordinator.advance(10), 2);
    final terminal = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(terminal!.terminalFailureKind, 'remote-validation');
    expect(terminal.pendingChunk, isNotNull);
    fixture.clock.value = fixture.clock.value.add(const Duration(days: 1));
    expect(await fixture.coordinator.advance(10), 0);
    expect(transport.putAttempts, hasLength(1));
  });

  test('E2EE 附件上传协调器在任何远端写入前终止源摘要错配', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[12, 13]),
      descriptorContentSha256: _filledBytes(32, 0xee),
    );
    addTearDown(fixture.close);

    expect(await fixture.coordinator.advance(10), 0);
    final terminal = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(terminal!.terminalFailureKind, 'source-integrity-failed');
    expect(fixture.transport.remoteCalls, 0);
  });

  test('E2EE 附件上传协调器对瞬时本地 IO 退避后继续', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[14, 15]),
      transientVerifyFailures: 1,
    );
    addTearDown(fixture.close);

    final firstAttemptAt = fixture.clock.value;
    expect(await fixture.coordinator.advance(10), 0);
    final deferred = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(deferred!.terminalFailureKind, isNull);
    expect(deferred.lastFailureKind, 'local-io');
    expect(deferred.consecutiveFailureCount, 1);
    expect(
      deferred.nextAttemptAt,
      firstAttemptAt.add(const Duration(seconds: 1)),
    );
    fixture.clock.value = deferred.nextAttemptAt;
    expect(await fixture.coordinator.advance(10), 3);
    expect(
      (await fixture.commands.readByAttachmentId(
        fixture.descriptor.attachmentId,
      ))!.phase,
      E2eeAttachmentUploadPhase.committed,
    );
  });

  test('E2EE 附件上传协调器不会因租约同时过期而吞掉未知本地错误', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[15, 16]),
    );
    addTearDown(fixture.close);

    fixture.fileStore.beforeOpenVerifiedContent = () {
      fixture.clock.value = fixture.clock.value.add(const Duration(minutes: 6));
      throw StateError('unexpected-local-failure');
    };

    await expectLater(
      fixture.coordinator.advance(1),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'unexpected-local-failure',
        ),
      ),
    );
    expect(fixture.transport.remoteCalls, 0);
  });

  test('E2EE 附件上传协调器在远端成功但租约过期后原样重放 mutation', () async {
    final transport = _AttachmentUploadTransport();
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[16, 17]),
      transport: transport,
    );
    addTearDown(fixture.close);

    var expireCreate = true;
    transport.afterCreate = () {
      if (!expireCreate) return;
      expireCreate = false;
      fixture.clock.value = fixture.clock.value.add(const Duration(minutes: 6));
    };
    expect(await fixture.coordinator.advance(1), 1);
    expect(
      (await fixture.commands.readByAttachmentId(
        fixture.descriptor.attachmentId,
      ))!.phase,
      E2eeAttachmentUploadPhase.createPending,
    );
    expect(await fixture.coordinator.advance(1), 1);
    expect(transport.createRequests, hasLength(2));
    expect(
      transport.createRequests.last.mutationId,
      transport.createRequests.first.mutationId,
    );

    var expirePut = true;
    transport.afterPut = () {
      if (!expirePut) return;
      expirePut = false;
      fixture.clock.value = fixture.clock.value.add(const Duration(minutes: 6));
    };
    expect(await fixture.coordinator.advance(1), 1);
    final chunkPending = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(chunkPending!.phase, E2eeAttachmentUploadPhase.uploading);
    expect(chunkPending.pendingChunk, isNotNull);
    expect(await fixture.coordinator.advance(1), 1);
    expect(transport.putAttempts, hasLength(2));
    expect(
      transport.putAttempts.last.mutationId,
      transport.putAttempts.first.mutationId,
    );
    expect(
      transport.putAttempts.last.ciphertext,
      transport.putAttempts.first.ciphertext,
    );

    var expireCommit = true;
    transport.afterCommit = () {
      if (!expireCommit) return;
      expireCommit = false;
      fixture.clock.value = fixture.clock.value.add(const Duration(minutes: 6));
    };
    expect(await fixture.coordinator.advance(1), 1);
    final commitPending = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(commitPending!.phase, E2eeAttachmentUploadPhase.commitPending);
    expect(await fixture.coordinator.advance(1), 1);
    expect(transport.commitRequests, hasLength(2));
    expect(
      transport.commitRequests.last.mutationId,
      transport.commitRequests.first.mutationId,
    );
    expect(
      transport.commitRequests.last.manifestCiphertext,
      transport.commitRequests.first.manifestCiphertext,
    );
    expect(
      (await fixture.commands.readByAttachmentId(
        fixture.descriptor.attachmentId,
      ))!.phase,
      E2eeAttachmentUploadPhase.committed,
    );
  });

  test('E2EE 附件上传协调器拒绝被篡改的 pending 密文', () async {
    final transport = _AttachmentUploadTransport(
      retryablePutFailuresRemaining: 1,
    );
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[18, 19]),
      transport: transport,
    );
    addTearDown(fixture.close);

    expect(await fixture.coordinator.advance(2), 2);
    final deferred = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    fixture.fileStore.rejectPendingReads = true;
    fixture.clock.value = deferred!.nextAttemptAt;
    expect(await fixture.coordinator.advance(10), 0);
    final terminal = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(
      terminal!.terminalFailureKind,
      'pending-ciphertext-integrity-failed',
    );
    expect(transport.putAttempts, hasLength(1));
  });

  test('E2EE 附件上传协调器将丢失的 pending 密文固化为终止状态', () async {
    final transport = _AttachmentUploadTransport(
      retryablePutFailuresRemaining: 1,
    );
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[20, 21]),
      transport: transport,
    );
    addTearDown(fixture.close);

    expect(await fixture.coordinator.advance(2), 2);
    final deferred = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    fixture.fileStore
      ..rejectPendingReads = true
      ..reportPendingMissing = true;
    fixture.clock.value = deferred!.nextAttemptAt;
    expect(await fixture.coordinator.advance(10), 0);
    final terminal = await fixture.commands.readByAttachmentId(
      fixture.descriptor.attachmentId,
    );
    expect(
      terminal!.terminalFailureKind,
      'pending-ciphertext-integrity-failed',
    );
    expect(transport.putAttempts, hasLength(1));
  });

  test('E2EE 附件上传协调器关闭失败后保留资源并允许重试关闭', () async {
    final fixture = await _AttachmentUploadFixture.create(
      plaintext: Uint8List.fromList(<int>[22, 23]),
    );
    addTearDown(fixture.close);

    expect(await fixture.coordinator.advance(1), 1);
    fixture.fileStore.verifiedContentCloseFailures = 1;
    await expectLater(
      fixture.coordinator.close(),
      throwsA(isA<FileSystemException>()),
    );
    await fixture.coordinator.close();
    await expectLater(
      fixture.coordinator.advance(1),
      throwsA(isA<StateError>()),
    );
  });

  test('E2EE 附件内存文件 adapter 保持完整性合同与 staging 删除边界', () async {
    final store = E2eeAttachmentMemoryFileStore();
    final identity = CloudSyncAttachmentIdentity(
      attachmentId: _attachmentId,
      uploadId: _uploadId,
      keyEpoch: 7,
    );
    final location = E2eeAttachmentFileLocation.stagingUploadChunk(
      chunk: CloudSyncAttachmentChunkIdentity(
        identity: identity,
        chunkIndex: 0,
      ),
      mutationId: _mutationId1,
    );
    final ciphertext = Uint8List.fromList(<int>[1, 2, 3, 4]);
    final stored = await store.publish(
      location: location,
      source: Stream<List<int>>.value(ciphertext),
    );

    expect(
      stored.storagePath,
      'memory://kelivo-e2ee-attachments/staging/upload/'
      '$_attachmentId/$_uploadId/7/0-$_mutationId1.ciphertext',
    );
    expect(await store.readVerified(stored), ciphertext);
    await expectLater(
      store.readVerified(
        E2eeAttachmentStoredFile(
          storagePath: stored.storagePath,
          bytes: cloudSyncMaximumAttachmentChunkCiphertextBytes + 1,
          sha256: stored.sha256,
        ),
      ),
      throwsA(isA<StateError>()),
    );
    final repeated = await store.publish(
      location: location,
      source: Stream<List<int>>.value(ciphertext),
    );
    expect(repeated.storagePath, stored.storagePath);
    await expectLater(
      store.publish(
        location: location,
        source: Stream<List<int>>.value(<int>[9, 9, 9]),
      ),
      throwsA(isA<StateError>()),
    );
    final alternateMutation = await store.publish(
      location: E2eeAttachmentFileLocation.stagingUploadChunk(
        chunk: CloudSyncAttachmentChunkIdentity(
          identity: identity,
          chunkIndex: 0,
        ),
        mutationId: _mutationId2,
      ),
      source: Stream<List<int>>.value(<int>[9, 9, 9]),
    );
    expect(alternateMutation.storagePath, isNot(stored.storagePath));
    await expectLater(
      store.readVerified(
        E2eeAttachmentStoredFile(
          storagePath: stored.storagePath,
          bytes: stored.bytes + 1,
          sha256: stored.sha256,
        ),
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      store.readVerified(
        E2eeAttachmentStoredFile(
          storagePath: stored.storagePath,
          bytes: stored.bytes,
          sha256: _filledBytes(32, 0xff),
        ),
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      store.publish(
        location: E2eeAttachmentFileLocation.stagingUploadChunk(
          chunk: CloudSyncAttachmentChunkIdentity(
            identity: identity,
            chunkIndex: 1,
          ),
          mutationId: _mutationId3,
        ),
        source: Stream<List<int>>.value(<int>[256]),
      ),
      throwsA(isA<FormatException>()),
    );

    final content = Uint8List.fromList(<int>[5, 6, 7]);
    final contentDigest = Uint8List.fromList(sha256.convert(content).bytes);
    final contentStored = await store.publish(
      location: E2eeAttachmentFileLocation.content(
        contentSha256: contentDigest,
      ),
      source: Stream<List<int>>.value(content),
    );
    expect(await store.readVerified(contentStored), content);
    expect(
      await store.readContentRange(
        storedFile: contentStored,
        offset: 1,
        length: 2,
      ),
      orderedEquals(<int>[6, 7]),
    );
    final contentReader = await store.openVerifiedContent(
      storedFile: contentStored,
      chunkPlaintextBytes: <int>[1, 2],
    );
    expect(await contentReader.readChunk(1), orderedEquals(<int>[6, 7]));
    await contentReader.close();
    await expectLater(contentReader.readChunk(0), throwsA(isA<StateError>()));
    await store.verifyContent(contentStored);
    await expectLater(
      store.readContentRange(storedFile: contentStored, offset: 2, length: 2),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      store.publish(
        location: E2eeAttachmentFileLocation.content(
          contentSha256: _filledBytes(32, 0x31),
        ),
        source: Stream<List<int>>.value(content),
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      store.deleteStaging(storagePath: contentStored.storagePath),
      throwsA(isA<StateError>()),
    );

    await store.deleteStaging(storagePath: stored.storagePath);
    await store.deleteStaging(storagePath: stored.storagePath);
    await expectLater(
      store.readVerified(stored),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('E2EE 附件平台文件 adapter 原子发布且拒绝越界与异常实体', () async {
    final root = await Directory.current.createTemp(
      'kelivo-e2ee-attachment-file-store-',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final installation = await Directory(
      p.join(root.path, 'installation'),
    ).create();
    final workspace = await Directory(
      p.join(root.path, 'account-workspace'),
    ).create();
    AppDirectories.bindWorkspaceRoot(
      workspace,
      installationRoot: installation,
      accountWorkspace: true,
    );

    final store = E2eeAttachmentPlatformFileStore();
    final identity = CloudSyncAttachmentIdentity(
      attachmentId: _attachmentId,
      uploadId: _uploadId,
      keyEpoch: 0xffffffff,
    );
    final location = E2eeAttachmentFileLocation.stagingUploadChunk(
      chunk: CloudSyncAttachmentChunkIdentity(
        identity: identity,
        chunkIndex: 999,
      ),
      mutationId: _mutationId1,
    );
    final ciphertext = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
    final stored = await store.publish(
      location: location,
      source: Stream<List<int>>.fromIterable(<List<int>>[
        ciphertext.sublist(0, 2),
        ciphertext.sublist(2),
      ]),
    );
    final ownedRoot = p.join(workspace.path, 'upload', 'e2ee');
    expect(
      p.equals(
        stored.storagePath,
        p.join(
          ownedRoot,
          'staging',
          'upload',
          _attachmentId,
          _uploadId,
          '4294967295',
          '999-$_mutationId1.ciphertext',
        ),
      ),
      isTrue,
    );
    expect(await store.readVerified(stored), ciphertext);
    expect(
      (await store.publish(
        location: location,
        source: Stream<List<int>>.value(ciphertext),
      )).storagePath,
      stored.storagePath,
    );
    await expectLater(
      store.publish(
        location: location,
        source: Stream<List<int>>.value(<int>[8, 8, 8]),
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      await File(stored.storagePath).parent
          .list(followLinks: false)
          .where((entity) => p.basename(entity.path).endsWith('.next'))
          .isEmpty,
      isTrue,
    );
    expect(await store.readVerified(stored), ciphertext);

    final interruptedLocation = E2eeAttachmentFileLocation.stagingUploadChunk(
      chunk: CloudSyncAttachmentChunkIdentity(
        identity: identity,
        chunkIndex: 998,
      ),
      mutationId: _mutationId2,
    );
    await expectLater(
      store.publish(
        location: interruptedLocation,
        source: Stream<List<int>>.error(StateError('source-interrupted')),
      ),
      throwsA(isA<StateError>()),
    );
    final stagingDirectory = File(stored.storagePath).parent;
    expect(
      await File(
        p.join(stagingDirectory.path, '998-$_mutationId2.ciphertext'),
      ).exists(),
      isFalse,
    );
    expect(
      await stagingDirectory
          .list(followLinks: false)
          .where((entity) => p.basename(entity.path).endsWith('.next'))
          .isEmpty,
      isTrue,
    );

    await expectLater(
      store.readVerified(
        E2eeAttachmentStoredFile(
          storagePath: p.join(root.path, 'outside.ciphertext'),
          bytes: 0,
          sha256: Uint8List.fromList(sha256.convert(const <int>[]).bytes),
        ),
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      store.readVerified(
        E2eeAttachmentStoredFile(
          storagePath: stored.storagePath,
          bytes: stored.bytes,
          sha256: _filledBytes(32, 0x41),
        ),
      ),
      throwsA(isA<FormatException>()),
    );

    final downloadMarker = File(p.join(ownedRoot, 'staging', 'download'));
    await downloadMarker.writeAsString('not-a-directory', flush: true);
    await expectLater(
      store.openDownloadPlaintextStaging(
        identity: identity,
        persistedStoragePath: null,
        confirmedPlaintextBytes: 0,
      ),
      throwsA(isA<StateError>()),
    );
    await downloadMarker.delete();

    final content = Uint8List.fromList(<int>[11, 12, 13]);
    final contentDigest = Uint8List.fromList(sha256.convert(content).bytes);
    final contentStored = await store.publish(
      location: E2eeAttachmentFileLocation.content(
        contentSha256: contentDigest,
      ),
      source: Stream<List<int>>.value(content),
    );
    expect(
      p.equals(
        contentStored.storagePath,
        p.join(
          ownedRoot,
          'content',
          contentDigest
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join(),
        ),
      ),
      isTrue,
    );
    expect(await store.readVerified(contentStored), content);
    expect(
      await store.readContentRange(
        storedFile: contentStored,
        offset: 1,
        length: 2,
      ),
      orderedEquals(<int>[12, 13]),
    );
    final contentReader = await store.openVerifiedContent(
      storedFile: contentStored,
      chunkPlaintextBytes: <int>[1, 2],
    );
    expect(await contentReader.readChunk(1), orderedEquals(<int>[12, 13]));
    await contentReader.close();
    await store.verifyContent(contentStored);
    await expectLater(
      store.readContentRange(storedFile: contentStored, offset: -1, length: 1),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      store.publish(
        location: E2eeAttachmentFileLocation.content(
          contentSha256: _filledBytes(32, 0x51),
        ),
        source: Stream<List<int>>.value(content),
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      store.deleteStaging(storagePath: contentStored.storagePath),
      throwsA(isA<StateError>()),
    );

    await File(
      contentStored.storagePath,
    ).writeAsBytes(<int>[11, 12, 14], flush: true);
    await expectLater(
      store.verifyContent(contentStored),
      throwsA(isA<FormatException>()),
    );

    await File(stored.storagePath).writeAsBytes(<int>[1, 2, 3], flush: true);
    await expectLater(
      store.readVerified(stored),
      throwsA(isA<FormatException>()),
    );
    await store.deleteStaging(storagePath: stored.storagePath);
    await store.deleteStaging(storagePath: stored.storagePath);
    await expectLater(
      store.readVerified(stored),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('E2EE 附件内存下载明文 staging 只按持久确认进度恢复并幂等发布', () async {
    final store = E2eeAttachmentMemoryFileStore();
    final identity = CloudSyncAttachmentIdentity(
      attachmentId: _attachmentId,
      uploadId: _uploadId,
      keyEpoch: 7,
    );
    final firstChunk = Uint8List.fromList(<int>[1, 2]);
    final secondChunk = Uint8List.fromList(<int>[3, 4, 5]);
    final plaintext = Uint8List.fromList(<int>[...firstChunk, ...secondChunk]);
    final contentDigest = Uint8List.fromList(sha256.convert(plaintext).bytes);

    final stagingPath = await store.openDownloadPlaintextStaging(
      identity: identity,
      persistedStoragePath: null,
      confirmedPlaintextBytes: 0,
    );
    expect(
      stagingPath,
      'memory://kelivo-e2ee-attachments/staging/download/'
      '$_attachmentId/$_uploadId/7/plaintext.part',
    );
    await store.appendDownloadPlaintextChunk(
      identity: identity,
      stagingPath: stagingPath,
      expectedOffset: 0,
      plaintext: firstChunk,
    );

    // 文件尾可能先于数据库确认落盘，恢复只能回退到数据库已确认位置。
    expect(
      await store.openDownloadPlaintextStaging(
        identity: identity,
        persistedStoragePath: stagingPath,
        confirmedPlaintextBytes: 0,
      ),
      stagingPath,
    );
    await store.appendDownloadPlaintextChunk(
      identity: identity,
      stagingPath: stagingPath,
      expectedOffset: 0,
      plaintext: firstChunk,
    );
    await store.openDownloadPlaintextStaging(
      identity: identity,
      persistedStoragePath: stagingPath,
      confirmedPlaintextBytes: firstChunk.length,
    );
    await expectLater(
      store.appendDownloadPlaintextChunk(
        identity: identity,
        stagingPath: stagingPath,
        expectedOffset: 0,
        plaintext: secondChunk,
      ),
      throwsA(isA<StateError>()),
    );
    await store.appendDownloadPlaintextChunk(
      identity: identity,
      stagingPath: stagingPath,
      expectedOffset: firstChunk.length,
      plaintext: secondChunk,
    );
    await store.appendDownloadPlaintextChunk(
      identity: identity,
      stagingPath: stagingPath,
      expectedOffset: plaintext.length,
      plaintext: Uint8List.fromList(<int>[99]),
    );
    await store.openDownloadPlaintextStaging(
      identity: identity,
      persistedStoragePath: stagingPath,
      confirmedPlaintextBytes: plaintext.length,
    );

    final stored = await store.publishDownloadPlaintext(
      identity: identity,
      stagingPath: stagingPath,
      expectedPlaintextBytes: plaintext.length,
      expectedSha256: contentDigest,
    );
    expect(stored.bytes, plaintext.length);
    expect(stored.sha256, contentDigest);
    await store.verifyContent(stored);
    final repeated = await store.publishDownloadPlaintext(
      identity: identity,
      stagingPath: stagingPath,
      expectedPlaintextBytes: plaintext.length,
      expectedSha256: contentDigest,
    );
    expect(repeated.storagePath, stored.storagePath);

    final isolatedIdentity = CloudSyncAttachmentIdentity(
      attachmentId: _attachmentId,
      uploadId: _uploadId,
      keyEpoch: 8,
    );
    expect(
      await store.openDownloadPlaintextStaging(
        identity: isolatedIdentity,
        persistedStoragePath: null,
        confirmedPlaintextBytes: 0,
      ),
      isNot(stagingPath),
    );
    await expectLater(
      store.openDownloadPlaintextStaging(
        identity: isolatedIdentity,
        persistedStoragePath:
            'memory://kelivo-e2ee-attachments/staging/download/'
            '$_attachmentId/$_uploadId/8/plaintext.part',
        confirmedPlaintextBytes: 1,
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      store.openDownloadPlaintextStaging(
        identity: identity,
        persistedStoragePath:
            'memory://kelivo-e2ee-attachments/staging/download/'
            '$_attachmentId/$_mutationId1/7/plaintext.part',
        confirmedPlaintextBytes: 0,
      ),
      throwsA(isA<StateError>()),
    );

    final zeroIdentity = CloudSyncAttachmentIdentity(
      attachmentId: _mutationId1,
      uploadId: _mutationId2,
      keyEpoch: 9,
    );
    final zeroStaging = await store.openDownloadPlaintextStaging(
      identity: zeroIdentity,
      persistedStoragePath: null,
      confirmedPlaintextBytes: 0,
    );
    await store.appendDownloadPlaintextChunk(
      identity: zeroIdentity,
      stagingPath: zeroStaging,
      expectedOffset: 0,
      plaintext: Uint8List(0),
    );
    final emptyDigest = Uint8List.fromList(sha256.convert(const <int>[]).bytes);
    final zeroStored = await store.publishDownloadPlaintext(
      identity: zeroIdentity,
      stagingPath: zeroStaging,
      expectedPlaintextBytes: 0,
      expectedSha256: emptyDigest,
    );
    expect(zeroStored.bytes, 0);
    await store.verifyContent(zeroStored);

    final corruptIdentity = CloudSyncAttachmentIdentity(
      attachmentId: _mutationId2,
      uploadId: _mutationId3,
      keyEpoch: 10,
    );
    final corruptStaging = await store.openDownloadPlaintextStaging(
      identity: corruptIdentity,
      persistedStoragePath: null,
      confirmedPlaintextBytes: 0,
    );
    await store.appendDownloadPlaintextChunk(
      identity: corruptIdentity,
      stagingPath: corruptStaging,
      expectedOffset: 0,
      plaintext: Uint8List.fromList(<int>[8, 8]),
    );
    await expectLater(
      store.publishDownloadPlaintext(
        identity: corruptIdentity,
        stagingPath: corruptStaging,
        expectedPlaintextBytes: 2,
        expectedSha256: Uint8List.fromList(
          sha256.convert(const <int>[8, 9]).bytes,
        ),
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      store.publishDownloadPlaintext(
        identity: corruptIdentity,
        stagingPath: corruptStaging,
        expectedPlaintextBytes: 1,
        expectedSha256: emptyDigest,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('E2EE 附件平台下载明文 staging 流式验密并拒绝篡改与异常路径', () async {
    final root = await Directory.current.createTemp(
      'kelivo-e2ee-download-plaintext-store-',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final installation = await Directory(
      p.join(root.path, 'installation'),
    ).create();
    final workspace = await Directory(
      p.join(root.path, 'account-workspace'),
    ).create();
    AppDirectories.bindWorkspaceRoot(
      workspace,
      installationRoot: installation,
      accountWorkspace: true,
    );

    final store = E2eeAttachmentPlatformFileStore();
    final identity = CloudSyncAttachmentIdentity(
      attachmentId: _attachmentId,
      uploadId: _uploadId,
      keyEpoch: 0xffffffff,
    );
    final firstChunk = Uint8List.fromList(<int>[11, 12]);
    final secondChunk = Uint8List.fromList(<int>[13, 14, 15]);
    final plaintext = Uint8List.fromList(<int>[...firstChunk, ...secondChunk]);
    final contentDigest = Uint8List.fromList(sha256.convert(plaintext).bytes);
    final stagingPath = await store.openDownloadPlaintextStaging(
      identity: identity,
      persistedStoragePath: null,
      confirmedPlaintextBytes: 0,
    );
    expect(
      p.equals(
        stagingPath,
        p.join(
          workspace.path,
          'upload',
          'e2ee',
          'staging',
          'download',
          _attachmentId,
          _uploadId,
          '4294967295',
          'plaintext.part',
        ),
      ),
      isTrue,
    );
    await store.appendDownloadPlaintextChunk(
      identity: identity,
      stagingPath: stagingPath,
      expectedOffset: 0,
      plaintext: firstChunk,
    );
    await store.openDownloadPlaintextStaging(
      identity: identity,
      persistedStoragePath: stagingPath,
      confirmedPlaintextBytes: firstChunk.length,
    );
    await store.appendDownloadPlaintextChunk(
      identity: identity,
      stagingPath: stagingPath,
      expectedOffset: firstChunk.length,
      plaintext: secondChunk,
    );
    final crashTail = await File(stagingPath).open(mode: FileMode.append);
    await crashTail.writeFrom(const <int>[99, 100]);
    await crashTail.flush();
    await crashTail.close();
    await store.openDownloadPlaintextStaging(
      identity: identity,
      persistedStoragePath: stagingPath,
      confirmedPlaintextBytes: plaintext.length,
    );
    expect(await File(stagingPath).length(), plaintext.length);
    await expectLater(
      store.appendDownloadPlaintextChunk(
        identity: identity,
        stagingPath: stagingPath,
        expectedOffset: firstChunk.length,
        plaintext: secondChunk,
      ),
      throwsA(isA<StateError>()),
    );

    final tampered = await File(stagingPath).readAsBytes();
    tampered[1] = 0xff;
    await File(stagingPath).writeAsBytes(tampered, flush: true);
    await expectLater(
      store.publishDownloadPlaintext(
        identity: identity,
        stagingPath: stagingPath,
        expectedPlaintextBytes: plaintext.length,
        expectedSha256: contentDigest,
      ),
      throwsA(isA<FormatException>()),
    );

    await store.deleteStaging(storagePath: stagingPath);
    await store.openDownloadPlaintextStaging(
      identity: identity,
      persistedStoragePath: stagingPath,
      confirmedPlaintextBytes: 0,
    );
    await store.appendDownloadPlaintextChunk(
      identity: identity,
      stagingPath: stagingPath,
      expectedOffset: 0,
      plaintext: firstChunk,
    );
    await store.appendDownloadPlaintextChunk(
      identity: identity,
      stagingPath: stagingPath,
      expectedOffset: firstChunk.length,
      plaintext: secondChunk,
    );
    final stored = await store.publishDownloadPlaintext(
      identity: identity,
      stagingPath: stagingPath,
      expectedPlaintextBytes: plaintext.length,
      expectedSha256: contentDigest,
    );
    expect(await File(stored.storagePath).length(), plaintext.length);
    await store.verifyContent(stored);
    final repeated = await store.publishDownloadPlaintext(
      identity: identity,
      stagingPath: stagingPath,
      expectedPlaintextBytes: plaintext.length,
      expectedSha256: contentDigest,
    );
    expect(repeated.storagePath, stored.storagePath);

    await File(
      stored.storagePath,
    ).writeAsBytes(const <int>[11, 12, 13, 14, 16], flush: true);
    await expectLater(
      store.publishDownloadPlaintext(
        identity: identity,
        stagingPath: stagingPath,
        expectedPlaintextBytes: plaintext.length,
        expectedSha256: contentDigest,
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      store.openDownloadPlaintextStaging(
        identity: identity,
        persistedStoragePath: p.join(root.path, 'outside.part'),
        confirmedPlaintextBytes: 0,
      ),
      throwsA(isA<StateError>()),
    );

    final unsafeIdentity = CloudSyncAttachmentIdentity(
      attachmentId: _mutationId1,
      uploadId: _mutationId2,
      keyEpoch: 1,
    );
    final unsafeParent = File(
      p.join(
        workspace.path,
        'upload',
        'e2ee',
        'staging',
        'download',
        _mutationId1,
      ),
    );
    await unsafeParent.parent.create(recursive: true);
    await unsafeParent.writeAsString('not-a-directory', flush: true);
    await expectLater(
      store.openDownloadPlaintextStaging(
        identity: unsafeIdentity,
        persistedStoragePath: null,
        confirmedPlaintextBytes: 0,
      ),
      throwsA(isA<StateError>()),
    );

    final zeroIdentity = CloudSyncAttachmentIdentity(
      attachmentId: _mutationId2,
      uploadId: _mutationId3,
      keyEpoch: 2,
    );
    final zeroStaging = await store.openDownloadPlaintextStaging(
      identity: zeroIdentity,
      persistedStoragePath: null,
      confirmedPlaintextBytes: 0,
    );
    await expectLater(
      store.openDownloadPlaintextStaging(
        identity: zeroIdentity,
        persistedStoragePath: zeroStaging,
        confirmedPlaintextBytes: 1,
      ),
      throwsA(isA<StateError>()),
    );
    await store.appendDownloadPlaintextChunk(
      identity: zeroIdentity,
      stagingPath: zeroStaging,
      expectedOffset: 0,
      plaintext: Uint8List(0),
    );
    final emptyDigest = Uint8List.fromList(sha256.convert(const <int>[]).bytes);
    final zeroStored = await store.publishDownloadPlaintext(
      identity: zeroIdentity,
      stagingPath: zeroStaging,
      expectedPlaintextBytes: 0,
      expectedSha256: emptyDigest,
    );
    expect(await File(zeroStored.storagePath).length(), 0);
    await store.verifyContent(zeroStored);
  });
}

final class _AttachmentUploadFixture {
  _AttachmentUploadFixture._({
    required this.directory,
    required this.repository,
    required this.commands,
    required this.fileStore,
    required this.deviceStateStore,
    required this.session,
    required this.descriptor,
    required Uint8List plaintext,
    required this.transport,
    required this.clock,
  }) : plaintext = Uint8List.fromList(plaintext).asUnmodifiableView();

  final Directory directory;
  final ChatDatabaseRepository repository;
  final E2eeAttachmentUploadCommands commands;
  final _AttachmentTestFileStore fileStore;
  final DeviceStateBlobStore deviceStateStore;
  final CloudSyncAccountSession session;
  final E2eeAttachmentDescriptor descriptor;
  final Uint8List plaintext;
  final _AttachmentUploadTransport transport;
  final _MutableAttachmentClock clock;
  final KelivoSecureCore _secureCore = const KelivoSecureCore();

  E2eeAttachmentUploadCoordinator? _coordinator;
  var _uuidSequence = 0;
  var _closed = false;

  E2eeAttachmentUploadCoordinator get coordinator {
    final value = _coordinator;
    if (value == null) throw StateError('附件上传测试协调器尚未打开');
    return value;
  }

  static Future<_AttachmentUploadFixture> create({
    required Uint8List plaintext,
    _AttachmentUploadTransport? transport,
    Uint8List? descriptorContentSha256,
    bool openCoordinator = true,
    int transientVerifyFailures = 0,
  }) async {
    final directory = await Directory.current.createTemp(
      'kelivo_attachment_upload_coordinator_',
    );
    ChatDatabaseRepository? repository;
    try {
      final database = AppDatabase.open(
        file: File(p.join(directory.path, 'upload.sqlite')),
        cipher: testDatabaseCipher,
      );
      await database.customSelect('SELECT 1;').getSingle();
      repository = ChatDatabaseRepository(
        database,
        databaseCipher: testDatabaseCipher,
      );
      const secureCore = KelivoSecureCore();
      final deviceStateStore = DeviceStateBlobStore(
        installationRoot: directory,
      );
      final nonce = sha256
          .convert(utf8.encode(directory.path))
          .toString()
          .substring(0, 16);
      final session = await _seedAccountKeyLeaseState(
        core: secureCore,
        store: deviceStateStore,
        baseUrl: 'https://upload-$nonce.example.com',
        loginName: 'upload-$nonce',
      );
      final dataKey = await secureCore.generateAttachmentDataKey();
      final attachmentId = _uuidStringForTest(dataKey.attachmentId);
      final keyLease = await E2eeAccountKeyLease.open(
        session: session,
        deviceStateStore: deviceStateStore,
        secureCore: secureCore,
      );
      final ark = keyLease.takeAccountRootKeyOwnership();
      late Uint8List wrappedDataKey;
      try {
        wrappedDataKey = await secureCore.wrapAttachmentDataKey(
          ark,
          dataKey.key,
          context: KelivoAttachmentContext(
            userId: _rawUuid(session.userId),
            attachmentId: dataKey.attachmentId,
            keyEpoch: session.keyEpoch,
          ),
        );
      } finally {
        await secureCore.closeAttachmentDataKey(dataKey.key);
        await secureCore.closeAccountRootKey(ark);
        await keyLease.close();
      }

      final baseFileStore = E2eeAttachmentMemoryFileStore();
      final actualDigest = Uint8List.fromList(sha256.convert(plaintext).bytes);
      final source = await baseFileStore.publish(
        location: E2eeAttachmentFileLocation.content(
          contentSha256: actualDigest,
        ),
        source: Stream<List<int>>.value(plaintext),
      );
      final fileStore = _AttachmentTestFileStore(
        baseFileStore,
        transientVerifyFailures: transientVerifyFailures,
      );
      final layout = KelivoAttachmentLayout(
        totalPlaintextBytes: plaintext.length,
      );
      final descriptor = E2eeAttachmentDescriptor(
        attachmentId: attachmentId,
        keyEpoch: session.keyEpoch,
        kind: E2eeAttachmentKind.file,
        totalPlaintextBytes: plaintext.length,
        contentSha256: descriptorContentSha256 ?? actualDigest,
        wrappedDataKey: wrappedDataKey,
        chunkCiphertextBytes: <int>[
          for (var index = 0; index < layout.chunkCount; index++)
            layout.plaintextLengthForChunk(index) +
                KelivoAttachmentLimits.chunkEnvelopeOverheadBytes,
        ],
        displayName: 'upload.bin',
        mediaType: 'application/octet-stream',
      );
      const targetRevisionId = 'attachment-upload-message';
      const localAssetId = 'attachment-upload-test';
      final assetTimestamp = DateTime.utc(2026, 7, 29, 8);
      await database
          .into(database.conversationRows)
          .insert(
            ConversationRowsCompanion.insert(
              id: 'attachment-upload-conversation',
              title: 'Attachment upload',
              createdAt: assetTimestamp,
              updatedAt: assetTimestamp,
            ),
          );
      await database
          .into(database.messageRows)
          .insert(
            MessageRowsCompanion.insert(
              id: targetRevisionId,
              conversationId: 'attachment-upload-conversation',
              role: 'user',
              content: '',
              timestamp: assetTimestamp,
              turnId: 'attachment-upload-turn',
              generationStatus: 'completed',
              messageOrder: 0,
            ),
          );
      await database
          .into(database.assetRows)
          .insert(
            AssetRowsCompanion.insert(
              id: localAssetId,
              contentHash: descriptor.contentSha256
                  .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
                  .join(),
              path: source.storagePath,
              byteSize: plaintext.length,
              createdAt: assetTimestamp,
              lastReferencedAt: assetTimestamp,
            ),
          );
      await database
          .into(database.messageAssetRows)
          .insert(
            MessageAssetRowsCompanion.insert(
              revisionId: targetRevisionId,
              ordinal: 0,
              assetId: localAssetId,
              kind: E2eeAttachmentKind.file.name,
              displayName: const Value('upload.bin'),
              mediaType: const Value('application/octet-stream'),
            ),
          );
      final commands = repository.e2eeAttachmentUploadCommands;
      final clock = _MutableAttachmentClock(DateTime.utc(2026, 7, 29, 8));
      await commands.create(
        draft: E2eeAttachmentUploadDraft(
          descriptor: descriptor,
          localAssetId: localAssetId,
          targetRevisionId: targetRevisionId,
          targetOrdinal: 0,
          sourcePath: source.storagePath,
          createMutationId: _mutationId1,
          commitMutationId: _mutationId2,
        ),
        now: clock.value,
      );
      final fixture = _AttachmentUploadFixture._(
        directory: directory,
        repository: repository,
        commands: commands,
        fileStore: fileStore,
        deviceStateStore: deviceStateStore,
        session: session,
        descriptor: descriptor,
        plaintext: plaintext,
        transport: transport ?? _AttachmentUploadTransport(),
        clock: clock,
      );
      if (openCoordinator) await fixture._openCoordinator();
      return fixture;
    } catch (_) {
      if (repository != null) await repository.close();
      if (await directory.exists()) await directory.delete(recursive: true);
      rethrow;
    }
  }

  Future<E2eeAttachmentCryptoSession> openCryptoSession() {
    return E2eeAttachmentCryptoSession.open(
      session: session,
      deviceStateStore: deviceStateStore,
      secureCore: _secureCore,
    );
  }

  Future<void> restartCoordinator() async {
    await _coordinator?.close();
    _coordinator = null;
    await _openCoordinator();
  }

  Future<void> _openCoordinator() async {
    final cryptoSession = await openCryptoSession();
    _coordinator = E2eeAttachmentUploadCoordinator.takeOwnership(
      commands: commands,
      fileStore: fileStore,
      transport: transport,
      token: session.token,
      cryptoSession: cryptoSession,
      utcNow: clock.call,
      newUuid: _nextUuid,
    );
  }

  String _nextUuid() {
    _uuidSequence++;
    return 'a0000000-0000-4000-8000-'
        '${_uuidSequence.toRadixString(16).padLeft(12, '0')}';
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _coordinator?.close();
    await repository.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

final class _MutableAttachmentClock {
  _MutableAttachmentClock(this.value);

  DateTime value;

  DateTime call() => value;
}

final class _AttachmentTestFileStore implements E2eeAttachmentFileStore {
  _AttachmentTestFileStore(this._delegate, {this.transientVerifyFailures = 0});

  final E2eeAttachmentFileStore _delegate;
  int transientVerifyFailures;
  bool rejectPendingReads = false;
  bool reportPendingMissing = false;
  void Function()? beforeOpenVerifiedContent;
  void Function(E2eeAttachmentStoredFile stored)? afterPublish;
  int verifiedContentCloseFailures = 0;
  int verifiedContentOpens = 0;
  int verifiedChunkReads = 0;
  int unverifiedRangeReads = 0;

  @override
  Future<E2eeAttachmentStoredFile> publish({
    required E2eeAttachmentFileLocation location,
    required Stream<List<int>> source,
  }) async {
    final stored = await _delegate.publish(location: location, source: source);
    afterPublish?.call(stored);
    return stored;
  }

  @override
  Future<Uint8List> readVerified(E2eeAttachmentStoredFile storedFile) {
    if (rejectPendingReads) {
      if (reportPendingMissing) {
        throw FileSystemException(
          'e2ee_attachment_file_missing',
          storedFile.storagePath,
        );
      }
      throw const FormatException('e2ee_attachment_file_integrity');
    }
    return _delegate.readVerified(storedFile);
  }

  @override
  Future<Uint8List> readContentRange({
    required E2eeAttachmentStoredFile storedFile,
    required int offset,
    required int length,
  }) {
    unverifiedRangeReads++;
    return _delegate.readContentRange(
      storedFile: storedFile,
      offset: offset,
      length: length,
    );
  }

  @override
  Future<E2eeAttachmentVerifiedContent> openVerifiedContent({
    required E2eeAttachmentStoredFile storedFile,
    required List<int> chunkPlaintextBytes,
  }) async {
    beforeOpenVerifiedContent?.call();
    if (transientVerifyFailures > 0) {
      transientVerifyFailures--;
      throw FileSystemException('temporary-sharing-violation');
    }
    final reader = await _delegate.openVerifiedContent(
      storedFile: storedFile,
      chunkPlaintextBytes: chunkPlaintextBytes,
    );
    verifiedContentOpens++;
    return _AttachmentTestVerifiedContent(reader, this);
  }

  @override
  Future<void> verifyContent(E2eeAttachmentStoredFile storedFile) {
    return _delegate.verifyContent(storedFile);
  }

  @override
  Future<String> openDownloadPlaintextStaging({
    required CloudSyncAttachmentIdentity identity,
    required String? persistedStoragePath,
    required int confirmedPlaintextBytes,
  }) {
    return _delegate.openDownloadPlaintextStaging(
      identity: identity,
      persistedStoragePath: persistedStoragePath,
      confirmedPlaintextBytes: confirmedPlaintextBytes,
    );
  }

  @override
  Future<void> appendDownloadPlaintextChunk({
    required CloudSyncAttachmentIdentity identity,
    required String stagingPath,
    required int expectedOffset,
    required Uint8List plaintext,
  }) {
    return _delegate.appendDownloadPlaintextChunk(
      identity: identity,
      stagingPath: stagingPath,
      expectedOffset: expectedOffset,
      plaintext: plaintext,
    );
  }

  @override
  Future<E2eeAttachmentStoredFile> publishDownloadPlaintext({
    required CloudSyncAttachmentIdentity identity,
    required String stagingPath,
    required int expectedPlaintextBytes,
    required Uint8List expectedSha256,
  }) {
    return _delegate.publishDownloadPlaintext(
      identity: identity,
      stagingPath: stagingPath,
      expectedPlaintextBytes: expectedPlaintextBytes,
      expectedSha256: expectedSha256,
    );
  }

  @override
  Future<void> deleteStaging({required String storagePath}) {
    return _delegate.deleteStaging(storagePath: storagePath);
  }
}

final class _AttachmentTestVerifiedContent
    implements E2eeAttachmentVerifiedContent {
  const _AttachmentTestVerifiedContent(this._delegate, this._owner);

  final E2eeAttachmentVerifiedContent _delegate;
  final _AttachmentTestFileStore _owner;

  @override
  Future<Uint8List> readChunk(int chunkIndex) {
    _owner.verifiedChunkReads++;
    return _delegate.readChunk(chunkIndex);
  }

  @override
  Future<void> close() {
    if (_owner.verifiedContentCloseFailures > 0) {
      _owner.verifiedContentCloseFailures--;
      throw FileSystemException('temporary-close-failure');
    }
    return _delegate.close();
  }
}

final class _AttachmentPutAttempt {
  _AttachmentPutAttempt({
    required this.mutationId,
    required this.chunkIndex,
    required Uint8List ciphertext,
  }) : ciphertext = Uint8List.fromList(ciphertext).asUnmodifiableView();

  final String mutationId;
  final int chunkIndex;
  final Uint8List ciphertext;
}

final class _AttachmentUploadTransport implements CloudSyncAttachmentTransport {
  _AttachmentUploadTransport({
    this.retryablePutFailuresRemaining = 0,
    this.permanentPutFailure,
  });

  int retryablePutFailuresRemaining;
  final CloudSyncException? permanentPutFailure;
  void Function()? afterCreate;
  void Function()? afterPut;
  void Function()? afterCommit;
  final List<CloudSyncAttachmentCreateUploadRequest> createRequests =
      <CloudSyncAttachmentCreateUploadRequest>[];
  final List<_AttachmentPutAttempt> putAttempts = <_AttachmentPutAttempt>[];
  final List<CloudSyncAttachmentCommitUploadRequest> commitRequests =
      <CloudSyncAttachmentCommitUploadRequest>[];

  int get remoteCalls =>
      createRequests.length + putAttempts.length + commitRequests.length;

  @override
  Future<CloudSyncAttachmentUpload> createAttachmentUpload({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentCreateUploadRequest request,
  }) async {
    createRequests.add(request);
    afterCreate?.call();
    return CloudSyncAttachmentUpload(
      identity: CloudSyncAttachmentIdentity(
        attachmentId: request.attachmentId,
        uploadId: _uploadId,
        keyEpoch: request.keyEpoch,
      ),
      chunkCount: request.chunkCount,
      totalCiphertextBytes: request.totalCiphertextBytes,
      createdAt: DateTime.utc(2026, 7, 29, 8),
    );
  }

  @override
  Future<CloudSyncAttachmentStoredChunk> putAttachmentChunk({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentPutChunkRequest request,
  }) async {
    putAttempts.add(
      _AttachmentPutAttempt(
        mutationId: request.mutationId,
        chunkIndex: request.chunk.chunkIndex,
        ciphertext: request.ciphertext,
      ),
    );
    afterPut?.call();
    if (retryablePutFailuresRemaining > 0) {
      retryablePutFailuresRemaining--;
      throw const CloudSyncException(
        kind: CloudSyncFailureKind.network,
        retryable: true,
      );
    }
    final permanent = permanentPutFailure;
    if (permanent != null) throw permanent;
    return CloudSyncAttachmentStoredChunk(
      chunk: request.chunk,
      ciphertextBytes: request.ciphertext.length,
    );
  }

  @override
  Future<CloudSyncAttachmentCommittedUpload> commitAttachmentUpload({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentCommitUploadRequest request,
  }) async {
    commitRequests.add(request);
    afterCommit?.call();
    return CloudSyncAttachmentCommittedUpload(
      identity: request.identity,
      committedAt: DateTime.utc(2026, 7, 29, 8, 1),
    );
  }

  @override
  Future<CloudSyncAttachmentManifest> getAttachmentManifest({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentIdentity identity,
  }) {
    throw UnsupportedError('上传协调器测试不读取远端清单');
  }

  @override
  Future<CloudSyncAttachmentChunk> getAttachmentChunk({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentChunkIdentity chunk,
  }) {
    throw UnsupportedError('上传协调器测试不下载远端分块');
  }

  @override
  Future<CloudSyncAttachmentDeleted> deleteAttachment({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentDeleteRequest request,
  }) {
    throw UnsupportedError('上传协调器测试不删除远端附件');
  }
}

Future<HttpRequest> _nextAttachmentRequest(
  StreamIterator<HttpRequest> requests,
) async {
  if (!await requests.moveNext()) {
    throw StateError('附件测试服务提前关闭');
  }
  return requests.current;
}

Future<void> _expectAttachmentRequest(
  HttpRequest request, {
  required String path,
  required Map<String, Object?> body,
}) async {
  expect(request.method, 'POST');
  expect(request.uri.path, path);
  expect(
    request.headers.value(HttpHeaders.authorizationHeader),
    'Bearer $_fullTokenValue',
  );
  expect(request.headers.value('x-kelivo-sync-protocol-version'), '3');
  expect(jsonDecode(await utf8.decoder.bind(request).join()), body);
}

Future<void> _writeJsonResponse(
  HttpRequest request,
  Map<String, Object?> body, {
  int statusCode = HttpStatus.ok,
}) async {
  request.response
    ..statusCode = statusCode
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  await request.response.close();
}

Uint8List _authenticatorSlotId(String baseUrl, String loginName) {
  final digest = sha256.convert(
    utf8.encode(
      'kelivo.e2ee.device-state.slot.v1\u0000$baseUrl\u0000$loginName',
    ),
  );
  return Uint8List.fromList(digest.bytes.sublist(0, 16));
}

Future<CloudSyncAccountSession> _seedAccountKeyLeaseState({
  required KelivoSecureCore core,
  required DeviceStateBlobStore store,
  required String baseUrl,
  required String loginName,
  bool bound = true,
}) async {
  final key = await core.createSlot(
    E2eeDeviceStateAccess.deriveSlotId(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
    ),
  );
  final identity = await core.generateDeviceIdentity();
  KelivoAccountRootKeyHandle? ark;
  try {
    if (bound) ark = await core.generateAccountRootKey();
    final blob = await core.sealDeviceState(
      key,
      identity,
      deviceId: _rawUuid(_deviceId1),
      keyVersion: 3,
      ark: ark,
      account: bound
          ? KelivoDeviceStateAccountBinding(
              userId: _rawUuid(_userId),
              keyEpoch: 7,
            )
          : null,
    );
    await store.write(
      normalizedBaseUrl: baseUrl,
      normalizedLoginName: loginName,
      blob: blob,
    );
  } finally {
    if (ark != null) await core.closeAccountRootKey(ark);
    await core.closeDeviceIdentity(identity);
    await core.close(key);
  }
  return _accountKeyLeaseSession(baseUrl: baseUrl, loginName: loginName);
}

CloudSyncAccountSession _accountKeyLeaseSession({
  required String baseUrl,
  required String loginName,
  String userId = _userId,
  String deviceId = _deviceId1,
  int keyEpoch = 7,
  int deviceKeyVersion = 3,
}) {
  return CloudSyncAccountSession(
    baseUrl: baseUrl,
    token: _fullToken,
    tokenExpiresAt: DateTime.utc(2030),
    keyEpoch: keyEpoch,
    userId: userId,
    loginName: loginName,
    displayName: 'Lease User',
    role: CloudSyncUserRole.user,
    attachmentQuotaBytes: 1024,
    deviceId: deviceId,
    deviceName: 'Lease Device',
    platform: CloudSyncPlatform.windows,
    clientVersion: '1.0.0',
    deviceKeyVersion: deviceKeyVersion,
    deviceCreatedAt: DateTime.utc(2026),
  );
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
