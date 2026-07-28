import 'dart:async';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/e2ee_sync_record_ledger.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_record_cipher.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_record_state.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_record_types.dart';
import 'package:Kelivo/core/services/sync/e2ee_sync_outbox.dart';
import 'package:Kelivo/core/services/sync/e2ee_sync_payload_codec.dart';
import 'package:Kelivo/core/services/sync/e2ee_sync_pull.dart';
import 'package:Kelivo/core/services/sync/sync_codec.dart';
import 'package:drift/drift.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:flutter_test/flutter_test.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

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

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory directory;
  late AppDatabase database;
  late ChatDatabaseRepository repository;
  late E2eeAccountRecordStateCodec stateCodec;
  late E2eeSyncRecordLedger ledger;
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
        accountRootKey: await secureCore.generateAccountRootKey(),
        userId: _ledgerUserId,
        currentKeyEpoch: 7,
      ),
    );
    ledger = E2eeSyncRecordLedger(database);
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
  }) async {
    final sealed = await stateCodec.sealTombstone(
      entityKey:
          entityKey ??
          SyncEntityKey(
            entityType: 'conversation',
            entityId: 'pull-tombstone-$operation',
          ),
      logicalVersion: 1,
      parentDigests: const [],
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

  E2eeSyncPullCoordinator createPullCoordinator({
    required E2eeSyncAuthenticatedPullTransport transport,
    required E2eeSyncTransactionalBusinessApplier applyPage,
  }) {
    var clockTick = 0;
    return E2eeSyncPullCoordinator(
      pullCommands: pullCommands,
      stateCodec: stateCodec,
      transport: transport,
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
            content: 'content',
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
    final refs = await outboxCommands.beginLocalWrite(
      intents: [
        E2eeSyncLocalWriteIntent(
          intentId: _syncUuid(100 + discriminator),
          entityKey: entityKey,
        ),
      ],
      writerSessionId: 'writer-$discriminator',
      now: now,
    );
    expect(
      await outboxCommands.finishLocalWrite(
        writerSessionId: 'writer-$discriminator',
        now: now.add(const Duration(seconds: 1)),
      ),
      1,
    );
    final lease = await outboxCommands.claimSealIntent(
      intent: refs.single,
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

  group('E2EE sync outbox commands', () {
    test('值快照复制只读输入并持有独立可写缓冲区', () {
      final input = Uint8List.fromList(<int>[1, 2, 3]).asUnmodifiableView();
      final snapshot = E2eeSyncValueSnapshot.copyFrom(input);

      snapshot.payload[0] = 9;

      expect(input, orderedEquals(<int>[1, 2, 3]));
      expect(snapshot.payload, orderedEquals(<int>[9, 2, 3]));
    });

    test('本地写成功或抛错都从 preparing 收口为 dirty', () async {
      final now = DateTime.utc(2026, 7, 28);

      Future<void> runLocalWrite({
        required int discriminator,
        required bool shouldThrow,
      }) async {
        final entityKey = SyncEntityKey(
          entityType: 'conversation',
          entityId: 'local-write-$discriminator',
        );
        final sessionId = 'writer-$discriminator';
        await outboxCommands.beginLocalWrite(
          intents: [
            E2eeSyncLocalWriteIntent(
              intentId: _syncUuid(discriminator),
              entityKey: entityKey,
            ),
          ],
          writerSessionId: sessionId,
          now: now,
        );
        final preparing =
            await (database.select(database.e2eeSyncIntentRows)..where(
                  (row) =>
                      row.entityType.equals(entityKey.entityType) &
                      row.entityId.equals(entityKey.entityId),
                ))
                .getSingle();
        expect(preparing.phase, 'preparing');
        expect(preparing.writerSessionId, sessionId);

        try {
          if (shouldThrow) throw StateError('模拟本地写入失败');
        } finally {
          expect(
            await outboxCommands.finishLocalWrite(
              writerSessionId: sessionId,
              now: now.add(const Duration(seconds: 1)),
            ),
            1,
          );
        }
      }

      await runLocalWrite(discriminator: 301, shouldThrow: false);
      await expectLater(
        runLocalWrite(discriminator: 302, shouldThrow: true),
        throwsStateError,
      );

      final intents = await database.select(database.e2eeSyncIntentRows).get();
      expect(intents, hasLength(2));
      expect(intents.every((row) => row.phase == 'dirty'), isTrue);
      expect(intents.every((row) => row.writerSessionId == null), isTrue);
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
