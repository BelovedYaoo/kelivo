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
import 'package:Kelivo/core/services/sync/cloud_sync_terminal_session_retirement.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/sync/config_sync_keys.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_authenticator.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_record_cipher.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_record_state.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_trust_manifest.dart';
import 'package:Kelivo/core/services/sync/e2ee_background_sync_runner.dart';
import 'package:Kelivo/core/services/sync/e2ee_chat_content_runtime.dart';
import 'package:Kelivo/core/services/sync/e2ee_config_provider_binding.dart';
import 'package:Kelivo/core/services/sync/e2ee_device_state_access.dart';
import 'package:Kelivo/core/services/sync/e2ee_mobile_background_sync.dart';
import 'package:Kelivo/core/services/sync/e2ee_sync_outbox.dart';
import 'package:Kelivo/core/services/sync/e2ee_sync_execution_budget.dart';
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

  test('E2EE 后台同步无持久会话时不打开内容运行时并释放工作区', () async {
    final events = <String>[];
    final workspace = _FakeBackgroundWorkspace(
      events: events,
      session: null,
      contentAcquisition: const E2eeBackgroundContentBusy(),
    );
    final runner = E2eeBackgroundSyncRunner.forTesting(
      _FixedBackgroundHost(E2eeBackgroundWorkspaceAcquired(workspace)),
    );

    final outcome = await runner.run();

    expect(outcome.disposition, E2eeBackgroundSyncDisposition.noSession);
    expect(workspace.contentAcquisitionCalls, 0);
    expect(events, <String>['workspace-close']);
  });

  test('E2EE 后台同步结束后解除永不触发的取消监听', () async {
    final cancellation = _TrackedSyncCancellationSignal();
    final runner = E2eeBackgroundSyncRunner.forTesting(
      const _FixedBackgroundHost(E2eeBackgroundWorkspaceBusy()),
    );

    final outcome = await runner.run(cancellationSignal: cancellation);

    expect(outcome.disposition, E2eeBackgroundSyncDisposition.workspaceBusy);
    expect(cancellation.registrationCount, 1);
    expect(cancellation.unregistrationCount, 1);
    expect(cancellation.activeListenerCount, 0);
  });

  test('E2EE 后台同步在前台持有租约时不打开 SQLCipher 或网络', () async {
    final runner = E2eeBackgroundSyncRunner.forTesting(
      const _FixedBackgroundHost(E2eeBackgroundWorkspaceBusy()),
    );

    final outcome = await runner.run();

    expect(outcome.disposition, E2eeBackgroundSyncDisposition.workspaceBusy);
  });

  test('E2EE 后台同步入口已取消时抛给平台且不获取工作区', () async {
    final cancellation = _TrackedSyncCancellationSignal()..cancel();
    final host = _DelayedBackgroundHost(
      const E2eeBackgroundWorkspaceBusy(),
      Duration.zero,
    );

    await expectLater(
      E2eeBackgroundSyncRunner.forTesting(
        host,
      ).run(cancellationSignal: cancellation),
      throwsA(isA<E2eeSyncExecutionCancelled>()),
    );

    expect(host.acquisitionCalls, 0);
    expect(cancellation.activeListenerCount, 0);
  });

  test('E2EE 后台同步总截止覆盖工作区前置阶段并在开库前抛给平台', () async {
    final events = <String>[];
    final workspace = _FakeBackgroundWorkspace(
      events: events,
      session: _session(),
      contentAcquisition: const E2eeBackgroundContentBusy(),
    );
    final host = _DelayedBackgroundHost(
      E2eeBackgroundWorkspaceAcquired(workspace),
      const Duration(milliseconds: 40),
    );

    await expectLater(
      E2eeBackgroundSyncRunner.forTesting(host).run(
        limits: const E2eeBackgroundSyncLimits(
          maximumDuration: Duration(milliseconds: 10),
        ),
      ),
      throwsA(isA<E2eeSyncDeadlineExceeded>()),
    );

    expect(host.acquisitionCalls, 1);
    expect(workspace.contentAcquisitionCalls, 0);
    expect(events, <String>['workspace-close']);
  });

  test('E2EE 后台同步工作区获取永不完成时仍按总截止返回', () async {
    final pending = Completer<E2eeBackgroundWorkspaceAcquisition>();
    final host = _PendingBackgroundHost(pending.future);

    await expectLater(
      E2eeBackgroundSyncRunner.forTesting(host)
          .run(
            limits: const E2eeBackgroundSyncLimits(
              maximumDuration: Duration(milliseconds: 10),
              maximumShutdownDuration: Duration(milliseconds: 20),
            ),
          )
          .timeout(
            const Duration(milliseconds: 150),
            onTimeout: () => throw StateError(
              'e2ee_background_sync_runner_deadline_not_enforced',
            ),
          ),
      throwsA(isA<E2eeSyncDeadlineExceeded>()),
    );

    expect(host.acquisitionCalls, 1);
  });

  test('E2EE 后台同步工作区先结算但返回前截止时仍释放所有权', () async {
    final events = <String>[];
    final workspace = _FakeBackgroundWorkspace(
      events: events,
      session: _session(),
      contentAcquisition: const E2eeBackgroundContentBusy(),
    );
    final host = _BlockingBackgroundHost(
      E2eeBackgroundWorkspaceAcquired(workspace),
      const Duration(milliseconds: 20),
    );

    await expectLater(
      E2eeBackgroundSyncRunner.forTesting(host).run(
        limits: const E2eeBackgroundSyncLimits(
          maximumDuration: Duration(milliseconds: 5),
          maximumShutdownDuration: Duration(milliseconds: 20),
        ),
      ),
      throwsA(isA<E2eeSyncDeadlineExceeded>()),
    );

    expect(host.acquisitionCalls, 1);
    expect(workspace.contentAcquisitionCalls, 0);
    expect(events, <String>['workspace-close']);
  });

  test('E2EE 后台同步账户租约占用时释放工作区且不创建内容运行时', () async {
    final events = <String>[];
    final workspace = _FakeBackgroundWorkspace(
      events: events,
      session: _session(),
      contentAcquisition: const E2eeBackgroundContentBusy(),
    );
    final runner = E2eeBackgroundSyncRunner.forTesting(
      _FixedBackgroundHost(E2eeBackgroundWorkspaceAcquired(workspace)),
    );

    final outcome = await runner.run();

    expect(outcome.disposition, E2eeBackgroundSyncDisposition.workspaceBusy);
    expect(workspace.contentAcquisitionCalls, 1);
    expect(events, <String>['content-acquire', 'workspace-close']);
  });

  test('E2EE 后台同步迟到内容严格释放后才释放工作区且各一次', () async {
    final events = <String>[];
    final pending = Completer<E2eeBackgroundContentAcquisition>();
    final runtimeClose = Completer<void>();
    final content = _FakeBackgroundContent(
      events: events,
      run: (_) async =>
          _backgroundCycleReport(E2eeSyncCycleDisposition.completed),
      closeRuntimeBarrier: runtimeClose.future,
    );
    final workspace = _PendingContentBackgroundWorkspace(
      events: events,
      session: _session(),
      acquisition: pending.future,
    );

    await expectLater(
      E2eeBackgroundSyncRunner.forTesting(
            _FixedBackgroundHost(E2eeBackgroundWorkspaceAcquired(workspace)),
          )
          .run(
            limits: const E2eeBackgroundSyncLimits(
              maximumDuration: Duration(milliseconds: 10),
              maximumShutdownDuration: Duration(milliseconds: 20),
            ),
          )
          .timeout(
            const Duration(milliseconds: 150),
            onTimeout: () => throw StateError(
              'e2ee_background_sync_content_deadline_not_enforced',
            ),
          ),
      throwsA(isA<E2eeSyncDeadlineExceeded>()),
    );

    expect(events, <String>['content-acquire']);

    pending.complete(E2eeBackgroundContentAcquired(content));
    await _waitUntil(() => events.contains('runtime-close-start'));
    expect(events, <String>['content-acquire', 'runtime-close-start']);

    runtimeClose.complete();
    await _waitUntil(() => events.contains('workspace-close'));

    expect(events, <String>[
      'content-acquire',
      'runtime-close-start',
      'runtime-close',
      'account-lease-close',
      'workspace-close',
    ]);
    expect(events.where((event) => event == 'runtime-close'), hasLength(1));
    expect(
      events.where((event) => event == 'account-lease-close'),
      hasLength(1),
    );
    expect(events.where((event) => event == 'workspace-close'), hasLength(1));
    expect(content.closeRuntimeCalls, 1);
    expect(content.closeAccountLeaseCalls, 1);
    expect(workspace.workspaceCloseCalls, 1);
  });

  test('E2EE 后台同步迟到内容占用结果释放工作区且仅一次', () async {
    final events = <String>[];
    final pending = Completer<E2eeBackgroundContentAcquisition>();
    final workspace = _PendingContentBackgroundWorkspace(
      events: events,
      session: _session(),
      acquisition: pending.future,
    );

    await expectLater(
      E2eeBackgroundSyncRunner.forTesting(
        _FixedBackgroundHost(E2eeBackgroundWorkspaceAcquired(workspace)),
      ).run(
        limits: const E2eeBackgroundSyncLimits(
          maximumDuration: Duration(milliseconds: 10),
          maximumShutdownDuration: Duration(milliseconds: 20),
        ),
      ),
      throwsA(isA<E2eeSyncDeadlineExceeded>()),
    );
    expect(events, <String>['content-acquire']);

    pending.complete(const E2eeBackgroundContentBusy());
    await _waitUntil(() => events.contains('workspace-close'));

    expect(events, <String>['content-acquire', 'workspace-close']);
    expect(workspace.workspaceCloseCalls, 1);
  });

  test('E2EE 后台同步迟到内容失败仍上报并释放工作区', () async {
    final reportedErrors = <FlutterErrorDetails>[];
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = reportedErrors.add;
    addTearDown(() => FlutterError.onError = previousErrorHandler);
    final events = <String>[];
    final pending = Completer<E2eeBackgroundContentAcquisition>();
    final workspace = _PendingContentBackgroundWorkspace(
      events: events,
      session: _session(),
      acquisition: pending.future,
    );

    await expectLater(
      E2eeBackgroundSyncRunner.forTesting(
        _FixedBackgroundHost(E2eeBackgroundWorkspaceAcquired(workspace)),
      ).run(
        limits: const E2eeBackgroundSyncLimits(
          maximumDuration: Duration(milliseconds: 10),
          maximumShutdownDuration: Duration(milliseconds: 20),
        ),
      ),
      throwsA(isA<E2eeSyncDeadlineExceeded>()),
    );
    expect(events, <String>['content-acquire']);

    final acquisitionError = StateError('late-content-acquisition-failed');
    pending.completeError(acquisitionError, StackTrace.current);
    await _waitUntil(
      () => events.contains('workspace-close') && reportedErrors.isNotEmpty,
    );

    expect(events, <String>['content-acquire', 'workspace-close']);
    expect(workspace.workspaceCloseCalls, 1);
    expect(reportedErrors, hasLength(1));
    expect(reportedErrors.single.exception, same(acquisitionError));
  });

  test('E2EE 后台同步正常有界执行并按所有权逆序关闭', () async {
    final events = <String>[];
    final content = _FakeBackgroundContent(
      events: events,
      run: (executionBudget) async {
        expect(executionBudget.maximumNetworkSteps, 7);
        expect(executionBudget.maximumAttachmentBytes, 2 * 1024 * 1024);
        expect(executionBudget.maximumDuration, const Duration(seconds: 3));
        return _backgroundCycleReport(E2eeSyncCycleDisposition.completed);
      },
    );
    final workspace = _FakeBackgroundWorkspace(
      events: events,
      session: _session(),
      contentAcquisition: E2eeBackgroundContentAcquired(content),
    );
    final runner = E2eeBackgroundSyncRunner.forTesting(
      _FixedBackgroundHost(E2eeBackgroundWorkspaceAcquired(workspace)),
    );

    final outcome = await runner.run(
      limits: const E2eeBackgroundSyncLimits(
        maximumNetworkSteps: 7,
        maximumAttachmentBytes: 2 * 1024 * 1024,
        maximumDuration: Duration(seconds: 3),
      ),
    );

    expect(outcome.disposition, E2eeBackgroundSyncDisposition.completed);
    expect(content.runCalls, 1);
    expect(events, <String>[
      'content-acquire',
      'run',
      'runtime-close',
      'account-lease-close',
      'workspace-close',
    ]);
  });

  test('E2EE 后台同步清理超过总截止时不向平台伪报成功', () async {
    final events = <String>[];
    final content = _FakeBackgroundContent(
      events: events,
      run: (_) async =>
          _backgroundCycleReport(E2eeSyncCycleDisposition.completed),
      closeRuntimeDelay: const Duration(milliseconds: 30),
    );
    final workspace = _FakeBackgroundWorkspace(
      events: events,
      session: _session(),
      contentAcquisition: E2eeBackgroundContentAcquired(content),
    );

    await expectLater(
      E2eeBackgroundSyncRunner.forTesting(
        _FixedBackgroundHost(E2eeBackgroundWorkspaceAcquired(workspace)),
      ).run(
        limits: const E2eeBackgroundSyncLimits(
          maximumDuration: Duration(milliseconds: 10),
        ),
      ),
      throwsA(isA<E2eeSyncDeadlineExceeded>()),
    );

    expect(events, <String>[
      'content-acquire',
      'run',
      'runtime-close',
      'account-lease-close',
      'workspace-close',
    ]);
  });

  test('E2EE 后台同步运行时关闭永不完成时仍尝试释放其余租约', () async {
    final events = <String>[];
    final closeRuntime = Completer<void>();
    final content = _FakeBackgroundContent(
      events: events,
      run: (_) async =>
          _backgroundCycleReport(E2eeSyncCycleDisposition.completed),
      closeRuntimeBarrier: closeRuntime.future,
    );
    final workspace = _FakeBackgroundWorkspace(
      events: events,
      session: _session(),
      contentAcquisition: E2eeBackgroundContentAcquired(content),
    );

    await expectLater(
      E2eeBackgroundSyncRunner.forTesting(
            _FixedBackgroundHost(E2eeBackgroundWorkspaceAcquired(workspace)),
          )
          .run(
            limits: const E2eeBackgroundSyncLimits(
              maximumDuration: Duration(milliseconds: 10),
              maximumShutdownDuration: Duration(milliseconds: 20),
            ),
          )
          .timeout(
            const Duration(milliseconds: 150),
            onTimeout: () => throw StateError(
              'e2ee_background_sync_cleanup_deadline_not_enforced',
            ),
          ),
      throwsA(isA<E2eeSyncDeadlineExceeded>()),
    );

    expect(events, <String>[
      'content-acquire',
      'run',
      'runtime-close-start',
      'account-lease-close',
      'workspace-close',
    ]);
  });

  test('E2EE 后台同步未来密钥世代返回阻塞且不归类成功', () async {
    final events = <String>[];
    final content = _FakeBackgroundContent(
      events: events,
      run: (_) async =>
          _backgroundCycleReport(E2eeSyncCycleDisposition.keyEpochUnavailable),
    );
    final workspace = _FakeBackgroundWorkspace(
      events: events,
      session: _session(),
      contentAcquisition: E2eeBackgroundContentAcquired(content),
    );

    final outcome = await E2eeBackgroundSyncRunner.forTesting(
      _FixedBackgroundHost(E2eeBackgroundWorkspaceAcquired(workspace)),
    ).run();

    expect(
      outcome.disposition,
      E2eeBackgroundSyncDisposition.blockedByKeyEpoch,
    );
    expect(
      outcome.report?.disposition,
      E2eeSyncCycleDisposition.keyEpochUnavailable,
    );
    expect(events.sublist(events.length - 3), <String>[
      'runtime-close',
      'account-lease-close',
      'workspace-close',
    ]);
  });

  test('E2EE 后台同步预算耗尽保留进度并正常释放所有权', () async {
    final events = <String>[];
    final content = _FakeBackgroundContent(
      events: events,
      run: (_) async {
        throw const E2eeSyncBudgetExhausted(
          E2eeSyncBudgetExhaustion.networkSteps,
        );
      },
    );
    final workspace = _FakeBackgroundWorkspace(
      events: events,
      session: _session(),
      contentAcquisition: E2eeBackgroundContentAcquired(content),
    );

    final outcome = await E2eeBackgroundSyncRunner.forTesting(
      _FixedBackgroundHost(E2eeBackgroundWorkspaceAcquired(workspace)),
    ).run();

    expect(outcome.disposition, E2eeBackgroundSyncDisposition.budgetExhausted);
    expect(outcome.budgetExhaustion, E2eeSyncBudgetExhaustion.networkSteps);
    expect(events.sublist(events.length - 3), <String>[
      'runtime-close',
      'account-lease-close',
      'workspace-close',
    ]);
  });

  test('E2EE 后台同步初始化失败不伪成功且仍关闭全部资源', () async {
    final events = <String>[];
    final content = _FakeBackgroundContent(
      events: events,
      run: (_) => Future<E2eeSyncCycleReport>.error(
        StateError('background-runtime-init-failed'),
      ),
    );
    final workspace = _FakeBackgroundWorkspace(
      events: events,
      session: _session(),
      contentAcquisition: E2eeBackgroundContentAcquired(content),
    );

    await expectLater(
      E2eeBackgroundSyncRunner.forTesting(
        _FixedBackgroundHost(E2eeBackgroundWorkspaceAcquired(workspace)),
      ).run(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'background-runtime-init-failed',
        ),
      ),
    );

    expect(events.sublist(events.length - 3), <String>[
      'runtime-close',
      'account-lease-close',
      'workspace-close',
    ]);
  });

  test('E2EE 后台内容运行时构造失败时关闭客户端与账户租约并保留根因', () async {
    final events = <String>[];
    final initializationFailure = StateError('background-runtime-create');
    final leaseCloseFailure = StateError('background-lease-close-secondary');

    await expectLater(
      rethrowCloudSyncPrimaryAfterCleanup(
        primaryError: initializationFailure,
        primaryStackTrace: StackTrace.current,
        cleanupSteps: <CloudSyncFailureCleanupStep>[
          CloudSyncFailureCleanupStep(
            operation: '测试网络客户端关闭失败',
            cleanup: () async {
              events.add('client-close');
            },
          ),
          CloudSyncFailureCleanupStep(
            operation: '测试账户租约关闭失败',
            cleanup: () async {
              events.add('account-lease-close');
              throw leaseCloseFailure;
            },
          ),
        ],
      ),
      throwsA(same(initializationFailure)),
    );

    expect(events, <String>['client-close', 'account-lease-close']);
  });

  test('E2EE 后台同步终止认证先提交 tombstone 再关闭资源', () async {
    final events = <String>[];
    final content = _FakeBackgroundContent(
      events: events,
      run: (_) => Future<E2eeSyncCycleReport>.error(
        const CloudSyncException(
          kind: CloudSyncFailureKind.unauthenticated,
          retryable: false,
        ),
      ),
    );
    final workspace = _FakeBackgroundWorkspace(
      events: events,
      session: _session(),
      contentAcquisition: E2eeBackgroundContentAcquired(content),
    );

    final outcome = await E2eeBackgroundSyncRunner.forTesting(
      _FixedBackgroundHost(E2eeBackgroundWorkspaceAcquired(workspace)),
    ).run();

    expect(
      outcome.disposition,
      E2eeBackgroundSyncDisposition.authenticationRetired,
    );
    expect(workspace.session, isNull);
    expect(events, <String>[
      'content-acquire',
      'run',
      'session-tombstone',
      'runtime-close',
      'account-lease-close',
      'workspace-close',
    ]);
  });

  test('E2EE 后台同步终止认证持久化永不完成时仍有界释放所有权', () async {
    final events = <String>[];
    final persistSession = Completer<void>();
    final content = _FakeBackgroundContent(
      events: events,
      run: (_) => Future<E2eeSyncCycleReport>.error(
        const CloudSyncException(
          kind: CloudSyncFailureKind.unauthenticated,
          retryable: false,
        ),
      ),
    );
    final workspace = _FakeBackgroundWorkspace(
      events: events,
      session: _session(),
      contentAcquisition: E2eeBackgroundContentAcquired(content),
      persistSessionBarrier: persistSession.future,
    );

    await expectLater(
      E2eeBackgroundSyncRunner.forTesting(
            _FixedBackgroundHost(E2eeBackgroundWorkspaceAcquired(workspace)),
          )
          .run(
            limits: const E2eeBackgroundSyncLimits(
              maximumDuration: Duration(milliseconds: 10),
              maximumShutdownDuration: Duration(milliseconds: 20),
            ),
          )
          .timeout(
            const Duration(milliseconds: 150),
            onTimeout: () => throw StateError(
              'e2ee_background_sync_retirement_deadline_not_enforced',
            ),
          ),
      throwsA(isA<E2eeSyncDeadlineExceeded>()),
    );

    expect(events, <String>[
      'content-acquire',
      'run',
      'session-tombstone-start',
      'runtime-close',
      'account-lease-close',
      'workspace-close',
    ]);
  });

  test('E2EE 后台同步异常、截止和取消均执行 finally 清理', () async {
    final failures = <Object>[
      StateError('sync-failed'),
      const E2eeSyncDeadlineExceeded(),
      const E2eeSyncExecutionCancelled(),
    ];
    for (final failure in failures) {
      final events = <String>[];
      final content = _FakeBackgroundContent(
        events: events,
        run: (_) => Future<E2eeSyncCycleReport>.error(failure),
      );
      final workspace = _FakeBackgroundWorkspace(
        events: events,
        session: _session(),
        contentAcquisition: E2eeBackgroundContentAcquired(content),
      );

      await expectLater(
        E2eeBackgroundSyncRunner.forTesting(
          _FixedBackgroundHost(E2eeBackgroundWorkspaceAcquired(workspace)),
        ).run(),
        throwsA(same(failure)),
      );
      expect(events.sublist(events.length - 3), <String>[
        'runtime-close',
        'account-lease-close',
        'workspace-close',
      ]);
    }
  });

  test('E2EE 单调预算截止会中止并等待在途网络 Future 结算', () async {
    final network = Completer<int>();
    var abortCalls = 0;
    var networkSettled = false;
    final budget = E2eeSyncExecutionBudget(
      maximumNetworkSteps: 1,
      maximumAttachmentBytes: 0,
      maximumDuration: const Duration(milliseconds: 20),
      abortInFlightNetwork: () {
        abortCalls++;
        network.completeError(StateError('network-aborted'));
      },
    );

    await expectLater(
      budget.runNetworkStep(
        operation: (_) async {
          try {
            return await network.future;
          } finally {
            networkSettled = true;
          }
        },
      ),
      throwsA(isA<E2eeSyncDeadlineExceeded>()),
    );

    expect(abortCalls, 1);
    expect(networkSettled, isTrue);
  });

  test('E2EE 单调预算取消会中止并等待在途网络 Future 结算', () async {
    final cancellation = _TrackedSyncCancellationSignal();
    final network = Completer<int>();
    var abortCalls = 0;
    var networkSettled = false;
    final budget = E2eeSyncExecutionBudget(
      maximumNetworkSteps: 1,
      maximumAttachmentBytes: 0,
      maximumDuration: const Duration(seconds: 5),
      abortInFlightNetwork: () {
        abortCalls++;
        network.completeError(StateError('network-aborted'));
      },
      cancellationSignal: cancellation,
    );
    addTearDown(budget.dispose);
    final run = budget.runNetworkStep(
      operation: (_) async {
        try {
          return await network.future;
        } finally {
          networkSettled = true;
        }
      },
    );

    cancellation.cancel();

    await expectLater(run, throwsA(isA<E2eeSyncExecutionCancelled>()));
    expect(abortCalls, 1);
    expect(networkSettled, isTrue);
  });

  test('E2EE 单调预算中止回调失败时仍等待在途网络 Future 结算', () async {
    final network = Completer<void>();
    var operationSettled = false;
    final budget = E2eeSyncExecutionBudget(
      maximumNetworkSteps: 1,
      maximumAttachmentBytes: 0,
      maximumDuration: const Duration(milliseconds: 20),
      abortInFlightNetwork: () {
        Future<void>.delayed(const Duration(milliseconds: 10), () {
          operationSettled = true;
          network.completeError(StateError('network-settled'));
        });
        throw StateError('abort-failed');
      },
    );

    await expectLater(
      budget.runNetworkStep(operation: (_) => network.future),
      throwsA(isA<E2eeSyncDeadlineExceeded>()),
    );

    expect(operationSettled, isTrue);
  });

  test('E2EE 单调预算在网络 Future 永不结算时只等待关闭宽限期', () async {
    final network = Completer<void>();
    var abortCalls = 0;
    final budget = E2eeSyncExecutionBudget(
      maximumNetworkSteps: 1,
      maximumAttachmentBytes: 0,
      maximumDuration: const Duration(milliseconds: 10),
      maximumShutdownDuration: const Duration(milliseconds: 20),
      abortInFlightNetwork: () => abortCalls++,
    );
    addTearDown(budget.dispose);

    await expectLater(
      budget
          .runNetworkStep(operation: (_) => network.future)
          .timeout(
            const Duration(milliseconds: 150),
            onTimeout: () => throw StateError(
              'e2ee_sync_network_settlement_deadline_not_enforced',
            ),
          ),
      throwsA(isA<E2eeSyncDeadlineExceeded>()),
    );

    expect(abortCalls, 1);
  });

  test('E2EE 单调预算在有界释放失败后返回前完成错误上报', () async {
    final reportedErrors = <FlutterErrorDetails>[];
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = reportedErrors.add;
    addTearDown(() => FlutterError.onError = previousErrorHandler);
    final budget = E2eeSyncExecutionBudget(
      maximumNetworkSteps: 1,
      maximumAttachmentBytes: 0,
      maximumDuration: const Duration(milliseconds: 5),
      maximumShutdownDuration: const Duration(milliseconds: 20),
      abortInFlightNetwork: () {},
    );
    addTearDown(budget.dispose);

    await expectLater(
      budget.runBoundedStep<String>(
        operation: (_) {
          final stopwatch = Stopwatch()..start();
          while (stopwatch.elapsed < const Duration(milliseconds: 10)) {}
          return Future<String>.value('owned-value');
        },
        releaseInterruptedValue: (_) async {
          throw StateError('bounded-release-failed');
        },
      ),
      throwsA(isA<E2eeSyncDeadlineExceeded>()),
    );

    expect(reportedErrors, hasLength(1));
    expect(reportedErrors.single.exception, isA<StateError>());
  });

  test('E2EE 单调预算迟到释放超过宽限后仍报告失败', () async {
    final reportedErrors = <FlutterErrorDetails>[];
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = reportedErrors.add;
    addTearDown(() => FlutterError.onError = previousErrorHandler);
    final releaseStarted = Completer<void>();
    final release = Completer<void>();
    final budget = E2eeSyncExecutionBudget(
      maximumNetworkSteps: 1,
      maximumAttachmentBytes: 0,
      maximumDuration: const Duration(milliseconds: 5),
      maximumShutdownDuration: const Duration(milliseconds: 10),
      abortInFlightNetwork: () {},
    );
    addTearDown(budget.dispose);

    await expectLater(
      budget.runBoundedStep<String>(
        operation: (_) {
          final stopwatch = Stopwatch()..start();
          while (stopwatch.elapsed < const Duration(milliseconds: 20)) {}
          return Future<String>.value('owned-value');
        },
        releaseInterruptedValue: (_) {
          releaseStarted.complete();
          return release.future;
        },
      ),
      throwsA(isA<E2eeSyncDeadlineExceeded>()),
    );

    await releaseStarted.future.timeout(const Duration(milliseconds: 100));
    release.completeError(StateError('late-release-failed'));
    await _waitUntil(() => reportedErrors.isNotEmpty);

    expect(reportedErrors, hasLength(1));
    expect(reportedErrors.single.exception, isA<StateError>());
    expect(
      reportedErrors.single.context.toString(),
      contains('释放截止后才返回的后台同步所有权失败'),
    );
  });

  test('Android 原生生命周期静态契约线性化副作用与终态', () async {
    final androidWorker = await File(
      'dependencies/workmanager_android/android/src/main/kotlin/'
      'dev/fluttercommunity/workmanager/BackgroundWorker.kt',
    ).readAsString();
    final androidLifecycle = await File(
      'dependencies/workmanager_android/android/src/main/kotlin/'
      'dev/fluttercommunity/workmanager/BackgroundWorkerLifecycle.kt',
    ).readAsString();
    final debugHelperStart = androidLifecycle.indexOf(
      'internal fun <TerminalOutcome, ForcedStop> '
      'reportBackgroundWorkerDebugIfActive(',
    );
    final terminalFinalizerStart = androidLifecycle.indexOf(
      'internal class BackgroundWorkerTerminalFinalizer',
    );

    final dartExecutionStart = androidWorker.indexOf(
      'private fun startDartExecutionIfActive(',
    );
    final taskExecutionStart = androidWorker.indexOf(
      'private fun startBackgroundTaskIfActive(',
    );
    final cancellationRequestStart = androidWorker.indexOf(
      'private fun requestDartCancellation()',
    );
    final cancellationSendStart = androidWorker.indexOf(
      'private fun sendDartCancellationIfReady()',
    );
    final finishEffectStart = androidWorker.indexOf(
      'private fun finishLifecycleEffect(',
    );
    final failureDebugStart = androidWorker.indexOf(
      'private fun reportFailureAndStop(',
    );
    final replyDebugStart = androidWorker.indexOf(
      'private fun reportDebugIfActive(',
    );
    final terminalCompletionStart = androidWorker.indexOf(
      'private fun completeTerminal(',
    );
    final terminalStatusStart = androidWorker.indexOf(
      'private fun reportTerminalStatus(',
    );
    final detachedDestroyStart = androidWorker.indexOf(
      'private fun scheduleDetachedEngineDestruction(',
    );

    expect(dartExecutionStart, greaterThanOrEqualTo(0));
    expect(taskExecutionStart, greaterThan(dartExecutionStart));
    expect(cancellationRequestStart, greaterThan(taskExecutionStart));
    expect(cancellationSendStart, greaterThan(cancellationRequestStart));
    expect(finishEffectStart, greaterThan(cancellationSendStart));
    expect(failureDebugStart, greaterThan(finishEffectStart));
    expect(replyDebugStart, greaterThan(failureDebugStart));
    expect(terminalCompletionStart, greaterThan(replyDebugStart));
    expect(terminalStatusStart, greaterThan(terminalCompletionStart));
    expect(detachedDestroyStart, greaterThan(terminalStatusStart));
    expect(debugHelperStart, greaterThanOrEqualTo(0));
    expect(terminalFinalizerStart, greaterThan(debugHelperStart));

    final dartExecution = androidWorker.substring(
      dartExecutionStart,
      taskExecutionStart,
    );
    final taskExecution = androidWorker.substring(
      taskExecutionStart,
      cancellationRequestStart,
    );
    final cancellationRequest = androidWorker.substring(
      cancellationRequestStart,
      cancellationSendStart,
    );
    final cancellationSend = androidWorker.substring(
      cancellationSendStart,
      finishEffectStart,
    );
    final failureDebug = androidWorker.substring(
      failureDebugStart,
      replyDebugStart,
    );
    final replyDebug = androidWorker.substring(
      replyDebugStart,
      terminalCompletionStart,
    );
    final terminalCompletion = androidWorker.substring(
      terminalCompletionStart,
      terminalStatusStart,
    );
    final detachedDestroy = androidWorker.substring(detachedDestroyStart);
    final debugHelper = androidLifecycle.substring(
      debugHelperStart,
      terminalFinalizerStart,
    );

    expect(
      androidWorker,
      contains('BackgroundWorkerLifecycleCoordinator<TerminalRequest'),
    );
    expect(
      dartExecution,
      contains('val effect = lifecycle.beginDartExecution() ?: return false'),
    );
    expect(dartExecution, contains('WorkmanagerDebug.onTaskStatusUpdate('));
    expect(dartExecution, contains('flutterApi = WorkmanagerFlutterApi('));
    expect(dartExecution, contains('executeDartCallback('));
    expect(dartExecution, contains('flutterApi.backgroundChannelInitialized'));
    expect(dartExecution, contains('finally'));
    expect(dartExecution, contains('finishLifecycleEffect(effect)'));

    expect(
      taskExecution,
      contains('val effect = lifecycle.beginTaskExecution() ?: return false'),
    );
    expect(taskExecution, contains('flutterApi.executeTask('));
    expect(taskExecution, contains('sendDartCancellationIfReady()'));
    expect(taskExecution, contains('finally'));
    expect(taskExecution, contains('finishLifecycleEffect(effect)'));

    expect(
      cancellationRequest,
      contains('lifecycle.requestCancellationWakeup()'),
    );
    expect(cancellationRequest, contains('mainHandler.post'));
    expect(
      cancellationSend,
      contains('val effect = lifecycle.beginCancellationDispatch() ?: return'),
    );
    expect(cancellationSend, contains('localFlutterApi.taskCancelled('));
    expect(cancellationSend, contains('reportDebugIfActive(exception)'));
    expect(cancellationSend, contains('finally'));
    expect(cancellationSend, contains('finishLifecycleEffect(effect)'));

    expect(
      failureDebug,
      contains('val debugEffect = lifecycle.beginDebugEffect() ?: return'),
    );
    expect(failureDebug, contains('WorkmanagerDebug.onExceptionEncountered('));
    expect(failureDebug, contains('stopEngine(Result.failure()'));
    expect(failureDebug, contains('finishLifecycleEffect(debugEffect)'));
    expect(replyDebug, contains('reportBackgroundWorkerDebugIfActive('));
    expect(replyDebug, contains('failureOutcome = { reporterFailure ->'));
    expect(
      replyDebug,
      contains('TerminalRequest(Result.failure(), reporterFailure.message)'),
    );
    expect(replyDebug, contains('WorkmanagerDebug.onExceptionEncountered('));
    expect(replyDebug, contains('completeTerminal = ::completeTerminal'));

    expect(debugHelper, contains('lifecycle.beginDebugEffect() ?: return'));
    expect(debugHelper, contains('catch (failure: Throwable)'));
    expect(debugHelper, contains('lifecycle.requestTerminal('));
    expect(debugHelper, contains('finally'));
    expect(debugHelper, contains('effect.finish()?.let(completeTerminal)'));
    expect(debugHelper, contains('reporterFailure?.let { throw it }'));

    final cancelIndex = terminalCompletion.indexOf('cancelForcedStop =');
    final statusIndex = terminalCompletion.indexOf('reportFinalStatus =');
    final shutdownIndex = terminalCompletion.indexOf('shutdownScheduler =');
    final detachIndex = terminalCompletion.indexOf('detachEngine =');
    final destroyIndex = terminalCompletion.indexOf(
      'scheduleDetachedEngineDestruction =',
    );
    final completerIndex = terminalCompletion.indexOf('completePlatform =');
    expect(cancelIndex, greaterThanOrEqualTo(0));
    expect(statusIndex, greaterThan(cancelIndex));
    expect(shutdownIndex, greaterThan(statusIndex));
    expect(detachIndex, greaterThan(shutdownIndex));
    expect(destroyIndex, greaterThan(detachIndex));
    expect(completerIndex, greaterThan(destroyIndex));
    expect(terminalCompletion, contains('engine.getAndSet(null)'));
    expect(terminalCompletion, contains('completer.set(result)'));

    expect(detachedDestroy, contains('mainHandler.post'));
    expect(detachedDestroy, contains('detachedEngine.destroy()'));
    expect(detachedDestroy, isNot(contains('engine.get')));
    expect(detachedDestroy, isNot(contains('WorkmanagerDebug')));
    expect(detachedDestroy, isNot(contains('flutterApi')));
    expect(detachedDestroy, isNot(contains('completer')));

    expect(
      androidLifecycle,
      contains('internal class BackgroundWorkerLifecycleCoordinator'),
    );
    expect(androidLifecycle, contains('private var terminalRequest'));
    expect(androidLifecycle, contains('private var inFlightEffects = 0'));
    expect(androidLifecycle, contains('fun beginDebugEffect(): Effect?'));
    expect(androidLifecycle, contains('fun beginCancellationDispatch()'));
    expect(
      androidLifecycle,
      contains('internal class BackgroundWorkerTerminalFinalizer'),
    );
    expect(androidLifecycle, contains('completePlatform()'));
    expect(
      RegExp(r'executeDartCallback\(').allMatches(androidWorker),
      hasLength(1),
    );
    expect(RegExp(r'\.executeTask\(').allMatches(androidWorker), hasLength(1));
    expect(
      RegExp(r'\.taskCancelled\(').allMatches(androidWorker),
      hasLength(1),
    );
    expect(RegExp(r'completer\.set\(').allMatches(androidWorker), hasLength(1));
    expect(androidWorker, isNot(contains('private var engineStopped')));
    expect(androidWorker, isNot(contains('claimDartExecution')));
    expect(androidWorker, isNot(contains('claimBackgroundTaskExecution')));
  });

  test('移动后台原生桥静态包含独立截止请求与单一终态状态机', () async {
    final androidWorker = await File(
      'dependencies/workmanager_android/android/src/main/kotlin/'
      'dev/fluttercommunity/workmanager/BackgroundWorker.kt',
    ).readAsString();
    final androidLifecycle = await File(
      'dependencies/workmanager_android/android/src/main/kotlin/'
      'dev/fluttercommunity/workmanager/BackgroundWorkerLifecycle.kt',
    ).readAsString();
    final appleOperation = await File(
      'dependencies/workmanager_apple/ios/Sources/workmanager_apple/'
      'BackgroundTaskOperation.swift',
    ).readAsString();
    final appleWorker = await File(
      'dependencies/workmanager_apple/ios/Sources/workmanager_apple/'
      'BackgroundWorker.swift',
    ).readAsString();
    final applePlugin = await File(
      'dependencies/workmanager_apple/ios/Sources/workmanager_apple/'
      'WorkmanagerPlugin.swift',
    ).readAsString();

    expect(androidWorker, contains('CANCELLATION_GRACE_MILLIS'));
    expect(androidWorker, contains('ScheduledExecutorService'));
    expect(androidWorker, contains('ScheduledFuture'));
    expect(androidWorker, contains('ScheduledThreadPoolExecutor'));
    expect(androidWorker, contains('cancellationScheduler.schedule('));
    expect(androidWorker, contains('TimeUnit.MILLISECONDS'));
    expect(androidWorker, contains('stopEngine(Result.failure()'));
    expect(androidWorker, contains('completion.forcedStop?.cancel(false)'));
    expect(androidWorker, contains('completer.set(result)'));
    expect(androidWorker, contains('scheduleDetachedEngineDestruction'));
    expect(androidLifecycle, contains('private enum class LifecycleState'));
    expect(androidLifecycle, contains('LifecycleState.TERMINAL'));
    expect(androidLifecycle, contains('takeTerminalCompletionLocked()'));
    expect(androidWorker, isNot(contains('postDelayed')));
    expect(androidWorker, isNot(contains('stopEngine(null)')));
    expect(appleOperation, contains('cancellationGrace'));
    expect(appleOperation, contains('DispatchQueue.global(qos: .utility)'));
    expect(appleOperation, contains('requestForcedCancellationCleanup'));
    expect(appleOperation, contains('self.finish()'));
    expect(appleOperation, contains('completionSemaphore.signal()'));
    expect(
      appleOperation,
      contains('private var backgroundResult = UIBackgroundFetchResult.failed'),
    );
    expect(appleOperation, contains('var wasSuccessful: Bool'));
    expect(appleWorker, contains('legacyFetchHardBound'));
    expect(
      appleWorker,
      contains('DispatchQueue.global(qos: .utility).asyncAfter('),
    );
    expect(appleWorker, contains('DispatchQueue.main.async'));
    expect(appleWorker, contains('guard self.installCancellationNotifier'));
    expect(appleWorker, contains('private enum LifecycleState'));
    expect(
      appleWorker,
      contains('private let lifecycleLock = NSRecursiveLock()'),
    );
    expect(appleWorker, contains('case pending'));
    expect(appleWorker, contains('case executing'));
    expect(appleWorker, contains('case terminal'));
    expect(appleWorker, contains('lifecycleState = .terminal'));
    expect(appleWorker, contains('guard runWhileExecuting({'));
    expect(appleWorker, isNot(contains('completionLock')));
    expect(appleWorker, isNot(contains('forceCancellationRequested')));
    expect(appleWorker, contains('completer?()'));
    expect(appleWorker, contains('platformCompletion()'));
    expect(
      appleWorker,
      contains('guard claimExecution() else { return false }'),
    );
    expect(appleWorker, contains('flutterEngine = FlutterEngine('));
    expect(
      applePlugin,
      contains(
        'task.setTaskCompleted(success: operation?.wasSuccessful ?? false)',
      ),
    );
    expect(applePlugin, contains('operation?.requestBestEffortCleanup()'));
  });

  test('E2EE 后台同步同一账户并发只允许一个执行', () async {
    final events = <String>[];
    final started = Completer<void>();
    final release = Completer<void>();
    final content = _FakeBackgroundContent(
      events: events,
      run: (_) async {
        started.complete();
        await release.future;
        return _backgroundCycleReport(E2eeSyncCycleDisposition.completed);
      },
    );
    final workspace = _FakeBackgroundWorkspace(
      events: events,
      session: _session(),
      contentAcquisition: E2eeBackgroundContentAcquired(content),
    );
    final host = _ExclusiveBackgroundHost(workspace);
    final firstRunner = E2eeBackgroundSyncRunner.forTesting(host);
    final secondRunner = E2eeBackgroundSyncRunner.forTesting(host);

    final first = firstRunner.run();
    await started.future;
    final second = await secondRunner.run();
    release.complete();
    final firstOutcome = await first;

    expect(second.disposition, E2eeBackgroundSyncDisposition.workspaceBusy);
    expect(firstOutcome.disposition, E2eeBackgroundSyncDisposition.completed);
    expect(content.runCalls, 1);
    expect(host.maximumConcurrentWorkspaces, 1);
  });

  test('移动后台同步生产 Runner 已接入安全引导门禁', () {
    expect(E2eeBackgroundSyncRunner(), isA<E2eeBackgroundSyncRunner>());
  });

  test('移动后台同步拒绝未知系统任务且不创建 Runner', () async {
    var runnerCreations = 0;
    final executor = E2eeMobileBackgroundTaskExecutor(
      runnerFactory: () {
        runnerCreations++;
        return E2eeBackgroundSyncRunner.forTesting(
          const _FixedBackgroundHost(E2eeBackgroundWorkspaceBusy()),
        );
      },
      cancelScheduledTask: () async {},
    );

    expect(
      () => executor.execute('other-background-task'),
      throwsA(isA<UnsupportedError>()),
    );
    expect(runnerCreations, 0);
  });

  test('移动后台同步并发系统回调共享一个 Runner', () async {
    final pending = Completer<E2eeBackgroundWorkspaceAcquisition>();
    var runnerCreations = 0;
    final executor = E2eeMobileBackgroundTaskExecutor(
      runnerFactory: () {
        runnerCreations++;
        return E2eeBackgroundSyncRunner.forTesting(
          _PendingBackgroundHost(pending.future),
        );
      },
      cancelScheduledTask: () async {},
    );

    final first = executor.execute(e2eeMobileBackgroundTaskName);
    final second = executor.execute(e2eeMobileBackgroundTaskName);
    expect(runnerCreations, 1);

    pending.complete(const E2eeBackgroundWorkspaceBusy());
    expect(await Future.wait(<Future<bool>>[first, second]), <bool>[
      true,
      true,
    ]);
    expect(runnerCreations, 1);
  });

  test('移动后台同步密钥世代阻塞时向平台返回失败', () async {
    final events = <String>[];
    final content = _FakeBackgroundContent(
      events: events,
      run: (_) async =>
          _backgroundCycleReport(E2eeSyncCycleDisposition.keyEpochUnavailable),
    );
    final workspace = _FakeBackgroundWorkspace(
      events: events,
      session: _session(),
      contentAcquisition: E2eeBackgroundContentAcquired(content),
    );
    var cancellationCalls = 0;
    final executor = E2eeMobileBackgroundTaskExecutor(
      runnerFactory: () => E2eeBackgroundSyncRunner.forTesting(
        _FixedBackgroundHost(E2eeBackgroundWorkspaceAcquired(workspace)),
      ),
      cancelScheduledTask: () async => cancellationCalls++,
    );

    expect(await executor.execute(e2eeMobileBackgroundTaskName), isFalse);
    expect(cancellationCalls, 0);
  });

  test('移动后台同步把平台取消信号贯穿到 Runner 且不获取工作区', () async {
    final cancellation = _TrackedSyncCancellationSignal()..cancel();
    final host = _DelayedBackgroundHost(
      const E2eeBackgroundWorkspaceBusy(),
      Duration.zero,
    );
    final executor = E2eeMobileBackgroundTaskExecutor(
      runnerFactory: () => E2eeBackgroundSyncRunner.forTesting(host),
      cancelScheduledTask: () async {},
    );

    await expectLater(
      executor.execute(
        e2eeMobileBackgroundTaskName,
        cancellationSignal: cancellation,
      ),
      throwsA(isA<E2eeSyncExecutionCancelled>()),
    );

    expect(host.acquisitionCalls, 0);
    expect(cancellation.activeListenerCount, 0);
  });

  test('移动后台同步发现持久会话已清除时取消后续系统任务', () async {
    final workspace = _FakeBackgroundWorkspace(
      events: <String>[],
      session: null,
      contentAcquisition: const E2eeBackgroundContentBusy(),
    );
    var cancellationCalls = 0;
    final executor = E2eeMobileBackgroundTaskExecutor(
      runnerFactory: () => E2eeBackgroundSyncRunner.forTesting(
        _FixedBackgroundHost(E2eeBackgroundWorkspaceAcquired(workspace)),
      ),
      cancelScheduledTask: () async => cancellationCalls++,
    );

    expect(await executor.execute(e2eeMobileBackgroundTaskName), isTrue);
    expect(cancellationCalls, 1);
    expect(workspace.contentAcquisitionCalls, 0);
  });

  test('移动后台调度把登录就绪与登出转换为串行注册和取消', () async {
    final platform = _RecordingMobileBackgroundSchedulerPlatform();
    final scheduler = E2eeMobileBackgroundSyncScheduler.forTesting(platform);
    final state = _TestMobileBackgroundAccountState();
    final lifecycle = E2eeMobileBackgroundSyncLifecycle(
      accountState: state,
      scheduler: scheduler,
    );
    addTearDown(lifecycle.dispose);

    await _waitUntil(() => platform.disableCalls == 1);
    state.update(signedIn: true, contentSyncEnabled: true);
    await _waitUntil(() => platform.enableCalls == 1);
    state.update(signedIn: false, contentSyncEnabled: false);
    await _waitUntil(() => platform.disableCalls == 2);

    expect(platform.events, <String>['disable', 'enable', 'disable']);
    expect(platform.maximumConcurrentCalls, 1);
  });

  test('移动后台调度在注册进行中收到登出时完成后立即取消', () async {
    final enableRelease = Completer<void>();
    final platform = _RecordingMobileBackgroundSchedulerPlatform(
      enableRelease: enableRelease,
    );
    final scheduler = E2eeMobileBackgroundSyncScheduler.forTesting(platform);

    final enabling = scheduler.setEnabled(true);
    await _waitUntil(() => platform.enableCalls == 1);
    final disabling = scheduler.setEnabled(false);
    enableRelease.complete();
    await Future.wait(<Future<void>>[enabling, disabling]);

    expect(platform.events, <String>['enable', 'disable']);
    expect(platform.maximumConcurrentCalls, 1);
  });

  test('移动后台注册失败但同时登出时仍执行取消且保留原始错误', () async {
    final enableRelease = Completer<void>();
    final platform = _RecordingMobileBackgroundSchedulerPlatform(
      enableRelease: enableRelease,
      enableError: StateError('enable-failed'),
    );
    final scheduler = E2eeMobileBackgroundSyncScheduler.forTesting(platform);

    final enabling = scheduler.setEnabled(true);
    await _waitUntil(() => platform.enableCalls == 1);
    final disabling = scheduler.setEnabled(false);
    enableRelease.complete();

    await expectLater(
      enabling,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'enable-failed',
        ),
      ),
    );
    await expectLater(disabling, throwsA(isA<StateError>()));
    expect(platform.events, <String>['enable', 'disable']);
    expect(platform.maximumConcurrentCalls, 1);
  });

  test('移动后台生命周期释放后不再响应账户状态变化', () async {
    final platform = _RecordingMobileBackgroundSchedulerPlatform();
    final scheduler = E2eeMobileBackgroundSyncScheduler.forTesting(platform);
    final state = _TestMobileBackgroundAccountState();
    final lifecycle = E2eeMobileBackgroundSyncLifecycle(
      accountState: state,
      scheduler: scheduler,
    );
    await _waitUntil(() => platform.disableCalls == 1);

    lifecycle.dispose();
    state.update(signedIn: true, contentSyncEnabled: true);
    await Future<void>.delayed(Duration.zero);

    expect(platform.enableCalls, 0);
    expect(platform.events, <String>['disable']);
  });

  test('E2EE headless 运行时直接使用 Vault 完成单次周期且不启动轮询', () async {
    final harness = await _E2eeRuntimeHarness.create();
    final pull = _RuntimePullTransport(
      accountUserId: harness.session.userId,
      blockInitialPull: false,
    );
    final records = _RuntimeRecordTransport(
      accountUserId: harness.session.userId,
      actorDeviceId: harness.session.deviceId,
    );
    final client = CloudSyncClient.forTesting(baseUrl: harness.session.baseUrl);
    E2eeChatContentTransports createTransports({
      required CloudSyncClient client,
      required CloudSyncAuthenticatedSession session,
    }) {
      return E2eeChatContentTransports(records: records, pull: pull);
    }

    final runtime = E2eeChatContentRuntime.takeHeadlessOwnership(
      session: harness.session,
      deviceStateStore: harness._deviceStateStore,
      secureCore: const KelivoSecureCore(),
      databaseGateway: harness._databaseGateway,
      databaseFile: harness._databaseFile,
      client: client,
      transportFactory: createTransports,
    );
    try {
      final report = await runtime.runSingleCycle(
        E2eeSyncExecutionBudget(
          maximumNetworkSteps: 17,
          maximumAttachmentBytes: 16 * 1024 * 1024,
          maximumDuration: const Duration(seconds: 5),
          abortInFlightNetwork: () => client.close(force: true),
        ),
      );

      expect(report.disposition, E2eeSyncCycleDisposition.completed);
      expect(pull.pullCalls, 2);
      expect(records.pushCalls, 0);
      expect(runtime.state, E2eeChatContentRuntimeState.ready);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(pull.pullCalls, 2);
    } finally {
      await runtime.close();
      await harness.close();
    }
    expect(runtime.state, E2eeChatContentRuntimeState.closed);
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

  test('重启内容运行时提交已安装 bootstrap 后才确认事务并重写 v4 会话', () async {
    final pendingSession = _session(
      securityBootstrap: _registrationBootstrap(),
    );
    final contentRuntime = _FakeCloudSyncContentRuntime(
      bootstrapSessionToCommit: pendingSession,
    );
    final authentication = _FakeE2eeAccountAuthentication();
    final fixture = await _createSignedInFixture(
      session: pendingSession,
      contentRuntime: contentRuntime,
      authentication: authentication,
    );
    addTearDown(fixture.close);

    await fixture.provider.initialize();

    expect(contentRuntime.bootstrapCommitCalls, 1);
    expect(authentication.requestNames, <String>['confirm-registration']);
    expect(fixture.provider.status, CloudSyncProviderStatus.idle);
    expect(fixture.provider.session?.securityBootstrap, isNull);
    expect(fixture.runtime.current.session?.securityBootstrap, isNull);
    expect(fixture.client.token?.value, pendingSession.token.value);
  });

  test('bootstrap 确认失败时禁止连接并保留会话材料供重启重放', () async {
    final pendingSession = _session(
      securityBootstrap: _registrationBootstrap(),
    );
    final contentRuntime = _FakeCloudSyncContentRuntime(
      bootstrapSessionToCommit: pendingSession,
    );
    final authentication = _FakeE2eeAccountAuthentication(
      confirmationFailure: StateError('registration_cleanup_failed'),
    );
    final fixture = await _createSignedInFixture(
      session: pendingSession,
      contentRuntime: contentRuntime,
      authentication: authentication,
    );
    addTearDown(fixture.close);

    await fixture.provider.initialize();

    expect(contentRuntime.bootstrapCommitCalls, 1);
    expect(authentication.requestNames, <String>['confirm-registration']);
    expect(fixture.provider.status, CloudSyncProviderStatus.error);
    expect(fixture.provider.contentSyncEnabled, isFalse);
    expect(fixture.runtime.current.session?.securityBootstrap, isNotNull);
  });

  test('控制面模式拒绝激活尚未安装的安全 bootstrap', () async {
    final pendingSession = _session(
      securityBootstrap: _registrationBootstrap(),
    );
    final fixture = await _createSignedInFixture(session: pendingSession);
    addTearDown(fixture.close);

    await fixture.provider.initialize();

    expect(fixture.provider.status, CloudSyncProviderStatus.error);
    expect(fixture.provider.contentSyncEnabled, isFalse);
    expect(fixture.client.requestNames, isEmpty);
    expect(fixture.runtime.current.session?.securityBootstrap, isNotNull);
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

  test('待批准设备完成配对后仅提交账户工作区并等待重启安装锚点', () async {
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
    await _waitUntil(() => fixture.provider.pendingDeviceApproval == null);

    expect(authentication.requestNames, <String>['login', 'start-pairing']);
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

    expect(fixture.authentication.requestNames, <String>['register']);
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

  test('首设备注册绑定阶段不提前执行恢复事务清理', () async {
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

    expect(authentication.requestNames, <String>['register']);
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

  test('E2EE 内容运行时无 bootstrap 且缺少本地成员锚点时禁止启动网络', () async {
    final harness = await _E2eeRuntimeHarness.create(
      seedMembershipAnchor: false,
    );
    addTearDown(harness.close);
    final instance = harness.createInstance();

    await expectLater(
      instance.runtime.initialize(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          '账户会话缺少本地已验证成员锚点',
        ),
      ),
    );

    expect(instance.runtime.state, E2eeChatContentRuntimeState.failed);
    expect(instance.pull.pullCalls, 0);
    expect(instance.transportSession, isNull);
  });

  test('E2EE 内容运行时先用 ARK 安装注册锚点并提交会话再创建传输层', () async {
    final harness = await _E2eeRuntimeHarness.create(
      seedMembershipAnchor: false,
      withSecurityBootstrap: true,
    );
    addTearDown(harness.close);
    final events = <String>[];
    late final _E2eeRuntimeInstance instance;
    instance = harness.createInstance(
      securityBootstrapCommitHandler: (pendingSession) async {
        expect(pendingSession.securityBootstrap, isNotNull);
        expect(instance.transportSession, isNull);
        expect(instance.pull.pullCalls, 0);
        events.add('commit');
      },
      onTransportCreated: () => events.add('transport'),
    );

    await instance.runtime.initialize().timeout(const Duration(seconds: 15));
    await _waitUntil(() => instance.pull.pullCalls >= 2);

    expect(events, <String>['commit', 'transport']);
    expect(instance.runtime.state, E2eeChatContentRuntimeState.ready);
    await instance.runtime.close();

    final replay = harness.createInstance(
      sessionOverride: harness.session.withoutSecurityBootstrap(),
    );
    await replay.runtime.initialize().timeout(const Duration(seconds: 15));
    await _waitUntil(() => replay.pull.pullCalls >= 2);
    expect(replay.runtime.state, E2eeChatContentRuntimeState.ready);
  });

  test('E2EE 内容运行时锚点安装后提交失败可按同一 bootstrap 幂等重放', () async {
    final harness = await _E2eeRuntimeHarness.create(
      seedMembershipAnchor: false,
      withSecurityBootstrap: true,
    );
    addTearDown(harness.close);
    final first = harness.createInstance(
      securityBootstrapCommitHandler: (_) async {
        throw StateError('bootstrap_commit_failed');
      },
    );

    await expectLater(first.runtime.initialize(), throwsStateError);
    expect(first.pull.pullCalls, 0);
    expect(first.transportSession, isNull);
    await first.runtime.close();

    var replayCommits = 0;
    final replay = harness.createInstance(
      securityBootstrapCommitHandler: (_) async => replayCommits++,
    );
    await replay.runtime.initialize().timeout(const Duration(seconds: 15));
    await _waitUntil(() => replay.pull.pullCalls >= 2);

    expect(replayCommits, 1);
    expect(replay.runtime.state, E2eeChatContentRuntimeState.ready);
  });

  test('E2EE 内容运行时拒绝用 bootstrap 覆盖冲突的本地成员锚点', () async {
    final harness = await _E2eeRuntimeHarness.create(
      seedMembershipAnchor: false,
      installConflictingMembershipAnchor: true,
      withSecurityBootstrap: true,
    );
    addTearDown(harness.close);
    var commitCalls = 0;
    final instance = harness.createInstance(
      securityBootstrapCommitHandler: (_) async => commitCalls++,
    );

    await expectLater(
      instance.runtime.initialize(),
      throwsA(isA<E2eeVerifiedMembershipAnchorConflict>()),
    );

    expect(commitCalls, 0);
    expect(instance.pull.pullCalls, 0);
    expect(instance.transportSession, isNull);
  });

  test('E2EE headless 运行时安装 bootstrap 并提交后才执行单次网络周期', () async {
    final harness = await _E2eeRuntimeHarness.create(
      seedMembershipAnchor: false,
      withSecurityBootstrap: true,
    );
    addTearDown(harness.close);
    final pull = _RuntimePullTransport(
      accountUserId: harness.session.userId,
      blockInitialPull: false,
    );
    final records = _RuntimeRecordTransport(
      accountUserId: harness.session.userId,
      actorDeviceId: harness.session.deviceId,
    );
    final client = CloudSyncClient.forTesting(baseUrl: harness.session.baseUrl);
    var transportCreated = false;
    final runtime = E2eeChatContentRuntime.takeHeadlessOwnership(
      session: harness.session,
      deviceStateStore: harness._deviceStateStore,
      secureCore: const KelivoSecureCore(),
      databaseGateway: harness._databaseGateway,
      databaseFile: harness._databaseFile,
      client: client,
      transportFactory: ({required client, required session}) {
        transportCreated = true;
        return E2eeChatContentTransports(records: records, pull: pull);
      },
    );
    runtime.bindSecurityBootstrapCommitHandler((pendingSession) async {
      expect(pendingSession.securityBootstrap, isNotNull);
      expect(transportCreated, isFalse);
      expect(pull.pullCalls, 0);
    });
    try {
      final report = await runtime.runSingleCycle(
        E2eeSyncExecutionBudget(
          maximumNetworkSteps: 17,
          maximumAttachmentBytes: 16 * 1024 * 1024,
          maximumDuration: const Duration(seconds: 5),
          abortInFlightNetwork: () => client.close(force: true),
        ),
      );

      expect(report.disposition, E2eeSyncCycleDisposition.completed);
      expect(transportCreated, isTrue);
      expect(pull.pullCalls, 2);
    } finally {
      await runtime.close();
    }
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

CloudSyncAccountSession _session({
  DateTime? tokenExpiresAt,
  CloudSyncSecurityBootstrap? securityBootstrap,
}) {
  return CloudSyncAccountSession(
    baseUrl: defaultCloudSyncBaseUrl,
    token: _fullToken,
    tokenExpiresAt: tokenExpiresAt ?? DateTime.utc(2100),
    keyEpoch: 1,
    authGeneration: securityBootstrap?.localMember.authGeneration ?? 0,
    sessionGeneration: 1,
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
    securityBootstrap: securityBootstrap,
  );
}

CloudSyncAuthenticatedSession _authenticatedSession({
  DateTime? tokenExpiresAt,
  int keyEpoch = 1,
  CloudSyncSecurityBootstrap? securityBootstrap,
}) {
  return CloudSyncAuthenticatedSession(
    token: _fullToken,
    tokenExpiresAt: tokenExpiresAt ?? DateTime.utc(2100),
    keyEpoch: keyEpoch,
    authGeneration: securityBootstrap?.localMember.authGeneration ?? 0,
    sessionGeneration: 1,
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
    securityState: securityBootstrap?.state,
    pairingReceipt: securityBootstrap?.pairingReceipt,
    securityBootstrap: securityBootstrap,
  );
}

CloudSyncSecurityBootstrap _registrationBootstrap() {
  final manifest = Uint8List(cloudSyncMembershipManifestMinimumBytes)
    ..fillRange(0, cloudSyncMembershipManifestMinimumBytes, 0x41);
  final state = CloudSyncAccountSecurityState(
    generation: 1,
    keyEpoch: 1,
    dataRekeyPhase: CloudSyncDataRekeyPhase.ready,
    membershipManifest: manifest,
    membershipManifestDigest: CloudSyncMembershipManifestDigest.fromBytes(
      Uint8List.fromList(sha256.convert(manifest).bytes),
    ),
    recoveryPublicKeyVersion: 1,
    recoveryPublicKey: Uint8List(cloudSyncRecoveryPublicKeyBytes)
      ..fillRange(0, cloudSyncRecoveryPublicKeyBytes, 0x42),
    recoveryCapsuleVersion: 1,
    recoveryCapsule: Uint8List(cloudSyncRecoveryCapsuleBytes)
      ..fillRange(0, cloudSyncRecoveryCapsuleBytes, 0x43),
    lastOperationId: '30000000-0000-4000-8000-000000000001',
    updatedAt: DateTime.utc(2026, 7, 29),
    envelopes: <CloudSyncAccountSecurityEnvelope>[
      CloudSyncAccountSecurityEnvelope(
        targetDeviceId: _deviceId,
        issuerDeviceId: _deviceId,
        envelopeVersion: 1,
        keyEpoch: 1,
        accountKeyEnvelope: Uint8List(cloudSyncAccountKeyEnvelopeBytes)
          ..fillRange(0, cloudSyncAccountKeyEnvelopeBytes, 0x44),
      ),
    ],
  );
  return CloudSyncSecurityBootstrap.firstRegistration(
    state: state,
    localMember: CloudSyncMembershipDeviceMaterial(
      deviceId: _deviceId,
      keyVersion: 1,
      authGeneration: 0,
      signingPublicKey: Uint8List(cloudSyncDevicePublicKeyBytes)
        ..fillRange(0, cloudSyncDevicePublicKeyBytes, 0x45),
      keyAgreementPublicKey: Uint8List(cloudSyncDevicePublicKeyBytes)
        ..fillRange(0, cloudSyncDevicePublicKeyBytes, 0x46),
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
        accountRootKey: await secureCore.generateAccountRootKey(
          userId: _runtimeUuidBytes(_userId),
          keyEpoch: 1,
        ),
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
    bool seedMembershipAnchor = true,
    bool installConflictingMembershipAnchor = false,
    bool withSecurityBootstrap = false,
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
    var session = CloudSyncAccountSession(
      baseUrl: 'https://runtime-$nonce.example.com',
      token: _fullToken,
      tokenExpiresAt: DateTime.utc(2100),
      keyEpoch: 1,
      authGeneration: 0,
      sessionGeneration: 1,
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
    final databaseGateway = ChatDatabaseGateway(cipher: testDatabaseCipher);
    final databaseFile = File(
      '${workspaceRoot.path}${Platform.pathSeparator}'
      '${AppDatabase.databaseFileName}',
    );
    if (seedDeviceState) {
      final bootstrap = await _seedRuntimeDeviceState(
        secureCore: secureCore,
        store: deviceStateStore,
        session: session,
        databaseGateway: databaseGateway,
        databaseFile: databaseFile,
        installMembershipAnchor: seedMembershipAnchor,
        installConflictingMembershipAnchor: installConflictingMembershipAnchor,
        createSecurityBootstrap: withSecurityBootstrap,
      );
      if (bootstrap != null) {
        session = _runtimeSessionWithBootstrap(session, bootstrap);
      }
    }
    return _E2eeRuntimeHarness._(
      root: root,
      session: session,
      deviceStateStore: deviceStateStore,
      databaseGateway: databaseGateway,
      databaseFile: databaseFile,
    );
  }

  _E2eeRuntimeInstance createInstance({
    bool blockInitialPull = false,
    bool withConfigProviders = true,
    CloudSyncException? pullFailure,
    CloudSyncSecurityBootstrapCommitHandler? securityBootstrapCommitHandler,
    CloudSyncAccountSession? sessionOverride,
    void Function()? onTransportCreated,
  }) {
    final activeSession = sessionOverride ?? session;
    final pull = _RuntimePullTransport(
      accountUserId: activeSession.userId,
      blockInitialPull: blockInitialPull,
      failure: pullFailure,
    );
    final records = _RuntimeRecordTransport(
      accountUserId: activeSession.userId,
      actorDeviceId: activeSession.deviceId,
    );
    final capture = _TransportSessionCapture();
    E2eeChatContentTransports createTransports({
      required CloudSyncClient client,
      required CloudSyncAuthenticatedSession session,
    }) {
      onTransportCreated?.call();
      capture.session = session;
      return E2eeChatContentTransports(records: records, pull: pull);
    }

    final runtime = E2eeChatContentRuntime.takeOwnership(
      session: activeSession,
      deviceStateStore: _deviceStateStore,
      secureCore: const KelivoSecureCore(),
      databaseGateway: _databaseGateway,
      databaseFile: _databaseFile,
      client: CloudSyncClient.forTesting(baseUrl: activeSession.baseUrl),
      transportFactory: createTransports,
    );
    if (securityBootstrapCommitHandler != null) {
      runtime.bindSecurityBootstrapCommitHandler(
        securityBootstrapCommitHandler,
      );
    }
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

Future<CloudSyncSecurityBootstrap?> _seedRuntimeDeviceState({
  required KelivoSecureCore secureCore,
  required DeviceStateBlobStore store,
  required CloudSyncAccountSession session,
  required ChatDatabaseGateway databaseGateway,
  required File databaseFile,
  required bool installMembershipAnchor,
  required bool installConflictingMembershipAnchor,
  required bool createSecurityBootstrap,
}) async {
  final key = await secureCore.createSlot(
    E2eeDeviceStateAccess.deriveSlotId(
      normalizedBaseUrl: session.baseUrl,
      normalizedLoginName: session.loginName,
    ),
  );
  final identity = await secureCore.generateDeviceIdentity();
  final ark = await secureCore.generateAccountRootKey(
    userId: _runtimeUuidBytes(session.userId),
    keyEpoch: session.keyEpoch,
  );
  Uint8List? blob;
  ChatDatabaseLease? databaseLease;
  CloudSyncSecurityBootstrap? bootstrap;
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
    final publicKeys = await secureCore.readDevicePublicKeys(identity);
    final recoveryPublicKey = Uint8List(32)..fillRange(0, 32, 0x71);
    final recoveryCapsule = Uint8List(cloudSyncRecoveryCapsuleBytes)
      ..fillRange(0, cloudSyncRecoveryCapsuleBytes, 0x72);
    final membership = await const E2eeAccountTrustManifestModule().create(
      ark: ark,
      change: E2eeInitializeMembershipChange(
        userId: session.userId,
        operationId: '30000000-0000-4000-8000-000000000001',
        member: E2eeMembershipDeviceInput(
          deviceId: session.deviceId,
          keyVersion: session.deviceKeyVersion,
          authGeneration: session.authGeneration,
          signingPublicKey: publicKeys.signingPublicKey,
          keyAgreementPublicKey: publicKeys.keyAgreementPublicKey,
        ),
        recoveryPublicKeyVersion: 1,
        recoveryPublicKey: recoveryPublicKey,
        recoveryCapsuleVersion: 1,
        recoveryCapsule: recoveryCapsule,
      ),
    );
    if (installMembershipAnchor || installConflictingMembershipAnchor) {
      databaseLease = await databaseGateway.acquire(databaseFile);
      var installedMembership = membership;
      KelivoDeviceIdentityHandle? conflictingIdentity;
      try {
        if (installConflictingMembershipAnchor) {
          conflictingIdentity = await secureCore.generateDeviceIdentity();
          final conflictingPublicKeys = await secureCore.readDevicePublicKeys(
            conflictingIdentity,
          );
          installedMembership = await const E2eeAccountTrustManifestModule()
              .create(
                ark: ark,
                change: E2eeInitializeMembershipChange(
                  userId: session.userId,
                  operationId: '30000000-0000-4000-8000-000000000002',
                  member: E2eeMembershipDeviceInput(
                    deviceId: session.deviceId,
                    keyVersion: session.deviceKeyVersion,
                    authGeneration: session.authGeneration,
                    signingPublicKey: conflictingPublicKeys.signingPublicKey,
                    keyAgreementPublicKey:
                        conflictingPublicKeys.keyAgreementPublicKey,
                  ),
                  recoveryPublicKeyVersion: 1,
                  recoveryPublicKey: recoveryPublicKey,
                  recoveryCapsuleVersion: 1,
                  recoveryCapsule: recoveryCapsule,
                ),
              );
        }
        await databaseLease.repository.e2eeVerifiedMembershipAnchorCommands
            .install(
              membership: installedMembership,
              now: DateTime.utc(2026, 7, 29),
            );
      } finally {
        final identityToClose = conflictingIdentity;
        if (identityToClose != null) {
          await secureCore.closeDeviceIdentity(identityToClose);
        }
      }
    }
    if (createSecurityBootstrap) {
      final state = CloudSyncAccountSecurityState(
        generation: membership.securityGeneration,
        keyEpoch: membership.keyEpoch,
        dataRekeyPhase: CloudSyncDataRekeyPhase.ready,
        membershipManifest: membership.manifest,
        membershipManifestDigest: CloudSyncMembershipManifestDigest.fromBytes(
          membership.digest,
        ),
        recoveryPublicKeyVersion: membership.recoveryPublicKeyVersion,
        recoveryPublicKey: recoveryPublicKey,
        recoveryCapsuleVersion: membership.recoveryCapsuleVersion,
        recoveryCapsule: recoveryCapsule,
        lastOperationId: membership.operationId,
        updatedAt: DateTime.utc(2026, 7, 29),
        envelopes: <CloudSyncAccountSecurityEnvelope>[
          CloudSyncAccountSecurityEnvelope(
            targetDeviceId: session.deviceId,
            issuerDeviceId: session.deviceId,
            envelopeVersion: 1,
            keyEpoch: session.keyEpoch,
            accountKeyEnvelope: Uint8List(cloudSyncAccountKeyEnvelopeBytes)
              ..fillRange(0, cloudSyncAccountKeyEnvelopeBytes, 0x73),
          ),
        ],
      );
      bootstrap = CloudSyncSecurityBootstrap.firstRegistration(
        state: state,
        localMember: CloudSyncMembershipDeviceMaterial(
          deviceId: session.deviceId,
          keyVersion: session.deviceKeyVersion,
          authGeneration: session.authGeneration,
          signingPublicKey: publicKeys.signingPublicKey,
          keyAgreementPublicKey: publicKeys.keyAgreementPublicKey,
        ),
      );
    }
  } finally {
    await databaseLease?.release();
    final sealedBlob = blob;
    if (sealedBlob != null) sealedBlob.fillRange(0, sealedBlob.length, 0);
    await secureCore.closeAccountRootKey(ark);
    await secureCore.closeDeviceIdentity(identity);
    await secureCore.close(key);
  }
  return bootstrap;
}

CloudSyncAccountSession _runtimeSessionWithBootstrap(
  CloudSyncAccountSession session,
  CloudSyncSecurityBootstrap bootstrap,
) {
  return CloudSyncAccountSession(
    baseUrl: session.baseUrl,
    token: session.token,
    tokenExpiresAt: session.tokenExpiresAt,
    keyEpoch: session.keyEpoch,
    authGeneration: session.authGeneration,
    sessionGeneration: session.sessionGeneration,
    userId: session.userId,
    loginName: session.loginName,
    displayName: session.displayName,
    role: session.role,
    attachmentQuotaBytes: session.attachmentQuotaBytes,
    deviceId: session.deviceId,
    deviceName: session.deviceName,
    platform: session.platform,
    clientVersion: session.clientVersion,
    deviceKeyVersion: session.deviceKeyVersion,
    deviceCreatedAt: session.deviceCreatedAt,
    securityBootstrap: bootstrap,
  );
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
  _FakeCloudSyncContentRuntime({
    this.initializeFailure,
    this.closeFailure,
    this.bootstrapSessionToCommit,
  });

  final Object? initializeFailure;
  final Object? closeFailure;
  final CloudSyncAccountSession? bootstrapSessionToCommit;
  int initializeCalls = 0;
  int closeCalls = 0;
  int bootstrapCommitCalls = 0;
  CloudSyncSecurityBootstrapCommitHandler? _securityBootstrapCommitHandler;
  CloudSyncTerminalAuthenticationHandler? _terminalAuthenticationHandler;

  @override
  void bindSecurityBootstrapCommitHandler(
    CloudSyncSecurityBootstrapCommitHandler handler,
  ) {
    if (_securityBootstrapCommitHandler != null) {
      throw StateError('security_bootstrap_commit_handler_already_bound');
    }
    _securityBootstrapCommitHandler = handler;
  }

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
    final bootstrapSession = bootstrapSessionToCommit;
    if (bootstrapSession != null) {
      final handler = _securityBootstrapCommitHandler;
      if (handler == null) {
        throw StateError('security_bootstrap_commit_handler_not_bound');
      }
      bootstrapCommitCalls++;
      await handler(bootstrapSession);
    }
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
    required CloudSyncGenesisSecurityState securityState,
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
    required CloudSyncDevicePairingMembershipCommit membershipCommit,
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
    required CloudSyncFullSessionToken sessionToken,
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
  Future<CloudSyncAccountSecurityState> getSecurityState() {
    throw UnsupportedError('unexpected_security_state_get');
  }

  @override
  Future<CloudSyncAccountSecurityHistoryPage> listSecurityStateHistory({
    int afterGeneration = 0,
    int pageSize = 20,
  }) {
    throw UnsupportedError('unexpected_security_state_history_list');
  }

  @override
  Future<CloudSyncDeviceRotationResult> commitDeviceRotation(
    CloudSyncDeviceRotationRequest request,
  ) {
    throw UnsupportedError('unexpected_device_rotation_commit');
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

final class _RecordingMobileBackgroundSchedulerPlatform
    implements E2eeMobileBackgroundSchedulerPlatform {
  _RecordingMobileBackgroundSchedulerPlatform({
    this.enableRelease,
    this.enableError,
  });

  final Completer<void>? enableRelease;
  final Object? enableError;
  final List<String> events = <String>[];
  int enableCalls = 0;
  int disableCalls = 0;
  int _concurrentCalls = 0;
  int maximumConcurrentCalls = 0;

  @override
  Future<void> enable() async {
    enableCalls++;
    await _run('enable', release: enableRelease, error: enableError);
  }

  @override
  Future<void> disable() => _run('disable');

  Future<void> _run(
    String operation, {
    Completer<void>? release,
    Object? error,
  }) async {
    events.add(operation);
    if (operation == 'disable') disableCalls++;
    _concurrentCalls++;
    if (_concurrentCalls > maximumConcurrentCalls) {
      maximumConcurrentCalls = _concurrentCalls;
    }
    try {
      if (release != null) await release.future;
      if (error != null) throw error;
    } finally {
      _concurrentCalls--;
    }
  }
}

final class _TestMobileBackgroundAccountState extends ChangeNotifier
    implements E2eeMobileBackgroundSyncAccountState {
  bool _signedIn = false;
  bool _contentSyncEnabled = false;

  @override
  bool get signedIn => _signedIn;

  @override
  bool get contentSyncEnabled => _contentSyncEnabled;

  void update({required bool signedIn, required bool contentSyncEnabled}) {
    _signedIn = signedIn;
    _contentSyncEnabled = contentSyncEnabled;
    notifyListeners();
  }
}

final class _TrackedSyncCancellationSignal
    implements E2eeSyncCancellationSignal {
  final Set<void Function()> _listeners = <void Function()>{};
  bool _cancelled = false;
  int registrationCount = 0;
  int unregistrationCount = 0;

  int get activeListenerCount => _listeners.length;

  @override
  E2eeSyncCancellationRegistration register(void Function() onCancelled) {
    registrationCount++;
    _listeners.add(onCancelled);
    if (_cancelled) onCancelled();
    return _TrackedSyncCancellationRegistration(() {
      if (_listeners.remove(onCancelled)) unregistrationCount++;
    });
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in _listeners.toList(growable: false)) {
      listener();
    }
  }
}

final class _TrackedSyncCancellationRegistration
    implements E2eeSyncCancellationRegistration {
  _TrackedSyncCancellationRegistration(this._onUnregister);

  final void Function() _onUnregister;
  bool _unregistered = false;

  @override
  void unregister() {
    if (_unregistered) return;
    _unregistered = true;
    _onUnregister();
  }
}

final class _FixedBackgroundHost implements E2eeBackgroundSyncHost {
  const _FixedBackgroundHost(this.acquisition);

  final E2eeBackgroundWorkspaceAcquisition acquisition;

  @override
  Future<E2eeBackgroundWorkspaceAcquisition> tryAcquireWorkspace(
    E2eeSyncExecutionBudget executionBudget,
  ) async {
    return acquisition;
  }
}

final class _DelayedBackgroundHost implements E2eeBackgroundSyncHost {
  _DelayedBackgroundHost(this.acquisition, this.delay);

  final E2eeBackgroundWorkspaceAcquisition acquisition;
  final Duration delay;
  int acquisitionCalls = 0;

  @override
  Future<E2eeBackgroundWorkspaceAcquisition> tryAcquireWorkspace(
    E2eeSyncExecutionBudget executionBudget,
  ) async {
    acquisitionCalls++;
    await Future<void>.delayed(delay);
    return acquisition;
  }
}

final class _PendingBackgroundHost implements E2eeBackgroundSyncHost {
  _PendingBackgroundHost(this.acquisition);

  final Future<E2eeBackgroundWorkspaceAcquisition> acquisition;
  int acquisitionCalls = 0;

  @override
  Future<E2eeBackgroundWorkspaceAcquisition> tryAcquireWorkspace(
    E2eeSyncExecutionBudget executionBudget,
  ) {
    acquisitionCalls++;
    return acquisition;
  }
}

final class _BlockingBackgroundHost implements E2eeBackgroundSyncHost {
  _BlockingBackgroundHost(this.acquisition, this.blockDuration);

  final E2eeBackgroundWorkspaceAcquisition acquisition;
  final Duration blockDuration;
  int acquisitionCalls = 0;

  @override
  Future<E2eeBackgroundWorkspaceAcquisition> tryAcquireWorkspace(
    E2eeSyncExecutionBudget executionBudget,
  ) {
    acquisitionCalls++;
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < blockDuration) {}
    return Future<E2eeBackgroundWorkspaceAcquisition>.value(acquisition);
  }
}

final class _ExclusiveBackgroundHost implements E2eeBackgroundSyncHost {
  _ExclusiveBackgroundHost(this._workspace);

  final E2eeBackgroundSyncWorkspace _workspace;
  bool _held = false;
  int _concurrentWorkspaces = 0;
  int maximumConcurrentWorkspaces = 0;

  @override
  Future<E2eeBackgroundWorkspaceAcquisition> tryAcquireWorkspace(
    E2eeSyncExecutionBudget executionBudget,
  ) async {
    if (_held) return const E2eeBackgroundWorkspaceBusy();
    _held = true;
    _concurrentWorkspaces++;
    if (_concurrentWorkspaces > maximumConcurrentWorkspaces) {
      maximumConcurrentWorkspaces = _concurrentWorkspaces;
    }
    return E2eeBackgroundWorkspaceAcquired(
      _TrackedBackgroundWorkspace(
        _workspace,
        onClose: () {
          _concurrentWorkspaces--;
          _held = false;
        },
      ),
    );
  }
}

final class _TrackedBackgroundWorkspace implements E2eeBackgroundSyncWorkspace {
  _TrackedBackgroundWorkspace(this._delegate, {required this.onClose});

  final E2eeBackgroundSyncWorkspace _delegate;
  final void Function() onClose;
  bool _closed = false;

  @override
  CloudSyncAccountSession? get session => _delegate.session;

  @override
  Future<E2eeBackgroundContentAcquisition> tryAcquireContent(
    E2eeSyncExecutionBudget executionBudget,
  ) {
    return _delegate.tryAcquireContent(executionBudget);
  }

  @override
  Future<void> persistSessionTombstone() {
    return _delegate.persistSessionTombstone();
  }

  @override
  Future<void> closeWorkspaceLease() async {
    if (_closed) return;
    _closed = true;
    try {
      await _delegate.closeWorkspaceLease();
    } finally {
      onClose();
    }
  }
}

final class _FakeBackgroundWorkspace implements E2eeBackgroundSyncWorkspace {
  _FakeBackgroundWorkspace({
    required this.events,
    required this.session,
    required this.contentAcquisition,
    this.persistSessionBarrier,
  });

  final List<String> events;
  final E2eeBackgroundContentAcquisition contentAcquisition;
  final Future<void>? persistSessionBarrier;
  @override
  CloudSyncAccountSession? session;
  int contentAcquisitionCalls = 0;
  int workspaceCloseCalls = 0;
  bool _closed = false;

  @override
  Future<E2eeBackgroundContentAcquisition> tryAcquireContent(
    E2eeSyncExecutionBudget executionBudget,
  ) async {
    contentAcquisitionCalls++;
    events.add('content-acquire');
    return contentAcquisition;
  }

  @override
  Future<void> persistSessionTombstone() async {
    final barrier = persistSessionBarrier;
    if (barrier != null) {
      events.add('session-tombstone-start');
      await barrier;
    }
    events.add('session-tombstone');
    session = null;
  }

  @override
  Future<void> closeWorkspaceLease() async {
    workspaceCloseCalls++;
    if (workspaceCloseCalls > 1) {
      throw StateError('background_workspace_closed_more_than_once');
    }
    if (_closed) return;
    _closed = true;
    events.add('workspace-close');
  }
}

final class _PendingContentBackgroundWorkspace
    implements E2eeBackgroundSyncWorkspace {
  _PendingContentBackgroundWorkspace({
    required this.events,
    required this.session,
    required this.acquisition,
  });

  final List<String> events;
  final Future<E2eeBackgroundContentAcquisition> acquisition;
  @override
  CloudSyncAccountSession? session;
  int workspaceCloseCalls = 0;

  @override
  Future<E2eeBackgroundContentAcquisition> tryAcquireContent(
    E2eeSyncExecutionBudget executionBudget,
  ) {
    events.add('content-acquire');
    return acquisition;
  }

  @override
  Future<void> persistSessionTombstone() async {
    events.add('session-tombstone');
    session = null;
  }

  @override
  Future<void> closeWorkspaceLease() async {
    workspaceCloseCalls++;
    if (workspaceCloseCalls > 1) {
      throw StateError('pending_background_workspace_closed_more_than_once');
    }
    events.add('workspace-close');
  }
}

typedef _FakeBackgroundRun =
    Future<E2eeSyncCycleReport> Function(
      E2eeSyncExecutionBudget executionBudget,
    );

final class _FakeBackgroundContent implements E2eeBackgroundSyncContent {
  _FakeBackgroundContent({
    required this.events,
    required this.run,
    this.closeRuntimeDelay = Duration.zero,
    this.closeRuntimeBarrier,
  });

  final List<String> events;
  final _FakeBackgroundRun run;
  final Duration closeRuntimeDelay;
  final Future<void>? closeRuntimeBarrier;
  int runCalls = 0;
  int closeRuntimeCalls = 0;
  int closeAccountLeaseCalls = 0;
  bool _runtimeClosed = false;
  bool _accountLeaseClosed = false;

  @override
  Future<E2eeSyncCycleReport> runOnce({
    required E2eeSyncExecutionBudget executionBudget,
  }) {
    runCalls++;
    events.add('run');
    return run(executionBudget);
  }

  @override
  void abortInFlightNetwork() {
    events.add('network-abort');
  }

  @override
  Future<void> closeRuntime() async {
    closeRuntimeCalls++;
    if (closeRuntimeCalls > 1) {
      throw StateError('background_runtime_closed_more_than_once');
    }
    if (_runtimeClosed) return;
    _runtimeClosed = true;
    final barrier = closeRuntimeBarrier;
    if (barrier != null) {
      events.add('runtime-close-start');
      await barrier;
    }
    if (closeRuntimeDelay > Duration.zero) {
      await Future<void>.delayed(closeRuntimeDelay);
    }
    events.add('runtime-close');
  }

  @override
  Future<void> closeAccountLease() async {
    closeAccountLeaseCalls++;
    if (closeAccountLeaseCalls > 1) {
      throw StateError('background_account_lease_closed_more_than_once');
    }
    if (_accountLeaseClosed) return;
    _accountLeaseClosed = true;
    events.add('account-lease-close');
  }
}

E2eeSyncCycleReport _backgroundCycleReport(
  E2eeSyncCycleDisposition disposition,
) {
  return E2eeSyncCycleReport(
    disposition: disposition,
    catchUpPullPages: 1,
    sealedRecords: 0,
    flushReport: const E2eeSyncFlushReport.idle(),
    finalPullPages: disposition == E2eeSyncCycleDisposition.completed ? 1 : 0,
  );
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
