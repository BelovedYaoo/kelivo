import 'dart:io';

import 'package:Kelivo/core/services/storage/durable_shared_preferences_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';
import 'package:Kelivo/core/services/backup/plaintext_remote_backup_retirement.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('启动入口绑定工作区后以同一 runtime 执行安装级退役', () async {
    final source = await File('lib/main.dart').readAsString();
    const bootstrapCall = 'AccountWorkspaceRuntime.bootstrap(';
    const retirementCall =
        'PlaintextRemoteBackupRetirement.retireCurrentInstallation(';
    final bootstrapOffset = source.indexOf(bootstrapCall);
    final retirementOffset = source.indexOf(retirementCall);
    final retirementEnd = source.indexOf(');', retirementOffset);

    expect(bootstrapOffset, greaterThanOrEqualTo(0));
    expect(retirementOffset, greaterThan(bootstrapOffset));
    expect(retirementEnd, greaterThan(retirementOffset));
    expect(
      source.substring(retirementOffset, retirementEnd),
      contains('workspaceRuntime: workspaceRuntime'),
    );
  });

  test('安装级退役精确清除匿名当前及非当前账号旧状态', () async {
    const retiredKeys = <String>{
      'webdav_config_v1',
      's3_config_v1',
      'backup_reminder_enabled_v1',
      'backup_reminder_interval_days_v1',
      'backup_reminder_minutes_of_day_v1',
      'backup_reminder_enabled_at_v1',
      'backup_reminder_last_backup_at_v1',
    };
    const activeWorkspaceKey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const signedOutWorkspaceKey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const prefixes = <String>{
      'flutter.',
      'kelivo.account.$activeWorkspaceKey.',
      'kelivo.account.$signedOutWorkspaceKey.',
    };
    final initialPreferences = <String, Object>{};
    for (final prefix in prefixes) {
      for (final key in retiredKeys) {
        initialPreferences['$prefix$key'] = 'retired';
      }
    }
    initialPreferences.addAll(<String, Object>{
      'flutter.unrelated_preference': 'kept',
      'flutter.webdav_config_v1_extra': 'kept-similar',
      'other.app.webdav_config_v1': 'kept-other-app',
    });
    final preferenceStore = _MemoryPlaintextRemoteBackupPreferenceStore(
      initialPreferences,
    );
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
      preferenceStore: preferenceStore,
      registeredPreferencePrefixes: prefixes,
      temporaryDirectory: temporaryDirectory,
    ).retire();

    expect(PlaintextRemoteBackupRetirement.retiredPreferenceKeys, retiredKeys);
    for (final prefix in prefixes) {
      for (final key in retiredKeys) {
        expect(preferenceStore.containsKey('$prefix$key'), isFalse);
      }
    }
    expect(preferenceStore['flutter.unrelated_preference'], 'kept');
    expect(preferenceStore['flutter.webdav_config_v1_extra'], 'kept-similar');
    expect(preferenceStore['other.app.webdav_config_v1'], 'kept-other-app');
    expect(await staleDirectory.exists(), isFalse);
    expect(
      await File('${temporaryDirectory.path}/kelivo_backup_old.zip').exists(),
      isFalse,
    );
    expect(await localExportDirectory.exists(), isTrue);
    expect(await unrelatedFile.exists(), isTrue);
  });

  test('发现未注册账号命名空间时在任何删除前显式失败', () async {
    const unknownWorkspaceKey =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    final preferenceStore =
        _MemoryPlaintextRemoteBackupPreferenceStore(<String, Object>{
          'flutter.webdav_config_v1': 'known-secret',
          'kelivo.account.$unknownWorkspaceKey.s3_config_v1': 'unknown-secret',
        });
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'kelivo_remote_backup_unknown_namespace_test_',
    );
    addTearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    await expectLater(
      PlaintextRemoteBackupRetirement(
        preferenceStore: preferenceStore,
        registeredPreferencePrefixes: const <String>{'flutter.'},
        temporaryDirectory: temporaryDirectory,
      ).retire(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'plaintext_remote_backup_unregistered_namespace:'
              'kelivo.account.$unknownWorkspaceKey.',
        ),
      ),
    );

    expect(preferenceStore.containsKey('flutter.webdav_config_v1'), isTrue);
    expect(
      preferenceStore.containsKey(
        'kelivo.account.$unknownWorkspaceKey.s3_config_v1',
      ),
      isTrue,
    );
    expect(preferenceStore.removeCallCount, 0);
  });

  test('偏好后端未实际删除时阻止完成且不继续清理临时文件', () async {
    final preferenceStore = _MemoryPlaintextRemoteBackupPreferenceStore(
      <String, Object>{'flutter.s3_config_v1': 'secret'},
      removeSucceeds: false,
    );
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'kelivo_remote_backup_remove_failure_test_',
    );
    final staleFile = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}_bk_settings.json',
    );
    await staleFile.writeAsString('plaintext', flush: true);
    addTearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    await expectLater(
      PlaintextRemoteBackupRetirement(
        preferenceStore: preferenceStore,
        registeredPreferencePrefixes: const <String>{'flutter.'},
        temporaryDirectory: temporaryDirectory,
      ).retire(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'plaintext_remote_backup_preference_retirement:'
              'flutter.s3_config_v1',
        ),
      ),
    );

    expect(preferenceStore.containsKey('flutter.s3_config_v1'), isTrue);
    expect(await staleFile.exists(), isTrue);
  });

  test('安装级退役重复执行保持幂等且不重复删除', () async {
    final preferenceStore = _MemoryPlaintextRemoteBackupPreferenceStore(
      <String, Object>{'flutter.webdav_config_v1': 'secret'},
    );
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'kelivo_remote_backup_idempotent_test_',
    );
    addTearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });
    final retirement = PlaintextRemoteBackupRetirement(
      preferenceStore: preferenceStore,
      registeredPreferencePrefixes: const <String>{'flutter.'},
      temporaryDirectory: temporaryDirectory,
    );

    await retirement.retire();
    await retirement.retire();

    expect(preferenceStore.containsKey('flutter.webdav_config_v1'), isFalse);
    expect(preferenceStore.removeCallCount, 1);
  });

  test('启动退役遇到异常临时根时显式失败', () async {
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
        preferenceStore: _MemoryPlaintextRemoteBackupPreferenceStore(
          const <String, Object>{},
        ),
        registeredPreferencePrefixes: const <String>{'flutter.'},
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

  test('发现未注册账号旧凭据时在任何删除前失败关闭', () async {
    const unknownWorkspaceKey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    final platform = InMemorySharedPreferencesStore.withData(<String, Object>{
      'flutter.webdav_config_v1': 'known-secret',
      'kelivo.account.$unknownWorkspaceKey.s3_config_v1': 'unknown-secret',
    });
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'kelivo_remote_backup_unknown_namespace_test_',
    );
    addTearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    await expectLater(
      PlaintextRemoteBackupRetirement(
        preferenceStore: _createDurablePreferencesStore(platform),
        registeredPreferencePrefixes: const <String>{'flutter.'},
        temporaryDirectory: temporaryDirectory,
      ).retire(),
      throwsStateError,
    );

    final remaining = await _readAllRawPreferences(platform);
    expect(remaining['flutter.webdav_config_v1'], 'known-secret');
    expect(
      remaining['kelivo.account.$unknownWorkspaceKey.s3_config_v1'],
      'unknown-secret',
    );
  });
}

Future<Map<String, Object>> _readAllRawPreferences(
  SharedPreferencesStorePlatform platform,
) {
  return platform.getAllWithParameters(
    GetAllParameters(filter: PreferencesFilter(prefix: '')),
  );
}

PlatformDurableSharedPreferencesStore _createDurablePreferencesStore(
  SharedPreferencesStorePlatform platform,
) {
  return PlatformDurableSharedPreferencesStore(
    platform,
    removalProof: const _TestSharedPreferencesRemovalProof(),
  );
}

final class _TestSharedPreferencesRemovalProof
    implements DurableSharedPreferencesRemovalProof {
  const _TestSharedPreferencesRemovalProof();

  @override
  Future<void> confirmRemoval(String rawKey) async {}
}

final class _MemoryPlaintextRemoteBackupPreferenceStore
    implements DurableSharedPreferencesStore {
  _MemoryPlaintextRemoteBackupPreferenceStore(
    Map<String, Object> values, {
    this.removeSucceeds = true,
  }) : _values = Map<String, Object>.from(values);

  final Map<String, Object> _values;
  final bool removeSucceeds;
  int removeCallCount = 0;

  Object? operator [](String key) => _values[key];

  bool containsKey(String key) => _values.containsKey(key);

  @override
  Future<Set<String>> readRawKeys() async => _values.keys.toSet();

  @override
  Future<void> remove(String key) async {
    removeCallCount++;
    if (!removeSucceeds) {
      throw StateError('plaintext_remote_backup_preference_retirement:$key');
    }
    _values.remove(key);
  }
}
