import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart' as raw_sqlite;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_gateway.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_state_retirement.dart';
import 'package:Kelivo/core/services/sync/e2ee_chat_sync_adapter.dart';
import 'package:Kelivo/core/services/sync/sync_codec.dart';
import 'package:Kelivo/core/services/sync/sync_write_executor.dart';
import 'package:Kelivo/utils/app_directories.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

import '../../database/test_database_cipher.dart';

const sqlite = _TestSqliteFacade();

final class _TestSqliteFacade {
  const _TestSqliteFacade();

  _TestSqliteFacade get sqlite3 => this;

  raw_sqlite.Database open(
    String path, {
    raw_sqlite.OpenMode mode = raw_sqlite.OpenMode.readWriteCreate,
  }) {
    final database = raw_sqlite.sqlite3.open(path, mode: mode);
    testDatabaseCipher.apply(database, createSlotIfMissing: false);
    return database;
  }
}

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
  });

  tearDown(() async {
    for (final service in services) {
      await service.close();
    }
    services.clear();
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
      databaseGateway: ChatDatabaseGateway(cipher: testDatabaseCipher),
      assetContentHash: assetContentHash,
    );
    services.add(service);
    return service;
  }

  LocalMessageAttachmentInput localFileAttachment(
    File file, {
    required String displayName,
    String mediaType = 'application/octet-stream',
  }) {
    return LocalMessageAttachmentInput.file(
      path: file.path,
      displayName: displayName,
      mediaType: mediaType,
    );
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
      userAttachments: const <LocalMessageAttachmentInput>[],
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

  test('本地图片与文件和纯文本正文在同一事务持久化', () async {
    final service = createService();
    await service.init();
    final conversation = await service.createConversation(title: 'Assets');
    final image = File('${tempDir.path}/images/photo.png');
    final upload = File('${tempDir.path}/upload/spec.pdf');
    await image.parent.create(recursive: true);
    await upload.parent.create(recursive: true);
    await image.writeAsBytes(const <int>[1, 2, 3, 4]);
    await upload.writeAsString('attachment payload');
    final generation = await service.beginSendGeneration(
      conversationId: conversation.id,
      userContent: '请分析附件',
      userAttachments: <LocalMessageAttachmentInput>[
        LocalMessageAttachmentInput.image(path: image.path),
        localFileAttachment(
          upload,
          displayName: 'spec.pdf',
          mediaType: 'application/pdf',
        ),
      ],
      modelId: 'model',
      providerId: 'provider',
    );
    final message = generation.userMessage!;

    expect(message.content, '请分析附件');
    expect(message.content, isNot(contains('[image:')));
    expect(message.content, isNot(contains('[file:')));
    expect(message.attachments, hasLength(2));
    expect(message.attachments.map((attachment) => attachment.kind), [
      'image',
      'file',
    ]);
    expect(
      message.attachments.every((attachment) => !attachment.hasRemoteIdentity),
      isTrue,
    );
    final persisted = (await service.loadMessages(
      conversation.id,
    )).singleWhere((candidate) => candidate.id == message.id);
    expect(
      persisted.attachments.map((attachment) => attachment.toJson()),
      message.attachments.map((attachment) => attachment.toJson()),
    );

    await service.deleteMessage(message.id);

    expect(await upload.exists(), isTrue, reason: 'GC must be delayed');
    expect(await image.exists(), isTrue, reason: 'GC must be delayed');
    await service.runAssetMaintenance(
      now: DateTime.now().toUtc().add(const Duration(days: 8)),
    );
    expect(await upload.exists(), isFalse);
    expect(await image.exists(), isFalse);
  });

  test('本地附件数量支持零和三十二边界，超限不落库', () async {
    final service = createService(
      assetContentHash: (file) async {
        final index = int.parse(
          p.basenameWithoutExtension(file.path).split('-').last,
        );
        return index.toRadixString(16).padLeft(64, '0');
      },
    );
    await service.init();
    final conversation = await service.createConversation(title: 'Assets');
    final withoutAttachments = await service.addMessage(
      conversationId: conversation.id,
      role: 'user',
      content: '纯文本',
      attachments: const <LocalMessageAttachmentInput>[],
    );
    expect(withoutAttachments.attachments, isEmpty);

    final files = <File>[];
    for (var index = 0; index < 33; index++) {
      final file = File('${tempDir.path}/upload/asset-$index.bin');
      await file.parent.create(recursive: true);
      await file.writeAsString('asset $index');
      files.add(file);
    }
    final maximum = await service.addMessage(
      conversationId: conversation.id,
      role: 'user',
      content: '三十二个附件',
      attachments: <LocalMessageAttachmentInput>[
        for (final file in files.take(32))
          localFileAttachment(file, displayName: p.basename(file.path)),
      ],
    );
    expect(maximum.attachments, hasLength(32));

    await expectLater(
      service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: '超限附件',
        attachments: <LocalMessageAttachmentInput>[
          for (final file in files)
            localFileAttachment(file, displayName: p.basename(file.path)),
        ],
      ),
      throwsRangeError,
    );
    expect(await service.loadMessages(conversation.id), hasLength(2));
  });

  test('缺失文件和托管目录外文件失败且不留下消息或引用', () async {
    final service = createService();
    await service.init();
    final conversation = await service.createConversation(title: 'Assets');
    final missing = File('${tempDir.path}/upload/missing.txt');
    final outside = File(
      '${tempDir.parent.path}/outside-${p.basename(tempDir.path)}.txt',
    );
    await outside.writeAsString('outside');
    addTearDown(() async {
      if (await outside.exists()) await outside.delete();
    });

    await expectLater(
      service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: '缺失',
        attachments: <LocalMessageAttachmentInput>[
          localFileAttachment(missing, displayName: 'missing.txt'),
        ],
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'asset_file_unavailable',
        ),
      ),
    );
    await expectLater(
      service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: '逃逸',
        attachments: <LocalMessageAttachmentInput>[
          localFileAttachment(outside, displayName: 'outside.txt'),
        ],
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'asset_path_outside_managed_root',
        ),
      ),
    );

    expect(await service.loadMessages(conversation.id), isEmpty);
    final database = sqlite.sqlite3.open(
      '${tempDir.path}/${AppDatabase.databaseFileName}',
    );
    try {
      expect(
        database.select('SELECT revision_id FROM message_asset_rows;'),
        isEmpty,
      );
    } finally {
      database.close();
    }
  });

  test('asset maintenance waits for another process lease owner', () async {
    final databaseFile = File(
      '${tempDir.path}/${AppDatabase.databaseFileName}',
    );
    final externalRepository = ChatDatabaseRepository.open(
      file: databaseFile,
      cipher: testDatabaseCipher,
    );
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
        await expectLater(
          service.addMessage(
            conversationId: conversation.id,
            role: 'user',
            content: '路径换链',
            attachments: <LocalMessageAttachmentInput>[
              LocalMessageAttachmentInput.file(
                path: managedFilePath,
                displayName: 'private.txt',
                mediaType: 'text/plain',
              ),
            ],
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'asset_file_escaped_managed_root',
            ),
          ),
        );

        expect(hashAttempts, 1);
        final database = sqlite.sqlite3.open(
          '${tempDir.path}/${AppDatabase.databaseFileName}',
        );
        try {
          expect(database.select('SELECT id FROM message_rows;'), isEmpty);
          expect(database.select('SELECT id FROM asset_rows;'), isEmpty);
          expect(
            database.select(
              'SELECT revision_id FROM asset_reference_dirty_rows;',
            ),
            isEmpty,
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
      const content = '复用路径';
      final message = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: content,
        attachments: <LocalMessageAttachmentInput>[
          localFileAttachment(
            upload,
            displayName: 'reused-path.txt',
            mediaType: 'text/plain',
          ),
        ],
      );

      await upload.writeAsString('new payload');
      final edited = await service.appendMessageVersion(
        messageId: message.id,
        content: content,
        attachments: <LocalMessageAttachmentInput>[
          localFileAttachment(
            upload,
            displayName: 'reused-path.txt',
            mediaType: 'text/plain',
          ),
        ],
      );
      expect(edited, isNotNull);
      await service.deleteMessage(message.id);
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
            <Object?>[edited!.id],
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
        content: '普通附件',
        attachments: <LocalMessageAttachmentInput>[
          localFileAttachment(
            upload,
            displayName: 'report',
            mediaType: 'text/plain',
          ),
        ],
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
        content: '未移动',
        attachments: <LocalMessageAttachmentInput>[
          localFileAttachment(
            upload,
            displayName: 'not-moved.txt',
            mediaType: 'text/plain',
          ),
        ],
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
        content: '待恢复',
        attachments: <LocalMessageAttachmentInput>[
          localFileAttachment(
            upload,
            displayName: 'pending.txt',
            mediaType: 'text/plain',
          ),
        ],
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
        content: '已完成清理',
        attachments: <LocalMessageAttachmentInput>[
          localFileAttachment(
            upload,
            displayName: 'completed.txt',
            mediaType: 'text/plain',
          ),
        ],
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
        content: '歧义回执',
        attachments: <LocalMessageAttachmentInput>[
          localFileAttachment(
            upload,
            displayName: 'ambiguous-completed.txt',
            mediaType: 'text/plain',
          ),
        ],
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

  group('ChatService remote batch serialization', () {
    test('nested remote batch reenters without waiting for itself', () async {
      final service = createService();
      await service.init();
      final events = <String>[];
      final conversation = Conversation(
        id: 'nested-remote-conversation',
        title: 'Nested remote batch',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      await service
          .runRemoteBatch(() async {
            events.add('outer-start');
            await service.runRemoteBatch(() async {
              events.add('inner');
              await service.upsertConversationFromSync(conversation);
            });
            events.add('outer-end');
          })
          .timeout(const Duration(seconds: 2));

      expect(events, <String>['outer-start', 'inner', 'outer-end']);
      expect(
        (await service.loadConversationForSync(conversation.id))?.title,
        conversation.title,
      );
    });

    test('concurrent remote batches never interleave', () async {
      final service = createService();
      await service.init();
      final events = <String>[];
      final firstEntered = Completer<void>();
      final releaseFirst = Completer<void>();
      final secondEntered = Completer<void>();
      final firstConversation = Conversation(
        id: 'first-remote-conversation',
        title: 'First remote batch',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final secondConversation = Conversation(
        id: 'second-remote-conversation',
        title: 'Second remote batch',
        createdAt: DateTime.utc(2026, 1, 2),
        updatedAt: DateTime.utc(2026, 1, 2),
      );

      final first = service.runRemoteBatch(() async {
        events.add('first-start');
        await service.upsertConversationFromSync(firstConversation);
        firstEntered.complete();
        await releaseFirst.future;
        events.add('first-end');
      });
      await firstEntered.future;

      final second = service.runRemoteBatch(() async {
        events.add('second-start');
        secondEntered.complete();
        await service.upsertConversationFromSync(secondConversation);
        events.add('second-end');
      });

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(secondEntered.isCompleted, isFalse);
      releaseFirst.complete();
      await Future.wait<void>(<Future<void>>[first, second]);

      expect(events, <String>[
        'first-start',
        'first-end',
        'second-start',
        'second-end',
      ]);
      expect(
        await service.loadConversationForSync(firstConversation.id),
        isNotNull,
      );
      expect(
        await service.loadConversationForSync(secondConversation.id),
        isNotNull,
      );
    });

    test('failed remote batch releases the next queued batch', () async {
      final service = createService();
      await service.init();
      final firstEntered = Completer<void>();
      final releaseFirst = Completer<void>();
      final secondEntered = Completer<void>();
      final rolledBackConversation = Conversation(
        id: 'rolled-back-remote-conversation',
        title: 'Rolled back remote batch',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final committedConversation = Conversation(
        id: 'committed-remote-conversation',
        title: 'Committed remote batch',
        createdAt: DateTime.utc(2026, 1, 2),
        updatedAt: DateTime.utc(2026, 1, 2),
      );

      final failing = service.runRemoteBatch<void>(() async {
        await service.upsertConversationFromSync(rolledBackConversation);
        firstEntered.complete();
        await releaseFirst.future;
        throw StateError('expected remote batch failure');
      });
      final failingExpectation = expectLater(
        failing,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'expected remote batch failure',
          ),
        ),
      );
      await firstEntered.future;

      final succeeding = service.runRemoteBatch(() async {
        secondEntered.complete();
        await service.upsertConversationFromSync(committedConversation);
      });

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(secondEntered.isCompleted, isFalse);
      releaseFirst.complete();
      await failingExpectation;
      await succeeding.timeout(const Duration(seconds: 2));

      expect(
        await service.loadConversationForSync(rolledBackConversation.id),
        isNull,
      );
      expect(
        await service.loadConversationForSync(committedConversation.id),
        isNotNull,
      );
    });

    test(
      'close waits for running and queued batches and rejects new batches',
      () async {
        final service = createService();
        await service.init();
        final events = <String>[];
        final firstEntered = Completer<void>();
        final releaseFirst = Completer<void>();
        final secondEntered = Completer<void>();
        final releaseSecond = Completer<void>();

        final first = service.runRemoteBatch(() async {
          events.add('first-start');
          firstEntered.complete();
          await releaseFirst.future;
          events.add('first-end');
        });
        await firstEntered.future;
        final second = service.runRemoteBatch(() async {
          events.add('second-start');
          secondEntered.complete();
          await releaseSecond.future;
          events.add('second-end');
        });

        var closeCompleted = false;
        final closing = service.close();
        final sameClosing = service.close();
        expect(identical(closing, sameClosing), isTrue);
        final trackedClosing = closing.whenComplete(() {
          closeCompleted = true;
        });

        var rejectedApplyRan = false;
        await expectLater(
          service.runRemoteBatch(() async {
            rejectedApplyRan = true;
          }),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              '聊天服务正在关闭，不能开始新的远端同步批次',
            ),
          ),
        );
        expect(rejectedApplyRan, isFalse);
        expect(closeCompleted, isFalse);
        expect(secondEntered.isCompleted, isFalse);

        releaseFirst.complete();
        await secondEntered.future;
        expect(closeCompleted, isFalse);

        releaseSecond.complete();
        await Future.wait<void>(<Future<void>>[first, second, trackedClosing]);

        expect(events, <String>[
          'first-start',
          'first-end',
          'second-start',
          'second-end',
        ]);
        expect(closeCompleted, isTrue);
        expect(service.initialized, isFalse);

        await service.init();
        await service.runRemoteBatch(() async {
          events.add('reopened');
        });
        expect(events.last, 'reopened');
      },
    );

    test(
      'close inside a remote batch is rejected without poisoning close',
      () async {
        final service = createService();
        await service.init();

        await service
            .runRemoteBatch(() async {
              await expectLater(
                service.close(),
                throwsA(
                  isA<StateError>().having(
                    (error) => error.message,
                    'message',
                    '远端同步批次内不能关闭聊天服务',
                  ),
                ),
              );
            })
            .timeout(const Duration(seconds: 2));

        expect(service.initialized, isTrue);
        await service.close().timeout(const Duration(seconds: 2));
        expect(service.initialized, isFalse);
      },
    );

    test('committed pull refreshes and notifies exactly once', () async {
      final service = createService();
      await service.init();
      var notifications = 0;
      service.addListener(() => notifications++);
      final E2eeChatSyncPullBatchRunner runner =
          service.runCommittedRemoteSyncPull;

      final result = await runner<int>(
        pull: () async => 7,
        shouldRefresh: () => true,
        mayHaveOrphanedAssets: () => false,
      );

      expect(result, 7);
      expect(notifications, 1);
    });

    test('failed pull does not refresh or notify', () async {
      final service = createService();
      await service.init();
      var notifications = 0;
      service.addListener(() => notifications++);

      await expectLater(
        service.runCommittedRemoteSyncPull<void>(
          pull: () async => throw StateError('pull-rolled-back'),
          shouldRefresh: () => true,
          mayHaveOrphanedAssets: () => true,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'pull-rolled-back',
          ),
        ),
      );

      expect(notifications, 0);
    });

    test(
      'close waits until pull commit and cache publication finish',
      () async {
        final service = createService();
        await service.init();
        final pullEntered = Completer<void>();
        final releasePull = Completer<void>();
        var notifications = 0;
        service.addListener(() => notifications++);

        final pulling = service.runCommittedRemoteSyncPull<void>(
          pull: () async {
            pullEntered.complete();
            await releasePull.future;
          },
          shouldRefresh: () => true,
          mayHaveOrphanedAssets: () => false,
        );
        await pullEntered.future;
        var closeCompleted = false;
        final closing = service.close().whenComplete(
          () => closeCompleted = true,
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(closeCompleted, isFalse);
        releasePull.complete();
        await Future.wait<void>(<Future<void>>[pulling, closing]);

        expect(notifications, 1);
        expect(closeCompleted, isTrue);
        expect(service.initialized, isFalse);
      },
    );
  });

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
        final upload = File('${tempDir.path}/upload/temporary.txt');
        await upload.parent.create(recursive: true);
        await upload.writeAsString('temporary attachment');
        final message = await service.addMessage(
          conversationId: conversation.id,
          role: 'user',
          content: 'secret',
          attachments: <LocalMessageAttachmentInput>[
            localFileAttachment(
              upload,
              displayName: 'temporary.txt',
              mediaType: 'text/plain',
            ),
          ],
        );

        expect(service.getAllConversations(), isEmpty);
        expect(service.getConversation(conversation.id), isNotNull);
        expect(service.getMessages(conversation.id), hasLength(1));
        expect(message.content, 'secret');
        expect(
          message.attachments.single.path,
          p.normalize(upload.absolute.path),
        );
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
          attachments: const <LocalMessageAttachmentInput>[],
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
      userAttachments: const <LocalMessageAttachmentInput>[],
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
      attachments: const <LocalMessageAttachmentInput>[],
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

  test('用户编辑版本以新结构化附件原子写入且保留原版本附件', () async {
    final service = createService();
    await service.init();
    final conversation = await service.createConversation(title: 'Edit');
    final oldFile = File('${tempDir.path}/upload/old.txt');
    final newFile = File('${tempDir.path}/upload/new.txt');
    await oldFile.parent.create(recursive: true);
    await oldFile.writeAsString('old attachment');
    await newFile.writeAsString('new attachment');
    final original = await service.addMessage(
      conversationId: conversation.id,
      role: 'user',
      content: '原始正文',
      attachments: <LocalMessageAttachmentInput>[
        localFileAttachment(
          oldFile,
          displayName: 'old.txt',
          mediaType: 'text/plain',
        ),
      ],
    );

    final edited = await service.appendMessageVersion(
      messageId: original.id,
      content: '编辑正文',
      attachments: <LocalMessageAttachmentInput>[
        localFileAttachment(
          newFile,
          displayName: 'new.txt',
          mediaType: 'text/plain',
        ),
      ],
    );

    expect(edited, isNotNull);
    expect(edited!.content, '编辑正文');
    expect(edited.attachments.single.displayName, 'new.txt');
    expect(edited.attachments.single.hasRemoteIdentity, isFalse);
    expect(
      (await service.loadMessagesForGroups(conversation.id, <String>{
        original.groupId ?? original.id,
      })).map((message) => message.attachments.single.displayName),
      containsAll(<String>['old.txt', 'new.txt']),
    );
  });

  test('批量导入成功后不创建旧同步状态库', () async {
    final service = createService();
    await service.init();
    var writes = 0;

    await service.runImportBatch<void>(
      overwrite: false,
      conversations: const [],
      messages: const [],
      write: () async {
        writes++;
      },
    );

    expect(writes, 1);
    await _expectLegacyCloudSyncStateAbsent(tempDir);
  });

  test('批量导入失败后不创建旧同步状态库', () async {
    final service = createService();
    await service.init();

    await expectLater(
      service.runImportBatch<void>(
        overwrite: true,
        conversations: const [],
        messages: const [],
        write: () => Future<void>.error(StateError('导入失败')),
      ),
      throwsA(isA<StateError>()),
    );

    await _expectLegacyCloudSyncStateAbsent(tempDir);
  });

  test('删除和清空聊天数据不创建旧同步状态库', () async {
    final service = createService();
    await service.init();
    final conversation = await service.createConversation(title: 'Local');

    await service.deleteConversation(conversation.id);
    expect(service.getConversation(conversation.id), isNull);
    await service.clearAllData(deleteUploads: false);

    expect(service.getAllCompleteConversations(), isEmpty);
    await _expectLegacyCloudSyncStateAbsent(tempDir);
  });

  test('恢复数据库快照不创建旧同步状态库', () async {
    final service = createService();
    await service.init();
    final snapshot = File('${tempDir.path}/restore-local-only.db');
    await service.createBackupDatabaseSnapshot(snapshot);

    await service.restoreDatabaseSnapshot(snapshot);

    await _expectLegacyCloudSyncStateAbsent(tempDir);
  });
}

Future<void> _expectLegacyCloudSyncStateAbsent(Directory root) async {
  for (final suffix in const <String>['.hive', '.hivec', '.lock']) {
    expect(
      await File(
        p.join(root.path, '${CloudSyncStateRetirement.legacyBoxName}$suffix'),
      ).exists(),
      isFalse,
    );
  }
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
