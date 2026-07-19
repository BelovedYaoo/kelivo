import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/services/database_v2_rollout_ledger.dart';
import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';
import 'package:Kelivo/core/services/storage/storage_usage_service.dart';
import 'package:Kelivo/utils/app_directories.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getApplicationCachePath() async => p.join(path, 'cache');

  @override
  Future<String?> getTemporaryPath() async => p.join(path, 'tmp');
}

Future<void> _writeSizedFile(Directory root, String name, int size) async {
  final file = File(p.join(root.path, name));
  await file.writeAsBytes(List<int>.filled(size, 1), flush: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform previousPathProvider;

  setUp(() async {
    final testRoot = Directory(
      p.join(Directory.current.path, '.dart_tool', 'storage_usage_tests'),
    );
    await testRoot.create(recursive: true);
    tempDir = await testRoot.createTemp('kelivo_storage_usage_test_');
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    AppDirectories.bindWorkspaceRoot(tempDir, accountWorkspace: false);
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPathProvider;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'chat records size uses SQLite files instead of legacy Hive files',
    () async {
      await _writeSizedFile(tempDir, AppDatabase.databaseFileName, 11);
      await _writeSizedFile(tempDir, '${AppDatabase.databaseFileName}-wal', 7);
      await _writeSizedFile(tempDir, '${AppDatabase.databaseFileName}-shm', 5);
      await _writeSizedFile(tempDir, 'conversations.hive', 100);
      await _writeSizedFile(tempDir, 'messages.hive', 200);
      await _writeSizedFile(tempDir, 'tool_events_v1.hive', 300);
      await _writeSizedFile(tempDir, 'messages.lock', 400);

      final report = await StorageUsageService.computeReport();
      final chat = report.categories.singleWhere(
        (category) => category.key == StorageUsageCategoryKey.chatData,
      );

      expect(chat.stats.bytes, 23);
      expect(chat.stats.fileCount, 3);
      expect(
        chat.subcategories.map((subcategory) => subcategory.id),
        containsAllInOrder(['sqlite_database', 'sqlite_wal', 'sqlite_shm']),
      );
      expect(
        chat.subcategories.map((subcategory) => p.basename(subcategory.path!)),
        containsAllInOrder([
          AppDatabase.databaseFileName,
          '${AppDatabase.databaseFileName}-wal',
          '${AppDatabase.databaseFileName}-shm',
        ]),
      );
      expect(report.totalBytes, 1023);
      expect(
        report.categories.where(
          (category) => category.key == StorageUsageCategoryKey.legacyChatData,
        ),
        isEmpty,
      );
    },
  );

  test('匿名工作区统计不包含账号工作区文件', () async {
    await _writeSizedFile(tempDir, AppDatabase.databaseFileName, 11);
    final accountData = Directory(
      p.join(
        tempDir.path,
        '.kelivo-workspaces',
        'accounts',
        List<String>.filled(64, 'a').join(),
        'data',
      ),
    );
    await accountData.create(recursive: true);
    await _writeSizedFile(accountData, AppDatabase.databaseFileName, 97);

    final report = await StorageUsageService.computeReport();

    expect(report.totalBytes, 11);
    expect(report.totalFiles, 1);
  });

  test(
    'migrated legacy chat data is clearable and disappears after cleanup',
    () async {
      await DatabaseV2RolloutLedger(tempDir).recordMigrationCompleted(
        migrationRunId: 'hive-0123456789abcdef0123456789abcdef',
        sourceKind: 'hive',
        sourceHash: List.filled(64, 'a').join(),
        migratedAtUtc: DateTime.utc(2026, 7, 12),
        conversationCount: 2,
        messageCount: 4,
        issueCounts: const {},
      );
      await _writeSizedFile(tempDir, 'conversations.hive', 100);
      await _writeSizedFile(tempDir, 'messages.hive', 200);
      await _writeSizedFile(tempDir, 'tool_events_v1.hive', 300);

      final before = await StorageUsageService.computeReport();
      final legacy = before.categories.singleWhere(
        (category) => category.key == StorageUsageCategoryKey.legacyChatData,
      );
      expect(legacy.stats.bytes, 600);
      expect(legacy.stats.fileCount, 3);
      expect(before.clearable.bytes, greaterThanOrEqualTo(600));

      await StorageUsageService.clearLegacyChatData();
      final after = await StorageUsageService.computeReport();

      expect(
        after.categories.where(
          (category) => category.key == StorageUsageCategoryKey.legacyChatData,
        ),
        isEmpty,
      );
    },
  );

  test(
    'chat records size works when only the main SQLite database exists',
    () async {
      await _writeSizedFile(tempDir, AppDatabase.databaseFileName, 19);

      final report = await StorageUsageService.computeReport();
      final chat = report.categories.singleWhere(
        (category) => category.key == StorageUsageCategoryKey.chatData,
      );

      expect(chat.stats.bytes, 19);
      expect(chat.stats.fileCount, 1);
      expect(chat.subcategories.single.id, 'sqlite_database');
      expect(
        p.basename(chat.subcategories.single.path!),
        AppDatabase.databaseFileName,
      );
    },
  );

  test('completed restore traces are clearable and then disappear', () async {
    const runId = '0123456789abcdef0123456789abcdef';
    final run = Directory(
      p.join(
        tempDir.path,
        RestoreWorkspaceLock.workspaceRootName,
        RestoreWorkspaceLock.completedRunsDirectoryName,
        'run_$runId',
      ),
    );
    await run.create(recursive: true);
    await _writeSizedFile(run, 'database.sqlite', 64);

    final before = await StorageUsageService.computeReport();
    final traces = before.categories.singleWhere(
      (category) => category.key == StorageUsageCategoryKey.restoreTraces,
    );
    expect(traces.stats.bytes, 64);
    expect(traces.stats.fileCount, 1);

    await StorageUsageService.clearRestoreTraces();
    final after = await StorageUsageService.computeReport();
    expect(
      after.categories.where(
        (category) => category.key == StorageUsageCategoryKey.restoreTraces,
      ),
      isEmpty,
    );
  });

  test('restore traces stay hidden while a restore run is active', () async {
    const runId = '0123456789abcdef0123456789abcdef';
    final workspace = Directory(
      p.join(tempDir.path, RestoreWorkspaceLock.workspaceRootName),
    );
    final completedRun = Directory(
      p.join(
        workspace.path,
        RestoreWorkspaceLock.completedRunsDirectoryName,
        'run_$runId',
      ),
    );
    await completedRun.create(recursive: true);
    await _writeSizedFile(completedRun, 'settings.json', 64);
    await File(
      p.join(workspace.path, RestoreWorkspaceLock.activeRunFileName),
    ).writeAsString(runId);

    final report = await StorageUsageService.computeReport();
    expect(
      report.categories.where(
        (category) => category.key == StorageUsageCategoryKey.restoreTraces,
      ),
      isEmpty,
    );
  });

  test('账号工作区清理其他缓存时保留头像与系统缓存', () async {
    AppDirectories.bindWorkspaceRoot(tempDir, accountWorkspace: true);
    final cacheDir = Directory(p.join(tempDir.path, 'cache'));
    final avatarCacheDir = Directory(p.join(cacheDir.path, 'avatars'));
    final systemCacheDir = Directory(p.join(cacheDir.path, 'system'));
    final otherCacheDir = Directory(p.join(cacheDir.path, 'responses'));
    await avatarCacheDir.create(recursive: true);
    await systemCacheDir.create(recursive: true);
    await otherCacheDir.create(recursive: true);
    await _writeSizedFile(avatarCacheDir, 'avatar.png', 3);
    await _writeSizedFile(systemCacheDir, 'engine.bin', 5);
    await _writeSizedFile(otherCacheDir, 'response.bin', 7);

    await StorageUsageService.clearOtherCache();

    expect(
      File(p.join(avatarCacheDir.path, 'avatar.png')).existsSync(),
      isTrue,
    );
    expect(
      File(p.join(systemCacheDir.path, 'engine.bin')).existsSync(),
      isTrue,
    );
    expect(otherCacheDir.existsSync(), isFalse);
  });
}
