import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../backup/restore_business_lease.dart';
import '../workspace/account_workspace_runtime.dart';
import 'cloud_sync_terminal_session_retirement.dart';
import 'cloud_sync_types.dart';
import 'e2ee_sync_execution_budget.dart';
import 'e2ee_sync_scheduler.dart';

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
          final activeSession = activeWorkspace.session;
          if (activeSession == null) {
            outcome = const E2eeBackgroundSyncOutcome.noSession();
          } else {
            final contentAcquisition = await executionBudget.runBoundedStep(
              operation: (_) =>
                  activeWorkspace.tryAcquireContent(executionBudget),
              releaseInterruptedValue: _releaseInterruptedContent,
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

Future<void> _releaseInterruptedWorkspace(
  E2eeBackgroundWorkspaceAcquisition acquisition,
) async {
  if (acquisition case E2eeBackgroundWorkspaceAcquired(
    workspace: final value,
  )) {
    await value.closeWorkspaceLease();
  }
}

Future<void> _releaseInterruptedContent(
  E2eeBackgroundContentAcquisition acquisition,
) async {
  if (acquisition case E2eeBackgroundContentAcquired(content: final value)) {
    await Future.wait<void>(<Future<void>>[
      value.closeRuntime(),
      value.closeAccountLease(),
    ]);
  }
}

abstract interface class _E2eeBackgroundVerifiedContentFactory {
  Future<E2eeBackgroundContentAcquisition> tryAcquireVerifiedContent({
    required AccountWorkspaceRuntime workspaceRuntime,
    required E2eeSyncExecutionBudget executionBudget,
  });
}

_E2eeBackgroundVerifiedContentFactory? _createVerifiedContentFactory() {
  // schema 21 必须在同一步骤内验证设备绑定并返回内容所有权，接线前禁止生产执行。
  return null;
}

final class E2eeBackgroundProductionRunnerFactory {
  E2eeBackgroundProductionRunnerFactory._(this._verifiedContentFactory);

  final _E2eeBackgroundVerifiedContentFactory _verifiedContentFactory;

  static E2eeBackgroundProductionRunnerFactory? tryCreate() {
    final verifiedContentFactory = _createVerifiedContentFactory();
    if (verifiedContentFactory == null) return null;
    return E2eeBackgroundProductionRunnerFactory._(verifiedContentFactory);
  }

  E2eeBackgroundSyncRunner createRunner() {
    return E2eeBackgroundSyncRunner._(
      _ProductionBackgroundSyncHost(_verifiedContentFactory),
    );
  }
}

final class _ProductionBackgroundSyncHost implements E2eeBackgroundSyncHost {
  const _ProductionBackgroundSyncHost(this._verifiedContentFactory);

  final _E2eeBackgroundVerifiedContentFactory _verifiedContentFactory;

  @override
  Future<E2eeBackgroundWorkspaceAcquisition> tryAcquireWorkspace(
    E2eeSyncExecutionBudget executionBudget,
  ) async {
    executionBudget.checkCanContinue();
    try {
      final runtime = await AccountWorkspaceRuntime.bootstrap();
      return E2eeBackgroundWorkspaceAcquired(
        _ProductionBackgroundSyncWorkspace(runtime, _verifiedContentFactory),
      );
    } on RestoreBusinessLeaseUnavailable {
      return const E2eeBackgroundWorkspaceBusy();
    }
  }
}

final class _ProductionBackgroundSyncWorkspace
    implements E2eeBackgroundSyncWorkspace {
  _ProductionBackgroundSyncWorkspace(
    this._workspaceRuntime,
    this._verifiedContentFactory,
  );

  final AccountWorkspaceRuntime _workspaceRuntime;
  final _E2eeBackgroundVerifiedContentFactory _verifiedContentFactory;

  @override
  CloudSyncAccountSession? get session => _workspaceRuntime.current.session;

  @override
  Future<E2eeBackgroundContentAcquisition> tryAcquireContent(
    E2eeSyncExecutionBudget executionBudget,
  ) {
    return _verifiedContentFactory.tryAcquireVerifiedContent(
      workspaceRuntime: _workspaceRuntime,
      executionBudget: executionBudget,
    );
  }

  @override
  Future<void> persistSessionTombstone() async {
    await _workspaceRuntime.signOut();
  }

  @override
  Future<void> closeWorkspaceLease() => _workspaceRuntime.close();
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
        operation,
        name: 'Kelivo.E2eeBackgroundSyncRunner',
        level: 1000,
        error: nextError,
        stackTrace: nextStackTrace,
      );
    }
  }
}
