import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import 'e2ee_account_record_cipher.dart';
import 'sync_codec.dart';

const e2eeAccountRecordStateFormatVersion = 1;
const e2eeAccountRecordStateDigestBytes = 32;

const _stateFrameHeaderBytes = 64;
const _stateParentDigestMaxCount = 2;
const _maxPositiveInt63 = 0x7fffffffffffffff;
const _maxPositiveUint32 = 0xffffffff;

final _stateFrameMagic = Uint8List.fromList(ascii.encode('KELVRS01'));
final _stateDigestDomain = Uint8List.fromList(
  ascii.encode('kelivo.sync.record-state-digest.v1\u0000'),
);

enum E2eeAccountRecordStateKind { value, tombstone }

final class E2eeAccountRecordStateDigest {
  factory E2eeAccountRecordStateDigest.fromTrustedStorage(Uint8List bytes) {
    if (bytes.length != e2eeAccountRecordStateDigestBytes) {
      throw const FormatException('账户记录状态摘要长度无效');
    }
    return E2eeAccountRecordStateDigest._(bytes);
  }

  E2eeAccountRecordStateDigest._(Uint8List bytes)
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  final Uint8List bytes;

  @override
  bool operator ==(Object other) =>
      other is E2eeAccountRecordStateDigest && _sameBytes(bytes, other.bytes);

  @override
  int get hashCode {
    var hash = 17;
    for (final byte in bytes) {
      hash = 37 * hash + byte;
    }
    return hash;
  }

  @override
  String toString() => 'E2eeAccountRecordStateDigest(<已隐藏>)';
}

final class E2eeSealedAccountRecordState {
  E2eeSealedAccountRecordState._({
    required this.record,
    required this.digest,
    required this.kind,
    required this.logicalVersion,
    required List<E2eeAccountRecordStateDigest> parentDigests,
    required this.operationId,
    required this.claimedWriterDeviceId,
    required this.claimedWriterKeyVersion,
  }) : parentDigests = List.unmodifiable(parentDigests);

  final E2eeSealedAccountRecordEnvelope record;
  final E2eeAccountRecordStateDigest digest;
  final E2eeAccountRecordStateKind kind;
  final int logicalVersion;
  final List<E2eeAccountRecordStateDigest> parentDigests;
  final String operationId;
  // 共享 ARK 只能认证账户成员，设备签名接入前不能把该声明用于授权或撤销。
  final String claimedWriterDeviceId;
  final int claimedWriterKeyVersion;

  int get keyEpoch => record.keyEpoch;
}

final class E2eeAuthenticatedAccountRecordState {
  E2eeAuthenticatedAccountRecordState._({
    required this.recordId,
    required this.entityKey,
    required this.digest,
    required this.kind,
    required this.logicalVersion,
    required List<E2eeAccountRecordStateDigest> parentDigests,
    required this.operationId,
    required this.claimedWriterDeviceId,
    required this.claimedWriterKeyVersion,
    required this.keyEpoch,
  }) : parentDigests = List.unmodifiable(parentDigests);

  final E2eeAccountRecordId recordId;
  final SyncEntityKey entityKey;
  final E2eeAccountRecordStateDigest digest;
  final E2eeAccountRecordStateKind kind;
  final int logicalVersion;
  final List<E2eeAccountRecordStateDigest> parentDigests;
  final String operationId;
  // 该值来自账户认证密文，但尚未经过设备签名验证。
  final String claimedWriterDeviceId;
  final int claimedWriterKeyVersion;
  final int keyEpoch;
}

final class E2eeAccountRecordStateCodec {
  E2eeAccountRecordStateCodec.takeOwnership(this._recordCipher);

  final E2eeAccountRecordCipher _recordCipher;

  int get currentKeyEpoch => _recordCipher.currentKeyEpoch;

  Future<E2eeAccountRecordId> deriveRecordId(SyncEntityKey entityKey) {
    return _recordCipher.deriveRecordId(entityKey);
  }

  Future<E2eeSealedAccountRecordState> sealValue({
    required SyncEntityKey entityKey,
    required int logicalVersion,
    required List<E2eeAccountRecordStateDigest> parentDigests,
    required String operationId,
    required String claimedWriterDeviceId,
    required int claimedWriterKeyVersion,
    required Uint8List payload,
  }) {
    return _seal(
      entityKey: entityKey,
      kind: E2eeAccountRecordStateKind.value,
      logicalVersion: logicalVersion,
      parentDigests: parentDigests,
      operationId: operationId,
      claimedWriterDeviceId: claimedWriterDeviceId,
      claimedWriterKeyVersion: claimedWriterKeyVersion,
      payload: payload,
    );
  }

  Future<E2eeSealedAccountRecordState> sealTombstone({
    required SyncEntityKey entityKey,
    required int logicalVersion,
    required List<E2eeAccountRecordStateDigest> parentDigests,
    required String operationId,
    required String claimedWriterDeviceId,
    required int claimedWriterKeyVersion,
  }) {
    return _seal(
      entityKey: entityKey,
      kind: E2eeAccountRecordStateKind.tombstone,
      logicalVersion: logicalVersion,
      parentDigests: parentDigests,
      operationId: operationId,
      claimedWriterDeviceId: claimedWriterDeviceId,
      claimedWriterKeyVersion: claimedWriterKeyVersion,
      payload: Uint8List(0),
    );
  }

  Future<T> open<T>(
    E2eeUntrustedAccountRecordEnvelope record, {
    required T Function(
      E2eeAuthenticatedAccountRecordState state,
      Uint8List borrowedPayload,
    )
    decode,
  }) {
    final digest = _digestUntrustedEnvelope(record);
    return _recordCipher.openVerified(
      record,
      decode: (recordId, entityKey, borrowedStateFrame) {
        final decoded = _decodeStateFrame(borrowedStateFrame);
        return decode(
          E2eeAuthenticatedAccountRecordState._(
            recordId: recordId,
            entityKey: entityKey,
            digest: digest,
            kind: decoded.kind,
            logicalVersion: decoded.logicalVersion,
            parentDigests: decoded.parentDigests,
            operationId: decoded.operationId,
            claimedWriterDeviceId: decoded.claimedWriterDeviceId,
            claimedWriterKeyVersion: decoded.claimedWriterKeyVersion,
            keyEpoch: record.keyEpoch,
          ),
          decoded.payload,
        );
      },
    );
  }

  Future<
    ({
      E2eeSealedAccountRecordState sealed,
      E2eeAuthenticatedAccountRecordState authenticated,
    })
  >
  restoreForSend(
    E2eeUntrustedAccountRecordEnvelope record, {
    required E2eeAccountRecordStateDigest expectedDigest,
  }) async {
    final digest = _digestUntrustedEnvelope(record);
    final opened = await _recordCipher.authenticateAndDecode(
      record,
      decode: (recordId, entityKey, borrowedStateFrame) {
        final decoded = _decodeStateFrame(borrowedStateFrame);
        return E2eeAuthenticatedAccountRecordState._(
          recordId: recordId,
          entityKey: entityKey,
          digest: digest,
          kind: decoded.kind,
          logicalVersion: decoded.logicalVersion,
          parentDigests: decoded.parentDigests,
          operationId: decoded.operationId,
          claimedWriterDeviceId: decoded.claimedWriterDeviceId,
          claimedWriterKeyVersion: decoded.claimedWriterKeyVersion,
          keyEpoch: record.keyEpoch,
        );
      },
    );
    if (digest != expectedDigest) {
      throw const FormatException('账户记录状态摘要与持久化摘要不匹配');
    }
    final authenticated = opened.decoded;
    return (
      sealed: E2eeSealedAccountRecordState._(
        record: opened.record,
        digest: digest,
        kind: authenticated.kind,
        logicalVersion: authenticated.logicalVersion,
        parentDigests: authenticated.parentDigests,
        operationId: authenticated.operationId,
        claimedWriterDeviceId: authenticated.claimedWriterDeviceId,
        claimedWriterKeyVersion: authenticated.claimedWriterKeyVersion,
      ),
      authenticated: authenticated,
    );
  }

  Future<void> close() => _recordCipher.close();

  Future<E2eeSealedAccountRecordState> _seal({
    required SyncEntityKey entityKey,
    required E2eeAccountRecordStateKind kind,
    required int logicalVersion,
    required List<E2eeAccountRecordStateDigest> parentDigests,
    required String operationId,
    required String claimedWriterDeviceId,
    required int claimedWriterKeyVersion,
    required Uint8List payload,
  }) async {
    final operationIdBytes = _parseCanonicalUuidV4(operationId, 'operationId');
    final claimedWriterDeviceIdBytes = _parseCanonicalUuidV4(
      claimedWriterDeviceId,
      'claimedWriterDeviceId',
    );
    _requirePositiveUint32(claimedWriterKeyVersion, 'claimedWriterKeyVersion');
    final normalizedParents = _normalizeParentDigests(
      logicalVersion,
      parentDigests,
    );
    final maximumPayloadBytes =
        _recordCipher.maxPayloadBytesFor(entityKey) -
        _stateFrameHeaderBytes -
        normalizedParents.length * e2eeAccountRecordStateDigestBytes;
    if (payload.length > maximumPayloadBytes) {
      throw ArgumentError.value(payload.length, 'payload', '账户记录状态内容过长');
    }
    Uint8List? frame;
    try {
      frame = _encodeStateFrame(
        kind: kind,
        logicalVersion: logicalVersion,
        parentDigests: normalizedParents,
        operationId: operationIdBytes,
        claimedWriterDeviceId: claimedWriterDeviceIdBytes,
        claimedWriterKeyVersion: claimedWriterKeyVersion,
        payload: payload,
      );
      final record = await _recordCipher.seal(
        entityKey: entityKey,
        payload: frame,
      );
      return E2eeSealedAccountRecordState._(
        record: record,
        digest: _digestSealedEnvelope(record),
        kind: kind,
        logicalVersion: logicalVersion,
        parentDigests: normalizedParents,
        operationId: operationId,
        claimedWriterDeviceId: claimedWriterDeviceId,
        claimedWriterKeyVersion: claimedWriterKeyVersion,
      );
    } finally {
      _clearBytes(frame);
      _clearBytes(operationIdBytes);
      _clearBytes(claimedWriterDeviceIdBytes);
    }
  }
}

final class _DecodedStateFrame {
  const _DecodedStateFrame({
    required this.kind,
    required this.logicalVersion,
    required this.parentDigests,
    required this.operationId,
    required this.claimedWriterDeviceId,
    required this.claimedWriterKeyVersion,
    required this.payload,
  });

  final E2eeAccountRecordStateKind kind;
  final int logicalVersion;
  final List<E2eeAccountRecordStateDigest> parentDigests;
  final String operationId;
  final String claimedWriterDeviceId;
  final int claimedWriterKeyVersion;
  final Uint8List payload;
}

Uint8List _encodeStateFrame({
  required E2eeAccountRecordStateKind kind,
  required int logicalVersion,
  required List<E2eeAccountRecordStateDigest> parentDigests,
  required Uint8List operationId,
  required Uint8List claimedWriterDeviceId,
  required int claimedWriterKeyVersion,
  required Uint8List payload,
}) {
  if (kind == E2eeAccountRecordStateKind.tombstone && payload.isNotEmpty) {
    throw const FormatException('账户记录墓碑不得包含内容');
  }
  final frame = Uint8List(
    _stateFrameHeaderBytes +
        parentDigests.length * e2eeAccountRecordStateDigestBytes +
        payload.length,
  );
  frame.setRange(0, _stateFrameMagic.length, _stateFrameMagic);
  final fields = ByteData.sublistView(frame);
  fields.setUint16(8, e2eeAccountRecordStateFormatVersion, Endian.big);
  fields.setUint8(10, kind == E2eeAccountRecordStateKind.value ? 1 : 2);
  fields.setUint8(11, parentDigests.length);
  fields.setUint32(12, claimedWriterKeyVersion, Endian.big);
  fields.setUint64(16, logicalVersion, Endian.big);
  frame.setRange(24, 40, operationId);
  frame.setRange(40, 56, claimedWriterDeviceId);
  fields.setUint32(56, payload.length, Endian.big);
  fields.setUint32(60, 0, Endian.big);
  var offset = _stateFrameHeaderBytes;
  for (final parent in parentDigests) {
    frame.setRange(
      offset,
      offset + e2eeAccountRecordStateDigestBytes,
      parent.bytes,
    );
    offset += e2eeAccountRecordStateDigestBytes;
  }
  frame.setRange(offset, frame.length, payload);
  return frame;
}

_DecodedStateFrame _decodeStateFrame(Uint8List frame) {
  if (frame.length < _stateFrameHeaderBytes ||
      !_rangeEquals(frame, 0, _stateFrameMagic)) {
    throw const FormatException('账户记录状态帧头无效');
  }
  final fields = ByteData.sublistView(frame);
  final version = fields.getUint16(8, Endian.big);
  final kindValue = fields.getUint8(10);
  final parentCount = fields.getUint8(11);
  final claimedWriterKeyVersion = fields.getUint32(12, Endian.big);
  final logicalVersion = fields.getUint64(16, Endian.big);
  final payloadLength = fields.getUint32(56, Endian.big);
  final reserved = fields.getUint32(60, Endian.big);
  if (version != e2eeAccountRecordStateFormatVersion || reserved != 0) {
    throw const FormatException('账户记录状态帧版本无效');
  }
  final kind = switch (kindValue) {
    1 => E2eeAccountRecordStateKind.value,
    2 => E2eeAccountRecordStateKind.tombstone,
    _ => throw const FormatException('账户记录状态类型无效'),
  };
  _requirePositiveInt63(logicalVersion, 'logicalVersion');
  _requirePositiveUint32(claimedWriterKeyVersion, 'claimedWriterKeyVersion');
  _validateParentCount(logicalVersion, parentCount);
  final expectedLength =
      _stateFrameHeaderBytes +
      parentCount * e2eeAccountRecordStateDigestBytes +
      payloadLength;
  if (expectedLength != frame.length ||
      (kind == E2eeAccountRecordStateKind.tombstone && payloadLength != 0)) {
    throw const FormatException('账户记录状态帧长度无效');
  }

  final operationId = _canonicalUuidV4FromBytes(
    Uint8List.sublistView(frame, 24, 40),
    'operationId',
  );
  final claimedWriterDeviceId = _canonicalUuidV4FromBytes(
    Uint8List.sublistView(frame, 40, 56),
    'claimedWriterDeviceId',
  );
  var offset = _stateFrameHeaderBytes;
  final parents = <E2eeAccountRecordStateDigest>[];
  for (var index = 0; index < parentCount; index++) {
    final end = offset + e2eeAccountRecordStateDigestBytes;
    parents.add(
      E2eeAccountRecordStateDigest._(Uint8List.sublistView(frame, offset, end)),
    );
    offset = end;
  }
  for (var index = 1; index < parents.length; index++) {
    if (_compareBytes(parents[index - 1].bytes, parents[index].bytes) >= 0) {
      throw const FormatException('账户记录父状态摘要顺序无效');
    }
  }
  return _DecodedStateFrame(
    kind: kind,
    logicalVersion: logicalVersion,
    parentDigests: List.unmodifiable(parents),
    operationId: operationId,
    claimedWriterDeviceId: claimedWriterDeviceId,
    claimedWriterKeyVersion: claimedWriterKeyVersion,
    payload: Uint8List.sublistView(frame, offset),
  );
}

List<E2eeAccountRecordStateDigest> _normalizeParentDigests(
  int logicalVersion,
  List<E2eeAccountRecordStateDigest> parents,
) {
  _requirePositiveInt63(logicalVersion, 'logicalVersion');
  _validateParentCount(logicalVersion, parents.length);
  final normalized = parents.toList(growable: false)
    ..sort((left, right) => _compareBytes(left.bytes, right.bytes));
  for (var index = 1; index < normalized.length; index++) {
    if (normalized[index - 1] == normalized[index]) {
      throw const FormatException('账户记录父状态摘要不得重复');
    }
  }
  return List.unmodifiable(normalized);
}

void _validateParentCount(int logicalVersion, int parentCount) {
  if (parentCount < 0 || parentCount > _stateParentDigestMaxCount) {
    throw const FormatException('账户记录父状态数量无效');
  }
  if ((logicalVersion == 1 && parentCount != 0) ||
      (logicalVersion > 1 && parentCount == 0)) {
    throw const FormatException('账户记录逻辑版本与父状态不一致');
  }
}

E2eeAccountRecordStateDigest _digestSealedEnvelope(
  E2eeSealedAccountRecordEnvelope record,
) {
  return _digestEnvelope(
    recordId: record.recordId.wireValue,
    keyEpoch: record.keyEpoch,
    ciphertext: record.ciphertext,
  );
}

E2eeAccountRecordStateDigest _digestUntrustedEnvelope(
  E2eeUntrustedAccountRecordEnvelope record,
) {
  return _digestEnvelope(
    recordId: record.recordId.wireValue,
    keyEpoch: record.keyEpoch,
    ciphertext: record.ciphertext,
  );
}

E2eeAccountRecordStateDigest _digestEnvelope({
  required String recordId,
  required int keyEpoch,
  required Uint8List ciphertext,
}) {
  final header = Uint8List(26);
  final fields = ByteData.sublistView(header);
  fields.setUint16(0, e2eeAccountRecordEnvelopeVersion, Endian.big);
  header.setRange(2, 18, Uuid.parseAsByteList(recordId));
  fields.setUint32(18, keyEpoch, Endian.big);
  fields.setUint32(22, ciphertext.length, Endian.big);

  final output = _SingleDigestSink();
  final sink = sha256.startChunkedConversion(output);
  sink.add(_stateDigestDomain);
  sink.add(header);
  sink.add(ciphertext);
  sink.close();
  return E2eeAccountRecordStateDigest._(Uint8List.fromList(output.value.bytes));
}

final class _SingleDigestSink implements Sink<Digest> {
  Digest? _value;

  Digest get value => _value ?? (throw StateError('状态摘要尚未完成'));

  @override
  void add(Digest data) {
    if (_value != null) throw StateError('状态摘要重复完成');
    _value = data;
  }

  @override
  void close() {}
}

Uint8List _parseCanonicalUuidV4(String value, String field) {
  final bytes = Uint8List.fromList(Uuid.parseAsByteList(value));
  if (_canonicalUuidV4FromBytes(bytes, field) != value) {
    throw FormatException('$field 必须为规范小写 UUID v4');
  }
  return bytes;
}

String _canonicalUuidV4FromBytes(Uint8List bytes, String field) {
  if (bytes.length != 16 ||
      (bytes[6] & 0xf0) != 0x40 ||
      (bytes[8] & 0xc0) != 0x80) {
    throw FormatException('$field 必须为 UUID v4');
  }
  return Uuid.unparse(bytes);
}

void _requirePositiveInt63(int value, String field) {
  if (value < 1 || value > _maxPositiveInt63) {
    throw FormatException('$field 必须位于正 int63 范围');
  }
}

void _requirePositiveUint32(int value, String field) {
  if (value < 1 || value > _maxPositiveUint32) {
    throw FormatException('$field 必须位于正 uint32 范围');
  }
}

int _compareBytes(Uint8List left, Uint8List right) {
  final length = left.length < right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    final difference = left[index] - right[index];
    if (difference != 0) return difference;
  }
  return left.length - right.length;
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
