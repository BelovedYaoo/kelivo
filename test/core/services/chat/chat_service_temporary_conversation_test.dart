import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_store.dart';
import 'package:Kelivo/core/services/sync/sync_codec.dart';
import 'package:Kelivo/core/services/sync/sync_write_executor.dart';
import 'package:Kelivo/utils/app_directories.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getApplicationCachePath() async => '$path/cache';

  @override
  Future<String?> getTemporaryPath() async => '$path/tmp';
}

final class _RecordingSyncWriteExecutor implements SyncWriteExecutor {
  final List<Set<SyncEntityKey>> batches = <Set<SyncEntityKey>>[];

  @override
  Future<T> runLocal<T>({
    required SyncEntityKey key,
    required Future<T> Function() write,
  }) {
    return runLocalBatch(keys: <SyncEntityKey>{key}, write: write);
  }

  @override
  Future<T> runLocalBatch<T>({
    required Iterable<SyncEntityKey> keys,
    required Future<T> Function() write,
  }) async {
    batches.add(Set<SyncEntityKey>.of(keys));
    return write();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final services = <ChatService>[];

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'kelivo_chat_service_test_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    AppDirectories.bindWorkspaceRoot(
      tempDir,
      installationRoot: tempDir,
      accountWorkspace: false,
    );
    await SandboxPathResolver.init();
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    for (final service in services) {
      await service.close();
    }
    services.clear();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  ChatService createService({
    Future<String> Function(File)? assetContentHash,
    SyncWriteExecutor syncWriteExecutor =
        const UntrackedSyncWriteExecutor.forTests(),
  }) {
    final service = ChatService(
      syncWriteExecutor,
      assetContentHash: assetContentHash,
    );
    services.add(service);
    return service;
  }

  test('cold init clears every stale streaming flag', () async {
    final first = createService();
    await first.init();
    final conversation = await first.createConversation(title: 'Chat');
    await first.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      content: 'partial',
      isStreaming: true,
    );
    await first.close();
    services.remove(first);

    final writeExecutor = _RecordingSyncWriteExecutor();
    final restarted = createService(syncWriteExecutor: writeExecutor);
    await restarted.init();

    final messages = await restarted.loadMessages(conversation.id);
    expect(messages, hasLength(1));
    expect(messages.single.content, 'partial');
    expect(messages.single.isStreaming, isFalse);
    expect(messages.single.generationStatus, 'interrupted');
    expect(writeExecutor.batches, hasLength(1));
    expect(
      writeExecutor.batches.single,
      contains(
        SyncEntityKey(entityType: 'message', entityId: messages.single.id),
      ),
    );
  });

  test('retained timeline cache stays appendable for the next send', () async {
    final service = createService();
    await service.init();
    final conversation = await service.createConversation(title: 'Chat');
    final first = await service.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      content: 'first answer',
    );
    await service.loadMessages(conversation.id);

    service.retainTimelineWindow(conversation.id, [first.id]);
    expect(service.getMessages(conversation.id).map((message) => message.id), [
      first.id,
    ]);

    final result = await service.beginSendGeneration(
      conversationId: conversation.id,
      userContent: 'next question',
      modelId: 'model',
      providerId: 'provider',
    );

    expect(service.getMessages(conversation.id).map((message) => message.id), [
      first.id,
      result.userMessage!.id,
      result.assistantMessage.id,
    ]);
    expect(result.assistantMessage.turnId, result.userMessage!.turnId);
  });

  test('switching conversations evicts an oversized previous cache', () async {
    final service = createService();
    await service.init();
    final first = await service.createConversation(title: 'Large');
    await service.addMessage(
      conversationId: first.id,
      role: 'user',
      content: 'x' * (5 * 1024 * 1024),
    );
    expect(await service.loadMessages(first.id), hasLength(1));

    await service.createConversation(title: 'Next');

    expect(service.getMessages(first.id), isEmpty);
    expect(service.getMessageCount(first.id), 1);
  });

  test(
    'persistent attachment uses delayed reference GC after message delete',
    () async {
      final service = createService();
      await service.init();
      final conversation = await service.createConversation(title: 'Assets');
      final upload = File('${tempDir.path}/upload/spec.pdf');
      await upload.parent.create(recursive: true);
      await upload.writeAsString('attachment payload');
      final message = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: '[file:${upload.path}|spec.pdf|application/pdf]',
      );

      await service.deleteMessage(message.id);

      expect(await upload.exists(), isTrue, reason: 'GC must be delayed');
      await service.runAssetMaintenance(
        now: DateTime.now().toUtc().add(const Duration(days: 8)),
      );
      expect(await upload.exists(), isFalse);
    },
  );

  test('asset maintenance waits for another process lease owner', () async {
    final databaseFile = File(
      '${tempDir.path}/${AppDatabase.databaseFileName}',
    );
    final externalRepository = ChatDatabaseRepository.open(file: databaseFile);
    addTearDown(externalRepository.close);
    final lease = await externalRepository.tryAcquireAssetGcLease(
      ownerToken: 'external-owner',
      now: DateTime.now().toUtc(),
      leaseDuration: const Duration(minutes: 2),
    );
    expect(lease.acquired, isTrue);
    final service = createService();
    await service.init();
    var completed = false;
    final maintenance = service.runAssetMaintenance().whenComplete(() {
      completed = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(completed, isFalse);

    expect(
      await externalRepository.releaseAssetGcLease(
        ownerToken: 'external-owner',
      ),
      isTrue,
    );
    await maintenance.timeout(const Duration(seconds: 2));
  });

  test(
    'attachment registration rejects a managed directory swapped to a junction',
    () async {
      final uploadDirectory = await AppDirectories.getUploadDirectory();
      final outsideDirectory = Directory(
        p.join(tempDir.path, 'outside-upload'),
      );
      await outsideDirectory.create();
      final outsideFile = File(p.join(outsideDirectory.path, 'private.txt'));
      await outsideFile.writeAsString('private payload');
      final managedDirectory = Directory(
        p.join(uploadDirectory.path, 'managed-then-linked'),
      );
      await managedDirectory.create();
      final managedFilePath = p.join(managedDirectory.path, 'private.txt');
      await File(managedFilePath).writeAsString('managed payload');
      var hashAttempts = 0;
      final service = createService(
        assetContentHash: (file) async {
          hashAttempts += 1;
          await managedDirectory.delete(recursive: true);
          await _createDirectoryLink(
            managedDirectory.path,
            outsideDirectory.path,
          );
          return List.filled(64, 'e').join();
        },
      );

      try {
        await service.init();
        final conversation = await service.createConversation(title: 'Assets');
        await service.addMessage(
          conversationId: conversation.id,
          role: 'user',
          content:
              '[file:$managedFilePath'
              '|private.txt|text/plain]',
        );

        expect(hashAttempts, 1);
        final database = sqlite.sqlite3.open(
          '${tempDir.path}/${AppDatabase.databaseFileName}',
        );
        try {
          expect(database.select('SELECT id FROM asset_rows;'), isEmpty);
          expect(
            database.select(
              'SELECT revision_id FROM asset_reference_dirty_rows;',
            ),
            hasLength(1),
          );
        } finally {
          database.close();
        }
      } finally {
        if (await managedDirectory.exists()) {
          await managedDirectory.delete();
        }
      }
    },
  );

  test(
    'cold init backfills attachment references left by an older writer',
    () async {
      final first = createService();
      await first.init();
      final conversation = await first.createConversation(title: 'Assets');
      final upload = File('${tempDir.path}/upload/legacy.txt');
      await upload.parent.create(recursive: true);
      await upload.writeAsString('legacy attachment payload');
      final message = await first.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: '[file:${upload.path}|legacy.txt|text/plain]',
      );
      await first.close();
      services.remove(first);

      final database = sqlite.sqlite3.open(
        '${tempDir.path}/${AppDatabase.databaseFileName}',
      );
      try {
        database.execute('DELETE FROM asset_rows;');
        database.execute(
          "DELETE FROM chat_storage_meta_rows "
          "WHERE key = 'asset_reference_backfill_version';",
        );
      } finally {
        database.close();
      }

      final hashStarted = Completer<void>();
      final hashResult = Completer<String>();
      final restarted = createService(
        assetContentHash: (file) {
          if (!hashStarted.isCompleted) hashStarted.complete();
          return hashResult.future;
        },
      );
      await restarted.init().timeout(const Duration(seconds: 1));
      await hashStarted.future.timeout(const Duration(seconds: 1));
      expect(hashResult.isCompleted, isFalse);

      hashResult.complete(List.filled(64, 'b').join());
      await restarted.runAssetReferenceMaintenance();
      await restarted.deleteMessage(message.id);
      await restarted.runAssetMaintenance(
        now: DateTime.now().toUtc().add(const Duration(days: 8)),
      );

      expect(await upload.exists(), isFalse);
    },
  );

  test(
    'stale backfill cannot replace assets for a newer message edit',
    () async {
      final oldHash = List.filled(64, '6').join();
      final newHash = List.filled(64, '7').join();
      final first = createService(assetContentHash: (_) async => oldHash);
      await first.init();
      final conversation = await first.createConversation(title: 'Assets');
      final oldUpload = File('${tempDir.path}/upload/old.txt');
      final newUpload = File('${tempDir.path}/upload/new.txt');
      await oldUpload.parent.create(recursive: true);
      await oldUpload.writeAsString('old attachment');
      await newUpload.writeAsString('new attachment');
      final message = await first.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: '[file:${oldUpload.path}|old.txt|text/plain]',
      );
      await first.close();
      services.remove(first);

      final database = sqlite.sqlite3.open(
        '${tempDir.path}/${AppDatabase.databaseFileName}',
      );
      try {
        database.execute('DELETE FROM asset_rows;');
        database.execute(
          "DELETE FROM chat_storage_meta_rows "
          "WHERE key = 'asset_reference_backfill_version';",
        );
      } finally {
        database.close();
      }

      final oldHashStarted = Completer<void>();
      final releaseOldHash = Completer<void>();
      final restarted = createService(
        assetContentHash: (file) async {
          if (p.equals(p.normalize(file.path), p.normalize(oldUpload.path))) {
            if (!oldHashStarted.isCompleted) oldHashStarted.complete();
            await releaseOldHash.future;
            return oldHash;
          }
          return newHash;
        },
      );
      await restarted.init();
      await oldHashStarted.future.timeout(const Duration(seconds: 1));

      await restarted.updateMessage(
        message.id,
        content: '[file:${newUpload.path}|new.txt|text/plain]',
      );
      releaseOldHash.complete();
      await restarted.runAssetReferenceMaintenance();

      final verified = sqlite.sqlite3.open(
        '${tempDir.path}/${AppDatabase.databaseFileName}',
      );
      try {
        expect(
          verified
              .select(
                'SELECT asset_id FROM message_asset_rows '
                'WHERE revision_id = ? ORDER BY asset_id;',
                <Object?>[message.id],
              )
              .map((row) => row['asset_id']),
          <Object?>['asset_$newHash'],
        );
        expect(
          verified.select(
            'SELECT revision_id FROM asset_reference_dirty_rows '
            'WHERE revision_id = ?;',
            <Object?>[message.id],
          ),
          isEmpty,
        );
      } finally {
        verified.close();
      }
    },
  );

  test(
    'failed attachment backfill stays retryable and cannot release the asset to GC',
    () async {
      final contentHash = List.filled(64, 'c').join();
      final first = createService(assetContentHash: (_) async => contentHash);
      await first.init();
      final conversation = await first.createConversation(title: 'Assets');
      final upload = File('${tempDir.path}/upload/retry.txt');
      await upload.parent.create(recursive: true);
      await upload.writeAsString('retryable attachment payload');
      final message = await first.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: '[file:${upload.path}|retry.txt|text/plain]',
      );
      await first.close();
      services.remove(first);

      final database = sqlite.sqlite3.open(
        '${tempDir.path}/${AppDatabase.databaseFileName}',
      );
      try {
        database.execute(
          'DELETE FROM message_asset_rows WHERE revision_id = ?;',
          <Object?>[message.id],
        );
        database.execute(
          'DELETE FROM asset_reference_dirty_rows WHERE revision_id = ?;',
          <Object?>[message.id],
        );
        database.execute(
          "DELETE FROM chat_storage_meta_rows "
          "WHERE key = 'asset_reference_backfill_version';",
        );
      } finally {
        database.close();
      }

      final hashStarted = Completer<void>();
      final releaseFailure = Completer<void>();
      var hashAttempts = 0;
      final restarted = createService(
        assetContentHash: (file) async {
          hashAttempts += 1;
          if (hashAttempts == 1) {
            hashStarted.complete();
            await releaseFailure.future;
            throw StateError('simulated_asset_hash_failure');
          }
          return contentHash;
        },
      );
      await restarted.init();
      await hashStarted.future.timeout(const Duration(seconds: 1));
      final failedMaintenance = restarted.runAssetReferenceMaintenance();
      releaseFailure.complete();

      await expectLater(failedMaintenance, throwsStateError);

      final failedDatabase = sqlite.sqlite3.open(
        '${tempDir.path}/${AppDatabase.databaseFileName}',
      );
      try {
        expect(
          failedDatabase.select(
            "SELECT value FROM chat_storage_meta_rows "
            "WHERE key = 'asset_reference_backfill_version';",
          ),
          isEmpty,
        );
        expect(
          failedDatabase.select(
            'SELECT revision_id FROM asset_reference_dirty_rows '
            'WHERE revision_id = ?;',
            <Object?>[message.id],
          ),
          hasLength(1),
        );
      } finally {
        failedDatabase.close();
      }

      await restarted.runAssetMaintenance(
        now: DateTime.now().toUtc().add(const Duration(days: 8)),
      );
      expect(await upload.exists(), isTrue);

      await restarted.runAssetReferenceMaintenance();
      final recoveredDatabase = sqlite.sqlite3.open(
        '${tempDir.path}/${AppDatabase.databaseFileName}',
      );
      try {
        expect(
          recoveredDatabase.select(
            "SELECT value FROM chat_storage_meta_rows "
            "WHERE key = 'asset_reference_backfill_version';",
          ),
          hasLength(1),
        );
        expect(
          recoveredDatabase.select(
            'SELECT revision_id FROM asset_reference_dirty_rows '
            'WHERE revision_id = ?;',
            <Object?>[message.id],
          ),
          isEmpty,
        );
      } finally {
        recoveredDatabase.close();
      }
    },
  );

  test(
    'GC preserves a path that a newer content hash still references',
    () async {
      final oldHash = List.filled(64, '9').join();
      final newHash = List.filled(64, 'a').join();
      final service = createService(
        assetContentHash: (file) async {
          return await file.readAsString() == 'old payload' ? oldHash : newHash;
        },
      );
      await service.init();
      final conversation = await service.createConversation(title: 'Assets');
      final upload = File('${tempDir.path}/upload/reused-path.txt');
      await upload.parent.create(recursive: true);
      await upload.writeAsString('old payload');
      final content = '[file:${upload.path}|reused-path.txt|text/plain]';
      final message = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: content,
      );

      await upload.writeAsString('new payload');
      await service.updateMessage(message.id, content: content);
      final scheduledAt = DateTime.now().toUtc();
      await service.runAssetMaintenance(now: scheduledAt);
      await service.runAssetMaintenance(
        now: scheduledAt.add(const Duration(days: 8)),
      );

      expect(await upload.readAsString(), 'new payload');
      final database = sqlite.sqlite3.open(
        '${tempDir.path}/${AppDatabase.databaseFileName}',
      );
      try {
        expect(
          database.select(
            'SELECT asset_id FROM message_asset_rows '
            'WHERE revision_id = ?;',
            <Object?>[message.id],
          ).single['asset_id'],
          'asset_$newHash',
        );
        expect(
          database.select('SELECT id FROM asset_rows WHERE id = ?;', <Object?>[
            'asset_$oldHash',
          ]),
          hasLength(1),
        );
      } finally {
        database.close();
      }
    },
  );

  test(
    'ordinary attachment whose name resembles a GC marker remains unchanged',
    () async {
      final contentHash = List.filled(64, '8').join();
      final first = createService(assetContentHash: (_) async => contentHash);
      await first.init();
      final conversation = await first.createConversation(title: 'Assets');
      final upload = File(
        '${tempDir.path}/upload/report.kelivo-gc-asset_$contentHash-42',
      );
      await upload.parent.create(recursive: true);
      await upload.writeAsString('ordinary attachment payload');
      await first.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: '[file:${upload.path}|report|text/plain]',
      );
      await first.close();
      services.remove(first);

      final restarted = createService(
        assetContentHash: (_) async => contentHash,
      );
      await restarted.init();
      await restarted.close();
      services.remove(restarted);

      expect(await upload.exists(), isTrue);
      expect(await File('${tempDir.path}/upload/report').exists(), isFalse);
    },
  );

  test('unknown file in the GC quarantine directory is preserved', () async {
    final quarantineDirectory = Directory('${tempDir.path}/upload/.kelivo-gc');
    await quarantineDirectory.create(recursive: true);
    final unknown = File('${quarantineDirectory.path}/unknown-entry');
    await unknown.writeAsString('must not be guessed');
    final service = createService();
    await service.init();

    await expectLater(service.runAssetMaintenance(), throwsStateError);
    expect(await unknown.exists(), isTrue);
  });

  test(
    'cold maintenance clears a pending record when the rename never happened',
    () async {
      final contentHash = List.filled(64, 'b').join();
      final assetId = 'asset_$contentHash';
      final first = createService(assetContentHash: (_) async => contentHash);
      await first.init();
      final conversation = await first.createConversation(title: 'Assets');
      final upload = File('${tempDir.path}/upload/not-moved.txt');
      await upload.parent.create(recursive: true);
      await upload.writeAsString('not moved payload');
      final message = await first.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: '[file:${upload.path}|not-moved.txt|text/plain]',
      );
      await first.deleteMessage(message.id);
      await first.close();
      services.remove(first);

      const generation = 40;
      final quarantineDirectory = Directory(
        '${tempDir.path}/upload/.kelivo-gc',
      );
      await quarantineDirectory.create();
      final quarantine = File('${quarantineDirectory.path}/not-created');
      final database = sqlite.sqlite3.open(
        '${tempDir.path}/${AppDatabase.databaseFileName}',
      );
      try {
        database.execute(
          'INSERT OR REPLACE INTO asset_gc_rows('
          'asset_id, not_before, attempts, generation'
          ') VALUES (?, ?, ?, ?);',
          <Object?>[
            assetId,
            DateTime.now()
                .toUtc()
                .add(const Duration(days: 30))
                .microsecondsSinceEpoch,
            1,
            generation,
          ],
        );
        database.execute(
          'INSERT INTO asset_gc_quarantine_rows('
          'quarantine_path, asset_id, generation, original_path, state, '
          'created_at'
          ") VALUES (?, ?, ?, ?, 'pending', ?);",
          <Object?>[
            quarantine.path,
            assetId,
            generation,
            upload.path,
            DateTime.now().microsecondsSinceEpoch,
          ],
        );
      } finally {
        database.close();
      }

      final restarted = createService(
        assetContentHash: (_) async => contentHash,
      );
      await restarted.init();
      await restarted.close();
      services.remove(restarted);

      expect(await upload.exists(), isTrue);
      expect(await quarantine.exists(), isFalse);
      final verified = sqlite.sqlite3.open(
        '${tempDir.path}/${AppDatabase.databaseFileName}',
      );
      try {
        expect(
          verified.select('SELECT * FROM asset_gc_quarantine_rows;'),
          isEmpty,
        );
      } finally {
        verified.close();
      }
    },
  );

  test(
    'cold maintenance restores a quarantined asset still owned by DB',
    () async {
      final contentHash = List.filled(64, 'd').join();
      final assetId = 'asset_$contentHash';
      final first = createService(assetContentHash: (_) async => contentHash);
      await first.init();
      final conversation = await first.createConversation(title: 'Assets');
      final upload = File('${tempDir.path}/upload/pending.txt');
      await upload.parent.create(recursive: true);
      await upload.writeAsString('pending GC payload');
      final message = await first.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: '[file:${upload.path}|pending.txt|text/plain]',
      );
      await first.deleteMessage(message.id);
      await first.close();
      services.remove(first);

      const generation = 41;
      final quarantineDirectory = Directory(
        '${tempDir.path}/upload/.kelivo-gc',
      );
      await quarantineDirectory.create();
      final quarantine = File('${quarantineDirectory.path}/pending-record');
      await upload.rename(quarantine.path);
      final database = sqlite.sqlite3.open(
        '${tempDir.path}/${AppDatabase.databaseFileName}',
      );
      try {
        database.execute(
          'INSERT OR REPLACE INTO asset_gc_rows('
          'asset_id, not_before, attempts, generation'
          ') VALUES (?, ?, ?, ?);',
          <Object?>[
            assetId,
            DateTime.now()
                .toUtc()
                .add(const Duration(days: 30))
                .microsecondsSinceEpoch,
            1,
            generation,
          ],
        );
        database.execute(
          'INSERT INTO asset_gc_quarantine_rows('
          'quarantine_path, asset_id, generation, original_path, state, '
          'created_at'
          ") VALUES (?, ?, ?, ?, 'pending', ?);",
          <Object?>[
            quarantine.path,
            assetId,
            generation,
            upload.path,
            DateTime.now().microsecondsSinceEpoch,
          ],
        );
      } finally {
        database.close();
      }

      final restarted = createService(
        assetContentHash: (_) async => contentHash,
      );
      await restarted.init();
      await restarted.close();
      services.remove(restarted);

      expect(await upload.exists(), isTrue);
      expect(await quarantine.exists(), isFalse);
    },
  );

  test(
    'cold maintenance deletes quarantine after DB completed asset GC',
    () async {
      final contentHash = List.filled(64, 'e').join();
      final assetId = 'asset_$contentHash';
      final first = createService(assetContentHash: (_) async => contentHash);
      await first.init();
      final conversation = await first.createConversation(title: 'Assets');
      final upload = File('${tempDir.path}/upload/completed.txt');
      await upload.parent.create(recursive: true);
      await upload.writeAsString('completed GC payload');
      final message = await first.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: '[file:${upload.path}|completed.txt|text/plain]',
      );
      await first.deleteMessage(message.id);
      await first.close();
      services.remove(first);

      const generation = 42;
      final quarantineDirectory = Directory(
        '${tempDir.path}/upload/.kelivo-gc',
      );
      await quarantineDirectory.create();
      final quarantine = File('${quarantineDirectory.path}/completed-record');
      await upload.rename(quarantine.path);
      final database = sqlite.sqlite3.open(
        '${tempDir.path}/${AppDatabase.databaseFileName}',
      );
      try {
        database.execute('DELETE FROM asset_rows WHERE id = ?;', <Object?>[
          assetId,
        ]);
        database.execute(
          'INSERT INTO asset_gc_quarantine_rows('
          'quarantine_path, asset_id, generation, original_path, state, '
          'created_at'
          ") VALUES (?, ?, ?, ?, 'completed', ?);",
          <Object?>[
            quarantine.path,
            assetId,
            generation,
            upload.path,
            DateTime.now().microsecondsSinceEpoch,
          ],
        );
      } finally {
        database.close();
      }

      final restarted = createService(
        assetContentHash: (_) async => contentHash,
      );
      await restarted.init();
      await restarted.close();
      services.remove(restarted);

      expect(await upload.exists(), isFalse);
      expect(await quarantine.exists(), isFalse);
    },
  );

  test(
    'cold maintenance restores completed quarantine for a newer dirty message',
    () async {
      final contentHash = List.filled(64, 'f').join();
      final assetId = 'asset_$contentHash';
      final first = createService(assetContentHash: (_) async => contentHash);
      await first.init();
      final conversation = await first.createConversation(title: 'Assets');
      final upload = File('${tempDir.path}/upload/completed-but-reused.txt');
      await upload.parent.create(recursive: true);
      await upload.writeAsString('payload needed by newer message');
      final message = await first.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: '[file:${upload.path}|completed-but-reused.txt|text/plain]',
      );
      await first.close();
      services.remove(first);

      const generation = 43;
      final quarantineDirectory = Directory(
        '${tempDir.path}/upload/.kelivo-gc',
      );
      await quarantineDirectory.create();
      final quarantine = File('${quarantineDirectory.path}/completed-reused');
      await upload.rename(quarantine.path);
      final database = sqlite.sqlite3.open(
        '${tempDir.path}/${AppDatabase.databaseFileName}',
      );
      try {
        database.execute('DELETE FROM asset_rows WHERE id = ?;', <Object?>[
          assetId,
        ]);
        database.execute(
          'INSERT OR IGNORE INTO asset_reference_dirty_rows(revision_id) '
          'VALUES (?);',
          <Object?>[message.id],
        );
        database.execute(
          'INSERT INTO asset_gc_quarantine_rows('
          'quarantine_path, asset_id, generation, original_path, state, '
          'created_at'
          ") VALUES (?, ?, ?, ?, 'completed', ?);",
          <Object?>[
            quarantine.path,
            assetId,
            generation,
            upload.path,
            DateTime.now().microsecondsSinceEpoch,
          ],
        );
      } finally {
        database.close();
      }

      final restarted = createService(
        assetContentHash: (_) async => contentHash,
      );
      await restarted.init();
      await restarted.runAssetMaintenance();

      expect(await upload.readAsString(), 'payload needed by newer message');
      expect(await quarantine.exists(), isFalse);
      final verified = sqlite.sqlite3.open(
        '${tempDir.path}/${AppDatabase.databaseFileName}',
      );
      try {
        expect(
          verified.select(
            'SELECT asset_id FROM message_asset_rows WHERE revision_id = ?;',
            <Object?>[message.id],
          ).single['asset_id'],
          assetId,
        );
        expect(
          verified.select(
            'SELECT revision_id FROM asset_reference_dirty_rows '
            'WHERE revision_id = ?;',
            <Object?>[message.id],
          ),
          isEmpty,
        );
        expect(
          verified.select('SELECT * FROM asset_gc_quarantine_rows;'),
          isEmpty,
        );
      } finally {
        verified.close();
      }
    },
  );

  test(
    'cold maintenance keeps an ambiguous completed receipt fail closed',
    () async {
      final contentHash = List.filled(64, '7').join();
      final assetId = 'asset_$contentHash';
      final first = createService(assetContentHash: (_) async => contentHash);
      await first.init();
      final conversation = await first.createConversation(title: 'Assets');
      final upload = File('${tempDir.path}/upload/ambiguous-completed.txt');
      await upload.parent.create(recursive: true);
      await upload.writeAsString('must remain recoverable');
      final message = await first.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: '[file:${upload.path}|ambiguous-completed.txt|text/plain]',
      );
      await first.deleteMessage(message.id);
      await first.close();
      services.remove(first);

      const generation = 44;
      final quarantine = File(
        '${tempDir.path}/upload/.kelivo-gc/ambiguous-completed',
      );
      final database = sqlite.sqlite3.open(
        '${tempDir.path}/${AppDatabase.databaseFileName}',
      );
      try {
        database.execute('DELETE FROM asset_rows WHERE id = ?;', <Object?>[
          assetId,
        ]);
        database.execute(
          'INSERT INTO asset_gc_quarantine_rows('
          'quarantine_path, asset_id, generation, original_path, state, '
          'created_at'
          ") VALUES (?, ?, ?, ?, 'completed', ?);",
          <Object?>[
            quarantine.path,
            assetId,
            generation,
            upload.path,
            DateTime.now().microsecondsSinceEpoch,
          ],
        );
      } finally {
        database.close();
      }

      final restarted = createService(
        assetContentHash: (_) async => contentHash,
      );
      await restarted.init();

      await expectLater(restarted.runAssetMaintenance(), throwsStateError);
      expect(await upload.readAsString(), 'must remain recoverable');
      expect(await quarantine.exists(), isFalse);
      final verified = sqlite.sqlite3.open(
        '${tempDir.path}/${AppDatabase.databaseFileName}',
      );
      try {
        expect(
          verified.select(
            'SELECT state FROM asset_gc_quarantine_rows '
            'WHERE quarantine_path = ?;',
            <Object?>[quarantine.path],
          ).single['state'],
          'completed',
        );
      } finally {
        verified.close();
      }
    },
  );

  group('ChatService temporary conversations', () {
    test('ordinary draft persists when its first message is added', () async {
      final service = createService();
      await service.init();

      final conversation = await service.createDraftConversation(title: 'Chat');
      final message = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'hello',
      );

      expect(service.getAllConversations().map((c) => c.id), [conversation.id]);
      expect(await service.loadMessages(conversation.id), hasLength(1));
      final timeline = await service.loadTimelinePage(
        conversation.id,
        fromStart: true,
      );
      expect(timeline!.slots.single.message.id, message.id);
      expect(timeline.slots.single.message.content, 'hello');
    });

    test(
      'temporary draft keeps messages in memory without entering history',
      () async {
        final service = createService();
        await service.init();

        final conversation = await service.createDraftConversation(
          title: 'Temporary Chat',
          temporary: true,
        );
        await service.addMessage(
          conversationId: conversation.id,
          role: 'user',
          content: 'secret',
        );

        expect(service.getAllConversations(), isEmpty);
        expect(service.getConversation(conversation.id), isNotNull);
        expect(service.getMessages(conversation.id), hasLength(1));
        expect(service.isTemporaryConversation(conversation.id), isTrue);
      },
    );

    test(
      'temporary conversation supports range and recent message reads',
      () async {
        final service = createService();
        await service.init();

        final conversation = await service.createDraftConversation(
          title: 'Temporary Chat',
          temporary: true,
        );
        for (var i = 0; i < 5; i++) {
          await service.addMessage(
            conversationId: conversation.id,
            role: i.isEven ? 'user' : 'assistant',
            content: 'temporary message $i',
          );
        }

        final range = service.getMessagesRange(
          conversation.id,
          start: 1,
          limit: 3,
        );
        final recent = service.getRecentMessages(
          conversation.id,
          minMessages: 2,
          maxMessages: 2,
        );

        expect(range.map((message) => message.content), [
          'temporary message 1',
          'temporary message 2',
          'temporary message 3',
        ]);
        expect(recent.map((message) => message.content), [
          'temporary message 3',
          'temporary message 4',
        ]);
      },
    );

    test(
      'temporary timeline pages stay bounded without evicting memory history',
      () async {
        final service = createService();
        await service.init();

        final conversation = await service.createDraftConversation(
          title: 'Temporary Chat',
          temporary: true,
        );
        for (var i = 0; i < 45; i++) {
          await service.addMessage(
            conversationId: conversation.id,
            role: i.isEven ? 'user' : 'assistant',
            content: 'temporary message $i',
          );
        }

        final tail = await service.loadTimelinePage(conversation.id, limit: 40);
        expect(tail, isNotNull);
        expect(tail!.slots, hasLength(40));
        expect(tail.slots.first.message.content, 'temporary message 5');
        expect(tail.hasMoreBefore, isTrue);
        service.retainTimelineWindow(
          conversation.id,
          tail.slots.map((slot) => slot.identity.revisionId),
        );

        expect(await service.loadMessages(conversation.id), hasLength(45));
        final before = await service.loadTimelinePage(
          conversation.id,
          beforeRevisionId: tail.slots.first.identity.revisionId,
          limit: 20,
        );
        expect(before!.slots, hasLength(5));
        expect(before.slots.first.message.content, 'temporary message 0');
      },
    );

    test('temporary batch deletion reports the removed revisions', () async {
      final service = createService();
      await service.init();

      final conversation = await service.createDraftConversation(
        title: 'Temporary Chat',
        temporary: true,
      );
      final first = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'first',
      );
      final second = await service.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        content: 'second',
      );

      final deleted = await service.deleteMessages(
        conversationId: conversation.id,
        messageIds: {second.id, 'missing'},
        versionSelectionChanges: const {},
      );
      final page = await service.loadTimelinePage(conversation.id);

      expect(deleted, {second.id});
      expect(page!.slots.map((slot) => slot.identity.revisionId), [first.id]);
      expect(await service.loadMessages(conversation.id), [first]);
    });

    test(
      'temporary timeline projects the selected revision per slot',
      () async {
        final service = createService();
        await service.init();

        final conversation = await service.createDraftConversation(
          title: 'Temporary Chat',
          temporary: true,
        );
        await service.addMessage(
          conversationId: conversation.id,
          role: 'assistant',
          content: 'version zero',
          groupId: 'answer-slot',
          version: 0,
          selectVersion: true,
        );
        final selected = await service.addMessage(
          conversationId: conversation.id,
          role: 'assistant',
          content: 'version two',
          groupId: 'answer-slot',
          version: 2,
          selectVersion: true,
        );

        final page = await service.loadTimelinePage(conversation.id);

        expect(page!.slots, hasLength(1));
        expect(page.slots.single.identity.versionCount, 2);
        expect(page.slots.single.message, selected);
      },
    );

    test(
      'temporary conversation is discarded when current conversation changes',
      () async {
        final service = createService();
        await service.init();

        final temporary = await service.createDraftConversation(
          title: 'Temporary Chat',
          temporary: true,
        );
        await service.addMessage(
          conversationId: temporary.id,
          role: 'user',
          content: 'secret',
        );

        final ordinary = await service.createDraftConversation(title: 'Chat');

        expect(service.getConversation(temporary.id), isNull);
        expect(service.getMessages(temporary.id), isEmpty);
        expect(service.currentConversationId, ordinary.id);
        expect(service.getAllConversations(), isEmpty);
      },
    );

    test('temporary message deletion only affects memory', () async {
      final service = createService();
      await service.init();

      final conversation = await service.createDraftConversation(
        title: 'Temporary Chat',
        temporary: true,
      );
      final message = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'secret',
      );

      await service.deleteMessage(message.id);

      expect(service.getAllConversations(), isEmpty);
      expect(service.getMessages(conversation.id), isEmpty);
      expect(service.getConversation(conversation.id)?.messageIds, isEmpty);
    });
  });

  group('ChatService fork conversations', () {
    test(
      'fork copies selected path as plain single-version messages',
      () async {
        final service = createService();
        await service.init();

        final source = await service.createConversation(title: 'Source');
        final original = await service.addMessage(
          conversationId: source.id,
          role: 'assistant',
          content: 'original answer',
        );
        final edited = await service.appendMessageVersion(
          messageId: original.id,
          content: 'edited answer',
        );
        expect(edited, isNotNull);

        final fork = await service.forkConversationAtRevision(
          sourceConversationId: source.id,
          sourceRevisionId: edited!.id,
          title: 'Fork',
        );

        expect(fork.title, source.title);
        final forkMessages = service.getMessages(fork.id);
        expect(forkMessages, hasLength(1));
        expect(forkMessages.single.conversationId, fork.id);
        expect(forkMessages.single.content, 'edited answer');
        expect(
          forkMessages.single.groupId ?? forkMessages.single.id,
          forkMessages.single.id,
        );
        expect(forkMessages.single.version, 0);
        expect(service.getVersionSelections(fork.id), isEmpty);
      },
    );
  });

  test('final generation commit publishes one statistics revision', () async {
    final service = createService();
    await service.init();
    final conversation = await service.createConversation(title: 'Stats');
    final generation = await service.beginSendGeneration(
      conversationId: conversation.id,
      userContent: 'question',
      modelId: 'model',
      providerId: 'provider',
    );
    var run = await service.transitionGenerationRun(
      id: generation.run.id,
      expectedState: generation.run.state,
      expectedStateRevision: generation.run.stateRevision,
      nextState: GenerationRunState.requesting,
    );
    run = await service.transitionGenerationRun(
      id: run.id,
      expectedState: run.state,
      expectedStateRevision: run.stateRevision,
      nextState: GenerationRunState.streaming,
    );
    final completedMessage = generation.assistantMessage.copyWith(
      content: 'answer',
      totalTokens: 12,
      isStreaming: false,
      promptTokens: 3,
      completionTokens: 9,
    );
    final revisionBefore = service.statisticsRevision;
    var notifications = 0;
    void listener() => notifications++;
    service.addListener(listener);
    addTearDown(() => service.removeListener(listener));

    await service.finalizeGenerationRunSilent(
      message: completedMessage,
      toolEvents: const [],
      generationRunId: run.id,
      expectedState: run.state,
      expectedStateRevision: run.stateRevision,
      terminalState: GenerationRunState.completed,
    );

    expect(service.statisticsRevision, revisionBefore + 1);
    expect(notifications, 1);
    final aggregate = await service.loadStatsAggregate(
      rangeStart: null,
      rangeEndExclusive: null,
      heatmapStart: DateTime.utc(2000),
      trendStart: DateTime.utc(2000),
      trendEndExclusive: DateTime.utc(2100),
    );
    expect(aggregate.totals.messages, 2);
    expect(aggregate.totals.inputTokens, 3);
    expect(aggregate.totals.outputTokens, 9);
  });

  test('business selection uses linear group versions', () async {
    final service = createService();
    await service.init();
    final conversation = await service.createConversation(title: 'Graph');
    final original = await service.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      content: 'v0',
    );
    final edited = await service.appendMessageVersion(
      messageId: original.id,
      content: 'v1',
    );

    expect(edited, isNotNull);
    final groupId = edited!.groupId ?? original.id;

    await service.setSelectedVersion(conversation.id, groupId, 0);
    expect(service.getVersionSelections(conversation.id), {groupId: 0});
    final page = await service.loadTimelinePage(
      conversation.id,
      fromStart: true,
    );
    expect(page!.slots.single.message.id, original.id);
  });

  test('批量导入仅在覆盖模式声明聊天实体为本地权威', () async {
    final store = await CloudSyncStore.open();
    addTearDown(store.close);
    final service = createService();
    await service.init();

    await service.runImportBatch<void>(
      overwrite: false,
      conversations: const [],
      messages: const [],
      write: () async {},
    );

    final mergeRequest = store.rescanRequest;
    expect(mergeRequest, isNotNull);
    expect(mergeRequest!.entityTypes, CloudSyncStore.chatRescanEntityTypes);
    expect(mergeRequest.localAuthoritativeEntityTypes, isEmpty);
    expect(await store.consumeRescanRequest(mergeRequest.generation), isTrue);

    await service.runImportBatch<void>(
      overwrite: true,
      conversations: const [],
      messages: const [],
      write: () async {},
    );

    final overwriteRequest = store.rescanRequest;
    expect(overwriteRequest, isNotNull);
    expect(
      overwriteRequest!.localAuthoritativeEntityTypes,
      CloudSyncStore.chatRescanEntityTypes,
    );
  });

  test('清空聊天数据声明聊天实体为本地权威', () async {
    final store = await CloudSyncStore.open();
    addTearDown(store.close);
    final service = createService();
    await service.init();

    await service.clearAllData(deleteUploads: false);

    expect(
      store.rescanRequest?.localAuthoritativeEntityTypes,
      CloudSyncStore.chatRescanEntityTypes,
    );
  });

  test('覆盖导入回滚后不会遗留清空操作的本地权威标记', () async {
    final store = await CloudSyncStore.open();
    addTearDown(store.close);
    final service = createService();
    await service.init();

    await expectLater(
      service.runImportBatch<void>(
        overwrite: true,
        conversations: const [],
        messages: const [],
        write: () async {
          await service.clearAllData(deleteUploads: false);
          throw StateError('导入失败');
        },
      ),
      throwsA(isA<StateError>()),
    );

    expect(store.rescanRequest?.localAuthoritativeEntityTypes, isEmpty);
  });

  test('恢复数据库快照声明聊天实体为本地权威', () async {
    final store = await CloudSyncStore.open();
    addTearDown(store.close);
    final service = createService();
    await service.init();
    final snapshot = File('${tempDir.path}/restore-authority.db');
    await service.createBackupDatabaseSnapshot(snapshot);

    await service.restoreDatabaseSnapshot(snapshot);

    expect(
      store.rescanRequest?.localAuthoritativeEntityTypes,
      CloudSyncStore.chatRescanEntityTypes,
    );
  });
}

Future<void> _createDirectoryLink(String linkPath, String targetPath) async {
  if (!Platform.isWindows) {
    await Link(linkPath).create(targetPath);
    return;
  }
  final result = await Process.run(
    'pwsh',
    <String>[
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r'New-Item -ItemType Junction -Path $env:KELIVO_LINK_PATH '
          r'-Target $env:KELIVO_LINK_TARGET | Out-Null',
    ],
    environment: <String, String>{
      'KELIVO_LINK_PATH': linkPath,
      'KELIVO_LINK_TARGET': targetPath,
    },
  );
  if (result.exitCode != 0) {
    throw StateError('asset_junction_setup_failed:${result.stderr}');
  }
}
