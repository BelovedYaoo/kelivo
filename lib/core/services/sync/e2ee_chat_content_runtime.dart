import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:kelivo_secure_core/kelivo_secure_core.dart';

import '../../database/chat_database_gateway.dart';
import '../../database/chat_database_repository.dart';
import '../../models/chat_message.dart';
import '../chat/chat_service.dart';
import '../workspace/device_state_blob_store.dart';
import 'cloud_sync_client.dart';
import 'cloud_sync_content_runtime.dart';
import 'cloud_sync_terminal_session_retirement.dart';
import 'cloud_sync_types.dart';
import 'e2ee_account_key_lease.dart';
import 'e2ee_account_record_cipher.dart';
import 'e2ee_account_record_state.dart';
import 'e2ee_attachment_crypto_session.dart';
import 'e2ee_attachment_download_coordinator.dart';
import 'e2ee_attachment_file_store.dart';
import 'e2ee_attachment_manifest.dart';
import 'e2ee_attachment_upload_coordinator.dart';
import 'e2ee_chat_sync_adapter.dart';
import 'config_sync_keys.dart';
import 'e2ee_config_sync_binding.dart';
import 'e2ee_sync_outbox.dart';
import 'e2ee_sync_execution_budget.dart';
import 'e2ee_sync_pull.dart';
import 'e2ee_sync_scheduler.dart';
import 'sync_codec.dart';
import 'sync_write_executor.dart';

final class E2eeChatContentTransports {
  const E2eeChatContentTransports({
    required this.records,
    required this.pull,
    required this.attachments,
  });

  final E2eeSyncAuthenticatedRecordTransport records;
  final E2eeSyncAuthenticatedPullTransport pull;
  final CloudSyncAttachmentTransport attachments;
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

enum E2eeChatContentRuntimeMode { continuous, singleCycle }

/// 组装聊天数据面，并集中持有密码学、数据库、网络和调度生命周期。
final class E2eeChatContentRuntime
    implements
        CloudSyncContentRuntime,
        E2eeConfigVaultWriteExecutor,
        StructuredAttachmentSyncWriteExecutor {
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
    mode: E2eeChatContentRuntimeMode.continuous,
  );

  factory E2eeChatContentRuntime.takeHeadlessOwnership({
    required CloudSyncAccountSession session,
    required DeviceStateBlobStore deviceStateStore,
    required KelivoSecureCore secureCore,
    required ChatDatabaseGateway databaseGateway,
    required File databaseFile,
    required CloudSyncClient client,
    E2eeChatContentTransportFactory transportFactory = _defaultTransportFactory,
    DateTime Function() utcNow = _defaultUtcNow,
  }) {
    final runtime = E2eeChatContentRuntime._(
      session: session,
      deviceStateStore: deviceStateStore,
      secureCore: secureCore,
      databaseGateway: databaseGateway,
      databaseFile: databaseFile,
      client: client,
      transportFactory: transportFactory,
      utcNow: utcNow,
      mode: E2eeChatContentRuntimeMode.singleCycle,
    );
    runtime.bindChatService(
      ChatService(runtime, databaseGateway: databaseGateway),
    );
    runtime.bindConfigProviders(E2eeHeadlessConfigSyncBinding());
    return runtime;
  }

  E2eeChatContentRuntime._({
    required CloudSyncAccountSession session,
    required this._deviceStateStore,
    required this._secureCore,
    required this._databaseGateway,
    required File databaseFile,
    required CloudSyncClient client,
    required this._transportFactory,
    required this._utcNow,
    required this._mode,
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
  final E2eeChatContentRuntimeMode _mode;

  E2eeChatContentRuntimeState _state = E2eeChatContentRuntimeState.created;
  ChatService? _chatService;
  E2eeConfigSyncBinding? _configBinding;
  ChatDatabaseLease? _databaseLease;
  E2eeAccountKeyLease? _keyLease;
  E2eeAccountRecordCipher? _recordCipher;
  E2eeAccountRecordStateCodec? _stateCodec;
  E2eeSyncOutbox? _outbox;
  E2eeAttachmentFileStore? _attachmentFileStore;
  E2eeAttachmentUploadCoordinator? _attachmentUploads;
  E2eeAttachmentUploadCommands? _attachmentUploadCommands;
  E2eeAttachmentDownloadCoordinator? _attachmentDownloads;
  bool _hasAttachmentUploadWork = false;
  E2eeSyncScheduler? _scheduler;
  E2eeSyncCycleRunner Function(E2eeSyncExecutionBudget?)? _cycleRunnerFactory;
  Future<E2eeSyncCycleReport>? _activeSingleCycle;
  Future<void>? _initializationFuture;
  Future<void>? _closeFuture;
  CloudSyncTerminalAuthenticationHandler? _terminalAuthenticationHandler;
  int _activeLocalWrites = 0;
  Completer<void>? _localWritesIdle;

  E2eeChatContentRuntimeState get state => _state;

  @override
  void bindTerminalAuthenticationHandler(
    CloudSyncTerminalAuthenticationHandler handler,
  ) {
    if (_state != E2eeChatContentRuntimeState.created) {
      throw StateError('E2EE 内容运行时启动后不能绑定终止认证处理器');
    }
    if (_terminalAuthenticationHandler != null) {
      throw StateError('E2EE 内容运行时只能绑定一个终止认证处理器');
    }
    _terminalAuthenticationHandler = handler;
  }

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

  void bindConfigProviders(E2eeConfigSyncBinding binding) {
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

      final authenticatedSession = _session.toAuthenticatedSession();
      final transports = _transportFactory(
        client: _client,
        session: authenticatedSession,
      );
      _validateTransports(transports);

      final attachmentFileStore = E2eeAttachmentPlatformFileStore();
      _attachmentFileStore = attachmentFileStore;
      final downloadCrypto = await E2eeAttachmentCryptoSession.open(
        session: _session,
        deviceStateStore: _deviceStateStore,
        secureCore: _secureCore,
      );
      final attachmentDownloads =
          E2eeAttachmentDownloadCoordinator.takeOwnership(
            commands: repository.e2eeAttachmentDownloadCommands,
            transport: transports.attachments,
            token: _session.token,
            crypto: downloadCrypto,
            fileStore: attachmentFileStore,
            leaseOwner: _session.deviceId,
            utcNow: _utcNow,
          );
      _attachmentDownloads = attachmentDownloads;
      _requireStillInitializing();

      final uploadCrypto = await E2eeAttachmentCryptoSession.open(
        session: _session,
        deviceStateStore: _deviceStateStore,
        secureCore: _secureCore,
      );
      final attachmentUploadCommands = repository.e2eeAttachmentUploadCommands;
      final attachmentUploads = E2eeAttachmentUploadCoordinator.takeOwnership(
        commands: attachmentUploadCommands,
        fileStore: attachmentFileStore,
        transport: transports.attachments,
        token: _session.token,
        cryptoSession: uploadCrypto,
        utcNow: _utcNow,
      );
      _attachmentUploadCommands = attachmentUploadCommands;
      _attachmentUploads = attachmentUploads;
      _hasAttachmentUploadWork = await attachmentUploadCommands
          .hasRetryableWork();
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
      E2eeSyncCycleRunner createCycleRunner(
        E2eeSyncExecutionBudget? executionBudget,
      ) {
        Future<T> runBudgeted<T>(Future<T> Function() action) async {
          executionBudget?.checkCanContinue();
          final result = await action();
          executionBudget?.checkCanContinue();
          return result;
        }

        return E2eeSyncCycleRunner(
          runPullBatch: <T>(pull) {
            return runBudgeted<T>(() {
              Future<T> run() => adapter.runPullAndPublish(pull);
              return configBinding == null
                  ? run()
                  : configBinding.runRemotePull(run);
            });
          },
          pullOnce: ({required int limit}) {
            return runBudgeted<E2eeSyncPullStepDisposition>(() async {
              final report = await pullCoordinator.pullOnce(
                limit: limit,
                executionBudget: executionBudget,
              );
              if (report.disposition ==
                  E2eeSyncPullDisposition.keyEpochUnavailable) {
                return E2eeSyncPullStepDisposition.keyEpochUnavailable;
              }
              if (report.hasMore ||
                  report.disposition ==
                      E2eeSyncPullDisposition.resetToSnapshot) {
                return E2eeSyncPullStepDisposition.more;
              }
              return E2eeSyncPullStepDisposition.complete;
            });
          },
          advanceAttachmentUploads: ({required int maximumRemoteSteps}) {
            return runBudgeted<void>(() async {
              if (!_hasAttachmentUploadWork) return;
              final remoteSteps = await attachmentUploads.advance(
                maximumRemoteSteps,
                executionBudget: executionBudget,
              );
              if (remoteSteps < maximumRemoteSteps) {
                _hasAttachmentUploadWork = await attachmentUploadCommands
                    .hasRetryableWork();
              }
            });
          },
          sealNext: () => runBudgeted<E2eeSyncSealStatus>(
            () => outbox.sealNext(
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
          ),
          flushOnce: () => runBudgeted<E2eeSyncFlushReport>(
            () => outbox.flushOnce(
              transport: transports.records,
              executionBudget: executionBudget,
            ),
          ),
        );
      }

      _cycleRunnerFactory = createCycleRunner;
      E2eeSyncScheduler? scheduler;
      if (_mode == E2eeChatContentRuntimeMode.continuous) {
        scheduler = E2eeSyncScheduler(
          cycleRunner: createCycleRunner(null),
          isTerminalFailure: isTerminalCloudSyncAuthenticationFailure,
          onTerminalFailure: _handleTerminalAuthenticationFailure,
        );
        _scheduler = scheduler;
      }

      await keyLease.close();
      _keyLease = null;
      _requireStillInitializing();

      _state = E2eeChatContentRuntimeState.ready;
      scheduler?.start();
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

  Future<E2eeSyncCycleReport> runSingleCycle(
    E2eeSyncExecutionBudget executionBudget,
  ) async {
    if (_mode != E2eeChatContentRuntimeMode.singleCycle) {
      throw StateError('E2EE 持续运行时不接受外部单次同步');
    }
    executionBudget.checkCanContinue();
    await initialize();
    // 初始化可能包含不可中断的本地数据库和安全核心步骤；其完成后必须在
    // 第一个远端调用前重新核对总截止时间。
    executionBudget.checkCanContinue();
    if (_state != E2eeChatContentRuntimeState.ready) {
      throw StateError('E2EE 内容运行时不接受新的单次同步');
    }
    if (_activeSingleCycle != null) {
      throw StateError('E2EE 内容运行时已有单次同步正在执行');
    }
    final factory = _cycleRunnerFactory;
    if (factory == null) {
      throw StateError('E2EE 内容运行时缺少单次同步执行器');
    }

    late final Future<E2eeSyncCycleReport> tracked;
    tracked = factory(executionBudget).run().whenComplete(() {
      if (identical(_activeSingleCycle, tracked)) {
        _activeSingleCycle = null;
      }
    });
    _activeSingleCycle = tracked;
    return tracked;
  }

  @override
  Future<T> runLocal<T>({
    required SyncEntityKey key,
    required Future<T> Function() write,
  }) {
    return runLocalBatch(keys: <SyncEntityKey>[key], write: write);
  }

  @override
  Future<List<ChatMessageAttachment>> materializeLocalAttachments(
    Iterable<ChatMessageAttachment> attachments,
  ) async {
    final inputs = List<ChatMessageAttachment>.unmodifiable(attachments);
    if (inputs.isEmpty) return const <ChatMessageAttachment>[];
    await initialize();
    _requireReadyForLocalOperation();
    _activeLocalWrites++;
    try {
      final fileStore = _attachmentFileStore;
      if (fileStore == null) {
        throw StateError('E2EE 内容运行时缺少附件文件存储');
      }
      final materialized = <ChatMessageAttachment>[];
      for (final attachment in inputs) {
        if (attachment.hasRemoteIdentity) {
          throw StateError('本地附件物化不得携带远端身份');
        }
        final contentSha256 = _decodeSha256Hex(attachment.contentHash);
        final stored = await fileStore.publish(
          location: E2eeAttachmentFileLocation.content(
            contentSha256: contentSha256,
          ),
          source: File(attachment.path).openRead(),
        );
        if (stored.bytes != attachment.byteSize) {
          throw StateError('附件内容寻址落盘长度与本地引用不一致');
        }
        materialized.add(
          ChatMessageAttachment(
            assetId: attachment.assetId,
            path: stored.storagePath,
            contentHash: attachment.contentHash,
            byteSize: attachment.byteSize,
            kind: attachment.kind,
            displayName: attachment.displayName,
            mediaType: attachment.mediaType,
          ),
        );
      }
      return List<ChatMessageAttachment>.unmodifiable(materialized);
    } finally {
      _finishLocalOperation();
    }
  }

  @override
  Future<T> runLocalBatchWithMessageAttachments<T>({
    required Iterable<SyncEntityKey> keys,
    required String targetRevisionId,
    required Iterable<ChatMessageAttachment> attachments,
    required bool Function(T result) targetWasPersisted,
    required Future<T> Function() write,
  }) async {
    final inputs = List<ChatMessageAttachment>.unmodifiable(attachments);
    if (inputs.isEmpty) {
      return runLocalBatch<T>(keys: keys, write: write);
    }
    await initialize();
    _requireReadyForLocalOperation();
    _activeLocalWrites++;
    try {
      final uploads = _attachmentUploads;
      final commands = _attachmentUploadCommands;
      if (uploads == null || commands == null) {
        throw StateError('E2EE 内容运行时缺少附件上传组件');
      }
      final drafts = <E2eeAttachmentUploadDraft>[];
      for (var index = 0; index < inputs.length; index++) {
        final attachment = inputs[index];
        if (attachment.hasRemoteIdentity) {
          throw StateError('本地附件上传草稿不得携带远端身份');
        }
        drafts.add(
          await uploads.prepareDraft(
            localAssetId: attachment.assetId,
            targetRevisionId: targetRevisionId,
            targetOrdinal: index,
            sourcePath: attachment.path,
            kind: E2eeAttachmentKind.values.byName(attachment.kind),
            totalPlaintextBytes: attachment.byteSize,
            contentSha256: _decodeSha256Hex(attachment.contentHash),
            displayName: attachment.displayName,
            mediaType: attachment.mediaType,
          ),
        );
      }

      var persistedTarget = false;
      final now = _utcNow();
      final result = await _runLocalBatchCore<T>(
        keys: keys,
        write: () async {
          final value = await write();
          persistedTarget = targetWasPersisted(value);
          if (persistedTarget) {
            for (final draft in drafts) {
              await commands.create(draft: draft, now: now);
            }
          }
          return value;
        },
      );
      if (persistedTarget) _hasAttachmentUploadWork = true;
      if (_state == E2eeChatContentRuntimeState.ready) {
        _scheduler?.wake();
      }
      return result;
    } finally {
      _finishLocalOperation();
    }
  }

  @override
  Future<T> runLocalBatch<T>({
    required Iterable<SyncEntityKey> keys,
    required Future<T> Function() write,
  }) async {
    await initialize();
    _requireReadyForLocalOperation();
    _activeLocalWrites++;
    try {
      final result = await _runLocalBatchCore<T>(keys: keys, write: write);
      if (_state == E2eeChatContentRuntimeState.ready) {
        _scheduler?.wake();
      }
      return result;
    } finally {
      _finishLocalOperation();
    }
  }

  Future<T> _runLocalBatchCore<T>({
    required Iterable<SyncEntityKey> keys,
    required Future<T> Function() write,
  }) async {
    final outbox = _outbox;
    if (outbox == null) throw StateError('E2EE 内容运行时缺少 outbox');
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
    return configBinding == null || configKeys.isEmpty
        ? outbox.runLocalBatch<T>(keys: normalizedKeys, write: write)
        : configBinding.runLocalWrite<T>(
            configKeys: configKeys,
            transaction: (trackedWrite) => outbox.runLocalBatch<T>(
              keys: normalizedKeys,
              write: trackedWrite,
            ),
            write: write,
          );
  }

  void _requireReadyForLocalOperation() {
    if (_state != E2eeChatContentRuntimeState.ready) {
      throw StateError('E2EE 内容运行时不接受新的本地写入');
    }
  }

  void _finishLocalOperation() {
    _activeLocalWrites--;
    if (_activeLocalWrites == 0) {
      _localWritesIdle?.complete();
      _localWritesIdle = null;
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
    final singleCycle = _activeSingleCycle;
    if (singleCycle != null) {
      try {
        await singleCycle;
      } catch (_) {
        // 单次执行的调用方接收原始错误；关闭只等待网络 Future 完成结算。
      }
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

  Future<void> _handleTerminalAuthenticationFailure(
    Object error,
    StackTrace stackTrace,
  ) {
    if (error is! CloudSyncException ||
        !isTerminalCloudSyncAuthenticationFailure(error)) {
      throw StateError('E2EE 同步调度器提交了非终止认证错误');
    }
    final handler = _terminalAuthenticationHandler;
    if (handler == null) {
      throw StateError('E2EE 内容运行时缺少终止认证处理器');
    }
    return handler(error, stackTrace);
  }

  Future<void> _closeOwnedResources(_CleanupAccumulator cleanup) async {
    final attachmentUploads = _attachmentUploads;
    if (attachmentUploads != null) {
      await cleanup.run('关闭 E2EE 附件上传协调器', attachmentUploads.close);
      if (cleanup.lastStepSucceeded) {
        _attachmentUploads = null;
        _attachmentUploadCommands = null;
        _hasAttachmentUploadWork = false;
      }
    }

    final attachmentDownloads = _attachmentDownloads;
    if (attachmentDownloads != null) {
      await cleanup.run('关闭 E2EE 附件下载协调器', attachmentDownloads.close);
      if (cleanup.lastStepSucceeded) _attachmentDownloads = null;
    }
    if (_attachmentUploads == null && _attachmentDownloads == null) {
      _attachmentFileStore = null;
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
    attachments: client,
  );
}

DateTime _defaultUtcNow() => DateTime.now().toUtc();

Uint8List _decodeSha256Hex(String value) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw const FormatException('附件内容摘要不是规范 SHA-256');
  }
  return Uint8List.fromList(<int>[
    for (var offset = 0; offset < value.length; offset += 2)
      int.parse(value.substring(offset, offset + 2), radix: 16),
  ]);
}

void _logCleanupFailure(String message, Object error, StackTrace stackTrace) {
  developer.log(
    message,
    name: 'Kelivo.E2eeChatContentRuntime',
    error: error,
    stackTrace: stackTrace,
  );
}
