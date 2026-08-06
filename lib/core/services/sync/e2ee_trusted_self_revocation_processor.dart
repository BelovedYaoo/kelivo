import 'dart:io';

import 'package:kelivo_secure_core/kelivo_secure_core.dart';

import '../../database/chat_database_gateway.dart';
import '../workspace/device_state_blob_store.dart';
import 'cloud_sync_client.dart';
import 'cloud_sync_types.dart';
import 'e2ee_account_trust_manifest.dart';
import 'e2ee_device_revocation_runtime.dart';
import 'e2ee_device_state_access.dart';
import 'e2ee_self_revocation_coordinator.dart';
import 'e2ee_sync_execution_budget.dart';

enum E2eeTrustedSelfRevocationProcessDisposition {
  idle,
  securityStateChanged,
}

/// 每周期至多推进一条撤销，换钥后强制上层销毁持有旧 ARK 的内容运行时。
final class E2eeTrustedSelfRevocationProcessor {
  factory E2eeTrustedSelfRevocationProcessor({
    required String baseUrl,
    required String normalizedLoginName,
    required DeviceStateBlobStore deviceStateStore,
    required KelivoSecureCore secureCore,
    required ChatDatabaseGateway databaseGateway,
    required File databaseFile,
    required CloudSyncSelfRevocationTransport selfRevocationTransport,
    required E2eeDeviceRevocationProductionRuntime revocationRuntime,
    E2eeSelfRevocationIntentVerifier intentVerifier =
        const E2eeNativeSelfRevocationIntentVerifier(),
    DateTime Function()? utcNow,
  }) {
    if (normalizedLoginName.isEmpty ||
        normalizedLoginName != normalizedLoginName.trim().toLowerCase()) {
      throw const FormatException('可信自撤销处理器登录名未规范化');
    }
    return E2eeTrustedSelfRevocationProcessor._(
      normalizeCloudSyncBaseUrl(baseUrl),
      normalizedLoginName,
      deviceStateStore,
      secureCore,
      databaseGateway,
      databaseFile.absolute,
      selfRevocationTransport,
      revocationRuntime,
      intentVerifier,
      utcNow ?? DateTime.now,
    );
  }

  const E2eeTrustedSelfRevocationProcessor._(
    this._baseUrl,
    this._normalizedLoginName,
    this._deviceStateStore,
    this._secureCore,
    this._databaseGateway,
    this._databaseFile,
    this._selfRevocationTransport,
    this._revocationRuntime,
    this._intentVerifier,
    this._utcNow,
  );

  final String _baseUrl;
  final String _normalizedLoginName;
  final DeviceStateBlobStore _deviceStateStore;
  final KelivoSecureCore _secureCore;
  final ChatDatabaseGateway _databaseGateway;
  final File _databaseFile;
  final CloudSyncSelfRevocationTransport _selfRevocationTransport;
  final E2eeDeviceRevocationProductionRuntime _revocationRuntime;
  final E2eeSelfRevocationIntentVerifier _intentVerifier;
  final DateTime Function() _utcNow;

  Future<E2eeTrustedSelfRevocationProcessDisposition> runOnce({
    required CloudSyncAccountSession session,
    E2eeSyncExecutionBudget? executionBudget,
  }) async {
    if (session.baseUrl != _baseUrl ||
        session.loginName != _normalizedLoginName) {
      throw const FormatException('可信自撤销处理器会话不属于当前工作区');
    }
    final trustedHead = await _readTrustedHead(session);
    final untrustedList = await _runNetworkStep(
      executionBudget,
      _selfRevocationTransport.listSelfRevocationRequests,
    );
    final verified = await E2eeTrustedSelfRevocationCoordinator(
      intentVerifier: _intentVerifier,
    ).verifyPendingRequestList(
      trustedCurrentHead: trustedHead,
      untrustedList: untrustedList,
      now: _utcNow().toUtc(),
    );
    E2eeVerifiedSelfRevocationIntent? selected;
    for (final intent in verified) {
      // 本机请求必须由另一可信设备签发 op3，本机绝不能取得目标新 ARK。
      if (intent.deviceId == session.deviceId) continue;
      selected = intent;
      break;
    }
    if (selected == null) {
      return E2eeTrustedSelfRevocationProcessDisposition.idle;
    }
    await _runNetworkStep(
      executionBudget,
      () => _revocationRuntime.approveSelfRevocation(
        session: session,
        intent: selected!,
      ),
    );
    return E2eeTrustedSelfRevocationProcessDisposition.securityStateChanged;
  }

  Future<E2eeVerifiedMembership> _readTrustedHead(
    CloudSyncAccountSession session,
  ) async {
    E2eeOpenedDeviceStateHandles? opened;
    ChatDatabaseLease? lease;
    Object? primaryError;
    StackTrace? primaryStackTrace;
    E2eeVerifiedMembership? membership;
    try {
      opened = await E2eeDeviceStateAccess(
        baseUrl: _baseUrl,
        deviceStateStore: _deviceStateStore,
        secureCore: _secureCore,
      ).openExisting(_normalizedLoginName);
      final state = opened;
      if (state == null || state.ark == null) {
        throw StateError('可信自撤销处理器缺少设备状态');
      }
      final account = state.binding.account;
      if (account == null ||
          state.binding.keyVersion != session.deviceKeyVersion ||
          account.keyEpoch != session.keyEpoch) {
        throw StateError('可信自撤销处理器设备状态与会话不匹配');
      }
      lease = await _databaseGateway.acquire(_databaseFile);
      final anchor = await lease
          .repository
          .e2eeVerifiedMembershipAnchorCommands
          .readVerified(accountUserId: session.userId, ark: state.ark!);
      if (anchor == null) {
        throw StateError('可信自撤销处理器缺少本地成员锚点');
      }
      membership = anchor.membership;
    } catch (error, stackTrace) {
      primaryError = error;
      primaryStackTrace = stackTrace;
    }
    final cleanupError = await _closeResources(
      lease: lease,
      opened: opened,
      secureCore: _secureCore,
    );
    if (primaryError != null && primaryStackTrace != null) {
      Error.throwWithStackTrace(primaryError, primaryStackTrace);
    }
    if (cleanupError != null) {
      Error.throwWithStackTrace(cleanupError.$1, cleanupError.$2);
    }
    return membership!;
  }
}

Future<T> _runNetworkStep<T>(
  E2eeSyncExecutionBudget? executionBudget,
  Future<T> Function() action,
) {
  if (executionBudget == null) return action();
  return executionBudget.runBoundedStep(operation: (_) => action());
}

Future<(Object, StackTrace)?> _closeResources({
  required ChatDatabaseLease? lease,
  required E2eeOpenedDeviceStateHandles? opened,
  required KelivoSecureCore secureCore,
}) async {
  Object? error;
  StackTrace? stackTrace;
  Future<void> close(Future<void> Function() action) async {
    try {
      await action();
    } catch (caught, caughtStackTrace) {
      error ??= caught;
      stackTrace ??= caughtStackTrace;
    }
  }

  if (lease != null) await close(lease.release);
  if (opened != null) {
    final ark = opened.ark;
    if (ark != null) await close(() => secureCore.closeAccountRootKey(ark));
    await close(() => secureCore.closeDeviceIdentity(opened.identity));
    await close(() => secureCore.close(opened.key));
  }
  return error == null ? null : (error!, stackTrace!);
}
