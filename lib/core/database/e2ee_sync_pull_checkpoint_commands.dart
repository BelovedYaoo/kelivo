part of 'chat_database_repository.dart';

enum E2eeSyncPullPhase { incremental, snapshot }

final class E2eeSyncPullCheckpoint {
  const E2eeSyncPullCheckpoint._({
    required this.accountUserId,
    required this.phase,
    required this.syncCursor,
    required this.lastChangeSeq,
    required this.snapshotRunId,
    required this.snapshotCursor,
    required this.snapshotLastRecordId,
    required this.snapshotMaxChangeSeq,
    required this.transitionVersion,
    required this.createdAt,
    required this.updatedAt,
  });

  final String accountUserId;
  final E2eeSyncPullPhase phase;
  final String? syncCursor;
  final int lastChangeSeq;
  final String? snapshotRunId;
  final String? snapshotCursor;
  final String? snapshotLastRecordId;
  final int? snapshotMaxChangeSeq;
  final int transitionVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class E2eeSyncPullCommit<T> {
  const E2eeSyncPullCommit({required this.value, required this.checkpoint});

  final T value;
  final E2eeSyncPullCheckpoint checkpoint;
}

final class E2eeSyncPullCheckpointStale implements Exception {
  const E2eeSyncPullCheckpointStale();

  @override
  String toString() => 'E2eeSyncPullCheckpointStale()';
}

final class E2eeSyncPullCheckpointCommands {
  const E2eeSyncPullCheckpointCommands._(this._database);

  final AppDatabase _database;

  Future<E2eeSyncPullCheckpoint> readOrCreate({
    required String accountUserId,
    required DateTime now,
  }) {
    final accountId = _requireCanonicalUuidV4(accountUserId, 'accountUserId');
    final timestamp = _requireStorageTime(now, 'now');
    return _database.transaction(() async {
      final existing = await _row(accountId);
      if (existing != null) return _checkpointFromRow(existing);
      await _database
          .into(_database.e2eeSyncPullCheckpointRows)
          .insert(
            E2eeSyncPullCheckpointRowsCompanion.insert(
              accountUserId: accountId,
              phase: 'incremental',
              lastChangeSeq: 0,
              transitionVersion: 1,
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          );
      return _checkpointFromRow(
        (await _row(accountId)) ?? (throw StateError('pull checkpoint 创建后丢失')),
      );
    });
  }

  Future<E2eeSyncPullCheckpoint> enterSnapshot({
    required E2eeSyncPullCheckpoint expected,
    required String snapshotRunId,
    required DateTime now,
  }) {
    final runId = _requireCanonicalUuidV4(snapshotRunId, 'snapshotRunId');
    return _database.transaction(() async {
      final current = await _requireCurrent(expected);
      final timestamp = _nextTimestamp(current, now);
      final nextVersion = _nextTransitionVersion(current.transitionVersion);
      final updated =
          await (_database.update(
            _database.e2eeSyncPullCheckpointRows,
          )..where((row) => _matchesCheckpoint(row, current))).write(
            E2eeSyncPullCheckpointRowsCompanion(
              phase: const Value('snapshot'),
              syncCursor: const Value(null),
              snapshotRunId: Value(runId),
              snapshotCursor: const Value(null),
              snapshotLastRecordId: const Value(null),
              snapshotMaxChangeSeq: const Value(0),
              transitionVersion: Value(nextVersion),
              updatedAt: Value(timestamp),
            ),
          );
      if (updated != 1) throw const E2eeSyncPullCheckpointStale();
      return _checkpointFromRow(
        (await _row(current.accountUserId)) ??
            (throw StateError('pull checkpoint 切换快照后丢失')),
      );
    });
  }

  Future<E2eeSyncPullCommit<T>> applyIncrementalPage<T>({
    required E2eeSyncPullCheckpoint expected,
    required String nextCursor,
    required int lastChangeSeq,
    required Future<T> Function() apply,
    required DateTime now,
  }) {
    if (expected.phase != E2eeSyncPullPhase.incremental) {
      throw StateError('pull checkpoint 当前不在增量阶段');
    }
    final cursor = _requirePullCursor(nextCursor, 'nextCursor');
    final sequence = _requirePullSequence(lastChangeSeq, 'lastChangeSeq');
    if (sequence < expected.lastChangeSeq) {
      throw const FormatException('增量 changeSeq 不得回退');
    }
    return _database.transaction(() async {
      final current = await _requireCurrent(expected);
      if (current.phase != E2eeSyncPullPhase.incremental) {
        throw const E2eeSyncPullCheckpointStale();
      }
      final value = await apply();
      final timestamp = _nextTimestamp(current, now);
      final nextVersion = _nextTransitionVersion(current.transitionVersion);
      // 游标最后更新，确保回调里的 ledger 与业务写入失败时整页一起回滚。
      final updated =
          await (_database.update(
            _database.e2eeSyncPullCheckpointRows,
          )..where((row) => _matchesCheckpoint(row, current))).write(
            E2eeSyncPullCheckpointRowsCompanion(
              syncCursor: Value(cursor),
              lastChangeSeq: Value(sequence),
              transitionVersion: Value(nextVersion),
              updatedAt: Value(timestamp),
            ),
          );
      if (updated != 1) throw const E2eeSyncPullCheckpointStale();
      final checkpoint = _checkpointFromRow(
        (await _row(current.accountUserId)) ??
            (throw StateError('增量 pull checkpoint 提交后丢失')),
      );
      return E2eeSyncPullCommit<T>(value: value, checkpoint: checkpoint);
    });
  }

  Future<E2eeSyncPullCommit<T>> applySnapshotPage<T>({
    required E2eeSyncPullCheckpoint expected,
    required String? nextSnapshotCursor,
    required String? snapshotLastRecordId,
    required int snapshotMaxChangeSeq,
    required String? finalSyncCursor,
    required Future<T> Function() apply,
    required DateTime now,
  }) {
    if (expected.phase != E2eeSyncPullPhase.snapshot) {
      throw StateError('pull checkpoint 当前不在快照阶段');
    }
    final nextCursor = nextSnapshotCursor == null
        ? null
        : _requirePullCursor(nextSnapshotCursor, 'nextSnapshotCursor');
    final finalCursor = finalSyncCursor == null
        ? null
        : _requirePullCursor(finalSyncCursor, 'finalSyncCursor');
    final lastRecordId = snapshotLastRecordId == null
        ? null
        : _requireCanonicalUuidV4(snapshotLastRecordId, 'snapshotLastRecordId');
    final maximumSequence = _requirePullSequence(
      snapshotMaxChangeSeq,
      'snapshotMaxChangeSeq',
    );
    final previousMaximum = expected.snapshotMaxChangeSeq;
    if (previousMaximum == null || maximumSequence < previousMaximum) {
      throw const FormatException('快照 changeSeq 上界不得回退');
    }
    final isFinal = finalCursor != null;
    if (isFinal) {
      if (nextCursor != null) {
        throw const FormatException('快照末页不得包含 nextSnapshotCursor');
      }
    } else if (nextCursor == null || lastRecordId == null) {
      throw const FormatException('快照中间页缺少续传位置');
    }

    return _database.transaction(() async {
      final current = await _requireCurrent(expected);
      if (current.phase != E2eeSyncPullPhase.snapshot) {
        throw const E2eeSyncPullCheckpointStale();
      }
      final value = await apply();
      final timestamp = _nextTimestamp(current, now);
      final nextVersion = _nextTransitionVersion(current.transitionVersion);
      final companion = isFinal
          ? E2eeSyncPullCheckpointRowsCompanion(
              phase: const Value('incremental'),
              syncCursor: Value(finalCursor),
              lastChangeSeq: Value(
                maximumSequence > current.lastChangeSeq
                    ? maximumSequence
                    : current.lastChangeSeq,
              ),
              snapshotRunId: const Value(null),
              snapshotCursor: const Value(null),
              snapshotLastRecordId: const Value(null),
              snapshotMaxChangeSeq: const Value(null),
              transitionVersion: Value(nextVersion),
              updatedAt: Value(timestamp),
            )
          : E2eeSyncPullCheckpointRowsCompanion(
              snapshotCursor: Value(nextCursor),
              snapshotLastRecordId: Value(lastRecordId),
              snapshotMaxChangeSeq: Value(maximumSequence),
              transitionVersion: Value(nextVersion),
              updatedAt: Value(timestamp),
            );
      // 快照进度同样最后更新；缺项永远不会在这里被解释为删除。
      final updated = await (_database.update(
        _database.e2eeSyncPullCheckpointRows,
      )..where((row) => _matchesCheckpoint(row, current))).write(companion);
      if (updated != 1) throw const E2eeSyncPullCheckpointStale();
      final checkpoint = _checkpointFromRow(
        (await _row(current.accountUserId)) ??
            (throw StateError('快照 pull checkpoint 提交后丢失')),
      );
      return E2eeSyncPullCommit<T>(value: value, checkpoint: checkpoint);
    });
  }

  Future<E2eeSyncPullCheckpointRow?> _row(String accountUserId) {
    return (_database.select(_database.e2eeSyncPullCheckpointRows)
          ..where((row) => row.accountUserId.equals(accountUserId)))
        .getSingleOrNull();
  }

  Future<E2eeSyncPullCheckpoint> _requireCurrent(
    E2eeSyncPullCheckpoint expected,
  ) async {
    final accountId = _requireCanonicalUuidV4(
      expected.accountUserId,
      'accountUserId',
    );
    final row = await _row(accountId);
    if (row == null || row.transitionVersion != expected.transitionVersion) {
      throw const E2eeSyncPullCheckpointStale();
    }
    return _checkpointFromRow(row);
  }
}

Expression<bool> _matchesCheckpoint(
  $E2eeSyncPullCheckpointRowsTable row,
  E2eeSyncPullCheckpoint checkpoint,
) {
  return row.accountUserId.equals(checkpoint.accountUserId) &
      row.transitionVersion.equals(checkpoint.transitionVersion);
}

E2eeSyncPullCheckpoint _checkpointFromRow(E2eeSyncPullCheckpointRow row) {
  final phase = switch (row.phase) {
    'incremental' => E2eeSyncPullPhase.incremental,
    'snapshot' => E2eeSyncPullPhase.snapshot,
    _ => throw StateError('pull checkpoint phase 损坏'),
  };
  return E2eeSyncPullCheckpoint._(
    accountUserId: _requireCanonicalUuidV4(row.accountUserId, 'accountUserId'),
    phase: phase,
    syncCursor: row.syncCursor == null
        ? null
        : _requirePullCursor(row.syncCursor!, 'syncCursor'),
    lastChangeSeq: _requirePullSequence(row.lastChangeSeq, 'lastChangeSeq'),
    snapshotRunId: row.snapshotRunId == null
        ? null
        : _requireCanonicalUuidV4(row.snapshotRunId!, 'snapshotRunId'),
    snapshotCursor: row.snapshotCursor == null
        ? null
        : _requirePullCursor(row.snapshotCursor!, 'snapshotCursor'),
    snapshotLastRecordId: row.snapshotLastRecordId == null
        ? null
        : _requireCanonicalUuidV4(
            row.snapshotLastRecordId!,
            'snapshotLastRecordId',
          ),
    snapshotMaxChangeSeq: row.snapshotMaxChangeSeq == null
        ? null
        : _requirePullSequence(
            row.snapshotMaxChangeSeq!,
            'snapshotMaxChangeSeq',
          ),
    transitionVersion: _requirePositiveInt63(
      row.transitionVersion,
      'transitionVersion',
    ),
    createdAt: _requireStorageTime(row.createdAt, 'createdAt'),
    updatedAt: _requireStorageTime(row.updatedAt, 'updatedAt'),
  );
}

String _requirePullCursor(String value, String name) {
  final length = utf8.encode(value).length;
  if (length < 1 || length > 4096) {
    throw FormatException('$name UTF-8 长度必须位于 1 到 4096 之间');
  }
  return value;
}

int _requirePullSequence(int value, String name) {
  if (value < 0 || value > _maxPositiveInt63) {
    throw FormatException('$name 必须位于非负 int63 范围');
  }
  return value;
}

int _nextTransitionVersion(int current) {
  if (current >= _maxPositiveInt63) {
    throw StateError('pull checkpoint transitionVersion 已耗尽');
  }
  return current + 1;
}

DateTime _nextTimestamp(E2eeSyncPullCheckpoint current, DateTime now) {
  final timestamp = _requireStorageTime(now, 'now');
  return timestamp.isBefore(current.updatedAt) ? current.updatedAt : timestamp;
}
