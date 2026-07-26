import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/sync/cloud_sync_client.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_record_types.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';

const _mutationId1 = '00000000-0000-4000-8000-000000000001';
const _mutationId2 = '00000000-0000-4000-8000-000000000002';
const _mutationId3 = '00000000-0000-4000-8000-000000000003';
const _recordId1 = '10000000-0000-4000-8000-000000000001';
const _recordId2 = '10000000-0000-4000-8000-000000000002';
const _recordId3 = '10000000-0000-4000-8000-000000000003';
const _deviceId1 = '20000000-0000-4000-8000-000000000001';
const _deviceId2 = '20000000-0000-4000-8000-000000000002';
const _attemptId1 = '30000000-0000-4000-8000-000000000001';
const _attemptId2 = '30000000-0000-4000-8000-000000000002';
const _userId = '40000000-0000-4000-8000-000000000001';
const _accountContextId = '50000000-0000-4000-8000-000000000001';
const _pairingId = '60000000-0000-4000-8000-000000000001';
const _issuerDeviceId = '70000000-0000-4000-8000-000000000001';
const _fullTokenValue = 'kelivo_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _onboardingTokenValue =
    'kelivo_onboarding_BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';

final _fullToken = CloudSyncFullSessionToken.parse(_fullTokenValue);
final _onboardingToken = CloudSyncOnboardingToken.parse(_onboardingTokenValue);

Uint8List _filledBytes(int length, [int value = 0]) {
  return Uint8List.fromList(List<int>.filled(length, value));
}

String _encodedBytes(int length, [int value = 0]) {
  return base64Url.encode(_filledBytes(length, value)).replaceAll('=', '');
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
}) {
  return <String, Object?>{
    'protocolVersion': cloudSyncOpaqueProtocolVersion,
    'result': 'authenticated',
    'keyEpoch': keyEpoch,
    'token': token,
    'tokenExpiresAt': '2026-07-27T05:00:00.000Z',
    'user': <String, Object?>{
      'id': _userId,
      'loginName': 'alice',
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

  test('设备配对全生命周期按令牌能力隔离并接管完整会话', () async {
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

  test('v3 推送以不透明 put 和 delete 提交并解析三类结果', () async {
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

    final pushFuture = client.pushRecords(<CloudSyncRecordMutation>[
      const CloudSyncPutRecordMutation(
        mutationId: _mutationId1,
        recordId: _recordId1,
        expectedRevision: 0,
        keyEpoch: 7,
        ciphertext: 'AQID',
      ),
      const CloudSyncDeleteRecordMutation(
        mutationId: _mutationId2,
        recordId: _recordId2,
        expectedRevision: 3,
      ),
      const CloudSyncPutRecordMutation(
        mutationId: _mutationId3,
        recordId: _recordId3,
        expectedRevision: 2,
        keyEpoch: 8,
        ciphertext: 'BAUG',
      ),
    ]);

    final request = await requestFuture;
    expect(request.uri.path, '/api/sync/record/push');
    expect(request.headers.value('x-kelivo-sync-protocol-version'), '3');
    expect(
      jsonDecode(await utf8.decoder.bind(request).join()),
      <String, Object?>{
        'mutations': <Object?>[
          <String, Object?>{
            'mutationId': _mutationId1,
            'recordId': _recordId1,
            'expectedRevision': 0,
            'operation': 'put',
            'envelopeVersion': 1,
            'keyEpoch': 7,
            'ciphertext': 'AQID',
          },
          <String, Object?>{
            'mutationId': _mutationId2,
            'recordId': _recordId2,
            'expectedRevision': 3,
            'operation': 'delete',
          },
          <String, Object?>{
            'mutationId': _mutationId3,
            'recordId': _recordId3,
            'expectedRevision': 2,
            'operation': 'put',
            'envelopeVersion': 1,
            'keyEpoch': 8,
            'ciphertext': 'BAUG',
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

  test('v3 增量拉取保持密文不透明并区分 put 与 delete', () async {
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
    expect(request.uri.path, '/api/sync/change/pull');
    expect(request.headers.value('x-kelivo-sync-protocol-version'), '3');
    expect(
      jsonDecode(await utf8.decoder.bind(request).join()),
      <String, Object?>{'cursor': 'cursor-1', 'limit': 2},
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

    final page = await pullFuture;
    expect(page.nextCursor, 'cursor-2');
    expect(page.hasMore, isTrue);
    expect(page.resetRequired, isFalse);
    expect(
      page.changes[0],
      isA<CloudSyncPutRecordChange>()
          .having((change) => change.changeSeq, 'changeSeq', 12)
          .having((change) => change.recordId, 'recordId', _recordId1)
          .having((change) => change.revision, 'revision', 2)
          .having((change) => change.envelopeVersion, 'envelopeVersion', 1)
          .having((change) => change.keyEpoch, 'keyEpoch', 7)
          .having((change) => change.ciphertext, 'ciphertext', 'AQID')
          .having(
            (change) => change.updatedByDeviceId,
            'updatedByDeviceId',
            _deviceId1,
          ),
    );
    expect(
      page.changes[1],
      isA<CloudSyncDeleteRecordChange>()
          .having((change) => change.changeSeq, 'changeSeq', 13)
          .having(
            (change) => change.deletedAt,
            'deletedAt',
            DateTime.utc(2026, 7, 19, 5, 1),
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

  test('v3 快照拉取解析 active 与 deleted 并返回固定水位游标', () async {
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
    expect(request.uri.path, '/api/sync/snapshot/pull');
    expect(request.headers.value('x-kelivo-sync-protocol-version'), '3');
    expect(
      jsonDecode(await utf8.decoder.bind(request).join()),
      <String, Object?>{'snapshotCursor': 'snapshot-1', 'limit': 2},
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

    final page = await pullFuture;
    expect(page.nextSnapshotCursor, isNull);
    expect(page.syncCursor, 'sync-13');
    expect(page.hasMore, isFalse);
    expect(
      page.records[0],
      isA<CloudSyncActiveRecord>()
          .having((record) => record.recordId, 'recordId', _recordId1)
          .having((record) => record.revision, 'revision', 2)
          .having((record) => record.lastChangeSeq, 'lastChangeSeq', 12)
          .having((record) => record.envelopeVersion, 'envelopeVersion', 1)
          .having((record) => record.keyEpoch, 'keyEpoch', 7)
          .having((record) => record.ciphertext, 'ciphertext', 'BAUG'),
    );
    expect(
      page.records[1],
      isA<CloudSyncDeletedRecord>()
          .having((record) => record.recordId, 'recordId', _recordId2)
          .having((record) => record.lastChangeSeq, 'lastChangeSeq', 13)
          .having(
            (record) => record.deletedAt,
            'deletedAt',
            DateTime.utc(2026, 7, 19, 5, 1),
          ),
    );
  });

  test('v3 推送在发网前拒绝非法标识、密文与批量边界', () {
    final client = CloudSyncClient.forTesting(baseUrl: 'http://127.0.0.1:1');
    addTearDown(() => client.close(force: true));
    final oversizedCiphertext = base64Url
        .encode(Uint8List(1048577))
        .replaceAll('=', '');
    final halfBatchCiphertext = base64Url
        .encode(Uint8List(524289))
        .replaceAll('=', '');
    final oversizedBatch = List<CloudSyncRecordMutation>.generate(
      11,
      (index) => CloudSyncDeleteRecordMutation(
        mutationId:
            '00000000-0000-4000-8000-${(index + 100).toString().padLeft(12, '0')}',
        recordId:
            '10000000-0000-4000-8000-${(index + 100).toString().padLeft(12, '0')}',
        expectedRevision: 1,
      ),
    );
    final invalidCalls = <(String, Object? Function())>[
      ('空批次', () => client.pushRecords(const <CloudSyncRecordMutation>[])),
      ('超过十条', () => client.pushRecords(oversizedBatch)),
      (
        '非规范 UUID',
        () => client.pushRecords(const <CloudSyncRecordMutation>[
          CloudSyncPutRecordMutation(
            mutationId: 'A0000000-0000-4000-8000-000000000001',
            recordId: _recordId1,
            expectedRevision: 0,
            keyEpoch: 1,
            ciphertext: 'AQID',
          ),
        ]),
      ),
      (
        '带填充 Base64URL',
        () => client.pushRecords(const <CloudSyncRecordMutation>[
          CloudSyncPutRecordMutation(
            mutationId: _mutationId1,
            recordId: _recordId1,
            expectedRevision: 0,
            keyEpoch: 1,
            ciphertext: 'AQID=',
          ),
        ]),
      ),
      (
        '非规范尾位 Base64URL',
        () => client.pushRecords(const <CloudSyncRecordMutation>[
          CloudSyncPutRecordMutation(
            mutationId: _mutationId1,
            recordId: _recordId1,
            expectedRevision: 0,
            keyEpoch: 1,
            ciphertext: 'AB',
          ),
        ]),
      ),
      (
        '单条密文超过一 MiB',
        () => client.pushRecords(<CloudSyncRecordMutation>[
          CloudSyncPutRecordMutation(
            mutationId: _mutationId1,
            recordId: _recordId1,
            expectedRevision: 0,
            keyEpoch: 1,
            ciphertext: oversizedCiphertext,
          ),
        ]),
      ),
      (
        '批次密文总量超过一 MiB',
        () => client.pushRecords(<CloudSyncRecordMutation>[
          CloudSyncPutRecordMutation(
            mutationId: _mutationId1,
            recordId: _recordId1,
            expectedRevision: 0,
            keyEpoch: 1,
            ciphertext: halfBatchCiphertext,
          ),
          CloudSyncPutRecordMutation(
            mutationId: _mutationId2,
            recordId: _recordId2,
            expectedRevision: 0,
            keyEpoch: 1,
            ciphertext: halfBatchCiphertext,
          ),
        ]),
      ),
      (
        'delete 不允许零 revision',
        () => client.pushRecords(const <CloudSyncRecordMutation>[
          CloudSyncDeleteRecordMutation(
            mutationId: _mutationId1,
            recordId: _recordId1,
            expectedRevision: 0,
          ),
        ]),
      ),
      (
        'key epoch 越界',
        () => client.pushRecords(const <CloudSyncRecordMutation>[
          CloudSyncPutRecordMutation(
            mutationId: _mutationId1,
            recordId: _recordId1,
            expectedRevision: 0,
            keyEpoch: 2147483648,
            ciphertext: 'AQID',
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
                  'ciphertext': 'AQID',
                  'ciphertextBytes': changeRequestCount == 1 ? 4 : 3,
                  'deletedAt': null,
                  'updatedAt': '2026-07-19T05:00:00.000Z',
                  'updatedByDeviceId': _deviceId1,
                },
                if (changeRequestCount > 1)
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
