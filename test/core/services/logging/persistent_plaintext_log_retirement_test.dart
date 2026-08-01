import 'dart:io';

import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/logging/persistent_plaintext_log_retirement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('旧请求与运行日志在业务启动前被完整退役', () async {
    final appDataDirectory = await Directory.systemTemp.createTemp(
      'kelivo_plaintext_log_retirement_',
    );
    addTearDown(() async {
      if (await appDataDirectory.exists()) {
        await appDataDirectory.delete(recursive: true);
      }
    });
    final logsDirectory = Directory(p.join(appDataDirectory.path, 'logs'));
    await logsDirectory.create();
    for (final name in <String>[
      'logs.txt',
      'logs_2026-07-31.txt',
      'logs_2026-07-31_1.txt',
      'flutter_logs.txt',
      'flutter_logs_2026-07-31.txt',
      'flutter_logs_2026-07-31_2.txt',
    ]) {
      await File(p.join(logsDirectory.path, name)).writeAsString(
        'Authorization: Bearer secret\nchat plaintext',
        flush: true,
      );
    }
    final unrelated = File(p.join(appDataDirectory.path, 'unrelated.txt'));
    await unrelated.writeAsString('kept', flush: true);

    await const PersistentPlaintextLogRetirement().retire(
      appDataDirectory: appDataDirectory,
    );

    expect(await logsDirectory.exists(), isFalse);
    expect(await unrelated.readAsString(), 'kept');
  });

  test('日志目录缺失或为空时重复退役保持幂等', () async {
    final appDataDirectory = await Directory.systemTemp.createTemp(
      'kelivo_plaintext_log_empty_',
    );
    addTearDown(() async {
      if (await appDataDirectory.exists()) {
        await appDataDirectory.delete(recursive: true);
      }
    });
    const retirement = PersistentPlaintextLogRetirement();

    await retirement.retire(appDataDirectory: appDataDirectory);
    final logsDirectory = Directory(p.join(appDataDirectory.path, 'logs'));
    await logsDirectory.create();
    await retirement.retire(appDataDirectory: appDataDirectory);
    await retirement.retire(appDataDirectory: appDataDirectory);

    expect(await logsDirectory.exists(), isFalse);
  });

  test('未知日志条目在任何删除前阻止整批退役', () async {
    final appDataDirectory = await Directory.systemTemp.createTemp(
      'kelivo_plaintext_log_unknown_',
    );
    addTearDown(() async {
      if (await appDataDirectory.exists()) {
        await appDataDirectory.delete(recursive: true);
      }
    });
    final logsDirectory = Directory(p.join(appDataDirectory.path, 'logs'));
    await logsDirectory.create();
    final known = File(p.join(logsDirectory.path, 'logs.txt'));
    final unknown = File(p.join(logsDirectory.path, 'conversation-export.txt'));
    await known.writeAsString('secret', flush: true);
    await unknown.writeAsString('user-owned', flush: true);

    await expectLater(
      const PersistentPlaintextLogRetirement().retire(
        appDataDirectory: appDataDirectory,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'plaintext_log_artifact_unsafe:conversation-export.txt',
        ),
      ),
    );

    expect(await known.readAsString(), 'secret');
    expect(await unknown.readAsString(), 'user-owned');
  });

  test('日志路径不是受控目录时失败关闭', () async {
    final appDataDirectory = await Directory.systemTemp.createTemp(
      'kelivo_plaintext_log_invalid_root_',
    );
    addTearDown(() async {
      if (await appDataDirectory.exists()) {
        await appDataDirectory.delete(recursive: true);
      }
    });
    final invalidLogs = File(p.join(appDataDirectory.path, 'logs'));
    await invalidLogs.writeAsString('must-not-delete', flush: true);

    await expectLater(
      const PersistentPlaintextLogRetirement().retire(
        appDataDirectory: appDataDirectory,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'plaintext_log_directory_unsafe',
        ),
      ),
    );

    expect(await invalidLogs.readAsString(), 'must-not-delete');
  });

  test('耐久屏障失败会阻断启动且下次退役继续收敛', () async {
    final appDataDirectory = await Directory.systemTemp.createTemp(
      'kelivo_plaintext_log_durability_',
    );
    addTearDown(() async {
      if (await appDataDirectory.exists()) {
        await appDataDirectory.delete(recursive: true);
      }
    });
    final logsDirectory = Directory(p.join(appDataDirectory.path, 'logs'));
    await logsDirectory.create();
    await File(
      p.join(logsDirectory.path, 'flutter_logs.txt'),
    ).writeAsString('uncaught secret', flush: true);

    await expectLater(
      const PersistentPlaintextLogRetirement().retire(
        appDataDirectory: appDataDirectory,
        durability: const _FailingDirectorySyncDurability(),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'test_directory_sync_failure',
        ),
      ),
    );
    expect(await logsDirectory.exists(), isTrue);

    await const PersistentPlaintextLogRetirement().retire(
      appDataDirectory: appDataDirectory,
    );
    expect(await logsDirectory.exists(), isFalse);
  });
}

final class _FailingDirectorySyncDurability implements RestoreDurability {
  const _FailingDirectorySyncDurability();

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) => throw UnimplementedError();

  @override
  Future<void> restrictDirectory(Directory directory) =>
      throw UnimplementedError();

  @override
  Future<void> restrictFile(File file) => throw UnimplementedError();

  @override
  Future<void> syncDirectory(Directory directory, {bool fullBarrier = false}) =>
      throw StateError('test_directory_sync_failure');

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) =>
      throw UnimplementedError();
}
