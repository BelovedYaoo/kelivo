import 'cloud_sync_types.dart';

typedef CloudSyncTerminalAuthenticationHandler =
    Future<void> Function(CloudSyncException failure, StackTrace stackTrace);

abstract interface class CloudSyncContentRuntime {
  void bindTerminalAuthenticationHandler(
    CloudSyncTerminalAuthenticationHandler handler,
  );

  Future<void> initialize();

  Future<void> close();
}
