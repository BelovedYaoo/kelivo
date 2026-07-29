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

final class CloudSyncDataRekeySourceRecordListRequest {
  CloudSyncDataRekeySourceRecordListRequest({
    required this.activeLease,
    String? afterRecordId,
    int limit = 10,
  }) : afterRecordId = afterRecordId == null
           ? null
           : _requireCanonicalUuid(afterRecordId, 'afterRecordId'),
       limit = _requireBoundedInt(limit, 'limit', maximum: 10);

  final CloudSyncDataRekeyActiveLease activeLease;
  final String? afterRecordId;
  final int limit;
}

final class CloudSyncDataRekeySourceRecord {
  factory CloudSyncDataRekeySourceRecord.fromJson(
    CloudSyncJsonMap json, {
    required CloudSyncDataRekeySourceRecordListRequest request,
  }) {
    _requireExactKeys(json, _jsonKeys, 'data-rekey 源记录');
    if (_requireString(json, 'kind') != 'put') {
      throw const FormatException('data-rekey 源记录操作无效');
    }
    final keyEpoch = _requirePositiveUint32(
      _requireInt(json, 'keyEpoch'),
      'keyEpoch',
    );
    if (keyEpoch != request.activeLease.operation.sourceKeyEpoch) {
      throw const FormatException('data-rekey 源记录未绑定源密钥代次');
    }
    final envelopeVersion = _requireInt(json, 'envelopeVersion');
    if (envelopeVersion != 1) {
      throw const FormatException('data-rekey 源记录信封版本无效');
    }
    final ciphertext = _decodeCanonicalBinary(
      _requireString(json, 'ciphertext'),
      field: 'ciphertext',
      minimumLength: 1,
      maximumLength: 1048576,
    );
    final ciphertextBytes = _requireBoundedInt(
      _requireInt(json, 'ciphertextBytes'),
      'ciphertextBytes',
      maximum: 1048576,
    );
    if (ciphertext.length != ciphertextBytes) {
      throw const FormatException('data-rekey 源记录密文长度不一致');
    }
    final ciphertextDigest = _decodeDataRekeyBytes(
      json,
      'ciphertextDigest',
      cloudSyncDataRekeyDigestBytes,
    );
    if (!_sameBytes(ciphertextDigest, _sha256DataRekeyCiphertext(ciphertext))) {
      throw const FormatException('data-rekey 源记录密文摘要不一致');
    }
    return CloudSyncDataRekeySourceRecord._(
      recordId: _requireCanonicalUuid(
        _requireString(json, 'recordId'),
        'recordId',
      ),
      revision: _requirePositiveUint32(
        _requireInt(json, 'revision'),
        'revision',
      ),
      envelopeVersion: envelopeVersion,
      keyEpoch: keyEpoch,
      ciphertext: Uint8List.fromList(ciphertext).asUnmodifiableView(),
      ciphertextBytes: ciphertextBytes,
      updatedAt: _requireCanonicalUtcDateTime(json, 'updatedAt'),
      updatedByDeviceId: _optionalCanonicalUuid(json, 'updatedByDeviceId'),
      lastChangeSeq: _requireNonNegativeSafeInteger(
        _requireInt(json, 'lastChangeSeq'),
        'lastChangeSeq',
      ),
      ciphertextDigest: ciphertextDigest,
    );
  }

  const CloudSyncDataRekeySourceRecord._({
    required this.recordId,
    required this.revision,
    required this.envelopeVersion,
    required this.keyEpoch,
    required this.ciphertext,
    required this.ciphertextBytes,
    required this.updatedAt,
    required this.updatedByDeviceId,
    required this.lastChangeSeq,
    required this.ciphertextDigest,
  });

  static const _jsonKeys = <String>{
    'recordId',
    'revision',
    'envelopeVersion',
    'keyEpoch',
    'ciphertext',
    'ciphertextBytes',
    'updatedAt',
    'updatedByDeviceId',
    'lastChangeSeq',
    'kind',
    'ciphertextDigest',
  };

  final String recordId;
  final int revision;
  final int envelopeVersion;
  final int keyEpoch;
  final Uint8List ciphertext;
  final int ciphertextBytes;
  final DateTime updatedAt;
  final String? updatedByDeviceId;
  final int lastChangeSeq;
  final Uint8List ciphertextDigest;
}

final class CloudSyncDataRekeySourceRecordPage {
  factory CloudSyncDataRekeySourceRecordPage.fromJson(
    CloudSyncJsonMap json, {
    required CloudSyncDataRekeySourceRecordListRequest request,
  }) {
    _requireExactKeys(json, _jsonKeys, 'data-rekey 源记录分页');
    final rawRecords = json['records'];
    if (rawRecords is! List<Object?> || rawRecords.length > request.limit) {
      throw const FormatException('data-rekey 源记录分页数量无效');
    }
    final records = rawRecords
        .map(
          (record) => CloudSyncDataRekeySourceRecord.fromJson(
            copyCloudSyncJsonMap(record),
            request: request,
          ),
        )
        .toList(growable: false);
    var previousRecordId = request.afterRecordId;
    for (final record in records) {
      if (previousRecordId != null &&
          record.recordId.compareTo(previousRecordId) <= 0) {
        throw const FormatException('data-rekey 源记录分页顺序无效');
      }
      previousRecordId = record.recordId;
    }
    final nextAfterRecordId = _optionalCanonicalUuid(json, 'nextAfterRecordId');
    final hasMore = _requireBool(json, 'hasMore');
    if (hasMore
        ? records.isEmpty || nextAfterRecordId != records.last.recordId
        : nextAfterRecordId != null) {
      throw const FormatException('data-rekey 源记录分页游标无效');
    }
    return CloudSyncDataRekeySourceRecordPage._(
      records: List<CloudSyncDataRekeySourceRecord>.unmodifiable(records),
      nextAfterRecordId: nextAfterRecordId,
      hasMore: hasMore,
    );
  }

  const CloudSyncDataRekeySourceRecordPage._({
    required this.records,
    required this.nextAfterRecordId,
    required this.hasMore,
  });

  static const _jsonKeys = <String>{'records', 'nextAfterRecordId', 'hasMore'};

  final List<CloudSyncDataRekeySourceRecord> records;
  final String? nextAfterRecordId;
  final bool hasMore;
}

final class CloudSyncDataRekeySourceAttachmentListRequest {
  CloudSyncDataRekeySourceAttachmentListRequest({
    required this.activeLease,
    this.afterCursor,
    int limit = 10,
  }) : limit = _requireBoundedInt(limit, 'limit', maximum: 10);

  final CloudSyncDataRekeyActiveLease activeLease;
  final CloudSyncDataRekeyAttachmentCursor? afterCursor;
  final int limit;
}

final class CloudSyncDataRekeySourceAttachmentChunk {
  factory CloudSyncDataRekeySourceAttachmentChunk.fromJson(
    CloudSyncJsonMap json,
  ) {
    _requireExactKeys(json, _jsonKeys, 'data-rekey 源附件分块');
    final chunkIndex = _requireInt(json, 'chunkIndex');
    if (chunkIndex < 0 || chunkIndex >= 1000) {
      throw const FormatException('data-rekey 源附件分块索引无效');
    }
    return CloudSyncDataRekeySourceAttachmentChunk._(
      chunkIndex: chunkIndex,
      ciphertextBytes: _requireBoundedInt(
        _requireInt(json, 'ciphertextBytes'),
        'ciphertextBytes',
        maximum: 4194304,
      ),
      ciphertextDigest: _decodeDataRekeyBytes(
        json,
        'ciphertextDigest',
        cloudSyncDataRekeyDigestBytes,
      ),
    );
  }

  const CloudSyncDataRekeySourceAttachmentChunk._({
    required this.chunkIndex,
    required this.ciphertextBytes,
    required this.ciphertextDigest,
  });

  static const _jsonKeys = <String>{
    'chunkIndex',
    'ciphertextBytes',
    'ciphertextDigest',
  };

  final int chunkIndex;
  final int ciphertextBytes;
  final Uint8List ciphertextDigest;
}

final class CloudSyncDataRekeySourceAttachment {
  factory CloudSyncDataRekeySourceAttachment.fromJson(
    CloudSyncJsonMap json, {
    required CloudSyncDataRekeySourceAttachmentListRequest request,
  }) {
    _requireExactKeys(json, _jsonKeys, 'data-rekey 源附件');
    final manifestKeyEpoch = _requirePositiveUint32(
      _requireInt(json, 'manifestKeyEpoch'),
      'manifestKeyEpoch',
    );
    if (manifestKeyEpoch != request.activeLease.operation.sourceKeyEpoch) {
      throw const FormatException('data-rekey 源附件未绑定源 manifest 代次');
    }
    final chunkCount = _requireBoundedInt(
      _requireInt(json, 'chunkCount'),
      'chunkCount',
      maximum: 1000,
    );
    final totalCiphertextBytes = _requireInt(json, 'totalCiphertextBytes');
    if (totalCiphertextBytes < chunkCount ||
        totalCiphertextBytes > chunkCount * 4194304) {
      throw const FormatException('data-rekey 源附件分块总长度无效');
    }
    final manifestCiphertext = _decodeCanonicalBinary(
      _requireString(json, 'manifestCiphertext'),
      field: 'manifestCiphertext',
      minimumLength: 1,
      maximumLength: 1048576,
    );
    final manifestCiphertextBytes = _requireBoundedInt(
      _requireInt(json, 'manifestCiphertextBytes'),
      'manifestCiphertextBytes',
      maximum: 1048576,
    );
    if (manifestCiphertext.length != manifestCiphertextBytes) {
      throw const FormatException('data-rekey 源附件 manifest 长度不一致');
    }
    final manifestCiphertextDigest = _decodeDataRekeyBytes(
      json,
      'manifestCiphertextDigest',
      cloudSyncDataRekeyDigestBytes,
    );
    if (!_sameBytes(
      manifestCiphertextDigest,
      _sha256DataRekeyCiphertext(manifestCiphertext),
    )) {
      throw const FormatException('data-rekey 源附件 manifest 摘要不一致');
    }
    final rawChunks = json['chunks'];
    if (rawChunks is! List<Object?> || rawChunks.length != chunkCount) {
      throw const FormatException('data-rekey 源附件分块数量无效');
    }
    final chunks = rawChunks
        .map(
          (chunk) => CloudSyncDataRekeySourceAttachmentChunk.fromJson(
            copyCloudSyncJsonMap(chunk),
          ),
        )
        .toList(growable: false);
    var accumulatedCiphertextBytes = 0;
    for (var position = 0; position < chunks.length; position++) {
      final chunk = chunks[position];
      if (chunk.chunkIndex != position) {
        throw const FormatException('data-rekey 源附件分块索引不连续');
      }
      accumulatedCiphertextBytes += chunk.ciphertextBytes;
    }
    if (accumulatedCiphertextBytes != totalCiphertextBytes) {
      throw const FormatException('data-rekey 源附件分块总长度不一致');
    }
    final chunkKeyEpoch = _requirePositiveUint32(
      _requireInt(json, 'chunkKeyEpoch'),
      'chunkKeyEpoch',
    );
    if (chunkKeyEpoch > manifestKeyEpoch) {
      throw const FormatException('data-rekey 源附件分块代次晚于 manifest');
    }
    return CloudSyncDataRekeySourceAttachment._(
      attachmentId: _requireCanonicalUuid(
        _requireString(json, 'attachmentId'),
        'attachmentId',
      ),
      uploadId: _requireCanonicalUuid(
        _requireString(json, 'uploadId'),
        'uploadId',
      ),
      chunkKeyEpoch: chunkKeyEpoch,
      manifestKeyEpoch: manifestKeyEpoch,
      manifestRevision: _requirePositiveUint32(
        _requireInt(json, 'manifestRevision'),
        'manifestRevision',
      ),
      chunkCount: chunkCount,
      totalCiphertextBytes: totalCiphertextBytes,
      manifestCiphertext: Uint8List.fromList(
        manifestCiphertext,
      ).asUnmodifiableView(),
      manifestCiphertextBytes: manifestCiphertextBytes,
      manifestCiphertextDigest: manifestCiphertextDigest,
      chunks: List<CloudSyncDataRekeySourceAttachmentChunk>.unmodifiable(
        chunks,
      ),
      committedAt: _requireCanonicalUtcDateTime(json, 'committedAt'),
    );
  }

  const CloudSyncDataRekeySourceAttachment._({
    required this.attachmentId,
    required this.uploadId,
    required this.chunkKeyEpoch,
    required this.manifestKeyEpoch,
    required this.manifestRevision,
    required this.chunkCount,
    required this.totalCiphertextBytes,
    required this.manifestCiphertext,
    required this.manifestCiphertextBytes,
    required this.manifestCiphertextDigest,
    required this.chunks,
    required this.committedAt,
  });

  static const _jsonKeys = <String>{
    'attachmentId',
    'uploadId',
    'chunkKeyEpoch',
    'manifestKeyEpoch',
    'manifestRevision',
    'chunkCount',
    'totalCiphertextBytes',
    'manifestCiphertext',
    'manifestCiphertextBytes',
    'manifestCiphertextDigest',
    'chunks',
    'committedAt',
  };

  final String attachmentId;
  final String uploadId;
  final int chunkKeyEpoch;
  final int manifestKeyEpoch;
  final int manifestRevision;
  final int chunkCount;
  final int totalCiphertextBytes;
  final Uint8List manifestCiphertext;
  final int manifestCiphertextBytes;
  final Uint8List manifestCiphertextDigest;
  final List<CloudSyncDataRekeySourceAttachmentChunk> chunks;
  final DateTime committedAt;

  CloudSyncDataRekeyAttachmentCursor get cursor =>
      CloudSyncDataRekeyAttachmentCursor(
        attachmentId: attachmentId,
        uploadId: uploadId,
      );
}

final class CloudSyncDataRekeySourceAttachmentPage {
  factory CloudSyncDataRekeySourceAttachmentPage.fromJson(
    CloudSyncJsonMap json, {
    required CloudSyncDataRekeySourceAttachmentListRequest request,
  }) {
    _requireExactKeys(json, _jsonKeys, 'data-rekey 源附件分页');
    final rawAttachments = json['attachments'];
    if (rawAttachments is! List<Object?> ||
        rawAttachments.length > request.limit) {
      throw const FormatException('data-rekey 源附件分页数量无效');
    }
    final attachments = rawAttachments
        .map(
          (attachment) => CloudSyncDataRekeySourceAttachment.fromJson(
            copyCloudSyncJsonMap(attachment),
            request: request,
          ),
        )
        .toList(growable: false);
    var previousCursor = request.afterCursor;
    for (final attachment in attachments) {
      final cursor = attachment.cursor;
      if (previousCursor != null &&
          _compareDataRekeyAttachmentCursor(cursor, previousCursor) <= 0) {
        throw const FormatException('data-rekey 源附件分页顺序无效');
      }
      previousCursor = cursor;
    }
    final nextAttachmentId = _optionalCanonicalUuid(
      json,
      'nextAfterAttachmentId',
    );
    final nextUploadId = _optionalCanonicalUuid(json, 'nextAfterUploadId');
    if ((nextAttachmentId == null) != (nextUploadId == null)) {
      throw const FormatException('data-rekey 源附件分页游标不完整');
    }
    final nextCursor = nextAttachmentId == null
        ? null
        : CloudSyncDataRekeyAttachmentCursor(
            attachmentId: nextAttachmentId,
            uploadId: nextUploadId!,
          );
    final hasMore = _requireBool(json, 'hasMore');
    if (hasMore
        ? attachments.isEmpty ||
              nextCursor == null ||
              _compareDataRekeyAttachmentCursor(
                    nextCursor,
                    attachments.last.cursor,
                  ) !=
                  0
        : nextCursor != null) {
      throw const FormatException('data-rekey 源附件分页游标无效');
    }
    return CloudSyncDataRekeySourceAttachmentPage._(
      attachments: List<CloudSyncDataRekeySourceAttachment>.unmodifiable(
        attachments,
      ),
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }

  const CloudSyncDataRekeySourceAttachmentPage._({
    required this.attachments,
    required this.nextCursor,
    required this.hasMore,
  });

  static const _jsonKeys = <String>{
    'attachments',
    'nextAfterAttachmentId',
    'nextAfterUploadId',
    'hasMore',
  };

  final List<CloudSyncDataRekeySourceAttachment> attachments;
  final CloudSyncDataRekeyAttachmentCursor? nextCursor;
  final bool hasMore;
}

int _compareDataRekeyAttachmentCursor(
  CloudSyncDataRekeyAttachmentCursor left,
  CloudSyncDataRekeyAttachmentCursor right,
) {
  final attachmentOrder = left.attachmentId.compareTo(right.attachmentId);
  return attachmentOrder == 0
      ? left.uploadId.compareTo(right.uploadId)
      : attachmentOrder;
}

final class CloudSyncDataRekeyRecordStageRequest {
  factory CloudSyncDataRekeyRecordStageRequest({
    required CloudSyncDataRekeyActiveLease activeLease,
    required String mutationId,
    required String sourceRecordId,
    required String targetRecordId,
    required int sourceRevision,
    required Uint8List ciphertext,
  }) {
    final checkedSourceRecordId = _requireCanonicalUuid(
      sourceRecordId,
      'sourceRecordId',
    );
    final checkedTargetRecordId = _requireCanonicalUuid(
      targetRecordId,
      'targetRecordId',
    );
    if (checkedSourceRecordId == checkedTargetRecordId) {
      throw const FormatException('data-rekey 新旧 recordId 必须不同');
    }
    return CloudSyncDataRekeyRecordStageRequest._(
      activeLease: activeLease,
      mutationId: _requireCanonicalUuid(mutationId, 'mutationId'),
      sourceRecordId: checkedSourceRecordId,
      targetRecordId: checkedTargetRecordId,
      sourceRevision: _requirePositiveUint32(sourceRevision, 'sourceRevision'),
      ciphertext: _copyBoundedBytes(ciphertext, 1048576, 'ciphertext'),
    );
  }

  const CloudSyncDataRekeyRecordStageRequest._({
    required this.activeLease,
    required this.mutationId,
    required this.sourceRecordId,
    required this.targetRecordId,
    required this.sourceRevision,
    required this.ciphertext,
  });

  final CloudSyncDataRekeyActiveLease activeLease;
  final String mutationId;
  final String sourceRecordId;
  final String targetRecordId;
  final int sourceRevision;
  final Uint8List ciphertext;
  int get envelopeVersion => 1;
}

final class CloudSyncDataRekeyRecordStageResult {
  factory CloudSyncDataRekeyRecordStageResult.fromJson(
    CloudSyncJsonMap json, {
    required CloudSyncDataRekeyRecordStageRequest request,
  }) {
    _requireExactKeys(json, _jsonKeys, 'data-rekey 记录暂存回执');
    if (_requireString(json, 'result') != 'staged' ||
        _requireString(json, 'operationId') !=
            request.activeLease.operation.operationId ||
        _requireString(json, 'mutationId') != request.mutationId ||
        _requireString(json, 'sourceRecordId') != request.sourceRecordId ||
        _requireString(json, 'targetRecordId') != request.targetRecordId ||
        _requireInt(json, 'leaseVersion') != request.activeLease.leaseVersion) {
      throw const FormatException('data-rekey 记录暂存回执未绑定请求');
    }
    return CloudSyncDataRekeyRecordStageResult._(
      operationId: request.activeLease.operation.operationId,
      mutationId: request.mutationId,
      sourceRecordId: request.sourceRecordId,
      targetRecordId: request.targetRecordId,
      leaseVersion: request.activeLease.leaseVersion,
    );
  }

  const CloudSyncDataRekeyRecordStageResult._({
    required this.operationId,
    required this.mutationId,
    required this.sourceRecordId,
    required this.targetRecordId,
    required this.leaseVersion,
  });

  static const _jsonKeys = <String>{
    'result',
    'operationId',
    'mutationId',
    'sourceRecordId',
    'targetRecordId',
    'leaseVersion',
  };

  final String operationId;
  final String mutationId;
  final String sourceRecordId;
  final String targetRecordId;
  final int leaseVersion;
}

final class CloudSyncDataRekeyAttachmentStageRequest {
  factory CloudSyncDataRekeyAttachmentStageRequest({
    required CloudSyncDataRekeyActiveLease activeLease,
    required String mutationId,
    required String attachmentId,
    required String uploadId,
    required int sourceManifestRevision,
    required Uint8List manifestCiphertext,
  }) {
    final checkedSourceManifestRevision = _requirePositiveUint32(
      sourceManifestRevision,
      'sourceManifestRevision',
    );
    if (checkedSourceManifestRevision == 0xffffffff) {
      throw const FormatException('data-rekey 源 manifest 版本已耗尽');
    }
    return CloudSyncDataRekeyAttachmentStageRequest._(
      activeLease: activeLease,
      mutationId: _requireCanonicalUuid(mutationId, 'mutationId'),
      attachmentId: _requireCanonicalUuid(attachmentId, 'attachmentId'),
      uploadId: _requireCanonicalUuid(uploadId, 'uploadId'),
      sourceManifestRevision: checkedSourceManifestRevision,
      manifestCiphertext: _copyBoundedBytes(
        manifestCiphertext,
        1048576,
        'manifestCiphertext',
      ),
    );
  }

  const CloudSyncDataRekeyAttachmentStageRequest._({
    required this.activeLease,
    required this.mutationId,
    required this.attachmentId,
    required this.uploadId,
    required this.sourceManifestRevision,
    required this.manifestCiphertext,
  });

  final CloudSyncDataRekeyActiveLease activeLease;
  final String mutationId;
  final String attachmentId;
  final String uploadId;
  final int sourceManifestRevision;
  final Uint8List manifestCiphertext;
  int get manifestKeyEpoch => activeLease.operation.targetKeyEpoch;
  int get manifestRevision => sourceManifestRevision + 1;
}

final class CloudSyncDataRekeyAttachmentStageResult {
  factory CloudSyncDataRekeyAttachmentStageResult.fromJson(
    CloudSyncJsonMap json, {
    required CloudSyncDataRekeyAttachmentStageRequest request,
  }) {
    _requireExactKeys(json, _jsonKeys, 'data-rekey 附件暂存回执');
    if (_requireString(json, 'result') != 'staged' ||
        _requireString(json, 'operationId') !=
            request.activeLease.operation.operationId ||
        _requireString(json, 'mutationId') != request.mutationId ||
        _requireString(json, 'attachmentId') != request.attachmentId ||
        _requireString(json, 'uploadId') != request.uploadId ||
        _requireInt(json, 'manifestRevision') != request.manifestRevision ||
        _requireInt(json, 'leaseVersion') != request.activeLease.leaseVersion) {
      throw const FormatException('data-rekey 附件暂存回执未绑定请求');
    }
    return CloudSyncDataRekeyAttachmentStageResult._(
      operationId: request.activeLease.operation.operationId,
      mutationId: request.mutationId,
      attachmentId: request.attachmentId,
      uploadId: request.uploadId,
      manifestRevision: request.manifestRevision,
      leaseVersion: request.activeLease.leaseVersion,
    );
  }

  const CloudSyncDataRekeyAttachmentStageResult._({
    required this.operationId,
    required this.mutationId,
    required this.attachmentId,
    required this.uploadId,
    required this.manifestRevision,
    required this.leaseVersion,
  });

  static const _jsonKeys = <String>{
    'result',
    'operationId',
    'mutationId',
    'attachmentId',
    'uploadId',
    'manifestRevision',
    'leaseVersion',
  };

  final String operationId;
  final String mutationId;
  final String attachmentId;
  final String uploadId;
  final int manifestRevision;
  final int leaseVersion;
}

final class CloudSyncDataRekeyFinalizeProof {
  factory CloudSyncDataRekeyFinalizeProof({
    required String issuerDeviceId,
    required Uint8List sourceSnapshotRoot,
    required int sourceRecordCount,
    required int sourceAttachmentCount,
    required int sourceMaximumChangeSeq,
    required String? sourceRecordCursorEnd,
    required CloudSyncDataRekeyAttachmentCursor? sourceAttachmentCursorEnd,
    required int membershipGeneration,
    required Uint8List membershipManifestDigest,
    required int stagedRecordCount,
    required int stagedAttachmentCount,
    required Uint8List stagedCiphertextSetDigest,
    required Uint8List signature,
  }) {
    final checkedSourceRecordCount = _requireNonNegativeInt32(
      sourceRecordCount,
      'sourceRecordCount',
    );
    final checkedSourceAttachmentCount = _requireNonNegativeInt32(
      sourceAttachmentCount,
      'sourceAttachmentCount',
    );
    final checkedStagedRecordCount = _requireNonNegativeInt32(
      stagedRecordCount,
      'stagedRecordCount',
    );
    final checkedStagedAttachmentCount = _requireNonNegativeInt32(
      stagedAttachmentCount,
      'stagedAttachmentCount',
    );
    if (checkedSourceRecordCount != checkedStagedRecordCount ||
        checkedSourceAttachmentCount != checkedStagedAttachmentCount) {
      throw const FormatException('data-rekey 最终证明暂存数量不完整');
    }
    final checkedSourceRecordCursorEnd = sourceRecordCursorEnd == null
        ? null
        : _requireCanonicalUuid(sourceRecordCursorEnd, 'sourceRecordCursorEnd');
    _requireCountCursorPair(
      count: checkedSourceRecordCount,
      hasCursor: checkedSourceRecordCursorEnd != null,
      field: 'sourceRecordCursorEnd',
    );
    _requireCountCursorPair(
      count: checkedSourceAttachmentCount,
      hasCursor: sourceAttachmentCursorEnd != null,
      field: 'sourceAttachmentCursorEnd',
    );
    return CloudSyncDataRekeyFinalizeProof._(
      issuerDeviceId: _requireCanonicalUuid(issuerDeviceId, 'issuerDeviceId'),
      sourceSnapshotRoot: _copyFixedBytes(
        sourceSnapshotRoot,
        cloudSyncDataRekeyDigestBytes,
        'sourceSnapshotRoot',
      ),
      sourceRecordCount: checkedSourceRecordCount,
      sourceAttachmentCount: checkedSourceAttachmentCount,
      sourceMaximumChangeSeq: _requireNonNegativeSafeInteger(
        sourceMaximumChangeSeq,
        'sourceMaximumChangeSeq',
      ),
      sourceRecordCursorEnd: checkedSourceRecordCursorEnd,
      sourceAttachmentCursorEnd: sourceAttachmentCursorEnd,
      membershipGeneration: _requirePositiveInt32(
        membershipGeneration,
        'membershipGeneration',
      ),
      membershipManifestDigest: _copyFixedBytes(
        membershipManifestDigest,
        cloudSyncDataRekeyDigestBytes,
        'membershipManifestDigest',
      ),
      stagedRecordCount: checkedStagedRecordCount,
      stagedAttachmentCount: checkedStagedAttachmentCount,
      stagedCiphertextSetDigest: _copyFixedBytes(
        stagedCiphertextSetDigest,
        cloudSyncDataRekeyDigestBytes,
        'stagedCiphertextSetDigest',
      ),
      signature: _copyFixedBytes(
        signature,
        cloudSyncDeviceProofBytes,
        'signature',
      ),
    );
  }

  const CloudSyncDataRekeyFinalizeProof._({
    required this.issuerDeviceId,
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
    required this.signature,
  });

  final String issuerDeviceId;
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
  final Uint8List signature;
  int get proofVersion => 2;
}

final class CloudSyncDataRekeyFinalizeRequest {
  factory CloudSyncDataRekeyFinalizeRequest({
    required CloudSyncDataRekeyActiveLease activeLease,
    required String mutationId,
    required CloudSyncDataRekeyFinalizeProof proof,
  }) {
    if (activeLease.operation.sourceDataGeneration == 0x7fffffff) {
      throw const FormatException('data-rekey 数据代次已耗尽');
    }
    return CloudSyncDataRekeyFinalizeRequest._(
      activeLease: activeLease,
      mutationId: _requireCanonicalUuid(mutationId, 'mutationId'),
      proof: proof,
    );
  }

  const CloudSyncDataRekeyFinalizeRequest._({
    required this.activeLease,
    required this.mutationId,
    required this.proof,
  });

  final CloudSyncDataRekeyActiveLease activeLease;
  final String mutationId;
  final CloudSyncDataRekeyFinalizeProof proof;
  int get targetDataGeneration =>
      activeLease.operation.sourceDataGeneration + 1;
}

final class CloudSyncDataRekeyFinalizeResult {
  factory CloudSyncDataRekeyFinalizeResult.fromJson(
    CloudSyncJsonMap json, {
    required CloudSyncDataRekeyFinalizeRequest request,
  }) {
    _requireExactKeys(json, _jsonKeys, 'data-rekey 最终提交回执');
    if (_requireString(json, 'result') != 'finalized') {
      throw const FormatException('data-rekey 最终提交结果无效');
    }
    final dataGeneration = _requirePositiveInt32(
      _requireInt(json, 'dataGeneration'),
      'dataGeneration',
    );
    final dataKeyEpoch = _requirePositiveUint32(
      _requireInt(json, 'dataKeyEpoch'),
      'dataKeyEpoch',
    );
    final changeWatermark = _requireNonNegativeSafeInteger(
      _requireInt(json, 'changeWatermark'),
      'changeWatermark',
    );
    if (dataGeneration != request.targetDataGeneration ||
        dataKeyEpoch != request.activeLease.operation.targetKeyEpoch ||
        changeWatermark < request.proof.sourceMaximumChangeSeq) {
      throw const FormatException('data-rekey 最终提交回执未绑定目标状态');
    }
    final completion = CloudSyncDataRekeyCompletion.fromJson(
      copyCloudSyncJsonMap(json['completion']),
    );
    if (!_completionMatchesRequest(completion, request)) {
      throw const FormatException('data-rekey 完成证明未绑定提交请求');
    }
    return CloudSyncDataRekeyFinalizeResult._(
      dataGeneration: dataGeneration,
      dataKeyEpoch: dataKeyEpoch,
      changeWatermark: changeWatermark,
      completion: completion,
    );
  }

  const CloudSyncDataRekeyFinalizeResult._({
    required this.dataGeneration,
    required this.dataKeyEpoch,
    required this.changeWatermark,
    required this.completion,
  });

  static const _jsonKeys = <String>{
    'result',
    'dataGeneration',
    'dataKeyEpoch',
    'changeWatermark',
    'completion',
  };

  final int dataGeneration;
  final int dataKeyEpoch;
  final int changeWatermark;
  final CloudSyncDataRekeyCompletion completion;
}

bool _completionMatchesRequest(
  CloudSyncDataRekeyCompletion completion,
  CloudSyncDataRekeyFinalizeRequest request,
) {
  final operation = request.activeLease.operation;
  final proof = request.proof;
  return completion.proofVersion == proof.proofVersion &&
      completion.operationId == operation.operationId &&
      completion.issuerDeviceId == proof.issuerDeviceId &&
      completion.sourceDataGeneration == operation.sourceDataGeneration &&
      completion.targetDataGeneration == request.targetDataGeneration &&
      completion.sourceKeyEpoch == operation.sourceKeyEpoch &&
      completion.targetKeyEpoch == operation.targetKeyEpoch &&
      _sameBytes(completion.sourceSnapshotRoot, proof.sourceSnapshotRoot) &&
      completion.sourceRecordCount == proof.sourceRecordCount &&
      completion.sourceAttachmentCount == proof.sourceAttachmentCount &&
      completion.sourceMaximumChangeSeq == proof.sourceMaximumChangeSeq &&
      completion.sourceRecordCursorEnd == proof.sourceRecordCursorEnd &&
      _sameDataRekeyAttachmentCursor(
        completion.sourceAttachmentCursorEnd,
        proof.sourceAttachmentCursorEnd,
      ) &&
      completion.membershipGeneration == proof.membershipGeneration &&
      _sameBytes(
        completion.membershipManifestDigest,
        proof.membershipManifestDigest,
      ) &&
      completion.stagedRecordCount == proof.stagedRecordCount &&
      completion.stagedAttachmentCount == proof.stagedAttachmentCount &&
      _sameBytes(
        completion.stagedCiphertextSetDigest,
        proof.stagedCiphertextSetDigest,
      ) &&
      _sameBytes(completion.signature, proof.signature);
}

bool _sameDataRekeyAttachmentCursor(
  CloudSyncDataRekeyAttachmentCursor? left,
  CloudSyncDataRekeyAttachmentCursor? right,
) {
  return left == null
      ? right == null
      : right != null &&
            left.attachmentId == right.attachmentId &&
            left.uploadId == right.uploadId;
}

Uint8List _sha256DataRekeyCiphertext(Uint8List ciphertext) {
  return Uint8List.fromList(sha256.convert(ciphertext).bytes);
}
