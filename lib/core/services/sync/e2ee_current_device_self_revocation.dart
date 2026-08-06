import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:uuid/uuid.dart';

import '../../database/chat_database_gateway.dart';
import '../workspace/device_state_blob_store.dart';
import 'cloud_sync_client.dart';
import 'cloud_sync_types.dart';
import 'e2ee_account_trust_manifest.dart';
import 'e2ee_device_state_access.dart';
import 'e2ee_self_revocation_checkpoint.dart';
import 'e2ee_self_revocation_coordinator.dart';
import 'e2ee_sync_execution_budget.dart';

abstract interface class E2eeSelfRevocationIntentSigner {
  Future<KelivoSelfRevocationIntent> sign({
    required KelivoDeviceIdentityHandle identity,
    required String userId,
    required String deviceId,
    required String mutationId,
    required String operationId,
    required int expectedGeneration,
    required int expectedKeyEpoch,
    required Uint8List expectedMembershipManifestDigest,
    required DateTime expiresAt,
  });
}

/// 唯一 Native 签名适配点；固定字段在进入安全核心后才编码和签名。
final class E2eeNativeSelfRevocationIntentSigner
    implements E2eeSelfRevocationIntentSigner {
  const E2eeNativeSelfRevocationIntentSigner()
    : _secureCore = const KelivoSecureCore();

  const E2eeNativeSelfRevocationIntentSigner.withSecureCore(this._secureCore);

  final KelivoSecureCore _secureCore;

  @override
  Future<KelivoSelfRevocationIntent> sign({
    required KelivoDeviceIdentityHandle identity,
    required String userId,
    required String deviceId,
    required String mutationId,
    required String operationId,
    required int expectedGeneration,
    required int expectedKeyEpoch,
    required Uint8List expectedMembershipManifestDigest,
    required DateTime expiresAt,
  }) {
    if (!expiresAt.isUtc ||
        expiresAt.microsecond != 0 ||
        expiresAt.millisecondsSinceEpoch < 0) {
      throw ArgumentError.value(expiresAt, 'expiresAt', '必须为非负整毫秒 UTC 时间');
    }
    return _secureCore.createSelfRevocationIntent(
      identity,
      userId: Uint8List.fromList(Uuid.parseAsByteList(userId)),
      deviceId: Uint8List.fromList(Uuid.parseAsByteList(deviceId)),
      mutationId: Uint8List.fromList(Uuid.parseAsByteList(mutationId)),
      operationId: Uint8List.fromList(Uuid.parseAsByteList(operationId)),
      expectedGeneration: expectedGeneration,
      expectedKeyEpoch: expectedKeyEpoch,
      expectedMembershipManifestDigest: expectedMembershipManifestDigest,
      expiresAtMs: expiresAt.millisecondsSinceEpoch,
    );
  }
}

sealed class E2eeCurrentDeviceSelfRevocationPreparation {
  const E2eeCurrentDeviceSelfRevocationPreparation();
}

final class E2eeCurrentDeviceSelfRevocationPrepared
    extends E2eeCurrentDeviceSelfRevocationPreparation {
  const E2eeCurrentDeviceSelfRevocationPrepared(this.checkpoint);

  final E2eeSelfRevocationCheckpoint checkpoint;
}

final class E2eeCurrentDeviceRecoveryReplacementRequired
    extends E2eeCurrentDeviceSelfRevocationPreparation {
  const E2eeCurrentDeviceRecoveryReplacementRequired();
}

sealed class E2eeCurrentDeviceSelfRevocationOutcome {
  const E2eeCurrentDeviceSelfRevocationOutcome();
}

final class E2eeCurrentDeviceSelfRevocationPending
    extends E2eeCurrentDeviceSelfRevocationOutcome {
  const E2eeCurrentDeviceSelfRevocationPending();
}

final class E2eeCurrentDeviceSelfRevocationConfirmed
    extends E2eeCurrentDeviceSelfRevocationOutcome {
  const E2eeCurrentDeviceSelfRevocationConfirmed(this.receipt);

  final E2eeVerifiedSelfRevocationReceipt receipt;
}

final class E2eeCurrentDeviceSelfRevocationCancelled
    extends E2eeCurrentDeviceSelfRevocationOutcome {
  const E2eeCurrentDeviceSelfRevocationCancelled();
}

final class E2eeCurrentDeviceSelfRevocationExpired
    extends E2eeCurrentDeviceSelfRevocationOutcome {
  const E2eeCurrentDeviceSelfRevocationExpired();
}

final class E2eeCurrentDeviceSelfRevocationSuperseded
    extends E2eeCurrentDeviceSelfRevocationOutcome {
  const E2eeCurrentDeviceSelfRevocationSuperseded();
}

final class E2eeSelfRevocationSubmissionException implements Exception {
  const E2eeSelfRevocationSubmissionException({
    required this.createFailure,
    required this.statusFailure,
  });

  final Object createFailure;
  final Object statusFailure;

  @override
  String toString() => 'E2eeSelfRevocationSubmissionException()';
}

typedef E2eeSelfRevocationSleeper = Future<void> Function(Duration duration);

final class E2eeCurrentDeviceSelfRevocationRuntime {
  factory E2eeCurrentDeviceSelfRevocationRuntime({
    required String baseUrl,
    required String normalizedLoginName,
    required DeviceStateBlobStore deviceStateStore,
    required KelivoSecureCore secureCore,
    required ChatDatabaseGateway databaseGateway,
    required File databaseFile,
    required E2eeSelfRevocationCheckpointStore checkpointStore,
    E2eeSelfRevocationIntentSigner signer =
        const E2eeNativeSelfRevocationIntentSigner(),
    E2eeSelfRevocationIntentVerifier verifier =
        const E2eeNativeSelfRevocationIntentVerifier(),
    DateTime Function()? utcNow,
    E2eeSelfRevocationSleeper sleeper = Future<void>.delayed,
    int maximumStatusPolls = 3,
    Duration statusPollInterval = const Duration(seconds: 1),
  }) {
    if (normalizedLoginName.isEmpty ||
        normalizedLoginName != normalizedLoginName.trim().toLowerCase()) {
      throw const FormatException('自撤销登录名未规范化');
    }
    if (maximumStatusPolls < 1 || maximumStatusPolls > 10) {
      throw RangeError.range(maximumStatusPolls, 1, 10, 'maximumStatusPolls');
    }
    if (statusPollInterval <= Duration.zero ||
        statusPollInterval > const Duration(seconds: 10)) {
      throw ArgumentError.value(
        statusPollInterval,
        'statusPollInterval',
        '必须位于 0 至 10 秒范围',
      );
    }
    return E2eeCurrentDeviceSelfRevocationRuntime._(
      normalizeCloudSyncBaseUrl(baseUrl),
      normalizedLoginName,
      deviceStateStore,
      secureCore,
      databaseGateway,
      databaseFile.absolute,
      checkpointStore,
      signer,
      verifier,
      utcNow ?? DateTime.now,
      sleeper,
      maximumStatusPolls,
      statusPollInterval,
    );
  }

  const E2eeCurrentDeviceSelfRevocationRuntime._(
    this._baseUrl,
    this._normalizedLoginName,
    this._deviceStateStore,
    this._secureCore,
    this._databaseGateway,
    this._databaseFile,
    this._checkpointStore,
    this._signer,
    this._verifier,
    this._utcNow,
    this._sleeper,
    this._maximumStatusPolls,
    this._statusPollInterval,
  );

  final String _baseUrl;
  final String _normalizedLoginName;
  final DeviceStateBlobStore _deviceStateStore;
  final KelivoSecureCore _secureCore;
  final ChatDatabaseGateway _databaseGateway;
  final File _databaseFile;
  final E2eeSelfRevocationCheckpointStore _checkpointStore;
  final E2eeSelfRevocationIntentSigner _signer;
  final E2eeSelfRevocationIntentVerifier _verifier;
  final DateTime Function() _utcNow;
  final E2eeSelfRevocationSleeper _sleeper;
  final int _maximumStatusPolls;
  final Duration _statusPollInterval;

  String get normalizedLoginName => _normalizedLoginName;

  Future<E2eeCurrentDeviceSelfRevocationPreparation> prepare({
    required CloudSyncAccountSession session,
    required String mutationId,
  }) async {
    if (session.baseUrl != _baseUrl ||
        session.loginName != _normalizedLoginName) {
      throw const FormatException('自撤销会话不属于当前账户工作区');
    }

    E2eeOpenedDeviceStateHandles? opened;
    ChatDatabaseLease? databaseLease;
    Object? primaryError;
    StackTrace? primaryStackTrace;
    E2eeCurrentDeviceSelfRevocationPreparation? preparation;
    try {
      opened = await E2eeDeviceStateAccess(
        baseUrl: _baseUrl,
        deviceStateStore: _deviceStateStore,
        secureCore: _secureCore,
      ).openExisting(_normalizedLoginName);
      final state = opened;
      if (state == null || state.ark == null) {
        throw StateError('自撤销缺少本机设备状态');
      }
      _requireOpenedStateMatchesSession(state, session);
      databaseLease = await _databaseGateway.acquire(_databaseFile);
      final anchor = await databaseLease
          .repository
          .e2eeVerifiedMembershipAnchorCommands
          .readVerified(accountUserId: session.userId, ark: state.ark!);
      if (anchor == null) {
        throw StateError('自撤销缺少本地已验证成员锚点');
      }
      final head = anchor.membership;
      _requireMembershipMatchesSession(head, session);
      if (head.members.length == 1) {
        preparation = const E2eeCurrentDeviceRecoveryReplacementRequired();
      } else {
        final expiresAt = DateTime.fromMillisecondsSinceEpoch(
          _utcNow().toUtc().millisecondsSinceEpoch +
              const Duration(hours: 24).inMilliseconds,
          isUtc: true,
        );
        final signed = await _signer.sign(
          identity: state.identity,
          userId: session.userId,
          deviceId: session.deviceId,
          mutationId: mutationId,
          operationId: mutationId,
          expectedGeneration: head.securityGeneration,
          expectedKeyEpoch: head.keyEpoch,
          expectedMembershipManifestDigest: head.digest,
          expiresAt: expiresAt,
        );
        final request = CloudSyncSelfRevocationRequest(
          deviceId: session.deviceId,
          mutationId: mutationId,
          operationId: mutationId,
          expectedGeneration: head.securityGeneration,
          expectedKeyEpoch: head.keyEpoch,
          expectedMembershipManifestDigest:
              CloudSyncMembershipManifestDigest.fromBytes(head.digest),
          expiresAt: expiresAt,
          continuationToken:
              CloudSyncSelfRevocationContinuationToken.generate(),
          intentDigest: signed.intentDigest,
          intentSignature: signed.intentSignature,
        );
        final checkpoint = await _checkpointStore.write(
          E2eeSelfRevocationCheckpoint(
            session: session,
            request: request,
            trustedHead: head,
          ),
        );
        preparation = E2eeCurrentDeviceSelfRevocationPrepared(checkpoint);
      }
    } catch (error, stackTrace) {
      primaryError = error;
      primaryStackTrace = stackTrace;
    }

    final cleanupError = await _closePreparationResources(
      secureCore: _secureCore,
      databaseLease: databaseLease,
      opened: opened,
    );
    if (primaryError != null && primaryStackTrace != null) {
      if (cleanupError != null) {
        developer.log(
          '自撤销准备失败后的安全资源清理未完全收敛',
          name: 'Kelivo.E2eeCurrentDeviceSelfRevocationRuntime',
          error: cleanupError.$1,
          stackTrace: cleanupError.$2,
        );
      }
      Error.throwWithStackTrace(primaryError, primaryStackTrace);
    }
    if (cleanupError != null) {
      Error.throwWithStackTrace(cleanupError.$1, cleanupError.$2);
    }
    return preparation!;
  }

  Future<E2eeCurrentDeviceSelfRevocationOutcome> submitAndPoll({
    required CloudSyncSelfRevocationTransport transport,
    required E2eeSelfRevocationCheckpoint checkpoint,
    E2eeSyncExecutionBudget? executionBudget,
  }) async {
    Object? createFailure;
    try {
      await _runNetworkStep(
        executionBudget,
        () => transport.createSelfRevocationRequest(checkpoint.request),
      );
    } catch (error) {
      // create 可能已在服务端提交；后续只允许 continuation 查询消除响应丢失歧义。
      createFailure = error;
    }

    for (var poll = 0; poll < _maximumStatusPolls; poll++) {
      try {
        final status = await _runNetworkStep(
          executionBudget,
          () => transport.continueSelfRevocationStatus(checkpoint.request),
        );
        switch (status) {
          case CloudSyncSelfRevocationPending():
            if (poll + 1 == _maximumStatusPolls) {
              return const E2eeCurrentDeviceSelfRevocationPending();
            }
            executionBudget?.checkCanContinue();
            await _sleeper(_statusPollInterval);
            executionBudget?.checkCanContinue();
          case CloudSyncUntrustedSelfRevocationConfirmed():
            final receipt = await _verifyConfirmed(
              checkpoint: checkpoint,
              confirmed: status,
            );
            return E2eeCurrentDeviceSelfRevocationConfirmed(receipt);
          case CloudSyncSelfRevocationCancelled():
            return const E2eeCurrentDeviceSelfRevocationCancelled();
          case CloudSyncSelfRevocationExpired():
            return const E2eeCurrentDeviceSelfRevocationExpired();
          case CloudSyncSelfRevocationSuperseded():
            return const E2eeCurrentDeviceSelfRevocationSuperseded();
        }
      } catch (statusFailure) {
        final prior = createFailure;
        if (prior != null) {
          throw E2eeSelfRevocationSubmissionException(
            createFailure: prior,
            statusFailure: statusFailure,
          );
        }
        rethrow;
      }
    }
    throw StateError('自撤销续查循环未返回结果');
  }

  Future<E2eeVerifiedSelfRevocationReceipt> _verifyConfirmed({
    required E2eeSelfRevocationCheckpoint checkpoint,
    required CloudSyncUntrustedSelfRevocationConfirmed confirmed,
  }) async {
    E2eeOpenedDeviceStateHandles? opened;
    Object? primaryError;
    StackTrace? primaryStackTrace;
    E2eeVerifiedSelfRevocationReceipt? receipt;
    try {
      opened = await E2eeDeviceStateAccess(
        baseUrl: checkpoint.session.baseUrl,
        deviceStateStore: _deviceStateStore,
        secureCore: _secureCore,
      ).openExisting(checkpoint.session.loginName);
      final state = opened;
      if (state == null || state.ark == null) {
        throw StateError('自撤销终态验证缺少旧设备状态');
      }
      _requireOpenedStateMatchesSession(state, checkpoint.session);
      final trustedHead = await const E2eeAccountTrustManifestModule()
          .verifyPersistedAnchorSnapshot(
            ark: state.ark!,
            userId: checkpoint.session.userId,
            securityGeneration: checkpoint.trustedHeadSecurityGeneration,
            keyEpoch: checkpoint.trustedHeadKeyEpoch,
            persistedManifest: checkpoint.trustedHeadManifest,
            persistedManifestDigest: checkpoint.trustedHeadManifestDigest,
          );
      receipt = await E2eeTrustedSelfRevocationCoordinator(
        intentVerifier: _verifier,
      ).verifyConfirmedReceipt(
        trustedCurrentHead: trustedHead,
        untrustedConfirmed: confirmed,
      );
    } catch (error, stackTrace) {
      primaryError = error;
      primaryStackTrace = stackTrace;
    }
    final cleanupError = await _closeOpenedState(
      secureCore: _secureCore,
      opened: opened,
    );
    if (primaryError != null && primaryStackTrace != null) {
      Error.throwWithStackTrace(primaryError, primaryStackTrace);
    }
    if (cleanupError != null) {
      Error.throwWithStackTrace(cleanupError.$1, cleanupError.$2);
    }
    return receipt!;
  }
}

Future<T> _runNetworkStep<T>(
  E2eeSyncExecutionBudget? executionBudget,
  Future<T> Function() action,
) {
  if (executionBudget == null) return action();
  return executionBudget.runBoundedStep(operation: (_) => action());
}

void _requireOpenedStateMatchesSession(
  E2eeOpenedDeviceStateHandles opened,
  CloudSyncAccountSession session,
) {
  final account = opened.binding.account;
  if (account == null ||
      opened.binding.keyVersion != session.deviceKeyVersion ||
      Uuid.unparse(opened.binding.deviceId) != session.deviceId ||
      Uuid.unparse(account.userId) != session.userId ||
      account.keyEpoch != session.keyEpoch) {
    throw StateError('自撤销设备状态与会话不匹配');
  }
}

void _requireMembershipMatchesSession(
  E2eeVerifiedMembership membership,
  CloudSyncAccountSession session,
) {
  final localMembers = membership.members
      .where((member) => member.deviceId == session.deviceId)
      .toList(growable: false);
  if (membership.userId != session.userId ||
      membership.keyEpoch != session.keyEpoch ||
      localMembers.length != 1 ||
      localMembers.single.keyVersion != session.deviceKeyVersion ||
      localMembers.single.authGeneration != session.authGeneration) {
    throw StateError('自撤销本地可信成员头与会话不匹配');
  }
}

Future<(Object, StackTrace)?> _closePreparationResources({
  required KelivoSecureCore secureCore,
  required ChatDatabaseLease? databaseLease,
  required E2eeOpenedDeviceStateHandles? opened,
}) async {
  Object? error;
  StackTrace? stackTrace;
  if (databaseLease != null) {
    try {
      await databaseLease.release();
    } catch (caught, caughtStackTrace) {
      error = caught;
      stackTrace = caughtStackTrace;
    }
  }
  final openedError = await _closeOpenedState(
    secureCore: secureCore,
    opened: opened,
  );
  if (error == null && openedError != null) return openedError;
  return error == null ? null : (error, stackTrace!);
}

Future<(Object, StackTrace)?> _closeOpenedState({
  required KelivoSecureCore secureCore,
  required E2eeOpenedDeviceStateHandles? opened,
}) async {
  if (opened == null) return null;
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

  final ark = opened.ark;
  if (ark != null) await close(() => secureCore.closeAccountRootKey(ark));
  await close(() => secureCore.closeDeviceIdentity(opened.identity));
  await close(() => secureCore.close(opened.key));
  return error == null ? null : (error!, stackTrace!);
}
