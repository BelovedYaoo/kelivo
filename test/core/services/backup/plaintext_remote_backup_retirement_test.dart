import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/services/backup/plaintext_remote_backup_retirement.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('启动退役清除旧远端备份状态且保留本地导出与无关数据', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'webdav_config_v1': '{"password":"webdav-secret"}',
      's3_config_v1': '{"secretAccessKey":"s3-secret"}',
      'backup_reminder_enabled_v1': true,
      'backup_reminder_interval_days_v1': 7,
      'backup_reminder_minutes_of_day_v1': 480,
      'backup_reminder_enabled_at_v1': '2026-07-01T00:00:00.000Z',
      'backup_reminder_last_backup_at_v1': '2026-07-02T00:00:00.000Z',
      'unrelated_preference': 'kept',
    });
    final preferences = await SharedPreferences.getInstance();
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'kelivo_remote_backup_retirement_test_',
    );
    addTearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    final staleDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}'
      'kelivo_backup_2026-07-01T00-00-00.000000',
    );
    await staleDirectory.create();
    await File(
      '${staleDirectory.path}${Platform.pathSeparator}'
      'kelivo_backup_2026-07-01T00-00-00.000000.zip',
    ).writeAsString('plaintext');
    for (final name in <String>[
      'kelivo_backup_old.zip',
      '_bk_settings.json',
      '_bk_chats.json',
      '_bk_manifest.json',
      '_bk_kelivo.db',
    ]) {
      await File(
        '${temporaryDirectory.path}${Platform.pathSeparator}$name',
      ).writeAsString('plaintext');
    }
    final localExportDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}'
      'kelivo_local_export_in_progress',
    );
    await localExportDirectory.create();
    final unrelatedFile = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}user_export.zip',
    );
    await unrelatedFile.writeAsString('kept');

    await PlaintextRemoteBackupRetirement(
      preferences: preferences,
      temporaryDirectory: temporaryDirectory,
    ).retire();

    for (final key in PlaintextRemoteBackupRetirement.retiredPreferenceKeys) {
      expect(preferences.containsKey(key), isFalse, reason: key);
    }
    expect(preferences.getString('unrelated_preference'), 'kept');
    expect(await staleDirectory.exists(), isFalse);
    expect(
      await File('${temporaryDirectory.path}/kelivo_backup_old.zip').exists(),
      isFalse,
    );
    expect(await localExportDirectory.exists(), isTrue);
    expect(await unrelatedFile.exists(), isTrue);
  });

  test('启动退役遇到异常临时根时显式失败', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final root = await Directory.systemTemp.createTemp(
      'kelivo_remote_backup_invalid_root_test_',
    );
    final invalidRoot = File('${root.path}${Platform.pathSeparator}temp-root');
    await invalidRoot.writeAsString('not-a-directory');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    await expectLater(
      PlaintextRemoteBackupRetirement(
        preferences: preferences,
        temporaryDirectory: Directory(invalidRoot.path),
      ).retire(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'plaintext_remote_backup_temp_root',
        ),
      ),
    );
  });
}
