part of 'e2ee_account_authenticator.dart';

const _pairingApprovalMaximumAttempts = 3;
const _pairingApprovalRetryDelay = Duration(milliseconds: 200);
const _pairingQueryInterval = Duration(seconds: 1);
const _pairingRecordDomain = 'kelivo.e2ee.pairing-transaction.record.v1';
const _pairingAssociatedDataDomain = 'kelivo.e2ee.pairing-transaction.aad.v1';
const _pairingRecordEpoch = 1;
const _pairingFrameVersion = 1;
const _pairingOnboardingTokenLength = 61;
const _pairingOnboardingTokenOffset = 96;
const _pairingOriginalStateOffset = 160;
const _pairingFullStateOffset =
    _pairingOriginalStateOffset + DeviceStateBlobStore.blobLength;
const _pairingFrameLength =
    _pairingFullStateOffset + DeviceStateBlobStore.blobLength;
final Uint8List _pairingFrameMagic = Uint8List.fromList(
  ascii.encode('KELVPT01'),
);

enum _E2eePendingPairingState {
  active,
  waiting,
  accepting,
  completed,
  cancelling,
  cancelled,
  failed,
}

final class E2eePendingDevicePairing {
  E2eePendingDevicePairing._({
    required this._owner,
    required this.loginName,
    required this.expiresAt,
    required this._onboardingToken,
    required this._pairingId,
    required this._pendingHandle,
    required this._qrPayload,
    required this._created,
    required this._onboardingTokenExpiresAt,
  });

  final E2eeAccountAuthenticator _owner;
  final String loginName;
  final DateTime expiresAt;
  final CloudSyncOnboardingToken _onboardingToken;
  final String _pairingId;
  KelivoPendingPairingHandle? _pendingHandle;
  CloudSyncDevicePairingQrPayload? _qrPayload;
  final CloudSyncDevicePairingCreated _created;
  final DateTime _onboardingTokenExpiresAt;
  _E2eePendingPairingState _state = _E2eePendingPairingState.active;

  Uint8List takeQrFrame({required DateTime now}) {
    if (_state != _E2eePendingPairingState.active &&
        _state != _E2eePendingPairingState.waiting) {
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

  void _beginWait(E2eeAccountAuthenticator owner) {
    if (!identical(owner, _owner)) {
      throw StateError('设备配对不属于当前认证器');
    }
    if (_state != _E2eePendingPairingState.active) {
      throw StateError('设备配对不能重复等待');
    }
    _state = _E2eePendingPairingState.waiting;
  }

  KelivoPendingPairingHandle _beginAccept() {
    if (_state != _E2eePendingPairingState.waiting) {
      throw StateError('设备配对不在等待批准状态');
    }
    final pending = _pendingHandle;
    if (pending == null) {
      throw StateError('设备配对句柄已经释放');
    }
    _state = _E2eePendingPairingState.accepting;
    _pendingHandle = null;
    return pending;
  }

  KelivoPendingPairingHandle? _finishCompletion({required bool succeeded}) {
    _state = succeeded
        ? _E2eePendingPairingState.completed
        : _E2eePendingPairingState.failed;
    _qrPayload?.dispose();
    _qrPayload = null;
    final pending = _pendingHandle;
    _pendingHandle = null;
    return pending;
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

Uint8List _encodePairingRecoveryTransaction(
  _PairingRecoveryTransaction transaction,
) {
  final tokenBytes = Uint8List.fromList(
    ascii.encode(transaction.onboardingToken.value),
  );
  try {
    if (transaction.keyVersion <= 0 ||
        transaction.keyVersion > 0xffffffff ||
        transaction.keyEpoch <= 0 ||
        transaction.keyEpoch > 0xffffffff ||
        tokenBytes.length != _pairingOnboardingTokenLength ||
        transaction.onboardingTokenExpiresAt.millisecondsSinceEpoch <= 0 ||
        transaction.pairingExpiresAt.millisecondsSinceEpoch <= 0 ||
        transaction.pairingExpiresAt.isAfter(
          transaction.onboardingTokenExpiresAt,
        ) ||
        transaction.originalStateBlob.length !=
            DeviceStateBlobStore.blobLength ||
        transaction.fullStateBlob.length != DeviceStateBlobStore.blobLength) {
      throw const FormatException('配对恢复事务元数据无效');
    }

    final frame = Uint8List(_pairingFrameLength);
    frame.setRange(0, _pairingFrameMagic.length, _pairingFrameMagic);
    final fields = ByteData.sublistView(frame);
    fields.setUint16(8, _pairingFrameVersion, Endian.big);
    fields.setUint16(10, 0, Endian.big);
    fields.setUint32(12, transaction.keyEpoch, Endian.big);
    fields.setUint32(16, transaction.keyVersion, Endian.big);
    fields.setUint32(20, 0, Endian.big);
    fields.setUint64(
      24,
      transaction.onboardingTokenExpiresAt.millisecondsSinceEpoch,
      Endian.big,
    );
    fields.setUint64(
      32,
      transaction.pairingExpiresAt.millisecondsSinceEpoch,
      Endian.big,
    );
    frame.setRange(
      40,
      56,
      E2eeAccountAuthenticator._uuidBytes(transaction.pairingId),
    );
    frame.setRange(
      56,
      72,
      E2eeAccountAuthenticator._uuidBytes(transaction.userId),
    );
    frame.setRange(
      72,
      88,
      E2eeAccountAuthenticator._uuidBytes(transaction.deviceId),
    );
    fields.setUint16(88, tokenBytes.length, Endian.big);
    frame.setRange(
      _pairingOnboardingTokenOffset,
      _pairingOnboardingTokenOffset + tokenBytes.length,
      tokenBytes,
    );
    frame.setRange(
      _pairingOriginalStateOffset,
      _pairingFullStateOffset,
      transaction.originalStateBlob,
    );
    frame.setRange(
      _pairingFullStateOffset,
      _pairingFrameLength,
      transaction.fullStateBlob,
    );
    return frame;
  } finally {
    tokenBytes.fillRange(0, tokenBytes.length, 0);
  }
}

_PairingRecoveryTransaction _decodePairingRecoveryTransaction(Uint8List frame) {
  if (frame.length != _pairingFrameLength ||
      !E2eeAccountAuthenticator._startsWith(frame, _pairingFrameMagic)) {
    throw const FormatException('配对恢复事务帧无效');
  }
  final fields = ByteData.sublistView(frame);
  final keyEpoch = fields.getUint32(12, Endian.big);
  final keyVersion = fields.getUint32(16, Endian.big);
  final onboardingExpiresAtMs = fields.getUint64(24, Endian.big);
  final pairingExpiresAtMs = fields.getUint64(32, Endian.big);
  final tokenLength = fields.getUint16(88, Endian.big);
  if (fields.getUint16(8, Endian.big) != _pairingFrameVersion ||
      fields.getUint16(10, Endian.big) != 0 ||
      keyEpoch <= 0 ||
      keyVersion <= 0 ||
      fields.getUint32(20, Endian.big) != 0 ||
      onboardingExpiresAtMs <= 0 ||
      pairingExpiresAtMs <= 0 ||
      tokenLength != _pairingOnboardingTokenLength ||
      !_allZero(frame, 90, _pairingOnboardingTokenOffset) ||
      !_allZero(
        frame,
        _pairingOnboardingTokenOffset + tokenLength,
        _pairingOriginalStateOffset,
      )) {
    throw const FormatException('配对恢复事务帧元数据无效');
  }
  final onboardingTokenExpiresAt = _pairingDateTimeFromMilliseconds(
    onboardingExpiresAtMs,
  );
  final pairingExpiresAt = _pairingDateTimeFromMilliseconds(pairingExpiresAtMs);
  if (pairingExpiresAt.isAfter(onboardingTokenExpiresAt)) {
    throw const FormatException('配对恢复事务期限顺序无效');
  }
  final token = ascii.decode(
    Uint8List.sublistView(
      frame,
      _pairingOnboardingTokenOffset,
      _pairingOnboardingTokenOffset + tokenLength,
    ),
    allowInvalid: false,
  );
  return _PairingRecoveryTransaction(
    pairingId: _pairingUuidFromFrame(frame, 40),
    userId: _pairingUuidFromFrame(frame, 56),
    deviceId: _pairingUuidFromFrame(frame, 72),
    keyVersion: keyVersion,
    keyEpoch: keyEpoch,
    onboardingToken: CloudSyncOnboardingToken.parse(token),
    onboardingTokenExpiresAt: onboardingTokenExpiresAt,
    pairingExpiresAt: pairingExpiresAt,
    originalStateBlob: Uint8List.fromList(
      frame.sublist(_pairingOriginalStateOffset, _pairingFullStateOffset),
    ),
    fullStateBlob: Uint8List.fromList(frame.sublist(_pairingFullStateOffset)),
  );
}

DateTime _pairingDateTimeFromMilliseconds(int value) {
  try {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  } on RangeError {
    throw const FormatException('配对恢复事务时间无效');
  }
}

String _pairingUuidFromFrame(Uint8List frame, int offset) {
  final value = E2eeAccountAuthenticator._uuidString(
    Uint8List.fromList(frame.sublist(offset, offset + 16)),
  );
  E2eeAccountAuthenticator._uuidBytes(value);
  return value;
}

bool _allZero(Uint8List value, int start, int end) {
  for (var index = start; index < end; index++) {
    if (value[index] != 0) return false;
  }
  return true;
}

final class _PairingRecoveryTransaction {
  _PairingRecoveryTransaction({
    required this.pairingId,
    required this.userId,
    required this.deviceId,
    required this.keyVersion,
    required this.keyEpoch,
    required this.onboardingToken,
    required DateTime onboardingTokenExpiresAt,
    required DateTime pairingExpiresAt,
    required Uint8List originalStateBlob,
    required Uint8List fullStateBlob,
  }) : onboardingTokenExpiresAt = onboardingTokenExpiresAt.toUtc(),
       pairingExpiresAt = pairingExpiresAt.toUtc(),
       originalStateBlob = Uint8List.fromList(originalStateBlob),
       fullStateBlob = Uint8List.fromList(fullStateBlob);

  final String pairingId;
  final String userId;
  final String deviceId;
  final int keyVersion;
  final int keyEpoch;
  final CloudSyncOnboardingToken onboardingToken;
  final DateTime onboardingTokenExpiresAt;
  final DateTime pairingExpiresAt;
  final Uint8List originalStateBlob;
  final Uint8List fullStateBlob;
  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    originalStateBlob.fillRange(0, originalStateBlob.length, 0);
    fullStateBlob.fillRange(0, fullStateBlob.length, 0);
  }
}

final class _OpenedPendingPairing {
  _OpenedPendingPairing({
    required this.transaction,
    required this.envelopeDigest,
  });

  final _PairingRecoveryTransaction transaction;
  final Uint8List envelopeDigest;
  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    transaction.dispose();
    envelopeDigest.fillRange(0, envelopeDigest.length, 0);
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
        created: created,
        onboardingTokenExpiresAt: approvalRequired.onboardingTokenExpiresAt,
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

  Future<CloudSyncAuthenticatedSession> waitForDevicePairing(
    E2eePendingDevicePairing pairing,
  ) async {
    _beginExclusiveOperation();
    _DeviceContext? context;
    KelivoPendingPairingHandle? acceptingHandle;
    KelivoAccountRootKeyHandle? acceptedArk;
    _PairingRecoveryTransaction? transaction;
    Uint8List? originalState;
    Uint8List? fullState;
    Object? primaryError;
    var transactionPersisted = false;
    var completed = false;
    var waitStarted = false;
    try {
      pairing._beginWait(this);
      waitStarted = true;
      final approved = await _waitForPairingApproval(pairing);
      acceptingHandle = pairing._beginAccept();
      context = await _openDeviceContext(pairing.loginName);
      await _validatePairingTargetContext(context, pairing._created);
      originalState = await _deviceStateStore.read(
        normalizedBaseUrl: _baseUrl,
        normalizedLoginName: pairing.loginName,
      );
      if (originalState == null) {
        throw StateError('待配对设备状态不存在');
      }

      final accepted = await _secureCore.acceptPairingApproval(
        context.key,
        context.identity,
        acceptingHandle,
        nowMs: DateTime.now().toUtc().millisecondsSinceEpoch,
        issuerDeviceId: E2eeAccountAuthenticator._uuidBytes(
          approved.issuerDeviceId,
        ),
        keyEpoch: approved.keyEpoch,
        issuerPublicKeys: KelivoDevicePublicKeys(
          signingPublicKey: approved.issuerSigningPublicKey,
          keyAgreementPublicKey: approved.issuerKeyAgreementPublicKey,
        ),
        approval: KelivoPairingApprovalBundle(
          envelope: approved.accountKeyEnvelope,
          signature: approved.deviceProof,
          authenticator: approved.pairingAuthenticator,
        ),
      );
      acceptingHandle = null;
      acceptedArk = accepted.ark;
      fullState = Uint8List.fromList(accepted.stateBlob);
      transaction = _PairingRecoveryTransaction(
        pairingId: approved.pairingId,
        userId: approved.accountContextId,
        deviceId: approved.targetDevice.id,
        keyVersion: approved.targetDevice.keyVersion,
        keyEpoch: approved.keyEpoch,
        onboardingToken: pairing._onboardingToken,
        onboardingTokenExpiresAt: pairing._onboardingTokenExpiresAt,
        pairingExpiresAt: approved.expiresAt,
        originalStateBlob: originalState,
        fullStateBlob: fullState,
      );
      await _validatePairingRecoveryStates(context, transaction);
      await _persistPendingPairing(
        context,
        normalizedLoginName: pairing.loginName,
        transaction: transaction,
      );
      transactionPersisted = true;
      await _deviceStateStore.write(
        normalizedBaseUrl: _baseUrl,
        normalizedLoginName: pairing.loginName,
        blob: fullState,
      );

      final session = await _accountClient.consumeDevicePairing(
        token: pairing._onboardingToken,
        pairingId: pairing._pairingId,
      );
      _validatePairingSession(
        normalizedLoginName: pairing.loginName,
        transaction: transaction,
        session: session,
      );
      completed = true;
      return session;
    } catch (error) {
      primaryError = error;
      rethrow;
    } finally {
      try {
        final remaining = waitStarted
            ? pairing._finishCompletion(succeeded: completed)
            : null;
        if (!transactionPersisted) {
          for (final pending in <KelivoPendingPairingHandle?>[
            acceptingHandle,
            remaining,
          ]) {
            if (pending != null) {
              await _secureCore.cancelPendingPairing(pending);
            }
          }
        }
        E2eeAccountAuthenticator._clearBytes(originalState);
        E2eeAccountAuthenticator._clearBytes(fullState);
        transaction?.dispose();
        await _closeHandles(ark: acceptedArk, context: context);
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

  Future<void> confirmDevicePairing({
    required String loginName,
    required CloudSyncAuthenticatedSession session,
  }) async {
    _beginExclusiveOperation();
    _DeviceContext? context;
    _OpenedPendingPairing? pending;
    Object? primaryError;
    try {
      final normalizedLoginName = E2eeAccountAuthenticator._normalizeLoginName(
        loginName,
      );
      context = await _openDeviceContext(normalizedLoginName);
      pending = await _readPendingPairing(context, normalizedLoginName);
      if (pending == null) return;
      await _ensurePendingPairingFullState(
        context,
        normalizedLoginName: normalizedLoginName,
        transaction: pending.transaction,
      );
      _validatePairingSession(
        normalizedLoginName: normalizedLoginName,
        transaction: pending.transaction,
        session: session,
      );
      final deleted = await _deviceStateStore.deletePendingPairingEnvelope(
        normalizedBaseUrl: _baseUrl,
        normalizedLoginName: normalizedLoginName,
        expectedDigest: pending.envelopeDigest,
      );
      if (!deleted) {
        throw StateError('设备配对恢复事务已被其他进程替换');
      }
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
        E2eeAccountAuthenticator._logSuppressedCleanupFailure(
          error,
          stackTrace,
        );
      } finally {
        _authenticationInProgress = false;
      }
    }
  }

  Future<CloudSyncDevicePairingApproval> approveScannedDevicePairing({
    required String loginName,
    required CloudSyncAuthenticatedSession session,
    required Uint8List qrFrame,
  }) async {
    try {
      _beginExclusiveOperation();
    } catch (_) {
      E2eeAccountAuthenticator._clearBytesPreservingFailure(qrFrame);
      rethrow;
    }
    _DeviceContext? context;
    CloudSyncDevicePairingQrPayload? payload;
    Uint8List? pairingSecret;
    Object? primaryError;
    try {
      final normalizedLoginName = E2eeAccountAuthenticator._normalizeLoginName(
        loginName,
      );
      final now = DateTime.now().toUtc();
      if (session.user.loginName != normalizedLoginName ||
          session.tokenExpiresAt.isBefore(now) ||
          session.tokenExpiresAt.isAtSameMomentAs(now)) {
        throw StateError('配对签发会话与当前账户不匹配或已经过期');
      }
      if (session.device.platform != CloudSyncPlatform.android &&
          session.device.platform != CloudSyncPlatform.ios) {
        throw UnsupportedError('设备配对只能由移动可信设备批准');
      }

      context = await _openDeviceContext(normalizedLoginName);
      _authenticatedLoginResult(context, session);
      final account = context.account;
      final ark = context.ark;
      if (account == null || ark == null) {
        throw StateError('配对签发设备缺少账户密钥状态');
      }

      payload = CloudSyncDevicePairingQrCodec.decodeTakingOwnership(
        qrFrame,
        now: now,
      );
      payload.requireAccountContextMatchesLocalUserId(session.user.id);
      pairingSecret = payload.takePairingSecret();
      late final KelivoPairingApprovalBundle bundle;
      try {
        bundle = await _secureCore.createPairingApproval(
          context.identity,
          ark,
          pairingId: payload.pairingIdBytes,
          userId: account.userId,
          issuerDeviceId: context.deviceId,
          targetDeviceId: payload.targetDeviceIdBytes,
          expiresAtMs: payload.expiresAt.millisecondsSinceEpoch,
          challenge: payload.challenge,
          keyEpoch: account.keyEpoch,
          targetPublicKeys: KelivoDevicePublicKeys(
            signingPublicKey: payload.signingPublicKey,
            keyAgreementPublicKey: payload.keyAgreementPublicKey,
          ),
          pairingSecret: pairingSecret,
        );
      } finally {
        E2eeAccountAuthenticator._clearBytes(pairingSecret);
        pairingSecret = null;
      }

      final approval = await _approvePairingBundleWithRetry(
        session: session,
        payload: payload,
        bundle: bundle,
      );
      if (approval.pairingId != payload.pairingId) {
        throw StateError('服务端批准结果与扫码配对不匹配');
      }
      return approval;
    } catch (error) {
      primaryError = error;
      rethrow;
    } finally {
      try {
        E2eeAccountAuthenticator._clearBytesPreservingFailure(qrFrame);
        E2eeAccountAuthenticator._clearBytes(pairingSecret);
        payload?.dispose();
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

  Future<CloudSyncDevicePairingApproval> _approvePairingBundleWithRetry({
    required CloudSyncAuthenticatedSession session,
    required CloudSyncDevicePairingQrPayload payload,
    required KelivoPairingApprovalBundle bundle,
  }) async {
    final retryDeadline = payload.expiresAt.isBefore(session.tokenExpiresAt)
        ? payload.expiresAt
        : session.tokenExpiresAt;
    for (var attempt = 1; ; attempt++) {
      try {
        return await _accountClient.approveDevicePairing(
          token: session.token,
          pairingId: payload.pairingId,
          keyEpoch: session.keyEpoch,
          accountKeyEnvelope: bundle.envelope,
          deviceProof: bundle.signature,
          pairingAuthenticator: bundle.authenticator,
        );
      } on CloudSyncException catch (error) {
        final retryAt = DateTime.now().toUtc().add(_pairingApprovalRetryDelay);
        if (!error.retryable ||
            attempt >= _pairingApprovalMaximumAttempts ||
            !retryAt.isBefore(retryDeadline)) {
          rethrow;
        }
        // 原样重放同一 bundle 才能与服务端批准幂等键保持一致。
        await Future<void>.delayed(_pairingApprovalRetryDelay);
      }
    }
  }

  Future<CloudSyncDevicePairingApproved> _waitForPairingApproval(
    E2eePendingDevicePairing pairing,
  ) async {
    while (true) {
      final now = DateTime.now().toUtc();
      final deadline =
          pairing.expiresAt.isBefore(pairing._onboardingTokenExpiresAt)
          ? pairing.expiresAt
          : pairing._onboardingTokenExpiresAt;
      if (!now.isBefore(deadline)) {
        throw const CloudSyncException(
          kind: CloudSyncFailureKind.conflict,
          retryable: false,
          serverCode: 'SYNC_DEVICE_PAIRING_EXPIRED',
        );
      }

      CloudSyncDevicePairingQueryResult query;
      try {
        query = await _accountClient.queryDevicePairing(
          token: pairing._onboardingToken,
          pairingId: pairing._pairingId,
        );
      } on CloudSyncException catch (error) {
        if (!error.retryable) rethrow;
        await _delayUntilNextPairingQuery(deadline);
        continue;
      }
      _validatePairingQuery(pairing._created, query);
      if (query is CloudSyncDevicePairingApproved) {
        return query;
      }
      await _delayUntilNextPairingQuery(deadline);
    }
  }

  Future<void> _delayUntilNextPairingQuery(DateTime deadline) async {
    final remaining = deadline.difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) return;
    await Future<void>.delayed(
      remaining < _pairingQueryInterval ? remaining : _pairingQueryInterval,
    );
  }

  void _validatePairingQuery(
    CloudSyncDevicePairingCreated created,
    CloudSyncDevicePairingQueryResult query,
  ) {
    final expectedTarget = created.targetDevice;
    final actualTarget = query.targetDevice;
    if (query.pairingId != created.pairingId ||
        query.accountContextId != created.accountContextId ||
        query.expiresAt != created.expiresAt ||
        !E2eeAccountAuthenticator._sameBytes(
          query.challenge,
          created.challenge,
        ) ||
        actualTarget.id != expectedTarget.id ||
        actualTarget.name != expectedTarget.name ||
        actualTarget.platform != expectedTarget.platform ||
        actualTarget.clientVersion != expectedTarget.clientVersion ||
        actualTarget.keyVersion != expectedTarget.keyVersion ||
        actualTarget.authGeneration != expectedTarget.authGeneration ||
        !E2eeAccountAuthenticator._sameBytes(
          actualTarget.signingPublicKey,
          expectedTarget.signingPublicKey,
        ) ||
        !E2eeAccountAuthenticator._sameBytes(
          actualTarget.keyAgreementPublicKey,
          expectedTarget.keyAgreementPublicKey,
        )) {
      throw StateError('服务端配对查询与已绑定 transcript 不匹配');
    }
  }

  Future<void> _validatePairingTargetContext(
    _DeviceContext context,
    CloudSyncDevicePairingCreated created,
  ) async {
    final target = created.targetDevice;
    final publicKeys = await _secureCore.readDevicePublicKeys(context.identity);
    if (context.account != null ||
        context.ark != null ||
        context.deviceIdText != target.id ||
        context.keyVersion != target.keyVersion ||
        !E2eeAccountAuthenticator._sameBytes(
          publicKeys.signingPublicKey,
          target.signingPublicKey,
        ) ||
        !E2eeAccountAuthenticator._sameBytes(
          publicKeys.keyAgreementPublicKey,
          target.keyAgreementPublicKey,
        )) {
      throw StateError('待配对设备状态与已绑定 transcript 不匹配');
    }
  }

  Future<void> _persistPendingPairing(
    _DeviceContext context, {
    required String normalizedLoginName,
    required _PairingRecoveryTransaction transaction,
  }) async {
    final frame = _encodePairingRecoveryTransaction(transaction);
    final recordId = _pairingRecordId(normalizedLoginName);
    final associatedData = _pairingAssociatedData(normalizedLoginName);
    Uint8List? envelope;
    try {
      envelope = await _secureCore.sealRecord(
        context.key,
        recordId: recordId,
        epoch: _pairingRecordEpoch,
        associatedData: associatedData,
        plaintext: frame,
      );
      if (envelope.length >
          DeviceStateBlobStore.pendingPairingEnvelopeMaxLength) {
        throw const FormatException('配对恢复事务密文超过持久化边界');
      }
      await _deviceStateStore.writePendingPairingEnvelope(
        normalizedBaseUrl: _baseUrl,
        normalizedLoginName: normalizedLoginName,
        envelope: envelope,
      );
    } finally {
      E2eeAccountAuthenticator._clearBytes(frame);
      E2eeAccountAuthenticator._clearBytes(recordId);
      E2eeAccountAuthenticator._clearBytes(associatedData);
      E2eeAccountAuthenticator._clearBytes(envelope);
    }
  }

  Future<_OpenedPendingPairing?> _readPendingPairing(
    _DeviceContext context,
    String normalizedLoginName,
  ) async {
    final envelope = await _deviceStateStore.readPendingPairingEnvelope(
      normalizedBaseUrl: _baseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    if (envelope == null) return null;
    final envelopeDigest = Uint8List.fromList(sha256.convert(envelope).bytes);
    final recordId = _pairingRecordId(normalizedLoginName);
    final associatedData = _pairingAssociatedData(normalizedLoginName);
    Uint8List? plaintext;
    try {
      plaintext = await _secureCore.openRecord(
        context.key,
        recordId: recordId,
        epoch: _pairingRecordEpoch,
        associatedData: associatedData,
        envelope: envelope,
      );
      final transaction = _decodePairingRecoveryTransaction(plaintext);
      return _OpenedPendingPairing(
        transaction: transaction,
        envelopeDigest: envelopeDigest,
      );
    } catch (_) {
      E2eeAccountAuthenticator._clearBytes(envelopeDigest);
      rethrow;
    } finally {
      E2eeAccountAuthenticator._clearBytes(envelope);
      E2eeAccountAuthenticator._clearBytes(recordId);
      E2eeAccountAuthenticator._clearBytes(associatedData);
      E2eeAccountAuthenticator._clearBytes(plaintext);
    }
  }

  Future<void> _ensurePendingPairingFullState(
    _DeviceContext context, {
    required String normalizedLoginName,
    required _PairingRecoveryTransaction transaction,
  }) async {
    await _validatePairingRecoveryStates(context, transaction);
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
        E2eeAccountAuthenticator._uuidString(account.userId) !=
            transaction.userId ||
        account.keyEpoch != transaction.keyEpoch) {
      throw StateError('配对恢复事务与已绑定设备状态不匹配');
    }
  }

  Future<void> _validatePairingRecoveryStates(
    _DeviceContext context,
    _PairingRecoveryTransaction transaction,
  ) async {
    KelivoOpenedDeviceState? original;
    KelivoOpenedDeviceState? full;
    Object? primaryError;
    try {
      original = await _secureCore.openDeviceState(
        context.key,
        stateBlob: transaction.originalStateBlob,
      );
      full = await _secureCore.openDeviceState(
        context.key,
        stateBlob: transaction.fullStateBlob,
      );
      final fullAccount = full.binding.account;
      if (original.ark != null ||
          original.binding.account != null ||
          E2eeAccountAuthenticator._uuidString(original.binding.deviceId) !=
              transaction.deviceId ||
          original.binding.keyVersion != transaction.keyVersion ||
          full.ark == null ||
          fullAccount == null ||
          E2eeAccountAuthenticator._uuidString(full.binding.deviceId) !=
              transaction.deviceId ||
          full.binding.keyVersion != transaction.keyVersion ||
          E2eeAccountAuthenticator._uuidString(fullAccount.userId) !=
              transaction.userId ||
          fullAccount.keyEpoch != transaction.keyEpoch ||
          context.deviceIdText != transaction.deviceId ||
          context.keyVersion != transaction.keyVersion) {
        throw StateError('配对恢复事务内的设备状态绑定无效');
      }
      final currentKeys = await _secureCore.readDevicePublicKeys(
        context.identity,
      );
      final originalKeys = await _secureCore.readDevicePublicKeys(
        original.identity,
      );
      final fullKeys = await _secureCore.readDevicePublicKeys(full.identity);
      if (!_sameDevicePublicKeys(currentKeys, originalKeys) ||
          !_sameDevicePublicKeys(currentKeys, fullKeys)) {
        throw StateError('配对恢复事务内的设备身份已被替换');
      }
    } catch (error) {
      primaryError = error;
      rethrow;
    } finally {
      Object? cleanupError;
      StackTrace? cleanupStackTrace;
      if (full != null) {
        try {
          await _closeTemporaryOpenedState(full, primaryError: primaryError);
        } catch (error, stackTrace) {
          cleanupError = error;
          cleanupStackTrace = stackTrace;
        }
      }
      if (original != null) {
        try {
          await _closeTemporaryOpenedState(
            original,
            primaryError: primaryError ?? cleanupError,
          );
        } catch (error, stackTrace) {
          cleanupError ??= error;
          cleanupStackTrace ??= stackTrace;
        }
      }
      if (primaryError == null &&
          cleanupError != null &&
          cleanupStackTrace != null) {
        Error.throwWithStackTrace(cleanupError, cleanupStackTrace);
      }
    }
  }

  bool _sameDevicePublicKeys(
    KelivoDevicePublicKeys left,
    KelivoDevicePublicKeys right,
  ) {
    return E2eeAccountAuthenticator._sameBytes(
          left.signingPublicKey,
          right.signingPublicKey,
        ) &&
        E2eeAccountAuthenticator._sameBytes(
          left.keyAgreementPublicKey,
          right.keyAgreementPublicKey,
        );
  }

  void _validatePairingSession({
    required String normalizedLoginName,
    required _PairingRecoveryTransaction transaction,
    required CloudSyncAuthenticatedSession session,
  }) {
    if (session.user.id != transaction.userId ||
        session.user.loginName != normalizedLoginName ||
        session.device.id != transaction.deviceId ||
        session.keyEpoch != transaction.keyEpoch) {
      throw StateError('配对消费结果与本地恢复事务不匹配');
    }
  }

  Uint8List _pairingRecordId(String normalizedLoginName) {
    final digest = sha256.convert(
      utf8.encode(
        '$_pairingRecordDomain\u0000$_baseUrl\u0000$normalizedLoginName',
      ),
    );
    return Uint8List.fromList(digest.bytes.sublist(0, 16));
  }

  Uint8List _pairingAssociatedData(String normalizedLoginName) {
    return Uint8List.fromList(
      utf8.encode(
        '$_pairingAssociatedDataDomain\u0000'
        '$_baseUrl\u0000$normalizedLoginName',
      ),
    );
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
