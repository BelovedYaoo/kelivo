import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

const e2eeDataRekeyDigestBytes = 32;
const e2eeDataRekeyCompletionFrameBytes = 270;
const e2eeDataRekeyCompletionSignatureBytes = 64;
const e2eeDataRekeySourceRecordFrameBytes = 77;
const e2eeDataRekeySourceAttachmentHeaderBytes = 96;
const e2eeDataRekeySourceAttachmentChunkFrameBytes = 44;
const e2eeDataRekeyStagedFrameBytes = 84;

const _maximumSafeInteger = 9007199254740991;

final _canonicalUuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final _completionDomain = Uint8List.fromList(
  ascii.encode('kelivo-data-rekey-completion-v2\u0000'),
);
final _completionDigestDomain = Uint8List.fromList(
  ascii.encode('kelivo-data-rekey-completion-proof-digest-v2\u0000'),
);
final _sourceSnapshotDomain = Uint8List.fromList(
  ascii.encode('kelivo-data-rekey-source-snapshot-v2\u0000'),
);
final _stagedSetDomain = Uint8List.fromList(
  ascii.encode('kelivo-data-rekey-staged-set-v1\u0000'),
);

final class E2eeDataRekeyAttachmentCursor {
  factory E2eeDataRekeyAttachmentCursor({
    required String attachmentId,
    required String uploadId,
  }) {
    return E2eeDataRekeyAttachmentCursor._(
      attachmentId: _requireCanonicalUuid(attachmentId, 'attachmentId'),
      uploadId: _requireCanonicalUuid(uploadId, 'uploadId'),
    );
  }

  const E2eeDataRekeyAttachmentCursor._({
    required this.attachmentId,
    required this.uploadId,
  });

  final String attachmentId;
  final String uploadId;
}

final class E2eeDataRekeySourceHeaderFields {
  factory E2eeDataRekeySourceHeaderFields({
    required String userId,
    required String operationId,
    required int sourceDataGeneration,
    required int sourceKeyEpoch,
    required int expectedRecordCount,
    required int expectedAttachmentCount,
    required int expectedMaximumChangeSeq,
  }) {
    return E2eeDataRekeySourceHeaderFields._(
      userId: _requireCanonicalUuid(userId, 'userId'),
      operationId: _requireCanonicalUuid(operationId, 'operationId'),
      sourceDataGeneration: _requireUint32(
        sourceDataGeneration,
        'sourceDataGeneration',
      ),
      sourceKeyEpoch: _requireUint32(sourceKeyEpoch, 'sourceKeyEpoch'),
      expectedRecordCount: _requireUint32(
        expectedRecordCount,
        'expectedRecordCount',
      ),
      expectedAttachmentCount: _requireUint32(
        expectedAttachmentCount,
        'expectedAttachmentCount',
      ),
      expectedMaximumChangeSeq: _requireUint64(
        expectedMaximumChangeSeq,
        'expectedMaximumChangeSeq',
      ),
    );
  }

  const E2eeDataRekeySourceHeaderFields._({
    required this.userId,
    required this.operationId,
    required this.sourceDataGeneration,
    required this.sourceKeyEpoch,
    required this.expectedRecordCount,
    required this.expectedAttachmentCount,
    required this.expectedMaximumChangeSeq,
  });

  final String userId;
  final String operationId;
  final int sourceDataGeneration;
  final int sourceKeyEpoch;
  final int expectedRecordCount;
  final int expectedAttachmentCount;
  final int expectedMaximumChangeSeq;
}

final class E2eeDataRekeySourceRecordDigestItem {
  factory E2eeDataRekeySourceRecordDigestItem({
    required String recordId,
    required int revision,
    required int envelopeVersion,
    required int keyEpoch,
    required int ciphertextBytes,
    required Uint8List ciphertextDigest,
    required int lastChangeSeq,
  }) {
    return E2eeDataRekeySourceRecordDigestItem._(
      recordId: _requireCanonicalUuid(recordId, 'recordId'),
      revision: _requireUint32(revision, 'revision'),
      envelopeVersion: _requireUint32(envelopeVersion, 'envelopeVersion'),
      keyEpoch: _requireUint32(keyEpoch, 'keyEpoch'),
      ciphertextBytes: _requireUint64(ciphertextBytes, 'ciphertextBytes'),
      ciphertextDigest: _copyDigest(ciphertextDigest, 'ciphertextDigest'),
      lastChangeSeq: _requireUint64(lastChangeSeq, 'lastChangeSeq'),
    );
  }

  const E2eeDataRekeySourceRecordDigestItem._({
    required this.recordId,
    required this.revision,
    required this.envelopeVersion,
    required this.keyEpoch,
    required this.ciphertextBytes,
    required this.ciphertextDigest,
    required this.lastChangeSeq,
  });

  final String recordId;
  final int revision;
  final int envelopeVersion;
  final int keyEpoch;
  final int ciphertextBytes;
  final Uint8List ciphertextDigest;
  final int lastChangeSeq;
}

final class E2eeDataRekeySourceAttachmentChunkDigestItem {
  factory E2eeDataRekeySourceAttachmentChunkDigestItem({
    required int chunkIndex,
    required int ciphertextBytes,
    required Uint8List ciphertextDigest,
  }) {
    return E2eeDataRekeySourceAttachmentChunkDigestItem._(
      chunkIndex: _requireUint32(chunkIndex, 'chunkIndex'),
      ciphertextBytes: _requireUint64(ciphertextBytes, 'ciphertextBytes'),
      ciphertextDigest: _copyDigest(ciphertextDigest, 'ciphertextDigest'),
    );
  }

  const E2eeDataRekeySourceAttachmentChunkDigestItem._({
    required this.chunkIndex,
    required this.ciphertextBytes,
    required this.ciphertextDigest,
  });

  final int chunkIndex;
  final int ciphertextBytes;
  final Uint8List ciphertextDigest;
}

final class E2eeDataRekeySourceAttachmentDigestItem {
  factory E2eeDataRekeySourceAttachmentDigestItem({
    required String attachmentId,
    required String uploadId,
    required int chunkKeyEpoch,
    required int manifestKeyEpoch,
    required int manifestRevision,
    required int chunkCount,
    required int totalCiphertextBytes,
    required int manifestCiphertextBytes,
    required Uint8List manifestCiphertextDigest,
    required List<E2eeDataRekeySourceAttachmentChunkDigestItem> chunks,
  }) {
    final checkedChunkCount = _requireUint32(chunkCount, 'chunkCount');
    final checkedTotalCiphertextBytes = _requireUint64(
      totalCiphertextBytes,
      'totalCiphertextBytes',
    );
    final copiedChunks =
        List<E2eeDataRekeySourceAttachmentChunkDigestItem>.unmodifiable(chunks);
    if (copiedChunks.length != checkedChunkCount) {
      throw const FormatException('chunks 数量与 chunkCount 不一致');
    }
    var accumulatedCiphertextBytes = 0;
    for (var index = 0; index < copiedChunks.length; index++) {
      final chunk = copiedChunks[index];
      if (chunk.chunkIndex != index) {
        throw const FormatException('chunks 索引必须从零连续递增');
      }
      accumulatedCiphertextBytes = _addUint64(
        accumulatedCiphertextBytes,
        chunk.ciphertextBytes,
        'totalCiphertextBytes',
      );
    }
    if (accumulatedCiphertextBytes != checkedTotalCiphertextBytes) {
      throw const FormatException('chunks 密文字节总数不一致');
    }
    return E2eeDataRekeySourceAttachmentDigestItem._(
      attachmentId: _requireCanonicalUuid(attachmentId, 'attachmentId'),
      uploadId: _requireCanonicalUuid(uploadId, 'uploadId'),
      chunkKeyEpoch: _requireUint32(chunkKeyEpoch, 'chunkKeyEpoch'),
      manifestKeyEpoch: _requireUint32(manifestKeyEpoch, 'manifestKeyEpoch'),
      manifestRevision: _requireUint32(manifestRevision, 'manifestRevision'),
      chunkCount: checkedChunkCount,
      totalCiphertextBytes: checkedTotalCiphertextBytes,
      manifestCiphertextBytes: _requireUint64(
        manifestCiphertextBytes,
        'manifestCiphertextBytes',
      ),
      manifestCiphertextDigest: _copyDigest(
        manifestCiphertextDigest,
        'manifestCiphertextDigest',
      ),
      chunks: copiedChunks,
    );
  }

  const E2eeDataRekeySourceAttachmentDigestItem._({
    required this.attachmentId,
    required this.uploadId,
    required this.chunkKeyEpoch,
    required this.manifestKeyEpoch,
    required this.manifestRevision,
    required this.chunkCount,
    required this.totalCiphertextBytes,
    required this.manifestCiphertextBytes,
    required this.manifestCiphertextDigest,
    required this.chunks,
  });

  final String attachmentId;
  final String uploadId;
  final int chunkKeyEpoch;
  final int manifestKeyEpoch;
  final int manifestRevision;
  final int chunkCount;
  final int totalCiphertextBytes;
  final int manifestCiphertextBytes;
  final Uint8List manifestCiphertextDigest;
  final List<E2eeDataRekeySourceAttachmentChunkDigestItem> chunks;

  E2eeDataRekeyAttachmentCursor get cursor => E2eeDataRekeyAttachmentCursor(
    attachmentId: attachmentId,
    uploadId: uploadId,
  );
}

final class E2eeDataRekeySourceSnapshot {
  const E2eeDataRekeySourceSnapshot._({
    required this.root,
    required this.recordCount,
    required this.attachmentCount,
    required this.maximumChangeSeq,
    required this.recordCursorEnd,
    required this.attachmentCursorEnd,
  });

  final Uint8List root;
  final int recordCount;
  final int attachmentCount;
  final int maximumChangeSeq;
  final String? recordCursorEnd;
  final E2eeDataRekeyAttachmentCursor? attachmentCursorEnd;
}

final class E2eeDataRekeySourceSnapshotAccumulator {
  E2eeDataRekeySourceSnapshotAccumulator(this._header) {
    _digest.add(buildE2eeDataRekeySourceHeader(_header));
  }

  final E2eeDataRekeySourceHeaderFields _header;
  final _DigestAccumulator _digest = _DigestAccumulator();

  int _recordCount = 0;
  int _attachmentCount = 0;
  int _maximumChangeSeq = 0;
  String? _recordCursorEnd;
  E2eeDataRekeyAttachmentCursor? _attachmentCursorEnd;
  bool _attachmentPhaseStarted = false;

  void addRecord(E2eeDataRekeySourceRecordDigestItem record) {
    if (_attachmentPhaseStarted) {
      throw const FormatException('冻结源附件阶段开始后不得追加记录');
    }
    if (_recordCount >= _header.expectedRecordCount) {
      throw const FormatException('冻结源记录数量超过声明');
    }
    final previous = _recordCursorEnd;
    if (previous != null && previous.compareTo(record.recordId) >= 0) {
      throw const FormatException('冻结源记录游标必须严格递增');
    }
    _digest.add(buildE2eeDataRekeySourceRecordFrame(record));
    _recordCount += 1;
    _recordCursorEnd = record.recordId;
    if (record.lastChangeSeq > _maximumChangeSeq) {
      _maximumChangeSeq = record.lastChangeSeq;
    }
  }

  void addAttachment(E2eeDataRekeySourceAttachmentDigestItem attachment) {
    if (_recordCount != _header.expectedRecordCount) {
      throw const FormatException('冻结源记录尚未完整，不能进入附件阶段');
    }
    _attachmentPhaseStarted = true;
    if (_attachmentCount >= _header.expectedAttachmentCount) {
      throw const FormatException('冻结源附件数量超过声明');
    }
    final previous = _attachmentCursorEnd;
    final cursor = attachment.cursor;
    if (previous != null && _compareAttachmentCursor(previous, cursor) >= 0) {
      throw const FormatException('冻结源附件游标必须严格递增');
    }
    _digest.add(buildE2eeDataRekeySourceAttachmentFrame(attachment));
    _attachmentCount += 1;
    _attachmentCursorEnd = cursor;
  }

  E2eeDataRekeySourceSnapshot finish() {
    if (_recordCount != _header.expectedRecordCount ||
        _attachmentCount != _header.expectedAttachmentCount) {
      throw const FormatException('冻结源快照数量与声明不一致');
    }
    if (_maximumChangeSeq != _header.expectedMaximumChangeSeq) {
      throw const FormatException('冻结源快照最大 changeSeq 与声明不一致');
    }
    return E2eeDataRekeySourceSnapshot._(
      root: _digest.finish(),
      recordCount: _recordCount,
      attachmentCount: _attachmentCount,
      maximumChangeSeq: _maximumChangeSeq,
      recordCursorEnd: _recordCursorEnd,
      attachmentCursorEnd: _attachmentCursorEnd,
    );
  }
}

final class E2eeDataRekeyStagedRecordDigestItem {
  factory E2eeDataRekeyStagedRecordDigestItem({
    required String sourceRecordId,
    required String targetRecordId,
    required int sourceRevision,
    required int targetKeyEpoch,
    required int envelopeVersion,
    required int ciphertextBytes,
    required Uint8List ciphertextDigest,
  }) {
    return E2eeDataRekeyStagedRecordDigestItem._(
      sourceRecordId: _requireCanonicalUuid(sourceRecordId, 'sourceRecordId'),
      targetRecordId: _requireCanonicalUuid(targetRecordId, 'targetRecordId'),
      sourceRevision: _requireUint32(sourceRevision, 'sourceRevision'),
      targetKeyEpoch: _requireUint32(targetKeyEpoch, 'targetKeyEpoch'),
      envelopeVersion: _requireUint32(envelopeVersion, 'envelopeVersion'),
      ciphertextBytes: _requireUint64(ciphertextBytes, 'ciphertextBytes'),
      ciphertextDigest: _copyDigest(ciphertextDigest, 'ciphertextDigest'),
    );
  }

  const E2eeDataRekeyStagedRecordDigestItem._({
    required this.sourceRecordId,
    required this.targetRecordId,
    required this.sourceRevision,
    required this.targetKeyEpoch,
    required this.envelopeVersion,
    required this.ciphertextBytes,
    required this.ciphertextDigest,
  });

  final String sourceRecordId;
  final String targetRecordId;
  final int sourceRevision;
  final int targetKeyEpoch;
  final int envelopeVersion;
  final int ciphertextBytes;
  final Uint8List ciphertextDigest;
}

final class E2eeDataRekeyStagedAttachmentDigestItem {
  factory E2eeDataRekeyStagedAttachmentDigestItem({
    required String attachmentId,
    required String uploadId,
    required int sourceManifestRevision,
    required int manifestRevision,
    required int manifestKeyEpoch,
    required int manifestCiphertextBytes,
    required Uint8List manifestCiphertextDigest,
  }) {
    return E2eeDataRekeyStagedAttachmentDigestItem._(
      attachmentId: _requireCanonicalUuid(attachmentId, 'attachmentId'),
      uploadId: _requireCanonicalUuid(uploadId, 'uploadId'),
      sourceManifestRevision: _requireUint32(
        sourceManifestRevision,
        'sourceManifestRevision',
      ),
      manifestRevision: _requireUint32(manifestRevision, 'manifestRevision'),
      manifestKeyEpoch: _requireUint32(manifestKeyEpoch, 'manifestKeyEpoch'),
      manifestCiphertextBytes: _requireUint64(
        manifestCiphertextBytes,
        'manifestCiphertextBytes',
      ),
      manifestCiphertextDigest: _copyDigest(
        manifestCiphertextDigest,
        'manifestCiphertextDigest',
      ),
    );
  }

  const E2eeDataRekeyStagedAttachmentDigestItem._({
    required this.attachmentId,
    required this.uploadId,
    required this.sourceManifestRevision,
    required this.manifestRevision,
    required this.manifestKeyEpoch,
    required this.manifestCiphertextBytes,
    required this.manifestCiphertextDigest,
  });

  final String attachmentId;
  final String uploadId;
  final int sourceManifestRevision;
  final int manifestRevision;
  final int manifestKeyEpoch;
  final int manifestCiphertextBytes;
  final Uint8List manifestCiphertextDigest;
}

final class E2eeDataRekeyStagedCiphertextSetAccumulator {
  E2eeDataRekeyStagedCiphertextSetAccumulator({
    required int expectedRecordCount,
    required int expectedAttachmentCount,
  }) : _expectedRecordCount = _requireUint32(
         expectedRecordCount,
         'expectedRecordCount',
       ),
       _expectedAttachmentCount = _requireUint32(
         expectedAttachmentCount,
         'expectedAttachmentCount',
       ) {
    _digest.add(_stagedSetDomain);
    _digest.add(_uint32Frame(_expectedRecordCount));
  }

  final int _expectedRecordCount;
  final int _expectedAttachmentCount;
  final _DigestAccumulator _digest = _DigestAccumulator();

  int _recordCount = 0;
  int _attachmentCount = 0;
  String? _recordCursorEnd;
  E2eeDataRekeyAttachmentCursor? _attachmentCursorEnd;
  bool _attachmentPhaseStarted = false;

  void addRecord(E2eeDataRekeyStagedRecordDigestItem record) {
    if (_attachmentPhaseStarted) {
      throw const FormatException('暂存附件阶段开始后不得追加记录');
    }
    if (_recordCount >= _expectedRecordCount) {
      throw const FormatException('暂存记录数量超过声明');
    }
    final previous = _recordCursorEnd;
    if (previous != null && previous.compareTo(record.sourceRecordId) >= 0) {
      throw const FormatException('暂存记录游标必须严格递增');
    }
    _digest.add(buildE2eeDataRekeyStagedRecordFrame(record));
    _recordCount += 1;
    _recordCursorEnd = record.sourceRecordId;
  }

  void addAttachment(E2eeDataRekeyStagedAttachmentDigestItem attachment) {
    _beginAttachmentPhase();
    if (_attachmentCount >= _expectedAttachmentCount) {
      throw const FormatException('暂存附件数量超过声明');
    }
    final previous = _attachmentCursorEnd;
    final cursor = E2eeDataRekeyAttachmentCursor(
      attachmentId: attachment.attachmentId,
      uploadId: attachment.uploadId,
    );
    if (previous != null && _compareAttachmentCursor(previous, cursor) >= 0) {
      throw const FormatException('暂存附件游标必须严格递增');
    }
    _digest.add(buildE2eeDataRekeyStagedAttachmentFrame(attachment));
    _attachmentCount += 1;
    _attachmentCursorEnd = cursor;
  }

  Uint8List finish() {
    _beginAttachmentPhase();
    if (_attachmentCount != _expectedAttachmentCount) {
      throw const FormatException('暂存附件数量与声明不一致');
    }
    return _digest.finish();
  }

  void _beginAttachmentPhase() {
    if (_attachmentPhaseStarted) return;
    if (_recordCount != _expectedRecordCount) {
      throw const FormatException('暂存记录尚未完整，不能进入附件阶段');
    }
    _attachmentPhaseStarted = true;
    _digest.add(_uint32Frame(_expectedAttachmentCount));
  }
}

Uint8List buildE2eeDataRekeySourceHeader(
  E2eeDataRekeySourceHeaderFields fields,
) {
  final frame = Uint8List(_sourceSnapshotDomain.length + 56);
  final data = ByteData.sublistView(frame);
  var offset = 0;
  offset = _writeBytes(frame, offset, _sourceSnapshotDomain);
  offset = _writeUuid(frame, offset, fields.userId);
  offset = _writeUuid(frame, offset, fields.operationId);
  offset = _writeUint32(data, offset, fields.sourceDataGeneration);
  offset = _writeUint32(data, offset, fields.sourceKeyEpoch);
  offset = _writeUint32(data, offset, fields.expectedRecordCount);
  offset = _writeUint32(data, offset, fields.expectedAttachmentCount);
  offset = _writeUint64(data, offset, fields.expectedMaximumChangeSeq);
  if (offset != frame.length) {
    throw StateError('data-rekey 冻结源快照头长度不一致');
  }
  return frame.asUnmodifiableView();
}

Uint8List buildE2eeDataRekeySourceRecordFrame(
  E2eeDataRekeySourceRecordDigestItem record,
) {
  final frame = Uint8List(e2eeDataRekeySourceRecordFrameBytes);
  final data = ByteData.sublistView(frame);
  var offset = 0;
  frame[offset++] = 1;
  offset = _writeUuid(frame, offset, record.recordId);
  offset = _writeUint32(data, offset, record.revision);
  offset = _writeUint32(data, offset, record.envelopeVersion);
  offset = _writeUint32(data, offset, record.keyEpoch);
  offset = _writeUint64(data, offset, record.ciphertextBytes);
  offset = _writeBytes(frame, offset, record.ciphertextDigest);
  offset = _writeUint64(data, offset, record.lastChangeSeq);
  if (offset != frame.length) {
    throw StateError('data-rekey 冻结源记录帧长度不一致');
  }
  return frame.asUnmodifiableView();
}

Uint8List buildE2eeDataRekeySourceAttachmentFrame(
  E2eeDataRekeySourceAttachmentDigestItem attachment,
) {
  final frame = Uint8List(
    e2eeDataRekeySourceAttachmentHeaderBytes +
        attachment.chunks.length * e2eeDataRekeySourceAttachmentChunkFrameBytes,
  );
  final data = ByteData.sublistView(frame);
  var offset = 0;
  offset = _writeUuid(frame, offset, attachment.attachmentId);
  offset = _writeUuid(frame, offset, attachment.uploadId);
  offset = _writeUint32(data, offset, attachment.chunkKeyEpoch);
  offset = _writeUint32(data, offset, attachment.manifestKeyEpoch);
  offset = _writeUint32(data, offset, attachment.manifestRevision);
  offset = _writeUint32(data, offset, attachment.chunkCount);
  offset = _writeUint64(data, offset, attachment.totalCiphertextBytes);
  offset = _writeUint64(data, offset, attachment.manifestCiphertextBytes);
  offset = _writeBytes(frame, offset, attachment.manifestCiphertextDigest);
  for (final chunk in attachment.chunks) {
    offset = _writeUint32(data, offset, chunk.chunkIndex);
    offset = _writeUint64(data, offset, chunk.ciphertextBytes);
    offset = _writeBytes(frame, offset, chunk.ciphertextDigest);
  }
  if (offset != frame.length) {
    throw StateError('data-rekey 冻结源附件帧长度不一致');
  }
  return frame.asUnmodifiableView();
}

E2eeDataRekeySourceSnapshot computeE2eeDataRekeySourceSnapshot({
  required E2eeDataRekeySourceHeaderFields header,
  required Iterable<E2eeDataRekeySourceRecordDigestItem> records,
  required Iterable<E2eeDataRekeySourceAttachmentDigestItem> attachments,
}) {
  final sortedRecords = List<E2eeDataRekeySourceRecordDigestItem>.of(records)
    ..sort((left, right) => left.recordId.compareTo(right.recordId));
  final sortedAttachments = List<E2eeDataRekeySourceAttachmentDigestItem>.of(
    attachments,
  )..sort(_compareSourceAttachment);
  final accumulator = E2eeDataRekeySourceSnapshotAccumulator(header);
  for (final record in sortedRecords) {
    accumulator.addRecord(record);
  }
  for (final attachment in sortedAttachments) {
    accumulator.addAttachment(attachment);
  }
  return accumulator.finish();
}

Uint8List buildE2eeDataRekeyStagedRecordFrame(
  E2eeDataRekeyStagedRecordDigestItem record,
) {
  final frame = Uint8List(e2eeDataRekeyStagedFrameBytes);
  final data = ByteData.sublistView(frame);
  var offset = 0;
  offset = _writeUuid(frame, offset, record.sourceRecordId);
  offset = _writeUuid(frame, offset, record.targetRecordId);
  offset = _writeUint32(data, offset, record.sourceRevision);
  offset = _writeUint32(data, offset, record.targetKeyEpoch);
  offset = _writeUint32(data, offset, record.envelopeVersion);
  offset = _writeUint64(data, offset, record.ciphertextBytes);
  offset = _writeBytes(frame, offset, record.ciphertextDigest);
  if (offset != frame.length) {
    throw StateError('data-rekey 暂存记录帧长度不一致');
  }
  return frame.asUnmodifiableView();
}

Uint8List buildE2eeDataRekeyStagedAttachmentFrame(
  E2eeDataRekeyStagedAttachmentDigestItem attachment,
) {
  final frame = Uint8List(e2eeDataRekeyStagedFrameBytes);
  final data = ByteData.sublistView(frame);
  var offset = 0;
  offset = _writeUuid(frame, offset, attachment.attachmentId);
  offset = _writeUuid(frame, offset, attachment.uploadId);
  offset = _writeUint32(data, offset, attachment.sourceManifestRevision);
  offset = _writeUint32(data, offset, attachment.manifestRevision);
  offset = _writeUint32(data, offset, attachment.manifestKeyEpoch);
  offset = _writeUint64(data, offset, attachment.manifestCiphertextBytes);
  offset = _writeBytes(frame, offset, attachment.manifestCiphertextDigest);
  if (offset != frame.length) {
    throw StateError('data-rekey 暂存附件帧长度不一致');
  }
  return frame.asUnmodifiableView();
}

Uint8List computeE2eeDataRekeyStagedCiphertextSetDigest({
  required Iterable<E2eeDataRekeyStagedRecordDigestItem> records,
  required Iterable<E2eeDataRekeyStagedAttachmentDigestItem> attachments,
}) {
  final sortedRecords = List<E2eeDataRekeyStagedRecordDigestItem>.of(
    records,
  )..sort((left, right) => left.sourceRecordId.compareTo(right.sourceRecordId));
  final sortedAttachments = List<E2eeDataRekeyStagedAttachmentDigestItem>.of(
    attachments,
  )..sort(_compareStagedAttachment);
  final accumulator = E2eeDataRekeyStagedCiphertextSetAccumulator(
    expectedRecordCount: sortedRecords.length,
    expectedAttachmentCount: sortedAttachments.length,
  );
  for (final record in sortedRecords) {
    accumulator.addRecord(record);
  }
  for (final attachment in sortedAttachments) {
    accumulator.addAttachment(attachment);
  }
  return accumulator.finish();
}

final class E2eeDataRekeyCompletionFields {
  factory E2eeDataRekeyCompletionFields({
    required String operationId,
    required String userId,
    required String issuerDeviceId,
    required int sourceDataGeneration,
    required int targetDataGeneration,
    required int sourceKeyEpoch,
    required int targetKeyEpoch,
    required Uint8List sourceSnapshotRoot,
    required int sourceRecordCount,
    required int sourceAttachmentCount,
    required int sourceMaximumChangeSeq,
    required String? sourceRecordCursorEnd,
    required E2eeDataRekeyAttachmentCursor? sourceAttachmentCursorEnd,
    required int membershipGeneration,
    required Uint8List membershipManifestDigest,
    required int stagedRecordCount,
    required int stagedAttachmentCount,
    required Uint8List stagedCiphertextSetDigest,
  }) {
    final checkedSourceRecordCount = _requireUint32(
      sourceRecordCount,
      'sourceRecordCount',
    );
    final checkedSourceAttachmentCount = _requireUint32(
      sourceAttachmentCount,
      'sourceAttachmentCount',
    );
    final checkedStagedRecordCount = _requireUint32(
      stagedRecordCount,
      'stagedRecordCount',
    );
    final checkedStagedAttachmentCount = _requireUint32(
      stagedAttachmentCount,
      'stagedAttachmentCount',
    );
    if (checkedSourceRecordCount != checkedStagedRecordCount ||
        checkedSourceAttachmentCount != checkedStagedAttachmentCount) {
      throw const FormatException('source 与 staged 数量必须一致');
    }
    _requireCountCursorPair(
      count: checkedSourceRecordCount,
      hasCursor: sourceRecordCursorEnd != null,
      field: 'sourceRecordCursorEnd',
    );
    _requireCountCursorPair(
      count: checkedSourceAttachmentCount,
      hasCursor: sourceAttachmentCursorEnd != null,
      field: 'sourceAttachmentCursorEnd',
    );
    return E2eeDataRekeyCompletionFields._(
      operationId: _requireCanonicalUuid(operationId, 'operationId'),
      userId: _requireCanonicalUuid(userId, 'userId'),
      issuerDeviceId: _requireCanonicalUuid(issuerDeviceId, 'issuerDeviceId'),
      sourceDataGeneration: _requireUint32(
        sourceDataGeneration,
        'sourceDataGeneration',
      ),
      targetDataGeneration: _requireUint32(
        targetDataGeneration,
        'targetDataGeneration',
      ),
      sourceKeyEpoch: _requireUint32(sourceKeyEpoch, 'sourceKeyEpoch'),
      targetKeyEpoch: _requireUint32(targetKeyEpoch, 'targetKeyEpoch'),
      sourceSnapshotRoot: _copyDigest(sourceSnapshotRoot, 'sourceSnapshotRoot'),
      sourceRecordCount: checkedSourceRecordCount,
      sourceAttachmentCount: checkedSourceAttachmentCount,
      sourceMaximumChangeSeq: _requireUint64(
        sourceMaximumChangeSeq,
        'sourceMaximumChangeSeq',
      ),
      sourceRecordCursorEnd: sourceRecordCursorEnd == null
          ? null
          : _requireCanonicalUuid(
              sourceRecordCursorEnd,
              'sourceRecordCursorEnd',
            ),
      sourceAttachmentCursorEnd: sourceAttachmentCursorEnd,
      membershipGeneration: _requireUint32(
        membershipGeneration,
        'membershipGeneration',
      ),
      membershipManifestDigest: _copyDigest(
        membershipManifestDigest,
        'membershipManifestDigest',
      ),
      stagedRecordCount: checkedStagedRecordCount,
      stagedAttachmentCount: checkedStagedAttachmentCount,
      stagedCiphertextSetDigest: _copyDigest(
        stagedCiphertextSetDigest,
        'stagedCiphertextSetDigest',
      ),
    );
  }

  const E2eeDataRekeyCompletionFields._({
    required this.operationId,
    required this.userId,
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
  });

  final String operationId;
  final String userId;
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
  final E2eeDataRekeyAttachmentCursor? sourceAttachmentCursorEnd;
  final int membershipGeneration;
  final Uint8List membershipManifestDigest;
  final int stagedRecordCount;
  final int stagedAttachmentCount;
  final Uint8List stagedCiphertextSetDigest;
}

Uint8List buildE2eeDataRekeyCompletionFrame(
  E2eeDataRekeyCompletionFields fields,
) {
  final frame = Uint8List(e2eeDataRekeyCompletionFrameBytes);
  final data = ByteData.sublistView(frame);
  var offset = 0;
  offset = _writeBytes(frame, offset, _completionDomain);
  offset = _writeUuid(frame, offset, fields.operationId);
  offset = _writeUuid(frame, offset, fields.userId);
  offset = _writeUuid(frame, offset, fields.issuerDeviceId);
  offset = _writeUint32(data, offset, fields.sourceDataGeneration);
  offset = _writeUint32(data, offset, fields.targetDataGeneration);
  offset = _writeUint32(data, offset, fields.sourceKeyEpoch);
  offset = _writeUint32(data, offset, fields.targetKeyEpoch);
  offset = _writeBytes(frame, offset, fields.sourceSnapshotRoot);
  offset = _writeUint32(data, offset, fields.sourceRecordCount);
  offset = _writeUint32(data, offset, fields.sourceAttachmentCount);
  offset = _writeUint64(data, offset, fields.sourceMaximumChangeSeq);
  offset = _writeNullableUuid(frame, offset, fields.sourceRecordCursorEnd);
  offset = _writeNullableAttachmentCursor(
    frame,
    offset,
    fields.sourceAttachmentCursorEnd,
  );
  offset = _writeUint32(data, offset, fields.membershipGeneration);
  offset = _writeBytes(frame, offset, fields.membershipManifestDigest);
  offset = _writeUint32(data, offset, fields.stagedRecordCount);
  offset = _writeUint32(data, offset, fields.stagedAttachmentCount);
  offset = _writeBytes(frame, offset, fields.stagedCiphertextSetDigest);
  if (offset != frame.length) {
    throw StateError('data-rekey completion 规范帧长度不一致');
  }
  return frame.asUnmodifiableView();
}

Uint8List digestE2eeDataRekeyCompletionProof({
  required Uint8List proofFrame,
  required Uint8List signature,
}) {
  final checkedProofFrame = _copyFixedBytes(
    proofFrame,
    e2eeDataRekeyCompletionFrameBytes,
    'proofFrame',
  );
  final checkedSignature = _copyFixedBytes(
    signature,
    e2eeDataRekeyCompletionSignatureBytes,
    'signature',
  );
  if (!_hasPrefix(checkedProofFrame, _completionDomain)) {
    throw const FormatException('proofFrame 的 data-rekey 域无效');
  }
  final digest = _DigestAccumulator();
  digest.add(_completionDigestDomain);
  digest.add(checkedProofFrame);
  digest.add(checkedSignature);
  return digest.finish();
}

Uint8List digestE2eeDataRekeyCiphertext(Uint8List ciphertext) {
  if (ciphertext.isEmpty) {
    throw const FormatException('data-rekey 密文不得为空');
  }
  final localCiphertext = Uint8List.fromList(ciphertext);
  return Uint8List.fromList(
    sha256.convert(localCiphertext).bytes,
  ).asUnmodifiableView();
}

String _requireCanonicalUuid(String value, String field) {
  if (!_canonicalUuidV4Pattern.hasMatch(value)) {
    throw FormatException('$field 必须为规范的小写 UUID v4');
  }
  return value;
}

int _requireUint32(int value, String field) {
  if (value < 0 || value > 0xffffffff) {
    throw FormatException('$field 必须位于 uint32 范围');
  }
  return value;
}

int _requireUint64(int value, String field) {
  if (value < 0 || value > _maximumSafeInteger) {
    throw FormatException('$field 必须为非负安全整数');
  }
  return value;
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

int _addUint64(int left, int right, String field) {
  if (right > _maximumSafeInteger - left) {
    throw FormatException('$field 必须为非负安全整数');
  }
  return left + right;
}

Uint8List _copyDigest(Uint8List value, String field) {
  return _copyFixedBytes(value, e2eeDataRekeyDigestBytes, field);
}

Uint8List _copyFixedBytes(Uint8List value, int length, String field) {
  if (value.length != length) {
    throw FormatException('$field 必须为 $length 字节');
  }
  return Uint8List.fromList(value).asUnmodifiableView();
}

int _writeUuid(Uint8List target, int offset, String value) {
  return _writeBytes(target, offset, Uuid.parseAsByteList(value));
}

int _writeBytes(Uint8List target, int offset, List<int> value) {
  target.setRange(offset, offset + value.length, value);
  return offset + value.length;
}

int _writeUint32(ByteData target, int offset, int value) {
  target.setUint32(offset, value, Endian.big);
  return offset + 4;
}

int _writeUint64(ByteData target, int offset, int value) {
  target.setUint64(offset, value, Endian.big);
  return offset + 8;
}

Uint8List _uint32Frame(int value) {
  final frame = Uint8List(4);
  ByteData.sublistView(frame).setUint32(0, value, Endian.big);
  return frame;
}

int _writeNullableUuid(Uint8List target, int offset, String? value) {
  target[offset] = value == null ? 0 : 1;
  if (value != null) _writeUuid(target, offset + 1, value);
  return offset + 17;
}

int _writeNullableAttachmentCursor(
  Uint8List target,
  int offset,
  E2eeDataRekeyAttachmentCursor? value,
) {
  target[offset] = value == null ? 0 : 1;
  if (value != null) {
    _writeUuid(target, offset + 1, value.attachmentId);
    _writeUuid(target, offset + 17, value.uploadId);
  }
  return offset + 33;
}

int _compareSourceAttachment(
  E2eeDataRekeySourceAttachmentDigestItem left,
  E2eeDataRekeySourceAttachmentDigestItem right,
) {
  final attachmentOrder = left.attachmentId.compareTo(right.attachmentId);
  return attachmentOrder == 0
      ? left.uploadId.compareTo(right.uploadId)
      : attachmentOrder;
}

int _compareAttachmentCursor(
  E2eeDataRekeyAttachmentCursor left,
  E2eeDataRekeyAttachmentCursor right,
) {
  final attachmentOrder = left.attachmentId.compareTo(right.attachmentId);
  return attachmentOrder == 0
      ? left.uploadId.compareTo(right.uploadId)
      : attachmentOrder;
}

bool _hasPrefix(Uint8List value, Uint8List prefix) {
  if (value.length < prefix.length) return false;
  for (var index = 0; index < prefix.length; index++) {
    if (value[index] != prefix[index]) return false;
  }
  return true;
}

int _compareStagedAttachment(
  E2eeDataRekeyStagedAttachmentDigestItem left,
  E2eeDataRekeyStagedAttachmentDigestItem right,
) {
  final attachmentOrder = left.attachmentId.compareTo(right.attachmentId);
  return attachmentOrder == 0
      ? left.uploadId.compareTo(right.uploadId)
      : attachmentOrder;
}

final class _DigestAccumulator {
  _DigestAccumulator() {
    _sink = sha256.startChunkedConversion(_output);
  }

  final _SingleDigestSink _output = _SingleDigestSink();
  late final ByteConversionSink _sink;
  bool _finished = false;

  void add(Uint8List value) {
    if (_finished) throw StateError('data-rekey 摘要已完成');
    _sink.add(value);
  }

  Uint8List finish() {
    if (_finished) throw StateError('data-rekey 摘要已完成');
    _finished = true;
    _sink.close();
    final value = _output.value ?? (throw StateError('data-rekey 摘要未生成'));
    return Uint8List.fromList(value.bytes).asUnmodifiableView();
  }
}

final class _SingleDigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) {
    if (value != null) throw StateError('data-rekey 摘要重复完成');
    value = data;
  }

  @override
  void close() {}
}
