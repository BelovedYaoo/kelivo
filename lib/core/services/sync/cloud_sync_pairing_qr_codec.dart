import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:uuid/uuid.dart';

import 'cloud_sync_types.dart';

const cloudSyncPairingSecretBytes = 32;
const cloudSyncPairingQrFrameVersion = 1;
const cloudSyncPairingQrMinimumFrameBytes = 208;
const cloudSyncPairingQrMaximumLifetime = Duration(minutes: 5);

final class CloudSyncDevicePairingQrPayload {
  CloudSyncDevicePairingQrPayload._({
    required this.protocolVersion,
    required this.platform,
    required this.untrustedDeviceName,
    required this.untrustedClientVersion,
    required this.keyVersion,
    required this.expiresAt,
    required Uint8List pairingIdBytes,
    required Uint8List accountContextIdBytes,
    required Uint8List targetDeviceIdBytes,
    required Uint8List challenge,
    required Uint8List signingPublicKey,
    required Uint8List keyAgreementPublicKey,
    required this._pairingSecret,
  }) : pairingIdBytes = _immutableBytes(pairingIdBytes),
       accountContextIdBytes = _immutableBytes(accountContextIdBytes),
       targetDeviceIdBytes = _immutableBytes(targetDeviceIdBytes),
       challenge = _immutableBytes(challenge),
       signingPublicKey = _immutableBytes(signingPublicKey),
       keyAgreementPublicKey = _immutableBytes(keyAgreementPublicKey);

  /// 接管 secret 后由单一对象负责清零，避免调用方与 QR 流程各留一份所有权。
  factory CloudSyncDevicePairingQrPayload.takeOwnership({
    required int protocolVersion,
    required CloudSyncPlatform platform,
    required String untrustedDeviceName,
    required String untrustedClientVersion,
    required int keyVersion,
    required DateTime expiresAt,
    required String pairingId,
    required String accountContextId,
    required String targetDeviceId,
    required Uint8List challenge,
    required Uint8List signingPublicKey,
    required Uint8List keyAgreementPublicKey,
    required Uint8List pairingSecret,
    required DateTime now,
  }) {
    _requireMutableOwnedBytes(pairingSecret, 'pairingSecret');
    try {
      if (pairingSecret.length != cloudSyncPairingSecretBytes) {
        throw const FormatException('pairingSecret 长度无效');
      }
      return CloudSyncDevicePairingQrPayload._(
        protocolVersion: _requireProtocolVersion(protocolVersion),
        platform: platform,
        untrustedDeviceName: _requireDeviceName(untrustedDeviceName),
        untrustedClientVersion: _requireClientVersion(untrustedClientVersion),
        keyVersion: _requirePositiveInt32(keyVersion, 'keyVersion'),
        expiresAt: _requireActivePairingExpiry(expiresAt, now),
        pairingIdBytes: _parseCanonicalUuidV4(pairingId, 'pairingId'),
        accountContextIdBytes: _parseCanonicalUuidV4(
          accountContextId,
          'accountContextId',
        ),
        targetDeviceIdBytes: _parseCanonicalUuidV4(
          targetDeviceId,
          'targetDeviceId',
        ),
        challenge: _requireFixedBytes(
          challenge,
          cloudSyncDeviceChallengeBytes,
          'challenge',
        ),
        signingPublicKey: _requireFixedBytes(
          signingPublicKey,
          cloudSyncDevicePublicKeyBytes,
          'signingPublicKey',
        ),
        keyAgreementPublicKey: _requireFixedBytes(
          keyAgreementPublicKey,
          cloudSyncDevicePublicKeyBytes,
          'keyAgreementPublicKey',
        ),
        pairingSecret: pairingSecret,
      );
    } catch (_) {
      _clearBytes(pairingSecret);
      rethrow;
    }
  }

  factory CloudSyncDevicePairingQrPayload.fromCreatedPairing({
    required CloudSyncDevicePairingCreated created,
    required Uint8List pairingSecret,
    required DateTime now,
  }) {
    final target = created.targetDevice;
    return CloudSyncDevicePairingQrPayload.takeOwnership(
      protocolVersion: cloudSyncOpaqueProtocolVersion,
      platform: target.platform,
      untrustedDeviceName: target.name,
      untrustedClientVersion: target.clientVersion,
      keyVersion: target.keyVersion,
      expiresAt: created.expiresAt,
      pairingId: created.pairingId,
      accountContextId: created.accountContextId,
      targetDeviceId: target.id,
      challenge: created.challenge,
      signingPublicKey: target.signingPublicKey,
      keyAgreementPublicKey: target.keyAgreementPublicKey,
      pairingSecret: pairingSecret,
      now: now,
    );
  }

  final int protocolVersion;
  final CloudSyncPlatform platform;

  /// 来自待配对设备，仅供确认现场设备，不可作为授权依据。
  final String untrustedDeviceName;

  /// 来自待配对设备，仅供展示，不可作为协议能力判断依据。
  final String untrustedClientVersion;

  final int keyVersion;
  final DateTime expiresAt;
  final Uint8List pairingIdBytes;
  final Uint8List accountContextIdBytes;
  final Uint8List targetDeviceIdBytes;
  final Uint8List challenge;
  final Uint8List signingPublicKey;
  final Uint8List keyAgreementPublicKey;
  Uint8List? _pairingSecret;

  String get pairingId => Uuid.unparse(pairingIdBytes);

  String get accountContextId => Uuid.unparse(accountContextIdBytes);

  String get targetDeviceId => Uuid.unparse(targetDeviceIdBytes);

  bool get isDisposed => _pairingSecret == null;

  bool isExpiredAt(DateTime now) => !now.toUtc().isBefore(expiresAt);

  /// 审批前强制绑定本地账号，防止展示字段诱导用户跨账号批准。
  void requireAccountContextMatchesLocalUserId(String localUserId) {
    final localUserIdBytes = _parseCanonicalUuidV4(localUserId, 'localUserId');
    for (var index = 0; index < localUserIdBytes.length; index++) {
      if (localUserIdBytes[index] != accountContextIdBytes[index]) {
        throw const FormatException('配对 QR 与当前账号不匹配');
      }
    }
  }

  /// secure core 会取得返回缓冲区的所有权；取出后本对象不再持有 secret。
  Uint8List takePairingSecret() {
    final secret = _pairingSecret;
    if (secret == null) {
      throw StateError('配对 QR secret 已释放');
    }
    _pairingSecret = null;
    return secret;
  }

  void dispose() {
    final secret = _pairingSecret;
    if (secret == null) return;
    _clearBytes(secret);
    _pairingSecret = null;
  }

  Uint8List get _activePairingSecret {
    final secret = _pairingSecret;
    if (secret == null) {
      throw StateError('配对 QR secret 已释放');
    }
    return secret;
  }

  @override
  String toString() => 'CloudSyncDevicePairingQrPayload(<敏感数据已隐藏>)';
}

abstract final class CloudSyncDevicePairingQrCodec {
  static const _magic = <int>[0x4b, 0x4c, 0x50, 0x51];
  static const _versionOffset = 4;
  static const _flagsOffset = 5;
  static const _totalLengthOffset = 6;
  static const _protocolVersionOffset = 8;
  static const _platformOffset = 12;
  static const _deviceNameLengthOffset = 13;
  static const _clientVersionLengthOffset = 14;
  static const _reservedOffset = 15;
  static const _keyVersionOffset = 16;
  static const _expiresAtOffset = 20;
  static const _pairingIdOffset = 28;
  static const _accountContextIdOffset = 44;
  static const _targetDeviceIdOffset = 60;
  static const _challengeOffset = 76;
  static const _signingPublicKeyOffset = 108;
  static const _keyAgreementPublicKeyOffset = 140;
  static const _pairingSecretOffset = 172;
  static const _displayFieldsOffset = 204;
  static const _crcBytes = 4;

  /// 返回帧包含 raw secret；完成 QR 渲染或传输后调用方必须清零缓冲区。
  static Uint8List encode(
    CloudSyncDevicePairingQrPayload payload, {
    required DateTime now,
  }) {
    _requireProtocolVersion(payload.protocolVersion);
    final expiresAt = _requireActivePairingExpiry(payload.expiresAt, now);
    final secret = payload._activePairingSecret;
    final deviceNameBytes = utf8.encode(payload.untrustedDeviceName);
    final clientVersionBytes = ascii.encode(payload.untrustedClientVersion);
    if (deviceNameBytes.length > 0xff || clientVersionBytes.length > 0xff) {
      throw const FormatException('配对 QR 展示字段编码长度越界');
    }
    final totalLength =
        _displayFieldsOffset +
        deviceNameBytes.length +
        clientVersionBytes.length +
        _crcBytes;
    if (totalLength > 0xffff) {
      throw const FormatException('配对 QR 总长度越界');
    }

    final frame = Uint8List(totalLength);
    try {
      frame.setRange(0, _magic.length, _magic);
      final bytes = ByteData.sublistView(frame);
      bytes.setUint8(_versionOffset, cloudSyncPairingQrFrameVersion);
      bytes.setUint8(_flagsOffset, 0);
      bytes.setUint16(_totalLengthOffset, totalLength, Endian.big);
      bytes.setUint32(
        _protocolVersionOffset,
        payload.protocolVersion,
        Endian.big,
      );
      bytes.setUint8(_platformOffset, _platformCode(payload.platform));
      bytes.setUint8(_deviceNameLengthOffset, deviceNameBytes.length);
      bytes.setUint8(_clientVersionLengthOffset, clientVersionBytes.length);
      bytes.setUint8(_reservedOffset, 0);
      bytes.setUint32(_keyVersionOffset, payload.keyVersion, Endian.big);
      bytes.setUint64(
        _expiresAtOffset,
        expiresAt.millisecondsSinceEpoch,
        Endian.big,
      );
      frame.setRange(
        _pairingIdOffset,
        _accountContextIdOffset,
        payload.pairingIdBytes,
      );
      frame.setRange(
        _accountContextIdOffset,
        _targetDeviceIdOffset,
        payload.accountContextIdBytes,
      );
      frame.setRange(
        _targetDeviceIdOffset,
        _challengeOffset,
        payload.targetDeviceIdBytes,
      );
      frame.setRange(
        _challengeOffset,
        _signingPublicKeyOffset,
        payload.challenge,
      );
      frame.setRange(
        _signingPublicKeyOffset,
        _keyAgreementPublicKeyOffset,
        payload.signingPublicKey,
      );
      frame.setRange(
        _keyAgreementPublicKeyOffset,
        _pairingSecretOffset,
        payload.keyAgreementPublicKey,
      );
      frame.setRange(_pairingSecretOffset, _displayFieldsOffset, secret);
      final clientVersionOffset = _displayFieldsOffset + deviceNameBytes.length;
      final crcOffset = clientVersionOffset + clientVersionBytes.length;
      frame.setRange(
        _displayFieldsOffset,
        clientVersionOffset,
        deviceNameBytes,
      );
      frame.setRange(clientVersionOffset, crcOffset, clientVersionBytes);
      bytes.setUint32(
        crcOffset,
        getCrc32(Uint8List.sublistView(frame, 0, crcOffset)),
        Endian.big,
      );
      return frame;
    } catch (_) {
      _clearBytes(frame);
      rethrow;
    }
  }

  /// 取得扫码帧所有权并始终清零，避免解析完成后原始扫码缓冲区继续留存 secret。
  static CloudSyncDevicePairingQrPayload decodeTakingOwnership(
    Uint8List frame, {
    required DateTime now,
  }) {
    _requireMutableOwnedBytes(frame, 'frame');
    try {
      if (frame.length < cloudSyncPairingQrMinimumFrameBytes ||
          frame.length > 0xffff) {
        throw const FormatException('配对 QR 帧长度无效');
      }
      for (var index = 0; index < _magic.length; index++) {
        if (frame[index] != _magic[index]) {
          throw const FormatException('配对 QR 帧 magic 无效');
        }
      }
      final bytes = ByteData.sublistView(frame);
      if (bytes.getUint8(_versionOffset) != cloudSyncPairingQrFrameVersion) {
        throw const FormatException('不支持的配对 QR 帧版本');
      }
      if (bytes.getUint8(_flagsOffset) != 0 ||
          bytes.getUint8(_reservedOffset) != 0) {
        throw const FormatException('配对 QR 帧保留字段无效');
      }
      if (bytes.getUint16(_totalLengthOffset, Endian.big) != frame.length) {
        throw const FormatException('配对 QR 总长度无效');
      }
      final deviceNameLength = bytes.getUint8(_deviceNameLengthOffset);
      final clientVersionLength = bytes.getUint8(_clientVersionLengthOffset);
      final expectedLength =
          _displayFieldsOffset +
          deviceNameLength +
          clientVersionLength +
          _crcBytes;
      if (expectedLength != frame.length) {
        throw const FormatException('配对 QR 展示字段长度无效');
      }
      final crcOffset = frame.length - _crcBytes;
      final expectedCrc = bytes.getUint32(crcOffset, Endian.big);
      final actualCrc = getCrc32(Uint8List.sublistView(frame, 0, crcOffset));
      if (expectedCrc != actualCrc) {
        throw const FormatException('配对 QR CRC 无效');
      }

      final protocolVersion = _requireProtocolVersion(
        bytes.getUint32(_protocolVersionOffset, Endian.big),
      );
      final platform = _platformFromCode(bytes.getUint8(_platformOffset));
      final keyVersion = _requirePositiveInt32(
        bytes.getUint32(_keyVersionOffset, Endian.big),
        'keyVersion',
      );
      final expiresAt = _requireActivePairingExpiry(
        _dateTimeFromMilliseconds(
          bytes.getUint64(_expiresAtOffset, Endian.big),
        ),
        now,
      );
      final pairingIdBytes = _readUuidV4(
        frame,
        _pairingIdOffset,
        _accountContextIdOffset,
        'pairingId',
      );
      final accountContextIdBytes = _readUuidV4(
        frame,
        _accountContextIdOffset,
        _targetDeviceIdOffset,
        'accountContextId',
      );
      final targetDeviceIdBytes = _readUuidV4(
        frame,
        _targetDeviceIdOffset,
        _challengeOffset,
        'targetDeviceId',
      );
      final clientVersionOffset = _displayFieldsOffset + deviceNameLength;
      final deviceName = _requireDeviceName(
        utf8.decode(
          Uint8List.sublistView(
            frame,
            _displayFieldsOffset,
            clientVersionOffset,
          ),
          allowMalformed: false,
        ),
      );
      final clientVersion = _requireClientVersion(
        ascii.decode(
          Uint8List.sublistView(frame, clientVersionOffset, crcOffset),
          allowInvalid: false,
        ),
      );
      final secret = Uint8List.fromList(
        Uint8List.sublistView(
          frame,
          _pairingSecretOffset,
          _displayFieldsOffset,
        ),
      );
      try {
        return CloudSyncDevicePairingQrPayload._(
          protocolVersion: protocolVersion,
          platform: platform,
          untrustedDeviceName: deviceName,
          untrustedClientVersion: clientVersion,
          keyVersion: keyVersion,
          expiresAt: expiresAt,
          pairingIdBytes: pairingIdBytes,
          accountContextIdBytes: accountContextIdBytes,
          targetDeviceIdBytes: targetDeviceIdBytes,
          challenge: Uint8List.sublistView(
            frame,
            _challengeOffset,
            _signingPublicKeyOffset,
          ),
          signingPublicKey: Uint8List.sublistView(
            frame,
            _signingPublicKeyOffset,
            _keyAgreementPublicKeyOffset,
          ),
          keyAgreementPublicKey: Uint8List.sublistView(
            frame,
            _keyAgreementPublicKeyOffset,
            _pairingSecretOffset,
          ),
          pairingSecret: secret,
        );
      } catch (_) {
        _clearBytes(secret);
        rethrow;
      }
    } finally {
      _clearBytes(frame);
    }
  }
}

final _clientVersionPattern = RegExp(r'^[0-9A-Za-z][0-9A-Za-z.+_-]*$');

Uint8List _parseCanonicalUuidV4(String value, String field) {
  final bytes = Uuid.parseAsByteList(value);
  if (Uuid.unparse(bytes) != value) {
    throw FormatException('$field 必须为规范小写 UUID');
  }
  _requireUuidV4Bytes(bytes, field);
  return bytes;
}

Uint8List _readUuidV4(Uint8List frame, int start, int end, String field) {
  final bytes = Uint8List.fromList(Uint8List.sublistView(frame, start, end));
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

int _requireProtocolVersion(int value) {
  if (value != cloudSyncOpaqueProtocolVersion) {
    throw const FormatException('不支持的配对协议版本');
  }
  return value;
}

int _requirePositiveInt32(int value, String field) {
  if (value < 1 || value > 0x7fffffff) {
    throw FormatException('$field 必须位于正 int32 范围');
  }
  return value;
}

String _requireDeviceName(String value) {
  final normalized = value.trim();
  if (value != normalized || normalized.isEmpty || normalized.length > 80) {
    throw const FormatException('deviceName 长度或规范形式无效');
  }
  return normalized;
}

String _requireClientVersion(String value) {
  if (value.isEmpty ||
      value.length > 32 ||
      !_clientVersionPattern.hasMatch(value)) {
    throw const FormatException('clientVersion 格式无效');
  }
  return value;
}

DateTime _requireActivePairingExpiry(DateTime expiresAt, DateTime now) {
  final normalized = expiresAt.toUtc();
  if (normalized.microsecondsSinceEpoch % Duration.microsecondsPerMillisecond !=
      0) {
    throw const FormatException('配对 QR 过期时间必须为毫秒精度');
  }
  final remainingMicroseconds =
      normalized.microsecondsSinceEpoch - now.toUtc().microsecondsSinceEpoch;
  if (normalized.millisecondsSinceEpoch <= 0 ||
      remainingMicroseconds <= 0 ||
      remainingMicroseconds >
          cloudSyncPairingQrMaximumLifetime.inMicroseconds) {
    throw const FormatException('配对 QR 已过期或有效期越界');
  }
  return normalized;
}

DateTime _dateTimeFromMilliseconds(int millisecondsSinceEpoch) {
  try {
    return DateTime.fromMillisecondsSinceEpoch(
      millisecondsSinceEpoch,
      isUtc: true,
    );
  } on ArgumentError {
    throw const FormatException('配对 QR 过期时间越界');
  }
}

Uint8List _requireFixedBytes(Uint8List value, int length, String field) {
  if (value.length != length) {
    throw FormatException('$field 长度无效');
  }
  return value;
}

Uint8List _immutableBytes(Uint8List value) {
  return Uint8List.fromList(value).asUnmodifiableView();
}

int _platformCode(CloudSyncPlatform platform) {
  return switch (platform) {
    CloudSyncPlatform.android => 1,
    CloudSyncPlatform.ios => 2,
    CloudSyncPlatform.macos => 3,
    CloudSyncPlatform.windows => 4,
    CloudSyncPlatform.linux => 5,
  };
}

CloudSyncPlatform _platformFromCode(int code) {
  return switch (code) {
    1 => CloudSyncPlatform.android,
    2 => CloudSyncPlatform.ios,
    3 => CloudSyncPlatform.macos,
    4 => CloudSyncPlatform.windows,
    5 => CloudSyncPlatform.linux,
    _ => throw const FormatException('配对 QR platform 无效'),
  };
}

void _requireMutableOwnedBytes(Uint8List value, String field) {
  if (value.isEmpty) return;
  final first = value.first;
  try {
    value[0] = first;
  } on UnsupportedError {
    throw ArgumentError('$field 必须为可清零缓冲区');
  }
}

void _clearBytes(Uint8List value) {
  value.fillRange(0, value.length, 0);
}
