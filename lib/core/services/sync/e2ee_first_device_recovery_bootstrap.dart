import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:uuid/uuid.dart';

import 'cloud_sync_types.dart';
import 'e2ee_account_authenticator.dart';
import 'e2ee_account_trust_manifest.dart';
import 'e2ee_first_device_registration_commit_coordinator.dart';
import 'sensitive_utf8.dart';

const e2eeCanonicalRecoveryServiceOrigin = 'https://kelivo.bemylover.top';
const _recoveryPassphraseMinimumScalars = 12;
const _recoveryPassphraseMaximumUtf8Bytes = 128;
const _initialSecurityVersion = 1;

enum E2eeRecoveryPassphraseValidation { valid, tooShort, tooLong, invalidUtf8 }

/// UI 仍会短暂持有 String；这里立即转成可清零字节并复用安全核心的唯一校验器。
E2eeRecoveryPassphraseValidation validateE2eeRecoveryPassphraseText(
  String passphrase,
) {
  late final Uint8List encoded;
  try {
    encoded = encodeSensitiveUtf8(passphrase);
  } on FormatException {
    return E2eeRecoveryPassphraseValidation.invalidUtf8;
  }
  try {
    const KelivoSecureCore().validateRecoveryPassphrase(encoded);
    return E2eeRecoveryPassphraseValidation.valid;
  } on ArgumentError {
    if (encoded.length > _recoveryPassphraseMaximumUtf8Bytes) {
      return E2eeRecoveryPassphraseValidation.tooLong;
    }
    if (passphrase.runes.length < _recoveryPassphraseMinimumScalars) {
      return E2eeRecoveryPassphraseValidation.tooShort;
    }
    return E2eeRecoveryPassphraseValidation.invalidUtf8;
  } finally {
    clearSensitiveBytes(encoded);
  }
}

enum _RecoveryBootstrapPreparerState { ready, preparing, closed }

// 协议固定 authority，避免 URL 规范化差异把恢复介质绑定到其他服务端点。
const _canonicalRecoveryServiceOriginSha256 = <int>[
  0xea,
  0x81,
  0x86,
  0xed,
  0x7b,
  0x73,
  0x8c,
  0x5e,
  0x7d,
  0x26,
  0xd2,
  0xd1,
  0x0e,
  0xb7,
  0x2b,
  0xc8,
  0xd1,
  0x0a,
  0xcb,
  0x9f,
  0xbc,
  0x14,
  0x95,
  0xef,
  0x37,
  0x15,
  0xf1,
  0x69,
  0x1e,
  0x31,
  0x40,
  0x9f,
];

abstract interface class E2eeFirstDeviceRecoveryIdentity {
  Uint8List get publicKey;
}

/// 移动平台恢复安全核心边界；应用层只持有不透明身份和公开材料。
abstract interface class E2eeFirstDeviceRecoveryCore {
  void validateRecoveryPassphrase(Uint8List passphrase);

  Future<E2eeFirstDeviceRecoveryIdentity> generateRecoveryIdentity({
    required String userId,
    required int recoveryPublicKeyVersion,
  });

  Future<Uint8List> sealRecoveryCapsule(
    KelivoAccountRootKeyHandle ark, {
    required int keyEpoch,
    required Uint8List recoveryPublicKey,
    required int recoveryPublicKeyVersion,
    required int capsuleVersion,
  });

  Future<Uint8List> exportRecoveryMedia(
    E2eeFirstDeviceRecoveryIdentity recovery,
    KelivoAccountRootKeyHandle initialArk, {
    required Uint8List initialCapsule,
    required Uint8List genesisManifest,
    required Uint8List passphrase,
    required Uint8List serviceOriginSha256,
  });

  Future<void> closeRecoveryIdentity(E2eeFirstDeviceRecoveryIdentity recovery);
}

final class E2eeFirstDeviceRecoveryBootstrapPreparer
    implements E2eeFirstDeviceSecurityBootstrapPreparer {
  /// 构造时复制并清零调用方口令；exporter 在事务耐久保存后消费密文缓冲区。
  factory E2eeFirstDeviceRecoveryBootstrapPreparer({
    required Uint8List recoveryPassphrase,
    required String serviceOrigin,
    required E2eeEncryptedRecoveryMediaExporter encryptedMediaExporter,
  }) {
    return E2eeFirstDeviceRecoveryBootstrapPreparer._create(
      recoveryPassphrase: recoveryPassphrase,
      serviceOrigin: serviceOrigin,
      encryptedMediaExporter: encryptedMediaExporter,
      recoveryCore: const _KelivoFirstDeviceRecoveryCore(),
    );
  }

  @visibleForTesting
  factory E2eeFirstDeviceRecoveryBootstrapPreparer.forTesting({
    required Uint8List recoveryPassphrase,
    required String serviceOrigin,
    required E2eeEncryptedRecoveryMediaExporter encryptedMediaExporter,
    required E2eeFirstDeviceRecoveryCore recoveryCore,
  }) {
    return E2eeFirstDeviceRecoveryBootstrapPreparer._create(
      recoveryPassphrase: recoveryPassphrase,
      serviceOrigin: serviceOrigin,
      encryptedMediaExporter: encryptedMediaExporter,
      recoveryCore: recoveryCore,
    );
  }

  factory E2eeFirstDeviceRecoveryBootstrapPreparer._create({
    required Uint8List recoveryPassphrase,
    required String serviceOrigin,
    required E2eeEncryptedRecoveryMediaExporter encryptedMediaExporter,
    required E2eeFirstDeviceRecoveryCore recoveryCore,
  }) {
    if (serviceOrigin != e2eeCanonicalRecoveryServiceOrigin) {
      _clearSensitiveBytes(recoveryPassphrase);
      throw ArgumentError.value(
        serviceOrigin,
        'serviceOrigin',
        '必须为规范服务 origin $e2eeCanonicalRecoveryServiceOrigin',
      );
    }
    final ownedPassphrase = Uint8List.fromList(recoveryPassphrase);
    try {
      _clearSensitiveBytes(recoveryPassphrase);
      return E2eeFirstDeviceRecoveryBootstrapPreparer._(
        ownedPassphrase,
        encryptedMediaExporter,
        recoveryCore,
      );
    } catch (_) {
      _clearSensitiveBytes(ownedPassphrase);
      rethrow;
    }
  }

  E2eeFirstDeviceRecoveryBootstrapPreparer._(
    this._recoveryPassphrase,
    this._encryptedMediaExporter,
    this._recoveryCore,
  );

  final Uint8List _recoveryPassphrase;
  final E2eeEncryptedRecoveryMediaExporter _encryptedMediaExporter;
  final E2eeFirstDeviceRecoveryCore _recoveryCore;
  final E2eeAccountTrustManifestModule _manifestModule =
      const E2eeAccountTrustManifestModule();

  _RecoveryBootstrapPreparerState _state =
      _RecoveryBootstrapPreparerState.ready;
  bool _hasPreparedBootstrap = false;
  bool _exporterClosed = false;

  /// 上层注册在调用 prepare 前中止时，用它销毁已接管的口令。
  @override
  void close() {
    switch (_state) {
      case _RecoveryBootstrapPreparerState.ready:
        _clearSensitiveBytes(_recoveryPassphrase);
        _exporterClosed = true;
        _state = _RecoveryBootstrapPreparerState.closed;
        return;
      case _RecoveryBootstrapPreparerState.preparing:
        throw StateError('首设备恢复安全 bootstrap 正在生成');
      case _RecoveryBootstrapPreparerState.closed:
        _exporterClosed = true;
        return;
    }
  }

  @override
  Future<E2eePreparedFirstDeviceSecurityBootstrap> prepare({
    required KelivoAccountRootKeyHandle accountRootKey,
    required String userId,
    required String operationId,
    required E2eeMembershipDeviceInput localMember,
  }) async {
    if (_state != _RecoveryBootstrapPreparerState.ready) {
      throw StateError('首设备恢复安全 bootstrap 已被消费');
    }
    _state = _RecoveryBootstrapPreparerState.preparing;
    try {
      final prepared = await _prepareOnce(
        accountRootKey: accountRootKey,
        userId: userId,
        operationId: operationId,
        localMember: localMember,
      );
      _hasPreparedBootstrap = true;
      return prepared;
    } finally {
      _clearSensitiveBytes(_recoveryPassphrase);
      _state = _RecoveryBootstrapPreparerState.closed;
    }
  }

  @override
  Future<bool> exportEncryptedRecoveryMedia(Uint8List encryptedMedia) async {
    if (!_hasPreparedBootstrap || _exporterClosed) {
      _clearSensitiveBytes(encryptedMedia);
      throw StateError('首设备恢复介质 exporter 不可用');
    }
    _exporterClosed = true;
    try {
      if (encryptedMedia.length != e2eeEncryptedRecoveryMediaBytes) {
        throw const FormatException('加密恢复介质长度无效');
      }
      return await _encryptedMediaExporter(encryptedMedia);
    } finally {
      _clearSensitiveBytes(encryptedMedia);
    }
  }

  Future<E2eePreparedFirstDeviceSecurityBootstrap> _prepareOnce({
    required KelivoAccountRootKeyHandle accountRootKey,
    required String userId,
    required String operationId,
    required E2eeMembershipDeviceInput localMember,
  }) async {
    E2eeFirstDeviceRecoveryIdentity? recoveryIdentity;
    Uint8List? encryptedMedia;
    E2eePreparedFirstDeviceSecurityBootstrap? prepared;
    Object? failure;
    StackTrace? failureStackTrace;
    try {
      _recoveryCore.validateRecoveryPassphrase(_recoveryPassphrase);
      recoveryIdentity = await _recoveryCore.generateRecoveryIdentity(
        userId: userId,
        recoveryPublicKeyVersion: _initialSecurityVersion,
      );
      final recoveryCapsule = await _recoveryCore.sealRecoveryCapsule(
        accountRootKey,
        keyEpoch: _initialSecurityVersion,
        recoveryPublicKey: recoveryIdentity.publicKey,
        recoveryPublicKeyVersion: _initialSecurityVersion,
        capsuleVersion: _initialSecurityVersion,
      );
      final createdMembership = await _manifestModule.create(
        ark: accountRootKey,
        change: E2eeInitializeMembershipChange(
          userId: userId,
          operationId: operationId,
          member: localMember,
          recoveryPublicKeyVersion: _initialSecurityVersion,
          recoveryPublicKey: recoveryIdentity.publicKey,
          recoveryCapsuleVersion: _initialSecurityVersion,
          recoveryCapsule: recoveryCapsule,
        ),
      );
      final membership = await _manifestModule.verify(
        ark: accountRootKey,
        expectation: E2eeInitializeMembershipExpectation(
          projection: E2eeMembershipServerProjection(
            userId: userId,
            securityGeneration: _initialSecurityVersion,
            keyEpoch: _initialSecurityVersion,
            membershipManifestVersion: e2eeAccountTrustManifestFormatVersion,
            membershipManifest: createdMembership.manifest,
            membershipManifestDigest: createdMembership.digest,
            recoveryPublicKeyVersion: _initialSecurityVersion,
            recoveryPublicKey: recoveryIdentity.publicKey,
            recoveryCapsuleVersion: _initialSecurityVersion,
            recoveryCapsule: recoveryCapsule,
            lastOperationId: operationId,
            dataRekeyPhase: E2eeDataRekeyPhase.ready,
          ),
          operationId: operationId,
          member: localMember,
        ),
      );
      final securityState = CloudSyncGenesisSecurityState(
        operationId: operationId,
        membershipManifest: membership.manifest,
        membershipManifestDigest: CloudSyncMembershipManifestDigest.fromBytes(
          membership.digest,
        ),
        recoveryPublicKeyVersion: _initialSecurityVersion,
        recoveryPublicKey: recoveryIdentity.publicKey,
        recoveryCapsuleVersion: _initialSecurityVersion,
        recoveryCapsule: recoveryCapsule,
      );
      encryptedMedia = await _recoveryCore.exportRecoveryMedia(
        recoveryIdentity,
        accountRootKey,
        initialCapsule: recoveryCapsule,
        genesisManifest: membership.manifest,
        passphrase: _recoveryPassphrase,
        serviceOriginSha256: Uint8List.fromList(
          _canonicalRecoveryServiceOriginSha256,
        ),
      );
      if (encryptedMedia.length != e2eeEncryptedRecoveryMediaBytes) {
        throw FormatException('加密恢复介质长度无效：${encryptedMedia.length}');
      }
      prepared = E2eePreparedFirstDeviceSecurityBootstrap(
        securityState: securityState,
        membership: membership,
        encryptedRecoveryMedia: encryptedMedia,
      );
      encryptedMedia = null;
    } catch (error, stackTrace) {
      failure = error;
      failureStackTrace = stackTrace;
    } finally {
      _clearSensitiveBytes(_recoveryPassphrase);
      final identity = recoveryIdentity;
      if (identity != null) {
        try {
          await _recoveryCore.closeRecoveryIdentity(identity);
        } catch (error, stackTrace) {
          if (failure == null) {
            failure = error;
            failureStackTrace = stackTrace;
          } else {
            developer.log(
              '首设备恢复身份关闭失败',
              name: 'kelivo.e2ee.first_device_recovery',
              error: error,
              stackTrace: stackTrace,
            );
          }
        }
      }
    }

    if (failure != null && failureStackTrace != null) {
      _clearSensitiveBytes(encryptedMedia);
      prepared?.dispose();
      Error.throwWithStackTrace(failure, failureStackTrace);
    }
    final result = prepared;
    if (result == null) {
      _clearSensitiveBytes(encryptedMedia);
      throw StateError('首设备恢复安全 bootstrap 未完整生成');
    }
    return result;
  }
}

final class _KelivoFirstDeviceRecoveryIdentity
    implements E2eeFirstDeviceRecoveryIdentity {
  const _KelivoFirstDeviceRecoveryIdentity(this.identity);

  final KelivoRecoveryIdentity identity;

  @override
  Uint8List get publicKey => identity.publicKey;
}

final class _KelivoFirstDeviceRecoveryCore
    implements E2eeFirstDeviceRecoveryCore {
  const _KelivoFirstDeviceRecoveryCore();

  final KelivoSecureCore _secureCore = const KelivoSecureCore();

  @override
  void validateRecoveryPassphrase(Uint8List passphrase) {
    _secureCore.validateRecoveryPassphrase(passphrase);
  }

  @override
  Future<E2eeFirstDeviceRecoveryIdentity> generateRecoveryIdentity({
    required String userId,
    required int recoveryPublicKeyVersion,
  }) async {
    final identity = await _secureCore.generateRecoveryIdentity(
      userId: _canonicalUuidV4Bytes(userId, 'userId'),
      recoveryPublicKeyVersion: recoveryPublicKeyVersion,
    );
    return _KelivoFirstDeviceRecoveryIdentity(identity);
  }

  @override
  Future<Uint8List> sealRecoveryCapsule(
    KelivoAccountRootKeyHandle ark, {
    required int keyEpoch,
    required Uint8List recoveryPublicKey,
    required int recoveryPublicKeyVersion,
    required int capsuleVersion,
  }) {
    return _secureCore.sealRecoveryCapsule(
      ark,
      keyEpoch: keyEpoch,
      recoveryPublicKey: recoveryPublicKey,
      recoveryPublicKeyVersion: recoveryPublicKeyVersion,
      capsuleVersion: capsuleVersion,
    );
  }

  @override
  Future<Uint8List> exportRecoveryMedia(
    E2eeFirstDeviceRecoveryIdentity recovery,
    KelivoAccountRootKeyHandle initialArk, {
    required Uint8List initialCapsule,
    required Uint8List genesisManifest,
    required Uint8List passphrase,
    required Uint8List serviceOriginSha256,
  }) {
    final identity = _nativeRecoveryIdentity(recovery);
    return _secureCore.exportRecoveryMedia(
      identity.identity.handle,
      initialArk,
      initialCapsule: initialCapsule,
      genesisManifest: genesisManifest,
      passphrase: passphrase,
      serviceOriginSha256: serviceOriginSha256,
    );
  }

  @override
  Future<void> closeRecoveryIdentity(E2eeFirstDeviceRecoveryIdentity recovery) {
    final identity = _nativeRecoveryIdentity(recovery);
    return _secureCore.closeRecovery(identity.identity.handle);
  }

  _KelivoFirstDeviceRecoveryIdentity _nativeRecoveryIdentity(
    E2eeFirstDeviceRecoveryIdentity recovery,
  ) {
    if (recovery is! _KelivoFirstDeviceRecoveryIdentity) {
      throw ArgumentError.value(recovery, 'recovery', '恢复身份不属于当前安全核心');
    }
    return recovery;
  }
}

Uint8List _canonicalUuidV4Bytes(String value, String field) {
  late final Uint8List bytes;
  try {
    bytes = Uint8List.fromList(Uuid.parseAsByteList(value));
  } on FormatException {
    throw ArgumentError.value(value, field, '必须为规范小写 UUIDv4');
  }
  if (bytes.length != 16 ||
      bytes[6] & 0xf0 != 0x40 ||
      bytes[8] & 0xc0 != 0x80 ||
      Uuid.unparse(bytes) != value) {
    throw ArgumentError.value(value, field, '必须为规范小写 UUIDv4');
  }
  return bytes;
}

void _clearSensitiveBytes(Uint8List? value) {
  value?.fillRange(0, value.length, 0);
}
