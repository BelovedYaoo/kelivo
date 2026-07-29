import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../utils/app_directories.dart';
import '../backup/restore_durability.dart';
import 'cloud_sync_attachment_types.dart';

const _attachmentOwnedRootName = 'e2ee';
const _memoryRoot = 'memory://kelivo-e2ee-attachments/';
const _sha256Bytes = 32;
const _downloadPlaintextFileName = 'plaintext.part';

final _canonicalUuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final _sha256HexPattern = RegExp(r'^[0-9a-f]{64}$');
final _uploadChunkFilePattern = RegExp(
  r'^(0|[1-9][0-9]{0,2})-([0-9a-f-]{36})\.ciphertext$',
);

final class E2eeAttachmentFileLocation {
  E2eeAttachmentFileLocation._({
    required List<String> directorySegments,
    required this._fileName,
  }) : _directorySegments = List<String>.unmodifiable(directorySegments);

  factory E2eeAttachmentFileLocation.stagingUploadChunk({
    required CloudSyncAttachmentChunkIdentity chunk,
    required String mutationId,
  }) {
    final identity = chunk.identity;
    final mutation = _requireCanonicalUuidV4(mutationId, 'mutationId');
    return E2eeAttachmentFileLocation._(
      directorySegments: <String>[
        'staging',
        'upload',
        identity.attachmentId,
        identity.uploadId,
        identity.keyEpoch.toString(),
      ],
      fileName: '${chunk.chunkIndex}-$mutation.ciphertext',
    );
  }

  factory E2eeAttachmentFileLocation.content({
    required Uint8List contentSha256,
  }) {
    return E2eeAttachmentFileLocation._(
      directorySegments: const <String>['content'],
      fileName: _requireSha256(contentSha256, 'contentSha256').toHex(),
    );
  }

  final List<String> _directorySegments;
  final String _fileName;

  bool get _isContent =>
      _directorySegments.length == 1 && _directorySegments.single == 'content';

  List<String> get _relativeSegments => <String>[
    ..._directorySegments,
    _fileName,
  ];
}

final class E2eeAttachmentStoredFile {
  E2eeAttachmentStoredFile({
    required String storagePath,
    required int bytes,
    required Uint8List sha256,
  }) : storagePath = _requireStoragePath(storagePath),
       bytes = _requireByteLength(bytes),
       sha256 = _requireSha256(sha256, 'sha256');

  final String storagePath;
  final int bytes;
  final Uint8List sha256;
}

abstract interface class E2eeAttachmentFileStore {
  Future<E2eeAttachmentStoredFile> publish({
    required E2eeAttachmentFileLocation location,
    required Stream<List<int>> source,
  });

  Future<Uint8List> readVerified(E2eeAttachmentStoredFile storedFile);

  Future<Uint8List> readContentRange({
    required E2eeAttachmentStoredFile storedFile,
    required int offset,
    required int length,
  });

  Future<E2eeAttachmentVerifiedContent> openVerifiedContent({
    required E2eeAttachmentStoredFile storedFile,
    required List<int> chunkPlaintextBytes,
  });

  Future<void> verifyContent(E2eeAttachmentStoredFile storedFile);

  Future<String> resolveContentStoragePath(Uint8List contentSha256);

  Future<String> openDownloadPlaintextStaging({
    required CloudSyncAttachmentIdentity identity,
    required String? persistedStoragePath,
    required int confirmedPlaintextBytes,
  });

  Future<void> appendDownloadPlaintextChunk({
    required CloudSyncAttachmentIdentity identity,
    required String stagingPath,
    required int expectedOffset,
    required Uint8List plaintext,
  });

  Future<E2eeAttachmentStoredFile> publishDownloadPlaintext({
    required CloudSyncAttachmentIdentity identity,
    required String stagingPath,
    required int expectedPlaintextBytes,
    required Uint8List expectedSha256,
  });

  Future<void> deleteStaging({required String storagePath});
}

abstract interface class E2eeAttachmentVerifiedContent {
  Future<Uint8List> readChunk(int chunkIndex);

  Future<void> close();
}

final class E2eeAttachmentPlatformFileStore implements E2eeAttachmentFileStore {
  E2eeAttachmentPlatformFileStore({RestoreDurability? durability})
    : _durability = durability ?? RestorePlatformDurability();

  final RestoreDurability _durability;
  final Random _random = Random.secure();

  @override
  Future<E2eeAttachmentStoredFile> publish({
    required E2eeAttachmentFileLocation location,
    required Stream<List<int>> source,
  }) async {
    final directory = await _resolveLocationDirectory(
      location._directorySegments,
      createMissing: true,
    );
    if (directory == null) {
      throw StateError('e2ee_attachment_directory_missing');
    }
    final target = File(p.join(directory.path, location._fileName));
    final temporary = await _createTemporaryFile(
      directory,
      targetBaseName: location._fileName,
    );
    var temporaryExists = true;
    try {
      final integrity = await _writeTemporary(temporary, source);
      if (location._isContent &&
          integrity.sha256.toHex() != location._fileName) {
        throw const FormatException('e2ee_attachment_content_digest_mismatch');
      }
      final targetType = await FileSystemEntity.type(
        target.path,
        followLinks: false,
      );
      if (targetType == FileSystemEntityType.notFound) {
        await _durability.renameAndSync(
          source: temporary,
          targetPath: target.path,
        );
        temporaryExists = false;
        return E2eeAttachmentStoredFile(
          storagePath: target.absolute.path,
          bytes: integrity.bytes,
          sha256: integrity.sha256,
        );
      }
      if (targetType != FileSystemEntityType.file) {
        throw StateError('e2ee_attachment_publish_target_unsafe');
      }
      await _requireCanonicalFile(target, directory);
      final existing = await _measureFile(target);
      if (existing.bytes != integrity.bytes ||
          !_sameBytes(existing.sha256, integrity.sha256)) {
        throw StateError('e2ee_attachment_publish_conflict');
      }
      return E2eeAttachmentStoredFile(
        storagePath: target.absolute.path,
        bytes: existing.bytes,
        sha256: existing.sha256,
      );
    } finally {
      if (temporaryExists &&
          await FileSystemEntity.type(temporary.path, followLinks: false) !=
              FileSystemEntityType.notFound) {
        if (await FileSystemEntity.type(temporary.path, followLinks: false) !=
            FileSystemEntityType.file) {
          throw StateError('e2ee_attachment_temporary_unsafe');
        }
        await temporary.delete();
        await _durability.syncDirectory(directory, fullBarrier: true);
      }
    }
  }

  @override
  Future<Uint8List> readVerified(E2eeAttachmentStoredFile storedFile) async {
    _requireBufferedReadSize(storedFile.bytes);
    final resolved = await _resolveStoredPath(
      storedFile.storagePath,
      allowMissing: false,
    );
    final file = resolved.file;
    if (file == null) {
      throw FileSystemException(
        'e2ee_attachment_file_missing',
        storedFile.storagePath,
      );
    }
    final bytes = await file.readAsBytes();
    if (bytes.length != storedFile.bytes ||
        !_sameBytes(
          Uint8List.fromList(sha256.convert(bytes).bytes),
          storedFile.sha256,
        )) {
      throw const FormatException('e2ee_attachment_file_integrity');
    }
    return Uint8List.fromList(bytes);
  }

  @override
  Future<Uint8List> readContentRange({
    required E2eeAttachmentStoredFile storedFile,
    required int offset,
    required int length,
  }) async {
    _requireContentRange(storedFile, offset: offset, length: length);
    final resolved = await _resolveStoredPath(
      storedFile.storagePath,
      allowMissing: false,
    );
    if (resolved.staging) {
      throw StateError('e2ee_attachment_content_path_required');
    }
    final file = resolved.file!;
    _requireContentDigestPath(storedFile, file.path);
    final before = await file.length();
    if (before != storedFile.bytes) {
      throw const FormatException('e2ee_attachment_file_integrity');
    }
    final input = await file.open(mode: FileMode.read);
    try {
      await input.setPosition(offset);
      final bytes = await input.read(length);
      if (bytes.length != length || await file.length() != before) {
        throw const FormatException('e2ee_attachment_file_integrity');
      }
      return Uint8List.fromList(bytes);
    } finally {
      await input.close();
    }
  }

  @override
  Future<E2eeAttachmentVerifiedContent> openVerifiedContent({
    required E2eeAttachmentStoredFile storedFile,
    required List<int> chunkPlaintextBytes,
  }) async {
    final chunkLengths = _requireChunkLayout(storedFile, chunkPlaintextBytes);
    final resolved = await _resolveStoredPath(
      storedFile.storagePath,
      allowMissing: false,
    );
    if (resolved.staging) {
      throw StateError('e2ee_attachment_content_path_required');
    }
    final file = resolved.file!;
    _requireContentDigestPath(storedFile, file.path);
    final input = await file.open(mode: FileMode.read);
    try {
      final chunkDigests = await _verifyOpenedContent(
        input: input,
        storedFile: storedFile,
        chunkLengths: chunkLengths,
      );
      return _PlatformVerifiedContent(
        input: input,
        storedFile: storedFile,
        chunkLengths: chunkLengths,
        chunkDigests: chunkDigests,
      );
    } catch (error, stackTrace) {
      try {
        await input.close();
      } catch (cleanupError, cleanupStackTrace) {
        developer.log(
          'E2EE 附件认证读取打开失败后的文件句柄清理失败',
          name: 'Kelivo.E2eeAttachmentPlatformFileStore',
          error: cleanupError,
          stackTrace: cleanupStackTrace,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<void> verifyContent(E2eeAttachmentStoredFile storedFile) async {
    final resolved = await _resolveStoredPath(
      storedFile.storagePath,
      allowMissing: false,
    );
    if (resolved.staging) {
      throw StateError('e2ee_attachment_content_path_required');
    }
    final file = resolved.file!;
    _requireContentDigestPath(storedFile, file.path);
    final measured = await _measureFile(file);
    if (measured.bytes != storedFile.bytes ||
        !_sameBytes(measured.sha256, storedFile.sha256)) {
      throw const FormatException('e2ee_attachment_file_integrity');
    }
  }

  @override
  Future<String> resolveContentStoragePath(Uint8List contentSha256) async {
    final digest = _requireSha256(contentSha256, 'contentSha256');
    final contentDirectory = await _resolveLocationDirectory(const <String>[
      'content',
    ], createMissing: true);
    if (contentDirectory == null) {
      throw StateError('e2ee_attachment_directory_missing');
    }
    final target = File(p.join(contentDirectory.path, digest.toHex()));
    final targetType = await FileSystemEntity.type(
      target.path,
      followLinks: false,
    );
    if (targetType != FileSystemEntityType.notFound) {
      if (targetType != FileSystemEntityType.file) {
        throw StateError('e2ee_attachment_publish_target_unsafe');
      }
      await _requireCanonicalFile(target, contentDirectory);
    }
    return p.normalize(target.absolute.path);
  }

  @override
  Future<String> openDownloadPlaintextStaging({
    required CloudSyncAttachmentIdentity identity,
    required String? persistedStoragePath,
    required int confirmedPlaintextBytes,
  }) async {
    final confirmed = _requirePlaintextLength(
      confirmedPlaintextBytes,
      'confirmedPlaintextBytes',
    );
    final target = await _downloadPlaintextTarget(
      identity,
      createMissingDirectories: true,
    );
    final canonicalPath = p.normalize(target.absolute.path);
    if (persistedStoragePath != null) {
      _requireExactPlatformStoragePath(persistedStoragePath, canonicalPath);
    }

    var type = await FileSystemEntity.type(canonicalPath, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      if (confirmed != 0) {
        throw StateError('e2ee_attachment_staging_shorter_than_confirmed');
      }
      try {
        await target.create(exclusive: true);
      } on FileSystemException {
        type = await FileSystemEntity.type(canonicalPath, followLinks: false);
        if (type == FileSystemEntityType.notFound) rethrow;
      }
      type = await FileSystemEntity.type(canonicalPath, followLinks: false);
      if (type != FileSystemEntityType.file) {
        throw StateError('e2ee_attachment_plaintext_staging_unsafe');
      }
      await _durability.restrictFile(target);
      await _durability.syncFile(target, fullBarrier: true);
      await _durability.syncDirectory(target.parent, fullBarrier: true);
    }
    if (type != FileSystemEntityType.file) {
      throw StateError('e2ee_attachment_plaintext_staging_unsafe');
    }
    await _requireCanonicalFile(target, target.parent);

    final actualBytes = await target.length();
    if (actualBytes < confirmed) {
      throw StateError('e2ee_attachment_staging_shorter_than_confirmed');
    }
    if (actualBytes > confirmed) {
      final output = await target.open(mode: FileMode.append);
      try {
        await output.truncate(confirmed);
        await output.flush();
      } finally {
        await output.close();
      }
      await _durability.syncFile(target, fullBarrier: true);
    }
    if (await target.length() != confirmed) {
      throw StateError('e2ee_attachment_staging_recovery_length');
    }
    await _requireCanonicalFile(target, target.parent);
    return canonicalPath;
  }

  @override
  Future<void> appendDownloadPlaintextChunk({
    required CloudSyncAttachmentIdentity identity,
    required String stagingPath,
    required int expectedOffset,
    required Uint8List plaintext,
  }) async {
    final offset = _requirePlaintextLength(expectedOffset, 'expectedOffset');
    final chunk = _copyPlaintextChunk(plaintext);
    if (chunk.length >
        cloudSyncMaximumAttachmentTotalCiphertextBytes - offset) {
      throw const FormatException('e2ee_attachment_plaintext_total_too_large');
    }
    final file = await _requireDownloadPlaintextStaging(
      identity: identity,
      stagingPath: stagingPath,
      allowMissing: false,
    );
    if (file == null) {
      throw FileSystemException('e2ee_attachment_file_missing', stagingPath);
    }
    if (await file.length() != offset) {
      throw StateError('e2ee_attachment_plaintext_offset_mismatch');
    }
    final output = await file.open(mode: FileMode.append);
    try {
      await output.writeFrom(chunk);
      await output.flush();
    } finally {
      await output.close();
    }
    await _durability.syncFile(file, fullBarrier: true);
    if (await file.length() != offset + chunk.length) {
      throw StateError('e2ee_attachment_plaintext_append_length');
    }
    await _requireCanonicalFile(file, file.parent);
  }

  @override
  Future<E2eeAttachmentStoredFile> publishDownloadPlaintext({
    required CloudSyncAttachmentIdentity identity,
    required String stagingPath,
    required int expectedPlaintextBytes,
    required Uint8List expectedSha256,
  }) async {
    final expectedBytes = _requirePlaintextLength(
      expectedPlaintextBytes,
      'expectedPlaintextBytes',
    );
    final expectedDigest = _requireSha256(expectedSha256, 'expectedSha256');
    final staging = await _requireDownloadPlaintextStaging(
      identity: identity,
      stagingPath: stagingPath,
      allowMissing: true,
    );
    final contentDirectory = await _resolveLocationDirectory(const <String>[
      'content',
    ], createMissing: true);
    if (contentDirectory == null) {
      throw StateError('e2ee_attachment_directory_missing');
    }
    final target = File(p.join(contentDirectory.path, expectedDigest.toHex()));
    final targetType = await FileSystemEntity.type(
      target.path,
      followLinks: false,
    );
    if (targetType != FileSystemEntityType.notFound) {
      if (targetType != FileSystemEntityType.file) {
        throw StateError('e2ee_attachment_publish_target_unsafe');
      }
      await _requireCanonicalFile(target, contentDirectory);
      final existing = await _measureFile(target);
      if (!_matchesIntegrity(
        existing,
        expectedBytes: expectedBytes,
        expectedSha256: expectedDigest,
      )) {
        throw StateError('e2ee_attachment_publish_conflict');
      }
      if (staging != null) {
        await staging.delete();
        await _durability.syncDirectory(staging.parent, fullBarrier: true);
      }
      return E2eeAttachmentStoredFile(
        storagePath: target.absolute.path,
        bytes: existing.bytes,
        sha256: existing.sha256,
      );
    }
    if (staging == null) {
      throw FileSystemException('e2ee_attachment_file_missing', stagingPath);
    }
    final staged = await _measureFile(staging);
    if (!_matchesIntegrity(
      staged,
      expectedBytes: expectedBytes,
      expectedSha256: expectedDigest,
    )) {
      throw const FormatException('e2ee_attachment_plaintext_integrity');
    }
    await _durability.renameAndSync(source: staging, targetPath: target.path);
    await _requireCanonicalFile(target, contentDirectory);
    final published = await _measureFile(target);
    if (!_matchesIntegrity(
      published,
      expectedBytes: expectedBytes,
      expectedSha256: expectedDigest,
    )) {
      throw StateError('e2ee_attachment_published_content_integrity');
    }
    return E2eeAttachmentStoredFile(
      storagePath: target.absolute.path,
      bytes: published.bytes,
      sha256: published.sha256,
    );
  }

  @override
  Future<void> deleteStaging({required String storagePath}) async {
    final resolved = await _resolveStoredPath(storagePath, allowMissing: true);
    if (!resolved.staging) {
      throw StateError('e2ee_attachment_delete_not_staging');
    }
    final file = resolved.file;
    if (file == null) return;
    await file.delete();
    await _durability.syncDirectory(file.parent, fullBarrier: true);
  }

  Future<File> _downloadPlaintextTarget(
    CloudSyncAttachmentIdentity identity, {
    required bool createMissingDirectories,
  }) async {
    final directory = await _resolveLocationDirectory(
      _downloadPlaintextDirectorySegments(identity),
      createMissing: createMissingDirectories,
    );
    if (directory == null) {
      throw FileSystemException('e2ee_attachment_staging_directory_missing');
    }
    return File(p.join(directory.path, _downloadPlaintextFileName));
  }

  Future<File?> _requireDownloadPlaintextStaging({
    required CloudSyncAttachmentIdentity identity,
    required String stagingPath,
    required bool allowMissing,
  }) async {
    final root = await _ownedRoot();
    final expected = p.normalize(
      p.joinAll(<String>[
        root.path,
        ..._downloadPlaintextDirectorySegments(identity),
        _downloadPlaintextFileName,
      ]),
    );
    _requireExactPlatformStoragePath(stagingPath, expected);
    final resolved = await _resolveStoredPath(
      stagingPath,
      allowMissing: allowMissing,
    );
    if (!resolved.staging) {
      throw StateError('e2ee_attachment_plaintext_staging_required');
    }
    return resolved.file;
  }

  Future<_StoredPathResolution> _resolveStoredPath(
    String storagePath, {
    required bool allowMissing,
  }) async {
    final root = await _ownedRoot();
    final absolute = p.normalize(p.absolute(_requireStoragePath(storagePath)));
    if (!p.isAbsolute(storagePath) || !p.isWithin(root.path, absolute)) {
      throw StateError('e2ee_attachment_path_outside_owned_root');
    }
    final relativeSegments = p.split(p.relative(absolute, from: root.path));
    final staging = _requireOwnedRelativeSegments(relativeSegments);
    final directory = await _resolveLocationDirectory(
      relativeSegments.sublist(0, relativeSegments.length - 1),
      createMissing: false,
      root: root,
    );
    if (directory == null) {
      if (allowMissing) {
        return _StoredPathResolution(file: null, staging: staging);
      }
      throw FileSystemException('e2ee_attachment_file_missing', absolute);
    }
    final file = File(p.join(directory.path, relativeSegments.last));
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      if (allowMissing) {
        return _StoredPathResolution(file: null, staging: staging);
      }
      throw FileSystemException('e2ee_attachment_file_missing', absolute);
    }
    if (type != FileSystemEntityType.file) {
      throw StateError('e2ee_attachment_owned_file_unsafe');
    }
    await _requireCanonicalFile(file, directory);
    return _StoredPathResolution(file: file, staging: staging);
  }

  Future<Directory?> _resolveLocationDirectory(
    List<String> segments, {
    required bool createMissing,
    Directory? root,
  }) async {
    var current = root ?? await _ownedRoot();
    var canonical = p.normalize(await current.resolveSymbolicLinks());
    for (final segment in segments) {
      final child = await _ownedChildDirectory(
        parent: current,
        parentCanonicalPath: canonical,
        name: segment,
        createMissing: createMissing,
      );
      if (child == null) return null;
      current = child;
      canonical = p.normalize(p.join(canonical, segment));
    }
    return current;
  }

  Future<Directory> _ownedRoot() async {
    if (!AppDirectories.isAccountWorkspace) {
      throw StateError('e2ee_attachment_account_workspace_required');
    }
    final upload = await AppDirectories.getUploadDirectory();
    final uploadCanonical = p.normalize(await upload.resolveSymbolicLinks());
    final root = await _ownedChildDirectory(
      parent: upload,
      parentCanonicalPath: uploadCanonical,
      name: _attachmentOwnedRootName,
      createMissing: true,
    );
    return root ?? (throw StateError('e2ee_attachment_root_missing'));
  }

  Future<Directory?> _ownedChildDirectory({
    required Directory parent,
    required String parentCanonicalPath,
    required String name,
    required bool createMissing,
  }) async {
    _requirePathSegment(name);
    final directory = Directory(p.join(parent.path, name));
    var type = await FileSystemEntity.type(directory.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      if (!createMissing) return null;
      await directory.create();
      type = await FileSystemEntity.type(directory.path, followLinks: false);
      if (type != FileSystemEntityType.directory) {
        throw StateError('e2ee_attachment_owned_directory_unsafe');
      }
      await _durability.restrictDirectory(directory);
      await _durability.syncDirectory(parent, fullBarrier: true);
      type = await FileSystemEntity.type(directory.path, followLinks: false);
    }
    if (type != FileSystemEntityType.directory) {
      throw StateError('e2ee_attachment_owned_directory_unsafe');
    }
    final canonical = p.normalize(await directory.resolveSymbolicLinks());
    if (!p.equals(canonical, p.normalize(p.join(parentCanonicalPath, name)))) {
      throw StateError('e2ee_attachment_owned_directory_unsafe');
    }
    return directory;
  }

  Future<File> _createTemporaryFile(
    Directory directory, {
    required String targetBaseName,
  }) async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final temporary = File(
        p.join(directory.path, '.$targetBaseName-${_randomHex(16)}.next'),
      );
      try {
        await temporary.create(exclusive: true);
      } on FileSystemException {
        final type = await FileSystemEntity.type(
          temporary.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.notFound) rethrow;
        if (type != FileSystemEntityType.file) {
          throw StateError('e2ee_attachment_temporary_unsafe');
        }
        continue;
      }
      try {
        if (await FileSystemEntity.type(temporary.path, followLinks: false) !=
            FileSystemEntityType.file) {
          throw StateError('e2ee_attachment_temporary_unsafe');
        }
        await _durability.restrictFile(temporary);
        if (await FileSystemEntity.type(temporary.path, followLinks: false) !=
            FileSystemEntityType.file) {
          throw StateError('e2ee_attachment_temporary_unsafe');
        }
        return temporary;
      } catch (_) {
        if (await FileSystemEntity.type(temporary.path, followLinks: false) ==
            FileSystemEntityType.file) {
          await temporary.delete();
          await _durability.syncDirectory(directory, fullBarrier: true);
        }
        rethrow;
      }
    }
    throw StateError('e2ee_attachment_temporary_collision');
  }

  String _randomHex(int byteLength) {
    final value = StringBuffer();
    for (var index = 0; index < byteLength; index++) {
      value.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return value.toString();
  }

  Future<_FileIntegrity> _writeTemporary(
    File temporary,
    Stream<List<int>> source,
  ) async {
    final digestOutput = _SingleDigestSink();
    final digestInput = sha256.startChunkedConversion(digestOutput);
    final output = await temporary.open(mode: FileMode.writeOnly);
    var bytes = 0;
    try {
      await for (final sourceChunk in source) {
        final chunk = _copyByteChunk(sourceChunk);
        bytes += chunk.length;
        digestInput.add(chunk);
        await output.writeFrom(chunk);
      }
      digestInput.close();
      await output.flush();
    } finally {
      await output.close();
    }
    await _durability.syncFile(temporary, fullBarrier: true);
    if (await FileSystemEntity.type(temporary.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('e2ee_attachment_temporary_unsafe');
    }
    final integrity = _FileIntegrity(
      bytes: bytes,
      sha256: Uint8List.fromList(digestOutput.value.bytes),
    );
    final measured = await _measureFile(temporary);
    if (measured.bytes != integrity.bytes ||
        !_sameBytes(measured.sha256, integrity.sha256)) {
      throw StateError('e2ee_attachment_temporary_integrity');
    }
    return integrity;
  }

  Future<_FileIntegrity> _measureFile(File file) async {
    final before = await file.length();
    final digest = await sha256.bind(file.openRead()).first;
    final after = await file.length();
    if (before != after) {
      throw StateError('e2ee_attachment_file_changed_during_read');
    }
    return _FileIntegrity(
      bytes: after,
      sha256: Uint8List.fromList(digest.bytes),
    );
  }

  Future<void> _requireCanonicalFile(File file, Directory parent) async {
    final canonical = p.normalize(await file.resolveSymbolicLinks());
    final parentCanonical = p.normalize(await parent.resolveSymbolicLinks());
    if (!p.equals(canonical, p.join(parentCanonical, p.basename(file.path)))) {
      throw StateError('e2ee_attachment_owned_file_unsafe');
    }
  }
}

Future<List<Uint8List>> _verifyOpenedContent({
  required RandomAccessFile input,
  required E2eeAttachmentStoredFile storedFile,
  required List<int> chunkLengths,
}) async {
  if (await input.length() != storedFile.bytes) {
    throw const FormatException('e2ee_attachment_file_integrity');
  }
  final contentDigestOutput = _SingleDigestSink();
  final contentDigestInput = sha256.startChunkedConversion(contentDigestOutput);
  final chunkDigests = <Uint8List>[];
  var contentDigestClosed = false;
  var totalRead = 0;
  try {
    for (final chunkLength in chunkLengths) {
      final chunkDigestOutput = _SingleDigestSink();
      final chunkDigestInput = sha256.startChunkedConversion(chunkDigestOutput);
      var chunkDigestClosed = false;
      var remaining = chunkLength;
      try {
        while (remaining > 0) {
          final bytes = await input.read(min(64 * 1024, remaining));
          if (bytes.isEmpty) {
            throw const FormatException('e2ee_attachment_file_integrity');
          }
          try {
            contentDigestInput.add(bytes);
            chunkDigestInput.add(bytes);
          } finally {
            bytes.fillRange(0, bytes.length, 0);
          }
          remaining -= bytes.length;
          totalRead += bytes.length;
        }
        chunkDigestInput.close();
        chunkDigestClosed = true;
        chunkDigests.add(
          Uint8List.fromList(
            chunkDigestOutput.value.bytes,
          ).asUnmodifiableView(),
        );
      } finally {
        if (!chunkDigestClosed) chunkDigestInput.close();
      }
    }
    contentDigestInput.close();
    contentDigestClosed = true;
    if (totalRead != storedFile.bytes ||
        await input.length() != storedFile.bytes ||
        !_sameBytes(
          Uint8List.fromList(contentDigestOutput.value.bytes),
          storedFile.sha256,
        )) {
      throw const FormatException('e2ee_attachment_file_integrity');
    }
    await input.setPosition(0);
    return List<Uint8List>.unmodifiable(chunkDigests);
  } finally {
    if (!contentDigestClosed) contentDigestInput.close();
  }
}

final class _PlatformVerifiedContent implements E2eeAttachmentVerifiedContent {
  _PlatformVerifiedContent({
    required this._input,
    required this._storedFile,
    required this._chunkLengths,
    required this._chunkDigests,
  }) : _chunkOffsets = _chunkOffsetsFor(_chunkLengths);

  final RandomAccessFile _input;
  final E2eeAttachmentStoredFile _storedFile;
  final List<int> _chunkLengths;
  final List<Uint8List> _chunkDigests;
  final List<int> _chunkOffsets;

  Future<void> _operationTail = Future<void>.value();
  bool _acceptingOperations = true;
  bool _closed = false;
  Future<void>? _closeFuture;

  @override
  Future<Uint8List> readChunk(int chunkIndex) {
    if (chunkIndex < 0 || chunkIndex >= _chunkLengths.length) {
      return Future<Uint8List>.error(
        const FormatException('e2ee_attachment_chunk_index_invalid'),
      );
    }
    return _runWhileOpen(() async {
      Uint8List? plaintext;
      try {
        if (await _input.length() != _storedFile.bytes) {
          throw const FormatException('e2ee_attachment_file_integrity');
        }
        await _input.setPosition(_chunkOffsets[chunkIndex]);
        plaintext = await _input.read(_chunkLengths[chunkIndex]);
        if (plaintext.length != _chunkLengths[chunkIndex] ||
            !_sameBytes(
              Uint8List.fromList(sha256.convert(plaintext).bytes),
              _chunkDigests[chunkIndex],
            ) ||
            await _input.length() != _storedFile.bytes) {
          throw const FormatException('e2ee_attachment_file_integrity');
        }
        final transferred = plaintext;
        plaintext = null;
        return transferred;
      } finally {
        plaintext?.fillRange(0, plaintext.length, 0);
      }
    });
  }

  @override
  Future<void> close() {
    if (_closed) return Future<void>.value();
    final active = _closeFuture;
    if (active != null) return active;
    _acceptingOperations = false;
    late final Future<void> closing;
    closing = () async {
      try {
        await _operationTail;
        await _input.close();
        _closed = true;
      } finally {
        if (identical(_closeFuture, closing)) _closeFuture = null;
      }
    }();
    _closeFuture = closing;
    return closing;
  }

  Future<T> _runWhileOpen<T>(Future<T> Function() operation) {
    if (!_acceptingOperations) {
      return Future<T>.error(
        StateError('e2ee_attachment_verified_content_closed'),
      );
    }
    final previous = _operationTail;
    final completed = Completer<void>();
    _operationTail = completed.future;
    return () async {
      await previous;
      try {
        return await operation();
      } finally {
        completed.complete();
      }
    }();
  }
}

final class E2eeAttachmentMemoryFileStore implements E2eeAttachmentFileStore {
  final Map<String, Uint8List> _files = <String, Uint8List>{};

  @override
  Future<E2eeAttachmentStoredFile> publish({
    required E2eeAttachmentFileLocation location,
    required Stream<List<int>> source,
  }) async {
    final builder = BytesBuilder(copy: true);
    await for (final chunk in source) {
      builder.add(_copyByteChunk(chunk));
    }
    final bytes = builder.takeBytes();
    final storagePath = '$_memoryRoot${location._relativeSegments.join('/')}';
    final digest = Uint8List.fromList(sha256.convert(bytes).bytes);
    if (location._isContent && digest.toHex() != location._fileName) {
      throw const FormatException('e2ee_attachment_content_digest_mismatch');
    }
    final existing = _files[storagePath];
    if (existing != null && !_sameBytes(existing, bytes)) {
      throw StateError('e2ee_attachment_publish_conflict');
    }
    _files[storagePath] = Uint8List.fromList(bytes);
    return E2eeAttachmentStoredFile(
      storagePath: storagePath,
      bytes: bytes.length,
      sha256: digest,
    );
  }

  @override
  Future<Uint8List> readVerified(E2eeAttachmentStoredFile storedFile) async {
    _requireBufferedReadSize(storedFile.bytes);
    _memoryRelativeSegments(storedFile.storagePath);
    final bytes = _files[storedFile.storagePath];
    if (bytes == null) {
      throw FileSystemException(
        'e2ee_attachment_file_missing',
        storedFile.storagePath,
      );
    }
    if (bytes.length != storedFile.bytes ||
        !_sameBytes(
          Uint8List.fromList(sha256.convert(bytes).bytes),
          storedFile.sha256,
        )) {
      throw const FormatException('e2ee_attachment_file_integrity');
    }
    return Uint8List.fromList(bytes);
  }

  @override
  Future<Uint8List> readContentRange({
    required E2eeAttachmentStoredFile storedFile,
    required int offset,
    required int length,
  }) async {
    _requireContentRange(storedFile, offset: offset, length: length);
    final segments = _memoryRelativeSegments(storedFile.storagePath);
    if (segments.first != 'content') {
      throw StateError('e2ee_attachment_content_path_required');
    }
    _requireContentDigestPath(storedFile, segments.last);
    final bytes = _files[storedFile.storagePath];
    if (bytes == null || bytes.length != storedFile.bytes) {
      throw const FormatException('e2ee_attachment_file_integrity');
    }
    return Uint8List.fromList(bytes.sublist(offset, offset + length));
  }

  @override
  Future<E2eeAttachmentVerifiedContent> openVerifiedContent({
    required E2eeAttachmentStoredFile storedFile,
    required List<int> chunkPlaintextBytes,
  }) async {
    final chunkLengths = _requireChunkLayout(storedFile, chunkPlaintextBytes);
    final segments = _memoryRelativeSegments(storedFile.storagePath);
    if (segments.first != 'content') {
      throw StateError('e2ee_attachment_content_path_required');
    }
    _requireContentDigestPath(storedFile, segments.last);
    final bytes = _files[storedFile.storagePath];
    if (bytes == null ||
        bytes.length != storedFile.bytes ||
        !_sameBytes(
          Uint8List.fromList(sha256.convert(bytes).bytes),
          storedFile.sha256,
        )) {
      throw const FormatException('e2ee_attachment_file_integrity');
    }
    return _MemoryVerifiedContent(
      plaintext: Uint8List.fromList(bytes),
      chunkLengths: chunkLengths,
    );
  }

  @override
  Future<void> verifyContent(E2eeAttachmentStoredFile storedFile) async {
    final segments = _memoryRelativeSegments(storedFile.storagePath);
    if (segments.first != 'content') {
      throw StateError('e2ee_attachment_content_path_required');
    }
    _requireContentDigestPath(storedFile, segments.last);
    final bytes = _files[storedFile.storagePath];
    if (bytes == null ||
        bytes.length != storedFile.bytes ||
        !_sameBytes(
          Uint8List.fromList(sha256.convert(bytes).bytes),
          storedFile.sha256,
        )) {
      throw const FormatException('e2ee_attachment_file_integrity');
    }
  }

  @override
  Future<String> resolveContentStoragePath(Uint8List contentSha256) async {
    final digest = _requireSha256(contentSha256, 'contentSha256');
    return '${_memoryRoot}content/${digest.toHex()}';
  }

  @override
  Future<String> openDownloadPlaintextStaging({
    required CloudSyncAttachmentIdentity identity,
    required String? persistedStoragePath,
    required int confirmedPlaintextBytes,
  }) async {
    final confirmed = _requirePlaintextLength(
      confirmedPlaintextBytes,
      'confirmedPlaintextBytes',
    );
    final storagePath = _memoryDownloadPlaintextPath(identity);
    if (persistedStoragePath != null && persistedStoragePath != storagePath) {
      throw StateError('e2ee_attachment_staging_identity_mismatch');
    }
    final existing = _files[storagePath];
    if (existing == null) {
      if (confirmed != 0) {
        throw StateError('e2ee_attachment_staging_shorter_than_confirmed');
      }
      _files[storagePath] = Uint8List(0);
      return storagePath;
    }
    if (existing.length < confirmed) {
      throw StateError('e2ee_attachment_staging_shorter_than_confirmed');
    }
    if (existing.length > confirmed) {
      _files[storagePath] = Uint8List.fromList(existing.sublist(0, confirmed));
    }
    return storagePath;
  }

  @override
  Future<void> appendDownloadPlaintextChunk({
    required CloudSyncAttachmentIdentity identity,
    required String stagingPath,
    required int expectedOffset,
    required Uint8List plaintext,
  }) async {
    final offset = _requirePlaintextLength(expectedOffset, 'expectedOffset');
    final chunk = _copyPlaintextChunk(plaintext);
    if (chunk.length >
        cloudSyncMaximumAttachmentTotalCiphertextBytes - offset) {
      throw const FormatException('e2ee_attachment_plaintext_total_too_large');
    }
    _requireExactMemoryDownloadPath(identity, stagingPath);
    final existing = _files[stagingPath];
    if (existing == null) {
      throw FileSystemException('e2ee_attachment_file_missing', stagingPath);
    }
    if (existing.length != offset) {
      throw StateError('e2ee_attachment_plaintext_offset_mismatch');
    }
    final appended = BytesBuilder(copy: true)
      ..add(existing)
      ..add(chunk);
    _files[stagingPath] = appended.takeBytes();
  }

  @override
  Future<E2eeAttachmentStoredFile> publishDownloadPlaintext({
    required CloudSyncAttachmentIdentity identity,
    required String stagingPath,
    required int expectedPlaintextBytes,
    required Uint8List expectedSha256,
  }) async {
    final expectedBytes = _requirePlaintextLength(
      expectedPlaintextBytes,
      'expectedPlaintextBytes',
    );
    final expectedDigest = _requireSha256(expectedSha256, 'expectedSha256');
    _requireExactMemoryDownloadPath(identity, stagingPath);
    final contentPath = '${_memoryRoot}content/${expectedDigest.toHex()}';
    final existingContent = _files[contentPath];
    if (existingContent != null) {
      final existingDigest = Uint8List.fromList(
        sha256.convert(existingContent).bytes,
      );
      if (existingContent.length != expectedBytes ||
          !_sameBytes(existingDigest, expectedDigest)) {
        throw StateError('e2ee_attachment_publish_conflict');
      }
      _files.remove(stagingPath);
      return E2eeAttachmentStoredFile(
        storagePath: contentPath,
        bytes: existingContent.length,
        sha256: existingDigest,
      );
    }
    final staged = _files[stagingPath];
    if (staged == null) {
      throw FileSystemException('e2ee_attachment_file_missing', stagingPath);
    }
    final stagedDigest = Uint8List.fromList(sha256.convert(staged).bytes);
    if (staged.length != expectedBytes ||
        !_sameBytes(stagedDigest, expectedDigest)) {
      throw const FormatException('e2ee_attachment_plaintext_integrity');
    }
    _files.remove(stagingPath);
    _files[contentPath] = staged;
    return E2eeAttachmentStoredFile(
      storagePath: contentPath,
      bytes: staged.length,
      sha256: stagedDigest,
    );
  }

  @override
  Future<void> deleteStaging({required String storagePath}) async {
    final segments = _memoryRelativeSegments(storagePath);
    if (!_requireOwnedRelativeSegments(segments)) {
      throw StateError('e2ee_attachment_delete_not_staging');
    }
    _files.remove(storagePath);
  }
}

final class _MemoryVerifiedContent implements E2eeAttachmentVerifiedContent {
  _MemoryVerifiedContent({
    required this._plaintext,
    required this._chunkLengths,
  }) : _chunkOffsets = _chunkOffsetsFor(_chunkLengths);

  final Uint8List _plaintext;
  final List<int> _chunkLengths;
  final List<int> _chunkOffsets;
  bool _closed = false;

  @override
  Future<Uint8List> readChunk(int chunkIndex) async {
    if (_closed) {
      throw StateError('e2ee_attachment_verified_content_closed');
    }
    if (chunkIndex < 0 || chunkIndex >= _chunkLengths.length) {
      throw const FormatException('e2ee_attachment_chunk_index_invalid');
    }
    final offset = _chunkOffsets[chunkIndex];
    return Uint8List.fromList(
      _plaintext.sublist(offset, offset + _chunkLengths[chunkIndex]),
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _plaintext.fillRange(0, _plaintext.length, 0);
  }
}

final class _StoredPathResolution {
  const _StoredPathResolution({required this.file, required this.staging});

  final File? file;
  final bool staging;
}

final class _FileIntegrity {
  _FileIntegrity({required this.bytes, required Uint8List sha256})
    : sha256 = Uint8List.fromList(sha256);

  final int bytes;
  final Uint8List sha256;
}

final class _SingleDigestSink implements Sink<Digest> {
  Digest? _digest;

  Digest get value =>
      _digest ?? (throw StateError('e2ee_attachment_digest_incomplete'));

  @override
  void add(Digest data) {
    if (_digest != null) {
      throw StateError('e2ee_attachment_digest_completed_twice');
    }
    _digest = data;
  }

  @override
  void close() {}
}

List<String> _memoryRelativeSegments(String storagePath) {
  if (!storagePath.startsWith(_memoryRoot)) {
    throw StateError('e2ee_attachment_path_outside_owned_root');
  }
  final relative = storagePath.substring(_memoryRoot.length);
  if (relative.isEmpty || relative.contains('\\')) {
    throw StateError('e2ee_attachment_owned_path_unsafe');
  }
  final segments = relative.split('/');
  _requireOwnedRelativeSegments(segments);
  return segments;
}

bool _requireOwnedRelativeSegments(List<String> segments) {
  if (segments.length == 2 &&
      segments.first == 'content' &&
      _sha256HexPattern.hasMatch(segments.last)) {
    return false;
  }
  if (segments.length != 6 ||
      segments[0] != 'staging' ||
      (segments[1] != 'upload' && segments[1] != 'download') ||
      !_canonicalUuidV4Pattern.hasMatch(segments[2]) ||
      !_canonicalUuidV4Pattern.hasMatch(segments[3]) ||
      !_isPositiveUint32(segments[4]) ||
      (segments[1] == 'upload'
          ? !_isUploadChunkFileName(segments[5])
          : segments[5] != _downloadPlaintextFileName)) {
    throw StateError('e2ee_attachment_owned_path_unsafe');
  }
  return true;
}

bool _isPositiveUint32(String value) {
  final parsed = int.tryParse(value);
  return parsed != null &&
      parsed >= 1 &&
      parsed <= 0xffffffff &&
      parsed.toString() == value;
}

bool _isUploadChunkFileName(String value) {
  final match = _uploadChunkFilePattern.firstMatch(value);
  if (match == null || !_canonicalUuidV4Pattern.hasMatch(match.group(2)!)) {
    return false;
  }
  final chunkIndex = int.parse(value.substring(0, value.indexOf('-')));
  return chunkIndex < cloudSyncMaximumAttachmentChunkCount;
}

List<String> _downloadPlaintextDirectorySegments(
  CloudSyncAttachmentIdentity identity,
) => <String>[
  'staging',
  'download',
  identity.attachmentId,
  identity.uploadId,
  identity.keyEpoch.toString(),
];

String _memoryDownloadPlaintextPath(CloudSyncAttachmentIdentity identity) =>
    '$_memoryRoot${[..._downloadPlaintextDirectorySegments(identity), _downloadPlaintextFileName].join('/')}';

void _requireExactMemoryDownloadPath(
  CloudSyncAttachmentIdentity identity,
  String storagePath,
) {
  _requireStoragePath(storagePath);
  if (storagePath != _memoryDownloadPlaintextPath(identity)) {
    throw StateError('e2ee_attachment_staging_identity_mismatch');
  }
  final segments = _memoryRelativeSegments(storagePath);
  if (!_requireOwnedRelativeSegments(segments)) {
    throw StateError('e2ee_attachment_plaintext_staging_required');
  }
}

void _requireExactPlatformStoragePath(String storagePath, String expectedPath) {
  final value = _requireStoragePath(storagePath);
  if (!p.isAbsolute(value) || value != expectedPath) {
    throw StateError('e2ee_attachment_staging_identity_mismatch');
  }
}

String _requireCanonicalUuidV4(String value, String field) {
  if (!_canonicalUuidV4Pattern.hasMatch(value)) {
    throw FormatException('$field 必须为规范的小写 UUID v4');
  }
  return value;
}

String _requireStoragePath(String value) {
  if (value.isEmpty || value.length > 32768 || value.contains('\u0000')) {
    throw const FormatException('e2ee_attachment_storage_path_invalid');
  }
  return value;
}

int _requireByteLength(int value) {
  if (value < 0) {
    throw const FormatException('e2ee_attachment_file_length_invalid');
  }
  return value;
}

int _requirePlaintextLength(int value, String field) {
  if (value < 0 || value > cloudSyncMaximumAttachmentTotalCiphertextBytes) {
    throw FormatException('$field 超出附件明文范围');
  }
  return value;
}

void _requireBufferedReadSize(int value) {
  // 只有单个密文分块允许进入内存；最终内容必须按路径或流消费。
  if (value > cloudSyncMaximumAttachmentChunkCiphertextBytes) {
    throw StateError('e2ee_attachment_buffered_read_too_large');
  }
}

List<int> _requireChunkLayout(
  E2eeAttachmentStoredFile storedFile,
  List<int> chunkPlaintextBytes,
) {
  if (chunkPlaintextBytes.isEmpty) {
    throw const FormatException('e2ee_attachment_chunk_layout_invalid');
  }
  var total = 0;
  for (final length in chunkPlaintextBytes) {
    if (length < 0 ||
        (length == 0 &&
            (storedFile.bytes != 0 || chunkPlaintextBytes.length != 1))) {
      throw const FormatException('e2ee_attachment_chunk_layout_invalid');
    }
    total += length;
    if (total > storedFile.bytes) {
      throw const FormatException('e2ee_attachment_chunk_layout_invalid');
    }
  }
  if (total != storedFile.bytes) {
    throw const FormatException('e2ee_attachment_chunk_layout_invalid');
  }
  return List<int>.unmodifiable(chunkPlaintextBytes);
}

List<int> _chunkOffsetsFor(List<int> chunkLengths) {
  final offsets = <int>[];
  var offset = 0;
  for (final length in chunkLengths) {
    offsets.add(offset);
    offset += length;
  }
  return List<int>.unmodifiable(offsets);
}

void _requireContentRange(
  E2eeAttachmentStoredFile storedFile, {
  required int offset,
  required int length,
}) {
  if (offset < 0 ||
      length < 0 ||
      length > cloudSyncMaximumAttachmentChunkCiphertextBytes ||
      offset > storedFile.bytes ||
      length > storedFile.bytes - offset) {
    throw const FormatException('e2ee_attachment_content_range_invalid');
  }
}

void _requireContentDigestPath(
  E2eeAttachmentStoredFile storedFile,
  String path,
) {
  if (p.basename(path) != storedFile.sha256.toHex()) {
    throw const FormatException('e2ee_attachment_content_digest_path');
  }
}

Uint8List _requireSha256(Uint8List value, String field) {
  if (value.length != _sha256Bytes) {
    throw FormatException('$field 长度必须为 32 字节');
  }
  return Uint8List.fromList(value).asUnmodifiableView();
}

void _requirePathSegment(String value) {
  if (value.isEmpty || p.basename(value) != value) {
    throw StateError('e2ee_attachment_owned_path_unsafe');
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

Uint8List _copyByteChunk(List<int> value) {
  for (final byte in value) {
    if (byte < 0 || byte > 0xff) {
      throw const FormatException('e2ee_attachment_source_not_bytes');
    }
  }
  return Uint8List.fromList(value);
}

Uint8List _copyPlaintextChunk(Uint8List value) {
  if (value.length > cloudSyncMaximumAttachmentChunkCiphertextBytes) {
    throw const FormatException('e2ee_attachment_plaintext_chunk_too_large');
  }
  return Uint8List.fromList(value);
}

bool _matchesIntegrity(
  _FileIntegrity integrity, {
  required int expectedBytes,
  required Uint8List expectedSha256,
}) =>
    integrity.bytes == expectedBytes &&
    _sameBytes(integrity.sha256, expectedSha256);

extension on Uint8List {
  String toHex() =>
      map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
