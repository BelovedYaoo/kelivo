import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../../../utils/app_directories.dart';
import '../../../utils/sandbox_path_resolver.dart';
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
  static final RegExp _markerPattern = RegExp(
    r'\[image:([^\]\r\n]+)\]|\[file:([^\|\]\r\n]+)\|([^\|\]\r\n]+)\|([^\]\r\n]+)\]',
  );
  static final RegExp _markerPrefix = RegExp(r'\[(?:image|file):');

  static ChatAttachmentMarkerDocument parse(String content) {
    final matches = _markerPattern
        .allMatches(content)
        .where((match) => !_isRemotePath(_pathFromMatch(match)))
        .toList(growable: false);
    final output = StringBuffer();
    final markers = <ChatAttachmentMarker>[];
    var cursor = 0;

    for (final match in matches) {
      var removalStart = match.start;
      var removalEnd = match.end;
      if (removalStart > cursor &&
          content.codeUnitAt(removalStart - 1) == 0x0a) {
        removalStart--;
        if (removalStart > cursor &&
            content.codeUnitAt(removalStart - 1) == 0x0d) {
          removalStart--;
        }
      } else if (removalEnd < content.length) {
        if (content.codeUnitAt(removalEnd) == 0x0d) {
          removalEnd++;
          if (removalEnd < content.length &&
              content.codeUnitAt(removalEnd) == 0x0a) {
            removalEnd++;
          }
        } else if (content.codeUnitAt(removalEnd) == 0x0a) {
          removalEnd++;
        }
      }
      output.write(content.substring(cursor, removalStart));
      final imagePath = match.group(1)?.trim();
      if (imagePath != null && imagePath.isNotEmpty) {
        final fileName = _fileNameFromPath(imagePath);
        markers.add(
          ChatAttachmentMarker(
            kind: CloudSyncAttachmentKind.image,
            order: markers.length,
            localPath: imagePath,
            fileName: fileName,
            mimeType: _imageMimeType(fileName),
          ),
        );
      } else {
        final filePath = match.group(2)?.trim() ?? '';
        final fileName = match.group(3)?.trim() ?? '';
        final mimeType = match.group(4)?.trim().toLowerCase() ?? '';
        _validateMarkerMetadata(filePath, fileName, mimeType);
        markers.add(
          ChatAttachmentMarker(
            kind: CloudSyncAttachmentKind.file,
            order: markers.length,
            localPath: filePath,
            fileName: fileName,
            mimeType: mimeType,
          ),
        );
      }
      cursor = removalEnd;
    }
    output.write(content.substring(cursor));

    final contentWithoutMarkers = markers.isEmpty
        ? output.toString()
        : output.toString().replaceFirst(RegExp(r'(?:\r?\n)+$'), '');
    final unparsedContent = contentWithoutMarkers.replaceAll(
      _markerPattern,
      '',
    );
    if (_markerPrefix.hasMatch(unparsedContent)) {
      throw const FormatException('消息包含无法解析的附件 marker');
    }
    return ChatAttachmentMarkerDocument(
      contentWithoutMarkers: contentWithoutMarkers,
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

  static String _pathFromMatch(Match match) {
    return (match.group(1) ?? match.group(2) ?? '').trim();
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

  Future<PreparedChatSyncAttachments> prepareMessage({
    required String messageId,
    required String content,
  }) async {
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
    final resolvedPath = path.normalize(
      SandboxPathResolver.fix(marker.localPath),
    );
    final file = File(resolvedPath);
    final stat = await file.stat();
    _validateFileStat(stat);
    final fileName = _safeMarkerField(marker.fileName);
    final mimeType = marker.mimeType.trim().toLowerCase();
    ChatAttachmentMarkerCodec._validateMarkerMetadata(
      resolvedPath,
      fileName,
      mimeType,
    );

    final cached = _store.attachmentBinding(
      _session,
      messageId: messageId,
      kind: marker.kind,
      order: marker.order,
    );
    final CloudSyncAttachmentBinding binding;
    if (_matchesLocalFile(
      cached,
      localPath: resolvedPath,
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
        localPath: resolvedPath,
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
      final file = File(cached.localPath);
      final stat = await file.stat();
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
    final directory = Directory(directoryPath);
    await directory.create(recursive: true);
    final safeName = _safeFileName(attachment.fileName, attachment.id);
    final finalPath = path.normalize(path.join(directoryPath, safeName));
    final partPath = path.normalize('$finalPath.part');
    if (!path.isWithin(directoryPath, finalPath) ||
        !path.isWithin(directoryPath, partPath)) {
      throw const FileSystemException('附件下载路径越界');
    }

    final finalFile = File(finalPath);
    if (await finalFile.exists()) {
      final existing = await _verifiedDownloadedBinding(
        messageId: messageId,
        kind: kind,
        order: order,
        attachment: attachment,
        file: finalFile,
      );
      if (existing != null) return existing;
    }

    final partFile = File(partPath);
    if (await partFile.exists()) await partFile.delete();
    try {
      final download = await _client.getAttachmentDownloadUrl(attachment.id);
      if (download.attachmentId != attachment.id) {
        throw const FormatException('附件下载地址与请求不匹配');
      }
      await _client.downloadSignedAttachment(
        downloadUrl: download.downloadUrl,
        destinationPath: partPath,
      );
      final verified = await _buildDownloadedBinding(
        messageId: messageId,
        kind: kind,
        order: order,
        attachment: attachment,
        file: partFile,
      );
      if (await finalFile.exists()) await finalFile.delete();
      await partFile.rename(finalPath);
      final finalStat = await finalFile.stat();
      final saved = verified.copyWith(
        localPath: finalPath,
        modifiedAt: finalStat.modified,
      );
      await _store.saveAttachmentBinding(_session, saved);
      return saved;
    } finally {
      if (await partFile.exists()) await partFile.delete();
    }
  }

  Future<CloudSyncAttachmentBinding?> _verifiedDownloadedBinding({
    required String messageId,
    required CloudSyncAttachmentKind kind,
    required int order,
    required CloudSyncAttachmentInfo attachment,
    required File file,
  }) async {
    try {
      final binding = await _buildDownloadedBinding(
        messageId: messageId,
        kind: kind,
        order: order,
        attachment: attachment,
        file: file,
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
      localPath: file.path,
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
