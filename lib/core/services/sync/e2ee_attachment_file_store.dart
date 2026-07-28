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

final _canonicalUuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final _sha256HexPattern = RegExp(r'^[0-9a-f]{64}$');
final _downloadChunkFilePattern = RegExp(r'^(0|[1-9][0-9]{0,2})\.ciphertext$');
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

  factory E2eeAttachmentFileLocation.stagingDownloadChunk({
    required CloudSyncAttachmentChunkIdentity chunk,
  }) {
    final identity = chunk.identity;
    return E2eeAttachmentFileLocation._(
      directorySegments: <String>[
        'staging',
        'download',
        identity.attachmentId,
        identity.uploadId,
        identity.keyEpoch.toString(),
      ],
      fileName: '${chunk.chunkIndex}.ciphertext',
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

  Future<void> verifyContent(E2eeAttachmentStoredFile storedFile);

  Future<void> deleteStaging({required String storagePath});
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
  Future<void> deleteStaging({required String storagePath}) async {
    final segments = _memoryRelativeSegments(storagePath);
    if (!_requireOwnedRelativeSegments(segments)) {
      throw StateError('e2ee_attachment_delete_not_staging');
    }
    _files.remove(storagePath);
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
      !_isChunkFileName(segments[5], upload: segments[1] == 'upload')) {
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

bool _isChunkFileName(String value, {required bool upload}) {
  if (upload) {
    final match = _uploadChunkFilePattern.firstMatch(value);
    if (match == null || !_canonicalUuidV4Pattern.hasMatch(match.group(2)!)) {
      return false;
    }
  } else if (!_downloadChunkFilePattern.hasMatch(value)) {
    return false;
  }
  final separator = upload ? value.indexOf('-') : value.indexOf('.');
  final chunkIndex = int.parse(value.substring(0, separator));
  return chunkIndex < cloudSyncMaximumAttachmentChunkCount;
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

void _requireBufferedReadSize(int value) {
  // 只有单个密文分块允许进入内存；最终内容必须按路径或流消费。
  if (value > cloudSyncMaximumAttachmentChunkCiphertextBytes) {
    throw StateError('e2ee_attachment_buffered_read_too_large');
  }
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

extension on Uint8List {
  String toHex() =>
      map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
