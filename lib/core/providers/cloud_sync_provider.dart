import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/sync/cloud_sync_client.dart';
import '../services/sync/cloud_sync_conflict_resolver.dart';
import '../services/sync/cloud_sync_coordinator.dart';
import '../services/sync/cloud_sync_types.dart';
import '../services/workspace/account_workspace_runtime.dart';

typedef CloudSyncAccountClientFactory =
    CloudSyncAccountClient Function({String? token});

CloudSyncAccountClient _createCloudSyncAccountClient({String? token}) {
  return CloudSyncClient(token: token);
}

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

final class CloudSyncProvider extends ChangeNotifier {
  CloudSyncProvider.controlPlaneOnly(
    this._workspaceRuntime, {
    CloudSyncAccountClientFactory clientFactory = _createCloudSyncAccountClient,
  }) {
    _clientFactory = clientFactory;
  }

  final AccountWorkspaceRuntime _workspaceRuntime;
  late final CloudSyncAccountClientFactory _clientFactory;

  CloudSyncProviderStatus _status = CloudSyncProviderStatus.initializing;
  CloudSyncAccountSession? _session;
  CloudSyncException? _lastError;
  CloudSyncException? _deviceError;
  List<CloudSyncDeviceSession> _devices = const <CloudSyncDeviceSession>[];
  CloudSyncAccountClient? _client;
  Future<void>? _initialization;
  bool _ready = false;
  bool _devicesLoading = false;
  bool _disposed = false;
  bool _workspaceRestartRequired = false;
  Completer<void>? _sessionMutation;
  int _sessionEpoch = 0;

  CloudSyncProviderStatus get status => _status;
  CloudSyncAccountSession? get session => _session;
  CloudSyncRunSummary? get lastRun => null;
  CloudSyncException? get lastError => _lastError;
  CloudSyncException? get deviceError => _deviceError;
  bool get contentSyncEnabled => false;
  List<CloudSyncDeviceSession> get devices =>
      List<CloudSyncDeviceSession>.unmodifiable(_devices);
  bool get initialized => _ready;
  bool get signedIn => _session != null;
  bool get workspaceRestartRequired => _workspaceRestartRequired;
  CloudSyncInitialHydrationState get initialHydrationState =>
      CloudSyncInitialHydrationState.notRequired;
  bool get paused => false;
  bool get devicesLoading => _devicesLoading;
  List<CloudSyncConflict> get conflicts => const <CloudSyncConflict>[];
  CloudSyncException? get conflictError => null;
  CloudSyncConflictResolutionFailureReason? get conflictResolutionFailure =>
      null;
  bool get conflictsLoading => false;
  bool get conflictListTruncated => false;
  String? get resolvingConflictId => null;
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
    _lastError = null;
    _setStatus(CloudSyncProviderStatus.initializing);

    try {
      final session = _workspaceRuntime.current.session;
      if (session != null && session.baseUrl != defaultCloudSyncBaseUrl) {
        await _workspaceRuntime.signOut();
        _workspaceRestartRequired = true;
        _setStatus(CloudSyncProviderStatus.workspaceChangePending);
        _ready = true;
        return;
      }

      _session = session;
      if (session == null) {
        _ready = true;
        _setStatus(CloudSyncProviderStatus.signedOut);
        return;
      }

      _connect(session);
      if (_disposed) return;
      _ready = true;
      _setStatus(CloudSyncProviderStatus.idle);
    } catch (error, stackTrace) {
      _recordFailure(
        error,
        stackTrace,
        operation: '初始化云同步账户',
        status: CloudSyncProviderStatus.error,
      );
    }
  }

  Future<bool> login({
    required String loginName,
    required String password,
    required String deviceName,
  }) async {
    await initialize();
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
    _setStatus(CloudSyncProviderStatus.signingIn);
    CloudSyncAccountClient? loginClient;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (_disposed) return false;
      loginClient = _clientFactory();
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

      _workspaceRestartRequired = false;
      _session = session;
      _connect(session, client: loginClient);
      loginClient = null;
      if (_disposed) return false;
      _setStatus(CloudSyncProviderStatus.idle);
      return true;
    } catch (error, stackTrace) {
      _recordFailure(
        error,
        stackTrace,
        operation: '登录云同步账户',
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

    _sessionEpoch++;
    _client?.close(force: true);
    _client = null;
    try {
      await _workspaceRuntime.signOut();
    } catch (error, stackTrace) {
      _recordFailure(
        error,
        stackTrace,
        operation: '退出云同步账户',
        status: CloudSyncProviderStatus.error,
      );
      if (_disposed) return false;
      // 失败后保持重启门禁，避免旧 token 被重新接回当前进程。
      _workspaceRestartRequired = true;
      _setStatus(CloudSyncProviderStatus.workspaceChangePending);
      return false;
    } finally {
      _endSessionMutation();
    }

    _devices = const <CloudSyncDeviceSession>[];
    _lastError = null;
    _deviceError = null;
    _workspaceRestartRequired = true;
    _setStatus(CloudSyncProviderStatus.workspaceChangePending);
    return true;
  }

  Future<bool> setPaused(bool value) => Future<bool>.value(false);

  Future<void> prepareWorkspaceRestart() async {
    if (!_workspaceRestartRequired) {
      throw StateError('account_workspace_restart_not_required');
    }
    _sessionEpoch++;
    _client?.close(force: true);
    _client = null;
    await _workspaceRuntime.prepareRestartHandoff();
  }

  Future<bool> syncAfterLocalWrites() => Future<bool>.value(false);

  Future<bool> syncNow() => Future<bool>.value(false);

  Future<bool> refreshConflicts() => Future<bool>.value(false);

  Future<bool> resolveConflict(
    CloudSyncConflict conflict,
    Set<String> localPaths,
  ) => Future<bool>.value(false);

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
      _recordDeviceFailure(error, stackTrace, operation: '读取账户设备');
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
      _recordDeviceFailure(error, stackTrace, operation: '撤销账户设备');
      return false;
    }
  }

  void clearError() {
    if (_lastError == null && _deviceError == null) return;
    _lastError = null;
    _deviceError = null;
    if (_status == CloudSyncProviderStatus.error) {
      _status = _session == null
          ? CloudSyncProviderStatus.signedOut
          : CloudSyncProviderStatus.idle;
    }
    _notify();
  }

  void _connect(
    CloudSyncAccountSession session, {
    CloudSyncAccountClient? client,
  }) {
    _sessionEpoch++;
    _client?.close(force: true);
    final nextClient = client ?? _clientFactory(token: session.token);
    nextClient.setToken(session.token);
    _client = nextClient;
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
    _client?.close(force: true);
    _client = null;
    super.dispose();
  }
}
