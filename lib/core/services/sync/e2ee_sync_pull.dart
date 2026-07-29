import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../database/chat_database_repository.dart';
import 'cloud_sync_client.dart';
import 'cloud_sync_record_types.dart';
import 'cloud_sync_types.dart';
import 'e2ee_account_record_cipher.dart';
import 'e2ee_account_record_state.dart';
import 'e2ee_sync_execution_budget.dart';
import 'e2ee_sync_payload_codec.dart';
import 'e2ee_sync_pull_types.dart';

export 'e2ee_sync_pull_types.dart';

const _maximumPositiveInt63 = 0x7fffffffffffffff;

abstract interface class E2eeSyncAuthenticatedPullTransport {
  String get accountUserId;

  Future<CloudSyncPullResult> pullChanges({String? cursor, int limit = 10});

  Future<CloudSyncSnapshotPage> pullSnapshot({
    String? snapshotCursor,
    int limit = 10,
  });
}

final class E2eeSyncCloudPullTransport
    implements E2eeSyncAuthenticatedPullTransport {
  E2eeSyncCloudPullTransport.bind({
    required this._client,
    required CloudSyncAuthenticatedSession session,
  }) : _token = session.token,
       accountUserId = session.user.id;

  final CloudSyncClient _client;
  final CloudSyncFullSessionToken _token;

  @override
  final String accountUserId;

  @override
  Future<CloudSyncPullResult> pullChanges({String? cursor, int limit = 10}) {
    return _client.pullChangesWithToken(
      token: _token,
      cursor: cursor,
      limit: limit,
    );
  }

  @override
  Future<CloudSyncSnapshotPage> pullSnapshot({
    String? snapshotCursor,
    int limit = 10,
  }) {
    return _client.pullSnapshotWithToken(
      token: _token,
      snapshotCursor: snapshotCursor,
      limit: limit,
    );
  }
}

enum E2eeSyncPullDisposition {
  idle,
  applied,
  preparationPending,
  resetToSnapshot,
  snapshotApplied,
  snapshotCompleted,
  keyEpochUnavailable,
}

enum E2eeSyncPullPagePreparationDisposition {
  ready,
  pending,
  keyEpochUnavailable,
}

abstract interface class E2eeSyncPullPagePreparer {
  Future<E2eeSyncPullPagePreparationDisposition> preparePage(
    List<E2eeSyncPulledChange> authenticatedChanges, {
    required int maximumRemoteSteps,
    E2eeSyncExecutionBudget? executionBudget,
  });
}

final class E2eeNoopSyncPullPagePreparer implements E2eeSyncPullPagePreparer {
  const E2eeNoopSyncPullPagePreparer();

  @override
  Future<E2eeSyncPullPagePreparationDisposition> preparePage(
    List<E2eeSyncPulledChange> authenticatedChanges, {
    required int maximumRemoteSteps,
    E2eeSyncExecutionBudget? executionBudget,
  }) async {
    if (maximumRemoteSteps < 1) {
      throw RangeError.range(maximumRemoteSteps, 1, null, 'maximumRemoteSteps');
    }
    for (final change in authenticatedChanges) {
      final attachments = change is E2eeSyncPulledValueChange
          ? change.payload['attachments']
          : null;
      if (change is E2eeSyncPulledValueChange &&
          change.state.entityKey.entityType ==
              E2eeSyncChatRecordTypes.message &&
          attachments is List<Object?> &&
          attachments.isNotEmpty) {
        throw StateError('sync_pull_noop_preparer_rejects_attachments');
      }
    }
    return E2eeSyncPullPagePreparationDisposition.ready;
  }
}

final class E2eeSyncPullReport {
  const E2eeSyncPullReport({
    required this.disposition,
    required this.received,
    required this.hasMore,
    required this.checkpoint,
  });

  final E2eeSyncPullDisposition disposition;
  final int received;
  final bool hasMore;
  final E2eeSyncPullCheckpoint checkpoint;
}

final class E2eeSyncPullCoordinator {
  E2eeSyncPullCoordinator({
    required this._pullCommands,
    required this._stateCodec,
    required this._transport,
    required this._pagePreparer,
    required this.maximumPreparationRemoteSteps,
    required this._applyBusiness,
    DateTime Function()? utcNow,
  }) : _utcNow = utcNow ?? _defaultUtcNow {
    if (maximumPreparationRemoteSteps < 1) {
      throw RangeError.range(
        maximumPreparationRemoteSteps,
        1,
        null,
        'maximumPreparationRemoteSteps',
      );
    }
  }

  final E2eeSyncPullCommands _pullCommands;
  final E2eeAccountRecordStateCodec _stateCodec;
  final E2eeSyncAuthenticatedPullTransport _transport;
  final E2eeSyncPullPagePreparer _pagePreparer;
  final int maximumPreparationRemoteSteps;
  final E2eeSyncTransactionalBusinessApplier _applyBusiness;
  final DateTime Function() _utcNow;
  Future<void> _tail = Future<void>.value();

  Future<E2eeSyncPullReport> pullOnce({
    int limit = 10,
    E2eeSyncExecutionBudget? executionBudget,
  }) {
    final previous = _tail;
    final completion = Completer<void>();
    _tail = completion.future;
    return () async {
      await previous;
      try {
        return await _pullOnce(limit: limit, executionBudget: executionBudget);
      } finally {
        completion.complete();
      }
    }();
  }

  Future<E2eeSyncPullReport> _pullOnce({
    required int limit,
    required E2eeSyncExecutionBudget? executionBudget,
  }) async {
    if (limit < 1 || limit > 10) {
      throw RangeError.range(limit, 1, 10, 'limit');
    }
    final checkpoint = await _pullCommands.readOrCreate(
      accountUserId: _transport.accountUserId,
      now: _utcNow(),
    );
    if (checkpoint.phase == E2eeSyncPullPhase.snapshot) {
      return _pullSnapshotPage(
        checkpoint: checkpoint,
        limit: limit,
        executionBudget: executionBudget,
      );
    }

    final pullResult = await _runBudgetedNetworkStep(
      executionBudget,
      () => _transport.pullChanges(cursor: checkpoint.syncCursor, limit: limit),
    );
    final CloudSyncChangePage page;
    switch (pullResult) {
      case CloudSyncResetRequired():
        final snapshot = await _pullCommands.enterSnapshot(
          expected: checkpoint,
          snapshotRunId: const Uuid().v4(),
          now: _utcNow(),
        );
        return E2eeSyncPullReport(
          disposition: E2eeSyncPullDisposition.resetToSnapshot,
          received: 0,
          hasMore: false,
          checkpoint: snapshot,
        );
      case CloudSyncChangePage():
        page = pullResult;
    }
    _validateIncrementalPageShape(
      page,
      limit,
      requestedCursor: checkpoint.syncCursor,
    );

    _validateIncrementalOrdering(page.changes, checkpoint.lastChangeSeq);
    for (final change in page.changes) {
      if (change case CloudSyncPutRecordChange(
        :final record,
      ) when record.keyEpoch > _stateCodec.currentKeyEpoch) {
        return E2eeSyncPullReport(
          disposition: E2eeSyncPullDisposition.keyEpochUnavailable,
          received: page.changes.length,
          hasMore: page.hasMore,
          checkpoint: checkpoint,
        );
      }
    }

    final authenticated = <E2eeSyncPulledChange>[];
    for (final change in page.changes) {
      authenticated.add(await _authenticateIncrementalChange(change));
    }
    final immutableChanges = List<E2eeSyncPulledChange>.unmodifiable(
      authenticated,
    );
    final preparation = await _pagePreparer.preparePage(
      immutableChanges,
      maximumRemoteSteps: maximumPreparationRemoteSteps,
      executionBudget: executionBudget,
    );
    if (preparation != E2eeSyncPullPagePreparationDisposition.ready) {
      return E2eeSyncPullReport(
        disposition:
            preparation ==
                E2eeSyncPullPagePreparationDisposition.keyEpochUnavailable
            ? E2eeSyncPullDisposition.keyEpochUnavailable
            : E2eeSyncPullDisposition.preparationPending,
        received: authenticated.length,
        hasMore:
            preparation == E2eeSyncPullPagePreparationDisposition.pending ||
            page.hasMore,
        checkpoint: checkpoint,
      );
    }
    final lastChangeSeq = page.changes.isEmpty
        ? checkpoint.lastChangeSeq
        : page.changes.last.changeSeq;
    final committed = await _pullCommands.applyIncrementalPage(
      expected: checkpoint,
      nextCursor: page.nextCursor,
      lastChangeSeq: lastChangeSeq,
      now: _utcNow(),
      changes: immutableChanges,
      applyBusiness: _applyBusiness,
    );
    return E2eeSyncPullReport(
      disposition: authenticated.isEmpty
          ? E2eeSyncPullDisposition.idle
          : E2eeSyncPullDisposition.applied,
      received: authenticated.length,
      hasMore: page.hasMore,
      checkpoint: committed.checkpoint,
    );
  }

  Future<E2eeSyncPullReport> _pullSnapshotPage({
    required E2eeSyncPullCheckpoint checkpoint,
    required int limit,
    required E2eeSyncExecutionBudget? executionBudget,
  }) async {
    final page = await _runBudgetedNetworkStep(
      executionBudget,
      () => _transport.pullSnapshot(
        snapshotCursor: checkpoint.snapshotCursor,
        limit: limit,
      ),
    );
    _validateSnapshotPageShape(
      page,
      limit,
      requestedCursor: checkpoint.snapshotCursor,
    );
    _validateSnapshotOrdering(page.records, checkpoint);
    for (final record in page.records) {
      if (record.record.keyEpoch > _stateCodec.currentKeyEpoch) {
        return E2eeSyncPullReport(
          disposition: E2eeSyncPullDisposition.keyEpochUnavailable,
          received: page.records.length,
          hasMore: page.hasMore,
          checkpoint: checkpoint,
        );
      }
    }

    final authenticated = <E2eeSyncPulledChange>[];
    for (final record in page.records) {
      authenticated.add(await _authenticateSnapshotRecord(record));
    }
    final immutableChanges = List<E2eeSyncPulledChange>.unmodifiable(
      authenticated,
    );
    final preparation = await _pagePreparer.preparePage(
      immutableChanges,
      maximumRemoteSteps: maximumPreparationRemoteSteps,
      executionBudget: executionBudget,
    );
    if (preparation != E2eeSyncPullPagePreparationDisposition.ready) {
      return E2eeSyncPullReport(
        disposition:
            preparation ==
                E2eeSyncPullPagePreparationDisposition.keyEpochUnavailable
            ? E2eeSyncPullDisposition.keyEpochUnavailable
            : E2eeSyncPullDisposition.preparationPending,
        received: authenticated.length,
        hasMore:
            preparation == E2eeSyncPullPagePreparationDisposition.pending ||
            page.hasMore,
        checkpoint: checkpoint,
      );
    }
    final previousMaximum = checkpoint.snapshotMaxChangeSeq;
    if (previousMaximum == null) {
      throw StateError('快照 checkpoint 缺少 changeSeq 上界');
    }
    final lastRecord = page.records.isEmpty ? null : page.records.last;
    final committed = await _pullCommands.applySnapshotPage(
      expected: checkpoint,
      nextSnapshotCursor: page.nextSnapshotCursor,
      snapshotLastRecordId:
          lastRecord?.recordId.wireValue ?? checkpoint.snapshotLastRecordId,
      snapshotMaxChangeSeq: lastRecord?.lastChangeSeq ?? previousMaximum,
      finalSyncCursor: page.syncCursor,
      changes: immutableChanges,
      applyBusiness: _applyBusiness,
      now: _utcNow(),
    );
    return E2eeSyncPullReport(
      disposition: page.hasMore
          ? E2eeSyncPullDisposition.snapshotApplied
          : E2eeSyncPullDisposition.snapshotCompleted,
      received: authenticated.length,
      hasMore: page.hasMore,
      checkpoint: committed.checkpoint,
    );
  }

  Future<E2eeSyncPulledChange> _authenticateIncrementalChange(
    CloudSyncRecordChange change,
  ) {
    if (change is! CloudSyncPutRecordChange) {
      throw const FormatException('增量同步只接受认证密文 put');
    }
    return _authenticateEnvelope(
      envelope: change.record,
      metadata: E2eeSyncUntrustedServerMetadata(
        changeSeq: change.changeSeq,
        revision: change.revision,
      ),
    );
  }

  Future<E2eeSyncPulledChange> _authenticateSnapshotRecord(
    CloudSyncEncryptedRecord record,
  ) {
    return _authenticateEnvelope(
      envelope: record.record,
      metadata: E2eeSyncUntrustedServerMetadata(
        changeSeq: record.lastChangeSeq,
        revision: record.revision,
      ),
    );
  }

  Future<E2eeSyncPulledChange> _authenticateEnvelope({
    required E2eeUntrustedAccountRecordEnvelope envelope,
    required E2eeSyncUntrustedServerMetadata metadata,
  }) {
    return _stateCodec.open(
      envelope,
      decode: (state, borrowedPayload) {
        E2eeSyncPayloadCodec.validateEntityKey(state.entityKey);
        return switch (state.kind) {
          E2eeAccountRecordStateKind.value => E2eeSyncPulledValueChange(
            untrustedServerMetadata: metadata,
            state: state,
            payload: E2eeSyncPayloadCodec.decode(
              entityKey: state.entityKey,
              bytes: borrowedPayload,
            ),
          ),
          E2eeAccountRecordStateKind.tombstone => E2eeSyncPulledTombstoneChange(
            untrustedServerMetadata: metadata,
            state: state,
          ),
        };
      },
    );
  }
}

Future<T> _runBudgetedNetworkStep<T>(
  E2eeSyncExecutionBudget? executionBudget,
  Future<T> Function() operation,
) {
  if (executionBudget == null) return operation();
  return executionBudget.runNetworkStep(operation: (_) => operation());
}

void _validateSnapshotPageShape(
  CloudSyncSnapshotPage page,
  int limit, {
  required String? requestedCursor,
}) {
  final nextCursor = page.nextSnapshotCursor;
  final syncCursor = page.syncCursor;
  final cursorsAreValid = page.hasMore
      ? nextCursor != null &&
            _isValidPullCursor(nextCursor) &&
            syncCursor == null
      : nextCursor == null &&
            syncCursor != null &&
            _isValidPullCursor(syncCursor);
  if (page.records.length > limit ||
      (page.hasMore && page.records.isEmpty) ||
      (page.records.isNotEmpty &&
          page.hasMore &&
          nextCursor == requestedCursor) ||
      !cursorsAreValid) {
    throw const FormatException('快照同步分页形状无效');
  }
}

void _validateSnapshotOrdering(
  List<CloudSyncEncryptedRecord> records,
  E2eeSyncPullCheckpoint checkpoint,
) {
  final checkpointSequence = checkpoint.snapshotMaxChangeSeq;
  if (checkpointSequence == null) {
    throw StateError('快照 checkpoint 缺少 changeSeq 上界');
  }
  var previous = checkpointSequence;
  for (final record in records) {
    if (record.lastChangeSeq <= previous ||
        record.lastChangeSeq > _maximumPositiveInt63 ||
        record.revision < 1 ||
        record.revision > _maximumPositiveInt63) {
      throw const FormatException('快照记录元数据未严格推进');
    }
    previous = record.lastChangeSeq;
  }
}

bool _isValidPullCursor(String cursor) {
  return cursor.isNotEmpty && cursor.length <= 4096;
}

void _validateIncrementalPageShape(
  CloudSyncChangePage page,
  int limit, {
  required String? requestedCursor,
}) {
  if (page.changes.length > limit ||
      (page.hasMore && page.changes.isEmpty) ||
      (page.changes.isNotEmpty && page.nextCursor == requestedCursor)) {
    throw const FormatException('增量同步分页形状无效');
  }
}

void _validateIncrementalOrdering(
  List<CloudSyncRecordChange> changes,
  int checkpointSequence,
) {
  var previous = checkpointSequence;
  for (final change in changes) {
    if (change.changeSeq <= previous ||
        change.changeSeq > _maximumPositiveInt63 ||
        change.revision < 1 ||
        change.revision > _maximumPositiveInt63) {
      throw const FormatException('增量记录元数据未严格推进');
    }
    previous = change.changeSeq;
  }
}

DateTime _defaultUtcNow() => DateTime.now().toUtc();
