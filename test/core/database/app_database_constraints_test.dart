import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/e2ee_sync_record_ledger.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_record_cipher.dart';
import 'package:Kelivo/core/services/sync/e2ee_account_record_state.dart';
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

String _ledgerOperationId(int value) =>
    '20000000-0000-4000-8000-${value.toString().padLeft(12, '0')}';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory directory;
  late AppDatabase database;
  late E2eeAccountRecordStateCodec stateCodec;
  late E2eeSyncRecordLedger ledger;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'kelivo_database_constraints_',
    );
    database = AppDatabase.open(
      file: File('${directory.path}/constraints.sqlite'),
      cipher: testDatabaseCipher,
    );
    await database.customSelect('SELECT 1;').getSingle();
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
  });

  tearDown(() async {
    await stateCodec.close();
    await database.close();
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
