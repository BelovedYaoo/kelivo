import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';
import '../../database/chat_database_gateway.dart';
import '../../database/sqlcipher_database_key.dart';
import '../workspace/account_workspace_runtime.dart';
import '../workspace/device_state_blob_store.dart';
import '../workspace/e2ee_data_rekey_stage_store.dart';
import 'cloud_sync_client.dart';
import 'cloud_sync_types.dart';
import 'e2ee_account_recovery.dart';
import 'e2ee_account_recovery_checkpoint.dart';
import 'e2ee_account_recovery_runner.dart';
import 'e2ee_account_trust_manifest.dart';
import 'e2ee_data_rekey_cryptography.dart';
import 'e2ee_data_rekey_executor.dart';
import 'e2ee_device_state_access.dart';
import 'e2ee_first_device_recovery_bootstrap.dart';
import 'e2ee_native_account_recovery.dart';
import 'sensitive_utf8.dart';

final class E2eeAccountRecoveryProductionRunner
    implements E2eeAccountRecoveryRunner {
  factory E2eeAccountRecoveryProductionRunner({
    required E2eeAccountRecoveryClient client,
    required E2eeAccountRecoveryAuthentication authentication,
    required AccountWorkspaceRuntime workspaceRuntime,
    required DeviceStateBlobStore deviceStateStore,
    KelivoSecureCore secureCore = const KelivoSecureCore(),
    E2eeDataRekeyStageStore? dataRekeyStageStore,
    String baseUrl = defaultCloudSyncBaseUrl,
    String Function()? uuidFactory,
    CloudSyncAccountRecoveryToken Function()? recoveryTokenFactory,
    CloudSyncFullSessionToken Function()? fullSessionTokenFactory,
    DateTime Function()? clock,
  }) {
    return E2eeAccountRecoveryProductionRunner._(
      client: client,
      authentication: authentication,
      workspaceRuntime: workspaceRuntime,
      deviceStateStore: deviceStateStore,
      secureCore: secureCore,
      dataRekeyStageStore:
          dataRekeyStageStore ??
          E2eeDataRekeyStageStore(
            installationRoot: workspaceRuntime.installationRoot,
          ),
      baseUrl: normalizeCloudSyncBaseUrl(baseUrl),
      uuidFactory: uuidFactory ?? const Uuid().v4,
      recoveryTokenFactory:
          recoveryTokenFactory ?? CloudSyncAccountRecoveryToken.generate,
      fullSessionTokenFactory:
          fullSessionTokenFactory ?? CloudSyncFullSessionToken.generate,
      clock: clock ?? _recoveryUtcNow,
    );
  }

  E2eeAccountRecoveryProductionRunner._({
    required this._client,
    required this._authentication,
    required this._workspaceRuntime,
    required this._deviceStateStore,
    required this._secureCore,
    required this._dataRekeyStageStore,
    required this._baseUrl,
    required this._uuidFactory,
    required this._recoveryTokenFactory,
    required this._fullSessionTokenFactory,
    required this._clock,
  });

  final E2eeAccountRecoveryClient _client;
  final E2eeAccountRecoveryAuthentication _authentication;
  final AccountWorkspaceRuntime _workspaceRuntime;
  final DeviceStateBlobStore _deviceStateStore;
  final KelivoSecureCore _secureCore;
  final E2eeDataRekeyStageStore _dataRekeyStageStore;
  final String _baseUrl;
  final String Function() _uuidFactory;
  final CloudSyncAccountRecoveryToken Function() _recoveryTokenFactory;
  final CloudSyncFullSessionToken Function() _fullSessionTokenFactory;
  final DateTime Function() _clock;

  _RecoveryCheckpointLease? _checkpointLease;
  AccountRecoveryWorkspaceLease? _workspaceLease;
  String? _workspaceUserId;
  E2eeAccountRecoveryCheckpointSnapshot? _terminalSnapshot;
  CloudSyncAuthenticatedSession? _terminalSession;
  final List<E2eeAccountRecoveryReopenLease> _pendingReopenLeases =
      <E2eeAccountRecoveryReopenLease>[];
  final List<_RecoveryOpenedDeviceStateCleanup> _pendingOpenedStateCleanups =
      <_RecoveryOpenedDeviceStateCleanup>[];
  final List<_PendingRecoveryResourceCleanup> _pendingResourceCleanups =
      <_PendingRecoveryResourceCleanup>[];
  bool _running = false;
  bool _closed = false;
  bool _workspaceBoundAcknowledged = false;

  @override
  Future<CloudSyncAuthenticatedSession> recover({
    required E2eeAccountRecoveryInput input,
    required CloudSyncPlatform platform,
    required String clientVersion,
    required E2eeAccountRecoveryProgressCallback onProgress,
  }) async {
    if (_closed) throw StateError('account_recovery_runner_closed');
    if (_running) throw StateError('account_recovery_runner_busy');
    if (platform != CloudSyncPlatform.android &&
        platform != CloudSyncPlatform.ios) {
      throw const CloudSyncException(
        kind: CloudSyncFailureKind.forbidden,
        retryable: false,
        serverCode: e2eeAccountRecoveryUnsupportedCode,
      );
    }
    final normalizedLoginName = _normalizeRecoveryLoginName(input.loginName);
    _running = true;
    final recoveryPassphrase = Uint8List.fromList(input.recoveryPassphrase);
    E2eeAccountRecoveryOnboardingLease? onboardingLease;
    E2eeNativeAccountRecoveryKeyLease? initialKeyLease;
    Object? primaryError;
    Future<void> releaseOnboardingLease() async {
      final lease = onboardingLease;
      if (lease == null) return;
      await _closeTrackedResource(lease, (value) => value.close());
      if (identical(onboardingLease, lease)) onboardingLease = null;
    }

    try {
      var checkpointLease = await _tryOpenCheckpointLease(normalizedLoginName);
      if (checkpointLease != null) _checkpointLease = checkpointLease;
      var snapshot = await checkpointLease?.store.read();
      if (snapshot == null || _requiresOnboarding(snapshot.checkpoint.phase)) {
        final acquiredOnboardingLease = await _authentication.begin(
          loginName: normalizedLoginName,
          password: input.accountPassword,
          deviceName: input.deviceName,
          platform: platform,
          clientVersion: clientVersion,
        );
        onboardingLease = acquiredOnboardingLease;
        _requireOnboardingBinding(
          acquiredOnboardingLease,
          normalizedLoginName: normalizedLoginName,
          platform: platform,
          clientVersion: clientVersion,
        );
        checkpointLease ??= await _openRequiredCheckpointLease(
          normalizedLoginName,
        );
        _checkpointLease = checkpointLease;
        onProgress(E2eeAccountRecoveryProgress.verifyingRecoveryMedia);
        final authorized =
            await E2eeAccountRecoveryAuthorizer(
              transport: _client,
              proofCore: acquiredOnboardingLease.proofCore,
              checkpointPersistence: checkpointLease.store,
              serviceOriginSha256: Uint8List.fromList(
                sha256
                    .convert(utf8.encode(e2eeCanonicalRecoveryServiceOrigin))
                    .bytes,
              ),
              attemptIdFactory: _uuidFactory,
              recoveryTokenFactory: _recoveryTokenFactory,
              now: _clock,
            ).authorize(
              onboardingToken: acquiredOnboardingLease.onboardingToken,
              expectedDeviceId: acquiredOnboardingLease.deviceId,
              recoveryMedia: input.encryptedRecoveryMedia,
              recoveryPassphrase: Uint8List.fromList(recoveryPassphrase),
            );
        if (authorized.keyLease is! E2eeNativeAccountRecoveryKeyLease) {
          await _closeRecoveryKeyLease(authorized.keyLease);
          throw StateError('账户恢复未获得 Native 密钥能力');
        }
        initialKeyLease =
            authorized.keyLease as E2eeNativeAccountRecoveryKeyLease;
        snapshot = await checkpointLease.store.read();
        if (snapshot == null ||
            snapshot.checkpoint.phase !=
                E2eeAccountRecoveryCheckpointPhase.authorized) {
          throw StateError('账户恢复授权 checkpoint 未持久化');
        }
      } else {
        clearSensitiveBytes(input.accountPassword);
        _checkpointLease = checkpointLease;
        onProgress(E2eeAccountRecoveryProgress.verifyingRecoveryMedia);
      }
      onProgress(E2eeAccountRecoveryProgress.rebuildingTrustedDevice);
      final initialSourceStateBlob = onboardingLease?.copySourceStateBlob();
      final transferredInitialKeyLease = initialKeyLease;
      initialKeyLease = null;
      final result = await _drive(
        snapshot: snapshot,
        normalizedLoginName: normalizedLoginName,
        encryptedRecoveryMedia: input.encryptedRecoveryMedia,
        recoveryPassphrase: recoveryPassphrase,
        initialKeyLease: transferredInitialKeyLease,
        initialSourceStateBlob: initialSourceStateBlob,
        releaseOnboardingLease: releaseOnboardingLease,
        onProgress: onProgress,
      );
      _terminalSnapshot = result.snapshot;
      _terminalSession = result.session;
      return result.session;
    } catch (error) {
      primaryError = error;
      rethrow;
    } finally {
      clearSensitiveBytes(recoveryPassphrase);
      try {
        await _closeRecoveryResourcesPreservingPrimary(
          primaryError: primaryError,
          actions: <Future<void> Function()>[
            () async {
              await _closeRecoveryDependencies(<Future<void> Function()>[
                () => _closeRecoveryKeyLease(initialKeyLease),
                () => _closeTrackedResource(
                  onboardingLease,
                  (value) => value.close(),
                ),
              ]);
              await _closeWorkspaceLease();
            },
          ],
        );
      } finally {
        _running = false;
      }
    }
  }

  Future<bool> finalizeRestartedWorkspace() async {
    if (_closed) throw StateError('account_recovery_runner_closed');
    if (_running) throw StateError('account_recovery_runner_busy');
    final current = _workspaceRuntime.current;
    final candidateSession = current.session;
    if (current.isLocal || candidateSession == null) {
      throw StateError('账户恢复启动收尾要求已认证的账户工作区');
    }
    _running = true;
    E2eeAccountRecoveryCheckpointSnapshot? snapshot;
    var retainSnapshot = false;
    Object? primaryError;
    try {
      final checkpointLease = await _openRequiredCheckpointLease(
        candidateSession.loginName,
      );
      _checkpointLease = checkpointLease;
      snapshot = await checkpointLease.store.read();
      if (snapshot == null) return false;
      if (snapshot.checkpoint.phase !=
          E2eeAccountRecoveryCheckpointPhase.sessionVerified) {
        throw StateError('账户恢复启动收尾发现非终态 checkpoint');
      }
      final verifiedSession = await _verifyCompletionSession(
        snapshot,
        normalizedLoginName: candidateSession.loginName,
      );
      final expectedSession = CloudSyncAccountSession.fromAuthenticatedSession(
        baseUrl: _baseUrl,
        session: verifiedSession,
      );
      if (!_sameRecoveryAccountSession(candidateSession, expectedSession)) {
        throw const FormatException('账户恢复启动会话与终态 checkpoint 不一致');
      }
      _terminalSnapshot = snapshot;
      _terminalSession = verifiedSession;
      retainSnapshot = true;
    } catch (error) {
      primaryError = error;
      rethrow;
    } finally {
      try {
        if (!retainSnapshot) snapshot?.clearSensitiveState();
      } finally {
        try {
          await _closeRecoveryResourcesPreservingPrimary(
            primaryError: primaryError,
            actions: <Future<void> Function()>[
              () async {
                await _closeRecoveryDependencies();
                await _closeWorkspaceLease();
              },
            ],
          );
        } finally {
          _running = false;
        }
      }
    }
    await acknowledgeWorkspaceBound();
    return true;
  }

  @override
  Future<void> acknowledgeWorkspaceBound() async {
    if (_closed) throw StateError('account_recovery_runner_closed');
    if (_running) throw StateError('account_recovery_runner_busy');
    if (_workspaceBoundAcknowledged) return;
    final lease = _checkpointLease;
    final terminal = _terminalSnapshot;
    if (lease == null || terminal == null) {
      throw StateError('账户恢复尚未产生已验证的终态会话');
    }
    if (terminal.checkpoint.phase !=
        E2eeAccountRecoveryCheckpointPhase.sessionVerified) {
      throw StateError('账户恢复终态 checkpoint 尚未验证会话');
    }
    final expectedSession = _terminalSession;
    final boundSession = _workspaceRuntime.current.session;
    if (_workspaceRuntime.current.isLocal ||
        expectedSession == null ||
        boundSession == null ||
        !_sameRecoveryAccountSession(
          boundSession,
          CloudSyncAccountSession.fromAuthenticatedSession(
            baseUrl: _baseUrl,
            session: expectedSession,
          ),
        )) {
      throw StateError('账户恢复终态尚未绑定目标工作区');
    }
    final deleted = await lease.store.delete(terminal);
    if (!deleted) {
      final current = await lease.store.read();
      try {
        if (current != null) {
          throw StateError('账户恢复终态 checkpoint 已发生并发变化');
        }
      } finally {
        current?.clearSensitiveState();
      }
    }
    _workspaceBoundAcknowledged = true;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    if (_running) throw StateError('account_recovery_runner_busy');
    final lease = _checkpointLease;
    await _closeRecoveryDependencies();
    await _closeWorkspaceLease();
    await lease?.close();
    _checkpointLease = null;
    _terminalSnapshot = null;
    _terminalSession = null;
    _closed = true;
  }

  Future<void> _closeRecoveryDependencies([
    List<Future<void> Function()> additionalActions = const [],
  ]) {
    return _closeRecoveryResources(<Future<void> Function()>[
      ...additionalActions,
      _drainPendingReopenLeases,
      _drainPendingOpenedStateCleanups,
      _drainPendingResourceCleanups,
      _authentication.close,
    ]);
  }

  Future<
    ({
      CloudSyncAuthenticatedSession session,
      E2eeAccountRecoveryCheckpointSnapshot snapshot,
    })
  >
  _drive({
    required E2eeAccountRecoveryCheckpointSnapshot snapshot,
    required String normalizedLoginName,
    required Uint8List encryptedRecoveryMedia,
    required Uint8List recoveryPassphrase,
    required E2eeNativeAccountRecoveryKeyLease? initialKeyLease,
    required Uint8List? initialSourceStateBlob,
    required Future<void> Function() releaseOnboardingLease,
    required E2eeAccountRecoveryProgressCallback onProgress,
  }) async {
    E2eeNativeAccountRecoveryKeyLease? availableInitialLease = initialKeyLease;
    E2eeNativeAccountRecoveryKeyLease? replacementKeyLease;
    Object? primaryError;
    try {
      for (;;) {
        final checkpoint = snapshot.checkpoint;
        switch (checkpoint.progress) {
          case E2eeAccountRecoveryChallengedProgress() ||
              E2eeAccountRecoveryProofReadyProgress():
            throw StateError('账户恢复授权阶段未由 Authorizer 收敛');
          case E2eeAccountRecoveryAuthorizedProgress(:final authorization):
            final keyLease = availableInitialLease;
            final sourceStateBlob = initialSourceStateBlob;
            if (keyLease == null || sourceStateBlob == null) {
              throw StateError('账户恢复授权阶段缺少 Native 准备能力');
            }
            snapshot = await _prepareInitialTransition(
              snapshot: snapshot,
              authorization: authorization,
              keyLease: keyLease,
              sourceStateBlob: sourceStateBlob,
            );
            await _closeRecoveryKeyLease(keyLease);
            availableInitialLease = null;
            await releaseOnboardingLease();
            continue;
          case E2eeAccountRecoveryResumePreparedProgress() ||
              E2eeAccountRecoveryReplacementPreparedProgress():
            await _requirePreparedSourceState(
              snapshot,
              normalizedLoginName: normalizedLoginName,
            );
            snapshot = await _commitPrepared(snapshot);
            continue;
          case E2eeAccountRecoveryResumeCommittedProgress() ||
              E2eeAccountRecoveryReplacementCommittedProgress():
            onProgress(E2eeAccountRecoveryProgress.restoringEncryptedData);
            snapshot = await _completeDataRekey(
              snapshot,
              normalizedLoginName: normalizedLoginName,
            );
            continue;
          case E2eeAccountRecoveryFirstRekeyFinalizedProgress() ||
              E2eeAccountRecoverySecondRekeyFinalizedProgress():
            onProgress(E2eeAccountRecoveryProgress.restoringEncryptedData);
            snapshot = await _activateFinalizedTransition(
              snapshot,
              normalizedLoginName: normalizedLoginName,
            );
            continue;
          case E2eeAccountRecoveryFirstLocalActivatedProgress():
            onProgress(E2eeAccountRecoveryProgress.restoringEncryptedData);
            await _acknowledgeCompletedRekey(
              snapshot,
              normalizedLoginName: normalizedLoginName,
            );
            snapshot = await _persistReplacementChallengeRequest(snapshot);
            continue;
          case E2eeAccountRecoveryReplacementChallengeRequestedProgress():
            snapshot = await _fetchReplacementChallenge(
              snapshot,
              normalizedLoginName: normalizedLoginName,
            );
            continue;
          case E2eeAccountRecoveryReplacementChallengeReceivedProgress():
            replacementKeyLease = await _createReplacementProof(
              snapshot: snapshot,
              normalizedLoginName: normalizedLoginName,
              encryptedRecoveryMedia: encryptedRecoveryMedia,
              recoveryPassphrase: recoveryPassphrase,
            );
            snapshot = (await _requiredCheckpointLease().store.read())!;
            continue;
          case E2eeAccountRecoveryReplacementProofReadyProgress():
            replacementKeyLease ??= await _createReplacementProof(
              snapshot: snapshot,
              normalizedLoginName: normalizedLoginName,
              encryptedRecoveryMedia: encryptedRecoveryMedia,
              recoveryPassphrase: recoveryPassphrase,
            );
            snapshot = await _prepareReplacementTransition(
              snapshot: snapshot,
              keyLease: replacementKeyLease,
              normalizedLoginName: normalizedLoginName,
            );
            final consumedLease = replacementKeyLease;
            await _closeRecoveryKeyLease(consumedLease);
            replacementKeyLease = null;
            continue;
          case E2eeAccountRecoverySecondLocalActivatedProgress():
            onProgress(E2eeAccountRecoveryProgress.restoringEncryptedData);
            await _acknowledgeCompletedRekey(
              snapshot,
              normalizedLoginName: normalizedLoginName,
            );
            final session = await _verifyCompletionSession(
              snapshot,
              normalizedLoginName: normalizedLoginName,
            );
            snapshot = await _advanceCheckpoint(
              snapshot,
              checkpoint.markSessionVerified(
                sessionGeneration: session.sessionGeneration,
                tokenExpiresAt: session.tokenExpiresAt,
              ),
            );
            return (session: session, snapshot: snapshot);
          case E2eeAccountRecoverySessionVerifiedProgress():
            final session = await _verifyCompletionSession(
              snapshot,
              normalizedLoginName: normalizedLoginName,
            );
            return (session: session, snapshot: snapshot);
        }
      }
    } catch (error) {
      primaryError = error;
      rethrow;
    } finally {
      snapshot.clearSensitiveState();
      clearSensitiveBytes(initialSourceStateBlob);
      await _closeRecoveryResourcesPreservingPrimary(
        primaryError: primaryError,
        actions: <Future<void> Function()>[
          () => _closeRecoveryKeyLease(availableInitialLease),
          () => _closeRecoveryKeyLease(replacementKeyLease),
        ],
      );
    }
  }

  Future<E2eeAccountRecoveryCheckpointSnapshot> _prepareInitialTransition({
    required E2eeAccountRecoveryCheckpointSnapshot snapshot,
    required E2eeAccountRecoveryCheckpointAuthorization authorization,
    required E2eeNativeAccountRecoveryKeyLease keyLease,
    required Uint8List sourceStateBlob,
  }) async {
    final checkpoint = snapshot.checkpoint;
    return switch (authorization.nextAction) {
      E2eeAccountRecoveryNextAction.recoverResume => _prepareResumeTransition(
        snapshot: snapshot,
        keyLease: keyLease,
        sourceStateBlob: sourceStateBlob,
      ),
      E2eeAccountRecoveryNextAction.recoverReplace =>
        _prepareDirectReplacementTransition(
          snapshot: snapshot,
          keyLease: keyLease,
          sourceStateBlob: sourceStateBlob,
        ),
      _ => throw StateError('账户恢复授权动作不可准备：${checkpoint.phase.name}'),
    };
  }

  Future<E2eeAccountRecoveryCheckpointSnapshot> _prepareResumeTransition({
    required E2eeAccountRecoveryCheckpointSnapshot snapshot,
    required E2eeNativeAccountRecoveryKeyLease keyLease,
    required Uint8List sourceStateBlob,
  }) async {
    final checkpoint = snapshot.checkpoint;
    final rekeyOperationId = checkpoint.challenge.dataState.operationId;
    if (rekeyOperationId == null) {
      throw StateError('恢复接续缺少既有 data-rekey operationId');
    }
    final operationId = _uuidFactory();
    final prepared = await keyLease.prepareResume(
      operationId: operationId,
      rekeyOperationId: rekeyOperationId,
    );
    final states = await keyLease.prepareDeviceStates(
      key: _requiredCheckpointLease().key,
      prepared: prepared,
    );
    try {
      final transition = _resumePreparedTransition(
        checkpoint: checkpoint,
        operationId: operationId,
        rekeyOperationId: rekeyOperationId,
        prepared: prepared,
        states: states,
        sourceStateBlob: sourceStateBlob,
      );
      return _advanceCheckpoint(
        snapshot,
        checkpoint.prepareTransition(
          commit: transition.commit,
          localTransitionPlan: transition.localTransitionPlan,
        ),
      );
    } finally {
      states.dispose();
    }
  }

  Future<E2eeAccountRecoveryCheckpointSnapshot>
  _prepareDirectReplacementTransition({
    required E2eeAccountRecoveryCheckpointSnapshot snapshot,
    required E2eeNativeAccountRecoveryKeyLease keyLease,
    required Uint8List sourceStateBlob,
  }) {
    return _prepareReplacement(
      snapshot: snapshot,
      keyLease: keyLease,
      sourceStateBlob: sourceStateBlob,
      replacementChallenge: null,
    );
  }

  Future<E2eeAccountRecoveryCheckpointSnapshot> _prepareReplacementTransition({
    required E2eeAccountRecoveryCheckpointSnapshot snapshot,
    required E2eeNativeAccountRecoveryKeyLease keyLease,
    required String normalizedLoginName,
  }) async {
    final progress = snapshot.checkpoint.progress;
    if (progress is! E2eeAccountRecoveryReplacementProofReadyProgress) {
      throw StateError('账户恢复 replacement proof 尚未持久化');
    }
    final reopenLease = await _openVerifiedRecoveryLease(
      normalizedLoginName: normalizedLoginName,
      checkpoint: snapshot.checkpoint,
    );
    Uint8List? source;
    Object? primaryError;
    try {
      source = await _readRequiredStateBlob(normalizedLoginName);
      return await _prepareReplacement(
        snapshot: snapshot,
        keyLease: keyLease,
        sourceStateBlob: source,
        replacementChallenge: progress.challenge,
      );
    } catch (error) {
      primaryError = error;
      rethrow;
    } finally {
      clearSensitiveBytes(source);
      await _closeRecoveryResourcesPreservingPrimary(
        primaryError: primaryError,
        actions: <Future<void> Function()>[
          () => _closeReopenLease(reopenLease),
        ],
      );
    }
  }

  Future<E2eeAccountRecoveryCheckpointSnapshot> _prepareReplacement({
    required E2eeAccountRecoveryCheckpointSnapshot snapshot,
    required E2eeNativeAccountRecoveryKeyLease keyLease,
    required Uint8List sourceStateBlob,
    required E2eeAccountRecoveryReplacementChallenge? replacementChallenge,
  }) async {
    final checkpoint = snapshot.checkpoint;
    final operationId = _uuidFactory();
    final completionSessionId = _uuidFactory();
    final completionToken = _fullSessionTokenFactory();
    final tokenBytes = encodeSensitiveUtf8(completionToken.value);
    try {
      final prepared = await keyLease.prepareReplacement(
        operationId: operationId,
        completionSessionId: completionSessionId,
        completionSessionTokenDigest: Uint8List.fromList(
          sha256.convert(tokenBytes).bytes,
        ),
      );
      final states = await keyLease.prepareDeviceStates(
        key: _requiredCheckpointLease().key,
        prepared: prepared,
      );
      try {
        final transition = _replacementPreparedTransition(
          checkpoint: checkpoint,
          operationId: operationId,
          completionSessionId: completionSessionId,
          completionSessionToken: completionToken,
          prepared: prepared,
          states: states,
          sourceStateBlob: sourceStateBlob,
          replacementChallenge: replacementChallenge,
        );
        return _advanceCheckpoint(
          snapshot,
          checkpoint.prepareTransition(
            commit: transition.commit,
            localTransitionPlan: transition.localTransitionPlan,
          ),
        );
      } finally {
        states.dispose();
      }
    } finally {
      clearSensitiveBytes(tokenBytes);
    }
  }

  Future<E2eeAccountRecoveryCheckpointSnapshot> _commitPrepared(
    E2eeAccountRecoveryCheckpointSnapshot snapshot,
  ) async {
    E2eeAccountRecoveryCheckpointSnapshot? committed;
    var retainCommitted = false;
    try {
      await E2eeAccountRecoveryCommitCoordinator(
        transport: _client,
        checkpointPersistence: _requiredCheckpointLease().store,
        now: _clock,
      ).commitPrepared();
      committed = await _requiredCheckpointLease().store.read();
      if (committed == null ||
          (committed.checkpoint.phase !=
                  E2eeAccountRecoveryCheckpointPhase.resumeCommitted &&
              committed.checkpoint.phase !=
                  E2eeAccountRecoveryCheckpointPhase.replacementCommitted)) {
        throw StateError('账户恢复远端提交回执未持久化');
      }
      retainCommitted = true;
      return committed;
    } finally {
      snapshot.clearSensitiveState();
      if (!retainCommitted) committed?.clearSensitiveState();
    }
  }

  Future<E2eeAccountRecoveryCheckpointSnapshot> _completeDataRekey(
    E2eeAccountRecoveryCheckpointSnapshot snapshot, {
    required String normalizedLoginName,
  }) async {
    final transition = _committedTransition(snapshot.checkpoint.progress);
    final reopenLease = snapshot.checkpoint.reopenBinding == null
        ? null
        : await _openVerifiedRecoveryLease(
            normalizedLoginName: normalizedLoginName,
            checkpoint: snapshot.checkpoint,
          );
    Object? primaryError;
    try {
      await _ensureUnprunedStatePublished(
        normalizedLoginName,
        transition.localTransitionPlan,
        allowSource: true,
        allowPruned: false,
      );
      final rekeyOperationId = _transitionRekeyOperationId(transition.commit);
      final completion = await _withDataRekeyExecutor(
        normalizedLoginName: normalizedLoginName,
        checkpoint: snapshot.checkpoint,
        transition: transition,
        targetStateBlob: transition.localTransitionPlan.unprunedStateBlob,
        action: (executor, context, transport) async {
          final execution = await executor.execute(context);
          if (execution != null) {
            return (await executor.confirmReady(
              context: context,
              execution: execution,
            )).completion;
          }
          final state = await transport.getDataRekeyState();
          if (state is! CloudSyncDataRekeyReadyState ||
              state.lastCompletion == null) {
            throw StateError('账户恢复 data-rekey 未返回完成证明');
          }
          return state.lastCompletion!;
        },
      );
      if (completion.operationId != rekeyOperationId) {
        throw const FormatException('账户恢复 data-rekey 完成操作不一致');
      }
      return _advanceCheckpoint(
        snapshot,
        snapshot.checkpoint.withRekeyCompletion(completion),
      );
    } catch (error) {
      primaryError = error;
      rethrow;
    } finally {
      await _closeRecoveryResourcesPreservingPrimary(
        primaryError: primaryError,
        actions: <Future<void> Function()>[
          () => _closeReopenLease(reopenLease),
        ],
      );
    }
  }

  Future<E2eeAccountRecoveryCheckpointSnapshot> _activateFinalizedTransition(
    E2eeAccountRecoveryCheckpointSnapshot snapshot, {
    required String normalizedLoginName,
  }) async {
    final transition = _finalizedTransition(snapshot.checkpoint.progress);
    final completion = _finalizedCompletion(snapshot.checkpoint.progress);
    final stateReopenLease = snapshot.checkpoint.reopenBinding == null
        ? null
        : await _openVerifiedRecoveryLease(
            normalizedLoginName: normalizedLoginName,
            checkpoint: snapshot.checkpoint,
          );
    Object? statePrimaryError;
    try {
      await _ensureUnprunedStatePublished(
        normalizedLoginName,
        transition.localTransitionPlan,
        allowSource: false,
        allowPruned: true,
      );
    } catch (error) {
      statePrimaryError = error;
      rethrow;
    } finally {
      await _closeRecoveryResourcesPreservingPrimary(
        primaryError: statePrimaryError,
        actions: <Future<void> Function()>[
          () => _closeReopenLease(stateReopenLease),
        ],
      );
    }
    final binding = _nativeStateBinding(
      transition,
      checkpoint: snapshot.checkpoint,
    );
    final continuation = transition.localTransitionPlan.copyContinuation();
    final prunedCandidate = transition.localTransitionPlan.prunedStateBlob;
    Uint8List? activated;
    try {
      activated = await _secureCore.activatePreparedAccountRecoveryDeviceState(
        _requiredCheckpointLease().key,
        continuation: continuation,
        stateBinding: binding,
        prunedCandidate: prunedCandidate,
        completionProofFrame: completion.proofFrame,
        completionProofSignature: KelivoDataRekeyCompletionProofSignature(
          completion.signature,
        ),
        completionProofDigest: completion.proofDigest,
      );
      if (!_sameRecoveryBytes(activated, prunedCandidate)) {
        throw const FormatException('账户恢复 Native 激活结果与 pruned 候选不一致');
      }
      final activatedMembership = await _installOrAdvanceRecoveryAnchor(
        normalizedLoginName: normalizedLoginName,
        checkpoint: snapshot.checkpoint,
        transition: transition,
      );
      await _publishPrunedState(
        normalizedLoginName,
        transition.localTransitionPlan,
        activated,
      );
      final deviceAuthGeneration = await _verifyActivatedStateAndAnchor(
        normalizedLoginName: normalizedLoginName,
        checkpoint: snapshot.checkpoint,
        transition: transition,
        completion: completion,
        membership: activatedMembership,
      );
      return _advanceCheckpoint(
        snapshot,
        snapshot.checkpoint.markLocalTransitionActivated(
          deviceAuthGeneration: deviceAuthGeneration,
        ),
      );
    } finally {
      clearSensitiveBytes(continuation);
      clearSensitiveBytes(prunedCandidate);
      clearSensitiveBytes(activated);
    }
  }

  Future<void> _acknowledgeCompletedRekey(
    E2eeAccountRecoveryCheckpointSnapshot snapshot, {
    required String normalizedLoginName,
  }) async {
    final completion = _activatedRekeyCompletion(snapshot.checkpoint.progress);
    await _withCompletedDataRekeyExecutor(
      normalizedLoginName: normalizedLoginName,
      checkpoint: snapshot.checkpoint,
      completion: completion,
      action: (executor, context, transport) async {
        final execution = await executor.execute(context);
        if (execution == null) {
          final state = await transport.getDataRekeyState();
          if (state is! CloudSyncDataRekeyReadyState ||
              state.lastCompletion == null ||
              !_sameRecoveryCompletion(state.lastCompletion!, completion)) {
            throw const FormatException('账户恢复服务端完成证明与 checkpoint 不一致');
          }
          return;
        }
        final confirmation = await executor.confirmReady(
          context: context,
          execution: execution,
        );
        if (!_sameRecoveryCompletion(confirmation.completion, completion)) {
          throw const FormatException('账户恢复本地确认与 checkpoint 完成证明不一致');
        }
        await executor.acknowledgeLocalCommit(
          context: context,
          confirmation: confirmation,
        );
      },
    );
  }

  Future<E2eeAccountRecoveryCheckpointSnapshot>
  _persistReplacementChallengeRequest(
    E2eeAccountRecoveryCheckpointSnapshot snapshot,
  ) {
    final progress = snapshot.checkpoint.progress;
    if (progress is! E2eeAccountRecoveryFirstLocalActivatedProgress) {
      throw StateError('账户恢复尚不可创建第二 challenge');
    }
    final request = E2eeAccountRecoveryReplacementChallengeRequest(
      challengeId: _uuidFactory(),
      expectedGeneration: progress.resumeReceipt.generation,
      expectedKeyEpoch: progress.resumeReceipt.keyEpoch,
      expectedMembershipManifestDigest:
          progress.completion.membershipManifestDigest,
      expectedMembershipOperationId:
          progress.resumeReceipt.membershipOperationId,
      dataGeneration: progress.completion.targetDataGeneration,
      dataKeyEpoch: progress.completion.targetKeyEpoch,
      sourceRekeyOperationId: progress.completion.operationId,
      sourceCompletionProofDigest: progress.completion.proofDigest,
    );
    return _advanceCheckpoint(
      snapshot,
      snapshot.checkpoint.requestReplacementChallenge(request),
    );
  }

  Future<E2eeAccountRecoveryCheckpointSnapshot> _fetchReplacementChallenge(
    E2eeAccountRecoveryCheckpointSnapshot snapshot, {
    required String normalizedLoginName,
  }) async {
    final progress = snapshot.checkpoint.progress;
    if (progress is! E2eeAccountRecoveryReplacementChallengeRequestedProgress) {
      throw StateError('账户恢复第二 challenge 请求未持久化');
    }
    final reopenLease = await _openVerifiedRecoveryLease(
      normalizedLoginName: normalizedLoginName,
      checkpoint: snapshot.checkpoint,
    );
    Object? primaryError;
    try {
      final challenge = await _client.createReplacementChallenge(
        recoveryToken: snapshot.checkpoint.recoveryToken,
        expectedAttemptId: snapshot.checkpoint.attemptId,
        expectedDeviceId: snapshot.checkpoint.expectedDeviceId,
        request: progress.request,
      );
      return _advanceCheckpoint(
        snapshot,
        snapshot.checkpoint.withReplacementChallenge(challenge),
      );
    } catch (error) {
      primaryError = error;
      rethrow;
    } finally {
      await _closeRecoveryResourcesPreservingPrimary(
        primaryError: primaryError,
        actions: <Future<void> Function()>[
          () => _closeReopenLease(reopenLease),
        ],
      );
    }
  }

  Future<E2eeNativeAccountRecoveryKeyLease> _createReplacementProof({
    required E2eeAccountRecoveryCheckpointSnapshot snapshot,
    required String normalizedLoginName,
    required Uint8List encryptedRecoveryMedia,
    required Uint8List recoveryPassphrase,
  }) async {
    final progress = snapshot.checkpoint.progress;
    final challenge = switch (progress) {
      E2eeAccountRecoveryReplacementChallengeReceivedProgress(
        :final challenge,
      ) =>
        challenge,
      E2eeAccountRecoveryReplacementProofReadyProgress(:final challenge) =>
        challenge,
      _ => throw StateError('账户恢复第二 challenge 尚未持久化'),
    };
    final reopenLease = await _openVerifiedRecoveryLease(
      normalizedLoginName: normalizedLoginName,
      checkpoint: snapshot.checkpoint,
    );
    E2eeOpenedDeviceStateHandles? opened;
    E2eeAccountRecoveryProof? proof;
    E2eeNativeAccountRecoveryKeyLease? candidateKeyLease;
    Object? primaryError;
    try {
      opened = await _openRequiredDeviceState(normalizedLoginName);
      final account = opened.binding.account;
      final ark = opened.ark;
      if (account == null || ark == null) {
        throw StateError('账户恢复第二 challenge 缺少本地 ARK');
      }
      _requireOpenedRecoveryBinding(
        opened: opened,
        binding: reopenLease.binding,
      );
      final history = await _readFrozenHistory(
        recoveryToken: snapshot.checkpoint.recoveryToken,
        attemptId: snapshot.checkpoint.attemptId,
        requestDigest: challenge.requestDigest,
        expectedGeneration: challenge.securityGeneration,
        expectedKeyEpoch: challenge.keyEpoch,
        expectedMembershipManifestDigest: challenge.membershipManifestDigest,
        expectedRecoveryPublicKeyVersion: challenge.recoveryPublicKeyVersion,
        expectedRecoveryPublicKey: challenge.recoveryPublicKey,
        expectedRecoveryCapsuleVersion: challenge.recoveryCapsuleVersion,
        expectedRecoveryCapsule: challenge.recoveryCapsule,
        expectedDataRekeyPhase: CloudSyncDataRekeyPhase.ready,
      );
      final verified = await _verifyRecoveryHistory(
        ark: ark,
        userId: Uuid.unparse(account.userId),
        history: history,
        dataRekeyPhase: E2eeDataRekeyPhase.ready,
      );
      final localMember = verified.members.singleWhere(
        (member) => member.deviceId == snapshot.checkpoint.expectedDeviceId,
      );
      if (localMember.keyVersion != reopenLease.binding.deviceKeyVersion ||
          localMember.authGeneration !=
              reopenLease.binding.deviceAuthGeneration) {
        throw const FormatException('账户恢复第二 challenge 设备密钥版本不一致');
      }
      final tokenBytes = encodeSensitiveUtf8(
        snapshot.checkpoint.recoveryToken.value,
      );
      final recoveryTokenDigest = Uint8List.fromList(
        sha256.convert(tokenBytes).bytes,
      );
      final sourceCapsule = _sourceCapsule(challenge.keyEpoch, history);
      try {
        proof = await reopenLease.proofCore
            .verifyReplacementChallengeAndCreateProof(
              recoveryMedia: Uint8List.fromList(encryptedRecoveryMedia),
              recoveryPassphrase: Uint8List.fromList(recoveryPassphrase),
              serviceOriginSha256: Uint8List.fromList(
                sha256
                    .convert(utf8.encode(e2eeCanonicalRecoveryServiceOrigin))
                    .bytes,
              ),
              membershipHistory: history
                  .map((item) => Uint8List.fromList(item.membershipManifest))
                  .toList(growable: false),
              sourceCapsule: sourceCapsule,
              challenge: challenge,
              recoveryTokenDigest: recoveryTokenDigest,
              expectedDeviceId: snapshot.checkpoint.expectedDeviceId,
            );
      } finally {
        clearSensitiveBytes(tokenBytes);
        clearSensitiveBytes(recoveryTokenDigest);
        clearSensitiveBytes(sourceCapsule);
      }
      if (proof.keyLease is! E2eeNativeAccountRecoveryKeyLease) {
        throw StateError('账户恢复第二 challenge 未获得 Native 密钥能力');
      }
      candidateKeyLease = proof.keyLease as E2eeNativeAccountRecoveryKeyLease;
      final nonceProof = proof.takeNonceProof();
      final trustSignature = proof.takeTrustSignature();
      if (progress is E2eeAccountRecoveryReplacementChallengeReceivedProgress) {
        try {
          await _advanceCheckpoint(
            snapshot,
            snapshot.checkpoint.withReplacementProof(
              nonceProof: nonceProof,
              trustSignature: trustSignature,
            ),
          );
        } finally {
          clearSensitiveBytes(nonceProof);
          clearSensitiveBytes(trustSignature);
        }
      } else {
        final expectedNonce = snapshot.checkpoint.copyNonceProof();
        final expectedSignature = snapshot.checkpoint.copyTrustSignature();
        try {
          if (!_sameRecoveryBytes(nonceProof, expectedNonce) ||
              !_sameRecoveryBytes(trustSignature, expectedSignature)) {
            throw const FormatException(
              '账户恢复第二 challenge proof 与 checkpoint 不一致',
            );
          }
        } finally {
          clearSensitiveBytes(nonceProof);
          clearSensitiveBytes(trustSignature);
          clearSensitiveBytes(expectedNonce);
          clearSensitiveBytes(expectedSignature);
        }
      }
    } catch (error) {
      primaryError = error;
      rethrow;
    } finally {
      proof?.dispose();
      if (primaryError != null) {
        await _closeRecoveryResourcesPreservingPrimary(
          primaryError: primaryError,
          actions: <Future<void> Function()>[
            () async {
              await _closeRecoveryKeyLease(
                candidateKeyLease ?? proof?.keyLease,
              );
            },
            () async {
              if (opened != null) await _closeOpenedDeviceState(opened);
            },
            () => _closeReopenLease(reopenLease),
          ],
        );
      } else {
        try {
          await _closeRecoveryResources(<Future<void> Function()>[
            () async {
              if (opened != null) await _closeOpenedDeviceState(opened);
            },
            () => _closeReopenLease(reopenLease),
          ]);
        } catch (error, stackTrace) {
          await _closeRecoveryResourcesPreservingPrimary(
            primaryError: error,
            actions: <Future<void> Function()>[
              () async {
                await _closeRecoveryKeyLease(candidateKeyLease);
              },
            ],
          );
          Error.throwWithStackTrace(error, stackTrace);
        }
      }
    }
    return candidateKeyLease;
  }

  Future<CloudSyncAuthenticatedSession> _verifyCompletionSession(
    E2eeAccountRecoveryCheckpointSnapshot snapshot, {
    required String normalizedLoginName,
  }) async {
    final progress = snapshot.checkpoint.progress;
    final completionSession = switch (progress) {
      E2eeAccountRecoverySecondLocalActivatedProgress(
        :final completionSession,
      ) =>
        completionSession,
      E2eeAccountRecoverySessionVerifiedProgress(:final completionSession) =>
        completionSession,
      _ => throw StateError('账户恢复尚无完整会话凭据'),
    };
    final replacementReceipt = switch (progress) {
      E2eeAccountRecoverySecondLocalActivatedProgress(
        :final replacementReceipt,
      ) =>
        replacementReceipt,
      E2eeAccountRecoverySessionVerifiedProgress(:final replacementReceipt) =>
        replacementReceipt,
      _ => throw StateError('账户恢复尚无 replacement 回执'),
    };
    final completion = _activatedRekeyCompletion(progress);
    final reopenLease = await _openVerifiedRecoveryLease(
      normalizedLoginName: normalizedLoginName,
      checkpoint: snapshot.checkpoint,
    );
    E2eeOpenedDeviceStateHandles? opened;
    Object? primaryError;
    try {
      opened = await _openRequiredDeviceState(normalizedLoginName);
      final account = opened.binding.account;
      final ark = opened.ark;
      if (account == null || ark == null) {
        throw StateError('账户恢复完整会话缺少本地账户状态');
      }
      final binding = reopenLease.binding;
      _requireOpenedRecoveryBinding(opened: opened, binding: binding);
      final session = await _client.getAuthenticatedSession(
        token: completionSession.token,
      );
      final state = session.securityState;
      final bindingManifestDigest = binding.membershipManifestDigest;
      try {
        if (session.token.value != completionSession.token.value ||
            session.user.id != binding.userId ||
            session.user.loginName != normalizedLoginName ||
            session.device.id != binding.deviceId ||
            session.deviceKeyVersion != binding.deviceKeyVersion ||
            session.authGeneration != binding.deviceAuthGeneration ||
            session.keyEpoch != binding.keyEpoch ||
            session.keyEpoch != replacementReceipt.keyEpoch ||
            binding.dataGeneration != completion.targetDataGeneration ||
            state == null ||
            state.generation != binding.membershipGeneration ||
            state.generation != replacementReceipt.generation ||
            state.keyEpoch != binding.keyEpoch ||
            state.dataRekeyPhase != CloudSyncDataRekeyPhase.ready ||
            state.lastOperationId != binding.membershipOperationId ||
            state.lastOperationId != replacementReceipt.membershipOperationId ||
            !_sameRecoveryBytes(
              state.membershipManifestDigest.bytes,
              bindingManifestDigest,
            ) ||
            !_sameRecoveryBytes(
              completion.membershipManifestDigest,
              bindingManifestDigest,
            ) ||
            session.securityBootstrap != null ||
            session.pairingReceipt != null ||
            !session.tokenExpiresAt.isAfter(_clock().toUtc()) ||
            !_matchesPersistedRecoverySession(progress, session)) {
          throw const FormatException('账户恢复完整会话未绑定最终本地安全状态');
        }
      } finally {
        clearSensitiveBytes(bindingManifestDigest);
      }
      final historyHead = await _requireFinalAnchor(
        normalizedLoginName: normalizedLoginName,
        userId: session.user.id,
        ark: ark,
        expectedManifest: state.membershipManifest,
        expectedDigest: state.membershipManifestDigest.bytes,
        expectedGeneration: state.generation,
        expectedKeyEpoch: state.keyEpoch,
      );
      await const E2eeAccountTrustManifestModule().verifyCurrentState(
        ark: ark,
        historyHead: historyHead,
        projection: E2eeMembershipServerProjection(
          userId: session.user.id,
          securityGeneration: state.generation,
          keyEpoch: state.keyEpoch,
          membershipManifestVersion: e2eeAccountTrustManifestFormatVersion,
          membershipManifest: state.membershipManifest,
          membershipManifestDigest: state.membershipManifestDigest.bytes,
          recoveryPublicKeyVersion: state.recoveryPublicKeyVersion,
          recoveryPublicKey: state.recoveryPublicKey,
          recoveryCapsuleVersion: state.recoveryCapsuleVersion,
          recoveryCapsule: state.recoveryCapsule,
          lastOperationId: state.lastOperationId,
          dataRekeyPhase: E2eeDataRekeyPhase.ready,
        ),
      );
      return session.withVerifiedDeviceKeyVersion(binding.deviceKeyVersion);
    } catch (error) {
      primaryError = error;
      rethrow;
    } finally {
      await _closeRecoveryResourcesPreservingPrimary(
        primaryError: primaryError,
        actions: <Future<void> Function()>[
          () async {
            if (opened != null) await _closeOpenedDeviceState(opened);
          },
          () => _closeReopenLease(reopenLease),
        ],
      );
    }
  }

  Future<T> _withDataRekeyExecutor<T>({
    required String normalizedLoginName,
    required E2eeAccountRecoveryCheckpoint checkpoint,
    required E2eeAccountRecoveryPreparedTransition transition,
    required Uint8List targetStateBlob,
    required Future<T> Function(
      E2eeDataRekeyExecutor executor,
      E2eeDataRekeyExecutionContext context,
      CloudSyncDataRekeyTransport transport,
    )
    action,
  }) async {
    final opened = await _openRequiredDeviceState(normalizedLoginName);
    E2eeDataRekeyCryptographySession? cryptography;
    ChatDatabaseLease? databaseLease;
    Object? primaryError;
    try {
      final account = opened.binding.account;
      if (opened.ark == null || account == null) {
        throw StateError('账户恢复 data-rekey 缺少 unpruned ARK');
      }
      final userId = Uuid.unparse(account.userId);
      final targetEpoch = _transitionTargetKeyEpoch(transition.commit);
      cryptography = await E2eeDataRekeyCryptographySession.openTargetState(
        secureCore: _secureCore,
        issuerState: opened,
        targetStateBlob: targetStateBlob,
        userId: userId,
        targetKeyEpoch: targetEpoch,
      );
      final workspace = await _prepareWorkspace(userId);
      final gateway = ChatDatabaseGateway(
        cipher: SqlCipherDatabaseKey.forWorkspace(
          workspace.context.workspaceKey,
        ),
      );
      final databaseFile = File(
        '${workspace.dataDirectory.path}${Platform.pathSeparator}'
        '${AppDatabase.databaseFileName}',
      );
      databaseLease = await gateway.acquire(databaseFile);
      final transport = _client.accountRecoveryDataRekeyTransport(
        checkpoint.recoveryToken,
      );
      final context = E2eeDataRekeyExecutionContext(
        baseUrl: _baseUrl,
        loginName: normalizedLoginName,
        userId: userId,
        issuerDeviceId: checkpoint.expectedDeviceId,
        membershipGeneration:
            transition.commit.membership.expectedGeneration + 1,
        membershipManifestDigest:
            transition.commit.membership.nextMembershipManifestDigest.bytes,
      );
      return await action(
        E2eeDataRekeyExecutor(
          transport: transport,
          journal: databaseLease.repository.e2eeDataRekeyCommands,
          stageStore: _dataRekeyStageStore,
          cryptography: cryptography,
          clock: _clock,
        ),
        context,
        transport,
      );
    } catch (error) {
      primaryError = error;
      rethrow;
    } finally {
      await _closeRecoveryResourcesPreservingPrimary(
        primaryError: primaryError,
        actions: <Future<void> Function()>[
          () async {
            await _releaseDatabaseLease(databaseLease);
          },
          () async {
            await _closeCryptographySession(cryptography);
          },
          () => _closeOpenedDeviceState(opened),
        ],
      );
    }
  }

  Future<T> _withCompletedDataRekeyExecutor<T>({
    required String normalizedLoginName,
    required E2eeAccountRecoveryCheckpoint checkpoint,
    required CloudSyncDataRekeyCompletion completion,
    required Future<T> Function(
      E2eeDataRekeyExecutor executor,
      E2eeDataRekeyExecutionContext context,
      CloudSyncDataRekeyTransport transport,
    )
    action,
  }) async {
    final reopenLease = await _openVerifiedRecoveryLease(
      normalizedLoginName: normalizedLoginName,
      checkpoint: checkpoint,
    );
    E2eeOpenedDeviceStateHandles? opened;
    Uint8List? targetStateBlob;
    E2eeDataRekeyCryptographySession? cryptography;
    ChatDatabaseLease? databaseLease;
    Object? primaryError;
    try {
      opened = await _openRequiredDeviceState(normalizedLoginName);
      targetStateBlob = await _readRequiredStateBlob(normalizedLoginName);
      final account = opened.binding.account;
      if (opened.ark == null || account == null) {
        throw StateError('账户恢复 data-rekey 清理缺少本地账户状态');
      }
      final binding = reopenLease.binding;
      _requireOpenedRecoveryBinding(opened: opened, binding: binding);
      final userId = Uuid.unparse(account.userId);
      final bindingManifestDigest = binding.membershipManifestDigest;
      try {
        if (Uuid.unparse(opened.binding.deviceId) !=
                checkpoint.expectedDeviceId ||
            account.keyEpoch != completion.targetKeyEpoch ||
            completion.issuerDeviceId != checkpoint.expectedDeviceId ||
            binding.dataGeneration != completion.targetDataGeneration ||
            binding.membershipGeneration != completion.membershipGeneration ||
            !_sameRecoveryBytes(
              bindingManifestDigest,
              completion.membershipManifestDigest,
            )) {
          throw const FormatException('账户恢复 data-rekey 清理绑定不一致');
        }
      } finally {
        clearSensitiveBytes(bindingManifestDigest);
      }
      cryptography = await E2eeDataRekeyCryptographySession.openTargetState(
        secureCore: _secureCore,
        issuerState: opened,
        targetStateBlob: targetStateBlob,
        userId: userId,
        targetKeyEpoch: completion.targetKeyEpoch,
      );
      final workspace = await _prepareWorkspace(userId);
      final gateway = ChatDatabaseGateway(
        cipher: SqlCipherDatabaseKey.forWorkspace(
          workspace.context.workspaceKey,
        ),
      );
      databaseLease = await gateway.acquire(
        File(
          '${workspace.dataDirectory.path}${Platform.pathSeparator}'
          '${AppDatabase.databaseFileName}',
        ),
      );
      final transport = _client.accountRecoveryDataRekeyTransport(
        checkpoint.recoveryToken,
      );
      final context = E2eeDataRekeyExecutionContext(
        baseUrl: _baseUrl,
        loginName: normalizedLoginName,
        userId: userId,
        issuerDeviceId: checkpoint.expectedDeviceId,
        membershipGeneration: completion.membershipGeneration,
        membershipManifestDigest: completion.membershipManifestDigest,
      );
      return await action(
        E2eeDataRekeyExecutor(
          transport: transport,
          journal: databaseLease.repository.e2eeDataRekeyCommands,
          stageStore: _dataRekeyStageStore,
          cryptography: cryptography,
          clock: _clock,
        ),
        context,
        transport,
      );
    } catch (error) {
      primaryError = error;
      rethrow;
    } finally {
      clearSensitiveBytes(targetStateBlob);
      await _closeRecoveryResourcesPreservingPrimary(
        primaryError: primaryError,
        actions: <Future<void> Function()>[
          () async {
            await _releaseDatabaseLease(databaseLease);
          },
          () async {
            await _closeCryptographySession(cryptography);
          },
          () async {
            if (opened != null) await _closeOpenedDeviceState(opened);
          },
          () => _closeReopenLease(reopenLease),
        ],
      );
    }
  }

  Future<E2eeVerifiedMembership> _installOrAdvanceRecoveryAnchor({
    required String normalizedLoginName,
    required E2eeAccountRecoveryCheckpoint checkpoint,
    required E2eeAccountRecoveryPreparedTransition transition,
  }) async {
    final reopenLease = checkpoint.reopenBinding == null
        ? null
        : await _openVerifiedRecoveryLease(
            normalizedLoginName: normalizedLoginName,
            checkpoint: checkpoint,
          );
    E2eeOpenedDeviceStateHandles? opened;
    ChatDatabaseLease? databaseLease;
    Object? primaryError;
    try {
      opened = await _openRequiredDeviceState(normalizedLoginName);
      final ark = opened.ark;
      final account = opened.binding.account;
      if (ark == null || account == null) {
        throw StateError('账户恢复成员锚缺少 unpruned ARK');
      }
      final userId = Uuid.unparse(account.userId);
      final previous = await _verifiedPreviousMembership(
        checkpoint: checkpoint,
        transition: transition,
        ark: ark,
        userId: userId,
      );
      final next = await const E2eeAccountTrustManifestModule()
          .verifyHistoryBatch(
            previous: previous,
            entries: <E2eeMembershipHistoryEntry>[
              E2eeMembershipHistoryEntry(
                manifest: transition.commit.membership.nextMembershipManifest,
                manifestDigest: transition
                    .commit
                    .membership
                    .nextMembershipManifestDigest
                    .bytes,
              ),
            ],
          );
      final workspace = await _prepareWorkspace(userId);
      final gateway = ChatDatabaseGateway(
        cipher: SqlCipherDatabaseKey.forWorkspace(
          workspace.context.workspaceKey,
        ),
      );
      databaseLease = await gateway.acquire(
        File(
          '${workspace.dataDirectory.path}${Platform.pathSeparator}'
          '${AppDatabase.databaseFileName}',
        ),
      );
      final commands =
          databaseLease.repository.e2eeVerifiedMembershipAnchorCommands;
      final current = await commands.readVerified(
        accountUserId: userId,
        ark: ark,
      );
      if (current == null) {
        await commands.install(membership: next, now: _clock().toUtc());
      } else if (_sameRecoveryBytes(current.membership.digest, next.digest)) {
        if (!_sameRecoveryBytes(current.membership.manifest, next.manifest)) {
          throw StateError('账户恢复成员锚摘要碰撞');
        }
      } else if (_sameRecoveryBytes(
        current.membership.digest,
        previous.digest,
      )) {
        await commands.advance(
          expected: current,
          next: next,
          now: _clock().toUtc(),
        );
      } else {
        throw const E2eeVerifiedMembershipAnchorConflict();
      }
      return next;
    } catch (error) {
      primaryError = error;
      rethrow;
    } finally {
      await _closeRecoveryResourcesPreservingPrimary(
        primaryError: primaryError,
        actions: <Future<void> Function()>[
          () async {
            await _releaseDatabaseLease(databaseLease);
          },
          () async {
            if (opened != null) await _closeOpenedDeviceState(opened);
          },
          () async {
            await _closeReopenLease(reopenLease);
          },
        ],
      );
    }
  }

  Future<int> _verifyActivatedStateAndAnchor({
    required String normalizedLoginName,
    required E2eeAccountRecoveryCheckpoint checkpoint,
    required E2eeAccountRecoveryPreparedTransition transition,
    required CloudSyncDataRekeyCompletion completion,
    required E2eeVerifiedMembership membership,
  }) async {
    final reopenLease = checkpoint.reopenBinding == null
        ? null
        : await _openVerifiedRecoveryLease(
            normalizedLoginName: normalizedLoginName,
            checkpoint: checkpoint,
          );
    E2eeOpenedDeviceStateHandles? opened;
    Object? primaryError;
    try {
      opened = await _openRequiredDeviceState(normalizedLoginName);
      final account = opened.binding.account;
      final ark = opened.ark;
      if (account == null || ark == null) {
        throw StateError('账户恢复激活状态缺少账户绑定');
      }
      final userId = Uuid.unparse(account.userId);
      final localMember = membership.members.singleWhere(
        (member) => member.deviceId == checkpoint.expectedDeviceId,
      );
      final existingReopenBinding = checkpoint.reopenBinding;
      if (userId != transition.localTransitionPlan.userId ||
          userId != membership.userId ||
          Uuid.unparse(opened.binding.deviceId) !=
              checkpoint.expectedDeviceId ||
          opened.binding.keyVersion !=
              transition.localTransitionPlan.deviceKeyVersion ||
          localMember.keyVersion != opened.binding.keyVersion ||
          (existingReopenBinding != null &&
              localMember.authGeneration !=
                  existingReopenBinding.deviceAuthGeneration) ||
          account.keyEpoch != completion.targetKeyEpoch ||
          membership.keyEpoch != completion.targetKeyEpoch ||
          membership.securityGeneration != completion.membershipGeneration ||
          !_sameRecoveryBytes(
            membership.digest,
            completion.membershipManifestDigest,
          )) {
        throw const FormatException('账户恢复激活后的本地绑定不一致');
      }
      await _requireFinalAnchor(
        normalizedLoginName: normalizedLoginName,
        userId: userId,
        ark: ark,
        expectedManifest: membership.manifest,
        expectedDigest: membership.digest,
        expectedGeneration: membership.securityGeneration,
        expectedKeyEpoch: membership.keyEpoch,
      );
      return localMember.authGeneration;
    } catch (error) {
      primaryError = error;
      rethrow;
    } finally {
      await _closeRecoveryResourcesPreservingPrimary(
        primaryError: primaryError,
        actions: <Future<void> Function()>[
          () async {
            if (opened != null) await _closeOpenedDeviceState(opened);
          },
          () async {
            await _closeReopenLease(reopenLease);
          },
        ],
      );
    }
  }

  Future<E2eeVerifiedMembership> _verifiedPreviousMembership({
    required E2eeAccountRecoveryCheckpoint checkpoint,
    required E2eeAccountRecoveryPreparedTransition transition,
    required KelivoAccountRootKeyHandle ark,
    required String userId,
  }) async {
    final commit = transition.commit;
    final requestDigest = switch (commit) {
      E2eeAccountRecoveryResumeCommit() => checkpoint.challenge.requestDigest,
      E2eeAccountRecoveryReplacementCommit(:final authorization) =>
        authorization.challengeRequestDigest,
    };
    final dataRekeyPhase = commit is E2eeAccountRecoveryResumeCommit
        ? CloudSyncDataRekeyPhase.rekeyPending
        : CloudSyncDataRekeyPhase.ready;
    final history = await _readFrozenHistory(
      recoveryToken: checkpoint.recoveryToken,
      attemptId: checkpoint.attemptId,
      requestDigest: requestDigest,
      expectedGeneration: commit.membership.expectedGeneration,
      expectedKeyEpoch: commit.membership.expectedKeyEpoch,
      expectedMembershipManifestDigest:
          commit.membership.expectedMembershipManifestDigest.bytes,
      expectedRecoveryPublicKeyVersion:
          checkpoint.challenge.recoveryPublicKeyVersion,
      expectedRecoveryPublicKey: checkpoint.challenge.recoveryPublicKey,
      expectedRecoveryCapsuleVersion:
          checkpoint.challenge.recoveryCapsuleVersion,
      expectedRecoveryCapsule: checkpoint.challenge.recoveryCapsule,
      expectedDataRekeyPhase: dataRekeyPhase,
    );
    return _verifyRecoveryHistory(
      ark: ark,
      userId: userId,
      history: history,
      dataRekeyPhase: dataRekeyPhase == CloudSyncDataRekeyPhase.ready
          ? E2eeDataRekeyPhase.ready
          : E2eeDataRekeyPhase.rekeyPending,
    );
  }

  Future<E2eeVerifiedMembership> _verifyRecoveryHistory({
    required KelivoAccountRootKeyHandle ark,
    required String userId,
    required List<CloudSyncAccountSecurityHistoryItem> history,
    required E2eeDataRekeyPhase dataRekeyPhase,
  }) {
    final head = history.last;
    return const E2eeAccountTrustManifestModule().verifyRecoveryHistory(
      ark: ark,
      entries: history
          .map(
            (item) => E2eeMembershipHistoryEntry(
              manifest: item.membershipManifest,
              manifestDigest: item.membershipManifestDigest.bytes,
            ),
          )
          .toList(growable: false),
      projection: E2eeMembershipServerProjection(
        userId: userId,
        securityGeneration: head.generation,
        keyEpoch: head.keyEpoch,
        membershipManifestVersion: e2eeAccountTrustManifestFormatVersion,
        membershipManifest: head.membershipManifest,
        membershipManifestDigest: head.membershipManifestDigest.bytes,
        recoveryPublicKeyVersion: head.recoveryPublicKeyVersion,
        recoveryPublicKey: head.recoveryPublicKey,
        recoveryCapsuleVersion: head.recoveryCapsuleVersion,
        recoveryCapsule: head.recoveryCapsule,
        lastOperationId: head.operationId,
        dataRekeyPhase: dataRekeyPhase,
      ),
    );
  }

  Future<List<CloudSyncAccountSecurityHistoryItem>> _readFrozenHistory({
    required CloudSyncAccountRecoveryToken recoveryToken,
    required String attemptId,
    required Uint8List requestDigest,
    required int expectedGeneration,
    required int expectedKeyEpoch,
    required Uint8List expectedMembershipManifestDigest,
    required int expectedRecoveryPublicKeyVersion,
    required Uint8List expectedRecoveryPublicKey,
    required int expectedRecoveryCapsuleVersion,
    required Uint8List expectedRecoveryCapsule,
    required CloudSyncDataRekeyPhase expectedDataRekeyPhase,
  }) async {
    final history = <CloudSyncAccountSecurityHistoryItem>[];
    var afterGeneration = 0;
    for (;;) {
      final page = await _client.listFrozenHistory(
        authorization: E2eeAccountRecoveryBearer.recovery(recoveryToken),
        attemptId: attemptId,
        challengeRequestDigest: requestDigest,
        afterGeneration: afterGeneration,
        pageSize: e2eeAccountRecoveryHistoryPageSize,
      );
      final current = page.currentState;
      if (page.afterGeneration != afterGeneration ||
          current.generation != expectedGeneration ||
          current.keyEpoch != expectedKeyEpoch ||
          current.dataRekeyPhase != expectedDataRekeyPhase ||
          !_sameRecoveryBytes(
            current.membershipManifestDigest.bytes,
            expectedMembershipManifestDigest,
          ) ||
          current.recoveryPublicKeyVersion !=
              expectedRecoveryPublicKeyVersion ||
          !_sameRecoveryBytes(
            current.recoveryPublicKey,
            expectedRecoveryPublicKey,
          ) ||
          current.recoveryCapsuleVersion != expectedRecoveryCapsuleVersion) {
        throw const FormatException('账户恢复冻结历史投影不一致');
      }
      history.addAll(page.items);
      if (history.length > e2eeAccountRecoveryMaximumHistoryEntries) {
        throw const FormatException('账户恢复冻结历史超过安全上限');
      }
      afterGeneration = page.nextAfterGeneration;
      if (!page.hasMore) break;
    }
    if (history.length != expectedGeneration ||
        history.isEmpty ||
        history.first.generation != 1 ||
        history.last.generation != expectedGeneration ||
        history.last.keyEpoch != expectedKeyEpoch ||
        !_sameRecoveryBytes(
          history.last.membershipManifestDigest.bytes,
          expectedMembershipManifestDigest,
        ) ||
        history.last.recoveryPublicKeyVersion !=
            expectedRecoveryPublicKeyVersion ||
        !_sameRecoveryBytes(
          history.last.recoveryPublicKey,
          expectedRecoveryPublicKey,
        ) ||
        history.last.recoveryCapsuleVersion != expectedRecoveryCapsuleVersion ||
        !_sameRecoveryBytes(
          history.last.recoveryCapsule,
          expectedRecoveryCapsule,
        )) {
      throw const FormatException('账户恢复冻结历史不完整');
    }
    return List<CloudSyncAccountSecurityHistoryItem>.unmodifiable(history);
  }

  Future<void> _requirePreparedSourceState(
    E2eeAccountRecoveryCheckpointSnapshot snapshot, {
    required String normalizedLoginName,
  }) async {
    final transition = _preparedTransition(snapshot.checkpoint.progress);
    final reopenLease = snapshot.checkpoint.reopenBinding == null
        ? null
        : await _openVerifiedRecoveryLease(
            normalizedLoginName: normalizedLoginName,
            checkpoint: snapshot.checkpoint,
          );
    DeviceStateBlobSnapshot? current;
    Uint8List? source;
    Object? primaryError;
    try {
      current = await _deviceStateStore.readVersioned(
        normalizedBaseUrl: _baseUrl,
        normalizedLoginName: normalizedLoginName,
      );
      if (current == null) throw StateError('账户恢复设备状态不存在');
      source = transition.localTransitionPlan.sourceStateBlob;
      if (!_sameRecoveryBytes(current.blob, source)) {
        throw StateError('账户恢复 prepared checkpoint 未绑定精确 source 状态');
      }
    } catch (error) {
      primaryError = error;
      rethrow;
    } finally {
      clearSensitiveBytes(current?.blob);
      clearSensitiveBytes(source);
      await _closeRecoveryResourcesPreservingPrimary(
        primaryError: primaryError,
        actions: <Future<void> Function()>[
          () => _closeReopenLease(reopenLease),
        ],
      );
    }
  }

  Future<void> _ensureUnprunedStatePublished(
    String normalizedLoginName,
    E2eeAccountRecoveryLocalTransitionPlan plan, {
    required bool allowSource,
    required bool allowPruned,
  }) async {
    final snapshot = await _deviceStateStore.readVersioned(
      normalizedBaseUrl: _baseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    if (snapshot == null) throw StateError('账户恢复设备状态不存在');
    final source = plan.sourceStateBlob;
    final unpruned = plan.unprunedStateBlob;
    final pruned = plan.prunedStateBlob;
    try {
      if (_sameRecoveryBytes(snapshot.blob, unpruned)) {
        return;
      }
      if (_sameRecoveryBytes(snapshot.blob, pruned)) {
        if (allowPruned) return;
        throw StateError('账户恢复 committed checkpoint 不得对应 pruned 状态');
      }
      if (!_sameRecoveryBytes(snapshot.blob, source)) {
        throw StateError('账户恢复设备状态与 prepared checkpoint 不一致');
      }
      if (!allowSource) {
        throw StateError('账户恢复 finalized checkpoint 不得回退到 source 状态');
      }
      await _deviceStateStore.compareAndSwap(
        normalizedBaseUrl: _baseUrl,
        normalizedLoginName: normalizedLoginName,
        expectedVersion: snapshot.version,
        blob: unpruned,
      );
    } finally {
      clearSensitiveBytes(snapshot.blob);
      clearSensitiveBytes(source);
      clearSensitiveBytes(unpruned);
      clearSensitiveBytes(pruned);
    }
  }

  Future<void> _publishPrunedState(
    String normalizedLoginName,
    E2eeAccountRecoveryLocalTransitionPlan plan,
    Uint8List activated,
  ) async {
    final snapshot = await _deviceStateStore.readVersioned(
      normalizedBaseUrl: _baseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    if (snapshot == null) throw StateError('账户恢复设备状态不存在');
    final unpruned = plan.unprunedStateBlob;
    final pruned = plan.prunedStateBlob;
    try {
      if (!_sameRecoveryBytes(activated, pruned)) {
        throw StateError('账户恢复 Native 激活结果不是精确 pruned 候选');
      }
      if (_sameRecoveryBytes(snapshot.blob, pruned)) return;
      if (!_sameRecoveryBytes(snapshot.blob, unpruned)) {
        throw StateError('账户恢复设备状态无法发布 pruned 候选');
      }
      await _deviceStateStore.compareAndSwap(
        normalizedBaseUrl: _baseUrl,
        normalizedLoginName: normalizedLoginName,
        expectedVersion: snapshot.version,
        blob: pruned,
      );
    } finally {
      clearSensitiveBytes(snapshot.blob);
      clearSensitiveBytes(unpruned);
      clearSensitiveBytes(pruned);
    }
  }

  Future<E2eeVerifiedMembership> _requireFinalAnchor({
    required String normalizedLoginName,
    required String userId,
    required KelivoAccountRootKeyHandle ark,
    required Uint8List expectedManifest,
    required Uint8List expectedDigest,
    required int expectedGeneration,
    required int expectedKeyEpoch,
  }) async {
    final workspace = await _prepareWorkspace(userId);
    final gateway = ChatDatabaseGateway(
      cipher: SqlCipherDatabaseKey.forWorkspace(workspace.context.workspaceKey),
    );
    final lease = await gateway.acquire(
      File(
        '${workspace.dataDirectory.path}${Platform.pathSeparator}'
        '${AppDatabase.databaseFileName}',
      ),
    );
    Object? primaryError;
    try {
      final anchor = await lease.repository.e2eeVerifiedMembershipAnchorCommands
          .readVerified(accountUserId: userId, ark: ark);
      if (anchor == null ||
          anchor.membership.userId != userId ||
          anchor.membership.securityGeneration != expectedGeneration ||
          anchor.membership.keyEpoch != expectedKeyEpoch ||
          !_sameRecoveryBytes(anchor.membership.manifest, expectedManifest) ||
          !_sameRecoveryBytes(anchor.membership.digest, expectedDigest)) {
        throw StateError('账户恢复最终成员锚与完整会话不一致');
      }
      return anchor.membership;
    } catch (error) {
      primaryError = error;
      rethrow;
    } finally {
      await _closeRecoveryResourcesPreservingPrimary(
        primaryError: primaryError,
        actions: <Future<void> Function()>[() => _releaseDatabaseLease(lease)],
      );
    }
  }

  Future<_RecoveryCheckpointLease?> _tryOpenCheckpointLease(
    String normalizedLoginName,
  ) async {
    final slotId = E2eeDeviceStateAccess.deriveSlotId(
      normalizedBaseUrl: _baseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    try {
      final key = await _secureCore.openSlot(slotId);
      return _RecoveryCheckpointLease(
        secureCore: _secureCore,
        key: key,
        store: E2eeAccountRecoveryCheckpointStore(
          normalizedBaseUrl: _baseUrl,
          normalizedLoginName: normalizedLoginName,
          deviceStateStore: _deviceStateStore,
          secureCore: _secureCore,
          key: key,
        ),
      );
    } on KelivoSecureCoreException catch (error) {
      if (error.status == KelivoSecureCoreStatus.slotNotFound) return null;
      rethrow;
    } finally {
      clearSensitiveBytes(slotId);
    }
  }

  Future<AccountRecoveryWorkspaceLease> _prepareWorkspace(String userId) async {
    final current = _workspaceLease;
    if (current != null) {
      if (_workspaceUserId != userId) {
        throw StateError('账户恢复目标工作区用户不一致');
      }
      current.context;
      return current;
    }
    final prepared = await _workspaceRuntime.prepareAccountWorkspace(
      canonicalBaseUrl: _baseUrl,
      userId: userId,
    );
    _workspaceLease = prepared;
    _workspaceUserId = userId;
    return prepared;
  }

  Future<void> _closeWorkspaceLease() async {
    final lease = _workspaceLease;
    await lease?.close();
    if (identical(_workspaceLease, lease)) {
      _workspaceLease = null;
      _workspaceUserId = null;
    }
  }

  Future<_RecoveryCheckpointLease> _openRequiredCheckpointLease(
    String normalizedLoginName,
  ) async {
    final lease = await _tryOpenCheckpointLease(normalizedLoginName);
    if (lease == null) throw StateError('账户恢复本机密钥槽不存在');
    return lease;
  }

  _RecoveryCheckpointLease _requiredCheckpointLease() {
    return _checkpointLease ?? (throw StateError('账户恢复 checkpoint 密钥租约不存在'));
  }

  Future<E2eeAccountRecoveryCheckpointSnapshot> _advanceCheckpoint(
    E2eeAccountRecoveryCheckpointSnapshot snapshot,
    E2eeAccountRecoveryCheckpoint checkpoint,
  ) async {
    E2eeAccountRecoveryCheckpointSnapshot? advanced;
    try {
      advanced = await _requiredCheckpointLease().store.advance(
        expectedEnvelopeDigest: snapshot.envelopeDigest,
        checkpoint: checkpoint,
      );
      return advanced;
    } finally {
      final retainedCheckpoint = advanced?.checkpoint;
      if (!identical(checkpoint, retainedCheckpoint)) {
        checkpoint.clearSensitiveState();
      }
      if (!identical(snapshot.checkpoint, retainedCheckpoint) &&
          !identical(snapshot.checkpoint, checkpoint)) {
        snapshot.clearSensitiveState();
      }
    }
  }

  Future<E2eeOpenedDeviceStateHandles> _openRequiredDeviceState(
    String normalizedLoginName,
  ) async {
    final opened = await E2eeDeviceStateAccess(
      baseUrl: _baseUrl,
      deviceStateStore: _deviceStateStore,
      secureCore: _secureCore,
    ).openExisting(normalizedLoginName);
    if (opened == null) throw StateError('账户恢复设备状态不存在');
    return opened;
  }

  Future<E2eeAccountRecoveryReopenLease> _openVerifiedRecoveryLease({
    required String normalizedLoginName,
    required E2eeAccountRecoveryCheckpoint checkpoint,
  }) async {
    final expectedBinding = checkpoint.reopenBinding;
    if (expectedBinding == null) {
      throw StateError('账户恢复 checkpoint 尚无重开绑定');
    }
    await _prepareWorkspace(expectedBinding.userId);
    final lease = await _authentication.reopenRecovery(
      loginName: normalizedLoginName,
      checkpoint: checkpoint,
    );
    try {
      if (!_sameRecoveryReopenBinding(lease.binding, expectedBinding)) {
        throw const FormatException('账户恢复重开租约与 checkpoint 不一致');
      }
      await lease.requireCurrentState();
      return lease;
    } catch (error) {
      await _closeRecoveryResourcesPreservingPrimary(
        primaryError: error,
        actions: <Future<void> Function()>[() => _closeReopenLease(lease)],
      );
      rethrow;
    }
  }

  Future<void> _closeReopenLease(E2eeAccountRecoveryReopenLease? lease) async {
    if (lease == null) return;
    try {
      await lease.close();
      _pendingReopenLeases.remove(lease);
    } catch (_) {
      if (!_pendingReopenLeases.contains(lease)) {
        _pendingReopenLeases.add(lease);
      }
      rethrow;
    }
  }

  Future<void> _closeRecoveryKeyLease(E2eeAccountRecoveryKeyLease? lease) {
    return _closeTrackedResource(lease, (value) => value.close());
  }

  Future<void> _releaseDatabaseLease(ChatDatabaseLease? lease) {
    return _closeTrackedResource(lease, (value) => value.release());
  }

  Future<void> _closeCryptographySession(
    E2eeDataRekeyCryptographySession? session,
  ) {
    return _closeTrackedResource(session, (value) => value.close());
  }

  Future<void> _closeTrackedResource<T extends Object>(
    T? resource,
    Future<void> Function(T resource) close,
  ) async {
    if (resource == null) return;
    _PendingRecoveryResourceCleanup? cleanup;
    for (final candidate in _pendingResourceCleanups) {
      if (identical(candidate.resource, resource)) {
        cleanup = candidate;
        break;
      }
    }
    cleanup ??= _PendingRecoveryResourceCleanup(
      resource: resource,
      close: () => close(resource),
    );
    try {
      await cleanup.close();
      _pendingResourceCleanups.remove(cleanup);
    } catch (_) {
      if (!_pendingResourceCleanups.contains(cleanup)) {
        _pendingResourceCleanups.add(cleanup);
      }
      rethrow;
    }
  }

  Future<void> _drainPendingResourceCleanups() async {
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final cleanup in List<_PendingRecoveryResourceCleanup>.of(
      _pendingResourceCleanups,
    )) {
      try {
        await cleanup.close();
        _pendingResourceCleanups.remove(cleanup);
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    if (firstError != null && firstStackTrace != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace);
    }
  }

  Future<void> _drainPendingReopenLeases() async {
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final lease in List<E2eeAccountRecoveryReopenLease>.of(
      _pendingReopenLeases,
    )) {
      try {
        await lease.close();
        _pendingReopenLeases.remove(lease);
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    if (firstError != null && firstStackTrace != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace);
    }
  }

  void _requireOpenedRecoveryBinding({
    required E2eeOpenedDeviceStateHandles opened,
    required E2eeAccountRecoveryReopenBinding binding,
  }) {
    final account = opened.binding.account;
    final ark = opened.ark;
    if (account == null ||
        ark == null ||
        Uuid.unparse(account.userId) != binding.userId ||
        Uuid.unparse(ark.userId) != binding.userId ||
        Uuid.unparse(opened.binding.deviceId) != binding.deviceId ||
        opened.binding.keyVersion != binding.deviceKeyVersion ||
        account.keyEpoch != binding.keyEpoch) {
      throw const FormatException('账户恢复设备状态与重开绑定不一致');
    }
  }

  Future<Uint8List> _readRequiredStateBlob(String normalizedLoginName) async {
    final snapshot = await _deviceStateStore.readVersioned(
      normalizedBaseUrl: _baseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    if (snapshot == null) throw StateError('账户恢复设备状态不存在');
    return snapshot.blob;
  }

  Future<void> _closeOpenedDeviceState(
    E2eeOpenedDeviceStateHandles opened,
  ) async {
    final cleanup = _RecoveryOpenedDeviceStateCleanup(opened);
    try {
      await cleanup.close(_secureCore);
    } catch (_) {
      if (!cleanup.isClosed && !_pendingOpenedStateCleanups.contains(cleanup)) {
        _pendingOpenedStateCleanups.add(cleanup);
      }
      rethrow;
    }
  }

  Future<void> _drainPendingOpenedStateCleanups() async {
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final cleanup in List<_RecoveryOpenedDeviceStateCleanup>.of(
      _pendingOpenedStateCleanups,
    )) {
      try {
        await cleanup.close(_secureCore);
        _pendingOpenedStateCleanups.remove(cleanup);
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    if (firstError != null && firstStackTrace != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace);
    }
  }
}

final class _PendingRecoveryResourceCleanup {
  const _PendingRecoveryResourceCleanup({
    required this.resource,
    required this.close,
  });

  final Object resource;
  final Future<void> Function() close;
}

final class _RecoveryOpenedDeviceStateCleanup {
  _RecoveryOpenedDeviceStateCleanup(E2eeOpenedDeviceStateHandles opened)
    : _key = opened.key,
      _identity = opened.identity,
      _ark = opened.ark;

  KelivoKeyHandle? _key;
  KelivoDeviceIdentityHandle? _identity;
  KelivoAccountRootKeyHandle? _ark;

  bool get isClosed => _key == null && _identity == null && _ark == null;

  Future<void> close(KelivoSecureCore secureCore) async {
    Object? firstError;
    StackTrace? firstStackTrace;

    Future<void> capture(Future<void> Function() action) async {
      try {
        await action();
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    final ark = _ark;
    if (ark != null) {
      await capture(() async {
        await secureCore.closeAccountRootKey(ark);
        if (identical(_ark, ark)) _ark = null;
      });
    }
    final identity = _identity;
    if (identity != null) {
      await capture(() async {
        await secureCore.closeDeviceIdentity(identity);
        if (identical(_identity, identity)) _identity = null;
      });
    }
    final key = _key;
    if (key != null) {
      await capture(() async {
        await secureCore.close(key);
        if (identical(_key, key)) _key = null;
      });
    }
    if (firstError != null && firstStackTrace != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
  }
}

final class _RecoveryCheckpointLease {
  _RecoveryCheckpointLease({
    required this.secureCore,
    required this.key,
    required this.store,
  });

  final KelivoSecureCore secureCore;
  final KelivoKeyHandle key;
  final E2eeAccountRecoveryCheckpointStore store;
  bool _closed = false;

  Future<void> close() async {
    if (_closed) return;
    await secureCore.close(key);
    _closed = true;
  }
}

void _requireOnboardingBinding(
  E2eeAccountRecoveryOnboardingLease lease, {
  required String normalizedLoginName,
  required CloudSyncPlatform platform,
  required String clientVersion,
}) {
  if (lease.loginName != normalizedLoginName ||
      lease.platform != platform ||
      lease.clientVersion != clientVersion ||
      lease.targetAuthGeneration != lease.sourceAuthGeneration + 1 ||
      !lease.onboardingTokenExpiresAt.isAfter(DateTime.now().toUtc())) {
    throw const FormatException('账户恢复 onboarding 租约绑定不一致');
  }
}

bool _requiresOnboarding(E2eeAccountRecoveryCheckpointPhase phase) {
  return phase == E2eeAccountRecoveryCheckpointPhase.challenged ||
      phase == E2eeAccountRecoveryCheckpointPhase.proofReady ||
      phase == E2eeAccountRecoveryCheckpointPhase.authorized;
}

String _normalizeRecoveryLoginName(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.length < 3 ||
      normalized.length > 64 ||
      !RegExp(r'^[a-z0-9][a-z0-9._-]*$').hasMatch(normalized)) {
    throw const FormatException('账户恢复登录名无效');
  }
  return normalized;
}

E2eeAccountRecoveryPreparedTransition _resumePreparedTransition({
  required E2eeAccountRecoveryCheckpoint checkpoint,
  required String operationId,
  required String rekeyOperationId,
  required KelivoPreparedAccountRecoveryCommit prepared,
  required KelivoPreparedAccountRecoveryDeviceStates states,
  required Uint8List sourceStateBlob,
}) {
  _requireNativePrepared(
    checkpoint: checkpoint,
    prepared: prepared,
    kind: KelivoAccountRecoveryCommitKind.resume,
    rekeyOperationId: rekeyOperationId,
  );
  return E2eeAccountRecoveryPreparedTransition(
    commit: E2eeAccountRecoveryResumeCommit(
      attemptId: checkpoint.attemptId,
      membership: _membershipCommit(
        checkpoint: checkpoint,
        operationId: operationId,
        prepared: prepared,
      ),
      rekeyOperationId: rekeyOperationId,
    ),
    localTransitionPlan: _localTransitionPlan(
      prepared: prepared,
      states: states,
      sourceStateBlob: sourceStateBlob,
    ),
  );
}

E2eeAccountRecoveryPreparedTransition _replacementPreparedTransition({
  required E2eeAccountRecoveryCheckpoint checkpoint,
  required String operationId,
  required String completionSessionId,
  required CloudSyncFullSessionToken completionSessionToken,
  required KelivoPreparedAccountRecoveryCommit prepared,
  required KelivoPreparedAccountRecoveryDeviceStates states,
  required Uint8List sourceStateBlob,
  required E2eeAccountRecoveryReplacementChallenge? replacementChallenge,
}) {
  _requireNativePrepared(
    checkpoint: checkpoint,
    prepared: prepared,
    kind: KelivoAccountRecoveryCommitKind.replacement,
    replacementChallenge: replacementChallenge,
    rekeyOperationId: operationId,
  );
  final recoveryCapsule = prepared.recoveryCapsule;
  if (recoveryCapsule == null) {
    throw StateError('账户恢复 replacement 未生成新 capsule');
  }
  final authorization = replacementChallenge == null
      ? E2eeAccountRecoveryReplacementAuthorization.initial(
          challengeRequestDigest: checkpoint.challenge.requestDigest,
        )
      : E2eeAccountRecoveryReplacementAuthorization.replacementChallenge(
          challengeId: replacementChallenge.challengeId,
          challengeRequestDigest: replacementChallenge.requestDigest,
          nonceProof: checkpoint.copyNonceProof(),
          trustSignature: checkpoint.copyTrustSignature(),
        );
  return E2eeAccountRecoveryPreparedTransition(
    commit: E2eeAccountRecoveryReplacementCommit(
      attemptId: checkpoint.attemptId,
      membership: _membershipCommit(
        checkpoint: checkpoint,
        operationId: operationId,
        prepared: prepared,
        replacementChallenge: replacementChallenge,
      ),
      authorization: authorization,
      nextRecoveryCapsuleVersion: prepared.nextRecoveryCapsuleVersion,
      nextRecoveryCapsule: recoveryCapsule,
      completionSessionId: completionSessionId,
      completionSessionToken: completionSessionToken,
    ),
    localTransitionPlan: _localTransitionPlan(
      prepared: prepared,
      states: states,
      sourceStateBlob: sourceStateBlob,
    ),
  );
}

E2eeAccountRecoveryMembershipCommit _membershipCommit({
  required E2eeAccountRecoveryCheckpoint checkpoint,
  required String operationId,
  required KelivoPreparedAccountRecoveryCommit prepared,
  E2eeAccountRecoveryReplacementChallenge? replacementChallenge,
}) {
  final expectedDigest =
      replacementChallenge?.membershipManifestDigest ??
      checkpoint.challenge.membershipManifestDigest;
  return E2eeAccountRecoveryMembershipCommit(
    expectedGeneration: prepared.expectedGeneration,
    expectedKeyEpoch: prepared.expectedKeyEpoch,
    expectedMembershipManifestDigest:
        CloudSyncMembershipManifestDigest.fromBytes(expectedDigest),
    operationId: operationId,
    nextMembershipManifest: prepared.membershipManifest,
    nextMembershipManifestDigest: CloudSyncMembershipManifestDigest.fromBytes(
      prepared.manifestDigest,
    ),
    envelope: E2eeAccountRecoveryEnvelope(
      envelopeVersion: 1,
      keyEpoch: prepared.nextKeyEpoch,
      accountKeyEnvelope: prepared.accountKeyEnvelope,
    ),
  );
}

E2eeAccountRecoveryLocalTransitionPlan _localTransitionPlan({
  required KelivoPreparedAccountRecoveryCommit prepared,
  required KelivoPreparedAccountRecoveryDeviceStates states,
  required Uint8List sourceStateBlob,
}) {
  final binding = prepared.stateBinding;
  Uint8List? continuation;
  try {
    continuation = states.takeContinuation();
    return E2eeAccountRecoveryLocalTransitionPlan(
      sourceStateBlob: sourceStateBlob,
      unprunedStateBlob: states.unprunedStateBlob,
      prunedStateBlob: states.prunedCandidate,
      deviceKeyVersion: binding.deviceKeyVersion,
      userId: Uuid.unparse(binding.userId),
      sourceDataGeneration: binding.sourceDataGeneration,
      operationAuthorizationDigest: binding.operationAuthorizationDigest,
      continuation: continuation,
    );
  } finally {
    clearSensitiveBytes(continuation);
  }
}

void _requireNativePrepared({
  required E2eeAccountRecoveryCheckpoint checkpoint,
  required KelivoPreparedAccountRecoveryCommit prepared,
  required KelivoAccountRecoveryCommitKind kind,
  required String rekeyOperationId,
  E2eeAccountRecoveryReplacementChallenge? replacementChallenge,
}) {
  final expectedGeneration =
      replacementChallenge?.securityGeneration ??
      checkpoint.challenge.securityGeneration;
  final expectedKeyEpoch =
      replacementChallenge?.keyEpoch ?? checkpoint.challenge.keyEpoch;
  final expectedDigest =
      replacementChallenge?.membershipManifestDigest ??
      checkpoint.challenge.membershipManifestDigest;
  final expectedRequestDigest =
      replacementChallenge?.requestDigest ?? checkpoint.challenge.requestDigest;
  final expectedSourceDataGeneration =
      replacementChallenge?.dataGeneration ??
      checkpoint.challenge.dataState.dataGeneration;
  final expectedSourceKeyEpoch = kind == KelivoAccountRecoveryCommitKind.resume
      ? checkpoint.challenge.dataState.dataKeyEpoch
      : expectedKeyEpoch;
  final expectedTargetKeyEpoch = kind == KelivoAccountRecoveryCommitKind.resume
      ? expectedKeyEpoch
      : expectedKeyEpoch + 1;
  final expectedCapsuleVersion = kind == KelivoAccountRecoveryCommitKind.resume
      ? (replacementChallenge?.recoveryCapsuleVersion ??
            checkpoint.challenge.recoveryCapsuleVersion)
      : (replacementChallenge?.recoveryCapsuleVersion ??
                checkpoint.challenge.recoveryCapsuleVersion) +
            1;
  final binding = prepared.stateBinding;
  final manifestDigest = Uint8List.fromList(
    sha256.convert(prepared.membershipManifest).bytes,
  );
  final expectedDeviceId = Uint8List.fromList(
    Uuid.parseAsByteList(checkpoint.expectedDeviceId),
  );
  final expectedRekeyOperationId = Uint8List.fromList(
    Uuid.parseAsByteList(rekeyOperationId),
  );
  if (prepared.kind != kind ||
      prepared.expectedGeneration != expectedGeneration ||
      prepared.expectedKeyEpoch != expectedKeyEpoch ||
      prepared.nextGeneration != expectedGeneration + 1 ||
      prepared.nextKeyEpoch != expectedTargetKeyEpoch ||
      prepared.nextRecoveryCapsuleVersion != expectedCapsuleVersion ||
      (kind == KelivoAccountRecoveryCommitKind.resume &&
          prepared.recoveryCapsule != null) ||
      (kind == KelivoAccountRecoveryCommitKind.replacement &&
          prepared.recoveryCapsule == null) ||
      !_sameRecoveryBytes(prepared.requestDigest, expectedRequestDigest) ||
      !_sameRecoveryBytes(prepared.manifestDigest, manifestDigest) ||
      binding.kind != kind ||
      binding.dataPhase !=
          (kind == KelivoAccountRecoveryCommitKind.resume
              ? KelivoAccountRecoveryDataPhase.rekeyPending
              : KelivoAccountRecoveryDataPhase.ready) ||
      binding.sourceKeyEpoch != expectedSourceKeyEpoch ||
      binding.targetKeyEpoch != expectedTargetKeyEpoch ||
      binding.sourceDataGeneration != expectedSourceDataGeneration ||
      binding.targetDataGeneration != expectedSourceDataGeneration + 1 ||
      binding.membershipGeneration != expectedGeneration + 1 ||
      !_sameRecoveryBytes(binding.membershipManifestDigest, manifestDigest) ||
      !_sameRecoveryBytes(binding.deviceId, expectedDeviceId) ||
      !_sameRecoveryBytes(binding.rekeyOperationId, expectedRekeyOperationId) ||
      expectedDigest.length != cloudSyncMembershipManifestDigestBytes ||
      (replacementChallenge != null &&
          binding.deviceKeyVersion != replacementChallenge.deviceKeyVersion)) {
    clearSensitiveBytes(manifestDigest);
    clearSensitiveBytes(expectedDeviceId);
    clearSensitiveBytes(expectedRekeyOperationId);
    // 诊断：记录绑定字段差异，便于定位服务端/密码学不匹配。
    print(
      'RECOVERY_BINDING_MISMATCH: kind=$kind prepared.kind=${prepared.kind} '
      'expGen=$expectedGeneration pGen=${prepared.expectedGeneration} '
      'expEpoch=$expectedKeyEpoch pEpoch=${prepared.expectedKeyEpoch} '
      'expNextGen=${expectedGeneration + 1} pNextGen=${prepared.nextGeneration} '
      'expNextEpoch=$expectedTargetKeyEpoch pNextEpoch=${prepared.nextKeyEpoch} '
      'capExp=$expectedCapsuleVersion cap=${prepared.nextRecoveryCapsuleVersion} '
      'hasCap=${prepared.recoveryCapsule != null} '
      'reqDigest=${_sameRecoveryBytes(
        prepared.requestDigest,
        expectedRequestDigest,
      )} '
      'manifest=${_sameRecoveryBytes(prepared.manifestDigest, manifestDigest)} '
      'bKind=${binding.kind} bPhase=${binding.dataPhase} '
      'srcEp=${binding.sourceKeyEpoch} exp=$expectedSourceKeyEpoch '
      'tgtEp=${binding.targetKeyEpoch} exp=$expectedTargetKeyEpoch '
      'srcGen=${binding.sourceDataGeneration} exp=$expectedSourceDataGeneration '
      'tgtGen=${binding.targetDataGeneration} '
      'exp=${expectedSourceDataGeneration + 1} '
      'memGen=${binding.membershipGeneration} exp=${expectedGeneration + 1} '
      'memDigestLen=${binding.membershipManifestDigest.length} '
      'expLen=$cloudSyncMembershipManifestDigestBytes '
      'devId=${_sameRecoveryBytes(binding.deviceId, expectedDeviceId)} '
      'rekey=${_sameRecoveryBytes(
        binding.rekeyOperationId,
        expectedRekeyOperationId,
      )} '
      'devKeyVer=${binding.deviceKeyVersion} '
      'challenge=${replacementChallenge?.deviceKeyVersion}',
    );
    throw const FormatException('账户恢复 Native prepared 绑定不一致');
  }
  clearSensitiveBytes(manifestDigest);
  clearSensitiveBytes(expectedDeviceId);
  clearSensitiveBytes(expectedRekeyOperationId);
}

KelivoPreparedAccountRecoveryStateBinding _nativeStateBinding(
  E2eeAccountRecoveryPreparedTransition transition, {
  required E2eeAccountRecoveryCheckpoint checkpoint,
}) {
  final commit = transition.commit;
  final plan = transition.localTransitionPlan;
  final rekeyOperationId = _transitionRekeyOperationId(commit);
  final authorizationDigest = plan.operationAuthorizationDigest;
  try {
    return KelivoPreparedAccountRecoveryStateBinding(
      kind: commit is E2eeAccountRecoveryResumeCommit
          ? KelivoAccountRecoveryCommitKind.resume
          : KelivoAccountRecoveryCommitKind.replacement,
      dataPhase: commit is E2eeAccountRecoveryResumeCommit
          ? KelivoAccountRecoveryDataPhase.rekeyPending
          : KelivoAccountRecoveryDataPhase.ready,
      deviceKeyVersion: plan.deviceKeyVersion,
      userId: Uint8List.fromList(Uuid.parseAsByteList(plan.userId)),
      deviceId: Uint8List.fromList(
        Uuid.parseAsByteList(checkpoint.expectedDeviceId),
      ),
      sourceKeyEpoch: commit is E2eeAccountRecoveryResumeCommit
          ? checkpoint.challenge.dataState.dataKeyEpoch
          : commit.membership.expectedKeyEpoch,
      targetKeyEpoch: _transitionTargetKeyEpoch(commit),
      sourceDataGeneration: plan.sourceDataGeneration,
      targetDataGeneration: plan.sourceDataGeneration + 1,
      membershipGeneration: commit.membership.expectedGeneration + 1,
      membershipManifestDigest:
          commit.membership.nextMembershipManifestDigest.bytes,
      rekeyOperationId: Uint8List.fromList(
        Uuid.parseAsByteList(rekeyOperationId),
      ),
      operationAuthorizationDigest: authorizationDigest,
    );
  } finally {
    clearSensitiveBytes(authorizationDigest);
  }
}

E2eeAccountRecoveryPreparedTransition _committedTransition(
  E2eeAccountRecoveryCheckpointProgress progress,
) => switch (progress) {
  E2eeAccountRecoveryResumeCommittedProgress(:final transition) => transition,
  E2eeAccountRecoveryReplacementCommittedProgress(:final transition) =>
    transition,
  _ => throw StateError('账户恢复 checkpoint 不处于 committed 阶段'),
};

E2eeAccountRecoveryPreparedTransition _preparedTransition(
  E2eeAccountRecoveryCheckpointProgress progress,
) => switch (progress) {
  E2eeAccountRecoveryResumePreparedProgress(:final transition) => transition,
  E2eeAccountRecoveryReplacementPreparedProgress(:final transition) =>
    transition,
  _ => throw StateError('账户恢复 checkpoint 不处于 prepared 阶段'),
};

E2eeAccountRecoveryPreparedTransition _finalizedTransition(
  E2eeAccountRecoveryCheckpointProgress progress,
) => switch (progress) {
  E2eeAccountRecoveryFirstRekeyFinalizedProgress(:final transition) =>
    transition,
  E2eeAccountRecoverySecondRekeyFinalizedProgress(:final transition) =>
    transition,
  _ => throw StateError('账户恢复 checkpoint 不处于 finalized 阶段'),
};

CloudSyncDataRekeyCompletion _finalizedCompletion(
  E2eeAccountRecoveryCheckpointProgress progress,
) => switch (progress) {
  E2eeAccountRecoveryFirstRekeyFinalizedProgress(:final completion) =>
    completion,
  E2eeAccountRecoverySecondRekeyFinalizedProgress(:final completion) =>
    completion,
  _ => throw StateError('账户恢复 checkpoint 缺少 data-rekey 完成证明'),
};

CloudSyncDataRekeyCompletion _activatedRekeyCompletion(
  E2eeAccountRecoveryCheckpointProgress progress,
) => switch (progress) {
  E2eeAccountRecoveryFirstLocalActivatedProgress(:final completion) =>
    completion,
  E2eeAccountRecoveryReplacementChallengeRequestedProgress(:final completion) =>
    completion,
  E2eeAccountRecoverySecondLocalActivatedProgress(:final completion) =>
    completion,
  E2eeAccountRecoverySessionVerifiedProgress(:final completion) => completion,
  _ => throw StateError('账户恢复 checkpoint 不处于本地激活阶段'),
};

String _transitionRekeyOperationId(E2eeAccountRecoveryPreparedCommit commit) =>
    switch (commit) {
      E2eeAccountRecoveryResumeCommit(:final rekeyOperationId) =>
        rekeyOperationId,
      E2eeAccountRecoveryReplacementCommit() => commit.membership.operationId,
    };

int _transitionTargetKeyEpoch(E2eeAccountRecoveryPreparedCommit commit) {
  return switch (commit) {
    E2eeAccountRecoveryResumeCommit() => commit.membership.expectedKeyEpoch,
    E2eeAccountRecoveryReplacementCommit() =>
      commit.membership.expectedKeyEpoch + 1,
  };
}

Uint8List _sourceCapsule(
  int currentKeyEpoch,
  List<CloudSyncAccountSecurityHistoryItem> history,
) {
  if (currentKeyEpoch <= 1) {
    throw const FormatException('账户恢复第二 challenge 不存在前驱 capsule');
  }
  final sourceEpoch = currentKeyEpoch - 1;
  CloudSyncAccountSecurityHistoryItem? source;
  for (var index = 0; index < history.length - 1; index++) {
    final candidate = history[index];
    final successor = history[index + 1];
    if (candidate.keyEpoch == sourceEpoch &&
        successor.keyEpoch == currentKeyEpoch) {
      if (source != null) throw const FormatException('账户恢复前驱 capsule 不唯一');
      source = candidate;
    }
  }
  if (source == null) throw const FormatException('账户恢复缺少前驱 capsule');
  return Uint8List.fromList(source.recoveryCapsule);
}

Future<void> _closeRecoveryResourcesPreservingPrimary({
  required Object? primaryError,
  required List<Future<void> Function()> actions,
}) async {
  try {
    await _closeRecoveryResources(actions);
  } catch (_) {
    if (primaryError == null) rethrow;
    developer.log(
      'E2EE_ACCOUNT_RECOVERY_CLEANUP_FAILED',
      name: 'Olivia.E2eeAccountRecovery',
    );
  }
}

Future<void> _closeRecoveryResources(
  List<Future<void> Function()> actions,
) async {
  Object? firstError;
  StackTrace? firstStackTrace;
  for (final action in actions) {
    try {
      await action();
    } catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
  }
  if (firstError != null && firstStackTrace != null) {
    Error.throwWithStackTrace(firstError, firstStackTrace);
  }
}

bool _sameRecoveryBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

bool _sameRecoveryCompletion(
  CloudSyncDataRekeyCompletion left,
  CloudSyncDataRekeyCompletion right,
) {
  final leftAttachmentCursor = left.sourceAttachmentCursorEnd;
  final rightAttachmentCursor = right.sourceAttachmentCursorEnd;
  return left.proofVersion == right.proofVersion &&
      left.operationId == right.operationId &&
      left.issuerDeviceId == right.issuerDeviceId &&
      left.sourceDataGeneration == right.sourceDataGeneration &&
      left.targetDataGeneration == right.targetDataGeneration &&
      left.sourceKeyEpoch == right.sourceKeyEpoch &&
      left.targetKeyEpoch == right.targetKeyEpoch &&
      _sameRecoveryBytes(left.sourceSnapshotRoot, right.sourceSnapshotRoot) &&
      left.sourceRecordCount == right.sourceRecordCount &&
      left.sourceAttachmentCount == right.sourceAttachmentCount &&
      left.sourceMaximumChangeSeq == right.sourceMaximumChangeSeq &&
      left.sourceRecordCursorEnd == right.sourceRecordCursorEnd &&
      leftAttachmentCursor?.attachmentId ==
          rightAttachmentCursor?.attachmentId &&
      leftAttachmentCursor?.uploadId == rightAttachmentCursor?.uploadId &&
      left.membershipGeneration == right.membershipGeneration &&
      _sameRecoveryBytes(
        left.membershipManifestDigest,
        right.membershipManifestDigest,
      ) &&
      left.stagedRecordCount == right.stagedRecordCount &&
      left.stagedAttachmentCount == right.stagedAttachmentCount &&
      _sameRecoveryBytes(
        left.stagedCiphertextSetDigest,
        right.stagedCiphertextSetDigest,
      ) &&
      _sameRecoveryBytes(left.proofFrame, right.proofFrame) &&
      _sameRecoveryBytes(left.proofDigest, right.proofDigest) &&
      _sameRecoveryBytes(left.signature, right.signature) &&
      left.finalizedAt == right.finalizedAt;
}

bool _sameRecoveryAccountSession(
  CloudSyncAccountSession left,
  CloudSyncAccountSession right,
) {
  return left.baseUrl == right.baseUrl &&
      left.token.value == right.token.value &&
      left.tokenExpiresAt == right.tokenExpiresAt &&
      left.keyEpoch == right.keyEpoch &&
      left.authGeneration == right.authGeneration &&
      left.sessionGeneration == right.sessionGeneration &&
      left.userId == right.userId &&
      left.loginName == right.loginName &&
      left.displayName == right.displayName &&
      left.role == right.role &&
      left.attachmentQuotaBytes == right.attachmentQuotaBytes &&
      left.deviceId == right.deviceId &&
      left.deviceName == right.deviceName &&
      left.platform == right.platform &&
      left.clientVersion == right.clientVersion &&
      left.deviceKeyVersion == right.deviceKeyVersion &&
      left.deviceCreatedAt == right.deviceCreatedAt &&
      left.securityBootstrap == null &&
      right.securityBootstrap == null;
}

bool _sameRecoveryReopenBinding(
  E2eeAccountRecoveryReopenBinding left,
  E2eeAccountRecoveryReopenBinding right,
) {
  final leftManifestDigest = left.membershipManifestDigest;
  final rightManifestDigest = right.membershipManifestDigest;
  final leftStateDigest = left.prunedStateDigest;
  final rightStateDigest = right.prunedStateDigest;
  try {
    return left.userId == right.userId &&
        left.deviceId == right.deviceId &&
        left.deviceKeyVersion == right.deviceKeyVersion &&
        left.deviceAuthGeneration == right.deviceAuthGeneration &&
        left.keyEpoch == right.keyEpoch &&
        left.dataGeneration == right.dataGeneration &&
        left.membershipGeneration == right.membershipGeneration &&
        left.membershipOperationId == right.membershipOperationId &&
        _sameRecoveryBytes(leftManifestDigest, rightManifestDigest) &&
        _sameRecoveryBytes(leftStateDigest, rightStateDigest);
  } finally {
    clearSensitiveBytes(leftManifestDigest);
    clearSensitiveBytes(rightManifestDigest);
    clearSensitiveBytes(leftStateDigest);
    clearSensitiveBytes(rightStateDigest);
  }
}

bool _matchesPersistedRecoverySession(
  E2eeAccountRecoveryCheckpointProgress progress,
  CloudSyncAuthenticatedSession session,
) {
  return switch (progress) {
    E2eeAccountRecoverySecondLocalActivatedProgress() => true,
    E2eeAccountRecoverySessionVerifiedProgress(
      :final sessionGeneration,
      :final tokenExpiresAt,
    ) =>
      session.sessionGeneration == sessionGeneration &&
          _recoveryUtcSecond(session.tokenExpiresAt) == tokenExpiresAt,
    _ => false,
  };
}

DateTime _recoveryUtcSecond(DateTime value) =>
    DateTime.fromMillisecondsSinceEpoch(
      value.toUtc().millisecondsSinceEpoch ~/ 1000 * 1000,
      isUtc: true,
    );

DateTime _recoveryUtcNow() => DateTime.now().toUtc();
