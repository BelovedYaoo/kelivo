import 'dart:io';

import 'chat_database_observer.dart';
import 'chat_database_repository.dart';
import 'database_cipher.dart';

final class ChatDatabaseLease {
  ChatDatabaseLease._(this.repository, this._gateway);

  final ChatDatabaseRepository repository;
  final ChatDatabaseGateway _gateway;
  Future<void>? _releaseFuture;
  bool _released = false;

  Future<void> release() {
    if (_released) return Future<void>.value();
    final existing = _releaseFuture;
    if (existing != null) return existing;
    late final Future<void> releasing;
    releasing = _gateway
        ._release(repository)
        .then((_) {
          _released = true;
        })
        .whenComplete(() {
          if (identical(_releaseFuture, releasing)) _releaseFuture = null;
        });
    _releaseFuture = releasing;
    return releasing;
  }
}

final class ChatDatabaseGateway {
  ChatDatabaseGateway({required this.cipher, ChatDatabaseObserver? observer})
    : _observer = observer ?? ChatDatabaseObserver.instance;

  ChatDatabaseRepository? _repository;
  Future<ChatDatabaseRepository>? _opening;
  Future<void>? _closing;
  String? _databasePath;
  int _leaseCount = 0;
  bool _closeRetryPending = false;
  final DatabaseCipher cipher;
  final ChatDatabaseObserver _observer;

  DatabaseCipher get databaseCipher => cipher;

  Future<ChatDatabaseLease> acquire(File databaseFile) async {
    await _closing;
    if (_closeRetryPending) {
      throw StateError('database_gateway_close_retry_pending');
    }
    final requestedPath = databaseFile.absolute.path;
    final activePath = _databasePath;
    if (activePath != null && activePath != requestedPath) {
      throw StateError('database_gateway_path_mismatch');
    }

    var repository = _repository;
    if (repository == null) {
      _databasePath = requestedPath;
      final opening = _opening ??= _open(databaseFile);
      try {
        repository = await opening;
      } catch (_) {
        if (identical(_opening, opening)) {
          _opening = null;
          _databasePath = null;
        }
        rethrow;
      }
      if (identical(_opening, opening)) {
        _repository = repository;
        _opening = null;
      }
    }

    _leaseCount++;
    return ChatDatabaseLease._(repository, this);
  }

  Future<ChatDatabaseRepository> _open(File databaseFile) async {
    return _observer.measure(ChatDatabaseOperation.gatewayOpen, () async {
      final repository = ChatDatabaseRepository.open(
        file: databaseFile,
        cipher: cipher,
        observer: _observer,
      );
      try {
        await repository.ensureReady();
        await repository.validateConnectionContract();
        return repository;
      } catch (_) {
        await repository.close();
        rethrow;
      }
    });
  }

  Future<void> _release(ChatDatabaseRepository repository) async {
    if (!identical(repository, _repository) || _leaseCount <= 0) {
      throw StateError('database_gateway_lease');
    }
    if (_leaseCount > 1) {
      _leaseCount--;
      return;
    }

    final closing = () async {
      await repository.close();
    }();
    _closeRetryPending = true;
    _closing = closing;
    try {
      await closing;
      if (!identical(repository, _repository) || _leaseCount != 1) {
        throw StateError('database_gateway_lease_changed_during_close');
      }
      _leaseCount = 0;
      _repository = null;
      _databasePath = null;
      _closeRetryPending = false;
    } finally {
      if (identical(_closing, closing)) _closing = null;
    }
  }
}
