import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:uuid/uuid.dart';

import '../../database/chat_database_repository.dart';
import 'cloud_sync_attachment_types.dart';
import 'cloud_sync_client.dart';
import 'cloud_sync_terminal_session_retirement.dart';
import 'cloud_sync_types.dart';
import 'e2ee_attachment_crypto_session.dart';
import 'e2ee_attachment_file_store.dart';
import 'e2ee_attachment_manifest.dart';
import 'e2ee_sync_execution_budget.dart';

const _attachmentUploadLeaseDuration = Duration(minutes: 5);

final class E2eeAttachmentUploadCoordinator {
  factory E2eeAttachmentUploadCoordinator.takeOwnership({
    required E2eeAttachmentUploadCommands commands,
    required E2eeAttachmentFileStore fileStore,
    required CloudSyncAttachmentTransport transport,
    required CloudSyncFullSessionToken token,
    required E2eeAttachmentCrypto cryptoSession,
    DateTime Function()? utcNow,
    String Function()? newUuid,
  }) {
    final uuidFactory = newUuid ?? _defaultUuid;
    return E2eeAttachmentUploadCoordinator._(
      commands: commands,
      fileStore: fileStore,
      transport: transport,
      token: token,
      cryptoSession: cryptoSession,
      utcNow: utcNow ?? _now,
      newUuid: uuidFactory,
      leaseOwner: _requireCanonicalUuidV4(uuidFactory(), 'leaseOwner'),
    );
  }

  E2eeAttachmentUploadCoordinator._({
    required this._commands,
    required this._fileStore,
    required this._transport,
    required this._token,
    required this._cryptoSession,
    required this._utcNow,
    required String Function() newUuid,
    required this._leaseOwner,
  }) : _uuidFactory = newUuid;

  final E2eeAttachmentUploadCommands _commands;
  final E2eeAttachmentFileStore _fileStore;
  final CloudSyncAttachmentTransport _transport;
  final CloudSyncFullSessionToken _token;
  final E2eeAttachmentCrypto _cryptoSession;
  final DateTime Function() _utcNow;
  final String Function() _uuidFactory;
  final String _leaseOwner;
  _OpenedUploadSource? _openedSource;

  Future<void> _operationTail = Future<void>.value();
  bool _acceptingOperations = true;
  bool _closed = false;
  Future<void>? _closeFuture;

  Future<E2eeAttachmentUploadDraft> prepareDraft({
    required String localAssetId,
    required String targetRevisionId,
    required int targetOrdinal,
    required String sourcePath,
    required E2eeAttachmentKind kind,
    required int totalPlaintextBytes,
    required Uint8List contentSha256,
    String? displayName,
    String? mediaType,
  }) {
    return _runWhileOpen(() async {
      final descriptor = await _cryptoSession.createUploadDescriptor(
        kind: kind,
        totalPlaintextBytes: totalPlaintextBytes,
        contentSha256: contentSha256,
        displayName: displayName,
        mediaType: mediaType,
      );
      return E2eeAttachmentUploadDraft(
        descriptor: descriptor,
        localAssetId: localAssetId,
        targetRevisionId: targetRevisionId,
        targetOrdinal: targetOrdinal,
        sourcePath: sourcePath,
        createMutationId: _nextUuid('createMutationId'),
        commitMutationId: _nextUuid('commitMutationId'),
      );
    });
  }

  Future<int> advance(
    int maximumRemoteSteps, {
    E2eeSyncExecutionBudget? executionBudget,
  }) {
    if (maximumRemoteSteps < 0) {
      return Future<int>.error(
        const FormatException('maximumRemoteSteps 不得为负数'),
      );
    }
    return _runWhileOpen(() => _advance(maximumRemoteSteps, executionBudget));
  }

  Future<void> close() {
    if (_closed) return Future<void>.value();
    final active = _closeFuture;
    if (active != null) return active;
    _acceptingOperations = false;
    late final Future<void> closing;
    closing = () async {
      try {
        await _closeAfterOperations();
        _closed = true;
      } finally {
        if (identical(_closeFuture, closing)) _closeFuture = null;
      }
    }();
    _closeFuture = closing;
    return closing;
  }

  Future<int> _advance(
    int maximumRemoteSteps,
    E2eeSyncExecutionBudget? executionBudget,
  ) async {
    if (maximumRemoteSteps == 0) return 0;
    executionBudget?.checkCanContinue();
    var remoteSteps = 0;
    while (remoteSteps < maximumRemoteSteps) {
      executionBudget?.checkCanContinue();
      final claimTime = _currentTime();
      final claimed = await _commands.claimDue(
        leaseToken: _nextUuid('leaseToken'),
        leaseOwner: _leaseOwner,
        leaseExpiresAt: claimTime.add(_attachmentUploadLeaseDuration),
        now: claimTime,
      );
      if (claimed == null) break;

      var lease = claimed;
      var ownsLease = true;
      try {
        final source = _sourceFile(lease.state);
        final sourceReader = await _openSourceReader(
          lease.state,
          source,
          executionBudget,
        );
        while (ownsLease && remoteSteps < maximumRemoteSteps) {
          executionBudget?.checkCanContinue();
          if (!_leaseIsActive(lease)) {
            ownsLease = false;
            break;
          }
          var releaseAfterRemoteStep = false;
          switch (lease.state.phase) {
            case E2eeAttachmentUploadPhase.createPending:
              remoteSteps++;
              final created = await _runRemote(
                () => _transport.createAttachmentUpload(
                  token: _token,
                  request: CloudSyncAttachmentCreateUploadRequest(
                    mutationId: lease.state.createMutationId,
                    attachmentId: lease.state.attachmentId,
                    chunkKeyEpoch: lease.state.descriptor.chunkKeyEpoch,
                    manifestKeyEpoch: lease.state.manifestKeyEpoch,
                    manifestRevision: lease.state.manifestRevision,
                    chunkCount:
                        lease.state.descriptor.chunkCiphertextBytes.length,
                    totalCiphertextBytes:
                        lease.state.descriptor.totalCiphertextBytes,
                  ),
                ),
                executionBudget: executionBudget,
              );
              _requireCreatedMatches(lease.state, created);
              final accepted = await _persistRemoteResult(
                () => _commands.acceptCreated(
                  lease: lease,
                  uploadId: created.identity.uploadId,
                  now: _currentTime(),
                ),
              );
              if (accepted == null) {
                ownsLease = false;
                continue;
              }
              lease = accepted;
              releaseAfterRemoteStep = true;
              break;
            case E2eeAttachmentUploadPhase.manifestPending:
              final uploadId = lease.state.uploadId;
              if (uploadId == null) {
                throw const _PermanentUploadFailure(
                  'persisted-upload-identity-invalid',
                );
              }
              final sealed = await _runLocal(
                'manifest-crypto-failed',
                () => _cryptoSession.sealManifest(
                  descriptor: lease.state.descriptor,
                  uploadId: uploadId,
                  manifestRevision: lease.state.manifestRevision,
                ),
              );
              lease = await _commands.attachManifest(
                lease: lease,
                sealedManifest: sealed,
                now: _currentTime(),
              );
              break;
            case E2eeAttachmentUploadPhase.uploading:
              if (lease.state.pendingChunk == null) {
                final staged = await _stageNextChunk(
                  lease,
                  sourceReader,
                  executionBudget,
                );
                if (staged == null) {
                  ownsLease = false;
                  continue;
                }
                lease = staged;
              }
              final pending = lease.state.pendingChunk;
              final uploadId = lease.state.uploadId;
              if (pending == null || uploadId == null) {
                throw const _PermanentUploadFailure(
                  'persisted-upload-state-invalid',
                );
              }
              final chunk = CloudSyncAttachmentChunkIdentity(
                identity: CloudSyncAttachmentIdentity(
                  attachmentId: lease.state.attachmentId,
                  uploadId: uploadId,
                  chunkKeyEpoch: lease.state.descriptor.chunkKeyEpoch,
                  manifestKeyEpoch: lease.state.manifestKeyEpoch,
                  manifestRevision: lease.state.manifestRevision,
                ),
                chunkIndex: pending.index,
              );
              final ciphertext = await _readPendingCiphertext(
                pending,
                executionBudget,
              );
              try {
                if (!_leaseIsActive(lease)) {
                  ownsLease = false;
                  continue;
                }
                remoteSteps++;
                final stored = await _runRemote(
                  () => _transport.putAttachmentChunk(
                    token: _token,
                    request: CloudSyncAttachmentPutChunkRequest(
                      mutationId: pending.mutationId,
                      chunk: chunk,
                      ciphertext: ciphertext,
                    ),
                  ),
                  executionBudget: executionBudget,
                  attachmentByteReservation: ciphertext.length,
                );
                _requireStoredChunkMatches(chunk, ciphertext.length, stored);
              } finally {
                ciphertext.fillRange(0, ciphertext.length, 0);
              }
              final acknowledged = await _persistRemoteResult(
                () => _commands.acknowledgeChunk(
                  lease: lease,
                  now: _currentTime(),
                ),
              );
              if (acknowledged == null) {
                ownsLease = false;
                continue;
              }
              lease = acknowledged;
              // 数据库先确认，崩溃恢复时才不会丢失必须重放的唯一密文。
              await _fileStore.deleteStaging(
                storagePath: pending.ciphertextPath,
              );
              releaseAfterRemoteStep = true;
              break;
            case E2eeAttachmentUploadPhase.commitPending:
              final uploadId = lease.state.uploadId;
              final manifestCiphertext = lease.state.manifestCiphertext;
              if (uploadId == null || manifestCiphertext == null) {
                throw const _PermanentUploadFailure(
                  'persisted-upload-state-invalid',
                );
              }
              final identity = CloudSyncAttachmentIdentity(
                attachmentId: lease.state.attachmentId,
                uploadId: uploadId,
                chunkKeyEpoch: lease.state.descriptor.chunkKeyEpoch,
                manifestKeyEpoch: lease.state.manifestKeyEpoch,
                manifestRevision: lease.state.manifestRevision,
              );
              remoteSteps++;
              final committed = await _runRemote(
                () => _transport.commitAttachmentUpload(
                  token: _token,
                  request: CloudSyncAttachmentCommitUploadRequest(
                    mutationId: lease.state.commitMutationId,
                    identity: identity,
                    manifestCiphertext: manifestCiphertext,
                    chunks: <CloudSyncAttachmentManifestChunk>[
                      for (
                        var index = 0;
                        index <
                            lease.state.descriptor.chunkCiphertextBytes.length;
                        index++
                      )
                        CloudSyncAttachmentManifestChunk(
                          chunkIndex: index,
                          ciphertextBytes: lease
                              .state
                              .descriptor
                              .chunkCiphertextBytes[index],
                        ),
                    ],
                  ),
                ),
                executionBudget: executionBudget,
                attachmentByteReservation: manifestCiphertext.length,
              );
              _requireCommittedMatches(identity, committed);
              final committedState = await _persistRemoteResult(
                () =>
                    _commands.markCommitted(lease: lease, now: _currentTime()),
              );
              if (committedState == null) {
                ownsLease = false;
                continue;
              }
              ownsLease = false;
              await _closeOpenedSource(lease.state.attachmentId);
              break;
            case E2eeAttachmentUploadPhase.committed:
              throw StateError('附件上传完成状态不得被 claim');
          }
          if (ownsLease && releaseAfterRemoteStep) {
            // 命令层没有续租操作；每个远端步骤重新 claim 可将竞争窗口限制在单次请求内。
            await _releaseLease(lease);
            ownsLease = false;
          }
        }
        if (ownsLease) {
          await _releaseLease(lease);
          ownsLease = false;
        }
      } on _RetryableUploadFailure catch (failure) {
        if (ownsLease) {
          final now = _currentTime();
          final released = await _commands.releaseAfterFailure(
            lease: lease,
            nextAttemptAt: now.add(
              _retryDelay(lease.state.consecutiveFailureCount),
            ),
            failureKind: failure.kind,
            now: now,
          );
          ownsLease = false;
          if (!released && now.isBefore(lease.leaseExpiresAt)) {
            throw StateError('附件上传可重试失败状态 CAS 失败');
          }
        }
      } on _PermanentUploadFailure catch (failure) {
        if (ownsLease) {
          await _commands.markPermanentlyFailed(
            lease: lease,
            failureKind: failure.kind,
            now: _currentTime(),
          );
          ownsLease = false;
        }
      } catch (error, stackTrace) {
        if (ownsLease) {
          final now = _currentTime();
          if (now.isBefore(lease.leaseExpiresAt)) {
            try {
              await _releaseLease(lease, now: now);
            } catch (cleanupError, cleanupStackTrace) {
              developer.log(
                'E2EE 附件上传异常后的租约释放失败',
                name: 'Kelivo.E2eeAttachmentUploadCoordinator',
                error: cleanupError,
                stackTrace: cleanupStackTrace,
              );
            }
          }
          ownsLease = false;
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
    return remoteSteps;
  }

  Future<E2eeAttachmentUploadLease?> _stageNextChunk(
    E2eeAttachmentUploadLease lease,
    E2eeAttachmentVerifiedContent sourceReader,
    E2eeSyncExecutionBudget? executionBudget,
  ) async {
    final state = lease.state;
    final uploadId = state.uploadId;
    if (uploadId == null) {
      throw const _PermanentUploadFailure('persisted-upload-identity-invalid');
    }
    final chunkIndex = state.nextChunkIndex;
    final plaintext = await _runLocal(
      'source-integrity-failed',
      () => sourceReader.readChunk(
        chunkIndex,
        checkCanContinue: executionBudget?.checkCanContinue,
      ),
    );
    Uint8List? ciphertext;
    E2eeAttachmentStoredFile? unownedStaging;
    try {
      executionBudget?.checkCanContinue();
      ciphertext = await _runLocal(
        'attachment-crypto-failed',
        () => _cryptoSession.sealChunk(
          descriptor: state.descriptor,
          uploadId: uploadId,
          chunkIndex: chunkIndex,
          plaintext: plaintext,
        ),
      );
      executionBudget?.checkCanContinue();
      final mutationId = _nextUuid('chunkMutationId');
      final identity = CloudSyncAttachmentIdentity(
        attachmentId: state.attachmentId,
        uploadId: uploadId,
        chunkKeyEpoch: state.descriptor.chunkKeyEpoch,
        manifestKeyEpoch: state.manifestKeyEpoch,
        manifestRevision: state.manifestRevision,
      );
      final stored = await _runLocal(
        'staging-integrity-failed',
        () => _fileStore.publish(
          location: E2eeAttachmentFileLocation.stagingUploadChunk(
            chunk: CloudSyncAttachmentChunkIdentity(
              identity: identity,
              chunkIndex: chunkIndex,
            ),
            mutationId: mutationId,
          ),
          source: Stream<List<int>>.value(ciphertext!),
          checkCanContinue: executionBudget?.checkCanContinue,
        ),
      );
      unownedStaging = stored;
      executionBudget?.checkCanContinue();
      if (stored.bytes != state.descriptor.chunkCiphertextBytes[chunkIndex]) {
        throw const _PermanentUploadFailure('staging-integrity-failed');
      }
      final staged = await _commands.stageChunk(
        lease: lease,
        chunkIndex: chunkIndex,
        mutationId: mutationId,
        ciphertextPath: stored.storagePath,
        ciphertextBytes: stored.bytes,
        ciphertextSha256: stored.sha256,
        now: _currentTime(),
      );
      unownedStaging = null;
      executionBudget?.checkCanContinue();
      return staged;
    } catch (error, stackTrace) {
      final staging = unownedStaging;
      if (staging != null) {
        try {
          await _fileStore.deleteStaging(storagePath: staging.storagePath);
        } catch (cleanupError, cleanupStackTrace) {
          developer.log(
            'E2EE 附件分块持久状态接管失败后的 staging 清理失败',
            name: 'Kelivo.E2eeAttachmentUploadCoordinator',
            error: cleanupError,
            stackTrace: cleanupStackTrace,
          );
        }
      }
      if (error is StateError && _isExpiredLeaseError(error)) return null;
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
      ciphertext?.fillRange(0, ciphertext.length, 0);
    }
  }

  Future<Uint8List> _readPendingCiphertext(
    E2eeAttachmentPendingChunk pending,
    E2eeSyncExecutionBudget? executionBudget,
  ) {
    return _runLocal(
      'pending-ciphertext-integrity-failed',
      () => _fileStore.readVerified(
        E2eeAttachmentStoredFile(
          storagePath: pending.ciphertextPath,
          bytes: pending.ciphertextBytes,
          sha256: pending.ciphertextSha256,
        ),
        checkCanContinue: executionBudget?.checkCanContinue,
      ),
    );
  }

  E2eeAttachmentStoredFile _sourceFile(E2eeAttachmentUploadState state) {
    try {
      return E2eeAttachmentStoredFile(
        storagePath: state.sourcePath,
        bytes: state.descriptor.totalPlaintextBytes,
        sha256: state.descriptor.contentSha256,
      );
    } on FormatException {
      throw const _PermanentUploadFailure('source-integrity-failed');
    }
  }

  Future<E2eeAttachmentVerifiedContent> _openSourceReader(
    E2eeAttachmentUploadState state,
    E2eeAttachmentStoredFile source,
    E2eeSyncExecutionBudget? executionBudget,
  ) async {
    final fingerprint =
        '${source.storagePath}\u0000${source.bytes}\u0000'
        '${_hex(source.sha256)}';
    final opened = _openedSource;
    if (opened != null &&
        opened.attachmentId == state.attachmentId &&
        opened.fingerprint == fingerprint) {
      return opened.reader;
    }
    if (opened != null) {
      await _runLocal('source-reader-close-failed', opened.reader.close);
      if (identical(_openedSource, opened)) _openedSource = null;
    }
    final layout = KelivoAttachmentLayout(
      totalPlaintextBytes: state.descriptor.totalPlaintextBytes,
    );
    final reader = await _runLocal(
      'source-integrity-failed',
      () => _fileStore.openVerifiedContent(
        storedFile: source,
        chunkPlaintextBytes: <int>[
          for (var index = 0; index < layout.chunkCount; index++)
            layout.plaintextLengthForChunk(index),
        ],
        checkCanContinue: executionBudget?.checkCanContinue,
      ),
    );
    _openedSource = _OpenedUploadSource(
      attachmentId: state.attachmentId,
      fingerprint: fingerprint,
      reader: reader,
    );
    return reader;
  }

  Future<void> _closeOpenedSource(String? attachmentId) async {
    final opened = _openedSource;
    if (opened == null ||
        (attachmentId != null && opened.attachmentId != attachmentId)) {
      return;
    }
    await opened.reader.close();
    if (identical(_openedSource, opened)) _openedSource = null;
  }

  Future<T?> _persistRemoteResult<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on StateError catch (error) {
      if (_isExpiredLeaseError(error)) return null;
      rethrow;
    }
  }

  Future<void> _releaseLease(
    E2eeAttachmentUploadLease lease, {
    DateTime? now,
  }) async {
    final releaseTime = now ?? _currentTime();
    final released = await _commands.release(lease: lease, now: releaseTime);
    if (!released && releaseTime.isBefore(lease.leaseExpiresAt)) {
      throw StateError('附件上传租约释放 CAS 失败');
    }
  }

  Future<T> _runRemote<T>(
    Future<T> Function() operation, {
    required E2eeSyncExecutionBudget? executionBudget,
    int attachmentByteReservation = 0,
  }) async {
    try {
      if (executionBudget == null) return await operation();
      return await executionBudget.runNetworkStep(
        attachmentByteReservation: attachmentByteReservation,
        operation: (_) => operation(),
      );
    } on CloudSyncException catch (error) {
      if (error.kind == CloudSyncFailureKind.cancelled ||
          isTerminalCloudSyncAuthenticationFailure(error)) {
        rethrow;
      }
      final kind = 'remote-${error.kind.name}';
      if (error.retryable) throw _RetryableUploadFailure(kind);
      throw _PermanentUploadFailure(kind);
    } on TimeoutException {
      throw const _RetryableUploadFailure('remote-timeout');
    } on FormatException {
      throw const _PermanentUploadFailure('remote-invalid-response');
    }
  }

  Future<T> _runLocal<T>(
    String failureKind,
    Future<T> Function() operation,
  ) async {
    try {
      return await operation();
    } on FormatException {
      throw _PermanentUploadFailure(failureKind);
    } on FileSystemException catch (error) {
      if (error.message == 'e2ee_attachment_file_missing') {
        throw _PermanentUploadFailure(failureKind);
      }
      throw const _RetryableUploadFailure('local-io');
    } on KelivoSecureCoreException catch (error) {
      if (error.operation == 'attachment_data_key_handle_close') {
        throw const _RetryableUploadFailure('local-crypto-cleanup');
      }
      throw _PermanentUploadFailure(failureKind);
    } on StateError catch (error) {
      if (error.message.toString().startsWith('e2ee_attachment_')) {
        throw _PermanentUploadFailure(failureKind);
      }
      rethrow;
    }
  }

  Future<T> _runWhileOpen<T>(Future<T> Function() operation) {
    if (!_acceptingOperations) {
      return Future<T>.error(StateError('E2EE 附件上传协调器已经关闭'));
    }
    final previous = _operationTail;
    final completed = Completer<void>();
    _operationTail = completed.future;
    return () async {
      await previous;
      try {
        return await operation();
      } finally {
        completed.complete();
      }
    }();
  }

  Future<void> _closeAfterOperations() async {
    await _operationTail;
    Object? firstError;
    StackTrace? firstStackTrace;
    final cleanup = <Future<void> Function()>[
      () => _closeOpenedSource(null),
      _cryptoSession.close,
    ];
    for (final action in cleanup) {
      try {
        await action();
      } catch (error, stackTrace) {
        if (firstError == null) {
          firstError = error;
          firstStackTrace = stackTrace;
        } else {
          developer.log(
            'E2EE 附件上传协调器关闭时的后续资源清理失败',
            name: 'Kelivo.E2eeAttachmentUploadCoordinator',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    }
    if (firstError != null && firstStackTrace != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace);
    }
  }

  DateTime _currentTime() => _utcNow().toUtc();

  bool _leaseIsActive(E2eeAttachmentUploadLease lease) =>
      _currentTime().isBefore(lease.leaseExpiresAt);

  String _nextUuid(String field) =>
      _requireCanonicalUuidV4(_uuidFactory(), field);
}

bool _isExpiredLeaseError(StateError error) => error.message == '附件上传租约已过期';

final class _OpenedUploadSource {
  const _OpenedUploadSource({
    required this.attachmentId,
    required this.fingerprint,
    required this.reader,
  });

  final String attachmentId;
  final String fingerprint;
  final E2eeAttachmentVerifiedContent reader;
}

sealed class _UploadFailure implements Exception {
  const _UploadFailure(this.kind);

  final String kind;
}

final class _RetryableUploadFailure extends _UploadFailure {
  const _RetryableUploadFailure(super.kind);
}

final class _PermanentUploadFailure extends _UploadFailure {
  const _PermanentUploadFailure(super.kind);
}

void _requireCreatedMatches(
  E2eeAttachmentUploadState state,
  CloudSyncAttachmentUpload created,
) {
  final identity = created.identity;
  if (identity.attachmentId != state.attachmentId ||
      identity.chunkKeyEpoch != state.descriptor.chunkKeyEpoch ||
      identity.manifestKeyEpoch != state.manifestKeyEpoch ||
      identity.manifestRevision != state.manifestRevision ||
      created.chunkCount != state.descriptor.chunkCiphertextBytes.length ||
      created.totalCiphertextBytes != state.descriptor.totalCiphertextBytes) {
    throw const _PermanentUploadFailure('remote-invalid-response');
  }
}

void _requireStoredChunkMatches(
  CloudSyncAttachmentChunkIdentity expected,
  int expectedBytes,
  CloudSyncAttachmentStoredChunk stored,
) {
  final actual = stored.chunk;
  if (!_sameIdentity(expected.identity, actual.identity) ||
      actual.chunkIndex != expected.chunkIndex ||
      stored.ciphertextBytes != expectedBytes) {
    throw const _PermanentUploadFailure('remote-invalid-response');
  }
}

void _requireCommittedMatches(
  CloudSyncAttachmentIdentity expected,
  CloudSyncAttachmentCommittedUpload committed,
) {
  if (!_sameIdentity(expected, committed.identity)) {
    throw const _PermanentUploadFailure('remote-invalid-response');
  }
}

bool _sameIdentity(
  CloudSyncAttachmentIdentity left,
  CloudSyncAttachmentIdentity right,
) {
  return left.attachmentId == right.attachmentId &&
      left.uploadId == right.uploadId &&
      left.chunkKeyEpoch == right.chunkKeyEpoch &&
      left.manifestKeyEpoch == right.manifestKeyEpoch &&
      left.manifestRevision == right.manifestRevision;
}

Duration _retryDelay(int consecutiveFailureCount) {
  final bounded = consecutiveFailureCount.clamp(0, 8);
  return Duration(seconds: 1 << bounded);
}

String _hex(Uint8List bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

String _defaultUuid() => const Uuid().v4();

DateTime _now() => DateTime.now().toUtc();

String _requireCanonicalUuidV4(String value, String field) {
  try {
    final bytes = Uint8List.fromList(Uuid.parseAsByteList(value));
    if (bytes.length != 16 ||
        (bytes[6] & 0xf0) != 0x40 ||
        (bytes[8] & 0xc0) != 0x80 ||
        Uuid.unparse(bytes) != value) {
      throw FormatException('$field 必须为规范小写 UUID v4');
    }
    return value;
  } on FormatException {
    throw FormatException('$field 必须为规范小写 UUID v4');
  }
}
