import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:kelivo_sync_api_client/kelivo_sync_api_client.dart' as api;
import 'package:one_of/one_of.dart';

import 'cloud_sync_record_types.dart';
import 'cloud_sync_types.dart';
import 'e2ee_account_record_cipher.dart';

abstract interface class CloudSyncRecordTransport {
  Future<List<CloudSyncRecordMutationResult>> pushRecords(
    List<CloudSyncRecordMutation> mutations,
  );

  Future<CloudSyncChangePage> pullChanges({String? cursor, int limit = 10});

  Future<CloudSyncSnapshotPage> pullSnapshot({
    String? snapshotCursor,
    int limit = 10,
  });
}

abstract interface class CloudSyncAccountClient {
  void setToken(CloudSyncFullSessionToken? token);

  void close({bool force = false});

  Future<CloudSyncOpaqueRegistrationStart> startOpaqueRegistration({
    required String loginName,
    required String displayName,
    required CloudSyncOpaqueDeviceIdentity device,
    required Uint8List registrationRequest,
  });

  Future<CloudSyncAuthenticatedSession> finishOpaqueRegistration({
    required String attemptId,
    required Uint8List registrationUpload,
    required Uint8List accountKeyEnvelope,
    required Uint8List deviceProof,
  });

  Future<CloudSyncOpaqueLoginStart> startOpaqueLogin({
    required String loginName,
    required CloudSyncOpaqueDeviceIdentity device,
    required Uint8List credentialRequest,
  });

  Future<CloudSyncOpaqueLoginFinishResult> finishOpaqueLogin({
    required String attemptId,
    required Uint8List credentialFinalization,
    required Uint8List deviceProof,
  });

  Future<CloudSyncDevicePairingCreated> createDevicePairing({
    required CloudSyncOnboardingToken token,
    required String pairingId,
    required Uint8List pairingSecretHash,
  });

  Future<CloudSyncDevicePairingQueryResult> queryDevicePairing({
    required CloudSyncOnboardingToken token,
    required String pairingId,
  });

  Future<CloudSyncDevicePairingApproval> approveDevicePairing({
    required CloudSyncFullSessionToken token,
    required String pairingId,
    required int keyEpoch,
    required Uint8List accountKeyEnvelope,
    required Uint8List deviceProof,
    required Uint8List pairingAuthenticator,
  });

  Future<CloudSyncAuthenticatedSession> consumeDevicePairing({
    required CloudSyncOnboardingToken token,
    required String pairingId,
  });

  Future<CloudSyncDevicePairingCancellation> cancelDevicePairing({
    required CloudSyncOnboardingToken token,
    required String pairingId,
  });

  Future<CloudSyncPage<CloudSyncDeviceSession>> listDevices({
    CloudSyncDeviceStatus? status,
    int pageIndex = 1,
    int pageSize = 50,
  });

  Future<CloudSyncDeviceSession> revokeDevice(String deviceId);
}

final class CloudSyncClient
    implements CloudSyncAccountClient, CloudSyncRecordTransport {
  CloudSyncClient._({
    required this.baseUrl,
    required this._dio,
    required this._client,
  });

  factory CloudSyncClient({CloudSyncFullSessionToken? token}) {
    return CloudSyncClient._forBaseUrl(
      baseUrl: defaultCloudSyncBaseUrl,
      token: token,
    );
  }

  @visibleForTesting
  factory CloudSyncClient.forTesting({
    required String baseUrl,
    CloudSyncFullSessionToken? token,
  }) {
    return CloudSyncClient._forBaseUrl(baseUrl: baseUrl, token: token);
  }

  factory CloudSyncClient._forBaseUrl({
    required String baseUrl,
    CloudSyncFullSessionToken? token,
  }) {
    final String normalized;
    try {
      normalized = normalizeCloudSyncBaseUrl(baseUrl);
    } on FormatException {
      throw const CloudSyncException(
        kind: CloudSyncFailureKind.invalidBaseUrl,
        retryable: false,
      );
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: normalized,
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        followRedirects: false,
        headers: const <String, String>{'accept': 'application/json'},
      ),
    );
    final client = CloudSyncClient._(
      baseUrl: normalized,
      dio: dio,
      // 鉴权逐请求显式注入，避免并发请求共享可变拦截器令牌。
      client: api.KelivoSyncApiClient(
        dio: dio,
        interceptors: const <Interceptor>[],
      ),
    );
    client.setToken(token);
    return client;
  }

  static final _syncProtocolVersion = e2eeAccountRecordSyncProtocolVersion
      .toString();

  final String baseUrl;
  final Dio _dio;
  final api.KelivoSyncApiClient _client;
  CloudSyncFullSessionToken? _sessionToken;

  @override
  void setToken(CloudSyncFullSessionToken? token) => _sessionToken = token;

  @override
  void close({bool force = false}) {
    _dio.close(force: force);
  }

  Future<CloudSyncHealth> health() {
    return _guard(() async {
      final response = await _client.getSystemApi().getSystemHealth();
      final data = _requireResponseData(response.data?.data);
      return CloudSyncHealth(
        service: data.service == api.SystemHealthDataServiceEnum.kelivoApi
            ? 'kelivo-api'
            : throw const FormatException('服务端返回了未知服务类型'),
        status: data.status.name,
        timestamp: data.timestamp.toUtc(),
      );
    });
  }

  @override
  Future<CloudSyncOpaqueRegistrationStart> startOpaqueRegistration({
    required String loginName,
    required String displayName,
    required CloudSyncOpaqueDeviceIdentity device,
    required Uint8List registrationRequest,
  }) {
    final normalizedLoginName = _normalizeLoginNameForRequest(loginName);
    final normalizedDisplayName = _normalizeTextForRequest(
      displayName,
      maximumLength: 80,
    );
    final encodedRegistrationRequest = _encodeFixedBinaryForRequest(
      registrationRequest,
      cloudSyncOpaqueRegistrationRequestBytes,
    );

    return _guard(() async {
      final request = api.OpaqueRegistrationStartRequest(
        (builder) => builder
          ..protocolVersion = cloudSyncOpaqueProtocolVersion
          ..loginName = normalizedLoginName
          ..displayName = normalizedDisplayName
          ..deviceId = device.deviceId
          ..deviceName = device.deviceName
          ..platform = _toRegistrationPlatform(device.platform)
          ..clientVersion = device.clientVersion
          ..deviceKeyVersion = device.deviceKeyVersion
          ..signingPublicKey = _encodeFixedBinaryForRequest(
            device.signingPublicKey,
            cloudSyncDevicePublicKeyBytes,
          )
          ..keyAgreementPublicKey = _encodeFixedBinaryForRequest(
            device.keyAgreementPublicKey,
            cloudSyncDevicePublicKeyBytes,
          )
          ..registrationRequest = encodedRegistrationRequest,
      );
      final response = await _client.getAuthApi().startOpaqueRegistration(
        opaqueRegistrationStartRequest: request,
      );
      final data = _requireResponseData(response.data?.data);
      _requireProtocolVersion(data.protocolVersion);
      return CloudSyncOpaqueRegistrationStart(
        attemptId: data.attemptId,
        userId: data.userId,
        accountBinding: data.accountBinding,
        deviceChallenge: _decodeFixedBinaryFromResponse(
          data.deviceChallenge,
          cloudSyncDeviceChallengeBytes,
        ),
        registrationResponse: _decodeFixedBinaryFromResponse(
          data.registrationResponse,
          cloudSyncOpaqueRegistrationResponseBytes,
        ),
        expiresAt: data.expiresAt,
      );
    });
  }

  @override
  Future<CloudSyncAuthenticatedSession> finishOpaqueRegistration({
    required String attemptId,
    required Uint8List registrationUpload,
    required Uint8List accountKeyEnvelope,
    required Uint8List deviceProof,
  }) {
    _requireClientIdentifier(attemptId);
    final encodedRegistrationUpload = _encodeFixedBinaryForRequest(
      registrationUpload,
      cloudSyncOpaqueRegistrationUploadBytes,
    );
    final encodedAccountKeyEnvelope = _encodeFixedBinaryForRequest(
      accountKeyEnvelope,
      cloudSyncAccountKeyEnvelopeBytes,
    );
    final encodedDeviceProof = _encodeFixedBinaryForRequest(
      deviceProof,
      cloudSyncDeviceProofBytes,
    );

    return _guard(() async {
      final request = api.OpaqueRegistrationFinishRequest(
        (builder) => builder
          ..protocolVersion = cloudSyncOpaqueProtocolVersion
          ..attemptId = attemptId
          ..registrationUpload = encodedRegistrationUpload
          ..accountKeyEnvelope = encodedAccountKeyEnvelope
          ..deviceProof = encodedDeviceProof,
      );
      final response = await _client.getAuthApi().finishOpaqueRegistration(
        opaqueRegistrationFinishRequest: request,
      );
      final data = _requireResponseData(response.data?.data);
      _requireProtocolVersion(data.protocolVersion);
      if (data.result.name != 'authenticated') {
        throw const FormatException('服务端返回了未知的注册结果');
      }
      return _authenticatedSessionFromRegistration(data);
    });
  }

  @override
  Future<CloudSyncOpaqueLoginStart> startOpaqueLogin({
    required String loginName,
    required CloudSyncOpaqueDeviceIdentity device,
    required Uint8List credentialRequest,
  }) {
    final normalizedLoginName = _normalizeLoginNameForRequest(loginName);
    final encodedCredentialRequest = _encodeFixedBinaryForRequest(
      credentialRequest,
      cloudSyncOpaqueCredentialRequestBytes,
    );

    return _guard(() async {
      final request = api.OpaqueLoginStartRequest(
        (builder) => builder
          ..protocolVersion = cloudSyncOpaqueProtocolVersion
          ..loginName = normalizedLoginName
          ..deviceId = device.deviceId
          ..deviceName = device.deviceName
          ..platform = _toLoginPlatform(device.platform)
          ..clientVersion = device.clientVersion
          ..deviceKeyVersion = device.deviceKeyVersion
          ..signingPublicKey = _encodeFixedBinaryForRequest(
            device.signingPublicKey,
            cloudSyncDevicePublicKeyBytes,
          )
          ..keyAgreementPublicKey = _encodeFixedBinaryForRequest(
            device.keyAgreementPublicKey,
            cloudSyncDevicePublicKeyBytes,
          )
          ..credentialRequest = encodedCredentialRequest,
      );
      final response = await _client.getAuthApi().startOpaqueLogin(
        opaqueLoginStartRequest: request,
      );
      final data = _requireResponseData(response.data?.data);
      _requireProtocolVersion(data.protocolVersion);
      return CloudSyncOpaqueLoginStart(
        attemptId: data.attemptId,
        accountBinding: data.accountBinding,
        deviceChallenge: _decodeFixedBinaryFromResponse(
          data.deviceChallenge,
          cloudSyncDeviceChallengeBytes,
        ),
        credentialResponse: _decodeFixedBinaryFromResponse(
          data.credentialResponse,
          cloudSyncOpaqueCredentialResponseBytes,
        ),
        expiresAt: data.expiresAt,
      );
    });
  }

  @override
  Future<CloudSyncOpaqueLoginFinishResult> finishOpaqueLogin({
    required String attemptId,
    required Uint8List credentialFinalization,
    required Uint8List deviceProof,
  }) {
    _requireClientIdentifier(attemptId);
    final encodedCredentialFinalization = _encodeFixedBinaryForRequest(
      credentialFinalization,
      cloudSyncOpaqueCredentialFinalizationBytes,
    );
    final encodedDeviceProof = _encodeFixedBinaryForRequest(
      deviceProof,
      cloudSyncDeviceProofBytes,
    );

    return _guard(() async {
      final request = api.OpaqueLoginFinishRequest(
        (builder) => builder
          ..protocolVersion = cloudSyncOpaqueProtocolVersion
          ..attemptId = attemptId
          ..credentialFinalization = encodedCredentialFinalization
          ..deviceProof = encodedDeviceProof,
      );
      final response = await _client.getAuthApi().finishOpaqueLogin(
        opaqueLoginFinishRequest: request,
      );
      final value = _requireResponseData(response.data?.data).oneOf.value;
      if (value is api.OpaqueLoginFinishDataOneOf) {
        _requireProtocolVersion(value.protocolVersion);
        if (value.result.name != 'authenticated') {
          throw const FormatException('服务端返回了未知的登录结果');
        }
        return CloudSyncOpaqueLoginAuthenticated(
          _authenticatedSessionFromLogin(value),
        );
      }
      if (value is api.OpaqueLoginFinishDataOneOf1) {
        _requireProtocolVersion(value.protocolVersion);
        if (value.result.name != 'deviceApprovalRequired') {
          throw const FormatException('服务端返回了未知的登录结果');
        }
        return CloudSyncOpaqueLoginApprovalRequired(
          onboardingToken: CloudSyncOnboardingToken.parse(
            value.onboardingToken,
          ),
          onboardingTokenExpiresAt: value.onboardingTokenExpiresAt,
          device: _authenticatedDevice(
            id: value.device.id,
            name: value.device.name,
            platform: value.device.platform.name,
            clientVersion: value.device.clientVersion,
            status: value.device.status.name,
            createdAt: value.device.createdAt,
          ),
        );
      }
      throw const FormatException('服务端返回了歧义的登录结果');
    });
  }

  @override
  Future<CloudSyncDevicePairingCreated> createDevicePairing({
    required CloudSyncOnboardingToken token,
    required String pairingId,
    required Uint8List pairingSecretHash,
  }) {
    _requireClientIdentifier(pairingId);
    final encodedSecretHash = _encodeFixedBinaryForRequest(
      pairingSecretHash,
      cloudSyncPairingSecretHashBytes,
    );

    return _guard(() async {
      final request = api.DevicePairingCreateRequest(
        (builder) => builder
          ..protocolVersion = cloudSyncOpaqueProtocolVersion
          ..pairingId = pairingId
          ..pairingSecretHash = encodedSecretHash,
      );
      final response = await _client.getAuthApi().createDevicePairing(
        devicePairingCreateRequest: request,
        headers: _authorizationHeaders(token.value),
      );
      final data = _requireResponseData(response.data?.data);
      _requireProtocolVersion(data.protocolVersion);
      return CloudSyncDevicePairingCreated(
        pairingId: data.pairingId,
        accountContextId: data.accountContextId,
        challenge: _decodeFixedBinaryFromResponse(
          data.challenge,
          cloudSyncDeviceChallengeBytes,
        ),
        expiresAt: data.expiresAt,
        targetDevice: _pairingTarget(data.targetDevice),
      );
    });
  }

  @override
  Future<CloudSyncDevicePairingQueryResult> queryDevicePairing({
    required CloudSyncOnboardingToken token,
    required String pairingId,
  }) {
    _requireClientIdentifier(pairingId);

    return _guard(() async {
      final request = api.DevicePairingQueryRequest(
        (builder) => builder
          ..protocolVersion = cloudSyncOpaqueProtocolVersion
          ..pairingId = pairingId,
      );
      final response = await _client.getAuthApi().queryDevicePairing(
        devicePairingQueryRequest: request,
        headers: _authorizationHeaders(token.value),
      );
      final value = _requireResponseData(response.data?.data).oneOf.value;
      if (value is api.DevicePairingQueryDataOneOf) {
        _requireProtocolVersion(value.protocolVersion);
        if (value.status.name != 'pending') {
          throw const FormatException('服务端返回了未知的配对状态');
        }
        return CloudSyncDevicePairingPending(
          pairingId: value.pairingId,
          accountContextId: value.accountContextId,
          challenge: _decodeFixedBinaryFromResponse(
            value.challenge,
            cloudSyncDeviceChallengeBytes,
          ),
          expiresAt: value.expiresAt,
          targetDevice: _pairingTarget(value.targetDevice),
        );
      }
      if (value is api.DevicePairingQueryDataOneOf1) {
        _requireProtocolVersion(value.protocolVersion);
        if (value.status.name != 'approved') {
          throw const FormatException('服务端返回了未知的配对状态');
        }
        return CloudSyncDevicePairingApproved(
          pairingId: value.pairingId,
          accountContextId: value.accountContextId,
          challenge: _decodeFixedBinaryFromResponse(
            value.challenge,
            cloudSyncDeviceChallengeBytes,
          ),
          expiresAt: value.expiresAt,
          targetDevice: _pairingTarget(value.targetDevice),
          issuerDeviceId: value.issuerDeviceId,
          issuerSigningPublicKey: _decodeFixedBinaryFromResponse(
            value.issuerSigningPublicKey,
            cloudSyncDevicePublicKeyBytes,
          ),
          issuerKeyAgreementPublicKey: _decodeFixedBinaryFromResponse(
            value.issuerKeyAgreementPublicKey,
            cloudSyncDevicePublicKeyBytes,
          ),
          keyEpoch: value.keyEpoch,
          accountKeyEnvelope: _decodeFixedBinaryFromResponse(
            value.accountKeyEnvelope,
            cloudSyncAccountKeyEnvelopeBytes,
          ),
          deviceProof: _decodeFixedBinaryFromResponse(
            value.deviceProof,
            cloudSyncDeviceProofBytes,
          ),
          pairingAuthenticator: _decodeFixedBinaryFromResponse(
            value.pairingAuthenticator,
            cloudSyncPairingAuthenticatorBytes,
          ),
        );
      }
      throw const FormatException('服务端返回了歧义的配对状态');
    });
  }

  @override
  Future<CloudSyncDevicePairingApproval> approveDevicePairing({
    required CloudSyncFullSessionToken token,
    required String pairingId,
    required int keyEpoch,
    required Uint8List accountKeyEnvelope,
    required Uint8List deviceProof,
    required Uint8List pairingAuthenticator,
  }) {
    _requireClientIdentifier(pairingId);
    _requireClientKeyEpoch(keyEpoch);
    final encodedAccountKeyEnvelope = _encodeFixedBinaryForRequest(
      accountKeyEnvelope,
      cloudSyncAccountKeyEnvelopeBytes,
    );
    final encodedDeviceProof = _encodeFixedBinaryForRequest(
      deviceProof,
      cloudSyncDeviceProofBytes,
    );
    final encodedPairingAuthenticator = _encodeFixedBinaryForRequest(
      pairingAuthenticator,
      cloudSyncPairingAuthenticatorBytes,
    );

    return _guard(() async {
      final request = api.DevicePairingApproveRequest(
        (builder) => builder
          ..protocolVersion = cloudSyncOpaqueProtocolVersion
          ..pairingId = pairingId
          ..keyEpoch = keyEpoch
          ..accountKeyEnvelope = encodedAccountKeyEnvelope
          ..deviceProof = encodedDeviceProof
          ..pairingAuthenticator = encodedPairingAuthenticator,
      );
      final response = await _client.getAuthApi().approveDevicePairing(
        devicePairingApproveRequest: request,
        headers: _authorizationHeaders(token.value),
      );
      final data = _requireResponseData(response.data?.data);
      _requireProtocolVersion(data.protocolVersion);
      if (data.result.name != 'approved') {
        throw const FormatException('服务端返回了未知的配对批准结果');
      }
      return CloudSyncDevicePairingApproval(
        pairingId: data.pairingId,
        approvedAt: data.approvedAt,
      );
    });
  }

  @override
  Future<CloudSyncAuthenticatedSession> consumeDevicePairing({
    required CloudSyncOnboardingToken token,
    required String pairingId,
  }) {
    _requireClientIdentifier(pairingId);

    return _guard(() async {
      final request = api.DevicePairingConsumeRequest(
        (builder) => builder
          ..protocolVersion = cloudSyncOpaqueProtocolVersion
          ..pairingId = pairingId,
      );
      final response = await _client.getAuthApi().consumeDevicePairing(
        devicePairingConsumeRequest: request,
        headers: _authorizationHeaders(token.value),
      );
      final data = _requireResponseData(response.data?.data);
      _requireProtocolVersion(data.protocolVersion);
      if (data.result.name != 'authenticated') {
        throw const FormatException('服务端返回了未知的配对消费结果');
      }
      return _authenticatedSessionFromPairing(data);
    });
  }

  @override
  Future<CloudSyncDevicePairingCancellation> cancelDevicePairing({
    required CloudSyncOnboardingToken token,
    required String pairingId,
  }) {
    _requireClientIdentifier(pairingId);

    return _guard(() async {
      final request = api.DevicePairingCancelRequest(
        (builder) => builder
          ..protocolVersion = cloudSyncOpaqueProtocolVersion
          ..pairingId = pairingId,
      );
      final response = await _client.getAuthApi().cancelDevicePairing(
        devicePairingCancelRequest: request,
        headers: _authorizationHeaders(token.value),
      );
      final data = _requireResponseData(response.data?.data);
      _requireProtocolVersion(data.protocolVersion);
      if (data.result.name != 'cancelled') {
        throw const FormatException('服务端返回了未知的配对取消结果');
      }
      return CloudSyncDevicePairingCancellation(
        pairingId: data.pairingId,
        cancelledAt: data.cancelledAt,
      );
    });
  }

  @override
  Future<List<CloudSyncRecordMutationResult>> pushRecords(
    List<CloudSyncRecordMutation> mutations,
  ) {
    _validatePushMutations(mutations);
    return _pushValidatedRecords(mutations, token: _requireFullSessionToken());
  }

  Future<List<CloudSyncRecordMutationResult>> pushRecordsWithToken(
    List<CloudSyncRecordMutation> mutations, {
    required CloudSyncFullSessionToken token,
  }) {
    _validatePushMutations(mutations);
    return _pushValidatedRecords(mutations, token: token);
  }

  Future<List<CloudSyncRecordMutationResult>> _pushValidatedRecords(
    List<CloudSyncRecordMutation> mutations, {
    required CloudSyncFullSessionToken token,
  }) {
    final requestedMutationIds = <String>{
      for (final mutation in mutations) mutation.mutationId,
    };

    return _guard(() async {
      final request = api.SyncPushRequest(
        (builder) =>
            builder.mutations.addAll(mutations.map(_toGeneratedMutation)),
      );
      final response = await _client.getSyncApi().pushEncryptedSyncRecords(
        xKelivoSyncProtocolVersion: _syncProtocolVersion,
        syncPushRequest: request,
        headers: _authorizationHeaders(token.value),
      );
      final data = _requireResponseData(response.data?.data);
      final results = data.results
          .map(_fromMutationResult)
          .toList(growable: false);
      _validateMutationResults(results, requestedMutationIds);
      return List<CloudSyncRecordMutationResult>.unmodifiable(results);
    });
  }

  @override
  Future<CloudSyncChangePage> pullChanges({String? cursor, int limit = 10}) {
    _validatePullArguments(cursor: cursor, limit: limit);

    return _guard(() async {
      final request = api.SyncPullRequest((builder) {
        builder.limit = limit;
        if (cursor != null) {
          builder.cursor = cursor;
        }
      });
      final response = await _client.getSyncApi().pullEncryptedSyncChanges(
        xKelivoSyncProtocolVersion: _syncProtocolVersion,
        syncPullRequest: request,
        headers: _requireFullSessionHeaders(),
      );
      final data = _requireResponseData(response.data?.data);
      _validateChangePage(
        changeCount: data.changes.length,
        pageLimit: limit,
        nextCursor: data.nextCursor,
        hasMore: data.hasMore,
        resetRequired: data.resetRequired,
      );
      final changes = data.changes
          .map(_fromRecordChange)
          .toList(growable: false);
      _validateChangeOrdering(changes);
      return CloudSyncChangePage(
        changes: List<CloudSyncRecordChange>.unmodifiable(changes),
        nextCursor: data.nextCursor,
        hasMore: data.hasMore,
        resetRequired: data.resetRequired,
      );
    });
  }

  @override
  Future<CloudSyncSnapshotPage> pullSnapshot({
    String? snapshotCursor,
    int limit = 10,
  }) {
    _validatePullArguments(cursor: snapshotCursor, limit: limit);

    return _guard(() async {
      final request = api.SyncSnapshotRequest((builder) {
        builder.limit = limit;
        if (snapshotCursor != null) {
          builder.snapshotCursor = snapshotCursor;
        }
      });
      final response = await _client.getSyncApi().pullEncryptedSyncSnapshot(
        xKelivoSyncProtocolVersion: _syncProtocolVersion,
        syncSnapshotRequest: request,
        headers: _requireFullSessionHeaders(),
      );
      final data = _requireResponseData(response.data?.data);
      _validateSnapshotPage(
        recordCount: data.records.length,
        pageLimit: limit,
        nextSnapshotCursor: data.nextSnapshotCursor,
        syncCursor: data.syncCursor,
        hasMore: data.hasMore,
      );
      final records = data.records
          .map(_fromRecordState)
          .toList(growable: false);
      return CloudSyncSnapshotPage(
        records: List<CloudSyncRecordState>.unmodifiable(records),
        nextSnapshotCursor: data.nextSnapshotCursor,
        syncCursor: data.syncCursor,
        hasMore: data.hasMore,
      );
    });
  }

  @override
  Future<CloudSyncPage<CloudSyncDeviceSession>> listDevices({
    CloudSyncDeviceStatus? status,
    int pageIndex = 1,
    int pageSize = 50,
  }) {
    if (pageIndex < 1 || pageSize < 1 || pageSize > 100) {
      throw const CloudSyncException(
        kind: CloudSyncFailureKind.validation,
        retryable: false,
      );
    }
    return _guard(() async {
      final request = api.ListTrustedDevicesRequest((builder) {
        builder
          ..pageIndex = pageIndex
          ..pageSize = pageSize;
        if (status != null) {
          builder.status = _toDeviceFilterStatus(status);
        }
      });
      final response = await _client.getDeviceApi().listTrustedDevices(
        listTrustedDevicesRequest: request,
        headers: _requireFullSessionHeaders(),
      );
      final data = _requireResponseData(response.data?.data);
      return CloudSyncPage<CloudSyncDeviceSession>(
        items: List<CloudSyncDeviceSession>.unmodifiable(
          data.items.map(_fromDevice),
        ),
        total: data.total,
        pageIndex: data.pageIndex,
        pageSize: data.pageSize,
      );
    });
  }

  @override
  Future<CloudSyncDeviceSession> revokeDevice(String deviceId) {
    _requireClientIdentifier(deviceId);
    return _guard(() async {
      final request = api.RevokeTrustedDeviceRequest(
        (builder) => builder.deviceId = deviceId,
      );
      final response = await _client.getDeviceApi().revokeTrustedDevice(
        revokeTrustedDeviceRequest: request,
        headers: _requireFullSessionHeaders(),
      );
      return _fromDevice(_requireResponseData(response.data?.data).device);
    });
  }

  Map<String, String> _requireFullSessionHeaders() {
    return _authorizationHeaders(_requireFullSessionToken().value);
  }

  CloudSyncFullSessionToken _requireFullSessionToken() {
    final token = _sessionToken;
    if (token == null) {
      throw const CloudSyncException(
        kind: CloudSyncFailureKind.unauthenticated,
        retryable: false,
      );
    }
    return token;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on CloudSyncException {
      rethrow;
    } on DioException catch (error) {
      throw _fromDioException(error);
    } on FormatException {
      throw const CloudSyncException(
        kind: CloudSyncFailureKind.invalidResponse,
        retryable: false,
      );
    }
  }
}

api.SyncMutation _toGeneratedMutation(CloudSyncRecordMutation mutation) {
  return switch (mutation) {
    CloudSyncPutRecordMutation() => _toGeneratedPutMutation(mutation),
  };
}

api.SyncMutation _toGeneratedPutMutation(CloudSyncPutRecordMutation mutation) {
  final record = mutation.state.record;
  final value = api.SyncPutMutation(
    (builder) => builder
      ..mutationId = mutation.mutationId
      ..recordId = mutation.recordId.wireValue
      ..expectedRevision = mutation.expectedRevision
      ..operation = api.SyncPutMutationOperationEnum.put
      ..envelopeVersion = e2eeAccountRecordEnvelopeVersion
      ..keyEpoch = record.keyEpoch
      ..ciphertext = _encodeSyncCiphertext(record.ciphertext),
  );
  return api.SyncMutation(
    (builder) =>
        builder.oneOf = OneOf2<api.SyncDeleteMutation, api.SyncPutMutation>(
          value: value,
          typeIndex: 1,
        ),
  );
}

CloudSyncRecordMutationResult _fromMutationResult(
  api.SyncMutationResult result,
) {
  final value = result.oneOf.value;
  if (value is api.SyncAppliedMutationResult) {
    _requireServerIdentifier(value.mutationId);
    if (value.revision < 1 || value.changeSeq < 0) {
      throw const FormatException('服务端返回了无效的 applied 结果');
    }
    return CloudSyncAppliedMutationResult(
      mutationId: value.mutationId,
      revision: value.revision,
      changeSeq: value.changeSeq,
    );
  }
  if (value is api.SyncConflictMutationResult) {
    _requireServerIdentifier(value.mutationId);
    final currentRevision = value.currentRevision;
    if (currentRevision != null && currentRevision < 1) {
      throw const FormatException('服务端返回了无效的 conflict 结果');
    }
    return CloudSyncConflictMutationResult(
      mutationId: value.mutationId,
      currentRevision: currentRevision,
    );
  }
  if (value is api.SyncRejectedMutationResult) {
    _requireServerIdentifier(value.mutationId);
    if (value.errorCode.isEmpty || value.errorCode.length > 100) {
      throw const FormatException('服务端返回了无效的 rejected 结果');
    }
    return CloudSyncRejectedMutationResult(
      mutationId: value.mutationId,
      errorCode: value.errorCode,
    );
  }
  throw const FormatException('服务端返回了未知的 mutation 结果');
}

CloudSyncRecordChange _fromRecordChange(api.SyncChange change) {
  final value = change.oneOf.value;
  if (value is api.SyncPutChange) {
    _validateRecordMetadata(
      recordId: value.recordId,
      revision: value.revision,
      sequence: value.changeSeq,
      updatedByDeviceId: value.updatedByDeviceId,
    );
    if (value.envelopeVersion != e2eeAccountRecordEnvelopeVersion ||
        value.keyEpoch < 1 ||
        value.keyEpoch > 2147483647 ||
        value.ciphertextBytes < 1 ||
        value.ciphertextBytes > e2eeAccountRecordMaxCiphertextBytes ||
        _syncCiphertextByteLength(value.ciphertext) != value.ciphertextBytes ||
        value.deletedAt != null) {
      throw const FormatException('服务端返回了无效的 put 增量');
    }
    final ciphertext = _decodeSyncCiphertext(
      value.ciphertext,
      value.ciphertextBytes,
    );
    return CloudSyncPutRecordChange(
      changeSeq: value.changeSeq,
      revision: value.revision,
      updatedAt: value.updatedAt.toUtc(),
      updatedByDeviceId: value.updatedByDeviceId,
      record: E2eeUntrustedAccountRecordEnvelope.fromTransport(
        recordId: E2eeUntrustedAccountRecordId.fromTransport(value.recordId),
        envelopeVersion: value.envelopeVersion,
        keyEpoch: value.keyEpoch,
        ciphertext: ciphertext,
      ),
    );
  }
  if (value is api.SyncDeleteChange) {
    throw const FormatException('服务端返回了不受信任的 delete 增量');
  }
  throw const FormatException('服务端返回了未知的同步增量');
}

CloudSyncRecordState _fromRecordState(api.SyncRecord record) {
  final values = record.anyOf.values.values.whereType<Object>().toList(
    growable: false,
  );
  if (values.length != 1) {
    throw const FormatException('服务端返回了歧义的同步记录');
  }
  final value = values.single;
  if (value is api.SyncActiveRecord) {
    _validateRecordMetadata(
      recordId: value.recordId,
      revision: value.revision,
      sequence: value.lastChangeSeq,
      updatedByDeviceId: value.updatedByDeviceId,
    );
    if (value.envelopeVersion != e2eeAccountRecordEnvelopeVersion ||
        value.keyEpoch < 1 ||
        value.keyEpoch > 2147483647 ||
        value.ciphertextBytes < 1 ||
        value.ciphertextBytes > e2eeAccountRecordMaxCiphertextBytes ||
        _syncCiphertextByteLength(value.ciphertext) != value.ciphertextBytes ||
        value.deletedAt != null) {
      throw const FormatException('服务端返回了无效的 active 记录');
    }
    final ciphertext = _decodeSyncCiphertext(
      value.ciphertext,
      value.ciphertextBytes,
    );
    return CloudSyncActiveRecord(
      revision: value.revision,
      updatedAt: value.updatedAt.toUtc(),
      updatedByDeviceId: value.updatedByDeviceId,
      lastChangeSeq: value.lastChangeSeq,
      record: E2eeUntrustedAccountRecordEnvelope.fromTransport(
        recordId: E2eeUntrustedAccountRecordId.fromTransport(value.recordId),
        envelopeVersion: value.envelopeVersion,
        keyEpoch: value.keyEpoch,
        ciphertext: ciphertext,
      ),
    );
  }
  if (value is api.SyncDeletedRecord) {
    throw const FormatException('服务端返回了不受信任的 deleted 记录');
  }
  throw const FormatException('服务端返回了未知的同步记录');
}

void _validatePushMutations(List<CloudSyncRecordMutation> mutations) {
  if (mutations.isEmpty || mutations.length > 10) {
    throw const CloudSyncException(
      kind: CloudSyncFailureKind.validation,
      retryable: false,
    );
  }

  final mutationIds = <String>{};
  var totalCiphertextBytes = 0;
  for (final mutation in mutations) {
    _requireClientIdentifier(mutation.mutationId);
    _requireClientIdentifier(mutation.recordId.wireValue);
    if (!mutationIds.add(mutation.mutationId) ||
        mutation.expectedRevision < 0) {
      throw const CloudSyncException(
        kind: CloudSyncFailureKind.validation,
        retryable: false,
      );
    }
    switch (mutation) {
      case CloudSyncPutRecordMutation():
        final record = mutation.state.record;
        if (record.keyEpoch < 1 || record.keyEpoch > 2147483647) {
          throw const CloudSyncException(
            kind: CloudSyncFailureKind.validation,
            retryable: false,
          );
        }
        final ciphertextBytes = record.ciphertext.length;
        if (ciphertextBytes < 1 ||
            ciphertextBytes > e2eeAccountRecordMaxCiphertextBytes) {
          throw const CloudSyncException(
            kind: CloudSyncFailureKind.validation,
            retryable: false,
          );
        }
        totalCiphertextBytes += ciphertextBytes;
    }
  }
  if (totalCiphertextBytes > 1048576) {
    throw const CloudSyncException(
      kind: CloudSyncFailureKind.validation,
      retryable: false,
    );
  }
}

void _validateMutationResults(
  List<CloudSyncRecordMutationResult> results,
  Set<String> requestedMutationIds,
) {
  if (results.length != requestedMutationIds.length) {
    throw const FormatException('服务端返回的 mutation 结果数量不匹配');
  }
  final resultIds = <String>{};
  for (final result in results) {
    if (!requestedMutationIds.contains(result.mutationId) ||
        !resultIds.add(result.mutationId)) {
      throw const FormatException('服务端返回了未知或重复的 mutation 结果');
    }
  }
}

void _validatePullArguments({required String? cursor, required int limit}) {
  if (limit < 1 ||
      limit > 10 ||
      (cursor != null && !_isValidSyncCursor(cursor))) {
    throw const CloudSyncException(
      kind: CloudSyncFailureKind.validation,
      retryable: false,
    );
  }
}

void _validateRecordMetadata({
  required String recordId,
  required int revision,
  required int sequence,
  required String? updatedByDeviceId,
}) {
  _requireServerIdentifier(recordId);
  if (updatedByDeviceId != null) {
    _requireServerIdentifier(updatedByDeviceId);
  }
  if (revision < 1 || sequence < 0) {
    throw const FormatException('服务端返回了无效的记录元数据');
  }
}

bool _isValidSyncCursor(String value) {
  return value.isNotEmpty && value.length <= 4096;
}

void _validateChangePage({
  required int changeCount,
  required int pageLimit,
  required String nextCursor,
  required bool hasMore,
  required bool resetRequired,
}) {
  final resetStateIsValid = !resetRequired || (changeCount == 0 && !hasMore);
  if (changeCount > pageLimit ||
      !_isValidSyncCursor(nextCursor) ||
      (hasMore && changeCount == 0) ||
      !resetStateIsValid) {
    throw const FormatException('服务端返回了无效的增量分页数据');
  }
}

void _validateChangeOrdering(List<CloudSyncRecordChange> changes) {
  int? previousSequence;
  for (final change in changes) {
    final previous = previousSequence;
    if (previous != null && change.changeSeq <= previous) {
      throw const FormatException('服务端返回了乱序的同步增量');
    }
    previousSequence = change.changeSeq;
  }
}

void _validateSnapshotPage({
  required int recordCount,
  required int pageLimit,
  required String? nextSnapshotCursor,
  required String? syncCursor,
  required bool hasMore,
}) {
  final nextCursorIsValid =
      nextSnapshotCursor == null || _isValidSyncCursor(nextSnapshotCursor);
  final syncCursorIsValid =
      syncCursor == null || _isValidSyncCursor(syncCursor);
  final cursorsMatchPageState = hasMore
      ? nextSnapshotCursor != null && syncCursor == null
      : nextSnapshotCursor == null && syncCursor != null;
  if (recordCount > pageLimit ||
      (hasMore && recordCount == 0) ||
      !nextCursorIsValid ||
      !syncCursorIsValid ||
      !cursorsMatchPageState) {
    throw const FormatException('服务端返回了无效的快照分页数据');
  }
}

String _encodeSyncCiphertext(Uint8List ciphertext) =>
    base64Url.encode(ciphertext).replaceAll('=', '');

Uint8List _decodeSyncCiphertext(String ciphertext, int expectedLength) {
  try {
    final padding = '=' * ((4 - ciphertext.length % 4) % 4);
    final decoded = base64Url.decode('$ciphertext$padding');
    if (decoded.length != expectedLength) {
      throw const FormatException('服务端返回了长度不匹配的同步密文');
    }
    return decoded;
  } on FormatException {
    throw const FormatException('服务端返回了无效的同步密文');
  }
}

int? _syncCiphertextByteLength(String ciphertext) {
  if (ciphertext.isEmpty ||
      ciphertext.length > 1398102 ||
      !_base64UrlPattern.hasMatch(ciphertext)) {
    return null;
  }
  final remainder = ciphertext.length % 4;
  if (remainder == 1) return null;
  final lastCharacter = ciphertext[ciphertext.length - 1];
  if ((remainder == 2 && !_base64UrlRemainder2.contains(lastCharacter)) ||
      (remainder == 3 && !_base64UrlRemainder3.contains(lastCharacter))) {
    return null;
  }
  return (ciphertext.length ~/ 4) * 3 +
      (remainder == 2 ? 1 : (remainder == 3 ? 2 : 0));
}

void _requireClientIdentifier(String value) {
  if (!_syncIdentifierPattern.hasMatch(value)) {
    throw const CloudSyncException(
      kind: CloudSyncFailureKind.validation,
      retryable: false,
    );
  }
}

void _requireServerIdentifier(String value) {
  if (!_syncIdentifierPattern.hasMatch(value)) {
    throw const FormatException('服务端返回了无效的同步标识符');
  }
}

CloudSyncAuthenticatedSession _authenticatedSessionFromRegistration(
  api.OpaqueRegistrationFinishData data,
) {
  return _authenticatedSession(
    token: data.token,
    tokenExpiresAt: data.tokenExpiresAt,
    keyEpoch: data.keyEpoch,
    userId: data.user.id,
    loginName: data.user.loginName,
    displayName: data.user.displayName,
    role: data.user.role.name,
    attachmentQuotaBytes: data.user.attachmentQuotaBytes,
    deviceId: data.device.id,
    deviceName: data.device.name,
    platform: data.device.platform.name,
    clientVersion: data.device.clientVersion,
    deviceStatus: data.device.status.name,
    deviceCreatedAt: data.device.createdAt,
  );
}

CloudSyncAuthenticatedSession _authenticatedSessionFromLogin(
  api.OpaqueLoginFinishDataOneOf data,
) {
  return _authenticatedSession(
    token: data.token,
    tokenExpiresAt: data.tokenExpiresAt,
    keyEpoch: data.keyEpoch,
    userId: data.user.id,
    loginName: data.user.loginName,
    displayName: data.user.displayName,
    role: data.user.role.name,
    attachmentQuotaBytes: data.user.attachmentQuotaBytes,
    deviceId: data.device.id,
    deviceName: data.device.name,
    platform: data.device.platform.name,
    clientVersion: data.device.clientVersion,
    deviceStatus: data.device.status.name,
    deviceCreatedAt: data.device.createdAt,
  );
}

CloudSyncAuthenticatedSession _authenticatedSessionFromPairing(
  api.DevicePairingConsumeData data,
) {
  return _authenticatedSession(
    token: data.token,
    tokenExpiresAt: data.tokenExpiresAt,
    keyEpoch: data.keyEpoch,
    userId: data.user.id,
    loginName: data.user.loginName,
    displayName: data.user.displayName,
    role: data.user.role.name,
    attachmentQuotaBytes: data.user.attachmentQuotaBytes,
    deviceId: data.device.id,
    deviceName: data.device.name,
    platform: data.device.platform.name,
    clientVersion: data.device.clientVersion,
    deviceStatus: data.device.status.name,
    deviceCreatedAt: data.device.createdAt,
  );
}

CloudSyncAuthenticatedSession _authenticatedSession({
  required String token,
  required DateTime tokenExpiresAt,
  required int keyEpoch,
  required String userId,
  required String loginName,
  required String displayName,
  required String role,
  required int attachmentQuotaBytes,
  required String deviceId,
  required String deviceName,
  required String platform,
  required String clientVersion,
  required String deviceStatus,
  required DateTime deviceCreatedAt,
}) {
  return CloudSyncAuthenticatedSession(
    token: CloudSyncFullSessionToken.parse(token),
    tokenExpiresAt: tokenExpiresAt,
    keyEpoch: keyEpoch,
    user: CloudSyncAuthenticatedUser(
      id: userId,
      loginName: loginName,
      displayName: displayName,
      role: _fromUserRoleName(role),
      attachmentQuotaBytes: attachmentQuotaBytes,
    ),
    device: _authenticatedDevice(
      id: deviceId,
      name: deviceName,
      platform: platform,
      clientVersion: clientVersion,
      status: deviceStatus,
      createdAt: deviceCreatedAt,
    ),
  );
}

CloudSyncAuthenticatedDevice _authenticatedDevice({
  required String id,
  required String name,
  required String platform,
  required String clientVersion,
  required String status,
  required DateTime createdAt,
}) {
  return CloudSyncAuthenticatedDevice(
    id: id,
    name: name,
    platform: _fromPlatformName(platform),
    clientVersion: clientVersion,
    status: switch (status) {
      'pending' => CloudSyncAuthenticatedDeviceStatus.pending,
      'active' => CloudSyncAuthenticatedDeviceStatus.active,
      _ => throw const FormatException('服务端返回了未知认证设备状态'),
    },
    createdAt: createdAt,
  );
}

CloudSyncDevicePairingTarget _pairingTarget(
  api.DevicePairingCreateDataTargetDevice target,
) {
  return CloudSyncDevicePairingTarget(
    id: target.id,
    name: target.name,
    platform: _fromPlatformName(target.platform.name),
    clientVersion: target.clientVersion,
    keyVersion: target.keyVersion,
    authGeneration: target.authGeneration,
    signingPublicKey: _decodeFixedBinaryFromResponse(
      target.signingPublicKey,
      cloudSyncDevicePublicKeyBytes,
    ),
    keyAgreementPublicKey: _decodeFixedBinaryFromResponse(
      target.keyAgreementPublicKey,
      cloudSyncDevicePublicKeyBytes,
    ),
  );
}

CloudSyncDeviceSession _fromDevice(api.TrustedDeviceSummary device) {
  _requireServerIdentifier(device.id);
  return CloudSyncDeviceSession(
    id: device.id,
    name: device.name,
    platform: _fromPlatformName(device.platform.name),
    clientVersion: device.clientVersion,
    status: switch (device.status.name) {
      'active' => CloudSyncDeviceStatus.active,
      'revoked' => CloudSyncDeviceStatus.revoked,
      _ => throw const FormatException('服务端返回了未知设备状态'),
    },
    createdAt: device.createdAt.toUtc(),
    lastSeenAt: device.lastSeenAt?.toUtc(),
    revokedAt: device.revokedAt?.toUtc(),
    isCurrent: device.isCurrent,
  );
}

api.OpaqueRegistrationStartRequestPlatformEnum _toRegistrationPlatform(
  CloudSyncPlatform platform,
) {
  return switch (platform) {
    CloudSyncPlatform.android =>
      api.OpaqueRegistrationStartRequestPlatformEnum.android,
    CloudSyncPlatform.ios => api.OpaqueRegistrationStartRequestPlatformEnum.ios,
    CloudSyncPlatform.macos =>
      api.OpaqueRegistrationStartRequestPlatformEnum.macos,
    CloudSyncPlatform.windows =>
      api.OpaqueRegistrationStartRequestPlatformEnum.windows,
    CloudSyncPlatform.linux =>
      api.OpaqueRegistrationStartRequestPlatformEnum.linux,
  };
}

api.OpaqueLoginStartRequestPlatformEnum _toLoginPlatform(
  CloudSyncPlatform platform,
) {
  return switch (platform) {
    CloudSyncPlatform.android =>
      api.OpaqueLoginStartRequestPlatformEnum.android,
    CloudSyncPlatform.ios => api.OpaqueLoginStartRequestPlatformEnum.ios,
    CloudSyncPlatform.macos => api.OpaqueLoginStartRequestPlatformEnum.macos,
    CloudSyncPlatform.windows =>
      api.OpaqueLoginStartRequestPlatformEnum.windows,
    CloudSyncPlatform.linux => api.OpaqueLoginStartRequestPlatformEnum.linux,
  };
}

CloudSyncPlatform _fromPlatformName(String value) {
  return switch (value) {
    'android' => CloudSyncPlatform.android,
    'ios' => CloudSyncPlatform.ios,
    'macos' => CloudSyncPlatform.macos,
    'windows' => CloudSyncPlatform.windows,
    'linux' => CloudSyncPlatform.linux,
    _ => throw const FormatException('服务端返回了未知平台'),
  };
}

CloudSyncUserRole _fromUserRoleName(String value) {
  return switch (value) {
    'owner' => CloudSyncUserRole.owner,
    'admin' => CloudSyncUserRole.admin,
    'user' => CloudSyncUserRole.user,
    _ => throw const FormatException('服务端返回了未知用户角色'),
  };
}

api.ListTrustedDevicesRequestStatusEnum _toDeviceFilterStatus(
  CloudSyncDeviceStatus status,
) {
  return switch (status) {
    CloudSyncDeviceStatus.active =>
      api.ListTrustedDevicesRequestStatusEnum.active,
    CloudSyncDeviceStatus.revoked =>
      api.ListTrustedDevicesRequestStatusEnum.revoked,
  };
}

Map<String, String> _authorizationHeaders(String token) {
  return <String, String>{'authorization': 'Bearer $token'};
}

void _requireProtocolVersion(int value) {
  if (value != cloudSyncOpaqueProtocolVersion) {
    throw const FormatException('服务端返回了不支持的认证协议版本');
  }
}

String _normalizeLoginNameForRequest(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.length < 3 ||
      normalized.length > 64 ||
      !_opaqueLoginNamePattern.hasMatch(normalized)) {
    throw const CloudSyncException(
      kind: CloudSyncFailureKind.validation,
      retryable: false,
    );
  }
  return normalized;
}

String _normalizeTextForRequest(String value, {required int maximumLength}) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > maximumLength) {
    throw const CloudSyncException(
      kind: CloudSyncFailureKind.validation,
      retryable: false,
    );
  }
  return normalized;
}

void _requireClientKeyEpoch(int value) {
  if (value < 1 || value > 0xffffffff) {
    throw const CloudSyncException(
      kind: CloudSyncFailureKind.validation,
      retryable: false,
    );
  }
}

String _encodeFixedBinaryForRequest(Uint8List value, int expectedBytes) {
  if (value.length != expectedBytes) {
    throw const CloudSyncException(
      kind: CloudSyncFailureKind.validation,
      retryable: false,
    );
  }
  return base64Url.encode(value).replaceAll('=', '');
}

Uint8List _decodeFixedBinaryFromResponse(String value, int expectedBytes) {
  final expectedEncodedLength = (expectedBytes * 8 + 5) ~/ 6;
  if (value.length != expectedEncodedLength ||
      !_base64UrlPattern.hasMatch(value)) {
    throw const FormatException('服务端返回了无效的二进制字段');
  }

  try {
    final padding = '=' * ((4 - value.length % 4) % 4);
    final decoded = base64Url.decode('$value$padding');
    final canonical = base64Url.encode(decoded).replaceAll('=', '');
    if (decoded.length != expectedBytes || canonical != value) {
      throw const FormatException('服务端返回了非规范二进制字段');
    }
    return Uint8List.fromList(decoded).asUnmodifiableView();
  } on FormatException {
    throw const FormatException('服务端返回了无效的二进制字段');
  }
}

T _requireResponseData<T>(T? data) {
  if (data == null) {
    throw const CloudSyncException(
      kind: CloudSyncFailureKind.invalidResponse,
      retryable: false,
    );
  }
  return data;
}

CloudSyncException _fromDioException(DioException error) {
  final statusCode = error.response?.statusCode;
  final serverError = _parseServerError(error.response?.data);
  // generated 客户端将 2xx 响应反序列化失败包装成 unknown DioException。
  final responseDeserializationFailed =
      error.type == DioExceptionType.unknown &&
      statusCode != null &&
      statusCode >= 200 &&
      statusCode < 300 &&
      error.error != null;
  final responseConnectionInterrupted =
      error.type == DioExceptionType.unknown &&
      statusCode == null &&
      (error.error is SocketException || error.error is HttpException);
  final kind = responseDeserializationFailed
      ? CloudSyncFailureKind.invalidResponse
      : responseConnectionInterrupted
      ? CloudSyncFailureKind.network
      : switch (error.type) {
          DioExceptionType.cancel => CloudSyncFailureKind.cancelled,
          DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout => CloudSyncFailureKind.timeout,
          DioExceptionType.connectionError ||
          DioExceptionType.badCertificate => CloudSyncFailureKind.network,
          _ => _failureKindFromStatus(statusCode),
        };
  final retryable =
      serverError?.retryable ??
      kind == CloudSyncFailureKind.network ||
          kind == CloudSyncFailureKind.timeout ||
          kind == CloudSyncFailureKind.rateLimited ||
          kind == CloudSyncFailureKind.server;
  return CloudSyncException(
    kind: kind,
    retryable: retryable,
    serverCode: serverError?.code,
    requestId: serverError?.requestId,
    statusCode: statusCode,
  );
}

CloudSyncFailureKind _failureKindFromStatus(int? statusCode) {
  if (statusCode == null) return CloudSyncFailureKind.unknown;
  return switch (statusCode) {
    400 || 422 => CloudSyncFailureKind.validation,
    401 => CloudSyncFailureKind.unauthenticated,
    403 => CloudSyncFailureKind.forbidden,
    404 => CloudSyncFailureKind.notFound,
    409 => CloudSyncFailureKind.conflict,
    429 => CloudSyncFailureKind.rateLimited,
    >= 500 => CloudSyncFailureKind.server,
    _ => CloudSyncFailureKind.invalidResponse,
  };
}

_ParsedServerError? _parseServerError(Object? raw) {
  try {
    final Object? decoded = raw is String ? jsonDecode(raw) : raw;
    final root = copyCloudSyncJsonMap(decoded);
    final error = copyCloudSyncJsonMap(root['error']);
    final code = error['code'];
    final retryable = error['retryable'];
    final requestId = root['requestId'];
    if (code is! String ||
        code.isEmpty ||
        retryable is! bool ||
        requestId is! String ||
        requestId.isEmpty) {
      return null;
    }
    return _ParsedServerError(
      code: code,
      retryable: retryable,
      requestId: requestId,
    );
  } on FormatException {
    return null;
  }
}

final _syncIdentifierPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final _opaqueLoginNamePattern = RegExp(r'^[a-z0-9][a-z0-9._-]*$');
final _base64UrlPattern = RegExp(r'^[A-Za-z0-9_-]+$');
const _base64UrlRemainder2 = 'AQgw';
const _base64UrlRemainder3 = 'AEIMQUYcgkosw048';

final class _ParsedServerError {
  const _ParsedServerError({
    required this.code,
    required this.retryable,
    required this.requestId,
  });

  final String code;
  final bool retryable;
  final String requestId;
}
