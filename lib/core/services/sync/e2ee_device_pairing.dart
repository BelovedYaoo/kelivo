part of 'e2ee_account_authenticator.dart';

enum _E2eePendingPairingState { active, cancelling, cancelled }

final class E2eePendingDevicePairing {
  E2eePendingDevicePairing._({
    required this._owner,
    required this.loginName,
    required this.expiresAt,
    required this._onboardingToken,
    required this._pairingId,
    required this._pendingHandle,
    required this._qrPayload,
  });

  final E2eeAccountAuthenticator _owner;
  final String loginName;
  final DateTime expiresAt;
  final CloudSyncOnboardingToken _onboardingToken;
  final String _pairingId;
  KelivoPendingPairingHandle? _pendingHandle;
  CloudSyncDevicePairingQrPayload? _qrPayload;
  _E2eePendingPairingState _state = _E2eePendingPairingState.active;

  Uint8List takeQrFrame({required DateTime now}) {
    if (_state != _E2eePendingPairingState.active) {
      throw StateError('设备配对已经结束');
    }
    final payload = _qrPayload;
    if (payload == null) {
      throw StateError('设备配对二维码已经取出');
    }
    try {
      return CloudSyncDevicePairingQrCodec.encode(payload, now: now);
    } finally {
      payload.dispose();
      _qrPayload = null;
    }
  }

  void _beginCancel(E2eeAccountAuthenticator owner) {
    if (!identical(owner, _owner)) {
      throw StateError('设备配对不属于当前认证器');
    }
    if (_state != _E2eePendingPairingState.active) {
      throw StateError('设备配对已经结束');
    }
    _state = _E2eePendingPairingState.cancelling;
  }

  KelivoPendingPairingHandle? _finishCancel() {
    _state = _E2eePendingPairingState.cancelled;
    _qrPayload?.dispose();
    _qrPayload = null;
    final pending = _pendingHandle;
    _pendingHandle = null;
    return pending;
  }
}

extension E2eeDevicePairingAuthentication on E2eeAccountAuthenticator {
  Future<E2eePendingDevicePairing> startDevicePairing(
    E2eeAccountLoginApprovalRequired approvalRequired,
  ) async {
    _beginExclusiveOperation();
    _DeviceContext? context;
    KelivoPendingPairingStart? started;
    CloudSyncDevicePairingQrPayload? payload;
    Uint8List? pairingSecret;
    Object? primaryError;
    var pendingHandleTransferred = false;
    try {
      final now = DateTime.now().toUtc();
      if (!now.isBefore(approvalRequired.onboardingTokenExpiresAt)) {
        throw const CloudSyncException(
          kind: CloudSyncFailureKind.unauthenticated,
          retryable: false,
          serverCode: 'SYNC_ONBOARDING_TOKEN_EXPIRED',
        );
      }
      final normalizedLoginName = E2eeAccountAuthenticator._normalizeLoginName(
        approvalRequired.loginName,
      );
      context = await _openDeviceContext(normalizedLoginName);
      if (context.account != null ||
          context.ark != null ||
          approvalRequired.device.id != context.deviceIdText) {
        throw StateError('待配对登录与本地设备状态不匹配');
      }

      final publicKeys = await _secureCore.readDevicePublicKeys(
        context.identity,
      );
      started = await _secureCore.startPendingPairing(
        context.identity,
        targetDeviceId: context.deviceId,
        targetKeyVersion: context.keyVersion,
      );
      final pairingId = E2eeAccountAuthenticator._uuidString(started.pairingId);
      final created = await _accountClient.createDevicePairing(
        token: approvalRequired.onboardingToken,
        pairingId: pairingId,
        pairingSecretHash: started.pairingSecretHash,
      );
      final validatedAt = DateTime.now().toUtc();
      _validateCreatedPairing(
        approvalRequired: approvalRequired,
        context: context,
        publicKeys: publicKeys,
        pairingId: pairingId,
        created: created,
        now: validatedAt,
      );
      await _secureCore.bindPendingPairing(
        started.state,
        pairingId: started.pairingId,
        userId: E2eeAccountAuthenticator._uuidBytes(created.accountContextId),
        targetDeviceId: context.deviceId,
        targetKeyVersion: context.keyVersion,
        targetPublicKeys: publicKeys,
        expiresAtMs: created.expiresAt.millisecondsSinceEpoch,
        challenge: created.challenge,
        nowMs: validatedAt.millisecondsSinceEpoch,
      );
      pairingSecret = started.takePairingSecret();
      payload = CloudSyncDevicePairingQrPayload.fromCreatedPairing(
        created: created,
        pairingSecret: pairingSecret,
        now: validatedAt,
      );
      pairingSecret = null;
      final result = E2eePendingDevicePairing._(
        owner: this,
        loginName: normalizedLoginName,
        expiresAt: created.expiresAt,
        onboardingToken: approvalRequired.onboardingToken,
        pairingId: pairingId,
        pendingHandle: started.state,
        qrPayload: payload,
      );
      payload = null;
      pendingHandleTransferred = true;
      return result;
    } catch (error) {
      primaryError = error;
      rethrow;
    } finally {
      try {
        payload?.dispose();
        E2eeAccountAuthenticator._clearBytes(pairingSecret);
        if (!pendingHandleTransferred && started != null) {
          started.discardPairingSecret();
          await _secureCore.cancelPendingPairing(started.state);
        }
        await _closeHandles(context: context);
      } catch (error, stackTrace) {
        if (primaryError == null) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        E2eeAccountAuthenticator._logSuppressedCleanupFailure(
          error,
          stackTrace,
        );
      } finally {
        _authenticationInProgress = false;
      }
    }
  }

  Future<void> cancelDevicePairing(E2eePendingDevicePairing pairing) async {
    _beginExclusiveOperation();
    Object? primaryError;
    KelivoPendingPairingHandle? pending;
    var cancellationStarted = false;
    try {
      pairing._beginCancel(this);
      cancellationStarted = true;
      await _accountClient.cancelDevicePairing(
        token: pairing._onboardingToken,
        pairingId: pairing._pairingId,
      );
    } catch (error) {
      primaryError = error;
      rethrow;
    } finally {
      try {
        if (cancellationStarted) {
          pending = pairing._finishCancel();
          if (pending != null) {
            await _secureCore.cancelPendingPairing(pending);
          }
        }
      } catch (error, stackTrace) {
        if (primaryError == null) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        E2eeAccountAuthenticator._logSuppressedCleanupFailure(
          error,
          stackTrace,
        );
      } finally {
        _authenticationInProgress = false;
      }
    }
  }

  void _validateCreatedPairing({
    required E2eeAccountLoginApprovalRequired approvalRequired,
    required _DeviceContext context,
    required KelivoDevicePublicKeys publicKeys,
    required String pairingId,
    required CloudSyncDevicePairingCreated created,
    required DateTime now,
  }) {
    final target = created.targetDevice;
    if (created.pairingId != pairingId ||
        !now.isBefore(created.expiresAt) ||
        created.expiresAt.isAfter(approvalRequired.onboardingTokenExpiresAt) ||
        target.id != context.deviceIdText ||
        target.id != approvalRequired.device.id ||
        target.name != approvalRequired.device.name ||
        target.platform != approvalRequired.device.platform ||
        target.clientVersion != approvalRequired.device.clientVersion ||
        target.keyVersion != context.keyVersion ||
        !E2eeAccountAuthenticator._sameBytes(
          target.signingPublicKey,
          publicKeys.signingPublicKey,
        ) ||
        !E2eeAccountAuthenticator._sameBytes(
          target.keyAgreementPublicKey,
          publicKeys.keyAgreementPublicKey,
        )) {
      throw StateError('服务端配对回显与本地设备身份不匹配');
    }
  }
}
