import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../backup/restore_durability.dart';

enum E2eeDataRekeyStageArtifactState { requestPending, confirmed }

final class E2eeDataRekeyStageArtifactSnapshot {
  E2eeDataRekeyStageArtifactSnapshot._({
    required this.state,
    required Uint8List envelope,
  }) : envelope = Uint8List.fromList(envelope);

  final E2eeDataRekeyStageArtifactState state;
  final Uint8List envelope;
}

final class E2eeDataRekeyStageStore {
  E2eeDataRekeyStageStore({
    required Directory installationRoot,
    RestoreDurability? durability,
  }) : _installationRoot = Directory(
         p.normalize(p.absolute(installationRoot.path)),
       ),
       _durability = durability ?? RestorePlatformDurability();

  static const maximumRequestEnvelopeLength = 1049600;
  static const maximumConfirmedEnvelopeLength = 1024;
  static const _storeDirectoryName = '.kelivo-data-rekey-v1';
  static const _locatorDomain = 'kelivo.data-rekey.stage.locator.v1';
  static const _frameHeaderLength = 44;
  static const _lockFileName = '.lock';
  static final Uint8List _frameMagic = Uint8List.fromList(
    ascii.encode('KELVDR01'),
  );
  static final RegExp _canonicalUuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final RegExp _artifactFilePattern = RegExp(
    r'^([0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})\.(request|confirmed)$',
  );
  static final RegExp _temporaryFilePattern = RegExp(
    r'^\.[0-9a-f-]{36}-(?:request|confirmed)-[0-9a-f]{32}\.next$',
  );
  static final Random _secureRandom = Random.secure();

  final Directory _installationRoot;
  final RestoreDurability _durability;

  Future<List<String>> listArtifactIds({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
    required String operationId,
    required int maximumCount,
  }) {
    final operation = _requireCanonicalUuid(operationId, 'operationId');
    final limit = _requireMaximumCount(maximumCount);
    return _withOperationLock(
      normalizedBaseUrl: normalizedBaseUrl,
      normalizedLoginName: normalizedLoginName,
      operationId: operation,
      create: false,
      action: (directory) async {
        if (directory == null) return const <String>[];
        await _cleanupTemporaryFiles(directory);
        return _listArtifactIds(directory, maximumCount: limit);
      },
    );
  }

  Future<E2eeDataRekeyStageArtifactSnapshot?> readArtifact({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
    required String operationId,
    required String artifactId,
  }) {
    final operation = _requireCanonicalUuid(operationId, 'operationId');
    final artifact = _requireCanonicalUuid(artifactId, 'artifactId');
    return _withOperationLock(
      normalizedBaseUrl: normalizedBaseUrl,
      normalizedLoginName: normalizedLoginName,
      operationId: operation,
      create: false,
      action: (directory) async {
        if (directory == null) return null;
        await _cleanupTemporaryFiles(directory);
        final confirmed = await _readArtifactFile(
          _artifactFile(directory, artifact, confirmed: true),
          maximumLength: maximumConfirmedEnvelopeLength,
        );
        final requestFile = _artifactFile(
          directory,
          artifact,
          confirmed: false,
        );
        if (confirmed != null) {
          // 确认帧必须先由协议层验证；读取阶段不能因可篡改文件而删除待重放请求。
          await _readArtifactFile(
            requestFile,
            maximumLength: maximumRequestEnvelopeLength,
          );
          return E2eeDataRekeyStageArtifactSnapshot._(
            state: E2eeDataRekeyStageArtifactState.confirmed,
            envelope: confirmed,
          );
        }
        final request = await _readArtifactFile(
          requestFile,
          maximumLength: maximumRequestEnvelopeLength,
        );
        return request == null
            ? null
            : E2eeDataRekeyStageArtifactSnapshot._(
                state: E2eeDataRekeyStageArtifactState.requestPending,
                envelope: request,
              );
      },
    );
  }

  Future<void> writePendingArtifact({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
    required String operationId,
    required String artifactId,
    required int maximumCount,
    required Uint8List envelope,
  }) {
    final operation = _requireCanonicalUuid(operationId, 'operationId');
    final artifact = _requireCanonicalUuid(artifactId, 'artifactId');
    final limit = _requireMaximumCount(maximumCount);
    _requireEnvelopeLength(
      envelope,
      maximum: maximumRequestEnvelopeLength,
      code: 'data_rekey_stage_store_request_length',
    );
    final copiedEnvelope = Uint8List.fromList(envelope);
    return _withOperationLock(
      normalizedBaseUrl: normalizedBaseUrl,
      normalizedLoginName: normalizedLoginName,
      operationId: operation,
      create: true,
      action: (directory) async {
        final resolvedDirectory = directory!;
        await _cleanupTemporaryFiles(resolvedDirectory);
        final ids = await _listArtifactIds(
          resolvedDirectory,
          maximumCount: limit,
        );
        final confirmedFile = _artifactFile(
          resolvedDirectory,
          artifact,
          confirmed: true,
        );
        if (await _readArtifactFile(
              confirmedFile,
              maximumLength: maximumConfirmedEnvelopeLength,
            ) !=
            null) {
          throw StateError('data_rekey_stage_store_artifact_confirmed');
        }
        final target = _artifactFile(
          resolvedDirectory,
          artifact,
          confirmed: false,
        );
        final current = await _readArtifactFile(
          target,
          maximumLength: maximumRequestEnvelopeLength,
        );
        if (current != null) {
          if (_sameBytes(current, copiedEnvelope)) return;
          throw StateError('data_rekey_stage_store_artifact_changed');
        }
        if (!ids.contains(artifact) && ids.length >= limit) {
          throw StateError('data_rekey_stage_store_artifact_count');
        }
        await _publishNewFile(
          directory: resolvedDirectory,
          target: target,
          bytes: _encodeFrame(copiedEnvelope),
        );
      },
    );
  }

  Future<void> confirmArtifact({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
    required String operationId,
    required String artifactId,
    required Uint8List expectedRequestDigest,
    required Uint8List confirmedEnvelope,
  }) {
    final operation = _requireCanonicalUuid(operationId, 'operationId');
    final artifact = _requireCanonicalUuid(artifactId, 'artifactId');
    if (expectedRequestDigest.length != 32) {
      throw const FormatException('data_rekey_stage_store_digest_length');
    }
    _requireEnvelopeLength(
      confirmedEnvelope,
      maximum: maximumConfirmedEnvelopeLength,
      code: 'data_rekey_stage_store_confirmation_length',
    );
    final copiedDigest = Uint8List.fromList(expectedRequestDigest);
    final copiedConfirmation = Uint8List.fromList(confirmedEnvelope);
    return _withOperationLock(
      normalizedBaseUrl: normalizedBaseUrl,
      normalizedLoginName: normalizedLoginName,
      operationId: operation,
      create: false,
      action: (directory) async {
        if (directory == null) {
          throw StateError('data_rekey_stage_store_operation_missing');
        }
        await _cleanupTemporaryFiles(directory);
        final requestFile = _artifactFile(
          directory,
          artifact,
          confirmed: false,
        );
        final request = await _readArtifactFile(
          requestFile,
          maximumLength: maximumRequestEnvelopeLength,
        );
        final confirmationFile = _artifactFile(
          directory,
          artifact,
          confirmed: true,
        );
        final currentConfirmation = await _readArtifactFile(
          confirmationFile,
          maximumLength: maximumConfirmedEnvelopeLength,
        );
        if (currentConfirmation != null &&
            !_sameBytes(currentConfirmation, copiedConfirmation)) {
          throw StateError('data_rekey_stage_store_confirmation_changed');
        }
        if (request != null) {
          final requestDigest = Uint8List.fromList(
            sha256.convert(request).bytes,
          );
          if (!_sameBytes(requestDigest, copiedDigest)) {
            throw StateError('data_rekey_stage_store_artifact_changed');
          }
        } else if (currentConfirmation == null) {
          throw StateError('data_rekey_stage_store_artifact_missing');
        }
        if (currentConfirmation == null) {
          await _publishNewFile(
            directory: directory,
            target: confirmationFile,
            bytes: _encodeFrame(copiedConfirmation),
          );
        }
        if (request != null) {
          await requestFile.delete();
          await _durability.syncDirectory(directory, fullBarrier: true);
        }
      },
    );
  }

  Future<void> clearOperation({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
    required String operationId,
    required int maximumCount,
  }) {
    final operation = _requireCanonicalUuid(operationId, 'operationId');
    final limit = _requireMaximumCount(maximumCount);
    return _withOperationLock(
      normalizedBaseUrl: normalizedBaseUrl,
      normalizedLoginName: normalizedLoginName,
      operationId: operation,
      create: false,
      action: (directory) async {
        if (directory == null) return;
        await _cleanupTemporaryFiles(directory);
        await _listArtifactIds(directory, maximumCount: limit);
        var changed = false;
        await for (final entity in directory.list(followLinks: false)) {
          final name = p.basename(entity.path);
          if (name == _lockFileName) continue;
          final type = await FileSystemEntity.type(
            entity.path,
            followLinks: false,
          );
          if (!_artifactFilePattern.hasMatch(name) ||
              type != FileSystemEntityType.file) {
            throw StateError('data_rekey_stage_store_owned_entry_unsafe');
          }
          await File(entity.path).delete();
          changed = true;
        }
        if (changed) {
          await _durability.syncDirectory(directory, fullBarrier: true);
        }
      },
    );
  }

  Future<List<String>> _listArtifactIds(
    Directory directory, {
    required int maximumCount,
  }) async {
    final ids = <String>{};
    await for (final entity in directory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (name == _lockFileName) continue;
      final match = _artifactFilePattern.firstMatch(name);
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (match == null || type != FileSystemEntityType.file) {
        throw StateError('data_rekey_stage_store_owned_entry_unsafe');
      }
      ids.add(match.group(1)!);
      if (ids.length > maximumCount) {
        throw StateError('data_rekey_stage_store_artifact_count');
      }
    }
    final sorted = ids.toList(growable: false)..sort();
    return List<String>.unmodifiable(sorted);
  }

  Future<T> _withOperationLock<T>({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
    required String operationId,
    required bool create,
    required Future<T> Function(Directory? directory) action,
  }) {
    final locator = _deriveLocator(
      normalizedBaseUrl: normalizedBaseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    final directory = Directory(
      p.join(_installationRoot.path, _storeDirectoryName, locator, operationId),
    );
    final lockKey = p.normalize(directory.absolute.path);
    return _DataRekeyStageCriticalSection.run(lockKey, () async {
      final type = await FileSystemEntity.type(
        directory.path,
        followLinks: false,
      );
      if (type == FileSystemEntityType.notFound) {
        if (!create) return action(null);
        await _createOwnedDirectory(directory);
      } else if (type != FileSystemEntityType.directory) {
        throw StateError('data_rekey_stage_store_operation_unsafe');
      }
      final lockFile = File(p.join(directory.path, _lockFileName));
      if (await FileSystemEntity.type(lockFile.path, followLinks: false) ==
          FileSystemEntityType.notFound) {
        try {
          await lockFile.create(exclusive: true);
          await _durability.restrictFile(lockFile);
          await _durability.syncDirectory(directory, fullBarrier: true);
        } on FileSystemException {
          if (await FileSystemEntity.type(lockFile.path, followLinks: false) !=
              FileSystemEntityType.file) {
            rethrow;
          }
        }
      }
      if (await FileSystemEntity.type(lockFile.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw StateError('data_rekey_stage_store_lock_unsafe');
      }
      final handle = await lockFile.open(mode: FileMode.append);
      try {
        await handle.lock(FileLock.exclusive);
        return await action(directory);
      } finally {
        try {
          await handle.unlock();
        } finally {
          await handle.close();
        }
      }
    });
  }

  Future<void> _createOwnedDirectory(Directory operationDirectory) async {
    final storeDirectory = Directory(
      p.join(_installationRoot.path, _storeDirectoryName),
    );
    final accountDirectory = operationDirectory.parent;
    for (final directory in <Directory>[
      storeDirectory,
      accountDirectory,
      operationDirectory,
    ]) {
      final type = await FileSystemEntity.type(
        directory.path,
        followLinks: false,
      );
      if (type == FileSystemEntityType.notFound) {
        await directory.create();
        await _durability.restrictDirectory(directory);
        await _durability.syncDirectory(directory.parent, fullBarrier: true);
      } else if (type != FileSystemEntityType.directory) {
        throw StateError('data_rekey_stage_store_directory_unsafe');
      }
    }
  }

  Future<Uint8List?> _readArtifactFile(
    File file, {
    required int maximumLength,
  }) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.file) {
      throw StateError('data_rekey_stage_store_artifact_unsafe');
    }
    final stat = await file.stat();
    if (stat.size <= _frameHeaderLength ||
        stat.size > _frameHeaderLength + maximumLength) {
      throw const FormatException('data_rekey_stage_store_frame_length');
    }
    final frame = await file.readAsBytes();
    if (frame.length != stat.size || !_startsWith(frame, _frameMagic)) {
      throw const FormatException('data_rekey_stage_store_frame_corrupt');
    }
    final fields = ByteData.sublistView(frame);
    final payloadLength = fields.getUint32(8, Endian.big);
    if (payloadLength < 1 ||
        payloadLength > maximumLength ||
        frame.length != _frameHeaderLength + payloadLength) {
      throw const FormatException('data_rekey_stage_store_frame_length');
    }
    final payload = Uint8List.fromList(
      Uint8List.sublistView(frame, _frameHeaderLength),
    );
    final expectedDigest = Uint8List.sublistView(frame, 12, 44);
    final actualDigest = Uint8List.fromList(sha256.convert(payload).bytes);
    if (!_sameBytes(actualDigest, expectedDigest)) {
      throw const FormatException('data_rekey_stage_store_frame_digest');
    }
    return payload;
  }

  Future<void> _publishNewFile({
    required Directory directory,
    required File target,
    required Uint8List bytes,
  }) async {
    if (await FileSystemEntity.type(target.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('data_rekey_stage_store_publish_target');
    }
    final targetBaseName = p.basename(target.path).replaceAll('.', '-');
    final temporary = await _createTemporaryFile(
      directory,
      targetBaseName: targetBaseName,
    );
    try {
      await _durability.restrictFile(temporary);
      await temporary.writeAsBytes(bytes, flush: true);
      await _durability.syncFile(temporary, fullBarrier: true);
      if (await FileSystemEntity.type(temporary.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw StateError('data_rekey_stage_store_temporary_changed');
      }
      await _durability.renameAndSync(
        source: temporary,
        targetPath: target.path,
      );
    } finally {
      if (await FileSystemEntity.type(temporary.path, followLinks: false) ==
          FileSystemEntityType.file) {
        await temporary.delete();
      }
    }
  }

  Future<File> _createTemporaryFile(
    Directory directory, {
    required String targetBaseName,
  }) async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final file = File(
        p.join(directory.path, '.$targetBaseName-${_randomHex(16)}.next'),
      );
      try {
        await file.create(exclusive: true);
        return file;
      } on FileSystemException {
        if (await FileSystemEntity.type(file.path, followLinks: false) ==
            FileSystemEntityType.notFound) {
          rethrow;
        }
      }
    }
    throw StateError('data_rekey_stage_store_temporary_collision');
  }

  Future<void> _cleanupTemporaryFiles(Directory directory) async {
    var changed = false;
    await for (final entity in directory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (!_temporaryFilePattern.hasMatch(name)) continue;
      if (await FileSystemEntity.type(entity.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw StateError('data_rekey_stage_store_temporary_unsafe');
      }
      await File(entity.path).delete();
      changed = true;
    }
    if (changed) {
      await _durability.syncDirectory(directory, fullBarrier: true);
    }
  }

  static Uint8List _encodeFrame(Uint8List envelope) {
    final frame = Uint8List(_frameHeaderLength + envelope.length);
    final fields = ByteData.sublistView(frame);
    frame.setRange(0, 8, _frameMagic);
    fields.setUint32(8, envelope.length, Endian.big);
    frame.setRange(12, 44, sha256.convert(envelope).bytes);
    frame.setRange(_frameHeaderLength, frame.length, envelope);
    return frame;
  }

  static String _deriveLocator({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
  }) {
    if (normalizedBaseUrl.isEmpty ||
        normalizedLoginName.isEmpty ||
        normalizedBaseUrl.contains('\u0000') ||
        normalizedLoginName.contains('\u0000')) {
      throw const FormatException('data_rekey_stage_store_locator_invalid');
    }
    final digest = sha256.convert(
      utf8.encode(
        '$_locatorDomain\u0000$normalizedBaseUrl\u0000$normalizedLoginName',
      ),
    );
    return digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static File _artifactFile(
    Directory directory,
    String artifactId, {
    required bool confirmed,
  }) {
    final suffix = confirmed ? 'confirmed' : 'request';
    return File(p.join(directory.path, '$artifactId.$suffix'));
  }

  static int _requireMaximumCount(int value) {
    if (value < 0 || value > 0x7fffffff) {
      throw const FormatException('data_rekey_stage_store_maximum_count');
    }
    return value;
  }

  static void _requireEnvelopeLength(
    Uint8List value, {
    required int maximum,
    required String code,
  }) {
    if (value.isEmpty || value.length > maximum) {
      throw FormatException(code);
    }
  }

  static String _requireCanonicalUuid(String value, String name) {
    if (!_canonicalUuidPattern.hasMatch(value)) {
      throw FormatException('$name 必须为规范 UUIDv4');
    }
    return value;
  }

  static bool _startsWith(Uint8List value, Uint8List prefix) {
    if (value.length < prefix.length) return false;
    var difference = 0;
    for (var index = 0; index < prefix.length; index++) {
      difference |= value[index] ^ prefix[index];
    }
    return difference == 0;
  }

  static bool _sameBytes(Uint8List left, Uint8List right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }

  static String _randomHex(int byteLength) {
    final value = StringBuffer();
    for (var index = 0; index < byteLength; index++) {
      value.write(_secureRandom.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return value.toString();
  }
}

abstract final class _DataRekeyStageCriticalSection {
  static final Map<String, Future<void>> _tails = <String, Future<void>>{};

  static Future<T> run<T>(String key, Future<T> Function() action) {
    final previous = _tails[key] ?? Future<void>.value();
    final release = Completer<void>();
    final current = release.future;
    _tails[key] = current;
    return _run(key, previous, current, release, action);
  }

  static Future<T> _run<T>(
    String key,
    Future<void> previous,
    Future<void> current,
    Completer<void> release,
    Future<T> Function() action,
  ) async {
    await previous;
    try {
      return await action();
    } finally {
      release.complete();
      if (identical(_tails[key], current)) {
        _tails.remove(key);
      }
    }
  }
}
