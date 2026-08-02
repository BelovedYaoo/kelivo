import 'dart:async';

import 'package:path/path.dart' as p;

import '../../database/chat_database_repository.dart';
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
import 'e2ee_attachment_manifest.dart';
import 'e2ee_config_asset_types.dart';
import 'e2ee_config_sync_binding.dart';
import 'e2ee_config_sync_payload_schema.dart';
import 'e2ee_config_sync_adapter.dart';
import 'e2ee_sync_outbox.dart';
import 'e2ee_sync_payload_codec.dart';
import 'e2ee_sync_pull_types.dart';
import 'sync_codec.dart';

typedef E2eeConfigProviderClock = DateTime Function();

/// 将十类账户配置的 Provider 内存态绑定到唯一 SQLCipher Vault 真相。
final class E2eeConfigProviderBinding implements E2eeConfigSyncBinding {
  E2eeConfigProviderBinding({
    required SettingsProvider settingsProvider,
    required AssistantProvider assistantProvider,
    required MemoryProvider memoryProvider,
    required McpProvider mcpProvider,
    required QuickPhraseProvider quickPhraseProvider,
    required InstructionInjectionProvider instructionInjectionProvider,
    required WorldBookProvider worldBookProvider,
    required UserProvider userProvider,
    E2eeConfigProviderClock clock = _defaultUtcNow,
  }) : _settings = settingsProvider,
       _assistants = assistantProvider,
       _memories = memoryProvider,
       _mcp = mcpProvider,
       _quickPhrases = quickPhraseProvider,
       _injections = instructionInjectionProvider,
       _worldBooks = worldBookProvider,
       _user = userProvider,
       _utcNow = clock;

  final SettingsProvider _settings;
  final AssistantProvider _assistants;
  final MemoryProvider _memories;
  final McpProvider _mcp;
  final QuickPhraseProvider _quickPhrases;
  final InstructionInjectionProvider _injections;
  final WorldBookProvider _worldBooks;
  final UserProvider _user;
  final E2eeConfigProviderClock _utcNow;
  final _ConfigProviderOperationLock _operationLock =
      _ConfigProviderOperationLock();

  E2eeConfigVaultCommands? _commands;
  E2eeConfigAssetCommands? _assetCommands;
  E2eeConfigSyncAdapter? _adapter;
  Set<SyncEntityKey>? _activeRemoteKeys;
  bool _initialized = false;
  bool _failed = false;

  bool get initialized => _initialized && !_failed;

  @override
  Future<void> initialize(
    E2eeConfigVaultCommands commands,
    E2eeConfigAssetCommands assetCommands,
  ) {
    return _operationLock.run(() async {
      if (_failed) throw StateError('E2EE 配置 Provider 桥接已经失败');
      if (_initialized) throw StateError('E2EE 配置 Provider 桥接不能重复初始化');
      _commands = commands;
      _assetCommands = assetCommands;
      _adapter = E2eeConfigSyncAdapter(
        commands: commands,
        assetCommands: assetCommands,
        now: _utcNow,
      );
      try {
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
        final entries = <E2eeConfigVaultEntry>[];
        for (final entityType in ConfigSyncKeys.entityTypes) {
          entries.addAll(await commands.readByType(entityType));
        }
        entries.sort(_compareVaultEntries);
        final hasGenerationSettings = entries.any(
          (entry) => entry.key == ConfigSyncKeys.generationSettings,
        );
        await _runNotificationBatch(() async {
          for (final entry in entries) {
            final payload = E2eeSyncPayloadCodec.decode(
              entityKey: entry.key,
              bytes: entry.payload,
            );
            await _applyValue(entry.key, payload);
          }
          if (!hasGenerationSettings) {
            await _applyDelete(ConfigSyncKeys.generationSettings);
          }
        });
        _initialized = true;
      } catch (_) {
        _failed = true;
        rethrow;
      }
    });
  }

  @override
  Future<E2eeSyncEntitySnapshot> readSnapshot(SyncEntityKey entityKey) {
    _requireReady();
    return _adapter!.readSnapshot(entityKey);
  }

  @override
  Future<T> runLocalWrite<T>({
    required Iterable<SyncEntityKey> configKeys,
    required Future<T> Function(Future<T> Function() write) transaction,
    required Future<T> Function() write,
  }) {
    final keys = _normalizeConfigKeys(configKeys);
    if (keys.isEmpty) return transaction(write);
    return _operationLock.run(() async {
      _requireReady();
      try {
        return await transaction(() async {
          final result = await write();
          await _persistKeys(keys);
          return result;
        });
      } catch (error, stackTrace) {
        await _restoreOrFail(keys);
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
  }

  @override
  Future<T> runRemotePull<T>(Future<T> Function() pull) {
    return _operationLock.run(() async {
      _requireReady();
      if (_activeRemoteKeys != null) {
        throw StateError('E2EE 配置远端拉取不能重入');
      }
      final touchedKeys = <SyncEntityKey>{};
      _activeRemoteKeys = touchedKeys;
      try {
        return await pull();
      } catch (error, stackTrace) {
        await _restoreOrFail(touchedKeys);
        Error.throwWithStackTrace(error, stackTrace);
      } finally {
        _activeRemoteKeys = null;
      }
    });
  }

  /// 必须由 pull coordinator 放在 Vault、ledger 与 checkpoint 的同一事务中。
  @override
  Future<void> applyTransactional(
    List<E2eeSyncPulledChange> applicableChanges,
  ) async {
    _requireReady();
    if (applicableChanges.isEmpty) return;
    final activeKeys = _activeRemoteKeys;
    if (activeKeys == null) {
      throw StateError('E2EE 配置远端应用缺少拉取事务边界');
    }
    final changes = applicableChanges.toList(growable: false)
      ..sort(_compareConfigChanges);
    activeKeys.addAll(changes.map((change) => change.state.entityKey));
    await _adapter!.applyTransactional(changes);
    await _runNotificationBatch(() async {
      for (final change in changes) {
        switch (change) {
          case E2eeSyncPulledValueChange(:final payload):
            await _applyValue(change.state.entityKey, payload);
          case E2eeSyncPulledTombstoneChange():
            await _applyDelete(change.state.entityKey);
        }
      }
    });
  }

  Future<void> _persistKeys(List<SyncEntityKey> keys) async {
    final commands = _commands!;
    final updatedAt = _utcNow().toUtc();
    for (final key in keys) {
      final payload = await _exportPayload(key);
      if (payload == null) {
        await commands.delete(key);
        continue;
      }
      final encoded = E2eeSyncPayloadCodec.encode(
        entityKey: key,
        payload: payload,
      );
      try {
        await commands.put(key: key, payload: encoded, updatedAt: updatedAt);
      } finally {
        encoded.fillRange(0, encoded.length, 0);
      }
    }
  }

  Future<void> _restoreOrFail(Iterable<SyncEntityKey> keys) async {
    try {
      await _restoreKeys(keys);
    } catch (error, stackTrace) {
      _failed = true;
      Error.throwWithStackTrace(
        StateError('E2EE 配置 Provider 回滚恢复失败：$error'),
        stackTrace,
      );
    }
  }

  Future<void> _restoreKeys(Iterable<SyncEntityKey> keys) async {
    final commands = _commands!;
    final ordered = _normalizeConfigKeys(keys)..sort(_compareConfigKeys);
    await _runNotificationBatch(() async {
      for (final key in ordered) {
        final entry = await commands.read(key);
        if (entry == null) {
          await _applyDelete(key);
          continue;
        }
        final payload = E2eeSyncPayloadCodec.decode(
          entityKey: key,
          bytes: entry.payload,
        );
        await _applyValue(key, payload);
      }
    });
  }

  Future<T> _runNotificationBatch<T>(Future<T> Function() action) {
    return _settings.runNotificationBatch(
      () => _assistants.runNotificationBatch(
        () => _memories.runNotificationBatch(
          () => _mcp.runNotificationBatch(
            () => _quickPhrases.runNotificationBatch(
              () => _injections.runNotificationBatch(
                () => _worldBooks.runNotificationBatch(
                  () => _user.runNotificationBatch(action),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<Map<String, Object?>?> _exportPayload(SyncEntityKey key) async {
    ConfigSyncKeys.validate(key);
    return switch (key.entityType) {
      ConfigSyncKeys.providerType => await _exportProvider(key.entityId),
      ConfigSyncKeys.assistantType => await _exportAssistant(key.entityId),
      ConfigSyncKeys.memoryType => _exportMemory(key.entityId),
      ConfigSyncKeys.worldBookType => _exportWorldBook(key.entityId),
      ConfigSyncKeys.quickPhraseType => _exportQuickPhrase(key.entityId),
      ConfigSyncKeys.searchServiceType => _exportSearchService(key.entityId),
      ConfigSyncKeys.networkTtsType => _exportTtsService(key.entityId),
      ConfigSyncKeys.mcpServerType => _exportMcpServer(key.entityId),
      ConfigSyncKeys.instructionInjectionType => _exportInjection(key.entityId),
      ConfigSyncKeys.preferenceType => await _exportPreference(key),
      _ => throw StateError('sync_config_entity_type_unreachable'),
    };
  }

  Future<Map<String, Object?>?> _exportProvider(String id) async {
    final config = _settings.providerConfigs[id];
    if (config == null) return null;
    final avatarAsset = await _exportConfigAsset(
      E2eeConfigAssetKey(
        entityKey: ConfigSyncKeys.provider(id),
        slot: E2eeConfigAssetSlot.avatar,
      ),
      config.avatarValue,
      managed: config.avatarType == 'file',
      context: '供应商头像',
    );
    final payload = _jsonObject(config.toJson());
    final orderIndex = _settings.providersOrder.indexOf(id);
    payload['_position'] = orderIndex < 0
        ? _settings.providerConfigs.keys.toList().indexOf(id)
        : orderIndex;
    payload['avatarAsset'] = avatarAsset.identity?.toPayload();
    if (avatarAsset.managed) {
      payload['avatarType'] = null;
      payload['avatarValue'] = null;
    }
    return payload;
  }

  Future<Map<String, Object?>?> _exportAssistant(String id) async {
    final assistant = _assistants.getById(id);
    if (assistant == null) return null;
    final entityKey = ConfigSyncKeys.assistant(id);
    final avatarAsset = await _exportConfigAsset(
      E2eeConfigAssetKey(
        entityKey: entityKey,
        slot: E2eeConfigAssetSlot.avatar,
      ),
      assistant.avatar,
      managed: _isLocalPath(assistant.avatar),
      context: '助手头像',
    );
    final backgroundAsset = await _exportConfigAsset(
      E2eeConfigAssetKey(
        entityKey: entityKey,
        slot: E2eeConfigAssetSlot.background,
      ),
      assistant.background,
      managed: _isLocalPath(assistant.background),
      context: '助手背景',
    );
    final payload = _jsonObject(assistant.toJson());
    payload['_position'] = _assistants.assistants.indexWhere(
      (candidate) => candidate.id == id,
    );
    payload['avatarAsset'] = avatarAsset.identity?.toPayload();
    payload['backgroundAsset'] = backgroundAsset.identity?.toPayload();
    if (avatarAsset.managed) payload['avatar'] = null;
    if (backgroundAsset.managed) payload['background'] = null;
    return payload;
  }

  Future<_ConfigAssetExport> _exportConfigAsset(
    E2eeConfigAssetKey key,
    String? value, {
    required bool managed,
    required String context,
  }) async {
    if (!managed) return const _ConfigAssetExport.unmanaged();
    if (!_isLocalPath(value)) {
      throw StateError('E2EE $context 缺少有效本机路径');
    }
    final record = await _assetCommands!.read(key);
    if (record == null ||
        !p.equals(p.normalize(value!.trim()), p.normalize(record.asset.path))) {
      throw StateError('E2EE $context 缺少匹配的受管引用');
    }
    return _ConfigAssetExport.managed(record.remoteIdentity);
  }

  Map<String, Object?>? _exportMemory(String id) {
    final memory = _memories.memories
        .where((candidate) => candidate.syncId == id)
        .firstOrNull;
    return memory == null ? null : _jsonObject(memory.toJson());
  }

  Map<String, Object?>? _exportWorldBook(String id) {
    final index = _worldBooks.books.indexWhere((book) => book.id == id);
    if (index < 0) return null;
    return _jsonObject(_worldBooks.books[index].toJson())
      ..['_position'] = index;
  }

  Map<String, Object?>? _exportQuickPhrase(String id) {
    final index = _quickPhrases.phrases.indexWhere((phrase) => phrase.id == id);
    if (index < 0) return null;
    return _jsonObject(_quickPhrases.phrases[index].toJson())
      ..['_position'] = index;
  }

  Map<String, Object?>? _exportSearchService(String id) {
    final index = _settings.searchServices.indexWhere(
      (service) => service.id == id,
    );
    if (index < 0) return null;
    return _jsonObject(_settings.searchServices[index].toJson())
      ..['_position'] = index;
  }

  Map<String, Object?>? _exportTtsService(String id) {
    final index = _settings.ttsServices.indexWhere(
      (service) => service.id == id,
    );
    if (index < 0) return null;
    return _jsonObject(_settings.ttsServices[index].toJson())
      ..['_position'] = index;
  }

  Map<String, Object?>? _exportMcpServer(String id) {
    final syncable = _mcp.servers.where(_isPortableMcp).toList(growable: false);
    final index = syncable.indexWhere((server) => server.id == id);
    if (index < 0) return null;
    return _jsonObject(syncable[index].toJson())..['_position'] = index;
  }

  Map<String, Object?>? _exportInjection(String id) {
    final index = _injections.items.indexWhere((item) => item.id == id);
    if (index < 0) return null;
    return _jsonObject(_injections.items[index].toJson())
      ..['_position'] = index;
  }

  Future<Map<String, Object?>> _exportPreference(SyncEntityKey key) async {
    return switch (key) {
      ConfigSyncKeys.profile => await _exportProfile(),
      ConfigSyncKeys.providerGrouping => <String, Object?>{
        'order': List<String>.of(_settings.providersOrder),
        'groups': <Object?>[
          for (final group in _settings.providerGroups)
            _jsonObject(group.toJson()),
        ],
        'assignments': Map<String, Object?>.from(
          _settings.providerGroupAssignments,
        ),
        'ungroupedPosition': _settings.providerUngroupedDisplayIndex,
      },
      ConfigSyncKeys.assistantSelection => <String, Object?>{
        'assistantId': _assistants.currentAssistantId,
      },
      ConfigSyncKeys.worldBookActivity => <String, Object?>{
        'activeIdsByAssistant': _stringListMap(
          _worldBooks.activeIdsByAssistant,
        ),
      },
      ConfigSyncKeys.instructionActivity => <String, Object?>{
        'activeIdsByAssistant': _stringListMap(
          _injections.activeIdsByAssistant,
        ),
      },
      ConfigSyncKeys.searchState => <String, Object?>{
        'selectedServiceId': _selectedSearchServiceId,
        'commonOptions': _jsonObject(_settings.searchCommonOptions.toJson()),
        'enabled': _settings.searchEnabled,
        'autoTestOnLaunch': _settings.searchAutoTestOnLaunch,
      },
      ConfigSyncKeys.ttsState => <String, Object?>{
        'selectedServiceId': _settings.selectedTtsService?.id,
        'autoPlayAssistantReplies': _settings.ttsAutoPlayAssistantReplies,
        'textSelectionMode': _settings.ttsTextSelectionMode.storageValue,
      },
      ConfigSyncKeys.mcpState => <String, Object?>{
        'requestTimeoutSeconds': _mcp.requestTimeoutSeconds,
      },
      ConfigSyncKeys.generationSettings => _generationSettingsPayload(
        _settings.generationSettingsSnapshot,
      ),
      _ => throw StateError('sync_config_preference_id_unreachable'),
    };
  }

  Future<Map<String, Object?>> _exportProfile() async {
    final avatarAsset = await _exportConfigAsset(
      E2eeConfigAssetKey(
        entityKey: ConfigSyncKeys.profile,
        slot: E2eeConfigAssetSlot.avatar,
      ),
      _user.avatarValue,
      managed: _user.avatarType == 'file',
      context: '用户头像',
    );
    return <String, Object?>{
      'name': _user.name,
      'avatarType': avatarAsset.managed ? null : _user.avatarType,
      'avatarValue': avatarAsset.managed ? null : _user.avatarValue,
      'avatarAsset': avatarAsset.identity?.toPayload(),
    };
  }

  String? get _selectedSearchServiceId {
    final selected = _settings.searchServiceSelected;
    return selected >= 0 && selected < _settings.searchServices.length
        ? _settings.searchServices[selected].id
        : null;
  }

  Future<void> _applyValue(
    SyncEntityKey key,
    Map<String, Object?> payload,
  ) async {
    E2eeConfigSyncPayloadSchema.validate(key, payload);
    switch (key.entityType) {
      case ConfigSyncKeys.providerType:
        await _applyProvider(key.entityId, payload);
      case ConfigSyncKeys.assistantType:
        await _applyAssistant(key.entityId, payload);
      case ConfigSyncKeys.memoryType:
        await _memories.syncUpsert(
          AssistantMemory.fromJson(_dynamicObject(payload)),
        );
      case ConfigSyncKeys.worldBookType:
        await _worldBooks.syncUpsert(
          WorldBook.fromJson(_dynamicObject(payload)),
          position: payload['_position']! as int,
        );
      case ConfigSyncKeys.quickPhraseType:
        await _quickPhrases.syncUpsert(
          QuickPhrase.fromJson(_dynamicObject(payload)),
          position: payload['_position']! as int,
        );
      case ConfigSyncKeys.searchServiceType:
        await _settings.syncUpsertSearchService(
          SearchServiceOptions.fromJson(_dynamicObject(payload)),
          position: payload['_position']! as int,
        );
      case ConfigSyncKeys.networkTtsType:
        await _settings.syncUpsertTtsService(
          TtsServiceOptions.fromJson(_dynamicObject(payload)),
          position: payload['_position']! as int,
        );
      case ConfigSyncKeys.mcpServerType:
        await _mcp.syncUpsertServer(
          McpServerConfig.fromJson(_dynamicObject(payload)),
          position: payload['_position']! as int,
        );
      case ConfigSyncKeys.instructionInjectionType:
        await _injections.syncUpsert(
          InstructionInjection.fromJson(_dynamicObject(payload)),
          position: payload['_position']! as int,
        );
      case ConfigSyncKeys.preferenceType:
        await _applyPreference(key, payload);
      default:
        throw StateError('sync_config_entity_type_unreachable');
    }
  }

  Future<void> _applyProvider(String id, Map<String, Object?> payload) async {
    final decodedPayload = Map<String, Object?>.from(payload)
      ..remove('avatarAsset');
    var config = ProviderConfig.fromJson(_dynamicObject(decodedPayload));
    final avatar = await _resolveConfigAsset(
      E2eeConfigAssetKey(
        entityKey: ConfigSyncKeys.provider(id),
        slot: E2eeConfigAssetSlot.avatar,
      ),
      payload['avatarAsset'],
      config.avatarValue,
      context: '供应商头像',
    );
    if (avatar.managed) {
      config = config.copyWith(avatarType: 'file', avatarValue: avatar.value);
    }
    await _settings.syncUpsertProviderConfig(
      id,
      config,
      position: payload['_position']! as int,
    );
  }

  Future<void> _applyAssistant(String id, Map<String, Object?> payload) async {
    final entityKey = ConfigSyncKeys.assistant(id);
    final decodedPayload = Map<String, Object?>.from(payload)
      ..remove('avatarAsset')
      ..remove('backgroundAsset');
    final decoded = Assistant.fromJson(_dynamicObject(decodedPayload));
    final avatar = await _resolveConfigAsset(
      E2eeConfigAssetKey(
        entityKey: entityKey,
        slot: E2eeConfigAssetSlot.avatar,
      ),
      payload['avatarAsset'],
      decoded.avatar,
      context: '助手头像',
    );
    final background = await _resolveConfigAsset(
      E2eeConfigAssetKey(
        entityKey: entityKey,
        slot: E2eeConfigAssetSlot.background,
      ),
      payload['backgroundAsset'],
      decoded.background,
      context: '助手背景',
    );
    final assistant = decoded.copyWith(
      avatar: avatar.value,
      background: background.value,
      clearAvatar: avatar.value == null,
      clearBackground: background.value == null,
    );
    await _assistants.syncUpsertAssistant(
      assistant,
      position: payload['_position']! as int,
    );
  }

  Future<_ConfigAssetResolution> _resolveConfigAsset(
    E2eeConfigAssetKey key,
    Object? payloadIdentity,
    String? portableValue, {
    required String context,
  }) async {
    final record = await _assetCommands!.read(key);
    if (payloadIdentity == null) {
      if (record == null) {
        return _ConfigAssetResolution.unmanaged(portableValue);
      }
      if (portableValue != null) {
        throw StateError('E2EE $context 与可移植值冲突');
      }
      return _ConfigAssetResolution.managed(record.asset.path);
    }
    final expected = E2eeConfigAssetRemoteIdentity.fromPayload(
      payloadIdentity,
      expectedKind: E2eeAttachmentKind.image,
    );
    final actual = record?.remoteIdentity;
    if (record == null ||
        actual == null ||
        !_sameAssetIdentity(actual, expected)) {
      throw StateError('E2EE $context 与本地受管引用不一致');
    }
    if (portableValue != null) {
      throw StateError('E2EE $context 与可移植值冲突');
    }
    return _ConfigAssetResolution.managed(record.asset.path);
  }

  Future<void> _applyPreference(
    SyncEntityKey key,
    Map<String, Object?> payload,
  ) async {
    switch (key) {
      case ConfigSyncKeys.profile:
        final avatarType = payload['avatarType'] as String?;
        final avatarValue = payload['avatarValue'] as String?;
        final avatar = await _resolveConfigAsset(
          E2eeConfigAssetKey(
            entityKey: ConfigSyncKeys.profile,
            slot: E2eeConfigAssetSlot.avatar,
          ),
          payload['avatarAsset'],
          avatarValue,
          context: '用户头像',
        );
        await _user.syncApplyProfile(
          name: payload['name']! as String,
          replaceAvatar: true,
          avatarType: avatar.managed ? 'file' : avatarType,
          avatarValue: avatar.value,
        );
      case ConfigSyncKeys.providerGrouping:
        await _settings.syncApplyProviderGrouping(
          order: (payload['order']! as List<Object?>).cast<String>(),
          groups: <ProviderGroup>[
            for (final value in payload['groups']! as List<Object?>)
              ProviderGroup.fromJson(_dynamicObject(value)),
          ],
          assignments: (payload['assignments']! as Map<String, Object?>).map(
            (entryKey, value) => MapEntry(entryKey, value! as String),
          ),
          ungroupedPosition: payload['ungroupedPosition']! as int,
        );
      case ConfigSyncKeys.assistantSelection:
        await _assistants.syncSetCurrentAssistant(
          payload['assistantId'] as String?,
        );
      case ConfigSyncKeys.worldBookActivity:
        await _worldBooks.syncReplaceActiveIds(
          _activeIds(payload['activeIdsByAssistant']),
        );
      case ConfigSyncKeys.instructionActivity:
        await _injections.syncReplaceActiveIds(
          _activeIds(payload['activeIdsByAssistant']),
        );
      case ConfigSyncKeys.searchState:
        await _settings.syncApplySearchState(
          selectedServiceId: payload['selectedServiceId'] as String?,
          commonOptions: SearchCommonOptions.fromJson(
            _dynamicObject(payload['commonOptions']),
          ),
          enabled: payload['enabled']! as bool,
          autoTestOnLaunch: payload['autoTestOnLaunch']! as bool,
        );
      case ConfigSyncKeys.ttsState:
        await _settings.syncApplyTtsState(
          selectedServiceId: payload['selectedServiceId'] as String?,
          autoPlayAssistantReplies:
              payload['autoPlayAssistantReplies']! as bool,
          textSelectionMode: TtsTextSelectionModeStorage.fromStorageValue(
            payload['textSelectionMode']! as String,
          ),
        );
      case ConfigSyncKeys.mcpState:
        await _mcp.syncUpdateRequestTimeout(
          Duration(seconds: payload['requestTimeoutSeconds']! as int),
        );
      case ConfigSyncKeys.generationSettings:
        await _settings.syncApplyGenerationSettings(
          _generationSettingsSnapshot(payload),
        );
      default:
        throw StateError('sync_config_preference_id_unreachable');
    }
  }

  Future<void> _applyDelete(SyncEntityKey key) async {
    ConfigSyncKeys.validate(key);
    switch (key.entityType) {
      case ConfigSyncKeys.providerType:
        await _settings.syncDeleteProviderConfig(key.entityId);
      case ConfigSyncKeys.assistantType:
        await _assistants.syncDeleteAssistant(key.entityId);
      case ConfigSyncKeys.memoryType:
        await _memories.syncDelete(key.entityId);
      case ConfigSyncKeys.worldBookType:
        await _worldBooks.syncDelete(key.entityId);
      case ConfigSyncKeys.quickPhraseType:
        await _quickPhrases.syncDelete(key.entityId);
      case ConfigSyncKeys.searchServiceType:
        await _settings.syncDeleteSearchService(key.entityId);
      case ConfigSyncKeys.networkTtsType:
        await _settings.syncDeleteTtsService(key.entityId);
      case ConfigSyncKeys.mcpServerType:
        await _mcp.syncDeleteServer(key.entityId);
      case ConfigSyncKeys.instructionInjectionType:
        await _injections.syncDelete(key.entityId);
      case ConfigSyncKeys.preferenceType:
        await _applyPreferenceDelete(key);
      default:
        throw StateError('sync_config_entity_type_unreachable');
    }
  }

  Future<void> _applyPreferenceDelete(SyncEntityKey key) async {
    switch (key) {
      case ConfigSyncKeys.profile:
        await _user.syncApplyProfile(name: 'User', replaceAvatar: true);
      case ConfigSyncKeys.providerGrouping:
        await _settings.syncApplyProviderGrouping(
          order: const <String>[],
          groups: const <ProviderGroup>[],
          assignments: const <String, String>{},
          ungroupedPosition: 0,
        );
      case ConfigSyncKeys.assistantSelection:
        await _assistants.syncSetCurrentAssistant(null);
      case ConfigSyncKeys.worldBookActivity:
        await _worldBooks.syncReplaceActiveIds(const <String, List<String>>{});
      case ConfigSyncKeys.instructionActivity:
        await _injections.syncReplaceActiveIds(const <String, List<String>>{});
      case ConfigSyncKeys.searchState:
        await _settings.syncApplySearchState(
          selectedServiceId: null,
          commonOptions: const SearchCommonOptions(),
          enabled: false,
          autoTestOnLaunch: false,
        );
      case ConfigSyncKeys.ttsState:
        await _settings.syncApplyTtsState(
          selectedServiceId: null,
          autoPlayAssistantReplies: false,
          textSelectionMode: TtsTextSelectionMode.fullText,
        );
      case ConfigSyncKeys.mcpState:
        await _mcp.syncUpdateRequestTimeout(const Duration(seconds: 30));
      case ConfigSyncKeys.generationSettings:
        await _settings.syncApplyGenerationSettings(
          SettingsProvider.defaultGenerationSettingsSnapshot,
        );
      default:
        throw StateError('sync_config_preference_id_unreachable');
    }
  }

  void _requireReady() {
    if (!_initialized ||
        _failed ||
        _commands == null ||
        _assetCommands == null ||
        _adapter == null) {
      throw StateError('E2EE 配置 Provider 桥接尚未就绪');
    }
  }
}

final class _ConfigAssetExport {
  const _ConfigAssetExport.unmanaged() : managed = false, identity = null;

  const _ConfigAssetExport.managed(this.identity) : managed = true;

  final bool managed;
  final E2eeConfigAssetRemoteIdentity? identity;
}

final class _ConfigAssetResolution {
  const _ConfigAssetResolution.unmanaged(this.value) : managed = false;

  const _ConfigAssetResolution.managed(this.value) : managed = true;

  final bool managed;
  final String? value;
}

bool _sameAssetIdentity(
  E2eeConfigAssetRemoteIdentity left,
  E2eeConfigAssetRemoteIdentity right,
) =>
    left.attachmentId == right.attachmentId &&
    left.uploadId == right.uploadId &&
    left.chunkKeyEpoch == right.chunkKeyEpoch &&
    left.manifestKeyEpoch == right.manifestKeyEpoch &&
    left.manifestRevision == right.manifestRevision &&
    left.kind == right.kind;

Map<String, Object?> _generationSettingsPayload(
  GenerationSettingsSnapshot snapshot,
) => <String, Object?>{
  'currentModel': _generationModelSelectionPayload(snapshot.currentModel),
  'titleModel': _generationModelSelectionPayload(snapshot.titleModel),
  'titlePrompt': snapshot.titlePrompt,
  'translateModel': _generationModelSelectionPayload(snapshot.translateModel),
  'translatePrompt': snapshot.translatePrompt,
  'ocrModel': _generationModelSelectionPayload(snapshot.ocrModel),
  'ocrPrompt': snapshot.ocrPrompt,
  'summaryModel': _generationModelSelectionPayload(snapshot.summaryModel),
  'summaryPrompt': snapshot.summaryPrompt,
  'suggestionModel': _generationModelSelectionPayload(snapshot.suggestionModel),
  'suggestionPrompt': snapshot.suggestionPrompt,
  'compressModel': _generationModelSelectionPayload(snapshot.compressModel),
  'compressPrompt': snapshot.compressPrompt,
  'learningModePrompt': snapshot.learningModePrompt,
};

Map<String, Object?>? _generationModelSelectionPayload(
  GenerationModelSelection? selection,
) => selection == null
    ? null
    : <String, Object?>{
        'providerId': selection.providerId,
        'modelId': selection.modelId,
      };

GenerationSettingsSnapshot _generationSettingsSnapshot(
  Map<String, Object?> payload,
) => GenerationSettingsSnapshot(
  currentModel: _generationModelSelection(payload['currentModel']),
  titleModel: _generationModelSelection(payload['titleModel']),
  titlePrompt: payload['titlePrompt']! as String,
  translateModel: _generationModelSelection(payload['translateModel']),
  translatePrompt: payload['translatePrompt']! as String,
  ocrModel: _generationModelSelection(payload['ocrModel']),
  ocrPrompt: payload['ocrPrompt']! as String,
  summaryModel: _generationModelSelection(payload['summaryModel']),
  summaryPrompt: payload['summaryPrompt']! as String,
  suggestionModel: _generationModelSelection(payload['suggestionModel']),
  suggestionPrompt: payload['suggestionPrompt']! as String,
  compressModel: _generationModelSelection(payload['compressModel']),
  compressPrompt: payload['compressPrompt']! as String,
  learningModePrompt: payload['learningModePrompt']! as String,
);

GenerationModelSelection? _generationModelSelection(Object? value) {
  if (value == null) return null;
  final object = value as Map<String, Object?>;
  return GenerationModelSelection(
    providerId: object['providerId']! as String,
    modelId: object['modelId']! as String,
  );
}

final class _ConfigProviderOperationLock {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) {
    final previous = _tail;
    final completed = Completer<void>();
    _tail = completed.future;
    return () async {
      await previous;
      try {
        return await action();
      } finally {
        completed.complete();
      }
    }();
  }
}

List<SyncEntityKey> _normalizeConfigKeys(Iterable<SyncEntityKey> keys) {
  final normalized = <SyncEntityKey>{};
  for (final key in keys) {
    ConfigSyncKeys.validate(key);
    normalized.add(key);
  }
  return normalized.toList(growable: false)..sort(_compareConfigKeys);
}

int _compareVaultEntries(
  E2eeConfigVaultEntry left,
  E2eeConfigVaultEntry right,
) => _compareConfigKeys(left.key, right.key);

int _compareConfigKeys(SyncEntityKey left, SyncEntityKey right) {
  var compared = _dependencyRank(
    left.entityType,
  ).compareTo(_dependencyRank(right.entityType));
  if (compared != 0) return compared;
  compared = left.entityType.compareTo(right.entityType);
  return compared != 0 ? compared : left.entityId.compareTo(right.entityId);
}

int _compareConfigChanges(
  E2eeSyncPulledChange left,
  E2eeSyncPulledChange right,
) {
  final leftTombstone = left is E2eeSyncPulledTombstoneChange;
  final rightTombstone = right is E2eeSyncPulledTombstoneChange;
  var compared = leftTombstone == rightTombstone ? 0 : (leftTombstone ? 1 : -1);
  if (compared != 0) return compared;
  final leftRank = _dependencyRank(left.state.entityKey.entityType);
  final rightRank = _dependencyRank(right.state.entityKey.entityType);
  compared = leftTombstone
      ? rightRank.compareTo(leftRank)
      : leftRank.compareTo(rightRank);
  if (compared != 0) return compared;
  compared = left.untrustedServerMetadata.changeSeq.compareTo(
    right.untrustedServerMetadata.changeSeq,
  );
  return compared != 0
      ? compared
      : _compareConfigKeys(left.state.entityKey, right.state.entityKey);
}

int _dependencyRank(String entityType) => switch (entityType) {
  ConfigSyncKeys.providerType ||
  ConfigSyncKeys.searchServiceType ||
  ConfigSyncKeys.networkTtsType ||
  ConfigSyncKeys.mcpServerType => 0,
  ConfigSyncKeys.assistantType ||
  ConfigSyncKeys.worldBookType ||
  ConfigSyncKeys.instructionInjectionType => 1,
  ConfigSyncKeys.memoryType || ConfigSyncKeys.quickPhraseType => 2,
  ConfigSyncKeys.preferenceType => 3,
  _ => throw StateError('sync_config_entity_type_unreachable'),
};

Map<String, Object?> _jsonObject(Map<String, dynamic> value) =>
    Map<String, Object?>.from(value);

Map<String, dynamic> _dynamicObject(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('E2EE 配置对象形状无效');
  }
  return Map<String, dynamic>.from(value);
}

Map<String, Object?> _stringListMap(Map<String, List<String>> values) =>
    <String, Object?>{
      for (final entry in values.entries) entry.key: <Object?>[...entry.value],
    };

Map<String, List<String>> _activeIds(Object? value) {
  final object = value as Map<String, Object?>;
  return <String, List<String>>{
    for (final entry in object.entries)
      entry.key: (entry.value! as List<Object?>).cast<String>(),
  };
}

bool _isPortableMcp(McpServerConfig server) =>
    server.transport == McpTransportType.http ||
    server.transport == McpTransportType.sse;

bool _isLocalPath(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty ||
      normalized.startsWith('http://') ||
      normalized.startsWith('https://') ||
      normalized.startsWith('data:')) {
    return false;
  }
  return normalized.startsWith('/') ||
      normalized.startsWith(r'\\') ||
      RegExp(r'^[A-Za-z]:[\\/]').hasMatch(normalized);
}

DateTime _defaultUtcNow() => DateTime.now().toUtc();
