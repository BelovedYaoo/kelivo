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
  ready('ready'),
  dormant('dormant');

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
    required int chunkKeyEpoch,
    required int manifestKeyEpoch,
    required int manifestRevision,
    required this.kind,
  }) : attachmentId = _requireCanonicalUuidV4(attachmentId, 'attachmentId'),
       uploadId = _requireCanonicalUuidV4(uploadId, 'uploadId'),
       chunkKeyEpoch = _requireAttachmentKeyEpoch(
         chunkKeyEpoch,
         'chunkKeyEpoch',
       ),
       manifestKeyEpoch = _requireAttachmentKeyEpoch(
         manifestKeyEpoch,
         'manifestKeyEpoch',
       ),
       manifestRevision = _requireAttachmentKeyEpoch(
         manifestRevision,
         'manifestRevision',
       ) {
    if (this.manifestKeyEpoch - this.chunkKeyEpoch !=
        this.manifestRevision - 1) {
      throw const FormatException('附件下载代次与修订关系无效');
    }
  }

  final String attachmentId;
  final String uploadId;
  final int chunkKeyEpoch;
  final int manifestKeyEpoch;
  final int manifestRevision;
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
    required this.cleanupStagingPath,
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
  final String? cleanupStagingPath;
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
  int get chunkKeyEpoch => reference.chunkKeyEpoch;
  int get manifestKeyEpoch => reference.manifestKeyEpoch;
  int get manifestRevision => reference.manifestRevision;
  E2eeAttachmentKind get kind => reference.kind;

  E2eeAttachmentManifest? get manifest {
    final value = descriptor;
    return value == null
        ? null
        : E2eeAttachmentManifest.fromDescriptor(
            descriptor: value,
            uploadId: uploadId,
            manifestKeyEpoch: manifestKeyEpoch,
            manifestRevision: manifestRevision,
          );
  }
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
      final owners =
          await (_database.select(table)..where(
                (row) =>
                    row.attachmentId.equals(reference.attachmentId) |
                    row.uploadId.equals(reference.uploadId),
              ))
              .get();
      if (owners.length > 1) {
        for (final owner in owners) {
          _clearAttachmentDownloadRowBytes(owner);
        }
        throw StateError('attachment_download_identity_conflict');
      }
      if (owners case [final existing]) {
        try {
          final existingReference = _attachmentDownloadReferenceFromRow(
            existing,
          );
          if (!_sameStableDownloadReference(existingReference, reference)) {
            throw StateError('attachment_download_identity_conflict');
          }
          if (_sameDownloadReference(existingReference, reference)) {
            if (existing.phase !=
                E2eeAttachmentDownloadPhase.dormant.wireValue) {
              return _attachmentDownloadStateFromRow(existing);
            }
            if (existing.transitionVersion >=
                _attachmentUploadMaxPositiveInt63) {
              throw StateError('附件下载 transitionVersion 已耗尽');
            }
            final reactivated =
                await (_database.update(table)..where(
                      (row) =>
                          _matchesAttachmentDownloadReference(
                            row,
                            existingReference,
                          ) &
                          row.phase.equals(
                            E2eeAttachmentDownloadPhase.dormant.wireValue,
                          ) &
                          row.transitionVersion.equals(
                            existing.transitionVersion,
                          ),
                    ))
                    .write(
                      E2eeAttachmentDownloadRowsCompanion(
                        phase: Value(
                          E2eeAttachmentDownloadPhase.manifestPending.wireValue,
                        ),
                        transitionVersion: Value(
                          existing.transitionVersion + 1,
                        ),
                        consecutiveFailureCount: const Value(0),
                        nextAttemptAt: Value(timestamp),
                        lastFailureKind: const Value(null),
                        terminalFailureKind: const Value(null),
                        updatedAt: Value(timestamp),
                      ),
                    );
            if (reactivated != 1) {
              throw StateError('附件下载休眠重激活 CAS 失败');
            }
            return _attachmentDownloadStateFromRow(
              await _attachmentDownloadRow(reference),
            );
          }
          _requireForwardManifestTransition(existingReference, reference);
          if (existing.transitionVersion >= _attachmentUploadMaxPositiveInt63) {
            throw StateError('附件下载 transitionVersion 已耗尽');
          }
          final retainReadyCandidate =
              (existing.phase == E2eeAttachmentDownloadPhase.ready.wireValue ||
                  existing.phase ==
                      E2eeAttachmentDownloadPhase.manifestPending.wireValue) &&
              existing.localAssetId != null &&
              existing.finalPath != null;
          final updated =
              await (_database.update(table)..where(
                    (row) =>
                        _matchesAttachmentDownloadReference(
                          row,
                          existingReference,
                        ) &
                        row.phase.equals(existing.phase) &
                        row.transitionVersion.equals(
                          existing.transitionVersion,
                        ),
                  ))
                  .write(
                    E2eeAttachmentDownloadRowsCompanion(
                      manifestKeyEpoch: Value(reference.manifestKeyEpoch),
                      manifestRevision: Value(reference.manifestRevision),
                      phase: Value(
                        E2eeAttachmentDownloadPhase.manifestPending.wireValue,
                      ),
                      manifestCiphertext: const Value(null),
                      contentSha256: const Value(null),
                      wrappedDataKey: const Value(null),
                      totalPlaintextBytes: const Value(null),
                      chunkCount: const Value(null),
                      totalCiphertextBytes: const Value(null),
                      displayName: const Value(null),
                      mediaType: const Value(null),
                      localAssetId: Value(
                        retainReadyCandidate ? existing.localAssetId : null,
                      ),
                      stagingPath: const Value(null),
                      cleanupStagingPath: Value(
                        existing.stagingPath ?? existing.cleanupStagingPath,
                      ),
                      finalPath: Value(
                        retainReadyCandidate ? existing.finalPath : null,
                      ),
                      nextChunkIndex: const Value(0),
                      confirmedPlaintextBytes: const Value(0),
                      leaseToken: const Value(null),
                      leaseOwnerSessionId: const Value(null),
                      leaseExpiresAt: const Value(null),
                      transitionVersion: Value(existing.transitionVersion + 1),
                      consecutiveFailureCount: const Value(0),
                      nextAttemptAt: Value(timestamp),
                      lastFailureKind: const Value(null),
                      terminalFailureKind: const Value(null),
                      updatedAt: Value(timestamp),
                    ),
                  );
          if (updated != 1) {
            throw StateError('附件下载清单换代 CAS 失败');
          }
          return _attachmentDownloadStateFromRow(
            await _attachmentDownloadRow(reference),
          );
        } finally {
          _clearAttachmentDownloadRowBytes(existing);
        }
      }
      await _database
          .into(table)
          .insert(
            E2eeAttachmentDownloadRowsCompanion.insert(
              attachmentId: reference.attachmentId,
              uploadId: reference.uploadId,
              chunkKeyEpoch: reference.chunkKeyEpoch,
              manifestKeyEpoch: reference.manifestKeyEpoch,
              manifestRevision: reference.manifestRevision,
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
        await _attachmentDownloadRow(reference),
      );
    });
  }

  Future<E2eeAttachmentDownloadState?> read(
    E2eeAttachmentDownloadReference reference,
  ) async {
    final row =
        await (_database.select(_database.e2eeAttachmentDownloadRows)..where(
              (table) => _matchesAttachmentDownloadReference(table, reference),
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
                row.chunkKeyEpoch.equals(reference.chunkKeyEpoch) &
                row.manifestKeyEpoch.equals(reference.manifestKeyEpoch) &
                row.manifestRevision.equals(reference.manifestRevision) &
                row.kind.equals(reference.kind.name);
          }
          return predicate;
        })
        ..orderBy(<OrderClauseGenerator<$E2eeAttachmentDownloadRowsTable>>[
          (row) => OrderingTerm.asc(row.nextAttemptAt),
          (row) => OrderingTerm.asc(row.createdAt),
          (row) => OrderingTerm.asc(row.attachmentId),
          (row) => OrderingTerm.asc(row.manifestKeyEpoch),
          (row) => OrderingTerm.asc(row.manifestRevision),
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
        final candidateReference = _attachmentDownloadReferenceFromRow(
          candidate,
        );
        final updated =
            await (_database.update(table)..where(
                  (row) =>
                      _matchesAttachmentDownloadReference(
                        row,
                        candidateReference,
                      ) &
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
        final claimed = await _attachmentDownloadRow(candidateReference);
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

  Future<E2eeAttachmentDownloadState> reuseReadyAssetAfterManifest({
    required E2eeAttachmentDownloadLease lease,
    required E2eeAttachmentManifest manifest,
    required Uint8List manifestCiphertext,
    required String finalPath,
    required DateTime now,
  }) async {
    final state = lease.state;
    final candidateAssetId = state.localAssetId;
    final candidatePath = state.finalPath;
    if (state.phase != E2eeAttachmentDownloadPhase.manifestPending ||
        candidateAssetId == null ||
        candidatePath == null) {
      throw StateError('附件下载当前没有可复用的完成资产');
    }
    _requireMatchingDownloadManifest(state.reference, manifest);
    if (manifestCiphertext.isEmpty ||
        manifestCiphertext.length >
            _attachmentDownloadMaxManifestCiphertextBytes) {
      throw const FormatException('附件下载清单密文长度无效');
    }
    final materialized = _requireAttachmentStorageText(
      finalPath,
      'finalPath',
      32768,
    );
    final expectedAssetId =
        'asset_${_attachmentDigestHex(manifest.contentSha256)}';
    if (candidateAssetId != expectedAssetId || candidatePath != materialized) {
      throw const FormatException('附件下载复用资产与新清单内容身份不一致');
    }
    final timestamp = _requireStorageTime(now, 'now');
    _requireActiveAttachmentDownloadLease(lease, timestamp);
    final persistedManifestCiphertext = Uint8List.fromList(manifestCiphertext);
    return _database.transaction(() async {
      if (state.transitionVersion >= _attachmentUploadMaxPositiveInt63) {
        throw StateError('附件下载 transitionVersion 已耗尽');
      }
      final asset = await (_database.select(
        _database.assetRows,
      )..where((row) => row.id.equals(candidateAssetId))).getSingleOrNull();
      if (asset == null ||
          asset.contentHash != _attachmentDigestHex(manifest.contentSha256) ||
          asset.path != materialized ||
          asset.byteSize != manifest.totalPlaintextBytes) {
        throw const FormatException('附件下载复用资产注册与新清单不一致');
      }
      final updated =
          await (_database.update(
            _database.e2eeAttachmentDownloadRows,
          )..where((row) => _matchesAttachmentDownloadLease(row, lease))).write(
            E2eeAttachmentDownloadRowsCompanion(
              phase: Value(E2eeAttachmentDownloadPhase.ready.wireValue),
              manifestCiphertext: Value(persistedManifestCiphertext),
              contentSha256: Value(manifest.contentSha256),
              wrappedDataKey: Value(manifest.wrappedDataKey),
              totalPlaintextBytes: Value(manifest.totalPlaintextBytes),
              chunkCount: Value(manifest.chunkCiphertextBytes.length),
              totalCiphertextBytes: Value(manifest.totalCiphertextBytes),
              displayName: Value(manifest.displayName),
              mediaType: Value(manifest.mediaType),
              localAssetId: Value(candidateAssetId),
              stagingPath: const Value(null),
              finalPath: Value(materialized),
              nextChunkIndex: Value(manifest.chunkCiphertextBytes.length),
              confirmedPlaintextBytes: Value(manifest.totalPlaintextBytes),
              leaseToken: const Value(null),
              leaseOwnerSessionId: const Value(null),
              leaseExpiresAt: const Value(null),
              transitionVersion: Value(state.transitionVersion + 1),
              consecutiveFailureCount: const Value(0),
              nextAttemptAt: Value(timestamp),
              lastFailureKind: const Value(null),
              terminalFailureKind: const Value(null),
              updatedAt: Value(timestamp),
            ),
          );
      if (updated != 1) throw StateError('附件下载完成资产复用 CAS 失败');
      await _database.customStatement(
        'DELETE FROM asset_gc_rows WHERE asset_id = ?;',
        [candidateAssetId],
      );
      return _attachmentDownloadStateFromRow(
        await _attachmentDownloadRow(state.reference),
      );
    });
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
        asset.chunkKeyEpoch != state.chunkKeyEpoch ||
        asset.manifestKeyEpoch != state.manifestKeyEpoch ||
        asset.manifestRevision != state.manifestRevision) {
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
        await _attachmentDownloadRow(lease.state.reference),
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

  Future<E2eeAttachmentDownloadLease> completeStagingCleanup({
    required E2eeAttachmentDownloadLease lease,
    required String cleanupStagingPath,
    required DateTime now,
  }) {
    final cleanupPath = _requireAttachmentStorageText(
      cleanupStagingPath,
      'cleanupStagingPath',
      32768,
    );
    if (lease.state.phase != E2eeAttachmentDownloadPhase.manifestPending ||
        lease.state.cleanupStagingPath != cleanupPath) {
      throw StateError('附件下载暂存清理回执不一致');
    }
    return _transitionDownloadLease(
      lease: lease,
      now: now,
      resetFailureState: false,
      changes: const E2eeAttachmentDownloadRowsCompanion(
        cleanupStagingPath: Value(null),
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
        await _attachmentDownloadRow(lease.state.reference),
      );
    });
  }

  Future<bool> deleteFailedForRebuild({
    required E2eeAttachmentDownloadReference reference,
    required int expectedTransitionVersion,
    required DateTime now,
  }) async {
    if (expectedTransitionVersion < 1 ||
        expectedTransitionVersion > _attachmentUploadMaxPositiveInt63) {
      throw const FormatException('expectedTransitionVersion 超出有效范围');
    }
    if (expectedTransitionVersion == _attachmentUploadMaxPositiveInt63) {
      throw StateError('附件下载 transitionVersion 已耗尽');
    }
    final timestamp = _requireStorageTime(now, 'now');
    final updated = await _database.customUpdate(
      '''
      UPDATE e2ee_attachment_download_rows
      SET phase = 'dormant',
          manifest_ciphertext = NULL,
          content_sha256 = NULL,
          wrapped_data_key = NULL,
          total_plaintext_bytes = NULL,
          chunk_count = NULL,
          total_ciphertext_bytes = NULL,
          display_name = NULL,
          media_type = NULL,
          local_asset_id = NULL,
          cleanup_staging_path = COALESCE(staging_path, cleanup_staging_path),
          staging_path = NULL,
          final_path = NULL,
          next_chunk_index = 0,
          confirmed_plaintext_bytes = 0,
          transition_version = transition_version + 1,
          consecutive_failure_count = 0,
          next_attempt_at = ?,
          last_failure_kind = NULL,
          terminal_failure_kind = NULL,
          updated_at = ?
      WHERE attachment_id = ?
        AND upload_id = ?
        AND chunk_key_epoch = ?
        AND manifest_key_epoch = ?
        AND manifest_revision = ?
        AND kind = ?
        AND transition_version = ?
        AND terminal_failure_kind IS NOT NULL
        AND lease_token IS NULL;
      ''',
      variables: <Variable<Object>>[
        Variable<int>(timestamp.microsecondsSinceEpoch),
        Variable<int>(timestamp.microsecondsSinceEpoch),
        Variable<String>(reference.attachmentId),
        Variable<String>(reference.uploadId),
        Variable<int>(reference.chunkKeyEpoch),
        Variable<int>(reference.manifestKeyEpoch),
        Variable<int>(reference.manifestRevision),
        Variable<String>(reference.kind.name),
        Variable<int>(expectedTransitionVersion),
      ],
      updates: {_database.e2eeAttachmentDownloadRows},
    );
    if (updated > 1) throw StateError('附件下载重建 CAS 更新了多行');
    return updated == 1;
  }

  Future<int> invalidateReadyByLocalAssetId(
    String localAssetId, {
    required DateTime now,
  }) {
    final id = _requireAttachmentStorageText(
      localAssetId,
      'localAssetId',
      1024,
    );
    final timestamp = _requireStorageTime(now, 'now');
    return _database.transaction(() async {
      final exhausted = await _database
          .customSelect(
            '''
        SELECT 1 AS exhausted
        FROM e2ee_attachment_download_rows
        WHERE local_asset_id = ?
          AND phase = 'ready'
          AND lease_token IS NULL
          AND transition_version >= ?
        LIMIT 1;
        ''',
            variables: <Variable<Object>>[
              Variable<String>(id),
              Variable<int>(_attachmentUploadMaxPositiveInt63),
            ],
          )
          .getSingleOrNull();
      if (exhausted != null) {
        throw StateError('附件下载 transitionVersion 已耗尽');
      }
      return _database.customUpdate(
        '''
        UPDATE e2ee_attachment_download_rows
        SET phase = 'dormant',
            manifest_ciphertext = NULL,
            content_sha256 = NULL,
            wrapped_data_key = NULL,
            total_plaintext_bytes = NULL,
            chunk_count = NULL,
            total_ciphertext_bytes = NULL,
            display_name = NULL,
            media_type = NULL,
            local_asset_id = NULL,
            cleanup_staging_path = NULL,
            staging_path = NULL,
            final_path = NULL,
            next_chunk_index = 0,
            confirmed_plaintext_bytes = 0,
            transition_version = transition_version + 1,
            consecutive_failure_count = 0,
            next_attempt_at = ?,
            last_failure_kind = NULL,
            terminal_failure_kind = NULL,
            updated_at = ?
        WHERE local_asset_id = ?
          AND phase = 'ready'
          AND lease_token IS NULL;
        ''',
        variables: <Variable<Object>>[
          Variable<int>(timestamp.microsecondsSinceEpoch),
          Variable<int>(timestamp.microsecondsSinceEpoch),
          Variable<String>(id),
        ],
        updates: {_database.e2eeAttachmentDownloadRows},
      );
    });
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
        await _attachmentDownloadRow(lease.state.reference),
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
    E2eeAttachmentDownloadReference reference,
  ) {
    return (_database.select(_database.e2eeAttachmentDownloadRows)
          ..where((row) => _matchesAttachmentDownloadReference(row, reference)))
        .getSingle();
  }
}

void _requireMatchingDownloadManifest(
  E2eeAttachmentDownloadReference reference,
  E2eeAttachmentManifest manifest,
) {
  if (manifest.attachmentId != reference.attachmentId ||
      manifest.uploadId != reference.uploadId ||
      manifest.chunkKeyEpoch != reference.chunkKeyEpoch ||
      manifest.manifestKeyEpoch != reference.manifestKeyEpoch ||
      manifest.manifestRevision != reference.manifestRevision ||
      manifest.kind != reference.kind) {
    throw const FormatException('附件下载清单与消息引用身份不一致');
  }
}

void _requireMatchingDownloadReference(
  E2eeAttachmentDownloadReference expected,
  E2eeAttachmentDownloadReference actual,
) {
  if (!_sameDownloadReference(expected, actual)) {
    throw StateError('attachment_download_identity_conflict');
  }
}

bool _sameStableDownloadReference(
  E2eeAttachmentDownloadReference left,
  E2eeAttachmentDownloadReference right,
) =>
    left.attachmentId == right.attachmentId &&
    left.uploadId == right.uploadId &&
    left.chunkKeyEpoch == right.chunkKeyEpoch &&
    left.kind == right.kind;

bool _sameDownloadReference(
  E2eeAttachmentDownloadReference left,
  E2eeAttachmentDownloadReference right,
) =>
    _sameStableDownloadReference(left, right) &&
    left.manifestKeyEpoch == right.manifestKeyEpoch &&
    left.manifestRevision == right.manifestRevision;

void _requireForwardManifestTransition(
  E2eeAttachmentDownloadReference current,
  E2eeAttachmentDownloadReference next,
) {
  if (!_sameStableDownloadReference(current, next) ||
      next.manifestKeyEpoch <= current.manifestKeyEpoch ||
      next.manifestRevision <= current.manifestRevision) {
    throw StateError('attachment_download_manifest_transition_invalid');
  }
  final epochDelta = next.manifestKeyEpoch - current.manifestKeyEpoch;
  final revisionDelta = next.manifestRevision - current.manifestRevision;
  if (epochDelta != revisionDelta) {
    throw StateError('attachment_download_manifest_transition_invalid');
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
  return _matchesAttachmentDownloadReference(row, lease.state.reference) &
      row.phase.equals(lease.state.phase.wireValue) &
      row.transitionVersion.equals(lease.state.transitionVersion) &
      row.leaseToken.equals(lease.leaseToken) &
      row.leaseOwnerSessionId.equals(lease.leaseOwner) &
      row.leaseExpiresAt.equalsValue(lease.leaseExpiresAt);
}

Expression<bool> _matchesAttachmentDownloadReference(
  $E2eeAttachmentDownloadRowsTable row,
  E2eeAttachmentDownloadReference reference,
) {
  return row.attachmentId.equals(reference.attachmentId) &
      row.uploadId.equals(reference.uploadId) &
      row.chunkKeyEpoch.equals(reference.chunkKeyEpoch) &
      row.manifestKeyEpoch.equals(reference.manifestKeyEpoch) &
      row.manifestRevision.equals(reference.manifestRevision) &
      row.kind.equals(reference.kind.name);
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
    final reference = _attachmentDownloadReferenceFromRow(row);
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
      cleanupStagingPath: row.cleanupStagingPath,
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

E2eeAttachmentDownloadReference _attachmentDownloadReferenceFromRow(
  E2eeAttachmentDownloadRow row,
) {
  return E2eeAttachmentDownloadReference(
    attachmentId: row.attachmentId,
    uploadId: row.uploadId,
    chunkKeyEpoch: row.chunkKeyEpoch,
    manifestKeyEpoch: row.manifestKeyEpoch,
    manifestRevision: row.manifestRevision,
    kind: switch (row.kind) {
      'image' => E2eeAttachmentKind.image,
      'file' => E2eeAttachmentKind.file,
      _ => throw StateError('附件下载持久类型不受支持'),
    },
  );
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
    chunkKeyEpoch: reference.chunkKeyEpoch,
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

int _requireAttachmentKeyEpoch(int value, String field) {
  if (value < 1 || value > 0xffffffff) {
    throw FormatException('$field 必须位于正 uint32 范围');
  }
  return value;
}

String _attachmentDigestHex(Uint8List digest) {
  if (digest.length != 32) {
    throw const FormatException('附件内容摘要长度无效');
  }
  return digest.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
