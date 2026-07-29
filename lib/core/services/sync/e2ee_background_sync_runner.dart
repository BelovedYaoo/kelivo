import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';

import '../../database/app_database.dart';
import '../../database/chat_database_gateway.dart';
import '../../database/database_installation_gate.dart';
import '../../database/sqlcipher_database_key.dart';
import '../backup/restore_business_lease.dart';
import '../backup/restore_receipt.dart';
import '../backup/restore_startup_gate.dart';
import '../workspace/account_workspace_runtime.dart';
import '../workspace/device_state_blob_store.dart';
import 'cloud_sync_client.dart';
import 'cloud_sync_terminal_session_retirement.dart';
import 'cloud_sync_types.dart';
import 'e2ee_chat_content_runtime.dart';
import 'e2ee_sync_execution_budget.dart';
import 'e2ee_sync_scheduler.dart';

final class E2eeBackgroundSyncCapability {
  E2eeBackgroundSyncCapability({
    required String accountUserId,
    required String deviceId,
    required int sessionGeneration,
    required int authGeneration,
    required int keyEpoch,
    required String manifestDigest,
  }) : accountUserId = _requireCapabilityIdentifier(
         accountUserId,
         'accountUserId',
       ),
       deviceId = _requireCapabilityIdentifier(deviceId, 'deviceId'),
       sessionGeneration = _requireCapabilityPositiveGeneration(
         sessionGeneration,
         'sessionGeneration',
       ),
       authGeneration = _requireCapabilityNonNegativeGeneration(
         authGeneration,
         'authGeneration',
       ),
       keyEpoch = _requireCapabilityKeyEpoch(keyEpoch),
       manifestDigest = _requireCapabilityManifestDigest(manifestDigest);

  final String accountUserId;
  final String deviceId;
  final int sessionGeneration;
  final int authGeneration;
  final int keyEpoch;
  final String manifestDigest;

  bool hasSameBinding(E2eeBackgroundSyncCapability other) {
    return accountUserId == other.accountUserId &&
        deviceId == other.deviceId &&
        sessionGeneration == other.sessionGeneration &&
        authGeneration == other.authGeneration &&
        keyEpoch == other.keyEpoch &&
        manifestDigest == other.manifestDigest;
  }

  bool matchesSession(CloudSyncAccountSession session) {
    return accountUserId == session.userId &&
        deviceId == session.deviceId &&
        keyEpoch == session.keyEpoch;
  }
}

abstract interface class E2eeBackgroundSyncTrustedCapabilityGate {
  /// 每次调用都必须从设备密钥保护的持久可信状态重新读取并完成验签。
  Future<E2eeBackgroundSyncCapability> loadVerifiedCapability(
    E2eeSyncExecutionBudget executionBudget,
  );
}

final class E2eeBackgroundSyncLimits {
  const E2eeBackgroundSyncLimits({
    this.maximumNetworkSteps = 17,
    this.maximumAttachmentBytes = 16 * 1024 * 1024,
    this.maximumDuration = const Duration(seconds: 25),
  });

  final int maximumNetworkSteps;
  final int maximumAttachmentBytes;
  final Duration maximumDuration;

  void validate() {
    if (maximumNetworkSteps < 1) {
      throw RangeError.range(
        maximumNetworkSteps,
        1,
        null,
        'maximumNetworkSteps',
      );
    }
    if (maximumAttachmentBytes < 0) {
      throw RangeError.range(
        maximumAttachmentBytes,
        0,
        null,
        'maximumAttachmentBytes',
      );
    }
    if (maximumDuration <= Duration.zero) {
      throw ArgumentError.value(maximumDuration, 'maximumDuration', '必须为正数');
    }
  }
}

enum E2eeBackgroundSyncDisposition {
  noSession,
  workspaceBusy,
  completed,
  blockedByKeyEpoch,
  budgetExhausted,
  authenticationRetired,
}

final class E2eeBackgroundSyncOutcome {
  const E2eeBackgroundSyncOutcome._(
    this.disposition, {
    this.report,
    this.budgetExhaustion,
  });

  const E2eeBackgroundSyncOutcome.noSession()
    : this._(E2eeBackgroundSyncDisposition.noSession);

  const E2eeBackgroundSyncOutcome.workspaceBusy()
    : this._(E2eeBackgroundSyncDisposition.workspaceBusy);

  const E2eeBackgroundSyncOutcome.completed(E2eeSyncCycleReport report)
    : this._(E2eeBackgroundSyncDisposition.completed, report: report);

  const E2eeBackgroundSyncOutcome.blockedByKeyEpoch(E2eeSyncCycleReport report)
    : this._(E2eeBackgroundSyncDisposition.blockedByKeyEpoch, report: report);

  const E2eeBackgroundSyncOutcome.budgetExhausted(
    E2eeSyncBudgetExhaustion reason,
  ) : this._(
        E2eeBackgroundSyncDisposition.budgetExhausted,
        budgetExhaustion: reason,
      );

  const E2eeBackgroundSyncOutcome.authenticationRetired()
    : this._(E2eeBackgroundSyncDisposition.authenticationRetired);

  final E2eeBackgroundSyncDisposition disposition;
  final E2eeSyncCycleReport? report;
  final E2eeSyncBudgetExhaustion? budgetExhaustion;
}

sealed class E2eeBackgroundWorkspaceAcquisition {
  const E2eeBackgroundWorkspaceAcquisition();
}

final class E2eeBackgroundWorkspaceBusy
    extends E2eeBackgroundWorkspaceAcquisition {
  const E2eeBackgroundWorkspaceBusy();
}

final class E2eeBackgroundWorkspaceAcquired
    extends E2eeBackgroundWorkspaceAcquisition {
  const E2eeBackgroundWorkspaceAcquired(this.workspace);

  final E2eeBackgroundSyncWorkspace workspace;
}

sealed class E2eeBackgroundContentAcquisition {
  const E2eeBackgroundContentAcquisition();
}

final class E2eeBackgroundContentBusy extends E2eeBackgroundContentAcquisition {
  const E2eeBackgroundContentBusy();
}

final class E2eeBackgroundContentAcquired
    extends E2eeBackgroundContentAcquisition {
  const E2eeBackgroundContentAcquired(this.content);

  final E2eeBackgroundSyncContent content;
}

abstract interface class E2eeBackgroundSyncHost {
  Future<E2eeBackgroundWorkspaceAcquisition> tryAcquireWorkspace(
    E2eeSyncExecutionBudget executionBudget,
  );
}

abstract interface class E2eeBackgroundSyncWorkspace {
  CloudSyncAccountSession? get session;

  Future<E2eeBackgroundContentAcquisition> tryAcquireContent(
    E2eeSyncExecutionBudget executionBudget,
  );

  Future<void> persistSessionTombstone();

  Future<void> closeWorkspaceLease();
}

abstract interface class E2eeBackgroundSyncContent {
  Future<E2eeSyncCycleReport> runOnce({
    required E2eeSyncExecutionBudget executionBudget,
  });

  void abortInFlightNetwork();

  Future<void> closeRuntime();

  Future<void> closeAccountLease();
}

/// 平台后台回调只需调用一次 [run]；工作区、密钥、数据库与网络所有权均在内部闭环。
final class E2eeBackgroundSyncRunner {
  factory E2eeBackgroundSyncRunner({
    required E2eeBackgroundSyncTrustedCapabilityGate capabilityGate,
    Directory? installationRoot,
  }) {
    return E2eeBackgroundSyncRunner._(
      _ProductionBackgroundSyncHost(installationRoot),
      capabilityGate,
    );
  }

  @visibleForTesting
  const E2eeBackgroundSyncRunner.forTesting(
    E2eeBackgroundSyncHost host, {
    E2eeBackgroundSyncTrustedCapabilityGate? capabilityGate,
  }) : this._(host, capabilityGate);

  const E2eeBackgroundSyncRunner._(this._host, this._capabilityGate);

  final E2eeBackgroundSyncHost _host;
  final E2eeBackgroundSyncTrustedCapabilityGate? _capabilityGate;

  Future<E2eeBackgroundSyncOutcome> run({
    E2eeBackgroundSyncLimits limits = const E2eeBackgroundSyncLimits(),
    E2eeSyncCancellationSignal? cancellationSignal,
  }) async {
    limits.validate();
    E2eeBackgroundSyncWorkspace? workspace;
    E2eeBackgroundSyncContent? content;
    final executionBudget = E2eeSyncExecutionBudget(
      maximumNetworkSteps: limits.maximumNetworkSteps,
      maximumAttachmentBytes: limits.maximumAttachmentBytes,
      maximumDuration: limits.maximumDuration,
      abortInFlightNetwork: () => content?.abortInFlightNetwork(),
      cancellationSignal: cancellationSignal,
    );
    try {
      var terminalRetirementAttempted = false;
      E2eeBackgroundSyncOutcome? outcome;
      E2eeBackgroundSyncCapability? expectedCapability;
      Object? primaryError;
      StackTrace? primaryStackTrace;

      try {
        executionBudget.checkCanContinue();
        final capabilityGate = _capabilityGate;
        if (capabilityGate != null) {
          expectedCapability = await capabilityGate.loadVerifiedCapability(
            executionBudget,
          );
          executionBudget.checkCanContinue();
        }
        final workspaceAcquisition = await _host.tryAcquireWorkspace(
          executionBudget,
        );
        switch (workspaceAcquisition) {
          case E2eeBackgroundWorkspaceBusy():
            outcome = const E2eeBackgroundSyncOutcome.workspaceBusy();
          case E2eeBackgroundWorkspaceAcquired(workspace: final acquired):
            workspace = acquired;
        }
        executionBudget.checkCanContinue();

        if (outcome == null) {
          final activeWorkspace = workspace!;
          final activeSession = activeWorkspace.session;
          if (activeSession == null) {
            outcome = const E2eeBackgroundSyncOutcome.noSession();
          } else {
            final capabilityGate = _capabilityGate;
            final expected = expectedCapability;
            if (capabilityGate != null && expected != null) {
              final current = await capabilityGate.loadVerifiedCapability(
                executionBudget,
              );
              executionBudget.checkCanContinue();
              if (!expected.hasSameBinding(current)) {
                throw StateError(
                  'e2ee_background_sync_capability_generation_changed',
                );
              }
              if (!current.matchesSession(activeSession)) {
                throw StateError(
                  'e2ee_background_sync_capability_session_mismatch',
                );
              }
            }
            final contentAcquisition = await activeWorkspace.tryAcquireContent(
              executionBudget,
            );
            switch (contentAcquisition) {
              case E2eeBackgroundContentBusy():
                outcome = const E2eeBackgroundSyncOutcome.workspaceBusy();
              case E2eeBackgroundContentAcquired(content: final acquired):
                content = acquired;
            }
            executionBudget.checkCanContinue();
          }
        }

        if (outcome == null) {
          final activeContent = content!;
          final activeWorkspace = workspace!;
          try {
            final report = await activeContent.runOnce(
              executionBudget: executionBudget,
            );
            outcome =
                report.disposition ==
                    E2eeSyncCycleDisposition.keyEpochUnavailable
                ? E2eeBackgroundSyncOutcome.blockedByKeyEpoch(report)
                : E2eeBackgroundSyncOutcome.completed(report);
          } on E2eeSyncBudgetExhausted catch (error) {
            outcome = E2eeBackgroundSyncOutcome.budgetExhausted(error.reason);
          } catch (error) {
            if (!isTerminalCloudSyncAuthenticationFailure(error)) rethrow;
            terminalRetirementAttempted = true;
            await retireTerminalCloudSyncSession(
              persistSessionTombstone: activeWorkspace.persistSessionTombstone,
              closeContentRuntime: activeContent.closeRuntime,
              releaseAccountLease: activeContent.closeAccountLease,
              releaseWorkspaceLease: activeWorkspace.closeWorkspaceLease,
            );
            executionBudget.checkCanContinue();
            outcome = const E2eeBackgroundSyncOutcome.authenticationRetired();
          }
        }
      } catch (error, stackTrace) {
        primaryError = error;
        primaryStackTrace = stackTrace;
      }

      if (!terminalRetirementAttempted) {
        final cleanup = _BackgroundCleanupAccumulator();
        if (content != null) {
          await cleanup.run(
            '关闭后台 E2EE 内容运行时失败',
            content.closeRuntime,
            executionBudget,
          );
          await cleanup.run(
            '释放后台账户业务租约失败',
            content.closeAccountLease,
            executionBudget,
          );
        }
        if (workspace != null) {
          await cleanup.run(
            '释放后台工作区租约失败',
            workspace.closeWorkspaceLease,
            executionBudget,
          );
        }
        if (primaryError == null && cleanup.error != null) {
          primaryError = cleanup.error;
          primaryStackTrace = cleanup.stackTrace;
        }
      }

      final error = primaryError;
      if (error != null) {
        Error.throwWithStackTrace(error, primaryStackTrace!);
      }
      return outcome!;
    } finally {
      executionBudget.dispose();
    }
  }
}

final class _ProductionBackgroundSyncHost implements E2eeBackgroundSyncHost {
  const _ProductionBackgroundSyncHost(this._installationRoot);

  final Directory? _installationRoot;

  @override
  Future<E2eeBackgroundWorkspaceAcquisition> tryAcquireWorkspace(
    E2eeSyncExecutionBudget executionBudget,
  ) async {
    executionBudget.checkCanContinue();
    try {
      final runtime = await AccountWorkspaceRuntime.bootstrap(
        installationRoot: _installationRoot,
      );
      return E2eeBackgroundWorkspaceAcquired(
        _ProductionBackgroundSyncWorkspace(runtime),
      );
    } on RestoreBusinessLeaseUnavailable {
      return const E2eeBackgroundWorkspaceBusy();
    }
  }
}

final class _ProductionBackgroundSyncWorkspace
    implements E2eeBackgroundSyncWorkspace {
  _ProductionBackgroundSyncWorkspace(this._workspaceRuntime);

  final AccountWorkspaceRuntime _workspaceRuntime;

  @override
  CloudSyncAccountSession? get session => _workspaceRuntime.current.session;

  @override
  Future<E2eeBackgroundContentAcquisition> tryAcquireContent(
    E2eeSyncExecutionBudget executionBudget,
  ) async {
    executionBudget.checkCanContinue();
    final activeSession = session;
    if (activeSession == null) {
      throw StateError('e2ee_background_sync_session_missing');
    }
    final appDataDirectory = _workspaceRuntime.current.dataDirectory;
    late final RestoreBusinessLease accountLease;
    try {
      accountLease = await RestoreBusinessLease.acquire(
        appDataDirectory: appDataDirectory,
      );
    } on RestoreBusinessLeaseUnavailable {
      return const E2eeBackgroundContentBusy();
    }

    CloudSyncClient? client;
    E2eeChatContentRuntime? runtime;
    try {
      executionBudget.checkCanContinue();
      final databaseCipher = SqlCipherDatabaseKey.forWorkspace(
        _workspaceRuntime.current.workspaceKey,
      );
      executionBudget.checkCanContinue();
      await _workspaceRuntime.discardPlaintextLocalState();
      executionBudget.checkCanContinue();
      final restoreOutcome =
          await RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: appDataDirectory,
            cipher: databaseCipher,
            businessLease: accountLease,
          );
      executionBudget.checkCanContinue();
      await DatabaseInstallationGate.ensureReady(
        appDataDirectory: appDataDirectory,
        cipher: databaseCipher,
        allowDatabaseIdentityChange:
            restoreOutcome?.selectedComponents.contains(
              RestoreComponent.database,
            ) ??
            false,
      );
      executionBudget.checkCanContinue();

      final databaseGateway = ChatDatabaseGateway(cipher: databaseCipher);
      final activeClient = CloudSyncClient(token: activeSession.token);
      client = activeClient;
      final activeRuntime = E2eeChatContentRuntime.takeHeadlessOwnership(
        session: activeSession,
        deviceStateStore: DeviceStateBlobStore(
          installationRoot: _workspaceRuntime.installationRoot,
        ),
        secureCore: const KelivoSecureCore(),
        databaseGateway: databaseGateway,
        databaseFile: File(
          '${appDataDirectory.path}${Platform.pathSeparator}'
          '${AppDatabase.databaseFileName}',
        ),
        client: activeClient,
      );
      runtime = activeRuntime;
      return E2eeBackgroundContentAcquired(
        _ProductionBackgroundSyncContent(
          runtime: activeRuntime,
          client: activeClient,
          accountLease: accountLease,
        ),
      );
    } catch (error, stackTrace) {
      final ownedRuntime = runtime;
      final ownedClient = client;
      await rethrowCloudSyncPrimaryAfterCleanup(
        primaryError: error,
        primaryStackTrace: stackTrace,
        cleanupSteps: <CloudSyncFailureCleanupStep>[
          if (ownedRuntime != null)
            CloudSyncFailureCleanupStep(
              operation: '后台 E2EE 内容构造失败后的运行时关闭失败',
              cleanup: ownedRuntime.close,
            ),
          if (ownedClient != null)
            CloudSyncFailureCleanupStep(
              operation: '后台 E2EE 内容构造失败后的网络客户端关闭失败',
              cleanup: () async {
                ownedClient.close(force: true);
              },
            ),
          CloudSyncFailureCleanupStep(
            operation: '后台 E2EE 内容构造失败后的账户租约释放失败',
            cleanup: accountLease.close,
          ),
        ],
      );
    }
  }

  @override
  Future<void> persistSessionTombstone() async {
    await _workspaceRuntime.signOut();
  }

  @override
  Future<void> closeWorkspaceLease() => _workspaceRuntime.close();
}

final class _ProductionBackgroundSyncContent
    implements E2eeBackgroundSyncContent {
  _ProductionBackgroundSyncContent({
    required this._runtime,
    required this._client,
    required this._accountLease,
  });

  final E2eeChatContentRuntime _runtime;
  final CloudSyncClient _client;
  final RestoreBusinessLease _accountLease;

  @override
  Future<E2eeSyncCycleReport> runOnce({
    required E2eeSyncExecutionBudget executionBudget,
  }) {
    executionBudget.checkCanContinue();
    return _runtime.runSingleCycle(executionBudget);
  }

  @override
  void abortInFlightNetwork() => _client.close(force: true);

  @override
  Future<void> closeRuntime() => _runtime.close();

  @override
  Future<void> closeAccountLease() => _accountLease.close();
}

final class _BackgroundCleanupAccumulator {
  Object? error;
  StackTrace? stackTrace;

  Future<void> run(
    String operation,
    Future<void> Function() action,
    E2eeSyncExecutionBudget executionBudget,
  ) async {
    try {
      await action();
    } catch (nextError, nextStackTrace) {
      _record(operation, nextError, nextStackTrace);
    }
    try {
      executionBudget.checkCanContinue();
    } catch (nextError, nextStackTrace) {
      _record('后台 E2EE 清理超过系统执行预算', nextError, nextStackTrace);
    }
  }

  void _record(String operation, Object nextError, StackTrace nextStackTrace) {
    if (error == null) {
      error = nextError;
      stackTrace = nextStackTrace;
    } else {
      developer.log(
        operation,
        name: 'Kelivo.E2eeBackgroundSyncRunner',
        level: 1000,
        error: nextError,
        stackTrace: nextStackTrace,
      );
    }
  }
}

String _requireCapabilityIdentifier(String value, String field) {
  if (value.isEmpty || value.trim() != value) {
    throw FormatException('$field 必须为非空规范标识符');
  }
  return value;
}

int _requireCapabilityPositiveGeneration(int value, String field) {
  if (value < 1 || value > 0x7fffffff) {
    throw FormatException('$field 必须位于正 int32 范围');
  }
  return value;
}

int _requireCapabilityNonNegativeGeneration(int value, String field) {
  if (value < 0 || value > 0x7fffffff) {
    throw FormatException('$field 必须位于非负 int32 范围');
  }
  return value;
}

int _requireCapabilityKeyEpoch(int value) {
  if (value < 1 || value > 0xffffffff) {
    throw const FormatException('keyEpoch 必须位于正 uint32 范围');
  }
  return value;
}

String _requireCapabilityManifestDigest(String value) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw const FormatException('manifestDigest 必须为规范 SHA-256 十六进制摘要');
  }
  return value;
}
