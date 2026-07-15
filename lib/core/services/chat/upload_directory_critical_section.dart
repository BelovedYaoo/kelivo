import 'dart:async';

abstract final class UploadDirectoryCriticalSection {
  static final Object _zoneKey = Object();
  static Future<void> _tail = Future<void>.value();

  static Future<T> run<T>(Future<T> Function() action) {
    if (Zone.current[_zoneKey] == true) return action();

    final previous = _tail;
    final release = Completer<void>();
    _tail = release.future;
    return _run(previous, release, action);
  }

  static Future<T> _run<T>(
    Future<void> previous,
    Completer<void> release,
    Future<T> Function() action,
  ) async {
    await previous;
    try {
      // Zone 标记允许同一调用链重入，避免未来清理逻辑嵌套时自锁。
      return await runZoned<Future<T>>(
        action,
        zoneValues: <Object, Object>{_zoneKey: true},
      );
    } finally {
      release.complete();
    }
  }
}
