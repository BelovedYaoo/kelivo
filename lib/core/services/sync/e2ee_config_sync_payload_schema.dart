import 'config_sync_keys.dart';
import 'sync_codec.dart';

const _maximumPositiveInt63 = 0x7fffffffffffffff;

abstract final class E2eeConfigSyncPayloadSchema {
  static void validate(SyncEntityKey entityKey, Map<String, Object?> payload) {
    ConfigSyncKeys.validate(entityKey);
    switch (entityKey.entityType) {
      case ConfigSyncKeys.providerType:
        _validateProvider(entityKey, payload);
      case ConfigSyncKeys.assistantType:
        _validateAssistant(entityKey, payload);
      case ConfigSyncKeys.memoryType:
        _validateMemory(entityKey, payload);
      case ConfigSyncKeys.worldBookType:
        _validateWorldBook(entityKey, payload);
      case ConfigSyncKeys.quickPhraseType:
        _validateQuickPhrase(entityKey, payload);
      case ConfigSyncKeys.searchServiceType:
        _validateSearchService(entityKey, payload);
      case ConfigSyncKeys.networkTtsType:
        _validateNetworkTts(entityKey, payload);
      case ConfigSyncKeys.mcpServerType:
        _validateMcpServer(entityKey, payload);
      case ConfigSyncKeys.instructionInjectionType:
        _validateInstructionInjection(entityKey, payload);
      case ConfigSyncKeys.preferenceType:
        _validatePreference(entityKey, payload);
      default:
        throw StateError('sync_config_entity_type_unreachable');
    }
  }
}

const _providerKeys = <String>{
  'id',
  'enabled',
  'name',
  'apiKey',
  'baseUrl',
  'providerType',
  'chatPath',
  'useResponseApi',
  'vertexAI',
  'location',
  'projectId',
  'serviceAccountJson',
  'models',
  'modelOverrides',
  'proxyEnabled',
  'proxyType',
  'proxyHost',
  'proxyPort',
  'proxyUsername',
  'proxyPassword',
  'avatarType',
  'avatarValue',
  'multiKeyEnabled',
  'apiKeys',
  'keyManagement',
  'aihubmixAppCodeEnabled',
  'balanceEnabled',
  'balanceApiPath',
  'balanceResultPath',
  'claudePromptCachingEnabled',
  'claudePromptCachingTtl',
  '_position',
};
const _apiKeyKeys = <String>{
  'id',
  'key',
  'name',
  'isEnabled',
  'priority',
  'maxRequestsPerMinute',
  'usage',
  'status',
  'lastError',
  'createdAt',
  'updatedAt',
};
const _apiKeyUsageKeys = <String>{
  'totalRequests',
  'successfulRequests',
  'failedRequests',
  'consecutiveFailures',
  'lastUsed',
};
const _keyManagementKeys = <String>{
  'strategy',
  'maxFailuresBeforeDisable',
  'failureRecoveryTimeMinutes',
  'enableAutoRecovery',
  'roundRobinIndex',
};

void _validateProvider(SyncEntityKey entityKey, Map<String, Object?> payload) {
  _expectExactKeys(payload, _providerKeys, 'provider');
  _requireMatchingIdentity(payload, 'id', entityKey);
  _requiredBoolean(payload, 'enabled');
  _requiredString(payload, 'name', allowEmpty: true);
  _requiredString(payload, 'apiKey', allowEmpty: true);
  _requiredString(payload, 'baseUrl', allowEmpty: true);
  _nullableEnumString(payload, 'providerType', const <String>{
    'openai',
    'google',
    'claude',
  });
  _nullableString(payload, 'chatPath');
  _nullableBoolean(payload, 'useResponseApi');
  _nullableBoolean(payload, 'vertexAI');
  _nullableString(payload, 'location');
  _nullableString(payload, 'projectId');
  _nullableString(payload, 'serviceAccountJson');
  _requiredIdentifierList(payload, 'models');
  _requiredObject(payload, 'modelOverrides');
  _nullableBoolean(payload, 'proxyEnabled');
  _nullableEnumString(payload, 'proxyType', const <String>{
    'http',
    'https',
    'socks5',
  });
  _nullableString(payload, 'proxyHost');
  _nullableString(payload, 'proxyPort');
  _nullableString(payload, 'proxyUsername');
  _nullableString(payload, 'proxyPassword');
  _nullableEnumString(payload, 'avatarType', const <String>{
    'emoji',
    'url',
    'file',
    'icon',
    'lobehub',
  });
  _nullableString(payload, 'avatarValue');
  _nullableBoolean(payload, 'multiKeyEnabled');
  _validateApiKeys(_requiredValue(payload, 'apiKeys'));
  _validateKeyManagement(_requiredValue(payload, 'keyManagement'));
  _nullableBoolean(payload, 'aihubmixAppCodeEnabled');
  _nullableBoolean(payload, 'balanceEnabled');
  _nullableString(payload, 'balanceApiPath');
  _nullableString(payload, 'balanceResultPath');
  _requiredBoolean(payload, 'claudePromptCachingEnabled');
  _requiredEnumString(payload, 'claudePromptCachingTtl', const <String>{
    '5m',
    '1h',
  });
  _requiredPosition(payload);
}

void _validateApiKeys(Object? value) {
  if (value == null) return;
  if (value is! List<Object?>) {
    throw const FormatException('provider.apiKeys 必须是数组或 null');
  }
  final ids = <String>{};
  for (var index = 0; index < value.length; index++) {
    final item = _expectObject(value[index], 'provider.apiKeys[$index]');
    _expectExactKeys(item, _apiKeyKeys, 'provider.apiKeys[$index]');
    final id = _requiredIdentifier(item, 'id');
    if (!ids.add(id)) {
      throw FormatException('provider.apiKeys[$index].id 重复');
    }
    _requiredString(item, 'key', allowEmpty: true);
    _nullableString(item, 'name');
    _requiredBoolean(item, 'isEnabled');
    final priority = _requiredPositiveInteger(item, 'priority');
    if (priority > 10) {
      throw FormatException('provider.apiKeys[$index].priority 超出范围');
    }
    _nullablePositiveInteger(item, 'maxRequestsPerMinute');
    _validateApiKeyUsage(_requiredObject(item, 'usage'), index);
    _requiredEnumString(item, 'status', const <String>{
      'active',
      'disabled',
      'error',
      'rateLimited',
    });
    _nullableString(item, 'lastError');
    final createdAt = _requiredNonNegativeInteger(item, 'createdAt');
    final updatedAt = _requiredNonNegativeInteger(item, 'updatedAt');
    if (updatedAt < createdAt) {
      throw FormatException(
        'provider.apiKeys[$index].updatedAt 不能早于 createdAt',
      );
    }
  }
}

void _validateApiKeyUsage(Map<String, Object?> usage, int index) {
  _expectExactKeys(usage, _apiKeyUsageKeys, 'provider.apiKeys[$index].usage');
  final total = _requiredNonNegativeInteger(usage, 'totalRequests');
  final successful = _requiredNonNegativeInteger(usage, 'successfulRequests');
  final failed = _requiredNonNegativeInteger(usage, 'failedRequests');
  final consecutive = _requiredNonNegativeInteger(usage, 'consecutiveFailures');
  if (successful + failed > total || consecutive > failed) {
    throw FormatException('provider.apiKeys[$index].usage 计数关系无效');
  }
  _nullableNonNegativeInteger(usage, 'lastUsed');
}

void _validateKeyManagement(Object? value) {
  if (value == null) return;
  final config = _expectObject(value, 'provider.keyManagement');
  _expectExactKeys(config, _keyManagementKeys, 'provider.keyManagement');
  _requiredEnumString(config, 'strategy', const <String>{
    'roundRobin',
    'priority',
    'leastUsed',
    'random',
  });
  _requiredPositiveInteger(config, 'maxFailuresBeforeDisable');
  _requiredNonNegativeInteger(config, 'failureRecoveryTimeMinutes');
  _requiredBoolean(config, 'enableAutoRecovery');
  _nullableNonNegativeInteger(config, 'roundRobinIndex');
}

const _assistantKeys = <String>{
  'id',
  'name',
  'avatar',
  'useAssistantAvatar',
  'useAssistantName',
  'chatModelProvider',
  'chatModelId',
  'temperature',
  'topP',
  'contextMessageSize',
  'limitContextMessages',
  'streamOutput',
  'thinkingBudget',
  'maxTokens',
  'systemPrompt',
  'messageTemplate',
  'searchEnabled',
  'mcpServerIds',
  'localToolIds',
  'background',
  'customHeaders',
  'customBody',
  'enableMemory',
  'enableRecentChatsReference',
  'recentChatsSummaryMessageCount',
  'presetMessages',
  'regexRules',
  '_position',
};
const _presetMessageKeys = <String>{'id', 'role', 'content'};
const _regexRuleKeys = <String>{
  'id',
  'name',
  'pattern',
  'replacement',
  'scopes',
  'visualOnly',
  'replaceOnly',
  'enabled',
};

void _validateAssistant(SyncEntityKey entityKey, Map<String, Object?> payload) {
  _expectExactKeys(payload, _assistantKeys, 'assistant');
  _requireMatchingIdentity(payload, 'id', entityKey);
  _requiredString(payload, 'name', allowEmpty: true);
  _nullableString(payload, 'avatar');
  _requiredBoolean(payload, 'useAssistantAvatar');
  _requiredBoolean(payload, 'useAssistantName');
  _nullableIdentifier(payload, 'chatModelProvider');
  _nullableString(payload, 'chatModelId');
  _nullableDoubleInRange(payload, 'temperature', minimum: 0, maximum: 2);
  _nullableDoubleInRange(payload, 'topP', minimum: 0, maximum: 1);
  final contextSize = _requiredPositiveInteger(payload, 'contextMessageSize');
  if (contextSize > 1024) {
    throw const FormatException('assistant.contextMessageSize 超出范围');
  }
  _requiredBoolean(payload, 'limitContextMessages');
  _requiredBoolean(payload, 'streamOutput');
  _nullableNonNegativeInteger(payload, 'thinkingBudget');
  _nullablePositiveInteger(payload, 'maxTokens');
  _requiredString(payload, 'systemPrompt', allowEmpty: true);
  _requiredString(payload, 'messageTemplate', allowEmpty: true);
  _requiredBoolean(payload, 'searchEnabled');
  _requiredIdentifierList(payload, 'mcpServerIds');
  _requiredIdentifierList(payload, 'localToolIds');
  _nullableString(payload, 'background');
  _validateStringPairList(
    _requiredList(payload, 'customHeaders'),
    firstKey: 'name',
    context: 'assistant.customHeaders',
  );
  _validateStringPairList(
    _requiredList(payload, 'customBody'),
    firstKey: 'key',
    context: 'assistant.customBody',
  );
  _requiredBoolean(payload, 'enableMemory');
  _requiredBoolean(payload, 'enableRecentChatsReference');
  _requiredPositiveInteger(payload, 'recentChatsSummaryMessageCount');
  _validatePresetMessages(_requiredList(payload, 'presetMessages'));
  _validateRegexRules(_requiredList(payload, 'regexRules'));
  _requiredPosition(payload);
}

void _validateStringPairList(
  List<Object?> values, {
  required String firstKey,
  required String context,
}) {
  for (var index = 0; index < values.length; index++) {
    final item = _expectObject(values[index], '$context[$index]');
    _expectExactKeys(item, <String>{firstKey, 'value'}, '$context[$index]');
    _requiredString(item, firstKey);
    _requiredString(item, 'value', allowEmpty: true);
  }
}

void _validatePresetMessages(List<Object?> values) {
  final ids = <String>{};
  for (var index = 0; index < values.length; index++) {
    final item = _expectObject(
      values[index],
      'assistant.presetMessages[$index]',
    );
    _expectExactKeys(
      item,
      _presetMessageKeys,
      'assistant.presetMessages[$index]',
    );
    final id = _requiredIdentifier(item, 'id');
    if (!ids.add(id)) {
      throw FormatException('assistant.presetMessages[$index].id 重复');
    }
    _requiredEnumString(item, 'role', const <String>{'user', 'assistant'});
    _requiredString(item, 'content', allowEmpty: true);
  }
}

void _validateRegexRules(List<Object?> values) {
  final ids = <String>{};
  for (var index = 0; index < values.length; index++) {
    final item = _expectObject(values[index], 'assistant.regexRules[$index]');
    _expectExactKeys(item, _regexRuleKeys, 'assistant.regexRules[$index]');
    final id = _requiredIdentifier(item, 'id');
    if (!ids.add(id)) {
      throw FormatException('assistant.regexRules[$index].id 重复');
    }
    _requiredString(item, 'name', allowEmpty: true);
    _requiredString(item, 'pattern', allowEmpty: true);
    _requiredString(item, 'replacement', allowEmpty: true);
    _requiredEnumStringList(item, 'scopes', const <String>{
      'user',
      'assistant',
    });
    final visualOnly = _requiredBoolean(item, 'visualOnly');
    final replaceOnly = _requiredBoolean(item, 'replaceOnly');
    if (visualOnly && replaceOnly) {
      throw FormatException('assistant.regexRules[$index] 模式互斥');
    }
    _requiredBoolean(item, 'enabled');
  }
}

const _memoryKeys = <String>{'id', 'syncId', 'assistantId', 'content'};

void _validateMemory(SyncEntityKey entityKey, Map<String, Object?> payload) {
  _expectExactKeys(payload, _memoryKeys, 'memory');
  _requiredNonNegativeInteger(payload, 'id');
  _requireMatchingIdentity(payload, 'syncId', entityKey);
  _requiredIdentifier(payload, 'assistantId');
  _requiredString(payload, 'content', allowEmpty: true);
}

const _worldBookKeys = <String>{
  'id',
  'name',
  'description',
  'enabled',
  'entries',
  '_position',
};
const _worldBookEntryKeys = <String>{
  'id',
  'name',
  'enabled',
  'priority',
  'position',
  'content',
  'injectDepth',
  'role',
  'keywords',
  'useRegex',
  'caseSensitive',
  'scanDepth',
  'constantActive',
};

void _validateWorldBook(SyncEntityKey entityKey, Map<String, Object?> payload) {
  _expectExactKeys(payload, _worldBookKeys, 'world-book');
  _requireMatchingIdentity(payload, 'id', entityKey);
  _requiredString(payload, 'name', allowEmpty: true);
  _requiredString(payload, 'description', allowEmpty: true);
  _requiredBoolean(payload, 'enabled');
  final entries = _requiredList(payload, 'entries');
  final ids = <String>{};
  for (var index = 0; index < entries.length; index++) {
    final item = _expectObject(entries[index], 'world-book.entries[$index]');
    _expectExactKeys(item, _worldBookEntryKeys, 'world-book.entries[$index]');
    final id = _requiredIdentifier(item, 'id');
    if (!ids.add(id)) {
      throw FormatException('world-book.entries[$index].id 重复');
    }
    _requiredString(item, 'name', allowEmpty: true);
    _requiredBoolean(item, 'enabled');
    _requiredSignedInteger(item, 'priority');
    _requiredEnumString(item, 'position', const <String>{
      'BEFORE_SYSTEM_PROMPT',
      'AFTER_SYSTEM_PROMPT',
      'TOP_OF_CHAT',
      'BOTTOM_OF_CHAT',
      'AT_DEPTH',
    });
    _requiredString(item, 'content', allowEmpty: true);
    _requiredNonNegativeInteger(item, 'injectDepth');
    _requiredEnumString(item, 'role', const <String>{'USER', 'ASSISTANT'});
    _requiredTrimmedStringList(item, 'keywords');
    _requiredBoolean(item, 'useRegex');
    _requiredBoolean(item, 'caseSensitive');
    _requiredNonNegativeInteger(item, 'scanDepth');
    _requiredBoolean(item, 'constantActive');
  }
  _requiredPosition(payload);
}

const _quickPhraseKeys = <String>{
  'id',
  'title',
  'content',
  'isGlobal',
  'assistantId',
  '_position',
};

void _validateQuickPhrase(
  SyncEntityKey entityKey,
  Map<String, Object?> payload,
) {
  _expectExactKeys(payload, _quickPhraseKeys, 'quick-phrase');
  _requireMatchingIdentity(payload, 'id', entityKey);
  _requiredString(payload, 'title', allowEmpty: true);
  _requiredString(payload, 'content', allowEmpty: true);
  final isGlobal = _requiredBoolean(payload, 'isGlobal');
  final assistantId = _nullableIdentifier(payload, 'assistantId');
  if (isGlobal != (assistantId == null)) {
    throw const FormatException('quick-phrase 全局状态与 assistantId 不一致');
  }
  _requiredPosition(payload);
}

const _searchBaseKeys = <String>{'type', 'id', '_position'};

void _validateSearchService(
  SyncEntityKey entityKey,
  Map<String, Object?> payload,
) {
  _requireMatchingIdentity(payload, 'id', entityKey);
  final type = _requiredString(payload, 'type');
  final requiredKeys = switch (type) {
    'bing_local' => <String>{'acceptLanguage'},
    'tavily' || 'exa' => <String>{'apiKey', 'url'},
    'zhipu' ||
    'linkup' ||
    'brave' ||
    'metaso' ||
    'ollama' ||
    'jina' => <String>{'apiKey'},
    'searxng' => <String>{'url', 'engines', 'language', 'username', 'password'},
    'duckduckgo' => <String>{'region'},
    'perplexity' => <String>{'apiKey'},
    'bocha' => <String>{'apiKey', 'summary'},
    'serper' => <String>{'apiKey', 'gl', 'hl', 'tbs', 'page'},
    'grok' => <String>{'apiKey', 'model', 'customUrl', 'systemPrompt'},
    'querit' => <String>{
      'apiKey',
      'sitesInclude',
      'sitesExclude',
      'timeRange',
      'countries',
      'languages',
    },
    _ => throw const FormatException('search-service.type 无效'),
  };
  final optionalKeys = switch (type) {
    'perplexity' => <String>{
      'country',
      'searchDomainFilter',
      'maxTokensPerPage',
    },
    'bocha' => <String>{'freshness', 'include', 'exclude'},
    _ => const <String>{},
  };
  _expectKeys(
    payload,
    required: <String>{..._searchBaseKeys, ...requiredKeys},
    optional: optionalKeys,
    context: 'search-service',
  );
  for (final key in requiredKeys) {
    if (key == 'page') {
      _requiredPositiveInteger(payload, key);
    } else if (key == 'summary') {
      _requiredBoolean(payload, key);
    } else {
      _requiredString(payload, key, allowEmpty: key != 'type');
    }
  }
  if (payload.containsKey('country')) _requiredString(payload, 'country');
  if (payload.containsKey('searchDomainFilter')) {
    _requiredStringList(payload, 'searchDomainFilter');
  }
  if (payload.containsKey('maxTokensPerPage')) {
    _requiredPositiveInteger(payload, 'maxTokensPerPage');
  }
  for (final key in const <String>{'freshness', 'include', 'exclude'}) {
    if (payload.containsKey(key)) {
      _requiredString(payload, key, allowEmpty: true);
    }
  }
  _requiredPosition(payload);
}

const _ttsBaseKeys = <String>{
  'id',
  'enabled',
  'name',
  'kind',
  'apiKey',
  'baseUrl',
  '_position',
};

void _validateNetworkTts(
  SyncEntityKey entityKey,
  Map<String, Object?> payload,
) {
  _requireMatchingIdentity(payload, 'id', entityKey);
  final kind = _requiredString(payload, 'kind');
  final specificKeys = switch (kind) {
    'openai' || 'groq' || 'mimo' => <String>{'model', 'voice'},
    'gemini' => <String>{'model', 'voiceName'},
    'minimax' => <String>{'model', 'voiceId', 'emotion', 'speed'},
    'qwen' => <String>{'model', 'voice', 'languageType'},
    'xai' => <String>{'voiceId', 'language'},
    'elevenlabs' => <String>{'modelId', 'voiceId', 'outputFormat'},
    _ => throw const FormatException('network-tts.kind 无效'),
  };
  _expectExactKeys(payload, <String>{
    ..._ttsBaseKeys,
    ...specificKeys,
  }, 'network-tts');
  _requiredBoolean(payload, 'enabled');
  _requiredString(payload, 'name');
  _requiredString(payload, 'apiKey', allowEmpty: true);
  _requiredString(payload, 'baseUrl', allowEmpty: true);
  for (final key in specificKeys) {
    if (key == 'speed') {
      final speed = _requiredDouble(payload, key);
      if (speed <= 0) throw const FormatException('network-tts.speed 必须大于零');
    } else {
      _requiredString(payload, key, allowEmpty: true);
    }
  }
  _requiredPosition(payload);
}

const _mcpBaseKeys = <String>{
  'id',
  'enabled',
  'name',
  'transport',
  'tools',
  '_position',
};
const _mcpToolRequiredKeys = <String>{
  'enabled',
  'name',
  'description',
  'params',
};
const _mcpToolOptionalKeys = <String>{'schema', 'needsApproval'};
const _mcpParamKeys = <String>{'name', 'required', 'type', 'default'};

void _validateMcpServer(SyncEntityKey entityKey, Map<String, Object?> payload) {
  _requireMatchingIdentity(payload, 'id', entityKey);
  final transport = _requiredString(payload, 'transport');
  switch (transport) {
    case 'http':
    case 'sse':
      _expectExactKeys(payload, <String>{
        ..._mcpBaseKeys,
        'url',
        'headers',
      }, 'mcp-server');
      _requiredString(payload, 'url', allowEmpty: true);
      _validateStringMap(
        _requiredObject(payload, 'headers'),
        'mcp-server.headers',
      );
    case 'stdio':
      _expectKeys(
        payload,
        required: <String>{..._mcpBaseKeys, 'command', 'args', 'env'},
        optional: const <String>{'workingDirectory'},
        context: 'mcp-server',
      );
      _nullableString(payload, 'command');
      _requiredStringList(payload, 'args');
      _validateStringMap(_requiredObject(payload, 'env'), 'mcp-server.env');
      if (payload.containsKey('workingDirectory')) {
        _requiredString(payload, 'workingDirectory');
      }
    case 'inmemory':
      _expectExactKeys(payload, _mcpBaseKeys, 'mcp-server');
    default:
      throw const FormatException('mcp-server.transport 无效');
  }
  _requiredBoolean(payload, 'enabled');
  _requiredString(payload, 'name', allowEmpty: true);
  _validateMcpTools(_requiredList(payload, 'tools'));
  _requiredPosition(payload);
}

void _validateMcpTools(List<Object?> values) {
  final names = <String>{};
  for (var index = 0; index < values.length; index++) {
    final item = _expectObject(values[index], 'mcp-server.tools[$index]');
    _expectKeys(
      item,
      required: _mcpToolRequiredKeys,
      optional: _mcpToolOptionalKeys,
      context: 'mcp-server.tools[$index]',
    );
    _requiredBoolean(item, 'enabled');
    final name = _requiredString(item, 'name');
    if (!names.add(name)) {
      throw FormatException('mcp-server.tools[$index].name 重复');
    }
    _nullableString(item, 'description');
    final params = _requiredList(item, 'params');
    final paramNames = <String>{};
    for (var paramIndex = 0; paramIndex < params.length; paramIndex++) {
      final param = _expectObject(
        params[paramIndex],
        'mcp-server.tools[$index].params[$paramIndex]',
      );
      _expectExactKeys(
        param,
        _mcpParamKeys,
        'mcp-server.tools[$index].params[$paramIndex]',
      );
      final paramName = _requiredString(param, 'name');
      if (!paramNames.add(paramName)) {
        throw FormatException(
          'mcp-server.tools[$index].params[$paramIndex].name 重复',
        );
      }
      _requiredBoolean(param, 'required');
      _nullableString(param, 'type');
      _requiredValue(param, 'default');
    }
    if (item.containsKey('schema')) _requiredObject(item, 'schema');
    if (item.containsKey('needsApproval') &&
        !_requiredBoolean(item, 'needsApproval')) {
      throw FormatException('mcp-server.tools[$index].needsApproval 非规范');
    }
  }
}

void _validateStringMap(Map<String, Object?> values, String context) {
  for (final entry in values.entries) {
    if (entry.key.trim().isEmpty || entry.value is! String) {
      throw FormatException('$context 必须只包含非空字符串键值');
    }
  }
}

const _instructionKeys = <String>{
  'id',
  'title',
  'prompt',
  'group',
  '_position',
};

void _validateInstructionInjection(
  SyncEntityKey entityKey,
  Map<String, Object?> payload,
) {
  _expectExactKeys(payload, _instructionKeys, 'instruction-injection');
  _requireMatchingIdentity(payload, 'id', entityKey);
  _requiredString(payload, 'title', allowEmpty: true);
  _requiredString(payload, 'prompt', allowEmpty: true);
  _requiredString(payload, 'group', allowEmpty: true);
  _requiredPosition(payload);
}

void _validatePreference(
  SyncEntityKey entityKey,
  Map<String, Object?> payload,
) {
  switch (entityKey.entityId) {
    case 'profile:default':
      _validateProfilePreference(payload);
    case 'provider-grouping:default':
      _validateProviderGroupingPreference(payload);
    case 'assistant-selection:default':
      _expectExactKeys(payload, const <String>{
        'assistantId',
      }, 'assistant-selection');
      _nullableIdentifier(payload, 'assistantId');
    case 'world-book-activity:default':
    case 'instruction-activity:default':
      _expectExactKeys(payload, const <String>{
        'activeIdsByAssistant',
      }, 'config-activity');
      _validateActiveIdsByAssistant(
        _requiredObject(payload, 'activeIdsByAssistant'),
      );
    case 'search-state:default':
      _validateSearchStatePreference(payload);
    case 'tts-state:default':
      _validateTtsStatePreference(payload);
    case 'mcp-state:default':
      _expectExactKeys(payload, const <String>{
        'requestTimeoutSeconds',
      }, 'mcp-state');
      _requiredPositiveInteger(payload, 'requestTimeoutSeconds');
    default:
      throw StateError('sync_config_preference_id_unreachable');
  }
}

void _validateProfilePreference(Map<String, Object?> payload) {
  _expectExactKeys(payload, const <String>{
    'name',
    'avatarType',
    'avatarValue',
  }, 'profile');
  _requiredString(payload, 'name');
  final avatarType = _nullableEnumString(payload, 'avatarType', const <String>{
    'emoji',
    'url',
    'file',
  });
  final avatarValue = _nullableString(payload, 'avatarValue');
  if ((avatarType == null) != (avatarValue == null) ||
      (avatarValue != null && avatarValue.trim().isEmpty)) {
    throw const FormatException('profile 头像类型和值必须同时有效');
  }
}

void _validateProviderGroupingPreference(Map<String, Object?> payload) {
  _expectExactKeys(payload, const <String>{
    'order',
    'groups',
    'assignments',
    'ungroupedPosition',
  }, 'provider-grouping');
  _requiredIdentifierList(payload, 'order');
  final groups = _requiredList(payload, 'groups');
  final groupIds = <String>{};
  for (var index = 0; index < groups.length; index++) {
    final group = _expectObject(
      groups[index],
      'provider-grouping.groups[$index]',
    );
    _expectExactKeys(group, const <String>{
      'id',
      'name',
      'createdAt',
    }, 'provider-grouping.groups[$index]');
    final id = _requiredIdentifier(group, 'id');
    if (!groupIds.add(id)) {
      throw FormatException('provider-grouping.groups[$index].id 重复');
    }
    _requiredString(group, 'name', allowEmpty: true);
    _requiredNonNegativeInteger(group, 'createdAt');
  }
  final assignments = _requiredObject(payload, 'assignments');
  for (final entry in assignments.entries) {
    _requireIdentifier(entry.key, 'provider-grouping.assignments 键');
    final groupId = entry.value;
    if (groupId is! String) {
      throw const FormatException('provider-grouping.assignments 值必须是字符串');
    }
    _requireIdentifier(groupId, 'provider-grouping.assignments 值');
    if (!groupIds.contains(groupId)) {
      throw const FormatException('provider-grouping.assignments 引用了未知分组');
    }
  }
  _requiredNonNegativeInteger(payload, 'ungroupedPosition');
}

void _validateActiveIdsByAssistant(Map<String, Object?> values) {
  for (final entry in values.entries) {
    _requireIdentifier(entry.key, 'activeIdsByAssistant 键');
    if (entry.value is! List<Object?>) {
      throw const FormatException('activeIdsByAssistant 值必须是数组');
    }
    _validateIdentifierValues(
      entry.value! as List<Object?>,
      'activeIdsByAssistant',
    );
  }
}

void _validateSearchStatePreference(Map<String, Object?> payload) {
  _expectExactKeys(payload, const <String>{
    'selectedServiceId',
    'commonOptions',
    'enabled',
    'autoTestOnLaunch',
  }, 'search-state');
  _nullableIdentifier(payload, 'selectedServiceId');
  final common = _requiredObject(payload, 'commonOptions');
  _expectExactKeys(common, const <String>{
    'resultSize',
    'timeout',
  }, 'search-state.commonOptions');
  _requiredPositiveInteger(common, 'resultSize');
  _requiredPositiveInteger(common, 'timeout');
  _requiredBoolean(payload, 'enabled');
  _requiredBoolean(payload, 'autoTestOnLaunch');
}

void _validateTtsStatePreference(Map<String, Object?> payload) {
  _expectExactKeys(payload, const <String>{
    'selectedServiceId',
    'autoPlayAssistantReplies',
    'textSelectionMode',
  }, 'tts-state');
  _nullableIdentifier(payload, 'selectedServiceId');
  _requiredBoolean(payload, 'autoPlayAssistantReplies');
  _requiredEnumString(payload, 'textSelectionMode', const <String>{
    'fullText',
    'quotedOnly',
    'outsideParentheses',
    'italicOnly',
    'nonItalic',
  });
}

void _expectExactKeys(
  Map<String, Object?> payload,
  Set<String> expected,
  String context,
) {
  _expectKeys(
    payload,
    required: expected,
    optional: const <String>{},
    context: context,
  );
}

void _expectKeys(
  Map<String, Object?> payload, {
  required Set<String> required,
  required Set<String> optional,
  required String context,
}) {
  final allowed = <String>{...required, ...optional};
  if (!required.every(payload.containsKey) ||
      !payload.keys.every(allowed.contains)) {
    throw FormatException('$context 字段不匹配');
  }
}

Map<String, Object?> _expectObject(Object? value, String context) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$context 必须是对象');
  }
  return value;
}

Object? _requiredValue(Map<String, Object?> payload, String key) {
  if (!payload.containsKey(key)) throw FormatException('缺少字段：$key');
  return payload[key];
}

Map<String, Object?> _requiredObject(
  Map<String, Object?> payload,
  String key,
) => _expectObject(_requiredValue(payload, key), key);

List<Object?> _requiredList(Map<String, Object?> payload, String key) {
  final value = _requiredValue(payload, key);
  if (value is! List<Object?>) throw FormatException('$key 必须是数组');
  return value;
}

String _requiredString(
  Map<String, Object?> payload,
  String key, {
  bool allowEmpty = false,
}) {
  final value = _requiredValue(payload, key);
  if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
    throw FormatException('$key 必须是${allowEmpty ? '' : '非空'}字符串');
  }
  return value;
}

String? _nullableString(Map<String, Object?> payload, String key) {
  final value = _requiredValue(payload, key);
  if (value == null) return null;
  if (value is! String) throw FormatException('$key 必须是字符串或 null');
  return value;
}

String _requiredIdentifier(Map<String, Object?> payload, String key) {
  final value = _requiredString(payload, key);
  _requireIdentifier(value, key);
  return value;
}

String? _nullableIdentifier(Map<String, Object?> payload, String key) {
  final value = _nullableString(payload, key);
  if (value != null) _requireIdentifier(value, key);
  return value;
}

void _requireIdentifier(String value, String context) {
  try {
    validateSyncEntityKey(
      SyncEntityKey(entityType: 'config-reference', entityId: value),
    );
  } on FormatException {
    throw FormatException('$context 不是合法同步实体 ID');
  }
}

void _requireMatchingIdentity(
  Map<String, Object?> payload,
  String key,
  SyncEntityKey entityKey,
) {
  final identity = _requiredIdentifier(payload, key);
  if (identity != entityKey.entityId) {
    throw FormatException('${entityKey.entityType}.$key 与记录身份不一致');
  }
}

bool _requiredBoolean(Map<String, Object?> payload, String key) {
  final value = _requiredValue(payload, key);
  if (value is! bool) throw FormatException('$key 必须是布尔值');
  return value;
}

void _nullableBoolean(Map<String, Object?> payload, String key) {
  final value = _requiredValue(payload, key);
  if (value != null && value is! bool) {
    throw FormatException('$key 必须是布尔值或 null');
  }
}

int _requiredSignedInteger(Map<String, Object?> payload, String key) {
  final value = _requiredValue(payload, key);
  if (value is! int ||
      value < -_maximumPositiveInt63 - 1 ||
      value > _maximumPositiveInt63) {
    throw FormatException('$key 必须是 int64');
  }
  return value;
}

int _requiredNonNegativeInteger(Map<String, Object?> payload, String key) {
  final value = _requiredSignedInteger(payload, key);
  if (value < 0) throw FormatException('$key 必须是非负整数');
  return value;
}

int _requiredPositiveInteger(Map<String, Object?> payload, String key) {
  final value = _requiredSignedInteger(payload, key);
  if (value <= 0) throw FormatException('$key 必须是正整数');
  return value;
}

void _nullableNonNegativeInteger(Map<String, Object?> payload, String key) {
  final value = _requiredValue(payload, key);
  if (value == null) return;
  if (value is! int || value < 0 || value > _maximumPositiveInt63) {
    throw FormatException('$key 必须是非负 int63 或 null');
  }
}

void _nullablePositiveInteger(Map<String, Object?> payload, String key) {
  final value = _requiredValue(payload, key);
  if (value == null) return;
  if (value is! int || value <= 0 || value > _maximumPositiveInt63) {
    throw FormatException('$key 必须是正 int63 或 null');
  }
}

double _requiredDouble(Map<String, Object?> payload, String key) {
  final value = _requiredValue(payload, key);
  if (value is! double || !value.isFinite) {
    throw FormatException('$key 必须是有限 double');
  }
  return value;
}

void _nullableDoubleInRange(
  Map<String, Object?> payload,
  String key, {
  required double minimum,
  required double maximum,
}) {
  final value = _requiredValue(payload, key);
  if (value == null) return;
  if (value is! double ||
      !value.isFinite ||
      value < minimum ||
      value > maximum) {
    throw FormatException('$key 超出 double 范围');
  }
}

String _requiredEnumString(
  Map<String, Object?> payload,
  String key,
  Set<String> values,
) {
  final value = _requiredString(payload, key);
  if (!values.contains(value)) throw FormatException('$key 枚举值无效');
  return value;
}

String? _nullableEnumString(
  Map<String, Object?> payload,
  String key,
  Set<String> values,
) {
  final value = _nullableString(payload, key);
  if (value != null && !values.contains(value)) {
    throw FormatException('$key 枚举值无效');
  }
  return value;
}

void _requiredStringList(Map<String, Object?> payload, String key) {
  final values = _requiredList(payload, key);
  for (var index = 0; index < values.length; index++) {
    if (values[index] is! String) {
      throw FormatException('$key[$index] 必须是字符串');
    }
  }
}

void _requiredTrimmedStringList(Map<String, Object?> payload, String key) {
  final values = _requiredList(payload, key);
  final unique = <String>{};
  for (var index = 0; index < values.length; index++) {
    final value = values[index];
    if (value is! String || value.isEmpty || value.trim() != value) {
      throw FormatException('$key[$index] 必须是规范非空字符串');
    }
    if (!unique.add(value)) throw FormatException('$key[$index] 重复');
  }
}

void _requiredIdentifierList(Map<String, Object?> payload, String key) {
  _validateIdentifierValues(_requiredList(payload, key), key);
}

void _validateIdentifierValues(List<Object?> values, String context) {
  final unique = <String>{};
  for (var index = 0; index < values.length; index++) {
    final value = values[index];
    if (value is! String) {
      throw FormatException('$context[$index] 必须是字符串');
    }
    _requireIdentifier(value, '$context[$index]');
    if (!unique.add(value)) throw FormatException('$context[$index] 重复');
  }
}

void _requiredEnumStringList(
  Map<String, Object?> payload,
  String key,
  Set<String> allowed,
) {
  final values = _requiredList(payload, key);
  final unique = <String>{};
  for (var index = 0; index < values.length; index++) {
    final value = values[index];
    if (value is! String || !allowed.contains(value)) {
      throw FormatException('$key[$index] 枚举值无效');
    }
    if (!unique.add(value)) throw FormatException('$key[$index] 重复');
  }
}

void _requiredPosition(Map<String, Object?> payload) {
  _requiredNonNegativeInteger(payload, '_position');
}
