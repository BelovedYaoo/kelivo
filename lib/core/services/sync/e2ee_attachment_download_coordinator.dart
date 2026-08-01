import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:uuid/uuid.dart';

import '../../database/chat_database_repository.dart';
import 'cloud_sync_attachment_types.dart';
import 'cloud_sync_client.dart';
import 'cloud_sync_types.dart';
import 'e2ee_attachment_crypto_session.dart';
import 'e2ee_attachment_file_store.dart';
import 'e2ee_attachment_manifest.dart';
import 'e2ee_message_attachment_readiness.dart';
import 'e2ee_sync_execution_budget.dart';
import 'e2ee_sync_payload_codec.dart';
import 'e2ee_sync_pull.dart';

const _downloadLeaseDuration = Duration(minutes: 15);
const _initialDownloadRetryDelay = Duration(seconds: 1);
const _maximumDownloadRetryDelay = Duration(minutes: 5);

typedef E2eeAttachmentLeaseTokenFactory = String Function();

final class E2eeAttachmentDownloadCoordinator
    implements E2eeSyncPullPagePreparer, E2eeMessageAttachmentReadiness {
  factory E2eeAttachmentDownloadCoordinator.takeOwnership({
    required E2eeAttachmentDownloadCommands commands,
    required CloudSyncAttachmentTransport transport,
    required CloudSyncFullSessionToken token,
    required E2eeAttachmentCrypto crypto,
    required E2eeAttachmentFileStore fileStore,
    required String leaseOwner,
    DateTime Function()? utcNow,
    E2eeAttachmentLeaseTokenFactory? leaseTokenFactory,
  }) => E2eeAttachmentDownloadCoordinator._(
    commands,
    transport,
    token,
    crypto,
    fileStore,
    leaseOwner,
    utcNow ?? _defaultUtcNow,
    leaseTokenFactory ?? _defaultLeaseToken,
  );

  E2eeAttachmentDownloadCoordinator._(
    this._commands,
    this._transport,
    this._token,
    this._crypto,
    this._fileStore,
    this._leaseOwner,
    this._utcNow,
    this._leaseTokenFactory,
  );

  final E2eeAttachmentDownloadCommands _commands;
  final CloudSyncAttachmentTransport _transport;
  final CloudSyncFullSessionToken _token;
  final E2eeAttachmentCrypto _crypto;
  final E2eeAttachmentFileStore _fileStore;
  final String _leaseOwner;
  final DateTime Function() _utcNow;
  final E2eeAttachmentLeaseTokenFactory _leaseTokenFactory;

  Future<void> _operationTail = Future<void>.value();
  bool _acceptingOperations = true;
  Future<void>? _closeFuture;

  @override
  Future<E2eeSyncPullPagePreparationDisposition> preparePage(
    List<E2eeSyncPulledChange> authenticatedChanges, {
    required int maximumRemoteSteps,
    E2eeSyncExecutionBudget? executionBudget,
  }) {
    if (maximumRemoteSteps < 1) {
      return Future<E2eeSyncPullPagePreparationDisposition>.error(
        RangeError.range(maximumRemoteSteps, 1, null, 'maximumRemoteSteps'),
      );
    }
    return _runWhileOpen(() async {
      final references = _uniqueAttachmentReferences(authenticatedChanges);
      if (references.any(
        (reference) =>
            reference.chunkKeyEpoch > _crypto.currentKeyEpoch ||
            reference.manifestKeyEpoch > _crypto.currentKeyEpoch,
      )) {
        return E2eeSyncPullPagePreparationDisposition.keyEpochUnavailable;
      }
      final now = _utcNow();
      for (final reference in references) {
        final state = await _commands.ensure(reference: reference, now: now);
        _requireUsableDownloadState(state);
      }

      final budget = _RemoteStepBudget(maximumRemoteSteps);
      for (final reference in references) {
        final disposition = await _materializeReference(
          reference,
          budget,
          executionBudget,
        );
        if (disposition != E2eeSyncPullPagePreparationDisposition.ready) {
          return disposition;
        }
      }
      return E2eeSyncPullPagePreparationDisposition.ready;
    });
  }

  @override
  Future<List<MessageAssetRegistration>> requireReadyForApply(
    E2eeSyncPulledValueChange messageChange,
  ) async {
    _requireAcceptingOperations();
    final references = _messageAttachmentReferences(messageChange);
    final registrations = <MessageAssetRegistration>[];
    for (final reference in references) {
      final state = await _commands.readReady(reference);
      if (state == null) {
        throw StateError('sync_message_attachment_not_ready');
      }
      registrations.add(_registrationFromReadyState(state));
    }
    return List<MessageAssetRegistration>.unmodifiable(registrations);
  }

  Future<void> close() {
    final active = _closeFuture;
    if (active != null) return active;
    _acceptingOperations = false;
    late final Future<void> closing;
    closing =
        () async {
          await _operationTail;
          await _crypto.close();
        }().whenComplete(() {
          if (identical(_closeFuture, closing)) _closeFuture = null;
        });
    _closeFuture = closing;
    return closing;
  }

  Future<E2eeSyncPullPagePreparationDisposition> _materializeReference(
    E2eeAttachmentDownloadReference reference,
    _RemoteStepBudget budget,
    E2eeSyncExecutionBudget? executionBudget,
  ) async {
    while (true) {
      final current = await _commands.read(reference);
      if (current == null) {
        throw StateError('attachment_download_state_missing');
      }
      _requireUsableDownloadState(current);
      if (current.phase == E2eeAttachmentDownloadPhase.ready) {
        return E2eeSyncPullPagePreparationDisposition.ready;
      }

      final claimNow = _utcNow();
      final lease = await _commands.claimDue(
        reference: reference,
        leaseToken: _leaseTokenFactory(),
        leaseOwner: _leaseOwner,
        leaseExpiresAt: claimNow.add(_downloadLeaseDuration),
        now: claimNow,
      );
      if (lease == null) {
        return E2eeSyncPullPagePreparationDisposition.pending;
      }

      late final _DownloadAdvance advanced;
      try {
        advanced = await _advanceLease(lease, budget, executionBudget);
      } catch (error, stackTrace) {
        if (error is E2eeSyncBudgetExhausted ||
            error is E2eeSyncDeadlineExceeded ||
            error is E2eeSyncExecutionCancelled) {
          await _commands.release(lease: lease, now: _utcNow());
          Error.throwWithStackTrace(error, stackTrace);
        }
        final resolution = _classifyDownloadFailure(error, lease.state.phase);
        if (resolution.permanent) {
          await _commands.markPermanentlyFailed(
            lease: lease,
            failureKind: resolution.failureKind,
            now: _utcNow(),
          );
          Error.throwWithStackTrace(error, stackTrace);
        }
        final failureNow = _utcNow();
        await _commands.releaseAfterFailure(
          lease: lease,
          nextAttemptAt: failureNow.add(
            _downloadRetryDelay(lease.state.consecutiveFailureCount),
          ),
          failureKind: resolution.failureKind,
          now: failureNow,
        );
        return E2eeSyncPullPagePreparationDisposition.pending;
      }
      switch (advanced) {
        case _DownloadReady():
          return E2eeSyncPullPagePreparationDisposition.ready;
        case _DownloadBudgetExhausted():
          await _commands.release(lease: lease, now: _utcNow());
          return E2eeSyncPullPagePreparationDisposition.pending;
        case _DownloadProgressed(:final lease):
          final released = await _commands.release(
            lease: lease,
            now: _utcNow(),
          );
          if (!released) {
            return E2eeSyncPullPagePreparationDisposition.pending;
          }
      }
    }
  }

  Future<_DownloadAdvance> _advanceLease(
    E2eeAttachmentDownloadLease lease,
    _RemoteStepBudget budget,
    E2eeSyncExecutionBudget? executionBudget,
  ) async {
    return switch (lease.state.phase) {
      E2eeAttachmentDownloadPhase.manifestPending => _downloadManifest(
        lease,
        budget,
        executionBudget,
      ),
      E2eeAttachmentDownloadPhase.downloading => _downloadNextChunk(
        lease,
        budget,
        executionBudget,
      ),
      E2eeAttachmentDownloadPhase.verifying => _publishPlaintext(lease),
      E2eeAttachmentDownloadPhase.ready => throw StateError(
        'attachment_download_ready_state_claimed',
      ),
      E2eeAttachmentDownloadPhase.dormant => throw StateError(
        'attachment_download_dormant_state_claimed',
      ),
    };
  }

  Future<_DownloadAdvance> _downloadManifest(
    E2eeAttachmentDownloadLease lease,
    _RemoteStepBudget budget,
    E2eeSyncExecutionBudget? executionBudget,
  ) async {
    final cleanupStagingPath = lease.state.cleanupStagingPath;
    if (cleanupStagingPath != null) {
      await _fileStore.deleteStaging(storagePath: cleanupStagingPath);
      final cleaned = await _commands.completeStagingCleanup(
        lease: lease,
        cleanupStagingPath: cleanupStagingPath,
        now: _utcNow(),
      );
      return _DownloadProgressed(cleaned);
    }
    if (!budget.tryConsume()) return const _DownloadBudgetExhausted();
    final reference = lease.state.reference;
    final identity = _cloudIdentity(reference);
    final remote = executionBudget == null
        ? await _transport.getAttachmentManifest(
            token: _token,
            identity: identity,
          )
        : await executionBudget.runNetworkStep(
            attachmentByteReservation:
                cloudSyncMaximumAttachmentManifestCiphertextBytes,
            actualAttachmentBytes: (result) => result.manifestCiphertextBytes,
            operation: (_) => _transport.getAttachmentManifest(
              token: _token,
              identity: identity,
            ),
          );
    _requireMatchingCloudIdentity(identity, remote.identity);
    final manifest = await _crypto.openManifest(
      attachmentId: reference.attachmentId,
      uploadId: reference.uploadId,
      chunkKeyEpoch: reference.chunkKeyEpoch,
      manifestKeyEpoch: reference.manifestKeyEpoch,
      manifestRevision: reference.manifestRevision,
      ciphertext: remote.manifestCiphertext,
    );
    _requireMatchingManifest(reference, remote, manifest);

    final finalPath = await _fileStore.resolveContentStoragePath(
      manifest.contentSha256,
    );
    final candidatePath = lease.state.finalPath;
    if (lease.state.localAssetId != null && candidatePath == finalPath) {
      final candidate = E2eeAttachmentStoredFile(
        storagePath: candidatePath!,
        bytes: manifest.totalPlaintextBytes,
        sha256: manifest.contentSha256,
      );
      if (await _verifyReusableContent(candidate)) {
        await _commands.reuseReadyAssetAfterManifest(
          lease: lease,
          manifest: manifest,
          manifestCiphertext: remote.manifestCiphertext,
          finalPath: finalPath,
          now: _utcNow(),
        );
        return const _DownloadReady();
      }
    }
    final stagingPath = await _fileStore.openDownloadPlaintextStaging(
      identity: identity,
      persistedStoragePath: null,
      confirmedPlaintextBytes: 0,
    );
    final attached = await _commands.attachManifest(
      lease: lease,
      manifest: manifest,
      manifestCiphertext: remote.manifestCiphertext,
      stagingPath: stagingPath,
      finalPath: finalPath,
      now: _utcNow(),
    );
    return _DownloadProgressed(attached);
  }

  Future<bool> _verifyReusableContent(
    E2eeAttachmentStoredFile candidate,
  ) async {
    try {
      await _fileStore.verifyContent(candidate);
      return true;
    } on FileSystemException catch (error) {
      if (error.message != 'e2ee_attachment_file_missing') rethrow;
      developer.log(
        'E2EE 附件完成文件不存在，按新清单重新下载',
        name: 'Kelivo.E2eeAttachmentDownloadCoordinator',
      );
      return false;
    } on FormatException catch (error) {
      if (error.message != 'e2ee_attachment_file_integrity') rethrow;
      developer.log(
        'E2EE 附件完成文件未通过新清单内容校验，重新下载',
        name: 'Kelivo.E2eeAttachmentDownloadCoordinator',
      );
      return false;
    }
  }

  Future<_DownloadAdvance> _downloadNextChunk(
    E2eeAttachmentDownloadLease lease,
    _RemoteStepBudget budget,
    E2eeSyncExecutionBudget? executionBudget,
  ) async {
    var activeLease = lease;
    final state = activeLease.state;
    final descriptor = state.descriptor;
    final manifest = state.manifest;
    final stagingPath = state.stagingPath;
    if (descriptor == null || manifest == null || stagingPath == null) {
      throw StateError('attachment_download_descriptor_missing');
    }
    final identity = _cloudIdentity(state.reference);
    try {
      await _fileStore.openDownloadPlaintextStaging(
        identity: identity,
        persistedStoragePath: stagingPath,
        confirmedPlaintextBytes: state.confirmedPlaintextBytes,
      );
    } on StateError catch (error) {
      if (!_isShorterThanConfirmed(error)) rethrow;
      activeLease = await _restartMissingStaging(activeLease, identity);
      return _DownloadProgressed(activeLease);
    }
    if (!budget.tryConsume()) return const _DownloadBudgetExhausted();

    final chunkIdentity = CloudSyncAttachmentChunkIdentity(
      identity: identity,
      chunkIndex: state.nextChunkIndex,
    );
    final expectedCiphertextBytes =
        descriptor.chunkCiphertextBytes[state.nextChunkIndex];
    final remote = executionBudget == null
        ? await _transport.getAttachmentChunk(
            token: _token,
            chunk: chunkIdentity,
          )
        : await executionBudget.runNetworkStep(
            attachmentByteReservation: expectedCiphertextBytes,
            actualAttachmentBytes: (result) => result.ciphertextBytes,
            operation: (_) => _transport.getAttachmentChunk(
              token: _token,
              chunk: chunkIdentity,
            ),
          );
    _requireMatchingChunk(
      expected: chunkIdentity,
      downloaded: remote,
      expectedCiphertextBytes: expectedCiphertextBytes,
    );

    Uint8List? plaintext;
    try {
      plaintext = await _crypto.openChunk(
        manifest: manifest,
        chunkIndex: state.nextChunkIndex,
        ciphertext: remote.ciphertext,
      );
      await _fileStore.appendDownloadPlaintextChunk(
        identity: identity,
        stagingPath: stagingPath,
        expectedOffset: state.confirmedPlaintextBytes,
        plaintext: plaintext,
      );
      final acknowledged = await _commands.acknowledgeChunk(
        lease: activeLease,
        chunkIndex: state.nextChunkIndex,
        confirmedPlaintextBytes:
            state.confirmedPlaintextBytes + plaintext.length,
        now: _utcNow(),
      );
      return _DownloadProgressed(acknowledged);
    } finally {
      plaintext?.fillRange(0, plaintext.length, 0);
    }
  }

  Future<_DownloadAdvance> _publishPlaintext(
    E2eeAttachmentDownloadLease lease,
  ) async {
    final state = lease.state;
    final descriptor = state.descriptor;
    final stagingPath = state.stagingPath;
    final finalPath = state.finalPath;
    final localAssetId = state.localAssetId;
    if (descriptor == null ||
        stagingPath == null ||
        finalPath == null ||
        localAssetId == null) {
      throw StateError('attachment_download_verification_state_missing');
    }
    final identity = _cloudIdentity(state.reference);
    late final E2eeAttachmentStoredFile stored;
    try {
      stored = await _fileStore.publishDownloadPlaintext(
        identity: identity,
        stagingPath: stagingPath,
        expectedPlaintextBytes: descriptor.totalPlaintextBytes,
        expectedSha256: descriptor.contentSha256,
      );
    } on FileSystemException catch (error) {
      if (!_isMissingStaging(error)) rethrow;
      final restarted = await _restartMissingStaging(lease, identity);
      return _DownloadProgressed(restarted);
    }
    if (stored.storagePath != finalPath ||
        stored.bytes != descriptor.totalPlaintextBytes ||
        !_sameBytes(stored.sha256, descriptor.contentSha256)) {
      throw const FormatException('attachment_download_published_identity');
    }

    await _commands.markReady(
      lease: lease,
      asset: MessageAssetRegistration(
        assetId: localAssetId,
        contentHash: _hex(descriptor.contentSha256),
        path: stored.storagePath,
        byteSize: stored.bytes,
        kind: state.kind.name,
        displayName: descriptor.displayName,
        mediaType: descriptor.mediaType,
        attachmentId: state.attachmentId,
        uploadId: state.uploadId,
        chunkKeyEpoch: state.chunkKeyEpoch,
        manifestKeyEpoch: state.manifestKeyEpoch,
        manifestRevision: state.manifestRevision,
      ),
      now: _utcNow(),
    );
    return const _DownloadReady();
  }

  Future<E2eeAttachmentDownloadLease> _restartMissingStaging(
    E2eeAttachmentDownloadLease lease,
    CloudSyncAttachmentIdentity identity,
  ) async {
    final stalePath = lease.state.stagingPath;
    if (stalePath == null) {
      throw StateError('attachment_download_staging_path_missing');
    }
    await _fileStore.deleteStaging(storagePath: stalePath);
    final rebuiltPath = await _fileStore.openDownloadPlaintextStaging(
      identity: identity,
      persistedStoragePath: null,
      confirmedPlaintextBytes: 0,
    );
    return _commands.restartStaging(
      lease: lease,
      stagingPath: rebuiltPath,
      now: _utcNow(),
    );
  }

  Future<T> _runWhileOpen<T>(Future<T> Function() operation) {
    try {
      _requireAcceptingOperations();
    } catch (error, stackTrace) {
      return Future<T>.error(error, stackTrace);
    }
    final previous = _operationTail;
    final completion = Completer<void>();
    _operationTail = completion.future;
    return () async {
      await previous;
      try {
        return await operation();
      } finally {
        completion.complete();
      }
    }();
  }

  void _requireAcceptingOperations() {
    if (!_acceptingOperations) {
      throw StateError('E2EE 附件下载协调器已经关闭');
    }
  }
}

final class _RemoteStepBudget {
  _RemoteStepBudget(this._remaining);

  int _remaining;

  bool tryConsume() {
    if (_remaining == 0) return false;
    _remaining--;
    return true;
  }
}

sealed class _DownloadAdvance {
  const _DownloadAdvance();
}

final class _DownloadReady extends _DownloadAdvance {
  const _DownloadReady();
}

final class _DownloadBudgetExhausted extends _DownloadAdvance {
  const _DownloadBudgetExhausted();
}

final class _DownloadProgressed extends _DownloadAdvance {
  const _DownloadProgressed(this.lease);

  final E2eeAttachmentDownloadLease lease;
}

final class _DownloadFailureResolution {
  const _DownloadFailureResolution({
    required this.permanent,
    required this.failureKind,
  });

  final bool permanent;
  final String failureKind;
}

List<E2eeAttachmentDownloadReference> _uniqueAttachmentReferences(
  List<E2eeSyncPulledChange> changes,
) {
  final byAttachmentId = <String, E2eeAttachmentDownloadReference>{};
  final uploadOwners = <String, String>{};
  for (final change in changes) {
    if (change is! E2eeSyncPulledValueChange) continue;
    for (final reference in _messageAttachmentReferences(change)) {
      final existing = byAttachmentId[reference.attachmentId];
      if (existing != null && !_sameReference(existing, reference)) {
        throw const FormatException('message_attachment_identity_conflict');
      }
      final uploadOwner = uploadOwners[reference.uploadId];
      if (uploadOwner != null && uploadOwner != reference.attachmentId) {
        throw const FormatException('message_attachment_upload_conflict');
      }
      byAttachmentId[reference.attachmentId] = reference;
      uploadOwners[reference.uploadId] = reference.attachmentId;
    }
  }
  return List<E2eeAttachmentDownloadReference>.unmodifiable(
    byAttachmentId.values,
  );
}

List<E2eeAttachmentDownloadReference> _messageAttachmentReferences(
  E2eeSyncPulledValueChange change,
) {
  if (change.state.entityKey.entityType != E2eeSyncChatRecordTypes.message) {
    return const <E2eeAttachmentDownloadReference>[];
  }
  final rawAttachments = change.payload['attachments'];
  if (rawAttachments is! List<Object?>) {
    throw const FormatException('message.attachments 必须为数组');
  }
  if (rawAttachments.length > e2eeSyncMaximumMessageAttachmentCount) {
    throw const FormatException('message.attachments 数量超出协议上限');
  }
  final references = <E2eeAttachmentDownloadReference>[];
  for (var index = 0; index < rawAttachments.length; index++) {
    final raw = rawAttachments[index];
    if (raw is! Map<String, Object?>) {
      throw FormatException('message.attachments[$index] 必须为对象');
    }
    final attachmentId = raw['attachmentId'];
    final uploadId = raw['uploadId'];
    final chunkKeyEpoch = raw['chunkKeyEpoch'];
    final manifestKeyEpoch = raw['manifestKeyEpoch'];
    final manifestRevision = raw['manifestRevision'];
    final kind = raw['kind'];
    final order = raw['order'];
    if (attachmentId is! String ||
        uploadId is! String ||
        chunkKeyEpoch is! int ||
        manifestKeyEpoch is! int ||
        manifestRevision is! int ||
        kind is! String ||
        order != index) {
      throw FormatException('message.attachments[$index] 身份字段无效');
    }
    references.add(
      E2eeAttachmentDownloadReference(
        attachmentId: attachmentId,
        uploadId: uploadId,
        chunkKeyEpoch: chunkKeyEpoch,
        manifestKeyEpoch: manifestKeyEpoch,
        manifestRevision: manifestRevision,
        kind: switch (kind) {
          'image' => E2eeAttachmentKind.image,
          'file' => E2eeAttachmentKind.file,
          _ => throw FormatException('message.attachments[$index].kind 无效'),
        },
      ),
    );
  }
  return List<E2eeAttachmentDownloadReference>.unmodifiable(references);
}

MessageAssetRegistration _registrationFromReadyState(
  E2eeAttachmentDownloadState state,
) {
  final descriptor = state.descriptor;
  final localAssetId = state.localAssetId;
  final finalPath = state.finalPath;
  if (state.phase != E2eeAttachmentDownloadPhase.ready ||
      descriptor == null ||
      localAssetId == null ||
      finalPath == null) {
    throw StateError('sync_message_attachment_ready_state_invalid');
  }
  return MessageAssetRegistration(
    assetId: localAssetId,
    contentHash: _hex(descriptor.contentSha256),
    path: finalPath,
    byteSize: descriptor.totalPlaintextBytes,
    kind: state.kind.name,
    displayName: descriptor.displayName,
    mediaType: descriptor.mediaType,
    attachmentId: state.attachmentId,
    uploadId: state.uploadId,
    chunkKeyEpoch: state.chunkKeyEpoch,
    manifestKeyEpoch: state.manifestKeyEpoch,
    manifestRevision: state.manifestRevision,
  );
}

void _requireUsableDownloadState(E2eeAttachmentDownloadState state) {
  final terminalFailure = state.terminalFailureKind;
  if (terminalFailure != null) {
    throw StateError('attachment_download_terminal:$terminalFailure');
  }
}

CloudSyncAttachmentIdentity _cloudIdentity(
  E2eeAttachmentDownloadReference reference,
) => CloudSyncAttachmentIdentity(
  attachmentId: reference.attachmentId,
  uploadId: reference.uploadId,
  chunkKeyEpoch: reference.chunkKeyEpoch,
  manifestKeyEpoch: reference.manifestKeyEpoch,
  manifestRevision: reference.manifestRevision,
);

void _requireMatchingCloudIdentity(
  CloudSyncAttachmentIdentity expected,
  CloudSyncAttachmentIdentity actual,
) {
  if (expected.attachmentId != actual.attachmentId ||
      expected.uploadId != actual.uploadId ||
      expected.chunkKeyEpoch != actual.chunkKeyEpoch ||
      expected.manifestKeyEpoch != actual.manifestKeyEpoch ||
      expected.manifestRevision != actual.manifestRevision) {
    throw const FormatException('attachment_download_remote_identity');
  }
}

void _requireMatchingManifest(
  E2eeAttachmentDownloadReference reference,
  CloudSyncAttachmentManifest remote,
  E2eeAttachmentManifest manifest,
) {
  if (manifest.attachmentId != reference.attachmentId ||
      manifest.uploadId != reference.uploadId ||
      manifest.chunkKeyEpoch != reference.chunkKeyEpoch ||
      manifest.manifestKeyEpoch != reference.manifestKeyEpoch ||
      manifest.manifestRevision != reference.manifestRevision ||
      manifest.kind != reference.kind ||
      remote.chunkCount != manifest.chunkCiphertextBytes.length ||
      remote.totalCiphertextBytes != manifest.totalCiphertextBytes) {
    throw const FormatException('attachment_download_manifest_identity');
  }
  for (var index = 0; index < remote.chunks.length; index++) {
    final chunk = remote.chunks[index];
    if (chunk.chunkIndex != index ||
        chunk.ciphertextBytes != manifest.chunkCiphertextBytes[index]) {
      throw const FormatException('attachment_download_manifest_layout');
    }
  }
}

void _requireMatchingChunk({
  required CloudSyncAttachmentChunkIdentity expected,
  required CloudSyncAttachmentChunk downloaded,
  required int expectedCiphertextBytes,
}) {
  final actual = downloaded.chunk;
  _requireMatchingCloudIdentity(expected.identity, actual.identity);
  if (actual.chunkIndex != expected.chunkIndex ||
      downloaded.ciphertextBytes != expectedCiphertextBytes ||
      downloaded.ciphertext.length != expectedCiphertextBytes) {
    throw const FormatException('attachment_download_chunk_identity');
  }
}

_DownloadFailureResolution _classifyDownloadFailure(
  Object error,
  E2eeAttachmentDownloadPhase phase,
) {
  if (error is CloudSyncException) {
    return _DownloadFailureResolution(
      permanent: !error.retryable,
      failureKind: 'remote-${error.kind.name}',
    );
  }
  if (error is FileSystemException || error is TimeoutException) {
    return _DownloadFailureResolution(
      permanent: false,
      failureKind: 'local-io-${phase.wireValue}',
    );
  }
  if (error is FormatException ||
      error is ArgumentError ||
      error is KelivoSecureCoreException) {
    return _DownloadFailureResolution(
      permanent: true,
      failureKind: 'invalid-${phase.wireValue}',
    );
  }
  return _DownloadFailureResolution(
    permanent: true,
    failureKind: 'invariant-${phase.wireValue}',
  );
}

Duration _downloadRetryDelay(int consecutiveFailureCount) {
  var delay = _initialDownloadRetryDelay;
  for (var index = 0; index < consecutiveFailureCount; index++) {
    final doubled = delay * 2;
    delay = doubled > _maximumDownloadRetryDelay
        ? _maximumDownloadRetryDelay
        : doubled;
  }
  return delay;
}

bool _sameReference(
  E2eeAttachmentDownloadReference left,
  E2eeAttachmentDownloadReference right,
) =>
    left.attachmentId == right.attachmentId &&
    left.uploadId == right.uploadId &&
    left.chunkKeyEpoch == right.chunkKeyEpoch &&
    left.manifestKeyEpoch == right.manifestKeyEpoch &&
    left.manifestRevision == right.manifestRevision &&
    left.kind == right.kind;

bool _isShorterThanConfirmed(StateError error) =>
    error.message == 'e2ee_attachment_staging_shorter_than_confirmed';

bool _isMissingStaging(FileSystemException error) =>
    error.message == 'e2ee_attachment_file_missing';

bool _sameBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

String _hex(Uint8List bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

String _defaultLeaseToken() => const Uuid().v4();

DateTime _defaultUtcNow() => DateTime.now().toUtc();
