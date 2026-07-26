import 'dart:typed_data';

typedef CloudSyncJsonMap = Map<String, Object?>;

const defaultCloudSyncBaseUrl = 'https://kelivo.bemylover.top';
const maximumCloudSyncAttachmentSizeBytes = 100 * 1024 * 1024;
const cloudSyncOpaqueProtocolVersion = 1;
const cloudSyncOpaqueRegistrationRequestBytes = 48;
const cloudSyncOpaqueRegistrationResponseBytes = 80;
const cloudSyncOpaqueRegistrationUploadBytes = 208;
const cloudSyncOpaqueCredentialRequestBytes = 112;
const cloudSyncOpaqueCredentialResponseBytes = 336;
const cloudSyncOpaqueCredentialFinalizationBytes = 80;
const cloudSyncDevicePublicKeyBytes = 32;
const cloudSyncDeviceChallengeBytes = 32;
const cloudSyncDeviceProofBytes = 64;
const cloudSyncAccountKeyEnvelopeBytes = 336;
const cloudSyncPairingSecretHashBytes = 32;
const cloudSyncPairingAuthenticatorBytes = 32;

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

enum CloudSyncAuthenticatedDeviceStatus { pending, active }

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

final class CloudSyncFullSessionToken {
  CloudSyncFullSessionToken._(this.value);

  factory CloudSyncFullSessionToken.parse(String value) {
    if (!_fullSessionTokenPattern.hasMatch(value)) {
      throw const FormatException('完整会话令牌格式无效');
    }
    return CloudSyncFullSessionToken._(value);
  }

  final String value;

  @override
  String toString() => 'CloudSyncFullSessionToken(<已隐藏>)';
}

final class CloudSyncOnboardingToken {
  CloudSyncOnboardingToken._(this.value);

  factory CloudSyncOnboardingToken.parse(String value) {
    if (!_onboardingTokenPattern.hasMatch(value)) {
      throw const FormatException('设备引导令牌格式无效');
    }
    return CloudSyncOnboardingToken._(value);
  }

  final String value;

  @override
  String toString() => 'CloudSyncOnboardingToken(<已隐藏>)';
}

final class CloudSyncOpaqueDeviceIdentity {
  CloudSyncOpaqueDeviceIdentity({
    required String deviceId,
    required String deviceName,
    required this.platform,
    required String clientVersion,
    required int deviceKeyVersion,
    required Uint8List signingPublicKey,
    required Uint8List keyAgreementPublicKey,
  }) : deviceId = _requireCanonicalUuid(deviceId, 'deviceId'),
       deviceName = _requireBoundedText(deviceName, 'deviceName', 80),
       clientVersion = _requireClientVersion(clientVersion),
       deviceKeyVersion = _requirePositiveInt32(
         deviceKeyVersion,
         'deviceKeyVersion',
       ),
       signingPublicKey = _copyFixedBytes(
         signingPublicKey,
         cloudSyncDevicePublicKeyBytes,
         'signingPublicKey',
       ),
       keyAgreementPublicKey = _copyFixedBytes(
         keyAgreementPublicKey,
         cloudSyncDevicePublicKeyBytes,
         'keyAgreementPublicKey',
       );

  final String deviceId;
  final String deviceName;
  final CloudSyncPlatform platform;
  final String clientVersion;
  final int deviceKeyVersion;
  final Uint8List signingPublicKey;
  final Uint8List keyAgreementPublicKey;
}

final class CloudSyncOpaqueRegistrationStart {
  CloudSyncOpaqueRegistrationStart({
    required String attemptId,
    required String userId,
    required String accountBinding,
    required Uint8List deviceChallenge,
    required Uint8List registrationResponse,
    required DateTime expiresAt,
  }) : attemptId = _requireCanonicalUuid(attemptId, 'attemptId'),
       userId = _requireCanonicalUuid(userId, 'userId'),
       accountBinding = _requireCanonicalUuid(accountBinding, 'accountBinding'),
       deviceChallenge = _copyFixedBytes(
         deviceChallenge,
         cloudSyncDeviceChallengeBytes,
         'deviceChallenge',
       ),
       registrationResponse = _copyFixedBytes(
         registrationResponse,
         cloudSyncOpaqueRegistrationResponseBytes,
         'registrationResponse',
       ),
       expiresAt = expiresAt.toUtc();

  final String attemptId;
  final String userId;
  final String accountBinding;
  final Uint8List deviceChallenge;
  final Uint8List registrationResponse;
  final DateTime expiresAt;
}

final class CloudSyncOpaqueLoginStart {
  CloudSyncOpaqueLoginStart({
    required String attemptId,
    required String accountBinding,
    required Uint8List deviceChallenge,
    required Uint8List credentialResponse,
    required DateTime expiresAt,
  }) : attemptId = _requireCanonicalUuid(attemptId, 'attemptId'),
       accountBinding = _requireCanonicalUuid(accountBinding, 'accountBinding'),
       deviceChallenge = _copyFixedBytes(
         deviceChallenge,
         cloudSyncDeviceChallengeBytes,
         'deviceChallenge',
       ),
       credentialResponse = _copyFixedBytes(
         credentialResponse,
         cloudSyncOpaqueCredentialResponseBytes,
         'credentialResponse',
       ),
       expiresAt = expiresAt.toUtc();

  final String attemptId;
  final String accountBinding;
  final Uint8List deviceChallenge;
  final Uint8List credentialResponse;
  final DateTime expiresAt;
}

final class CloudSyncAuthenticatedUser {
  CloudSyncAuthenticatedUser({
    required String id,
    required String loginName,
    required String displayName,
    required this.role,
    required int attachmentQuotaBytes,
  }) : id = _requireCanonicalUuid(id, 'user.id'),
       loginName = _requireNormalizedLoginName(loginName),
       displayName = _requireBoundedText(displayName, 'user.displayName', 80),
       attachmentQuotaBytes = _requireNonNegativeSafeInteger(
         attachmentQuotaBytes,
         'user.attachmentQuotaBytes',
       );

  final String id;
  final String loginName;
  final String displayName;
  final CloudSyncUserRole role;
  final int attachmentQuotaBytes;
}

final class CloudSyncAuthenticatedDevice {
  CloudSyncAuthenticatedDevice({
    required String id,
    required String name,
    required this.platform,
    required String clientVersion,
    required this.status,
    required DateTime createdAt,
  }) : id = _requireCanonicalUuid(id, 'device.id'),
       name = _requireBoundedText(name, 'device.name', 80),
       clientVersion = _requireClientVersion(clientVersion),
       createdAt = createdAt.toUtc();

  final String id;
  final String name;
  final CloudSyncPlatform platform;
  final String clientVersion;
  final CloudSyncAuthenticatedDeviceStatus status;
  final DateTime createdAt;
}

final class CloudSyncAuthenticatedSession {
  CloudSyncAuthenticatedSession({
    required this.token,
    required DateTime tokenExpiresAt,
    required int keyEpoch,
    required this.user,
    required this.device,
  }) : tokenExpiresAt = tokenExpiresAt.toUtc(),
       keyEpoch = _requirePositiveUint32(keyEpoch, 'keyEpoch') {
    if (device.status != CloudSyncAuthenticatedDeviceStatus.active) {
      throw const FormatException('已认证会话的设备状态必须为 active');
    }
  }

  final CloudSyncFullSessionToken token;
  final DateTime tokenExpiresAt;
  final int keyEpoch;
  final CloudSyncAuthenticatedUser user;
  final CloudSyncAuthenticatedDevice device;
}

sealed class CloudSyncOpaqueLoginFinishResult {
  const CloudSyncOpaqueLoginFinishResult();
}

final class CloudSyncOpaqueLoginAuthenticated
    extends CloudSyncOpaqueLoginFinishResult {
  const CloudSyncOpaqueLoginAuthenticated(this.session);

  final CloudSyncAuthenticatedSession session;
}

final class CloudSyncOpaqueLoginApprovalRequired
    extends CloudSyncOpaqueLoginFinishResult {
  CloudSyncOpaqueLoginApprovalRequired({
    required this.onboardingToken,
    required DateTime onboardingTokenExpiresAt,
    required this.device,
  }) : onboardingTokenExpiresAt = onboardingTokenExpiresAt.toUtc() {
    if (device.status != CloudSyncAuthenticatedDeviceStatus.pending) {
      throw const FormatException('待批准设备的状态必须为 pending');
    }
  }

  final CloudSyncOnboardingToken onboardingToken;
  final DateTime onboardingTokenExpiresAt;
  final CloudSyncAuthenticatedDevice device;
}

final class CloudSyncDevicePairingTarget {
  CloudSyncDevicePairingTarget({
    required String id,
    required String name,
    required this.platform,
    required String clientVersion,
    required int keyVersion,
    required int authGeneration,
    required Uint8List signingPublicKey,
    required Uint8List keyAgreementPublicKey,
  }) : id = _requireCanonicalUuid(id, 'targetDevice.id'),
       name = _requireBoundedText(name, 'targetDevice.name', 80),
       clientVersion = _requireClientVersion(clientVersion),
       keyVersion = _requirePositiveInt32(
         keyVersion,
         'targetDevice.keyVersion',
       ),
       authGeneration = _requireNonNegativeInt32(
         authGeneration,
         'targetDevice.authGeneration',
       ),
       signingPublicKey = _copyFixedBytes(
         signingPublicKey,
         cloudSyncDevicePublicKeyBytes,
         'targetDevice.signingPublicKey',
       ),
       keyAgreementPublicKey = _copyFixedBytes(
         keyAgreementPublicKey,
         cloudSyncDevicePublicKeyBytes,
         'targetDevice.keyAgreementPublicKey',
       );

  final String id;
  final String name;
  final CloudSyncPlatform platform;
  final String clientVersion;
  final int keyVersion;
  final int authGeneration;
  final Uint8List signingPublicKey;
  final Uint8List keyAgreementPublicKey;
}

final class CloudSyncDevicePairingCreated {
  CloudSyncDevicePairingCreated({
    required String pairingId,
    required String accountContextId,
    required Uint8List challenge,
    required DateTime expiresAt,
    required this.targetDevice,
  }) : pairingId = _requireCanonicalUuid(pairingId, 'pairingId'),
       accountContextId = _requireCanonicalUuid(
         accountContextId,
         'accountContextId',
       ),
       challenge = _copyFixedBytes(
         challenge,
         cloudSyncDeviceChallengeBytes,
         'challenge',
       ),
       expiresAt = expiresAt.toUtc();

  final String pairingId;
  final String accountContextId;
  final Uint8List challenge;
  final DateTime expiresAt;
  final CloudSyncDevicePairingTarget targetDevice;
}

sealed class CloudSyncDevicePairingQueryResult {
  CloudSyncDevicePairingQueryResult({
    required String pairingId,
    required String accountContextId,
    required Uint8List challenge,
    required DateTime expiresAt,
    required this.targetDevice,
  }) : pairingId = _requireCanonicalUuid(pairingId, 'pairingId'),
       accountContextId = _requireCanonicalUuid(
         accountContextId,
         'accountContextId',
       ),
       challenge = _copyFixedBytes(
         challenge,
         cloudSyncDeviceChallengeBytes,
         'challenge',
       ),
       expiresAt = expiresAt.toUtc();

  final String pairingId;
  final String accountContextId;
  final Uint8List challenge;
  final DateTime expiresAt;
  final CloudSyncDevicePairingTarget targetDevice;
}

final class CloudSyncDevicePairingPending
    extends CloudSyncDevicePairingQueryResult {
  CloudSyncDevicePairingPending({
    required super.pairingId,
    required super.accountContextId,
    required super.challenge,
    required super.expiresAt,
    required super.targetDevice,
  });
}

final class CloudSyncDevicePairingApproved
    extends CloudSyncDevicePairingQueryResult {
  CloudSyncDevicePairingApproved({
    required super.pairingId,
    required super.accountContextId,
    required super.challenge,
    required super.expiresAt,
    required super.targetDevice,
    required String issuerDeviceId,
    required Uint8List issuerSigningPublicKey,
    required Uint8List issuerKeyAgreementPublicKey,
    required int keyEpoch,
    required Uint8List accountKeyEnvelope,
    required Uint8List deviceProof,
    required Uint8List pairingAuthenticator,
  }) : issuerDeviceId = _requireCanonicalUuid(issuerDeviceId, 'issuerDeviceId'),
       issuerSigningPublicKey = _copyFixedBytes(
         issuerSigningPublicKey,
         cloudSyncDevicePublicKeyBytes,
         'issuerSigningPublicKey',
       ),
       issuerKeyAgreementPublicKey = _copyFixedBytes(
         issuerKeyAgreementPublicKey,
         cloudSyncDevicePublicKeyBytes,
         'issuerKeyAgreementPublicKey',
       ),
       keyEpoch = _requirePositiveUint32(keyEpoch, 'keyEpoch'),
       accountKeyEnvelope = _copyFixedBytes(
         accountKeyEnvelope,
         cloudSyncAccountKeyEnvelopeBytes,
         'accountKeyEnvelope',
       ),
       deviceProof = _copyFixedBytes(
         deviceProof,
         cloudSyncDeviceProofBytes,
         'deviceProof',
       ),
       pairingAuthenticator = _copyFixedBytes(
         pairingAuthenticator,
         cloudSyncPairingAuthenticatorBytes,
         'pairingAuthenticator',
       );

  final String issuerDeviceId;
  final Uint8List issuerSigningPublicKey;
  final Uint8List issuerKeyAgreementPublicKey;
  final int keyEpoch;
  final Uint8List accountKeyEnvelope;
  final Uint8List deviceProof;
  final Uint8List pairingAuthenticator;
}

final class CloudSyncDevicePairingApproval {
  CloudSyncDevicePairingApproval({
    required String pairingId,
    required DateTime approvedAt,
  }) : pairingId = _requireCanonicalUuid(pairingId, 'pairingId'),
       approvedAt = approvedAt.toUtc();

  final String pairingId;
  final DateTime approvedAt;
}

final class CloudSyncDevicePairingCancellation {
  CloudSyncDevicePairingCancellation({
    required String pairingId,
    required DateTime cancelledAt,
  }) : pairingId = _requireCanonicalUuid(pairingId, 'pairingId'),
       cancelledAt = cancelledAt.toUtc();

  final String pairingId;
  final DateTime cancelledAt;
}

final class CloudSyncAccountSession {
  static const _jsonKeys = <String>{..._metadataKeys, 'token'};
  static const _metadataKeys = <String>{
    'version',
    'baseUrl',
    'tokenExpiresAt',
    'keyEpoch',
    'userId',
    'loginName',
    'displayName',
    'role',
    'attachmentQuotaBytes',
    'deviceId',
    'deviceName',
    'platform',
    'clientVersion',
    'deviceCreatedAt',
  };

  CloudSyncAccountSession({
    required String baseUrl,
    required this.token,
    required DateTime tokenExpiresAt,
    required int keyEpoch,
    required String userId,
    required String loginName,
    required String displayName,
    required this.role,
    required int attachmentQuotaBytes,
    required String deviceId,
    required String deviceName,
    required this.platform,
    required String clientVersion,
    required DateTime deviceCreatedAt,
  }) : baseUrl = normalizeCloudSyncBaseUrl(baseUrl),
       tokenExpiresAt = tokenExpiresAt.toUtc(),
       keyEpoch = _requirePositiveUint32(keyEpoch, 'keyEpoch'),
       userId = _requireCanonicalUuid(userId, 'userId'),
       loginName = _requireNormalizedLoginName(loginName),
       displayName = _requireBoundedText(displayName, 'displayName', 80),
       attachmentQuotaBytes = _requireNonNegativeSafeInteger(
         attachmentQuotaBytes,
         'attachmentQuotaBytes',
       ),
       deviceId = _requireCanonicalUuid(deviceId, 'deviceId'),
       deviceName = _requireBoundedText(deviceName, 'deviceName', 80),
       clientVersion = _requireClientVersion(clientVersion),
       deviceCreatedAt = deviceCreatedAt.toUtc();

  factory CloudSyncAccountSession.fromAuthenticatedSession({
    required String baseUrl,
    required CloudSyncAuthenticatedSession session,
  }) {
    final user = session.user;
    final device = session.device;
    return CloudSyncAccountSession(
      baseUrl: baseUrl,
      token: session.token,
      tokenExpiresAt: session.tokenExpiresAt,
      keyEpoch: session.keyEpoch,
      userId: user.id,
      loginName: user.loginName,
      displayName: user.displayName,
      role: user.role,
      attachmentQuotaBytes: user.attachmentQuotaBytes,
      deviceId: device.id,
      deviceName: device.name,
      platform: device.platform,
      clientVersion: device.clientVersion,
      deviceCreatedAt: device.createdAt,
    );
  }

  final String baseUrl;
  final CloudSyncFullSessionToken token;
  final DateTime tokenExpiresAt;
  final int keyEpoch;
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

  bool isExpiredAt(DateTime now) => !now.toUtc().isBefore(tokenExpiresAt);

  CloudSyncJsonMap toJson() => <String, Object?>{
    'version': 2,
    'baseUrl': baseUrl,
    'token': token.value,
    'tokenExpiresAt': tokenExpiresAt.toIso8601String(),
    'keyEpoch': keyEpoch,
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
    _requireExactKeys(json, _jsonKeys, '账号会话 JSON');
    _requireAccountSessionVersion(json);
    return CloudSyncAccountSession(
      baseUrl: _requireString(json, 'baseUrl'),
      token: CloudSyncFullSessionToken.parse(_requireString(json, 'token')),
      tokenExpiresAt: _requireCanonicalUtcDateTime(json, 'tokenExpiresAt'),
      keyEpoch: _requireInt(json, 'keyEpoch'),
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
      deviceCreatedAt: _requireCanonicalUtcDateTime(json, 'deviceCreatedAt'),
    );
  }

  factory CloudSyncAccountSession.fromMetadataJson(
    CloudSyncJsonMap json, {
    required CloudSyncFullSessionToken token,
  }) {
    _requireExactKeys(json, _metadataKeys, '账号会话 metadata');
    return CloudSyncAccountSession.fromJson(<String, Object?>{
      ...json,
      'token': token.value,
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

final _canonicalUuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final _normalizedLoginNamePattern = RegExp(r'^[a-z0-9][a-z0-9._-]*$');
final _clientVersionPattern = RegExp(r'^[0-9A-Za-z][0-9A-Za-z.+_-]*$');
final _fullSessionTokenPattern = RegExp(r'^kelivo_[A-Za-z0-9_-]{43}$');
final _onboardingTokenPattern = RegExp(
  r'^kelivo_onboarding_[A-Za-z0-9_-]{43}$',
);

String _requireCanonicalUuid(String value, String field) {
  if (!_canonicalUuidV4Pattern.hasMatch(value)) {
    throw FormatException('$field 必须为规范的小写 UUID v4');
  }
  return value;
}

String _requireNormalizedLoginName(String value) {
  if (value.length < 3 ||
      value.length > 64 ||
      !_normalizedLoginNamePattern.hasMatch(value)) {
    throw const FormatException('loginName 必须为规范登录名');
  }
  return value;
}

String _requireBoundedText(String value, String field, int maximumLength) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > maximumLength) {
    throw FormatException('$field 长度无效');
  }
  return normalized;
}

String _requireClientVersion(String value) {
  if (value.isEmpty ||
      value.length > 32 ||
      !_clientVersionPattern.hasMatch(value)) {
    throw const FormatException('clientVersion 格式无效');
  }
  return value;
}

int _requirePositiveInt32(int value, String field) {
  if (value < 1 || value > 0x7fffffff) {
    throw FormatException('$field 必须位于正 int32 范围');
  }
  return value;
}

int _requireNonNegativeInt32(int value, String field) {
  if (value < 0 || value > 0x7fffffff) {
    throw FormatException('$field 必须位于非负 int32 范围');
  }
  return value;
}

int _requirePositiveUint32(int value, String field) {
  if (value < 1 || value > 0xffffffff) {
    throw FormatException('$field 必须位于正 uint32 范围');
  }
  return value;
}

int _requireNonNegativeSafeInteger(int value, String field) {
  if (value < 0 || value > 9007199254740991) {
    throw FormatException('$field 必须为非负安全整数');
  }
  return value;
}

Uint8List _copyFixedBytes(Uint8List value, int length, String field) {
  if (value.length != length) {
    throw FormatException('$field 必须为 $length 字节');
  }
  return Uint8List.fromList(value).asUnmodifiableView();
}

void _requireAccountSessionVersion(CloudSyncJsonMap json) {
  final version = json['version'];
  if (version is! int || version != 2) {
    throw const FormatException('不支持的本地同步状态版本');
  }
}

void _requireExactKeys(
  CloudSyncJsonMap json,
  Set<String> expected,
  String context,
) {
  if (json.length != expected.length || !json.keys.every(expected.contains)) {
    throw FormatException('$context 字段集合无效');
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

DateTime _requireCanonicalUtcDateTime(CloudSyncJsonMap json, String key) {
  final value = _requireString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc || parsed.toIso8601String() != value) {
    throw FormatException('$key 必须为规范 UTC 时间');
  }
  return parsed;
}

T _parseEnum<T extends Enum>(List<T> values, String name, String field) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('$field 枚举值无效');
}
