import 'dart:convert';

import 'package:hive/hive.dart';

import 'cloud_sync_types.dart';

final class CloudSyncStore {
  CloudSyncStore._(this._box);

  static const defaultBoxName = 'cloud_sync_state_v1';
  static const _sessionKey = 'active-session';
  static const _lastBaseUrlKey = 'last-base-url';

  final Box<String> _box;

  static Future<CloudSyncStore> open({String boxName = defaultBoxName}) async {
    if (boxName.trim().isEmpty) {
      throw const FormatException('同步状态 box 名称不能为空');
    }
    return CloudSyncStore._(await Hive.openBox<String>(boxName));
  }

  CloudSyncAccountSession? get activeSession {
    return _read(_sessionKey, CloudSyncAccountSession.fromJson);
  }

  Future<void> saveSession(CloudSyncAccountSession session) {
    return _write(_sessionKey, session.toJson());
  }

  Future<void> clearSession() => _box.delete(_sessionKey);

  String? get lastBaseUrl {
    final raw = _box.get(_lastBaseUrlKey);
    return raw == null ? null : normalizeCloudSyncBaseUrl(raw);
  }

  Future<void> saveLastBaseUrl(String baseUrl) {
    return _box.put(_lastBaseUrlKey, normalizeCloudSyncBaseUrl(baseUrl));
  }

  bool isPaused(CloudSyncAccountSession session) {
    final raw = _box.get(_pausedKey(session));
    if (raw == null || raw == 'false') return false;
    if (raw == 'true') return true;
    throw const FormatException('同步暂停状态无效');
  }

  Future<void> savePaused(
    CloudSyncAccountSession session, {
    required bool paused,
  }) {
    return _box.put(_pausedKey(session), paused.toString());
  }

  CloudSyncCursorState cursorState(CloudSyncAccountSession session) {
    return _read(_cursorKey(session), CloudSyncCursorState.fromJson) ??
        const CloudSyncCursorState();
  }

  Future<void> savePullCursor(CloudSyncAccountSession session, String? cursor) {
    final current = cursorState(session);
    return _write(
      _cursorKey(session),
      CloudSyncCursorState(
        pullCursor: _validatedOptionalCursor(cursor),
        snapshotCursor: current.snapshotCursor,
        snapshotSyncCursor: current.snapshotSyncCursor,
      ).toJson(),
    );
  }

  Future<void> saveSnapshotProgress(
    CloudSyncAccountSession session, {
    required String? snapshotCursor,
    required String? syncCursor,
  }) {
    final current = cursorState(session);
    return _write(
      _cursorKey(session),
      CloudSyncCursorState(
        pullCursor: current.pullCursor,
        snapshotCursor: _validatedOptionalCursor(snapshotCursor),
        snapshotSyncCursor: _validatedOptionalCursor(syncCursor),
      ).toJson(),
    );
  }

  Future<void> completeSnapshot(
    CloudSyncAccountSession session, {
    required String syncCursor,
  }) {
    return _write(
      _cursorKey(session),
      CloudSyncCursorState(pullCursor: _validatedCursor(syncCursor)).toJson(),
    );
  }

  Future<void> clearSyncProgress(CloudSyncAccountSession session) {
    return _box.delete(_cursorKey(session));
  }

  Future<void> beginSnapshot(CloudSyncAccountSession session) async {
    final prefix = _accountPrefix(session, 'snapshot-seen');
    final keys = _box.keys
        .whereType<String>()
        .where((key) => key.startsWith(prefix))
        .toList(growable: false);
    await _box.deleteAll(keys);
  }

  Future<void> markSnapshotRecordsSeen(
    CloudSyncAccountSession session,
    Iterable<CloudSyncRecord> records,
  ) async {
    final entries = <String, String>{
      for (final record in records)
        _snapshotSeenKey(session, record.entityType, record.entityId): '1',
    };
    if (entries.isNotEmpty) {
      await _box.putAll(entries);
    }
  }

  bool wasSeenInSnapshot(
    CloudSyncAccountSession session, {
    required CloudSyncEntityType entityType,
    required String entityId,
  }) {
    return _box.containsKey(_snapshotSeenKey(session, entityType, entityId));
  }

  Future<void> finishSnapshot(CloudSyncAccountSession session) async {
    final prefix = _accountPrefix(session, 'snapshot-seen');
    final keys = _box.keys
        .whereType<String>()
        .where((key) => key.startsWith(prefix))
        .toList(growable: false);
    await _box.deleteAll(keys);
  }

  CloudSyncShadow? shadow(
    CloudSyncAccountSession session, {
    required CloudSyncEntityType entityType,
    required String entityId,
  }) {
    return _read(
      _shadowKey(session, entityType, entityId),
      CloudSyncShadow.fromJson,
    );
  }

  List<CloudSyncShadow> shadows(CloudSyncAccountSession session) {
    final prefix = _accountPrefix(session, 'shadow');
    final result = <CloudSyncShadow>[];
    for (final key in _box.keys.whereType<String>()) {
      if (!key.startsWith(prefix)) continue;
      final item = _read(key, CloudSyncShadow.fromJson);
      if (item == null) {
        throw StateError('shadow 索引存在但内容缺失：$key');
      }
      result.add(item);
    }
    result.sort((left, right) {
      final byType = left.entityType.wireName.compareTo(
        right.entityType.wireName,
      );
      return byType != 0 ? byType : left.entityId.compareTo(right.entityId);
    });
    return List<CloudSyncShadow>.unmodifiable(result);
  }

  Future<void> saveShadow(
    CloudSyncAccountSession session,
    CloudSyncShadow shadow,
  ) {
    return _write(
      _shadowKey(session, shadow.entityType, shadow.entityId),
      shadow.toJson(),
    );
  }

  Future<void> deleteShadow(
    CloudSyncAccountSession session, {
    required CloudSyncEntityType entityType,
    required String entityId,
  }) {
    return _box.delete(_shadowKey(session, entityType, entityId));
  }

  Future<CloudSyncOutboxMutation> enqueueOutbox(
    CloudSyncAccountSession session,
    CloudSyncOutboxMutation mutation, {
    bool merge = true,
  }) async {
    final sameId = outboxById(session, mutation.mutationId);
    if (sameId != null) {
      if (_requestFingerprint(sameId) != _requestFingerprint(mutation)) {
        throw StateError('mutationId 已用于另一份不可变请求');
      }
      return sameId;
    }

    if (merge) {
      final candidates = outboxForEntity(
        session,
        entityType: mutation.entityType,
        entityId: mutation.entityId,
      );
      for (final existing in candidates.reversed) {
        if (existing.canMergeWith(mutation)) {
          final merged = existing.mergedWith(mutation);
          await _write(
            _outboxKey(session, existing.mutationId),
            merged.toJson(),
          );
          return merged;
        }
      }
    }

    await _write(_outboxKey(session, mutation.mutationId), mutation.toJson());
    return mutation;
  }

  CloudSyncOutboxMutation? outboxById(
    CloudSyncAccountSession session,
    String mutationId,
  ) {
    return _read(
      _outboxKey(session, mutationId),
      CloudSyncOutboxMutation.fromJson,
    );
  }

  List<CloudSyncOutboxMutation> outboxForEntity(
    CloudSyncAccountSession session, {
    required CloudSyncEntityType entityType,
    required String entityId,
  }) {
    return List<CloudSyncOutboxMutation>.unmodifiable(
      _allOutbox(session).where(
        (item) => item.entityType == entityType && item.entityId == entityId,
      ),
    );
  }

  List<CloudSyncOutboxMutation> pendingOutbox(
    CloudSyncAccountSession session, {
    DateTime? readyAt,
    int limit = 10,
  }) {
    if (limit < 1 || limit > 10) {
      throw const FormatException('单次 outbox 查询数量必须为 1 到 10');
    }
    final deadline = (readyAt ?? DateTime.now()).toUtc();
    return List<CloudSyncOutboxMutation>.unmodifiable(
      _allOutbox(
        session,
      ).where((item) => !item.nextAttemptAt.isAfter(deadline)).take(limit),
    );
  }

  Future<CloudSyncOutboxMutation> markOutboxRetry(
    CloudSyncAccountSession session, {
    required String mutationId,
    required DateTime nextAttemptAt,
    String? errorCode,
  }) async {
    final existing = outboxById(session, mutationId);
    if (existing == null) {
      throw StateError('找不到待重试的 mutation：$mutationId');
    }
    final retried = existing.scheduledForRetry(
      nextAttemptAt: nextAttemptAt,
      errorCode: errorCode,
    );
    await _write(_outboxKey(session, mutationId), retried.toJson());
    return retried;
  }

  Future<CloudSyncOutboxMutation> markOutboxAttempted(
    CloudSyncAccountSession session, {
    required String mutationId,
  }) async {
    final existing = outboxById(session, mutationId);
    if (existing == null) {
      throw StateError('找不到待发送的 mutation：$mutationId');
    }
    final attempted = existing.attempted();
    await _write(_outboxKey(session, mutationId), attempted.toJson());
    return attempted;
  }

  Future<void> acknowledgeOutbox(
    CloudSyncAccountSession session, {
    required String mutationId,
    int? revision,
    int? lastChangeSeq,
    bool deleted = false,
    String? parentId,
    int? schemaVersion,
    CloudSyncJsonMap? payload,
    DateTime? updatedAt,
  }) async {
    final existing = outboxById(session, mutationId);
    if (existing == null) return;
    if ((revision == null) != (lastChangeSeq == null)) {
      throw const FormatException('revision 与 lastChangeSeq 必须同时提供');
    }
    if (revision != null && lastChangeSeq != null) {
      final currentShadow = shadow(
        session,
        entityType: existing.entityType,
        entityId: existing.entityId,
      );
      final nextSchemaVersion =
          schemaVersion ??
          existing.schemaVersion ??
          currentShadow?.schemaVersion;
      if (nextSchemaVersion == null) {
        throw const FormatException('确认 outbox 时缺少 schemaVersion');
      }
      final nextPayload = payload ?? currentShadow?.payload;
      if (!deleted && nextPayload == null) {
        throw const FormatException('确认有效实体时缺少 payload');
      }
      await saveShadow(
        session,
        CloudSyncShadow(
          entityType: existing.entityType,
          entityId: existing.entityId,
          parentId: parentId ?? existing.parentId ?? currentShadow?.parentId,
          revision: revision,
          schemaVersion: nextSchemaVersion,
          lastChangeSeq: lastChangeSeq,
          deleted: deleted,
          payload: nextPayload,
          updatedAt: updatedAt ?? DateTime.now(),
        ),
      );
    }
    // 先保存 revision shadow；若随后崩溃，固定 mutationId 会让重放保持幂等。
    await _box.delete(_outboxKey(session, mutationId));
  }

  Future<void> removeOutbox(
    CloudSyncAccountSession session,
    String mutationId,
  ) {
    return _box.delete(_outboxKey(session, mutationId));
  }

  CloudSyncAttachmentBinding? attachmentBinding(
    CloudSyncAccountSession session, {
    required String messageId,
    required CloudSyncAttachmentKind kind,
    required int order,
  }) {
    final binding = _read(
      _attachmentBindingKey(
        session,
        messageId: messageId,
        kind: kind,
        order: order,
      ),
      CloudSyncAttachmentBinding.fromJson,
    );
    if (binding != null &&
        (binding.messageId != messageId ||
            binding.kind != kind ||
            binding.order != order)) {
      throw const FormatException('附件绑定索引与内容不一致');
    }
    return binding;
  }

  Future<void> saveAttachmentBinding(
    CloudSyncAccountSession session,
    CloudSyncAttachmentBinding binding,
  ) {
    return _write(
      _attachmentBindingKey(
        session,
        messageId: binding.messageId,
        kind: binding.kind,
        order: binding.order,
      ),
      binding.toJson(),
    );
  }

  Future<void> deleteAttachmentBinding(
    CloudSyncAccountSession session, {
    required String messageId,
    required CloudSyncAttachmentKind kind,
    required int order,
  }) {
    return _box.delete(
      _attachmentBindingKey(
        session,
        messageId: messageId,
        kind: kind,
        order: order,
      ),
    );
  }

  String? remoteOrdinaryMessageContentSha256(
    CloudSyncAccountSession session, {
    required String messageId,
  }) {
    return _read(_remoteOrdinaryMessageKey(session, messageId), (json) {
      if (json['version'] != 1) {
        throw const FormatException('远端普通消息指纹版本无效');
      }
      final value = json['contentSha256'];
      if (value is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
        throw const FormatException('远端普通消息指纹无效');
      }
      return value;
    });
  }

  Future<void> saveRemoteOrdinaryMessageContentSha256(
    CloudSyncAccountSession session, {
    required String messageId,
    required String contentSha256,
  }) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(contentSha256)) {
      throw const FormatException('远端普通消息指纹无效');
    }
    return _write(
      _remoteOrdinaryMessageKey(session, messageId),
      <String, Object?>{'version': 1, 'contentSha256': contentSha256},
    );
  }

  Future<void> deleteRemoteOrdinaryMessageContentSha256(
    CloudSyncAccountSession session, {
    required String messageId,
  }) {
    return _box.delete(_remoteOrdinaryMessageKey(session, messageId));
  }

  Future<void> clearAccountState(CloudSyncAccountSession session) async {
    final prefix = 'account:${session.accountScope}:';
    final keys = _box.keys
        .whereType<String>()
        .where((key) => key.startsWith(prefix))
        .toList(growable: false);
    await _box.deleteAll(keys);
  }

  Future<void> close() => _box.close();

  List<CloudSyncOutboxMutation> _allOutbox(CloudSyncAccountSession session) {
    final prefix = _accountPrefix(session, 'outbox');
    final result = <CloudSyncOutboxMutation>[];
    for (final key in _box.keys.whereType<String>()) {
      if (!key.startsWith(prefix)) continue;
      final item = _read(key, CloudSyncOutboxMutation.fromJson);
      if (item == null) {
        throw StateError('outbox 索引存在但内容缺失：$key');
      }
      result.add(item);
    }
    result.sort((left, right) {
      final byTime = left.createdAt.compareTo(right.createdAt);
      return byTime != 0 ? byTime : left.mutationId.compareTo(right.mutationId);
    });
    return result;
  }

  T? _read<T>(String key, T Function(CloudSyncJsonMap json) decode) {
    final raw = _box.get(key);
    if (raw == null) return null;
    final Object? decoded = jsonDecode(raw);
    return decode(copyCloudSyncJsonMap(decoded));
  }

  Future<void> _write(String key, CloudSyncJsonMap value) {
    return _box.put(key, jsonEncode(copyCloudSyncJsonMap(value)));
  }

  String _cursorKey(CloudSyncAccountSession session) {
    return '${_accountPrefix(session, 'cursor')}state';
  }

  String _pausedKey(CloudSyncAccountSession session) {
    return '${_accountPrefix(session, 'setting')}paused';
  }

  String _shadowKey(
    CloudSyncAccountSession session,
    CloudSyncEntityType entityType,
    String entityId,
  ) {
    return '${_accountPrefix(session, 'shadow')}'
        '${entityType.wireName}:${Uri.encodeComponent(entityId)}';
  }

  String _outboxKey(CloudSyncAccountSession session, String mutationId) {
    return '${_accountPrefix(session, 'outbox')}${Uri.encodeComponent(mutationId)}';
  }

  String _snapshotSeenKey(
    CloudSyncAccountSession session,
    CloudSyncEntityType entityType,
    String entityId,
  ) {
    return '${_accountPrefix(session, 'snapshot-seen')}'
        '${entityType.wireName}:${Uri.encodeComponent(entityId)}';
  }

  String _attachmentBindingKey(
    CloudSyncAccountSession session, {
    required String messageId,
    required CloudSyncAttachmentKind kind,
    required int order,
  }) {
    if (messageId.trim().isEmpty || order < 0) {
      throw const FormatException('附件绑定索引无效');
    }
    return '${_accountPrefix(session, 'attachment')}message:'
        '${Uri.encodeComponent(messageId)}:${kind.name}:$order';
  }

  String _remoteOrdinaryMessageKey(
    CloudSyncAccountSession session,
    String messageId,
  ) {
    if (messageId.trim().isEmpty || messageId.length > 128) {
      throw const FormatException('远端普通消息索引无效');
    }
    return '${_accountPrefix(session, 'remote-ordinary-message')}'
        '${Uri.encodeComponent(messageId)}';
  }

  String _accountPrefix(CloudSyncAccountSession session, String area) {
    return 'account:${session.accountScope}:$area:';
  }
}

String _requestFingerprint(CloudSyncOutboxMutation mutation) {
  return jsonEncode(<String, Object?>{
    'mutationId': mutation.mutationId,
    'entityType': mutation.entityType.wireName,
    'entityId': mutation.entityId,
    'operation': mutation.operation.name,
    'parentId': mutation.parentId,
    'baseRevision': mutation.baseRevision,
    'schemaVersion': mutation.schemaVersion,
    'payload': mutation.payload,
    'patch': mutation.patch
        .map((item) => item.toJson())
        .toList(growable: false),
  });
}

String _validatedCursor(String value) {
  if (value.isEmpty) {
    throw const FormatException('同步游标不能为空');
  }
  return value;
}

String? _validatedOptionalCursor(String? value) {
  return value == null ? null : _validatedCursor(value);
}
