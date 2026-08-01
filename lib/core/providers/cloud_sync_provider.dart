import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../services/sync/cloud_sync_client.dart';
import '../services/sync/cloud_sync_content_runtime.dart';
import '../services/sync/cloud_sync_terminal_session_retirement.dart';
import '../services/sync/cloud_sync_types.dart';
import '../services/sync/e2ee_account_authenticator.dart';
import '../services/sync/e2ee_device_pairing_membership_commit.dart';
import '../services/sync/e2ee_first_device_recovery_bootstrap.dart';
import '../services/sync/e2ee_first_device_registration_commit_coordinator.dart';
import '../services/sync/e2ee_mobile_background_sync.dart';
import '../services/sync/sensitive_utf8.dart';
import '../services/workspace/account_workspace_runtime.dart';
import '../services/workspace/device_state_blob_store.dart';
import '../services/workspace/installation_operation_lease.dart';
import '../services/workspace/local_cryptographic_wipe.dart';

typedef CloudSyncAccountClientFactory =
    CloudSyncAccountClient Function({CloudSyncFullSessionToken? token});
typedef E2eeAccountAuthenticationFactory =
    E2eeAccountAuthentication Function(
      CloudSyncAccountClient accountClient, {
      E2eeFirstDeviceSecurityBootstrapPreparer? firstDeviceBootstrapPreparer,
    });
typedef E2eeFirstDeviceRecoveryBootstrapFactory =
    E2eeFirstDeviceSecurityBootstrapPreparer Function({
      required Uint8List recoveryPassphrase,
      required E2eeEncryptedRecoveryMediaExporter encryptedMediaExporter,
    });
typedef CloudSyncCurrentDeviceRevocationCommitter =
    Future<CloudSyncDeviceRotationResult> Function({
      required CloudSyncAccountClient client,
      required CloudSyncAccountSession session,
      required String mutationId,
    });
typedef CloudSyncRevocationMutationIdFactory = String Function();

CloudSyncAccountClient _createCloudSyncAccountClient({
  CloudSyncFullSessionToken? token,
}) {
  return CloudSyncClient(token: token);
}

E2eeFirstDeviceSecurityBootstrapPreparer _createFirstDeviceRecoveryBootstrap({
  required Uint8List recoveryPassphrase,
  required E2eeEncryptedRecoveryMediaExporter encryptedMediaExporter,
}) {
  return E2eeFirstDeviceRecoveryBootstrapPreparer(
    recoveryPassphrase: recoveryPassphrase,
    serviceOrigin: e2eeCanonicalRecoveryServiceOrigin,
    encryptedMediaExporter: encryptedMediaExporter,
  );
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

final class CloudSyncProvider extends ChangeNotifier
    implements E2eeMobileBackgroundSyncAccountState {
  factory CloudSyncProvider.controlPlaneOnly(
    AccountWorkspaceRuntime workspaceRuntime, {
    CloudSyncAccountClientFactory clientFactory = _createCloudSyncAccountClient,
    E2eeAccountAuthenticationFactory? authenticationFactory,
    E2eeFirstDeviceRecoveryBootstrapFactory
        firstDeviceRecoveryBootstrapFactory =
        _createFirstDeviceRecoveryBootstrap,
    LocalCryptographicWipe? localCryptographicWipe,
    InstallationOperationLease? installationOperationLease,
    InstallationBusinessLease? installationBusinessLease,
    CloudSyncCurrentDeviceRevocationCommitter? currentDeviceRevocationCommitter,
    CloudSyncRevocationMutationIdFactory? revocationMutationIdFactory,
    LocalCryptographicWipeStep? stopBackgroundSync,
    LocalCryptographicWipeStep? restartForLocalDeviceWipe,
  }) {
    return CloudSyncProvider._(
      workspaceRuntime,
      contentRuntime: null,
      clientFactory: clientFactory,
      authenticationFactory: authenticationFactory,
      firstDeviceRecoveryBootstrapFactory: firstDeviceRecoveryBootstrapFactory,
      devicePairingMembershipCommitPreparer: null,
      localCryptographicWipe: localCryptographicWipe,
      installationOperationLease: installationOperationLease,
      installationBusinessLease: installationBusinessLease,
      currentDeviceRevocationCommitter: currentDeviceRevocationCommitter,
      revocationMutationIdFactory: revocationMutationIdFactory,
      stopBackgroundSync: stopBackgroundSync,
      restartForLocalDeviceWipe: restartForLocalDeviceWipe,
    );
  }

  factory CloudSyncProvider.withContentRuntime(
    AccountWorkspaceRuntime workspaceRuntime, {
    required CloudSyncContentRuntime contentRuntime,
    CloudSyncAccountClientFactory clientFactory = _createCloudSyncAccountClient,
    E2eeAccountAuthenticationFactory? authenticationFactory,
    E2eeFirstDeviceRecoveryBootstrapFactory
        firstDeviceRecoveryBootstrapFactory =
        _createFirstDeviceRecoveryBootstrap,
    E2eeDevicePairingMembershipCommitPreparer?
    devicePairingMembershipCommitPreparer,
    LocalCryptographicWipe? localCryptographicWipe,
    InstallationOperationLease? installationOperationLease,
    InstallationBusinessLease? installationBusinessLease,
    CloudSyncCurrentDeviceRevocationCommitter? currentDeviceRevocationCommitter,
    CloudSyncRevocationMutationIdFactory? revocationMutationIdFactory,
    LocalCryptographicWipeStep? stopBackgroundSync,
    LocalCryptographicWipeStep? restartForLocalDeviceWipe,
  }) {
    return CloudSyncProvider._(
      workspaceRuntime,
      contentRuntime: contentRuntime,
      clientFactory: clientFactory,
      authenticationFactory: authenticationFactory,
      firstDeviceRecoveryBootstrapFactory: firstDeviceRecoveryBootstrapFactory,
      devicePairingMembershipCommitPreparer:
          devicePairingMembershipCommitPreparer,
      localCryptographicWipe: localCryptographicWipe,
      installationOperationLease: installationOperationLease,
      installationBusinessLease: installationBusinessLease,
      currentDeviceRevocationCommitter: currentDeviceRevocationCommitter,
      revocationMutationIdFactory: revocationMutationIdFactory,
      stopBackgroundSync: stopBackgroundSync,
      restartForLocalDeviceWipe: restartForLocalDeviceWipe,
    );
  }

  CloudSyncProvider._(
    this._workspaceRuntime, {
    required this._contentRuntime,
    required CloudSyncAccountClientFactory clientFactory,
    required E2eeAccountAuthenticationFactory? authenticationFactory,
    required E2eeFirstDeviceRecoveryBootstrapFactory
    firstDeviceRecoveryBootstrapFactory,
    required E2eeDevicePairingMembershipCommitPreparer?
    devicePairingMembershipCommitPreparer,
    required LocalCryptographicWipe? localCryptographicWipe,
    required InstallationOperationLease? installationOperationLease,
    required InstallationBusinessLease? installationBusinessLease,
    required CloudSyncCurrentDeviceRevocationCommitter?
    currentDeviceRevocationCommitter,
    required CloudSyncRevocationMutationIdFactory? revocationMutationIdFactory,
    required LocalCryptographicWipeStep? stopBackgroundSync,
    required LocalCryptographicWipeStep? restartForLocalDeviceWipe,
  }) {
    _localCryptographicWipe = localCryptographicWipe;
    _installationOperationLease = installationOperationLease;
    _installationBusinessLease = installationBusinessLease;
    _currentDeviceRevocationCommitter = currentDeviceRevocationCommitter;
    _revocationMutationIdFactory =
        revocationMutationIdFactory ?? const Uuid().v4;
    _stopBackgroundSync = stopBackgroundSync;
    _restartForLocalDeviceWipe = restartForLocalDeviceWipe;
    _configureFactories(
      clientFactory,
      authenticationFactory,
      firstDeviceRecoveryBootstrapFactory,
      devicePairingMembershipCommitPreparer,
    );
  }

  void _configureFactories(
    CloudSyncAccountClientFactory clientFactory,
    E2eeAccountAuthenticationFactory? authenticationFactory,
    E2eeFirstDeviceRecoveryBootstrapFactory firstDeviceRecoveryBootstrapFactory,
    E2eeDevicePairingMembershipCommitPreparer?
    devicePairingMembershipCommitPreparer,
  ) {
    _clientFactory = clientFactory;
    _firstDeviceRecoveryBootstrapFactory = firstDeviceRecoveryBootstrapFactory;
    _authenticationFactory =
        authenticationFactory ??
        (accountClient, {firstDeviceBootstrapPreparer}) =>
            E2eeAccountAuthenticator(
              baseUrl: defaultCloudSyncBaseUrl,
              accountClient: accountClient,
              deviceStateStore: DeviceStateBlobStore(
                installationRoot: _workspaceRuntime.installationRoot,
              ),
              secureCore: const KelivoSecureCore(),
              firstDeviceBootstrapPreparer: firstDeviceBootstrapPreparer,
              devicePairingMembershipCommitPreparer:
                  devicePairingMembershipCommitPreparer,
            );
  }

  final AccountWorkspaceRuntime _workspaceRuntime;
  final CloudSyncContentRuntime? _contentRuntime;
  late final LocalCryptographicWipe? _localCryptographicWipe;
  late final InstallationOperationLease? _installationOperationLease;
  late final InstallationBusinessLease? _installationBusinessLease;
  late final CloudSyncCurrentDeviceRevocationCommitter?
  _currentDeviceRevocationCommitter;
  late final CloudSyncRevocationMutationIdFactory _revocationMutationIdFactory;
  late final LocalCryptographicWipeStep? _stopBackgroundSync;
  late final LocalCryptographicWipeStep? _restartForLocalDeviceWipe;
  late final CloudSyncAccountClientFactory _clientFactory;
  late final E2eeAccountAuthenticationFactory _authenticationFactory;
  late final E2eeFirstDeviceRecoveryBootstrapFactory
  _firstDeviceRecoveryBootstrapFactory;

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
  bool _localDeviceWipePending = false;
  bool _workspaceClosedForLocalWipe = false;
  _CurrentDeviceRevocationAttempt? _currentDeviceRevocationAttempt;
  Future<bool>? _localDeviceRevocationContinuation;
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
  @override
  bool get contentSyncEnabled =>
      _contentRuntime != null && _contentRuntimeReady && !_contentRuntimeClosed;
  List<CloudSyncDeviceSession> get devices =>
      List<CloudSyncDeviceSession>.unmodifiable(_devices);
  bool get initialized => _ready;
  @override
  bool get signedIn => _session != null;
  bool get workspaceRestartRequired => _workspaceRestartRequired;
  bool get localDeviceWipePending => _localDeviceWipePending;
  bool get localDeviceWipeSupported =>
      (_localCryptographicWipe?.isSupported ?? false) &&
      _installationOperationLease != null &&
      (_installationBusinessLease?.isClosed == false) &&
      _currentDeviceRevocationCommitter != null &&
      _stopBackgroundSync != null &&
      _restartForLocalDeviceWipe != null;
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
        contentRuntime.bindSecurityBootstrapCommitHandler(
          _commitSecurityBootstrap,
        );
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
      } else if (session.securityBootstrap != null) {
        throw StateError('待安装安全 bootstrap 不能在控制面模式激活');
      }
      final activeSession = _session;
      if (activeSession == null) {
        throw StateError('内容运行时初始化后账户会话丢失');
      }
      _connect(activeSession, reservedSessionEpoch: contentRuntimeEpoch);
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
    if (!_ready || _disposed || _localDeviceWipePending) return false;
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
    Uint8List? passwordBytes;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (_disposed) return false;
      loginClient = _clientFactory();
      final authentication = _authenticationFactory(loginClient);
      passwordBytes = encodeSensitiveUtf8(password);
      final loginResult = await authentication.loginDevice(
        loginName: loginName.trim(),
        password: passwordBytes,
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
              client: loginClient,
              approval: loginResult,
              pairing: pairing,
              qrFrame: qrFrame,
            );
          } catch (error, stackTrace) {
            _clearMutableBytes(qrFrame);
            try {
              await pairing.cancel();
            } catch (_) {
              developer.log(
                '创建设备配对二维码失败后的清理未完成',
                name: 'Kelivo.CloudSyncProvider',
                level: 900,
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
      clearSensitiveBytes(passwordBytes);
      loginClient?.close(force: true);
      _endSessionMutation();
    }
  }

  Future<bool> register({
    required String loginName,
    required String displayName,
    required String password,
    required String recoveryPassphrase,
    required String deviceName,
    required E2eeEncryptedRecoveryMediaExporter encryptedMediaExporter,
  }) async {
    await initialize();
    if (!_ready || _disposed || _localDeviceWipePending) return false;
    if (sensitiveUtf8Equals(password, recoveryPassphrase)) {
      _lastError = const CloudSyncException(
        kind: CloudSyncFailureKind.validation,
        retryable: false,
        serverCode: e2eeRecoveryPassphraseMatchesPasswordCode,
      );
      _notify();
      return false;
    }
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
    Uint8List? passwordBytes;
    Uint8List? recoveryPassphraseBytes;
    E2eeFirstDeviceSecurityBootstrapPreparer? bootstrapPreparer;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (_disposed) return false;
      recoveryPassphraseBytes = encodeSensitiveUtf8(recoveryPassphrase);
      bootstrapPreparer = _firstDeviceRecoveryBootstrapFactory(
        recoveryPassphrase: recoveryPassphraseBytes,
        encryptedMediaExporter: encryptedMediaExporter,
      );
      registrationClient = _clientFactory();
      final authentication = _authenticationFactory(
        registrationClient,
        firstDeviceBootstrapPreparer: bootstrapPreparer,
      );
      passwordBytes = encodeSensitiveUtf8(password);
      final authenticatedSession = await authentication.registerFirstDevice(
        loginName: loginName.trim(),
        displayName: displayName.trim(),
        password: passwordBytes,
        deviceName: deviceName.trim(),
        platform: _currentPlatform(),
        clientVersion: packageInfo.version,
      );
      if (_disposed) return false;
      final connected = await _bindAuthenticatedSession(
        authenticatedSession,
        registrationClient,
      );
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
      bootstrapPreparer?.close();
      clearSensitiveBytes(passwordBytes);
      clearSensitiveBytes(recoveryPassphraseBytes);
      registrationClient?.close(force: true);
      _endSessionMutation();
    }
  }

  Future<bool> resumeFirstDeviceRegistration({
    required String loginName,
    required E2eeEncryptedRecoveryMediaExporter encryptedMediaExporter,
  }) async {
    await initialize();
    if (!_ready || _disposed || _localDeviceWipePending) return false;
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
    _setStatus(CloudSyncProviderStatus.signingIn);
    CloudSyncAccountClient? registrationClient;
    try {
      registrationClient = _clientFactory();
      final authentication = _authenticationFactory(registrationClient);
      final authenticatedSession = await authentication
          .resumeFirstDeviceRegistration(
            loginName: loginName.trim(),
            encryptedMediaExporter: encryptedMediaExporter,
          );
      if (_disposed) return false;
      final connected = await _bindAuthenticatedSession(
        authenticatedSession,
        registrationClient,
      );
      if (connected) registrationClient = null;
      return true;
    } catch (error, stackTrace) {
      _recordFailure(
        error,
        stackTrace,
        operation: '恢复首设备注册',
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

  Future<bool> discardPendingFirstDeviceRegistration({
    required String loginName,
  }) async {
    await initialize();
    if (!_ready || _disposed || _localDeviceWipePending) return false;
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
    _setStatus(CloudSyncProviderStatus.signingIn);
    CloudSyncAccountClient? registrationClient;
    try {
      registrationClient = _clientFactory();
      final authentication = _authenticationFactory(registrationClient);
      await authentication.discardFirstDeviceRegistration(
        loginName: loginName.trim(),
      );
      _setStatus(CloudSyncProviderStatus.signedOut);
      return true;
    } catch (error, stackTrace) {
      _recordFailure(
        error,
        stackTrace,
        operation: '废弃首设备注册',
        status: CloudSyncProviderStatus.signedOut,
      );
      return false;
    } finally {
      registrationClient?.close(force: true);
      _endSessionMutation();
    }
  }

  Future<bool> logout() async {
    await initialize();
    if (_disposed || _sessionMutationInProgress || _localDeviceWipePending) {
      return false;
    }
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
    if (_localDeviceWipePending) return false;
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
    if (_localDeviceWipePending || _sessionMutationInProgress) return false;
    final client = _client;
    final session = _session;
    if (client == null || session == null) return false;
    final revokesCurrentSession = deviceId == session.deviceId;
    if (revokesCurrentSession && !localDeviceWipeSupported) {
      _deviceError = const CloudSyncException(
        kind: CloudSyncFailureKind.conflict,
        retryable: false,
        serverCode: 'SYNC_LOCAL_DEVICE_WIPE_UNSUPPORTED',
      );
      _notify();
      return false;
    }
    if (revokesCurrentSession) {
      return _beginCurrentDeviceRevocation(client: client, session: session);
    }
    final epoch = _sessionEpoch;

    try {
      final revoked = await client.revokeDevice(deviceId);
      if (epoch != _sessionEpoch || _disposed) return false;
      if (revoked.id != deviceId || revoked.isCurrent) {
        throw const FormatException('cloud_sync_revoke_receipt');
      }
      await refreshDevices();
      return true;
    } catch (error, stackTrace) {
      if (epoch != _sessionEpoch || _disposed) return false;
      _recordDeviceFailure(error, stackTrace, operation: '撤销账户设备');
      return false;
    }
  }

  Future<bool> retryLocalDeviceWipe() async {
    final attempt = _currentDeviceRevocationAttempt;
    if (!_localDeviceWipePending || attempt == null || _disposed) {
      return false;
    }
    return _continueCurrentDeviceRevocation(attempt);
  }

  Future<bool> _beginCurrentDeviceRevocation({
    required CloudSyncAccountClient client,
    required CloudSyncAccountSession session,
  }) {
    final wipe = _localCryptographicWipe;
    final installationOperationLease = _installationOperationLease;
    final installationBusinessLease = _installationBusinessLease;
    final committer = _currentDeviceRevocationCommitter;
    if (wipe == null ||
        installationOperationLease == null ||
        installationBusinessLease == null ||
        committer == null ||
        _stopBackgroundSync == null ||
        _restartForLocalDeviceWipe == null) {
      throw StateError('local_device_wipe_capability_mismatch');
    }
    _beginSessionMutation();
    final attempt = _CurrentDeviceRevocationAttempt(
      client: client,
      session: session,
      mutationId: _revocationMutationIdFactory(),
      wipe: wipe,
      installationOperationLease: installationOperationLease,
      installationBusinessLease: installationBusinessLease,
      committer: committer,
    );
    _currentDeviceRevocationAttempt = attempt;
    _localDeviceWipePending = true;
    _workspaceRestartRequired = false;
    _pendingDeviceApproval = null;
    _devicesLoading = false;
    _setStatus(CloudSyncProviderStatus.signingOut);
    return _continueCurrentDeviceRevocation(attempt);
  }

  Future<bool> _continueCurrentDeviceRevocation(
    _CurrentDeviceRevocationAttempt attempt,
  ) {
    final existing = _localDeviceRevocationContinuation;
    if (existing != null) return existing;
    late final Future<bool> continuation;
    continuation = _performCurrentDeviceRevocation(attempt).whenComplete(() {
      if (identical(_localDeviceRevocationContinuation, continuation)) {
        _localDeviceRevocationContinuation = null;
      }
    });
    _localDeviceRevocationContinuation = continuation;
    return continuation;
  }

  Future<bool> _performCurrentDeviceRevocation(
    _CurrentDeviceRevocationAttempt attempt,
  ) async {
    final stopBackgroundSync = _stopBackgroundSync;
    final restartForLocalDeviceWipe = _restartForLocalDeviceWipe;
    try {
      if (stopBackgroundSync == null || restartForLocalDeviceWipe == null) {
        throw StateError('local_device_wipe_unavailable');
      }
      final intent =
          attempt.installationIntent ??
          await attempt.installationOperationLease.beginRevocationRequest();
      attempt.installationIntent = intent;
      if (!attempt.requestedPublished) {
        await attempt.wipe.markRevocationRequested(
          deviceId: attempt.session.deviceId,
          mutationId: attempt.mutationId,
        );
        await _requirePersistedRevocationIntent(
          wipe: attempt.wipe,
          attempt: attempt,
          phase: LocalCryptographicWipePhase.revocationRequested,
        );
        attempt.requestedPublished = true;
      }
      if (!attempt.businessDrained) {
        await stopBackgroundSync();
        await _closeContentRuntime();
        await _closeWorkspaceForLocalWipe();
        await attempt.installationBusinessLease.close();
        await intent.drainBusinessAfterRequestedPublished();
        attempt.businessDrained = true;
      }
      if (!attempt.receiptValidated) {
        final receipt = await attempt.committer(
          client: attempt.client,
          session: attempt.session,
          mutationId: attempt.mutationId,
        );
        await _requirePersistedRevocationIntent(
          wipe: attempt.wipe,
          attempt: attempt,
          phase: LocalCryptographicWipePhase.revocationRequested,
        );
        if (receipt.operationId != attempt.mutationId ||
            receipt.revokedDeviceId != attempt.session.deviceId) {
          throw const FormatException('cloud_sync_revoke_receipt');
        }
        attempt.receiptValidated = true;
      }
      if (!attempt.confirmedPublished) {
        await attempt.wipe.markRevocationConfirmed(
          deviceId: attempt.session.deviceId,
          mutationId: attempt.mutationId,
        );
        await _requirePersistedRevocationIntent(
          wipe: attempt.wipe,
          attempt: attempt,
          phase: LocalCryptographicWipePhase.revocationConfirmed,
        );
        attempt.confirmedPublished = true;
      }
      _retireConfirmedLocalSession(attempt);
      await restartForLocalDeviceWipe();
      // 成功的进程重启不会回到业务界面。若平台实现意外返回，仍保留
      // 本机擦除门禁，等待进程真正退出后由冷启动恢复路径完成删除。
      return true;
    } catch (error) {
      await _quiesceAfterLocalWipeFailure();
      developer.log(
        '当前设备远端撤销后，本机密码学擦除尚未完成',
        name: 'Kelivo.CloudSyncProvider',
        level: 1000,
      );
      _deviceError = error is FormatException
          ? _normalizeFailure(error)
          : const CloudSyncException(
              kind: CloudSyncFailureKind.unknown,
              retryable: true,
              serverCode: 'SYNC_LOCAL_DEVICE_WIPE_INCOMPLETE',
            );
      _localDeviceWipePending = true;
      _workspaceRestartRequired = false;
      _setStatus(CloudSyncProviderStatus.error);
      return false;
    }
  }

  Future<void> _requirePersistedRevocationIntent({
    required LocalCryptographicWipe wipe,
    required _CurrentDeviceRevocationAttempt attempt,
    required LocalCryptographicWipePhase phase,
  }) async {
    final persisted = await wipe.readPendingIntent();
    if (persisted == null ||
        persisted.phase != phase ||
        persisted.deviceId != attempt.session.deviceId ||
        persisted.mutationId != attempt.mutationId) {
      throw const FormatException('local_wipe_persisted_intent');
    }
  }

  void _retireConfirmedLocalSession(_CurrentDeviceRevocationAttempt attempt) {
    if (attempt.sessionRetired) return;
    attempt.sessionRetired = true;
    _session = null;
    _contentRuntimeReady = false;
    _devices = const <CloudSyncDeviceSession>[];
    _sessionEpoch++;
    attempt.client.close(force: true);
    if (identical(_client, attempt.client)) _client = null;
    _setStatus(CloudSyncProviderStatus.signingOut);
  }

  Future<void> _closeWorkspaceForLocalWipe() async {
    if (_workspaceClosedForLocalWipe) return;
    await _workspaceRuntime.close();
    _workspaceClosedForLocalWipe = true;
  }

  Future<void> _quiesceAfterLocalWipeFailure() async {
    final stopBackgroundSync = _stopBackgroundSync;
    if (stopBackgroundSync != null) {
      await _attemptLocalWipeQuiescence('取消本机擦除后的后台同步', stopBackgroundSync);
    }
    await _attemptLocalWipeQuiescence('关闭本机擦除后的内容运行时', _closeContentRuntime);
    await _attemptLocalWipeQuiescence(
      '释放本机擦除后的工作区',
      _closeWorkspaceForLocalWipe,
    );
    final installationBusinessLease = _installationBusinessLease;
    if (installationBusinessLease != null) {
      await _attemptLocalWipeQuiescence(
        '释放本机擦除后的安装业务租约',
        installationBusinessLease.close,
      );
    }
  }

  Future<void> _attemptLocalWipeQuiescence(
    String operation,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      developer.log('云同步清理步骤失败', name: 'Kelivo.CloudSyncProvider', level: 1000);
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

  Future<void> _commitSecurityBootstrap(
    CloudSyncAccountSession pendingSession,
  ) async {
    final bootstrap = pendingSession.securityBootstrap;
    final current = _session;
    if (bootstrap == null ||
        current == null ||
        current.securityBootstrap == null ||
        current.accountScope != pendingSession.accountScope ||
        current.deviceId != pendingSession.deviceId ||
        current.authGeneration != pendingSession.authGeneration ||
        current.sessionGeneration != pendingSession.sessionGeneration ||
        current.token.value != pendingSession.token.value) {
      throw StateError('安全 bootstrap 提交会话与当前工作区不匹配');
    }

    final client = _clientFactory(token: pendingSession.token);
    try {
      final authentication = _authenticationFactory(client);
      final authenticatedSession = pendingSession.toAuthenticatedSession();
      switch (bootstrap.source) {
        case CloudSyncSecurityBootstrapSource.firstRegistration:
          await authentication.confirmFirstDeviceRegistration(
            loginName: pendingSession.loginName,
            session: authenticatedSession,
          );
          break;
        case CloudSyncSecurityBootstrapSource.pairing:
          await authentication.confirmDevicePairing(
            loginName: pendingSession.loginName,
            session: authenticatedSession,
          );
          break;
      }

      final cleanedSession = pendingSession.withoutSecurityBootstrap();
      final binding = await _workspaceRuntime.bindAccount(cleanedSession);
      if (binding is! AccountWorkspaceRetained) {
        throw StateError('安全 bootstrap 只能在当前账户工作区内提交');
      }
      _session = cleanedSession;
    } finally {
      client.close(force: true);
    }
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

    debugPrint('[CloudSyncProvider] terminal authentication retired');
    _setStatus(CloudSyncProviderStatus.workspaceChangePending);
  }

  void _retainPendingApproval({
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
      client: client,
      pairing: pairing,
    );
    _pendingPairingTask = task;
    _setStatus(CloudSyncProviderStatus.awaitingDeviceApproval);
    unawaited(task);
  }

  Future<void> _completePendingDevicePairing({
    required CloudSyncAccountClient client,
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
    if (workspaceBinding is AccountWorkspaceRestartRequired ||
        session.securityBootstrap != null) {
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
    debugPrint('[CloudSyncProvider] operation failed');
    _notify();
  }

  void _recordDeviceFailure(
    Object error,
    StackTrace stackTrace, {
    required String operation,
  }) {
    _deviceError = _normalizeFailure(error);
    debugPrint('[CloudSyncProvider] device operation failed');
    _notify();
  }

  CloudSyncException _normalizeFailure(Object error) {
    if (error is CloudSyncException) return error;
    if (error is E2eeRecoveryMediaExportCancelled) {
      return const CloudSyncException(
        kind: CloudSyncFailureKind.cancelled,
        retryable: false,
        serverCode: e2eePendingRegistrationExportRequiredCode,
      );
    }
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
        );
      }),
    );
    super.dispose();
  }
}

final class _CurrentDeviceRevocationAttempt {
  _CurrentDeviceRevocationAttempt({
    required this.client,
    required this.session,
    required this.mutationId,
    required this.wipe,
    required this.installationOperationLease,
    required this.installationBusinessLease,
    required this.committer,
  });

  final CloudSyncAccountClient client;
  final CloudSyncAccountSession session;
  final String mutationId;
  final LocalCryptographicWipe wipe;
  final InstallationOperationLease installationOperationLease;
  final InstallationBusinessLease installationBusinessLease;
  final CloudSyncCurrentDeviceRevocationCommitter committer;

  InstallationWipeIntent? installationIntent;
  bool requestedPublished = false;
  bool businessDrained = false;
  bool receiptValidated = false;
  bool confirmedPublished = false;
  bool sessionRetired = false;
}
