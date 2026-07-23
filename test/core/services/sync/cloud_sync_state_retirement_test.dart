import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/sync/cloud_sync_state_retirement.dart';
import 'package:Kelivo/core/services/sync/sync_codec.dart';
import 'package:Kelivo/core/services/sync/sync_write_executor.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'kelivo_cloud_sync_state_retirement_test_',
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('硬切删除明文同步状态完整文件族并保留账号工作区密文', () async {
    final plaintextArtifacts = <File>[
      for (final suffix in const <String>['.hive', '.hivec', '.lock'])
        File(
          p.join(
            tempDirectory.path,
            '${CloudSyncStateRetirement.legacyBoxName}$suffix',
          ),
        ),
    ];
    for (final artifact in plaintextArtifacts) {
      await artifact.writeAsString('shadow-and-outbox-plaintext');
    }
    final encryptedAccountArtifacts = <File>[
      File(p.join(tempDirectory.path, 'session-v2')),
      File(p.join(tempDirectory.path, 'token-v1-device.bin')),
    ];
    for (final artifact in encryptedAccountArtifacts) {
      await artifact.writeAsString('encrypted-account-record');
    }

    await CloudSyncStateRetirement.discardPlaintextState(
      appDataDirectory: tempDirectory,
    );

    for (final artifact in plaintextArtifacts) {
      expect(await artifact.exists(), isFalse);
    }
    for (final artifact in encryptedAccountArtifacts) {
      expect(await artifact.readAsString(), 'encrypted-account-record');
    }
  });

  test('硬切发现同前缀未知文件时拒绝清理且不触碰任何状态', () async {
    final plaintextArtifact = File(
      p.join(
        tempDirectory.path,
        '${CloudSyncStateRetirement.legacyBoxName}.hive',
      ),
    );
    final unknownArtifact = File(
      p.join(
        tempDirectory.path,
        '${CloudSyncStateRetirement.legacyBoxName}.hive-journal',
      ),
    );
    await plaintextArtifact.writeAsString('shadow-plaintext');
    await unknownArtifact.writeAsString('unknown-topology');

    await expectLater(
      CloudSyncStateRetirement.discardPlaintextState(
        appDataDirectory: tempDirectory,
      ),
      throwsA(isA<StateError>()),
    );

    expect(await plaintextArtifact.readAsString(), 'shadow-plaintext');
    expect(await unknownArtifact.readAsString(), 'unknown-topology');
    expect(
      await File(
        p.join(tempDirectory.path, '.cloud-sync-state-retirement-v1'),
      ).exists(),
      isFalse,
    );
  });

  test('硬切按大小写不敏感前缀识别未知拓扑并拒绝启动', () async {
    final unknownArtifact = File(
      p.join(tempDirectory.path, 'CLOUD_SYNC_STATE_V1.unknown'),
    );
    await unknownArtifact.writeAsString('unknown-topology');

    await expectLater(
      CloudSyncStateRetirement.discardPlaintextState(
        appDataDirectory: tempDirectory,
      ),
      throwsA(isA<StateError>()),
    );

    expect(await unknownArtifact.readAsString(), 'unknown-topology');
  });

  test('硬切在没有旧同步状态时保持幂等且不创建清理标记', () async {
    await CloudSyncStateRetirement.discardPlaintextState(
      appDataDirectory: tempDirectory,
    );
    await CloudSyncStateRetirement.discardPlaintextState(
      appDataDirectory: tempDirectory,
    );

    expect(await tempDirectory.list().toList(), isEmpty);
  });

  test('硬切发现旧同步状态同名目录时拒绝清理', () async {
    final unexpectedDirectory = Directory(
      p.join(
        tempDirectory.path,
        '${CloudSyncStateRetirement.legacyBoxName}.hive',
      ),
    );
    await unexpectedDirectory.create();

    await expectLater(
      CloudSyncStateRetirement.discardPlaintextState(
        appDataDirectory: tempDirectory,
      ),
      throwsA(isA<StateError>()),
    );

    expect(await unexpectedDirectory.exists(), isTrue);
  });

  test('硬切发现旧同步状态符号链接时拒绝跟随和清理', () async {
    final encryptedAccountArtifact = File(
      p.join(tempDirectory.path, 'session-v2'),
    );
    await encryptedAccountArtifact.writeAsString('encrypted-account-record');
    final unexpectedLink = Link(
      p.join(
        tempDirectory.path,
        '${CloudSyncStateRetirement.legacyBoxName}.hive',
      ),
    );
    await unexpectedLink.create(encryptedAccountArtifact.path);

    await expectLater(
      CloudSyncStateRetirement.discardPlaintextState(
        appDataDirectory: tempDirectory,
      ),
      throwsA(isA<StateError>()),
    );

    expect(await unexpectedLink.exists(), isTrue);
    expect(
      await encryptedAccountArtifact.readAsString(),
      'encrypted-account-record',
    );
  });

  test('硬切在清理标记耐久后中断并于下次启动无条件续删', () async {
    final plaintextArtifact = File(
      p.join(
        tempDirectory.path,
        '${CloudSyncStateRetirement.legacyBoxName}.hive',
      ),
    );
    await plaintextArtifact.writeAsString('shadow-plaintext');
    final marker = File(
      p.join(tempDirectory.path, '.cloud-sync-state-retirement-v1'),
    );
    final interruptingDurability = _InterruptAfterMarkerDurability(
      delegate: RestorePlatformDurability(),
      markerPath: marker.path,
      plaintextArtifactPath: plaintextArtifact.path,
    );

    await expectLater(
      CloudSyncStateRetirement.discardPlaintextState(
        appDataDirectory: tempDirectory,
        durability: interruptingDurability,
      ),
      throwsA(isA<StateError>()),
    );

    expect(interruptingDurability.markerWasDurableBeforeInterruption, isTrue);
    expect(await marker.exists(), isTrue);
    expect(await plaintextArtifact.exists(), isTrue);

    await CloudSyncStateRetirement.discardPlaintextState(
      appDataDirectory: tempDirectory,
    );

    expect(await marker.exists(), isFalse);
    expect(await plaintextArtifact.exists(), isFalse);
  });

  test('仅本地写执行器只执行一次写入并返回本地结果', () async {
    const executor = LocalOnlySyncWriteExecutor();
    var writeCount = 0;

    final result = await executor.runLocal(
      key: const SyncEntityKey(entityType: 'chat', entityId: 'chat-1'),
      write: () async {
        writeCount += 1;
        return 'local-result';
      },
    );

    expect(result, 'local-result');
    expect(writeCount, 1);
  });

  test('仅本地批量写不遍历实体键且只执行本地写入', () async {
    const executor = LocalOnlySyncWriteExecutor();
    var writeCount = 0;

    final result = await executor.runLocalBatch(
      keys: _unreadableSyncEntityKeys(),
      write: () async {
        writeCount += 1;
        return 7;
      },
    );

    expect(result, 7);
    expect(writeCount, 1);
  });

  test('仅本地写执行器原样透传写入异常', () async {
    const executor = LocalOnlySyncWriteExecutor();

    await expectLater(
      executor.runLocal<void>(
        key: const SyncEntityKey(entityType: 'chat', entityId: 'chat-error'),
        write: () => throw StateError('local-write-failed'),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'local-write-failed',
        ),
      ),
    );
  });
}

Iterable<SyncEntityKey> _unreadableSyncEntityKeys() sync* {
  throw StateError('仅本地执行器不应读取同步实体键');
}

final class _InterruptAfterMarkerDurability implements RestoreDurability {
  _InterruptAfterMarkerDurability({
    required this.delegate,
    required this.markerPath,
    required this.plaintextArtifactPath,
  });

  final RestoreDurability delegate;
  final String markerPath;
  final String plaintextArtifactPath;
  bool _markerRestricted = false;
  bool _markerSynced = false;
  bool _interrupted = false;
  bool markerWasDurableBeforeInterruption = false;

  @override
  Future<void> restrictDirectory(Directory directory) {
    return delegate.restrictDirectory(directory);
  }

  @override
  Future<void> restrictFile(File file) async {
    await delegate.restrictFile(file);
    if (p.equals(file.path, markerPath)) {
      _markerRestricted = true;
    }
  }

  @override
  Future<void> syncDirectory(
    Directory directory, {
    bool fullBarrier = false,
  }) async {
    await delegate.syncDirectory(directory, fullBarrier: fullBarrier);
    if (!_interrupted &&
        await File(markerPath).exists() &&
        await File(plaintextArtifactPath).exists()) {
      _interrupted = true;
      markerWasDurableBeforeInterruption =
          _markerRestricted && _markerSynced && fullBarrier;
      throw StateError('模拟清理标记持久化后的进程中断');
    }
  }

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) async {
    await delegate.syncFile(file, fullBarrier: fullBarrier);
    if (p.equals(file.path, markerPath) && fullBarrier) {
      _markerSynced = true;
    }
  }

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) {
    return delegate.renameAndSync(source: source, targetPath: targetPath);
  }
}
