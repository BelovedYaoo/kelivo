import 'dart:async';

import 'package:uuid/uuid.dart';

import 'cloud_sync_store.dart';
import 'cloud_sync_types.dart';
import 'sync_codec.dart';

enum SyncWriteDisposition { completed, deferred }

typedef SyncWriteExportAndEnqueue =
    Future<SyncWriteDisposition> Function(SyncWriteIntent intent);

final class SyncWriteJournal {
  factory SyncWriteJournal({
    required CloudSyncStore store,
    required String journalScopeId,
    required SyncWriteExportAndEnqueue exportAndEnqueue,
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
  final SyncWriteExportAndEnqueue _exportAndEnqueue;
  final String Function() _createIntentId;
  final DateTime Function() _now;
  final Map<String, Future<void>> _keyTails = <String, Future<void>>{};
  int _activeOperations = 0;
  bool _transitioning = false;
  Completer<void>? _gateChanged;
  CloudSyncAccountSession? _session;

  Future<T> runLocal<T>({
    required SyncEntityKey key,
    required Future<T> Function() write,
  }) {
    return _withSessionLease((accountScope) {
      return _withKeyLock(key, () async {
        final intent = await _store.beginWriteIntent(
          SyncWriteIntent(
            intentId: _createIntentId(),
            entityType: CloudSyncEntityType.parse(key.entityType),
            entityId: key.entityId,
            journalScopeId: _journalScopeId,
            accountScope: accountScope,
            createdAt: _now(),
          ),
        );
        final result = await write();
        final disposition = await _exportAndEnqueue(intent);
        if (disposition == SyncWriteDisposition.completed) {
          await _store.completeWriteIntent(intent);
        }
        return result;
      });
    });
  }

  Future<T> runRemote<T>({
    required SyncEntityKey key,
    required Future<T> Function() write,
  }) {
    return _withSessionLease((_) => _withKeyLock(key, write));
  }

  Future<void> recover() {
    return _withSessionLease((accountScope) async {
      final intents = _store.writeIntents(
        journalScopeId: _journalScopeId,
        accountScope: accountScope,
      );
      await Future.wait<void>(
        intents.map((intent) {
          final key = SyncEntityKey(
            entityType: intent.entityType.wireName,
            entityId: intent.entityId,
          );
          return _withKeyLock(key, () async {
            final disposition = await _exportAndEnqueue(intent);
            if (disposition == SyncWriteDisposition.completed) {
              await _store.completeWriteIntent(intent);
            }
          });
        }),
      );
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
