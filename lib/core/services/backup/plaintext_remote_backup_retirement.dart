import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../storage/durable_shared_preferences_store.dart';
import '../workspace/account_workspace_runtime.dart';

final class PlaintextRemoteBackupRetirement {
  const PlaintextRemoteBackupRetirement({
    required this.preferenceStore,
    required this.registeredPreferencePrefixes,
    required this.temporaryDirectory,
  });

  static const Set<String> retiredPreferenceKeys = <String>{
    'webdav_config_v1',
    's3_config_v1',
    'backup_reminder_enabled_v1',
    'backup_reminder_interval_days_v1',
    'backup_reminder_minutes_of_day_v1',
    'backup_reminder_enabled_at_v1',
    'backup_reminder_last_backup_at_v1',
    'request_log_enabled_v1',
    'flutter_log_enabled_v1',
    'log_save_output_v1',
    'log_auto_delete_days_v1',
    'log_max_size_mb_v1',
  };

  static const Set<String> _retiredLooseFileNames = <String>{
    '_bk_settings.json',
    '_bk_chats.json',
    '_bk_manifest.json',
    '_bk_kelivo.db',
  };
  static const _localPreferencePrefix = 'flutter.';
  static const _accountPreferencePrefix = 'kelivo.account.';
  static final _workspaceKeyPattern = RegExp(r'^[0-9a-f]{64}$');

  final DurableSharedPreferencesStore preferenceStore;
  final Set<String> registeredPreferencePrefixes;
  final Directory temporaryDirectory;

  static Future<void> retireCurrentInstallation({
    required AccountWorkspaceRuntime workspaceRuntime,
  }) async {
    final registeredPreferencePrefixes = await workspaceRuntime
        .registeredPreferencesPrefixes();
    final temporaryDirectory = await getTemporaryDirectory();
    await PlaintextRemoteBackupRetirement(
      preferenceStore:
          PlatformDurableSharedPreferencesStore.forCurrentPlatform(),
      registeredPreferencePrefixes: registeredPreferencePrefixes,
      temporaryDirectory: temporaryDirectory,
    ).retire();
  }

  Future<void> retire() async {
    _validateRegisteredPreferencePrefixes();
    final existingKeys = await preferenceStore.readRawKeys();
    for (final rawKey in existingKeys) {
      final accountPrefix = _retiredAccountPrefix(rawKey);
      if (accountPrefix != null &&
          !registeredPreferencePrefixes.contains(accountPrefix)) {
        throw StateError(
          'plaintext_remote_backup_unregistered_namespace:$accountPrefix',
        );
      }
    }
    final retiredRawKeys = <String>{
      for (final prefix in registeredPreferencePrefixes)
        for (final key in retiredPreferenceKeys) '$prefix$key',
    };
    final existingRetiredKeys =
        existingKeys.where(retiredRawKeys.contains).toList()..sort();
    for (final rawKey in existingRetiredKeys) {
      await preferenceStore.remove(rawKey);
    }

    final rootType = await FileSystemEntity.type(
      temporaryDirectory.path,
      followLinks: false,
    );
    if (rootType == FileSystemEntityType.notFound) return;
    if (rootType != FileSystemEntityType.directory) {
      throw StateError('plaintext_remote_backup_temp_root');
    }

    await for (final entity in temporaryDirectory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      final isRetiredDirectory =
          type == FileSystemEntityType.directory &&
          name.startsWith('kelivo_backup_');
      final isRetiredFile =
          type == FileSystemEntityType.file &&
          (_retiredLooseFileNames.contains(name) ||
              (name.startsWith('kelivo_backup_') && name.endsWith('.zip')));
      if (isRetiredDirectory) {
        await _deleteDirectoryWithoutFollowingLinks(Directory(entity.path));
      } else if (isRetiredFile) {
        await File(entity.path).delete();
      }
    }
  }

  void _validateRegisteredPreferencePrefixes() {
    if (!registeredPreferencePrefixes.contains(_localPreferencePrefix)) {
      throw StateError('plaintext_remote_backup_local_namespace_missing');
    }
    for (final prefix in registeredPreferencePrefixes) {
      if (prefix == _localPreferencePrefix) continue;
      if (!prefix.startsWith(_accountPreferencePrefix) ||
          !prefix.endsWith('.')) {
        throw StateError('plaintext_remote_backup_namespace_invalid:$prefix');
      }
      final workspaceKey = prefix.substring(
        _accountPreferencePrefix.length,
        prefix.length - 1,
      );
      if (!_workspaceKeyPattern.hasMatch(workspaceKey)) {
        throw StateError('plaintext_remote_backup_namespace_invalid:$prefix');
      }
    }
  }

  static String? _retiredAccountPrefix(String rawKey) {
    if (!rawKey.startsWith(_accountPreferencePrefix)) return null;
    final workspaceKeyStart = _accountPreferencePrefix.length;
    final separator = rawKey.indexOf('.', workspaceKeyStart);
    if (separator < 0) return null;
    final logicalKey = rawKey.substring(separator + 1);
    if (!retiredPreferenceKeys.contains(logicalKey)) return null;
    final workspaceKey = rawKey.substring(workspaceKeyStart, separator);
    if (!_workspaceKeyPattern.hasMatch(workspaceKey)) {
      throw StateError(
        'plaintext_remote_backup_namespace_invalid:'
        '$_accountPreferencePrefix$workspaceKey.',
      );
    }
    return '$_accountPreferencePrefix$workspaceKey.';
  }

  static Future<void> _deleteDirectoryWithoutFollowingLinks(
    Directory directory,
  ) async {
    await for (final entity in directory.list(followLinks: false)) {
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      switch (type) {
        case FileSystemEntityType.directory:
          await _deleteDirectoryWithoutFollowingLinks(Directory(entity.path));
          break;
        case FileSystemEntityType.file:
          await File(entity.path).delete();
          break;
        case FileSystemEntityType.link:
          await Link(entity.path).delete();
          break;
        case FileSystemEntityType.notFound:
          throw StateError('plaintext_remote_backup_artifact_changed');
        default:
          throw StateError('plaintext_remote_backup_artifact_type');
      }
    }
    await directory.delete();
  }
}
