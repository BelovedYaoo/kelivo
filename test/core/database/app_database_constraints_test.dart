import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_gateway.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/e2ee_sync_record_ledger.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_record_cipher.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_record_state.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_trust_manifest.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_key_transition.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_attachment_types.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_client.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_types.dart';
import 'package:Kelivo/core/services/sync/e2ee_attachment_crypto_session.dart';
import 'package:Kelivo/core/services/sync/e2ee_attachment_download_coordinator.dart';
import 'package:Kelivo/core/services/sync/e2ee_attachment_file_store.dart';
import 'package:Kelivo/core/services/sync/e2ee_attachment_manifest.dart';
import 'package:Kelivo/core/services/sync/e2ee_chat_sync_adapter.dart';
import 'package:Kelivo/core/services/sync/e2ee_message_attachment_readiness.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_record_types.dart';
import 'package:Kelivo/core/services/sync/config_sync_keys.dart';
import 'package:Kelivo/core/services/sync/e2ee_config_sync_adapter.dart';
import 'package:Kelivo/core/services/sync/e2ee_data_rekey_executor.dart';
import 'package:Kelivo/core/services/sync/e2ee_data_rekey_wire.dart';
import 'package:Kelivo/core/services/sync/e2ee_device_state_access.dart';
import 'package:Kelivo/core/services/sync/e2ee_device_state_key_transition.dart';
import 'package:Kelivo/core/services/sync/e2ee_sync_outbox.dart';
import 'package:Kelivo/core/services/sync/e2ee_sync_execution_budget.dart';
import 'package:Kelivo/core/services/sync/e2ee_sync_payload_codec.dart';
import 'package:Kelivo/core/services/sync/e2ee_sync_pull.dart';
import 'package:Kelivo/core/services/sync/sync_codec.dart';
import 'package:Kelivo/core/services/workspace/e2ee_data_rekey_stage_store.dart';
import 'package:Kelivo/core/services/workspace/device_state_blob_store.dart';
import 'package:drift/drift.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:uuid/uuid.dart';

import 'test_database_cipher.dart';

Matcher throwsRemoteSqliteException() => throwsA(
  isA<DriftRemoteException>().having(
    (error) => error.remoteCause,
    'remoteCause',
    isA<SqliteException>(),
  ),
);

const _ledgerEntityKey = SyncEntityKey(
  entityType: 'chat',
  entityId: 'ledger-chat-1',
);
const _ledgerUserId = '10000000-0000-4000-8000-000000000001';
const _ledgerClaimedWriterDeviceId = '30000000-0000-4000-8000-000000000001';
const _syncIntentId = '40000000-0000-4000-8000-000000000001';
const _syncOperationId = '50000000-0000-4000-8000-000000000001';
const _syncRecordId = '60000000-0000-4000-8000-000000000001';
const _syncAccountUserId = '70000000-0000-4000-8000-000000000001';
const _syncActorDeviceId = '80000000-0000-4000-8000-000000000001';

String _ledgerOperationId(int value) =>
    '20000000-0000-4000-8000-${value.toString().padLeft(12, '0')}';

String _syncUuid(int value) =>
    '90000000-0000-4000-8000-${value.toString().padLeft(12, '0')}';

Uint8List _syncDigest(int value, {int length = 32}) =>
    Uint8List.fromList(List<int>.filled(length, value));

String _digestHex(Uint8List value) =>
    value.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

bool _containsByteSequence(Uint8List source, List<int> target) {
  if (target.isEmpty || target.length > source.length) return false;
  for (var start = 0; start <= source.length - target.length; start++) {
    var matches = true;
    for (var offset = 0; offset < target.length; offset++) {
      if (source[start + offset] != target[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}

Map<String, Object?> _conversationPayload(String title) => <String, Object?>{
  'title': title,
  'createdAt': '2026-07-28T00:00:00.000Z',
  'updatedAt': '2026-07-28T00:00:00.000Z',
  'isPinned': false,
  'assistantId': null,
  'mcpServerIds': const <Object?>[],
  'truncateIndex': -1,
  'summary': null,
  'lastSummarizedMessageCount': 0,
  'chatSuggestions': const <Object?>[],
};

Map<String, Object?> _turnPayload(String conversationId) => <String, Object?>{
  'conversationId': conversationId,
  'createdAt': '2026-07-28T00:00:01.000Z',
};

Map<String, Object?> _messagePayload({
  required String conversationId,
  required String turnId,
  required String groupId,
  List<Object?> attachments = const <Object?>[],
  String content = '远端消息',
}) => <String, Object?>{
  'conversationId': conversationId,
  'turnId': turnId,
  'role': 'assistant',
  'content': content,
  'attachments': attachments,
  'timestamp': '2026-07-28T00:00:02.000Z',
  'groupId': groupId,
  'version': 0,
  'status': 'completed',
  'modelId': 'model-1',
  'providerId': 'provider-1',
  'totalTokens': 12,
  'reasoningText': null,
  'reasoningSegmentsJson': null,
  'translation': null,
  'reasoningStartAt': null,
  'reasoningFinishedAt': null,
  'promptTokens': 5,
  'completionTokens': 7,
  'cachedTokens': 0,
  'durationMs': 100,
};

List<({SyncEntityKey key, Map<String, Object?> payload})>
_configPayloadCases() {
  const providerId = 'provider-config-1';
  const assistantId = 'assistant-config-1';
  const memoryId = 'memory-config-1';
  const worldBookId = 'world-book-config-1';
  const quickPhraseId = 'quick-phrase-config-1';
  const searchServiceId = 'search-config-1';
  const ttsServiceId = 'tts-config-1';
  const mcpServerId = 'mcp-config-1';
  const instructionId = 'instruction-config-1';
  return <({SyncEntityKey key, Map<String, Object?> payload})>[
    (
      key: ConfigSyncKeys.provider(providerId),
      payload: <String, Object?>{
        'id': providerId,
        'enabled': true,
        'name': 'OpenAI',
        'apiKey': 'sk-provider-secret',
        'baseUrl': 'https://api.example.com/v1',
        'providerType': 'openai',
        'chatPath': null,
        'useResponseApi': true,
        'vertexAI': null,
        'location': null,
        'projectId': null,
        'serviceAccountJson': null,
        'models': <Object?>['gpt-4.1'],
        'modelOverrides': <String, Object?>{
          'gpt-4.1': <String, Object?>{
            'apiModelId': 'gpt-4.1-2026-07-01',
            'headers': <Object?>[
              <String, Object?>{'name': 'X-Secret', 'value': 'header-secret'},
            ],
            'body': <Object?>[
              <String, Object?>{'key': 'reasoning', 'value': 'true'},
            ],
          },
        },
        'proxyEnabled': true,
        'proxyType': 'http',
        'proxyHost': '127.0.0.1',
        'proxyPort': '7890',
        'proxyUsername': 'proxy-user',
        'proxyPassword': 'proxy-secret',
        'avatarType': null,
        'avatarValue': null,
        'multiKeyEnabled': true,
        'apiKeys': <Object?>[
          <String, Object?>{
            'id': 'key-1',
            'key': 'sk-key-secret',
            'name': '主密钥',
            'isEnabled': true,
            'priority': 1,
            'maxRequestsPerMinute': 60,
            'usage': <String, Object?>{
              'totalRequests': 12,
              'successfulRequests': 10,
              'failedRequests': 2,
              'consecutiveFailures': 0,
              'lastUsed': 1785254400000,
            },
            'status': 'active',
            'lastError': null,
            'createdAt': 1785254300000,
            'updatedAt': 1785254400000,
          },
        ],
        'keyManagement': <String, Object?>{
          'strategy': 'roundRobin',
          'maxFailuresBeforeDisable': 3,
          'failureRecoveryTimeMinutes': 5,
          'enableAutoRecovery': true,
          'roundRobinIndex': 0,
        },
        'aihubmixAppCodeEnabled': false,
        'balanceEnabled': true,
        'balanceApiPath': '/credits',
        'balanceResultPath': r'$.data.balance',
        'claudePromptCachingEnabled': false,
        'claudePromptCachingTtl': '5m',
        '_position': 0,
      },
    ),
    (
      key: ConfigSyncKeys.assistant(assistantId),
      payload: <String, Object?>{
        'id': assistantId,
        'name': '助手',
        'avatar': null,
        'useAssistantAvatar': false,
        'useAssistantName': true,
        'chatModelProvider': providerId,
        'chatModelId': 'gpt-4.1',
        'temperature': 0.7,
        'topP': 1.0,
        'contextMessageSize': 64,
        'limitContextMessages': true,
        'streamOutput': true,
        'thinkingBudget': 128,
        'maxTokens': 4096,
        'systemPrompt': '你是助手',
        'messageTemplate': '{{ message }}',
        'searchEnabled': true,
        'mcpServerIds': <Object?>[mcpServerId],
        'localToolIds': <Object?>['calculator'],
        'background': 'https://example.com/background.png',
        'customHeaders': <Object?>[
          <String, Object?>{'name': 'X-Assistant', 'value': 'header-value'},
        ],
        'customBody': <Object?>[
          <String, Object?>{'key': 'reasoning', 'value': 'true'},
        ],
        'enableMemory': true,
        'enableRecentChatsReference': true,
        'recentChatsSummaryMessageCount': 5,
        'presetMessages': <Object?>[
          <String, Object?>{'id': 'preset-1', 'role': 'user', 'content': '你好'},
        ],
        'regexRules': <Object?>[
          <String, Object?>{
            'id': 'regex-1',
            'name': '清理',
            'pattern': r'\s+$',
            'replacement': '',
            'scopes': <Object?>['assistant'],
            'visualOnly': false,
            'replaceOnly': true,
            'enabled': true,
          },
        ],
        '_position': 0,
      },
    ),
    (
      key: ConfigSyncKeys.memory(memoryId),
      payload: <String, Object?>{
        'id': 7,
        'syncId': memoryId,
        'assistantId': assistantId,
        'content': '偏好简洁回答',
      },
    ),
    (
      key: ConfigSyncKeys.worldBook(worldBookId),
      payload: <String, Object?>{
        'id': worldBookId,
        'name': '世界书',
        'description': '设定',
        'enabled': true,
        'entries': <Object?>[
          <String, Object?>{
            'id': 'entry-1',
            'name': '地点',
            'enabled': true,
            'priority': 1,
            'position': 'AFTER_SYSTEM_PROMPT',
            'content': '地点设定',
            'injectDepth': 4,
            'role': 'USER',
            'keywords': <Object?>['地点'],
            'useRegex': false,
            'caseSensitive': false,
            'scanDepth': 4,
            'constantActive': false,
          },
        ],
        '_position': 0,
      },
    ),
    (
      key: ConfigSyncKeys.quickPhrase(quickPhraseId),
      payload: <String, Object?>{
        'id': quickPhraseId,
        'title': '继续',
        'content': '请继续',
        'isGlobal': false,
        'assistantId': assistantId,
        '_position': 0,
      },
    ),
    (
      key: ConfigSyncKeys.searchService(searchServiceId),
      payload: <String, Object?>{
        'type': 'searxng',
        'id': searchServiceId,
        'url': 'https://search.example.com',
        'engines': 'google,bing',
        'language': 'zh-CN',
        'username': 'search-user',
        'password': 'search-secret',
        '_position': 0,
      },
    ),
    (
      key: ConfigSyncKeys.networkTts(ttsServiceId),
      payload: <String, Object?>{
        'id': ttsServiceId,
        'enabled': true,
        'name': 'MiniMax',
        'kind': 'minimax',
        'apiKey': 'tts-secret',
        'baseUrl': 'https://tts.example.com/v1',
        'model': 'speech-2.6-turbo',
        'voiceId': 'female-shaonv',
        'emotion': 'calm',
        'speed': 1.0,
        '_position': 0,
      },
    ),
    (
      key: ConfigSyncKeys.mcpServer(mcpServerId),
      payload: <String, Object?>{
        'id': mcpServerId,
        'enabled': true,
        'name': '远端 MCP',
        'transport': 'http',
        'url': 'https://mcp.example.com',
        'tools': <Object?>[
          <String, Object?>{
            'enabled': true,
            'name': 'search',
            'description': '搜索',
            'params': <Object?>[
              <String, Object?>{
                'name': 'query',
                'required': true,
                'type': 'string',
                'default': null,
              },
            ],
            'schema': <String, Object?>{
              'type': 'object',
              'properties': <String, Object?>{
                'query': <String, Object?>{'type': 'string'},
              },
            },
            'needsApproval': true,
          },
        ],
        'headers': <String, Object?>{'Authorization': 'Bearer mcp-secret'},
        '_position': 0,
      },
    ),
    (
      key: ConfigSyncKeys.instructionInjection(instructionId),
      payload: <String, Object?>{
        'id': instructionId,
        'title': '格式',
        'prompt': '使用 Markdown',
        'group': '输出',
        '_position': 0,
      },
    ),
    (
      key: ConfigSyncKeys.profile,
      payload: <String, Object?>{
        'name': 'Ovo',
        'avatarType': 'emoji',
        'avatarValue': 'O',
      },
    ),
    (
      key: ConfigSyncKeys.providerGrouping,
      payload: <String, Object?>{
        'order': <Object?>[providerId],
        'groups': <Object?>[
          <String, Object?>{
            'id': 'group-1',
            'name': '常用',
            'createdAt': 1785254400000,
          },
        ],
        'assignments': <String, Object?>{providerId: 'group-1'},
        'ungroupedPosition': 1,
      },
    ),
    (
      key: ConfigSyncKeys.assistantSelection,
      payload: <String, Object?>{'assistantId': assistantId},
    ),
    (
      key: ConfigSyncKeys.worldBookActivity,
      payload: <String, Object?>{
        'activeIdsByAssistant': <String, Object?>{
          assistantId: <Object?>[worldBookId],
        },
      },
    ),
    (
      key: ConfigSyncKeys.instructionActivity,
      payload: <String, Object?>{
        'activeIdsByAssistant': <String, Object?>{
          assistantId: <Object?>[instructionId],
        },
      },
    ),
    (
      key: ConfigSyncKeys.searchState,
      payload: <String, Object?>{
        'selectedServiceId': searchServiceId,
        'commonOptions': <String, Object?>{'resultSize': 10, 'timeout': 5000},
        'enabled': true,
        'autoTestOnLaunch': false,
      },
    ),
    (
      key: ConfigSyncKeys.ttsState,
      payload: <String, Object?>{
        'selectedServiceId': ttsServiceId,
        'autoPlayAssistantReplies': true,
        'textSelectionMode': 'fullText',
      },
    ),
    (
      key: ConfigSyncKeys.mcpState,
      payload: <String, Object?>{'requestTimeoutSeconds': 30},
    ),
  ];
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory directory;
  late AppDatabase database;
  late ChatDatabaseRepository repository;
  late E2eeAccountRecordStateCodec stateCodec;
  late E2eeSyncRecordLedger ledger;
  late E2eeConfigVaultCommands configVault;
  late E2eeAttachmentUploadCommands attachmentUploads;
  late E2eeAttachmentDownloadCommands attachmentDownloads;
  late E2eeDataRekeyCommands dataRekeyCommands;
  late E2eeSyncOutboxCommands outboxCommands;
  late E2eeSyncPullCommands pullCommands;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'kelivo_database_constraints_',
    );
    database = AppDatabase.open(
      file: File('${directory.path}/constraints.sqlite'),
      cipher: testDatabaseCipher,
    );
    await database.customSelect('SELECT 1;').getSingle();
    repository = ChatDatabaseRepository(
      database,
      databaseCipher: testDatabaseCipher,
    );
    const secureCore = KelivoSecureCore();
    stateCodec = E2eeAccountRecordStateCodec.takeOwnership(
      E2eeAccountRecordCipher.takeOwnership(
        secureCore: secureCore,
        accountRootKey: await secureCore.generateAccountRootKey(
          userId: Uuid.parseAsByteList(_ledgerUserId),
          keyEpoch: 7,
        ),
        userId: _ledgerUserId,
        currentKeyEpoch: 7,
      ),
    );
    ledger = E2eeSyncRecordLedger(database);
    configVault = repository.e2eeConfigVaultCommands;
    attachmentUploads = repository.e2eeAttachmentUploadCommands;
    attachmentDownloads = repository.e2eeAttachmentDownloadCommands;
    dataRekeyCommands = repository.e2eeDataRekeyCommands;
    outboxCommands = await repository.acquireE2eeSyncOutboxCommands(
      now: DateTime.utc(2026, 7, 28),
    );
    pullCommands = repository.e2eeSyncPullCommands;
  });

  tearDown(() async {
    await stateCodec.close();
    await repository.close();
    await directory.delete(recursive: true);
  });

  Future<
    ({
      KelivoAccountRootKeyHandle ark,
      E2eeVerifiedMembership initialized,
      E2eeVerifiedMembership paired,
      E2eeVerifiedMembership revoked,
      E2eeVerifiedMembership resumed,
      E2eeVerifiedMembership replaced,
    })
  >
  createMembershipChain() async {
    const secureCore = KelivoSecureCore();
    const manifestModule = E2eeAccountTrustManifestModule();
    final ark = await secureCore.generateAccountRootKey(
      userId: Uuid.parseAsByteList(_syncAccountUserId),
      keyEpoch: 1,
    );
    try {
      final issuer = await _newDatabaseMembershipDevice(
        secureCore,
        deviceId: _syncActorDeviceId,
        authGeneration: 0,
      );
      final subject = await _newDatabaseMembershipDevice(
        secureCore,
        deviceId: _syncUuid(101),
        authGeneration: 1,
      );
      final recoveryPublicKey = await _newDatabaseRecoveryPublicKey(secureCore);
      final initialized = await manifestModule.create(
        ark: ark,
        change: E2eeInitializeMembershipChange(
          userId: _syncAccountUserId,
          operationId: _syncOperationId,
          member: issuer,
          recoveryPublicKeyVersion: 1,
          recoveryPublicKey: recoveryPublicKey,
          recoveryCapsuleVersion: 1,
          recoveryCapsule: Uint8List(80)..fillRange(0, 80, 0x41),
        ),
      );
      final paired = await manifestModule.create(
        ark: ark,
        change: E2eeAddDeviceMembershipChange(
          previous: initialized,
          pairingId: _syncUuid(102),
          issuerDeviceId: issuer.deviceId,
          subject: subject,
        ),
      );
      final epoch2 = await secureCore.generateAccountRootKey(
        userId: Uuid.parseAsByteList(_syncAccountUserId),
        keyEpoch: 2,
      );
      try {
        await secureCore.addAccountRootKeyEpoch(ark, source: epoch2);
      } finally {
        await secureCore.closeAccountRootKey(epoch2);
      }
      final revoked = await manifestModule.create(
        ark: ark,
        change: E2eeRevokeRotateMembershipChange(
          previous: paired,
          operationId: _syncUuid(105),
          issuerDeviceId: issuer.deviceId,
          revokedDeviceId: subject.deviceId,
          nextRecoveryCapsuleVersion: 2,
          nextRecoveryCapsule: Uint8List(80)..fillRange(0, 80, 0x42),
          operationAuthorizationDigest: _syncDigest(0x51),
        ),
      );
      final recoveryDevice = await _newDatabaseMembershipDevice(
        secureCore,
        deviceId: _syncUuid(106),
        authGeneration: 1,
      );
      final resumed = await manifestModule.create(
        ark: ark,
        change: E2eeRecoverResumeMembershipChange(
          previous: revoked,
          operationId: _syncUuid(107),
          subject: recoveryDevice,
        ),
      );
      final epoch3 = await secureCore.generateAccountRootKey(
        userId: Uuid.parseAsByteList(_syncAccountUserId),
        keyEpoch: 3,
      );
      try {
        await secureCore.addAccountRootKeyEpoch(ark, source: epoch3);
      } finally {
        await secureCore.closeAccountRootKey(epoch3);
      }
      final replaced = await manifestModule.create(
        ark: ark,
        change: E2eeRecoverReplaceMembershipChange(
          previous: resumed,
          operationId: _syncUuid(108),
          subject: recoveryDevice,
          nextRecoveryCapsuleVersion: 3,
          nextRecoveryCapsule: Uint8List(80)..fillRange(0, 80, 0x43),
        ),
      );
      return (
        ark: ark,
        initialized: initialized,
        paired: paired,
        revoked: revoked,
        resumed: resumed,
        replaced: replaced,
      );
    } catch (_) {
      await secureCore.closeAccountRootKey(ark);
      rethrow;
    }
  }

  Future<E2eeAuthenticatedAccountRecordState> createAuthenticatedState({
    SyncEntityKey entityKey = _ledgerEntityKey,
    required int logicalVersion,
    required List<E2eeAccountRecordStateDigest> parentDigests,
    required int operation,
  }) async {
    final sealed = await stateCodec.sealValue(
      entityKey: entityKey,
      logicalVersion: logicalVersion,
      parentDigests: parentDigests,
      operationId: _ledgerOperationId(operation),
      claimedWriterDeviceId: _ledgerClaimedWriterDeviceId,
      claimedWriterKeyVersion: 1,
      payload: Uint8List.fromList(<int>[operation]),
    );
    return stateCodec.open(
      E2eeUntrustedAccountRecordEnvelope.fromTransport(
        recordId: E2eeUntrustedAccountRecordId.fromTransport(
          sealed.record.recordId.wireValue,
        ),
        envelopeVersion: e2eeAccountRecordEnvelopeVersion,
        keyEpoch: sealed.record.keyEpoch,
        ciphertext: sealed.record.ciphertext,
      ),
      decode: (state, _) => state,
    );
  }

  Future<CloudSyncPutRecordChange> createPullValueChange({
    required int changeSeq,
    required int revision,
    required int operation,
    Map<String, Object?>? payload,
    Uint8List? encodedPayload,
    int? keyEpoch,
    SyncEntityKey? entityKey,
    int logicalVersion = 1,
    List<E2eeAccountRecordStateDigest> parentDigests = const [],
  }) async {
    final resolvedEntityKey =
        entityKey ??
        SyncEntityKey(
          entityType: 'conversation',
          entityId: 'pull-value-$operation',
        );
    final sealed = await stateCodec.sealValue(
      entityKey: resolvedEntityKey,
      logicalVersion: logicalVersion,
      parentDigests: parentDigests,
      operationId: _ledgerOperationId(operation),
      claimedWriterDeviceId: _ledgerClaimedWriterDeviceId,
      claimedWriterKeyVersion: 1,
      payload:
          encodedPayload ??
          E2eeSyncPayloadCodec.encode(
            entityKey: resolvedEntityKey,
            payload: payload ?? _conversationPayload('远端会话'),
          ),
    );
    return CloudSyncPutRecordChange(
      changeSeq: changeSeq,
      revision: revision,
      updatedAt: DateTime.utc(2026, 7, 28),
      updatedByDeviceId: _syncActorDeviceId,
      record: E2eeUntrustedAccountRecordEnvelope.fromTransport(
        recordId: E2eeUntrustedAccountRecordId.fromTransport(
          sealed.record.recordId.wireValue,
        ),
        envelopeVersion: e2eeAccountRecordEnvelopeVersion,
        keyEpoch: keyEpoch ?? sealed.record.keyEpoch,
        ciphertext: sealed.record.ciphertext,
      ),
    );
  }

  Future<E2eeAuthenticatedAccountRecordState> authenticatePullChange(
    CloudSyncPutRecordChange change,
  ) {
    return stateCodec.open(change.record, decode: (state, _) => state);
  }

  Future<E2eeSyncPulledValueChange> authenticatePulledValueChange(
    CloudSyncPutRecordChange change,
  ) {
    return stateCodec.open(
      change.record,
      decode: (state, borrowedPayload) => E2eeSyncPulledValueChange(
        untrustedServerMetadata: E2eeSyncUntrustedServerMetadata(
          changeSeq: change.changeSeq,
          revision: change.revision,
        ),
        state: state,
        payload: E2eeSyncPayloadCodec.decode(
          entityKey: state.entityKey,
          bytes: borrowedPayload,
        ),
      ),
    );
  }

  CloudSyncEncryptedRecord snapshotRecordFromChange(
    CloudSyncPutRecordChange change,
  ) {
    return CloudSyncEncryptedRecord(
      revision: change.revision,
      updatedAt: change.updatedAt,
      updatedByDeviceId: change.updatedByDeviceId,
      lastChangeSeq: change.changeSeq,
      record: change.record,
    );
  }

  Future<CloudSyncPutRecordChange> createPullTombstoneChange({
    required int changeSeq,
    required int revision,
    required int operation,
    SyncEntityKey? entityKey,
    int logicalVersion = 1,
    List<E2eeAccountRecordStateDigest> parentDigests = const [],
  }) async {
    final sealed = await stateCodec.sealTombstone(
      entityKey:
          entityKey ??
          SyncEntityKey(
            entityType: 'conversation',
            entityId: 'pull-tombstone-$operation',
          ),
      logicalVersion: logicalVersion,
      parentDigests: parentDigests,
      operationId: _ledgerOperationId(operation),
      claimedWriterDeviceId: _ledgerClaimedWriterDeviceId,
      claimedWriterKeyVersion: 1,
    );
    return CloudSyncPutRecordChange(
      changeSeq: changeSeq,
      revision: revision,
      updatedAt: DateTime.utc(2026, 7, 28),
      updatedByDeviceId: _syncActorDeviceId,
      record: E2eeUntrustedAccountRecordEnvelope.fromTransport(
        recordId: E2eeUntrustedAccountRecordId.fromTransport(
          sealed.record.recordId.wireValue,
        ),
        envelopeVersion: e2eeAccountRecordEnvelopeVersion,
        keyEpoch: sealed.record.keyEpoch,
        ciphertext: sealed.record.ciphertext,
      ),
    );
  }

  Future<E2eeSyncPulledTombstoneChange> authenticatePulledTombstoneChange(
    CloudSyncPutRecordChange change,
  ) {
    return stateCodec.open(
      change.record,
      decode: (state, borrowedPayload) {
        expect(borrowedPayload, isEmpty);
        return E2eeSyncPulledTombstoneChange(
          untrustedServerMetadata: E2eeSyncUntrustedServerMetadata(
            changeSeq: change.changeSeq,
            revision: change.revision,
          ),
          state: state,
        );
      },
    );
  }

  E2eeSyncPullCoordinator createPullCoordinator({
    required E2eeSyncAuthenticatedPullTransport transport,
    required E2eeSyncTransactionalBusinessApplier applyPage,
    E2eeSyncPullPagePreparer pagePreparer =
        const E2eeNoopSyncPullPagePreparer(),
    int maximumPreparationRemoteSteps = 1,
  }) {
    var clockTick = 0;
    return E2eeSyncPullCoordinator(
      pullCommands: pullCommands,
      stateCodec: stateCodec,
      transport: transport,
      pagePreparer: pagePreparer,
      maximumPreparationRemoteSteps: maximumPreparationRemoteSteps,
      applyBusiness: applyPage,
      utcNow: () =>
          DateTime.utc(2026, 7, 28).add(Duration(microseconds: clockTick++)),
    );
  }

  Future<void> insertConversation({
    String id = 'conversation-1',
    DateTime? timestamp,
  }) {
    final value = timestamp ?? DateTime.utc(2026, 7, 11);
    return database
        .into(database.conversationRows)
        .insert(
          ConversationRowsCompanion.insert(
            id: id,
            title: 'Conversation',
            createdAt: value,
            updatedAt: value,
          ),
        );
  }

  Future<void> insertMessage({
    String id = 'message-1',
    String conversationId = 'conversation-1',
    String role = 'assistant',
    String content = 'content',
    String? groupId = 'group-1',
    int version = 0,
    int messageOrder = 0,
    int? totalTokens = 0,
    DateTime? timestamp,
  }) {
    return database
        .into(database.messageRows)
        .insert(
          MessageRowsCompanion.insert(
            id: id,
            conversationId: conversationId,
            role: role,
            content: content,
            timestamp: timestamp ?? DateTime.utc(2026, 7, 11),
            turnId: 'turn-1',
            generationStatus: 'completed',
            groupId: Value(groupId),
            version: Value(version),
            totalTokens: Value(totalTokens),
            messageOrder: messageOrder,
          ),
        );
  }

  Future<void> insertAsset({required String id, required String contentHash}) {
    final now = DateTime.utc(2026, 7, 11);
    return database
        .into(database.assetRows)
        .insert(
          AssetRowsCompanion.insert(
            id: id,
            contentHash: contentHash,
            path: 'D:\\workspace\\assets\\$id.bin',
            byteSize: 1,
            createdAt: now,
            lastReferencedAt: now,
          ),
        );
  }

  Future<void> insertSyncIntent({
    String entityType = 'conversation',
    String entityId = 'conversation-1',
    String intentId = _syncIntentId,
    int generation = 1,
    String phase = 'dirty',
    String? writerSessionId,
    String? sealLeaseToken,
    String? sealOwnerSessionId,
    DateTime? sealLeaseExpiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) async {
    final created = createdAt ?? DateTime.utc(2026, 7, 27);
    await database
        .into(database.e2eeSyncIntentRows)
        .insert(
          E2eeSyncIntentRowsCompanion.insert(
            entityType: entityType,
            entityId: entityId,
            intentId: intentId,
            generation: generation,
            phase: phase,
            writerSessionId: Value(writerSessionId),
            sealLeaseToken: Value(sealLeaseToken),
            sealOwnerSessionId: Value(sealOwnerSessionId),
            sealLeaseExpiresAt: Value(sealLeaseExpiresAt),
            createdAt: created,
            updatedAt: updatedAt ?? created,
          ),
        );
  }

  Future<void> insertSyncOperation({
    String operationId = _syncOperationId,
    Uint8List? stateDigest,
    String recordId = _syncRecordId,
    String entityType = 'conversation',
    String entityId = 'conversation-1',
    String intentId = _syncIntentId,
    int intentGeneration = 1,
    int expectedRevision = 0,
    String accountUserId = _syncAccountUserId,
    String actorDeviceId = _syncActorDeviceId,
    int claimedWriterKeyVersion = 1,
    String outcome = 'active',
    int? resultRevision,
    int? resultChangeSeq,
    int? currentRevision,
    String? errorCode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) async {
    final created = createdAt ?? DateTime.utc(2026, 7, 27);
    await database
        .into(database.e2eeSyncOperationRows)
        .insert(
          E2eeSyncOperationRowsCompanion.insert(
            operationId: operationId,
            stateDigest: stateDigest ?? _syncDigest(1),
            recordId: recordId,
            entityType: entityType,
            entityId: entityId,
            intentId: intentId,
            intentGeneration: intentGeneration,
            expectedRevision: expectedRevision,
            accountUserId: accountUserId,
            actorDeviceId: actorDeviceId,
            claimedWriterKeyVersion: claimedWriterKeyVersion,
            outcome: outcome,
            resultRevision: Value(resultRevision),
            resultChangeSeq: Value(resultChangeSeq),
            currentRevision: Value(currentRevision),
            errorCode: Value(errorCode),
            createdAt: created,
            updatedAt: updatedAt ?? created,
          ),
        );
  }

  Future<void> insertSyncOutbox({
    String operationId = _syncOperationId,
    String recordId = _syncRecordId,
    int envelopeVersion = 1,
    int keyEpoch = 1,
    Uint8List? ciphertext,
    String phase = 'ready',
    String? leaseToken,
    String? leaseOwnerSessionId,
    DateTime? leaseExpiresAt,
    int transitionVersion = 1,
    int attemptCount = 0,
    DateTime? nextAttemptAt,
    String? lastFailureKind,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) async {
    final created = createdAt ?? DateTime.utc(2026, 7, 27);
    await database
        .into(database.e2eeSyncOutboxRows)
        .insert(
          E2eeSyncOutboxRowsCompanion.insert(
            operationId: operationId,
            recordId: recordId,
            envelopeVersion: envelopeVersion,
            keyEpoch: keyEpoch,
            ciphertext: ciphertext ?? Uint8List.fromList(const [1]),
            phase: phase,
            leaseToken: Value(leaseToken),
            leaseOwnerSessionId: Value(leaseOwnerSessionId),
            leaseExpiresAt: Value(leaseExpiresAt),
            transitionVersion: transitionVersion,
            attemptCount: attemptCount,
            nextAttemptAt: nextAttemptAt ?? created,
            lastFailureKind: Value(lastFailureKind),
            createdAt: created,
            updatedAt: updatedAt ?? created,
          ),
        );
  }

  Future<void> insertSyncRemoteRecord({
    String recordId = _syncRecordId,
    int? revision,
    int? lastChangeSeq,
    Uint8List? stateDigest,
    String gate = 'ready',
    int? observedRevision,
    String? errorCode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) async {
    final created = createdAt ?? DateTime.utc(2026, 7, 27);
    await database
        .into(database.e2eeSyncRemoteRecordRows)
        .insert(
          E2eeSyncRemoteRecordRowsCompanion.insert(
            recordId: recordId,
            revision: Value(revision),
            lastChangeSeq: Value(lastChangeSeq),
            stateDigest: Value(stateDigest),
            gate: gate,
            observedRevision: Value(observedRevision),
            errorCode: Value(errorCode),
            createdAt: created,
            updatedAt: updatedAt ?? created,
          ),
        );
  }

  Future<E2eeSealedAccountRecordState> createCommittedOutbox({
    required int discriminator,
    required DateTime now,
  }) async {
    final entityKey = SyncEntityKey(
      entityType: 'conversation',
      entityId: 'outbox-state-$discriminator',
    );
    await outboxCommands.runLocalWriteAtomically<void>(
      intents: [
        E2eeSyncLocalWriteIntent(
          intentId: _syncUuid(100 + discriminator),
          entityKey: entityKey,
        ),
      ],
      writerSessionId: 'writer-$discriminator',
      now: now,
      write: () async {},
    );
    final refs = await outboxCommands.listDirtyIntents(limit: 10);
    final ref = refs.singleWhere((item) => item.entityKey == entityKey);
    final lease = await outboxCommands.claimSealIntent(
      intent: ref,
      leaseToken: 'seal-token-$discriminator',
      leaseOwner: 'seal-owner-$discriminator',
      leaseExpiresAt: now.add(const Duration(minutes: 1)),
      now: now.add(const Duration(seconds: 2)),
    );
    expect(lease, isA<E2eeSyncSealLease>());
    final recordId = await stateCodec.deriveRecordId(entityKey);
    final plan = await outboxCommands.readSealPlan(
      lease: lease!,
      recordId: recordId,
    );
    final sealed = await stateCodec.sealValue(
      entityKey: entityKey,
      logicalVersion: plan.logicalVersion,
      parentDigests: plan.parentDigests,
      operationId: _syncUuid(200 + discriminator),
      claimedWriterDeviceId: _syncActorDeviceId,
      claimedWriterKeyVersion: 1,
      payload: Uint8List.fromList([discriminator]),
    );
    expect(
      await outboxCommands.commitSealed(
        plan: plan,
        state: sealed,
        accountUserId: _syncAccountUserId,
        actorDeviceId: _syncActorDeviceId,
        now: now.add(const Duration(seconds: 3)),
      ),
      isTrue,
    );
    return sealed;
  }

  group('schema invariants', () {
    test('accepts valid boundary values', () async {
      await insertConversation();
      await insertMessage();
      await database
          .into(database.conversationMcpServerRows)
          .insert(
            ConversationMcpServerRowsCompanion.insert(
              conversationId: 'conversation-1',
              serverId: 'server-1',
              ordinal: 0,
            ),
          );

      expect(await database.select(database.messageRows).get(), hasLength(1));
      expect(
        await database.select(database.conversationMcpServerRows).get(),
        hasLength(1),
      );
    });

    test('rejects orphan messages', () async {
      await expectLater(insertMessage(), throwsRemoteSqliteException());
    });

    test('rejects duplicate order and duplicate group version', () async {
      await insertConversation();
      await insertMessage();

      await expectLater(
        insertMessage(id: 'message-2', groupId: 'group-2', messageOrder: 0),
        throwsRemoteSqliteException(),
      );
      await expectLater(
        insertMessage(id: 'message-3', groupId: 'group-1', messageOrder: 1),
        throwsRemoteSqliteException(),
      );
    });

    test('rejects invalid role and negative numeric fields', () async {
      await insertConversation();

      await expectLater(insertMessage(role: ''), throwsRemoteSqliteException());
      await expectLater(
        insertMessage(id: 'message-2', version: -1),
        throwsRemoteSqliteException(),
      );
      await expectLater(
        insertMessage(id: 'message-3', messageOrder: -1),
        throwsRemoteSqliteException(),
      );
      await expectLater(
        insertMessage(id: 'message-4', totalTokens: -1),
        throwsRemoteSqliteException(),
      );
    });

    test('rejects duplicate MCP ordinal', () async {
      await insertConversation();
      await database
          .into(database.conversationMcpServerRows)
          .insert(
            ConversationMcpServerRowsCompanion.insert(
              conversationId: 'conversation-1',
              serverId: 'server-1',
              ordinal: 0,
            ),
          );

      await expectLater(
        database
            .into(database.conversationMcpServerRows)
            .insert(
              ConversationMcpServerRowsCompanion.insert(
                conversationId: 'conversation-1',
                serverId: 'server-2',
                ordinal: 0,
              ),
            ),
        throwsRemoteSqliteException(),
      );
    });
  });

  group('E2EE verified membership anchor schema', () {
    Future<void> insertAnchor({
      String accountUserId = _syncAccountUserId,
      int manifestLength = 476,
      int digestLength = 32,
      int securityGeneration = 1,
      int keyEpoch = 1,
      int transitionVersion = 1,
      DateTime? createdAt,
      DateTime? updatedAt,
    }) {
      final created = createdAt ?? DateTime.utc(2026, 7, 29);
      return database
          .into(database.e2eeVerifiedMembershipAnchorRows)
          .insert(
            E2eeVerifiedMembershipAnchorRowsCompanion.insert(
              accountUserId: accountUserId,
              membershipManifest: Uint8List(manifestLength),
              membershipManifestDigest: Uint8List(digestLength),
              securityGeneration: securityGeneration,
              keyEpoch: keyEpoch,
              transitionVersion: transitionVersion,
              createdAt: created,
              updatedAt: updatedAt ?? created,
            ),
          );
    }

    test('接受规范大小与整数边界', () async {
      await insertAnchor();
      await insertAnchor(
        accountUserId: _syncUuid(250),
        manifestLength: 22916,
        securityGeneration: 2147483647,
        keyEpoch: 4294967295,
        transitionVersion: 9223372036854775807,
      );

      expect(
        await database.select(database.e2eeVerifiedMembershipAnchorRows).get(),
        hasLength(2),
      );
    });

    test('拒绝非法身份、字节长度、整数和时间关系', () async {
      final createdAt = DateTime.utc(2026, 7, 29);
      final invalidWrites = <Future<void> Function()>[
        () => insertAnchor(
          accountUserId: _syncAccountUserId.replaceFirst('-4000-', '-5000-'),
        ),
        () => insertAnchor(manifestLength: 356),
        () => insertAnchor(manifestLength: 475),
        () => insertAnchor(manifestLength: 477),
        () => insertAnchor(manifestLength: 22917),
        () => insertAnchor(digestLength: 31),
        () => insertAnchor(digestLength: 33),
        () => insertAnchor(securityGeneration: 0),
        () => insertAnchor(securityGeneration: 2147483648),
        () => insertAnchor(keyEpoch: 0),
        () => insertAnchor(keyEpoch: 4294967296),
        () => insertAnchor(transitionVersion: 0),
        () => insertAnchor(
          createdAt: createdAt,
          updatedAt: createdAt.subtract(const Duration(microseconds: 1)),
        ),
      ];
      for (final write in invalidWrites) {
        await expectLater(write(), throwsRemoteSqliteException());
      }
    });

    test('每个账户只允许一个锚点', () async {
      await insertAnchor();
      await expectLater(insertAnchor(), throwsRemoteSqliteException());
    });
  });

  group('E2EE verified membership anchor commands', () {
    test('成员清单 v2 固定授权摘要与成员区偏移', () async {
      const secureCore = KelivoSecureCore();
      final chain = await createMembershipChain();
      addTearDown(() => secureCore.closeAccountRootKey(chain.ark));

      expect(e2eeAccountTrustManifestFormatVersion, 2);
      expect(e2eeAccountTrustManifestMinimumLength, 476);
      expect(e2eeAccountTrustManifestMaximumLength, 22916);
      for (final membership in <E2eeVerifiedMembership>[
        chain.initialized,
        chain.paired,
        chain.resumed,
        chain.replaced,
      ]) {
        final fields = ByteData.sublistView(membership.manifest);
        expect(fields.getUint32(8, Endian.big), 2);
        expect(membership.manifest.sublist(224, 256), everyElement(0));
        expect(fields.getUint32(256, Endian.big), membership.members.length);
        expect(
          membership.manifest.length,
          260 + membership.members.length * 88 + 128,
        );
      }
    });

    test('真实恢复五段成员清单 v2 固定向量保持完整签名链', () async {
      const secureCore = KelivoSecureCore();
      const vectors =
          <
            ({
              String manifestBase64,
              String digestBase64,
              int operationCode,
              String operationId,
              int securityGeneration,
              int keyEpoch,
              String issuerDeviceId,
              String subjectDeviceId,
              String authorizationDigestBase64,
            })
          >[
            (
              manifestBase64: _frozenInitializedManifestV2,
              digestBase64: '05HPAtPXROeSH0q-hR9L3XRc1aQPMF8n05DghrDFUi8=',
              operationCode: 1,
              operationId: _syncOperationId,
              securityGeneration: 1,
              keyEpoch: 1,
              issuerDeviceId: _syncActorDeviceId,
              subjectDeviceId: _syncActorDeviceId,
              authorizationDigestBase64:
                  'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
            ),
            (
              manifestBase64: _frozenPairedManifestV2,
              digestBase64: 'YK_d1CAY4CnUQukssxT6jZCY6sSDyZ3cq3TZTszE0iE=',
              operationCode: 2,
              operationId: '90000000-0000-4000-8000-000000000102',
              securityGeneration: 2,
              keyEpoch: 1,
              issuerDeviceId: _syncActorDeviceId,
              subjectDeviceId: '90000000-0000-4000-8000-000000000101',
              authorizationDigestBase64:
                  'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
            ),
            (
              manifestBase64: _frozenRevokedManifestV2,
              digestBase64: 'G7pb1XYcWVtnnG1lZzHl5UivRPBpekjvxp6qUamvEqo=',
              operationCode: 3,
              operationId: '90000000-0000-4000-8000-000000000105',
              securityGeneration: 3,
              keyEpoch: 2,
              issuerDeviceId: _syncActorDeviceId,
              subjectDeviceId: '90000000-0000-4000-8000-000000000101',
              authorizationDigestBase64:
                  'UVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVE=',
            ),
            (
              manifestBase64: _frozenResumedManifestV2,
              digestBase64: 'KUa5iTtfhjRhHm6HgnOqLdKrcMUeq2D9Y90RygxrnKo=',
              operationCode: 4,
              operationId: '90000000-0000-4000-8000-000000000107',
              securityGeneration: 4,
              keyEpoch: 2,
              issuerDeviceId: '90000000-0000-4000-8000-000000000106',
              subjectDeviceId: '90000000-0000-4000-8000-000000000106',
              authorizationDigestBase64:
                  'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
            ),
            (
              manifestBase64: _frozenReplacedManifestV2,
              digestBase64: 'UTGRh5hTkjhzE9CnK0w8AhTQ2hwbbmPuDN919DL48-4=',
              operationCode: 5,
              operationId: '90000000-0000-4000-8000-000000000108',
              securityGeneration: 5,
              keyEpoch: 3,
              issuerDeviceId: '90000000-0000-4000-8000-000000000106',
              subjectDeviceId: '90000000-0000-4000-8000-000000000106',
              authorizationDigestBase64:
                  'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
            ),
          ];
      Uint8List? previousManifest;
      Uint8List? previousDigest;

      for (final vector in vectors) {
        final manifest = Uint8List.fromList(
          base64Url.decode(vector.manifestBase64),
        );
        final expectedDigest = Uint8List.fromList(
          base64Url.decode(vector.digestBase64),
        );
        final fields = ByteData.sublistView(manifest);
        final memberCount = fields.getUint32(256, Endian.big);
        final payloadLength = 260 + memberCount * 88;
        final payload = Uint8List.sublistView(manifest, 0, payloadLength);
        final transitionSignature = Uint8List.sublistView(
          manifest,
          payloadLength,
          payloadLength + 64,
        );
        final currentSignature = Uint8List.sublistView(
          manifest,
          payloadLength + 64,
        );
        final userId = Uint8List.sublistView(manifest, 12, 28);

        expect(fields.getUint32(8, Endian.big), 2);
        expect(manifest, hasLength(payloadLength + 128));
        expect(
          Uint8List.fromList(sha256.convert(manifest).bytes),
          orderedEquals(expectedDigest),
        );
        expect(
          manifest.sublist(36, 68),
          orderedEquals(previousDigest ?? Uint8List(32)),
        );
        expect(fields.getUint32(172, Endian.big), vector.operationCode);
        expect(fields.getUint32(28, Endian.big), vector.securityGeneration);
        expect(fields.getUint32(32, Endian.big), vector.keyEpoch);
        expect(Uuid.unparse(manifest.sublist(176, 192)), vector.operationId);
        expect(Uuid.unparse(manifest.sublist(192, 208)), vector.issuerDeviceId);
        expect(
          Uuid.unparse(manifest.sublist(208, 224)),
          vector.subjectDeviceId,
        );
        expect(
          manifest.sublist(224, 256),
          orderedEquals(base64Url.decode(vector.authorizationDigestBase64)),
        );
        expect(currentSignature, isNot(everyElement(0)));
        await secureCore.verifyUntrustedAccountTrustPayload(
          KelivoUntrustedAccountTrustPublicKey.fromTransport(
            Uint8List.sublistView(manifest, 68, 100),
          ),
          userId: userId,
          keyEpoch: vector.keyEpoch,
          canonicalPayload: payload,
          signature: KelivoAccountTrustSignature(currentSignature),
        );

        if (vector.operationCode == 3 || vector.operationCode == 5) {
          final trustedPrevious = previousManifest;
          if (trustedPrevious == null) {
            fail('轮换固定向量缺少上一版清单');
          }
          final previousFields = ByteData.sublistView(trustedPrevious);
          expect(transitionSignature, isNot(everyElement(0)));
          await secureCore.verifyUntrustedAccountTrustPayload(
            KelivoUntrustedAccountTrustPublicKey.fromTransport(
              Uint8List.sublistView(trustedPrevious, 68, 100),
            ),
            userId: userId,
            keyEpoch: previousFields.getUint32(32, Endian.big),
            canonicalPayload: payload,
            signature: KelivoAccountTrustSignature(transitionSignature),
          );
        } else {
          expect(transitionSignature, everyElement(0));
        }

        previousManifest = manifest;
        previousDigest = expectedDigest;
      }
    });

    test('协调自撤销摘要进入 op3 双签名载荷且其他操作严格为零', () async {
      const secureCore = KelivoSecureCore();
      const manifestModule = E2eeAccountTrustManifestModule();
      final chain = await createMembershipChain();
      addTearDown(() => secureCore.closeAccountRootKey(chain.ark));
      final expectedAuthorizationDigest = _syncDigest(0x71);
      final authorizationInput = Uint8List.fromList(
        expectedAuthorizationDigest,
      );
      final nextRecoveryCapsule = Uint8List(80)..fillRange(0, 80, 0x72);
      final change = E2eeRevokeRotateMembershipChange(
        previous: chain.paired,
        operationId: _syncUuid(338),
        issuerDeviceId: _syncUuid(101),
        revokedDeviceId: _syncActorDeviceId,
        nextRecoveryCapsuleVersion: 2,
        nextRecoveryCapsule: nextRecoveryCapsule,
        operationAuthorizationDigest: authorizationInput,
      );
      authorizationInput[0] ^= 0xff;
      change.operationAuthorizationDigest[1] ^= 0xff;

      final coordinated = await manifestModule.create(
        ark: chain.ark,
        change: change,
      );

      expect(
        coordinated.operationAuthorizationDigest,
        orderedEquals(expectedAuthorizationDigest),
      );
      coordinated.operationAuthorizationDigest[2] ^= 0xff;
      expect(
        coordinated.operationAuthorizationDigest,
        orderedEquals(expectedAuthorizationDigest),
      );
      expect(
        coordinated.manifest.sublist(224, 256),
        orderedEquals(expectedAuthorizationDigest),
      );
      final verified = await manifestModule.verifyHistoryBatch(
        previous: chain.paired,
        entries: <E2eeMembershipHistoryEntry>[
          E2eeMembershipHistoryEntry(
            manifest: coordinated.manifest,
            manifestDigest: coordinated.digest,
          ),
        ],
      );
      expect(
        verified.operationAuthorizationDigest,
        orderedEquals(expectedAuthorizationDigest),
      );
      final projection = E2eeMembershipServerProjection(
        userId: coordinated.userId,
        securityGeneration: coordinated.securityGeneration,
        keyEpoch: coordinated.keyEpoch,
        membershipManifestVersion: e2eeAccountTrustManifestFormatVersion,
        membershipManifest: coordinated.manifest,
        membershipManifestDigest: coordinated.digest,
        recoveryPublicKeyVersion: coordinated.recoveryPublicKeyVersion,
        recoveryPublicKey: coordinated.recoveryPublicKey,
        recoveryCapsuleVersion: coordinated.recoveryCapsuleVersion,
        recoveryCapsule: nextRecoveryCapsule,
        lastOperationId: coordinated.operationId,
        dataRekeyPhase: E2eeDataRekeyPhase.rekeyPending,
      );
      final expected = E2eeRevokeRotateMembershipExpectation(
        projection: projection,
        previous: chain.paired,
        operationId: coordinated.operationId,
        issuerDeviceId: coordinated.issuerDeviceId,
        revokedDeviceId: coordinated.subjectDeviceId,
        operationAuthorizationDigest: expectedAuthorizationDigest,
      );
      expect(
        (await manifestModule.verify(
          ark: chain.ark,
          expectation: expected,
        )).digest,
        orderedEquals(coordinated.digest),
      );
      await expectLater(
        manifestModule.verify(
          ark: chain.ark,
          expectation: E2eeRevokeRotateMembershipExpectation(
            projection: projection,
            previous: chain.paired,
            operationId: coordinated.operationId,
            issuerDeviceId: coordinated.issuerDeviceId,
            revokedDeviceId: coordinated.subjectDeviceId,
            operationAuthorizationDigest: _syncDigest(0x72),
          ),
        ),
        throwsStateError,
      );

      final tamperedAuthorization = Uint8List.fromList(coordinated.manifest)
        ..[224] ^= 0xff;
      await expectLater(
        manifestModule.verifyHistoryBatch(
          previous: chain.paired,
          entries: <E2eeMembershipHistoryEntry>[
            E2eeMembershipHistoryEntry(
              manifest: tamperedAuthorization,
              manifestDigest: Uint8List.fromList(
                sha256.convert(tamperedAuthorization).bytes,
              ),
            ),
          ],
        ),
        throwsA(isA<KelivoSecureCoreException>()),
      );
      final nonRevokeAuthorization = Uint8List.fromList(chain.paired.manifest)
        ..[224] = 1;
      await expectLater(
        manifestModule.verifyHistoryBatch(
          previous: chain.initialized,
          entries: <E2eeMembershipHistoryEntry>[
            E2eeMembershipHistoryEntry(
              manifest: nonRevokeAuthorization,
              manifestDigest: Uint8List.fromList(
                sha256.convert(nonRevokeAuthorization).bytes,
              ),
            ),
          ],
        ),
        throwsFormatException,
      );
      expect(
        () => E2eeRevokeRotateMembershipChange(
          previous: chain.paired,
          operationId: _syncUuid(339),
          issuerDeviceId: _syncUuid(101),
          revokedDeviceId: _syncActorDeviceId,
          nextRecoveryCapsuleVersion: 2,
          nextRecoveryCapsule: Uint8List(80)..fillRange(0, 80, 0x73),
          operationAuthorizationDigest: Uint8List(32),
        ),
        throwsArgumentError,
      );
    });

    test('已验证清单安装、重启验签、推进与响应丢失重放闭环', () async {
      const secureCore = KelivoSecureCore();
      const manifestModule = E2eeAccountTrustManifestModule();
      final chain = await createMembershipChain();
      addTearDown(() => secureCore.closeAccountRootKey(chain.ark));
      var commands = repository.e2eeVerifiedMembershipAnchorCommands;
      final installed = await commands.install(
        membership: chain.initialized,
        now: DateTime.utc(2026, 7, 29),
      );
      expect(installed.transitionVersion, 1);
      final installedReplay = await commands.install(
        membership: chain.initialized,
        now: DateTime.utc(2026, 7, 29, 0, 0, 1),
      );
      expect(installedReplay.transitionVersion, 1);
      expect(installedReplay.createdAt, installed.createdAt);
      expect(installedReplay.updatedAt, installed.updatedAt);

      await repository.close();
      database = AppDatabase.open(
        file: File('${directory.path}/constraints.sqlite'),
        cipher: testDatabaseCipher,
      );
      await database.customSelect('SELECT 1;').getSingle();
      repository = ChatDatabaseRepository(
        database,
        databaseCipher: testDatabaseCipher,
      );
      commands = repository.e2eeVerifiedMembershipAnchorCommands;

      final reopened = await commands.readVerified(
        accountUserId: _syncAccountUserId,
        ark: chain.ark,
      );
      expect(reopened, isA<E2eeLocallyVerifiedMembershipAnchor>());
      expect(
        reopened!.membership.digest,
        orderedEquals(chain.initialized.digest),
      );
      expect(reopened.transitionVersion, 1);

      final advanced = await commands.advance(
        expected: reopened,
        next: chain.paired,
        now: DateTime.utc(2026, 7, 29, 0, 0, 1),
      );
      expect(advanced.membership.digest, orderedEquals(chain.paired.digest));
      expect(advanced.transitionVersion, 2);

      final replayed = await commands.advance(
        expected: reopened,
        next: chain.paired,
        now: DateTime.utc(2026, 7, 29, 0, 0, 2),
      );
      expect(replayed.transitionVersion, 2);
      expect(replayed.updatedAt, advanced.updatedAt);

      final revoked = await commands.advance(
        expected: advanced,
        next: chain.revoked,
        now: DateTime.utc(2026, 7, 29, 0, 0, 3),
      );
      expect(revoked.membership.keyEpoch, 2);
      expect(revoked.membership.digest, orderedEquals(chain.revoked.digest));
      expect(revoked.transitionVersion, 3);

      await repository.close();
      database = AppDatabase.open(
        file: File('${directory.path}/constraints.sqlite'),
        cipher: testDatabaseCipher,
      );
      await database.customSelect('SELECT 1;').getSingle();
      repository = ChatDatabaseRepository(
        database,
        databaseCipher: testDatabaseCipher,
      );
      final reopenedRevoked = await repository
          .e2eeVerifiedMembershipAnchorCommands
          .readVerified(accountUserId: _syncAccountUserId, ark: chain.ark);
      expect(reopenedRevoked!.transitionVersion, 3);
      expect(
        reopenedRevoked.membership.digest,
        orderedEquals(chain.revoked.digest),
      );
      final unanchoredRecoveryDevice = await _newDatabaseMembershipDevice(
        secureCore,
        deviceId: _syncUuid(109),
        authGeneration: 1,
      );
      await expectLater(
        manifestModule.create(
          ark: chain.ark,
          change: E2eeRecoverResumeMembershipChange(
            previous: reopenedRevoked.membership,
            operationId: _syncUuid(110),
            subject: unanchoredRecoveryDevice,
          ),
        ),
        throwsStateError,
      );

      final resumed = await repository.e2eeVerifiedMembershipAnchorCommands
          .advance(
            expected: reopenedRevoked,
            next: chain.resumed,
            now: DateTime.utc(2026, 7, 29, 0, 0, 4),
          );
      expect(resumed.transitionVersion, 4);
      expect(resumed.membership.keyEpoch, 2);
      final replaced = await repository.e2eeVerifiedMembershipAnchorCommands
          .advance(
            expected: resumed,
            next: chain.replaced,
            now: DateTime.utc(2026, 7, 29, 0, 0, 5),
          );
      expect(replaced.transitionVersion, 5);
      expect(replaced.membership.keyEpoch, 3);

      await repository.close();
      database = AppDatabase.open(
        file: File('${directory.path}/constraints.sqlite'),
        cipher: testDatabaseCipher,
      );
      await database.customSelect('SELECT 1;').getSingle();
      repository = ChatDatabaseRepository(
        database,
        databaseCipher: testDatabaseCipher,
      );
      final reopenedReplaced = await repository
          .e2eeVerifiedMembershipAnchorCommands
          .readVerified(accountUserId: _syncAccountUserId, ark: chain.ark);
      expect(reopenedReplaced!.transitionVersion, 5);
      expect(
        reopenedReplaced.membership.digest,
        orderedEquals(chain.replaced.digest),
      );
    });

    test('现有锚点拒绝覆盖、非后继与陈旧分叉', () async {
      const secureCore = KelivoSecureCore();
      const manifestModule = E2eeAccountTrustManifestModule();
      final chain = await createMembershipChain();
      addTearDown(() => secureCore.closeAccountRootKey(chain.ark));
      final commands = repository.e2eeVerifiedMembershipAnchorCommands;
      final installed = await commands.install(
        membership: chain.initialized,
        now: DateTime.utc(2026, 7, 29),
      );

      await expectLater(
        commands.install(
          membership: chain.paired,
          now: DateTime.utc(2026, 7, 29, 0, 0, 1),
        ),
        throwsA(isA<E2eeVerifiedMembershipAnchorConflict>()),
      );
      expect(
        () => commands.advance(
          expected: installed,
          next: chain.initialized,
          now: DateTime.utc(2026, 7, 29, 0, 0, 1),
        ),
        throwsFormatException,
      );

      await commands.advance(
        expected: installed,
        next: chain.paired,
        now: DateTime.utc(2026, 7, 29, 0, 0, 1),
      );
      final alternativeSubject = await _newDatabaseMembershipDevice(
        secureCore,
        deviceId: _syncUuid(103),
        authGeneration: 1,
      );
      final alternative = await manifestModule.create(
        ark: chain.ark,
        change: E2eeAddDeviceMembershipChange(
          previous: chain.initialized,
          pairingId: _syncUuid(104),
          issuerDeviceId: _syncActorDeviceId,
          subject: alternativeSubject,
        ),
      );
      await expectLater(
        commands.advance(
          expected: installed,
          next: alternative,
          now: DateTime.utc(2026, 7, 29, 0, 0, 2),
        ),
        throwsA(isA<E2eeVerifiedMembershipAnchorStale>()),
      );
    });

    test('双连接安装与相同推进精确幂等且能力不可跨连接', () async {
      const secureCore = KelivoSecureCore();
      final chain = await createMembershipChain();
      addTearDown(() => secureCore.closeAccountRootKey(chain.ark));
      final secondDatabase = AppDatabase.open(
        file: File('${directory.path}/constraints.sqlite'),
        cipher: testDatabaseCipher,
      );
      await secondDatabase.customSelect('SELECT 1;').getSingle();
      final secondRepository = ChatDatabaseRepository(
        secondDatabase,
        databaseCipher: testDatabaseCipher,
      );
      try {
        final firstCommands = repository.e2eeVerifiedMembershipAnchorCommands;
        final secondCommands =
            secondRepository.e2eeVerifiedMembershipAnchorCommands;
        final installed =
            await Future.wait(<Future<E2eeLocallyVerifiedMembershipAnchor>>[
              firstCommands.install(
                membership: chain.initialized,
                now: DateTime.utc(2026, 7, 29),
              ),
              secondCommands.install(
                membership: chain.initialized,
                now: DateTime.utc(2026, 7, 29),
              ),
            ]);
        expect(
          installed.map((anchor) => anchor.transitionVersion),
          everyElement(1),
        );
        expect(
          () => secondCommands.advance(
            expected: installed.first,
            next: chain.paired,
            now: DateTime.utc(2026, 7, 29, 0, 0, 1),
          ),
          throwsA(isA<E2eeVerifiedMembershipAnchorStale>()),
        );

        final secondExpected = await secondCommands.readVerified(
          accountUserId: _syncAccountUserId,
          ark: chain.ark,
        );
        final advanced =
            await Future.wait(<Future<E2eeLocallyVerifiedMembershipAnchor>>[
              firstCommands.advance(
                expected: installed.first,
                next: chain.paired,
                now: DateTime.utc(2026, 7, 29, 0, 0, 1),
              ),
              secondCommands.advance(
                expected: secondExpected!,
                next: chain.paired,
                now: DateTime.utc(2026, 7, 29, 0, 0, 1),
              ),
            ]);
        expect(
          advanced.map((anchor) => anchor.transitionVersion),
          everyElement(2),
        );
        expect(advanced.first.updatedAt, advanced.last.updatedAt);
        expect(
          advanced.map((anchor) => anchor.membership.digest),
          everyElement(orderedEquals(chain.paired.digest)),
        );
      } finally {
        await secondRepository.close();
      }
    });

    test('推进拒绝已耗尽的本地 transitionVersion', () async {
      const secureCore = KelivoSecureCore();
      final chain = await createMembershipChain();
      addTearDown(() => secureCore.closeAccountRootKey(chain.ark));
      final commands = repository.e2eeVerifiedMembershipAnchorCommands;
      await commands.install(
        membership: chain.initialized,
        now: DateTime.utc(2026, 7, 29),
      );
      await database
          .update(database.e2eeVerifiedMembershipAnchorRows)
          .write(
            const E2eeVerifiedMembershipAnchorRowsCompanion(
              transitionVersion: Value(9223372036854775807),
            ),
          );
      final exhausted = await commands.readVerified(
        accountUserId: _syncAccountUserId,
        ark: chain.ark,
      );
      expect(
        () => commands.advance(
          expected: exhausted!,
          next: chain.paired,
          now: DateTime.utc(2026, 7, 29, 0, 0, 1),
        ),
        throwsStateError,
      );
    });

    test('读取拒绝摘要与当前 ARK 签名篡改', () async {
      const secureCore = KelivoSecureCore();
      final chain = await createMembershipChain();
      addTearDown(() => secureCore.closeAccountRootKey(chain.ark));
      final commands = repository.e2eeVerifiedMembershipAnchorCommands;
      await commands.install(
        membership: chain.initialized,
        now: DateTime.utc(2026, 7, 29),
      );

      await database
          .update(database.e2eeVerifiedMembershipAnchorRows)
          .write(
            E2eeVerifiedMembershipAnchorRowsCompanion(
              membershipManifestDigest: Value(Uint8List(32)..[0] = 1),
            ),
          );
      await expectLater(
        commands.readVerified(
          accountUserId: _syncAccountUserId,
          ark: chain.ark,
        ),
        throwsStateError,
      );

      final tamperedManifest = Uint8List.fromList(chain.initialized.manifest)
        ..[chain.initialized.manifest.length - 1] ^= 1;
      await database
          .update(database.e2eeVerifiedMembershipAnchorRows)
          .write(
            E2eeVerifiedMembershipAnchorRowsCompanion(
              membershipManifest: Value(tamperedManifest),
              membershipManifestDigest: Value(
                Uint8List.fromList(sha256.convert(tamperedManifest).bytes),
              ),
            ),
          );
      await expectLater(
        commands.readVerified(
          accountUserId: _syncAccountUserId,
          ark: chain.ark,
        ),
        throwsA(isA<KelivoSecureCoreException>()),
      );
    });
  });

  group('E2EE data-rekey 持久日志', () {
    E2eeDataRekeyOperationBinding binding({
      String? operationId,
      int sourceDataGeneration = 4,
      int sourceKeyEpoch = 7,
      int targetKeyEpoch = 8,
      int sourceRecordCount = 2,
      int sourceAttachmentCount = 1,
      int sourceMaximumChangeSeq = 33,
      int membershipGeneration = 12,
      Uint8List? membershipManifestDigest,
    }) => E2eeDataRekeyOperationBinding(
      userId: _syncAccountUserId,
      issuerDeviceId: _syncActorDeviceId,
      operationId: operationId ?? _syncUuid(301),
      sourceDataGeneration: sourceDataGeneration,
      sourceKeyEpoch: sourceKeyEpoch,
      targetKeyEpoch: targetKeyEpoch,
      sourceRecordCount: sourceRecordCount,
      sourceAttachmentCount: sourceAttachmentCount,
      sourceMaximumChangeSeq: sourceMaximumChangeSeq,
      sourceRecordCursorEnd: sourceRecordCount == 0 ? null : _syncUuid(302),
      sourceAttachmentIdEnd: sourceAttachmentCount == 0 ? null : _syncUuid(303),
      sourceAttachmentUploadIdEnd: sourceAttachmentCount == 0
          ? null
          : _syncUuid(304),
      membershipGeneration: membershipGeneration,
      membershipManifestDigest: membershipManifestDigest ?? _syncDigest(9),
    );

    test('租约意图在重复调用与数据库重开后复用随机身份', () async {
      final operationBinding = binding();
      final first = await dataRekeyCommands.ensureClaimIntent(
        binding: operationBinding,
        now: DateTime.utc(2026, 7, 30, 4),
      );
      final repeated = await dataRekeyCommands.ensureClaimIntent(
        binding: operationBinding,
        now: DateTime.utc(2026, 7, 30, 4, 1),
      );

      expect(first.phase, E2eeDataRekeyJournalPhase.claimPending);
      expect(first.leaseToken, hasLength(36));
      expect(first.leaseMutationId, hasLength(36));
      expect(first.leaseToken, isNot(first.leaseMutationId));
      expect(repeated.leaseToken, first.leaseToken);
      expect(repeated.leaseMutationId, first.leaseMutationId);
      expect(repeated.binding, operationBinding);

      await repository.close();
      database = AppDatabase.open(
        file: File('${directory.path}/constraints.sqlite'),
        cipher: testDatabaseCipher,
      );
      await database.customSelect('SELECT 1;').getSingle();
      repository = ChatDatabaseRepository(
        database,
        databaseCipher: testDatabaseCipher,
      );
      dataRekeyCommands = repository.e2eeDataRekeyCommands;

      final reopened = await dataRekeyCommands.ensureClaimIntent(
        binding: operationBinding,
        now: DateTime.utc(2026, 7, 30, 4, 2),
      );
      expect(reopened.leaseToken, first.leaseToken);
      expect(reopened.leaseMutationId, first.leaseMutationId);
      expect(reopened.binding, operationBinding);
    });

    test('租约回执和执行阶段耐久推进且重复回执不回退', () async {
      final operationBinding = binding();
      final intent = await dataRekeyCommands.ensureClaimIntent(
        binding: operationBinding,
        now: DateTime.utc(2026, 7, 30, 4),
      );
      final expiresAt = DateTime.utc(2026, 7, 30, 4, 10);
      final leased = await dataRekeyCommands.recordLeaseClaim(
        operationId: operationBinding.operationId,
        leaseToken: intent.leaseToken,
        leaseVersion: 3,
        leaseExpiresAt: expiresAt,
        now: DateTime.utc(2026, 7, 30, 4, 1),
      );
      expect(leased.phase, E2eeDataRekeyJournalPhase.leased);
      expect(leased.leaseVersion, 3);
      expect(leased.leaseExpiresAt, expiresAt);

      await dataRekeyCommands.advancePhase(
        operationId: operationBinding.operationId,
        leaseToken: intent.leaseToken,
        leaseVersion: 3,
        phase: E2eeDataRekeyJournalPhase.staging,
        now: DateTime.utc(2026, 7, 30, 4, 2),
      );
      final replayed = await dataRekeyCommands.recordLeaseClaim(
        operationId: operationBinding.operationId,
        leaseToken: intent.leaseToken,
        leaseVersion: 3,
        leaseExpiresAt: expiresAt,
        now: DateTime.utc(2026, 7, 30, 4, 3),
      );
      expect(replayed.phase, E2eeDataRekeyJournalPhase.staging);

      await repository.close();
      database = AppDatabase.open(
        file: File('${directory.path}/constraints.sqlite'),
        cipher: testDatabaseCipher,
      );
      await database.customSelect('SELECT 1;').getSingle();
      repository = ChatDatabaseRepository(
        database,
        databaseCipher: testDatabaseCipher,
      );
      dataRekeyCommands = repository.e2eeDataRekeyCommands;

      final reopened = await dataRekeyCommands.readActive();
      expect(reopened?.phase, E2eeDataRekeyJournalPhase.staging);
      expect(reopened?.leaseToken, intent.leaseToken);
      expect(reopened?.leaseVersion, 3);
      expect(reopened?.leaseExpiresAt, expiresAt);
    });

    test('续租只接受同一令牌的单调版本和到期时间', () async {
      final operationBinding = binding();
      final intent = await dataRekeyCommands.ensureClaimIntent(
        binding: operationBinding,
        now: DateTime.utc(2026, 7, 30, 4),
      );
      final firstExpiry = DateTime.utc(2026, 7, 30, 4, 10);
      await dataRekeyCommands.recordLeaseClaim(
        operationId: operationBinding.operationId,
        leaseToken: intent.leaseToken,
        leaseVersion: 3,
        leaseExpiresAt: firstExpiry,
        now: DateTime.utc(2026, 7, 30, 4, 1),
      );

      final renewed = await dataRekeyCommands.recordLeaseClaim(
        operationId: operationBinding.operationId,
        leaseToken: intent.leaseToken,
        leaseVersion: 4,
        leaseExpiresAt: DateTime.utc(2026, 7, 30, 4, 20),
        now: DateTime.utc(2026, 7, 30, 4, 11),
      );
      expect(renewed.leaseVersion, 4);
      expect(renewed.leaseExpiresAt, DateTime.utc(2026, 7, 30, 4, 20));

      final invalidReceipts = <Future<E2eeDataRekeyJournalState> Function()>[
        () => dataRekeyCommands.recordLeaseClaim(
          operationId: operationBinding.operationId,
          leaseToken: _syncUuid(399),
          leaseVersion: 5,
          leaseExpiresAt: DateTime.utc(2026, 7, 30, 4, 30),
          now: DateTime.utc(2026, 7, 30, 4, 21),
        ),
        () => dataRekeyCommands.recordLeaseClaim(
          operationId: operationBinding.operationId,
          leaseToken: intent.leaseToken,
          leaseVersion: 3,
          leaseExpiresAt: DateTime.utc(2026, 7, 30, 4, 30),
          now: DateTime.utc(2026, 7, 30, 4, 21),
        ),
        () => dataRekeyCommands.recordLeaseClaim(
          operationId: operationBinding.operationId,
          leaseToken: intent.leaseToken,
          leaseVersion: 4,
          leaseExpiresAt: firstExpiry,
          now: DateTime.utc(2026, 7, 30, 4, 21),
        ),
      ];
      for (final invalidReceipt in invalidReceipts) {
        await expectLater(invalidReceipt(), throwsStateError);
      }
    });

    test('完成清理只接受 finalizing 阶段的完整租约身份', () async {
      final operationBinding = binding();
      final intent = await dataRekeyCommands.ensureClaimIntent(
        binding: operationBinding,
        now: DateTime.utc(2026, 7, 30, 4),
      );
      await dataRekeyCommands.recordLeaseClaim(
        operationId: operationBinding.operationId,
        leaseToken: intent.leaseToken,
        leaseVersion: 1,
        leaseExpiresAt: DateTime.utc(2026, 7, 30, 4, 10),
        now: DateTime.utc(2026, 7, 30, 4, 1),
      );
      await expectLater(
        dataRekeyCommands.complete(
          operationId: operationBinding.operationId,
          leaseToken: intent.leaseToken,
          leaseVersion: 1,
        ),
        throwsStateError,
      );
      await dataRekeyCommands.advancePhase(
        operationId: operationBinding.operationId,
        leaseToken: intent.leaseToken,
        leaseVersion: 1,
        phase: E2eeDataRekeyJournalPhase.finalizing,
        now: DateTime.utc(2026, 7, 30, 4, 2),
      );
      await expectLater(
        dataRekeyCommands.complete(
          operationId: operationBinding.operationId,
          leaseToken: intent.leaseToken,
          leaseVersion: 2,
        ),
        throwsStateError,
      );

      await dataRekeyCommands.complete(
        operationId: operationBinding.operationId,
        leaseToken: intent.leaseToken,
        leaseVersion: 1,
      );
      expect(await dataRekeyCommands.readActive(), equals(null));
    });

    test('零记录边界有效且成员摘要不暴露可变底层字节', () {
      final sourceDigest = _syncDigest(19);
      final operationBinding = binding(
        sourceRecordCount: 0,
        sourceAttachmentCount: 0,
        membershipManifestDigest: sourceDigest,
      );
      final expectedDigest = Uint8List.fromList(sourceDigest);

      sourceDigest[0] ^= 0xff;
      final exposedDigest = operationBinding.membershipManifestDigest;
      expect(() => exposedDigest[1] ^= 0xff, throwsUnsupportedError);

      expect(operationBinding.sourceRecordCursorEnd, equals(null));
      expect(operationBinding.sourceAttachmentIdEnd, equals(null));
      expect(operationBinding.sourceAttachmentUploadIdEnd, equals(null));
      expect(operationBinding.membershipManifestDigest, expectedDigest);
    });

    test('拒绝非相邻密钥世代与错误摘要长度', () {
      expect(() => binding(targetKeyEpoch: 9), throwsA(isA<FormatException>()));
      expect(
        () => binding(membershipManifestDigest: Uint8List(31)),
        throwsA(isA<FormatException>()),
      );
    });

    test('拒绝无法完成的数据代次与超出同步协议的水位', () {
      expect(
        () => binding(sourceDataGeneration: 2147483647),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => binding(sourceMaximumChangeSeq: 9007199254740992),
        throwsA(isA<FormatException>()),
      );

      final maximum = binding(
        sourceDataGeneration: 2147483646,
        sourceMaximumChangeSeq: 9007199254740991,
      );
      expect(maximum.sourceDataGeneration, 2147483646);
      expect(maximum.sourceMaximumChangeSeq, 9007199254740991);
    });

    test('数据库拒绝无法生成下一代的数据代次', () async {
      final operationBinding = binding(sourceDataGeneration: 2147483646);
      await expectLater(
        database
            .into(database.e2eeDataRekeyOperationRows)
            .insert(
              E2eeDataRekeyOperationRowsCompanion.insert(
                userId: operationBinding.userId,
                issuerDeviceId: operationBinding.issuerDeviceId,
                operationId: operationBinding.operationId,
                sourceDataGeneration: 2147483647,
                sourceKeyEpoch: operationBinding.sourceKeyEpoch,
                targetKeyEpoch: operationBinding.targetKeyEpoch,
                sourceRecordCount: operationBinding.sourceRecordCount,
                sourceAttachmentCount: operationBinding.sourceAttachmentCount,
                sourceMaximumChangeSeq: operationBinding.sourceMaximumChangeSeq,
                sourceRecordCursorEnd: Value(
                  operationBinding.sourceRecordCursorEnd,
                ),
                sourceAttachmentIdEnd: Value(
                  operationBinding.sourceAttachmentIdEnd,
                ),
                sourceAttachmentUploadIdEnd: Value(
                  operationBinding.sourceAttachmentUploadIdEnd,
                ),
                membershipGeneration: operationBinding.membershipGeneration,
                membershipManifestDigest:
                    operationBinding.membershipManifestDigest,
                phase: E2eeDataRekeyJournalPhase.claimPending.wireValue,
                leaseToken: _syncUuid(306),
                leaseMutationId: _syncUuid(307),
                createdAt: DateTime.utc(2026, 7, 30, 4),
                updatedAt: DateTime.utc(2026, 7, 30, 4),
              ),
            ),
        throwsRemoteSqliteException(),
      );
    });

    test('数据库拒绝超出同步协议的变更水位', () async {
      final operationBinding = binding(
        sourceMaximumChangeSeq: 9007199254740991,
      );
      await expectLater(
        database
            .into(database.e2eeDataRekeyOperationRows)
            .insert(
              E2eeDataRekeyOperationRowsCompanion.insert(
                userId: operationBinding.userId,
                issuerDeviceId: operationBinding.issuerDeviceId,
                operationId: operationBinding.operationId,
                sourceDataGeneration: operationBinding.sourceDataGeneration,
                sourceKeyEpoch: operationBinding.sourceKeyEpoch,
                targetKeyEpoch: operationBinding.targetKeyEpoch,
                sourceRecordCount: operationBinding.sourceRecordCount,
                sourceAttachmentCount: operationBinding.sourceAttachmentCount,
                sourceMaximumChangeSeq: 9007199254740992,
                sourceRecordCursorEnd: Value(
                  operationBinding.sourceRecordCursorEnd,
                ),
                sourceAttachmentIdEnd: Value(
                  operationBinding.sourceAttachmentIdEnd,
                ),
                sourceAttachmentUploadIdEnd: Value(
                  operationBinding.sourceAttachmentUploadIdEnd,
                ),
                membershipGeneration: operationBinding.membershipGeneration,
                membershipManifestDigest:
                    operationBinding.membershipManifestDigest,
                phase: E2eeDataRekeyJournalPhase.claimPending.wireValue,
                leaseToken: _syncUuid(306),
                leaseMutationId: _syncUuid(307),
                createdAt: DateTime.utc(2026, 7, 30, 4),
                updatedAt: DateTime.utc(2026, 7, 30, 4),
              ),
            ),
        throwsRemoteSqliteException(),
      );
    });

    test('同一 operation 绑定漂移时失败关闭并保留原重试身份', () async {
      final original = binding();
      final first = await dataRekeyCommands.ensureClaimIntent(
        binding: original,
        now: DateTime.utc(2026, 7, 30, 4),
      );

      await expectLater(
        dataRekeyCommands.ensureClaimIntent(
          binding: binding(membershipGeneration: 13),
          now: DateTime.utc(2026, 7, 30, 4, 1),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'data_rekey_operation_binding_changed',
          ),
        ),
      );

      final retained = await dataRekeyCommands.ensureClaimIntent(
        binding: original,
        now: DateTime.utc(2026, 7, 30, 4, 2),
      );
      expect(retained.leaseToken, first.leaseToken);
      expect(retained.leaseMutationId, first.leaseMutationId);
    });

    test('旧 operation 未显式完成前拒绝新 operation', () async {
      final original = binding();
      final first = await dataRekeyCommands.ensureClaimIntent(
        binding: original,
        now: DateTime.utc(2026, 7, 30, 4),
      );

      await expectLater(
        dataRekeyCommands.ensureClaimIntent(
          binding: binding(operationId: _syncUuid(305)),
          now: DateTime.utc(2026, 7, 30, 4, 1),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'data_rekey_operation_in_progress',
          ),
        ),
      );

      final retained = await dataRekeyCommands.ensureClaimIntent(
        binding: original,
        now: DateTime.utc(2026, 7, 30, 4, 2),
      );
      expect(retained.leaseToken, first.leaseToken);
      expect(retained.leaseMutationId, first.leaseMutationId);
    });

    test('数据库拒绝租约令牌与声明变更标识复用', () async {
      final operationBinding = binding();
      await dataRekeyCommands.ensureClaimIntent(
        binding: operationBinding,
        now: DateTime.utc(2026, 7, 30, 4),
      );

      await expectLater(
        database.customStatement(
          'UPDATE e2ee_data_rekey_operation_rows '
          'SET lease_mutation_id = lease_token;',
        ),
        throwsRemoteSqliteException(),
      );
    });

    test('恢复读取拒绝租约令牌与声明变更标识复用', () async {
      final operationBinding = binding();
      await dataRekeyCommands.ensureClaimIntent(
        binding: operationBinding,
        now: DateTime.utc(2026, 7, 30, 4),
      );
      await database.customStatement('PRAGMA ignore_check_constraints = ON;');
      try {
        await database.customStatement(
          'UPDATE e2ee_data_rekey_operation_rows '
          'SET lease_mutation_id = lease_token;',
        );
      } finally {
        await database.customStatement(
          'PRAGMA ignore_check_constraints = OFF;',
        );
      }

      await expectLater(
        dataRekeyCommands.ensureClaimIntent(
          binding: operationBinding,
          now: DateTime.utc(2026, 7, 30, 4, 1),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'data_rekey_lease_identity_reused',
          ),
        ),
      );
    });

    test('数据库拒绝未持租约却进入执行阶段的日志', () async {
      final operationBinding = binding();
      await expectLater(
        database
            .into(database.e2eeDataRekeyOperationRows)
            .insert(
              E2eeDataRekeyOperationRowsCompanion.insert(
                userId: operationBinding.userId,
                issuerDeviceId: operationBinding.issuerDeviceId,
                operationId: operationBinding.operationId,
                sourceDataGeneration: operationBinding.sourceDataGeneration,
                sourceKeyEpoch: operationBinding.sourceKeyEpoch,
                targetKeyEpoch: operationBinding.targetKeyEpoch,
                sourceRecordCount: operationBinding.sourceRecordCount,
                sourceAttachmentCount: operationBinding.sourceAttachmentCount,
                sourceMaximumChangeSeq: operationBinding.sourceMaximumChangeSeq,
                sourceRecordCursorEnd: Value(
                  operationBinding.sourceRecordCursorEnd,
                ),
                sourceAttachmentIdEnd: Value(
                  operationBinding.sourceAttachmentIdEnd,
                ),
                sourceAttachmentUploadIdEnd: Value(
                  operationBinding.sourceAttachmentUploadIdEnd,
                ),
                membershipGeneration: operationBinding.membershipGeneration,
                membershipManifestDigest:
                    operationBinding.membershipManifestDigest,
                phase: E2eeDataRekeyJournalPhase.leased.wireValue,
                leaseToken: _syncUuid(306),
                leaseMutationId: _syncUuid(307),
                createdAt: DateTime.utc(2026, 7, 30, 4),
                updatedAt: DateTime.utc(2026, 7, 30, 4),
              ),
            ),
        throwsRemoteSqliteException(),
      );
    });
  });

  group('E2EE data-rekey 执行器', () {
    test('跨请求完成空源换代且仅在本地确认后清理耐久状态', () async {
      final operationId = _syncUuid(320);
      final transport = _ZeroSourceDataRekeyTransport(
        userId: _syncAccountUserId,
        issuerDeviceId: _syncActorDeviceId,
        operationId: operationId,
      );
      final cryptography = _ZeroSourceDataRekeyCryptography();
      final stageStore = E2eeDataRekeyStageStore(
        installationRoot: await Directory(
          '${directory.path}/data-rekey',
        ).create(),
      );
      final context = E2eeDataRekeyExecutionContext(
        baseUrl: 'https://kelivo.bemylover.top',
        loginName: 'owner',
        userId: _syncAccountUserId,
        issuerDeviceId: _syncActorDeviceId,
        membershipGeneration: 12,
        membershipManifestDigest: _syncDigest(9),
      );
      final executor = E2eeDataRekeyExecutor(
        transport: transport,
        journal: dataRekeyCommands,
        stageStore: stageStore,
        cryptography: cryptography,
        clock: () => DateTime.utc(2026, 7, 30, 5),
      );

      final execution = await executor.execute(context);

      expect(execution, isNot(equals(null)));
      expect(execution!.result.dataGeneration, 5);
      expect(transport.finalizeRequests, hasLength(2));
      expect(
        transport.finalizeRequests[1].mutationId,
        transport.finalizeRequests[0].mutationId,
      );
      expect(
        transport.finalizeRequests[1].proof.signature,
        transport.finalizeRequests[0].proof.signature,
      );
      expect(cryptography.signatureCount, 1);
      expect(
        (await dataRekeyCommands.readActive())?.phase,
        E2eeDataRekeyJournalPhase.finalizing,
      );
      expect(
        await stageStore.listArtifactIds(
          normalizedBaseUrl: context.normalizedBaseUrl,
          normalizedLoginName: context.normalizedLoginName,
          operationId: operationId,
          maximumCount: 1,
        ),
        hasLength(1),
      );

      final confirmation = await executor.confirmReady(
        context: context,
        execution: execution,
      );
      await executor.acknowledgeLocalCommit(
        context: context,
        confirmation: confirmation,
      );

      expect(await dataRekeyCommands.readActive(), equals(null));
      expect(
        await stageStore.listArtifactIds(
          normalizedBaseUrl: context.normalizedBaseUrl,
          normalizedLoginName: context.normalizedLoginName,
          operationId: operationId,
          maximumCount: 1,
        ),
        isEmpty,
      );
    });

    test('stage 回执丢失后原样重放已落盘密文且不重复重包', () async {
      final operationId = _syncUuid(321);
      final sourceRecordId = _syncUuid(322);
      final transport = _RecordResponseLossDataRekeyTransport(
        userId: _syncAccountUserId,
        issuerDeviceId: _syncActorDeviceId,
        operationId: operationId,
        sourceRecordId: sourceRecordId,
      );
      final cryptography = _RecordDataRekeyCryptography(
        targetRecordId: _syncUuid(323),
      );
      final stageStore = E2eeDataRekeyStageStore(
        installationRoot: await Directory(
          '${directory.path}/data-rekey-response-loss',
        ).create(),
      );
      final context = E2eeDataRekeyExecutionContext(
        baseUrl: 'https://kelivo.bemylover.top',
        loginName: 'owner',
        userId: _syncAccountUserId,
        issuerDeviceId: _syncActorDeviceId,
        membershipGeneration: 12,
        membershipManifestDigest: _syncDigest(9),
      );
      E2eeDataRekeyExecutor executor() => E2eeDataRekeyExecutor(
        transport: transport,
        journal: dataRekeyCommands,
        stageStore: stageStore,
        cryptography: cryptography,
        clock: () => DateTime.utc(2026, 7, 30, 5),
      );

      await expectLater(
        executor().execute(context),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'simulated_stage_response_loss',
          ),
        ),
      );
      final execution = await executor().execute(context);

      expect(execution, isNot(equals(null)));
      expect(transport.stageRequests, hasLength(2));
      expect(
        transport.stageRequests[1].mutationId,
        transport.stageRequests[0].mutationId,
      );
      expect(
        transport.stageRequests[1].targetRecordId,
        transport.stageRequests[0].targetRecordId,
      );
      expect(
        transport.stageRequests[1].ciphertext,
        orderedEquals(transport.stageRequests[0].ciphertext),
      );
      expect(cryptography.recordRewrapCount, 1);
      await expectLater(
        executor().confirmReady(context: context, execution: execution!),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'data_rekey_ready_confirmation_pending',
          ),
        ),
      );
      expect(
        (await dataRekeyCommands.readActive())?.phase,
        E2eeDataRekeyJournalPhase.finalizing,
      );
    });

    test('租约被其他设备接管后丢弃旧工件并以新幂等键重新重包', () async {
      final operationId = _syncUuid(328);
      final sourceRecordId = _syncUuid(329);
      final transport = _RecordResponseLossDataRekeyTransport(
        userId: _syncAccountUserId,
        issuerDeviceId: _syncActorDeviceId,
        operationId: operationId,
        sourceRecordId: sourceRecordId,
      );
      final cryptography = _RecordDataRekeyCryptography(
        targetRecordId: _syncUuid(330),
      );
      final stageStore = E2eeDataRekeyStageStore(
        installationRoot: await Directory(
          '${directory.path}/data-rekey-lease-takeover',
        ).create(),
      );
      final context = E2eeDataRekeyExecutionContext(
        baseUrl: 'https://kelivo.bemylover.top',
        loginName: 'owner',
        userId: _syncAccountUserId,
        issuerDeviceId: _syncActorDeviceId,
        membershipGeneration: 12,
        membershipManifestDigest: _syncDigest(9),
      );
      E2eeDataRekeyExecutor executor() => E2eeDataRekeyExecutor(
        transport: transport,
        journal: dataRekeyCommands,
        stageStore: stageStore,
        cryptography: cryptography,
        clock: () => DateTime.utc(2026, 7, 30, 5),
      );

      await expectLater(
        executor().execute(context),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'simulated_stage_response_loss',
          ),
        ),
      );
      transport.simulateLeaseTakeover();
      final execution = await executor().execute(context);

      expect(execution, isNot(equals(null)));
      expect(transport.stageRequests, hasLength(2));
      expect(transport.stageRequests[0].activeLease.leaseVersion, 1);
      expect(transport.stageRequests[1].activeLease.leaseVersion, 3);
      expect(
        transport.stageRequests[1].mutationId,
        isNot(transport.stageRequests[0].mutationId),
      );
      expect(
        transport.stageRequests[1].ciphertext,
        isNot(orderedEquals(transport.stageRequests[0].ciphertext)),
      );
      expect(cryptography.recordRewrapCount, 2);
    });

    test('finalize 响应丢失且服务端已 ready 时从耐久请求恢复', () async {
      final operationId = _syncUuid(324);
      final transport = _FinalizeResponseLossDataRekeyTransport(
        userId: _syncAccountUserId,
        issuerDeviceId: _syncActorDeviceId,
        operationId: operationId,
      );
      final cryptography = _ZeroSourceDataRekeyCryptography();
      final stageStore = E2eeDataRekeyStageStore(
        installationRoot: await Directory(
          '${directory.path}/data-rekey-finalize-loss',
        ).create(),
      );
      final context = E2eeDataRekeyExecutionContext(
        baseUrl: 'https://kelivo.bemylover.top',
        loginName: 'owner',
        userId: _syncAccountUserId,
        issuerDeviceId: _syncActorDeviceId,
        membershipGeneration: 12,
        membershipManifestDigest: _syncDigest(9),
      );
      E2eeDataRekeyExecutor executor() => E2eeDataRekeyExecutor(
        transport: transport,
        journal: dataRekeyCommands,
        stageStore: stageStore,
        cryptography: cryptography,
        clock: () => DateTime.utc(2026, 7, 30, 5),
      );

      await expectLater(
        executor().execute(context),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'simulated_finalize_response_loss',
          ),
        ),
      );
      final execution = await executor().execute(context);

      expect(execution, isNot(equals(null)));
      expect(transport.finalizeRequests, hasLength(2));
      expect(
        transport.finalizeRequests[1].mutationId,
        transport.finalizeRequests[0].mutationId,
      );
      expect(
        transport.finalizeRequests[1].proof.signature,
        orderedEquals(transport.finalizeRequests[0].proof.signature),
      );
      expect(cryptography.signatureCount, 1);
    });

    test('附件换代仅暂存新 manifest 并保持分块身份与摘要', () async {
      final operationId = _syncUuid(325);
      final attachmentId = _syncUuid(326);
      final uploadId = _syncUuid(327);
      final transport = _AttachmentDataRekeyTransport(
        userId: _syncAccountUserId,
        issuerDeviceId: _syncActorDeviceId,
        operationId: operationId,
        attachmentId: attachmentId,
        uploadId: uploadId,
      );
      final cryptography = _AttachmentDataRekeyCryptography();
      final stageStore = E2eeDataRekeyStageStore(
        installationRoot: await Directory(
          '${directory.path}/data-rekey-attachment',
        ).create(),
      );
      final context = E2eeDataRekeyExecutionContext(
        baseUrl: 'https://kelivo.bemylover.top',
        loginName: 'owner',
        userId: _syncAccountUserId,
        issuerDeviceId: _syncActorDeviceId,
        membershipGeneration: 12,
        membershipManifestDigest: _syncDigest(9),
      );
      final executor = E2eeDataRekeyExecutor(
        transport: transport,
        journal: dataRekeyCommands,
        stageStore: stageStore,
        cryptography: cryptography,
        clock: () => DateTime.utc(2026, 7, 30, 5),
      );

      await executor.execute(context);

      expect(cryptography.attachmentRewrapCount, 1);
      expect(cryptography.sourceChunkKeyEpoch, 6);
      expect(cryptography.sourceChunkDigests, <List<int>>[
        _syncDigest(41),
        _syncDigest(42),
      ]);
      expect(transport.stageRequests, hasLength(1));
      final request = transport.stageRequests.single;
      expect(request.attachmentId, attachmentId);
      expect(request.uploadId, uploadId);
      expect(request.sourceManifestRevision, 2);
      expect(request.manifestRevision, 3);
      expect(request.manifestKeyEpoch, 8);
    });
  });

  group('E2EE 账户密钥变更编排', () {
    test('恢复接续拒绝复用遗留数据换代 operationId', () {
      final operationId = _syncUuid(330);

      expect(
        () => E2eeAccountKeyTransitionBinding(
          kind: E2eeAccountKeyTransitionKind.recoveryResume,
          userId: _syncAccountUserId,
          issuerDeviceId: _syncActorDeviceId,
          membershipOperationId: operationId,
          rekeyOperationId: operationId,
          securityGeneration: 12,
          targetKeyEpoch: 8,
          membershipManifestDigest: _syncDigest(9),
        ),
        throwsFormatException,
      );
      expect(
        () => E2eeAccountKeyTransitionRemoteReceipt(
          kind: E2eeAccountKeyTransitionKind.recoveryResume,
          userId: _syncAccountUserId,
          issuerDeviceId: _syncActorDeviceId,
          membershipOperationId: operationId,
          rekeyOperationId: operationId,
          securityGeneration: 12,
          targetKeyEpoch: 8,
          membershipManifestDigest: _syncDigest(9),
        ),
        throwsFormatException,
      );
    });

    test('绑定与回执的安全关键字节不暴露内部存储', () {
      final expectedDigest = _syncDigest(0x61);
      final bindingInput = Uint8List.fromList(expectedDigest);
      final binding = E2eeAccountKeyTransitionBinding(
        kind: E2eeAccountKeyTransitionKind.recoveryResume,
        userId: _syncAccountUserId,
        issuerDeviceId: _syncActorDeviceId,
        membershipOperationId: _syncUuid(336),
        rekeyOperationId: _syncUuid(337),
        securityGeneration: 12,
        targetKeyEpoch: 8,
        membershipManifestDigest: bindingInput,
      );
      bindingInput[0] ^= 0xff;
      final exposedBindingDigest = binding.membershipManifestDigest;
      exposedBindingDigest[1] ^= 0xff;
      expect(binding.membershipManifestDigest, orderedEquals(expectedDigest));

      final receiptInput = Uint8List.fromList(expectedDigest);
      final receipt = E2eeAccountKeyTransitionRemoteReceipt(
        kind: E2eeAccountKeyTransitionKind.recoveryResume,
        userId: _syncAccountUserId,
        issuerDeviceId: _syncActorDeviceId,
        membershipOperationId: _syncUuid(336),
        rekeyOperationId: _syncUuid(337),
        securityGeneration: 12,
        targetKeyEpoch: 8,
        membershipManifestDigest: receiptInput,
      );
      receiptInput[0] ^= 0xff;
      final exposedReceiptDigest = receipt.membershipManifestDigest;
      exposedReceiptDigest[1] ^= 0xff;
      expect(receipt.membershipManifestDigest, orderedEquals(expectedDigest));
    });

    test('恢复接续计划允许连续接管并严格追溯最初数据换代', () async {
      final chain = await createMembershipChain();
      addTearDown(() => KelivoSecureCore().closeAccountRootKey(chain.ark));
      const manifestModule = E2eeAccountTrustManifestModule();
      final takeoverDevice = await _newDatabaseMembershipDevice(
        const KelivoSecureCore(),
        deviceId: _syncUuid(109),
        authGeneration: 1,
      );
      final takeover = await manifestModule.create(
        ark: chain.ark,
        change: E2eeRecoverResumeMembershipChange(
          previous: chain.resumed,
          operationId: _syncUuid(110),
          subject: takeoverDevice,
        ),
      );
      final sourceState = Uint8List(DeviceStateBlobStore.blobLength)..[0] = 1;
      final unprunedState = Uint8List(DeviceStateBlobStore.blobLength)..[0] = 2;
      final prunedState = Uint8List(DeviceStateBlobStore.blobLength)..[0] = 3;
      final binding = E2eeAccountKeyTransitionBinding(
        kind: E2eeAccountKeyTransitionKind.recoveryResume,
        userId: _syncAccountUserId,
        issuerDeviceId: takeover.issuerDeviceId,
        membershipOperationId: takeover.operationId,
        rekeyOperationId: chain.revoked.operationId,
        securityGeneration: takeover.securityGeneration,
        targetKeyEpoch: takeover.keyEpoch,
        membershipManifestDigest: takeover.digest,
      );

      expect(chain.revoked.issuerDeviceId, isNot(binding.issuerDeviceId));
      expect(takeover.securityGeneration, chain.paired.securityGeneration + 3);
      expect(
        () => takeover.requireDataRekeyLineage(
          rekeyOperationId: chain.revoked.operationId,
        ),
        returnsNormally,
      );
      expect(
        () => E2eeDeviceStateKeyTransitionPlan(
          binding: binding,
          previousMembership: chain.resumed,
          nextMembership: takeover,
          sourceStateBlob: sourceState,
          unprunedStateBlob: unprunedState,
          prunedStateBlob: prunedState,
        ),
        returnsNormally,
      );

      final unrelatedRekeyBinding = E2eeAccountKeyTransitionBinding(
        kind: E2eeAccountKeyTransitionKind.recoveryResume,
        userId: binding.userId,
        issuerDeviceId: binding.issuerDeviceId,
        membershipOperationId: binding.membershipOperationId,
        rekeyOperationId: _syncUuid(339),
        securityGeneration: binding.securityGeneration,
        targetKeyEpoch: binding.targetKeyEpoch,
        membershipManifestDigest: binding.membershipManifestDigest,
      );
      expect(
        () => E2eeDeviceStateKeyTransitionPlan(
          binding: unrelatedRekeyBinding,
          previousMembership: chain.resumed,
          nextMembership: takeover,
          sourceStateBlob: sourceState,
          unprunedStateBlob: unprunedState,
          prunedStateBlob: prunedState,
        ),
        throwsFormatException,
      );
    });

    test('设备状态换代计划不暴露内部快照', () async {
      final chain = await createMembershipChain();
      addTearDown(() => KelivoSecureCore().closeAccountRootKey(chain.ark));
      final binding = E2eeAccountKeyTransitionBinding(
        kind: E2eeAccountKeyTransitionKind.deviceRevocation,
        userId: _syncAccountUserId,
        issuerDeviceId: _syncActorDeviceId,
        membershipOperationId: chain.revoked.operationId,
        rekeyOperationId: chain.revoked.operationId,
        securityGeneration: chain.revoked.securityGeneration,
        targetKeyEpoch: chain.revoked.keyEpoch,
        membershipManifestDigest: chain.revoked.digest,
      );
      final sourceInput = Uint8List(DeviceStateBlobStore.blobLength)..[0] = 1;
      final unprunedInput = Uint8List(DeviceStateBlobStore.blobLength)..[0] = 2;
      final prunedInput = Uint8List(DeviceStateBlobStore.blobLength)..[0] = 3;
      final plan = E2eeDeviceStateKeyTransitionPlan(
        binding: binding,
        previousMembership: chain.paired,
        nextMembership: chain.revoked,
        sourceStateBlob: sourceInput,
        unprunedStateBlob: unprunedInput,
        prunedStateBlob: prunedInput,
      );
      sourceInput[0] = 4;
      unprunedInput[0] = 5;
      prunedInput[0] = 6;
      final exposedSource = plan.sourceStateBlob;
      final exposedUnpruned = plan.unprunedStateBlob;
      final exposedPruned = plan.prunedStateBlob;
      exposedSource[1] = 4;
      exposedUnpruned[1] = 5;
      exposedPruned[1] = 6;

      expect(plan.sourceStateBlob[0], 1);
      expect(plan.unprunedStateBlob[0], 2);
      expect(plan.prunedStateBlob[0], 3);
      expect(plan.sourceStateBlob[1], 0);
      expect(plan.unprunedStateBlob[1], 0);
      expect(plan.prunedStateBlob[1], 0);
    });

    test('数据已就绪时恢复替换允许从当前成员头直达', () async {
      final chain = await createMembershipChain();
      addTearDown(() => KelivoSecureCore().closeAccountRootKey(chain.ark));
      final recoveryDevice = await _newDatabaseMembershipDevice(
        const KelivoSecureCore(),
        deviceId: _syncUuid(111),
        authGeneration: 1,
      );
      final replaced = await const E2eeAccountTrustManifestModule().create(
        ark: chain.ark,
        change: E2eeRecoverReplaceMembershipChange(
          previous: chain.paired,
          operationId: _syncUuid(112),
          subject: recoveryDevice,
          nextRecoveryCapsuleVersion: 2,
          nextRecoveryCapsule: Uint8List(80)..fillRange(0, 80, 0x66),
        ),
      );
      final binding = E2eeAccountKeyTransitionBinding(
        kind: E2eeAccountKeyTransitionKind.recoveryReplacement,
        userId: replaced.userId,
        issuerDeviceId: replaced.issuerDeviceId,
        membershipOperationId: replaced.operationId,
        rekeyOperationId: replaced.operationId,
        securityGeneration: replaced.securityGeneration,
        targetKeyEpoch: replaced.keyEpoch,
        membershipManifestDigest: replaced.digest,
      );

      expect(
        () => E2eeDeviceStateKeyTransitionPlan(
          binding: binding,
          previousMembership: chain.paired,
          nextMembership: replaced,
          sourceStateBlob: Uint8List(DeviceStateBlobStore.blobLength)..[0] = 1,
          unprunedStateBlob: Uint8List(DeviceStateBlobStore.blobLength)
            ..[0] = 2,
          prunedStateBlob: Uint8List(DeviceStateBlobStore.blobLength)..[0] = 3,
        ),
        returnsNormally,
      );
    });

    test('本地提交拒绝跨签发设备复用 ready 确认', () async {
      final chain = await createMembershipChain();
      addTearDown(() => KelivoSecureCore().closeAccountRootKey(chain.ark));
      final binding = E2eeAccountKeyTransitionBinding(
        kind: E2eeAccountKeyTransitionKind.recoveryResume,
        userId: chain.resumed.userId,
        issuerDeviceId: chain.resumed.issuerDeviceId,
        membershipOperationId: chain.resumed.operationId,
        rekeyOperationId: chain.revoked.operationId,
        securityGeneration: chain.resumed.securityGeneration,
        targetKeyEpoch: chain.resumed.keyEpoch,
        membershipManifestDigest: chain.resumed.digest,
      );
      final forgedIssuerBinding = E2eeAccountKeyTransitionBinding(
        kind: binding.kind,
        userId: binding.userId,
        issuerDeviceId: _syncActorDeviceId,
        membershipOperationId: binding.membershipOperationId,
        rekeyOperationId: binding.rekeyOperationId,
        securityGeneration: binding.securityGeneration,
        targetKeyEpoch: binding.targetKeyEpoch,
        membershipManifestDigest: binding.membershipManifestDigest,
      );
      final context = E2eeDataRekeyExecutionContext(
        baseUrl: 'https://kelivo.bemylover.top',
        loginName: 'owner',
        userId: binding.userId,
        issuerDeviceId: forgedIssuerBinding.issuerDeviceId,
        membershipGeneration: binding.securityGeneration,
        membershipManifestDigest: binding.membershipManifestDigest,
      );
      final capturingLocal = _CapturingAccountKeyTransitionLocalCommitter();
      await E2eeAccountKeyTransitionCoordinator(
        dataRekeyExecutor: E2eeDataRekeyExecutor(
          transport: _ZeroSourceDataRekeyTransport(
            userId: binding.userId,
            issuerDeviceId: forgedIssuerBinding.issuerDeviceId,
            operationId: binding.rekeyOperationId,
            sourceKeyEpoch: binding.targetKeyEpoch - 1,
            targetKeyEpoch: binding.targetKeyEpoch,
          ),
          journal: dataRekeyCommands,
          stageStore: E2eeDataRekeyStageStore(
            installationRoot: await Directory(
              '${directory.path}/cross-issuer-ready',
            ).create(),
          ),
          cryptography: _ZeroSourceDataRekeyCryptography(
            issuerDeviceId: forgedIssuerBinding.issuerDeviceId,
            targetKeyEpoch: binding.targetKeyEpoch,
          ),
          clock: () => DateTime.utc(2026, 7, 30, 5),
        ),
        remoteCommit: _FakeAccountKeyTransitionRemote(
          forgedIssuerBinding,
          failFirstComplete: false,
        ),
        localCommitter: capturingLocal,
      ).execute(context: context, binding: forgedIssuerBinding);
      final plan = E2eeDeviceStateKeyTransitionPlan(
        binding: binding,
        previousMembership: chain.revoked,
        nextMembership: chain.resumed,
        sourceStateBlob: Uint8List(DeviceStateBlobStore.blobLength)..[0] = 1,
        unprunedStateBlob: Uint8List(DeviceStateBlobStore.blobLength)..[0] = 2,
        prunedStateBlob: Uint8List(DeviceStateBlobStore.blobLength)..[0] = 3,
      );
      final committer = E2eeDeviceStateKeyTransitionCommitter(
        baseUrl: context.normalizedBaseUrl,
        normalizedLoginName: context.normalizedLoginName,
        plan: plan,
        deviceStateStore: DeviceStateBlobStore(
          installationRoot: await Directory(
            '${directory.path}/cross-issuer-state',
          ).create(),
        ),
        secureCore: const KelivoSecureCore(),
        databaseGateway: ChatDatabaseGateway(cipher: testDatabaseCipher),
        databaseFile: File('${directory.path}/constraints.sqlite'),
      );

      await expectLater(
        committer.commit(
          binding: binding,
          confirmation: capturingLocal.confirmation!,
        ),
        throwsFormatException,
      );
    });

    test('本地提交后 checkpoint 清理失败可在无换代日志时恢复', () async {
      final operationId = _syncUuid(331);
      final transport = _ZeroSourceDataRekeyTransport(
        userId: _syncAccountUserId,
        issuerDeviceId: _syncActorDeviceId,
        operationId: operationId,
      );
      final stageStore = E2eeDataRekeyStageStore(
        installationRoot: await Directory(
          '${directory.path}/account-key-transition',
        ).create(),
      );
      final context = E2eeDataRekeyExecutionContext(
        baseUrl: 'https://kelivo.bemylover.top',
        loginName: 'owner',
        userId: _syncAccountUserId,
        issuerDeviceId: _syncActorDeviceId,
        membershipGeneration: 12,
        membershipManifestDigest: _syncDigest(9),
      );
      final binding = E2eeAccountKeyTransitionBinding(
        kind: E2eeAccountKeyTransitionKind.deviceRevocation,
        userId: _syncAccountUserId,
        issuerDeviceId: _syncActorDeviceId,
        membershipOperationId: operationId,
        rekeyOperationId: operationId,
        securityGeneration: 12,
        targetKeyEpoch: 8,
        membershipManifestDigest: _syncDigest(9),
      );
      final remote = _FakeAccountKeyTransitionRemote(binding);
      final local = _FakeAccountKeyTransitionLocalCommitter();
      final coordinator = E2eeAccountKeyTransitionCoordinator(
        dataRekeyExecutor: E2eeDataRekeyExecutor(
          transport: transport,
          journal: dataRekeyCommands,
          stageStore: stageStore,
          cryptography: _ZeroSourceDataRekeyCryptography(),
          clock: () => DateTime.utc(2026, 7, 30, 5),
        ),
        remoteCommit: remote,
        localCommitter: local,
      );

      await expectLater(
        coordinator.execute(context: context, binding: binding),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'simulated_checkpoint_cleanup_loss',
          ),
        ),
      );
      expect(local.commitCalls, 1);
      expect(remote.commitCalls, 1);
      expect(remote.completeCalls, 1);
      expect(await dataRekeyCommands.readActive(), equals(null));

      final receipt = await coordinator.execute(
        context: context,
        binding: binding,
      );

      expect(receipt.rekeyOperationId, operationId);
      expect(local.commitCalls, 1);
      expect(local.requireCommittedCalls, 1);
      expect(remote.commitCalls, 2);
      expect(remote.completeCalls, 2);
    });

    test('ready 后推进成员锚并只发布已裁剪设备状态', () async {
      const secureCore = KelivoSecureCore();
      const manifestModule = E2eeAccountTrustManifestModule();
      const baseUrl = 'https://kelivo.bemylover.top';
      final testIdentity = sha256
          .convert(utf8.encode(directory.path))
          .toString()
          .substring(0, 12);
      final loginName = 'transition-$testIdentity';
      final deviceStateRoot = await Directory(
        '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
        '${Platform.pathSeparator}device_state_key_transition_$testIdentity',
      ).create(recursive: true);
      final slotId = E2eeDeviceStateAccess.deriveSlotId(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      );
      KelivoKeyHandle? key;
      KelivoDeviceIdentityHandle? identity;
      KelivoAccountRootKeyHandle? ark;
      E2eeOpenedDeviceStateHandles? opened;
      addTearDown(() async {
        final openedToClose = opened;
        if (openedToClose != null) {
          await secureCore.closeAccountRootKey(openedToClose.ark!);
          await secureCore.closeDeviceIdentity(openedToClose.identity);
          await secureCore.close(openedToClose.key);
        }
        final arkToClose = ark;
        if (arkToClose != null) {
          await secureCore.closeAccountRootKey(arkToClose);
        }
        final identityToClose = identity;
        if (identityToClose != null) {
          await secureCore.closeDeviceIdentity(identityToClose);
        }
        final keyToClose = key;
        if (keyToClose != null) await secureCore.close(keyToClose);
        await secureCore.deleteSlot(slotId);
        if (await deviceStateRoot.exists()) {
          await deviceStateRoot.delete(recursive: true);
        }
      });

      key = await secureCore.createSlot(slotId);
      identity = await secureCore.generateDeviceIdentity();
      ark = await secureCore.generateAccountRootKey(
        userId: Uuid.parseAsByteList(_syncAccountUserId),
        keyEpoch: 1,
      );
      final publicKeys = await secureCore.readDevicePublicKeys(identity);
      final recoveryDevice = E2eeMembershipDeviceInput(
        deviceId: _syncActorDeviceId,
        keyVersion: 1,
        authGeneration: 1,
        signingPublicKey: publicKeys.signingPublicKey,
        keyAgreementPublicKey: publicKeys.keyAgreementPublicKey,
      );
      final originalDevice = await _newDatabaseMembershipDevice(
        secureCore,
        deviceId: _syncUuid(332),
        authGeneration: 0,
      );
      final initialized = await manifestModule.create(
        ark: ark,
        change: E2eeInitializeMembershipChange(
          userId: _syncAccountUserId,
          operationId: _syncUuid(333),
          member: originalDevice,
          recoveryPublicKeyVersion: 1,
          recoveryPublicKey: await _newDatabaseRecoveryPublicKey(secureCore),
          recoveryCapsuleVersion: 1,
          recoveryCapsule: Uint8List(80)..fillRange(0, 80, 0x51),
        ),
      );
      final resumed = await manifestModule.create(
        ark: ark,
        change: E2eeRecoverResumeMembershipChange(
          previous: initialized,
          operationId: _syncUuid(334),
          subject: recoveryDevice,
        ),
      );
      await repository.e2eeVerifiedMembershipAnchorCommands.install(
        membership: resumed,
        now: DateTime.utc(2026, 7, 30, 5),
      );
      final sourceStateBlob = await secureCore.sealDeviceState(
        key,
        identity,
        deviceId: Uuid.parseAsByteList(_syncActorDeviceId),
        keyVersion: 1,
        ark: ark,
        account: KelivoDeviceStateAccountBinding(
          userId: Uuid.parseAsByteList(_syncAccountUserId),
          keyEpoch: 1,
        ),
      );
      final nextEpoch = await secureCore.generateAccountRootKey(
        userId: Uuid.parseAsByteList(_syncAccountUserId),
        keyEpoch: 2,
      );
      try {
        await secureCore.addAccountRootKeyEpoch(ark, source: nextEpoch);
      } finally {
        await secureCore.closeAccountRootKey(nextEpoch);
      }
      final operationId = _syncUuid(335);
      final replaced = await manifestModule.create(
        ark: ark,
        change: E2eeRecoverReplaceMembershipChange(
          previous: resumed,
          operationId: operationId,
          subject: recoveryDevice,
          nextRecoveryCapsuleVersion: 2,
          nextRecoveryCapsule: Uint8List(80)..fillRange(0, 80, 0x52),
        ),
      );
      final unprunedStateBlob = await secureCore.sealDeviceState(
        key,
        identity,
        deviceId: Uuid.parseAsByteList(_syncActorDeviceId),
        keyVersion: 1,
        ark: ark,
        account: KelivoDeviceStateAccountBinding(
          userId: Uuid.parseAsByteList(_syncAccountUserId),
          keyEpoch: 2,
        ),
      );
      await secureCore.pruneAccountRootKeyEpoch(ark, keyEpoch: 1);
      final prunedStateBlob = await secureCore.sealDeviceState(
        key,
        identity,
        deviceId: Uuid.parseAsByteList(_syncActorDeviceId),
        keyVersion: 1,
        ark: ark,
        account: KelivoDeviceStateAccountBinding(
          userId: Uuid.parseAsByteList(_syncAccountUserId),
          keyEpoch: 2,
        ),
      );
      final deviceStateStore = DeviceStateBlobStore(
        installationRoot: deviceStateRoot,
      );
      await deviceStateStore.compareAndSwap(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
        expectedVersion: null,
        blob: sourceStateBlob,
      );
      final binding = E2eeAccountKeyTransitionBinding(
        kind: E2eeAccountKeyTransitionKind.recoveryReplacement,
        userId: _syncAccountUserId,
        issuerDeviceId: _syncActorDeviceId,
        membershipOperationId: operationId,
        rekeyOperationId: operationId,
        securityGeneration: replaced.securityGeneration,
        targetKeyEpoch: replaced.keyEpoch,
        membershipManifestDigest: replaced.digest,
      );
      final context = E2eeDataRekeyExecutionContext(
        baseUrl: baseUrl,
        loginName: loginName,
        userId: _syncAccountUserId,
        issuerDeviceId: _syncActorDeviceId,
        membershipGeneration: replaced.securityGeneration,
        membershipManifestDigest: replaced.digest,
      );
      final stageStore = E2eeDataRekeyStageStore(
        installationRoot: await Directory(
          '${directory.path}/device-state-key-transition-stage',
        ).create(),
      );
      final remote = _FakeAccountKeyTransitionRemote(
        binding,
        failFirstComplete: false,
      );
      final transitionPlan = E2eeDeviceStateKeyTransitionPlan(
        binding: binding,
        previousMembership: resumed,
        nextMembership: replaced,
        sourceStateBlob: sourceStateBlob,
        unprunedStateBlob: unprunedStateBlob,
        prunedStateBlob: prunedStateBlob,
      );
      binding.membershipManifestDigest[0] ^= 0xff;
      transitionPlan.sourceStateBlob[0] ^= 0xff;
      transitionPlan.unprunedStateBlob[0] ^= 0xff;
      transitionPlan.prunedStateBlob[0] ^= 0xff;
      final coordinator = E2eeAccountKeyTransitionCoordinator(
        dataRekeyExecutor: E2eeDataRekeyExecutor(
          transport: _ZeroSourceDataRekeyTransport(
            userId: _syncAccountUserId,
            issuerDeviceId: _syncActorDeviceId,
            operationId: operationId,
            sourceKeyEpoch: 1,
            targetKeyEpoch: 2,
          ),
          journal: dataRekeyCommands,
          stageStore: stageStore,
          cryptography: _ZeroSourceDataRekeyCryptography(
            issuerDeviceId: _syncActorDeviceId,
            targetKeyEpoch: 2,
          ),
          clock: () => DateTime.utc(2026, 7, 30, 5),
        ),
        remoteCommit: remote,
        localCommitter: E2eeDeviceStateKeyTransitionCommitter(
          baseUrl: baseUrl,
          normalizedLoginName: loginName,
          plan: transitionPlan,
          deviceStateStore: deviceStateStore,
          secureCore: secureCore,
          databaseGateway: ChatDatabaseGateway(cipher: testDatabaseCipher),
          databaseFile: File('${directory.path}/constraints.sqlite'),
          clock: () => DateTime.utc(2026, 7, 30, 5, 1),
        ),
      );

      await coordinator.execute(context: context, binding: binding);
      await coordinator.execute(context: context, binding: binding);

      final current = await deviceStateStore.read(
        normalizedBaseUrl: baseUrl,
        normalizedLoginName: loginName,
      );
      expect(current, orderedEquals(prunedStateBlob));
      opened = await E2eeDeviceStateAccess(
        baseUrl: baseUrl,
        deviceStateStore: deviceStateStore,
        secureCore: secureCore,
      ).openExisting(loginName);
      final committed = opened!;
      final anchor = await repository.e2eeVerifiedMembershipAnchorCommands
          .readVerified(accountUserId: _syncAccountUserId, ark: committed.ark!);
      expect(anchor, isNot(equals(null)));
      expect(anchor!.membership.digest, orderedEquals(replaced.digest));
      await expectLater(
        secureCore.deriveAccountTrustPublicKey(
          committed.ark!,
          userId: Uuid.parseAsByteList(_syncAccountUserId),
          keyEpoch: 1,
        ),
        throwsA(isA<KelivoSecureCoreException>()),
      );
      expect(await dataRekeyCommands.readActive(), equals(null));
      expect(remote.commitCalls, 2);
      expect(remote.completeCalls, 2);
    });
  });

  group('E2EE sync durable queue schema', () {
    test('accepts every valid state and nonnegative change sequence', () async {
      final leaseExpiry = DateTime.utc(2026, 7, 27, 0, 1);
      await insertSyncIntent();
      await insertSyncIntent(
        entityId: 'conversation-2',
        intentId: _syncUuid(2),
        phase: 'preparing',
        writerSessionId: 'writer-session',
      );
      await insertSyncIntent(
        entityId: 'conversation-3',
        intentId: _syncUuid(3),
        phase: 'sealing',
        sealLeaseToken: 'seal-token',
        sealOwnerSessionId: 'seal-owner',
        sealLeaseExpiresAt: leaseExpiry,
      );

      await insertSyncOperation();
      await insertSyncOperation(
        operationId: _syncUuid(12),
        stateDigest: _syncDigest(2),
        recordId: _syncUuid(22),
        intentId: _syncUuid(2),
        outcome: 'applied',
        resultRevision: 1,
        resultChangeSeq: 0,
      );
      await insertSyncOperation(
        operationId: _syncUuid(13),
        stateDigest: _syncDigest(3),
        recordId: _syncUuid(23),
        intentId: _syncUuid(3),
        outcome: 'conflict',
      );
      await insertSyncOperation(
        operationId: _syncUuid(14),
        stateDigest: _syncDigest(4),
        recordId: _syncUuid(24),
        intentId: _syncUuid(4),
        outcome: 'rejected',
        errorCode: 'permission-denied',
      );

      await insertSyncOutbox();
      await insertSyncOutbox(
        operationId: _syncUuid(12),
        recordId: _syncUuid(22),
        phase: 'sending',
        leaseToken: 'send-token',
        leaseOwnerSessionId: 'send-owner',
        leaseExpiresAt: leaseExpiry,
        attemptCount: 1,
        lastFailureKind: 'timeout',
      );

      await insertSyncRemoteRecord(
        revision: 1,
        lastChangeSeq: 0,
        stateDigest: _syncDigest(10),
      );
      await insertSyncRemoteRecord(
        recordId: _syncUuid(32),
        gate: 'requires-pull',
      );
      await insertSyncRemoteRecord(
        recordId: _syncUuid(33),
        revision: 2,
        lastChangeSeq: 1,
        stateDigest: _syncDigest(11),
        gate: 'quarantined',
        observedRevision: 3,
        errorCode: 'state-mismatch',
      );

      expect(
        await database.select(database.e2eeSyncIntentRows).get(),
        hasLength(3),
      );
      expect(
        await database.select(database.e2eeSyncOperationRows).get(),
        hasLength(4),
      );
      expect(
        await database.select(database.e2eeSyncOutboxRows).get(),
        hasLength(2),
      );
      expect(
        await database.select(database.e2eeSyncRemoteRecordRows).get(),
        hasLength(3),
      );
    });

    test(
      'intent constraints reject malformed identities and lease states',
      () async {
        final createdAt = DateTime.utc(2026, 7, 27);
        final invalidWrites = <Future<void> Function()>[
          () => insertSyncIntent(entityType: ''),
          () =>
              insertSyncIntent(entityId: List<String>.filled(1025, 'x').join()),
          () => insertSyncIntent(
            intentId: _syncIntentId.replaceFirst('-4000-', '-5000-'),
          ),
          () => insertSyncIntent(generation: 0),
          () => insertSyncIntent(phase: 'unknown'),
          () => insertSyncIntent(phase: 'preparing'),
          () => insertSyncIntent(phase: 'preparing', writerSessionId: ''),
          () => insertSyncIntent(phase: 'dirty', writerSessionId: 'writer'),
          () => insertSyncIntent(
            phase: 'sealing',
            sealLeaseToken: 'token',
            sealOwnerSessionId: 'owner',
          ),
          () => insertSyncIntent(
            createdAt: createdAt,
            updatedAt: createdAt.subtract(const Duration(microseconds: 1)),
          ),
        ];
        for (final write in invalidWrites) {
          await expectLater(write(), throwsRemoteSqliteException());
        }

        await insertSyncIntent();
        await expectLater(
          insertSyncIntent(entityId: 'conversation-2', intentId: _syncIntentId),
          throwsRemoteSqliteException(),
        );
        expect(
          await database.select(database.e2eeSyncIntentRows).get(),
          hasLength(1),
        );
      },
    );

    test('operation constraints keep outcomes mutually exclusive', () async {
      final createdAt = DateTime.utc(2026, 7, 27);
      final invalidWrites = <Future<void> Function()>[
        () => insertSyncOperation(
          operationId: _syncOperationId.replaceFirst('-4000-', '-5000-'),
        ),
        () => insertSyncOperation(stateDigest: _syncDigest(1, length: 31)),
        () => insertSyncOperation(
          recordId: _syncRecordId.replaceFirst('-4000-', '-5000-'),
        ),
        () => insertSyncOperation(entityType: ''),
        () => insertSyncOperation(
          intentId: _syncIntentId.replaceFirst('-4000-', '-5000-'),
        ),
        () => insertSyncOperation(intentGeneration: 0),
        () => insertSyncOperation(expectedRevision: -1),
        () => insertSyncOperation(
          accountUserId: _syncAccountUserId.replaceFirst('-4000-', '-5000-'),
        ),
        () => insertSyncOperation(
          actorDeviceId: _syncActorDeviceId.replaceFirst('-4000-', '-5000-'),
        ),
        () => insertSyncOperation(claimedWriterKeyVersion: 0),
        () => insertSyncOperation(claimedWriterKeyVersion: 4294967296),
        () => insertSyncOperation(outcome: 'unknown'),
        () => insertSyncOperation(outcome: 'active', resultRevision: 1),
        () => insertSyncOperation(outcome: 'applied', resultRevision: 1),
        () => insertSyncOperation(
          outcome: 'applied',
          resultRevision: 1,
          resultChangeSeq: -1,
        ),
        () => insertSyncOperation(outcome: 'conflict', resultRevision: 1),
        () => insertSyncOperation(outcome: 'conflict', errorCode: 'conflict'),
        () => insertSyncOperation(outcome: 'rejected'),
        () => insertSyncOperation(
          outcome: 'rejected',
          errorCode: List<String>.filled(101, 'x').join(),
        ),
        () => insertSyncOperation(
          createdAt: createdAt,
          updatedAt: createdAt.subtract(const Duration(microseconds: 1)),
        ),
      ];
      for (final write in invalidWrites) {
        await expectLater(write(), throwsRemoteSqliteException());
      }

      await insertSyncOperation();
      await expectLater(
        insertSyncOperation(
          operationId: _syncUuid(42),
          stateDigest: _syncDigest(1),
          recordId: _syncUuid(43),
        ),
        throwsRemoteSqliteException(),
      );
      expect(
        await database.select(database.e2eeSyncOperationRows).get(),
        hasLength(1),
      );
    });

    test(
      'outbox constraints reject reseal shape and invalid send leases',
      () async {
        await insertSyncOperation();
        final createdAt = DateTime.utc(2026, 7, 27);
        final invalidWrites = <Future<void> Function()>[
          () => insertSyncOutbox(operationId: _syncUuid(51)),
          () => insertSyncOutbox(
            recordId: _syncRecordId.replaceFirst('-4000-', '-5000-'),
          ),
          () => insertSyncOutbox(envelopeVersion: 2),
          () => insertSyncOutbox(keyEpoch: 0),
          () => insertSyncOutbox(ciphertext: Uint8List(0)),
          () => insertSyncOutbox(ciphertext: Uint8List(1048577)),
          () => insertSyncOutbox(phase: 'unknown'),
          () => insertSyncOutbox(phase: 'ready', leaseToken: 'token'),
          () => insertSyncOutbox(phase: 'sending'),
          () => insertSyncOutbox(
            phase: 'sending',
            leaseToken: '',
            leaseOwnerSessionId: 'owner',
            leaseExpiresAt: createdAt,
          ),
          () => insertSyncOutbox(transitionVersion: 0),
          () => insertSyncOutbox(attemptCount: -1),
          () => insertSyncOutbox(lastFailureKind: ''),
          () => insertSyncOutbox(
            lastFailureKind: List<String>.filled(101, 'x').join(),
          ),
          () => insertSyncOutbox(
            createdAt: createdAt,
            updatedAt: createdAt.subtract(const Duration(microseconds: 1)),
          ),
        ];
        for (final write in invalidWrites) {
          await expectLater(write(), throwsRemoteSqliteException());
        }

        await insertSyncOutbox();
        await insertSyncOperation(
          operationId: _syncUuid(52),
          stateDigest: _syncDigest(52),
          recordId: _syncUuid(53),
        );
        await expectLater(
          insertSyncOutbox(operationId: _syncUuid(52), recordId: _syncUuid(54)),
          throwsRemoteSqliteException(),
        );
        expect(
          await database.select(database.e2eeSyncOutboxRows).get(),
          hasLength(1),
        );
      },
    );

    test(
      'remote record constraints reject partial state and invalid gates',
      () async {
        final createdAt = DateTime.utc(2026, 7, 27);
        final invalidWrites = <Future<void> Function()>[
          () => insertSyncRemoteRecord(
            recordId: _syncRecordId.replaceFirst('-4000-', '-5000-'),
          ),
          () => insertSyncRemoteRecord(revision: 1),
          () => insertSyncRemoteRecord(
            revision: 0,
            lastChangeSeq: 0,
            stateDigest: _syncDigest(1),
          ),
          () => insertSyncRemoteRecord(
            revision: 1,
            lastChangeSeq: -1,
            stateDigest: _syncDigest(1),
          ),
          () => insertSyncRemoteRecord(
            revision: 1,
            lastChangeSeq: 0,
            stateDigest: _syncDigest(1, length: 31),
          ),
          () => insertSyncRemoteRecord(gate: 'unknown'),
          () => insertSyncRemoteRecord(gate: 'ready', observedRevision: 1),
          () => insertSyncRemoteRecord(gate: 'ready', errorCode: 'error'),
          () =>
              insertSyncRemoteRecord(gate: 'requires-pull', errorCode: 'error'),
          () => insertSyncRemoteRecord(gate: 'quarantined'),
          () => insertSyncRemoteRecord(
            gate: 'quarantined',
            errorCode: List<String>.filled(101, 'x').join(),
          ),
          () => insertSyncRemoteRecord(
            createdAt: createdAt,
            updatedAt: createdAt.subtract(const Duration(microseconds: 1)),
          ),
        ];
        for (final write in invalidWrites) {
          await expectLater(write(), throwsRemoteSqliteException());
        }

        expect(
          await database.select(database.e2eeSyncRemoteRecordRows).get(),
          isEmpty,
        );
      },
    );
  });

  group('E2EE sync pull checkpoint boundary', () {
    test('增量页业务写入与游标最后原子提交', () async {
      final wireChange = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 90,
      );
      final change = await authenticatePulledValueChange(wireChange);
      final initial = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28),
      );
      expect(initial.phase, E2eeSyncPullPhase.incremental);
      expect(initial.syncCursor, equals(null));
      expect(initial.lastChangeSeq, 0);
      expect(initial.transitionVersion, 1);

      final committed = await pullCommands.applyIncrementalPage(
        expected: initial,
        nextCursor: 'cursor-1',
        lastChangeSeq: 1,
        changes: <E2eeSyncPulledChange>[change],
        now: DateTime.utc(2026, 7, 28, 0, 1),
        applyBusiness: (_) async {
          await insertConversation(id: 'pulled-conversation');
        },
      );

      expect(committed.value.businessApplyCount, 1);
      expect(committed.checkpoint.syncCursor, 'cursor-1');
      expect(committed.checkpoint.lastChangeSeq, 1);
      expect(committed.checkpoint.transitionVersion, 2);
      expect(
        await database.select(database.conversationRows).getSingle(),
        isA<ConversationRow>().having(
          (row) => row.id,
          'id',
          'pulled-conversation',
        ),
      );
    });

    test('业务写入失败时回滚整页且旧 checkpoint 仍可重试', () async {
      final wireChange = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 91,
      );
      final change = await authenticatePulledValueChange(wireChange);
      final initial = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28),
      );

      await expectLater(
        pullCommands.applyIncrementalPage(
          expected: initial,
          nextCursor: 'cursor-failed',
          lastChangeSeq: 1,
          changes: <E2eeSyncPulledChange>[change],
          now: DateTime.utc(2026, 7, 28, 0, 1),
          applyBusiness: (_) async {
            await insertConversation(id: 'rolled-back-conversation');
            throw StateError('apply-failed');
          },
        ),
        throwsA(isA<StateError>()),
      );

      final persisted = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28, 0, 2),
      );
      expect(persisted.transitionVersion, initial.transitionVersion);
      expect(persisted.syncCursor, equals(null));
      expect(await database.select(database.conversationRows).get(), isEmpty);
    });

    test('CAS 拒绝旧 checkpoint 且不会执行回调', () async {
      final firstWireChange = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 92,
      );
      final secondWireChange = await createPullValueChange(
        changeSeq: 2,
        revision: 1,
        operation: 93,
      );
      final firstChange = await authenticatePulledValueChange(firstWireChange);
      final secondChange = await authenticatePulledValueChange(
        secondWireChange,
      );
      final initial = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28),
      );
      await pullCommands.applyIncrementalPage(
        expected: initial,
        nextCursor: 'cursor-current',
        lastChangeSeq: 1,
        changes: <E2eeSyncPulledChange>[firstChange],
        now: DateTime.utc(2026, 7, 28, 0, 1),
        applyBusiness: (_) async {},
      );
      var callbackRan = false;

      await expectLater(
        pullCommands.applyIncrementalPage(
          expected: initial,
          nextCursor: 'cursor-stale',
          lastChangeSeq: 2,
          changes: <E2eeSyncPulledChange>[secondChange],
          now: DateTime.utc(2026, 7, 28, 0, 2),
          applyBusiness: (_) async {
            callbackRan = true;
          },
        ),
        throwsA(isA<E2eeSyncPullCheckpointStale>()),
      );
      expect(callbackRan, isFalse);
    });

    test('reset、快照续传与末页游标切换保持单一状态', () async {
      final wireChange = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 94,
      );
      final change = await authenticatePulledValueChange(wireChange);
      final initial = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28),
      );
      final snapshot = await pullCommands.enterSnapshot(
        expected: initial,
        snapshotRunId: _syncUuid(70),
        now: DateTime.utc(2026, 7, 28, 0, 1),
      );
      expect(snapshot.phase, E2eeSyncPullPhase.snapshot);
      expect(snapshot.syncCursor, equals(null));
      expect(snapshot.snapshotRunId, _syncUuid(70));
      expect(snapshot.snapshotMaxChangeSeq, 0);

      final middle = await pullCommands.applySnapshotPage(
        expected: snapshot,
        nextSnapshotCursor: 'snapshot-cursor-1',
        snapshotLastRecordId: change.state.recordId.wireValue,
        snapshotMaxChangeSeq: 1,
        finalSyncCursor: null,
        changes: <E2eeSyncPulledChange>[change],
        now: DateTime.utc(2026, 7, 28, 0, 2),
        applyBusiness: (_) async {},
      );
      expect(middle.checkpoint.phase, E2eeSyncPullPhase.snapshot);
      expect(middle.checkpoint.snapshotCursor, 'snapshot-cursor-1');
      expect(
        middle.checkpoint.snapshotLastRecordId,
        change.state.recordId.wireValue,
      );
      expect(middle.checkpoint.snapshotMaxChangeSeq, 1);

      final completed = await pullCommands.applySnapshotPage(
        expected: middle.checkpoint,
        nextSnapshotCursor: null,
        snapshotLastRecordId: change.state.recordId.wireValue,
        snapshotMaxChangeSeq: 1,
        finalSyncCursor: 'sync-cursor-9',
        changes: const <E2eeSyncPulledChange>[],
        now: DateTime.utc(2026, 7, 28, 0, 3),
        applyBusiness: (_) async {},
      );
      expect(completed.checkpoint.phase, E2eeSyncPullPhase.incremental);
      expect(completed.checkpoint.syncCursor, 'sync-cursor-9');
      expect(completed.checkpoint.lastChangeSeq, 1);
      expect(completed.checkpoint.snapshotRunId, equals(null));
      expect(completed.checkpoint.snapshotCursor, equals(null));
      expect(completed.checkpoint.snapshotLastRecordId, equals(null));
      expect(completed.checkpoint.snapshotMaxChangeSeq, equals(null));
    });

    test('SQLite 约束拒绝增量与快照字段混合', () async {
      final createdAt = DateTime.utc(2026, 7, 28);
      await expectLater(
        database
            .into(database.e2eeSyncPullCheckpointRows)
            .insert(
              E2eeSyncPullCheckpointRowsCompanion.insert(
                accountUserId: _syncAccountUserId,
                phase: 'incremental',
                syncCursor: const Value('cursor'),
                lastChangeSeq: 0,
                snapshotRunId: Value(_syncUuid(72)),
                snapshotMaxChangeSeq: const Value(0),
                transitionVersion: 1,
                createdAt: createdAt,
                updatedAt: createdAt,
              ),
            ),
        throwsRemoteSqliteException(),
      );
    });
  });

  group('E2EE sync authenticated snapshot pull commands', () {
    test('中间页原子应用且空终页切回增量阶段', () async {
      final initial = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28),
      );
      final snapshot = await pullCommands.enterSnapshot(
        expected: initial,
        snapshotRunId: _syncUuid(73),
        now: DateTime.utc(2026, 7, 28, 0, 1),
      );
      final wireChange = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 73,
      );
      final change = await authenticatePulledValueChange(wireChange);
      final middle = await pullCommands.applySnapshotPage(
        expected: snapshot,
        nextSnapshotCursor: 'snapshot-page-1',
        snapshotLastRecordId: change.state.recordId.wireValue,
        snapshotMaxChangeSeq: 1,
        finalSyncCursor: null,
        changes: <E2eeSyncPulledChange>[change],
        applyBusiness: (_) => insertConversation(id: 'snapshot-middle'),
        now: DateTime.utc(2026, 7, 28, 0, 2),
      );

      expect(middle.checkpoint.phase, E2eeSyncPullPhase.snapshot);
      expect(middle.checkpoint.snapshotCursor, 'snapshot-page-1');
      expect(
        middle.checkpoint.snapshotLastRecordId,
        change.state.recordId.wireValue,
      );
      expect(middle.checkpoint.snapshotMaxChangeSeq, 1);
      expect(middle.value.receivedCount, 1);
      expect(middle.value.businessApplyCount, 1);
      expect(
        await database.select(database.e2eeSyncRecordStateRows).get(),
        hasLength(1),
      );
      expect(
        (await database.select(database.conversationRows).getSingle()).id,
        'snapshot-middle',
      );

      final completed = await pullCommands.applySnapshotPage(
        expected: middle.checkpoint,
        nextSnapshotCursor: null,
        snapshotLastRecordId: change.state.recordId.wireValue,
        snapshotMaxChangeSeq: 1,
        finalSyncCursor: 'sync-after-snapshot',
        changes: const <E2eeSyncPulledChange>[],
        applyBusiness: (_) async {
          fail('空终页不得执行业务 apply');
        },
        now: DateTime.utc(2026, 7, 28, 0, 3),
      );

      expect(completed.checkpoint.phase, E2eeSyncPullPhase.incremental);
      expect(completed.checkpoint.syncCursor, 'sync-after-snapshot');
      expect(completed.checkpoint.lastChangeSeq, 1);
      expect(completed.checkpoint.snapshotRunId, equals(null));
      expect(completed.checkpoint.snapshotCursor, equals(null));
      expect(completed.checkpoint.snapshotLastRecordId, equals(null));
      expect(completed.checkpoint.snapshotMaxChangeSeq, equals(null));
      expect(completed.value.receivedCount, 0);
      expect(completed.value.businessApplyCount, 0);
    });

    test('同 record 多版本历史严格推进且业务只应用最终状态', () async {
      const entityKey = SyncEntityKey(
        entityType: 'conversation',
        entityId: 'snapshot-history',
      );
      final firstWireChange = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 74,
        entityKey: entityKey,
        payload: _conversationPayload('v1'),
      );
      final firstChange = await authenticatePulledValueChange(firstWireChange);
      final secondWireChange = await createPullValueChange(
        changeSeq: 2,
        revision: 2,
        operation: 75,
        entityKey: entityKey,
        logicalVersion: 2,
        parentDigests: <E2eeAccountRecordStateDigest>[firstChange.state.digest],
        payload: _conversationPayload('v2'),
      );
      final secondChange = await authenticatePulledValueChange(
        secondWireChange,
      );
      final initial = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28),
      );
      final snapshot = await pullCommands.enterSnapshot(
        expected: initial,
        snapshotRunId: _syncUuid(74),
        now: DateTime.utc(2026, 7, 28, 0, 1),
      );

      final completed = await pullCommands.applySnapshotPage(
        expected: snapshot,
        nextSnapshotCursor: null,
        snapshotLastRecordId: secondChange.state.recordId.wireValue,
        snapshotMaxChangeSeq: 2,
        finalSyncCursor: 'sync-after-history',
        changes: <E2eeSyncPulledChange>[firstChange, secondChange],
        applyBusiness: (changes) async {
          expect(changes, hasLength(1));
          expect(changes.single.state.digest, secondChange.state.digest);
          await insertConversation(id: 'snapshot-history-final');
        },
        now: DateTime.utc(2026, 7, 28, 0, 2),
      );

      expect(completed.checkpoint.phase, E2eeSyncPullPhase.incremental);
      expect(completed.checkpoint.syncCursor, 'sync-after-history');
      expect(completed.checkpoint.lastChangeSeq, 2);
      expect(completed.value.receivedCount, 2);
      expect(completed.value.businessApplyCount, 1);
      expect(
        await database.select(database.e2eeSyncRecordStateRows).get(),
        hasLength(2),
      );
      final remote = await database
          .select(database.e2eeSyncRemoteRecordRows)
          .getSingle();
      expect(remote.revision, 2);
      expect(remote.lastChangeSeq, 2);
      expect(
        remote.stateDigest,
        orderedEquals(secondChange.state.digest.bytes),
      );
      expect(
        (await database.select(database.conversationRows).getSingle()).id,
        'snapshot-history-final',
      );
    });

    test('同 record 页内冲突保留冲突前最后可应用状态', () async {
      const entityKey = SyncEntityKey(
        entityType: 'conversation',
        entityId: 'snapshot-conflict-history',
      );
      final genesisWireChange = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 83,
        entityKey: entityKey,
        payload: _conversationPayload('base'),
      );
      final genesisChange = await authenticatePulledValueChange(
        genesisWireChange,
      );
      final firstWireChange = await createPullValueChange(
        changeSeq: 2,
        revision: 2,
        operation: 84,
        entityKey: entityKey,
        logicalVersion: 2,
        parentDigests: <E2eeAccountRecordStateDigest>[
          genesisChange.state.digest,
        ],
        payload: _conversationPayload('stable'),
      );
      final firstChange = await authenticatePulledValueChange(firstWireChange);
      final conflictWireChange = await createPullValueChange(
        changeSeq: 3,
        revision: 3,
        operation: 88,
        entityKey: entityKey,
        logicalVersion: 2,
        parentDigests: <E2eeAccountRecordStateDigest>[
          genesisChange.state.digest,
        ],
        payload: _conversationPayload('conflict'),
      );
      final conflictChange = await authenticatePulledValueChange(
        conflictWireChange,
      );
      final initial = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28),
      );
      final snapshot = await pullCommands.enterSnapshot(
        expected: initial,
        snapshotRunId: _syncUuid(80),
        now: DateTime.utc(2026, 7, 28, 0, 1),
      );

      final completed = await pullCommands.applySnapshotPage(
        expected: snapshot,
        nextSnapshotCursor: null,
        snapshotLastRecordId: conflictChange.state.recordId.wireValue,
        snapshotMaxChangeSeq: 3,
        finalSyncCursor: 'sync-after-conflict-history',
        changes: <E2eeSyncPulledChange>[
          genesisChange,
          firstChange,
          conflictChange,
        ],
        applyBusiness: (changes) async {
          expect(changes, hasLength(1));
          expect(changes.single.state.digest, firstChange.state.digest);
          expect(
            (changes.single as E2eeSyncPulledValueChange).payload['title'],
            'stable',
          );
        },
        now: DateTime.utc(2026, 7, 28, 0, 2),
      );

      expect(completed.value.businessApplyCount, 1);
      expect(
        await database.select(database.e2eeSyncRecordStateRows).get(),
        hasLength(3),
      );
      expect(
        await database.select(database.e2eeSyncRecordHeadRows).get(),
        hasLength(2),
      );
    });

    test('页内 changeSeq 乱序时拒绝整页且保持快照 checkpoint', () async {
      final firstWireChange = await createPullValueChange(
        changeSeq: 2,
        revision: 1,
        operation: 76,
      );
      final secondWireChange = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 77,
      );
      final firstChange = await authenticatePulledValueChange(firstWireChange);
      final secondChange = await authenticatePulledValueChange(
        secondWireChange,
      );
      final initial = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28),
      );
      final snapshot = await pullCommands.enterSnapshot(
        expected: initial,
        snapshotRunId: _syncUuid(75),
        now: DateTime.utc(2026, 7, 28, 0, 1),
      );
      var businessApplyRan = false;

      expect(
        () => pullCommands.applySnapshotPage(
          expected: snapshot,
          nextSnapshotCursor: null,
          snapshotLastRecordId: secondChange.state.recordId.wireValue,
          snapshotMaxChangeSeq: 1,
          finalSyncCursor: 'sync-must-not-commit',
          changes: <E2eeSyncPulledChange>[firstChange, secondChange],
          applyBusiness: (_) async {
            businessApplyRan = true;
          },
          now: DateTime.utc(2026, 7, 28, 0, 2),
        ),
        throwsA(isA<FormatException>()),
      );

      final unchanged = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28, 0, 3),
      );
      expect(unchanged.phase, E2eeSyncPullPhase.snapshot);
      expect(unchanged.snapshotCursor, equals(null));
      expect(unchanged.snapshotMaxChangeSeq, 0);
      expect(unchanged.transitionVersion, snapshot.transitionVersion);
      expect(businessApplyRan, isFalse);
      expect(
        await database.select(database.e2eeSyncRecordStateRows).get(),
        isEmpty,
      );
      expect(
        await database.select(database.e2eeSyncRemoteRecordRows).get(),
        isEmpty,
      );
    });

    test('业务 apply 异常时回滚快照整页与 checkpoint', () async {
      final wireChange = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 78,
      );
      final change = await authenticatePulledValueChange(wireChange);
      final initial = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28),
      );
      final snapshot = await pullCommands.enterSnapshot(
        expected: initial,
        snapshotRunId: _syncUuid(76),
        now: DateTime.utc(2026, 7, 28, 0, 1),
      );

      await expectLater(
        pullCommands.applySnapshotPage(
          expected: snapshot,
          nextSnapshotCursor: 'snapshot-must-not-commit',
          snapshotLastRecordId: change.state.recordId.wireValue,
          snapshotMaxChangeSeq: 1,
          finalSyncCursor: null,
          changes: <E2eeSyncPulledChange>[change],
          applyBusiness: (_) async {
            await insertConversation(id: 'snapshot-rolled-back');
            throw StateError('snapshot-apply-failed');
          },
          now: DateTime.utc(2026, 7, 28, 0, 2),
        ),
        throwsA(isA<StateError>()),
      );

      final unchanged = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28, 0, 3),
      );
      expect(unchanged.phase, E2eeSyncPullPhase.snapshot);
      expect(unchanged.snapshotCursor, equals(null));
      expect(unchanged.snapshotMaxChangeSeq, 0);
      expect(unchanged.transitionVersion, snapshot.transitionVersion);
      expect(
        await database.select(database.e2eeSyncRecordStateRows).get(),
        isEmpty,
      );
      expect(
        await database.select(database.e2eeSyncRemoteRecordRows).get(),
        isEmpty,
      );
      expect(await database.select(database.conversationRows).get(), isEmpty);
    });
  });

  group('E2EE sync authenticated pull coordinator', () {
    test('认证整页后原子提交 ledger、业务数据与 checkpoint', () async {
      final valueChange = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 60,
        payload: _conversationPayload('pulled-conversation'),
      );
      final tombstoneChange = await createPullTombstoneChange(
        changeSeq: 2,
        revision: 1,
        operation: 61,
      );
      final transport = _FakeAuthenticatedPullTransport(
        accountUserId: _syncAccountUserId,
        onPull: (cursor, limit) async {
          expect(cursor, equals(null));
          expect(limit, 10);
          return CloudSyncChangePage(
            changes: <CloudSyncRecordChange>[valueChange, tombstoneChange],
            nextCursor: 'cursor-pull-2',
            hasMore: false,
          );
        },
      );
      final coordinator = createPullCoordinator(
        transport: transport,
        applyPage: (changes) async {
          expect(changes, hasLength(2));
          final value = changes.first;
          expect(value, isA<E2eeSyncPulledValueChange>());
          expect(
            (value as E2eeSyncPulledValueChange).payload['title'],
            'pulled-conversation',
          );
          expect(changes.last, isA<E2eeSyncPulledTombstoneChange>());
          await insertConversation(id: 'pulled-conversation');
        },
      );

      final report = await coordinator.pullOnce();

      expect(report.disposition, E2eeSyncPullDisposition.applied);
      expect(report.received, 2);
      expect(report.hasMore, isFalse);
      expect(report.checkpoint.syncCursor, 'cursor-pull-2');
      expect(report.checkpoint.lastChangeSeq, 2);
      expect(
        await database.select(database.e2eeSyncRecordStateRows).get(),
        hasLength(2),
      );
      expect(
        (await database.select(database.conversationRows).getSingle()).id,
        'pulled-conversation',
      );
    });

    test('本地 ledger 已推进时旧增量只推进 checkpoint 且不回滚业务', () async {
      const entityKey = SyncEntityKey(
        entityType: 'conversation',
        entityId: 'pull-stale-replay',
      );
      final firstChange = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 65,
        entityKey: entityKey,
        payload: _conversationPayload('v1'),
      );
      final firstState = await authenticatePullChange(firstChange);
      final secondChange = await createPullValueChange(
        changeSeq: 2,
        revision: 2,
        operation: 66,
        entityKey: entityKey,
        logicalVersion: 2,
        parentDigests: <E2eeAccountRecordStateDigest>[firstState.digest],
        payload: _conversationPayload('v2'),
      );
      final secondState = await authenticatePullChange(secondChange);
      await ledger.accept(firstState);
      await ledger.accept(secondState);
      await insertSyncRemoteRecord(
        recordId: secondState.recordId.wireValue,
        revision: 2,
        lastChangeSeq: 2,
        stateDigest: secondState.digest.bytes,
      );
      var businessApplyRan = false;
      final coordinator = createPullCoordinator(
        transport: _FakeAuthenticatedPullTransport(
          accountUserId: _syncAccountUserId,
          onPull: (_, _) async => CloudSyncChangePage(
            changes: <CloudSyncRecordChange>[firstChange],
            nextCursor: 'cursor-stale-replay',
            hasMore: false,
          ),
        ),
        applyPage: (_) async {
          businessApplyRan = true;
        },
      );

      final report = await coordinator.pullOnce();

      expect(businessApplyRan, isFalse);
      expect(report.checkpoint.syncCursor, 'cursor-stale-replay');
      expect(report.checkpoint.lastChangeSeq, 1);
      final remote = await database
          .select(database.e2eeSyncRemoteRecordRows)
          .getSingle();
      expect(remote.revision, 2);
      expect(remote.lastChangeSeq, 2);
      expect(remote.stateDigest, orderedEquals(secondState.digest.bytes));
    });

    test('同实体 intent 或同 record outbox 存在时保留本地业务值', () async {
      const intentEntityKey = SyncEntityKey(
        entityType: 'conversation',
        entityId: 'pull-pending-intent',
      );
      const outboxEntityKey = SyncEntityKey(
        entityType: 'conversation',
        entityId: 'pull-pending-outbox',
      );
      final intentChange = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 67,
        entityKey: intentEntityKey,
      );
      final outboxChange = await createPullValueChange(
        changeSeq: 2,
        revision: 1,
        operation: 68,
        entityKey: outboxEntityKey,
      );
      final outboxState = await authenticatePullChange(outboxChange);
      await insertSyncIntent(
        entityType: intentEntityKey.entityType,
        entityId: intentEntityKey.entityId,
        intentId: _syncUuid(601),
      );
      final pendingOperationId = _syncUuid(602);
      await insertSyncOperation(
        operationId: pendingOperationId,
        stateDigest: _syncDigest(22),
        recordId: outboxState.recordId.wireValue,
        entityType: outboxEntityKey.entityType,
        entityId: outboxEntityKey.entityId,
        intentId: _syncUuid(603),
      );
      await insertSyncOutbox(
        operationId: pendingOperationId,
        recordId: outboxState.recordId.wireValue,
      );
      var businessApplyRan = false;
      final coordinator = createPullCoordinator(
        transport: _FakeAuthenticatedPullTransport(
          accountUserId: _syncAccountUserId,
          onPull: (_, _) async => CloudSyncChangePage(
            changes: <CloudSyncRecordChange>[intentChange, outboxChange],
            nextCursor: 'cursor-local-pending',
            hasMore: false,
          ),
        ),
        applyPage: (_) async {
          businessApplyRan = true;
        },
      );

      final report = await coordinator.pullOnce();

      expect(businessApplyRan, isFalse);
      expect(report.checkpoint.lastChangeSeq, 2);
      expect(
        await database.select(database.e2eeSyncRecordStateRows).get(),
        hasLength(2),
      );
      expect(
        await database.select(database.e2eeSyncRemoteRecordRows).get(),
        hasLength(2),
      );
      expect(
        await database.select(database.e2eeSyncIntentRows).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.e2eeSyncOutboxRows).get(),
        hasLength(1),
      );
    });

    test('同 record 的远端 revision 跳号时整页 ledger 与 checkpoint 回滚', () async {
      const entityKey = SyncEntityKey(
        entityType: 'conversation',
        entityId: 'pull-invalid-metadata',
      );
      final firstChange = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 69,
        entityKey: entityKey,
      );
      final firstState = await authenticatePullChange(firstChange);
      final skippedRevision = await createPullValueChange(
        changeSeq: 2,
        revision: 3,
        operation: 70,
        entityKey: entityKey,
        logicalVersion: 2,
        parentDigests: <E2eeAccountRecordStateDigest>[firstState.digest],
      );
      var businessApplyRan = false;
      final coordinator = createPullCoordinator(
        transport: _FakeAuthenticatedPullTransport(
          accountUserId: _syncAccountUserId,
          onPull: (_, _) async => CloudSyncChangePage(
            changes: <CloudSyncRecordChange>[firstChange, skippedRevision],
            nextCursor: 'cursor-invalid-metadata',
            hasMore: false,
          ),
        ),
        applyPage: (_) async {
          businessApplyRan = true;
        },
      );

      await expectLater(
        coordinator.pullOnce(),
        throwsA(isA<FormatException>()),
      );

      expect(businessApplyRan, isFalse);
      expect(
        await database.select(database.e2eeSyncRecordStateRows).get(),
        isEmpty,
      );
      expect(
        await database.select(database.e2eeSyncRemoteRecordRows).get(),
        isEmpty,
      );
      final checkpoint = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28, 0, 1),
      );
      expect(checkpoint.syncCursor, equals(null));
      expect(checkpoint.lastChangeSeq, 0);
      expect(checkpoint.transitionVersion, 1);
    });

    test('业务 apply 抛错时回滚 ledger、业务数据与 checkpoint', () async {
      final change = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 62,
      );
      final transport = _FakeAuthenticatedPullTransport(
        accountUserId: _syncAccountUserId,
        onPull: (_, _) async => CloudSyncChangePage(
          changes: <CloudSyncRecordChange>[change],
          nextCursor: 'cursor-must-rollback',
          hasMore: false,
        ),
      );
      final coordinator = createPullCoordinator(
        transport: transport,
        applyPage: (changes) async {
          await insertConversation(id: 'rolled-back-pull');
          throw StateError('apply-failed');
        },
      );

      await expectLater(coordinator.pullOnce(), throwsA(isA<StateError>()));

      final checkpoint = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28, 0, 1),
      );
      expect(checkpoint.syncCursor, equals(null));
      expect(checkpoint.lastChangeSeq, 0);
      expect(checkpoint.transitionVersion, 1);
      expect(
        await database.select(database.e2eeSyncRecordStateRows).get(),
        isEmpty,
      );
      expect(await database.select(database.conversationRows).get(), isEmpty);
    });

    test('事务前准备 pending 时保持整页 checkpoint 且不执行业务写入', () async {
      final change = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 162,
      );
      final preparer = _FakePullPagePreparer(
        E2eeSyncPullPagePreparationDisposition.pending,
      );
      var businessApplyRan = false;
      final coordinator = createPullCoordinator(
        transport: _FakeAuthenticatedPullTransport(
          accountUserId: _syncAccountUserId,
          onPull: (_, _) async => CloudSyncChangePage(
            changes: <CloudSyncRecordChange>[change],
            nextCursor: 'preparation-pending-must-not-commit',
            hasMore: false,
          ),
        ),
        pagePreparer: preparer,
        maximumPreparationRemoteSteps: 3,
        applyPage: (_) async {
          businessApplyRan = true;
        },
      );

      final report = await coordinator.pullOnce();

      expect(report.disposition, E2eeSyncPullDisposition.preparationPending);
      expect(report.hasMore, isTrue);
      expect(report.checkpoint.syncCursor, equals(null));
      expect(report.checkpoint.lastChangeSeq, 0);
      expect(preparer.maximumRemoteSteps, <int>[3]);
      expect(preparer.pages.single, hasLength(1));
      expect(businessApplyRan, isFalse);
      expect(
        await database.select(database.e2eeSyncRecordStateRows).get(),
        isEmpty,
      );
      expect(
        await database.select(database.e2eeSyncRemoteRecordRows).get(),
        isEmpty,
      );
    });

    test('事务前网络预算耗尽时不调用下一网络步骤且保持 checkpoint', () async {
      final change = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 164,
      );
      final preparer = _BudgetConsumingPullPagePreparer();
      var businessApplyRan = false;
      final coordinator = createPullCoordinator(
        transport: _FakeAuthenticatedPullTransport(
          accountUserId: _syncAccountUserId,
          onPull: (_, _) async => CloudSyncChangePage(
            changes: <CloudSyncRecordChange>[change],
            nextCursor: 'budget-exhausted-must-not-commit',
            hasMore: false,
          ),
        ),
        pagePreparer: preparer,
        applyPage: (_) async {
          businessApplyRan = true;
        },
      );
      final budget = E2eeSyncExecutionBudget(
        maximumNetworkSteps: 1,
        maximumAttachmentBytes: 0,
        maximumDuration: const Duration(seconds: 5),
        abortInFlightNetwork: () {},
      );

      await expectLater(
        coordinator.pullOnce(executionBudget: budget),
        throwsA(
          isA<E2eeSyncBudgetExhausted>().having(
            (error) => error.reason,
            'reason',
            E2eeSyncBudgetExhaustion.networkSteps,
          ),
        ),
      );

      expect(budget.networkStepsConsumed, 1);
      expect(preparer.remoteCalls, 0);
      expect(businessApplyRan, isFalse);
      final checkpoint = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28, 0, 2),
      );
      expect(checkpoint.syncCursor, equals(null));
      expect(checkpoint.lastChangeSeq, 0);
      expect(checkpoint.transitionVersion, 1);
      expect(
        await database.select(database.e2eeSyncRecordStateRows).get(),
        isEmpty,
      );
      expect(
        await database.select(database.e2eeSyncRemoteRecordRows).get(),
        isEmpty,
      );
    });

    test('事务前准备遇到未来附件世代时复用密钥暂停语义', () async {
      final change = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 163,
      );
      var businessApplyRan = false;
      final coordinator = createPullCoordinator(
        transport: _FakeAuthenticatedPullTransport(
          accountUserId: _syncAccountUserId,
          onPull: (_, _) async => CloudSyncChangePage(
            changes: <CloudSyncRecordChange>[change],
            nextCursor: 'attachment-future-epoch-must-not-commit',
            hasMore: false,
          ),
        ),
        pagePreparer: _FakePullPagePreparer(
          E2eeSyncPullPagePreparationDisposition.keyEpochUnavailable,
        ),
        applyPage: (_) async {
          businessApplyRan = true;
        },
      );

      final report = await coordinator.pullOnce();

      expect(report.disposition, E2eeSyncPullDisposition.keyEpochUnavailable);
      expect(report.checkpoint.syncCursor, equals(null));
      expect(report.checkpoint.transitionVersion, 1);
      expect(businessApplyRan, isFalse);
    });

    test('reset 后按快照游标续传同 record 历史并切回增量', () async {
      const entityKey = SyncEntityKey(
        entityType: 'conversation',
        entityId: 'coordinator-snapshot-history',
      );
      final firstWireChange = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 79,
        entityKey: entityKey,
      );
      final firstState = await authenticatePullChange(firstWireChange);
      final secondWireChange = await createPullValueChange(
        changeSeq: 2,
        revision: 2,
        operation: 80,
        entityKey: entityKey,
        logicalVersion: 2,
        parentDigests: <E2eeAccountRecordStateDigest>[firstState.digest],
      );
      final firstRecord = snapshotRecordFromChange(firstWireChange);
      final secondRecord = snapshotRecordFromChange(secondWireChange);
      final transport = _FakeAuthenticatedPullTransport(
        accountUserId: _syncAccountUserId,
        onPull: (_, _) async => const CloudSyncResetRequired(),
        onSnapshot: (cursor, limit) async {
          expect(limit, 10);
          if (cursor == null) {
            return CloudSyncSnapshotPage(
              records: <CloudSyncEncryptedRecord>[firstRecord],
              nextSnapshotCursor: 'snapshot-page-1',
              syncCursor: null,
              hasMore: true,
            );
          }
          expect(cursor, 'snapshot-page-1');
          return CloudSyncSnapshotPage(
            records: <CloudSyncEncryptedRecord>[secondRecord],
            nextSnapshotCursor: null,
            syncCursor: 'snapshot-ready-cursor',
            hasMore: false,
          );
        },
      );
      final appliedVersions = <int>[];
      final coordinator = createPullCoordinator(
        transport: transport,
        applyPage: (changes) async {
          expect(changes, hasLength(1));
          appliedVersions.add(changes.single.state.logicalVersion);
        },
      );

      final reset = await coordinator.pullOnce();
      final middle = await coordinator.pullOnce();
      final completed = await coordinator.pullOnce();

      expect(reset.disposition, E2eeSyncPullDisposition.resetToSnapshot);
      expect(reset.checkpoint.phase, E2eeSyncPullPhase.snapshot);
      expect(reset.checkpoint.syncCursor, equals(null));
      expect(reset.checkpoint.snapshotRunId, isA<String>());
      expect(middle.disposition, E2eeSyncPullDisposition.snapshotApplied);
      expect(middle.checkpoint.phase, E2eeSyncPullPhase.snapshot);
      expect(middle.checkpoint.snapshotCursor, 'snapshot-page-1');
      expect(middle.checkpoint.snapshotMaxChangeSeq, 1);
      expect(completed.disposition, E2eeSyncPullDisposition.snapshotCompleted);
      expect(completed.checkpoint.phase, E2eeSyncPullPhase.incremental);
      expect(completed.checkpoint.syncCursor, 'snapshot-ready-cursor');
      expect(completed.checkpoint.lastChangeSeq, 2);
      expect(appliedVersions, <int>[1, 2]);
      expect(transport.callCount, 1);
      expect(transport.snapshotCallCount, 2);
      expect(transport.snapshotCursors, <String?>[null, 'snapshot-page-1']);
      expect(
        await database.select(database.e2eeSyncRecordStateRows).get(),
        hasLength(2),
      );
      final remote = await database
          .select(database.e2eeSyncRemoteRecordRows)
          .getSingle();
      expect(remote.revision, 2);
      expect(remote.lastChangeSeq, 2);
    });

    test('快照遇到未来 key epoch 时保持 checkpoint 不变', () async {
      final wireChange = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 81,
        keyEpoch: stateCodec.currentKeyEpoch + 1,
      );
      final initial = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28),
      );
      final snapshot = await pullCommands.enterSnapshot(
        expected: initial,
        snapshotRunId: _syncUuid(77),
        now: DateTime.utc(2026, 7, 28, 0, 1),
      );
      var businessApplyRan = false;
      final transport = _FakeAuthenticatedPullTransport(
        accountUserId: _syncAccountUserId,
        onPull: (_, _) async => throw StateError('快照阶段不得拉取增量'),
        onSnapshot: (_, _) async => CloudSyncSnapshotPage(
          records: <CloudSyncEncryptedRecord>[
            snapshotRecordFromChange(wireChange),
          ],
          nextSnapshotCursor: null,
          syncCursor: 'future-epoch-must-not-commit',
          hasMore: false,
        ),
      );
      final coordinator = createPullCoordinator(
        transport: transport,
        applyPage: (_) async {
          businessApplyRan = true;
        },
      );

      final report = await coordinator.pullOnce();

      expect(report.disposition, E2eeSyncPullDisposition.keyEpochUnavailable);
      expect(report.checkpoint.phase, E2eeSyncPullPhase.snapshot);
      expect(report.checkpoint.snapshotCursor, snapshot.snapshotCursor);
      expect(
        report.checkpoint.snapshotMaxChangeSeq,
        snapshot.snapshotMaxChangeSeq,
      );
      expect(report.checkpoint.transitionVersion, snapshot.transitionVersion);
      expect(transport.callCount, 0);
      expect(transport.snapshotCallCount, 1);
      expect(businessApplyRan, isFalse);
      expect(
        await database.select(database.e2eeSyncRecordStateRows).get(),
        isEmpty,
      );
      expect(
        await database.select(database.e2eeSyncRemoteRecordRows).get(),
        isEmpty,
      );
    });

    test('快照空中间页在认证前拒绝且不推进 checkpoint', () async {
      final initial = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28),
      );
      final snapshot = await pullCommands.enterSnapshot(
        expected: initial,
        snapshotRunId: _syncUuid(78),
        now: DateTime.utc(2026, 7, 28, 0, 1),
      );
      var businessApplyRan = false;
      final transport = _FakeAuthenticatedPullTransport(
        accountUserId: _syncAccountUserId,
        onPull: (_, _) async => throw StateError('快照阶段不得拉取增量'),
        onSnapshot: (_, _) async => const CloudSyncSnapshotPage(
          records: <CloudSyncEncryptedRecord>[],
          nextSnapshotCursor: 'invalid-empty-middle',
          syncCursor: null,
          hasMore: true,
        ),
      );
      final coordinator = createPullCoordinator(
        transport: transport,
        applyPage: (_) async {
          businessApplyRan = true;
        },
      );

      await expectLater(
        coordinator.pullOnce(),
        throwsA(isA<FormatException>()),
      );

      final unchanged = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28, 0, 2),
      );
      expect(unchanged.phase, E2eeSyncPullPhase.snapshot);
      expect(unchanged.snapshotCursor, equals(null));
      expect(unchanged.snapshotMaxChangeSeq, 0);
      expect(unchanged.transitionVersion, snapshot.transitionVersion);
      expect(transport.snapshotCallCount, 1);
      expect(businessApplyRan, isFalse);
      expect(
        await database.select(database.e2eeSyncRecordStateRows).get(),
        isEmpty,
      );
    });

    test('快照跨页 changeSeq 回退时保留上一页原子结果', () async {
      final wireChange = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 82,
      );
      final record = snapshotRecordFromChange(wireChange);
      final initial = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28),
      );
      await pullCommands.enterSnapshot(
        expected: initial,
        snapshotRunId: _syncUuid(79),
        now: DateTime.utc(2026, 7, 28, 0, 1),
      );
      final transport = _FakeAuthenticatedPullTransport(
        accountUserId: _syncAccountUserId,
        onPull: (_, _) async => throw StateError('快照阶段不得拉取增量'),
        onSnapshot: (cursor, _) async {
          if (cursor == null) {
            return CloudSyncSnapshotPage(
              records: <CloudSyncEncryptedRecord>[record],
              nextSnapshotCursor: 'snapshot-cross-page-1',
              syncCursor: null,
              hasMore: true,
            );
          }
          expect(cursor, 'snapshot-cross-page-1');
          return CloudSyncSnapshotPage(
            records: <CloudSyncEncryptedRecord>[record],
            nextSnapshotCursor: null,
            syncCursor: 'cross-page-must-not-commit',
            hasMore: false,
          );
        },
      );
      var businessApplyCount = 0;
      final coordinator = createPullCoordinator(
        transport: transport,
        applyPage: (_) async {
          businessApplyCount++;
        },
      );

      final firstPage = await coordinator.pullOnce();
      await expectLater(
        coordinator.pullOnce(),
        throwsA(isA<FormatException>()),
      );

      final unchanged = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28, 0, 3),
      );
      expect(firstPage.disposition, E2eeSyncPullDisposition.snapshotApplied);
      expect(unchanged.phase, E2eeSyncPullPhase.snapshot);
      expect(unchanged.snapshotCursor, 'snapshot-cross-page-1');
      expect(unchanged.snapshotMaxChangeSeq, 1);
      expect(
        unchanged.transitionVersion,
        firstPage.checkpoint.transitionVersion,
      );
      expect(transport.snapshotCursors, <String?>[
        null,
        'snapshot-cross-page-1',
      ]);
      expect(businessApplyCount, 1);
      expect(
        await database.select(database.e2eeSyncRecordStateRows).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.e2eeSyncRemoteRecordRows).get(),
        hasLength(1),
      );
    });

    test('未来 key epoch 保留旧 checkpoint 且不进入业务 apply', () async {
      final change = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 63,
        keyEpoch: stateCodec.currentKeyEpoch + 1,
      );
      var applyRan = false;
      final transport = _FakeAuthenticatedPullTransport(
        accountUserId: _syncAccountUserId,
        onPull: (_, _) async => CloudSyncChangePage(
          changes: <CloudSyncRecordChange>[change],
          nextCursor: 'future-key-cursor',
          hasMore: false,
        ),
      );
      final coordinator = createPullCoordinator(
        transport: transport,
        applyPage: (_) async {
          applyRan = true;
        },
      );

      final report = await coordinator.pullOnce();

      expect(report.disposition, E2eeSyncPullDisposition.keyEpochUnavailable);
      expect(report.checkpoint.syncCursor, equals(null));
      expect(report.checkpoint.lastChangeSeq, 0);
      expect(applyRan, isFalse);
    });

    test('认证通过但 payload 非规范时拒绝整页且不推进 checkpoint', () async {
      final change = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 64,
        encodedPayload: Uint8List.fromList(
          '{"payload":{"id":"bad"},"recordType":"conversation","version":1}'
              .codeUnits,
        ),
      );
      var applyRan = false;
      final transport = _FakeAuthenticatedPullTransport(
        accountUserId: _syncAccountUserId,
        onPull: (_, _) async => CloudSyncChangePage(
          changes: <CloudSyncRecordChange>[change],
          nextCursor: 'malformed-payload-cursor',
          hasMore: false,
        ),
      );
      final coordinator = createPullCoordinator(
        transport: transport,
        applyPage: (_) async {
          applyRan = true;
        },
      );

      await expectLater(
        coordinator.pullOnce(),
        throwsA(isA<FormatException>()),
      );

      final checkpoint = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28, 0, 1),
      );
      expect(checkpoint.syncCursor, equals(null));
      expect(checkpoint.lastChangeSeq, 0);
      expect(applyRan, isFalse);
    });

    test('认证墓碑的未知实体类型拒绝整页且不进入业务 apply', () async {
      final change = await createPullTombstoneChange(
        changeSeq: 1,
        revision: 1,
        operation: 95,
        entityKey: const SyncEntityKey(
          entityType: 'unknown-record',
          entityId: 'unknown-1',
        ),
      );
      var applyRan = false;
      final coordinator = createPullCoordinator(
        transport: _FakeAuthenticatedPullTransport(
          accountUserId: _syncAccountUserId,
          onPull: (_, _) async => CloudSyncChangePage(
            changes: <CloudSyncRecordChange>[change],
            nextCursor: 'unknown-tombstone-must-not-commit',
            hasMore: false,
          ),
        ),
        applyPage: (_) async {
          applyRan = true;
        },
      );

      await expectLater(
        coordinator.pullOnce(),
        throwsA(isA<FormatException>()),
      );

      final checkpoint = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28, 0, 1),
      );
      expect(checkpoint.syncCursor, equals(null));
      expect(checkpoint.lastChangeSeq, 0);
      expect(applyRan, isFalse);
    });

    test('抽象 transport 拒绝空续页', () async {
      const invalidPage = CloudSyncChangePage(
        changes: <CloudSyncRecordChange>[],
        nextCursor: 'invalid-empty-page-cursor',
        hasMore: true,
      );
      var applyRan = false;
      final coordinator = createPullCoordinator(
        transport: _FakeAuthenticatedPullTransport(
          accountUserId: _syncAccountUserId,
          onPull: (_, _) async => invalidPage,
        ),
        applyPage: (_) async {
          applyRan = true;
        },
      );

      await expectLater(
        coordinator.pullOnce(),
        throwsA(isA<FormatException>()),
      );

      final checkpoint = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28, 0, 1),
      );
      expect(checkpoint.syncCursor, equals(null));
      expect(checkpoint.lastChangeSeq, 0);
      expect(applyRan, isFalse);
      expect(
        await database.select(database.e2eeSyncRecordStateRows).get(),
        isEmpty,
      );
      expect(
        await database.select(database.e2eeSyncRemoteRecordRows).get(),
        isEmpty,
      );
    });

    test('非空增量页拒绝原地游标且保持已提交 checkpoint', () async {
      final change = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 85,
      );
      final transport = _FakeAuthenticatedPullTransport(
        accountUserId: _syncAccountUserId,
        onPull: (cursor, _) async {
          if (cursor == null) {
            return const CloudSyncChangePage(
              changes: <CloudSyncRecordChange>[],
              nextCursor: 'incremental-stuck',
              hasMore: false,
            );
          }
          expect(cursor, 'incremental-stuck');
          return CloudSyncChangePage(
            changes: <CloudSyncRecordChange>[change],
            nextCursor: 'incremental-stuck',
            hasMore: false,
          );
        },
      );
      var businessApplyRan = false;
      final coordinator = createPullCoordinator(
        transport: transport,
        applyPage: (_) async {
          businessApplyRan = true;
        },
      );

      final idle = await coordinator.pullOnce();
      await expectLater(
        coordinator.pullOnce(),
        throwsA(isA<FormatException>()),
      );

      final unchanged = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28, 0, 2),
      );
      expect(idle.disposition, E2eeSyncPullDisposition.idle);
      expect(unchanged.syncCursor, 'incremental-stuck');
      expect(unchanged.lastChangeSeq, 0);
      expect(unchanged.transitionVersion, idle.checkpoint.transitionVersion);
      expect(businessApplyRan, isFalse);
    });

    test('非空快照页拒绝原地游标且保留上一页结果', () async {
      final firstWireChange = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 86,
      );
      final secondWireChange = await createPullValueChange(
        changeSeq: 2,
        revision: 1,
        operation: 87,
      );
      final initial = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28),
      );
      await pullCommands.enterSnapshot(
        expected: initial,
        snapshotRunId: _syncUuid(81),
        now: DateTime.utc(2026, 7, 28, 0, 1),
      );
      final transport = _FakeAuthenticatedPullTransport(
        accountUserId: _syncAccountUserId,
        onPull: (_, _) async => throw StateError('快照阶段不得拉取增量'),
        onSnapshot: (cursor, _) async {
          if (cursor == null) {
            return CloudSyncSnapshotPage(
              records: <CloudSyncEncryptedRecord>[
                snapshotRecordFromChange(firstWireChange),
              ],
              nextSnapshotCursor: 'snapshot-stuck',
              syncCursor: null,
              hasMore: true,
            );
          }
          expect(cursor, 'snapshot-stuck');
          return CloudSyncSnapshotPage(
            records: <CloudSyncEncryptedRecord>[
              snapshotRecordFromChange(secondWireChange),
            ],
            nextSnapshotCursor: 'snapshot-stuck',
            syncCursor: null,
            hasMore: true,
          );
        },
      );
      var businessApplyCount = 0;
      final coordinator = createPullCoordinator(
        transport: transport,
        applyPage: (_) async {
          businessApplyCount++;
        },
      );

      final first = await coordinator.pullOnce();
      await expectLater(
        coordinator.pullOnce(),
        throwsA(isA<FormatException>()),
      );

      final unchanged = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28, 0, 3),
      );
      expect(first.disposition, E2eeSyncPullDisposition.snapshotApplied);
      expect(unchanged.snapshotCursor, 'snapshot-stuck');
      expect(unchanged.snapshotMaxChangeSeq, 1);
      expect(unchanged.transitionVersion, first.checkpoint.transitionVersion);
      expect(businessApplyCount, 1);
    });

    test('并发 pull 严格串行且后一个请求使用已提交游标', () async {
      final firstChange = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 71,
      );
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final transport = _FakeAuthenticatedPullTransport(
        accountUserId: _syncAccountUserId,
        onPull: (cursor, _) async {
          if (cursor == null) {
            firstStarted.complete();
            await releaseFirst.future;
            return CloudSyncChangePage(
              changes: <CloudSyncRecordChange>[firstChange],
              nextCursor: 'serialized-cursor-1',
              hasMore: true,
            );
          }
          expect(cursor, 'serialized-cursor-1');
          return const CloudSyncChangePage(
            changes: <CloudSyncRecordChange>[],
            nextCursor: 'serialized-cursor-2',
            hasMore: false,
          );
        },
      );
      final coordinator = createPullCoordinator(
        transport: transport,
        applyPage: (_) async {},
      );

      final first = coordinator.pullOnce();
      await firstStarted.future;
      final second = coordinator.pullOnce();
      await Future<void>.delayed(Duration.zero);
      expect(transport.callCount, 1);

      releaseFirst.complete();
      await Future.wait(<Future<E2eeSyncPullReport>>[first, second]);

      expect(transport.cursors, <String?>[null, 'serialized-cursor-1']);
      final checkpoint = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28, 0, 1),
      );
      expect(checkpoint.syncCursor, 'serialized-cursor-2');
      expect(checkpoint.transitionVersion, 3);
    });
  });

  group('E2EE chat sync adapter', () {
    test('逆序六实体按依赖提交且只在 checkpoint 提交后发布', () async {
      const conversationId = 'adapter-conversation';
      const turnId = 'adapter-turn';
      const messageId = 'adapter-message';
      const groupId = 'adapter-group';
      const keys = <SyncEntityKey>[
        SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.thoughtSignature,
          entityId: messageId,
        ),
        SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.toolEvent,
          entityId: messageId,
        ),
        SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.messageSelection,
          entityId: groupId,
        ),
        SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.message,
          entityId: messageId,
        ),
        SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.turn,
          entityId: turnId,
        ),
        SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.conversation,
          entityId: conversationId,
        ),
      ];
      final payloads = <Map<String, Object?>>[
        <String, Object?>{'messageId': messageId, 'signature': 'signature-1'},
        <String, Object?>{
          'messageId': messageId,
          'events': <Object?>[
            <String, Object?>{'id': 'tool-1', 'name': 'search'},
          ],
        },
        <String, Object?>{
          'conversationId': conversationId,
          'groupId': groupId,
          'selectedVersion': 0,
        },
        _messagePayload(
          conversationId: conversationId,
          turnId: turnId,
          groupId: groupId,
        ),
        _turnPayload(conversationId),
        _conversationPayload('Adapter conversation'),
      ];
      final changes = <E2eeSyncPulledChange>[];
      for (var index = 0; index < keys.length; index++) {
        final wire = await createPullValueChange(
          changeSeq: index + 1,
          revision: 1,
          operation: 820 + index,
          entityKey: keys[index],
          payload: payloads[index],
        );
        changes.add(await authenticatePulledValueChange(wire));
      }

      var publishCount = 0;
      Future<T> runPullBatch<T>({
        required Future<T> Function() pull,
        required bool Function() shouldRefresh,
        required bool Function() mayHaveOrphanedAssets,
      }) async {
        final result = await pull();
        if (shouldRefresh()) {
          final checkpoint = await pullCommands.readOrCreate(
            accountUserId: _syncAccountUserId,
            now: DateTime.utc(2026, 7, 28, 0, 2),
          );
          expect(checkpoint.lastChangeSeq, keys.length);
          expect(await repository.getMessage(messageId), isNot(equals(null)));
          expect(mayHaveOrphanedAssets(), isFalse);
          publishCount++;
        }
        return result;
      }

      final adapter = E2eeChatSyncAdapter(
        repository: repository,
        runPullBatch: runPullBatch,
        attachmentReadiness: const E2eeNoAttachmentMessageReadiness(),
      );
      final initial = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28),
      );

      await adapter.runPullAndPublish(
        () => pullCommands.applyIncrementalPage(
          expected: initial,
          nextCursor: 'adapter-cursor',
          lastChangeSeq: keys.length,
          changes: changes,
          applyBusiness: adapter.applyTransactional,
          now: DateTime.utc(2026, 7, 28, 0, 1),
        ),
      );

      expect(publishCount, 1);
      expect(
        await repository.getGeminiThoughtSignature(messageId),
        'signature-1',
      );
      expect(await repository.getToolEvents(messageId), hasLength(1));
      expect(
        (await repository.getConversation(
          conversationId,
        ))?.versionSelections[groupId],
        0,
      );
      expect(await database.select(database.e2eeSyncIntentRows).get(), isEmpty);
      expect(await database.select(database.e2eeSyncOutboxRows).get(), isEmpty);
      for (var index = 0; index < keys.length; index++) {
        final snapshot = await adapter.readSnapshot(keys[index]);
        expect(snapshot, isA<E2eeSyncValueSnapshot>());
        final decoded = E2eeSyncPayloadCodec.decode(
          entityKey: keys[index],
          bytes: (snapshot as E2eeSyncValueSnapshot).payload,
        );
        expect(decoded, payloads[index]);
      }
    });

    test('ready 附件与消息在同一 pull 事务落库完整远端身份', () async {
      const conversationId = 'ready-attachment-conversation';
      const turnId = 'ready-attachment-turn';
      const messageId = 'ready-attachment-message';
      const groupId = 'ready-attachment-group';
      const attachmentId = '11000000-0000-4000-8000-000000000001';
      const uploadId = '12000000-0000-4000-8000-000000000001';
      const contentHash =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const keys = <SyncEntityKey>[
        SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.conversation,
          entityId: conversationId,
        ),
        SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.turn,
          entityId: turnId,
        ),
        SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.message,
          entityId: messageId,
        ),
      ];
      final payloads = <Map<String, Object?>>[
        _conversationPayload('Ready attachment conversation'),
        _turnPayload(conversationId),
        _messagePayload(
          conversationId: conversationId,
          turnId: turnId,
          groupId: groupId,
          attachments: const <Object?>[
            <String, Object?>{
              'attachmentId': attachmentId,
              'uploadId': uploadId,
              'chunkKeyEpoch': 7,
              'manifestKeyEpoch': 7,
              'manifestRevision': 1,
              'kind': 'file',
              'order': 0,
            },
          ],
        ),
      ];
      final changes = <E2eeSyncPulledChange>[];
      for (var index = 0; index < keys.length; index++) {
        final wire = await createPullValueChange(
          changeSeq: index + 1,
          revision: 1,
          operation: 860 + index,
          entityKey: keys[index],
          payload: payloads[index],
        );
        changes.add(await authenticatePulledValueChange(wire));
      }
      final readiness =
          _FixedMessageAttachmentReadiness(const <MessageAssetRegistration>[
            MessageAssetRegistration(
              assetId: 'asset_$contentHash',
              contentHash: contentHash,
              path: 'memory://kelivo-e2ee-attachments/content/$contentHash',
              byteSize: 3,
              kind: 'file',
              displayName: 'ready.txt',
              mediaType: 'text/plain',
              attachmentId: attachmentId,
              uploadId: uploadId,
              chunkKeyEpoch: 7,
              manifestKeyEpoch: 7,
              manifestRevision: 1,
            ),
          ]);
      final adapter = E2eeChatSyncAdapter(
        repository: repository,
        runPullBatch:
            <T>({
              required Future<T> Function() pull,
              required bool Function() shouldRefresh,
              required bool Function() mayHaveOrphanedAssets,
            }) => pull(),
        attachmentReadiness: readiness,
      );
      final initial = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28),
      );

      final committed = await adapter.runPullAndPublish(
        () => pullCommands.applyIncrementalPage(
          expected: initial,
          nextCursor: 'ready-attachment-committed',
          lastChangeSeq: changes.length,
          changes: changes,
          applyBusiness: adapter.applyTransactional,
          now: DateTime.utc(2026, 7, 28, 0, 1),
        ),
      );

      expect(committed.checkpoint.syncCursor, 'ready-attachment-committed');
      expect(readiness.messageIds, <String>[messageId]);
      final persistedMessage = await repository.getMessage(messageId);
      expect(persistedMessage, isNot(equals(null)));
      expect(persistedMessage!.attachments, hasLength(1));
      final persistedAttachment = persistedMessage.attachments.single;
      expect(persistedAttachment.assetId, 'asset_$contentHash');
      expect(persistedAttachment.contentHash, contentHash);
      expect(
        persistedAttachment.path,
        'memory://kelivo-e2ee-attachments/content/$contentHash',
      );
      expect(persistedAttachment.byteSize, 3);
      expect(persistedAttachment.kind, 'file');
      expect(persistedAttachment.displayName, 'ready.txt');
      expect(persistedAttachment.mediaType, 'text/plain');
      expect(persistedAttachment.attachmentId, attachmentId);
      expect(persistedAttachment.uploadId, uploadId);
      expect(persistedAttachment.chunkKeyEpoch, 7);
      expect(persistedAttachment.manifestKeyEpoch, 7);
      expect(persistedAttachment.manifestRevision, 1);
      final reference = await database
          .customSelect(
            'SELECT ordinal, asset_id, kind, display_name, media_type, '
            'attachment_id, upload_id, chunk_key_epoch, '
            'manifest_key_epoch, manifest_revision '
            'FROM message_asset_rows WHERE revision_id = ?;',
            variables: const <Variable<Object>>[Variable<String>(messageId)],
          )
          .getSingle();
      expect(reference.read<int>('ordinal'), 0);
      expect(reference.read<String>('asset_id'), 'asset_$contentHash');
      expect(reference.read<String>('kind'), 'file');
      expect(reference.read<String>('display_name'), 'ready.txt');
      expect(reference.read<String>('media_type'), 'text/plain');
      expect(reference.read<String>('attachment_id'), attachmentId);
      expect(reference.read<String>('upload_id'), uploadId);
      expect(reference.read<int>('chunk_key_epoch'), 7);
      expect(reference.read<int>('manifest_key_epoch'), 7);
      expect(reference.read<int>('manifest_revision'), 1);
    });

    test('附件拉取未就绪整页回滚且本地消息仅在远端身份完整后可封装', () async {
      const conversationId = 'attachment-conversation';
      const turnId = 'attachment-turn';
      const messageId = 'attachment-message';
      const groupId = 'attachment-group';
      const conversationKey = SyncEntityKey(
        entityType: E2eeSyncChatRecordTypes.conversation,
        entityId: conversationId,
      );
      const turnKey = SyncEntityKey(
        entityType: E2eeSyncChatRecordTypes.turn,
        entityId: turnId,
      );
      const messageKey = SyncEntityKey(
        entityType: E2eeSyncChatRecordTypes.message,
        entityId: messageId,
      );
      final payloads = <Map<String, Object?>>[
        _conversationPayload('Attachment conversation'),
        _turnPayload(conversationId),
        _messagePayload(
          conversationId: conversationId,
          turnId: turnId,
          groupId: groupId,
          attachments: const <Object?>[
            <String, Object?>{
              'attachmentId': '10000000-0000-4000-8000-000000000001',
              'uploadId': '20000000-0000-4000-8000-000000000001',
              'chunkKeyEpoch': 1,
              'manifestKeyEpoch': 1,
              'manifestRevision': 1,
              'kind': 'file',
              'order': 0,
            },
          ],
        ),
      ];
      const keys = <SyncEntityKey>[conversationKey, turnKey, messageKey];
      final changes = <E2eeSyncPulledChange>[];
      for (var index = 0; index < keys.length; index++) {
        final wire = await createPullValueChange(
          changeSeq: index + 1,
          revision: 1,
          operation: 840 + index,
          entityKey: keys[index],
          payload: payloads[index],
        );
        changes.add(await authenticatePulledValueChange(wire));
      }
      var publishCount = 0;
      Future<T> runPullBatch<T>({
        required Future<T> Function() pull,
        required bool Function() shouldRefresh,
        required bool Function() mayHaveOrphanedAssets,
      }) async {
        final result = await pull();
        if (shouldRefresh()) publishCount++;
        return result;
      }

      final adapter = E2eeChatSyncAdapter(
        repository: repository,
        runPullBatch: runPullBatch,
        attachmentReadiness: const E2eeNoAttachmentMessageReadiness(),
      );
      final initial = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28),
      );

      await expectLater(
        adapter.runPullAndPublish(
          () => pullCommands.applyIncrementalPage(
            expected: initial,
            nextCursor: 'attachment-must-not-commit',
            lastChangeSeq: changes.length,
            changes: changes,
            applyBusiness: adapter.applyTransactional,
            now: DateTime.utc(2026, 7, 28, 0, 1),
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'sync_message_attachments_not_configured',
          ),
        ),
      );

      final unchanged = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28, 0, 2),
      );
      expect(unchanged.syncCursor, equals(null));
      expect(unchanged.lastChangeSeq, 0);
      expect(await repository.getConversation(conversationId), equals(null));
      expect(publishCount, 0);

      await insertConversation(id: conversationId);
      await insertMessage(
        id: messageId,
        conversationId: conversationId,
        groupId: groupId,
        content: '[file:C:\\private\\secret.txt|secret.txt|text/plain]',
      );
      await expectLater(
        adapter.readSnapshot(messageKey),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'sync_message_local_attachment_marker_rejected',
          ),
        ),
      );

      const structuredConversationId = 'attachment-structured-conversation';
      const structuredMessageId = 'attachment-structured-message';
      const structuredKey = SyncEntityKey(
        entityType: E2eeSyncChatRecordTypes.message,
        entityId: structuredMessageId,
      );
      await insertConversation(id: structuredConversationId);
      await insertMessage(
        id: structuredMessageId,
        conversationId: structuredConversationId,
        groupId: 'attachment-structured-group',
        content: 'structured attachment',
      );
      final localAsset = MessageAssetRegistration(
        assetId:
            'asset_abababababababababababababababababababababababababababababababab',
        contentHash:
            'abababababababababababababababababababababababababababababababab',
        path: '${directory.path}${Platform.pathSeparator}structured.bin',
        byteSize: 17,
        kind: 'file',
        displayName: 'structured.bin',
        mediaType: 'application/octet-stream',
      );
      expect(
        await repository.replaceMessageAssetReferences(
          conversationId: structuredConversationId,
          revisionId: structuredMessageId,
          expectedContent: 'structured attachment',
          assets: <MessageAssetRegistration>[localAsset],
        ),
        isTrue,
      );

      await expectLater(
        adapter.readSnapshot(structuredKey),
        throwsA(
          isA<E2eeSyncOutboxBlocked>().having(
            (error) => error.reason,
            'reason',
            E2eeSyncOutboxBlockReason.attachmentPending,
          ),
        ),
      );

      final remoteAsset = MessageAssetRegistration(
        assetId: localAsset.assetId,
        contentHash: localAsset.contentHash,
        path: localAsset.path,
        byteSize: localAsset.byteSize,
        kind: localAsset.kind,
        displayName: localAsset.displayName,
        mediaType: localAsset.mediaType,
        attachmentId: '10000000-0000-4000-8000-000000000002',
        uploadId: '20000000-0000-4000-8000-000000000002',
        chunkKeyEpoch: 7,
        manifestKeyEpoch: 7,
        manifestRevision: 1,
      );
      expect(
        await repository.replaceMessageAssetReferences(
          conversationId: structuredConversationId,
          revisionId: structuredMessageId,
          expectedContent: 'structured attachment',
          assets: <MessageAssetRegistration>[remoteAsset],
        ),
        isTrue,
      );
      final snapshot = await adapter.readSnapshot(structuredKey);
      final encoded = (snapshot as E2eeSyncValueSnapshot).payload;
      final decoded = E2eeSyncPayloadCodec.decode(
        entityKey: structuredKey,
        bytes: encoded,
      );
      expect(decoded['attachments'], <Object?>[
        <String, Object?>{
          'attachmentId': remoteAsset.attachmentId,
          'uploadId': remoteAsset.uploadId,
          'chunkKeyEpoch': remoteAsset.chunkKeyEpoch,
          'manifestKeyEpoch': remoteAsset.manifestKeyEpoch,
          'manifestRevision': remoteAsset.manifestRevision,
          'kind': 'file',
          'order': 0,
        },
      ]);
      expect(utf8.decode(encoded), isNot(contains(localAsset.path)));
    });

    test('附件引用硬切完整远程身份并拒绝旧结构与非法世代', () {
      const key = SyncEntityKey(
        entityType: E2eeSyncChatRecordTypes.message,
        entityId: 'attachment-identity-message',
      );
      final valid = _messagePayload(
        conversationId: 'attachment-identity-conversation',
        turnId: 'attachment-identity-turn',
        groupId: 'attachment-identity-group',
        attachments: const <Object?>[
          <String, Object?>{
            'attachmentId': '30000000-0000-4000-8000-000000000001',
            'uploadId': '40000000-0000-4000-8000-000000000001',
            'chunkKeyEpoch': 0xffffffff,
            'manifestKeyEpoch': 0xffffffff,
            'manifestRevision': 1,
            'kind': 'image',
            'order': 0,
          },
        ],
      );

      final encoded = E2eeSyncPayloadCodec.encode(
        entityKey: key,
        payload: valid,
      );
      expect(
        E2eeSyncPayloadCodec.decode(entityKey: key, bytes: encoded),
        valid,
      );
      expect(e2eeSyncPayloadFormatVersion, 3);

      final legacyEnvelope = Map<String, Object?>.from(
        jsonDecode(utf8.decode(encoded)) as Map<String, Object?>,
      )..['version'] = 1;
      expect(
        () => E2eeSyncPayloadCodec.decode(
          entityKey: key,
          bytes: Uint8List.fromList(utf8.encode(jsonEncode(legacyEnvelope))),
        ),
        throwsFormatException,
      );

      final oldAttachment = <String, Object?>{
        'attachmentId': '30000000-0000-4000-8000-000000000001',
        'kind': 'image',
        'order': 0,
      };
      for (final invalidAttachment in <Map<String, Object?>>[
        oldAttachment,
        <String, Object?>{
          ...oldAttachment,
          'uploadId': '40000000-0000-4000-8000-000000000001',
          'keyEpoch': 0,
        },
        <String, Object?>{
          ...oldAttachment,
          'uploadId': '40000000-0000-4000-8000-000000000001',
          'chunkKeyEpoch': 0x100000000,
          'manifestKeyEpoch': 0xffffffff,
          'manifestRevision': 1,
        },
        <String, Object?>{
          ...oldAttachment,
          'uploadId': '40000000-0000-4000-8000-000000000001',
          'chunkKeyEpoch': 1,
          'manifestKeyEpoch': 3,
          'manifestRevision': 2,
          'order': 1,
        },
      ]) {
        expect(
          () => E2eeSyncPayloadCodec.encode(
            entityKey: key,
            payload: <String, Object?>{
              ...valid,
              'attachments': <Object?>[invalidAttachment],
            },
          ),
          throwsFormatException,
        );
      }
    });

    test('turn 墓碑只按 turnId 幂等删除所属消息', () async {
      const conversationId = 'turn-delete-conversation';
      const turnId = 'turn-delete-turn';
      const messageId = 'turn-delete-message';
      const conversationKey = SyncEntityKey(
        entityType: E2eeSyncChatRecordTypes.conversation,
        entityId: conversationId,
      );
      const turnKey = SyncEntityKey(
        entityType: E2eeSyncChatRecordTypes.turn,
        entityId: turnId,
      );
      const messageKey = SyncEntityKey(
        entityType: E2eeSyncChatRecordTypes.message,
        entityId: messageId,
      );
      final valuePayloads = <Map<String, Object?>>[
        _conversationPayload('Turn delete conversation'),
        _turnPayload(conversationId),
        _messagePayload(
          conversationId: conversationId,
          turnId: turnId,
          groupId: messageId,
        ),
      ];
      const valueKeys = <SyncEntityKey>[conversationKey, turnKey, messageKey];
      final valueChanges = <E2eeSyncPulledChange>[];
      E2eeSyncPulledValueChange? turnValue;
      for (var index = 0; index < valueKeys.length; index++) {
        final wire = await createPullValueChange(
          changeSeq: index + 1,
          revision: 1,
          operation: 860 + index,
          entityKey: valueKeys[index],
          payload: valuePayloads[index],
        );
        final change = await authenticatePulledValueChange(wire);
        valueChanges.add(change);
        if (valueKeys[index] == turnKey) turnValue = change;
      }
      Future<T> runPullBatch<T>({
        required Future<T> Function() pull,
        required bool Function() shouldRefresh,
        required bool Function() mayHaveOrphanedAssets,
      }) async {
        final result = await pull();
        if (shouldRefresh()) mayHaveOrphanedAssets();
        return result;
      }

      final adapter = E2eeChatSyncAdapter(
        repository: repository,
        runPullBatch: runPullBatch,
        attachmentReadiness: const E2eeNoAttachmentMessageReadiness(),
      );
      final initial = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 28),
      );
      final seeded = await adapter.runPullAndPublish(
        () => pullCommands.applyIncrementalPage(
          expected: initial,
          nextCursor: 'turn-seeded',
          lastChangeSeq: 3,
          changes: valueChanges,
          applyBusiness: adapter.applyTransactional,
          now: DateTime.utc(2026, 7, 28, 0, 1),
        ),
      );
      final firstWireTombstone = await createPullTombstoneChange(
        changeSeq: 4,
        revision: 2,
        operation: 870,
        entityKey: turnKey,
        logicalVersion: 2,
        parentDigests: <E2eeAccountRecordStateDigest>[turnValue!.state.digest],
      );
      final firstTombstone = await authenticatePulledTombstoneChange(
        firstWireTombstone,
      );

      final deleted = await adapter.runPullAndPublish(
        () => pullCommands.applyIncrementalPage(
          expected: seeded.checkpoint,
          nextCursor: 'turn-deleted',
          lastChangeSeq: 4,
          changes: <E2eeSyncPulledChange>[firstTombstone],
          applyBusiness: adapter.applyTransactional,
          now: DateTime.utc(2026, 7, 28, 0, 2),
        ),
      );

      expect(await repository.getMessage(messageId), equals(null));
      expect(
        await repository.getConversation(conversationId),
        isNot(equals(null)),
      );
      expect(
        await adapter.readSnapshot(turnKey),
        isA<E2eeSyncTombstoneSnapshot>(),
      );

      final secondWireTombstone = await createPullTombstoneChange(
        changeSeq: 5,
        revision: 3,
        operation: 871,
        entityKey: turnKey,
        logicalVersion: 3,
        parentDigests: <E2eeAccountRecordStateDigest>[
          firstTombstone.state.digest,
        ],
      );
      final secondTombstone = await authenticatePulledTombstoneChange(
        secondWireTombstone,
      );
      await adapter.runPullAndPublish(
        () => pullCommands.applyIncrementalPage(
          expected: deleted.checkpoint,
          nextCursor: 'turn-delete-replayed',
          lastChangeSeq: 5,
          changes: <E2eeSyncPulledChange>[secondTombstone],
          applyBusiness: adapter.applyTransactional,
          now: DateTime.utc(2026, 7, 28, 0, 3),
        ),
      );
      expect(await repository.getMessage(messageId), equals(null));
      expect(
        await repository.getConversation(conversationId),
        isNot(equals(null)),
      );
    });
  });

  group('E2EE sync outbox commands', () {
    test('值快照复制只读输入并持有独立可写缓冲区', () {
      final input = Uint8List.fromList(<int>[1, 2, 3]).asUnmodifiableView();
      final snapshot = E2eeSyncValueSnapshot.copyFrom(input);

      snapshot.payload[0] = 9;

      expect(input, orderedEquals(<int>[1, 2, 3]));
      expect(snapshot.payload, orderedEquals(<int>[9, 2, 3]));
    });

    test('本地业务写与 dirty intent 在同一事务提交或回滚', () async {
      final outbox = E2eeSyncOutbox.takeOwnership(
        commands: outboxCommands,
        stateCodec: stateCodec,
        accountUserId: _syncAccountUserId,
        actorDeviceId: _syncActorDeviceId,
        claimedWriterKeyVersion: 1,
      );
      addTearDown(outbox.close);
      await outbox.initialize();

      const committedKey = SyncEntityKey(
        entityType: 'conversation',
        entityId: 'local-write-301',
      );
      await outbox.runLocal<void>(
        key: committedKey,
        write: () => repository.runInTransaction(
          () => insertConversation(id: committedKey.entityId),
        ),
      );

      const rolledBackKey = SyncEntityKey(
        entityType: 'conversation',
        entityId: 'local-write-302',
      );
      await expectLater(
        outbox.runLocal<void>(
          key: rolledBackKey,
          write: () async {
            await repository.runInTransaction(
              () => insertConversation(id: rolledBackKey.entityId),
            );
            throw StateError('模拟本地写入失败');
          },
        ),
        throwsStateError,
      );

      final conversations = await database
          .select(database.conversationRows)
          .get();
      expect(conversations.map((row) => row.id), <String>[
        committedKey.entityId,
      ]);
      final intents = await database.select(database.e2eeSyncIntentRows).get();
      expect(intents, hasLength(1));
      expect(intents.single.entityId, committedKey.entityId);
      expect(intents.single.phase, 'dirty');
      expect(intents.single.writerSessionId, null);
    });

    test('seal commit 持久化认证密文且 unknown 重试逐字节不变', () async {
      final now = DateTime.utc(2026, 7, 28, 1);
      final sealed = await createCommittedOutbox(discriminator: 1, now: now);

      expect(await database.select(database.e2eeSyncIntentRows).get(), isEmpty);
      final operation = await database
          .select(database.e2eeSyncOperationRows)
          .getSingle();
      final stored = await database
          .select(database.e2eeSyncOutboxRows)
          .getSingle();
      expect(operation.operationId, sealed.operationId);
      expect(operation.expectedRevision, 0);
      expect(operation.stateDigest, orderedEquals(sealed.digest.bytes));
      expect(stored.operationId, sealed.operationId);
      expect(stored.ciphertext, orderedEquals(sealed.record.ciphertext));
      expect(
        await database.select(database.e2eeSyncRecordStateRows).get(),
        isEmpty,
      );

      final firstClaim = (await outboxCommands.claimSendBatch(
        accountUserId: _syncAccountUserId,
        actorDeviceId: _syncActorDeviceId,
        leaseOwner: 'send-owner-first',
        leaseExpiresAt: now.add(const Duration(minutes: 2)),
        now: now.add(const Duration(minutes: 1)),
      )).single;
      expect(
        await outboxCommands.releaseUnknownResult(
          claim: firstClaim,
          nextAttemptAt: now.add(const Duration(minutes: 3)),
          errorKind: 'transport-unknown',
          now: now.add(const Duration(minutes: 2)),
        ),
        isTrue,
      );
      expect(
        await outboxCommands.claimSendBatch(
          accountUserId: _syncAccountUserId,
          actorDeviceId: _syncActorDeviceId,
          leaseOwner: 'send-owner-too-early',
          leaseExpiresAt: now.add(const Duration(minutes: 4)),
          now: now.add(const Duration(minutes: 2, seconds: 59)),
        ),
        isEmpty,
      );
      final retryClaim = (await outboxCommands.claimSendBatch(
        accountUserId: _syncAccountUserId,
        actorDeviceId: _syncActorDeviceId,
        leaseOwner: 'send-owner-retry',
        leaseExpiresAt: now.add(const Duration(minutes: 4)),
        now: now.add(const Duration(minutes: 3)),
      )).single;

      expect(retryClaim.operationId, firstClaim.operationId);
      expect(retryClaim.expectedRevision, firstClaim.expectedRevision);
      expect(retryClaim.ciphertext, orderedEquals(firstClaim.ciphertext));
      expect(retryClaim.digest, firstClaim.digest);
    });

    test('过期租约可重领且旧 claim stale，applied 后才写入 ledger', () async {
      final now = DateTime.utc(2026, 7, 28, 2);
      await createCommittedOutbox(discriminator: 2, now: now);
      final oldClaim = (await outboxCommands.claimSendBatch(
        accountUserId: _syncAccountUserId,
        actorDeviceId: _syncActorDeviceId,
        leaseOwner: 'send-owner-old',
        leaseExpiresAt: now.add(const Duration(minutes: 2)),
        now: now.add(const Duration(minutes: 1)),
      )).single;
      final newClaim = (await outboxCommands.claimSendBatch(
        accountUserId: _syncAccountUserId,
        actorDeviceId: _syncActorDeviceId,
        leaseOwner: 'send-owner-new',
        leaseExpiresAt: now.add(const Duration(minutes: 4)),
        now: now.add(const Duration(minutes: 2)),
      )).single;
      final restored = await stateCodec.restoreForSend(
        E2eeUntrustedAccountRecordEnvelope.fromTransport(
          recordId: E2eeUntrustedAccountRecordId.fromTransport(
            newClaim.recordId,
          ),
          envelopeVersion: newClaim.envelopeVersion,
          keyEpoch: newClaim.keyEpoch,
          ciphertext: newClaim.ciphertext,
        ),
        expectedDigest: newClaim.digest,
      );

      expect(newClaim.operationId, oldClaim.operationId);
      expect(newClaim.expectedRevision, oldClaim.expectedRevision);
      expect(newClaim.ciphertext, orderedEquals(oldClaim.ciphertext));
      expect(
        await outboxCommands.settleApplied(
          claim: oldClaim,
          state: restored.authenticated,
          revision: 1,
          changeSeq: 0,
          now: now.add(const Duration(minutes: 2, seconds: 1)),
        ),
        isFalse,
      );
      expect(
        await database.select(database.e2eeSyncRecordStateRows).get(),
        isEmpty,
      );

      expect(
        await outboxCommands.settleApplied(
          claim: newClaim,
          state: restored.authenticated,
          revision: 1,
          changeSeq: 0,
          now: now.add(const Duration(minutes: 3)),
        ),
        isTrue,
      );
      expect(
        await database.select(database.e2eeSyncRecordStateRows).get(),
        hasLength(1),
      );
      expect(await database.select(database.e2eeSyncOutboxRows).get(), isEmpty);
      final operation = await database
          .select(database.e2eeSyncOperationRows)
          .getSingle();
      expect(operation.outcome, 'applied');
      expect(operation.resultRevision, 1);
      expect(operation.resultChangeSeq, 0);
    });

    test('远端确认无记录后的 genesis applied 可推进 ready 状态', () async {
      final now = DateTime.utc(2026, 7, 28, 3);
      await createCommittedOutbox(discriminator: 3, now: now);
      final claim = (await outboxCommands.claimSendBatch(
        accountUserId: _syncAccountUserId,
        actorDeviceId: _syncActorDeviceId,
        leaseOwner: 'send-owner-genesis',
        leaseExpiresAt: now.add(const Duration(minutes: 2)),
        now: now.add(const Duration(minutes: 1)),
      )).single;
      await insertSyncRemoteRecord(recordId: claim.recordId, createdAt: now);
      final restored = await stateCodec.restoreForSend(
        E2eeUntrustedAccountRecordEnvelope.fromTransport(
          recordId: E2eeUntrustedAccountRecordId.fromTransport(claim.recordId),
          envelopeVersion: claim.envelopeVersion,
          keyEpoch: claim.keyEpoch,
          ciphertext: claim.ciphertext,
        ),
        expectedDigest: claim.digest,
      );

      expect(
        await outboxCommands.settleApplied(
          claim: claim,
          state: restored.authenticated,
          revision: 1,
          changeSeq: 4,
          now: now.add(const Duration(minutes: 1, seconds: 1)),
        ),
        isTrue,
      );
      final remote = await database
          .select(database.e2eeSyncRemoteRecordRows)
          .getSingle();
      expect(remote.gate, 'ready');
      expect(remote.revision, 1);
      expect(remote.lastChangeSeq, 4);
      expect(remote.stateDigest, orderedEquals(claim.digest.bytes));
      expect(
        await database.select(database.e2eeSyncRecordStateRows).get(),
        hasLength(1),
      );
    });

    test('迟到的 applied 与 conflict 不降低远端安全门', () async {
      final now = DateTime.utc(2026, 7, 28, 4);
      await createCommittedOutbox(discriminator: 4, now: now);
      final appliedClaim = (await outboxCommands.claimSendBatch(
        accountUserId: _syncAccountUserId,
        actorDeviceId: _syncActorDeviceId,
        leaseOwner: 'send-owner-blocked-applied',
        leaseExpiresAt: now.add(const Duration(minutes: 2)),
        now: now.add(const Duration(minutes: 1)),
      )).single;
      await insertSyncRemoteRecord(
        recordId: appliedClaim.recordId,
        gate: 'requires-pull',
        observedRevision: 3,
        createdAt: now,
      );
      final restored = await stateCodec.restoreForSend(
        E2eeUntrustedAccountRecordEnvelope.fromTransport(
          recordId: E2eeUntrustedAccountRecordId.fromTransport(
            appliedClaim.recordId,
          ),
          envelopeVersion: appliedClaim.envelopeVersion,
          keyEpoch: appliedClaim.keyEpoch,
          ciphertext: appliedClaim.ciphertext,
        ),
        expectedDigest: appliedClaim.digest,
      );
      expect(
        await outboxCommands.settleApplied(
          claim: appliedClaim,
          state: restored.authenticated,
          revision: 1,
          changeSeq: 5,
          now: now.add(const Duration(minutes: 1, seconds: 1)),
        ),
        isTrue,
      );
      var remote =
          await (database.select(database.e2eeSyncRemoteRecordRows)
                ..where((row) => row.recordId.equals(appliedClaim.recordId)))
              .getSingle();
      expect(remote.gate, 'requires-pull');
      expect(remote.observedRevision, 3);
      expect(
        await database.select(database.e2eeSyncRecordStateRows).get(),
        isEmpty,
      );

      await createCommittedOutbox(discriminator: 5, now: now);
      final conflictClaim = (await outboxCommands.claimSendBatch(
        accountUserId: _syncAccountUserId,
        actorDeviceId: _syncActorDeviceId,
        leaseOwner: 'send-owner-blocked-conflict',
        leaseExpiresAt: now.add(const Duration(minutes: 3)),
        now: now.add(const Duration(minutes: 2)),
      )).single;
      await insertSyncRemoteRecord(
        recordId: conflictClaim.recordId,
        gate: 'quarantined',
        observedRevision: 8,
        errorCode: 'REMOTE_AUTHENTICATION_FAILED',
        createdAt: now,
      );
      expect(
        await outboxCommands.settleConflict(
          claim: conflictClaim,
          currentRevision: 2,
          newIntentId: _syncUuid(505),
          now: now.add(const Duration(minutes: 2, seconds: 1)),
        ),
        isTrue,
      );
      remote =
          await (database.select(database.e2eeSyncRemoteRecordRows)
                ..where((row) => row.recordId.equals(conflictClaim.recordId)))
              .getSingle();
      expect(remote.gate, 'quarantined');
      expect(remote.observedRevision, 8);
      expect(remote.errorCode, 'REMOTE_AUTHENTICATION_FAILED');
    });

    test('未来密钥世代仅延迟自身且不阻塞同批当前世代', () async {
      final now = DateTime.now().toUtc().subtract(const Duration(minutes: 10));
      final futureState = await createCommittedOutbox(
        discriminator: 6,
        now: now,
      );
      final currentState = await createCommittedOutbox(
        discriminator: 7,
        now: now.add(const Duration(seconds: 1)),
      );
      await (database.update(database.e2eeSyncOutboxRows)
            ..where((row) => row.operationId.equals(futureState.operationId)))
          .write(const E2eeSyncOutboxRowsCompanion(keyEpoch: Value(8)));
      final outbox = E2eeSyncOutbox.takeOwnership(
        commands: outboxCommands,
        stateCodec: stateCodec,
        accountUserId: _syncAccountUserId,
        actorDeviceId: _syncActorDeviceId,
        claimedWriterKeyVersion: 1,
      );
      addTearDown(outbox.close);
      await outbox.initialize();
      final transport = _ApplyingOutboxTransport(
        accountUserId: _syncAccountUserId,
        actorDeviceId: _syncActorDeviceId,
      );

      final report = await outbox.flushOnce(transport: transport);

      expect(report.claimed, 2);
      expect(report.sent, 1);
      expect(report.applied, 1);
      expect(report.deferred, 1);
      expect(report.quarantined, 0);
      expect(report.stale, 0);
      expect(transport.mutations, hasLength(1));
      expect(transport.mutations.single.mutationId, currentState.operationId);
      final remaining = await database
          .select(database.e2eeSyncOutboxRows)
          .getSingle();
      expect(remaining.operationId, futureState.operationId);
      expect(remaining.phase, 'ready');
      expect(remaining.lastFailureKind, 'key-epoch-unavailable');
    });
  });

  group('E2EE config payload codec and adapter', () {
    test('十类配置实体与八个偏好单例规范往返且聊天 schema 不退化', () {
      final seenEntityTypes = <String>{};
      for (final testCase in _configPayloadCases()) {
        seenEntityTypes.add(testCase.key.entityType);
        final encoded = E2eeSyncPayloadCodec.encode(
          entityKey: testCase.key,
          payload: testCase.payload,
        );
        final decoded = E2eeSyncPayloadCodec.decode(
          entityKey: testCase.key,
          bytes: encoded,
        );
        final reencoded = E2eeSyncPayloadCodec.encode(
          entityKey: testCase.key,
          payload: decoded,
        );

        expect(decoded, testCase.payload, reason: testCase.key.toString());
        expect(reencoded, orderedEquals(encoded));
      }
      expect(seenEntityTypes, ConfigSyncKeys.entityTypes);

      const chatKey = SyncEntityKey(
        entityType: E2eeSyncChatRecordTypes.conversation,
        entityId: 'config-codec-chat-regression',
      );
      final chatEncoded = E2eeSyncPayloadCodec.encode(
        entityKey: chatKey,
        payload: _conversationPayload('聊天回归'),
      );
      expect(
        E2eeSyncPayloadCodec.decode(entityKey: chatKey, bytes: chatEncoded),
        _conversationPayload('聊天回归'),
      );
    });

    test('拒绝额外字段、身份错配、未知变体、非法数值与非规范编码', () {
      final providerCase = _configPayloadCases().firstWhere(
        (testCase) => testCase.key.entityType == ConfigSyncKeys.providerType,
      );
      final withExtraField = <String, Object?>{
        ...providerCase.payload,
        'unexpected': true,
      };
      expect(
        () => E2eeSyncPayloadCodec.encode(
          entityKey: providerCase.key,
          payload: withExtraField,
        ),
        throwsFormatException,
      );

      final wrongIdentity = <String, Object?>{
        ...providerCase.payload,
        'id': 'provider-config-other',
      };
      expect(
        () => E2eeSyncPayloadCodec.encode(
          entityKey: providerCase.key,
          payload: wrongIdentity,
        ),
        throwsFormatException,
      );

      final apiKeys = List<Object?>.from(
        providerCase.payload['apiKeys'] as List<Object?>,
      );
      final firstApiKey = Map<String, Object?>.from(
        apiKeys.first as Map<String, Object?>,
      );
      final usage = Map<String, Object?>.from(
        firstApiKey['usage'] as Map<String, Object?>,
      )..['unknownUsageField'] = 1;
      apiKeys[0] = <String, Object?>{...firstApiKey, 'usage': usage};
      expect(
        () => E2eeSyncPayloadCodec.encode(
          entityKey: providerCase.key,
          payload: <String, Object?>{
            ...providerCase.payload,
            'apiKeys': apiKeys,
          },
        ),
        throwsFormatException,
      );

      final invalidPosition = <String, Object?>{
        ...providerCase.payload,
        '_position': -1,
      };
      expect(
        () => E2eeSyncPayloadCodec.encode(
          entityKey: providerCase.key,
          payload: invalidPosition,
        ),
        throwsFormatException,
      );

      final invalidUnicode = <String, Object?>{
        ...providerCase.payload,
        'name': String.fromCharCode(0xd800),
      };
      expect(
        () => E2eeSyncPayloadCodec.encode(
          entityKey: providerCase.key,
          payload: invalidUnicode,
        ),
        throwsFormatException,
      );

      final searchCase = _configPayloadCases().firstWhere(
        (testCase) =>
            testCase.key.entityType == ConfigSyncKeys.searchServiceType,
      );
      expect(
        () => E2eeSyncPayloadCodec.encode(
          entityKey: searchCase.key,
          payload: <String, Object?>{
            ...searchCase.payload,
            'type': 'unknown-search',
          },
        ),
        throwsFormatException,
      );

      final canonical = E2eeSyncPayloadCodec.encode(
        entityKey: providerCase.key,
        payload: providerCase.payload,
      );
      final nonCanonical = Uint8List.fromList(
        utf8.encode(' ${utf8.decode(canonical)}'),
      );
      expect(
        () => E2eeSyncPayloadCodec.decode(
          entityKey: providerCase.key,
          bytes: nonCanonical,
        ),
        throwsFormatException,
      );
      expect(
        () => E2eeSyncPayloadCodec.validateEntityKey(
          const SyncEntityKey(
            entityType: 'unknown-config-type',
            entityId: 'unknown-config-id',
          ),
        ),
        throwsFormatException,
      );
    });

    test('远端整页按依赖稳定写入 Vault，墓碑幂等且不产生 outbox 回声', () async {
      final cases = _configPayloadCases();
      final providerCase = cases.firstWhere(
        (testCase) => testCase.key.entityType == ConfigSyncKeys.providerType,
      );
      final secondProviderKey = ConfigSyncKeys.provider('provider-config-2');
      final secondProviderPayload = <String, Object?>{
        ...providerCase.payload,
        'id': secondProviderKey.entityId,
        'name': '第二供应商',
        '_position': 1,
      };
      final assistantCase = cases.firstWhere(
        (testCase) => testCase.key.entityType == ConfigSyncKeys.assistantType,
      );
      final profileCase = cases.firstWhere(
        (testCase) => testCase.key == ConfigSyncKeys.profile,
      );
      final input = <({SyncEntityKey key, Map<String, Object?> payload})>[
        profileCase,
        assistantCase,
        (key: secondProviderKey, payload: secondProviderPayload),
        providerCase,
      ];
      final changes = <E2eeSyncPulledChange>[];
      for (var index = 0; index < input.length; index++) {
        final wire = await createPullValueChange(
          changeSeq: index + 1,
          revision: 1,
          operation: 900 + index,
          entityKey: input[index].key,
          payload: input[index].payload,
        );
        changes.add(await authenticatePulledValueChange(wire));
      }

      var clockTick = 0;
      final adapter = E2eeConfigSyncAdapter(
        commands: configVault,
        now: () => DateTime.utc(2026, 7, 29, 0, 0, clockTick++),
      );
      final initial = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 29),
      );
      final committed = await pullCommands.applyIncrementalPage(
        expected: initial,
        nextCursor: 'config-adapter-values',
        lastChangeSeq: changes.length,
        changes: changes,
        applyBusiness: adapter.applyTransactional,
        now: DateTime.utc(2026, 7, 29, 0, 1),
      );

      final insertedRows = await database
          .customSelect(
            'SELECT rowid AS row_id, entity_type, entity_id '
            'FROM e2ee_config_entry_rows ORDER BY row_id',
          )
          .get();
      expect(insertedRows.map((row) => row.read<String>('entity_id')), <String>[
        secondProviderKey.entityId,
        providerCase.key.entityId,
        assistantCase.key.entityId,
        profileCase.key.entityId,
      ]);
      expect(committed.checkpoint.syncCursor, 'config-adapter-values');
      expect(await database.select(database.e2eeSyncIntentRows).get(), isEmpty);
      expect(await database.select(database.e2eeSyncOutboxRows).get(), isEmpty);

      for (final testCase in input) {
        final snapshot = await adapter.readSnapshot(testCase.key);
        expect(snapshot, isA<E2eeSyncValueSnapshot>());
        final valueSnapshot = snapshot as E2eeSyncValueSnapshot;
        expect(
          E2eeSyncPayloadCodec.decode(
            entityKey: testCase.key,
            bytes: valueSnapshot.payload,
          ),
          testCase.payload,
        );
      }
      final firstSnapshot =
          await adapter.readSnapshot(providerCase.key) as E2eeSyncValueSnapshot;
      firstSnapshot.payload.fillRange(0, firstSnapshot.payload.length, 0);
      final secondSnapshot =
          await adapter.readSnapshot(providerCase.key) as E2eeSyncValueSnapshot;
      expect(secondSnapshot.payload, isNot(everyElement(0)));

      final assistantValue = changes[1] as E2eeSyncPulledValueChange;
      final tombstoneWire = await createPullTombstoneChange(
        changeSeq: 5,
        revision: 2,
        operation: 904,
        entityKey: assistantCase.key,
        logicalVersion: 2,
        parentDigests: <E2eeAccountRecordStateDigest>[
          assistantValue.state.digest,
        ],
      );
      final tombstone = await authenticatePulledTombstoneChange(tombstoneWire);
      final firstDeletion = await pullCommands.applyIncrementalPage(
        expected: committed.checkpoint,
        nextCursor: 'config-adapter-tombstone',
        lastChangeSeq: 5,
        changes: <E2eeSyncPulledChange>[tombstone],
        applyBusiness: adapter.applyTransactional,
        now: DateTime.utc(2026, 7, 29, 0, 2),
      );

      expect(
        await adapter.readSnapshot(assistantCase.key),
        isA<E2eeSyncTombstoneSnapshot>(),
      );
      expect(
        await adapter.readSnapshot(providerCase.key),
        isA<E2eeSyncValueSnapshot>(),
      );
      expect(await database.select(database.e2eeSyncIntentRows).get(), isEmpty);
      expect(await database.select(database.e2eeSyncOutboxRows).get(), isEmpty);

      final secondTombstoneWire = await createPullTombstoneChange(
        changeSeq: 6,
        revision: 3,
        operation: 905,
        entityKey: assistantCase.key,
        logicalVersion: 3,
        parentDigests: <E2eeAccountRecordStateDigest>[tombstone.state.digest],
      );
      final secondTombstone = await authenticatePulledTombstoneChange(
        secondTombstoneWire,
      );
      final secondDeletion = await pullCommands.applyIncrementalPage(
        expected: firstDeletion.checkpoint,
        nextCursor: 'config-adapter-tombstone-replayed',
        lastChangeSeq: 6,
        changes: <E2eeSyncPulledChange>[secondTombstone],
        applyBusiness: adapter.applyTransactional,
        now: DateTime.utc(2026, 7, 29, 0, 3),
      );
      expect(secondDeletion.checkpoint.lastChangeSeq, 6);
      expect(
        await adapter.readSnapshot(assistantCase.key),
        isA<E2eeSyncTombstoneSnapshot>(),
      );
      expect(await database.select(database.e2eeSyncIntentRows).get(), isEmpty);
      expect(await database.select(database.e2eeSyncOutboxRows).get(), isEmpty);
    });

    test('任一配置 payload 非法时 ledger、Vault 与 checkpoint 整页回滚', () async {
      final cases = _configPayloadCases();
      final providerCase = cases.firstWhere(
        (testCase) => testCase.key.entityType == ConfigSyncKeys.providerType,
      );
      final assistantCase = cases.firstWhere(
        (testCase) => testCase.key.entityType == ConfigSyncKeys.assistantType,
      );
      final providerWire = await createPullValueChange(
        changeSeq: 1,
        revision: 1,
        operation: 910,
        entityKey: providerCase.key,
        payload: providerCase.payload,
      );
      final assistantWire = await createPullValueChange(
        changeSeq: 2,
        revision: 1,
        operation: 911,
        entityKey: assistantCase.key,
        payload: assistantCase.payload,
      );
      final providerChange = await authenticatePulledValueChange(providerWire);
      final authenticatedAssistant = await authenticatePullChange(
        assistantWire,
      );
      final invalidAssistant = E2eeSyncPulledValueChange(
        untrustedServerMetadata: E2eeSyncUntrustedServerMetadata(
          changeSeq: 2,
          revision: 1,
        ),
        state: authenticatedAssistant,
        payload: <String, Object?>{
          ...assistantCase.payload,
          'id': 'assistant-wrong-identity',
        },
      );
      final initial = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 29),
      );
      final adapter = E2eeConfigSyncAdapter(
        commands: configVault,
        now: () => DateTime.utc(2026, 7, 29, 0, 1),
      );

      await expectLater(
        pullCommands.applyIncrementalPage(
          expected: initial,
          nextCursor: 'must-rollback-config-page',
          lastChangeSeq: 2,
          changes: <E2eeSyncPulledChange>[providerChange, invalidAssistant],
          applyBusiness: adapter.applyTransactional,
          now: DateTime.utc(2026, 7, 29, 0, 2),
        ),
        throwsFormatException,
      );

      final unchanged = await pullCommands.readOrCreate(
        accountUserId: _syncAccountUserId,
        now: DateTime.utc(2026, 7, 29, 0, 3),
      );
      expect(unchanged.syncCursor, equals(null));
      expect(unchanged.lastChangeSeq, 0);
      expect(await configVault.read(providerCase.key), equals(null));
      expect(await configVault.read(assistantCase.key), equals(null));
      expect(
        await database.select(database.e2eeSyncRecordStateRows).get(),
        isEmpty,
      );
      expect(
        await database.select(database.e2eeSyncRemoteRecordRows).get(),
        isEmpty,
      );
    });
  });

  group('E2EE config vault commands', () {
    test('配置写入与 dirty intent 同事务提交或回滚', () async {
      final outbox = E2eeSyncOutbox.takeOwnership(
        commands: outboxCommands,
        stateCodec: stateCodec,
        accountUserId: _syncAccountUserId,
        actorDeviceId: _syncActorDeviceId,
        claimedWriterKeyVersion: 1,
      );
      addTearDown(outbox.close);
      await outbox.initialize();

      final committedKey = ConfigSyncKeys.provider('provider-vault-1');
      final sourcePayload = Uint8List.fromList(<int>[1, 2, 3]);
      await outbox.runLocal<void>(
        key: committedKey,
        write: () => configVault.put(
          key: committedKey,
          payload: sourcePayload,
          updatedAt: DateTime.utc(2026, 7, 29),
        ),
      );
      sourcePayload[0] = 9;

      final committed = await configVault.read(committedKey);
      expect(committed, isNot(equals(null)));
      expect(committed!.key, committedKey);
      expect(committed.payload, orderedEquals(<int>[1, 2, 3]));
      expect(committed.updatedAt, DateTime.utc(2026, 7, 29));

      final rolledBackKey = ConfigSyncKeys.provider('provider-vault-2');
      await expectLater(
        outbox.runLocal<void>(
          key: rolledBackKey,
          write: () async {
            await configVault.put(
              key: rolledBackKey,
              payload: Uint8List.fromList(<int>[4, 5, 6]),
              updatedAt: DateTime.utc(2026, 7, 29, 0, 1),
            );
            throw StateError('模拟配置写入失败');
          },
        ),
        throwsStateError,
      );

      expect(await configVault.read(rolledBackKey), equals(null));
      final intents = await database.select(database.e2eeSyncIntentRows).get();
      expect(intents, hasLength(1));
      expect(intents.single.entityType, committedKey.entityType);
      expect(intents.single.entityId, committedKey.entityId);

      await expectLater(
        configVault.put(
          key: const SyncEntityKey(
            entityType: E2eeSyncChatRecordTypes.conversation,
            entityId: 'not-config',
          ),
          payload: Uint8List.fromList(<int>[1]),
          updatedAt: DateTime.utc(2026, 7, 29),
        ),
        throwsFormatException,
      );
      await expectLater(
        configVault.put(
          key: committedKey,
          payload: Uint8List(0),
          updatedAt: DateTime.utc(2026, 7, 29),
        ),
        throwsFormatException,
      );
    });

    test('配置查询稳定排序并支持更新与幂等删除', () async {
      final laterKey = ConfigSyncKeys.provider('provider-vault-b');
      final earlierKey = ConfigSyncKeys.provider('provider-vault-a');
      await configVault.put(
        key: laterKey,
        payload: Uint8List.fromList(<int>[2]),
        updatedAt: DateTime.utc(2026, 7, 29, 1),
      );
      await configVault.put(
        key: earlierKey,
        payload: Uint8List.fromList(<int>[1]),
        updatedAt: DateTime.utc(2026, 7, 29, 2),
      );
      await configVault.put(
        key: laterKey,
        payload: Uint8List.fromList(<int>[3]),
        updatedAt: DateTime.utc(2026, 7, 29, 3),
      );

      final entries = await configVault.readByType(ConfigSyncKeys.providerType);
      expect(entries.map((entry) => entry.key), <SyncEntityKey>[
        earlierKey,
        laterKey,
      ]);
      expect(entries.last.payload, orderedEquals(<int>[3]));
      expect(entries.last.updatedAt, DateTime.utc(2026, 7, 29, 3));
      expect(
        () => entries.last.payload[0] = 8,
        throwsA(isA<UnsupportedError>()),
      );

      expect(await configVault.delete(laterKey), isTrue);
      expect(await configVault.delete(laterKey), isFalse);
      expect(await configVault.read(laterKey), equals(null));

      await expectLater(
        configVault.put(
          key: const SyncEntityKey(
            entityType: ConfigSyncKeys.preferenceType,
            entityId: 'unknown:default',
          ),
          payload: Uint8List.fromList(<int>[1]),
          updatedAt: DateTime.utc(2026, 7, 29),
        ),
        throwsFormatException,
      );
      await expectLater(
        configVault.put(
          key: earlierKey,
          payload: Uint8List(e2eeConfigVaultMaxPayloadBytes + 1),
          updatedAt: DateTime.utc(2026, 7, 29),
        ),
        throwsFormatException,
      );
      await expectLater(
        configVault.put(
          key: earlierKey,
          payload: Uint8List.fromList(<int>[1]),
          updatedAt: DateTime(2026, 7, 29),
        ),
        throwsFormatException,
      );
    });

    test('配置表约束拒绝绕过命令层的非法记录', () async {
      Future<void> insert({
        required String entityType,
        required String entityId,
        required Uint8List payload,
      }) {
        return database
            .into(database.e2eeConfigEntryRows)
            .insert(
              E2eeConfigEntryRowsCompanion.insert(
                entityType: entityType,
                entityId: entityId,
                payload: payload,
                updatedAt: DateTime.utc(2026, 7, 29),
              ),
            );
      }

      await expectLater(
        insert(
          entityType: E2eeSyncChatRecordTypes.conversation,
          entityId: 'not-config',
          payload: Uint8List.fromList(<int>[1]),
        ),
        throwsRemoteSqliteException(),
      );
      await expectLater(
        insert(
          entityType: ConfigSyncKeys.preferenceType,
          entityId: 'unknown:default',
          payload: Uint8List.fromList(<int>[1]),
        ),
        throwsRemoteSqliteException(),
      );
      await expectLater(
        insert(
          entityType: ConfigSyncKeys.providerType,
          entityId: 'empty-payload',
          payload: Uint8List(0),
        ),
        throwsRemoteSqliteException(),
      );
    });
  });

  group('E2EE sync record ledger', () {
    test(
      'accepts genesis and fast-forward and distinguishes replays',
      () async {
        final genesis = await createAuthenticatedState(
          logicalVersion: 1,
          parentDigests: const [],
          operation: 1,
        );
        final genesisResult = await ledger.accept(genesis);
        expect(genesisResult.kind, E2eeSyncRecordAcceptanceKind.genesis);
        expect(genesisResult.heads, <Object>[genesis.digest]);
        expect(genesisResult.hasConflict, isFalse);

        final currentReplay = await ledger.accept(genesis);
        expect(currentReplay.kind, E2eeSyncRecordAcceptanceKind.currentReplay);

        final next = await createAuthenticatedState(
          logicalVersion: 2,
          parentDigests: <E2eeAccountRecordStateDigest>[genesis.digest],
          operation: 2,
        );
        final nextResult = await ledger.accept(next);
        expect(nextResult.kind, E2eeSyncRecordAcceptanceKind.fastForward);
        expect(nextResult.heads, <Object>[next.digest]);

        final staleReplay = await ledger.accept(genesis);
        expect(staleReplay.kind, E2eeSyncRecordAcceptanceKind.staleReplay);
        expect(staleReplay.heads, <Object>[next.digest]);
      },
    );

    test(
      'keeps sibling heads and collapses an explicit two-parent merge',
      () async {
        final genesis = await createAuthenticatedState(
          logicalVersion: 1,
          parentDigests: const [],
          operation: 10,
        );
        await ledger.accept(genesis);
        final first = await createAuthenticatedState(
          logicalVersion: 2,
          parentDigests: <E2eeAccountRecordStateDigest>[genesis.digest],
          operation: 11,
        );
        final second = await createAuthenticatedState(
          logicalVersion: 2,
          parentDigests: <E2eeAccountRecordStateDigest>[genesis.digest],
          operation: 12,
        );
        await ledger.accept(first);
        final conflict = await ledger.accept(second);
        expect(conflict.kind, E2eeSyncRecordAcceptanceKind.conflict);
        expect(
          conflict.heads,
          unorderedEquals(<Object>[first.digest, second.digest]),
        );
        expect(conflict.hasConflict, isTrue);

        final merge = await createAuthenticatedState(
          logicalVersion: 3,
          parentDigests: <E2eeAccountRecordStateDigest>[
            first.digest,
            second.digest,
          ],
          operation: 13,
        );
        final merged = await ledger.accept(merge);
        expect(merged.kind, E2eeSyncRecordAcceptanceKind.merge);
        expect(merged.heads, <Object>[merge.digest]);
        expect(merged.hasConflict, isFalse);
      },
    );

    test(
      'rejects gaps, wrong versions, operation reuse, and rollback',
      () async {
        final unknownParent = E2eeAccountRecordStateDigest.fromTrustedStorage(
          Uint8List.fromList(List<int>.filled(32, 7)),
        );
        final gap = await createAuthenticatedState(
          logicalVersion: 2,
          parentDigests: <E2eeAccountRecordStateDigest>[unknownParent],
          operation: 20,
        );
        await expectLater(
          ledger.accept(gap),
          throwsA(
            isA<E2eeSyncRecordRejected>().having(
              (error) => error.reason,
              'reason',
              E2eeSyncRecordRejectionReason.historyGap,
            ),
          ),
        );

        final genesis = await createAuthenticatedState(
          logicalVersion: 1,
          parentDigests: const [],
          operation: 21,
        );
        await ledger.accept(genesis);
        final otherGenesis = await createAuthenticatedState(
          entityKey: const SyncEntityKey(
            entityType: 'chat',
            entityId: 'known-other-chat',
          ),
          logicalVersion: 1,
          parentDigests: const [],
          operation: 29,
        );
        await ledger.accept(otherGenesis);
        final mismatchedParent = await createAuthenticatedState(
          logicalVersion: 2,
          parentDigests: <E2eeAccountRecordStateDigest>[otherGenesis.digest],
          operation: 30,
        );
        await expectLater(
          ledger.accept(mismatchedParent),
          throwsA(
            isA<E2eeSyncRecordRejected>().having(
              (error) => error.reason,
              'reason',
              E2eeSyncRecordRejectionReason.parentRecordMismatch,
            ),
          ),
        );
        final wrongVersion = await createAuthenticatedState(
          logicalVersion: 3,
          parentDigests: <E2eeAccountRecordStateDigest>[genesis.digest],
          operation: 22,
        );
        await expectLater(
          ledger.accept(wrongVersion),
          throwsA(
            isA<E2eeSyncRecordRejected>().having(
              (error) => error.reason,
              'reason',
              E2eeSyncRecordRejectionReason.versionMismatch,
            ),
          ),
        );

        final operationReuse = await createAuthenticatedState(
          logicalVersion: 2,
          parentDigests: <E2eeAccountRecordStateDigest>[genesis.digest],
          operation: 21,
        );
        await expectLater(
          ledger.accept(operationReuse),
          throwsA(
            isA<E2eeSyncRecordRejected>().having(
              (error) => error.reason,
              'reason',
              E2eeSyncRecordRejectionReason.operationIdReuse,
            ),
          ),
        );
        final crossRecordOperationReuse = await createAuthenticatedState(
          entityKey: const SyncEntityKey(
            entityType: 'chat',
            entityId: 'other-chat',
          ),
          logicalVersion: 1,
          parentDigests: const [],
          operation: 21,
        );
        await expectLater(
          ledger.accept(crossRecordOperationReuse),
          throwsA(
            isA<E2eeSyncRecordRejected>().having(
              (error) => error.reason,
              'reason',
              E2eeSyncRecordRejectionReason.operationIdReuse,
            ),
          ),
        );

        final next = await createAuthenticatedState(
          logicalVersion: 2,
          parentDigests: <E2eeAccountRecordStateDigest>[genesis.digest],
          operation: 23,
        );
        await ledger.accept(next);
        final latest = await createAuthenticatedState(
          logicalVersion: 3,
          parentDigests: <E2eeAccountRecordStateDigest>[next.digest],
          operation: 24,
        );
        await ledger.accept(latest);
        final lowBranch = await createAuthenticatedState(
          logicalVersion: 2,
          parentDigests: <E2eeAccountRecordStateDigest>[genesis.digest],
          operation: 25,
        );
        final delayedConflict = await ledger.accept(lowBranch);
        expect(delayedConflict.kind, E2eeSyncRecordAcceptanceKind.conflict);
        expect(
          delayedConflict.heads,
          unorderedEquals(<Object>[latest.digest, lowBranch.digest]),
        );

        final secondGenesis = await createAuthenticatedState(
          logicalVersion: 1,
          parentDigests: const [],
          operation: 26,
        );
        await expectLater(
          ledger.accept(secondGenesis),
          throwsA(
            isA<E2eeSyncRecordRejected>().having(
              (error) => error.reason,
              'reason',
              E2eeSyncRecordRejectionReason.rollback,
            ),
          ),
        );
      },
    );

    test('rejects replay when persisted parent edges are damaged', () async {
      final genesis = await createAuthenticatedState(
        logicalVersion: 1,
        parentDigests: const [],
        operation: 27,
      );
      await ledger.accept(genesis);
      final next = await createAuthenticatedState(
        logicalVersion: 2,
        parentDigests: <E2eeAccountRecordStateDigest>[genesis.digest],
        operation: 28,
      );
      await ledger.accept(next);
      await (database.delete(
        database.e2eeSyncRecordParentRows,
      )..where((row) => row.childDigest.equals(next.digest.bytes))).go();

      await expectLater(
        ledger.accept(next),
        throwsA(
          isA<E2eeSyncRecordRejected>().having(
            (error) => error.reason,
            'reason',
            E2eeSyncRecordRejectionReason.storedStateMismatch,
          ),
        ),
      );
    });

    test('rejects replay when every persisted head is missing', () async {
      final genesis = await createAuthenticatedState(
        logicalVersion: 1,
        parentDigests: const [],
        operation: 29,
      );
      await ledger.accept(genesis);
      await database.delete(database.e2eeSyncRecordHeadRows).go();

      await expectLater(
        ledger.accept(genesis),
        throwsA(
          isA<E2eeSyncRecordRejected>().having(
            (error) => error.reason,
            'reason',
            E2eeSyncRecordRejectionReason.storedStateMismatch,
          ),
        ),
      );
    });

    test('enforces state, edge, and head constraints in SQLite', () async {
      final genesis = await createAuthenticatedState(
        logicalVersion: 1,
        parentDigests: const [],
        operation: 30,
      );
      await ledger.accept(genesis);
      final otherGenesis = await createAuthenticatedState(
        entityKey: const SyncEntityKey(
          entityType: 'chat',
          entityId: 'constraint-chat-2',
        ),
        logicalVersion: 1,
        parentDigests: const [],
        operation: 32,
      );
      await ledger.accept(otherGenesis);

      await expectLater(
        database.customStatement(
          'INSERT INTO e2ee_sync_record_state_rows '
          '(digest, record_id, entity_type, entity_id, logical_version, kind, '
          'operation_id, claimed_writer_device_id, claimed_writer_key_version, '
          'key_epoch, '
          'accepted_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            Uint8List(31),
            genesis.recordId.wireValue,
            genesis.entityKey.entityType,
            genesis.entityKey.entityId,
            1,
            'value',
            _ledgerOperationId(31),
            _ledgerClaimedWriterDeviceId,
            1,
            7,
            1,
          ],
        ),
        throwsRemoteSqliteException(),
      );
      await expectLater(
        database.customStatement(
          'INSERT INTO e2ee_sync_record_head_rows (digest) VALUES (?);',
          <Object?>[Uint8List.fromList(List<int>.filled(32, 9))],
        ),
        throwsRemoteSqliteException(),
      );
      await expectLater(
        database.customStatement(
          'INSERT INTO e2ee_sync_record_parent_rows '
          '(child_digest, ordinal, parent_digest) VALUES (?, ?, ?);',
          <Object?>[genesis.digest.bytes, 2, otherGenesis.digest.bytes],
        ),
        throwsRemoteSqliteException(),
      );
      await expectLater(
        database.customStatement(
          'INSERT INTO e2ee_sync_record_parent_rows '
          '(child_digest, ordinal, parent_digest) VALUES (?, ?, ?);',
          <Object?>[genesis.digest.bytes, 0, genesis.digest.bytes],
        ),
        throwsRemoteSqliteException(),
      );
    });

    test('participates in an outer transaction rollback', () async {
      final genesis = await createAuthenticatedState(
        logicalVersion: 1,
        parentDigests: const [],
        operation: 40,
      );
      await expectLater(
        database.transaction<void>(() async {
          await ledger.accept(genesis);
          throw StateError('rollback');
        }),
        throwsA(isA<StateError>()),
      );

      final acceptedAfterRollback = await ledger.accept(genesis);
      expect(acceptedAfterRollback.kind, E2eeSyncRecordAcceptanceKind.genesis);
    });
  });

  group('消息附件一等引用约束', () {
    Future<void> prepareMessageAssets() async {
      await insertConversation();
      await insertMessage();
      await insertAsset(
        id: 'asset-reference-1',
        contentHash:
            '1111111111111111111111111111111111111111111111111111111111111111',
      );
      await insertAsset(
        id: 'asset-reference-2',
        contentHash:
            '2222222222222222222222222222222222222222222222222222222222222222',
      );
    }

    test('接受本地引用与完整远端身份的序号边界', () async {
      await prepareMessageAssets();

      await database
          .into(database.messageAssetRows)
          .insert(
            MessageAssetRowsCompanion.insert(
              revisionId: 'message-1',
              ordinal: 0,
              assetId: 'asset-reference-1',
              kind: 'image',
            ),
          );
      await database
          .into(database.messageAssetRows)
          .insert(
            MessageAssetRowsCompanion.insert(
              revisionId: 'message-1',
              ordinal: 31,
              assetId: 'asset-reference-2',
              kind: 'file',
              displayName: const Value('report.txt'),
              mediaType: const Value('text/plain'),
              attachmentId: const Value('d0000000-0000-4000-8000-000000000011'),
              uploadId: const Value('e0000000-0000-4000-8000-000000000011'),
              chunkKeyEpoch: const Value(0xffffffff),
              manifestKeyEpoch: const Value(0xffffffff),
              manifestRevision: const Value(1),
            ),
          );

      final rows = await database.select(database.messageAssetRows).get();
      expect(rows.map((row) => row.ordinal), <int>[0, 31]);
      expect(rows.last.attachmentId, 'd0000000-0000-4000-8000-000000000011');
      expect(rows.last.chunkKeyEpoch, 0xffffffff);
      expect(rows.last.manifestKeyEpoch, 0xffffffff);
      expect(rows.last.manifestRevision, 1);
    });

    test('拒绝越界序号、重复序号与不完整远端身份', () async {
      await prepareMessageAssets();

      Future<void> insertReference({
        required int ordinal,
        required String assetId,
        Value<String?> attachmentId = const Value.absent(),
        Value<String?> uploadId = const Value.absent(),
        Value<int?> chunkKeyEpoch = const Value.absent(),
        Value<int?> manifestKeyEpoch = const Value.absent(),
        Value<int?> manifestRevision = const Value.absent(),
      }) {
        return database
            .into(database.messageAssetRows)
            .insert(
              MessageAssetRowsCompanion.insert(
                revisionId: 'message-1',
                ordinal: ordinal,
                assetId: assetId,
                kind: 'image',
                attachmentId: attachmentId,
                uploadId: uploadId,
                chunkKeyEpoch: chunkKeyEpoch,
                manifestKeyEpoch: manifestKeyEpoch,
                manifestRevision: manifestRevision,
              ),
            );
      }

      await expectLater(
        insertReference(ordinal: 32, assetId: 'asset-reference-1'),
        throwsRemoteSqliteException(),
      );
      await expectLater(
        insertReference(
          ordinal: 0,
          assetId: 'asset-reference-1',
          attachmentId: const Value('d0000000-0000-4000-8000-000000000012'),
        ),
        throwsRemoteSqliteException(),
      );
      await insertReference(ordinal: 0, assetId: 'asset-reference-1');
      await expectLater(
        insertReference(ordinal: 0, assetId: 'asset-reference-2'),
        throwsRemoteSqliteException(),
      );
      await insertReference(
        ordinal: 1,
        assetId: 'asset-reference-2',
        attachmentId: const Value('d0000000-0000-4000-8000-000000000013'),
        uploadId: const Value('e0000000-0000-4000-8000-000000000013'),
        chunkKeyEpoch: const Value(1),
        manifestKeyEpoch: const Value(1),
        manifestRevision: const Value(1),
      );
      await expectLater(
        insertReference(
          ordinal: 2,
          assetId: 'asset-reference-1',
          attachmentId: const Value('d0000000-0000-4000-8000-000000000013'),
          uploadId: const Value('e0000000-0000-4000-8000-000000000014'),
          chunkKeyEpoch: const Value(1),
          manifestKeyEpoch: const Value(1),
          manifestRevision: const Value(1),
        ),
        throwsRemoteSqliteException(),
      );
      await expectLater(
        insertReference(
          ordinal: 2,
          assetId: 'asset-reference-1',
          attachmentId: const Value('d0000000-0000-4000-8000-000000000014'),
          uploadId: const Value('e0000000-0000-4000-8000-000000000013'),
          chunkKeyEpoch: const Value(1),
          manifestKeyEpoch: const Value(1),
          manifestRevision: const Value(1),
        ),
        throwsRemoteSqliteException(),
      );
    });
  });

  group('E2EE 附件持久上传状态', () {
    E2eeAttachmentUploadDraft uploadDraft({
      String attachmentId = 'd0000000-0000-4000-8000-000000000001',
      String localAssetId = 'asset-upload-1',
      String targetRevisionId = 'message-upload-1',
      int targetOrdinal = 0,
      int contentByte = 0x5a,
      String createMutationId = 'd1000000-0000-4000-8000-000000000001',
      String commitMutationId = 'd2000000-0000-4000-8000-000000000001',
    }) {
      return E2eeAttachmentUploadDraft(
        descriptor: E2eeAttachmentDescriptor(
          attachmentId: attachmentId,
          chunkKeyEpoch: 0xffffffff,
          kind: E2eeAttachmentKind.file,
          totalPlaintextBytes: KelivoAttachmentLimits.chunkPlaintextBytes + 1,
          contentSha256: Uint8List.fromList(List<int>.filled(32, contentByte)),
          wrappedDataKey: Uint8List.fromList(
            List<int>.filled(KelivoAttachmentLimits.wrappedDataKeyBytes, 0xa5),
          ),
          chunkCiphertextBytes: <int>[
            KelivoAttachmentLimits.maxChunkEnvelopeBytes,
            KelivoAttachmentLimits.chunkEnvelopeOverheadBytes + 1,
          ],
          displayName: 'upload.txt',
          mediaType: 'text/plain',
        ),
        localAssetId: localAssetId,
        targetRevisionId: targetRevisionId,
        targetOrdinal: targetOrdinal,
        sourcePath: 'D:\\workspace\\upload\\asset.bin',
        createMutationId: createMutationId,
        commitMutationId: commitMutationId,
      );
    }

    Future<void> prepareUploadTarget(
      E2eeAttachmentUploadDraft draft, {
      bool insertGraph = true,
    }) async {
      final now = DateTime.utc(2026, 7, 29);
      if (insertGraph) {
        await insertConversation(id: 'conversation-upload-1');
        await insertMessage(
          id: draft.targetRevisionId,
          conversationId: 'conversation-upload-1',
          groupId: 'group-upload-1',
        );
        await database
            .into(database.assetRows)
            .insert(
              AssetRowsCompanion.insert(
                id: draft.localAssetId,
                contentHash: draft.descriptor.contentSha256
                    .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
                    .join(),
                path: draft.sourcePath,
                byteSize: draft.descriptor.totalPlaintextBytes,
                createdAt: now,
                lastReferencedAt: now,
              ),
            );
      }
      await database
          .into(database.messageAssetRows)
          .insert(
            MessageAssetRowsCompanion.insert(
              revisionId: draft.targetRevisionId,
              ordinal: draft.targetOrdinal,
              assetId: draft.localAssetId,
              kind: draft.descriptor.kind.name,
              displayName: Value(draft.descriptor.displayName),
              mediaType: Value(draft.descriptor.mediaType),
            ),
          );
    }

    test('创建提交后响应丢失按消息附件自然键恢复原状态', () async {
      final now = DateTime.utc(2026, 7, 29, 0, 15);
      final initialDraft = uploadDraft();
      await prepareUploadTarget(initialDraft);
      final initial = await attachmentUploads.create(
        draft: initialDraft,
        now: now,
      );

      final replay = await attachmentUploads.create(
        draft: uploadDraft(
          attachmentId: 'd0000000-0000-4000-8000-000000000090',
          createMutationId: 'd1000000-0000-4000-8000-000000000090',
          commitMutationId: 'd2000000-0000-4000-8000-000000000090',
        ),
        now: now.add(const Duration(seconds: 1)),
      );
      expect(replay.descriptor.attachmentId, initial.descriptor.attachmentId);
      expect(replay.createMutationId, initial.createMutationId);
      expect(replay.commitMutationId, initial.commitMutationId);

      final lease = (await attachmentUploads.claimDue(
        leaseToken: 'natural-key-terminal-lease',
        leaseOwner: 'foreground-runtime',
        leaseExpiresAt: now.add(const Duration(minutes: 5)),
        now: now.add(const Duration(seconds: 2)),
      ))!;
      final terminal = await attachmentUploads.markPermanentlyFailed(
        lease: lease,
        failureKind: 'source-unavailable',
        now: now.add(const Duration(seconds: 3)),
      );
      final terminalReplay = await attachmentUploads.create(
        draft: uploadDraft(
          attachmentId: 'd0000000-0000-4000-8000-000000000091',
          createMutationId: 'd1000000-0000-4000-8000-000000000091',
          commitMutationId: 'd2000000-0000-4000-8000-000000000091',
        ),
        now: now.add(const Duration(seconds: 4)),
      );
      expect(
        terminalReplay.descriptor.attachmentId,
        terminal.descriptor.attachmentId,
      );
      expect(terminalReplay.terminalFailureKind, 'source-unavailable');
      expect(terminalReplay.transitionVersion, terminal.transitionVersion);

      await expectLater(
        attachmentUploads.create(
          draft: uploadDraft(
            attachmentId: 'd0000000-0000-4000-8000-000000000092',
            contentByte: 0x5b,
            createMutationId: 'd1000000-0000-4000-8000-000000000092',
            commitMutationId: 'd2000000-0000-4000-8000-000000000092',
          ),
          now: now.add(const Duration(seconds: 5)),
        ),
        throwsStateError,
      );
    });

    test('同一本地资产可创建多个独立远端身份', () async {
      final now = DateTime.utc(2026, 7, 29);
      final firstDraft = uploadDraft(localAssetId: 'shared-local-asset');
      await prepareUploadTarget(firstDraft);
      final first = await attachmentUploads.create(draft: firstDraft, now: now);
      final secondDraft = uploadDraft(
        attachmentId: 'd0000000-0000-4000-8000-000000000002',
        localAssetId: 'shared-local-asset',
        targetOrdinal: 31,
        createMutationId: 'd1000000-0000-4000-8000-000000000002',
        commitMutationId: 'd2000000-0000-4000-8000-000000000002',
      );
      await prepareUploadTarget(secondDraft, insertGraph: false);
      final second = await attachmentUploads.create(
        draft: secondDraft,
        now: now,
      );

      expect(first.localAssetId, second.localAssetId);
      expect(first.targetOrdinal, 0);
      expect(second.targetOrdinal, 31);
      expect(
        first.descriptor.attachmentId,
        isNot(second.descriptor.attachmentId),
      );
      expect(
        await attachmentUploads.readByAttachmentId(
          second.descriptor.attachmentId,
        ),
        isA<E2eeAttachmentUploadState>(),
      );
    });

    test('创建只接受存在、未远端化且资产一致的目标', () async {
      final now = DateTime.utc(2026, 7, 29, 0, 30);
      final draft = uploadDraft();
      await expectLater(
        attachmentUploads.create(draft: draft, now: now),
        throwsStateError,
      );

      await prepareUploadTarget(draft);
      await (database.update(database.messageAssetRows)..where(
            (row) =>
                row.revisionId.equals(draft.targetRevisionId) &
                row.ordinal.equals(draft.targetOrdinal),
          ))
          .write(
            const MessageAssetRowsCompanion(
              attachmentId: Value('d0000000-0000-4000-8000-000000000010'),
              uploadId: Value('e0000000-0000-4000-8000-000000000010'),
              chunkKeyEpoch: Value(1),
              manifestKeyEpoch: Value(1),
              manifestRevision: Value(1),
            ),
          );
      await expectLater(
        attachmentUploads.create(draft: draft, now: now),
        throwsStateError,
      );

      final mismatchedAssetDraft = uploadDraft(
        attachmentId: 'd0000000-0000-4000-8000-000000000011',
        targetOrdinal: 1,
        createMutationId: 'd1000000-0000-4000-8000-000000000011',
        commitMutationId: 'd2000000-0000-4000-8000-000000000011',
      );
      await prepareUploadTarget(mismatchedAssetDraft, insertGraph: false);
      await (database.update(database.assetRows)
            ..where((row) => row.id.equals(mismatchedAssetDraft.localAssetId)))
          .write(
            const AssetRowsCompanion(
              path: Value('D:\\workspace\\upload\\other.bin'),
            ),
          );
      await expectLater(
        attachmentUploads.create(draft: mismatchedAssetDraft, now: now),
        throwsStateError,
      );
    });

    test('删除目标引用会级联清除未完成上传', () async {
      final now = DateTime.utc(2026, 7, 29, 0, 45);
      final draft = uploadDraft();
      await prepareUploadTarget(draft);
      await attachmentUploads.create(draft: draft, now: now);

      await (database.delete(database.messageAssetRows)..where(
            (row) =>
                row.revisionId.equals(draft.targetRevisionId) &
                row.ordinal.equals(draft.targetOrdinal),
          ))
          .go();

      expect(
        await attachmentUploads.readByAttachmentId(
          draft.descriptor.attachmentId,
        ),
        equals(null),
      );
    });

    test('失败重试保留同一分块密文并最终提交', () async {
      final now = DateTime.utc(2026, 7, 29, 1);
      final draft = uploadDraft();
      await prepareUploadTarget(draft);
      final created = await attachmentUploads.create(draft: draft, now: now);
      expect(created.phase, E2eeAttachmentUploadPhase.createPending);
      expect(created.descriptor.chunkKeyEpoch, 0xffffffff);
      expect(created.attemptCount, 0);

      var lease = (await attachmentUploads.claimDue(
        leaseToken: 'lease-upload-1',
        leaseOwner: 'foreground-runtime',
        leaseExpiresAt: now.add(const Duration(minutes: 5)),
        now: now,
      ))!;
      expect(lease.state.attemptCount, 1);
      expect(
        await attachmentUploads.claimDue(
          leaseToken: 'lease-upload-blocked',
          leaseOwner: 'background-runtime',
          leaseExpiresAt: now.add(const Duration(minutes: 5)),
          now: now,
        ),
        equals(null),
      );

      const uploadId = 'e0000000-0000-4000-8000-000000000001';
      lease = await attachmentUploads.acceptCreated(
        lease: lease,
        uploadId: uploadId,
        now: now.add(const Duration(seconds: 1)),
      );
      expect(lease.state.phase, E2eeAttachmentUploadPhase.manifestPending);

      const secureCore = KelivoSecureCore();
      final manifestCipher = E2eeAttachmentManifestCipher.takeOwnership(
        E2eeAccountRecordCipher.takeOwnership(
          secureCore: secureCore,
          accountRootKey: await secureCore.generateAccountRootKey(
            userId: Uuid.parseAsByteList(_ledgerUserId),
            keyEpoch: 0xffffffff,
          ),
          userId: _ledgerUserId,
          currentKeyEpoch: 0xffffffff,
        ),
      );
      try {
        final sealedManifest = await manifestCipher.seal(
          E2eeAttachmentManifest.fromDescriptor(
            descriptor: draft.descriptor,
            uploadId: uploadId,
            manifestKeyEpoch: 0xffffffff,
            manifestRevision: 1,
          ),
        );
        lease = await attachmentUploads.attachManifest(
          lease: lease,
          sealedManifest: sealedManifest,
          now: now.add(const Duration(seconds: 2)),
        );
      } finally {
        await manifestCipher.close();
      }
      expect(lease.state.phase, E2eeAttachmentUploadPhase.uploading);

      lease = await attachmentUploads.stageChunk(
        lease: lease,
        chunkIndex: 0,
        mutationId: 'd3000000-0000-4000-8000-000000000001',
        ciphertextPath: 'D:\\workspace\\cache\\chunk-0.part',
        ciphertextBytes: KelivoAttachmentLimits.maxChunkEnvelopeBytes,
        ciphertextSha256: Uint8List.fromList(List<int>.filled(32, 0x31)),
        now: now.add(const Duration(seconds: 3)),
      );
      final firstPending = lease.state.pendingChunk!;
      await expectLater(
        database.customStatement(
          'UPDATE e2ee_attachment_upload_rows SET '
          'pending_chunk_ciphertext_bytes = NULL WHERE attachment_id = ?;',
          <Object?>[draft.descriptor.attachmentId],
        ),
        throwsRemoteSqliteException(),
      );
      final retryAt = now.add(const Duration(minutes: 10));
      expect(
        await attachmentUploads.releaseAfterFailure(
          lease: lease,
          nextAttemptAt: retryAt,
          failureKind: 'network-timeout',
          now: now.add(const Duration(seconds: 4)),
        ),
        isTrue,
      );
      final persisted = await attachmentUploads.readByAttachmentId(
        draft.descriptor.attachmentId,
      );
      expect(persisted!.pendingChunk!.mutationId, firstPending.mutationId);
      expect(
        persisted.pendingChunk!.ciphertextPath,
        firstPending.ciphertextPath,
      );
      expect(
        persisted.pendingChunk!.ciphertextSha256,
        orderedEquals(firstPending.ciphertextSha256),
      );
      expect(persisted.consecutiveFailureCount, 1);
      expect(
        await attachmentUploads.claimDue(
          leaseToken: 'lease-upload-too-early',
          leaseOwner: 'foreground-runtime',
          leaseExpiresAt: retryAt.add(const Duration(minutes: 5)),
          now: retryAt.subtract(const Duration(microseconds: 1)),
        ),
        equals(null),
      );

      lease = (await attachmentUploads.claimDue(
        leaseToken: 'lease-upload-2',
        leaseOwner: 'background-runtime',
        leaseExpiresAt: retryAt.add(const Duration(minutes: 5)),
        now: retryAt,
      ))!;
      expect(lease.state.pendingChunk!.mutationId, firstPending.mutationId);
      expect(lease.state.attemptCount, 2);
      expect(
        await attachmentUploads.release(
          lease: lease,
          now: retryAt.add(const Duration(microseconds: 1)),
        ),
        isTrue,
      );
      expect(
        (await attachmentUploads.readByAttachmentId(
          draft.descriptor.attachmentId,
        ))!.consecutiveFailureCount,
        1,
      );
      lease = (await attachmentUploads.claimDue(
        leaseToken: 'lease-upload-3',
        leaseOwner: 'background-runtime',
        leaseExpiresAt: retryAt.add(const Duration(minutes: 5)),
        now: retryAt.add(const Duration(microseconds: 2)),
      ))!;
      lease = await attachmentUploads.acknowledgeChunk(
        lease: lease,
        now: retryAt.add(const Duration(seconds: 1)),
      );
      expect(lease.state.nextChunkIndex, 1);
      expect(lease.state.pendingChunk, equals(null));
      expect(lease.state.consecutiveFailureCount, 0);

      lease = await attachmentUploads.stageChunk(
        lease: lease,
        chunkIndex: 1,
        mutationId: 'd3000000-0000-4000-8000-000000000002',
        ciphertextPath: 'D:\\workspace\\cache\\chunk-1.part',
        ciphertextBytes: KelivoAttachmentLimits.chunkEnvelopeOverheadBytes + 1,
        ciphertextSha256: Uint8List.fromList(List<int>.filled(32, 0x32)),
        now: retryAt.add(const Duration(seconds: 2)),
      );
      lease = await attachmentUploads.acknowledgeChunk(
        lease: lease,
        now: retryAt.add(const Duration(seconds: 3)),
      );
      expect(lease.state.phase, E2eeAttachmentUploadPhase.commitPending);
      await database.customStatement(
        'UPDATE e2ee_attachment_upload_rows SET '
        'transition_version = transition_version + 1 '
        'WHERE attachment_id = ?;',
        <Object?>[draft.descriptor.attachmentId],
      );
      await expectLater(
        attachmentUploads.markCommitted(
          lease: lease,
          now: retryAt.add(const Duration(seconds: 4)),
        ),
        throwsStateError,
      );
      final targetAfterStaleLease =
          await (database.select(database.messageAssetRows)..where(
                (row) =>
                    row.revisionId.equals(draft.targetRevisionId) &
                    row.ordinal.equals(draft.targetOrdinal),
              ))
              .getSingle();
      expect(targetAfterStaleLease.attachmentId, equals(null));
      expect(targetAfterStaleLease.uploadId, equals(null));
      expect(targetAfterStaleLease.chunkKeyEpoch, equals(null));
      expect(targetAfterStaleLease.manifestKeyEpoch, equals(null));
      expect(targetAfterStaleLease.manifestRevision, equals(null));
      expect(
        (await attachmentUploads.readByAttachmentId(
          draft.descriptor.attachmentId,
        ))!.phase,
        E2eeAttachmentUploadPhase.commitPending,
      );
      await database.customStatement(
        'UPDATE e2ee_attachment_upload_rows SET transition_version = ? '
        'WHERE attachment_id = ?;',
        <Object?>[lease.state.transitionVersion, draft.descriptor.attachmentId],
      );
      final committed = await attachmentUploads.markCommitted(
        lease: lease,
        now: retryAt.add(const Duration(seconds: 5)),
      );
      expect(committed.phase, E2eeAttachmentUploadPhase.committed);
      expect(committed.nextChunkIndex, 2);
      expect(committed.manifestCiphertext, isNotEmpty);
      expect(
        (await attachmentUploads.readByAttachmentId(
          draft.descriptor.attachmentId,
        ))!.phase,
        E2eeAttachmentUploadPhase.committed,
      );
      final committedTarget =
          await (database.select(database.messageAssetRows)..where(
                (row) =>
                    row.revisionId.equals(draft.targetRevisionId) &
                    row.ordinal.equals(draft.targetOrdinal),
              ))
              .getSingle();
      expect(committedTarget.attachmentId, draft.descriptor.attachmentId);
      expect(committedTarget.uploadId, uploadId);
      expect(committedTarget.chunkKeyEpoch, draft.descriptor.chunkKeyEpoch);
      expect(committedTarget.manifestKeyEpoch, 0xffffffff);
      expect(committedTarget.manifestRevision, 1);
    });

    test('过期租约可接管且旧租约不能再推进', () async {
      final now = DateTime.utc(2026, 7, 29, 2);
      final draft = uploadDraft(
        attachmentId: 'd0000000-0000-4000-8000-000000000002',
        localAssetId: 'asset-upload-2',
      );
      await prepareUploadTarget(draft);
      await attachmentUploads.create(draft: draft, now: now);
      final oldLease = (await attachmentUploads.claimDue(
        leaseToken: 'expired-lease',
        leaseOwner: 'foreground-runtime',
        leaseExpiresAt: now.add(const Duration(seconds: 1)),
        now: now,
      ))!;
      await expectLater(
        attachmentUploads.acceptCreated(
          lease: oldLease,
          uploadId: 'e0000000-0000-4000-8000-000000000002',
          now: now.add(const Duration(seconds: 1)),
        ),
        throwsStateError,
      );
      final takeoverTime = now.add(const Duration(seconds: 2));
      final newLease = (await attachmentUploads.claimDue(
        leaseToken: 'takeover-lease',
        leaseOwner: 'background-runtime',
        leaseExpiresAt: takeoverTime.add(const Duration(minutes: 5)),
        now: takeoverTime,
      ))!;
      expect(newLease.state.attemptCount, 2);
      expect(
        await attachmentUploads.release(lease: oldLease, now: takeoverTime),
        isFalse,
      );
      await expectLater(
        attachmentUploads.acceptCreated(
          lease: oldLease,
          uploadId: 'e0000000-0000-4000-8000-000000000002',
          now: takeoverTime,
        ),
        throwsStateError,
      );
    });

    test('非法布局和数据库阶段跃迁均被拒绝', () async {
      final now = DateTime.utc(2026, 7, 29, 3);
      final draft = uploadDraft(
        attachmentId: 'd0000000-0000-4000-8000-000000000003',
        localAssetId: 'asset-upload-3',
      );
      await prepareUploadTarget(draft);
      await attachmentUploads.create(draft: draft, now: now);
      await expectLater(
        database.customStatement(
          "UPDATE e2ee_attachment_upload_rows SET phase = 'commit-pending' "
          'WHERE attachment_id = ?;',
          <Object?>[draft.descriptor.attachmentId],
        ),
        throwsRemoteSqliteException(),
      );
      await expectLater(
        database.customStatement(
          'UPDATE e2ee_attachment_upload_rows SET '
          'pending_chunk_index = 0 WHERE attachment_id = ?;',
          <Object?>[draft.descriptor.attachmentId],
        ),
        throwsRemoteSqliteException(),
      );
      expect(
        () => E2eeAttachmentUploadDraft(
          descriptor: draft.descriptor,
          localAssetId: 'asset-invalid',
          targetRevisionId: draft.targetRevisionId,
          targetOrdinal: draft.targetOrdinal,
          sourcePath: 'bad\u0000path',
          createMutationId: 'd1000000-0000-4000-8000-000000000010',
          commitMutationId: 'd2000000-0000-4000-8000-000000000010',
        ),
        throwsFormatException,
      );
      expect(() => uploadDraft(targetOrdinal: 32), throwsFormatException);
    });

    test('永久失败保留待发分块并只允许精确 CAS 重建', () async {
      final now = DateTime.utc(2026, 7, 29, 4);
      final draft = uploadDraft(
        attachmentId: 'd0000000-0000-4000-8000-000000000004',
        localAssetId: 'asset-upload-4',
      );
      await prepareUploadTarget(draft);
      await attachmentUploads.create(draft: draft, now: now);
      var lease = (await attachmentUploads.claimDue(
        leaseToken: 'terminal-upload-lease',
        leaseOwner: 'foreground-runtime',
        leaseExpiresAt: now.add(const Duration(minutes: 5)),
        now: now,
      ))!;
      lease = await attachmentUploads.acceptCreated(
        lease: lease,
        uploadId: 'e0000000-0000-4000-8000-000000000004',
        now: now.add(const Duration(seconds: 1)),
      );
      const secureCore = KelivoSecureCore();
      final manifestCipher = E2eeAttachmentManifestCipher.takeOwnership(
        E2eeAccountRecordCipher.takeOwnership(
          secureCore: secureCore,
          accountRootKey: await secureCore.generateAccountRootKey(
            userId: Uuid.parseAsByteList(_ledgerUserId),
            keyEpoch: 0xffffffff,
          ),
          userId: _ledgerUserId,
          currentKeyEpoch: 0xffffffff,
        ),
      );
      try {
        lease = await attachmentUploads.attachManifest(
          lease: lease,
          sealedManifest: await manifestCipher.seal(
            E2eeAttachmentManifest.fromDescriptor(
              descriptor: draft.descriptor,
              uploadId: lease.state.uploadId!,
              manifestKeyEpoch: 0xffffffff,
              manifestRevision: 1,
            ),
          ),
          now: now.add(const Duration(seconds: 2)),
        );
      } finally {
        await manifestCipher.close();
      }
      final digest = Uint8List.fromList(List<int>.filled(32, 0x41));
      final expectedDigest = Uint8List.fromList(digest);
      await expectLater(
        () => attachmentUploads.stageChunk(
          lease: lease,
          chunkIndex: 0,
          mutationId: 'd3000000-0000-4000-8000-000000000040',
          ciphertextPath: 'D:\\workspace\\cache\\chunk-terminal.part',
          ciphertextBytes: KelivoAttachmentLimits.maxChunkEnvelopeBytes,
          ciphertextSha256: Uint8List(31),
          now: now.add(const Duration(seconds: 3)),
        ),
        throwsFormatException,
      );
      final stageFuture = attachmentUploads.stageChunk(
        lease: lease,
        chunkIndex: 0,
        mutationId: 'd3000000-0000-4000-8000-000000000040',
        ciphertextPath: 'D:\\workspace\\cache\\chunk-terminal.part',
        ciphertextBytes: KelivoAttachmentLimits.maxChunkEnvelopeBytes,
        ciphertextSha256: digest,
        now: now.add(const Duration(seconds: 3)),
      );
      digest[0] = 0x42;
      lease = await stageFuture;
      final terminal = await attachmentUploads.markPermanentlyFailed(
        lease: lease,
        failureKind: 'ciphertext-corrupt',
        now: now.add(const Duration(seconds: 4)),
      );
      expect(terminal.phase, E2eeAttachmentUploadPhase.uploading);
      expect(terminal.terminalFailureKind, 'ciphertext-corrupt');
      expect(
        terminal.pendingChunk!.mutationId,
        lease.state.pendingChunk!.mutationId,
      );
      expect(
        terminal.pendingChunk!.ciphertextSha256,
        orderedEquals(expectedDigest),
      );
      expect(
        await attachmentUploads.claimDue(
          leaseToken: 'terminal-upload-reclaim',
          leaseOwner: 'foreground-runtime',
          leaseExpiresAt: now.add(const Duration(minutes: 6)),
          now: now.add(const Duration(minutes: 5)),
        ),
        equals(null),
      );
      expect(
        await attachmentUploads.deleteFailedForRebuild(
          attachmentId: terminal.attachmentId,
          expectedTransitionVersion: terminal.transitionVersion - 1,
        ),
        isFalse,
      );
      expect(
        await attachmentUploads.deleteFailedForRebuild(
          attachmentId: terminal.attachmentId,
          expectedTransitionVersion: terminal.transitionVersion,
        ),
        isTrue,
      );
    });
  });

  group('E2EE 附件持久下载状态', () {
    E2eeAttachmentDownloadReference downloadReference({
      String attachmentId = 'f0000000-0000-4000-8000-000000000001',
      String uploadId = 'f1000000-0000-4000-8000-000000000001',
      int chunkKeyEpoch = 7,
      int manifestKeyEpoch = 7,
      int manifestRevision = 1,
    }) {
      return E2eeAttachmentDownloadReference(
        attachmentId: attachmentId,
        uploadId: uploadId,
        chunkKeyEpoch: chunkKeyEpoch,
        manifestKeyEpoch: manifestKeyEpoch,
        manifestRevision: manifestRevision,
        kind: E2eeAttachmentKind.file,
      );
    }

    E2eeAttachmentManifest downloadManifest(
      E2eeAttachmentDownloadReference reference, {
      int totalPlaintextBytes = 0,
      int digestByte = 0x61,
    }) {
      final layout = KelivoAttachmentLayout(
        totalPlaintextBytes: totalPlaintextBytes,
      );
      return E2eeAttachmentManifest(
        attachmentId: reference.attachmentId,
        uploadId: reference.uploadId,
        chunkKeyEpoch: reference.chunkKeyEpoch,
        manifestKeyEpoch: reference.manifestKeyEpoch,
        manifestRevision: reference.manifestRevision,
        kind: reference.kind,
        totalPlaintextBytes: totalPlaintextBytes,
        contentSha256: Uint8List.fromList(List<int>.filled(32, digestByte)),
        wrappedDataKey: Uint8List.fromList(
          List<int>.filled(KelivoAttachmentLimits.wrappedDataKeyBytes, 0x71),
        ),
        chunkCiphertextBytes: List<int>.generate(
          layout.chunkCount,
          (index) =>
              layout.plaintextLengthForChunk(index) +
              KelivoAttachmentLimits.chunkEnvelopeOverheadBytes,
          growable: false,
        ),
        displayName: 'download.txt',
        mediaType: 'text/plain',
      );
    }

    test('单行清单换代支持离线跨代并拒绝旧租约与回滚', () async {
      final now = DateTime.utc(2026, 7, 29, 5);
      final reference = downloadReference(
        chunkKeyEpoch: 6,
        manifestKeyEpoch: 6,
      );
      final first = await attachmentDownloads.ensure(
        reference: reference,
        now: now,
      );
      final repeated = await attachmentDownloads.ensure(
        reference: reference,
        now: now.add(const Duration(seconds: 1)),
      );
      expect(repeated.transitionVersion, first.transitionVersion);
      var staleLease = (await attachmentDownloads.claimDue(
        reference: reference,
        leaseToken: 'download-stale-before-manifest-rotation',
        leaseOwner: 'foreground-runtime',
        leaseExpiresAt: now.add(const Duration(minutes: 5)),
        now: now.add(const Duration(seconds: 2)),
      ))!;
      staleLease = await attachmentDownloads.attachManifest(
        lease: staleLease,
        manifest: downloadManifest(reference, totalPlaintextBytes: 1),
        manifestCiphertext: Uint8List.fromList([1, 2, 3]),
        stagingPath: 'D:\\workspace\\upload\\e2ee\\tmp\\stale.part',
        finalPath: 'D:\\workspace\\upload\\e2ee\\content\\stale',
        now: now.add(const Duration(seconds: 3)),
      );
      final rotatedReference = downloadReference(
        chunkKeyEpoch: 6,
        manifestKeyEpoch: 7,
        manifestRevision: 2,
      );
      final rotated = await attachmentDownloads.ensure(
        reference: rotatedReference,
        now: now.add(const Duration(seconds: 4)),
      );
      expect(rotated.manifestKeyEpoch, 7);
      expect(rotated.manifestRevision, 2);
      expect(rotated.phase, E2eeAttachmentDownloadPhase.manifestPending);
      expect(rotated.manifestCiphertext, equals(null));
      expect(rotated.descriptor, equals(null));
      expect(rotated.localAssetId, equals(null));
      expect(rotated.stagingPath, equals(null));
      expect(
        rotated.cleanupStagingPath,
        'D:\\workspace\\upload\\e2ee\\tmp\\stale.part',
      );
      expect(rotated.finalPath, equals(null));
      expect(await attachmentDownloads.read(reference), equals(null));
      expect(
        await attachmentDownloads.read(rotatedReference),
        isA<E2eeAttachmentDownloadState>(),
      );
      expect(
        await database.select(database.e2eeAttachmentDownloadRows).get(),
        hasLength(1),
      );
      expect(
        await attachmentDownloads.release(
          lease: staleLease,
          now: now.add(const Duration(seconds: 5)),
        ),
        isFalse,
      );

      final offlineJumpReference = downloadReference(
        chunkKeyEpoch: 6,
        manifestKeyEpoch: 8,
        manifestRevision: 3,
      );
      final offlineJump = await attachmentDownloads.ensure(
        reference: offlineJumpReference,
        now: now.add(const Duration(seconds: 6)),
      );
      expect(offlineJump.manifestKeyEpoch, 8);
      expect(offlineJump.manifestRevision, 3);
      expect(
        offlineJump.cleanupStagingPath,
        'D:\\workspace\\upload\\e2ee\\tmp\\stale.part',
      );
      expect(
        await database.select(database.e2eeAttachmentDownloadRows).get(),
        hasLength(1),
      );
      final cleanupLease = (await attachmentDownloads.claimDue(
        reference: offlineJumpReference,
        leaseToken: 'download-cleanup-after-manifest-rotation',
        leaseOwner: 'foreground-runtime',
        leaseExpiresAt: now.add(const Duration(minutes: 5)),
        now: now.add(const Duration(seconds: 7)),
      ))!;
      final cleanedLease = await attachmentDownloads.completeStagingCleanup(
        lease: cleanupLease,
        cleanupStagingPath: offlineJump.cleanupStagingPath!,
        now: now.add(const Duration(seconds: 8)),
      );
      expect(cleanedLease.state.cleanupStagingPath, equals(null));
      expect(
        await attachmentDownloads.release(
          lease: cleanedLease,
          now: now.add(const Duration(seconds: 9)),
        ),
        isTrue,
      );
      await expectLater(
        attachmentDownloads.ensure(
          reference: rotatedReference,
          now: now.add(const Duration(seconds: 10)),
        ),
        throwsStateError,
      );

      await expectLater(
        attachmentDownloads.ensure(
          reference: downloadReference(
            uploadId: 'f1000000-0000-4000-8000-000000000002',
            chunkKeyEpoch: 6,
            manifestKeyEpoch: 8,
            manifestRevision: 3,
          ),
          now: now.add(const Duration(seconds: 11)),
        ),
        throwsStateError,
      );
      await expectLater(
        attachmentDownloads.ensure(
          reference: downloadReference(
            attachmentId: 'f0000000-0000-4000-8000-000000000002',
            chunkKeyEpoch: 6,
            manifestKeyEpoch: 8,
            manifestRevision: 3,
          ),
          now: now.add(const Duration(seconds: 12)),
        ),
        throwsStateError,
      );
    });

    test('零字节附件完成后原子注册资产并支持同内容复用', () async {
      final now = DateTime.utc(2026, 7, 29, 6);
      final references = <E2eeAttachmentDownloadReference>[
        downloadReference(
          attachmentId: 'f0000000-0000-4000-8000-000000000010',
          uploadId: 'f1000000-0000-4000-8000-000000000010',
        ),
        downloadReference(
          attachmentId: 'f0000000-0000-4000-8000-000000000011',
          uploadId: 'f1000000-0000-4000-8000-000000000011',
        ),
      ];
      final digest = Uint8List.fromList(List<int>.filled(32, 0x61));
      final contentHash = digest
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      final assetId = 'asset_$contentHash';
      const finalPath = 'D:\\workspace\\upload\\e2ee\\content\\shared';
      await repository.registerAsset(
        id: assetId,
        contentHash: contentHash,
        path: 'D:\\workspace\\upload\\e2ee\\content\\old',
        byteSize: 0,
        createdAt: now,
      );
      await repository.scheduleUnreferencedAssetGc(notBefore: now);
      final initialGcCandidate = (await repository.claimAssetGc(
        now: now,
      )).single;
      const quarantinePath = 'D:\\workspace\\quarantine\\shared';
      await repository.recordAssetGcQuarantine(
        assetId: assetId,
        generation: initialGcCandidate.generation,
        originalPath: initialGcCandidate.path,
        quarantinePath: quarantinePath,
        createdAt: now,
      );

      for (var index = 0; index < references.length; index++) {
        final reference = references[index];
        await attachmentDownloads.ensure(reference: reference, now: now);
        var lease = (await attachmentDownloads.claimDue(
          leaseToken: 'download-ready-$index',
          leaseOwner: 'foreground-runtime',
          leaseExpiresAt: now.add(const Duration(minutes: 5)),
          now: now,
        ))!;
        await expectLater(
          () => attachmentDownloads.attachManifest(
            lease: lease,
            manifest: downloadManifest(reference),
            manifestCiphertext: Uint8List.fromList([1, 2, 3]),
            stagingPath: finalPath,
            finalPath: finalPath,
            now: now.add(const Duration(seconds: 1)),
          ),
          throwsFormatException,
        );
        final manifestCiphertext = Uint8List.fromList([1, 2, 3]);
        final attachFuture = attachmentDownloads.attachManifest(
          lease: lease,
          manifest: downloadManifest(reference),
          manifestCiphertext: manifestCiphertext,
          stagingPath: 'D:\\workspace\\upload\\e2ee\\tmp\\$index.part',
          finalPath: finalPath,
          now: now.add(const Duration(seconds: 1)),
        );
        manifestCiphertext[0] = 9;
        lease = await attachFuture;
        expect(lease.state.manifestCiphertext, orderedEquals([1, 2, 3]));
        if (index == 0) {
          expect(
            await repository.isAssetGcClaimStillValid(
              initialGcCandidate,
              now: now,
            ),
            isFalse,
          );
          expect(
            await repository.completeAssetGc(
              assetId: assetId,
              expectedGeneration: initialGcCandidate.generation,
              expectedQuarantinePaths: const {quarantinePath},
              now: now,
            ),
            isFalse,
          );
          expect(
            (await attachmentDownloads.read(reference))!.phase,
            E2eeAttachmentDownloadPhase.downloading,
          );
        }
        lease = await attachmentDownloads.acknowledgeChunk(
          lease: lease,
          chunkIndex: 0,
          confirmedPlaintextBytes: 0,
          now: now.add(const Duration(seconds: 2)),
        );
        final ready = await attachmentDownloads.markReady(
          lease: lease,
          asset: MessageAssetRegistration(
            assetId: assetId,
            contentHash: contentHash,
            path: finalPath,
            byteSize: 0,
            kind: 'file',
            displayName: 'download.txt',
            mediaType: 'text/plain',
            attachmentId: reference.attachmentId,
            uploadId: reference.uploadId,
            chunkKeyEpoch: reference.chunkKeyEpoch,
            manifestKeyEpoch: reference.manifestKeyEpoch,
            manifestRevision: reference.manifestRevision,
          ),
          now: now.add(const Duration(seconds: 3)),
        );
        expect(ready.phase, E2eeAttachmentDownloadPhase.ready);
        expect(ready.stagingPath, equals(null));
        expect(ready.finalPath, finalPath);
        expect(
          (await attachmentDownloads.readReady(reference))!.localAssetId,
          assetId,
        );
        if (index == 0) {
          expect(
            await repository.scheduleUnreferencedAssetGc(notBefore: now),
            1,
          );
        }
      }

      final reuseCandidateReference = downloadReference(
        attachmentId: references.first.attachmentId,
        uploadId: references.first.uploadId,
        chunkKeyEpoch: references.first.chunkKeyEpoch,
        manifestKeyEpoch: references.first.manifestKeyEpoch + 1,
        manifestRevision: references.first.manifestRevision + 1,
      );
      final reuseCandidate = await attachmentDownloads.ensure(
        reference: reuseCandidateReference,
        now: now.add(const Duration(seconds: 4)),
      );
      expect(reuseCandidate.phase, E2eeAttachmentDownloadPhase.manifestPending);
      expect(reuseCandidate.localAssetId, assetId);
      expect(reuseCandidate.finalPath, finalPath);
      expect(await repository.scheduleUnreferencedAssetGc(notBefore: now), 0);

      final consecutiveCandidate = await attachmentDownloads.ensure(
        reference: downloadReference(
          attachmentId: reuseCandidate.attachmentId,
          uploadId: reuseCandidate.uploadId,
          chunkKeyEpoch: reuseCandidate.chunkKeyEpoch,
          manifestKeyEpoch: reuseCandidate.manifestKeyEpoch + 1,
          manifestRevision: reuseCandidate.manifestRevision + 1,
        ),
        now: now.add(const Duration(seconds: 5)),
      );
      expect(
        consecutiveCandidate.phase,
        E2eeAttachmentDownloadPhase.manifestPending,
      );
      expect(consecutiveCandidate.localAssetId, assetId);
      expect(consecutiveCandidate.finalPath, finalPath);

      final assetCount = await database
          .customSelect(
            'SELECT COUNT(*) AS item_count FROM asset_rows WHERE id = ?;',
            variables: [Variable<String>(assetId)],
          )
          .getSingle();
      expect(assetCount.read<int>('item_count'), 1);
      final mappingCount = await database
          .customSelect(
            'SELECT COUNT(*) AS item_count '
            'FROM e2ee_attachment_download_rows WHERE local_asset_id = ?;',
            variables: [Variable<String>(assetId)],
          )
          .getSingle();
      expect(mappingCount.read<int>('item_count'), 2);
      final pendingGc = await database
          .customSelect(
            'SELECT COUNT(*) AS item_count FROM asset_gc_rows '
            'WHERE asset_id = ?;',
            variables: [Variable<String>(assetId)],
          )
          .getSingle();
      expect(pendingGc.read<int>('item_count'), 0);

      expect(
        await attachmentDownloads.invalidateReadyByLocalAssetId(
          assetId,
          now: now.add(const Duration(seconds: 6)),
        ),
        1,
      );
      final invalidated = (await attachmentDownloads.read(references.last))!;
      expect(invalidated.phase, E2eeAttachmentDownloadPhase.dormant);
      expect(invalidated.localAssetId, equals(null));
      final reactivated = await attachmentDownloads.ensure(
        reference: references.last,
        now: now.add(const Duration(seconds: 7)),
      );
      expect(reactivated.phase, E2eeAttachmentDownloadPhase.manifestPending);
    });

    test('重建暂存与永久失败保留进度并要求精确 CAS', () async {
      final now = DateTime.utc(2026, 7, 29, 7);
      final reference = downloadReference(
        attachmentId: 'f0000000-0000-4000-8000-000000000020',
        uploadId: 'f1000000-0000-4000-8000-000000000020',
        chunkKeyEpoch: 7,
        manifestKeyEpoch: 8,
        manifestRevision: 2,
      );
      await attachmentDownloads.ensure(reference: reference, now: now);
      var lease = (await attachmentDownloads.claimDue(
        leaseToken: 'download-rebuild-1',
        leaseOwner: 'foreground-runtime',
        leaseExpiresAt: now.add(const Duration(minutes: 5)),
        now: now,
      ))!;
      lease = await attachmentDownloads.attachManifest(
        lease: lease,
        manifest: downloadManifest(reference, totalPlaintextBytes: 1),
        manifestCiphertext: Uint8List.fromList([4, 5, 6]),
        stagingPath: 'D:\\workspace\\upload\\e2ee\\tmp\\before.part',
        finalPath: 'D:\\workspace\\upload\\e2ee\\content\\one',
        now: now.add(const Duration(seconds: 1)),
      );
      lease = await attachmentDownloads.acknowledgeChunk(
        lease: lease,
        chunkIndex: 0,
        confirmedPlaintextBytes: 1,
        now: now.add(const Duration(seconds: 2)),
      );
      lease = await attachmentDownloads.restartStaging(
        lease: lease,
        stagingPath: 'D:\\workspace\\upload\\e2ee\\tmp\\after.part',
        now: now.add(const Duration(seconds: 3)),
      );
      expect(lease.state.phase, E2eeAttachmentDownloadPhase.downloading);
      expect(lease.state.nextChunkIndex, 0);
      expect(lease.state.confirmedPlaintextBytes, 0);

      final terminal = await attachmentDownloads.markPermanentlyFailed(
        lease: lease,
        failureKind: 'manifest-rejected',
        now: now.add(const Duration(seconds: 4)),
      );
      expect(terminal.phase, E2eeAttachmentDownloadPhase.downloading);
      expect(terminal.stagingPath, lease.state.stagingPath);
      expect(terminal.terminalFailureKind, 'manifest-rejected');
      expect(terminal.consecutiveFailureCount, 1);
      expect(
        await attachmentDownloads.claimDue(
          leaseToken: 'download-rebuild-blocked',
          leaseOwner: 'background-runtime',
          leaseExpiresAt: now.add(const Duration(minutes: 10)),
          now: now.add(const Duration(minutes: 6)),
        ),
        equals(null),
      );
      expect(
        await attachmentDownloads.deleteFailedForRebuild(
          reference: reference,
          expectedTransitionVersion: terminal.transitionVersion - 1,
          now: now.add(const Duration(seconds: 5)),
        ),
        isFalse,
      );
      expect(
        await attachmentDownloads.deleteFailedForRebuild(
          reference: reference,
          expectedTransitionVersion: terminal.transitionVersion,
          now: now.add(const Duration(seconds: 6)),
        ),
        isTrue,
      );
      final dormant = (await attachmentDownloads.read(reference))!;
      expect(dormant.phase, E2eeAttachmentDownloadPhase.dormant);
      expect(
        dormant.cleanupStagingPath,
        'D:\\workspace\\upload\\e2ee\\tmp\\after.part',
      );
      await expectLater(
        attachmentDownloads.ensure(
          reference: downloadReference(
            attachmentId: reference.attachmentId,
            uploadId: reference.uploadId,
            chunkKeyEpoch: 7,
            manifestKeyEpoch: 7,
            manifestRevision: 1,
          ),
          now: now.add(const Duration(seconds: 7)),
        ),
        throwsStateError,
      );
      final reactivated = await attachmentDownloads.ensure(
        reference: reference,
        now: now.add(const Duration(seconds: 8)),
      );
      expect(reactivated.phase, E2eeAttachmentDownloadPhase.manifestPending);
      expect(reactivated.cleanupStagingPath, dormant.cleanupStagingPath);
    });

    test('资产回收仅休眠下载身份并保留非回滚高水位', () async {
      final now = DateTime.utc(2026, 7, 29, 8);
      final reference = downloadReference(
        attachmentId: 'f0000000-0000-4000-8000-000000000030',
        uploadId: 'f1000000-0000-4000-8000-000000000030',
        chunkKeyEpoch: 7,
        manifestKeyEpoch: 8,
        manifestRevision: 2,
      );
      final manifest = downloadManifest(reference);
      final contentHash = manifest.contentSha256
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      final assetId = 'asset_$contentHash';
      const finalPath = 'D:\\workspace\\upload\\e2ee\\content\\gc-ready';
      await attachmentDownloads.ensure(reference: reference, now: now);
      var lease = (await attachmentDownloads.claimDue(
        reference: reference,
        leaseToken: 'download-ready-for-gc',
        leaseOwner: 'foreground-runtime',
        leaseExpiresAt: now.add(const Duration(minutes: 5)),
        now: now,
      ))!;
      lease = await attachmentDownloads.attachManifest(
        lease: lease,
        manifest: manifest,
        manifestCiphertext: Uint8List.fromList([1, 2, 3]),
        stagingPath: 'D:\\workspace\\upload\\e2ee\\tmp\\gc-ready.part',
        finalPath: finalPath,
        now: now.add(const Duration(seconds: 1)),
      );
      lease = await attachmentDownloads.acknowledgeChunk(
        lease: lease,
        chunkIndex: 0,
        confirmedPlaintextBytes: 0,
        now: now.add(const Duration(seconds: 2)),
      );
      await attachmentDownloads.markReady(
        lease: lease,
        asset: MessageAssetRegistration(
          assetId: assetId,
          contentHash: contentHash,
          path: finalPath,
          byteSize: 0,
          kind: 'file',
          displayName: 'download.txt',
          mediaType: 'text/plain',
          attachmentId: reference.attachmentId,
          uploadId: reference.uploadId,
          chunkKeyEpoch: reference.chunkKeyEpoch,
          manifestKeyEpoch: reference.manifestKeyEpoch,
          manifestRevision: reference.manifestRevision,
        ),
        now: now.add(const Duration(seconds: 3)),
      );
      expect(await repository.scheduleUnreferencedAssetGc(notBefore: now), 1);
      final candidate = (await repository.claimAssetGc(now: now)).single;
      const quarantinePath = 'D:\\workspace\\quarantine\\gc-ready';
      await repository.recordAssetGcQuarantine(
        assetId: assetId,
        generation: candidate.generation,
        originalPath: finalPath,
        quarantinePath: quarantinePath,
        createdAt: now,
      );
      expect(
        await repository.completeAssetGc(
          assetId: assetId,
          expectedGeneration: candidate.generation,
          expectedQuarantinePaths: const {quarantinePath},
          now: now.add(const Duration(seconds: 4)),
        ),
        isTrue,
      );
      final dormant = (await attachmentDownloads.read(reference))!;
      expect(dormant.phase, E2eeAttachmentDownloadPhase.dormant);
      expect(dormant.localAssetId, equals(null));
      await expectLater(
        attachmentDownloads.ensure(
          reference: downloadReference(
            attachmentId: reference.attachmentId,
            uploadId: reference.uploadId,
            chunkKeyEpoch: 7,
            manifestKeyEpoch: 7,
            manifestRevision: 1,
          ),
          now: now.add(const Duration(seconds: 5)),
        ),
        throwsStateError,
      );
    });
  });

  group('E2EE 附件下载协调器', () {
    const attachmentId = 'd0000000-0000-4000-8000-000000000001';
    const uploadId = 'd1000000-0000-4000-8000-000000000001';
    final token = CloudSyncFullSessionToken.parse(
      'kelivo_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
    );

    E2eeAttachmentManifest createManifest({
      int chunkKeyEpoch = 7,
      int manifestKeyEpoch = 7,
      int manifestRevision = 1,
      List<Uint8List>? plaintextChunks,
    }) {
      final chunks =
          plaintextChunks ??
          <Uint8List>[
            Uint8List.fromList(<int>[1, 2, 3]),
          ];
      final totalPlaintextBytes = chunks.fold<int>(
        0,
        (total, chunk) => total + chunk.length,
      );
      final layout = KelivoAttachmentLayout(
        totalPlaintextBytes: totalPlaintextBytes,
      );
      expect(chunks, hasLength(layout.chunkCount));
      for (var index = 0; index < chunks.length; index++) {
        expect(chunks[index], hasLength(layout.plaintextLengthForChunk(index)));
      }
      final plaintext = BytesBuilder(copy: false);
      for (final chunk in chunks) {
        plaintext.add(chunk);
      }
      final digest = Uint8List.fromList(
        sha256.convert(plaintext.takeBytes()).bytes,
      );
      return E2eeAttachmentManifest(
        attachmentId: attachmentId,
        uploadId: uploadId,
        chunkKeyEpoch: chunkKeyEpoch,
        manifestKeyEpoch: manifestKeyEpoch,
        manifestRevision: manifestRevision,
        kind: E2eeAttachmentKind.file,
        totalPlaintextBytes: totalPlaintextBytes,
        contentSha256: digest,
        wrappedDataKey: Uint8List.fromList(
          List<int>.filled(KelivoAttachmentLimits.wrappedDataKeyBytes, 0x71),
        ),
        chunkCiphertextBytes: List<int>.generate(
          layout.chunkCount,
          (index) =>
              layout.plaintextLengthForChunk(index) +
              KelivoAttachmentLimits.chunkEnvelopeOverheadBytes,
          growable: false,
        ),
        displayName: 'download.txt',
        mediaType: 'text/plain',
      );
    }

    Map<String, Object?> attachmentPayload({
      int chunkKeyEpoch = 7,
      int manifestKeyEpoch = 7,
      int manifestRevision = 1,
    }) => <String, Object?>{
      'attachmentId': attachmentId,
      'uploadId': uploadId,
      'chunkKeyEpoch': chunkKeyEpoch,
      'manifestKeyEpoch': manifestKeyEpoch,
      'manifestRevision': manifestRevision,
      'kind': 'file',
      'order': 0,
    };

    Future<E2eeSyncPulledValueChange> createMessageChange({
      required int operation,
      required String messageId,
      int chunkKeyEpoch = 7,
      int manifestKeyEpoch = 7,
      int manifestRevision = 1,
    }) async {
      final wire = await createPullValueChange(
        changeSeq: operation,
        revision: 1,
        operation: operation,
        entityKey: SyncEntityKey(
          entityType: E2eeSyncChatRecordTypes.message,
          entityId: messageId,
        ),
        payload: _messagePayload(
          conversationId: 'download-conversation',
          turnId: 'download-turn',
          groupId: 'download-group-$operation',
          attachments: <Object?>[
            attachmentPayload(
              chunkKeyEpoch: chunkKeyEpoch,
              manifestKeyEpoch: manifestKeyEpoch,
              manifestRevision: manifestRevision,
            ),
          ],
        ),
      );
      return authenticatePulledValueChange(wire);
    }

    E2eeAttachmentDownloadCoordinator createCoordinator({
      required _FakeAttachmentTransport transport,
      required _FakeAttachmentCrypto crypto,
      required E2eeAttachmentFileStore fileStore,
      required DateTime Function() utcNow,
    }) {
      var leaseSequence = 0;
      return E2eeAttachmentDownloadCoordinator.takeOwnership(
        commands: attachmentDownloads,
        transport: transport,
        token: token,
        crypto: crypto,
        fileStore: fileStore,
        leaseOwner: 'download-test-runtime',
        utcNow: utcNow,
        leaseTokenFactory: () => 'download-lease-${leaseSequence++}',
      );
    }

    test('远端步骤预算跨重启续传且重复身份只下载一次', () async {
      final firstPlaintext = Uint8List.fromList(
        List<int>.filled(KelivoAttachmentLimits.chunkPlaintextBytes, 0x31),
      );
      final secondPlaintext = Uint8List.fromList(<int>[4, 5, 6]);
      final plaintextChunks = <Uint8List>[firstPlaintext, secondPlaintext];
      final manifest = createManifest(plaintextChunks: plaintextChunks);
      final transport = _FakeAttachmentTransport(manifest);
      final fileStore = E2eeAttachmentMemoryFileStore();
      var now = DateTime.utc(2026, 7, 29, 8);
      final firstCrypto = _FakeAttachmentCrypto(
        currentKeyEpoch: 7,
        manifest: manifest,
        plaintextChunks: plaintextChunks,
      );
      final firstCoordinator = createCoordinator(
        transport: transport,
        crypto: firstCrypto,
        fileStore: fileStore,
        utcNow: () => now,
      );
      final firstMessage = await createMessageChange(
        operation: 201,
        messageId: 'download-message-1',
      );
      final repeatedMessage = await createMessageChange(
        operation: 202,
        messageId: 'download-message-2',
      );

      final firstPreparation = await firstCoordinator.preparePage(
        <E2eeSyncPulledChange>[firstMessage, repeatedMessage],
        maximumRemoteSteps: 2,
      );

      expect(firstPreparation, E2eeSyncPullPagePreparationDisposition.pending);
      final reference = E2eeAttachmentDownloadReference(
        attachmentId: attachmentId,
        uploadId: uploadId,
        chunkKeyEpoch: 7,
        manifestKeyEpoch: 7,
        manifestRevision: 1,
        kind: E2eeAttachmentKind.file,
      );
      final checkpoint = (await attachmentDownloads.read(reference))!;
      expect(checkpoint.phase, E2eeAttachmentDownloadPhase.downloading);
      expect(checkpoint.nextChunkIndex, 1);
      expect(
        checkpoint.confirmedPlaintextBytes,
        KelivoAttachmentLimits.chunkPlaintextBytes,
      );
      expect(transport.manifestRequests, 1);
      expect(transport.chunkRequests, <int>[0]);
      await firstCoordinator.close();

      now = now.add(const Duration(seconds: 1));
      final secondCoordinator = createCoordinator(
        transport: transport,
        crypto: _FakeAttachmentCrypto(
          currentKeyEpoch: 7,
          manifest: manifest,
          plaintextChunks: plaintextChunks,
        ),
        fileStore: fileStore,
        utcNow: () => now,
      );
      final completed = await secondCoordinator.preparePage(
        <E2eeSyncPulledChange>[repeatedMessage, firstMessage],
        maximumRemoteSteps: 1,
      );

      expect(completed, E2eeSyncPullPagePreparationDisposition.ready);
      expect(transport.manifestRequests, 1);
      expect(transport.chunkRequests, <int>[0, 1]);
      final registrations = await secondCoordinator.requireReadyForApply(
        firstMessage,
      );
      expect(registrations, hasLength(1));
      final registration = registrations.single;
      expect(
        registration.assetId,
        'asset_${_digestHex(manifest.contentSha256)}',
      );
      expect(registration.contentHash, _digestHex(manifest.contentSha256));
      expect(registration.byteSize, manifest.totalPlaintextBytes);
      expect(registration.kind, 'file');
      expect(registration.displayName, 'download.txt');
      expect(registration.mediaType, 'text/plain');
      expect(registration.attachmentId, attachmentId);
      expect(registration.uploadId, uploadId);
      expect(registration.chunkKeyEpoch, 7);
      expect(registration.manifestKeyEpoch, 7);
      expect(registration.manifestRevision, 1);
      expect(
        registration.path,
        'memory://kelivo-e2ee-attachments/content/'
        '${_digestHex(manifest.contentSha256)}',
      );
      await secondCoordinator.close();
    });

    test('离线跨代仅认证新清单并复用已校验完成文件', () async {
      final plaintextChunks = <Uint8List>[
        Uint8List.fromList(<int>[1, 2, 3]),
      ];
      final oldManifest = createManifest(plaintextChunks: plaintextChunks);
      final fileStore = E2eeAttachmentMemoryFileStore();
      var now = DateTime.utc(2026, 7, 29, 8, 30);
      final oldTransport = _FakeAttachmentTransport(oldManifest);
      final oldCoordinator = createCoordinator(
        transport: oldTransport,
        crypto: _FakeAttachmentCrypto(
          currentKeyEpoch: 7,
          manifest: oldManifest,
          plaintextChunks: plaintextChunks,
        ),
        fileStore: fileStore,
        utcNow: () => now,
      );
      final oldRevision = await createMessageChange(
        operation: 211,
        messageId: 'download-old-manifest-revision',
      );

      expect(
        await oldCoordinator.preparePage(<E2eeSyncPulledChange>[
          oldRevision,
        ], maximumRemoteSteps: 2),
        E2eeSyncPullPagePreparationDisposition.ready,
      );
      expect(oldTransport.chunkRequests, <int>[0]);
      await oldCoordinator.close();

      now = now.add(const Duration(seconds: 1));
      final rotatedManifest = createManifest(
        chunkKeyEpoch: 7,
        manifestKeyEpoch: 9,
        manifestRevision: 3,
        plaintextChunks: plaintextChunks,
      );
      final rotatedTransport = _FakeAttachmentTransport(rotatedManifest);
      final rotatedCoordinator = createCoordinator(
        transport: rotatedTransport,
        crypto: _FakeAttachmentCrypto(
          currentKeyEpoch: 9,
          manifest: rotatedManifest,
          plaintextChunks: plaintextChunks,
        ),
        fileStore: fileStore,
        utcNow: () => now,
      );
      final rotatedRevision = await createMessageChange(
        operation: 212,
        messageId: 'download-rotated-manifest-revision',
        manifestKeyEpoch: 9,
        manifestRevision: 3,
      );

      expect(
        await rotatedCoordinator.preparePage(<E2eeSyncPulledChange>[
          rotatedRevision,
        ], maximumRemoteSteps: 1),
        E2eeSyncPullPagePreparationDisposition.ready,
      );
      expect(rotatedTransport.manifestRequests, 1);
      expect(rotatedTransport.chunkRequests, isEmpty);
      final rows = await database
          .select(database.e2eeAttachmentDownloadRows)
          .get();
      expect(rows, hasLength(1));
      expect(rows.single.manifestKeyEpoch, 9);
      expect(rows.single.manifestRevision, 3);
      expect(rows.single.phase, E2eeAttachmentDownloadPhase.ready.wireValue);
      final registrations = await rotatedCoordinator.requireReadyForApply(
        rotatedRevision,
      );
      expect(registrations.single.manifestKeyEpoch, 9);
      expect(registrations.single.manifestRevision, 3);
      await rotatedCoordinator.close();
    });

    test('清理暂存回执在物理删除后崩溃可幂等恢复且先于发网', () async {
      final plaintextChunks = <Uint8List>[
        Uint8List.fromList(<int>[1, 2, 3]),
      ];
      final oldManifest = createManifest(plaintextChunks: plaintextChunks);
      final fileStore = _DeleteAfterRemovalFailingAttachmentFileStore(
        E2eeAttachmentMemoryFileStore(),
      );
      var now = DateTime.utc(2026, 7, 29, 8, 45);
      final oldCoordinator = createCoordinator(
        transport: _FakeAttachmentTransport(oldManifest),
        crypto: _FakeAttachmentCrypto(
          currentKeyEpoch: 7,
          manifest: oldManifest,
          plaintextChunks: plaintextChunks,
        ),
        fileStore: fileStore,
        utcNow: () => now,
      );
      final oldRevision = await createMessageChange(
        operation: 213,
        messageId: 'download-cleanup-old-revision',
      );
      expect(
        await oldCoordinator.preparePage(<E2eeSyncPulledChange>[
          oldRevision,
        ], maximumRemoteSteps: 1),
        E2eeSyncPullPagePreparationDisposition.pending,
      );
      await oldCoordinator.close();

      now = now.add(const Duration(seconds: 1));
      final rotatedManifest = createManifest(
        chunkKeyEpoch: 7,
        manifestKeyEpoch: 8,
        manifestRevision: 2,
        plaintextChunks: plaintextChunks,
      );
      final rotatedTransport = _FakeAttachmentTransport(rotatedManifest);
      final rotatedCoordinator = createCoordinator(
        transport: rotatedTransport,
        crypto: _FakeAttachmentCrypto(
          currentKeyEpoch: 8,
          manifest: rotatedManifest,
          plaintextChunks: plaintextChunks,
        ),
        fileStore: fileStore,
        utcNow: () => now,
      );
      final rotatedRevision = await createMessageChange(
        operation: 214,
        messageId: 'download-cleanup-rotated-revision',
        manifestKeyEpoch: 8,
        manifestRevision: 2,
      );
      fileStore.failNextDeleteAfterRemoval = true;

      expect(
        await rotatedCoordinator.preparePage(<E2eeSyncPulledChange>[
          rotatedRevision,
        ], maximumRemoteSteps: 1),
        E2eeSyncPullPagePreparationDisposition.pending,
      );
      expect(fileStore.deleteRequests, 1);
      expect(rotatedTransport.manifestRequests, 0);
      final reference = E2eeAttachmentDownloadReference(
        attachmentId: attachmentId,
        uploadId: uploadId,
        chunkKeyEpoch: 7,
        manifestKeyEpoch: 8,
        manifestRevision: 2,
        kind: E2eeAttachmentKind.file,
      );
      final failedCleanup = (await attachmentDownloads.read(reference))!;
      expect(failedCleanup.cleanupStagingPath, isNot(equals(null)));
      expect(failedCleanup.lastFailureKind, 'local-io-manifest-pending');

      now = now.add(const Duration(seconds: 2));
      expect(
        await rotatedCoordinator.preparePage(<E2eeSyncPulledChange>[
          rotatedRevision,
        ], maximumRemoteSteps: 1),
        E2eeSyncPullPagePreparationDisposition.pending,
      );
      expect(fileStore.deleteRequests, 2);
      expect(rotatedTransport.manifestRequests, 1);
      final recovered = (await attachmentDownloads.read(reference))!;
      expect(recovered.cleanupStagingPath, equals(null));
      expect(recovered.phase, E2eeAttachmentDownloadPhase.downloading);
      await rotatedCoordinator.close();
    });

    test('未来附件代次在建状态和发网前暂停', () async {
      final manifest = createManifest();
      final transport = _FakeAttachmentTransport(manifest);
      final crypto = _FakeAttachmentCrypto(
        currentKeyEpoch: 7,
        manifest: manifest,
        plaintextChunks: <Uint8List>[
          Uint8List.fromList(<int>[1, 2, 3]),
        ],
      );
      final coordinator = createCoordinator(
        transport: transport,
        crypto: crypto,
        fileStore: E2eeAttachmentMemoryFileStore(),
        utcNow: () => DateTime.utc(2026, 7, 29, 9),
      );
      final change = await createMessageChange(
        operation: 203,
        messageId: 'download-future-epoch',
        chunkKeyEpoch: 8,
        manifestKeyEpoch: 8,
      );

      final disposition = await coordinator.preparePage(<E2eeSyncPulledChange>[
        change,
      ], maximumRemoteSteps: 1);

      expect(
        disposition,
        E2eeSyncPullPagePreparationDisposition.keyEpochUnavailable,
      );
      expect(transport.manifestRequests, 0);
      expect(
        await database.select(database.e2eeAttachmentDownloadRows).get(),
        isEmpty,
      );
      await coordinator.close();
    });

    test('清单与分块认证篡改进入永久失败且不提升 ready', () async {
      final manifest = createManifest();
      final message = await createMessageChange(
        operation: 204,
        messageId: 'download-tampered-manifest',
      );
      var now = DateTime.utc(2026, 7, 29, 10);
      final manifestCrypto = _FakeAttachmentCrypto(
        currentKeyEpoch: 7,
        manifest: manifest,
        plaintextChunks: <Uint8List>[
          Uint8List.fromList(<int>[1, 2, 3]),
        ],
      )..manifestFailure = const FormatException('manifest-tampered');
      final manifestCoordinator = createCoordinator(
        transport: _FakeAttachmentTransport(manifest),
        crypto: manifestCrypto,
        fileStore: E2eeAttachmentMemoryFileStore(),
        utcNow: () => now,
      );

      await expectLater(
        manifestCoordinator.preparePage(<E2eeSyncPulledChange>[
          message,
        ], maximumRemoteSteps: 1),
        throwsFormatException,
      );
      final reference = E2eeAttachmentDownloadReference(
        attachmentId: attachmentId,
        uploadId: uploadId,
        chunkKeyEpoch: 7,
        manifestKeyEpoch: 7,
        manifestRevision: 1,
        kind: E2eeAttachmentKind.file,
      );
      expect(
        (await attachmentDownloads.read(reference))!.terminalFailureKind,
        'invalid-manifest-pending',
      );
      await manifestCoordinator.close();
      expect(
        await attachmentDownloads.deleteFailedForRebuild(
          reference: reference,
          expectedTransitionVersion: (await attachmentDownloads.read(
            reference,
          ))!.transitionVersion,
          now: now,
        ),
        isTrue,
      );

      now = now.add(const Duration(seconds: 1));
      final chunkCrypto = _FakeAttachmentCrypto(
        currentKeyEpoch: 7,
        manifest: manifest,
        plaintextChunks: <Uint8List>[
          Uint8List.fromList(<int>[1, 2, 3]),
        ],
      )..chunkFailureIndex = 0;
      final chunkCoordinator = createCoordinator(
        transport: _FakeAttachmentTransport(manifest),
        crypto: chunkCrypto,
        fileStore: E2eeAttachmentMemoryFileStore(),
        utcNow: () => now,
      );
      expect(
        await chunkCoordinator.preparePage(<E2eeSyncPulledChange>[
          message,
        ], maximumRemoteSteps: 1),
        E2eeSyncPullPagePreparationDisposition.pending,
      );
      now = now.add(const Duration(seconds: 1));
      await expectLater(
        chunkCoordinator.preparePage(<E2eeSyncPulledChange>[
          message,
        ], maximumRemoteSteps: 1),
        throwsFormatException,
      );
      final terminal = (await attachmentDownloads.read(reference))!;
      expect(terminal.terminalFailureKind, 'invalid-downloading');
      expect(terminal.confirmedPlaintextBytes, 0);
      expect(await attachmentDownloads.readReady(reference), equals(null));
      await chunkCoordinator.close();
    });

    test('可重试网络失败持久退避且到期前不重复发网', () async {
      final manifest = createManifest();
      final transport = _FakeAttachmentTransport(manifest)
        ..manifestFailure = const CloudSyncException(
          kind: CloudSyncFailureKind.network,
          retryable: true,
        );
      final crypto = _FakeAttachmentCrypto(
        currentKeyEpoch: 7,
        manifest: manifest,
        plaintextChunks: <Uint8List>[
          Uint8List.fromList(<int>[1, 2, 3]),
        ],
      );
      var now = DateTime.utc(2026, 7, 29, 11);
      final coordinator = createCoordinator(
        transport: transport,
        crypto: crypto,
        fileStore: E2eeAttachmentMemoryFileStore(),
        utcNow: () => now,
      );
      final message = await createMessageChange(
        operation: 205,
        messageId: 'download-network-retry',
      );

      expect(
        await coordinator.preparePage(<E2eeSyncPulledChange>[
          message,
        ], maximumRemoteSteps: 1),
        E2eeSyncPullPagePreparationDisposition.pending,
      );
      expect(transport.manifestRequests, 1);
      expect(
        await coordinator.preparePage(<E2eeSyncPulledChange>[
          message,
        ], maximumRemoteSteps: 1),
        E2eeSyncPullPagePreparationDisposition.pending,
      );
      expect(transport.manifestRequests, 1);

      now = now.add(const Duration(seconds: 2));
      transport.manifestFailure = null;
      expect(
        await coordinator.preparePage(<E2eeSyncPulledChange>[
          message,
        ], maximumRemoteSteps: 1),
        E2eeSyncPullPagePreparationDisposition.pending,
      );
      expect(transport.manifestRequests, 2);
      final reference = E2eeAttachmentDownloadReference(
        attachmentId: attachmentId,
        uploadId: uploadId,
        chunkKeyEpoch: 7,
        manifestKeyEpoch: 7,
        manifestRevision: 1,
        kind: E2eeAttachmentKind.file,
      );
      final state = (await attachmentDownloads.read(reference))!;
      expect(state.phase, E2eeAttachmentDownloadPhase.downloading);
      expect(state.consecutiveFailureCount, 0);
      await coordinator.close();
    });
  });

  test('附件清单密文往返并隐藏敏感元数据', () async {
    const secureCore = KelivoSecureCore();
    final accountRootKey = await secureCore.generateAccountRootKey(
      userId: Uuid.parseAsByteList(_ledgerUserId),
      keyEpoch: 7,
    );
    final attachmentDataKey = await secureCore.generateAttachmentDataKey();
    final attachmentId = Uuid.unparse(attachmentDataKey.attachmentId);
    const uploadId = 'a0000000-0000-4000-8000-000000000001';
    final attachmentContext = KelivoAttachmentContext(
      userId: Uuid.parseAsByteList(_ledgerUserId),
      attachmentId: attachmentDataKey.attachmentId,
      keyEpoch: 7,
    );
    final wrappedDataKey = await secureCore.wrapAttachmentDataKey(
      accountRootKey,
      attachmentDataKey.key,
      context: attachmentContext,
    );
    final contentDigest = Uint8List.fromList(List<int>.filled(32, 0x5a));
    final manifest = E2eeAttachmentManifest(
      attachmentId: attachmentId,
      uploadId: uploadId,
      chunkKeyEpoch: 7,
      manifestKeyEpoch: 7,
      manifestRevision: 1,
      kind: E2eeAttachmentKind.file,
      totalPlaintextBytes: KelivoAttachmentLimits.chunkPlaintextBytes + 1,
      contentSha256: contentDigest,
      wrappedDataKey: wrappedDataKey,
      chunkCiphertextBytes: <int>[
        KelivoAttachmentLimits.maxChunkEnvelopeBytes,
        KelivoAttachmentLimits.chunkEnvelopeOverheadBytes + 1,
      ],
      displayName: '计划.txt',
      mediaType: 'text/plain',
    );
    final manifestCipher = E2eeAttachmentManifestCipher.takeOwnership(
      E2eeAccountRecordCipher.takeOwnership(
        secureCore: secureCore,
        accountRootKey: accountRootKey,
        userId: _ledgerUserId,
        currentKeyEpoch: 7,
      ),
    );

    try {
      final sealed = await manifestCipher.seal(manifest);
      expect(
        _containsByteSequence(sealed.ciphertext, utf8.encode('计划.txt')),
        isFalse,
      );
      expect(
        _containsByteSequence(sealed.ciphertext, ascii.encode('text/plain')),
        isFalse,
      );

      final opened = await manifestCipher.open(
        attachmentId: attachmentId,
        uploadId: uploadId,
        chunkKeyEpoch: 7,
        manifestKeyEpoch: 7,
        manifestRevision: 1,
        ciphertext: sealed.ciphertext,
      );
      expect(opened.attachmentId, attachmentId);
      expect(opened.uploadId, uploadId);
      expect(opened.chunkKeyEpoch, 7);
      expect(opened.manifestKeyEpoch, 7);
      expect(opened.manifestRevision, 1);
      expect(opened.kind, E2eeAttachmentKind.file);
      expect(opened.displayName, '计划.txt');
      expect(opened.mediaType, 'text/plain');
      expect(opened.contentSha256, orderedEquals(contentDigest));
      expect(opened.wrappedDataKey, orderedEquals(wrappedDataKey));
      expect(
        opened.chunkCiphertextBytes,
        orderedEquals(<int>[
          KelivoAttachmentLimits.maxChunkEnvelopeBytes,
          KelivoAttachmentLimits.chunkEnvelopeOverheadBytes + 1,
        ]),
      );
    } finally {
      await secureCore.closeAttachmentDataKey(attachmentDataKey.key);
      await manifestCipher.close();
    }
  });

  test('附件清单拒绝篡改和外层身份错配', () async {
    const secureCore = KelivoSecureCore();
    final accountRootKey = await secureCore.generateAccountRootKey(
      userId: Uuid.parseAsByteList(_ledgerUserId),
      keyEpoch: 7,
    );
    final attachmentDataKey = await secureCore.generateAttachmentDataKey();
    final attachmentId = Uuid.unparse(attachmentDataKey.attachmentId);
    const uploadId = 'a0000000-0000-4000-8000-000000000002';
    final wrappedDataKey = await secureCore.wrapAttachmentDataKey(
      accountRootKey,
      attachmentDataKey.key,
      context: KelivoAttachmentContext(
        userId: Uuid.parseAsByteList(_ledgerUserId),
        attachmentId: attachmentDataKey.attachmentId,
        keyEpoch: 7,
      ),
    );
    final manifestCipher = E2eeAttachmentManifestCipher.takeOwnership(
      E2eeAccountRecordCipher.takeOwnership(
        secureCore: secureCore,
        accountRootKey: accountRootKey,
        userId: _ledgerUserId,
        currentKeyEpoch: 7,
      ),
    );

    try {
      final sealed = await manifestCipher.seal(
        E2eeAttachmentManifest(
          attachmentId: attachmentId,
          uploadId: uploadId,
          chunkKeyEpoch: 7,
          manifestKeyEpoch: 7,
          manifestRevision: 1,
          kind: E2eeAttachmentKind.image,
          totalPlaintextBytes: 0,
          contentSha256: Uint8List(32),
          wrappedDataKey: wrappedDataKey,
          chunkCiphertextBytes: <int>[
            KelivoAttachmentLimits.chunkEnvelopeOverheadBytes,
          ],
        ),
      );
      final tampered = Uint8List.fromList(sealed.ciphertext)
        ..[sealed.ciphertext.length - 1] ^= 1;

      await expectLater(
        manifestCipher.open(
          attachmentId: attachmentId,
          uploadId: uploadId,
          chunkKeyEpoch: 7,
          manifestKeyEpoch: 7,
          manifestRevision: 1,
          ciphertext: tampered,
        ),
        throwsA(
          isA<KelivoSecureCoreException>().having(
            (error) => error.status,
            'status',
            KelivoSecureCoreStatus.recordAuthenticationFailed,
          ),
        ),
      );
      await expectLater(
        manifestCipher.open(
          attachmentId: attachmentId,
          uploadId: 'a0000000-0000-4000-8000-000000000003',
          chunkKeyEpoch: 7,
          manifestKeyEpoch: 7,
          manifestRevision: 1,
          ciphertext: sealed.ciphertext,
        ),
        throwsFormatException,
      );
      await expectLater(
        manifestCipher.open(
          attachmentId: attachmentId,
          uploadId: uploadId,
          chunkKeyEpoch: 7,
          manifestKeyEpoch: 7,
          manifestRevision: 1,
          ciphertext: Uint8List.sublistView(
            sealed.ciphertext,
            0,
            sealed.ciphertext.length - 1,
          ),
        ),
        throwsA(isA<KelivoSecureCoreException>()),
      );
    } finally {
      await secureCore.closeAttachmentDataKey(attachmentDataKey.key);
      await manifestCipher.close();
    }
  });

  test('附件清单严格校验边界、布局和文件元数据', () {
    final maximumManifest = E2eeAttachmentManifest(
      attachmentId: 'b0000000-0000-4000-8000-000000000001',
      uploadId: 'c0000000-0000-4000-8000-000000000001',
      chunkKeyEpoch: 0xffffffff,
      manifestKeyEpoch: 0xffffffff,
      manifestRevision: 1,
      kind: E2eeAttachmentKind.image,
      totalPlaintextBytes: KelivoAttachmentLimits.maxTotalPlaintextBytes,
      contentSha256: Uint8List(32),
      wrappedDataKey: Uint8List(KelivoAttachmentLimits.wrappedDataKeyBytes),
      chunkCiphertextBytes: List<int>.filled(
        KelivoAttachmentLimits.maxChunkCount,
        KelivoAttachmentLimits.maxChunkEnvelopeBytes,
      ),
    );
    expect(
      maximumManifest.totalCiphertextBytes,
      KelivoAttachmentLimits.maxChunkCount *
          KelivoAttachmentLimits.maxChunkEnvelopeBytes,
    );

    expect(
      () => E2eeAttachmentManifest(
        attachmentId: 'b0000000-0000-4000-8000-000000000002',
        uploadId: 'c0000000-0000-4000-8000-000000000002',
        chunkKeyEpoch: 7,
        manifestKeyEpoch: 7,
        manifestRevision: 1,
        kind: E2eeAttachmentKind.file,
        totalPlaintextBytes: 1,
        contentSha256: Uint8List(32),
        wrappedDataKey: Uint8List(KelivoAttachmentLimits.wrappedDataKeyBytes),
        chunkCiphertextBytes: <int>[
          KelivoAttachmentLimits.chunkEnvelopeOverheadBytes,
        ],
        displayName: '../secret.txt',
        mediaType: 'text/plain',
      ),
      throwsFormatException,
    );
    expect(
      () => E2eeAttachmentManifest(
        attachmentId: 'b0000000-0000-4000-8000-000000000003',
        uploadId: 'c0000000-0000-4000-8000-000000000003',
        chunkKeyEpoch: 7,
        manifestKeyEpoch: 7,
        manifestRevision: 1,
        kind: E2eeAttachmentKind.file,
        totalPlaintextBytes: 1,
        contentSha256: Uint8List(32),
        wrappedDataKey: Uint8List(
          KelivoAttachmentLimits.wrappedDataKeyBytes - 1,
        ),
        chunkCiphertextBytes: <int>[
          KelivoAttachmentLimits.chunkEnvelopeOverheadBytes + 1,
        ],
      ),
      throwsFormatException,
    );
    expect(
      () => E2eeAttachmentManifest(
        attachmentId: 'b0000000-0000-4000-8000-000000000004',
        uploadId: 'c0000000-0000-4000-8000-000000000004',
        chunkKeyEpoch: 7,
        manifestKeyEpoch: 7,
        manifestRevision: 1,
        kind: E2eeAttachmentKind.image,
        totalPlaintextBytes: 1,
        contentSha256: Uint8List(32),
        wrappedDataKey: Uint8List(KelivoAttachmentLimits.wrappedDataKeyBytes),
        chunkCiphertextBytes: <int>[
          KelivoAttachmentLimits.chunkEnvelopeOverheadBytes,
        ],
      ),
      throwsFormatException,
    );
    expect(
      () => E2eeAttachmentManifest(
        attachmentId: 'b0000000-0000-4000-8000-000000000005',
        uploadId: 'c0000000-0000-4000-8000-000000000005',
        chunkKeyEpoch: 7,
        manifestKeyEpoch: 7,
        manifestRevision: 1,
        kind: E2eeAttachmentKind.file,
        totalPlaintextBytes: 1,
        contentSha256: Uint8List(32),
        wrappedDataKey: Uint8List(KelivoAttachmentLimits.wrappedDataKeyBytes),
        chunkCiphertextBytes: <int>[
          KelivoAttachmentLimits.chunkEnvelopeOverheadBytes + 1,
        ],
      ),
      throwsFormatException,
    );
  });

  test('DateTime values round-trip with microsecond precision', () async {
    final timestamp = DateTime.fromMicrosecondsSinceEpoch(
      1783784523123456,
      isUtc: true,
    );
    await insertConversation(timestamp: timestamp);
    await insertMessage(timestamp: timestamp);

    final conversation = await database
        .select(database.conversationRows)
        .getSingle();
    final message = await database.select(database.messageRows).getSingle();
    expect(conversation.createdAt.microsecondsSinceEpoch, 1783784523123456);
    expect(message.timestamp.microsecondsSinceEpoch, 1783784523123456);
  });

  test('critical list and revision queries use stable indexes', () async {
    await insertConversation();
    await insertMessage();

    Future<String> plan(String sql, List<Variable<Object>> variables) async {
      final rows = await database
          .customSelect('EXPLAIN QUERY PLAN $sql', variables: variables)
          .get();
      return rows.map((row) => row.read<String>('detail')).join('\n');
    }

    expect(
      await plan(
        'SELECT id FROM conversation_rows '
        'ORDER BY updated_at DESC, id ASC LIMIT 50;',
        const [],
      ),
      contains('idx_conversations_updated_at'),
    );
    expect(
      await plan(
        'SELECT id FROM message_rows WHERE conversation_id = ? '
        'ORDER BY timestamp ASC, id ASC;',
        [const Variable<String>('conversation-1')],
      ),
      contains('idx_messages_conversation_timestamp'),
    );
    expect(
      await plan(
        'SELECT id FROM message_rows '
        'WHERE conversation_id = ? AND group_id = ? '
        'ORDER BY version ASC, id ASC;',
        const [Variable<String>('conversation-1'), Variable<String>('group-1')],
      ),
      contains('idx_messages_group'),
    );
  });
}

typedef _PullHandler =
    Future<CloudSyncPullResult> Function(String? cursor, int limit);
typedef _SnapshotPullHandler =
    Future<CloudSyncSnapshotPage> Function(String? cursor, int limit);

final class _FakeAuthenticatedPullTransport
    implements E2eeSyncAuthenticatedPullTransport {
  _FakeAuthenticatedPullTransport({
    required this.accountUserId,
    required this.onPull,
    this.onSnapshot,
  });

  @override
  final String accountUserId;

  final _PullHandler onPull;
  final _SnapshotPullHandler? onSnapshot;
  final List<String?> cursors = <String?>[];
  final List<String?> snapshotCursors = <String?>[];
  int callCount = 0;
  int snapshotCallCount = 0;

  @override
  Future<CloudSyncPullResult> pullChanges({String? cursor, int limit = 10}) {
    callCount++;
    cursors.add(cursor);
    return onPull(cursor, limit);
  }

  @override
  Future<CloudSyncSnapshotPage> pullSnapshot({
    String? snapshotCursor,
    int limit = 10,
  }) {
    final handler = onSnapshot;
    if (handler == null) throw StateError('测试未配置快照 pull');
    snapshotCallCount++;
    snapshotCursors.add(snapshotCursor);
    return handler(snapshotCursor, limit);
  }
}

final class _FakePullPagePreparer implements E2eeSyncPullPagePreparer {
  _FakePullPagePreparer(this.disposition);

  final E2eeSyncPullPagePreparationDisposition disposition;
  final List<List<E2eeSyncPulledChange>> pages = <List<E2eeSyncPulledChange>>[];
  final List<int> maximumRemoteSteps = <int>[];

  @override
  Future<E2eeSyncPullPagePreparationDisposition> preparePage(
    List<E2eeSyncPulledChange> authenticatedChanges, {
    required int maximumRemoteSteps,
    E2eeSyncExecutionBudget? executionBudget,
  }) async {
    pages.add(List<E2eeSyncPulledChange>.unmodifiable(authenticatedChanges));
    this.maximumRemoteSteps.add(maximumRemoteSteps);
    return disposition;
  }
}

final class _BudgetConsumingPullPagePreparer
    implements E2eeSyncPullPagePreparer {
  int remoteCalls = 0;

  @override
  Future<E2eeSyncPullPagePreparationDisposition> preparePage(
    List<E2eeSyncPulledChange> authenticatedChanges, {
    required int maximumRemoteSteps,
    E2eeSyncExecutionBudget? executionBudget,
  }) async {
    final budget = executionBudget;
    if (budget == null) {
      throw StateError('测试缺少 E2EE 同步执行预算');
    }
    await budget.runNetworkStep<void>(
      operation: (_) async {
        remoteCalls++;
      },
    );
    return E2eeSyncPullPagePreparationDisposition.ready;
  }
}

final class _FixedMessageAttachmentReadiness
    implements E2eeMessageAttachmentReadiness {
  _FixedMessageAttachmentReadiness(List<MessageAssetRegistration> assets)
    : _assets = List<MessageAssetRegistration>.unmodifiable(assets);

  final List<MessageAssetRegistration> _assets;
  final List<String> messageIds = <String>[];

  @override
  Future<List<MessageAssetRegistration>> requireReadyForApply(
    E2eeSyncPulledValueChange messageChange,
  ) async {
    messageIds.add(messageChange.state.entityKey.entityId);
    return _assets;
  }
}

final class _DeleteAfterRemovalFailingAttachmentFileStore
    implements E2eeAttachmentFileStore {
  _DeleteAfterRemovalFailingAttachmentFileStore(this._delegate);

  final E2eeAttachmentFileStore _delegate;
  bool failNextDeleteAfterRemoval = false;
  int deleteRequests = 0;

  @override
  Future<E2eeAttachmentStoredFile> publish({
    required E2eeAttachmentFileLocation location,
    required Stream<List<int>> source,
    E2eeAttachmentCheckCanContinue? checkCanContinue,
  }) => _delegate.publish(
    location: location,
    source: source,
    checkCanContinue: checkCanContinue,
  );

  @override
  Future<Uint8List> readVerified(
    E2eeAttachmentStoredFile storedFile, {
    E2eeAttachmentCheckCanContinue? checkCanContinue,
  }) => _delegate.readVerified(storedFile, checkCanContinue: checkCanContinue);

  @override
  Future<Uint8List> readContentRange({
    required E2eeAttachmentStoredFile storedFile,
    required int offset,
    required int length,
  }) => _delegate.readContentRange(
    storedFile: storedFile,
    offset: offset,
    length: length,
  );

  @override
  Future<E2eeAttachmentVerifiedContent> openVerifiedContent({
    required E2eeAttachmentStoredFile storedFile,
    required List<int> chunkPlaintextBytes,
    E2eeAttachmentCheckCanContinue? checkCanContinue,
  }) => _delegate.openVerifiedContent(
    storedFile: storedFile,
    chunkPlaintextBytes: chunkPlaintextBytes,
    checkCanContinue: checkCanContinue,
  );

  @override
  Future<void> verifyContent(E2eeAttachmentStoredFile storedFile) =>
      _delegate.verifyContent(storedFile);

  @override
  Future<String> resolveContentStoragePath(Uint8List contentSha256) =>
      _delegate.resolveContentStoragePath(contentSha256);

  @override
  Future<String> openDownloadPlaintextStaging({
    required CloudSyncAttachmentIdentity identity,
    required String? persistedStoragePath,
    required int confirmedPlaintextBytes,
  }) => _delegate.openDownloadPlaintextStaging(
    identity: identity,
    persistedStoragePath: persistedStoragePath,
    confirmedPlaintextBytes: confirmedPlaintextBytes,
  );

  @override
  Future<void> appendDownloadPlaintextChunk({
    required CloudSyncAttachmentIdentity identity,
    required String stagingPath,
    required int expectedOffset,
    required Uint8List plaintext,
  }) => _delegate.appendDownloadPlaintextChunk(
    identity: identity,
    stagingPath: stagingPath,
    expectedOffset: expectedOffset,
    plaintext: plaintext,
  );

  @override
  Future<E2eeAttachmentStoredFile> publishDownloadPlaintext({
    required CloudSyncAttachmentIdentity identity,
    required String stagingPath,
    required int expectedPlaintextBytes,
    required Uint8List expectedSha256,
  }) => _delegate.publishDownloadPlaintext(
    identity: identity,
    stagingPath: stagingPath,
    expectedPlaintextBytes: expectedPlaintextBytes,
    expectedSha256: expectedSha256,
  );

  @override
  Future<void> deleteStaging({required String storagePath}) async {
    deleteRequests++;
    await _delegate.deleteStaging(storagePath: storagePath);
    if (failNextDeleteAfterRemoval) {
      failNextDeleteAfterRemoval = false;
      throw FileSystemException(
        'e2ee_attachment_delete_interrupted_after_removal',
        storagePath,
      );
    }
  }
}

final class _FakeAttachmentCrypto implements E2eeAttachmentCrypto {
  _FakeAttachmentCrypto({
    required this.currentKeyEpoch,
    required this.manifest,
    required List<Uint8List> plaintextChunks,
  }) : _plaintextChunks = <Uint8List>[
         for (final chunk in plaintextChunks) Uint8List.fromList(chunk),
       ];

  @override
  final int currentKeyEpoch;
  final E2eeAttachmentManifest manifest;
  final List<Uint8List> _plaintextChunks;
  Object? manifestFailure;
  int? chunkFailureIndex;
  bool closed = false;

  @override
  Future<E2eeAttachmentDescriptor> createUploadDescriptor({
    required E2eeAttachmentKind kind,
    required int totalPlaintextBytes,
    required Uint8List contentSha256,
    String? displayName,
    String? mediaType,
  }) => Future<E2eeAttachmentDescriptor>.error(
    UnsupportedError('下载测试不得生成附件上传描述'),
  );

  @override
  Future<E2eeAttachmentManifest> openManifest({
    required String attachmentId,
    required String uploadId,
    required int chunkKeyEpoch,
    required int manifestKeyEpoch,
    required int manifestRevision,
    required Uint8List ciphertext,
  }) async {
    final failure = manifestFailure;
    if (failure != null) throw failure;
    if (attachmentId != manifest.attachmentId ||
        uploadId != manifest.uploadId ||
        chunkKeyEpoch != manifest.chunkKeyEpoch ||
        manifestKeyEpoch != manifest.manifestKeyEpoch ||
        manifestRevision != manifest.manifestRevision) {
      throw const FormatException('测试清单身份不一致');
    }
    return manifest;
  }

  @override
  Future<Uint8List> openChunk({
    required E2eeAttachmentManifest manifest,
    required int chunkIndex,
    required Uint8List ciphertext,
  }) async {
    if (chunkFailureIndex == chunkIndex) {
      throw const FormatException('chunk-tampered');
    }
    if (manifest.attachmentId != this.manifest.attachmentId ||
        manifest.uploadId != this.manifest.uploadId ||
        chunkIndex < 0 ||
        chunkIndex >= _plaintextChunks.length) {
      throw const FormatException('测试分块身份不一致');
    }
    return Uint8List.fromList(_plaintextChunks[chunkIndex]);
  }

  @override
  Future<E2eeSealedAttachmentManifest> sealManifest({
    required E2eeAttachmentDescriptor descriptor,
    required String uploadId,
    required int manifestRevision,
  }) => Future<E2eeSealedAttachmentManifest>.error(
    UnsupportedError('下载测试不得封装附件清单'),
  );

  @override
  Future<E2eeSealedAttachmentManifest> rewrapManifest({
    required E2eeAttachmentManifest source,
    required int targetManifestRevision,
  }) => Future<E2eeSealedAttachmentManifest>.error(
    UnsupportedError('下载测试不得重包附件清单'),
  );

  @override
  Future<Uint8List> sealChunk({
    required E2eeAttachmentDescriptor descriptor,
    required String uploadId,
    required int chunkIndex,
    required Uint8List plaintext,
  }) => Future<Uint8List>.error(UnsupportedError('下载测试不得加密附件分块'));

  @override
  Future<void> close() async {
    closed = true;
  }
}

final class _FakeAttachmentTransport implements CloudSyncAttachmentTransport {
  _FakeAttachmentTransport(this.manifest);

  final E2eeAttachmentManifest manifest;
  CloudSyncException? manifestFailure;
  int manifestRequests = 0;
  final List<int> chunkRequests = <int>[];

  CloudSyncAttachmentIdentity get _identity => CloudSyncAttachmentIdentity(
    attachmentId: manifest.attachmentId,
    uploadId: manifest.uploadId,
    chunkKeyEpoch: manifest.chunkKeyEpoch,
    manifestKeyEpoch: manifest.manifestKeyEpoch,
    manifestRevision: manifest.manifestRevision,
  );

  @override
  Future<CloudSyncAttachmentManifest> getAttachmentManifest({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentIdentity identity,
  }) async {
    manifestRequests++;
    final failure = manifestFailure;
    if (failure != null) throw failure;
    return CloudSyncAttachmentManifest(
      identity: _identity,
      chunkCount: manifest.chunkCiphertextBytes.length,
      totalCiphertextBytes: manifest.totalCiphertextBytes,
      manifestCiphertext: Uint8List.fromList(<int>[1, 2, 3]),
      manifestCiphertextBytes: 3,
      chunks: <CloudSyncAttachmentManifestChunk>[
        for (
          var index = 0;
          index < manifest.chunkCiphertextBytes.length;
          index++
        )
          CloudSyncAttachmentManifestChunk(
            chunkIndex: index,
            ciphertextBytes: manifest.chunkCiphertextBytes[index],
          ),
      ],
      committedAt: DateTime.utc(2026, 7, 29),
    );
  }

  @override
  Future<CloudSyncAttachmentChunk> getAttachmentChunk({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentChunkIdentity chunk,
  }) async {
    chunkRequests.add(chunk.chunkIndex);
    final ciphertextBytes = manifest.chunkCiphertextBytes[chunk.chunkIndex];
    return CloudSyncAttachmentChunk(
      chunk: chunk,
      ciphertext: Uint8List(ciphertextBytes),
      ciphertextBytes: ciphertextBytes,
    );
  }

  @override
  Future<CloudSyncAttachmentUpload> createAttachmentUpload({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentCreateUploadRequest request,
  }) =>
      Future<CloudSyncAttachmentUpload>.error(UnsupportedError('下载测试不得创建附件上传'));

  @override
  Future<CloudSyncAttachmentStoredChunk> putAttachmentChunk({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentPutChunkRequest request,
  }) => Future<CloudSyncAttachmentStoredChunk>.error(
    UnsupportedError('下载测试不得上传附件分块'),
  );

  @override
  Future<CloudSyncAttachmentCommittedUpload> commitAttachmentUpload({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentCommitUploadRequest request,
  }) => Future<CloudSyncAttachmentCommittedUpload>.error(
    UnsupportedError('下载测试不得提交附件上传'),
  );

  @override
  Future<CloudSyncAttachmentDeleted> deleteAttachment({
    required CloudSyncFullSessionToken token,
    required CloudSyncAttachmentDeleteRequest request,
  }) =>
      Future<CloudSyncAttachmentDeleted>.error(UnsupportedError('下载测试不得删除附件'));
}

final class _ApplyingOutboxTransport
    implements E2eeSyncAuthenticatedRecordTransport {
  _ApplyingOutboxTransport({
    required this.accountUserId,
    required this.actorDeviceId,
  });

  @override
  final String accountUserId;

  @override
  final String actorDeviceId;

  List<CloudSyncRecordMutation> mutations = const [];

  @override
  Future<List<CloudSyncRecordMutationResult>> pushRecords(
    List<CloudSyncRecordMutation> mutations,
  ) async {
    this.mutations = List.unmodifiable(mutations);
    return <CloudSyncRecordMutationResult>[
      for (var index = 0; index < mutations.length; index++)
        CloudSyncAppliedMutationResult(
          mutationId: mutations[index].mutationId,
          revision: mutations[index].expectedRevision + 1,
          changeSeq: 100 + index,
        ),
    ];
  }
}

Future<E2eeMembershipDeviceInput> _newDatabaseMembershipDevice(
  KelivoSecureCore secureCore, {
  required String deviceId,
  required int authGeneration,
}) async {
  final identity = await secureCore.generateDeviceIdentity();
  try {
    final publicKeys = await secureCore.readDevicePublicKeys(identity);
    return E2eeMembershipDeviceInput(
      deviceId: deviceId,
      keyVersion: 1,
      authGeneration: authGeneration,
      signingPublicKey: publicKeys.signingPublicKey,
      keyAgreementPublicKey: publicKeys.keyAgreementPublicKey,
    );
  } finally {
    await secureCore.closeDeviceIdentity(identity);
  }
}

Future<Uint8List> _newDatabaseRecoveryPublicKey(
  KelivoSecureCore secureCore,
) async {
  final identity = await secureCore.generateDeviceIdentity();
  try {
    final publicKeys = await secureCore.readDevicePublicKeys(identity);
    return Uint8List.fromList(publicKeys.keyAgreementPublicKey);
  } finally {
    await secureCore.closeDeviceIdentity(identity);
  }
}

final class _ZeroSourceDataRekeyCryptography
    implements E2eeDataRekeyCryptography {
  _ZeroSourceDataRekeyCryptography({
    this.issuerDeviceId = _syncActorDeviceId,
    this.targetKeyEpoch = 8,
  });

  int signatureCount = 0;

  @override
  final String issuerDeviceId;

  @override
  final int targetKeyEpoch;

  @override
  Future<E2eeDataRekeyRewrappedRecord> rewrapRecord(
    CloudSyncDataRekeySourceRecord source,
  ) => throw StateError('空源测试不得重包记录');

  @override
  Future<E2eeDataRekeyRewrappedAttachmentManifest> rewrapAttachmentManifest(
    CloudSyncDataRekeySourceAttachment source,
  ) => throw StateError('空源测试不得重包附件');

  @override
  Future<Uint8List> signCompletionProof(Uint8List proofFrame) async {
    expect(proofFrame, hasLength(e2eeDataRekeyCompletionFrameBytes));
    signatureCount += 1;
    return Uint8List(e2eeDataRekeyCompletionSignatureBytes)
      ..fillRange(0, e2eeDataRekeyCompletionSignatureBytes, 0x5a);
  }
}

final class _ZeroSourceDataRekeyTransport
    implements CloudSyncDataRekeyTransport {
  _ZeroSourceDataRekeyTransport({
    required this.userId,
    required this.issuerDeviceId,
    required this.operationId,
    this.sourceKeyEpoch = 7,
    this.targetKeyEpoch = 8,
  });

  final String userId;
  final String issuerDeviceId;
  final String operationId;
  final int sourceKeyEpoch;
  final int targetKeyEpoch;
  final List<CloudSyncDataRekeyFinalizeRequest> finalizeRequests =
      <CloudSyncDataRekeyFinalizeRequest>[];
  CloudSyncDataRekeyFinalizeRequest? _finalizedRequest;

  @override
  Future<CloudSyncDataRekeyState> getDataRekeyState() async {
    final finalizedRequest = _finalizedRequest;
    if (finalizedRequest != null) {
      return CloudSyncDataRekeyState.fromJson(<String, Object?>{
        'phase': 'ready',
        'dataGeneration': finalizedRequest.targetDataGeneration,
        'dataKeyEpoch': finalizedRequest.activeLease.operation.targetKeyEpoch,
        'changeWatermark': finalizedRequest.proof.sourceMaximumChangeSeq,
        'lastCompletion': _dataRekeyCompletionJson(
          userId: userId,
          request: finalizedRequest,
        ),
        'updatedAt': '2026-07-30T05:01:00.000Z',
      });
    }
    return CloudSyncDataRekeyState.fromJson(<String, Object?>{
      'phase': 'rekey-pending',
      'dataGeneration': 4,
      'dataKeyEpoch': sourceKeyEpoch,
      'changeWatermark': 0,
      'operationId': operationId,
      'targetKeyEpoch': targetKeyEpoch,
      'sourceRecordCount': 0,
      'sourceAttachmentCount': 0,
      'sourceMaximumChangeSeq': 0,
      'sourceRecordCursorEnd': null,
      'sourceAttachmentCursorEnd': null,
      'lease': null,
      'lastCompletion': null,
      'updatedAt': '2026-07-30T05:00:00.000Z',
    });
  }

  @override
  Future<CloudSyncDataRekeyLeaseClaim> claimDataRekeyLease(
    CloudSyncDataRekeyLeaseClaimRequest request,
  ) async {
    return CloudSyncDataRekeyLeaseClaim.fromJson(<String, Object?>{
      'phase': 'rekey-pending',
      'operationId': operationId,
      'sourceDataGeneration': 4,
      'sourceKeyEpoch': sourceKeyEpoch,
      'targetKeyEpoch': targetKeyEpoch,
      'leaseVersion': 1,
      'leaseExpiresAt': '2026-07-30T05:10:00.000Z',
      'sourceRecordCount': 0,
      'sourceAttachmentCount': 0,
      'sourceMaximumChangeSeq': 0,
      'sourceRecordCursorEnd': null,
      'sourceAttachmentCursorEnd': null,
    }, request: request);
  }

  @override
  Future<CloudSyncDataRekeySourceRecordPage> listDataRekeySourceRecords(
    CloudSyncDataRekeySourceRecordListRequest request,
  ) async {
    expect(request.limit, 10);
    return CloudSyncDataRekeySourceRecordPage.fromJson(<String, Object?>{
      'records': <Object?>[],
      'nextAfterRecordId': null,
      'hasMore': false,
    }, request: request);
  }

  @override
  Future<CloudSyncDataRekeySourceAttachmentPage> listDataRekeySourceAttachments(
    CloudSyncDataRekeySourceAttachmentListRequest request,
  ) async {
    expect(request.limit, 10);
    return CloudSyncDataRekeySourceAttachmentPage.fromJson(<String, Object?>{
      'attachments': <Object?>[],
      'nextAfterAttachmentId': null,
      'nextAfterUploadId': null,
      'hasMore': false,
    }, request: request);
  }

  @override
  Future<CloudSyncDataRekeyRecordStageResult> stageDataRekeyRecord(
    CloudSyncDataRekeyRecordStageRequest request,
  ) => throw StateError('空源测试不得暂存记录');

  @override
  Future<CloudSyncDataRekeyAttachmentStageResult> stageDataRekeyAttachment(
    CloudSyncDataRekeyAttachmentStageRequest request,
  ) => throw StateError('空源测试不得暂存附件');

  @override
  Future<CloudSyncDataRekeyFinalizeOutcome> finalizeDataRekey(
    CloudSyncDataRekeyFinalizeRequest request,
  ) async {
    finalizeRequests.add(request);
    if (finalizeRequests.length == 1) {
      return CloudSyncDataRekeyFinalizeOutcome.fromJson(<String, Object?>{
        'result': 'verification-pending',
        'operationId': operationId,
        'phase': 'verified',
        'sourceRecordCount': 0,
        'sourceAttachmentCount': 0,
        'stagedRecordCount': 0,
        'stagedAttachmentCount': 0,
      }, request: request);
    }
    final outcome = _finalizedDataRekeyOutcome(
      userId: userId,
      request: request,
    );
    _finalizedRequest = request;
    return outcome;
  }
}

final class _FinalizeResponseLossDataRekeyTransport
    extends _ZeroSourceDataRekeyTransport {
  _FinalizeResponseLossDataRekeyTransport({
    required super.userId,
    required super.issuerDeviceId,
    required super.operationId,
  });

  bool _ready = false;

  @override
  Future<CloudSyncDataRekeyState> getDataRekeyState() {
    if (!_ready) return super.getDataRekeyState();
    return Future<CloudSyncDataRekeyState>.value(
      CloudSyncDataRekeyState.fromJson(<String, Object?>{
        'phase': 'ready',
        'dataGeneration': 5,
        'dataKeyEpoch': 8,
        'changeWatermark': 0,
        'lastCompletion': null,
        'updatedAt': '2026-07-30T05:01:00.000Z',
      }),
    );
  }

  @override
  Future<CloudSyncDataRekeyFinalizeOutcome> finalizeDataRekey(
    CloudSyncDataRekeyFinalizeRequest request,
  ) async {
    finalizeRequests.add(request);
    if (finalizeRequests.length == 1) {
      _ready = true;
      throw StateError('simulated_finalize_response_loss');
    }
    final outcome = _finalizedDataRekeyOutcome(
      userId: userId,
      request: request,
    );
    _finalizedRequest = request;
    return outcome;
  }
}

final class _RecordDataRekeyCryptography implements E2eeDataRekeyCryptography {
  _RecordDataRekeyCryptography({required this.targetRecordId});

  final String targetRecordId;
  int recordRewrapCount = 0;

  @override
  final String issuerDeviceId = _syncActorDeviceId;

  @override
  final int targetKeyEpoch = 8;

  @override
  Future<E2eeDataRekeyRewrappedRecord> rewrapRecord(
    CloudSyncDataRekeySourceRecord source,
  ) async {
    recordRewrapCount += 1;
    return E2eeDataRekeyRewrappedRecord(
      sourceRecordId: source.recordId,
      sourceRevision: source.revision,
      targetRecordId: targetRecordId,
      targetKeyEpoch: 8,
      ciphertext: Uint8List.fromList(<int>[9, 8, 7, recordRewrapCount]),
    );
  }

  @override
  Future<E2eeDataRekeyRewrappedAttachmentManifest> rewrapAttachmentManifest(
    CloudSyncDataRekeySourceAttachment source,
  ) => throw StateError('记录重放测试不得重包附件');

  @override
  Future<Uint8List> signCompletionProof(Uint8List proofFrame) async {
    return Uint8List(e2eeDataRekeyCompletionSignatureBytes)
      ..fillRange(0, e2eeDataRekeyCompletionSignatureBytes, 0x6a);
  }
}

final class _RecordResponseLossDataRekeyTransport
    implements CloudSyncDataRekeyTransport {
  _RecordResponseLossDataRekeyTransport({
    required this.userId,
    required this.issuerDeviceId,
    required this.operationId,
    required this.sourceRecordId,
  });

  final String userId;
  final String issuerDeviceId;
  final String operationId;
  final String sourceRecordId;
  final List<CloudSyncDataRekeyRecordStageRequest> stageRequests =
      <CloudSyncDataRekeyRecordStageRequest>[];
  bool _leaseClaimed = false;
  bool _leaseOwned = true;
  int _leaseVersion = 1;

  void simulateLeaseTakeover() {
    _leaseClaimed = true;
    _leaseOwned = false;
    _leaseVersion = 2;
  }

  @override
  Future<CloudSyncDataRekeyState> getDataRekeyState() async {
    return CloudSyncDataRekeyState.fromJson(<String, Object?>{
      'phase': 'rekey-pending',
      'dataGeneration': 4,
      'dataKeyEpoch': 7,
      'changeWatermark': 9,
      'operationId': operationId,
      'targetKeyEpoch': 8,
      'sourceRecordCount': 1,
      'sourceAttachmentCount': 0,
      'sourceMaximumChangeSeq': 9,
      'sourceRecordCursorEnd': sourceRecordId,
      'sourceAttachmentCursorEnd': null,
      'lease': _leaseClaimed
          ? <String, Object?>{
              'leaseVersion': _leaseVersion,
              'ownedByCurrentDevice': _leaseOwned,
              'expiresAt': _leaseVersion == 1
                  ? '2026-07-30T05:10:00.000Z'
                  : '2026-07-30T05:15:00.000Z',
            }
          : null,
      'lastCompletion': null,
      'updatedAt': '2026-07-30T05:00:00.000Z',
    });
  }

  @override
  Future<CloudSyncDataRekeyLeaseClaim> claimDataRekeyLease(
    CloudSyncDataRekeyLeaseClaimRequest request,
  ) async {
    _leaseClaimed = true;
    if (!_leaseOwned) {
      _leaseOwned = true;
      _leaseVersion += 1;
    }
    return CloudSyncDataRekeyLeaseClaim.fromJson(<String, Object?>{
      'phase': 'rekey-pending',
      'operationId': operationId,
      'sourceDataGeneration': 4,
      'sourceKeyEpoch': 7,
      'targetKeyEpoch': 8,
      'leaseVersion': _leaseVersion,
      'leaseExpiresAt': _leaseVersion == 1
          ? '2026-07-30T05:10:00.000Z'
          : '2026-07-30T05:20:00.000Z',
      'sourceRecordCount': 1,
      'sourceAttachmentCount': 0,
      'sourceMaximumChangeSeq': 9,
      'sourceRecordCursorEnd': sourceRecordId,
      'sourceAttachmentCursorEnd': null,
    }, request: request);
  }

  @override
  Future<CloudSyncDataRekeySourceRecordPage> listDataRekeySourceRecords(
    CloudSyncDataRekeySourceRecordListRequest request,
  ) async {
    final ciphertext = Uint8List.fromList(<int>[1, 2, 3]);
    return CloudSyncDataRekeySourceRecordPage.fromJson(<String, Object?>{
      'records': <Object?>[
        <String, Object?>{
          'recordId': sourceRecordId,
          'revision': 3,
          'envelopeVersion': 1,
          'keyEpoch': 7,
          'ciphertext': _dataRekeyBinary(ciphertext),
          'ciphertextBytes': ciphertext.length,
          'updatedAt': '2026-07-30T04:59:00.000Z',
          'updatedByDeviceId': issuerDeviceId,
          'lastChangeSeq': 9,
          'kind': 'put',
          'ciphertextDigest': _dataRekeyBinary(
            Uint8List.fromList(sha256.convert(ciphertext).bytes),
          ),
        },
      ],
      'nextAfterRecordId': null,
      'hasMore': false,
    }, request: request);
  }

  @override
  Future<CloudSyncDataRekeySourceAttachmentPage> listDataRekeySourceAttachments(
    CloudSyncDataRekeySourceAttachmentListRequest request,
  ) async {
    return CloudSyncDataRekeySourceAttachmentPage.fromJson(<String, Object?>{
      'attachments': <Object?>[],
      'nextAfterAttachmentId': null,
      'nextAfterUploadId': null,
      'hasMore': false,
    }, request: request);
  }

  @override
  Future<CloudSyncDataRekeyRecordStageResult> stageDataRekeyRecord(
    CloudSyncDataRekeyRecordStageRequest request,
  ) async {
    stageRequests.add(request);
    if (stageRequests.length == 1) {
      throw StateError('simulated_stage_response_loss');
    }
    return CloudSyncDataRekeyRecordStageResult.fromJson(<String, Object?>{
      'result': 'staged',
      'operationId': operationId,
      'mutationId': request.mutationId,
      'sourceRecordId': request.sourceRecordId,
      'targetRecordId': request.targetRecordId,
      'leaseVersion': request.activeLease.leaseVersion,
    }, request: request);
  }

  @override
  Future<CloudSyncDataRekeyAttachmentStageResult> stageDataRekeyAttachment(
    CloudSyncDataRekeyAttachmentStageRequest request,
  ) => throw StateError('记录重放测试不得暂存附件');

  @override
  Future<CloudSyncDataRekeyFinalizeOutcome> finalizeDataRekey(
    CloudSyncDataRekeyFinalizeRequest request,
  ) async {
    return _finalizedDataRekeyOutcome(userId: userId, request: request);
  }
}

final class _AttachmentDataRekeyCryptography
    implements E2eeDataRekeyCryptography {
  @override
  final String issuerDeviceId = _syncActorDeviceId;

  @override
  final int targetKeyEpoch = 8;

  int attachmentRewrapCount = 0;
  int? sourceChunkKeyEpoch;
  List<List<int>> sourceChunkDigests = const <List<int>>[];

  @override
  Future<E2eeDataRekeyRewrappedRecord> rewrapRecord(
    CloudSyncDataRekeySourceRecord source,
  ) => throw StateError('附件换代测试不得重包记录');

  @override
  Future<E2eeDataRekeyRewrappedAttachmentManifest> rewrapAttachmentManifest(
    CloudSyncDataRekeySourceAttachment source,
  ) async {
    attachmentRewrapCount += 1;
    sourceChunkKeyEpoch = source.chunkKeyEpoch;
    sourceChunkDigests = <List<int>>[
      for (final chunk in source.chunks)
        List<int>.unmodifiable(chunk.ciphertextDigest),
    ];
    return E2eeDataRekeyRewrappedAttachmentManifest(
      attachmentId: source.attachmentId,
      uploadId: source.uploadId,
      chunkKeyEpoch: source.chunkKeyEpoch,
      manifestKeyEpoch: 8,
      manifestRevision: source.manifestRevision + 1,
      manifestCiphertext: Uint8List.fromList(<int>[8, 7, 6, 5]),
    );
  }

  @override
  Future<Uint8List> signCompletionProof(Uint8List proofFrame) async {
    return Uint8List(e2eeDataRekeyCompletionSignatureBytes)
      ..fillRange(0, e2eeDataRekeyCompletionSignatureBytes, 0x7a);
  }
}

final class _AttachmentDataRekeyTransport
    implements CloudSyncDataRekeyTransport {
  _AttachmentDataRekeyTransport({
    required this.userId,
    required this.issuerDeviceId,
    required this.operationId,
    required this.attachmentId,
    required this.uploadId,
  });

  final String userId;
  final String issuerDeviceId;
  final String operationId;
  final String attachmentId;
  final String uploadId;
  final List<CloudSyncDataRekeyAttachmentStageRequest> stageRequests =
      <CloudSyncDataRekeyAttachmentStageRequest>[];
  bool _leaseClaimed = false;

  @override
  Future<CloudSyncDataRekeyState> getDataRekeyState() async {
    return CloudSyncDataRekeyState.fromJson(<String, Object?>{
      'phase': 'rekey-pending',
      'dataGeneration': 4,
      'dataKeyEpoch': 7,
      'changeWatermark': 0,
      'operationId': operationId,
      'targetKeyEpoch': 8,
      'sourceRecordCount': 0,
      'sourceAttachmentCount': 1,
      'sourceMaximumChangeSeq': 0,
      'sourceRecordCursorEnd': null,
      'sourceAttachmentCursorEnd': <String, Object?>{
        'attachmentId': attachmentId,
        'uploadId': uploadId,
      },
      'lease': _leaseClaimed
          ? <String, Object?>{
              'leaseVersion': 1,
              'ownedByCurrentDevice': true,
              'expiresAt': '2026-07-30T05:10:00.000Z',
            }
          : null,
      'lastCompletion': null,
      'updatedAt': '2026-07-30T05:00:00.000Z',
    });
  }

  @override
  Future<CloudSyncDataRekeyLeaseClaim> claimDataRekeyLease(
    CloudSyncDataRekeyLeaseClaimRequest request,
  ) async {
    _leaseClaimed = true;
    return CloudSyncDataRekeyLeaseClaim.fromJson(<String, Object?>{
      'phase': 'rekey-pending',
      'operationId': operationId,
      'sourceDataGeneration': 4,
      'sourceKeyEpoch': 7,
      'targetKeyEpoch': 8,
      'leaseVersion': 1,
      'leaseExpiresAt': '2026-07-30T05:10:00.000Z',
      'sourceRecordCount': 0,
      'sourceAttachmentCount': 1,
      'sourceMaximumChangeSeq': 0,
      'sourceRecordCursorEnd': null,
      'sourceAttachmentCursorEnd': <String, Object?>{
        'attachmentId': attachmentId,
        'uploadId': uploadId,
      },
    }, request: request);
  }

  @override
  Future<CloudSyncDataRekeySourceRecordPage> listDataRekeySourceRecords(
    CloudSyncDataRekeySourceRecordListRequest request,
  ) async {
    return CloudSyncDataRekeySourceRecordPage.fromJson(<String, Object?>{
      'records': <Object?>[],
      'nextAfterRecordId': null,
      'hasMore': false,
    }, request: request);
  }

  @override
  Future<CloudSyncDataRekeySourceAttachmentPage> listDataRekeySourceAttachments(
    CloudSyncDataRekeySourceAttachmentListRequest request,
  ) async {
    final manifestCiphertext = Uint8List.fromList(<int>[1, 3, 5, 7]);
    return CloudSyncDataRekeySourceAttachmentPage.fromJson(<String, Object?>{
      'attachments': <Object?>[
        <String, Object?>{
          'attachmentId': attachmentId,
          'uploadId': uploadId,
          'chunkKeyEpoch': 6,
          'manifestKeyEpoch': 7,
          'manifestRevision': 2,
          'chunkCount': 2,
          'totalCiphertextBytes': 11,
          'manifestCiphertext': _dataRekeyBinary(manifestCiphertext),
          'manifestCiphertextBytes': manifestCiphertext.length,
          'manifestCiphertextDigest': _dataRekeyBinary(
            Uint8List.fromList(sha256.convert(manifestCiphertext).bytes),
          ),
          'chunks': <Object?>[
            <String, Object?>{
              'chunkIndex': 0,
              'ciphertextBytes': 5,
              'ciphertextDigest': _dataRekeyBinary(_syncDigest(41)),
            },
            <String, Object?>{
              'chunkIndex': 1,
              'ciphertextBytes': 6,
              'ciphertextDigest': _dataRekeyBinary(_syncDigest(42)),
            },
          ],
          'committedAt': '2026-07-30T04:59:00.000Z',
        },
      ],
      'nextAfterAttachmentId': null,
      'nextAfterUploadId': null,
      'hasMore': false,
    }, request: request);
  }

  @override
  Future<CloudSyncDataRekeyRecordStageResult> stageDataRekeyRecord(
    CloudSyncDataRekeyRecordStageRequest request,
  ) => throw StateError('附件换代测试不得暂存记录');

  @override
  Future<CloudSyncDataRekeyAttachmentStageResult> stageDataRekeyAttachment(
    CloudSyncDataRekeyAttachmentStageRequest request,
  ) async {
    stageRequests.add(request);
    return CloudSyncDataRekeyAttachmentStageResult.fromJson(<String, Object?>{
      'result': 'staged',
      'operationId': operationId,
      'mutationId': request.mutationId,
      'attachmentId': request.attachmentId,
      'uploadId': request.uploadId,
      'manifestRevision': request.manifestRevision,
      'leaseVersion': request.activeLease.leaseVersion,
    }, request: request);
  }

  @override
  Future<CloudSyncDataRekeyFinalizeOutcome> finalizeDataRekey(
    CloudSyncDataRekeyFinalizeRequest request,
  ) async {
    return _finalizedDataRekeyOutcome(userId: userId, request: request);
  }
}

final class _FakeAccountKeyTransitionRemote
    implements E2eeAccountKeyTransitionRemoteCommit {
  _FakeAccountKeyTransitionRemote(
    this.binding, {
    this.failFirstComplete = true,
  });

  final E2eeAccountKeyTransitionBinding binding;
  final bool failFirstComplete;
  int commitCalls = 0;
  int completeCalls = 0;

  @override
  Future<E2eeAccountKeyTransitionRemoteReceipt> commit() async {
    commitCalls += 1;
    final receipt = E2eeAccountKeyTransitionRemoteReceipt(
      kind: binding.kind,
      userId: binding.userId,
      issuerDeviceId: binding.issuerDeviceId,
      membershipOperationId: binding.membershipOperationId,
      rekeyOperationId: binding.rekeyOperationId,
      securityGeneration: binding.securityGeneration,
      targetKeyEpoch: binding.targetKeyEpoch,
      membershipManifestDigest: binding.membershipManifestDigest,
    );
    receipt.membershipManifestDigest[0] ^= 0xff;
    return receipt;
  }

  @override
  Future<void> complete(E2eeAccountKeyTransitionRemoteReceipt receipt) async {
    completeCalls += 1;
    if (failFirstComplete && completeCalls == 1) {
      throw StateError('simulated_checkpoint_cleanup_loss');
    }
  }
}

final class _FakeAccountKeyTransitionLocalCommitter
    implements E2eeAccountKeyTransitionLocalCommitter {
  int commitCalls = 0;
  int requireCommittedCalls = 0;
  bool _committed = false;

  @override
  Future<void> commit({
    required E2eeAccountKeyTransitionBinding binding,
    required E2eeDataRekeyReadyConfirmation confirmation,
  }) async {
    commitCalls += 1;
    expect(confirmation.execution.operationId, binding.rekeyOperationId);
    _committed = true;
  }

  @override
  Future<void> requireCommitted({
    required E2eeAccountKeyTransitionBinding binding,
  }) async {
    requireCommittedCalls += 1;
    if (!_committed) throw StateError('local_transition_not_committed');
  }
}

final class _CapturingAccountKeyTransitionLocalCommitter
    implements E2eeAccountKeyTransitionLocalCommitter {
  E2eeDataRekeyReadyConfirmation? confirmation;

  @override
  Future<void> commit({
    required E2eeAccountKeyTransitionBinding binding,
    required E2eeDataRekeyReadyConfirmation confirmation,
  }) async {
    this.confirmation = confirmation;
  }

  @override
  Future<void> requireCommitted({
    required E2eeAccountKeyTransitionBinding binding,
  }) async {
    throw StateError('捕获 ready 确认测试不得进入恢复提交分支');
  }
}

CloudSyncDataRekeyFinalizeOutcome _finalizedDataRekeyOutcome({
  required String userId,
  required CloudSyncDataRekeyFinalizeRequest request,
}) {
  final operation = request.activeLease.operation;
  final proof = request.proof;
  return CloudSyncDataRekeyFinalizeOutcome.fromJson(<String, Object?>{
    'result': 'finalized',
    'dataGeneration': request.targetDataGeneration,
    'dataKeyEpoch': operation.targetKeyEpoch,
    'changeWatermark': proof.sourceMaximumChangeSeq,
    'completion': _dataRekeyCompletionJson(userId: userId, request: request),
  }, request: request);
}

Map<String, Object?> _dataRekeyCompletionJson({
  required String userId,
  required CloudSyncDataRekeyFinalizeRequest request,
}) {
  final operation = request.activeLease.operation;
  final proof = request.proof;
  final attachmentCursor = proof.sourceAttachmentCursorEnd;
  final proofFrame = _dataRekeyProofFrame(userId: userId, request: request);
  final proofDigest = digestE2eeDataRekeyCompletionProof(
    proofFrame: proofFrame,
    signature: proof.signature,
  );
  return <String, Object?>{
    'proofVersion': 2,
    'operationId': operation.operationId,
    'issuerDeviceId': proof.issuerDeviceId,
    'sourceDataGeneration': operation.sourceDataGeneration,
    'targetDataGeneration': request.targetDataGeneration,
    'sourceKeyEpoch': operation.sourceKeyEpoch,
    'targetKeyEpoch': operation.targetKeyEpoch,
    'sourceSnapshotRoot': _dataRekeyBinary(proof.sourceSnapshotRoot),
    'sourceRecordCount': proof.sourceRecordCount,
    'sourceAttachmentCount': proof.sourceAttachmentCount,
    'sourceMaximumChangeSeq': proof.sourceMaximumChangeSeq,
    'sourceRecordCursorEnd': proof.sourceRecordCursorEnd,
    'sourceAttachmentCursorEnd': attachmentCursor == null
        ? null
        : <String, Object?>{
            'attachmentId': attachmentCursor.attachmentId,
            'uploadId': attachmentCursor.uploadId,
          },
    'membershipGeneration': proof.membershipGeneration,
    'membershipManifestDigest': _dataRekeyBinary(
      proof.membershipManifestDigest,
    ),
    'stagedRecordCount': proof.stagedRecordCount,
    'stagedAttachmentCount': proof.stagedAttachmentCount,
    'stagedCiphertextSetDigest': _dataRekeyBinary(
      proof.stagedCiphertextSetDigest,
    ),
    'proofFrame': _dataRekeyBinary(proofFrame),
    'proofDigest': _dataRekeyBinary(proofDigest),
    'signature': _dataRekeyBinary(proof.signature),
    'finalizedAt': '2026-07-30T05:01:00.000Z',
  };
}

Uint8List _dataRekeyProofFrame({
  required String userId,
  required CloudSyncDataRekeyFinalizeRequest request,
}) {
  final operation = request.activeLease.operation;
  final proof = request.proof;
  final attachmentCursor = proof.sourceAttachmentCursorEnd;
  return buildE2eeDataRekeyCompletionFrame(
    E2eeDataRekeyCompletionFields(
      operationId: operation.operationId,
      userId: userId,
      issuerDeviceId: proof.issuerDeviceId,
      sourceDataGeneration: operation.sourceDataGeneration,
      targetDataGeneration: request.targetDataGeneration,
      sourceKeyEpoch: operation.sourceKeyEpoch,
      targetKeyEpoch: operation.targetKeyEpoch,
      sourceSnapshotRoot: proof.sourceSnapshotRoot,
      sourceRecordCount: proof.sourceRecordCount,
      sourceAttachmentCount: proof.sourceAttachmentCount,
      sourceMaximumChangeSeq: proof.sourceMaximumChangeSeq,
      sourceRecordCursorEnd: proof.sourceRecordCursorEnd,
      sourceAttachmentCursorEnd: attachmentCursor == null
          ? null
          : E2eeDataRekeyAttachmentCursor(
              attachmentId: attachmentCursor.attachmentId,
              uploadId: attachmentCursor.uploadId,
            ),
      membershipGeneration: proof.membershipGeneration,
      membershipManifestDigest: proof.membershipManifestDigest,
      stagedRecordCount: proof.stagedRecordCount,
      stagedAttachmentCount: proof.stagedAttachmentCount,
      stagedCiphertextSetDigest: proof.stagedCiphertextSetDigest,
    ),
  );
}

String _dataRekeyBinary(Uint8List value) =>
    base64Url.encode(value).replaceAll('=', '');

const _frozenInitializedManifestV2 =
    'S0VMSVZPTU0AAAACcAAAAAAAQACAAAAAAAAAAQAAAAEAAAABAAAAAAAAAAAAAAAAAAAAAAAA'
    'AAAAAAAAAAAAAAAAAADGukVpqxpKKb7327NSIZoQDnypuTvOcwZRu6WPOJ7N9AAAAAHdcNiz'
    'mGV7lSarTk0dOJ3AcGcuNv_hdOgcSyttHlb1YQAAAAHZsfPixtUoZopz8iV1xE7Z-Y2caElk'
    'dhtiFBfv2A16YAAAAAFQAAAAAABAAIAAAAAAAAABgAAAAAAAQACAAAAAAAAAAYAAAAAAAEAA'
    'gAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGAAAAAAABAAIAA'
    'AAAAAAABAAAAAQAAAABkCWCQOAtJwkHe2y6WyXI2zvEKUkuD0VIaOlQNR-P5sNO8ZAdbShbi'
    'NX4vOAUtEjBjPRRAAdoofmUKAhY9FngVAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABRchNtfNvxE9RFzJGH3Dy8lFu43'
    '7rKxS8XQYcWPoBGwP8dWlf80C2rKqN4xiL-cqN7s-twIEpPX1zb7GD0ulw8=';

const _frozenPairedManifestV2 =
    'S0VMSVZPTU0AAAACcAAAAAAAQACAAAAAAAAAAQAAAAIAAAAB05HPAtPXROeSH0q-hR9L3XRc'
    '1aQPMF8n05DghrDFUi_GukVpqxpKKb7327NSIZoQDnypuTvOcwZRu6WPOJ7N9AAAAAHdcNiz'
    'mGV7lSarTk0dOJ3AcGcuNv_hdOgcSyttHlb1YQAAAAHZsfPixtUoZopz8iV1xE7Z-Y2caElk'
    'dhtiFBfv2A16YAAAAAKQAAAAAABAAIAAAAAAAAECgAAAAAAAQACAAAAAAAAAAZAAAAAAAEAA'
    'gAAAAAAAAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKAAAAAAABAAIAA'
    'AAAAAAABAAAAAQAAAABkCWCQOAtJwkHe2y6WyXI2zvEKUkuD0VIaOlQNR-P5sNO8ZAdbShbi'
    'NX4vOAUtEjBjPRRAAdoofmUKAhY9FngVkAAAAAAAQACAAAAAAAABAQAAAAEAAAABJN6Lhjzf'
    '3JAmNndeTSZas-gkRy_PHT13A3F21JfYcNVx_bKKmvgFLu2jtfVT3SDGmmtPr7kPaIRNDlpg'
    'aJPONAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
    'AAAAAAAAAAAAAAAAAAA8Jp5SY8OMWGQlUuX8P9uByzKZkfZ_BAABAgIMEDbGkcdpkkL8jKHr'
    'xWfXXMudiusorxqxnFcq6U1RutmjiskC';

const _frozenRevokedManifestV2 =
    'S0VMSVZPTU0AAAACcAAAAAAAQACAAAAAAAAAAQAAAAMAAAACYK_d1CAY4CnUQukssxT6jZCY'
    '6sSDyZ3cq3TZTszE0iFBKYAXQdhCsoXJ8NK_2xAp7hO3Mi2BBjbO49mscH2EeAAAAAHdcNiz'
    'mGV7lSarTk0dOJ3AcGcuNv_hdOgcSyttHlb1YQAAAAKMvCPqXupQkBoOv3kpgEJqpju6Xq63'
    '7q5HKomKPuN09wAAAAOQAAAAAABAAIAAAAAAAAEFgAAAAAAAQACAAAAAAAAAAZAAAAAAAEAA'
    'gAAAAAAAAQFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUQAAAAGAAAAAAABAAIAA'
    'AAAAAAABAAAAAQAAAABkCWCQOAtJwkHe2y6WyXI2zvEKUkuD0VIaOlQNR-P5sNO8ZAdbShbi'
    'NX4vOAUtEjBjPRRAAdoofmUKAhY9FngV6P5mgbJusLnAH-4iYHZSzcQe6fAYc27aYm3gdQyO'
    'XW-MZsfXqL_HQUOPsKEDlj9n8Sh-LOeGddlc2ay7O0ZPDFM00n9-1kLDBZlw-zHyUowk3dAR'
    'CRnOU8K_klM_Yun_pvWdp3F8RVinPhTH78kF8P2g3psJGoQ72_k5O-xjkQc=';

const _frozenResumedManifestV2 =
    'S0VMSVZPTU0AAAACcAAAAAAAQACAAAAAAAAAAQAAAAQAAAACG7pb1XYcWVtnnG1lZzHl5Uiv'
    'RPBpekjvxp6qUamvEqpBKYAXQdhCsoXJ8NK_2xAp7hO3Mi2BBjbO49mscH2EeAAAAAHdcNiz'
    'mGV7lSarTk0dOJ3AcGcuNv_hdOgcSyttHlb1YQAAAAKMvCPqXupQkBoOv3kpgEJqpju6Xq63'
    '7q5HKomKPuN09wAAAASQAAAAAABAAIAAAAAAAAEHkAAAAAAAQACAAAAAAAABBpAAAAAAAEAA'
    'gAAAAAAAAQYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKAAAAAAABAAIAA'
    'AAAAAAABAAAAAQAAAABkCWCQOAtJwkHe2y6WyXI2zvEKUkuD0VIaOlQNR-P5sNO8ZAdbShbi'
    'NX4vOAUtEjBjPRRAAdoofmUKAhY9FngVkAAAAAAAQACAAAAAAAABBgAAAAEAAAABgdIlodNd'
    'qTKZrV-1klAXdgXZkX--B30hzXsjLBMkKk3Gd8znvWfqfRtKVxTbElc6PyPTRh1foRX3Y6VY'
    '1-kwewAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
    'AAAAAAAAAAAAAAAAAAAywzUx0Vy0qXRMsNYCBwMvpfduygnmZfR1iAkPMTsIb411KqH0Ru3Y'
    'B-l8QbUc1WZQyMIyPI5kDIPimcijKCEL';

const _frozenReplacedManifestV2 =
    'S0VMSVZPTU0AAAACcAAAAAAAQACAAAAAAAAAAQAAAAUAAAADKUa5iTtfhjRhHm6HgnOqLdKr'
    'cMUeq2D9Y90RygxrnKqiI_8VH8y31X2yfFQY-X5kcA9Rn_BnnARxRCt-qLc9MAAAAAHdcNiz'
    'mGV7lSarTk0dOJ3AcGcuNv_hdOgcSyttHlb1YQAAAAMj5alo_Jncfvde8oXxu6mtnu0hJJ-h'
    'JJVGKZMV_7x4iQAAAAWQAAAAAABAAIAAAAAAAAEIkAAAAAAAQACAAAAAAAABBpAAAAAAAEAA'
    'gAAAAAAAAQYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGQAAAAAABAAIAA'
    'AAAAAAEGAAAAAQAAAAGB0iWh012pMpmtX7WSUBd2BdmRf74HfSHNeyMsEyQqTcZ3zOe9Z-p9'
    'G0pXFNsSVzo_I9NGHV-hFfdjpVjX6TB7T6V_HIXj7StNhx5Ry0MvFZzvHdtsw5wKWp-vUl2q'
    '2aSCe9hG1AZ9ex_vHEjKhnNDgSb9YEDUdgzAwV6u3W9lAoWRoPC9qV8tBZ47iKrMKN2MwLWS'
    'oFE9h4oTfa-zpZrOrqpq5CjsjXW4k_cT7zl40-J66eRal6O_lt4TvKd61wQ=';
