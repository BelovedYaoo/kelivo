import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:uuid/uuid.dart';

import '../../database/chat_database_gateway.dart';
import '../workspace/device_state_blob_store.dart';
import '../workspace/e2ee_data_rekey_stage_store.dart';
import 'cloud_sync_client.dart';
import 'cloud_sync_types.dart';
import 'e2ee_account_key_transition.dart';
import 'e2ee_account_trust_manifest.dart';
import 'e2ee_data_rekey_cryptography.dart';
import 'e2ee_data_rekey_executor.dart';
import 'e2ee_device_state_access.dart';
import 'e2ee_device_state_key_transition.dart';

/// 账户密钥变更的生产资源边界；协议请求的准备与远端幂等身份由调用方持有。
final class E2eeAccountKeyTransitionProductionRunner {
  factory E2eeAccountKeyTransitionProductionRunner({
    required String baseUrl,
    required String normalizedLoginName,
    required DeviceStateBlobStore deviceStateStore,
    required KelivoSecureCore secureCore,
    required ChatDatabaseGateway databaseGateway,
    required File databaseFile,
    required CloudSyncDataRekeyTransport dataRekeyTransport,
    required E2eeDataRekeyStageStore stageStore,
    DateTime Function()? clock,
  }) {
    if (normalizedLoginName.isEmpty ||
        normalizedLoginName != normalizedLoginName.trim().toLowerCase()) {
      throw const FormatException('账户密钥变更登录名未规范化');
    }
    return E2eeAccountKeyTransitionProductionRunner._(
      normalizeCloudSyncBaseUrl(baseUrl),
      normalizedLoginName,
      deviceStateStore,
      secureCore,
      databaseGateway,
      databaseFile.absolute,
      dataRekeyTransport,
      stageStore,
      clock,
    );
  }

  E2eeAccountKeyTransitionProductionRunner._(
    this._baseUrl,
    this._normalizedLoginName,
    this._deviceStateStore,
    this._secureCore,
    this._databaseGateway,
    this._databaseFile,
    this._dataRekeyTransport,
    this._stageStore,
    this._clock,
  );

  final String _baseUrl;
  final String _normalizedLoginName;
  final DeviceStateBlobStore _deviceStateStore;
  final KelivoSecureCore _secureCore;
  final ChatDatabaseGateway _databaseGateway;
  final File _databaseFile;
  final CloudSyncDataRekeyTransport _dataRekeyTransport;
  final E2eeDataRekeyStageStore _stageStore;
  final DateTime Function()? _clock;

  bool _running = false;

  Future<E2eeAccountKeyTransitionRemoteReceipt> execute({
    required E2eeDeviceStateKeyTransitionPlan plan,
    required E2eeAccountKeyTransitionRemoteCommit remoteCommit,
  }) async {
    if (_running) throw StateError('account_key_transition_runner_busy');
    _running = true;
    try {
      return await _execute(plan: plan, remoteCommit: remoteCommit);
    } finally {
      _running = false;
    }
  }

  Future<E2eeAccountKeyTransitionRemoteReceipt> _execute({
    required E2eeDeviceStateKeyTransitionPlan plan,
    required E2eeAccountKeyTransitionRemoteCommit remoteCommit,
  }) async {
    final binding = plan.binding;
    final snapshot = await _deviceStateStore.readVersioned(
      normalizedBaseUrl: _baseUrl,
      normalizedLoginName: _normalizedLoginName,
    );
    if (snapshot == null) {
      throw const E2eeDeviceStateKeyTransitionConflict();
    }
    late final _TransitionStatePosition position;
    try {
      position = _requireCurrentStateMatchesPlan(snapshot.blob, plan);
    } finally {
      snapshot.blob.fillRange(0, snapshot.blob.length, 0);
    }

    E2eeOpenedDeviceStateHandles? issuerState;
    E2eeDataRekeyCryptographySession? cryptography;
    ChatDatabaseLease? databaseLease;
    E2eeAccountKeyTransitionRemoteReceipt? receipt;
    Object? primaryError;
    StackTrace? primaryStackTrace;
    try {
      issuerState = await E2eeDeviceStateAccess(
        baseUrl: _baseUrl,
        deviceStateStore: _deviceStateStore,
        secureCore: _secureCore,
      ).openExisting(_normalizedLoginName);
      if (issuerState == null || issuerState.stateVersion != snapshot.version) {
        throw const E2eeDeviceStateKeyTransitionConflict();
      }
      await _requireIssuerStateMatchesPlan(
        secureCore: _secureCore,
        issuerState: issuerState,
        plan: plan,
        position: position,
      );
      final targetStateBlob = plan.unprunedStateBlob;
      try {
        cryptography = await E2eeDataRekeyCryptographySession.openTargetState(
          secureCore: _secureCore,
          issuerState: issuerState,
          targetStateBlob: targetStateBlob,
          userId: binding.userId,
          targetKeyEpoch: binding.targetKeyEpoch,
        );
      } finally {
        targetStateBlob.fillRange(0, targetStateBlob.length, 0);
      }

      databaseLease = await _databaseGateway.acquire(_databaseFile);
      final context = E2eeDataRekeyExecutionContext(
        baseUrl: _baseUrl,
        loginName: _normalizedLoginName,
        userId: binding.userId,
        issuerDeviceId: binding.issuerDeviceId,
        membershipGeneration: binding.securityGeneration,
        membershipManifestDigest: binding.membershipManifestDigest,
      );
      final executor = E2eeDataRekeyExecutor(
        transport: _dataRekeyTransport,
        journal: databaseLease.repository.e2eeDataRekeyCommands,
        stageStore: _stageStore,
        cryptography: cryptography,
        clock: _clock,
      );
      receipt = await E2eeAccountKeyTransitionCoordinator(
        dataRekeyExecutor: executor,
        remoteCommit: remoteCommit,
        localCommitter: E2eeDeviceStateKeyTransitionCommitter(
          baseUrl: _baseUrl,
          normalizedLoginName: _normalizedLoginName,
          plan: plan,
          deviceStateStore: _deviceStateStore,
          secureCore: _secureCore,
          databaseGateway: _databaseGateway,
          databaseFile: _databaseFile,
          clock: _clock,
        ),
      ).execute(context: context, binding: binding);
    } catch (error, stackTrace) {
      primaryError = error;
      primaryStackTrace = stackTrace;
    }

    final cleanupError = await _cleanupProductionRun(
      secureCore: _secureCore,
      databaseLease: databaseLease,
      cryptography: cryptography,
      issuerState: issuerState,
    );
    if (primaryError != null && primaryStackTrace != null) {
      if (cleanupError != null) {
        developer.log(
          '账户密钥变更失败后的生产资源清理未完全收敛',
          name: 'Kelivo.E2eeAccountKeyTransitionProductionRunner',
          level: 1000,
        );
      }
      Error.throwWithStackTrace(primaryError, primaryStackTrace);
    }
    if (cleanupError != null) {
      Error.throwWithStackTrace(cleanupError.$1, cleanupError.$2);
    }
    return receipt!;
  }
}

enum _TransitionStatePosition { source, unpruned, pruned }

_TransitionStatePosition _requireCurrentStateMatchesPlan(
  Uint8List current,
  E2eeDeviceStateKeyTransitionPlan plan,
) {
  final source = plan.sourceStateBlob;
  final unpruned = plan.unprunedStateBlob;
  final pruned = plan.prunedStateBlob;
  try {
    if (_sameTransitionRunnerBytes(current, source)) {
      return _TransitionStatePosition.source;
    }
    if (_sameTransitionRunnerBytes(current, unpruned)) {
      return _TransitionStatePosition.unpruned;
    }
    if (_sameTransitionRunnerBytes(current, pruned)) {
      return _TransitionStatePosition.pruned;
    }
    throw const E2eeDeviceStateKeyTransitionConflict();
  } finally {
    source.fillRange(0, source.length, 0);
    unpruned.fillRange(0, unpruned.length, 0);
    pruned.fillRange(0, pruned.length, 0);
  }
}

Future<void> _requireIssuerStateMatchesPlan({
  required KelivoSecureCore secureCore,
  required E2eeOpenedDeviceStateHandles issuerState,
  required E2eeDeviceStateKeyTransitionPlan plan,
  required _TransitionStatePosition position,
}) async {
  final binding = plan.binding;
  final account = issuerState.binding.account;
  final ark = issuerState.ark;
  final expectedStateEpoch = position == _TransitionStatePosition.source
      ? plan.previousMembership.keyEpoch
      : binding.targetKeyEpoch;
  if (ark == null ||
      account == null ||
      Uuid.unparse(issuerState.binding.deviceId) != binding.issuerDeviceId ||
      Uuid.unparse(account.userId) != binding.userId ||
      account.keyEpoch != expectedStateEpoch ||
      !_sameTransitionRunnerBytes(ark.userId, account.userId)) {
    throw const E2eeDeviceStateKeyTransitionConflict();
  }
  final issuerMember = _requireIssuerMember(plan.nextMembership, binding);
  if (issuerMember.keyVersion != issuerState.binding.keyVersion) {
    throw const E2eeDeviceStateKeyTransitionConflict();
  }
  final publicKeys = await secureCore.readDevicePublicKeys(
    issuerState.identity,
  );
  if (!_sameTransitionRunnerBytes(
        publicKeys.signingPublicKey,
        issuerMember.signingPublicKey,
      ) ||
      !_sameTransitionRunnerBytes(
        publicKeys.keyAgreementPublicKey,
        issuerMember.keyAgreementPublicKey,
      )) {
    throw const E2eeDeviceStateKeyTransitionConflict();
  }
}

E2eeVerifiedMembershipDevice _requireIssuerMember(
  E2eeVerifiedMembership membership,
  E2eeAccountKeyTransitionBinding binding,
) {
  E2eeVerifiedMembershipDevice? matched;
  for (final member in membership.members) {
    if (member.deviceId != binding.issuerDeviceId) continue;
    if (matched != null) {
      throw const E2eeDeviceStateKeyTransitionConflict();
    }
    matched = member;
  }
  if (matched == null) {
    throw const E2eeDeviceStateKeyTransitionConflict();
  }
  return matched;
}

Future<(Object, StackTrace)?> _cleanupProductionRun({
  required KelivoSecureCore secureCore,
  required ChatDatabaseLease? databaseLease,
  required E2eeDataRekeyCryptographySession? cryptography,
  required E2eeOpenedDeviceStateHandles? issuerState,
}) async {
  Object? firstError;
  StackTrace? firstStackTrace;
  final cleanup = <({Future<void> Function() action, int attempts})>[
    if (databaseLease != null) (action: databaseLease.release, attempts: 1),
    if (cryptography != null) (action: cryptography.close, attempts: 2),
    if (issuerState?.ark != null)
      (
        action: () => secureCore.closeAccountRootKey(issuerState!.ark!),
        attempts: 2,
      ),
    if (issuerState != null)
      (
        action: () => secureCore.closeDeviceIdentity(issuerState.identity),
        attempts: 2,
      ),
    if (issuerState != null)
      (action: () => secureCore.close(issuerState.key), attempts: 2),
  ];
  for (final entry in cleanup) {
    final failure = await _attemptProductionCleanup(
      entry.action,
      attempts: entry.attempts,
    );
    if (failure != null) {
      if (firstError == null) {
        firstError = failure.$1;
        firstStackTrace = failure.$2;
      } else {
        developer.log(
          '账户密钥变更生产资源的后续清理失败',
          name: 'Kelivo.E2eeAccountKeyTransitionProductionRunner',
          level: 1000,
        );
      }
    }
  }
  if (firstError == null || firstStackTrace == null) return null;
  return (firstError, firstStackTrace);
}

Future<(Object, StackTrace)?> _attemptProductionCleanup(
  Future<void> Function() action, {
  required int attempts,
}) async {
  Object? lastError;
  StackTrace? lastStackTrace;
  for (var attempt = 0; attempt < attempts; attempt++) {
    try {
      await action();
      return null;
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;
    }
  }
  return (lastError!, lastStackTrace!);
}

bool _sameTransitionRunnerBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}
