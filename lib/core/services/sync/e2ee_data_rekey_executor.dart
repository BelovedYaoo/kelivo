import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../database/chat_database_repository.dart';
import '../workspace/e2ee_data_rekey_stage_store.dart';
import 'cloud_sync_client.dart';
import 'cloud_sync_types.dart';
import 'e2ee_data_rekey_artifact_codec.dart';
import 'e2ee_data_rekey_wire.dart';

const _dataRekeyPageSize = 10;
const _dataRekeyMaximumArtifactCount = 0x7fffffff;
const _leaseRenewalMargin = Duration(seconds: 30);

final _dataRekeyLoginNamePattern = RegExp(r'^[a-z0-9][a-z0-9._-]*$');
final _dataRekeyUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

final class E2eeDataRekeyExecutionContext {
  factory E2eeDataRekeyExecutionContext({
    required String baseUrl,
    required String loginName,
    required String userId,
    required String issuerDeviceId,
    required int membershipGeneration,
    required Uint8List membershipManifestDigest,
  }) {
    final normalizedLoginName = loginName.trim().toLowerCase();
    if (normalizedLoginName.length < 3 ||
        normalizedLoginName.length > 64 ||
        !_dataRekeyLoginNamePattern.hasMatch(normalizedLoginName)) {
      throw const FormatException('data-rekey 登录名无效');
    }
    if (membershipGeneration <= 0 ||
        membershipGeneration > _dataRekeyMaximumArtifactCount) {
      throw const FormatException('data-rekey 成员代次无效');
    }
    if (membershipManifestDigest.length != e2eeDataRekeyDigestBytes) {
      throw const FormatException('data-rekey 成员摘要长度无效');
    }
    return E2eeDataRekeyExecutionContext._(
      normalizedBaseUrl: normalizeCloudSyncBaseUrl(baseUrl),
      normalizedLoginName: normalizedLoginName,
      userId: _requireDataRekeyUuid(userId, 'userId'),
      issuerDeviceId: _requireDataRekeyUuid(issuerDeviceId, 'issuerDeviceId'),
      membershipGeneration: membershipGeneration,
      membershipManifestDigest: Uint8List.fromList(
        membershipManifestDigest,
      ).asUnmodifiableView(),
    );
  }

  const E2eeDataRekeyExecutionContext._({
    required this.normalizedBaseUrl,
    required this.normalizedLoginName,
    required this.userId,
    required this.issuerDeviceId,
    required this.membershipGeneration,
    required this.membershipManifestDigest,
  });

  final String normalizedBaseUrl;
  final String normalizedLoginName;
  final String userId;
  final String issuerDeviceId;
  final int membershipGeneration;
  final Uint8List membershipManifestDigest;
}

final class E2eeDataRekeyRewrappedRecord {
  E2eeDataRekeyRewrappedRecord({
    required String sourceRecordId,
    required this.sourceRevision,
    required String targetRecordId,
    required this.targetKeyEpoch,
    required Uint8List ciphertext,
  }) : sourceRecordId = _requireDataRekeyUuid(sourceRecordId, 'sourceRecordId'),
       targetRecordId = _requireDataRekeyUuid(targetRecordId, 'targetRecordId'),
       ciphertext = _copyNonEmptyDataRekeyBytes(ciphertext, 'ciphertext');

  final String sourceRecordId;
  final int sourceRevision;
  final String targetRecordId;
  final int targetKeyEpoch;
  final Uint8List ciphertext;
}

final class E2eeDataRekeyRewrappedAttachmentManifest {
  E2eeDataRekeyRewrappedAttachmentManifest({
    required String attachmentId,
    required String uploadId,
    required this.chunkKeyEpoch,
    required this.manifestKeyEpoch,
    required this.manifestRevision,
    required Uint8List manifestCiphertext,
  }) : attachmentId = _requireDataRekeyUuid(attachmentId, 'attachmentId'),
       uploadId = _requireDataRekeyUuid(uploadId, 'uploadId'),
       manifestCiphertext = _copyNonEmptyDataRekeyBytes(
         manifestCiphertext,
         'manifestCiphertext',
       );

  final String attachmentId;
  final String uploadId;
  final int chunkKeyEpoch;
  final int manifestKeyEpoch;
  final int manifestRevision;
  final Uint8List manifestCiphertext;
}

abstract interface class E2eeDataRekeyCryptography {
  String get issuerDeviceId;

  int get targetKeyEpoch;

  Future<E2eeDataRekeyRewrappedRecord> rewrapRecord(
    CloudSyncDataRekeySourceRecord source,
  );

  Future<E2eeDataRekeyRewrappedAttachmentManifest> rewrapAttachmentManifest(
    CloudSyncDataRekeySourceAttachment source,
  );

  Future<Uint8List> signCompletionProof(Uint8List proofFrame);
}

final class E2eeDataRekeyFinalizedExecution {
  const E2eeDataRekeyFinalizedExecution._({
    required this.result,
    required this.operationId,
    required this.leaseToken,
    required this.leaseVersion,
    required this.artifactMaximumCount,
    required this.userId,
    required this.issuerDeviceId,
  });

  final CloudSyncDataRekeyFinalizeResult result;
  final String operationId;
  final String leaseToken;
  final int leaseVersion;
  final int artifactMaximumCount;
  final String userId;
  final String issuerDeviceId;
}

final class E2eeDataRekeyReadyConfirmation {
  const E2eeDataRekeyReadyConfirmation._(this.execution);

  final E2eeDataRekeyFinalizedExecution execution;

  CloudSyncDataRekeyCompletion get completion => execution.result.completion;
}

final class E2eeDataRekeyExecutor {
  factory E2eeDataRekeyExecutor({
    required CloudSyncDataRekeyTransport transport,
    required E2eeDataRekeyCommands journal,
    required E2eeDataRekeyStageStore stageStore,
    required E2eeDataRekeyCryptography cryptography,
    DateTime Function()? clock,
  }) {
    return E2eeDataRekeyExecutor._(
      transport,
      journal,
      stageStore,
      cryptography,
      clock ?? _utcNow,
    );
  }

  E2eeDataRekeyExecutor._(
    this._transport,
    this._journal,
    this._stageStore,
    this._cryptography,
    this._clock,
  );

  final CloudSyncDataRekeyTransport _transport;
  final E2eeDataRekeyCommands _journal;
  final E2eeDataRekeyStageStore _stageStore;
  final E2eeDataRekeyCryptography _cryptography;
  final DateTime Function() _clock;

  bool _running = false;

  Future<E2eeDataRekeyFinalizedExecution?> execute(
    E2eeDataRekeyExecutionContext context,
  ) async {
    if (_running) throw StateError('data_rekey_executor_busy');
    if (_cryptography.issuerDeviceId != context.issuerDeviceId) {
      throw const FormatException('data-rekey 签名设备与执行上下文不匹配');
    }
    _running = true;
    try {
      final serverState = await _transport.getDataRekeyState();
      final journalState = await _journal.readActive();
      if (serverState is CloudSyncDataRekeyReadyState) {
        if (journalState == null) return null;
        _requireContextMatchesJournal(context, journalState.binding);
        _requireCryptographyMatchesBinding(_cryptography, journalState.binding);
        _requireReadyStateMatchesJournal(serverState, journalState.binding);
        return _resumeReadyFinalize(context, journalState);
      }
      return _executePending(
        context,
        serverState as CloudSyncDataRekeyPendingState,
      );
    } finally {
      _running = false;
    }
  }

  Future<E2eeDataRekeyReadyConfirmation> confirmReady({
    required E2eeDataRekeyExecutionContext context,
    required E2eeDataRekeyFinalizedExecution execution,
  }) async {
    if (_running) throw StateError('data_rekey_executor_busy');
    _requireExecutionMatchesContext(execution, context);
    _running = true;
    try {
      final journalState = await _journal.readActive();
      if (journalState == null ||
          journalState.phase != E2eeDataRekeyJournalPhase.finalizing ||
          journalState.leaseToken != execution.leaseToken ||
          journalState.leaseVersion != execution.leaseVersion ||
          journalState.binding.operationId != execution.operationId) {
        throw StateError('data_rekey_ready_confirmation_identity_mismatch');
      }
      _requireContextMatchesJournal(context, journalState.binding);
      final state = await _transport.getDataRekeyState();
      if (state is! CloudSyncDataRekeyReadyState) {
        throw StateError('data_rekey_ready_confirmation_pending');
      }
      _requireReadyStateMatchesJournal(state, journalState.binding);
      final completion = state.lastCompletion;
      if (completion == null) {
        throw const FormatException('data-rekey ready 状态缺少完成证明');
      }
      final artifact = await _readFinalizeArtifact(
        context: context,
        binding: _artifactBinding(journalState.binding),
        journalState: journalState,
      );
      if (artifact == null) {
        throw StateError('data_rekey_finalize_artifact_missing');
      }
      _verifyFinalizedCompletion(
        userId: context.userId,
        request: artifact.request,
        completion: completion,
      );
      return E2eeDataRekeyReadyConfirmation._(execution);
    } finally {
      _running = false;
    }
  }

  Future<void> acknowledgeLocalCommit({
    required E2eeDataRekeyExecutionContext context,
    required E2eeDataRekeyFinalizedExecution execution,
  }) async {
    _requireExecutionMatchesContext(execution, context);
    final current = await _journal.readActive();
    if (current != null) {
      if (current.binding.operationId != execution.operationId ||
          current.leaseToken != execution.leaseToken ||
          current.leaseVersion != execution.leaseVersion ||
          current.phase != E2eeDataRekeyJournalPhase.finalizing) {
        throw StateError('data_rekey_local_commit_identity_mismatch');
      }
      await _journal.complete(
        operationId: execution.operationId,
        leaseToken: execution.leaseToken,
        leaseVersion: execution.leaseVersion,
      );
    }
    // 日志先完成可避免崩溃后丢失唯一可重放的 finalize 请求；残留缓存只造成可清理的磁盘占用。
    await _stageStore.clearOperation(
      normalizedBaseUrl: context.normalizedBaseUrl,
      normalizedLoginName: context.normalizedLoginName,
      operationId: execution.operationId,
      maximumCount: execution.artifactMaximumCount,
    );
  }

  Future<E2eeDataRekeyFinalizedExecution> _executePending(
    E2eeDataRekeyExecutionContext context,
    CloudSyncDataRekeyPendingState pending,
  ) async {
    final binding = _operationBinding(context, pending);
    _requireCryptographyMatchesBinding(_cryptography, binding);
    var journalState = await _journal.ensureClaimIntent(
      binding: binding,
      now: _now(),
    );
    final artifactMaximumCount = _artifactMaximumCount(binding);
    final lease = await _ensureLease(
      context: context,
      binding: binding,
      journalState: journalState,
      serverLease: pending.lease,
      checkServerLease: true,
    );
    journalState = lease.journalState;

    for (;;) {
      final artifactBinding = _artifactBinding(binding);
      final finalizeArtifact = await _readFinalizeArtifact(
        context: context,
        binding: artifactBinding,
        journalState: journalState,
      );
      if (finalizeArtifact != null) {
        await _advancePhase(journalState, E2eeDataRekeyJournalPhase.finalizing);
        try {
          return await _finalizePending(
            context: context,
            binding: binding,
            journalState: journalState,
            artifact: finalizeArtifact,
            artifactMaximumCount: artifactMaximumCount,
          );
        } on _DataRekeyLeaseGenerationChanged catch (change) {
          journalState = change.journalState;
          continue;
        }
      }

      await _advancePhase(journalState, E2eeDataRekeyJournalPhase.scanning);
      final scan = await _scanSource(context, binding, journalState);
      journalState = scan.journalState;
      await _advancePhase(journalState, E2eeDataRekeyJournalPhase.staging);
      try {
        final staging = await _stageSource(
          context: context,
          binding: binding,
          artifactBinding: artifactBinding,
          journalState: journalState,
          artifactMaximumCount: artifactMaximumCount,
        );
        journalState = staging.journalState;
        final artifact = await _loadOrCreateFinalizeArtifact(
          context: context,
          binding: binding,
          artifactBinding: artifactBinding,
          journalState: journalState,
          sourceSnapshot: scan.snapshot,
          stagedCiphertextSetDigest: staging.digest,
          artifactMaximumCount: artifactMaximumCount,
        );
        await _advancePhase(journalState, E2eeDataRekeyJournalPhase.finalizing);
        return await _finalizePending(
          context: context,
          binding: binding,
          journalState: journalState,
          artifact: artifact,
          artifactMaximumCount: artifactMaximumCount,
        );
      } on _DataRekeyLeaseGenerationChanged catch (change) {
        journalState = change.journalState;
      }
    }
  }

  Future<E2eeDataRekeyFinalizedExecution> _resumeReadyFinalize(
    E2eeDataRekeyExecutionContext context,
    E2eeDataRekeyJournalState journalState,
  ) async {
    if (journalState.phase != E2eeDataRekeyJournalPhase.finalizing ||
        journalState.leaseVersion == null) {
      throw StateError('data_rekey_ready_without_finalize_checkpoint');
    }
    final artifact = await _readFinalizeArtifact(
      context: context,
      binding: _artifactBinding(journalState.binding),
      journalState: journalState,
    );
    if (artifact == null) {
      throw StateError('data_rekey_finalize_artifact_missing');
    }
    final outcome = await _transport.finalizeDataRekey(artifact.request);
    if (outcome is! CloudSyncDataRekeyFinalizeResult) {
      throw StateError('data_rekey_ready_finalize_not_completed');
    }
    _verifyFinalizedResult(
      userId: context.userId,
      request: artifact.request,
      result: outcome,
    );
    return _finalizedExecution(
      context: context,
      binding: journalState.binding,
      journalState: journalState,
      result: outcome,
    );
  }

  Future<_DataRekeyLeaseState> _ensureLease({
    required E2eeDataRekeyExecutionContext context,
    required E2eeDataRekeyOperationBinding binding,
    required E2eeDataRekeyJournalState journalState,
    CloudSyncDataRekeyLease? serverLease,
    required bool checkServerLease,
  }) async {
    final now = _now();
    final localExpiry = journalState.leaseExpiresAt;
    final localVersion = journalState.leaseVersion;
    final serverDisagrees =
        serverLease != null &&
        (!serverLease.ownedByCurrentDevice ||
            serverLease.leaseVersion != localVersion);
    final needsClaim =
        localVersion == null ||
        localExpiry == null ||
        (checkServerLease && (serverLease == null || serverDisagrees)) ||
        !localExpiry.isAfter(now.add(_leaseRenewalMargin));
    if (!needsClaim) {
      return _DataRekeyLeaseState(
        journalState: journalState,
        generationChanged: false,
      );
    }

    final mutationId = localVersion == null
        ? journalState.leaseMutationId
        : _deriveDataRekeyMutationId(
            'kelivo.data-rekey.lease-renewal.v1',
            <String>[
              binding.operationId,
              journalState.leaseToken,
              '$localVersion',
              localExpiry!.toIso8601String(),
            ],
          );
    final request = CloudSyncDataRekeyLeaseClaimRequest(
      operation: _operationScope(binding),
      leaseToken: journalState.leaseToken,
      mutationId: mutationId,
    );
    final claim = await _transport.claimDataRekeyLease(request);
    _requireClaimMatchesBinding(claim, binding);
    final generationChanged =
        localVersion != null && claim.activeLease.leaseVersion != localVersion;
    if (generationChanged) {
      await _stageStore.clearOperation(
        normalizedBaseUrl: context.normalizedBaseUrl,
        normalizedLoginName: context.normalizedLoginName,
        operationId: binding.operationId,
        maximumCount: _artifactMaximumCount(binding),
      );
    }
    final recorded = await _journal.recordLeaseClaim(
      operationId: binding.operationId,
      leaseToken: journalState.leaseToken,
      leaseVersion: claim.activeLease.leaseVersion,
      leaseExpiresAt: claim.leaseExpiresAt,
      now: _now(),
    );
    return _DataRekeyLeaseState(
      journalState: recorded,
      generationChanged: generationChanged,
    );
  }

  Future<_DataRekeyLeaseState> _ensureLeaseForWork({
    required E2eeDataRekeyExecutionContext context,
    required E2eeDataRekeyOperationBinding binding,
    required E2eeDataRekeyJournalState journalState,
  }) {
    return _ensureLease(
      context: context,
      binding: binding,
      journalState: journalState,
      checkServerLease: false,
    );
  }

  Future<_DataRekeyScanResult> _scanSource(
    E2eeDataRekeyExecutionContext context,
    E2eeDataRekeyOperationBinding binding,
    E2eeDataRekeyJournalState initialJournalState,
  ) async {
    final accumulator = E2eeDataRekeySourceSnapshotAccumulator(
      E2eeDataRekeySourceHeaderFields(
        userId: binding.userId,
        operationId: binding.operationId,
        sourceDataGeneration: binding.sourceDataGeneration,
        sourceKeyEpoch: binding.sourceKeyEpoch,
        expectedRecordCount: binding.sourceRecordCount,
        expectedAttachmentCount: binding.sourceAttachmentCount,
        expectedMaximumChangeSeq: binding.sourceMaximumChangeSeq,
      ),
    );
    var journalState = initialJournalState;
    String? afterRecordId;
    do {
      final lease = await _ensureLeaseForWork(
        context: context,
        binding: binding,
        journalState: journalState,
      );
      journalState = lease.journalState;
      final request = CloudSyncDataRekeySourceRecordListRequest(
        activeLease: _activeLease(journalState),
        afterRecordId: afterRecordId,
        limit: _dataRekeyPageSize,
      );
      final page = await _transport.listDataRekeySourceRecords(request);
      for (final record in page.records) {
        accumulator.addRecord(_sourceRecordDigest(record));
      }
      afterRecordId = page.nextAfterRecordId;
      if (!page.hasMore) break;
    } while (true);

    CloudSyncDataRekeyAttachmentCursor? afterAttachment;
    do {
      final lease = await _ensureLeaseForWork(
        context: context,
        binding: binding,
        journalState: journalState,
      );
      journalState = lease.journalState;
      final request = CloudSyncDataRekeySourceAttachmentListRequest(
        activeLease: _activeLease(journalState),
        afterCursor: afterAttachment,
        limit: _dataRekeyPageSize,
      );
      final page = await _transport.listDataRekeySourceAttachments(request);
      for (final attachment in page.attachments) {
        accumulator.addAttachment(_sourceAttachmentDigest(attachment));
      }
      afterAttachment = page.nextCursor;
      if (!page.hasMore) break;
    } while (true);

    final snapshot = accumulator.finish();
    _requireSnapshotMatchesBinding(snapshot, binding);
    return _DataRekeyScanResult(snapshot: snapshot, journalState: journalState);
  }

  Future<_DataRekeyStagingResult> _stageSource({
    required E2eeDataRekeyExecutionContext context,
    required E2eeDataRekeyOperationBinding binding,
    required E2eeDataRekeyArtifactBinding artifactBinding,
    required E2eeDataRekeyJournalState journalState,
    required int artifactMaximumCount,
  }) async {
    final accumulator = E2eeDataRekeyStagedCiphertextSetAccumulator(
      expectedRecordCount: binding.sourceRecordCount,
      expectedAttachmentCount: binding.sourceAttachmentCount,
    );
    String? afterRecordId;
    do {
      final lease = await _ensureLeaseForWork(
        context: context,
        binding: binding,
        journalState: journalState,
      );
      journalState = lease.journalState;
      if (lease.generationChanged) {
        throw _DataRekeyLeaseGenerationChanged(journalState);
      }
      final request = CloudSyncDataRekeySourceRecordListRequest(
        activeLease: _activeLease(journalState),
        afterRecordId: afterRecordId,
        limit: _dataRekeyPageSize,
      );
      final page = await _transport.listDataRekeySourceRecords(request);
      for (final source in page.records) {
        final refreshed = await _ensureLeaseForWork(
          context: context,
          binding: binding,
          journalState: journalState,
        );
        journalState = refreshed.journalState;
        if (refreshed.generationChanged) {
          throw _DataRekeyLeaseGenerationChanged(journalState);
        }
        accumulator.addRecord(
          await _stageRecord(
            context: context,
            binding: binding,
            artifactBinding: artifactBinding,
            journalState: journalState,
            source: source,
            artifactMaximumCount: artifactMaximumCount,
          ),
        );
      }
      afterRecordId = page.nextAfterRecordId;
      if (!page.hasMore) break;
    } while (true);

    CloudSyncDataRekeyAttachmentCursor? afterAttachment;
    do {
      final lease = await _ensureLeaseForWork(
        context: context,
        binding: binding,
        journalState: journalState,
      );
      journalState = lease.journalState;
      if (lease.generationChanged) {
        throw _DataRekeyLeaseGenerationChanged(journalState);
      }
      final request = CloudSyncDataRekeySourceAttachmentListRequest(
        activeLease: _activeLease(journalState),
        afterCursor: afterAttachment,
        limit: _dataRekeyPageSize,
      );
      final page = await _transport.listDataRekeySourceAttachments(request);
      for (final source in page.attachments) {
        final refreshed = await _ensureLeaseForWork(
          context: context,
          binding: binding,
          journalState: journalState,
        );
        journalState = refreshed.journalState;
        if (refreshed.generationChanged) {
          throw _DataRekeyLeaseGenerationChanged(journalState);
        }
        accumulator.addAttachment(
          await _stageAttachment(
            context: context,
            binding: binding,
            artifactBinding: artifactBinding,
            journalState: journalState,
            source: source,
            artifactMaximumCount: artifactMaximumCount,
          ),
        );
      }
      afterAttachment = page.nextCursor;
      if (!page.hasMore) break;
    } while (true);
    return _DataRekeyStagingResult(
      digest: accumulator.finish(),
      journalState: journalState,
    );
  }

  Future<E2eeDataRekeyStagedRecordDigestItem> _stageRecord({
    required E2eeDataRekeyExecutionContext context,
    required E2eeDataRekeyOperationBinding binding,
    required E2eeDataRekeyArtifactBinding artifactBinding,
    required E2eeDataRekeyJournalState journalState,
    required CloudSyncDataRekeySourceRecord source,
    required int artifactMaximumCount,
  }) async {
    final artifactId = _deriveDataRekeyMutationId(
      'kelivo.data-rekey.record-stage.v1',
      <String>[
        binding.operationId,
        '${journalState.leaseVersion}',
        source.recordId,
      ],
    );
    final snapshot = await _stageStore.readArtifact(
      normalizedBaseUrl: context.normalizedBaseUrl,
      normalizedLoginName: context.normalizedLoginName,
      operationId: binding.operationId,
      artifactId: artifactId,
    );
    if (snapshot?.state == E2eeDataRekeyStageArtifactState.confirmed) {
      final confirmed = E2eeDataRekeyStageArtifact.decode(
        snapshot!.envelope,
        expectedBinding: artifactBinding,
      );
      if (confirmed is! E2eeDataRekeyConfirmedRecordArtifact) {
        throw const FormatException('data-rekey 记录确认工件类型无效');
      }
      _requireRecordConfirmationMatches(confirmed, source, journalState);
      return confirmed.digestItem;
    }

    final E2eeDataRekeyPendingRecordArtifact pending;
    if (snapshot != null) {
      final restored = E2eeDataRekeyStageArtifact.decode(
        snapshot.envelope,
        expectedBinding: artifactBinding,
      );
      if (restored is! E2eeDataRekeyPendingRecordArtifact) {
        throw const FormatException('data-rekey 记录请求工件类型无效');
      }
      _requireRecordRequestMatches(restored, source, journalState);
      pending = restored;
    } else {
      final rewrapped = await _cryptography.rewrapRecord(source);
      _requireRewrappedRecordMatches(rewrapped, source, binding);
      pending = E2eeDataRekeyPendingRecordArtifact(
        binding: artifactBinding,
        activeLease: _activeLease(journalState),
        mutationId: artifactId,
        sourceRecordId: source.recordId,
        targetRecordId: rewrapped.targetRecordId,
        sourceRevision: source.revision,
        ciphertext: rewrapped.ciphertext,
      );
      await _stageStore.writePendingArtifact(
        normalizedBaseUrl: context.normalizedBaseUrl,
        normalizedLoginName: context.normalizedLoginName,
        operationId: binding.operationId,
        artifactId: artifactId,
        maximumCount: artifactMaximumCount,
        envelope: pending.encode(),
      );
    }
    final requestEnvelope = pending.encode();
    final receipt = await _transport.stageDataRekeyRecord(pending.request);
    final confirmed = pending.confirm(receipt);
    await _stageStore.confirmArtifact(
      normalizedBaseUrl: context.normalizedBaseUrl,
      normalizedLoginName: context.normalizedLoginName,
      operationId: binding.operationId,
      artifactId: artifactId,
      expectedRequestDigest: _sha256Bytes(requestEnvelope),
      confirmedEnvelope: confirmed.encode(),
    );
    return confirmed.digestItem;
  }

  Future<E2eeDataRekeyStagedAttachmentDigestItem> _stageAttachment({
    required E2eeDataRekeyExecutionContext context,
    required E2eeDataRekeyOperationBinding binding,
    required E2eeDataRekeyArtifactBinding artifactBinding,
    required E2eeDataRekeyJournalState journalState,
    required CloudSyncDataRekeySourceAttachment source,
    required int artifactMaximumCount,
  }) async {
    final artifactId = _deriveDataRekeyMutationId(
      'kelivo.data-rekey.attachment-stage.v1',
      <String>[
        binding.operationId,
        '${journalState.leaseVersion}',
        source.attachmentId,
        source.uploadId,
      ],
    );
    final snapshot = await _stageStore.readArtifact(
      normalizedBaseUrl: context.normalizedBaseUrl,
      normalizedLoginName: context.normalizedLoginName,
      operationId: binding.operationId,
      artifactId: artifactId,
    );
    if (snapshot?.state == E2eeDataRekeyStageArtifactState.confirmed) {
      final confirmed = E2eeDataRekeyStageArtifact.decode(
        snapshot!.envelope,
        expectedBinding: artifactBinding,
      );
      if (confirmed is! E2eeDataRekeyConfirmedAttachmentArtifact) {
        throw const FormatException('data-rekey 附件确认工件类型无效');
      }
      _requireAttachmentConfirmationMatches(confirmed, source, journalState);
      return confirmed.digestItem;
    }

    final E2eeDataRekeyPendingAttachmentArtifact pending;
    if (snapshot != null) {
      final restored = E2eeDataRekeyStageArtifact.decode(
        snapshot.envelope,
        expectedBinding: artifactBinding,
      );
      if (restored is! E2eeDataRekeyPendingAttachmentArtifact) {
        throw const FormatException('data-rekey 附件请求工件类型无效');
      }
      _requireAttachmentRequestMatches(restored, source, journalState);
      pending = restored;
    } else {
      final rewrapped = await _cryptography.rewrapAttachmentManifest(source);
      _requireRewrappedAttachmentMatches(rewrapped, source, binding);
      pending = E2eeDataRekeyPendingAttachmentArtifact(
        binding: artifactBinding,
        activeLease: _activeLease(journalState),
        mutationId: artifactId,
        attachmentId: source.attachmentId,
        uploadId: source.uploadId,
        sourceManifestRevision: source.manifestRevision,
        manifestCiphertext: rewrapped.manifestCiphertext,
      );
      await _stageStore.writePendingArtifact(
        normalizedBaseUrl: context.normalizedBaseUrl,
        normalizedLoginName: context.normalizedLoginName,
        operationId: binding.operationId,
        artifactId: artifactId,
        maximumCount: artifactMaximumCount,
        envelope: pending.encode(),
      );
    }
    final requestEnvelope = pending.encode();
    final receipt = await _transport.stageDataRekeyAttachment(pending.request);
    final confirmed = pending.confirm(receipt);
    await _stageStore.confirmArtifact(
      normalizedBaseUrl: context.normalizedBaseUrl,
      normalizedLoginName: context.normalizedLoginName,
      operationId: binding.operationId,
      artifactId: artifactId,
      expectedRequestDigest: _sha256Bytes(requestEnvelope),
      confirmedEnvelope: confirmed.encode(),
    );
    return confirmed.digestItem;
  }

  Future<E2eeDataRekeyFinalizeArtifact> _loadOrCreateFinalizeArtifact({
    required E2eeDataRekeyExecutionContext context,
    required E2eeDataRekeyOperationBinding binding,
    required E2eeDataRekeyArtifactBinding artifactBinding,
    required E2eeDataRekeyJournalState journalState,
    required E2eeDataRekeySourceSnapshot sourceSnapshot,
    required Uint8List stagedCiphertextSetDigest,
    required int artifactMaximumCount,
  }) async {
    final existing = await _readFinalizeArtifact(
      context: context,
      binding: artifactBinding,
      journalState: journalState,
    );
    final expectedFields = _completionFields(
      binding: binding,
      sourceSnapshotRoot: sourceSnapshot.root,
      stagedCiphertextSetDigest: stagedCiphertextSetDigest,
    );
    final expectedFrame = buildE2eeDataRekeyCompletionFrame(expectedFields);
    if (existing != null) {
      final restoredFrame = _proofFrameFromRequest(
        userId: binding.userId,
        request: existing.request,
      );
      if (!_sameDataRekeyBytes(restoredFrame, expectedFrame)) {
        throw const FormatException('data-rekey finalize 工件与源快照不一致');
      }
      return existing;
    }

    final signature = await _cryptography.signCompletionProof(expectedFrame);
    final request = CloudSyncDataRekeyFinalizeRequest(
      activeLease: _activeLease(journalState),
      mutationId: _finalizeArtifactId(
        binding.operationId,
        journalState.leaseVersion!,
      ),
      proof: CloudSyncDataRekeyFinalizeProof(
        issuerDeviceId: binding.issuerDeviceId,
        sourceSnapshotRoot: sourceSnapshot.root,
        sourceRecordCount: binding.sourceRecordCount,
        sourceAttachmentCount: binding.sourceAttachmentCount,
        sourceMaximumChangeSeq: binding.sourceMaximumChangeSeq,
        sourceRecordCursorEnd: binding.sourceRecordCursorEnd,
        sourceAttachmentCursorEnd: _cloudAttachmentCursor(binding),
        membershipGeneration: binding.membershipGeneration,
        membershipManifestDigest: binding.membershipManifestDigest,
        stagedRecordCount: binding.sourceRecordCount,
        stagedAttachmentCount: binding.sourceAttachmentCount,
        stagedCiphertextSetDigest: stagedCiphertextSetDigest,
        signature: signature,
      ),
    );
    final artifact = E2eeDataRekeyFinalizeArtifact(
      binding: artifactBinding,
      request: request,
    );
    await _stageStore.writePendingArtifact(
      normalizedBaseUrl: context.normalizedBaseUrl,
      normalizedLoginName: context.normalizedLoginName,
      operationId: binding.operationId,
      artifactId: artifact.artifactId,
      maximumCount: artifactMaximumCount,
      envelope: artifact.encode(),
    );
    return artifact;
  }

  Future<E2eeDataRekeyFinalizeArtifact?> _readFinalizeArtifact({
    required E2eeDataRekeyExecutionContext context,
    required E2eeDataRekeyArtifactBinding binding,
    required E2eeDataRekeyJournalState journalState,
  }) async {
    final snapshot = await _stageStore.readArtifact(
      normalizedBaseUrl: context.normalizedBaseUrl,
      normalizedLoginName: context.normalizedLoginName,
      operationId: binding.operation.operationId,
      artifactId: _finalizeArtifactId(
        binding.operation.operationId,
        journalState.leaseVersion!,
      ),
    );
    if (snapshot == null) return null;
    if (snapshot.state != E2eeDataRekeyStageArtifactState.requestPending) {
      throw const FormatException('data-rekey finalize 工件状态无效');
    }
    final artifact = E2eeDataRekeyFinalizeArtifact.decode(
      snapshot.envelope,
      expectedBinding: binding,
    );
    _requireFinalizeMatchesJournal(artifact.request, journalState);
    return artifact;
  }

  Future<E2eeDataRekeyFinalizedExecution> _finalizePending({
    required E2eeDataRekeyExecutionContext context,
    required E2eeDataRekeyOperationBinding binding,
    required E2eeDataRekeyJournalState journalState,
    required E2eeDataRekeyFinalizeArtifact artifact,
    required int artifactMaximumCount,
  }) async {
    CloudSyncDataRekeyFinalizePending? previousProgress;
    final requestLimit = _finalizeRequestLimit(binding);
    for (var requestIndex = 0; requestIndex < requestLimit; requestIndex++) {
      final lease = await _ensureLeaseForWork(
        context: context,
        binding: binding,
        journalState: journalState,
      );
      journalState = lease.journalState;
      if (lease.generationChanged) {
        throw _DataRekeyLeaseGenerationChanged(journalState);
      }
      _requireFinalizeMatchesJournal(artifact.request, journalState);
      final outcome = await _transport.finalizeDataRekey(artifact.request);
      if (outcome is CloudSyncDataRekeyFinalizeResult) {
        _verifyFinalizedResult(
          userId: context.userId,
          request: artifact.request,
          result: outcome,
        );
        return _finalizedExecution(
          context: context,
          binding: binding,
          journalState: journalState,
          result: outcome,
        );
      }
      final progress = outcome as CloudSyncDataRekeyFinalizePending;
      if (previousProgress != null &&
          !_finalizeProgressAdvanced(previousProgress, progress)) {
        throw StateError('data_rekey_finalize_progress_stalled');
      }
      previousProgress = progress;
    }
    throw StateError('data_rekey_finalize_request_limit');
  }

  E2eeDataRekeyFinalizedExecution _finalizedExecution({
    required E2eeDataRekeyExecutionContext context,
    required E2eeDataRekeyOperationBinding binding,
    required E2eeDataRekeyJournalState journalState,
    required CloudSyncDataRekeyFinalizeResult result,
  }) {
    return E2eeDataRekeyFinalizedExecution._(
      result: result,
      operationId: binding.operationId,
      leaseToken: journalState.leaseToken,
      leaseVersion: journalState.leaseVersion!,
      artifactMaximumCount: _artifactMaximumCount(binding),
      userId: context.userId,
      issuerDeviceId: context.issuerDeviceId,
    );
  }

  Future<void> _advancePhase(
    E2eeDataRekeyJournalState journalState,
    E2eeDataRekeyJournalPhase phase,
  ) async {
    await _journal.advancePhase(
      operationId: journalState.binding.operationId,
      leaseToken: journalState.leaseToken,
      leaseVersion: journalState.leaseVersion!,
      phase: phase,
      now: _now(),
    );
  }

  DateTime _now() {
    final value = _clock();
    if (!value.isUtc) throw StateError('data_rekey_clock_not_utc');
    return value;
  }
}

final class _DataRekeyLeaseState {
  const _DataRekeyLeaseState({
    required this.journalState,
    required this.generationChanged,
  });

  final E2eeDataRekeyJournalState journalState;
  final bool generationChanged;
}

final class _DataRekeyScanResult {
  const _DataRekeyScanResult({
    required this.snapshot,
    required this.journalState,
  });

  final E2eeDataRekeySourceSnapshot snapshot;
  final E2eeDataRekeyJournalState journalState;
}

final class _DataRekeyStagingResult {
  const _DataRekeyStagingResult({
    required this.digest,
    required this.journalState,
  });

  final Uint8List digest;
  final E2eeDataRekeyJournalState journalState;
}

final class _DataRekeyLeaseGenerationChanged implements Exception {
  const _DataRekeyLeaseGenerationChanged(this.journalState);

  final E2eeDataRekeyJournalState journalState;
}

E2eeDataRekeyOperationBinding _operationBinding(
  E2eeDataRekeyExecutionContext context,
  CloudSyncDataRekeyPendingState pending,
) {
  final attachmentCursor = pending.sourceAttachmentCursorEnd;
  return E2eeDataRekeyOperationBinding(
    userId: context.userId,
    issuerDeviceId: context.issuerDeviceId,
    operationId: pending.operationId,
    sourceDataGeneration: pending.sourceDataGeneration,
    sourceKeyEpoch: pending.sourceKeyEpoch,
    targetKeyEpoch: pending.targetKeyEpoch,
    sourceRecordCount: pending.sourceRecordCount,
    sourceAttachmentCount: pending.sourceAttachmentCount,
    sourceMaximumChangeSeq: pending.sourceMaximumChangeSeq,
    sourceRecordCursorEnd: pending.sourceRecordCursorEnd,
    sourceAttachmentIdEnd: attachmentCursor?.attachmentId,
    sourceAttachmentUploadIdEnd: attachmentCursor?.uploadId,
    membershipGeneration: context.membershipGeneration,
    membershipManifestDigest: context.membershipManifestDigest,
  );
}

E2eeDataRekeyArtifactBinding _artifactBinding(
  E2eeDataRekeyOperationBinding binding,
) {
  return E2eeDataRekeyArtifactBinding(
    userId: binding.userId,
    issuerDeviceId: binding.issuerDeviceId,
    operation: _operationScope(binding),
  );
}

CloudSyncDataRekeyOperationScope _operationScope(
  E2eeDataRekeyOperationBinding binding,
) {
  return CloudSyncDataRekeyOperationScope(
    operationId: binding.operationId,
    sourceDataGeneration: binding.sourceDataGeneration,
    sourceKeyEpoch: binding.sourceKeyEpoch,
    targetKeyEpoch: binding.targetKeyEpoch,
  );
}

CloudSyncDataRekeyActiveLease _activeLease(
  E2eeDataRekeyJournalState journalState,
) {
  final version = journalState.leaseVersion;
  if (version == null) throw StateError('data_rekey_lease_missing');
  return CloudSyncDataRekeyActiveLease(
    operation: _operationScope(journalState.binding),
    leaseToken: journalState.leaseToken,
    leaseVersion: version,
  );
}

void _requireClaimMatchesBinding(
  CloudSyncDataRekeyLeaseClaim claim,
  E2eeDataRekeyOperationBinding binding,
) {
  final cursor = claim.sourceAttachmentCursorEnd;
  if (claim.sourceRecordCount != binding.sourceRecordCount ||
      claim.sourceAttachmentCount != binding.sourceAttachmentCount ||
      claim.sourceMaximumChangeSeq != binding.sourceMaximumChangeSeq ||
      claim.sourceRecordCursorEnd != binding.sourceRecordCursorEnd ||
      cursor?.attachmentId != binding.sourceAttachmentIdEnd ||
      cursor?.uploadId != binding.sourceAttachmentUploadIdEnd) {
    throw const FormatException('data-rekey 租约冻结源绑定发生变化');
  }
}

E2eeDataRekeySourceRecordDigestItem _sourceRecordDigest(
  CloudSyncDataRekeySourceRecord source,
) {
  return E2eeDataRekeySourceRecordDigestItem(
    recordId: source.recordId,
    revision: source.revision,
    envelopeVersion: source.envelopeVersion,
    keyEpoch: source.keyEpoch,
    ciphertextBytes: source.ciphertextBytes,
    ciphertextDigest: source.ciphertextDigest,
    lastChangeSeq: source.lastChangeSeq,
  );
}

E2eeDataRekeySourceAttachmentDigestItem _sourceAttachmentDigest(
  CloudSyncDataRekeySourceAttachment source,
) {
  return E2eeDataRekeySourceAttachmentDigestItem(
    attachmentId: source.attachmentId,
    uploadId: source.uploadId,
    chunkKeyEpoch: source.chunkKeyEpoch,
    manifestKeyEpoch: source.manifestKeyEpoch,
    manifestRevision: source.manifestRevision,
    chunkCount: source.chunkCount,
    totalCiphertextBytes: source.totalCiphertextBytes,
    manifestCiphertextBytes: source.manifestCiphertextBytes,
    manifestCiphertextDigest: source.manifestCiphertextDigest,
    chunks: <E2eeDataRekeySourceAttachmentChunkDigestItem>[
      for (final chunk in source.chunks)
        E2eeDataRekeySourceAttachmentChunkDigestItem(
          chunkIndex: chunk.chunkIndex,
          ciphertextBytes: chunk.ciphertextBytes,
          ciphertextDigest: chunk.ciphertextDigest,
        ),
    ],
  );
}

void _requireSnapshotMatchesBinding(
  E2eeDataRekeySourceSnapshot snapshot,
  E2eeDataRekeyOperationBinding binding,
) {
  final cursor = snapshot.attachmentCursorEnd;
  if (snapshot.recordCount != binding.sourceRecordCount ||
      snapshot.attachmentCount != binding.sourceAttachmentCount ||
      snapshot.maximumChangeSeq != binding.sourceMaximumChangeSeq ||
      snapshot.recordCursorEnd != binding.sourceRecordCursorEnd ||
      cursor?.attachmentId != binding.sourceAttachmentIdEnd ||
      cursor?.uploadId != binding.sourceAttachmentUploadIdEnd) {
    throw const FormatException('data-rekey 冻结源快照未覆盖声明边界');
  }
}

void _requireRewrappedRecordMatches(
  E2eeDataRekeyRewrappedRecord rewrapped,
  CloudSyncDataRekeySourceRecord source,
  E2eeDataRekeyOperationBinding binding,
) {
  if (rewrapped.sourceRecordId != source.recordId ||
      rewrapped.sourceRevision != source.revision ||
      rewrapped.targetKeyEpoch != binding.targetKeyEpoch ||
      rewrapped.targetRecordId == source.recordId) {
    throw const FormatException('data-rekey 记录重包身份无效');
  }
}

void _requireRewrappedAttachmentMatches(
  E2eeDataRekeyRewrappedAttachmentManifest rewrapped,
  CloudSyncDataRekeySourceAttachment source,
  E2eeDataRekeyOperationBinding binding,
) {
  if (rewrapped.attachmentId != source.attachmentId ||
      rewrapped.uploadId != source.uploadId ||
      rewrapped.chunkKeyEpoch != source.chunkKeyEpoch ||
      rewrapped.manifestKeyEpoch != binding.targetKeyEpoch ||
      rewrapped.manifestRevision != source.manifestRevision + 1) {
    throw const FormatException('data-rekey 附件重包改变了分块或 manifest 身份');
  }
}

void _requireRecordRequestMatches(
  E2eeDataRekeyPendingRecordArtifact artifact,
  CloudSyncDataRekeySourceRecord source,
  E2eeDataRekeyJournalState journalState,
) {
  final request = artifact.request;
  if (!_sameLease(request.activeLease, _activeLease(journalState)) ||
      request.sourceRecordId != source.recordId ||
      request.sourceRevision != source.revision) {
    throw const FormatException('data-rekey 记录请求工件未绑定当前源');
  }
}

void _requireRecordConfirmationMatches(
  E2eeDataRekeyConfirmedRecordArtifact artifact,
  CloudSyncDataRekeySourceRecord source,
  E2eeDataRekeyJournalState journalState,
) {
  final item = artifact.digestItem;
  if (!_sameLease(artifact.activeLease, _activeLease(journalState)) ||
      item.sourceRecordId != source.recordId ||
      item.sourceRevision != source.revision) {
    throw const FormatException('data-rekey 记录确认工件未绑定当前源');
  }
}

void _requireAttachmentRequestMatches(
  E2eeDataRekeyPendingAttachmentArtifact artifact,
  CloudSyncDataRekeySourceAttachment source,
  E2eeDataRekeyJournalState journalState,
) {
  final request = artifact.request;
  if (!_sameLease(request.activeLease, _activeLease(journalState)) ||
      request.attachmentId != source.attachmentId ||
      request.uploadId != source.uploadId ||
      request.sourceManifestRevision != source.manifestRevision) {
    throw const FormatException('data-rekey 附件请求工件未绑定当前源');
  }
}

void _requireAttachmentConfirmationMatches(
  E2eeDataRekeyConfirmedAttachmentArtifact artifact,
  CloudSyncDataRekeySourceAttachment source,
  E2eeDataRekeyJournalState journalState,
) {
  final item = artifact.digestItem;
  if (!_sameLease(artifact.activeLease, _activeLease(journalState)) ||
      item.attachmentId != source.attachmentId ||
      item.uploadId != source.uploadId ||
      item.sourceManifestRevision != source.manifestRevision) {
    throw const FormatException('data-rekey 附件确认工件未绑定当前源');
  }
}

void _requireFinalizeMatchesJournal(
  CloudSyncDataRekeyFinalizeRequest request,
  E2eeDataRekeyJournalState journalState,
) {
  final binding = journalState.binding;
  final proof = request.proof;
  final attachmentCursor = proof.sourceAttachmentCursorEnd;
  if (!_sameLease(request.activeLease, _activeLease(journalState)) ||
      request.mutationId !=
          _finalizeArtifactId(
            binding.operationId,
            journalState.leaseVersion!,
          ) ||
      proof.issuerDeviceId != binding.issuerDeviceId ||
      proof.sourceRecordCount != binding.sourceRecordCount ||
      proof.sourceAttachmentCount != binding.sourceAttachmentCount ||
      proof.sourceMaximumChangeSeq != binding.sourceMaximumChangeSeq ||
      proof.sourceRecordCursorEnd != binding.sourceRecordCursorEnd ||
      attachmentCursor?.attachmentId != binding.sourceAttachmentIdEnd ||
      attachmentCursor?.uploadId != binding.sourceAttachmentUploadIdEnd ||
      proof.membershipGeneration != binding.membershipGeneration ||
      !_sameDataRekeyBytes(
        proof.membershipManifestDigest,
        binding.membershipManifestDigest,
      )) {
    throw const FormatException('data-rekey finalize 工件未绑定耐久日志');
  }
}

E2eeDataRekeyCompletionFields _completionFields({
  required E2eeDataRekeyOperationBinding binding,
  required Uint8List sourceSnapshotRoot,
  required Uint8List stagedCiphertextSetDigest,
}) {
  final attachmentCursor = binding.sourceAttachmentIdEnd == null
      ? null
      : E2eeDataRekeyAttachmentCursor(
          attachmentId: binding.sourceAttachmentIdEnd!,
          uploadId: binding.sourceAttachmentUploadIdEnd!,
        );
  return E2eeDataRekeyCompletionFields(
    operationId: binding.operationId,
    userId: binding.userId,
    issuerDeviceId: binding.issuerDeviceId,
    sourceDataGeneration: binding.sourceDataGeneration,
    targetDataGeneration: binding.sourceDataGeneration + 1,
    sourceKeyEpoch: binding.sourceKeyEpoch,
    targetKeyEpoch: binding.targetKeyEpoch,
    sourceSnapshotRoot: sourceSnapshotRoot,
    sourceRecordCount: binding.sourceRecordCount,
    sourceAttachmentCount: binding.sourceAttachmentCount,
    sourceMaximumChangeSeq: binding.sourceMaximumChangeSeq,
    sourceRecordCursorEnd: binding.sourceRecordCursorEnd,
    sourceAttachmentCursorEnd: attachmentCursor,
    membershipGeneration: binding.membershipGeneration,
    membershipManifestDigest: binding.membershipManifestDigest,
    stagedRecordCount: binding.sourceRecordCount,
    stagedAttachmentCount: binding.sourceAttachmentCount,
    stagedCiphertextSetDigest: stagedCiphertextSetDigest,
  );
}

Uint8List _proofFrameFromRequest({
  required String userId,
  required CloudSyncDataRekeyFinalizeRequest request,
}) {
  final operation = request.activeLease.operation;
  final proof = request.proof;
  final cursor = proof.sourceAttachmentCursorEnd;
  return buildE2eeDataRekeyCompletionFrame(
    E2eeDataRekeyCompletionFields(
      operationId: operation.operationId,
      userId: userId,
      issuerDeviceId: proof.issuerDeviceId,
      sourceDataGeneration: operation.sourceDataGeneration,
      targetDataGeneration: request.targetDataGeneration,
      sourceKeyEpoch: operation.sourceKeyEpoch,
      targetKeyEpoch: operation.targetKeyEpoch,
      sourceSnapshotRoot: proof.sourceSnapshotRoot,
      sourceRecordCount: proof.sourceRecordCount,
      sourceAttachmentCount: proof.sourceAttachmentCount,
      sourceMaximumChangeSeq: proof.sourceMaximumChangeSeq,
      sourceRecordCursorEnd: proof.sourceRecordCursorEnd,
      sourceAttachmentCursorEnd: cursor == null
          ? null
          : E2eeDataRekeyAttachmentCursor(
              attachmentId: cursor.attachmentId,
              uploadId: cursor.uploadId,
            ),
      membershipGeneration: proof.membershipGeneration,
      membershipManifestDigest: proof.membershipManifestDigest,
      stagedRecordCount: proof.stagedRecordCount,
      stagedAttachmentCount: proof.stagedAttachmentCount,
      stagedCiphertextSetDigest: proof.stagedCiphertextSetDigest,
    ),
  );
}

void _verifyFinalizedResult({
  required String userId,
  required CloudSyncDataRekeyFinalizeRequest request,
  required CloudSyncDataRekeyFinalizeResult result,
}) {
  _verifyFinalizedCompletion(
    userId: userId,
    request: request,
    completion: result.completion,
  );
}

void _verifyFinalizedCompletion({
  required String userId,
  required CloudSyncDataRekeyFinalizeRequest request,
  required CloudSyncDataRekeyCompletion completion,
}) {
  final proofFrame = _proofFrameFromRequest(userId: userId, request: request);
  final proofDigest = digestE2eeDataRekeyCompletionProof(
    proofFrame: proofFrame,
    signature: request.proof.signature,
  );
  if (completion.operationId != request.activeLease.operation.operationId ||
      completion.issuerDeviceId != request.proof.issuerDeviceId ||
      !_sameDataRekeyBytes(completion.proofFrame, proofFrame) ||
      !_sameDataRekeyBytes(completion.proofDigest, proofDigest) ||
      !_sameDataRekeyBytes(completion.signature, request.proof.signature)) {
    throw const FormatException('data-rekey 最终回执证明帧或摘要无效');
  }
}

void _requireExecutionMatchesContext(
  E2eeDataRekeyFinalizedExecution execution,
  E2eeDataRekeyExecutionContext context,
) {
  if (execution.userId != context.userId ||
      execution.issuerDeviceId != context.issuerDeviceId) {
    throw const FormatException('data-rekey 本地确认账户不匹配');
  }
}

CloudSyncDataRekeyAttachmentCursor? _cloudAttachmentCursor(
  E2eeDataRekeyOperationBinding binding,
) {
  return binding.sourceAttachmentIdEnd == null
      ? null
      : CloudSyncDataRekeyAttachmentCursor(
          attachmentId: binding.sourceAttachmentIdEnd!,
          uploadId: binding.sourceAttachmentUploadIdEnd!,
        );
}

void _requireContextMatchesJournal(
  E2eeDataRekeyExecutionContext context,
  E2eeDataRekeyOperationBinding binding,
) {
  if (context.userId != binding.userId ||
      context.issuerDeviceId != binding.issuerDeviceId ||
      context.membershipGeneration != binding.membershipGeneration ||
      !_sameDataRekeyBytes(
        context.membershipManifestDigest,
        binding.membershipManifestDigest,
      )) {
    throw const FormatException('data-rekey 执行上下文与耐久日志不匹配');
  }
}

void _requireReadyStateMatchesJournal(
  CloudSyncDataRekeyReadyState ready,
  E2eeDataRekeyOperationBinding binding,
) {
  if (ready.dataGeneration != binding.sourceDataGeneration + 1 ||
      ready.dataKeyEpoch != binding.targetKeyEpoch ||
      ready.changeWatermark < binding.sourceMaximumChangeSeq) {
    throw const FormatException('data-rekey ready 状态未绑定目标代次');
  }
}

void _requireCryptographyMatchesBinding(
  E2eeDataRekeyCryptography cryptography,
  E2eeDataRekeyOperationBinding binding,
) {
  if (cryptography.issuerDeviceId != binding.issuerDeviceId ||
      cryptography.targetKeyEpoch != binding.targetKeyEpoch) {
    throw const FormatException('data-rekey 密码会话未绑定签发设备或目标代次');
  }
}

bool _sameLease(
  CloudSyncDataRekeyActiveLease left,
  CloudSyncDataRekeyActiveLease right,
) {
  final leftOperation = left.operation;
  final rightOperation = right.operation;
  return left.leaseToken == right.leaseToken &&
      left.leaseVersion == right.leaseVersion &&
      leftOperation.operationId == rightOperation.operationId &&
      leftOperation.sourceDataGeneration ==
          rightOperation.sourceDataGeneration &&
      leftOperation.sourceKeyEpoch == rightOperation.sourceKeyEpoch &&
      leftOperation.targetKeyEpoch == rightOperation.targetKeyEpoch;
}

bool _finalizeProgressAdvanced(
  CloudSyncDataRekeyFinalizePending previous,
  CloudSyncDataRekeyFinalizePending current,
) {
  final previousValues = <int>[
    previous.phase.index,
    previous.sourceRecordCount,
    previous.sourceAttachmentCount,
    previous.stagedRecordCount,
    previous.stagedAttachmentCount,
  ];
  final currentValues = <int>[
    current.phase.index,
    current.sourceRecordCount,
    current.sourceAttachmentCount,
    current.stagedRecordCount,
    current.stagedAttachmentCount,
  ];
  for (var index = 0; index < previousValues.length; index++) {
    if (currentValues[index] == previousValues[index]) continue;
    return currentValues[index] > previousValues[index];
  }
  return false;
}

int _artifactMaximumCount(E2eeDataRekeyOperationBinding binding) {
  final total = binding.sourceRecordCount + binding.sourceAttachmentCount + 1;
  if (total > _dataRekeyMaximumArtifactCount) {
    throw const FormatException('data-rekey 工件数量超过本地上限');
  }
  return total;
}

int _finalizeRequestLimit(E2eeDataRekeyOperationBinding binding) {
  final recordPages =
      (binding.sourceRecordCount + _dataRekeyPageSize - 1) ~/
      _dataRekeyPageSize;
  final attachmentPages =
      (binding.sourceAttachmentCount + _dataRekeyPageSize - 1) ~/
      _dataRekeyPageSize;
  return (recordPages + attachmentPages) * 2 + 6;
}

String _finalizeArtifactId(String operationId, int leaseVersion) {
  return _deriveDataRekeyMutationId('kelivo.data-rekey.finalize.v1', <String>[
    operationId,
    '$leaseVersion',
  ]);
}

String _deriveDataRekeyMutationId(String domain, List<String> fields) {
  final input = utf8.encode(<String>[domain, ...fields].join('\u0000'));
  final bytes = Uint8List.fromList(sha256.convert(input).bytes.sublist(0, 16));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  return Uuid.unparse(bytes);
}

Uint8List _sha256Bytes(Uint8List value) {
  return Uint8List.fromList(sha256.convert(value).bytes);
}

Uint8List _copyNonEmptyDataRekeyBytes(Uint8List value, String field) {
  if (value.isEmpty || value.length > 1048576) {
    throw FormatException('$field 长度无效');
  }
  return Uint8List.fromList(value).asUnmodifiableView();
}

bool _sameDataRekeyBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

String _requireDataRekeyUuid(String value, String field) {
  if (!_dataRekeyUuidPattern.hasMatch(value)) {
    throw FormatException('$field 必须为规范 UUIDv4');
  }
  return value;
}

DateTime _utcNow() => DateTime.now().toUtc();
