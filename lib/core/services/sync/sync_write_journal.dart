import 'dart:async';

import 'package:uuid/uuid.dart';

import 'cloud_sync_store.dart';
import 'cloud_sync_types.dart';
import 'sync_codec.dart';

enum SyncWriteDisposition { completed, deferred }

final class SyncWriteRecoverySummary {
  const SyncWriteRecoverySummary({
    required this.completedCount,
    required this.deferredCount,
  });

  final int completedCount;
  final int deferredCount;
}

typedef SyncWriteExportAndEnqueue =
    Future<Map<SyncEntityKey, SyncWriteDisposition>> Function(
      List<SyncWriteIntent> intents,
    );

final class SyncWriteJournal {
  factory SyncWriteJournal({
    required CloudSyncStore store,
    required String journalScopeId,
    SyncWriteExportAndEnqueue? exportAndEnqueue,
    CloudSyncAccountSession? initialSession,
    String Function()? createIntentId,
    DateTime Function()? now,
  }) {
    if (journalScopeId.trim().isEmpty) {
      throw const FormatException('写前 journal 的本地作用域不能为空');
    }
    return SyncWriteJournal._(
      store: store,
      journalScopeId: journalScopeId,
      exportAndEnqueue: exportAndEnqueue,
      session: initialSession,
      createIntentId: createIntentId ?? const Uuid().v4,
      now: now ?? DateTime.now,
    );
  }

  SyncWriteJournal._({
    required this._store,
    required this._journalScopeId,
    required this._exportAndEnqueue,
    required this._session,
    required this._createIntentId,
    required this._now,
  });

  final CloudSyncStore _store;
  final String _journalScopeId;
  SyncWriteExportAndEnqueue? _exportAndEnqueue;
  final String Function() _createIntentId;
  final DateTime Function() _now;
  final Map<String, Future<void>> _keyTails = <String, Future<void>>{};
  int _activeOperations = 0;
  bool _transitioning = false;
  bool _closed = false;
  Completer<void>? _gateChanged;
  CloudSyncAccountSession? _session;

  void bindExporter(SyncWriteExportAndEnqueue exporter) {
    if (_closed) {
      throw StateError('写前 journal 已关闭');
    }
    if (_exportAndEnqueue != null) {
      throw StateError('写前 journal 的 exporter 已绑定');
    }
    _exportAndEnqueue = exporter;
  }

  Future<T> runLocal<T>({
    required SyncEntityKey key,
    required Future<T> Function() write,
  }) {
    return runLocalBatch(keys: <SyncEntityKey>[key], write: write);
  }

  Future<T> runLocalBatch<T>({
    required Iterable<SyncEntityKey> keys,
    required Future<T> Function() write,
  }) {
    final orderedKeys = _normalizeBatchKeys(keys);
    return _withSessionLease((accountScope) {
      return _withKeyLocks(orderedKeys, () async {
        final intents = <SyncWriteIntent>[];
        for (final key in orderedKeys) {
          intents.add(
            await _store.beginWriteIntent(
              SyncWriteIntent(
                intentId: _createIntentId(),
                entityType: CloudSyncEntityType.parse(key.entityType),
                entityId: key.entityId,
                journalScopeId: _journalScopeId,
                accountScope: accountScope,
                createdAt: _now(),
              ),
            ),
          );
        }
        final result = await write();
        final dispositions = await _dispatchBatch(intents);
        for (final intent in intents) {
          final key = SyncEntityKey(
            entityType: intent.entityType.wireName,
            entityId: intent.entityId,
          );
          final disposition = dispositions[key]!;
          if (disposition == SyncWriteDisposition.completed) {
            await _store.completeWriteIntent(intent);
          }
        }
        return result;
      });
    });
  }

  Future<T> runRemote<T>({
    required SyncEntityKey key,
    required Future<T> Function() write,
  }) {
    return runRemoteBatch(keys: <SyncEntityKey>[key], write: write);
  }

  Future<T> runRemoteBatch<T>({
    required Iterable<SyncEntityKey> keys,
    required Future<T> Function() write,
  }) {
    final orderedKeys = _normalizeBatchKeys(keys);
    return _withSessionLease((_) => _withKeyLocks(orderedKeys, write));
  }

  List<SyncEntityKey> _normalizeBatchKeys(Iterable<SyncEntityKey> keys) {
    final byStorageKey = <String, SyncEntityKey>{};
    for (final key in keys) {
      byStorageKey.putIfAbsent(key.storageKey, () => key);
    }
    if (byStorageKey.isEmpty) {
      throw const FormatException('同步批量写入至少需要一个实体');
    }
    // 所有调用共享同一锁顺序，领域层即使反序传参也不会形成循环等待。
    return byStorageKey.values.toList(growable: false)
      ..sort((left, right) => left.storageKey.compareTo(right.storageKey));
  }

  Future<T> _withKeyLocks<T>(
    List<SyncEntityKey> keys,
    Future<T> Function() action,
  ) {
    Future<T> acquire(int index) {
      if (index == keys.length) return action();
      return _withKeyLock(keys[index], () => acquire(index + 1));
    }

    return acquire(0);
  }

  Future<SyncWriteRecoverySummary> recover() {
    return _withSessionLease((accountScope) async {
      final intents = _store.writeIntents(
        journalScopeId: _journalScopeId,
        accountScope: accountScope,
      );
      if (intents.isEmpty) {
        return const SyncWriteRecoverySummary(
          completedCount: 0,
          deferredCount: 0,
        );
      }
      final keys = _normalizeBatchKeys(
        intents.map(
          (intent) => SyncEntityKey(
            entityType: intent.entityType.wireName,
            entityId: intent.entityId,
          ),
        ),
      );
      return _withKeyLocks(keys, () async {
        final dispositions = await _dispatchBatch(intents);
        var completedCount = 0;
        var deferredCount = 0;
        for (final intent in intents) {
          final key = SyncEntityKey(
            entityType: intent.entityType.wireName,
            entityId: intent.entityId,
          );
          final disposition = dispositions[key]!;
          if (disposition == SyncWriteDisposition.completed) {
            await _store.completeWriteIntent(intent);
            completedCount++;
          } else {
            deferredCount++;
          }
        }
        return SyncWriteRecoverySummary(
          completedCount: completedCount,
          deferredCount: deferredCount,
        );
      });
    });
  }

  Future<void> transitionSession(CloudSyncAccountSession? session) async {
    await _beginTransition();
    try {
      if (session != null) {
        await _store.bindJournalScopeWriteIntents(
          journalScopeId: _journalScopeId,
          accountScope: session.accountScope,
        );
      }
      _session = session;
    } finally {
      _endTransition();
    }
  }

  Future<void> close() async {
    while (_transitioning) {
      await _waitForGateChange();
    }
    if (_closed) return;
    _transitioning = true;
    try {
      while (_activeOperations > 0) {
        await _waitForGateChange();
      }
      _closed = true;
    } finally {
      _endTransition();
    }
  }

  Future<Map<SyncEntityKey, SyncWriteDisposition>> _dispatchBatch(
    List<SyncWriteIntent> intents,
  ) async {
    final keys = <SyncEntityKey>{
      for (final intent in intents)
        SyncEntityKey(
          entityType: intent.entityType.wireName,
          entityId: intent.entityId,
        ),
    };
    final exporter = _exportAndEnqueue;
    if (exporter == null) {
      return Map<SyncEntityKey, SyncWriteDisposition>.unmodifiable(
        <SyncEntityKey, SyncWriteDisposition>{
          for (final key in keys) key: SyncWriteDisposition.deferred,
        },
      );
    }
    final dispositions = await exporter(
      List<SyncWriteIntent>.unmodifiable(intents),
    );
    if (dispositions.length != keys.length ||
        !keys.every(dispositions.containsKey)) {
      throw StateError('批量写前 exporter 未返回全部且仅返回请求实体');
    }
    return Map<SyncEntityKey, SyncWriteDisposition>.unmodifiable(dispositions);
  }

  Future<T> _withSessionLease<T>(
    Future<T> Function(String? accountScope) action,
  ) async {
    final accountScope = await _beginOperation();
    try {
      return await action(accountScope);
    } finally {
      _endOperation();
    }
  }

  Future<String?> _beginOperation() async {
    while (_transitioning) {
      await _waitForGateChange();
    }
    if (_closed) {
      throw StateError('写前 journal 已关闭');
    }
    _activeOperations++;
    return _session?.accountScope;
  }

  void _endOperation() {
    _activeOperations--;
    _notifyGateChanged();
  }

  Future<void> _beginTransition() async {
    while (_transitioning) {
      await _waitForGateChange();
    }
    if (_closed) {
      throw StateError('写前 journal 已关闭');
    }
    _transitioning = true;
    while (_activeOperations > 0) {
      await _waitForGateChange();
    }
  }

  void _endTransition() {
    _transitioning = false;
    _notifyGateChanged();
  }

  Future<void> _waitForGateChange() {
    return (_gateChanged ??= Completer<void>()).future;
  }

  void _notifyGateChanged() {
    final changed = _gateChanged;
    _gateChanged = null;
    changed?.complete();
  }

  Future<T> _withKeyLock<T>(
    SyncEntityKey key,
    Future<T> Function() action,
  ) async {
    final previous = _keyTails[key.storageKey];
    final done = Completer<void>();
    final tail = done.future;
    _keyTails[key.storageKey] = tail;
    if (previous != null) await previous;
    try {
      return await action();
    } finally {
      done.complete();
      if (identical(_keyTails[key.storageKey], tail)) {
        _keyTails.remove(key.storageKey);
      }
    }
  }
}
