import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../backup/restore_durability.dart';
import 'local_wipe_marker_topology.dart';

typedef LocalCryptographicWipeStep = Future<void> Function();
typedef LocalInstallationRootWipe =
    Future<void> Function({
      required String rootPath,
      required String preservedEntryName,
    });
typedef _LocalCryptographicWipeRuntime = ({
  bool isSupported,
  Future<Directory> Function() applicationCacheDirectory,
  LocalCryptographicWipeStep deleteAllSecureSlots,
  LocalInstallationRootWipe wipeInstallationRoot,
  LocalCryptographicWipeStep clearAllPreferences,
  LocalCryptographicWipeStep shutdownLogging,
});

enum LocalCryptographicWipePhase {
  revocationRequested,
  revocationConfirmed,
  completion,
}

final class LocalCryptographicWipeIntent {
  const LocalCryptographicWipeIntent({
    required this.phase,
    required this.deviceId,
    required this.mutationId,
    required this.createdAtUtc,
  });

  final LocalCryptographicWipePhase phase;
  final String deviceId;
  final String mutationId;
  final DateTime createdAtUtc;
}

final class LocalDeviceRevocationConfirmationRequired implements Exception {
  const LocalDeviceRevocationConfirmationRequired(this.intent);

  final LocalCryptographicWipeIntent intent;
}

abstract interface class LocalCryptographicWipe {
  bool get isSupported;

  Future<void> markRevocationRequested({
    required String deviceId,
    required String mutationId,
  });

  Future<void> markRevocationConfirmed({
    required String deviceId,
    required String mutationId,
  });

  Future<LocalCryptographicWipeIntent?> readPendingIntent();

  Future<bool> hasPendingWipe();

  Future<bool> resumePendingAtColdStart({
    required LocalCryptographicWipeStep stopBackgroundSync,
  });
}

final class InstallationLocalCryptographicWipe
    implements LocalCryptographicWipe {
  InstallationLocalCryptographicWipe({
    required Directory installationRoot,
    required bool isSupported,
    required Future<Directory> Function() applicationCacheDirectory,
    required LocalCryptographicWipeStep deleteAllSecureSlots,
    required LocalInstallationRootWipe wipeInstallationRoot,
    required LocalCryptographicWipeStep clearAllPreferences,
    required LocalCryptographicWipeStep shutdownLogging,
    RestoreDurability? durability,
    DateTime Function()? utcNow,
  }) : _installationRoot = Directory(
         p.normalize(p.absolute(installationRoot.path)),
       ),
       _runtime = (
         isSupported: isSupported,
         applicationCacheDirectory: applicationCacheDirectory,
         deleteAllSecureSlots: deleteAllSecureSlots,
         wipeInstallationRoot: wipeInstallationRoot,
         clearAllPreferences: clearAllPreferences,
         shutdownLogging: shutdownLogging,
       ),
       _durability = durability ?? RestorePlatformDurability(),
       _utcNow = utcNow ?? DateTime.now;

  static const _markerFormat = 'kelivo.local-cryptographic-wipe';
  static const _markerVersion = 2;
  static const _maximumMarkerBytes = 4096;
  static final RegExp _deviceIdPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  final Directory _installationRoot;
  final _LocalCryptographicWipeRuntime _runtime;
  final RestoreDurability _durability;
  final DateTime Function() _utcNow;

  @override
  bool get isSupported => _runtime.isSupported;

  File get _revocationRequestedMarkerFile => File(
    p.join(
      _installationRoot.path,
      LocalWipeMarkerTopology.revocationRequestedMarkerFileName,
    ),
  );
  File get _revocationConfirmedMarkerFile => File(
    p.join(
      _installationRoot.path,
      LocalWipeMarkerTopology.revocationConfirmedMarkerFileName,
    ),
  );
  File get _completionMarkerFile => File(
    p.join(
      _installationRoot.path,
      LocalWipeMarkerTopology.completionMarkerFileName,
    ),
  );

  @override
  Future<void> markRevocationRequested({
    required String deviceId,
    required String mutationId,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('local_wipe_unsupported');
    }
    _validateIdentity(deviceId: deviceId, mutationId: mutationId);
    await _requireInstallationRoot();
    final existing = await _readPendingState();
    if (existing != null) {
      if (!existing.matches(deviceId: deviceId, mutationId: mutationId)) {
        throw StateError('local_wipe_marker_collision');
      }
      return;
    }

    final marker = _LocalWipeMarker(
      phase: LocalCryptographicWipePhase.revocationRequested,
      deviceId: deviceId,
      mutationId: mutationId,
      createdAtUtc: _utcNow().toUtc(),
    );
    await _publishMarker(marker, target: _revocationRequestedMarkerFile);
  }

  @override
  Future<void> markRevocationConfirmed({
    required String deviceId,
    required String mutationId,
  }) async {
    _validateIdentity(deviceId: deviceId, mutationId: mutationId);
    await _requireInstallationRoot();
    final existing = await _readPendingState();
    if (existing == null ||
        !existing.matches(deviceId: deviceId, mutationId: mutationId)) {
      throw StateError('local_wipe_marker_collision');
    }
    if (existing.phase != LocalCryptographicWipePhase.revocationRequested) {
      return;
    }
    final confirmed = existing.withPhase(
      LocalCryptographicWipePhase.revocationConfirmed,
    );
    await _publishMarker(confirmed, target: _revocationConfirmedMarkerFile);
    await _normalizePublishedMarkers();
  }

  void _validateIdentity({
    required String deviceId,
    required String mutationId,
  }) {
    if (!_deviceIdPattern.hasMatch(deviceId)) {
      throw const FormatException('local_wipe_device_id');
    }
    if (!_deviceIdPattern.hasMatch(mutationId)) {
      throw const FormatException('local_wipe_mutation_id');
    }
  }

  Future<void> _publishMarker(
    _LocalWipeMarker marker, {
    required File target,
  }) async {
    final encoded = utf8.encode(jsonEncode(marker.toJson()));
    if (encoded.length > _maximumMarkerBytes) {
      throw StateError('local_wipe_marker_size');
    }
    final temporary = await _createTemporaryMarker(target);
    await _durability.restrictFile(temporary);
    await temporary.writeAsBytes(encoded, flush: true);
    await _durability.syncFile(temporary, fullBarrier: true);
    final staged = await _readMarkerFile(temporary);
    if (staged != marker) {
      throw StateError('local_wipe_marker_staging');
    }
    await _durability.renameAndSync(source: temporary, targetPath: target.path);
    final published = await _readMarkerFile(target);
    if (published != marker) {
      throw StateError('local_wipe_marker_publish');
    }
  }

  @override
  Future<LocalCryptographicWipeIntent?> readPendingIntent() async {
    if (!await _installationRootExists()) return null;
    await _requireInstallationRoot();
    return (await _readPendingState())?.intent;
  }

  @override
  Future<bool> hasPendingWipe() async {
    return await readPendingIntent() != null;
  }

  @override
  Future<bool> resumePendingAtColdStart({
    required LocalCryptographicWipeStep stopBackgroundSync,
  }) async {
    if (!await _installationRootExists()) return false;
    await _requireInstallationRoot();
    final marker = await _readPendingState();
    if (marker == null) return false;
    if (marker.phase == LocalCryptographicWipePhase.revocationRequested) {
      throw LocalDeviceRevocationConfirmationRequired(marker.intent);
    }
    if (marker.phase == LocalCryptographicWipePhase.completion) {
      await _commitCompletion();
      return true;
    }
    if (!isSupported) {
      throw UnsupportedError('local_wipe_unsupported');
    }

    await stopBackgroundSync();
    await _runtime.shutdownLogging();
    await _runtime.deleteAllSecureSlots();
    await _wipeInstallationContents();
    await _runtime.clearAllPreferences();
    await _wipeInstallationContents();
    await _deleteApplicationCacheContents();
    await _commitCompletion();
    return true;
  }

  Future<void> _requireInstallationRoot() async {
    final type = await FileSystemEntity.type(
      _installationRoot.path,
      followLinks: false,
    );
    if (type != FileSystemEntityType.directory) {
      throw StateError('local_wipe_installation_root_unsafe');
    }
    final canonical = await _canonicalDirectoryPath(_installationRoot);
    if (!p.equals(canonical, _installationRoot.path)) {
      throw StateError('local_wipe_installation_root_unsafe');
    }
  }

  Future<bool> _installationRootExists() async {
    final type = await FileSystemEntity.type(
      _installationRoot.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) return false;
    if (type != FileSystemEntityType.directory) {
      throw StateError('local_wipe_installation_root_unsafe');
    }
    return true;
  }

  Future<_LocalWipeMarker?> _readPendingState() async {
    await _recoverUnpublishedMarkers();
    return _normalizePublishedMarkers();
  }

  Future<void> _recoverUnpublishedMarkers() async {
    final snapshot = await LocalWipeMarkerTopology.inspect(_installationRoot);
    await _recoverTemporaryPhase(
      snapshot: snapshot,
      temporaryKind: LocalWipeMarkerArtifactKind.revocationRequestedTemporary,
      phase: LocalCryptographicWipePhase.revocationRequested,
      target: _revocationRequestedMarkerFile,
      fallback: null,
    );
    final requested = await _readPublishedMarker(
      _revocationRequestedMarkerFile,
      LocalCryptographicWipePhase.revocationRequested,
    );
    await _recoverTemporaryPhase(
      snapshot: snapshot,
      temporaryKind: LocalWipeMarkerArtifactKind.revocationConfirmedTemporary,
      phase: LocalCryptographicWipePhase.revocationConfirmed,
      target: _revocationConfirmedMarkerFile,
      fallback: requested,
    );
    final confirmed = await _readPublishedMarker(
      _revocationConfirmedMarkerFile,
      LocalCryptographicWipePhase.revocationConfirmed,
    );
    await _recoverTemporaryPhase(
      snapshot: snapshot,
      temporaryKind: LocalWipeMarkerArtifactKind.completionTemporary,
      phase: LocalCryptographicWipePhase.completion,
      target: _completionMarkerFile,
      fallback: confirmed,
    );
  }

  Future<void> _recoverTemporaryPhase({
    required LocalWipeMarkerTopologySnapshot snapshot,
    required LocalWipeMarkerArtifactKind temporaryKind,
    required LocalCryptographicWipePhase phase,
    required File target,
    required _LocalWipeMarker? fallback,
  }) async {
    final temporaries = snapshot.files(temporaryKind);
    if (temporaries.isEmpty) return;
    final published = await _readPublishedMarker(target, phase);
    final valid = <({File file, _LocalWipeMarker marker})>[];
    for (final temporary in temporaries) {
      try {
        final marker = await _readMarkerFile(temporary);
        if (marker.phase != phase) {
          throw const FormatException('local_wipe_marker_phase');
        }
        valid.add((file: temporary, marker: marker));
      } on FormatException {
        // confirmed/completion 临时文件只会在上一个耐久 phase 仍保留时
        // 创建，因此可由上一个 marker 恢复；requested 没有此前证据。
      }
    }
    if (published != null) {
      if (valid.any((candidate) => candidate.marker != published)) {
        throw StateError('local_wipe_marker_collision');
      }
      await _deleteTemporaryMarkers(temporaries);
      return;
    }
    if (valid.isNotEmpty) {
      final selected = valid.first;
      if (valid.any((candidate) => candidate.marker != selected.marker) ||
          (fallback != null && !selected.marker.sameIntent(fallback))) {
        throw StateError('local_wipe_marker_collision');
      }
      await _durability.renameAndSync(
        source: selected.file,
        targetPath: target.path,
      );
      if (await _readMarkerFile(target) != selected.marker) {
        throw StateError('local_wipe_marker_publish');
      }
      await _deleteTemporaryMarkers(temporaries);
      return;
    }
    if (fallback == null) {
      throw const FormatException('local_wipe_marker_partial_requested');
    }
    await _publishMarker(fallback.withPhase(phase), target: target);
    await _deleteTemporaryMarkers(temporaries);
  }

  Future<void> _deleteTemporaryMarkers(List<File> temporaries) async {
    for (final temporary in temporaries) {
      final type = await FileSystemEntity.type(
        temporary.path,
        followLinks: false,
      );
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.file) {
        throw StateError('local_wipe_marker_intermediate');
      }
      await temporary.delete();
      await _requireInstallationRoot();
    }
    await _durability.syncDirectory(_installationRoot, fullBarrier: true);
  }

  Future<_LocalWipeMarker?> _readPublishedMarker(
    File source,
    LocalCryptographicWipePhase phase,
  ) async {
    final type = await FileSystemEntity.type(source.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.file) {
      throw const FormatException('local_wipe_marker_file');
    }
    final marker = await _readMarkerFile(source);
    if (marker.phase != phase) {
      throw const FormatException('local_wipe_marker_phase');
    }
    return marker;
  }

  Future<_LocalWipeMarker> _readMarkerFile(File source) async {
    _requireDirectChild(parent: _installationRoot, childPath: source.path);
    if (await FileSystemEntity.type(source.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FormatException('local_wipe_marker_file');
    }
    final length = await source.length();
    if (length <= 0 || length > _maximumMarkerBytes) {
      throw const FormatException('local_wipe_marker_size');
    }
    final bytes = await source.readAsBytes();
    if (bytes.length != length ||
        await FileSystemEntity.type(source.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await source.length() != length) {
      throw const FormatException('local_wipe_marker_changed');
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('local_wipe_marker_json');
      }
      return _LocalWipeMarker.fromJson(decoded);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('local_wipe_marker_json');
    }
  }

  Future<_LocalWipeMarker?> _normalizePublishedMarkers() async {
    var requested = await _readPublishedMarker(
      _revocationRequestedMarkerFile,
      LocalCryptographicWipePhase.revocationRequested,
    );
    var confirmed = await _readPublishedMarker(
      _revocationConfirmedMarkerFile,
      LocalCryptographicWipePhase.revocationConfirmed,
    );
    final completion = await _readPublishedMarker(
      _completionMarkerFile,
      LocalCryptographicWipePhase.completion,
    );
    if (requested != null && completion != null) {
      throw StateError('local_wipe_marker_collision');
    }
    if (requested != null && confirmed != null) {
      if (!requested.sameIntent(confirmed)) {
        throw StateError('local_wipe_marker_collision');
      }
      await _deleteTransitionSource(
        source: _revocationRequestedMarkerFile,
        retained: _revocationConfirmedMarkerFile,
      );
      requested = null;
    }
    if (confirmed != null && completion != null) {
      if (!confirmed.sameIntent(completion)) {
        throw StateError('local_wipe_marker_collision');
      }
      await _deleteTransitionSource(
        source: _revocationConfirmedMarkerFile,
        retained: _completionMarkerFile,
      );
      confirmed = null;
    }
    return requested ?? confirmed ?? completion;
  }

  Future<void> _deleteTransitionSource({
    required File source,
    required File retained,
  }) async {
    await source.delete();
    await _durability.syncDirectory(_installationRoot, fullBarrier: true);
    if (await FileSystemEntity.type(source.path, followLinks: false) !=
            FileSystemEntityType.notFound ||
        await FileSystemEntity.type(retained.path, followLinks: false) !=
            FileSystemEntityType.file) {
      throw StateError('local_wipe_marker_transition');
    }
  }

  Future<File> _createTemporaryMarker(File target) async {
    final targetName = _requireDirectChild(
      parent: _installationRoot,
      childPath: target.path,
    );
    for (var attempt = 0; attempt < 16; attempt++) {
      final temporary = File(
        p.join(
          _installationRoot.path,
          '$targetName.${_utcNow().microsecondsSinceEpoch}_${pid}_$attempt.tmp',
        ),
      );
      try {
        await temporary.create(exclusive: true);
        return temporary;
      } on PathExistsException {
        continue;
      }
    }
    throw StateError('local_wipe_marker_temp_collision');
  }

  Future<void> _wipeInstallationContents() => _runtime.wipeInstallationRoot(
    rootPath: _installationRoot.path,
    preservedEntryName:
        LocalWipeMarkerTopology.revocationConfirmedMarkerFileName,
  );

  Future<void> _requireOnlyMarkersRetained(Set<String> expectedNames) async {
    await _requireInstallationRoot();
    final retained = await _installationRoot.list(followLinks: false).toList();
    final retainedNames = <String>{};
    for (final entity in retained) {
      final name = _requireDirectChild(
        parent: _installationRoot,
        childPath: entity.path,
      );
      if (await FileSystemEntity.type(entity.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw StateError('local_wipe_installation_not_empty');
      }
      retainedNames.add(name);
    }
    if (retained.length != retainedNames.length ||
        retainedNames.length != expectedNames.length ||
        !retainedNames.containsAll(expectedNames)) {
      throw StateError('local_wipe_installation_not_empty');
    }
  }

  Future<void> _deleteApplicationCacheContents() async {
    final cache = Directory(
      p.normalize(
        p.absolute((await _runtime.applicationCacheDirectory()).path),
      ),
    );
    final type = await FileSystemEntity.type(cache.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.directory) {
      throw StateError('local_wipe_cache_root_unsafe');
    }
    final canonical = await _canonicalDirectoryPath(cache);
    if (!p.equals(canonical, cache.path)) {
      throw StateError('local_wipe_cache_root_unsafe');
    }
    if (p.equals(cache.path, _installationRoot.path) ||
        p.isWithin(_installationRoot.path, cache.path)) {
      return;
    }
    if (p.isWithin(cache.path, _installationRoot.path)) {
      throw StateError('local_wipe_cache_root_unsafe');
    }
    final entities = await cache.list(followLinks: false).toList();
    for (final entity in entities) {
      _requireDirectChild(parent: cache, childPath: entity.path);
      await _deleteEntityWithoutFollowingLinks(parent: cache, entity: entity);
      await _requireAnchoredDirectory(cache, 'local_wipe_cache_root_unsafe');
    }
    if (!await cache.list(followLinks: false).isEmpty) {
      throw StateError('local_wipe_cache_not_empty');
    }
    await _durability.syncDirectory(cache, fullBarrier: true);
  }

  String _requireDirectChild({
    required Directory parent,
    required String childPath,
  }) {
    final normalizedParent = p.normalize(p.absolute(parent.path));
    final normalizedChild = p.normalize(p.absolute(childPath));
    final name = p.basename(normalizedChild);
    if (name.isEmpty ||
        name == '.' ||
        name == '..' ||
        !p.equals(p.dirname(normalizedChild), normalizedParent) ||
        !p.equals(p.join(normalizedParent, name), normalizedChild)) {
      throw StateError('local_wipe_artifact_outside_root');
    }
    return name;
  }

  Future<String> _canonicalDirectoryPath(Directory directory) async {
    try {
      return p.normalize(await directory.resolveSymbolicLinks());
    } on FileSystemException catch (error) {
      // 某些 Windows 虚拟卷不提供规范路径 API；只有逐级确认不存在
      // reparse/link 时才能退回词法绝对路径，擦除边界仍保持失败关闭。
      if (Platform.isWindows &&
          error.osError?.errorCode == 1 &&
          await _hasNoLinkComponent(directory.path)) {
        return p.normalize(p.absolute(directory.path));
      }
      rethrow;
    }
  }

  Future<bool> _hasNoLinkComponent(String path) async {
    try {
      var current = p.normalize(p.absolute(path));
      while (true) {
        final type = await FileSystemEntity.type(current, followLinks: false);
        if (type == FileSystemEntityType.notFound ||
            type == FileSystemEntityType.link) {
          return false;
        }
        final parent = p.dirname(current);
        if (p.equals(parent, current)) return true;
        current = parent;
      }
    } on FileSystemException {
      return false;
    }
  }

  Future<void> _deleteEntityWithoutFollowingLinks({
    required Directory parent,
    required FileSystemEntity entity,
  }) async {
    _requireDirectChild(parent: parent, childPath: entity.path);
    final type = await FileSystemEntity.type(entity.path, followLinks: false);
    switch (type) {
      case FileSystemEntityType.file:
        await File(entity.path).delete();
        return;
      case FileSystemEntityType.directory:
        final directory = Directory(entity.path);
        await _requireAnchoredDirectory(
          directory,
          'local_wipe_artifact_unsafe',
        );
        final children = await directory.list(followLinks: false).toList();
        for (final child in children) {
          await _deleteEntityWithoutFollowingLinks(
            parent: directory,
            entity: child,
          );
        }
        await _requireAnchoredDirectory(
          directory,
          'local_wipe_artifact_changed',
        );
        if (!await directory.list(followLinks: false).isEmpty) {
          throw StateError('local_wipe_directory_not_empty');
        }
        await directory.delete();
        return;
      case FileSystemEntityType.link:
        await Link(entity.path).delete();
        return;
      case FileSystemEntityType.notFound:
        throw StateError('local_wipe_artifact_changed');
      default:
        throw StateError('local_wipe_artifact_unsafe');
    }
  }

  Future<void> _commitCompletion() async {
    await _requireInstallationRoot();
    final marker = await _readPublishedMarker(
      _revocationConfirmedMarkerFile,
      LocalCryptographicWipePhase.revocationConfirmed,
    );
    var completionMarker = await _readPublishedMarker(
      _completionMarkerFile,
      LocalCryptographicWipePhase.completion,
    );
    if (marker == null && completionMarker == null) {
      throw StateError('local_wipe_marker_missing');
    }
    if (marker == null) {
      await _requireOnlyMarkersRetained({
        LocalWipeMarkerTopology.completionMarkerFileName,
      });
      await _finalizeCompletionMarker();
      return;
    }
    if (completionMarker == null) {
      await _requireOnlyMarkersRetained({
        LocalWipeMarkerTopology.revocationConfirmedMarkerFileName,
      });
      await _publishMarker(
        marker.withPhase(LocalCryptographicWipePhase.completion),
        target: _completionMarkerFile,
      );
      completionMarker = await _readPublishedMarker(
        _completionMarkerFile,
        LocalCryptographicWipePhase.completion,
      );
    }
    if (completionMarker == null || !completionMarker.sameIntent(marker)) {
      throw StateError('local_wipe_marker_collision');
    }
    await _requireOnlyMarkersRetained({
      LocalWipeMarkerTopology.revocationConfirmedMarkerFileName,
      LocalWipeMarkerTopology.completionMarkerFileName,
    });
    await _revocationConfirmedMarkerFile.delete();
    await _durability.syncDirectory(_installationRoot, fullBarrier: true);
    if (await _readPublishedMarker(
          _revocationConfirmedMarkerFile,
          LocalCryptographicWipePhase.revocationConfirmed,
        ) !=
        null) {
      throw StateError('local_wipe_completion_commit');
    }
    final retainedCompletion = await _readPublishedMarker(
      _completionMarkerFile,
      LocalCryptographicWipePhase.completion,
    );
    if (retainedCompletion != completionMarker) {
      throw StateError('local_wipe_completion_commit');
    }
    await _requireOnlyMarkersRetained({
      LocalWipeMarkerTopology.completionMarkerFileName,
    });
    await _finalizeCompletionMarker();
  }

  Future<void> _finalizeCompletionMarker() async {
    await _requireOnlyMarkersRetained({
      LocalWipeMarkerTopology.completionMarkerFileName,
    });
    final marker = await _readPublishedMarker(
      _completionMarkerFile,
      LocalCryptographicWipePhase.completion,
    );
    if (marker == null) {
      throw StateError('local_wipe_completion_marker_missing');
    }
    await _completionMarkerFile.delete();
    try {
      await _durability.syncDirectory(_installationRoot, fullBarrier: true);
      if (!await _installationRoot.list(followLinks: false).isEmpty) {
        throw StateError('local_wipe_installation_not_empty');
      }
    } catch (error, stackTrace) {
      final existing = await _readPublishedMarker(
        _completionMarkerFile,
        LocalCryptographicWipePhase.completion,
      );
      if (existing == null) {
        await _publishMarker(marker, target: _completionMarkerFile);
      } else if (existing != marker) {
        throw StateError('local_wipe_marker_collision');
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _requireAnchoredDirectory(
    Directory directory,
    String errorCode,
  ) async {
    final normalized = p.normalize(p.absolute(directory.path));
    final type = await FileSystemEntity.type(normalized, followLinks: false);
    if (type != FileSystemEntityType.directory ||
        !p.equals(await _canonicalDirectoryPath(directory), normalized)) {
      throw StateError(errorCode);
    }
  }
}

final class _LocalWipeMarker {
  const _LocalWipeMarker({
    required this.phase,
    required this.deviceId,
    required this.mutationId,
    required this.createdAtUtc,
  });

  final LocalCryptographicWipePhase phase;
  final String deviceId;
  final String mutationId;
  final DateTime createdAtUtc;

  LocalCryptographicWipeIntent get intent => LocalCryptographicWipeIntent(
    phase: phase,
    deviceId: deviceId,
    mutationId: mutationId,
    createdAtUtc: createdAtUtc,
  );

  _LocalWipeMarker withPhase(LocalCryptographicWipePhase nextPhase) =>
      _LocalWipeMarker(
        phase: nextPhase,
        deviceId: deviceId,
        mutationId: mutationId,
        createdAtUtc: createdAtUtc,
      );

  bool matches({required String deviceId, required String mutationId}) =>
      this.deviceId == deviceId && this.mutationId == mutationId;

  bool sameIntent(_LocalWipeMarker other) =>
      deviceId == other.deviceId &&
      mutationId == other.mutationId &&
      createdAtUtc == other.createdAtUtc;

  Map<String, Object> _payloadJson() => <String, Object>{
    'format': InstallationLocalCryptographicWipe._markerFormat,
    'version': InstallationLocalCryptographicWipe._markerVersion,
    'phase': phase.wireName,
    'deviceId': deviceId,
    'mutationId': mutationId,
    'createdAtUtc': createdAtUtc.toIso8601String(),
  };

  String get checksum =>
      sha256.convert(utf8.encode(jsonEncode(_payloadJson()))).toString();

  Map<String, Object> toJson() => <String, Object>{
    ..._payloadJson(),
    'checksum': checksum,
  };

  factory _LocalWipeMarker.fromJson(Map<String, Object?> json) {
    const expectedKeys = <String>{
      'format',
      'version',
      'phase',
      'deviceId',
      'mutationId',
      'createdAtUtc',
      'checksum',
    };
    if (json.length != expectedKeys.length ||
        !json.keys.toSet().containsAll(expectedKeys) ||
        json['format'] != InstallationLocalCryptographicWipe._markerFormat ||
        json['version'] != InstallationLocalCryptographicWipe._markerVersion ||
        json['phase'] is! String ||
        json['deviceId'] is! String ||
        json['mutationId'] is! String ||
        json['createdAtUtc'] is! String ||
        json['checksum'] is! String) {
      throw const FormatException('local_wipe_marker_fields');
    }
    final deviceId = json['deviceId']! as String;
    final mutationId = json['mutationId']! as String;
    if (!InstallationLocalCryptographicWipe._deviceIdPattern.hasMatch(
          deviceId,
        ) ||
        !InstallationLocalCryptographicWipe._deviceIdPattern.hasMatch(
          mutationId,
        )) {
      throw const FormatException('local_wipe_marker_identity');
    }
    final phase = LocalCryptographicWipePhaseWire.parse(
      json['phase']! as String,
    );
    if (phase == null) {
      throw const FormatException('local_wipe_marker_phase');
    }
    final createdAtRaw = json['createdAtUtc']! as String;
    final createdAt = DateTime.parse(createdAtRaw);
    if (!createdAt.isUtc || createdAt.toIso8601String() != createdAtRaw) {
      throw const FormatException('local_wipe_marker_created_at');
    }
    final marker = _LocalWipeMarker(
      phase: phase,
      deviceId: deviceId,
      mutationId: mutationId,
      createdAtUtc: createdAt,
    );
    if (marker.checksum != json['checksum']) {
      throw const FormatException('local_wipe_marker_checksum');
    }
    return marker;
  }

  @override
  bool operator ==(Object other) =>
      other is _LocalWipeMarker &&
      other.phase == phase &&
      other.deviceId == deviceId &&
      other.mutationId == mutationId &&
      other.createdAtUtc == createdAtUtc;

  @override
  int get hashCode => Object.hash(phase, deviceId, mutationId, createdAtUtc);
}

extension on LocalCryptographicWipePhase {
  String get wireName => switch (this) {
    LocalCryptographicWipePhase.revocationRequested => 'revocation-requested',
    LocalCryptographicWipePhase.revocationConfirmed => 'revocation-confirmed',
    LocalCryptographicWipePhase.completion => 'completion',
  };
}

abstract final class LocalCryptographicWipePhaseWire {
  static LocalCryptographicWipePhase? parse(String value) => switch (value) {
    'revocation-requested' => LocalCryptographicWipePhase.revocationRequested,
    'revocation-confirmed' => LocalCryptographicWipePhase.revocationConfirmed,
    'completion' => LocalCryptographicWipePhase.completion,
    _ => null,
  };
}
