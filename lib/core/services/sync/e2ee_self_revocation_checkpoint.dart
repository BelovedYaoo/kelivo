import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:path/path.dart' as p;

import '../backup/restore_durability.dart';
import 'cloud_sync_types.dart';
import 'e2ee_account_trust_manifest.dart';

final class E2eeSelfRevocationCheckpoint {
  factory E2eeSelfRevocationCheckpoint({
    required CloudSyncAccountSession session,
    required CloudSyncSelfRevocationRequest request,
    required E2eeVerifiedMembership trustedHead,
  }) {
    if (session.deviceId != request.deviceId ||
        session.userId != trustedHead.userId ||
        session.keyEpoch != trustedHead.keyEpoch ||
        request.expectedGeneration != trustedHead.securityGeneration ||
        request.expectedKeyEpoch != trustedHead.keyEpoch ||
        !_sameBytes(
          request.expectedMembershipManifestDigest.bytes,
          trustedHead.digest,
        ) ||
        !trustedHead.members.any(
          (member) =>
              member.deviceId == session.deviceId &&
              member.keyVersion == session.deviceKeyVersion &&
              member.authGeneration == session.authGeneration,
        )) {
      throw const FormatException('自撤销 checkpoint 未绑定当前可信设备状态');
    }
    return E2eeSelfRevocationCheckpoint._(
      session: session,
      request: request,
      trustedHeadManifest: trustedHead.manifest,
      trustedHeadManifestDigest: trustedHead.digest,
      trustedHeadSecurityGeneration: trustedHead.securityGeneration,
      trustedHeadKeyEpoch: trustedHead.keyEpoch,
    );
  }

  E2eeSelfRevocationCheckpoint._({
    required this.session,
    required this.request,
    required Uint8List trustedHeadManifest,
    required Uint8List trustedHeadManifestDigest,
    required this.trustedHeadSecurityGeneration,
    required this.trustedHeadKeyEpoch,
  }) : trustedHeadManifest = Uint8List.fromList(
         trustedHeadManifest,
       ).asUnmodifiableView(),
       trustedHeadManifestDigest = Uint8List.fromList(
         trustedHeadManifestDigest,
       ).asUnmodifiableView() {
    if (this.trustedHeadManifest.isEmpty ||
        this.trustedHeadManifest.length >
            e2eeAccountTrustManifestMaximumLength ||
        this.trustedHeadManifestDigest.length != 32 ||
        !_sameBytes(
          sha256.convert(this.trustedHeadManifest).bytes,
          this.trustedHeadManifestDigest,
        ) ||
        trustedHeadSecurityGeneration != request.expectedGeneration ||
        trustedHeadKeyEpoch != request.expectedKeyEpoch ||
        session.deviceId != request.deviceId ||
        session.keyEpoch != trustedHeadKeyEpoch) {
      throw const FormatException('自撤销 checkpoint 可信头无效');
    }
  }

  final CloudSyncAccountSession session;
  final CloudSyncSelfRevocationRequest request;
  final Uint8List trustedHeadManifest;
  final Uint8List trustedHeadManifestDigest;
  final int trustedHeadSecurityGeneration;
  final int trustedHeadKeyEpoch;
}

final class E2eeSelfRevocationCheckpointStore {
  E2eeSelfRevocationCheckpointStore({
    required Directory installationRoot,
    KelivoSecureCore secureCore = const KelivoSecureCore(),
    RestoreDurability? durability,
  }) : _installationRoot = Directory(
         p.normalize(p.absolute(installationRoot.path)),
       ),
       _secureCore = secureCore,
       _durability = durability ?? RestorePlatformDurability();

  static const _version = 1;
  static const _recordEpoch = 1;
  static const _maximumPlaintextBytes = 128 * 1024;
  static const _maximumEnvelopeBytes = _maximumPlaintextBytes + 80;
  static const _headerLength = 16;
  static const _directoryName = '.kelivo-self-revocation-v1';
  static const _slotDomain = 'kelivo.self-revocation.checkpoint.slot.v1';
  static const _recordDomain = 'kelivo.self-revocation.checkpoint.record.v1';
  static const _aadDomain = 'kelivo.self-revocation.checkpoint.aad.v1';
  static final Uint8List _magic = Uint8List.fromList(
    ascii.encode('KELVSR01'),
  );
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final Random _random = Random.secure();

  final Directory _installationRoot;
  final KelivoSecureCore _secureCore;
  final RestoreDurability _durability;

  Future<E2eeSelfRevocationCheckpoint> write(
    E2eeSelfRevocationCheckpoint checkpoint,
  ) async {
    final mutationId = checkpoint.request.mutationId;
    final target = _checkpointFile(mutationId);
    final existing = await read(
      deviceId: checkpoint.request.deviceId,
      mutationId: mutationId,
    );
    if (existing != null) {
      if (_sameBytes(_encode(existing), _encode(checkpoint))) return existing;
      throw StateError('自撤销 checkpoint 已存在且内容不同');
    }

    final plaintext = _encode(checkpoint);
    Uint8List? envelope;
    File? temporary;
    try {
      if (plaintext.length > _maximumPlaintextBytes) {
        throw const FormatException('自撤销 checkpoint 明文超过协议上限');
      }
      envelope = await _withKey(
        mutationId,
        createMissing: true,
        action: (key) => _secureCore.sealRecord(
          key,
          recordId: _identifier(_recordDomain, mutationId),
          epoch: _recordEpoch,
          associatedData: _associatedData(
            deviceId: checkpoint.request.deviceId,
            mutationId: mutationId,
          ),
          plaintext: plaintext,
        ),
      );
      final frame = _encodeFrame(envelope);
      final directory = await _requireDirectory(create: true);
      temporary = File(
        p.join(directory.path, '.$mutationId-${_randomHex(16)}.next'),
      );
      await temporary.writeAsBytes(frame, flush: true);
      await _durability.restrictFile(temporary);
      await _durability.syncFile(temporary, fullBarrier: true);
      await _durability.renameAndSync(
        source: temporary,
        targetPath: target.path,
      );
      final published = await read(
        deviceId: checkpoint.request.deviceId,
        mutationId: mutationId,
      );
      if (published == null ||
          !_sameBytes(_encode(published), _encode(checkpoint))) {
        throw StateError('自撤销 checkpoint 发布后校验失败');
      }
      return published;
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
      envelope?.fillRange(0, envelope.length, 0);
      final pending = temporary;
      if (pending != null && await pending.exists()) {
        await pending.delete();
      }
    }
  }

  Future<E2eeSelfRevocationCheckpoint?> read({
    required String deviceId,
    required String mutationId,
  }) async {
    _requireUuid(deviceId, 'deviceId');
    _requireUuid(mutationId, 'mutationId');
    final directory = await _requireDirectory(create: false);
    if (directory == null) return null;
    final file = _checkpointFile(mutationId);
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.file) {
      throw StateError('自撤销 checkpoint 路径类型无效');
    }
    final frame = await file.readAsBytes();
    Uint8List? envelope;
    Uint8List? plaintext;
    try {
      envelope = _decodeFrame(frame);
      plaintext = await _withKey(
        mutationId,
        createMissing: false,
        action: (key) => _secureCore.openRecord(
          key,
          recordId: _identifier(_recordDomain, mutationId),
          epoch: _recordEpoch,
          associatedData: _associatedData(
            deviceId: deviceId,
            mutationId: mutationId,
          ),
          envelope: envelope!,
        ),
      );
      final checkpoint = _decode(plaintext);
      if (checkpoint.request.deviceId != deviceId ||
          checkpoint.request.mutationId != mutationId) {
        throw const FormatException('自撤销 checkpoint 与擦除意图不匹配');
      }
      return checkpoint;
    } finally {
      frame.fillRange(0, frame.length, 0);
      envelope?.fillRange(0, envelope.length, 0);
      plaintext?.fillRange(0, plaintext.length, 0);
    }
  }

  Future<T> _withKey<T>(
    String mutationId, {
    required bool createMissing,
    required Future<T> Function(KelivoKeyHandle key) action,
  }) async {
    final slotId = _identifier(_slotDomain, mutationId);
    final KelivoKeyHandle key;
    if (createMissing) {
      try {
        key = await _secureCore.createSlot(slotId);
      } on KelivoSecureCoreException catch (error) {
        if (error.status != KelivoSecureCoreStatus.slotAlreadyExists) rethrow;
        key = await _secureCore.openSlot(slotId);
      }
    } else {
      key = await _secureCore.openSlot(slotId);
    }
    Object? primaryError;
    StackTrace? primaryStackTrace;
    T? result;
    try {
      result = await action(key);
    } catch (error, stackTrace) {
      primaryError = error;
      primaryStackTrace = stackTrace;
    }
    try {
      await _secureCore.close(key);
    } catch (error, stackTrace) {
      if (primaryError == null) {
        primaryError = error;
        primaryStackTrace = stackTrace;
      }
    }
    if (primaryError != null && primaryStackTrace != null) {
      Error.throwWithStackTrace(primaryError, primaryStackTrace);
    }
    return result as T;
  }

  Future<Directory?> _requireDirectory({required bool create}) async {
    final rootType = await FileSystemEntity.type(
      _installationRoot.path,
      followLinks: false,
    );
    if (rootType != FileSystemEntityType.directory) {
      throw StateError('自撤销 checkpoint 安装根目录无效');
    }
    final directory = Directory(p.join(_installationRoot.path, _directoryName));
    final type = await FileSystemEntity.type(directory.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      if (!create) return null;
      await directory.create();
      await _durability.restrictDirectory(directory);
      await _durability.syncDirectory(_installationRoot, fullBarrier: true);
      return directory;
    }
    if (type != FileSystemEntityType.directory) {
      throw StateError('自撤销 checkpoint 存储目录无效');
    }
    return directory;
  }

  File _checkpointFile(String mutationId) {
    _requireUuid(mutationId, 'mutationId');
    return File(
      p.join(_installationRoot.path, _directoryName, '$mutationId.bin'),
    );
  }
}

Uint8List _encode(E2eeSelfRevocationCheckpoint checkpoint) {
  final request = checkpoint.request;
  final json = <String, Object?>{
    'version': 1,
    'session': checkpoint.session.toJson(),
    'request': <String, Object?>{
      'deviceId': request.deviceId,
      'mutationId': request.mutationId,
      'operationId': request.operationId,
      'expectedGeneration': request.expectedGeneration,
      'expectedKeyEpoch': request.expectedKeyEpoch,
      'expectedMembershipManifestDigest':
          request.expectedMembershipManifestDigest.encoded,
      'expiresAt': request.expiresAt.toIso8601String(),
      'continuationToken': request.continuationToken.value,
      'intentDigest': _encodeBinary(request.intentDigest),
      'intentSignature': _encodeBinary(request.intentSignature),
    },
    'trustedHead': <String, Object?>{
      'securityGeneration': checkpoint.trustedHeadSecurityGeneration,
      'keyEpoch': checkpoint.trustedHeadKeyEpoch,
      'manifest': _encodeBinary(checkpoint.trustedHeadManifest),
      'manifestDigest': _encodeBinary(checkpoint.trustedHeadManifestDigest),
    },
  };
  return Uint8List.fromList(utf8.encode(jsonEncode(json)));
}

E2eeSelfRevocationCheckpoint _decode(Uint8List plaintext) {
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(plaintext, allowMalformed: false));
  } on FormatException {
    throw const FormatException('自撤销 checkpoint JSON 无效');
  }
  final root = _exactMap(decoded, <String>{'version', 'session', 'request', 'trustedHead'});
  if (root['version'] != 1) {
    throw const FormatException('自撤销 checkpoint 版本无效');
  }
  final session = CloudSyncAccountSession.fromJson(
    _exactMap(root['session'], CloudSyncAccountSessionJsonKeys.all),
  );
  final requestJson = _exactMap(root['request'], const <String>{
    'deviceId',
    'mutationId',
    'operationId',
    'expectedGeneration',
    'expectedKeyEpoch',
    'expectedMembershipManifestDigest',
    'expiresAt',
    'continuationToken',
    'intentDigest',
    'intentSignature',
  });
  final request = CloudSyncSelfRevocationRequest(
    deviceId: _string(requestJson, 'deviceId'),
    mutationId: _string(requestJson, 'mutationId'),
    operationId: _string(requestJson, 'operationId'),
    expectedGeneration: _integer(requestJson, 'expectedGeneration'),
    expectedKeyEpoch: _integer(requestJson, 'expectedKeyEpoch'),
    expectedMembershipManifestDigest: CloudSyncMembershipManifestDigest.parse(
      _string(requestJson, 'expectedMembershipManifestDigest'),
    ),
    expiresAt: _timestamp(requestJson, 'expiresAt'),
    continuationToken: CloudSyncSelfRevocationContinuationToken.parse(
      _string(requestJson, 'continuationToken'),
    ),
    intentDigest: _binary(requestJson, 'intentDigest', exactLength: 32),
    intentSignature: _binary(
      requestJson,
      'intentSignature',
      exactLength: cloudSyncSelfRevocationIntentSignatureBytes,
    ),
  );
  final head = _exactMap(root['trustedHead'], const <String>{
    'securityGeneration',
    'keyEpoch',
    'manifest',
    'manifestDigest',
  });
  return E2eeSelfRevocationCheckpoint._(
    session: session,
    request: request,
    trustedHeadManifest: _binary(
      head,
      'manifest',
      maximumLength: e2eeAccountTrustManifestMaximumLength,
    ),
    trustedHeadManifestDigest: _binary(
      head,
      'manifestDigest',
      exactLength: 32,
    ),
    trustedHeadSecurityGeneration: _integer(head, 'securityGeneration'),
    trustedHeadKeyEpoch: _integer(head, 'keyEpoch'),
  );
}

Uint8List _encodeFrame(Uint8List envelope) {
  if (envelope.isEmpty || envelope.length > E2eeSelfRevocationCheckpointStore._maximumEnvelopeBytes) {
    throw const FormatException('自撤销 checkpoint 密文长度无效');
  }
  final frame = Uint8List(E2eeSelfRevocationCheckpointStore._headerLength + envelope.length);
  frame.setRange(0, E2eeSelfRevocationCheckpointStore._magic.length, E2eeSelfRevocationCheckpointStore._magic);
  final fields = ByteData.sublistView(frame);
  fields.setUint32(8, E2eeSelfRevocationCheckpointStore._version, Endian.big);
  fields.setUint32(12, envelope.length, Endian.big);
  frame.setRange(E2eeSelfRevocationCheckpointStore._headerLength, frame.length, envelope);
  return frame;
}

Uint8List _decodeFrame(Uint8List frame) {
  if (frame.length < E2eeSelfRevocationCheckpointStore._headerLength ||
      frame.length > E2eeSelfRevocationCheckpointStore._headerLength + E2eeSelfRevocationCheckpointStore._maximumEnvelopeBytes ||
      !_sameBytes(frame.sublist(0, 8), E2eeSelfRevocationCheckpointStore._magic)) {
    throw const FormatException('自撤销 checkpoint 帧无效');
  }
  final fields = ByteData.sublistView(frame);
  final version = fields.getUint32(8, Endian.big);
  final length = fields.getUint32(12, Endian.big);
  if (version != E2eeSelfRevocationCheckpointStore._version ||
      length < 1 ||
      length > E2eeSelfRevocationCheckpointStore._maximumEnvelopeBytes ||
      frame.length != E2eeSelfRevocationCheckpointStore._headerLength + length) {
    throw const FormatException('自撤销 checkpoint 帧头无效');
  }
  return Uint8List.sublistView(frame, E2eeSelfRevocationCheckpointStore._headerLength);
}

Uint8List _identifier(String domain, String mutationId) {
  return Uint8List.fromList(
    sha256.convert(utf8.encode('$domain\u0000$mutationId')).bytes.sublist(0, 16),
  );
}

Uint8List _associatedData({required String deviceId, required String mutationId}) {
  return Uint8List.fromList(
    utf8.encode('${E2eeSelfRevocationCheckpointStore._aadDomain}\u0000$deviceId\u0000$mutationId'),
  );
}

Map<String, Object?> _exactMap(Object? value, Set<String> keys) {
  if (value is! Map<String, Object?> ||
      value.length != keys.length ||
      !value.keys.toSet().containsAll(keys)) {
    throw const FormatException('自撤销 checkpoint 字段集合无效');
  }
  return value;
}

String _string(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! String || value.isEmpty) {
    throw FormatException('自撤销 checkpoint $field 无效');
  }
  return value;
}

int _integer(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! int) throw FormatException('自撤销 checkpoint $field 无效');
  return value;
}

DateTime _timestamp(Map<String, Object?> json, String field) {
  final raw = _string(json, field);
  final parsed = DateTime.tryParse(raw);
  if (parsed == null || !parsed.isUtc || parsed.toIso8601String() != raw) {
    throw FormatException('自撤销 checkpoint $field 时间无效');
  }
  return parsed;
}

String _encodeBinary(List<int> value) => base64Url.encode(value).replaceAll('=', '');

Uint8List _binary(
  Map<String, Object?> json,
  String field, {
  int? exactLength,
  int? maximumLength,
}) {
  final raw = _string(json, field);
  if (raw.contains('=') || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(raw)) {
    throw FormatException('自撤销 checkpoint $field 编码无效');
  }
  try {
    final padding = '=' * ((4 - raw.length % 4) % 4);
    final decoded = Uint8List.fromList(base64Url.decode('$raw$padding'));
    if (_encodeBinary(decoded) != raw ||
        (exactLength != null && decoded.length != exactLength) ||
        (maximumLength != null &&
            (decoded.isEmpty || decoded.length > maximumLength))) {
      throw const FormatException();
    }
    return decoded;
  } on FormatException {
    throw FormatException('自撤销 checkpoint $field 编码无效');
  }
}

void _requireUuid(String value, String field) {
  if (!E2eeSelfRevocationCheckpointStore._uuidPattern.hasMatch(value)) {
    throw FormatException('自撤销 checkpoint $field 无效');
  }
}

String _randomHex(int byteLength) {
  final bytes = Uint8List(byteLength);
  for (var index = 0; index < bytes.length; index++) {
    bytes[index] = E2eeSelfRevocationCheckpointStore._random.nextInt(256);
  }
  try {
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  } finally {
    bytes.fillRange(0, bytes.length, 0);
  }
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

abstract final class CloudSyncAccountSessionJsonKeys {
  static const all = <String>{
    'version',
    'baseUrl',
    'token',
    'tokenExpiresAt',
    'keyEpoch',
    'authGeneration',
    'sessionGeneration',
    'userId',
    'loginName',
    'displayName',
    'role',
    'attachmentQuotaBytes',
    'deviceId',
    'deviceName',
    'platform',
    'clientVersion',
    'deviceKeyVersion',
    'deviceCreatedAt',
    'securityBootstrap',
  };
}
