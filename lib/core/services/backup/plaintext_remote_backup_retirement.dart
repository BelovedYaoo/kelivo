import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class PlaintextRemoteBackupRetirement {
  const PlaintextRemoteBackupRetirement({
    required this.preferences,
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
  };

  static const Set<String> _retiredLooseFileNames = <String>{
    '_bk_settings.json',
    '_bk_chats.json',
    '_bk_manifest.json',
    '_bk_kelivo.db',
  };

  final SharedPreferences preferences;
  final Directory temporaryDirectory;

  static Future<void> retireCurrentInstallation() async {
    final preferences = await SharedPreferences.getInstance();
    final temporaryDirectory = await getTemporaryDirectory();
    await PlaintextRemoteBackupRetirement(
      preferences: preferences,
      temporaryDirectory: temporaryDirectory,
    ).retire();
  }

  Future<void> retire() async {
    for (final key in retiredPreferenceKeys) {
      if (!preferences.containsKey(key)) continue;
      await preferences.remove(key);
      if (preferences.containsKey(key)) {
        throw StateError('plaintext_remote_backup_preference_retirement:$key');
      }
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
