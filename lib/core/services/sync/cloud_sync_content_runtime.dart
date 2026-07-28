abstract interface class CloudSyncContentRuntime {
  Future<void> initialize();

  Future<void> close();
}
