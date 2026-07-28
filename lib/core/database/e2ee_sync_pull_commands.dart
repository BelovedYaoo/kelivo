part of 'chat_database_repository.dart';

final class E2eeSyncPullApplyResult {
  const E2eeSyncPullApplyResult({
    required this.receivedCount,
    required this.businessApplyCount,
  });

  final int receivedCount;
  final int businessApplyCount;
}

final class E2eeSyncPullCommands {
  E2eeSyncPullCommands._(this._database)
    : _checkpointCommands = E2eeSyncPullCheckpointCommands._(_database),
      _recordLedger = E2eeSyncRecordLedger(_database);

  final AppDatabase _database;
  final E2eeSyncPullCheckpointCommands _checkpointCommands;
  final E2eeSyncRecordLedger _recordLedger;

  Future<E2eeSyncPullCheckpoint> readOrCreate({
    required String accountUserId,
    required DateTime now,
  }) {
    return _checkpointCommands.readOrCreate(
      accountUserId: accountUserId,
      now: now,
    );
  }

  Future<E2eeSyncPullCheckpoint> enterSnapshot({
    required E2eeSyncPullCheckpoint expected,
    required String snapshotRunId,
    required DateTime now,
  }) {
    return _checkpointCommands.enterSnapshot(
      expected: expected,
      snapshotRunId: snapshotRunId,
      now: now,
    );
  }

  Future<E2eeSyncPullCommit<E2eeSyncPullApplyResult>> applyIncrementalPage({
    required E2eeSyncPullCheckpoint expected,
    required String nextCursor,
    required int lastChangeSeq,
    required List<E2eeSyncPulledChange> changes,
    required E2eeSyncTransactionalBusinessApplier applyBusiness,
    required DateTime now,
  }) {
    _requireIncrementalPageOrdering(
      expected: expected,
      lastChangeSeq: lastChangeSeq,
      changes: changes,
    );
    final immutableChanges = List<E2eeSyncPulledChange>.unmodifiable(changes);
    return _checkpointCommands.applyIncrementalPage<E2eeSyncPullApplyResult>(
      expected: expected,
      nextCursor: nextCursor,
      lastChangeSeq: lastChangeSeq,
      now: now,
      apply: () => _applyAuthenticatedChanges(
        immutableChanges,
        applyBusiness: applyBusiness,
        now: now,
      ),
    );
  }

  Future<E2eeSyncPullCommit<E2eeSyncPullApplyResult>> applySnapshotPage({
    required E2eeSyncPullCheckpoint expected,
    required String? nextSnapshotCursor,
    required String? snapshotLastRecordId,
    required int snapshotMaxChangeSeq,
    required String? finalSyncCursor,
    required List<E2eeSyncPulledChange> changes,
    required E2eeSyncTransactionalBusinessApplier applyBusiness,
    required DateTime now,
  }) {
    _requireSnapshotPageOrdering(
      expected: expected,
      snapshotLastRecordId: snapshotLastRecordId,
      snapshotMaxChangeSeq: snapshotMaxChangeSeq,
      finalSyncCursor: finalSyncCursor,
      changes: changes,
    );
    final immutableChanges = List<E2eeSyncPulledChange>.unmodifiable(changes);
    return _checkpointCommands.applySnapshotPage<E2eeSyncPullApplyResult>(
      expected: expected,
      nextSnapshotCursor: nextSnapshotCursor,
      snapshotLastRecordId: snapshotLastRecordId,
      snapshotMaxChangeSeq: snapshotMaxChangeSeq,
      finalSyncCursor: finalSyncCursor,
      now: now,
      apply: () => _applyAuthenticatedChanges(
        immutableChanges,
        applyBusiness: applyBusiness,
        now: now,
      ),
    );
  }

  Future<E2eeSyncPullApplyResult> _applyAuthenticatedChanges(
    List<E2eeSyncPulledChange> changes, {
    required E2eeSyncTransactionalBusinessApplier applyBusiness,
    required DateTime now,
  }) async {
    final timestamp = _requireStorageTime(now, 'now');
    final applicableByRecord = <String, E2eeSyncPulledChange>{};
    for (final change in changes) {
      final recordId = change.state.recordId.wireValue;
      final currentRemote = await _remoteRecord(recordId);
      await _requireReadyRemotePointsToHead(currentRemote, recordId);
      final remoteDisposition = _classifyPulledRemoteMetadata(
        current: currentRemote,
        metadata: change.untrustedServerMetadata,
        digest: change.state.digest,
      );
      final acceptance = await _recordLedger.accept(change.state);
      _requireLedgerMatchesRemoteDisposition(
        acceptance: acceptance,
        remoteDisposition: remoteDisposition,
      );

      final remoteReady = await _applyRemoteMetadata(
        current: currentRemote,
        change: change,
        disposition: remoteDisposition,
        now: timestamp,
      );
      if (remoteReady) {
        await _requireDigestIsCurrentHead(
          recordId,
          _remoteDigestAfter(
            current: currentRemote,
            change: change,
            disposition: remoteDisposition,
          ),
        );
      }

      final hasPendingLocalWrite = await _hasPendingLocalWrite(change.state);
      if (remoteReady &&
          !hasPendingLocalWrite &&
          _acceptanceCanApplyBusiness(acceptance.kind)) {
        // 业务 payload 是完整状态；同 record 只提交页内最后一个可应用状态。
        applicableByRecord
          ..remove(recordId)
          ..[recordId] = change;
      }
    }

    final immutableApplicable = List<E2eeSyncPulledChange>.unmodifiable(
      applicableByRecord.values,
    );
    if (immutableApplicable.isNotEmpty) {
      await applyBusiness(immutableApplicable);
    }
    return E2eeSyncPullApplyResult(
      receivedCount: changes.length,
      businessApplyCount: immutableApplicable.length,
    );
  }

  Future<E2eeSyncRemoteRecordRow?> _remoteRecord(String recordId) {
    return (_database.select(
      _database.e2eeSyncRemoteRecordRows,
    )..where((row) => row.recordId.equals(recordId))).getSingleOrNull();
  }

  Future<void> _requireReadyRemotePointsToHead(
    E2eeSyncRemoteRecordRow? remote,
    String recordId,
  ) async {
    if (remote == null || remote.gate != 'ready') return;
    final digest = remote.stateDigest;
    if (digest == null) {
      if (await _hasAnyCurrentHead(recordId)) {
        throw StateError('远端 ready 空状态与 ledger head 不一致');
      }
      return;
    }
    await _requireDigestIsCurrentHead(recordId, digest);
  }

  Future<bool> _hasAnyCurrentHead(String recordId) async {
    final states = _database.e2eeSyncRecordStateRows;
    final heads = _database.e2eeSyncRecordHeadRows;
    final query =
        _database.select(states).join([
            innerJoin(heads, heads.digest.equalsExp(states.digest)),
          ])
          ..where(states.recordId.equals(recordId))
          ..limit(1);
    return (await query.get()).isNotEmpty;
  }

  Future<void> _requireDigestIsCurrentHead(
    String recordId,
    Uint8List digest,
  ) async {
    final states = _database.e2eeSyncRecordStateRows;
    final heads = _database.e2eeSyncRecordHeadRows;
    final query =
        _database.select(states).join([
            innerJoin(heads, heads.digest.equalsExp(states.digest)),
          ])
          ..where(
            states.recordId.equals(recordId) & states.digest.equals(digest),
          )
          ..limit(1);
    if ((await query.get()).isEmpty) {
      throw StateError('远端 ready 状态未指向当前 ledger head');
    }
  }

  Future<bool> _applyRemoteMetadata({
    required E2eeSyncRemoteRecordRow? current,
    required E2eeSyncPulledChange change,
    required _PullRemoteMetadataDisposition disposition,
    required DateTime now,
  }) async {
    if (disposition == _PullRemoteMetadataDisposition.stale) {
      return current?.gate == 'ready';
    }
    final metadata = change.untrustedServerMetadata;
    if (disposition == _PullRemoteMetadataDisposition.replay) {
      if (current == null) {
        throw StateError('远端 replay 缺少已持久化状态');
      }
      final nextGate = _resolvedRemoteGate(current, metadata.revision);
      if (nextGate != current.gate) {
        await _writePulledRemote(
          current: current,
          recordId: change.state.recordId.wireValue,
          revision: metadata.revision,
          changeSeq: metadata.changeSeq,
          digest: change.state.digest,
          gate: nextGate,
          now: now,
        );
      }
      return nextGate == 'ready';
    }

    final nextGate = current == null
        ? 'ready'
        : _resolvedRemoteGate(current, metadata.revision);
    await _writePulledRemote(
      current: current,
      recordId: change.state.recordId.wireValue,
      revision: metadata.revision,
      changeSeq: metadata.changeSeq,
      digest: change.state.digest,
      gate: nextGate,
      now: now,
    );
    return nextGate == 'ready';
  }

  Future<void> _writePulledRemote({
    required E2eeSyncRemoteRecordRow? current,
    required String recordId,
    required int revision,
    required int changeSeq,
    required E2eeAccountRecordStateDigest digest,
    required String gate,
    required DateTime now,
  }) async {
    final timestamp = current != null && now.isBefore(current.updatedAt)
        ? current.updatedAt
        : now;
    final observedRevision = gate == 'ready' ? null : current?.observedRevision;
    final errorCode = gate == 'quarantined' ? current?.errorCode : null;
    if (current == null) {
      await _database
          .into(_database.e2eeSyncRemoteRecordRows)
          .insert(
            E2eeSyncRemoteRecordRowsCompanion.insert(
              recordId: recordId,
              revision: Value(revision),
              lastChangeSeq: Value(changeSeq),
              stateDigest: Value(_copyBytes(digest.bytes)),
              gate: gate,
              observedRevision: Value(observedRevision),
              errorCode: Value(errorCode),
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          );
      return;
    }
    final updated =
        await (_database.update(
          _database.e2eeSyncRemoteRecordRows,
        )..where((row) => row.recordId.equals(recordId))).write(
          E2eeSyncRemoteRecordRowsCompanion(
            revision: Value(revision),
            lastChangeSeq: Value(changeSeq),
            stateDigest: Value(_copyBytes(digest.bytes)),
            gate: Value(gate),
            observedRevision: Value(observedRevision),
            errorCode: Value(errorCode),
            updatedAt: Value(timestamp),
          ),
        );
    if (updated != 1) throw StateError('pull remote 元数据更新失败');
  }

  Future<bool> _hasPendingLocalWrite(
    E2eeAuthenticatedAccountRecordState state,
  ) async {
    final intent =
        await (_database.select(_database.e2eeSyncIntentRows)
              ..where(
                (row) =>
                    row.entityType.equals(state.entityKey.entityType) &
                    row.entityId.equals(state.entityKey.entityId),
              )
              ..limit(1))
            .getSingleOrNull();
    if (intent != null) return true;
    final outbox =
        await (_database.select(_database.e2eeSyncOutboxRows)
              ..where((row) => row.recordId.equals(state.recordId.wireValue))
              ..limit(1))
            .getSingleOrNull();
    return outbox != null;
  }
}

enum _PullRemoteMetadataDisposition { advance, replay, stale }

_PullRemoteMetadataDisposition _classifyPulledRemoteMetadata({
  required E2eeSyncRemoteRecordRow? current,
  required E2eeSyncUntrustedServerMetadata metadata,
  required E2eeAccountRecordStateDigest digest,
}) {
  if (current == null || current.revision == null) {
    if (current != null &&
        (current.lastChangeSeq != null || current.stateDigest != null)) {
      throw StateError('pull remote 元数据字段不完整');
    }
    if (metadata.revision != 1) {
      throw const FormatException('远端新记录 revision 必须从 1 开始');
    }
    return _PullRemoteMetadataDisposition.advance;
  }
  final currentSequence = current.lastChangeSeq;
  final currentDigest = current.stateDigest;
  if (currentSequence == null || currentDigest == null) {
    throw StateError('pull remote 元数据字段不完整');
  }
  if (metadata.revision == current.revision &&
      metadata.changeSeq == currentSequence) {
    if (!_sameBytes(currentDigest, digest.bytes)) {
      throw const FormatException('同 revision/changeSeq 对应了不同认证状态');
    }
    return _PullRemoteMetadataDisposition.replay;
  }
  if (metadata.revision == current.revision! + 1 &&
      metadata.changeSeq > currentSequence) {
    return _PullRemoteMetadataDisposition.advance;
  }
  if (metadata.revision < current.revision! &&
      metadata.changeSeq < currentSequence) {
    return _PullRemoteMetadataDisposition.stale;
  }
  throw const FormatException('远端 revision/changeSeq 未按同一方向严格推进');
}

void _requireLedgerMatchesRemoteDisposition({
  required E2eeSyncRecordAcceptance acceptance,
  required _PullRemoteMetadataDisposition remoteDisposition,
}) {
  final matches = switch (acceptance.kind) {
    E2eeSyncRecordAcceptanceKind.staleReplay =>
      remoteDisposition == _PullRemoteMetadataDisposition.stale,
    E2eeSyncRecordAcceptanceKind.currentReplay =>
      remoteDisposition == _PullRemoteMetadataDisposition.replay,
    E2eeSyncRecordAcceptanceKind.genesis ||
    E2eeSyncRecordAcceptanceKind.fastForward ||
    E2eeSyncRecordAcceptanceKind.conflict ||
    E2eeSyncRecordAcceptanceKind.merge =>
      remoteDisposition == _PullRemoteMetadataDisposition.advance,
  };
  if (!matches) {
    throw const FormatException('ledger 分类与远端元数据推进方向不一致');
  }
}

bool _acceptanceCanApplyBusiness(E2eeSyncRecordAcceptanceKind kind) {
  return switch (kind) {
    E2eeSyncRecordAcceptanceKind.genesis ||
    E2eeSyncRecordAcceptanceKind.fastForward ||
    E2eeSyncRecordAcceptanceKind.merge => true,
    E2eeSyncRecordAcceptanceKind.conflict ||
    E2eeSyncRecordAcceptanceKind.currentReplay ||
    E2eeSyncRecordAcceptanceKind.staleReplay => false,
  };
}

String _resolvedRemoteGate(E2eeSyncRemoteRecordRow current, int revision) {
  if (current.gate == 'quarantined') return 'quarantined';
  if (current.gate != 'requires-pull') return 'ready';
  final observedRevision = current.observedRevision;
  return observedRevision != null && revision < observedRevision
      ? 'requires-pull'
      : 'ready';
}

Uint8List _remoteDigestAfter({
  required E2eeSyncRemoteRecordRow? current,
  required E2eeSyncPulledChange change,
  required _PullRemoteMetadataDisposition disposition,
}) {
  if (disposition == _PullRemoteMetadataDisposition.advance) {
    return change.state.digest.bytes;
  }
  final digest = current?.stateDigest;
  if (digest == null) throw StateError('pull remote 当前摘要缺失');
  return digest;
}

void _requireIncrementalPageOrdering({
  required E2eeSyncPullCheckpoint expected,
  required int lastChangeSeq,
  required List<E2eeSyncPulledChange> changes,
}) {
  var previous = expected.lastChangeSeq;
  for (final change in changes) {
    final sequence = change.untrustedServerMetadata.changeSeq;
    if (sequence <= previous) {
      throw const FormatException('pull 页 changeSeq 未严格推进');
    }
    previous = sequence;
  }
  if (previous != lastChangeSeq) {
    throw const FormatException('pull 页末 changeSeq 与 checkpoint 不一致');
  }
}

void _requireSnapshotPageOrdering({
  required E2eeSyncPullCheckpoint expected,
  required String? snapshotLastRecordId,
  required int snapshotMaxChangeSeq,
  required String? finalSyncCursor,
  required List<E2eeSyncPulledChange> changes,
}) {
  final previousMaximum = expected.snapshotMaxChangeSeq;
  if (previousMaximum == null) {
    throw StateError('pull checkpoint 当前不在快照阶段');
  }
  if (changes.isEmpty) {
    if (finalSyncCursor == null) {
      throw const FormatException('快照空页只能是终页');
    }
    if (snapshotMaxChangeSeq != previousMaximum ||
        snapshotLastRecordId != expected.snapshotLastRecordId) {
      throw const FormatException('快照空终页不得改变已验证进度');
    }
    return;
  }

  var previousSequence = previousMaximum;
  for (final change in changes) {
    final sequence = change.untrustedServerMetadata.changeSeq;
    if (sequence <= previousSequence) {
      throw const FormatException('快照页 changeSeq 未相对 checkpoint 严格推进');
    }
    previousSequence = sequence;
  }
  if (previousSequence != snapshotMaxChangeSeq) {
    throw const FormatException('快照页末 changeSeq 与快照上界不一致');
  }
  if (snapshotLastRecordId != changes.last.state.recordId.wireValue) {
    throw const FormatException('快照页末 recordId 与续传记录不一致');
  }
}
