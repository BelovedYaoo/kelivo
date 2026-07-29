part of 'cloud_sync_types.dart';

final class CloudSyncDataRekeyOperationScope {
  factory CloudSyncDataRekeyOperationScope({
    required String operationId,
    required int sourceDataGeneration,
    required int sourceKeyEpoch,
    required int targetKeyEpoch,
  }) {
    final checkedSourceKeyEpoch = _requirePositiveUint32(
      sourceKeyEpoch,
      'sourceKeyEpoch',
    );
    final checkedTargetKeyEpoch = _requirePositiveUint32(
      targetKeyEpoch,
      'targetKeyEpoch',
    );
    if (checkedTargetKeyEpoch != checkedSourceKeyEpoch + 1) {
      throw const FormatException('data-rekey operation 密钥代次不连续');
    }
    return CloudSyncDataRekeyOperationScope._(
      operationId: _requireCanonicalUuid(operationId, 'operationId'),
      sourceDataGeneration: _requirePositiveInt32(
        sourceDataGeneration,
        'sourceDataGeneration',
      ),
      sourceKeyEpoch: checkedSourceKeyEpoch,
      targetKeyEpoch: checkedTargetKeyEpoch,
    );
  }

  const CloudSyncDataRekeyOperationScope._({
    required this.operationId,
    required this.sourceDataGeneration,
    required this.sourceKeyEpoch,
    required this.targetKeyEpoch,
  });

  final String operationId;
  final int sourceDataGeneration;
  final int sourceKeyEpoch;
  final int targetKeyEpoch;

  CloudSyncJsonMap toJson() => <String, Object?>{
    'operationId': operationId,
    'sourceDataGeneration': sourceDataGeneration,
    'sourceKeyEpoch': sourceKeyEpoch,
    'targetKeyEpoch': targetKeyEpoch,
  };
}

final class CloudSyncDataRekeyLeaseClaimRequest {
  CloudSyncDataRekeyLeaseClaimRequest({
    required this.operation,
    required String leaseToken,
    required String mutationId,
  }) : leaseToken = _requireCanonicalUuid(leaseToken, 'leaseToken'),
       mutationId = _requireCanonicalUuid(mutationId, 'mutationId');

  final CloudSyncDataRekeyOperationScope operation;
  final String leaseToken;
  final String mutationId;

  CloudSyncJsonMap toJson() => <String, Object?>{
    ...operation.toJson(),
    'leaseToken': leaseToken,
    'mutationId': mutationId,
  };
}

final class CloudSyncDataRekeyActiveLease {
  CloudSyncDataRekeyActiveLease({
    required this.operation,
    required String leaseToken,
    required int leaseVersion,
  }) : leaseToken = _requireCanonicalUuid(leaseToken, 'leaseToken'),
       leaseVersion = _requirePositiveInt32(leaseVersion, 'leaseVersion');

  final CloudSyncDataRekeyOperationScope operation;
  final String leaseToken;
  final int leaseVersion;

  CloudSyncJsonMap toJson() => <String, Object?>{
    ...operation.toJson(),
    'leaseToken': leaseToken,
    'leaseVersion': leaseVersion,
  };
}

final class CloudSyncDataRekeyLeaseClaim {
  factory CloudSyncDataRekeyLeaseClaim.fromJson(
    CloudSyncJsonMap json, {
    required CloudSyncDataRekeyLeaseClaimRequest request,
  }) {
    _requireExactKeys(json, _jsonKeys, 'data-rekey 租约声明回执');
    if (_requireString(json, 'phase') != 'rekey-pending') {
      throw const FormatException('data-rekey 租约声明阶段无效');
    }
    final operation = request.operation;
    if (_requireString(json, 'operationId') != operation.operationId ||
        _requireInt(json, 'sourceDataGeneration') !=
            operation.sourceDataGeneration ||
        _requireInt(json, 'sourceKeyEpoch') != operation.sourceKeyEpoch ||
        _requireInt(json, 'targetKeyEpoch') != operation.targetKeyEpoch) {
      throw const FormatException('data-rekey 租约声明回执未绑定请求');
    }
    final sourceRecordCount = _requireNonNegativeInt32(
      _requireInt(json, 'sourceRecordCount'),
      'sourceRecordCount',
    );
    final sourceAttachmentCount = _requireNonNegativeInt32(
      _requireInt(json, 'sourceAttachmentCount'),
      'sourceAttachmentCount',
    );
    final sourceRecordCursorEnd = _optionalCanonicalUuid(
      json,
      'sourceRecordCursorEnd',
    );
    final sourceAttachmentCursorEnd = _optionalDataRekeyAttachmentCursor(
      json,
      'sourceAttachmentCursorEnd',
    );
    _requireCountCursorPair(
      count: sourceRecordCount,
      hasCursor: sourceRecordCursorEnd != null,
      field: 'sourceRecordCursorEnd',
    );
    _requireCountCursorPair(
      count: sourceAttachmentCount,
      hasCursor: sourceAttachmentCursorEnd != null,
      field: 'sourceAttachmentCursorEnd',
    );
    final leaseVersion = _requirePositiveInt32(
      _requireInt(json, 'leaseVersion'),
      'leaseVersion',
    );
    return CloudSyncDataRekeyLeaseClaim._(
      activeLease: CloudSyncDataRekeyActiveLease(
        operation: operation,
        leaseToken: request.leaseToken,
        leaseVersion: leaseVersion,
      ),
      leaseExpiresAt: _requireCanonicalUtcDateTime(json, 'leaseExpiresAt'),
      sourceRecordCount: sourceRecordCount,
      sourceAttachmentCount: sourceAttachmentCount,
      sourceMaximumChangeSeq: _requireNonNegativeSafeInteger(
        _requireInt(json, 'sourceMaximumChangeSeq'),
        'sourceMaximumChangeSeq',
      ),
      sourceRecordCursorEnd: sourceRecordCursorEnd,
      sourceAttachmentCursorEnd: sourceAttachmentCursorEnd,
    );
  }

  const CloudSyncDataRekeyLeaseClaim._({
    required this.activeLease,
    required this.leaseExpiresAt,
    required this.sourceRecordCount,
    required this.sourceAttachmentCount,
    required this.sourceMaximumChangeSeq,
    required this.sourceRecordCursorEnd,
    required this.sourceAttachmentCursorEnd,
  });

  static const _jsonKeys = <String>{
    'phase',
    'operationId',
    'sourceDataGeneration',
    'sourceKeyEpoch',
    'targetKeyEpoch',
    'leaseVersion',
    'leaseExpiresAt',
    'sourceRecordCount',
    'sourceAttachmentCount',
    'sourceMaximumChangeSeq',
    'sourceRecordCursorEnd',
    'sourceAttachmentCursorEnd',
  };

  final CloudSyncDataRekeyActiveLease activeLease;
  final DateTime leaseExpiresAt;
  final int sourceRecordCount;
  final int sourceAttachmentCount;
  final int sourceMaximumChangeSeq;
  final String? sourceRecordCursorEnd;
  final CloudSyncDataRekeyAttachmentCursor? sourceAttachmentCursorEnd;
}
