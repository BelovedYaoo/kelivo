import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:kelivo_sync_api_client/kelivo_sync_api_client.dart' as api;

import 'cloud_sync_types.dart';

abstract interface class CloudSyncTransport {
  Future<List<CloudSyncMutationResult>> push(
    List<CloudSyncOutboxMutation> mutations,
  );

  Future<CloudSyncPullResult> pull({String? cursor, int limit = 100});

  Future<CloudSyncSnapshotResult> snapshot({
    String? snapshotCursor,
    int limit = 100,
  });
}

final class CloudSyncClient implements CloudSyncTransport {
  CloudSyncClient._({
    required this.baseUrl,
    required this._dio,
    required this._signedUrlDio,
    required this._client,
  });

  factory CloudSyncClient({required String baseUrl, String? token}) {
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
        headers: const <String, String>{'accept': 'application/json'},
      ),
    );
    final generatedClient = api.KelivoSyncApiClient(dio: dio);
    final signedUrlDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(minutes: 5),
      ),
    );
    final client = CloudSyncClient._(
      baseUrl: normalized,
      dio: dio,
      signedUrlDio: signedUrlDio,
      client: generatedClient,
    );
    client.setToken(token);
    return client;
  }

  static const _bearerAuthName = 'BearerAuth';

  final String baseUrl;
  final Dio _dio;
  final Dio _signedUrlDio;
  final api.KelivoSyncApiClient _client;

  void setToken(String? token) {
    if (token == null || token.isEmpty) {
      _client.removeBearerAuth(_bearerAuthName);
      return;
    }
    _client.setBearerAuth(_bearerAuthName, token);
  }

  void close({bool force = false}) {
    _dio.close(force: force);
    _signedUrlDio.close(force: force);
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

  Future<CloudSyncAccountSession> login({
    required String loginName,
    required String password,
    required String deviceName,
    required CloudSyncPlatform platform,
    required String clientVersion,
  }) {
    _requireNonEmpty(loginName);
    _requireNonEmpty(password);
    _requireNonEmpty(deviceName);
    _requireNonEmpty(clientVersion);

    return _guard(() async {
      final request = api.CreateAuthSessionRequest(
        (builder) => builder
          ..loginName = loginName
          ..password = password
          ..deviceName = deviceName
          ..platform = _toLoginPlatform(platform)
          ..clientVersion = clientVersion,
      );
      final response = await _client.getAuthApi().createAuthSession(
        createAuthSessionRequest: request,
      );
      final data = _requireResponseData(response.data?.data);
      final session = CloudSyncAccountSession(
        baseUrl: baseUrl,
        token: data.token,
        userId: data.user.id,
        loginName: data.user.loginName,
        displayName: data.user.displayName,
        role: _fromUserRole(data.user.role),
        attachmentQuotaBytes: data.user.attachmentQuotaBytes,
        deviceId: data.device.id,
        deviceName: data.device.name,
        platform: _fromAuthPlatform(data.device.platform),
        clientVersion: data.device.clientVersion,
        deviceCreatedAt: data.device.createdAt,
      );
      setToken(session.token);
      return session;
    });
  }

  @override
  Future<List<CloudSyncMutationResult>> push(
    List<CloudSyncOutboxMutation> mutations,
  ) {
    if (mutations.isEmpty || mutations.length > 10) {
      throw const CloudSyncException(
        kind: CloudSyncFailureKind.validation,
        retryable: false,
      );
    }
    return _guard(() async {
      final generated = mutations.map(_toGeneratedMutation).toList();
      final request = api.SyncPushRequest(
        (builder) => builder.mutations.replace(generated),
      );
      final response = await _client.getSyncApi().pushSyncChanges(
        syncPushRequest: request,
      );
      final data = _requireResponseData(response.data?.data);
      return List<CloudSyncMutationResult>.unmodifiable(
        data.results.map(_fromMutationResult),
      );
    });
  }

  @override
  Future<CloudSyncPullResult> pull({String? cursor, int limit = 100}) {
    _requirePageLimit(limit);
    return _guard(() async {
      final request = api.SyncPullRequest(
        (builder) => builder
          ..cursor = cursor
          ..limit = limit,
      );
      final response = await _client.getSyncApi().pullSyncChanges(
        syncPullRequest: request,
      );
      final data = _requireResponseData(response.data?.data);
      return CloudSyncPullResult(
        changes: List<CloudSyncChange>.unmodifiable(
          data.changes.map(_fromChange),
        ),
        nextCursor: data.nextCursor,
        hasMore: data.hasMore,
        resetRequired: data.resetRequired,
      );
    });
  }

  @override
  Future<CloudSyncSnapshotResult> snapshot({
    String? snapshotCursor,
    int limit = 100,
  }) {
    _requirePageLimit(limit);
    return _guard(() async {
      final request = api.SyncSnapshotRequest(
        (builder) => builder
          ..snapshotCursor = snapshotCursor
          ..limit = limit,
      );
      final response = await _client.getSyncApi().pullSyncSnapshot(
        syncSnapshotRequest: request,
      );
      final data = _requireResponseData(response.data?.data);
      return CloudSyncSnapshotResult(
        records: List<CloudSyncRecord>.unmodifiable(
          data.records.map(_fromRecord),
        ),
        nextSnapshotCursor: data.nextSnapshotCursor,
        syncCursor: data.syncCursor,
        hasMore: data.hasMore,
      );
    });
  }

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
      final request = api.ListDeviceSessionsRequest((builder) {
        builder
          ..pageIndex = pageIndex
          ..pageSize = pageSize;
        if (status != null) {
          builder.status = _toDeviceFilterStatus(status);
        }
      });
      final response = await _client.getDeviceApi().listDeviceSessions(
        listDeviceSessionsRequest: request,
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

  Future<CloudSyncDeviceSession> revokeDevice(String deviceId) {
    _requireNonEmpty(deviceId);
    return _guard(() async {
      final request = api.RevokeDeviceSessionRequest(
        (builder) => builder.deviceId = deviceId,
      );
      final response = await _client.getDeviceApi().revokeDeviceSession(
        revokeDeviceSessionRequest: request,
      );
      return _fromDevice(_requireResponseData(response.data?.data).device);
    });
  }

  Future<CloudSyncAttachmentUploadPreparation> prepareAttachmentUpload({
    required String sha256,
    required String md5Base64,
    required int sizeBytes,
  }) {
    _requireNonEmpty(sha256);
    _requireNonEmpty(md5Base64);
    if (sizeBytes < 0 || sizeBytes > maximumCloudSyncAttachmentSizeBytes) {
      throw const CloudSyncException(
        kind: CloudSyncFailureKind.validation,
        retryable: false,
      );
    }
    return _guard(() async {
      final request = api.PrepareAttachmentUploadRequest(
        (builder) => builder
          ..sha256 = sha256
          ..md5 = md5Base64
          ..sizeBytes = sizeBytes,
      );
      final response = await _client.getAttachmentApi().prepareAttachmentUpload(
        prepareAttachmentUploadRequest: request,
      );
      final data = _requireResponseData(response.data?.data);
      return CloudSyncAttachmentUploadPreparation(
        blobId: data.blobId,
        alreadyExists: data.alreadyExists,
        uploadUrl: data.uploadUrl,
        uploadHeaders: <String, String>{
          for (final entry in data.uploadHeaders.entries)
            entry.key: entry.value,
        },
        etag: data.etag,
      );
    });
  }

  Future<CloudSyncAttachmentInfo> completeAttachmentUpload({
    required String attachmentId,
    required String blobId,
    required String entityType,
    required String entityId,
    required String fileName,
    required String mimeType,
    required String etag,
  }) {
    for (final value in <String>[
      attachmentId,
      blobId,
      entityType,
      entityId,
      fileName,
      mimeType,
      etag,
    ]) {
      _requireNonEmpty(value);
    }
    return _guard(() async {
      final request = api.CompleteAttachmentUploadRequest(
        (builder) => builder
          ..attachmentId = attachmentId
          ..blobId = blobId
          ..entityType = entityType
          ..entityId = entityId
          ..fileName = fileName
          ..mimeType = mimeType
          ..etag = etag,
      );
      final response = await _client
          .getAttachmentApi()
          .completeAttachmentUpload(completeAttachmentUploadRequest: request);
      return _fromAttachmentInfo(
        _requireResponseData(response.data?.data).attachment,
      );
    });
  }

  Future<List<CloudSyncAttachmentInfo>> listAttachmentInfo({
    required String entityType,
    required String entityId,
  }) {
    _requireNonEmpty(entityType);
    _requireNonEmpty(entityId);
    return _guard(() async {
      final request = api.ListAttachmentInfoRequest(
        (builder) => builder
          ..entityType = entityType
          ..entityId = entityId,
      );
      final response = await _client.getAttachmentApi().listAttachmentInfo(
        listAttachmentInfoRequest: request,
      );
      final data = _requireResponseData(response.data?.data);
      return List<CloudSyncAttachmentInfo>.unmodifiable(
        data.items.map(_fromAttachmentInfo),
      );
    });
  }

  Future<CloudSyncAttachmentDownload> getAttachmentDownloadUrl(
    String attachmentId,
  ) {
    _requireNonEmpty(attachmentId);
    return _guard(() async {
      final request = api.GetAttachmentDownloadUrlRequest(
        (builder) => builder.attachmentId = attachmentId,
      );
      final response = await _client
          .getAttachmentApi()
          .getAttachmentDownloadUrl(getAttachmentDownloadUrlRequest: request);
      final data = _requireResponseData(response.data?.data);
      return CloudSyncAttachmentDownload(
        attachmentId: data.attachmentId,
        downloadUrl: data.downloadUrl,
        expiresAt: data.expiresAt,
      );
    });
  }

  Future<void> deleteAttachmentInfo(String attachmentId) {
    _requireNonEmpty(attachmentId);
    return _guard(() async {
      final request = api.DeleteAttachmentInfoRequest(
        (builder) => builder.attachmentId = attachmentId,
      );
      final response = await _client.getAttachmentApi().deleteAttachmentInfo(
        deleteAttachmentInfoRequest: request,
      );
      final data = _requireResponseData(response.data?.data);
      if (!data.deleted || data.attachmentId != attachmentId) {
        throw const FormatException('附件删除结果不匹配');
      }
    });
  }

  Future<String> putSignedAttachment({
    required String uploadUrl,
    required Map<String, String> headers,
    required Stream<List<int>> content,
  }) {
    final url = _requireSignedUrl(uploadUrl);
    final safeHeaders = _validatedSignedHeaders(headers);
    return _guard(() async {
      final response = await _signedUrlDio.put<Object?>(
        url,
        data: content,
        options: Options(headers: safeHeaders, followRedirects: false),
      );
      final etag = response.headers.value('etag')?.trim();
      if (etag == null || etag.isEmpty) {
        throw const FormatException('签名上传响应缺少 ETag');
      }
      return etag;
    });
  }

  Future<void> downloadSignedAttachment({
    required String downloadUrl,
    required String destinationPath,
    required int expectedSizeBytes,
  }) {
    final url = _requireSignedUrl(downloadUrl);
    _requireNonEmpty(destinationPath);
    if (expectedSizeBytes < 0 ||
        expectedSizeBytes > maximumCloudSyncAttachmentSizeBytes) {
      throw const CloudSyncException(
        kind: CloudSyncFailureKind.validation,
        retryable: false,
      );
    }
    return _guard(() async {
      final response = await _signedUrlDio.get<ResponseBody>(
        url,
        options: Options(
          headers: const <String, String>{},
          followRedirects: false,
          responseType: ResponseType.stream,
        ),
      );
      final body = response.data;
      if (body == null) {
        throw const FormatException('签名下载响应缺少数据流');
      }
      final declaredSize = body.contentLength;
      if (declaredSize > maximumCloudSyncAttachmentSizeBytes ||
          (declaredSize >= 0 && declaredSize != expectedSizeBytes)) {
        throw const FormatException('签名下载声明长度无效');
      }

      final file = File(destinationPath);
      final sink = file.openWrite(mode: FileMode.writeOnly);
      try {
        var receivedBytes = 0;
        await for (final chunk in body.stream) {
          final nextSize = receivedBytes + chunk.length;
          if (nextSize > maximumCloudSyncAttachmentSizeBytes ||
              nextSize > expectedSizeBytes) {
            throw const FormatException('签名下载实际长度超出限制');
          }
          sink.add(chunk);
          receivedBytes = nextSize;
        }
        if (receivedBytes != expectedSizeBytes) {
          throw const FormatException('签名下载实际长度不匹配');
        }
        await sink.flush();
        await sink.close();
      } catch (error, stackTrace) {
        Object? cleanupError;
        StackTrace? cleanupStackTrace;
        try {
          await sink.close();
        } catch (error, stackTrace) {
          cleanupError = error;
          cleanupStackTrace = stackTrace;
        }
        try {
          if (await file.exists()) await file.delete();
        } catch (error, stackTrace) {
          cleanupError ??= error;
          cleanupStackTrace ??= stackTrace;
        }
        if (cleanupError != null && cleanupStackTrace != null) {
          Error.throwWithStackTrace(cleanupError, cleanupStackTrace);
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
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

api.SyncMutation _toGeneratedMutation(CloudSyncOutboxMutation mutation) {
  final map = <String, Object?>{
    'mutationId': mutation.mutationId,
    'entityType': mutation.entityType.wireName,
    'entityId': mutation.entityId,
    'operation': mutation.operation.name,
    if (mutation.parentId != null) 'parentId': mutation.parentId,
    if (mutation.operation != CloudSyncMutationOperation.create)
      'baseRevision': mutation.baseRevision,
    if (mutation.schemaVersion != null) 'schemaVersion': mutation.schemaVersion,
    if (mutation.payload != null) 'payload': mutation.payload,
    if (mutation.operation == CloudSyncMutationOperation.update)
      'patch': mutation.patch
          .map((item) => item.toJson())
          .toList(growable: false),
  };
  try {
    final result = api.standardSerializers.deserializeWith(
      api.SyncMutation.serializer,
      map,
    );
    if (result == null) {
      throw const FormatException('无法构造同步 mutation');
    }
    return result;
  } on CloudSyncException {
    rethrow;
  } on Object {
    throw const CloudSyncException(
      kind: CloudSyncFailureKind.validation,
      retryable: false,
    );
  }
}

CloudSyncMutationResult _fromMutationResult(api.SyncMutationResult result) {
  final value = result.oneOf.value;
  if (value is api.SyncAppliedMutationResult) {
    return CloudSyncMutationResult(
      mutationId: value.mutationId,
      status: CloudSyncMutationStatus.applied,
      retryable: false,
      revision: value.revision,
      changeSeq: value.changeSeq,
    );
  }
  if (value is api.SyncConflictMutationResult) {
    return CloudSyncMutationResult(
      mutationId: value.mutationId,
      status: CloudSyncMutationStatus.conflict,
      retryable: false,
      currentRevision: value.currentRevision,
      reason: _conflictReason(value.reason),
    );
  }
  if (value is api.SyncRejectedMutationResult) {
    return CloudSyncMutationResult(
      mutationId: value.mutationId,
      status: CloudSyncMutationStatus.rejected,
      retryable: false,
      errorCode: value.errorCode,
    );
  }
  if (value is api.SyncRetryMutationResult) {
    return CloudSyncMutationResult(
      mutationId: value.mutationId,
      status: CloudSyncMutationStatus.retry,
      retryable: value.retryable,
    );
  }
  throw const FormatException('未知的 mutation 结果');
}

CloudSyncChange _fromChange(api.SyncChange change) {
  final value = change.oneOf.value;
  if (value is api.SyncUpsertChange) {
    return CloudSyncChange.upsert(
      changeSeq: value.changeSeq,
      record: _fromRecord(value.record),
    );
  }
  if (value is api.SyncDeleteChange) {
    return CloudSyncChange.delete(
      changeSeq: value.changeSeq,
      entityType: _fromEntityType(value.entityType),
      entityId: value.entityId,
      revision: value.revision,
      deletedAt: value.deletedAt.toUtc(),
    );
  }
  throw const FormatException('未知的增量变更');
}

CloudSyncRecord _fromRecord(api.SyncRecord record) {
  final payload = <String, Object?>{};
  for (final entry in record.payload.entries) {
    payload[entry.key] = copyCloudSyncJsonValue(entry.value?.value);
  }
  return CloudSyncRecord(
    entityType: _fromEntityType(record.entityType),
    entityId: record.entityId,
    parentId: record.parentId,
    revision: record.revision,
    schemaVersion: record.schemaVersion,
    sortSeq: record.sortSeq,
    payload: payload,
    deletedAt: record.deletedAt?.toUtc(),
    updatedAt: record.updatedAt.toUtc(),
    updatedByDeviceId: record.updatedByDeviceId,
    lastChangeSeq: record.lastChangeSeq,
  );
}

CloudSyncDeviceSession _fromDevice(api.DeviceSessionSummary device) {
  return CloudSyncDeviceSession(
    id: device.id,
    name: device.name,
    platform: _fromDevicePlatform(device.platform),
    clientVersion: device.clientVersion,
    status: device.status == api.DeviceSessionSummaryStatusEnum.active
        ? CloudSyncDeviceStatus.active
        : CloudSyncDeviceStatus.revoked,
    createdAt: device.createdAt.toUtc(),
    lastSeenAt: device.lastSeenAt?.toUtc(),
    revokedAt: device.revokedAt?.toUtc(),
    isCurrent: device.isCurrent,
  );
}

CloudSyncAttachmentInfo _fromAttachmentInfo(api.AttachmentInfo attachment) {
  return CloudSyncAttachmentInfo(
    id: attachment.id,
    blobId: attachment.blobId,
    entityType: attachment.entityType,
    entityId: attachment.entityId,
    fileName: attachment.fileName,
    mimeType: attachment.mimeType,
    sizeBytes: attachment.sizeBytes,
    sha256: attachment.sha256,
    createdAt: attachment.createdAt,
  );
}

CloudSyncEntityType _fromEntityType(api.SyncEntityType value) {
  if (value == api.SyncEntityType.conversation) {
    return CloudSyncEntityType.conversation;
  }
  if (value == api.SyncEntityType.turn) return CloudSyncEntityType.turn;
  if (value == api.SyncEntityType.message) return CloudSyncEntityType.message;
  if (value == api.SyncEntityType.messageSelection) {
    return CloudSyncEntityType.messageSelection;
  }
  if (value == api.SyncEntityType.toolEvent) {
    return CloudSyncEntityType.toolEvent;
  }
  if (value == api.SyncEntityType.thoughtSignature) {
    return CloudSyncEntityType.thoughtSignature;
  }
  if (value == api.SyncEntityType.provider) return CloudSyncEntityType.provider;
  if (value == api.SyncEntityType.assistant) {
    return CloudSyncEntityType.assistant;
  }
  if (value == api.SyncEntityType.memory) return CloudSyncEntityType.memory;
  if (value == api.SyncEntityType.worldBook) {
    return CloudSyncEntityType.worldBook;
  }
  if (value == api.SyncEntityType.quickPhrase) {
    return CloudSyncEntityType.quickPhrase;
  }
  if (value == api.SyncEntityType.searchService) {
    return CloudSyncEntityType.searchService;
  }
  if (value == api.SyncEntityType.networkTts) {
    return CloudSyncEntityType.networkTts;
  }
  if (value == api.SyncEntityType.mcpServer) {
    return CloudSyncEntityType.mcpServer;
  }
  if (value == api.SyncEntityType.userPreference) {
    return CloudSyncEntityType.userPreference;
  }
  throw const FormatException('服务端返回了未知实体类型');
}

api.CreateAuthSessionRequestPlatformEnum _toLoginPlatform(
  CloudSyncPlatform platform,
) {
  return switch (platform) {
    CloudSyncPlatform.android =>
      api.CreateAuthSessionRequestPlatformEnum.android,
    CloudSyncPlatform.ios => api.CreateAuthSessionRequestPlatformEnum.ios,
    CloudSyncPlatform.macos => api.CreateAuthSessionRequestPlatformEnum.macos,
    CloudSyncPlatform.windows =>
      api.CreateAuthSessionRequestPlatformEnum.windows,
    CloudSyncPlatform.linux => api.CreateAuthSessionRequestPlatformEnum.linux,
  };
}

CloudSyncPlatform _fromAuthPlatform(api.AuthDeviceSummaryPlatformEnum value) {
  if (value == api.AuthDeviceSummaryPlatformEnum.android) {
    return CloudSyncPlatform.android;
  }
  if (value == api.AuthDeviceSummaryPlatformEnum.ios) {
    return CloudSyncPlatform.ios;
  }
  if (value == api.AuthDeviceSummaryPlatformEnum.macos) {
    return CloudSyncPlatform.macos;
  }
  if (value == api.AuthDeviceSummaryPlatformEnum.windows) {
    return CloudSyncPlatform.windows;
  }
  if (value == api.AuthDeviceSummaryPlatformEnum.linux) {
    return CloudSyncPlatform.linux;
  }
  throw const FormatException('服务端返回了未知平台');
}

CloudSyncPlatform _fromDevicePlatform(
  api.DeviceSessionSummaryPlatformEnum value,
) {
  if (value == api.DeviceSessionSummaryPlatformEnum.android) {
    return CloudSyncPlatform.android;
  }
  if (value == api.DeviceSessionSummaryPlatformEnum.ios) {
    return CloudSyncPlatform.ios;
  }
  if (value == api.DeviceSessionSummaryPlatformEnum.macos) {
    return CloudSyncPlatform.macos;
  }
  if (value == api.DeviceSessionSummaryPlatformEnum.windows) {
    return CloudSyncPlatform.windows;
  }
  if (value == api.DeviceSessionSummaryPlatformEnum.linux) {
    return CloudSyncPlatform.linux;
  }
  throw const FormatException('服务端返回了未知平台');
}

CloudSyncUserRole _fromUserRole(api.UserSummaryRoleEnum value) {
  if (value == api.UserSummaryRoleEnum.owner) return CloudSyncUserRole.owner;
  if (value == api.UserSummaryRoleEnum.admin) return CloudSyncUserRole.admin;
  if (value == api.UserSummaryRoleEnum.user) return CloudSyncUserRole.user;
  throw const FormatException('服务端返回了未知用户角色');
}

api.ListDeviceSessionsRequestStatusEnum _toDeviceFilterStatus(
  CloudSyncDeviceStatus status,
) {
  return switch (status) {
    CloudSyncDeviceStatus.active =>
      api.ListDeviceSessionsRequestStatusEnum.active,
    CloudSyncDeviceStatus.revoked =>
      api.ListDeviceSessionsRequestStatusEnum.revoked,
  };
}

String _conflictReason(api.SyncConflictMutationResultReasonEnum value) {
  if (value == api.SyncConflictMutationResultReasonEnum.entityExists) {
    return 'entity-exists';
  }
  if (value == api.SyncConflictMutationResultReasonEnum.entityMissing) {
    return 'entity-missing';
  }
  if (value == api.SyncConflictMutationResultReasonEnum.entityDeleted) {
    return 'entity-deleted';
  }
  if (value == api.SyncConflictMutationResultReasonEnum.entityActive) {
    return 'entity-active';
  }
  if (value == api.SyncConflictMutationResultReasonEnum.revisionAhead) {
    return 'revision-ahead';
  }
  if (value == api.SyncConflictMutationResultReasonEnum.revisionStale) {
    return 'revision-stale';
  }
  throw const FormatException('服务端返回了未知冲突原因');
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

void _requireNonEmpty(String value) {
  if (value.trim().isEmpty) {
    throw const CloudSyncException(
      kind: CloudSyncFailureKind.validation,
      retryable: false,
    );
  }
}

String _requireSignedUrl(String value) {
  final normalized = value.trim();
  final uri = Uri.tryParse(normalized);
  if (uri == null ||
      !isAllowedCloudSyncTransportUri(uri) ||
      uri.userInfo.isNotEmpty) {
    throw const CloudSyncException(
      kind: CloudSyncFailureKind.validation,
      retryable: false,
    );
  }
  return normalized;
}

Map<String, String> _validatedSignedHeaders(Map<String, String> headers) {
  final result = <String, String>{};
  for (final entry in headers.entries) {
    final name = entry.key.trim();
    final value = entry.value.trim();
    if (name.isEmpty ||
        value.isEmpty ||
        name.toLowerCase() == 'authorization') {
      throw const CloudSyncException(
        kind: CloudSyncFailureKind.validation,
        retryable: false,
      );
    }
    result[name] = value;
  }
  return Map<String, String>.unmodifiable(result);
}

void _requirePageLimit(int limit) {
  if (limit < 1 || limit > 100) {
    throw const CloudSyncException(
      kind: CloudSyncFailureKind.validation,
      retryable: false,
    );
  }
}

CloudSyncException _fromDioException(DioException error) {
  final statusCode = error.response?.statusCode;
  final serverError = _parseServerError(error.response?.data);
  final kind = switch (error.type) {
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
