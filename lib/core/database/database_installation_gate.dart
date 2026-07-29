import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../services/backup/restore_durability.dart';
import 'app_database.dart';
import 'chat_database_repository.dart';
import 'database_cipher.dart';

final class DatabaseInstallationReceipt {
  const DatabaseInstallationReceipt({
    required this.installationId,
    required this.databaseId,
    required this.attachmentStagingCutoverVersion,
  });

  static const formatVersion = 2;
  static const currentAttachmentStagingCutoverVersion = 23;

  final String installationId;
  final String databaseId;
  final int attachmentStagingCutoverVersion;

  Map<String, Object> toJson() => {
    'version': formatVersion,
    'installationId': installationId,
    'databaseId': databaseId,
    'attachmentStagingCutoverVersion': attachmentStagingCutoverVersion,
  };

  static DatabaseInstallationReceipt fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value.length != 4 ||
        value['version'] != formatVersion ||
        value['installationId'] is! String ||
        value['databaseId'] is! String ||
        value['attachmentStagingCutoverVersion'] !=
            currentAttachmentStagingCutoverVersion) {
      throw const FormatException('database_installation_receipt');
    }
    final receipt = DatabaseInstallationReceipt(
      installationId: value['installationId'] as String,
      databaseId: value['databaseId'] as String,
      attachmentStagingCutoverVersion:
          value['attachmentStagingCutoverVersion'] as int,
    );
    if (!_isUuid(receipt.installationId) || !_isUuid(receipt.databaseId)) {
      throw const FormatException('database_installation_receipt');
    }
    return receipt;
  }
}

final class DatabaseInstallationGate {
  DatabaseInstallationGate._();

  static const _receiptPrefix = 'database_installation_receipt_';
  static const _receiptSuffix = '.json';
  static const _temporaryFileName = '.database_installation_receipt.tmp';
  static const _maximumReceiptBytes = 4096;

  static Future<DatabaseInstallationReceipt> ensureReady({
    required Directory appDataDirectory,
    required DatabaseCipher cipher,
    bool allowDatabaseIdentityChange = false,
    RestoreDurability? durability,
  }) async {
    final resolvedDurability = durability ?? RestorePlatformDurability();
    await appDataDirectory.create(recursive: true);
    final databaseFile = File(
      p.join(appDataDirectory.path, AppDatabase.databaseFileName),
    );
    final receiptFiles = await _listReceiptFiles(appDataDirectory);
    var receipts = const <({File file, DatabaseInstallationReceipt receipt})>[];
    final databaseType = await FileSystemEntity.type(
      databaseFile.path,
      followLinks: false,
    );
    if (receiptFiles.isNotEmpty &&
        databaseType == FileSystemEntityType.notFound) {
      throw StateError('database_missing');
    }
    if (databaseType != FileSystemEntityType.notFound &&
        databaseType != FileSystemEntityType.file) {
      throw StateError('database_type');
    }

    late InstalledChatDatabaseInfo info;
    try {
      if (databaseType == FileSystemEntityType.notFound) {
        final repository = ChatDatabaseRepository.open(
          file: databaseFile,
          cipher: cipher,
        );
        try {
          await repository.ensureReady();
        } finally {
          await repository.close();
        }
      } else {
        final requiresHardCut =
            ChatDatabaseRepository.requiresInstalledDatabaseHardCut(
              databaseFile,
              cipher: cipher,
            );
        if (requiresHardCut) {
          await _discardObsoleteDatabase(
            appDataDirectory: appDataDirectory,
            databaseFile: databaseFile,
            durability: resolvedDurability,
          );
          final repository = ChatDatabaseRepository.open(
            file: databaseFile,
            cipher: cipher,
          );
          try {
            await repository.ensureReady();
          } finally {
            await repository.close();
          }
        } else {
          receipts = await _readReceiptFiles(receiptFiles);
        }
      }

      info = ChatDatabaseRepository.inspectInstalledDatabase(
        databaseFile,
        cipher: cipher,
      );
    } catch (_) {
      rethrow;
    }
    if (info.databaseId == null) {
      if (receipts.isNotEmpty) {
        if (!allowDatabaseIdentityChange) {
          throw StateError('database_identity_missing');
        }
      }
      final databaseId = const Uuid().v4();
      ChatDatabaseRepository.assignInstalledDatabaseIdentity(
        databaseFile,
        databaseId,
        cipher: cipher,
      );
      info = ChatDatabaseRepository.inspectInstalledDatabase(
        databaseFile,
        cipher: cipher,
      );
    }
    final databaseId = info.databaseId!;
    final matching = receipts
        .where((entry) => entry.receipt.databaseId == databaseId)
        .toList(growable: false);
    if (matching.length > 1) {
      throw StateError('database_installation_receipt_duplicate');
    }
    if (matching.length == 1) {
      await _removeStaleReceipts(
        receipts.where((entry) => entry.file.path != matching.single.file.path),
        durability: resolvedDurability,
      );
      return matching.single.receipt;
    }
    if (receipts.isNotEmpty) {
      if (!allowDatabaseIdentityChange) {
        throw StateError('database_identity_mismatch');
      }
    }
    final installationIds = receipts
        .map((entry) => entry.receipt.installationId)
        .toSet();
    if (installationIds.length > 1) {
      throw StateError('database_installation_identity_mismatch');
    }
    await _discardObsoleteAttachmentStaging(
      appDataDirectory: appDataDirectory,
      durability: resolvedDurability,
    );
    final updated = DatabaseInstallationReceipt(
      installationId: installationIds.firstOrNull ?? const Uuid().v4(),
      databaseId: databaseId,
      attachmentStagingCutoverVersion:
          DatabaseInstallationReceipt.currentAttachmentStagingCutoverVersion,
    );
    final receiptFile = File(
      p.join(
        appDataDirectory.path,
        '$_receiptPrefix${updated.databaseId}$_receiptSuffix',
      ),
    );
    await _publishReceipt(receiptFile, updated, durability: resolvedDurability);
    await _removeStaleReceipts(receipts, durability: resolvedDurability);
    return updated;
  }

  static Future<DatabaseInstallationReceipt?> read({
    required Directory appDataDirectory,
    required DatabaseCipher cipher,
  }) async {
    final receipts = await _readReceipts(appDataDirectory);
    if (receipts.isEmpty) return null;
    final databaseFile = File(
      p.join(appDataDirectory.path, AppDatabase.databaseFileName),
    );
    if (!await databaseFile.exists()) throw StateError('database_missing');
    final databaseId = ChatDatabaseRepository.inspectInstalledDatabase(
      databaseFile,
      cipher: cipher,
    ).databaseId;
    final matching = receipts
        .where((entry) => entry.receipt.databaseId == databaseId)
        .toList(growable: false);
    if (matching.length != 1) {
      throw StateError('database_installation_receipt_match');
    }
    return matching.single.receipt;
  }

  static Future<void> discardReceiptsForEncryptionCutover({
    required Directory appDataDirectory,
    required RestoreDurability durability,
  }) async {
    final files = <File>[];
    await for (final entity in appDataDirectory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (name != _temporaryFileName &&
          (!name.startsWith(_receiptPrefix) ||
              !name.endsWith(_receiptSuffix))) {
        continue;
      }
      if (await FileSystemEntity.type(entity.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw StateError('database_installation_receipt_type');
      }
      files.add(File(entity.path));
    }
    for (final file in files) {
      await file.delete();
    }
    if (files.isNotEmpty) {
      await durability.syncDirectory(appDataDirectory, fullBarrier: true);
    }
  }

  static Future<void> _discardObsoleteDatabase({
    required Directory appDataDirectory,
    required File databaseFile,
    required RestoreDurability durability,
  }) async {
    const suffixes = ['-wal', '-shm', '-journal', ''];
    final files = <File>[];
    for (final suffix in suffixes) {
      final file = File('${databaseFile.path}$suffix');
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.file) {
        throw StateError('database_schema_cutover_database_type');
      }
      files.add(file);
    }

    // 先移除回执，再按侧车到主库的顺序删除；任一步中断都能在下次启动重试，
    // 不会留下“回执存在但主库已消失”或“新主库复用旧 WAL”的状态。
    await discardReceiptsForEncryptionCutover(
      appDataDirectory: appDataDirectory,
      durability: durability,
    );
    for (final file in files) {
      await file.delete();
    }
    await durability.syncDirectory(appDataDirectory, fullBarrier: true);
  }

  static Future<void> _discardObsoleteAttachmentStaging({
    required Directory appDataDirectory,
    required RestoreDurability durability,
  }) async {
    final workspaceRoot = p.normalize(p.absolute(appDataDirectory.path));
    final uploadDirectory = Directory(p.join(workspaceRoot, 'upload'));
    final ownedRoot = Directory(p.join(uploadDirectory.path, 'e2ee'));
    final stagingRoot = Directory(p.join(ownedRoot.path, 'staging'));
    if (!p.isWithin(workspaceRoot, stagingRoot.path)) {
      throw StateError('e2ee_attachment_staging_cutover_path');
    }
    for (final directory in <Directory>[uploadDirectory, ownedRoot]) {
      final type = await FileSystemEntity.type(
        directory.path,
        followLinks: false,
      );
      if (type == FileSystemEntityType.notFound) return;
      if (type != FileSystemEntityType.directory) {
        throw StateError('e2ee_attachment_staging_cutover_type');
      }
    }
    final stagingType = await FileSystemEntity.type(
      stagingRoot.path,
      followLinks: false,
    );
    if (stagingType == FileSystemEntityType.notFound) return;
    if (stagingType != FileSystemEntityType.directory) {
      throw StateError('e2ee_attachment_staging_cutover_type');
    }
    await _deleteAttachmentStagingDirectory(
      stagingRoot,
      durability: durability,
    );
  }

  static Future<void> _deleteAttachmentStagingDirectory(
    Directory directory, {
    required RestoreDurability durability,
  }) async {
    await for (final entity in directory.list(followLinks: false)) {
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      switch (type) {
        case FileSystemEntityType.file:
          await File(entity.path).delete();
        case FileSystemEntityType.directory:
          await _deleteAttachmentStagingDirectory(
            Directory(entity.path),
            durability: durability,
          );
        case FileSystemEntityType.notFound:
        case FileSystemEntityType.link:
        case FileSystemEntityType.pipe:
        case FileSystemEntityType.unixDomainSock:
          throw StateError('e2ee_attachment_staging_cutover_type');
      }
    }
    await durability.syncDirectory(directory, fullBarrier: true);
    final parent = directory.parent;
    await directory.delete();
    await durability.syncDirectory(parent, fullBarrier: true);
  }

  static Future<List<({File file, DatabaseInstallationReceipt receipt})>>
  _readReceipts(Directory directory) async {
    return _readReceiptFiles(await _listReceiptFiles(directory));
  }

  static Future<List<File>> _listReceiptFiles(Directory directory) async {
    final files = <File>[];
    await for (final entity in directory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (!name.startsWith(_receiptPrefix) || !name.endsWith(_receiptSuffix)) {
        continue;
      }
      if (await FileSystemEntity.type(entity.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw StateError('database_installation_receipt_type');
      }
      files.add(File(entity.path));
    }
    return files;
  }

  static Future<List<({File file, DatabaseInstallationReceipt receipt})>>
  _readReceiptFiles(Iterable<File> files) async {
    final receipts = <({File file, DatabaseInstallationReceipt receipt})>[];
    for (final file in files) {
      final name = p.basename(file.path);
      final receipt = await _readReceipt(file);
      if (name != '$_receiptPrefix${receipt.databaseId}$_receiptSuffix') {
        throw const FormatException('database_installation_receipt_name');
      }
      receipts.add((file: file, receipt: receipt));
    }
    return receipts;
  }

  static Future<void> _removeStaleReceipts(
    Iterable<({File file, DatabaseInstallationReceipt receipt})> entries, {
    required RestoreDurability durability,
  }) async {
    Directory? parent;
    for (final entry in entries) {
      await entry.file.delete();
      parent = entry.file.parent;
    }
    if (parent != null) {
      await durability.syncDirectory(parent, fullBarrier: true);
    }
  }

  static Future<DatabaseInstallationReceipt> _readReceipt(File file) async {
    if (await file.length() > _maximumReceiptBytes) {
      throw const FormatException('database_installation_receipt');
    }
    final decoded = jsonDecode(await file.readAsString());
    return DatabaseInstallationReceipt.fromJson(decoded);
  }

  static Future<void> _publishReceipt(
    File target,
    DatabaseInstallationReceipt receipt, {
    required RestoreDurability durability,
  }) async {
    final temporary = File(p.join(target.parent.path, _temporaryFileName));
    if (await FileSystemEntity.type(temporary.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('database_installation_receipt_temporary');
    }
    try {
      await temporary.create(exclusive: true);
      await durability.restrictFile(temporary);
      await temporary.writeAsString(jsonEncode(receipt.toJson()), flush: true);
      await durability.syncFile(temporary, fullBarrier: true);
      if (await target.exists()) {
        throw StateError('database_installation_receipt_collision');
      }
      await durability.renameAndSync(
        source: temporary,
        targetPath: target.path,
      );
      final published = await _readReceipt(target);
      if (published.installationId != receipt.installationId ||
          published.databaseId != receipt.databaseId) {
        throw StateError('database_installation_receipt_publish');
      }
    } finally {
      if (await FileSystemEntity.type(temporary.path, followLinks: false) ==
          FileSystemEntityType.file) {
        await temporary.delete();
        await durability.syncDirectory(target.parent, fullBarrier: true);
      }
    }
  }
}

bool _isUuid(String value) => RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
).hasMatch(value);
