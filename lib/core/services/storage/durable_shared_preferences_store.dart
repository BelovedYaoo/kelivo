import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

import '../backup/restore_durability.dart';

abstract interface class DurableSharedPreferencesStore {
  Future<Set<String>> readRawKeys();

  Future<void> remove(String rawKey);
}

final class PlatformDurableSharedPreferencesStore
    implements DurableSharedPreferencesStore {
  const PlatformDurableSharedPreferencesStore(
    SharedPreferencesStorePlatform platform, {
    required DurableSharedPreferencesRemovalProof removalProof,
  }) : this._(platform, removalProof);

  const PlatformDurableSharedPreferencesStore._(
    this._platform,
    this._removalProof,
  );

  factory PlatformDurableSharedPreferencesStore.forCurrentPlatform() {
    final DurableSharedPreferencesRemovalProof removalProof;
    if (Platform.isAndroid) {
      removalProof = const _AndroidCommitReceiptRemovalProof();
    } else if (Platform.isWindows || Platform.isLinux) {
      removalProof = JsonFileSharedPreferencesRemovalProof(
        applicationSupportDirectory: getApplicationSupportDirectory,
        durability: RestorePlatformDurability(),
      );
    } else {
      removalProof = const _UnsupportedSharedPreferencesRemovalProof();
    }
    return PlatformDurableSharedPreferencesStore(
      SharedPreferencesStorePlatform.instance,
      removalProof: removalProof,
    );
  }

  final SharedPreferencesStorePlatform _platform;
  final DurableSharedPreferencesRemovalProof _removalProof;

  @override
  Future<Set<String>> readRawKeys() async {
    final values = await _platform.getAllWithParameters(
      GetAllParameters(filter: PreferencesFilter(prefix: '')),
    );
    return values.keys.toSet();
  }

  @override
  Future<void> remove(String rawKey) async {
    if (!await _platform.remove(rawKey)) {
      throw StateError('durable_shared_preferences_remove_rejected');
    }
    await _removalProof.confirmRemoval(rawKey);
    if ((await readRawKeys()).contains(rawKey)) {
      throw StateError('durable_shared_preferences_remove_incomplete');
    }
  }
}

abstract interface class DurableSharedPreferencesRemovalProof {
  Future<void> confirmRemoval(String rawKey);
}

final class _AndroidCommitReceiptRemovalProof
    implements DurableSharedPreferencesRemovalProof {
  const _AndroidCommitReceiptRemovalProof();

  @override
  Future<void> confirmRemoval(String rawKey) async {}
}

final class JsonFileSharedPreferencesRemovalProof
    implements DurableSharedPreferencesRemovalProof {
  JsonFileSharedPreferencesRemovalProof({
    required Future<Directory> Function() applicationSupportDirectory,
    required RestoreDurability durability,
  }) : this._(applicationSupportDirectory, durability);

  JsonFileSharedPreferencesRemovalProof._(
    this._applicationSupportDirectory,
    this._durability,
  );

  static const _preferencesFileName = 'shared_preferences.json';

  final Future<Directory> Function() _applicationSupportDirectory;
  final RestoreDurability _durability;

  @override
  Future<void> confirmRemoval(String rawKey) async {
    final directory = await _applicationSupportDirectory();
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw StateError('durable_shared_preferences_directory_unsafe');
    }
    final file = File(p.join(directory.path, _preferencesFileName));
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      await _durability.syncDirectory(directory, fullBarrier: true);
      return;
    }
    if (type != FileSystemEntityType.file) {
      throw StateError('durable_shared_preferences_file_unsafe');
    }

    await _durability.syncFile(file, fullBarrier: true);
    await _durability.syncDirectory(directory, fullBarrier: true);
    final bytes = await file.readAsBytes();
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('durable_shared_preferences_file_changed');
    }
    final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('durable_shared_preferences_file_json');
    }
    if (decoded.containsKey(rawKey)) {
      throw StateError('durable_shared_preferences_remove_incomplete');
    }
  }
}

final class _UnsupportedSharedPreferencesRemovalProof
    implements DurableSharedPreferencesRemovalProof {
  const _UnsupportedSharedPreferencesRemovalProof();

  @override
  Future<void> confirmRemoval(String rawKey) {
    throw UnsupportedError('durable_shared_preferences_platform');
  }
}
