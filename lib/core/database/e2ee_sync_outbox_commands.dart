part of 'chat_database_repository.dart';

const _maxPositiveInt63 = 0x7fffffffffffffff;
const _maxPositiveUint32 = 0xffffffff;
const _maxSendBatchCount = 10;
const _maxSendBatchCiphertextBytes = 1048576;

enum E2eeSyncOutboxBlockReason {
  leaseLost,
  activeOutbox,
  attachmentPending,
  requiresPull,
  quarantined,
  inconsistentHistory,
}

final class E2eeSyncOutboxBlocked implements Exception {
  const E2eeSyncOutboxBlocked(this.reason);

  final E2eeSyncOutboxBlockReason reason;

  @override
  String toString() => 'E2eeSyncOutboxBlocked(${reason.name})';
}

final class E2eeSyncLocalWriteIntent {
  E2eeSyncLocalWriteIntent({required String intentId, required this.entityKey})
    : intentId = _requireCanonicalUuidV4(intentId, 'intentId') {
    validateSyncEntityKey(entityKey);
  }

  final String intentId;
  final SyncEntityKey entityKey;
}

final class E2eeSyncIntentRef {
  E2eeSyncIntentRef({
    required String intentId,
    required this.entityKey,
    required int generation,
  }) : intentId = _requireCanonicalUuidV4(intentId, 'intentId'),
       generation = _requirePositiveInt63(generation, 'generation') {
    validateSyncEntityKey(entityKey);
  }

  final String intentId;
  final SyncEntityKey entityKey;
  final int generation;
}

final class E2eeSyncSealLease {
  E2eeSyncSealLease({
    required this.intent,
    required String leaseToken,
    required String leaseOwner,
    required DateTime leaseExpiresAt,
  }) : leaseToken = _requireBoundedText(leaseToken, 'leaseToken'),
       leaseOwner = _requireBoundedText(leaseOwner, 'leaseOwner'),
       leaseExpiresAt = _requireStorageTime(leaseExpiresAt, 'leaseExpiresAt');

  final E2eeSyncIntentRef intent;
  final String leaseToken;
  final String leaseOwner;
  final DateTime leaseExpiresAt;
}

final class E2eeSyncSealPlan {
  E2eeSyncSealPlan._({
    required this.lease,
    required this.recordId,
    required this.logicalVersion,
    required List<E2eeAccountRecordStateDigest> parentDigests,
    required this.expectedRevision,
    required this.remoteDigest,
    required this.hadRemoteRow,
    required this.remoteLastChangeSeq,
  }) : parentDigests = List.unmodifiable(parentDigests);

  final E2eeSyncSealLease lease;
  final E2eeAccountRecordId recordId;
  final int logicalVersion;
  final List<E2eeAccountRecordStateDigest> parentDigests;
  final int expectedRevision;
  final E2eeAccountRecordStateDigest? remoteDigest;
  final bool hadRemoteRow;
  final int? remoteLastChangeSeq;
}

final class E2eeSyncClaimedOutboxMutation {
  E2eeSyncClaimedOutboxMutation({
    required String operationId,
    required String accountUserId,
    required String actorDeviceId,
    required this.entityKey,
    required String recordId,
    required this.envelopeVersion,
    required this.keyEpoch,
    required Uint8List ciphertext,
    required E2eeAccountRecordStateDigest digest,
    required this.expectedRevision,
    required this.claimedWriterKeyVersion,
    required String leaseToken,
    required String leaseOwner,
    required this.transitionVersion,
    required this.attemptCount,
  }) : operationId = _requireCanonicalUuidV4(operationId, 'operationId'),
       accountUserId = _requireCanonicalUuidV4(accountUserId, 'accountUserId'),
       actorDeviceId = _requireCanonicalUuidV4(actorDeviceId, 'actorDeviceId'),
       recordId = _requireCanonicalUuidV4(recordId, 'recordId'),
       ciphertext = Uint8List.fromList(ciphertext).asUnmodifiableView(),
       digest = E2eeAccountRecordStateDigest.fromTrustedStorage(digest.bytes),
       leaseToken = _requireBoundedText(leaseToken, 'leaseToken'),
       leaseOwner = _requireBoundedText(leaseOwner, 'leaseOwner') {
    validateSyncEntityKey(entityKey);
    if (envelopeVersion != e2eeAccountRecordEnvelopeVersion ||
        keyEpoch < 1 ||
        keyEpoch > _maxPositiveUint32 ||
        this.ciphertext.isEmpty ||
        this.ciphertext.length > e2eeAccountRecordMaxCiphertextBytes ||
        expectedRevision < 0 ||
        expectedRevision > _maxPositiveInt63 ||
        claimedWriterKeyVersion < 1 ||
        claimedWriterKeyVersion > _maxPositiveUint32 ||
        transitionVersion < 1 ||
        transitionVersion > _maxPositiveInt63 ||
        attemptCount < 1 ||
        attemptCount > _maxPositiveInt63) {
      throw const FormatException('outbox claim 字段超出持久化范围');
    }
  }

  final String operationId;
  final String accountUserId;
  final String actorDeviceId;
  final SyncEntityKey entityKey;
  final String recordId;
  final int envelopeVersion;
  final int keyEpoch;
  final Uint8List ciphertext;
  final E2eeAccountRecordStateDigest digest;
  final int expectedRevision;
  final int claimedWriterKeyVersion;
  final String leaseToken;
  final String leaseOwner;
  final int transitionVersion;
  final int attemptCount;
}

final class E2eeSyncOutboxCommands {
  E2eeSyncOutboxCommands._(this._database)
    : _recordLedger = E2eeSyncRecordLedger(_database);

  final AppDatabase _database;
  final E2eeSyncRecordLedger _recordLedger;

  Object get ownershipIdentity => _database;

  Future<T> runLocalWriteAtomically<T>({
    required List<E2eeSyncLocalWriteIntent> intents,
    required String writerSessionId,
    required DateTime now,
    required Future<T> Function() write,
  }) async {
    final writerSession = _requireBoundedText(
      writerSessionId,
      'writerSessionId',
    );
    final timestamp = _requireStorageTime(now, 'now');
    final seenKeys = <String>{};
    for (final intent in intents) {
      validateSyncEntityKey(intent.entityKey);
      if (!seenKeys.add(intent.entityKey.storageKey)) {
        throw const FormatException('同一批本地写入包含重复实体键');
      }
    }
    if (intents.isEmpty) {
      throw ArgumentError.value(intents, 'intents', '本地同步写入必须包含实体键');
    }

    // 业务闭包必须继承同一 Drift 事务上下文，避免崩溃后留下无法解释的偏状态。
    return _database.transaction(() async {
      final refs = <E2eeSyncIntentRef>[];
      for (final input in intents) {
        final existing = await _intentByKey(input.entityKey);
        if (existing == null) {
          await _database
              .into(_database.e2eeSyncIntentRows)
              .insert(
                E2eeSyncIntentRowsCompanion.insert(
                  entityType: input.entityKey.entityType,
                  entityId: input.entityKey.entityId,
                  intentId: input.intentId,
                  generation: 1,
                  phase: 'preparing',
                  writerSessionId: Value(writerSession),
                  createdAt: timestamp,
                  updatedAt: timestamp,
                ),
              );
          refs.add(
            E2eeSyncIntentRef(
              intentId: input.intentId,
              entityKey: input.entityKey,
              generation: 1,
            ),
          );
          continue;
        }
        if (existing.generation >= _maxPositiveInt63) {
          throw StateError('同步意图 generation 已耗尽');
        }
        final nextGeneration = existing.generation + 1;
        final updated =
            await (_database.update(_database.e2eeSyncIntentRows)..where(
                  (row) =>
                      row.entityType.equals(existing.entityType) &
                      row.entityId.equals(existing.entityId) &
                      row.intentId.equals(existing.intentId) &
                      row.generation.equals(existing.generation),
                ))
                .write(
                  E2eeSyncIntentRowsCompanion(
                    generation: Value(nextGeneration),
                    phase: const Value('preparing'),
                    writerSessionId: Value(writerSession),
                    sealLeaseToken: const Value(null),
                    sealOwnerSessionId: const Value(null),
                    sealLeaseExpiresAt: const Value(null),
                    updatedAt: Value(timestamp),
                  ),
                );
        if (updated != 1) throw StateError('同步意图 generation 竞争失败');
        refs.add(
          E2eeSyncIntentRef(
            intentId: existing.intentId,
            entityKey: input.entityKey,
            generation: nextGeneration,
          ),
        );
      }
      final result = await Future<T>.sync(write);
      final finished =
          await (_database.update(_database.e2eeSyncIntentRows)..where(
                (row) =>
                    row.phase.equals('preparing') &
                    row.writerSessionId.equals(writerSession),
              ))
              .write(
                E2eeSyncIntentRowsCompanion(
                  phase: const Value('dirty'),
                  writerSessionId: const Value(null),
                  sealLeaseToken: const Value(null),
                  sealOwnerSessionId: const Value(null),
                  sealLeaseExpiresAt: const Value(null),
                  updatedAt: Value(timestamp),
                ),
              );
      if (finished != refs.length) {
        throw StateError('本地同步意图未完整收口为 dirty');
      }
      return result;
    });
  }

  Future<int> _recoverStartup({required DateTime now}) {
    final timestamp = _requireStorageTime(now, 'now');
    return _database.transaction(() async {
      final recoveredIntents =
          await (_database.update(_database.e2eeSyncIntentRows)..where(
                (row) =>
                    row.phase.equals('preparing') | row.phase.equals('sealing'),
              ))
              .write(
                E2eeSyncIntentRowsCompanion(
                  phase: const Value('dirty'),
                  writerSessionId: const Value(null),
                  sealLeaseToken: const Value(null),
                  sealOwnerSessionId: const Value(null),
                  sealLeaseExpiresAt: const Value(null),
                  updatedAt: Value(timestamp),
                ),
              );
      final sendingCount = _database.e2eeSyncOutboxRows.operationId.count();
      final exhausted =
          await (_database.selectOnly(_database.e2eeSyncOutboxRows)
                ..addColumns([sendingCount])
                ..where(
                  _database.e2eeSyncOutboxRows.phase.equals('sending') &
                      _database.e2eeSyncOutboxRows.transitionVersion.equals(
                        _maxPositiveInt63,
                      ),
                ))
              .getSingle();
      if (exhausted.read(sendingCount)! > 0) {
        throw StateError('outbox transitionVersion 已耗尽');
      }
      final recoveredOutbox = await _database.customUpdate(
        'UPDATE e2ee_sync_outbox_rows '
        "SET phase = 'ready', lease_token = NULL, "
        'lease_owner_session_id = NULL, lease_expires_at = NULL, '
        'transition_version = transition_version + 1, '
        "last_failure_kind = 'process-restarted', next_attempt_at = ?, "
        'updated_at = ? '
        "WHERE phase = 'sending';",
        variables: [
          Variable.withInt(timestamp.microsecondsSinceEpoch),
          Variable.withInt(timestamp.microsecondsSinceEpoch),
        ],
        updates: {_database.e2eeSyncOutboxRows},
        updateKind: UpdateKind.update,
      );
      return recoveredIntents + recoveredOutbox;
    });
  }

  Future<List<E2eeSyncIntentRef>> listDirtyIntents({int limit = 10}) async {
    RangeError.checkValueInInterval(limit, 1, 100, 'limit');
    final query = _database.select(_database.e2eeSyncIntentRows)
      ..where((row) => row.phase.equals('dirty'))
      ..orderBy([
        (row) => OrderingTerm.asc(row.updatedAt),
        (row) => OrderingTerm.asc(row.entityType),
        (row) => OrderingTerm.asc(row.entityId),
      ])
      ..limit(limit);
    final rows = await query.get();
    return List.unmodifiable(rows.map(_intentRefFromRow));
  }

  Future<E2eeSyncSealLease?> claimSealIntent({
    required E2eeSyncIntentRef intent,
    required String leaseToken,
    required String leaseOwner,
    required DateTime leaseExpiresAt,
    required DateTime now,
  }) async {
    final token = _requireBoundedText(leaseToken, 'leaseToken');
    final owner = _requireBoundedText(leaseOwner, 'leaseOwner');
    final timestamp = _requireStorageTime(now, 'now');
    final expiry = _requireStorageTime(leaseExpiresAt, 'leaseExpiresAt');
    if (!expiry.isAfter(timestamp)) {
      throw const FormatException('seal lease 必须晚于当前时间');
    }
    final updated =
        await (_database.update(_database.e2eeSyncIntentRows)..where(
              (row) =>
                  row.entityType.equals(intent.entityKey.entityType) &
                  row.entityId.equals(intent.entityKey.entityId) &
                  row.intentId.equals(intent.intentId) &
                  row.generation.equals(intent.generation) &
                  row.phase.equals('dirty'),
            ))
            .write(
              E2eeSyncIntentRowsCompanion(
                phase: const Value('sealing'),
                writerSessionId: const Value(null),
                sealLeaseToken: Value(token),
                sealOwnerSessionId: Value(owner),
                sealLeaseExpiresAt: Value(expiry),
                updatedAt: Value(timestamp),
              ),
            );
    if (updated == 0) return null;
    if (updated != 1) throw StateError('seal intent CAS 更新了多行');
    return E2eeSyncSealLease(
      intent: intent,
      leaseToken: token,
      leaseOwner: owner,
      leaseExpiresAt: expiry,
    );
  }

  Future<bool> releaseSealIntent({
    required E2eeSyncSealLease lease,
    required DateTime now,
  }) async {
    final timestamp = _requireStorageTime(now, 'now');
    final updated =
        await (_database.update(
          _database.e2eeSyncIntentRows,
        )..where((row) => _matchesSealLease(row, lease))).write(
          E2eeSyncIntentRowsCompanion(
            phase: const Value('dirty'),
            sealLeaseToken: const Value(null),
            sealOwnerSessionId: const Value(null),
            sealLeaseExpiresAt: const Value(null),
            updatedAt: Value(timestamp),
          ),
        );
    if (updated > 1) throw StateError('release seal intent 更新了多行');
    return updated == 1;
  }

  Future<E2eeSyncSealPlan> readSealPlan({
    required E2eeSyncSealLease lease,
    required E2eeAccountRecordId recordId,
  }) {
    return _database.transaction(() async {
      if (await _currentSealLease(lease) == null) {
        throw const E2eeSyncOutboxBlocked(E2eeSyncOutboxBlockReason.leaseLost);
      }
      if (await _activeOutboxByRecord(recordId.wireValue) != null) {
        throw const E2eeSyncOutboxBlocked(
          E2eeSyncOutboxBlockReason.activeOutbox,
        );
      }
      final snapshot = await _readHistorySnapshot(
        lease.intent.entityKey,
        recordId.wireValue,
      );
      return E2eeSyncSealPlan._(
        lease: lease,
        recordId: recordId,
        logicalVersion: snapshot.logicalVersion,
        parentDigests: snapshot.parentDigests,
        expectedRevision: snapshot.expectedRevision,
        remoteDigest: snapshot.remoteDigest,
        hadRemoteRow: snapshot.hadRemoteRow,
        remoteLastChangeSeq: snapshot.remoteLastChangeSeq,
      );
    });
  }

  Future<bool> commitSealed({
    required E2eeSyncSealPlan plan,
    required E2eeSealedAccountRecordState state,
    required String accountUserId,
    required String actorDeviceId,
    required DateTime now,
  }) {
    final accountId = _requireCanonicalUuidV4(accountUserId, 'accountUserId');
    final deviceId = _requireCanonicalUuidV4(actorDeviceId, 'actorDeviceId');
    final timestamp = _requireStorageTime(now, 'now');
    _requireSealedMatchesPlan(plan, state, deviceId);

    return _database.transaction(() async {
      if (await _currentSealLease(plan.lease) == null ||
          !plan.lease.leaseExpiresAt.isAfter(timestamp) ||
          await _activeOutboxByRecord(plan.recordId.wireValue) != null) {
        return false;
      }
      final current = await _readHistorySnapshot(
        plan.lease.intent.entityKey,
        plan.recordId.wireValue,
      );
      if (!_historyMatchesPlan(current, plan)) return false;
      final reusedOperation =
          await (_database.select(_database.e2eeSyncOperationRows)
                ..where((row) => row.operationId.equals(state.operationId)))
              .getSingleOrNull();
      final reusedDigest =
          await (_database.select(_database.e2eeSyncOperationRows)
                ..where((row) => row.stateDigest.equals(state.digest.bytes)))
              .getSingleOrNull();
      if (reusedOperation != null || reusedDigest != null) {
        throw StateError('operationId 或状态摘要已被持久化');
      }
      await _database
          .into(_database.e2eeSyncOperationRows)
          .insert(
            E2eeSyncOperationRowsCompanion.insert(
              operationId: state.operationId,
              stateDigest: _copyBytes(state.digest.bytes),
              recordId: plan.recordId.wireValue,
              entityType: plan.lease.intent.entityKey.entityType,
              entityId: plan.lease.intent.entityKey.entityId,
              intentId: plan.lease.intent.intentId,
              intentGeneration: plan.lease.intent.generation,
              expectedRevision: plan.expectedRevision,
              accountUserId: accountId,
              actorDeviceId: deviceId,
              claimedWriterKeyVersion: state.claimedWriterKeyVersion,
              outcome: 'active',
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          );
      await _database
          .into(_database.e2eeSyncOutboxRows)
          .insert(
            E2eeSyncOutboxRowsCompanion.insert(
              operationId: state.operationId,
              recordId: plan.recordId.wireValue,
              envelopeVersion: e2eeAccountRecordEnvelopeVersion,
              keyEpoch: state.keyEpoch,
              ciphertext: _copyBytes(state.record.ciphertext),
              phase: 'ready',
              transitionVersion: 1,
              attemptCount: 0,
              nextAttemptAt: timestamp,
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          );
      final deleted = await (_database.delete(
        _database.e2eeSyncIntentRows,
      )..where((row) => _matchesSealLease(row, plan.lease))).go();
      if (deleted != 1) throw StateError('seal CAS 删除意图失败');
      return true;
    });
  }

  Future<List<E2eeSyncClaimedOutboxMutation>> claimSendBatch({
    required String accountUserId,
    required String actorDeviceId,
    required String leaseOwner,
    required DateTime leaseExpiresAt,
    required DateTime now,
  }) {
    final accountId = _requireCanonicalUuidV4(accountUserId, 'accountUserId');
    final deviceId = _requireCanonicalUuidV4(actorDeviceId, 'actorDeviceId');
    final owner = _requireBoundedText(leaseOwner, 'leaseOwner');
    final timestamp = _requireStorageTime(now, 'now');
    final expiry = _requireStorageTime(leaseExpiresAt, 'leaseExpiresAt');
    if (!expiry.isAfter(timestamp)) {
      throw const FormatException('send lease 必须晚于当前时间');
    }

    return _database.transaction(() async {
      final outbox = _database.e2eeSyncOutboxRows;
      final operations = _database.e2eeSyncOperationRows;
      final query = _database.select(outbox).join([
        innerJoin(
          operations,
          operations.operationId.equalsExp(outbox.operationId) &
              operations.recordId.equalsExp(outbox.recordId),
        ),
      ]);
      query.where(
        operations.outcome.equals('active') &
            operations.accountUserId.equals(accountId) &
            operations.actorDeviceId.equals(deviceId) &
            ((outbox.phase.equals('ready') &
                    outbox.nextAttemptAt.isSmallerOrEqualValue(
                      timestamp.microsecondsSinceEpoch,
                    )) |
                (outbox.phase.equals('sending') &
                    outbox.leaseExpiresAt.isSmallerOrEqualValue(
                      timestamp.microsecondsSinceEpoch,
                    ))),
      );
      query.orderBy([
        OrderingTerm.asc(outbox.nextAttemptAt),
        OrderingTerm.asc(outbox.createdAt),
        OrderingTerm.asc(outbox.operationId),
      ]);
      query.limit(_maxSendBatchCount);

      final candidates = await query.get();
      final claims = <E2eeSyncClaimedOutboxMutation>[];
      var ciphertextBytes = 0;
      for (final joined in candidates) {
        final operation = joined.readTable(operations);
        final stored = joined.readTable(outbox);
        if (ciphertextBytes + stored.ciphertext.length >
            _maxSendBatchCiphertextBytes) {
          break;
        }
        if (stored.transitionVersion >= _maxPositiveInt63 ||
            stored.attemptCount >= _maxPositiveInt63) {
          throw StateError('outbox 发送计数已耗尽');
        }
        final token = const Uuid().v4();
        final nextTransitionVersion = stored.transitionVersion + 1;
        final nextAttemptCount = stored.attemptCount + 1;
        final updated =
            await (_database.update(outbox)..where(
                  (row) =>
                      row.operationId.equals(stored.operationId) &
                      row.recordId.equals(stored.recordId) &
                      row.phase.equals(stored.phase) &
                      row.transitionVersion.equals(stored.transitionVersion),
                ))
                .write(
                  E2eeSyncOutboxRowsCompanion(
                    phase: const Value('sending'),
                    leaseToken: Value(token),
                    leaseOwnerSessionId: Value(owner),
                    leaseExpiresAt: Value(expiry),
                    transitionVersion: Value(nextTransitionVersion),
                    attemptCount: Value(nextAttemptCount),
                    updatedAt: Value(timestamp),
                  ),
                );
        if (updated == 0) continue;
        if (updated != 1) throw StateError('claim send CAS 更新了多行');
        claims.add(
          _claimFromRows(
            operation: operation,
            outbox: stored,
            leaseToken: token,
            leaseOwner: owner,
            transitionVersion: nextTransitionVersion,
            attemptCount: nextAttemptCount,
          ),
        );
        ciphertextBytes += stored.ciphertext.length;
      }
      return List.unmodifiable(claims);
    });
  }

  Future<bool> releaseUnknownResult({
    required E2eeSyncClaimedOutboxMutation claim,
    required DateTime nextAttemptAt,
    required String errorKind,
    required DateTime now,
  }) {
    final timestamp = _requireStorageTime(now, 'now');
    final retryAt = _requireStorageTime(nextAttemptAt, 'nextAttemptAt');
    final failureKind = _requireErrorCode(errorKind, 'errorKind');
    if (retryAt.isBefore(timestamp)) {
      throw const FormatException('outbox 重试时间不得早于当前时间');
    }
    if (claim.transitionVersion >= _maxPositiveInt63) {
      throw StateError('outbox transitionVersion 已耗尽');
    }
    return _database.transaction(() async {
      if (await _currentClaim(claim) == null) return false;
      final updated =
          await (_database.update(
            _database.e2eeSyncOutboxRows,
          )..where((row) => _matchesSendClaim(row, claim))).write(
            E2eeSyncOutboxRowsCompanion(
              phase: const Value('ready'),
              leaseToken: const Value(null),
              leaseOwnerSessionId: const Value(null),
              leaseExpiresAt: const Value(null),
              transitionVersion: Value(claim.transitionVersion + 1),
              nextAttemptAt: Value(retryAt),
              lastFailureKind: Value(failureKind),
              updatedAt: Value(timestamp),
            ),
          );
      if (updated > 1) throw StateError('release unknown CAS 更新了多行');
      return updated == 1;
    });
  }

  Future<bool> settleApplied({
    required E2eeSyncClaimedOutboxMutation claim,
    required E2eeAuthenticatedAccountRecordState state,
    required int revision,
    required int changeSeq,
    required DateTime now,
  }) async {
    if (revision < 1 || revision > _maxPositiveInt63) {
      throw const FormatException('applied revision 超出范围');
    }
    if (changeSeq < 0 || changeSeq > _maxPositiveInt63) {
      throw const FormatException('applied changeSeq 超出范围');
    }
    final timestamp = _requireStorageTime(now, 'now');
    _requireAuthenticatedMatchesClaim(claim, state);
    final settlement = await _database.transaction(() async {
      final current = await _currentClaim(claim);
      if (current == null) return _AppliedSettlement.staleClaim;

      final remote = await (_database.select(
        _database.e2eeSyncRemoteRecordRows,
      )..where((row) => row.recordId.equals(claim.recordId))).getSingleOrNull();
      final disposition = _classifyApplied(
        current: remote,
        revision: revision,
        changeSeq: changeSeq,
        digest: state.digest,
      );

      if (disposition == _AppliedDisposition.advance ||
          disposition == _AppliedDisposition.replay) {
        // 旧响应不能成为新远端状态的父节点；只接受当前或推进中的服务端认证状态。
        await _recordLedger.accept(state);
      }

      final operationUpdated =
          await (_database.update(_database.e2eeSyncOperationRows)..where(
                (row) =>
                    row.operationId.equals(claim.operationId) &
                    row.recordId.equals(claim.recordId) &
                    row.outcome.equals('active'),
              ))
              .write(
                E2eeSyncOperationRowsCompanion(
                  outcome: const Value('applied'),
                  resultRevision: Value(revision),
                  resultChangeSeq: Value(changeSeq),
                  currentRevision: const Value(null),
                  errorCode: const Value(null),
                  updatedAt: Value(timestamp),
                ),
              );
      if (operationUpdated != 1) {
        throw StateError('applied 操作 CAS 失败');
      }
      await _deleteClaimedOutbox(claim);
      if (disposition == _AppliedDisposition.advance) {
        await _writeRemoteReady(
          recordId: claim.recordId,
          revision: revision,
          changeSeq: changeSeq,
          digest: state.digest,
          now: timestamp,
        );
      } else if (disposition == _AppliedDisposition.inconsistent) {
        await _writeRemoteBlocked(
          recordId: claim.recordId,
          gate: 'quarantined',
          observedRevision: revision,
          errorCode: 'REMOTE_APPLIED_METADATA_MISMATCH',
          now: timestamp,
        );
        return _AppliedSettlement.inconsistent;
      }
      return _AppliedSettlement.settled;
    });
    if (settlement == _AppliedSettlement.inconsistent) {
      throw StateError('applied 结果违反远端 revision/changeSeq 单调性');
    }
    return settlement == _AppliedSettlement.settled;
  }

  Future<bool> settleConflict({
    required E2eeSyncClaimedOutboxMutation claim,
    required int? currentRevision,
    required String newIntentId,
    required DateTime now,
  }) {
    if (currentRevision != null &&
        (currentRevision < 1 || currentRevision > _maxPositiveInt63)) {
      throw const FormatException('conflict currentRevision 超出范围');
    }
    final intentId = _requireCanonicalUuidV4(newIntentId, 'newIntentId');
    final timestamp = _requireStorageTime(now, 'now');
    return _database.transaction(() async {
      final current = await _currentClaim(claim);
      if (current == null) return false;
      final operationUpdated =
          await (_database.update(_database.e2eeSyncOperationRows)..where(
                (row) =>
                    row.operationId.equals(claim.operationId) &
                    row.recordId.equals(claim.recordId) &
                    row.outcome.equals('active'),
              ))
              .write(
                E2eeSyncOperationRowsCompanion(
                  outcome: const Value('conflict'),
                  resultRevision: const Value(null),
                  resultChangeSeq: const Value(null),
                  currentRevision: Value(currentRevision),
                  errorCode: const Value(null),
                  updatedAt: Value(timestamp),
                ),
              );
      if (operationUpdated != 1) {
        throw StateError('conflict 操作 CAS 失败');
      }
      await _deleteClaimedOutbox(claim);
      await _writeRemoteBlocked(
        recordId: claim.recordId,
        gate: 'requires-pull',
        observedRevision: currentRevision,
        errorCode: null,
        now: timestamp,
      );
      await _ensureConflictIntent(
        operation: current.operation,
        newIntentId: intentId,
        now: timestamp,
      );
      return true;
    });
  }

  Future<bool> settleRejected({
    required E2eeSyncClaimedOutboxMutation claim,
    required String errorCode,
    required DateTime now,
  }) {
    return _settleRejectedOrCorrupt(
      claim: claim,
      errorCode: _requireErrorCode(errorCode, 'errorCode'),
      now: _requireStorageTime(now, 'now'),
    );
  }

  Future<bool> quarantineCorrupt({
    required E2eeSyncClaimedOutboxMutation claim,
    required String errorCode,
    required DateTime now,
  }) {
    return _settleRejectedOrCorrupt(
      claim: claim,
      errorCode: _requireErrorCode(errorCode, 'errorCode'),
      now: _requireStorageTime(now, 'now'),
    );
  }

  Future<bool> _settleRejectedOrCorrupt({
    required E2eeSyncClaimedOutboxMutation claim,
    required String errorCode,
    required DateTime now,
  }) {
    return _database.transaction(() async {
      if (await _currentClaim(claim) == null) return false;
      final operationUpdated =
          await (_database.update(_database.e2eeSyncOperationRows)..where(
                (row) =>
                    row.operationId.equals(claim.operationId) &
                    row.recordId.equals(claim.recordId) &
                    row.outcome.equals('active'),
              ))
              .write(
                E2eeSyncOperationRowsCompanion(
                  outcome: const Value('rejected'),
                  resultRevision: const Value(null),
                  resultChangeSeq: const Value(null),
                  currentRevision: const Value(null),
                  errorCode: Value(errorCode),
                  updatedAt: Value(now),
                ),
              );
      if (operationUpdated != 1) {
        throw StateError('rejected 操作 CAS 失败');
      }
      await _deleteClaimedOutbox(claim);
      await _writeRemoteBlocked(
        recordId: claim.recordId,
        gate: 'quarantined',
        observedRevision: null,
        errorCode: errorCode,
        now: now,
      );
      return true;
    });
  }

  Future<E2eeSyncIntentRow?> _intentByKey(SyncEntityKey key) {
    validateSyncEntityKey(key);
    return (_database.select(_database.e2eeSyncIntentRows)..where(
          (row) =>
              row.entityType.equals(key.entityType) &
              row.entityId.equals(key.entityId),
        ))
        .getSingleOrNull();
  }

  Future<E2eeSyncIntentRow?> _currentSealLease(E2eeSyncSealLease lease) {
    return (_database.select(
      _database.e2eeSyncIntentRows,
    )..where((row) => _matchesSealLease(row, lease))).getSingleOrNull();
  }

  Future<E2eeSyncOutboxRow?> _activeOutboxByRecord(String recordId) {
    return (_database.select(
      _database.e2eeSyncOutboxRows,
    )..where((row) => row.recordId.equals(recordId))).getSingleOrNull();
  }

  Future<_HistorySnapshot> _readHistorySnapshot(
    SyncEntityKey entityKey,
    String recordId,
  ) async {
    validateSyncEntityKey(entityKey);
    final remote = await (_database.select(
      _database.e2eeSyncRemoteRecordRows,
    )..where((row) => row.recordId.equals(recordId))).getSingleOrNull();
    if (remote?.gate == 'requires-pull') {
      throw const E2eeSyncOutboxBlocked(E2eeSyncOutboxBlockReason.requiresPull);
    }
    if (remote?.gate == 'quarantined') {
      throw const E2eeSyncOutboxBlocked(E2eeSyncOutboxBlockReason.quarantined);
    }

    final states = _database.e2eeSyncRecordStateRows;
    final heads = _database.e2eeSyncRecordHeadRows;
    final query = _database.select(states).join([
      innerJoin(heads, heads.digest.equalsExp(states.digest)),
    ])..where(states.recordId.equals(recordId));
    query.orderBy([OrderingTerm.asc(states.digest)]);
    final joinedHeads = await query.get();
    if (joinedHeads.length > 2) {
      throw const E2eeSyncOutboxBlocked(
        E2eeSyncOutboxBlockReason.inconsistentHistory,
      );
    }
    final stateHeads = [
      for (final joined in joinedHeads) joined.readTable(states),
    ];
    for (final state in stateHeads) {
      final storedKey = _entityKeyFromStorage(state.entityType, state.entityId);
      if (storedKey != entityKey) {
        throw const E2eeSyncOutboxBlocked(
          E2eeSyncOutboxBlockReason.inconsistentHistory,
        );
      }
    }
    final parentDigests = [
      for (final state in stateHeads)
        E2eeAccountRecordStateDigest.fromTrustedStorage(state.digest),
    ];
    final remoteDigest = remote?.stateDigest == null
        ? null
        : E2eeAccountRecordStateDigest.fromTrustedStorage(remote!.stateDigest!);
    if (remote?.revision == null) {
      if (stateHeads.isNotEmpty ||
          remote?.lastChangeSeq != null ||
          remoteDigest != null) {
        throw const E2eeSyncOutboxBlocked(
          E2eeSyncOutboxBlockReason.inconsistentHistory,
        );
      }
      return _HistorySnapshot(
        hadRemoteRow: remote != null,
        expectedRevision: 0,
        remoteLastChangeSeq: null,
        remoteDigest: null,
        logicalVersion: 1,
        parentDigests: const [],
      );
    }
    if (stateHeads.isEmpty ||
        remote?.lastChangeSeq == null ||
        remoteDigest == null ||
        !parentDigests.contains(remoteDigest)) {
      throw const E2eeSyncOutboxBlocked(
        E2eeSyncOutboxBlockReason.inconsistentHistory,
      );
    }
    var maximumLogicalVersion = 0;
    for (final state in stateHeads) {
      if (state.logicalVersion > maximumLogicalVersion) {
        maximumLogicalVersion = state.logicalVersion;
      }
    }
    if (maximumLogicalVersion >= _maxPositiveInt63) {
      throw StateError('认证记录 logicalVersion 已耗尽');
    }
    return _HistorySnapshot(
      hadRemoteRow: true,
      expectedRevision: remote!.revision!,
      remoteLastChangeSeq: remote.lastChangeSeq,
      remoteDigest: remoteDigest,
      logicalVersion: maximumLogicalVersion + 1,
      parentDigests: parentDigests,
    );
  }

  Future<_CurrentClaim?> _currentClaim(
    E2eeSyncClaimedOutboxMutation claim,
  ) async {
    final outbox = await (_database.select(
      _database.e2eeSyncOutboxRows,
    )..where((row) => _matchesSendClaim(row, claim))).getSingleOrNull();
    if (outbox == null) return null;
    final operation =
        await (_database.select(_database.e2eeSyncOperationRows)..where(
              (row) =>
                  row.operationId.equals(claim.operationId) &
                  row.recordId.equals(claim.recordId) &
                  row.outcome.equals('active'),
            ))
            .getSingleOrNull();
    if (operation == null) return null;
    if (!_operationMatchesClaim(operation, claim) ||
        outbox.recordId != operation.recordId ||
        outbox.envelopeVersion != claim.envelopeVersion ||
        outbox.keyEpoch != claim.keyEpoch ||
        outbox.attemptCount != claim.attemptCount ||
        !_sameBytes(outbox.ciphertext, claim.ciphertext)) {
      throw StateError('outbox claim 与持久化元数据不一致');
    }
    return _CurrentClaim(operation: operation);
  }

  Future<void> _deleteClaimedOutbox(E2eeSyncClaimedOutboxMutation claim) async {
    final deleted = await (_database.delete(
      _database.e2eeSyncOutboxRows,
    )..where((row) => _matchesSendClaim(row, claim))).go();
    if (deleted != 1) throw StateError('outbox 发送租约 CAS 删除失败');
  }

  Future<void> _writeRemoteReady({
    required String recordId,
    required int revision,
    required int changeSeq,
    required E2eeAccountRecordStateDigest digest,
    required DateTime now,
  }) async {
    final current = await (_database.select(
      _database.e2eeSyncRemoteRecordRows,
    )..where((row) => row.recordId.equals(recordId))).getSingleOrNull();
    if (current == null) {
      await _database
          .into(_database.e2eeSyncRemoteRecordRows)
          .insert(
            E2eeSyncRemoteRecordRowsCompanion.insert(
              recordId: recordId,
              revision: Value(revision),
              lastChangeSeq: Value(changeSeq),
              stateDigest: Value(_copyBytes(digest.bytes)),
              gate: 'ready',
              createdAt: now,
              updatedAt: now,
            ),
          );
      return;
    }
    await (_database.update(
      _database.e2eeSyncRemoteRecordRows,
    )..where((row) => row.recordId.equals(recordId))).write(
      E2eeSyncRemoteRecordRowsCompanion(
        revision: Value(revision),
        lastChangeSeq: Value(changeSeq),
        stateDigest: Value(_copyBytes(digest.bytes)),
        gate: const Value('ready'),
        observedRevision: const Value(null),
        errorCode: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> _writeRemoteBlocked({
    required String recordId,
    required String gate,
    required int? observedRevision,
    required String? errorCode,
    required DateTime now,
  }) async {
    final current = await (_database.select(
      _database.e2eeSyncRemoteRecordRows,
    )..where((row) => row.recordId.equals(recordId))).getSingleOrNull();
    if (current == null) {
      await _database
          .into(_database.e2eeSyncRemoteRecordRows)
          .insert(
            E2eeSyncRemoteRecordRowsCompanion.insert(
              recordId: recordId,
              gate: gate,
              observedRevision: Value(observedRevision),
              errorCode: Value(errorCode),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return;
    }
    if (current.gate == 'quarantined' && gate != 'quarantined') {
      return;
    }
    final nextObservedRevision = switch ((
      current.observedRevision,
      observedRevision,
    )) {
      (final int currentValue, final int nextValue) =>
        currentValue > nextValue ? currentValue : nextValue,
      (final int currentValue, null) => currentValue,
      (null, final int nextValue) => nextValue,
      (null, null) => null,
    };
    await (_database.update(
      _database.e2eeSyncRemoteRecordRows,
    )..where((row) => row.recordId.equals(recordId))).write(
      E2eeSyncRemoteRecordRowsCompanion(
        gate: Value(gate),
        observedRevision: Value(nextObservedRevision),
        errorCode: Value(errorCode),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> _ensureConflictIntent({
    required E2eeSyncOperationRow operation,
    required String newIntentId,
    required DateTime now,
  }) async {
    final key = _entityKeyFromStorage(operation.entityType, operation.entityId);
    if (await _intentByKey(key) != null) return;
    if (operation.intentGeneration >= _maxPositiveInt63) {
      throw StateError('同步意图 generation 已耗尽');
    }
    await _database
        .into(_database.e2eeSyncIntentRows)
        .insert(
          E2eeSyncIntentRowsCompanion.insert(
            entityType: key.entityType,
            entityId: key.entityId,
            intentId: newIntentId,
            generation: operation.intentGeneration + 1,
            phase: 'dirty',
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
}

final class _HistorySnapshot {
  _HistorySnapshot({
    required this.hadRemoteRow,
    required this.expectedRevision,
    required this.remoteLastChangeSeq,
    required this.remoteDigest,
    required this.logicalVersion,
    required List<E2eeAccountRecordStateDigest> parentDigests,
  }) : parentDigests = List.unmodifiable(parentDigests);

  final bool hadRemoteRow;
  final int expectedRevision;
  final int? remoteLastChangeSeq;
  final E2eeAccountRecordStateDigest? remoteDigest;
  final int logicalVersion;
  final List<E2eeAccountRecordStateDigest> parentDigests;
}

final class _CurrentClaim {
  const _CurrentClaim({required this.operation});

  final E2eeSyncOperationRow operation;
}

enum _AppliedDisposition { advance, replay, stale, inconsistent }

enum _AppliedSettlement { staleClaim, settled, inconsistent }

_AppliedDisposition _classifyApplied({
  required E2eeSyncRemoteRecordRow? current,
  required int revision,
  required int changeSeq,
  required E2eeAccountRecordStateDigest digest,
}) {
  if (current == null) return _AppliedDisposition.advance;
  if (current.gate != 'ready') {
    return _AppliedDisposition.stale;
  }
  final currentRevision = current.revision;
  final currentChangeSeq = current.lastChangeSeq;
  final currentDigest = current.stateDigest;
  if (currentRevision == null &&
      currentChangeSeq == null &&
      currentDigest == null) {
    return _AppliedDisposition.advance;
  }
  if (currentRevision == null ||
      currentChangeSeq == null ||
      currentDigest == null) {
    return _AppliedDisposition.inconsistent;
  }

  final revisionOrder = revision.compareTo(currentRevision);
  final changeSeqOrder = changeSeq.compareTo(currentChangeSeq);
  if (revisionOrder > 0 && changeSeqOrder > 0) {
    return _AppliedDisposition.advance;
  }
  if (revisionOrder < 0 && changeSeqOrder < 0) {
    return _AppliedDisposition.stale;
  }
  if (revisionOrder == 0 && changeSeqOrder == 0) {
    return _sameBytes(currentDigest, digest.bytes)
        ? _AppliedDisposition.replay
        : _AppliedDisposition.inconsistent;
  }
  return _AppliedDisposition.inconsistent;
}

E2eeSyncIntentRef _intentRefFromRow(E2eeSyncIntentRow row) {
  return E2eeSyncIntentRef(
    intentId: row.intentId,
    entityKey: _entityKeyFromStorage(row.entityType, row.entityId),
    generation: row.generation,
  );
}

SyncEntityKey _entityKeyFromStorage(String entityType, String entityId) {
  final key = SyncEntityKey(entityType: entityType, entityId: entityId);
  validateSyncEntityKey(key);
  return key;
}

Expression<bool> _matchesSealLease(
  $E2eeSyncIntentRowsTable row,
  E2eeSyncSealLease lease,
) {
  return row.entityType.equals(lease.intent.entityKey.entityType) &
      row.entityId.equals(lease.intent.entityKey.entityId) &
      row.intentId.equals(lease.intent.intentId) &
      row.generation.equals(lease.intent.generation) &
      row.phase.equals('sealing') &
      row.sealLeaseToken.equals(lease.leaseToken) &
      row.sealOwnerSessionId.equals(lease.leaseOwner) &
      row.sealLeaseExpiresAt.equalsValue(lease.leaseExpiresAt);
}

Expression<bool> _matchesSendClaim(
  $E2eeSyncOutboxRowsTable row,
  E2eeSyncClaimedOutboxMutation claim,
) {
  return row.operationId.equals(claim.operationId) &
      row.recordId.equals(claim.recordId) &
      row.phase.equals('sending') &
      row.leaseToken.equals(claim.leaseToken) &
      row.leaseOwnerSessionId.equals(claim.leaseOwner) &
      row.transitionVersion.equals(claim.transitionVersion);
}

E2eeSyncClaimedOutboxMutation _claimFromRows({
  required E2eeSyncOperationRow operation,
  required E2eeSyncOutboxRow outbox,
  required String leaseToken,
  required String leaseOwner,
  required int transitionVersion,
  required int attemptCount,
}) {
  if (operation.operationId != outbox.operationId ||
      operation.recordId != outbox.recordId ||
      operation.outcome != 'active') {
    throw StateError('operation 与 outbox 关联不一致');
  }
  return E2eeSyncClaimedOutboxMutation(
    operationId: operation.operationId,
    accountUserId: operation.accountUserId,
    actorDeviceId: operation.actorDeviceId,
    entityKey: _entityKeyFromStorage(operation.entityType, operation.entityId),
    recordId: operation.recordId,
    envelopeVersion: outbox.envelopeVersion,
    keyEpoch: outbox.keyEpoch,
    ciphertext: outbox.ciphertext,
    digest: E2eeAccountRecordStateDigest.fromTrustedStorage(
      operation.stateDigest,
    ),
    expectedRevision: operation.expectedRevision,
    claimedWriterKeyVersion: operation.claimedWriterKeyVersion,
    leaseToken: leaseToken,
    leaseOwner: leaseOwner,
    transitionVersion: transitionVersion,
    attemptCount: attemptCount,
  );
}

bool _operationMatchesClaim(
  E2eeSyncOperationRow operation,
  E2eeSyncClaimedOutboxMutation claim,
) {
  return operation.operationId == claim.operationId &&
      operation.recordId == claim.recordId &&
      operation.entityType == claim.entityKey.entityType &&
      operation.entityId == claim.entityKey.entityId &&
      operation.expectedRevision == claim.expectedRevision &&
      operation.accountUserId == claim.accountUserId &&
      operation.actorDeviceId == claim.actorDeviceId &&
      operation.claimedWriterKeyVersion == claim.claimedWriterKeyVersion &&
      _sameBytes(operation.stateDigest, claim.digest.bytes);
}

bool _historyMatchesPlan(_HistorySnapshot current, E2eeSyncSealPlan plan) {
  return current.hadRemoteRow == plan.hadRemoteRow &&
      current.expectedRevision == plan.expectedRevision &&
      current.remoteLastChangeSeq == plan.remoteLastChangeSeq &&
      current.remoteDigest == plan.remoteDigest &&
      current.logicalVersion == plan.logicalVersion &&
      _sameDigestList(current.parentDigests, plan.parentDigests);
}

void _requireSealedMatchesPlan(
  E2eeSyncSealPlan plan,
  E2eeSealedAccountRecordState state,
  String actorDeviceId,
) {
  if (state.record.recordId != plan.recordId ||
      state.logicalVersion != plan.logicalVersion ||
      state.operationId.isEmpty ||
      state.claimedWriterDeviceId != actorDeviceId ||
      state.record.ciphertext.isEmpty ||
      !_sameDigestList(state.parentDigests, plan.parentDigests)) {
    throw const FormatException('sealed state 与 seal plan 不匹配');
  }
}

void _requireAuthenticatedMatchesClaim(
  E2eeSyncClaimedOutboxMutation claim,
  E2eeAuthenticatedAccountRecordState state,
) {
  if (state.recordId.wireValue != claim.recordId ||
      state.entityKey != claim.entityKey ||
      state.digest != claim.digest ||
      state.operationId != claim.operationId ||
      state.claimedWriterDeviceId != claim.actorDeviceId ||
      state.claimedWriterKeyVersion != claim.claimedWriterKeyVersion ||
      state.keyEpoch != claim.keyEpoch) {
    throw const FormatException('认证状态与 outbox claim 不匹配');
  }
}

bool _sameDigestList(
  List<E2eeAccountRecordStateDigest> left,
  List<E2eeAccountRecordStateDigest> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _sameBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

Uint8List _copyBytes(Uint8List value) =>
    Uint8List.fromList(value).asUnmodifiableView();

final _canonicalUuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

String _requireCanonicalUuidV4(String value, String name) {
  if (!_canonicalUuidV4Pattern.hasMatch(value)) {
    throw FormatException('$name 必须为规范 UUIDv4');
  }
  return value;
}

int _requirePositiveInt63(int value, String name) {
  if (value < 1 || value > _maxPositiveInt63) {
    throw FormatException('$name 必须位于正 int63 范围');
  }
  return value;
}

String _requireBoundedText(String value, String name) {
  final bytes = utf8.encode(value).length;
  if (bytes < 1 || bytes > 1024) {
    throw FormatException('$name UTF-8 长度必须位于 1 到 1024 之间');
  }
  return value;
}

String _requireErrorCode(String value, String name) {
  final bytes = utf8.encode(value).length;
  if (bytes < 1 || bytes > 100) {
    throw FormatException('$name UTF-8 长度必须位于 1 到 100 之间');
  }
  return value;
}

DateTime _requireStorageTime(DateTime value, String name) {
  final normalized = value.toUtc();
  if (normalized.microsecondsSinceEpoch < 0) {
    throw FormatException('$name 不得早于 Unix epoch');
  }
  return normalized;
}
