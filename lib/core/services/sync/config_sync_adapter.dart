import '../../models/api_keys.dart';
import '../../models/assistant.dart';
import '../../models/assistant_memory.dart';
import '../../models/instruction_injection.dart';
import '../../models/provider_group.dart';
import '../../models/quick_phrase.dart';
import '../../models/world_book.dart';
import '../../providers/assistant_provider.dart';
import '../../providers/instruction_injection_provider.dart';
import '../../providers/mcp_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/quick_phrase_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/world_book_provider.dart';
import '../search/search_service.dart';
import '../tts/network_tts.dart';
import '../tts/tts_text_selection.dart';
import 'config_sync_keys.dart';
import 'sync_codec.dart';

class ConfigSyncAdapter implements SyncEntityAdapter {
  ConfigSyncAdapter({
    required SettingsProvider settingsProvider,
    required AssistantProvider assistantProvider,
    required MemoryProvider memoryProvider,
    required McpProvider mcpProvider,
    required QuickPhraseProvider quickPhraseProvider,
    required InstructionInjectionProvider instructionInjectionProvider,
    required WorldBookProvider worldBookProvider,
    required UserProvider userProvider,
  }) : _settings = settingsProvider,
       _assistants = assistantProvider,
       _memories = memoryProvider,
       _mcp = mcpProvider,
       _quickPhrases = quickPhraseProvider,
       _injections = instructionInjectionProvider,
       _worldBooks = worldBookProvider,
       _user = userProvider {
    ready = _initialize();
  }

  static const String _providerType = ConfigSyncKeys.providerType;
  static const String _assistantType = ConfigSyncKeys.assistantType;
  static const String _memoryType = ConfigSyncKeys.memoryType;
  static const String _worldBookType = ConfigSyncKeys.worldBookType;
  static const String _quickPhraseType = ConfigSyncKeys.quickPhraseType;
  static const String _searchServiceType = ConfigSyncKeys.searchServiceType;
  static const String _networkTtsType = ConfigSyncKeys.networkTtsType;
  static const String _mcpServerType = ConfigSyncKeys.mcpServerType;
  static const String _instructionInjectionType =
      ConfigSyncKeys.instructionInjectionType;
  static const String _preferenceType = ConfigSyncKeys.preferenceType;

  static const String _profilePreference = 'profile:default';
  static const String _providerGroupingPreference = 'provider-grouping:default';
  static const String _assistantSelectionPreference =
      'assistant-selection:default';
  static const String _worldBookActivityPreference =
      'world-book-activity:default';
  static const String _injectionActivityPreference =
      'instruction-activity:default';
  static const String _searchStatePreference = 'search-state:default';
  static const String _ttsStatePreference = 'tts-state:default';
  static const String _mcpStatePreference = 'mcp-state:default';
  final SettingsProvider _settings;
  final AssistantProvider _assistants;
  final MemoryProvider _memories;
  final McpProvider _mcp;
  final QuickPhraseProvider _quickPhrases;
  final InstructionInjectionProvider _injections;
  final WorldBookProvider _worldBooks;
  final UserProvider _user;

  late final Future<void> ready;

  @override
  Set<String> get entityTypes => const <String>{
    _providerType,
    _assistantType,
    _memoryType,
    _worldBookType,
    _quickPhraseType,
    _searchServiceType,
    _networkTtsType,
    _mcpServerType,
    _instructionInjectionType,
    _preferenceType,
  };

  @override
  int get applyPriority => 20;

  @override
  Future<T> runRemoteBatch<T>(Future<T> Function() apply) {
    return _settings.runNotificationBatch(
      () => _assistants.runNotificationBatch(
        () => _memories.runNotificationBatch(
          () => _mcp.runNotificationBatch(
            () => _quickPhrases.runNotificationBatch(
              () => _injections.runNotificationBatch(
                () => _worldBooks.runNotificationBatch(
                  () => _user.runNotificationBatch(apply),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _initialize() async {
    await Future.wait<void>(<Future<void>>[
      _settings.ready,
      _assistants.ready,
      _mcp.ready,
      _user.ready,
      _memories.initialize(),
      _quickPhrases.initialize(),
      _injections.initialize(),
      _worldBooks.initialize(),
    ]);
  }

  @override
  Future<LocalSyncEntity?> exportLocalEntity(SyncEntityKey key) async {
    await ready;
    for (final entity in _exportEntitiesForType(key.entityType)) {
      if (entity.entityId == key.entityId) return entity;
    }
    return null;
  }

  @override
  Future<Map<SyncEntityKey, LocalSyncEntity>> exportLocalEntitiesForKeys(
    Set<SyncEntityKey> keys,
  ) async {
    await ready;
    final keysByType = <String, Set<SyncEntityKey>>{};
    for (final key in keys) {
      if (!entityTypes.contains(key.entityType)) {
        throw FormatException('不支持的配置同步实体：${key.entityType}');
      }
      (keysByType[key.entityType] ??= <SyncEntityKey>{}).add(key);
    }

    final result = <SyncEntityKey, LocalSyncEntity>{};
    for (final entry in keysByType.entries) {
      for (final entity in _exportEntitiesForType(entry.key)) {
        if (entry.value.contains(entity.key)) {
          result[entity.key] = entity;
        }
      }
    }
    return Map<SyncEntityKey, LocalSyncEntity>.unmodifiable(result);
  }

  Iterable<LocalSyncEntity> _exportEntitiesForType(String entityType) {
    return switch (entityType) {
      _providerType => _exportProviders(),
      _assistantType => _exportAssistants(),
      _memoryType => _exportMemories(),
      _worldBookType => _exportWorldBooks(),
      _quickPhraseType => _exportQuickPhrases(),
      _searchServiceType => _exportSearchServices(),
      _networkTtsType => _exportTtsServices(),
      _mcpServerType => _exportMcpServers(),
      _instructionInjectionType => _exportInstructionInjections(),
      _preferenceType => _exportPreferences(),
      _ => throw FormatException('不支持的配置同步实体：$entityType'),
    };
  }

  @override
  Future<List<LocalSyncEntity>> exportLocalEntities() async {
    await ready;
    return <LocalSyncEntity>[
      ..._exportProviders(),
      ..._exportAssistants(),
      ..._exportMemories(),
      ..._exportWorldBooks(),
      ..._exportQuickPhrases(),
      ..._exportSearchServices(),
      ..._exportTtsServices(),
      ..._exportMcpServers(),
      ..._exportInstructionInjections(),
      ..._exportPreferences(),
    ];
  }

  Iterable<LocalSyncEntity> _exportProviders() sync* {
    var fallbackPosition = _settings.providersOrder.length;
    for (final entry in _settings.providerConfigs.entries) {
      final position = _settings.providersOrder.indexOf(entry.key);
      yield LocalSyncEntity(
        entityType: _providerType,
        entityId: entry.key,
        payload: _providerPayload(
          entry.value,
          position: position < 0 ? fallbackPosition++ : position,
        ),
      );
    }
  }

  Iterable<LocalSyncEntity> _exportAssistants() sync* {
    for (var index = 0; index < _assistants.assistants.length; index++) {
      final assistant = _assistants.assistants[index];
      final payload = _mutableJsonObject(assistant.toJson());
      payload.remove('id');
      payload['_position'] = index;
      if (_isLocalPath(assistant.avatar)) payload['avatar'] = null;
      if (_isLocalPath(assistant.background)) payload['background'] = null;
      yield LocalSyncEntity(
        entityType: _assistantType,
        entityId: assistant.id,
        payload: payload,
      );
    }
  }

  Iterable<LocalSyncEntity> _exportMemories() sync* {
    for (final memory in _memories.memories) {
      final payload = _mutableJsonObject(memory.toJson())
        ..remove('id')
        ..remove('syncId');
      yield LocalSyncEntity(
        entityType: _memoryType,
        entityId: memory.syncId,
        parentId: memory.assistantId,
        payload: payload,
      );
    }
  }

  Iterable<LocalSyncEntity> _exportWorldBooks() sync* {
    for (var index = 0; index < _worldBooks.books.length; index++) {
      final book = _worldBooks.books[index];
      yield LocalSyncEntity(
        entityType: _worldBookType,
        entityId: book.id,
        payload: _mutableJsonObject(book.toJson())
          ..remove('id')
          ..['_position'] = index,
      );
    }
  }

  Iterable<LocalSyncEntity> _exportQuickPhrases() sync* {
    for (var index = 0; index < _quickPhrases.phrases.length; index++) {
      final phrase = _quickPhrases.phrases[index];
      yield LocalSyncEntity(
        entityType: _quickPhraseType,
        entityId: phrase.id,
        parentId: phrase.assistantId,
        payload: _mutableJsonObject(phrase.toJson())
          ..remove('id')
          ..['_position'] = index,
      );
    }
  }

  Iterable<LocalSyncEntity> _exportSearchServices() sync* {
    for (var index = 0; index < _settings.searchServices.length; index++) {
      final service = _settings.searchServices[index];
      yield LocalSyncEntity(
        entityType: _searchServiceType,
        entityId: service.id,
        payload: _mutableJsonObject(service.toJson())
          ..remove('id')
          ..['_position'] = index,
      );
    }
  }

  Iterable<LocalSyncEntity> _exportTtsServices() sync* {
    for (var index = 0; index < _settings.ttsServices.length; index++) {
      final service = _settings.ttsServices[index];
      yield LocalSyncEntity(
        entityType: _networkTtsType,
        entityId: service.id,
        payload: _mutableJsonObject(service.toJson())
          ..remove('id')
          ..['_position'] = index,
      );
    }
  }

  Iterable<LocalSyncEntity> _exportMcpServers() sync* {
    var position = 0;
    for (final server in _mcp.servers) {
      if (server.transport != McpTransportType.http &&
          server.transport != McpTransportType.sse) {
        continue;
      }
      yield LocalSyncEntity(
        entityType: _mcpServerType,
        entityId: server.id,
        payload: _mutableJsonObject(server.toJson())
          ..remove('id')
          ..['_position'] = position++,
      );
    }
  }

  Iterable<LocalSyncEntity> _exportInstructionInjections() sync* {
    for (var index = 0; index < _injections.items.length; index++) {
      final item = _injections.items[index];
      yield LocalSyncEntity(
        entityType: _instructionInjectionType,
        entityId: item.id,
        payload: _mutableJsonObject(item.toJson())
          ..remove('id')
          ..['_position'] = index,
      );
    }
  }

  Iterable<LocalSyncEntity> _exportPreferences() sync* {
    final profile = <String, Object?>{'name': _user.name};
    if (_user.avatarType != 'file' &&
        !_isLocalPath(_user.avatarValue) &&
        _user.avatarType != null &&
        _user.avatarValue != null) {
      profile['avatarType'] = _user.avatarType;
      profile['avatarValue'] = _user.avatarValue;
    }
    yield LocalSyncEntity(
      entityType: _preferenceType,
      entityId: _profilePreference,
      payload: profile,
    );

    yield LocalSyncEntity(
      entityType: _preferenceType,
      entityId: _providerGroupingPreference,
      payload: <String, Object?>{
        'groups': _settings.providerGroups
            .map((e) => _mutableJsonObject(e.toJson()))
            .toList(growable: false),
        'assignments': Map<String, Object?>.from(
          _settings.providerGroupAssignments,
        ),
        'ungroupedPosition': _settings.providerUngroupedDisplayIndex,
      },
    );

    yield LocalSyncEntity(
      entityType: _preferenceType,
      entityId: _assistantSelectionPreference,
      payload: <String, Object?>{'assistantId': _assistants.currentAssistantId},
    );
    yield LocalSyncEntity(
      entityType: _preferenceType,
      entityId: _worldBookActivityPreference,
      payload: <String, Object?>{
        'activeIdsByAssistant': _stringListMap(
          _worldBooks.activeIdsByAssistant,
        ),
      },
    );
    yield LocalSyncEntity(
      entityType: _preferenceType,
      entityId: _injectionActivityPreference,
      payload: <String, Object?>{
        'activeIdsByAssistant': _stringListMap(
          _injections.activeIdsByAssistant,
        ),
      },
    );

    final selectedSearch =
        _settings.searchServiceSelected >= 0 &&
            _settings.searchServiceSelected < _settings.searchServices.length
        ? _settings.searchServices[_settings.searchServiceSelected].id
        : null;
    yield LocalSyncEntity(
      entityType: _preferenceType,
      entityId: _searchStatePreference,
      payload: <String, Object?>{
        'selectedServiceId': selectedSearch,
        'commonOptions': _mutableJsonObject(
          _settings.searchCommonOptions.toJson(),
        ),
        'enabled': _settings.searchEnabled,
        'autoTestOnLaunch': _settings.searchAutoTestOnLaunch,
      },
    );

    yield LocalSyncEntity(
      entityType: _preferenceType,
      entityId: _ttsStatePreference,
      payload: <String, Object?>{
        'selectedServiceId': _settings.selectedTtsService?.id,
        'autoPlayAssistantReplies': _settings.ttsAutoPlayAssistantReplies,
        'textSelectionMode': _settings.ttsTextSelectionMode.name,
      },
    );
    yield LocalSyncEntity(
      entityType: _preferenceType,
      entityId: _mcpStatePreference,
      payload: <String, Object?>{
        'requestTimeoutSeconds': _mcp.requestTimeoutSeconds,
      },
    );
  }

  @override
  Future<void> applyRemoteUpsert(RemoteSyncEntity entity) async {
    await ready;
    final payload = validateSyncJsonObject(entity.payload);
    switch (entity.entityType) {
      case _providerType:
        await _applyProvider(entity.entityId, payload);
      case _assistantType:
        await _applyAssistant(entity.entityId, payload);
      case _memoryType:
        await _applyMemory(entity.entityId, payload);
      case _worldBookType:
        await _worldBooks.syncUpsert(
          WorldBook.fromJson(<String, Object?>{
            ...payload,
            'id': entity.entityId,
          }),
          position: _position(payload),
        );
      case _quickPhraseType:
        await _quickPhrases.syncUpsert(
          QuickPhrase.fromJson(<String, Object?>{
            ...payload,
            'id': entity.entityId,
          }),
          position: _position(payload),
        );
      case _searchServiceType:
        await _settings.syncUpsertSearchService(
          SearchServiceOptions.fromJson(<String, Object?>{
            ...payload,
            'id': entity.entityId,
          }),
          position: _position(payload),
        );
      case _networkTtsType:
        await _settings.syncUpsertTtsService(
          TtsServiceOptions.fromJson(<String, Object?>{
            ...payload,
            'id': entity.entityId,
          }),
          position: _position(payload),
        );
      case _mcpServerType:
        await _applyMcpServer(entity.entityId, payload);
      case _instructionInjectionType:
        await _injections.syncUpsert(
          InstructionInjection.fromJson(<String, Object?>{
            ...payload,
            'id': entity.entityId,
          }),
          position: _position(payload),
        );
      case _preferenceType:
        await _applyPreference(entity.entityId, payload);
      default:
        throw FormatException('不支持的配置同步实体：${entity.entityType}');
    }
  }

  Future<void> _applyProvider(
    String entityId,
    Map<String, Object?> payload,
  ) async {
    final sanitized = _sanitizeProviderPayload(payload);
    final current = _settings.providerConfigs[entityId];
    var config = ProviderConfig.fromJson(<String, Object?>{
      ...sanitized,
      'id': entityId,
    });
    final currentKeys = <String, ApiKeyConfig>{
      for (final key in current?.apiKeys ?? const <ApiKeyConfig>[]) key.id: key,
    };
    final mergedKeys = config.apiKeys
        ?.map((key) {
          final local = currentKeys[key.id];
          if (local == null) return key;
          return key.copyWith(
            usage: local.usage,
            status: local.status,
            lastError: local.lastError,
          );
        })
        .toList(growable: false);
    final localRoundRobinIndex = current?.keyManagement?.roundRobinIndex;
    config = config.copyWith(
      id: entityId,
      apiKeys: mergedKeys,
      keyManagement: localRoundRobinIndex == null
          ? config.keyManagement
          : config.keyManagement?.copyWith(
              roundRobinIndex: localRoundRobinIndex,
            ),
      proxyEnabled: current?.proxyEnabled,
      proxyType: current?.proxyType,
      proxyHost: current?.proxyHost,
      proxyPort: current?.proxyPort,
      proxyUsername: current?.proxyUsername,
      proxyPassword: current?.proxyPassword,
      avatarType: sanitized.containsKey('avatarType')
          ? config.avatarType
          : current?.avatarType,
      avatarValue: sanitized.containsKey('avatarValue')
          ? config.avatarValue
          : current?.avatarValue,
    );
    await _settings.syncUpsertProviderConfig(
      entityId,
      config,
      position: _position(payload),
    );
  }

  Future<void> _applyAssistant(
    String entityId,
    Map<String, Object?> payload,
  ) async {
    final sanitized = _mutableJsonObject(payload);
    if (_isLocalPath(_optionalString(sanitized, 'avatar'))) {
      sanitized.remove('avatar');
    }
    if (_isLocalPath(_optionalString(sanitized, 'background'))) {
      sanitized.remove('background');
    }
    final decoded = Assistant.fromJson(<String, Object?>{
      ...sanitized,
      'id': entityId,
    });
    final current = _assistants.getById(entityId);
    final assistant = decoded.copyWith(
      avatar: sanitized.containsKey('avatar')
          ? decoded.avatar ??
                (_isLocalPath(current?.avatar) ? current?.avatar : null)
          : current?.avatar,
      background: sanitized.containsKey('background')
          ? decoded.background ??
                (_isLocalPath(current?.background) ? current?.background : null)
          : current?.background,
    );
    await _assistants.syncUpsertAssistant(
      assistant,
      position: _position(payload),
    );
  }

  Future<void> _applyMemory(
    String entityId,
    Map<String, Object?> payload,
  ) async {
    final memory = AssistantMemory.fromJson(<String, Object?>{
      ...payload,
      'syncId': entityId,
    });
    await _memories.syncUpsert(memory);
  }

  Future<void> _applyMcpServer(
    String entityId,
    Map<String, Object?> payload,
  ) async {
    final server = McpServerConfig.fromJson(<String, Object?>{
      ...payload,
      'id': entityId,
    });
    if (server.transport != McpTransportType.http &&
        server.transport != McpTransportType.sse) {
      throw const FormatException('云同步仅接受 HTTP 或 SSE MCP 服务');
    }
    await _mcp.syncUpsertServer(server, position: _position(payload));
  }

  Future<void> _applyPreference(
    String entityId,
    Map<String, Object?> payload,
  ) async {
    switch (entityId) {
      case _profilePreference:
        final hasAvatarType = payload.containsKey('avatarType');
        final hasAvatarValue = payload.containsKey('avatarValue');
        if (hasAvatarType != hasAvatarValue) {
          throw const FormatException('资料头像类型和值必须同时出现');
        }
        final avatarType = _optionalString(payload, 'avatarType');
        final avatarValue = _optionalString(payload, 'avatarValue');
        final hasPortableAvatar = hasAvatarType && avatarType != null;
        if (hasPortableAvatar &&
            (avatarValue == null ||
                avatarValue.trim().isEmpty ||
                avatarType == 'file' ||
                _isLocalPath(avatarValue))) {
          throw const FormatException('云端资料头像必须是可跨设备使用的值');
        }
        final localAvatarIsFile =
            _user.avatarType == 'file' || _isLocalPath(_user.avatarValue);
        await _user.syncApplyProfile(
          name: _requiredString(payload, 'name'),
          replaceAvatar: hasAvatarType || !localAvatarIsFile,
          avatarType: hasPortableAvatar ? avatarType : null,
          avatarValue: hasPortableAvatar ? avatarValue : null,
        );
      case _providerGroupingPreference:
        await _applyProviderGrouping(payload);
      case _assistantSelectionPreference:
        await _assistants.syncSetCurrentAssistant(
          _optionalString(payload, 'assistantId'),
        );
      case _worldBookActivityPreference:
        await _worldBooks.syncReplaceActiveIds(
          _readStringListMap(payload, 'activeIdsByAssistant'),
        );
      case _injectionActivityPreference:
        await _injections.syncReplaceActiveIds(
          _readStringListMap(payload, 'activeIdsByAssistant'),
        );
      case _searchStatePreference:
        await _settings.syncApplySearchState(
          selectedServiceId: _optionalString(payload, 'selectedServiceId'),
          commonOptions: SearchCommonOptions.fromJson(
            _requiredObject(payload, 'commonOptions'),
          ),
          enabled: _requiredBool(payload, 'enabled'),
          autoTestOnLaunch: _requiredBool(payload, 'autoTestOnLaunch'),
        );
      case _ttsStatePreference:
        await _settings.syncApplyTtsState(
          selectedServiceId: _optionalString(payload, 'selectedServiceId'),
          autoPlayAssistantReplies: _requiredBool(
            payload,
            'autoPlayAssistantReplies',
          ),
          textSelectionMode: TtsTextSelectionModeStorage.fromStorageValue(
            _optionalString(payload, 'textSelectionMode'),
          ),
        );
      case _mcpStatePreference:
        final seconds = _requiredInt(payload, 'requestTimeoutSeconds');
        if (seconds <= 0) {
          throw const FormatException('MCP 请求超时时间必须大于零');
        }
        await _mcp.syncUpdateRequestTimeout(Duration(seconds: seconds));
      default:
        throw FormatException('不支持的配置同步偏好：$entityId');
    }
  }

  Future<void> _applyProviderGrouping(Map<String, Object?> payload) async {
    final rawGroups = payload['groups'];
    if (rawGroups is! List<Object?>) {
      throw const FormatException('供应商分组必须是数组');
    }
    final groups = rawGroups
        .map(_strictJsonObject)
        .map(ProviderGroup.fromJson)
        .toList(growable: false);
    final assignments = <String, String>{};
    final rawAssignments = _requiredObject(payload, 'assignments');
    for (final entry in rawAssignments.entries) {
      final groupId = entry.value;
      if (groupId is! String) {
        throw const FormatException('供应商分组关系必须是字符串');
      }
      assignments[entry.key] = groupId;
    }
    await _settings.syncApplyProviderGrouping(
      groups: groups,
      assignments: assignments,
      ungroupedPosition: _requiredInt(payload, 'ungroupedPosition'),
    );
  }

  @override
  Future<void> applyRemoteDelete(SyncEntityKey key) async {
    await ready;
    switch (key.entityType) {
      case _providerType:
        await _settings.syncDeleteProviderConfig(key.entityId);
      case _assistantType:
        await _assistants.syncDeleteAssistant(key.entityId);
      case _memoryType:
        await _memories.syncDelete(key.entityId);
      case _worldBookType:
        await _worldBooks.syncDelete(key.entityId);
      case _quickPhraseType:
        await _quickPhrases.syncDelete(key.entityId);
      case _searchServiceType:
        await _settings.syncDeleteSearchService(key.entityId);
      case _networkTtsType:
        await _settings.syncDeleteTtsService(key.entityId);
      case _mcpServerType:
        await _mcp.syncDeleteServer(key.entityId);
      case _instructionInjectionType:
        await _injections.syncDelete(key.entityId);
      case _preferenceType:
        await _deletePreference(key.entityId);
      default:
        throw FormatException('不支持的配置同步实体：${key.entityType}');
    }
  }

  Future<void> _deletePreference(String entityId) async {
    switch (entityId) {
      case _profilePreference:
        await _user.syncApplyProfile(
          name: 'User',
          replaceAvatar: _user.avatarType != 'file',
        );
      case _providerGroupingPreference:
        await _settings.syncApplyProviderGrouping(
          groups: const <ProviderGroup>[],
          assignments: const <String, String>{},
          ungroupedPosition: 0,
        );
      case _assistantSelectionPreference:
        await _assistants.syncSetCurrentAssistant(null);
      case _worldBookActivityPreference:
        await _worldBooks.syncReplaceActiveIds(const <String, List<String>>{});
      case _injectionActivityPreference:
        await _injections.syncReplaceActiveIds(const <String, List<String>>{});
      case _searchStatePreference:
        await _settings.syncApplySearchState(
          selectedServiceId: null,
          commonOptions: const SearchCommonOptions(),
          enabled: false,
          autoTestOnLaunch: false,
        );
      case _ttsStatePreference:
        await _settings.syncApplyTtsState(
          selectedServiceId: null,
          autoPlayAssistantReplies: false,
          textSelectionMode: TtsTextSelectionMode.fullText,
        );
      case _mcpStatePreference:
        await _mcp.syncUpdateRequestTimeout(const Duration(seconds: 30));
      default:
        throw FormatException('不支持的配置同步偏好：$entityId');
    }
  }

  Map<String, Object?> _providerPayload(
    ProviderConfig config, {
    required int position,
  }) {
    final payload = _mutableJsonObject(config.toJson());
    payload.remove('id');
    payload['_position'] = position;
    payload.remove('proxyEnabled');
    payload.remove('proxyType');
    payload.remove('proxyHost');
    payload.remove('proxyPort');
    payload.remove('proxyUsername');
    payload.remove('proxyPassword');
    if (config.avatarType == 'file' || _isLocalPath(config.avatarValue)) {
      payload.remove('avatarType');
      payload.remove('avatarValue');
    }
    payload['apiKeys'] = config.apiKeys
        ?.map(
          (key) => <String, Object?>{
            'id': key.id,
            'key': key.key,
            'name': key.name,
            'isEnabled': key.isEnabled,
            'priority': key.priority,
            'maxRequestsPerMinute': key.maxRequestsPerMinute,
            'createdAt': key.createdAt,
            'updatedAt': key.updatedAt,
          },
        )
        .toList(growable: false);
    final management = config.keyManagement;
    payload['keyManagement'] = <String, Object?>{
      'strategy':
          management?.strategy.name ?? LoadBalanceStrategy.roundRobin.name,
      'maxFailuresBeforeDisable': management?.maxFailuresBeforeDisable ?? 3,
      'failureRecoveryTimeMinutes': management?.failureRecoveryTimeMinutes ?? 5,
      'enableAutoRecovery': management?.enableAutoRecovery ?? true,
    };
    return payload;
  }

  static Map<String, Object?> _sanitizeProviderPayload(
    Map<String, Object?> payload,
  ) {
    final sanitized = _mutableJsonObject(payload);
    sanitized.remove('proxyEnabled');
    sanitized.remove('proxyType');
    sanitized.remove('proxyHost');
    sanitized.remove('proxyPort');
    sanitized.remove('proxyUsername');
    sanitized.remove('proxyPassword');
    if (sanitized['avatarType'] == 'file' ||
        _isLocalPath(_optionalString(sanitized, 'avatarValue'))) {
      sanitized.remove('avatarType');
      sanitized.remove('avatarValue');
    }

    final rawKeys = sanitized['apiKeys'];
    if (rawKeys != null) {
      if (rawKeys is! List<Object?>) {
        throw const FormatException('供应商多 Key 配置必须是数组');
      }
      sanitized['apiKeys'] = rawKeys
          .map((value) {
            final key = _strictJsonObject(value);
            return <String, Object?>{
              'id': key['id'],
              'key': key['key'],
              'name': key['name'],
              'isEnabled': key['isEnabled'],
              'priority': key['priority'],
              'maxRequestsPerMinute': key['maxRequestsPerMinute'],
              'createdAt': key['createdAt'],
              'updatedAt': key['updatedAt'],
            };
          })
          .toList(growable: false);
    }

    final rawManagement = sanitized['keyManagement'];
    if (rawManagement != null) {
      final management = _strictJsonObject(rawManagement);
      sanitized['keyManagement'] = <String, Object?>{
        'strategy': management['strategy'],
        'maxFailuresBeforeDisable': management['maxFailuresBeforeDisable'],
        'failureRecoveryTimeMinutes': management['failureRecoveryTimeMinutes'],
        'enableAutoRecovery': management['enableAutoRecovery'],
      };
    }
    return sanitized;
  }

  static int _position(Map<String, Object?> payload) {
    final value = payload['_position'];
    if (value is int && value >= 0) return value;
    throw const FormatException('有序同步配置必须包含非负整数位置');
  }

  static bool _isLocalPath(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return false;
    return normalized.startsWith('/') ||
        normalized.startsWith(r'\') ||
        normalized.startsWith('file:') ||
        RegExp(r'^[A-Za-z]:[\\/]').hasMatch(normalized);
  }

  static Map<String, Object?> _stringListMap(
    Map<String, List<String>> source,
  ) => <String, Object?>{
    for (final entry in source.entries)
      entry.key: List<String>.unmodifiable(entry.value),
  };

  static Map<String, List<String>> _readStringListMap(
    Map<String, Object?> payload,
    String key,
  ) {
    final raw = _requiredObject(payload, key);
    final result = <String, List<String>>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! List<Object?> || value.any((e) => e is! String)) {
        throw FormatException('$key 必须是字符串数组映射');
      }
      result[entry.key] = value.cast<String>();
    }
    return result;
  }

  static Map<String, Object?> _strictJsonObject(Object? value) {
    if (value is! Map) throw const FormatException('同步配置必须是 JSON 对象');
    final result = <String, Object?>{};
    for (final key in value.keys) {
      if (key is! String) throw const FormatException('同步配置键必须是字符串');
      result[key] = value[key];
    }
    return validateSyncJsonObject(result);
  }

  static Map<String, Object?> _mutableJsonObject(Object? value) =>
      Map<String, Object?>.from(_strictJsonObject(value));

  static Map<String, Object?> _requiredObject(
    Map<String, Object?> payload,
    String key,
  ) {
    final value = payload[key];
    if (value is! Map<String, Object?>) {
      throw FormatException('$key 必须是 JSON 对象');
    }
    return value;
  }

  static String _requiredString(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key 必须是非空字符串');
    }
    return value;
  }

  static String? _optionalString(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value == null) return null;
    if (value is! String) throw FormatException('$key 必须是字符串或 null');
    return value;
  }

  static bool _requiredBool(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is! bool) throw FormatException('$key 必须是布尔值');
    return value;
  }

  static int _requiredInt(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is! num || !value.isFinite || value % 1 != 0) {
      throw FormatException('$key 必须是整数');
    }
    return value.toInt();
  }
}
