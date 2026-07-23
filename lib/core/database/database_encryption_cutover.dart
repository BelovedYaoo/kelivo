import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../services/backup/restore_durability.dart';
import '../services/backup/restore_workspace_lock.dart';
import '../services/legacy_data_retirement_service.dart';
import 'app_database.dart';
import 'database_installation_gate.dart';

final class DatabaseEncryptionCutover {
  DatabaseEncryptionCutover._();

  static final List<int> _plaintextHeader = ascii.encode(
    'SQLite format 3\u0000',
  );
  static const _databaseSidecarSuffixes = ['-wal', '-shm', '-journal', ''];
  static const _cleanupMarkerFileName = '.database-encryption-cutover-v1';

  static Future<void> validatePlaintextStateTopology({
    required Directory appDataDirectory,
  }) async {
    if (await FileSystemEntity.type(
          appDataDirectory.path,
          followLinks: false,
        ) !=
        FileSystemEntityType.directory) {
      throw StateError('database_encryption_cutover_directory_type');
    }
    final legacyRetirement = LegacyDataRetirementService(appDataDirectory);
    await legacyRetirement.inspectHiveArtifacts();
    await legacyRetirement.readReceipt();
    await _validateOptionalFile(
      File(p.join(appDataDirectory.path, _cleanupMarkerFileName)),
      errorCode: 'database_encryption_cutover_marker_type',
    );
    await _validateDatabaseFamily(
      File(p.join(appDataDirectory.path, AppDatabase.databaseFileName)),
    );
    await _validateInstallationReceiptTopology(appDataDirectory);

    final workspaceLock = RestoreWorkspaceLock(
      appDataDirectory: appDataDirectory,
    );
    final workspaceType = await FileSystemEntity.type(
      workspaceLock.workspaceRoot.path,
      followLinks: false,
    );
    if (workspaceType == FileSystemEntityType.notFound) return;
    if (workspaceType != FileSystemEntityType.directory) {
      throw StateError('database_encryption_cutover_workspace_type');
    }
    await _validateOptionalFile(
      File(
        p.join(
          workspaceLock.workspaceRoot.path,
          RestoreWorkspaceLock.lockFileName,
        ),
      ),
      errorCode: 'database_encryption_cutover_workspace_entry',
    );
    await _validateOptionalFile(
      File(p.join(workspaceLock.workspaceRoot.path, _cleanupMarkerFileName)),
      errorCode: 'database_encryption_cutover_marker_type',
    );
    await _validateRegularDirectoryTree(workspaceLock.workspaceRoot);
  }

  static Future<void> discardPlaintextState({
    required Directory appDataDirectory,
    RestoreDurability? durability,
  }) async {
    await validatePlaintextStateTopology(appDataDirectory: appDataDirectory);
    final resolvedDurability = durability ?? RestorePlatformDurability();
    await LegacyDataRetirementService(
      appDataDirectory,
      durability: resolvedDurability,
    ).retireHiveArtifacts();
    final databaseFile = File(
      p.join(appDataDirectory.path, AppDatabase.databaseFileName),
    );
    await _discardPlaintextDatabase(
      appDataDirectory: appDataDirectory,
      databaseFile: databaseFile,
      durability: resolvedDurability,
    );

    final workspaceLock = RestoreWorkspaceLock(
      appDataDirectory: appDataDirectory,
      durability: resolvedDurability,
    );
    final workspaceType = await FileSystemEntity.type(
      workspaceLock.workspaceRoot.path,
      followLinks: false,
    );
    if (workspaceType == FileSystemEntityType.notFound) return;
    if (workspaceType != FileSystemEntityType.directory) {
      throw StateError('database_encryption_cutover_workspace_type');
    }
    await workspaceLock.synchronized(() async {
      final cleanupMarker = File(
        p.join(workspaceLock.workspaceRoot.path, _cleanupMarkerFileName),
      );
      final markerType = await FileSystemEntity.type(
        cleanupMarker.path,
        followLinks: false,
      );
      if (markerType != FileSystemEntityType.notFound &&
          markerType != FileSystemEntityType.file) {
        throw StateError('database_encryption_cutover_marker_type');
      }
      final cleanupInProgress = markerType == FileSystemEntityType.file;
      if (!cleanupInProgress &&
          !await _containsPlaintextDatabase(workspaceLock.workspaceRoot)) {
        return;
      }
      if (!cleanupInProgress) {
        await _createCleanupMarker(
          cleanupMarker,
          directory: workspaceLock.workspaceRoot,
          durability: resolvedDurability,
        );
      }
      await _deleteWorkspaceContents(workspaceLock);
      await resolvedDurability.syncDirectory(
        workspaceLock.workspaceRoot,
        fullBarrier: true,
      );
      await cleanupMarker.delete();
      await resolvedDurability.syncDirectory(
        workspaceLock.workspaceRoot,
        fullBarrier: true,
      );
    });
  }

  static Future<void> _discardPlaintextDatabase({
    required Directory appDataDirectory,
    required File databaseFile,
    required RestoreDurability durability,
  }) async {
    final cleanupMarker = File(
      p.join(appDataDirectory.path, _cleanupMarkerFileName),
    );
    final markerType = await FileSystemEntity.type(
      cleanupMarker.path,
      followLinks: false,
    );
    if (markerType != FileSystemEntityType.notFound &&
        markerType != FileSystemEntityType.file) {
      throw StateError('database_encryption_cutover_marker_type');
    }
    final cleanupInProgress = markerType == FileSystemEntityType.file;
    if (!cleanupInProgress && !await _hasPlaintextHeader(databaseFile)) return;

    if (!cleanupInProgress) {
      await _createCleanupMarker(
        cleanupMarker,
        directory: appDataDirectory,
        durability: durability,
      );
    }
    // 标记先于回执和数据库文件持久化，确保断电后的下一次启动
    // 不依赖可能已经消失的明文主库头也能继续清理。
    await DatabaseInstallationGate.discardReceiptsForEncryptionCutover(
      appDataDirectory: appDataDirectory,
      durability: durability,
    );
    await _deleteDatabaseFamily(databaseFile, durability: durability);
    await cleanupMarker.delete();
    await durability.syncDirectory(appDataDirectory, fullBarrier: true);
  }

  static Future<void> _createCleanupMarker(
    File marker, {
    required Directory directory,
    required RestoreDurability durability,
  }) async {
    await marker.writeAsString('1\n', flush: true);
    await durability.restrictFile(marker);
    await durability.syncFile(marker, fullBarrier: true);
    await durability.syncDirectory(directory, fullBarrier: true);
  }

  static Future<bool> _containsPlaintextDatabase(Directory root) async {
    final pending = <Directory>[root];
    while (pending.isNotEmpty) {
      final directory = pending.removeLast();
      await for (final entity in directory.list(followLinks: false)) {
        final type = await FileSystemEntity.type(
          entity.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.directory) {
          pending.add(Directory(entity.path));
          continue;
        }
        if (type != FileSystemEntityType.file) {
          throw StateError('database_encryption_cutover_workspace_entry');
        }
        if (p.basename(entity.path) == AppDatabase.databaseFileName &&
            await _hasPlaintextHeader(File(entity.path))) {
          return true;
        }
      }
    }
    return false;
  }

  static Future<void> _deleteWorkspaceContents(
    RestoreWorkspaceLock workspaceLock,
  ) async {
    await for (final entity in workspaceLock.workspaceRoot.list(
      followLinks: false,
    )) {
      final name = p.basename(entity.path);
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if ((name == RestoreWorkspaceLock.lockFileName ||
              name == _cleanupMarkerFileName) &&
          type == FileSystemEntityType.file) {
        continue;
      }
      if (type == FileSystemEntityType.file) {
        await File(entity.path).delete();
        continue;
      }
      if (type == FileSystemEntityType.directory) {
        await _deleteRegularDirectoryTree(Directory(entity.path));
        continue;
      }
      throw StateError('database_encryption_cutover_workspace_entry');
    }
  }

  static Future<void> _deleteRegularDirectoryTree(Directory directory) async {
    await for (final entity in directory.list(followLinks: false)) {
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type == FileSystemEntityType.file) {
        await File(entity.path).delete();
      } else if (type == FileSystemEntityType.directory) {
        await _deleteRegularDirectoryTree(Directory(entity.path));
      } else {
        throw StateError('database_encryption_cutover_workspace_entry');
      }
    }
    await directory.delete();
  }

  static Future<void> _deleteDatabaseFamily(
    File databaseFile, {
    required RestoreDurability durability,
  }) async {
    final files = <File>[];
    for (final suffix in _databaseSidecarSuffixes) {
      final file = File('${databaseFile.path}$suffix');
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.file) {
        throw StateError('database_encryption_cutover_database_type');
      }
      files.add(file);
    }
    for (final file in files) {
      await file.delete();
    }
    if (files.isNotEmpty) {
      await durability.syncDirectory(databaseFile.parent, fullBarrier: true);
    }
  }

  static Future<void> _validateDatabaseFamily(File databaseFile) async {
    for (final suffix in _databaseSidecarSuffixes) {
      final type = await FileSystemEntity.type(
        '${databaseFile.path}$suffix',
        followLinks: false,
      );
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.file) {
        throw StateError('database_encryption_cutover_database_type');
      }
    }
  }

  static Future<void> _validateInstallationReceiptTopology(
    Directory appDataDirectory,
  ) async {
    await for (final entity in appDataDirectory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final isReceipt =
          name == '.database_installation_receipt.tmp' ||
          (name.startsWith('database_installation_receipt_') &&
              name.endsWith('.json'));
      if (!isReceipt) continue;
      if (await FileSystemEntity.type(entity.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw StateError('database_installation_receipt_type');
      }
    }
  }

  static Future<void> _validateOptionalFile(
    File file, {
    required String errorCode,
  }) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.file) {
      throw StateError(errorCode);
    }
  }

  static Future<void> _validateRegularDirectoryTree(Directory directory) async {
    await for (final entity in directory.list(followLinks: false)) {
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type == FileSystemEntityType.file) continue;
      if (type == FileSystemEntityType.directory) {
        await _validateRegularDirectoryTree(Directory(entity.path));
        continue;
      }
      throw StateError('database_encryption_cutover_workspace_entry');
    }
  }

  static Future<bool> _hasPlaintextHeader(File file) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      return false;
    }
    if (await file.length() < _plaintextHeader.length) return false;
    final input = await file.open();
    try {
      final header = await input.read(_plaintextHeader.length);
      if (header.length != _plaintextHeader.length) return false;
      for (var index = 0; index < _plaintextHeader.length; index++) {
        if (header[index] != _plaintextHeader[index]) return false;
      }
      return true;
    } finally {
      await input.close();
    }
  }
}
