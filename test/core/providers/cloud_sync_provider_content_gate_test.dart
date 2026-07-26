import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/providers/cloud_sync_provider.dart';
import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_client.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_authenticator.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/workspace/account_session_token_store.dart';
import 'package:Kelivo/core/services/workspace/account_workspace_runtime.dart';
import 'package:Kelivo/features/settings/pages/cloud_sync_page.dart'
    hide CloudSyncPage;
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

const _userId = '40000000-0000-4000-8000-000000000001';
const _deviceId = '20000000-0000-4000-8000-000000000001';
const _otherDeviceId = '20000000-0000-4000-8000-000000000002';
const _fullTokenValue = 'kelivo_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _onboardingTokenValue =
    'kelivo_onboarding_BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';
final _fullToken = CloudSyncFullSessionToken.parse(_fullTokenValue);
final _onboardingToken = CloudSyncOnboardingToken.parse(_onboardingTokenValue);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('内容同步硬关闭且不需要旧同步状态库', () async {
    final fixture = await _createSignedInFixture();
    addTearDown(fixture.close);

    await fixture.provider.initialize();

    expect(fixture.provider.contentSyncEnabled, isFalse);
    expect(fixture.client.requestNames, isEmpty);
    final legacyStatePaths = fixture.root
        .listSync(recursive: true)
        .map((entry) => entry.path)
        .where((path) => path.contains('cloud_sync_state_v1'));
    expect(legacyStatePaths, isEmpty);
  });

  test('恢复已有会话后设备列表与非当前设备撤销仍可用', () async {
    final client = _FakeCloudSyncAccountClient(
      listedDevices: <CloudSyncDeviceSession>[_otherDevice()],
    );
    final fixture = await _createSignedInFixture(client: client);
    addTearDown(fixture.close);

    await fixture.provider.initialize();

    expect(fixture.provider.initialized, isTrue);
    expect(fixture.provider.signedIn, isTrue);
    expect(fixture.provider.status, CloudSyncProviderStatus.idle);
    expect(client.token?.value, _fullTokenValue);
    expect(client.requestNames, isEmpty);

    expect(await fixture.provider.refreshDevices(), isTrue);
    expect(fixture.provider.devices.single.name, '测试电脑');
    expect(await fixture.provider.revokeDevice(_otherDeviceId), isTrue);
    expect(client.requestNames, <String>[
      'list-devices',
      'revoke-device:$_otherDeviceId',
      'list-devices',
    ]);
  });

  test('恢复过期会话时清理持久状态且不接回令牌', () async {
    final client = _FakeCloudSyncAccountClient();
    final fixture = await _createSignedInFixture(
      client: client,
      session: _session(tokenExpiresAt: DateTime.utc(2000)),
    );
    addTearDown(fixture.close);

    await fixture.provider.initialize();

    expect(fixture.provider.initialized, isTrue);
    expect(fixture.provider.signedIn, isFalse);
    expect(fixture.provider.workspaceRestartRequired, isTrue);
    expect(
      fixture.provider.status,
      CloudSyncProviderStatus.workspaceChangePending,
    );
    expect(client.token, isNull);
    expect(client.requestNames, isEmpty);
  });

  test('新账户登录仅建立账户工作区并要求重启', () async {
    PackageInfo.setMockInitialValues(
      appName: 'Kelivo',
      packageName: 'Kelivo',
      version: '1.1.17',
      buildNumber: '1',
      buildSignature: 'test',
    );
    final fixture = await _createSignedOutFixture();
    addTearDown(fixture.close);

    expect(
      await fixture.provider.login(
        loginName: '  ovo  ',
        password: 'password',
        deviceName: '  测试手机  ',
      ),
      isTrue,
    );

    expect(fixture.authentication.requestNames, <String>['login']);
    expect(fixture.authentication.lastLoginName, 'ovo');
    expect(fixture.authentication.lastPassword, 'password');
    expect(fixture.authentication.lastDeviceName, '测试手机');
    expect(fixture.provider.workspaceRestartRequired, isTrue);
    expect(
      fixture.provider.status,
      CloudSyncProviderStatus.workspaceChangePending,
    );
  });

  test('新设备登录待批准时保留引导上下文且不建立会话', () async {
    PackageInfo.setMockInitialValues(
      appName: 'Kelivo',
      packageName: 'Kelivo',
      version: '1.1.17',
      buildNumber: '1',
      buildSignature: 'test',
    );
    final approval = E2eeAccountLoginApprovalRequired(
      onboardingToken: _onboardingToken,
      onboardingTokenExpiresAt: DateTime.utc(2100),
      loginName: 'ovo',
      device: CloudSyncAuthenticatedDevice(
        id: _deviceId,
        name: '测试电脑',
        platform: CloudSyncPlatform.windows,
        clientVersion: '1.1.17',
        status: CloudSyncAuthenticatedDeviceStatus.pending,
        createdAt: DateTime.utc(2026, 7, 26),
      ),
    );
    final fixture = await _createSignedOutFixture(
      authentication: _FakeE2eeAccountAuthentication(loginResult: approval),
    );
    addTearDown(fixture.close);

    expect(
      await fixture.provider.login(
        loginName: 'ovo',
        password: 'password',
        deviceName: '测试电脑',
      ),
      isFalse,
    );

    expect(fixture.provider.pendingDeviceApproval, same(approval));
    expect(
      fixture.provider.lastError?.serverCode,
      'SYNC_DEVICE_APPROVAL_REQUIRED',
    );
    expect(fixture.provider.signedIn, isFalse);
    expect(fixture.provider.workspaceRestartRequired, isFalse);
    expect(fixture.client.token, isNull);
  });

  test('账户登录失败时保持登出且关闭候选客户端', () async {
    PackageInfo.setMockInitialValues(
      appName: 'Kelivo',
      packageName: 'Kelivo',
      version: '1.1.17',
      buildNumber: '1',
      buildSignature: 'test',
    );
    final fixture = await _createSignedOutFixture(
      authentication: _FakeE2eeAccountAuthentication(
        loginFailure: const CloudSyncException(
          kind: CloudSyncFailureKind.unauthenticated,
          retryable: false,
        ),
      ),
    );
    addTearDown(fixture.close);

    expect(
      await fixture.provider.login(
        loginName: 'ovo',
        password: 'wrong-password',
        deviceName: '测试电脑',
      ),
      isFalse,
    );

    expect(
      fixture.provider.lastError?.kind,
      CloudSyncFailureKind.unauthenticated,
    );
    expect(fixture.provider.signedIn, isFalse);
    expect(fixture.provider.workspaceRestartRequired, isFalse);
    expect(fixture.client.token, isNull);
    expect(fixture.client.closed, isTrue);
  });

  test('移动端首设备注册仅建立账户工作区并要求重启', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    PackageInfo.setMockInitialValues(
      appName: 'Kelivo',
      packageName: 'Kelivo',
      version: '1.1.17',
      buildNumber: '1',
      buildSignature: 'test',
    );
    final fixture = await _createSignedOutFixture();
    addTearDown(fixture.close);

    expect(
      await fixture.provider.register(
        loginName: '  ovo  ',
        displayName: '  Ovo  ',
        password: 'password',
        deviceName: '  测试手机  ',
      ),
      isTrue,
    );

    expect(fixture.authentication.requestNames, <String>[
      'register',
      'confirm-registration',
    ]);
    expect(fixture.authentication.lastLoginName, 'ovo');
    expect(fixture.authentication.lastDisplayName, 'Ovo');
    expect(fixture.authentication.lastPassword, 'password');
    expect(fixture.authentication.lastDeviceName, '测试手机');
    expect(fixture.authentication.lastPlatform, CloudSyncPlatform.android);
    expect(fixture.provider.workspaceRestartRequired, isTrue);
    expect(
      fixture.provider.status,
      CloudSyncProviderStatus.workspaceChangePending,
    );
  });

  test('首设备注册工作区提交后事务清理失败仍保持已提交结果', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    PackageInfo.setMockInitialValues(
      appName: 'Kelivo',
      packageName: 'Kelivo',
      version: '1.1.17',
      buildNumber: '1',
      buildSignature: 'test',
    );
    final authentication = _FakeE2eeAccountAuthentication(
      confirmationFailure: StateError('registration_cleanup_failed'),
    );
    final fixture = await _createSignedOutFixture(
      authentication: authentication,
    );
    addTearDown(fixture.close);

    expect(
      await fixture.provider.register(
        loginName: 'ovo',
        displayName: 'Ovo',
        password: 'password',
        deviceName: '测试手机',
      ),
      isTrue,
    );

    expect(authentication.requestNames, <String>[
      'register',
      'confirm-registration',
    ]);
    expect(fixture.provider.lastError, isNull);
    expect(fixture.provider.workspaceRestartRequired, isTrue);
    expect(
      fixture.provider.status,
      CloudSyncProviderStatus.workspaceChangePending,
    );
  });

  test('移动端首设备注册失败时不建立账户工作区', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    PackageInfo.setMockInitialValues(
      appName: 'Kelivo',
      packageName: 'Kelivo',
      version: '1.1.17',
      buildNumber: '1',
      buildSignature: 'test',
    );
    final fixture = await _createSignedOutFixture(
      authentication: _FakeE2eeAccountAuthentication(
        registrationFailure: const CloudSyncException(
          kind: CloudSyncFailureKind.conflict,
          retryable: false,
          serverCode: 'AUTH_REGISTRATION_CONFLICT',
        ),
      ),
    );
    addTearDown(fixture.close);

    expect(
      await fixture.provider.register(
        loginName: 'ovo',
        displayName: 'Ovo',
        password: 'password',
        deviceName: '测试手机',
      ),
      isFalse,
    );

    expect(
      fixture.provider.lastError?.serverCode,
      'AUTH_REGISTRATION_CONFLICT',
    );
    expect(fixture.provider.signedIn, isFalse);
    expect(fixture.provider.workspaceRestartRequired, isFalse);
    expect(fixture.client.token, isNull);
    expect(fixture.client.closed, isTrue);
  });

  test('撤销当前设备后退出本机会话', () async {
    final client = _FakeCloudSyncAccountClient(
      listedDevices: <CloudSyncDeviceSession>[_currentDevice()],
      revokedDevice: _currentDevice(),
    );
    final fixture = await _createSignedInFixture(client: client);
    addTearDown(fixture.close);
    await fixture.provider.initialize();

    expect(await fixture.provider.revokeDevice(_deviceId), isTrue);

    expect(fixture.provider.signedIn, isFalse);
    expect(fixture.provider.workspaceRestartRequired, isTrue);
    expect(
      fixture.provider.status,
      CloudSyncProviderStatus.workspaceChangePending,
    );
  });

  test('设备控制面失败时返回可诊断错误且不影响内容门禁', () async {
    final client = _FakeCloudSyncAccountClient(
      listFailure: const CloudSyncException(
        kind: CloudSyncFailureKind.network,
        retryable: true,
      ),
    );
    final fixture = await _createSignedInFixture(client: client);
    addTearDown(fixture.close);
    await fixture.provider.initialize();

    expect(await fixture.provider.refreshDevices(), isFalse);

    expect(fixture.provider.deviceError?.kind, CloudSyncFailureKind.network);
    expect(client.requestNames, <String>['list-devices']);
  });

  testWidgets('云同步页面仅展示本机内容提示和账号设备控制面', (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = await tester.runAsync(_createSignedInFixture);
    if (fixture == null) {
      throw StateError('content_gate_fixture_not_created');
    }
    addTearDown(() => tester.runAsync(fixture.close));
    await fixture.provider.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider<CloudSyncProvider>.value(
        value: fixture.provider,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: CloudSyncSettingsContent()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(find.text('端到端加密升级期间，聊天与配置仅保存在本机，账号和设备管理仍可用。'), findsOneWidget);
    expect(find.text('暂停同步'), findsNothing);
    expect(find.text('立即同步'), findsNothing);
    expect(find.text('同步冲突'), findsNothing);
    expect(find.text('设备'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);
  });
}

Future<_Fixture> _createSignedInFixture({
  _FakeCloudSyncAccountClient? client,
  _FakeE2eeAccountAuthentication? authentication,
  CloudSyncAccountSession? session,
}) async {
  final testRoot = Directory(
    '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
    '${Platform.pathSeparator}content_gate_tests',
  );
  await testRoot.create(recursive: true);
  final root = await testRoot.createTemp('signed-in-');
  final tokenStore = _MemoryAccountSessionTokenStore();
  final installationRoot = Directory(
    '${root.path}${Platform.pathSeparator}installation',
  );
  var runtime = await AccountWorkspaceRuntime.bootstrap(
    installationRoot: installationRoot,
    sessionTokenStore: tokenStore,
  );
  await runtime.bindAccount(_session());
  await runtime.close();
  runtime = await AccountWorkspaceRuntime.bootstrap(
    installationRoot: installationRoot,
    sessionTokenStore: tokenStore,
  );
  if (session != null) {
    await runtime.bindAccount(session);
  }

  final accountClient = client ?? _FakeCloudSyncAccountClient();
  final accountAuthentication =
      authentication ?? _FakeE2eeAccountAuthentication();
  final provider = CloudSyncProvider.controlPlaneOnly(
    runtime,
    clientFactory: ({CloudSyncFullSessionToken? token}) {
      accountClient.setToken(token);
      return accountClient;
    },
    authenticationFactory: (_) => accountAuthentication,
  );
  return _Fixture(
    root: root,
    runtime: runtime,
    provider: provider,
    client: accountClient,
    authentication: accountAuthentication,
  );
}

Future<_Fixture> _createSignedOutFixture({
  _FakeCloudSyncAccountClient? client,
  _FakeE2eeAccountAuthentication? authentication,
}) async {
  final testRoot = Directory(
    '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
    '${Platform.pathSeparator}content_gate_tests',
  );
  await testRoot.create(recursive: true);
  final root = await testRoot.createTemp('signed-out-');
  final runtime = await AccountWorkspaceRuntime.bootstrap(
    installationRoot: Directory(
      '${root.path}${Platform.pathSeparator}installation',
    ),
    sessionTokenStore: _MemoryAccountSessionTokenStore(),
  );
  final accountClient = client ?? _FakeCloudSyncAccountClient();
  final accountAuthentication =
      authentication ?? _FakeE2eeAccountAuthentication();
  final provider = CloudSyncProvider.controlPlaneOnly(
    runtime,
    clientFactory: ({CloudSyncFullSessionToken? token}) {
      accountClient.setToken(token);
      return accountClient;
    },
    authenticationFactory: (_) => accountAuthentication,
  );
  return _Fixture(
    root: root,
    runtime: runtime,
    provider: provider,
    client: accountClient,
    authentication: accountAuthentication,
  );
}

CloudSyncAccountSession _session({DateTime? tokenExpiresAt}) {
  return CloudSyncAccountSession(
    baseUrl: defaultCloudSyncBaseUrl,
    token: _fullToken,
    tokenExpiresAt: tokenExpiresAt ?? DateTime.utc(2100),
    keyEpoch: 1,
    userId: _userId,
    loginName: 'ovo',
    displayName: 'Ovo',
    role: CloudSyncUserRole.user,
    attachmentQuotaBytes: maximumCloudSyncAttachmentSizeBytes,
    deviceId: _deviceId,
    deviceName: '测试手机',
    platform: CloudSyncPlatform.android,
    clientVersion: '1.1.17',
    deviceCreatedAt: DateTime.utc(2026, 7, 22),
  );
}

CloudSyncAuthenticatedSession _authenticatedSession({
  DateTime? tokenExpiresAt,
  int keyEpoch = 1,
}) {
  return CloudSyncAuthenticatedSession(
    token: _fullToken,
    tokenExpiresAt: tokenExpiresAt ?? DateTime.utc(2100),
    keyEpoch: keyEpoch,
    user: CloudSyncAuthenticatedUser(
      id: _userId,
      loginName: 'ovo',
      displayName: 'Ovo',
      role: CloudSyncUserRole.user,
      attachmentQuotaBytes: maximumCloudSyncAttachmentSizeBytes,
    ),
    device: CloudSyncAuthenticatedDevice(
      id: _deviceId,
      name: '测试手机',
      platform: CloudSyncPlatform.android,
      clientVersion: '1.1.17',
      status: CloudSyncAuthenticatedDeviceStatus.active,
      createdAt: DateTime.utc(2026, 7, 22),
    ),
  );
}

CloudSyncDeviceSession _currentDevice() {
  return CloudSyncDeviceSession(
    id: _deviceId,
    name: '测试手机',
    platform: CloudSyncPlatform.android,
    clientVersion: '1.1.17',
    status: CloudSyncDeviceStatus.active,
    createdAt: DateTime.utc(2026, 7, 22),
    lastSeenAt: DateTime.utc(2026, 7, 22),
    revokedAt: null,
    isCurrent: true,
  );
}

CloudSyncDeviceSession _otherDevice() {
  return CloudSyncDeviceSession(
    id: _otherDeviceId,
    name: '测试电脑',
    platform: CloudSyncPlatform.windows,
    clientVersion: '1.1.17',
    status: CloudSyncDeviceStatus.active,
    createdAt: DateTime.utc(2026, 7, 22),
    lastSeenAt: DateTime.utc(2026, 7, 22),
    revokedAt: null,
    isCurrent: false,
  );
}

final class _Fixture {
  const _Fixture({
    required this.root,
    required this.runtime,
    required this.provider,
    required this.client,
    required this.authentication,
  });

  final Directory root;
  final AccountWorkspaceRuntime runtime;
  final CloudSyncProvider provider;
  final _FakeCloudSyncAccountClient client;
  final _FakeE2eeAccountAuthentication authentication;

  Future<void> close() async {
    provider.dispose();
    await runtime.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }
}

final class _FakeCloudSyncAccountClient implements CloudSyncAccountClient {
  _FakeCloudSyncAccountClient({
    this.listedDevices = const <CloudSyncDeviceSession>[],
    this.revokedDevice,
    this.listFailure,
  });

  final List<CloudSyncDeviceSession> listedDevices;
  final CloudSyncDeviceSession? revokedDevice;
  final CloudSyncException? listFailure;
  final List<String> requestNames = <String>[];
  CloudSyncFullSessionToken? token;
  bool closed = false;

  @override
  void close({bool force = false}) {
    closed = true;
  }

  @override
  Future<CloudSyncOpaqueRegistrationStart> startOpaqueRegistration({
    required String loginName,
    required String displayName,
    required CloudSyncOpaqueDeviceIdentity device,
    required Uint8List registrationRequest,
  }) {
    throw UnsupportedError('unexpected_opaque_registration_start');
  }

  @override
  Future<CloudSyncAuthenticatedSession> finishOpaqueRegistration({
    required String attemptId,
    required Uint8List registrationUpload,
    required Uint8List accountKeyEnvelope,
    required Uint8List deviceProof,
  }) {
    throw UnsupportedError('unexpected_opaque_registration_finish');
  }

  @override
  Future<CloudSyncOpaqueLoginStart> startOpaqueLogin({
    required String loginName,
    required CloudSyncOpaqueDeviceIdentity device,
    required Uint8List credentialRequest,
  }) {
    throw UnsupportedError('unexpected_opaque_login_start');
  }

  @override
  Future<CloudSyncOpaqueLoginFinishResult> finishOpaqueLogin({
    required String attemptId,
    required Uint8List credentialFinalization,
    required Uint8List deviceProof,
  }) {
    throw UnsupportedError('unexpected_opaque_login_finish');
  }

  @override
  Future<CloudSyncDevicePairingCreated> createDevicePairing({
    required CloudSyncOnboardingToken token,
    required String pairingId,
    required Uint8List pairingSecretHash,
  }) {
    throw UnsupportedError('unexpected_pairing_create');
  }

  @override
  Future<CloudSyncDevicePairingQueryResult> queryDevicePairing({
    required CloudSyncOnboardingToken token,
    required String pairingId,
  }) {
    throw UnsupportedError('unexpected_pairing_query');
  }

  @override
  Future<CloudSyncDevicePairingApproval> approveDevicePairing({
    required CloudSyncFullSessionToken token,
    required String pairingId,
    required int keyEpoch,
    required Uint8List accountKeyEnvelope,
    required Uint8List deviceProof,
    required Uint8List pairingAuthenticator,
  }) {
    throw UnsupportedError('unexpected_pairing_approve');
  }

  @override
  Future<CloudSyncAuthenticatedSession> consumeDevicePairing({
    required CloudSyncOnboardingToken token,
    required String pairingId,
  }) {
    throw UnsupportedError('unexpected_pairing_consume');
  }

  @override
  Future<CloudSyncDevicePairingCancellation> cancelDevicePairing({
    required CloudSyncOnboardingToken token,
    required String pairingId,
  }) {
    throw UnsupportedError('unexpected_pairing_cancel');
  }

  @override
  Future<CloudSyncPage<CloudSyncDeviceSession>> listDevices({
    CloudSyncDeviceStatus? status,
    int pageIndex = 1,
    int pageSize = 50,
  }) async {
    requestNames.add('list-devices');
    final failure = listFailure;
    if (failure != null) throw failure;
    return CloudSyncPage<CloudSyncDeviceSession>(
      items: listedDevices,
      total: listedDevices.length,
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
  }

  @override
  Future<CloudSyncDeviceSession> revokeDevice(String deviceId) {
    requestNames.add('revoke-device:$deviceId');
    return Future<CloudSyncDeviceSession>.value(
      revokedDevice ?? _otherDevice(),
    );
  }

  @override
  void setToken(CloudSyncFullSessionToken? token) {
    this.token = token;
  }
}

final class _FakeE2eeAccountAuthentication
    implements E2eeAccountAuthentication {
  _FakeE2eeAccountAuthentication({
    E2eeAccountLoginResult? loginResult,
    CloudSyncAuthenticatedSession? registrationSession,
    this.loginFailure,
    this.registrationFailure,
    this.confirmationFailure,
  }) : loginResult =
           loginResult ??
           E2eeAccountLoginAuthenticated(_authenticatedSession()),
       registrationSession = registrationSession ?? _authenticatedSession();

  final E2eeAccountLoginResult loginResult;
  final CloudSyncAuthenticatedSession registrationSession;
  final Object? loginFailure;
  final Object? registrationFailure;
  final Object? confirmationFailure;
  final List<String> requestNames = <String>[];
  String? lastLoginName;
  String? lastDisplayName;
  String? lastPassword;
  String? lastDeviceName;
  CloudSyncPlatform? lastPlatform;
  String? lastClientVersion;

  @override
  Future<E2eeAccountLoginResult> loginDevice({
    required String loginName,
    required Uint8List password,
    required String deviceName,
    required CloudSyncPlatform platform,
    required String clientVersion,
  }) async {
    requestNames.add('login');
    lastLoginName = loginName;
    lastPassword = utf8.decode(password);
    lastDeviceName = deviceName;
    lastPlatform = platform;
    lastClientVersion = clientVersion;
    try {
      final failure = loginFailure;
      if (failure != null) throw failure;
      return loginResult;
    } finally {
      password.fillRange(0, password.length, 0);
    }
  }

  @override
  Future<CloudSyncAuthenticatedSession> registerFirstDevice({
    required String loginName,
    required String displayName,
    required Uint8List password,
    required String deviceName,
    required CloudSyncPlatform platform,
    required String clientVersion,
  }) async {
    requestNames.add('register');
    lastLoginName = loginName;
    lastDisplayName = displayName;
    lastPassword = utf8.decode(password);
    lastDeviceName = deviceName;
    lastPlatform = platform;
    lastClientVersion = clientVersion;
    try {
      final failure = registrationFailure;
      if (failure != null) throw failure;
      return registrationSession;
    } finally {
      password.fillRange(0, password.length, 0);
    }
  }

  @override
  Future<void> confirmFirstDeviceRegistration({
    required String loginName,
    required CloudSyncAuthenticatedSession session,
  }) async {
    requestNames.add('confirm-registration');
    lastLoginName = loginName;
    final failure = confirmationFailure;
    if (failure != null) throw failure;
  }
}

final class _MemoryAccountSessionTokenStore
    implements AccountSessionTokenStore {
  final Map<String, String> _tokens = <String, String>{};

  @override
  Future<AccountSessionTokenReference> writeToken({
    required Directory accountDirectory,
    required String workspaceKey,
    required String token,
    required AccountSessionTokenReference? currentReference,
    required RestoreDurability durability,
  }) async {
    final reference = AccountSessionTokenReference.next(currentReference);
    _tokens[_key(accountDirectory, reference)] = token;
    return reference;
  }

  @override
  Future<String> readToken({
    required Directory accountDirectory,
    required String workspaceKey,
    required AccountSessionTokenReference reference,
  }) async {
    final token = _tokens[_key(accountDirectory, reference)];
    if (token == null) throw StateError('account_session_token_missing');
    return token;
  }

  @override
  Future<void> deleteTokens({
    required Directory accountDirectory,
    required AccountSessionTokenReference? keep,
    required RestoreDurability durability,
  }) async {
    final prefix = '${accountDirectory.absolute.path}|';
    final keepKey = keep == null ? null : _key(accountDirectory, keep);
    _tokens.removeWhere((key, _) => key.startsWith(prefix) && key != keepKey);
  }

  static String _key(
    Directory accountDirectory,
    AccountSessionTokenReference reference,
  ) {
    return '${accountDirectory.absolute.path}|'
        '${reference.slot}|${reference.generation}';
  }
}
