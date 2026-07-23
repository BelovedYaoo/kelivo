import 'dart:io';

import 'package:path/path.dart' as p;

import '../backup/restore_durability.dart';

final class CloudSyncStateRetirement {
  CloudSyncStateRetirement._();

  static const legacyBoxName = 'cloud_sync_state_v1';
  static const _artifactSuffixes = <String>['.hive', '.hivec', '.lock'];
  static const _cleanupMarkerFileName = '.cloud-sync-state-retirement-v1';

  static Future<void> validatePlaintextStateTopology({
    required Directory appDataDirectory,
  }) async {
    await _validateDirectoryAndMarker(appDataDirectory);
    await _inspectArtifacts(appDataDirectory);
  }

  static Future<void> discardPlaintextState({
    required Directory appDataDirectory,
    RestoreDurability? durability,
  }) async {
    final resolvedDurability = durability ?? RestorePlatformDurability();
    final (cleanupMarker, markerType) = await _validateDirectoryAndMarker(
      appDataDirectory,
    );
    final initialArtifacts = await _inspectArtifacts(appDataDirectory);
    if (markerType == FileSystemEntityType.notFound &&
        initialArtifacts.isEmpty) {
      return;
    }
    if (markerType == FileSystemEntityType.notFound) {
      await _createCleanupMarker(
        cleanupMarker,
        directory: appDataDirectory,
        durability: resolvedDurability,
      );
    }

    final artifacts = await _inspectArtifacts(appDataDirectory);
    for (final artifact in artifacts) {
      final type = await FileSystemEntity.type(
        artifact.path,
        followLinks: false,
      );
      if (type != FileSystemEntityType.file) {
        throw StateError(
          'cloud_sync_state_retirement_artifact_type:${artifact.path}',
        );
      }
      await artifact.delete();
    }
    await resolvedDurability.syncDirectory(appDataDirectory, fullBarrier: true);
    final recreatedArtifacts = await _inspectArtifacts(appDataDirectory);
    if (recreatedArtifacts.isNotEmpty) {
      throw StateError(
        'cloud_sync_state_retirement_artifact_recreated:'
        '${recreatedArtifacts.map((artifact) => artifact.path).join(',')}',
      );
    }
    if (await FileSystemEntity.type(cleanupMarker.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError(
        'cloud_sync_state_retirement_marker_type:${cleanupMarker.path}',
      );
    }
    await cleanupMarker.delete();
    await resolvedDurability.syncDirectory(appDataDirectory, fullBarrier: true);
  }

  static Future<(File, FileSystemEntityType)> _validateDirectoryAndMarker(
    Directory appDataDirectory,
  ) async {
    final appDataType = await FileSystemEntity.type(
      appDataDirectory.path,
      followLinks: false,
    );
    if (appDataType != FileSystemEntityType.directory) {
      throw StateError(
        'cloud_sync_state_retirement_directory_type:'
        '${appDataDirectory.path}',
      );
    }

    final cleanupMarker = File(
      p.join(appDataDirectory.path, _cleanupMarkerFileName),
    );
    final markerType = await FileSystemEntity.type(
      cleanupMarker.path,
      followLinks: false,
    );
    if (markerType != FileSystemEntityType.notFound &&
        markerType != FileSystemEntityType.file) {
      throw StateError(
        'cloud_sync_state_retirement_marker_type:${cleanupMarker.path}',
      );
    }
    return (cleanupMarker, markerType);
  }

  static Future<List<File>> _inspectArtifacts(
    Directory appDataDirectory,
  ) async {
    final artifactNames = <String>{
      for (final suffix in _artifactSuffixes) '$legacyBoxName$suffix',
    };
    final artifacts = <File>[];
    await for (final entity in appDataDirectory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (!name.toLowerCase().startsWith(legacyBoxName.toLowerCase())) {
        continue;
      }
      if (!artifactNames.contains(name)) {
        throw StateError(
          'cloud_sync_state_retirement_unknown_topology:${entity.path}',
        );
      }
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type != FileSystemEntityType.file) {
        throw StateError(
          'cloud_sync_state_retirement_artifact_type:${entity.path}',
        );
      }
      artifacts.add(File(entity.path));
    }
    artifacts.sort((left, right) => left.path.compareTo(right.path));
    return artifacts;
  }

  static Future<void> _createCleanupMarker(
    File marker, {
    required Directory directory,
    required RestoreDurability durability,
  }) async {
    await marker.create(exclusive: true);
    await durability.restrictFile(marker);
    await marker.writeAsString('1\n', flush: true);
    await durability.syncFile(marker, fullBarrier: true);
    await durability.syncDirectory(directory, fullBarrier: true);
  }
}
