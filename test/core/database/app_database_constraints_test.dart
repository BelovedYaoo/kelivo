import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import 'test_database_cipher.dart';

Matcher throwsRemoteSqliteException() => throwsA(
  isA<DriftRemoteException>().having(
    (error) => error.remoteCause,
    'remoteCause',
    isA<SqliteException>(),
  ),
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory directory;
  late AppDatabase database;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'kelivo_database_constraints_',
    );
    database = AppDatabase.open(
      file: File('${directory.path}/constraints.sqlite'),
      cipher: testDatabaseCipher,
    );
    await database.customSelect('SELECT 1;').getSingle();
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

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
