part of 'e2ee_account_authenticator.dart';

const _pairingApprovalMaximumAttempts = 3;
const _pairingApprovalRetryDelay = Duration(milliseconds: 200);
const _pairingQueryInterval = Duration(seconds: 1);
const _pairingRecordDomain = 'kelivo.e2ee.pairing-transaction.record.v1';
const _pairingAssociatedDataDomain = 'kelivo.e2ee.pairing-transaction.aad.v1';
const _pairingRecordEpoch = 1;
const _pairingFrameVersion = 3;
const _pairingOnboardingTokenLength = 61;
const _pairingSessionTokenLength = 50;
const _pairingOnboardingTokenOffset = 96;
const _pairingSessionTokenOffset = 160;
const _pairingOriginalStateOffset = 216;
const _pairingFullStateOffset =
    _pairingOriginalStateOffset + DeviceStateBlobStore.blobLength;
const _pairingIssuerDeviceIdOffset =
    _pairingFullStateOffset + DeviceStateBlobStore.blobLength;
const _pairingIssuerKeyVersionOffset = _pairingIssuerDeviceIdOffset + 16;
const _pairingIssuerAuthGenerationOffset = _pairingIssuerKeyVersionOffset + 4;
const _pairingTargetAuthGenerationOffset =
    _pairingIssuerAuthGenerationOffset + 4;
const _pairingIssuerSigningPublicKeyOffset =
    _pairingTargetAuthGenerationOffset + 8;
const _pairingIssuerKeyAgreementPublicKeyOffset =
    _pairingIssuerSigningPublicKeyOffset + cloudSyncDevicePublicKeyBytes;
const _pairingApprovedAccountKeyEnvelopeOffset =
    _pairingIssuerKeyAgreementPublicKeyOffset + cloudSyncDevicePublicKeyBytes;
const _pairingFrameLength =
    _pairingApprovedAccountKeyEnvelopeOffset + cloudSyncAccountKeyEnvelopeBytes;
final Uint8List _pairingFrameMagic = Uint8List.fromList(
  ascii.encode('KELVPT03'),
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

final class E2eePendingDevicePairing implements E2eeDevicePairingSession {
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
  @override
  final DateTime expiresAt;
  final CloudSyncOnboardingToken _onboardingToken;
  final String _pairingId;
  KelivoPendingPairingHandle? _pendingHandle;
  CloudSyncDevicePairingQrPayload? _qrPayload;
  final CloudSyncDevicePairingCreated _created;
  final DateTime _onboardingTokenExpiresAt;
  final Completer<void> _cancellationRequested = Completer<void>();
  final Completer<void> _waitFinished = Completer<void>();
  _E2eePendingPairingState _state = _E2eePendingPairingState.active;
  bool _cancelInterruptedWait = false;
  Future<void>? _cancellationTask;

  @override
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

  @override
  Future<CloudSyncAuthenticatedSession> wait() {
    return E2eeDevicePairingAuthentication(_owner).waitForDevicePairing(this);
  }

  @override
  Future<void> cancel() {
    final existing = _cancellationTask;
    if (existing != null) return existing;
    final task = E2eeDevicePairingAuthentication(
      _owner,
    ).cancelDevicePairing(this);
    _cancellationTask = task;
    return task;
  }

  bool _isWaitingFor(E2eeAccountAuthenticator owner) {
    return identical(owner, _owner) &&
        _state == _E2eePendingPairingState.waiting;
  }

  KelivoPendingPairingHandle? _beginCancel(E2eeAccountAuthenticator owner) {
    if (!identical(owner, _owner)) {
      throw StateError('设备配对不属于当前认证器');
    }
    if (_state != _E2eePendingPairingState.active &&
        _state != _E2eePendingPairingState.waiting) {
      throw StateError('设备配对已经结束');
    }
    _cancelInterruptedWait = _state == _E2eePendingPairingState.waiting;
    _state = _E2eePendingPairingState.cancelling;
    _cancellationRequested.complete();
    _qrPayload?.dispose();
    _qrPayload = null;
    final pending = _pendingHandle;
    _pendingHandle = null;
    return pending;
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
    if (_state == _E2eePendingPairingState.cancelling ||
        _state == _E2eePendingPairingState.cancelled) {
      _qrPayload?.dispose();
      _qrPayload = null;
      return null;
    }
    _state = succeeded
        ? _E2eePendingPairingState.completed
        : _E2eePendingPairingState.failed;
    _qrPayload?.dispose();
    _qrPayload = null;
    final pending = _pendingHandle;
    _pendingHandle = null;
    return pending;
  }

  Future<T> _awaitWhileNotCancelled<T>(Future<T> operation) async {
    _throwIfCancellationRequested();
    await Future.any<void>(<Future<void>>[
      operation.then<void>((_) {}),
      _cancellationRequested.future,
    ]);
    _throwIfCancellationRequested();
    return operation;
  }

  void _throwIfCancellationRequested() {
    if (_state == _E2eePendingPairingState.cancelling ||
        _state == _E2eePendingPairingState.cancelled) {
      throw const CloudSyncException(
        kind: CloudSyncFailureKind.cancelled,
        retryable: false,
        serverCode: 'SYNC_DEVICE_PAIRING_CANCELLED',
      );
    }
  }

  bool get _cancellationOwnsExclusiveOperation => _cancelInterruptedWait;

  Future<void> get _waitFinishedFuture => _waitFinished.future;

  void _markWaitFinished() {
    if (!_waitFinished.isCompleted) {
      _waitFinished.complete();
    }
  }

  void _finishCancel() {
    _state = _E2eePendingPairingState.cancelled;
    _qrPayload?.dispose();
    _qrPayload = null;
    _pendingHandle = null;
  }
}

Uint8List _encodePairingRecoveryTransaction(
  _PairingRecoveryTransaction transaction,
) {
  final tokenBytes = Uint8List.fromList(
    ascii.encode(transaction.onboardingToken.value),
  );
  final sessionTokenBytes = Uint8List.fromList(
    ascii.encode(transaction.sessionToken.value),
  );
  try {
    if (transaction.keyVersion <= 0 ||
        transaction.keyVersion > 0xffffffff ||
        transaction.keyEpoch <= 0 ||
        transaction.keyEpoch > 0xffffffff ||
        tokenBytes.length != _pairingOnboardingTokenLength ||
        sessionTokenBytes.length != _pairingSessionTokenLength ||
        transaction.onboardingTokenExpiresAt.millisecondsSinceEpoch <= 0 ||
        transaction.pairingExpiresAt.millisecondsSinceEpoch <= 0 ||
        transaction.pairingExpiresAt.isAfter(
          transaction.onboardingTokenExpiresAt,
        ) ||
        transaction.issuerKeyVersion <= 0 ||
        transaction.issuerKeyVersion > 0x7fffffff ||
        transaction.issuerAuthGeneration < 0 ||
        transaction.issuerAuthGeneration > 0x7fffffff ||
        transaction.targetAuthGeneration < 0 ||
        transaction.targetAuthGeneration >= 0x7fffffff ||
        transaction.issuerSigningPublicKey.length !=
            cloudSyncDevicePublicKeyBytes ||
        transaction.issuerKeyAgreementPublicKey.length !=
            cloudSyncDevicePublicKeyBytes ||
        transaction.approvedAccountKeyEnvelope.length !=
            cloudSyncAccountKeyEnvelopeBytes ||
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
    fields.setUint16(90, sessionTokenBytes.length, Endian.big);
    frame.setRange(
      _pairingOnboardingTokenOffset,
      _pairingOnboardingTokenOffset + tokenBytes.length,
      tokenBytes,
    );
    frame.setRange(
      _pairingSessionTokenOffset,
      _pairingSessionTokenOffset + sessionTokenBytes.length,
      sessionTokenBytes,
    );
    frame.setRange(
      _pairingOriginalStateOffset,
      _pairingFullStateOffset,
      transaction.originalStateBlob,
    );
    frame.setRange(
      _pairingFullStateOffset,
      _pairingIssuerDeviceIdOffset,
      transaction.fullStateBlob,
    );
    frame.setRange(
      _pairingIssuerDeviceIdOffset,
      _pairingIssuerKeyVersionOffset,
      E2eeAccountAuthenticator._uuidBytes(transaction.issuerDeviceId),
    );
    fields.setUint32(
      _pairingIssuerKeyVersionOffset,
      transaction.issuerKeyVersion,
      Endian.big,
    );
    fields.setUint32(
      _pairingIssuerAuthGenerationOffset,
      transaction.issuerAuthGeneration,
      Endian.big,
    );
    fields.setUint32(
      _pairingTargetAuthGenerationOffset,
      transaction.targetAuthGeneration,
      Endian.big,
    );
    frame.setRange(
      _pairingIssuerSigningPublicKeyOffset,
      _pairingIssuerKeyAgreementPublicKeyOffset,
      transaction.issuerSigningPublicKey,
    );
    frame.setRange(
      _pairingIssuerKeyAgreementPublicKeyOffset,
      _pairingApprovedAccountKeyEnvelopeOffset,
      transaction.issuerKeyAgreementPublicKey,
    );
    frame.setRange(
      _pairingApprovedAccountKeyEnvelopeOffset,
      _pairingFrameLength,
      transaction.approvedAccountKeyEnvelope,
    );
    return frame;
  } finally {
    tokenBytes.fillRange(0, tokenBytes.length, 0);
    sessionTokenBytes.fillRange(0, sessionTokenBytes.length, 0);
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
  final sessionTokenLength = fields.getUint16(90, Endian.big);
  final issuerKeyVersion = fields.getUint32(
    _pairingIssuerKeyVersionOffset,
    Endian.big,
  );
  final issuerAuthGeneration = fields.getUint32(
    _pairingIssuerAuthGenerationOffset,
    Endian.big,
  );
  final targetAuthGeneration = fields.getUint32(
    _pairingTargetAuthGenerationOffset,
    Endian.big,
  );
  if (fields.getUint16(8, Endian.big) != _pairingFrameVersion ||
      fields.getUint16(10, Endian.big) != 0 ||
      keyEpoch <= 0 ||
      keyVersion <= 0 ||
      fields.getUint32(20, Endian.big) != 0 ||
      onboardingExpiresAtMs <= 0 ||
      pairingExpiresAtMs <= 0 ||
      tokenLength != _pairingOnboardingTokenLength ||
      sessionTokenLength != _pairingSessionTokenLength ||
      fields.getUint32(92, Endian.big) != 0 ||
      issuerKeyVersion <= 0 ||
      issuerKeyVersion > 0x7fffffff ||
      issuerAuthGeneration > 0x7fffffff ||
      targetAuthGeneration >= 0x7fffffff ||
      !_allZero(
        frame,
        _pairingTargetAuthGenerationOffset + 4,
        _pairingIssuerSigningPublicKeyOffset,
      ) ||
      !_allZero(
        frame,
        _pairingOnboardingTokenOffset + tokenLength,
        _pairingSessionTokenOffset,
      ) ||
      !_allZero(
        frame,
        _pairingSessionTokenOffset + sessionTokenLength,
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
  final sessionToken = ascii.decode(
    Uint8List.sublistView(
      frame,
      _pairingSessionTokenOffset,
      _pairingSessionTokenOffset + sessionTokenLength,
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
    sessionToken: CloudSyncFullSessionToken.parse(sessionToken),
    onboardingTokenExpiresAt: onboardingTokenExpiresAt,
    pairingExpiresAt: pairingExpiresAt,
    issuerDeviceId: _pairingUuidFromFrame(frame, _pairingIssuerDeviceIdOffset),
    issuerKeyVersion: issuerKeyVersion,
    issuerAuthGeneration: issuerAuthGeneration,
    targetAuthGeneration: targetAuthGeneration,
    issuerSigningPublicKey: Uint8List.fromList(
      frame.sublist(
        _pairingIssuerSigningPublicKeyOffset,
        _pairingIssuerKeyAgreementPublicKeyOffset,
      ),
    ),
    issuerKeyAgreementPublicKey: Uint8List.fromList(
      frame.sublist(
        _pairingIssuerKeyAgreementPublicKeyOffset,
        _pairingApprovedAccountKeyEnvelopeOffset,
      ),
    ),
    approvedAccountKeyEnvelope: Uint8List.fromList(
      frame.sublist(_pairingApprovedAccountKeyEnvelopeOffset),
    ),
    originalStateBlob: Uint8List.fromList(
      frame.sublist(_pairingOriginalStateOffset, _pairingFullStateOffset),
    ),
    fullStateBlob: Uint8List.fromList(
      frame.sublist(_pairingFullStateOffset, _pairingIssuerDeviceIdOffset),
    ),
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
    required this.sessionToken,
    required DateTime onboardingTokenExpiresAt,
    required DateTime pairingExpiresAt,
    required this.issuerDeviceId,
    required this.issuerKeyVersion,
    required this.issuerAuthGeneration,
    required this.targetAuthGeneration,
    required Uint8List issuerSigningPublicKey,
    required Uint8List issuerKeyAgreementPublicKey,
    required Uint8List approvedAccountKeyEnvelope,
    required Uint8List originalStateBlob,
    required Uint8List fullStateBlob,
  }) : onboardingTokenExpiresAt = onboardingTokenExpiresAt.toUtc(),
       pairingExpiresAt = pairingExpiresAt.toUtc(),
       issuerSigningPublicKey = Uint8List.fromList(issuerSigningPublicKey),
       issuerKeyAgreementPublicKey = Uint8List.fromList(
         issuerKeyAgreementPublicKey,
       ),
       approvedAccountKeyEnvelope = Uint8List.fromList(
         approvedAccountKeyEnvelope,
       ),
       originalStateBlob = Uint8List.fromList(originalStateBlob),
       fullStateBlob = Uint8List.fromList(fullStateBlob);

  final String pairingId;
  final String userId;
  final String deviceId;
  final int keyVersion;
  final int keyEpoch;
  final CloudSyncOnboardingToken onboardingToken;
  final CloudSyncFullSessionToken sessionToken;
  final DateTime onboardingTokenExpiresAt;
  final DateTime pairingExpiresAt;
  final String issuerDeviceId;
  final int issuerKeyVersion;
  final int issuerAuthGeneration;
  final int targetAuthGeneration;
  final Uint8List issuerSigningPublicKey;
  final Uint8List issuerKeyAgreementPublicKey;
  final Uint8List approvedAccountKeyEnvelope;
  final Uint8List originalStateBlob;
  final Uint8List fullStateBlob;
  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    issuerSigningPublicKey.fillRange(0, issuerSigningPublicKey.length, 0);
    issuerKeyAgreementPublicKey.fillRange(
      0,
      issuerKeyAgreementPublicKey.length,
      0,
    );
    approvedAccountKeyEnvelope.fillRange(
      0,
      approvedAccountKeyEnvelope.length,
      0,
    );
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
        normalizedServiceOrigin: _baseUrl,
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
    final interruptsActiveWait = pairing._isWaitingFor(this);
    if (!interruptsActiveWait) {
      _beginExclusiveOperation();
    }
    Object? primaryError;
    KelivoPendingPairingHandle? pending;
    var cancellationStarted = false;
    try {
      pending = pairing._beginCancel(this);
      cancellationStarted = true;
      if (pending != null) {
        await _secureCore.cancelPendingPairing(pending);
      }
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
          pairing._finishCancel();
          if (interruptsActiveWait) {
            await pairing._waitFinishedFuture;
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
      final originalSnapshot = await _deviceStateStore.readVersioned(
        normalizedBaseUrl: _baseUrl,
        normalizedLoginName: pairing.loginName,
      );
      if (originalSnapshot == null) {
        throw StateError('待配对设备状态不存在');
      }
      if (originalSnapshot.version != context.stateVersion) {
        throw const DeviceStateBlobConflict();
      }
      originalState = originalSnapshot.blob;

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
        sessionToken: CloudSyncFullSessionToken.generate(),
        onboardingTokenExpiresAt: pairing._onboardingTokenExpiresAt,
        pairingExpiresAt: approved.expiresAt,
        issuerDeviceId: approved.issuerDeviceId,
        issuerKeyVersion: approved.issuerKeyVersion,
        issuerAuthGeneration: approved.issuerAuthGeneration,
        targetAuthGeneration: approved.targetDevice.authGeneration,
        issuerSigningPublicKey: approved.issuerSigningPublicKey,
        issuerKeyAgreementPublicKey: approved.issuerKeyAgreementPublicKey,
        approvedAccountKeyEnvelope: approved.accountKeyEnvelope,
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
      await _deviceStateStore.compareAndSwap(
        normalizedBaseUrl: _baseUrl,
        normalizedLoginName: pairing.loginName,
        expectedVersion: context.stateVersion,
        blob: fullState,
      );

      final session = await _accountClient.consumeDevicePairing(
        token: pairing._onboardingToken,
        pairingId: pairing._pairingId,
        sessionToken: transaction.sessionToken,
      );
      final verifiedSession = await _validatePairingSession(
        context: context,
        accountRootKey: acceptedArk,
        normalizedLoginName: pairing.loginName,
        transaction: transaction,
        session: session,
      );
      completed = true;
      return _bindVerifiedDeviceKeyVersion(context, verifiedSession);
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
        final cancellationOwnsOperation =
            waitStarted && pairing._cancellationOwnsExclusiveOperation;
        if (waitStarted) {
          pairing._markWaitFinished();
        }
        if (!cancellationOwnsOperation) {
          _authenticationInProgress = false;
        }
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
      final accountRootKey = context.ark;
      if (accountRootKey == null) {
        throw StateError('配对确认缺少账户根密钥');
      }
      await _validatePairingSession(
        context: context,
        accountRootKey: accountRootKey,
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

  bool _pairingRecoveryRequiresOpaqueLogin(CloudSyncException error) {
    return !error.retryable &&
        (error.serverCode == 'AUTH_DEVICE_PAIRING_CONFLICT' ||
            error.serverCode == 'AUTH_ONBOARDING_TOKEN_INVALID');
  }

  Future<E2eeAccountLoginApprovalRequired>
  _rollbackPairingAfterApprovalRequired(
    _DeviceContext context, {
    required String normalizedLoginName,
    required _OpenedPendingPairing pending,
    required CloudSyncOnboardingToken onboardingToken,
    required DateTime onboardingTokenExpiresAt,
    required CloudSyncAuthenticatedDevice device,
  }) async {
    final transaction = pending.transaction;
    await _validatePairingRecoveryStates(context, transaction);
    if (device.id != transaction.deviceId) {
      throw StateError('待批准登录与配对恢复事务的设备不匹配');
    }
    // 先发布 identity-only 状态；即使进程在删除 sidecar 前退出，下次仍可重复收敛。
    await _deviceStateStore.compareAndSwap(
      normalizedBaseUrl: _baseUrl,
      normalizedLoginName: normalizedLoginName,
      expectedVersion: context.stateVersion,
      blob: transaction.originalStateBlob,
    );
    final deleted = await _deviceStateStore.deletePendingPairingEnvelope(
      normalizedBaseUrl: _baseUrl,
      normalizedLoginName: normalizedLoginName,
      expectedDigest: pending.envelopeDigest,
    );
    if (!deleted) {
      throw StateError('设备配对恢复事务已被其他进程替换');
    }
    _accountClient.setToken(null);
    return E2eeAccountLoginApprovalRequired(
      onboardingToken: onboardingToken,
      onboardingTokenExpiresAt: onboardingTokenExpiresAt,
      loginName: normalizedLoginName,
      device: device,
    );
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

      payload = CloudSyncDevicePairingQrCodec.decodeTakingOwnership(
        qrFrame,
        now: now,
      );
      payload.requireServiceOriginMatches(_baseUrl);
      context = await _openDeviceContext(normalizedLoginName);
      _authenticatedLoginResult(context, session);
      final account = context.account;
      final ark = context.ark;
      if (account == null || ark == null) {
        throw StateError('配对签发设备缺少账户密钥状态');
      }

      payload.requireAccountContextMatchesLocalUserId(session.user.id);
      final membershipCommitPreparer =
          _devicePairingMembershipCommitPreparer ??
          (throw UnsupportedError('账户信任成员清单尚未接入设备配对批准'));
      final preparedMembershipCommit = await _preparePairingMembershipCommit(
        context: context,
        accountRootKey: ark,
        session: session,
        payload: payload,
        preparer: membershipCommitPreparer,
      );
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

      // 本地锚点不参与服务端 CAS，网络写入前后都要复核同一 capability。
      await membershipCommitPreparer.requireStillCurrent(
        accountRootKey: ark,
        prepared: preparedMembershipCommit,
      );
      final approval = await _approvePairingBundleWithRetry(
        session: session,
        payload: payload,
        bundle: bundle,
        membershipCommit: preparedMembershipCommit.commit,
      );
      if (approval.pairingId != payload.pairingId) {
        throw StateError('服务端批准结果与扫码配对不匹配');
      }
      await membershipCommitPreparer.requireStillCurrent(
        accountRootKey: ark,
        prepared: preparedMembershipCommit,
      );
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
    required CloudSyncDevicePairingMembershipCommit membershipCommit,
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
          membershipCommit: membershipCommit,
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

  Future<E2eePreparedDevicePairingMembershipCommit>
  _preparePairingMembershipCommit({
    required _DeviceContext context,
    required KelivoAccountRootKeyHandle accountRootKey,
    required CloudSyncAuthenticatedSession session,
    required CloudSyncDevicePairingQrPayload payload,
    required E2eeDevicePairingMembershipCommitPreparer preparer,
  }) async {
    final issuerPublicKeys = await _secureCore.readDevicePublicKeys(
      context.identity,
    );
    final issuer = E2eeMembershipDeviceInput(
      deviceId: context.deviceIdText,
      keyVersion: context.keyVersion,
      authGeneration: session.authGeneration,
      signingPublicKey: issuerPublicKeys.signingPublicKey,
      keyAgreementPublicKey: issuerPublicKeys.keyAgreementPublicKey,
    );
    // pending 设备在服务端创建和续期时始终保持 generation 0，消费原子激活为 1。
    final subject = E2eeMembershipDeviceInput(
      deviceId: payload.targetDeviceId,
      keyVersion: payload.keyVersion,
      authGeneration: 1,
      signingPublicKey: payload.signingPublicKey,
      keyAgreementPublicKey: payload.keyAgreementPublicKey,
    );
    _accountClient.setToken(session.token);
    final currentSecurityState = await _accountClient.getSecurityState();
    return preparer.prepare(
      accountRootKey: accountRootKey,
      userId: session.user.id,
      keyEpoch: session.keyEpoch,
      currentSecurityState: currentSecurityState,
      pairingId: payload.pairingId,
      issuer: issuer,
      subject: subject,
    );
  }

  Future<CloudSyncDevicePairingApproved> _waitForPairingApproval(
    E2eePendingDevicePairing pairing,
  ) async {
    while (true) {
      pairing._throwIfCancellationRequested();
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
        query = await pairing._awaitWhileNotCancelled(
          _accountClient.queryDevicePairing(
            token: pairing._onboardingToken,
            pairingId: pairing._pairingId,
          ),
        );
      } on CloudSyncException catch (error) {
        pairing._throwIfCancellationRequested();
        if (!error.retryable) rethrow;
        await pairing._awaitWhileNotCancelled(
          _delayUntilNextPairingQuery(deadline),
        );
        continue;
      }
      _validatePairingQuery(pairing._created, query);
      if (query is CloudSyncDevicePairingApproved) {
        return query;
      }
      await pairing._awaitWhileNotCancelled(
        _delayUntilNextPairingQuery(deadline),
      );
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
      await _deviceStateStore.compareAndSwap(
        normalizedBaseUrl: _baseUrl,
        normalizedLoginName: normalizedLoginName,
        expectedVersion: context.stateVersion,
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

  Future<CloudSyncAuthenticatedSession> _validatePairingSession({
    required _DeviceContext context,
    required KelivoAccountRootKeyHandle accountRootKey,
    required String normalizedLoginName,
    required _PairingRecoveryTransaction transaction,
    required CloudSyncAuthenticatedSession session,
  }) async {
    if (session.user.id != transaction.userId ||
        session.user.loginName != normalizedLoginName ||
        session.device.id != transaction.deviceId ||
        session.keyEpoch != transaction.keyEpoch ||
        session.authGeneration != transaction.targetAuthGeneration + 1 ||
        context.deviceIdText != transaction.deviceId ||
        context.keyVersion != transaction.keyVersion) {
      throw StateError('配对消费结果与本地恢复事务不匹配');
    }

    final state = session.securityState;
    final receipt = session.pairingReceipt;
    if (state == null || receipt == null) {
      throw StateError('配对消费结果缺少完整安全状态或消费回执');
    }
    if (state.keyEpoch != transaction.keyEpoch ||
        state.dataRekeyPhase != CloudSyncDataRekeyPhase.ready ||
        state.lastOperationId != transaction.pairingId ||
        receipt.pairingId != transaction.pairingId ||
        receipt.issuerDeviceId != transaction.issuerDeviceId ||
        receipt.keyEpoch != state.keyEpoch ||
        receipt.securityGeneration != state.generation ||
        !E2eeAccountAuthenticator._sameBytes(
          receipt.membershipManifestDigest.bytes,
          state.membershipManifestDigest.bytes,
        )) {
      throw StateError('配对消费回执与账户安全状态不匹配');
    }
    CloudSyncAccountSecurityEnvelope? localEnvelope;
    for (final envelope in state.envelopes) {
      if (envelope.targetDeviceId == transaction.deviceId) {
        localEnvelope = envelope;
        break;
      }
    }
    if (localEnvelope == null ||
        localEnvelope.issuerDeviceId != transaction.issuerDeviceId ||
        localEnvelope.keyEpoch != transaction.keyEpoch ||
        !E2eeAccountAuthenticator._sameBytes(
          localEnvelope.accountKeyEnvelope,
          transaction.approvedAccountKeyEnvelope,
        )) {
      throw StateError('配对消费账户密钥信封与冻结批准载荷不匹配');
    }

    final publicKeys = await _secureCore.readDevicePublicKeys(context.identity);
    final localMemberInput = E2eeMembershipDeviceInput(
      deviceId: transaction.deviceId,
      keyVersion: transaction.keyVersion,
      authGeneration: session.authGeneration,
      signingPublicKey: publicKeys.signingPublicKey,
      keyAgreementPublicKey: publicKeys.keyAgreementPublicKey,
    );
    final projection = E2eeMembershipServerProjection(
      userId: session.user.id,
      securityGeneration: state.generation,
      keyEpoch: state.keyEpoch,
      membershipManifestVersion: e2eeAccountTrustManifestFormatVersion,
      membershipManifest: state.membershipManifest,
      membershipManifestDigest: state.membershipManifestDigest.bytes,
      recoveryPublicKeyVersion: state.recoveryPublicKeyVersion,
      recoveryPublicKey: state.recoveryPublicKey,
      recoveryCapsuleVersion: state.recoveryCapsuleVersion,
      recoveryCapsule: state.recoveryCapsule,
      lastOperationId: state.lastOperationId,
      dataRekeyPhase: E2eeDataRekeyPhase.ready,
    );
    final verified = await const E2eeAccountTrustManifestModule().verify(
      ark: accountRootKey,
      expectation: E2eePairingBootstrapMembershipExpectation(
        projection: projection,
        consumedKeyEpoch: receipt.keyEpoch,
        consumedSecurityGeneration: receipt.securityGeneration,
        consumedMembershipManifestDigest:
            receipt.membershipManifestDigest.bytes,
        pairingId: receipt.pairingId,
        issuerDeviceId: receipt.issuerDeviceId,
        localMember: localMemberInput,
      ),
    );
    E2eeVerifiedMembershipDevice? verifiedLocalMember;
    E2eeVerifiedMembershipDevice? verifiedIssuerMember;
    for (final member in verified.members) {
      if (member.deviceId == transaction.deviceId) {
        verifiedLocalMember = member;
      }
      if (member.deviceId == transaction.issuerDeviceId) {
        verifiedIssuerMember = member;
      }
    }
    if (verifiedLocalMember == null ||
        verifiedIssuerMember == null ||
        verifiedIssuerMember.keyVersion != transaction.issuerKeyVersion ||
        verifiedIssuerMember.authGeneration !=
            transaction.issuerAuthGeneration ||
        !E2eeAccountAuthenticator._sameBytes(
          verifiedIssuerMember.signingPublicKey,
          transaction.issuerSigningPublicKey,
        ) ||
        !E2eeAccountAuthenticator._sameBytes(
          verifiedIssuerMember.keyAgreementPublicKey,
          transaction.issuerKeyAgreementPublicKey,
        )) {
      throw StateError('配对签发者公开身份与签名成员清单不匹配');
    }
    final localMember = CloudSyncMembershipDeviceMaterial(
      deviceId: verifiedLocalMember.deviceId,
      keyVersion: verifiedLocalMember.keyVersion,
      authGeneration: verifiedLocalMember.authGeneration,
      signingPublicKey: verifiedLocalMember.signingPublicKey,
      keyAgreementPublicKey: verifiedLocalMember.keyAgreementPublicKey,
    );
    final issuerMember = CloudSyncMembershipDeviceMaterial(
      deviceId: verifiedIssuerMember.deviceId,
      keyVersion: verifiedIssuerMember.keyVersion,
      authGeneration: verifiedIssuerMember.authGeneration,
      signingPublicKey: verifiedIssuerMember.signingPublicKey,
      keyAgreementPublicKey: verifiedIssuerMember.keyAgreementPublicKey,
    );
    return session.withSecurityBootstrap(
      CloudSyncSecurityBootstrap.pairing(
        state: state,
        localMember: localMember,
        issuerMember: issuerMember,
        receipt: receipt,
      ),
    );
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
