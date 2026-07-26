import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:uuid/uuid.dart';

import '../workspace/device_state_blob_store.dart';
import 'cloud_sync_client.dart';
import 'cloud_sync_pairing_qr_codec.dart';
import 'cloud_sync_types.dart';

part 'e2ee_device_pairing.dart';

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

  Future<void> confirmFirstDeviceRegistration({
    required String loginName,
    required CloudSyncAuthenticatedSession session,
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
  static const _registrationRecordDomain =
      'kelivo.e2ee.registration-transaction.record.v1';
  static const _registrationAssociatedDataDomain =
      'kelivo.e2ee.registration-transaction.aad.v1';
  static const _registrationRecordEpoch = 1;
  static const _registrationFrameVersion = 1;
  static const _registrationFrameHeaderLength = 96;
  static const _registrationUploadOffset = _registrationFrameHeaderLength;
  static const _registrationEnvelopeOffset =
      _registrationUploadOffset + cloudSyncOpaqueRegistrationUploadBytes;
  static const _registrationProofOffset =
      _registrationEnvelopeOffset + cloudSyncAccountKeyEnvelopeBytes;
  static const _registrationStateOffset =
      _registrationProofOffset + cloudSyncDeviceProofBytes;
  static const _registrationFrameLength =
      _registrationStateOffset + DeviceStateBlobStore.blobLength;
  static final Uint8List _registrationFrameMagic = Uint8List.fromList(
    ascii.encode('KELVRT01'),
  );
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
    Uint8List? accountKeyEnvelope;
    Uint8List? deviceProof;
    Uint8List? fullStateBlob;
    _OpenedPendingRegistration? pending;
    _PendingRegistrationTransaction? transaction;
    Object? primaryError;
    try {
      if (platform != CloudSyncPlatform.android &&
          platform != CloudSyncPlatform.ios) {
        throw UnsupportedError('首个可信设备只能在移动端注册');
      }
      final normalizedLoginName = _normalizeLoginName(loginName);
      context = await _openDeviceContext(normalizedLoginName);
      pending = await _readPendingRegistration(context, normalizedLoginName);
      if (pending != null) {
        transaction = pending.transaction;
        await _ensurePendingRegistrationState(
          context,
          normalizedLoginName: normalizedLoginName,
          transaction: transaction,
        );
        final session = await _finishPendingRegistration(transaction);
        _validateRegistrationSession(
          context,
          normalizedLoginName: normalizedLoginName,
          transaction: transaction,
          session: session,
        );
        return session;
      }
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
      accountKeyEnvelope = Uint8List.fromList(registrationBundle.envelope);
      deviceProof = Uint8List.fromList(registrationBundle.signature);

      fullStateBlob = Uint8List.fromList(
        await _secureCore.sealDeviceState(
          context.key,
          context.identity,
          deviceId: context.deviceId,
          keyVersion: context.keyVersion,
          ark: ark,
          account: KelivoDeviceStateAccountBinding(userId: userId, keyEpoch: 1),
        ),
      );
      transaction = _PendingRegistrationTransaction(
        attemptId: start.attemptId,
        userId: start.userId,
        accountBinding: start.accountBinding,
        deviceId: context.deviceIdText,
        keyVersion: context.keyVersion,
        keyEpoch: 1,
        attemptExpiresAt: start.expiresAt,
        registrationUpload: registrationUpload,
        accountKeyEnvelope: accountKeyEnvelope,
        deviceProof: deviceProof,
        fullStateBlob: fullStateBlob,
      );
      // 本地事务是注册提交点；服务端调用只能发生在唯一 ARK 与原样载荷均可恢复之后。
      await _persistPendingRegistration(
        context,
        normalizedLoginName: normalizedLoginName,
        transaction: transaction,
      );
      await _deviceStateStore.write(
        normalizedBaseUrl: _baseUrl,
        normalizedLoginName: normalizedLoginName,
        blob: fullStateBlob,
      );

      final session = await _finishPendingRegistration(transaction);
      _validateRegistrationSession(
        context,
        normalizedLoginName: normalizedLoginName,
        transaction: transaction,
        session: session,
      );
      return session;
    } catch (error, stackTrace) {
      final reportedError =
          transaction != null &&
              error is CloudSyncException &&
              _registrationRecoveryRequiresLogin(error, transaction)
          ? CloudSyncException(
              kind: CloudSyncFailureKind.unauthenticated,
              retryable: false,
              serverCode: 'SYNC_REGISTRATION_RECOVERY_LOGIN_REQUIRED',
              requestId: error.requestId,
              statusCode: error.statusCode,
            )
          : error;
      primaryError = reportedError;
      _clearAccountClientToken();
      Error.throwWithStackTrace(reportedError, stackTrace);
    } finally {
      final stateToCancel = opaqueStateActive ? opaqueStart : null;
      try {
        await _finishAuthentication(
          primaryError: primaryError,
          cleanup: () => _cleanupOperation(
            cancelOpaque: stateToCancel == null
                ? null
                : () =>
                      _secureCore.cancelOpaqueRegistration(stateToCancel.state),
            mutableSecrets: <Uint8List?>[
              password,
              passwordCopy,
              registrationUpload,
              accountKeyEnvelope,
              deviceProof,
              fullStateBlob,
            ],
            ark: ark,
            context: context,
          ),
        );
      } finally {
        if (pending != null) {
          pending.dispose();
        } else {
          transaction?.dispose();
        }
      }
    }
  }

  @override
  Future<void> confirmFirstDeviceRegistration({
    required String loginName,
    required CloudSyncAuthenticatedSession session,
  }) async {
    _beginExclusiveOperation();
    _DeviceContext? context;
    _OpenedPendingRegistration? pending;
    Object? primaryError;
    try {
      final normalizedLoginName = _normalizeLoginName(loginName);
      context = await _openDeviceContext(normalizedLoginName);
      pending = await _readPendingRegistration(context, normalizedLoginName);
      if (pending == null) return;
      await _ensurePendingRegistrationState(
        context,
        normalizedLoginName: normalizedLoginName,
        transaction: pending.transaction,
      );
      _validateRegistrationSession(
        context,
        normalizedLoginName: normalizedLoginName,
        transaction: pending.transaction,
        session: session,
      );
      await _deviceStateStore.deletePendingRegistrationEnvelope(
        normalizedBaseUrl: _baseUrl,
        normalizedLoginName: normalizedLoginName,
        expectedDigest: pending.envelopeDigest,
      );
    } catch (error) {
      primaryError = error;
      rethrow;
    } finally {
      try {
        pending?.dispose();
        await _closeHandles(context: context);
      } catch (error, stackTrace) {
        if (primaryError == null) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        _logSuppressedCleanupFailure(error, stackTrace);
      } finally {
        _authenticationInProgress = false;
      }
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
    Uint8List? deviceProof;
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
      deviceProof = Uint8List.fromList(
        await _secureCore.signDeviceLoginProof(
          context.identity,
          attemptId: _uuidBytes(start.attemptId),
          accountContextId: opaqueAccountBinding,
          deviceId: context.deviceId,
          expiresAtMs: start.expiresAt.millisecondsSinceEpoch,
          challenge: start.deviceChallenge,
          credentialFinalization: credentialFinalization,
        ),
      );
      final result = await _accountClient.finishOpaqueLogin(
        attemptId: start.attemptId,
        credentialFinalization: credentialFinalization,
        deviceProof: deviceProof,
      );
      final loginResult = switch (result) {
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
      if (loginResult is E2eeAccountLoginAuthenticated) {
        await _discardPendingRegistrationAfterAuthenticatedLogin(
          normalizedLoginName,
        );
      }
      return loginResult;
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
            deviceProof,
          ],
          context: context,
        ),
      );
    }
  }

  Future<CloudSyncAuthenticatedSession> _finishPendingRegistration(
    _PendingRegistrationTransaction transaction,
  ) {
    return _accountClient.finishOpaqueRegistration(
      attemptId: transaction.attemptId,
      registrationUpload: transaction.registrationUpload,
      accountKeyEnvelope: transaction.accountKeyEnvelope,
      deviceProof: transaction.deviceProof,
    );
  }

  Future<void> _persistPendingRegistration(
    _DeviceContext context, {
    required String normalizedLoginName,
    required _PendingRegistrationTransaction transaction,
  }) async {
    final frame = _encodePendingRegistration(transaction);
    final recordId = _registrationRecordId(normalizedLoginName);
    final associatedData = _registrationAssociatedData(normalizedLoginName);
    Uint8List? envelope;
    try {
      envelope = await _secureCore.sealRecord(
        context.key,
        recordId: recordId,
        epoch: _registrationRecordEpoch,
        associatedData: associatedData,
        plaintext: frame,
      );
      if (envelope.length >
          DeviceStateBlobStore.pendingRegistrationEnvelopeMaxLength) {
        throw const FormatException('注册事务密文超过持久化边界');
      }
      await _deviceStateStore.writePendingRegistrationEnvelope(
        normalizedBaseUrl: _baseUrl,
        normalizedLoginName: normalizedLoginName,
        envelope: envelope,
      );
    } finally {
      _clearBytes(frame);
      _clearBytes(recordId);
      _clearBytes(associatedData);
      _clearBytes(envelope);
    }
  }

  Future<_OpenedPendingRegistration?> _readPendingRegistration(
    _DeviceContext context,
    String normalizedLoginName,
  ) async {
    final envelope = await _deviceStateStore.readPendingRegistrationEnvelope(
      normalizedBaseUrl: _baseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    if (envelope == null) return null;
    final envelopeDigest = Uint8List.fromList(sha256.convert(envelope).bytes);
    final recordId = _registrationRecordId(normalizedLoginName);
    final associatedData = _registrationAssociatedData(normalizedLoginName);
    Uint8List? plaintext;
    try {
      plaintext = await _secureCore.openRecord(
        context.key,
        recordId: recordId,
        epoch: _registrationRecordEpoch,
        associatedData: associatedData,
        envelope: envelope,
      );
      final transaction = _decodePendingRegistration(plaintext);
      return _OpenedPendingRegistration(
        transaction: transaction,
        envelopeDigest: envelopeDigest,
      );
    } catch (_) {
      _clearBytes(envelopeDigest);
      rethrow;
    } finally {
      _clearBytes(envelope);
      _clearBytes(recordId);
      _clearBytes(associatedData);
      _clearBytes(plaintext);
    }
  }

  Future<void> _ensurePendingRegistrationState(
    _DeviceContext context, {
    required String normalizedLoginName,
    required _PendingRegistrationTransaction transaction,
  }) async {
    if (context.deviceIdText != transaction.deviceId ||
        context.keyVersion != transaction.keyVersion) {
      throw StateError('注册事务与当前设备身份不匹配');
    }
    await _validatePendingFullState(context, transaction);
    final account = context.account;
    if (account == null) {
      if (context.ark != null) {
        throw StateError('未绑定设备状态意外包含账户根密钥');
      }
      await _deviceStateStore.write(
        normalizedBaseUrl: _baseUrl,
        normalizedLoginName: normalizedLoginName,
        blob: transaction.fullStateBlob,
      );
      return;
    }
    if (context.ark == null ||
        _uuidString(account.userId) != transaction.userId ||
        account.keyEpoch != transaction.keyEpoch) {
      throw StateError('注册事务与已绑定设备状态不匹配');
    }
  }

  Future<void> _validatePendingFullState(
    _DeviceContext context,
    _PendingRegistrationTransaction transaction,
  ) async {
    KelivoOpenedDeviceState? opened;
    Object? primaryError;
    try {
      opened = await _secureCore.openDeviceState(
        context.key,
        stateBlob: transaction.fullStateBlob,
      );
      final account = opened.binding.account;
      if (opened.ark == null ||
          account == null ||
          _uuidString(opened.binding.deviceId) != transaction.deviceId ||
          opened.binding.keyVersion != transaction.keyVersion ||
          _uuidString(account.userId) != transaction.userId ||
          account.keyEpoch != transaction.keyEpoch) {
        throw StateError('注册事务内的完整设备状态绑定无效');
      }
      final currentKeys = await _secureCore.readDevicePublicKeys(
        context.identity,
      );
      final pendingKeys = await _secureCore.readDevicePublicKeys(
        opened.identity,
      );
      if (!_sameBytes(
            currentKeys.signingPublicKey,
            pendingKeys.signingPublicKey,
          ) ||
          !_sameBytes(
            currentKeys.keyAgreementPublicKey,
            pendingKeys.keyAgreementPublicKey,
          )) {
        throw StateError('注册事务内的设备身份已被替换');
      }
    } catch (error) {
      primaryError = error;
      rethrow;
    } finally {
      if (opened != null) {
        await _closeTemporaryOpenedState(opened, primaryError: primaryError);
      }
    }
  }

  Future<void> _closeTemporaryOpenedState(
    KelivoOpenedDeviceState opened, {
    required Object? primaryError,
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

    if (opened.ark != null) {
      await close(() => _secureCore.closeAccountRootKey(opened.ark!));
    }
    await close(() => _secureCore.closeDeviceIdentity(opened.identity));
    if (firstError != null && firstStackTrace != null) {
      if (primaryError == null) {
        Error.throwWithStackTrace(firstError!, firstStackTrace!);
      }
      _logSuppressedCleanupFailure(firstError!, firstStackTrace!);
    }
  }

  void _validateRegistrationSession(
    _DeviceContext context, {
    required String normalizedLoginName,
    required _PendingRegistrationTransaction transaction,
    required CloudSyncAuthenticatedSession session,
  }) {
    if (context.deviceIdText != transaction.deviceId ||
        context.keyVersion != transaction.keyVersion ||
        session.user.id != transaction.userId ||
        session.user.loginName != normalizedLoginName ||
        session.device.id != transaction.deviceId ||
        session.keyEpoch != transaction.keyEpoch) {
      throw StateError('注册结果与本地注册事务不匹配');
    }
    final account = context.account;
    if (account != null &&
        (_uuidString(account.userId) != transaction.userId ||
            account.keyEpoch != transaction.keyEpoch ||
            context.ark == null)) {
      throw StateError('注册结果与已绑定设备状态不匹配');
    }
  }

  Future<void> _discardPendingRegistrationAfterAuthenticatedLogin(
    String normalizedLoginName,
  ) async {
    Uint8List? envelope;
    Uint8List? digest;
    try {
      envelope = await _deviceStateStore.readPendingRegistrationEnvelope(
        normalizedBaseUrl: _baseUrl,
        normalizedLoginName: normalizedLoginName,
      );
      if (envelope == null) return;
      digest = Uint8List.fromList(sha256.convert(envelope).bytes);
      await _deviceStateStore.deletePendingRegistrationEnvelope(
        normalizedBaseUrl: _baseUrl,
        normalizedLoginName: normalizedLoginName,
        expectedDigest: digest,
      );
    } catch (error, stackTrace) {
      developer.log(
        '账户已认证，遗留注册事务将在后续登录重试清理',
        name: 'Kelivo.E2eeAccountAuthenticator',
        level: 900,
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _clearBytes(envelope);
      _clearBytes(digest);
    }
  }

  bool _registrationRecoveryRequiresLogin(
    CloudSyncException error,
    _PendingRegistrationTransaction transaction,
  ) {
    return error.serverCode == 'AUTH_REGISTRATION_FAILED' &&
        !DateTime.now().toUtc().isBefore(transaction.attemptExpiresAt);
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

  Uint8List _registrationRecordId(String normalizedLoginName) {
    final digest = sha256.convert(
      utf8.encode(
        '$_registrationRecordDomain\u0000$_baseUrl\u0000$normalizedLoginName',
      ),
    );
    return Uint8List.fromList(digest.bytes.sublist(0, 16));
  }

  Uint8List _registrationAssociatedData(String normalizedLoginName) {
    return Uint8List.fromList(
      utf8.encode(
        '$_registrationAssociatedDataDomain\u0000'
        '$_baseUrl\u0000$normalizedLoginName',
      ),
    );
  }

  static Uint8List _encodePendingRegistration(
    _PendingRegistrationTransaction transaction,
  ) {
    if (transaction.keyVersion <= 0 ||
        transaction.keyVersion > 0xffffffff ||
        transaction.keyEpoch != 1 ||
        transaction.attemptExpiresAt.millisecondsSinceEpoch <= 0) {
      throw const FormatException('注册事务元数据无效');
    }
    _requireFixedBytes(
      transaction.registrationUpload,
      cloudSyncOpaqueRegistrationUploadBytes,
      'registrationUpload',
    );
    _requireFixedBytes(
      transaction.accountKeyEnvelope,
      cloudSyncAccountKeyEnvelopeBytes,
      'accountKeyEnvelope',
    );
    _requireFixedBytes(
      transaction.deviceProof,
      cloudSyncDeviceProofBytes,
      'deviceProof',
    );
    _requireFixedBytes(
      transaction.fullStateBlob,
      DeviceStateBlobStore.blobLength,
      'fullStateBlob',
    );

    final frame = Uint8List(_registrationFrameLength);
    frame.setRange(0, _registrationFrameMagic.length, _registrationFrameMagic);
    final fields = ByteData.sublistView(frame);
    fields.setUint16(8, _registrationFrameVersion, Endian.big);
    fields.setUint16(10, 0, Endian.big);
    fields.setUint32(12, transaction.keyEpoch, Endian.big);
    fields.setUint32(16, transaction.keyVersion, Endian.big);
    fields.setUint32(20, 0, Endian.big);
    fields.setUint64(
      24,
      transaction.attemptExpiresAt.millisecondsSinceEpoch,
      Endian.big,
    );
    frame.setRange(32, 48, _uuidBytes(transaction.attemptId));
    frame.setRange(48, 64, _uuidBytes(transaction.userId));
    frame.setRange(64, 80, _uuidBytes(transaction.accountBinding));
    frame.setRange(80, 96, _uuidBytes(transaction.deviceId));
    frame.setRange(
      _registrationUploadOffset,
      _registrationEnvelopeOffset,
      transaction.registrationUpload,
    );
    frame.setRange(
      _registrationEnvelopeOffset,
      _registrationProofOffset,
      transaction.accountKeyEnvelope,
    );
    frame.setRange(
      _registrationProofOffset,
      _registrationStateOffset,
      transaction.deviceProof,
    );
    frame.setRange(
      _registrationStateOffset,
      _registrationFrameLength,
      transaction.fullStateBlob,
    );
    return frame;
  }

  static _PendingRegistrationTransaction _decodePendingRegistration(
    Uint8List frame,
  ) {
    if (frame.length != _registrationFrameLength ||
        !_startsWith(frame, _registrationFrameMagic)) {
      throw const FormatException('注册事务帧无效');
    }
    final fields = ByteData.sublistView(frame);
    final keyEpoch = fields.getUint32(12, Endian.big);
    final keyVersion = fields.getUint32(16, Endian.big);
    final expiresAtMs = fields.getUint64(24, Endian.big);
    if (fields.getUint16(8, Endian.big) != _registrationFrameVersion ||
        fields.getUint16(10, Endian.big) != 0 ||
        keyEpoch != 1 ||
        keyVersion <= 0 ||
        fields.getUint32(20, Endian.big) != 0 ||
        expiresAtMs <= 0) {
      throw const FormatException('注册事务帧元数据无效');
    }
    final attemptExpiresAt = _utcDateTimeFromMilliseconds(expiresAtMs);
    return _PendingRegistrationTransaction(
      attemptId: _canonicalUuidFromBytes(frame, 32),
      userId: _canonicalUuidFromBytes(frame, 48),
      accountBinding: _canonicalUuidFromBytes(frame, 64),
      deviceId: _canonicalUuidFromBytes(frame, 80),
      keyVersion: keyVersion,
      keyEpoch: keyEpoch,
      attemptExpiresAt: attemptExpiresAt,
      registrationUpload: Uint8List.fromList(
        frame.sublist(_registrationUploadOffset, _registrationEnvelopeOffset),
      ),
      accountKeyEnvelope: Uint8List.fromList(
        frame.sublist(_registrationEnvelopeOffset, _registrationProofOffset),
      ),
      deviceProof: Uint8List.fromList(
        frame.sublist(_registrationProofOffset, _registrationStateOffset),
      ),
      fullStateBlob: Uint8List.fromList(
        frame.sublist(_registrationStateOffset),
      ),
    );
  }

  static DateTime _utcDateTimeFromMilliseconds(int value) {
    try {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    } on RangeError {
      throw const FormatException('注册事务过期时间无效');
    }
  }

  static String _canonicalUuidFromBytes(Uint8List frame, int offset) {
    final value = _uuidString(
      Uint8List.fromList(frame.sublist(offset, offset + 16)),
    );
    _uuidBytes(value);
    return value;
  }

  static void _requireFixedBytes(
    Uint8List value,
    int expectedLength,
    String field,
  ) {
    if (value.length != expectedLength) {
      throw FormatException('注册事务字段长度无效：$field');
    }
  }

  static bool _startsWith(Uint8List value, Uint8List prefix) {
    if (value.length < prefix.length) return false;
    for (var index = 0; index < prefix.length; index++) {
      if (value[index] != prefix[index]) return false;
    }
    return true;
  }

  static bool _sameBytes(Uint8List left, Uint8List right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
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

  void _beginExclusiveOperation() {
    if (_authenticationInProgress) {
      throw const CloudSyncException(
        kind: CloudSyncFailureKind.conflict,
        retryable: false,
        serverCode: 'SYNC_AUTHENTICATION_IN_PROGRESS',
      );
    }
    _authenticationInProgress = true;
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

final class _PendingRegistrationTransaction {
  _PendingRegistrationTransaction({
    required this.attemptId,
    required this.userId,
    required this.accountBinding,
    required this.deviceId,
    required this.keyVersion,
    required this.keyEpoch,
    required DateTime attemptExpiresAt,
    required Uint8List registrationUpload,
    required Uint8List accountKeyEnvelope,
    required Uint8List deviceProof,
    required Uint8List fullStateBlob,
  }) : attemptExpiresAt = attemptExpiresAt.toUtc(),
       registrationUpload = Uint8List.fromList(registrationUpload),
       accountKeyEnvelope = Uint8List.fromList(accountKeyEnvelope),
       deviceProof = Uint8List.fromList(deviceProof),
       fullStateBlob = Uint8List.fromList(fullStateBlob);

  final String attemptId;
  final String userId;
  final String accountBinding;
  final String deviceId;
  final int keyVersion;
  final int keyEpoch;
  final DateTime attemptExpiresAt;
  final Uint8List registrationUpload;
  final Uint8List accountKeyEnvelope;
  final Uint8List deviceProof;
  final Uint8List fullStateBlob;
  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    registrationUpload.fillRange(0, registrationUpload.length, 0);
    accountKeyEnvelope.fillRange(0, accountKeyEnvelope.length, 0);
    deviceProof.fillRange(0, deviceProof.length, 0);
    fullStateBlob.fillRange(0, fullStateBlob.length, 0);
  }
}

final class _OpenedPendingRegistration {
  _OpenedPendingRegistration({
    required this.transaction,
    required this.envelopeDigest,
  });

  final _PendingRegistrationTransaction transaction;
  final Uint8List envelopeDigest;
  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    transaction.dispose();
    envelopeDigest.fillRange(0, envelopeDigest.length, 0);
  }
}
