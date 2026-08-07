import 'dart:typed_data';

import 'e2ee_data_rekey_executor.dart';
import 'e2ee_self_revocation_rotation_binding.dart';

const _accountKeyTransitionMaximumInt32 = 0x7fffffff;
const _accountKeyTransitionMaximumUint32 = 0xffffffff;

final _accountKeyTransitionUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

enum E2eeAccountKeyTransitionKind {
  deviceRevocation,
  recoveryResume,
  recoveryReplacement,
}

final class E2eeAccountKeyTransitionBinding {
  factory E2eeAccountKeyTransitionBinding({
    required E2eeAccountKeyTransitionKind kind,
    required String userId,
    required String issuerDeviceId,
    required String membershipOperationId,
    required String rekeyOperationId,
    required int securityGeneration,
    required int targetKeyEpoch,
    required Uint8List membershipManifestDigest,
  }) {
    return E2eeAccountKeyTransitionBinding._validated(
      kind: kind,
      userId: userId,
      issuerDeviceId: issuerDeviceId,
      membershipOperationId: membershipOperationId,
      rekeyOperationId: rekeyOperationId,
      securityGeneration: securityGeneration,
      targetKeyEpoch: targetKeyEpoch,
      membershipManifestDigest: membershipManifestDigest,
      selfRevocationAuthorization: null,
    );
  }

  factory E2eeAccountKeyTransitionBinding.selfRevocation({
    required String userId,
    required String issuerDeviceId,
    required String membershipOperationId,
    required String rekeyOperationId,
    required int securityGeneration,
    required int targetKeyEpoch,
    required Uint8List membershipManifestDigest,
    required E2eeSelfRevocationRotationBinding authorization,
  }) {
    return E2eeAccountKeyTransitionBinding._validated(
      kind: E2eeAccountKeyTransitionKind.deviceRevocation,
      userId: userId,
      issuerDeviceId: issuerDeviceId,
      membershipOperationId: membershipOperationId,
      rekeyOperationId: rekeyOperationId,
      securityGeneration: securityGeneration,
      targetKeyEpoch: targetKeyEpoch,
      membershipManifestDigest: membershipManifestDigest,
      selfRevocationAuthorization: authorization,
    );
  }

  factory E2eeAccountKeyTransitionBinding._validated({
    required E2eeAccountKeyTransitionKind kind,
    required String userId,
    required String issuerDeviceId,
    required String membershipOperationId,
    required String rekeyOperationId,
    required int securityGeneration,
    required int targetKeyEpoch,
    required Uint8List membershipManifestDigest,
    required E2eeSelfRevocationRotationBinding? selfRevocationAuthorization,
  }) {
    final checkedMembershipOperationId = _requireTransitionUuid(
      membershipOperationId,
      'membershipOperationId',
    );
    final checkedRekeyOperationId = _requireTransitionUuid(
      rekeyOperationId,
      'rekeyOperationId',
    );
    final checkedSecurityGeneration = _requireTransitionPositiveInt(
      securityGeneration,
      _accountKeyTransitionMaximumInt32,
      'securityGeneration',
    );
    final checkedTargetKeyEpoch = _requireTransitionPositiveInt(
      targetKeyEpoch,
      _accountKeyTransitionMaximumUint32,
      'targetKeyEpoch',
    );
    _requireTransitionOperationRelationship(
      kind,
      checkedMembershipOperationId,
      checkedRekeyOperationId,
    );
    _requireSelfRevocationAuthorizationMatchesTransition(
      kind: kind,
      authorization: selfRevocationAuthorization,
      membershipOperationId: checkedMembershipOperationId,
      rekeyOperationId: checkedRekeyOperationId,
      securityGeneration: checkedSecurityGeneration,
      targetKeyEpoch: checkedTargetKeyEpoch,
    );
    return E2eeAccountKeyTransitionBinding._(
      kind: kind,
      userId: _requireTransitionUuid(userId, 'userId'),
      issuerDeviceId: _requireTransitionUuid(issuerDeviceId, 'issuerDeviceId'),
      membershipOperationId: checkedMembershipOperationId,
      rekeyOperationId: checkedRekeyOperationId,
      securityGeneration: checkedSecurityGeneration,
      targetKeyEpoch: checkedTargetKeyEpoch,
      membershipManifestDigest: _copyTransitionDigest(
        membershipManifestDigest,
        'membershipManifestDigest',
      ),
      selfRevocationAuthorization: selfRevocationAuthorization,
    );
  }

  const E2eeAccountKeyTransitionBinding._({
    required this.kind,
    required this.userId,
    required this.issuerDeviceId,
    required this.membershipOperationId,
    required this.rekeyOperationId,
    required this.securityGeneration,
    required this.targetKeyEpoch,
    required this._membershipManifestDigest,
    required this.selfRevocationAuthorization,
  });

  final E2eeAccountKeyTransitionKind kind;
  final String userId;
  final String issuerDeviceId;
  final String membershipOperationId;
  final String rekeyOperationId;
  final int securityGeneration;
  final int targetKeyEpoch;
  final Uint8List _membershipManifestDigest;
  final E2eeSelfRevocationRotationBinding? selfRevocationAuthorization;

  Uint8List get membershipManifestDigest =>
      Uint8List.fromList(_membershipManifestDigest);
}

final class E2eeAccountKeyTransitionRemoteReceipt {
  factory E2eeAccountKeyTransitionRemoteReceipt({
    required E2eeAccountKeyTransitionKind kind,
    required String userId,
    required String issuerDeviceId,
    required String membershipOperationId,
    required String rekeyOperationId,
    required int securityGeneration,
    required int targetKeyEpoch,
    required Uint8List membershipManifestDigest,
  }) {
    return E2eeAccountKeyTransitionRemoteReceipt._validated(
      kind: kind,
      userId: userId,
      issuerDeviceId: issuerDeviceId,
      membershipOperationId: membershipOperationId,
      rekeyOperationId: rekeyOperationId,
      securityGeneration: securityGeneration,
      targetKeyEpoch: targetKeyEpoch,
      membershipManifestDigest: membershipManifestDigest,
      selfRevocationAuthorization: null,
    );
  }

  factory E2eeAccountKeyTransitionRemoteReceipt.selfRevocation({
    required String userId,
    required String issuerDeviceId,
    required String membershipOperationId,
    required String rekeyOperationId,
    required int securityGeneration,
    required int targetKeyEpoch,
    required Uint8List membershipManifestDigest,
    required E2eeSelfRevocationRotationBinding authorization,
  }) {
    return E2eeAccountKeyTransitionRemoteReceipt._validated(
      kind: E2eeAccountKeyTransitionKind.deviceRevocation,
      userId: userId,
      issuerDeviceId: issuerDeviceId,
      membershipOperationId: membershipOperationId,
      rekeyOperationId: rekeyOperationId,
      securityGeneration: securityGeneration,
      targetKeyEpoch: targetKeyEpoch,
      membershipManifestDigest: membershipManifestDigest,
      selfRevocationAuthorization: authorization,
    );
  }

  factory E2eeAccountKeyTransitionRemoteReceipt._validated({
    required E2eeAccountKeyTransitionKind kind,
    required String userId,
    required String issuerDeviceId,
    required String membershipOperationId,
    required String rekeyOperationId,
    required int securityGeneration,
    required int targetKeyEpoch,
    required Uint8List membershipManifestDigest,
    required E2eeSelfRevocationRotationBinding? selfRevocationAuthorization,
  }) {
    final checkedMembershipOperationId = _requireTransitionUuid(
      membershipOperationId,
      'membershipOperationId',
    );
    final checkedRekeyOperationId = _requireTransitionUuid(
      rekeyOperationId,
      'rekeyOperationId',
    );
    final checkedSecurityGeneration = _requireTransitionPositiveInt(
      securityGeneration,
      _accountKeyTransitionMaximumInt32,
      'securityGeneration',
    );
    final checkedTargetKeyEpoch = _requireTransitionPositiveInt(
      targetKeyEpoch,
      _accountKeyTransitionMaximumUint32,
      'targetKeyEpoch',
    );
    _requireTransitionOperationRelationship(
      kind,
      checkedMembershipOperationId,
      checkedRekeyOperationId,
    );
    _requireSelfRevocationAuthorizationMatchesTransition(
      kind: kind,
      authorization: selfRevocationAuthorization,
      membershipOperationId: checkedMembershipOperationId,
      rekeyOperationId: checkedRekeyOperationId,
      securityGeneration: checkedSecurityGeneration,
      targetKeyEpoch: checkedTargetKeyEpoch,
    );
    return E2eeAccountKeyTransitionRemoteReceipt._(
      kind: kind,
      userId: _requireTransitionUuid(userId, 'userId'),
      issuerDeviceId: _requireTransitionUuid(issuerDeviceId, 'issuerDeviceId'),
      membershipOperationId: checkedMembershipOperationId,
      rekeyOperationId: checkedRekeyOperationId,
      securityGeneration: checkedSecurityGeneration,
      targetKeyEpoch: checkedTargetKeyEpoch,
      membershipManifestDigest: _copyTransitionDigest(
        membershipManifestDigest,
        'membershipManifestDigest',
      ),
      selfRevocationAuthorization: selfRevocationAuthorization,
    );
  }

  const E2eeAccountKeyTransitionRemoteReceipt._({
    required this.kind,
    required this.userId,
    required this.issuerDeviceId,
    required this.membershipOperationId,
    required this.rekeyOperationId,
    required this.securityGeneration,
    required this.targetKeyEpoch,
    required this._membershipManifestDigest,
    required this.selfRevocationAuthorization,
  });

  final E2eeAccountKeyTransitionKind kind;
  final String userId;
  final String issuerDeviceId;
  final String membershipOperationId;
  final String rekeyOperationId;
  final int securityGeneration;
  final int targetKeyEpoch;
  final Uint8List _membershipManifestDigest;
  final E2eeSelfRevocationRotationBinding? selfRevocationAuthorization;

  Uint8List get membershipManifestDigest =>
      Uint8List.fromList(_membershipManifestDigest);
}

abstract interface class E2eeAccountKeyTransitionRemoteCommit {
  Future<E2eeAccountKeyTransitionRemoteReceipt> commit();

  Future<void> complete(E2eeAccountKeyTransitionRemoteReceipt receipt);
}

abstract interface class E2eeAccountKeyTransitionLocalCommitter {
  Future<void> commit({
    required E2eeAccountKeyTransitionBinding binding,
    required E2eeDataRekeyFinalizedExecution execution,
  });

  Future<void> requireCommitted({
    required E2eeAccountKeyTransitionBinding binding,
  });
}

final class E2eeAccountKeyTransitionCoordinator {
  factory E2eeAccountKeyTransitionCoordinator({
    required E2eeDataRekeyExecutor dataRekeyExecutor,
    required E2eeAccountKeyTransitionRemoteCommit remoteCommit,
    required E2eeAccountKeyTransitionLocalCommitter localCommitter,
  }) => E2eeAccountKeyTransitionCoordinator._(
    dataRekeyExecutor,
    remoteCommit,
    localCommitter,
  );

  E2eeAccountKeyTransitionCoordinator._(
    this._dataRekeyExecutor,
    this._remoteCommit,
    this._localCommitter,
  );

  final E2eeDataRekeyExecutor _dataRekeyExecutor;
  final E2eeAccountKeyTransitionRemoteCommit _remoteCommit;
  final E2eeAccountKeyTransitionLocalCommitter _localCommitter;

  bool _running = false;

  Future<E2eeAccountKeyTransitionRemoteReceipt> execute({
    required E2eeDataRekeyExecutionContext context,
    required E2eeAccountKeyTransitionBinding binding,
  }) async {
    if (_running) throw StateError('account_key_transition_busy');
    _requireContextMatchesTransition(context, binding);
    _running = true;
    try {
      final receipt = await _remoteCommit.commit();
      _requireReceiptMatchesTransition(receipt, binding);
      final execution = await _dataRekeyExecutor.execute(context);
      if (execution == null) {
        await _localCommitter.requireCommitted(binding: binding);
        await _remoteCommit.complete(receipt);
        return receipt;
      }
      _requireExecutionMatchesTransition(execution, binding);
      // execute 已触发服务端 finalize（回执自带已验证完成证明），
      // 服务端 data-rekey 已脱离 ready 状态，无需也不能再 confirmReady。
      await _localCommitter.commit(binding: binding, execution: execution);
      await _dataRekeyExecutor.acknowledgeLocalCommit(
        context: context,
        execution: execution,
      );
      await _remoteCommit.complete(receipt);
      return receipt;
    } finally {
      _running = false;
    }
  }
}

void _requireContextMatchesTransition(
  E2eeDataRekeyExecutionContext context,
  E2eeAccountKeyTransitionBinding binding,
) {
  if (context.userId != binding.userId ||
      context.issuerDeviceId != binding.issuerDeviceId ||
      context.membershipGeneration != binding.securityGeneration ||
      !_sameTransitionBytes(
        context.membershipManifestDigest,
        binding._membershipManifestDigest,
      )) {
    throw const FormatException('账户密钥变更与 data-rekey 上下文不匹配');
  }
}

void _requireReceiptMatchesTransition(
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
      !_sameSelfRevocationAuthorization(
        receipt.selfRevocationAuthorization,
        binding.selfRevocationAuthorization,
      ) ||
      !_sameTransitionBytes(
        receipt._membershipManifestDigest,
        binding._membershipManifestDigest,
      )) {
    throw const FormatException('账户密钥变更远端回执不匹配');
  }
}

void _requireExecutionMatchesTransition(
  E2eeDataRekeyFinalizedExecution execution,
  E2eeAccountKeyTransitionBinding binding,
) {
  final result = execution.result;
  final completion = result.completion;
  if (execution.operationId != binding.rekeyOperationId ||
      execution.userId != binding.userId ||
      execution.issuerDeviceId != binding.issuerDeviceId ||
      result.dataKeyEpoch != binding.targetKeyEpoch ||
      completion.operationId != binding.rekeyOperationId ||
      completion.issuerDeviceId != binding.issuerDeviceId ||
      completion.targetKeyEpoch != binding.targetKeyEpoch ||
      completion.membershipGeneration != binding.securityGeneration ||
      !_sameTransitionBytes(
        completion.membershipManifestDigest,
        binding._membershipManifestDigest,
      )) {
    throw const FormatException('账户密钥变更 data-rekey 回执不匹配');
  }
}

void _requireTransitionOperationRelationship(
  E2eeAccountKeyTransitionKind kind,
  String membershipOperationId,
  String rekeyOperationId,
) {
  final sameOperation = membershipOperationId == rekeyOperationId;
  switch (kind) {
    case E2eeAccountKeyTransitionKind.deviceRevocation:
      if (!sameOperation) {
        throw const FormatException('设备撤销成员操作与数据换代操作必须相同');
      }
    case E2eeAccountKeyTransitionKind.recoveryResume:
      if (sameOperation) {
        throw const FormatException('恢复接续不得复用遗留数据换代操作');
      }
    case E2eeAccountKeyTransitionKind.recoveryReplacement:
      if (!sameOperation) {
        throw const FormatException('恢复替换成员操作与第二轮数据换代操作必须相同');
      }
  }
}

void _requireSelfRevocationAuthorizationMatchesTransition({
  required E2eeAccountKeyTransitionKind kind,
  required E2eeSelfRevocationRotationBinding? authorization,
  required String membershipOperationId,
  required String rekeyOperationId,
  required int securityGeneration,
  required int targetKeyEpoch,
}) {
  if (authorization == null) return;
  if (kind != E2eeAccountKeyTransitionKind.deviceRevocation ||
      authorization.operationId != membershipOperationId ||
      authorization.operationId != rekeyOperationId ||
      authorization.expectedGeneration + 1 != securityGeneration ||
      authorization.expectedKeyEpoch + 1 != targetKeyEpoch) {
    throw const FormatException('自撤销授权与账户密钥变更不匹配');
  }
}

bool _sameSelfRevocationAuthorization(
  E2eeSelfRevocationRotationBinding? left,
  E2eeSelfRevocationRotationBinding? right,
) {
  if (left == null || right == null) return left == null && right == null;
  return left.hasSameSecurityBinding(right);
}

String _requireTransitionUuid(String value, String field) {
  if (!_accountKeyTransitionUuidPattern.hasMatch(value)) {
    throw FormatException('$field 必须是规范 UUID v4');
  }
  return value;
}

int _requireTransitionPositiveInt(int value, int maximum, String field) {
  if (value <= 0 || value > maximum) {
    throw FormatException('$field 超出协议范围');
  }
  return value;
}

Uint8List _copyTransitionDigest(Uint8List value, String field) {
  if (value.length != 32) throw FormatException('$field 长度无效');
  return Uint8List.fromList(value).asUnmodifiableView();
}

bool _sameTransitionBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}
