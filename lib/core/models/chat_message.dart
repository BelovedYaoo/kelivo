import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'chat_message.g.dart';

@HiveType(typeId: 0)
class ChatMessage extends HiveObject {
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

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String role; // 'user' or 'assistant'

  @HiveField(2)
  final String content;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final String? modelId;

  @HiveField(5)
  final String? providerId;

  @HiveField(6)
  final int? totalTokens;

  @HiveField(7)
  final String conversationId;

  @HiveField(8)
  final bool isStreaming;

  // Optional reasoning fields for assistant messages
  @HiveField(9)
  final String? reasoningText;

  @HiveField(10)
  final DateTime? reasoningStartAt;

  @HiveField(11)
  final DateTime? reasoningFinishedAt;

  // Translation field for translated content
  @HiveField(12)
  final String? translation;

  // JSON encoded reasoning segments for multiple reasoning blocks
  @HiveField(13)
  final String? reasoningSegmentsJson;

  // Versioning: group messages sharing the same semantic position
  // groupId identifies a message thread; version starts from 0 and increments
  @HiveField(14)
  final String? groupId;

  @HiveField(15)
  final int version;

  @HiveField(16)
  final int? promptTokens;

  @HiveField(17)
  final int? completionTokens;

  @HiveField(18)
  final int? cachedTokens;

  @HiveField(19)
  final int? durationMs;

  @HiveField(20)
  final String turnId;

  @HiveField(21)
  final String generationStatus;

  factory ChatMessage({
    String? id,
    required String role,
    required String content,
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
    return ChatMessage(
      id: json['id'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
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
