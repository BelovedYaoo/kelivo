typedef CloudSyncJsonMap = Map<String, Object?>;

const maximumCloudSyncAttachmentSizeBytes = 100 * 1024 * 1024;

const _supportedEntityTypes = <String>{
  'conversation',
  'turn',
  'message',
  'message-selection',
  'tool-event',
  'thought-signature',
  'provider',
  'assistant',
  'memory',
  'world-book',
  'quick-phrase',
  'search-service',
  'network-tts',
  'mcp-server',
  'user-preference',
};

String normalizeCloudSyncBaseUrl(String value) {
  final trimmed = value.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    throw const FormatException('同步服务地址格式无效');
  }
  return uri.origin;
}

Object? copyCloudSyncJsonValue(Object? value) {
  if (value == null || value is String || value is bool || value is int) {
    return value;
  }
  if (value is double) {
    if (!value.isFinite) {
      throw const FormatException('JSON 数值必须为有限值');
    }
    return value;
  }
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(value.map(copyCloudSyncJsonValue));
  }
  if (value is Map<Object?, Object?>) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw const FormatException('JSON 对象键必须为字符串');
      }
      result[key] = copyCloudSyncJsonValue(entry.value);
    }
    return Map<String, Object?>.unmodifiable(result);
  }
  throw const FormatException('值不是合法 JSON');
}

CloudSyncJsonMap copyCloudSyncJsonMap(Object? value) {
  final copied = copyCloudSyncJsonValue(value);
  if (copied is! Map<String, Object?>) {
    throw const FormatException('JSON 根节点必须为对象');
  }
  return copied;
}

enum CloudSyncPlatform { android, ios, macos, windows, linux }

enum CloudSyncUserRole { owner, admin, user }

enum CloudSyncDeviceStatus { active, revoked }

enum CloudSyncMutationOperation { create, update, delete, restore }

enum CloudSyncPatchOperation { add, replace, remove }

enum CloudSyncMutationStatus { applied, conflict, rejected, retry }

enum CloudSyncChangeOperation { upsert, delete }

enum CloudSyncAttachmentKind { image, file }

enum CloudSyncFailureKind {
  invalidBaseUrl,
  unauthenticated,
  forbidden,
  notFound,
  conflict,
  validation,
  rateLimited,
  server,
  network,
  timeout,
  cancelled,
  invalidResponse,
  unknown,
}

enum CloudSyncEntityType {
  conversation('conversation'),
  turn('turn'),
  message('message'),
  messageSelection('message-selection'),
  toolEvent('tool-event'),
  thoughtSignature('thought-signature'),
  provider('provider'),
  assistant('assistant'),
  memory('memory'),
  worldBook('world-book'),
  quickPhrase('quick-phrase'),
  searchService('search-service'),
  networkTts('network-tts'),
  mcpServer('mcp-server'),
  userPreference('user-preference');

  const CloudSyncEntityType(this.wireName);

  final String wireName;

  static CloudSyncEntityType parse(String value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    throw FormatException('不支持的同步实体类型：$value');
  }
}

final class CloudSyncException implements Exception {
  const CloudSyncException({
    required this.kind,
    required this.retryable,
    this.serverCode,
    this.requestId,
    this.statusCode,
  });

  final CloudSyncFailureKind kind;
  final bool retryable;
  final String? serverCode;
  final String? requestId;
  final int? statusCode;

  @override
  String toString() {
    return 'CloudSyncException(kind: ${kind.name}, '
        'serverCode: $serverCode, retryable: $retryable)';
  }
}

final class CloudSyncAccountSession {
  CloudSyncAccountSession({
    required String baseUrl,
    required this.token,
    required this.userId,
    required this.loginName,
    required this.displayName,
    required this.role,
    required this.attachmentQuotaBytes,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.clientVersion,
    required DateTime deviceCreatedAt,
  }) : baseUrl = normalizeCloudSyncBaseUrl(baseUrl),
       deviceCreatedAt = deviceCreatedAt.toUtc() {
    _requireNonEmpty(token, 'token');
    _requireNonEmpty(userId, 'userId');
    _requireNonEmpty(loginName, 'loginName');
    _requireNonEmpty(displayName, 'displayName');
    _requireNonEmpty(deviceId, 'deviceId');
    _requireNonEmpty(deviceName, 'deviceName');
    _requireNonEmpty(clientVersion, 'clientVersion');
    if (attachmentQuotaBytes < 0) {
      throw const FormatException('attachmentQuotaBytes 不能为负数');
    }
  }

  final String baseUrl;
  final String token;
  final String userId;
  final String loginName;
  final String displayName;
  final CloudSyncUserRole role;
  final int attachmentQuotaBytes;
  final String deviceId;
  final String deviceName;
  final CloudSyncPlatform platform;
  final String clientVersion;
  final DateTime deviceCreatedAt;

  String get accountScope => Uri.encodeComponent('$baseUrl\n$userId');

  CloudSyncJsonMap toJson() => <String, Object?>{
    'version': 1,
    'baseUrl': baseUrl,
    'token': token,
    'userId': userId,
    'loginName': loginName,
    'displayName': displayName,
    'role': role.name,
    'attachmentQuotaBytes': attachmentQuotaBytes,
    'deviceId': deviceId,
    'deviceName': deviceName,
    'platform': platform.name,
    'clientVersion': clientVersion,
    'deviceCreatedAt': deviceCreatedAt.toIso8601String(),
  };

  factory CloudSyncAccountSession.fromJson(CloudSyncJsonMap json) {
    _requireVersion(json);
    return CloudSyncAccountSession(
      baseUrl: _requireString(json, 'baseUrl'),
      token: _requireString(json, 'token'),
      userId: _requireString(json, 'userId'),
      loginName: _requireString(json, 'loginName'),
      displayName: _requireString(json, 'displayName'),
      role: _parseEnum(
        CloudSyncUserRole.values,
        _requireString(json, 'role'),
        'role',
      ),
      attachmentQuotaBytes: _requireInt(json, 'attachmentQuotaBytes'),
      deviceId: _requireString(json, 'deviceId'),
      deviceName: _requireString(json, 'deviceName'),
      platform: _parseEnum(
        CloudSyncPlatform.values,
        _requireString(json, 'platform'),
        'platform',
      ),
      clientVersion: _requireString(json, 'clientVersion'),
      deviceCreatedAt: _requireDateTime(json, 'deviceCreatedAt'),
    );
  }
}

final class CloudSyncHealth {
  const CloudSyncHealth({
    required this.service,
    required this.status,
    required this.timestamp,
  });

  final String service;
  final String status;
  final DateTime timestamp;
}

final class CloudSyncAttachmentInfo {
  CloudSyncAttachmentInfo({
    required String id,
    required String blobId,
    required String entityType,
    required String entityId,
    required String fileName,
    required String mimeType,
    required this.sizeBytes,
    required String sha256,
    required DateTime createdAt,
  }) : id = _validatedUuid(id, 'attachmentId'),
       blobId = _validatedUuid(blobId, 'blobId'),
       entityType = _validatedAttachmentEntityType(entityType),
       entityId = _validatedId(entityId, 'entityId'),
       fileName = _validatedAttachmentFileName(fileName),
       mimeType = _validatedAttachmentMimeType(mimeType),
       sha256 = _validatedSha256(sha256),
       createdAt = createdAt.toUtc() {
    _validateAttachmentSize(sizeBytes);
  }

  final String id;
  final String blobId;
  final String entityType;
  final String entityId;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final String sha256;
  final DateTime createdAt;
}

final class CloudSyncAttachmentUploadPreparation {
  CloudSyncAttachmentUploadPreparation({
    required String blobId,
    required this.alreadyExists,
    required String? uploadUrl,
    required Map<String, String> uploadHeaders,
    required String? etag,
  }) : blobId = _validatedUuid(blobId, 'blobId'),
       uploadUrl = _validatedOptionalHttpUrl(uploadUrl, 'uploadUrl'),
       uploadHeaders = Map<String, String>.unmodifiable(uploadHeaders),
       etag = _validatedOptionalNonEmpty(etag, 'etag') {
    for (final entry in uploadHeaders.entries) {
      _requireNonEmpty(entry.key, 'uploadHeaders key');
      _requireNonEmpty(entry.value, 'uploadHeaders value');
    }
    if (alreadyExists) {
      if (this.uploadUrl != null ||
          this.uploadHeaders.isNotEmpty ||
          this.etag == null) {
        throw const FormatException('已存在附件的上传准备结果无效');
      }
    } else if (this.uploadUrl == null || this.etag != null) {
      throw const FormatException('待上传附件的上传准备结果无效');
    }
  }

  final String blobId;
  final bool alreadyExists;
  final String? uploadUrl;
  final Map<String, String> uploadHeaders;
  final String? etag;
}

final class CloudSyncAttachmentDownload {
  CloudSyncAttachmentDownload({
    required String attachmentId,
    required String downloadUrl,
    required DateTime expiresAt,
  }) : attachmentId = _validatedUuid(attachmentId, 'attachmentId'),
       downloadUrl = _validatedHttpUrl(downloadUrl, 'downloadUrl'),
       expiresAt = expiresAt.toUtc();

  final String attachmentId;
  final String downloadUrl;
  final DateTime expiresAt;
}

final class CloudSyncAttachmentBinding {
  CloudSyncAttachmentBinding({
    required String messageId,
    required String attachmentId,
    required this.kind,
    required this.order,
    required String localPath,
    required DateTime modifiedAt,
    required this.sizeBytes,
    required String sha256,
    required String md5Base64,
    required String fileName,
    required String mimeType,
    required this.completed,
  }) : messageId = _validatedId(messageId, 'messageId'),
       attachmentId = _validatedUuid(attachmentId, 'attachmentId'),
       localPath = _validatedLocalPath(localPath),
       modifiedAt = modifiedAt.toUtc(),
       sha256 = _validatedSha256(sha256),
       md5Base64 = _validatedMd5Base64(md5Base64),
       fileName = _validatedAttachmentFileName(fileName),
       mimeType = _validatedAttachmentMimeType(mimeType) {
    if (order < 0) {
      throw const FormatException('附件顺序不能为负数');
    }
    _validateAttachmentSize(sizeBytes);
  }

  final String messageId;
  final String attachmentId;
  final CloudSyncAttachmentKind kind;
  final int order;
  final String localPath;
  final DateTime modifiedAt;
  final int sizeBytes;
  final String sha256;
  final String md5Base64;
  final String fileName;
  final String mimeType;
  final bool completed;

  CloudSyncAttachmentBinding copyWith({
    String? localPath,
    DateTime? modifiedAt,
    int? sizeBytes,
    String? sha256,
    String? md5Base64,
    String? fileName,
    String? mimeType,
    bool? completed,
  }) {
    return CloudSyncAttachmentBinding(
      messageId: messageId,
      attachmentId: attachmentId,
      kind: kind,
      order: order,
      localPath: localPath ?? this.localPath,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      sha256: sha256 ?? this.sha256,
      md5Base64: md5Base64 ?? this.md5Base64,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      completed: completed ?? this.completed,
    );
  }

  CloudSyncJsonMap toJson() => <String, Object?>{
    'version': 1,
    'messageId': messageId,
    'attachmentId': attachmentId,
    'kind': kind.name,
    'order': order,
    'localPath': localPath,
    'modifiedAt': modifiedAt.toIso8601String(),
    'sizeBytes': sizeBytes,
    'sha256': sha256,
    'md5Base64': md5Base64,
    'fileName': fileName,
    'mimeType': mimeType,
    'completed': completed,
  };

  factory CloudSyncAttachmentBinding.fromJson(CloudSyncJsonMap json) {
    _requireVersion(json);
    final completed = json['completed'];
    if (completed is! bool) {
      throw const FormatException('completed 必须为布尔值');
    }
    return CloudSyncAttachmentBinding(
      messageId: _requireString(json, 'messageId'),
      attachmentId: _requireString(json, 'attachmentId'),
      kind: _parseEnum(
        CloudSyncAttachmentKind.values,
        _requireString(json, 'kind'),
        'kind',
      ),
      order: _requireInt(json, 'order'),
      localPath: _requireString(json, 'localPath'),
      modifiedAt: _requireDateTime(json, 'modifiedAt'),
      sizeBytes: _requireInt(json, 'sizeBytes'),
      sha256: _requireString(json, 'sha256'),
      md5Base64: _requireString(json, 'md5Base64'),
      fileName: _requireString(json, 'fileName'),
      mimeType: _requireString(json, 'mimeType'),
      completed: completed,
    );
  }
}

final class CloudSyncDeviceSession {
  const CloudSyncDeviceSession({
    required this.id,
    required this.name,
    required this.platform,
    required this.clientVersion,
    required this.status,
    required this.createdAt,
    required this.lastSeenAt,
    required this.revokedAt,
    required this.isCurrent,
  });

  final String id;
  final String name;
  final CloudSyncPlatform platform;
  final String clientVersion;
  final CloudSyncDeviceStatus status;
  final DateTime createdAt;
  final DateTime? lastSeenAt;
  final DateTime? revokedAt;
  final bool isCurrent;
}

final class CloudSyncPage<T> {
  const CloudSyncPage({
    required this.items,
    required this.total,
    required this.pageIndex,
    required this.pageSize,
  });

  final List<T> items;
  final int total;
  final int pageIndex;
  final int pageSize;
}

final class CloudSyncPatch {
  CloudSyncPatch._({required this.operation, required this.path, this.value});

  factory CloudSyncPatch.add(String path, Object? value) {
    return CloudSyncPatch._(
      operation: CloudSyncPatchOperation.add,
      path: _validatedPatchPath(path),
      value: copyCloudSyncJsonValue(value),
    );
  }

  factory CloudSyncPatch.replace(String path, Object? value) {
    return CloudSyncPatch._(
      operation: CloudSyncPatchOperation.replace,
      path: _validatedPatchPath(path),
      value: copyCloudSyncJsonValue(value),
    );
  }

  factory CloudSyncPatch.remove(String path) {
    return CloudSyncPatch._(
      operation: CloudSyncPatchOperation.remove,
      path: _validatedPatchPath(path),
    );
  }

  final CloudSyncPatchOperation operation;
  final String path;
  final Object? value;

  CloudSyncJsonMap toJson() => <String, Object?>{
    'op': operation.name,
    'path': path,
    if (operation != CloudSyncPatchOperation.remove) 'value': value,
  };

  factory CloudSyncPatch.fromJson(CloudSyncJsonMap json) {
    final operation = _parseEnum(
      CloudSyncPatchOperation.values,
      _requireString(json, 'op'),
      'op',
    );
    final path = _requireString(json, 'path');
    if (operation != CloudSyncPatchOperation.remove &&
        !json.containsKey('value')) {
      throw const FormatException('add/replace patch 必须包含 value');
    }
    return switch (operation) {
      CloudSyncPatchOperation.add => CloudSyncPatch.add(path, json['value']),
      CloudSyncPatchOperation.replace => CloudSyncPatch.replace(
        path,
        json['value'],
      ),
      CloudSyncPatchOperation.remove => CloudSyncPatch.remove(path),
    };
  }
}

final class CloudSyncOutboxMutation {
  CloudSyncOutboxMutation._({
    required this.mutationId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.parentId,
    required this.baseRevision,
    required this.schemaVersion,
    required this.payload,
    required this.patch,
    required this.attemptCount,
    required this.createdAt,
    required this.nextAttemptAt,
    required this.lastErrorCode,
  });

  factory CloudSyncOutboxMutation.create({
    required String mutationId,
    required CloudSyncEntityType entityType,
    required String entityId,
    required int schemaVersion,
    required CloudSyncJsonMap payload,
    String? parentId,
    DateTime? createdAt,
  }) {
    if (schemaVersion < 1) {
      throw const FormatException('schemaVersion 必须大于 0');
    }
    final now = (createdAt ?? DateTime.now()).toUtc();
    return CloudSyncOutboxMutation._(
      mutationId: _validatedId(mutationId, 'mutationId'),
      entityType: entityType,
      entityId: _validatedId(entityId, 'entityId'),
      operation: CloudSyncMutationOperation.create,
      parentId: _validatedOptionalId(parentId, 'parentId'),
      baseRevision: 0,
      schemaVersion: schemaVersion,
      payload: copyCloudSyncJsonMap(payload),
      patch: const <CloudSyncPatch>[],
      attemptCount: 0,
      createdAt: now,
      nextAttemptAt: now,
      lastErrorCode: null,
    );
  }

  factory CloudSyncOutboxMutation.update({
    required String mutationId,
    required CloudSyncEntityType entityType,
    required String entityId,
    required int baseRevision,
    required List<CloudSyncPatch> patch,
    int? schemaVersion,
    DateTime? createdAt,
  }) {
    if (baseRevision < 1 || (schemaVersion != null && schemaVersion < 1)) {
      throw const FormatException('同步版本号无效');
    }
    if (patch.length > 100 || (patch.isEmpty && schemaVersion == null)) {
      throw const FormatException('更新操作需要 patch 或 schemaVersion');
    }
    final now = (createdAt ?? DateTime.now()).toUtc();
    return CloudSyncOutboxMutation._(
      mutationId: _validatedId(mutationId, 'mutationId'),
      entityType: entityType,
      entityId: _validatedId(entityId, 'entityId'),
      operation: CloudSyncMutationOperation.update,
      parentId: null,
      baseRevision: baseRevision,
      schemaVersion: schemaVersion,
      payload: null,
      patch: List<CloudSyncPatch>.unmodifiable(patch),
      attemptCount: 0,
      createdAt: now,
      nextAttemptAt: now,
      lastErrorCode: null,
    );
  }

  factory CloudSyncOutboxMutation.delete({
    required String mutationId,
    required CloudSyncEntityType entityType,
    required String entityId,
    required int baseRevision,
    DateTime? createdAt,
  }) {
    return _revisionMutation(
      mutationId: mutationId,
      entityType: entityType,
      entityId: entityId,
      baseRevision: baseRevision,
      operation: CloudSyncMutationOperation.delete,
      createdAt: createdAt,
    );
  }

  factory CloudSyncOutboxMutation.restore({
    required String mutationId,
    required CloudSyncEntityType entityType,
    required String entityId,
    required int baseRevision,
    DateTime? createdAt,
  }) {
    return _revisionMutation(
      mutationId: mutationId,
      entityType: entityType,
      entityId: entityId,
      baseRevision: baseRevision,
      operation: CloudSyncMutationOperation.restore,
      createdAt: createdAt,
    );
  }

  final String mutationId;
  final CloudSyncEntityType entityType;
  final String entityId;
  final CloudSyncMutationOperation operation;
  final String? parentId;
  final int baseRevision;
  final int? schemaVersion;
  final CloudSyncJsonMap? payload;
  final List<CloudSyncPatch> patch;
  final int attemptCount;
  final DateTime createdAt;
  final DateTime nextAttemptAt;
  final String? lastErrorCode;

  bool canMergeWith(CloudSyncOutboxMutation newer) {
    if (attemptCount != 0 ||
        newer.attemptCount != 0 ||
        entityType != newer.entityType ||
        entityId != newer.entityId ||
        operation != newer.operation) {
      return false;
    }
    if (operation == CloudSyncMutationOperation.update) {
      return baseRevision == newer.baseRevision &&
          patch.length + newer.patch.length <= 100;
    }
    return true;
  }

  CloudSyncOutboxMutation mergedWith(CloudSyncOutboxMutation newer) {
    if (!canMergeWith(newer)) {
      throw StateError('这些 outbox 项不能安全合并');
    }
    if (operation == CloudSyncMutationOperation.update) {
      return CloudSyncOutboxMutation._(
        mutationId: mutationId,
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        parentId: null,
        baseRevision: newer.baseRevision,
        schemaVersion: newer.schemaVersion ?? schemaVersion,
        payload: null,
        // 保留 JSON Patch 的先后语义，不能按 path 覆盖掉中间操作。
        patch: List<CloudSyncPatch>.unmodifiable(<CloudSyncPatch>[
          ...patch,
          ...newer.patch,
        ]),
        attemptCount: 0,
        createdAt: createdAt,
        nextAttemptAt: newer.nextAttemptAt,
        lastErrorCode: null,
      );
    }
    return CloudSyncOutboxMutation._(
      mutationId: mutationId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      parentId: newer.parentId,
      baseRevision: newer.baseRevision,
      schemaVersion: newer.schemaVersion,
      payload: newer.payload,
      patch: newer.patch,
      attemptCount: 0,
      createdAt: createdAt,
      nextAttemptAt: newer.nextAttemptAt,
      lastErrorCode: null,
    );
  }

  CloudSyncOutboxMutation attempted() {
    return CloudSyncOutboxMutation._(
      mutationId: mutationId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      parentId: parentId,
      baseRevision: baseRevision,
      schemaVersion: schemaVersion,
      payload: payload,
      patch: patch,
      attemptCount: attemptCount + 1,
      createdAt: createdAt,
      nextAttemptAt: nextAttemptAt,
      lastErrorCode: lastErrorCode,
    );
  }

  CloudSyncOutboxMutation scheduledForRetry({
    required DateTime nextAttemptAt,
    String? errorCode,
  }) {
    return CloudSyncOutboxMutation._(
      mutationId: mutationId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      parentId: parentId,
      baseRevision: baseRevision,
      schemaVersion: schemaVersion,
      payload: payload,
      patch: patch,
      attemptCount: attemptCount,
      createdAt: createdAt,
      nextAttemptAt: nextAttemptAt.toUtc(),
      lastErrorCode: errorCode,
    );
  }

  CloudSyncJsonMap toJson() => <String, Object?>{
    'version': 1,
    'mutationId': mutationId,
    'entityType': entityType.wireName,
    'entityId': entityId,
    'operation': operation.name,
    if (parentId != null) 'parentId': parentId,
    'baseRevision': baseRevision,
    if (schemaVersion != null) 'schemaVersion': schemaVersion,
    if (payload != null) 'payload': payload,
    'patch': patch.map((item) => item.toJson()).toList(growable: false),
    'attemptCount': attemptCount,
    'createdAt': createdAt.toIso8601String(),
    'nextAttemptAt': nextAttemptAt.toIso8601String(),
    if (lastErrorCode != null) 'lastErrorCode': lastErrorCode,
  };

  factory CloudSyncOutboxMutation.fromJson(CloudSyncJsonMap json) {
    _requireVersion(json);
    final mutationId = _requireString(json, 'mutationId');
    final entityType = CloudSyncEntityType.parse(
      _requireString(json, 'entityType'),
    );
    final entityId = _requireString(json, 'entityId');
    final operation = _parseEnum(
      CloudSyncMutationOperation.values,
      _requireString(json, 'operation'),
      'operation',
    );
    final baseRevision = _requireInt(json, 'baseRevision');
    final createdAt = _requireDateTime(json, 'createdAt');
    final patchValue = json['patch'];
    if (patchValue is! List<Object?>) {
      throw const FormatException('patch 必须为数组');
    }
    final decoded = switch (operation) {
      CloudSyncMutationOperation.create => CloudSyncOutboxMutation.create(
        mutationId: mutationId,
        entityType: entityType,
        entityId: entityId,
        schemaVersion: _requireInt(json, 'schemaVersion'),
        payload: copyCloudSyncJsonMap(json['payload']),
        parentId: _optionalString(json, 'parentId'),
        createdAt: createdAt,
      ),
      CloudSyncMutationOperation.update => CloudSyncOutboxMutation.update(
        mutationId: mutationId,
        entityType: entityType,
        entityId: entityId,
        baseRevision: baseRevision,
        schemaVersion: _optionalInt(json, 'schemaVersion'),
        patch: _decodePatchList(json['patch']),
        createdAt: createdAt,
      ),
      CloudSyncMutationOperation.delete => CloudSyncOutboxMutation.delete(
        mutationId: mutationId,
        entityType: entityType,
        entityId: entityId,
        baseRevision: baseRevision,
        createdAt: createdAt,
      ),
      CloudSyncMutationOperation.restore => CloudSyncOutboxMutation.restore(
        mutationId: mutationId,
        entityType: entityType,
        entityId: entityId,
        baseRevision: baseRevision,
        createdAt: createdAt,
      ),
    };
    if (operation == CloudSyncMutationOperation.create) {
      if (baseRevision != 0 || patchValue.isNotEmpty) {
        throw const FormatException('create 本地状态结构无效');
      }
    } else if (operation == CloudSyncMutationOperation.update) {
      if (json['payload'] != null || json['parentId'] != null) {
        throw const FormatException('update 本地状态结构无效');
      }
    } else if (operation != CloudSyncMutationOperation.update &&
        (patchValue.isNotEmpty ||
            json['payload'] != null ||
            json['schemaVersion'] != null ||
            json['parentId'] != null)) {
      throw const FormatException('delete/restore 本地状态结构无效');
    }
    final attemptCount = _requireInt(json, 'attemptCount');
    if (attemptCount < 0) {
      throw const FormatException('attemptCount 不能为负数');
    }
    return CloudSyncOutboxMutation._(
      mutationId: decoded.mutationId,
      entityType: decoded.entityType,
      entityId: decoded.entityId,
      operation: decoded.operation,
      parentId: decoded.parentId,
      baseRevision: decoded.baseRevision,
      schemaVersion: decoded.schemaVersion,
      payload: decoded.payload,
      patch: decoded.patch,
      attemptCount: attemptCount,
      createdAt: decoded.createdAt,
      nextAttemptAt: _requireDateTime(json, 'nextAttemptAt'),
      lastErrorCode: _optionalString(json, 'lastErrorCode'),
    );
  }
}

final class CloudSyncShadow {
  CloudSyncShadow({
    required this.entityType,
    required String entityId,
    required String? parentId,
    required this.revision,
    required this.schemaVersion,
    required this.lastChangeSeq,
    required this.deleted,
    required CloudSyncJsonMap? payload,
    required DateTime updatedAt,
  }) : entityId = _validatedId(entityId, 'entityId'),
       parentId = _validatedOptionalId(parentId, 'parentId'),
       payload = payload == null ? null : copyCloudSyncJsonMap(payload),
       updatedAt = updatedAt.toUtc() {
    if (revision < 1 || schemaVersion < 1 || lastChangeSeq < 1) {
      throw const FormatException('shadow 版本号必须大于 0');
    }
    if (!deleted && payload == null) {
      throw const FormatException('有效 shadow 必须保留已确认 payload');
    }
  }

  final CloudSyncEntityType entityType;
  final String entityId;
  final String? parentId;
  final int revision;
  final int schemaVersion;
  final int lastChangeSeq;
  final bool deleted;
  final CloudSyncJsonMap? payload;
  final DateTime updatedAt;

  CloudSyncJsonMap toJson() => <String, Object?>{
    'version': 1,
    'entityType': entityType.wireName,
    'entityId': entityId,
    if (parentId != null) 'parentId': parentId,
    'revision': revision,
    'schemaVersion': schemaVersion,
    'lastChangeSeq': lastChangeSeq,
    'deleted': deleted,
    if (payload != null) 'payload': payload,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CloudSyncShadow.fromJson(CloudSyncJsonMap json) {
    _requireVersion(json);
    final deleted = json['deleted'];
    if (deleted is! bool) {
      throw const FormatException('deleted 必须为布尔值');
    }
    return CloudSyncShadow(
      entityType: CloudSyncEntityType.parse(_requireString(json, 'entityType')),
      entityId: _requireString(json, 'entityId'),
      parentId: _optionalString(json, 'parentId'),
      revision: _requireInt(json, 'revision'),
      schemaVersion: _requireInt(json, 'schemaVersion'),
      lastChangeSeq: _requireInt(json, 'lastChangeSeq'),
      deleted: deleted,
      payload: json['payload'] == null
          ? null
          : copyCloudSyncJsonMap(json['payload']),
      updatedAt: _requireDateTime(json, 'updatedAt'),
    );
  }
}

final class CloudSyncCursorState {
  const CloudSyncCursorState({
    this.pullCursor,
    this.snapshotCursor,
    this.snapshotSyncCursor,
  });

  final String? pullCursor;
  final String? snapshotCursor;
  final String? snapshotSyncCursor;

  CloudSyncJsonMap toJson() => <String, Object?>{
    'version': 1,
    if (pullCursor != null) 'pullCursor': pullCursor,
    if (snapshotCursor != null) 'snapshotCursor': snapshotCursor,
    if (snapshotSyncCursor != null) 'snapshotSyncCursor': snapshotSyncCursor,
  };

  factory CloudSyncCursorState.fromJson(CloudSyncJsonMap json) {
    _requireVersion(json);
    return CloudSyncCursorState(
      pullCursor: _optionalString(json, 'pullCursor'),
      snapshotCursor: _optionalString(json, 'snapshotCursor'),
      snapshotSyncCursor: _optionalString(json, 'snapshotSyncCursor'),
    );
  }
}

final class CloudSyncMutationResult {
  const CloudSyncMutationResult({
    required this.mutationId,
    required this.status,
    required this.retryable,
    this.revision,
    this.changeSeq,
    this.currentRevision,
    this.reason,
    this.errorCode,
  });

  final String mutationId;
  final CloudSyncMutationStatus status;
  final bool retryable;
  final int? revision;
  final int? changeSeq;
  final int? currentRevision;
  final String? reason;
  final String? errorCode;
}

final class CloudSyncRecord {
  CloudSyncRecord({
    required this.entityType,
    required String entityId,
    required String? parentId,
    required this.revision,
    required this.schemaVersion,
    required this.sortSeq,
    required CloudSyncJsonMap payload,
    required DateTime? deletedAt,
    required DateTime updatedAt,
    required String? updatedByDeviceId,
    required this.lastChangeSeq,
  }) : entityId = _validatedId(entityId, 'entityId'),
       parentId = _validatedOptionalId(parentId, 'parentId'),
       payload = copyCloudSyncJsonMap(payload),
       deletedAt = deletedAt?.toUtc(),
       updatedAt = updatedAt.toUtc(),
       updatedByDeviceId = _validatedOptionalId(
         updatedByDeviceId,
         'updatedByDeviceId',
       ) {
    if (revision < 1 || schemaVersion < 1 || lastChangeSeq < 1) {
      throw const FormatException('服务端记录版本号无效');
    }
  }

  final CloudSyncEntityType entityType;
  final String entityId;
  final String? parentId;
  final int revision;
  final int schemaVersion;
  final int? sortSeq;
  final CloudSyncJsonMap payload;
  final DateTime? deletedAt;
  final DateTime updatedAt;
  final String? updatedByDeviceId;
  final int lastChangeSeq;
}

final class CloudSyncChange {
  const CloudSyncChange._({
    required this.changeSeq,
    required this.operation,
    required this.record,
    required this.entityType,
    required this.entityId,
    required this.revision,
    required this.deletedAt,
  });

  factory CloudSyncChange.upsert({
    required int changeSeq,
    required CloudSyncRecord record,
  }) {
    return CloudSyncChange._(
      changeSeq: changeSeq,
      operation: CloudSyncChangeOperation.upsert,
      record: record,
      entityType: record.entityType,
      entityId: record.entityId,
      revision: record.revision,
      deletedAt: record.deletedAt,
    );
  }

  factory CloudSyncChange.delete({
    required int changeSeq,
    required CloudSyncEntityType entityType,
    required String entityId,
    required int revision,
    required DateTime deletedAt,
  }) {
    return CloudSyncChange._(
      changeSeq: changeSeq,
      operation: CloudSyncChangeOperation.delete,
      record: null,
      entityType: entityType,
      entityId: entityId,
      revision: revision,
      deletedAt: deletedAt,
    );
  }

  final int changeSeq;
  final CloudSyncChangeOperation operation;
  final CloudSyncRecord? record;
  final CloudSyncEntityType entityType;
  final String entityId;
  final int revision;
  final DateTime? deletedAt;
}

final class CloudSyncPullResult {
  const CloudSyncPullResult({
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
    required this.resetRequired,
  });

  final List<CloudSyncChange> changes;
  final String nextCursor;
  final bool hasMore;
  final bool resetRequired;
}

final class CloudSyncSnapshotResult {
  const CloudSyncSnapshotResult({
    required this.records,
    required this.nextSnapshotCursor,
    required this.syncCursor,
    required this.hasMore,
  });

  final List<CloudSyncRecord> records;
  final String? nextSnapshotCursor;
  final String? syncCursor;
  final bool hasMore;
}

CloudSyncOutboxMutation _revisionMutation({
  required String mutationId,
  required CloudSyncEntityType entityType,
  required String entityId,
  required int baseRevision,
  required CloudSyncMutationOperation operation,
  DateTime? createdAt,
}) {
  if (baseRevision < 1) {
    throw const FormatException('baseRevision 必须大于 0');
  }
  final now = (createdAt ?? DateTime.now()).toUtc();
  return CloudSyncOutboxMutation._(
    mutationId: _validatedId(mutationId, 'mutationId'),
    entityType: entityType,
    entityId: _validatedId(entityId, 'entityId'),
    operation: operation,
    parentId: null,
    baseRevision: baseRevision,
    schemaVersion: null,
    payload: null,
    patch: const <CloudSyncPatch>[],
    attemptCount: 0,
    createdAt: now,
    nextAttemptAt: now,
    lastErrorCode: null,
  );
}

List<CloudSyncPatch> _decodePatchList(Object? value) {
  if (value is! List<Object?> || value.isEmpty) {
    throw const FormatException('patch 必须为非空数组');
  }
  return List<CloudSyncPatch>.unmodifiable(
    value.map((item) => CloudSyncPatch.fromJson(copyCloudSyncJsonMap(item))),
  );
}

String _validatedPatchPath(String value) {
  final pattern = RegExp(r'^/(?:[^~/]|~[01])+(?:/(?:[^~/]|~[01])*)*$');
  if (value.length > 512 || !pattern.hasMatch(value)) {
    throw const FormatException('patch 路径必须是合法的非根 JSON Pointer');
  }
  return value;
}

String _validatedId(String value, String field) {
  _requireNonEmpty(value, field);
  if (value.length > 128) {
    throw FormatException('$field 不能超过 128 个字符');
  }
  return value;
}

String _validatedUuid(String value, String field) {
  final normalized = value.trim().toLowerCase();
  if (!RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  ).hasMatch(normalized)) {
    throw FormatException('$field 必须为 UUID');
  }
  return normalized;
}

String? _validatedOptionalId(String? value, String field) {
  if (value == null) return null;
  return _validatedId(value, field);
}

String _validatedAttachmentEntityType(String value) {
  final normalized = value.trim();
  if (normalized.length > 64 ||
      !RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(normalized)) {
    throw const FormatException('附件实体类型无效');
  }
  return normalized;
}

String _validatedAttachmentFileName(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 255) {
    throw const FormatException('附件文件名无效');
  }
  return normalized;
}

String _validatedAttachmentMimeType(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.length < 3 ||
      normalized.length > 255 ||
      !RegExp(r'^[^\s/\[\]\|]+/[^\s/\[\]\|]+$').hasMatch(normalized)) {
    throw const FormatException('附件 MIME 类型无效');
  }
  return normalized;
}

String _validatedSha256(String value) {
  final normalized = value.trim().toLowerCase();
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(normalized)) {
    throw const FormatException('附件 SHA-256 摘要无效');
  }
  return normalized;
}

String _validatedMd5Base64(String value) {
  final normalized = value.trim();
  if (!RegExp(r'^[A-Za-z0-9+/]{22}==$').hasMatch(normalized)) {
    throw const FormatException('附件 MD5 摘要无效');
  }
  return normalized;
}

String _validatedLocalPath(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw const FormatException('附件本地路径不能为空');
  }
  return normalized;
}

void _validateAttachmentSize(int value) {
  if (value < 0 || value > maximumCloudSyncAttachmentSizeBytes) {
    throw const FormatException('附件大小超出允许范围');
  }
}

String _validatedHttpUrl(String value, String field) {
  final normalized = value.trim();
  final uri = Uri.tryParse(normalized);
  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw FormatException('$field 格式无效');
  }
  return normalized;
}

String? _validatedOptionalHttpUrl(String? value, String field) {
  return value == null ? null : _validatedHttpUrl(value, field);
}

String? _validatedOptionalNonEmpty(String? value, String field) {
  if (value == null) return null;
  final normalized = value.trim();
  _requireNonEmpty(normalized, field);
  return normalized;
}

void _requireNonEmpty(String value, String field) {
  if (value.trim().isEmpty) {
    throw FormatException('$field 不能为空');
  }
}

void _requireVersion(CloudSyncJsonMap json) {
  if (json['version'] != 1) {
    throw const FormatException('不支持的本地同步状态版本');
  }
}

String _requireString(CloudSyncJsonMap json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key 必须为非空字符串');
  }
  return value;
}

String? _optionalString(CloudSyncJsonMap json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.isEmpty) {
    throw FormatException('$key 必须为非空字符串或 null');
  }
  return value;
}

int _requireInt(CloudSyncJsonMap json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('$key 必须为整数');
  }
  return value;
}

int? _optionalInt(CloudSyncJsonMap json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! int) {
    throw FormatException('$key 必须为整数或 null');
  }
  return value;
}

DateTime _requireDateTime(CloudSyncJsonMap json, String key) {
  final value = _requireString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('$key 必须为 ISO 8601 时间');
  }
  return parsed.toUtc();
}

T _parseEnum<T extends Enum>(List<T> values, String name, String field) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('$field 枚举值无效');
}

bool isSupportedCloudSyncEntityType(String value) {
  return _supportedEntityTypes.contains(value);
}
