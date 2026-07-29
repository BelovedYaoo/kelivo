part of '../kelivo_secure_core.dart';

const _recoveryPublicKeyLength = native.KELIVO_RECOVERY_PUBLIC_KEY_SIZE;
const _recoveryCapsuleLength = native.KELIVO_RECOVERY_CAPSULE_SIZE;
const _recoveryMediaLength = native.KELIVO_RECOVERY_MEDIA_SIZE;
const _recoveryGenesisLength = native.KELIVO_RECOVERY_GENESIS_SIZE;
const _recoveryOriginDigestLength =
    native.KELIVO_RECOVERY_SERVICE_ORIGIN_SHA256_SIZE;
const _recoveryPassphraseMinimumScalars = 12;
const _recoveryPassphraseMaximumUtf8Length = 128;
const _recoveryHistoryMaximumEntries = 4096;
const _recoveryManifestMinimumLength = 444;
const _recoveryManifestMaximumLength = 228 + 256 * 88 + 128;

final class KelivoRecoveryHandle {
  KelivoRecoveryHandle._(
    int value, {
    required Uint8List userId,
    required this.recoveryPublicKeyVersion,
  }) : userId = _immutableDeviceBytes(userId),
       _state = _DeviceHandleState(value);

  final _DeviceHandleState _state;
  final Uint8List userId;
  final int recoveryPublicKeyVersion;

  @override
  String toString() => 'KelivoRecoveryHandle(opaque)';
}

final class KelivoRecoveryIdentity {
  KelivoRecoveryIdentity._({required this.handle, required Uint8List publicKey})
    : publicKey = _immutableDeviceBytes(publicKey);

  final KelivoRecoveryHandle handle;
  final Uint8List publicKey;
}

final class KelivoRecoveryCapsuleOpen {
  const KelivoRecoveryCapsuleOpen._({
    required this.ark,
    required this.keyEpoch,
    required this.capsuleVersion,
  });

  final KelivoAccountRootKeyHandle ark;
  final int keyEpoch;
  final int capsuleVersion;
}

extension KelivoRecoveryCore on KelivoSecureCore {
  Future<KelivoRecoveryIdentity> generateRecoveryIdentity({
    required Uint8List userId,
    int recoveryPublicKeyVersion = 1,
  }) async {
    _validateUuidV4(userId, 'userId');
    _validatePositiveUint32(
      recoveryPublicKeyVersion,
      'recoveryPublicKeyVersion',
    );
    final boundUserId = Uint8List.fromList(userId);
    final result = await Isolate.run(
      () => _generateRecoveryIdentity(
        Uint8List.fromList(boundUserId),
        recoveryPublicKeyVersion,
      ),
    );
    return KelivoRecoveryIdentity._(
      handle: KelivoRecoveryHandle._(
        result.handle,
        userId: boundUserId,
        recoveryPublicKeyVersion: recoveryPublicKeyVersion,
      ),
      publicKey: result.publicKey,
    );
  }

  Future<void> closeRecovery(KelivoRecoveryHandle recovery) =>
      _closeDeviceHandle(
        recovery._state,
        operation: 'recovery_handle_close',
        close: native.kelivo_recovery_handle_close,
        invalidStatus: KelivoSecureCoreStatus.invalidRecoveryHandle,
      );

  Future<Uint8List> sealRecoveryCapsule(
    KelivoAccountRootKeyHandle ark, {
    required int keyEpoch,
    required Uint8List recoveryPublicKey,
    required int recoveryPublicKeyVersion,
    required int capsuleVersion,
  }) async {
    _validatePositiveUint32(keyEpoch, 'keyEpoch');
    _validatePositiveUint32(
      recoveryPublicKeyVersion,
      'recoveryPublicKeyVersion',
    );
    _validatePositiveUint32(capsuleVersion, 'capsuleVersion');
    _requireLength(
      recoveryPublicKey,
      _recoveryPublicKeyLength,
      'recoveryPublicKey',
    );
    final arkValue = ark._state.beginUse();
    try {
      return await Isolate.run(
        () => _sealRecoveryCapsule(
          arkValue,
          Uint8List.fromList(ark.userId),
          keyEpoch,
          recoveryPublicKeyVersion,
          capsuleVersion,
          Uint8List.fromList(recoveryPublicKey),
        ),
      );
    } finally {
      ark._state.completeUse();
    }
  }

  Future<Uint8List> exportRecoveryMedia(
    KelivoRecoveryHandle recovery,
    KelivoAccountRootKeyHandle initialArk, {
    required Uint8List initialCapsule,
    required Uint8List genesisManifest,
    required Uint8List passphrase,
    required Uint8List serviceOriginSha256,
  }) async {
    try {
      _requireLength(initialCapsule, _recoveryCapsuleLength, 'initialCapsule');
      _requireLength(
        genesisManifest,
        _recoveryGenesisLength,
        'genesisManifest',
      );
      _validateRecoveryPassphrase(passphrase);
      _requireLength(
        serviceOriginSha256,
        _recoveryOriginDigestLength,
        'serviceOriginSha256',
      );
      _requireSameRecoveryAccount(recovery.userId, initialArk.userId);
      final handles = _beginDeviceHandlePair(
        recovery._state,
        initialArk._state,
      );
      try {
        return await _runWithTransferredPassword(
          passphrase,
          (workerPassphrase) => _exportRecoveryMedia(
            handles.$1,
            handles.$2,
            Uint8List.fromList(initialCapsule),
            Uint8List.fromList(genesisManifest),
            workerPassphrase,
            Uint8List.fromList(serviceOriginSha256),
          ),
        );
      } finally {
        _completeDeviceHandlePair(recovery._state, initialArk._state);
      }
    } finally {
      passphrase.fillRange(0, passphrase.length, 0);
    }
  }

  Future<KelivoRecoveryCapsuleOpen> recoverAccountRootKey({
    required Uint8List media,
    required Uint8List passphrase,
    required Uint8List serviceOriginSha256,
    required List<Uint8List> membershipHistory,
    required Uint8List currentCapsule,
    Uint8List? sourceCapsule,
  }) async {
    try {
      _requireLength(media, _recoveryMediaLength, 'media');
      _validateRecoveryPassphrase(passphrase);
      _requireLength(
        serviceOriginSha256,
        _recoveryOriginDigestLength,
        'serviceOriginSha256',
      );
      _requireLength(currentCapsule, _recoveryCapsuleLength, 'currentCapsule');
      if (sourceCapsule != null) {
        _requireLength(sourceCapsule, _recoveryCapsuleLength, 'sourceCapsule');
      }
      final history = _copyRecoveryHistory(membershipHistory);
      final result = await _runWithTransferredPassword(
        passphrase,
        (workerPassphrase) => _recoverAccountRootKey(
          Uint8List.fromList(media),
          workerPassphrase,
          Uint8List.fromList(serviceOriginSha256),
          history,
          sourceCapsule == null ? null : Uint8List.fromList(sourceCapsule),
          Uint8List.fromList(currentCapsule),
        ),
      );
      return KelivoRecoveryCapsuleOpen._(
        ark: KelivoAccountRootKeyHandle._(result.arkHandle, result.userId),
        keyEpoch: result.keyEpoch,
        capsuleVersion: result.capsuleVersion,
      );
    } finally {
      passphrase.fillRange(0, passphrase.length, 0);
    }
  }
}

final class _RecoveryIdentityNativeResult {
  const _RecoveryIdentityNativeResult({
    required this.handle,
    required this.publicKey,
  });

  final int handle;
  final Uint8List publicKey;
}

final class _RecoveryCapsuleOpenNativeResult {
  const _RecoveryCapsuleOpenNativeResult({
    required this.arkHandle,
    required this.userId,
    required this.keyEpoch,
    required this.capsuleVersion,
  });

  final int arkHandle;
  final Uint8List userId;
  final int keyEpoch;
  final int capsuleVersion;
}

void _validateRecoveryPassphrase(Uint8List passphrase) {
  if (passphrase.length > _recoveryPassphraseMaximumUtf8Length) {
    throw ArgumentError.value(
      passphrase.length,
      'passphrase',
      '恢复口令不得超过 $_recoveryPassphraseMaximumUtf8Length 个 UTF-8 字节',
    );
  }
  final scalarCount = _countValidUtf8Scalars(passphrase);
  if (scalarCount < _recoveryPassphraseMinimumScalars) {
    throw ArgumentError.value(
      scalarCount,
      'passphrase',
      '恢复口令不得少于 $_recoveryPassphraseMinimumScalars 个 Unicode scalar',
    );
  }
}

int _countValidUtf8Scalars(Uint8List bytes) {
  var offset = 0;
  var scalarCount = 0;
  while (offset < bytes.length) {
    final first = bytes[offset];
    if (first <= 0x7f) {
      offset += 1;
    } else if (first >= 0xc2 && first <= 0xdf) {
      _requireUtf8Continuation(bytes, offset, 1);
      offset += 2;
    } else if (first == 0xe0) {
      _requireUtf8Range(bytes, offset + 1, 0xa0, 0xbf);
      _requireUtf8Continuation(bytes, offset, 2, start: 2);
      offset += 3;
    } else if ((first >= 0xe1 && first <= 0xec) ||
        (first >= 0xee && first <= 0xef)) {
      _requireUtf8Continuation(bytes, offset, 2);
      offset += 3;
    } else if (first == 0xed) {
      _requireUtf8Range(bytes, offset + 1, 0x80, 0x9f);
      _requireUtf8Continuation(bytes, offset, 2, start: 2);
      offset += 3;
    } else if (first == 0xf0) {
      _requireUtf8Range(bytes, offset + 1, 0x90, 0xbf);
      _requireUtf8Continuation(bytes, offset, 3, start: 2);
      offset += 4;
    } else if (first >= 0xf1 && first <= 0xf3) {
      _requireUtf8Continuation(bytes, offset, 3);
      offset += 4;
    } else if (first == 0xf4) {
      _requireUtf8Range(bytes, offset + 1, 0x80, 0x8f);
      _requireUtf8Continuation(bytes, offset, 3, start: 2);
      offset += 4;
    } else {
      throw ArgumentError('恢复口令必须是有效 UTF-8');
    }
    scalarCount += 1;
  }
  return scalarCount;
}

void _requireUtf8Continuation(
  Uint8List bytes,
  int sequenceOffset,
  int continuationCount, {
  int start = 1,
}) {
  for (var index = start; index <= continuationCount; index++) {
    _requireUtf8Range(bytes, sequenceOffset + index, 0x80, 0xbf);
  }
}

void _requireUtf8Range(Uint8List bytes, int offset, int minimum, int maximum) {
  if (offset >= bytes.length ||
      bytes[offset] < minimum ||
      bytes[offset] > maximum) {
    throw ArgumentError('恢复口令必须是有效 UTF-8');
  }
}

Uint8List _copyRecoveryHistory(List<Uint8List> entries) {
  if (entries.isEmpty) {
    throw ArgumentError('成员历史不能为空');
  }
  if (entries.length > _recoveryHistoryMaximumEntries) {
    throw ArgumentError.value(entries.length, 'membershipHistory', '成员历史条目过多');
  }
  var totalLength = 0;
  for (final entry in entries) {
    if (entry.length < _recoveryManifestMinimumLength ||
        entry.length > _recoveryManifestMaximumLength) {
      throw ArgumentError.value(entry.length, 'membershipHistory', '成员清单长度无效');
    }
    totalLength += entry.length;
  }
  final history = Uint8List(totalLength);
  var offset = 0;
  for (final entry in entries) {
    history.setRange(offset, offset + entry.length, entry);
    offset += entry.length;
  }
  return history;
}

_RecoveryIdentityNativeResult _generateRecoveryIdentity(
  Uint8List userId,
  int recoveryPublicKeyVersion,
) {
  final userIdPointer = _copyToNative(userId);
  final outputHandle = calloc<ffi.Uint64>();
  final outputPublicKey = calloc<ffi.Uint8>(_recoveryPublicKeyLength);
  final outputPublicKeyLength = calloc<ffi.Size>();
  var published = false;
  try {
    _throwOnError(
      operation: 'recovery_identity_generate',
      statusCode: native.kelivo_recovery_identity_generate(
        userIdPointer,
        userId.length,
        recoveryPublicKeyVersion,
        outputHandle,
        outputPublicKey,
        _recoveryPublicKeyLength,
        outputPublicKeyLength,
      ),
    );
    if (outputHandle.value == native.KELIVO_RECOVERY_INVALID_HANDLE) {
      throw StateError('recovery_identity_generate 成功返回了无效句柄');
    }
    _requireExactOutputLength(
      operation: 'recovery_identity_generate',
      expected: _recoveryPublicKeyLength,
      actual: outputPublicKeyLength.value,
    );
    final result = _RecoveryIdentityNativeResult(
      handle: outputHandle.value,
      publicKey: Uint8List.fromList(
        outputPublicKey.asTypedList(_recoveryPublicKeyLength),
      ),
    );
    published = true;
    return result;
  } finally {
    if (!published &&
        outputHandle.value != native.KELIVO_RECOVERY_INVALID_HANDLE) {
      native.kelivo_recovery_handle_close(outputHandle.value);
    }
    _clearAndFree(userIdPointer, userId.length);
    _clearAndFree(outputPublicKey, _recoveryPublicKeyLength);
    calloc.free(outputPublicKeyLength);
    calloc.free(outputHandle);
    userId.fillRange(0, userId.length, 0);
  }
}

Uint8List _sealRecoveryCapsule(
  int arkHandle,
  Uint8List userId,
  int keyEpoch,
  int recoveryPublicKeyVersion,
  int capsuleVersion,
  Uint8List recoveryPublicKey,
) {
  final userIdPointer = _copyToNative(userId);
  final publicKeyPointer = _copyToNative(recoveryPublicKey);
  try {
    return _fixedDeviceOutput(
      operation: 'recovery_capsule_seal',
      expectedLength: _recoveryCapsuleLength,
      call: (output, capacity, outputLength) =>
          native.kelivo_recovery_capsule_seal(
            arkHandle,
            userIdPointer,
            userId.length,
            keyEpoch,
            recoveryPublicKeyVersion,
            capsuleVersion,
            publicKeyPointer,
            recoveryPublicKey.length,
            output,
            capacity,
            outputLength,
          ),
    );
  } finally {
    _clearAndFree(userIdPointer, userId.length);
    _clearAndFree(publicKeyPointer, recoveryPublicKey.length);
    userId.fillRange(0, userId.length, 0);
    recoveryPublicKey.fillRange(0, recoveryPublicKey.length, 0);
  }
}

Uint8List _exportRecoveryMedia(
  int recoveryHandle,
  int initialArkHandle,
  Uint8List initialCapsule,
  Uint8List genesis,
  Uint8List passphrase,
  Uint8List origin,
) {
  final authority = calloc<native.KelivoRecoveryMediaExportAuthority>();
  final genesisPointer = _copyToNative(genesis);
  final originPointer = _copyToNative(origin);
  var passphrasePointer = ffi.nullptr.cast<ffi.Uint8>();
  try {
    // 最后分配口令副本，后续任意失败都已进入 finally 清零路径。
    passphrasePointer = _copyToNative(passphrase);
    authority.ref.struct_size =
        native.KELIVO_RECOVERY_MEDIA_EXPORT_AUTHORITY_STRUCT_SIZE;
    for (var index = 0; index < initialCapsule.length; index++) {
      authority.ref.initial_capsule[index] = initialCapsule[index];
    }
    authority.ref.local_epoch_one_ark_handle = initialArkHandle;
    return _fixedDeviceOutput(
      operation: 'recovery_media_export',
      expectedLength: _recoveryMediaLength,
      call: (output, capacity, outputLength) =>
          native.kelivo_recovery_media_export(
            recoveryHandle,
            authority,
            genesisPointer,
            genesis.length,
            passphrasePointer,
            passphrase.length,
            originPointer,
            origin.length,
            output,
            capacity,
            outputLength,
          ),
    );
  } finally {
    _clearAndFree(
      authority.cast<ffi.Uint8>(),
      ffi.sizeOf<native.KelivoRecoveryMediaExportAuthority>(),
    );
    _clearAndFree(genesisPointer, genesis.length);
    if (passphrasePointer.address != 0) {
      _clearAndFree(passphrasePointer, passphrase.length);
    }
    _clearAndFree(originPointer, origin.length);
    initialCapsule.fillRange(0, initialCapsule.length, 0);
    genesis.fillRange(0, genesis.length, 0);
    passphrase.fillRange(0, passphrase.length, 0);
    origin.fillRange(0, origin.length, 0);
  }
}

_RecoveryCapsuleOpenNativeResult _recoverAccountRootKey(
  Uint8List media,
  Uint8List passphrase,
  Uint8List origin,
  Uint8List history,
  Uint8List? sourceCapsule,
  Uint8List currentCapsule,
) {
  final mediaPointer = _copyToNative(media);
  final originPointer = _copyToNative(origin);
  final historyPointer = _copyToNative(history);
  final sourceCapsulePointer = sourceCapsule == null
      ? ffi.nullptr.cast<ffi.Uint8>()
      : _copyToNative(sourceCapsule);
  final currentCapsulePointer = _copyToNative(currentCapsule);
  final outputBinding = calloc<native.KelivoRecoveryCapsuleBinding>();
  final outputArkHandle = calloc<ffi.Uint64>();
  var passphrasePointer = ffi.nullptr.cast<ffi.Uint8>();
  var published = false;
  try {
    // 大体积历史和所有输出先完成分配，避免口令原生副本越过异常路径。
    passphrasePointer = _copyToNative(passphrase);
    _throwOnError(
      operation: 'recovery_media_import_history_verify_and_capsule_open',
      statusCode: native
          .kelivo_recovery_media_import_history_verify_and_capsule_open(
            mediaPointer,
            media.length,
            passphrasePointer,
            passphrase.length,
            originPointer,
            origin.length,
            historyPointer,
            history.length,
            sourceCapsulePointer,
            sourceCapsule?.length ?? 0,
            currentCapsulePointer,
            currentCapsule.length,
            outputBinding,
            outputArkHandle,
          ),
    );
    if (outputArkHandle.value == native.KELIVO_DEVICE_INVALID_HANDLE) {
      throw StateError('恢复成功但返回了无效 ARK keyring 句柄');
    }
    if (outputBinding.ref.struct_size !=
        native.KELIVO_RECOVERY_CAPSULE_BINDING_STRUCT_SIZE) {
      throw StateError('恢复成功但返回了未知绑定结构');
    }
    final userId = _copyNativeByteArray(
      outputBinding.ref.user_id,
      _deviceUuidLength,
    );
    _validateUuidV4(userId, 'userId');
    _validatePositiveUint32(outputBinding.ref.key_epoch, 'keyEpoch');
    _validatePositiveUint32(
      outputBinding.ref.capsule_version,
      'capsuleVersion',
    );
    final result = _RecoveryCapsuleOpenNativeResult(
      arkHandle: outputArkHandle.value,
      userId: _immutableDeviceBytes(userId),
      keyEpoch: outputBinding.ref.key_epoch,
      capsuleVersion: outputBinding.ref.capsule_version,
    );
    published = true;
    return result;
  } finally {
    if (!published &&
        outputArkHandle.value != native.KELIVO_DEVICE_INVALID_HANDLE) {
      native.kelivo_account_root_key_handle_close(outputArkHandle.value);
    }
    _clearAndFree(mediaPointer, media.length);
    if (passphrasePointer.address != 0) {
      _clearAndFree(passphrasePointer, passphrase.length);
    }
    _clearAndFree(originPointer, origin.length);
    _clearAndFree(historyPointer, history.length);
    if (sourceCapsule != null) {
      _clearAndFree(sourceCapsulePointer, sourceCapsule.length);
      sourceCapsule.fillRange(0, sourceCapsule.length, 0);
    }
    _clearAndFree(currentCapsulePointer, currentCapsule.length);
    _clearAndFree(
      outputBinding.cast<ffi.Uint8>(),
      ffi.sizeOf<native.KelivoRecoveryCapsuleBinding>(),
    );
    calloc.free(outputArkHandle);
    media.fillRange(0, media.length, 0);
    passphrase.fillRange(0, passphrase.length, 0);
    origin.fillRange(0, origin.length, 0);
    history.fillRange(0, history.length, 0);
    currentCapsule.fillRange(0, currentCapsule.length, 0);
  }
}

void _requireSameRecoveryAccount(Uint8List actual, Uint8List expected) {
  if (actual.length != expected.length) {
    throw StateError('恢复介质导出账户失配');
  }
  var difference = 0;
  for (var index = 0; index < actual.length; index++) {
    difference |= actual[index] ^ expected[index];
  }
  if (difference != 0) {
    throw StateError('恢复介质导出账户失配');
  }
}
