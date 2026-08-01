import 'dart:typed_data';

import 'e2ee_data_rekey_executor.dart';

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
  E2eeAccountKeyTransitionBinding({
    required this.kind,
    required String userId,
    required String issuerDeviceId,
    required String membershipOperationId,
    required String rekeyOperationId,
    required int securityGeneration,
    required int targetKeyEpoch,
    required Uint8List membershipManifestDigest,
  }) : userId = _requireTransitionUuid(userId, 'userId'),
       issuerDeviceId = _requireTransitionUuid(
         issuerDeviceId,
         'issuerDeviceId',
       ),
       membershipOperationId = _requireTransitionUuid(
         membershipOperationId,
         'membershipOperationId',
       ),
       rekeyOperationId = _requireTransitionUuid(
         rekeyOperationId,
         'rekeyOperationId',
       ),
       securityGeneration = _requireTransitionPositiveInt(
         securityGeneration,
         _accountKeyTransitionMaximumInt32,
         'securityGeneration',
       ),
       targetKeyEpoch = _requireTransitionPositiveInt(
         targetKeyEpoch,
         _accountKeyTransitionMaximumUint32,
         'targetKeyEpoch',
       ),
       membershipManifestDigest = _copyTransitionDigest(
         membershipManifestDigest,
         'membershipManifestDigest',
       ) {
    final sameOperation = membershipOperationId == rekeyOperationId;
    if (kind == E2eeAccountKeyTransitionKind.deviceRevocation &&
        !sameOperation) {
      throw const FormatException('设备撤销成员操作与数据换代操作必须相同');
    }
    if (kind == E2eeAccountKeyTransitionKind.recoveryReplacement &&
        !sameOperation) {
      throw const FormatException('恢复替换成员操作与第二轮数据换代操作必须相同');
    }
  }

  final E2eeAccountKeyTransitionKind kind;
  final String userId;
  final String issuerDeviceId;
  final String membershipOperationId;
  final String rekeyOperationId;
  final int securityGeneration;
  final int targetKeyEpoch;
  final Uint8List membershipManifestDigest;
}

final class E2eeAccountKeyTransitionRemoteReceipt {
  E2eeAccountKeyTransitionRemoteReceipt({
    required this.kind,
    required String userId,
    required String membershipOperationId,
    required String rekeyOperationId,
    required int securityGeneration,
    required int targetKeyEpoch,
    required Uint8List membershipManifestDigest,
  }) : userId = _requireTransitionUuid(userId, 'userId'),
       membershipOperationId = _requireTransitionUuid(
         membershipOperationId,
         'membershipOperationId',
       ),
       rekeyOperationId = _requireTransitionUuid(
         rekeyOperationId,
         'rekeyOperationId',
       ),
       securityGeneration = _requireTransitionPositiveInt(
         securityGeneration,
         _accountKeyTransitionMaximumInt32,
         'securityGeneration',
       ),
       targetKeyEpoch = _requireTransitionPositiveInt(
         targetKeyEpoch,
         _accountKeyTransitionMaximumUint32,
         'targetKeyEpoch',
       ),
       membershipManifestDigest = _copyTransitionDigest(
         membershipManifestDigest,
         'membershipManifestDigest',
       );

  final E2eeAccountKeyTransitionKind kind;
  final String userId;
  final String membershipOperationId;
  final String rekeyOperationId;
  final int securityGeneration;
  final int targetKeyEpoch;
  final Uint8List membershipManifestDigest;
}

abstract interface class E2eeAccountKeyTransitionRemoteCommit {
  Future<E2eeAccountKeyTransitionRemoteReceipt> commit();

  Future<void> complete(E2eeAccountKeyTransitionRemoteReceipt receipt);
}

abstract interface class E2eeAccountKeyTransitionLocalCommitter {
  Future<void> commit({
    required E2eeAccountKeyTransitionBinding binding,
    required E2eeDataRekeyReadyConfirmation confirmation,
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
      final confirmation = await _dataRekeyExecutor.confirmReady(
        context: context,
        execution: execution,
      );
      await _localCommitter.commit(
        binding: binding,
        confirmation: confirmation,
      );
      await _dataRekeyExecutor.acknowledgeLocalCommit(
        context: context,
        confirmation: confirmation,
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
        binding.membershipManifestDigest,
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
      receipt.membershipOperationId != binding.membershipOperationId ||
      receipt.rekeyOperationId != binding.rekeyOperationId ||
      receipt.securityGeneration != binding.securityGeneration ||
      receipt.targetKeyEpoch != binding.targetKeyEpoch ||
      !_sameTransitionBytes(
        receipt.membershipManifestDigest,
        binding.membershipManifestDigest,
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
        binding.membershipManifestDigest,
      )) {
    throw const FormatException('账户密钥变更 data-rekey 回执不匹配');
  }
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
