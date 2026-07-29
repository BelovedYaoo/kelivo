import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/sync/cloud_sync_client.dart';
import '../services/sync/cloud_sync_content_runtime.dart';
import '../services/sync/cloud_sync_terminal_session_retirement.dart';
import '../services/sync/cloud_sync_types.dart';
import '../services/sync/e2ee_account_authenticator.dart';
import '../services/workspace/account_workspace_runtime.dart';
import '../services/workspace/device_state_blob_store.dart';

typedef CloudSyncAccountClientFactory =
    CloudSyncAccountClient Function({CloudSyncFullSessionToken? token});
typedef E2eeAccountAuthenticationFactory =
    E2eeAccountAuthentication Function(CloudSyncAccountClient accountClient);

CloudSyncAccountClient _createCloudSyncAccountClient({
  CloudSyncFullSessionToken? token,
}) {
  return CloudSyncClient(token: token);
}

enum CloudSyncProviderStatus {
  initializing,
  signedOut,
  signingIn,
  awaitingDeviceApproval,
  signingOut,
  workspaceChangePending,
  idle,
  error,
}

final class CloudSyncProvider extends ChangeNotifier {
  factory CloudSyncProvider.controlPlaneOnly(
    AccountWorkspaceRuntime workspaceRuntime, {
    CloudSyncAccountClientFactory clientFactory = _createCloudSyncAccountClient,
    E2eeAccountAuthenticationFactory? authenticationFactory,
  }) {
    return CloudSyncProvider._(
      workspaceRuntime,
      contentRuntime: null,
      clientFactory: clientFactory,
      authenticationFactory: authenticationFactory,
    );
  }

  factory CloudSyncProvider.withContentRuntime(
    AccountWorkspaceRuntime workspaceRuntime, {
    required CloudSyncContentRuntime contentRuntime,
    CloudSyncAccountClientFactory clientFactory = _createCloudSyncAccountClient,
    E2eeAccountAuthenticationFactory? authenticationFactory,
  }) {
    return CloudSyncProvider._(
      workspaceRuntime,
      contentRuntime: contentRuntime,
      clientFactory: clientFactory,
      authenticationFactory: authenticationFactory,
    );
  }

  CloudSyncProvider._(
    this._workspaceRuntime, {
    required this._contentRuntime,
    required CloudSyncAccountClientFactory clientFactory,
    required E2eeAccountAuthenticationFactory? authenticationFactory,
  }) {
    _configureFactories(clientFactory, authenticationFactory);
  }

  void _configureFactories(
    CloudSyncAccountClientFactory clientFactory,
    E2eeAccountAuthenticationFactory? authenticationFactory,
  ) {
    _clientFactory = clientFactory;
    _authenticationFactory =
        authenticationFactory ??
        (accountClient) => E2eeAccountAuthenticator(
          baseUrl: defaultCloudSyncBaseUrl,
          accountClient: accountClient,
          deviceStateStore: DeviceStateBlobStore(
            installationRoot: _workspaceRuntime.installationRoot,
          ),
          secureCore: const KelivoSecureCore(),
        );
  }

  final AccountWorkspaceRuntime _workspaceRuntime;
  final CloudSyncContentRuntime? _contentRuntime;
  late final CloudSyncAccountClientFactory _clientFactory;
  late final E2eeAccountAuthenticationFactory _authenticationFactory;

  CloudSyncProviderStatus _status = CloudSyncProviderStatus.initializing;
  CloudSyncAccountSession? _session;
  CloudSyncException? _lastError;
  CloudSyncException? _deviceError;
  E2eeAccountLoginApprovalRequired? _pendingDeviceApproval;
  E2eeDevicePairingSession? _pendingPairingSession;
  CloudSyncAccountClient? _pendingPairingClient;
  Uint8List? _pendingPairingQrFrame;
  Future<void>? _pendingPairingTask;
  List<CloudSyncDeviceSession> _devices = const <CloudSyncDeviceSession>[];
  CloudSyncAccountClient? _client;
  Future<void>? _initialization;
  Future<void>? _contentRuntimeClose;
  bool _ready = false;
  bool _contentRuntimeReady = false;
  bool _contentRuntimeClosed = false;
  bool _devicesLoading = false;
  bool _disposed = false;
  bool _workspaceRestartRequired = false;
  bool _pendingPairingCancellationRequested = false;
  bool _devicePairingApprovalInProgress = false;
  Completer<void>? _sessionMutation;
  int _sessionEpoch = 0;
  int _pendingPairingGeneration = 0;

  CloudSyncProviderStatus get status => _status;
  CloudSyncAccountSession? get session => _session;
  CloudSyncException? get lastError => _lastError;
  CloudSyncException? get deviceError => _deviceError;
  E2eeAccountLoginApprovalRequired? get pendingDeviceApproval =>
      _pendingDeviceApproval;
  DateTime? get pendingDevicePairingExpiresAt =>
      _pendingPairingSession?.expiresAt;
  int get pendingDevicePairingGeneration => _pendingPairingGeneration;
  bool get devicePairingApprovalInProgress => _devicePairingApprovalInProgress;
  bool get contentSyncEnabled =>
      _contentRuntime != null && _contentRuntimeReady && !_contentRuntimeClosed;
  List<CloudSyncDeviceSession> get devices =>
      List<CloudSyncDeviceSession>.unmodifiable(_devices);
  bool get initialized => _ready;
  bool get signedIn => _session != null;
  bool get workspaceRestartRequired => _workspaceRestartRequired;
  bool get devicesLoading => _devicesLoading;
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
      if (session != null &&
          (session.baseUrl != defaultCloudSyncBaseUrl ||
              session.isExpiredAt(DateTime.now().toUtc()))) {
        await _workspaceRuntime.signOut();
        _workspaceRestartRequired = true;
        _setStatus(CloudSyncProviderStatus.workspaceChangePending);
        _ready = true;
        return;
      }

      _session = session;
      if (session == null) {
        if (_contentRuntime != null) {
          throw StateError('content_runtime_requires_account_session');
        }
        _ready = true;
        _setStatus(CloudSyncProviderStatus.signedOut);
        return;
      }

      final contentRuntime = _contentRuntime;
      int? contentRuntimeEpoch;
      if (contentRuntime != null) {
        // runtime 会在 initialize 返回前启动调度器，先固定世代并绑定处理器，
        // 才不会漏掉首次拉取立刻返回的远端撤销。
        contentRuntimeEpoch = ++_sessionEpoch;
        final boundEpoch = contentRuntimeEpoch;
        contentRuntime.bindTerminalAuthenticationHandler((failure, stackTrace) {
          return _retireTerminalAuthentication(
            sessionEpoch: boundEpoch,
            failure: failure,
            failureStackTrace: stackTrace,
          );
        });
        await contentRuntime.initialize();
        if (_disposed) {
          await _closeContentRuntime();
          return;
        }
        if (contentRuntimeEpoch != _sessionEpoch || _session == null) {
          return;
        }
        _contentRuntimeReady = true;
      }
      _connect(session, reservedSessionEpoch: contentRuntimeEpoch);
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
    if (_session != null ||
        _sessionMutationInProgress ||
        _pendingPairingSession != null) {
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
    _pendingDeviceApproval = null;
    _devicesLoading = false;
    _setStatus(CloudSyncProviderStatus.signingIn);
    CloudSyncAccountClient? loginClient;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (_disposed) return false;
      loginClient = _clientFactory();
      final authentication = _authenticationFactory(loginClient);
      final loginResult = await authentication.loginDevice(
        loginName: loginName.trim(),
        password: Uint8List.fromList(utf8.encode(password)),
        deviceName: deviceName.trim(),
        platform: _currentPlatform(),
        clientVersion: packageInfo.version,
      );
      if (_disposed) return false;
      switch (loginResult) {
        case E2eeAccountLoginApprovalRequired():
          final pairing = await authentication.startDevicePairing(loginResult);
          Uint8List? qrFrame;
          try {
            qrFrame = pairing.takeQrFrame(now: DateTime.now().toUtc());
            if (_disposed) {
              _clearMutableBytes(qrFrame);
              await pairing.cancel();
              return false;
            }
            _retainPendingApproval(
              authentication: authentication,
              client: loginClient,
              approval: loginResult,
              pairing: pairing,
              qrFrame: qrFrame,
            );
          } catch (error, stackTrace) {
            _clearMutableBytes(qrFrame);
            try {
              await pairing.cancel();
            } catch (cleanupError, cleanupStackTrace) {
              developer.log(
                '创建设备配对二维码失败后的清理未完成',
                name: 'Kelivo.CloudSyncProvider',
                level: 900,
                error: cleanupError,
                stackTrace: cleanupStackTrace,
              );
            }
            Error.throwWithStackTrace(error, stackTrace);
          }
          loginClient = null;
          return false;
        case E2eeAccountLoginAuthenticated(:final session):
          final connected = await _bindAuthenticatedSession(
            session,
            loginClient,
          );
          await _confirmDevicePairingAfterWorkspaceCommit(
            authentication,
            loginName: loginName.trim(),
            session: session,
          );
          if (connected) loginClient = null;
          return true;
      }
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

  Future<bool> register({
    required String loginName,
    required String displayName,
    required String password,
    required String deviceName,
  }) async {
    await initialize();
    if (!_ready || _disposed) return false;
    if (_session != null ||
        _sessionMutationInProgress ||
        _pendingPairingSession != null) {
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
    _pendingDeviceApproval = null;
    _devicesLoading = false;
    _setStatus(CloudSyncProviderStatus.signingIn);
    CloudSyncAccountClient? registrationClient;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (_disposed) return false;
      registrationClient = _clientFactory();
      final authentication = _authenticationFactory(registrationClient);
      final authenticatedSession = await authentication.registerFirstDevice(
        loginName: loginName.trim(),
        displayName: displayName.trim(),
        password: Uint8List.fromList(utf8.encode(password)),
        deviceName: deviceName.trim(),
        platform: _currentPlatform(),
        clientVersion: packageInfo.version,
      );
      if (_disposed) return false;
      final connected = await _bindAuthenticatedSession(
        authenticatedSession,
        registrationClient,
      );
      try {
        await authentication.confirmFirstDeviceRegistration(
          loginName: loginName.trim(),
          session: authenticatedSession,
        );
      } catch (error, stackTrace) {
        // 工作区会话已经提交，事务清理失败只能延后重试，不能把成功注册伪装成失败。
        developer.log(
          '首设备注册已提交，恢复事务将在后续认证重试清理',
          name: 'Kelivo.CloudSyncProvider',
          level: 900,
          error: error,
          stackTrace: stackTrace,
        );
      }
      if (connected) registrationClient = null;
      return true;
    } catch (error, stackTrace) {
      _recordFailure(
        error,
        stackTrace,
        operation: '注册云同步账户',
        status: _session == null
            ? CloudSyncProviderStatus.signedOut
            : CloudSyncProviderStatus.error,
      );
      return false;
    } finally {
      registrationClient?.close(force: true);
      _endSessionMutation();
    }
  }

  Future<bool> logout() async {
    await initialize();
    if (_disposed || _sessionMutationInProgress) return false;
    if (_pendingPairingSession != null) {
      return cancelPendingDevicePairing();
    }
    _beginSessionMutation();
    _session = null;
    _contentRuntimeReady = false;
    _pendingDeviceApproval = null;
    _devicesLoading = false;
    _setStatus(CloudSyncProviderStatus.signingOut);

    _sessionEpoch++;
    _client?.close(force: true);
    _client = null;
    Object? primaryError;
    StackTrace? primaryStackTrace;
    try {
      await _closeContentRuntime();
    } catch (error, stackTrace) {
      primaryError = error;
      primaryStackTrace = stackTrace;
    }
    try {
      await _workspaceRuntime.signOut();
    } catch (error, stackTrace) {
      if (primaryError == null) {
        primaryError = error;
        primaryStackTrace = stackTrace;
      } else {
        developer.log(
          '关闭内容运行时失败后清理账户会话仍然失败',
          name: 'Kelivo.CloudSyncProvider',
          level: 1000,
          error: error,
          stackTrace: stackTrace,
        );
      }
    } finally {
      _endSessionMutation();
    }
    if (primaryError != null) {
      _recordFailure(
        primaryError,
        primaryStackTrace!,
        operation: '退出云同步账户',
        status: CloudSyncProviderStatus.error,
      );
      if (_disposed) return false;
      // 失败后保持重启门禁，避免旧 token 被重新接回当前进程。
      _workspaceRestartRequired = true;
      _setStatus(CloudSyncProviderStatus.workspaceChangePending);
      return false;
    }

    _devices = const <CloudSyncDeviceSession>[];
    _lastError = null;
    _deviceError = null;
    _workspaceRestartRequired = true;
    _setStatus(CloudSyncProviderStatus.workspaceChangePending);
    return true;
  }

  Future<void> prepareWorkspaceRestart() async {
    if (!_workspaceRestartRequired) {
      throw StateError('account_workspace_restart_not_required');
    }
    _sessionEpoch++;
    _client?.close(force: true);
    _client = null;
    Object? primaryError;
    StackTrace? primaryStackTrace;
    try {
      await _closeContentRuntime();
    } catch (error, stackTrace) {
      primaryError = error;
      primaryStackTrace = stackTrace;
    }
    try {
      await _workspaceRuntime.prepareRestartHandoff();
    } catch (error, stackTrace) {
      if (primaryError == null) {
        primaryError = error;
        primaryStackTrace = stackTrace;
      } else {
        developer.log(
          '关闭内容运行时失败后释放工作区租约仍然失败',
          name: 'Kelivo.CloudSyncProvider',
          level: 1000,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    if (primaryError != null) {
      Error.throwWithStackTrace(primaryError, primaryStackTrace!);
    }
  }

  Future<void> _closeContentRuntime() {
    _contentRuntimeReady = false;
    final runtime = _contentRuntime;
    if (runtime == null || _contentRuntimeClosed) {
      return Future<void>.value();
    }
    final active = _contentRuntimeClose;
    if (active != null) return active;

    late final Future<void> closing;
    closing = runtime
        .close()
        .then((_) {
          _contentRuntimeClosed = true;
        })
        .whenComplete(() {
          if (identical(_contentRuntimeClose, closing)) {
            _contentRuntimeClose = null;
          }
        });
    _contentRuntimeClose = closing;
    return closing;
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

  Uint8List? takePendingDevicePairingQrFrame() {
    final frame = _pendingPairingQrFrame;
    _pendingPairingQrFrame = null;
    return frame;
  }

  Future<bool> cancelPendingDevicePairing() async {
    final pairing = _pendingPairingSession;
    final task = _pendingPairingTask;
    if (pairing == null || task == null) return false;
    _pendingPairingCancellationRequested = true;
    _notify();
    Object? cancellationError;
    StackTrace? cancellationStackTrace;
    try {
      await pairing.cancel();
    } catch (error, stackTrace) {
      cancellationError = error;
      cancellationStackTrace = stackTrace;
    }
    await task;
    if (cancellationError != null) {
      if (_session != null || _workspaceRestartRequired) {
        developer.log(
          '设备配对已先于取消完成提交',
          name: 'Kelivo.CloudSyncProvider',
          level: 800,
          error: cancellationError,
          stackTrace: cancellationStackTrace,
        );
        return false;
      }
      _recordFailure(
        cancellationError,
        cancellationStackTrace!,
        operation: '取消设备配对',
        status: CloudSyncProviderStatus.signedOut,
      );
      return false;
    }
    return true;
  }

  Future<bool> approveDevicePairing(Uint8List qrFrame) async {
    try {
      await initialize();
      final session = _session;
      final client = _client;
      final platform = _currentPlatform();
      if (_disposed ||
          session == null ||
          client == null ||
          _devicePairingApprovalInProgress ||
          (platform != CloudSyncPlatform.android &&
              platform != CloudSyncPlatform.ios)) {
        _deviceError = const CloudSyncException(
          kind: CloudSyncFailureKind.validation,
          retryable: false,
          serverCode: 'SYNC_DEVICE_PAIRING_APPROVAL_UNAVAILABLE',
        );
        _notify();
        return false;
      }

      _devicePairingApprovalInProgress = true;
      _deviceError = null;
      _notify();
      try {
        final authentication = _authenticationFactory(client);
        await authentication.approveScannedDevicePairing(
          loginName: session.loginName,
          session: session.toAuthenticatedSession(),
          qrFrame: qrFrame,
        );
        return true;
      } catch (error, stackTrace) {
        _recordDeviceFailure(error, stackTrace, operation: '批准设备配对');
        return false;
      } finally {
        _devicePairingApprovalInProgress = false;
        _notify();
      }
    } catch (error, stackTrace) {
      _recordDeviceFailure(error, stackTrace, operation: '批准设备配对');
      return false;
    } finally {
      _clearMutableBytes(qrFrame);
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
    int? reservedSessionEpoch,
  }) {
    if (reservedSessionEpoch == null) {
      _sessionEpoch++;
    } else if (reservedSessionEpoch != _sessionEpoch) {
      throw StateError('云同步内容运行时会话世代已经失效');
    }
    _client?.close(force: true);
    final nextClient = client ?? _clientFactory(token: session.token);
    nextClient.setToken(session.token);
    _client = nextClient;
  }

  Future<void> _retireTerminalAuthentication({
    required int sessionEpoch,
    required CloudSyncException failure,
    required StackTrace failureStackTrace,
  }) async {
    if (_disposed || sessionEpoch != _sessionEpoch || _session == null) {
      return;
    }

    _beginSessionMutation();
    _sessionEpoch++;
    _session = null;
    _contentRuntimeReady = false;
    _pendingDeviceApproval = null;
    _devicesLoading = false;
    _devices = const <CloudSyncDeviceSession>[];
    _workspaceRestartRequired = true;
    _ready = true;
    _lastError = failure;
    _deviceError = null;
    _setStatus(CloudSyncProviderStatus.signingOut);
    _client?.close(force: true);
    _client = null;

    // 持久 tombstone 必须先于可能等待本地写入的 runtime 关闭，避免崩溃后
    // 旧会话再次被启动流程接回。
    try {
      await retireTerminalCloudSyncSession(
        persistSessionTombstone: () async {
          await _workspaceRuntime.signOut();
        },
        closeContentRuntime: _closeContentRuntime,
        releaseAccountLease: () async {},
        releaseWorkspaceLease: _workspaceRuntime.prepareRestartHandoff,
      );
    } catch (error, stackTrace) {
      _recordFailure(
        error,
        stackTrace,
        operation: '终止认证后清理云同步会话',
        status: CloudSyncProviderStatus.workspaceChangePending,
      );
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      _endSessionMutation();
    }

    debugPrint('云同步会话因终止认证失效：$failure\n$failureStackTrace');
    _setStatus(CloudSyncProviderStatus.workspaceChangePending);
  }

  void _retainPendingApproval({
    required E2eeAccountAuthentication authentication,
    required CloudSyncAccountClient client,
    required E2eeAccountLoginApprovalRequired approval,
    required E2eeDevicePairingSession pairing,
    required Uint8List qrFrame,
  }) {
    client.setToken(null);
    _pendingDeviceApproval = approval;
    _pendingPairingSession = pairing;
    _pendingPairingClient = client;
    _pendingPairingQrFrame = qrFrame;
    _pendingPairingGeneration++;
    _pendingPairingCancellationRequested = false;
    _lastError = null;
    final task = _completePendingDevicePairing(
      authentication: authentication,
      client: client,
      approval: approval,
      pairing: pairing,
    );
    _pendingPairingTask = task;
    _setStatus(CloudSyncProviderStatus.awaitingDeviceApproval);
    unawaited(task);
  }

  Future<void> _completePendingDevicePairing({
    required E2eeAccountAuthentication authentication,
    required CloudSyncAccountClient client,
    required E2eeAccountLoginApprovalRequired approval,
    required E2eeDevicePairingSession pairing,
  }) async {
    var clientTransferred = false;
    try {
      final authenticatedSession = await pairing.wait();
      if (!_ownsPendingDevicePairing(pairing, client) || _disposed) return;
      clientTransferred = await _bindAuthenticatedSession(
        authenticatedSession,
        client,
      );
      await _confirmDevicePairingAfterWorkspaceCommit(
        authentication,
        loginName: approval.loginName,
        session: authenticatedSession,
      );
    } catch (error, stackTrace) {
      if (!_ownsPendingDevicePairing(pairing, client)) return;
      if (!_pendingPairingCancellationRequested && !_disposed) {
        _recordFailure(
          error,
          stackTrace,
          operation: '等待设备配对批准',
          status: CloudSyncProviderStatus.signedOut,
        );
      }
    } finally {
      if (_ownsPendingDevicePairing(pairing, client)) {
        final cancelled = _pendingPairingCancellationRequested;
        _releasePendingDevicePairing(
          client: client,
          closeClient: !clientTransferred,
        );
        if (cancelled && !_disposed) {
          _setStatus(CloudSyncProviderStatus.signedOut);
        }
      }
    }
  }

  Future<void> _confirmDevicePairingAfterWorkspaceCommit(
    E2eeAccountAuthentication authentication, {
    required String loginName,
    required CloudSyncAuthenticatedSession session,
  }) async {
    try {
      await authentication.confirmDevicePairing(
        loginName: loginName,
        session: session,
      );
    } catch (error, stackTrace) {
      // 工作区会话已提交；确认清理可由下次登录重复完成，不能撤销成功登录。
      developer.log(
        '设备配对已提交，恢复事务将在后续登录重试清理',
        name: 'Kelivo.CloudSyncProvider',
        level: 900,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  bool _ownsPendingDevicePairing(
    E2eeDevicePairingSession pairing,
    CloudSyncAccountClient client,
  ) {
    return identical(_pendingPairingSession, pairing) &&
        identical(_pendingPairingClient, client);
  }

  void _releasePendingDevicePairing({
    required CloudSyncAccountClient client,
    required bool closeClient,
  }) {
    _clearMutableBytes(_pendingPairingQrFrame);
    _pendingPairingQrFrame = null;
    _pendingDeviceApproval = null;
    _pendingPairingSession = null;
    _pendingPairingClient = null;
    _pendingPairingTask = null;
    _pendingPairingCancellationRequested = false;
    if (closeClient) {
      client.close(force: true);
    }
  }

  Future<bool> _bindAuthenticatedSession(
    CloudSyncAuthenticatedSession authenticatedSession,
    CloudSyncAccountClient client,
  ) async {
    final session = CloudSyncAccountSession.fromAuthenticatedSession(
      baseUrl: defaultCloudSyncBaseUrl,
      session: authenticatedSession,
    );
    final workspaceBinding = await _workspaceRuntime.bindAccount(session);
    if (workspaceBinding is AccountWorkspaceRestartRequired) {
      _workspaceRestartRequired = true;
      _setStatus(CloudSyncProviderStatus.workspaceChangePending);
      return false;
    }

    _workspaceRestartRequired = false;
    _session = session;
    _connect(session, client: client);
    if (!_disposed) _setStatus(CloudSyncProviderStatus.idle);
    return true;
  }

  static void _clearMutableBytes(Uint8List? value) {
    if (value == null) return;
    value.fillRange(0, value.length, 0);
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
    _contentRuntimeReady = false;
    _sessionEpoch++;
    final pendingPairing = _pendingPairingSession;
    if (pendingPairing != null) {
      _pendingPairingCancellationRequested = true;
      unawaited(
        pendingPairing.cancel().catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          developer.log(
            '关闭云同步页面时取消设备配对失败',
            name: 'Kelivo.CloudSyncProvider',
            level: 900,
            error: error,
            stackTrace: stackTrace,
          );
        }),
      );
    }
    _clearMutableBytes(_pendingPairingQrFrame);
    _pendingPairingQrFrame = null;
    _client?.close(force: true);
    _client = null;
    unawaited(
      _closeContentRuntime().catchError((Object error, StackTrace stackTrace) {
        developer.log(
          '关闭 E2EE 内容同步运行时失败',
          name: 'Kelivo.CloudSyncProvider',
          level: 1000,
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );
    super.dispose();
  }
}
