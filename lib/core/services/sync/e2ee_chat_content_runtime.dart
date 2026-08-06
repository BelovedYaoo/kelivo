import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../utils/app_directories.dart';
import '../../../utils/sandbox_path_resolver.dart';
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
import 'e2ee_account_trust_manifest.dart';
import 'e2ee_attachment_crypto_session.dart';
import 'e2ee_attachment_download_coordinator.dart';
import 'e2ee_attachment_file_store.dart';
import 'e2ee_attachment_manifest.dart';
import 'e2ee_attachment_upload_coordinator.dart';
import 'e2ee_chat_sync_adapter.dart';
import 'config_sync_keys.dart';
import 'e2ee_config_asset_types.dart';
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

typedef E2eeAttachmentUploadWorkScanner =
    Future<bool> Function(E2eeAttachmentUploadCommands commands);

enum E2eeChatContentRuntimeState {
  created,
  initializing,
  ready,
  failed,
  closing,
  closed,
}

enum E2eeChatContentRuntimeMode { continuous, singleCycle }

final class _MaterializedAttachmentSourceRetirement {
  const _MaterializedAttachmentSourceRetirement({
    required this.retirementId,
    required this.sourcePath,
    required this.quarantinePath,
  });

  final String retirementId;
  final String sourcePath;
  final String quarantinePath;
}

/// 组装聊天数据面，并集中持有密码学、数据库、网络和调度生命周期。
final class E2eeChatContentRuntime
    implements
        CloudSyncContentRuntime,
        E2eeConfigVaultWriteExecutor,
        ConfigAssetSyncWriteExecutor,
        ImportSyncWriteExecutor,
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
    @visibleForTesting
    E2eeAttachmentUploadWorkScanner attachmentWorkScanner =
        _defaultAttachmentUploadWorkScanner,
  }) => E2eeChatContentRuntime._(
    session: session,
    deviceStateStore: deviceStateStore,
    secureCore: secureCore,
    databaseGateway: databaseGateway,
    databaseFile: databaseFile,
    client: client,
    transportFactory: transportFactory,
    utcNow: utcNow,
    attachmentWorkScanner: attachmentWorkScanner,
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
    @visibleForTesting
    E2eeAttachmentUploadWorkScanner attachmentWorkScanner =
        _defaultAttachmentUploadWorkScanner,
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
      attachmentWorkScanner: attachmentWorkScanner,
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
    required this._attachmentWorkScanner,
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
  final E2eeAttachmentUploadWorkScanner _attachmentWorkScanner;
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
  int _attachmentUploadWorkGeneration = 0;
  // 接管信息只跨越材料化到事务提交窗口，不能进入聊天附件持久格式。
  final Expando<_MaterializedAttachmentSourceRetirement>
  _materializedSourceRetirements =
      Expando<_MaterializedAttachmentSourceRetirement>();
  E2eeSyncScheduler? _scheduler;
  E2eeSyncCycleRunner Function(E2eeSyncExecutionBudget?)? _cycleRunnerFactory;
  Future<E2eeSyncCycleReport>? _activeSingleCycle;
  Future<void>? _initializationFuture;
  Future<void>? _closeFuture;
  final Object _startupRecoveryZoneKey = Object();
  CloudSyncSecurityBootstrapCommitHandler? _securityBootstrapCommitHandler;
  CloudSyncTerminalAuthenticationHandler? _terminalAuthenticationHandler;
  int _activeLocalWrites = 0;
  Completer<void>? _localWritesIdle;

  E2eeChatContentRuntimeState get state => _state;

  @override
  void bindSecurityBootstrapCommitHandler(
    CloudSyncSecurityBootstrapCommitHandler handler,
  ) {
    if (_state != E2eeChatContentRuntimeState.created) {
      throw StateError('E2EE 内容运行时启动后不能绑定安全 bootstrap 提交处理器');
    }
    if (_securityBootstrapCommitHandler != null) {
      throw StateError('E2EE 内容运行时只能绑定一个安全 bootstrap 提交处理器');
    }
    _securityBootstrapCommitHandler = handler;
  }

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
      final keyLease = await E2eeAccountKeyLease.open(
        session: _session,
        deviceStateStore: _deviceStateStore,
        secureCore: _secureCore,
      );
      _keyLease = keyLease;
      _requireStillInitializing();

      unownedArk = keyLease.takeAccountRootKeyOwnership();
      final databaseLease = await _databaseGateway.acquire(_databaseFile);
      _databaseLease = databaseLease;
      _requireStillInitializing();

      final repository = databaseLease.repository;
      await _establishMembershipTrust(
        commands: repository.e2eeVerifiedMembershipAnchorCommands,
        accountRootKey: unownedArk,
      );
      _requireStillInitializing();

      await chatService.init();
      _requireStillInitializing();

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
        await configBinding.initialize(
          repository.e2eeConfigVaultCommands,
          repository.e2eeConfigAssetCommands,
        );
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
      await attachmentFileStore.reconcileUnreferencedContent(
        isPathDemanded: repository.isManagedPathDemanded,
      );
      _requireStillInitializing();
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
      await _refreshAttachmentUploadWork(attachmentUploadCommands);
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
            final mayHaveOrphanedAssets = await _applyConfigAssetChanges(
              changes: configChanges,
              downloads: attachmentDownloads,
              commands: repository.e2eeConfigAssetCommands,
            );
            await binding.applyTransactional(configChanges);
            adapter.recordExternalTransactionalApply(
              mayHaveOrphanedAssets: mayHaveOrphanedAssets,
            );
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
                await _refreshAttachmentUploadWork(attachmentUploadCommands);
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

      // 只授权这条异步链在 initializing 期使用已就绪的本地事务，
      // 外部 initialize 调用仍必须等待恢复整体完成。
      await runZoned<Future<void>>(
        chatService.recoverStaleStreamingStateForE2eeStartup,
        zoneValues: <Object?, Object?>{_startupRecoveryZoneKey: this},
      );
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

  Future<void> _establishMembershipTrust({
    required E2eeVerifiedMembershipAnchorCommands commands,
    required KelivoAccountRootKeyHandle accountRootKey,
  }) async {
    final bootstrap = _session.securityBootstrap;
    if (bootstrap == null) {
      final anchor = await commands.readVerified(
        accountUserId: _session.userId,
        ark: accountRootKey,
      );
      if (anchor == null) {
        throw StateError('账户会话缺少本地已验证成员锚点');
      }
      _validateCurrentMembership(anchor.membership);
      return;
    }

    final commitHandler = _securityBootstrapCommitHandler;
    if (commitHandler == null) {
      throw StateError('待安装安全 bootstrap 缺少提交处理器');
    }
    final verified = await _verifySecurityBootstrap(
      bootstrap,
      accountRootKey: accountRootKey,
    );
    await commands.install(membership: verified, now: _utcNow());
    try {
      await commitHandler(_session);
    } catch (_) {
      developer.log(
        '成员锚点已安装，但安全 bootstrap 恢复事务清理或会话提交失败',
        name: 'Kelivo.E2eeChatContentRuntime',
        level: 1000,
      );
      rethrow;
    }
  }

  Future<E2eeVerifiedMembership> _verifySecurityBootstrap(
    CloudSyncSecurityBootstrap bootstrap, {
    required KelivoAccountRootKeyHandle accountRootKey,
  }) async {
    final state = bootstrap.state;
    if (state.dataRekeyPhase != CloudSyncDataRekeyPhase.ready) {
      throw StateError('初始安全 bootstrap 不能处于数据重加密阶段');
    }
    final localMember = _membershipDeviceInput(bootstrap.localMember);
    final projection = E2eeMembershipServerProjection(
      userId: _session.userId,
      securityGeneration: state.generation,
      keyEpoch: state.keyEpoch,
      membershipManifestVersion: e2eeAccountTrustManifestFormatVersion,
      membershipManifest: state.membershipManifest,
      membershipManifestDigest: state.membershipManifestDigest.bytes,
      recoveryPublicKeyVersion: state.recoveryPublicKeyVersion,
      recoveryPublicKey: state.recoveryPublicKey,
      recoveryCapsuleVersion: state.recoveryCapsuleVersion,
      recoveryCapsule: state.recoveryCapsule,
      lastOperationId: state.lastOperationId,
      dataRekeyPhase: E2eeDataRekeyPhase.ready,
    );
    final expectation = switch (bootstrap.source) {
      CloudSyncSecurityBootstrapSource.firstRegistration =>
        E2eeInitializeMembershipExpectation(
          projection: projection,
          operationId: state.lastOperationId,
          member: localMember,
        ),
      CloudSyncSecurityBootstrapSource.pairing =>
        E2eePairingBootstrapMembershipExpectation(
          projection: projection,
          consumedKeyEpoch: bootstrap.pairingReceipt!.keyEpoch,
          consumedSecurityGeneration:
              bootstrap.pairingReceipt!.securityGeneration,
          consumedMembershipManifestDigest:
              bootstrap.pairingReceipt!.membershipManifestDigest.bytes,
          pairingId: bootstrap.pairingReceipt!.pairingId,
          issuerDeviceId: bootstrap.pairingReceipt!.issuerDeviceId,
          localMember: localMember,
        ),
    };
    final verified = await const E2eeAccountTrustManifestModule().verify(
      ark: accountRootKey,
      expectation: expectation,
    );
    final verifiedLocal = _requireMembershipDevice(
      verified,
      bootstrap.localMember.deviceId,
    );
    if (!_sameMembershipDevice(verifiedLocal, bootstrap.localMember)) {
      throw StateError('安全 bootstrap 本机成员材料与签名清单不匹配');
    }
    final issuer = bootstrap.issuerMember;
    if (issuer != null) {
      final verifiedIssuer = _requireMembershipDevice(
        verified,
        issuer.deviceId,
      );
      if (!_sameMembershipDevice(verifiedIssuer, issuer)) {
        throw StateError('安全 bootstrap 签发者材料与签名清单不匹配');
      }
    }
    return verified;
  }

  void _validateCurrentMembership(E2eeVerifiedMembership membership) {
    if (membership.userId != _session.userId ||
        membership.keyEpoch != _session.keyEpoch) {
      throw StateError('本地成员锚点与账户会话不匹配');
    }
    final local = _requireMembershipDevice(membership, _session.deviceId);
    if (local.keyVersion != _session.deviceKeyVersion ||
        local.authGeneration != _session.authGeneration) {
      throw StateError('本地成员锚点与当前设备认证状态不匹配');
    }
  }

  E2eeMembershipDeviceInput _membershipDeviceInput(
    CloudSyncMembershipDeviceMaterial member,
  ) {
    return E2eeMembershipDeviceInput(
      deviceId: member.deviceId,
      keyVersion: member.keyVersion,
      authGeneration: member.authGeneration,
      signingPublicKey: member.signingPublicKey,
      keyAgreementPublicKey: member.keyAgreementPublicKey,
    );
  }

  E2eeVerifiedMembershipDevice _requireMembershipDevice(
    E2eeVerifiedMembership membership,
    String deviceId,
  ) {
    E2eeVerifiedMembershipDevice? result;
    for (final member in membership.members) {
      if (member.deviceId != deviceId) continue;
      if (result != null) {
        throw StateError('签名成员清单包含重复设备');
      }
      result = member;
    }
    return result ?? (throw StateError('签名成员清单缺少当前设备'));
  }

  bool _sameMembershipDevice(
    E2eeVerifiedMembershipDevice verified,
    CloudSyncMembershipDeviceMaterial expected,
  ) {
    return verified.deviceId == expected.deviceId &&
        verified.keyVersion == expected.keyVersion &&
        verified.authGeneration == expected.authGeneration &&
        _sameRuntimeBytes(
          verified.signingPublicKey,
          expected.signingPublicKey,
        ) &&
        _sameRuntimeBytes(
          verified.keyAgreementPublicKey,
          expected.keyAgreementPublicKey,
        );
  }

  bool _sameRuntimeBytes(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }

  Future<E2eeSyncCycleReport> runSingleCycle(
    E2eeSyncExecutionBudget executionBudget,
  ) async {
    if (_mode != E2eeChatContentRuntimeMode.singleCycle) {
      throw StateError('E2EE 持续运行时不接受外部单次同步');
    }
    await executionBudget.runBoundedStep(operation: (_) => initialize());
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
    await _awaitLocalOperationReadiness();
    _activeLocalWrites++;
    try {
      return _materializeLocalAttachmentsCore(inputs);
    } finally {
      _finishLocalOperation();
    }
  }

  Future<List<ChatMessageAttachment>> _materializeLocalAttachmentsCore(
    Iterable<ChatMessageAttachment> attachments,
  ) async {
    final fileStore = _attachmentFileStore;
    if (fileStore == null) {
      throw StateError('E2EE 内容运行时缺少附件文件存储');
    }
    final materialized = <ChatMessageAttachment>[];
    for (final attachment in attachments) {
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
      final output = ChatMessageAttachment(
        assetId: attachment.assetId,
        path: stored.storagePath,
        contentHash: attachment.contentHash,
        byteSize: attachment.byteSize,
        kind: attachment.kind,
        displayName: attachment.displayName,
        mediaType: attachment.mediaType,
      );
      final retirement = await _createMaterializedSourceRetirement(
        sourcePath: attachment.path,
        materializedPath: stored.storagePath,
      );
      if (retirement != null) {
        _materializedSourceRetirements[output] = retirement;
      }
      materialized.add(output);
    }
    return List<ChatMessageAttachment>.unmodifiable(materialized);
  }

  @override
  Future<List<MaterializedConfigAsset>> materializeLocalConfigAssets(
    Iterable<LocalConfigAssetInput> assets,
  ) async {
    final inputs = List<LocalConfigAssetInput>.unmodifiable(assets);
    if (inputs.isEmpty) return const <MaterializedConfigAsset>[];
    await initialize();
    _requireReadyForLocalOperation();
    _activeLocalWrites++;
    try {
      final fileStore = _attachmentFileStore;
      if (fileStore == null) {
        throw StateError('E2EE 内容运行时缺少配置资产文件存储');
      }
      final keys = <E2eeConfigAssetKey>{};
      final materialized = <MaterializedConfigAsset>[];
      for (final input in inputs) {
        if (!keys.add(input.key)) {
          throw StateError('配置资产物化不得包含重复目标');
        }
        _validateLocalConfigAssetInput(input);
        final sourcePath = SandboxPathResolver.resolveUserSelectedSource(
          input.sourcePath,
        );
        final source = File(sourcePath);
        if (await FileSystemEntity.type(source.path, followLinks: false) !=
            FileSystemEntityType.file) {
          throw StateError('配置资产源文件不可用');
        }
        final before = await source.stat();
        if (before.size < 0 ||
            before.size > KelivoAttachmentLimits.maxTotalPlaintextBytes) {
          throw const FormatException('配置资产文件长度超出限制');
        }
        final measured = await _measureConfigAssetFile(source.path);
        if (await FileSystemEntity.type(source.path, followLinks: false) !=
            FileSystemEntityType.file) {
          throw StateError('配置资产源文件在摘要期间被替换');
        }
        final after = await source.stat();
        if (before.size != after.size ||
            before.modified != after.modified ||
            measured.bytes != after.size) {
          throw StateError('配置资产源文件在摘要期间发生变化');
        }
        final contentSha256 = _decodeSha256Hex(measured.contentHash);
        final stored = await fileStore.publish(
          location: E2eeAttachmentFileLocation.content(
            contentSha256: contentSha256,
          ),
          source: source.openRead(),
        );
        if (stored.bytes != measured.bytes ||
            _sha256Hex(stored.sha256) != measured.contentHash) {
          throw StateError('配置资产内容寻址落盘结果不一致');
        }
        materialized.add(
          MaterializedConfigAsset(
            key: input.key,
            assetId: 'asset_${measured.contentHash}',
            path: stored.storagePath,
            contentHash: measured.contentHash,
            byteSize: measured.bytes,
            kind: input.kind,
            displayName: input.displayName,
            mediaType: input.mediaType,
          ),
        );
      }
      return List<MaterializedConfigAsset>.unmodifiable(materialized);
    } finally {
      _finishLocalOperation();
    }
  }

  @override
  Future<T> runLocalBatchWithMessageAttachments<T>({
    required Iterable<SyncEntityKey> keys,
    required Iterable<StructuredMessageAttachmentSyncTarget> targets,
    required bool Function(T result) targetWasPersisted,
    required Future<T> Function() write,
  }) async {
    final inputs = List<StructuredMessageAttachmentSyncTarget>.unmodifiable(
      targets,
    );
    if (inputs.isEmpty) {
      return runLocalBatch<T>(keys: keys, write: write);
    }
    final revisionIds = <String>{};
    for (final input in inputs) {
      if (input.attachments.isEmpty) {
        throw StateError('附件消息批次不得为空');
      }
      if (!revisionIds.add(input.targetRevisionId)) {
        throw StateError('附件消息批次不得包含重复目标');
      }
    }
    await _awaitLocalOperationReadiness();
    _activeLocalWrites++;
    try {
      final uploads = _attachmentUploads;
      final commands = _attachmentUploadCommands;
      final repository = _databaseLease?.repository;
      if (uploads == null || commands == null || repository == null) {
        throw StateError('E2EE 内容运行时缺少附件上传组件');
      }
      final retirements = <_MaterializedAttachmentSourceRetirement>[];
      final drafts = <E2eeAttachmentUploadDraft>[];
      for (final input in inputs) {
        for (var index = 0; index < input.attachments.length; index++) {
          final attachment = input.attachments[index];
          if (attachment.hasRemoteIdentity) continue;
          drafts.add(
            await uploads.prepareDraft(
              localAssetId: attachment.assetId,
              target: E2eeMessageAttachmentUploadTarget(
                revisionId: input.targetRevisionId,
                ordinal: index,
              ),
              sourcePath: attachment.path,
              kind: E2eeAttachmentKind.values.byName(attachment.kind),
              totalPlaintextBytes: attachment.byteSize,
              contentSha256: _decodeSha256Hex(attachment.contentHash),
              displayName: attachment.displayName,
              mediaType: attachment.mediaType,
            ),
          );
          final retirement = _materializedSourceRetirements[attachment];
          if (retirement != null &&
              !retirements.any(
                (existing) =>
                    p.equals(existing.sourcePath, retirement.sourcePath),
              )) {
            retirements.add(retirement);
          }
        }
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
            for (final retirement in retirements) {
              await repository.recordMaterializedSourceRetirement(
                retirementId: retirement.retirementId,
                originalPath: retirement.sourcePath,
                quarantinePath: retirement.quarantinePath,
                createdAt: now,
              );
            }
          }
          return value;
        },
      );
      if (persistedTarget) {
        _markAttachmentUploadWork();
        if (retirements.isNotEmpty) _scheduleAssetMaintenance();
      }
      if (_state == E2eeChatContentRuntimeState.ready) {
        _scheduler?.wake();
      }
      return result;
    } finally {
      for (final input in inputs) {
        for (final attachment in input.attachments) {
          _materializedSourceRetirements[attachment] = null;
        }
      }
      _finishLocalOperation();
    }
  }

  @override
  Future<T> runLocalBatchWithConfigAssets<T>({
    required Iterable<SyncEntityKey> keys,
    required Iterable<ConfigAssetSyncTarget> targets,
    required bool Function(T result) targetWasPersisted,
    required Future<T> Function() write,
  }) async {
    final inputs = List<ConfigAssetSyncTarget>.unmodifiable(targets);
    if (inputs.isEmpty) return runLocalBatch<T>(keys: keys, write: write);
    final targetKeys = <E2eeConfigAssetKey>{};
    for (final input in inputs) {
      if (!targetKeys.add(input.key) ||
          (input.asset != null && input.asset!.key != input.key)) {
        throw StateError('配置资产事务目标重复或身份不匹配');
      }
    }
    await initialize();
    _requireReadyForLocalOperation();
    _activeLocalWrites++;
    try {
      final uploads = _attachmentUploads;
      final uploadCommands = _attachmentUploadCommands;
      final repository = _databaseLease?.repository;
      if (uploads == null || uploadCommands == null || repository == null) {
        throw StateError('E2EE 内容运行时缺少配置资产上传组件');
      }
      final drafts = <E2eeConfigAssetKey, E2eeAttachmentUploadDraft>{};
      for (final input in inputs) {
        final asset = input.asset;
        if (asset == null) continue;
        drafts[input.key] = await uploads.prepareDraft(
          localAssetId: asset.assetId,
          target: E2eeConfigAssetUploadTarget(input.key),
          sourcePath: asset.path,
          kind: E2eeAttachmentKind.values.byName(asset.kind),
          totalPlaintextBytes: asset.byteSize,
          contentSha256: _decodeSha256Hex(asset.contentHash),
          displayName: asset.displayName,
          mediaType: asset.mediaType,
        );
      }

      var persistedTarget = false;
      var mayHaveOrphanedAssets = false;
      final now = _utcNow().toUtc();
      final result = await _runLocalBatchCore<T>(
        keys: keys,
        write: () async {
          final value = await write();
          persistedTarget = targetWasPersisted(value);
          if (!persistedTarget) return value;
          for (final input in inputs) {
            final asset = input.asset;
            if (asset == null) {
              mayHaveOrphanedAssets |= await repository.e2eeConfigAssetCommands
                  .remove(input.key);
              continue;
            }
            mayHaveOrphanedAssets |= await repository.e2eeConfigAssetCommands
                .replace(
                  key: input.key,
                  asset: MessageAssetRegistration(
                    assetId: asset.assetId,
                    contentHash: asset.contentHash,
                    path: asset.path,
                    byteSize: asset.byteSize,
                    kind: asset.kind,
                    displayName: asset.displayName,
                    mediaType: asset.mediaType,
                  ),
                  now: now,
                );
            final draft = drafts[input.key];
            if (draft == null) {
              throw StateError('E2EE 配置资产上传草稿缺失');
            }
            await uploadCommands.create(draft: draft, now: now);
          }
          return value;
        },
      );
      if (persistedTarget) {
        if (drafts.isNotEmpty) _markAttachmentUploadWork();
        if (mayHaveOrphanedAssets) _scheduleAssetMaintenance();
      }
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
    await _awaitLocalOperationReadiness();
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

  @override
  Future<T> runLocalImportBatches<T>({
    required Stream<List<SyncEntityKey>> keyBatches,
    required Stream<List<String>> attachmentRevisionBatches,
    required Future<T> Function() write,
  }) async {
    await initialize();
    _requireReadyForLocalOperation();
    _activeLocalWrites++;
    final materialized = <ChatMessageAttachment>[];
    try {
      final outbox = _outbox;
      final uploads = _attachmentUploads;
      final commands = _attachmentUploadCommands;
      final repository = _databaseLease?.repository;
      if (outbox == null ||
          uploads == null ||
          commands == null ||
          repository == null) {
        throw StateError('E2EE 内容运行时缺少导入组件');
      }
      var hasAttachmentUploadWork = false;
      var hasMaterializedSourceRetirements = false;
      final result = await outbox.runLocalImportBatches<T>(
        keyBatches: keyBatches,
        write: () async {
          final value = await write();
          final prepared = await _prepareImportedAttachmentDrafts(
            revisionBatches: attachmentRevisionBatches,
            uploads: uploads,
            commands: commands,
            repository: repository,
            materialized: materialized,
          );
          hasAttachmentUploadWork = prepared.created;
          hasMaterializedSourceRetirements = prepared.hasRetirements;
          return value;
        },
      );
      if (hasAttachmentUploadWork) _markAttachmentUploadWork();
      if (hasMaterializedSourceRetirements) {
        _scheduleMaterializedSourceRetirement();
      }
      if (_state == E2eeChatContentRuntimeState.ready) {
        _scheduler?.wake();
      }
      return result;
    } finally {
      for (final attachment in materialized) {
        _materializedSourceRetirements[attachment] = null;
      }
      _finishLocalOperation();
    }
  }

  Future<({bool created, bool hasRetirements})>
  _prepareImportedAttachmentDrafts({
    required Stream<List<String>> revisionBatches,
    required E2eeAttachmentUploadCoordinator uploads,
    required E2eeAttachmentUploadCommands commands,
    required ChatDatabaseRepository repository,
    required List<ChatMessageAttachment> materialized,
  }) async {
    var created = false;
    final retirements = <_MaterializedAttachmentSourceRetirement>[];
    await for (final revisionBatch in revisionBatches) {
      if (revisionBatch.length > syncImportEntityBatchLimit) {
        throw RangeError.range(
          revisionBatch.length,
          0,
          syncImportEntityBatchLimit,
          'attachmentRevisionBatch.length',
        );
      }
      final seenRevisionIds = <String>{};
      for (final revisionId in revisionBatch) {
        if (!seenRevisionIds.add(revisionId)) continue;
        final message = await repository.getMessage(revisionId);
        if (message == null) {
          throw StateError('导入附件目标消息不存在');
        }
        final localAttachments = message.attachments
            .where((attachment) => !attachment.hasRemoteIdentity)
            .toList(growable: false);
        if (localAttachments.isEmpty) continue;
        final stored = await _materializeLocalAttachmentsCore(localAttachments);
        materialized.addAll(stored);
        var localIndex = 0;
        final replacements = <ChatMessageAttachment>[
          for (final attachment in message.attachments)
            if (attachment.hasRemoteIdentity)
              attachment
            else
              stored[localIndex++],
        ];
        final drafts = <E2eeAttachmentUploadDraft>[];
        for (var index = 0; index < replacements.length; index++) {
          final attachment = replacements[index];
          if (attachment.hasRemoteIdentity) continue;
          final original = message.attachments[index];
          await repository.relocateLocalAssetForImport(
            assetId: original.assetId,
            expectedContentHash: original.contentHash,
            expectedByteSize: original.byteSize,
            expectedPath: original.path,
            targetPath: attachment.path,
          );
          drafts.add(
            await uploads.prepareDraft(
              localAssetId: attachment.assetId,
              targetRevisionId: revisionId,
              targetOrdinal: index,
              sourcePath: attachment.path,
              kind: E2eeAttachmentKind.values.byName(attachment.kind),
              totalPlaintextBytes: attachment.byteSize,
              contentSha256: _decodeSha256Hex(attachment.contentHash),
              displayName: attachment.displayName,
              mediaType: attachment.mediaType,
            ),
          );
          final retirement = _materializedSourceRetirements[attachment];
          if (retirement != null &&
              !retirements.any(
                (existing) =>
                    p.equals(existing.sourcePath, retirement.sourcePath),
              )) {
            retirements.add(retirement);
          }
        }
        final now = _utcNow();
        for (final draft in drafts) {
          await commands.create(draft: draft, now: now);
        }
        created = true;
      }
    }
    for (final retirement in retirements) {
      await repository.recordMaterializedSourceRetirement(
        retirementId: retirement.retirementId,
        originalPath: retirement.sourcePath,
        quarantinePath: retirement.quarantinePath,
        createdAt: _utcNow(),
      );
    }
    return (created: created, hasRetirements: retirements.isNotEmpty);
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

  Future<bool> _applyConfigAssetChanges({
    required List<E2eeSyncPulledChange> changes,
    required E2eeAttachmentDownloadCoordinator downloads,
    required E2eeConfigAssetCommands commands,
  }) async {
    var mayHaveOrphanedAssets = false;
    final now = _utcNow().toUtc();
    for (final change in changes) {
      final entityKey = change.state.entityKey;
      final fields = e2eeConfigAssetPayloadFieldsFor(entityKey);
      if (fields.isEmpty) continue;
      final keys = <E2eeConfigAssetSlot, E2eeConfigAssetKey>{
        for (final field in fields)
          field.slot: E2eeConfigAssetKey(
            entityKey: entityKey,
            slot: field.slot,
          ),
      };
      switch (change) {
        case E2eeSyncPulledTombstoneChange():
          for (final key in keys.values) {
            mayHaveOrphanedAssets |= await commands.remove(key);
          }
        case E2eeSyncPulledValueChange(:final payload):
          final registrations = await downloads.requireReadyForConfigApply(
            change,
          );
          final bySlot = <E2eeConfigAssetSlot, MessageAssetRegistration>{
            for (final registration in registrations)
              registration.key.slot: registration.asset,
          };
          for (final field in fields) {
            final key = keys[field.slot]!;
            if (payload[field.identityField] == null) {
              mayHaveOrphanedAssets |= await commands.remove(key);
              continue;
            }
            final asset = bySlot[field.slot];
            if (asset == null) {
              throw StateError('E2EE 配置资产下载登记缺失');
            }
            mayHaveOrphanedAssets |= await commands.replace(
              key: key,
              asset: asset,
              now: now,
            );
          }
      }
    }
    return mayHaveOrphanedAssets;
  }

  void _markAttachmentUploadWork() {
    _attachmentUploadWorkGeneration++;
    _hasAttachmentUploadWork = true;
  }

  Future<void> _refreshAttachmentUploadWork(
    E2eeAttachmentUploadCommands commands,
  ) async {
    final scannedGeneration = _attachmentUploadWorkGeneration;
    final hasWork = await _attachmentWorkScanner(commands);
    // 扫描期间提交的新草稿拥有更新世代，旧 false 无权清除它的唤醒。
    if (hasWork || scannedGeneration == _attachmentUploadWorkGeneration) {
      _hasAttachmentUploadWork = hasWork;
    }
  }

  Future<_MaterializedAttachmentSourceRetirement?>
  _createMaterializedSourceRetirement({
    required String sourcePath,
    required String materializedPath,
  }) async {
    final source = p.normalize(File(sourcePath).absolute.path);
    final materialized = p.normalize(File(materializedPath).absolute.path);
    if (p.equals(source, materialized)) return null;
    final upload = await AppDirectories.getUploadDirectory();
    final images = await AppDirectories.getImagesDirectory();
    Directory? owner;
    for (final root in <Directory>[upload, images]) {
      if (SandboxPathResolver.isOwnedManagedPath(
        path: source,
        managedDirectory: root,
      )) {
        owner = root;
        break;
      }
    }
    if (owner == null) return null;
    final quarantineRoot = p.normalize(
      p.join(owner.absolute.path, '.kelivo-gc'),
    );
    if (p.equals(source, quarantineRoot) ||
        p.isWithin(quarantineRoot, source)) {
      return null;
    }
    final e2eeRoot = p.normalize(p.join(upload.absolute.path, 'e2ee'));
    if (p.equals(source, e2eeRoot) || p.isWithin(e2eeRoot, source)) {
      return null;
    }
    final retirementId = const Uuid().v4();
    return _MaterializedAttachmentSourceRetirement(
      retirementId: retirementId,
      sourcePath: source,
      quarantinePath: p.join(owner.absolute.path, '.kelivo-gc', retirementId),
    );
  }

  void _scheduleAssetMaintenance() {
    final chatService = _chatService;
    if (chatService == null) return;
    unawaited(() async {
      try {
        // 第一次调用可能正在等待启动维护；第二次保证处理其后提交的回执。
        await chatService.runAssetMaintenance();
        await chatService.runAssetMaintenance();
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'e2ee_chat_content_runtime',
            context: ErrorDescription('收尾 E2EE 受管资产失败'),
          ),
        );
      }
    }());
  }

  void _requireReadyForLocalOperation() {
    if (_state != E2eeChatContentRuntimeState.ready) {
      throw StateError('E2EE 内容运行时不接受新的本地写入');
    }
  }

  Future<void> _awaitLocalOperationReadiness() async {
    if (identical(Zone.current[_startupRecoveryZoneKey], this)) {
      _requireStillInitializing();
      return;
    }
    await initialize();
    _requireReadyForLocalOperation();
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

Future<bool> _defaultAttachmentUploadWorkScanner(
  E2eeAttachmentUploadCommands commands,
) => commands.hasRetryableWork();

void _validateLocalConfigAssetInput(LocalConfigAssetInput input) {
  final expectedKind = switch (input.key.slot) {
    E2eeConfigAssetSlot.avatar ||
    E2eeConfigAssetSlot.background => E2eeAttachmentKind.image,
    E2eeConfigAssetSlot.appFont ||
    E2eeConfigAssetSlot.codeFont => E2eeAttachmentKind.file,
  };
  if (input.sourcePath.trim().isEmpty || input.kind != expectedKind.name) {
    throw const FormatException('配置资产物化输入无效');
  }
  if (expectedKind == E2eeAttachmentKind.image) {
    if (input.displayName != null || input.mediaType != null) {
      throw const FormatException('配置图片资产不得携带文件元数据');
    }
    return;
  }
  if ((input.displayName ?? '').trim().isEmpty ||
      (input.mediaType ?? '').trim().isEmpty) {
    throw const FormatException('配置文件资产缺少显示名称或媒体类型');
  }
}

Future<({String contentHash, int bytes})> _measureConfigAssetFile(String path) {
  return Isolate.run(() async {
    final file = File(path);
    final digest = await sha256.bind(file.openRead()).first;
    final bytes = await file.length();
    if (bytes < 0 || bytes > KelivoAttachmentLimits.maxTotalPlaintextBytes) {
      throw const FormatException('配置资产文件长度超出限制');
    }
    return (contentHash: digest.toString(), bytes: bytes);
  });
}

String _sha256Hex(Uint8List value) =>
    value.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

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
  developer.log('E2EE 内容运行时资源清理失败', name: 'Kelivo.E2eeChatContentRuntime');
}
