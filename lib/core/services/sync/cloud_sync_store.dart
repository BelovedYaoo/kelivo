import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'cloud_sync_types.dart';

final class CloudSyncStore {
  CloudSyncStore._(this._box);

  static const defaultBoxName = 'cloud_sync_state_v1';
  static const _sessionKey = 'active-session';
  static const _lastBaseUrlKey = 'last-base-url';
  static const _journalScopeIdKey = 'journal-scope-id';
  static const _configRescanGenerationKey = 'config-rescan-generation';
  static const _localProtocolVersionKey = 'local-sync-protocol-version';
  static const _localProtocolVersion = 2;

  final Box<String> _box;

  static Future<CloudSyncStore> open({String boxName = defaultBoxName}) async {
    if (boxName.trim().isEmpty) {
      throw const FormatException('同步状态 box 名称不能为空');
    }
    final box = await Hive.openBox<String>(boxName);
    final store = CloudSyncStore._(box);
    try {
      await store._migrateLocalProtocolState();
      return store;
    } catch (_) {
      await box.close();
      rethrow;
    }
  }

  static Future<void> markDefaultConfigRescanRequired() async {
    final wasOpen = Hive.isBoxOpen(defaultBoxName);
    final box = wasOpen
        ? Hive.box<String>(defaultBoxName)
        : await Hive.openBox<String>(defaultBoxName);
    try {
      await CloudSyncStore._(box).createConfigRescanGeneration();
    } finally {
      if (!wasOpen) {
        await box.close();
      }
    }
  }

  Future<void> _migrateLocalProtocolState() async {
    final persisted = int.tryParse(_box.get(_localProtocolVersionKey) ?? '');
    if (persisted != null && persisted > _localProtocolVersion) {
      throw StateError('本地同步协议版本高于当前客户端支持范围：$persisted');
    }
    if (persisted == _localProtocolVersion) return;

    final staleKeys = _box.keys
        .whereType<String>()
        .where(
          (key) => key.startsWith('account:') || key.startsWith('journal:'),
        )
        .toList(growable: false);
    if (staleKeys.isNotEmpty) {
      await _box.deleteAll(staleKeys);
    }
    await _box.put(_localProtocolVersionKey, _localProtocolVersion.toString());
  }

  CloudSyncAccountSession? get activeSession {
    return _read(_sessionKey, CloudSyncAccountSession.fromJson);
  }

  Future<void> saveSession(CloudSyncAccountSession session) {
    return _write(_sessionKey, session.toJson());
  }

  Future<void> clearSession() => _box.delete(_sessionKey);

  String? get configRescanGeneration {
    final persisted = _box.get(_configRescanGenerationKey);
    if (persisted == null) return null;
    if (persisted.trim().isEmpty) {
      throw const FormatException('配置重扫代次无效');
    }
    return persisted;
  }

  Future<String> createConfigRescanGeneration({
    String Function()? createGeneration,
  }) async {
    final generation = (createGeneration ?? const Uuid().v4)().trim();
    if (generation.isEmpty) {
      throw const FormatException('配置重扫代次不能为空');
    }
    await _box.put(_configRescanGenerationKey, generation);
    return generation;
  }

  Future<bool> consumeConfigRescanGeneration(String expected) async {
    final normalized = expected.trim();
    if (normalized.isEmpty) {
      throw const FormatException('待消费的配置重扫代次不能为空');
    }
    if (configRescanGeneration != normalized) return false;
    // 同步期间可能再次导入，比较删除可避免旧任务清掉更新后的代次。
    await _box.delete(_configRescanGenerationKey);
    return true;
  }

  Future<String> loadOrCreateJournalScopeId({
    String Function()? createId,
  }) async {
    final persisted = _box.get(_journalScopeIdKey);
    if (persisted != null) {
      if (persisted.trim().isEmpty) {
        throw const FormatException('写前 journal 的本地作用域无效');
      }
      return persisted;
    }

    final created = (createId ?? const Uuid().v4)().trim();
    if (created.isEmpty) {
      throw const FormatException('写前 journal 的本地作用域不能为空');
    }
    await _box.put(_journalScopeIdKey, created);
    return created;
  }

  Future<SyncWriteIntent> beginWriteIntent(SyncWriteIntent intent) async {
    final key = _writeIntentKey(intent);
    final existing = _read(key, SyncWriteIntent.fromJson);
    if (existing != null) return existing;
    await _write(key, intent.toJson());
    return intent;
  }

  List<SyncWriteIntent> writeIntents({
    required String journalScopeId,
    required String? accountScope,
  }) {
    final prefix = _writeIntentPrefix(
      journalScopeId: journalScopeId,
      accountScope: accountScope,
    );
    final result = <SyncWriteIntent>[];
    for (final key in _box.keys.whereType<String>()) {
      if (!key.startsWith(prefix)) continue;
      final intent = _read(key, SyncWriteIntent.fromJson);
      if (intent == null) {
        throw StateError('写前 intent 索引存在但内容缺失：$key');
      }
      if (intent.journalScopeId != journalScopeId ||
          intent.accountScope != accountScope) {
        throw StateError('写前 intent 索引与作用域不一致：$key');
      }
      result.add(intent);
    }
    result.sort((left, right) {
      final byTime = left.createdAt.compareTo(right.createdAt);
      return byTime != 0 ? byTime : left.intentId.compareTo(right.intentId);
    });
    return List<SyncWriteIntent>.unmodifiable(result);
  }

  Future<void> completeWriteIntent(SyncWriteIntent intent) async {
    final key = _writeIntentKey(intent);
    final current = _read(key, SyncWriteIntent.fromJson);
    if (current == null) return;
    if (current.intentId != intent.intentId) {
      throw StateError('不能用旧 intent 清理更新后的写入标记');
    }
    await _box.delete(key);
  }

  Future<void> bindJournalScopeWriteIntents({
    required String journalScopeId,
    required String accountScope,
  }) async {
    if (accountScope.trim().isEmpty) {
      throw const FormatException('绑定写前 intent 的账号作用域不能为空');
    }
    final intents = writeIntents(
      journalScopeId: journalScopeId,
      accountScope: null,
    );
    for (final intent in intents) {
      final bound = intent.bindToAccount(accountScope);
      final accountKey = _writeIntentKey(bound);
      final existing = _read(accountKey, SyncWriteIntent.fromJson);
      if (existing == null) {
        await _write(accountKey, bound.toJson());
      }
      await _box.delete(_writeIntentKey(intent));
    }
  }

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

  int outboxCount(CloudSyncAccountSession session) {
    return _allOutbox(session).length;
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
    final ready =
        _allOutbox(session)
            .where(
              (item) =>
                  item.blockedAt == null &&
                  !item.nextAttemptAt.isAfter(deadline),
            )
            .toList(growable: false)
          ..sort((left, right) {
            // 服务端按批处理请求，稳定的依赖深度可避免 UUID 或写入时间让子实体抢先。
            final byDependency = _pushDependencyDepth(
              left.entityType,
            ).compareTo(_pushDependencyDepth(right.entityType));
            if (byDependency != 0) return byDependency;
            final byTime = left.createdAt.compareTo(right.createdAt);
            return byTime != 0
                ? byTime
                : left.mutationId.compareTo(right.mutationId);
          });
    return List<CloudSyncOutboxMutation>.unmodifiable(ready.take(limit));
  }

  Future<CloudSyncOutboxMutation> markOutboxBlocked(
    CloudSyncAccountSession session, {
    required String mutationId,
    required String errorCode,
    DateTime? blockedAt,
  }) async {
    final existing = outboxById(session, mutationId);
    if (existing == null) {
      throw StateError('找不到被永久拒绝的 mutation：$mutationId');
    }
    final blocked = existing.blocked(
      blockedAt: blockedAt ?? DateTime.now(),
      errorCode: errorCode,
    );
    await _write(_outboxKey(session, mutationId), blocked.toJson());
    return blocked;
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

  String _writeIntentKey(SyncWriteIntent intent) {
    return '${_writeIntentPrefix(journalScopeId: intent.journalScopeId, accountScope: intent.accountScope)}${intent.entityType.wireName}:${Uri.encodeComponent(intent.entityId)}';
  }

  String _writeIntentPrefix({
    required String journalScopeId,
    required String? accountScope,
  }) {
    if (journalScopeId.trim().isEmpty) {
      throw const FormatException('写前 intent 的本地作用域不能为空');
    }
    final encodedJournalScope = Uri.encodeComponent(journalScopeId);
    return accountScope == null
        ? 'journal:$encodedJournalScope:write-intent:'
        : 'account:$accountScope:write-intent:$encodedJournalScope:';
  }
}

int _pushDependencyDepth(CloudSyncEntityType entityType) {
  return switch (entityType) {
    CloudSyncEntityType.turn ||
    CloudSyncEntityType.messageSelection ||
    CloudSyncEntityType.memory ||
    CloudSyncEntityType.quickPhrase => 1,
    CloudSyncEntityType.message => 2,
    CloudSyncEntityType.toolEvent || CloudSyncEntityType.thoughtSignature => 3,
    _ => 0,
  };
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
