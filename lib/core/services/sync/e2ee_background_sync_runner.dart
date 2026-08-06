import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';

import '../../../utils/app_directories.dart';
import '../../database/app_database.dart';
import '../../database/chat_database_gateway.dart';
import '../../database/database_installation_gate.dart';
import '../../database/sqlcipher_database_key.dart';
import '../backup/plaintext_remote_backup_retirement.dart';
import '../backup/restore_business_lease.dart';
import '../backup/restore_receipt.dart';
import '../backup/restore_startup_gate.dart';
import '../workspace/account_workspace_runtime.dart';
import '../workspace/device_state_blob_store.dart';
import '../workspace/installation_operation_lease.dart';
import 'cloud_sync_client.dart';
import 'cloud_sync_terminal_session_retirement.dart';
import 'cloud_sync_types.dart';
import 'e2ee_account_authenticator.dart';
import 'e2ee_chat_content_runtime.dart';
import 'e2ee_device_revocation_runtime.dart';
import 'e2ee_sync_execution_budget.dart';
import 'e2ee_sync_scheduler.dart';
import 'e2ee_trusted_self_revocation_processor.dart';
import '../workspace/e2ee_data_rekey_stage_store.dart';

final class E2eeBackgroundSyncLimits {
  const E2eeBackgroundSyncLimits({
    this.maximumNetworkSteps = 17,
    this.maximumAttachmentBytes = 16 * 1024 * 1024,
    this.maximumDuration = const Duration(seconds: 25),
    this.maximumShutdownDuration = const Duration(seconds: 2),
  });

  final int maximumNetworkSteps;
  final int maximumAttachmentBytes;
  final Duration maximumDuration;
  final Duration maximumShutdownDuration;

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
    if (maximumShutdownDuration <= Duration.zero) {
      throw ArgumentError.value(
        maximumShutdownDuration,
        'maximumShutdownDuration',
        '必须为正数',
      );
    }
  }
}

enum E2eeBackgroundSyncDisposition {
  noSession,
  workspaceBusy,
  completed,
  blockedByKeyEpoch,
  securityStateChanged,
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

  const E2eeBackgroundSyncOutcome.securityStateChanged(
    E2eeSyncCycleReport report,
  ) : this._(
        E2eeBackgroundSyncDisposition.securityStateChanged,
        report: report,
      );

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

  Future<void> retirePlaintextState(E2eeSyncExecutionBudget executionBudget);

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
  factory E2eeBackgroundSyncRunner({Directory? installationRoot}) {
    return E2eeBackgroundSyncRunner._(
      _ProductionBackgroundSyncHost(installationRoot),
    );
  }

  @visibleForTesting
  const E2eeBackgroundSyncRunner.forTesting(E2eeBackgroundSyncHost host)
    : this._(host);

  const E2eeBackgroundSyncRunner._(this._host);

  final E2eeBackgroundSyncHost _host;

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
      maximumShutdownDuration: limits.maximumShutdownDuration,
      abortInFlightNetwork: () => content?.abortInFlightNetwork(),
      cancellationSignal: cancellationSignal,
    );
    try {
      var terminalRetirementAttempted = false;
      E2eeBackgroundSyncOutcome? outcome;
      Object? primaryError;
      StackTrace? primaryStackTrace;

      try {
        executionBudget.checkCanContinue();
        final workspaceAcquisition = await executionBudget.runBoundedStep(
          operation: (_) => _host.tryAcquireWorkspace(executionBudget),
          releaseInterruptedValue: _releaseInterruptedWorkspace,
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
          final interruptedCleanup =
              _InterruptedWorkspaceRetirementCleanupBarrier(
                workspace: activeWorkspace,
                transferWorkspaceOwnership: () {
                  if (!identical(workspace, activeWorkspace)) {
                    throw StateError(
                      'e2ee_background_workspace_ownership_mismatch',
                    );
                  }
                  workspace = null;
                },
              );
          final retirementAttempt = await executionBudget.runBoundedStep(
            operation: (_) => _captureWorkspaceRetirement(
              activeWorkspace.retirePlaintextState(executionBudget),
            ),
            releaseInterruptedValue: interruptedCleanup.release,
            transferInterruptedOwnership:
                interruptedCleanup.takeWorkspaceOwnership,
          );
          if (retirementAttempt case _BackgroundWorkspaceRetirementFailed(
            :final error,
            :final stackTrace,
          )) {
            Error.throwWithStackTrace(error, stackTrace);
          }
          executionBudget.checkCanContinue();
          final activeSession = activeWorkspace.session;
          if (activeSession == null) {
            outcome = const E2eeBackgroundSyncOutcome.noSession();
          } else {
            final interruptedCleanup =
                _InterruptedContentAcquisitionCleanupBarrier(
                  workspace: activeWorkspace,
                  transferWorkspaceOwnership: () {
                    if (!identical(workspace, activeWorkspace)) {
                      throw StateError(
                        'e2ee_background_workspace_ownership_mismatch',
                      );
                    }
                    workspace = null;
                  },
                );
            final contentAttempt = await executionBudget.runBoundedStep(
              operation: (_) => _captureContentAcquisition(
                activeWorkspace.tryAcquireContent(executionBudget),
              ),
              releaseInterruptedValue: interruptedCleanup.release,
              transferInterruptedOwnership:
                  interruptedCleanup.takeWorkspaceOwnership,
            );
            final E2eeBackgroundContentAcquisition contentAcquisition;
            switch (contentAttempt) {
              case _BackgroundContentAcquisitionCompleted(
                acquisition: final value,
              ):
                contentAcquisition = value;
              case _BackgroundContentAcquisitionFailed(
                :final error,
                :final stackTrace,
              ):
                Error.throwWithStackTrace(error, stackTrace);
            }
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
            outcome = switch (report.disposition) {
              E2eeSyncCycleDisposition.keyEpochUnavailable =>
                E2eeBackgroundSyncOutcome.blockedByKeyEpoch(report),
              E2eeSyncCycleDisposition.securityStateChanged =>
                E2eeBackgroundSyncOutcome.securityStateChanged(report),
              E2eeSyncCycleDisposition.completed =>
                E2eeBackgroundSyncOutcome.completed(report),
            };
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
              executeStep: executionBudget.runCleanupStep,
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
        final activeWorkspace = workspace;
        if (activeWorkspace != null) {
          await cleanup.run(
            '释放后台工作区租约失败',
            activeWorkspace.closeWorkspaceLease,
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

Future<void> _releaseInterruptedWorkspace(
  E2eeBackgroundWorkspaceAcquisition acquisition,
) async {
  if (acquisition case E2eeBackgroundWorkspaceAcquired(
    workspace: final value,
  )) {
    await value.closeWorkspaceLease();
  }
}

sealed class _BackgroundWorkspaceRetirementAttempt {
  const _BackgroundWorkspaceRetirementAttempt();
}

final class _BackgroundWorkspaceRetirementCompleted
    extends _BackgroundWorkspaceRetirementAttempt {
  const _BackgroundWorkspaceRetirementCompleted();
}

final class _BackgroundWorkspaceRetirementFailed
    extends _BackgroundWorkspaceRetirementAttempt {
  const _BackgroundWorkspaceRetirementFailed(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

Future<_BackgroundWorkspaceRetirementAttempt> _captureWorkspaceRetirement(
  Future<void> retirement,
) async {
  try {
    await retirement;
    return const _BackgroundWorkspaceRetirementCompleted();
  } catch (error, stackTrace) {
    return _BackgroundWorkspaceRetirementFailed(error, stackTrace);
  }
}

final class _InterruptedWorkspaceRetirementCleanupBarrier {
  _InterruptedWorkspaceRetirementCleanupBarrier({
    required this.workspace,
    required this.transferWorkspaceOwnership,
  });

  final E2eeBackgroundSyncWorkspace workspace;
  final void Function() transferWorkspaceOwnership;
  bool _ownershipTransferred = false;
  Future<void>? _cleanup;

  void takeWorkspaceOwnership() {
    if (_ownershipTransferred) return;
    _ownershipTransferred = true;
    transferWorkspaceOwnership();
  }

  Future<void> release(_BackgroundWorkspaceRetirementAttempt attempt) {
    if (!_ownershipTransferred) {
      throw StateError('e2ee_background_retirement_cleanup_without_ownership');
    }
    return _cleanup ??= _releaseOnce(attempt);
  }

  Future<void> _releaseOnce(
    _BackgroundWorkspaceRetirementAttempt attempt,
  ) async {
    Object? primaryError;
    StackTrace? primaryStackTrace;
    if (attempt case _BackgroundWorkspaceRetirementFailed(
      :final error,
      :final stackTrace,
    )) {
      primaryError = error;
      primaryStackTrace = stackTrace;
    }
    try {
      await workspace.closeWorkspaceLease();
    } catch (error, stackTrace) {
      primaryError ??= error;
      primaryStackTrace ??= stackTrace;
    }
    final error = primaryError;
    if (error != null) {
      Error.throwWithStackTrace(error, primaryStackTrace!);
    }
  }
}

sealed class _BackgroundContentAcquisitionAttempt {
  const _BackgroundContentAcquisitionAttempt();
}

final class _BackgroundContentAcquisitionCompleted
    extends _BackgroundContentAcquisitionAttempt {
  const _BackgroundContentAcquisitionCompleted(this.acquisition);

  final E2eeBackgroundContentAcquisition acquisition;
}

final class _BackgroundContentAcquisitionFailed
    extends _BackgroundContentAcquisitionAttempt {
  const _BackgroundContentAcquisitionFailed(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

Future<_BackgroundContentAcquisitionAttempt> _captureContentAcquisition(
  Future<E2eeBackgroundContentAcquisition> acquisition,
) async {
  try {
    return _BackgroundContentAcquisitionCompleted(await acquisition);
  } catch (error, stackTrace) {
    return _BackgroundContentAcquisitionFailed(error, stackTrace);
  }
}

final class _InterruptedContentAcquisitionCleanupBarrier {
  _InterruptedContentAcquisitionCleanupBarrier({
    required this.workspace,
    required this.transferWorkspaceOwnership,
  });

  final E2eeBackgroundSyncWorkspace workspace;
  final void Function() transferWorkspaceOwnership;
  bool _ownershipTransferred = false;
  Future<void>? _cleanup;

  void takeWorkspaceOwnership() {
    if (_ownershipTransferred) return;
    _ownershipTransferred = true;
    transferWorkspaceOwnership();
  }

  Future<void> release(_BackgroundContentAcquisitionAttempt attempt) {
    if (!_ownershipTransferred) {
      throw StateError('e2ee_background_content_cleanup_without_ownership');
    }
    return _cleanup ??= _releaseOnce(attempt);
  }

  Future<void> _releaseOnce(
    _BackgroundContentAcquisitionAttempt attempt,
  ) async {
    Object? primaryError;
    StackTrace? primaryStackTrace;

    Future<void> run(String operation, Future<void> Function() action) async {
      try {
        await action();
      } catch (error, stackTrace) {
        if (primaryError == null) {
          primaryError = error;
          primaryStackTrace = stackTrace;
        } else {
          developer.log(
            'E2EE 后台同步后续资源清理失败',
            name: 'Kelivo.E2eeBackgroundSyncRunner',
            level: 1000,
          );
        }
      }
    }

    switch (attempt) {
      case _BackgroundContentAcquisitionCompleted(
        acquisition: E2eeBackgroundContentAcquired(content: final content),
      ):
        await run('关闭迟到的后台 E2EE 内容运行时失败', content.closeRuntime);
        await run('释放迟到的后台账户业务租约失败', content.closeAccountLease);
      case _BackgroundContentAcquisitionCompleted():
        break;
      case _BackgroundContentAcquisitionFailed(:final error, :final stackTrace):
        primaryError = error;
        primaryStackTrace = stackTrace;
    }
    await run('释放迟到内容获取持有的工作区租约失败', workspace.closeWorkspaceLease);

    final error = primaryError;
    if (error != null) {
      Error.throwWithStackTrace(error, primaryStackTrace!);
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
    final installationRoot =
        _installationRoot ??
        await AppDirectories.getInstallationRootDirectory();
    late final InstallationBusinessLease installationBusinessLease;
    try {
      installationBusinessLease = await InstallationOperationLease(
        installationRoot: installationRoot,
      ).acquireBusiness();
    } on InstallationBusinessLeaseUnavailable {
      return const E2eeBackgroundWorkspaceBusy();
    }
    KelivoInstallationRootSession? installationRootSession;
    try {
      executionBudget.checkCanContinue();
      installationRootSession = await const KelivoSecureCore()
          .openInstallationRoot(installationRoot.path);
      executionBudget.checkCanContinue();
      final runtime = await AccountWorkspaceRuntime.bootstrap(
        installationRoot: installationRoot,
      );
      return E2eeBackgroundWorkspaceAcquired(
        _ProductionBackgroundSyncWorkspace(
          runtime,
          installationBusinessLease,
          installationRootSession,
        ),
      );
    } on RestoreBusinessLeaseUnavailable {
      await installationRootSession?.close();
      await installationBusinessLease.close();
      return const E2eeBackgroundWorkspaceBusy();
    } catch (error, stackTrace) {
      final sessionToClose = installationRootSession;
      await rethrowCloudSyncPrimaryAfterCleanup(
        primaryError: error,
        primaryStackTrace: stackTrace,
        cleanupSteps: <CloudSyncFailureCleanupStep>[
          if (sessionToClose != null)
            CloudSyncFailureCleanupStep(
              operation: '后台工作区构造失败后的受管安装根会话释放失败',
              cleanup: sessionToClose.close,
            ),
          CloudSyncFailureCleanupStep(
            operation: '后台工作区构造失败后的安装业务租约释放失败',
            cleanup: installationBusinessLease.close,
          ),
        ],
      );
    }
  }
}

final class _ProductionBackgroundSyncWorkspace
    implements E2eeBackgroundSyncWorkspace {
  _ProductionBackgroundSyncWorkspace(
    this._workspaceRuntime,
    this._installationBusinessLease,
    this._installationRootSession,
  );

  final AccountWorkspaceRuntime _workspaceRuntime;
  final InstallationBusinessLease _installationBusinessLease;
  final KelivoInstallationRootSession _installationRootSession;

  @override
  CloudSyncAccountSession? get session => _workspaceRuntime.current.session;

  @override
  Future<void> retirePlaintextState(
    E2eeSyncExecutionBudget executionBudget,
  ) async {
    executionBudget.checkCanContinue();
    await PlaintextPersistenceRetirement.retireCurrentInstallation(
      workspaceRuntime: _workspaceRuntime,
      retirePersistentLogs: _installationRootSession.retirePersistentLogs,
    );
    executionBudget.checkCanContinue();
  }

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
        retireAttachmentStaging:
            _installationRootSession.retireAttachmentStaging,
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
      final deviceStateStore = DeviceStateBlobStore(
        installationRoot: _workspaceRuntime.installationRoot,
      );
      const secureCore = KelivoSecureCore();
      final databaseFile = File(
        '${appDataDirectory.path}${Platform.pathSeparator}'
        '${AppDatabase.databaseFileName}',
      );
      final revocationRuntime =
          E2eeDeviceRevocationProductionRuntime.create(
            baseUrl: activeSession.baseUrl,
            normalizedLoginName: activeSession.loginName,
            deviceStateStore: deviceStateStore,
            secureCore: secureCore,
            databaseGateway: databaseGateway,
            databaseFile: databaseFile,
            rotationTransport: activeClient,
            dataRekeyTransport: activeClient,
            stageStore: E2eeDataRekeyStageStore(
              installationRoot: _workspaceRuntime.installationRoot,
            ),
          );
      final selfRevocationProcessor = E2eeTrustedSelfRevocationProcessor(
        baseUrl: activeSession.baseUrl,
        normalizedLoginName: activeSession.loginName,
        deviceStateStore: deviceStateStore,
        secureCore: secureCore,
        databaseGateway: databaseGateway,
        databaseFile: databaseFile,
        selfRevocationTransport: activeClient,
        revocationRuntime: revocationRuntime,
      );
      final activeRuntime = E2eeChatContentRuntime.takeHeadlessOwnership(
        session: activeSession,
        deviceStateStore: deviceStateStore,
        secureCore: secureCore,
        databaseGateway: databaseGateway,
        databaseFile: databaseFile,
        client: activeClient,
        securityMaintenance: (budget) async {
          final disposition = await selfRevocationProcessor.runOnce(
            session: activeSession,
            executionBudget: budget,
          );
          return disposition ==
                  E2eeTrustedSelfRevocationProcessDisposition
                      .securityStateChanged
              ? E2eeSyncSecurityMaintenanceDisposition.securityStateChanged
              : E2eeSyncSecurityMaintenanceDisposition.continueSync;
        },
      );
      activeRuntime.bindSecurityBootstrapCommitHandler((pendingSession) {
        return _commitSecurityBootstrap(pendingSession, activeClient);
      });
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
  Future<void> closeWorkspaceLease() async {
    try {
      await _workspaceRuntime.close();
      await _installationRootSession.close();
    } catch (error, stackTrace) {
      await rethrowCloudSyncPrimaryAfterCleanup(
        primaryError: error,
        primaryStackTrace: stackTrace,
        cleanupSteps: <CloudSyncFailureCleanupStep>[
          CloudSyncFailureCleanupStep(
            operation: '后台工作区关闭失败后的受管安装根会话释放失败',
            cleanup: _installationRootSession.close,
          ),
          CloudSyncFailureCleanupStep(
            operation: '后台工作区关闭失败后的安装业务租约释放失败',
            cleanup: _installationBusinessLease.close,
          ),
        ],
      );
    }
    await _installationBusinessLease.close();
  }

  Future<void> _commitSecurityBootstrap(
    CloudSyncAccountSession pendingSession,
    CloudSyncAccountClient client,
  ) async {
    final bootstrap = pendingSession.securityBootstrap;
    final current = session;
    if (bootstrap == null ||
        current == null ||
        current.securityBootstrap == null ||
        current.accountScope != pendingSession.accountScope ||
        current.deviceId != pendingSession.deviceId ||
        current.authGeneration != pendingSession.authGeneration ||
        current.sessionGeneration != pendingSession.sessionGeneration ||
        current.token.value != pendingSession.token.value) {
      throw StateError('后台安全 bootstrap 提交会话与当前工作区不匹配');
    }
    final authentication = E2eeAccountAuthenticator(
      baseUrl: pendingSession.baseUrl,
      accountClient: client,
      deviceStateStore: DeviceStateBlobStore(
        installationRoot: _workspaceRuntime.installationRoot,
      ),
      secureCore: const KelivoSecureCore(),
    );
    final authenticatedSession = pendingSession.toAuthenticatedSession();
    switch (bootstrap.source) {
      case CloudSyncSecurityBootstrapSource.firstRegistration:
        await authentication.confirmFirstDeviceRegistration(
          loginName: pendingSession.loginName,
          session: authenticatedSession,
        );
        break;
      case CloudSyncSecurityBootstrapSource.pairing:
        await authentication.confirmDevicePairing(
          loginName: pendingSession.loginName,
          session: authenticatedSession,
        );
        break;
    }
    final binding = await _workspaceRuntime.bindAccount(
      pendingSession.withoutSecurityBootstrap(),
    );
    if (binding is! AccountWorkspaceRetained) {
      throw StateError('后台安全 bootstrap 只能在当前账户工作区内提交');
    }
  }
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
      await executionBudget.runCleanupStep(action);
    } catch (nextError, nextStackTrace) {
      _record(operation, nextError, nextStackTrace);
    }
  }

  void _record(String operation, Object nextError, StackTrace nextStackTrace) {
    if (error == null) {
      error = nextError;
      stackTrace = nextStackTrace;
    } else {
      developer.log(
        'E2EE 后台同步失败后的后续资源清理失败',
        name: 'Kelivo.E2eeBackgroundSyncRunner',
        level: 1000,
      );
    }
  }
}
