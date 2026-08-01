import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:kelivo_secure_core/kelivo_secure_core.dart';

import '../workspace/device_state_blob_store.dart';
import 'cloud_sync_types.dart';
import 'e2ee_device_state_access.dart';

final class E2eeAccountKeyLease {
  E2eeAccountKeyLease._({
    required this._secureCore,
    required this._accountRootKey,
    required this.userId,
    required this.keyEpoch,
    required this.deviceKeyVersion,
  });

  final KelivoSecureCore _secureCore;
  KelivoAccountRootKeyHandle? _accountRootKey;

  final String userId;
  final int keyEpoch;
  final int deviceKeyVersion;

  static Future<E2eeAccountKeyLease> open({
    required CloudSyncAccountSession session,
    required DeviceStateBlobStore deviceStateStore,
    required KelivoSecureCore secureCore,
  }) async {
    final stateAccess = E2eeDeviceStateAccess(
      baseUrl: session.baseUrl,
      deviceStateStore: deviceStateStore,
      secureCore: secureCore,
    );
    final opened = await stateAccess.openExisting(session.loginName);
    if (opened == null) {
      throw StateError('当前账户缺少本机设备状态');
    }

    KelivoKeyHandle? key = opened.key;
    KelivoDeviceIdentityHandle? identity = opened.identity;
    KelivoAccountRootKeyHandle? ark = opened.ark;
    try {
      final account = opened.binding.account;
      if (account == null || ark == null) {
        throw StateError('当前设备状态尚未绑定账户密钥');
      }
      if (_uuidString(opened.binding.deviceId) != session.deviceId ||
          opened.binding.keyVersion != session.deviceKeyVersion ||
          _uuidString(account.userId) != session.userId ||
          account.keyEpoch != session.keyEpoch) {
        throw StateError('账户会话与本机设备状态绑定不匹配');
      }

      Object? closeError;
      StackTrace? closeStackTrace;

      final ownedIdentity = identity;
      identity = null;
      try {
        await secureCore.closeDeviceIdentity(ownedIdentity);
      } catch (error, stackTrace) {
        closeError = error;
        closeStackTrace = stackTrace;
      }

      final ownedKey = key;
      key = null;
      try {
        await secureCore.close(ownedKey);
      } catch (error, stackTrace) {
        if (closeError == null) {
          closeError = error;
          closeStackTrace = stackTrace;
        } else {
          developer.log(
            'E2EE 账户密钥租约打开时的后续资源清理失败',
            name: 'Kelivo.E2eeAccountKeyLease',
          );
        }
      }

      if (closeError != null && closeStackTrace != null) {
        Error.throwWithStackTrace(closeError, closeStackTrace);
      }

      final lease = E2eeAccountKeyLease._(
        secureCore: secureCore,
        accountRootKey: ark,
        userId: session.userId,
        keyEpoch: session.keyEpoch,
        deviceKeyVersion: session.deviceKeyVersion,
      );
      ark = null;
      return lease;
    } catch (error, stackTrace) {
      await _cleanupAfterOpenFailure(
        secureCore: secureCore,
        ark: ark,
        identity: identity,
        key: key,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  KelivoAccountRootKeyHandle takeAccountRootKeyOwnership() {
    final ark = _accountRootKey;
    if (ark == null) {
      throw StateError('账户根密钥租约已经关闭或完成所有权转移');
    }
    _accountRootKey = null;
    return ark;
  }

  Future<void> close() async {
    final ark = _accountRootKey;
    if (ark == null) return;
    // 先撤销对象可见的所有权，原生关闭失败时也不得继续使用未知状态句柄。
    _accountRootKey = null;
    await _secureCore.closeAccountRootKey(ark);
  }

  static Future<void> _cleanupAfterOpenFailure({
    required KelivoSecureCore secureCore,
    required KelivoAccountRootKeyHandle? ark,
    required KelivoDeviceIdentityHandle? identity,
    required KelivoKeyHandle? key,
  }) async {
    final actions = <Future<void> Function()>[
      if (ark != null) () => secureCore.closeAccountRootKey(ark),
      if (identity != null) () => secureCore.closeDeviceIdentity(identity),
      if (key != null) () => secureCore.close(key),
    ];
    for (final action in actions) {
      try {
        await action();
      } catch (_) {
        developer.log(
          'E2EE 账户密钥租约打开失败后的资源清理失败',
          name: 'Kelivo.E2eeAccountKeyLease',
        );
      }
    }
  }

  static String _uuidString(Uint8List value) {
    if (value.length != 16) {
      throw const FormatException('设备状态 UUID 长度无效');
    }
    final hex = value
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
