part of '../kelivo_secure_core.dart';

const _deviceUuidLength = native.KELIVO_DEVICE_UUID_SIZE;
const _devicePublicKeyLength = native.KELIVO_DEVICE_PUBLIC_KEY_SIZE;
const _devicePublicKeysLength = native.KELIVO_DEVICE_PUBLIC_KEYS_SIZE;
const _deviceChallengeLength = native.KELIVO_DEVICE_CHALLENGE_SIZE;
const _deviceProofLength = native.KELIVO_DEVICE_PROOF_SIZE;
const _accountKeyEnvelopeLength = native.KELIVO_ACCOUNT_KEY_ENVELOPE_SIZE;
const _pairingSecretLength = native.KELIVO_PAIRING_SECRET_SIZE;
const _pairingAuthenticatorLength = native.KELIVO_PAIRING_AUTHENTICATOR_SIZE;
const _pairingProtocolVersion = native.KELIVO_PAIRING_PROTOCOL_VERSION;
const _pendingPairingMaterialLength =
    native.KELIVO_PENDING_PAIRING_MATERIAL_SIZE;
const _registrationFinishBundleLength =
    native.KELIVO_REGISTRATION_FINISH_BUNDLE_SIZE;
const _pairingApprovalBundleLength = native.KELIVO_PAIRING_APPROVAL_BUNDLE_SIZE;
const _deviceStateBlobLength = native.KELIVO_DEVICE_STATE_BLOB_SIZE;
const _recordEntityKeyMaxLength = native.KELIVO_RECORD_ENTITY_KEY_MAX_SIZE;
const _accountTrustPublicKeyLength =
    native.KELIVO_ACCOUNT_TRUST_PUBLIC_KEY_SIZE;
const _accountTrustSignatureLength = native.KELIVO_ACCOUNT_TRUST_SIGNATURE_SIZE;
const _accountTrustPayloadMaxLength =
    native.KELIVO_ACCOUNT_TRUST_PAYLOAD_MAX_SIZE;
const _maxUint32 = 0xffffffff;

enum _DeviceHandlePhase { open, busy, closing, closed }

final class _DeviceHandleState {
  _DeviceHandleState(this.value);

  final int value;
  _DeviceHandlePhase phase = _DeviceHandlePhase.open;

  int beginUse() {
    if (phase != _DeviceHandlePhase.open) {
      throw StateError('设备安全句柄已占用、正在关闭或已经关闭');
    }
    phase = _DeviceHandlePhase.busy;
    return value;
  }

  void completeUse() {
    if (phase != _DeviceHandlePhase.busy) {
      throw StateError('设备安全句柄生命周期已失配');
    }
    phase = _DeviceHandlePhase.open;
  }

  int beginClose() {
    if (phase != _DeviceHandlePhase.open) {
      throw StateError('设备安全句柄已占用、正在关闭或已经关闭');
    }
    phase = _DeviceHandlePhase.closing;
    return value;
  }

  void completeClose() {
    phase = _DeviceHandlePhase.closed;
  }

  void cancelClose() {
    if (phase == _DeviceHandlePhase.closing) {
      phase = _DeviceHandlePhase.open;
    }
  }
}

final class KelivoDeviceIdentityHandle {
  KelivoDeviceIdentityHandle._(int value) : _state = _DeviceHandleState(value);

  final _DeviceHandleState _state;

  @override
  String toString() => 'KelivoDeviceIdentityHandle(opaque)';
}

final class KelivoAccountRootKeyHandle {
  KelivoAccountRootKeyHandle._(int value, Uint8List userId)
    : userId = _immutableDeviceBytes(userId),
      _state = _DeviceHandleState(value);

  final _DeviceHandleState _state;
  final Uint8List userId;

  @override
  String toString() => 'KelivoAccountRootKeyHandle(opaque)';
}

enum _PendingPairingPhase {
  unbound,
  binding,
  bound,
  accepting,
  closing,
  closed,
}

final class KelivoPendingPairingHandle {
  KelivoPendingPairingHandle._(this._value);

  final int _value;
  _PendingPairingPhase _phase = _PendingPairingPhase.unbound;
  _PendingPairingPhase? _phaseBeforeClose;
  Uint8List? _boundUserId;

  int _beginBind() {
    if (_phase != _PendingPairingPhase.unbound) {
      throw StateError('pending 配对必须处于未绑定状态');
    }
    _phase = _PendingPairingPhase.binding;
    return _value;
  }

  void _completeBind(Uint8List userId) {
    if (_phase != _PendingPairingPhase.binding) {
      throw StateError('pending 配对绑定生命周期已失配');
    }
    _boundUserId = _immutableDeviceBytes(userId);
    _phase = _PendingPairingPhase.bound;
  }

  void _cancelBind() {
    if (_phase == _PendingPairingPhase.binding) {
      _boundUserId = null;
      _phase = _PendingPairingPhase.unbound;
    }
  }

  (int, Uint8List) _beginAccept() {
    if (_phase != _PendingPairingPhase.bound) {
      throw StateError('pending 配对必须先绑定创建响应');
    }
    final userId = _boundUserId;
    if (userId == null) {
      throw StateError('pending 配对缺少账户绑定');
    }
    _phase = _PendingPairingPhase.accepting;
    return (_value, userId);
  }

  void _completeAccept() {
    _boundUserId = null;
    _phase = _PendingPairingPhase.closed;
  }

  void _cancelAccept() {
    if (_phase == _PendingPairingPhase.accepting) {
      _phase = _PendingPairingPhase.bound;
    }
  }

  int _beginClose() {
    if (_phase != _PendingPairingPhase.unbound &&
        _phase != _PendingPairingPhase.bound) {
      throw StateError('pending 配对正在操作或已经关闭');
    }
    _phaseBeforeClose = _phase;
    _phase = _PendingPairingPhase.closing;
    return _value;
  }

  void _completeClose() {
    _phaseBeforeClose = null;
    _boundUserId = null;
    _phase = _PendingPairingPhase.closed;
  }

  void _cancelClose() {
    if (_phase == _PendingPairingPhase.closing) {
      _phase = _phaseBeforeClose ?? _PendingPairingPhase.closed;
      _phaseBeforeClose = null;
    }
  }

  @override
  String toString() => 'KelivoPendingPairingHandle(opaque)';
}

final class KelivoDevicePublicKeys {
  factory KelivoDevicePublicKeys({
    required Uint8List signingPublicKey,
    required Uint8List keyAgreementPublicKey,
  }) {
    _requireLength(
      signingPublicKey,
      _devicePublicKeyLength,
      'signingPublicKey',
    );
    _requireLength(
      keyAgreementPublicKey,
      _devicePublicKeyLength,
      'keyAgreementPublicKey',
    );
    return KelivoDevicePublicKeys._(
      _immutableDeviceBytes(signingPublicKey),
      _immutableDeviceBytes(keyAgreementPublicKey),
    );
  }

  const KelivoDevicePublicKeys._(
    this.signingPublicKey,
    this.keyAgreementPublicKey,
  );

  final Uint8List signingPublicKey;
  final Uint8List keyAgreementPublicKey;
}

final class KelivoAccountRootKeyEnvelope {
  factory KelivoAccountRootKeyEnvelope(Uint8List bytes) {
    _requireLength(bytes, _accountKeyEnvelopeLength, 'bytes');
    return KelivoAccountRootKeyEnvelope._(_immutableDeviceBytes(bytes));
  }

  const KelivoAccountRootKeyEnvelope._(this.bytes);

  final Uint8List bytes;
}

final class KelivoAccountTrustPublicKey {
  // 私有构造器确保验签信任锚只能来自本机已认证 ARK，而不是服务器裸公钥。
  const KelivoAccountTrustPublicKey._(this.bytes);

  final Uint8List bytes;
}

final class KelivoUntrustedAccountTrustPublicKey {
  // 该类型只证明编码可参与严格验签，信任关系必须由上层签名链建立。
  factory KelivoUntrustedAccountTrustPublicKey.fromTransport(Uint8List bytes) {
    _requireLength(bytes, _accountTrustPublicKeyLength, 'bytes');
    return KelivoUntrustedAccountTrustPublicKey._(_immutableDeviceBytes(bytes));
  }

  const KelivoUntrustedAccountTrustPublicKey._(this.bytes);

  final Uint8List bytes;
}

final class KelivoAccountTrustSignature {
  factory KelivoAccountTrustSignature(Uint8List bytes) {
    _requireLength(bytes, _accountTrustSignatureLength, 'bytes');
    return KelivoAccountTrustSignature._(_immutableDeviceBytes(bytes));
  }

  const KelivoAccountTrustSignature._(this.bytes);

  final Uint8List bytes;
}

final class KelivoDeviceStateAccountBinding {
  factory KelivoDeviceStateAccountBinding({
    required Uint8List userId,
    required int keyEpoch,
  }) {
    _validateUuidV4(userId, 'userId');
    _validatePositiveUint32(keyEpoch, 'keyEpoch');
    return KelivoDeviceStateAccountBinding._(
      _immutableDeviceBytes(userId),
      keyEpoch,
    );
  }

  const KelivoDeviceStateAccountBinding._(this.userId, this.keyEpoch);

  final Uint8List userId;
  final int keyEpoch;
}

final class KelivoDeviceStateBinding {
  const KelivoDeviceStateBinding._({
    required this.deviceId,
    required this.keyVersion,
    required this.account,
  });

  final Uint8List deviceId;
  final int keyVersion;
  final KelivoDeviceStateAccountBinding? account;
}

final class KelivoDeviceRegistrationBundle {
  KelivoDeviceRegistrationBundle._(this.envelope, this.signature);

  final Uint8List envelope;
  final Uint8List signature;
}

final class KelivoPairingApprovalBundle {
  factory KelivoPairingApprovalBundle({
    required Uint8List envelope,
    required Uint8List signature,
    required Uint8List authenticator,
  }) {
    _requireLength(envelope, _accountKeyEnvelopeLength, 'envelope');
    _requireLength(signature, _deviceProofLength, 'signature');
    _requireLength(authenticator, _pairingAuthenticatorLength, 'authenticator');
    return KelivoPairingApprovalBundle._(
      _immutableDeviceBytes(envelope),
      _immutableDeviceBytes(signature),
      _immutableDeviceBytes(authenticator),
    );
  }

  const KelivoPairingApprovalBundle._(
    this.envelope,
    this.signature,
    this.authenticator,
  );

  final Uint8List envelope;
  final Uint8List signature;
  final Uint8List authenticator;
}

final class KelivoPendingPairingStart {
  KelivoPendingPairingStart._({
    required this.state,
    required this.pairingId,
    required this._pairingSecret,
    required this.pairingSecretHash,
  });

  final KelivoPendingPairingHandle state;
  final Uint8List pairingId;
  final Uint8List pairingSecretHash;
  Uint8List? _pairingSecret;

  /// 二维码编码器取得缓冲区所有权后必须在不再需要时主动清零。
  Uint8List takePairingSecret() {
    final secret = _pairingSecret;
    if (secret == null) {
      throw StateError('配对 secret 已经取出');
    }
    _pairingSecret = null;
    return secret;
  }

  void discardPairingSecret() {
    final secret = _pairingSecret;
    if (secret == null) return;
    secret.fillRange(0, secret.length, 0);
    _pairingSecret = null;
  }
}

final class KelivoAcceptedPairing {
  KelivoAcceptedPairing._({required this.ark, required this.stateBlob});

  final KelivoAccountRootKeyHandle ark;
  final Uint8List stateBlob;
}

final class KelivoOpenedDeviceState {
  KelivoOpenedDeviceState._({
    required this.binding,
    required this.identity,
    required this.ark,
  });

  final KelivoDeviceStateBinding binding;
  final KelivoDeviceIdentityHandle identity;
  final KelivoAccountRootKeyHandle? ark;
}

extension KelivoDeviceCore on KelivoSecureCore {
  Future<KelivoDeviceIdentityHandle> generateDeviceIdentity() async {
    final value = await Isolate.run(
      () => _generateDeviceHandle(
        operation: 'device_identity_generate',
        generate: native.kelivo_device_identity_generate,
      ),
    );
    return KelivoDeviceIdentityHandle._(value);
  }

  Future<KelivoDevicePublicKeys> readDevicePublicKeys(
    KelivoDeviceIdentityHandle identity,
  ) async {
    final value = identity._state.beginUse();
    try {
      final bytes = await Isolate.run(() => _readDevicePublicKeys(value));
      return KelivoDevicePublicKeys(
        signingPublicKey: Uint8List.sublistView(
          bytes,
          0,
          _devicePublicKeyLength,
        ),
        keyAgreementPublicKey: Uint8List.sublistView(
          bytes,
          _devicePublicKeyLength,
        ),
      );
    } finally {
      identity._state.completeUse();
    }
  }

  Future<void> validateDevicePublicKeys(
    Iterable<KelivoDevicePublicKeys> devicePublicKeys, {
    Iterable<Uint8List> additionalKeyAgreementPublicKeys = const [],
  }) async {
    final copiedDeviceKeys = <(Uint8List, Uint8List)>[
      for (final publicKeys in devicePublicKeys)
        (
          Uint8List.fromList(publicKeys.signingPublicKey),
          Uint8List.fromList(publicKeys.keyAgreementPublicKey),
        ),
    ];
    final copiedAgreementKeys = <Uint8List>[
      for (final publicKey in additionalKeyAgreementPublicKeys)
        Uint8List.fromList(publicKey),
    ];
    for (final publicKey in copiedAgreementKeys) {
      _requireLength(publicKey, _devicePublicKeyLength, 'publicKey');
    }
    await Isolate.run(
      () => _validateDevicePublicKeySet(copiedDeviceKeys, copiedAgreementKeys),
    );
  }

  Future<void> closeDeviceIdentity(KelivoDeviceIdentityHandle identity) =>
      _closeDeviceHandle(
        identity._state,
        operation: 'device_identity_handle_close',
        close: native.kelivo_device_identity_handle_close,
        invalidStatus: KelivoSecureCoreStatus.invalidDeviceIdentityHandle,
      );

  Future<KelivoAccountRootKeyHandle> generateAccountRootKey({
    required Uint8List userId,
    required int keyEpoch,
  }) async {
    _validateUuidV4(userId, 'userId');
    _validatePositiveUint32(keyEpoch, 'keyEpoch');
    final boundUserId = Uint8List.fromList(userId);
    final value = await Isolate.run(
      () => _generateAccountRootKey(Uint8List.fromList(boundUserId), keyEpoch),
    );
    return KelivoAccountRootKeyHandle._(value, boundUserId);
  }

  Future<void> closeAccountRootKey(KelivoAccountRootKeyHandle ark) =>
      _closeDeviceHandle(
        ark._state,
        operation: 'account_root_key_handle_close',
        close: native.kelivo_account_root_key_handle_close,
        invalidStatus: KelivoSecureCoreStatus.invalidAccountRootKeyHandle,
      );

  Future<void> addAccountRootKeyEpoch(
    KelivoAccountRootKeyHandle target, {
    required KelivoAccountRootKeyHandle source,
  }) async {
    _requireSameArkAccount(target, source.userId);
    final handles = _beginDeviceHandlePair(target._state, source._state);
    try {
      await Isolate.run(
        () => _throwOnError(
          operation: 'account_root_keyring_add_epoch',
          statusCode: native.kelivo_account_root_keyring_add_epoch(
            handles.$1,
            handles.$2,
          ),
        ),
      );
    } finally {
      _completeDeviceHandlePair(target._state, source._state);
    }
  }

  Future<void> pruneAccountRootKeyEpoch(
    KelivoAccountRootKeyHandle ark, {
    required int keyEpoch,
  }) async {
    _validatePositiveUint32(keyEpoch, 'keyEpoch');
    final value = ark._state.beginUse();
    try {
      await Isolate.run(
        () => _throwOnError(
          operation: 'account_root_keyring_prune_epoch',
          statusCode: native.kelivo_account_root_keyring_prune_epoch(
            value,
            keyEpoch,
          ),
        ),
      );
    } finally {
      ark._state.completeUse();
    }
  }

  Future<KelivoAccountTrustPublicKey> deriveAccountTrustPublicKey(
    KelivoAccountRootKeyHandle ark, {
    required Uint8List userId,
    required int keyEpoch,
  }) async {
    _validateUuidV4(userId, 'userId');
    _requireSameArkAccount(ark, userId);
    _validatePositiveUint32(keyEpoch, 'keyEpoch');
    final value = ark._state.beginUse();
    try {
      final publicKey = await Isolate.run(
        () => _deriveAccountTrustPublicKey(
          value,
          Uint8List.fromList(userId),
          keyEpoch,
        ),
      );
      return KelivoAccountTrustPublicKey._(_immutableDeviceBytes(publicKey));
    } finally {
      ark._state.completeUse();
    }
  }

  Future<KelivoAccountTrustSignature> signAccountTrustPayload(
    KelivoAccountRootKeyHandle ark, {
    required Uint8List userId,
    required int keyEpoch,
    required Uint8List canonicalPayload,
  }) async {
    _validateUuidV4(userId, 'userId');
    _requireSameArkAccount(ark, userId);
    _validatePositiveUint32(keyEpoch, 'keyEpoch');
    _validateAccountTrustPayload(canonicalPayload);
    final value = ark._state.beginUse();
    try {
      final signature = await Isolate.run(
        () => _signAccountTrustPayload(
          value,
          Uint8List.fromList(userId),
          keyEpoch,
          Uint8List.fromList(canonicalPayload),
        ),
      );
      return KelivoAccountTrustSignature(signature);
    } finally {
      ark._state.completeUse();
    }
  }

  Future<void> verifyAccountTrustPayload(
    KelivoAccountTrustPublicKey publicKey, {
    required Uint8List userId,
    required int keyEpoch,
    required Uint8List canonicalPayload,
    required KelivoAccountTrustSignature signature,
  }) async {
    _validateUuidV4(userId, 'userId');
    _validatePositiveUint32(keyEpoch, 'keyEpoch');
    _validateAccountTrustPayload(canonicalPayload);
    await Isolate.run(
      () => _verifyAccountTrustPayload(
        Uint8List.fromList(publicKey.bytes),
        Uint8List.fromList(userId),
        keyEpoch,
        Uint8List.fromList(canonicalPayload),
        Uint8List.fromList(signature.bytes),
      ),
    );
  }

  Future<void> verifyUntrustedAccountTrustPayload(
    KelivoUntrustedAccountTrustPublicKey publicKey, {
    required Uint8List userId,
    required int keyEpoch,
    required Uint8List canonicalPayload,
    required KelivoAccountTrustSignature signature,
  }) async {
    _validateUuidV4(userId, 'userId');
    _validatePositiveUint32(keyEpoch, 'keyEpoch');
    _validateAccountTrustPayload(canonicalPayload);
    await Isolate.run(
      () => _verifyAccountTrustPayload(
        Uint8List.fromList(publicKey.bytes),
        Uint8List.fromList(userId),
        keyEpoch,
        Uint8List.fromList(canonicalPayload),
        Uint8List.fromList(signature.bytes),
      ),
    );
  }

  Future<KelivoAccountRootKeyEnvelope> sealAccountRootKeyEnvelope(
    KelivoDeviceIdentityHandle issuerIdentity,
    KelivoAccountRootKeyHandle ark, {
    required Uint8List userId,
    required Uint8List issuerDeviceId,
    required Uint8List targetDeviceId,
    required int keyEpoch,
    required KelivoDevicePublicKeys targetPublicKeys,
  }) async {
    _validateUuidV4(userId, 'userId');
    _requireSameArkAccount(ark, userId);
    _validateUuidV4(issuerDeviceId, 'issuerDeviceId');
    _validateUuidV4(targetDeviceId, 'targetDeviceId');
    _validatePositiveUint32(keyEpoch, 'keyEpoch');
    final handles = _beginDeviceHandlePair(issuerIdentity._state, ark._state);
    try {
      final envelope = await Isolate.run(
        () => _sealAccountRootKeyEnvelope(
          handles.$1,
          handles.$2,
          Uint8List.fromList(userId),
          Uint8List.fromList(issuerDeviceId),
          Uint8List.fromList(targetDeviceId),
          keyEpoch,
          Uint8List.fromList(targetPublicKeys.signingPublicKey),
          Uint8List.fromList(targetPublicKeys.keyAgreementPublicKey),
        ),
      );
      return KelivoAccountRootKeyEnvelope(envelope);
    } finally {
      _completeDeviceHandlePair(issuerIdentity._state, ark._state);
    }
  }

  Future<KelivoAccountRootKeyHandle> openAccountRootKeyEnvelope(
    KelivoDeviceIdentityHandle targetIdentity, {
    required KelivoAccountRootKeyEnvelope envelope,
    required Uint8List userId,
    required Uint8List issuerDeviceId,
    required Uint8List targetDeviceId,
    required int keyEpoch,
    required KelivoDevicePublicKeys issuerPublicKeys,
    required KelivoDevicePublicKeys targetPublicKeys,
  }) async {
    _validateUuidV4(userId, 'userId');
    _validateUuidV4(issuerDeviceId, 'issuerDeviceId');
    _validateUuidV4(targetDeviceId, 'targetDeviceId');
    _validatePositiveUint32(keyEpoch, 'keyEpoch');
    final boundUserId = Uint8List.fromList(userId);
    final identityValue = targetIdentity._state.beginUse();
    try {
      final arkHandle = await Isolate.run(
        () => _openAccountRootKeyEnvelope(
          identityValue,
          Uint8List.fromList(envelope.bytes),
          Uint8List.fromList(boundUserId),
          Uint8List.fromList(issuerDeviceId),
          Uint8List.fromList(targetDeviceId),
          keyEpoch,
          Uint8List.fromList(issuerPublicKeys.signingPublicKey),
          Uint8List.fromList(issuerPublicKeys.keyAgreementPublicKey),
          Uint8List.fromList(targetPublicKeys.signingPublicKey),
          Uint8List.fromList(targetPublicKeys.keyAgreementPublicKey),
        ),
      );
      return KelivoAccountRootKeyHandle._(arkHandle, boundUserId);
    } finally {
      targetIdentity._state.completeUse();
    }
  }

  Future<Uint8List> deriveAccountRecordId(
    KelivoAccountRootKeyHandle ark, {
    required Uint8List canonicalEntityKey,
  }) async {
    if (canonicalEntityKey.isEmpty ||
        canonicalEntityKey.length > _recordEntityKeyMaxLength) {
      throw ArgumentError.value(
        canonicalEntityKey.length,
        'canonicalEntityKey',
        '规范实体键必须为 1 至 $_recordEntityKeyMaxLength 字节',
      );
    }

    final value = ark._state.beginUse();
    try {
      final recordId = await Isolate.run(
        () => _deriveAccountRecordId(
          value,
          Uint8List.fromList(canonicalEntityKey),
        ),
      );
      return _immutableDeviceBytes(recordId);
    } finally {
      ark._state.completeUse();
    }
  }

  Future<Uint8List> sealAccountRecord(
    KelivoAccountRootKeyHandle ark, {
    required Uint8List recordId,
    required int keyEpoch,
    required Uint8List associatedData,
    required Uint8List plaintext,
  }) async {
    _validatePositiveUint32(keyEpoch, 'keyEpoch');
    _validateRecordContext(
      recordId: recordId,
      epoch: keyEpoch,
      associatedData: associatedData,
    );
    if (plaintext.length > _recordMaxPlaintextSize) {
      throw ArgumentError.value(
        plaintext.length,
        'plaintext',
        '记录明文不得超过 $_recordMaxPlaintextSize 字节',
      );
    }

    final value = ark._state.beginUse();
    try {
      return await Isolate.run(
        () => _sealRecord(
          _RecordKeySource.accountRoot,
          value,
          Uint8List.fromList(recordId),
          keyEpoch,
          Uint8List.fromList(associatedData),
          Uint8List.fromList(plaintext),
        ),
      );
    } finally {
      ark._state.completeUse();
    }
  }

  Future<Uint8List> openAccountRecord(
    KelivoAccountRootKeyHandle ark, {
    required Uint8List recordId,
    required int keyEpoch,
    required Uint8List associatedData,
    required Uint8List envelope,
  }) async {
    _validatePositiveUint32(keyEpoch, 'keyEpoch');
    _validateRecordContext(
      recordId: recordId,
      epoch: keyEpoch,
      associatedData: associatedData,
    );
    if (envelope.length > _recordMaxEnvelopeSize) {
      throw ArgumentError.value(
        envelope.length,
        'envelope',
        '记录信封不得超过 $_recordMaxEnvelopeSize 字节',
      );
    }

    final value = ark._state.beginUse();
    try {
      return await Isolate.run(
        () => _openRecord(
          _RecordKeySource.accountRoot,
          value,
          Uint8List.fromList(recordId),
          keyEpoch,
          Uint8List.fromList(associatedData),
          Uint8List.fromList(envelope),
        ),
      );
    } finally {
      ark._state.completeUse();
    }
  }

  Future<Uint8List> signDeviceLoginProof(
    KelivoDeviceIdentityHandle identity, {
    required Uint8List attemptId,
    required Uint8List accountContextId,
    required Uint8List deviceId,
    required int expiresAtMs,
    required Uint8List challenge,
    required Uint8List credentialFinalization,
  }) async {
    _validateProofContext(
      attemptId: attemptId,
      accountContextId: accountContextId,
      deviceId: deviceId,
      expiresAtMs: expiresAtMs,
      challenge: challenge,
    );
    _requireLength(
      credentialFinalization,
      _opaqueCredentialFinalizationSize,
      'credentialFinalization',
    );
    final value = identity._state.beginUse();
    try {
      final copiedAttemptId = Uint8List.fromList(attemptId);
      final copiedAccountContextId = Uint8List.fromList(accountContextId);
      final copiedDeviceId = Uint8List.fromList(deviceId);
      final copiedChallenge = Uint8List.fromList(challenge);
      final copiedFinalization = Uint8List.fromList(credentialFinalization);
      final proof = await Isolate.run(
        () => _signDeviceLoginProof(
          value,
          copiedAttemptId,
          copiedAccountContextId,
          copiedDeviceId,
          expiresAtMs,
          copiedChallenge,
          copiedFinalization,
        ),
      );
      return _immutableDeviceBytes(proof);
    } finally {
      identity._state.completeUse();
    }
  }

  Future<KelivoDeviceRegistrationBundle> createDeviceRegistrationFinish(
    KelivoDeviceIdentityHandle identity,
    KelivoAccountRootKeyHandle ark, {
    required Uint8List userId,
    required Uint8List deviceId,
    required int keyEpoch,
    required Uint8List attemptId,
    required Uint8List accountContextId,
    required int expiresAtMs,
    required Uint8List challenge,
    required Uint8List registrationUpload,
  }) async {
    _validateUuidV4(userId, 'userId');
    _requireSameArkAccount(ark, userId);
    _validatePositiveUint32(keyEpoch, 'keyEpoch');
    _validateProofContext(
      attemptId: attemptId,
      accountContextId: accountContextId,
      deviceId: deviceId,
      expiresAtMs: expiresAtMs,
      challenge: challenge,
    );
    _requireLength(
      registrationUpload,
      _opaqueRegistrationUploadSize,
      'registrationUpload',
    );
    final handles = _beginDeviceHandlePair(identity._state, ark._state);
    try {
      final bundle = await Isolate.run(
        () => _createDeviceRegistrationFinish(
          handles.$1,
          handles.$2,
          Uint8List.fromList(userId),
          Uint8List.fromList(deviceId),
          keyEpoch,
          Uint8List.fromList(attemptId),
          Uint8List.fromList(accountContextId),
          expiresAtMs,
          Uint8List.fromList(challenge),
          Uint8List.fromList(registrationUpload),
        ),
      );
      return KelivoDeviceRegistrationBundle._(
        _immutableDeviceBytes(
          Uint8List.sublistView(bundle, 0, _accountKeyEnvelopeLength),
        ),
        _immutableDeviceBytes(
          Uint8List.sublistView(bundle, _accountKeyEnvelopeLength),
        ),
      );
    } finally {
      _completeDeviceHandlePair(identity._state, ark._state);
    }
  }

  Future<KelivoPendingPairingStart> startPendingPairing(
    KelivoDeviceIdentityHandle identity, {
    required Uint8List targetDeviceId,
    required int targetKeyVersion,
  }) async {
    _validateUuidV4(targetDeviceId, 'targetDeviceId');
    _validatePositiveUint32(targetKeyVersion, 'targetKeyVersion');
    final identityValue = identity._state.beginUse();
    try {
      final nativeResult = await Isolate.run(
        () => _startPendingPairing(
          identityValue,
          Uint8List.fromList(targetDeviceId),
          targetKeyVersion,
        ),
      );
      final secret = nativeResult.pairingSecret.materialize().asUint8List();
      return KelivoPendingPairingStart._(
        state: KelivoPendingPairingHandle._(nativeResult.handle),
        pairingId: _immutableDeviceBytes(nativeResult.pairingId),
        pairingSecret: secret,
        pairingSecretHash: _immutableDeviceBytes(
          nativeResult.pairingSecretHash,
        ),
      );
    } finally {
      identity._state.completeUse();
    }
  }

  Future<void> bindPendingPairing(
    KelivoPendingPairingHandle pending, {
    required Uint8List pairingId,
    required Uint8List userId,
    required Uint8List targetDeviceId,
    required int targetKeyVersion,
    required KelivoDevicePublicKeys targetPublicKeys,
    required int expiresAtMs,
    required Uint8List challenge,
    required int nowMs,
  }) async {
    _validateUuidV4(pairingId, 'pairingId');
    _validateUuidV4(userId, 'userId');
    _validateUuidV4(targetDeviceId, 'targetDeviceId');
    _validatePositiveUint32(targetKeyVersion, 'targetKeyVersion');
    _validateTimestamp(expiresAtMs, 'expiresAtMs');
    _validateTimestamp(nowMs, 'nowMs');
    _requireLength(challenge, _deviceChallengeLength, 'challenge');
    final boundUserId = Uint8List.fromList(userId);
    final pendingValue = pending._beginBind();
    try {
      await Isolate.run(
        () => _bindPendingPairing(
          pendingValue,
          Uint8List.fromList(pairingId),
          Uint8List.fromList(boundUserId),
          Uint8List.fromList(targetDeviceId),
          targetKeyVersion,
          Uint8List.fromList(targetPublicKeys.signingPublicKey),
          Uint8List.fromList(targetPublicKeys.keyAgreementPublicKey),
          expiresAtMs,
          Uint8List.fromList(challenge),
          nowMs,
        ),
      );
      pending._completeBind(boundUserId);
    } on KelivoSecureCoreException catch (error) {
      if (error.status == KelivoSecureCoreStatus.pairingExpired ||
          error.status == KelivoSecureCoreStatus.invalidPendingPairingHandle) {
        pending._completeClose();
      } else if (error.status ==
          KelivoSecureCoreStatus.pendingPairingStateInvalid) {
        // 本地与 Rust 状态若失配，继续猜测状态会让 secret 生命周期失去单一真相。
        native.kelivo_pending_pairing_handle_close(pendingValue);
        pending._completeClose();
      } else {
        pending._cancelBind();
      }
      rethrow;
    } catch (_) {
      // isolate 在原生调用后异常时无法证明 bind 是否已经生效，直接销毁更可审计。
      native.kelivo_pending_pairing_handle_close(pendingValue);
      pending._completeClose();
      rethrow;
    }
  }

  Future<void> cancelPendingPairing(KelivoPendingPairingHandle pending) async {
    final value = pending._beginClose();
    try {
      await Isolate.run(
        () => _throwOnError(
          operation: 'pending_pairing_handle_close',
          statusCode: native.kelivo_pending_pairing_handle_close(value),
        ),
      );
      pending._completeClose();
    } on KelivoSecureCoreException catch (error) {
      if (error.status == KelivoSecureCoreStatus.invalidPendingPairingHandle) {
        pending._completeClose();
      } else {
        pending._cancelClose();
      }
      rethrow;
    } catch (_) {
      pending._cancelClose();
      rethrow;
    }
  }

  Future<KelivoPairingApprovalBundle> createPairingApproval(
    KelivoDeviceIdentityHandle identity,
    KelivoAccountRootKeyHandle ark, {
    required Uint8List pairingId,
    required Uint8List userId,
    required Uint8List issuerDeviceId,
    required Uint8List targetDeviceId,
    required int expiresAtMs,
    required Uint8List challenge,
    required int keyEpoch,
    required KelivoDevicePublicKeys targetPublicKeys,
    required Uint8List pairingSecret,
  }) async {
    _validateUuidV4(pairingId, 'pairingId');
    _validateUuidV4(userId, 'userId');
    _requireSameArkAccount(ark, userId);
    _validateUuidV4(issuerDeviceId, 'issuerDeviceId');
    _validateUuidV4(targetDeviceId, 'targetDeviceId');
    _validateTimestamp(expiresAtMs, 'expiresAtMs');
    _requireLength(challenge, _deviceChallengeLength, 'challenge');
    _validatePositiveUint32(keyEpoch, 'keyEpoch');
    _requireLength(pairingSecret, _pairingSecretLength, 'pairingSecret');
    final handles = _beginDeviceHandlePair(identity._state, ark._state);
    try {
      final bundle = await _runWithTransferredDeviceSecret(
        pairingSecret,
        (workerSecret) => _createPairingApproval(
          handles.$1,
          handles.$2,
          Uint8List.fromList(pairingId),
          Uint8List.fromList(userId),
          Uint8List.fromList(issuerDeviceId),
          Uint8List.fromList(targetDeviceId),
          expiresAtMs,
          Uint8List.fromList(challenge),
          keyEpoch,
          Uint8List.fromList(targetPublicKeys.signingPublicKey),
          Uint8List.fromList(targetPublicKeys.keyAgreementPublicKey),
          workerSecret,
        ),
      );
      final signatureOffset = _accountKeyEnvelopeLength;
      final authenticatorOffset = signatureOffset + _deviceProofLength;
      return KelivoPairingApprovalBundle(
        envelope: Uint8List.sublistView(bundle, 0, signatureOffset),
        signature: Uint8List.sublistView(
          bundle,
          signatureOffset,
          authenticatorOffset,
        ),
        authenticator: Uint8List.sublistView(bundle, authenticatorOffset),
      );
    } finally {
      _completeDeviceHandlePair(identity._state, ark._state);
    }
  }

  Future<KelivoAcceptedPairing> acceptPairingApproval(
    KelivoKeyHandle key,
    KelivoDeviceIdentityHandle identity,
    KelivoPendingPairingHandle pending, {
    required int nowMs,
    required Uint8List issuerDeviceId,
    required int keyEpoch,
    required KelivoDevicePublicKeys issuerPublicKeys,
    required KelivoPairingApprovalBundle approval,
  }) async {
    _validateTimestamp(nowMs, 'nowMs');
    _validateUuidV4(issuerDeviceId, 'issuerDeviceId');
    _validatePositiveUint32(keyEpoch, 'keyEpoch');
    final keyValue = key._beginUse();
    int identityValue;
    try {
      identityValue = identity._state.beginUse();
    } catch (_) {
      key._completeUse();
      rethrow;
    }
    (int, Uint8List) pendingUse;
    try {
      pendingUse = pending._beginAccept();
    } catch (_) {
      identity._state.completeUse();
      key._completeUse();
      rethrow;
    }
    try {
      final result = await Isolate.run(
        () => _acceptPairingApproval(
          keyValue,
          identityValue,
          pendingUse.$1,
          nowMs,
          Uint8List.fromList(issuerDeviceId),
          keyEpoch,
          Uint8List.fromList(issuerPublicKeys.signingPublicKey),
          Uint8List.fromList(issuerPublicKeys.keyAgreementPublicKey),
          Uint8List.fromList(approval.signature),
          Uint8List.fromList(approval.authenticator),
          Uint8List.fromList(approval.envelope),
        ),
      );
      pending._completeAccept();
      return KelivoAcceptedPairing._(
        ark: KelivoAccountRootKeyHandle._(result.arkHandle, pendingUse.$2),
        stateBlob: _immutableDeviceBytes(result.stateBlob),
      );
    } on KelivoSecureCoreException catch (error) {
      if (error.status == KelivoSecureCoreStatus.pairingExpired ||
          error.status == KelivoSecureCoreStatus.invalidPendingPairingHandle) {
        pending._completeAccept();
      } else {
        pending._cancelAccept();
      }
      rethrow;
    } catch (_) {
      // 未知跨 isolate 故障可能发生在原生成功之后，不能把已消费句柄伪装成可重试。
      native.kelivo_pending_pairing_handle_close(pendingUse.$1);
      pending._completeAccept();
      rethrow;
    } finally {
      identity._state.completeUse();
      key._completeUse();
    }
  }

  Future<Uint8List> sealDeviceState(
    KelivoKeyHandle key,
    KelivoDeviceIdentityHandle identity, {
    required Uint8List deviceId,
    required int keyVersion,
    KelivoAccountRootKeyHandle? ark,
    KelivoDeviceStateAccountBinding? account,
  }) async {
    _validateUuidV4(deviceId, 'deviceId');
    _validatePositiveUint32(keyVersion, 'keyVersion');
    if ((ark == null) != (account == null)) {
      throw ArgumentError('ARK 与账户绑定必须同时提供或同时省略');
    }
    if (ark != null && account != null) {
      _requireSameArkAccount(ark, account.userId);
    }
    final keyValue = key._beginUse();
    int identityValue;
    try {
      identityValue = identity._state.beginUse();
    } catch (_) {
      key._completeUse();
      rethrow;
    }
    int? arkValue;
    try {
      arkValue = ark?._state.beginUse();
    } catch (_) {
      identity._state.completeUse();
      key._completeUse();
      rethrow;
    }
    try {
      final stateBlob = await Isolate.run(
        () => _sealDeviceState(
          keyValue,
          identityValue,
          arkValue ?? native.KELIVO_DEVICE_INVALID_HANDLE,
          Uint8List.fromList(deviceId),
          keyVersion,
          account == null ? null : Uint8List.fromList(account.userId),
          account?.keyEpoch ?? 0,
        ),
      );
      return _immutableDeviceBytes(stateBlob);
    } finally {
      if (ark != null) ark._state.completeUse();
      identity._state.completeUse();
      key._completeUse();
    }
  }

  Future<KelivoOpenedDeviceState> openDeviceState(
    KelivoKeyHandle key, {
    required Uint8List stateBlob,
  }) async {
    _requireLength(stateBlob, _deviceStateBlobLength, 'stateBlob');
    final keyValue = key._beginUse();
    try {
      final result = await Isolate.run(
        () => _openDeviceState(keyValue, Uint8List.fromList(stateBlob)),
      );
      return KelivoOpenedDeviceState._(
        binding: result.binding,
        identity: KelivoDeviceIdentityHandle._(result.identityHandle),
        ark: result.arkHandle == native.KELIVO_DEVICE_INVALID_HANDLE
            ? null
            : KelivoAccountRootKeyHandle._(
                result.arkHandle,
                result.binding.account!.userId,
              ),
      );
    } finally {
      key._completeUse();
    }
  }
}

typedef _NativeHandleGenerator =
    int Function(ffi.Pointer<ffi.Uint64> outHandle);
typedef _NativeHandleCloser = int Function(int handle);
typedef _FixedDeviceOutputCall =
    int Function(
      ffi.Pointer<ffi.Uint8> output,
      int capacity,
      ffi.Pointer<ffi.Size> outputLength,
    );

final class _PendingPairingStartNativeResult {
  const _PendingPairingStartNativeResult({
    required this.handle,
    required this.pairingId,
    required this.pairingSecret,
    required this.pairingSecretHash,
  });

  final int handle;
  final Uint8List pairingId;
  final TransferableTypedData pairingSecret;
  final Uint8List pairingSecretHash;
}

final class _AcceptedPairingNativeResult {
  const _AcceptedPairingNativeResult({
    required this.arkHandle,
    required this.stateBlob,
  });

  final int arkHandle;
  final Uint8List stateBlob;
}

final class _OpenedDeviceStateNativeResult {
  const _OpenedDeviceStateNativeResult({
    required this.binding,
    required this.identityHandle,
    required this.arkHandle,
  });

  final KelivoDeviceStateBinding binding;
  final int identityHandle;
  final int arkHandle;
}

Uint8List _immutableDeviceBytes(Uint8List bytes) =>
    Uint8List.fromList(bytes).asUnmodifiableView();

void _requireLength(Uint8List bytes, int expected, String name) {
  if (bytes.length != expected) {
    throw ArgumentError.value(bytes.length, name, '必须为 $expected 字节');
  }
}

void _validateUuidV4(Uint8List bytes, String name) {
  if (bytes.length != _deviceUuidLength ||
      bytes[6] & 0xf0 != 0x40 ||
      bytes[8] & 0xc0 != 0x80) {
    throw ArgumentError.value(
      bytes.length,
      name,
      '必须为 RFC 4122 UUIDv4 原始 16 字节',
    );
  }
}

void _requireSameArkAccount(
  KelivoAccountRootKeyHandle ark,
  Uint8List expectedUserId,
) {
  if (ark.userId.length != expectedUserId.length) {
    throw ArgumentError('ARK 句柄账户与调用账户不匹配');
  }
  var difference = 0;
  for (var index = 0; index < ark.userId.length; index++) {
    difference |= ark.userId[index] ^ expectedUserId[index];
  }
  if (difference != 0) {
    throw ArgumentError('ARK 句柄账户与调用账户不匹配');
  }
}

void _validatePositiveUint32(int value, String name) {
  if (value <= 0 || value > _maxUint32) {
    throw ArgumentError.value(value, name, '必须位于无符号 32 位正整数范围');
  }
}

void _validateAccountTrustPayload(Uint8List canonicalPayload) {
  if (canonicalPayload.isEmpty ||
      canonicalPayload.length > _accountTrustPayloadMaxLength) {
    throw ArgumentError.value(
      canonicalPayload.length,
      'canonicalPayload',
      '规范载荷必须为 1 至 $_accountTrustPayloadMaxLength 字节',
    );
  }
}

void _validateTimestamp(int value, String name) {
  if (value <= 0 || value > _recordMaxEpoch) {
    throw ArgumentError.value(value, name, '必须位于正 63 位整数范围');
  }
}

void _validateProofContext({
  required Uint8List attemptId,
  required Uint8List accountContextId,
  required Uint8List deviceId,
  required int expiresAtMs,
  required Uint8List challenge,
}) {
  _validateUuidV4(attemptId, 'attemptId');
  _validateUuidV4(accountContextId, 'accountContextId');
  _validateUuidV4(deviceId, 'deviceId');
  _validateTimestamp(expiresAtMs, 'expiresAtMs');
  _requireLength(challenge, _deviceChallengeLength, 'challenge');
}

(int, int) _beginDeviceHandlePair(
  _DeviceHandleState first,
  _DeviceHandleState second,
) {
  final firstValue = first.beginUse();
  try {
    return (firstValue, second.beginUse());
  } catch (_) {
    first.completeUse();
    rethrow;
  }
}

void _completeDeviceHandlePair(
  _DeviceHandleState first,
  _DeviceHandleState second,
) {
  second.completeUse();
  first.completeUse();
}

Future<void> _closeDeviceHandle(
  _DeviceHandleState state, {
  required String operation,
  required _NativeHandleCloser close,
  required KelivoSecureCoreStatus invalidStatus,
}) async {
  final value = state.beginClose();
  try {
    await Isolate.run(
      () => _throwOnError(operation: operation, statusCode: close(value)),
    );
    state.completeClose();
  } on KelivoSecureCoreException catch (error) {
    if (error.status == invalidStatus) {
      state.completeClose();
    } else {
      state.cancelClose();
    }
    rethrow;
  } catch (_) {
    state.cancelClose();
    rethrow;
  }
}

int _generateDeviceHandle({
  required String operation,
  required _NativeHandleGenerator generate,
}) {
  final output = calloc<ffi.Uint64>();
  try {
    _throwOnError(operation: operation, statusCode: generate(output));
    if (output.value == native.KELIVO_DEVICE_INVALID_HANDLE) {
      throw StateError('$operation 成功返回了无效句柄');
    }
    return output.value;
  } finally {
    calloc.free(output);
  }
}

int _generateAccountRootKey(Uint8List userId, int keyEpoch) {
  final userIdPointer = _copyToNative(userId);
  try {
    return _generateDeviceHandle(
      operation: 'account_root_key_generate',
      generate: (output) => native.kelivo_account_root_key_generate(
        userIdPointer,
        userId.length,
        keyEpoch,
        output,
      ),
    );
  } finally {
    _clearAndFree(userIdPointer, userId.length);
    userId.fillRange(0, userId.length, 0);
  }
}

Uint8List _fixedDeviceOutput({
  required String operation,
  required int expectedLength,
  required _FixedDeviceOutputCall call,
}) {
  final output = calloc<ffi.Uint8>(expectedLength);
  final outputLength = calloc<ffi.Size>();
  try {
    _throwOnError(
      operation: operation,
      statusCode: call(output, expectedLength, outputLength),
    );
    _requireExactOutputLength(
      operation: operation,
      expected: expectedLength,
      actual: outputLength.value,
    );
    return Uint8List.fromList(output.asTypedList(expectedLength));
  } finally {
    _clearAndFree(output, expectedLength);
    calloc.free(outputLength);
  }
}

Uint8List _readDevicePublicKeys(int identityHandle) => _fixedDeviceOutput(
  operation: 'device_identity_public_keys',
  expectedLength: _devicePublicKeysLength,
  call: (output, capacity, outputLength) =>
      native.kelivo_device_identity_public_keys(
        identityHandle,
        output,
        capacity,
        outputLength,
      ),
);

void _validateDeviceSigningPublicKey(Uint8List publicKey) {
  final pointer = _copyToNative(publicKey);
  try {
    _throwOnError(
      operation: 'device_signing_public_key_validate',
      statusCode: native.kelivo_device_signing_public_key_validate(
        pointer,
        publicKey.length,
      ),
    );
  } finally {
    _clearAndFree(pointer, publicKey.length);
    publicKey.fillRange(0, publicKey.length, 0);
  }
}

void _validateDeviceKeyAgreementPublicKey(Uint8List publicKey) {
  final pointer = _copyToNative(publicKey);
  try {
    _throwOnError(
      operation: 'device_key_agreement_public_key_validate',
      statusCode: native.kelivo_device_key_agreement_public_key_validate(
        pointer,
        publicKey.length,
      ),
    );
  } finally {
    _clearAndFree(pointer, publicKey.length);
    publicKey.fillRange(0, publicKey.length, 0);
  }
}

void _validateDevicePublicKeySet(
  List<(Uint8List, Uint8List)> devicePublicKeys,
  List<Uint8List> additionalKeyAgreementPublicKeys,
) {
  try {
    for (final publicKeys in devicePublicKeys) {
      _validateDeviceSigningPublicKey(publicKeys.$1);
      _validateDeviceKeyAgreementPublicKey(publicKeys.$2);
    }
    for (final publicKey in additionalKeyAgreementPublicKeys) {
      _validateDeviceKeyAgreementPublicKey(publicKey);
    }
  } finally {
    for (final publicKeys in devicePublicKeys) {
      publicKeys.$1.fillRange(0, publicKeys.$1.length, 0);
      publicKeys.$2.fillRange(0, publicKeys.$2.length, 0);
    }
    for (final publicKey in additionalKeyAgreementPublicKeys) {
      publicKey.fillRange(0, publicKey.length, 0);
    }
  }
}

Uint8List _deriveAccountRecordId(int arkHandle, Uint8List canonicalEntityKey) {
  final entityKeyPointer = _copyToNative(canonicalEntityKey);
  try {
    return _fixedDeviceOutput(
      operation: 'account_record_id_derive',
      expectedLength: _recordIdLength,
      call: (output, capacity, outputLength) =>
          native.kelivo_account_record_id_derive(
            arkHandle,
            entityKeyPointer,
            canonicalEntityKey.length,
            output,
            capacity,
            outputLength,
          ),
    );
  } finally {
    _clearAndFree(entityKeyPointer, canonicalEntityKey.length);
    canonicalEntityKey.fillRange(0, canonicalEntityKey.length, 0);
  }
}

Uint8List _deriveAccountTrustPublicKey(
  int arkHandle,
  Uint8List userId,
  int keyEpoch,
) {
  final userIdPointer = _copyToNative(userId);
  try {
    return _fixedDeviceOutput(
      operation: 'account_trust_public_key_derive',
      expectedLength: _accountTrustPublicKeyLength,
      call: (output, capacity, outputLength) =>
          native.kelivo_account_trust_public_key_derive(
            arkHandle,
            userIdPointer,
            userId.length,
            keyEpoch,
            output,
            capacity,
            outputLength,
          ),
    );
  } finally {
    _clearAndFree(userIdPointer, userId.length);
    userId.fillRange(0, userId.length, 0);
  }
}

Uint8List _signAccountTrustPayload(
  int arkHandle,
  Uint8List userId,
  int keyEpoch,
  Uint8List canonicalPayload,
) {
  final userIdPointer = _copyToNative(userId);
  final payloadPointer = _copyToNative(canonicalPayload);
  try {
    return _fixedDeviceOutput(
      operation: 'account_trust_payload_sign',
      expectedLength: _accountTrustSignatureLength,
      call: (output, capacity, outputLength) =>
          native.kelivo_account_trust_payload_sign(
            arkHandle,
            userIdPointer,
            userId.length,
            keyEpoch,
            payloadPointer,
            canonicalPayload.length,
            output,
            capacity,
            outputLength,
          ),
    );
  } finally {
    _clearAndFree(userIdPointer, userId.length);
    _clearAndFree(payloadPointer, canonicalPayload.length);
    userId.fillRange(0, userId.length, 0);
    canonicalPayload.fillRange(0, canonicalPayload.length, 0);
  }
}

void _verifyAccountTrustPayload(
  Uint8List publicKey,
  Uint8List userId,
  int keyEpoch,
  Uint8List canonicalPayload,
  Uint8List signature,
) {
  final publicKeyPointer = _copyToNative(publicKey);
  final userIdPointer = _copyToNative(userId);
  final payloadPointer = _copyToNative(canonicalPayload);
  final signaturePointer = _copyToNative(signature);
  try {
    _throwOnError(
      operation: 'account_trust_payload_verify',
      statusCode: native.kelivo_account_trust_payload_verify(
        publicKeyPointer,
        publicKey.length,
        userIdPointer,
        userId.length,
        keyEpoch,
        payloadPointer,
        canonicalPayload.length,
        signaturePointer,
        signature.length,
      ),
    );
  } finally {
    _clearAndFree(publicKeyPointer, publicKey.length);
    _clearAndFree(userIdPointer, userId.length);
    _clearAndFree(payloadPointer, canonicalPayload.length);
    _clearAndFree(signaturePointer, signature.length);
    publicKey.fillRange(0, publicKey.length, 0);
    userId.fillRange(0, userId.length, 0);
    canonicalPayload.fillRange(0, canonicalPayload.length, 0);
    signature.fillRange(0, signature.length, 0);
  }
}

Uint8List _sealAccountRootKeyEnvelope(
  int issuerIdentityHandle,
  int arkHandle,
  Uint8List userId,
  Uint8List issuerDeviceId,
  Uint8List targetDeviceId,
  int keyEpoch,
  Uint8List targetSigningPublicKey,
  Uint8List targetKeyAgreementPublicKey,
) {
  final userIdPointer = _copyToNative(userId);
  final issuerDeviceIdPointer = _copyToNative(issuerDeviceId);
  final targetDeviceIdPointer = _copyToNative(targetDeviceId);
  final targetSigningKeyPointer = _copyToNative(targetSigningPublicKey);
  final targetAgreementKeyPointer = _copyToNative(targetKeyAgreementPublicKey);
  try {
    return _fixedDeviceOutput(
      operation: 'account_root_key_envelope_seal',
      expectedLength: _accountKeyEnvelopeLength,
      call: (output, capacity, outputLength) =>
          native.kelivo_account_root_key_envelope_seal(
            issuerIdentityHandle,
            arkHandle,
            userIdPointer,
            userId.length,
            issuerDeviceIdPointer,
            issuerDeviceId.length,
            targetDeviceIdPointer,
            targetDeviceId.length,
            keyEpoch,
            targetSigningKeyPointer,
            targetSigningPublicKey.length,
            targetAgreementKeyPointer,
            targetKeyAgreementPublicKey.length,
            output,
            capacity,
            outputLength,
          ),
    );
  } finally {
    _clearAndFree(userIdPointer, userId.length);
    _clearAndFree(issuerDeviceIdPointer, issuerDeviceId.length);
    _clearAndFree(targetDeviceIdPointer, targetDeviceId.length);
    _clearAndFree(targetSigningKeyPointer, targetSigningPublicKey.length);
    _clearAndFree(
      targetAgreementKeyPointer,
      targetKeyAgreementPublicKey.length,
    );
    userId.fillRange(0, userId.length, 0);
    issuerDeviceId.fillRange(0, issuerDeviceId.length, 0);
    targetDeviceId.fillRange(0, targetDeviceId.length, 0);
    targetSigningPublicKey.fillRange(0, targetSigningPublicKey.length, 0);
    targetKeyAgreementPublicKey.fillRange(
      0,
      targetKeyAgreementPublicKey.length,
      0,
    );
  }
}

int _openAccountRootKeyEnvelope(
  int targetIdentityHandle,
  Uint8List envelope,
  Uint8List userId,
  Uint8List issuerDeviceId,
  Uint8List targetDeviceId,
  int keyEpoch,
  Uint8List issuerSigningPublicKey,
  Uint8List issuerKeyAgreementPublicKey,
  Uint8List targetSigningPublicKey,
  Uint8List targetKeyAgreementPublicKey,
) {
  final envelopePointer = _copyToNative(envelope);
  final userIdPointer = _copyToNative(userId);
  final issuerDeviceIdPointer = _copyToNative(issuerDeviceId);
  final targetDeviceIdPointer = _copyToNative(targetDeviceId);
  final issuerSigningKeyPointer = _copyToNative(issuerSigningPublicKey);
  final issuerAgreementKeyPointer = _copyToNative(issuerKeyAgreementPublicKey);
  final targetSigningKeyPointer = _copyToNative(targetSigningPublicKey);
  final targetAgreementKeyPointer = _copyToNative(targetKeyAgreementPublicKey);
  final outputHandle = calloc<ffi.Uint64>();
  var published = false;
  try {
    _throwOnError(
      operation: 'account_root_key_envelope_open',
      statusCode: native.kelivo_account_root_key_envelope_open(
        targetIdentityHandle,
        envelopePointer,
        envelope.length,
        userIdPointer,
        userId.length,
        issuerDeviceIdPointer,
        issuerDeviceId.length,
        targetDeviceIdPointer,
        targetDeviceId.length,
        keyEpoch,
        issuerSigningKeyPointer,
        issuerSigningPublicKey.length,
        issuerAgreementKeyPointer,
        issuerKeyAgreementPublicKey.length,
        targetSigningKeyPointer,
        targetSigningPublicKey.length,
        targetAgreementKeyPointer,
        targetKeyAgreementPublicKey.length,
        outputHandle,
      ),
    );
    if (outputHandle.value == native.KELIVO_DEVICE_INVALID_HANDLE) {
      throw StateError('account_root_key_envelope_open 成功返回了无效 ARK 句柄');
    }
    published = true;
    return outputHandle.value;
  } finally {
    if (!published &&
        outputHandle.value != native.KELIVO_DEVICE_INVALID_HANDLE) {
      native.kelivo_account_root_key_handle_close(outputHandle.value);
    }
    _clearAndFree(envelopePointer, envelope.length);
    _clearAndFree(userIdPointer, userId.length);
    _clearAndFree(issuerDeviceIdPointer, issuerDeviceId.length);
    _clearAndFree(targetDeviceIdPointer, targetDeviceId.length);
    _clearAndFree(issuerSigningKeyPointer, issuerSigningPublicKey.length);
    _clearAndFree(
      issuerAgreementKeyPointer,
      issuerKeyAgreementPublicKey.length,
    );
    _clearAndFree(targetSigningKeyPointer, targetSigningPublicKey.length);
    _clearAndFree(
      targetAgreementKeyPointer,
      targetKeyAgreementPublicKey.length,
    );
    envelope.fillRange(0, envelope.length, 0);
    userId.fillRange(0, userId.length, 0);
    issuerDeviceId.fillRange(0, issuerDeviceId.length, 0);
    targetDeviceId.fillRange(0, targetDeviceId.length, 0);
    issuerSigningPublicKey.fillRange(0, issuerSigningPublicKey.length, 0);
    issuerKeyAgreementPublicKey.fillRange(
      0,
      issuerKeyAgreementPublicKey.length,
      0,
    );
    targetSigningPublicKey.fillRange(0, targetSigningPublicKey.length, 0);
    targetKeyAgreementPublicKey.fillRange(
      0,
      targetKeyAgreementPublicKey.length,
      0,
    );
    calloc.free(outputHandle);
  }
}

Uint8List _signDeviceLoginProof(
  int identityHandle,
  Uint8List attemptId,
  Uint8List accountContextId,
  Uint8List deviceId,
  int expiresAtMs,
  Uint8List challenge,
  Uint8List credentialFinalization,
) {
  final attemptIdPointer = _copyToNative(attemptId);
  final accountContextPointer = _copyToNative(accountContextId);
  final deviceIdPointer = _copyToNative(deviceId);
  final challengePointer = _copyToNative(challenge);
  final finalizationPointer = _copyToNative(credentialFinalization);
  try {
    return _fixedDeviceOutput(
      operation: 'device_login_proof_sign',
      expectedLength: _deviceProofLength,
      call: (output, capacity, outputLength) =>
          native.kelivo_device_login_proof_sign(
            identityHandle,
            attemptIdPointer,
            attemptId.length,
            accountContextPointer,
            accountContextId.length,
            deviceIdPointer,
            deviceId.length,
            expiresAtMs,
            challengePointer,
            challenge.length,
            finalizationPointer,
            credentialFinalization.length,
            output,
            capacity,
            outputLength,
          ),
    );
  } finally {
    _clearAndFree(attemptIdPointer, attemptId.length);
    _clearAndFree(accountContextPointer, accountContextId.length);
    _clearAndFree(deviceIdPointer, deviceId.length);
    _clearAndFree(challengePointer, challenge.length);
    _clearAndFree(finalizationPointer, credentialFinalization.length);
    attemptId.fillRange(0, attemptId.length, 0);
    accountContextId.fillRange(0, accountContextId.length, 0);
    deviceId.fillRange(0, deviceId.length, 0);
    challenge.fillRange(0, challenge.length, 0);
    credentialFinalization.fillRange(0, credentialFinalization.length, 0);
  }
}

Uint8List _createDeviceRegistrationFinish(
  int identityHandle,
  int arkHandle,
  Uint8List userId,
  Uint8List deviceId,
  int keyEpoch,
  Uint8List attemptId,
  Uint8List accountContextId,
  int expiresAtMs,
  Uint8List challenge,
  Uint8List registrationUpload,
) {
  final userIdPointer = _copyToNative(userId);
  final deviceIdPointer = _copyToNative(deviceId);
  final attemptIdPointer = _copyToNative(attemptId);
  final accountContextPointer = _copyToNative(accountContextId);
  final challengePointer = _copyToNative(challenge);
  final uploadPointer = _copyToNative(registrationUpload);
  try {
    return _fixedDeviceOutput(
      operation: 'device_registration_finish_create',
      expectedLength: _registrationFinishBundleLength,
      call: (output, capacity, outputLength) =>
          native.kelivo_device_registration_finish_create(
            identityHandle,
            arkHandle,
            userIdPointer,
            userId.length,
            deviceIdPointer,
            deviceId.length,
            keyEpoch,
            attemptIdPointer,
            attemptId.length,
            accountContextPointer,
            accountContextId.length,
            expiresAtMs,
            challengePointer,
            challenge.length,
            uploadPointer,
            registrationUpload.length,
            output,
            capacity,
            outputLength,
          ),
    );
  } finally {
    _clearAndFree(userIdPointer, userId.length);
    _clearAndFree(deviceIdPointer, deviceId.length);
    _clearAndFree(attemptIdPointer, attemptId.length);
    _clearAndFree(accountContextPointer, accountContextId.length);
    _clearAndFree(challengePointer, challenge.length);
    _clearAndFree(uploadPointer, registrationUpload.length);
    userId.fillRange(0, userId.length, 0);
    deviceId.fillRange(0, deviceId.length, 0);
    attemptId.fillRange(0, attemptId.length, 0);
    accountContextId.fillRange(0, accountContextId.length, 0);
    challenge.fillRange(0, challenge.length, 0);
    registrationUpload.fillRange(0, registrationUpload.length, 0);
  }
}

_PendingPairingStartNativeResult _startPendingPairing(
  int identityHandle,
  Uint8List targetDeviceId,
  int targetKeyVersion,
) {
  final targetDeviceIdPointer = _copyToNative(targetDeviceId);
  final outputHandle = calloc<ffi.Uint64>();
  final output = calloc<ffi.Uint8>(_pendingPairingMaterialLength);
  final outputLength = calloc<ffi.Size>();
  var published = false;
  try {
    _throwOnError(
      operation: 'pending_pairing_start',
      statusCode: native.kelivo_pending_pairing_start(
        identityHandle,
        targetDeviceIdPointer,
        targetDeviceId.length,
        targetKeyVersion,
        outputHandle,
        output,
        _pendingPairingMaterialLength,
        outputLength,
      ),
    );
    _requireExactOutputLength(
      operation: 'pending_pairing_start',
      expected: _pendingPairingMaterialLength,
      actual: outputLength.value,
    );
    if (outputHandle.value == native.KELIVO_DEVICE_INVALID_HANDLE) {
      throw StateError('pending_pairing_start 成功返回了无效句柄');
    }
    final material = output.asTypedList(_pendingPairingMaterialLength);
    final pairingId = Uint8List.fromList(
      Uint8List.sublistView(material, 0, _deviceUuidLength),
    );
    final secret = Uint8List.fromList(
      Uint8List.sublistView(
        material,
        _deviceUuidLength,
        _deviceUuidLength + _pairingSecretLength,
      ),
    );
    final secretHash = Uint8List.fromList(
      Uint8List.sublistView(material, _deviceUuidLength + _pairingSecretLength),
    );
    final transferableSecret = TransferableTypedData.fromList([secret]);
    secret.fillRange(0, secret.length, 0);
    published = true;
    return _PendingPairingStartNativeResult(
      handle: outputHandle.value,
      pairingId: pairingId,
      pairingSecret: transferableSecret,
      pairingSecretHash: secretHash,
    );
  } finally {
    if (!published &&
        outputHandle.value != native.KELIVO_DEVICE_INVALID_HANDLE) {
      native.kelivo_pending_pairing_handle_close(outputHandle.value);
    }
    _clearAndFree(targetDeviceIdPointer, targetDeviceId.length);
    _clearAndFree(output, _pendingPairingMaterialLength);
    targetDeviceId.fillRange(0, targetDeviceId.length, 0);
    calloc.free(outputHandle);
    calloc.free(outputLength);
  }
}

void _bindPendingPairing(
  int pendingHandle,
  Uint8List pairingId,
  Uint8List userId,
  Uint8List targetDeviceId,
  int targetKeyVersion,
  Uint8List targetSigningPublicKey,
  Uint8List targetKeyAgreementPublicKey,
  int expiresAtMs,
  Uint8List challenge,
  int nowMs,
) {
  final pairingIdPointer = _copyToNative(pairingId);
  final userIdPointer = _copyToNative(userId);
  final targetDeviceIdPointer = _copyToNative(targetDeviceId);
  final signingKeyPointer = _copyToNative(targetSigningPublicKey);
  final agreementKeyPointer = _copyToNative(targetKeyAgreementPublicKey);
  final challengePointer = _copyToNative(challenge);
  try {
    _throwOnError(
      operation: 'pending_pairing_bind',
      statusCode: native.kelivo_pending_pairing_bind(
        pendingHandle,
        _pairingProtocolVersion,
        pairingIdPointer,
        pairingId.length,
        userIdPointer,
        userId.length,
        targetDeviceIdPointer,
        targetDeviceId.length,
        targetKeyVersion,
        signingKeyPointer,
        targetSigningPublicKey.length,
        agreementKeyPointer,
        targetKeyAgreementPublicKey.length,
        expiresAtMs,
        challengePointer,
        challenge.length,
        nowMs,
      ),
    );
  } finally {
    _clearAndFree(pairingIdPointer, pairingId.length);
    _clearAndFree(userIdPointer, userId.length);
    _clearAndFree(targetDeviceIdPointer, targetDeviceId.length);
    _clearAndFree(signingKeyPointer, targetSigningPublicKey.length);
    _clearAndFree(agreementKeyPointer, targetKeyAgreementPublicKey.length);
    _clearAndFree(challengePointer, challenge.length);
    pairingId.fillRange(0, pairingId.length, 0);
    userId.fillRange(0, userId.length, 0);
    targetDeviceId.fillRange(0, targetDeviceId.length, 0);
    targetSigningPublicKey.fillRange(0, targetSigningPublicKey.length, 0);
    targetKeyAgreementPublicKey.fillRange(
      0,
      targetKeyAgreementPublicKey.length,
      0,
    );
    challenge.fillRange(0, challenge.length, 0);
  }
}

Future<T> _runWithTransferredDeviceSecret<T>(
  Uint8List secret,
  T Function(Uint8List workerSecret) operation,
) async {
  final temporary = Uint8List.fromList(secret);
  final transferred = TransferableTypedData.fromList([temporary]);
  temporary.fillRange(0, temporary.length, 0);
  try {
    return await Isolate.run(() {
      final workerSecret = transferred.materialize().asUint8List();
      try {
        return operation(workerSecret);
      } finally {
        workerSecret.fillRange(0, workerSecret.length, 0);
      }
    });
  } catch (error, stackTrace) {
    try {
      final unsent = transferred.materialize().asUint8List();
      unsent.fillRange(0, unsent.length, 0);
    } on ArgumentError {
      // 已发送时由工作 isolate 的 finally 清零唯一缓冲区。
    } on StateError {
      // 已发送时由工作 isolate 的 finally 清零唯一缓冲区。
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}

Uint8List _createPairingApproval(
  int identityHandle,
  int arkHandle,
  Uint8List pairingId,
  Uint8List userId,
  Uint8List issuerDeviceId,
  Uint8List targetDeviceId,
  int expiresAtMs,
  Uint8List challenge,
  int keyEpoch,
  Uint8List targetSigningPublicKey,
  Uint8List targetKeyAgreementPublicKey,
  Uint8List pairingSecret,
) {
  final pairingIdPointer = _copyToNative(pairingId);
  final userIdPointer = _copyToNative(userId);
  final issuerDeviceIdPointer = _copyToNative(issuerDeviceId);
  final targetDeviceIdPointer = _copyToNative(targetDeviceId);
  final challengePointer = _copyToNative(challenge);
  final signingKeyPointer = _copyToNative(targetSigningPublicKey);
  final agreementKeyPointer = _copyToNative(targetKeyAgreementPublicKey);
  final secretPointer = _copyToNative(pairingSecret);
  try {
    return _fixedDeviceOutput(
      operation: 'device_pairing_approval_create',
      expectedLength: _pairingApprovalBundleLength,
      call: (output, capacity, outputLength) =>
          native.kelivo_device_pairing_approval_create(
            identityHandle,
            arkHandle,
            pairingIdPointer,
            pairingId.length,
            userIdPointer,
            userId.length,
            issuerDeviceIdPointer,
            issuerDeviceId.length,
            targetDeviceIdPointer,
            targetDeviceId.length,
            expiresAtMs,
            challengePointer,
            challenge.length,
            keyEpoch,
            signingKeyPointer,
            targetSigningPublicKey.length,
            agreementKeyPointer,
            targetKeyAgreementPublicKey.length,
            secretPointer,
            pairingSecret.length,
            output,
            capacity,
            outputLength,
          ),
    );
  } finally {
    _clearAndFree(pairingIdPointer, pairingId.length);
    _clearAndFree(userIdPointer, userId.length);
    _clearAndFree(issuerDeviceIdPointer, issuerDeviceId.length);
    _clearAndFree(targetDeviceIdPointer, targetDeviceId.length);
    _clearAndFree(challengePointer, challenge.length);
    _clearAndFree(signingKeyPointer, targetSigningPublicKey.length);
    _clearAndFree(agreementKeyPointer, targetKeyAgreementPublicKey.length);
    _clearAndFree(secretPointer, pairingSecret.length);
    pairingId.fillRange(0, pairingId.length, 0);
    userId.fillRange(0, userId.length, 0);
    issuerDeviceId.fillRange(0, issuerDeviceId.length, 0);
    targetDeviceId.fillRange(0, targetDeviceId.length, 0);
    challenge.fillRange(0, challenge.length, 0);
    targetSigningPublicKey.fillRange(0, targetSigningPublicKey.length, 0);
    targetKeyAgreementPublicKey.fillRange(
      0,
      targetKeyAgreementPublicKey.length,
      0,
    );
    pairingSecret.fillRange(0, pairingSecret.length, 0);
  }
}

_AcceptedPairingNativeResult _acceptPairingApproval(
  int keyHandle,
  int identityHandle,
  int pendingHandle,
  int nowMs,
  Uint8List issuerDeviceId,
  int keyEpoch,
  Uint8List issuerSigningPublicKey,
  Uint8List issuerKeyAgreementPublicKey,
  Uint8List signature,
  Uint8List authenticator,
  Uint8List envelope,
) {
  final issuerDeviceIdPointer = _copyToNative(issuerDeviceId);
  final signingKeyPointer = _copyToNative(issuerSigningPublicKey);
  final agreementKeyPointer = _copyToNative(issuerKeyAgreementPublicKey);
  final signaturePointer = _copyToNative(signature);
  final authenticatorPointer = _copyToNative(authenticator);
  final envelopePointer = _copyToNative(envelope);
  final outputHandle = calloc<ffi.Uint64>();
  final output = calloc<ffi.Uint8>(_deviceStateBlobLength);
  final outputLength = calloc<ffi.Size>();
  var published = false;
  try {
    _throwOnError(
      operation: 'device_pairing_approval_accept',
      statusCode: native.kelivo_device_pairing_approval_accept(
        keyHandle,
        identityHandle,
        pendingHandle,
        nowMs,
        issuerDeviceIdPointer,
        issuerDeviceId.length,
        keyEpoch,
        signingKeyPointer,
        issuerSigningPublicKey.length,
        agreementKeyPointer,
        issuerKeyAgreementPublicKey.length,
        signaturePointer,
        signature.length,
        authenticatorPointer,
        authenticator.length,
        envelopePointer,
        envelope.length,
        outputHandle,
        output,
        _deviceStateBlobLength,
        outputLength,
      ),
    );
    _requireExactOutputLength(
      operation: 'device_pairing_approval_accept',
      expected: _deviceStateBlobLength,
      actual: outputLength.value,
    );
    if (outputHandle.value == native.KELIVO_DEVICE_INVALID_HANDLE) {
      throw StateError('device_pairing_approval_accept 成功返回了无效 ARK 句柄');
    }
    published = true;
    return _AcceptedPairingNativeResult(
      arkHandle: outputHandle.value,
      stateBlob: Uint8List.fromList(output.asTypedList(_deviceStateBlobLength)),
    );
  } finally {
    if (!published &&
        outputHandle.value != native.KELIVO_DEVICE_INVALID_HANDLE) {
      native.kelivo_account_root_key_handle_close(outputHandle.value);
    }
    _clearAndFree(issuerDeviceIdPointer, issuerDeviceId.length);
    _clearAndFree(signingKeyPointer, issuerSigningPublicKey.length);
    _clearAndFree(agreementKeyPointer, issuerKeyAgreementPublicKey.length);
    _clearAndFree(signaturePointer, signature.length);
    _clearAndFree(authenticatorPointer, authenticator.length);
    _clearAndFree(envelopePointer, envelope.length);
    _clearAndFree(output, _deviceStateBlobLength);
    issuerDeviceId.fillRange(0, issuerDeviceId.length, 0);
    issuerSigningPublicKey.fillRange(0, issuerSigningPublicKey.length, 0);
    issuerKeyAgreementPublicKey.fillRange(
      0,
      issuerKeyAgreementPublicKey.length,
      0,
    );
    signature.fillRange(0, signature.length, 0);
    authenticator.fillRange(0, authenticator.length, 0);
    envelope.fillRange(0, envelope.length, 0);
    calloc.free(outputHandle);
    calloc.free(outputLength);
  }
}

Uint8List _sealDeviceState(
  int keyHandle,
  int identityHandle,
  int arkHandle,
  Uint8List deviceId,
  int keyVersion,
  Uint8List? userId,
  int keyEpoch,
) {
  final deviceIdPointer = _copyToNative(deviceId);
  final userIdPointer = userId == null
      ? ffi.nullptr.cast<ffi.Uint8>()
      : _copyToNative(userId);
  try {
    return _fixedDeviceOutput(
      operation: 'device_state_seal',
      expectedLength: _deviceStateBlobLength,
      call: (output, capacity, outputLength) => native.kelivo_device_state_seal(
        keyHandle,
        identityHandle,
        arkHandle,
        deviceIdPointer,
        deviceId.length,
        keyVersion,
        userIdPointer,
        userId?.length ?? 0,
        keyEpoch,
        output,
        capacity,
        outputLength,
      ),
    );
  } finally {
    _clearAndFree(deviceIdPointer, deviceId.length);
    if (userId != null) {
      _clearAndFree(userIdPointer, userId.length);
      userId.fillRange(0, userId.length, 0);
    }
    deviceId.fillRange(0, deviceId.length, 0);
  }
}

_OpenedDeviceStateNativeResult _openDeviceState(
  int keyHandle,
  Uint8List stateBlob,
) {
  final blobPointer = _copyToNative(stateBlob);
  final binding = calloc<native.KelivoDeviceStateBinding>();
  final identityHandle = calloc<ffi.Uint64>();
  final arkHandle = calloc<ffi.Uint64>();
  var published = false;
  try {
    _throwOnError(
      operation: 'device_state_open',
      statusCode: native.kelivo_device_state_open(
        keyHandle,
        blobPointer,
        stateBlob.length,
        binding,
        identityHandle,
        arkHandle,
      ),
    );
    if (identityHandle.value == native.KELIVO_DEVICE_INVALID_HANDLE) {
      throw StateError('device_state_open 成功返回了无效设备身份句柄');
    }
    final openedBinding = _readAuthenticatedDeviceStateBinding(
      binding.ref,
      arkHandle: arkHandle.value,
    );
    published = true;
    return _OpenedDeviceStateNativeResult(
      binding: openedBinding,
      identityHandle: identityHandle.value,
      arkHandle: arkHandle.value,
    );
  } finally {
    if (!published) {
      if (identityHandle.value != native.KELIVO_DEVICE_INVALID_HANDLE) {
        native.kelivo_device_identity_handle_close(identityHandle.value);
      }
      if (arkHandle.value != native.KELIVO_DEVICE_INVALID_HANDLE) {
        native.kelivo_account_root_key_handle_close(arkHandle.value);
      }
    }
    _clearAndFree(blobPointer, stateBlob.length);
    _clearAndFree(
      binding.cast<ffi.Uint8>(),
      ffi.sizeOf<native.KelivoDeviceStateBinding>(),
    );
    stateBlob.fillRange(0, stateBlob.length, 0);
    calloc.free(identityHandle);
    calloc.free(arkHandle);
  }
}

KelivoDeviceStateBinding _readAuthenticatedDeviceStateBinding(
  native.KelivoDeviceStateBinding value, {
  required int arkHandle,
}) {
  if (value.struct_size != native.KELIVO_DEVICE_STATE_BINDING_STRUCT_SIZE) {
    throw StateError('device_state_open 成功返回了未知绑定结构');
  }
  const accountFlag = native.KELIVO_DEVICE_STATE_BINDING_FLAG_ACCOUNT;
  if ((value.flags & ~accountFlag) != 0) {
    throw StateError('device_state_open 成功返回了未知绑定标志');
  }
  final deviceId = _copyNativeByteArray(value.device_id, _deviceUuidLength);
  _validateUuidV4(deviceId, 'deviceId');
  _validatePositiveUint32(value.key_version, 'keyVersion');
  final hasAccount = (value.flags & accountFlag) != 0;
  final userId = _copyNativeByteArray(value.user_id, _deviceUuidLength);
  final account = hasAccount
      ? KelivoDeviceStateAccountBinding(
          userId: userId,
          keyEpoch: value.key_epoch,
        )
      : null;
  if (hasAccount != (arkHandle != native.KELIVO_DEVICE_INVALID_HANDLE)) {
    throw StateError('device_state_open 成功返回了失配的账户句柄');
  }
  if (!hasAccount &&
      (value.key_epoch != 0 || userId.any((byte) => byte != 0))) {
    throw StateError('device_state_open 成功返回了非规范空账户绑定');
  }
  return KelivoDeviceStateBinding._(
    deviceId: _immutableDeviceBytes(deviceId),
    keyVersion: value.key_version,
    account: account,
  );
}

Uint8List _copyNativeByteArray(ffi.Array<ffi.Uint8> source, int length) {
  final bytes = Uint8List(length);
  for (var index = 0; index < length; index++) {
    bytes[index] = source[index];
  }
  return bytes;
}
