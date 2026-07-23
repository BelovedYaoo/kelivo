import 'sync_codec.dart';

abstract interface class SyncWriteExecutor {
  Future<T> runLocal<T>({
    required SyncEntityKey key,
    required Future<T> Function() write,
  });

  Future<T> runLocalBatch<T>({
    required Iterable<SyncEntityKey> keys,
    required Future<T> Function() write,
  });
}

final class LocalOnlySyncWriteExecutor implements SyncWriteExecutor {
  const LocalOnlySyncWriteExecutor();

  @override
  Future<T> runLocal<T>({
    required SyncEntityKey key,
    required Future<T> Function() write,
  }) {
    return Future<T>.sync(write);
  }

  @override
  Future<T> runLocalBatch<T>({
    required Iterable<SyncEntityKey> keys,
    required Future<T> Function() write,
  }) {
    return Future<T>.sync(write);
  }
}

final class UntrackedSyncWriteExecutor implements SyncWriteExecutor {
  const UntrackedSyncWriteExecutor.forTests();

  @override
  Future<T> runLocal<T>({
    required SyncEntityKey key,
    required Future<T> Function() write,
  }) {
    return write();
  }

  @override
  Future<T> runLocalBatch<T>({
    required Iterable<SyncEntityKey> keys,
    required Future<T> Function() write,
  }) {
    return write();
  }
}
