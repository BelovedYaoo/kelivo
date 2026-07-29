part of 'cloud_sync_types.dart';

const cloudSyncDataRekeyDigestBytes = 32;
const cloudSyncDataRekeyProofFrameBytes = 270;

final class CloudSyncDataRekeyAttachmentCursor {
  factory CloudSyncDataRekeyAttachmentCursor({
    required String attachmentId,
    required String uploadId,
  }) {
    return CloudSyncDataRekeyAttachmentCursor._(
      _requireCanonicalUuid(attachmentId, 'attachmentId'),
      _requireCanonicalUuid(uploadId, 'uploadId'),
    );
  }

  const CloudSyncDataRekeyAttachmentCursor._(this.attachmentId, this.uploadId);

  factory CloudSyncDataRekeyAttachmentCursor.fromJson(CloudSyncJsonMap json) {
    _requireExactKeys(json, _jsonKeys, 'data-rekey 附件游标');
    return CloudSyncDataRekeyAttachmentCursor(
      attachmentId: _requireString(json, 'attachmentId'),
      uploadId: _requireString(json, 'uploadId'),
    );
  }

  static const _jsonKeys = <String>{'attachmentId', 'uploadId'};

  final String attachmentId;
  final String uploadId;
}

final class CloudSyncDataRekeyLease {
  factory CloudSyncDataRekeyLease({
    required int leaseVersion,
    required bool ownedByCurrentDevice,
    required DateTime expiresAt,
  }) {
    if (!expiresAt.isUtc) {
      throw const FormatException('data-rekey 租约到期时间必须为 UTC');
    }
    return CloudSyncDataRekeyLease._(
      _requirePositiveInt32(leaseVersion, 'leaseVersion'),
      ownedByCurrentDevice,
      expiresAt,
    );
  }

  const CloudSyncDataRekeyLease._(
    this.leaseVersion,
    this.ownedByCurrentDevice,
    this.expiresAt,
  );

  factory CloudSyncDataRekeyLease.fromJson(CloudSyncJsonMap json) {
    _requireExactKeys(json, _jsonKeys, 'data-rekey 租约');
    return CloudSyncDataRekeyLease(
      leaseVersion: _requireInt(json, 'leaseVersion'),
      ownedByCurrentDevice: _requireBool(json, 'ownedByCurrentDevice'),
      expiresAt: _requireCanonicalUtcDateTime(json, 'expiresAt'),
    );
  }

  static const _jsonKeys = <String>{
    'leaseVersion',
    'ownedByCurrentDevice',
    'expiresAt',
  };

  final int leaseVersion;
  final bool ownedByCurrentDevice;
  final DateTime expiresAt;
}

final class CloudSyncDataRekeyCompletion {
  factory CloudSyncDataRekeyCompletion.fromJson(CloudSyncJsonMap json) {
    _requireExactKeys(json, _jsonKeys, 'data-rekey 完成证明');
    final proofVersion = _requireInt(json, 'proofVersion');
    if (proofVersion != 2) {
      throw const FormatException('data-rekey 完成证明版本无效');
    }
    final sourceDataGeneration = _requirePositiveInt32(
      _requireInt(json, 'sourceDataGeneration'),
      'sourceDataGeneration',
    );
    final targetDataGeneration = _requirePositiveInt32(
      _requireInt(json, 'targetDataGeneration'),
      'targetDataGeneration',
    );
    final sourceKeyEpoch = _requirePositiveUint32(
      _requireInt(json, 'sourceKeyEpoch'),
      'sourceKeyEpoch',
    );
    final targetKeyEpoch = _requirePositiveUint32(
      _requireInt(json, 'targetKeyEpoch'),
      'targetKeyEpoch',
    );
    if (targetDataGeneration != sourceDataGeneration + 1 ||
        targetKeyEpoch != sourceKeyEpoch + 1) {
      throw const FormatException('data-rekey 完成证明代次不连续');
    }
    final sourceRecordCount = _requireNonNegativeInt32(
      _requireInt(json, 'sourceRecordCount'),
      'sourceRecordCount',
    );
    final sourceAttachmentCount = _requireNonNegativeInt32(
      _requireInt(json, 'sourceAttachmentCount'),
      'sourceAttachmentCount',
    );
    final stagedRecordCount = _requireNonNegativeInt32(
      _requireInt(json, 'stagedRecordCount'),
      'stagedRecordCount',
    );
    final stagedAttachmentCount = _requireNonNegativeInt32(
      _requireInt(json, 'stagedAttachmentCount'),
      'stagedAttachmentCount',
    );
    if (sourceRecordCount != stagedRecordCount ||
        sourceAttachmentCount != stagedAttachmentCount) {
      throw const FormatException('data-rekey 完成证明暂存数量不完整');
    }
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
    return CloudSyncDataRekeyCompletion._(
      proofVersion: proofVersion,
      operationId: _requireCanonicalUuid(
        _requireString(json, 'operationId'),
        'operationId',
      ),
      issuerDeviceId: _requireCanonicalUuid(
        _requireString(json, 'issuerDeviceId'),
        'issuerDeviceId',
      ),
      sourceDataGeneration: sourceDataGeneration,
      targetDataGeneration: targetDataGeneration,
      sourceKeyEpoch: sourceKeyEpoch,
      targetKeyEpoch: targetKeyEpoch,
      sourceSnapshotRoot: _decodeDataRekeyBytes(
        json,
        'sourceSnapshotRoot',
        cloudSyncDataRekeyDigestBytes,
      ),
      sourceRecordCount: sourceRecordCount,
      sourceAttachmentCount: sourceAttachmentCount,
      sourceMaximumChangeSeq: _requireNonNegativeSafeInteger(
        _requireInt(json, 'sourceMaximumChangeSeq'),
        'sourceMaximumChangeSeq',
      ),
      sourceRecordCursorEnd: sourceRecordCursorEnd,
      sourceAttachmentCursorEnd: sourceAttachmentCursorEnd,
      membershipGeneration: _requirePositiveInt32(
        _requireInt(json, 'membershipGeneration'),
        'membershipGeneration',
      ),
      membershipManifestDigest: _decodeDataRekeyBytes(
        json,
        'membershipManifestDigest',
        cloudSyncDataRekeyDigestBytes,
      ),
      stagedRecordCount: stagedRecordCount,
      stagedAttachmentCount: stagedAttachmentCount,
      stagedCiphertextSetDigest: _decodeDataRekeyBytes(
        json,
        'stagedCiphertextSetDigest',
        cloudSyncDataRekeyDigestBytes,
      ),
      proofFrame: _decodeDataRekeyBytes(
        json,
        'proofFrame',
        cloudSyncDataRekeyProofFrameBytes,
      ),
      proofDigest: _decodeDataRekeyBytes(
        json,
        'proofDigest',
        cloudSyncDataRekeyDigestBytes,
      ),
      signature: _decodeDataRekeyBytes(
        json,
        'signature',
        cloudSyncDeviceProofBytes,
      ),
      finalizedAt: _requireCanonicalUtcDateTime(json, 'finalizedAt'),
    );
  }

  const CloudSyncDataRekeyCompletion._({
    required this.proofVersion,
    required this.operationId,
    required this.issuerDeviceId,
    required this.sourceDataGeneration,
    required this.targetDataGeneration,
    required this.sourceKeyEpoch,
    required this.targetKeyEpoch,
    required this.sourceSnapshotRoot,
    required this.sourceRecordCount,
    required this.sourceAttachmentCount,
    required this.sourceMaximumChangeSeq,
    required this.sourceRecordCursorEnd,
    required this.sourceAttachmentCursorEnd,
    required this.membershipGeneration,
    required this.membershipManifestDigest,
    required this.stagedRecordCount,
    required this.stagedAttachmentCount,
    required this.stagedCiphertextSetDigest,
    required this.proofFrame,
    required this.proofDigest,
    required this.signature,
    required this.finalizedAt,
  });

  static const _jsonKeys = <String>{
    'proofVersion',
    'operationId',
    'issuerDeviceId',
    'sourceDataGeneration',
    'targetDataGeneration',
    'sourceKeyEpoch',
    'targetKeyEpoch',
    'sourceSnapshotRoot',
    'sourceRecordCount',
    'sourceAttachmentCount',
    'sourceMaximumChangeSeq',
    'sourceRecordCursorEnd',
    'sourceAttachmentCursorEnd',
    'membershipGeneration',
    'membershipManifestDigest',
    'stagedRecordCount',
    'stagedAttachmentCount',
    'stagedCiphertextSetDigest',
    'proofFrame',
    'proofDigest',
    'signature',
    'finalizedAt',
  };

  final int proofVersion;
  final String operationId;
  final String issuerDeviceId;
  final int sourceDataGeneration;
  final int targetDataGeneration;
  final int sourceKeyEpoch;
  final int targetKeyEpoch;
  final Uint8List sourceSnapshotRoot;
  final int sourceRecordCount;
  final int sourceAttachmentCount;
  final int sourceMaximumChangeSeq;
  final String? sourceRecordCursorEnd;
  final CloudSyncDataRekeyAttachmentCursor? sourceAttachmentCursorEnd;
  final int membershipGeneration;
  final Uint8List membershipManifestDigest;
  final int stagedRecordCount;
  final int stagedAttachmentCount;
  final Uint8List stagedCiphertextSetDigest;
  final Uint8List proofFrame;
  final Uint8List proofDigest;
  final Uint8List signature;
  final DateTime finalizedAt;
}

sealed class CloudSyncDataRekeyState {
  const CloudSyncDataRekeyState();

  factory CloudSyncDataRekeyState.fromJson(CloudSyncJsonMap json) {
    return switch (_requireString(json, 'phase')) {
      'ready' => CloudSyncDataRekeyReadyState.fromJson(json),
      'rekey-pending' => CloudSyncDataRekeyPendingState.fromJson(json),
      _ => throw const FormatException('data-rekey 状态阶段无效'),
    };
  }

  int get dataGeneration;
  int get dataKeyEpoch;
  int get changeWatermark;
  CloudSyncDataRekeyCompletion? get lastCompletion;
  DateTime get updatedAt;
}

final class CloudSyncDataRekeyReadyState extends CloudSyncDataRekeyState {
  factory CloudSyncDataRekeyReadyState.fromJson(CloudSyncJsonMap json) {
    _requireExactKeys(json, _jsonKeys, 'data-rekey ready 状态');
    if (_requireString(json, 'phase') != 'ready') {
      throw const FormatException('data-rekey ready 状态阶段无效');
    }
    return CloudSyncDataRekeyReadyState._(
      dataGeneration: _requirePositiveInt32(
        _requireInt(json, 'dataGeneration'),
        'dataGeneration',
      ),
      dataKeyEpoch: _requirePositiveUint32(
        _requireInt(json, 'dataKeyEpoch'),
        'dataKeyEpoch',
      ),
      changeWatermark: _requireNonNegativeSafeInteger(
        _requireInt(json, 'changeWatermark'),
        'changeWatermark',
      ),
      lastCompletion: _optionalDataRekeyCompletion(json, 'lastCompletion'),
      updatedAt: _requireCanonicalUtcDateTime(json, 'updatedAt'),
    );
  }

  const CloudSyncDataRekeyReadyState._({
    required this.dataGeneration,
    required this.dataKeyEpoch,
    required this.changeWatermark,
    required this.lastCompletion,
    required this.updatedAt,
  });

  static const _jsonKeys = <String>{
    'phase',
    'dataGeneration',
    'dataKeyEpoch',
    'changeWatermark',
    'lastCompletion',
    'updatedAt',
  };

  @override
  final int dataGeneration;
  @override
  final int dataKeyEpoch;
  @override
  final int changeWatermark;
  @override
  final CloudSyncDataRekeyCompletion? lastCompletion;
  @override
  final DateTime updatedAt;
}

final class CloudSyncDataRekeyPendingState extends CloudSyncDataRekeyState {
  factory CloudSyncDataRekeyPendingState.fromJson(CloudSyncJsonMap json) {
    _requireExactKeys(json, _jsonKeys, 'data-rekey pending 状态');
    if (_requireString(json, 'phase') != 'rekey-pending') {
      throw const FormatException('data-rekey pending 状态阶段无效');
    }
    final dataGeneration = _requirePositiveInt32(
      _requireInt(json, 'dataGeneration'),
      'dataGeneration',
    );
    final dataKeyEpoch = _requirePositiveUint32(
      _requireInt(json, 'dataKeyEpoch'),
      'dataKeyEpoch',
    );
    final targetKeyEpoch = _requirePositiveUint32(
      _requireInt(json, 'targetKeyEpoch'),
      'targetKeyEpoch',
    );
    if (targetKeyEpoch != dataKeyEpoch + 1) {
      throw const FormatException('data-rekey 目标密钥代次不连续');
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
    return CloudSyncDataRekeyPendingState._(
      dataGeneration: dataGeneration,
      dataKeyEpoch: dataKeyEpoch,
      changeWatermark: _requireNonNegativeSafeInteger(
        _requireInt(json, 'changeWatermark'),
        'changeWatermark',
      ),
      operationId: _requireCanonicalUuid(
        _requireString(json, 'operationId'),
        'operationId',
      ),
      targetKeyEpoch: targetKeyEpoch,
      sourceRecordCount: sourceRecordCount,
      sourceAttachmentCount: sourceAttachmentCount,
      sourceMaximumChangeSeq: _requireNonNegativeSafeInteger(
        _requireInt(json, 'sourceMaximumChangeSeq'),
        'sourceMaximumChangeSeq',
      ),
      sourceRecordCursorEnd: sourceRecordCursorEnd,
      sourceAttachmentCursorEnd: sourceAttachmentCursorEnd,
      lease: _optionalDataRekeyLease(json, 'lease'),
      lastCompletion: _optionalDataRekeyCompletion(json, 'lastCompletion'),
      updatedAt: _requireCanonicalUtcDateTime(json, 'updatedAt'),
    );
  }

  const CloudSyncDataRekeyPendingState._({
    required this.dataGeneration,
    required this.dataKeyEpoch,
    required this.changeWatermark,
    required this.operationId,
    required this.targetKeyEpoch,
    required this.sourceRecordCount,
    required this.sourceAttachmentCount,
    required this.sourceMaximumChangeSeq,
    required this.sourceRecordCursorEnd,
    required this.sourceAttachmentCursorEnd,
    required this.lease,
    required this.lastCompletion,
    required this.updatedAt,
  });

  static const _jsonKeys = <String>{
    'phase',
    'dataGeneration',
    'dataKeyEpoch',
    'changeWatermark',
    'operationId',
    'targetKeyEpoch',
    'sourceRecordCount',
    'sourceAttachmentCount',
    'sourceMaximumChangeSeq',
    'sourceRecordCursorEnd',
    'sourceAttachmentCursorEnd',
    'lease',
    'lastCompletion',
    'updatedAt',
  };

  @override
  final int dataGeneration;
  @override
  final int dataKeyEpoch;
  @override
  final int changeWatermark;
  final String operationId;
  final int targetKeyEpoch;
  final int sourceRecordCount;
  final int sourceAttachmentCount;
  final int sourceMaximumChangeSeq;
  final String? sourceRecordCursorEnd;
  final CloudSyncDataRekeyAttachmentCursor? sourceAttachmentCursorEnd;
  final CloudSyncDataRekeyLease? lease;
  @override
  final CloudSyncDataRekeyCompletion? lastCompletion;
  @override
  final DateTime updatedAt;

  int get sourceDataGeneration => dataGeneration;
  int get sourceKeyEpoch => dataKeyEpoch;
}

String? _optionalCanonicalUuid(CloudSyncJsonMap json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('$key 必须为 UUID 或 null');
  }
  return _requireCanonicalUuid(value, key);
}

CloudSyncDataRekeyAttachmentCursor? _optionalDataRekeyAttachmentCursor(
  CloudSyncJsonMap json,
  String key,
) {
  final value = json[key];
  return value == null
      ? null
      : CloudSyncDataRekeyAttachmentCursor.fromJson(
          copyCloudSyncJsonMap(value),
        );
}

CloudSyncDataRekeyLease? _optionalDataRekeyLease(
  CloudSyncJsonMap json,
  String key,
) {
  final value = json[key];
  return value == null
      ? null
      : CloudSyncDataRekeyLease.fromJson(copyCloudSyncJsonMap(value));
}

CloudSyncDataRekeyCompletion? _optionalDataRekeyCompletion(
  CloudSyncJsonMap json,
  String key,
) {
  final value = json[key];
  return value == null
      ? null
      : CloudSyncDataRekeyCompletion.fromJson(copyCloudSyncJsonMap(value));
}

Uint8List _decodeDataRekeyBytes(
  CloudSyncJsonMap json,
  String key,
  int exactLength,
) {
  return _copyFixedBytes(
    _decodeCanonicalBinary(
      _requireString(json, key),
      field: key,
      exactLength: exactLength,
    ),
    exactLength,
    key,
  );
}

void _requireCountCursorPair({
  required int count,
  required bool hasCursor,
  required String field,
}) {
  if ((count == 0) == hasCursor) {
    throw FormatException('$field 与数量不一致');
  }
}
