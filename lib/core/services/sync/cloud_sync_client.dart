import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:kelivo_sync_api_client/kelivo_sync_api_client.dart' as api;
import 'package:one_of/one_of.dart';

import 'cloud_sync_attachment_types.dart';
import 'cloud_sync_record_types.dart';
import 'cloud_sync_types.dart';
import 'e2ee_account_recovery.dart';
import 'e2ee_account_record_cipher.dart';

abstract interface class CloudSyncRecordTransport {
  Future<List<CloudSyncRecordMutationResult>> pushRecords(
    List<CloudSyncRecordMutation> mutations,
  );

  Future<CloudSyncPullResult> pullChanges({String? cursor, int limit = 10});

  Future<CloudSyncSnapshotPage> pullSnapshot({
    String? snapshotCursor,
    int limit = 10,
  });
}

abstract interface class CloudSyncAttachmentTransport {
  Future<CloudSyncAttachmentUpload> createAttachmentUpload({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentCreateUploadRequest request,
  });

  Future<CloudSyncAttachmentStoredChunk> putAttachmentChunk({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentPutChunkRequest request,
  });

  Future<CloudSyncAttachmentCommittedUpload> commitAttachmentUpload({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentCommitUploadRequest request,
  });

  Future<CloudSyncAttachmentManifest> getAttachmentManifest({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentIdentity identity,
  });

  Future<CloudSyncAttachmentChunk> getAttachmentChunk({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentChunkIdentity chunk,
  });

  Future<CloudSyncAttachmentDeleted> deleteAttachment({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentDeleteRequest request,
  });
}

abstract interface class CloudSyncDeviceRotationTransport {
  Future<CloudSyncDeviceRotationResult> commitDeviceRotation(
    CloudSyncDeviceRotationRequest request,
  );
}

abstract interface class CloudSyncAccountClient
    implements CloudSyncDeviceRotationTransport {
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
    required CloudSyncGenesisSecurityState securityState,
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
    required CloudSyncDevicePairingMembershipCommit membershipCommit,
    required Uint8List accountKeyEnvelope,
    required Uint8List deviceProof,
    required Uint8List pairingAuthenticator,
  });

  Future<CloudSyncAuthenticatedSession> consumeDevicePairing({
    required CloudSyncOnboardingToken token,
    required String pairingId,
    required CloudSyncFullSessionToken sessionToken,
  });

  Future<CloudSyncDevicePairingCancellation> cancelDevicePairing({
    required CloudSyncOnboardingToken token,
    required String pairingId,
  });

  Future<CloudSyncAccountSecurityState> getSecurityState();

  Future<CloudSyncAccountSecurityHistoryPage> listSecurityStateHistory({
    int afterGeneration = 0,
    int pageSize = 20,
  });

  Future<CloudSyncPage<CloudSyncDeviceSession>> listDevices({
    CloudSyncDeviceStatus? status,
    int pageIndex = 1,
    int pageSize = 50,
  });

  Future<CloudSyncDeviceSession> revokeDevice(String deviceId);
}

abstract interface class CloudSyncSessionTransport {
  Future<CloudSyncAuthenticatedSession> getAuthenticatedSession({
    required CloudSyncFullSessionToken token,
  });
}

abstract interface class CloudSyncSelfRevocationTransport {
  Future<CloudSyncSelfRevocationRequestResult> createSelfRevocationRequest(
    CloudSyncSelfRevocationRequest request,
  );

  Future<CloudSyncSelfRevocationStatus> getSelfRevocationStatus(
    CloudSyncSelfRevocationRequestResult request,
  );

  Future<CloudSyncSelfRevocationStatus> continueSelfRevocationStatus(
    CloudSyncSelfRevocationRequest request,
  );

  Future<CloudSyncSelfRevocationCancelled> cancelSelfRevocationRequest(
    CloudSyncSelfRevocationRequestResult request,
  );

  Future<CloudSyncUntrustedSelfRevocationRequestList>
  listSelfRevocationRequests();
}

abstract interface class CloudSyncDataRekeyStateTransport {
  Future<CloudSyncDataRekeyState> getDataRekeyState();
}

abstract interface class CloudSyncDataRekeyTransport
    implements CloudSyncDataRekeyStateTransport {
  Future<CloudSyncDataRekeyLeaseClaim> claimDataRekeyLease(
    CloudSyncDataRekeyLeaseClaimRequest request,
  );

  Future<CloudSyncDataRekeySourceRecordPage> listDataRekeySourceRecords(
    CloudSyncDataRekeySourceRecordListRequest request,
  );

  Future<CloudSyncDataRekeySourceAttachmentPage> listDataRekeySourceAttachments(
    CloudSyncDataRekeySourceAttachmentListRequest request,
  );

  Future<CloudSyncDataRekeyRecordStageResult> stageDataRekeyRecord(
    CloudSyncDataRekeyRecordStageRequest request,
  );

  Future<CloudSyncDataRekeyAttachmentStageResult> stageDataRekeyAttachment(
    CloudSyncDataRekeyAttachmentStageRequest request,
  );

  Future<CloudSyncDataRekeyFinalizeOutcome> finalizeDataRekey(
    CloudSyncDataRekeyFinalizeRequest request,
  );
}

final class CloudSyncClient
    implements
        CloudSyncAccountClient,
        CloudSyncAttachmentTransport,
        CloudSyncDataRekeyTransport,
        CloudSyncSelfRevocationTransport,
        CloudSyncSessionTransport,
        E2eeAccountRecoveryTransport,
        CloudSyncRecordTransport {
  CloudSyncClient._({
    required this.baseUrl,
    required this._dio,
    required this._client,
    required this._now,
    this._dataRekeyBearerOverride,
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
    DateTime Function()? now,
  }) {
    return CloudSyncClient._forBaseUrl(
      baseUrl: baseUrl,
      token: token,
      now: now,
    );
  }

  factory CloudSyncClient._forBaseUrl({
    required String baseUrl,
    CloudSyncFullSessionToken? token,
    DateTime Function()? now,
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
      now: now ?? DateTime.now,
      // 鉴权逐请求显式注入，避免并发请求共享可变拦截器令牌。
      client: api.KelivoSyncApiClient(
        dio: dio,
        interceptors: <Interceptor>[
          InterceptorsWrapper(
            onResponse: (response, handler) {
              if (response.requestOptions.extra[_strictResponseMarker] ==
                  true) {
                response.extra[_rawResponseKey] = response.data;
              }
              handler.next(response);
            },
          ),
        ],
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
  final DateTime Function() _now;
  final String? _dataRekeyBearerOverride;
  CloudSyncFullSessionToken? _sessionToken;

  @override
  void setToken(CloudSyncFullSessionToken? token) => _sessionToken = token;

  @override
  void close({bool force = false}) {
    _dio.close(force: force);
  }

  CloudSyncDataRekeyTransport accountRecoveryDataRekeyTransport(
    CloudSyncAccountRecoveryToken recoveryToken,
  ) {
    // 恢复令牌只绑定不可见代理，避免并发恢复期间污染完整会话令牌。
    return _CloudSyncAccountRecoveryDataRekeyTransport(this, recoveryToken);
  }

  @override
  Future<CloudSyncAuthenticatedSession> getAuthenticatedSession({
    required CloudSyncFullSessionToken token,
  }) {
    return _guard(() async {
      final response = await _client.getAuthApi().getAuthenticatedSession(
        headers: _authorizationHeaders(token.value),
        extra: _strictResponseExtra,
      );
      return _parseCurrentAuthenticatedSession(
        response.extra[_rawResponseKey],
        expectedToken: token,
      );
    });
  }

  @override
  Future<CloudSyncSelfRevocationRequestResult> createSelfRevocationRequest(
    CloudSyncSelfRevocationRequest request,
  ) {
    return _guard(() async {
      final generatedRequest = api.CreateSelfRevocationRequest(
        (builder) => builder
          ..mutationId = request.mutationId
          ..operationId = request.operationId
          ..expectedGeneration = request.expectedGeneration
          ..expectedKeyEpoch = request.expectedKeyEpoch
          ..expectedMembershipManifestDigest =
              request.expectedMembershipManifestDigest.encoded
          ..expiresAt = request.expiresAt
          ..continuationToken = request.continuationToken.value
          ..intentSignature = _encodeFixedBinaryForRequest(
            request.intentSignature,
            cloudSyncSelfRevocationIntentSignatureBytes,
          ),
      );
      final response = await _client.getDeviceApi().createSelfRevocationRequest(
        createSelfRevocationRequest: generatedRequest,
        headers: _requireFullSessionHeaders(),
        extra: _strictResponseExtra,
      );
      return CloudSyncSelfRevocationRequestResult.fromJson(
        _strictResponseData(
          response.extra[_rawResponseKey],
          _selfRevocationRequestResultDataKeys,
          '自撤销请求响应',
        ),
        request: request,
      );
    });
  }

  @override
  Future<CloudSyncSelfRevocationStatus> getSelfRevocationStatus(
    CloudSyncSelfRevocationRequestResult request,
  ) {
    return _guard(() async {
      final response = await _client.getDeviceApi().getSelfRevocationStatus(
        headers: _authorizationHeaders(request.continuationToken.value),
        extra: _strictResponseExtra,
      );
      return CloudSyncSelfRevocationStatus.fromJson(
        _strictVariantResponseData(response.extra[_rawResponseKey], '自撤销状态响应'),
        request: request,
      );
    });
  }

  @override
  Future<CloudSyncSelfRevocationStatus> continueSelfRevocationStatus(
    CloudSyncSelfRevocationRequest request,
  ) {
    return _guard(() async {
      final response = await _client.getDeviceApi().getSelfRevocationStatus(
        headers: _authorizationHeaders(request.continuationToken.value),
        extra: _strictResponseExtra,
      );
      return CloudSyncSelfRevocationStatus.fromJsonForRequest(
        _strictVariantResponseData(response.extra[_rawResponseKey], '自撤销状态响应'),
        request: request,
      );
    });
  }

  @override
  Future<CloudSyncSelfRevocationCancelled> cancelSelfRevocationRequest(
    CloudSyncSelfRevocationRequestResult request,
  ) {
    return _guard(() async {
      final generatedRequest = api.CancelSelfRevocationRequest(
        (builder) => builder..mutationId = request.mutationId,
      );
      final response = await _client.getDeviceApi().cancelSelfRevocationRequest(
        cancelSelfRevocationRequest: generatedRequest,
        headers: _requireFullSessionHeaders(),
        extra: _strictResponseExtra,
      );
      final status = CloudSyncSelfRevocationStatus.fromJson(
        _strictVariantResponseData(
          response.extra[_rawResponseKey],
          '取消自撤销请求响应',
        ),
        request: request,
      );
      if (status is! CloudSyncSelfRevocationCancelled) {
        throw const FormatException('取消自撤销请求未返回取消终态');
      }
      return status;
    });
  }

  @override
  Future<CloudSyncUntrustedSelfRevocationRequestList>
  listSelfRevocationRequests() {
    return _guard(() async {
      final response = await _client.getDeviceApi().listSelfRevocationRequests(
        headers: _requireFullSessionHeaders(),
        extra: _strictResponseExtra,
      );
      return CloudSyncUntrustedSelfRevocationRequestList.fromJson(
        _strictResponseData(
          response.extra[_rawResponseKey],
          _selfRevocationRequestListDataKeys,
          '待协调自撤销请求列表响应',
        ),
        now: _now(),
      );
    });
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
    required CloudSyncGenesisSecurityState securityState,
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
          ..securityState.replace(
            api.GenesisSecurityState(
              (state) => state
                ..generation = 1
                ..operationId = securityState.operationId
                ..keyEpoch = 1
                ..membershipManifest = _encodeBinaryForRequest(
                  securityState.membershipManifest,
                )
                ..membershipManifestDigest =
                    securityState.membershipManifestDigest.encoded
                ..recoveryPublicKeyVersion =
                    securityState.recoveryPublicKeyVersion
                ..recoveryPublicKey = _encodeFixedBinaryForRequest(
                  securityState.recoveryPublicKey,
                  cloudSyncRecoveryPublicKeyBytes,
                )
                ..recoveryCapsuleVersion = securityState.recoveryCapsuleVersion
                ..recoveryCapsule = _encodeBinaryForRequest(
                  securityState.recoveryCapsule,
                ),
            ),
          )
          ..deviceProof = encodedDeviceProof,
      );
      final response = await _client.getAuthApi().finishOpaqueRegistration(
        opaqueRegistrationFinishRequest: request,
        extra: _strictResponseExtra,
      );
      return _parseRegistrationSession(response.extra[_rawResponseKey]);
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
          authGeneration: value.device.authGeneration,
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
  Future<E2eeAccountRecoveryAuthorizedState> getAuthorizedState({
    required CloudSyncAccountRecoveryToken recoveryToken,
  }) async {
    try {
      return await _guard(() async {
        final response = await _client
            .getAccountRecoveryApi()
            .getAccountRecoveryState(
              headers: _authorizationHeaders(recoveryToken.value),
              extra: _strictResponseExtra,
            );
        return _parseAccountRecoveryAuthorizedState(
          response.extra[_rawResponseKey],
        );
      });
    } on CloudSyncException catch (error) {
      if (error.kind == CloudSyncFailureKind.unauthenticated &&
          error.serverCode == 'AUTH_ACCOUNT_RECOVERY_TOKEN_INVALID') {
        throw const E2eeAccountRecoveryTokenUnavailable();
      }
      rethrow;
    }
  }

  @override
  Future<E2eeAccountRecoveryChallenge> createChallenge({
    required CloudSyncOnboardingToken onboardingToken,
    required String attemptId,
  }) {
    _requireClientIdentifier(attemptId);
    return _guard(() async {
      final challengeRequest = api.AccountRecoveryAttemptStartRequestOneOf(
        (builder) => builder
          ..action =
              api.AccountRecoveryAttemptStartRequestOneOfActionEnum.challenge
          ..protocolVersion = e2eeAccountRecoveryProtocolVersion
          ..attemptId = attemptId,
      );
      final request = api.AccountRecoveryAttemptStartRequest(
        (builder) => builder.oneOf =
            OneOf.fromValue2<
              api.AccountRecoveryAttemptStartRequestOneOf,
              api.AccountRecoveryAttemptStartRequestOneOf1
            >(value: challengeRequest),
      );
      final response = await _client
          .getAccountRecoveryApi()
          .startAccountRecoveryAttempt(
            accountRecoveryAttemptStartRequest: request,
            headers: _authorizationHeaders(onboardingToken.value),
            extra: _strictResponseExtra,
          );
      return _parseAccountRecoveryChallenge(
        response.extra[_rawResponseKey],
        expectedAttemptId: attemptId,
      );
    });
  }

  @override
  Future<CloudSyncAccountSecurityHistoryPage> listFrozenHistory({
    required E2eeAccountRecoveryBearer authorization,
    required String attemptId,
    required Uint8List challengeRequestDigest,
    required int afterGeneration,
    required int pageSize,
  }) {
    _requireClientIdentifier(attemptId);
    if (afterGeneration < 0 ||
        afterGeneration > 0x7fffffff ||
        pageSize < 1 ||
        pageSize > e2eeAccountRecoveryHistoryPageSize) {
      throw const CloudSyncException(
        kind: CloudSyncFailureKind.validation,
        retryable: false,
      );
    }
    final encodedRequestDigest = _encodeFixedBinaryForRequest(
      challengeRequestDigest,
      32,
    );
    return _guard(() async {
      final request = api.AccountRecoveryHistoryListRequest(
        (builder) => builder
          ..afterGeneration = afterGeneration
          ..pageSize = pageSize
          ..attemptId = attemptId
          ..challengeRequestDigest = encodedRequestDigest,
      );
      final response = await _client
          .getAccountRecoveryApi()
          .listAccountRecoveryHistory(
            accountRecoveryHistoryListRequest: request,
            headers: _authorizationHeaders(authorization.value),
            extra: _strictResponseExtra,
          );
      return _parseAccountSecurityStateHistory(
        response.extra[_rawResponseKey],
        expectedAfterGeneration: afterGeneration,
        expectedPageSize: pageSize,
      );
    });
  }

  @override
  Future<E2eeAccountRecoveryAuthorizationReceipt> authorize({
    required E2eeAccountRecoveryBearer authorization,
    required String attemptId,
    required Uint8List challengeRequestDigest,
    required CloudSyncAccountRecoveryToken recoveryToken,
    required Uint8List nonceProof,
    required Uint8List trustSignature,
  }) {
    _requireClientIdentifier(attemptId);
    final encodedRequestDigest = _encodeFixedBinaryForRequest(
      challengeRequestDigest,
      32,
    );
    final encodedNonceProof = _encodeFixedBinaryForRequest(
      nonceProof,
      e2eeAccountRecoveryNonceProofBytes,
    );
    final encodedTrustSignature = _encodeFixedBinaryForRequest(
      trustSignature,
      e2eeAccountRecoveryTrustSignatureBytes,
    );
    return _guard(() async {
      final authorizeRequest = api.AccountRecoveryAttemptStartRequestOneOf1(
        (builder) => builder
          ..action =
              api.AccountRecoveryAttemptStartRequestOneOf1ActionEnum.authorize
          ..protocolVersion = e2eeAccountRecoveryProtocolVersion
          ..attemptId = attemptId
          ..challengeRequestDigest = encodedRequestDigest
          ..recoveryToken = recoveryToken.value
          ..nonceProof = encodedNonceProof
          ..trustSignature = encodedTrustSignature,
      );
      final request = api.AccountRecoveryAttemptStartRequest(
        (builder) => builder.oneOf =
            OneOf.fromValue2<
              api.AccountRecoveryAttemptStartRequestOneOf,
              api.AccountRecoveryAttemptStartRequestOneOf1
            >(value: authorizeRequest),
      );
      final response = await _client
          .getAccountRecoveryApi()
          .startAccountRecoveryAttempt(
            accountRecoveryAttemptStartRequest: request,
            headers: _authorizationHeaders(authorization.value),
            extra: _strictResponseExtra,
          );
      return _parseAccountRecoveryAuthorizationReceipt(
        response.extra[_rawResponseKey],
        expectedAttemptId: attemptId,
      );
    });
  }

  @override
  Future<E2eeAccountRecoveryReplacementChallenge> createReplacementChallenge({
    required CloudSyncAccountRecoveryToken recoveryToken,
    required String expectedAttemptId,
    required String expectedDeviceId,
    required E2eeAccountRecoveryReplacementChallengeRequest request,
  }) {
    _requireClientIdentifier(expectedAttemptId);
    _requireClientIdentifier(expectedDeviceId);
    final generatedRequest = api.AccountRecoveryReplacementChallengeRequest((
      builder,
    ) {
      builder
        ..protocolVersion = e2eeAccountRecoveryProtocolVersion
        ..challengeId = request.challengeId
        ..expectedGeneration = request.expectedGeneration
        ..expectedKeyEpoch = request.expectedKeyEpoch
        ..expectedMembershipManifestDigest = _encodeFixedBinaryForRequest(
          request.expectedMembershipManifestDigest,
          cloudSyncMembershipManifestDigestBytes,
        )
        ..expectedMembershipOperationId = request.expectedMembershipOperationId
        ..dataGeneration = request.dataGeneration
        ..dataKeyEpoch = request.dataKeyEpoch
        ..sourceRekeyOperationId = request.sourceRekeyOperationId
        ..sourceCompletionProofDigest = _encodeFixedBinaryForRequest(
          request.sourceCompletionProofDigest,
          cloudSyncMembershipManifestDigestBytes,
        );
    });
    return _guard(() async {
      final response = await _client
          .getAccountRecoveryApi()
          .createAccountRecoveryReplacementChallenge(
            accountRecoveryReplacementChallengeRequest: generatedRequest,
            headers: _authorizationHeaders(recoveryToken.value),
            extra: _strictResponseExtra,
          );
      return _parseAccountRecoveryReplacementChallenge(
        response.extra[_rawResponseKey],
        expectedAttemptId: expectedAttemptId,
        expectedDeviceId: expectedDeviceId,
        request: request,
      );
    });
  }

  @override
  Future<E2eeAccountRecoveryCommitReceipt> commitRecoveryResume({
    required CloudSyncAccountRecoveryToken recoveryToken,
    required E2eeAccountRecoveryResumeCommit request,
  }) {
    final membership = request.membership;
    return _guard(() async {
      final generatedRequest = api.AccountRecoveryResumeCommitRequest((
        builder,
      ) {
        builder
          ..protocolVersion = e2eeAccountRecoveryProtocolVersion
          ..expectedGeneration = membership.expectedGeneration
          ..expectedKeyEpoch = membership.expectedKeyEpoch
          ..expectedMembershipManifestDigest =
              membership.expectedMembershipManifestDigest.encoded
          ..operationId = membership.operationId
          ..nextMembershipManifest = _encodeBinaryForRequest(
            membership.nextMembershipManifest,
          )
          ..nextMembershipManifestDigest =
              membership.nextMembershipManifestDigest.encoded
          ..rekeyOperationId = request.rekeyOperationId;
        builder.envelope
          ..envelopeVersion = membership.envelope.envelopeVersion
          ..keyEpoch = membership.envelope.keyEpoch
          ..accountKeyEnvelope = _encodeFixedBinaryForRequest(
            membership.envelope.accountKeyEnvelope,
            cloudSyncAccountKeyEnvelopeBytes,
          );
      });
      final response = await _client
          .getAccountRecoveryApi()
          .commitAccountRecoveryResume(
            accountRecoveryResumeCommitRequest: generatedRequest,
            headers: _authorizationHeaders(recoveryToken.value),
            extra: _strictResponseExtra,
          );
      return _parseAccountRecoveryCommitReceipt(
        response.extra[_rawResponseKey],
        expectedKind: E2eeAccountRecoveryCommitKind.resume,
        expectedAttemptId: request.attemptId,
        expectedMembershipOperationId: membership.operationId,
        expectedRekeyOperationId: request.rekeyOperationId,
        expectedGeneration: membership.expectedGeneration + 1,
        expectedKeyEpoch: membership.expectedKeyEpoch,
        expectedNextAction: E2eeAccountRecoveryNextAction.finishFirstDataRekey,
      );
    });
  }

  @override
  Future<E2eeAccountRecoveryCommitReceipt> commitRecoveryReplacement({
    required CloudSyncAccountRecoveryToken recoveryToken,
    required E2eeAccountRecoveryReplacementCommit request,
  }) {
    final membership = request.membership;
    return _guard(() async {
      final generatedAuthorization = switch (request.authorization) {
        E2eeAccountRecoveryReplacementInitialAuthorization(
          :final challengeRequestDigest,
        ) =>
          api.AccountRecoveryReplacementCommitRequestAuthorization(
            (builder) => builder.oneOf =
                OneOf.fromValue2<
                  api.AccountRecoveryReplacementCommitRequestAuthorizationOneOf,
                  api.AccountRecoveryReplacementCommitRequestAuthorizationOneOf1
                >(
                  value: api.AccountRecoveryReplacementCommitRequestAuthorizationOneOf(
                    (authorization) => authorization
                      ..kind = api
                          .AccountRecoveryReplacementCommitRequestAuthorizationOneOfKindEnum
                          .initial
                      ..challengeRequestDigest = _encodeFixedBinaryForRequest(
                        challengeRequestDigest,
                        32,
                      ),
                  ),
                ),
          ),
        E2eeAccountRecoveryReplacementChallengeAuthorization(
          :final challengeId,
          :final challengeRequestDigest,
          :final nonceProof,
          :final trustSignature,
        ) =>
          api.AccountRecoveryReplacementCommitRequestAuthorization(
            (builder) => builder.oneOf =
                OneOf.fromValue2<
                  api.AccountRecoveryReplacementCommitRequestAuthorizationOneOf,
                  api.AccountRecoveryReplacementCommitRequestAuthorizationOneOf1
                >(
                  value: api.AccountRecoveryReplacementCommitRequestAuthorizationOneOf1(
                    (authorization) => authorization
                      ..kind = api
                          .AccountRecoveryReplacementCommitRequestAuthorizationOneOf1KindEnum
                          .replacementChallenge
                      ..challengeId = challengeId
                      ..challengeRequestDigest = _encodeFixedBinaryForRequest(
                        challengeRequestDigest,
                        32,
                      )
                      ..nonceProof = _encodeFixedBinaryForRequest(
                        nonceProof,
                        e2eeAccountRecoveryNonceProofBytes,
                      )
                      ..trustSignature = _encodeFixedBinaryForRequest(
                        trustSignature,
                        e2eeAccountRecoveryTrustSignatureBytes,
                      ),
                  ),
                ),
          ),
      };
      final generatedRequest = api.AccountRecoveryReplacementCommitRequest((
        builder,
      ) {
        builder
          ..protocolVersion = e2eeAccountRecoveryProtocolVersion
          ..expectedGeneration = membership.expectedGeneration
          ..expectedKeyEpoch = membership.expectedKeyEpoch
          ..expectedMembershipManifestDigest =
              membership.expectedMembershipManifestDigest.encoded
          ..operationId = membership.operationId
          ..nextMembershipManifest = _encodeBinaryForRequest(
            membership.nextMembershipManifest,
          )
          ..nextMembershipManifestDigest =
              membership.nextMembershipManifestDigest.encoded
          ..nextRecoveryCapsuleVersion = request.nextRecoveryCapsuleVersion
          ..nextRecoveryCapsule = _encodeBinaryForRequest(
            request.nextRecoveryCapsule,
          )
          ..completionSessionId = request.completionSessionId
          ..completionSessionToken = request.completionSessionToken.value;
        builder.authorization.replace(generatedAuthorization);
        builder.envelope
          ..envelopeVersion = membership.envelope.envelopeVersion
          ..keyEpoch = membership.envelope.keyEpoch
          ..accountKeyEnvelope = _encodeFixedBinaryForRequest(
            membership.envelope.accountKeyEnvelope,
            cloudSyncAccountKeyEnvelopeBytes,
          );
      });
      final response = await _client
          .getAccountRecoveryApi()
          .commitAccountRecoveryReplacement(
            accountRecoveryReplacementCommitRequest: generatedRequest,
            headers: _authorizationHeaders(recoveryToken.value),
            extra: _strictResponseExtra,
          );
      return _parseAccountRecoveryCommitReceipt(
        response.extra[_rawResponseKey],
        expectedKind: E2eeAccountRecoveryCommitKind.replacement,
        expectedAttemptId: request.attemptId,
        expectedMembershipOperationId: membership.operationId,
        expectedRekeyOperationId: membership.operationId,
        expectedGeneration: membership.expectedGeneration + 1,
        expectedKeyEpoch: membership.expectedKeyEpoch + 1,
        expectedNextAction: E2eeAccountRecoveryNextAction.finishSecondDataRekey,
      );
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
        extra: _strictResponseExtra,
      );
      return _parseDevicePairingQuery(response.extra[_rawResponseKey]);
    });
  }

  @override
  Future<CloudSyncDevicePairingApproval> approveDevicePairing({
    required CloudSyncFullSessionToken token,
    required String pairingId,
    required int keyEpoch,
    required CloudSyncDevicePairingMembershipCommit membershipCommit,
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
          ..expectedSecurityGeneration =
              membershipCommit.expectedSecurityGeneration
          ..expectedMembershipManifestDigest =
              membershipCommit.expectedMembershipManifestDigest.encoded
          ..nextMembershipManifest = _encodeBinaryForRequest(
            membershipCommit.nextMembershipManifest,
          )
          ..nextMembershipManifestDigest =
              membershipCommit.nextMembershipManifestDigest.encoded
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
    required CloudSyncFullSessionToken sessionToken,
  }) {
    _requireClientIdentifier(pairingId);

    return _guard(() async {
      final request = api.DevicePairingConsumeRequest(
        (builder) => builder
          ..protocolVersion = cloudSyncOpaqueProtocolVersion
          ..pairingId = pairingId
          ..sessionToken = sessionToken.value,
      );
      final response = await _client.getAuthApi().consumeDevicePairing(
        devicePairingConsumeRequest: request,
        headers: _authorizationHeaders(token.value),
        extra: _strictResponseExtra,
      );
      return _parsePairingSession(
        response.extra[_rawResponseKey],
        expectedToken: sessionToken,
      );
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
  Future<CloudSyncAttachmentUpload> createAttachmentUpload({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentCreateUploadRequest request,
  }) {
    return _guard(() async {
      final generatedRequest = api.AttachmentCreateUploadRequest(
        (builder) => builder
          ..mutationId = request.mutationId
          ..attachmentId = request.attachmentId
          ..chunkKeyEpoch = request.chunkKeyEpoch
          ..manifestKeyEpoch = request.manifestKeyEpoch
          ..manifestRevision = request.manifestRevision
          ..chunkCount = request.chunkCount
          ..totalCiphertextBytes = request.totalCiphertextBytes,
      );
      final response = await _client
          .getSyncAttachmentApi()
          .createEncryptedAttachmentUpload(
            xKelivoSyncProtocolVersion: _syncProtocolVersion,
            attachmentCreateUploadRequest: generatedRequest,
            headers: _authorizationHeaders(token.value),
            extra: _strictResponseExtra,
          );
      _requireStrictAttachmentResponse(
        response.extra[_rawResponseKey],
        _attachmentUploadResponseKeys,
      );
      final data = _requireResponseData(response.data?.data);
      if (data.status.name != 'open') {
        throw const FormatException('服务端返回了未知的附件上传状态');
      }
      final identity = _attachmentIdentity(
        attachmentId: data.attachmentId,
        uploadId: data.uploadId,
        chunkKeyEpoch: data.chunkKeyEpoch,
        manifestKeyEpoch: data.manifestKeyEpoch,
        manifestRevision: data.manifestRevision,
      );
      _requireAttachmentCreateResponseMatches(
        request: request,
        identity: identity,
        chunkCount: data.chunkCount,
        totalCiphertextBytes: data.totalCiphertextBytes,
      );
      return CloudSyncAttachmentUpload(
        identity: identity,
        chunkCount: data.chunkCount,
        totalCiphertextBytes: data.totalCiphertextBytes,
        createdAt: data.createdAt,
      );
    });
  }

  @override
  Future<CloudSyncAttachmentStoredChunk> putAttachmentChunk({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentPutChunkRequest request,
  }) {
    return _guard(() async {
      final identity = request.chunk.identity;
      final generatedRequest = api.AttachmentPutChunkRequest(
        (builder) => builder
          ..mutationId = request.mutationId
          ..attachmentId = identity.attachmentId
          ..uploadId = identity.uploadId
          ..chunkKeyEpoch = identity.chunkKeyEpoch
          ..chunkIndex = request.chunk.chunkIndex
          ..ciphertext = _encodeSyncCiphertext(request.ciphertext),
      );
      final response = await _client
          .getSyncAttachmentApi()
          .putEncryptedAttachmentChunk(
            xKelivoSyncProtocolVersion: _syncProtocolVersion,
            attachmentPutChunkRequest: generatedRequest,
            headers: _authorizationHeaders(token.value),
            extra: _strictResponseExtra,
          );
      _requireStrictAttachmentResponse(
        response.extra[_rawResponseKey],
        _attachmentStoredChunkResponseKeys,
      );
      final data = _requireResponseData(response.data?.data);
      if (data.status.name != 'stored' ||
          data.attachmentId != identity.attachmentId ||
          data.uploadId != identity.uploadId ||
          data.chunkKeyEpoch != identity.chunkKeyEpoch ||
          data.chunkIndex != request.chunk.chunkIndex ||
          data.ciphertextBytes != request.ciphertext.length) {
        throw const FormatException('服务端返回的附件分块写入结果与请求不一致');
      }
      return CloudSyncAttachmentStoredChunk(
        chunk: request.chunk,
        ciphertextBytes: data.ciphertextBytes,
      );
    });
  }

  @override
  Future<CloudSyncAttachmentCommittedUpload> commitAttachmentUpload({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentCommitUploadRequest request,
  }) {
    return _guard(() async {
      final identity = request.identity;
      final generatedRequest = api.AttachmentCommitUploadRequest(
        (builder) => builder
          ..mutationId = request.mutationId
          ..attachmentId = identity.attachmentId
          ..uploadId = identity.uploadId
          ..manifestKeyEpoch = identity.manifestKeyEpoch
          ..manifestRevision = identity.manifestRevision
          ..manifestCiphertext = _encodeSyncCiphertext(
            request.manifestCiphertext,
          )
          ..chunks.addAll(request.chunks.map(_toGeneratedManifestChunk)),
      );
      final response = await _client
          .getSyncAttachmentApi()
          .commitEncryptedAttachmentUpload(
            xKelivoSyncProtocolVersion: _syncProtocolVersion,
            attachmentCommitUploadRequest: generatedRequest,
            headers: _authorizationHeaders(token.value),
            extra: _strictResponseExtra,
          );
      _requireStrictAttachmentResponse(
        response.extra[_rawResponseKey],
        _attachmentCommittedResponseKeys,
      );
      final data = _requireResponseData(response.data?.data);
      final responseIdentity = _attachmentIdentity(
        attachmentId: data.attachmentId,
        uploadId: data.uploadId,
        chunkKeyEpoch: data.chunkKeyEpoch,
        manifestKeyEpoch: data.manifestKeyEpoch,
        manifestRevision: data.manifestRevision,
      );
      if (data.status.name != 'committed') {
        throw const FormatException('服务端返回了未知的附件提交状态');
      }
      _requireMatchingAttachmentIdentity(identity, responseIdentity);
      return CloudSyncAttachmentCommittedUpload(
        identity: responseIdentity,
        committedAt: data.committedAt,
      );
    });
  }

  @override
  Future<CloudSyncAttachmentManifest> getAttachmentManifest({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentIdentity identity,
  }) {
    return _guard(() async {
      final generatedRequest = api.AttachmentGetManifestRequest(
        (builder) => builder
          ..attachmentId = identity.attachmentId
          ..uploadId = identity.uploadId
          ..manifestKeyEpoch = identity.manifestKeyEpoch
          ..manifestRevision = identity.manifestRevision,
      );
      final response = await _client
          .getSyncAttachmentApi()
          .getEncryptedAttachmentManifest(
            xKelivoSyncProtocolVersion: _syncProtocolVersion,
            attachmentGetManifestRequest: generatedRequest,
            headers: _authorizationHeaders(token.value),
            extra: _strictResponseExtra,
          );
      _requireStrictAttachmentResponse(
        response.extra[_rawResponseKey],
        _attachmentManifestResponseKeys,
        validateChunks: true,
      );
      final data = _requireResponseData(response.data?.data);
      final responseIdentity = _attachmentIdentity(
        attachmentId: data.attachmentId,
        uploadId: data.uploadId,
        chunkKeyEpoch: data.chunkKeyEpoch,
        manifestKeyEpoch: data.manifestKeyEpoch,
        manifestRevision: data.manifestRevision,
      );
      _requireMatchingAttachmentIdentity(identity, responseIdentity);
      final manifestCiphertext = _decodeCanonicalAttachmentCiphertext(
        data.manifestCiphertext,
        expectedLength: data.manifestCiphertextBytes,
        maximumLength: cloudSyncMaximumAttachmentManifestCiphertextBytes,
      );
      return CloudSyncAttachmentManifest(
        identity: responseIdentity,
        chunkCount: data.chunkCount,
        totalCiphertextBytes: data.totalCiphertextBytes,
        manifestCiphertext: manifestCiphertext,
        manifestCiphertextBytes: data.manifestCiphertextBytes,
        chunks: data.chunks
            .map(
              (chunk) => CloudSyncAttachmentManifestChunk(
                chunkIndex: chunk.chunkIndex,
                ciphertextBytes: chunk.ciphertextBytes,
              ),
            )
            .toList(growable: false),
        committedAt: data.committedAt,
      );
    });
  }

  @override
  Future<CloudSyncAttachmentChunk> getAttachmentChunk({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentChunkIdentity chunk,
  }) {
    return _guard(() async {
      final identity = chunk.identity;
      final generatedRequest = api.AttachmentGetChunkRequest(
        (builder) => builder
          ..attachmentId = identity.attachmentId
          ..uploadId = identity.uploadId
          ..chunkKeyEpoch = identity.chunkKeyEpoch
          ..chunkIndex = chunk.chunkIndex,
      );
      final response = await _client
          .getSyncAttachmentApi()
          .getEncryptedAttachmentChunk(
            xKelivoSyncProtocolVersion: _syncProtocolVersion,
            attachmentGetChunkRequest: generatedRequest,
            headers: _authorizationHeaders(token.value),
            extra: _strictResponseExtra,
          );
      _requireStrictAttachmentResponse(
        response.extra[_rawResponseKey],
        _attachmentChunkResponseKeys,
      );
      final data = _requireResponseData(response.data?.data);
      final responseIdentity = _attachmentIdentity(
        attachmentId: data.attachmentId,
        uploadId: data.uploadId,
        chunkKeyEpoch: data.chunkKeyEpoch,
        manifestKeyEpoch: identity.manifestKeyEpoch,
        manifestRevision: identity.manifestRevision,
      );
      _requireMatchingAttachmentChunkIdentity(identity, responseIdentity);
      if (data.chunkIndex != chunk.chunkIndex) {
        throw const FormatException('服务端返回了其他附件分块');
      }
      final ciphertext = _decodeCanonicalAttachmentCiphertext(
        data.ciphertext,
        expectedLength: data.ciphertextBytes,
        maximumLength: cloudSyncMaximumAttachmentChunkCiphertextBytes,
      );
      return CloudSyncAttachmentChunk(
        chunk: chunk,
        ciphertext: ciphertext,
        ciphertextBytes: data.ciphertextBytes,
      );
    });
  }

  @override
  Future<CloudSyncAttachmentDeleted> deleteAttachment({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentDeleteRequest request,
  }) {
    return _guard(() async {
      final identity = request.identity;
      final generatedRequest = api.AttachmentDeleteRequest(
        (builder) => builder
          ..mutationId = request.mutationId
          ..attachmentId = identity.attachmentId
          ..uploadId = identity.uploadId
          ..manifestKeyEpoch = identity.manifestKeyEpoch
          ..manifestRevision = identity.manifestRevision,
      );
      final response = await _client
          .getSyncAttachmentApi()
          .deleteEncryptedAttachment(
            xKelivoSyncProtocolVersion: _syncProtocolVersion,
            attachmentDeleteRequest: generatedRequest,
            headers: _authorizationHeaders(token.value),
            extra: _strictResponseExtra,
          );
      _requireStrictAttachmentResponse(
        response.extra[_rawResponseKey],
        _attachmentDeletedResponseKeys,
      );
      final data = _requireResponseData(response.data?.data);
      final responseIdentity = _attachmentIdentity(
        attachmentId: data.attachmentId,
        uploadId: data.uploadId,
        chunkKeyEpoch: data.chunkKeyEpoch,
        manifestKeyEpoch: data.manifestKeyEpoch,
        manifestRevision: data.manifestRevision,
      );
      if (data.status.name != 'deleted') {
        throw const FormatException('服务端返回了未知的附件删除状态');
      }
      _requireMatchingAttachmentIdentity(identity, responseIdentity);
      return CloudSyncAttachmentDeleted(
        identity: responseIdentity,
        deletedAt: data.deletedAt,
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
  Future<CloudSyncPullResult> pullChanges({String? cursor, int limit = 10}) {
    _validatePullArguments(cursor: cursor, limit: limit);
    return _pullValidatedChanges(
      cursor: cursor,
      limit: limit,
      token: _requireFullSessionToken(),
    );
  }

  Future<CloudSyncPullResult> pullChangesWithToken({
    required CloudSyncFullSessionToken token,
    String? cursor,
    int limit = 10,
  }) {
    _validatePullArguments(cursor: cursor, limit: limit);
    return _pullValidatedChanges(cursor: cursor, limit: limit, token: token);
  }

  Future<CloudSyncPullResult> _pullValidatedChanges({
    required String? cursor,
    required int limit,
    required CloudSyncFullSessionToken token,
  }) {
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
        headers: _authorizationHeaders(token.value),
      );
      final data = _requireResponseData(response.data?.data);
      if (data.resetRequired) {
        _validateResetRequired(
          changeCount: data.changes.length,
          nextCursor: data.nextCursor,
          hasMore: data.hasMore,
        );
        return const CloudSyncResetRequired();
      }
      final nextCursor = _requireValidChangePage(
        changeCount: data.changes.length,
        pageLimit: limit,
        requestedCursor: cursor,
        nextCursor: data.nextCursor,
        hasMore: data.hasMore,
      );
      final changes = data.changes
          .map(_fromRecordChange)
          .toList(growable: false);
      _validateChangeOrdering(changes);
      return CloudSyncChangePage(
        changes: List<CloudSyncRecordChange>.unmodifiable(changes),
        nextCursor: nextCursor,
        hasMore: data.hasMore,
      );
    });
  }

  @override
  Future<CloudSyncSnapshotPage> pullSnapshot({
    String? snapshotCursor,
    int limit = 10,
  }) {
    _validatePullArguments(cursor: snapshotCursor, limit: limit);
    return _pullValidatedSnapshot(
      snapshotCursor: snapshotCursor,
      limit: limit,
      token: _requireFullSessionToken(),
    );
  }

  Future<CloudSyncSnapshotPage> pullSnapshotWithToken({
    required CloudSyncFullSessionToken token,
    String? snapshotCursor,
    int limit = 10,
  }) {
    _validatePullArguments(cursor: snapshotCursor, limit: limit);
    return _pullValidatedSnapshot(
      snapshotCursor: snapshotCursor,
      limit: limit,
      token: token,
    );
  }

  Future<CloudSyncSnapshotPage> _pullValidatedSnapshot({
    required String? snapshotCursor,
    required int limit,
    required CloudSyncFullSessionToken token,
  }) {
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
        headers: _authorizationHeaders(token.value),
      );
      final data = _requireResponseData(response.data?.data);
      _validateSnapshotPage(
        recordCount: data.records.length,
        pageLimit: limit,
        requestedSnapshotCursor: snapshotCursor,
        nextSnapshotCursor: data.nextSnapshotCursor,
        syncCursor: data.syncCursor,
        hasMore: data.hasMore,
      );
      final records = data.records
          .map(_fromRecordState)
          .toList(growable: false);
      _validateSnapshotOrdering(records);
      return CloudSyncSnapshotPage(
        records: List<CloudSyncEncryptedRecord>.unmodifiable(records),
        nextSnapshotCursor: data.nextSnapshotCursor,
        syncCursor: data.syncCursor,
        hasMore: data.hasMore,
      );
    });
  }

  @override
  Future<CloudSyncAccountSecurityState> getSecurityState() {
    return _guard(() async {
      final response = await _client.getDeviceApi().getDeviceSecurityState(
        headers: _requireFullSessionHeaders(),
        extra: _strictResponseExtra,
      );
      return _parseAccountSecurityState(response.extra[_rawResponseKey]);
    });
  }

  @override
  Future<CloudSyncDataRekeyState> getDataRekeyState() {
    return _guard(() async {
      final response = await _client.getDataRekeyApi().getDataRekeyState(
        xKelivoSyncProtocolVersion: _syncProtocolVersion,
        headers: _requireDataRekeyHeaders(),
        extra: _strictResponseExtra,
      );
      return _parseDataRekeyState(response.extra[_rawResponseKey]);
    });
  }

  @override
  Future<CloudSyncDataRekeyLeaseClaim> claimDataRekeyLease(
    CloudSyncDataRekeyLeaseClaimRequest request,
  ) {
    return _guard(() async {
      final operation = request.operation;
      final generatedRequest = api.DataRekeyLeaseClaimRequest(
        (builder) => builder
          ..operationId = operation.operationId
          ..sourceDataGeneration = operation.sourceDataGeneration
          ..sourceKeyEpoch = operation.sourceKeyEpoch
          ..targetKeyEpoch = operation.targetKeyEpoch
          ..leaseToken = request.leaseToken
          ..mutationId = request.mutationId,
      );
      final response = await _client.getDataRekeyApi().claimDataRekeyLease(
        xKelivoSyncProtocolVersion: _syncProtocolVersion,
        dataRekeyLeaseClaimRequest: generatedRequest,
        headers: _requireDataRekeyHeaders(),
        extra: _strictResponseExtra,
      );
      return _parseDataRekeyLeaseClaim(
        response.extra[_rawResponseKey],
        request: request,
      );
    });
  }

  @override
  Future<CloudSyncDataRekeySourceRecordPage> listDataRekeySourceRecords(
    CloudSyncDataRekeySourceRecordListRequest request,
  ) {
    return _guard(() async {
      final activeLease = request.activeLease;
      final operation = activeLease.operation;
      final generatedRequest = api.DataRekeySourceRecordListRequest(
        (builder) => builder
          ..operationId = operation.operationId
          ..sourceDataGeneration = operation.sourceDataGeneration
          ..sourceKeyEpoch = operation.sourceKeyEpoch
          ..targetKeyEpoch = operation.targetKeyEpoch
          ..leaseToken = activeLease.leaseToken
          ..leaseVersion = activeLease.leaseVersion
          ..afterRecordId = request.afterRecordId
          ..limit = request.limit,
      );
      final response = await _client
          .getDataRekeyApi()
          .listDataRekeySourceRecords(
            xKelivoSyncProtocolVersion: _syncProtocolVersion,
            dataRekeySourceRecordListRequest: generatedRequest,
            headers: _requireDataRekeyHeaders(),
            extra: _strictResponseExtra,
          );
      return _parseDataRekeySourceRecordPage(
        response.extra[_rawResponseKey],
        request: request,
      );
    });
  }

  @override
  Future<CloudSyncDataRekeySourceAttachmentPage> listDataRekeySourceAttachments(
    CloudSyncDataRekeySourceAttachmentListRequest request,
  ) {
    return _guard(() async {
      final activeLease = request.activeLease;
      final operation = activeLease.operation;
      final generatedRequest = api.DataRekeySourceAttachmentListRequest(
        (builder) => builder
          ..operationId = operation.operationId
          ..sourceDataGeneration = operation.sourceDataGeneration
          ..sourceKeyEpoch = operation.sourceKeyEpoch
          ..targetKeyEpoch = operation.targetKeyEpoch
          ..leaseToken = activeLease.leaseToken
          ..leaseVersion = activeLease.leaseVersion
          ..afterAttachmentId = request.afterCursor?.attachmentId
          ..afterUploadId = request.afterCursor?.uploadId
          ..limit = request.limit,
      );
      final response = await _client
          .getDataRekeyApi()
          .listDataRekeySourceAttachments(
            xKelivoSyncProtocolVersion: _syncProtocolVersion,
            dataRekeySourceAttachmentListRequest: generatedRequest,
            headers: _requireDataRekeyHeaders(),
            extra: _strictResponseExtra,
          );
      return _parseDataRekeySourceAttachmentPage(
        response.extra[_rawResponseKey],
        request: request,
      );
    });
  }

  @override
  Future<CloudSyncDataRekeyRecordStageResult> stageDataRekeyRecord(
    CloudSyncDataRekeyRecordStageRequest request,
  ) {
    return _guard(() async {
      final activeLease = request.activeLease;
      final operation = activeLease.operation;
      final generatedRequest = api.DataRekeyRecordStageRequest(
        (builder) => builder
          ..operationId = operation.operationId
          ..sourceDataGeneration = operation.sourceDataGeneration
          ..sourceKeyEpoch = operation.sourceKeyEpoch
          ..targetKeyEpoch = operation.targetKeyEpoch
          ..leaseToken = activeLease.leaseToken
          ..leaseVersion = activeLease.leaseVersion
          ..mutationId = request.mutationId
          ..sourceRecordId = request.sourceRecordId
          ..targetRecordId = request.targetRecordId
          ..sourceRevision = request.sourceRevision
          ..envelopeVersion = request.envelopeVersion
          ..ciphertext = _encodeBinaryForRequest(request.ciphertext),
      );
      final response = await _client.getDataRekeyApi().stageDataRekeyRecord(
        xKelivoSyncProtocolVersion: _syncProtocolVersion,
        dataRekeyRecordStageRequest: generatedRequest,
        headers: _requireDataRekeyHeaders(),
        extra: _strictResponseExtra,
      );
      return _parseDataRekeyRecordStageResult(
        response.extra[_rawResponseKey],
        request: request,
      );
    });
  }

  @override
  Future<CloudSyncDataRekeyAttachmentStageResult> stageDataRekeyAttachment(
    CloudSyncDataRekeyAttachmentStageRequest request,
  ) {
    return _guard(() async {
      final activeLease = request.activeLease;
      final operation = activeLease.operation;
      final generatedRequest = api.DataRekeyAttachmentStageRequest(
        (builder) => builder
          ..operationId = operation.operationId
          ..sourceDataGeneration = operation.sourceDataGeneration
          ..sourceKeyEpoch = operation.sourceKeyEpoch
          ..targetKeyEpoch = operation.targetKeyEpoch
          ..leaseToken = activeLease.leaseToken
          ..leaseVersion = activeLease.leaseVersion
          ..mutationId = request.mutationId
          ..attachmentId = request.attachmentId
          ..uploadId = request.uploadId
          ..sourceManifestRevision = request.sourceManifestRevision
          ..manifestKeyEpoch = request.manifestKeyEpoch
          ..manifestRevision = request.manifestRevision
          ..manifestCiphertext = _encodeBinaryForRequest(
            request.manifestCiphertext,
          ),
      );
      final response = await _client.getDataRekeyApi().stageDataRekeyAttachment(
        xKelivoSyncProtocolVersion: _syncProtocolVersion,
        dataRekeyAttachmentStageRequest: generatedRequest,
        headers: _requireDataRekeyHeaders(),
        extra: _strictResponseExtra,
      );
      return _parseDataRekeyAttachmentStageResult(
        response.extra[_rawResponseKey],
        request: request,
      );
    });
  }

  @override
  Future<CloudSyncDataRekeyFinalizeOutcome> finalizeDataRekey(
    CloudSyncDataRekeyFinalizeRequest request,
  ) {
    return _guard(() async {
      final activeLease = request.activeLease;
      final operation = activeLease.operation;
      final proof = request.proof;
      final generatedProof = api.DataRekeyFinalizeRequestProof((builder) {
        builder
          ..proofVersion = proof.proofVersion
          ..issuerDeviceId = proof.issuerDeviceId
          ..targetDataGeneration = request.targetDataGeneration
          ..sourceSnapshotRoot = _encodeBinaryForRequest(
            proof.sourceSnapshotRoot,
          )
          ..sourceRecordCount = proof.sourceRecordCount
          ..sourceAttachmentCount = proof.sourceAttachmentCount
          ..sourceMaximumChangeSeq = proof.sourceMaximumChangeSeq
          ..sourceRecordCursorEnd = proof.sourceRecordCursorEnd
          ..membershipGeneration = proof.membershipGeneration
          ..membershipManifestDigest = _encodeBinaryForRequest(
            proof.membershipManifestDigest,
          )
          ..stagedRecordCount = proof.stagedRecordCount
          ..stagedAttachmentCount = proof.stagedAttachmentCount
          ..stagedCiphertextSetDigest = _encodeBinaryForRequest(
            proof.stagedCiphertextSetDigest,
          )
          ..signature = _encodeBinaryForRequest(proof.signature);
        final attachmentCursor = proof.sourceAttachmentCursorEnd;
        if (attachmentCursor != null) {
          builder.sourceAttachmentCursorEnd
            ..attachmentId = attachmentCursor.attachmentId
            ..uploadId = attachmentCursor.uploadId;
        }
      });
      final generatedRequest = api.DataRekeyFinalizeRequest(
        (builder) => builder
          ..operationId = operation.operationId
          ..sourceDataGeneration = operation.sourceDataGeneration
          ..sourceKeyEpoch = operation.sourceKeyEpoch
          ..targetKeyEpoch = operation.targetKeyEpoch
          ..leaseToken = activeLease.leaseToken
          ..leaseVersion = activeLease.leaseVersion
          ..mutationId = request.mutationId
          ..proof.replace(generatedProof),
      );
      final response = await _client.getDataRekeyApi().finalizeDataRekey(
        xKelivoSyncProtocolVersion: _syncProtocolVersion,
        dataRekeyFinalizeRequest: generatedRequest,
        headers: _requireDataRekeyHeaders(),
        extra: _strictResponseExtra,
      );
      return _parseDataRekeyFinalizeOutcome(
        response.extra[_rawResponseKey],
        request: request,
      );
    });
  }

  @override
  Future<CloudSyncAccountSecurityHistoryPage> listSecurityStateHistory({
    int afterGeneration = 0,
    int pageSize = 20,
  }) {
    if (afterGeneration < 0 ||
        afterGeneration > 0x7fffffff ||
        pageSize < 1 ||
        pageSize > 100) {
      throw const CloudSyncException(
        kind: CloudSyncFailureKind.validation,
        retryable: false,
      );
    }
    return _guard(() async {
      final request = api.ListAccountSecurityStateHistoryRequest(
        (builder) => builder
          ..afterGeneration = afterGeneration
          ..pageSize = pageSize,
      );
      final response = await _client
          .getDeviceApi()
          .listDeviceSecurityStateHistory(
            listAccountSecurityStateHistoryRequest: request,
            headers: _requireFullSessionHeaders(),
            extra: _strictResponseExtra,
          );
      return _parseAccountSecurityStateHistory(
        response.extra[_rawResponseKey],
        expectedAfterGeneration: afterGeneration,
        expectedPageSize: pageSize,
      );
    });
  }

  @override
  Future<CloudSyncDeviceRotationResult> commitDeviceRotation(
    CloudSyncDeviceRotationRequest request,
  ) {
    return _guard(() async {
      final generatedRequest = api.CommitDeviceRotationRequest((builder) {
        builder
          ..expectedGeneration = request.expectedGeneration
          ..expectedKeyEpoch = request.expectedKeyEpoch
          ..expectedMembershipManifestDigest =
              request.expectedMembershipManifestDigest.encoded
          ..operationId = request.operationId
          ..revokeDeviceId = request.revokeDeviceId
          ..nextMembershipManifest = _encodeBinaryForRequest(
            request.nextMembershipManifest,
          )
          ..nextMembershipManifestDigest =
              request.nextMembershipManifestDigest.encoded
          ..nextRecoveryCapsuleVersion = request.nextRecoveryCapsuleVersion
          ..nextRecoveryCapsule = _encodeBinaryForRequest(
            request.nextRecoveryCapsule,
          )
          ..envelopes.replace(
            request.envelopes.map(_toGeneratedRotationEnvelope),
          );
        final authorization = request.authorization;
        if (authorization != null) {
          builder
            ..selfRevocationMutationId = authorization.mutationId
            ..selfRevocationIntentDigest = _encodeBinaryForRequest(
              authorization.intentDigest,
            );
        }
      });
      final response = await _client.getDeviceApi().commitDeviceRotation(
        commitDeviceRotationRequest: generatedRequest,
        headers: _requireFullSessionHeaders(),
        extra: _strictResponseExtra,
      );
      return _parseDeviceRotationResult(
        response.extra[_rawResponseKey],
        request: request,
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
  Future<CloudSyncDeviceSession> revokeDevice(String deviceId) async {
    _requireClientIdentifier(deviceId);
    throw const CloudSyncException(
      kind: CloudSyncFailureKind.conflict,
      retryable: false,
      serverCode: 'SYNC_DEVICE_ROTATION_REQUIRED',
    );
  }

  Map<String, String> _requireFullSessionHeaders() {
    return _authorizationHeaders(_requireFullSessionToken().value);
  }

  Map<String, String> _requireDataRekeyHeaders() {
    final bearerOverride = _dataRekeyBearerOverride;
    return bearerOverride == null
        ? _requireFullSessionHeaders()
        : _authorizationHeaders(bearerOverride);
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

final class _CloudSyncAccountRecoveryDataRekeyTransport
    implements CloudSyncDataRekeyTransport {
  _CloudSyncAccountRecoveryDataRekeyTransport(
    CloudSyncClient owner,
    CloudSyncAccountRecoveryToken recoveryToken,
  ) : _delegate = CloudSyncClient._(
        baseUrl: owner.baseUrl,
        dio: owner._dio,
        client: owner._client,
        now: owner._now,
        dataRekeyBearerOverride: recoveryToken.value,
      );

  final CloudSyncClient _delegate;

  @override
  Future<CloudSyncDataRekeyState> getDataRekeyState() {
    return _delegate.getDataRekeyState();
  }

  @override
  Future<CloudSyncDataRekeyLeaseClaim> claimDataRekeyLease(
    CloudSyncDataRekeyLeaseClaimRequest request,
  ) {
    return _delegate.claimDataRekeyLease(request);
  }

  @override
  Future<CloudSyncDataRekeySourceRecordPage> listDataRekeySourceRecords(
    CloudSyncDataRekeySourceRecordListRequest request,
  ) {
    return _delegate.listDataRekeySourceRecords(request);
  }

  @override
  Future<CloudSyncDataRekeySourceAttachmentPage> listDataRekeySourceAttachments(
    CloudSyncDataRekeySourceAttachmentListRequest request,
  ) {
    return _delegate.listDataRekeySourceAttachments(request);
  }

  @override
  Future<CloudSyncDataRekeyRecordStageResult> stageDataRekeyRecord(
    CloudSyncDataRekeyRecordStageRequest request,
  ) {
    return _delegate.stageDataRekeyRecord(request);
  }

  @override
  Future<CloudSyncDataRekeyAttachmentStageResult> stageDataRekeyAttachment(
    CloudSyncDataRekeyAttachmentStageRequest request,
  ) {
    return _delegate.stageDataRekeyAttachment(request);
  }

  @override
  Future<CloudSyncDataRekeyFinalizeOutcome> finalizeDataRekey(
    CloudSyncDataRekeyFinalizeRequest request,
  ) {
    return _delegate.finalizeDataRekey(request);
  }
}

api.AttachmentManifestChunk _toGeneratedManifestChunk(
  CloudSyncAttachmentManifestChunk chunk,
) {
  return api.AttachmentManifestChunk(
    (builder) => builder
      ..chunkIndex = chunk.chunkIndex
      ..ciphertextBytes = chunk.ciphertextBytes,
  );
}

api.UnsignedAccountSecurityStateEnvelope _toGeneratedRotationEnvelope(
  CloudSyncDeviceRotationEnvelope envelope,
) {
  return api.UnsignedAccountSecurityStateEnvelope(
    (builder) => builder
      ..targetDeviceId = envelope.targetDeviceId
      ..envelopeVersion = envelope.envelopeVersion
      ..keyEpoch = envelope.keyEpoch
      ..accountKeyEnvelope = _encodeFixedBinaryForRequest(
        envelope.accountKeyEnvelope,
        cloudSyncAccountKeyEnvelopeBytes,
      ),
  );
}

CloudSyncAttachmentIdentity _attachmentIdentity({
  required String attachmentId,
  required String uploadId,
  required int chunkKeyEpoch,
  required int manifestKeyEpoch,
  required int manifestRevision,
}) {
  return CloudSyncAttachmentIdentity(
    attachmentId: attachmentId,
    uploadId: uploadId,
    chunkKeyEpoch: chunkKeyEpoch,
    manifestKeyEpoch: manifestKeyEpoch,
    manifestRevision: manifestRevision,
  );
}

void _requireAttachmentCreateResponseMatches({
  required CloudSyncAttachmentCreateUploadRequest request,
  required CloudSyncAttachmentIdentity identity,
  required int chunkCount,
  required int totalCiphertextBytes,
}) {
  if (identity.attachmentId != request.attachmentId ||
      identity.chunkKeyEpoch != request.chunkKeyEpoch ||
      identity.manifestKeyEpoch != request.manifestKeyEpoch ||
      identity.manifestRevision != request.manifestRevision ||
      chunkCount != request.chunkCount ||
      totalCiphertextBytes != request.totalCiphertextBytes) {
    throw const FormatException('服务端返回的附件上传身份与请求不一致');
  }
}

void _requireMatchingAttachmentIdentity(
  CloudSyncAttachmentIdentity expected,
  CloudSyncAttachmentIdentity actual,
) {
  if (actual.attachmentId != expected.attachmentId ||
      actual.uploadId != expected.uploadId ||
      actual.chunkKeyEpoch != expected.chunkKeyEpoch ||
      actual.manifestKeyEpoch != expected.manifestKeyEpoch ||
      actual.manifestRevision != expected.manifestRevision) {
    throw const FormatException('服务端返回了其他附件上传身份');
  }
}

void _requireMatchingAttachmentChunkIdentity(
  CloudSyncAttachmentIdentity expected,
  CloudSyncAttachmentIdentity actual,
) {
  if (actual.attachmentId != expected.attachmentId ||
      actual.uploadId != expected.uploadId ||
      actual.chunkKeyEpoch != expected.chunkKeyEpoch) {
    throw const FormatException('服务端返回了其他附件分块身份');
  }
}

void _requireStrictAttachmentResponse(
  Object? rawResponse,
  Set<String> expectedDataKeys, {
  bool validateChunks = false,
}) {
  final envelope = copyCloudSyncJsonMap(rawResponse);
  _requireExactAttachmentKeys(
    envelope,
    _attachmentResponseEnvelopeKeys,
    '附件响应',
  );
  final data = copyCloudSyncJsonMap(envelope['data']);
  _requireExactAttachmentKeys(data, expectedDataKeys, '附件响应 data');
  if (!validateChunks) return;

  final chunks = data['chunks'];
  if (chunks is! List<Object?>) {
    throw const FormatException('附件响应 chunks 必须为数组');
  }
  for (final chunk in chunks) {
    _requireExactAttachmentKeys(
      copyCloudSyncJsonMap(chunk),
      _attachmentManifestChunkKeys,
      '附件响应 chunk',
    );
  }
}

void _requireExactAttachmentKeys(
  CloudSyncJsonMap value,
  Set<String> expectedKeys,
  String context,
) {
  if (value.length != expectedKeys.length ||
      !value.keys.every(expectedKeys.contains)) {
    throw FormatException('$context 字段集合无效');
  }
}

Uint8List _decodeCanonicalAttachmentCiphertext(
  String value, {
  required int expectedLength,
  required int maximumLength,
}) {
  if (expectedLength < 1 ||
      expectedLength > maximumLength ||
      value.length != (expectedLength * 8 + 5) ~/ 6 ||
      !_base64UrlPattern.hasMatch(value)) {
    throw const FormatException('服务端返回了无效的附件密文');
  }
  try {
    final padding = '=' * ((4 - value.length % 4) % 4);
    final decoded = base64Url.decode('$value$padding');
    if (decoded.length != expectedLength ||
        base64Url.encode(decoded).replaceAll('=', '') != value) {
      throw const FormatException('服务端返回了非规范附件密文');
    }
    return Uint8List.fromList(decoded);
  } on FormatException {
    throw const FormatException('服务端返回了无效的附件密文');
  }
}

api.SyncMutation _toGeneratedMutation(CloudSyncRecordMutation mutation) {
  return switch (mutation) {
    CloudSyncPutRecordMutation() => _toGeneratedPutMutation(mutation),
  };
}

api.SyncMutation _toGeneratedPutMutation(CloudSyncPutRecordMutation mutation) {
  final record = mutation.state.record;
  return api.SyncMutation(
    (builder) => builder
      ..mutationId = mutation.mutationId
      ..recordId = mutation.recordId.wireValue
      ..expectedRevision = mutation.expectedRevision
      ..operation = api.SyncMutationOperationEnum.put
      ..envelopeVersion = e2eeAccountRecordEnvelopeVersion
      ..keyEpoch = record.keyEpoch
      ..ciphertext = _encodeSyncCiphertext(record.ciphertext),
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
  if (change.operation != api.SyncChangeOperationEnum.put) {
    throw const FormatException('服务端返回了未知的同步增量');
  }
  _validateRecordMetadata(
    recordId: change.recordId,
    revision: change.revision,
    sequence: change.changeSeq,
    updatedByDeviceId: change.updatedByDeviceId,
  );
  _validateEncryptedRecord(
    envelopeVersion: change.envelopeVersion,
    keyEpoch: change.keyEpoch,
    ciphertext: change.ciphertext,
    ciphertextBytes: change.ciphertextBytes,
    description: 'put 增量',
  );
  final ciphertext = _decodeSyncCiphertext(
    change.ciphertext,
    change.ciphertextBytes,
  );
  return CloudSyncPutRecordChange(
    changeSeq: change.changeSeq,
    revision: change.revision,
    updatedAt: change.updatedAt.toUtc(),
    updatedByDeviceId: change.updatedByDeviceId,
    record: E2eeUntrustedAccountRecordEnvelope.fromTransport(
      recordId: E2eeUntrustedAccountRecordId.fromTransport(change.recordId),
      envelopeVersion: change.envelopeVersion,
      keyEpoch: change.keyEpoch,
      ciphertext: ciphertext,
    ),
  );
}

CloudSyncEncryptedRecord _fromRecordState(api.SyncRecord record) {
  _validateRecordMetadata(
    recordId: record.recordId,
    revision: record.revision,
    sequence: record.lastChangeSeq,
    updatedByDeviceId: record.updatedByDeviceId,
  );
  _validateEncryptedRecord(
    envelopeVersion: record.envelopeVersion,
    keyEpoch: record.keyEpoch,
    ciphertext: record.ciphertext,
    ciphertextBytes: record.ciphertextBytes,
    description: '快照记录',
  );
  final ciphertext = _decodeSyncCiphertext(
    record.ciphertext,
    record.ciphertextBytes,
  );
  return CloudSyncEncryptedRecord(
    revision: record.revision,
    updatedAt: record.updatedAt.toUtc(),
    updatedByDeviceId: record.updatedByDeviceId,
    lastChangeSeq: record.lastChangeSeq,
    record: E2eeUntrustedAccountRecordEnvelope.fromTransport(
      recordId: E2eeUntrustedAccountRecordId.fromTransport(record.recordId),
      envelopeVersion: record.envelopeVersion,
      keyEpoch: record.keyEpoch,
      ciphertext: ciphertext,
    ),
  );
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
        _requireClientKeyEpoch(record.keyEpoch);
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

String _requireValidChangePage({
  required int changeCount,
  required int pageLimit,
  required String? requestedCursor,
  required String? nextCursor,
  required bool hasMore,
}) {
  if (changeCount > pageLimit ||
      nextCursor == null ||
      !_isValidSyncCursor(nextCursor) ||
      (hasMore && changeCount == 0) ||
      (changeCount > 0 && nextCursor == requestedCursor)) {
    throw const FormatException('服务端返回了无效的增量分页数据');
  }
  return nextCursor;
}

void _validateResetRequired({
  required int changeCount,
  required String? nextCursor,
  required bool hasMore,
}) {
  if (changeCount != 0 || nextCursor != null || hasMore) {
    throw const FormatException('服务端返回了无效的游标重置数据');
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

void _validateSnapshotOrdering(List<CloudSyncEncryptedRecord> records) {
  int? previousSequence;
  for (final record in records) {
    final previous = previousSequence;
    if (previous != null && record.lastChangeSeq <= previous) {
      throw const FormatException('服务端返回了乱序的快照历史');
    }
    previousSequence = record.lastChangeSeq;
  }
}

void _validateEncryptedRecord({
  required int envelopeVersion,
  required int keyEpoch,
  required String ciphertext,
  required int ciphertextBytes,
  required String description,
}) {
  if (envelopeVersion != e2eeAccountRecordEnvelopeVersion ||
      keyEpoch < 1 ||
      keyEpoch > 0xffffffff ||
      ciphertextBytes < 1 ||
      ciphertextBytes > e2eeAccountRecordMaxCiphertextBytes ||
      _syncCiphertextByteLength(ciphertext) != ciphertextBytes) {
    throw FormatException('服务端返回了无效的$description');
  }
}

void _validateSnapshotPage({
  required int recordCount,
  required int pageLimit,
  required String? requestedSnapshotCursor,
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
      (hasMore &&
          recordCount > 0 &&
          nextSnapshotCursor == requestedSnapshotCursor) ||
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

CloudSyncJsonMap _strictResponseData(
  Object? rawResponse,
  Set<String> expectedDataKeys,
  String context,
) {
  final envelope = copyCloudSyncJsonMap(rawResponse);
  _requireRawExactKeys(envelope, _strictResponseEnvelopeKeys, context);
  final data = copyCloudSyncJsonMap(envelope['data']);
  _requireRawExactKeys(data, expectedDataKeys, '$context data');
  return data;
}

CloudSyncJsonMap _strictVariantResponseData(
  Object? rawResponse,
  String context,
) {
  final envelope = copyCloudSyncJsonMap(rawResponse);
  _requireRawExactKeys(envelope, _strictResponseEnvelopeKeys, context);
  return copyCloudSyncJsonMap(envelope['data']);
}

E2eeAccountRecoveryChallenge _parseAccountRecoveryChallenge(
  Object? rawResponse, {
  required String expectedAttemptId,
}) {
  final data = _strictResponseData(
    rawResponse,
    _accountRecoveryChallengeDataKeys,
    '账户恢复 challenge 响应',
  );
  if (_rawString(data, 'action') != 'challenge' ||
      !const <String>{
        'created',
        'replayed',
      }.contains(_rawString(data, 'result')) ||
      _rawInt(data, 'protocolVersion') != e2eeAccountRecoveryProtocolVersion ||
      _rawString(data, 'attemptId') != expectedAttemptId) {
    throw const FormatException('账户恢复 challenge 未绑定原请求');
  }
  return E2eeAccountRecoveryChallenge(
    attemptId: expectedAttemptId,
    requestDigest: _decodeFixedBinaryFromResponse(
      _rawString(data, 'requestDigest'),
      32,
    ),
    challengeFrame: _decodeFixedBinaryFromResponse(
      _rawString(data, 'challengeFrame'),
      e2eeAccountRecoveryChallengeFrameBytes,
    ),
    sealedNonce: _decodeFixedBinaryFromResponse(
      _rawString(data, 'sealedNonce'),
      e2eeAccountRecoverySealedNonceBytes,
    ),
    securityGeneration: _rawInt(data, 'securityGeneration'),
    keyEpoch: _rawInt(data, 'keyEpoch'),
    membershipManifestDigest: _decodeFixedBinaryFromResponse(
      _rawString(data, 'membershipManifestDigest'),
      32,
    ),
    recoveryPublicKeyVersion: _rawInt(data, 'recoveryPublicKeyVersion'),
    recoveryPublicKey: _decodeFixedBinaryFromResponse(
      _rawString(data, 'recoveryPublicKey'),
      cloudSyncRecoveryPublicKeyBytes,
    ),
    recoveryCapsuleVersion: _rawInt(data, 'recoveryCapsuleVersion'),
    recoveryCapsule: _decodeRangedBinaryFromResponse(
      _rawString(data, 'recoveryCapsule'),
      minimumBytes: 1,
      maximumBytes: cloudSyncRecoveryCapsuleMaximumBytes,
    ),
    recoveryCapsuleDigest: _decodeFixedBinaryFromResponse(
      _rawString(data, 'recoveryCapsuleDigest'),
      32,
    ),
    dataState: _parseAccountRecoveryDataState(data['dataState']),
    expiresAt: _rawUtcDateTime(data, 'expiresAt'),
  );
}

E2eeAccountRecoveryReplacementChallenge
_parseAccountRecoveryReplacementChallenge(
  Object? rawResponse, {
  required String expectedAttemptId,
  required String expectedDeviceId,
  required E2eeAccountRecoveryReplacementChallengeRequest request,
}) {
  final data = _strictResponseData(
    rawResponse,
    _accountRecoveryReplacementChallengeDataKeys,
    '账户恢复替换 challenge 响应',
  );
  final result = switch (_rawString(data, 'result')) {
    'created' => E2eeAccountRecoveryReplacementChallengeResult.created,
    'replayed' => E2eeAccountRecoveryReplacementChallengeResult.replayed,
    _ => throw const FormatException('账户恢复替换 challenge 结果无效'),
  };
  if (_rawInt(data, 'protocolVersion') != e2eeAccountRecoveryProtocolVersion ||
      _rawString(data, 'challengeId') != request.challengeId ||
      _rawString(data, 'attemptId') != expectedAttemptId) {
    throw const FormatException('账户恢复替换 challenge 未绑定原请求');
  }
  final deviceState = copyCloudSyncJsonMap(data['deviceState']);
  _requireRawExactKeys(
    deviceState,
    _accountRecoveryReplacementDeviceStateKeys,
    '账户恢复替换 challenge deviceState',
  );
  final securityState = copyCloudSyncJsonMap(data['securityState']);
  _requireRawExactKeys(
    securityState,
    _accountRecoveryReplacementSecurityStateKeys,
    '账户恢复替换 challenge securityState',
  );
  final dataState = copyCloudSyncJsonMap(data['dataState']);
  _requireRawExactKeys(
    dataState,
    _accountRecoveryReplacementDataStateKeys,
    '账户恢复替换 challenge dataState',
  );
  if (_rawString(dataState, 'phase') != 'ready') {
    throw const FormatException('账户恢复替换 challenge 数据状态必须就绪');
  }
  final sourceCompletion = CloudSyncDataRekeyCompletion.fromJson(
    copyCloudSyncJsonMap(data['sourceCompletion']),
  );
  final challenge = E2eeAccountRecoveryReplacementChallenge(
    result: result,
    challengeId: request.challengeId,
    attemptId: expectedAttemptId,
    requestDigest: _decodeFixedBinaryFromResponse(
      _rawString(data, 'requestDigest'),
      cloudSyncMembershipManifestDigestBytes,
    ),
    challengeFrame: _decodeFixedBinaryFromResponse(
      _rawString(data, 'challengeFrame'),
      e2eeAccountRecoveryReplacementChallengeFrameBytes,
    ),
    sealedNonce: _decodeFixedBinaryFromResponse(
      _rawString(data, 'sealedNonce'),
      e2eeAccountRecoverySealedNonceBytes,
    ),
    deviceKeyVersion: _rawInt(deviceState, 'keyVersion'),
    deviceSigningPublicKey: _decodeFixedBinaryFromResponse(
      _rawString(deviceState, 'signingPublicKey'),
      cloudSyncDevicePublicKeyBytes,
    ),
    deviceKeyAgreementPublicKey: _decodeFixedBinaryFromResponse(
      _rawString(deviceState, 'keyAgreementPublicKey'),
      cloudSyncDevicePublicKeyBytes,
    ),
    securityGeneration: _rawInt(securityState, 'generation'),
    keyEpoch: _rawInt(securityState, 'keyEpoch'),
    membershipManifest: _decodeRangedBinaryFromResponse(
      _rawString(securityState, 'membershipManifest'),
      minimumBytes: cloudSyncMembershipManifestMinimumBytes,
      maximumBytes: cloudSyncMembershipManifestMaximumBytes,
    ),
    membershipManifestDigest: _decodeFixedBinaryFromResponse(
      _rawString(securityState, 'membershipManifestDigest'),
      cloudSyncMembershipManifestDigestBytes,
    ),
    membershipOperationId: _rawString(securityState, 'membershipOperationId'),
    recoveryPublicKeyVersion: _rawInt(
      securityState,
      'recoveryPublicKeyVersion',
    ),
    recoveryPublicKey: _decodeFixedBinaryFromResponse(
      _rawString(securityState, 'recoveryPublicKey'),
      cloudSyncRecoveryPublicKeyBytes,
    ),
    recoveryCapsuleVersion: _rawInt(securityState, 'recoveryCapsuleVersion'),
    recoveryCapsule: _decodeRangedBinaryFromResponse(
      _rawString(securityState, 'recoveryCapsule'),
      minimumBytes: 1,
      maximumBytes: cloudSyncRecoveryCapsuleMaximumBytes,
    ),
    recoveryCapsuleDigest: _decodeFixedBinaryFromResponse(
      _rawString(securityState, 'recoveryCapsuleDigest'),
      cloudSyncMembershipManifestDigestBytes,
    ),
    dataGeneration: _rawInt(dataState, 'dataGeneration'),
    dataKeyEpoch: _rawInt(dataState, 'dataKeyEpoch'),
    sourceRekeyOperationId: _rawString(dataState, 'sourceRekeyOperationId'),
    sourceCompletion: sourceCompletion,
    expiresAt: _rawUtcDateTime(data, 'expiresAt'),
  );
  if (challenge.securityGeneration != request.expectedGeneration ||
      challenge.keyEpoch != request.expectedKeyEpoch ||
      !_sameResponseBytes(
        challenge.membershipManifestDigest,
        request.expectedMembershipManifestDigest,
      ) ||
      challenge.membershipOperationId !=
          request.expectedMembershipOperationId ||
      challenge.dataGeneration != request.dataGeneration ||
      challenge.dataKeyEpoch != request.dataKeyEpoch ||
      challenge.sourceRekeyOperationId != request.sourceRekeyOperationId ||
      sourceCompletion.issuerDeviceId != expectedDeviceId ||
      !_sameResponseBytes(
        sourceCompletion.proofDigest,
        request.sourceCompletionProofDigest,
      )) {
    throw const FormatException('账户恢复替换 challenge 快照未绑定创建请求');
  }
  return challenge;
}

E2eeAccountRecoveryAuthorizedState _parseAccountRecoveryAuthorizedState(
  Object? rawResponse,
) {
  final data = _strictResponseData(
    rawResponse,
    _accountRecoveryStateDataKeys,
    '账户恢复远程状态响应',
  );
  if (_rawInt(data, 'protocolVersion') != e2eeAccountRecoveryProtocolVersion) {
    throw const FormatException('账户恢复远程状态尚不可接管');
  }
  final status = switch (_rawString(data, 'status')) {
    'authorized' => E2eeAccountRecoveryRemoteStatus.authorized,
    'resume-committed' => E2eeAccountRecoveryRemoteStatus.resumeCommitted,
    'replacement-committed' =>
      E2eeAccountRecoveryRemoteStatus.replacementCommitted,
    _ => throw const FormatException('账户恢复远程状态无效'),
  };
  final nextAction = switch (_rawString(data, 'nextAction')) {
    'recover-resume' => E2eeAccountRecoveryNextAction.recoverResume,
    'finish-first-data-rekey' =>
      E2eeAccountRecoveryNextAction.finishFirstDataRekey,
    'create-replacement-challenge' =>
      E2eeAccountRecoveryNextAction.createReplacementChallenge,
    'recover-replace' => E2eeAccountRecoveryNextAction.recoverReplace,
    'finish-second-data-rekey' =>
      E2eeAccountRecoveryNextAction.finishSecondDataRekey,
    _ => throw const FormatException('账户恢复远程状态下一步无效'),
  };
  return E2eeAccountRecoveryAuthorizedState(
    attemptId: _rawString(data, 'attemptId'),
    authorizedAt: _rawUtcDateTime(data, 'authorizedAt'),
    recoveryTokenExpiresAt: _rawUtcDateTime(data, 'recoveryTokenExpiresAt'),
    status: status,
    nextAction: nextAction,
    securityState: CloudSyncAccountSecurityState.fromJson(
      copyCloudSyncJsonMap(data['securityState']),
    ),
    dataState: _parseAccountRecoveryDataState(data['dataState']),
  );
}

E2eeAccountRecoveryDataState _parseAccountRecoveryDataState(Object? raw) {
  final data = copyCloudSyncJsonMap(raw);
  _requireRawExactKeys(data, _accountRecoveryDataStateKeys, '账户恢复数据状态');
  final phase = _rawString(data, 'phase');
  final operationId = data['operationId'];
  final targetKeyEpoch = data['targetKeyEpoch'];
  return switch (phase) {
    'ready' when operationId == null && targetKeyEpoch == null =>
      E2eeAccountRecoveryDataState.ready(
        dataGeneration: _rawInt(data, 'dataGeneration'),
        dataKeyEpoch: _rawInt(data, 'dataKeyEpoch'),
      ),
    'rekey-pending' when operationId is String && targetKeyEpoch is int =>
      E2eeAccountRecoveryDataState.rekeyPending(
        dataGeneration: _rawInt(data, 'dataGeneration'),
        dataKeyEpoch: _rawInt(data, 'dataKeyEpoch'),
        operationId: operationId,
        targetKeyEpoch: targetKeyEpoch,
      ),
    _ => throw const FormatException('账户恢复数据状态字段组合无效'),
  };
}

E2eeAccountRecoveryAuthorizationReceipt
_parseAccountRecoveryAuthorizationReceipt(
  Object? rawResponse, {
  required String expectedAttemptId,
}) {
  final data = _strictResponseData(
    rawResponse,
    _accountRecoveryAuthorizationDataKeys,
    '账户恢复授权响应',
  );
  final result = switch (_rawString(data, 'result')) {
    'authorized' => E2eeAccountRecoveryAuthorizationResult.authorized,
    'replayed' => E2eeAccountRecoveryAuthorizationResult.replayed,
    _ => throw const FormatException('账户恢复授权结果无效'),
  };
  final nextAction = switch (_rawString(data, 'nextAction')) {
    'recover-resume' => E2eeAccountRecoveryNextAction.recoverResume,
    'recover-replace' => E2eeAccountRecoveryNextAction.recoverReplace,
    _ => throw const FormatException('账户恢复授权下一步无效'),
  };
  if (_rawString(data, 'action') != 'authorized' ||
      _rawString(data, 'status') != 'authorized' ||
      _rawInt(data, 'protocolVersion') != e2eeAccountRecoveryProtocolVersion ||
      _rawString(data, 'attemptId') != expectedAttemptId) {
    throw const FormatException('账户恢复授权响应未绑定原请求');
  }
  return E2eeAccountRecoveryAuthorizationReceipt(
    attemptId: expectedAttemptId,
    result: result,
    nextAction: nextAction,
    recoveryTokenExpiresAt: _rawUtcDateTime(data, 'recoveryTokenExpiresAt'),
  );
}

E2eeAccountRecoveryCommitReceipt _parseAccountRecoveryCommitReceipt(
  Object? rawResponse, {
  required E2eeAccountRecoveryCommitKind expectedKind,
  required String expectedAttemptId,
  required String expectedMembershipOperationId,
  required String expectedRekeyOperationId,
  required int expectedGeneration,
  required int expectedKeyEpoch,
  required E2eeAccountRecoveryNextAction expectedNextAction,
}) {
  final data = _strictResponseData(
    rawResponse,
    _accountRecoveryCommitDataKeys,
    '账户恢复成员提交响应',
  );
  final result = switch (_rawString(data, 'result')) {
    'committed' => E2eeAccountRecoveryCommitResult.committed,
    'replayed' => E2eeAccountRecoveryCommitResult.replayed,
    _ => throw const FormatException('账户恢复成员提交结果无效'),
  };
  final kind = switch (_rawString(data, 'status')) {
    'resume-committed' => E2eeAccountRecoveryCommitKind.resume,
    'replacement-committed' => E2eeAccountRecoveryCommitKind.replacement,
    _ => throw const FormatException('账户恢复成员提交状态无效'),
  };
  final nextAction = switch (_rawString(data, 'nextAction')) {
    'finish-first-data-rekey' =>
      E2eeAccountRecoveryNextAction.finishFirstDataRekey,
    'finish-second-data-rekey' =>
      E2eeAccountRecoveryNextAction.finishSecondDataRekey,
    _ => throw const FormatException('账户恢复成员提交下一步无效'),
  };
  final receipt = E2eeAccountRecoveryCommitReceipt(
    result: result,
    kind: kind,
    attemptId: _rawString(data, 'attemptId'),
    membershipOperationId: _rawString(data, 'membershipOperationId'),
    rekeyOperationId: _rawString(data, 'rekeyOperationId'),
    generation: _rawInt(data, 'generation'),
    keyEpoch: _rawInt(data, 'keyEpoch'),
    nextAction: nextAction,
  );
  if (receipt.kind != expectedKind ||
      receipt.attemptId != expectedAttemptId ||
      receipt.membershipOperationId != expectedMembershipOperationId ||
      receipt.rekeyOperationId != expectedRekeyOperationId ||
      receipt.generation != expectedGeneration ||
      receipt.keyEpoch != expectedKeyEpoch ||
      receipt.nextAction != expectedNextAction) {
    throw const FormatException('账户恢复成员提交响应未绑定原请求');
  }
  return receipt;
}

CloudSyncAccountSecurityState _parseAccountSecurityState(Object? rawResponse) {
  return CloudSyncAccountSecurityState.fromJson(
    _strictResponseData(rawResponse, _accountSecurityStateDataKeys, '账户安全状态响应'),
  );
}

CloudSyncDataRekeyState _parseDataRekeyState(Object? rawResponse) {
  final envelope = copyCloudSyncJsonMap(rawResponse);
  _requireRawExactKeys(
    envelope,
    _strictResponseEnvelopeKeys,
    'data-rekey 状态响应',
  );
  return CloudSyncDataRekeyState.fromJson(
    copyCloudSyncJsonMap(envelope['data']),
  );
}

CloudSyncDataRekeyLeaseClaim _parseDataRekeyLeaseClaim(
  Object? rawResponse, {
  required CloudSyncDataRekeyLeaseClaimRequest request,
}) {
  final envelope = copyCloudSyncJsonMap(rawResponse);
  _requireRawExactKeys(
    envelope,
    _strictResponseEnvelopeKeys,
    'data-rekey 租约声明响应',
  );
  return CloudSyncDataRekeyLeaseClaim.fromJson(
    copyCloudSyncJsonMap(envelope['data']),
    request: request,
  );
}

CloudSyncDataRekeySourceRecordPage _parseDataRekeySourceRecordPage(
  Object? rawResponse, {
  required CloudSyncDataRekeySourceRecordListRequest request,
}) {
  return CloudSyncDataRekeySourceRecordPage.fromJson(
    _strictResponseData(rawResponse, const <String>{
      'records',
      'nextAfterRecordId',
      'hasMore',
    }, 'data-rekey 源记录分页响应'),
    request: request,
  );
}

CloudSyncDataRekeySourceAttachmentPage _parseDataRekeySourceAttachmentPage(
  Object? rawResponse, {
  required CloudSyncDataRekeySourceAttachmentListRequest request,
}) {
  return CloudSyncDataRekeySourceAttachmentPage.fromJson(
    _strictResponseData(rawResponse, const <String>{
      'attachments',
      'nextAfterAttachmentId',
      'nextAfterUploadId',
      'hasMore',
    }, 'data-rekey 源附件分页响应'),
    request: request,
  );
}

CloudSyncDataRekeyRecordStageResult _parseDataRekeyRecordStageResult(
  Object? rawResponse, {
  required CloudSyncDataRekeyRecordStageRequest request,
}) {
  return CloudSyncDataRekeyRecordStageResult.fromJson(
    _strictResponseData(rawResponse, const <String>{
      'result',
      'operationId',
      'mutationId',
      'sourceRecordId',
      'targetRecordId',
      'leaseVersion',
    }, 'data-rekey 记录暂存响应'),
    request: request,
  );
}

CloudSyncDataRekeyAttachmentStageResult _parseDataRekeyAttachmentStageResult(
  Object? rawResponse, {
  required CloudSyncDataRekeyAttachmentStageRequest request,
}) {
  return CloudSyncDataRekeyAttachmentStageResult.fromJson(
    _strictResponseData(rawResponse, const <String>{
      'result',
      'operationId',
      'mutationId',
      'attachmentId',
      'uploadId',
      'manifestRevision',
      'leaseVersion',
    }, 'data-rekey 附件暂存响应'),
    request: request,
  );
}

CloudSyncDataRekeyFinalizeOutcome _parseDataRekeyFinalizeOutcome(
  Object? rawResponse, {
  required CloudSyncDataRekeyFinalizeRequest request,
}) {
  final envelope = copyCloudSyncJsonMap(rawResponse);
  _requireRawExactKeys(
    envelope,
    _strictResponseEnvelopeKeys,
    'data-rekey 最终提交响应',
  );
  return CloudSyncDataRekeyFinalizeOutcome.fromJson(
    copyCloudSyncJsonMap(envelope['data']),
    request: request,
  );
}

CloudSyncAccountSecurityHistoryPage _parseAccountSecurityStateHistory(
  Object? rawResponse, {
  required int expectedAfterGeneration,
  required int expectedPageSize,
}) {
  final page = CloudSyncAccountSecurityHistoryPage.fromJson(
    _strictResponseData(
      rawResponse,
      _accountSecurityStateHistoryDataKeys,
      '账户安全状态历史响应',
    ),
  );
  if (page.afterGeneration != expectedAfterGeneration ||
      page.pageSize != expectedPageSize) {
    throw const FormatException('账户安全状态历史未回显请求分页');
  }
  return page;
}

CloudSyncDeviceRotationResult _parseDeviceRotationResult(
  Object? rawResponse, {
  required CloudSyncDeviceRotationRequest request,
}) {
  final result = CloudSyncDeviceRotationResult.fromJson(
    _strictResponseData(
      rawResponse,
      request.authorization == null
          ? _directDeviceRotationResultDataKeys
          : _selfRevocationDeviceRotationResultDataKeys,
      '设备轮换响应',
    ),
    authorization: request.authorization,
  );
  if (result.operationId != request.operationId ||
      result.revokedDeviceId != request.revokeDeviceId ||
      result.fromGeneration != request.expectedGeneration ||
      result.generation != request.expectedGeneration + 1 ||
      result.keyEpoch != request.expectedKeyEpoch + 1 ||
      result.membershipManifestDigest.encoded !=
          request.nextMembershipManifestDigest.encoded) {
    throw const FormatException('设备轮换响应未绑定原始请求');
  }
  return result;
}

void _requireRawExactKeys(
  CloudSyncJsonMap value,
  Set<String> expectedKeys,
  String context,
) {
  if (value.length != expectedKeys.length ||
      !value.keys.every(expectedKeys.contains)) {
    throw FormatException('$context 字段集合无效');
  }
}

String _rawString(CloudSyncJsonMap value, String key) {
  final field = value[key];
  if (field is! String || field.isEmpty) {
    throw FormatException('$key 必须为非空字符串');
  }
  return field;
}

int _rawInt(CloudSyncJsonMap value, String key) {
  final field = value[key];
  if (field is! int) {
    throw FormatException('$key 必须为整数');
  }
  return field;
}

bool _sameResponseBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

DateTime _rawUtcDateTime(CloudSyncJsonMap value, String key) {
  final raw = _rawString(value, key);
  final parsed = DateTime.tryParse(raw);
  if (parsed == null || !parsed.isUtc || parsed.toIso8601String() != raw) {
    throw FormatException('$key 必须为规范 UTC 时间');
  }
  return parsed;
}

void _requireRawProtocolVersion(CloudSyncJsonMap data) {
  if (_rawInt(data, 'protocolVersion') != cloudSyncOpaqueProtocolVersion) {
    throw const FormatException('服务端返回了不支持的认证协议版本');
  }
}

CloudSyncDevicePairingTarget _pairingTargetFromRaw(CloudSyncJsonMap target) {
  _requireRawExactKeys(target, _pairingTargetKeys, '配对查询 targetDevice');
  return CloudSyncDevicePairingTarget(
    id: _rawString(target, 'id'),
    name: _rawString(target, 'name'),
    platform: _fromPlatformName(_rawString(target, 'platform')),
    clientVersion: _rawString(target, 'clientVersion'),
    keyVersion: _rawInt(target, 'keyVersion'),
    authGeneration: _rawInt(target, 'authGeneration'),
    signingPublicKey: _decodeFixedBinaryFromResponse(
      _rawString(target, 'signingPublicKey'),
      cloudSyncDevicePublicKeyBytes,
    ),
    keyAgreementPublicKey: _decodeFixedBinaryFromResponse(
      _rawString(target, 'keyAgreementPublicKey'),
      cloudSyncDevicePublicKeyBytes,
    ),
  );
}

CloudSyncAuthenticatedSession _parseRegistrationSession(Object? rawResponse) {
  final data = _strictResponseData(
    rawResponse,
    _registrationSessionDataKeys,
    '注册响应',
  );
  _requireRawProtocolVersion(data);
  if (_rawString(data, 'result') != 'authenticated') {
    throw const FormatException('服务端返回了未知的注册结果');
  }
  final securityState = CloudSyncAccountSecurityState.fromJson(
    copyCloudSyncJsonMap(data['securityState']),
  );
  return _authenticatedSessionFromRawMaps(
    data: data,
    keyEpoch: securityState.keyEpoch,
    securityState: securityState,
  );
}

CloudSyncAuthenticatedSession _parseCurrentAuthenticatedSession(
  Object? rawResponse, {
  required CloudSyncFullSessionToken expectedToken,
}) {
  final data = _strictResponseData(
    rawResponse,
    _registrationSessionDataKeys,
    '会话读取响应',
  );
  _requireRawProtocolVersion(data);
  if (_rawString(data, 'result') != 'authenticated' ||
      _rawString(data, 'token') != expectedToken.value) {
    throw const FormatException('服务端返回的完整会话未绑定本地令牌');
  }
  final securityState = CloudSyncAccountSecurityState.fromJson(
    copyCloudSyncJsonMap(data['securityState']),
  );
  return _authenticatedSessionFromRawMaps(
    data: data,
    keyEpoch: securityState.keyEpoch,
    securityState: securityState,
  );
}

CloudSyncAuthenticatedSession _authenticatedSessionFromLogin(
  api.OpaqueLoginFinishDataOneOf data,
) {
  return _authenticatedSession(
    token: data.token,
    tokenExpiresAt: data.tokenExpiresAt,
    keyEpoch: data.keyEpoch,
    authGeneration: data.device.authGeneration,
    sessionGeneration: data.device.sessionGeneration,
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

CloudSyncDevicePairingQueryResult _parseDevicePairingQuery(
  Object? rawResponse,
) {
  final envelope = copyCloudSyncJsonMap(rawResponse);
  _requireRawExactKeys(envelope, _strictResponseEnvelopeKeys, '配对查询响应');
  final data = copyCloudSyncJsonMap(envelope['data']);
  final status = _rawString(data, 'status');
  final expectedKeys = switch (status) {
    'pending' => _pairingPendingDataKeys,
    'approved' => _pairingApprovedDataKeys,
    _ => throw const FormatException('服务端返回了未知的配对状态'),
  };
  _requireRawExactKeys(data, expectedKeys, '配对查询 data');
  _requireRawProtocolVersion(data);
  final target = _pairingTargetFromRaw(
    copyCloudSyncJsonMap(data['targetDevice']),
  );
  final common = (
    pairingId: _rawString(data, 'pairingId'),
    accountContextId: _rawString(data, 'accountContextId'),
    challenge: _decodeFixedBinaryFromResponse(
      _rawString(data, 'challenge'),
      cloudSyncDeviceChallengeBytes,
    ),
    expiresAt: _rawUtcDateTime(data, 'expiresAt'),
  );
  if (status == 'pending') {
    return CloudSyncDevicePairingPending(
      pairingId: common.pairingId,
      accountContextId: common.accountContextId,
      challenge: common.challenge,
      expiresAt: common.expiresAt,
      targetDevice: target,
    );
  }
  return CloudSyncDevicePairingApproved(
    pairingId: common.pairingId,
    accountContextId: common.accountContextId,
    challenge: common.challenge,
    expiresAt: common.expiresAt,
    targetDevice: target,
    issuerDeviceId: _rawString(data, 'issuerDeviceId'),
    issuerKeyVersion: _rawInt(data, 'issuerKeyVersion'),
    issuerAuthGeneration: _rawInt(data, 'issuerAuthGeneration'),
    issuerSigningPublicKey: _decodeFixedBinaryFromResponse(
      _rawString(data, 'issuerSigningPublicKey'),
      cloudSyncDevicePublicKeyBytes,
    ),
    issuerKeyAgreementPublicKey: _decodeFixedBinaryFromResponse(
      _rawString(data, 'issuerKeyAgreementPublicKey'),
      cloudSyncDevicePublicKeyBytes,
    ),
    keyEpoch: _rawInt(data, 'keyEpoch'),
    accountKeyEnvelope: _decodeFixedBinaryFromResponse(
      _rawString(data, 'accountKeyEnvelope'),
      cloudSyncAccountKeyEnvelopeBytes,
    ),
    deviceProof: _decodeFixedBinaryFromResponse(
      _rawString(data, 'deviceProof'),
      cloudSyncDeviceProofBytes,
    ),
    pairingAuthenticator: _decodeFixedBinaryFromResponse(
      _rawString(data, 'pairingAuthenticator'),
      cloudSyncPairingAuthenticatorBytes,
    ),
  );
}

CloudSyncAuthenticatedSession _parsePairingSession(
  Object? rawResponse, {
  required CloudSyncFullSessionToken expectedToken,
}) {
  final data = _strictResponseData(
    rawResponse,
    _pairingSessionDataKeys,
    '配对消费响应',
  );
  _requireRawProtocolVersion(data);
  if (_rawString(data, 'result') != 'authenticated') {
    throw const FormatException('服务端返回了未知的配对消费结果');
  }
  if (_rawString(data, 'token') != expectedToken.value) {
    throw const FormatException('服务端返回了其他完整会话令牌');
  }
  final securityState = CloudSyncAccountSecurityState.fromJson(
    copyCloudSyncJsonMap(data['securityState']),
  );
  final manifestDigest = CloudSyncMembershipManifestDigest.parse(
    _rawString(data, 'membershipManifestDigest'),
  );
  final receipt = CloudSyncDevicePairingConsumptionReceipt(
    pairingId: _rawString(data, 'pairingId'),
    issuerDeviceId: _rawString(data, 'issuerDeviceId'),
    keyEpoch: _rawInt(data, 'keyEpoch'),
    securityGeneration: _rawInt(data, 'securityGeneration'),
    membershipManifestDigest: manifestDigest,
  );
  return _authenticatedSessionFromRawMaps(
    data: data,
    keyEpoch: receipt.keyEpoch,
    securityState: securityState,
    pairingReceipt: receipt,
  );
}

CloudSyncAuthenticatedSession _authenticatedSessionFromRawMaps({
  required CloudSyncJsonMap data,
  required int keyEpoch,
  required CloudSyncAccountSecurityState securityState,
  CloudSyncDevicePairingConsumptionReceipt? pairingReceipt,
}) {
  final user = copyCloudSyncJsonMap(data['user']);
  final device = copyCloudSyncJsonMap(data['device']);
  _requireRawExactKeys(user, _authenticatedUserKeys, '认证响应 user');
  _requireRawExactKeys(device, _authenticatedDeviceKeys, '认证响应 device');
  return _authenticatedSession(
    token: _rawString(data, 'token'),
    tokenExpiresAt: _rawUtcDateTime(data, 'tokenExpiresAt'),
    keyEpoch: keyEpoch,
    authGeneration: _rawInt(device, 'authGeneration'),
    sessionGeneration: _rawInt(device, 'sessionGeneration'),
    userId: _rawString(user, 'id'),
    loginName: _rawString(user, 'loginName'),
    displayName: _rawString(user, 'displayName'),
    role: _rawString(user, 'role'),
    attachmentQuotaBytes: _rawInt(user, 'attachmentQuotaBytes'),
    deviceId: _rawString(device, 'id'),
    deviceName: _rawString(device, 'name'),
    platform: _rawString(device, 'platform'),
    clientVersion: _rawString(device, 'clientVersion'),
    deviceStatus: _rawString(device, 'status'),
    deviceCreatedAt: _rawUtcDateTime(device, 'createdAt'),
    securityState: securityState,
    pairingReceipt: pairingReceipt,
  );
}

CloudSyncAuthenticatedSession _authenticatedSession({
  required String token,
  required DateTime tokenExpiresAt,
  required int keyEpoch,
  required int authGeneration,
  required int sessionGeneration,
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
  CloudSyncAccountSecurityState? securityState,
  CloudSyncDevicePairingConsumptionReceipt? pairingReceipt,
}) {
  return CloudSyncAuthenticatedSession(
    token: CloudSyncFullSessionToken.parse(token),
    tokenExpiresAt: tokenExpiresAt,
    keyEpoch: keyEpoch,
    authGeneration: authGeneration,
    sessionGeneration: sessionGeneration,
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
    securityState: securityState,
    pairingReceipt: pairingReceipt,
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

String _encodeBinaryForRequest(Uint8List value) {
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

Uint8List _decodeRangedBinaryFromResponse(
  String value, {
  required int minimumBytes,
  required int maximumBytes,
}) {
  if (minimumBytes < 0 ||
      maximumBytes < minimumBytes ||
      value.isEmpty ||
      value.length > (maximumBytes * 8 + 5) ~/ 6 ||
      !_base64UrlPattern.hasMatch(value)) {
    throw const FormatException('服务端返回了无效的变长二进制字段');
  }
  try {
    final padding = '=' * ((4 - value.length % 4) % 4);
    final decoded = base64Url.decode('$value$padding');
    final canonical = base64Url.encode(decoded).replaceAll('=', '');
    if (decoded.length < minimumBytes ||
        decoded.length > maximumBytes ||
        canonical != value) {
      throw const FormatException('服务端返回了非规范变长二进制字段');
    }
    return Uint8List.fromList(decoded).asUnmodifiableView();
  } on FormatException {
    throw const FormatException('服务端返回了无效的变长二进制字段');
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

const _strictResponseMarker = 'kelivo.strict-response';
const _rawResponseKey = 'kelivo.raw-response';
const _strictResponseExtra = <String, Object>{_strictResponseMarker: true};
const _strictResponseEnvelopeKeys = <String>{'data'};
const _accountSecurityStateDataKeys = <String>{
  'generation',
  'keyEpoch',
  'dataRekeyPhase',
  'membershipManifest',
  'membershipManifestDigest',
  'recoveryPublicKeyVersion',
  'recoveryPublicKey',
  'recoveryCapsuleVersion',
  'recoveryCapsule',
  'lastOperationId',
  'updatedAt',
  'envelopes',
};
const _accountSecurityStateHistoryDataKeys = <String>{
  'items',
  'afterGeneration',
  'nextAfterGeneration',
  'pageSize',
  'hasMore',
  'currentState',
};
const _directDeviceRotationResultDataKeys = <String>{
  'result',
  'operationId',
  'revokedDeviceId',
  'fromGeneration',
  'generation',
  'keyEpoch',
  'dataRekeyPhase',
  'membershipManifestDigest',
  'committedAt',
};
const _selfRevocationDeviceRotationResultDataKeys = <String>{
  ..._directDeviceRotationResultDataKeys,
  'selfRevocationMutationId',
  'selfRevocationIntentDigest',
};
const _selfRevocationRequestResultDataKeys = <String>{
  'result',
  'status',
  'deviceId',
  'mutationId',
  'operationId',
  'expectedGeneration',
  'expectedKeyEpoch',
  'expectedMembershipManifestDigest',
  'intentDigest',
  'intentSignature',
  'requestedAt',
  'expiresAt',
  'receiptExpiresAt',
};
const _selfRevocationRequestListDataKeys = <String>{'requests'};
const _registrationSessionDataKeys = <String>{
  'protocolVersion',
  'result',
  'token',
  'tokenExpiresAt',
  'user',
  'device',
  'securityState',
};
const _authenticatedUserKeys = <String>{
  'id',
  'loginName',
  'displayName',
  'role',
  'attachmentQuotaBytes',
};
const _authenticatedDeviceKeys = <String>{
  'id',
  'name',
  'platform',
  'clientVersion',
  'authGeneration',
  'status',
  'createdAt',
  'sessionGeneration',
};
const _pairingTargetKeys = <String>{
  'id',
  'name',
  'platform',
  'clientVersion',
  'keyVersion',
  'authGeneration',
  'signingPublicKey',
  'keyAgreementPublicKey',
};
const _pairingPendingDataKeys = <String>{
  'protocolVersion',
  'pairingId',
  'accountContextId',
  'challenge',
  'expiresAt',
  'targetDevice',
  'status',
};
const _pairingApprovedDataKeys = <String>{
  ..._pairingPendingDataKeys,
  'issuerDeviceId',
  'issuerKeyVersion',
  'issuerAuthGeneration',
  'issuerSigningPublicKey',
  'issuerKeyAgreementPublicKey',
  'keyEpoch',
  'accountKeyEnvelope',
  'deviceProof',
  'pairingAuthenticator',
};
const _pairingSessionDataKeys = <String>{
  'protocolVersion',
  'result',
  'pairingId',
  'issuerDeviceId',
  'keyEpoch',
  'securityGeneration',
  'membershipManifestDigest',
  'securityState',
  'token',
  'tokenExpiresAt',
  'user',
  'device',
};
const _attachmentResponseEnvelopeKeys = <String>{'data'};
const _attachmentUploadResponseKeys = <String>{
  'attachmentId',
  'uploadId',
  'chunkKeyEpoch',
  'manifestKeyEpoch',
  'manifestRevision',
  'chunkCount',
  'totalCiphertextBytes',
  'status',
  'createdAt',
};
const _attachmentStoredChunkResponseKeys = <String>{
  'attachmentId',
  'uploadId',
  'chunkKeyEpoch',
  'chunkIndex',
  'ciphertextBytes',
  'status',
};
const _attachmentCommittedResponseKeys = <String>{
  'attachmentId',
  'uploadId',
  'chunkKeyEpoch',
  'manifestKeyEpoch',
  'manifestRevision',
  'status',
  'committedAt',
};
const _attachmentManifestResponseKeys = <String>{
  'dataRekeyPhase',
  'attachmentId',
  'uploadId',
  'chunkKeyEpoch',
  'manifestKeyEpoch',
  'manifestRevision',
  'chunkCount',
  'totalCiphertextBytes',
  'manifestCiphertext',
  'manifestCiphertextBytes',
  'chunks',
  'committedAt',
};
const _attachmentChunkResponseKeys = <String>{
  'dataRekeyPhase',
  'attachmentId',
  'uploadId',
  'chunkKeyEpoch',
  'chunkIndex',
  'ciphertext',
  'ciphertextBytes',
};
const _attachmentDeletedResponseKeys = <String>{
  'attachmentId',
  'uploadId',
  'chunkKeyEpoch',
  'manifestKeyEpoch',
  'manifestRevision',
  'status',
  'deletedAt',
};
const _attachmentManifestChunkKeys = <String>{'chunkIndex', 'ciphertextBytes'};
const _accountRecoveryChallengeDataKeys = <String>{
  'action',
  'result',
  'protocolVersion',
  'attemptId',
  'requestDigest',
  'challengeFrame',
  'sealedNonce',
  'securityGeneration',
  'keyEpoch',
  'membershipManifestDigest',
  'recoveryPublicKeyVersion',
  'recoveryPublicKey',
  'recoveryCapsuleVersion',
  'recoveryCapsule',
  'recoveryCapsuleDigest',
  'dataState',
  'expiresAt',
};
const _accountRecoveryReplacementChallengeDataKeys = <String>{
  'result',
  'protocolVersion',
  'challengeId',
  'attemptId',
  'requestDigest',
  'challengeFrame',
  'sealedNonce',
  'deviceState',
  'securityState',
  'dataState',
  'sourceCompletion',
  'expiresAt',
};
const _accountRecoveryReplacementDeviceStateKeys = <String>{
  'keyVersion',
  'signingPublicKey',
  'keyAgreementPublicKey',
};
const _accountRecoveryReplacementSecurityStateKeys = <String>{
  'generation',
  'keyEpoch',
  'membershipManifest',
  'membershipManifestDigest',
  'membershipOperationId',
  'recoveryPublicKeyVersion',
  'recoveryPublicKey',
  'recoveryCapsuleVersion',
  'recoveryCapsule',
  'recoveryCapsuleDigest',
};
const _accountRecoveryReplacementDataStateKeys = <String>{
  'phase',
  'dataGeneration',
  'dataKeyEpoch',
  'sourceRekeyOperationId',
};
const _accountRecoveryDataStateKeys = <String>{
  'phase',
  'dataGeneration',
  'dataKeyEpoch',
  'operationId',
  'targetKeyEpoch',
};
const _accountRecoveryAuthorizationDataKeys = <String>{
  'action',
  'result',
  'protocolVersion',
  'attemptId',
  'status',
  'nextAction',
  'recoveryTokenExpiresAt',
};
const _accountRecoveryStateDataKeys = <String>{
  'protocolVersion',
  'attemptId',
  'status',
  'nextAction',
  'authorizedAt',
  'recoveryTokenExpiresAt',
  'securityState',
  'dataState',
};
const _accountRecoveryCommitDataKeys = <String>{
  'result',
  'attemptId',
  'status',
  'membershipOperationId',
  'rekeyOperationId',
  'generation',
  'keyEpoch',
  'nextAction',
};

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
