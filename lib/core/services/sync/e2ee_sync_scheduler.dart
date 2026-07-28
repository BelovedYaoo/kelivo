import 'dart:async';
import 'dart:developer' as developer;

import 'e2ee_sync_outbox.dart';

typedef E2eeSyncRunPullBatch = Future<T> Function<T>(Future<T> Function() pull);

enum E2eeSyncPullStepDisposition { complete, more, keyEpochUnavailable }

typedef E2eeSyncPullOnce =
    Future<E2eeSyncPullStepDisposition> Function({required int limit});
typedef E2eeSyncSealNext = Future<E2eeSyncSealStatus> Function();
typedef E2eeSyncFlushOnce = Future<E2eeSyncFlushReport> Function();
typedef E2eeSyncTimerFactory =
    Timer Function(Duration delay, void Function() callback);
typedef E2eeSyncBackgroundErrorReporter =
    void Function(Object error, StackTrace stackTrace);

enum E2eeSyncCycleDisposition { completed, keyEpochUnavailable }

final class E2eeSyncCycleReport {
  const E2eeSyncCycleReport({
    required this.disposition,
    required this.catchUpPullPages,
    required this.sealedRecords,
    required this.flushReport,
    required this.finalPullPages,
  });

  final E2eeSyncCycleDisposition disposition;
  final int catchUpPullPages;
  final int sealedRecords;
  final E2eeSyncFlushReport flushReport;
  final int finalPullPages;
}

/// 固定同步阶段与工作上限，避免一次后台唤醒长期占用数据库或网络。
final class E2eeSyncCycleRunner {
  E2eeSyncCycleRunner({
    required this._runPullBatch,
    required this._pullOnce,
    required this._sealNext,
    required this._flushOnce,
    this.pullPageLimit = 10,
    this.maximumPullPagesPerPhase = 4,
    this.maximumSealAttempts = 10,
  }) {
    if (pullPageLimit < 1 || pullPageLimit > 10) {
      throw RangeError.range(pullPageLimit, 1, 10, 'pullPageLimit');
    }
    if (maximumPullPagesPerPhase < 1) {
      throw RangeError.range(
        maximumPullPagesPerPhase,
        1,
        null,
        'maximumPullPagesPerPhase',
      );
    }
    if (maximumSealAttempts < 1) {
      throw RangeError.range(
        maximumSealAttempts,
        1,
        null,
        'maximumSealAttempts',
      );
    }
  }

  final E2eeSyncRunPullBatch _runPullBatch;
  final E2eeSyncPullOnce _pullOnce;
  final E2eeSyncSealNext _sealNext;
  final E2eeSyncFlushOnce _flushOnce;
  final int pullPageLimit;
  final int maximumPullPagesPerPhase;
  final int maximumSealAttempts;

  Future<E2eeSyncCycleReport> run() async {
    final catchUp = await _runBoundedPullPhase();
    if (catchUp.keyEpochUnavailable) {
      return E2eeSyncCycleReport(
        disposition: E2eeSyncCycleDisposition.keyEpochUnavailable,
        catchUpPullPages: catchUp.pages,
        sealedRecords: 0,
        flushReport: const E2eeSyncFlushReport.idle(),
        finalPullPages: 0,
      );
    }

    var sealedRecords = 0;
    for (var attempt = 0; attempt < maximumSealAttempts; attempt++) {
      final status = await _sealNext();
      if (status == E2eeSyncSealStatus.sealed) {
        sealedRecords++;
        continue;
      }
      if (status == E2eeSyncSealStatus.raced) continue;
      break;
    }

    final flushReport = await _flushOnce();
    if (flushReport.deferred > 0) {
      return E2eeSyncCycleReport(
        disposition: E2eeSyncCycleDisposition.keyEpochUnavailable,
        catchUpPullPages: catchUp.pages,
        sealedRecords: sealedRecords,
        flushReport: flushReport,
        finalPullPages: 0,
      );
    }

    final finalPull = await _runBoundedPullPhase();
    return E2eeSyncCycleReport(
      disposition: finalPull.keyEpochUnavailable
          ? E2eeSyncCycleDisposition.keyEpochUnavailable
          : E2eeSyncCycleDisposition.completed,
      catchUpPullPages: catchUp.pages,
      sealedRecords: sealedRecords,
      flushReport: flushReport,
      finalPullPages: finalPull.pages,
    );
  }

  Future<({int pages, bool keyEpochUnavailable})> _runBoundedPullPhase() {
    return _runPullBatch<({int pages, bool keyEpochUnavailable})>(() async {
      var pages = 0;
      for (; pages < maximumPullPagesPerPhase; pages++) {
        final disposition = await _pullOnce(limit: pullPageLimit);
        if (disposition == E2eeSyncPullStepDisposition.keyEpochUnavailable) {
          return (pages: pages + 1, keyEpochUnavailable: true);
        }
        if (disposition == E2eeSyncPullStepDisposition.complete) {
          return (pages: pages + 1, keyEpochUnavailable: false);
        }
      }
      return (pages: pages, keyEpochUnavailable: false);
    });
  }
}

enum E2eeSyncSchedulerState {
  notStarted,
  running,
  polling,
  retrying,
  keyEpochPaused,
  closing,
  closed,
}

/// 串行化所有同步周期，并将高频本地唤醒压缩为至多一个后继周期。
final class E2eeSyncScheduler {
  E2eeSyncScheduler({
    required this._cycleRunner,
    Duration pollInterval = const Duration(seconds: 30),
    Duration initialRetryDelay = const Duration(seconds: 1),
    Duration maximumRetryDelay = const Duration(minutes: 5),
    this._timerFactory = _defaultTimerFactory,
    this._errorReporter = _defaultErrorReporter,
  }) : _pollInterval = _requirePositiveDuration(pollInterval, 'pollInterval'),
       _initialRetryDelay = _requirePositiveDuration(
         initialRetryDelay,
         'initialRetryDelay',
       ),
       _maximumRetryDelay = _requirePositiveDuration(
         maximumRetryDelay,
         'maximumRetryDelay',
       ) {
    if (_maximumRetryDelay < _initialRetryDelay) {
      throw ArgumentError.value(
        maximumRetryDelay,
        'maximumRetryDelay',
        '不得小于 initialRetryDelay',
      );
    }
  }

  final E2eeSyncCycleRunner _cycleRunner;
  final Duration _pollInterval;
  final Duration _initialRetryDelay;
  final Duration _maximumRetryDelay;
  final E2eeSyncTimerFactory _timerFactory;
  final E2eeSyncBackgroundErrorReporter _errorReporter;

  E2eeSyncSchedulerState _state = E2eeSyncSchedulerState.notStarted;
  Future<void>? _activeCycle;
  Future<void>? _closeFuture;
  Timer? _timer;
  Duration? _nextRunDelay;
  bool _wakePending = false;
  int _consecutiveFailures = 0;

  E2eeSyncSchedulerState get state => _state;
  Duration? get nextRunDelay => _nextRunDelay;

  void start() {
    if (_state != E2eeSyncSchedulerState.notStarted) {
      throw StateError('E2EE 同步调度器只能启动一次');
    }
    _launchCycle();
  }

  void wake() {
    switch (_state) {
      case E2eeSyncSchedulerState.notStarted:
        throw StateError('E2EE 同步调度器尚未启动');
      case E2eeSyncSchedulerState.running:
        _wakePending = true;
        return;
      case E2eeSyncSchedulerState.retrying:
        // 网络退避期间只记录一次需求，不能让本地高频写入绕过退避。
        _wakePending = true;
        return;
      case E2eeSyncSchedulerState.polling:
        _cancelTimer();
        if (_activeCycle != null) {
          _wakePending = true;
          return;
        }
        _launchCycle();
        return;
      case E2eeSyncSchedulerState.keyEpochPaused:
      case E2eeSyncSchedulerState.closing:
      case E2eeSyncSchedulerState.closed:
        return;
    }
  }

  void resumeAfterKeyEpochChange() {
    if (_state != E2eeSyncSchedulerState.keyEpochPaused) return;
    _consecutiveFailures = 0;
    _schedule(Duration.zero, E2eeSyncSchedulerState.polling);
  }

  Future<void> close() {
    return _closeFuture ??= _close();
  }

  Future<void> _close() async {
    if (_state == E2eeSyncSchedulerState.closed) return;
    _state = E2eeSyncSchedulerState.closing;
    _wakePending = false;
    _cancelTimer();
    await _activeCycle;
    _state = E2eeSyncSchedulerState.closed;
  }

  void _launchCycle() {
    if (_state == E2eeSyncSchedulerState.closing ||
        _state == E2eeSyncSchedulerState.closed ||
        _activeCycle != null) {
      return;
    }
    _cancelTimer();
    _state = E2eeSyncSchedulerState.running;
    late final Future<void> tracked;
    tracked = _executeCycle().whenComplete(() {
      if (!identical(_activeCycle, tracked)) return;
      _activeCycle = null;
      if (_state == E2eeSyncSchedulerState.polling && _wakePending) {
        _wakePending = false;
        _cancelTimer();
        _launchCycle();
      }
    });
    _activeCycle = tracked;
    unawaited(tracked);
  }

  Future<void> _executeCycle() async {
    E2eeSyncCycleReport? report;
    Object? failure;
    StackTrace? failureStackTrace;
    try {
      report = await _cycleRunner.run();
    } catch (error, stackTrace) {
      failure = error;
      failureStackTrace = stackTrace;
      _reportBackgroundError(error, stackTrace);
    }

    if (_state == E2eeSyncSchedulerState.closing ||
        _state == E2eeSyncSchedulerState.closed) {
      return;
    }
    if (failure != null && failureStackTrace != null) {
      _consecutiveFailures++;
      _wakePending = false;
      _schedule(
        _retryDelay(_consecutiveFailures),
        E2eeSyncSchedulerState.retrying,
      );
      return;
    }
    if (report?.disposition == E2eeSyncCycleDisposition.keyEpochUnavailable) {
      _wakePending = false;
      _state = E2eeSyncSchedulerState.keyEpochPaused;
      return;
    }

    _consecutiveFailures = 0;
    if (_wakePending) {
      _wakePending = false;
      _schedule(Duration.zero, E2eeSyncSchedulerState.polling);
    } else {
      _schedule(_pollInterval, E2eeSyncSchedulerState.polling);
    }
  }

  void _schedule(Duration delay, E2eeSyncSchedulerState waitingState) {
    _cancelTimer();
    _state = waitingState;
    _nextRunDelay = delay;
    _timer = _timerFactory(delay, () {
      _timer = null;
      _nextRunDelay = null;
      _wakePending = false;
      _launchCycle();
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
    _nextRunDelay = null;
  }

  Duration _retryDelay(int consecutiveFailures) {
    var microseconds = _initialRetryDelay.inMicroseconds;
    final maximum = _maximumRetryDelay.inMicroseconds;
    for (var index = 1; index < consecutiveFailures; index++) {
      if (microseconds >= maximum) break;
      microseconds = microseconds > maximum ~/ 2 ? maximum : microseconds * 2;
    }
    return Duration(
      microseconds: microseconds > maximum ? maximum : microseconds,
    );
  }

  void _reportBackgroundError(Object error, StackTrace stackTrace) {
    try {
      _errorReporter(error, stackTrace);
    } catch (reportingError, reportingStackTrace) {
      developer.log(
        'E2EE 后台同步错误报告器自身失败',
        name: 'Kelivo.E2eeSyncScheduler',
        error: reportingError,
        stackTrace: reportingStackTrace,
      );
    }
  }
}

Timer _defaultTimerFactory(Duration delay, void Function() callback) {
  return Timer(delay, callback);
}

void _defaultErrorReporter(Object error, StackTrace stackTrace) {
  developer.log(
    'E2EE 后台同步周期失败',
    name: 'Kelivo.E2eeSyncScheduler',
    error: error,
    stackTrace: stackTrace,
  );
}

Duration _requirePositiveDuration(Duration value, String field) {
  if (value <= Duration.zero) {
    throw ArgumentError.value(value, field, '必须为正数');
  }
  return value;
}
