import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:uuid/uuid.dart';

import '../../database/chat_database_gateway.dart';
import '../workspace/device_state_blob_store.dart';
import 'cloud_sync_types.dart';
import 'e2ee_account_key_transition.dart';
import 'e2ee_account_trust_manifest.dart';
import 'e2ee_data_rekey_executor.dart';
import 'e2ee_device_state_access.dart';
import 'e2ee_self_revocation_rotation_binding.dart';

final class E2eeDeviceStateKeyTransitionConflict implements Exception {
  const E2eeDeviceStateKeyTransitionConflict();

  @override
  String toString() => 'E2eeDeviceStateKeyTransitionConflict()';
}

final class E2eeDeviceStateKeyTransitionPlan {
  factory E2eeDeviceStateKeyTransitionPlan({
    required E2eeAccountKeyTransitionBinding binding,
    required E2eeVerifiedMembership previousMembership,
    required E2eeVerifiedMembership nextMembership,
    required Uint8List sourceStateBlob,
    required Uint8List unprunedStateBlob,
    required Uint8List prunedStateBlob,
  }) {
    _requireMembershipTransitionMatches(
      binding,
      previousMembership,
      nextMembership,
    );
    final source = _copyStateBlob(sourceStateBlob, 'sourceStateBlob');
    final unpruned = _copyStateBlob(unprunedStateBlob, 'unprunedStateBlob');
    final pruned = _copyStateBlob(prunedStateBlob, 'prunedStateBlob');
    if (_sameStateBytes(source, unpruned) ||
        _sameStateBytes(source, pruned) ||
        _sameStateBytes(unpruned, pruned)) {
      throw const FormatException('账户密钥变更设备状态必须是三个不同快照');
    }
    return E2eeDeviceStateKeyTransitionPlan._(
      binding,
      previousMembership,
      nextMembership,
      source,
      unpruned,
      pruned,
    );
  }

  const E2eeDeviceStateKeyTransitionPlan._(
    this.binding,
    this.previousMembership,
    this.nextMembership,
    this._sourceStateBlob,
    this._unprunedStateBlob,
    this._prunedStateBlob,
  );

  final E2eeAccountKeyTransitionBinding binding;
  final E2eeVerifiedMembership previousMembership;
  final E2eeVerifiedMembership nextMembership;
  final Uint8List _sourceStateBlob;
  final Uint8List _unprunedStateBlob;
  final Uint8List _prunedStateBlob;

  Uint8List get sourceStateBlob => Uint8List.fromList(_sourceStateBlob);

  Uint8List get unprunedStateBlob => Uint8List.fromList(_unprunedStateBlob);

  Uint8List get prunedStateBlob => Uint8List.fromList(_prunedStateBlob);
}

final class E2eeDeviceStateKeyTransitionCommitter
    implements E2eeAccountKeyTransitionLocalCommitter {
  factory E2eeDeviceStateKeyTransitionCommitter({
    required String baseUrl,
    required String normalizedLoginName,
    required E2eeDeviceStateKeyTransitionPlan plan,
    required DeviceStateBlobStore deviceStateStore,
    required KelivoSecureCore secureCore,
    required ChatDatabaseGateway databaseGateway,
    required File databaseFile,
    DateTime Function()? clock,
  }) {
    if (normalizedLoginName.isEmpty ||
        normalizedLoginName != normalizedLoginName.trim().toLowerCase()) {
      throw const FormatException('账户密钥变更登录名未规范化');
    }
    return E2eeDeviceStateKeyTransitionCommitter._(
      normalizeCloudSyncBaseUrl(baseUrl),
      normalizedLoginName,
      plan,
      deviceStateStore,
      secureCore,
      databaseGateway,
      databaseFile.absolute,
      clock ?? _transitionUtcNow,
    );
  }

  E2eeDeviceStateKeyTransitionCommitter._(
    this._baseUrl,
    this._normalizedLoginName,
    this._plan,
    this._deviceStateStore,
    this._secureCore,
    this._databaseGateway,
    this._databaseFile,
    this._clock,
  );

  final String _baseUrl;
  final String _normalizedLoginName;
  final E2eeDeviceStateKeyTransitionPlan _plan;
  final DeviceStateBlobStore _deviceStateStore;
  final KelivoSecureCore _secureCore;
  final ChatDatabaseGateway _databaseGateway;
  final File _databaseFile;
  final DateTime Function() _clock;

  bool _running = false;

  @override
  Future<void> commit({
    required E2eeAccountKeyTransitionBinding binding,
    required E2eeDataRekeyReadyConfirmation confirmation,
  }) async {
    if (_running) throw StateError('device_state_key_transition_busy');
    _requireSameBinding(binding, _plan.binding);
    _requireConfirmationMatchesPlan(confirmation, _plan);
    _running = true;
    try {
      final position = await _ensureUnprunedStatePublished();
      await _ensureMembershipAnchorAdvanced();
      if (position != _DeviceStateTransitionPosition.pruned) {
        await _ensurePrunedStatePublished();
      }
      await _requireCommitted();
    } finally {
      _running = false;
    }
  }

  @override
  Future<void> requireCommitted({
    required E2eeAccountKeyTransitionBinding binding,
  }) async {
    if (_running) throw StateError('device_state_key_transition_busy');
    _requireSameBinding(binding, _plan.binding);
    _running = true;
    try {
      await _requireCommitted();
    } finally {
      _running = false;
    }
  }

  Future<_DeviceStateTransitionPosition> _ensureUnprunedStatePublished() async {
    final current = await _readRequiredState();
    try {
      if (_sameStateBytes(current.blob, _plan._prunedStateBlob)) {
        return _DeviceStateTransitionPosition.pruned;
      }
      if (_sameStateBytes(current.blob, _plan._unprunedStateBlob)) {
        return _DeviceStateTransitionPosition.unpruned;
      }
      if (!_sameStateBytes(current.blob, _plan._sourceStateBlob)) {
        throw const E2eeDeviceStateKeyTransitionConflict();
      }
      await _deviceStateStore.compareAndSwap(
        normalizedBaseUrl: _baseUrl,
        normalizedLoginName: _normalizedLoginName,
        expectedVersion: current.version,
        blob: _plan._unprunedStateBlob,
      );
      return _DeviceStateTransitionPosition.unpruned;
    } finally {
      _clearStateBytes(current.blob);
    }
  }

  Future<void> _ensureMembershipAnchorAdvanced() {
    return _withCurrentState((opened) async {
      final ark = opened.ark!;
      final lease = await _databaseGateway.acquire(_databaseFile);
      try {
        final commands = lease.repository.e2eeVerifiedMembershipAnchorCommands;
        final current = await commands.readVerified(
          accountUserId: _plan.binding.userId,
          ark: ark,
        );
        if (current == null) {
          throw StateError('账户密钥变更缺少本地已验证成员锚点');
        }
        if (_sameMembership(current.membership, _plan.nextMembership)) return;
        if (!_sameMembership(current.membership, _plan.previousMembership)) {
          throw const E2eeDeviceStateKeyTransitionConflict();
        }
        await commands.advance(
          expected: current,
          next: _plan.nextMembership,
          now: _clock().toUtc(),
        );
      } finally {
        await lease.release();
      }
    });
  }

  Future<void> _ensurePrunedStatePublished() async {
    final current = await _readRequiredState();
    try {
      if (_sameStateBytes(current.blob, _plan._prunedStateBlob)) return;
      if (!_sameStateBytes(current.blob, _plan._unprunedStateBlob)) {
        throw const E2eeDeviceStateKeyTransitionConflict();
      }
      await _deviceStateStore.compareAndSwap(
        normalizedBaseUrl: _baseUrl,
        normalizedLoginName: _normalizedLoginName,
        expectedVersion: current.version,
        blob: _plan._prunedStateBlob,
      );
    } finally {
      _clearStateBytes(current.blob);
    }
  }

  Future<void> _requireCommitted() async {
    final current = await _readRequiredState();
    try {
      if (!_sameStateBytes(current.blob, _plan._prunedStateBlob)) {
        throw const E2eeDeviceStateKeyTransitionConflict();
      }
    } finally {
      _clearStateBytes(current.blob);
    }
    await _withCurrentState((opened) async {
      final lease = await _databaseGateway.acquire(_databaseFile);
      try {
        final anchor = await lease
            .repository
            .e2eeVerifiedMembershipAnchorCommands
            .readVerified(
              accountUserId: _plan.binding.userId,
              ark: opened.ark!,
            );
        if (anchor == null ||
            !_sameMembership(anchor.membership, _plan.nextMembership)) {
          throw const E2eeDeviceStateKeyTransitionConflict();
        }
      } finally {
        await lease.release();
      }
    });
  }

  Future<DeviceStateBlobSnapshot> _readRequiredState() async {
    final current = await _deviceStateStore.readVersioned(
      normalizedBaseUrl: _baseUrl,
      normalizedLoginName: _normalizedLoginName,
    );
    if (current == null) {
      throw const E2eeDeviceStateKeyTransitionConflict();
    }
    return current;
  }

  Future<void> _withCurrentState(
    Future<void> Function(E2eeOpenedDeviceStateHandles opened) action,
  ) async {
    final access = E2eeDeviceStateAccess(
      baseUrl: _baseUrl,
      deviceStateStore: _deviceStateStore,
      secureCore: _secureCore,
    );
    final opened = await access.openExisting(_normalizedLoginName);
    if (opened == null || opened.ark == null) {
      throw const E2eeDeviceStateKeyTransitionConflict();
    }
    Object? primaryError;
    StackTrace? primaryStackTrace;
    try {
      await _requireOpenedStateMatchesPlan(opened, _plan, _secureCore);
      await action(opened);
    } catch (error, stackTrace) {
      primaryError = error;
      primaryStackTrace = stackTrace;
    }
    final cleanupError = await _closeOpenedState(_secureCore, opened);
    if (primaryError != null && primaryStackTrace != null) {
      if (cleanupError != null) {
        developer.log(
          '账户密钥变更失败后的设备状态句柄清理失败',
          name: 'Kelivo.E2eeDeviceStateKeyTransitionCommitter',
          error: cleanupError.$1,
          stackTrace: cleanupError.$2,
        );
      }
      Error.throwWithStackTrace(primaryError, primaryStackTrace);
    }
    if (cleanupError != null) {
      Error.throwWithStackTrace(cleanupError.$1, cleanupError.$2);
    }
  }
}

enum _DeviceStateTransitionPosition { unpruned, pruned }

void _requireMembershipTransitionMatches(
  E2eeAccountKeyTransitionBinding binding,
  E2eeVerifiedMembership previous,
  E2eeVerifiedMembership next,
) {
  final expectedKind = switch (binding.kind) {
    E2eeAccountKeyTransitionKind.deviceRevocation =>
      E2eeMembershipOperationKind.revokeRotate,
    E2eeAccountKeyTransitionKind.recoveryResume =>
      E2eeMembershipOperationKind.recoverResume,
    E2eeAccountKeyTransitionKind.recoveryReplacement =>
      E2eeMembershipOperationKind.recoverReplace,
  };
  final expectedEpoch = switch (binding.kind) {
    E2eeAccountKeyTransitionKind.recoveryResume => previous.keyEpoch,
    _ => previous.keyEpoch + 1,
  };
  if (previous.userId != binding.userId ||
      next.userId != binding.userId ||
      next.operationKind != expectedKind ||
      next.operationId != binding.membershipOperationId ||
      next.issuerDeviceId != binding.issuerDeviceId ||
      next.securityGeneration != previous.securityGeneration + 1 ||
      next.securityGeneration != binding.securityGeneration ||
      next.keyEpoch != expectedEpoch ||
      next.keyEpoch != binding.targetKeyEpoch ||
      !_sameStateBytes(next.previousDigest, previous.digest) ||
      !_sameStateBytes(next.digest, binding.membershipManifestDigest)) {
    throw const FormatException('账户密钥变更成员清单与计划不匹配');
  }
  _requireSelfRevocationBindingMatchesMembership(binding, previous, next);
  final issuerCount = next.members
      .where((member) => member.deviceId == binding.issuerDeviceId)
      .length;
  if (issuerCount != 1) {
    throw const FormatException('账户密钥变更签发设备不在下一成员清单');
  }
  switch (binding.kind) {
    case E2eeAccountKeyTransitionKind.deviceRevocation:
      break;
    case E2eeAccountKeyTransitionKind.recoveryResume:
      final issuedByNewDevice =
          previous.issuerDeviceId != binding.issuerDeviceId &&
          !previous.members.any(
            (member) => member.deviceId == binding.issuerDeviceId,
          );
      if (!issuedByNewDevice) {
        throw const FormatException('恢复接续签发设备不是新的接管设备');
      }
      next.requireDataRekeyLineage(rekeyOperationId: binding.rekeyOperationId);
    case E2eeAccountKeyTransitionKind.recoveryReplacement:
      if (next.members.length != 1) {
        throw const FormatException('恢复替换成员清单必须只保留恢复设备');
      }
      final replacementMember = next.members.single;
      final resumesSameDevice =
          previous.operationKind == E2eeMembershipOperationKind.recoverResume &&
          previous.issuerDeviceId == binding.issuerDeviceId &&
          previous.subjectDeviceId == binding.issuerDeviceId;
      final directReplacement =
          previous.operationKind != E2eeMembershipOperationKind.recoverResume &&
          !previous.members.any(
            (member) =>
                member.deviceId == binding.issuerDeviceId ||
                _sameStateBytes(
                  member.signingPublicKey,
                  replacementMember.signingPublicKey,
                ) ||
                _sameStateBytes(
                  member.keyAgreementPublicKey,
                  replacementMember.keyAgreementPublicKey,
                ),
          );
      if (replacementMember.deviceId != binding.issuerDeviceId ||
          (!resumesSameDevice && !directReplacement)) {
        throw const FormatException('恢复替换设备与已验证前驱不匹配');
      }
  }
}

void _requireSameBinding(
  E2eeAccountKeyTransitionBinding actual,
  E2eeAccountKeyTransitionBinding expected,
) {
  if (actual.kind != expected.kind ||
      actual.userId != expected.userId ||
      actual.issuerDeviceId != expected.issuerDeviceId ||
      actual.membershipOperationId != expected.membershipOperationId ||
      actual.rekeyOperationId != expected.rekeyOperationId ||
      actual.securityGeneration != expected.securityGeneration ||
      actual.targetKeyEpoch != expected.targetKeyEpoch ||
      !_sameSelfRevocationBinding(
        actual.selfRevocationAuthorization,
        expected.selfRevocationAuthorization,
      ) ||
      !_sameStateBytes(
        actual.membershipManifestDigest,
        expected.membershipManifestDigest,
      )) {
    throw const FormatException('账户密钥变更本地提交绑定不匹配');
  }
}

void _requireSelfRevocationBindingMatchesMembership(
  E2eeAccountKeyTransitionBinding binding,
  E2eeVerifiedMembership previous,
  E2eeVerifiedMembership next,
) {
  final authorization = binding.selfRevocationAuthorization;
  if (authorization == null) {
    if (!_allZeroStateBytes(next.operationAuthorizationDigest)) {
      throw const FormatException('非自撤销成员操作不得携带授权摘要');
    }
    return;
  }
  if (binding.kind != E2eeAccountKeyTransitionKind.deviceRevocation ||
      authorization.operationId != next.operationId ||
      authorization.deviceId != next.subjectDeviceId ||
      authorization.expectedGeneration != previous.securityGeneration ||
      authorization.expectedKeyEpoch != previous.keyEpoch ||
      !_sameStateBytes(
        authorization.expectedMembershipManifestDigest,
        previous.digest,
      ) ||
      !_sameStateBytes(
        authorization.intentDigest,
        next.operationAuthorizationDigest,
      )) {
    throw const FormatException('自撤销成员操作未绑定原始意图');
  }
}

bool _sameSelfRevocationBinding(
  E2eeSelfRevocationRotationBinding? left,
  E2eeSelfRevocationRotationBinding? right,
) {
  if (left == null || right == null) return left == null && right == null;
  return left.hasSameSecurityBinding(right);
}

void _requireConfirmationMatchesPlan(
  E2eeDataRekeyReadyConfirmation confirmation,
  E2eeDeviceStateKeyTransitionPlan plan,
) {
  final execution = confirmation.execution;
  final completion = execution.result.completion;
  if (execution.operationId != plan.binding.rekeyOperationId ||
      execution.userId != plan.binding.userId ||
      execution.issuerDeviceId != plan.binding.issuerDeviceId ||
      completion.operationId != plan.binding.rekeyOperationId ||
      completion.issuerDeviceId != plan.binding.issuerDeviceId ||
      completion.membershipGeneration != plan.binding.securityGeneration ||
      completion.targetKeyEpoch != plan.binding.targetKeyEpoch ||
      !_sameStateBytes(
        completion.membershipManifestDigest,
        plan.binding.membershipManifestDigest,
      )) {
    throw const FormatException('账户密钥变更 ready 确认与本地计划不匹配');
  }
}

Future<void> _requireOpenedStateMatchesPlan(
  E2eeOpenedDeviceStateHandles opened,
  E2eeDeviceStateKeyTransitionPlan plan,
  KelivoSecureCore secureCore,
) async {
  final account = opened.binding.account;
  if (account == null ||
      Uuid.unparse(account.userId) != plan.binding.userId ||
      account.keyEpoch != plan.binding.targetKeyEpoch ||
      Uuid.unparse(opened.binding.deviceId) != plan.binding.issuerDeviceId) {
    throw const E2eeDeviceStateKeyTransitionConflict();
  }
  final issuer = plan.nextMembership.members.singleWhere(
    (member) => member.deviceId == plan.binding.issuerDeviceId,
  );
  final publicKeys = await secureCore.readDevicePublicKeys(opened.identity);
  if (opened.binding.keyVersion != issuer.keyVersion ||
      !_sameStateBytes(publicKeys.signingPublicKey, issuer.signingPublicKey) ||
      !_sameStateBytes(
        publicKeys.keyAgreementPublicKey,
        issuer.keyAgreementPublicKey,
      )) {
    throw const E2eeDeviceStateKeyTransitionConflict();
  }
}

Future<(Object, StackTrace)?> _closeOpenedState(
  KelivoSecureCore secureCore,
  E2eeOpenedDeviceStateHandles opened,
) async {
  Object? firstError;
  StackTrace? firstStackTrace;
  Future<void> close(Future<void> Function() action) async {
    try {
      await action();
    } catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
  }

  await close(() => secureCore.closeAccountRootKey(opened.ark!));
  await close(() => secureCore.closeDeviceIdentity(opened.identity));
  await close(() => secureCore.close(opened.key));
  final error = firstError;
  final stackTrace = firstStackTrace;
  if (error == null || stackTrace == null) return null;
  return (error, stackTrace);
}

Uint8List _copyStateBlob(Uint8List value, String field) {
  if (value.length != DeviceStateBlobStore.blobLength) {
    throw FormatException('$field 长度无效');
  }
  return Uint8List.fromList(value).asUnmodifiableView();
}

bool _sameMembership(
  E2eeVerifiedMembership left,
  E2eeVerifiedMembership right,
) {
  return left.userId == right.userId &&
      left.securityGeneration == right.securityGeneration &&
      left.keyEpoch == right.keyEpoch &&
      _sameStateBytes(left.manifest, right.manifest) &&
      _sameStateBytes(left.digest, right.digest);
}

bool _sameStateBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

bool _allZeroStateBytes(List<int> value) {
  var accumulator = 0;
  for (final byte in value) {
    accumulator |= byte;
  }
  return accumulator == 0;
}

void _clearStateBytes(Uint8List value) {
  value.fillRange(0, value.length, 0);
}

DateTime _transitionUtcNow() => DateTime.now().toUtc();
