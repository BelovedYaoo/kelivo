import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../services/chat/chat_service.dart';
import '../services/sync/chat_sync_adapter.dart';
import '../services/sync/cloud_attachment_sync_service.dart';
import '../services/sync/cloud_sync_client.dart';
import '../services/sync/cloud_sync_conflict_resolver.dart';
import '../services/sync/cloud_sync_coordinator.dart';
import '../services/sync/cloud_sync_mutation_planner.dart';
import '../services/sync/cloud_sync_store.dart';
import '../services/sync/cloud_sync_types.dart';
import '../services/sync/config_sync_adapter.dart';
import '../services/sync/sync_codec.dart';
import '../services/sync/sync_write_journal.dart';
import '../services/workspace/account_workspace_runtime.dart';
import 'assistant_provider.dart';
import 'instruction_injection_provider.dart';
import 'mcp_provider.dart';
import 'memory_provider.dart';
import 'quick_phrase_provider.dart';
import 'settings_provider.dart';
import 'user_provider.dart';
import 'world_book_provider.dart';

enum CloudSyncProviderStatus {
  initializing,
  signedOut,
  signingIn,
  signingOut,
  workspaceChangePending,
  idle,
  syncing,
  pendingSync,
  syncBlocked,
  needsAttention,
  paused,
  error,
}

enum CloudSyncInitialHydrationState {
  notRequired,
  pending,
  completed;

  static CloudSyncInitialHydrationState initialForWorkspace({
    required bool isLocalWorkspace,
  }) => isLocalWorkspace ? notRequired : pending;

  bool get allowsAssistantDefaults => switch (this) {
    notRequired || completed => true,
    pending => false,
  };
}

CloudSyncProviderStatus _resolveCloudSyncProviderStatus({
  required bool paused,
  required bool hasOpenConflicts,
  required bool hasBlockedWrites,
  required bool hasPendingWrites,
}) {
  if (paused) return CloudSyncProviderStatus.paused;
  if (hasOpenConflicts) return CloudSyncProviderStatus.needsAttention;
  if (hasBlockedWrites) return CloudSyncProviderStatus.syncBlocked;
  if (hasPendingWrites) return CloudSyncProviderStatus.pendingSync;
  return CloudSyncProviderStatus.idle;
}

final class CloudSyncProvider extends ChangeNotifier
    with WidgetsBindingObserver {
  CloudSyncProvider(
    this._chatService,
    this._store,
    this._writeJournal,
    this._workspaceRuntime, {
    required SettingsProvider settingsProvider,
    required AssistantProvider assistantProvider,
    required MemoryProvider memoryProvider,
    required McpProvider mcpProvider,
    required QuickPhraseProvider quickPhraseProvider,
    required InstructionInjectionProvider instructionInjectionProvider,
    required WorldBookProvider worldBookProvider,
    required UserProvider userProvider,
  }) : _initialHydrationState =
           CloudSyncInitialHydrationState.initialForWorkspace(
             isLocalWorkspace: _workspaceRuntime.current.isLocal,
           ),
       _configAdapter = ConfigSyncAdapter(
         settingsProvider: settingsProvider,
         assistantProvider: assistantProvider,
         memoryProvider: memoryProvider,
         mcpProvider: mcpProvider,
         quickPhraseProvider: quickPhraseProvider,
         instructionInjectionProvider: instructionInjectionProvider,
         worldBookProvider: worldBookProvider,
         userProvider: userProvider,
       );

  static const Duration automaticSyncInterval = Duration(seconds: 30);

  final ChatService _chatService;
  final ConfigSyncAdapter _configAdapter;
  final CloudSyncStore _store;
  final SyncWriteJournal _writeJournal;
  final AccountWorkspaceRuntime _workspaceRuntime;

  CloudSyncProviderStatus _status = CloudSyncProviderStatus.initializing;
  CloudSyncAccountSession? _session;
  CloudSyncRunSummary? _lastRun;
  CloudSyncException? _lastError;
  CloudSyncException? _deviceError;
  List<CloudSyncDeviceSession> _devices = const <CloudSyncDeviceSession>[];
  CloudSyncClient? _client;
  CloudSyncCoordinator? _coordinator;
  CloudSyncConflictResolver? _conflictResolver;
  CloudSyncMutationPlanner? _mutationPlanner;
  Future<void>? _initialization;
  Future<bool>? _activeSync;
  Future<bool>? _activeConflictRefresh;
  Future<bool>? _activeConflictResolution;
  Timer? _timer;
  bool _ready = false;
  bool _paused = false;
  bool _devicesLoading = false;
  bool _conflictsLoading = false;
  bool _conflictListTruncated = false;
  bool _foreground = true;
  bool _observingLifecycle = false;
  bool _disposed = false;
  Completer<void>? _sessionMutation;
  bool _journalExporterBound = false;
  bool _storeCloseScheduled = false;
  bool _workspaceRestartRequired = false;
  CloudSyncInitialHydrationState _initialHydrationState;
  int _sessionEpoch = 0;
  List<CloudSyncConflict> _conflicts = const <CloudSyncConflict>[];
  CloudSyncException? _conflictError;
  CloudSyncConflictResolutionFailureReason? _conflictResolutionFailure;
  String? _resolvingConflictId;

  CloudSyncProviderStatus get status => _status;
  CloudSyncAccountSession? get session => _session;
  CloudSyncRunSummary? get lastRun => _lastRun;
  CloudSyncException? get lastError => _lastError;
  CloudSyncException? get deviceError => _deviceError;
  List<CloudSyncDeviceSession> get devices =>
      List<CloudSyncDeviceSession>.unmodifiable(_devices);
  bool get initialized => _ready;
  bool get signedIn => _session != null;
  bool get workspaceRestartRequired => _workspaceRestartRequired;
  CloudSyncInitialHydrationState get initialHydrationState =>
      _initialHydrationState;
  bool get paused => _paused;
  bool get devicesLoading => _devicesLoading;
  List<CloudSyncConflict> get conflicts =>
      List<CloudSyncConflict>.unmodifiable(_conflicts);
  CloudSyncException? get conflictError => _conflictError;
  CloudSyncConflictResolutionFailureReason? get conflictResolutionFailure =>
      _conflictResolutionFailure;
  bool get conflictsLoading => _conflictsLoading;
  bool get conflictListTruncated => _conflictListTruncated;
  String? get resolvingConflictId => _resolvingConflictId;
  bool get _sessionMutationInProgress => _sessionMutation != null;

  Future<void> initialize() {
    if (_ready) return Future<void>.value();
    final active = _initialization;
    if (active != null) return active;

    final run = _initialize();
    _initialization = run;
    return run.whenComplete(() {
      if (identical(_initialization, run)) {
        _initialization = null;
      }
    });
  }

  Future<void> _initialize() async {
    if (!_observingLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _observingLifecycle = true;
    }
    _lastError = null;
    _setStatus(CloudSyncProviderStatus.initializing);

    try {
      await _chatService.init();
      if (_disposed) return;
      final store = _store;
      await _configAdapter.ready;
      if (_disposed) return;
      final session = _workspaceRuntime.current.session;
      if (session != null && session.baseUrl != defaultCloudSyncBaseUrl) {
        await _workspaceRuntime.signOut();
        await _writeJournal.transitionSession(null);
        _workspaceRestartRequired = true;
        _initialHydrationState = CloudSyncInitialHydrationState.pending;
        _setStatus(CloudSyncProviderStatus.workspaceChangePending);
        _ready = true;
        return;
      }
      _session = session;
      if (session == null) {
        _paused = false;
        _ready = true;
        _setStatus(CloudSyncProviderStatus.signedOut);
        return;
      }

      await _repairBlockedAssistantPayloadMutations(session);
      if (_disposed) return;
      _paused = store.isPaused(session);
      _connect(session);
      await _writeJournal.transitionSession(session);
      await _writeJournal.recover();
      if (_disposed) return;
      _ready = true;
      _setStatus(
        _paused ? CloudSyncProviderStatus.paused : CloudSyncProviderStatus.idle,
      );
      if (_paused) {
        unawaited(refreshConflicts());
      } else {
        _startAutomaticSync();
        unawaited(syncNow());
      }
    } catch (error, stackTrace) {
      _recordFailure(
        error,
        stackTrace,
        operation: '初始化云同步',
        status: CloudSyncProviderStatus.error,
      );
    }
  }

  Future<void> _repairBlockedAssistantPayloadMutations(
    CloudSyncAccountSession session,
  ) async {
    for (final mutation in _store.blockedOutbox(session)) {
      final replacement = _repairLegacyAssistantMediaMutation(
        session,
        mutation,
      );
      if (replacement == null) continue;

      // 新 mutation 先落盘，再移除服务端已记住结果的旧 mutationId；中途退出时，
      // 确定性的替代 ID 可让下次启动安全续做而不会丢失账号级恢复状态。
      await _store.enqueueOutbox(session, replacement, merge: false);
      await _store.removeOutbox(session, mutation.mutationId);
    }
  }

  CloudSyncOutboxMutation? _repairLegacyAssistantMediaMutation(
    CloudSyncAccountSession session,
    CloudSyncOutboxMutation mutation,
  ) {
    if (mutation.entityType != CloudSyncEntityType.assistant ||
        mutation.lastErrorCode != 'SYNC_PAYLOAD_INVALID') {
      return null;
    }
    final replacementId = const Uuid().v5(
      Namespace.url.value,
      'kelivo://cloud-sync/assistant-media-repair/'
      '${session.accountScope}/${mutation.mutationId}',
    );
    switch (mutation.operation) {
      case CloudSyncMutationOperation.create:
        final payload = mutation.payload;
        final schemaVersion = mutation.schemaVersion;
        if (payload == null ||
            schemaVersion == null ||
            (payload.containsKey('avatar') &&
                payload.containsKey('background'))) {
          return null;
        }
        return CloudSyncOutboxMutation.create(
          mutationId: replacementId,
          entityType: mutation.entityType,
          entityId: mutation.entityId,
          parentId: mutation.parentId,
          schemaVersion: schemaVersion,
          payload: <String, Object?>{
            ...payload,
            if (!payload.containsKey('avatar')) 'avatar': null,
            if (!payload.containsKey('background')) 'background': null,
          },
          createdAt: mutation.createdAt,
        );
      case CloudSyncMutationOperation.update:
        final repairsMediaRemoval = mutation.patch.any(
          (patch) =>
              patch.operation == CloudSyncPatchOperation.remove &&
              (patch.path == '/avatar' || patch.path == '/background'),
        );
        if (!repairsMediaRemoval) return null;
        return CloudSyncOutboxMutation.update(
          mutationId: replacementId,
          entityType: mutation.entityType,
          entityId: mutation.entityId,
          baseRevision: mutation.baseRevision,
          schemaVersion: mutation.schemaVersion,
          patch: mutation.patch
              .map(
                (patch) =>
                    patch.operation == CloudSyncPatchOperation.remove &&
                        (patch.path == '/avatar' || patch.path == '/background')
                    ? CloudSyncPatch.replace(patch.path, null)
                    : patch,
              )
              .toList(growable: false),
          createdAt: mutation.createdAt,
        );
      case CloudSyncMutationOperation.delete ||
          CloudSyncMutationOperation.restore:
        return null;
    }
  }

  Future<bool> login({
    required String loginName,
    required String password,
    required String deviceName,
  }) async {
    await initialize();
    final store = _store;
    if (!_ready || _disposed) return false;
    if (_session != null || _sessionMutationInProgress) {
      _lastError = const CloudSyncException(
        kind: CloudSyncFailureKind.conflict,
        retryable: false,
        serverCode: 'SYNC_SESSION_ALREADY_ACTIVE',
      );
      _notify();
      return false;
    }

    _beginSessionMutation();
    _lastError = null;
    _deviceError = null;
    _devicesLoading = false;
    _conflicts = const <CloudSyncConflict>[];
    _conflictError = null;
    _conflictResolutionFailure = null;
    _conflictListTruncated = false;
    _conflictsLoading = false;
    _setStatus(CloudSyncProviderStatus.signingIn);
    CloudSyncClient? loginClient;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (_disposed) return false;
      loginClient = CloudSyncClient();
      final session = await loginClient.login(
        loginName: loginName.trim(),
        password: password,
        deviceName: deviceName.trim(),
        platform: _currentPlatform(),
        clientVersion: packageInfo.version,
      );
      if (_disposed) return false;
      final workspaceBinding = await _workspaceRuntime.bindAccount(session);
      if (workspaceBinding is AccountWorkspaceRestartRequired) {
        _workspaceRestartRequired = true;
        _setStatus(CloudSyncProviderStatus.workspaceChangePending);
        return true;
      }
      await store.savePaused(session, paused: false);
      if (_disposed) return false;

      _workspaceRestartRequired = false;
      _initialHydrationState = CloudSyncInitialHydrationState.pending;
      _session = session;
      _paused = false;
      await _repairBlockedAssistantPayloadMutations(session);
      if (_disposed) return false;
      _connect(session, client: loginClient);
      loginClient = null;
      try {
        await _writeJournal.transitionSession(session);
        await _writeJournal.recover();
      } catch (error, stackTrace) {
        if (_disposed) return false;
        _recordFailure(
          error,
          stackTrace,
          operation: '恢复云同步写入',
          status: CloudSyncProviderStatus.error,
        );
        _startAutomaticSync();
        return false;
      }
      if (_disposed) return false;
      _setStatus(CloudSyncProviderStatus.idle);
      _startAutomaticSync();
      final connectedEpoch = _sessionEpoch;
      final synchronized = await syncNow();
      return synchronized &&
          !_disposed &&
          connectedEpoch == _sessionEpoch &&
          identical(_session, session);
    } catch (error, stackTrace) {
      _recordFailure(
        error,
        stackTrace,
        operation: '登录云同步',
        status: _session == null
            ? CloudSyncProviderStatus.signedOut
            : CloudSyncProviderStatus.error,
      );
      return false;
    } finally {
      loginClient?.close(force: true);
      _endSessionMutation();
    }
  }

  Future<bool> logout() async {
    await initialize();
    if (_disposed || _sessionMutationInProgress) return false;
    _beginSessionMutation();
    _session = null;
    _devicesLoading = false;
    _setStatus(CloudSyncProviderStatus.signingOut);

    final activeSync = _activeSync;
    final activeConflictRefresh = _activeConflictRefresh;
    final activeConflictResolution = _activeConflictResolution;
    _sessionEpoch++;
    _stopAutomaticSync();
    _client?.close(force: true);
    _client = null;
    _coordinator = null;
    _conflictResolver = null;
    _mutationPlanner = null;
    try {
      if (activeSync != null) {
        await activeSync;
      }
      if (activeConflictRefresh != null) {
        await activeConflictRefresh;
      }
      if (activeConflictResolution != null) {
        await activeConflictResolution;
      }
      await _writeJournal.transitionSession(null);
      await _workspaceRuntime.signOut();
    } catch (error, stackTrace) {
      _recordFailure(
        error,
        stackTrace,
        operation: '退出云同步',
        status: CloudSyncProviderStatus.error,
      );
      if (_disposed) return false;
      // 退出失败后不得重新启用旧 token；持久层会在下次冷启动时
      // 根据 tombstone 或仍有效的会话记录收敛到唯一状态。
      _workspaceRestartRequired = true;
      _initialHydrationState = CloudSyncInitialHydrationState.pending;
      _setStatus(CloudSyncProviderStatus.workspaceChangePending);
      return false;
    } finally {
      _endSessionMutation();
    }

    _stopAutomaticSync();
    _paused = false;
    _devices = const <CloudSyncDeviceSession>[];
    _lastRun = null;
    _lastError = null;
    _deviceError = null;
    _conflicts = const <CloudSyncConflict>[];
    _conflictError = null;
    _conflictResolutionFailure = null;
    _conflictListTruncated = false;
    _conflictsLoading = false;
    _resolvingConflictId = null;
    _workspaceRestartRequired = true;
    _initialHydrationState = CloudSyncInitialHydrationState.pending;
    _setStatus(CloudSyncProviderStatus.workspaceChangePending);
    return true;
  }

  Future<bool> setPaused(bool value) async {
    await initialize();
    final store = _store;
    final session = _session;
    if (session == null || _disposed || _sessionMutationInProgress) {
      return false;
    }
    if (value == _paused) return true;
    _beginSessionMutation();
    final epoch = _sessionEpoch;

    try {
      await store.savePaused(session, paused: value);
      if (_disposed ||
          epoch != _sessionEpoch ||
          !identical(_session, session)) {
        return false;
      }

      _paused = value;
      _lastError = null;
      if (value) {
        final activeSync = _activeSync;
        final activeConflictRefresh = _activeConflictRefresh;
        final activeConflictResolution = _activeConflictResolution;
        _sessionEpoch++;
        _stopAutomaticSync();
        _devicesLoading = false;
        _client?.close(force: true);
        _client = null;
        _coordinator = null;
        _conflictResolver = null;
        _mutationPlanner = null;
        _setStatus(CloudSyncProviderStatus.paused);
        if (activeSync != null) await activeSync;
        if (activeConflictRefresh != null) {
          await activeConflictRefresh;
        }
        if (activeConflictResolution != null) {
          await activeConflictResolution;
        }
        if (_disposed || !identical(_session, session)) return false;
        _connect(session);
        _setStatus(CloudSyncProviderStatus.paused);
      } else {
        _setStatus(CloudSyncProviderStatus.idle);
        _startAutomaticSync();
        unawaited(syncNow());
      }
      return true;
    } catch (error, stackTrace) {
      _recordFailure(
        error,
        stackTrace,
        operation: '保存云同步开关',
        status: CloudSyncProviderStatus.error,
      );
      return false;
    } finally {
      _endSessionMutation();
    }
  }

  Future<void> prepareWorkspaceRestart() async {
    if (!_workspaceRestartRequired) {
      throw StateError('account_workspace_restart_not_required');
    }
    _stopAutomaticSync();
    _client?.close(force: true);
    _client = null;
    _coordinator = null;
    _conflictResolver = null;
    _mutationPlanner = null;
    await _workspaceRuntime.prepareRestartHandoff();
  }

  Future<bool> syncAfterLocalWrites() async {
    await initialize();
    final session = _session;
    if (_disposed ||
        !_ready ||
        session == null ||
        _paused ||
        _workspaceRestartRequired ||
        _sessionMutationInProgress) {
      return false;
    }
    final epoch = _sessionEpoch;

    final syncBeforeBarrier = _activeSync;
    if (syncBeforeBarrier != null) {
      await syncBeforeBarrier;
    }
    if (_disposed ||
        epoch != _sessionEpoch ||
        !identical(_session, session) ||
        _workspaceRestartRequired ||
        _sessionMutationInProgress) {
      return false;
    }

    try {
      // 本地 API 会在业务写完成后提前返回；同会话 transition 用作 journal
      // 屏障，确保后台导出与入队结束后才触发下一轮同步。
      await _writeJournal.transitionSession(session);
    } catch (error, stackTrace) {
      if (_disposed ||
          epoch != _sessionEpoch ||
          !identical(_session, session)) {
        return false;
      }
      _recordFailure(
        error,
        stackTrace,
        operation: '等待本地同步写入完成',
        status: CloudSyncProviderStatus.error,
      );
      return false;
    }
    if (_disposed ||
        epoch != _sessionEpoch ||
        !identical(_session, session) ||
        _workspaceRestartRequired ||
        _sessionMutationInProgress) {
      return false;
    }

    final syncAfterBarrier = _activeSync;
    if (syncAfterBarrier != null) {
      await syncAfterBarrier;
      if (_disposed ||
          epoch != _sessionEpoch ||
          !identical(_session, session) ||
          _workspaceRestartRequired ||
          _sessionMutationInProgress) {
        return false;
      }
    }
    return syncNow();
  }

  Future<bool> syncNow() {
    if (_activeConflictResolution != null) {
      return Future<bool>.value(false);
    }
    final activeConflictRefresh = _activeConflictRefresh;
    if (activeConflictRefresh != null) {
      return activeConflictRefresh.then((refreshed) {
        if (!refreshed || _disposed) return false;
        return syncNow();
      });
    }
    final active = _activeSync;
    if (active != null) return active;

    final run = _runSync();
    _activeSync = run;
    return run.whenComplete(() {
      if (identical(_activeSync, run)) {
        _activeSync = null;
      }
    });
  }

  Future<bool> _runSync() async {
    await initialize();
    final coordinator = _coordinator;
    final client = _client;
    final session = _session;
    if (_disposed ||
        !_ready ||
        coordinator == null ||
        client == null ||
        session == null ||
        _paused) {
      return false;
    }

    final epoch = _sessionEpoch;
    _lastError = null;
    _setStatus(CloudSyncProviderStatus.syncing);
    try {
      return await _store.runWithRescanStable(() async {
        final rescanRequest = _store.rescanRequest;
        if (rescanRequest?.hasActiveWrites == true) {
          _setStatus(CloudSyncProviderStatus.pendingSync);
          return false;
        }
        final result = await coordinator.synchronize(
          rescanEntityTypes: rescanRequest?.entityTypes ?? const <String>{},
          localAuthoritativeEntityTypes:
              rescanRequest?.localAuthoritativeEntityTypes ?? const <String>{},
        );
        final recovery = await _writeJournal.recover();
        if (epoch != _sessionEpoch || _disposed) return false;
        final conflicts = await client.listConflicts(
          state: CloudSyncConflictState.open,
          limit: 100,
        );
        if (epoch != _sessionEpoch || _disposed) return false;
        _conflicts = List<CloudSyncConflict>.unmodifiable(conflicts);
        _conflictListTruncated = conflicts.length >= 100;
        _conflictError = null;
        final outboxCounts = _store.outboxCounts(session);
        final hasBlockedWrites = outboxCounts.blocked > 0;
        final hasPendingWrites =
            recovery.deferredCount > 0 ||
            outboxCounts.total > outboxCounts.blocked;
        var complete =
            !hasBlockedWrites && !hasPendingWrites && conflicts.isEmpty;
        if (rescanRequest != null && complete) {
          complete = await _store.consumeRescanRequest(
            rescanRequest.generation,
          );
          if (epoch != _sessionEpoch || _disposed) return false;
        }
        _lastRun = result.copyWith(deferredWriteCount: recovery.deferredCount);
        _lastError = null;
        if (_initialHydrationState == CloudSyncInitialHydrationState.pending) {
          _initialHydrationState = CloudSyncInitialHydrationState.completed;
        }
        _setStatus(
          _resolveCloudSyncProviderStatus(
            paused: _paused,
            hasOpenConflicts: conflicts.isNotEmpty,
            hasBlockedWrites: hasBlockedWrites,
            hasPendingWrites: hasPendingWrites || !complete,
          ),
        );
        return complete;
      });
    } catch (error, stackTrace) {
      if (epoch != _sessionEpoch || _disposed) return false;
      _recordFailure(
        error,
        stackTrace,
        operation: '执行云同步',
        status: CloudSyncProviderStatus.error,
      );
      return false;
    }
  }

  Future<bool> refreshConflicts() {
    final active = _activeConflictRefresh;
    if (active != null) return active;
    final activeSync = _activeSync;
    if (activeSync != null) return activeSync;
    final activeResolution = _activeConflictResolution;
    if (activeResolution != null) return activeResolution;

    final run = _runRefreshConflicts();
    _activeConflictRefresh = run;
    return run.whenComplete(() {
      if (identical(_activeConflictRefresh, run)) {
        _activeConflictRefresh = null;
      }
    });
  }

  Future<bool> _runRefreshConflicts() async {
    await initialize();
    final client = _client;
    if (client == null || _session == null || _disposed) return false;
    if (_activeConflictResolution != null) return false;
    final epoch = _sessionEpoch;
    _conflictsLoading = true;
    _conflictError = null;
    _notify();
    try {
      await _refreshConflicts(client, epoch);
      if (epoch != _sessionEpoch || _disposed) return false;
      _updateAttentionStatus();
      return true;
    } catch (error, stackTrace) {
      if (epoch != _sessionEpoch || _disposed) return false;
      _conflictError = _normalizeFailure(error);
      debugPrint('读取同步冲突失败：$error\n$stackTrace');
      return false;
    } finally {
      if (epoch == _sessionEpoch && !_disposed) {
        _conflictsLoading = false;
        _notify();
      }
    }
  }

  Future<bool> resolveConflict(
    CloudSyncConflict conflict,
    Set<String> localPaths,
  ) {
    if (_activeConflictRefresh != null) {
      return Future<bool>.value(false);
    }
    final active = _activeConflictResolution;
    if (active != null) return active;

    final run = _runConflictResolution(conflict, localPaths);
    _activeConflictResolution = run;
    return run.whenComplete(() {
      if (identical(_activeConflictResolution, run)) {
        _activeConflictResolution = null;
      }
    });
  }

  Future<bool> _runConflictResolution(
    CloudSyncConflict conflict,
    Set<String> localPaths,
  ) async {
    await initialize();
    final activeSync = _activeSync;
    if (activeSync != null) {
      await activeSync;
    }
    final resolver = _conflictResolver;
    final client = _client;
    if (_disposed ||
        _paused ||
        _session == null ||
        resolver == null ||
        client == null) {
      return false;
    }
    final epoch = _sessionEpoch;
    _resolvingConflictId = conflict.conflictId;
    _conflictResolutionFailure = null;
    _conflictError = null;
    _notify();
    try {
      final resolved = await _store.runWithRescanStable(() async {
        if (_store.rescanRequest?.hasActiveWrites == true) return false;
        await resolver.resolve(conflict, Set<String>.unmodifiable(localPaths));
        return true;
      });
      if (!resolved) {
        _setStatus(CloudSyncProviderStatus.pendingSync);
        return false;
      }
      if (epoch != _sessionEpoch || _disposed) return false;
      await _refreshConflicts(client, epoch);
      if (epoch != _sessionEpoch || _disposed) return false;
      _updateAttentionStatus();
      return true;
    } on CloudSyncConflictResolutionException catch (error, stackTrace) {
      if (epoch != _sessionEpoch || _disposed) return false;
      _conflictResolutionFailure = error.reason;
      debugPrint('解决同步冲突失败：$error\n$stackTrace');
      return false;
    } catch (error, stackTrace) {
      if (epoch != _sessionEpoch || _disposed) return false;
      _conflictError = _normalizeFailure(error);
      debugPrint('解决同步冲突失败：$error\n$stackTrace');
      return false;
    } finally {
      if (epoch == _sessionEpoch && !_disposed) {
        _resolvingConflictId = null;
        _notify();
      }
    }
  }

  Future<void> _refreshConflicts(CloudSyncClient client, int epoch) async {
    final conflicts = await client.listConflicts(
      state: CloudSyncConflictState.open,
      limit: 100,
    );
    if (epoch != _sessionEpoch || _disposed) return;
    _conflicts = List<CloudSyncConflict>.unmodifiable(conflicts);
    _conflictListTruncated = conflicts.length >= 100;
    _conflictError = null;
  }

  void _updateAttentionStatus() {
    final session = _session;
    if (session == null || _disposed) return;
    if (_paused) {
      _status = CloudSyncProviderStatus.paused;
      return;
    }
    final hasDeferredWrites = (_lastRun?.deferredWriteCount ?? 0) > 0;
    final outboxCounts = _store.outboxCounts(session);
    _status = _resolveCloudSyncProviderStatus(
      paused: false,
      hasOpenConflicts: _conflicts.isNotEmpty,
      hasBlockedWrites: outboxCounts.blocked > 0,
      hasPendingWrites:
          outboxCounts.total > outboxCounts.blocked ||
          hasDeferredWrites ||
          _store.rescanRequest != null,
    );
  }

  Future<bool> refreshDevices() async {
    await initialize();
    final client = _client;
    if (client == null || _session == null) return false;
    final epoch = _sessionEpoch;
    _devicesLoading = true;
    _notify();
    try {
      final page = await client.listDevices(pageSize: 100);
      if (epoch != _sessionEpoch || _disposed) return false;
      _devices = page.items;
      _deviceError = null;
      return true;
    } catch (error, stackTrace) {
      if (epoch != _sessionEpoch || _disposed) return false;
      _recordDeviceFailure(error, stackTrace, operation: '读取同步设备');
      return false;
    } finally {
      if (epoch == _sessionEpoch && !_disposed) {
        _devicesLoading = false;
        _notify();
      }
    }
  }

  Future<bool> revokeDevice(String deviceId) async {
    await initialize();
    final client = _client;
    final session = _session;
    if (client == null || session == null) return false;
    final epoch = _sessionEpoch;

    try {
      final revoked = await client.revokeDevice(deviceId);
      if (epoch != _sessionEpoch || _disposed) return false;
      if (revoked.isCurrent) {
        return logout();
      }
      await refreshDevices();
      return true;
    } catch (error, stackTrace) {
      if (epoch != _sessionEpoch || _disposed) return false;
      _recordDeviceFailure(error, stackTrace, operation: '撤销同步设备');
      return false;
    }
  }

  void clearError() {
    if (_lastError == null &&
        _deviceError == null &&
        _conflictError == null &&
        _conflictResolutionFailure == null) {
      return;
    }
    _lastError = null;
    _deviceError = null;
    _conflictError = null;
    _conflictResolutionFailure = null;
    if (_status == CloudSyncProviderStatus.error) {
      if (_session == null) {
        _status = CloudSyncProviderStatus.signedOut;
      } else {
        _updateAttentionStatus();
      }
    }
    _notify();
  }

  void _connect(CloudSyncAccountSession session, {CloudSyncClient? client}) {
    _sessionEpoch++;
    _client?.close(force: true);
    final nextClient = client ?? CloudSyncClient(token: session.token);
    nextClient.setToken(session.token);
    _client = nextClient;
    final attachmentSyncService = CloudAttachmentSyncService(
      session,
      nextClient,
      _store,
    );
    final adapters = <SyncEntityAdapter>[
      _configAdapter,
      ChatSyncAdapter(_chatService, attachmentSyncService),
    ];
    final mutationPlanner = CloudSyncMutationPlanner(
      _store,
      adapters: adapters,
    );
    _mutationPlanner = mutationPlanner;
    final coordinator = CloudSyncCoordinator(
      session,
      nextClient,
      _store,
      _writeJournal,
      adapters: adapters,
      mutationPlanner: mutationPlanner,
    );
    _coordinator = coordinator;
    _conflictResolver = CloudSyncConflictResolver(
      session: session,
      client: nextClient,
      store: _store,
      writeJournal: _writeJournal,
      adapters: adapters,
      synchronize: () async {
        final rescanRequest = _store.rescanRequest;
        if (rescanRequest?.hasActiveWrites == true) {
          throw StateError('本地批量写入尚未完成，不能解决同步冲突');
        }
        final result = await coordinator.synchronize(
          rescanEntityTypes: rescanRequest?.entityTypes ?? const <String>{},
          localAuthoritativeEntityTypes:
              rescanRequest?.localAuthoritativeEntityTypes ?? const <String>{},
        );
        final recovery = await _writeJournal.recover();
        if (!_disposed && identical(_session, session)) {
          _lastRun = result.copyWith(
            deferredWriteCount: recovery.deferredCount,
          );
          if (_initialHydrationState ==
              CloudSyncInitialHydrationState.pending) {
            _initialHydrationState = CloudSyncInitialHydrationState.completed;
            _notify();
          }
        }
      },
    );
    if (!_journalExporterBound) {
      _writeJournal.bindExporter(_captureLocalIntents);
      _journalExporterBound = true;
    }
  }

  Future<Map<SyncEntityKey, SyncWriteDisposition>> _captureLocalIntents(
    List<SyncWriteIntent> intents,
  ) {
    final session = _session;
    final mutationPlanner = _mutationPlanner;
    if (session == null || mutationPlanner == null) {
      return Future<Map<SyncEntityKey, SyncWriteDisposition>>.value(
        <SyncEntityKey, SyncWriteDisposition>{
          for (final intent in intents)
            SyncEntityKey(
              entityType: intent.entityType.wireName,
              entityId: intent.entityId,
            ): SyncWriteDisposition.deferred,
        },
      );
    }
    return mutationPlanner.captureLocalIntents(session, intents);
  }

  void _startAutomaticSync() {
    _stopAutomaticSync();
    if (_disposed ||
        !_foreground ||
        _paused ||
        _session == null ||
        !_ready ||
        _status == CloudSyncProviderStatus.signingOut) {
      return;
    }
    _timer = Timer.periodic(automaticSyncInterval, (_) {
      unawaited(syncNow());
    });
  }

  void _stopAutomaticSync() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _foreground = true;
        _startAutomaticSync();
        if (_session != null && !_paused) {
          unawaited(syncNow());
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _foreground = false;
        _stopAutomaticSync();
    }
  }

  CloudSyncPlatform _currentPlatform() {
    if (kIsWeb) {
      throw const CloudSyncException(
        kind: CloudSyncFailureKind.validation,
        retryable: false,
        serverCode: 'SYNC_PLATFORM_UNSUPPORTED',
      );
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => CloudSyncPlatform.android,
      TargetPlatform.iOS => CloudSyncPlatform.ios,
      TargetPlatform.macOS => CloudSyncPlatform.macos,
      TargetPlatform.windows => CloudSyncPlatform.windows,
      TargetPlatform.linux => CloudSyncPlatform.linux,
      TargetPlatform.fuchsia => throw const CloudSyncException(
        kind: CloudSyncFailureKind.validation,
        retryable: false,
        serverCode: 'SYNC_PLATFORM_UNSUPPORTED',
      ),
    };
  }

  void _recordFailure(
    Object error,
    StackTrace stackTrace, {
    required String operation,
    CloudSyncProviderStatus? status,
  }) {
    _lastError = _normalizeFailure(error);
    if (status != null) {
      _status = status;
    }
    debugPrint('$operation失败：$error\n$stackTrace');
    _notify();
  }

  void _recordDeviceFailure(
    Object error,
    StackTrace stackTrace, {
    required String operation,
  }) {
    _deviceError = _normalizeFailure(error);
    debugPrint('$operation失败：$error\n$stackTrace');
    _notify();
  }

  CloudSyncException _normalizeFailure(Object error) {
    if (error is CloudSyncException) return error;
    if (error is FormatException) {
      return const CloudSyncException(
        kind: CloudSyncFailureKind.invalidResponse,
        retryable: false,
      );
    }
    return const CloudSyncException(
      kind: CloudSyncFailureKind.unknown,
      retryable: false,
    );
  }

  void _setStatus(CloudSyncProviderStatus value) {
    _status = value;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _beginSessionMutation() {
    if (_sessionMutation != null) {
      throw StateError('云同步会话变更已在执行');
    }
    _sessionMutation = Completer<void>();
  }

  void _endSessionMutation() {
    final mutation = _sessionMutation;
    _sessionMutation = null;
    mutation?.complete();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionEpoch++;
    _stopAutomaticSync();
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _client?.close(force: true);
    if (!_storeCloseScheduled) {
      _storeCloseScheduled = true;
      unawaited(_closeStoreAfterOperations());
    }
    super.dispose();
  }

  Future<void> _closeStoreAfterOperations() async {
    try {
      await _initialization;
    } catch (error, stackTrace) {
      debugPrint('关闭同步存储前等待初始化失败：$error\n$stackTrace');
    }
    final sessionMutation = _sessionMutation?.future;
    if (sessionMutation != null) {
      try {
        await sessionMutation;
      } catch (error, stackTrace) {
        debugPrint('关闭同步存储前等待会话变更失败：$error\n$stackTrace');
      }
    }
    try {
      await _activeSync;
    } catch (error, stackTrace) {
      debugPrint('关闭同步存储前等待同步失败：$error\n$stackTrace');
    }
    try {
      await _activeConflictRefresh;
    } catch (error, stackTrace) {
      debugPrint('关闭同步存储前等待冲突刷新失败：$error\n$stackTrace');
    }
    try {
      await _activeConflictResolution;
    } catch (error, stackTrace) {
      debugPrint('关闭同步存储前等待冲突处理失败：$error\n$stackTrace');
    }
    await _writeJournal.close();
    await _store.close();
  }
}
