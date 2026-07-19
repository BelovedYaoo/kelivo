import 'dart:async';

typedef CheckpointDelay = Future<void> Function(Duration duration);

/// 串行执行检查点写入，同时只保留最新的待写值。
///
/// [finalize] 会关闭队列，丢弃已被最终写入覆盖的待处理检查点，
/// 等待正在执行的检查点完成，再运行最终写入。
class LatestWinsCheckpointWriter<T> {
  LatestWinsCheckpointWriter({
    required this.write,
    this.minimumInterval = const Duration(milliseconds: 250),
    DateTime Function()? now,
    CheckpointDelay? delay,
    this.onError,
  }) : _now = now ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed;

  final Future<void> Function(T value) write;
  final DateTime Function() _now;
  final CheckpointDelay _delay;
  final void Function(Object error, StackTrace stackTrace)? onError;
  final Duration minimumInterval;

  T? _pending;
  Future<void>? _drainFuture;
  DateTime? _lastWriteStartedAt;
  Object? _failure;
  StackTrace? _failureStackTrace;
  bool _accepting = true;

  void add(T value) {
    if (!_accepting) {
      throw StateError('Checkpoint writer is closed.');
    }
    _throwIfFailed();
    _pending = value;
    _drainFuture ??= _drain();
  }

  Future<void> barrier() async {
    await _drainFuture;
    _throwIfFailed();
  }

  Future<R> finalize<R>(Future<R> Function() writeFinal) async {
    if (!_accepting) {
      throw StateError('Checkpoint writer is closed.');
    }
    _accepting = false;
    _pending = null;
    await _drainFuture;
    return writeFinal();
  }

  Future<void> _drain() async {
    try {
      while (_pending != null) {
        final lastStartedAt = _lastWriteStartedAt;
        if (lastStartedAt != null) {
          final elapsed = _now().difference(lastStartedAt);
          final remaining = minimumInterval - elapsed;
          if (remaining > Duration.zero) {
            await _delay(remaining);
          }
        }

        final value = _pending;
        if (value == null) break;
        _pending = null;
        _lastWriteStartedAt = _now();
        await write(value);
      }
    } catch (error, stackTrace) {
      _pending = null;
      _failure = error;
      _failureStackTrace = stackTrace;
      onError?.call(error, stackTrace);
    } finally {
      _drainFuture = null;
    }
  }

  Never _throwFailure(Object failure, StackTrace? stackTrace) {
    Error.throwWithStackTrace(failure, stackTrace ?? StackTrace.current);
  }

  void _throwIfFailed() {
    final failure = _failure;
    if (failure != null) {
      _throwFailure(failure, _failureStackTrace);
    }
  }
}
