import 'package:crypto/crypto.dart';

import 'cloud_sync_client.dart';
import 'cloud_sync_types.dart';
import 'e2ee_account_key_transition.dart';
import 'e2ee_device_state_key_transition.dart';
import 'e2ee_self_revocation_rotation_binding.dart';

final class E2eeCloudSyncDeviceRotationRemoteCommit
    implements E2eeAccountKeyTransitionRemoteCommit {
  factory E2eeCloudSyncDeviceRotationRemoteCommit({
    required CloudSyncDeviceRotationTransport rotationTransport,
    required CloudSyncDataRekeyStateTransport dataRekeyStateTransport,
    required E2eeDeviceStateKeyTransitionPlan plan,
    required CloudSyncDeviceRotationRequest request,
  }) {
    _requireRequestMatchesPlan(request, plan);
    return E2eeCloudSyncDeviceRotationRemoteCommit._(
      rotationTransport,
      dataRekeyStateTransport,
      plan,
      request,
    );
  }

  const E2eeCloudSyncDeviceRotationRemoteCommit._(
    this._rotationTransport,
    this._dataRekeyStateTransport,
    this._plan,
    this._request,
  );

  final CloudSyncDeviceRotationTransport _rotationTransport;
  final CloudSyncDataRekeyStateTransport _dataRekeyStateTransport;
  final E2eeDeviceStateKeyTransitionPlan _plan;
  final CloudSyncDeviceRotationRequest _request;

  @override
  Future<E2eeAccountKeyTransitionRemoteReceipt> commit() async {
    final result = await _rotationTransport.commitDeviceRotation(_request);
    _requireResultMatchesPlan(result, _plan, _request);
    return _receiptFromResult(result, _plan.binding);
  }

  @override
  Future<void> complete(E2eeAccountKeyTransitionRemoteReceipt receipt) async {
    _requireReceiptMatchesPlan(receipt, _plan.binding);
    // rotation commit 只开启换钥；ready 和签名完成证明才是远端真正收敛的确认。
    final state = await _dataRekeyStateTransport.getDataRekeyState();
    if (state is! CloudSyncDataRekeyReadyState) {
      throw const FormatException('设备轮换完成时远端仍处于 data-rekey pending');
    }
    final completion = state.lastCompletion;
    final binding = _plan.binding;
    if (completion == null ||
        state.dataGeneration != completion.targetDataGeneration ||
        state.dataKeyEpoch != binding.targetKeyEpoch ||
        completion.operationId != binding.rekeyOperationId ||
        completion.issuerDeviceId != binding.issuerDeviceId ||
        completion.targetKeyEpoch != binding.targetKeyEpoch ||
        completion.membershipGeneration != binding.securityGeneration ||
        !_sameBytes(
          completion.membershipManifestDigest,
          binding.membershipManifestDigest,
        )) {
      throw const FormatException('设备轮换 ready 状态未绑定账户换钥计划');
    }
  }
}

void _requireRequestMatchesPlan(
  CloudSyncDeviceRotationRequest request,
  E2eeDeviceStateKeyTransitionPlan plan,
) {
  final binding = plan.binding;
  final previous = plan.previousMembership;
  final next = plan.nextMembership;
  final expectedTargetIds = next.members
      .map((member) => member.deviceId)
      .toList(growable: false);
  final actualTargetIds = request.envelopes
      .map((envelope) => envelope.targetDeviceId)
      .toList(growable: false);
  final capsuleDigest = sha256.convert(request.nextRecoveryCapsule).bytes;
  if (binding.kind != E2eeAccountKeyTransitionKind.deviceRevocation ||
      request.expectedGeneration != previous.securityGeneration ||
      request.expectedKeyEpoch != previous.keyEpoch ||
      !_sameBytes(
        request.expectedMembershipManifestDigest.bytes,
        previous.digest,
      ) ||
      request.operationId != binding.membershipOperationId ||
      request.operationId != binding.rekeyOperationId ||
      request.revokeDeviceId != next.subjectDeviceId ||
      request.nextRecoveryCapsuleVersion != next.recoveryCapsuleVersion ||
      !_sameBytes(capsuleDigest, next.recoveryCapsuleDigest) ||
      !_sameBytes(request.nextMembershipManifest, next.manifest) ||
      !_sameBytes(
        request.nextMembershipManifestDigest.bytes,
        binding.membershipManifestDigest,
      ) ||
      !_sameStringList(actualTargetIds, expectedTargetIds) ||
      !_sameAuthorization(
        request.authorization,
        binding.selfRevocationAuthorization,
      )) {
    throw const FormatException('设备轮换请求未绑定已验证账户换钥计划');
  }
}

void _requireResultMatchesPlan(
  CloudSyncDeviceRotationResult result,
  E2eeDeviceStateKeyTransitionPlan plan,
  CloudSyncDeviceRotationRequest request,
) {
  final binding = plan.binding;
  if (result.operationId != binding.membershipOperationId ||
      result.revokedDeviceId != request.revokeDeviceId ||
      result.fromGeneration != request.expectedGeneration ||
      result.generation != binding.securityGeneration ||
      result.keyEpoch != binding.targetKeyEpoch ||
      result.dataRekeyPhase != CloudSyncDataRekeyPhase.rekeyPending ||
      result.membershipManifestDigest.encoded !=
          request.nextMembershipManifestDigest.encoded ||
      !_sameAuthorization(
        result.authorization,
        binding.selfRevocationAuthorization,
      )) {
    throw const FormatException('设备轮换远端回执未绑定已验证账户换钥计划');
  }
}

E2eeAccountKeyTransitionRemoteReceipt _receiptFromResult(
  CloudSyncDeviceRotationResult result,
  E2eeAccountKeyTransitionBinding binding,
) {
  final authorization = binding.selfRevocationAuthorization;
  if (authorization == null) {
    return E2eeAccountKeyTransitionRemoteReceipt(
      kind: binding.kind,
      userId: binding.userId,
      issuerDeviceId: binding.issuerDeviceId,
      membershipOperationId: result.operationId,
      rekeyOperationId: binding.rekeyOperationId,
      securityGeneration: result.generation,
      targetKeyEpoch: result.keyEpoch,
      membershipManifestDigest: result.membershipManifestDigest.bytes,
    );
  }
  return E2eeAccountKeyTransitionRemoteReceipt.selfRevocation(
    userId: binding.userId,
    issuerDeviceId: binding.issuerDeviceId,
    membershipOperationId: result.operationId,
    rekeyOperationId: binding.rekeyOperationId,
    securityGeneration: result.generation,
    targetKeyEpoch: result.keyEpoch,
    membershipManifestDigest: result.membershipManifestDigest.bytes,
    authorization: authorization,
  );
}

void _requireReceiptMatchesPlan(
  E2eeAccountKeyTransitionRemoteReceipt receipt,
  E2eeAccountKeyTransitionBinding binding,
) {
  if (receipt.kind != binding.kind ||
      receipt.userId != binding.userId ||
      receipt.issuerDeviceId != binding.issuerDeviceId ||
      receipt.membershipOperationId != binding.membershipOperationId ||
      receipt.rekeyOperationId != binding.rekeyOperationId ||
      receipt.securityGeneration != binding.securityGeneration ||
      receipt.targetKeyEpoch != binding.targetKeyEpoch ||
      !_sameBytes(
        receipt.membershipManifestDigest,
        binding.membershipManifestDigest,
      ) ||
      !_sameAuthorization(
        receipt.selfRevocationAuthorization,
        binding.selfRevocationAuthorization,
      )) {
    throw const FormatException('设备轮换完成回执未绑定账户换钥计划');
  }
}

bool _sameAuthorization(
  E2eeSelfRevocationRotationBinding? left,
  E2eeSelfRevocationRotationBinding? right,
) {
  if (left == null || right == null) return left == null && right == null;
  return left.hasSameSecurityBinding(right);
}

bool _sameStringList(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}
