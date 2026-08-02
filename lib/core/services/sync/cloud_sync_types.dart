import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'e2ee_self_revocation_rotation_binding.dart';

part 'cloud_sync_data_rekey_types.dart';
part 'cloud_sync_data_rekey_transport_types.dart';

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
const cloudSyncMembershipManifestDigestBytes = 32;
const cloudSyncMembershipManifestMinimumBytes = 476;
const cloudSyncMembershipManifestMaximumBytes = 22916;
const cloudSyncRecoveryPublicKeyBytes = 32;
const cloudSyncRecoveryCapsuleBytes = 156;
const cloudSyncRecoveryCapsuleMaximumBytes = 4096;
const cloudSyncAccountSecurityEnvelopeMaximumCount = 256;
const cloudSyncSelfRevocationIntentDigestBytes = 32;
const cloudSyncSelfRevocationIntentSignatureBytes = 64;

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

String cloudSyncAccountScope({
  required String canonicalBaseUrl,
  required String userId,
}) {
  if (normalizeCloudSyncBaseUrl(canonicalBaseUrl) != canonicalBaseUrl) {
    throw const FormatException('同步服务地址必须为规范形式');
  }
  final canonicalUserId = _requireCanonicalUuid(userId, 'userId');
  return Uri.encodeComponent('$canonicalBaseUrl\n$canonicalUserId');
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

enum CloudSyncDataRekeyPhase { ready, rekeyPending }

enum CloudSyncSecurityBootstrapSource { firstRegistration, pairing }

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

  factory CloudSyncFullSessionToken.generate() {
    final random = Random.secure();
    final tokenBytes = Uint8List(32);
    try {
      for (var index = 0; index < tokenBytes.length; index++) {
        tokenBytes[index] = random.nextInt(256);
      }
      final encoded = base64Url.encode(tokenBytes).replaceAll('=', '');
      return CloudSyncFullSessionToken.parse('kelivo_$encoded');
    } finally {
      tokenBytes.fillRange(0, tokenBytes.length, 0);
    }
  }

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

final class CloudSyncSelfRevocationContinuationToken {
  CloudSyncSelfRevocationContinuationToken._(this.value);

  factory CloudSyncSelfRevocationContinuationToken.generate() {
    final random = Random.secure();
    final tokenBytes = Uint8List(32);
    try {
      for (var index = 0; index < tokenBytes.length; index++) {
        tokenBytes[index] = random.nextInt(256);
      }
      final encoded = base64Url.encode(tokenBytes).replaceAll('=', '');
      return CloudSyncSelfRevocationContinuationToken.parse(
        'kelivo_revocation_$encoded',
      );
    } finally {
      tokenBytes.fillRange(0, tokenBytes.length, 0);
    }
  }

  factory CloudSyncSelfRevocationContinuationToken.parse(String value) {
    if (!_selfRevocationContinuationTokenPattern.hasMatch(value)) {
      throw const FormatException('自撤销续查令牌格式无效');
    }
    return CloudSyncSelfRevocationContinuationToken._(value);
  }

  final String value;

  @override
  String toString() => 'CloudSyncSelfRevocationContinuationToken(<已隐藏>)';
}

final class CloudSyncMembershipManifestDigest {
  CloudSyncMembershipManifestDigest._(this.bytes, this.encoded);

  factory CloudSyncMembershipManifestDigest.fromBytes(Uint8List value) {
    final bytes = _copyFixedBytes(
      value,
      cloudSyncMembershipManifestDigestBytes,
      'membershipManifestDigest',
    );
    return CloudSyncMembershipManifestDigest._(
      bytes,
      base64Url.encode(bytes).replaceAll('=', ''),
    );
  }

  factory CloudSyncMembershipManifestDigest.parse(String value) {
    if (value.length != 43 || !_canonicalBase64UrlPattern.hasMatch(value)) {
      throw const FormatException('成员清单摘要格式无效');
    }
    try {
      final decoded = base64Url.decode('$value=');
      final canonical = base64Url.encode(decoded).replaceAll('=', '');
      if (decoded.length != cloudSyncMembershipManifestDigestBytes ||
          canonical != value) {
        throw const FormatException('成员清单摘要不是规范编码');
      }
      return CloudSyncMembershipManifestDigest.fromBytes(
        Uint8List.fromList(decoded),
      );
    } on FormatException {
      throw const FormatException('成员清单摘要格式无效');
    }
  }

  final Uint8List bytes;
  final String encoded;
}

final class CloudSyncSelfRevocationRequest {
  factory CloudSyncSelfRevocationRequest({
    required String deviceId,
    required String mutationId,
    required String operationId,
    required int expectedGeneration,
    required int expectedKeyEpoch,
    required CloudSyncMembershipManifestDigest expectedMembershipManifestDigest,
    required DateTime expiresAt,
    required CloudSyncSelfRevocationContinuationToken continuationToken,
    required Uint8List intentDigest,
    required Uint8List intentSignature,
  }) {
    if (!expiresAt.isUtc ||
        expiresAt.microsecond != 0 ||
        expiresAt.millisecondsSinceEpoch < 0) {
      throw const FormatException('自撤销意图到期时间必须为毫秒精度 UTC 时间');
    }
    return CloudSyncSelfRevocationRequest._(
      deviceId: _requireCanonicalUuid(deviceId, 'deviceId'),
      mutationId: _requireCanonicalUuid(mutationId, 'mutationId'),
      operationId: _requireCanonicalUuid(operationId, 'operationId'),
      expectedGeneration: _requireBoundedInt(
        expectedGeneration,
        'expectedGeneration',
        maximum: 0x7ffffffe,
      ),
      expectedKeyEpoch: _requireBoundedInt(
        expectedKeyEpoch,
        'expectedKeyEpoch',
        maximum: 0xfffffffe,
      ),
      expectedMembershipManifestDigest: expectedMembershipManifestDigest,
      expiresAt: expiresAt,
      continuationToken: continuationToken,
      intentDigest: _copyFixedBytes(
        intentDigest,
        cloudSyncSelfRevocationIntentDigestBytes,
        'intentDigest',
      ),
      intentSignature: _copyFixedBytes(
        intentSignature,
        cloudSyncSelfRevocationIntentSignatureBytes,
        'intentSignature',
      ),
    );
  }

  const CloudSyncSelfRevocationRequest._({
    required this.deviceId,
    required this.mutationId,
    required this.operationId,
    required this.expectedGeneration,
    required this.expectedKeyEpoch,
    required this.expectedMembershipManifestDigest,
    required this.expiresAt,
    required this.continuationToken,
    required this.intentDigest,
    required this.intentSignature,
  });

  final String deviceId;
  final String mutationId;
  final String operationId;
  final int expectedGeneration;
  final int expectedKeyEpoch;
  final CloudSyncMembershipManifestDigest expectedMembershipManifestDigest;
  final DateTime expiresAt;
  final CloudSyncSelfRevocationContinuationToken continuationToken;
  final Uint8List intentDigest;
  final Uint8List intentSignature;
}

final class CloudSyncSelfRevocationRequestResult {
  factory CloudSyncSelfRevocationRequestResult.fromJson(
    CloudSyncJsonMap json, {
    required CloudSyncSelfRevocationRequest request,
  }) {
    _requireExactKeys(json, _jsonKeys, '自撤销请求结果');
    if (_requireString(json, 'result') != 'requested' ||
        _requireString(json, 'status') != 'pending') {
      throw const FormatException('自撤销请求结果状态无效');
    }
    final deviceId = _requireCanonicalUuid(
      _requireString(json, 'deviceId'),
      'deviceId',
    );
    final mutationId = _requireCanonicalUuid(
      _requireString(json, 'mutationId'),
      'mutationId',
    );
    final operationId = _requireCanonicalUuid(
      _requireString(json, 'operationId'),
      'operationId',
    );
    final expectedGeneration = _requireBoundedInt(
      _requireInt(json, 'expectedGeneration'),
      'expectedGeneration',
      maximum: 0x7ffffffe,
    );
    final expectedKeyEpoch = _requireBoundedInt(
      _requireInt(json, 'expectedKeyEpoch'),
      'expectedKeyEpoch',
      maximum: 0xfffffffe,
    );
    final expectedMembershipManifestDigest =
        CloudSyncMembershipManifestDigest.parse(
          _requireString(json, 'expectedMembershipManifestDigest'),
        );
    final intentDigest = _decodeCanonicalBinary(
      _requireString(json, 'intentDigest'),
      field: 'intentDigest',
      exactLength: cloudSyncSelfRevocationIntentDigestBytes,
    );
    final intentSignature = _decodeCanonicalBinary(
      _requireString(json, 'intentSignature'),
      field: 'intentSignature',
      exactLength: cloudSyncSelfRevocationIntentSignatureBytes,
    );
    final requestedAt = _requireCanonicalUtcDateTime(json, 'requestedAt');
    final expiresAt = _requireCanonicalUtcDateTime(json, 'expiresAt');
    final receiptExpiresAt = _requireCanonicalUtcDateTime(
      json,
      'receiptExpiresAt',
    );
    if (deviceId != request.deviceId ||
        mutationId != request.mutationId ||
        operationId != request.operationId ||
        expectedGeneration != request.expectedGeneration ||
        expectedKeyEpoch != request.expectedKeyEpoch ||
        expectedMembershipManifestDigest.encoded !=
            request.expectedMembershipManifestDigest.encoded ||
        !_sameBytes(intentDigest, request.intentDigest) ||
        !_sameBytes(intentSignature, request.intentSignature) ||
        expiresAt != request.expiresAt ||
        !requestedAt.isBefore(expiresAt) ||
        expiresAt.difference(requestedAt) >
            const Duration(hours: 24, minutes: 5) ||
        receiptExpiresAt.difference(requestedAt) != const Duration(days: 30)) {
      throw const FormatException('自撤销请求结果未绑定原始意图');
    }
    return CloudSyncSelfRevocationRequestResult._(
      request: request,
      requestedAt: requestedAt,
      receiptExpiresAt: receiptExpiresAt,
    );
  }

  const CloudSyncSelfRevocationRequestResult._({
    required this.request,
    required this.requestedAt,
    required this.receiptExpiresAt,
  });

  static const _jsonKeys = <String>{
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

  final CloudSyncSelfRevocationRequest request;
  final DateTime requestedAt;
  final DateTime receiptExpiresAt;

  String get deviceId => request.deviceId;
  String get mutationId => request.mutationId;
  String get operationId => request.operationId;
  int get expectedGeneration => request.expectedGeneration;
  int get expectedKeyEpoch => request.expectedKeyEpoch;
  CloudSyncMembershipManifestDigest get expectedMembershipManifestDigest =>
      request.expectedMembershipManifestDigest;
  DateTime get expiresAt => request.expiresAt;
  CloudSyncSelfRevocationContinuationToken get continuationToken =>
      request.continuationToken;
  Uint8List get intentDigest => request.intentDigest;
  Uint8List get intentSignature => request.intentSignature;
}

sealed class CloudSyncSelfRevocationStatus {
  const CloudSyncSelfRevocationStatus(this.request);

  factory CloudSyncSelfRevocationStatus.fromJson(
    CloudSyncJsonMap json, {
    required CloudSyncSelfRevocationRequestResult request,
  }) {
    final status = _requireString(json, 'status');
    return switch (status) {
      'pending' => () {
        _requireExactKeys(json, _pendingJsonKeys, '自撤销待处理状态');
        _validateSelfRevocationStatusBinding(json, request);
        return CloudSyncSelfRevocationPending._(request);
      }(),
      'cancelled' => () {
        _requireExactKeys(json, _cancelledJsonKeys, '自撤销已取消状态');
        _validateSelfRevocationStatusBinding(json, request);
        final cancelledAt = _requireCanonicalUtcDateTime(json, 'cancelledAt');
        if (cancelledAt.isBefore(request.requestedAt) ||
            !cancelledAt.isBefore(request.expiresAt)) {
          throw const FormatException('自撤销取消时间越界');
        }
        return CloudSyncSelfRevocationCancelled._(
          request,
          cancelledAt: cancelledAt,
        );
      }(),
      'confirmed' => () {
        _requireExactKeys(json, _confirmedJsonKeys, '自撤销已确认状态');
        _validateSelfRevocationStatusBinding(json, request);
        return CloudSyncUntrustedSelfRevocationConfirmed._(
          request,
          untrustedReceipt: CloudSyncUntrustedSelfRevocationReceipt.fromJson(
            copyCloudSyncJsonMap(json['receipt']),
            request: request,
          ),
        );
      }(),
      'expired' => () {
        _requireExactKeys(json, _terminalJsonKeys, '自撤销已过期状态');
        _validateSelfRevocationStatusBinding(json, request);
        return CloudSyncSelfRevocationExpired._(request);
      }(),
      'superseded' => () {
        _requireExactKeys(json, _terminalJsonKeys, '自撤销已取代状态');
        _validateSelfRevocationStatusBinding(json, request);
        return CloudSyncSelfRevocationSuperseded._(request);
      }(),
      _ => throw const FormatException('自撤销状态分支无效'),
    };
  }

  static const _pendingJsonKeys = <String>{
    'status',
    ..._selfRevocationStatusBindingJsonKeys,
  };
  static const _cancelledJsonKeys = <String>{
    'status',
    ..._selfRevocationStatusBindingJsonKeys,
    'cancelledAt',
  };
  static const _confirmedJsonKeys = <String>{
    'status',
    ..._selfRevocationStatusBindingJsonKeys,
    'receipt',
  };
  static const _terminalJsonKeys = <String>{
    'status',
    ..._selfRevocationStatusBindingJsonKeys,
  };

  final CloudSyncSelfRevocationRequestResult request;
}

final class CloudSyncSelfRevocationPending
    extends CloudSyncSelfRevocationStatus {
  const CloudSyncSelfRevocationPending._(super.request);
}

final class CloudSyncSelfRevocationCancelled
    extends CloudSyncSelfRevocationStatus {
  const CloudSyncSelfRevocationCancelled._(
    super.request, {
    required this.cancelledAt,
  });

  final DateTime cancelledAt;
}

final class CloudSyncUntrustedSelfRevocationConfirmed
    extends CloudSyncSelfRevocationStatus {
  const CloudSyncUntrustedSelfRevocationConfirmed._(
    super.request, {
    required this.untrustedReceipt,
  });

  final CloudSyncUntrustedSelfRevocationReceipt untrustedReceipt;
}

final class CloudSyncSelfRevocationExpired
    extends CloudSyncSelfRevocationStatus {
  const CloudSyncSelfRevocationExpired._(super.request);
}

final class CloudSyncSelfRevocationSuperseded
    extends CloudSyncSelfRevocationStatus {
  const CloudSyncSelfRevocationSuperseded._(super.request);
}

final class CloudSyncUntrustedSelfRevocationReceipt {
  factory CloudSyncUntrustedSelfRevocationReceipt.fromJson(
    CloudSyncJsonMap json, {
    required CloudSyncSelfRevocationRequestResult request,
  }) {
    _requireExactKeys(json, _jsonKeys, '自撤销终态回执');
    final rawSecurityStates = json['securityStates'];
    if (rawSecurityStates is! List<Object?> ||
        rawSecurityStates.isEmpty ||
        rawSecurityStates.length > 31) {
      throw const FormatException('自撤销终态回执安全状态数量无效');
    }
    final securityStates = rawSecurityStates
        .map(
          (value) => CloudSyncAccountSecurityHistoryItem.fromJson(
            copyCloudSyncJsonMap(value),
          ),
        )
        .toList(growable: false);
    final first = securityStates.first;
    if (first.generation != request.expectedGeneration + 1 ||
        first.keyEpoch != request.expectedKeyEpoch + 1 ||
        first.operationId != request.operationId) {
      throw const FormatException('自撤销轮换安全状态未绑定原始意图');
    }
    final operationIds = <String>{first.operationId};
    var previous = first;
    for (final state in securityStates.skip(1)) {
      if (state.generation != previous.generation + 1 ||
          state.keyEpoch != previous.keyEpoch ||
          !operationIds.add(state.operationId)) {
        throw const FormatException('自撤销恢复接续安全状态不连续');
      }
      previous = state;
    }
    final completion = CloudSyncDataRekeyCompletion.fromJson(
      copyCloudSyncJsonMap(json['completion']),
    );
    if (completion.operationId != request.operationId ||
        completion.issuerDeviceId == request.deviceId ||
        completion.sourceKeyEpoch != request.expectedKeyEpoch ||
        completion.targetKeyEpoch != previous.keyEpoch ||
        completion.membershipGeneration != previous.generation ||
        !_sameBytes(
          completion.membershipManifestDigest,
          previous.membershipManifestDigest.bytes,
        )) {
      throw const FormatException('自撤销完成证明未绑定最终安全状态');
    }
    // 这些时间戳不是成员清单签名链的一部分，传输层不能据此宣称回执可信。
    return CloudSyncUntrustedSelfRevocationReceipt._(
      securityStates: List<CloudSyncAccountSecurityHistoryItem>.unmodifiable(
        securityStates,
      ),
      completion: completion,
    );
  }

  const CloudSyncUntrustedSelfRevocationReceipt._({
    required this.securityStates,
    required this.completion,
  });

  static const _jsonKeys = <String>{'securityStates', 'completion'};

  final List<CloudSyncAccountSecurityHistoryItem> securityStates;
  final CloudSyncDataRekeyCompletion completion;
}

const _selfRevocationStatusBindingJsonKeys = <String>{
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

void _validateSelfRevocationStatusBinding(
  CloudSyncJsonMap json,
  CloudSyncSelfRevocationRequestResult request,
) {
  final expectedMembershipManifestDigest =
      CloudSyncMembershipManifestDigest.parse(
        _requireString(json, 'expectedMembershipManifestDigest'),
      );
  final intentDigest = _decodeCanonicalBinary(
    _requireString(json, 'intentDigest'),
    field: 'intentDigest',
    exactLength: cloudSyncSelfRevocationIntentDigestBytes,
  );
  final intentSignature = _decodeCanonicalBinary(
    _requireString(json, 'intentSignature'),
    field: 'intentSignature',
    exactLength: cloudSyncSelfRevocationIntentSignatureBytes,
  );
  if (_requireCanonicalUuid(_requireString(json, 'deviceId'), 'deviceId') !=
          request.deviceId ||
      _requireCanonicalUuid(_requireString(json, 'mutationId'), 'mutationId') !=
          request.mutationId ||
      _requireCanonicalUuid(
            _requireString(json, 'operationId'),
            'operationId',
          ) !=
          request.operationId ||
      _requireBoundedInt(
            _requireInt(json, 'expectedGeneration'),
            'expectedGeneration',
            maximum: 0x7ffffffe,
          ) !=
          request.expectedGeneration ||
      _requireBoundedInt(
            _requireInt(json, 'expectedKeyEpoch'),
            'expectedKeyEpoch',
            maximum: 0xfffffffe,
          ) !=
          request.expectedKeyEpoch ||
      expectedMembershipManifestDigest.encoded !=
          request.expectedMembershipManifestDigest.encoded ||
      !_sameBytes(intentDigest, request.intentDigest) ||
      !_sameBytes(intentSignature, request.intentSignature) ||
      _requireCanonicalUtcDateTime(json, 'requestedAt') !=
          request.requestedAt ||
      _requireCanonicalUtcDateTime(json, 'expiresAt') != request.expiresAt ||
      _requireCanonicalUtcDateTime(json, 'receiptExpiresAt') !=
          request.receiptExpiresAt) {
    throw const FormatException('自撤销状态未绑定原始请求');
  }
}

final class CloudSyncUntrustedPendingSelfRevocationRequest {
  factory CloudSyncUntrustedPendingSelfRevocationRequest.fromJson(
    CloudSyncJsonMap json,
  ) {
    _requireExactKeys(json, _jsonKeys, '待协调自撤销请求');
    final deviceName = _requireString(json, 'deviceName');
    if (deviceName.isEmpty || deviceName.length > 128) {
      throw const FormatException('自撤销设备名称长度无效');
    }
    final requestedAt = _requireCanonicalUtcDateTime(json, 'requestedAt');
    final expiresAt = _requireCanonicalUtcDateTime(json, 'expiresAt');
    if (!requestedAt.isBefore(expiresAt) ||
        expiresAt.difference(requestedAt) >
            const Duration(hours: 24, minutes: 5)) {
      throw const FormatException('待协调自撤销请求时间范围无效');
    }
    return CloudSyncUntrustedPendingSelfRevocationRequest._(
      deviceId: _requireCanonicalUuid(
        _requireString(json, 'deviceId'),
        'deviceId',
      ),
      deviceName: deviceName,
      mutationId: _requireCanonicalUuid(
        _requireString(json, 'mutationId'),
        'mutationId',
      ),
      operationId: _requireCanonicalUuid(
        _requireString(json, 'operationId'),
        'operationId',
      ),
      expectedGeneration: _requireBoundedInt(
        _requireInt(json, 'expectedGeneration'),
        'expectedGeneration',
        maximum: 0x7ffffffe,
      ),
      expectedKeyEpoch: _requireBoundedInt(
        _requireInt(json, 'expectedKeyEpoch'),
        'expectedKeyEpoch',
        maximum: 0xfffffffe,
      ),
      expectedMembershipManifestDigest: CloudSyncMembershipManifestDigest.parse(
        _requireString(json, 'expectedMembershipManifestDigest'),
      ),
      intentDigest: _copyFixedBytes(
        _decodeCanonicalBinary(
          _requireString(json, 'intentDigest'),
          field: 'intentDigest',
          exactLength: cloudSyncSelfRevocationIntentDigestBytes,
        ),
        cloudSyncSelfRevocationIntentDigestBytes,
        'intentDigest',
      ),
      intentSignature: _copyFixedBytes(
        _decodeCanonicalBinary(
          _requireString(json, 'intentSignature'),
          field: 'intentSignature',
          exactLength: cloudSyncSelfRevocationIntentSignatureBytes,
        ),
        cloudSyncSelfRevocationIntentSignatureBytes,
        'intentSignature',
      ),
      requestedAt: requestedAt,
      expiresAt: expiresAt,
    );
  }

  const CloudSyncUntrustedPendingSelfRevocationRequest._({
    required this.deviceId,
    required this.deviceName,
    required this.mutationId,
    required this.operationId,
    required this.expectedGeneration,
    required this.expectedKeyEpoch,
    required this.expectedMembershipManifestDigest,
    required this.intentDigest,
    required this.intentSignature,
    required this.requestedAt,
    required this.expiresAt,
  });

  static const _jsonKeys = <String>{
    'deviceId',
    'deviceName',
    'mutationId',
    'operationId',
    'expectedGeneration',
    'expectedKeyEpoch',
    'expectedMembershipManifestDigest',
    'intentDigest',
    'intentSignature',
    'requestedAt',
    'expiresAt',
  };

  final String deviceId;
  final String deviceName;
  final String mutationId;
  final String operationId;
  final int expectedGeneration;
  final int expectedKeyEpoch;
  final CloudSyncMembershipManifestDigest expectedMembershipManifestDigest;
  final Uint8List intentDigest;
  final Uint8List intentSignature;
  final DateTime requestedAt;
  final DateTime expiresAt;
}

final class CloudSyncUntrustedSelfRevocationRequestList {
  factory CloudSyncUntrustedSelfRevocationRequestList.fromJson(
    CloudSyncJsonMap json, {
    required DateTime now,
  }) {
    _requireExactKeys(json, _jsonKeys, '待协调自撤销请求列表');
    final rawRequests = json['requests'];
    if (rawRequests is! List<Object?> || rawRequests.length > 64) {
      throw const FormatException('待协调自撤销请求列表数量无效');
    }
    final requests = rawRequests
        .map(
          (value) => CloudSyncUntrustedPendingSelfRevocationRequest.fromJson(
            copyCloudSyncJsonMap(value),
          ),
        )
        .toList(growable: false);
    final deviceIds = <String>{};
    final mutationIds = <String>{};
    final operationIds = <String>{};
    final expectedHead = requests.firstOrNull;
    final currentTime = now.toUtc();
    CloudSyncUntrustedPendingSelfRevocationRequest? previous;
    for (final request in requests) {
      final prior = previous;
      if (!deviceIds.add(request.deviceId) ||
          !mutationIds.add(request.mutationId) ||
          !operationIds.add(request.operationId) ||
          !currentTime.isBefore(request.expiresAt) ||
          (prior != null &&
              (request.requestedAt.isBefore(prior.requestedAt) ||
                  (request.requestedAt == prior.requestedAt &&
                      request.deviceId.compareTo(prior.deviceId) <= 0))) ||
          (expectedHead != null &&
              (request.expectedGeneration != expectedHead.expectedGeneration ||
                  request.expectedKeyEpoch != expectedHead.expectedKeyEpoch ||
                  !_sameBytes(
                    request.expectedMembershipManifestDigest.bytes,
                    expectedHead.expectedMembershipManifestDigest.bytes,
                  )))) {
        throw const FormatException('待协调自撤销请求列表重复、顺序或安全头无效');
      }
      previous = request;
    }
    return CloudSyncUntrustedSelfRevocationRequestList._(
      List<CloudSyncUntrustedPendingSelfRevocationRequest>.unmodifiable(
        requests,
      ),
    );
  }

  const CloudSyncUntrustedSelfRevocationRequestList._(this.requests);

  static const _jsonKeys = <String>{'requests'};

  final List<CloudSyncUntrustedPendingSelfRevocationRequest> requests;
}

final class CloudSyncMembershipDeviceMaterial {
  CloudSyncMembershipDeviceMaterial({
    required String deviceId,
    required int keyVersion,
    required int authGeneration,
    required Uint8List signingPublicKey,
    required Uint8List keyAgreementPublicKey,
  }) : deviceId = _requireCanonicalUuid(deviceId, 'deviceId'),
       keyVersion = _requirePositiveInt32(keyVersion, 'keyVersion'),
       authGeneration = _requireNonNegativeInt32(
         authGeneration,
         'authGeneration',
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

  factory CloudSyncMembershipDeviceMaterial.fromJson(CloudSyncJsonMap json) {
    _requireExactKeys(json, _jsonKeys, '成员设备材料');
    return CloudSyncMembershipDeviceMaterial(
      deviceId: _requireString(json, 'deviceId'),
      keyVersion: _requireInt(json, 'keyVersion'),
      authGeneration: _requireInt(json, 'authGeneration'),
      signingPublicKey: _decodeCanonicalBinary(
        _requireString(json, 'signingPublicKey'),
        field: 'signingPublicKey',
        exactLength: cloudSyncDevicePublicKeyBytes,
      ),
      keyAgreementPublicKey: _decodeCanonicalBinary(
        _requireString(json, 'keyAgreementPublicKey'),
        field: 'keyAgreementPublicKey',
        exactLength: cloudSyncDevicePublicKeyBytes,
      ),
    );
  }

  static const _jsonKeys = <String>{
    'deviceId',
    'keyVersion',
    'authGeneration',
    'signingPublicKey',
    'keyAgreementPublicKey',
  };

  final String deviceId;
  final int keyVersion;
  final int authGeneration;
  final Uint8List signingPublicKey;
  final Uint8List keyAgreementPublicKey;

  CloudSyncJsonMap toJson() => <String, Object?>{
    'deviceId': deviceId,
    'keyVersion': keyVersion,
    'authGeneration': authGeneration,
    'signingPublicKey': _encodeCanonicalBinary(signingPublicKey),
    'keyAgreementPublicKey': _encodeCanonicalBinary(keyAgreementPublicKey),
  };
}

final class CloudSyncAccountSecurityEnvelope {
  CloudSyncAccountSecurityEnvelope({
    required String targetDeviceId,
    required String issuerDeviceId,
    required int envelopeVersion,
    required int keyEpoch,
    required Uint8List accountKeyEnvelope,
  }) : targetDeviceId = _requireCanonicalUuid(targetDeviceId, 'targetDeviceId'),
       issuerDeviceId = _requireCanonicalUuid(issuerDeviceId, 'issuerDeviceId'),
       envelopeVersion = _requireProtocolLiteral(
         envelopeVersion,
         'envelopeVersion',
       ),
       keyEpoch = _requirePositiveUint32(keyEpoch, 'keyEpoch'),
       accountKeyEnvelope = _copyFixedBytes(
         accountKeyEnvelope,
         cloudSyncAccountKeyEnvelopeBytes,
         'accountKeyEnvelope',
       );

  factory CloudSyncAccountSecurityEnvelope.fromJson(CloudSyncJsonMap json) {
    _requireExactKeys(json, _jsonKeys, '账户安全信封');
    return CloudSyncAccountSecurityEnvelope(
      targetDeviceId: _requireString(json, 'targetDeviceId'),
      issuerDeviceId: _requireString(json, 'issuerDeviceId'),
      envelopeVersion: _requireInt(json, 'envelopeVersion'),
      keyEpoch: _requireInt(json, 'keyEpoch'),
      accountKeyEnvelope: _decodeCanonicalBinary(
        _requireString(json, 'accountKeyEnvelope'),
        field: 'accountKeyEnvelope',
        exactLength: cloudSyncAccountKeyEnvelopeBytes,
      ),
    );
  }

  static const _jsonKeys = <String>{
    'targetDeviceId',
    'issuerDeviceId',
    'envelopeVersion',
    'keyEpoch',
    'accountKeyEnvelope',
  };

  final String targetDeviceId;
  final String issuerDeviceId;
  final int envelopeVersion;
  final int keyEpoch;
  final Uint8List accountKeyEnvelope;

  CloudSyncJsonMap toJson() => <String, Object?>{
    'targetDeviceId': targetDeviceId,
    'issuerDeviceId': issuerDeviceId,
    'envelopeVersion': envelopeVersion,
    'keyEpoch': keyEpoch,
    'accountKeyEnvelope': _encodeCanonicalBinary(accountKeyEnvelope),
  };
}

final class CloudSyncAccountSecurityState {
  factory CloudSyncAccountSecurityState({
    required int generation,
    required int keyEpoch,
    required CloudSyncDataRekeyPhase dataRekeyPhase,
    required Uint8List membershipManifest,
    required CloudSyncMembershipManifestDigest membershipManifestDigest,
    required int recoveryPublicKeyVersion,
    required Uint8List recoveryPublicKey,
    required int recoveryCapsuleVersion,
    required Uint8List recoveryCapsule,
    required String lastOperationId,
    required DateTime updatedAt,
    required List<CloudSyncAccountSecurityEnvelope> envelopes,
  }) {
    final manifest = _copyRangedBytes(
      membershipManifest,
      minimumLength: cloudSyncMembershipManifestMinimumBytes,
      maximumLength: cloudSyncMembershipManifestMaximumBytes,
      field: 'membershipManifest',
    );
    final actualDigest = Uint8List.fromList(sha256.convert(manifest).bytes);
    if (!_sameBytes(actualDigest, membershipManifestDigest.bytes)) {
      throw const FormatException('成员清单摘要与清单字节不一致');
    }
    final envelopeSnapshot = List<CloudSyncAccountSecurityEnvelope>.of(
      envelopes,
      growable: false,
    );
    if (envelopeSnapshot.isEmpty ||
        envelopeSnapshot.length >
            cloudSyncAccountSecurityEnvelopeMaximumCount) {
      throw const FormatException('账户安全信封数量无效');
    }
    final targetIds = <String>{};
    for (final envelope in envelopeSnapshot) {
      if (envelope.keyEpoch != keyEpoch ||
          !targetIds.add(envelope.targetDeviceId)) {
        throw const FormatException('账户安全信封身份或密钥代次无效');
      }
    }
    return CloudSyncAccountSecurityState._(
      _requirePositiveInt32(generation, 'generation'),
      _requirePositiveUint32(keyEpoch, 'keyEpoch'),
      dataRekeyPhase,
      manifest,
      membershipManifestDigest,
      _requirePositiveInt32(
        recoveryPublicKeyVersion,
        'recoveryPublicKeyVersion',
      ),
      _copyFixedBytes(
        recoveryPublicKey,
        cloudSyncRecoveryPublicKeyBytes,
        'recoveryPublicKey',
      ),
      _requirePositiveInt32(recoveryCapsuleVersion, 'recoveryCapsuleVersion'),
      _copyRangedBytes(
        recoveryCapsule,
        minimumLength: 1,
        maximumLength: cloudSyncRecoveryCapsuleMaximumBytes,
        field: 'recoveryCapsule',
      ),
      _requireCanonicalUuid(lastOperationId, 'lastOperationId'),
      updatedAt.toUtc(),
      List<CloudSyncAccountSecurityEnvelope>.unmodifiable(envelopeSnapshot),
    );
  }

  const CloudSyncAccountSecurityState._(
    this.generation,
    this.keyEpoch,
    this.dataRekeyPhase,
    this.membershipManifest,
    this.membershipManifestDigest,
    this.recoveryPublicKeyVersion,
    this.recoveryPublicKey,
    this.recoveryCapsuleVersion,
    this.recoveryCapsule,
    this.lastOperationId,
    this.updatedAt,
    this.envelopes,
  );

  factory CloudSyncAccountSecurityState.fromJson(CloudSyncJsonMap json) {
    _requireExactKeys(json, _jsonKeys, '账户安全状态');
    final rawEnvelopes = json['envelopes'];
    if (rawEnvelopes is! List<Object?>) {
      throw const FormatException('envelopes 必须为数组');
    }
    return CloudSyncAccountSecurityState(
      generation: _requireInt(json, 'generation'),
      keyEpoch: _requireInt(json, 'keyEpoch'),
      dataRekeyPhase: _parseDataRekeyPhase(
        _requireString(json, 'dataRekeyPhase'),
      ),
      membershipManifest: _decodeCanonicalBinary(
        _requireString(json, 'membershipManifest'),
        field: 'membershipManifest',
        minimumLength: cloudSyncMembershipManifestMinimumBytes,
        maximumLength: cloudSyncMembershipManifestMaximumBytes,
      ),
      membershipManifestDigest: CloudSyncMembershipManifestDigest.parse(
        _requireString(json, 'membershipManifestDigest'),
      ),
      recoveryPublicKeyVersion: _requireInt(json, 'recoveryPublicKeyVersion'),
      recoveryPublicKey: _decodeCanonicalBinary(
        _requireString(json, 'recoveryPublicKey'),
        field: 'recoveryPublicKey',
        exactLength: cloudSyncRecoveryPublicKeyBytes,
      ),
      recoveryCapsuleVersion: _requireInt(json, 'recoveryCapsuleVersion'),
      recoveryCapsule: _decodeCanonicalBinary(
        _requireString(json, 'recoveryCapsule'),
        field: 'recoveryCapsule',
        minimumLength: 1,
        maximumLength: cloudSyncRecoveryCapsuleMaximumBytes,
      ),
      lastOperationId: _requireString(json, 'lastOperationId'),
      updatedAt: _requireCanonicalUtcDateTime(json, 'updatedAt'),
      envelopes: rawEnvelopes
          .map(
            (value) => CloudSyncAccountSecurityEnvelope.fromJson(
              copyCloudSyncJsonMap(value),
            ),
          )
          .toList(growable: false),
    );
  }

  static const _jsonKeys = <String>{
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

  final int generation;
  final int keyEpoch;
  final CloudSyncDataRekeyPhase dataRekeyPhase;
  final Uint8List membershipManifest;
  final CloudSyncMembershipManifestDigest membershipManifestDigest;
  final int recoveryPublicKeyVersion;
  final Uint8List recoveryPublicKey;
  final int recoveryCapsuleVersion;
  final Uint8List recoveryCapsule;
  final String lastOperationId;
  final DateTime updatedAt;
  final List<CloudSyncAccountSecurityEnvelope> envelopes;

  CloudSyncJsonMap toJson() => <String, Object?>{
    'generation': generation,
    'keyEpoch': keyEpoch,
    'dataRekeyPhase': _dataRekeyPhaseWireName(dataRekeyPhase),
    'membershipManifest': _encodeCanonicalBinary(membershipManifest),
    'membershipManifestDigest': membershipManifestDigest.encoded,
    'recoveryPublicKeyVersion': recoveryPublicKeyVersion,
    'recoveryPublicKey': _encodeCanonicalBinary(recoveryPublicKey),
    'recoveryCapsuleVersion': recoveryCapsuleVersion,
    'recoveryCapsule': _encodeCanonicalBinary(recoveryCapsule),
    'lastOperationId': lastOperationId,
    'updatedAt': updatedAt.toIso8601String(),
    'envelopes': envelopes.map((value) => value.toJson()).toList(),
  };
}

final class CloudSyncAccountSecurityHistoryItem {
  factory CloudSyncAccountSecurityHistoryItem({
    required int generation,
    required int keyEpoch,
    required Uint8List membershipManifest,
    required CloudSyncMembershipManifestDigest membershipManifestDigest,
    required int recoveryPublicKeyVersion,
    required Uint8List recoveryPublicKey,
    required int recoveryCapsuleVersion,
    required Uint8List recoveryCapsule,
    required String operationId,
    required DateTime committedAt,
  }) {
    final manifest = _copyRangedBytes(
      membershipManifest,
      minimumLength: cloudSyncMembershipManifestMinimumBytes,
      maximumLength: cloudSyncMembershipManifestMaximumBytes,
      field: 'membershipManifest',
    );
    final actualDigest = Uint8List.fromList(sha256.convert(manifest).bytes);
    if (!_sameBytes(actualDigest, membershipManifestDigest.bytes)) {
      throw const FormatException('历史成员清单摘要与清单字节不一致');
    }
    return CloudSyncAccountSecurityHistoryItem._(
      generation: _requirePositiveInt32(generation, 'generation'),
      keyEpoch: _requirePositiveUint32(keyEpoch, 'keyEpoch'),
      membershipManifest: manifest,
      membershipManifestDigest: membershipManifestDigest,
      recoveryPublicKeyVersion: _requirePositiveInt32(
        recoveryPublicKeyVersion,
        'recoveryPublicKeyVersion',
      ),
      recoveryPublicKey: _copyFixedBytes(
        recoveryPublicKey,
        cloudSyncRecoveryPublicKeyBytes,
        'recoveryPublicKey',
      ),
      recoveryCapsuleVersion: _requirePositiveInt32(
        recoveryCapsuleVersion,
        'recoveryCapsuleVersion',
      ),
      recoveryCapsule: _copyRangedBytes(
        recoveryCapsule,
        minimumLength: 1,
        maximumLength: cloudSyncRecoveryCapsuleMaximumBytes,
        field: 'recoveryCapsule',
      ),
      operationId: _requireCanonicalUuid(operationId, 'operationId'),
      committedAt: committedAt.toUtc(),
    );
  }

  const CloudSyncAccountSecurityHistoryItem._({
    required this.generation,
    required this.keyEpoch,
    required this.membershipManifest,
    required this.membershipManifestDigest,
    required this.recoveryPublicKeyVersion,
    required this.recoveryPublicKey,
    required this.recoveryCapsuleVersion,
    required this.recoveryCapsule,
    required this.operationId,
    required this.committedAt,
  });

  factory CloudSyncAccountSecurityHistoryItem.fromJson(CloudSyncJsonMap json) {
    _requireExactKeys(json, _jsonKeys, '账户安全状态历史项');
    return CloudSyncAccountSecurityHistoryItem(
      generation: _requireInt(json, 'generation'),
      keyEpoch: _requireInt(json, 'keyEpoch'),
      membershipManifest: _decodeCanonicalBinary(
        _requireString(json, 'membershipManifest'),
        field: 'membershipManifest',
        minimumLength: cloudSyncMembershipManifestMinimumBytes,
        maximumLength: cloudSyncMembershipManifestMaximumBytes,
      ),
      membershipManifestDigest: CloudSyncMembershipManifestDigest.parse(
        _requireString(json, 'membershipManifestDigest'),
      ),
      recoveryPublicKeyVersion: _requireInt(json, 'recoveryPublicKeyVersion'),
      recoveryPublicKey: _decodeCanonicalBinary(
        _requireString(json, 'recoveryPublicKey'),
        field: 'recoveryPublicKey',
        exactLength: cloudSyncRecoveryPublicKeyBytes,
      ),
      recoveryCapsuleVersion: _requireInt(json, 'recoveryCapsuleVersion'),
      recoveryCapsule: _decodeCanonicalBinary(
        _requireString(json, 'recoveryCapsule'),
        field: 'recoveryCapsule',
        minimumLength: 1,
        maximumLength: cloudSyncRecoveryCapsuleMaximumBytes,
      ),
      operationId: _requireString(json, 'operationId'),
      committedAt: _requireCanonicalUtcDateTime(json, 'committedAt'),
    );
  }

  static const _jsonKeys = <String>{
    'generation',
    'keyEpoch',
    'membershipManifest',
    'membershipManifestDigest',
    'recoveryPublicKeyVersion',
    'recoveryPublicKey',
    'recoveryCapsuleVersion',
    'recoveryCapsule',
    'operationId',
    'committedAt',
  };

  final int generation;
  final int keyEpoch;
  final Uint8List membershipManifest;
  final CloudSyncMembershipManifestDigest membershipManifestDigest;
  final int recoveryPublicKeyVersion;
  final Uint8List recoveryPublicKey;
  final int recoveryCapsuleVersion;
  final Uint8List recoveryCapsule;
  final String operationId;
  final DateTime committedAt;
}

final class CloudSyncAccountSecurityCurrentProjection {
  CloudSyncAccountSecurityCurrentProjection({
    required int generation,
    required int keyEpoch,
    required this.dataRekeyPhase,
    required this.membershipManifestDigest,
    required int recoveryPublicKeyVersion,
    required Uint8List recoveryPublicKey,
    required int recoveryCapsuleVersion,
    required DateTime updatedAt,
  }) : generation = _requirePositiveInt32(generation, 'generation'),
       keyEpoch = _requirePositiveUint32(keyEpoch, 'keyEpoch'),
       recoveryPublicKeyVersion = _requirePositiveInt32(
         recoveryPublicKeyVersion,
         'recoveryPublicKeyVersion',
       ),
       recoveryPublicKey = _copyFixedBytes(
         recoveryPublicKey,
         cloudSyncRecoveryPublicKeyBytes,
         'recoveryPublicKey',
       ),
       recoveryCapsuleVersion = _requirePositiveInt32(
         recoveryCapsuleVersion,
         'recoveryCapsuleVersion',
       ),
       updatedAt = updatedAt.toUtc();

  factory CloudSyncAccountSecurityCurrentProjection.fromJson(
    CloudSyncJsonMap json,
  ) {
    _requireExactKeys(json, _jsonKeys, '账户安全状态当前投影');
    return CloudSyncAccountSecurityCurrentProjection(
      generation: _requireInt(json, 'generation'),
      keyEpoch: _requireInt(json, 'keyEpoch'),
      dataRekeyPhase: _parseDataRekeyPhase(
        _requireString(json, 'dataRekeyPhase'),
      ),
      membershipManifestDigest: CloudSyncMembershipManifestDigest.parse(
        _requireString(json, 'membershipManifestDigest'),
      ),
      recoveryPublicKeyVersion: _requireInt(json, 'recoveryPublicKeyVersion'),
      recoveryPublicKey: _decodeCanonicalBinary(
        _requireString(json, 'recoveryPublicKey'),
        field: 'recoveryPublicKey',
        exactLength: cloudSyncRecoveryPublicKeyBytes,
      ),
      recoveryCapsuleVersion: _requireInt(json, 'recoveryCapsuleVersion'),
      updatedAt: _requireCanonicalUtcDateTime(json, 'updatedAt'),
    );
  }

  static const _jsonKeys = <String>{
    'generation',
    'keyEpoch',
    'dataRekeyPhase',
    'membershipManifestDigest',
    'recoveryPublicKeyVersion',
    'recoveryPublicKey',
    'recoveryCapsuleVersion',
    'updatedAt',
  };

  final int generation;
  final int keyEpoch;
  final CloudSyncDataRekeyPhase dataRekeyPhase;
  final CloudSyncMembershipManifestDigest membershipManifestDigest;
  final int recoveryPublicKeyVersion;
  final Uint8List recoveryPublicKey;
  final int recoveryCapsuleVersion;
  final DateTime updatedAt;
}

final class CloudSyncAccountSecurityHistoryPage {
  factory CloudSyncAccountSecurityHistoryPage({
    required List<CloudSyncAccountSecurityHistoryItem> items,
    required int afterGeneration,
    required int nextAfterGeneration,
    required int pageSize,
    required bool hasMore,
    required CloudSyncAccountSecurityCurrentProjection currentState,
  }) {
    final checkedAfterGeneration = _requireNonNegativeInt32(
      afterGeneration,
      'afterGeneration',
    );
    final checkedNextAfterGeneration = _requireNonNegativeInt32(
      nextAfterGeneration,
      'nextAfterGeneration',
    );
    final checkedPageSize = _requireBoundedInt(
      pageSize,
      'pageSize',
      maximum: 100,
    );
    final snapshot = List<CloudSyncAccountSecurityHistoryItem>.of(
      items,
      growable: false,
    );
    if (snapshot.length > checkedPageSize ||
        checkedAfterGeneration > currentState.generation) {
      throw const FormatException('安全状态历史分页边界无效');
    }
    var expectedGeneration = checkedAfterGeneration + 1;
    for (final item in snapshot) {
      if (item.generation != expectedGeneration ||
          item.generation > currentState.generation) {
        throw const FormatException('安全状态历史 generation 不连续');
      }
      expectedGeneration += 1;
    }
    final expectedNextAfterGeneration = snapshot.isEmpty
        ? checkedAfterGeneration
        : snapshot.last.generation;
    final expectedHasMore =
        expectedNextAfterGeneration < currentState.generation;
    if (checkedNextAfterGeneration != expectedNextAfterGeneration ||
        hasMore != expectedHasMore ||
        (snapshot.isEmpty && expectedHasMore)) {
      throw const FormatException('安全状态历史游标或剩余状态无效');
    }
    if (snapshot.isNotEmpty &&
        snapshot.last.generation == currentState.generation) {
      final latest = snapshot.last;
      if (latest.keyEpoch != currentState.keyEpoch ||
          !_sameBytes(
            latest.membershipManifestDigest.bytes,
            currentState.membershipManifestDigest.bytes,
          ) ||
          latest.recoveryPublicKeyVersion !=
              currentState.recoveryPublicKeyVersion ||
          !_sameBytes(
            latest.recoveryPublicKey,
            currentState.recoveryPublicKey,
          ) ||
          latest.recoveryCapsuleVersion !=
              currentState.recoveryCapsuleVersion) {
        throw const FormatException('安全状态历史末项与当前投影不一致');
      }
    }
    return CloudSyncAccountSecurityHistoryPage._(
      items: List<CloudSyncAccountSecurityHistoryItem>.unmodifiable(snapshot),
      afterGeneration: checkedAfterGeneration,
      nextAfterGeneration: checkedNextAfterGeneration,
      pageSize: checkedPageSize,
      hasMore: hasMore,
      currentState: currentState,
    );
  }

  const CloudSyncAccountSecurityHistoryPage._({
    required this.items,
    required this.afterGeneration,
    required this.nextAfterGeneration,
    required this.pageSize,
    required this.hasMore,
    required this.currentState,
  });

  factory CloudSyncAccountSecurityHistoryPage.fromJson(CloudSyncJsonMap json) {
    _requireExactKeys(json, _jsonKeys, '账户安全状态历史页');
    final rawItems = json['items'];
    if (rawItems is! List<Object?>) {
      throw const FormatException('items 必须为数组');
    }
    return CloudSyncAccountSecurityHistoryPage(
      items: rawItems
          .map(
            (value) => CloudSyncAccountSecurityHistoryItem.fromJson(
              copyCloudSyncJsonMap(value),
            ),
          )
          .toList(growable: false),
      afterGeneration: _requireInt(json, 'afterGeneration'),
      nextAfterGeneration: _requireInt(json, 'nextAfterGeneration'),
      pageSize: _requireInt(json, 'pageSize'),
      hasMore: _requireBool(json, 'hasMore'),
      currentState: CloudSyncAccountSecurityCurrentProjection.fromJson(
        copyCloudSyncJsonMap(json['currentState']),
      ),
    );
  }

  static const _jsonKeys = <String>{
    'items',
    'afterGeneration',
    'nextAfterGeneration',
    'pageSize',
    'hasMore',
    'currentState',
  };

  final List<CloudSyncAccountSecurityHistoryItem> items;
  final int afterGeneration;
  final int nextAfterGeneration;
  final int pageSize;
  final bool hasMore;
  final CloudSyncAccountSecurityCurrentProjection currentState;
}

final class CloudSyncDeviceRotationEnvelope {
  CloudSyncDeviceRotationEnvelope({
    required String targetDeviceId,
    required int envelopeVersion,
    required int keyEpoch,
    required Uint8List accountKeyEnvelope,
  }) : targetDeviceId = _requireCanonicalUuid(targetDeviceId, 'targetDeviceId'),
       envelopeVersion = _requireProtocolLiteral(
         envelopeVersion,
         'envelopeVersion',
       ),
       keyEpoch = _requirePositiveUint32(keyEpoch, 'keyEpoch'),
       accountKeyEnvelope = _copyFixedBytes(
         accountKeyEnvelope,
         cloudSyncAccountKeyEnvelopeBytes,
         'accountKeyEnvelope',
       );

  final String targetDeviceId;
  final int envelopeVersion;
  final int keyEpoch;
  final Uint8List accountKeyEnvelope;
}

// 恢复口令只保护离线恢复介质，服务端轮换协议仅承载不透明恢复胶囊。
final class CloudSyncDeviceRotationRequest {
  factory CloudSyncDeviceRotationRequest.direct({
    required int expectedGeneration,
    required int expectedKeyEpoch,
    required CloudSyncMembershipManifestDigest expectedMembershipManifestDigest,
    required String operationId,
    required String revokeDeviceId,
    required Uint8List nextMembershipManifest,
    required int nextRecoveryCapsuleVersion,
    required Uint8List nextRecoveryCapsule,
    required List<CloudSyncDeviceRotationEnvelope> envelopes,
  }) {
    return CloudSyncDeviceRotationRequest._validated(
      authorization: null,
      expectedGeneration: expectedGeneration,
      expectedKeyEpoch: expectedKeyEpoch,
      expectedMembershipManifestDigest: expectedMembershipManifestDigest,
      operationId: operationId,
      revokeDeviceId: revokeDeviceId,
      nextMembershipManifest: nextMembershipManifest,
      nextRecoveryCapsuleVersion: nextRecoveryCapsuleVersion,
      nextRecoveryCapsule: nextRecoveryCapsule,
      envelopes: envelopes,
    );
  }

  factory CloudSyncDeviceRotationRequest.selfRevocation({
    required E2eeSelfRevocationRotationBinding authorization,
    required int expectedGeneration,
    required int expectedKeyEpoch,
    required CloudSyncMembershipManifestDigest expectedMembershipManifestDigest,
    required String operationId,
    required String revokeDeviceId,
    required Uint8List nextMembershipManifest,
    required int nextRecoveryCapsuleVersion,
    required Uint8List nextRecoveryCapsule,
    required List<CloudSyncDeviceRotationEnvelope> envelopes,
  }) {
    return CloudSyncDeviceRotationRequest._validated(
      authorization: authorization,
      expectedGeneration: expectedGeneration,
      expectedKeyEpoch: expectedKeyEpoch,
      expectedMembershipManifestDigest: expectedMembershipManifestDigest,
      operationId: operationId,
      revokeDeviceId: revokeDeviceId,
      nextMembershipManifest: nextMembershipManifest,
      nextRecoveryCapsuleVersion: nextRecoveryCapsuleVersion,
      nextRecoveryCapsule: nextRecoveryCapsule,
      envelopes: envelopes,
    );
  }

  factory CloudSyncDeviceRotationRequest._validated({
    required E2eeSelfRevocationRotationBinding? authorization,
    required int expectedGeneration,
    required int expectedKeyEpoch,
    required CloudSyncMembershipManifestDigest expectedMembershipManifestDigest,
    required String operationId,
    required String revokeDeviceId,
    required Uint8List nextMembershipManifest,
    required int nextRecoveryCapsuleVersion,
    required Uint8List nextRecoveryCapsule,
    required List<CloudSyncDeviceRotationEnvelope> envelopes,
  }) {
    final checkedGeneration = _requireBoundedInt(
      expectedGeneration,
      'expectedGeneration',
      maximum: 0x7ffffffe,
    );
    final checkedKeyEpoch = _requireBoundedInt(
      expectedKeyEpoch,
      'expectedKeyEpoch',
      maximum: 0xfffffffe,
    );
    final checkedOperationId = _requireCanonicalUuid(
      operationId,
      'operationId',
    );
    final checkedRevokeDeviceId = _requireCanonicalUuid(
      revokeDeviceId,
      'revokeDeviceId',
    );
    final manifest = _copyRangedBytes(
      nextMembershipManifest,
      minimumLength: cloudSyncMembershipManifestMinimumBytes,
      maximumLength: cloudSyncMembershipManifestMaximumBytes,
      field: 'nextMembershipManifest',
    );
    final nextDigest = CloudSyncMembershipManifestDigest.fromBytes(
      Uint8List.fromList(sha256.convert(manifest).bytes),
    );
    if (_sameBytes(expectedMembershipManifestDigest.bytes, nextDigest.bytes)) {
      throw const FormatException('设备轮换必须更换成员清单');
    }
    final envelopeSnapshot = List<CloudSyncDeviceRotationEnvelope>.of(
      envelopes,
      growable: false,
    );
    if (envelopeSnapshot.isEmpty ||
        envelopeSnapshot.length >
            cloudSyncAccountSecurityEnvelopeMaximumCount) {
      throw const FormatException('设备轮换信封数量无效');
    }
    final nextKeyEpoch = checkedKeyEpoch + 1;
    String? previousTargetDeviceId;
    for (final envelope in envelopeSnapshot) {
      if (envelope.keyEpoch != nextKeyEpoch ||
          envelope.targetDeviceId == checkedRevokeDeviceId ||
          (previousTargetDeviceId != null &&
              previousTargetDeviceId.compareTo(envelope.targetDeviceId) >= 0)) {
        throw const FormatException('设备轮换信封身份、顺序或密钥代次无效');
      }
      previousTargetDeviceId = envelope.targetDeviceId;
    }
    if (authorization != null &&
        (authorization.operationId != checkedOperationId ||
            authorization.deviceId != checkedRevokeDeviceId ||
            authorization.expectedGeneration != checkedGeneration ||
            authorization.expectedKeyEpoch != checkedKeyEpoch ||
            !_sameBytes(
              authorization.expectedMembershipManifestDigest,
              expectedMembershipManifestDigest.bytes,
            ))) {
      throw const FormatException('自撤销轮换授权与安全头不匹配');
    }
    return CloudSyncDeviceRotationRequest._(
      authorization: authorization,
      expectedGeneration: checkedGeneration,
      expectedKeyEpoch: checkedKeyEpoch,
      expectedMembershipManifestDigest: expectedMembershipManifestDigest,
      operationId: checkedOperationId,
      revokeDeviceId: checkedRevokeDeviceId,
      nextMembershipManifest: manifest,
      nextMembershipManifestDigest: nextDigest,
      nextRecoveryCapsuleVersion: _requirePositiveInt32(
        nextRecoveryCapsuleVersion,
        'nextRecoveryCapsuleVersion',
      ),
      nextRecoveryCapsule: _copyRangedBytes(
        nextRecoveryCapsule,
        minimumLength: 1,
        maximumLength: cloudSyncRecoveryCapsuleMaximumBytes,
        field: 'nextRecoveryCapsule',
      ),
      envelopes: List<CloudSyncDeviceRotationEnvelope>.unmodifiable(
        envelopeSnapshot,
      ),
    );
  }

  const CloudSyncDeviceRotationRequest._({
    required this.authorization,
    required this.expectedGeneration,
    required this.expectedKeyEpoch,
    required this.expectedMembershipManifestDigest,
    required this.operationId,
    required this.revokeDeviceId,
    required this.nextMembershipManifest,
    required this.nextMembershipManifestDigest,
    required this.nextRecoveryCapsuleVersion,
    required this.nextRecoveryCapsule,
    required this.envelopes,
  });

  final E2eeSelfRevocationRotationBinding? authorization;
  final int expectedGeneration;
  final int expectedKeyEpoch;
  final CloudSyncMembershipManifestDigest expectedMembershipManifestDigest;
  final String operationId;
  final String revokeDeviceId;
  final Uint8List nextMembershipManifest;
  final CloudSyncMembershipManifestDigest nextMembershipManifestDigest;
  final int nextRecoveryCapsuleVersion;
  final Uint8List nextRecoveryCapsule;
  final List<CloudSyncDeviceRotationEnvelope> envelopes;
}

final class CloudSyncDeviceRotationResult {
  factory CloudSyncDeviceRotationResult.direct({
    required String operationId,
    required String revokedDeviceId,
    required int fromGeneration,
    required int generation,
    required int keyEpoch,
    required CloudSyncDataRekeyPhase dataRekeyPhase,
    required CloudSyncMembershipManifestDigest membershipManifestDigest,
    required DateTime committedAt,
  }) {
    return CloudSyncDeviceRotationResult._validated(
      authorization: null,
      operationId: operationId,
      revokedDeviceId: revokedDeviceId,
      fromGeneration: fromGeneration,
      generation: generation,
      keyEpoch: keyEpoch,
      dataRekeyPhase: dataRekeyPhase,
      membershipManifestDigest: membershipManifestDigest,
      committedAt: committedAt,
    );
  }

  factory CloudSyncDeviceRotationResult.selfRevocation({
    required E2eeSelfRevocationRotationBinding authorization,
    required String operationId,
    required String revokedDeviceId,
    required int fromGeneration,
    required int generation,
    required int keyEpoch,
    required CloudSyncDataRekeyPhase dataRekeyPhase,
    required CloudSyncMembershipManifestDigest membershipManifestDigest,
    required DateTime committedAt,
  }) {
    return CloudSyncDeviceRotationResult._validated(
      authorization: authorization,
      operationId: operationId,
      revokedDeviceId: revokedDeviceId,
      fromGeneration: fromGeneration,
      generation: generation,
      keyEpoch: keyEpoch,
      dataRekeyPhase: dataRekeyPhase,
      membershipManifestDigest: membershipManifestDigest,
      committedAt: committedAt,
    );
  }

  factory CloudSyncDeviceRotationResult._validated({
    required E2eeSelfRevocationRotationBinding? authorization,
    required String operationId,
    required String revokedDeviceId,
    required int fromGeneration,
    required int generation,
    required int keyEpoch,
    required CloudSyncDataRekeyPhase dataRekeyPhase,
    required CloudSyncMembershipManifestDigest membershipManifestDigest,
    required DateTime committedAt,
  }) {
    final checkedFromGeneration = _requirePositiveInt32(
      fromGeneration,
      'fromGeneration',
    );
    final checkedGeneration = _requirePositiveInt32(generation, 'generation');
    final checkedOperationId = _requireCanonicalUuid(
      operationId,
      'operationId',
    );
    final checkedRevokedDeviceId = _requireCanonicalUuid(
      revokedDeviceId,
      'revokedDeviceId',
    );
    final checkedKeyEpoch = _requirePositiveUint32(keyEpoch, 'keyEpoch');
    if (checkedGeneration != checkedFromGeneration + 1 ||
        dataRekeyPhase != CloudSyncDataRekeyPhase.rekeyPending) {
      throw const FormatException('设备轮换结果代次或重加密状态无效');
    }
    if (authorization != null &&
        (authorization.operationId != checkedOperationId ||
            authorization.deviceId != checkedRevokedDeviceId ||
            authorization.expectedGeneration != checkedFromGeneration ||
            authorization.expectedKeyEpoch + 1 != checkedKeyEpoch)) {
      throw const FormatException('设备轮换结果安全头未绑定自撤销意图');
    }
    return CloudSyncDeviceRotationResult._(
      authorization: authorization,
      operationId: checkedOperationId,
      revokedDeviceId: checkedRevokedDeviceId,
      fromGeneration: checkedFromGeneration,
      generation: checkedGeneration,
      keyEpoch: checkedKeyEpoch,
      dataRekeyPhase: dataRekeyPhase,
      membershipManifestDigest: membershipManifestDigest,
      committedAt: committedAt.toUtc(),
    );
  }

  const CloudSyncDeviceRotationResult._({
    required this.authorization,
    required this.operationId,
    required this.revokedDeviceId,
    required this.fromGeneration,
    required this.generation,
    required this.keyEpoch,
    required this.dataRekeyPhase,
    required this.membershipManifestDigest,
    required this.committedAt,
  });

  factory CloudSyncDeviceRotationResult.fromJson(
    CloudSyncJsonMap json, {
    required E2eeSelfRevocationRotationBinding? authorization,
  }) {
    _requireExactKeys(
      json,
      authorization == null ? _directJsonKeys : _selfRevocationJsonKeys,
      '设备轮换结果',
    );
    if (_requireString(json, 'result') != 'committed') {
      throw const FormatException('设备轮换结果枚举值无效');
    }
    if (authorization != null &&
        (_requireCanonicalUuid(
                  _requireString(json, 'selfRevocationMutationId'),
                  'selfRevocationMutationId',
                ) !=
                authorization.mutationId ||
            !_sameBytes(
              _decodeCanonicalBinary(
                _requireString(json, 'selfRevocationIntentDigest'),
                field: 'selfRevocationIntentDigest',
                exactLength: cloudSyncSelfRevocationIntentDigestBytes,
              ),
              authorization.intentDigest,
            ))) {
      throw const FormatException('设备轮换结果未绑定自撤销意图');
    }
    return CloudSyncDeviceRotationResult._validated(
      authorization: authorization,
      operationId: _requireString(json, 'operationId'),
      revokedDeviceId: _requireString(json, 'revokedDeviceId'),
      fromGeneration: _requireInt(json, 'fromGeneration'),
      generation: _requireInt(json, 'generation'),
      keyEpoch: _requireInt(json, 'keyEpoch'),
      dataRekeyPhase: _parseDataRekeyPhase(
        _requireString(json, 'dataRekeyPhase'),
      ),
      membershipManifestDigest: CloudSyncMembershipManifestDigest.parse(
        _requireString(json, 'membershipManifestDigest'),
      ),
      committedAt: _requireCanonicalUtcDateTime(json, 'committedAt'),
    );
  }

  static const _directJsonKeys = <String>{
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
  static const _selfRevocationJsonKeys = <String>{
    ..._directJsonKeys,
    'selfRevocationMutationId',
    'selfRevocationIntentDigest',
  };

  final E2eeSelfRevocationRotationBinding? authorization;
  final String operationId;
  final String revokedDeviceId;
  final int fromGeneration;
  final int generation;
  final int keyEpoch;
  final CloudSyncDataRekeyPhase dataRekeyPhase;
  final CloudSyncMembershipManifestDigest membershipManifestDigest;
  final DateTime committedAt;
}

final class CloudSyncGenesisSecurityState {
  factory CloudSyncGenesisSecurityState({
    required String operationId,
    required Uint8List membershipManifest,
    required CloudSyncMembershipManifestDigest membershipManifestDigest,
    required int recoveryPublicKeyVersion,
    required Uint8List recoveryPublicKey,
    required int recoveryCapsuleVersion,
    required Uint8List recoveryCapsule,
  }) {
    final manifest = _copyRangedBytes(
      membershipManifest,
      minimumLength: cloudSyncMembershipManifestMinimumBytes,
      maximumLength: cloudSyncMembershipManifestMaximumBytes,
      field: 'membershipManifest',
    );
    final actualDigest = Uint8List.fromList(sha256.convert(manifest).bytes);
    if (!_sameBytes(actualDigest, membershipManifestDigest.bytes)) {
      throw const FormatException('genesis 成员清单摘要不一致');
    }
    return CloudSyncGenesisSecurityState._(
      _requireCanonicalUuid(operationId, 'operationId'),
      manifest,
      membershipManifestDigest,
      _requirePositiveInt32(
        recoveryPublicKeyVersion,
        'recoveryPublicKeyVersion',
      ),
      _copyFixedBytes(
        recoveryPublicKey,
        cloudSyncRecoveryPublicKeyBytes,
        'recoveryPublicKey',
      ),
      _requirePositiveInt32(recoveryCapsuleVersion, 'recoveryCapsuleVersion'),
      _copyFixedBytes(
        recoveryCapsule,
        cloudSyncRecoveryCapsuleBytes,
        'recoveryCapsule',
      ),
    );
  }

  const CloudSyncGenesisSecurityState._(
    this.operationId,
    this.membershipManifest,
    this.membershipManifestDigest,
    this.recoveryPublicKeyVersion,
    this.recoveryPublicKey,
    this.recoveryCapsuleVersion,
    this.recoveryCapsule,
  );

  final String operationId;
  final Uint8List membershipManifest;
  final CloudSyncMembershipManifestDigest membershipManifestDigest;
  final int recoveryPublicKeyVersion;
  final Uint8List recoveryPublicKey;
  final int recoveryCapsuleVersion;
  final Uint8List recoveryCapsule;
}

final class CloudSyncDevicePairingConsumptionReceipt {
  CloudSyncDevicePairingConsumptionReceipt({
    required String pairingId,
    required String issuerDeviceId,
    required int keyEpoch,
    required int securityGeneration,
    required this.membershipManifestDigest,
  }) : pairingId = _requireCanonicalUuid(pairingId, 'pairingId'),
       issuerDeviceId = _requireCanonicalUuid(issuerDeviceId, 'issuerDeviceId'),
       keyEpoch = _requirePositiveUint32(keyEpoch, 'keyEpoch'),
       securityGeneration = _requirePositiveInt32(
         securityGeneration,
         'securityGeneration',
       );

  factory CloudSyncDevicePairingConsumptionReceipt.fromJson(
    CloudSyncJsonMap json,
  ) {
    _requireExactKeys(json, _jsonKeys, '配对消费回执');
    return CloudSyncDevicePairingConsumptionReceipt(
      pairingId: _requireString(json, 'pairingId'),
      issuerDeviceId: _requireString(json, 'issuerDeviceId'),
      keyEpoch: _requireInt(json, 'keyEpoch'),
      securityGeneration: _requireInt(json, 'securityGeneration'),
      membershipManifestDigest: CloudSyncMembershipManifestDigest.parse(
        _requireString(json, 'membershipManifestDigest'),
      ),
    );
  }

  static const _jsonKeys = <String>{
    'pairingId',
    'issuerDeviceId',
    'keyEpoch',
    'securityGeneration',
    'membershipManifestDigest',
  };

  final String pairingId;
  final String issuerDeviceId;
  final int keyEpoch;
  final int securityGeneration;
  final CloudSyncMembershipManifestDigest membershipManifestDigest;

  CloudSyncJsonMap toJson() => <String, Object?>{
    'pairingId': pairingId,
    'issuerDeviceId': issuerDeviceId,
    'keyEpoch': keyEpoch,
    'securityGeneration': securityGeneration,
    'membershipManifestDigest': membershipManifestDigest.encoded,
  };
}

final class CloudSyncSecurityBootstrap {
  factory CloudSyncSecurityBootstrap.firstRegistration({
    required CloudSyncAccountSecurityState state,
    required CloudSyncMembershipDeviceMaterial localMember,
  }) {
    if (state.generation != 1 ||
        state.keyEpoch != 1 ||
        localMember.authGeneration != 0) {
      throw const FormatException('首设备注册 bootstrap 状态无效');
    }
    return CloudSyncSecurityBootstrap._(
      CloudSyncSecurityBootstrapSource.firstRegistration,
      state,
      localMember,
      null,
      null,
    );
  }

  factory CloudSyncSecurityBootstrap.pairing({
    required CloudSyncAccountSecurityState state,
    required CloudSyncMembershipDeviceMaterial localMember,
    required CloudSyncMembershipDeviceMaterial issuerMember,
    required CloudSyncDevicePairingConsumptionReceipt receipt,
  }) {
    if (receipt.keyEpoch != state.keyEpoch ||
        receipt.securityGeneration != state.generation ||
        !_sameBytes(
          receipt.membershipManifestDigest.bytes,
          state.membershipManifestDigest.bytes,
        ) ||
        receipt.issuerDeviceId != issuerMember.deviceId ||
        localMember.deviceId == issuerMember.deviceId ||
        localMember.authGeneration == 0) {
      throw const FormatException('设备配对 bootstrap 回执无效');
    }
    return CloudSyncSecurityBootstrap._(
      CloudSyncSecurityBootstrapSource.pairing,
      state,
      localMember,
      issuerMember,
      receipt,
    );
  }

  const CloudSyncSecurityBootstrap._(
    this.source,
    this.state,
    this.localMember,
    this.issuerMember,
    this.pairingReceipt,
  );

  factory CloudSyncSecurityBootstrap.fromJson(CloudSyncJsonMap json) {
    _requireExactKeys(json, _jsonKeys, '安全 bootstrap');
    final source = _parseEnum(
      CloudSyncSecurityBootstrapSource.values,
      _requireString(json, 'source'),
      'source',
    );
    final state = CloudSyncAccountSecurityState.fromJson(
      copyCloudSyncJsonMap(json['state']),
    );
    final localMember = CloudSyncMembershipDeviceMaterial.fromJson(
      copyCloudSyncJsonMap(json['localMember']),
    );
    final issuerValue = json['issuerMember'];
    final receiptValue = json['pairingReceipt'];
    return switch (source) {
      CloudSyncSecurityBootstrapSource.firstRegistration =>
        issuerValue == null && receiptValue == null
            ? CloudSyncSecurityBootstrap.firstRegistration(
                state: state,
                localMember: localMember,
              )
            : throw const FormatException('首设备 bootstrap 不得包含配对回执'),
      CloudSyncSecurityBootstrapSource.pairing =>
        CloudSyncSecurityBootstrap.pairing(
          state: state,
          localMember: localMember,
          issuerMember: CloudSyncMembershipDeviceMaterial.fromJson(
            copyCloudSyncJsonMap(issuerValue),
          ),
          receipt: CloudSyncDevicePairingConsumptionReceipt.fromJson(
            copyCloudSyncJsonMap(receiptValue),
          ),
        ),
    };
  }

  static const _jsonKeys = <String>{
    'source',
    'state',
    'localMember',
    'issuerMember',
    'pairingReceipt',
  };

  final CloudSyncSecurityBootstrapSource source;
  final CloudSyncAccountSecurityState state;
  final CloudSyncMembershipDeviceMaterial localMember;
  final CloudSyncMembershipDeviceMaterial? issuerMember;
  final CloudSyncDevicePairingConsumptionReceipt? pairingReceipt;

  CloudSyncJsonMap toJson() => <String, Object?>{
    'source': source.name,
    'state': state.toJson(),
    'localMember': localMember.toJson(),
    'issuerMember': issuerMember?.toJson(),
    'pairingReceipt': pairingReceipt?.toJson(),
  };
}

// 该提交只承载账户信任模块的签名产物，传输层不具备替代签名验证的权限。
final class CloudSyncDevicePairingMembershipCommit {
  factory CloudSyncDevicePairingMembershipCommit({
    required int expectedSecurityGeneration,
    required CloudSyncMembershipManifestDigest expectedMembershipManifestDigest,
    required int nextMembershipManifestVersion,
    required Uint8List nextMembershipManifest,
  }) {
    final manifestCopy = _copyBoundedBytes(
      nextMembershipManifest,
      cloudSyncMembershipManifestMaximumBytes,
      'nextMembershipManifest',
    );
    return CloudSyncDevicePairingMembershipCommit._(
      expectedSecurityGeneration: _requireBoundedInt(
        expectedSecurityGeneration,
        'expectedSecurityGeneration',
        maximum: 0x7ffffffe,
      ),
      expectedMembershipManifestDigest: expectedMembershipManifestDigest,
      nextMembershipManifestVersion: _requirePositiveInt32(
        nextMembershipManifestVersion,
        'nextMembershipManifestVersion',
      ),
      nextMembershipManifest: manifestCopy,
      nextMembershipManifestDigest: CloudSyncMembershipManifestDigest.fromBytes(
        Uint8List.fromList(sha256.convert(manifestCopy).bytes),
      ),
    );
  }

  CloudSyncDevicePairingMembershipCommit._({
    required this.expectedSecurityGeneration,
    required this.expectedMembershipManifestDigest,
    required this.nextMembershipManifestVersion,
    required this.nextMembershipManifest,
    required this.nextMembershipManifestDigest,
  });

  final int expectedSecurityGeneration;
  final CloudSyncMembershipManifestDigest expectedMembershipManifestDigest;
  final int nextMembershipManifestVersion;
  final Uint8List nextMembershipManifest;
  final CloudSyncMembershipManifestDigest nextMembershipManifestDigest;
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
    required int authGeneration,
    required int sessionGeneration,
    required this.user,
    required this.device,
    int? deviceKeyVersion,
    this.securityState,
    this.pairingReceipt,
    this.securityBootstrap,
  }) : tokenExpiresAt = tokenExpiresAt.toUtc(),
       keyEpoch = _requirePositiveUint32(keyEpoch, 'keyEpoch'),
       authGeneration = _requireNonNegativeInt32(
         authGeneration,
         'authGeneration',
       ),
       sessionGeneration = _requirePositiveInt32(
         sessionGeneration,
         'sessionGeneration',
       ),
       deviceKeyVersion = deviceKeyVersion == null
           ? null
           : _requirePositiveInt32(deviceKeyVersion, 'deviceKeyVersion') {
    if (device.status != CloudSyncAuthenticatedDeviceStatus.active) {
      throw const FormatException('已认证会话的设备状态必须为 active');
    }
    final state = securityState;
    final receipt = pairingReceipt;
    if (state != null && state.keyEpoch != keyEpoch) {
      throw const FormatException('已认证会话与账户安全状态密钥代次不一致');
    }
    if (receipt != null &&
        (state == null ||
            receipt.keyEpoch != keyEpoch ||
            receipt.securityGeneration != state.generation ||
            !_sameBytes(
              receipt.membershipManifestDigest.bytes,
              state.membershipManifestDigest.bytes,
            ))) {
      throw const FormatException('已认证会话的配对消费回执无效');
    }
    final bootstrap = securityBootstrap;
    if (bootstrap != null &&
        (state == null || !identical(bootstrap.state, state))) {
      throw const FormatException('已认证会话 bootstrap 未绑定原始安全状态');
    }
  }

  final CloudSyncFullSessionToken token;
  final DateTime tokenExpiresAt;
  final int keyEpoch;
  final int authGeneration;
  final int sessionGeneration;
  final CloudSyncAuthenticatedUser user;
  final CloudSyncAuthenticatedDevice device;
  final int? deviceKeyVersion;
  final CloudSyncAccountSecurityState? securityState;
  final CloudSyncDevicePairingConsumptionReceipt? pairingReceipt;
  final CloudSyncSecurityBootstrap? securityBootstrap;

  CloudSyncAuthenticatedSession withVerifiedDeviceKeyVersion(
    int verifiedDeviceKeyVersion,
  ) {
    final checkedVersion = _requirePositiveInt32(
      verifiedDeviceKeyVersion,
      'verifiedDeviceKeyVersion',
    );
    final currentVersion = deviceKeyVersion;
    if (currentVersion != null && currentVersion != checkedVersion) {
      throw StateError('已认证会话的设备密钥版本与本地验证结果不匹配');
    }
    return CloudSyncAuthenticatedSession(
      token: token,
      tokenExpiresAt: tokenExpiresAt,
      keyEpoch: keyEpoch,
      authGeneration: authGeneration,
      sessionGeneration: sessionGeneration,
      user: user,
      device: device,
      deviceKeyVersion: checkedVersion,
      securityState: securityState,
      pairingReceipt: pairingReceipt,
      securityBootstrap: securityBootstrap,
    );
  }

  CloudSyncAuthenticatedSession withSecurityBootstrap(
    CloudSyncSecurityBootstrap bootstrap,
  ) {
    if (!identical(bootstrap.state, securityState)) {
      throw StateError('安全 bootstrap 与认证响应安全状态不一致');
    }
    return CloudSyncAuthenticatedSession(
      token: token,
      tokenExpiresAt: tokenExpiresAt,
      keyEpoch: keyEpoch,
      authGeneration: authGeneration,
      sessionGeneration: sessionGeneration,
      user: user,
      device: device,
      deviceKeyVersion: deviceKeyVersion,
      securityState: securityState,
      pairingReceipt: pairingReceipt,
      securityBootstrap: bootstrap,
    );
  }
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
    required int authGeneration,
  }) : onboardingTokenExpiresAt = onboardingTokenExpiresAt.toUtc(),
       authGeneration = _requireNonNegativeInt32(
         authGeneration,
         'device.authGeneration',
       ) {
    if (device.status != CloudSyncAuthenticatedDeviceStatus.pending) {
      throw const FormatException('待批准设备的状态必须为 pending');
    }
  }

  final CloudSyncOnboardingToken onboardingToken;
  final DateTime onboardingTokenExpiresAt;
  final CloudSyncAuthenticatedDevice device;
  final int authGeneration;
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
    required int issuerKeyVersion,
    required int issuerAuthGeneration,
    required Uint8List issuerSigningPublicKey,
    required Uint8List issuerKeyAgreementPublicKey,
    required int keyEpoch,
    required Uint8List accountKeyEnvelope,
    required Uint8List deviceProof,
    required Uint8List pairingAuthenticator,
  }) : issuerDeviceId = _requireCanonicalUuid(issuerDeviceId, 'issuerDeviceId'),
       issuerKeyVersion = _requirePositiveInt32(
         issuerKeyVersion,
         'issuerKeyVersion',
       ),
       issuerAuthGeneration = _requireNonNegativeInt32(
         issuerAuthGeneration,
         'issuerAuthGeneration',
       ),
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
  final int issuerKeyVersion;
  final int issuerAuthGeneration;
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
    'authGeneration',
    'sessionGeneration',
    'userId',
    'loginName',
    'displayName',
    'role',
    'attachmentQuotaBytes',
    'deviceId',
    'deviceName',
    'platform',
    'clientVersion',
    'deviceKeyVersion',
    'deviceCreatedAt',
    'securityBootstrap',
  };

  CloudSyncAccountSession({
    required String baseUrl,
    required this.token,
    required DateTime tokenExpiresAt,
    required int keyEpoch,
    required int authGeneration,
    required int sessionGeneration,
    required String userId,
    required String loginName,
    required String displayName,
    required this.role,
    required int attachmentQuotaBytes,
    required String deviceId,
    required String deviceName,
    required this.platform,
    required String clientVersion,
    required int deviceKeyVersion,
    required DateTime deviceCreatedAt,
    this.securityBootstrap,
  }) : baseUrl = normalizeCloudSyncBaseUrl(baseUrl),
       tokenExpiresAt = tokenExpiresAt.toUtc(),
       keyEpoch = _requirePositiveUint32(keyEpoch, 'keyEpoch'),
       authGeneration = _requireNonNegativeInt32(
         authGeneration,
         'authGeneration',
       ),
       sessionGeneration = _requirePositiveInt32(
         sessionGeneration,
         'sessionGeneration',
       ),
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
       deviceKeyVersion = _requirePositiveInt32(
         deviceKeyVersion,
         'deviceKeyVersion',
       ),
       deviceCreatedAt = deviceCreatedAt.toUtc() {
    final bootstrap = securityBootstrap;
    if (bootstrap != null &&
        (bootstrap.state.keyEpoch != keyEpoch ||
            bootstrap.localMember.deviceId != this.deviceId ||
            bootstrap.localMember.keyVersion != this.deviceKeyVersion ||
            bootstrap.localMember.authGeneration != this.authGeneration)) {
      throw const FormatException('账户会话 bootstrap 与本机身份不一致');
    }
  }

  factory CloudSyncAccountSession.fromAuthenticatedSession({
    required String baseUrl,
    required CloudSyncAuthenticatedSession session,
  }) {
    final user = session.user;
    final device = session.device;
    final deviceKeyVersion = session.deviceKeyVersion;
    if (deviceKeyVersion == null) {
      throw StateError('已认证会话尚未绑定本地设备密钥版本');
    }
    return CloudSyncAccountSession(
      baseUrl: baseUrl,
      token: session.token,
      tokenExpiresAt: session.tokenExpiresAt,
      keyEpoch: session.keyEpoch,
      authGeneration: session.authGeneration,
      sessionGeneration: session.sessionGeneration,
      userId: user.id,
      loginName: user.loginName,
      displayName: user.displayName,
      role: user.role,
      attachmentQuotaBytes: user.attachmentQuotaBytes,
      deviceId: device.id,
      deviceName: device.name,
      platform: device.platform,
      clientVersion: device.clientVersion,
      deviceKeyVersion: deviceKeyVersion,
      deviceCreatedAt: device.createdAt,
      securityBootstrap: session.securityBootstrap,
    );
  }

  CloudSyncAuthenticatedSession toAuthenticatedSession() {
    return CloudSyncAuthenticatedSession(
      token: token,
      tokenExpiresAt: tokenExpiresAt,
      keyEpoch: keyEpoch,
      authGeneration: authGeneration,
      sessionGeneration: sessionGeneration,
      user: CloudSyncAuthenticatedUser(
        id: userId,
        loginName: loginName,
        displayName: displayName,
        role: role,
        attachmentQuotaBytes: attachmentQuotaBytes,
      ),
      device: CloudSyncAuthenticatedDevice(
        id: deviceId,
        name: deviceName,
        platform: platform,
        clientVersion: clientVersion,
        status: CloudSyncAuthenticatedDeviceStatus.active,
        createdAt: deviceCreatedAt,
      ),
      deviceKeyVersion: deviceKeyVersion,
      securityState: securityBootstrap?.state,
      pairingReceipt: securityBootstrap?.pairingReceipt,
      securityBootstrap: securityBootstrap,
    );
  }

  final String baseUrl;
  final CloudSyncFullSessionToken token;
  final DateTime tokenExpiresAt;
  final int keyEpoch;
  final int authGeneration;
  final int sessionGeneration;
  final String userId;
  final String loginName;
  final String displayName;
  final CloudSyncUserRole role;
  final int attachmentQuotaBytes;
  final String deviceId;
  final String deviceName;
  final CloudSyncPlatform platform;
  final String clientVersion;
  final int deviceKeyVersion;
  final DateTime deviceCreatedAt;
  final CloudSyncSecurityBootstrap? securityBootstrap;

  String get accountScope =>
      cloudSyncAccountScope(canonicalBaseUrl: baseUrl, userId: userId);

  bool isExpiredAt(DateTime now) => !now.toUtc().isBefore(tokenExpiresAt);

  CloudSyncJsonMap toJson() => <String, Object?>{
    'version': 4,
    'baseUrl': baseUrl,
    'token': token.value,
    'tokenExpiresAt': tokenExpiresAt.toIso8601String(),
    'keyEpoch': keyEpoch,
    'authGeneration': authGeneration,
    'sessionGeneration': sessionGeneration,
    'userId': userId,
    'loginName': loginName,
    'displayName': displayName,
    'role': role.name,
    'attachmentQuotaBytes': attachmentQuotaBytes,
    'deviceId': deviceId,
    'deviceName': deviceName,
    'platform': platform.name,
    'clientVersion': clientVersion,
    'deviceKeyVersion': deviceKeyVersion,
    'deviceCreatedAt': deviceCreatedAt.toIso8601String(),
    'securityBootstrap': securityBootstrap?.toJson(),
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
      authGeneration: _requireInt(json, 'authGeneration'),
      sessionGeneration: _requireInt(json, 'sessionGeneration'),
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
      deviceKeyVersion: _requireInt(json, 'deviceKeyVersion'),
      deviceCreatedAt: _requireCanonicalUtcDateTime(json, 'deviceCreatedAt'),
      securityBootstrap: json['securityBootstrap'] == null
          ? null
          : CloudSyncSecurityBootstrap.fromJson(
              copyCloudSyncJsonMap(json['securityBootstrap']),
            ),
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

  CloudSyncAccountSession withoutSecurityBootstrap() {
    if (securityBootstrap == null) return this;
    return CloudSyncAccountSession(
      baseUrl: baseUrl,
      token: token,
      tokenExpiresAt: tokenExpiresAt,
      keyEpoch: keyEpoch,
      authGeneration: authGeneration,
      sessionGeneration: sessionGeneration,
      userId: userId,
      loginName: loginName,
      displayName: displayName,
      role: role,
      attachmentQuotaBytes: attachmentQuotaBytes,
      deviceId: deviceId,
      deviceName: deviceName,
      platform: platform,
      clientVersion: clientVersion,
      deviceKeyVersion: deviceKeyVersion,
      deviceCreatedAt: deviceCreatedAt,
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
final _canonicalBase64UrlPattern = RegExp(r'^[A-Za-z0-9_-]+$');
final _fullSessionTokenPattern = RegExp(r'^kelivo_[A-Za-z0-9_-]{43}$');
final _onboardingTokenPattern = RegExp(
  r'^kelivo_onboarding_[A-Za-z0-9_-]{43}$',
);
final _selfRevocationContinuationTokenPattern = RegExp(
  r'^kelivo_revocation_[A-Za-z0-9_-]{43}$',
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

int _requireBoundedInt(int value, String field, {required int maximum}) {
  if (value < 1 || value > maximum) {
    throw FormatException('$field 必须位于 1 到 $maximum');
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

Uint8List _copyBoundedBytes(Uint8List value, int maximumLength, String field) {
  if (value.isEmpty || value.length > maximumLength) {
    throw FormatException('$field 长度无效');
  }
  return Uint8List.fromList(value).asUnmodifiableView();
}

Uint8List _copyRangedBytes(
  Uint8List value, {
  required int minimumLength,
  required int maximumLength,
  required String field,
}) {
  if (value.length < minimumLength || value.length > maximumLength) {
    throw FormatException('$field 长度无效');
  }
  return Uint8List.fromList(value).asUnmodifiableView();
}

int _requireProtocolLiteral(int value, String field) {
  if (value != cloudSyncOpaqueProtocolVersion) {
    throw FormatException('$field 协议版本无效');
  }
  return value;
}

String _encodeCanonicalBinary(Uint8List value) {
  return base64Url.encode(value).replaceAll('=', '');
}

Uint8List _decodeCanonicalBinary(
  String value, {
  required String field,
  int? exactLength,
  int? minimumLength,
  int? maximumLength,
}) {
  if (value.isEmpty || !_canonicalBase64UrlPattern.hasMatch(value)) {
    throw FormatException('$field 不是规范 Base64URL');
  }
  try {
    final padding = '=' * ((4 - value.length % 4) % 4);
    final decoded = Uint8List.fromList(base64Url.decode('$value$padding'));
    if (_encodeCanonicalBinary(decoded) != value ||
        (exactLength != null && decoded.length != exactLength) ||
        (minimumLength != null && decoded.length < minimumLength) ||
        (maximumLength != null && decoded.length > maximumLength)) {
      throw FormatException('$field 编码长度无效');
    }
    return decoded;
  } on FormatException {
    throw FormatException('$field 不是规范 Base64URL');
  }
}

CloudSyncDataRekeyPhase _parseDataRekeyPhase(String value) {
  return switch (value) {
    'ready' => CloudSyncDataRekeyPhase.ready,
    'rekey-pending' => CloudSyncDataRekeyPhase.rekeyPending,
    _ => throw const FormatException('dataRekeyPhase 枚举值无效'),
  };
}

String _dataRekeyPhaseWireName(CloudSyncDataRekeyPhase value) {
  return switch (value) {
    CloudSyncDataRekeyPhase.ready => 'ready',
    CloudSyncDataRekeyPhase.rekeyPending => 'rekey-pending',
  };
}

bool _sameBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

void _requireAccountSessionVersion(CloudSyncJsonMap json) {
  final version = json['version'];
  if (version is! int || version != 4) {
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

bool _requireBool(CloudSyncJsonMap json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('$key 必须为布尔值');
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
