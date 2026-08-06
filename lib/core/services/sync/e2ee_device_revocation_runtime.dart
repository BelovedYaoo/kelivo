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
import 'e2ee_account_key_transition_runner.dart';
import 'e2ee_account_trust_manifest.dart';
import 'e2ee_cloud_sync_device_rotation_remote_commit.dart';
import 'e2ee_device_state_access.dart';
import 'e2ee_device_state_key_transition.dart';
import 'e2ee_self_revocation_coordinator.dart';
import 'e2ee_self_revocation_rotation_binding.dart';

final class E2eePreparedDeviceRevocation {
  const E2eePreparedDeviceRevocation({
    required this.plan,
    required this.request,
  });

  final E2eeDeviceStateKeyTransitionPlan plan;
  final CloudSyncDeviceRotationRequest request;
}

/// 从本地已验证成员锚点生成完整轮换计划，避免 Provider 拼接安全字段。
final class E2eeDeviceRevocationPlanPreparer {
  factory E2eeDeviceRevocationPlanPreparer({
    required String baseUrl,
    required String normalizedLoginName,
    required DeviceStateBlobStore deviceStateStore,
    required KelivoSecureCore secureCore,
    required ChatDatabaseGateway databaseGateway,
    required File databaseFile,
  }) {
    if (normalizedLoginName.isEmpty ||
        normalizedLoginName != normalizedLoginName.trim().toLowerCase()) {
      throw const FormatException('设备撤销登录名未规范化');
    }
    return E2eeDeviceRevocationPlanPreparer._(
      normalizeCloudSyncBaseUrl(baseUrl),
      normalizedLoginName,
      deviceStateStore,
      secureCore,
      databaseGateway,
      databaseFile.absolute,
    );
  }

  const E2eeDeviceRevocationPlanPreparer._(
    this._baseUrl,
    this._normalizedLoginName,
    this._deviceStateStore,
    this._secureCore,
    this._databaseGateway,
    this._databaseFile,
  );

  final String _baseUrl;
  final String _normalizedLoginName;
  final DeviceStateBlobStore _deviceStateStore;
  final KelivoSecureCore _secureCore;
  final ChatDatabaseGateway _databaseGateway;
  final File _databaseFile;
  final E2eeAccountTrustManifestModule _manifestModule =
      const E2eeAccountTrustManifestModule();

  Future<E2eePreparedDeviceRevocation> prepareDirect({
    required CloudSyncAccountSession session,
    required String operationId,
    required String revokedDeviceId,
  }) {
    return _prepare(
      session: session,
      operationId: operationId,
      revokedDeviceId: revokedDeviceId,
      authorization: null,
    );
  }

  Future<E2eePreparedDeviceRevocation> prepareSelfRevocation({
    required CloudSyncAccountSession session,
    required E2eeVerifiedSelfRevocationIntent intent,
  }) {
    final authorization = intent.toRotationBinding();
    return _prepare(
      session: session,
      operationId: intent.operationId,
      revokedDeviceId: intent.deviceId,
      authorization: authorization,
    );
  }

  Future<E2eePreparedDeviceRevocation> _prepare({
    required CloudSyncAccountSession session,
    required String operationId,
    required String revokedDeviceId,
    required E2eeSelfRevocationRotationBinding? authorization,
  }) async {
    _requireSessionScope(session);
    final snapshot = await _deviceStateStore.readVersioned(
      normalizedBaseUrl: _baseUrl,
      normalizedLoginName: _normalizedLoginName,
    );
    if (snapshot == null) {
      throw const E2eeDeviceStateKeyTransitionConflict();
    }

    E2eeOpenedDeviceStateHandles? opened;
    ChatDatabaseLease? databaseLease;
    KelivoAccountRootKeyHandle? generatedEpoch;
    Object? primaryError;
    StackTrace? primaryStackTrace;
    E2eePreparedDeviceRevocation? prepared;
    try {
      opened = await E2eeDeviceStateAccess(
        baseUrl: _baseUrl,
        deviceStateStore: _deviceStateStore,
        secureCore: _secureCore,
      ).openExisting(_normalizedLoginName);
      final state = opened;
      if (state == null ||
          state.ark == null ||
          state.stateVersion != snapshot.version) {
        throw const E2eeDeviceStateKeyTransitionConflict();
      }
      _requireOpenedStateMatchesSession(state, session);

      databaseLease = await _databaseGateway.acquire(_databaseFile);
      final anchor = await databaseLease
          .repository
          .e2eeVerifiedMembershipAnchorCommands
          .readVerified(accountUserId: session.userId, ark: state.ark!);
      if (anchor == null) {
        throw StateError('设备撤销缺少本地已验证成员锚点');
      }
      final previous = anchor.membership;
      _requireMembershipMatchesSession(previous, session);
      _requireRevocationMembers(
        previous: previous,
        issuerDeviceId: session.deviceId,
        revokedDeviceId: revokedDeviceId,
      );
      _requireAuthorizationMatchesHead(
        authorization: authorization,
        previous: previous,
        revokedDeviceId: revokedDeviceId,
        operationId: operationId,
      );

      final targetKeyEpoch = previous.keyEpoch + 1;
      generatedEpoch = await _secureCore.generateAccountRootKey(
        userId: Uuid.parseAsByteList(session.userId),
        keyEpoch: targetKeyEpoch,
      );
      await _secureCore.addAccountRootKeyEpoch(
        state.ark!,
        source: generatedEpoch,
      );
      await _secureCore.closeAccountRootKey(generatedEpoch);
      generatedEpoch = null;

      final nextRecoveryCapsuleVersion = previous.recoveryCapsuleVersion + 1;
      final nextRecoveryCapsule = await _secureCore.sealRecoveryCapsule(
        state.ark!,
        keyEpoch: targetKeyEpoch,
        recoveryPublicKey: previous.recoveryPublicKey,
        recoveryPublicKeyVersion: previous.recoveryPublicKeyVersion,
        capsuleVersion: nextRecoveryCapsuleVersion,
      );
      final next = await _manifestModule.create(
        ark: state.ark!,
        change: E2eeRevokeRotateMembershipChange(
          previous: previous,
          operationId: operationId,
          issuerDeviceId: session.deviceId,
          revokedDeviceId: revokedDeviceId,
          nextRecoveryCapsuleVersion: nextRecoveryCapsuleVersion,
          nextRecoveryCapsule: nextRecoveryCapsule,
          operationAuthorizationDigest: authorization?.intentDigest,
        ),
      );
      final envelopes = await _sealEnvelopes(
        state: state,
        session: session,
        membership: next,
      );
      final unprunedStateBlob = await _sealState(
        state: state,
        session: session,
        keyEpoch: targetKeyEpoch,
      );
      await _secureCore.pruneAccountRootKeyEpoch(
        state.ark!,
        keyEpoch: previous.keyEpoch,
      );
      final prunedStateBlob = await _sealState(
        state: state,
        session: session,
        keyEpoch: targetKeyEpoch,
      );
      final binding = authorization == null
          ? E2eeAccountKeyTransitionBinding(
              kind: E2eeAccountKeyTransitionKind.deviceRevocation,
              userId: session.userId,
              issuerDeviceId: session.deviceId,
              membershipOperationId: operationId,
              rekeyOperationId: operationId,
              securityGeneration: next.securityGeneration,
              targetKeyEpoch: next.keyEpoch,
              membershipManifestDigest: next.digest,
            )
          : E2eeAccountKeyTransitionBinding.selfRevocation(
              userId: session.userId,
              issuerDeviceId: session.deviceId,
              membershipOperationId: operationId,
              rekeyOperationId: operationId,
              securityGeneration: next.securityGeneration,
              targetKeyEpoch: next.keyEpoch,
              membershipManifestDigest: next.digest,
              authorization: authorization,
            );
      final request = authorization == null
          ? CloudSyncDeviceRotationRequest.direct(
              expectedGeneration: previous.securityGeneration,
              expectedKeyEpoch: previous.keyEpoch,
              expectedMembershipManifestDigest:
                  CloudSyncMembershipManifestDigest.fromBytes(previous.digest),
              operationId: operationId,
              revokeDeviceId: revokedDeviceId,
              nextMembershipManifest: next.manifest,
              nextRecoveryCapsuleVersion: nextRecoveryCapsuleVersion,
              nextRecoveryCapsule: nextRecoveryCapsule,
              envelopes: envelopes,
            )
          : CloudSyncDeviceRotationRequest.selfRevocation(
              authorization: authorization,
              expectedGeneration: previous.securityGeneration,
              expectedKeyEpoch: previous.keyEpoch,
              expectedMembershipManifestDigest:
                  CloudSyncMembershipManifestDigest.fromBytes(previous.digest),
              operationId: operationId,
              revokeDeviceId: revokedDeviceId,
              nextMembershipManifest: next.manifest,
              nextRecoveryCapsuleVersion: nextRecoveryCapsuleVersion,
              nextRecoveryCapsule: nextRecoveryCapsule,
              envelopes: envelopes,
            );
      prepared = E2eePreparedDeviceRevocation(
        plan: E2eeDeviceStateKeyTransitionPlan(
          binding: binding,
          previousMembership: previous,
          nextMembership: next,
          sourceStateBlob: snapshot.blob,
          unprunedStateBlob: unprunedStateBlob,
          prunedStateBlob: prunedStateBlob,
        ),
        request: request,
      );
    } catch (error, stackTrace) {
      primaryError = error;
      primaryStackTrace = stackTrace;
    } finally {
      snapshot.blob.fillRange(0, snapshot.blob.length, 0);
    }

    final cleanupError = await _closePreparationResources(
      secureCore: _secureCore,
      generatedEpoch: generatedEpoch,
      databaseLease: databaseLease,
      opened: opened,
    );
    if (primaryError != null && primaryStackTrace != null) {
      if (cleanupError != null) {
        developer.log(
          '设备撤销计划失败后的安全资源清理未完全收敛',
          name: 'Kelivo.E2eeDeviceRevocationPlanPreparer',
          error: cleanupError.$1,
          stackTrace: cleanupError.$2,
        );
      }
      Error.throwWithStackTrace(primaryError, primaryStackTrace);
    }
    if (cleanupError != null) {
      Error.throwWithStackTrace(cleanupError.$1, cleanupError.$2);
    }
    return prepared!;
  }

  Future<List<CloudSyncDeviceRotationEnvelope>> _sealEnvelopes({
    required E2eeOpenedDeviceStateHandles state,
    required CloudSyncAccountSession session,
    required E2eeVerifiedMembership membership,
  }) async {
    final members = List<E2eeVerifiedMembershipDevice>.of(membership.members)
      ..sort((left, right) => left.deviceId.compareTo(right.deviceId));
    final envelopes = <CloudSyncDeviceRotationEnvelope>[];
    for (final member in members) {
      final envelope = await _secureCore.sealAccountRootKeyEnvelope(
        state.identity,
        state.ark!,
        userId: Uuid.parseAsByteList(session.userId),
        issuerDeviceId: Uuid.parseAsByteList(session.deviceId),
        targetDeviceId: Uuid.parseAsByteList(member.deviceId),
        keyEpoch: membership.keyEpoch,
        targetPublicKeys: KelivoDevicePublicKeys(
          signingPublicKey: member.signingPublicKey,
          keyAgreementPublicKey: member.keyAgreementPublicKey,
        ),
      );
      envelopes.add(
        CloudSyncDeviceRotationEnvelope(
          targetDeviceId: member.deviceId,
          envelopeVersion: 1,
          keyEpoch: membership.keyEpoch,
          accountKeyEnvelope: envelope.bytes,
        ),
      );
    }
    return List<CloudSyncDeviceRotationEnvelope>.unmodifiable(envelopes);
  }

  Future<Uint8List> _sealState({
    required E2eeOpenedDeviceStateHandles state,
    required CloudSyncAccountSession session,
    required int keyEpoch,
  }) {
    return _secureCore.sealDeviceState(
      state.key,
      state.identity,
      deviceId: Uuid.parseAsByteList(session.deviceId),
      keyVersion: session.deviceKeyVersion,
      ark: state.ark!,
      account: KelivoDeviceStateAccountBinding(
        userId: Uuid.parseAsByteList(session.userId),
        keyEpoch: keyEpoch,
      ),
    );
  }

  void _requireSessionScope(CloudSyncAccountSession session) {
    if (session.baseUrl != _baseUrl ||
        session.loginName != _normalizedLoginName) {
      throw const FormatException('设备撤销会话不属于当前账户工作区');
    }
  }
}

/// 生产入口只接收已准备的安全计划，远端提交和本地换钥由同一 runner 收敛。
final class E2eeDeviceRevocationProductionRuntime {
  E2eeDeviceRevocationProductionRuntime({
    required this.planPreparer,
    required this.transitionRunner,
    required this.rotationTransport,
    required this.dataRekeyStateTransport,
  });

  factory E2eeDeviceRevocationProductionRuntime.create({
    required String baseUrl,
    required String normalizedLoginName,
    required DeviceStateBlobStore deviceStateStore,
    required KelivoSecureCore secureCore,
    required ChatDatabaseGateway databaseGateway,
    required File databaseFile,
    required CloudSyncDeviceRotationTransport rotationTransport,
    required CloudSyncDataRekeyTransport dataRekeyTransport,
    required E2eeDataRekeyStageStore stageStore,
    DateTime Function()? clock,
  }) {
    return E2eeDeviceRevocationProductionRuntime(
      planPreparer: E2eeDeviceRevocationPlanPreparer(
        baseUrl: baseUrl,
        normalizedLoginName: normalizedLoginName,
        deviceStateStore: deviceStateStore,
        secureCore: secureCore,
        databaseGateway: databaseGateway,
        databaseFile: databaseFile,
      ),
      transitionRunner: E2eeAccountKeyTransitionProductionRunner(
        baseUrl: baseUrl,
        normalizedLoginName: normalizedLoginName,
        deviceStateStore: deviceStateStore,
        secureCore: secureCore,
        databaseGateway: databaseGateway,
        databaseFile: databaseFile,
        dataRekeyTransport: dataRekeyTransport,
        stageStore: stageStore,
        clock: clock,
      ),
      rotationTransport: rotationTransport,
      dataRekeyStateTransport: dataRekeyTransport,
    );
  }

  final E2eeDeviceRevocationPlanPreparer planPreparer;
  final E2eeAccountKeyTransitionProductionRunner transitionRunner;
  final CloudSyncDeviceRotationTransport rotationTransport;
  final CloudSyncDataRekeyStateTransport dataRekeyStateTransport;

  Future<E2eeAccountKeyTransitionRemoteReceipt> revokeDirect({
    required CloudSyncAccountSession session,
    required String operationId,
    required String revokedDeviceId,
  }) async {
    final prepared = await planPreparer.prepareDirect(
      session: session,
      operationId: operationId,
      revokedDeviceId: revokedDeviceId,
    );
    return _execute(prepared);
  }

  Future<E2eeAccountKeyTransitionRemoteReceipt> approveSelfRevocation({
    required CloudSyncAccountSession session,
    required E2eeVerifiedSelfRevocationIntent intent,
  }) async {
    final prepared = await planPreparer.prepareSelfRevocation(
      session: session,
      intent: intent,
    );
    return _execute(prepared);
  }

  Future<E2eeAccountKeyTransitionRemoteReceipt> _execute(
    E2eePreparedDeviceRevocation prepared,
  ) {
    return transitionRunner.execute(
      plan: prepared.plan,
      remoteCommit: E2eeCloudSyncDeviceRotationRemoteCommit(
        rotationTransport: rotationTransport,
        dataRekeyStateTransport: dataRekeyStateTransport,
        plan: prepared.plan,
        request: prepared.request,
      ),
    );
  }
}

void _requireOpenedStateMatchesSession(
  E2eeOpenedDeviceStateHandles opened,
  CloudSyncAccountSession session,
) {
  final account = opened.binding.account;
  if (account == null ||
      opened.binding.keyVersion != session.deviceKeyVersion ||
      Uuid.unparse(opened.binding.deviceId) != session.deviceId ||
      Uuid.unparse(account.userId) != session.userId ||
      account.keyEpoch != session.keyEpoch) {
    throw const E2eeDeviceStateKeyTransitionConflict();
  }
}

void _requireMembershipMatchesSession(
  E2eeVerifiedMembership membership,
  CloudSyncAccountSession session,
) {
  if (membership.userId != session.userId ||
      membership.keyEpoch != session.keyEpoch) {
    throw const E2eeDeviceStateKeyTransitionConflict();
  }
  final local = membership.members
      .where((member) => member.deviceId == session.deviceId)
      .toList(growable: false);
  if (local.length != 1 ||
      local.single.keyVersion != session.deviceKeyVersion ||
      local.single.authGeneration != session.authGeneration) {
    throw const E2eeDeviceStateKeyTransitionConflict();
  }
}

void _requireRevocationMembers({
  required E2eeVerifiedMembership previous,
  required String issuerDeviceId,
  required String revokedDeviceId,
}) {
  if (issuerDeviceId == revokedDeviceId ||
      !previous.members.any((member) => member.deviceId == issuerDeviceId) ||
      !previous.members.any((member) => member.deviceId == revokedDeviceId)) {
    throw const FormatException('设备撤销目标不属于本地可信成员清单');
  }
}

void _requireAuthorizationMatchesHead({
  required E2eeSelfRevocationRotationBinding? authorization,
  required E2eeVerifiedMembership previous,
  required String revokedDeviceId,
  required String operationId,
}) {
  if (authorization == null) return;
  if (authorization.deviceId != revokedDeviceId ||
      authorization.operationId != operationId ||
      authorization.expectedGeneration != previous.securityGeneration ||
      authorization.expectedKeyEpoch != previous.keyEpoch ||
      !_sameBytes(
        authorization.expectedMembershipManifestDigest,
        previous.digest,
      )) {
    throw const FormatException('自撤销授权未绑定本地可信成员头');
  }
}

Future<(Object, StackTrace)?> _closePreparationResources({
  required KelivoSecureCore secureCore,
  required KelivoAccountRootKeyHandle? generatedEpoch,
  required ChatDatabaseLease? databaseLease,
  required E2eeOpenedDeviceStateHandles? opened,
}) async {
  Object? error;
  StackTrace? stackTrace;

  Future<void> close(Future<void> Function() action) async {
    try {
      await action();
    } catch (caught, caughtStackTrace) {
      error ??= caught;
      stackTrace ??= caughtStackTrace;
    }
  }

  if (databaseLease != null) await close(databaseLease.release);
  if (generatedEpoch != null) {
    await close(() => secureCore.closeAccountRootKey(generatedEpoch));
  }
  if (opened != null) {
    final ark = opened.ark;
    if (ark != null) await close(() => secureCore.closeAccountRootKey(ark));
    await close(() => secureCore.closeDeviceIdentity(opened.identity));
    await close(() => secureCore.close(opened.key));
  }
  return error == null ? null : (error!, stackTrace!);
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}
