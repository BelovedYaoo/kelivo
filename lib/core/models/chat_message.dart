import 'package:uuid/uuid.dart';

final class ChatMessageAttachment {
  static final RegExp _contentHashPattern = RegExp(r'^[0-9a-f]{64}$');
  static final RegExp _uuidV4Pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  factory ChatMessageAttachment({
    required String assetId,
    required String path,
    required String contentHash,
    required int byteSize,
    required String kind,
    String? displayName,
    String? mediaType,
    String? attachmentId,
    String? uploadId,
    int? chunkKeyEpoch,
    int? manifestKeyEpoch,
    int? manifestRevision,
  }) {
    if (assetId.trim().isEmpty || assetId.contains('\u0000')) {
      throw ArgumentError.value(assetId, 'assetId');
    }
    if (path.trim().isEmpty || path.contains('\u0000')) {
      throw ArgumentError.value(path, 'path');
    }
    if (!_contentHashPattern.hasMatch(contentHash)) {
      throw ArgumentError.value(contentHash, 'contentHash');
    }
    if (byteSize < 0) {
      throw ArgumentError.value(byteSize, 'byteSize');
    }
    if (kind != 'image' && kind != 'file') {
      throw ArgumentError.value(kind, 'kind');
    }
    if (displayName != null &&
        (displayName.trim().isEmpty ||
            displayName.contains('\u0000') ||
            displayName.contains('/') ||
            displayName.contains('\\'))) {
      throw ArgumentError.value(displayName, 'displayName');
    }
    if (mediaType != null &&
        (mediaType.trim() != mediaType ||
            mediaType.indexOf('/') <= 0 ||
            mediaType.endsWith('/'))) {
      throw ArgumentError.value(mediaType, 'mediaType');
    }
    if (kind == 'file' && (displayName == null || mediaType == null)) {
      throw ArgumentError.value((displayName, mediaType), 'fileMetadata');
    }
    final remoteFields = <Object?>[
      attachmentId,
      uploadId,
      chunkKeyEpoch,
      manifestKeyEpoch,
      manifestRevision,
    ];
    final hasRemoteIdentity = remoteFields.every((value) => value != null);
    if (!hasRemoteIdentity && remoteFields.any((value) => value != null)) {
      throw ArgumentError.value(remoteFields, 'remoteIdentity');
    }
    if (hasRemoteIdentity) {
      if (!_uuidV4Pattern.hasMatch(attachmentId!)) {
        throw ArgumentError.value(attachmentId, 'attachmentId');
      }
      if (!_uuidV4Pattern.hasMatch(uploadId!)) {
        throw ArgumentError.value(uploadId, 'uploadId');
      }
      for (final entry in <(String, int)>[
        ('chunkKeyEpoch', chunkKeyEpoch!),
        ('manifestKeyEpoch', manifestKeyEpoch!),
        ('manifestRevision', manifestRevision!),
      ]) {
        if (entry.$2 < 1 || entry.$2 > 0xffffffff) {
          throw ArgumentError.value(entry.$2, entry.$1);
        }
      }
      if (manifestKeyEpoch - chunkKeyEpoch != manifestRevision - 1) {
        throw ArgumentError.value(remoteFields, 'remoteIdentity');
      }
    }
    return ChatMessageAttachment._(
      assetId: assetId,
      path: path,
      contentHash: contentHash,
      byteSize: byteSize,
      kind: kind,
      displayName: displayName,
      mediaType: mediaType,
      attachmentId: attachmentId,
      uploadId: uploadId,
      chunkKeyEpoch: chunkKeyEpoch,
      manifestKeyEpoch: manifestKeyEpoch,
      manifestRevision: manifestRevision,
    );
  }

  const ChatMessageAttachment._({
    required this.assetId,
    required this.path,
    required this.contentHash,
    required this.byteSize,
    required this.kind,
    required this.displayName,
    required this.mediaType,
    required this.attachmentId,
    required this.uploadId,
    required this.chunkKeyEpoch,
    required this.manifestKeyEpoch,
    required this.manifestRevision,
  });

  final String assetId;
  final String path;
  final String contentHash;
  final int byteSize;
  final String kind;
  final String? displayName;
  final String? mediaType;
  final String? attachmentId;
  final String? uploadId;
  final int? chunkKeyEpoch;
  final int? manifestKeyEpoch;
  final int? manifestRevision;

  bool get hasRemoteIdentity => attachmentId != null;

  Map<String, Object?> toJson() => <String, Object?>{
    'assetId': assetId,
    'path': path,
    'contentHash': contentHash,
    'byteSize': byteSize,
    'kind': kind,
    'displayName': displayName,
    'mediaType': mediaType,
    'attachmentId': attachmentId,
    'uploadId': uploadId,
    'chunkKeyEpoch': chunkKeyEpoch,
    'manifestKeyEpoch': manifestKeyEpoch,
    'manifestRevision': manifestRevision,
  };

  factory ChatMessageAttachment.fromJson(Map<String, Object?> json) {
    if (json.containsKey('keyEpoch')) {
      throw const FormatException('chat_attachment.keyEpoch');
    }
    return ChatMessageAttachment(
      assetId: _requiredString(json, 'assetId'),
      path: _requiredString(json, 'path'),
      contentHash: _requiredString(json, 'contentHash'),
      byteSize: _requiredInt(json, 'byteSize'),
      kind: _requiredString(json, 'kind'),
      displayName: _optionalString(json, 'displayName'),
      mediaType: _optionalString(json, 'mediaType'),
      attachmentId: _optionalString(json, 'attachmentId'),
      uploadId: _optionalString(json, 'uploadId'),
      chunkKeyEpoch: _optionalInt(json, 'chunkKeyEpoch'),
      manifestKeyEpoch: _optionalInt(json, 'manifestKeyEpoch'),
      manifestRevision: _optionalInt(json, 'manifestRevision'),
    );
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String) throw FormatException('chat_attachment.$key');
    return value;
  }

  static int _requiredInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! int) throw FormatException('chat_attachment.$key');
    return value;
  }

  static String? _optionalString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value != null && value is! String) {
      throw FormatException('chat_attachment.$key');
    }
    return value as String?;
  }

  static int? _optionalInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value != null && value is! int) {
      throw FormatException('chat_attachment.$key');
    }
    return value as int?;
  }
}

class ChatMessage {
  static const int maximumAttachmentCount = 32;
  static const String generationStatusDraft = 'draft';
  static const String generationStatusCompleted = 'completed';
  static const String generationStatusInterrupted = 'interrupted';
  static const String generationStatusFailed = 'failed';

  static const Set<String> generationStatuses = <String>{
    generationStatusDraft,
    generationStatusCompleted,
    generationStatusInterrupted,
    generationStatusFailed,
  };

  final String id;

  final String role; // 'user' or 'assistant'

  final String content;

  final List<ChatMessageAttachment> attachments;

  final DateTime timestamp;

  final String? modelId;

  final String? providerId;

  final int? totalTokens;

  final String conversationId;

  final bool isStreaming;

  // Optional reasoning fields for assistant messages
  final String? reasoningText;

  final DateTime? reasoningStartAt;

  final DateTime? reasoningFinishedAt;

  // Translation field for translated content
  final String? translation;

  // JSON encoded reasoning segments for multiple reasoning blocks
  final String? reasoningSegmentsJson;

  // Versioning: group messages sharing the same semantic position
  // groupId identifies a message thread; version starts from 0 and increments
  final String? groupId;

  final int version;

  final int? promptTokens;

  final int? completionTokens;

  final int? cachedTokens;

  final int? durationMs;

  final String turnId;

  final String generationStatus;

  factory ChatMessage({
    String? id,
    required String role,
    required String content,
    Iterable<ChatMessageAttachment> attachments = const [],
    DateTime? timestamp,
    String? modelId,
    String? providerId,
    int? totalTokens,
    required String conversationId,
    bool isStreaming = false,
    String? reasoningText,
    DateTime? reasoningStartAt,
    DateTime? reasoningFinishedAt,
    String? translation,
    String? reasoningSegmentsJson,
    String? groupId,
    int? version,
    int? promptTokens,
    int? completionTokens,
    int? cachedTokens,
    int? durationMs,
    String? turnId,
    String? generationStatus,
  }) {
    final resolvedId = _nonEmpty(id) ?? const Uuid().v4();
    final resolvedGroupId = _nonEmpty(groupId) ?? resolvedId;
    return ChatMessage._(
      id: resolvedId,
      role: role,
      content: content,
      attachments: _freezeAttachments(attachments),
      timestamp: timestamp ?? DateTime.now(),
      modelId: modelId,
      providerId: providerId,
      totalTokens: totalTokens,
      conversationId: conversationId,
      isStreaming: isStreaming,
      reasoningText: reasoningText,
      reasoningStartAt: reasoningStartAt,
      reasoningFinishedAt: reasoningFinishedAt,
      translation: translation,
      reasoningSegmentsJson: reasoningSegmentsJson,
      groupId: resolvedGroupId,
      version: version ?? 0,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      cachedTokens: cachedTokens,
      durationMs: durationMs,
      turnId: _nonEmpty(turnId) ?? resolvedGroupId,
      generationStatus: _resolveGenerationStatus(
        generationStatus,
        isStreaming: isStreaming,
      ),
    );
  }

  ChatMessage._({
    required this.id,
    required this.role,
    required this.content,
    required this.attachments,
    required this.timestamp,
    required this.modelId,
    required this.providerId,
    required this.totalTokens,
    required this.conversationId,
    required this.isStreaming,
    required this.reasoningText,
    required this.reasoningStartAt,
    required this.reasoningFinishedAt,
    required this.translation,
    required this.reasoningSegmentsJson,
    required this.groupId,
    required this.version,
    required this.promptTokens,
    required this.completionTokens,
    required this.cachedTokens,
    required this.durationMs,
    required this.turnId,
    required this.generationStatus,
  });

  static String? _nonEmpty(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static List<ChatMessageAttachment> _freezeAttachments(
    Iterable<ChatMessageAttachment> attachments,
  ) {
    final frozen = List<ChatMessageAttachment>.unmodifiable(attachments);
    if (frozen.length > maximumAttachmentCount) {
      throw RangeError.range(
        frozen.length,
        0,
        maximumAttachmentCount,
        'attachments.length',
      );
    }
    return frozen;
  }

  static String _resolveGenerationStatus(
    String? value, {
    required bool isStreaming,
  }) {
    final normalized = value?.trim().toLowerCase();
    if (normalized != null && generationStatuses.contains(normalized)) {
      return normalized;
    }
    return isStreaming ? generationStatusDraft : generationStatusCompleted;
  }

  ChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    Iterable<ChatMessageAttachment>? attachments,
    DateTime? timestamp,
    String? modelId,
    String? providerId,
    int? totalTokens,
    String? conversationId,
    bool? isStreaming,
    String? reasoningText,
    DateTime? reasoningStartAt,
    DateTime? reasoningFinishedAt,
    String? translation,
    String? reasoningSegmentsJson,
    String? groupId,
    int? version,
    int? promptTokens,
    int? completionTokens,
    int? cachedTokens,
    int? durationMs,
    String? turnId,
    String? generationStatus,
  }) {
    final nextIsStreaming = isStreaming ?? this.isStreaming;
    final nextGenerationStatus = generationStatus != null
        ? _resolveGenerationStatus(
            generationStatus,
            isStreaming: nextIsStreaming,
          )
        : nextIsStreaming
        ? generationStatusDraft
        : (this.isStreaming && this.generationStatus == generationStatusDraft)
        ? generationStatusCompleted
        : this.generationStatus;

    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      attachments: attachments ?? this.attachments,
      timestamp: timestamp ?? this.timestamp,
      modelId: modelId ?? this.modelId,
      providerId: providerId ?? this.providerId,
      totalTokens: totalTokens ?? this.totalTokens,
      conversationId: conversationId ?? this.conversationId,
      isStreaming: nextIsStreaming,
      reasoningText: reasoningText ?? this.reasoningText,
      reasoningStartAt: reasoningStartAt ?? this.reasoningStartAt,
      reasoningFinishedAt: reasoningFinishedAt ?? this.reasoningFinishedAt,
      translation: translation ?? this.translation,
      reasoningSegmentsJson:
          reasoningSegmentsJson ?? this.reasoningSegmentsJson,
      groupId: groupId ?? this.groupId,
      version: version ?? this.version,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      cachedTokens: cachedTokens ?? this.cachedTokens,
      durationMs: durationMs ?? this.durationMs,
      turnId: turnId ?? this.turnId,
      generationStatus: nextGenerationStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'attachments': attachments
          .map((attachment) => attachment.toJson())
          .toList(growable: false),
      'timestamp': timestamp.toIso8601String(),
      'modelId': modelId,
      'providerId': providerId,
      'totalTokens': totalTokens,
      'conversationId': conversationId,
      'isStreaming': isStreaming,
      'reasoningText': reasoningText,
      'reasoningStartAt': reasoningStartAt?.toIso8601String(),
      'reasoningFinishedAt': reasoningFinishedAt?.toIso8601String(),
      'translation': translation,
      'reasoningSegmentsJson': reasoningSegmentsJson,
      'groupId': groupId,
      'version': version,
      'promptTokens': promptTokens,
      'completionTokens': completionTokens,
      'cachedTokens': cachedTokens,
      'durationMs': durationMs,
      'turnId': turnId,
      'generationStatus': generationStatus,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawAttachments = json['attachments'];
    if (rawAttachments is! List<Object?>) {
      throw const FormatException('chat_message.attachments');
    }
    return ChatMessage(
      id: json['id'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
      attachments: rawAttachments.map((value) {
        if (value is! Map<Object?, Object?>) {
          throw const FormatException('chat_message.attachments.item');
        }
        final attachment = <String, Object?>{};
        for (final entry in value.entries) {
          final key = entry.key;
          if (key is! String) {
            throw const FormatException('chat_message.attachments.item');
          }
          attachment[key] = entry.value;
        }
        return ChatMessageAttachment.fromJson(attachment);
      }),
      timestamp: DateTime.parse(json['timestamp'] as String),
      modelId: json['modelId'] as String?,
      providerId: json['providerId'] as String?,
      totalTokens: json['totalTokens'] as int?,
      conversationId: json['conversationId'] as String,
      isStreaming: json['isStreaming'] as bool? ?? false,
      reasoningText: json['reasoningText'] as String?,
      reasoningStartAt: json['reasoningStartAt'] != null
          ? DateTime.parse(json['reasoningStartAt'] as String)
          : null,
      reasoningFinishedAt: json['reasoningFinishedAt'] != null
          ? DateTime.parse(json['reasoningFinishedAt'] as String)
          : null,
      translation: json['translation'] as String?,
      reasoningSegmentsJson: json['reasoningSegmentsJson'] as String?,
      groupId: json['groupId'] as String?,
      version: (json['version'] as int?) ?? 0,
      promptTokens: json['promptTokens'] as int?,
      completionTokens: json['completionTokens'] as int?,
      cachedTokens: json['cachedTokens'] as int?,
      durationMs: json['durationMs'] as int?,
      turnId: json['turnId'] as String?,
      generationStatus: json['generationStatus'] as String?,
    );
  }
}
