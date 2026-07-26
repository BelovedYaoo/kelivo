import 'package:drift/drift.dart';

import '../services/sync/e2ee_account_record_state.dart';
import 'app_database.dart';

enum E2eeSyncRecordAcceptanceKind {
  genesis,
  fastForward,
  conflict,
  merge,
  currentReplay,
  staleReplay,
}

final class E2eeSyncRecordAcceptance {
  E2eeSyncRecordAcceptance({
    required this.kind,
    required List<E2eeAccountRecordStateDigest> heads,
  }) : heads = List.unmodifiable(heads);

  final E2eeSyncRecordAcceptanceKind kind;
  final List<E2eeAccountRecordStateDigest> heads;

  bool get hasConflict => heads.length > 1;
}

enum E2eeSyncRecordRejectionReason {
  historyGap,
  rollback,
  versionMismatch,
  operationIdReuse,
  parentRecordMismatch,
  storedStateMismatch,
}

final class E2eeSyncRecordRejected implements Exception {
  const E2eeSyncRecordRejected(this.reason);

  final E2eeSyncRecordRejectionReason reason;

  @override
  String toString() => 'E2eeSyncRecordRejected(${reason.name})';
}

final class E2eeSyncRecordLedger {
  E2eeSyncRecordLedger(this._database);

  final AppDatabase _database;

  Future<E2eeSyncRecordAcceptance> accept(
    E2eeAuthenticatedAccountRecordState state,
  ) {
    return _database.transaction(() => _acceptInTransaction(state));
  }

  Future<E2eeSyncRecordAcceptance> _acceptInTransaction(
    E2eeAuthenticatedAccountRecordState state,
  ) async {
    final stored = await _stateByDigest(state.digest.bytes);
    if (stored != null) {
      await _requireMatchingStoredState(stored, state);
      final heads = await _headsForRecord(state.recordId.wireValue);
      if (heads.isEmpty) {
        throw const E2eeSyncRecordRejected(
          E2eeSyncRecordRejectionReason.storedStateMismatch,
        );
      }
      final isCurrent = heads.contains(state.digest);
      return E2eeSyncRecordAcceptance(
        kind: isCurrent
            ? E2eeSyncRecordAcceptanceKind.currentReplay
            : E2eeSyncRecordAcceptanceKind.staleReplay,
        heads: heads,
      );
    }

    final reusedOperation = await _stateByOperation(state.operationId);
    if (reusedOperation != null) {
      throw const E2eeSyncRecordRejected(
        E2eeSyncRecordRejectionReason.operationIdReuse,
      );
    }

    final latest = await _latestState(state.recordId.wireValue);
    final parents = state.parentDigests;
    if (parents.isEmpty) {
      if (state.logicalVersion != 1) {
        throw const E2eeSyncRecordRejected(
          E2eeSyncRecordRejectionReason.versionMismatch,
        );
      }
      if (latest != null) {
        throw const E2eeSyncRecordRejected(
          E2eeSyncRecordRejectionReason.rollback,
        );
      }
    } else {
      if (parents.length > 2 || state.logicalVersion == 1) {
        throw const E2eeSyncRecordRejected(
          E2eeSyncRecordRejectionReason.versionMismatch,
        );
      }
      // 单机无法区分合法离线分支与服务器选择性延迟，已知祖先的连续分支必须保留为冲突。
      await _validateParents(state);
    }

    await _database
        .into(_database.e2eeSyncRecordStateRows)
        .insert(
          E2eeSyncRecordStateRowsCompanion.insert(
            digest: state.digest.bytes,
            recordId: state.recordId.wireValue,
            entityType: state.entityKey.entityType,
            entityId: state.entityKey.entityId,
            logicalVersion: state.logicalVersion,
            kind: _storageKind(state.kind),
            operationId: state.operationId,
            // 该字段只是 AEAD 内的写入者自声明，授权与撤销不得依赖它。
            claimedWriterDeviceId: state.claimedWriterDeviceId,
            claimedWriterKeyVersion: state.claimedWriterKeyVersion,
            keyEpoch: state.keyEpoch,
            acceptedAt: DateTime.now().toUtc(),
          ),
        );

    for (var ordinal = 0; ordinal < parents.length; ordinal++) {
      final parent = parents[ordinal];
      await _database
          .into(_database.e2eeSyncRecordParentRows)
          .insert(
            E2eeSyncRecordParentRowsCompanion.insert(
              childDigest: state.digest.bytes,
              ordinal: ordinal,
              parentDigest: parent.bytes,
            ),
          );
      await (_database.delete(
        _database.e2eeSyncRecordHeadRows,
      )..where((row) => row.digest.equals(parent.bytes))).go();
    }
    await _database
        .into(_database.e2eeSyncRecordHeadRows)
        .insert(
          E2eeSyncRecordHeadRowsCompanion.insert(digest: state.digest.bytes),
        );

    final heads = await _headsForRecord(state.recordId.wireValue);
    final kind = switch ((parents.length, heads.length)) {
      (0, _) => E2eeSyncRecordAcceptanceKind.genesis,
      (_, > 1) => E2eeSyncRecordAcceptanceKind.conflict,
      (2, _) => E2eeSyncRecordAcceptanceKind.merge,
      _ => E2eeSyncRecordAcceptanceKind.fastForward,
    };
    return E2eeSyncRecordAcceptance(kind: kind, heads: heads);
  }

  Future<void> _validateParents(
    E2eeAuthenticatedAccountRecordState state,
  ) async {
    var maximumParentVersion = 0;
    for (final digest in state.parentDigests) {
      final parent = await _stateByDigest(digest.bytes);
      if (parent == null) {
        throw const E2eeSyncRecordRejected(
          E2eeSyncRecordRejectionReason.historyGap,
        );
      }
      if (parent.recordId != state.recordId.wireValue ||
          parent.entityType != state.entityKey.entityType ||
          parent.entityId != state.entityKey.entityId) {
        throw const E2eeSyncRecordRejected(
          E2eeSyncRecordRejectionReason.parentRecordMismatch,
        );
      }
      if (parent.logicalVersion > maximumParentVersion) {
        maximumParentVersion = parent.logicalVersion;
      }
    }
    if (maximumParentVersion == 0 ||
        state.logicalVersion != maximumParentVersion + 1) {
      throw const E2eeSyncRecordRejected(
        E2eeSyncRecordRejectionReason.versionMismatch,
      );
    }
  }

  Future<E2eeSyncRecordStateRow?> _stateByDigest(Uint8List digest) {
    return (_database.select(
      _database.e2eeSyncRecordStateRows,
    )..where((row) => row.digest.equals(digest))).getSingleOrNull();
  }

  Future<E2eeSyncRecordStateRow?> _stateByOperation(String operationId) {
    return (_database.select(
      _database.e2eeSyncRecordStateRows,
    )..where((row) => row.operationId.equals(operationId))).getSingleOrNull();
  }

  Future<E2eeSyncRecordStateRow?> _latestState(String recordId) {
    return (_database.select(_database.e2eeSyncRecordStateRows)
          ..where((row) => row.recordId.equals(recordId))
          ..orderBy([
            (row) => OrderingTerm.desc(row.logicalVersion),
            (row) => OrderingTerm.desc(row.digest),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<E2eeAccountRecordStateDigest>> _headsForRecord(
    String recordId,
  ) async {
    final states = _database.e2eeSyncRecordStateRows;
    final heads = _database.e2eeSyncRecordHeadRows;
    final query = _database.select(states).join([
      innerJoin(heads, heads.digest.equalsExp(states.digest)),
    ])..where(states.recordId.equals(recordId));
    query.orderBy([OrderingTerm.asc(states.digest)]);
    final rows = await query.get();
    return rows
        .map(
          (row) => E2eeAccountRecordStateDigest.fromTrustedStorage(
            row.readTable(states).digest,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _requireMatchingStoredState(
    E2eeSyncRecordStateRow stored,
    E2eeAuthenticatedAccountRecordState incoming,
  ) async {
    if (stored.recordId != incoming.recordId.wireValue ||
        stored.entityType != incoming.entityKey.entityType ||
        stored.entityId != incoming.entityKey.entityId ||
        stored.logicalVersion != incoming.logicalVersion ||
        stored.kind != _storageKind(incoming.kind) ||
        stored.operationId != incoming.operationId ||
        stored.claimedWriterDeviceId != incoming.claimedWriterDeviceId ||
        stored.claimedWriterKeyVersion != incoming.claimedWriterKeyVersion ||
        stored.keyEpoch != incoming.keyEpoch) {
      throw const E2eeSyncRecordRejected(
        E2eeSyncRecordRejectionReason.storedStateMismatch,
      );
    }

    final storedParents = await (_database.select(
      _database.e2eeSyncRecordParentRows,
    )..where((row) => row.childDigest.equals(incoming.digest.bytes))).get();
    storedParents.sort((left, right) => left.ordinal.compareTo(right.ordinal));
    if (storedParents.length != incoming.parentDigests.length) {
      throw const E2eeSyncRecordRejected(
        E2eeSyncRecordRejectionReason.storedStateMismatch,
      );
    }
    for (var index = 0; index < storedParents.length; index++) {
      final storedParent = storedParents[index];
      final storedDigest = E2eeAccountRecordStateDigest.fromTrustedStorage(
        storedParent.parentDigest,
      );
      if (storedParent.ordinal != index ||
          storedDigest != incoming.parentDigests[index]) {
        throw const E2eeSyncRecordRejected(
          E2eeSyncRecordRejectionReason.storedStateMismatch,
        );
      }
    }
  }
}

String _storageKind(E2eeAccountRecordStateKind kind) => switch (kind) {
  E2eeAccountRecordStateKind.value => 'value',
  E2eeAccountRecordStateKind.tombstone => 'tombstone',
};
