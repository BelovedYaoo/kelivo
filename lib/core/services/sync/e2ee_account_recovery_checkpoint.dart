import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';

import '../workspace/device_state_blob_store.dart';
import 'e2ee_account_recovery.dart';

const _checkpointVersion = 1;
const _checkpointRecordEpoch = 1;
const _checkpointFixedLength = 819;
const _checkpointTokenLength = 59;
const _checkpointCapsuleMaximumLength = 4096;
const _checkpointRecordDomain = 'kelivo.account-recovery.checkpoint.record.v1';
const _checkpointAssociatedDataDomain =
    'kelivo.account-recovery.checkpoint.aad.v1';
final _checkpointMagic = Uint8List.fromList(ascii.encode('KELVARC1'));
final _canonicalUuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

final class E2eeAccountRecoveryCheckpointStore
    implements E2eeAccountRecoveryCheckpointPersistence {
  factory E2eeAccountRecoveryCheckpointStore({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
    required DeviceStateBlobStore deviceStateStore,
    required KelivoSecureCore secureCore,
    required KelivoKeyHandle key,
  }) {
    if (normalizedBaseUrl.isEmpty || normalizedBaseUrl.contains('\u0000')) {
      throw const FormatException('账户恢复 checkpoint 服务地址无效');
    }
    if (normalizedLoginName.isEmpty || normalizedLoginName.contains('\u0000')) {
      throw const FormatException('账户恢复 checkpoint 登录名无效');
    }
    final scope = '$normalizedBaseUrl\u0000$normalizedLoginName';
    final recordDigest = sha256.convert(
      utf8.encode('$_checkpointRecordDomain\u0000$scope'),
    );
    final recordId = Uint8List.fromList(
      recordDigest.bytes.sublist(0, 16),
    ).asUnmodifiableView();
    final associatedData = Uint8List.fromList(
      utf8.encode('$_checkpointAssociatedDataDomain\u0000$scope'),
    ).asUnmodifiableView();
    return E2eeAccountRecoveryCheckpointStore._(
      normalizedBaseUrl,
      normalizedLoginName,
      deviceStateStore,
      secureCore,
      key,
      recordId,
      associatedData,
    );
  }

  const E2eeAccountRecoveryCheckpointStore._(
    this._normalizedBaseUrl,
    this._normalizedLoginName,
    this._deviceStateStore,
    this._secureCore,
    this._key,
    this._recordId,
    this._associatedData,
  );

  final String _normalizedBaseUrl;
  final String _normalizedLoginName;
  final DeviceStateBlobStore _deviceStateStore;
  final KelivoSecureCore _secureCore;
  final KelivoKeyHandle _key;
  final Uint8List _recordId;
  final Uint8List _associatedData;

  @override
  Future<E2eeAccountRecoveryCheckpointSnapshot?> read() async {
    Uint8List? envelope;
    Uint8List? plaintext;
    try {
      envelope = await _deviceStateStore.readPendingAccountRecoveryEnvelope(
        normalizedBaseUrl: _normalizedBaseUrl,
        normalizedLoginName: _normalizedLoginName,
      );
      if (envelope == null) return null;
      plaintext = await _secureCore.openRecord(
        _key,
        recordId: _recordId,
        epoch: _checkpointRecordEpoch,
        associatedData: _associatedData,
        envelope: envelope,
      );
      return E2eeAccountRecoveryCheckpointSnapshot(
        checkpoint: _decodeCheckpoint(plaintext),
        envelopeDigest: _digest(envelope),
      );
    } finally {
      _clear(envelope);
      _clear(plaintext);
    }
  }

  @override
  Future<E2eeAccountRecoveryCheckpointSnapshot> create(
    E2eeAccountRecoveryCheckpoint checkpoint,
  ) async {
    final current = await read();
    if (current != null) {
      if (_sameCheckpoint(current.checkpoint, checkpoint)) return current;
      throw StateError('账户恢复 checkpoint 已存在');
    }
    final envelope = await _seal(checkpoint);
    try {
      try {
        await _deviceStateStore.writePendingAccountRecoveryEnvelope(
          normalizedBaseUrl: _normalizedBaseUrl,
          normalizedLoginName: _normalizedLoginName,
          envelope: envelope,
        );
      } on StateError {
        final raced = await read();
        if (raced != null && _sameCheckpoint(raced.checkpoint, checkpoint)) {
          return raced;
        }
        rethrow;
      }
      return E2eeAccountRecoveryCheckpointSnapshot(
        checkpoint: checkpoint,
        envelopeDigest: _digest(envelope),
      );
    } finally {
      _clear(envelope);
    }
  }

  @override
  Future<E2eeAccountRecoveryCheckpointSnapshot> advance({
    required Uint8List expectedEnvelopeDigest,
    required E2eeAccountRecoveryCheckpoint checkpoint,
  }) async {
    if (expectedEnvelopeDigest.length != 32) {
      throw const FormatException('账户恢复 checkpoint 信封摘要长度无效');
    }
    final current = await read();
    if (current == null) {
      throw StateError('账户恢复 checkpoint 不存在');
    }
    if (_sameCheckpoint(current.checkpoint, checkpoint)) {
      return current;
    }
    if (!_sameBytes(current.envelopeDigest, expectedEnvelopeDigest)) {
      throw StateError('账户恢复 checkpoint 已被并发推进');
    }
    final envelope = await _seal(checkpoint);
    try {
      try {
        await _deviceStateStore.replacePendingAccountRecoveryEnvelope(
          normalizedBaseUrl: _normalizedBaseUrl,
          normalizedLoginName: _normalizedLoginName,
          expectedDigest: expectedEnvelopeDigest,
          envelope: envelope,
        );
      } on StateError {
        final raced = await read();
        if (raced != null && _sameCheckpoint(raced.checkpoint, checkpoint)) {
          return raced;
        }
        rethrow;
      }
      return E2eeAccountRecoveryCheckpointSnapshot(
        checkpoint: checkpoint,
        envelopeDigest: _digest(envelope),
      );
    } finally {
      _clear(envelope);
    }
  }

  @override
  Future<bool> delete(E2eeAccountRecoveryCheckpointSnapshot snapshot) {
    return _deviceStateStore.deletePendingAccountRecoveryEnvelope(
      normalizedBaseUrl: _normalizedBaseUrl,
      normalizedLoginName: _normalizedLoginName,
      expectedDigest: snapshot.envelopeDigest,
    );
  }

  Future<Uint8List> _seal(E2eeAccountRecoveryCheckpoint checkpoint) async {
    final plaintext = _encodeCheckpoint(checkpoint);
    try {
      final envelope = await _secureCore.sealRecord(
        _key,
        recordId: _recordId,
        epoch: _checkpointRecordEpoch,
        associatedData: _associatedData,
        plaintext: plaintext,
      );
      if (envelope.length >
          DeviceStateBlobStore.pendingAccountRecoveryEnvelopeMaxLength) {
        envelope.fillRange(0, envelope.length, 0);
        throw const FormatException('账户恢复 checkpoint 密文超过存储上限');
      }
      return envelope;
    } finally {
      _clear(plaintext);
    }
  }
}

bool _sameCheckpoint(
  E2eeAccountRecoveryCheckpoint left,
  E2eeAccountRecoveryCheckpoint right,
) {
  final leftFrame = _encodeCheckpoint(left);
  final rightFrame = _encodeCheckpoint(right);
  try {
    return _sameBytes(leftFrame, rightFrame);
  } finally {
    _clear(leftFrame);
    _clear(rightFrame);
  }
}

Uint8List _encodeCheckpoint(E2eeAccountRecoveryCheckpoint checkpoint) {
  final challenge = checkpoint.challenge;
  final capsule = challenge.recoveryCapsule;
  if (capsule.isEmpty || capsule.length > _checkpointCapsuleMaximumLength) {
    throw const FormatException('账户恢复 checkpoint capsule 长度无效');
  }
  final tokenBytes = Uint8List.fromList(
    ascii.encode(checkpoint.recoveryToken.value),
  );
  Uint8List? nonceProof;
  Uint8List? trustSignature;
  try {
    if (tokenBytes.length != _checkpointTokenLength) {
      throw const FormatException('账户恢复 checkpoint token 长度无效');
    }
    if (checkpoint.stage != E2eeAccountRecoveryStage.challenged) {
      nonceProof = checkpoint.copyNonceProof();
      trustSignature = checkpoint.copyTrustSignature();
    }
    final frame = Uint8List(_checkpointFixedLength + capsule.length);
    final view = ByteData.sublistView(frame);
    var offset = 0;
    offset = _writeBytes(frame, offset, _checkpointMagic);
    offset = _writeUint32(view, offset, _checkpointVersion);
    offset = _writeUint32(view, offset, _stageCode(checkpoint.stage));
    offset = _writeBytes(
      frame,
      offset,
      _uuidBytes(checkpoint.expectedDeviceId),
    );
    offset = _writeBytes(frame, offset, _uuidBytes(challenge.attemptId));
    offset = _writeBytes(frame, offset, challenge.requestDigest);
    offset = _writeBytes(frame, offset, challenge.challengeFrame);
    offset = _writeBytes(frame, offset, challenge.sealedNonce);
    offset = _writeUint32(view, offset, challenge.securityGeneration);
    offset = _writeUint32(view, offset, challenge.keyEpoch);
    offset = _writeBytes(frame, offset, challenge.membershipManifestDigest);
    offset = _writeUint32(view, offset, challenge.recoveryPublicKeyVersion);
    offset = _writeBytes(frame, offset, challenge.recoveryPublicKey);
    offset = _writeUint32(view, offset, challenge.recoveryCapsuleVersion);
    offset = _writeUint32(view, offset, capsule.length);
    offset = _writeBytes(frame, offset, capsule);
    offset = _writeBytes(frame, offset, challenge.recoveryCapsuleDigest);
    offset = _writeUint32(
      view,
      offset,
      challenge.dataState.phase == E2eeAccountRecoveryDataPhase.ready ? 1 : 2,
    );
    offset = _writeUint32(view, offset, challenge.dataState.dataGeneration);
    offset = _writeUint32(view, offset, challenge.dataState.dataKeyEpoch);
    offset = _writeBytes(
      frame,
      offset,
      challenge.dataState.operationId == null
          ? Uint8List(16)
          : _uuidBytes(challenge.dataState.operationId!),
    );
    offset = _writeUint32(
      view,
      offset,
      challenge.dataState.targetKeyEpoch ?? 0,
    );
    offset = _writeUint64(
      view,
      offset,
      challenge.expiresAt.millisecondsSinceEpoch,
    );
    offset = _writeBytes(frame, offset, tokenBytes);
    offset = _writeBytes(
      frame,
      offset,
      nonceProof ?? Uint8List(e2eeAccountRecoveryNonceProofBytes),
    );
    offset = _writeBytes(
      frame,
      offset,
      trustSignature ?? Uint8List(e2eeAccountRecoveryTrustSignatureBytes),
    );
    offset = _writeUint64(
      view,
      offset,
      checkpoint.recoveryTokenExpiresAt?.millisecondsSinceEpoch ?? 0,
    );
    offset = _writeUint32(view, offset, _nextActionCode(checkpoint.nextAction));
    if (offset != frame.length) {
      frame.fillRange(0, frame.length, 0);
      throw StateError('账户恢复 checkpoint 编码长度不一致');
    }
    return frame;
  } finally {
    _clear(tokenBytes);
    _clear(nonceProof);
    _clear(trustSignature);
  }
}

E2eeAccountRecoveryCheckpoint _decodeCheckpoint(Uint8List frame) {
  if (frame.length < _checkpointFixedLength ||
      !_startsWith(frame, _checkpointMagic)) {
    throw const FormatException('账户恢复 checkpoint 帧无效');
  }
  final view = ByteData.sublistView(frame);
  var offset = _checkpointMagic.length;
  if (_readUint32(view, offset) != _checkpointVersion) {
    throw const FormatException('账户恢复 checkpoint 版本无效');
  }
  offset += 4;
  final stage = _parseStage(_readUint32(view, offset));
  offset += 4;
  final expectedDeviceId = _uuidString(frame, offset);
  offset += 16;
  final attemptId = _uuidString(frame, offset);
  offset += 16;
  final requestDigest = _readBytes(frame, offset, 32);
  offset += 32;
  final challengeFrame = _readBytes(
    frame,
    offset,
    e2eeAccountRecoveryChallengeFrameBytes,
  );
  offset += e2eeAccountRecoveryChallengeFrameBytes;
  final sealedNonce = _readBytes(
    frame,
    offset,
    e2eeAccountRecoverySealedNonceBytes,
  );
  offset += e2eeAccountRecoverySealedNonceBytes;
  final securityGeneration = _readUint32(view, offset);
  offset += 4;
  final keyEpoch = _readUint32(view, offset);
  offset += 4;
  final membershipManifestDigest = _readBytes(frame, offset, 32);
  offset += 32;
  final recoveryPublicKeyVersion = _readUint32(view, offset);
  offset += 4;
  final recoveryPublicKey = _readBytes(frame, offset, 32);
  offset += 32;
  final recoveryCapsuleVersion = _readUint32(view, offset);
  offset += 4;
  final capsuleLength = _readUint32(view, offset);
  offset += 4;
  if (capsuleLength <= 0 ||
      capsuleLength > _checkpointCapsuleMaximumLength ||
      frame.length != _checkpointFixedLength + capsuleLength) {
    throw const FormatException('账户恢复 checkpoint capsule 边界无效');
  }
  final recoveryCapsule = _readBytes(frame, offset, capsuleLength);
  offset += capsuleLength;
  final recoveryCapsuleDigest = _readBytes(frame, offset, 32);
  offset += 32;
  final dataPhaseCode = _readUint32(view, offset);
  offset += 4;
  final dataGeneration = _readUint32(view, offset);
  offset += 4;
  final dataKeyEpoch = _readUint32(view, offset);
  offset += 4;
  final operationIdBytes = _readBytes(frame, offset, 16);
  offset += 16;
  final targetKeyEpoch = _readUint32(view, offset);
  offset += 4;
  final expiresAtMs = _readUint64(view, offset);
  offset += 8;
  final tokenBytes = _readBytes(frame, offset, _checkpointTokenLength);
  offset += _checkpointTokenLength;
  final nonceProof = _readBytes(
    frame,
    offset,
    e2eeAccountRecoveryNonceProofBytes,
  );
  offset += e2eeAccountRecoveryNonceProofBytes;
  final trustSignature = _readBytes(
    frame,
    offset,
    e2eeAccountRecoveryTrustSignatureBytes,
  );
  offset += e2eeAccountRecoveryTrustSignatureBytes;
  final recoveryTokenExpiresAtMs = _readUint64(view, offset);
  offset += 8;
  final nextActionCode = _readUint32(view, offset);
  offset += 4;
  if (offset != frame.length || expiresAtMs <= 0) {
    throw const FormatException('账户恢复 checkpoint 尾部状态无效');
  }
  final dataState = switch (dataPhaseCode) {
    1 when _allZero(operationIdBytes) && targetKeyEpoch == 0 =>
      E2eeAccountRecoveryDataState.ready(
        dataGeneration: dataGeneration,
        dataKeyEpoch: dataKeyEpoch,
      ),
    2 when !_allZero(operationIdBytes) && targetKeyEpoch > 0 =>
      E2eeAccountRecoveryDataState.rekeyPending(
        dataGeneration: dataGeneration,
        dataKeyEpoch: dataKeyEpoch,
        operationId: _uuidStringFromBytes(operationIdBytes),
        targetKeyEpoch: targetKeyEpoch,
      ),
    _ => throw const FormatException('账户恢复 checkpoint 数据换钥状态无效'),
  };
  final challenge = E2eeAccountRecoveryChallenge(
    attemptId: attemptId,
    requestDigest: requestDigest,
    challengeFrame: challengeFrame,
    sealedNonce: sealedNonce,
    securityGeneration: securityGeneration,
    keyEpoch: keyEpoch,
    membershipManifestDigest: membershipManifestDigest,
    recoveryPublicKeyVersion: recoveryPublicKeyVersion,
    recoveryPublicKey: recoveryPublicKey,
    recoveryCapsuleVersion: recoveryCapsuleVersion,
    recoveryCapsule: recoveryCapsule,
    recoveryCapsuleDigest: recoveryCapsuleDigest,
    dataState: dataState,
    expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAtMs, isUtc: true),
  );
  final CloudSyncAccountRecoveryToken recoveryToken;
  try {
    recoveryToken = CloudSyncAccountRecoveryToken.parse(
      ascii.decode(tokenBytes),
    );
  } finally {
    _clear(tokenBytes);
  }
  switch (stage) {
    case E2eeAccountRecoveryStage.challenged:
      if (!_allZero(nonceProof) ||
          !_allZero(trustSignature) ||
          recoveryTokenExpiresAtMs != 0 ||
          nextActionCode != 0) {
        throw const FormatException('账户恢复 challenge checkpoint 状态无效');
      }
      return E2eeAccountRecoveryCheckpoint.challenged(
        expectedDeviceId: expectedDeviceId,
        recoveryToken: recoveryToken,
        challenge: challenge,
      );
    case E2eeAccountRecoveryStage.proofReady:
      if (_allZero(nonceProof) ||
          _allZero(trustSignature) ||
          recoveryTokenExpiresAtMs != 0 ||
          nextActionCode != 0) {
        throw const FormatException('账户恢复 proof checkpoint 状态无效');
      }
      return E2eeAccountRecoveryCheckpoint.challenged(
        expectedDeviceId: expectedDeviceId,
        recoveryToken: recoveryToken,
        challenge: challenge,
      ).withProof(nonceProof: nonceProof, trustSignature: trustSignature);
    case E2eeAccountRecoveryStage.authorized:
      if (_allZero(nonceProof) ||
          _allZero(trustSignature) ||
          recoveryTokenExpiresAtMs <= 0 ||
          nextActionCode == 0) {
        throw const FormatException('账户恢复授权 checkpoint 状态无效');
      }
      return E2eeAccountRecoveryCheckpoint.challenged(
            expectedDeviceId: expectedDeviceId,
            recoveryToken: recoveryToken,
            challenge: challenge,
          )
          .withProof(nonceProof: nonceProof, trustSignature: trustSignature)
          .authorized(
            recoveryTokenExpiresAt: DateTime.fromMillisecondsSinceEpoch(
              recoveryTokenExpiresAtMs,
              isUtc: true,
            ),
            nextAction: _parseNextAction(nextActionCode),
          );
  }
}

int _stageCode(E2eeAccountRecoveryStage stage) => switch (stage) {
  E2eeAccountRecoveryStage.challenged => 1,
  E2eeAccountRecoveryStage.proofReady => 2,
  E2eeAccountRecoveryStage.authorized => 3,
};

E2eeAccountRecoveryStage _parseStage(int value) => switch (value) {
  1 => E2eeAccountRecoveryStage.challenged,
  2 => E2eeAccountRecoveryStage.proofReady,
  3 => E2eeAccountRecoveryStage.authorized,
  _ => throw const FormatException('账户恢复 checkpoint 阶段无效'),
};

int _nextActionCode(E2eeAccountRecoveryNextAction? action) => switch (action) {
  null => 0,
  E2eeAccountRecoveryNextAction.recoverResume => 1,
  E2eeAccountRecoveryNextAction.recoverReplace => 2,
};

E2eeAccountRecoveryNextAction _parseNextAction(int value) => switch (value) {
  1 => E2eeAccountRecoveryNextAction.recoverResume,
  2 => E2eeAccountRecoveryNextAction.recoverReplace,
  _ => throw const FormatException('账户恢复 checkpoint 下一步无效'),
};

int _writeBytes(Uint8List target, int offset, Uint8List value) {
  target.setRange(offset, offset + value.length, value);
  return offset + value.length;
}

int _writeUint32(ByteData view, int offset, int value) {
  if (value < 0 || value > 0xffffffff) {
    throw const FormatException('账户恢复 checkpoint uint32 越界');
  }
  view.setUint32(offset, value, Endian.big);
  return offset + 4;
}

int _writeUint64(ByteData view, int offset, int value) {
  if (value < 0) {
    throw const FormatException('账户恢复 checkpoint uint64 越界');
  }
  view.setUint64(offset, value, Endian.big);
  return offset + 8;
}

int _readUint32(ByteData view, int offset) {
  if (offset < 0 || offset + 4 > view.lengthInBytes) {
    throw const FormatException('账户恢复 checkpoint uint32 截断');
  }
  return view.getUint32(offset, Endian.big);
}

int _readUint64(ByteData view, int offset) {
  if (offset < 0 || offset + 8 > view.lengthInBytes) {
    throw const FormatException('账户恢复 checkpoint uint64 截断');
  }
  return view.getUint64(offset, Endian.big);
}

Uint8List _readBytes(Uint8List frame, int offset, int length) {
  if (offset < 0 || length < 0 || offset + length > frame.length) {
    throw const FormatException('账户恢复 checkpoint 字段截断');
  }
  return Uint8List.fromList(frame.sublist(offset, offset + length));
}

Uint8List _uuidBytes(String value) {
  final compact = value.replaceAll('-', '');
  if (compact.length != 32) {
    throw const FormatException('账户恢复 checkpoint UUID 长度无效');
  }
  final bytes = Uint8List(16);
  for (var index = 0; index < bytes.length; index++) {
    final byte = int.tryParse(
      compact.substring(index * 2, index * 2 + 2),
      radix: 16,
    );
    if (byte == null) {
      throw const FormatException('账户恢复 checkpoint UUID 字节无效');
    }
    bytes[index] = byte;
  }
  return bytes;
}

String _uuidString(Uint8List frame, int offset) {
  return _uuidStringFromBytes(_readBytes(frame, offset, 16));
}

String _uuidStringFromBytes(Uint8List bytes) {
  if (bytes.length != 16) {
    throw const FormatException('账户恢复 checkpoint UUID 字节数无效');
  }
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return _canonicalUuid(
    '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}',
    'uuid',
  );
}

String _canonicalUuid(String value, String field) {
  if (!_canonicalUuidV4Pattern.hasMatch(value)) {
    throw FormatException('$field 不是规范 UUID v4');
  }
  return value;
}

Uint8List _digest(Uint8List value) =>
    Uint8List.fromList(sha256.convert(value).bytes);

bool _startsWith(Uint8List value, Uint8List prefix) {
  if (value.length < prefix.length) return false;
  for (var index = 0; index < prefix.length; index++) {
    if (value[index] != prefix[index]) return false;
  }
  return true;
}

bool _sameBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

bool _allZero(Uint8List value) {
  var difference = 0;
  for (final byte in value) {
    difference |= byte;
  }
  return difference == 0;
}

void _clear(Uint8List? value) {
  value?.fillRange(0, value.length, 0);
}
