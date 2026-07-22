import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../database/database_cipher.dart';
import 'restore_durability.dart';

/// 在描述关闭的活动 SQLite 数据库，或将其重命名进上一版数据包前，
/// 先让数据库成为自包含状态。
final class RestoreLiveDatabase {
  RestoreLiveDatabase._();

  static const _sidecarSuffixes = ['-wal', '-shm', '-journal'];

  /// 完整数据库文件族不存在时返回 false。
  static Future<bool> normalize({
    required File databaseFile,
    required DatabaseCipher cipher,
    RestoreDurability? durability,
  }) async {
    final resolvedDurability = durability ?? RestorePlatformDurability();
    final databaseType = await FileSystemEntity.type(
      databaseFile.path,
      followLinks: false,
    );
    final sidecars = <File>[];
    for (final suffix in _sidecarSuffixes) {
      final sidecar = File('${databaseFile.path}$suffix');
      final type = await FileSystemEntity.type(
        sidecar.path,
        followLinks: false,
      );
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.file) {
        throw StateError('restore_live_database_sidecar_type:$suffix');
      }
      sidecars.add(sidecar);
    }
    if (databaseType == FileSystemEntityType.notFound) {
      if (sidecars.isNotEmpty) {
        throw StateError('restore_live_database_orphan_sidecar');
      }
      return false;
    }
    if (databaseType != FileSystemEntityType.file) {
      throw StateError('restore_live_database_type');
    }

    final database = sqlite.sqlite3.open(databaseFile.absolute.path);
    try {
      cipher.apply(database, createSlotIfMissing: false);
      database.execute('PRAGMA busy_timeout = 5000;');
      final checkpoint = database.select('PRAGMA wal_checkpoint(TRUNCATE);');
      if (checkpoint.length != 1 ||
          checkpoint.single['busy'] != 0 ||
          checkpoint.single['log'] != checkpoint.single['checkpointed']) {
        throw StateError('restore_live_database_checkpoint');
      }
      final journalMode = database.select('PRAGMA journal_mode = DELETE;');
      if (journalMode.length != 1 ||
          journalMode.single.values.single.toString().toLowerCase() !=
              'delete') {
        throw StateError('restore_live_database_journal_mode');
      }
    } finally {
      database.close();
    }

    for (final suffix in _sidecarSuffixes) {
      if (await FileSystemEntity.type(
            '${databaseFile.path}$suffix',
            followLinks: false,
          ) !=
          FileSystemEntityType.notFound) {
        throw StateError('restore_live_database_sidecar_remains:$suffix');
      }
    }
    await resolvedDurability.syncFile(databaseFile, fullBarrier: true);
    await resolvedDurability.syncDirectory(
      databaseFile.parent,
      fullBarrier: true,
    );
    return true;
  }
}
