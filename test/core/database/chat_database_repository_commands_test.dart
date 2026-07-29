import 'dart:io';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/sync/sync_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'test_database_cipher.dart';

void main() {
  late Directory directory;
  late File databaseFile;
  late ChatDatabaseRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kelivo_commands_test_');
    databaseFile = File('${directory.path}/chat.sqlite');
    repository = ChatDatabaseRepository.open(
      file: databaseFile,
      cipher: testDatabaseCipher,
    );
    await repository.ensureReady();
  });

  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });

  Conversation conversation({
    String id = 'conversation-1',
    List<String> suggestions = const ['suggestion'],
  }) {
    return Conversation(
      id: id,
      title: 'Conversation',
      chatSuggestions: suggestions,
    );
  }

  ChatMessage message({
    required String id,
    String conversationId = 'conversation-1',
    String role = 'assistant',
    String? groupId,
    int version = 0,
    bool isStreaming = false,
    String? content,
    Iterable<ChatMessageAttachment> attachments = const [],
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? id,
      attachments: attachments,
      conversationId: conversationId,
      groupId: groupId ?? id,
      version: version,
      isStreaming: isStreaming,
    );
  }

  ChatMessageAttachment attachment(
    int index, {
    String? assetId,
    String? contentHash,
    bool withRemoteIdentity = false,
    int chunkKeyEpoch = 1,
  }) {
    final kind = index.isEven ? 'image' : 'file';
    final suffix = (index + 1).toString().padLeft(12, '0');
    return ChatMessageAttachment(
      assetId: assetId ?? 'asset-$index',
      path: 'D:\\workspace\\assets\\asset-$index.bin',
      contentHash: contentHash ?? index.toRadixString(16).padLeft(64, '0'),
      byteSize: index + 1,
      kind: kind,
      displayName: kind == 'file' ? 'asset-$index.bin' : null,
      mediaType: kind == 'file' ? 'application/octet-stream' : null,
      attachmentId: withRemoteIdentity
          ? 'a0000000-0000-4000-8000-$suffix'
          : null,
      uploadId: withRemoteIdentity ? 'b0000000-0000-4000-8000-$suffix' : null,
      chunkKeyEpoch: withRemoteIdentity ? chunkKeyEpoch : null,
      manifestKeyEpoch: withRemoteIdentity ? chunkKeyEpoch : null,
      manifestRevision: withRemoteIdentity ? 1 : null,
    );
  }

  ChatMessageAttachment withoutRemoteIdentity(ChatMessageAttachment source) {
    return ChatMessageAttachment(
      assetId: source.assetId,
      path: source.path,
      contentHash: source.contentHash,
      byteSize: source.byteSize,
      kind: source.kind,
      displayName: source.displayName,
      mediaType: source.mediaType,
    );
  }

  test(
    'legacy append persists conversation and selection without active JSON',
    () async {
      final persisted = await repository.appendMessageToConversation(
        conversation: conversation(),
        message: message(
          id: 'message-1',
          groupId: 'group-1',
          version: 1,
          isStreaming: true,
        ),
        selectVersion: true,
      );

      expect(persisted.messageIds, const ['message-1']);
      expect(persisted.versionSelections, const {'group-1': 1});
      expect((await repository.getConversation('conversation-1'))?.messageIds, [
        'message-1',
      ]);
      expect(await repository.getActiveStreamingIds(), isEmpty);
    },
  );

  test(
    'append rolls back the conversation when message validation fails',
    () async {
      await expectLater(
        repository.appendMessageToConversation(
          conversation: conversation(),
          message: message(id: 'message-1', role: ''),
        ),
        throwsA(
          predicate<Object>(
            (error) =>
                error.toString().contains('CHECK constraint failed: role'),
          ),
        ),
      );

      expect(await repository.getConversation('conversation-1'), isNull);
      expect(await repository.getMessage('message-1'), isNull);
      expect(await repository.getActiveStreamingIds(), isEmpty);
    },
  );

  test('结构化附件按 ordinal 原子写入并从资产联表水合', () async {
    final now = DateTime.utc(2026, 7, 29, 12);
    final attachments = List<ChatMessageAttachment>.generate(
      ChatMessage.maximumAttachmentCount,
      (index) => attachment(
        index,
        withRemoteIdentity: index == 0 || index == 31,
        chunkKeyEpoch: index == 31 ? 0xffffffff : 7,
      ),
      growable: false,
    );
    final structured = message(
      id: 'message-assets',
      role: 'user',
      content: 'structured assets',
      attachments: attachments,
    );
    await repository.putConversation(conversation());
    final commands = await repository.acquireE2eeSyncOutboxCommands(now: now);

    await commands.runLocalWriteAtomically<void>(
      intents: <E2eeSyncLocalWriteIntent>[
        E2eeSyncLocalWriteIntent(
          intentId: 'c0000000-0000-4000-8000-000000000001',
          entityKey: const SyncEntityKey(
            entityType: 'message',
            entityId: 'message-assets',
          ),
        ),
      ],
      writerSessionId: 'test-writer',
      now: now,
      write: () => repository.putMessage(structured),
    );

    final persisted = (await repository.getMessage(structured.id))!;
    expect(persisted.attachments, hasLength(32));
    expect(persisted.attachments.first.assetId, 'asset-0');
    expect(persisted.attachments.first.kind, 'image');
    expect(
      persisted.attachments.first.attachmentId,
      'a0000000-0000-4000-8000-000000000001',
    );
    expect(persisted.attachments.first.chunkKeyEpoch, 7);
    expect(persisted.attachments.first.manifestKeyEpoch, 7);
    expect(persisted.attachments.first.manifestRevision, 1);
    expect(persisted.attachments.last.assetId, 'asset-31');
    expect(persisted.attachments.last.kind, 'file');
    expect(persisted.attachments.last.displayName, 'asset-31.bin');
    expect(persisted.attachments.last.mediaType, 'application/octet-stream');
    expect(persisted.attachments.last.chunkKeyEpoch, 0xffffffff);
    expect(persisted.attachments.last.manifestKeyEpoch, 0xffffffff);
    expect(persisted.attachments.last.manifestRevision, 1);
    expect(
      (await repository.getMessagesRange(
        structured.conversationId,
        start: 0,
        limit: 10,
      )).single.attachments,
      hasLength(32),
    );
    expect(
      (await repository.getSelectedContextMessages(
        structured.conversationId,
        truncateIndex: 0,
        limit: 10,
      )).single.attachments.last.assetId,
      'asset-31',
    );

    final database = sqlite.sqlite3.open(databaseFile.path);
    testDatabaseCipher.apply(database, createSlotIfMissing: false);
    addTearDown(database.close);
    final references = database.select(
      'SELECT ordinal, asset_id FROM message_asset_rows '
      'WHERE revision_id = ? ORDER BY ordinal',
      <Object?>[structured.id],
    );
    expect(references, hasLength(32));
    expect(references.first['ordinal'], 0);
    expect(references.first['asset_id'], 'asset-0');
    expect(references.last['ordinal'], 31);
    expect(references.last['asset_id'], 'asset-31');
    expect(
      database.select(
        'SELECT phase FROM e2ee_sync_intent_rows '
        'WHERE entity_type = ? AND entity_id = ?',
        <Object?>['message', structured.id],
      ).single['phase'],
      'dirty',
    );

    final staleLocalAttachments = persisted.attachments
        .map(withoutRemoteIdentity)
        .toList(growable: false);
    await repository.updateMessage(
      persisted.copyWith(
        content: 'updated without stale remote overwrite',
        attachments: staleLocalAttachments,
      ),
    );
    final afterTextUpdate = (await repository.getMessage(structured.id))!;
    expect(afterTextUpdate.attachments.first.attachmentId, isNotNull);
    expect(afterTextUpdate.attachments.last.chunkKeyEpoch, 0xffffffff);

    await repository.updateMessage(afterTextUpdate.copyWith(attachments: []));
    expect((await repository.getMessage(structured.id))!.attachments, isEmpty);
    expect(
      database.select(
        'SELECT ordinal FROM message_asset_rows WHERE revision_id = ?',
        <Object?>[structured.id],
      ),
      isEmpty,
    );
  });

  test('附件写入失败时消息资产引用与 dirty intent 整体回滚', () async {
    final now = DateTime.utc(2026, 7, 29, 13);
    final duplicateHash = List<String>.filled(64, 'd').join();
    final invalid = message(
      id: 'message-assets-invalid',
      role: 'user',
      attachments: <ChatMessageAttachment>[
        attachment(1, assetId: 'asset-invalid-1', contentHash: duplicateHash),
        attachment(3, assetId: 'asset-invalid-2', contentHash: duplicateHash),
      ],
    );
    await repository.putConversation(conversation());
    final commands = await repository.acquireE2eeSyncOutboxCommands(now: now);

    await expectLater(
      commands.runLocalWriteAtomically<void>(
        intents: <E2eeSyncLocalWriteIntent>[
          E2eeSyncLocalWriteIntent(
            intentId: 'c0000000-0000-4000-8000-000000000002',
            entityKey: const SyncEntityKey(
              entityType: 'message',
              entityId: 'message-assets-invalid',
            ),
          ),
        ],
        writerSessionId: 'test-writer',
        now: now,
        write: () => repository.putMessage(invalid),
      ),
      throwsA(
        predicate<Object>(
          (error) =>
              error.toString().contains('UNIQUE constraint failed') &&
              error.toString().contains('asset_rows.content_hash'),
        ),
      ),
    );

    expect(await repository.getMessage(invalid.id), isNull);
    final database = sqlite.sqlite3.open(databaseFile.path);
    testDatabaseCipher.apply(database, createSlotIfMissing: false);
    addTearDown(database.close);
    expect(
      database.select('SELECT id FROM asset_rows WHERE id IN (?, ?)', <Object?>[
        'asset-invalid-1',
        'asset-invalid-2',
      ]),
      isEmpty,
    );
    expect(
      database.select(
        'SELECT ordinal FROM message_asset_rows WHERE revision_id = ?',
        <Object?>[invalid.id],
      ),
      isEmpty,
    );
    expect(
      database.select(
        'SELECT phase FROM e2ee_sync_intent_rows '
        'WHERE entity_type = ? AND entity_id = ?',
        <Object?>['message', invalid.id],
      ),
      isEmpty,
    );
  });

  test('附件 marker 不会隐式生成资产引用', () async {
    await repository.putConversation(conversation());
    final marker = message(
      id: 'message-marker',
      role: 'user',
      content: r'[file:D:\workspace\legacy.txt|legacy.txt|text/plain]',
    );

    await repository.putMessage(marker);

    expect((await repository.getMessage(marker.id))!.attachments, isEmpty);
    final database = sqlite.sqlite3.open(databaseFile.path);
    testDatabaseCipher.apply(database, createSlotIfMissing: false);
    addTearDown(database.close);
    expect(
      database.select(
        'SELECT ordinal FROM message_asset_rows WHERE revision_id = ?',
        <Object?>[marker.id],
      ),
      isEmpty,
    );
    expect(
      database.select(
        'SELECT revision_id FROM asset_reference_dirty_rows '
        'WHERE revision_id = ?',
        <Object?>[marker.id],
      ),
      isEmpty,
    );
  });

  test('损坏的会话与工具 JSON 不会静默退化为空集合', () async {
    await repository.putMigrationBatch(
      conversations: <Conversation>[conversation()],
      messages: <({ChatMessage message, int messageOrder})>[
        (message: message(id: 'message-1'), messageOrder: 0),
      ],
      toolEventsByMessageId: const <String, List<Map<String, dynamic>>>{
        'message-1': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'tool'},
        ],
      },
      geminiSignaturesByMessageId: const <String, String>{},
    );

    final database = sqlite.sqlite3.open(databaseFile.path);
    testDatabaseCipher.apply(database, createSlotIfMissing: false);
    addTearDown(database.close);

    database.execute(
      'UPDATE conversation_rows SET version_selections_json = ? WHERE id = ?',
      <Object?>['{"group-1":1.5}', 'conversation-1'],
    );
    await expectLater(
      repository.getConversation('conversation-1'),
      throwsA(isA<FormatException>()),
    );

    database.execute(
      'UPDATE conversation_rows SET version_selections_json = ?, '
      'chat_suggestions_json = ? WHERE id = ?',
      <Object?>['{}', '[1]', 'conversation-1'],
    );
    await expectLater(
      repository.getConversation('conversation-1'),
      throwsA(isA<FormatException>()),
    );

    database.execute(
      'UPDATE tool_event_rows SET events_json = ? WHERE message_id = ?',
      <Object?>['[1]', 'message-1'],
    );
    await expectLater(
      repository.getToolEvents('message-1'),
      throwsA(isA<FormatException>()),
    );

    await repository.setToolEvents('message-1', const <Map<String, dynamic>>[
      <String, dynamic>{'id': 'tool'},
    ]);
    final messageParts = database.select(
      'SELECT payload FROM message_part_rows '
      'WHERE revision_id = ? AND kind = ?',
      <Object?>['message-1', 'tool_call'],
    );
    expect(messageParts, isNotEmpty);
    for (final payload in <String>['[]', '1', 'null']) {
      database.execute(
        'UPDATE message_part_rows SET payload = ? '
        'WHERE revision_id = ? AND kind = ?',
        <Object?>[payload, 'message-1', 'tool_call'],
      );
      await expectLater(
        repository.getToolEvents('message-1'),
        throwsA(isA<FormatException>()),
        reason: '非法权威工具事件载荷不得静默回退：$payload',
      );
    }
  });

  test(
    'concurrent appends allocate unique order inside transactions',
    () async {
      final base = conversation();
      await Future.wait([
        for (var index = 0; index < 12; index++)
          repository.appendMessageToConversation(
            conversation: base,
            message: message(id: 'message-$index'),
          ),
      ]);

      final ids = await repository.getMessageIds('conversation-1');
      expect(ids, hasLength(12));
      expect(ids.toSet(), hasLength(12));
    },
  );

  test('append version selects the new row in the linear group', () async {
    await repository.appendLinearMessageToConversation(
      conversation: conversation(),
      message: message(id: 'message-0', groupId: 'group-1'),
    );

    final result = await repository.appendMessageVersion(
      messageId: 'message-0',
      content: 'v1',
      attachments: const [],
    );

    expect(result?.message.version, 1);
    final timeline = await repository.loadLinearMessageWindow(
      conversationId: 'conversation-1',
      fromStart: true,
    );
    expect(timeline.slots.single.revisionId, result!.message.id);
    expect(
      (await repository.getConversation('conversation-1'))?.versionSelections,
      const {'group-1': 1},
    );
  });

  test('editing a middle user version preserves the active future', () async {
    final base = conversation();
    for (final item in [
      message(id: 'u1', role: 'user'),
      message(id: 'a1'),
      message(id: 'u2', role: 'user'),
      message(id: 'a2'),
    ]) {
      await repository.appendLinearMessageToConversation(
        conversation: base,
        message: item,
      );
    }

    final result = await repository.appendMessageVersion(
      messageId: 'u2',
      content: 'u2 edited',
      attachments: const [],
    );
    final timeline = await repository.loadLinearMessageWindow(
      conversationId: base.id,
      fromStart: true,
    );

    expect(timeline.slots.map((slot) => slot.revisionId), [
      'u1',
      'a1',
      result!.message.id,
      'a2',
    ]);
    expect(await repository.getMessage('u2'), isNotNull);
    final persisted = await repository.getMessage(result.message.id);
    expect(persisted?.id, result.message.id);
    expect(persisted?.content, 'u2 edited');
  });

  test(
    'concurrent selection and append commands preserve unrelated state',
    () async {
      final base = conversation();
      await repository.appendMessageToConversation(
        conversation: base,
        message: message(id: 'message-0'),
      );

      await Future.wait([
        repository.setSelectedVersion(
          conversationId: 'conversation-1',
          groupId: 'group-1',
          version: 1,
        ),
        repository.setSelectedVersion(
          conversationId: 'conversation-1',
          groupId: 'group-2',
          version: 2,
        ),
        repository.appendMessageToConversation(
          conversation: base,
          message: message(id: 'message-1'),
        ),
      ]);

      expect(
        (await repository.getConversation('conversation-1'))?.versionSelections,
        const {'group-1': 1, 'group-2': 2},
      );
      expect(await repository.getMessageIds('conversation-1'), const [
        'message-0',
        'message-1',
      ]);
    },
  );

  test(
    'fork command rolls back its earlier rows when a later message fails',
    () async {
      await expectLater(
        repository.createConversationWithMessages(
          conversation: conversation(id: 'fork'),
          messages: [
            message(id: 'message-1', conversationId: 'fork'),
            message(id: 'message-2', conversationId: 'fork', role: ''),
          ],
        ),
        throwsA(
          predicate<Object>(
            (error) =>
                error.toString().contains('CHECK constraint failed: role'),
          ),
        ),
      );

      expect(await repository.getConversation('fork'), isNull);
      expect(await repository.getMessage('message-1'), isNull);
    },
  );

  test(
    'batch delete atomically updates selection, order and cascaded artifacts',
    () async {
      final messages = [
        message(id: 'message-v0', groupId: 'group-1'),
        message(id: 'user-1', role: 'user'),
        message(id: 'message-v1', groupId: 'group-1', version: 1),
        message(id: 'user-2', role: 'user'),
      ];
      await repository.putMigrationBatch(
        conversations: [
          conversation().copyWith(
            messageIds: messages.map((message) => message.id).toList(),
            versionSelections: const {'group-1': 1},
          ),
        ],
        messages: [
          for (final (index, message) in messages.indexed)
            (message: message, messageOrder: index),
        ],
        toolEventsByMessageId: const {
          'message-v0': [
            {'id': 'tool'},
          ],
        },
        geminiSignaturesByMessageId: const {'message-v0': 'signature'},
      );

      final result = await repository.deleteMessages(
        conversationId: 'conversation-1',
        messageIds: {'message-v0', 'user-1'},
        versionSelectionChanges: const {'group-1': 0},
      );

      expect(result?.messages.map((message) => message.id), [
        'message-v0',
        'user-1',
      ]);
      expect(await repository.getMessageIds('conversation-1'), [
        'message-v1',
        'user-2',
      ]);
      final persisted = await repository.getConversation('conversation-1');
      expect(persisted?.versionSelections, const {'group-1': 1});
      expect(persisted?.chatSuggestions, isEmpty);
      expect(await repository.getToolEvents('message-v0'), isEmpty);
      expect(await repository.getGeminiThoughtSignature('message-v0'), isNull);
    },
  );

  test(
    'batch delete rejects a partial target set without changing data',
    () async {
      final messages = [
        message(id: 'message-0', groupId: 'group-1'),
        message(id: 'message-1', groupId: 'group-1', version: 1),
      ];
      await repository.putMigrationBatch(
        conversations: [
          conversation().copyWith(
            messageIds: messages.map((message) => message.id).toList(),
            versionSelections: const {'group-1': 1},
          ),
        ],
        messages: [
          for (final (index, message) in messages.indexed)
            (message: message, messageOrder: index),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );

      await expectLater(
        repository.deleteMessages(
          conversationId: 'conversation-1',
          messageIds: {'message-0', 'missing'},
          versionSelectionChanges: const {'group-1': 0},
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'delete_messages_not_found',
          ),
        ),
      );

      expect(await repository.getMessageIds('conversation-1'), const [
        'message-0',
        'message-1',
      ]);
      final persisted = await repository.getConversation('conversation-1');
      expect(persisted?.versionSelections, const {'group-1': 1});
      expect(persisted?.chatSuggestions, const ['suggestion']);
    },
  );

  test(
    'final checkpoint stores content, tools and streaming receipt atomically',
    () async {
      final streaming = message(id: 'message-1', isStreaming: true);
      await repository.appendMessageToConversation(
        conversation: conversation(),
        message: streaming,
      );

      await repository.updateStreamingCheckpoint(
        streaming.copyWith(content: 'final', isStreaming: false),
        const [
          {'id': 'tool', 'content': 'result'},
        ],
      );

      expect((await repository.getMessage('message-1'))?.content, 'final');
      expect(await repository.getToolEvents('message-1'), const [
        {'id': 'tool', 'content': 'result'},
      ]);
      expect(await repository.getActiveStreamingIds(), isEmpty);
    },
  );
}
