import 'dart:async';
import 'dart:developer' as developer;

enum E2eeSyncBudgetExhaustion { networkSteps, attachmentBytes }

final class E2eeSyncBudgetExhausted implements Exception {
  const E2eeSyncBudgetExhausted(this.reason);

  final E2eeSyncBudgetExhaustion reason;

  @override
  String toString() => 'E2eeSyncBudgetExhausted($reason)';
}

final class E2eeSyncDeadlineExceeded implements Exception {
  const E2eeSyncDeadlineExceeded();

  @override
  String toString() => 'E2eeSyncDeadlineExceeded';
}

final class E2eeSyncExecutionCancelled implements Exception {
  const E2eeSyncExecutionCancelled();

  @override
  String toString() => 'E2eeSyncExecutionCancelled';
}

typedef E2eeSyncAbortInFlightNetwork = void Function();

abstract interface class E2eeSyncCancellationSignal {
  /// 已取消的信号也必须立即通知新注册者，并返回可幂等解绑的句柄。
  E2eeSyncCancellationRegistration register(void Function() onCancelled);
}

abstract interface class E2eeSyncCancellationRegistration {
  void unregister();
}

final class E2eeSyncCancellationController
    implements E2eeSyncCancellationSignal {
  final Set<void Function()> _listeners = <void Function()>{};
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  @override
  E2eeSyncCancellationRegistration register(void Function() onCancelled) {
    if (_cancelled) {
      onCancelled();
      return const _NoopSyncCancellationRegistration();
    }
    _listeners.add(onCancelled);
    return _SyncCancellationRegistration(() {
      _listeners.remove(onCancelled);
    });
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final listeners = _listeners.toList(growable: false);
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }
}

final class _SyncCancellationRegistration
    implements E2eeSyncCancellationRegistration {
  _SyncCancellationRegistration(this._unregister);

  final void Function() _unregister;
  bool _registered = true;

  @override
  void unregister() {
    if (!_registered) return;
    _registered = false;
    _unregister();
  }
}

final class _NoopSyncCancellationRegistration
    implements E2eeSyncCancellationRegistration {
  const _NoopSyncCancellationRegistration();

  @override
  void unregister() {}
}

/// 为一次同步统一核算网络、附件和单调墙钟预算。
///
/// 截止或取消会先中止同一网络客户端，并在关闭宽限期内等待在途调用结算；
/// 超过宽限期后由原生桥释放平台任务，避免失控 I/O 永久占用后台执行槽。
final class E2eeSyncExecutionBudget {
  E2eeSyncExecutionBudget({
    required this.maximumNetworkSteps,
    required this.maximumAttachmentBytes,
    required this.maximumDuration,
    this.maximumShutdownDuration = const Duration(seconds: 2),
    required this._abortInFlightNetwork,
    E2eeSyncCancellationSignal? cancellationSignal,
  }) : _stopwatch = Stopwatch()..start() {
    if (maximumNetworkSteps < 1) {
      throw RangeError.range(
        maximumNetworkSteps,
        1,
        null,
        'maximumNetworkSteps',
      );
    }
    if (maximumAttachmentBytes < 0) {
      throw RangeError.range(
        maximumAttachmentBytes,
        0,
        null,
        'maximumAttachmentBytes',
      );
    }
    if (maximumDuration <= Duration.zero) {
      throw ArgumentError.value(maximumDuration, 'maximumDuration', '必须为正数');
    }
    if (maximumShutdownDuration <= Duration.zero) {
      throw ArgumentError.value(
        maximumShutdownDuration,
        'maximumShutdownDuration',
        '必须为正数',
      );
    }
    _cancellationRegistration = cancellationSignal?.register(_markCancelled);
  }

  final int maximumNetworkSteps;
  final int maximumAttachmentBytes;
  final Duration maximumDuration;
  final Duration maximumShutdownDuration;
  final E2eeSyncAbortInFlightNetwork _abortInFlightNetwork;
  final Stopwatch _stopwatch;

  int _networkStepsConsumed = 0;
  int _attachmentBytesConsumed = 0;
  bool _cancelled = false;
  bool _disposed = false;
  Completer<_ExecutionInterruption>? _activeInterruption;
  E2eeSyncCancellationRegistration? _cancellationRegistration;
  Stopwatch? _shutdownStopwatch;

  int get networkStepsConsumed => _networkStepsConsumed;
  int get attachmentBytesConsumed => _attachmentBytesConsumed;

  Duration get remainingDuration {
    final remaining = maximumDuration - _stopwatch.elapsed;
    return remaining > Duration.zero ? remaining : Duration.zero;
  }

  void checkCanContinue() {
    if (_disposed) throw StateError('e2ee_sync_execution_budget_disposed');
    if (_cancelled) throw const E2eeSyncExecutionCancelled();
    if (remainingDuration == Duration.zero) {
      _beginShutdown();
      throw const E2eeSyncDeadlineExceeded();
    }
  }

  Future<T> runBoundedStep<T>({
    required Future<T> Function(Duration remaining) operation,
    Future<void> Function(T value)? releaseInterruptedValue,
  }) async {
    checkCanContinue();
    if (_activeInterruption != null) {
      throw StateError('e2ee_sync_budget_step_reentrant');
    }
    final remaining = remainingDuration;
    final interruption = Completer<_ExecutionInterruption>();
    _activeInterruption = interruption;
    final deadlineTimer = Timer(
      remaining,
      () => _interrupt(_ExecutionInterruption.deadline),
    );
    final operationOutcome = Future<T>.sync(() => operation(remaining))
        .then<_NetworkOutcome<T>>(
          _NetworkSucceeded<T>.new,
          onError: (Object error, StackTrace stackTrace) =>
              _NetworkFailed<T>(error, stackTrace),
        );

    try {
      final winner = await Future.any<Object>(<Future<Object>>[
        operationOutcome,
        interruption.future,
      ]);
      if (winner case _ExecutionInterruption interruptionReason) {
        _beginShutdown();
        final settled = await _waitForBoundedSettlement(operationOutcome);
        await _releaseInterruptedOutcome(
          operationOutcome: operationOutcome,
          settled: settled,
          release: releaseInterruptedValue,
        );
        _throwInterruption(interruptionReason);
      }

      final outcome = winner as _NetworkOutcome<T>;
      switch (outcome) {
        case _NetworkFailed<T>(:final error, :final stackTrace):
          Error.throwWithStackTrace(error, stackTrace);
        case _NetworkSucceeded<T>(:final value):
          checkCanContinue();
          return value;
      }
    } finally {
      deadlineTimer.cancel();
      if (identical(_activeInterruption, interruption)) {
        _activeInterruption = null;
      }
    }
  }

  Future<void> runCleanupStep(Future<void> Function() operation) async {
    if (_disposed) throw StateError('e2ee_sync_execution_budget_disposed');
    if (_activeInterruption != null) {
      throw StateError('e2ee_sync_budget_step_reentrant');
    }
    final operationOutcome = Future<void>.sync(operation)
        .then<_NetworkOutcome<void>>(
          _NetworkSucceeded<void>.new,
          onError: (Object error, StackTrace stackTrace) =>
              _NetworkFailed<void>(error, stackTrace),
        );
    final initialInterruption = _currentInterruption;
    if (initialInterruption != null) {
      _beginShutdown();
      await _waitForBoundedSettlement(operationOutcome);
      _throwInterruption(initialInterruption);
    }

    final interruption = Completer<_ExecutionInterruption>();
    _activeInterruption = interruption;
    final deadlineTimer = Timer(
      remainingDuration,
      () => _interrupt(_ExecutionInterruption.deadline),
    );
    try {
      final winner = await Future.any<Object>(<Future<Object>>[
        operationOutcome,
        interruption.future,
      ]);
      if (winner case _ExecutionInterruption interruptionReason) {
        _beginShutdown();
        await _waitForBoundedSettlement(operationOutcome);
        _throwInterruption(interruptionReason);
      }

      final outcome = winner as _NetworkOutcome<void>;
      switch (outcome) {
        case _NetworkFailed<void>(:final error, :final stackTrace):
          Error.throwWithStackTrace(error, stackTrace);
        case _NetworkSucceeded<void>():
          checkCanContinue();
      }
    } finally {
      deadlineTimer.cancel();
      if (identical(_activeInterruption, interruption)) {
        _activeInterruption = null;
      }
    }
  }

  Future<T> runNetworkStep<T>({
    required Future<T> Function(Duration remaining) operation,
    int attachmentByteReservation = 0,
    int Function(T result)? actualAttachmentBytes,
  }) async {
    checkCanContinue();
    if (_activeInterruption != null) {
      throw StateError('e2ee_sync_budget_network_step_reentrant');
    }
    if (_networkStepsConsumed >= maximumNetworkSteps) {
      throw const E2eeSyncBudgetExhausted(
        E2eeSyncBudgetExhaustion.networkSteps,
      );
    }
    if (attachmentByteReservation < 0) {
      throw RangeError.range(
        attachmentByteReservation,
        0,
        null,
        'attachmentByteReservation',
      );
    }
    if (attachmentByteReservation >
        maximumAttachmentBytes - _attachmentBytesConsumed) {
      throw const E2eeSyncBudgetExhausted(
        E2eeSyncBudgetExhaustion.attachmentBytes,
      );
    }

    _networkStepsConsumed++;
    _attachmentBytesConsumed += attachmentByteReservation;
    final remaining = remainingDuration;
    final interruption = Completer<_ExecutionInterruption>();
    _activeInterruption = interruption;
    final deadlineTimer = Timer(
      remaining,
      () => _interrupt(_ExecutionInterruption.deadline),
    );
    final operationFuture = Future<T>.sync(() => operation(remaining));
    final operationOutcome = operationFuture.then<_NetworkOutcome<T>>(
      _NetworkSucceeded<T>.new,
      onError: (Object error, StackTrace stackTrace) =>
          _NetworkFailed<T>(error, stackTrace),
    );

    try {
      final winner = await Future.any<Object>(<Future<Object>>[
        operationOutcome,
        interruption.future,
      ]);
      if (winner case _ExecutionInterruption interruptionReason) {
        _beginShutdown();
        try {
          _abortInFlightNetwork();
        } catch (error, stackTrace) {
          developer.log(
            '中止后台同步在途网络请求失败',
            name: 'Kelivo.E2eeSyncExecutionBudget',
            level: 1000,
            error: error,
            stackTrace: stackTrace,
          );
        }
        // 系统不会为失控 transport 无限续命；宽限期后由原生桥强制收尾。
        await _waitForBoundedSettlement(operationOutcome);
        _throwInterruption(interruptionReason);
      }

      final outcome = winner as _NetworkOutcome<T>;
      switch (outcome) {
        case _NetworkFailed<T>(:final error, :final stackTrace):
          Error.throwWithStackTrace(error, stackTrace);
        case _NetworkSucceeded<T>(:final value):
          final actualBytes = actualAttachmentBytes?.call(value);
          if (actualBytes != null) {
            if (actualBytes < 0 || actualBytes > attachmentByteReservation) {
              throw const FormatException('附件响应字节数超出同步预算预留范围');
            }
            _attachmentBytesConsumed -= attachmentByteReservation - actualBytes;
          }
          checkCanContinue();
          return value;
      }
    } finally {
      deadlineTimer.cancel();
      if (identical(_activeInterruption, interruption)) {
        _activeInterruption = null;
      }
    }
  }

  /// 解除外部取消监听，避免长生命周期信号保留本次同步的资源所有权图。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final registration = _cancellationRegistration;
    _cancellationRegistration = null;
    try {
      registration?.unregister();
    } catch (error, stackTrace) {
      developer.log(
        '解除后台同步取消监听失败',
        name: 'Kelivo.E2eeSyncExecutionBudget',
        level: 1000,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _markCancelled() {
    if (_disposed) return;
    _cancelled = true;
    _beginShutdown();
    _interrupt(_ExecutionInterruption.cancelled);
  }

  void _beginShutdown() {
    _shutdownStopwatch ??= Stopwatch()..start();
  }

  _ExecutionInterruption? get _currentInterruption {
    if (_cancelled) return _ExecutionInterruption.cancelled;
    if (remainingDuration == Duration.zero) {
      return _ExecutionInterruption.deadline;
    }
    return null;
  }

  Never _throwInterruption(_ExecutionInterruption interruption) {
    switch (interruption) {
      case _ExecutionInterruption.deadline:
        throw const E2eeSyncDeadlineExceeded();
      case _ExecutionInterruption.cancelled:
        throw const E2eeSyncExecutionCancelled();
    }
  }

  Future<_NetworkOutcome<T>?> _waitForBoundedSettlement<T>(
    Future<_NetworkOutcome<T>> operation,
  ) async {
    final shutdownStopwatch = _shutdownStopwatch;
    if (shutdownStopwatch == null) return null;
    final remaining = maximumShutdownDuration - shutdownStopwatch.elapsed;
    if (remaining <= Duration.zero) return null;
    final timeout = Completer<_NetworkOutcome<T>?>();
    final timer = Timer(remaining, () => timeout.complete(null));
    try {
      return await Future.any<_NetworkOutcome<T>?>(
        <Future<_NetworkOutcome<T>?>>[operation, timeout.future],
      );
    } finally {
      timer.cancel();
    }
  }

  Future<void> _releaseInterruptedOutcome<T>({
    required Future<_NetworkOutcome<T>> operationOutcome,
    required _NetworkOutcome<T>? settled,
    required Future<void> Function(T value)? release,
  }) async {
    if (release == null) return;
    if (settled case _NetworkSucceeded<T>(:final value)) {
      final releaseOutcome = Future<void>.sync(() => release(value))
          .then<_NetworkOutcome<void>>(
            _NetworkSucceeded<void>.new,
            onError: (Object error, StackTrace stackTrace) =>
                _NetworkFailed<void>(error, stackTrace),
          );
      final releaseResult = await _waitForBoundedSettlement(releaseOutcome);
      if (releaseResult case _NetworkFailed<void>(
        :final error,
        :final stackTrace,
      )) {
        developer.log(
          '释放截止后才返回的后台同步所有权失败',
          name: 'Kelivo.E2eeSyncExecutionBudget',
          level: 1000,
          error: error,
          stackTrace: stackTrace,
        );
      }
      return;
    }
    if (settled != null) return;
    unawaited(
      operationOutcome.then((outcome) async {
        if (outcome case _NetworkSucceeded<T>(:final value)) {
          try {
            await release(value);
          } catch (error, stackTrace) {
            developer.log(
              '释放关闭宽限期后才返回的后台同步所有权失败',
              name: 'Kelivo.E2eeSyncExecutionBudget',
              level: 1000,
              error: error,
              stackTrace: stackTrace,
            );
          }
        }
      }),
    );
  }

  void _interrupt(_ExecutionInterruption interruption) {
    final active = _activeInterruption;
    if (active == null || active.isCompleted) return;
    active.complete(interruption);
  }
}

enum _ExecutionInterruption { deadline, cancelled }

sealed class _NetworkOutcome<T> {
  const _NetworkOutcome();
}

final class _NetworkSucceeded<T> extends _NetworkOutcome<T> {
  const _NetworkSucceeded(this.value);

  final T value;
}

final class _NetworkFailed<T> extends _NetworkOutcome<T> {
  const _NetworkFailed(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}
