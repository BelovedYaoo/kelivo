import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../../../utils/app_directories.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../chat/upload_directory_critical_section.dart';
import 'chat_sync_codec.dart';
import 'cloud_sync_client.dart';
import 'cloud_sync_store.dart';
import 'cloud_sync_types.dart';

final class ChatAttachmentMarker {
  const ChatAttachmentMarker({
    required this.kind,
    required this.order,
    required this.localPath,
    required this.fileName,
    required this.mimeType,
  });

  final CloudSyncAttachmentKind kind;
  final int order;
  final String localPath;
  final String fileName;
  final String mimeType;
}

final class ChatAttachmentMarkerDocument {
  ChatAttachmentMarkerDocument({
    required this.contentWithoutMarkers,
    required List<ChatAttachmentMarker> markers,
  }) : markers = List<ChatAttachmentMarker>.unmodifiable(markers);

  final String contentWithoutMarkers;
  final List<ChatAttachmentMarker> markers;
}

abstract final class ChatAttachmentMarkerCodec {
  static final RegExp _imageMarkerLine = RegExp(r'^\[image:([^\]\r\n]+)\]$');
  static final RegExp _fileMarkerLine = RegExp(
    r'^\[file:([^\|\]\r\n]+)\|([^\|\]\r\n]+)\|([^\]\r\n]+)\]$',
  );

  static ChatAttachmentMarkerDocument parse(String content) {
    final lines = content.split('\n');
    var blockEnd = lines.length;
    while (blockEnd > 0 &&
        _withoutCarriageReturn(lines[blockEnd - 1]).isEmpty) {
      blockEnd--;
    }

    var blockStart = blockEnd;
    final reversed = <ChatAttachmentMarker>[];
    while (blockStart > 0) {
      final marker = _tryParseMarkerLine(
        _withoutCarriageReturn(lines[blockStart - 1]),
      );
      if (marker == null || _isRemotePath(marker.localPath)) break;
      reversed.add(marker);
      blockStart--;
    }
    if (reversed.isEmpty) {
      return ChatAttachmentMarkerDocument(
        contentWithoutMarkers: content,
        markers: const <ChatAttachmentMarker>[],
      );
    }

    final prefixLines = lines.sublist(0, blockStart);
    while (prefixLines.isNotEmpty &&
        _withoutCarriageReturn(prefixLines.last).isEmpty) {
      prefixLines.removeLast();
    }
    final markers = <ChatAttachmentMarker>[
      for (final (index, marker) in reversed.reversed.indexed)
        ChatAttachmentMarker(
          kind: marker.kind,
          order: index,
          localPath: marker.localPath,
          fileName: marker.fileName,
          mimeType: marker.mimeType,
        ),
    ];
    return ChatAttachmentMarkerDocument(
      contentWithoutMarkers: prefixLines.join('\n'),
      markers: markers,
    );
  }

  static String restore(
    String contentWithoutMarkers,
    Iterable<ChatAttachmentMarker> markers,
  ) {
    final ordered = markers.toList(growable: false)
      ..sort((left, right) => left.order.compareTo(right.order));
    final orders = <int>{};
    var restored = contentWithoutMarkers;
    for (final marker in ordered) {
      if (marker.order < 0 || !orders.add(marker.order)) {
        throw const FormatException('附件 marker 顺序无效');
      }
      _validateMarkerMetadata(
        marker.localPath,
        marker.fileName,
        marker.mimeType,
      );
      if (restored.isNotEmpty && !restored.endsWith('\n')) {
        restored += '\n';
      }
      restored += switch (marker.kind) {
        CloudSyncAttachmentKind.image => '[image:${marker.localPath}]',
        CloudSyncAttachmentKind.file =>
          '[file:${marker.localPath}|${marker.fileName}|${marker.mimeType}]',
      };
    }
    return restored;
  }

  static void _validateMarkerMetadata(
    String localPath,
    String fileName,
    String mimeType,
  ) {
    if (localPath.trim().isEmpty ||
        fileName.trim().isEmpty ||
        fileName.length > 255 ||
        !RegExp(r'^[^\s/\[\]\|]+/[^\s/\[\]\|]+$').hasMatch(mimeType)) {
      throw const FormatException('附件 marker 元数据无效');
    }
  }

  static String _fileNameFromPath(String value) {
    final fileName = path.basename(value.replaceAll('\\', '/')).trim();
    if (fileName.isEmpty || fileName.length > 255) {
      throw const FormatException('图片附件文件名无效');
    }
    return fileName;
  }

  static ChatAttachmentMarker? _tryParseMarkerLine(String line) {
    final imageMatch = _imageMarkerLine.firstMatch(line);
    if (imageMatch != null) {
      final localPath = imageMatch.group(1)?.trim() ?? '';
      try {
        final fileName = _fileNameFromPath(localPath);
        return ChatAttachmentMarker(
          kind: CloudSyncAttachmentKind.image,
          order: 0,
          localPath: localPath,
          fileName: fileName,
          mimeType: _imageMimeType(fileName),
        );
      } on FormatException {
        return null;
      }
    }

    final fileMatch = _fileMarkerLine.firstMatch(line);
    if (fileMatch == null) return null;
    final localPath = fileMatch.group(1)?.trim() ?? '';
    final fileName = fileMatch.group(2)?.trim() ?? '';
    final mimeType = fileMatch.group(3)?.trim().toLowerCase() ?? '';
    try {
      _validateMarkerMetadata(localPath, fileName, mimeType);
      return ChatAttachmentMarker(
        kind: CloudSyncAttachmentKind.file,
        order: 0,
        localPath: localPath,
        fileName: fileName,
        mimeType: mimeType,
      );
    } on FormatException {
      return null;
    }
  }

  static String _withoutCarriageReturn(String line) {
    return line.endsWith('\r') ? line.substring(0, line.length - 1) : line;
  }

  static bool _isRemotePath(String value) {
    final scheme = Uri.tryParse(value)?.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https' || scheme == 'data';
  }

  static String _imageMimeType(String fileName) {
    return switch (path.extension(fileName).toLowerCase()) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.bmp' => 'image/bmp',
      '.svg' => 'image/svg+xml',
      '.heic' => 'image/heic',
      '.avif' => 'image/avif',
      _ => 'application/octet-stream',
    };
  }
}

final class PreparedChatSyncAttachments {
  PreparedChatSyncAttachments({
    required this.syncedContent,
    required List<ChatSyncAttachmentReference> references,
  }) : references = List<ChatSyncAttachmentReference>.unmodifiable(references);

  final String syncedContent;
  final List<ChatSyncAttachmentReference> references;
}

final class CloudAttachmentSyncService {
  CloudAttachmentSyncService(this._session, this._client, this._store);

  static const Uuid _uuid = Uuid();

  final CloudSyncAccountSession _session;
  final CloudSyncClient _client;
  final CloudSyncStore _store;

  Future<void> rememberRemoteOrdinaryUserMessage({
    required String messageId,
    required String content,
  }) async {
    if (ChatAttachmentMarkerCodec.parse(content).markers.isEmpty) {
      await forgetRemoteOrdinaryUserMessage(messageId);
      return;
    }
    await _store.saveRemoteOrdinaryMessageContentSha256(
      _session,
      messageId: messageId,
      contentSha256: _contentSha256(content),
    );
  }

  Future<void> forgetRemoteOrdinaryUserMessage(String messageId) {
    return _store.deleteRemoteOrdinaryMessageContentSha256(
      _session,
      messageId: messageId,
    );
  }

  Future<PreparedChatSyncAttachments> prepareMessage({
    required String messageId,
    required String content,
  }) async {
    final remoteOrdinaryContentSha256 = _store
        .remoteOrdinaryMessageContentSha256(_session, messageId: messageId);
    if (remoteOrdinaryContentSha256 != null) {
      if (remoteOrdinaryContentSha256 == _contentSha256(content)) {
        return PreparedChatSyncAttachments(
          syncedContent: content,
          references: const <ChatSyncAttachmentReference>[],
        );
      }
      await forgetRemoteOrdinaryUserMessage(messageId);
    }
    final document = ChatAttachmentMarkerCodec.parse(content);
    final references = <ChatSyncAttachmentReference>[];
    for (final marker in document.markers) {
      final binding = await _prepareMarker(messageId, marker);
      references.add(
        ChatSyncAttachmentReference(
          attachmentId: binding.attachmentId,
          kind: binding.kind.name,
          order: binding.order,
        ),
      );
    }
    return PreparedChatSyncAttachments(
      syncedContent: document.contentWithoutMarkers,
      references: references,
    );
  }

  Future<String> restoreMessage({
    required String messageId,
    required String syncedContent,
    required List<ChatSyncAttachmentReference> references,
  }) async {
    if (references.isEmpty) return syncedContent;

    final serverAttachments = await _client.listAttachmentInfo(
      entityType: 'message',
      entityId: messageId,
    );
    final byId = <String, CloudSyncAttachmentInfo>{
      for (final attachment in serverAttachments) attachment.id: attachment,
    };
    if (byId.length != serverAttachments.length) {
      throw const FormatException('服务端附件列表包含重复标识');
    }
    final markers = <ChatAttachmentMarker>[];
    final attachmentIds = <String>{};
    final orders = <int>{};
    for (final reference in references) {
      if (!attachmentIds.add(reference.attachmentId) ||
          reference.order < 0 ||
          !orders.add(reference.order)) {
        throw const FormatException('消息附件引用重复或顺序无效');
      }
      final attachment = byId[reference.attachmentId];
      if (attachment == null ||
          attachment.entityType != 'message' ||
          attachment.entityId != messageId) {
        throw const FormatException('消息附件引用与服务端附件列表不一致');
      }
      final kind = switch (reference.kind) {
        ChatSyncAttachmentReference.imageKind => CloudSyncAttachmentKind.image,
        ChatSyncAttachmentReference.fileKind => CloudSyncAttachmentKind.file,
        _ => throw const FormatException('消息附件类型无效'),
      };
      final binding = await _restoreAttachment(
        messageId: messageId,
        kind: kind,
        order: reference.order,
        attachment: attachment,
      );
      markers.add(
        ChatAttachmentMarker(
          kind: kind,
          order: reference.order,
          localPath: binding.localPath,
          fileName: _safeMarkerField(attachment.fileName),
          mimeType: attachment.mimeType,
        ),
      );
    }
    return ChatAttachmentMarkerCodec.restore(syncedContent, markers);
  }

  Future<CloudSyncAttachmentBinding> _prepareMarker(
    String messageId,
    ChatAttachmentMarker marker,
  ) async {
    final target = await _resolveManagedUploadTarget(marker.localPath);
    final localPath = target.path;
    final fileName = _safeMarkerField(marker.fileName);
    final mimeType = marker.mimeType.trim().toLowerCase();
    ChatAttachmentMarkerCodec._validateMarkerMetadata(
      localPath,
      fileName,
      mimeType,
    );

    final cached = _store.attachmentBinding(
      _session,
      messageId: messageId,
      kind: marker.kind,
      order: marker.order,
    );
    if (target.type == FileSystemEntityType.notFound) {
      return _restoreMissingManagedFile(
        messageId: messageId,
        marker: marker,
        target: target,
        fileName: fileName,
        mimeType: mimeType,
        cached: cached,
      );
    }

    final file = target.file;
    final stat = await file.stat();
    _validateFileStat(stat);
    final CloudSyncAttachmentBinding binding;
    if (_matchesLocalFile(
      cached,
      localPath: localPath,
      stat: stat,
      fileName: fileName,
      mimeType: mimeType,
    )) {
      binding = cached!;
    } else {
      final digests = await _digestFile(file);
      final statAfterDigest = await file.stat();
      if (!_sameFileStat(stat, statAfterDigest)) {
        throw const FileSystemException('附件在摘要计算期间发生变化');
      }
      binding = CloudSyncAttachmentBinding(
        messageId: messageId,
        attachmentId: _attachmentId(
          messageId: messageId,
          kind: marker.kind,
          order: marker.order,
          sha256: digests.sha256Hex,
          fileName: fileName,
          mimeType: mimeType,
        ),
        kind: marker.kind,
        order: marker.order,
        localPath: localPath,
        modifiedAt: stat.modified,
        sizeBytes: stat.size,
        sha256: digests.sha256Hex,
        md5Base64: digests.md5Base64,
        fileName: fileName,
        mimeType: mimeType,
        completed: false,
      );
      await _store.saveAttachmentBinding(_session, binding);
    }
    if (binding.completed) return binding;

    final prepared = await _client.prepareAttachmentUpload(
      sha256: binding.sha256,
      md5Base64: binding.md5Base64,
      sizeBytes: binding.sizeBytes,
    );
    final String etag;
    if (prepared.alreadyExists) {
      etag = prepared.etag!;
    } else {
      etag = await _client.putSignedAttachment(
        uploadUrl: prepared.uploadUrl!,
        headers: prepared.uploadHeaders,
        content: file.openRead(),
      );
    }
    final completed = await _client.completeAttachmentUpload(
      attachmentId: binding.attachmentId,
      blobId: prepared.blobId,
      entityType: 'message',
      entityId: messageId,
      fileName: binding.fileName,
      mimeType: binding.mimeType,
      etag: etag,
    );
    _validateCompletedAttachment(binding, completed);
    final statAfterComplete = await file.stat();
    if (!_sameFileStat(stat, statAfterComplete)) {
      throw const FileSystemException('附件在上传期间发生变化');
    }
    final saved = binding.copyWith(completed: true);
    await _store.saveAttachmentBinding(_session, saved);
    return saved;
  }

  Future<CloudSyncAttachmentBinding> _restoreMissingManagedFile({
    required String messageId,
    required ChatAttachmentMarker marker,
    required _ManagedUploadTarget target,
    required String fileName,
    required String mimeType,
    required CloudSyncAttachmentBinding? cached,
  }) async {
    if (!_matchesMissingCompletedBinding(
      cached,
      localPath: target.path,
      fileName: fileName,
      mimeType: mimeType,
    )) {
      throw const FileSystemException('受管附件文件缺失，且没有可信的已完成绑定');
    }
    final binding = cached!;
    final serverAttachments = await _client.listAttachmentInfo(
      entityType: 'message',
      entityId: messageId,
    );
    final matches = serverAttachments
        .where((attachment) => attachment.id == binding.attachmentId)
        .toList(growable: false);
    if (matches.length != 1) {
      throw const FormatException('已完成附件绑定无法在服务端唯一核验');
    }
    final attachment = matches.single;
    _validateCompletedAttachment(binding, attachment);

    return _downloadAttachmentToPath(
      messageId: messageId,
      kind: marker.kind,
      order: marker.order,
      attachment: attachment,
      destinationPath: target.path,
      replaceInvalidExisting: false,
    );
  }

  Future<CloudSyncAttachmentBinding> _restoreAttachment({
    required String messageId,
    required CloudSyncAttachmentKind kind,
    required int order,
    required CloudSyncAttachmentInfo attachment,
  }) async {
    final cached = _store.attachmentBinding(
      _session,
      messageId: messageId,
      kind: kind,
      order: order,
    );
    if (cached != null &&
        cached.completed &&
        cached.attachmentId == attachment.id &&
        cached.sha256 == attachment.sha256 &&
        cached.sizeBytes == attachment.sizeBytes &&
        cached.fileName == attachment.fileName &&
        cached.mimeType == attachment.mimeType) {
      final cachedTarget = await _resolveManagedUploadTarget(cached.localPath);
      final stat = await cachedTarget.file.stat();
      if (_matchesCachedDownload(cached, stat)) return cached;
    }

    final uploadDirectory = await AppDirectories.getUploadDirectory();
    final accountHash = sha256
        .convert(utf8.encode(_session.accountScope))
        .toString();
    final cloudRootPath = path.normalize(
      path.join(uploadDirectory.path, 'cloud'),
    );
    final directoryPath = path.normalize(
      path.join(cloudRootPath, accountHash, attachment.id),
    );
    if (!path.isWithin(cloudRootPath, directoryPath)) {
      throw const FileSystemException('附件账户目录越界');
    }
    final safeName = _safeFileName(attachment.fileName, attachment.id);
    final finalPath = path.normalize(path.join(directoryPath, safeName));
    if (!path.isWithin(directoryPath, finalPath)) {
      throw const FileSystemException('附件下载路径越界');
    }
    return _downloadAttachmentToPath(
      messageId: messageId,
      kind: kind,
      order: order,
      attachment: attachment,
      destinationPath: finalPath,
      replaceInvalidExisting: true,
    );
  }

  Future<CloudSyncAttachmentBinding> _downloadAttachmentToPath({
    required String messageId,
    required CloudSyncAttachmentKind kind,
    required int order,
    required CloudSyncAttachmentInfo attachment,
    required String destinationPath,
    required bool replaceInvalidExisting,
  }) {
    return UploadDirectoryCriticalSection.run(() async {
      var target = await _resolveManagedUploadTarget(destinationPath);
      if (target.type != FileSystemEntityType.notFound) {
        final existing = await _verifiedDownloadedBinding(
          messageId: messageId,
          kind: kind,
          order: order,
          attachment: attachment,
          file: target.file,
          localPath: target.path,
        );
        if (existing != null) return existing;
        if (!replaceInvalidExisting) {
          throw const FileSystemException('受管附件恢复目标已被其他文件占用');
        }
      }

      await Directory(
        path.dirname(target.resolvedPath),
      ).create(recursive: true);
      target = await _resolveManagedUploadTarget(target.path);
      final partStoredPath = path.normalize('${target.path}.part');
      final partTarget = await _resolveManagedUploadTarget(partStoredPath);
      final partPath = partTarget.resolvedPath;
      if (partTarget.type != FileSystemEntityType.notFound) {
        final rawPartType = await FileSystemEntity.type(
          partTarget.path,
          followLinks: false,
        );
        if (rawPartType != FileSystemEntityType.file &&
            rawPartType != FileSystemEntityType.link) {
          throw const FileSystemException('附件临时下载路径被非文件占用');
        }
        await partTarget.file.delete();
      }

      var partFile = File(partPath);
      try {
        final download = await _client.getAttachmentDownloadUrl(attachment.id);
        if (download.attachmentId != attachment.id) {
          throw const FormatException('附件下载地址与请求不匹配');
        }
        await _client.downloadSignedAttachment(
          downloadUrl: download.downloadUrl,
          destinationPath: partPath,
          expectedSizeBytes: attachment.sizeBytes,
        );
        final downloadedPartTarget = await _resolveManagedUploadTarget(
          partStoredPath,
        );
        if (downloadedPartTarget.type != FileSystemEntityType.file) {
          throw const FileSystemException('附件临时下载文件类型无效');
        }
        partFile = downloadedPartTarget.file;
        final verified = await _buildDownloadedBinding(
          messageId: messageId,
          kind: kind,
          order: order,
          attachment: attachment,
          file: partFile,
          localPath: target.path,
        );

        final currentTarget = await _resolveManagedUploadTarget(target.path);
        if (currentTarget.type != FileSystemEntityType.notFound) {
          final existing = await _verifiedDownloadedBinding(
            messageId: messageId,
            kind: kind,
            order: order,
            attachment: attachment,
            file: currentTarget.file,
            localPath: currentTarget.path,
          );
          if (existing != null) return existing;
          if (!replaceInvalidExisting) {
            throw const FileSystemException('受管附件恢复目标已被其他文件占用');
          }
          final rawTargetType = await FileSystemEntity.type(
            currentTarget.path,
            followLinks: false,
          );
          if (rawTargetType != FileSystemEntityType.file &&
              rawTargetType != FileSystemEntityType.link) {
            throw const FileSystemException('附件下载目标被非文件占用');
          }
          await currentTarget.file.delete();
        }

        await partFile.rename(currentTarget.resolvedPath);
        final finalFile = currentTarget.file;
        final finalStat = await finalFile.stat();
        final saved = verified.copyWith(
          localPath: target.path,
          modifiedAt: finalStat.modified,
        );
        await _store.saveAttachmentBinding(_session, saved);
        return saved;
      } finally {
        if (await partFile.exists()) await partFile.delete();
      }
    });
  }

  Future<CloudSyncAttachmentBinding?> _verifiedDownloadedBinding({
    required String messageId,
    required CloudSyncAttachmentKind kind,
    required int order,
    required CloudSyncAttachmentInfo attachment,
    required File file,
    required String localPath,
  }) async {
    try {
      final binding = await _buildDownloadedBinding(
        messageId: messageId,
        kind: kind,
        order: order,
        attachment: attachment,
        file: file,
        localPath: localPath,
      );
      await _store.saveAttachmentBinding(_session, binding);
      return binding;
    } on FormatException {
      return null;
    }
  }

  Future<CloudSyncAttachmentBinding> _buildDownloadedBinding({
    required String messageId,
    required CloudSyncAttachmentKind kind,
    required int order,
    required CloudSyncAttachmentInfo attachment,
    required File file,
    required String localPath,
  }) async {
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file ||
        stat.size != attachment.sizeBytes) {
      throw const FormatException('下载附件大小不匹配');
    }
    final digests = await _digestFile(file);
    final statAfterDigest = await file.stat();
    if (!_sameFileStat(stat, statAfterDigest)) {
      throw const FormatException('下载附件在校验期间发生变化');
    }
    if (digests.sha256Hex != attachment.sha256) {
      throw const FormatException('下载附件摘要不匹配');
    }
    return CloudSyncAttachmentBinding(
      messageId: messageId,
      attachmentId: attachment.id,
      kind: kind,
      order: order,
      localPath: localPath,
      modifiedAt: stat.modified,
      sizeBytes: stat.size,
      sha256: digests.sha256Hex,
      md5Base64: digests.md5Base64,
      fileName: attachment.fileName,
      mimeType: attachment.mimeType,
      completed: true,
    );
  }

  String _attachmentId({
    required String messageId,
    required CloudSyncAttachmentKind kind,
    required int order,
    required String sha256,
    required String fileName,
    required String mimeType,
  }) {
    final seed = jsonEncode(<Object>[
      _session.accountScope,
      messageId,
      kind.name,
      order,
      sha256,
      fileName,
      mimeType,
    ]);
    return _uuid.v5(Namespace.url.value, seed);
  }
}

String _contentSha256(String content) {
  return sha256.convert(utf8.encode(content)).toString();
}

final class _ManagedUploadTarget {
  const _ManagedUploadTarget({
    required this.path,
    required this.resolvedPath,
    required this.type,
  });

  final String path;
  final String resolvedPath;
  final FileSystemEntityType type;

  File get file => File(resolvedPath);
}

Future<_ManagedUploadTarget> _resolveManagedUploadTarget(
  String storedPath,
) async {
  final uploadDirectory = await AppDirectories.getUploadDirectory();
  await uploadDirectory.create(recursive: true);
  final lexicalRoot = path.normalize(path.absolute(uploadDirectory.path));
  final fixedPath = SandboxPathResolver.fix(storedPath);
  if (!path.isAbsolute(fixedPath)) {
    throw const FileSystemException('附件路径必须是受管目录内的绝对路径');
  }
  final candidate = path.normalize(fixedPath);
  if (!_isWithinOrEqual(lexicalRoot, candidate) ||
      path.equals(lexicalRoot, candidate)) {
    throw const FileSystemException('附件路径不在受管上传目录内');
  }

  final canonicalRoot = path.normalize(
    await Directory(lexicalRoot).resolveSymbolicLinks(),
  );
  final relativeCandidate = path.relative(candidate, from: lexicalRoot);
  final expectedResolvedPath = path.normalize(
    path.join(canonicalRoot, relativeCandidate),
  );
  final type = await FileSystemEntity.type(candidate, followLinks: false);
  if (type != FileSystemEntityType.notFound) {
    if (type == FileSystemEntityType.link) {
      throw const FileSystemException('附件路径不能是符号链接');
    }
    final resolvedPath = path.normalize(
      await File(candidate).resolveSymbolicLinks(),
    );
    if (!_isWithinOrEqual(canonicalRoot, resolvedPath) ||
        path.equals(canonicalRoot, resolvedPath)) {
      throw const FileSystemException('附件真实路径越出受管上传目录');
    }
    if (!path.equals(expectedResolvedPath, resolvedPath)) {
      throw const FileSystemException('附件路径不能经过符号链接');
    }
    return _ManagedUploadTarget(
      path: candidate,
      resolvedPath: resolvedPath,
      type: await FileSystemEntity.type(resolvedPath),
    );
  }

  var ancestorPath = path.dirname(candidate);
  var ancestorType = await FileSystemEntity.type(
    ancestorPath,
    followLinks: false,
  );
  while (ancestorType == FileSystemEntityType.notFound) {
    final parentPath = path.dirname(ancestorPath);
    if (path.equals(parentPath, ancestorPath)) {
      throw const FileSystemException('无法定位附件路径的受管父目录');
    }
    ancestorPath = parentPath;
    ancestorType = await FileSystemEntity.type(
      ancestorPath,
      followLinks: false,
    );
  }
  if (ancestorType != FileSystemEntityType.directory) {
    throw const FileSystemException('附件父路径不是普通目录');
  }
  final resolvedAncestor = path.normalize(
    await Directory(ancestorPath).resolveSymbolicLinks(),
  );
  if (!_isWithinOrEqual(canonicalRoot, resolvedAncestor)) {
    throw const FileSystemException('附件父目录越出受管上传目录');
  }
  final expectedResolvedAncestor = path.normalize(
    path.join(canonicalRoot, path.relative(ancestorPath, from: lexicalRoot)),
  );
  if (!path.equals(expectedResolvedAncestor, resolvedAncestor)) {
    throw const FileSystemException('附件父目录不能经过符号链接');
  }
  return _ManagedUploadTarget(
    path: candidate,
    resolvedPath: expectedResolvedPath,
    type: FileSystemEntityType.notFound,
  );
}

bool _isWithinOrEqual(String root, String candidate) {
  return path.equals(root, candidate) || path.isWithin(root, candidate);
}

bool _matchesLocalFile(
  CloudSyncAttachmentBinding? binding, {
  required String localPath,
  required FileStat stat,
  required String fileName,
  required String mimeType,
}) {
  return binding != null &&
      binding.localPath == localPath &&
      binding.modifiedAt == stat.modified.toUtc() &&
      binding.sizeBytes == stat.size &&
      (binding.kind == CloudSyncAttachmentKind.image ||
          (binding.fileName == fileName && binding.mimeType == mimeType));
}

bool _matchesMissingCompletedBinding(
  CloudSyncAttachmentBinding? binding, {
  required String localPath,
  required String fileName,
  required String mimeType,
}) {
  return binding != null &&
      binding.completed &&
      path.equals(path.normalize(binding.localPath), localPath) &&
      (binding.kind == CloudSyncAttachmentKind.image ||
          (binding.fileName == fileName && binding.mimeType == mimeType));
}

bool _matchesCachedDownload(CloudSyncAttachmentBinding binding, FileStat stat) {
  return stat.type == FileSystemEntityType.file &&
      stat.size == binding.sizeBytes &&
      stat.modified.toUtc() == binding.modifiedAt;
}

bool _sameFileStat(FileStat left, FileStat right) {
  return left.type == FileSystemEntityType.file &&
      right.type == FileSystemEntityType.file &&
      left.size == right.size &&
      left.modified.toUtc() == right.modified.toUtc();
}

void _validateFileStat(FileStat stat) {
  if (stat.type != FileSystemEntityType.file) {
    throw const FileSystemException('附件路径不是普通文件');
  }
  if (stat.size < 0 || stat.size > maximumCloudSyncAttachmentSizeBytes) {
    throw const FileSystemException('附件超过 100 MiB 限制');
  }
}

void _validateCompletedAttachment(
  CloudSyncAttachmentBinding binding,
  CloudSyncAttachmentInfo attachment,
) {
  if (attachment.id != binding.attachmentId ||
      attachment.entityType != 'message' ||
      attachment.entityId != binding.messageId ||
      attachment.fileName != binding.fileName ||
      attachment.mimeType != binding.mimeType ||
      attachment.sizeBytes != binding.sizeBytes ||
      attachment.sha256 != binding.sha256) {
    throw const FormatException('附件完成结果与本地绑定不一致');
  }
}

Future<_FileDigests> _digestFile(File file) async {
  final shaOutput = _DigestSink();
  final md5Output = _DigestSink();
  final shaInput = sha256.startChunkedConversion(shaOutput);
  final md5Input = md5.startChunkedConversion(md5Output);
  await for (final chunk in file.openRead()) {
    shaInput.add(chunk);
    md5Input.add(chunk);
  }
  shaInput.close();
  md5Input.close();
  final shaDigest = shaOutput.value;
  final md5Digest = md5Output.value;
  if (shaDigest == null || md5Digest == null) {
    throw const FormatException('无法计算附件摘要');
  }
  return _FileDigests(
    sha256Hex: shaDigest.toString(),
    md5Base64: base64.encode(md5Digest.bytes),
  );
}

String _safeFileName(String value, String attachmentId) {
  var fileName = path.basename(value.replaceAll('\\', '/')).trim();
  fileName = fileName.replaceAll(RegExp(r'[\x00-\x1f<>:"/\\|?*\[\]]'), '_');
  fileName = fileName.replaceFirst(RegExp(r'[ .]+$'), '');
  if (fileName.isEmpty || fileName == '.' || fileName == '..') {
    fileName = attachmentId;
  }
  final stem = path.basenameWithoutExtension(fileName).toUpperCase();
  if (<String>{
    'CON',
    'PRN',
    'AUX',
    'NUL',
    'COM1',
    'COM2',
    'COM3',
    'COM4',
    'COM5',
    'COM6',
    'COM7',
    'COM8',
    'COM9',
    'LPT1',
    'LPT2',
    'LPT3',
    'LPT4',
    'LPT5',
    'LPT6',
    'LPT7',
    'LPT8',
    'LPT9',
  }.contains(stem)) {
    fileName = '_$fileName';
  }
  if (fileName.length <= 120) return fileName;
  final rawExtension = path.extension(fileName);
  final extension = rawExtension.length < 40 ? rawExtension : '';
  final maximumStemLength = 120 - extension.length;
  final originalStem = extension.isEmpty
      ? fileName
      : path.basenameWithoutExtension(fileName);
  return '${originalStem.substring(0, maximumStemLength)}$extension';
}

String _safeMarkerField(String value) {
  return value.trim().replaceAll(RegExp(r'[\r\n\|]'), '_').replaceAll(']', '_');
}

final class _FileDigests {
  const _FileDigests({required this.sha256Hex, required this.md5Base64});

  final String sha256Hex;
  final String md5Base64;
}

final class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) {
    if (value != null) throw StateError('摘要输出只能写入一次');
    value = data;
  }

  @override
  void close() {}
}
