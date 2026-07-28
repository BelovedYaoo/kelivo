import 'dart:convert';
import 'dart:typed_data';

import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:uuid/uuid.dart';

import 'e2ee_account_record_cipher.dart';
import 'sync_codec.dart';

const e2eeAttachmentManifestFormatVersion = 1;
const e2eeAttachmentManifestEntityType = 'attachment-manifest';

const _manifestContentDigestBytes = 32;
const _manifestDisplayNameMaxBytes = 1024;
const _manifestMediaTypeMaxBytes = 255;
const _maximumUint32 = 0xffffffff;
const _manifestWrappedDataKeyOffset = 94;
const _manifestHeaderBytes =
    _manifestWrappedDataKeyOffset + KelivoAttachmentLimits.wrappedDataKeyBytes;

final _manifestMagic = Uint8List.fromList(ascii.encode('KELVAM01'));

enum E2eeAttachmentKind {
  image(1),
  file(2);

  const E2eeAttachmentKind(this.wireValue);

  final int wireValue;

  static E2eeAttachmentKind fromWireValue(int value) {
    for (final kind in values) {
      if (kind.wireValue == value) return kind;
    }
    throw const FormatException('附件清单类型无效');
  }
}

final class E2eeAttachmentManifest {
  factory E2eeAttachmentManifest({
    required String attachmentId,
    required String uploadId,
    required int keyEpoch,
    required E2eeAttachmentKind kind,
    required int totalPlaintextBytes,
    required Uint8List contentSha256,
    required Uint8List wrappedDataKey,
    required List<int> chunkCiphertextBytes,
    String? displayName,
    String? mediaType,
  }) {
    final canonicalAttachmentId = _canonicalUuidV4(
      attachmentId,
      'attachmentId',
    );
    final canonicalUploadId = _canonicalUuidV4(uploadId, 'uploadId');
    _requirePositiveUint32(keyEpoch, 'keyEpoch');
    if (contentSha256.length != _manifestContentDigestBytes) {
      throw const FormatException('附件内容摘要长度无效');
    }
    if (wrappedDataKey.length != KelivoAttachmentLimits.wrappedDataKeyBytes) {
      throw const FormatException('附件包装密钥长度无效');
    }
    final normalizedDisplayName = _validateDisplayName(displayName);
    final normalizedMediaType = _validateMediaType(mediaType);
    if (kind == E2eeAttachmentKind.file &&
        (normalizedDisplayName == null || normalizedMediaType == null)) {
      throw const FormatException('文件附件必须包含显示名称和媒体类型');
    }

    final layout = KelivoAttachmentLayout(
      totalPlaintextBytes: totalPlaintextBytes,
    );
    if (chunkCiphertextBytes.length != layout.chunkCount) {
      throw const FormatException('附件清单分块数量与明文布局不一致');
    }
    final immutableChunkLengths = List<int>.unmodifiable(chunkCiphertextBytes);
    for (var index = 0; index < immutableChunkLengths.length; index++) {
      final expected =
          layout.plaintextLengthForChunk(index) +
          KelivoAttachmentLimits.chunkEnvelopeOverheadBytes;
      if (immutableChunkLengths[index] != expected) {
        throw FormatException('附件清单第 $index 块密文长度与明文布局不一致');
      }
    }

    return E2eeAttachmentManifest._(
      attachmentId: canonicalAttachmentId,
      uploadId: canonicalUploadId,
      keyEpoch: keyEpoch,
      kind: kind,
      totalPlaintextBytes: totalPlaintextBytes,
      contentSha256: contentSha256,
      wrappedDataKey: wrappedDataKey,
      chunkCiphertextBytes: immutableChunkLengths,
      displayName: normalizedDisplayName,
      mediaType: normalizedMediaType,
    );
  }

  E2eeAttachmentManifest._({
    required this.attachmentId,
    required this.uploadId,
    required this.keyEpoch,
    required this.kind,
    required this.totalPlaintextBytes,
    required Uint8List contentSha256,
    required Uint8List wrappedDataKey,
    required this.chunkCiphertextBytes,
    required this.displayName,
    required this.mediaType,
  }) : contentSha256 = Uint8List.fromList(contentSha256).asUnmodifiableView(),
       wrappedDataKey = Uint8List.fromList(wrappedDataKey).asUnmodifiableView();

  final String attachmentId;
  final String uploadId;
  final int keyEpoch;
  final E2eeAttachmentKind kind;
  final int totalPlaintextBytes;
  final Uint8List contentSha256;
  final Uint8List wrappedDataKey;
  final List<int> chunkCiphertextBytes;
  final String? displayName;
  final String? mediaType;

  int get totalCiphertextBytes =>
      chunkCiphertextBytes.fold(0, (total, length) => total + length);
}

final class E2eeSealedAttachmentManifest {
  E2eeSealedAttachmentManifest._({
    required this.attachmentId,
    required this.uploadId,
    required this.keyEpoch,
    required Uint8List ciphertext,
  }) : ciphertext = Uint8List.fromList(ciphertext).asUnmodifiableView();

  final String attachmentId;
  final String uploadId;
  final int keyEpoch;
  final Uint8List ciphertext;
}

final class E2eeAttachmentManifestCipher {
  E2eeAttachmentManifestCipher.takeOwnership(this._recordCipher);

  final E2eeAccountRecordCipher _recordCipher;

  Future<E2eeSealedAttachmentManifest> seal(
    E2eeAttachmentManifest manifest,
  ) async {
    if (manifest.keyEpoch != _recordCipher.currentKeyEpoch) {
      throw const FormatException('附件清单密钥世代与当前账户密钥不一致');
    }
    final entityKey = _manifestEntityKey(manifest.attachmentId);
    final payload = _encodeManifest(manifest);
    try {
      final sealed = await _recordCipher.seal(
        entityKey: entityKey,
        payload: payload,
      );
      return E2eeSealedAttachmentManifest._(
        attachmentId: manifest.attachmentId,
        uploadId: manifest.uploadId,
        keyEpoch: manifest.keyEpoch,
        ciphertext: sealed.ciphertext,
      );
    } finally {
      payload.fillRange(0, payload.length, 0);
    }
  }

  Future<E2eeAttachmentManifest> open({
    required String attachmentId,
    required String uploadId,
    required int keyEpoch,
    required Uint8List ciphertext,
  }) async {
    final canonicalAttachmentId = _canonicalUuidV4(
      attachmentId,
      'attachmentId',
    );
    final canonicalUploadId = _canonicalUuidV4(uploadId, 'uploadId');
    _requirePositiveUint32(keyEpoch, 'keyEpoch');
    final entityKey = _manifestEntityKey(canonicalAttachmentId);
    final recordId = await _recordCipher.deriveRecordId(entityKey);
    final envelope = E2eeUntrustedAccountRecordEnvelope.fromTransport(
      recordId: E2eeUntrustedAccountRecordId.fromTransport(recordId.wireValue),
      envelopeVersion: e2eeAccountRecordEnvelopeVersion,
      keyEpoch: keyEpoch,
      ciphertext: ciphertext,
    );
    return _recordCipher.open(
      envelope,
      decode: (authenticatedEntityKey, borrowedPayload) {
        if (authenticatedEntityKey != entityKey) {
          throw const FormatException('附件清单记录身份不一致');
        }
        final manifest = _decodeManifest(borrowedPayload);
        if (manifest.attachmentId != canonicalAttachmentId ||
            manifest.uploadId != canonicalUploadId ||
            manifest.keyEpoch != keyEpoch) {
          throw const FormatException('附件清单认证上下文与请求不一致');
        }
        return manifest;
      },
    );
  }

  Future<void> close() => _recordCipher.close();
}

SyncEntityKey _manifestEntityKey(String attachmentId) => SyncEntityKey(
  entityType: e2eeAttachmentManifestEntityType,
  entityId: attachmentId,
);

Uint8List _encodeManifest(E2eeAttachmentManifest manifest) {
  final displayNameBytes = manifest.displayName == null
      ? Uint8List(0)
      : Uint8List.fromList(utf8.encode(manifest.displayName!));
  final mediaTypeBytes = manifest.mediaType == null
      ? Uint8List(0)
      : Uint8List.fromList(ascii.encode(manifest.mediaType!));
  final frame = Uint8List(
    _manifestHeaderBytes +
        manifest.chunkCiphertextBytes.length * 4 +
        displayNameBytes.length +
        mediaTypeBytes.length,
  );
  final fields = ByteData.view(
    frame.buffer,
    frame.offsetInBytes,
    frame.lengthInBytes,
  );
  frame.setRange(0, 8, _manifestMagic);
  fields.setUint16(8, e2eeAttachmentManifestFormatVersion, Endian.big);
  fields.setUint8(10, manifest.kind.wireValue);
  fields.setUint8(11, 0);
  frame.setRange(12, 28, Uuid.parseAsByteList(manifest.attachmentId));
  frame.setRange(28, 44, Uuid.parseAsByteList(manifest.uploadId));
  fields.setUint32(44, manifest.keyEpoch, Endian.big);
  fields.setUint64(48, manifest.totalPlaintextBytes, Endian.big);
  fields.setUint16(56, manifest.chunkCiphertextBytes.length, Endian.big);
  fields.setUint16(58, displayNameBytes.length, Endian.big);
  fields.setUint16(60, mediaTypeBytes.length, Endian.big);
  frame.setRange(62, 94, manifest.contentSha256);
  frame.setRange(
    _manifestWrappedDataKeyOffset,
    _manifestHeaderBytes,
    manifest.wrappedDataKey,
  );
  var offset = _manifestHeaderBytes;
  for (final chunkLength in manifest.chunkCiphertextBytes) {
    fields.setUint32(offset, chunkLength, Endian.big);
    offset += 4;
  }
  frame.setRange(offset, offset + displayNameBytes.length, displayNameBytes);
  offset += displayNameBytes.length;
  frame.setRange(offset, offset + mediaTypeBytes.length, mediaTypeBytes);
  displayNameBytes.fillRange(0, displayNameBytes.length, 0);
  mediaTypeBytes.fillRange(0, mediaTypeBytes.length, 0);
  return frame;
}

E2eeAttachmentManifest _decodeManifest(Uint8List frame) {
  if (frame.length < _manifestHeaderBytes ||
      !_sameBytes(Uint8List.sublistView(frame, 0, 8), _manifestMagic)) {
    throw const FormatException('附件清单帧头无效');
  }
  final fields = ByteData.sublistView(frame);
  if (fields.getUint16(8, Endian.big) != e2eeAttachmentManifestFormatVersion) {
    throw const FormatException('不支持的附件清单版本');
  }
  if (fields.getUint8(11) != 0) {
    throw const FormatException('附件清单保留位非零');
  }
  final kind = E2eeAttachmentKind.fromWireValue(fields.getUint8(10));
  final chunkCount = fields.getUint16(56, Endian.big);
  final displayNameLength = fields.getUint16(58, Endian.big);
  final mediaTypeLength = fields.getUint16(60, Endian.big);
  if (chunkCount < 1 ||
      chunkCount > KelivoAttachmentLimits.maxChunkCount ||
      displayNameLength > _manifestDisplayNameMaxBytes ||
      mediaTypeLength > _manifestMediaTypeMaxBytes) {
    throw const FormatException('附件清单长度字段无效');
  }
  final expectedLength =
      _manifestHeaderBytes +
      chunkCount * 4 +
      displayNameLength +
      mediaTypeLength;
  if (frame.length != expectedLength) {
    throw const FormatException('附件清单帧长度不一致');
  }
  var offset = _manifestHeaderBytes;
  final chunkCiphertextBytes = <int>[];
  for (var index = 0; index < chunkCount; index++) {
    chunkCiphertextBytes.add(fields.getUint32(offset, Endian.big));
    offset += 4;
  }
  final displayName = displayNameLength == 0
      ? null
      : utf8.decode(
          Uint8List.sublistView(frame, offset, offset + displayNameLength),
          allowMalformed: false,
        );
  offset += displayNameLength;
  final mediaType = mediaTypeLength == 0
      ? null
      : ascii.decode(
          Uint8List.sublistView(frame, offset, offset + mediaTypeLength),
          allowInvalid: false,
        );
  try {
    return E2eeAttachmentManifest(
      attachmentId: Uuid.unparse(Uint8List.sublistView(frame, 12, 28)),
      uploadId: Uuid.unparse(Uint8List.sublistView(frame, 28, 44)),
      keyEpoch: fields.getUint32(44, Endian.big),
      kind: kind,
      totalPlaintextBytes: fields.getUint64(48, Endian.big),
      contentSha256: Uint8List.sublistView(frame, 62, 94),
      wrappedDataKey: Uint8List.sublistView(
        frame,
        _manifestWrappedDataKeyOffset,
        _manifestHeaderBytes,
      ),
      chunkCiphertextBytes: chunkCiphertextBytes,
      displayName: displayName,
      mediaType: mediaType,
    );
  } on ArgumentError catch (error) {
    throw FormatException('附件清单字段无效：${error.message}');
  }
}

String _canonicalUuidV4(String value, String field) {
  late final Uint8List bytes;
  try {
    bytes = Uint8List.fromList(Uuid.parseAsByteList(value));
  } on FormatException {
    throw FormatException('$field 不是规范 UUIDv4');
  }
  if (bytes.length != 16 ||
      bytes[6] & 0xf0 != 0x40 ||
      bytes[8] & 0xc0 != 0x80 ||
      Uuid.unparse(bytes) != value) {
    throw FormatException('$field 不是规范 UUIDv4');
  }
  return value;
}

void _requirePositiveUint32(int value, String field) {
  if (value <= 0 || value > _maximumUint32) {
    throw FormatException('$field 必须为正 uint32');
  }
}

String? _validateDisplayName(String? value) {
  if (value == null) return null;
  if (value.isEmpty || value == '.' || value == '..') {
    throw const FormatException('附件显示名称无效');
  }
  final encodedLength = utf8.encode(value).length;
  if (encodedLength > _manifestDisplayNameMaxBytes ||
      value.contains('/') ||
      value.contains('\\') ||
      value.runes.any((rune) => rune < 0x20 || rune == 0x7f)) {
    throw const FormatException('附件显示名称包含非法字符或长度超限');
  }
  return value;
}

String? _validateMediaType(String? value) {
  if (value == null) return null;
  final slash = value.indexOf('/');
  if (value.isEmpty ||
      value.length > _manifestMediaTypeMaxBytes ||
      slash <= 0 ||
      slash == value.length - 1 ||
      value.codeUnits.any((unit) => unit < 0x21 || unit > 0x7e)) {
    throw const FormatException('附件媒体类型无效');
  }
  return value;
}

bool _sameBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}
