part of 'chat_database_repository.dart';

const _attachmentDownloadActivePhases = <String>[
  'manifest-pending',
  'downloading',
  'verifying',
];
const _attachmentDownloadMaxManifestCiphertextBytes = 1024 * 1024;

enum E2eeAttachmentDownloadPhase {
  manifestPending('manifest-pending'),
  downloading('downloading'),
  verifying('verifying'),
  ready('ready');

  const E2eeAttachmentDownloadPhase(this.wireValue);

  final String wireValue;

  static E2eeAttachmentDownloadPhase fromWireValue(String value) {
    for (final phase in values) {
      if (phase.wireValue == value) return phase;
    }
    throw StateError('附件下载阶段不受支持');
  }
}

final class E2eeAttachmentDownloadReference {
  E2eeAttachmentDownloadReference({
    required String attachmentId,
    required String uploadId,
    required int keyEpoch,
    required this.kind,
  }) : attachmentId = _requireCanonicalUuidV4(attachmentId, 'attachmentId'),
       uploadId = _requireCanonicalUuidV4(uploadId, 'uploadId'),
       keyEpoch = _requireAttachmentKeyEpoch(keyEpoch);

  final String attachmentId;
  final String uploadId;
  final int keyEpoch;
  final E2eeAttachmentKind kind;
}

final class E2eeAttachmentDownloadState {
  E2eeAttachmentDownloadState._({
    required this.reference,
    required this.phase,
    required Uint8List? manifestCiphertext,
    required this.descriptor,
    required this.localAssetId,
    required this.stagingPath,
    required this.finalPath,
    required this.nextChunkIndex,
    required this.confirmedPlaintextBytes,
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

  final E2eeAttachmentDownloadReference reference;
  final E2eeAttachmentDownloadPhase phase;
  final Uint8List? manifestCiphertext;
  final E2eeAttachmentDescriptor? descriptor;
  final String? localAssetId;
  final String? stagingPath;
  final String? finalPath;
  final int nextChunkIndex;
  final int confirmedPlaintextBytes;
  final int transitionVersion;
  final int attemptCount;
  final int consecutiveFailureCount;
  final DateTime nextAttemptAt;
  final String? lastFailureKind;
  final String? terminalFailureKind;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get attachmentId => reference.attachmentId;
  String get uploadId => reference.uploadId;
  int get keyEpoch => reference.keyEpoch;
  E2eeAttachmentKind get kind => reference.kind;
}

final class E2eeAttachmentDownloadLease {
  E2eeAttachmentDownloadLease._({
    required this.state,
    required this.leaseToken,
    required this.leaseOwner,
    required this.leaseExpiresAt,
  });

  final E2eeAttachmentDownloadState state;
  final String leaseToken;
  final String leaseOwner;
  final DateTime leaseExpiresAt;
}

final class E2eeAttachmentDownloadCommands {
  E2eeAttachmentDownloadCommands._(ChatDatabaseRepository repository)
    : _database = repository._db;

  final AppDatabase _database;

  Future<E2eeAttachmentDownloadState> ensure({
    required E2eeAttachmentDownloadReference reference,
    required DateTime now,
  }) {
    final timestamp = _requireStorageTime(now, 'now');
    return _database.transaction(() async {
      final table = _database.e2eeAttachmentDownloadRows;
      final existing =
          await (_database.select(table)..where(
                (row) => row.attachmentId.equals(reference.attachmentId),
              ))
              .getSingleOrNull();
      if (existing != null) {
        final state = _attachmentDownloadStateFromRow(existing);
        _requireMatchingDownloadReference(reference, state.reference);
        return state;
      }
      final uploadOwner =
          await (_database.selectOnly(table)
                ..addColumns([table.attachmentId])
                ..where(table.uploadId.equals(reference.uploadId)))
              .getSingleOrNull();
      if (uploadOwner != null) {
        throw StateError('attachment_download_identity_conflict');
      }
      await _database
          .into(table)
          .insert(
            E2eeAttachmentDownloadRowsCompanion.insert(
              attachmentId: reference.attachmentId,
              uploadId: reference.uploadId,
              keyEpoch: reference.keyEpoch,
              kind: reference.kind.name,
              phase: E2eeAttachmentDownloadPhase.manifestPending.wireValue,
              nextChunkIndex: 0,
              confirmedPlaintextBytes: 0,
              transitionVersion: 1,
              attemptCount: 0,
              consecutiveFailureCount: 0,
              nextAttemptAt: timestamp,
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          );
      return _attachmentDownloadStateFromRow(
        await _attachmentDownloadRow(reference.attachmentId),
      );
    });
  }

  Future<E2eeAttachmentDownloadState?> read(
    E2eeAttachmentDownloadReference reference,
  ) async {
    final row =
        await (_database.select(_database.e2eeAttachmentDownloadRows)..where(
              (table) => table.attachmentId.equals(reference.attachmentId),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    final state = _attachmentDownloadStateFromRow(row);
    _requireMatchingDownloadReference(reference, state.reference);
    return state;
  }

  Future<E2eeAttachmentDownloadState?> readReady(
    E2eeAttachmentDownloadReference reference,
  ) async {
    final state = await read(reference);
    return state?.phase == E2eeAttachmentDownloadPhase.ready ? state : null;
  }

  Future<E2eeAttachmentDownloadLease?> claimDue({
    E2eeAttachmentDownloadReference? reference,
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
      throw const FormatException('附件下载租约必须晚于当前时间');
    }

    return _database.transaction(() async {
      final table = _database.e2eeAttachmentDownloadRows;
      final query = _database.select(table)
        ..where((row) {
          var predicate =
              row.phase.isIn(_attachmentDownloadActivePhases) &
              row.terminalFailureKind.isNull() &
              row.nextAttemptAt.isSmallerOrEqualValue(
                timestamp.microsecondsSinceEpoch,
              ) &
              (row.leaseToken.isNull() |
                  row.leaseExpiresAt.isSmallerOrEqualValue(
                    timestamp.microsecondsSinceEpoch,
                  ));
          if (reference != null) {
            predicate =
                predicate &
                row.attachmentId.equals(reference.attachmentId) &
                row.uploadId.equals(reference.uploadId) &
                row.keyEpoch.equals(reference.keyEpoch) &
                row.kind.equals(reference.kind.name);
          }
          return predicate;
        })
        ..orderBy(<OrderClauseGenerator<$E2eeAttachmentDownloadRowsTable>>[
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
          throw StateError('附件下载持久计数器已耗尽');
        }
        final nextTransitionVersion = candidate.transitionVersion + 1;
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
                  E2eeAttachmentDownloadRowsCompanion(
                    leaseToken: Value(token),
                    leaseOwnerSessionId: Value(owner),
                    leaseExpiresAt: Value(expiry),
                    transitionVersion: Value(nextTransitionVersion),
                    attemptCount: Value(candidate.attemptCount + 1),
                    updatedAt: Value(timestamp),
                  ),
                );
        if (updated == 0) return null;
        if (updated != 1) throw StateError('附件下载 claim CAS 更新了多行');
        final claimed = await _attachmentDownloadRow(candidate.attachmentId);
        return _attachmentDownloadLeaseFromRow(
          claimed,
          leaseToken: token,
          leaseOwner: owner,
          leaseExpiresAt: expiry,
        );
      } finally {
        _clearAttachmentDownloadRowBytes(candidate);
      }
    });
  }

  Future<E2eeAttachmentDownloadLease> attachManifest({
    required E2eeAttachmentDownloadLease lease,
    required E2eeAttachmentManifest manifest,
    required Uint8List manifestCiphertext,
    required String stagingPath,
    required String finalPath,
    required DateTime now,
  }) async {
    final state = lease.state;
    if (state.phase != E2eeAttachmentDownloadPhase.manifestPending) {
      throw StateError('附件下载当前不等待认证清单');
    }
    _requireMatchingDownloadManifest(state.reference, manifest);
    if (manifestCiphertext.isEmpty ||
        manifestCiphertext.length >
            _attachmentDownloadMaxManifestCiphertextBytes) {
      throw const FormatException('附件下载清单密文长度无效');
    }
    final persistedManifestCiphertext = Uint8List.fromList(manifestCiphertext);
    final staging = _requireAttachmentStorageText(
      stagingPath,
      'stagingPath',
      32768,
    );
    final materialized = _requireAttachmentStorageText(
      finalPath,
      'finalPath',
      32768,
    );
    if (staging == materialized) {
      throw const FormatException('附件下载暂存路径不得等于最终路径');
    }
    final localAssetId =
        'asset_${_attachmentDigestHex(manifest.contentSha256)}';
    return _transitionDownloadLease(
      lease: lease,
      now: now,
      resetFailureState: true,
      cancelAssetGcFor: localAssetId,
      changes: E2eeAttachmentDownloadRowsCompanion(
        phase: Value(E2eeAttachmentDownloadPhase.downloading.wireValue),
        manifestCiphertext: Value(persistedManifestCiphertext),
        contentSha256: Value(manifest.contentSha256),
        wrappedDataKey: Value(manifest.wrappedDataKey),
        totalPlaintextBytes: Value(manifest.totalPlaintextBytes),
        chunkCount: Value(manifest.chunkCiphertextBytes.length),
        totalCiphertextBytes: Value(manifest.totalCiphertextBytes),
        displayName: Value(manifest.displayName),
        mediaType: Value(manifest.mediaType),
        localAssetId: Value(localAssetId),
        stagingPath: Value(staging),
        finalPath: Value(materialized),
      ),
    );
  }

  Future<E2eeAttachmentDownloadLease> acknowledgeChunk({
    required E2eeAttachmentDownloadLease lease,
    required int chunkIndex,
    required int confirmedPlaintextBytes,
    required DateTime now,
  }) {
    final state = lease.state;
    final descriptor = state.descriptor;
    if (state.phase != E2eeAttachmentDownloadPhase.downloading ||
        descriptor == null ||
        chunkIndex != state.nextChunkIndex) {
      throw StateError('附件下载当前不能确认该分块');
    }
    final nextChunkIndex = chunkIndex + 1;
    final expectedConfirmed =
        (nextChunkIndex * KelivoAttachmentLimits.chunkPlaintextBytes).clamp(
          0,
          descriptor.totalPlaintextBytes,
        );
    if (confirmedPlaintextBytes != expectedConfirmed) {
      throw const FormatException('附件下载已确认明文字节数不一致');
    }
    final phase = nextChunkIndex == descriptor.chunkCiphertextBytes.length
        ? E2eeAttachmentDownloadPhase.verifying
        : E2eeAttachmentDownloadPhase.downloading;
    return _transitionDownloadLease(
      lease: lease,
      now: now,
      resetFailureState: true,
      changes: E2eeAttachmentDownloadRowsCompanion(
        phase: Value(phase.wireValue),
        nextChunkIndex: Value(nextChunkIndex),
        confirmedPlaintextBytes: Value(confirmedPlaintextBytes),
      ),
    );
  }

  Future<E2eeAttachmentDownloadState> markReady({
    required E2eeAttachmentDownloadLease lease,
    required MessageAssetRegistration asset,
    required DateTime now,
  }) async {
    final state = lease.state;
    final descriptor = state.descriptor;
    final expectedAssetId = state.localAssetId;
    final expectedPath = state.finalPath;
    if (state.phase != E2eeAttachmentDownloadPhase.verifying ||
        descriptor == null ||
        expectedAssetId == null ||
        expectedPath == null) {
      throw StateError('附件下载当前不能发布完成');
    }
    final expectedHash = _attachmentDigestHex(descriptor.contentSha256);
    if (asset.assetId != expectedAssetId ||
        asset.contentHash != expectedHash ||
        asset.path != expectedPath ||
        asset.byteSize != descriptor.totalPlaintextBytes ||
        asset.kind != state.kind.name ||
        asset.displayName != descriptor.displayName ||
        asset.mediaType != descriptor.mediaType ||
        asset.attachmentId != state.attachmentId ||
        asset.uploadId != state.uploadId ||
        asset.keyEpoch != state.keyEpoch) {
      throw const FormatException('附件下载资产注册与认证清单不一致');
    }
    final timestamp = _requireStorageTime(now, 'now');
    _requireActiveAttachmentDownloadLease(lease, timestamp);
    return _database.transaction(() async {
      if (lease.state.transitionVersion >= _attachmentUploadMaxPositiveInt63) {
        throw StateError('附件下载 transitionVersion 已耗尽');
      }
      await _database.customStatement(
        '''
        INSERT INTO asset_rows(
          id, content_hash, path, byte_size, width, height, thumbnail_path,
          created_at, last_referenced_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          content_hash = excluded.content_hash,
          path = excluded.path,
          byte_size = excluded.byte_size,
          width = excluded.width,
          height = excluded.height,
          thumbnail_path = excluded.thumbnail_path,
          last_referenced_at = MAX(
            asset_rows.last_referenced_at,
            excluded.last_referenced_at
          );
      ''',
        [
          asset.assetId,
          asset.contentHash,
          asset.path,
          asset.byteSize,
          asset.width,
          asset.height,
          asset.thumbnailPath,
          timestamp.microsecondsSinceEpoch,
          timestamp.microsecondsSinceEpoch,
        ],
      );
      await _database.customStatement(
        'DELETE FROM asset_gc_rows WHERE asset_id = ?;',
        [asset.assetId],
      );
      final updated =
          await (_database.update(
            _database.e2eeAttachmentDownloadRows,
          )..where((row) => _matchesAttachmentDownloadLease(row, lease))).write(
            E2eeAttachmentDownloadRowsCompanion(
              phase: Value(E2eeAttachmentDownloadPhase.ready.wireValue),
              stagingPath: const Value(null),
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
      if (updated != 1) throw StateError('附件下载完成 CAS 失败');
      return _attachmentDownloadStateFromRow(
        await _attachmentDownloadRow(lease.state.attachmentId),
      );
    });
  }

  Future<E2eeAttachmentDownloadLease> restartStaging({
    required E2eeAttachmentDownloadLease lease,
    required String stagingPath,
    required DateTime now,
  }) {
    final state = lease.state;
    if ((state.phase != E2eeAttachmentDownloadPhase.downloading &&
            state.phase != E2eeAttachmentDownloadPhase.verifying) ||
        state.descriptor == null ||
        state.finalPath == null) {
      throw StateError('附件下载当前不能重建暂存文件');
    }
    final staging = _requireAttachmentStorageText(
      stagingPath,
      'stagingPath',
      32768,
    );
    if (staging == state.finalPath) {
      throw const FormatException('附件下载暂存路径不得等于最终路径');
    }
    return _transitionDownloadLease(
      lease: lease,
      now: now,
      resetFailureState: false,
      changes: E2eeAttachmentDownloadRowsCompanion(
        phase: Value(E2eeAttachmentDownloadPhase.downloading.wireValue),
        stagingPath: Value(staging),
        nextChunkIndex: const Value(0),
        confirmedPlaintextBytes: const Value(0),
      ),
    );
  }

  Future<bool> release({
    required E2eeAttachmentDownloadLease lease,
    required DateTime now,
  }) {
    final timestamp = _requireStorageTime(now, 'now');
    return _releaseDownloadLease(
      lease: lease,
      nextAttemptAt: timestamp,
      recordFailure: false,
      now: timestamp,
    );
  }

  Future<bool> releaseAfterFailure({
    required E2eeAttachmentDownloadLease lease,
    required DateTime nextAttemptAt,
    required String failureKind,
    required DateTime now,
  }) {
    final timestamp = _requireStorageTime(now, 'now');
    final retryAt = _requireStorageTime(nextAttemptAt, 'nextAttemptAt');
    final failure = _requireErrorCode(failureKind, 'failureKind');
    if (retryAt.isBefore(timestamp)) {
      throw const FormatException('附件下载重试时间不得早于当前时间');
    }
    if (lease.state.consecutiveFailureCount >=
        _attachmentUploadMaxPositiveInt63) {
      throw StateError('附件下载 consecutiveFailureCount 已耗尽');
    }
    return _releaseDownloadLease(
      lease: lease,
      nextAttemptAt: retryAt,
      recordFailure: true,
      lastFailureKind: failure,
      consecutiveFailureCount: lease.state.consecutiveFailureCount + 1,
      now: timestamp,
    );
  }

  Future<E2eeAttachmentDownloadState> markPermanentlyFailed({
    required E2eeAttachmentDownloadLease lease,
    required String failureKind,
    required DateTime now,
  }) {
    final timestamp = _requireStorageTime(now, 'now');
    final failure = _requireErrorCode(failureKind, 'failureKind');
    _requireActiveAttachmentDownloadLease(lease, timestamp);
    return _database.transaction(() async {
      if (lease.state.transitionVersion >= _attachmentUploadMaxPositiveInt63) {
        throw StateError('附件下载 transitionVersion 已耗尽');
      }
      if (lease.state.consecutiveFailureCount >=
          _attachmentUploadMaxPositiveInt63) {
        throw StateError('附件下载 consecutiveFailureCount 已耗尽');
      }
      final updated =
          await (_database.update(
            _database.e2eeAttachmentDownloadRows,
          )..where((row) => _matchesAttachmentDownloadLease(row, lease))).write(
            E2eeAttachmentDownloadRowsCompanion(
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
      if (updated != 1) throw StateError('附件下载失败终态 CAS 失败');
      return _attachmentDownloadStateFromRow(
        await _attachmentDownloadRow(lease.state.attachmentId),
      );
    });
  }

  Future<bool> deleteFailedForRebuild({
    required E2eeAttachmentDownloadReference reference,
    required int expectedTransitionVersion,
  }) async {
    if (expectedTransitionVersion < 1 ||
        expectedTransitionVersion > _attachmentUploadMaxPositiveInt63) {
      throw const FormatException('expectedTransitionVersion 超出有效范围');
    }
    final table = _database.e2eeAttachmentDownloadRows;
    final deleted =
        await (_database.delete(table)..where(
              (row) =>
                  row.attachmentId.equals(reference.attachmentId) &
                  row.uploadId.equals(reference.uploadId) &
                  row.keyEpoch.equals(reference.keyEpoch) &
                  row.kind.equals(reference.kind.name) &
                  row.transitionVersion.equals(expectedTransitionVersion) &
                  row.terminalFailureKind.isNotNull() &
                  row.leaseToken.isNull(),
            ))
            .go();
    if (deleted > 1) throw StateError('附件下载重建 CAS 删除了多行');
    return deleted == 1;
  }

  Future<int> invalidateReadyByLocalAssetId(String localAssetId) {
    final id = _requireAttachmentStorageText(
      localAssetId,
      'localAssetId',
      1024,
    );
    final table = _database.e2eeAttachmentDownloadRows;
    return (_database.delete(table)..where(
          (row) =>
              row.localAssetId.equals(id) &
              row.phase.equals(E2eeAttachmentDownloadPhase.ready.wireValue) &
              row.leaseToken.isNull(),
        ))
        .go();
  }

  Future<E2eeAttachmentDownloadLease> _transitionDownloadLease({
    required E2eeAttachmentDownloadLease lease,
    required DateTime now,
    required bool resetFailureState,
    String? cancelAssetGcFor,
    required E2eeAttachmentDownloadRowsCompanion changes,
  }) {
    final timestamp = _requireStorageTime(now, 'now');
    _requireActiveAttachmentDownloadLease(lease, timestamp);
    return _database.transaction(() async {
      if (lease.state.transitionVersion >= _attachmentUploadMaxPositiveInt63) {
        throw StateError('附件下载 transitionVersion 已耗尽');
      }
      final persistedChanges = changes.copyWith(
        transitionVersion: Value(lease.state.transitionVersion + 1),
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
          await (_database.update(_database.e2eeAttachmentDownloadRows)
                ..where((row) => _matchesAttachmentDownloadLease(row, lease)))
              .write(persistedChanges);
      if (updated != 1) throw StateError('附件下载阶段 CAS 失败');
      if (cancelAssetGcFor != null) {
        await _database.customStatement(
          'DELETE FROM asset_gc_rows WHERE asset_id = ?;',
          [cancelAssetGcFor],
        );
      }
      return _attachmentDownloadLeaseFromRow(
        await _attachmentDownloadRow(lease.state.attachmentId),
        leaseToken: lease.leaseToken,
        leaseOwner: lease.leaseOwner,
        leaseExpiresAt: lease.leaseExpiresAt,
      );
    });
  }

  Future<bool> _releaseDownloadLease({
    required E2eeAttachmentDownloadLease lease,
    required DateTime nextAttemptAt,
    required bool recordFailure,
    String? lastFailureKind,
    int? consecutiveFailureCount,
    required DateTime now,
  }) async {
    if (recordFailure &&
        (lastFailureKind == null || consecutiveFailureCount == null)) {
      throw StateError('附件下载失败释放缺少失败状态');
    }
    if (!now.isBefore(lease.leaseExpiresAt)) return false;
    if (lease.state.transitionVersion >= _attachmentUploadMaxPositiveInt63) {
      throw StateError('附件下载 transitionVersion 已耗尽');
    }
    final updated =
        await (_database.update(
          _database.e2eeAttachmentDownloadRows,
        )..where((row) => _matchesAttachmentDownloadLease(row, lease))).write(
          E2eeAttachmentDownloadRowsCompanion(
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
    if (updated > 1) throw StateError('附件下载 release CAS 更新了多行');
    return updated == 1;
  }

  Future<E2eeAttachmentDownloadRow> _attachmentDownloadRow(
    String attachmentId,
  ) {
    return (_database.select(
      _database.e2eeAttachmentDownloadRows,
    )..where((row) => row.attachmentId.equals(attachmentId))).getSingle();
  }
}

void _requireMatchingDownloadManifest(
  E2eeAttachmentDownloadReference reference,
  E2eeAttachmentManifest manifest,
) {
  if (manifest.attachmentId != reference.attachmentId ||
      manifest.uploadId != reference.uploadId ||
      manifest.keyEpoch != reference.keyEpoch ||
      manifest.kind != reference.kind) {
    throw const FormatException('附件下载清单与消息引用身份不一致');
  }
}

void _requireMatchingDownloadReference(
  E2eeAttachmentDownloadReference expected,
  E2eeAttachmentDownloadReference actual,
) {
  if (actual.attachmentId != expected.attachmentId ||
      actual.uploadId != expected.uploadId ||
      actual.keyEpoch != expected.keyEpoch ||
      actual.kind != expected.kind) {
    throw StateError('attachment_download_identity_conflict');
  }
}

void _requireActiveAttachmentDownloadLease(
  E2eeAttachmentDownloadLease lease,
  DateTime now,
) {
  if (!now.isBefore(lease.leaseExpiresAt)) {
    throw StateError('附件下载租约已过期');
  }
}

Expression<bool> _matchesAttachmentDownloadLease(
  $E2eeAttachmentDownloadRowsTable row,
  E2eeAttachmentDownloadLease lease,
) {
  return row.attachmentId.equals(lease.state.attachmentId) &
      row.phase.equals(lease.state.phase.wireValue) &
      row.transitionVersion.equals(lease.state.transitionVersion) &
      row.leaseToken.equals(lease.leaseToken) &
      row.leaseOwnerSessionId.equals(lease.leaseOwner) &
      row.leaseExpiresAt.equalsValue(lease.leaseExpiresAt);
}

E2eeAttachmentDownloadLease _attachmentDownloadLeaseFromRow(
  E2eeAttachmentDownloadRow row, {
  required String leaseToken,
  required String leaseOwner,
  required DateTime leaseExpiresAt,
}) {
  try {
    if (row.leaseToken != leaseToken ||
        row.leaseOwnerSessionId != leaseOwner ||
        row.leaseExpiresAt == null ||
        !row.leaseExpiresAt!.isAtSameMomentAs(leaseExpiresAt)) {
      throw StateError('附件下载租约持久状态不一致');
    }
    return E2eeAttachmentDownloadLease._(
      state: _attachmentDownloadStateFromRow(row),
      leaseToken: leaseToken,
      leaseOwner: leaseOwner,
      leaseExpiresAt: leaseExpiresAt,
    );
  } catch (_) {
    _clearAttachmentDownloadRowBytes(row);
    rethrow;
  }
}

E2eeAttachmentDownloadState _attachmentDownloadStateFromRow(
  E2eeAttachmentDownloadRow row,
) {
  try {
    final reference = E2eeAttachmentDownloadReference(
      attachmentId: row.attachmentId,
      uploadId: row.uploadId,
      keyEpoch: row.keyEpoch,
      kind: switch (row.kind) {
        'image' => E2eeAttachmentKind.image,
        'file' => E2eeAttachmentKind.file,
        _ => throw StateError('附件下载持久类型不受支持'),
      },
    );
    final hasDescriptor = row.contentSha256 != null;
    final descriptor = hasDescriptor
        ? _attachmentDownloadDescriptorFromRow(row, reference)
        : null;
    return E2eeAttachmentDownloadState._(
      reference: reference,
      phase: E2eeAttachmentDownloadPhase.fromWireValue(row.phase),
      manifestCiphertext: row.manifestCiphertext,
      descriptor: descriptor,
      localAssetId: row.localAssetId,
      stagingPath: row.stagingPath,
      finalPath: row.finalPath,
      nextChunkIndex: row.nextChunkIndex,
      confirmedPlaintextBytes: row.confirmedPlaintextBytes,
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
    _clearAttachmentDownloadRowBytes(row);
  }
}

E2eeAttachmentDescriptor _attachmentDownloadDescriptorFromRow(
  E2eeAttachmentDownloadRow row,
  E2eeAttachmentDownloadReference reference,
) {
  final totalPlaintextBytes = row.totalPlaintextBytes;
  final contentSha256 = row.contentSha256;
  final wrappedDataKey = row.wrappedDataKey;
  final chunkCount = row.chunkCount;
  final totalCiphertextBytes = row.totalCiphertextBytes;
  if (totalPlaintextBytes == null ||
      contentSha256 == null ||
      wrappedDataKey == null ||
      chunkCount == null ||
      totalCiphertextBytes == null) {
    throw StateError('附件下载持久清单字段不完整');
  }
  final layout = KelivoAttachmentLayout(
    totalPlaintextBytes: totalPlaintextBytes,
  );
  if (layout.chunkCount != chunkCount ||
      layout.totalCiphertextBytes != totalCiphertextBytes) {
    throw StateError('附件下载持久布局不一致');
  }
  return E2eeAttachmentDescriptor(
    attachmentId: reference.attachmentId,
    keyEpoch: reference.keyEpoch,
    kind: reference.kind,
    totalPlaintextBytes: totalPlaintextBytes,
    contentSha256: contentSha256,
    wrappedDataKey: wrappedDataKey,
    chunkCiphertextBytes: List<int>.generate(
      layout.chunkCount,
      (index) =>
          layout.plaintextLengthForChunk(index) +
          KelivoAttachmentLimits.chunkEnvelopeOverheadBytes,
      growable: false,
    ),
    displayName: row.displayName,
    mediaType: row.mediaType,
  );
}

void _clearAttachmentDownloadRowBytes(E2eeAttachmentDownloadRow row) {
  row.manifestCiphertext?.fillRange(0, row.manifestCiphertext!.length, 0);
  row.contentSha256?.fillRange(0, row.contentSha256!.length, 0);
  row.wrappedDataKey?.fillRange(0, row.wrappedDataKey!.length, 0);
}

int _requireAttachmentKeyEpoch(int value) {
  if (value < 1 || value > 0xffffffff) {
    throw const FormatException('keyEpoch 必须位于正 uint32 范围');
  }
  return value;
}

String _attachmentDigestHex(Uint8List digest) {
  if (digest.length != 32) {
    throw const FormatException('附件内容摘要长度无效');
  }
  return digest.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
