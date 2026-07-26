import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:uuid/uuid.dart';

import '../workspace/device_state_blob_store.dart';
import 'cloud_sync_client.dart';
import 'cloud_sync_types.dart';

sealed class E2eeAccountLoginResult {
  const E2eeAccountLoginResult();
}

final class E2eeAccountLoginAuthenticated extends E2eeAccountLoginResult {
  const E2eeAccountLoginAuthenticated(this.session);

  final CloudSyncAuthenticatedSession session;
}

final class E2eeAccountLoginApprovalRequired extends E2eeAccountLoginResult {
  E2eeAccountLoginApprovalRequired({
    required this.onboardingToken,
    required DateTime onboardingTokenExpiresAt,
    required this.loginName,
    required this.device,
  }) : onboardingTokenExpiresAt = onboardingTokenExpiresAt.toUtc();

  final CloudSyncOnboardingToken onboardingToken;
  final DateTime onboardingTokenExpiresAt;
  final String loginName;
  final CloudSyncAuthenticatedDevice device;
}

abstract interface class E2eeAccountAuthentication {
  /// 为避免密码在调用方继续驻留，所有退出路径都会清零传入缓冲区。
  Future<CloudSyncAuthenticatedSession> registerFirstDevice({
    required String loginName,
    required String displayName,
    required Uint8List password,
    required String deviceName,
    required CloudSyncPlatform platform,
    required String clientVersion,
  });

  /// 为避免密码在调用方继续驻留，所有退出路径都会清零传入缓冲区。
  Future<E2eeAccountLoginResult> loginDevice({
    required String loginName,
    required Uint8List password,
    required String deviceName,
    required CloudSyncPlatform platform,
    required String clientVersion,
  });
}

final class E2eeAccountAuthenticator implements E2eeAccountAuthentication {
  factory E2eeAccountAuthenticator({
    required String baseUrl,
    required CloudSyncAccountClient accountClient,
    required DeviceStateBlobStore deviceStateStore,
    required KelivoSecureCore secureCore,
  }) {
    return E2eeAccountAuthenticator._(
      normalizeCloudSyncBaseUrl(baseUrl),
      accountClient,
      deviceStateStore,
      secureCore,
    );
  }

  E2eeAccountAuthenticator._(
    this._baseUrl,
    this._accountClient,
    this._deviceStateStore,
    this._secureCore,
  );

  static const _deviceStateSlotDomain = 'kelivo.e2ee.device-state.slot.v1';
  static final RegExp _normalizedLoginNamePattern = RegExp(
    r'^[a-z0-9][a-z0-9._-]*$',
  );
  static final RegExp _canonicalUuidV4Pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  final String _baseUrl;
  final CloudSyncAccountClient _accountClient;
  final DeviceStateBlobStore _deviceStateStore;
  final KelivoSecureCore _secureCore;
  bool _authenticationInProgress = false;

  @override
  Future<CloudSyncAuthenticatedSession> registerFirstDevice({
    required String loginName,
    required String displayName,
    required Uint8List password,
    required String deviceName,
    required CloudSyncPlatform platform,
    required String clientVersion,
  }) async {
    final passwordCopy = _beginAuthentication(password);
    _DeviceContext? context;
    KelivoOpaqueRegistrationStart? opaqueStart;
    var opaqueStateActive = false;
    KelivoAccountRootKeyHandle? ark;
    Uint8List? registrationUpload;
    Object? primaryError;
    try {
      if (platform != CloudSyncPlatform.android &&
          platform != CloudSyncPlatform.ios) {
        throw UnsupportedError('首个可信设备只能在移动端注册');
      }
      final normalizedLoginName = _normalizeLoginName(loginName);
      context = await _openDeviceContext(normalizedLoginName);
      if (context.account != null || context.ark != null) {
        throw StateError('已绑定账户的设备状态不能再次注册');
      }
      final device = await _deviceIdentity(
        context,
        deviceName: deviceName,
        platform: platform,
        clientVersion: clientVersion,
      );
      opaqueStart = await _secureCore.startOpaqueRegistration(passwordCopy);
      opaqueStateActive = true;
      final start = await _accountClient.startOpaqueRegistration(
        loginName: normalizedLoginName,
        displayName: displayName,
        device: device,
        registrationRequest: opaqueStart.request,
      );
      opaqueStateActive = false;
      registrationUpload = await _secureCore.finishOpaqueRegistration(
        opaqueStart.state,
        password: passwordCopy,
        response: start.registrationResponse,
        accountId: _uuidBytes(start.accountBinding),
      );
      ark = await _secureCore.generateAccountRootKey();
      final userId = _uuidBytes(start.userId);
      final registrationBundle = await _secureCore
          .createDeviceRegistrationFinish(
            context.identity,
            ark,
            userId: userId,
            deviceId: context.deviceId,
            keyEpoch: 1,
            attemptId: _uuidBytes(start.attemptId),
            accountContextId: _uuidBytes(start.accountBinding),
            expiresAtMs: start.expiresAt.millisecondsSinceEpoch,
            challenge: start.deviceChallenge,
            registrationUpload: registrationUpload,
          );

      final fullStateBlob = await _secureCore.sealDeviceState(
        context.key,
        context.identity,
        deviceId: context.deviceId,
        keyVersion: context.keyVersion,
        ark: ark,
        account: KelivoDeviceStateAccountBinding(userId: userId, keyEpoch: 1),
      );
      // 服务端完成注册后无法回滚，必须先确保唯一 ARK 已经在本机耐久化。
      await _deviceStateStore.write(
        normalizedBaseUrl: _baseUrl,
        normalizedLoginName: normalizedLoginName,
        blob: fullStateBlob,
      );

      final session = await _accountClient.finishOpaqueRegistration(
        attemptId: start.attemptId,
        registrationUpload: registrationUpload,
        accountKeyEnvelope: registrationBundle.envelope,
        deviceProof: registrationBundle.signature,
      );
      if (session.user.id != start.userId ||
          session.device.id != context.deviceIdText ||
          session.keyEpoch != 1) {
        throw StateError('注册结果与本地设备状态不匹配');
      }
      return session;
    } catch (error) {
      primaryError = error;
      _clearAccountClientToken();
      rethrow;
    } finally {
      final stateToCancel = opaqueStateActive ? opaqueStart : null;
      await _finishAuthentication(
        primaryError: primaryError,
        cleanup: () => _cleanupOperation(
          cancelOpaque: stateToCancel == null
              ? null
              : () => _secureCore.cancelOpaqueRegistration(stateToCancel.state),
          mutableSecrets: <Uint8List?>[
            password,
            passwordCopy,
            registrationUpload,
          ],
          ark: ark,
          context: context,
        ),
      );
    }
  }

  @override
  Future<E2eeAccountLoginResult> loginDevice({
    required String loginName,
    required Uint8List password,
    required String deviceName,
    required CloudSyncPlatform platform,
    required String clientVersion,
  }) async {
    final passwordCopy = _beginAuthentication(password);
    _DeviceContext? context;
    KelivoOpaqueLoginStart? opaqueStart;
    var opaqueStateActive = false;
    Uint8List? credentialFinalization;
    Object? primaryError;
    try {
      final normalizedLoginName = _normalizeLoginName(loginName);
      context = await _openDeviceContext(normalizedLoginName);
      final device = await _deviceIdentity(
        context,
        deviceName: deviceName,
        platform: platform,
        clientVersion: clientVersion,
      );
      opaqueStart = await _secureCore.startOpaqueLogin(passwordCopy);
      opaqueStateActive = true;
      final start = await _accountClient.startOpaqueLogin(
        loginName: normalizedLoginName,
        device: device,
        credentialRequest: opaqueStart.request,
      );
      final opaqueAccountBinding = _uuidBytes(start.accountBinding);

      opaqueStateActive = false;
      credentialFinalization = await _secureCore.finishOpaqueLogin(
        opaqueStart.state,
        password: passwordCopy,
        response: start.credentialResponse,
        accountId: opaqueAccountBinding,
      );
      final deviceProof = await _secureCore.signDeviceLoginProof(
        context.identity,
        attemptId: _uuidBytes(start.attemptId),
        accountContextId: opaqueAccountBinding,
        deviceId: context.deviceId,
        expiresAtMs: start.expiresAt.millisecondsSinceEpoch,
        challenge: start.deviceChallenge,
        credentialFinalization: credentialFinalization,
      );
      final result = await _accountClient.finishOpaqueLogin(
        attemptId: start.attemptId,
        credentialFinalization: credentialFinalization,
        deviceProof: deviceProof,
      );
      return switch (result) {
        CloudSyncOpaqueLoginAuthenticated(:final session) =>
          _authenticatedLoginResult(context, session),
        CloudSyncOpaqueLoginApprovalRequired(
          :final onboardingToken,
          :final onboardingTokenExpiresAt,
          :final device,
        ) =>
          _approvalRequiredLoginResult(
            context,
            onboardingToken: onboardingToken,
            onboardingTokenExpiresAt: onboardingTokenExpiresAt,
            loginName: normalizedLoginName,
            device: device,
          ),
      };
    } catch (error) {
      primaryError = error;
      _clearAccountClientToken();
      rethrow;
    } finally {
      final stateToCancel = opaqueStateActive ? opaqueStart : null;
      await _finishAuthentication(
        primaryError: primaryError,
        cleanup: () => _cleanupOperation(
          cancelOpaque: stateToCancel == null
              ? null
              : () => _secureCore.cancelOpaqueLogin(stateToCancel.state),
          mutableSecrets: <Uint8List?>[
            password,
            passwordCopy,
            credentialFinalization,
          ],
          context: context,
        ),
      );
    }
  }

  E2eeAccountLoginAuthenticated _authenticatedLoginResult(
    _DeviceContext context,
    CloudSyncAuthenticatedSession session,
  ) {
    final account = context.account;
    if (account == null ||
        context.ark == null ||
        session.user.id != _uuidString(account.userId) ||
        session.device.id != context.deviceIdText ||
        session.keyEpoch != account.keyEpoch) {
      throw StateError('已认证登录结果与本地设备状态不匹配');
    }
    return E2eeAccountLoginAuthenticated(session);
  }

  E2eeAccountLoginApprovalRequired _approvalRequiredLoginResult(
    _DeviceContext context, {
    required CloudSyncOnboardingToken onboardingToken,
    required DateTime onboardingTokenExpiresAt,
    required String loginName,
    required CloudSyncAuthenticatedDevice device,
  }) {
    if (context.account != null ||
        context.ark != null ||
        device.id != context.deviceIdText) {
      throw StateError('待批准登录结果与本地设备状态不匹配');
    }
    _accountClient.setToken(null);
    return E2eeAccountLoginApprovalRequired(
      onboardingToken: onboardingToken,
      onboardingTokenExpiresAt: onboardingTokenExpiresAt,
      loginName: loginName,
      device: device,
    );
  }

  Future<CloudSyncOpaqueDeviceIdentity> _deviceIdentity(
    _DeviceContext context, {
    required String deviceName,
    required CloudSyncPlatform platform,
    required String clientVersion,
  }) async {
    final publicKeys = await _secureCore.readDevicePublicKeys(context.identity);
    return CloudSyncOpaqueDeviceIdentity(
      deviceId: context.deviceIdText,
      deviceName: deviceName,
      platform: platform,
      clientVersion: clientVersion,
      deviceKeyVersion: context.keyVersion,
      signingPublicKey: publicKeys.signingPublicKey,
      keyAgreementPublicKey: publicKeys.keyAgreementPublicKey,
    );
  }

  Future<_DeviceContext> _openDeviceContext(String normalizedLoginName) async {
    final slotId = _deriveSlotId(normalizedLoginName);
    final blob = await _deviceStateStore.read(
      normalizedBaseUrl: _baseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    if (blob != null) {
      final key = await _secureCore.openSlot(slotId);
      try {
        final opened = await _secureCore.openDeviceState(key, stateBlob: blob);
        return _DeviceContext(
          key: key,
          identity: opened.identity,
          ark: opened.ark,
          deviceId: opened.binding.deviceId,
          keyVersion: opened.binding.keyVersion,
          account: opened.binding.account,
        );
      } catch (error, stackTrace) {
        await _runCleanupPreservingPrimary(<Future<void> Function()>[
          () => _secureCore.close(key),
        ]);
        Error.throwWithStackTrace(error, stackTrace);
      }
    }

    final key = await _openOrCreateSlot(slotId);
    KelivoDeviceIdentityHandle? identity;
    try {
      identity = await _secureCore.generateDeviceIdentity();
      final deviceId = _uuidBytes(const Uuid().v4());
      final stateBlob = await _secureCore.sealDeviceState(
        key,
        identity,
        deviceId: deviceId,
        keyVersion: 1,
      );
      await _deviceStateStore.write(
        normalizedBaseUrl: _baseUrl,
        normalizedLoginName: normalizedLoginName,
        blob: stateBlob,
      );
      return _DeviceContext(
        key: key,
        identity: identity,
        ark: null,
        deviceId: deviceId,
        keyVersion: 1,
        account: null,
      );
    } catch (error, stackTrace) {
      await _runCleanupPreservingPrimary(<Future<void> Function()>[
        if (identity != null) () => _secureCore.closeDeviceIdentity(identity!),
        () => _secureCore.close(key),
      ]);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<KelivoKeyHandle> _openOrCreateSlot(Uint8List slotId) async {
    try {
      return await _secureCore.createSlot(slotId);
    } on KelivoSecureCoreException catch (error) {
      if (error.status != KelivoSecureCoreStatus.slotAlreadyExists) rethrow;
      return _secureCore.openSlot(slotId);
    }
  }

  Uint8List _deriveSlotId(String normalizedLoginName) {
    final digest = sha256.convert(
      utf8.encode(
        '$_deviceStateSlotDomain\u0000$_baseUrl\u0000$normalizedLoginName',
      ),
    );
    return Uint8List.fromList(digest.bytes.sublist(0, 16));
  }

  static String _normalizeLoginName(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.length < 3 ||
        normalized.length > 64 ||
        !_normalizedLoginNamePattern.hasMatch(normalized)) {
      throw const CloudSyncException(
        kind: CloudSyncFailureKind.validation,
        retryable: false,
      );
    }
    return normalized;
  }

  static Uint8List _uuidBytes(String value) {
    if (!_canonicalUuidV4Pattern.hasMatch(value)) {
      throw const FormatException('设备认证标识必须为规范的小写 UUID v4');
    }
    final hex = value.replaceAll('-', '');
    return Uint8List.fromList(<int>[
      for (var offset = 0; offset < hex.length; offset += 2)
        int.parse(hex.substring(offset, offset + 2), radix: 16),
    ]);
  }

  static String _uuidString(Uint8List value) {
    if (value.length != 16) {
      throw const FormatException('设备认证标识必须为 16 字节');
    }
    final hex = value
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  static void _clearBytes(Uint8List? value) {
    if (value == null) return;
    value.fillRange(0, value.length, 0);
  }

  Uint8List _beginAuthentication(Uint8List password) {
    // 设备状态槽和账户客户端由实例共享，交错认证会破坏令牌与句柄归属。
    if (_authenticationInProgress) {
      _clearBytesPreservingFailure(password);
      throw const CloudSyncException(
        kind: CloudSyncFailureKind.conflict,
        retryable: false,
        serverCode: 'SYNC_AUTHENTICATION_IN_PROGRESS',
      );
    }
    _authenticationInProgress = true;
    try {
      return Uint8List.fromList(password);
    } catch (_) {
      _authenticationInProgress = false;
      _clearBytesPreservingFailure(password);
      rethrow;
    }
  }

  Future<void> _finishAuthentication({
    required Object? primaryError,
    required Future<void> Function() cleanup,
  }) async {
    try {
      await cleanup();
    } catch (error, stackTrace) {
      _clearAccountClientToken();
      if (primaryError == null) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      _logSuppressedCleanupFailure(error, stackTrace);
    } finally {
      _authenticationInProgress = false;
    }
  }

  void _clearAccountClientToken() {
    try {
      _accountClient.setToken(null);
    } catch (error, stackTrace) {
      _logSuppressedCleanupFailure(error, stackTrace);
    }
  }

  static void _clearBytesPreservingFailure(Uint8List value) {
    try {
      _clearBytes(value);
    } catch (error, stackTrace) {
      _logSuppressedCleanupFailure(error, stackTrace);
    }
  }

  static Future<void> _runCleanupPreservingPrimary(
    List<Future<void> Function()> actions,
  ) async {
    for (final action in actions) {
      try {
        await action();
      } catch (error, stackTrace) {
        _logSuppressedCleanupFailure(error, stackTrace);
      }
    }
  }

  static void _logSuppressedCleanupFailure(
    Object error,
    StackTrace stackTrace,
  ) {
    developer.log(
      'E2EE 认证资源清理失败',
      name: 'Kelivo.E2eeAccountAuthenticator',
      error: error,
      stackTrace: stackTrace,
    );
  }

  Future<void> _cleanupOperation({
    required Future<void> Function()? cancelOpaque,
    required List<Uint8List?> mutableSecrets,
    KelivoAccountRootKeyHandle? ark,
    _DeviceContext? context,
  }) async {
    Object? firstError;
    StackTrace? firstStackTrace;

    Future<void> capture(Future<void> Function() action) async {
      try {
        await action();
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    if (cancelOpaque != null) await capture(cancelOpaque);
    for (final secret in mutableSecrets) {
      try {
        _clearBytes(secret);
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    await capture(() => _closeHandles(ark: ark, context: context));
    if (firstError != null && firstStackTrace != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
  }

  Future<void> _closeHandles({
    KelivoAccountRootKeyHandle? ark,
    _DeviceContext? context,
  }) async {
    Object? firstError;
    StackTrace? firstStackTrace;

    Future<void> close(Future<void> Function() action) async {
      try {
        await action();
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    if (ark != null) {
      await close(() => _secureCore.closeAccountRootKey(ark));
    }
    if (context != null) {
      if (context.ark != null) {
        await close(() => _secureCore.closeAccountRootKey(context.ark!));
      }
      await close(() => _secureCore.closeDeviceIdentity(context.identity));
      await close(() => _secureCore.close(context.key));
    }
    if (firstError != null && firstStackTrace != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
  }
}

final class _DeviceContext {
  const _DeviceContext({
    required this.key,
    required this.identity,
    required this.ark,
    required this.deviceId,
    required this.keyVersion,
    required this.account,
  });

  final KelivoKeyHandle key;
  final KelivoDeviceIdentityHandle identity;
  final KelivoAccountRootKeyHandle? ark;
  final Uint8List deviceId;
  final int keyVersion;
  final KelivoDeviceStateAccountBinding? account;

  String get deviceIdText => E2eeAccountAuthenticator._uuidString(deviceId);
}
