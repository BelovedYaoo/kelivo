import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../backup/restore_durability.dart';

final class DeviceStateBlobStore {
  DeviceStateBlobStore({
    required Directory installationRoot,
    RestoreDurability? durability,
  }) : _installationRoot = Directory(
         p.normalize(p.absolute(installationRoot.path)),
       ),
       _durability = durability ?? RestorePlatformDurability();

  static const blobLength = 188;
  static const _maximumGeneration = 0x7fffffffffffffff;
  static const _storeDirectoryName = '.kelivo-device-state-v1';
  static const _locatorDomain = 'kelivo.device-state.locator.v1';
  static const _stateFilePrefix = 'state';
  static const _manifestFilePrefix = 'manifest';
  static const _stateFrameHeaderLength = 20;
  static const _stateFrameLength = _stateFrameHeaderLength + blobLength;
  static const _manifestFrameLength = 56;
  static const _manifestHashOffset = 24;
  static final Uint8List _stateFrameMagic = Uint8List.fromList(
    ascii.encode('KELVDS01'),
  );
  static final Uint8List _manifestFrameMagic = Uint8List.fromList(
    ascii.encode('KELVDM01'),
  );

  final Directory _installationRoot;
  final RestoreDurability _durability;

  Future<Uint8List?> read({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
  }) {
    final locator = _deriveLocator(
      normalizedBaseUrl: normalizedBaseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    return _DeviceStateStoreCriticalSection.run(() async {
      final directory = await _findLocatorDirectory(locator);
      if (directory == null) return null;
      final manifest = await _readCurrentManifest(directory);
      if (manifest == null) return null;
      return _readPublishedState(directory, manifest);
    });
  }

  Future<void> write({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
    required Uint8List blob,
  }) {
    if (blob.length != blobLength) {
      throw const FormatException('device_state_store_blob_length');
    }
    final state = Uint8List.fromList(blob);
    final locator = _deriveLocator(
      normalizedBaseUrl: normalizedBaseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    return _DeviceStateStoreCriticalSection.run(() async {
      final directory = await _ensureLocatorDirectory(locator);
      final current = await _readCurrentManifest(directory);
      if (current != null) {
        await _readPublishedState(directory, current);
      }
      final generation = (current?.generation ?? 0) + 1;
      if (generation > _maximumGeneration) {
        throw StateError('device_state_store_generation_exhausted');
      }
      final slot = current?.slot == 'a' ? 'b' : 'a';
      await _retireManifest(directory, slot);

      final stateFrame = _encodeStateFrame(generation: generation, blob: state);
      await _publishFile(
        directory: directory,
        target: _stateFile(directory, slot),
        temporary: _stateTemporaryFile(directory, slot),
        bytes: stateFrame,
        replaceExisting: true,
      );

      final manifestFrame = _encodeManifestFrame(
        generation: generation,
        slot: slot,
        stateFrameHash: Uint8List.fromList(sha256.convert(stateFrame).bytes),
      );
      await _publishFile(
        directory: directory,
        target: _manifestFile(directory, slot),
        temporary: _manifestTemporaryFile(directory, slot),
        bytes: manifestFrame,
        replaceExisting: false,
      );
    });
  }

  Future<void> delete({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
  }) {
    final locator = _deriveLocator(
      normalizedBaseUrl: normalizedBaseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    return _DeviceStateStoreCriticalSection.run(() async {
      final directory = await _findLocatorDirectory(locator);
      if (directory == null) return;
      final manifests = <File>[
        for (final slot in const <String>['a', 'b'])
          _manifestFile(directory, slot),
      ];
      final remainingFiles = <File>[
        for (final slot in const <String>['a', 'b']) ...<File>[
          _stateFile(directory, slot),
          _stateTemporaryFile(directory, slot),
          _manifestTemporaryFile(directory, slot),
        ],
      ];
      final ownedFiles = <File>[...manifests, ...remainingFiles];
      for (final file in ownedFiles) {
        final type = await FileSystemEntity.type(file.path, followLinks: false);
        if (type != FileSystemEntityType.notFound &&
            type != FileSystemEntityType.file) {
          throw StateError('device_state_store_owned_file_unsafe');
        }
      }

      var deletedManifest = false;
      for (final manifest in manifests) {
        deletedManifest = await _deleteRegularFile(manifest) || deletedManifest;
      }
      if (deletedManifest) {
        // 先持久化撤销发布，再清理 slot，避免崩溃后留下指向缺失状态的 manifest。
        await _durability.syncDirectory(directory, fullBarrier: true);
      }

      var deletedRemainingFile = false;
      for (final file in remainingFiles) {
        deletedRemainingFile =
            await _deleteRegularFile(file) || deletedRemainingFile;
      }
      if (deletedRemainingFile) {
        await _durability.syncDirectory(directory, fullBarrier: true);
      }

      if (!await directory.list(followLinks: false).isEmpty) return;
      final storeRoot = directory.parent;
      await directory.delete();
      await _durability.syncDirectory(storeRoot, fullBarrier: true);
      if (!await storeRoot.list(followLinks: false).isEmpty) return;
      await storeRoot.delete();
      await _durability.syncDirectory(_installationRoot, fullBarrier: true);
    });
  }

  Future<Directory?> _findLocatorDirectory(String locator) async {
    final installationCanonical = await _requireInstallationRoot();
    final storeRoot = await _ownedChildDirectory(
      parent: _installationRoot,
      parentCanonicalPath: installationCanonical,
      name: _storeDirectoryName,
      createMissing: false,
      errorCode: 'device_state_store_root_unsafe',
    );
    if (storeRoot == null) return null;
    final storeCanonical = p.join(installationCanonical, _storeDirectoryName);
    return _ownedChildDirectory(
      parent: storeRoot,
      parentCanonicalPath: storeCanonical,
      name: locator,
      createMissing: false,
      errorCode: 'device_state_store_locator_unsafe',
    );
  }

  Future<Directory> _ensureLocatorDirectory(String locator) async {
    final installationCanonical = await _requireInstallationRoot();
    final storeRoot = await _ownedChildDirectory(
      parent: _installationRoot,
      parentCanonicalPath: installationCanonical,
      name: _storeDirectoryName,
      createMissing: true,
      errorCode: 'device_state_store_root_unsafe',
    );
    final resolvedStoreRoot = storeRoot!;
    final storeCanonical = p.join(installationCanonical, _storeDirectoryName);
    final locatorDirectory = await _ownedChildDirectory(
      parent: resolvedStoreRoot,
      parentCanonicalPath: storeCanonical,
      name: locator,
      createMissing: true,
      errorCode: 'device_state_store_locator_unsafe',
    );
    return locatorDirectory!;
  }

  Future<String> _requireInstallationRoot() async {
    final type = await FileSystemEntity.type(
      _installationRoot.path,
      followLinks: false,
    );
    if (type != FileSystemEntityType.directory) {
      throw StateError('device_state_store_installation_root_unsafe');
    }
    return p.normalize(await _installationRoot.resolveSymbolicLinks());
  }

  Future<Directory?> _ownedChildDirectory({
    required Directory parent,
    required String parentCanonicalPath,
    required String name,
    required bool createMissing,
    required String errorCode,
  }) async {
    final directory = Directory(p.join(parent.path, name));
    var type = await FileSystemEntity.type(directory.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      if (!createMissing) return null;
      await directory.create();
      await _durability.restrictDirectory(directory);
      await _durability.syncDirectory(parent, fullBarrier: true);
      type = await FileSystemEntity.type(directory.path, followLinks: false);
    }
    if (type != FileSystemEntityType.directory) {
      throw StateError(errorCode);
    }
    final canonical = p.normalize(await directory.resolveSymbolicLinks());
    if (!p.equals(canonical, p.normalize(p.join(parentCanonicalPath, name)))) {
      throw StateError(errorCode);
    }
    return directory;
  }

  Future<_DeviceStateManifest?> _readCurrentManifest(
    Directory directory,
  ) async {
    final manifests = <_DeviceStateManifest>[];
    for (final slot in const <String>['a', 'b']) {
      final file = _manifestFile(directory, slot);
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.file) {
        throw const FormatException('device_state_store_corrupt');
      }
      final frame = await _readExactFrame(file, _manifestFrameLength);
      manifests.add(_decodeManifestFrame(frame, expectedSlot: slot));
    }
    if (manifests.isEmpty) return null;
    manifests.sort(
      (left, right) => right.generation.compareTo(left.generation),
    );
    if (manifests.length > 1 &&
        manifests[0].generation == manifests[1].generation) {
      throw const FormatException('device_state_store_corrupt');
    }
    return manifests.first;
  }

  Future<Uint8List> _readPublishedState(
    Directory directory,
    _DeviceStateManifest manifest,
  ) async {
    final file = _stateFile(directory, manifest.slot);
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type != FileSystemEntityType.file) {
      throw const FormatException('device_state_store_corrupt');
    }
    final frame = await _readExactFrame(file, _stateFrameLength);
    if (!_sameBytes(
      Uint8List.fromList(sha256.convert(frame).bytes),
      manifest.stateFrameHash,
    )) {
      throw const FormatException('device_state_store_corrupt');
    }
    if (!_startsWith(frame, _stateFrameMagic)) {
      throw const FormatException('device_state_store_corrupt');
    }
    final fields = ByteData.sublistView(frame);
    if (fields.getUint64(8, Endian.big) != manifest.generation ||
        fields.getUint32(16, Endian.big) != blobLength) {
      throw const FormatException('device_state_store_corrupt');
    }
    return Uint8List.fromList(frame.sublist(_stateFrameHeaderLength));
  }

  Future<void> _retireManifest(Directory directory, String slot) async {
    if (await _deleteRegularFile(_manifestFile(directory, slot))) {
      await _durability.syncDirectory(directory, fullBarrier: true);
    }
  }

  Future<void> _publishFile({
    required Directory directory,
    required File target,
    required File temporary,
    required Uint8List bytes,
    required bool replaceExisting,
  }) async {
    if (await _deleteRegularFile(temporary)) {
      await _durability.syncDirectory(directory, fullBarrier: true);
    }
    final targetType = await FileSystemEntity.type(
      target.path,
      followLinks: false,
    );
    if (targetType != FileSystemEntityType.notFound) {
      if (!replaceExisting || targetType != FileSystemEntityType.file) {
        throw StateError('device_state_store_publish_target');
      }
      await target.delete();
      await _durability.syncDirectory(directory, fullBarrier: true);
    }

    await temporary.create(exclusive: true);
    await _durability.restrictFile(temporary);
    await temporary.writeAsBytes(bytes, flush: true);
    await _durability.syncFile(temporary, fullBarrier: true);
    await _durability.renameAndSync(source: temporary, targetPath: target.path);
  }

  static Uint8List _encodeStateFrame({
    required int generation,
    required Uint8List blob,
  }) {
    final frame = Uint8List(_stateFrameLength);
    frame.setRange(0, _stateFrameMagic.length, _stateFrameMagic);
    final fields = ByteData.sublistView(frame);
    fields.setUint64(8, generation, Endian.big);
    fields.setUint32(16, blobLength, Endian.big);
    frame.setRange(_stateFrameHeaderLength, frame.length, blob);
    return frame;
  }

  static Uint8List _encodeManifestFrame({
    required int generation,
    required String slot,
    required Uint8List stateFrameHash,
  }) {
    final frame = Uint8List(_manifestFrameLength);
    frame.setRange(0, _manifestFrameMagic.length, _manifestFrameMagic);
    final fields = ByteData.sublistView(frame);
    fields.setUint64(8, generation, Endian.big);
    frame[16] = slot == 'a' ? 0 : 1;
    frame.setRange(_manifestHashOffset, frame.length, stateFrameHash);
    return frame;
  }

  static _DeviceStateManifest _decodeManifestFrame(
    Uint8List frame, {
    required String expectedSlot,
  }) {
    if (!_startsWith(frame, _manifestFrameMagic)) {
      throw const FormatException('device_state_store_corrupt');
    }
    final fields = ByteData.sublistView(frame);
    final generation = fields.getUint64(8, Endian.big);
    final expectedSlotCode = expectedSlot == 'a' ? 0 : 1;
    if (generation <= 0 ||
        generation > _maximumGeneration ||
        frame[16] != expectedSlotCode) {
      throw const FormatException('device_state_store_corrupt');
    }
    for (var index = 17; index < _manifestHashOffset; index++) {
      if (frame[index] != 0) {
        throw const FormatException('device_state_store_corrupt');
      }
    }
    return _DeviceStateManifest(
      generation: generation,
      slot: expectedSlot,
      stateFrameHash: Uint8List.fromList(frame.sublist(_manifestHashOffset)),
    );
  }

  static Future<Uint8List> _readExactFrame(
    File file,
    int expectedLength,
  ) async {
    final reader = await file.open(mode: FileMode.read);
    try {
      if (await reader.length() != expectedLength) {
        throw const FormatException('device_state_store_corrupt');
      }
      final frame = await reader.read(expectedLength);
      if (frame.length != expectedLength) {
        throw const FormatException('device_state_store_corrupt');
      }
      return frame;
    } finally {
      await reader.close();
    }
  }

  static Future<bool> _deleteRegularFile(File file) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return false;
    if (type != FileSystemEntityType.file) {
      throw StateError('device_state_store_owned_file_unsafe');
    }
    await file.delete();
    return true;
  }

  static String _deriveLocator({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
  }) {
    if (normalizedBaseUrl.isEmpty ||
        normalizedLoginName.isEmpty ||
        normalizedBaseUrl.contains('\u0000') ||
        normalizedLoginName.contains('\u0000')) {
      throw const FormatException('device_state_store_locator_input');
    }
    return sha256
        .convert(
          utf8.encode(
            '$_locatorDomain\u0000$normalizedBaseUrl\u0000$normalizedLoginName',
          ),
        )
        .toString();
  }

  static bool _startsWith(Uint8List value, Uint8List prefix) {
    if (value.length < prefix.length) return false;
    for (var index = 0; index < prefix.length; index++) {
      if (value[index] != prefix[index]) return false;
    }
    return true;
  }

  static bool _sameBytes(Uint8List left, Uint8List right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }

  static File _stateFile(Directory directory, String slot) {
    return File(p.join(directory.path, '$_stateFilePrefix-$slot.bin'));
  }

  static File _stateTemporaryFile(Directory directory, String slot) {
    return File(p.join(directory.path, '.$_stateFilePrefix-$slot.next'));
  }

  static File _manifestFile(Directory directory, String slot) {
    return File(p.join(directory.path, '$_manifestFilePrefix-$slot.bin'));
  }

  static File _manifestTemporaryFile(Directory directory, String slot) {
    return File(p.join(directory.path, '.$_manifestFilePrefix-$slot.next'));
  }
}

final class _DeviceStateManifest {
  const _DeviceStateManifest({
    required this.generation,
    required this.slot,
    required this.stateFrameHash,
  });

  final int generation;
  final String slot;
  final Uint8List stateFrameHash;
}

abstract final class _DeviceStateStoreCriticalSection {
  static Future<void> _tail = Future<void>.value();

  static Future<T> run<T>(Future<T> Function() action) {
    final previous = _tail;
    final release = Completer<void>();
    _tail = release.future;
    return _run(previous, release, action);
  }

  static Future<T> _run<T>(
    Future<void> previous,
    Completer<void> release,
    Future<T> Function() action,
  ) async {
    await previous;
    try {
      return await action();
    } finally {
      release.complete();
    }
  }
}
