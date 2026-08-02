part of 'chat_database_repository.dart';

const _attachmentUploadMaxPositiveInt63 = 0x7fffffffffffffff;
const _attachmentUploadPhases = <String>[
  'create-pending',
  'manifest-pending',
  'uploading',
  'commit-pending',
];

enum E2eeAttachmentUploadPhase {
  createPending('create-pending'),
  manifestPending('manifest-pending'),
  uploading('uploading'),
  commitPending('commit-pending'),
  committed('committed');

  const E2eeAttachmentUploadPhase(this.wireValue);

  final String wireValue;

  static E2eeAttachmentUploadPhase fromWireValue(String value) {
    for (final phase in values) {
      if (phase.wireValue == value) return phase;
    }
    throw StateError('附件上传阶段不受支持');
  }
}

sealed class E2eeAttachmentUploadTarget {
  const E2eeAttachmentUploadTarget();
}

final class E2eeMessageAttachmentUploadTarget
    extends E2eeAttachmentUploadTarget {
  E2eeMessageAttachmentUploadTarget({
    required String revisionId,
    required int ordinal,
  }) : revisionId = _requireAttachmentStorageText(
         revisionId,
         'revisionId',
         1024,
       ),
       ordinal = _requireAttachmentTargetOrdinal(ordinal);

  final String revisionId;
  final int ordinal;
}

final class E2eeConfigAssetUploadTarget extends E2eeAttachmentUploadTarget {
  E2eeConfigAssetUploadTarget(this.key);

  final E2eeConfigAssetKey key;
}

final class E2eeAttachmentUploadDraft {
  E2eeAttachmentUploadDraft({
    required this.descriptor,
    required String localAssetId,
    required this.target,
    required String sourcePath,
    required String createMutationId,
    required String commitMutationId,
  }) : localAssetId = _requireAttachmentStorageText(
         localAssetId,
         'localAssetId',
         1024,
       ),
       sourcePath = _requireAttachmentStorageText(
         sourcePath,
         'sourcePath',
         32768,
       ),
       createMutationId = _requireCanonicalUuidV4(
         createMutationId,
         'createMutationId',
       ),
       commitMutationId = _requireCanonicalUuidV4(
         commitMutationId,
         'commitMutationId',
       ) {
    if (this.createMutationId == this.commitMutationId) {
      throw const FormatException('附件创建与提交 mutationId 不得相同');
    }
  }

  final E2eeAttachmentDescriptor descriptor;
  final String localAssetId;
  final E2eeAttachmentUploadTarget target;
  final String sourcePath;
  final String createMutationId;
  final String commitMutationId;
}

final class E2eeAttachmentPendingChunk {
  E2eeAttachmentPendingChunk._({
    required this.index,
    required this.mutationId,
    required this.ciphertextPath,
    required this.ciphertextBytes,
    required Uint8List ciphertextSha256,
  }) : ciphertextSha256 = Uint8List.fromList(
         ciphertextSha256,
       ).asUnmodifiableView();

  final int index;
  final String mutationId;
  final String ciphertextPath;
  final int ciphertextBytes;
  final Uint8List ciphertextSha256;
}

final class E2eeAttachmentUploadState {
  E2eeAttachmentUploadState._({
    required this.descriptor,
    required this.localAssetId,
    required this.target,
    required this.sourcePath,
    required this.phase,
    required this.createMutationId,
    required this.uploadId,
    required this.manifestKeyEpoch,
    required this.manifestRevision,
    required Uint8List? manifestCiphertext,
    required this.commitMutationId,
    required this.nextChunkIndex,
    required this.pendingChunk,
    required this.transitionVersion,
    required this.attemptCount,
    required this.consecutiveFailureCount,
    required this.nextAttemptAt,
    required this.lastFailureKind,
    required this.terminalFailureKind,
    required this.createdAt,
    required this.updatedAt,
  }) : manifestCiphertext = manifestCiphertext == null
           ? null
           : Uint8List.fromList(manifestCiphertext).asUnmodifiableView();

  final E2eeAttachmentDescriptor descriptor;
  final String localAssetId;
  final E2eeAttachmentUploadTarget target;
  final String sourcePath;
  final E2eeAttachmentUploadPhase phase;
  final String createMutationId;
  final String? uploadId;
  final int manifestKeyEpoch;
  final int manifestRevision;
  final Uint8List? manifestCiphertext;
  final String commitMutationId;
  final int nextChunkIndex;
  final E2eeAttachmentPendingChunk? pendingChunk;
  final int transitionVersion;
  final int attemptCount;
  final int consecutiveFailureCount;
  final DateTime nextAttemptAt;
  final String? lastFailureKind;
  final String? terminalFailureKind;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get attachmentId => descriptor.attachmentId;
}

final class E2eeAttachmentUploadLease {
  E2eeAttachmentUploadLease._({
    required this.state,
    required this.leaseToken,
    required this.leaseOwner,
    required this.leaseExpiresAt,
  });

  final E2eeAttachmentUploadState state;
  final String leaseToken;
  final String leaseOwner;
  final DateTime leaseExpiresAt;
}

final class E2eeAttachmentUploadCommands {
  E2eeAttachmentUploadCommands._(this._database);

  final AppDatabase _database;

  Future<E2eeAttachmentUploadState> create({
    required E2eeAttachmentUploadDraft draft,
    required DateTime now,
  }) async {
    final timestamp = _requireStorageTime(now, 'now');
    final descriptor = draft.descriptor;
    return _database.transaction(() async {
      final existing = await _uploadRowByTarget(draft.target);
      if (existing != null) {
        return _requireSameUploadSource(existing, draft);
      }
      await _requireTargetMatchesDraft(draft);
      final asset = await (_database.select(
        _database.assetRows,
      )..where((row) => row.id.equals(draft.localAssetId))).getSingleOrNull();
      if (asset == null ||
          asset.contentHash != _attachmentDigestHex(descriptor.contentSha256) ||
          asset.path != draft.sourcePath ||
          asset.byteSize != descriptor.totalPlaintextBytes) {
        throw StateError('附件上传本地资产与认证描述不一致');
      }
      final targetColumns = _attachmentUploadTargetColumns(draft.target);
      await _database
          .into(_database.e2eeAttachmentUploadRows)
          .insert(
            E2eeAttachmentUploadRowsCompanion.insert(
              attachmentId: descriptor.attachmentId,
              localAssetId: draft.localAssetId,
              targetRevisionId: Value(targetColumns.revisionId),
              targetOrdinal: Value(targetColumns.ordinal),
              targetConfigEntityType: Value(targetColumns.configEntityType),
              targetConfigEntityId: Value(targetColumns.configEntityId),
              targetConfigSlot: Value(targetColumns.configSlot),
              sourcePath: draft.sourcePath,
              chunkKeyEpoch: descriptor.chunkKeyEpoch,
              manifestKeyEpoch: descriptor.chunkKeyEpoch,
              manifestRevision: 1,
              kind: descriptor.kind.name,
              displayName: Value(descriptor.displayName),
              mediaType: Value(descriptor.mediaType),
              contentSha256: descriptor.contentSha256,
              wrappedDataKey: descriptor.wrappedDataKey,
              totalPlaintextBytes: descriptor.totalPlaintextBytes,
              chunkCount: descriptor.chunkCiphertextBytes.length,
              totalCiphertextBytes: descriptor.totalCiphertextBytes,
              phase: E2eeAttachmentUploadPhase.createPending.wireValue,
              createMutationId: draft.createMutationId,
              commitMutationId: draft.commitMutationId,
              nextChunkIndex: 0,
              transitionVersion: 1,
              attemptCount: 0,
              consecutiveFailureCount: 0,
              nextAttemptAt: timestamp,
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      final persisted = await _uploadRowByTarget(draft.target);
      if (persisted == null) {
        throw StateError('附件上传自然键创建冲突');
      }
      return _requireSameUploadSource(persisted, draft);
    });
  }

  Future<E2eeAttachmentUploadRow?> _uploadRowByTarget(
    E2eeAttachmentUploadTarget target,
  ) {
    final query = _database.select(_database.e2eeAttachmentUploadRows);
    switch (target) {
      case E2eeMessageAttachmentUploadTarget():
        query.where(
          (row) =>
              row.targetRevisionId.equals(target.revisionId) &
              row.targetOrdinal.equals(target.ordinal),
        );
      case E2eeConfigAssetUploadTarget():
        final key = target.key;
        query.where(
          (row) =>
              row.targetConfigEntityType.equals(key.entityKey.entityType) &
              row.targetConfigEntityId.equals(key.entityKey.entityId) &
              row.targetConfigSlot.equals(key.slot.wireValue),
        );
    }
    return query.getSingleOrNull();
  }

  Future<void> _requireTargetMatchesDraft(
    E2eeAttachmentUploadDraft draft,
  ) async {
    switch (draft.target) {
      case E2eeMessageAttachmentUploadTarget(:final revisionId, :final ordinal):
        final target =
            await (_database.select(_database.messageAssetRows)..where(
                  (row) =>
                      row.revisionId.equals(revisionId) &
                      row.ordinal.equals(ordinal),
                ))
                .getSingleOrNull();
        if (target == null) throw StateError('附件上传目标消息引用不存在');
        _requirePendingTargetMatches(
          assetId: target.assetId,
          attachmentId: target.attachmentId,
          uploadId: target.uploadId,
          chunkKeyEpoch: target.chunkKeyEpoch,
          manifestKeyEpoch: target.manifestKeyEpoch,
          manifestRevision: target.manifestRevision,
          kind: target.kind,
          displayName: target.displayName,
          mediaType: target.mediaType,
          draft: draft,
          context: '消息引用',
        );
      case E2eeConfigAssetUploadTarget(:final key):
        final target =
            await (_database.select(_database.configAssetRows)..where(
                  (row) =>
                      row.entityType.equals(key.entityKey.entityType) &
                      row.entityId.equals(key.entityKey.entityId) &
                      row.slot.equals(key.slot.wireValue),
                ))
                .getSingleOrNull();
        if (target == null) throw StateError('附件上传目标配置资产不存在');
        _requirePendingTargetMatches(
          assetId: target.assetId,
          attachmentId: target.attachmentId,
          uploadId: target.uploadId,
          chunkKeyEpoch: target.chunkKeyEpoch,
          manifestKeyEpoch: target.manifestKeyEpoch,
          manifestRevision: target.manifestRevision,
          kind: target.kind,
          displayName: target.displayName,
          mediaType: target.mediaType,
          draft: draft,
          context: '配置资产',
        );
    }
  }

  Future<E2eeAttachmentUploadState?> readByAttachmentId(
    String attachmentId,
  ) async {
    final id = _requireCanonicalUuidV4(attachmentId, 'attachmentId');
    final row = await (_database.select(
      _database.e2eeAttachmentUploadRows,
    )..where((table) => table.attachmentId.equals(id))).getSingleOrNull();
    return row == null ? null : _stateFromRow(row);
  }

  Future<bool> hasRetryableWork() async {
    final table = _database.e2eeAttachmentUploadRows;
    final query = _database.selectOnly(table)
      ..addColumns(<Expression<Object>>[table.attachmentId])
      ..where(
        table.phase.isIn(_attachmentUploadPhases) &
            table.terminalFailureKind.isNull(),
      )
      ..limit(1);
    return await query.getSingleOrNull() != null;
  }

  Future<E2eeAttachmentUploadLease?> claimDue({
    required String leaseToken,
    required String leaseOwner,
    required DateTime leaseExpiresAt,
    required DateTime now,
  }) {
    final token = _requireBoundedText(leaseToken, 'leaseToken');
    final owner = _requireBoundedText(leaseOwner, 'leaseOwner');
    final timestamp = _requireStorageTime(now, 'now');
    final expiry = _requireStorageTime(leaseExpiresAt, 'leaseExpiresAt');
    if (!expiry.isAfter(timestamp)) {
      throw const FormatException('附件上传租约必须晚于当前时间');
    }

    return _database.transaction(() async {
      final table = _database.e2eeAttachmentUploadRows;
      final query = _database.select(table)
        ..where(
          (row) =>
              row.phase.isIn(_attachmentUploadPhases) &
              row.terminalFailureKind.isNull() &
              row.nextAttemptAt.isSmallerOrEqualValue(
                timestamp.microsecondsSinceEpoch,
              ) &
              (row.leaseToken.isNull() |
                  row.leaseExpiresAt.isSmallerOrEqualValue(
                    timestamp.microsecondsSinceEpoch,
                  )),
        )
        ..orderBy(<OrderClauseGenerator<$E2eeAttachmentUploadRowsTable>>[
          (row) => OrderingTerm.asc(row.nextAttemptAt),
          (row) => OrderingTerm.asc(row.createdAt),
          (row) => OrderingTerm.asc(row.attachmentId),
        ])
        ..limit(1);
      final candidate = await query.getSingleOrNull();
      if (candidate == null) return null;
      try {
        if (candidate.transitionVersion >= _attachmentUploadMaxPositiveInt63 ||
            candidate.attemptCount >= _attachmentUploadMaxPositiveInt63 ||
            candidate.consecutiveFailureCount >=
                _attachmentUploadMaxPositiveInt63) {
          throw StateError('附件上传状态计数已耗尽');
        }
        final nextTransitionVersion = candidate.transitionVersion + 1;
        final nextAttemptCount = candidate.attemptCount + 1;
        final updated =
            await (_database.update(table)..where(
                  (row) =>
                      row.attachmentId.equals(candidate.attachmentId) &
                      row.phase.equals(candidate.phase) &
                      row.transitionVersion.equals(
                        candidate.transitionVersion,
                      ) &
                      (row.leaseToken.isNull() |
                          row.leaseExpiresAt.isSmallerOrEqualValue(
                            timestamp.microsecondsSinceEpoch,
                          )),
                ))
                .write(
                  E2eeAttachmentUploadRowsCompanion(
                    leaseToken: Value(token),
                    leaseOwnerSessionId: Value(owner),
                    leaseExpiresAt: Value(expiry),
                    transitionVersion: Value(nextTransitionVersion),
                    attemptCount: Value(nextAttemptCount),
                    updatedAt: Value(timestamp),
                  ),
                );
        if (updated == 0) return null;
        if (updated != 1) throw StateError('附件上传 claim CAS 更新了多行');
        final claimed = await _rowByAttachmentId(candidate.attachmentId);
        return _leaseFromRow(
          claimed,
          leaseToken: token,
          leaseOwner: owner,
          leaseExpiresAt: expiry,
        );
      } finally {
        _clearAttachmentUploadRowBytes(candidate);
      }
    });
  }

  Future<E2eeAttachmentUploadLease> acceptCreated({
    required E2eeAttachmentUploadLease lease,
    required String uploadId,
    required DateTime now,
  }) async {
    if (lease.state.phase != E2eeAttachmentUploadPhase.createPending) {
      throw StateError('附件上传当前不等待创建响应');
    }
    final id = _requireCanonicalUuidV4(uploadId, 'uploadId');
    return _transitionLease(
      lease: lease,
      now: now,
      resetFailureState: true,
      changes: E2eeAttachmentUploadRowsCompanion(
        phase: Value(E2eeAttachmentUploadPhase.manifestPending.wireValue),
        uploadId: Value(id),
      ),
    );
  }

  Future<E2eeAttachmentUploadLease> attachManifest({
    required E2eeAttachmentUploadLease lease,
    required E2eeSealedAttachmentManifest sealedManifest,
    required DateTime now,
  }) async {
    final state = lease.state;
    if (state.phase != E2eeAttachmentUploadPhase.manifestPending ||
        state.uploadId == null) {
      throw StateError('附件上传当前不等待认证清单');
    }
    if (sealedManifest.attachmentId != state.attachmentId ||
        sealedManifest.uploadId != state.uploadId ||
        sealedManifest.chunkKeyEpoch != state.descriptor.chunkKeyEpoch ||
        sealedManifest.manifestKeyEpoch != state.manifestKeyEpoch ||
        sealedManifest.manifestRevision != state.manifestRevision) {
      throw const FormatException('附件认证清单与持久上传身份不一致');
    }
    return _transitionLease(
      lease: lease,
      now: now,
      resetFailureState: false,
      changes: E2eeAttachmentUploadRowsCompanion(
        phase: Value(E2eeAttachmentUploadPhase.uploading.wireValue),
        manifestCiphertext: Value(sealedManifest.ciphertext),
      ),
    );
  }

  Future<E2eeAttachmentUploadLease> stageChunk({
    required E2eeAttachmentUploadLease lease,
    required int chunkIndex,
    required String mutationId,
    required String ciphertextPath,
    required int ciphertextBytes,
    required Uint8List ciphertextSha256,
    required DateTime now,
  }) async {
    final state = lease.state;
    if (state.phase != E2eeAttachmentUploadPhase.uploading ||
        state.pendingChunk != null ||
        chunkIndex != state.nextChunkIndex) {
      throw StateError('附件上传当前不能暂存该分块');
    }
    final expectedBytes = state.descriptor.chunkCiphertextBytes[chunkIndex];
    if (ciphertextBytes != expectedBytes) {
      throw const FormatException('待上传附件分块密文长度不一致');
    }
    final mutation = _requireCanonicalUuidV4(mutationId, 'mutationId');
    final path = _requireAttachmentStorageText(
      ciphertextPath,
      'ciphertextPath',
      32768,
    );
    if (ciphertextSha256.length != 32) {
      throw const FormatException('待上传附件分块密文摘要长度无效');
    }
    final persistedCiphertextSha256 = Uint8List.fromList(ciphertextSha256);
    return _transitionLease(
      lease: lease,
      now: now,
      resetFailureState: false,
      changes: E2eeAttachmentUploadRowsCompanion(
        pendingChunkIndex: Value(chunkIndex),
        pendingChunkMutationId: Value(mutation),
        pendingChunkCiphertextPath: Value(path),
        pendingChunkCiphertextBytes: Value(ciphertextBytes),
        pendingChunkCiphertextSha256: Value(persistedCiphertextSha256),
      ),
    );
  }

  Future<E2eeAttachmentUploadLease> acknowledgeChunk({
    required E2eeAttachmentUploadLease lease,
    required DateTime now,
  }) async {
    final state = lease.state;
    final pending = state.pendingChunk;
    if (state.phase != E2eeAttachmentUploadPhase.uploading ||
        pending == null ||
        pending.index != state.nextChunkIndex) {
      throw StateError('附件上传当前没有可确认分块');
    }
    final nextIndex = state.nextChunkIndex + 1;
    final nextPhase = nextIndex == state.descriptor.chunkCiphertextBytes.length
        ? E2eeAttachmentUploadPhase.commitPending
        : E2eeAttachmentUploadPhase.uploading;
    return _transitionLease(
      lease: lease,
      now: now,
      resetFailureState: true,
      changes: E2eeAttachmentUploadRowsCompanion(
        phase: Value(nextPhase.wireValue),
        nextChunkIndex: Value(nextIndex),
        pendingChunkIndex: const Value(null),
        pendingChunkMutationId: const Value(null),
        pendingChunkCiphertextPath: const Value(null),
        pendingChunkCiphertextBytes: const Value(null),
        pendingChunkCiphertextSha256: const Value(null),
      ),
    );
  }

  Future<E2eeAttachmentUploadState> markCommitted({
    required E2eeAttachmentUploadLease lease,
    required DateTime now,
  }) {
    if (lease.state.phase != E2eeAttachmentUploadPhase.commitPending) {
      throw StateError('附件上传当前不能提交完成');
    }
    final timestamp = _requireStorageTime(now, 'now');
    _requireActiveAttachmentUploadLease(lease, timestamp);
    return _database.transaction(() async {
      if (lease.state.transitionVersion >= _attachmentUploadMaxPositiveInt63) {
        throw StateError('附件上传 transitionVersion 已耗尽');
      }
      final uploadId = lease.state.uploadId;
      if (uploadId == null) throw StateError('附件上传缺少远端 uploadId');
      final targetUpdated = switch (lease.state.target) {
        E2eeMessageAttachmentUploadTarget(:final revisionId, :final ordinal) =>
          await (_database.update(_database.messageAssetRows)..where(
                (row) =>
                    row.revisionId.equals(revisionId) &
                    row.ordinal.equals(ordinal) &
                    row.assetId.equals(lease.state.localAssetId) &
                    row.attachmentId.isNull() &
                    row.uploadId.isNull() &
                    row.chunkKeyEpoch.isNull() &
                    row.manifestKeyEpoch.isNull() &
                    row.manifestRevision.isNull(),
              ))
              .write(
                MessageAssetRowsCompanion(
                  attachmentId: Value(lease.state.attachmentId),
                  uploadId: Value(uploadId),
                  chunkKeyEpoch: Value(lease.state.descriptor.chunkKeyEpoch),
                  manifestKeyEpoch: Value(lease.state.manifestKeyEpoch),
                  manifestRevision: Value(lease.state.manifestRevision),
                ),
              ),
        E2eeConfigAssetUploadTarget(:final key) =>
          await (_database.update(_database.configAssetRows)..where(
                (row) =>
                    row.entityType.equals(key.entityKey.entityType) &
                    row.entityId.equals(key.entityKey.entityId) &
                    row.slot.equals(key.slot.wireValue) &
                    row.assetId.equals(lease.state.localAssetId) &
                    row.attachmentId.isNull() &
                    row.uploadId.isNull() &
                    row.chunkKeyEpoch.isNull() &
                    row.manifestKeyEpoch.isNull() &
                    row.manifestRevision.isNull(),
              ))
              .write(
                ConfigAssetRowsCompanion(
                  attachmentId: Value(lease.state.attachmentId),
                  uploadId: Value(uploadId),
                  chunkKeyEpoch: Value(lease.state.descriptor.chunkKeyEpoch),
                  manifestKeyEpoch: Value(lease.state.manifestKeyEpoch),
                  manifestRevision: Value(lease.state.manifestRevision),
                ),
              ),
      };
      if (targetUpdated != 1) throw StateError('附件上传目标引用 CAS 失败');
      final updated =
          await (_database.update(
            _database.e2eeAttachmentUploadRows,
          )..where((row) => _matchesAttachmentUploadLease(row, lease))).write(
            E2eeAttachmentUploadRowsCompanion(
              phase: Value(E2eeAttachmentUploadPhase.committed.wireValue),
              leaseToken: const Value(null),
              leaseOwnerSessionId: const Value(null),
              leaseExpiresAt: const Value(null),
              transitionVersion: Value(lease.state.transitionVersion + 1),
              consecutiveFailureCount: const Value(0),
              nextAttemptAt: Value(timestamp),
              lastFailureKind: const Value(null),
              terminalFailureKind: const Value(null),
              updatedAt: Value(timestamp),
            ),
          );
      if (updated != 1) throw StateError('附件上传完成 CAS 失败');
      return _stateFromRow(await _rowByAttachmentId(lease.state.attachmentId));
    });
  }

  Future<bool> release({
    required E2eeAttachmentUploadLease lease,
    required DateTime now,
  }) {
    final timestamp = _requireStorageTime(now, 'now');
    return _releaseLease(
      lease: lease,
      nextAttemptAt: timestamp,
      recordFailure: false,
      now: timestamp,
    );
  }

  Future<bool> releaseAfterFailure({
    required E2eeAttachmentUploadLease lease,
    required DateTime nextAttemptAt,
    required String failureKind,
    required DateTime now,
  }) {
    final timestamp = _requireStorageTime(now, 'now');
    final retryAt = _requireStorageTime(nextAttemptAt, 'nextAttemptAt');
    final failure = _requireErrorCode(failureKind, 'failureKind');
    if (retryAt.isBefore(timestamp)) {
      throw const FormatException('附件上传重试时间不得早于当前时间');
    }
    if (lease.state.consecutiveFailureCount >=
        _attachmentUploadMaxPositiveInt63) {
      throw StateError('附件上传 consecutiveFailureCount 已耗尽');
    }
    return _releaseLease(
      lease: lease,
      nextAttemptAt: retryAt,
      recordFailure: true,
      lastFailureKind: failure,
      consecutiveFailureCount: lease.state.consecutiveFailureCount + 1,
      now: timestamp,
    );
  }

  Future<E2eeAttachmentUploadState> markPermanentlyFailed({
    required E2eeAttachmentUploadLease lease,
    required String failureKind,
    required DateTime now,
  }) {
    final timestamp = _requireStorageTime(now, 'now');
    final failure = _requireErrorCode(failureKind, 'failureKind');
    _requireActiveAttachmentUploadLease(lease, timestamp);
    return _database.transaction(() async {
      if (lease.state.transitionVersion >= _attachmentUploadMaxPositiveInt63) {
        throw StateError('附件上传 transitionVersion 已耗尽');
      }
      if (lease.state.consecutiveFailureCount >=
          _attachmentUploadMaxPositiveInt63) {
        throw StateError('附件上传 consecutiveFailureCount 已耗尽');
      }
      final updated =
          await (_database.update(
            _database.e2eeAttachmentUploadRows,
          )..where((row) => _matchesAttachmentUploadLease(row, lease))).write(
            E2eeAttachmentUploadRowsCompanion(
              leaseToken: const Value(null),
              leaseOwnerSessionId: const Value(null),
              leaseExpiresAt: const Value(null),
              transitionVersion: Value(lease.state.transitionVersion + 1),
              consecutiveFailureCount: Value(
                lease.state.consecutiveFailureCount + 1,
              ),
              lastFailureKind: Value(failure),
              terminalFailureKind: Value(failure),
              updatedAt: Value(timestamp),
            ),
          );
      if (updated != 1) throw StateError('附件上传失败终态 CAS 失败');
      return _stateFromRow(await _rowByAttachmentId(lease.state.attachmentId));
    });
  }

  Future<bool> deleteFailedForRebuild({
    required String attachmentId,
    required int expectedTransitionVersion,
  }) async {
    final id = _requireCanonicalUuidV4(attachmentId, 'attachmentId');
    if (expectedTransitionVersion < 1 ||
        expectedTransitionVersion > _attachmentUploadMaxPositiveInt63) {
      throw const FormatException('expectedTransitionVersion 超出有效范围');
    }
    final deleted =
        await (_database.delete(_database.e2eeAttachmentUploadRows)..where(
              (row) =>
                  row.attachmentId.equals(id) &
                  row.transitionVersion.equals(expectedTransitionVersion) &
                  row.terminalFailureKind.isNotNull() &
                  row.leaseToken.isNull(),
            ))
            .go();
    if (deleted > 1) throw StateError('附件上传重建 CAS 删除了多行');
    return deleted == 1;
  }

  Future<E2eeAttachmentUploadLease> _transitionLease({
    required E2eeAttachmentUploadLease lease,
    required DateTime now,
    required bool resetFailureState,
    required E2eeAttachmentUploadRowsCompanion changes,
  }) {
    final timestamp = _requireStorageTime(now, 'now');
    _requireActiveAttachmentUploadLease(lease, timestamp);
    return _database.transaction(() async {
      if (lease.state.transitionVersion >= _attachmentUploadMaxPositiveInt63) {
        throw StateError('附件上传 transitionVersion 已耗尽');
      }
      final nextTransitionVersion = lease.state.transitionVersion + 1;
      final persistedChanges = changes.copyWith(
        transitionVersion: Value(nextTransitionVersion),
        consecutiveFailureCount: resetFailureState
            ? const Value(0)
            : const Value.absent(),
        nextAttemptAt: Value(timestamp),
        lastFailureKind: resetFailureState
            ? const Value(null)
            : const Value.absent(),
        updatedAt: Value(timestamp),
      );
      final updated =
          await (_database.update(_database.e2eeAttachmentUploadRows)
                ..where((row) => _matchesAttachmentUploadLease(row, lease)))
              .write(persistedChanges);
      if (updated != 1) throw StateError('附件上传阶段 CAS 失败');
      final next = await _rowByAttachmentId(lease.state.attachmentId);
      return _leaseFromRow(
        next,
        leaseToken: lease.leaseToken,
        leaseOwner: lease.leaseOwner,
        leaseExpiresAt: lease.leaseExpiresAt,
      );
    });
  }

  Future<bool> _releaseLease({
    required E2eeAttachmentUploadLease lease,
    required DateTime nextAttemptAt,
    required bool recordFailure,
    String? lastFailureKind,
    int? consecutiveFailureCount,
    required DateTime now,
  }) async {
    if (recordFailure &&
        (lastFailureKind == null || consecutiveFailureCount == null)) {
      throw StateError('附件上传失败释放缺少失败状态');
    }
    if (!now.isBefore(lease.leaseExpiresAt)) return false;
    if (lease.state.transitionVersion >= _attachmentUploadMaxPositiveInt63) {
      throw StateError('附件上传 transitionVersion 已耗尽');
    }
    final updated =
        await (_database.update(
          _database.e2eeAttachmentUploadRows,
        )..where((row) => _matchesAttachmentUploadLease(row, lease))).write(
          E2eeAttachmentUploadRowsCompanion(
            leaseToken: const Value(null),
            leaseOwnerSessionId: const Value(null),
            leaseExpiresAt: const Value(null),
            transitionVersion: Value(lease.state.transitionVersion + 1),
            consecutiveFailureCount: recordFailure
                ? Value(consecutiveFailureCount!)
                : const Value.absent(),
            nextAttemptAt: Value(nextAttemptAt),
            lastFailureKind: recordFailure
                ? Value(lastFailureKind)
                : const Value.absent(),
            updatedAt: Value(now),
          ),
        );
    if (updated > 1) throw StateError('附件上传 release CAS 更新了多行');
    return updated == 1;
  }

  Future<E2eeAttachmentUploadRow> _rowByAttachmentId(String attachmentId) {
    return (_database.select(
      _database.e2eeAttachmentUploadRows,
    )..where((row) => row.attachmentId.equals(attachmentId))).getSingle();
  }
}

typedef _AttachmentUploadTargetColumns = ({
  String? revisionId,
  int? ordinal,
  String? configEntityType,
  String? configEntityId,
  String? configSlot,
});

_AttachmentUploadTargetColumns _attachmentUploadTargetColumns(
  E2eeAttachmentUploadTarget target,
) => switch (target) {
  E2eeMessageAttachmentUploadTarget(:final revisionId, :final ordinal) => (
    revisionId: revisionId,
    ordinal: ordinal,
    configEntityType: null,
    configEntityId: null,
    configSlot: null,
  ),
  E2eeConfigAssetUploadTarget(:final key) => (
    revisionId: null,
    ordinal: null,
    configEntityType: key.entityKey.entityType,
    configEntityId: key.entityKey.entityId,
    configSlot: key.slot.wireValue,
  ),
};

E2eeAttachmentUploadTarget _attachmentUploadTargetFromRow(
  E2eeAttachmentUploadRow row,
) {
  final revisionId = row.targetRevisionId;
  final ordinal = row.targetOrdinal;
  final configEntityType = row.targetConfigEntityType;
  final configEntityId = row.targetConfigEntityId;
  final configSlot = row.targetConfigSlot;
  if (revisionId != null &&
      ordinal != null &&
      configEntityType == null &&
      configEntityId == null &&
      configSlot == null) {
    return E2eeMessageAttachmentUploadTarget(
      revisionId: revisionId,
      ordinal: ordinal,
    );
  }
  if (revisionId == null &&
      ordinal == null &&
      configEntityType != null &&
      configEntityId != null &&
      configSlot != null) {
    return E2eeConfigAssetUploadTarget(
      E2eeConfigAssetKey(
        entityKey: SyncEntityKey(
          entityType: configEntityType,
          entityId: configEntityId,
        ),
        slot: E2eeConfigAssetSlot.fromWireValue(configSlot),
      ),
    );
  }
  throw StateError('附件上传目标持久状态无效');
}

void _requirePendingTargetMatches({
  required String assetId,
  required String? attachmentId,
  required String? uploadId,
  required int? chunkKeyEpoch,
  required int? manifestKeyEpoch,
  required int? manifestRevision,
  required String kind,
  required String? displayName,
  required String? mediaType,
  required E2eeAttachmentUploadDraft draft,
  required String context,
}) {
  final descriptor = draft.descriptor;
  if (assetId != draft.localAssetId ||
      attachmentId != null ||
      uploadId != null ||
      chunkKeyEpoch != null ||
      manifestKeyEpoch != null ||
      manifestRevision != null ||
      kind != descriptor.kind.name ||
      displayName != descriptor.displayName ||
      mediaType != descriptor.mediaType) {
    throw StateError('附件上传目标$context与草稿不一致');
  }
}

bool _sameAttachmentUploadTarget(
  E2eeAttachmentUploadTarget left,
  E2eeAttachmentUploadTarget right,
) {
  if (left is E2eeMessageAttachmentUploadTarget &&
      right is E2eeMessageAttachmentUploadTarget) {
    return left.revisionId == right.revisionId && left.ordinal == right.ordinal;
  }
  if (left is E2eeConfigAssetUploadTarget &&
      right is E2eeConfigAssetUploadTarget) {
    return left.key == right.key;
  }
  return false;
}

void _requireActiveAttachmentUploadLease(
  E2eeAttachmentUploadLease lease,
  DateTime now,
) {
  if (!now.isBefore(lease.leaseExpiresAt)) {
    throw StateError('附件上传租约已过期');
  }
}

Expression<bool> _matchesAttachmentUploadLease(
  $E2eeAttachmentUploadRowsTable row,
  E2eeAttachmentUploadLease lease,
) {
  return row.attachmentId.equals(lease.state.attachmentId) &
      row.phase.equals(lease.state.phase.wireValue) &
      row.transitionVersion.equals(lease.state.transitionVersion) &
      row.leaseToken.equals(lease.leaseToken) &
      row.leaseOwnerSessionId.equals(lease.leaseOwner) &
      row.leaseExpiresAt.equalsValue(lease.leaseExpiresAt);
}

E2eeAttachmentUploadLease _leaseFromRow(
  E2eeAttachmentUploadRow row, {
  required String leaseToken,
  required String leaseOwner,
  required DateTime leaseExpiresAt,
}) {
  try {
    if (row.leaseToken != leaseToken ||
        row.leaseOwnerSessionId != leaseOwner ||
        row.leaseExpiresAt == null ||
        !row.leaseExpiresAt!.isAtSameMomentAs(leaseExpiresAt)) {
      throw StateError('附件上传租约持久状态不一致');
    }
    return E2eeAttachmentUploadLease._(
      state: _stateFromRow(row),
      leaseToken: leaseToken,
      leaseOwner: leaseOwner,
      leaseExpiresAt: leaseExpiresAt,
    );
  } catch (_) {
    _clearAttachmentUploadRowBytes(row);
    rethrow;
  }
}

E2eeAttachmentUploadState _stateFromRow(E2eeAttachmentUploadRow row) {
  try {
    final layout = KelivoAttachmentLayout(
      totalPlaintextBytes: row.totalPlaintextBytes,
    );
    if (row.chunkCount != layout.chunkCount ||
        row.totalCiphertextBytes != layout.totalCiphertextBytes) {
      throw StateError('附件上传持久布局不一致');
    }
    final chunkCiphertextBytes = List<int>.generate(
      layout.chunkCount,
      (index) =>
          layout.plaintextLengthForChunk(index) +
          KelivoAttachmentLimits.chunkEnvelopeOverheadBytes,
      growable: false,
    );
    final descriptor = E2eeAttachmentDescriptor(
      attachmentId: row.attachmentId,
      chunkKeyEpoch: row.chunkKeyEpoch,
      kind: switch (row.kind) {
        'image' => E2eeAttachmentKind.image,
        'file' => E2eeAttachmentKind.file,
        _ => throw StateError('附件上传持久类型不受支持'),
      },
      totalPlaintextBytes: row.totalPlaintextBytes,
      contentSha256: row.contentSha256,
      wrappedDataKey: row.wrappedDataKey,
      chunkCiphertextBytes: chunkCiphertextBytes,
      displayName: row.displayName,
      mediaType: row.mediaType,
    );
    final pendingChunk = row.pendingChunkIndex == null
        ? null
        : E2eeAttachmentPendingChunk._(
            index: row.pendingChunkIndex!,
            mutationId: _requireCanonicalUuidV4(
              row.pendingChunkMutationId!,
              'pendingChunkMutationId',
            ),
            ciphertextPath: _requireAttachmentStorageText(
              row.pendingChunkCiphertextPath!,
              'pendingChunkCiphertextPath',
              32768,
            ),
            ciphertextBytes: row.pendingChunkCiphertextBytes!,
            ciphertextSha256: row.pendingChunkCiphertextSha256!,
          );
    final uploadId = row.uploadId == null
        ? null
        : _requireCanonicalUuidV4(row.uploadId!, 'uploadId');
    return E2eeAttachmentUploadState._(
      descriptor: descriptor,
      localAssetId: _requireAttachmentStorageText(
        row.localAssetId,
        'localAssetId',
        1024,
      ),
      target: _attachmentUploadTargetFromRow(row),
      sourcePath: _requireAttachmentStorageText(
        row.sourcePath,
        'sourcePath',
        32768,
      ),
      phase: E2eeAttachmentUploadPhase.fromWireValue(row.phase),
      createMutationId: _requireCanonicalUuidV4(
        row.createMutationId,
        'createMutationId',
      ),
      uploadId: uploadId,
      manifestKeyEpoch: row.manifestKeyEpoch,
      manifestRevision: row.manifestRevision,
      manifestCiphertext: row.manifestCiphertext,
      commitMutationId: _requireCanonicalUuidV4(
        row.commitMutationId,
        'commitMutationId',
      ),
      nextChunkIndex: row.nextChunkIndex,
      pendingChunk: pendingChunk,
      transitionVersion: row.transitionVersion,
      attemptCount: row.attemptCount,
      consecutiveFailureCount: row.consecutiveFailureCount,
      nextAttemptAt: row.nextAttemptAt.toUtc(),
      lastFailureKind: row.lastFailureKind,
      terminalFailureKind: row.terminalFailureKind,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  } finally {
    _clearAttachmentUploadRowBytes(row);
  }
}

E2eeAttachmentUploadState _requireSameUploadSource(
  E2eeAttachmentUploadRow row,
  E2eeAttachmentUploadDraft draft,
) {
  final existing = _stateFromRow(row);
  final persisted = existing.descriptor;
  final requested = draft.descriptor;
  if (existing.localAssetId != draft.localAssetId ||
      !_sameAttachmentUploadTarget(existing.target, draft.target) ||
      existing.sourcePath != draft.sourcePath ||
      persisted.chunkKeyEpoch != requested.chunkKeyEpoch ||
      existing.manifestKeyEpoch != requested.chunkKeyEpoch ||
      existing.manifestRevision != 1 ||
      persisted.kind != requested.kind ||
      persisted.totalPlaintextBytes != requested.totalPlaintextBytes ||
      persisted.displayName != requested.displayName ||
      persisted.mediaType != requested.mediaType ||
      !_sameAttachmentUploadValues(
        persisted.contentSha256,
        requested.contentSha256,
      ) ||
      !_sameAttachmentUploadValues(
        persisted.chunkCiphertextBytes,
        requested.chunkCiphertextBytes,
      )) {
    throw StateError('附件上传自然键已绑定不同来源');
  }
  return existing;
}

bool _sameAttachmentUploadValues(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

int _requireAttachmentTargetOrdinal(int value) {
  if (value < 0 || value > 31) {
    throw const FormatException('附件目标 ordinal 必须位于 0 到 31');
  }
  return value;
}

void _clearAttachmentUploadRowBytes(E2eeAttachmentUploadRow row) {
  row.contentSha256.fillRange(0, row.contentSha256.length, 0);
  row.wrappedDataKey.fillRange(0, row.wrappedDataKey.length, 0);
  final manifestCiphertext = row.manifestCiphertext;
  manifestCiphertext?.fillRange(0, manifestCiphertext.length, 0);
  final pendingChunkCiphertextSha256 = row.pendingChunkCiphertextSha256;
  pendingChunkCiphertextSha256?.fillRange(
    0,
    pendingChunkCiphertextSha256.length,
    0,
  );
}

String _requireAttachmentStorageText(
  String value,
  String name,
  int maximumBytes,
) {
  final length = utf8.encode(value).length;
  if (length < 1 || length > maximumBytes || value.contains('\u0000')) {
    throw FormatException('$name UTF-8 长度或内容无效');
  }
  return value;
}
