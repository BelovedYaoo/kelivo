import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:kelivo_secure_core/kelivo_secure_core.dart';

import '../../database/chat_database_gateway.dart';
import '../chat/chat_service.dart';
import '../workspace/device_state_blob_store.dart';
import 'cloud_sync_client.dart';
import 'cloud_sync_content_runtime.dart';
import 'cloud_sync_types.dart';
import 'e2ee_account_key_lease.dart';
import 'e2ee_account_record_cipher.dart';
import 'e2ee_account_record_state.dart';
import 'e2ee_attachment_crypto_session.dart';
import 'e2ee_attachment_download_coordinator.dart';
import 'e2ee_attachment_file_store.dart';
import 'e2ee_chat_sync_adapter.dart';
import 'e2ee_config_provider_binding.dart';
import 'config_sync_keys.dart';
import 'e2ee_sync_outbox.dart';
import 'e2ee_sync_pull.dart';
import 'e2ee_sync_scheduler.dart';
import 'sync_codec.dart';
import 'sync_write_executor.dart';

final class E2eeChatContentTransports {
  const E2eeChatContentTransports({required this.records, required this.pull});

  final E2eeSyncAuthenticatedRecordTransport records;
  final E2eeSyncAuthenticatedPullTransport pull;
}

typedef E2eeChatContentTransportFactory =
    E2eeChatContentTransports Function({
      required CloudSyncClient client,
      required CloudSyncAuthenticatedSession session,
    });

enum E2eeChatContentRuntimeState {
  created,
  initializing,
  ready,
  failed,
  closing,
  closed,
}

/// 组装聊天数据面，并集中持有密码学、数据库、网络和调度生命周期。
final class E2eeChatContentRuntime
    implements CloudSyncContentRuntime, E2eeConfigVaultWriteExecutor {
  factory E2eeChatContentRuntime.takeOwnership({
    required CloudSyncAccountSession session,
    required DeviceStateBlobStore deviceStateStore,
    required KelivoSecureCore secureCore,
    required ChatDatabaseGateway databaseGateway,
    required File databaseFile,
    required CloudSyncClient client,
    E2eeChatContentTransportFactory transportFactory = _defaultTransportFactory,
    DateTime Function() utcNow = _defaultUtcNow,
  }) => E2eeChatContentRuntime._(
    session: session,
    deviceStateStore: deviceStateStore,
    secureCore: secureCore,
    databaseGateway: databaseGateway,
    databaseFile: databaseFile,
    client: client,
    transportFactory: transportFactory,
    utcNow: utcNow,
  );

  E2eeChatContentRuntime._({
    required CloudSyncAccountSession session,
    required this._deviceStateStore,
    required this._secureCore,
    required this._databaseGateway,
    required File databaseFile,
    required CloudSyncClient client,
    required this._transportFactory,
    required this._utcNow,
  }) : _session = session,
       _databaseFile = databaseFile.absolute,
       _client = client {
    if (client.baseUrl != session.baseUrl) {
      throw StateError('E2EE 内容运行时客户端与账户服务地址不匹配');
    }
  }

  final CloudSyncAccountSession _session;
  final DeviceStateBlobStore _deviceStateStore;
  final KelivoSecureCore _secureCore;
  final ChatDatabaseGateway _databaseGateway;
  final File _databaseFile;
  final CloudSyncClient _client;
  final E2eeChatContentTransportFactory _transportFactory;
  final DateTime Function() _utcNow;

  E2eeChatContentRuntimeState _state = E2eeChatContentRuntimeState.created;
  ChatService? _chatService;
  E2eeConfigProviderBinding? _configBinding;
  ChatDatabaseLease? _databaseLease;
  E2eeAccountKeyLease? _keyLease;
  E2eeAccountRecordCipher? _recordCipher;
  E2eeAccountRecordStateCodec? _stateCodec;
  E2eeSyncOutbox? _outbox;
  E2eeAttachmentDownloadCoordinator? _attachmentDownloads;
  E2eeSyncScheduler? _scheduler;
  Future<void>? _initializationFuture;
  Future<void>? _closeFuture;
  int _activeLocalWrites = 0;
  Completer<void>? _localWritesIdle;

  E2eeChatContentRuntimeState get state => _state;

  void bindChatService(ChatService chatService) {
    if (_state != E2eeChatContentRuntimeState.created) {
      throw StateError('E2EE 内容运行时启动后不能绑定聊天服务');
    }
    if (_chatService != null) {
      throw StateError('E2EE 内容运行时只能绑定一个聊天服务');
    }
    if (!identical(chatService.databaseGateway, _databaseGateway)) {
      throw StateError('E2EE 内容运行时与聊天服务必须共享数据库网关');
    }
    if (!chatService.usesSyncWriteExecutor(this)) {
      throw StateError('E2EE 内容运行时必须作为聊天服务的写入执行器');
    }
    _chatService = chatService;
  }

  void bindConfigProviders(E2eeConfigProviderBinding binding) {
    if (_state != E2eeChatContentRuntimeState.created) {
      throw StateError('E2EE 内容运行时启动后不能绑定配置 Provider');
    }
    if (_configBinding != null) {
      throw StateError('E2EE 内容运行时只能绑定一组配置 Provider');
    }
    _configBinding = binding;
  }

  @override
  Future<void> initialize() {
    if (_state == E2eeChatContentRuntimeState.ready) {
      return Future<void>.value();
    }
    if (_state == E2eeChatContentRuntimeState.closing ||
        _state == E2eeChatContentRuntimeState.closed) {
      return Future<void>.error(StateError('E2EE 内容运行时正在关闭'));
    }
    final active = _initializationFuture;
    if (active != null) return active;
    if (_state == E2eeChatContentRuntimeState.failed) {
      return Future<void>.error(StateError('E2EE 内容运行时初始化已经失败'));
    }
    if (_chatService == null) {
      return Future<void>.error(StateError('E2EE 内容运行时尚未绑定聊天服务'));
    }
    if (_configBinding == null) {
      _state = E2eeChatContentRuntimeState.failed;
      return Future<void>.error(StateError('E2EE 内容运行时尚未绑定配置 Provider'));
    }

    _state = E2eeChatContentRuntimeState.initializing;
    final initialization = _initialize();
    _initializationFuture = initialization;
    return initialization;
  }

  Future<void> _initialize() async {
    KelivoAccountRootKeyHandle? unownedArk;
    try {
      final chatService = _chatService!;
      await chatService.init();
      _requireStillInitializing();

      final keyLease = await E2eeAccountKeyLease.open(
        session: _session,
        deviceStateStore: _deviceStateStore,
        secureCore: _secureCore,
      );
      _keyLease = keyLease;
      _requireStillInitializing();

      unownedArk = keyLease.takeAccountRootKeyOwnership();
      final recordCipher = E2eeAccountRecordCipher.takeOwnership(
        secureCore: _secureCore,
        accountRootKey: unownedArk,
        userId: _session.userId,
        currentKeyEpoch: _session.keyEpoch,
      );
      unownedArk = null;
      _recordCipher = recordCipher;

      final stateCodec = E2eeAccountRecordStateCodec.takeOwnership(
        recordCipher,
      );
      _recordCipher = null;
      _stateCodec = stateCodec;

      final databaseLease = await _databaseGateway.acquire(_databaseFile);
      _databaseLease = databaseLease;
      _requireStillInitializing();

      final repository = databaseLease.repository;
      final outboxCommands = await repository.acquireE2eeSyncOutboxCommands(
        now: _utcNow(),
      );
      _requireStillInitializing();

      final outbox = E2eeSyncOutbox.takeOwnership(
        commands: outboxCommands,
        stateCodec: stateCodec,
        accountUserId: _session.userId,
        actorDeviceId: _session.deviceId,
        claimedWriterKeyVersion: _session.deviceKeyVersion,
      );
      _stateCodec = null;
      _outbox = outbox;
      await outbox.initialize();
      _requireStillInitializing();

      final configBinding = _configBinding;
      if (configBinding != null) {
        await configBinding.initialize(repository.e2eeConfigVaultCommands);
        _requireStillInitializing();
      }

      final attachmentCrypto = await E2eeAttachmentCryptoSession.open(
        session: _session,
        deviceStateStore: _deviceStateStore,
        secureCore: _secureCore,
      );
      final attachmentDownloads =
          E2eeAttachmentDownloadCoordinator.takeOwnership(
            commands: repository.e2eeAttachmentDownloadCommands,
            transport: _client,
            token: _session.token,
            crypto: attachmentCrypto,
            fileStore: E2eeAttachmentPlatformFileStore(),
            leaseOwner: _session.deviceId,
            utcNow: _utcNow,
          );
      _attachmentDownloads = attachmentDownloads;
      _requireStillInitializing();

      Future<T> runPullBatch<T>({
        required Future<T> Function() pull,
        required bool Function() shouldRefresh,
        required bool Function() mayHaveOrphanedAssets,
      }) {
        return chatService.runCommittedRemoteSyncPull<T>(
          pull: pull,
          shouldRefresh: shouldRefresh,
          mayHaveOrphanedAssets: mayHaveOrphanedAssets,
        );
      }

      final adapter = E2eeChatSyncAdapter(
        repository: repository,
        runPullBatch: runPullBatch,
        attachmentReadiness: attachmentDownloads,
      );
      final authenticatedSession = _session.toAuthenticatedSession();
      final transports = _transportFactory(
        client: _client,
        session: authenticatedSession,
      );
      _validateTransports(transports);

      final pullCoordinator = E2eeSyncPullCoordinator(
        pullCommands: repository.e2eeSyncPullCommands,
        stateCodec: stateCodec,
        transport: transports.pull,
        pagePreparer: attachmentDownloads,
        maximumPreparationRemoteSteps: 1,
        applyBusiness: (changes) async {
          final configChanges = <E2eeSyncPulledChange>[];
          final chatChanges = <E2eeSyncPulledChange>[];
          for (final change in changes) {
            if (ConfigSyncKeys.entityTypes.contains(
              change.state.entityKey.entityType,
            )) {
              configChanges.add(change);
            } else {
              chatChanges.add(change);
            }
          }
          if (configChanges.isNotEmpty) {
            final binding = configBinding;
            if (binding == null) {
              throw StateError('E2EE 配置变更缺少 Provider 桥接');
            }
            await binding.applyTransactional(configChanges);
          }
          await adapter.applyTransactional(chatChanges);
        },
        utcNow: _utcNow,
      );
      final cycleRunner = E2eeSyncCycleRunner(
        runPullBatch: <T>(pull) {
          Future<T> run() => adapter.runPullAndPublish(pull);
          return configBinding == null
              ? run()
              : configBinding.runRemotePull(run);
        },
        pullOnce: ({required int limit}) async {
          final report = await pullCoordinator.pullOnce(limit: limit);
          if (report.disposition ==
              E2eeSyncPullDisposition.keyEpochUnavailable) {
            return E2eeSyncPullStepDisposition.keyEpochUnavailable;
          }
          if (report.hasMore ||
              report.disposition == E2eeSyncPullDisposition.resetToSnapshot) {
            return E2eeSyncPullStepDisposition.more;
          }
          return E2eeSyncPullStepDisposition.complete;
        },
        sealNext: () => outbox.sealNext(
          readSnapshot: (entityKey) {
            if (ConfigSyncKeys.entityTypes.contains(entityKey.entityType)) {
              final binding = configBinding;
              if (binding == null) {
                throw StateError('E2EE 配置快照缺少 Provider 桥接');
              }
              return binding.readSnapshot(entityKey);
            }
            return adapter.readSnapshot(entityKey);
          },
        ),
        flushOnce: () => outbox.flushOnce(transport: transports.records),
      );
      final scheduler = E2eeSyncScheduler(cycleRunner: cycleRunner);
      _scheduler = scheduler;

      await keyLease.close();
      _keyLease = null;
      _requireStillInitializing();

      _state = E2eeChatContentRuntimeState.ready;
      scheduler.start();
    } catch (error, stackTrace) {
      if (unownedArk != null) {
        try {
          await _secureCore.closeAccountRootKey(unownedArk);
        } catch (cleanupError, cleanupStackTrace) {
          _logCleanupFailure(
            'E2EE 内容运行时初始化失败后的裸 ARK 清理失败',
            cleanupError,
            cleanupStackTrace,
          );
        }
      }
      if (_state != E2eeChatContentRuntimeState.closing) {
        _state = E2eeChatContentRuntimeState.failed;
      }
      await _cleanupAfterInitializationFailure();
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<T> runLocal<T>({
    required SyncEntityKey key,
    required Future<T> Function() write,
  }) {
    return runLocalBatch(keys: <SyncEntityKey>[key], write: write);
  }

  @override
  Future<T> runLocalBatch<T>({
    required Iterable<SyncEntityKey> keys,
    required Future<T> Function() write,
  }) async {
    await initialize();
    if (_state != E2eeChatContentRuntimeState.ready) {
      throw StateError('E2EE 内容运行时不接受新的本地写入');
    }
    _activeLocalWrites++;
    try {
      final outbox = _outbox;
      if (outbox == null) {
        throw StateError('E2EE 内容运行时缺少 outbox');
      }
      final normalizedKeys = keys.toSet().toList(growable: false);
      for (final key in normalizedKeys) {
        validateSyncEntityKey(key);
      }
      final configKeys = normalizedKeys
          .where((key) => ConfigSyncKeys.entityTypes.contains(key.entityType))
          .toList(growable: false);
      final configBinding = _configBinding;
      if (configKeys.isNotEmpty && configBinding == null) {
        throw StateError('E2EE 配置本地写入缺少 Provider 桥接');
      }
      final result = configBinding == null || configKeys.isEmpty
          ? await outbox.runLocalBatch<T>(keys: normalizedKeys, write: write)
          : await configBinding.runLocalWrite<T>(
              configKeys: configKeys,
              transaction: (trackedWrite) => outbox.runLocalBatch<T>(
                keys: normalizedKeys,
                write: trackedWrite,
              ),
              write: write,
            );
      if (_state == E2eeChatContentRuntimeState.ready) {
        _scheduler?.wake();
      }
      return result;
    } finally {
      _activeLocalWrites--;
      if (_activeLocalWrites == 0) {
        _localWritesIdle?.complete();
        _localWritesIdle = null;
      }
    }
  }

  @override
  Future<void> close() {
    if (_state == E2eeChatContentRuntimeState.closed) {
      return Future<void>.value();
    }
    final active = _closeFuture;
    if (active != null) return active;
    _state = E2eeChatContentRuntimeState.closing;
    late final Future<void> closing;
    closing = _close().whenComplete(() {
      if (identical(_closeFuture, closing) &&
          _state != E2eeChatContentRuntimeState.closed) {
        _closeFuture = null;
      }
    });
    _closeFuture = closing;
    return closing;
  }

  Future<void> _close() async {
    final cleanup = _CleanupAccumulator();
    final schedulerClose = _scheduler?.close();
    cleanup.runSync('强制关闭 E2EE 内容运行时网络客户端', () {
      _client.close(force: true);
    });

    final initialization = _initializationFuture;
    if (initialization != null) {
      try {
        await initialization;
      } catch (_) {
        // initialize 的调用方已经接收原始错误；关闭只负责继续清理残余所有权。
      }
    }
    if (schedulerClose != null) {
      await cleanup.run('等待 E2EE 同步周期结束', () => schedulerClose);
      if (cleanup.lastStepSucceeded) _scheduler = null;
    }
    await _waitForLocalWrites();

    final chatService = _chatService;
    if (chatService != null) {
      await cleanup.run('关闭 E2EE 聊天服务', chatService.close);
    }

    await _closeOwnedResources(cleanup);
    if (cleanup.error == null) {
      _state = E2eeChatContentRuntimeState.closed;
      return;
    }
    cleanup.throwPrimary();
  }

  Future<void> _cleanupAfterInitializationFailure() async {
    final cleanup = _CleanupAccumulator(logOnly: true);
    final scheduler = _scheduler;
    if (scheduler != null) {
      await cleanup.run('关闭初始化失败的 E2EE 同步调度器', scheduler.close);
      if (cleanup.lastStepSucceeded) _scheduler = null;
    }
    cleanup.runSync('关闭初始化失败的 E2EE 网络客户端', () {
      _client.close(force: true);
    });
    final chatService = _chatService;
    if (chatService != null) {
      await cleanup.run('关闭初始化失败的 E2EE 聊天服务', chatService.close);
    }
    await _closeOwnedResources(cleanup);
  }

  Future<void> _closeOwnedResources(_CleanupAccumulator cleanup) async {
    final attachmentDownloads = _attachmentDownloads;
    if (attachmentDownloads != null) {
      await cleanup.run('关闭 E2EE 附件下载协调器', attachmentDownloads.close);
      if (cleanup.lastStepSucceeded) _attachmentDownloads = null;
    }

    final outbox = _outbox;
    if (outbox != null) {
      await cleanup.run('关闭 E2EE outbox 及记录状态加密器', outbox.close);
      if (cleanup.lastStepSucceeded) _outbox = null;
    }

    final stateCodec = _stateCodec;
    if (stateCodec != null) {
      await cleanup.run('关闭未转移的 E2EE 记录状态加密器', stateCodec.close);
      if (cleanup.lastStepSucceeded) _stateCodec = null;
    }

    final recordCipher = _recordCipher;
    if (recordCipher != null) {
      await cleanup.run('关闭未转移的 E2EE 账户记录加密器', recordCipher.close);
      if (cleanup.lastStepSucceeded) _recordCipher = null;
    }

    final keyLease = _keyLease;
    if (keyLease != null) {
      await cleanup.run('关闭未转移的 E2EE 账户密钥租约', keyLease.close);
      if (cleanup.lastStepSucceeded) _keyLease = null;
    }

    final databaseLease = _databaseLease;
    if (databaseLease != null) {
      await cleanup.run('释放 E2EE 内容运行时数据库租约', databaseLease.release);
      if (cleanup.lastStepSucceeded) _databaseLease = null;
    }
  }

  Future<void> _waitForLocalWrites() async {
    if (_activeLocalWrites == 0) return;
    _localWritesIdle ??= Completer<void>();
    await _localWritesIdle!.future;
  }

  void _requireStillInitializing() {
    if (_state != E2eeChatContentRuntimeState.initializing) {
      throw StateError('E2EE 内容运行时初始化被关闭流程中止');
    }
  }

  void _validateTransports(E2eeChatContentTransports transports) {
    if (transports.records.accountUserId != _session.userId ||
        transports.records.actorDeviceId != _session.deviceId ||
        transports.pull.accountUserId != _session.userId) {
      throw StateError('E2EE 内容 transport 与账户会话不匹配');
    }
  }
}

final class _CleanupAccumulator {
  _CleanupAccumulator({this.logOnly = false});

  final bool logOnly;
  Object? error;
  StackTrace? stackTrace;
  bool lastStepSucceeded = false;

  Future<void> run(String label, Future<void> Function() action) async {
    try {
      await action();
      lastStepSucceeded = true;
    } catch (nextError, nextStackTrace) {
      lastStepSucceeded = false;
      _record(label, nextError, nextStackTrace);
    }
  }

  void runSync(String label, void Function() action) {
    try {
      action();
      lastStepSucceeded = true;
    } catch (nextError, nextStackTrace) {
      lastStepSucceeded = false;
      _record(label, nextError, nextStackTrace);
    }
  }

  void _record(String label, Object nextError, StackTrace nextStackTrace) {
    if (!logOnly && error == null) {
      error = nextError;
      stackTrace = nextStackTrace;
      return;
    }
    _logCleanupFailure(label, nextError, nextStackTrace);
  }

  Never throwPrimary() {
    final primary = error;
    final primaryStackTrace = stackTrace;
    if (primary == null || primaryStackTrace == null) {
      throw StateError('E2EE 内容运行时清理错误状态不完整');
    }
    Error.throwWithStackTrace(primary, primaryStackTrace);
  }
}

E2eeChatContentTransports _defaultTransportFactory({
  required CloudSyncClient client,
  required CloudSyncAuthenticatedSession session,
}) {
  return E2eeChatContentTransports(
    records: E2eeSyncCloudRecordTransport.bind(
      client: client,
      session: session,
    ),
    pull: E2eeSyncCloudPullTransport.bind(client: client, session: session),
  );
}

DateTime _defaultUtcNow() => DateTime.now().toUtc();

void _logCleanupFailure(String message, Object error, StackTrace stackTrace) {
  developer.log(
    message,
    name: 'Kelivo.E2eeChatContentRuntime',
    error: error,
    stackTrace: stackTrace,
  );
}
