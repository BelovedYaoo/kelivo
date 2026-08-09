import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/database_cipher.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';

import 'test_database_cipher.dart';

void main() {
  group('ChatDatabaseRepository snapshot', () {
    late Directory directory;
    late File sourceFile;
    late ChatDatabaseRepository sourceRepository;
    late bool sourceClosed;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'kelivo_repository_snapshot_test_',
      );
      sourceFile = File('${directory.path}/source.sqlite');
      sourceRepository = ChatDatabaseRepository.open(
        file: sourceFile,
        cipher: testDatabaseCipher,
      );
      await sourceRepository.ensureReady();
      sourceClosed = false;
    });

    tearDown(() async {
      if (!sourceClosed) {
        await sourceRepository.close();
      }
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test('backs up a live WAL database into one standalone file', () async {
      await sourceRepository.putMigrationBatch(
        conversations: [
          Conversation(
            id: 'conversation',
            title: 'Snapshot',
            messageIds: const ['message'],
          ),
        ],
        messages: [
          (
            message: ChatMessage(
              id: 'message',
              role: 'assistant',
              content: 'content from live wal',
              conversationId: 'conversation',
            ),
            messageOrder: 0,
          ),
        ],
        toolEventsByMessageId: const {
          'message': [
            {'id': 'event'},
          ],
        },
        geminiSignaturesByMessageId: const {'message': 'signature'},
      );
      await sourceRepository.markMigrationComplete();

      final snapshotFile = File('${directory.path}/snapshot.sqlite');
      final info = await ChatDatabaseRepository.createConsistentSnapshot(
        sourceFile: sourceFile,
        destinationFile: snapshotFile,
        cipher: testDatabaseCipher,
      );

      expect(info.schemaVersion, AppDatabase.currentSchemaVersion);
      expect(info.conversationCount, 1);
      expect(info.messageCount, 1);
      expect(await snapshotFile.exists(), isTrue);
      expect(await File('${snapshotFile.path}-wal').exists(), isFalse);
      expect(await File('${snapshotFile.path}-shm').exists(), isFalse);
      expect(await snapshotFile.openRead(0, 16).first, const <int>[
        0x53,
        0x51,
        0x4c,
        0x69,
        0x74,
        0x65,
        0x20,
        0x66,
        0x6f,
        0x72,
        0x6d,
        0x61,
        0x74,
        0x20,
        0x33,
        0x00,
      ]);

      await sourceRepository.close();
      sourceClosed = true;
      await _deleteDatabaseFamily(sourceFile);

      final snapshotRepository = ChatDatabaseRepository.open(
        file: snapshotFile,
        cipher: testPlaintextDatabaseCipher,
      );
      try {
        await snapshotRepository.ensureReady();
        await snapshotRepository.validateIntegrity();
        expect(
          (await snapshotRepository.getMessagesRange(
            'conversation',
            start: 0,
            limit: 1,
          )).single.content,
          'content from live wal',
        );
        expect(await snapshotRepository.getToolEvents('message'), const [
          {'id': 'event'},
        ]);
        expect(
          await snapshotRepository.getGeminiThoughtSignature('message'),
          'signature',
        );
        expect(await snapshotRepository.isMigrationComplete(), isTrue);
      } finally {
        await snapshotRepository.close();
      }
    });

    test('rejects using the live database as its own destination', () async {
      await expectLater(
        ChatDatabaseRepository.createConsistentSnapshot(
          sourceFile: sourceFile,
          destinationFile: sourceFile,
          cipher: testDatabaseCipher,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(await sourceRepository.isMigrationComplete(), isFalse);
    });

    test(
      'bridges a plaintext schema 12 snapshot into current SQLCipher',
      () async {
        await sourceRepository.close();
        sourceClosed = true;
        final snapshotFile = File('${directory.path}/legacy-v12.sqlite');
        final attachmentFile = File('${directory.path}/legacy-image.png');
        await attachmentFile.writeAsBytes(const <int>[1, 2, 3, 4], flush: true);
        await _createSnapshotFixture(
          databaseFile: snapshotFile,
          conversationId: 'legacy-v12',
          title: 'Legacy v12',
          messageId: 'legacy-v12-message',
          messageContent: 'legacy v12 content',
          cipher: testPlaintextDatabaseCipher,
        );
        await _downgradeFixtureToSchema12(
          databaseFile: snapshotFile,
          conversationId: 'legacy-v12',
          messageId: 'legacy-v12-message',
          attachmentFile: attachmentFile,
        );
        await _deleteDatabaseSidecars(snapshotFile);

        final preparation =
            await ChatDatabaseRepository.prepareBackupSnapshotForRestore(
              snapshotFile,
              cipher: testDatabaseCipher,
            );

        expect(preparation.sourceWasPlaintext, isTrue);
        expect(preparation.sourceInfo.schemaVersion, 12);
        expect(
          preparation.preparedInfo.schemaVersion,
          AppDatabase.currentSchemaVersion,
        );
        expect(preparation.preparedInfo.conversationCount, 1);
        expect(preparation.preparedInfo.messageCount, 1);

        final preparedRepository = ChatDatabaseRepository.open(
          file: snapshotFile,
          cipher: testDatabaseCipher,
        );
        try {
          await preparedRepository.ensureReady();
          final message = (await preparedRepository.getMessagesRange(
            'legacy-v12',
            start: 0,
            limit: 1,
          )).single;
          expect(message.content, 'legacy v12 content');
          expect(message.attachments, hasLength(1));
          expect(message.attachments.single.kind, 'image');
          expect(message.attachments.single.path, attachmentFile.path);
          expect(message.attachments.single.hasRemoteIdentity, isFalse);
        } finally {
          await preparedRepository.close();
        }
      },
    );

    test(
      'inspects only normalized standalone snapshots without writing',
      () async {
        final snapshotFile = File('${directory.path}/inspection.sqlite');
        await _createSnapshotFixture(
          databaseFile: snapshotFile,
          conversationId: 'inspection',
          title: 'Inspection',
          messageId: 'streaming-message',
          messageContent: 'partial',
          isStreaming: true,
        );

        await expectLater(
          ChatDatabaseRepository.inspectPreparedSnapshot(
            snapshotFile,
            cipher: testDatabaseCipher,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'database_streaming_messages',
            ),
          ),
        );

        await ChatDatabaseRepository.prepareSnapshotForRestore(
          snapshotFile,
          cipher: testDatabaseCipher,
        );
        final before = (await sha256.bind(snapshotFile.openRead()).first)
            .toString();

        final info = await ChatDatabaseRepository.inspectPreparedSnapshot(
          snapshotFile,
          cipher: testDatabaseCipher,
        );

        final after = (await sha256.bind(snapshotFile.openRead()).first)
            .toString();
        expect(info.conversationCount, 1);
        expect(info.messageCount, 1);
        expect(after, before);
      },
    );

    test('rejects a prepared snapshot with a sidecar', () async {
      final snapshotFile = File('${directory.path}/sidecar.sqlite');
      await _createSnapshotFixture(
        databaseFile: snapshotFile,
        conversationId: 'sidecar',
        title: 'Sidecar',
      );
      await ChatDatabaseRepository.prepareSnapshotForRestore(
        snapshotFile,
        cipher: testDatabaseCipher,
      );
      await File('${snapshotFile.path}-wal').writeAsBytes([1], flush: true);

      await expectLater(
        ChatDatabaseRepository.inspectPreparedSnapshot(
          snapshotFile,
          cipher: testDatabaseCipher,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'database_sidecar:-wal',
          ),
        ),
      );
    });

    test('rejects current schema missing generation run state', () async {
      await sourceRepository.close();
      sourceClosed = true;
      final raw = sqlite.sqlite3.open(sourceFile.path);
      try {
        testDatabaseCipher.apply(raw, createSlotIfMissing: false);
        raw.execute('PRAGMA foreign_keys = OFF;');
        raw.execute('DROP TABLE generation_run_rows;');
      } finally {
        raw.close();
      }

      expect(
        () => ChatDatabaseRepository.inspectInstalledDatabase(
          sourceFile,
          cipher: testDatabaseCipher,
          validateContents: true,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'required_tables',
          ),
        ),
      );
    });
  });
}

Future<void> _createSnapshotFixture({
  required File databaseFile,
  required String conversationId,
  required String title,
  String? messageId,
  String? messageContent,
  bool isStreaming = false,
  DatabaseCipher cipher = testDatabaseCipher,
}) async {
  final databasePath = databaseFile.path;
  await Isolate.run(() async {
    final repository = ChatDatabaseRepository.open(
      file: File(databasePath),
      cipher: cipher,
    );
    try {
      await repository.ensureReady();
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: conversationId,
            title: title,
            messageIds: messageId == null ? const [] : [messageId],
          ),
        ],
        messages: messageId == null
            ? const []
            : [
                (
                  message: ChatMessage(
                    id: messageId,
                    role: 'assistant',
                    content: messageContent ?? '',
                    conversationId: conversationId,
                    isStreaming: isStreaming,
                  ),
                  messageOrder: 0,
                ),
              ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      await repository.checkpoint();
    } finally {
      await repository.close();
    }
  });
}

Future<void> _downgradeFixtureToSchema12({
  required File databaseFile,
  required String conversationId,
  required String messageId,
  required File attachmentFile,
}) async {
  final raw = sqlite.sqlite3.open(databaseFile.path);
  try {
    raw.execute('PRAGMA foreign_keys = OFF;');
    for (final table in const <String>[
      'asset_reference_dirty_rows',
      'asset_gc_quarantine_rows',
      'asset_gc_lease_rows',
      'asset_gc_rows',
      'gc_audit_rows',
      'e2ee_attachment_download_rows',
      'e2ee_attachment_upload_rows',
      'e2ee_config_entry_rows',
      'e2ee_data_rekey_operation_rows',
      'e2ee_verified_membership_anchor_rows',
      'e2ee_sync_pull_checkpoint_rows',
      'e2ee_sync_remote_record_rows',
      'e2ee_sync_outbox_rows',
      'e2ee_sync_operation_rows',
      'e2ee_sync_intent_rows',
      'e2ee_sync_record_head_rows',
      'e2ee_sync_record_parent_rows',
      'e2ee_sync_record_state_rows',
    ]) {
      raw.execute('DROP TABLE $table;');
    }
    raw.execute('DROP TABLE message_asset_rows;');
    raw.execute('''
      CREATE TABLE message_asset_rows(
        conversation_id TEXT NOT NULL,
        revision_id TEXT NOT NULL,
        asset_id TEXT NOT NULL REFERENCES asset_rows(id) ON DELETE CASCADE,
        kind TEXT NOT NULL CHECK(kind <> ''),
        PRIMARY KEY(revision_id, asset_id, kind),
        FOREIGN KEY(revision_id)
          REFERENCES message_rows(id) ON DELETE CASCADE
      );
    ''');
    raw.execute(
      'CREATE INDEX idx_message_assets_asset '
      'ON message_asset_rows(asset_id, revision_id);',
    );
    raw.execute(
      'INSERT INTO asset_rows '
      '(id, content_hash, path, byte_size, width, height, thumbnail_path, '
      'created_at, last_referenced_at) '
      'VALUES (?, ?, ?, ?, NULL, NULL, NULL, 1, 1);',
      [
        'legacy-asset',
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        attachmentFile.path,
        await attachmentFile.length(),
      ],
    );
    raw.execute(
      'INSERT INTO message_asset_rows '
      '(conversation_id, revision_id, asset_id, kind) '
      'VALUES (?, ?, ?, ?);',
      [conversationId, messageId, 'legacy-asset', 'image'],
    );
    raw.userVersion = 12;
  } finally {
    raw.close();
  }
}

Future<void> _deleteDatabaseFamily(File databaseFile) async {
  for (final suffix in const ['', '-wal', '-shm', '-journal']) {
    final file = File('${databaseFile.path}$suffix');
    if (await file.exists()) {
      await file.delete();
    }
  }
}

Future<void> _deleteDatabaseSidecars(File databaseFile) async {
  for (final suffix in const ['-wal', '-shm', '-journal']) {
    final file = File('${databaseFile.path}$suffix');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
