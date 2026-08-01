import 'installation_operation_lease.dart';
import 'local_cryptographic_wipe.dart';

sealed class LocalCryptographicWipeStartupAdmission {
  const LocalCryptographicWipeStartupAdmission();
}

final class LocalCryptographicWipeBusinessReady
    extends LocalCryptographicWipeStartupAdmission {
  const LocalCryptographicWipeBusinessReady(this.businessLease);

  final InstallationBusinessLease businessLease;
}

final class LocalCryptographicWipeRestartRequired
    extends LocalCryptographicWipeStartupAdmission {
  const LocalCryptographicWipeRestartRequired();
}

/// 在任何 workspace bootstrap 前完成安装级擦除准入。
///
/// 实例会保留失败中的独占 lease 和擦除进度，使 marker 已删除但 lease
/// 清理失败时只重试 completion，不会重新执行不可逆擦除步骤。
final class LocalCryptographicWipeStartupCoordinator {
  factory LocalCryptographicWipeStartupCoordinator({
    required InstallationOperationLease installationOperationLease,
    required LocalCryptographicWipe localCryptographicWipe,
    required LocalCryptographicWipeStep stopBackgroundSync,
  }) => LocalCryptographicWipeStartupCoordinator._(
    installationOperationLease,
    localCryptographicWipe,
    stopBackgroundSync,
  );

  LocalCryptographicWipeStartupCoordinator._(
    this._installationOperationLease,
    this._localCryptographicWipe,
    this._stopBackgroundSync,
  );

  final InstallationOperationLease _installationOperationLease;
  final LocalCryptographicWipe _localCryptographicWipe;
  final LocalCryptographicWipeStep _stopBackgroundSync;

  InstallationWipeLease? _pendingWipeLease;
  bool _wipeResumed = false;

  Future<LocalCryptographicWipeStartupAdmission> admit() async {
    final pending = await _installationOperationLease.acquirePendingWipe();
    if (pending == null) {
      final business = await _installationOperationLease.acquireBusiness();
      return LocalCryptographicWipeBusinessReady(business);
    }
    _pendingWipeLease = pending;
    await retryPendingWipe();
    return const LocalCryptographicWipeRestartRequired();
  }

  Future<void> retryPendingWipe() async {
    final lease =
        _pendingWipeLease ??
        await _installationOperationLease.acquirePendingWipe();
    if (lease == null) {
      throw StateError('local_device_wipe_marker_missing');
    }
    _pendingWipeLease = lease;
    if (!_wipeResumed) {
      final resumed = await _localCryptographicWipe.resumePendingAtColdStart(
        stopBackgroundSync: _stopBackgroundSync,
      );
      if (!resumed) {
        throw StateError('local_device_wipe_marker_missing');
      }
      _wipeResumed = true;
    }
    await lease.complete();
  }
}
