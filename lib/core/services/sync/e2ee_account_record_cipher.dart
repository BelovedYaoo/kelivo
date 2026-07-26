import 'dart:convert';
import 'dart:typed_data';

import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:uuid/uuid.dart';

import 'sync_codec.dart';

const e2eeAccountRecordEnvelopeVersion = 1;
const e2eeAccountRecordSyncProtocolVersion = 3;
const e2eeAccountRecordMaxCiphertextBytes = 1048576;

const _recordEnvelopeOverheadBytes = 80;
const _recordFrameHeaderBytes = 24;
const _recordMaxFrameBytes =
    e2eeAccountRecordMaxCiphertextBytes - _recordEnvelopeOverheadBytes;
const _recordEntityTypeMaxBytes = 64;
const _recordEntityIdMaxBytes = 1024;
const _recordKeyHeaderBytes = 20;
const _recordKeyFormatVersion = 1;
const _recordFrameFormatVersion = 1;
const _maxPositiveInt32 = 0x7fffffff;

final _recordEntityTypePattern = RegExp(r'^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$');
final _recordKeyMagic = Uint8List.fromList(ascii.encode('KELVRK01'));
final _recordFrameMagic = Uint8List.fromList(ascii.encode('KELVRF01'));
final _recordAssociatedDataMagic = Uint8List.fromList(ascii.encode('KELVRA01'));

final class E2eeAccountRecordId {
  E2eeAccountRecordId._(Uint8List bytes)
    : _bytes = Uint8List.fromList(bytes).asUnmodifiableView(),
      wireValue = Uuid.unparse(bytes);

  final Uint8List _bytes;
  final String wireValue;

  @override
  bool operator ==(Object other) =>
      other is E2eeAccountRecordId && other.wireValue == wireValue;

  @override
  int get hashCode => wireValue.hashCode;

  @override
  String toString() => 'E2eeAccountRecordId(opaque)';
}

final class E2eeUntrustedAccountRecordId {
  factory E2eeUntrustedAccountRecordId.fromTransport(String wireValue) {
    final bytes = _parseCanonicalUuidV4(wireValue, 'recordId');
    return E2eeUntrustedAccountRecordId._(wireValue, bytes);
  }

  E2eeUntrustedAccountRecordId._(this.wireValue, Uint8List bytes)
    : _bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  final String wireValue;
  final Uint8List _bytes;

  @override
  bool operator ==(Object other) =>
      other is E2eeUntrustedAccountRecordId && other.wireValue == wireValue;

  @override
  int get hashCode => wireValue.hashCode;

  @override
  String toString() => 'E2eeUntrustedAccountRecordId(unverified)';
}

final class E2eeSealedAccountRecordEnvelope {
  E2eeSealedAccountRecordEnvelope._({
    required this.recordId,
    required this.keyEpoch,
    required Uint8List ciphertext,
  }) : ciphertext = Uint8List.fromList(ciphertext).asUnmodifiableView();

  final E2eeAccountRecordId recordId;
  final int keyEpoch;
  final Uint8List ciphertext;
}

final class E2eeUntrustedAccountRecordEnvelope {
  factory E2eeUntrustedAccountRecordEnvelope.fromTransport({
    required E2eeUntrustedAccountRecordId recordId,
    required int envelopeVersion,
    required int keyEpoch,
    required Uint8List ciphertext,
  }) {
    if (envelopeVersion != e2eeAccountRecordEnvelopeVersion) {
      throw const FormatException('不支持的账户记录信封版本');
    }
    _requirePositiveInt32(keyEpoch, 'keyEpoch');
    if (ciphertext.isEmpty ||
        ciphertext.length > e2eeAccountRecordMaxCiphertextBytes) {
      throw const FormatException('账户记录密文长度无效');
    }
    return E2eeUntrustedAccountRecordEnvelope._(
      recordId: recordId,
      keyEpoch: keyEpoch,
      ciphertext: ciphertext,
    );
  }

  E2eeUntrustedAccountRecordEnvelope._({
    required this.recordId,
    required this.keyEpoch,
    required Uint8List ciphertext,
  }) : ciphertext = Uint8List.fromList(ciphertext).asUnmodifiableView();

  final E2eeUntrustedAccountRecordId recordId;
  final int keyEpoch;
  final Uint8List ciphertext;
}

enum _AccountRecordCipherPhase { open, closing, closed }

final class E2eeAccountRecordCipher {
  factory E2eeAccountRecordCipher.takeOwnership({
    required KelivoSecureCore secureCore,
    required KelivoAccountRootKeyHandle accountRootKey,
    required String userId,
    required int currentKeyEpoch,
  }) {
    _requirePositiveInt32(currentKeyEpoch, 'currentKeyEpoch');
    return E2eeAccountRecordCipher._(
      secureCore: secureCore,
      accountRootKey: accountRootKey,
      userId: _parseCanonicalUuidV4(userId, 'userId'),
      currentKeyEpoch: currentKeyEpoch,
    );
  }

  E2eeAccountRecordCipher._({
    required this._secureCore,
    required this._accountRootKey,
    required Uint8List userId,
    required this.currentKeyEpoch,
  }) : _userId = Uint8List.fromList(userId).asUnmodifiableView();

  final KelivoSecureCore _secureCore;
  final KelivoAccountRootKeyHandle _accountRootKey;
  final Uint8List _userId;
  final int currentKeyEpoch;
  _AccountRecordCipherPhase _phase = _AccountRecordCipherPhase.open;

  Future<E2eeAccountRecordId> deriveRecordId(SyncEntityKey entityKey) async {
    _requireOpen();
    final encodedKey = _encodeEntityKey(entityKey);
    try {
      return await _deriveRecordId(encodedKey.canonicalBytes);
    } finally {
      encodedKey.clear();
    }
  }

  int maxPayloadBytesFor(SyncEntityKey entityKey) {
    _requireOpen();
    final encodedKey = _encodeEntityKey(entityKey);
    try {
      return _recordMaxFrameBytes -
          _recordFrameHeaderBytes -
          encodedKey.typeBytes.length -
          encodedKey.idBytes.length;
    } finally {
      encodedKey.clear();
    }
  }

  Future<E2eeSealedAccountRecordEnvelope> seal({
    required SyncEntityKey entityKey,
    required Uint8List payload,
  }) async {
    _requireOpen();
    final encodedKey = _encodeEntityKey(entityKey);
    Uint8List? frame;
    Uint8List? associatedData;
    Uint8List? ciphertext;
    try {
      final frameValue = _encodeRecordFrame(encodedKey, payload);
      frame = frameValue;
      final associatedDataValue = _buildAssociatedData(_userId);
      associatedData = associatedDataValue;
      final recordId = await _deriveRecordId(encodedKey.canonicalBytes);
      final ciphertextValue = await _secureCore.sealAccountRecord(
        _accountRootKey,
        recordId: recordId._bytes,
        keyEpoch: currentKeyEpoch,
        associatedData: associatedDataValue,
        plaintext: frameValue,
      );
      ciphertext = ciphertextValue;
      if (ciphertextValue.length > e2eeAccountRecordMaxCiphertextBytes) {
        throw StateError('账户记录密文超过同步协议上限');
      }
      return E2eeSealedAccountRecordEnvelope._(
        recordId: recordId,
        keyEpoch: currentKeyEpoch,
        ciphertext: ciphertextValue,
      );
    } finally {
      _clearBytes(ciphertext);
      _clearBytes(associatedData);
      _clearBytes(frame);
      encodedKey.clear();
    }
  }

  Future<T> open<T>(
    E2eeUntrustedAccountRecordEnvelope record, {
    required T Function(SyncEntityKey entityKey, Uint8List borrowedPayload)
    decode,
  }) {
    return openVerified(
      record,
      decode: (_, entityKey, borrowedPayload) =>
          decode(entityKey, borrowedPayload),
    );
  }

  Future<T> openVerified<T>(
    E2eeUntrustedAccountRecordEnvelope record, {
    required T Function(
      E2eeAccountRecordId recordId,
      SyncEntityKey entityKey,
      Uint8List borrowedPayload,
    )
    decode,
  }) async {
    _requireOpen();
    if (record.keyEpoch > currentKeyEpoch) {
      throw const FormatException('账户记录使用了尚未获得的密钥世代');
    }

    Uint8List? associatedData;
    Uint8List? plaintext;
    _EncodedEntityKey? encodedKey;
    try {
      final associatedDataValue = _buildAssociatedData(_userId);
      associatedData = associatedDataValue;
      final plaintextValue = await _secureCore.openAccountRecord(
        _accountRootKey,
        recordId: record.recordId._bytes,
        keyEpoch: record.keyEpoch,
        associatedData: associatedDataValue,
        envelope: record.ciphertext,
      );
      plaintext = plaintextValue;
      final decodedFrame = _decodeRecordFrame(plaintextValue);
      encodedKey = _encodeEntityKey(decodedFrame.entityKey);
      final expectedRecordId = await _deriveRecordId(encodedKey.canonicalBytes);
      if (!_sameBytes(expectedRecordId._bytes, record.recordId._bytes)) {
        throw const FormatException('账户记录标识与密文实体键不匹配');
      }
      // payload 只在回调期间借用，避免解密明文逃逸出可清零的生命周期。
      final result = decode(
        expectedRecordId,
        decodedFrame.entityKey,
        decodedFrame.payload,
      );
      if (result is Future<Object?>) {
        throw ArgumentError.value(decode, 'decode', '解码回调必须同步完成');
      }
      return result;
    } finally {
      encodedKey?.clear();
      _clearBytes(plaintext);
      _clearBytes(associatedData);
    }
  }

  Future<void> close() async {
    if (_phase == _AccountRecordCipherPhase.closed) return;
    if (_phase == _AccountRecordCipherPhase.closing) {
      throw StateError('账户记录加密器正在关闭');
    }
    _phase = _AccountRecordCipherPhase.closing;
    try {
      await _secureCore.closeAccountRootKey(_accountRootKey);
      _phase = _AccountRecordCipherPhase.closed;
    } catch (_) {
      _phase = _AccountRecordCipherPhase.open;
      rethrow;
    }
  }

  Future<E2eeAccountRecordId> _deriveRecordId(
    Uint8List canonicalEntityKey,
  ) async {
    final bytes = await _secureCore.deriveAccountRecordId(
      _accountRootKey,
      canonicalEntityKey: canonicalEntityKey,
    );
    _requireUuidV4Bytes(bytes, 'derivedRecordId');
    return E2eeAccountRecordId._(bytes);
  }

  void _requireOpen() {
    if (_phase != _AccountRecordCipherPhase.open) {
      throw StateError('账户记录加密器已经关闭');
    }
  }
}

final class _EncodedEntityKey {
  _EncodedEntityKey({
    required this.typeBytes,
    required this.idBytes,
    required this.canonicalBytes,
  });

  final Uint8List typeBytes;
  final Uint8List idBytes;
  final Uint8List canonicalBytes;

  void clear() {
    _clearBytes(canonicalBytes);
    _clearBytes(typeBytes);
    _clearBytes(idBytes);
  }
}

final class _DecodedRecordFrame {
  const _DecodedRecordFrame({required this.entityKey, required this.payload});

  final SyncEntityKey entityKey;
  final Uint8List payload;
}

_EncodedEntityKey _encodeEntityKey(SyncEntityKey key) {
  if (!_recordEntityTypePattern.hasMatch(key.entityType)) {
    throw const FormatException('同步实体类型必须为小写 kebab-case');
  }
  if (key.entityId.isEmpty || key.entityId.contains('\u0000')) {
    throw const FormatException('同步实体 ID 不能为空或包含 NUL');
  }

  final typeBytes = _encodeUtf8(key.entityType, 'entityType');
  final idBytes = _encodeUtf8(key.entityId, 'entityId');
  if (typeBytes.isEmpty || typeBytes.length > _recordEntityTypeMaxBytes) {
    _clearBytes(typeBytes);
    _clearBytes(idBytes);
    throw const FormatException('同步实体类型长度无效');
  }
  if (idBytes.isEmpty || idBytes.length > _recordEntityIdMaxBytes) {
    _clearBytes(typeBytes);
    _clearBytes(idBytes);
    throw const FormatException('同步实体 ID 长度无效');
  }

  final canonicalBytes = Uint8List(
    _recordKeyHeaderBytes + typeBytes.length + idBytes.length,
  );
  canonicalBytes.setRange(0, _recordKeyMagic.length, _recordKeyMagic);
  final fields = ByteData.sublistView(canonicalBytes);
  fields.setUint16(8, _recordKeyFormatVersion, Endian.big);
  fields.setUint16(10, 0, Endian.big);
  fields.setUint32(12, typeBytes.length, Endian.big);
  fields.setUint32(16, idBytes.length, Endian.big);
  canonicalBytes.setRange(
    _recordKeyHeaderBytes,
    _recordKeyHeaderBytes + typeBytes.length,
    typeBytes,
  );
  canonicalBytes.setRange(
    _recordKeyHeaderBytes + typeBytes.length,
    canonicalBytes.length,
    idBytes,
  );
  return _EncodedEntityKey(
    typeBytes: typeBytes,
    idBytes: idBytes,
    canonicalBytes: canonicalBytes,
  );
}

Uint8List _encodeRecordFrame(_EncodedEntityKey key, Uint8List payload) {
  final length =
      _recordFrameHeaderBytes +
      key.typeBytes.length +
      key.idBytes.length +
      payload.length;
  if (length > _recordMaxFrameBytes) {
    throw ArgumentError.value(payload.length, 'payload', '账户记录内容超过同步协议上限');
  }
  final frame = Uint8List(length);
  frame.setRange(0, _recordFrameMagic.length, _recordFrameMagic);
  final fields = ByteData.sublistView(frame);
  fields.setUint16(8, _recordFrameFormatVersion, Endian.big);
  fields.setUint16(10, 0, Endian.big);
  fields.setUint32(12, key.typeBytes.length, Endian.big);
  fields.setUint32(16, key.idBytes.length, Endian.big);
  fields.setUint32(20, payload.length, Endian.big);
  var offset = _recordFrameHeaderBytes;
  frame.setRange(offset, offset + key.typeBytes.length, key.typeBytes);
  offset += key.typeBytes.length;
  frame.setRange(offset, offset + key.idBytes.length, key.idBytes);
  offset += key.idBytes.length;
  frame.setRange(offset, frame.length, payload);
  return frame;
}

_DecodedRecordFrame _decodeRecordFrame(Uint8List frame) {
  if (frame.length < _recordFrameHeaderBytes ||
      !_rangeEquals(frame, 0, _recordFrameMagic)) {
    throw const FormatException('账户记录明文帧头无效');
  }
  final fields = ByteData.sublistView(frame);
  final version = fields.getUint16(8, Endian.big);
  final reserved = fields.getUint16(10, Endian.big);
  final typeLength = fields.getUint32(12, Endian.big);
  final idLength = fields.getUint32(16, Endian.big);
  final payloadLength = fields.getUint32(20, Endian.big);
  if (version != _recordFrameFormatVersion || reserved != 0) {
    throw const FormatException('账户记录明文帧版本无效');
  }
  final expectedLength =
      _recordFrameHeaderBytes + typeLength + idLength + payloadLength;
  if (typeLength < 1 ||
      typeLength > _recordEntityTypeMaxBytes ||
      idLength < 1 ||
      idLength > _recordEntityIdMaxBytes ||
      expectedLength != frame.length ||
      expectedLength > _recordMaxFrameBytes) {
    throw const FormatException('账户记录明文帧长度无效');
  }

  var offset = _recordFrameHeaderBytes;
  final typeEnd = offset + typeLength;
  final entityType = _decodeUtf8(
    Uint8List.sublistView(frame, offset, typeEnd),
    'entityType',
  );
  offset = typeEnd;
  final idEnd = offset + idLength;
  final entityId = _decodeUtf8(
    Uint8List.sublistView(frame, offset, idEnd),
    'entityId',
  );
  final entityKey = SyncEntityKey(entityType: entityType, entityId: entityId);
  _validateDecodedEntityKey(entityKey);
  return _DecodedRecordFrame(
    entityKey: entityKey,
    payload: Uint8List.sublistView(frame, idEnd),
  );
}

void _validateDecodedEntityKey(SyncEntityKey key) {
  final encoded = _encodeEntityKey(key);
  encoded.clear();
}

Uint8List _buildAssociatedData(Uint8List userId) {
  final result = Uint8List(28);
  result.setRange(
    0,
    _recordAssociatedDataMagic.length,
    _recordAssociatedDataMagic,
  );
  final fields = ByteData.sublistView(result);
  fields.setUint16(8, 1, Endian.big);
  fields.setUint16(10, e2eeAccountRecordSyncProtocolVersion, Endian.big);
  result.setRange(12, 28, userId);
  return result;
}

Uint8List _parseCanonicalUuidV4(String value, String field) {
  final bytes = Uint8List.fromList(Uuid.parseAsByteList(value));
  if (Uuid.unparse(bytes) != value) {
    throw FormatException('$field 必须为规范小写 UUID');
  }
  _requireUuidV4Bytes(bytes, field);
  return bytes;
}

void _requireUuidV4Bytes(Uint8List bytes, String field) {
  if (bytes.length != 16 ||
      (bytes[6] & 0xf0) != 0x40 ||
      (bytes[8] & 0xc0) != 0x80) {
    throw FormatException('$field 必须为 UUID v4');
  }
}

void _requirePositiveInt32(int value, String field) {
  if (value < 1 || value > _maxPositiveInt32) {
    throw FormatException('$field 必须位于正 int32 范围');
  }
}

Uint8List _encodeUtf8(String value, String field) {
  if (!_isWellFormedUtf16(value)) {
    throw FormatException('$field 包含未配对的 UTF-16 代理项');
  }
  try {
    return Uint8List.fromList(const Utf8Encoder().convert(value));
  } on FormatException {
    throw FormatException('$field 包含无效 Unicode');
  }
}

bool _isWellFormedUtf16(String value) {
  for (var index = 0; index < value.length; index++) {
    final codeUnit = value.codeUnitAt(index);
    if (codeUnit >= 0xd800 && codeUnit <= 0xdbff) {
      if (++index >= value.length) return false;
      final trailing = value.codeUnitAt(index);
      if (trailing < 0xdc00 || trailing > 0xdfff) return false;
    } else if (codeUnit >= 0xdc00 && codeUnit <= 0xdfff) {
      return false;
    }
  }
  return true;
}

String _decodeUtf8(Uint8List value, String field) {
  try {
    return const Utf8Decoder(allowMalformed: false).convert(value);
  } on FormatException {
    throw FormatException('$field 包含无效 UTF-8');
  }
}

bool _rangeEquals(Uint8List value, int offset, Uint8List expected) {
  if (offset < 0 || offset + expected.length > value.length) return false;
  var difference = 0;
  for (var index = 0; index < expected.length; index++) {
    difference |= value[offset + index] ^ expected[index];
  }
  return difference == 0;
}

bool _sameBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

void _clearBytes(Uint8List? value) {
  if (value == null || value.isEmpty) return;
  value.fillRange(0, value.length, 0);
}
