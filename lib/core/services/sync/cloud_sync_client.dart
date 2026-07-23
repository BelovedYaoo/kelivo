import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:kelivo_sync_api_client/kelivo_sync_api_client.dart' as api;
import 'package:one_of/one_of.dart';

import 'cloud_sync_record_types.dart';
import 'cloud_sync_types.dart';

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
  void setToken(String? token);

  void close({bool force = false});

  Future<CloudSyncAccountSession> login({
    required String loginName,
    required String password,
    required String deviceName,
    required CloudSyncPlatform platform,
    required String clientVersion,
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

  factory CloudSyncClient({String? token}) {
    return CloudSyncClient._forBaseUrl(
      baseUrl: defaultCloudSyncBaseUrl,
      token: token,
    );
  }

  @visibleForTesting
  factory CloudSyncClient.forTesting({required String baseUrl, String? token}) {
    return CloudSyncClient._forBaseUrl(baseUrl: baseUrl, token: token);
  }

  factory CloudSyncClient._forBaseUrl({
    required String baseUrl,
    String? token,
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
      client: api.KelivoSyncApiClient(dio: dio),
    );
    client.setToken(token);
    return client;
  }

  static const _bearerAuthName = 'BearerAuth';
  static const _syncProtocolVersion = '3';

  final String baseUrl;
  final Dio _dio;
  final api.KelivoSyncApiClient _client;

  @override
  void setToken(String? token) {
    if (token == null || token.isEmpty) {
      _client.removeBearerAuth(_bearerAuthName);
      return;
    }
    _client.setBearerAuth(_bearerAuthName, token);
  }

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
  Future<List<CloudSyncRecordMutationResult>> pushRecords(
    List<CloudSyncRecordMutation> mutations,
  ) {
    _validatePushMutations(mutations);
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

  @override
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
    CloudSyncDeleteRecordMutation() => _toGeneratedDeleteMutation(mutation),
  };
}

api.SyncMutation _toGeneratedPutMutation(CloudSyncPutRecordMutation mutation) {
  final value = api.SyncPutMutation(
    (builder) => builder
      ..mutationId = mutation.mutationId
      ..recordId = mutation.recordId
      ..expectedRevision = mutation.expectedRevision
      ..operation = api.SyncPutMutationOperationEnum.put
      ..envelopeVersion = CloudSyncPutRecordMutation.envelopeVersion
      ..keyEpoch = mutation.keyEpoch
      ..ciphertext = mutation.ciphertext,
  );
  return api.SyncMutation(
    (builder) =>
        builder.oneOf = OneOf2<api.SyncDeleteMutation, api.SyncPutMutation>(
          value: value,
          typeIndex: 1,
        ),
  );
}

api.SyncMutation _toGeneratedDeleteMutation(
  CloudSyncDeleteRecordMutation mutation,
) {
  final value = api.SyncDeleteMutation(
    (builder) => builder
      ..mutationId = mutation.mutationId
      ..recordId = mutation.recordId
      ..expectedRevision = mutation.expectedRevision
      ..operation = api.SyncDeleteMutationOperationEnum.delete,
  );
  return api.SyncMutation(
    (builder) =>
        builder.oneOf = OneOf2<api.SyncDeleteMutation, api.SyncPutMutation>(
          value: value,
          typeIndex: 0,
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
    final ciphertextBytes = _syncCiphertextByteLength(value.ciphertext);
    if (value.envelopeVersion != CloudSyncPutRecordMutation.envelopeVersion ||
        value.keyEpoch < 1 ||
        value.keyEpoch > 2147483647 ||
        ciphertextBytes == null ||
        ciphertextBytes != value.ciphertextBytes ||
        value.deletedAt != null) {
      throw const FormatException('服务端返回了无效的 put 增量');
    }
    return CloudSyncPutRecordChange(
      changeSeq: value.changeSeq,
      recordId: value.recordId,
      revision: value.revision,
      updatedAt: value.updatedAt.toUtc(),
      updatedByDeviceId: value.updatedByDeviceId,
      envelopeVersion: value.envelopeVersion,
      keyEpoch: value.keyEpoch,
      ciphertext: value.ciphertext,
    );
  }
  if (value is api.SyncDeleteChange) {
    _validateRecordMetadata(
      recordId: value.recordId,
      revision: value.revision,
      sequence: value.changeSeq,
      updatedByDeviceId: value.updatedByDeviceId,
    );
    if (value.envelopeVersion != null ||
        value.keyEpoch != null ||
        value.ciphertext != null ||
        value.ciphertextBytes != 0) {
      throw const FormatException('服务端返回了无效的 delete 增量');
    }
    return CloudSyncDeleteRecordChange(
      changeSeq: value.changeSeq,
      recordId: value.recordId,
      revision: value.revision,
      updatedAt: value.updatedAt.toUtc(),
      updatedByDeviceId: value.updatedByDeviceId,
      deletedAt: value.deletedAt.toUtc(),
    );
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
    final ciphertextBytes = _syncCiphertextByteLength(value.ciphertext);
    if (value.envelopeVersion != CloudSyncPutRecordMutation.envelopeVersion ||
        value.keyEpoch < 1 ||
        value.keyEpoch > 2147483647 ||
        ciphertextBytes == null ||
        ciphertextBytes != value.ciphertextBytes ||
        value.deletedAt != null) {
      throw const FormatException('服务端返回了无效的 active 记录');
    }
    return CloudSyncActiveRecord(
      recordId: value.recordId,
      revision: value.revision,
      updatedAt: value.updatedAt.toUtc(),
      updatedByDeviceId: value.updatedByDeviceId,
      lastChangeSeq: value.lastChangeSeq,
      envelopeVersion: value.envelopeVersion,
      keyEpoch: value.keyEpoch,
      ciphertext: value.ciphertext,
    );
  }
  if (value is api.SyncDeletedRecord) {
    _validateRecordMetadata(
      recordId: value.recordId,
      revision: value.revision,
      sequence: value.lastChangeSeq,
      updatedByDeviceId: value.updatedByDeviceId,
    );
    if (value.envelopeVersion != null ||
        value.keyEpoch != null ||
        value.ciphertext != null ||
        value.ciphertextBytes != 0) {
      throw const FormatException('服务端返回了无效的 deleted 记录');
    }
    return CloudSyncDeletedRecord(
      recordId: value.recordId,
      revision: value.revision,
      updatedAt: value.updatedAt.toUtc(),
      updatedByDeviceId: value.updatedByDeviceId,
      lastChangeSeq: value.lastChangeSeq,
      deletedAt: value.deletedAt.toUtc(),
    );
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
    _requireClientIdentifier(mutation.recordId);
    if (!mutationIds.add(mutation.mutationId) ||
        mutation.expectedRevision < 0) {
      throw const CloudSyncException(
        kind: CloudSyncFailureKind.validation,
        retryable: false,
      );
    }
    switch (mutation) {
      case CloudSyncPutRecordMutation():
        if (mutation.keyEpoch < 1 || mutation.keyEpoch > 2147483647) {
          throw const CloudSyncException(
            kind: CloudSyncFailureKind.validation,
            retryable: false,
          );
        }
        final ciphertextBytes = _syncCiphertextByteLength(mutation.ciphertext);
        if (ciphertextBytes == null ||
            ciphertextBytes < 1 ||
            ciphertextBytes > 1048576) {
          throw const CloudSyncException(
            kind: CloudSyncFailureKind.validation,
            retryable: false,
          );
        }
        totalCiphertextBytes += ciphertextBytes;
      case CloudSyncDeleteRecordMutation():
        if (mutation.expectedRevision == 0) {
          throw const CloudSyncException(
            kind: CloudSyncFailureKind.validation,
            retryable: false,
          );
        }
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

final _syncIdentifierPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
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
