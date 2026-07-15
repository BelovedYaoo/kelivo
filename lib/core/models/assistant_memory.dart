import 'dart:convert';

import 'package:uuid/uuid.dart';

class AssistantMemory {
  final int id; // 0 for new (not used in store), >0 persisted
  final String syncId;
  final String assistantId;
  final String content;

  factory AssistantMemory({
    required int id,
    required String assistantId,
    required String content,
    String? syncId,
  }) => AssistantMemory._(
    id: id,
    syncId: _nonEmpty(syncId) ?? const Uuid().v4(),
    assistantId: assistantId,
    content: content,
  );

  const AssistantMemory._({
    required this.id,
    required this.syncId,
    required this.assistantId,
    required this.content,
  });

  AssistantMemory copyWith({
    int? id,
    String? syncId,
    String? assistantId,
    String? content,
  }) => AssistantMemory(
    id: id ?? this.id,
    syncId: syncId ?? this.syncId,
    assistantId: assistantId ?? this.assistantId,
    content: content ?? this.content,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'syncId': syncId,
    'assistantId': assistantId,
    'content': content,
  };

  static AssistantMemory fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final assistantId = (json['assistantId'] ?? '').toString();
    final content = (json['content'] ?? '').toString();
    final rawSyncId = json['syncId'];
    final storedSyncId = rawSyncId is String ? _nonEmpty(rawSyncId) : null;
    return AssistantMemory._(
      id: id,
      syncId:
          storedSyncId ??
          _legacySyncId(id, assistantId: assistantId, content: content),
      assistantId: assistantId,
      content: content,
    );
  }

  static String _legacySyncId(
    int id, {
    required String assistantId,
    required String content,
  }) {
    // 使用规范 JSON 消除字符串拼接歧义，让同一旧备份在多端得到相同身份。
    final seed = jsonEncode(<Object>[assistantId, id, content]);
    return const Uuid().v5(Namespace.url.value, seed);
  }

  static String? _nonEmpty(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
