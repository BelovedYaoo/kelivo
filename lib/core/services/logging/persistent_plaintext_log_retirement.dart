import 'dart:io';

import 'package:path/path.dart' as p;

import '../backup/restore_durability.dart';

final class PersistentPlaintextLogRetirement {
  const PersistentPlaintextLogRetirement();

  static final RegExp _rotatedLogNamePattern = RegExp(
    r'^(?:logs|flutter_logs)_\d{4}-\d{2}-\d{2}(?:_[1-9]\d*)?\.txt$',
  );

  Future<void> retire({
    required Directory appDataDirectory,
    RestoreDurability? durability,
  }) async {
    await validatePlaintextStateTopology(appDataDirectory: appDataDirectory);
    final root = await _requireAnchoredDirectory(
      appDataDirectory,
      errorCode: 'plaintext_log_root_unsafe',
    );
    final logsDirectory = Directory(p.join(root.path, 'logs'));
    final logsType = await FileSystemEntity.type(
      logsDirectory.path,
      followLinks: false,
    );
    if (logsType == FileSystemEntityType.notFound) return;
    final artifacts = await logsDirectory.list(followLinks: false).toList();

    artifacts.sort((left, right) => left.path.compareTo(right.path));
    for (final artifact in artifacts) {
      await _requireAnchoredDirectory(
        logsDirectory,
        expectedPath: p.join(root.path, 'logs'),
        errorCode: 'plaintext_log_directory_changed',
      );
      if (await FileSystemEntity.type(artifact.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw StateError('plaintext_log_artifact_changed');
      }
      await File(artifact.path).delete();
      if (await FileSystemEntity.type(artifact.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw StateError('plaintext_log_artifact_retirement');
      }
    }

    final resolvedDurability = durability ?? RestorePlatformDurability();
    await resolvedDurability.syncDirectory(logsDirectory, fullBarrier: true);
    await _requireAnchoredDirectory(
      logsDirectory,
      expectedPath: p.join(root.path, 'logs'),
      errorCode: 'plaintext_log_directory_changed',
    );
    if (!await logsDirectory.list(followLinks: false).isEmpty) {
      throw StateError('plaintext_log_directory_not_empty');
    }
    await logsDirectory.delete();
    await resolvedDurability.syncDirectory(root, fullBarrier: true);
    if (await FileSystemEntity.type(logsDirectory.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('plaintext_log_directory_retirement');
    }
  }

  Future<void> validatePlaintextStateTopology({
    required Directory appDataDirectory,
  }) async {
    final root = await _requireAnchoredDirectory(
      appDataDirectory,
      errorCode: 'plaintext_log_root_unsafe',
    );
    final logsDirectory = Directory(p.join(root.path, 'logs'));
    final logsType = await FileSystemEntity.type(
      logsDirectory.path,
      followLinks: false,
    );
    if (logsType == FileSystemEntityType.notFound) return;
    if (logsType != FileSystemEntityType.directory) {
      throw StateError('plaintext_log_directory_unsafe');
    }
    await _requireAnchoredDirectory(
      logsDirectory,
      expectedPath: p.join(root.path, 'logs'),
      errorCode: 'plaintext_log_directory_unsafe',
    );
    await for (final artifact in logsDirectory.list(followLinks: false)) {
      final type = await FileSystemEntity.type(
        artifact.path,
        followLinks: false,
      );
      final name = p.basename(artifact.path);
      if (type != FileSystemEntityType.file || !_isRetiredLogName(name)) {
        throw StateError('plaintext_log_artifact_unsafe:$name');
      }
    }
  }

  static bool _isRetiredLogName(String name) =>
      name == 'logs.txt' ||
      name == 'flutter_logs.txt' ||
      _rotatedLogNamePattern.hasMatch(name);

  static Future<Directory> _requireAnchoredDirectory(
    Directory directory, {
    String? expectedPath,
    required String errorCode,
  }) async {
    final normalized = p.normalize(p.absolute(directory.path));
    if (await FileSystemEntity.type(normalized, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw StateError(errorCode);
    }
    try {
      final canonical = p.normalize(
        await Directory(normalized).resolveSymbolicLinks(),
      );
      if (!p.equals(canonical, p.normalize(expectedPath ?? normalized))) {
        throw StateError(errorCode);
      }
    } on FileSystemException {
      throw StateError(errorCode);
    }
    return Directory(normalized);
  }
}
