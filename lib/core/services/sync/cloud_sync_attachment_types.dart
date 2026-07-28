import 'dart:typed_data';

const cloudSyncMaximumAttachmentChunkCount = 1000;
const cloudSyncMaximumAttachmentChunkCiphertextBytes = 4 * 1024 * 1024;
const cloudSyncMaximumAttachmentManifestCiphertextBytes = 1024 * 1024;
const cloudSyncMaximumAttachmentTotalCiphertextBytes =
    cloudSyncMaximumAttachmentChunkCount *
    cloudSyncMaximumAttachmentChunkCiphertextBytes;

final class CloudSyncAttachmentIdentity {
  CloudSyncAttachmentIdentity({
    required String attachmentId,
    required String uploadId,
    required int keyEpoch,
  }) : attachmentId = _requireIdentifier(attachmentId, 'attachmentId'),
       uploadId = _requireIdentifier(uploadId, 'uploadId'),
       keyEpoch = _requirePositiveUint32(keyEpoch, 'keyEpoch');

  final String attachmentId;
  final String uploadId;
  final int keyEpoch;
}

final class CloudSyncAttachmentChunkIdentity {
  CloudSyncAttachmentChunkIdentity({
    required this.identity,
    required int chunkIndex,
  }) : chunkIndex = _requireChunkIndex(chunkIndex);

  final CloudSyncAttachmentIdentity identity;
  final int chunkIndex;
}

final class CloudSyncAttachmentCreateUploadRequest {
  CloudSyncAttachmentCreateUploadRequest({
    required String mutationId,
    required String attachmentId,
    required int keyEpoch,
    required int chunkCount,
    required int totalCiphertextBytes,
  }) : mutationId = _requireIdentifier(mutationId, 'mutationId'),
       attachmentId = _requireIdentifier(attachmentId, 'attachmentId'),
       keyEpoch = _requirePositiveUint32(keyEpoch, 'keyEpoch'),
       chunkCount = _requireChunkCount(chunkCount),
       totalCiphertextBytes = _requireTotalCiphertextBytes(
         totalCiphertextBytes,
         chunkCount,
       );

  final String mutationId;
  final String attachmentId;
  final int keyEpoch;
  final int chunkCount;
  final int totalCiphertextBytes;
}

final class CloudSyncAttachmentPutChunkRequest {
  CloudSyncAttachmentPutChunkRequest({
    required String mutationId,
    required this.chunk,
    required Uint8List ciphertext,
  }) : mutationId = _requireIdentifier(mutationId, 'mutationId'),
       ciphertext = _copyCiphertext(
         ciphertext,
         cloudSyncMaximumAttachmentChunkCiphertextBytes,
         'ciphertext',
       );

  final String mutationId;
  final CloudSyncAttachmentChunkIdentity chunk;
  final Uint8List ciphertext;
}

final class CloudSyncAttachmentManifestChunk {
  CloudSyncAttachmentManifestChunk({
    required int chunkIndex,
    required int ciphertextBytes,
  }) : chunkIndex = _requireChunkIndex(chunkIndex),
       ciphertextBytes = _requireCiphertextByteLength(
         ciphertextBytes,
         cloudSyncMaximumAttachmentChunkCiphertextBytes,
         'ciphertextBytes',
       );

  final int chunkIndex;
  final int ciphertextBytes;
}

final class CloudSyncAttachmentCommitUploadRequest {
  CloudSyncAttachmentCommitUploadRequest({
    required String mutationId,
    required this.identity,
    required Uint8List manifestCiphertext,
    required List<CloudSyncAttachmentManifestChunk> chunks,
  }) : mutationId = _requireIdentifier(mutationId, 'mutationId'),
       manifestCiphertext = _copyCiphertext(
         manifestCiphertext,
         cloudSyncMaximumAttachmentManifestCiphertextBytes,
         'manifestCiphertext',
       ),
       chunks = _copyManifestChunks(chunks);

  final String mutationId;
  final CloudSyncAttachmentIdentity identity;
  final Uint8List manifestCiphertext;
  final List<CloudSyncAttachmentManifestChunk> chunks;
}

final class CloudSyncAttachmentDeleteRequest {
  CloudSyncAttachmentDeleteRequest({
    required String mutationId,
    required this.identity,
  }) : mutationId = _requireIdentifier(mutationId, 'mutationId');

  final String mutationId;
  final CloudSyncAttachmentIdentity identity;
}

final class CloudSyncAttachmentUpload {
  CloudSyncAttachmentUpload({
    required this.identity,
    required int chunkCount,
    required int totalCiphertextBytes,
    required DateTime createdAt,
  }) : chunkCount = _requireChunkCount(chunkCount),
       totalCiphertextBytes = _requireTotalCiphertextBytes(
         totalCiphertextBytes,
         chunkCount,
       ),
       createdAt = createdAt.toUtc();

  final CloudSyncAttachmentIdentity identity;
  final int chunkCount;
  final int totalCiphertextBytes;
  final DateTime createdAt;
}

final class CloudSyncAttachmentStoredChunk {
  CloudSyncAttachmentStoredChunk({
    required this.chunk,
    required int ciphertextBytes,
  }) : ciphertextBytes = _requireCiphertextByteLength(
         ciphertextBytes,
         cloudSyncMaximumAttachmentChunkCiphertextBytes,
         'ciphertextBytes',
       );

  final CloudSyncAttachmentChunkIdentity chunk;
  final int ciphertextBytes;
}

final class CloudSyncAttachmentCommittedUpload {
  CloudSyncAttachmentCommittedUpload({
    required this.identity,
    required DateTime committedAt,
  }) : committedAt = committedAt.toUtc();

  final CloudSyncAttachmentIdentity identity;
  final DateTime committedAt;
}

final class CloudSyncAttachmentManifest {
  CloudSyncAttachmentManifest({
    required this.identity,
    required int chunkCount,
    required int totalCiphertextBytes,
    required Uint8List manifestCiphertext,
    required int manifestCiphertextBytes,
    required List<CloudSyncAttachmentManifestChunk> chunks,
    required DateTime committedAt,
  }) : chunkCount = _requireChunkCount(chunkCount),
       totalCiphertextBytes = _requireTotalCiphertextBytes(
         totalCiphertextBytes,
         chunkCount,
       ),
       manifestCiphertext = _copyCiphertext(
         manifestCiphertext,
         cloudSyncMaximumAttachmentManifestCiphertextBytes,
         'manifestCiphertext',
       ),
       manifestCiphertextBytes = _requireCiphertextByteLength(
         manifestCiphertextBytes,
         cloudSyncMaximumAttachmentManifestCiphertextBytes,
         'manifestCiphertextBytes',
       ),
       chunks = _copyManifestChunks(chunks),
       committedAt = committedAt.toUtc() {
    if (this.manifestCiphertext.length != manifestCiphertextBytes ||
        this.chunks.length != chunkCount ||
        this.chunks.fold<int>(
              0,
              (total, chunk) => total + chunk.ciphertextBytes,
            ) !=
            totalCiphertextBytes) {
      throw const FormatException('附件清单长度字段不一致');
    }
  }

  final CloudSyncAttachmentIdentity identity;
  final int chunkCount;
  final int totalCiphertextBytes;
  final Uint8List manifestCiphertext;
  final int manifestCiphertextBytes;
  final List<CloudSyncAttachmentManifestChunk> chunks;
  final DateTime committedAt;
}

final class CloudSyncAttachmentChunk {
  CloudSyncAttachmentChunk({
    required this.chunk,
    required Uint8List ciphertext,
    required int ciphertextBytes,
  }) : ciphertext = _copyCiphertext(
         ciphertext,
         cloudSyncMaximumAttachmentChunkCiphertextBytes,
         'ciphertext',
       ),
       ciphertextBytes = _requireCiphertextByteLength(
         ciphertextBytes,
         cloudSyncMaximumAttachmentChunkCiphertextBytes,
         'ciphertextBytes',
       ) {
    if (this.ciphertext.length != ciphertextBytes) {
      throw const FormatException('附件分块密文长度字段不一致');
    }
  }

  final CloudSyncAttachmentChunkIdentity chunk;
  final Uint8List ciphertext;
  final int ciphertextBytes;
}

final class CloudSyncAttachmentDeleted {
  CloudSyncAttachmentDeleted({
    required this.identity,
    required DateTime deletedAt,
  }) : deletedAt = deletedAt.toUtc();

  final CloudSyncAttachmentIdentity identity;
  final DateTime deletedAt;
}

final _identifierPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

String _requireIdentifier(String value, String field) {
  if (!_identifierPattern.hasMatch(value)) {
    throw FormatException('$field 必须为规范的小写 UUID v4');
  }
  return value;
}

int _requirePositiveUint32(int value, String field) {
  if (value < 1 || value > 0xffffffff) {
    throw FormatException('$field 必须位于正 uint32 范围');
  }
  return value;
}

int _requireChunkCount(int value) {
  if (value < 1 || value > cloudSyncMaximumAttachmentChunkCount) {
    throw const FormatException('chunkCount 超出附件协议范围');
  }
  return value;
}

int _requireChunkIndex(int value) {
  if (value < 0 || value >= cloudSyncMaximumAttachmentChunkCount) {
    throw const FormatException('chunkIndex 超出附件协议范围');
  }
  return value;
}

int _requireCiphertextByteLength(int value, int maximum, String field) {
  if (value < 1 || value > maximum) {
    throw FormatException('$field 超出附件协议范围');
  }
  return value;
}

int _requireTotalCiphertextBytes(int value, int chunkCount) {
  if (value < chunkCount ||
      value > chunkCount * cloudSyncMaximumAttachmentChunkCiphertextBytes) {
    throw const FormatException('totalCiphertextBytes 与 chunkCount 不一致');
  }
  return value;
}

Uint8List _copyCiphertext(Uint8List value, int maximum, String field) {
  _requireCiphertextByteLength(value.length, maximum, field);
  return Uint8List.fromList(value).asUnmodifiableView();
}

List<CloudSyncAttachmentManifestChunk> _copyManifestChunks(
  List<CloudSyncAttachmentManifestChunk> chunks,
) {
  if (chunks.isEmpty || chunks.length > cloudSyncMaximumAttachmentChunkCount) {
    throw const FormatException('附件清单分块数量超出协议范围');
  }
  final copied = List<CloudSyncAttachmentManifestChunk>.of(chunks);
  for (var position = 0; position < copied.length; position++) {
    if (copied[position].chunkIndex != position) {
      throw const FormatException('附件清单分块索引必须从零连续递增');
    }
  }
  return List<CloudSyncAttachmentManifestChunk>.unmodifiable(copied);
}
