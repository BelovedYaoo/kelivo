import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';

import 'test_database_cipher.dart';

void main() {
  test(
    'asset references cancel delayed GC and unreferenced assets are claimed',
    () async {
      final root = await Directory.systemTemp.createTemp('asset_gc_test_');
      final repository = ChatDatabaseRepository.open(
        file: File('${root.path}/assets.sqlite'),
        cipher: testDatabaseCipher,
      );
      addTearDown(() async {
        await repository.close();
        await root.delete(recursive: true);
      });
      final now = DateTime.utc(2026, 7, 12);
      final conversation = Conversation(
        id: 'conversation-1',
        title: 'Assets',
        createdAt: now,
        updatedAt: now,
        messageIds: const ['revision-1'],
      );
      final message = ChatMessage(
        id: 'revision-1',
        role: 'user',
        content: 'asset',
        timestamp: now,
        conversationId: conversation.id,
      );
      await repository.putMigrationBatch(
        conversations: [conversation],
        messages: [(message: message, messageOrder: 0)],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      await repository.registerAsset(
        id: 'asset-1',
        contentHash: List.filled(64, 'a').join(),
        path: '${root.path}/image.png',
        byteSize: 4096,
        width: 1200,
        height: 800,
        thumbnailPath: '${root.path}/image.thumb.webp',
        createdAt: now,
      );
      await repository.linkMessageAsset(
        conversationId: conversation.id,
        revisionId: message.id,
        assetId: 'asset-1',
        kind: 'image',
      );

      expect(await repository.scheduleUnreferencedAssetGc(notBefore: now), 0);
      await repository.unlinkMessageAsset(
        revisionId: message.id,
        assetId: 'asset-1',
      );
      expect(await repository.scheduleUnreferencedAssetGc(notBefore: now), 1);
      final candidate = (await repository.claimAssetGc(now: now)).single;
      expect(candidate.assetId, 'asset-1');
      expect(candidate.thumbnailPath, endsWith('image.thumb.webp'));
      expect(
        await repository.isAssetGcClaimStillValid(candidate, now: now),
        isTrue,
      );
      final firstQuarantine = '${root.path}/quarantine/first';
      await repository.recordAssetGcQuarantine(
        assetId: candidate.assetId,
        generation: candidate.generation,
        originalPath: candidate.path,
        quarantinePath: firstQuarantine,
        createdAt: now,
      );
      expect(
        (await repository.getAssetGcQuarantine(firstQuarantine))?.state,
        AssetGcQuarantineState.pending,
      );

      await repository.linkMessageAsset(
        conversationId: conversation.id,
        revisionId: message.id,
        assetId: 'asset-1',
        kind: 'image',
      );
      expect(
        await repository.isAssetGcClaimStillValid(candidate, now: now),
        isFalse,
      );
      expect(
        (await repository.getAssetGcQuarantine(firstQuarantine))?.state,
        AssetGcQuarantineState.pending,
      );
      expect(await repository.claimAssetGc(now: now), isEmpty);
      expect(
        await repository.completeAssetGc(
          assetId: 'asset-1',
          expectedGeneration: candidate.generation,
          expectedQuarantinePaths: {firstQuarantine},
          now: now,
        ),
        isFalse,
      );
      await repository.deleteAssetGcQuarantine(firstQuarantine);

      await repository.unlinkMessageAsset(
        revisionId: message.id,
        assetId: 'asset-1',
      );
      await repository.scheduleUnreferencedAssetGc(notBefore: now);
      expect(
        await repository.completeAssetGc(
          assetId: 'asset-1',
          expectedGeneration: candidate.generation,
          expectedQuarantinePaths: const {},
          now: now,
        ),
        isFalse,
        reason: 'a stale claim cannot complete a newly scheduled generation',
      );
      final nextCandidate = (await repository.claimAssetGc(now: now)).single;
      expect(nextCandidate.generation, isNot(candidate.generation));
      final secondQuarantine = '${root.path}/quarantine/second';
      await repository.recordAssetGcQuarantine(
        assetId: nextCandidate.assetId,
        generation: nextCandidate.generation,
        originalPath: nextCandidate.path,
        quarantinePath: secondQuarantine,
        createdAt: now,
      );
      await repository.deleteAssetGcQuarantine(secondQuarantine);
      expect(
        await repository.completeAssetGc(
          assetId: 'asset-1',
          expectedGeneration: nextCandidate.generation,
          expectedQuarantinePaths: {secondQuarantine},
          now: now,
        ),
        isFalse,
        reason: 'a missing pending receipt must fence physical deletion',
      );
      await repository.recordAssetGcQuarantine(
        assetId: nextCandidate.assetId,
        generation: nextCandidate.generation,
        originalPath: nextCandidate.path,
        quarantinePath: secondQuarantine,
        createdAt: now,
      );
      expect(
        await repository.completeAssetGc(
          assetId: 'asset-1',
          expectedGeneration: nextCandidate.generation,
          expectedQuarantinePaths: {secondQuarantine},
          now: now,
        ),
        isTrue,
      );
      expect(
        (await repository.getAssetGcQuarantine(secondQuarantine))?.state,
        AssetGcQuarantineState.completed,
      );
    },
  );

  test(
    'a claimed asset cannot delete paths referenced by another asset',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'asset_gc_shared_path_test_',
      );
      final repository = ChatDatabaseRepository.open(
        file: File('${root.path}/assets.sqlite'),
        cipher: testDatabaseCipher,
      );
      addTearDown(() async {
        await repository.close();
        await root.delete(recursive: true);
      });
      final now = DateTime.utc(2026, 7, 12);
      final conversation = Conversation(
        id: 'conversation-1',
        title: 'Assets',
        createdAt: now,
        updatedAt: now,
        messageIds: const ['revision-1'],
      );
      final message = ChatMessage(
        id: 'revision-1',
        role: 'user',
        content: 'asset',
        timestamp: now,
        conversationId: conversation.id,
      );
      await repository.putMigrationBatch(
        conversations: [conversation],
        messages: [(message: message, messageOrder: 0)],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      final sharedMainPath = '${root.path}/shared-main.png';
      final sharedThumbnailPath = '${root.path}/shared-thumbnail.webp';
      await repository.registerAsset(
        id: 'asset-old',
        contentHash: List.filled(64, 'b').join(),
        path: sharedMainPath,
        thumbnailPath: sharedThumbnailPath,
        byteSize: 4096,
        createdAt: now,
      );
      await repository.scheduleUnreferencedAssetGc(notBefore: now);
      final staleCandidate = (await repository.claimAssetGc(now: now)).single;

      await repository.markMessageAssetReferencesDirty(message.id);
      expect(
        await repository.isAssetGcClaimStillValid(staleCandidate, now: now),
        isFalse,
        reason: 'an in-flight reference rewrite must block every asset GC',
      );
      final rawReference = message.copyWith(
        content: '[file:$sharedMainPath|shared-main.png|image/png]',
      );
      await repository.updateMessage(rawReference);
      expect(
        await repository.replaceMessageAssetReferences(
          conversationId: conversation.id,
          revisionId: message.id,
          expectedContent: rawReference.content,
          assets: const [],
        ),
        isTrue,
      );
      expect(
        await repository.isAssetGcClaimStillValid(staleCandidate, now: now),
        isFalse,
        reason: 'a raw attachment marker survives a missing-file index pass',
      );
      await repository.updateMessage(message);
      expect(
        await repository.isAssetGcClaimStillValid(staleCandidate, now: now),
        isTrue,
      );

      await repository.registerAsset(
        id: 'asset-current',
        contentHash: List.filled(64, 'c').join(),
        path: sharedThumbnailPath,
        thumbnailPath: sharedMainPath,
        byteSize: 4096,
        createdAt: now,
      );
      await repository.linkMessageAsset(
        conversationId: conversation.id,
        revisionId: message.id,
        assetId: 'asset-current',
        kind: 'image',
      );

      expect(
        await repository.isAssetGcClaimStillValid(staleCandidate, now: now),
        isFalse,
      );
      expect(
        await repository.completeAssetGc(
          assetId: staleCandidate.assetId,
          expectedGeneration: staleCandidate.generation,
          expectedQuarantinePaths: const {},
          now: now,
        ),
        isFalse,
      );
      expect(await repository.claimAssetGc(now: now), isEmpty);
    },
  );

  test(
    'shared paths honor the newest unreferenced asset delay window',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'asset_gc_shared_delay_test_',
      );
      final repository = ChatDatabaseRepository.open(
        file: File('${root.path}/assets.sqlite'),
        cipher: testDatabaseCipher,
      );
      addTearDown(() async {
        await repository.close();
        await root.delete(recursive: true);
      });
      final now = DateTime.utc(2026, 7, 12);
      final conversation = Conversation(
        id: 'conversation-delay',
        title: 'Assets',
        createdAt: now,
        updatedAt: now,
        messageIds: const ['revision-delay'],
      );
      final message = ChatMessage(
        id: 'revision-delay',
        role: 'user',
        content: 'asset',
        timestamp: now,
        conversationId: conversation.id,
      );
      await repository.putMigrationBatch(
        conversations: [conversation],
        messages: [(message: message, messageOrder: 0)],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      final sharedMainPath = '${root.path}/shared-delay-main.png';
      final sharedThumbnailPath = '${root.path}/shared-delay-thumbnail.webp';
      await repository.registerAsset(
        id: 'asset-delay-old',
        contentHash: List.filled(64, 'd').join(),
        path: sharedMainPath,
        thumbnailPath: sharedThumbnailPath,
        byteSize: 4096,
        createdAt: now,
      );
      await repository.scheduleUnreferencedAssetGc(notBefore: now);
      final oldCandidate = (await repository.claimAssetGc(now: now)).single;

      await repository.registerAsset(
        id: 'asset-delay-new',
        contentHash: List.filled(64, 'e').join(),
        path: sharedThumbnailPath,
        thumbnailPath: sharedMainPath,
        byteSize: 4096,
        createdAt: now,
      );
      await repository.linkMessageAsset(
        conversationId: conversation.id,
        revisionId: message.id,
        assetId: 'asset-delay-new',
        kind: 'image',
      );
      await repository.unlinkMessageAsset(
        revisionId: message.id,
        assetId: 'asset-delay-new',
      );
      final newlyUnreferencedAt = now.add(const Duration(days: 8));
      await repository.scheduleUnreferencedAssetGc(
        notBefore: newlyUnreferencedAt.add(const Duration(days: 7)),
      );

      expect(
        await repository.isAssetGcClaimStillValid(
          oldCandidate,
          now: newlyUnreferencedAt,
        ),
        isFalse,
      );
      expect(
        await repository.completeAssetGc(
          assetId: oldCandidate.assetId,
          expectedGeneration: oldCandidate.generation,
          expectedQuarantinePaths: const {},
          now: newlyUnreferencedAt,
        ),
        isFalse,
      );
      expect(await repository.claimAssetGc(now: newlyUnreferencedAt), isEmpty);
    },
  );

  test(
    'completed quarantine restores a path claimed by a newer delayed asset',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'asset_gc_completed_shared_delay_test_',
      );
      final repository = ChatDatabaseRepository.open(
        file: File('${root.path}/assets.sqlite'),
        cipher: testDatabaseCipher,
      );
      addTearDown(() async {
        await repository.close();
        await root.delete(recursive: true);
      });
      final now = DateTime.utc(2026, 7, 12);
      final conversation = Conversation(
        id: 'conversation-completed-delay',
        title: 'Assets',
        createdAt: now,
        updatedAt: now,
        messageIds: const ['revision-completed-delay'],
      );
      final message = ChatMessage(
        id: 'revision-completed-delay',
        role: 'user',
        content: 'asset',
        timestamp: now,
        conversationId: conversation.id,
      );
      await repository.putMigrationBatch(
        conversations: [conversation],
        messages: [(message: message, messageOrder: 0)],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      final sharedPath = '${root.path}/shared-delayed-path.txt';
      await repository.registerAsset(
        id: 'asset-completed-old',
        contentHash: List.filled(64, 'f').join(),
        path: sharedPath,
        byteSize: 4096,
        createdAt: now,
      );
      await repository.scheduleUnreferencedAssetGc(notBefore: now);
      final oldCandidate = (await repository.claimAssetGc(now: now)).single;
      final quarantinePath = '${root.path}/quarantine/completed-old';
      await repository.recordAssetGcQuarantine(
        assetId: oldCandidate.assetId,
        generation: oldCandidate.generation,
        originalPath: oldCandidate.path,
        quarantinePath: quarantinePath,
        createdAt: now,
      );
      expect(
        await repository.completeAssetGc(
          assetId: oldCandidate.assetId,
          expectedGeneration: oldCandidate.generation,
          expectedQuarantinePaths: {quarantinePath},
          now: now,
        ),
        isTrue,
      );

      await repository.registerAsset(
        id: 'asset-completed-new',
        contentHash: List.filled(64, '0').join(),
        path: sharedPath,
        byteSize: 4096,
        createdAt: now.add(const Duration(seconds: 1)),
      );
      await repository.linkMessageAsset(
        conversationId: conversation.id,
        revisionId: message.id,
        assetId: 'asset-completed-new',
        kind: 'file',
      );
      await repository.unlinkMessageAsset(
        revisionId: message.id,
        assetId: 'asset-completed-new',
      );
      final delayedUntil = now.add(const Duration(days: 7));
      await repository.scheduleUnreferencedAssetGc(notBefore: delayedUntil);

      AssetGcCompletedDisposition? disposition;
      final completedRecord = await repository.getAssetGcQuarantine(
        quarantinePath,
      );
      expect(completedRecord, isNotNull);
      await repository.settleCompletedAssetGcQuarantine(
        expectedRecord: completedRecord!,
        settleFile: (value) async {
          disposition = value;
        },
      );

      expect(disposition, AssetGcCompletedDisposition.restore);
      expect(
        await repository.claimAssetGc(
          now: delayedUntil.subtract(const Duration(microseconds: 1)),
        ),
        isEmpty,
      );
      expect(
        (await repository.claimAssetGc(now: delayedUntil)).single.assetId,
        'asset-completed-new',
      );
    },
  );

  test(
    'unrelated dirty references do not orphan a completed quarantine',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'asset_gc_completed_unrelated_dirty_test_',
      );
      final repository = ChatDatabaseRepository.open(
        file: File('${root.path}/assets.sqlite'),
        cipher: testDatabaseCipher,
      );
      addTearDown(() async {
        await repository.close();
        await root.delete(recursive: true);
      });
      final now = DateTime.utc(2026, 7, 12);
      final conversation = Conversation(
        id: 'conversation-unrelated-dirty',
        title: 'Assets',
        createdAt: now,
        updatedAt: now,
        messageIds: const ['revision-unrelated-dirty'],
      );
      final message = ChatMessage(
        id: 'revision-unrelated-dirty',
        role: 'user',
        content: '[file:${root.path}/other.txt|other.txt|text/plain]',
        timestamp: now,
        conversationId: conversation.id,
      );
      await repository.putMigrationBatch(
        conversations: [conversation],
        messages: [(message: message, messageOrder: 0)],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      final completedPath = '${root.path}/completed.txt';
      await repository.registerAsset(
        id: 'asset-unrelated-dirty',
        contentHash: List.filled(64, '1').join(),
        path: completedPath,
        byteSize: 4096,
        createdAt: now,
      );
      await repository.scheduleUnreferencedAssetGc(notBefore: now);
      final candidate = (await repository.claimAssetGc(now: now)).single;
      final quarantinePath = '${root.path}/quarantine/unrelated-dirty';
      await repository.recordAssetGcQuarantine(
        assetId: candidate.assetId,
        generation: candidate.generation,
        originalPath: candidate.path,
        quarantinePath: quarantinePath,
        createdAt: now,
      );
      expect(
        await repository.completeAssetGc(
          assetId: candidate.assetId,
          expectedGeneration: candidate.generation,
          expectedQuarantinePaths: {quarantinePath},
          now: now,
        ),
        isTrue,
      );
      await repository.markMessageAssetReferencesDirty(message.id);

      AssetGcCompletedDisposition? disposition;
      final completedRecord = await repository.getAssetGcQuarantine(
        quarantinePath,
      );
      expect(completedRecord, isNotNull);
      await repository.settleCompletedAssetGcQuarantine(
        expectedRecord: completedRecord!,
        settleFile: (value) async {
          disposition = value;
        },
      );

      expect(disposition, AssetGcCompletedDisposition.delete);
    },
  );

  test(
    'an existing database creates the quarantine receipt table on demand',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'asset_gc_schema_upgrade_test_',
      );
      final databaseFile = File('${root.path}/assets.sqlite');
      ChatDatabaseRepository? repository = ChatDatabaseRepository.open(
        file: databaseFile,
        cipher: testDatabaseCipher,
      );
      addTearDown(() async {
        await repository?.close();
        await root.delete(recursive: true);
      });
      expect(await repository.listAssetGcQuarantines(), isEmpty);

      final initializedRepository = repository;
      repository = null;
      await initializedRepository.close();
      final database = sqlite.sqlite3.open(databaseFile.path);
      try {
        testDatabaseCipher.apply(database, createSlotIfMissing: false);
        database.execute('DROP TABLE asset_gc_quarantine_rows;');
      } finally {
        database.close();
      }

      repository = ChatDatabaseRepository.open(
        file: databaseFile,
        cipher: testDatabaseCipher,
      );
      expect(await repository.listAssetGcQuarantines(), isEmpty);
    },
  );

  test(
    'asset GC lease fences another repository until release or expiry',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'asset_gc_lease_test_',
      );
      final databaseFile = File('${root.path}/assets.sqlite');
      final first = ChatDatabaseRepository.open(
        file: databaseFile,
        cipher: testDatabaseCipher,
      );
      final second = ChatDatabaseRepository.open(
        file: databaseFile,
        cipher: testDatabaseCipher,
      );
      addTearDown(() async {
        await first.close();
        await second.close();
        await root.delete(recursive: true);
      });
      final now = DateTime.utc(2026, 7, 19, 12);
      const leaseDuration = Duration(minutes: 2);

      final firstLease = await first.tryAcquireAssetGcLease(
        ownerToken: 'first-owner',
        now: now,
        leaseDuration: leaseDuration,
      );
      expect(firstLease.acquired, isTrue);

      final blockedLease = await second.tryAcquireAssetGcLease(
        ownerToken: 'second-owner',
        now: now.add(const Duration(seconds: 30)),
        leaseDuration: leaseDuration,
      );
      expect(blockedLease.acquired, isFalse);
      expect(blockedLease.expiresAt, firstLease.expiresAt);

      expect(
        await second.releaseAssetGcLease(ownerToken: 'second-owner'),
        isFalse,
      );
      expect(
        (await second.tryAcquireAssetGcLease(
          ownerToken: 'second-owner',
          now: firstLease.expiresAt.add(const Duration(microseconds: 1)),
          leaseDuration: leaseDuration,
        )).acquired,
        isTrue,
      );
    },
  );
}
