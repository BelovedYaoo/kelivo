typedef CloudSyncJsonMap = Map<String, Object?>;

const defaultCloudSyncBaseUrl = 'https://kelivo.bemylover.top';
const maximumCloudSyncAttachmentSizeBytes = 100 * 1024 * 1024;

bool isAllowedCloudSyncTransportUri(Uri uri) {
  if (uri.scheme == 'https') return uri.host.isNotEmpty;
  if (uri.scheme != 'http' || uri.host.isEmpty) return false;
  final host = uri.host.toLowerCase();
  return host == 'localhost' || host == '127.0.0.1' || host == '::1';
}

String normalizeCloudSyncBaseUrl(String value) {
  final trimmed = value.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null ||
      !isAllowedCloudSyncTransportUri(uri) ||
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

  CloudSyncJsonMap toMetadataJson() {
    final metadata = toJson();
    metadata.remove('token');
    return metadata;
  }

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

  factory CloudSyncAccountSession.fromMetadataJson(
    CloudSyncJsonMap json, {
    required String token,
  }) {
    if (json.containsKey('token')) {
      throw const FormatException('session_metadata_token');
    }
    return CloudSyncAccountSession.fromJson(<String, Object?>{
      ...json,
      'token': token,
    });
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

int _requireInt(CloudSyncJsonMap json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('$key 必须为整数');
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
