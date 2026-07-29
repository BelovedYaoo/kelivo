import 'dart:io';
import 'dart:typed_data';

import 'package:kelivo_secure_core/kelivo_secure_core.dart';

import '../../database/chat_database_gateway.dart';
import 'cloud_sync_types.dart';
import 'e2ee_account_trust_manifest.dart';

final class E2eePreparedDevicePairingMembershipCommit {
  const E2eePreparedDevicePairingMembershipCommit._({
    required this.commit,
    required this._anchorCapability,
  });

  final CloudSyncDevicePairingMembershipCommit commit;
  final _MembershipAnchorCapability _anchorCapability;
}

abstract interface class E2eeDevicePairingMembershipCommitPreparer {
  Future<E2eePreparedDevicePairingMembershipCommit> prepare({
    required KelivoAccountRootKeyHandle accountRootKey,
    required String userId,
    required int keyEpoch,
    required CloudSyncAccountSecurityState currentSecurityState,
    required String pairingId,
    required E2eeMembershipDeviceInput issuer,
    required E2eeMembershipDeviceInput subject,
  });

  Future<void> requireStillCurrent({
    required KelivoAccountRootKeyHandle accountRootKey,
    required E2eePreparedDevicePairingMembershipCommit prepared,
  });
}

final class E2eeDevicePairingMembershipCommitCoordinator
    implements E2eeDevicePairingMembershipCommitPreparer {
  E2eeDevicePairingMembershipCommitCoordinator(
    this._databaseGateway, {
    required File databaseFile,
  }) : _databaseFile = databaseFile.absolute;

  final ChatDatabaseGateway _databaseGateway;
  final File _databaseFile;
  final E2eeAccountTrustManifestModule _manifestModule =
      const E2eeAccountTrustManifestModule();

  @override
  Future<E2eePreparedDevicePairingMembershipCommit> prepare({
    required KelivoAccountRootKeyHandle accountRootKey,
    required String userId,
    required int keyEpoch,
    required CloudSyncAccountSecurityState currentSecurityState,
    required String pairingId,
    required E2eeMembershipDeviceInput issuer,
    required E2eeMembershipDeviceInput subject,
  }) async {
    if (currentSecurityState.keyEpoch != keyEpoch) {
      throw const FormatException('服务端安全状态与本地 ARK 代次不一致');
    }
    if (subject.authGeneration != 1) {
      throw const FormatException('配对目标设备的激活后认证代必须为 1');
    }

    final lease = await _databaseGateway.acquire(_databaseFile);
    try {
      final commands = lease.repository.e2eeVerifiedMembershipAnchorCommands;
      final localAnchor = await commands.readVerified(
        accountUserId: userId,
        ark: accountRootKey,
      );
      if (localAnchor == null) {
        throw StateError('配对批准缺少本地已验证成员锚点');
      }

      final currentVerification = await _manifestModule.verifyCurrentState(
        ark: accountRootKey,
        historyHead: localAnchor.membership,
        projection: _projection(
          userId: userId,
          state: currentSecurityState,
          membershipManifest: currentSecurityState.membershipManifest,
          membershipManifestDigest:
              currentSecurityState.membershipManifestDigest.bytes,
          securityGeneration: currentSecurityState.generation,
          lastOperationId: currentSecurityState.lastOperationId,
        ),
      );
      final previous = currentVerification.membership;
      _requireIssuerMatchesAnchor(previous, issuer);

      final created = await _manifestModule.create(
        ark: accountRootKey,
        change: E2eeAddDeviceMembershipChange(
          previous: previous,
          pairingId: pairingId,
          issuerDeviceId: issuer.deviceId,
          subject: subject,
        ),
      );
      final verified = await _manifestModule.verify(
        ark: accountRootKey,
        expectation: E2eeAddDeviceMembershipExpectation(
          projection: _projection(
            userId: userId,
            state: currentSecurityState,
            membershipManifest: created.manifest,
            membershipManifestDigest: created.digest,
            securityGeneration: created.securityGeneration,
            lastOperationId: pairingId,
          ),
          previous: previous,
          pairingId: pairingId,
          issuerDeviceId: issuer.deviceId,
          subject: subject,
        ),
      );

      final commit = CloudSyncDevicePairingMembershipCommit(
        expectedSecurityGeneration: currentSecurityState.generation,
        expectedMembershipManifestDigest:
            currentSecurityState.membershipManifestDigest,
        nextMembershipManifestVersion: e2eeAccountTrustManifestFormatVersion,
        nextMembershipManifest: verified.manifest,
      );
      if (!_sameBytes(
        commit.nextMembershipManifestDigest.bytes,
        verified.digest,
      )) {
        throw StateError('批准提交摘要与已验证成员清单不一致');
      }
      return E2eePreparedDevicePairingMembershipCommit._(
        commit: commit,
        anchorCapability: _MembershipAnchorCapability(localAnchor),
      );
    } finally {
      await lease.release();
    }
  }

  @override
  Future<void> requireStillCurrent({
    required KelivoAccountRootKeyHandle accountRootKey,
    required E2eePreparedDevicePairingMembershipCommit prepared,
  }) async {
    final capability = prepared._anchorCapability;
    final lease = await _databaseGateway.acquire(_databaseFile);
    try {
      final current = await lease
          .repository
          .e2eeVerifiedMembershipAnchorCommands
          .readVerified(accountUserId: capability.userId, ark: accountRootKey);
      if (current == null || !capability.matches(current)) {
        throw StateError('配对批准期间本地成员锚点已经变化');
      }
    } finally {
      await lease.release();
    }
  }
}

E2eeMembershipServerProjection _projection({
  required String userId,
  required CloudSyncAccountSecurityState state,
  required Uint8List membershipManifest,
  required Uint8List membershipManifestDigest,
  required int securityGeneration,
  required String lastOperationId,
}) {
  if (state.dataRekeyPhase != CloudSyncDataRekeyPhase.ready) {
    throw StateError('配对批准时数据换钥状态必须为 ready');
  }
  return E2eeMembershipServerProjection(
    userId: userId,
    securityGeneration: securityGeneration,
    keyEpoch: state.keyEpoch,
    membershipManifestVersion: e2eeAccountTrustManifestFormatVersion,
    membershipManifest: membershipManifest,
    membershipManifestDigest: membershipManifestDigest,
    recoveryPublicKeyVersion: state.recoveryPublicKeyVersion,
    recoveryPublicKey: state.recoveryPublicKey,
    recoveryCapsuleVersion: state.recoveryCapsuleVersion,
    recoveryCapsule: state.recoveryCapsule,
    lastOperationId: lastOperationId,
    dataRekeyPhase: E2eeDataRekeyPhase.ready,
  );
}

void _requireIssuerMatchesAnchor(
  E2eeVerifiedMembership membership,
  E2eeMembershipDeviceInput issuer,
) {
  E2eeVerifiedMembershipDevice? matched;
  for (final member in membership.members) {
    if (member.deviceId != issuer.deviceId) continue;
    if (matched != null) {
      throw StateError('本地已验证成员锚点包含重复签发设备');
    }
    matched = member;
  }
  if (matched == null ||
      matched.keyVersion != issuer.keyVersion ||
      matched.authGeneration != issuer.authGeneration ||
      !_sameBytes(matched.signingPublicKey, issuer.signingPublicKey) ||
      !_sameBytes(
        matched.keyAgreementPublicKey,
        issuer.keyAgreementPublicKey,
      )) {
    throw const FormatException('配对签发设备与当前成员锚点不一致');
  }
}

final class _MembershipAnchorCapability {
  _MembershipAnchorCapability(E2eeLocallyVerifiedMembershipAnchor anchor)
    : userId = anchor.membership.userId,
      securityGeneration = anchor.membership.securityGeneration,
      keyEpoch = anchor.membership.keyEpoch,
      manifest = _immutableBytes(anchor.membership.manifest),
      manifestDigest = _immutableBytes(anchor.membership.digest),
      transitionVersion = anchor.transitionVersion,
      createdAt = anchor.createdAt.toUtc(),
      updatedAt = anchor.updatedAt.toUtc();

  final String userId;
  final int securityGeneration;
  final int keyEpoch;
  final Uint8List manifest;
  final Uint8List manifestDigest;
  final int transitionVersion;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool matches(E2eeLocallyVerifiedMembershipAnchor current) {
    final membership = current.membership;
    return membership.userId == userId &&
        membership.securityGeneration == securityGeneration &&
        membership.keyEpoch == keyEpoch &&
        current.transitionVersion == transitionVersion &&
        current.createdAt.toUtc().isAtSameMomentAs(createdAt) &&
        current.updatedAt.toUtc().isAtSameMomentAs(updatedAt) &&
        _sameBytes(membership.manifest, manifest) &&
        _sameBytes(membership.digest, manifestDigest);
  }
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

Uint8List _immutableBytes(List<int> value) =>
    Uint8List.fromList(value).asUnmodifiableView();
