import 'dart:developer' as developer;

import 'cloud_sync_types.dart';

typedef CloudSyncRetirementStep = Future<void> Function();
typedef CloudSyncRetirementStepExecutor =
    Future<void> Function(CloudSyncRetirementStep step);

final class CloudSyncFailureCleanupStep {
  const CloudSyncFailureCleanupStep({
    required this.operation,
    required this.cleanup,
  });

  final String operation;
  final CloudSyncRetirementStep cleanup;
}

bool isTerminalCloudSyncAuthenticationFailure(Object error) {
  return error is CloudSyncException &&
      !error.retryable &&
      (error.kind == CloudSyncFailureKind.unauthenticated ||
          error.kind == CloudSyncFailureKind.forbidden);
}

Future<Never> rethrowCloudSyncPrimaryAfterCleanup({
  required Object primaryError,
  required StackTrace primaryStackTrace,
  required Iterable<CloudSyncFailureCleanupStep> cleanupSteps,
}) async {
  for (final step in cleanupSteps) {
    try {
      await step.cleanup();
    } catch (_) {
      developer.log(
        '云同步终止会话清理步骤失败',
        name: 'Kelivo.CloudSyncSessionRetirement',
        level: 1000,
      );
    }
  }
  Error.throwWithStackTrace(primaryError, primaryStackTrace);
}

/// 固定终止认证的耐久顺序，并在某一步失败后继续释放后续所有权。
Future<void> retireTerminalCloudSyncSession({
  required CloudSyncRetirementStep persistSessionTombstone,
  required CloudSyncRetirementStep closeContentRuntime,
  required CloudSyncRetirementStep releaseAccountLease,
  required CloudSyncRetirementStep releaseWorkspaceLease,
  CloudSyncRetirementStepExecutor? executeStep,
}) async {
  Object? primaryError;
  StackTrace? primaryStackTrace;

  Future<void> run(String operation, CloudSyncRetirementStep action) async {
    try {
      final executor = executeStep;
      if (executor == null) {
        await action();
      } else {
        await executor(action);
      }
    } catch (error, stackTrace) {
      if (primaryError == null) {
        primaryError = error;
        primaryStackTrace = stackTrace;
        return;
      }
      developer.log(
        '云同步终止会话后续清理步骤失败',
        name: 'Kelivo.CloudSyncSessionRetirement',
        level: 1000,
      );
    }
  }

  await run('终止认证后持久清除账户会话失败', persistSessionTombstone);
  await run('终止认证后关闭内容运行时失败', closeContentRuntime);
  await run('终止认证后释放账户业务租约失败', releaseAccountLease);
  await run('终止认证后释放工作区租约失败', releaseWorkspaceLease);

  final error = primaryError;
  if (error != null) {
    Error.throwWithStackTrace(error, primaryStackTrace!);
  }
}
