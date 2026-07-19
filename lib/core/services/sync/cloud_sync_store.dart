import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'cloud_sync_types.dart';

final class CloudSyncRescanRequest {
  CloudSyncRescanRequest({
    required String generation,
    required Iterable<String> entityTypes,
    Iterable<String> localAuthoritativeEntityTypes = const <String>[],
    Iterable<String> activeWriteIds = const <String>[],
  }) : generation = generation.trim(),
       entityTypes = Set<String>.unmodifiable(
         entityTypes.map((type) => type.trim()),
       ),
       localAuthoritativeEntityTypes = Set<String>.unmodifiable(
         localAuthoritativeEntityTypes.map((type) => type.trim()),
       ),
       activeWriteIds = Set<String>.unmodifiable(
         activeWriteIds.map((id) => id.trim()),
       ) {
    if (this.generation.isEmpty) {
      throw const FormatException('重扫请求代次不能为空');
    }
    if (this.entityTypes.isEmpty || this.entityTypes.contains('')) {
      throw const FormatException('重扫请求实体类型不能为空');
    }
    if (this.activeWriteIds.contains('')) {
      throw const FormatException('重扫写入标识不能为空');
    }
    if (!this.entityTypes.containsAll(this.localAuthoritativeEntityTypes)) {
      throw const FormatException('本地权威实体类型必须属于重扫范围');
    }
    final unsupported = this.entityTypes
        .where((type) => !isSupportedCloudSyncEntityType(type))
        .toList(growable: false);
    if (unsupported.isNotEmpty) {
      throw FormatException('重扫请求包含不支持的实体类型：${unsupported.join(', ')}');
    }
  }

  factory CloudSyncRescanRequest.fromJson(CloudSyncJsonMap json) {
    final version = json['version'];
    if (version != 1 && version != 2 && version != 3) {
      throw const FormatException('重扫请求版本无效');
    }
    final generation = json['generation'];
    final rawEntityTypes = json['entityTypes'];
    if (generation is! String || rawEntityTypes is! List<Object?>) {
      throw const FormatException('重扫请求内容无效');
    }
    final entityTypes = <String>[];
    for (final value in rawEntityTypes) {
      if (value is! String) {
        throw const FormatException('重扫请求实体类型无效');
      }
      entityTypes.add(value);
    }
    final rawActiveWriteIds = version == 2 || version == 3
        ? json['activeWriteIds']
        : const <Object?>[];
    if (rawActiveWriteIds is! List<Object?>) {
      throw const FormatException('重扫写入状态无效');
    }
    final activeWriteIds = <String>[];
    for (final value in rawActiveWriteIds) {
      if (value is! String) {
        throw const FormatException('重扫写入标识无效');
      }
      activeWriteIds.add(value);
    }
    final rawLocalAuthoritativeEntityTypes = version == 3
        ? json['localAuthoritativeEntityTypes']
        : const <Object?>[];
    if (rawLocalAuthoritativeEntityTypes is! List<Object?>) {
      throw const FormatException('本地权威实体类型状态无效');
    }
    final localAuthoritativeEntityTypes = <String>[];
    for (final value in rawLocalAuthoritativeEntityTypes) {
      if (value is! String) {
        throw const FormatException('本地权威实体类型无效');
      }
      localAuthoritativeEntityTypes.add(value);
    }
    return CloudSyncRescanRequest(
      generation: generation,
      entityTypes: entityTypes,
      localAuthoritativeEntityTypes: localAuthoritativeEntityTypes,
      activeWriteIds: activeWriteIds,
    );
  }

  final String generation;
  final Set<String> entityTypes;
  final Set<String> localAuthoritativeEntityTypes;
  final Set<String> activeWriteIds;

  bool get hasActiveWrites => activeWriteIds.isNotEmpty;

  CloudSyncJsonMap toJson() {
    final sortedEntityTypes = entityTypes.toList(growable: false)..sort();
    final sortedLocalAuthoritativeEntityTypes =
        localAuthoritativeEntityTypes.toList(growable: false)..sort();
    return <String, Object?>{
      'version': 3,
      'generation': generation,
      'entityTypes': sortedEntityTypes,
      'localAuthoritativeEntityTypes': sortedLocalAuthoritativeEntityTypes,
      'activeWriteIds': activeWriteIds.toList(growable: false)..sort(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is CloudSyncRescanRequest &&
        generation == other.generation &&
        entityTypes.length == other.entityTypes.length &&
        entityTypes.every(other.entityTypes.contains) &&
        localAuthoritativeEntityTypes.length ==
            other.localAuthoritativeEntityTypes.length &&
        localAuthoritativeEntityTypes.every(
          other.localAuthoritativeEntityTypes.contains,
        ) &&
        activeWriteIds.length == other.activeWriteIds.length &&
        activeWriteIds.every(other.activeWriteIds.contains);
  }

  @override
  int get hashCode {
    final sortedEntityTypes = entityTypes.toList(growable: false)..sort();
    final sortedLocalAuthoritativeEntityTypes =
        localAuthoritativeEntityTypes.toList(growable: false)..sort();
    final sortedActiveWriteIds = activeWriteIds.toList(growable: false)..sort();
    return Object.hash(
      generation,
      Object.hashAll(sortedEntityTypes),
      Object.hashAll(sortedLocalAuthoritativeEntityTypes),
      Object.hashAll(sortedActiveWriteIds),
    );
  }
}

final class CloudSyncRescanWriteLease {
  CloudSyncRescanWriteLease(
    String writeId, {
    Iterable<String> localAuthoritativeEntityTypes = const <String>[],
  }) : writeId = writeId.trim(),
       localAuthoritativeEntityTypes = Set<String>.unmodifiable(
         localAuthoritativeEntityTypes.map((type) => type.trim()),
       ) {
    if (this.writeId.isEmpty) {
      throw const FormatException('重扫写入标识不能为空');
    }
    if (this.localAuthoritativeEntityTypes.contains('')) {
      throw const FormatException('本地权威实体类型不能为空');
    }
  }

  final String writeId;
  final Set<String> localAuthoritativeEntityTypes;
}

final class _AsyncMutex {
  final Object _zoneKey = Object();
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) async {
    if (identical(Zone.current[_zoneKey], this)) return action();
    final previous = _tail;
    final released = Completer<void>();
    _tail = released.future;
    await previous;
    try {
      return await runZoned(
        action,
        zoneValues: <Object, Object>{_zoneKey: this},
      );
    } finally {
      released.complete();
    }
  }
}

final class _CloudSyncOutboxSnapshot {
  _CloudSyncOutboxSnapshot(Iterable<CloudSyncOutboxMutation> mutations) {
    final grouped =
        <(CloudSyncEntityType, String), List<CloudSyncOutboxMutation>>{};
    for (final mutation in mutations) {
      _byMutationId[mutation.mutationId] = mutation;
      (grouped[(mutation.entityType, mutation.entityId)] ??=
              <CloudSyncOutboxMutation>[])
          .add(mutation);
    }
    for (final entry in grouped.entries) {
      entry.value.sort(_compareOutboxByCreation);
      _byEntity[entry.key] = List<CloudSyncOutboxMutation>.unmodifiable(
        entry.value,
      );
    }
  }

  final Map<String, CloudSyncOutboxMutation> _byMutationId =
      <String, CloudSyncOutboxMutation>{};
  final Map<(CloudSyncEntityType, String), List<CloudSyncOutboxMutation>>
  _byEntity = <(CloudSyncEntityType, String), List<CloudSyncOutboxMutation>>{};

  int get length => _byMutationId.length;
  int get blockedCount => _byMutationId.values
      .where((mutation) => mutation.blockedAt != null)
      .length;

  List<CloudSyncOutboxMutation> get blocked {
    final mutations =
        _byMutationId.values
            .where((mutation) => mutation.blockedAt != null)
            .toList(growable: false)
          ..sort(_compareOutboxByCreation);
    return List<CloudSyncOutboxMutation>.unmodifiable(mutations);
  }

  List<CloudSyncOutboxMutation> forEntity({
    required CloudSyncEntityType entityType,
    required String entityId,
  }) {
    return _byEntity[(entityType, entityId)] ??
        const <CloudSyncOutboxMutation>[];
  }

  List<CloudSyncOutboxMutation> _pending({
    required DateTime readyAt,
    required int limit,
  }) {
    final ready =
        _byMutationId.values
            .where(
              (item) =>
                  item.blockedAt == null &&
                  !item.nextAttemptAt.isAfter(readyAt),
            )
            .toList(growable: false)
          ..sort((left, right) {
            final byDependency = _pushDependencyDepth(
              left.entityType,
            ).compareTo(_pushDependencyDepth(right.entityType));
            if (byDependency != 0) return byDependency;
            return _compareOutboxByCreation(left, right);
          });
    return List<CloudSyncOutboxMutation>.unmodifiable(ready.take(limit));
  }

  void _upsert(CloudSyncOutboxMutation mutation) {
    final previous = _byMutationId[mutation.mutationId];
    if (previous != null) {
      _removeFromEntity(previous);
    }
    _byMutationId[mutation.mutationId] = mutation;
    final key = (mutation.entityType, mutation.entityId);
    final next = <CloudSyncOutboxMutation>[...?_byEntity[key], mutation]
      ..sort(_compareOutboxByCreation);
    _byEntity[key] = List<CloudSyncOutboxMutation>.unmodifiable(next);
  }

  void _remove(String mutationId) {
    final previous = _byMutationId.remove(mutationId);
    if (previous != null) {
      _removeFromEntity(previous);
    }
  }

  void _removeFromEntity(CloudSyncOutboxMutation mutation) {
    final key = (mutation.entityType, mutation.entityId);
    final current = _byEntity[key];
    if (current == null) return;
    final next = current
        .where((item) => item.mutationId != mutation.mutationId)
        .toList(growable: false);
    if (next.isEmpty) {
      _byEntity.remove(key);
    } else {
      _byEntity[key] = List<CloudSyncOutboxMutation>.unmodifiable(next);
    }
  }

  void _clear() {
    _byMutationId.clear();
    _byEntity.clear();
  }
}

final class CloudSyncStore {
  CloudSyncStore._(this._box);

  static const defaultBoxName = 'cloud_sync_state_v1';
  static const Set<String> chatRescanEntityTypes = <String>{
    'conversation',
    'turn',
    'message',
    'message-selection',
    'tool-event',
    'thought-signature',
  };
  static const Set<String> configRescanEntityTypes = <String>{
    'provider',
    'assistant',
    'memory',
    'world-book',
    'quick-phrase',
    'search-service',
    'network-tts',
    'mcp-server',
    'instruction-injection',
    'user-preference',
  };
  static const Set<String> allRescanEntityTypes = <String>{
    ...chatRescanEntityTypes,
    ...configRescanEntityTypes,
  };
  static const _legacySessionKey = 'active-session';
  static const _legacyLastBaseUrlKey = 'last-base-url';
  static const _journalScopeIdKey = 'journal-scope-id';
  static const _rescanRequestKey = 'rescan-request';
  static const _configRescanGenerationKey = 'config-rescan-generation';
  static const _localProtocolVersionKey = 'local-sync-protocol-version';
  static const _localProtocolVersion = 3;

  static void _validateLocalAuthoritativeScope({
    required Set<String> entityTypes,
    required Set<String> localAuthoritativeEntityTypes,
  }) {
    final normalizedEntityTypes = entityTypes
        .map((type) => type.trim())
        .toSet();
    final normalizedAuthoritativeTypes = localAuthoritativeEntityTypes
        .map((type) => type.trim())
        .toSet();
    if (!normalizedEntityTypes.containsAll(normalizedAuthoritativeTypes)) {
      throw const FormatException('本地权威实体类型必须属于本次重扫范围');
    }
  }

  final Box<String> _box;
  static final Expando<_AsyncMutex> _rescanLocks = Expando<_AsyncMutex>();
  static final Expando<_AsyncMutex> _rescanOperationGates =
      Expando<_AsyncMutex>();
  final Map<String, _CloudSyncOutboxSnapshot> _activeOutboxSnapshots =
      <String, _CloudSyncOutboxSnapshot>{};

  _AsyncMutex get _rescanLock => _rescanLocks[_box] ??= _AsyncMutex();
  _AsyncMutex get _rescanOperationGate =>
      _rescanOperationGates[_box] ??= _AsyncMutex();

  static Future<CloudSyncStore> open({String boxName = defaultBoxName}) async {
    if (boxName.trim().isEmpty) {
      throw const FormatException('同步状态 box 名称不能为空');
    }
    final box = await Hive.openBox<String>(boxName);
    final store = CloudSyncStore._(box);
    try {
      await store._migrateLocalProtocolState();
      await store._removeLegacySessionState();
      await store._migrateLegacyConfigRescan();
      await store._recoverInterruptedRescanWrites();
      return store;
    } catch (_) {
      await box.close();
      rethrow;
    }
  }

  static Future<void> markDefaultRescanRequired(Set<String> entityTypes) async {
    final wasOpen = Hive.isBoxOpen(defaultBoxName);
    final store = wasOpen
        ? CloudSyncStore._(Hive.box<String>(defaultBoxName))
        : await CloudSyncStore.open();
    try {
      await store.markRescanRequired(entityTypes: entityTypes);
    } finally {
      if (!wasOpen) {
        await store.close();
      }
    }
  }

  static Future<T> runWithDefaultRescanWrite<T>({
    required Set<String> entityTypes,
    Set<String> localAuthoritativeEntityTypes = const <String>{},
    required Future<T> Function() write,
    bool keepActiveOnSuccess = false,
  }) async {
    final wasOpen = Hive.isBoxOpen(defaultBoxName);
    final store = wasOpen
        ? CloudSyncStore._(Hive.box<String>(defaultBoxName))
        : await CloudSyncStore.open();
    try {
      return await store._rescanOperationGate.run(() async {
        final lease = await store.beginRescanWrite(
          entityTypes: entityTypes,
          localAuthoritativeEntityTypes: localAuthoritativeEntityTypes,
        );
        try {
          final result = await write();
          final completed = await store.completeRescanWrite(
            lease,
            keepActive: keepActiveOnSuccess,
          );
          if (!completed) {
            throw StateError('重扫写入租约在提交前失效');
          }
          return result;
        } catch (_) {
          await store.abortRescanWrite(lease);
          rethrow;
        }
      });
    } finally {
      if (!wasOpen) await store.close();
    }
  }

  Future<T> runWithRescanStable<T>(Future<T> Function() action) {
    return _rescanOperationGate.run(action);
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
    await _box.delete(_rescanRequestKey);
    await _box.put(_localProtocolVersionKey, _localProtocolVersion.toString());
  }

  Future<void> _removeLegacySessionState() async {
    final legacyKeys = <String>[
      if (_box.containsKey(_legacySessionKey)) _legacySessionKey,
      if (_box.containsKey(_legacyLastBaseUrlKey)) _legacyLastBaseUrlKey,
    ];
    if (legacyKeys.isNotEmpty) {
      await _box.deleteAll(legacyKeys);
    }
  }

  CloudSyncRescanRequest? get rescanRequest {
    return _read(_rescanRequestKey, CloudSyncRescanRequest.fromJson);
  }

  Future<CloudSyncRescanRequest> markRescanRequired({
    required Set<String> entityTypes,
    Set<String> localAuthoritativeEntityTypes = const <String>{},
    String Function()? createGeneration,
  }) {
    return _rescanLock.run(() async {
      _validateLocalAuthoritativeScope(
        entityTypes: entityTypes,
        localAuthoritativeEntityTypes: localAuthoritativeEntityTypes,
      );
      final generation = (createGeneration ?? const Uuid().v4)().trim();
      if (generation.isEmpty) {
        throw const FormatException('重扫请求代次不能为空');
      }
      final current = rescanRequest;
      final request = CloudSyncRescanRequest(
        generation: generation,
        entityTypes: <String>{...?current?.entityTypes, ...entityTypes},
        localAuthoritativeEntityTypes: <String>{
          ...?current?.localAuthoritativeEntityTypes,
          ...localAuthoritativeEntityTypes,
        },
        activeWriteIds: current?.activeWriteIds ?? const <String>{},
      );
      await _write(_rescanRequestKey, request.toJson());
      return request;
    });
  }

  Future<CloudSyncRescanWriteLease> beginRescanWrite({
    required Set<String> entityTypes,
    Set<String> localAuthoritativeEntityTypes = const <String>{},
    String Function()? createId,
  }) {
    return _rescanLock.run(() async {
      _validateLocalAuthoritativeScope(
        entityTypes: entityTypes,
        localAuthoritativeEntityTypes: localAuthoritativeEntityTypes,
      );
      final writeId = (createId ?? const Uuid().v4)().trim();
      if (writeId.isEmpty) {
        throw const FormatException('重扫写入标识不能为空');
      }
      final current = rescanRequest;
      if (current?.activeWriteIds.contains(writeId) == true) {
        throw StateError('重扫写入标识重复：$writeId');
      }
      final request = CloudSyncRescanRequest(
        generation: const Uuid().v4(),
        entityTypes: <String>{...?current?.entityTypes, ...entityTypes},
        localAuthoritativeEntityTypes:
            current?.localAuthoritativeEntityTypes ?? const <String>{},
        activeWriteIds: <String>{...?current?.activeWriteIds, writeId},
      );
      await _write(_rescanRequestKey, request.toJson());
      return CloudSyncRescanWriteLease(
        writeId,
        localAuthoritativeEntityTypes: localAuthoritativeEntityTypes,
      );
    });
  }

  Future<bool> completeRescanWrite(
    CloudSyncRescanWriteLease lease, {
    bool keepActive = false,
  }) {
    return _rescanLock.run(() async {
      final current = rescanRequest;
      if (current == null || !current.activeWriteIds.contains(lease.writeId)) {
        return false;
      }
      final request = CloudSyncRescanRequest(
        // 完成时旋转代次，让任何与本次写入重叠的旧扫描都无法消费请求。
        generation: const Uuid().v4(),
        entityTypes: current.entityTypes,
        localAuthoritativeEntityTypes: <String>{
          ...current.localAuthoritativeEntityTypes,
          ...lease.localAuthoritativeEntityTypes,
        },
        activeWriteIds: keepActive
            ? current.activeWriteIds
            : current.activeWriteIds.where((id) => id != lease.writeId),
      );
      await _write(_rescanRequestKey, request.toJson());
      return true;
    });
  }

  Future<bool> abortRescanWrite(CloudSyncRescanWriteLease lease) {
    return _rescanLock.run(() async {
      final current = rescanRequest;
      if (current == null || !current.activeWriteIds.contains(lease.writeId)) {
        return false;
      }
      await _write(
        _rescanRequestKey,
        CloudSyncRescanRequest(
          generation: const Uuid().v4(),
          entityTypes: current.entityTypes,
          localAuthoritativeEntityTypes: current.localAuthoritativeEntityTypes,
          activeWriteIds: current.activeWriteIds.where(
            (id) => id != lease.writeId,
          ),
        ).toJson(),
      );
      return true;
    });
  }

  Future<bool> consumeRescanRequest(String expectedGeneration) {
    return _rescanLock.run(() async {
      final normalized = expectedGeneration.trim();
      if (normalized.isEmpty) {
        throw const FormatException('待消费的重扫请求代次不能为空');
      }
      final current = rescanRequest;
      if (current?.generation != normalized || current!.hasActiveWrites) {
        return false;
      }
      // 同步期间可能再次导入，比较删除可避免旧任务清掉更新后的代次。
      await _box.delete(_rescanRequestKey);
      return true;
    });
  }

  Future<void> _migrateLegacyConfigRescan() async {
    final generation = _box.get(_configRescanGenerationKey)?.trim();
    if (generation == null) return;
    if (generation.isEmpty) {
      throw const FormatException('配置重扫代次无效');
    }
    if (rescanRequest == null) {
      final request = CloudSyncRescanRequest(
        generation: generation,
        entityTypes: configRescanEntityTypes,
      );
      await _write(_rescanRequestKey, request.toJson());
    }
    await _box.delete(_configRescanGenerationKey);
  }

  Future<void> _recoverInterruptedRescanWrites() async {
    final current = rescanRequest;
    if (current == null || !current.hasActiveWrites) return;
    await _write(
      _rescanRequestKey,
      CloudSyncRescanRequest(
        generation: const Uuid().v4(),
        entityTypes: current.entityTypes,
        localAuthoritativeEntityTypes: current.localAuthoritativeEntityTypes,
      ).toJson(),
    );
  }

  static Future<void> markDefaultConfigRescanRequired() {
    return markDefaultRescanRequired(configRescanEntityTypes);
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
      _activeOutboxSnapshot(session)?._upsert(sameId);
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
          _activeOutboxSnapshot(session)?._upsert(merged);
          return merged;
        }
      }
    }

    await _write(_outboxKey(session, mutation.mutationId), mutation.toJson());
    _activeOutboxSnapshot(session)?._upsert(mutation);
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
    return _outboxSnapshot(
      session,
    ).forEntity(entityType: entityType, entityId: entityId);
  }

  int outboxCount(CloudSyncAccountSession session) {
    return _outboxSnapshot(session).length;
  }

  ({int total, int blocked}) outboxCounts(CloudSyncAccountSession session) {
    final snapshot = _outboxSnapshot(session);
    return (total: snapshot.length, blocked: snapshot.blockedCount);
  }

  List<CloudSyncOutboxMutation> blockedOutbox(CloudSyncAccountSession session) {
    return _outboxSnapshot(session).blocked;
  }

  _CloudSyncOutboxSnapshot _outboxSnapshot(CloudSyncAccountSession session) {
    return _activeOutboxSnapshot(session) ??
        _CloudSyncOutboxSnapshot(_scanAllOutbox(session));
  }

  Future<T> runWithOutboxSnapshot<T>(
    CloudSyncAccountSession session,
    Future<T> Function() run,
  ) async {
    final scope = session.accountScope;
    if (_activeOutboxSnapshots.containsKey(scope)) {
      throw StateError('同一账号的 outbox 快照作用域不能重叠');
    }
    final snapshot = _CloudSyncOutboxSnapshot(_scanAllOutbox(session));
    _activeOutboxSnapshots[scope] = snapshot;
    try {
      return await run();
    } finally {
      if (identical(_activeOutboxSnapshots[scope], snapshot)) {
        _activeOutboxSnapshots.remove(scope);
      }
    }
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
    return _outboxSnapshot(session)._pending(readyAt: deadline, limit: limit);
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
    _activeOutboxSnapshot(session)?._upsert(blocked);
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
    _activeOutboxSnapshot(session)?._upsert(retried);
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
    _activeOutboxSnapshot(session)?._upsert(attempted);
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
    _activeOutboxSnapshot(session)?._remove(mutationId);
  }

  Future<void> removeOutbox(
    CloudSyncAccountSession session,
    String mutationId,
  ) async {
    await _box.delete(_outboxKey(session, mutationId));
    _activeOutboxSnapshot(session)?._remove(mutationId);
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
    _activeOutboxSnapshot(session)?._clear();
  }

  Future<void> close() async {
    _activeOutboxSnapshots.clear();
    await _box.close();
  }

  _CloudSyncOutboxSnapshot? _activeOutboxSnapshot(
    CloudSyncAccountSession session,
  ) {
    return _activeOutboxSnapshots[session.accountScope];
  }

  List<CloudSyncOutboxMutation> _scanAllOutbox(
    CloudSyncAccountSession session,
  ) {
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

int _compareOutboxByCreation(
  CloudSyncOutboxMutation left,
  CloudSyncOutboxMutation right,
) {
  final byTime = left.createdAt.compareTo(right.createdAt);
  return byTime != 0 ? byTime : left.mutationId.compareTo(right.mutationId);
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
