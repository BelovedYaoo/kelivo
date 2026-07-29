import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'e2ee_background_sync_runner.dart';
import 'e2ee_sync_execution_budget.dart';

const e2eeMobileBackgroundTaskUniqueName = 'psyche.kelivo.e2ee-sync.periodic';
const e2eeMobileBackgroundTaskName = 'e2ee-background-sync';

const _mobileBackgroundSyncFrequency = Duration(minutes: 15);
const _mobileBackgroundSyncLimits = E2eeBackgroundSyncLimits(
  maximumDuration: Duration(seconds: 20),
);

typedef E2eeBackgroundSyncRunnerFactory = E2eeBackgroundSyncRunner Function();

final class E2eeMobileBackgroundTaskExecutor {
  factory E2eeMobileBackgroundTaskExecutor({
    required E2eeBackgroundSyncRunnerFactory runnerFactory,
    required Future<void> Function() cancelScheduledTask,
    E2eeBackgroundSyncLimits limits = _mobileBackgroundSyncLimits,
  }) {
    return E2eeMobileBackgroundTaskExecutor._(
      runnerFactory,
      cancelScheduledTask,
      limits,
    );
  }

  E2eeMobileBackgroundTaskExecutor._(
    this._runnerFactory,
    this._cancelScheduledTask,
    this._limits,
  );

  final E2eeBackgroundSyncRunnerFactory _runnerFactory;
  final Future<void> Function() _cancelScheduledTask;
  final E2eeBackgroundSyncLimits _limits;
  Future<bool>? _inFlight;
  E2eeSyncCancellationController? _inFlightCancellation;
  final List<E2eeSyncCancellationRegistration> _cancellationLinks =
      <E2eeSyncCancellationRegistration>[];

  Future<bool> execute(
    String taskName, {
    E2eeSyncCancellationSignal? cancellationSignal,
  }) {
    if (taskName != e2eeMobileBackgroundTaskName &&
        taskName != e2eeMobileBackgroundTaskUniqueName) {
      throw UnsupportedError('e2ee_mobile_background_task_unknown');
    }

    final active = _inFlight;
    if (active != null) {
      _linkCancellation(cancellationSignal);
      return active;
    }

    final cancellation = E2eeSyncCancellationController();
    _inFlightCancellation = cancellation;
    _linkCancellation(cancellationSignal);
    final run = _executeOnce(cancellation);
    _inFlight = run;
    return run.whenComplete(() {
      if (!identical(_inFlight, run)) return;
      _inFlight = null;
      _inFlightCancellation = null;
      final links = _cancellationLinks.toList(growable: false);
      _cancellationLinks.clear();
      for (final link in links) {
        link.unregister();
      }
    });
  }

  Future<bool> _executeOnce(E2eeSyncCancellationSignal cancellation) async {
    final outcome = await _runnerFactory().run(
      limits: _limits,
      cancellationSignal: cancellation,
    );
    switch (outcome.disposition) {
      case E2eeBackgroundSyncDisposition.noSession:
      case E2eeBackgroundSyncDisposition.authenticationRetired:
        await _cancelScheduledTask();
        return true;
      case E2eeBackgroundSyncDisposition.workspaceBusy:
      case E2eeBackgroundSyncDisposition.completed:
      case E2eeBackgroundSyncDisposition.budgetExhausted:
        return true;
      case E2eeBackgroundSyncDisposition.blockedByKeyEpoch:
        return false;
    }
  }

  void _linkCancellation(E2eeSyncCancellationSignal? source) {
    final target = _inFlightCancellation;
    if (source == null || target == null) return;
    _cancellationLinks.add(source.register(target.cancel));
  }
}

E2eeMobileBackgroundTaskExecutor? _productionTaskExecutor;

Future<bool> _executeProductionBackgroundTask(
  String taskName,
  BackgroundTaskContext context,
) async {
  final productionFactory = E2eeBackgroundProductionRunnerFactory.tryCreate();
  if (productionFactory == null) {
    await Workmanager().cancelByUniqueName(e2eeMobileBackgroundTaskUniqueName);
    return false;
  }
  final executor = _productionTaskExecutor ??= E2eeMobileBackgroundTaskExecutor(
    runnerFactory: productionFactory.createRunner,
    cancelScheduledTask: () =>
        Workmanager().cancelByUniqueName(e2eeMobileBackgroundTaskUniqueName),
  );
  return executor.execute(
    taskName,
    cancellationSignal: _WorkmanagerCancellationSignal(context),
  );
}

@pragma('vm:entry-point')
void e2eeMobileBackgroundCallbackDispatcher() {
  Workmanager().executeTask((taskName, _, context) {
    return _executeProductionBackgroundTask(taskName, context);
  });
}

final class _WorkmanagerCancellationSignal
    implements E2eeSyncCancellationSignal {
  const _WorkmanagerCancellationSignal(this._context);

  final BackgroundTaskContext _context;

  @override
  E2eeSyncCancellationRegistration register(void Function() onCancelled) {
    return _WorkmanagerSyncCancellationRegistration(
      _context.registerCancellation(onCancelled),
    );
  }
}

final class _WorkmanagerSyncCancellationRegistration
    implements E2eeSyncCancellationRegistration {
  const _WorkmanagerSyncCancellationRegistration(this._registration);

  final BackgroundTaskCancellationRegistration _registration;

  @override
  void unregister() => _registration.unregister();
}

abstract interface class E2eeMobileBackgroundSchedulerPlatform {
  Future<void> enable();

  Future<void> disable();
}

final class E2eeMobileBackgroundSyncScheduler {
  factory E2eeMobileBackgroundSyncScheduler.forCurrentPlatform() {
    final supported =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    return E2eeMobileBackgroundSyncScheduler._(
      supported
          ? _WorkmanagerMobileBackgroundSchedulerPlatform()
          : const _UnsupportedMobileBackgroundSchedulerPlatform(),
    );
  }

  @visibleForTesting
  E2eeMobileBackgroundSyncScheduler.forTesting(
    E2eeMobileBackgroundSchedulerPlatform platform,
  ) : this._(platform);

  E2eeMobileBackgroundSyncScheduler._(this._platform);

  final E2eeMobileBackgroundSchedulerPlatform _platform;
  bool? _desiredEnabled;
  bool? _appliedEnabled;
  Future<void>? _activeReconciliation;

  Future<void> setEnabled(bool enabled) {
    _desiredEnabled = enabled;
    final active = _activeReconciliation;
    if (active != null) return active;

    final run = _reconcile();
    _activeReconciliation = run;
    return run.whenComplete(() {
      if (identical(_activeReconciliation, run)) {
        _activeReconciliation = null;
      }
    });
  }

  Future<void> _reconcile() async {
    Object? primaryError;
    StackTrace? primaryStackTrace;
    while (_appliedEnabled != _desiredEnabled) {
      final target = _desiredEnabled!;
      try {
        if (target) {
          await _platform.enable();
        } else {
          await _platform.disable();
        }
        _appliedEnabled = target;
      } catch (error, stackTrace) {
        primaryError ??= error;
        primaryStackTrace ??= stackTrace;
        if (_desiredEnabled == target) break;
      }
    }
    if (primaryError != null) {
      Error.throwWithStackTrace(primaryError, primaryStackTrace!);
    }
  }
}

final class _WorkmanagerMobileBackgroundSchedulerPlatform
    implements E2eeMobileBackgroundSchedulerPlatform {
  Future<void>? _initialization;

  Future<void> _initialize() {
    final active = _initialization;
    if (active != null) return active;

    final run = Workmanager().initialize(
      e2eeMobileBackgroundCallbackDispatcher,
    );
    _initialization = run;
    return run.catchError((Object error, StackTrace stackTrace) {
      if (identical(_initialization, run)) _initialization = null;
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  @override
  Future<void> enable() async {
    if (E2eeBackgroundProductionRunnerFactory.tryCreate() == null) {
      throw StateError('e2ee_background_verified_binding_factory_unavailable');
    }
    await _initialize();
    await Workmanager().registerPeriodicTask(
      e2eeMobileBackgroundTaskUniqueName,
      e2eeMobileBackgroundTaskName,
      frequency: _mobileBackgroundSyncFrequency,
      initialDelay: _mobileBackgroundSyncFrequency,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
        requiresStorageNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
    final scheduled = await Workmanager().isScheduledByUniqueName(
      e2eeMobileBackgroundTaskUniqueName,
    );
    if (!scheduled) {
      throw StateError('e2ee_mobile_background_task_registration_unconfirmed');
    }
  }

  @override
  Future<void> disable() {
    return Workmanager().cancelByUniqueName(e2eeMobileBackgroundTaskUniqueName);
  }
}

final class _UnsupportedMobileBackgroundSchedulerPlatform
    implements E2eeMobileBackgroundSchedulerPlatform {
  const _UnsupportedMobileBackgroundSchedulerPlatform();

  @override
  Future<void> disable() async {}

  @override
  Future<void> enable() async {}
}

abstract interface class E2eeMobileBackgroundSyncAccountState
    implements Listenable {
  bool get signedIn;

  bool get contentSyncEnabled;
}

final class E2eeMobileBackgroundSyncLifecycle {
  factory E2eeMobileBackgroundSyncLifecycle({
    required E2eeMobileBackgroundSyncAccountState accountState,
    required E2eeMobileBackgroundSyncScheduler scheduler,
  }) {
    return E2eeMobileBackgroundSyncLifecycle._(accountState, scheduler);
  }

  E2eeMobileBackgroundSyncLifecycle._(this._accountState, this._scheduler) {
    _accountState.addListener(_reconcile);
    _reconcile();
  }

  final E2eeMobileBackgroundSyncAccountState _accountState;
  final E2eeMobileBackgroundSyncScheduler _scheduler;
  bool _disposed = false;

  void _reconcile() {
    if (_disposed) return;
    final enabled = _accountState.signedIn && _accountState.contentSyncEnabled;
    unawaited(
      _scheduler.setEnabled(enabled).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        developer.log(
          enabled ? '注册移动端 E2EE 后台同步失败' : '取消移动端 E2EE 后台同步失败',
          name: 'Kelivo.E2eeMobileBackgroundSync',
          level: 1000,
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _accountState.removeListener(_reconcile);
  }
}
