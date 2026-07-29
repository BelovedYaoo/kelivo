import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';

part '../../database/e2ee_verified_membership_anchor_commands.dart';

const e2eeAccountTrustManifestFormatVersion = 1;
const e2eeAccountTrustManifestMaximumMembers = 256;
const e2eeAccountTrustManifestMaximumHistoryBatchEntries = 256;
const e2eeAccountTrustManifestMaximumHistoryEntries = 4096;
const e2eeAccountTrustManifestMaximumRecoveryCapsuleLength = 4096;

const _manifestHeaderLength = 228;
const _manifestMemberLength = 88;
const _manifestSignatureLength = 64;
const _manifestSignatureSectionLength = _manifestSignatureLength * 2;
const _manifestDigestLength = 32;
const _publicKeyLength = 32;
const _maximumSecurityGeneration = 0x7fffffff;
const _maximumDeviceCounter = 0x7fffffff;
const _maximumUint32 = 0xffffffff;
final _manifestMagic = Uint8List.fromList(ascii.encode('KELIVOMM'));
final _zeroDigest = Uint8List(_manifestDigestLength).asUnmodifiableView();
final _zeroSignature = Uint8List(_manifestSignatureLength).asUnmodifiableView();

const e2eeAccountTrustManifestMaximumLength =
    _manifestHeaderLength +
    e2eeAccountTrustManifestMaximumMembers * _manifestMemberLength +
    _manifestSignatureSectionLength;
const e2eeAccountTrustManifestMinimumLength =
    _manifestHeaderLength +
    _manifestMemberLength +
    _manifestSignatureSectionLength;

enum E2eeMembershipOperationKind {
  initialize,
  addDevice,
  revokeRotate,
  recoverResume,
  recoverReplace,
}

enum E2eeDataRekeyPhase { ready, rekeyPending }

final class E2eeMembershipDeviceInput {
  factory E2eeMembershipDeviceInput({
    required String deviceId,
    required int keyVersion,
    required int authGeneration,
    required Uint8List signingPublicKey,
    required Uint8List keyAgreementPublicKey,
  }) {
    final canonicalDeviceId = _canonicalUuidV4(deviceId, 'deviceId');
    _requirePositiveDeviceCounter(keyVersion, 'keyVersion');
    _requireDeviceAuthGeneration(authGeneration, 'authGeneration');
    return E2eeMembershipDeviceInput._(
      canonicalDeviceId,
      _uuidBytes(canonicalDeviceId),
      keyVersion,
      authGeneration,
      _copyFixed(signingPublicKey, _publicKeyLength, 'signingPublicKey'),
      _copyFixed(
        keyAgreementPublicKey,
        _publicKeyLength,
        'keyAgreementPublicKey',
      ),
    );
  }

  const E2eeMembershipDeviceInput._(
    this.deviceId,
    this._deviceIdBytes,
    this.keyVersion,
    this.authGeneration,
    this.signingPublicKey,
    this.keyAgreementPublicKey,
  );

  final String deviceId;
  final Uint8List _deviceIdBytes;
  final int keyVersion;
  final int authGeneration;
  final Uint8List signingPublicKey;
  final Uint8List keyAgreementPublicKey;
}

final class E2eeVerifiedMembershipDevice {
  E2eeVerifiedMembershipDevice._(_MembershipMember member)
    : deviceId = member.deviceId,
      keyVersion = member.keyVersion,
      authGeneration = member.authGeneration,
      signingPublicKey = _immutableBytes(member.signingPublicKey),
      keyAgreementPublicKey = _immutableBytes(member.keyAgreementPublicKey);

  final String deviceId;
  final int keyVersion;
  final int authGeneration;
  final Uint8List signingPublicKey;
  final Uint8List keyAgreementPublicKey;
}

final class E2eeMembershipServerProjection {
  factory E2eeMembershipServerProjection({
    required String userId,
    required int securityGeneration,
    required int keyEpoch,
    required int membershipManifestVersion,
    required Uint8List membershipManifest,
    required Uint8List membershipManifestDigest,
    required int recoveryPublicKeyVersion,
    required Uint8List recoveryPublicKey,
    required int recoveryCapsuleVersion,
    required Uint8List recoveryCapsule,
    required String lastOperationId,
    required E2eeDataRekeyPhase dataRekeyPhase,
  }) {
    final canonicalUserId = _canonicalUuidV4(userId, 'userId');
    _requireSecurityGeneration(securityGeneration, 'securityGeneration');
    _requirePositiveUint32(keyEpoch, 'keyEpoch');
    _requirePositiveUint32(
      membershipManifestVersion,
      'membershipManifestVersion',
    );
    if (membershipManifest.length < e2eeAccountTrustManifestMinimumLength ||
        membershipManifest.length > e2eeAccountTrustManifestMaximumLength) {
      throw ArgumentError.value(
        membershipManifest.length,
        'membershipManifest',
        '不在成员清单协议长度范围内',
      );
    }
    _requirePositiveUint32(
      recoveryPublicKeyVersion,
      'recoveryPublicKeyVersion',
    );
    _requirePositiveUint32(recoveryCapsuleVersion, 'recoveryCapsuleVersion');
    final canonicalLastOperationId = _canonicalUuidV4(
      lastOperationId,
      'lastOperationId',
    );
    return E2eeMembershipServerProjection._(
      canonicalUserId,
      securityGeneration,
      keyEpoch,
      membershipManifestVersion,
      _immutableBytes(membershipManifest),
      _copyFixed(
        membershipManifestDigest,
        _manifestDigestLength,
        'membershipManifestDigest',
      ),
      recoveryPublicKeyVersion,
      _copyFixed(recoveryPublicKey, _publicKeyLength, 'recoveryPublicKey'),
      recoveryCapsuleVersion,
      _copyRecoveryCapsule(recoveryCapsule),
      canonicalLastOperationId,
      dataRekeyPhase,
    );
  }

  const E2eeMembershipServerProjection._(
    this.userId,
    this.securityGeneration,
    this.keyEpoch,
    this.membershipManifestVersion,
    this.membershipManifest,
    this.membershipManifestDigest,
    this.recoveryPublicKeyVersion,
    this.recoveryPublicKey,
    this.recoveryCapsuleVersion,
    this.recoveryCapsule,
    this.lastOperationId,
    this.dataRekeyPhase,
  );

  final String userId;
  final int securityGeneration;
  final int keyEpoch;
  final int membershipManifestVersion;
  final Uint8List membershipManifest;
  final Uint8List membershipManifestDigest;
  final int recoveryPublicKeyVersion;
  final Uint8List recoveryPublicKey;
  final int recoveryCapsuleVersion;
  final Uint8List recoveryCapsule;
  final String lastOperationId;
  final E2eeDataRekeyPhase dataRekeyPhase;
}

final class E2eeMembershipHistoryEntry {
  factory E2eeMembershipHistoryEntry({
    required Uint8List manifest,
    required Uint8List manifestDigest,
  }) {
    if (manifest.length < e2eeAccountTrustManifestMinimumLength ||
        manifest.length > e2eeAccountTrustManifestMaximumLength) {
      throw ArgumentError.value(manifest.length, 'manifest', '成员清单长度无效');
    }
    return E2eeMembershipHistoryEntry._(
      _immutableBytes(manifest),
      _copyFixed(manifestDigest, _manifestDigestLength, 'manifestDigest'),
    );
  }

  const E2eeMembershipHistoryEntry._(this.manifest, this.manifestDigest);

  final Uint8List manifest;
  final Uint8List manifestDigest;
}

sealed class E2eeAccountTrustManifestChange {
  const E2eeAccountTrustManifestChange._();
}

final class E2eeInitializeMembershipChange
    extends E2eeAccountTrustManifestChange {
  factory E2eeInitializeMembershipChange({
    required String userId,
    required String operationId,
    required E2eeMembershipDeviceInput member,
    required int recoveryPublicKeyVersion,
    required Uint8List recoveryPublicKey,
    required int recoveryCapsuleVersion,
    required Uint8List recoveryCapsule,
  }) {
    _requirePositiveUint32(
      recoveryPublicKeyVersion,
      'recoveryPublicKeyVersion',
    );
    _requirePositiveUint32(recoveryCapsuleVersion, 'recoveryCapsuleVersion');
    return E2eeInitializeMembershipChange._(
      _canonicalUuidV4(userId, 'userId'),
      _canonicalUuidV4(operationId, 'operationId'),
      member,
      recoveryPublicKeyVersion,
      _copyFixed(recoveryPublicKey, _publicKeyLength, 'recoveryPublicKey'),
      recoveryCapsuleVersion,
      _copyRecoveryCapsule(recoveryCapsule),
    );
  }

  const E2eeInitializeMembershipChange._(
    this.userId,
    this.operationId,
    this.member,
    this.recoveryPublicKeyVersion,
    this.recoveryPublicKey,
    this.recoveryCapsuleVersion,
    this.recoveryCapsule,
  ) : super._();

  final String userId;
  final String operationId;
  final E2eeMembershipDeviceInput member;
  final int recoveryPublicKeyVersion;
  final Uint8List recoveryPublicKey;
  final int recoveryCapsuleVersion;
  final Uint8List recoveryCapsule;
}

final class E2eeAddDeviceMembershipChange
    extends E2eeAccountTrustManifestChange {
  factory E2eeAddDeviceMembershipChange({
    required E2eeVerifiedMembership previous,
    required String pairingId,
    required String issuerDeviceId,
    required E2eeMembershipDeviceInput subject,
  }) {
    return E2eeAddDeviceMembershipChange._(
      previous,
      _canonicalUuidV4(pairingId, 'pairingId'),
      _canonicalUuidV4(issuerDeviceId, 'issuerDeviceId'),
      subject,
    );
  }

  const E2eeAddDeviceMembershipChange._(
    this.previous,
    this.pairingId,
    this.issuerDeviceId,
    this.subject,
  ) : super._();

  final E2eeVerifiedMembership previous;
  final String pairingId;
  final String issuerDeviceId;
  final E2eeMembershipDeviceInput subject;
}

final class E2eeRevokeRotateMembershipChange
    extends E2eeAccountTrustManifestChange {
  factory E2eeRevokeRotateMembershipChange({
    required E2eeVerifiedMembership previous,
    required String operationId,
    required String issuerDeviceId,
    required String revokedDeviceId,
    required int nextRecoveryCapsuleVersion,
    required Uint8List nextRecoveryCapsule,
  }) {
    _requirePositiveUint32(
      nextRecoveryCapsuleVersion,
      'nextRecoveryCapsuleVersion',
    );
    return E2eeRevokeRotateMembershipChange._(
      previous,
      _canonicalUuidV4(operationId, 'operationId'),
      _canonicalUuidV4(issuerDeviceId, 'issuerDeviceId'),
      _canonicalUuidV4(revokedDeviceId, 'revokedDeviceId'),
      nextRecoveryCapsuleVersion,
      _copyRecoveryCapsule(nextRecoveryCapsule),
    );
  }

  const E2eeRevokeRotateMembershipChange._(
    this.previous,
    this.operationId,
    this.issuerDeviceId,
    this.revokedDeviceId,
    this.nextRecoveryCapsuleVersion,
    this.nextRecoveryCapsule,
  ) : super._();

  final E2eeVerifiedMembership previous;
  final String operationId;
  final String issuerDeviceId;
  final String revokedDeviceId;
  final int nextRecoveryCapsuleVersion;
  final Uint8List nextRecoveryCapsule;
}

final class E2eeRecoverResumeMembershipChange
    extends E2eeAccountTrustManifestChange {
  factory E2eeRecoverResumeMembershipChange({
    required E2eeVerifiedMembership previous,
    required String operationId,
    required E2eeMembershipDeviceInput subject,
  }) {
    return E2eeRecoverResumeMembershipChange._(
      previous,
      _canonicalUuidV4(operationId, 'operationId'),
      subject,
    );
  }

  const E2eeRecoverResumeMembershipChange._(
    this.previous,
    this.operationId,
    this.subject,
  ) : super._();

  final E2eeVerifiedMembership previous;
  final String operationId;
  final E2eeMembershipDeviceInput subject;
}

final class E2eeRecoverReplaceMembershipChange
    extends E2eeAccountTrustManifestChange {
  factory E2eeRecoverReplaceMembershipChange({
    required E2eeVerifiedMembership previous,
    required String operationId,
    required E2eeMembershipDeviceInput subject,
    required int nextRecoveryCapsuleVersion,
    required Uint8List nextRecoveryCapsule,
  }) {
    _requirePositiveUint32(
      nextRecoveryCapsuleVersion,
      'nextRecoveryCapsuleVersion',
    );
    return E2eeRecoverReplaceMembershipChange._(
      previous,
      _canonicalUuidV4(operationId, 'operationId'),
      subject,
      nextRecoveryCapsuleVersion,
      _copyRecoveryCapsule(nextRecoveryCapsule),
    );
  }

  const E2eeRecoverReplaceMembershipChange._(
    this.previous,
    this.operationId,
    this.subject,
    this.nextRecoveryCapsuleVersion,
    this.nextRecoveryCapsule,
  ) : super._();

  final E2eeVerifiedMembership previous;
  final String operationId;
  final E2eeMembershipDeviceInput subject;
  final int nextRecoveryCapsuleVersion;
  final Uint8List nextRecoveryCapsule;
}

sealed class E2eeAccountTrustManifestExpectation {
  const E2eeAccountTrustManifestExpectation._();

  E2eeMembershipServerProjection get projection;
}

final class E2eeInitializeMembershipExpectation
    extends E2eeAccountTrustManifestExpectation {
  factory E2eeInitializeMembershipExpectation({
    required E2eeMembershipServerProjection projection,
    required String operationId,
    required E2eeMembershipDeviceInput member,
  }) {
    return E2eeInitializeMembershipExpectation._(
      projection,
      _canonicalUuidV4(operationId, 'operationId'),
      member,
    );
  }

  const E2eeInitializeMembershipExpectation._(
    this.projection,
    this.operationId,
    this.member,
  ) : super._();

  @override
  final E2eeMembershipServerProjection projection;
  final String operationId;
  final E2eeMembershipDeviceInput member;
}

final class E2eeAddDeviceMembershipExpectation
    extends E2eeAccountTrustManifestExpectation {
  factory E2eeAddDeviceMembershipExpectation({
    required E2eeMembershipServerProjection projection,
    required E2eeVerifiedMembership previous,
    required String pairingId,
    required String issuerDeviceId,
    required E2eeMembershipDeviceInput subject,
  }) {
    return E2eeAddDeviceMembershipExpectation._(
      projection,
      previous,
      _canonicalUuidV4(pairingId, 'pairingId'),
      _canonicalUuidV4(issuerDeviceId, 'issuerDeviceId'),
      subject,
    );
  }

  const E2eeAddDeviceMembershipExpectation._(
    this.projection,
    this.previous,
    this.pairingId,
    this.issuerDeviceId,
    this.subject,
  ) : super._();

  @override
  final E2eeMembershipServerProjection projection;
  final E2eeVerifiedMembership previous;
  final String pairingId;
  final String issuerDeviceId;
  final E2eeMembershipDeviceInput subject;
}

final class E2eeRevokeRotateMembershipExpectation
    extends E2eeAccountTrustManifestExpectation {
  factory E2eeRevokeRotateMembershipExpectation({
    required E2eeMembershipServerProjection projection,
    required E2eeVerifiedMembership previous,
    required String operationId,
    required String issuerDeviceId,
    required String revokedDeviceId,
  }) {
    return E2eeRevokeRotateMembershipExpectation._(
      projection,
      previous,
      _canonicalUuidV4(operationId, 'operationId'),
      _canonicalUuidV4(issuerDeviceId, 'issuerDeviceId'),
      _canonicalUuidV4(revokedDeviceId, 'revokedDeviceId'),
    );
  }

  const E2eeRevokeRotateMembershipExpectation._(
    this.projection,
    this.previous,
    this.operationId,
    this.issuerDeviceId,
    this.revokedDeviceId,
  ) : super._();

  @override
  final E2eeMembershipServerProjection projection;
  final E2eeVerifiedMembership previous;
  final String operationId;
  final String issuerDeviceId;
  final String revokedDeviceId;
}

final class E2eeRecoverResumeMembershipExpectation
    extends E2eeAccountTrustManifestExpectation {
  factory E2eeRecoverResumeMembershipExpectation({
    required E2eeMembershipServerProjection projection,
    required E2eeVerifiedMembership previous,
    required String operationId,
    required E2eeMembershipDeviceInput subject,
  }) {
    return E2eeRecoverResumeMembershipExpectation._(
      projection,
      previous,
      _canonicalUuidV4(operationId, 'operationId'),
      subject,
    );
  }

  const E2eeRecoverResumeMembershipExpectation._(
    this.projection,
    this.previous,
    this.operationId,
    this.subject,
  ) : super._();

  @override
  final E2eeMembershipServerProjection projection;
  final E2eeVerifiedMembership previous;
  final String operationId;
  final E2eeMembershipDeviceInput subject;
}

final class E2eeRecoverReplaceMembershipExpectation
    extends E2eeAccountTrustManifestExpectation {
  factory E2eeRecoverReplaceMembershipExpectation({
    required E2eeMembershipServerProjection projection,
    required E2eeVerifiedMembership previous,
    required String operationId,
    required E2eeMembershipDeviceInput subject,
  }) {
    return E2eeRecoverReplaceMembershipExpectation._(
      projection,
      previous,
      _canonicalUuidV4(operationId, 'operationId'),
      subject,
    );
  }

  const E2eeRecoverReplaceMembershipExpectation._(
    this.projection,
    this.previous,
    this.operationId,
    this.subject,
  ) : super._();

  @override
  final E2eeMembershipServerProjection projection;
  final E2eeVerifiedMembership previous;
  final String operationId;
  final E2eeMembershipDeviceInput subject;
}

final class E2eePairingBootstrapMembershipExpectation
    extends E2eeAccountTrustManifestExpectation {
  factory E2eePairingBootstrapMembershipExpectation({
    required E2eeMembershipServerProjection projection,
    required int consumedKeyEpoch,
    required int consumedSecurityGeneration,
    required Uint8List consumedMembershipManifestDigest,
    required String pairingId,
    required String issuerDeviceId,
    required E2eeMembershipDeviceInput localMember,
  }) {
    _requirePositiveUint32(consumedKeyEpoch, 'consumedKeyEpoch');
    _requireSecurityGeneration(
      consumedSecurityGeneration,
      'consumedSecurityGeneration',
    );
    return E2eePairingBootstrapMembershipExpectation._(
      projection,
      consumedKeyEpoch,
      consumedSecurityGeneration,
      _copyFixed(
        consumedMembershipManifestDigest,
        _manifestDigestLength,
        'consumedMembershipManifestDigest',
      ),
      _canonicalUuidV4(pairingId, 'pairingId'),
      _canonicalUuidV4(issuerDeviceId, 'issuerDeviceId'),
      localMember,
    );
  }

  const E2eePairingBootstrapMembershipExpectation._(
    this.projection,
    this.consumedKeyEpoch,
    this.consumedSecurityGeneration,
    this.consumedMembershipManifestDigest,
    this.pairingId,
    this.issuerDeviceId,
    this.localMember,
  ) : super._();

  @override
  final E2eeMembershipServerProjection projection;
  final int consumedKeyEpoch;
  final int consumedSecurityGeneration;
  final Uint8List consumedMembershipManifestDigest;
  final String pairingId;
  final String issuerDeviceId;
  final E2eeMembershipDeviceInput localMember;
}

final class E2eeVerifiedMembership {
  E2eeVerifiedMembership._({
    required _ManifestData data,
    required Uint8List manifest,
    required Uint8List digest,
    required Set<String> operationIds,
    required this._hasCompleteOperationHistory,
  }) : _data = data,
       _operationIds = Set<String>.unmodifiable(operationIds),
       manifest = _immutableBytes(manifest),
       digest = _immutableBytes(digest),
       userId = data.userId,
       securityGeneration = data.securityGeneration,
       keyEpoch = data.keyEpoch,
       previousDigest = _immutableBytes(data.previousDigest),
       currentAccountTrustPublicKey = _immutableBytes(
         data.currentAccountTrustPublicKey,
       ),
       recoveryPublicKeyVersion = data.recoveryPublicKeyVersion,
       recoveryPublicKey = _immutableBytes(data.recoveryPublicKey),
       recoveryCapsuleVersion = data.recoveryCapsuleVersion,
       recoveryCapsuleDigest = _immutableBytes(data.recoveryCapsuleDigest),
       operationKind = data.operationKind,
       operationId = data.operationId,
       issuerDeviceId = data.issuerDeviceId,
       subjectDeviceId = data.subjectDeviceId,
       members = List<E2eeVerifiedMembershipDevice>.unmodifiable(
         data.members.map(E2eeVerifiedMembershipDevice._),
       );

  final _ManifestData _data;
  final Set<String> _operationIds;
  final bool _hasCompleteOperationHistory;
  final Uint8List manifest;
  final Uint8List digest;
  final String userId;
  final int securityGeneration;
  final int keyEpoch;
  final Uint8List previousDigest;
  final Uint8List currentAccountTrustPublicKey;
  final int recoveryPublicKeyVersion;
  final Uint8List recoveryPublicKey;
  final int recoveryCapsuleVersion;
  final Uint8List recoveryCapsuleDigest;
  final E2eeMembershipOperationKind operationKind;
  final String operationId;
  final String issuerDeviceId;
  final String subjectDeviceId;
  final List<E2eeVerifiedMembershipDevice> members;
}

final class E2eeCurrentSecurityStateVerification {
  const E2eeCurrentSecurityStateVerification._(
    this.membership,
    this.reportedDataRekeyPhase,
  );

  final E2eeVerifiedMembership membership;

  // 该值是服务端可变运行状态，不能替代独立签名的 rekey completion proof。
  final E2eeDataRekeyPhase reportedDataRekeyPhase;
}

final class E2eeAccountTrustManifestModule {
  const E2eeAccountTrustManifestModule({
    this._secureCore = const KelivoSecureCore(),
  });

  final KelivoSecureCore _secureCore;

  Future<E2eeVerifiedMembership> create({
    required KelivoAccountRootKeyHandle ark,
    required E2eeAccountTrustManifestChange change,
  }) async {
    final operationHistory = _operationHistoryForChange(change);
    final signingContext = _changeSigningContext(change);
    final currentTrustPublicKey = await _secureCore.deriveAccountTrustPublicKey(
      ark,
      userId: signingContext.$1,
      keyEpoch: signingContext.$2,
    );
    final data = switch (change) {
      E2eeInitializeMembershipChange value => _buildInitialize(
        value,
        currentTrustPublicKey.bytes,
      ),
      E2eeAddDeviceMembershipChange value => _buildAddDevice(
        value,
        currentTrustPublicKey.bytes,
      ),
      E2eeRevokeRotateMembershipChange value => _buildRevokeRotate(
        value,
        currentTrustPublicKey.bytes,
      ),
      E2eeRecoverResumeMembershipChange value => _buildRecoverResume(
        value,
        currentTrustPublicKey.bytes,
      ),
      E2eeRecoverReplaceMembershipChange value => _buildRecoverReplace(
        value,
        currentTrustPublicKey.bytes,
      ),
    };
    _validateRecoveryKeySeparation(data.recoveryPublicKey, data.members);
    await _validatePublicMaterial(data);
    final payload = _encodePayload(data);
    var transitionSignature = _zeroSignature;
    final transitionPrevious = switch (change) {
      E2eeRevokeRotateMembershipChange value => value.previous,
      E2eeRecoverReplaceMembershipChange value => value.previous,
      _ => null,
    };
    if (transitionPrevious != null) {
      transitionSignature = (await _secureCore.signAccountTrustPayload(
        ark,
        userId: data.userIdBytes,
        keyEpoch: transitionPrevious.keyEpoch,
        canonicalPayload: payload,
      )).bytes;
    }
    final currentSignature = await _secureCore.signAccountTrustPayload(
      ark,
      userId: data.userIdBytes,
      keyEpoch: data.keyEpoch,
      canonicalPayload: payload,
    );
    final transitionOffset = payload.length;
    final currentOffset = transitionOffset + _manifestSignatureLength;
    final manifest = Uint8List(payload.length + _manifestSignatureSectionLength)
      ..setRange(0, payload.length, payload)
      ..setRange(transitionOffset, currentOffset, transitionSignature)
      ..setRange(
        currentOffset,
        currentOffset + _manifestSignatureLength,
        currentSignature.bytes,
      );
    return _verified(data, manifest, operationHistory);
  }

  Future<E2eeVerifiedMembership> verify({
    required KelivoAccountRootKeyHandle ark,
    required E2eeAccountTrustManifestExpectation expectation,
  }) async {
    final projection = expectation.projection;
    final manifest = Uint8List.fromList(projection.membershipManifest);
    final digest = _sha256(manifest);
    if (!_sameBytes(digest, projection.membershipManifestDigest)) {
      throw StateError('成员清单摘要与服务端投影不一致');
    }
    final parsed = _parseManifest(manifest);
    final operationHistory = _operationHistoryForExpectation(
      expectation,
      parsed.data.operationId,
    );
    _validateProjection(parsed.data, projection);
    await _verifyWithAccountRootKey(ark, parsed);
    await _verifyExpectedTransition(parsed, expectation);
    await _validatePublicMaterial(parsed.data);
    _validateExpectation(parsed.data, expectation);
    return E2eeVerifiedMembership._(
      data: parsed.data,
      manifest: manifest,
      digest: digest,
      operationIds: operationHistory.ids,
      hasCompleteOperationHistory: operationHistory.isComplete,
    );
  }

  Future<E2eeVerifiedMembership> _verifyPersistedAnchor({
    required KelivoAccountRootKeyHandle ark,
    required String userId,
    required int securityGeneration,
    required int keyEpoch,
    required Uint8List persistedManifest,
    required Uint8List persistedManifestDigest,
  }) async {
    final expectedUserId = _canonicalUuidV4(userId, 'userId');
    _requireSecurityGeneration(securityGeneration, 'securityGeneration');
    _requirePositiveUint32(keyEpoch, 'keyEpoch');
    final manifest = Uint8List.fromList(persistedManifest);
    final expectedDigest = _copyFixed(
      persistedManifestDigest,
      _manifestDigestLength,
      'persistedManifestDigest',
    );
    final digest = _sha256(manifest);
    if (!_sameBytes(digest, expectedDigest)) {
      throw StateError('本地成员清单锚点摘要不一致');
    }
    final parsed = _parseManifest(manifest);
    if (parsed.data.userId != expectedUserId ||
        parsed.data.securityGeneration != securityGeneration ||
        parsed.data.keyEpoch != keyEpoch) {
      throw StateError('本地成员清单锚点外层状态不一致');
    }
    switch (parsed.data.operationKind) {
      case E2eeMembershipOperationKind.initialize:
      case E2eeMembershipOperationKind.addDevice:
      case E2eeMembershipOperationKind.recoverResume:
        _requireZeroTransitionSignature(parsed.transitionSignature);
      case E2eeMembershipOperationKind.revokeRotate:
      case E2eeMembershipOperationKind.recoverReplace:
        // 旧代签名在写入前已沿完整历史验证；重启后由 SQLCipher 锚和当前 ARK 共同认证。
        _requireNonZeroTransitionSignature(parsed.transitionSignature);
    }
    await _verifyWithAccountRootKey(ark, parsed);
    await _validatePublicMaterial(parsed.data);
    return E2eeVerifiedMembership._(
      data: parsed.data,
      manifest: manifest,
      digest: digest,
      operationIds: <String>{parsed.data.operationId},
      hasCompleteOperationHistory: false,
    );
  }

  Future<E2eeVerifiedMembership> verifyHistoryBatch({
    required E2eeVerifiedMembership previous,
    required List<E2eeMembershipHistoryEntry> entries,
  }) async {
    if (entries.isEmpty) {
      throw ArgumentError('历史清单批次不能为空');
    }
    if (entries.length > e2eeAccountTrustManifestMaximumHistoryBatchEntries) {
      throw ArgumentError('单批历史清单不得超过 256 份');
    }
    final snapshot = List<E2eeMembershipHistoryEntry>.of(
      entries,
      growable: false,
    );
    var current = previous;
    for (final entry in snapshot) {
      current = await _verifyHistorySuccessor(current, entry);
    }
    return current;
  }

  Future<E2eeCurrentSecurityStateVerification> verifyCurrentState({
    required KelivoAccountRootKeyHandle ark,
    required E2eeVerifiedMembership historyHead,
    required E2eeMembershipServerProjection projection,
  }) async {
    if (!_sameBytes(historyHead.manifest, projection.membershipManifest) ||
        !_sameBytes(historyHead.digest, projection.membershipManifestDigest)) {
      throw StateError('服务端当前安全状态不是已验证历史链头');
    }
    _validateProjection(historyHead._data, projection);
    _validateProjectionOperation(historyHead._data, projection.lastOperationId);
    final trustPublicKey = await _secureCore.deriveAccountTrustPublicKey(
      ark,
      userId: historyHead._data.userIdBytes,
      keyEpoch: historyHead.keyEpoch,
    );
    if (!_sameBytes(
      trustPublicKey.bytes,
      historyHead.currentAccountTrustPublicKey,
    )) {
      throw StateError('恢复 capsule 中的 ARK 与已验证历史链头不匹配');
    }
    final parsed = _parseManifest(historyHead.manifest);
    await _secureCore.verifyAccountTrustPayload(
      trustPublicKey,
      userId: parsed.data.userIdBytes,
      keyEpoch: parsed.data.keyEpoch,
      canonicalPayload: parsed.payload,
      signature: KelivoAccountTrustSignature(parsed.currentSignature),
    );
    // 单一服务器仍可回放有效旧前缀造成回滚或拒绝服务，不能据此声称全局最新。
    return E2eeCurrentSecurityStateVerification._(
      historyHead,
      projection.dataRekeyPhase,
    );
  }

  Future<void> _verifyWithAccountRootKey(
    KelivoAccountRootKeyHandle ark,
    _ParsedManifest parsed,
  ) async {
    // 当前公钥必须由本地已认证 ARK 派生，服务端裸公钥不能进入该信任入口。
    final trustPublicKey = await _secureCore.deriveAccountTrustPublicKey(
      ark,
      userId: parsed.data.userIdBytes,
      keyEpoch: parsed.data.keyEpoch,
    );
    if (!_sameBytes(
      trustPublicKey.bytes,
      parsed.data.currentAccountTrustPublicKey,
    )) {
      throw StateError('成员清单账户信任公钥与本地 ARK 不匹配');
    }
    await _secureCore.verifyAccountTrustPayload(
      trustPublicKey,
      userId: parsed.data.userIdBytes,
      keyEpoch: parsed.data.keyEpoch,
      canonicalPayload: parsed.payload,
      signature: KelivoAccountTrustSignature(parsed.currentSignature),
    );
  }

  Future<void> _verifyExpectedTransition(
    _ParsedManifest parsed,
    E2eeAccountTrustManifestExpectation expectation,
  ) async {
    switch (expectation) {
      case E2eeInitializeMembershipExpectation():
      case E2eeAddDeviceMembershipExpectation():
      case E2eePairingBootstrapMembershipExpectation():
      case E2eeRecoverResumeMembershipExpectation():
        _requireZeroTransitionSignature(parsed.transitionSignature);
      case E2eeRevokeRotateMembershipExpectation value:
        _requireNonZeroTransitionSignature(parsed.transitionSignature);
        await _verifyPreviousEpochTransition(parsed, previous: value.previous);
      case E2eeRecoverReplaceMembershipExpectation value:
        _requireNonZeroTransitionSignature(parsed.transitionSignature);
        await _verifyPreviousEpochTransition(parsed, previous: value.previous);
    }
  }

  Future<E2eeVerifiedMembership> _verifyHistorySuccessor(
    E2eeVerifiedMembership previous,
    E2eeMembershipHistoryEntry entry,
  ) async {
    final manifest = Uint8List.fromList(entry.manifest);
    final digest = _sha256(manifest);
    if (!_sameBytes(digest, entry.manifestDigest)) {
      throw StateError('历史成员清单摘要不一致');
    }
    final parsed = _parseManifest(manifest);
    final operationHistory = _nextOperationHistory(
      previous: previous,
      operationId: parsed.data.operationId,
      requireComplete: _isRecoveryOperation(parsed.data.operationKind),
    );
    _validateHistorySuccessor(parsed.data, previous);
    switch (parsed.data.operationKind) {
      case E2eeMembershipOperationKind.initialize:
        throw StateError('genesis 之后不能再次初始化成员清单');
      case E2eeMembershipOperationKind.addDevice:
      case E2eeMembershipOperationKind.recoverResume:
        _requireZeroTransitionSignature(parsed.transitionSignature);
      case E2eeMembershipOperationKind.revokeRotate:
      case E2eeMembershipOperationKind.recoverReplace:
        _requireNonZeroTransitionSignature(parsed.transitionSignature);
        await _verifyPreviousEpochTransition(parsed, previous: previous);
    }
    await _verifyCurrentSignatureFromHistory(parsed);
    await _validatePublicMaterial(parsed.data);
    return E2eeVerifiedMembership._(
      data: parsed.data,
      manifest: manifest,
      digest: digest,
      operationIds: operationHistory.ids,
      hasCompleteOperationHistory: operationHistory.isComplete,
    );
  }

  Future<void> _verifyPreviousEpochTransition(
    _ParsedManifest parsed, {
    required E2eeVerifiedMembership previous,
  }) {
    return _secureCore.verifyUntrustedAccountTrustPayload(
      KelivoUntrustedAccountTrustPublicKey.fromTransport(
        previous.currentAccountTrustPublicKey,
      ),
      userId: parsed.data.userIdBytes,
      keyEpoch: previous.keyEpoch,
      canonicalPayload: parsed.payload,
      signature: KelivoAccountTrustSignature(parsed.transitionSignature),
    );
  }

  Future<void> _verifyCurrentSignatureFromHistory(_ParsedManifest parsed) {
    return _secureCore.verifyUntrustedAccountTrustPayload(
      KelivoUntrustedAccountTrustPublicKey.fromTransport(
        parsed.data.currentAccountTrustPublicKey,
      ),
      userId: parsed.data.userIdBytes,
      keyEpoch: parsed.data.keyEpoch,
      canonicalPayload: parsed.payload,
      signature: KelivoAccountTrustSignature(parsed.currentSignature),
    );
  }

  Future<void> _validatePublicMaterial(_ManifestData data) {
    return _secureCore.validateDevicePublicKeys(
      <KelivoDevicePublicKeys>[
        for (final member in data.members)
          KelivoDevicePublicKeys(
            signingPublicKey: member.signingPublicKey,
            keyAgreementPublicKey: member.keyAgreementPublicKey,
          ),
      ],
      additionalKeyAgreementPublicKeys: <Uint8List>[data.recoveryPublicKey],
    );
  }
}

typedef _OperationHistory = ({Set<String> ids, bool isComplete});

_OperationHistory _operationHistoryForChange(
  E2eeAccountTrustManifestChange change,
) {
  return switch (change) {
    E2eeInitializeMembershipChange value => _initialOperationHistory(
      value.operationId,
    ),
    E2eeAddDeviceMembershipChange value => _nextOperationHistory(
      previous: value.previous,
      operationId: value.pairingId,
    ),
    E2eeRevokeRotateMembershipChange value => _nextOperationHistory(
      previous: value.previous,
      operationId: value.operationId,
    ),
    E2eeRecoverResumeMembershipChange value => _nextOperationHistory(
      previous: value.previous,
      operationId: value.operationId,
      requireComplete: true,
    ),
    E2eeRecoverReplaceMembershipChange value => _nextOperationHistory(
      previous: value.previous,
      operationId: value.operationId,
      requireComplete: true,
    ),
  };
}

_OperationHistory _operationHistoryForExpectation(
  E2eeAccountTrustManifestExpectation expectation,
  String operationId,
) {
  return switch (expectation) {
    E2eeInitializeMembershipExpectation() => _initialOperationHistory(
      operationId,
    ),
    E2eeAddDeviceMembershipExpectation value => _nextOperationHistory(
      previous: value.previous,
      operationId: operationId,
    ),
    E2eeRevokeRotateMembershipExpectation value => _nextOperationHistory(
      previous: value.previous,
      operationId: operationId,
    ),
    E2eePairingBootstrapMembershipExpectation() => (
      ids: <String>{operationId},
      isComplete: false,
    ),
    E2eeRecoverResumeMembershipExpectation value => _nextOperationHistory(
      previous: value.previous,
      operationId: operationId,
      requireComplete: true,
    ),
    E2eeRecoverReplaceMembershipExpectation value => _nextOperationHistory(
      previous: value.previous,
      operationId: operationId,
      requireComplete: true,
    ),
  };
}

_OperationHistory _initialOperationHistory(String operationId) {
  return (ids: <String>{operationId}, isComplete: true);
}

_OperationHistory _nextOperationHistory({
  required E2eeVerifiedMembership previous,
  required String operationId,
  bool requireComplete = false,
}) {
  if (requireComplete && !previous._hasCompleteOperationHistory) {
    throw StateError('恢复操作必须基于从 genesis 完整验证的成员历史');
  }
  if (previous._operationIds.contains(operationId)) {
    throw StateError('成员清单 operationId 在完整历史中重复');
  }
  if (previous._operationIds.length >=
      e2eeAccountTrustManifestMaximumHistoryEntries) {
    throw StateError('成员清单完整历史已达到 4096 份上限');
  }
  return (
    ids: <String>{...previous._operationIds, operationId},
    isComplete: previous._hasCompleteOperationHistory,
  );
}

bool _isRecoveryOperation(E2eeMembershipOperationKind operationKind) {
  return operationKind == E2eeMembershipOperationKind.recoverResume ||
      operationKind == E2eeMembershipOperationKind.recoverReplace;
}

(Uint8List, int) _changeSigningContext(E2eeAccountTrustManifestChange change) {
  return switch (change) {
    E2eeInitializeMembershipChange value => (_uuidBytes(value.userId), 1),
    E2eeAddDeviceMembershipChange value => (
      value.previous._data.userIdBytes,
      value.previous.keyEpoch,
    ),
    E2eeRevokeRotateMembershipChange value => (
      value.previous._data.userIdBytes,
      _nextKeyEpoch(value.previous),
    ),
    E2eeRecoverResumeMembershipChange value => (
      value.previous._data.userIdBytes,
      value.previous.keyEpoch,
    ),
    E2eeRecoverReplaceMembershipChange value => (
      value.previous._data.userIdBytes,
      _nextKeyEpoch(value.previous),
    ),
  };
}

int _nextKeyEpoch(E2eeVerifiedMembership previous) {
  if (previous.keyEpoch == _maximumUint32) {
    throw StateError('ARK keyEpoch 已经耗尽');
  }
  return previous.keyEpoch + 1;
}

_ManifestData _buildInitialize(
  E2eeInitializeMembershipChange change,
  Uint8List currentAccountTrustPublicKey,
) {
  if (change.member.authGeneration != 0) {
    throw ArgumentError('首个成员的 authGeneration 必须为 0');
  }
  if (change.recoveryPublicKeyVersion != 1 ||
      change.recoveryCapsuleVersion != 1) {
    throw ArgumentError('初始化恢复公钥和 capsule 版本必须从 1 开始');
  }
  return _ManifestData(
    userId: change.userId,
    userIdBytes: _uuidBytes(change.userId),
    securityGeneration: 1,
    keyEpoch: 1,
    previousDigest: _zeroDigest,
    currentAccountTrustPublicKey: currentAccountTrustPublicKey,
    recoveryPublicKeyVersion: change.recoveryPublicKeyVersion,
    recoveryPublicKey: change.recoveryPublicKey,
    recoveryCapsuleVersion: change.recoveryCapsuleVersion,
    recoveryCapsuleDigest: _sha256(change.recoveryCapsule),
    operationKind: E2eeMembershipOperationKind.initialize,
    operationId: change.operationId,
    operationIdBytes: _uuidBytes(change.operationId),
    issuerDeviceId: change.member.deviceId,
    issuerDeviceIdBytes: change.member._deviceIdBytes,
    subjectDeviceId: change.member.deviceId,
    subjectDeviceIdBytes: change.member._deviceIdBytes,
    members: <_MembershipMember>[_memberFromInput(change.member)],
  );
}

_ManifestData _buildAddDevice(
  E2eeAddDeviceMembershipChange change,
  Uint8List currentAccountTrustPublicKey,
) {
  final previous = change.previous._data;
  if (previous.securityGeneration == _maximumSecurityGeneration) {
    throw StateError('成员清单安全代次已经耗尽');
  }
  if (previous.members.length == e2eeAccountTrustManifestMaximumMembers) {
    throw StateError('成员清单已达到 256 个设备上限');
  }
  if (_findMember(previous, change.issuerDeviceId) == null) {
    throw ArgumentError('批准设备不在上一版成员清单中');
  }
  if (_findMember(previous, change.subject.deviceId) != null) {
    throw ArgumentError('新增设备已经存在于上一版成员清单中');
  }
  if (change.subject.authGeneration == 0) {
    throw ArgumentError('新增设备必须使用激活后的 authGeneration');
  }
  if (!_sameBytes(
    currentAccountTrustPublicKey,
    previous.currentAccountTrustPublicKey,
  )) {
    throw ArgumentError('同一 ARK epoch 的账户信任公钥不得变化');
  }
  final members = <_MembershipMember>[
    ...previous.members,
    _memberFromInput(change.subject),
  ]..sort(_compareMembers);
  _validateCanonicalMembers(members);
  return _ManifestData(
    userId: previous.userId,
    userIdBytes: previous.userIdBytes,
    securityGeneration: previous.securityGeneration + 1,
    keyEpoch: previous.keyEpoch,
    previousDigest: change.previous.digest,
    currentAccountTrustPublicKey: currentAccountTrustPublicKey,
    recoveryPublicKeyVersion: previous.recoveryPublicKeyVersion,
    recoveryPublicKey: previous.recoveryPublicKey,
    recoveryCapsuleVersion: previous.recoveryCapsuleVersion,
    recoveryCapsuleDigest: previous.recoveryCapsuleDigest,
    operationKind: E2eeMembershipOperationKind.addDevice,
    operationId: change.pairingId,
    operationIdBytes: _uuidBytes(change.pairingId),
    issuerDeviceId: change.issuerDeviceId,
    issuerDeviceIdBytes: _uuidBytes(change.issuerDeviceId),
    subjectDeviceId: change.subject.deviceId,
    subjectDeviceIdBytes: change.subject._deviceIdBytes,
    members: members,
  );
}

_ManifestData _buildRevokeRotate(
  E2eeRevokeRotateMembershipChange change,
  Uint8List currentAccountTrustPublicKey,
) {
  final previous = change.previous._data;
  if (previous.securityGeneration == _maximumSecurityGeneration) {
    throw StateError('成员清单安全代次已经耗尽');
  }
  if (previous.keyEpoch == _maximumUint32) {
    throw StateError('ARK keyEpoch 已经耗尽');
  }
  if (previous.recoveryCapsuleVersion == _maximumUint32) {
    throw StateError('恢复 capsule 版本已经耗尽');
  }
  if (_findMember(previous, change.issuerDeviceId) == null) {
    throw ArgumentError('撤销发起设备不在上一版成员清单中');
  }
  if (_findMember(previous, change.revokedDeviceId) == null) {
    throw ArgumentError('被撤销设备不在上一版成员清单中');
  }
  if (change.issuerDeviceId == change.revokedDeviceId) {
    throw ArgumentError('撤销发起设备不能撤销自身');
  }
  if (_sameBytes(
    currentAccountTrustPublicKey,
    previous.currentAccountTrustPublicKey,
  )) {
    throw ArgumentError('ARK 轮换必须产生新的账户信任公钥');
  }
  if (change.nextRecoveryCapsuleVersion !=
      previous.recoveryCapsuleVersion + 1) {
    throw ArgumentError('恢复 capsule 版本必须精确增加 1');
  }
  final capsuleDigest = _sha256(change.nextRecoveryCapsule);
  if (_sameBytes(capsuleDigest, previous.recoveryCapsuleDigest)) {
    throw ArgumentError('ARK 轮换必须产生新的恢复 capsule');
  }
  final members = <_MembershipMember>[
    for (final member in previous.members)
      if (member.deviceId != change.revokedDeviceId) member,
  ];
  return _ManifestData(
    userId: previous.userId,
    userIdBytes: previous.userIdBytes,
    securityGeneration: previous.securityGeneration + 1,
    keyEpoch: previous.keyEpoch + 1,
    previousDigest: change.previous.digest,
    currentAccountTrustPublicKey: currentAccountTrustPublicKey,
    recoveryPublicKeyVersion: previous.recoveryPublicKeyVersion,
    recoveryPublicKey: previous.recoveryPublicKey,
    recoveryCapsuleVersion: change.nextRecoveryCapsuleVersion,
    recoveryCapsuleDigest: capsuleDigest,
    operationKind: E2eeMembershipOperationKind.revokeRotate,
    operationId: change.operationId,
    operationIdBytes: _uuidBytes(change.operationId),
    issuerDeviceId: change.issuerDeviceId,
    issuerDeviceIdBytes: _uuidBytes(change.issuerDeviceId),
    subjectDeviceId: change.revokedDeviceId,
    subjectDeviceIdBytes: _uuidBytes(change.revokedDeviceId),
    members: members,
  );
}

_ManifestData _buildRecoverResume(
  E2eeRecoverResumeMembershipChange change,
  Uint8List currentAccountTrustPublicKey,
) {
  final previous = change.previous._data;
  if (previous.securityGeneration == _maximumSecurityGeneration) {
    throw StateError('成员清单安全代次已经耗尽');
  }
  if (previous.members.length == e2eeAccountTrustManifestMaximumMembers) {
    throw StateError('成员清单已达到 256 个设备上限');
  }
  if (_findMember(previous, change.subject.deviceId) != null) {
    throw ArgumentError('恢复接续设备已经存在于上一版成员清单中');
  }
  if (change.subject.authGeneration == 0) {
    throw ArgumentError('恢复接续设备必须使用激活后的 authGeneration');
  }
  if (!_sameBytes(
    currentAccountTrustPublicKey,
    previous.currentAccountTrustPublicKey,
  )) {
    throw ArgumentError('恢复接续不得改变当前 ARK 账户信任公钥');
  }
  final members = <_MembershipMember>[
    ...previous.members,
    _memberFromInput(change.subject),
  ]..sort(_compareMembers);
  _validateCanonicalMembers(members);
  return _ManifestData(
    userId: previous.userId,
    userIdBytes: previous.userIdBytes,
    securityGeneration: previous.securityGeneration + 1,
    keyEpoch: previous.keyEpoch,
    previousDigest: change.previous.digest,
    currentAccountTrustPublicKey: currentAccountTrustPublicKey,
    recoveryPublicKeyVersion: previous.recoveryPublicKeyVersion,
    recoveryPublicKey: previous.recoveryPublicKey,
    recoveryCapsuleVersion: previous.recoveryCapsuleVersion,
    recoveryCapsuleDigest: previous.recoveryCapsuleDigest,
    operationKind: E2eeMembershipOperationKind.recoverResume,
    operationId: change.operationId,
    operationIdBytes: _uuidBytes(change.operationId),
    issuerDeviceId: change.subject.deviceId,
    issuerDeviceIdBytes: change.subject._deviceIdBytes,
    subjectDeviceId: change.subject.deviceId,
    subjectDeviceIdBytes: change.subject._deviceIdBytes,
    members: members,
  );
}

_ManifestData _buildRecoverReplace(
  E2eeRecoverReplaceMembershipChange change,
  Uint8List currentAccountTrustPublicKey,
) {
  final previous = change.previous._data;
  if (previous.securityGeneration == _maximumSecurityGeneration) {
    throw StateError('成员清单安全代次已经耗尽');
  }
  if (previous.keyEpoch == _maximumUint32) {
    throw StateError('ARK keyEpoch 已经耗尽');
  }
  if (previous.recoveryCapsuleVersion == _maximumUint32) {
    throw StateError('恢复 capsule 版本已经耗尽');
  }
  if (change.subject.authGeneration == 0) {
    throw ArgumentError('恢复替换设备必须使用激活后的 authGeneration');
  }
  if (_sameBytes(
    currentAccountTrustPublicKey,
    previous.currentAccountTrustPublicKey,
  )) {
    throw ArgumentError('恢复替换必须产生新的账户信任公钥');
  }
  if (change.nextRecoveryCapsuleVersion !=
      previous.recoveryCapsuleVersion + 1) {
    throw ArgumentError('恢复 capsule 版本必须精确增加 1');
  }
  final capsuleDigest = _sha256(change.nextRecoveryCapsule);
  if (_sameBytes(capsuleDigest, previous.recoveryCapsuleDigest)) {
    throw ArgumentError('恢复替换必须产生新的恢复 capsule');
  }
  final member = _memberFromInput(change.subject);
  _validateRecoverReplaceMember(previous, member);
  return _ManifestData(
    userId: previous.userId,
    userIdBytes: previous.userIdBytes,
    securityGeneration: previous.securityGeneration + 1,
    keyEpoch: previous.keyEpoch + 1,
    previousDigest: change.previous.digest,
    currentAccountTrustPublicKey: currentAccountTrustPublicKey,
    recoveryPublicKeyVersion: previous.recoveryPublicKeyVersion,
    recoveryPublicKey: previous.recoveryPublicKey,
    recoveryCapsuleVersion: change.nextRecoveryCapsuleVersion,
    recoveryCapsuleDigest: capsuleDigest,
    operationKind: E2eeMembershipOperationKind.recoverReplace,
    operationId: change.operationId,
    operationIdBytes: _uuidBytes(change.operationId),
    issuerDeviceId: change.subject.deviceId,
    issuerDeviceIdBytes: change.subject._deviceIdBytes,
    subjectDeviceId: change.subject.deviceId,
    subjectDeviceIdBytes: change.subject._deviceIdBytes,
    members: <_MembershipMember>[member],
  );
}

void _validateExpectation(
  _ManifestData data,
  E2eeAccountTrustManifestExpectation expectation,
) {
  switch (expectation) {
    case E2eeInitializeMembershipExpectation value:
      _validateInitializeExpectation(data, value);
    case E2eeAddDeviceMembershipExpectation value:
      _validateAddExpectation(data, value);
    case E2eeRevokeRotateMembershipExpectation value:
      _validateRevokeExpectation(data, value);
    case E2eeRecoverResumeMembershipExpectation value:
      _validateRecoverResumeExpectation(data, value);
    case E2eeRecoverReplaceMembershipExpectation value:
      _validateRecoverReplaceExpectation(data, value);
    case E2eePairingBootstrapMembershipExpectation value:
      _validateBootstrapExpectation(data, value);
  }
}

void _validateInitializeExpectation(
  _ManifestData data,
  E2eeInitializeMembershipExpectation expectation,
) {
  if (data.operationKind != E2eeMembershipOperationKind.initialize ||
      data.securityGeneration != 1 ||
      data.keyEpoch != 1 ||
      !_allZero(data.previousDigest) ||
      data.operationId != expectation.operationId ||
      data.issuerDeviceId != data.subjectDeviceId ||
      data.members.length != 1 ||
      data.members.single.deviceId != data.subjectDeviceId ||
      data.members.single.authGeneration != 0 ||
      data.recoveryPublicKeyVersion != 1 ||
      data.recoveryCapsuleVersion != 1 ||
      !_memberMatches(data.members.single, expectation.member) ||
      expectation.projection.lastOperationId != expectation.operationId ||
      expectation.projection.dataRekeyPhase != E2eeDataRekeyPhase.ready) {
    throw StateError('初始化成员清单不符合本地预期');
  }
}

void _validateAddExpectation(
  _ManifestData data,
  E2eeAddDeviceMembershipExpectation expectation,
) {
  final previous = expectation.previous._data;
  _validatePreviousAnchor(data, expectation.previous);
  if (data.operationKind != E2eeMembershipOperationKind.addDevice ||
      data.keyEpoch != previous.keyEpoch ||
      !_sameBytes(
        data.currentAccountTrustPublicKey,
        previous.currentAccountTrustPublicKey,
      ) ||
      data.operationId != expectation.pairingId ||
      data.issuerDeviceId != expectation.issuerDeviceId ||
      data.subjectDeviceId != expectation.subject.deviceId ||
      expectation.projection.lastOperationId != expectation.pairingId ||
      !_sameRecoveryState(data, previous) ||
      _findMember(previous, expectation.issuerDeviceId) == null ||
      _findMember(previous, expectation.subject.deviceId) != null ||
      data.members.length != previous.members.length + 1) {
    throw StateError('新增设备成员清单不符合本地预期');
  }
  if (expectation.projection.dataRekeyPhase != E2eeDataRekeyPhase.ready) {
    throw StateError('新增设备时数据换钥状态必须为 ready');
  }
  final subject = _findMember(data, expectation.subject.deviceId);
  if (subject == null ||
      subject.authGeneration == 0 ||
      !_memberMatches(subject, expectation.subject)) {
    throw StateError('新增设备成员信息与配对预期不一致');
  }
  _requireUnchangedMembers(
    previous: previous,
    current: data,
    omittedDeviceId: null,
  );
}

void _validateRevokeExpectation(
  _ManifestData data,
  E2eeRevokeRotateMembershipExpectation expectation,
) {
  final previous = expectation.previous._data;
  _validatePreviousAnchor(data, expectation.previous);
  if (data.operationKind != E2eeMembershipOperationKind.revokeRotate ||
      previous.keyEpoch == _maximumUint32 ||
      data.keyEpoch != previous.keyEpoch + 1 ||
      _sameBytes(
        data.currentAccountTrustPublicKey,
        previous.currentAccountTrustPublicKey,
      ) ||
      data.operationId != expectation.operationId ||
      data.issuerDeviceId != expectation.issuerDeviceId ||
      data.subjectDeviceId != expectation.revokedDeviceId ||
      data.issuerDeviceId == data.subjectDeviceId ||
      expectation.projection.lastOperationId != expectation.operationId ||
      _findMember(previous, expectation.issuerDeviceId) == null ||
      _findMember(previous, expectation.revokedDeviceId) == null ||
      _findMember(data, expectation.issuerDeviceId) == null ||
      _findMember(data, expectation.revokedDeviceId) != null ||
      data.members.length != previous.members.length - 1 ||
      data.recoveryPublicKeyVersion != previous.recoveryPublicKeyVersion ||
      !_sameBytes(data.recoveryPublicKey, previous.recoveryPublicKey) ||
      previous.recoveryCapsuleVersion == _maximumUint32 ||
      data.recoveryCapsuleVersion != previous.recoveryCapsuleVersion + 1 ||
      _sameBytes(data.recoveryCapsuleDigest, previous.recoveryCapsuleDigest)) {
    throw StateError('撤销轮换成员清单不符合本地预期');
  }
  if (expectation.projection.dataRekeyPhase !=
      E2eeDataRekeyPhase.rekeyPending) {
    throw StateError('撤销轮换提交后数据换钥状态必须为 rekey-pending');
  }
  _requireUnchangedMembers(
    previous: previous,
    current: data,
    omittedDeviceId: expectation.revokedDeviceId,
  );
}

void _validateRecoverResumeExpectation(
  _ManifestData data,
  E2eeRecoverResumeMembershipExpectation expectation,
) {
  final previous = expectation.previous._data;
  _validatePreviousAnchor(data, expectation.previous);
  if (data.operationKind != E2eeMembershipOperationKind.recoverResume ||
      data.keyEpoch != previous.keyEpoch ||
      !_sameBytes(
        data.currentAccountTrustPublicKey,
        previous.currentAccountTrustPublicKey,
      ) ||
      !_sameRecoveryState(data, previous) ||
      data.operationId != expectation.operationId ||
      data.issuerDeviceId != expectation.subject.deviceId ||
      data.subjectDeviceId != expectation.subject.deviceId ||
      _findMember(previous, expectation.subject.deviceId) != null ||
      data.members.length != previous.members.length + 1 ||
      expectation.projection.lastOperationId != expectation.operationId ||
      expectation.projection.dataRekeyPhase != E2eeDataRekeyPhase.ready) {
    throw StateError('恢复接续成员清单不符合本地预期');
  }
  final subject = _findMember(data, expectation.subject.deviceId);
  if (subject == null ||
      subject.authGeneration == 0 ||
      !_memberMatches(subject, expectation.subject)) {
    throw StateError('恢复接续设备成员信息与本地预期不一致');
  }
  _requireUnchangedMembers(
    previous: previous,
    current: data,
    omittedDeviceId: null,
  );
}

void _validateRecoverReplaceExpectation(
  _ManifestData data,
  E2eeRecoverReplaceMembershipExpectation expectation,
) {
  final previous = expectation.previous._data;
  _validatePreviousAnchor(data, expectation.previous);
  if (data.operationKind != E2eeMembershipOperationKind.recoverReplace ||
      previous.keyEpoch == _maximumUint32 ||
      data.keyEpoch != previous.keyEpoch + 1 ||
      _sameBytes(
        data.currentAccountTrustPublicKey,
        previous.currentAccountTrustPublicKey,
      ) ||
      data.recoveryPublicKeyVersion != previous.recoveryPublicKeyVersion ||
      !_sameBytes(data.recoveryPublicKey, previous.recoveryPublicKey) ||
      previous.recoveryCapsuleVersion == _maximumUint32 ||
      data.recoveryCapsuleVersion != previous.recoveryCapsuleVersion + 1 ||
      _sameBytes(data.recoveryCapsuleDigest, previous.recoveryCapsuleDigest) ||
      data.operationId != expectation.operationId ||
      data.issuerDeviceId != expectation.subject.deviceId ||
      data.subjectDeviceId != expectation.subject.deviceId ||
      data.members.length != 1 ||
      expectation.projection.lastOperationId != expectation.operationId ||
      expectation.projection.dataRekeyPhase !=
          E2eeDataRekeyPhase.rekeyPending) {
    throw StateError('恢复替换成员清单不符合本地预期');
  }
  final subject = data.members.single;
  if (subject.authGeneration == 0 ||
      !_memberMatches(subject, expectation.subject)) {
    throw StateError('恢复替换设备成员信息与本地预期不一致');
  }
  _validateRecoverReplaceMember(previous, subject, stateError: true);
}

void _validateBootstrapExpectation(
  _ManifestData data,
  E2eePairingBootstrapMembershipExpectation expectation,
) {
  final localMember = _findMember(data, expectation.localMember.deviceId);
  if (expectation.projection.keyEpoch != expectation.consumedKeyEpoch ||
      expectation.projection.securityGeneration !=
          expectation.consumedSecurityGeneration ||
      !_sameBytes(
        expectation.projection.membershipManifestDigest,
        expectation.consumedMembershipManifestDigest,
      ) ||
      data.operationKind != E2eeMembershipOperationKind.addDevice ||
      data.securityGeneration < 2 ||
      _allZero(data.previousDigest) ||
      data.operationId != expectation.pairingId ||
      data.issuerDeviceId != expectation.issuerDeviceId ||
      data.subjectDeviceId != expectation.localMember.deviceId ||
      data.issuerDeviceId == data.subjectDeviceId ||
      expectation.projection.lastOperationId != expectation.pairingId ||
      _findMember(data, expectation.issuerDeviceId) == null ||
      localMember == null ||
      localMember.authGeneration == 0 ||
      expectation.projection.dataRekeyPhase != E2eeDataRekeyPhase.ready ||
      !_memberMatches(localMember, expectation.localMember)) {
    throw StateError('配对引导成员清单与本机绑定不一致');
  }
}

void _validatePreviousAnchor(
  _ManifestData current,
  E2eeVerifiedMembership previous,
) {
  final previousData = previous._data;
  if (previousData.securityGeneration == _maximumSecurityGeneration ||
      current.userId != previousData.userId ||
      current.securityGeneration != previousData.securityGeneration + 1 ||
      !_sameBytes(current.previousDigest, previous.digest)) {
    throw StateError('成员清单发生回滚、跳代或分叉');
  }
}

void _validateHistorySuccessor(
  _ManifestData current,
  E2eeVerifiedMembership previous,
) {
  final previousData = previous._data;
  _validatePreviousAnchor(current, previous);
  switch (current.operationKind) {
    case E2eeMembershipOperationKind.initialize:
      throw StateError('genesis 之后不能再次初始化成员清单');
    case E2eeMembershipOperationKind.addDevice:
      if (current.keyEpoch != previousData.keyEpoch ||
          !_sameBytes(
            current.currentAccountTrustPublicKey,
            previousData.currentAccountTrustPublicKey,
          ) ||
          !_sameRecoveryState(current, previousData) ||
          current.issuerDeviceId == current.subjectDeviceId ||
          _findMember(previousData, current.issuerDeviceId) == null ||
          _findMember(previousData, current.subjectDeviceId) != null ||
          current.members.length != previousData.members.length + 1) {
        throw StateError('历史新增设备成员清单转换无效');
      }
      final subject = _findMember(current, current.subjectDeviceId);
      if (subject == null || subject.authGeneration == 0) {
        throw StateError('历史新增设备成员必须使用激活后的认证代次');
      }
      _requireUnchangedMembers(
        previous: previousData,
        current: current,
        omittedDeviceId: null,
      );
    case E2eeMembershipOperationKind.revokeRotate:
      if (previousData.keyEpoch == _maximumUint32 ||
          current.keyEpoch != previousData.keyEpoch + 1 ||
          _sameBytes(
            current.currentAccountTrustPublicKey,
            previousData.currentAccountTrustPublicKey,
          ) ||
          current.issuerDeviceId == current.subjectDeviceId ||
          _findMember(previousData, current.issuerDeviceId) == null ||
          _findMember(previousData, current.subjectDeviceId) == null ||
          _findMember(current, current.issuerDeviceId) == null ||
          _findMember(current, current.subjectDeviceId) != null ||
          current.members.length != previousData.members.length - 1 ||
          current.recoveryPublicKeyVersion !=
              previousData.recoveryPublicKeyVersion ||
          !_sameBytes(
            current.recoveryPublicKey,
            previousData.recoveryPublicKey,
          ) ||
          previousData.recoveryCapsuleVersion == _maximumUint32 ||
          current.recoveryCapsuleVersion !=
              previousData.recoveryCapsuleVersion + 1 ||
          _sameBytes(
            current.recoveryCapsuleDigest,
            previousData.recoveryCapsuleDigest,
          )) {
        throw StateError('历史撤销轮换成员清单转换无效');
      }
      _requireUnchangedMembers(
        previous: previousData,
        current: current,
        omittedDeviceId: current.subjectDeviceId,
      );
    case E2eeMembershipOperationKind.recoverResume:
      if (current.keyEpoch != previousData.keyEpoch ||
          !_sameBytes(
            current.currentAccountTrustPublicKey,
            previousData.currentAccountTrustPublicKey,
          ) ||
          !_sameRecoveryState(current, previousData) ||
          current.issuerDeviceId != current.subjectDeviceId ||
          _findMember(previousData, current.subjectDeviceId) != null ||
          current.members.length != previousData.members.length + 1) {
        throw StateError('历史恢复接续成员清单转换无效');
      }
      final resumedSubject = _findMember(current, current.subjectDeviceId);
      if (resumedSubject == null || resumedSubject.authGeneration == 0) {
        throw StateError('历史恢复接续设备必须使用激活后的认证代次');
      }
      _requireUnchangedMembers(
        previous: previousData,
        current: current,
        omittedDeviceId: null,
      );
    case E2eeMembershipOperationKind.recoverReplace:
      if (previousData.keyEpoch == _maximumUint32 ||
          current.keyEpoch != previousData.keyEpoch + 1 ||
          _sameBytes(
            current.currentAccountTrustPublicKey,
            previousData.currentAccountTrustPublicKey,
          ) ||
          current.recoveryPublicKeyVersion !=
              previousData.recoveryPublicKeyVersion ||
          !_sameBytes(
            current.recoveryPublicKey,
            previousData.recoveryPublicKey,
          ) ||
          previousData.recoveryCapsuleVersion == _maximumUint32 ||
          current.recoveryCapsuleVersion !=
              previousData.recoveryCapsuleVersion + 1 ||
          _sameBytes(
            current.recoveryCapsuleDigest,
            previousData.recoveryCapsuleDigest,
          ) ||
          current.issuerDeviceId != current.subjectDeviceId ||
          current.members.length != 1 ||
          current.members.single.deviceId != current.subjectDeviceId ||
          current.members.single.authGeneration == 0) {
        throw StateError('历史恢复替换成员清单转换无效');
      }
      _validateRecoverReplaceMember(
        previousData,
        current.members.single,
        stateError: true,
      );
  }
}

void _requireUnchangedMembers({
  required _ManifestData previous,
  required _ManifestData current,
  required String? omittedDeviceId,
}) {
  for (final oldMember in previous.members) {
    if (oldMember.deviceId == omittedDeviceId) continue;
    final currentMember = _findMember(current, oldMember.deviceId);
    if (currentMember == null || !_sameMember(oldMember, currentMember)) {
      throw StateError('已有成员在状态转换中被替换');
    }
  }
}

void _validateProjection(
  _ManifestData data,
  E2eeMembershipServerProjection projection,
) {
  final capsuleDigest = _sha256(projection.recoveryCapsule);
  if (projection.membershipManifestVersion !=
          e2eeAccountTrustManifestFormatVersion ||
      projection.userId != data.userId ||
      projection.securityGeneration != data.securityGeneration ||
      projection.keyEpoch != data.keyEpoch ||
      projection.recoveryPublicKeyVersion != data.recoveryPublicKeyVersion ||
      !_sameBytes(projection.recoveryPublicKey, data.recoveryPublicKey) ||
      projection.recoveryCapsuleVersion != data.recoveryCapsuleVersion ||
      !_sameBytes(capsuleDigest, data.recoveryCapsuleDigest)) {
    throw StateError('成员清单与服务端安全状态投影不一致');
  }
}

void _validateProjectionOperation(_ManifestData data, String lastOperationId) {
  if (lastOperationId != data.operationId) {
    throw StateError('服务端最后操作与已验证成员清单不一致');
  }
}

void _requireZeroTransitionSignature(Uint8List signature) {
  if (!_allZero(signature)) {
    throw StateError('非轮换成员清单不得携带 epoch 过渡签名');
  }
}

void _requireNonZeroTransitionSignature(Uint8List signature) {
  if (_allZero(signature)) {
    throw StateError('ARK 轮换成员清单缺少旧 epoch 过渡签名');
  }
}

_ParsedManifest _parseManifest(Uint8List manifest) {
  if (manifest.length < e2eeAccountTrustManifestMinimumLength) {
    throw const FormatException('成员清单长度不足');
  }
  if (!_sameBytes(Uint8List.sublistView(manifest, 0, 8), _manifestMagic)) {
    throw const FormatException('成员清单魔数无效');
  }
  final fields = ByteData.sublistView(manifest);
  if (fields.getUint32(8, Endian.big) !=
      e2eeAccountTrustManifestFormatVersion) {
    throw const FormatException('成员清单格式版本无效');
  }
  final memberCount = fields.getUint32(224, Endian.big);
  if (memberCount == 0 ||
      memberCount > e2eeAccountTrustManifestMaximumMembers) {
    throw const FormatException('成员数量必须为 1 至 256');
  }
  final payloadLength =
      _manifestHeaderLength + memberCount * _manifestMemberLength;
  if (manifest.length != payloadLength + _manifestSignatureSectionLength) {
    throw const FormatException('成员清单长度与成员数量不一致');
  }
  final securityGeneration = fields.getUint32(28, Endian.big);
  if (securityGeneration == 0 ||
      securityGeneration > _maximumSecurityGeneration) {
    throw const FormatException('成员清单安全代次无效');
  }
  final keyEpoch = fields.getUint32(32, Endian.big);
  final recoveryPublicKeyVersion = fields.getUint32(100, Endian.big);
  final recoveryCapsuleVersion = fields.getUint32(136, Endian.big);
  if (keyEpoch == 0 ||
      recoveryPublicKeyVersion == 0 ||
      recoveryCapsuleVersion == 0) {
    throw const FormatException('成员清单正整数版本字段无效');
  }
  final operationKind = switch (fields.getUint32(172, Endian.big)) {
    1 => E2eeMembershipOperationKind.initialize,
    2 => E2eeMembershipOperationKind.addDevice,
    3 => E2eeMembershipOperationKind.revokeRotate,
    4 => E2eeMembershipOperationKind.recoverResume,
    5 => E2eeMembershipOperationKind.recoverReplace,
    _ => throw const FormatException('成员清单操作类型无效'),
  };
  final userIdBytes = _readUuid(manifest, 12, 'userId');
  final operationIdBytes = _readUuid(manifest, 176, 'operationId');
  final issuerDeviceIdBytes = _readUuid(manifest, 192, 'issuerDeviceId');
  final subjectDeviceIdBytes = _readUuid(manifest, 208, 'subjectDeviceId');
  final members = <_MembershipMember>[];
  var offset = _manifestHeaderLength;
  for (var index = 0; index < memberCount; index++) {
    final deviceIdBytes = _readUuid(manifest, offset, 'member.deviceId');
    final keyVersion = fields.getUint32(offset + 16, Endian.big);
    final authGeneration = fields.getUint32(offset + 20, Endian.big);
    if (keyVersion == 0 || keyVersion > _maximumDeviceCounter) {
      throw const FormatException('成员密钥版本必须为正 31 位整数');
    }
    if (authGeneration > _maximumDeviceCounter) {
      throw const FormatException('成员认证代次必须为非负 31 位整数');
    }
    members.add(
      _MembershipMember(
        deviceId: Uuid.unparse(deviceIdBytes),
        deviceIdBytes: deviceIdBytes,
        keyVersion: keyVersion,
        authGeneration: authGeneration,
        signingPublicKey: Uint8List.sublistView(
          manifest,
          offset + 24,
          offset + 56,
        ),
        keyAgreementPublicKey: Uint8List.sublistView(
          manifest,
          offset + 56,
          offset + 88,
        ),
      ),
    );
    offset += _manifestMemberLength;
  }
  _validateCanonicalMembers(members, untrusted: true);
  final recoveryPublicKey = Uint8List.sublistView(manifest, 104, 136);
  _validateRecoveryKeySeparation(recoveryPublicKey, members, untrusted: true);
  final data = _ManifestData(
    userId: Uuid.unparse(userIdBytes),
    userIdBytes: userIdBytes,
    securityGeneration: securityGeneration,
    keyEpoch: keyEpoch,
    previousDigest: Uint8List.sublistView(manifest, 36, 68),
    currentAccountTrustPublicKey: Uint8List.sublistView(manifest, 68, 100),
    recoveryPublicKeyVersion: recoveryPublicKeyVersion,
    recoveryPublicKey: recoveryPublicKey,
    recoveryCapsuleVersion: recoveryCapsuleVersion,
    recoveryCapsuleDigest: Uint8List.sublistView(manifest, 140, 172),
    operationKind: operationKind,
    operationId: Uuid.unparse(operationIdBytes),
    operationIdBytes: operationIdBytes,
    issuerDeviceId: Uuid.unparse(issuerDeviceIdBytes),
    issuerDeviceIdBytes: issuerDeviceIdBytes,
    subjectDeviceId: Uuid.unparse(subjectDeviceIdBytes),
    subjectDeviceIdBytes: subjectDeviceIdBytes,
    members: members,
  );
  return _ParsedManifest(
    data,
    Uint8List.fromList(manifest.sublist(0, payloadLength)),
    Uint8List.fromList(
      manifest.sublist(payloadLength, payloadLength + _manifestSignatureLength),
    ),
    Uint8List.fromList(
      manifest.sublist(payloadLength + _manifestSignatureLength),
    ),
  );
}

Uint8List _encodePayload(_ManifestData data) {
  final payload = Uint8List(
    _manifestHeaderLength + data.members.length * _manifestMemberLength,
  );
  final fields = ByteData.sublistView(payload);
  payload.setRange(0, 8, _manifestMagic);
  fields.setUint32(8, e2eeAccountTrustManifestFormatVersion, Endian.big);
  payload.setRange(12, 28, data.userIdBytes);
  fields.setUint32(28, data.securityGeneration, Endian.big);
  fields.setUint32(32, data.keyEpoch, Endian.big);
  payload.setRange(36, 68, data.previousDigest);
  payload.setRange(68, 100, data.currentAccountTrustPublicKey);
  fields.setUint32(100, data.recoveryPublicKeyVersion, Endian.big);
  payload.setRange(104, 136, data.recoveryPublicKey);
  fields.setUint32(136, data.recoveryCapsuleVersion, Endian.big);
  payload.setRange(140, 172, data.recoveryCapsuleDigest);
  fields.setUint32(172, _operationCode(data.operationKind), Endian.big);
  payload.setRange(176, 192, data.operationIdBytes);
  payload.setRange(192, 208, data.issuerDeviceIdBytes);
  payload.setRange(208, 224, data.subjectDeviceIdBytes);
  fields.setUint32(224, data.members.length, Endian.big);
  var offset = _manifestHeaderLength;
  for (final member in data.members) {
    payload.setRange(offset, offset + 16, member.deviceIdBytes);
    fields.setUint32(offset + 16, member.keyVersion, Endian.big);
    fields.setUint32(offset + 20, member.authGeneration, Endian.big);
    payload.setRange(offset + 24, offset + 56, member.signingPublicKey);
    payload.setRange(offset + 56, offset + 88, member.keyAgreementPublicKey);
    offset += _manifestMemberLength;
  }
  return payload;
}

E2eeVerifiedMembership _verified(
  _ManifestData data,
  Uint8List manifest,
  _OperationHistory operationHistory,
) {
  return E2eeVerifiedMembership._(
    data: data,
    manifest: manifest,
    digest: _sha256(manifest),
    operationIds: operationHistory.ids,
    hasCompleteOperationHistory: operationHistory.isComplete,
  );
}

final class _ParsedManifest {
  const _ParsedManifest(
    this.data,
    this.payload,
    this.transitionSignature,
    this.currentSignature,
  );

  final _ManifestData data;
  final Uint8List payload;
  final Uint8List transitionSignature;
  final Uint8List currentSignature;
}

final class _ManifestData {
  _ManifestData({
    required this.userId,
    required Uint8List userIdBytes,
    required this.securityGeneration,
    required this.keyEpoch,
    required Uint8List previousDigest,
    required Uint8List currentAccountTrustPublicKey,
    required this.recoveryPublicKeyVersion,
    required Uint8List recoveryPublicKey,
    required this.recoveryCapsuleVersion,
    required Uint8List recoveryCapsuleDigest,
    required this.operationKind,
    required this.operationId,
    required Uint8List operationIdBytes,
    required this.issuerDeviceId,
    required Uint8List issuerDeviceIdBytes,
    required this.subjectDeviceId,
    required Uint8List subjectDeviceIdBytes,
    required List<_MembershipMember> members,
  }) : userIdBytes = _immutableBytes(userIdBytes),
       previousDigest = _immutableBytes(previousDigest),
       currentAccountTrustPublicKey = _immutableBytes(
         currentAccountTrustPublicKey,
       ),
       recoveryPublicKey = _immutableBytes(recoveryPublicKey),
       recoveryCapsuleDigest = _immutableBytes(recoveryCapsuleDigest),
       operationIdBytes = _immutableBytes(operationIdBytes),
       issuerDeviceIdBytes = _immutableBytes(issuerDeviceIdBytes),
       subjectDeviceIdBytes = _immutableBytes(subjectDeviceIdBytes),
       members = List<_MembershipMember>.unmodifiable(members);

  final String userId;
  final Uint8List userIdBytes;
  final int securityGeneration;
  final int keyEpoch;
  final Uint8List previousDigest;
  final Uint8List currentAccountTrustPublicKey;
  final int recoveryPublicKeyVersion;
  final Uint8List recoveryPublicKey;
  final int recoveryCapsuleVersion;
  final Uint8List recoveryCapsuleDigest;
  final E2eeMembershipOperationKind operationKind;
  final String operationId;
  final Uint8List operationIdBytes;
  final String issuerDeviceId;
  final Uint8List issuerDeviceIdBytes;
  final String subjectDeviceId;
  final Uint8List subjectDeviceIdBytes;
  final List<_MembershipMember> members;
}

final class _MembershipMember {
  _MembershipMember({
    required this.deviceId,
    required Uint8List deviceIdBytes,
    required this.keyVersion,
    required this.authGeneration,
    required Uint8List signingPublicKey,
    required Uint8List keyAgreementPublicKey,
  }) : deviceIdBytes = _immutableBytes(deviceIdBytes),
       signingPublicKey = _immutableBytes(signingPublicKey),
       keyAgreementPublicKey = _immutableBytes(keyAgreementPublicKey);

  final String deviceId;
  final Uint8List deviceIdBytes;
  final int keyVersion;
  final int authGeneration;
  final Uint8List signingPublicKey;
  final Uint8List keyAgreementPublicKey;
}

_MembershipMember _memberFromInput(E2eeMembershipDeviceInput input) {
  return _MembershipMember(
    deviceId: input.deviceId,
    deviceIdBytes: input._deviceIdBytes,
    keyVersion: input.keyVersion,
    authGeneration: input.authGeneration,
    signingPublicKey: input.signingPublicKey,
    keyAgreementPublicKey: input.keyAgreementPublicKey,
  );
}

void _validateCanonicalMembers(
  List<_MembershipMember> members, {
  bool untrusted = false,
}) {
  final signingKeys = <String>{};
  final agreementKeys = <String>{};
  for (var index = 0; index < members.length; index++) {
    final member = members[index];
    if (index > 0 &&
        _compareBytes(members[index - 1].deviceIdBytes, member.deviceIdBytes) >=
            0) {
      _memberValidationFailure('成员必须按 deviceId 严格升序排列', untrusted);
    }
    if (!signingKeys.add(base64Url.encode(member.signingPublicKey))) {
      _memberValidationFailure('成员 Ed25519 公钥不得重复', untrusted);
    }
    if (!agreementKeys.add(base64Url.encode(member.keyAgreementPublicKey))) {
      _memberValidationFailure('成员 X25519 公钥不得重复', untrusted);
    }
  }
}

void _validateRecoveryKeySeparation(
  Uint8List recoveryPublicKey,
  List<_MembershipMember> members, {
  bool untrusted = false,
}) {
  for (final member in members) {
    if (_sameBytes(recoveryPublicKey, member.keyAgreementPublicKey)) {
      _memberValidationFailure('恢复公钥不得复用成员 X25519 公钥', untrusted);
    }
  }
}

Never _memberValidationFailure(String message, bool untrusted) {
  if (untrusted) throw FormatException(message);
  throw ArgumentError(message);
}

_MembershipMember? _findMember(_ManifestData data, String deviceId) {
  for (final member in data.members) {
    if (member.deviceId == deviceId) return member;
  }
  return null;
}

bool _memberMatches(
  _MembershipMember member,
  E2eeMembershipDeviceInput expected,
) {
  return member.deviceId == expected.deviceId &&
      member.keyVersion == expected.keyVersion &&
      member.authGeneration == expected.authGeneration &&
      _sameBytes(member.signingPublicKey, expected.signingPublicKey) &&
      _sameBytes(member.keyAgreementPublicKey, expected.keyAgreementPublicKey);
}

bool _sameMember(_MembershipMember left, _MembershipMember right) {
  return left.deviceId == right.deviceId &&
      left.keyVersion == right.keyVersion &&
      left.authGeneration == right.authGeneration &&
      _sameBytes(left.signingPublicKey, right.signingPublicKey) &&
      _sameBytes(left.keyAgreementPublicKey, right.keyAgreementPublicKey);
}

void _validateRecoverReplaceMember(
  _ManifestData previous,
  _MembershipMember subject, {
  bool stateError = false,
}) {
  if (previous.operationKind == E2eeMembershipOperationKind.recoverResume) {
    final resumedSubject = _findMember(previous, previous.subjectDeviceId);
    if (resumedSubject == null || !_sameMember(resumedSubject, subject)) {
      _recoverReplaceFailure('恢复接续后的替换必须逐字段保留同一恢复设备', stateError);
    }
    return;
  }
  if (_findMember(previous, subject.deviceId) != null) {
    _recoverReplaceFailure('直达恢复替换设备不得已存在于成员清单', stateError);
  }
  for (final previousMember in previous.members) {
    if (_sameBytes(previousMember.signingPublicKey, subject.signingPublicKey) ||
        _sameBytes(
          previousMember.keyAgreementPublicKey,
          subject.keyAgreementPublicKey,
        )) {
      _recoverReplaceFailure('直达恢复替换设备不得复用旧成员公钥', stateError);
    }
  }
}

Never _recoverReplaceFailure(String message, bool stateError) {
  if (stateError) throw StateError(message);
  throw ArgumentError(message);
}

bool _sameRecoveryState(_ManifestData left, _ManifestData right) {
  return left.recoveryPublicKeyVersion == right.recoveryPublicKeyVersion &&
      _sameBytes(left.recoveryPublicKey, right.recoveryPublicKey) &&
      left.recoveryCapsuleVersion == right.recoveryCapsuleVersion &&
      _sameBytes(left.recoveryCapsuleDigest, right.recoveryCapsuleDigest);
}

int _compareMembers(_MembershipMember left, _MembershipMember right) {
  return _compareBytes(left.deviceIdBytes, right.deviceIdBytes);
}

int _compareBytes(Uint8List left, Uint8List right) {
  for (var index = 0; index < left.length; index++) {
    final difference = left[index] - right[index];
    if (difference != 0) return difference;
  }
  return left.length - right.length;
}

Uint8List _readUuid(Uint8List source, int offset, String field) {
  final bytes = Uint8List.fromList(source.sublist(offset, offset + 16));
  if (!_isUuidV4(bytes)) {
    throw FormatException('成员清单 $field 不是 RFC 4122 UUIDv4');
  }
  return bytes;
}

String _canonicalUuidV4(String value, String field) {
  late final Uint8List bytes;
  try {
    bytes = Uint8List.fromList(Uuid.parseAsByteList(value));
  } on FormatException {
    throw ArgumentError.value(value, field, '必须为规范小写 UUIDv4');
  }
  if (!_isUuidV4(bytes) || Uuid.unparse(bytes) != value) {
    throw ArgumentError.value(value, field, '必须为规范小写 UUIDv4');
  }
  return value;
}

Uint8List _uuidBytes(String value) {
  return Uint8List.fromList(Uuid.parseAsByteList(value)).asUnmodifiableView();
}

bool _isUuidV4(Uint8List bytes) {
  return bytes.length == 16 &&
      bytes[6] & 0xf0 == 0x40 &&
      bytes[8] & 0xc0 == 0x80;
}

void _requireSecurityGeneration(int value, String field) {
  if (value <= 0 || value > _maximumSecurityGeneration) {
    throw ArgumentError.value(value, field, '必须为正 31 位整数');
  }
}

void _requirePositiveUint32(int value, String field) {
  if (value <= 0 || value > _maximumUint32) {
    throw ArgumentError.value(value, field, '必须为正 uint32');
  }
}

void _requirePositiveDeviceCounter(int value, String field) {
  if (value <= 0 || value > _maximumDeviceCounter) {
    throw ArgumentError.value(value, field, '必须为正 31 位整数');
  }
}

void _requireDeviceAuthGeneration(int value, String field) {
  if (value < 0 || value > _maximumDeviceCounter) {
    throw ArgumentError.value(value, field, '必须为非负 31 位整数');
  }
}

Uint8List _copyFixed(Uint8List value, int length, String field) {
  if (value.length != length) {
    throw ArgumentError.value(value.length, field, '必须为 $length 字节');
  }
  return _immutableBytes(value);
}

Uint8List _copyRecoveryCapsule(Uint8List value) {
  if (value.isEmpty ||
      value.length > e2eeAccountTrustManifestMaximumRecoveryCapsuleLength) {
    throw ArgumentError.value(
      value.length,
      'recoveryCapsule',
      '必须为 1 至 '
          '$e2eeAccountTrustManifestMaximumRecoveryCapsuleLength 字节',
    );
  }
  return _immutableBytes(value);
}

Uint8List _immutableBytes(Uint8List value) {
  return Uint8List.fromList(value).asUnmodifiableView();
}

Uint8List _sha256(Uint8List value) {
  return Uint8List.fromList(sha256.convert(value).bytes).asUnmodifiableView();
}

bool _sameBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

bool _allZero(Uint8List value) {
  var aggregate = 0;
  for (final byte in value) {
    aggregate |= byte;
  }
  return aggregate == 0;
}

int _operationCode(E2eeMembershipOperationKind kind) {
  return switch (kind) {
    E2eeMembershipOperationKind.initialize => 1,
    E2eeMembershipOperationKind.addDevice => 2,
    E2eeMembershipOperationKind.revokeRotate => 3,
    E2eeMembershipOperationKind.recoverResume => 4,
    E2eeMembershipOperationKind.recoverReplace => 5,
  };
}
