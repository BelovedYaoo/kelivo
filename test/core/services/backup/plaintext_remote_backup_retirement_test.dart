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
      'request_log_enabled_v1',
      'flutter_log_enabled_v1',
      'log_save_output_v1',
      'log_auto_delete_days_v1',
      'log_max_size_mb_v1',
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
    var retirementCalls = 0;

    await PlaintextRemoteBackupRetirement(
      preferenceStore: preferenceStore,
      registeredPreferencePrefixes: prefixes,
      retirePlaintextBackups: () async => retirementCalls += 1,
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
    expect(retirementCalls, 1);
  });

  test('发现未注册账号命名空间时在任何删除前显式失败', () async {
    const unknownWorkspaceKey =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    final preferenceStore =
        _MemoryPlaintextRemoteBackupPreferenceStore(<String, Object>{
          'flutter.webdav_config_v1': 'known-secret',
          'kelivo.account.$unknownWorkspaceKey.s3_config_v1': 'unknown-secret',
        });
    var retirementCalled = false;

    await expectLater(
      PlaintextRemoteBackupRetirement(
        preferenceStore: preferenceStore,
        registeredPreferencePrefixes: const <String>{'flutter.'},
        retirePlaintextBackups: () async => retirementCalled = true,
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
    expect(retirementCalled, isFalse);
  });

  test('偏好后端未实际删除时阻止完成且不调用原生退役', () async {
    final preferenceStore = _MemoryPlaintextRemoteBackupPreferenceStore(
      <String, Object>{'flutter.s3_config_v1': 'secret'},
      removeSucceeds: false,
    );
    var retirementCalled = false;

    await expectLater(
      PlaintextRemoteBackupRetirement(
        preferenceStore: preferenceStore,
        registeredPreferencePrefixes: const <String>{'flutter.'},
        retirePlaintextBackups: () async => retirementCalled = true,
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
    expect(retirementCalled, isFalse);
  });

  test('安装级退役重复执行保持幂等且不重复删除', () async {
    final preferenceStore = _MemoryPlaintextRemoteBackupPreferenceStore(
      <String, Object>{'flutter.webdav_config_v1': 'secret'},
    );
    var retirementCalls = 0;
    final retirement = PlaintextRemoteBackupRetirement(
      preferenceStore: preferenceStore,
      registeredPreferencePrefixes: const <String>{'flutter.'},
      retirePlaintextBackups: () async => retirementCalls += 1,
    );

    await retirement.retire();
    await retirement.retire();

    expect(preferenceStore.containsKey('flutter.webdav_config_v1'), isFalse);
    expect(preferenceStore.removeCallCount, 1);
    expect(retirementCalls, 2);
  });

  test('原生明文备份退役失败时显式阻断', () async {
    await expectLater(
      PlaintextRemoteBackupRetirement(
        preferenceStore: _MemoryPlaintextRemoteBackupPreferenceStore(
          const <String, Object>{},
        ),
        registeredPreferencePrefixes: const <String>{'flutter.'},
        retirePlaintextBackups: () async {
          throw StateError('managed_root_retirement_failed');
        },
      ).retire(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'managed_root_retirement_failed',
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
    var retirementCalled = false;

    await expectLater(
      PlaintextRemoteBackupRetirement(
        preferenceStore: _createDurablePreferencesStore(platform),
        registeredPreferencePrefixes: const <String>{'flutter.'},
        retirePlaintextBackups: () async => retirementCalled = true,
      ).retire(),
      throwsStateError,
    );

    final remaining = await _readAllRawPreferences(platform);
    expect(remaining['flutter.webdav_config_v1'], 'known-secret');
    expect(
      remaining['kelivo.account.$unknownWorkspaceKey.s3_config_v1'],
      'unknown-secret',
    );
    expect(retirementCalled, isFalse);
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
