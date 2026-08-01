import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import '../backup/restore_durability.dart';

final class DeviceStateBlobVersion {
  DeviceStateBlobVersion._(
    this._locator,
    this._generation,
    this._slot,
    Uint8List stateFrameHash,
  ) : _stateFrameHash = Uint8List.fromList(stateFrameHash);

  final String _locator;
  final int _generation;
  final String _slot;
  final Uint8List _stateFrameHash;

  @override
  bool operator ==(Object other) {
    return other is DeviceStateBlobVersion &&
        _locator == other._locator &&
        _generation == other._generation &&
        _slot == other._slot &&
        DeviceStateBlobStore._sameBytes(_stateFrameHash, other._stateFrameHash);
  }

  @override
  int get hashCode => Object.hash(
    _locator,
    _generation,
    _slot,
    Object.hashAll(_stateFrameHash),
  );

  @override
  String toString() => 'DeviceStateBlobVersion(<opaque>)';
}

final class DeviceStateBlobSnapshot {
  DeviceStateBlobSnapshot._({required Uint8List blob, required this.version})
    : blob = Uint8List.fromList(blob);

  final Uint8List blob;
  final DeviceStateBlobVersion version;
}

final class DeviceStateBlobConflict implements Exception {
  const DeviceStateBlobConflict();

  @override
  String toString() => 'device_state_store_conflict';
}

final class DeviceStateBlobStore {
  DeviceStateBlobStore({
    required Directory installationRoot,
    RestoreDurability? durability,
  }) : _installationRoot = Directory(
         p.normalize(p.absolute(installationRoot.path)),
       ),
       _durability = durability ?? RestorePlatformDurability();

  static const blobLength = 448;
  // 固定注册载荷与恢复介质不足 3 KiB；预留协议升级空间并限制损坏文件的读取分配。
  static const pendingRegistrationEnvelopeMaxLength = 4096;
  // 配对恢复事务包含两个设备状态和一次性能力；保留升级空间但拒绝无界读取。
  static const pendingPairingEnvelopeMaxLength = 4096;
  static const _maximumGeneration = 0x7fffffffffffffff;
  static const _storeDirectoryName = '.kelivo-device-state-v1';
  static const _locatorDomain = 'kelivo.device-state.locator.v1';
  static const _stateFilePrefix = 'state';
  static const _manifestFilePrefix = 'manifest';
  static const _tombstoneFileName = 'tombstone.bin';
  static const _pendingRegistrationFileName = 'registration-pending.bin';
  static const _registrationMediaConfirmationFileName =
      'registration-media-confirmed.bin';
  static const _pendingPairingFileName = 'pairing-pending.bin';
  static const _lockFileName = '.lock';
  static const _stateFrameHeaderLength = 20;
  static const _stateFrameLength = _stateFrameHeaderLength + blobLength;
  static const _manifestFrameLength = 56;
  static const _manifestHashOffset = 24;
  static const _tombstoneHeaderLength = 16;
  static const _tombstoneFrameLength = _tombstoneHeaderLength + 32;
  static const _pendingRegistrationHeaderLength = 44;
  static const _pendingRegistrationDigestOffset = 12;
  static const _registrationMediaConfirmationFrameLength = 44;
  static const _registrationMediaConfirmationDigestOffset = 12;
  static final RegExp _temporaryFilePattern = RegExp(
    r'^\.(?:state-[ab]|manifest-[ab]|tombstone|registration-pending|registration-media-confirmed|pairing-pending)-[0-9a-f]{32}\.next$',
  );
  static final Random _secureRandom = Random.secure();
  static final Uint8List _stateFrameMagic = Uint8List.fromList(
    ascii.encode('KELVDS01'),
  );
  static final Uint8List _manifestFrameMagic = Uint8List.fromList(
    ascii.encode('KELVDM01'),
  );
  static final Uint8List _tombstoneFrameMagic = Uint8List.fromList(
    ascii.encode('KELVDT01'),
  );
  static final Uint8List _pendingRegistrationFrameMagic = Uint8List.fromList(
    ascii.encode('KELVRP01'),
  );
  static final Uint8List _pendingPairingFrameMagic = Uint8List.fromList(
    ascii.encode('KELVPP01'),
  );
  static final Uint8List _registrationMediaConfirmationFrameMagic =
      Uint8List.fromList(ascii.encode('KELVRC01'));

  final Directory _installationRoot;
  final RestoreDurability _durability;

  Future<Uint8List?> read({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
  }) async {
    final snapshot = await readVersioned(
      normalizedBaseUrl: normalizedBaseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    return snapshot?.blob;
  }

  Future<DeviceStateBlobSnapshot?> readVersioned({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
  }) {
    final locator = _deriveLocator(
      normalizedBaseUrl: normalizedBaseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    return _withLocatorLock(locator, (directory) async {
      if (await _readTombstone(directory) != null) return null;
      final manifest = await _readCurrentManifest(directory);
      if (manifest == null) return null;
      final blob = await _readPublishedState(directory, manifest);
      return DeviceStateBlobSnapshot._(
        blob: blob,
        version: _versionForManifest(locator, manifest),
      );
    });
  }

  Future<DeviceStateBlobSnapshot> compareAndSwap({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
    required DeviceStateBlobVersion? expectedVersion,
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
    return _withLocatorLock(locator, (directory) async {
      final tombstone = await _readTombstone(directory);
      final current = tombstone == null
          ? await _readCurrentManifest(directory)
          : null;
      if (expectedVersion == null) {
        if (current != null) throw const DeviceStateBlobConflict();
      } else {
        if (tombstone != null ||
            current == null ||
            expectedVersion._locator != locator) {
          throw const DeviceStateBlobConflict();
        }
        final currentBlob = await _readPublishedState(directory, current);
        final currentVersion = _versionForManifest(locator, current);
        if (currentVersion != expectedVersion) {
          throw const DeviceStateBlobConflict();
        }
        if (_sameBytes(currentBlob, state)) {
          return DeviceStateBlobSnapshot._(
            blob: currentBlob,
            version: currentVersion,
          );
        }
      }

      if (tombstone != null) {
        await _cleanupDeletedState(directory);
      } else {
        await _cleanupTemporaryFiles(directory);
      }
      final generation = _nextGeneration(
        tombstone?.generation ?? current?.generation ?? 0,
      );
      final slot = current?.slot == 'a' ? 'b' : 'a';
      if (current != null) await _retireManifest(directory, slot);
      final stateFrame = _encodeStateFrame(generation: generation, blob: state);
      final stateFrameHash = Uint8List.fromList(
        sha256.convert(stateFrame).bytes,
      );
      await _publishFile(
        directory: directory,
        target: _stateFile(directory, slot),
        bytes: stateFrame,
        replaceExisting: true,
      );
      await _publishFile(
        directory: directory,
        target: _manifestFile(directory, slot),
        bytes: _encodeManifestFrame(
          generation: generation,
          slot: slot,
          stateFrameHash: stateFrameHash,
        ),
        replaceExisting: false,
      );
      if (tombstone != null) {
        await _deleteRegularFile(_tombstoneFile(directory));
        await _durability.syncDirectory(directory, fullBarrier: true);
      }
      return DeviceStateBlobSnapshot._(
        blob: state,
        version: DeviceStateBlobVersion._(
          locator,
          generation,
          slot,
          stateFrameHash,
        ),
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
    return _withLocatorLock(locator, (directory) async {
      if (await _readTombstone(directory) == null) {
        final currentGeneration = await _highestManifestGenerationForDelete(
          directory,
        );
        await _publishFile(
          directory: directory,
          target: _tombstoneFile(directory),
          bytes: _encodeTombstoneFrame(_nextGeneration(currentGeneration)),
          replaceExisting: false,
        );
      }
      await _cleanupDeletedState(directory);
    });
  }

  Future<Uint8List?> readPendingRegistrationEnvelope({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
  }) => _readPendingEnvelopeForLocator(
    normalizedBaseUrl: normalizedBaseUrl,
    normalizedLoginName: normalizedLoginName,
    kind: _PendingEnvelopeKind.registration,
  );

  Future<void> writePendingRegistrationEnvelope({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
    required Uint8List envelope,
  }) => _writePendingEnvelopeForLocator(
    normalizedBaseUrl: normalizedBaseUrl,
    normalizedLoginName: normalizedLoginName,
    envelope: envelope,
    kind: _PendingEnvelopeKind.registration,
  );

  Future<Uint8List?> readPendingRegistrationMediaConfirmation({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
  }) {
    final locator = _deriveLocator(
      normalizedBaseUrl: normalizedBaseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    return _withLocatorLock(locator, (directory) async {
      if (await _readTombstone(directory) != null) return null;
      final manifest = await _readCurrentManifest(directory);
      final confirmation = await _readRegistrationMediaConfirmation(directory);
      if (manifest == null) {
        if (confirmation != null) {
          throw const FormatException(
            'device_state_store_registration_confirmation_orphan',
          );
        }
        return null;
      }
      await _readPublishedState(directory, manifest);
      if (confirmation == null) return null;
      final pending = await _readPendingEnvelope(
        directory,
        _PendingEnvelopeKind.registration,
      );
      if (pending == null ||
          !_sameBytes(
            confirmation,
            Uint8List.fromList(sha256.convert(pending).bytes),
          )) {
        throw const FormatException(
          'device_state_store_registration_confirmation_orphan',
        );
      }
      return confirmation;
    });
  }

  Future<void> writePendingRegistrationMediaConfirmation({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
    required Uint8List pendingEnvelopeDigest,
  }) {
    if (pendingEnvelopeDigest.length != 32) {
      throw const FormatException(
        'device_state_store_registration_confirmation_digest_length',
      );
    }
    final copiedDigest = Uint8List.fromList(pendingEnvelopeDigest);
    final locator = _deriveLocator(
      normalizedBaseUrl: normalizedBaseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    return _withLocatorLock(locator, (directory) async {
      if (await _readTombstone(directory) != null) {
        throw StateError(
          'device_state_store_registration_confirmation_deleted',
        );
      }
      final manifest = await _readCurrentManifest(directory);
      if (manifest == null) {
        throw StateError(
          'device_state_store_registration_confirmation_state_missing',
        );
      }
      await _readPublishedState(directory, manifest);
      await _cleanupTemporaryFiles(directory);
      final pending = await _readPendingEnvelope(
        directory,
        _PendingEnvelopeKind.registration,
      );
      if (pending == null ||
          !_sameBytes(
            copiedDigest,
            Uint8List.fromList(sha256.convert(pending).bytes),
          )) {
        throw StateError(
          'device_state_store_registration_confirmation_pending_changed',
        );
      }
      final current = await _readRegistrationMediaConfirmation(directory);
      if (current != null) {
        if (_sameBytes(current, copiedDigest)) return;
        throw StateError(
          'device_state_store_registration_confirmation_changed',
        );
      }
      await _publishFile(
        directory: directory,
        target: _registrationMediaConfirmationFile(directory),
        bytes: _encodeRegistrationMediaConfirmationFrame(copiedDigest),
        replaceExisting: false,
      );
    });
  }

  Future<bool> deletePendingRegistrationEnvelope({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
    required Uint8List expectedDigest,
  }) => _deletePendingEnvelopeForLocator(
    normalizedBaseUrl: normalizedBaseUrl,
    normalizedLoginName: normalizedLoginName,
    expectedDigest: expectedDigest,
    kind: _PendingEnvelopeKind.registration,
  );

  Future<Uint8List?> readPendingPairingEnvelope({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
  }) => _readPendingEnvelopeForLocator(
    normalizedBaseUrl: normalizedBaseUrl,
    normalizedLoginName: normalizedLoginName,
    kind: _PendingEnvelopeKind.pairing,
  );

  Future<void> writePendingPairingEnvelope({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
    required Uint8List envelope,
  }) => _writePendingEnvelopeForLocator(
    normalizedBaseUrl: normalizedBaseUrl,
    normalizedLoginName: normalizedLoginName,
    envelope: envelope,
    kind: _PendingEnvelopeKind.pairing,
  );

  Future<bool> deletePendingPairingEnvelope({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
    required Uint8List expectedDigest,
  }) => _deletePendingEnvelopeForLocator(
    normalizedBaseUrl: normalizedBaseUrl,
    normalizedLoginName: normalizedLoginName,
    expectedDigest: expectedDigest,
    kind: _PendingEnvelopeKind.pairing,
  );

  Future<Uint8List?> _readPendingEnvelopeForLocator({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
    required _PendingEnvelopeKind kind,
  }) {
    final locator = _deriveLocator(
      normalizedBaseUrl: normalizedBaseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    return _withLocatorLock(locator, (directory) async {
      if (await _readTombstone(directory) != null) return null;
      final manifest = await _readCurrentManifest(directory);
      final pending = await _readPendingEnvelope(directory, kind);
      if (manifest == null) {
        if (pending != null) {
          throw FormatException('${_pendingEnvelopeCode(kind)}_orphan');
        }
        return null;
      }
      await _readPublishedState(directory, manifest);
      return pending;
    });
  }

  Future<void> _writePendingEnvelopeForLocator({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
    required Uint8List envelope,
    required _PendingEnvelopeKind kind,
  }) {
    if (envelope.isEmpty || envelope.length > _pendingEnvelopeMaxLength(kind)) {
      throw FormatException('${_pendingEnvelopeCode(kind)}_envelope_length');
    }
    final copiedEnvelope = Uint8List.fromList(envelope);
    final locator = _deriveLocator(
      normalizedBaseUrl: normalizedBaseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    return _withLocatorLock(locator, (directory) async {
      if (await _readTombstone(directory) != null) {
        throw StateError('${_pendingEnvelopeCode(kind)}_deleted');
      }
      final manifest = await _readCurrentManifest(directory);
      if (manifest == null) {
        throw StateError('${_pendingEnvelopeCode(kind)}_state_missing');
      }
      await _readPublishedState(directory, manifest);
      await _cleanupTemporaryFiles(directory);
      final current = await _readPendingEnvelope(directory, kind);
      if (current != null) {
        if (_sameBytes(current, copiedEnvelope)) return;
        throw StateError('${_pendingEnvelopeCode(kind)}_pending');
      }
      if (kind == _PendingEnvelopeKind.registration &&
          await _readRegistrationMediaConfirmation(directory) != null) {
        throw StateError('device_state_store_registration_confirmation_orphan');
      }
      await _publishFile(
        directory: directory,
        target: _pendingEnvelopeFile(directory, kind),
        bytes: _encodePendingEnvelopeFrame(copiedEnvelope, kind),
        replaceExisting: false,
      );
    });
  }

  Future<bool> _deletePendingEnvelopeForLocator({
    required String normalizedBaseUrl,
    required String normalizedLoginName,
    required Uint8List expectedDigest,
    required _PendingEnvelopeKind kind,
  }) {
    if (expectedDigest.length != 32) {
      throw FormatException('${_pendingEnvelopeCode(kind)}_digest_length');
    }
    final copiedDigest = Uint8List.fromList(expectedDigest);
    final locator = _deriveLocator(
      normalizedBaseUrl: normalizedBaseUrl,
      normalizedLoginName: normalizedLoginName,
    );
    return _withLocatorLock(locator, (directory) async {
      if (await _readTombstone(directory) != null) return false;
      final current = await _readPendingEnvelope(directory, kind);
      if (current == null) return false;
      final currentDigest = Uint8List.fromList(sha256.convert(current).bytes);
      if (!_sameBytes(currentDigest, copiedDigest)) {
        throw StateError('${_pendingEnvelopeCode(kind)}_changed');
      }
      if (kind == _PendingEnvelopeKind.registration) {
        final confirmation = await _readRegistrationMediaConfirmation(
          directory,
        );
        if (confirmation != null) {
          if (!_sameBytes(confirmation, currentDigest)) {
            throw StateError(
              'device_state_store_registration_confirmation_changed',
            );
          }
          await _deleteRegularFile(
            _registrationMediaConfirmationFile(directory),
          );
          await _durability.syncDirectory(directory, fullBarrier: true);
        }
      }
      await _deleteRegularFile(_pendingEnvelopeFile(directory, kind));
      await _durability.syncDirectory(directory, fullBarrier: true);
      return true;
    });
  }

  Future<T> _withLocatorLock<T>(
    String locator,
    Future<T> Function(Directory directory) action,
  ) {
    final lockKey = p.normalize(
      p.join(
        _installationRoot.path,
        _storeDirectoryName,
        locator,
        _lockFileName,
      ),
    );
    return _DeviceStateStoreCriticalSection.run(lockKey, () async {
      final directory = await _ensureLocatorDirectory(locator);
      final lockFile = File(p.join(directory.path, _lockFileName));
      return _DeviceStateOsFileLock.run(
        file: lockFile,
        durability: _durability,
        action: () async {
          final verified = await _findLocatorDirectory(locator);
          if (verified == null ||
              !p.equals(verified.absolute.path, directory.absolute.path)) {
            throw StateError('device_state_store_locator_changed');
          }
          return action(directory);
        },
      );
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

  Future<int> _highestManifestGenerationForDelete(Directory directory) async {
    var highest = 0;
    for (final slot in const <String>['a', 'b']) {
      final file = _manifestFile(directory, slot);
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.file) {
        throw StateError('device_state_store_owned_file_unsafe');
      }
      try {
        final manifest = _decodeManifestFrame(
          await _readExactFrame(file, _manifestFrameLength),
          expectedSlot: slot,
        );
        if (manifest.generation > highest) highest = manifest.generation;
      } on FormatException {
        // tombstone 对旧 manifest 具有绝对优先级，因此损坏旧代无需阻止硬删除。
      }
    }
    return highest;
  }

  Future<_DeviceStateTombstone?> _readTombstone(Directory directory) async {
    final file = _tombstoneFile(directory);
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.file) {
      throw const FormatException('device_state_store_tombstone_corrupt');
    }
    final frame = await _readExactFrame(file, _tombstoneFrameLength);
    if (!_startsWith(frame, _tombstoneFrameMagic)) {
      throw const FormatException('device_state_store_tombstone_corrupt');
    }
    final generation = ByteData.sublistView(frame).getUint64(8, Endian.big);
    if (generation <= 0 || generation > _maximumGeneration) {
      throw const FormatException('device_state_store_tombstone_corrupt');
    }
    final expectedHash = Uint8List.fromList(
      sha256.convert(frame.sublist(0, _tombstoneHeaderLength)).bytes,
    );
    if (!_sameBytes(
      expectedHash,
      Uint8List.fromList(frame.sublist(_tombstoneHeaderLength)),
    )) {
      throw const FormatException('device_state_store_tombstone_corrupt');
    }
    return _DeviceStateTombstone(generation);
  }

  Future<void> _cleanupDeletedState(Directory directory) async {
    final manifests = <File>[
      for (final slot in const <String>['a', 'b'])
        _manifestFile(directory, slot),
    ];
    final temporaryFiles = await _ownedTemporaryFiles(directory);
    final remainingFiles = <File>[
      for (final slot in const <String>['a', 'b']) _stateFile(directory, slot),
      for (final kind in _PendingEnvelopeKind.values)
        _pendingEnvelopeFile(directory, kind),
      _registrationMediaConfirmationFile(directory),
      ...temporaryFiles,
    ];
    for (final file in <File>[...manifests, ...remainingFiles]) {
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
  }

  Future<void> _cleanupTemporaryFiles(Directory directory) async {
    final temporaryFiles = await _ownedTemporaryFiles(directory);
    var deleted = false;
    for (final file in temporaryFiles) {
      deleted = await _deleteRegularFile(file) || deleted;
    }
    if (deleted) {
      await _durability.syncDirectory(directory, fullBarrier: true);
    }
  }

  Future<List<File>> _ownedTemporaryFiles(Directory directory) async {
    final files = <File>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (!_temporaryFilePattern.hasMatch(p.basename(entity.path))) continue;
      if (await FileSystemEntity.type(entity.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw StateError('device_state_store_owned_file_unsafe');
      }
      files.add(File(entity.path));
    }
    return files;
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

  Future<Uint8List?> _readPendingEnvelope(
    Directory directory,
    _PendingEnvelopeKind kind,
  ) async {
    final file = _pendingEnvelopeFile(directory, kind);
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.file) {
      throw StateError('device_state_store_owned_file_unsafe');
    }
    final corruptCode = '${_pendingEnvelopeCode(kind)}_corrupt';
    final frame = await _readBoundedFrame(
      file,
      minimumLength: _pendingRegistrationHeaderLength + 1,
      maximumLength:
          _pendingRegistrationHeaderLength + _pendingEnvelopeMaxLength(kind),
      corruptCode: corruptCode,
    );
    if (!_startsWith(frame, _pendingEnvelopeMagic(kind))) {
      throw FormatException(corruptCode);
    }
    final envelopeLength = ByteData.sublistView(frame).getUint32(8, Endian.big);
    if (envelopeLength <= 0 ||
        envelopeLength != frame.length - _pendingRegistrationHeaderLength) {
      throw FormatException(corruptCode);
    }
    final envelope = Uint8List.fromList(
      frame.sublist(_pendingRegistrationHeaderLength),
    );
    final storedDigest = Uint8List.fromList(
      frame.sublist(
        _pendingRegistrationDigestOffset,
        _pendingRegistrationHeaderLength,
      ),
    );
    final actualDigest = Uint8List.fromList(sha256.convert(envelope).bytes);
    if (!_sameBytes(storedDigest, actualDigest)) {
      throw FormatException(corruptCode);
    }
    return envelope;
  }

  Future<Uint8List?> _readRegistrationMediaConfirmation(
    Directory directory,
  ) async {
    final file = _registrationMediaConfirmationFile(directory);
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.file) {
      throw StateError('device_state_store_owned_file_unsafe');
    }
    final frame = await _readExactFrame(
      file,
      _registrationMediaConfirmationFrameLength,
    );
    if (!_startsWith(frame, _registrationMediaConfirmationFrameMagic) ||
        frame[8] != 0 ||
        frame[9] != 0 ||
        frame[10] != 0 ||
        frame[11] != 0) {
      throw const FormatException(
        'device_state_store_registration_confirmation_corrupt',
      );
    }
    return Uint8List.fromList(
      frame.sublist(_registrationMediaConfirmationDigestOffset),
    );
  }

  Future<void> _retireManifest(Directory directory, String slot) async {
    if (await _deleteRegularFile(_manifestFile(directory, slot))) {
      await _durability.syncDirectory(directory, fullBarrier: true);
    }
  }

  Future<void> _publishFile({
    required Directory directory,
    required File target,
    required Uint8List bytes,
    required bool replaceExisting,
  }) async {
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

    final temporary = await _createTemporaryFile(
      directory,
      targetBaseName: p.basenameWithoutExtension(target.path),
    );
    await _durability.restrictFile(temporary);
    if (await FileSystemEntity.type(temporary.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('device_state_store_temporary_changed');
    }
    await temporary.writeAsBytes(bytes, flush: true);
    await _durability.syncFile(temporary, fullBarrier: true);
    if (await FileSystemEntity.type(temporary.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('device_state_store_temporary_changed');
    }
    await _durability.renameAndSync(source: temporary, targetPath: target.path);
  }

  Future<File> _createTemporaryFile(
    Directory directory, {
    required String targetBaseName,
  }) async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final name = '.$targetBaseName-${_randomHex(16)}.next';
      final file = File(p.join(directory.path, name));
      try {
        await file.create(exclusive: true);
        if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file) {
          throw StateError('device_state_store_temporary_changed');
        }
        return file;
      } on FileSystemException {
        final type = await FileSystemEntity.type(file.path, followLinks: false);
        if (type == FileSystemEntityType.notFound) rethrow;
        if (type != FileSystemEntityType.file) {
          throw StateError('device_state_store_owned_file_unsafe');
        }
      }
    }
    throw StateError('device_state_store_temporary_collision');
  }

  static String _randomHex(int byteLength) {
    final value = StringBuffer();
    for (var index = 0; index < byteLength; index++) {
      value.write(_secureRandom.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return value.toString();
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

  static Uint8List _encodeTombstoneFrame(int generation) {
    final frame = Uint8List(_tombstoneFrameLength);
    frame.setRange(0, _tombstoneFrameMagic.length, _tombstoneFrameMagic);
    ByteData.sublistView(frame).setUint64(8, generation, Endian.big);
    frame.setRange(
      _tombstoneHeaderLength,
      frame.length,
      sha256.convert(frame.sublist(0, _tombstoneHeaderLength)).bytes,
    );
    return frame;
  }

  static Uint8List _encodePendingEnvelopeFrame(
    Uint8List envelope,
    _PendingEnvelopeKind kind,
  ) {
    final frame = Uint8List(_pendingRegistrationHeaderLength + envelope.length);
    frame.setRange(
      0,
      _pendingEnvelopeMagic(kind).length,
      _pendingEnvelopeMagic(kind),
    );
    ByteData.sublistView(frame).setUint32(8, envelope.length, Endian.big);
    frame.setRange(
      _pendingRegistrationDigestOffset,
      _pendingRegistrationHeaderLength,
      sha256.convert(envelope).bytes,
    );
    frame.setRange(_pendingRegistrationHeaderLength, frame.length, envelope);
    return frame;
  }

  static Uint8List _encodeRegistrationMediaConfirmationFrame(
    Uint8List pendingEnvelopeDigest,
  ) {
    final frame = Uint8List(_registrationMediaConfirmationFrameLength);
    frame.setRange(
      0,
      _registrationMediaConfirmationFrameMagic.length,
      _registrationMediaConfirmationFrameMagic,
    );
    frame.setRange(
      _registrationMediaConfirmationDigestOffset,
      frame.length,
      pendingEnvelopeDigest,
    );
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

  static Future<Uint8List> _readBoundedFrame(
    File file, {
    required int minimumLength,
    required int maximumLength,
    String corruptCode = 'device_state_store_registration_corrupt',
  }) async {
    final reader = await file.open(mode: FileMode.read);
    try {
      final length = await reader.length();
      if (length < minimumLength || length > maximumLength) {
        throw FormatException(corruptCode);
      }
      final frame = await reader.read(length);
      if (frame.length != length) {
        throw FormatException(corruptCode);
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

  static int _nextGeneration(int current) {
    if (current >= _maximumGeneration) {
      throw StateError('device_state_store_generation_exhausted');
    }
    return current + 1;
  }

  static DeviceStateBlobVersion _versionForManifest(
    String locator,
    _DeviceStateManifest manifest,
  ) {
    return DeviceStateBlobVersion._(
      locator,
      manifest.generation,
      manifest.slot,
      manifest.stateFrameHash,
    );
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

  static File _manifestFile(Directory directory, String slot) {
    return File(p.join(directory.path, '$_manifestFilePrefix-$slot.bin'));
  }

  static File _tombstoneFile(Directory directory) {
    return File(p.join(directory.path, _tombstoneFileName));
  }

  static File _pendingEnvelopeFile(
    Directory directory,
    _PendingEnvelopeKind kind,
  ) {
    final fileName = switch (kind) {
      _PendingEnvelopeKind.registration => _pendingRegistrationFileName,
      _PendingEnvelopeKind.pairing => _pendingPairingFileName,
    };
    return File(p.join(directory.path, fileName));
  }

  static File _registrationMediaConfirmationFile(Directory directory) {
    return File(p.join(directory.path, _registrationMediaConfirmationFileName));
  }

  static int _pendingEnvelopeMaxLength(_PendingEnvelopeKind kind) {
    return switch (kind) {
      _PendingEnvelopeKind.registration => pendingRegistrationEnvelopeMaxLength,
      _PendingEnvelopeKind.pairing => pendingPairingEnvelopeMaxLength,
    };
  }

  static String _pendingEnvelopeCode(_PendingEnvelopeKind kind) {
    return switch (kind) {
      _PendingEnvelopeKind.registration => 'device_state_store_registration',
      _PendingEnvelopeKind.pairing => 'device_state_store_pairing',
    };
  }

  static Uint8List _pendingEnvelopeMagic(_PendingEnvelopeKind kind) {
    return switch (kind) {
      _PendingEnvelopeKind.registration => _pendingRegistrationFrameMagic,
      _PendingEnvelopeKind.pairing => _pendingPairingFrameMagic,
    };
  }
}

enum _PendingEnvelopeKind { registration, pairing }

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

final class _DeviceStateTombstone {
  const _DeviceStateTombstone(this.generation);

  final int generation;
}

abstract final class _DeviceStateOsFileLock {
  static final _windows = _WindowsDeviceStateFileLock();
  static final _posix = _PosixDeviceStateFileLock();

  static Future<T> run<T>({
    required File file,
    required RestoreDurability durability,
    required Future<T> Function() action,
  }) {
    if (Platform.isWindows) {
      return _windows.run(file: file, durability: durability, action: action);
    }
    if (Platform.isLinux ||
        Platform.isAndroid ||
        Platform.isMacOS ||
        Platform.isIOS) {
      return _posix.run(file: file, durability: durability, action: action);
    }
    throw UnsupportedError('device_state_store_file_lock_platform');
  }
}

typedef _DeviceStateCreateFileNative =
    IntPtr Function(
      Pointer<Utf16>,
      Uint32,
      Uint32,
      Pointer<Void>,
      Uint32,
      Uint32,
      IntPtr,
    );
typedef _DeviceStateCreateFileDart =
    int Function(Pointer<Utf16>, int, int, Pointer<Void>, int, int, int);
typedef _DeviceStateGetFileInformationNative =
    Int32 Function(IntPtr, Int32, Pointer<Void>, Uint32);
typedef _DeviceStateGetFileInformationDart =
    int Function(int, int, Pointer<Void>, int);
typedef _DeviceStateHandleCallNative = Int32 Function(IntPtr);
typedef _DeviceStateHandleCallDart = int Function(int);
typedef _DeviceStateGetLastErrorNative = Uint32 Function();
typedef _DeviceStateGetLastErrorDart = int Function();

final class _DeviceStateFileAttributeTagInfo extends Struct {
  @Uint32()
  external int fileAttributes;

  @Uint32()
  external int reparseTag;
}

final class _WindowsDeviceStateFileLock {
  _WindowsDeviceStateFileLock()
    : _library = DynamicLibrary.open('kernel32.dll') {
    _createFile = _library
        .lookupFunction<
          _DeviceStateCreateFileNative,
          _DeviceStateCreateFileDart
        >('CreateFileW');
    _getFileInformation = _library
        .lookupFunction<
          _DeviceStateGetFileInformationNative,
          _DeviceStateGetFileInformationDart
        >('GetFileInformationByHandleEx');
    _closeHandle = _library
        .lookupFunction<
          _DeviceStateHandleCallNative,
          _DeviceStateHandleCallDart
        >('CloseHandle');
    _getLastError = _library
        .lookupFunction<
          _DeviceStateGetLastErrorNative,
          _DeviceStateGetLastErrorDart
        >('GetLastError');
  }

  static const _invalidHandleValue = -1;
  static const _genericReadWrite = 0xc0000000;
  static const _openAlways = 4;
  static const _fileAttributeDirectory = 0x00000010;
  static const _fileAttributeNormal = 0x00000080;
  static const _fileAttributeReparsePoint = 0x00000400;
  static const _fileFlagOpenReparsePoint = 0x00200000;
  static const _fileAttributeTagInfoClass = 9;
  static const _errorSharingViolation = 32;
  static const _errorLockViolation = 33;
  static const _extendedPathPrefix = '\\\\?\\';
  static const _devicePathPrefix = '\\\\.\\';
  static const _uncPathPrefix = '\\\\';
  static const _extendedUncPathPrefix = '\\\\?\\UNC\\';

  final DynamicLibrary _library;
  late final _DeviceStateCreateFileDart _createFile;
  late final _DeviceStateGetFileInformationDart _getFileInformation;
  late final _DeviceStateHandleCallDart _closeHandle;
  late final _DeviceStateGetLastErrorDart _getLastError;

  Future<T> run<T>({
    required File file,
    required RestoreDurability durability,
    required Future<T> Function() action,
  }) async {
    final initialType = await _requireLockPath(file, allowMissing: true);
    final handle = await _openExclusive(file);
    Object? operationError;
    StackTrace? operationStackTrace;
    try {
      final info = calloc<_DeviceStateFileAttributeTagInfo>();
      try {
        if (_getFileInformation(
              handle,
              _fileAttributeTagInfoClass,
              info.cast<Void>(),
              sizeOf<_DeviceStateFileAttributeTagInfo>(),
            ) ==
            0) {
          throw FileSystemException(
            'device_state_store_lock_information:${_getLastError()}',
            file.path,
          );
        }
        final attributes = info.ref.fileAttributes;
        if ((attributes & _fileAttributeReparsePoint) != 0 ||
            (attributes & _fileAttributeDirectory) != 0) {
          throw StateError('device_state_store_lock_reparse');
        }
      } finally {
        calloc.free(info);
      }
      await _requireLockPath(file);
      await durability.restrictFile(file);
      if (initialType == FileSystemEntityType.notFound) {
        await durability.syncDirectory(file.parent, fullBarrier: true);
      }
      return await action();
    } catch (error, stackTrace) {
      operationError = error;
      operationStackTrace = stackTrace;
      rethrow;
    } finally {
      if (_closeHandle(handle) == 0 && operationError == null) {
        Error.throwWithStackTrace(
          FileSystemException(
            'device_state_store_lock_close:${_getLastError()}',
            file.path,
          ),
          operationStackTrace ?? StackTrace.current,
        );
      }
    }
  }

  Future<int> _openExclusive(File file) async {
    while (true) {
      final nativePath = _nativePath(file.absolute.path).toNativeUtf16();
      late final int handle;
      var error = 0;
      try {
        handle = _createFile(
          nativePath,
          _genericReadWrite,
          0,
          nullptr,
          _openAlways,
          _fileAttributeNormal | _fileFlagOpenReparsePoint,
          0,
        );
        if (handle == _invalidHandleValue) error = _getLastError();
      } finally {
        malloc.free(nativePath);
      }
      if (handle != _invalidHandleValue) return handle;
      if (error != _errorSharingViolation && error != _errorLockViolation) {
        throw FileSystemException(
          'device_state_store_lock_open:$error',
          file.path,
        );
      }
      await _requireLockPath(file, allowMissing: true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  static Future<FileSystemEntityType> _requireLockPath(
    File file, {
    bool allowMissing = false,
  }) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.file ||
        (allowMissing && type == FileSystemEntityType.notFound)) {
      return type;
    }
    throw StateError('device_state_store_lock_path');
  }

  static String _nativePath(String path) {
    final absolute = p.normalize(p.absolute(path));
    if (absolute.startsWith(_extendedPathPrefix) ||
        absolute.startsWith(_devicePathPrefix)) {
      return absolute;
    }
    if (absolute.startsWith(_uncPathPrefix)) {
      return '$_extendedUncPathPrefix${absolute.substring(2)}';
    }
    return '$_extendedPathPrefix$absolute';
  }
}

typedef _DeviceStateOpenNative = Int32 Function(Pointer<Utf8>, Int32, Uint32);
typedef _DeviceStateOpenDart = int Function(Pointer<Utf8>, int, int);
typedef _DeviceStateFdCallNative = Int32 Function(Int32);
typedef _DeviceStateFdCallDart = int Function(int);
typedef _DeviceStateFlockNative = Int32 Function(Int32, Int32);
typedef _DeviceStateFlockDart = int Function(int, int);
typedef _DeviceStateErrnoNative = Pointer<Int32> Function();
typedef _DeviceStateErrnoDart = Pointer<Int32> Function();

final class _PosixDeviceStateFileLock {
  _PosixDeviceStateFileLock()
    : _library = DynamicLibrary.process(),
      _isApple = Platform.isMacOS || Platform.isIOS {
    _open = _library
        .lookupFunction<_DeviceStateOpenNative, _DeviceStateOpenDart>('open');
    _close = _library
        .lookupFunction<_DeviceStateFdCallNative, _DeviceStateFdCallDart>(
          'close',
        );
    _flock = _library
        .lookupFunction<_DeviceStateFlockNative, _DeviceStateFlockDart>(
          'flock',
        );
    final errnoSymbol = Platform.isAndroid
        ? '__errno'
        : _isApple
        ? '__error'
        : '__errno_location';
    _errno = _library
        .lookupFunction<_DeviceStateErrnoNative, _DeviceStateErrnoDart>(
          errnoSymbol,
        );
  }

  static const _eintr = 4;
  static const _oReadWrite = 2;
  static const _lockExclusive = 2;
  static const _lockUnlock = 8;

  final DynamicLibrary _library;
  final bool _isApple;
  late final _DeviceStateOpenDart _open;
  late final _DeviceStateFdCallDart _close;
  late final _DeviceStateFlockDart _flock;
  late final _DeviceStateErrnoDart _errno;

  int get _oCreate => _isApple ? 0x00000200 : 0x00000040;
  int get _oNoFollow => _isApple ? 0x00000100 : 0x00020000;
  int get _oCloseOnExec => _isApple ? 0x01000000 : 0x00080000;
  int get _lastError => _errno().value;

  Future<T> run<T>({
    required File file,
    required RestoreDurability durability,
    required Future<T> Function() action,
  }) async {
    final initialType = await FileSystemEntity.type(
      file.path,
      followLinks: false,
    );
    if (initialType != FileSystemEntityType.notFound &&
        initialType != FileSystemEntityType.file) {
      throw StateError('device_state_store_lock_path');
    }
    final nativePath = file.absolute.path.toNativeUtf8();
    late final int fd;
    try {
      fd = _retryOnEintr(
        () => _open(
          nativePath,
          _oReadWrite | _oCreate | _oNoFollow | _oCloseOnExec,
          0x180,
        ),
        path: file.path,
        operation: 'open',
        failure: (result) => result < 0,
      );
    } finally {
      malloc.free(nativePath);
    }

    Object? operationError;
    try {
      _retryOnEintr(
        () => _flock(fd, _lockExclusive),
        path: file.path,
        operation: 'flock',
        failure: (result) => result != 0,
      );
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw StateError('device_state_store_lock_path');
      }
      await durability.restrictFile(file);
      if (initialType == FileSystemEntityType.notFound) {
        await durability.syncDirectory(file.parent, fullBarrier: true);
      }
      return await action();
    } catch (error) {
      operationError = error;
      rethrow;
    } finally {
      final unlockResult = _flock(fd, _lockUnlock);
      final unlockError = unlockResult == 0 ? null : _lastError;
      final closeResult = _close(fd);
      final closeError = closeResult == 0 ? null : _lastError;
      if (operationError == null &&
          (unlockError != null || closeError != null)) {
        throw FileSystemException(
          'device_state_store_lock_release:$unlockError:$closeError',
          file.path,
        );
      }
    }
  }

  int _retryOnEintr(
    int Function() callback, {
    required String path,
    required String operation,
    required bool Function(int result) failure,
  }) {
    while (true) {
      final result = callback();
      if (!failure(result)) return result;
      final error = _lastError;
      if (error == _eintr) continue;
      throw FileSystemException(
        'device_state_store_lock_$operation:$error',
        path,
      );
    }
  }
}

abstract final class _DeviceStateStoreCriticalSection {
  // 先在本 isolate 排队，避免阻塞式系统锁卡住自己的事件循环；
  // 跨 isolate 与跨进程的互斥只由上面的内核锁负责。
  static final Map<String, Future<void>> _tails = <String, Future<void>>{};

  static Future<T> run<T>(String key, Future<T> Function() action) {
    final previous = _tails[key] ?? Future<void>.value();
    final release = Completer<void>();
    final current = release.future;
    _tails[key] = current;
    return _run(key, previous, current, release, action);
  }

  static Future<T> _run<T>(
    String key,
    Future<void> previous,
    Future<void> current,
    Completer<void> release,
    Future<T> Function() action,
  ) async {
    await previous;
    try {
      return await action();
    } finally {
      release.complete();
      if (identical(_tails[key], current)) {
        _tails.remove(key);
      }
    }
  }
}
