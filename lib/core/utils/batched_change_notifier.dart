import 'package:flutter/foundation.dart';

mixin BatchedChangeNotifier on ChangeNotifier {
  int _notificationBatchDepth = 0;
  bool _notificationPending = false;

  Future<T> runNotificationBatch<T>(Future<T> Function() action) async {
    _notificationBatchDepth++;
    try {
      return await action();
    } finally {
      _notificationBatchDepth--;
      if (_notificationBatchDepth == 0 && _notificationPending) {
        _notificationPending = false;
        super.notifyListeners();
      }
    }
  }

  @override
  void notifyListeners() {
    if (_notificationBatchDepth > 0) {
      _notificationPending = true;
      return;
    }
    super.notifyListeners();
  }
}
