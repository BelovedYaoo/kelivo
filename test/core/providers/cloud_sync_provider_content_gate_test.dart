import 'dart:io';

import 'package:Kelivo/core/providers/cloud_sync_provider.dart';
import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_client.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/workspace/account_session_token_store.dart';
import 'package:Kelivo/core/services/workspace/account_workspace_runtime.dart';
import 'package:Kelivo/features/settings/pages/cloud_sync_page.dart'
    hide CloudSyncPage;
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('内容同步硬关闭且不需要旧同步状态库', () async {
    final fixture = await _createSignedInFixture();
    addTearDown(fixture.close);

    await fixture.provider.initialize();

    expect(fixture.provider.contentSyncEnabled, isFalse);
    expect(
      fixture.provider.initialHydrationState,
      CloudSyncInitialHydrationState.notRequired,
    );
    expect(await fixture.provider.setPaused(true), isFalse);
    expect(await fixture.provider.syncAfterLocalWrites(), isFalse);
    expect(await fixture.provider.syncNow(), isFalse);
    expect(await fixture.provider.refreshConflicts(), isFalse);
    expect(
      await fixture.provider.resolveConflict(_conflict(), const <String>{}),
      isFalse,
    );
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
    expect(fixture.provider.paused, isFalse);
    expect(client.token, 'session-token');
    expect(client.requestNames, isEmpty);

    expect(await fixture.provider.refreshDevices(), isTrue);
    expect(fixture.provider.devices.single.name, '测试电脑');
    expect(await fixture.provider.revokeDevice('device-2'), isTrue);
    expect(client.requestNames, <String>[
      'list-devices',
      'revoke-device:device-2',
      'list-devices',
    ]);
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

    expect(fixture.client.requestNames, <String>['login']);
    expect(fixture.client.lastLoginName, 'ovo');
    expect(fixture.client.lastDeviceName, '测试手机');
    expect(fixture.provider.workspaceRestartRequired, isTrue);
    expect(
      fixture.provider.status,
      CloudSyncProviderStatus.workspaceChangePending,
    );
  });

  test('撤销当前设备后退出本机会话', () async {
    final client = _FakeCloudSyncAccountClient(
      listedDevices: <CloudSyncDeviceSession>[_currentDevice()],
      revokedDevice: _currentDevice(),
    );
    final fixture = await _createSignedInFixture(client: client);
    addTearDown(fixture.close);
    await fixture.provider.initialize();

    expect(await fixture.provider.revokeDevice('device-1'), isTrue);

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
    expect(await fixture.provider.syncNow(), isFalse);
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
  final session = _session();
  await runtime.bindAccount(session);
  await runtime.close();
  runtime = await AccountWorkspaceRuntime.bootstrap(
    installationRoot: installationRoot,
    sessionTokenStore: tokenStore,
  );

  final accountClient = client ?? _FakeCloudSyncAccountClient();
  final provider = CloudSyncProvider.controlPlaneOnly(
    runtime,
    clientFactory: ({String? token}) {
      accountClient.setToken(token);
      return accountClient;
    },
  );
  return _Fixture(
    root: root,
    runtime: runtime,
    provider: provider,
    client: accountClient,
  );
}

Future<_Fixture> _createSignedOutFixture({
  _FakeCloudSyncAccountClient? client,
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
  final provider = CloudSyncProvider.controlPlaneOnly(
    runtime,
    clientFactory: ({String? token}) {
      accountClient.setToken(token);
      return accountClient;
    },
  );
  return _Fixture(
    root: root,
    runtime: runtime,
    provider: provider,
    client: accountClient,
  );
}

CloudSyncAccountSession _session() {
  return CloudSyncAccountSession(
    baseUrl: defaultCloudSyncBaseUrl,
    token: 'session-token',
    userId: 'user-1',
    loginName: 'ovo',
    displayName: 'Ovo',
    role: CloudSyncUserRole.user,
    attachmentQuotaBytes: maximumCloudSyncAttachmentSizeBytes,
    deviceId: 'device-1',
    deviceName: '测试手机',
    platform: CloudSyncPlatform.android,
    clientVersion: '1.1.17',
    deviceCreatedAt: DateTime.utc(2026, 7, 22),
  );
}

CloudSyncDeviceSession _currentDevice() {
  return CloudSyncDeviceSession(
    id: 'device-1',
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
    id: 'device-2',
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

CloudSyncConflict _conflict() {
  return CloudSyncConflict(
    conflictId: 'conflict-1',
    mutationId: 'mutation-1',
    entityType: CloudSyncEntityType.message,
    entityId: 'message-1',
    baseRevision: 1,
    fields: <CloudSyncConflictField>[
      CloudSyncConflictField(
        path: '/content',
        current: CloudSyncConflictFieldState(exists: true, value: 'cloud'),
        desired: CloudSyncConflictFieldState(exists: true, value: 'local'),
      ),
    ],
    state: CloudSyncConflictState.open,
    createdAt: DateTime.utc(2026, 7, 22),
    resolvedAt: null,
  );
}

final class _Fixture {
  const _Fixture({
    required this.root,
    required this.runtime,
    required this.provider,
    required this.client,
  });

  final Directory root;
  final AccountWorkspaceRuntime runtime;
  final CloudSyncProvider provider;
  final _FakeCloudSyncAccountClient client;

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
  String? token;
  String? lastLoginName;
  String? lastDeviceName;
  bool closed = false;

  @override
  void close({bool force = false}) {
    closed = true;
  }

  @override
  Future<CloudSyncAccountSession> login({
    required String loginName,
    required String password,
    required String deviceName,
    required CloudSyncPlatform platform,
    required String clientVersion,
  }) {
    requestNames.add('login');
    lastLoginName = loginName;
    lastDeviceName = deviceName;
    return Future<CloudSyncAccountSession>.value(_session());
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
  void setToken(String? token) {
    this.token = token;
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
