import '../../database/chat_database_repository.dart';
import 'e2ee_config_sync_adapter.dart';
import 'e2ee_sync_outbox.dart';
import 'e2ee_sync_pull_types.dart';
import 'sync_codec.dart';

abstract interface class E2eeConfigSyncBinding {
  Future<void> initialize(E2eeConfigVaultCommands commands);

  Future<E2eeSyncEntitySnapshot> readSnapshot(SyncEntityKey entityKey);

  Future<T> runLocalWrite<T>({
    required Iterable<SyncEntityKey> configKeys,
    required Future<T> Function(Future<T> Function() write) transaction,
    required Future<T> Function() write,
  });

  Future<T> runRemotePull<T>(Future<T> Function() pull);

  Future<void> applyTransactional(List<E2eeSyncPulledChange> applicableChanges);
}

/// 后台同步只维护 SQLCipher Vault 真相，不创建或水合任何 UI Provider。
final class E2eeHeadlessConfigSyncBinding implements E2eeConfigSyncBinding {
  E2eeConfigSyncAdapter? _adapter;
  bool _remotePullActive = false;

  @override
  Future<void> initialize(E2eeConfigVaultCommands commands) async {
    if (_adapter != null) {
      throw StateError('E2EE 后台配置桥接不能重复初始化');
    }
    _adapter = E2eeConfigSyncAdapter(commands: commands);
  }

  @override
  Future<E2eeSyncEntitySnapshot> readSnapshot(SyncEntityKey entityKey) {
    return _requireAdapter().readSnapshot(entityKey);
  }

  @override
  Future<T> runLocalWrite<T>({
    required Iterable<SyncEntityKey> configKeys,
    required Future<T> Function(Future<T> Function() write) transaction,
    required Future<T> Function() write,
  }) {
    throw StateError('E2EE 后台配置桥接不接受本地写入');
  }

  @override
  Future<T> runRemotePull<T>(Future<T> Function() pull) async {
    _requireAdapter();
    if (_remotePullActive) {
      throw StateError('E2EE 后台配置远端拉取不能重入');
    }
    _remotePullActive = true;
    try {
      return await pull();
    } finally {
      _remotePullActive = false;
    }
  }

  @override
  Future<void> applyTransactional(
    List<E2eeSyncPulledChange> applicableChanges,
  ) {
    if (!_remotePullActive) {
      throw StateError('E2EE 后台配置远端应用缺少拉取事务边界');
    }
    return _requireAdapter().applyTransactional(applicableChanges);
  }

  E2eeConfigSyncAdapter _requireAdapter() {
    final adapter = _adapter;
    if (adapter == null) {
      throw StateError('E2EE 后台配置桥接尚未就绪');
    }
    return adapter;
  }
}
