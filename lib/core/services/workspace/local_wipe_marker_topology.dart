import 'dart:io';

import 'package:path/path.dart' as p;

enum LocalWipeMarkerArtifactKind {
  revocationRequested,
  revocationConfirmed,
  completion,
  revocationRequestedTemporary,
  revocationConfirmedTemporary,
  completionTemporary,
}

final class LocalWipeMarkerTopologySnapshot {
  LocalWipeMarkerTopologySnapshot(
    Map<LocalWipeMarkerArtifactKind, List<File>> artifacts,
  ) : _artifacts = Map<LocalWipeMarkerArtifactKind, List<File>>.unmodifiable({
        for (final entry in artifacts.entries)
          entry.key: List<File>.unmodifiable(entry.value),
      });

  final Map<LocalWipeMarkerArtifactKind, List<File>> _artifacts;

  bool get isEmpty => _artifacts.isEmpty;

  bool contains(LocalWipeMarkerArtifactKind kind) =>
      _artifacts[kind]?.isNotEmpty ?? false;

  List<File> files(LocalWipeMarkerArtifactKind kind) =>
      _artifacts[kind] ?? const <File>[];
}

abstract final class LocalWipeMarkerTopology {
  static const revocationRequestedMarkerFileName =
      '.kelivo-local-wipe-v2.revocation-requested.json';
  static const revocationConfirmedMarkerFileName =
      '.kelivo-local-wipe-v2.revocation-confirmed.json';
  static const completionMarkerFileName =
      '.kelivo-local-wipe-v2.completed.json';

  // 旧版 marker 不迁移。保留前缀下的任何未知状态都必须阻断业务，
  // 不能被硬切后的新版本静默忽略。
  static const reservedPrefix = '.kelivo-local-wipe-';

  static final RegExp _revocationRequestedTemporaryPattern = RegExp(
    r'^\.kelivo-local-wipe-v2\.revocation-requested\.json\.[0-9]+_[0-9]+_[0-9]+\.tmp$',
  );
  static final RegExp _revocationConfirmedTemporaryPattern = RegExp(
    r'^\.kelivo-local-wipe-v2\.revocation-confirmed\.json\.[0-9]+_[0-9]+_[0-9]+\.tmp$',
  );
  static final RegExp _completionTemporaryPattern = RegExp(
    r'^\.kelivo-local-wipe-v2\.completed\.json\.[0-9]+_[0-9]+_[0-9]+\.tmp$',
  );

  static String markerFileName(LocalWipeMarkerArtifactKind kind) =>
      switch (kind) {
        LocalWipeMarkerArtifactKind.revocationRequested ||
        LocalWipeMarkerArtifactKind.revocationRequestedTemporary =>
          revocationRequestedMarkerFileName,
        LocalWipeMarkerArtifactKind.revocationConfirmed ||
        LocalWipeMarkerArtifactKind.revocationConfirmedTemporary =>
          revocationConfirmedMarkerFileName,
        LocalWipeMarkerArtifactKind.completion ||
        LocalWipeMarkerArtifactKind.completionTemporary =>
          completionMarkerFileName,
      };

  static LocalWipeMarkerArtifactKind? classifyName(String name) {
    if (name == revocationRequestedMarkerFileName) {
      return LocalWipeMarkerArtifactKind.revocationRequested;
    }
    if (name == revocationConfirmedMarkerFileName) {
      return LocalWipeMarkerArtifactKind.revocationConfirmed;
    }
    if (name == completionMarkerFileName) {
      return LocalWipeMarkerArtifactKind.completion;
    }
    if (_revocationRequestedTemporaryPattern.hasMatch(name)) {
      return LocalWipeMarkerArtifactKind.revocationRequestedTemporary;
    }
    if (_revocationConfirmedTemporaryPattern.hasMatch(name)) {
      return LocalWipeMarkerArtifactKind.revocationConfirmedTemporary;
    }
    if (_completionTemporaryPattern.hasMatch(name)) {
      return LocalWipeMarkerArtifactKind.completionTemporary;
    }
    return null;
  }

  static Future<LocalWipeMarkerTopologySnapshot> inspect(
    Directory installationRoot,
  ) async {
    final rootPath = p.normalize(p.absolute(installationRoot.path));
    if (await FileSystemEntity.type(rootPath, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw StateError('local_wipe_marker_root_unsafe');
    }
    final artifacts = <LocalWipeMarkerArtifactKind, List<File>>{};
    await for (final entity in installationRoot.list(followLinks: false)) {
      final entityPath = p.normalize(p.absolute(entity.path));
      final name = p.basename(entityPath);
      if (!name.startsWith(reservedPrefix)) continue;
      if (!p.equals(p.dirname(entityPath), rootPath)) {
        throw StateError('local_wipe_marker_artifact_outside_root');
      }
      final kind = classifyName(name);
      final type = await FileSystemEntity.type(entityPath, followLinks: false);
      if (kind == null || type != FileSystemEntityType.file) {
        throw StateError('local_wipe_marker_topology_unsafe');
      }
      artifacts.putIfAbsent(kind, () => <File>[]).add(File(entityPath));
    }
    for (final files in artifacts.values) {
      files.sort((left, right) => left.path.compareTo(right.path));
    }
    return LocalWipeMarkerTopologySnapshot(artifacts);
  }
}
