import 'sync_codec.dart';

abstract final class ConfigSyncKeys {
  static const String providerType = 'provider';
  static const String assistantType = 'assistant';
  static const String memoryType = 'memory';
  static const String worldBookType = 'world-book';
  static const String quickPhraseType = 'quick-phrase';
  static const String searchServiceType = 'search-service';
  static const String networkTtsType = 'network-tts';
  static const String mcpServerType = 'mcp-server';
  static const String instructionInjectionType = 'instruction-injection';
  static const String preferenceType = 'user-preference';

  static const SyncEntityKey profile = SyncEntityKey(
    entityType: preferenceType,
    entityId: 'profile:default',
  );
  static const SyncEntityKey providerGrouping = SyncEntityKey(
    entityType: preferenceType,
    entityId: 'provider-grouping:default',
  );
  static const SyncEntityKey assistantSelection = SyncEntityKey(
    entityType: preferenceType,
    entityId: 'assistant-selection:default',
  );
  static const SyncEntityKey worldBookActivity = SyncEntityKey(
    entityType: preferenceType,
    entityId: 'world-book-activity:default',
  );
  static const SyncEntityKey instructionActivity = SyncEntityKey(
    entityType: preferenceType,
    entityId: 'instruction-activity:default',
  );
  static const SyncEntityKey searchState = SyncEntityKey(
    entityType: preferenceType,
    entityId: 'search-state:default',
  );
  static const SyncEntityKey ttsState = SyncEntityKey(
    entityType: preferenceType,
    entityId: 'tts-state:default',
  );
  static const SyncEntityKey mcpState = SyncEntityKey(
    entityType: preferenceType,
    entityId: 'mcp-state:default',
  );

  static SyncEntityKey provider(String id) => _entity(providerType, id);
  static SyncEntityKey assistant(String id) => _entity(assistantType, id);
  static SyncEntityKey memory(String id) => _entity(memoryType, id);
  static SyncEntityKey worldBook(String id) => _entity(worldBookType, id);
  static SyncEntityKey quickPhrase(String id) => _entity(quickPhraseType, id);
  static SyncEntityKey searchService(String id) =>
      _entity(searchServiceType, id);
  static SyncEntityKey networkTts(String id) => _entity(networkTtsType, id);
  static SyncEntityKey mcpServer(String id) => _entity(mcpServerType, id);
  static SyncEntityKey instructionInjection(String id) =>
      _entity(instructionInjectionType, id);

  static SyncEntityKey _entity(String type, String id) =>
      SyncEntityKey(entityType: type, entityId: id);
}
