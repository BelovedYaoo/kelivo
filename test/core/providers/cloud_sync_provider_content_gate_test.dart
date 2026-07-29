import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_gateway.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/cloud_sync_provider.dart';
import 'package:Kelivo/core/providers/instruction_injection_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/memory_provider.dart';
import 'package:Kelivo/core/providers/quick_phrase_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/providers/world_book_provider.dart';
import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_client.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_content_runtime.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_record_types.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/sync/config_sync_keys.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_authenticator.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_record_cipher.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_record_state.dart';
import 'package:Kelivo/core/services/sync/e2ee_chat_content_runtime.dart';
import 'package:Kelivo/core/services/sync/e2ee_config_provider_binding.dart';
import 'package:Kelivo/core/services/sync/e2ee_device_state_access.dart';
import 'package:Kelivo/core/services/sync/e2ee_sync_outbox.dart';
import 'package:Kelivo/core/services/sync/e2ee_sync_payload_codec.dart';
import 'package:Kelivo/core/services/sync/e2ee_sync_pull.dart';
import 'package:Kelivo/core/services/sync/e2ee_sync_scheduler.dart';
import 'package:Kelivo/core/services/sync/sync_codec.dart';
import 'package:Kelivo/core/services/sync/sync_write_executor.dart';
import 'package:Kelivo/core/services/workspace/account_session_token_store.dart';
import 'package:Kelivo/core/services/workspace/account_workspace_runtime.dart';
import 'package:Kelivo/core/services/workspace/device_state_blob_store.dart';
import 'package:Kelivo/features/settings/pages/cloud_sync_page.dart'
    hide CloudSyncPage;
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/utils/app_directories.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/test_database_cipher.dart';

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

  test('E2EE 同步周期按有界拉取、封装、发送和最终拉取执行', () async {
    final events = <String>[];
    final pullSteps = <E2eeSyncPullStepDisposition>[
      E2eeSyncPullStepDisposition.more,
      E2eeSyncPullStepDisposition.more,
      E2eeSyncPullStepDisposition.complete,
    ];
    final sealSteps = <E2eeSyncSealStatus>[
      E2eeSyncSealStatus.sealed,
      E2eeSyncSealStatus.sealed,
      E2eeSyncSealStatus.idle,
    ];
    final runner = E2eeSyncCycleRunner(
      maximumPullPagesPerPhase: 2,
      maximumSealAttempts: 4,
      runPullBatch: <T>(pull) async {
        events.add('pull-batch-start');
        final result = await pull();
        events.add('pull-batch-end');
        return result;
      },
      pullOnce: ({required int limit}) async {
        expect(limit, 10);
        events.add('pull');
        return pullSteps.removeAt(0);
      },
      sealNext: () async {
        events.add('seal');
        return sealSteps.removeAt(0);
      },
      flushOnce: () async {
        events.add('flush');
        return const E2eeSyncFlushReport.idle();
      },
    );

    final report = await runner.run();

    expect(report.disposition, E2eeSyncCycleDisposition.completed);
    expect(report.catchUpPullPages, 2);
    expect(report.sealedRecords, 2);
    expect(report.finalPullPages, 1);
    expect(events, <String>[
      'pull-batch-start',
      'pull',
      'pull',
      'pull-batch-end',
      'seal',
      'seal',
      'seal',
      'flush',
      'pull-batch-start',
      'pull',
      'pull-batch-end',
    ]);
  });

  test('E2EE 调度器串行执行并将运行中唤醒合并为一个周期', () async {
    final timers = _ManualTimerQueue();
    final firstPull = Completer<void>();
    var pullCalls = 0;
    var activePullBatches = 0;
    var maximumActivePullBatches = 0;
    final runner = E2eeSyncCycleRunner(
      runPullBatch: <T>(pull) async {
        activePullBatches++;
        if (activePullBatches > maximumActivePullBatches) {
          maximumActivePullBatches = activePullBatches;
        }
        try {
          return await pull();
        } finally {
          activePullBatches--;
        }
      },
      pullOnce: ({required int limit}) async {
        pullCalls++;
        if (pullCalls == 1) await firstPull.future;
        return E2eeSyncPullStepDisposition.complete;
      },
      sealNext: () async => E2eeSyncSealStatus.idle,
      flushOnce: () async => const E2eeSyncFlushReport.idle(),
    );
    final scheduler = E2eeSyncScheduler(
      cycleRunner: runner,
      timerFactory: timers.create,
    );
    addTearDown(scheduler.close);

    scheduler.start();
    await _waitUntil(() => pullCalls == 1);
    scheduler
      ..wake()
      ..wake()
      ..wake();
    firstPull.complete();
    await _waitUntil(() => scheduler.state == E2eeSyncSchedulerState.polling);

    expect(timers.nextDelay, Duration.zero);
    timers.fireNext();
    await _waitUntil(() => pullCalls == 4);
    await _waitUntil(
      () => scheduler.nextRunDelay == const Duration(seconds: 30),
    );

    expect(maximumActivePullBatches, 1);
    expect(pullCalls, 4);
  });

  test('E2EE 调度器不会丢失周期完成边界上的本地唤醒', () async {
    final timers = _ManualTimerQueue();
    var pullCalls = 0;
    var injectedWake = false;
    late E2eeSyncScheduler scheduler;
    final runner = E2eeSyncCycleRunner(
      runPullBatch: <T>(pull) => pull(),
      pullOnce: ({required int limit}) async {
        pullCalls++;
        return E2eeSyncPullStepDisposition.complete;
      },
      sealNext: () async => E2eeSyncSealStatus.idle,
      flushOnce: () async => const E2eeSyncFlushReport.idle(),
    );
    scheduler = E2eeSyncScheduler(
      cycleRunner: runner,
      timerFactory: (delay, callback) {
        final timer = timers.create(delay, callback);
        if (!injectedWake && delay == const Duration(seconds: 30)) {
          injectedWake = true;
          scheduler.wake();
        }
        return timer;
      },
    );
    addTearDown(scheduler.close);

    scheduler.start();
    await _waitUntil(() => pullCalls == 4);

    expect(injectedWake, isTrue);
    expect(scheduler.nextRunDelay, const Duration(seconds: 30));
  });

  test('E2EE 调度器连续失败指数退避且成功后恢复轮询', () async {
    final timers = _ManualTimerQueue();
    final errors = <Object>[];
    var failuresRemaining = 2;
    var pullCalls = 0;
    final runner = E2eeSyncCycleRunner(
      runPullBatch: <T>(pull) => pull(),
      pullOnce: ({required int limit}) async {
        pullCalls++;
        if (failuresRemaining > 0) {
          failuresRemaining--;
          throw StateError('offline');
        }
        return E2eeSyncPullStepDisposition.complete;
      },
      sealNext: () async => E2eeSyncSealStatus.idle,
      flushOnce: () async => const E2eeSyncFlushReport.idle(),
    );
    final scheduler = E2eeSyncScheduler(
      cycleRunner: runner,
      timerFactory: timers.create,
      errorReporter: (error, _) => errors.add(error),
    );
    addTearDown(scheduler.close);

    scheduler.start();
    await _waitUntil(() => scheduler.state == E2eeSyncSchedulerState.retrying);
    expect(scheduler.nextRunDelay, const Duration(seconds: 1));

    timers.fireNext();
    await _waitUntil(
      () => scheduler.nextRunDelay == const Duration(seconds: 2),
    );

    timers.fireNext();
    await _waitUntil(() => scheduler.state == E2eeSyncSchedulerState.polling);
    expect(scheduler.nextRunDelay, const Duration(seconds: 30));
    expect(pullCalls, 4);
    expect(errors, hasLength(2));
  });

  test('E2EE 调度器遇到终止错误后停止且仅通知一次', () async {
    final timers = _ManualTimerQueue();
    final terminalFailure = StateError('session_revoked');
    var pullCalls = 0;
    var terminalNotifications = 0;
    final runner = E2eeSyncCycleRunner(
      runPullBatch: <T>(pull) => pull(),
      pullOnce: ({required int limit}) async {
        pullCalls++;
        throw terminalFailure;
      },
      sealNext: () async => E2eeSyncSealStatus.idle,
      flushOnce: () async => const E2eeSyncFlushReport.idle(),
    );
    final scheduler = E2eeSyncScheduler(
      cycleRunner: runner,
      timerFactory: timers.create,
      isTerminalFailure: (error) => identical(error, terminalFailure),
      onTerminalFailure: (error, stackTrace) async {
        terminalNotifications++;
      },
    );
    addTearDown(scheduler.close);

    scheduler.start();
    await _waitUntil(() => terminalNotifications == 1);
    scheduler
      ..wake()
      ..wake();
    await Future<void>.delayed(Duration.zero);

    expect(scheduler.state, E2eeSyncSchedulerState.terminated);
    expect(scheduler.nextRunDelay, isNull);
    expect(timers.nextDelay, isNull);
    expect(pullCalls, 1);
    expect(terminalNotifications, 1);
  });

  test('E2EE 调度器清空在途周期后才允许终止回调关闭自身', () async {
    final terminalFailure = StateError('session_revoked');
    late E2eeSyncScheduler scheduler;
    var terminalNotifications = 0;
    final runner = E2eeSyncCycleRunner(
      runPullBatch: <T>(pull) => pull(),
      pullOnce: ({required int limit}) =>
          Future<E2eeSyncPullStepDisposition>.error(terminalFailure),
      sealNext: () async => E2eeSyncSealStatus.idle,
      flushOnce: () async => const E2eeSyncFlushReport.idle(),
    );
    scheduler = E2eeSyncScheduler(
      cycleRunner: runner,
      isTerminalFailure: (error) => identical(error, terminalFailure),
      onTerminalFailure: (error, stackTrace) async {
        terminalNotifications++;
        await scheduler.close();
      },
    );

    scheduler.start();
    await _waitUntil(() => scheduler.state == E2eeSyncSchedulerState.closed);

    expect(terminalNotifications, 1);
  });

  test('E2EE 调度器遇到未来密钥世代后暂停且不响应普通唤醒', () async {
    final timers = _ManualTimerQueue();
    var keyEpochAvailable = false;
    var pullCalls = 0;
    final runner = E2eeSyncCycleRunner(
      runPullBatch: <T>(pull) => pull(),
      pullOnce: ({required int limit}) async {
        pullCalls++;
        return keyEpochAvailable
            ? E2eeSyncPullStepDisposition.complete
            : E2eeSyncPullStepDisposition.keyEpochUnavailable;
      },
      sealNext: () async => E2eeSyncSealStatus.idle,
      flushOnce: () async => const E2eeSyncFlushReport.idle(),
    );
    final scheduler = E2eeSyncScheduler(
      cycleRunner: runner,
      timerFactory: timers.create,
    );
    addTearDown(scheduler.close);

    scheduler.start();
    await _waitUntil(
      () => scheduler.state == E2eeSyncSchedulerState.keyEpochPaused,
    );
    scheduler
      ..wake()
      ..wake();
    await Future<void>.delayed(Duration.zero);

    expect(pullCalls, 1);
    expect(timers.nextDelay, isNull);

    keyEpochAvailable = true;
    scheduler.resumeAfterKeyEpochChange();
    expect(timers.nextDelay, Duration.zero);
    timers.fireNext();
    await _waitUntil(() => scheduler.state == E2eeSyncSchedulerState.polling);
    expect(pullCalls, 3);
  });

  test('E2EE 调度器关闭会取消定时器并等待在途周期', () async {
    final timers = _ManualTimerQueue();
    final blockedPull = Completer<void>();
    var pullStarted = false;
    final runner = E2eeSyncCycleRunner(
      runPullBatch: <T>(pull) => pull(),
      pullOnce: ({required int limit}) async {
        pullStarted = true;
        await blockedPull.future;
        return E2eeSyncPullStepDisposition.complete;
      },
      sealNext: () async => E2eeSyncSealStatus.idle,
      flushOnce: () async => const E2eeSyncFlushReport.idle(),
    );
    final scheduler = E2eeSyncScheduler(
      cycleRunner: runner,
      timerFactory: timers.create,
    );
    scheduler.start();
    await _waitUntil(() => pullStarted);

    var closed = false;
    final closeFuture = scheduler.close().then((_) => closed = true);
    await Future<void>.delayed(Duration.zero);
    expect(closed, isFalse);

    blockedPull.complete();
    await closeFuture;
    expect(scheduler.state, E2eeSyncSchedulerState.closed);
    expect(timers.nextDelay, isNull);
  });

  test('E2EE 生产运行时缺少配置桥接时失败关闭且不启动网络', () async {
    final harness = await _E2eeRuntimeHarness.create();
    addTearDown(harness.close);
    final instance = harness.createInstance(withConfigProviders: false);

    await expectLater(instance.runtime.initialize(), throwsStateError);

    expect(instance.runtime.state, E2eeChatContentRuntimeState.failed);
    expect(instance.pull.pullCalls, 0);
    expect(instance.transportSession, isNull);
    await instance.runtime.close();
  });

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

  test('已有会话仅在内容运行时初始化成功后开启内容同步', () async {
    final contentRuntime = _FakeCloudSyncContentRuntime();
    final fixture = await _createSignedInFixture(
      contentRuntime: contentRuntime,
    );
    addTearDown(fixture.close);

    expect(fixture.provider.contentSyncEnabled, isFalse);

    await fixture.provider.initialize();

    expect(contentRuntime.initializeCalls, 1);
    expect(fixture.provider.contentSyncEnabled, isTrue);
    expect(fixture.provider.status, CloudSyncProviderStatus.idle);
  });

  test('内容运行时初始化失败时不接回控制面令牌', () async {
    final contentRuntime = _FakeCloudSyncContentRuntime(
      initializeFailure: StateError('content_runtime_initialize_failed'),
    );
    final fixture = await _createSignedInFixture(
      contentRuntime: contentRuntime,
    );
    addTearDown(fixture.close);

    await fixture.provider.initialize();

    expect(contentRuntime.initializeCalls, 1);
    expect(fixture.provider.contentSyncEnabled, isFalse);
    expect(fixture.provider.status, CloudSyncProviderStatus.error);
    expect(fixture.client.token, isNull);
  });

  test('登出先关闭内容运行时并关闭内容同步门', () async {
    final contentRuntime = _FakeCloudSyncContentRuntime();
    final fixture = await _createSignedInFixture(
      contentRuntime: contentRuntime,
    );
    addTearDown(fixture.close);
    await fixture.provider.initialize();

    expect(await fixture.provider.logout(), isTrue);

    expect(contentRuntime.closeCalls, 1);
    expect(fixture.provider.contentSyncEnabled, isFalse);
    expect(fixture.provider.workspaceRestartRequired, isTrue);
  });

  test('内容运行时关闭失败时仍清理持久会话并保持重启门禁', () async {
    final contentRuntime = _FakeCloudSyncContentRuntime(
      closeFailure: StateError('content_runtime_close_failed'),
    );
    final fixture = await _createSignedInFixture(
      contentRuntime: contentRuntime,
    );
    addTearDown(fixture.close);
    await fixture.provider.initialize();

    expect(await fixture.provider.logout(), isFalse);

    expect(contentRuntime.closeCalls, 1);
    expect(fixture.runtime.current.session, isNull);
    expect(fixture.provider.signedIn, isFalse);
    expect(fixture.provider.contentSyncEnabled, isFalse);
    expect(fixture.provider.workspaceRestartRequired, isTrue);
    expect(
      fixture.provider.status,
      CloudSyncProviderStatus.workspaceChangePending,
    );
  });

  test('远端终止认证后持久清除会话并关闭内容运行时', () async {
    final contentRuntime = _FakeCloudSyncContentRuntime();
    final fixture = await _createSignedInFixture(
      contentRuntime: contentRuntime,
    );
    addTearDown(fixture.close);
    await fixture.provider.initialize();

    await contentRuntime.triggerTerminalAuthentication(
      const CloudSyncException(
        kind: CloudSyncFailureKind.unauthenticated,
        retryable: false,
        serverCode: 'SYNC_SESSION_REVOKED',
      ),
    );

    expect(contentRuntime.closeCalls, 1);
    expect(fixture.runtime.current.session, isNull);
    expect(fixture.provider.signedIn, isFalse);
    expect(fixture.provider.contentSyncEnabled, isFalse);
    expect(fixture.provider.workspaceRestartRequired, isTrue);
    expect(
      fixture.provider.status,
      CloudSyncProviderStatus.workspaceChangePending,
    );
    expect(
      fixture.provider.lastError?.kind,
      CloudSyncFailureKind.unauthenticated,
    );
  });

  test('远端终止认证清理失败时仍不保留已登录假象', () async {
    final contentRuntime = _FakeCloudSyncContentRuntime(
      closeFailure: StateError('content_runtime_close_failed'),
    );
    final fixture = await _createSignedInFixture(
      contentRuntime: contentRuntime,
    );
    addTearDown(fixture.close);
    await fixture.provider.initialize();

    await expectLater(
      contentRuntime.triggerTerminalAuthentication(
        const CloudSyncException(
          kind: CloudSyncFailureKind.forbidden,
          retryable: false,
          serverCode: 'SYNC_DEVICE_REVOKED',
        ),
      ),
      throwsStateError,
    );

    expect(fixture.runtime.current.session, isNull);
    expect(fixture.provider.signedIn, isFalse);
    expect(fixture.provider.contentSyncEnabled, isFalse);
    expect(fixture.provider.workspaceRestartRequired, isTrue);
    expect(fixture.provider.lastError?.kind, CloudSyncFailureKind.unknown);
    expect(
      fixture.provider.status,
      CloudSyncProviderStatus.workspaceChangePending,
    );
  });

  test('旧内容运行时的终止回调不得登出替换后的新会话', () async {
    PackageInfo.setMockInitialValues(
      appName: 'Kelivo',
      packageName: 'Kelivo',
      version: '1.1.17',
      buildNumber: '1',
      buildSignature: 'test',
    );
    final contentRuntime = _FakeCloudSyncContentRuntime();
    final fixture = await _createSignedInFixture(
      contentRuntime: contentRuntime,
    );
    addTearDown(fixture.close);
    await fixture.provider.initialize();
    final staleHandler = contentRuntime.terminalAuthenticationHandler;

    expect(await fixture.provider.logout(), isTrue);
    expect(
      await fixture.provider.login(
        loginName: 'ovo',
        password: 'password',
        deviceName: '新设备',
      ),
      isTrue,
    );
    await staleHandler(
      const CloudSyncException(
        kind: CloudSyncFailureKind.unauthenticated,
        retryable: false,
      ),
      StackTrace.current,
    );

    expect(fixture.provider.signedIn, isTrue);
    expect(fixture.provider.session?.deviceId, _deviceId);
    expect(fixture.provider.status, CloudSyncProviderStatus.idle);
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

    expect(fixture.authentication.requestNames, <String>[
      'login',
      'confirm-pairing',
    ]);
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
    final pairing = _FakeE2eeDevicePairingSession();
    final authentication = _FakeE2eeAccountAuthentication(
      loginResult: approval,
      pairingSession: pairing,
    );
    final fixture = await _createSignedOutFixture(
      authentication: authentication,
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
    expect(authentication.requestNames, <String>['login', 'start-pairing']);
    expect(
      fixture.provider.status,
      CloudSyncProviderStatus.awaitingDeviceApproval,
    );
    expect(
      fixture.provider.takePendingDevicePairingQrFrame(),
      pairing.expectedQrFrame,
    );
    expect(fixture.provider.signedIn, isFalse);
    expect(fixture.provider.workspaceRestartRequired, isFalse);
    expect(fixture.client.token, isNull);
    expect(await fixture.provider.cancelPendingDevicePairing(), isTrue);
    expect(pairing.cancelCalls, 1);
    expect(fixture.client.closed, isTrue);
  });

  test('待批准设备完成配对后提交账户工作区并确认恢复事务', () async {
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
    final pairing = _FakeE2eeDevicePairingSession();
    final authentication = _FakeE2eeAccountAuthentication(
      loginResult: approval,
      pairingSession: pairing,
    );
    final fixture = await _createSignedOutFixture(
      authentication: authentication,
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
    pairing.approve(_authenticatedSession());
    await _waitUntil(
      () => authentication.requestNames.contains('confirm-pairing'),
    );

    expect(authentication.requestNames, <String>[
      'login',
      'start-pairing',
      'confirm-pairing',
    ]);
    expect(fixture.provider.pendingDeviceApproval, isNull);
    expect(fixture.provider.workspaceRestartRequired, isTrue);
    expect(
      fixture.provider.status,
      CloudSyncProviderStatus.workspaceChangePending,
    );
    expect(fixture.client.closed, isTrue);
  });

  test('等待设备配对失败时清理待批准状态并关闭候选客户端', () async {
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
    final pairing = _FakeE2eeDevicePairingSession();
    final fixture = await _createSignedOutFixture(
      authentication: _FakeE2eeAccountAuthentication(
        loginResult: approval,
        pairingSession: pairing,
      ),
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
    pairing.fail(
      const CloudSyncException(
        kind: CloudSyncFailureKind.network,
        retryable: true,
      ),
    );
    await _waitUntil(() => fixture.provider.pendingDeviceApproval == null);

    expect(fixture.provider.lastError?.kind, CloudSyncFailureKind.network);
    expect(fixture.provider.status, CloudSyncProviderStatus.signedOut);
    expect(fixture.client.closed, isTrue);
    expect(fixture.provider.takePendingDevicePairingQrFrame(), isNull);
  });

  test('移动可信设备批准扫码配对并清零二维码帧', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final authentication = _FakeE2eeAccountAuthentication();
    final fixture = await _createSignedInFixture(
      authentication: authentication,
    );
    addTearDown(fixture.close);
    await fixture.provider.initialize();
    final qrFrame = Uint8List.fromList(<int>[8, 6, 7, 5, 3, 0, 9]);

    expect(await fixture.provider.approveDevicePairing(qrFrame), isTrue);

    expect(authentication.requestNames, <String>['approve-pairing']);
    expect(authentication.lastPairingQrFrame, <int>[8, 6, 7, 5, 3, 0, 9]);
    expect(qrFrame, everyElement(0));
    expect(fixture.provider.devicePairingApprovalInProgress, isFalse);
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

  testWidgets('移动平台展示注册模式且桌面平台仅保留登录', (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final fixture = await tester.runAsync(_createSignedOutFixture);
    if (fixture == null) {
      throw StateError('registration_ui_fixture_not_created');
    }
    addTearDown(() => tester.runAsync(fixture.close));
    await tester.runAsync(fixture.provider.initialize);

    for (final platform in <TargetPlatform>[
      TargetPlatform.android,
      TargetPlatform.iOS,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      await tester.pumpWidget(
        _cloudSyncTestApp(
          fixture.provider,
          contentKey: ValueKey<TargetPlatform>(platform),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('cloud-sync-register-mode')),
        findsOneWidget,
      );
    }

    for (final platform in <TargetPlatform>[
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      await tester.pumpWidget(
        _cloudSyncTestApp(
          fixture.provider,
          contentKey: ValueKey<TargetPlatform>(platform),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('cloud-sync-register-mode')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('cloud-sync-display-name-field')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('cloud-sync-authentication-submit')),
        findsOneWidget,
      );
      expect(find.text('登录'), findsWidgets);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('桌面登录表单仍提交登录参数', (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    _setCloudSyncPackageInfo();
    final fixture = await tester.runAsync(_createSignedOutFixture);
    if (fixture == null) {
      throw StateError('sign_in_ui_fixture_not_created');
    }
    addTearDown(() => tester.runAsync(fixture.close));
    await tester.runAsync(fixture.provider.initialize);
    await tester.pumpWidget(_cloudSyncTestApp(fixture.provider));
    await tester.pump();

    await _enterCloudSyncField(tester, 'cloud-sync-login-name-field', ' ovo ');
    await _enterCloudSyncField(tester, 'cloud-sync-password-field', 'password');
    await _enterCloudSyncField(
      tester,
      'cloud-sync-device-name-field',
      ' Windows 电脑 ',
    );
    final submit = find.byKey(
      const ValueKey<String>('cloud-sync-authentication-submit'),
    );
    expect(tester.widget<IosTileButton>(submit).enabled, isTrue);
    await tester.tap(submit);
    await _pumpCloudSyncUntil(
      tester,
      () => fixture.authentication.requestNames.contains('login'),
    );
    await _pumpCloudSyncUntil(
      tester,
      () => fixture.provider.workspaceRestartRequired,
    );

    expect(fixture.authentication.requestNames.first, 'login');
    expect(fixture.authentication.lastLoginName, 'ovo');
    expect(fixture.authentication.lastPassword, 'password');
    expect(fixture.authentication.lastDeviceName, 'Windows 电脑');
    expect(fixture.authentication.lastPlatform, CloudSyncPlatform.windows);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('移动注册提交参数且请求期间禁止重复提交', (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    _setCloudSyncPackageInfo();
    final registrationBarrier = Completer<void>();
    addTearDown(() {
      if (!registrationBarrier.isCompleted) registrationBarrier.complete();
    });
    final authentication = _FakeE2eeAccountAuthentication(
      registrationBarrier: registrationBarrier.future,
    );
    final fixture = await tester.runAsync(
      () => _createSignedOutFixture(authentication: authentication),
    );
    if (fixture == null) throw StateError('register_ui_fixture_not_created');
    addTearDown(() => tester.runAsync(fixture.close));
    await tester.runAsync(fixture.provider.initialize);
    await tester.pumpWidget(_cloudSyncTestApp(fixture.provider));
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('cloud-sync-register-mode')),
    );
    await tester.pump();
    await _enterCloudSyncField(tester, 'cloud-sync-login-name-field', ' ovo ');
    await _enterCloudSyncField(
      tester,
      'cloud-sync-display-name-field',
      ' Ovo 用户 ',
    );
    await _enterCloudSyncField(tester, 'cloud-sync-password-field', 'password');
    await _enterCloudSyncField(
      tester,
      'cloud-sync-device-name-field',
      ' 安卓手机 ',
    );
    final submit = find.byKey(
      const ValueKey<String>('cloud-sync-authentication-submit'),
    );
    await tester.tap(submit);
    await _pumpCloudSyncUntil(
      tester,
      () => authentication.requestNames.contains('register'),
    );
    await tester.pump();

    expect(tester.widget<IosTileButton>(submit).enabled, isFalse);
    await tester.tap(submit);
    await tester.pump();
    expect(
      authentication.requestNames.where((name) => name == 'register'),
      hasLength(1),
    );

    registrationBarrier.complete();
    await _pumpCloudSyncUntil(
      tester,
      () => fixture.provider.workspaceRestartRequired,
    );
    expect(authentication.lastLoginName, 'ovo');
    expect(authentication.lastDisplayName, 'Ovo 用户');
    expect(authentication.lastPassword, 'password');
    expect(authentication.lastDeviceName, '安卓手机');
    expect(authentication.lastPlatform, CloudSyncPlatform.android);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('移动注册失败保持登出并展示账户错误', (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    _setCloudSyncPackageInfo();
    final authentication = _FakeE2eeAccountAuthentication(
      registrationFailure: const CloudSyncException(
        kind: CloudSyncFailureKind.conflict,
        retryable: false,
        serverCode: 'AUTH_REGISTRATION_CONFLICT',
      ),
    );
    final fixture = await tester.runAsync(
      () => _createSignedOutFixture(authentication: authentication),
    );
    if (fixture == null) {
      throw StateError('register_failure_ui_fixture_not_created');
    }
    addTearDown(() => tester.runAsync(fixture.close));
    await tester.runAsync(fixture.provider.initialize);
    await tester.pumpWidget(_cloudSyncTestApp(fixture.provider));
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('cloud-sync-register-mode')),
    );
    await tester.pump();
    await _enterCloudSyncField(tester, 'cloud-sync-login-name-field', 'ovo');
    await _enterCloudSyncField(tester, 'cloud-sync-display-name-field', 'Ovo');
    await _enterCloudSyncField(tester, 'cloud-sync-password-field', 'password');
    await _enterCloudSyncField(
      tester,
      'cloud-sync-device-name-field',
      'iPhone',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('cloud-sync-authentication-submit')),
    );
    await _pumpCloudSyncUntil(tester, () => fixture.provider.lastError != null);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(fixture.provider.status, CloudSyncProviderStatus.signedOut);
    expect(fixture.provider.signedIn, isFalse);
    expect(
      fixture.provider.lastError?.serverCode,
      'AUTH_REGISTRATION_CONFLICT',
    );
    expect(find.text('数据已在其他设备发生变化，请重新同步。'), findsWidgets);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('待批准登录显示二进制二维码且页面退出时取消配对', (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    final pairing = _FakeE2eeDevicePairingSession();
    final fixture = await tester.runAsync(
      () => _createSignedOutFixture(
        authentication: _FakeE2eeAccountAuthentication(
          loginResult: approval,
          pairingSession: pairing,
        ),
      ),
    );
    if (fixture == null) {
      throw StateError('pairing_ui_fixture_not_created');
    }
    addTearDown(() => tester.runAsync(fixture.close));
    await tester.runAsync(
      () => fixture.provider.login(
        loginName: 'ovo',
        password: 'password',
        deviceName: '测试电脑',
      ),
    );

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

    expect(find.text('设备批准'), findsOneWidget);
    expect(find.text('等待可信设备批准'), findsOneWidget);
    expect(find.byType(PrettyQrView), findsOneWidget);
    expect(pairing.waitCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => _waitUntil(() => pairing.cancelCalls == 1));
    expect(fixture.provider.pendingDeviceApproval, isNull);
  });

  test('E2EE 内容运行时离线初始化不阻塞且关闭等待网络周期后释放所有权', () async {
    final harness = await _E2eeRuntimeHarness.create();
    addTearDown(harness.close);
    final first = harness.createInstance(blockInitialPull: true);

    await first.runtime.initialize().timeout(const Duration(seconds: 15));
    await _waitUntil(() => first.pull.pullCalls == 1);
    expect(first.runtime.state, E2eeChatContentRuntimeState.ready);
    expect(
      first.transportSession?.deviceKeyVersion,
      harness.session.deviceKeyVersion,
    );

    var closed = false;
    final closeFuture = first.runtime.close().then((_) => closed = true);
    await Future<void>.delayed(Duration.zero);
    expect(closed, isFalse);

    first.pull.failBlockedPull();
    await closeFuture;
    expect(first.runtime.state, E2eeChatContentRuntimeState.closed);

    final reopened = harness.createInstance();
    await reopened.runtime.initialize().timeout(const Duration(seconds: 15));
    await _waitUntil(() => reopened.pull.pullCalls >= 2);
    expect(reopened.runtime.state, E2eeChatContentRuntimeState.ready);
    await reopened.runtime.close();
  });

  test('E2EE 内容运行时仅将不可重试的认证拒绝归类为终止认证', () async {
    final harness = await _E2eeRuntimeHarness.create();
    addTearDown(harness.close);

    for (final kind in <CloudSyncFailureKind>[
      CloudSyncFailureKind.unauthenticated,
      CloudSyncFailureKind.forbidden,
    ]) {
      final instance = harness.createInstance(
        pullFailure: CloudSyncException(kind: kind, retryable: false),
      );
      final terminalFailure = Completer<CloudSyncException>();
      instance.runtime.bindTerminalAuthenticationHandler((failure, _) async {
        terminalFailure.complete(failure);
      });

      await instance.runtime.initialize().timeout(const Duration(seconds: 15));
      expect(
        (await terminalFailure.future.timeout(const Duration(seconds: 5))).kind,
        kind,
      );
      expect(instance.pull.pullCalls, 1);
      await instance.runtime.close();
    }
  });

  test('E2EE 内容运行时遇到普通网络错误时继续退避重试', () async {
    final harness = await _E2eeRuntimeHarness.create();
    addTearDown(harness.close);
    final instance = harness.createInstance(
      pullFailure: const CloudSyncException(
        kind: CloudSyncFailureKind.network,
        retryable: true,
      ),
    );
    var terminalNotifications = 0;
    instance.runtime.bindTerminalAuthenticationHandler((failure, _) async {
      terminalNotifications++;
    });

    await instance.runtime.initialize().timeout(const Duration(seconds: 15));
    await _waitUntil(() => instance.pull.pullCalls >= 2);

    expect(terminalNotifications, 0);
    expect(instance.runtime.state, E2eeChatContentRuntimeState.ready);
    await instance.runtime.close();
  });

  test('E2EE 内容运行时在本地事务提交后唤醒密文发送周期', () async {
    final harness = await _E2eeRuntimeHarness.create();
    addTearDown(harness.close);
    final instance = harness.createInstance();
    await instance.runtime.initialize().timeout(const Duration(seconds: 15));
    await _waitUntil(() => instance.pull.pullCalls >= 2);
    final pullsBeforeWrite = instance.pull.pullCalls;

    await instance.chatService.createConversation(title: '本地事务');

    await _waitUntil(() => instance.records.pushCalls == 1);
    await _waitUntil(() => instance.pull.pullCalls >= pullsBeforeWrite + 2);
    expect(instance.records.mutationCount, 1);
    expect(
      instance.transportSession?.deviceKeyVersion,
      harness.session.deviceKeyVersion,
    );
    await instance.runtime.close();
  });

  test('E2EE 内容运行时缺少本机密钥状态时失败关闭且不启动网络', () async {
    final harness = await _E2eeRuntimeHarness.create(seedDeviceState: false);
    addTearDown(harness.close);
    final instance = harness.createInstance();

    await expectLater(instance.runtime.initialize(), throwsStateError);

    expect(instance.runtime.state, E2eeChatContentRuntimeState.failed);
    expect(instance.pull.pullCalls, 0);
    expect(instance.transportSession, isNull);
    await instance.runtime.close();
    expect(instance.runtime.state, E2eeChatContentRuntimeState.closed);
  });

  test('E2EE 配置桥接从 Vault 水合且事务失败后恢复 Provider', () async {
    final harness = await _E2eeConfigBindingHarness.create(
      initialProfileName: 'Vault 用户',
    );
    addTearDown(harness.close);

    expect(harness.providers.user.name, 'Vault 用户');

    await expectLater(
      harness.binding.runLocalWrite<void>(
        configKeys: const <SyncEntityKey>[ConfigSyncKeys.profile],
        transaction: (trackedWrite) {
          return harness.repository.runInTransaction<void>(() async {
            await trackedWrite();
            throw StateError('模拟事务提交失败');
          });
        },
        write: () => harness.providers.user.setName('未提交用户'),
      ),
      throwsStateError,
    );

    expect(harness.providers.user.name, 'Vault 用户');
    expect(await harness.readProfileName(), 'Vault 用户');
  });

  test('E2EE 配置远端事务提交后刷新 Provider 且不产生本地 outbox', () async {
    final harness = await _E2eeConfigBindingHarness.create(
      initialProfileName: '旧用户',
    );
    addTearDown(harness.close);
    final change = await harness.profileChange('远端用户');

    await harness.binding.runRemotePull(
      () => harness.repository.runInTransaction<void>(
        () =>
            harness.binding.applyTransactional(<E2eeSyncPulledChange>[change]),
      ),
    );

    expect(harness.providers.user.name, '远端用户');
    expect(await harness.readProfileName(), '远端用户');
    final outbox = await harness.repository.acquireE2eeSyncOutboxCommands(
      now: DateTime.utc(2026, 7, 29),
    );
    expect(await outbox.listDirtyIntents(limit: 10), isEmpty);
  });

  test('E2EE 生产运行时配置写入与 outbox 原子提交并触发发送', () async {
    final harness = await _E2eeRuntimeHarness.create();
    addTearDown(harness.close);
    final instance = harness.createInstance(withConfigProviders: true);
    await instance.runtime.initialize().timeout(const Duration(seconds: 15));
    await _waitUntil(() => instance.pull.pullCalls >= 2);

    await instance.configProviders!.user.setName('配置事务用户');

    await _waitUntil(() => instance.records.pushCalls == 1);
    expect(instance.records.mutationCount, 1);
    await instance.runtime.close();
  });
}

Widget _cloudSyncTestApp(CloudSyncProvider provider, {Key? contentKey}) {
  return ChangeNotifierProvider<CloudSyncProvider>.value(
    value: provider,
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: CloudSyncSettingsContent(key: contentKey)),
    ),
  );
}

Future<void> _enterCloudSyncField(
  WidgetTester tester,
  String key,
  String value,
) async {
  final field = find.descendant(
    of: find.byKey(ValueKey<String>(key)),
    matching: find.byType(EditableText),
  );
  expect(field, findsOneWidget);
  await tester.enterText(field, value);
}

Future<void> _pumpCloudSyncUntil(
  WidgetTester tester,
  bool Function() condition,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  fail('等待云同步页面状态收敛超时');
}

void _setCloudSyncPackageInfo() {
  PackageInfo.setMockInitialValues(
    appName: 'Kelivo',
    packageName: 'Kelivo',
    version: '1.1.17',
    buildNumber: '1',
    buildSignature: 'test',
  );
}

Future<_Fixture> _createSignedInFixture({
  _FakeCloudSyncAccountClient? client,
  _FakeE2eeAccountAuthentication? authentication,
  CloudSyncAccountSession? session,
  CloudSyncContentRuntime? contentRuntime,
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
  final provider = contentRuntime == null
      ? CloudSyncProvider.controlPlaneOnly(
          runtime,
          clientFactory: ({CloudSyncFullSessionToken? token}) {
            accountClient.setToken(token);
            return accountClient;
          },
          authenticationFactory: (_) => accountAuthentication,
        )
      : CloudSyncProvider.withContentRuntime(
          runtime,
          contentRuntime: contentRuntime,
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
    deviceKeyVersion: 1,
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
    deviceKeyVersion: 1,
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

final class _E2eeConfigBindingHarness {
  const _E2eeConfigBindingHarness._({
    required this.directory,
    required this.repository,
    required this.providers,
    required this.binding,
  });

  final Directory directory;
  final ChatDatabaseRepository repository;
  final _TestConfigProviders providers;
  final E2eeConfigProviderBinding binding;

  static Future<_E2eeConfigBindingHarness> create({
    required String initialProfileName,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final directory = await Directory.systemTemp.createTemp(
      'kelivo_config_binding_',
    );
    final database = AppDatabase.open(
      file: File(
        '${directory.path}${Platform.pathSeparator}config-binding.sqlite',
      ),
      cipher: testDatabaseCipher,
    );
    await database.customSelect('SELECT 1;').getSingle();
    final repository = ChatDatabaseRepository(
      database,
      databaseCipher: testDatabaseCipher,
    );
    try {
      final providers = _TestConfigProviders.create(
        const _VaultPassThroughWriteExecutor(),
      );
      final binding = providers.createBinding();
      final encoded = E2eeSyncPayloadCodec.encode(
        entityKey: ConfigSyncKeys.profile,
        payload: _profilePayload(initialProfileName),
      );
      try {
        await repository.e2eeConfigVaultCommands.put(
          key: ConfigSyncKeys.profile,
          payload: encoded,
          updatedAt: DateTime.utc(2026, 7, 29),
        );
      } finally {
        encoded.fillRange(0, encoded.length, 0);
      }
      await binding.initialize(repository.e2eeConfigVaultCommands);
      return _E2eeConfigBindingHarness._(
        directory: directory,
        repository: repository,
        providers: providers,
        binding: binding,
      );
    } catch (_) {
      await repository.close();
      if (await directory.exists()) await directory.delete(recursive: true);
      rethrow;
    }
  }

  Future<String> readProfileName() async {
    final entry = await repository.e2eeConfigVaultCommands.read(
      ConfigSyncKeys.profile,
    );
    if (entry == null) throw StateError('测试配置 Vault 缺少用户资料');
    return E2eeSyncPayloadCodec.decode(
          entityKey: entry.key,
          bytes: entry.payload,
        )['name']
        as String;
  }

  Future<E2eeSyncPulledValueChange> profileChange(String name) async {
    const secureCore = KelivoSecureCore();
    final codec = E2eeAccountRecordStateCodec.takeOwnership(
      E2eeAccountRecordCipher.takeOwnership(
        secureCore: secureCore,
        accountRootKey: await secureCore.generateAccountRootKey(keyEpoch: 1),
        userId: _userId,
        currentKeyEpoch: 1,
      ),
    );
    try {
      final sealed = await codec.sealValue(
        entityKey: ConfigSyncKeys.profile,
        logicalVersion: 1,
        parentDigests: const <E2eeAccountRecordStateDigest>[],
        operationId: '50000000-0000-4000-8000-000000000001',
        claimedWriterDeviceId: _otherDeviceId,
        claimedWriterKeyVersion: 1,
        payload: Uint8List.fromList(<int>[1]),
      );
      final authenticated = await codec.open(
        E2eeUntrustedAccountRecordEnvelope.fromTransport(
          recordId: E2eeUntrustedAccountRecordId.fromTransport(
            sealed.record.recordId.wireValue,
          ),
          envelopeVersion: e2eeAccountRecordEnvelopeVersion,
          keyEpoch: sealed.record.keyEpoch,
          ciphertext: sealed.record.ciphertext,
        ),
        decode: (state, _) => state,
      );
      return E2eeSyncPulledValueChange(
        untrustedServerMetadata: E2eeSyncUntrustedServerMetadata(
          changeSeq: 1,
          revision: 1,
        ),
        state: authenticated,
        payload: _profilePayload(name),
      );
    } finally {
      await codec.close();
    }
  }

  Future<void> close() async {
    providers.dispose();
    await repository.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

Map<String, Object?> _profilePayload(String name) => <String, Object?>{
  'name': name,
  'avatarType': null,
  'avatarValue': null,
};

final class _TestConfigProviders {
  const _TestConfigProviders._({
    required this.settings,
    required this.assistants,
    required this.memories,
    required this.mcp,
    required this.quickPhrases,
    required this.injections,
    required this.worldBooks,
    required this.user,
  });

  final SettingsProvider settings;
  final AssistantProvider assistants;
  final MemoryProvider memories;
  final McpProvider mcp;
  final QuickPhraseProvider quickPhrases;
  final InstructionInjectionProvider injections;
  final WorldBookProvider worldBooks;
  final UserProvider user;

  factory _TestConfigProviders.create(
    SyncWriteExecutor executor, {
    ChatService? chatService,
  }) {
    return _TestConfigProviders._(
      settings: SettingsProvider(syncWriteExecutor: executor),
      assistants: AssistantProvider(
        chatService: chatService,
        syncWriteExecutor: executor,
      ),
      memories: MemoryProvider(syncWriteExecutor: executor),
      mcp: McpProvider(syncWriteExecutor: executor),
      quickPhrases: QuickPhraseProvider(syncWriteExecutor: executor),
      injections: InstructionInjectionProvider(syncWriteExecutor: executor),
      worldBooks: WorldBookProvider(syncWriteExecutor: executor),
      user: UserProvider(syncWriteExecutor: executor),
    );
  }

  E2eeConfigProviderBinding createBinding() {
    return E2eeConfigProviderBinding(
      settingsProvider: settings,
      assistantProvider: assistants,
      memoryProvider: memories,
      mcpProvider: mcp,
      quickPhraseProvider: quickPhrases,
      instructionInjectionProvider: injections,
      worldBookProvider: worldBooks,
      userProvider: user,
    );
  }

  void dispose() {
    settings.dispose();
    assistants.dispose();
    memories.dispose();
    mcp.dispose();
    quickPhrases.dispose();
    injections.dispose();
    worldBooks.dispose();
    user.dispose();
  }
}

final class _VaultPassThroughWriteExecutor
    implements E2eeConfigVaultWriteExecutor {
  const _VaultPassThroughWriteExecutor();

  @override
  Future<T> runLocal<T>({
    required SyncEntityKey key,
    required Future<T> Function() write,
  }) {
    return Future<T>.sync(write);
  }

  @override
  Future<T> runLocalBatch<T>({
    required Iterable<SyncEntityKey> keys,
    required Future<T> Function() write,
  }) {
    return Future<T>.sync(write);
  }
}

final class _E2eeRuntimeHarness {
  _E2eeRuntimeHarness._({
    required this.root,
    required this.session,
    required this._deviceStateStore,
    required this._databaseGateway,
    required this._databaseFile,
  });

  final Directory root;
  final CloudSyncAccountSession session;
  final DeviceStateBlobStore _deviceStateStore;
  final ChatDatabaseGateway _databaseGateway;
  final File _databaseFile;
  final List<_E2eeRuntimeInstance> _instances = <_E2eeRuntimeInstance>[];

  static Future<_E2eeRuntimeHarness> create({
    bool seedDeviceState = true,
  }) async {
    final testRoot = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}content_runtime_tests',
    );
    await testRoot.create(recursive: true);
    final root = await testRoot.createTemp('runtime-');
    final installationRoot = Directory(
      '${root.path}${Platform.pathSeparator}installation',
    );
    final workspaceRoot = Directory(
      '${root.path}${Platform.pathSeparator}workspace',
    );
    await installationRoot.create(recursive: true);
    await workspaceRoot.create(recursive: true);
    AppDirectories.bindWorkspaceRoot(
      workspaceRoot,
      installationRoot: installationRoot,
      accountWorkspace: true,
    );
    await SandboxPathResolver.init();

    final nonce = sha256
        .convert(utf8.encode(root.path))
        .toString()
        .substring(0, 16);
    final session = CloudSyncAccountSession(
      baseUrl: 'https://runtime-$nonce.example.com',
      token: _fullToken,
      tokenExpiresAt: DateTime.utc(2100),
      keyEpoch: 1,
      userId: _userId,
      loginName: 'runtime-$nonce',
      displayName: 'Runtime User',
      role: CloudSyncUserRole.user,
      attachmentQuotaBytes: maximumCloudSyncAttachmentSizeBytes,
      deviceId: _deviceId,
      deviceName: 'Runtime Device',
      platform: CloudSyncPlatform.windows,
      clientVersion: '1.1.17',
      deviceKeyVersion: 1,
      deviceCreatedAt: DateTime.utc(2026, 7, 29),
    );
    const secureCore = KelivoSecureCore();
    final deviceStateStore = DeviceStateBlobStore(
      installationRoot: installationRoot,
    );
    if (seedDeviceState) {
      await _seedRuntimeDeviceState(
        secureCore: secureCore,
        store: deviceStateStore,
        session: session,
      );
    }
    return _E2eeRuntimeHarness._(
      root: root,
      session: session,
      deviceStateStore: deviceStateStore,
      databaseGateway: ChatDatabaseGateway(cipher: testDatabaseCipher),
      databaseFile: File(
        '${workspaceRoot.path}${Platform.pathSeparator}'
        '${AppDatabase.databaseFileName}',
      ),
    );
  }

  _E2eeRuntimeInstance createInstance({
    bool blockInitialPull = false,
    bool withConfigProviders = true,
    CloudSyncException? pullFailure,
  }) {
    final pull = _RuntimePullTransport(
      accountUserId: session.userId,
      blockInitialPull: blockInitialPull,
      failure: pullFailure,
    );
    final records = _RuntimeRecordTransport(
      accountUserId: session.userId,
      actorDeviceId: session.deviceId,
    );
    final capture = _TransportSessionCapture();
    E2eeChatContentTransports createTransports({
      required CloudSyncClient client,
      required CloudSyncAuthenticatedSession session,
    }) {
      capture.session = session;
      return E2eeChatContentTransports(records: records, pull: pull);
    }

    final runtime = E2eeChatContentRuntime.takeOwnership(
      session: session,
      deviceStateStore: _deviceStateStore,
      secureCore: const KelivoSecureCore(),
      databaseGateway: _databaseGateway,
      databaseFile: _databaseFile,
      client: CloudSyncClient.forTesting(baseUrl: session.baseUrl),
      transportFactory: createTransports,
    );
    final chatService = ChatService(runtime, databaseGateway: _databaseGateway);
    runtime.bindChatService(chatService);
    _TestConfigProviders? configProviders;
    if (withConfigProviders) {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      configProviders = _TestConfigProviders.create(
        runtime,
        chatService: chatService,
      );
      runtime.bindConfigProviders(configProviders.createBinding());
    }
    final instance = _E2eeRuntimeInstance(
      runtime: runtime,
      chatService: chatService,
      configProviders: configProviders,
      pull: pull,
      records: records,
      capture: capture,
    );
    _instances.add(instance);
    return instance;
  }

  Future<void> close() async {
    for (final instance in _instances.reversed) {
      instance.pull.failBlockedPull();
      await instance.runtime.close();
      instance.chatService.dispose();
      instance.configProviders?.dispose();
    }
    _instances.clear();
    if (await root.exists()) await root.delete(recursive: true);
  }
}

final class _E2eeRuntimeInstance {
  const _E2eeRuntimeInstance({
    required this.runtime,
    required this.chatService,
    required this.configProviders,
    required this.pull,
    required this.records,
    required this._capture,
  });

  final E2eeChatContentRuntime runtime;
  final ChatService chatService;
  final _TestConfigProviders? configProviders;
  final _RuntimePullTransport pull;
  final _RuntimeRecordTransport records;
  final _TransportSessionCapture _capture;

  CloudSyncAuthenticatedSession? get transportSession => _capture.session;
}

final class _TransportSessionCapture {
  CloudSyncAuthenticatedSession? session;
}

final class _RuntimePullTransport
    implements E2eeSyncAuthenticatedPullTransport {
  _RuntimePullTransport({
    required this.accountUserId,
    required bool blockInitialPull,
    this.failure,
  }) : _blockedPull = blockInitialPull ? Completer<void>() : null;

  @override
  final String accountUserId;
  final Completer<void>? _blockedPull;
  final CloudSyncException? failure;
  int pullCalls = 0;

  @override
  Future<CloudSyncPullResult> pullChanges({
    String? cursor,
    int limit = 10,
  }) async {
    pullCalls++;
    if (pullCalls == 1 && _blockedPull != null) {
      await _blockedPull.future;
    }
    final pullFailure = failure;
    if (pullFailure != null) throw pullFailure;
    return CloudSyncChangePage(
      changes: const <CloudSyncRecordChange>[],
      nextCursor: 'runtime-cursor-$pullCalls',
      hasMore: false,
    );
  }

  @override
  Future<CloudSyncSnapshotPage> pullSnapshot({
    String? snapshotCursor,
    int limit = 10,
  }) {
    throw StateError('runtime_snapshot_not_expected');
  }

  void failBlockedPull() {
    final blockedPull = _blockedPull;
    if (blockedPull == null || blockedPull.isCompleted) return;
    blockedPull.completeError(
      const CloudSyncException(
        kind: CloudSyncFailureKind.network,
        retryable: true,
      ),
    );
  }
}

final class _RuntimeRecordTransport
    implements E2eeSyncAuthenticatedRecordTransport {
  _RuntimeRecordTransport({
    required this.accountUserId,
    required this.actorDeviceId,
  });

  @override
  final String accountUserId;
  @override
  final String actorDeviceId;
  int pushCalls = 0;
  int mutationCount = 0;
  int _changeSequence = 0;

  @override
  Future<List<CloudSyncRecordMutationResult>> pushRecords(
    List<CloudSyncRecordMutation> mutations,
  ) async {
    pushCalls++;
    mutationCount += mutations.length;
    return <CloudSyncRecordMutationResult>[
      for (final mutation in mutations)
        CloudSyncAppliedMutationResult(
          mutationId: mutation.mutationId,
          revision: mutation.expectedRevision + 1,
          changeSeq: ++_changeSequence,
        ),
    ];
  }
}

Future<void> _seedRuntimeDeviceState({
  required KelivoSecureCore secureCore,
  required DeviceStateBlobStore store,
  required CloudSyncAccountSession session,
}) async {
  final key = await secureCore.createSlot(
    E2eeDeviceStateAccess.deriveSlotId(
      normalizedBaseUrl: session.baseUrl,
      normalizedLoginName: session.loginName,
    ),
  );
  final identity = await secureCore.generateDeviceIdentity();
  final ark = await secureCore.generateAccountRootKey(
    keyEpoch: session.keyEpoch,
  );
  Uint8List? blob;
  try {
    blob = Uint8List.fromList(
      await secureCore.sealDeviceState(
        key,
        identity,
        deviceId: _runtimeUuidBytes(session.deviceId),
        keyVersion: session.deviceKeyVersion,
        ark: ark,
        account: KelivoDeviceStateAccountBinding(
          userId: _runtimeUuidBytes(session.userId),
          keyEpoch: session.keyEpoch,
        ),
      ),
    );
    await store.write(
      normalizedBaseUrl: session.baseUrl,
      normalizedLoginName: session.loginName,
      blob: blob,
    );
  } finally {
    final sealedBlob = blob;
    if (sealedBlob != null) sealedBlob.fillRange(0, sealedBlob.length, 0);
    await secureCore.closeAccountRootKey(ark);
    await secureCore.closeDeviceIdentity(identity);
    await secureCore.close(key);
  }
}

Uint8List _runtimeUuidBytes(String value) {
  final hex = value.replaceAll('-', '');
  return Uint8List.fromList(<int>[
    for (var offset = 0; offset < hex.length; offset += 2)
      int.parse(hex.substring(offset, offset + 2), radix: 16),
  ]);
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

final class _FakeCloudSyncContentRuntime implements CloudSyncContentRuntime {
  _FakeCloudSyncContentRuntime({this.initializeFailure, this.closeFailure});

  final Object? initializeFailure;
  final Object? closeFailure;
  int initializeCalls = 0;
  int closeCalls = 0;
  CloudSyncTerminalAuthenticationHandler? _terminalAuthenticationHandler;

  CloudSyncTerminalAuthenticationHandler get terminalAuthenticationHandler {
    final handler = _terminalAuthenticationHandler;
    if (handler == null) {
      throw StateError('terminal_authentication_handler_not_bound');
    }
    return handler;
  }

  @override
  void bindTerminalAuthenticationHandler(
    CloudSyncTerminalAuthenticationHandler handler,
  ) {
    if (_terminalAuthenticationHandler != null) {
      throw StateError('terminal_authentication_handler_already_bound');
    }
    _terminalAuthenticationHandler = handler;
  }

  Future<void> triggerTerminalAuthentication(CloudSyncException failure) {
    return terminalAuthenticationHandler(failure, StackTrace.current);
  }

  @override
  Future<void> initialize() async {
    initializeCalls++;
    final failure = initializeFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> close() async {
    closeCalls++;
    final failure = closeFailure;
    if (failure != null) throw failure;
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
    _FakeE2eeDevicePairingSession? pairingSession,
    this.loginFailure,
    this.registrationFailure,
    this.confirmationFailure,
    this.registrationBarrier,
  }) : loginResult =
           loginResult ??
           E2eeAccountLoginAuthenticated(_authenticatedSession()),
       registrationSession = registrationSession ?? _authenticatedSession(),
       pairingSession = pairingSession ?? _FakeE2eeDevicePairingSession();

  final E2eeAccountLoginResult loginResult;
  final CloudSyncAuthenticatedSession registrationSession;
  final _FakeE2eeDevicePairingSession pairingSession;
  final Object? loginFailure;
  final Object? registrationFailure;
  final Object? confirmationFailure;
  final Future<void>? registrationBarrier;
  final List<String> requestNames = <String>[];
  String? lastLoginName;
  String? lastDisplayName;
  String? lastPassword;
  String? lastDeviceName;
  CloudSyncPlatform? lastPlatform;
  String? lastClientVersion;
  List<int>? lastPairingQrFrame;

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
      final barrier = registrationBarrier;
      if (barrier != null) await barrier;
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

  @override
  Future<E2eeDevicePairingSession> startDevicePairing(
    E2eeAccountLoginApprovalRequired approval,
  ) async {
    requestNames.add('start-pairing');
    return pairingSession;
  }

  @override
  Future<void> confirmDevicePairing({
    required String loginName,
    required CloudSyncAuthenticatedSession session,
  }) async {
    requestNames.add('confirm-pairing');
    lastLoginName = loginName;
  }

  @override
  Future<CloudSyncDevicePairingApproval> approveScannedDevicePairing({
    required String loginName,
    required CloudSyncAuthenticatedSession session,
    required Uint8List qrFrame,
  }) async {
    requestNames.add('approve-pairing');
    lastLoginName = loginName;
    try {
      lastPairingQrFrame = List<int>.of(qrFrame);
      return CloudSyncDevicePairingApproval(
        pairingId: _otherDeviceId,
        approvedAt: DateTime.utc(2026, 7, 26),
      );
    } finally {
      qrFrame.fillRange(0, qrFrame.length, 0);
    }
  }
}

final class _FakeE2eeDevicePairingSession implements E2eeDevicePairingSession {
  _FakeE2eeDevicePairingSession()
    : expectedQrFrame = Uint8List.fromList(<int>[1, 3, 3, 7]);

  final Uint8List expectedQrFrame;
  final Completer<CloudSyncAuthenticatedSession> _completion =
      Completer<CloudSyncAuthenticatedSession>();
  bool _qrFrameTaken = false;
  int waitCalls = 0;
  int cancelCalls = 0;

  @override
  DateTime get expiresAt => DateTime.utc(2100);

  @override
  Uint8List takeQrFrame({required DateTime now}) {
    if (_qrFrameTaken) throw StateError('qr_frame_taken');
    _qrFrameTaken = true;
    return Uint8List.fromList(expectedQrFrame);
  }

  @override
  Future<CloudSyncAuthenticatedSession> wait() {
    waitCalls++;
    return _completion.future;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    if (!_completion.isCompleted) {
      _completion.completeError(
        const CloudSyncException(
          kind: CloudSyncFailureKind.cancelled,
          retryable: false,
          serverCode: 'SYNC_DEVICE_PAIRING_CANCELLED',
        ),
      );
    }
  }

  void approve(CloudSyncAuthenticatedSession session) {
    _completion.complete(session);
  }

  void fail(Object error) {
    _completion.completeError(error);
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

final class _ManualTimerQueue {
  final List<_ManualTimer> _timers = <_ManualTimer>[];

  Duration? get nextDelay {
    for (final timer in _timers) {
      if (timer.isActive) return timer.delay;
    }
    return null;
  }

  Timer create(Duration delay, void Function() callback) {
    final timer = _ManualTimer(delay, callback);
    _timers.add(timer);
    return timer;
  }

  void fireNext() {
    for (final timer in _timers) {
      if (!timer.isActive) continue;
      timer.fire();
      return;
    }
    fail('没有可触发的 E2EE 同步定时器');
  }
}

final class _ManualTimer implements Timer {
  _ManualTimer(this.delay, this._callback);

  final Duration delay;
  final void Function() _callback;
  bool _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : 1;

  @override
  void cancel() {
    _active = false;
  }

  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }
}

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('等待异步状态收敛超时');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
