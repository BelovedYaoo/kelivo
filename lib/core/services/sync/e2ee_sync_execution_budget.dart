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

/// 为一次同步统一核算网络、附件和单调墙钟预算。
///
/// 截止或取消不会只让上层 Future 超时返回，而是先中止同一网络客户端，
/// 再等待在途调用结算，避免随后关闭数据库和密钥时底层 I/O 仍在运行。
final class E2eeSyncExecutionBudget {
  E2eeSyncExecutionBudget({
    required this.maximumNetworkSteps,
    required this.maximumAttachmentBytes,
    required this.maximumDuration,
    required this._abortInFlightNetwork,
    Future<void>? cancellationSignal,
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
    cancellationSignal?.whenComplete(_markCancelled).ignore();
  }

  final int maximumNetworkSteps;
  final int maximumAttachmentBytes;
  final Duration maximumDuration;
  final E2eeSyncAbortInFlightNetwork _abortInFlightNetwork;
  final Stopwatch _stopwatch;

  int _networkStepsConsumed = 0;
  int _attachmentBytesConsumed = 0;
  bool _cancelled = false;
  Completer<_ExecutionInterruption>? _activeInterruption;

  int get networkStepsConsumed => _networkStepsConsumed;
  int get attachmentBytesConsumed => _attachmentBytesConsumed;

  Duration get remainingDuration {
    final remaining = maximumDuration - _stopwatch.elapsed;
    return remaining > Duration.zero ? remaining : Duration.zero;
  }

  void checkCanContinue() {
    if (_cancelled) throw const E2eeSyncExecutionCancelled();
    if (remainingDuration == Duration.zero) {
      throw const E2eeSyncDeadlineExceeded();
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
        // 必须等被中止的网络 Future 真正结算，调用方才可以关闭其余资源。
        await operationOutcome;
        switch (interruptionReason) {
          case _ExecutionInterruption.deadline:
            throw const E2eeSyncDeadlineExceeded();
          case _ExecutionInterruption.cancelled:
            throw const E2eeSyncExecutionCancelled();
        }
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

  void _markCancelled() {
    _cancelled = true;
    _interrupt(_ExecutionInterruption.cancelled);
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
