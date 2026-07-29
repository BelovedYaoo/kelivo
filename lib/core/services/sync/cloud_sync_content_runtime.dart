import 'cloud_sync_types.dart';

typedef CloudSyncTerminalAuthenticationHandler =
    Future<void> Function(CloudSyncException failure, StackTrace stackTrace);
typedef CloudSyncSecurityBootstrapCommitHandler =
    Future<void> Function(CloudSyncAccountSession session);

abstract interface class CloudSyncContentRuntime {
  void bindSecurityBootstrapCommitHandler(
    CloudSyncSecurityBootstrapCommitHandler handler,
  );

  void bindTerminalAuthenticationHandler(
    CloudSyncTerminalAuthenticationHandler handler,
  );

  Future<void> initialize();

  Future<void> close();
}
